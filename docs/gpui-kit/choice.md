# Choice components

Ports of GPUI Kit's [radio](https://github.com/longbridge/gpui-kit/blob/main/website/component/radio.md),
[rating](https://github.com/longbridge/gpui-kit/blob/main/website/component/rating.md),
[toggle](https://github.com/longbridge/gpui-kit/blob/main/website/component/toggle.md),
[button group and button variants](https://github.com/longbridge/gpui-kit/blob/main/website/component/button.md)
and [stepper](https://github.com/longbridge/gpui-kit/blob/main/website/component/stepper.md).
The implementation is in `ui/component_choice.v` (shared helpers, buttons,
toggles), `ui/component_choice_radio.v`, `ui/component_choice_rating.v` and
`ui/component_choice_stepper.v`; `examples/gpui_choice/main.v` shows every
component and variant.

## Conventions

- Every builder takes a config struct and returns `!Element`. The frame must be
  finite and non-negative, child frames are parent-local, and interactive
  components need a non-empty `id`.
- State is controlled. A component never changes itself: it emits an action,
  the application decodes it with the component's decoder, stores the result
  and rebuilds. Every decoder takes **the same config the component was built
  with**, so build one config from the model and use it in both places:

  ```v
  fn plan_config(m &Model) ui2.RadioGroupConfig {
      return ui2.RadioGroupConfig{
          id:       'plan'
          frame:    ui2.rect(20, 20, 300, 120)
          selected: m.plan
          options:  [ui2.RadioOption{ value: 'free', label: 'Free' },
              ui2.RadioOption{ value: 'pro', label: 'Pro' }]
      }
  }

  // build:    ui2.radio_group(plan_config(m)) or { panic(err) }
  // on_event: if value := ui2.radio_group_value_from_action(plan_config(m), action) {
  //               m.plan = value
  //           }
  ```

  Decoders return `none` for actions that belong to something else, forged or
  malformed actions, disabled components or items, and actions that would not
  change anything (selecting the selected option, clicking the current step).
- Items in radio groups, toggle groups and button groups have a `value`: the
  stable key the decoder returns. It defaults to the label and must be unique
  and non-empty. Element ids and actions are
  `${id}:component:<kind>:<hex of value>`, so an item keeps its identity when the
  list is reordered; `radio_group_action_id`, `toggle_group_action_id`,
  `button_group_action_id`, `rating_action_id` and `stepper_action_id` build them.
- `size` is `ComponentSize` (`.small`, `.medium`, `.large`) and colors come from
  `ComponentTheme`; pass `component_theme(dark)` to follow the app's theme.
- `icon` fields take an SF Symbol name drawn as a `symbol:` image tinted like the
  text. Use names `symbol_known` accepts, so every renderer draws the same icon.
- Components cannot capture keys. Each has a pure key helper
  (`radio_group_value_after_key`, `rating_value_after_key`,
  `stepper_step_after_key`) to call from `on_key_event` while the application
  considers the component focused.
- Clickable parts are views with button behavior, not native buttons: a native
  button dims its title when disabled and centers one line, and these parts need
  their own selected, pressed and disabled colors, icons beside captions, and
  multi-line content. Rounded borders are drawn as a border-colored shape under
  an inset fill, because a `BoxStyle` border is square-cornered in the custom
  renderer and clipped at the corners by AppKit.

## Radio

```v
ui2.radio_group(
    id:          'payment'
    frame:       ui2.rect(20, 20, 360, 140)
    selected:    m.payment
    orientation: .vertical // or .horizontal, which wraps onto new rows
    options:     [
        ui2.RadioOption{ value: 'card', label: 'Credit card', description: 'Visa, Mastercard' },
        ui2.RadioOption{ value: 'bank', label: 'Bank transfer', enabled: false },
    ]
) or { panic(err) }

if value := ui2.radio_group_value_from_action(config, action) { m.payment = value }
if value := ui2.radio_group_value_after_key(config, event.code) { m.payment = value }

ui2.radio(id: 'terms', label: 'I accept the terms', checked: m.terms, frame: frame) or { panic(err) }
if _ := ui2.radio_checked_from_action(terms_config, action) { m.terms = true }
```

API: `RadioOption{value, label, description, enabled}`,
`RadioGroupConfig{id, frame, options, selected, orientation, enabled,
accessibility_label, size, theme}`, `radio_group`, `radio_group_value_from_action`,
`radio_group_value_after_key`, `radio_group_action_id`;
`RadioConfig{id, frame, label, description, checked, enabled, action_id,
accessibility_label, size, theme}`, `radio`, `radio_checked_from_action`.

Implemented: single radio and group; labels and descriptions (wrapped to at most
three lines from an estimate of their width); per-option and whole-group
disabling; vertical and horizontal (wrapping) layout; the controlled selection;
sizes; arrow/Home/End navigation that wraps and skips disabled options, as in a
native radio group. A radio cannot uncheck itself, as upstream. The group has
role `radiogroup` and each option role `radio` with value `checked`/`unchecked`.

Omitted: arbitrary child elements inside a radio (descriptions cover the
documented use); tab order and focus rings (no portable focus API); tooltips
(wrap the element with `with_tooltip`). Upstream draws a check inside the
filled circle; this port draws the conventional inner dot.

## Rating

```v
ui2.rating(id: 'stars', frame: ui2.rect(20, 20, ui2.rating_width(5, .medium), 26), value: m.stars) or { panic(err) }
if value := ui2.rating_value_from_action(config, action) { m.stars = value }
ui2.rating(value: 4, readonly: true, tone: .success, size: .small, frame: frame) or { panic(err) }
```

API: `RatingConfig{id, frame, value, max = 5, enabled, readonly, tone = .warning,
size, theme}`, `rating`, `rating_value_from_action`, `rating_value_after_key`,
`rating_value_after_click`, `rating_width`, `rating_action_id`,
`rating_max_stars` (50).

Click rule, as upstream: clicking an empty star fills up to it; clicking a
filled star sets the rating to the star before it. Re-selecting the current
value therefore lowers it by one rather than clearing it, and clicking the first
star of a non-empty rating clears it. `rating_value_after_click(value, star)` exposes the
rule. Keys: right/up and left/down step by one, Home clears, End fills, a digit
sets that many stars.

Implemented: any maximum from 1 to 50, value clamped to `0..max`, sizes, the
filled color from a theme tone (upstream's default is the theme's yellow, here
`.warning`), `readonly` (display only, full color, role `img`) and disabled
(display only, dimmed). Empty stars use the theme's border color so filled and
empty stay distinct in both themes.

Omitted: hover preview (ui2 has no hover state for composed views) and an
arbitrary color (pick a `ComponentTone`). Stars are a filled `★` on Apple
backends and the `star` symbol (a filled Material glyph) elsewhere: SF Symbols'
`star` is an outline and the custom renderer's ★ is half size.

## Toggle and toggle group

```v
ui2.toggle(id: 'bold', label: 'Bold', icon: 'textformat', pressed: m.bold, frame: frame) or { panic(err) }
if pressed := ui2.toggle_pressed_from_action(bold_config, action) { m.bold = pressed }

ui2.toggle_group(
    id:          'period'
    frame:       ui2.rect(20, 60, 360, 32)
    items:       [ui2.ToggleItem{ value: 'day', label: 'Day' }, ui2.ToggleItem{ value: 'week', label: 'Week' }]
    selected:    m.period // []string
    multiple:    false
    allow_empty: false
    segmented:   true
    variant:     .outline
) or { panic(err) }
if selection := ui2.toggle_group_selection_from_action(config, action) { m.period = selection }
```

API: `ToggleVariant` (`.ghost`, the default, and `.outline`),
`ToggleConfig{id, frame, label, icon, pressed, enabled, action_id,
accessibility_label, variant, size, theme}`, `toggle`,
`toggle_pressed_from_action`; `ToggleItem{value, label, icon, enabled,
accessibility_label}`, `ToggleGroupConfig{id, frame, items, selected, multiple =
true, allow_empty = true, segmented, fill, enabled, accessibility_label, variant,
size, theme}`, `toggle_group`, `toggle_group_selection_from_action`,
`toggle_group_action_id`.

Implemented: label, icon, or both; pressed state; ghost and outline variants;
sizes; disabled toggles and items; groups with multiple selection (upstream's
behavior) or single selection (upstream suggests keeping that in the model; here
it is `multiple: false`), optionally refusing to release the last pressed item;
segmented groups that join their items (outline items share one border, ghost
items touch); packing at estimated widths or `fill`ing the frame. The decoder
returns the new selection in item order. Toggles have role `button` with value
`pressed`/`released`, like ui2's `toggle_button`.

Why not ui2's `toggle_button` kind: it keeps a live pressed state in the backend
and flips it before the action arrives, and backend groups enforce exclusivity
on their own. That is right for an uncontrolled control, but here the
application decides (a disabled item, `allow_empty: false`, a selection it
rejects), and a declaration that does not change is not reapplied, so the
backend's state would drift from the model. A composed view draws exactly what
the config says.

Omitted: hover styling and tooltips (use `with_tooltip`), a gap option for
segmented groups (use a non-segmented group).

## Button group and button variants

```v
ui2.button_group(
    id:      'range'
    frame:   ui2.rect(20, 20, 280, 32)
    variant: .primary
    outline: true
    items:   ['day', 'week', 'month'].map(ui2.ButtonGroupItem{ value: it, label: it.capitalize(), selected: m.range == it })
) or { panic(err) }
if value := ui2.button_group_value_from_action(config, action) { m.range = value }

ui2.styled_button(id: 'save', label: 'Save', variant: .primary, frame: frame) or { panic(err) }
```

API: `ButtonVariant` (`.secondary`, the default, `.primary`, `.danger`,
`.success`, `.warning`, `.ghost`), `ButtonVariantColors`,
`button_variant_colors(theme, variant, outline, selected, enabled)`;
`ButtonGroupItem{value, label, icon, action_id, selected, enabled,
accessibility_label}`, `ButtonGroupConfig{id, frame, items, orientation, variant,
outline, fill, enabled, accessibility_label, size, theme}`, `button_group`,
`button_group_value_from_action`, `button_group_action_id`;
`StyledButtonConfig{id, frame, label, icon, action_id, variant, outline,
selected, enabled, accessibility_label, size, theme}`, `styled_button`,
`styled_button_width`.

Implemented: attached buttons that share their borders, with only the group's
outer corners rounded; horizontal and vertical groups; every variant with
`outline` combinable, as upstream; divider lines between solid buttons; sizes;
selected and disabled buttons and groups; icons; per-item custom actions. Each
button emits its own action and `selected` only changes its look, so the
application implements single or multiple selection (see the gallery's
"Selected" and "Ghost" rows, or use `toggle_group`). Outline text in a light
tone (the warning yellow) is darkened until it reads at 4.5:1.

`styled_button` exists because the variants are not all expressible with ui2's
`button`: solid colors are, but an outline button's border is square-cornered
in the custom renderer, while this composite looks the same everywhere. Size a
frame with `styled_button_width`.

Omitted: `info` (ComponentTheme has no info color), `link` (ui2 has `link`) and
`text` variants; custom variants (use `button_variant_colors` or plain
`button`); `compact`; loading spinners and progress icons; dropdown carets;
hover and active colors (no hover state for composed views); tooltips (use
`with_tooltip`).

## Stepper

```v
ui2.stepper(
    id:      'wizard'
    frame:   ui2.rect(20, 20, 600, 72)
    current: m.step // items.len marks every step completed
    items:   [ui2.StepperItem{ title: 'Account', description: 'Name and email' },
        ui2.StepperItem{ title: 'Payment', icon: 'lock', enabled: false }]
) or { panic(err) }
if step := ui2.stepper_step_from_action(config, action) { m.step = step }
next := ui2.stepper_next_step(config) or { m.step }
```

API: `StepperItem{title, description, icon, enabled}`, `StepperConfig{id, frame,
items, current, orientation, clickable = true, enabled, text_center, size,
theme}`, `StepperStepState` and `stepper_step_state(index, current)`, `stepper`,
`stepper_step_from_action`, `stepper_next_step`, `stepper_previous_step`,
`stepper_step_after_key`, `stepper_action_id`.

Implemented: completed steps (primary circle with a check), the current step
(primary circle with its number, bold title) and upcoming steps (muted), or the
item's icon in every state, as upstream; connecting lines that take the primary
color once passed; titles and descriptions; horizontal (the last step only
takes the room its text needs, as upstream) and vertical layout (the rest of the
frame goes between the steps); `text_center`; sizes; disabled steppers and
steps; clickable steps or a display-only stepper (`clickable: false`, which
needs no id). Next/previous helpers skip disabled steps. The stepper has role
`list`; steps are buttons with value `completed`/`current`/`upcoming`, or
`listitem`s when not clickable.

Omitted: arbitrary child elements per step (title and description cover the
documented examples) and `text_center` for vertical steppers.

## Attribution

The rating click rule (`rating_value_after_click`) is adapted from
`crates/component/src/rating.rs` of GPUI Kit (Longbridge, Apache-2.0); see the
[attribution](../../third_party/gpui-kit/NOTICE.md). Everything else in this
group is a new implementation of the documented concepts.

## Verification

```sh
v test ui/component_choice_test.v
v -d ui2_custom_rendering test ui/component_choice_test.v
v run examples/gpui_choice/main.v
v -d ui2_custom_rendering run examples/gpui_choice/main.v
```
