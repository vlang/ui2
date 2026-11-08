# Toolbar, status bar and title bar

Ports of GPUI Kit's
[toolbar](https://github.com/longbridge/gpui-kit/blob/main/website/component/toolbar.md),
[status bar](https://github.com/longbridge/gpui-kit/blob/main/website/component/status-bar.md)
and [title bar](https://github.com/longbridge/gpui-kit/blob/main/website/component/title-bar.md).
The shared item model, layout and drawing are in `ui/component_bars.v`; each bar
is in `ui/component_bars_toolbar.v`, `ui/component_bars_status.v` and
`ui/component_bars_title.v`. `examples/gpui_bars/main.v` is an editor window with
an application-drawn title bar, a toolbar, a document and a status bar, plus a
panel of the bars in their other sizes and styles, with a light/dark toggle.

## Conventions

- Every builder takes a config struct and returns `!Element`. The frame must be
  finite and non-negative; the toolbar and the title bar need a non-empty `id`,
  and a status bar needs one as soon as it holds a command.
- State is controlled. A bar never changes itself: it emits actions, the
  application decodes them with the bar's decoder, stores the result and
  rebuilds. Every decoder takes **the same config the bar was built with**, so
  build the config from the model in one function and use it in both places.
- Decoders return `none` for actions that belong to something else, forged or
  malformed actions, disabled commands and disabled bars, and changes that change
  nothing.
- `size` is `ComponentSize`; colors come from `ComponentTheme`
  (`component_theme(dark)`); `style` overrides the surface.
- Commands are views with button behavior, not native buttons, so every color is
  the bar's own: a native button dims a disabled title and cannot show a pressed
  (selected) state without being disabled.
- Child frames, including the ones in custom items, are parent-local.

## Items

All three bars hold the same `BarItem`s. Build them with the constructors and
spread them to set the rest:

```v
items := [
	ui2.bar_command('new', 'New', 'plus'), // caption, icon before it
	ui2.bar_icon_command('undo', 'arrow.uturn.backward', 'Undo'), // tooltip = accessible name
	ui2.bar_separator(),
	ui2.toolbar_group('history', 'History', [undo, redo]), // a named run (toolbar)
	ui2.BarItem{
		...ui2.bar_icon_command('bold', 'textformat', 'Bold')
		selected: app.bold // drawn pressed
	},
	ui2.BarItem{
		...ui2.bar_command('insert', 'Insert', 'plus.rectangle')
		dropdown:  true // a chevron after the caption
		action_id: ui2.dropdown_menu_toggle_action('insert-menu') // opens a menu
	},
	ui2.bar_spacer(), // pushes what follows to the far end
	ui2.BarItem{
		...ui2.bar_label('Saved')
		icon:  'checkmark.circle'
		muted: true
	},
	ui2.bar_custom('search', 200, [field]), // application elements in a 200-wide slot
]
```

| Kind | Constructor | Notes |
| --- | --- | --- |
| `command` | `bar_command(id, caption, icon)`, `bar_icon_command(id, icon, tooltip)` | Ghost button: no fill until hovered, focused or `selected`. `enabled`, `tooltip`, `dropdown`, `action_id`, `accessibility_label`, `width` (overrides the estimate). |
| `label` | `bar_label(text)` | Read-only text with an optional `icon`; `muted`, `bold`. No hover, no click. |
| `separator` | `bar_separator()` | A one-point line, three quarters of a command high. |
| `spacer` | `bar_spacer()` | Spacers share the room the other items leave. |
| `custom` | `bar_custom(id, width, children)` | `width` along the bar, `control` high (see `bar_metrics`) and centered across it. |
| `group` | `toolbar_group(id, label, items)` | Announced as one `group` with the label. Groups cannot nest. |

Commands, groups and custom items need an `id`, unique across the bar (regions
of a status or title bar included). A command emits
`bar_item_action(bar id, item id)` — the id is hex-encoded, so any string works
and a command keeps its identity when items move — unless it has an
`action_id`. Icons are `symbol:` images; use names `symbol_known` accepts.

There is no backend-neutral text measurement, so captions are sized from
`component_text_width_estimate` with room to spare: a native label ends its text
with an ellipsis rather than overflow. Items that do not fit are left out from
the end of their run, so nothing overlaps; the `*_overflow` functions list the
commands left out, for an overflow menu.

## Sizes and styling

`bar_metrics(kind, size)` returns the geometry of a bar: the `height` the size
is designed for (give the bar that frame height, or that width for a vertical
toolbar), the `control` height of commands and custom slots, `padding`, `gap`,
`font_size`, `icon`, `radius`, `inner` (padding inside a command) and, for title
bars, `window_button` (the width of a window button).

| | `.small` | `.medium` (default) | `.large` |
| --- | --- | --- | --- |
| Toolbar | 28, controls 20 (upstream `xsmall`) | 32, controls 24 (upstream default `small`) | 48, controls 32 (upstream `medium`) |
| Status bar | 24, controls 18 | 28, controls 20 (upstream: xsmall ghost buttons) | 32, controls 24 |
| Title bar | 28, buttons 40 wide | 34 (upstream `TITLE_BAR_HEIGHT`), buttons 46 wide | 40, buttons 50 wide |

`BarStyle` overrides the surface; what is left unset keeps the bar's default:

| Field | Default |
| --- | --- |
| `background ?u32`, `gradient` | Toolbar: none (transparent, as upstream). Status bar: the background tinted toward `muted`. Title bar: upstream's vertical gradient from the title-bar color mixed toward the background down to the title-bar color. |
| `foreground ?u32` | Text and icons: `foreground` (status bar: between `muted_foreground` and `foreground`). |
| `border ?u32` | The theme border softened toward the background. |
| `edges BarEdges` | `.auto`: none (toolbar), `.top` (status bar), `.bottom` (title bar); or `.none`, `.top`, `.bottom`, `.top_and_bottom`, `.all` (a border on every side that follows `radius`). |
| `radius`, `shadow` | 0, none. |

Hover and selected fills are translucent tints of the foreground, so they work
on any surface. Lines are views of their own, one point wide and square on
every renderer; a rounded border is a border-colored shape under an inset fill,
which also looks the same everywhere.

## Toolbar

```v
fn toolbar_config(app &App) ui2.ToolbarConfig {
	return ui2.ToolbarConfig{
		id:      'toolbar'
		frame:   ui2.rect(0, 34, ui2.bounds().width, 40)
		label:   'Document' // accessible name
		items:   app.toolbar_items()
		hovered: app.toolbar_hover
		focused: app.toolbar_focus
		style:   ui2.BarStyle{
			background: theme.background
			edges:      .bottom
		}
		theme:   theme
	}
}

// build:    ui2.toolbar(toolbar_config(app)) or { panic(err) }
// on_event: if hover := ui2.toolbar_hover_from_event(toolbar_config(app), event) {
//               app.toolbar_hover = hover
//           } else if item := ui2.toolbar_item_from_action(toolbar_config(app), event) {
//               app.run(item.id) // flip a toggle with !item.selected
//           }
```

- `orientation: .vertical` stacks the items top to bottom (a tool palette):
  commands are `control` square, or as wide as the bar when they have a caption;
  separators turn horizontal.
- `enabled: false` disables every command and the keyboard helper.
- `toolbar_item_frame(config, id)` is where an item (a group member too) is
  drawn, in the toolbar's parent coordinates: the `anchor` of a `dropdown_menu`
  a command opens. `toolbar_overflow(config)` lists the commands that did not
  fit.

### Keyboard

Components cannot take focus, so roving focus is a pure helper over the
application's `focused` value, after the ARIA toolbar pattern GPUI Kit follows.
The focused command is drawn with a two-point ring in the primary color.

```v
fn on_key(event ui2.KeyEvent) {
	cfg := toolbar_config(app)
	if event.code == .f6 { // or however the app moves focus into the toolbar
		app.toolbar_focus = ui2.toolbar_focus_order(cfg)[0] or { '' }
	} else if step := ui2.toolbar_key(cfg, event) {
		app.toolbar_focus = step.focused
		if step.activated {
			app.run(step.item.id) // Enter or Space
		}
	} else {
		return
	}
	ui2.consume_key()
	ui2.refresh()
}
```

While `focused` names a command, Left and Right (Up and Down on a vertical
toolbar) move to the previous or next shown, enabled command, wrapping at the
ends; Home and End go to the first and last; Enter and Space activate the
focused command; Escape lets go (`focused` becomes `''`). Tab is the
application's: clear `focused` when it moves focus elsewhere. Modified keys and
moves that change nothing return `none`. A transparent toolbar draws the inside
of the focus ring in `theme.background`, the surface it assumes it sits on.

## Status bar

```v
ui2.status_bar(
	id:       'status'
	frame:    ui2.rect(0, h - 28, w, 28)
	leading:  [ui2.bar_command('branch', 'main', 'arrow.triangle.2.circlepath'),
		ui2.bar_separator(), ui2.bar_label('0 problems')]
	center:   [ui2.bar_label(app.message)]
	trailing: [ui2.BarItem{
		...ui2.bar_command('position', 'Ln 12, Col 4', '')
		tooltip: 'Go to Line/Column'
	}, ui2.bar_label('UTF-8')]
	hovered:  app.status_hover
	theme:    theme
)!
```

`leading` and `trailing` are pinned to the ends (upstream's `left` and `right`);
`center` (upstream's `child`) fills the room between them and, as upstream,
is centered there when both ends have items, against the end when only
`leading` has, and from the start otherwise — so a bar of only `center` items
reads like a plain container. The ends are packed first, leading before
trailing; when room runs out each end loses the items nearest the middle.
Decode with `status_bar_item_from_action` and `status_bar_hover_from_event`;
`status_bar_item_frame` and `status_bar_overflow` work as for the toolbar. The
bar is `role: status` with `label` (default "Status").

## Title bar

### Hiding the platform's title bar

`set_window_chrome(.hidden_titlebar)` needs the window, which does not exist
until `run_window` starts. Schedule it from `main` with a zero-second timer: it
runs at the start of the first build, after the window is made, and the build
it asks for lays the window out again at its new size. Keep the result —
Linux, the BSDs, Android and iOS keep their frame and report false:

```v
fn main() {
	ui2.after(0, fn () {
		mut app := state()
		app.chrome_hidden = ui2.set_window_chrome(.hidden_titlebar)
	})
	ui2.run_window('Editor', 1180, 780, build, on_event)
}
```

(A flag the build function checks on its first call works too; the timer keeps
side effects out of `build`.) With the chrome hidden, the content view covers the
whole window: draw the title bar at y 0.

### The bar

```v
fn title_config(app &App) ui2.TitleBarConfig {
	return ui2.TitleBarConfig{
		id:       'titlebar'
		frame:    ui2.rect(0, 0, ui2.bounds().width, 34)
		title:    'Quarterly report.md' // centered on the bar
		leading:  [menu_button('file', 'File', 'menu-file'), menu_button('edit', 'Edit', 'menu-edit')]
		center:   [] // breadcrumbs, a search field…; the title then leads them
		trailing: [ui2.bar_custom('search', 200, [search_field]),
			ui2.bar_icon_command('settings', 'gearshape', 'Settings')]
		window:   ui2.title_bar_window(app.chrome_hidden)
		hovered:  app.title_hover
		theme:    theme
	}
}
```

`title_bar_window(chrome_hidden)` asks the platform what the bar needs, as a
`TitleBarWindow`:

- `leading_inset` — `window_controls_leading_inset()`: room for macOS's traffic
  lights, which stay over the content's leading corner (about 81 points).
  The leading items start after it.
- `controls` — `window_draws_own_controls()`: Windows needs minimize, maximize
  and close drawn once its caption is gone. Set it yourself for a custom-drawn
  look anywhere (the gallery's "Linux look" bar):
  `ui2.TitleBarWindow{ ...ui2.title_bar_window(hidden), controls: true }`.
- `maximized` — `window_is_maximized()`: the maximize button shows restore.
- `minimizable`, `maximizable` — which buttons a window offers (close always);
  `maximizable` also gates double click to maximize.

With `chrome_hidden` false, all of that is off and the title bar is simply a
bar under the platform's own.

The window buttons are drawn from one-point lines (minimize, maximize, the
restore pair of squares) and the `xmark` symbol, crisp and alike on every
renderer; they take the bar's full height, and close turns `theme.danger` when
hovered.

### Events

The bar itself is the drag region: a clickable view that reports
`pointer:down` with `title_bar_drag_action(id)`. Commands and window buttons
answer their own clicks; labels, the title, separators and icons let a press
through to the bar, so a window can be dragged by its title. There is no
double-click event, so the title bar keeps its last press and compares:

```v
if ev := ui2.title_bar_event(title_config(app), event, app.last_click, time.ticks()) {
	app.last_click = ev.click // the press to compare the next one with
	match ev.kind {
		.drag { ui2.start_window_drag() }
		.toggle_maximize { ui2.toggle_maximize_window() }
		.minimize { ui2.minimize_window() }
		.close { ui2.quit() } // ui/ cannot quit; perhaps ask to save first
		.command { app.run(ev.item.id) }
	}
}
```

`start_window_drag` works only while the press is being handled, which is when
`on_event` receives it. A second press within
`title_bar_double_click_interval` (500 ms) and `title_bar_double_click_distance`
(4 points) of a single one is a double click (`title_bar_is_double_click`); the
returned `click` then has `count: 2`, so a third press starts over instead of
toggling back. On AppKit the press reaches the bar even under the hidden title
bar, and AppKit does not zoom the window on its own there, so the double click is
the application's on every platform. Window buttons the bar does not draw cannot
be forged, and `enabled: false` disables the commands but neither dragging nor
the window buttons.

`title_bar_hover_from_event` returns the next `hovered` value: a command's id,
or `window:minimize`, `window:maximize` or `window:close` for the window buttons
(item ids cannot start with `window:`).

### Menus, breadcrumbs, search

A menu-bar button is a command whose `action_id` toggles an existing
`dropdown_menu`; `title_bar_item_frame(config, id)` is its anchor:

```v
fn menu_button(id string, caption string, menu string) ui2.BarItem {
	return ui2.BarItem{
		...ui2.bar_command(id, caption, '')
		action_id: ui2.dropdown_menu_toggle_action(menu)
		selected:  app.menu(menu).open // pressed while its menu is open
	}
}

// build, after the bars:
ui2.dropdown_menu(id: 'menu-file', state: app.file_menu, items: file_items,
	anchor: ui2.title_bar_item_frame(title_config(app), 'file') or { ui2.Rect{} },
	window: ui2.rect(0, 0, w, h))!
```

Feed events to `dropdown_menu_update` before the title bar's decoder, and close
the other menus when one opens, as a menu bar does. Breadcrumbs (`breadcrumb`)
and search fields (`input_group`) go in custom items; the example hosts an
`input_group` in the trailing region.

### Platform notes

- macOS: the traffic lights are centered 16 points from the top on current
  macOS, a point above the middle of the 34-point bar (GPUI Kit moves them to
  match; ui2 cannot yet). ui2 cannot tell full screen apart, where they hide,
  so the inset stays.
- Windows: the drawn buttons emit actions the app turns into
  `minimize_window`/`toggle_maximize_window`/`quit`; Windows' own caption
  buttons, snap layouts on the maximize button and the system menu are not
  involved.
- Linux, the BSDs, Android, iOS: the platform keeps its frame (`set_window_chrome`
  reports false), so `title_bar_window(false)` gives a plain bar.

## Accessibility

Toolbars are `toolbar` with their `label`; groups `group` with theirs; status
bars `status`; title bars `group` labelled with the title (or `label`).
Commands are `button`s named by `accessibility_label`, the caption or the
tooltip, with value `selected` when selected; labels are `text`; separators
`separator`; window buttons `button`s named Minimize, Maximize or Restore, and
Close, with matching tooltips. AppKit does not map `toolbar` yet, so a toolbar
keeps the view's own role there.

## Implemented and omitted

### Toolbar

| Upstream feature | Status |
| --- | --- |
| Commands (icon and/or label, tooltip), quiet ghost + compact presentation | Implemented as `command` items |
| `child` (sized controls take the bar's size) vs `content` (keep their own) | Commands take the bar's size; custom items keep their own width |
| Separators, plain-string labels, `div().flex_1()` spacers | Implemented (`bar_separator`, `bar_label`, `bar_spacer`) |
| Custom elements | Implemented (`bar_custom`) |
| Sizes `xsmall`/`small`/`medium` (28/32/48), `large` falls back | `.small`/`.medium`/`.large` |
| `ToolbarGroup` with accessible label | Implemented (`toolbar_group`); like upstream it does not disable its members |
| Transparent, borderless; `Styled` | Transparent by default; `BarStyle` (background, gradient, foreground, border, edges, radius, shadow) |
| Roving focus: Left/Right (Up/Down vertical), wrapping; Tab enters/leaves | `toolbar_key` with Home/End, Enter/Space and Escape added; Tab is the app's |
| `disabled(true)` (navigation only) | `enabled: false` disables commands and navigation together, since the bar owns its commands |
| Selected/toggled commands | Added: `selected`, drawn pressed, value `selected` |
| Dropdown chevron, overflow list, item frames | Added: `dropdown`, `toolbar_overflow`, `toolbar_item_frame` |
| Hover highlight | Controlled (`hovered` + `toolbar_hover_from_event`); there is no pressed (active) style |
| Hosted inputs keeping arrow keys | The app decides: call `toolbar_key` only while the toolbar has focus |

### Status bar

| Upstream feature | Status |
| --- | --- |
| `left`, `right`, `child`/`children` regions | `leading`, `trailing`, `center` |
| Center alignment rule (both → centered, left only → end, else start) | Implemented |
| Labels, ghost xsmall buttons, separators, custom elements (progress…) | Implemented |
| `status_bar`/`status_bar_border` tokens, text-xs muted text | Theme-derived defaults; `BarStyle` overrides |
| `Styled` (`bg`, `border_color`, `py`…) | `BarStyle` and `size` (three sizes; upstream has one) |
| Overflow | Added: ends drop their innermost items, the center its last ones; `status_bar_overflow` |

### Title bar

| Upstream feature | Status |
| --- | --- |
| Custom content (`child`) | `leading`, `center`, `trailing` items and a centered `title` |
| `TITLE_BAR_HEIGHT` 34, left padding 80 (macOS) / 12 | `.medium` is 34; the inset comes from `window_controls_leading_inset()` |
| `window_options()` / `title_bar_options()` (transparent title bar) | `set_window_chrome(.hidden_titlebar)` from a zero-second timer |
| `traffic_light_position` (9, 9) | Omitted: ui2 has no API to move the traffic lights |
| Drag to move | Implemented: the bar reports `pointer:down`; the app calls `start_window_drag()` |
| Double click to maximize (`zoom_window`, `titlebar_double_click`) | Implemented in `title_bar_event` from two presses; always zoom (macOS's "double-click a title bar to minimize" preference is not read) |
| Minimize / maximize-restore / close buttons, hover and close-danger colors | Implemented, drawn when `window.controls`; `minimizable`/`maximizable` stand in for upstream's `window.window_controls()` |
| `on_close_window` | The close event: the app calls `ui2.quit()` or does something else |
| Default gradient background, bottom border | Implemented |
| Right click shows the window menu (Linux) | Omitted: ui2 reports no mouse button and has no window-menu API |
| Server-side decorations detection (Linux) | Not applicable: ui2's Linux and BSD windows keep their frame |
| `pl_3` in full screen | Omitted: ui2 cannot tell full screen apart |
| `WindowControlArea` hit testing (Windows snap layouts) | Omitted: ui2 has no non-client hit-test hook |
| `window_border` (client-side shadow and resize edges) | Omitted: ui2's windows keep their native border |

## Verification

```sh
v test ui/component_bars_test.v
v -d ui2_custom_rendering test ui/component_bars_test.v
v run examples/gpui_bars/main.v
v -d ui2_custom_rendering run examples/gpui_bars/main.v
```

The tests cover the metrics, packing (spacers, overflow from the end and from
the inner end, whole-point offsets), validation, toolbar structure, groups,
hover and focus drawing, styles, vertical layout, item frames, every decoder
with foreign, forged and disabled actions, roving focus, the status bar's
alignment rules and overflow, and the title bar's inset, centering, window
buttons and glyphs, drag, double and triple clicks, hover and the window it
reads with the chrome left alone, in both themes and in tiny frames.
