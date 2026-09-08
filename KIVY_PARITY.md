# Kivy compatibility

UI2 is gradually adopting useful concepts and widgets from
[Kivy](https://kivy.org/doc/stable/api-kivy.uix.html). The goal is consistent
behavior in UI2's V and QML APIs on every backend, not Python/KV source
compatibility or a copy of Kivy's default theme.

## ProgressBar

`ProgressBar` follows Kivy's horizontal, display-only behavior. `max` defaults
to 100, and `value` is clamped to `0...max`.

```qml
ProgressBar {
    id: download
    value: app.downloaded
    max: app.total
    background: #E2E8F0
    color: #2563EB
    corner_radius: 6
}
```

The equivalent V API is `progress_bar(ProgressBarConfig{...})`:

```v
bar := ui2.progress_bar(
	id: 'download'
	frame: ui2.rect(20, 20, 240, 12)
	value: downloaded
	max: total
	background: 0xe2e8f0
	color: 0x2563eb
	radius: 6
)
```

Use `progress_bar_value_normalized(value, max)` when application logic also
needs the normalized `0...1` value. A non-positive maximum produces an empty
bar instead of dividing by zero. The generated element supplies progress-bar
accessibility metadata, which can be overridden with QML's shared
`accessibility_role`, `accessibility_label`, and `accessibility_value`
properties.

## Slider

`Slider` supports horizontal and vertical orientation, arbitrary numeric
`min`/`max` ranges, optional `step` snapping, configurable track and thumb
styling, and an optional colored value track. Vertical sliders place the
minimum at the bottom and maximum at the top.

```qml
Slider {
    id: volume
    bind.value: app.volume
    min: 0
    max: 100
    step: 5
    value_track: true
    on_change: app.volume_changed()
}
```

The V constructor is `slider(SliderConfig{...})`. A stable `id` lets event
handlers read the live value with `slider_value(id)` or update it with
`set_slider_value(id, value)`. The QML model adapter supports two-way numeric
`bind.value` fields of type `int`, `f32`, or `f64`.

## Switch

`Switch` is a reusable boolean control with tap and horizontal-drag input. Its
entire frame is interactive, while the switch chrome is centered inside it.
Native backends use their platform toggle controls where available; the custom
renderer provides matching pill-and-thumb geometry and configurable colors.

```qml
Switch {
    id: notifications
    bind.active: app.notifications_enabled
    on_active: app.save_preferences()
    active_color: #16A34A
    inactive_color: #CBD5E1
    thumb_color: #FFFFFF
}
```

The V constructor is `switch_control(SwitchConfig{...})`. A stable `id` lets
event handlers read the newly selected state with `switch_active(id)` or update
it with `set_switch_active(id, active)`. QML's `active` property defaults to
`false`, and `bind.active` accepts mutable `bool` model fields.
