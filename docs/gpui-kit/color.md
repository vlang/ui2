# Color picker

A port of GPUI Kit's
[color picker](https://github.com/longbridge/gpui-kit/blob/main/website/component/color-picker.md)
(`ColorPicker` and `ColorSelect`), with the saturation and brightness area,
hue slider and alpha slider most color pickers have. The implementation is in
`ui/component_color_model.v` (the color model and conversions),
`ui/component_color.v` (configuration, layout and decoders),
`ui/component_color_view.v` (the panel) and `ui/component_color_trigger.v`
(the triggers and the popover). `examples/gpui_color/main.v` shows every
variant with working state handling, and `ui/component_color_test.v` covers
the logic.

## Conventions

- `color_picker(config) !Element` builds the picker. The frame must be finite
  and non-negative, child frames are parent-local, and the picker needs a
  non-empty `id`.
- State is controlled. The application stores the color (and, for the popover
  variants, whether the popover is open, the current tab, the hex text being
  typed and the swatch being previewed) and rebuilds. `color_picker_event`
  decodes everything the picker emits against **the config it was built
  with**, so build the config from the model in one function and use it in
  both places.
- Keep the color as a `ColorHsva`, not as `0xRRGGBB`. A gray has no hue and
  black no saturation, so a picker whose state went through RGB would lose the
  hue slider's position as soon as the area's thumb reached its left or bottom
  edge.
- Pointer events carry **window coordinates**. The picker maps them onto its
  area and sliders from the config, so the config must say where the picker is
  in the window: `frame` is parent-local as everywhere else, and
  `origin_x`/`origin_y` is the window position of that parent (zero for a child
  of the screen). A popover is placed in window coordinates and must be a child
  of the screen; give it `window: ui2.bounds()`.
- Components cannot capture keys. `color_picker_value_after_key` nudges a part
  with the arrow keys and `color_picker_dismiss_on_key` recognizes Escape; call
  them from `on_key_event`.

## Color model

```v
brand := ui2.color_from_rgb(0x3366ff)      // or color_from_hex('#36f') or { ... }
brand.hex()                                // '#3366FF'
brand.with_alpha(0.5).hex()                // '#3366FF80'
brand.css_rgb()                            // 'rgb(51, 102, 255)'
brand.css_hsl()                            // 'hsl(225, 100%, 60%)'
brand.hsla()                               // ColorHsla{h: 225, s: 1, l: 0.6, a: 1}
ui2.color_from_hsla(225, 1, 0.6, 1).rgb()  // 0x3366ff, for BoxStyle.bg
```

| Type or function | Purpose |
| --- | --- |
| `ColorHsva{h, s, v, a}` | Hue in degrees (0 to 360; 360 is kept so a hue slider can sit at its end), saturation, value and alpha from 0 to 1. The picker's value. |
| `ColorHsla{h, s, l, a}`, `ColorRgba{r, g, b, a}` | The same color as HSL, and as 8-bit channels with an alpha. |
| `color_hsva(h, s, v, a)`, `c.normalized()` | Wraps the hue into 0..360 (370 is 10, -30 is 330) and clamps the rest; NaN becomes 0, or 1 for the alpha. |
| `color_from_rgb(rgb)`, `color_from_rgba(rgb, alpha)`, `color_from_hsla(h, s, l, a)`, `color_from_hex(text) ?ColorHsva` | Into the model. A gray gets hue 0. |
| `c.rgb() u32`, `c.rgba()`, `c.hsla()`, `l.hsva()`, `rgba.rgb()` | Out of the model, rounding channels to the nearest byte. |
| `c.with_rgba(rgba)` | The color the channels name, keeping this color's hue for a gray and its saturation for black, and unchanged when the channels round to its own. |
| `c.with_alpha(a)`, `c.same_rgb(other)` | |
| `color_hex(rgb, alpha)`, `c.hex()` | `#RRGGBB`, or `#RRGGBBAA` while the alpha rounds below 255. The alpha is rounded, so 0.5 is `80` and parses back to the same byte. |
| `color_parse_hex(text) ?ColorRgba` | `#rgb`, `#rgba`, `#rrggbb` and `#rrggbbaa`, with or without `#`, surrounding spaces allowed; a single digit repeats (`#fff` is white). Anything else, signs included, is none. |
| `c.css_rgb()`, `c.css_hsl()` | `rgb(...)`/`rgba(...)` and `hsl(...)`/`hsla(...)`, components rounded. |
| `color_contrast_foreground(rgb)` | Black or white, whichever contrasts more: for marks drawn on a color. |
| `color_default_palettes() []ColorPalette`, `color_default_featured() []u32` | The built-in palette (nine families of eleven shades, light to dark) and featured row. |

HSL has no saturation at black and white. `hsla()` reports the HSV saturation
for black, and `hsva()` gives it back, so dragging the lightness slider to 0 and
back keeps the saturation. White has none to keep.

## Color picker

```v
fn brand_config(m &Model) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		id:       'brand'
		frame:    ui2.rect(24, 24, 288, 0) // zero height: color_picker_height
		value:    m.brand
		hex_text: m.brand_hex // ?string: what the user is typing, if anything
		preview:  m.brand_preview
		panel:    m.brand_panel
		theme:    theme
	}
}

// build:
ui2.color_picker(brand_config(m)) or { panic(err) }

// on_event:
config := brand_config(m)
if event := ui2.color_picker_event(config, action) {
	match event.kind {
		.change, .select {
			m.brand = event.value
			m.brand_hex = none
		}
		.hex_change {
			typed := ui2.text(ui2.color_picker_hex_field_id('brand'))
			m.brand_hex = typed
			m.brand = ui2.color_picker_hex_value(config, typed) or { m.brand }
		}
		.hex_submit {
			typed := ui2.text(ui2.color_picker_hex_field_id('brand'))
			m.brand = ui2.color_picker_hex_value(config, typed) or { m.brand }
			m.brand_hex = none
		}
		.preview { m.brand_preview = event.value }
		.preview_end { m.brand_preview = none }
		.panel { m.brand_panel = event.panel }
		.toggle, .dismiss {}
	}
	m.brand_open = event.open // for the popover variants
}
```

The popover variants put a trigger in the layout and the panel in an overlay:

```v
fn tint_config(m &Model) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		...brand_config(m)
		id:      'tint'
		frame:   ui2.rect(24, 400, 240, 32)
		variant: .field // or .swatch, with `label` and optionally `icon`
		open:    m.tint_open
		window:  ui2.bounds()
	}
}

// build: the trigger where it belongs, the popover last among the screen's children
children << ui2.color_picker(tint_config(m)) or { panic(err) }
// ...
children << ui2.color_picker_popover(tint_config(m)) or { panic(err) }
```

### Variants and panels

- `variant: .inline` (default) draws the panel at `frame`. A zero frame
  height takes `color_picker_height(config)`.
- `variant: .swatch` is GPUI Kit's `ColorPicker` button: a square of the
  color (over a checkerboard while it is translucent) followed by `label`, or
  an `icon` with a bar of the color under it. Its tooltip is the hex value.
- `variant: .field` is GPUI Kit's `ColorSelect`: a framed field with a
  swatch, the hex value (or `placeholder` while `empty`) and a caret. The whole
  field is the trigger.
- The panel has up to three tabs, listed in `panels`; with one (or none) the
  tab bar is hidden. The panel is as tall as its tallest tab, so switching tabs
  neither resizes it nor moves a popover.
  - `.spectrum`: the saturation and brightness area (saturation along x, HSV
    value along y), the hue slider, the alpha slider and the first row of
    featured colors.
  - `.palette`: every featured color, then the palette families, as GPUI Kit's
    Palette tab.
  - `.sliders`: hue, saturation, lightness and alpha sliders with their
    values, as GPUI Kit's HSLA tab (titled HSL without alpha).
- Below every tab: a preview of the color (the previewed swatch while the
  pointer is on one) and the hex field.

### `ColorPickerConfig`

| Field | Meaning |
| --- | --- |
| `id`, `frame`, `size`, `theme` | As for every component. `frame` is the panel (inline) or the trigger. |
| `origin_x`, `origin_y` | Window position of the element `frame` is relative to. |
| `value ColorHsva`, `empty bool` | The color; `empty` means none was chosen yet (blank hex field, placeholder in the field, empty swatch). |
| `hex_text ?string` | The text in the hex field while the user types; none shows `value.hex()`. |
| `preview ?ColorHsva` | A swatch under the pointer, shown in the preview and the hex field. |
| `variant`, `open` | See above; `open` is the popover's state. |
| `panel`, `panels` | The current tab and the tabs to offer (default all three). |
| `alpha bool = true` | Show the alpha slider; false keeps every color the picker produces opaque. |
| `featured []u32`, `palettes []ColorPalette` | Swatches; empty uses the defaults. At most `color_picker_max_swatches` (512) in total. |
| `area_height` | Zero: at least 0.6 of the inner width, and tall enough that the spectrum tab is as tall as the others. |
| `opaque_gradients` | Draw without per-stop opacity; see Drawing. |
| `panel_width = 288`, `anchor`, `window` | The popover panel's width, the corner that meets the trigger, and the window (`ui2.bounds()`). |
| `label`, `icon`, `placeholder` | Trigger text, a symbol (see `symbol_known`) in place of the swatch, and the field's text without a color. |
| `enabled` | False: nothing is emitted or decoded and the popover does not open. |
| `focused_part ?ColorPickerPart` | Draws a focus ring on the part the application sends arrow keys to. |
| `accessibility_label` | The picker's name; defaults to `label`, then "Color picker". |

### Functions

| Function | Purpose |
| --- | --- |
| `color_picker(config) !Element` | The panel or the trigger. |
| `color_picker_popover(config) !Element` | The open popover: a transparent backdrop over `window` that reports a click outside, and the panel with a shadow. Empty and hidden while closed, inline or disabled. |
| `color_picker_event(config, event) ?ColorPickerEvent` | Decodes actions and `pointer:` events. Kinds: `.change` (a press, drag or release on the area or a slider; `part`, and `done` on release), `.select` (a swatch), `.hex_change`, `.hex_submit`, `.preview`/`.preview_end` (pointer on/off a swatch), `.panel`, `.toggle`, `.dismiss`. `open` is the popover's state after the event: a swatch or Return closes it, as upstream (keep it open when the hex does not parse); drags keep it open. |
| `color_picker_value_from_pointer(config, event) ?ColorHsva` | The color a pointer event on the area or a slider asks for. |
| `color_picker_value_at(config, part, x, y) ?ColorHsva` | The same from a window point; points outside clamp to the nearest edge. |
| `color_picker_part_frame(config, part) ?Rect`, `color_picker_panel_frame(config) Rect` | Where the area or a track, and the panel, are in window coordinates. |
| `color_picker_hex_field_id(id)` | The hex field's id (for `text`, `set_text`, `focus`) and its change action. |
| `color_picker_hex_value(config, typed) ?ColorHsva` | The color typed hex names, keeping the hue for grays, opaque without `alpha`; none while incomplete. |
| `color_picker_value_after_key(config, part, event) ?ColorHsva` | Arrow keys: left/right move the area's saturation and up/down its brightness; on a slider left/down lower it and right/up raise it, Home and End go to its ends. 1% (1 degree of hue) per press, 10% (10 degrees) with Shift, snapped to whole steps. |
| `color_picker_dismiss_on_key(config, event) bool` | Escape on an open popover. |
| `color_picker_height(config)` | The panel's height. |
| `color_picker_popover_frame(anchor, window, width, height, corner) Rect` | Popover placement; see below. |

The decoder rejects actions of other components, forged or malformed actions
(swatch indexes the panel does not show, parts of another tab, unknown tabs),
everything while disabled, everything inside a closed popover, choosing the
current tab and drags that do not change the color. A press and a release are
reported even when the color stays, so the application can note which part
the user is working with (`event.part`, for `focused_part` and the arrow keys)
and when a drag ends (`event.done`, for example to add the color to the
featured "recent" row). Choosing a swatch keeps the current alpha.

### Pointer handling

The area and the sliders are draggable views. Each reaches half a thumb past
its gradient, so the thumb stays inside it at the ends and a press just
outside an edge still lands; the value is computed from the gradient's own
rectangle. Every backend keeps reporting a drag to the view where it started,
wherever the pointer goes, so dragging past an edge pins the value there.
Swatches are hoverable views with button behavior.

### Keyboard

Which part arrow keys go to is the application's decision; the gallery uses
the part last pressed (`event.part`) and hands the keys back to a hex field
when the user types in it. On AppKit, clicking a plain view does not take
focus from a text field, so `focused_id()` alone cannot tell; see
`handle_key` in the gallery. Escape inside a focused AppKit text field goes to
the field editor, not to `on_key_event` (see "Which keys reach on_key_event"
in [inputs.md](inputs.md)).

### Popover placement

`color_picker_popover_frame` puts the `anchor` corner of the popover against
the matching corner of the trigger, 4 points away: `.top_left` (default)
opens below and to the right, `.top_right` below and to the left,
`.bottom_left` and `.bottom_right` above. With a window it opens on the other
side when only that side has room (or it has more), then slides back inside
the window 8 points from its edges; a popover larger than the window keeps its
top-left corner visible. It is the only placement code, so a shared popover
positioner can replace it.

## Drawing

The saturation and brightness area is drawn one of two ways.

- **Layered** (AppKit, UIKit): the pure hue under a white gradient fading out
  to the right and a black gradient fading in downwards. Composited they give
  exactly HSV(h, s, v) at every point. This needs a gradient stop's opacity.
- **Banded**: horizontal bands, each an opaque gradient from the gray to the
  full color at the band's brightness. HSV is linear in saturation, so each
  band is exact along its row and the brightness steps between bands (2-point
  bands, or 4-point on the custom renderer, which is invisible in practice).
  Native Windows always draws this way because it does not draw a gradient's
  per-stop opacity. The custom renderer does too, for cost: it cuts every
  gradient into 4-point cells, and sokol_gl draws nothing at all in a frame
  that needs more than its 64k vertices (the window stays blank). Two layers
  over the area of a 288-point panel take about 35k, the bands half that.
  `opaque_gradients: true` selects the bands everywhere.

The hue track is a seven-stop gradient (HSV is linear in hue between multiples
of 60 degrees), the HSL saturation track two stops and the lightness track
three (black, the color at 50% and white), all exact. The alpha track is a
gradient from transparent to opaque over a checkerboard; on native Windows (and
with `opaque_gradients`) each checker cell instead holds the ramp already
composited over its own color, which is exact without per-stop opacity.
Translucent previews and swatches use the fill opacity every backend draws.
Swatches are square, as in GPUI Kit, which also keeps a full palette cheap on
the custom renderer.

## Accessibility

The inline panel is a `group` and the popover panel a `dialog`, named by
`accessibility_label` and valued with the hex color. The area is a `group`
valued "Saturation 50%, brightness 75%"; sliders are `slider`s valued in
degrees or percent; swatches are `radio`s named by their hex value (with the
palette family) and valued `checked`/`unchecked`; tabs come from a button
group; the swatch trigger is a `button` and the field trigger a `combobox`,
both valued with the hex color or "none". The backdrop is `presentation`.

## GPUI Kit and ui2

| GPUI Kit | ui2 |
| --- | --- |
| `ColorPicker` (swatch or icon button, label, popover) | `variant: .swatch` with `label`, `icon` and `color_picker_popover` |
| `ColorSelect` (framed field, placeholder, sizes) | `variant: .field`, `placeholder`, `size` |
| `ColorPickerState` value, preview, open state, active tab | The application's model; `value`, `preview`, `open`, `panel` in the config |
| `ColorPickerEvent::Change` | `color_picker_event` (`.change`, `.select`, committed hex) |
| `default_value`, `set_value`, `clear_value` | The application sets `value` (and `empty`) |
| Palette tab: featured colors and nine palette families | `.palette`; `featured`, `palettes`; built-in palette generated from HSL, not copied |
| HSLA tab: hue, saturation, lightness and alpha sliders with values | `.sliders` |
| Hex field: preview while typing, commit on Enter, `#rgb`..`#rrggbbaa` | Implemented (`color_picker_hex_value`, `.hex_change`, `.hex_submit`) |
| Hovering a swatch previews it | `.preview` / `.preview_end` events |
| Selecting a swatch or Enter closes; sliders keep the popover open | `event.open` |
| Enter toggles and Escape dismisses the focused trigger | `color_picker_dismiss_on_key`; activation is the trigger's button behavior (Enter/Space on Windows) |
| `anchor(Anchor)` | `anchor`, with flipping and window clamping |
| `featured_colors`, `label`, `accessibility_label`, `icon`, sizes | Implemented (three sizes; ui2 has no xsmall) |
| Swatch radio semantics, hex names | Implemented (`radio` role) |
| Saturation and brightness area | Added (upstream has none), with arrow-key nudging |
| RGB and HSL text inputs | Not in upstream; the model has `css_rgb`/`css_hsl` and conversions for applications that want them |
| Focus traversal between swatches, focus rings | Omitted: ui2 views do not take keyboard focus; `focused_part` draws the ring for the part the application routes keys to |
| Styling through `Styled`/`refine_style` | Omitted: the theme and size set the look, as for other ui2 components |
| Theme-derived default featured colors (`theme.red`, `red_light`, ...) | `ComponentTheme` has no such colors; the default featured row is the palette's middle shades, gray, black and white |

## Attribution

The hex forms the model accepts and writes follow `parse_hex` and
`hex_string` in `crates/base/src/color_picker.rs` of GPUI Kit (Longbridge,
Apache-2.0), and the tests reuse that file's malformed-hex cases; see the
[attribution](../../third_party/gpui-kit/NOTICE.md). Everything else is a new
implementation of the documented concepts.

## Verification

```sh
v test ui/component_color_test.v
v -d ui2_custom_rendering test ui/component_color_test.v
v run examples/gpui_color/main.v
v -d ui2_custom_rendering run examples/gpui_color/main.v
```
