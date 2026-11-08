# Input components

Ports of GPUI Kit's
[number input](https://github.com/longbridge/gpui-kit/blob/main/website/component/number-input.md),
[OTP input](https://github.com/longbridge/gpui-kit/blob/main/website/component/otp-input.md)
and [input group](https://github.com/longbridge/gpui-kit/blob/main/website/component/input-group.md),
which also covers the prefix, suffix and clear button of GPUI Kit's
[input](https://github.com/longbridge/gpui-kit/blob/main/website/component/input.md).
The implementation is in `ui/component_inputs.v` (shared field helpers and the
input group), `ui/component_inputs_number.v` and `ui/component_inputs_otp.v`;
`examples/gpui_inputs/main.v` shows every component with working state
handling, and `ui/component_inputs_test.v` covers the logic.

## Conventions

- Every builder takes a config struct and returns `!Element`. The frame must be
  finite and non-negative, child frames are parent-local, and every one of
  these components needs a non-empty `id`.
- Each component is built around native text fields, so typing, selection,
  input methods, paste, undo, secure entry and screen readers behave as in any
  other field. A field emits its own id as an action on every edit; read what
  it holds with `ui2.text(id)`. The `*_field_id` and `otp_input_cell_id`
  helpers return those ids.
- State is controlled. The application stores the text, rebuilds with it, and
  decodes the component's actions with its decoder, which takes **the config
  the component was built with**. Build the config from the model in one
  function and use it in both places.
- Text fields are controlled on change (README, "State and identity"): a
  rebuild that declares the same text as last time keeps whatever the field
  shows. When the application rejects or rewrites what was typed and the
  stored text ends up unchanged, put it back with `ui2.set_text(id, text)`
  after the rebuild. The gallery's `refresh_and_settle` shows the pattern.
- Components cannot capture keys. Each has pure key helpers to call from
  `on_key_event` while one of its fields has focus (`ui2.focused_id()`); call
  `ui2.consume_key()` when a helper returns something.
- `size` is `ComponentSize` and colors come from `ComponentTheme`. `invalid`
  draws the theme's danger border without rejecting edits.

### How the frame is drawn

A field whose box declares a border draws that box on every backend (AppKit
then goes without its native bezel); a field without one keeps the backend's
own frame, AppKit's bezel or the custom renderer's outline. The number input
and the input group give their field the full height of a shared frame
(border, corner radius and a muted background for the addons) and a one-pixel
border in the theme's border color, which reads as the divider between the
field and the parts beside it. OTP cells stand alone and keep the backend's
own field frame until they are marked invalid.

### Which keys reach `on_key_event` while a field has focus

| Backend | Delivered first, so the helper can consume them |
| --- | --- |
| Custom renderer | Every key; typed characters arrive separately as text. |
| AppKit | Keys AppKit routes through `performKeyEquivalent:`: function keys such as the arrows, Home, End and forward Delete, and Command shortcuts. **Not** Backspace, Return, Escape or typed characters, which the field editor takes. |
| Win32, UIKit | Not verified. |

The AppKit row was measured with a probe that sent real key events to a key
window. The consequence is spelled out under OTP input below.

## Number input

```v
fn quantity_config(m &Model) ui2.NumberInputConfig {
	return ui2.NumberInputConfig{
		id:    'quantity'
		frame: ui2.rect(24, 24, 176, 32)
		text:  m.quantity
		min:   1
		max:   99
	}
}

// build:
ui2.number_input(quantity_config(m)) or { panic(err) }

// on_event:
config := quantity_config(m)
if kind := ui2.number_input_event(config, action) {
	field := ui2.number_input_field_id('quantity')
	match kind {
		.change {
			typed := ui2.text(field)
			m.quantity = ui2.number_input_sanitize(config, typed)
			// After refresh(): if m.quantity != typed, set_text(field, m.quantity)
		}
		.submit {
			m.quantity = ui2.number_input_commit(config, ui2.text(field)) or { m.quantity }
		}
		.decrement, .increment {
			m.quantity = ui2.number_input_value_from_action(config, action) or { m.quantity }
		}
	}
}

// on_key_event, while focused_id() == number_input_field_id('quantity'):
if next := ui2.number_input_value_from_key(quantity_config(m), event) {
	ui2.consume_key()
	m.quantity = next
}
```

`NumberInputConfig`: `id`, `frame`, `text`, `placeholder`, `min ?f64`,
`max ?f64`, `step` (default 1, finite and positive), `precision` (decimal
places; -1, the default, keeps the decimals of the text, the step and a bound
the value was clamped to), `enabled`, `readonly`, `invalid`, `controls`
(`.sides`: − field +, or `.trailing`: field with ▲ above ▼ on the right),
`align`, `accessibility_label`, `size`, `theme`.

| Function | Purpose |
| --- | --- |
| `number_input(config) !Element` | The control. Buttons that cannot move the value are disabled. |
| `number_input_field_id(id)` | The native field's id and its change action. |
| `number_input_event(config, action) ?NumberInputEventKind` | `.change`, `.submit`, `.decrement` or `.increment`; none for foreign, forged and disabled actions, edits and steps while read-only, and steps that cannot move. |
| `number_input_value_from_action(config, action) ?string` | The text after a step button. |
| `number_input_key_step(event) ?NumberInputStep` / `number_input_value_from_key(config, event) ?string` | ↑ and ↓ without modifiers. |
| `number_input_step(config, direction) ?string` | One step from `config.text`, also for programmatic increment and decrement. |
| `number_input_sanitize(config, typed) string` | Keeps an optional leading sign (a minus only when the range allows negatives), digits and one decimal point (none at precision 0); folds full-width digits, signs and points from CJK input methods into ASCII. |
| `number_input_commit(config, text) ?string` | Parses, clamps and formats; empty stays empty, unparsable gives none. |
| `number_input_parse(text) ?f64`, `number_input_format(value, precision)`, `number_input_in_range(config, text)` | The pieces the above are built from. |

Stepping follows GPUI Kit (and the web): empty or unparsable text steps from
zero into the range, the result is clamped, and a step that cannot move the
value in the pressed direction (at a bound, or ↓ below the min) does nothing.
Decimals are kept exactly: stepping 0.2 by 0.1 gives `0.3`. A typed value
outside the range is kept while typing; show it with `invalid` (see
`number_input_in_range`) and clamp it with `number_input_commit`.

| GPUI Kit | ui2 |
| --- | --- |
| Increment/decrement buttons, ↑/↓ keys | Implemented (keys through `number_input_value_from_key`) |
| `min`, `max`, `step`, clamping, direction rule, precision kept | Implemented |
| Restricted typing, full-width normalization, leading `.5` | Implemented (`number_input_sanitize`, `number_input_parse`) |
| `MaskPattern::Number { fraction }` | `precision` |
| `MaskPattern::Number { separator }` (thousands separators) | Omitted: the field would have to reformat while the user types, moving the caret, which ui2's controlled fields cannot do without fighting the native editor. |
| `step_by` (a step computed from the value and direction) | Not needed as an API: the application computes `step` from its value before each build. |
| `set_step(None)` (application handles `Step` events) | The application always owns the value; it may ignore `number_input_value_from_action` and step itself. |
| Clamp on blur | ui2 reports no blur, so the clamp is `number_input_commit`, called on Return or before the value is used. |
| `controls_right` | `controls: .trailing` |
| Sizes, disabled, read-only | Implemented |
| Centered text | `align`; the default is `.left` because AppKit fields ignore alignment today (see Requested backend changes). |
| `prefix` / `suffix` elements, `appearance(false)` | Omitted: use an input group for units and adornments; the frame is part of the component. |
| `spinbutton` role | The field carries `accessibility_role: 'spinbutton'`; AppKit keeps its native text-field role for that name. |

## OTP input

```v
fn code_config(m &Model) ui2.OtpInputConfig {
	return ui2.OtpInputConfig{
		id:        'code'
		frame:     ui2.rect(24, 24, 320, 40)
		code:      m.code
		separator: '-'
	}
}

// on_event: a cell changed.
config := code_config(m)
if index := ui2.otp_input_cell_from_action(config, action) {
	cell := ui2.otp_input_cell_id('code', index)
	edit := ui2.otp_input_edit(config, index, ui2.text(cell))
	m.code = edit.code
	ui2.refresh()
	// The edited cell may still show what was typed (e.g. `35`).
	expected := ui2.otp_input_cell_text(edit.code, index)
	if ui2.text(cell) != expected {
		ui2.set_text(cell, expected)
	}
	ui2.focus(ui2.otp_input_cell_id('code', edit.focus))
	if edit.complete {
		// verify m.code
	}
}

// on_key_event: Backspace, Delete, ←, →, Home and End move between cells.
if index := ui2.otp_input_cell_from_action(config, ui2.focused_id()) {
	if edit := ui2.otp_input_key(config, index, event) {
		ui2.consume_key()
		// store edit.code, refresh, focus edit.focus
	}
}
```

`OtpInputConfig`: `id`, `frame`, `code` (the characters entered so far),
`length` (1 to `otp_input_max_length`, default 6), `groups` (default 2, clamped
to 1..length; each group holds ceil(length / groups) cells as in GPUI Kit),
`separator` (drawn between groups; empty leaves a wider gap), `charset`
(`.digits` or `.alphanumeric`), `masked`, `enabled`, `invalid`,
`accessibility_label`, `size`, `theme`. Functions: `otp_input`,
`otp_input_cell_id`, `otp_input_cell_from_action` (also decodes a
`focused_id()`), `otp_input_edit`, `otp_input_key`, `otp_input_cell_text`,
`otp_input_focus_index` (the cell that takes the next character),
`otp_input_normalize` and `otp_input_width` (for sizing the frame; a narrower
frame shrinks the cells).

The code has no gaps. A character typed into a filled cell replaces it, one
typed into any empty cell is appended, several at once (a paste or an
autofilled code, `123-456` included) fill the cells from there, and emptying a
cell removes its character. Focus moves to the cell after the last one
written. Backspace removes the focused cell's character, or the last one from
an empty cell; Delete removes the focused cell's character; the arrows, Home
and End move between the filled cells and the next empty one.

### One native field per cell

The OTP input uses one single-character native field per cell rather than a
single field behind drawn boxes:

- **Input methods and paste** happen in a real field, with the platform's
  composition window, candidate list and paste menu where the user is typing.
  A hidden field would compose text the user cannot see, and ui2 cannot give
  focus to a hidden element at all.
- **Focus** is the platform's: clicking a cell focuses it, and the focused
  cell shows the native caret and focus ring. The application moves focus
  after each edit with `ui2.focus`, which every backend supports. With one field behind boxes, the boxes would sit on top of
  the field and take its clicks, and they could not show focus, because
  components learn nothing about focus changes.
- **Accessibility**: each cell is a text field labelled "Digit 2 of 6" inside a
  group named by `accessibility_label`, and masked cells are native secure
  fields, so the code is never exposed as plain text.

The cost is the key handling above. Backspace in an empty cell has no text to
delete, so the field reports no change; only `on_key_event` can move back, and
on AppKit Backspace does not reach it while a field is being edited.
Backspace in a filled cell works everywhere (the field reports the emptied
cell), as do the arrows, Home, End and Delete.

| GPUI Kit | ui2 |
| --- | --- |
| Length, digits only, full-width digits | Implemented, plus `.alphanumeric` |
| Auto-advance, Backspace back, paste a whole code, arrows | Implemented (see the AppKit Backspace gap) |
| Masked | Native secure entry instead of asterisk icons |
| `groups(n)` | Implemented, with an optional `separator` |
| Disabled, sizes | Implemented; `with_size(px)` is replaced by the frame, which shrinks the cells to fit |
| `Change` when complete, `set_value`, `value`, `set_masked` | `edit.complete`; the application owns `code` and `masked` |
| `focus()` | `ui2.focus(otp_input_cell_id(id, otp_input_focus_index(config)))` |
| `Focus` / `Blur` events | Omitted: ui2 reports no focus changes. |
| Invalid state | Added (`invalid`) |

## Input group

```v
fn search_config(m &Model) ui2.InputGroupConfig {
	return ui2.InputGroupConfig{
		id:          'search'
		frame:       ui2.rect(24, 24, 352, 32)
		text:        m.search
		placeholder: 'Search'
		clearable:   true
		addons:      [
			ui2.InputGroupAddon{ id: 'icon', kind: .icon, icon: 'magnifyingglass' },
			ui2.InputGroupAddon{ id: 'go', kind: .button, side: .trailing, text: 'Search', primary: true },
		]
	}
}

// on_event:
if event := ui2.input_group_event(search_config(m), action) {
	field := ui2.input_group_field_id('search')
	match event.kind {
		.change { m.search = ui2.text(field) }
		.clear { m.search = '' } // then ui2.focus(field) after the rebuild
		.submit, .addon { run_search(m.search) } // event.addon == 'go' for the button
	}
}
```

`InputGroupConfig`: `id`, `frame`, `text`, `placeholder`, `addons`,
`clearable`, `enabled`, `readonly`, `invalid`, `secure`, `keyboard`,
`accessibility_label`, `size`, `theme`. `InputGroupAddon`: `id` (stable and
unique), `kind` (`.text`, `.icon` or `.button`), `side` (`.leading` or
`.trailing`), `text`, `icon` (a name `symbol_known` accepts; others are
rejected), `enabled`, `primary` (a filled button instead of a ghost one),
`tooltip`, `accessibility_label` (required for icon-only buttons).

Leading addons are packed from the left and trailing ones against the right,
in the order listed; the field takes the rest, and addons shrink when they
would leave it less than two control heights. Text and icon addons are muted
decoration. The clear button appears inside the right end of the field while
there is text, the group is enabled and the field is editable; it does not move
the field's edges, so the field keeps its identity and focus while it comes
and goes. `input_group_event` returns `.change`, `.submit`, `.clear` or `.addon`
(with the addon's id) and rejects foreign and forged actions, everything while
disabled, edits while read-only, a clear with nothing to clear and presses of
disabled, unknown or non-button addons.

| GPUI Kit | ui2 |
| --- | --- |
| `InlineStart` / `InlineEnd` addons | `side: .leading` / `.trailing` |
| `InputGroupText`, icons, `InputGroupButton` (label, icon, both; ghost or primary; disabled; tooltip; accessibility label) | Implemented |
| Clear button (`Input::cleanable`) | `clearable` |
| Shared border, radius and background; sizes | Implemented |
| `disabled`, `readonly`, `invalid` | Implemented |
| Password masking, `mask_toggle` | `secure`; the gallery toggles it from an eye button addon |
| `content_type` | `keyboard` |
| `BlockStart` / `BlockEnd` addons, `InputGroupTextarea` | Omitted: ui2's text area cannot grow with its content, and a toolbar row is easy to place above or below the group. |
| Clicking addon text or an icon focuses the input | Omitted: ui2 can only make a view clickable by making it a button, which would add a Tab stop and announce decoration as a button. |
| Button `loading`, dropdown menus, popover triggers | Omitted: they need the loading and menu components of later batches. |
| Context menu, paste hook, inline tokens, `Styled` overrides | Omitted: outside what ui2's native fields expose. |

## Platform notes

- On AppKit `padding_left` moves the text in for fields whose box declares a
  border; a field with the native bezel keeps the bezel's own inset.
- Number fields use the ARIA role `spinbutton`, which AppKit has no role for, so
  VoiceOver reads them as text fields.

## Verification

```sh
v test ui/component_inputs_test.v
v -d ui2_custom_rendering test ui/component_inputs_test.v
v run examples/gpui_inputs/main.v
v -d ui2_custom_rendering run examples/gpui_inputs/main.v
```
