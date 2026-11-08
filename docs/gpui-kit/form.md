# Form

Port of GPUI Kit's
[form](https://github.com/longbridge/gpui-kit/blob/main/website/component/form.md)
(`Form`, `Field`, `v_form`, `h_form`). The implementation is in
`ui/component_form.v` (layout, building, actions) and
`ui/component_form_validate.v` (validation helpers);
`examples/gpui_form/main.v` shows a registration form, a settings form with
sections, a four-column address form and a standalone field, all with real
controls, and `ui/component_form_test.v` covers the logic.

## Conventions

- `form(FormConfig) !Element` takes a config struct like every catalog
  component. The frame must be finite and non-negative, the form needs a
  non-empty `id`, and child frames are parent-local.
- The form lays out; the application owns every control and every value. A
  field's `control` is a closure that builds any ui2 element (a text field,
  `dropdown`, `checkbox`, `switch_control`, `number_input`, `select_box`,
  `date_picker`, `radio_group`, a view holding several of them...) at the frame
  the form gives it. The control keeps its own id, events and decoder.
- State is controlled. Validation messages, visibility and required markers
  are values in the config; build the config from the model in one function and
  use it in the build and in the event handler, as for every component.
- `size` (`ComponentSize`) sets the default control height, the label and
  description sizes and the spacing; colors come from `ComponentTheme`.

## Form

```v
fn signup_config(m &Model) ui2.FormConfig {
	errors := if m.tried { signup_errors(m) } else { map[string]string{} }
	return ui2.FormConfig{
		id:      'signup'
		frame:   ui2.rect(24, 24, 360, 0)
		fields:  [
			ui2.FormField{
				id:          'email'
				label:       'Email'
				required:    true
				description: 'We will send a confirmation link.'
				error:       errors['email'] or { '' }
				control:     fn [m] (frame ui2.Rect) !ui2.Element {
					return ui2.text_field_with_change_and_submit('email',
						ui2.form_submit_action('signup'), 'you@example.com', m.email, frame,
						ui2.BoxStyle{ radius: 6 }, ui2.TextStyle{ size: 14 }, ui2.keyboard_default)
				}
			},
			ui2.FormField{
				id:           'terms'
				label_indent: false
				control:      fn [m] (frame ui2.Rect) !ui2.Element {
					return ui2.checkbox('terms', 'I agree to the terms', m.terms, frame,
						ui2.TextStyle{ size: 14 })
				}
			},
		]
		actions: [ui2.FormAction{ id: 'create', label: 'Create account', kind: .submit }]
	}
}

// build:
ui2.form(signup_config(m)) or { panic(err) }

// on_event:
if event := ui2.form_event(signup_config(m), action) {
	if event.kind == .submit {
		m.tried = true // the next build shows the messages
	}
} else if action == 'email' {
	m.email = ui2.text('email')
}
```

