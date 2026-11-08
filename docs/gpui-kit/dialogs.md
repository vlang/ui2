# Dialogs, alert dialogs, sheets and focus traps

Ports of GPUI Kit's
[dialog](https://github.com/longbridge/gpui-kit/blob/main/website/component/dialog.md),
[alert dialog](https://github.com/longbridge/gpui-kit/blob/main/website/component/alert-dialog.md),
[sheet](https://github.com/longbridge/gpui-kit/blob/main/website/component/sheet.md) and
[focus trap](https://github.com/longbridge/gpui-kit/blob/main/website/component/focus-trap.md).
The implementation is in `ui/component_dialogs.v` (shared types, layout and the
dialog), `ui/component_dialogs_alert.v`, `ui/component_dialogs_sheet.v` and
`ui/component_dialogs_focus.v`; `examples/gpui_dialogs/main.v` shows all of them
with working state handling, and `ui/component_dialogs_test.v` covers the logic.

## How these relate to message boxes, `modal_view` and `popup`

ui2 already had three kinds of overlay, and these components sit beside them:

| API | What it is |
| --- | --- |
| `message_box`, `alert`, `confirm` | The operating system's own modal alert. It blocks until answered and is drawn outside the window. |
| `custom_message_box` | A fixed-size hand-drawn card with a title, one line of text and native buttons. |
| `modal_view` | The generic in-window overlay: a full-frame backdrop button (with an optional dismiss action), a centered surface button that keeps clicks inside the content from reaching the backdrop, and the content on top. |
| `popup` | `modal_view` plus a title row and a separator. |

`modal_dialog` is built **on** `modal_view`. It works out the dialog's size
from its content, then hands `modal_view` that size, its backdrop style and the
dismiss action, and passes the drawn surface (header, scrolling body, footer,
close button) as `modal_view`'s content. Centering, the backdrop and click
absorption are therefore `modal_view`'s, unchanged. `alert_dialog` is a
`modal_dialog` with an alert's defaults, the way GPUI Kit's `AlertDialog` is
built on its `Dialog`.

`sheet` cannot use `modal_view`, which always centers its content, so it
follows the same structure itself: a backdrop button over the frame, then a
panel against one edge whose first child is a transparent surface button that
keeps clicks inside the panel off the backdrop.

Use `message_box` when the platform's look and blocking behavior are wanted,
and these when the dialog has to hold arbitrary ui2 content, follow a
`ComponentTheme`, or must not block.

## Conventions

- Every builder takes a config and returns `!Element`. `frame` is the area the
  overlay covers, normally the window: `ui2.rect(0, 0, b.width, b.height)` with
  `b := ui2.bounds()`. Add the overlay as the **last** child of the screen so it
  is drawn over the page; several open overlays stack in the order added.
- Every one needs a non-empty `id`. Internal parts use ids under
  `${id}:component:`; body children must not use that namespace.
- State is controlled. The application owns `open`, decodes the overlay's
  actions with its decoder, which takes **the config the overlay was built
  with**, and rebuilds. Build each config in one function and use it in the
  build and in the handlers.
- A closed overlay stays in the tree with `hidden` set, so the native text
  fields in it keep their state between openings. Leave it out of the tree to
  discard that state.
- Body children are positioned relative to the body content, which is
  `dialog_body_width(config)` wide for a dialog and `sheet_layout(config).content_width`
  for a sheet. The body is always a `scroll` element: it only scrolls when its
  content is taller than the room it has, and like every ui2 scroll it keeps 16
  points of blank space below the content, which the layout counts as the
  padding under the body.
- Text is not measured by the backends, so titles and descriptions are wrapped
  against an estimate of their width that comes out a little wider than SF Pro
  and Roboto draw. A wrapped label is given room for every line it is expected
  to need.
- ui2 colors are opaque, so there is no translucent scrim. `backdrop` chooses
  between `.clear` (the default: the page stays visible but cannot be clicked),
  `.solid` (a fill of `dialog_backdrop_color(theme)`, the theme background
  darkened, which hides the page) and `.none` (no backdrop at all, so the page
  stays interactive).
- Components cannot capture keys. Each overlay has a pure key helper for
  `on_key_event`; call `ui2.consume_key()` when it returns something.

### Which keys reach the application while a text field has focus

Measured on AppKit with a probe that sent key events to a window with focused
fields; the custom renderer delivers every key to `on_key_event` first.

| Key | AppKit, field with change events | AppKit, plain `text_field` | Custom renderer |
| --- | --- | --- | --- |
| Escape | `on_key_event` | `on_key_event` | `on_key_event` |
| Return | The field (emits its `submit_id`) | The field | `on_key_event`, then the field |
| Tab, Shift+Tab | `on_key` only, as `'tab'`/`'shift+tab'` | Neither | `on_key_event`, then `on_key` |

So a dialog with fields should create them with `text_field_with_change` or
`text_field_with_change_and_submit`, register both key handlers for its focus
trap, and route the fields' `submit_id` to the same answer as Enter.

## Dialog

```v
fn profile_config(m &Model) ui2.DialogConfig {
	b := ui2.bounds()
	base := ui2.DialogConfig{
		id:          'profile'
		frame:       ui2.rect(0, 0, b.width, b.height)
		open:        m.profile_open
		title:       'Edit profile'
		description: 'Make changes to your profile here.'
		buttons:     [
			ui2.DialogButton{ id: 'cancel', text: 'Cancel', role: .cancel },
			ui2.DialogButton{ id: 'save', text: 'Save changes', role: .confirm },
		]
	}
	width := ui2.dialog_body_width(base)
	return ui2.DialogConfig{
		...base
		children: [
			ui2.text_field_with_change_and_submit('name', 'profile-submit', 'Name', m.name,
				ui2.rect(0, 0, width, 32), ui2.BoxStyle{}, ui2.TextStyle{}, 0),
		]
	}
}

// build: the dialog goes last.
children << ui2.modal_dialog(profile_config(m)) or { panic(err) }

// on_event:
if request := ui2.dialog_event_from_action(profile_config(m), action) {
	if request.reason == .confirm {
		save(m)
	}
	m.profile_open = false // every request either confirms or dismisses here
}

// on_key_event:
if request := ui2.dialog_key_event(profile_config(m), event) {
	ui2.consume_key()
	// the same handling as above
}
```

`DialogConfig` fields:

| Field | Default | Meaning |
| --- | --- | --- |
| `title`, `description` | | Header text. Both wrap; the description is muted. |
| `icon`, `icon_tone` | `''`, `.warning` | A symbol name (see `symbol_known`) drawn before the title, tinted with the tone (`.neutral` uses the foreground color). |
| `children`, `content_height` | `[]`, `-1` | Body content; `-1` measures how far the visible children reach. |
| `buttons`, `footer_align` | `[]`, `.end` | Footer buttons in order, packed to the right, centered or stretched. |
| `width`, `custom_width` | `.medium`, `0` | `.small` 360, `.medium` 448, `.large` 640 or `.full`; `custom_width > 0` replaces the preset. |
| `height` | `0` | `> 0` fixes the height; otherwise the dialog is as tall as its content. |
| `close_button` | `true` | An `xmark` symbol in the top right corner. |
| `close_on_backdrop`, `close_on_escape`, `confirm_on_enter` | `true` | Whether the decoders accept a backdrop press, Escape and Enter. |
| `backdrop` | `.clear` | See the conventions above. |
| `enabled` | `true` | `false` disables every button and makes the decoders reject every action, e.g. while saving. |
| `size`, `theme` | `.medium` | Component metrics and colors. |

The dialog is centered in `frame` and never comes closer than
`dialog_window_margin` (16) to its edges. One taller than that keeps its header
and footer and scrolls its body; one wider is narrowed. `dialog_layout(config)`
returns the geometry (`DialogLayout`) without building anything, and the tests
use it to check placement for any window size.

`DialogButton{id, text, role, variant, enabled}`: `id` is a stable key reported
back in the event; `role` is `.action`, `.confirm` or `.cancel`; `variant`
is `.auto` (primary for confirm, outline otherwise), `.primary`, `.danger`,
`.outline` or `.ghost`. `dialog_button_action_id(id, button_id)` is the action a
button emits.

The decoder returns `DialogEvent{reason, button}` with `reason` one of
`.close_button`, `.backdrop`, `.escape`, `.confirm`, `.cancel` or `.action`.
`event.dismisses()` is true for the close button, the backdrop, Escape and a
cancel button. The decoder rejects foreign, malformed and forged actions,
unknown and disabled buttons, a disabled close button or backdrop, and every
action of a closed or disabled dialog. `dialog_key_event` reads Escape and,
when `confirm_on_enter` is set, Enter or keypad Enter as the first enabled
confirm button; keys with modifiers are left alone.

`dialog_open_animation(config)` is an optional entrance: start it on
`dialog_surface_id(config.id)` when opening and the surface drops 48 points
into place over 0.2 s. When it ends the surface returns to its declaration, so a
later resize lays the dialog out afresh.

Accessibility: the root has the role `dialog` and the title as its label; the
close button is a `button` labelled `Close`.

## Alert dialog

```v
fn delete_config(m &Model) ui2.AlertDialogConfig {
	b := ui2.bounds()
	return ui2.AlertDialogConfig{
		id:             'delete'
		frame:          ui2.rect(0, 0, b.width, b.height)
		open:           m.confirming
		title:          'Delete project?'
		description:    'This action cannot be undone.'
		icon:           'trash'
		confirm_text:   'Delete'
		destructive:    true
		default_choice: .cancel // Return keeps the project
	}
}

// on_event:
if choice := ui2.alert_dialog_choice_from_action(delete_config(m), action) {
	m.confirming = false
	if choice == .confirm {
		delete_project(m)
	}
}

// on_key_event:
if choice := ui2.alert_dialog_key_choice(delete_config(m), event) {
	ui2.consume_key()
	// the same handling as above
}
```

The footer holds Cancel (`show_cancel`, default `true`) then the confirm button,
centered. `destructive` fills the confirm button with the theme's danger color
and makes the icon default to the danger tone (otherwise `.warning`; set
`icon_tone` to override). Unlike a plain dialog an alert has no close button and
ignores backdrop presses unless `close_button` or `close_on_backdrop` asks for
them, and it is 420 points wide (`custom_width`). `children` add body content
below the description.

The decoders return `AlertDialogChoice`, `.confirm` or `.cancel`. Every way of
dismissing it (Cancel, Escape, and the close button or backdrop when enabled)
is `.cancel`, as `message_box` reports dismissal. `alert_dialog_key_choice`
answers Escape with `.cancel` and Enter with `default_choice`, which is also
marked with the accessibility value `default` on its button; with the Cancel
button hidden Enter can only confirm. The root's role is `alertdialog`.
`alert_dialog_layout` and `alert_dialog_open_animation` mirror the dialog's.

## Sheet

```v
fn settings_config(m &Model) ui2.SheetConfig {
	b := ui2.bounds()
	return ui2.SheetConfig{
		id:         'settings'
		frame:      ui2.rect(0, 0, b.width, b.height)
		open:       m.settings_open
		side:       .right
		panel_size: m.settings_width
		resizable:  true
		title:      'Settings'
		buttons:    [ui2.DialogButton{ id: 'apply', text: 'Apply', role: .confirm }]
	}
}

// Opening, with the optional slide:
m.settings_open = true
(ui2.sheet_open_animation(settings_config(m)) or { panic(err) }).start(ui2.sheet_panel_id('settings'))

// on_event:
cfg := settings_config(m)
if size := ui2.sheet_size_from_pointer(cfg, action) {
	m.settings_width = size // a drag on the resize handle
} else if request := ui2.sheet_event_from_action(cfg, action) {
	slide := ui2.sheet_close_animation(cfg, fn [mut m] () {
		m.settings_open = false
	}) or { panic(err) }
	slide.start(ui2.sheet_panel_id('settings'))
}
```

A sheet is a panel against one side of `frame` (`side`: `.right`, the default,
`.left`, `.top` or `.bottom`) with a backdrop over the rest. `panel_size` (350)
is its width for left and right sheets and its height for top and bottom ones,
clamped to the frame. `margin_top` keeps a strip at the top clear, for instance
under a custom title bar, on every side but the bottom. It has a title, an
optional description, a close button, a body that fills the panel and scrolls
when needed, and footer buttons at the bottom. `close_on_backdrop`,
`close_on_escape`, `backdrop`, `enabled`, `size` and `theme` work as for a
dialog; Enter only confirms when `confirm_on_enter` is set.

`resizable` adds a 6-point drag handle on the panel's inner edge with a resize
cursor. `sheet_size_from_pointer(config, event)` turns its pointer events into
the `panel_size` to rebuild with, between `min_size` (160) and the frame.
Pointer events carry window coordinates, so the sheet's frame must be in window
coordinates too, as it is when the sheet is a child of the screen.

The slide is optional and the application keeps `open`.
`sheet_open_animation(config)` moves the panel (`sheet_panel_id(id)`) in from
just past its edge; `sheet_close_animation(config, closed)` moves it back out
and then calls `closed`, where the application sets `open` to false. Both take
`animation_duration` (0.2 s) and release the panel to its declared frame when
they end. Without them the sheet appears and disappears at once.
`sheet_layout(config)` returns the geometry, including the off-screen frame the
slide starts from.

## Focus trap

```v
// The trap of the overlay on top: the text inputs in its body.
fn trap(m &Model) ?ui2.FocusTrap {
	if !m.profile_open {
		return none
	}
	return ui2.FocusTrap{
		ids: ui2.focus_trap_ids(profile_config(m).children)
	}
}

fn tab(backwards bool) {
	t := trap(model) or { return }
	ui2.consume_key() // Tab never reaches the page behind the overlay
	if next := ui2.focus_trap_target([t], ui2.focused_id(), backwards) {
		ui2.focus(next)
	}
}

ui2.on_key_event(fn (event ui2.KeyEvent) {
	if backwards := ui2.focus_trap_direction(event) {
		tab(backwards)
	}
})
// AppKit reports Tab in a focused field only here.
ui2.on_key(fn (key string) {
	if backwards := ui2.focus_trap_key_direction(key) {
		tab(backwards)
	}
})
```

`focus()` and `focused_id()` belong to the backends, so `ui/` cannot call them;
the trap is a set of pure helpers the application calls from its key handlers.

- `focus_trap_next(ids, current, backwards) string` is the core: the id after
  `current`, wrapping at either end; a `current` outside the list moves to the
  first id (the last one backwards). Empty and repeated ids are skipped, and
  no usable id gives `''`.
- `focus_trap_direction(event)` reads Tab (`false`) and Shift+Tab (`true`) from
  `on_key_event`; `focus_trap_key_direction(key)` reads `'tab'` and
  `'shift+tab'` from `on_key`. Tab with Ctrl, Alt or Cmd is not theirs.
- `FocusTrap{ids, enabled, modal}` is one trap. `next(current, backwards)`
  cycles it; a `modal` trap (the default) pulls focus in when Tab is pressed
  outside it, a non-modal one only confines focus already inside it, and a
  disabled one does nothing. `first()` is the id to focus when the trap opens,
  and `contains(id)` tests membership.
- `focus_trap_target(traps, current, backwards)` handles several traps, listed
  from the outermost (or bottom) to the innermost (or top): the last enabled
  trap holding `current` wins, so a nested trap confines focus within it, and
  with none holding it the last enabled modal trap pulls focus in.
- `focus_trap_ids(elements)` lists, in tree order, the ids of the visible and
  enabled text fields and text areas, which are what `focus()` can move to on
  every backend (the custom renderer focuses only text inputs, and AppKit
  buttons take focus only with Full Keyboard Access).

To focus the first field when an overlay opens, call `ui2.focus(trap.first())`
once the overlay has been rendered, e.g. from `ui2.after(0.05, ...)`. The
gallery does this, and also calls `ui2.dismiss_keyboard()` before opening an
overlay that has no fields of its own over one that does.

## Parity with GPUI Kit

### Dialog

| Upstream feature | Status |
| --- | --- |
| Title, description, body content, footer buttons | Implemented: `title`, `description`, `children`, `buttons`. |
| Close button with an icon | Implemented: `close_button`, drawn with `symbol:xmark`. |
| Width (448 default), `max_w`, kept inside the window with a 16 px margin | Implemented: `width` presets, `custom_width`, `dialog_window_margin`. |
| `h(px)`, scrollable body that keeps the header and footer | Implemented: `height`; the body scrolls when the content is taller than the room. |
| `overlay`, `overlay_closable`, `keyboard`, Enter confirms | Implemented as `backdrop`, `close_on_backdrop`, `close_on_escape`, `confirm_on_enter`, decoded by the application. |
| Dialog with an icon | Implemented: `icon`, `icon_tone` in the header. |
| `on_ok`/`on_cancel` returning `false` to stay open, `on_close` | By design the decoders report what was chosen and the application decides whether to close; there are no callbacks. |
| `DialogAction`/`DialogClose` wrappers, `DialogChangeReason` | Replaced by `DialogButtonRole` and `DialogReason`. |
| Entrance animations (`SlideDown`, `Fade`, `FadeSlide`, `None`) | Partial: `dialog_open_animation` slides; ui2 has no opacity to fade with. Reduced motion is the application's choice of whether to start it. |
| Nested dialogs | Supported by adding several overlays in order. Upstream's 16 px offset per layer is omitted because `modal_view` always centers. |
| `margin_top` (top offset instead of centering) | Omitted: dialogs are centered by `modal_view`. |
| Declarative `trigger`, `content` builder, `DialogHeader`/`Title`/`Description`/`Footer` parts, `WindowExt::open_dialog`/`close_dialog` | Not applicable: any element opens a dialog by setting `open`, and the parts are config fields. Footers hold buttons only, not arbitrary elements. |
| Custom styling (`bg`, `rounded`, padding) | Through `ComponentTheme` and `size` only. |
| Initial focus, built-in focus trap | Application-wired with the focus-trap helpers. |
| Shadow, translucent overlay, window drag area on the overlay | Not available in ui2 (no shadows, opaque colors only). |

### Alert dialog

| Upstream feature | Status |
| --- | --- |
| Title, description, icon | Implemented. |
| `confirm()`/`show_cancel`, `ok_text`, `cancel_text` | Implemented as `show_cancel` (default `true` here, since this is a confirm dialog; upstream defaults to OK only), `confirm_text`, `cancel_text`. |
| `ok_variant(Danger)` | Implemented as `destructive`. `cancel_variant` is omitted: Cancel is always outlined. |
| Not overlay-closable, no close button, Escape closes, 420 px wide | Implemented as the defaults. |
| Centered footer | Implemented (`footer_align`, as documented upstream; upstream's code right-aligns). |
| Default and cancel roles | Implemented: `default_choice` picks what Enter answers; every dismissal answers `.cancel`. |
| `button_props` merging | Not needed: V's struct update syntax does the same. |
| Callbacks, trigger, content builder | As for the dialog. |

### Sheet

| Upstream feature | Status |
| --- | --- |
| Left, right (default), top and bottom placement | Implemented. |
| `size` (350 default), `margin_top` | Implemented as `panel_size` and `margin_top` (default 0, since a ui2 window's content has no title bar in it). |
| Title, body, footer, close button | Implemented; a `description` is added, and footers hold buttons only. |
| `overlay`, `overlay_closable`, Escape | Implemented as `backdrop`, `close_on_backdrop`, `close_on_escape`. |
| `resizable` | Implemented, but off by default because the application has to store the size. |
| Slide animation | Implemented and optional, in and out, over the full panel size. Upstream slides in only, by 100 px over 0.15 s. |
| `on_close`, styling | As for the dialog. |

### Focus trap

| Upstream feature | Status |
| --- | --- |
| Tab and Shift+Tab cycle within a container | Implemented as pure helpers the key handlers call. |
| Multiple independent traps, nested traps (innermost wins), conditional traps | Implemented by `focus_trap_target` and `FocusTrap.enabled`/`modal`. |
| Built into Dialog and Sheet | Application-wired: `focus_trap_ids` collects a body's fields. |
| Traps over any focusable element | Limited to text fields and text areas, the controls every backend can focus. |
| `Root` intercepting Tab | Not applicable: components cannot capture keys. |

## Verification

```sh
v test ui/component_dialogs_test.v
v -d ui2_custom_rendering test ui/component_dialogs_test.v
v run examples/gpui_dialogs/main.v
v -d ui2_custom_rendering run examples/gpui_dialogs/main.v
```

The tests cover layout (centering, presets, window margins, scrolling bodies,
text wrapping, tiny windows), element structure, every decoder against foreign,
malformed, forged, disabled and closed input, the key helpers, the sheet slide
animations and resizing, and the focus-trap helpers. The gallery opens with the
profile dialog showing; its buttons open the long dialog, the alert dialog (from
the page, and nested over the profile dialog) and a sheet on each side.
