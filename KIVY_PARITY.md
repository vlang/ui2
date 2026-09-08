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