`FormConfig`: `id`, `frame`, `fields`, `actions`, `label_layout`
(`BoxOrientation`: `.vertical`, the default, puts labels above the controls;
`.horizontal` beside them), `columns` (1 to `form_max_columns`), `collapse_below`,
`label_width` (the label column of a horizontal layout, default 140),
`label_align` (of horizontal labels; `.right` gives the settings look),
`label_text_size` (0 is the size's font size), `row_gap` and `column_gap`
(negative, the default, uses the size's spacing: 12/16/20 between rows and
1.5 times that between columns), `actions_align`, `reserve_descriptions`,
`accessibility_label`, `size`, `theme`.

`FormField`: `id` (stable, unique; required), `kind` (`.field` or `.section`),
`label` (a section's title), `required` (a danger-colored `*` after the label),
`description`, `description_fn` with `description_height`, `error`,
`visible`, `label_indent`, `col_span`, `col_start`, `height` (of the control;
0 is the size's control height), `align`, `control`, `text` (a read-only
value drawn where the control would be), `accessibility_label`.

### Layout

- **Vertical** (default): the label row, then the control, then the
  description or message. **Horizontal**: a label column `label_width` wide
  (at most half the cell), the control beside it, the description under the
  control. Label orientation and `columns` are independent, as in GPUI Kit.
- **Grid**: fields flow left to right, top to bottom over `columns` equal
  columns. `col_span` spans columns (clamped to the grid); `col_start`
  (1-based) puts a field in a given column. Placement follows CSS grid's
  sparse auto-placement, which GPUI Kit's grid uses: a field with a column
  start goes on the first row from the previous field where its columns are
  free, and holes left behind stay empty. A row is as tall as its tallest
  field; controls in a row line up because labels reserve the same room.
- **Hidden fields** (`visible: false`) take no room and are not built, so the
  fields after them move up; their native state (text being edited, focus) is
  not kept. Combine `visible` and `required` for conditional fields.
- **`label_indent`** keeps the label's room for a field without a label: the
  label column in a horizontal layout (GPUI Kit's meaning) and, in ui2, also
  the label row in a vertical layout, so a label-less checkbox lines up with
  the inputs beside it. `false` lets the control use that room. A label that is
  set is always drawn.
- **`align`** places a horizontal label beside a control taller than one line:
  `.center` (default), `.start` (on the control's first line, for text areas)
  or `.end`.
- **Sections** (`kind: .section`) take a row of their own across every column:
  a bold title, an optional muted description and a one-pixel rule, with a
  row's extra space above them when they follow other fields. A section with
  neither title nor description is just the rule.
- **Descriptions and messages**: `description` is muted text under the control;
  `error`, while not empty, replaces it in the theme's danger color after an
  `exclamationmark.circle` icon. Both wrap onto as many lines as an estimate
  of their width needs, up to `form_max_description_lines`.
  `reserve_descriptions` gives every field one description line even without
  text, so a message appearing does not move the fields below.
- **Actions**: one row after the fields, spanning the form, aligned with
  `actions_align`: `.end` (default, GPUI Kit's footer), `.start`, `.center` or
  `.stretch` (the buttons share the width, for a full-width submit button).
  Buttons are `styled_button`s sized to their labels (or `width`) and shrink
  evenly when they do not fit. A submit action defaults to the primary
  variant, others to secondary; `variant` and `outline` override that.
- **Size**: content is laid out from the top of `frame`, and the form's view is
  as tall as `frame.height` or its content, whichever is taller, so every
  control stays inside it (AppKit does not deliver clicks outside a view's
  bounds). `form_layout(config).height` is the content height, for sizing a
  card or a scroll around the form.
- **Responsive**: `collapse_below` makes the form one column with labels
  above their controls while `frame.width` is below it; spans and column starts
  clamp to the single column. `form_responsive_columns(width, columns,
  breakpoint)` is the same rule for applications that choose `columns`
  themselves.

### Placing controls

The `control` closure receives the control's frame in the form's coordinates
and returns the control placed there. V closures capture by value: capture a
reference to the model (`fn [m] (frame ui2.Rect) !ui2.Element`) or the values
the control needs. An error returned by the closure is returned by `form`.

- **Several controls in one field** (first and last name, city and postal
  code): return a transparent view at `frame` holding them, and divide it with
  `form_split(frame, widths, gap)`. Positive widths are fixed, zeros share the
  rest, and the frames are relative to `frame`'s origin.
- **Popups** (`select_popup`, `date_picker_overlay`) are drawn last, as
  children of the screen, anchored at the control in window coordinates.
  `form_control_frame(config, field_id)` is the control's frame in the form's
  parent's coordinates, which is the window's for a form that is a child of
  the screen. Use it as the `anchor`, and pass the closure's `frame` as the
  control's own frame:

  ```v
  fn country_config(m &Model) ui2.SelectConfig {
  	anchor := ui2.form_control_frame(address_config(m), 'country') or { ui2.Rect{} }
  	return ui2.SelectConfig{ id: 'country', frame: anchor, anchor: anchor, ... }
  }
  // the field's control:
  control: fn [m] (frame ui2.Rect) !ui2.Element {
  	return ui2.select_box(ui2.SelectConfig{ ...country_config(m), frame: frame })
  }
  // after the forms in build: ui2.select_popup(country_config(m))
  ```

  Calling the form's config function from inside a closure is safe: building
  a config does not run the closures, and `form_layout` never calls them.
- A control without an `accessibility_label` gets the field's
  (`accessibility_label`, or the label).

### Layout without building

`form_layout(config) !FormLayout` validates the config and returns what `form`
draws: `fields` (each visible field's `row`, `column`, `span`, `cell`,
`label`, `control` and `description` frames in the form's coordinates; for a
section, `label` is the title and `control` the rule), `actions` (one frame per
action), `columns` and `vertical` (after `collapse_below`) and `height`.
`layout.field(id)` finds a field.

### A field on its own

`form_field(FormFieldConfig) !Element` lays out one field in its own frame, as
a one-column form would: `id`, `frame`, `field`, `label_layout`, `label_width`,
`label_align`, `label_text_size`, `size`, `theme`. Its control's frame is
relative to the field's view. The example's newsletter card uses it beside a
separate Subscribe button.

## Actions and events

`FormAction`: `id` (stable, unique), `label`, `kind` (`.button`, `.submit`,
`.reset`), `variant` (`?ButtonVariant`), `outline`, `icon` (a name
`symbol_known` accepts), `enabled`, `width`, `accessibility_label` (required
for icon-only actions).

| Function | Purpose |
| --- | --- |
| `form_event(config, action) ?FormEvent` | `FormEvent{kind, action}` for a press of an action, and for `form_submit_action` (reported as the first enabled submit action). None for foreign, forged, unknown and disabled actions, and for a submit while every submit action is disabled. A form without submit actions reports Return with an empty `action`. |
| `form_action_id(id, action)` | The id and action of an action's button: `${id}:component:action:<hex of the action id>`. |
| `form_submit_action(id)` | The action to give text fields as `submit_id`, so Return submits the form. |
| `form_first_error(config) ?string` | The first visible field with a message, in field order: the one to focus after a failed submit. |

The form never submits or resets anything itself. On submit, validate, store
the messages and rebuild; on reset, put the model back and rebuild. Text
fields take a changed declared text, so a reset shows at once.

## Validation

Pure helpers that turn values into messages; the application stores them and
passes them back as each field's `error`.

```v
errors := ui2.form_validate([
	ui2.FormValue{ field: 'email', label: 'Email', value: m.email,
		rules: [ui2.form_required(), ui2.form_email()] },
	ui2.FormValue{ field: 'confirm', label: 'Confirm password', value: m.confirm,
		rules: [ui2.form_equals(m.password).with_message('The passwords do not match.')] },
	ui2.FormValue{ field: 'zip', label: 'ZIP code', value: m.zip,
		rules: [ui2.form_pattern('#####|#####-####')] },
])
// errors == {'email': 'Email is required.', ...}; empty when everything passes.
```

| Rule | Passes when | Default message |
| --- | --- | --- |
| `form_required()` | the value is not blank | `<Label> is required.` |
| `form_min_length(n)`, `form_max_length(n)` | at least / at most n characters (Unicode scalars) | `<Label> must be at least n characters.` |
| `form_email()` | `form_email_valid` (the value trimmed) | `Enter a valid email address.` |
| `form_digits()`, `form_alphanumeric()` | only 0-9 / only ASCII letters and digits | `<Label> can only contain digits.` |
| `form_number(min, max)` | `number_input_parse` reads a number within the optional bounds | `<Label> must be a number from min to max.` |
| `form_pattern(p)` | `form_pattern_matches(value, p)` | `<Label> is not in the expected format.` |
| `form_equals(other)` | the value is `other` | `<Label> does not match.` |

Every rule but `required` passes a blank value, so optional fields are only
checked once something is typed. `.with_message(text)` replaces a rule's
message; `FormRule{...}` with `check: FormCheck` builds one directly.
`form_check(value, label, rules) string` returns the first failure ('' when
valid); `form_validate([]FormValue) map[string]string` maps each failing
field to its first message (a field listed twice keeps its first failure).
Checks of the application's own (a password needing a digit, two fields
together) sit beside these: add them to the map.

`form_email_valid` accepts what people type as an address: one `@`, a local
part of letters, digits and RFC 5322's unquoted symbols with no leading,
trailing or doubled dot, and a domain of at least two labels (letters, digits,
hyphens not at either end, non-ASCII allowed) whose last label is at least two
characters and not all digits. Quoted local parts and IP-literal domains are
refused, and the address is not looked up.

`form_pattern_matches(value, pattern)` matches the whole value: `#` a digit,
`A` an ASCII letter, `*` a letter or digit, `?` any character, `\` makes the
next character literal and `|` separates alternatives. `A#A #A#` accepts
Canadian postal codes, `###-###-####|(###) ###-####` two phone formats.

## Accessibility

The form's view is a `group` named by `accessibility_label`. Required labels
announce "<label>, required", messages carry their text and their icon is
labelled "Error", section titles have the role `heading` and rules
`separator`. Controls without a label of their own get the field's.

## GPUI Kit features

| GPUI Kit | ui2 |
| --- | --- |
| `Form::new()`, `v_form()`, `h_form()`, `layout`, `label_layout(Axis)` | `FormConfig.label_layout` (`.vertical` / `.horizontal`) |
| `columns(n)`, `Field::col_span`, `col_start` | Implemented, with CSS grid's sparse placement |
| `Field::col_end` | Omitted: `col_start` with `col_span` places a field anywhere; an end line would only be a third way to say the same. |
| `label_width`, `label_text_size`, `small()` / `large()` | `label_width`, `label_text_size`, `size` |
| Styled gaps and padding (`gap_x`, `gap_y`, `p`) | `row_gap`, `column_gap`; padding is the frame's position |
| `Field::label`, `required` marker | Implemented |
| `Field::label_fn` (a custom label element) | Omitted: the label is text so the required marker, the tooltip of a cut label and accessibility can derive from it; draw anything richer in the control. |
| `label_indent` | Implemented; also keeps the label row in vertical layouts (see Layout) |
| `description`, `description_fn` | `description`; `description_fn` with `description_height` |
| `visible` | Implemented: hidden fields leave no row behind, as upstream's test requires |
| `items_start` / `items_center` / `items_end` | `align` (`.start`, `.center`, `.end`) |
| `child` / `children` (any element) | `control` closures given the frame to fill |
| `footer` (trailing-aligned content after the fields) | `actions` (submit/reset/button with variants and a decoder) and `actions_align`; other footer content is a full-width field with `label_indent: false` |
| Submit handling (application-owned) | `form_event`, `form_submit_action` for Return, `form_first_error` |
| Validation (left to the application upstream) | Added: rules, `form_check`, `form_validate`, `form_email_valid`, `form_pattern_matches`, `error` messages that color the description |
| Sections in the settings example (labelled separators) | `kind: .section` with title, description and rule |
| Responsive `columns(if is_mobile { 1 } else { 2 })` | `collapse_below` and `form_responsive_columns` |
| Rows sized by flexbox to their content | Rows are as tall as their tallest field; text heights are estimated, since ui2 has no text measurement |

## Platform notes

- On AppKit a text area's border is its layer's, which window captures leave
  out; the gallery puts its text area in a bordered view there so screenshots
  match the custom renderer.

## Attribution

The API follows GPUI Kit's documented form (Longbridge, Apache-2.0); the
layout, building, decoder and validation code is new. Two tests in
`ui/component_form_test.v` (label orientation independent of the columns,
hidden fields leaving no row) are adapted from
`crates/component/src/form/tests.rs`, and the file carries the header. See the
[attribution](../../third_party/gpui-kit/NOTICE.md).

## Verification

```sh
v test ui/component_form_test.v
v -d ui2_custom_rendering test ui/component_form_test.v
v run examples/gpui_form/main.v
v -d ui2_custom_rendering run examples/gpui_form/main.v
UI2_FORM_DARK=1 v run examples/gpui_form/main.v
```

The tests cover grid placement (flow, spans, column starts, holes, clamping,
sections), both label layouts and their independence from columns (upstream's
test), hidden fields, gaps and sizes, label room, horizontal alignment and
label width, descriptions, messages, custom descriptions and reserved lines,
sections, the actions row in every alignment, collapsing, `form_split`,
`form_control_frame`, configuration errors, the built elements (keys, required
markers, messages, read-only values, accessibility labels, growth to the
content), closure errors, `form_field`, every decoded event and rejected
action, `form_first_error`, the text estimates, every validation rule and
message, email shapes and patterns.
