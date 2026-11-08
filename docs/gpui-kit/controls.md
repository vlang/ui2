# Slider, switch and checkbox

An audit of ui2's existing `slider`, `switch_control` and `checkbox` against GPUI
Kit's [slider](https://github.com/longbridge/gpui-kit/blob/main/website/component/slider.md),
[switch](https://github.com/longbridge/gpui-kit/blob/main/website/component/switch.md)
and [checkbox](https://github.com/longbridge/gpui-kit/blob/main/website/component/checkbox.md),
and the components that close the gaps.

ui2's three controls are platform controls: AppKit draws an `NSSlider`, an
`NSSwitch` and an `NSButton` checkbox whatever the theme, UIKit and Win32 their
own, and the custom renderer a fixed design. None of them can show a label and
description beside a switch, an indeterminate mark, a second thumb, marks or a
value bubble. They are kept unchanged (two fields were added to the slider and
switch configs), and drawn components follow GPUI Kit on every backend:

| GPUI Kit | Platform control | Drawn component |
| --- | --- | --- |
| `Slider` | `slider` (`ui/slider.v`) | `styled_slider` (`ui/component_controls_slider.v`) |
| `Switch` | `switch_control` (`ui/switch.v`) | `styled_switch` (`ui/component_controls_switch.v`) |
| `Checkbox` | `checkbox` (`ui/ui.v`) | `styled_checkbox`, `checkbox_group` (`ui/component_controls.v`) |

`examples/gpui_controls/main.v` shows every variant next to the platform
controls, with a light/dark toggle and keyboard focus driven by Tab.

## Conventions

- Builders take a config struct and return `!Element`: the frame must be finite
  and non-negative, child frames are parent-local, and the id is required.
- State is controlled. A component emits an action (the slider also pointer
  events), the application decodes it with the component's decoder **against
  the same config it built with**, stores the result and rebuilds.
- Colors come from `ComponentTheme` (`component_theme(dark)`), sizes from
  `ComponentSize`.
- Components cannot take keyboard focus. Each has a `focused` field that draws
  GPUI Kit's focus ring (half the accent over the background) and a key helper to
  call from `on_key_event` while the application routes keys to it; the gallery
  moves focus with Tab and Shift+Tab.
- Rings and bubbles stay inside the frame: components keep 2 units around a
  checkbox box or switch track and 3 past a slider thumb's center at each end.

## Slider

```v
fn price_config(m &Model) ui2.StyledSliderConfig {
    return ui2.StyledSliderConfig{
        id:           'price'
        frame:        ui2.rect(20, 40, 320, 64)
        max:          1000
        step:         10
        range:        true
        start:        m.low
        end:          m.high
        value_label:  .always
        value_prefix: '$'
        marks:        [ui2.SliderMark{ value: 0, label: '$0' },
            ui2.SliderMark{ value: 1000, label: '$1000' }]
        focused:      m.focus == 'price'
        active:       m.thumb
    }
}

// on_event:
if change := ui2.styled_slider_change(price_config(m), action) {
    m.low, m.high = change.start, change.end
    m.focus, m.thumb = 'price', change.thumb
    if change.done { save() } // GPUI Kit's SliderEvent::Release
}
// on_key_event:
if change := ui2.styled_slider_change_after_key(price_config(m), event) { ... }
```

API: `StyledSliderConfig{id, frame, origin_x, origin_y, min, max = 100, step = 1,
value, range, start, end, scale, orientation, reverse, marks, snap_to_marks,
value_label, focused, active, enabled, color, thumb_color, decimals = -1,
value_prefix, value_suffix, accessibility_label = 'Slider', size, theme}`;
`styled_slider`, `styled_slider_change`, `styled_slider_change_after_key`,
`styled_slider_value_text`, `styled_slider_thickness`, `slider_step_marks`,
`styled_slider_thumb_id`, `styled_slider_track_id`;
`SliderChange{thumb, value, start, end, done}`; `SliderScale` (`linear`,
`logarithmic`), `SliderThumb` (`value`, `start`, `end`), `SliderValueLabel`
(`hidden`, `active`, `always`), `SliderMark{value, label}`;
`slider_scale_fraction`, `slider_scale_value`.

The track and the thumbs are draggable views. Pointer events carry window
coordinates, so a slider that is not a direct child of the screen sets
`origin_x`/`origin_y` to the window position of its parent (as the color picker
does). A press on the track moves the nearest thumb there; a press on a thumb
only reports it and a drag moves it; a focused range keeps moving its active
thumb through a drag that began on the track. Presses and releases are always
reported, drags that change nothing are not.

`styled_slider_thickness(config)` is the natural height of a horizontal slider
(the width of a vertical one) including the bubble and mark labels it shows.
`slider_step_marks(config, every, labelled)` builds tick marks.

| Upstream feature | Status |
| --- | --- |
| Single value, `min`/`max`/`step`/`default_value` | Implemented (`value`, `step` defaults to 1 as upstream; 0 is continuous). Values snap to `min + k * step` and are rounded to the step's decimals. Already present in `slider`. |
| Range (`SliderValue::Range`, two thumbs) | Implemented: `range`, `start`, `end`; the start never passes the end. |
| Vertical (`.vertical()`, min at the bottom) | Implemented. Already present in `slider` (`orientation`). |
| Disabled | Implemented: dimmed track, fill and thumbs, no events. Upstream hides the thumbs of a disabled slider; ui2 keeps them dimmed so the value stays visible. `slider` gained `enabled`. |
| Logarithmic scale (`SliderScale`) | Implemented, with upstream's formula `min * (max / min)^p`; `min` must be above zero. |
| `reverse()` fill | Implemented (`reverse`); ignored for ranges, as upstream. |
| Custom styling (`bg`, `text_color`) | Implemented as `color` (track fill and thumb ring) and `thumb_color`. Corner radii are always round. `slider` keeps `SliderStyle`. |
| `accessibility_label` | Implemented. Thumbs have role `slider` with the formatted value; range thumbs are named `<label> minimum` and `<label> maximum`. `slider` gained `accessibility_label`. |
| Change and Release events | Implemented: `SliderChange.done` marks the release (and key changes, which are complete at once). |
| Keyboard: arrows, Page Up/Down, Home/End | Implemented (`styled_slider_change_after_key`, and `slider_value_after_key` for the platform slider): a step (ten with Shift), a tenth of the range rounded to whole steps, the ends. A logarithmic slider moves by 1% (10%) of its track. Tab is the application's (the gallery cycles focus). |
| Hover ring around a thumb | Adapted: the ring is drawn around the active thumb while `focused`, rather than on hover. |
| Marks / ticks (task requirement, not upstream) | Implemented: `marks` draw dots on the track, filled-side dots in a contrasting color, and optional labels under (or beside) it; `snap_to_marks` restricts values and keys to the marks. |
| Value tooltip (task requirement, not upstream) | Implemented: `value_label: .active` shows a bubble over the active thumb while focused, `.always` over every thumb, merging a range's two bubbles when they would overlap. `decimals`, `value_prefix` and `value_suffix` format it. |
| Sizes (task requirement; upstream sizes the slider with `Styled`) | Implemented: small 4/12, medium 6/16 (upstream's), large 8/20 track/thumb. |
| Arbitrary `Styled` sizing (`w`, `h`, `flex_1`) | Omitted: the frame is the size. |
| Touch drag handling | Already present: ui2's draggable views report touch drags as pointer drags. |

## Switch

```v
ui2.styled_switch(
    id:          'notify'
    frame:       ui2.rect(20, 20, 320, 44)
    checked:     m.notify
    label:       'Notifications'
    description: 'Show alerts, play sounds and badge the app icon.'
) or { panic(err) }

if checked := ui2.styled_switch_checked_from_action(config, action) { m.notify = checked }
if checked := ui2.styled_switch_checked_after_key(config, event) { m.notify = checked }
```

API: `StyledSwitchConfig{id, frame, checked, label, description, label_side,
enabled, loading, color, tooltip, focused, reduce_motion, action_id,
accessibility_label, size, theme}`; `styled_switch`,
`styled_switch_checked_from_action`, `styled_switch_checked_after_key`,
`styled_switch_width`, `styled_switch_height`, `styled_switch_thumb_x`;
`SwitchLabelSide` (`right`, `left`).

| Upstream feature | Status |
| --- | --- |
| `checked`, `on_change` (controlled) | Implemented: the whole row, label included, is clickable; the decoder returns the requested value. Already present in `switch_control` (`active`, action, `switch_active`). |
| `label` | Implemented; the label wraps (up to three lines) and the track keeps its size, as upstream's narrow-container test requires. |
| Description (task requirement; upstream composes it in its settings example) | Implemented: muted text under the label, wrapping up to four lines. |
| `label_side(Side::Left)` | Implemented: `label_side: .left` puts the label first and the track at the right edge of the frame, for settings rows. |
| Sizes `small`/`medium`/`large` | Implemented with upstream's 28x16, 36x20 and 44x24 tracks and 12, 16, 20 thumbs inset by 2. |
| Disabled | Implemented: the track fades to half strength and the thumb stays, as upstream. `switch_control` gained `enabled` (its `SwitchStyle` already had disabled colors). |
| `color` (checked track) | Implemented; the thumb takes the theme's light or dark end, whichever contrasts more with it. Disabled keeps the color at half strength. |
| `tooltip` | Implemented (on the row). Already available for every element through `with_tooltip`. |
| Focus ring, `focus_ring(false)` | Implemented as `focused` (the application decides; no ring unless set). |
| `tab_stop`, `tab_index` | Omitted: ui2 has no portable focus order for drawn views; the application routes keys. |
| Enter/Space activation | Implemented (`styled_switch_checked_after_key`). |
| `accessibility_label` | Implemented; defaults to the label. Role `switch`, value `on`/`off`. `switch_control` gained `accessibility_label`. |
| 150 ms thumb animation | Implemented: the thumb slides with ui2's animation runtime (`out_cubic`, 0.15 s) and reverses from where it is when toggled mid-slide; `reduce_motion` moves it at once. |
| Loading (task requirement, not upstream) | Implemented: `loading` shows a spinner in the thumb, ignores clicks and keys, and reports `on, busy`/`off, busy`. |
| `w`/`h` styling | Omitted: the frame is the size; `styled_switch_width` gives the natural width. |

## Checkbox

```v
ui2.styled_checkbox(
    id:            'all'
    frame:         ui2.rect(20, 20, 300, 24)
    label:         'Select all'
    checked:       m.all
    indeterminate: m.some
) or { panic(err) }

if checked := ui2.styled_checkbox_checked_from_action(config, action) { m.all = checked }
```

API: `StyledCheckboxConfig{id, frame, label, description, checked,
indeterminate, enabled, focused, tooltip, action_id, accessibility_label, size,
theme}`; `styled_checkbox`, `styled_checkbox_checked_from_action`,
`styled_checkbox_checked_after_key`, `styled_checkbox_width`,
`styled_checkbox_height`.

| Upstream feature | Status |
| --- | --- |
| `label`, `checked`, `on_change` (controlled) | Implemented; the whole row is clickable. Already present in `checkbox` (native title and state). |
| Description / custom children | Implemented as `description` (muted, wrapping up to four lines; the label wraps up to three). Arbitrary child elements are omitted. |
| Indeterminate (base `CheckboxState::Indeterminate`) | Implemented: a dash, value `mixed`, and activation checks the box, as upstream. |
| Sizes (`text_xs`/`text_sm`/base/`text_lg`) | Implemented for small, medium and large: 14, 16 and 18 unit boxes (upstream's 0.875, 1 and 1.125 rem) with 12, 14 and 16 point labels. Upstream's extra-small has no `ComponentSize`. |
| Disabled | Implemented: box and mark at half strength, muted label. The native `checkbox` can be disabled through `Element.enabled`. |
| Without a label | Implemented; set `accessibility_label`. |
| Tooltip | Implemented (`tooltip`). |
| Focus ring, Enter/Space | Implemented (`focused`, `styled_checkbox_checked_after_key`). Upstream's checkbox does not take focus on a press; the gallery follows that. |
| `tab_stop`, `tab_index`, `role` override | Omitted (no portable focus order; the role is always `checkbox`). |
| Check mark fade animation | Omitted: the mark appears at once. |
| Checkbox list (upstream example) | Implemented as `checkbox_group`, below. |

The box and mark are drawn by ui2, not the platform: a rounded box (border under
an inset fill, as the choice components draw rings) and the check or dash as a
stroked vector path, so they scale with the size and look the same everywhere.

## Checkbox group

```v
ui2.checkbox_group(
    id:         'notify'
    frame:      ui2.rect(20, 20, 300, ui2.checkbox_group_height(config))
    select_all: 'All notifications'
    selected:   m.channels
    options:    [ui2.CheckboxOption{ value: 'mail', label: 'Email', description: 'Daily digest' },
        ui2.CheckboxOption{ value: 'sms', label: 'Text messages', enabled: false }]
) or { panic(err) }

if selection := ui2.checkbox_group_selection_from_action(config, action) { m.channels = selection }
```

API: `CheckboxOption{value, label, description, enabled}`,
`CheckboxGroupConfig{id, frame, options, selected, orientation, select_all,
enabled, accessibility_label, size, theme}`; `checkbox_group`,
`checkbox_group_selection_from_action`, `checkbox_group_height`,
`checkbox_group_action_id`, `checkbox_group_select_all_action_id`.

Options are laid out vertically or left to right, wrapping onto new rows. Values
default to labels and must be unique; ids and actions are
`${id}:component:option:<hex of value>`, so an option keeps its identity when
reordered. The optional select-all checkbox is checked when every enabled option
is, indeterminate when some selected value is, and toggles every enabled option
(disabled ones keep their state); in a vertical group the options are indented
under it. The decoder returns the selection in option order and drops values that
are not options. The group has role `group` and lists the selected labels as its
value.

## Platform controls

The existing APIs are unchanged and every existing example builds as before.
Additions:

- `SliderConfig.enabled` (default true) and `SliderConfig.accessibility_label`
  (default `Slider`); `slider_value_after_key(config, event) ?f64` drives a
  slider from the keyboard with the same keys as `styled_slider`.
- `SwitchConfig.enabled` (default true) and `SwitchConfig.accessibility_label`
  (default `Switch`).
- `ui/slider_test.v` had an expression (`- -50`) the current V parser rejects;
  it is now `+ 50`.

## Attribution

The documented API concepts are GPUI Kit's (Longbridge, Apache-2.0): the switch
and checkbox sizes, the logarithmic formula, the nearest-thumb rule, the
indeterminate-becomes-checked activation. No upstream code was adapted; the
implementations are new.

## Verification

```sh
v test ui/component_controls_test.v ui/slider_test.v ui/switch_test.v
v -d ui2_custom_rendering test ui/component_controls_test.v
v run examples/gpui_controls/main.v
v -d ui2_custom_rendering run examples/gpui_controls/main.v
```
