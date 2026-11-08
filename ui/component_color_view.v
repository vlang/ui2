module ui2

import math

// The color picker's panel: the elements built from color_picker_layout.
//
// The saturation and brightness area is drawn one of two ways.
//
// Layered: three stacked views, the pure hue, a white gradient fading out to
// the right and a black one fading in downwards. Composited they give exactly
// HSV(h, s, v) at every point. AppKit and UIKit draw it this way.
//
// Banded: horizontal bands, each an opaque gradient from the gray to the full
// color at the band's brightness. HSV is linear in saturation, so every band
// is exact along its row; brightness steps from band to band. Native Windows
// draws it this way because it cannot draw a gradient's per-stop opacity. The
// custom renderer does too: it cuts every gradient into 4-point cells, all of
// which count against sokol_gl's 64k vertices per frame, and the bands are
// one gradient's worth where the layers are two. opaque_gradients asks for the
// bands everywhere.
//
// The alpha ramp is a gradient from transparent to opaque over a
// checkerboard, except on native Windows (and with opaque_gradients), where
// each checker cell holds the ramp already composited over its own color.

// color_picker_checker_colors are the light and dark squares behind
// translucent colors.
fn color_picker_checker_colors(theme ComponentTheme) (u32, u32) {
	return theme.background, choice_mix(theme.background, theme.border, 0.75)
}

// color_picker_checker covers frame with a checkerboard of `cell` squares:
// one light view with the dark squares over it.
fn color_picker_checker(frame Rect, cell f64, light u32, dark u32) []Element {
	mut out := [view('', frame, BoxStyle{ bg: light }, []Element{})]
	if cell <= 0 || frame.width <= 0 || frame.height <= 0 {
		return out
	}
	columns := int(math.ceil(frame.width / cell))
	rows := int(math.ceil(frame.height / cell))
	for row in 0 .. rows {
		for col in 0 .. columns {
			if (row + col) % 2 == 0 {
				continue
			}
			x := f64(col) * cell
			y := f64(row) * cell
			out << view('', rect(frame.x + x, frame.y + y, math.min(cell, frame.width - x),
				math.min(cell, frame.height - y)), BoxStyle{ bg: dark }, []Element{})
		}
	}
	return out
}

// color_picker_translucent draws rgb at alpha over a checkerboard in frame,
// or a plain fill when it is opaque. Fill opacity is drawn by every backend.
fn color_picker_translucent(frame Rect, rgb u32, alpha f64, theme ComponentTheme) []Element {
	if color_alpha_byte(alpha) >= 255 {
		return [view('', frame, BoxStyle{ bg: rgb }, []Element{})]
	}
	light, dark := color_picker_checker_colors(theme)
	mut out := color_picker_checker(frame, math.max(math.round(math.min(frame.width, frame.height) / 4),
		3), light, dark)
	out << view('', frame, BoxStyle{
		bg:      rgb
		opacity: color_alpha(alpha)
	}, []Element{})
	return out
}

// color_picker_banded is whether the area is drawn as opaque bands.
fn color_picker_banded(config ColorPickerConfig) bool {
	$if ui2_custom_rendering ? {
		return true
	} $else $if windows {
		return true
	} $else {
		return config.opaque_gradients
	}
}

// color_picker_composited is whether the alpha ramp is drawn as precomposited
// cells.
fn color_picker_composited(config ColorPickerConfig) bool {
	$if ui2_custom_rendering ? {
		return config.opaque_gradients
	} $else $if windows {
		return true
	} $else {
		return config.opaque_gradients
	}
}

// color_picker_area_bands is how many bands the area is drawn with. On the
// custom renderer a band of any height under 4 points costs a full row of
// cells, so bands are 4 points tall there and 2 points elsewhere.
fn color_picker_area_bands(height f64) int {
	$if ui2_custom_rendering ? {
		return int(math.max(8, math.min(128, math.ceil(height / 4))))
	} $else {
		return int(math.max(8, math.min(128, math.ceil(height / 2))))
	}
}

// color_picker_area_layers draws the saturation and brightness gradient for
// hue into g.
fn color_picker_area_layers(config ColorPickerConfig, g Rect, hue f64) []Element {
	if g.width <= 0 || g.height <= 0 {
		return []Element{}
	}
	if !color_picker_banded(config) {
		return [
			view('', g, BoxStyle{ bg: color_hsva(hue, 1, 1, 1).rgb() }, []Element{}),
			view('', g, BoxStyle{
				gradient: linear_gradient(0, GradientStop{
					color:    0xffffff
					position: 0
					opacity:  1
				}, GradientStop{
					color:    0xffffff
					position: 1
					opacity:  0
				})
			}, []Element{}),
			view('', g, BoxStyle{
				gradient: linear_gradient(90, GradientStop{
					color:    0x000000
					position: 0
					opacity:  0
				}, GradientStop{
					color:    0x000000
					position: 1
					opacity:  1
				})
			}, []Element{}),
		]
	}
	bands := color_picker_area_bands(g.height)
	mut out := []Element{cap: bands}
	for index in 0 .. bands {
		y0 := g.y + g.height * f64(index) / f64(bands)
		y1 := g.y + g.height * f64(index + 1) / f64(bands)
		value := 1 - (f64(index) + 0.5) / f64(bands)
		gray := color_hsva(hue, 0, value, 1).rgb()
		// Each band reaches half a point into the next, so no seam shows.
		overlap := if index < bands - 1 { 0.5 } else { 0.0 }
		out << view('', rect(g.x, y0, g.width, y1 - y0 + overlap), BoxStyle{
			bg:       gray
			gradient: linear_gradient(0, gradient_stop(gray, 0), gradient_stop(color_hsva(hue,
				1, value, 1).rgb(), 1))
		}, []Element{})
	}
	return out
}

// color_picker_hue_gradient runs through the hues at full saturation and
// value. HSV is linear in hue between multiples of 60 degrees, so seven stops
// draw it exactly.
fn color_picker_hue_gradient() Gradient {
	mut stops := []GradientStop{cap: 7}
	for index in 0 .. 7 {
		stops << gradient_stop(color_hsva(f64(index) * 60, 1, 1, 1).rgb(), f64(index) / 6)
	}
	return Gradient{
		angle: 0
		stops: stops
	}
}

// color_picker_alpha_track draws rgb from transparent to opaque over a
// checkerboard in track.
fn color_picker_alpha_track(config ColorPickerConfig, track Rect, rgb u32) []Element {
	light, dark := color_picker_checker_colors(config.theme)
	cell := math.max(track.height / 2, 2)
	if !color_picker_composited(config) {
		mut out := color_picker_checker(track, cell, light, dark)
		out << view('', track, BoxStyle{
			gradient: linear_gradient(0, GradientStop{
				color:    rgb
				position: 0
				opacity:  0
			}, GradientStop{
				color:    rgb
				position: 1
				opacity:  1
			})
		}, []Element{})
		return out
	}
	if track.width <= 0 || track.height <= 0 {
		return []Element{}
	}
	columns := int(math.ceil(track.width / cell))
	rows := int(math.ceil(track.height / cell))
	mut out := []Element{cap: columns * rows}
	for row in 0 .. rows {
		for col in 0 .. columns {
			x := f64(col) * cell
			y := f64(row) * cell
			w := math.min(cell, track.width - x)
			base := if (row + col) % 2 == 0 { light } else { dark }
			from := color_over(rgb, x / track.width, base)
			to := color_over(rgb, (x + w) / track.width, base)
			out << view('', rect(track.x + x, track.y + y, w, math.min(cell, track.height - y)),
				BoxStyle{
					bg:       from
					gradient: linear_gradient(0, gradient_stop(from, 0), gradient_stop(to, 1))
				}, []Element{})
		}
	}
	return out
}

fn color_picker_border_box(color u32, width f64, radius f64) BoxStyle {
	return BoxStyle{
		transparent:   true
		radius:        radius
		border_color:  color
		border_left:   width
		border_top:    width
		border_right:  width
		border_bottom: width
	}
}

// color_picker_ring is the area's thumb: a white ring inside a dark one, so it
// shows on light and dark colors alike.
fn color_picker_ring(cx f64, cy f64, d f64) []Element {
	outer := rect(cx - d / 2, cy - d / 2, d, d)
	return [
		view('', outer, color_picker_border_box(0x1f2937, 1, d / 2), []Element{}),
		view('', rect(outer.x + 1, outer.y + 1, d - 2, d - 2), color_picker_border_box(0xffffff,
			2, d / 2 - 1), []Element{}),
	]
}

// color_picker_knob is a slider's thumb: a white disc with the color it
// selects in the middle.
fn color_picker_knob(cx f64, cy f64, d f64, fill u32, theme ComponentTheme) []Element {
	inner := math.max(d - 6, 0)
	return [
		view('', rect(cx - d / 2, cy - d / 2, d, d), BoxStyle{
			bg:            0xffffff
			radius:        d / 2
			border_color:  choice_mix(theme.border, 0x000000, 0.3)
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, []Element{}),
		view('', rect(cx - inner / 2, cy - inner / 2, inner, inner), BoxStyle{
			bg:     fill
			radius: inner / 2
		}, []Element{}),
	]
}

// color_picker_focus_ring outlines a focused part, 3 points outside it.
fn color_picker_focus_ring(frame Rect, theme ComponentTheme) Element {
	return view('', rect(frame.x - 3, frame.y - 3, frame.width + 6, frame.height + 6),
		color_picker_border_box(theme.primary, 2, 3), []Element{})
}

fn color_picker_focused(config ColorPickerConfig, part ColorPickerPart) bool {
	focused := config.focused_part or { return false }
	return focused == part
}

fn color_picker_percent(fraction f64) string {
	return '${int(math.round(unit_clamp(fraction) * 100))}%'
}

// color_picker_area is the draggable saturation and brightness area. Its view
// reaches half a thumb past the gradient on every side, so the thumb stays
// inside it at the corners and a press just outside the edge still lands.
fn color_picker_area(config ColorPickerConfig, area Rect, m ColorPickerMetrics) Element {
	r := m.thumb / 2
	value := config.value.normalized()
	g := rect(r, r, area.width, area.height)
	mut children := color_picker_area_layers(config, g, value.h)
	children << view('', g, color_picker_border_box(choice_mix(config.theme.border, 0x000000,
		0.1), 1, 0), []Element{})
	if color_picker_focused(config, .area) {
		children << color_picker_focus_ring(g, config.theme)
	}
	children << color_picker_ring(r + value.s * area.width, r + (1 - value.v) * area.height,
		m.thumb)
	return Element{
		...draggable_view_with_cursor(component_part_id(config.id, 'area'), rect(area.x - r,
			area.y - r, area.width + 2 * r, area.height + 2 * r), BoxStyle{
			transparent: true
		}, cursor_crosshair, children)
		key:                 'area'
		enabled:             config.enabled
		accessibility_role:  'group'
		accessibility_label: color_picker_caption(.area)
		accessibility_value: 'Saturation ${color_picker_percent(value.s)}, brightness ${color_picker_percent(value.v)}'
	}
}

// color_picker_slider is a draggable slider over a gradient track. Like the
// area, its view reaches half a thumb past each end of the track.
fn color_picker_slider(config ColorPickerConfig, slot ColorPickerSlider, m ColorPickerMetrics) Element {
	r := m.thumb / 2
	track := slot.track
	value := config.value.normalized()
	hsl := value.hsla()
	rgb := value.rgb()
	local := rect(r, (m.thumb - track.height) / 2, track.width, track.height)
	mut children := []Element{}
	mut fraction := 0.0
	mut knob := rgb
	mut readout := ''
	match slot.part {
		.hue {
			children << view('', local, BoxStyle{
				gradient: color_picker_hue_gradient()
			}, []Element{})
			fraction = value.h / 360
			knob = color_hsva(value.h, 1, 1, 1).rgb()
			readout = '${int(math.round(value.h))}°'
		}
		.alpha {
			children << color_picker_alpha_track(config, local, rgb)
			fraction = value.a
			knob = color_over(rgb, value.a, 0xffffff)
			readout = color_picker_percent(value.a)
		}
		.saturation {
			children << view('', local, BoxStyle{
				gradient: linear_gradient(0, gradient_stop(color_from_hsla(hsl.h, 0, hsl.l,
					1).rgb(), 0), gradient_stop(color_from_hsla(hsl.h, 1, hsl.l, 1).rgb(),
					1))
			}, []Element{})
			fraction = hsl.s
			readout = color_picker_percent(hsl.s)
		}
		.lightness {
			// HSL is linear in lightness on either side of 50%, so black, the
			// color at half lightness and white draw it exactly.
			children << view('', local, BoxStyle{
				gradient: linear_gradient(0, gradient_stop(0x000000, 0), gradient_stop(color_from_hsla(hsl.h,
					hsl.s, 0.5, 1).rgb(), 0.5), gradient_stop(0xffffff, 1))
			}, []Element{})
			fraction = hsl.l
			readout = color_picker_percent(hsl.l)
		}
		.area {}
	}
	if color_picker_focused(config, slot.part) {
		children << color_picker_focus_ring(local, config.theme)
	}
	children << color_picker_knob(r + unit_clamp(fraction) * track.width, m.thumb / 2,
		m.thumb, knob, config.theme)
	name := color_picker_part_name(slot.part)
	return Element{
		...draggable_view_with_cursor(component_part_id(config.id, name), rect(track.x - r,
			track.y + track.height / 2 - r, track.width + 2 * r, m.thumb), BoxStyle{
			transparent: true
		}, cursor_pointing_hand, children)
		key:                 name
		enabled:             config.enabled
		accessibility_role:  'slider'
		accessibility_label: color_picker_caption(slot.part)
		accessibility_value: readout
	}
}

// color_picker_slider_readout is the value shown right of a slider on the
// sliders panel: degrees of hue, otherwise percent.
fn color_picker_slider_readout(value ColorHsva, part ColorPickerPart) string {
	n := value.normalized()
	return match part {
		.hue { '${int(math.round(n.h))}°' }
		.alpha { color_picker_percent(n.a) }
		.saturation { color_picker_percent(n.hsla().s) }
		.lightness { color_picker_percent(n.hsla().l) }
		.area { '' }
	}
}

// color_picker_swatch is one palette or featured color: a square, as in
// GPUI Kit, with a check mark and a wider frame in the foreground color while
// it is the current color. Swatches are hoverable, so the application can
// preview the color under the pointer.
fn color_picker_swatch(config ColorPickerConfig, slot ColorPickerSwatch, selected bool) Element {
	side := slot.frame.width
	mut children := []Element{}
	if selected && side >= 8 {
		mark := math.round(side * 0.7)
		children << choice_icon('checkmark', rect((side - mark) / 2, (side - mark) / 2, mark,
			mark), color_contrast_foreground(slot.color))
	}
	edge := if selected { 2.0 } else { 1.0 }
	return Element{
		...with_hover(button_view(component_part_id(config.id, 'swatch:' + slot.part), slot.frame,
			BoxStyle{
				bg:            slot.color
				border_color:  if selected {
					config.theme.foreground
				} else {
					choice_mix(slot.color, 0x000000, 0.15)
				}
				border_left:   edge
				border_top:    edge
				border_right:  edge
				border_bottom: edge
			}, children))
		key:                 'swatch:' + slot.part
		enabled:             config.enabled
		accessibility_role:  'radio'
		accessibility_label: slot.name
		accessibility_value: if selected { 'checked' } else { 'unchecked' }
	}
}

fn color_picker_panel_title(panel ColorPickerPanel, alpha bool) string {
	return match panel {
		.spectrum { 'Spectrum' }
		.palette { 'Palette' }
		.sliders {
			if alpha { 'HSLA' } else { 'HSL' }
		}
	}
}

// color_picker_tabs is a button group whose buttons emit the picker's own
// `panel:<name>` actions.
fn color_picker_tabs(config ColorPickerConfig, layout ColorPickerLayout) Element {
	mut items := []ButtonGroupItem{}
	for item in color_picker_panels(config) {
		name := color_picker_panel_name(item)
		items << ButtonGroupItem{
			value:     name
			label:     color_picker_panel_title(item, config.alpha)
			action_id: component_part_id(config.id, 'panel:' + name)
			selected:  item == layout.panel
		}
	}
	group := button_group(
		id:                  component_part_id(config.id, 'tabs')
		frame:               layout.tabs
		items:               items
		fill:                true
		enabled:             config.enabled
		accessibility_label: 'Color picker view'
		size:                config.size
		theme:               config.theme
	) or { view('', layout.tabs, BoxStyle{ transparent: true }, []Element{}) }
	return Element{
		...group
		key: 'tabs'
	}
}

// color_picker_shown_color is the color the preview and the hex field show:
// a previewed swatch, else the value.
fn color_picker_shown_color(config ColorPickerConfig) ColorHsva {
	return config.preview or { config.value }
}

// color_picker_hex_of is how the picker writes a color: without the alpha
// when the picker has no alpha slider.
fn color_picker_hex_of(config ColorPickerConfig, c ColorHsva) string {
	return if config.alpha { c.hex() } else { color_hex(c.rgb(), 1) }
}

fn color_picker_previewing(config ColorPickerConfig) bool {
	if _ := config.preview {
		return true
	}
	return false
}

fn color_picker_hex_text(config ColorPickerConfig) string {
	if typed := config.hex_text {
		return typed
	}
	if previewed := config.preview {
		return color_picker_hex_of(config, previewed)
	}
	return if config.empty { '' } else { color_picker_hex_of(config, config.value) }
}

// color_picker_panel_children builds everything inside the panel, in panel
// coordinates.
fn color_picker_panel_children(config ColorPickerConfig, layout ColorPickerLayout) []Element {
	m := color_picker_metrics(config.size)
	theme := config.theme
	mut children := []Element{}
	if layout.tabs.width > 0 {
		children << color_picker_tabs(config, layout)
	}
	if layout.area.width > 0 {
		children << color_picker_area(config, layout.area, m)
	}
	for slot in layout.sliders {
		if slot.caption.width > 0 {
			children << Element{
				...label('', color_picker_caption(slot.part), slot.caption, TextStyle{
					color: theme.muted_foreground
					size:  m.font
				})
				key: 'caption:' + color_picker_part_name(slot.part)
			}
			children << Element{
				...label('', color_picker_slider_readout(config.value, slot.part), slot.readout,
					TextStyle{
						color: theme.muted_foreground
						size:  m.font
						align: .right
					})
				key: 'readout:' + color_picker_part_name(slot.part)
			}
		}
		children << color_picker_slider(config, slot, m)
	}
	if layout.divider.width > 0 {
		children << Element{
			...view('', layout.divider, BoxStyle{ bg: theme.border }, []Element{})
			key: 'divider'
		}
	}
	current := config.value.rgb()
	for slot in layout.swatches {
		children << color_picker_swatch(config, slot, !config.empty && slot.color == current)
	}
	children << Element{
		...view('', layout.footer, BoxStyle{ bg: theme.border }, []Element{})
		key: 'footer'
	}
	shown := color_picker_shown_color(config).normalized()
	mut preview := []Element{}
	previewing := color_picker_previewing(config)
	if !config.empty || previewing {
		preview = color_picker_translucent(component_local(layout.preview), shown.rgb(), if config.alpha {
			shown.a
		} else {
			1.0
		}, theme)
	}
	preview << view('', component_local(layout.preview), color_picker_border_box(theme.border,
		1, 0), []Element{})
	children << Element{
		...view('', layout.preview, BoxStyle{ transparent: true }, preview)
		key:                 'preview'
		accessibility_role:  'img'
		accessibility_label: 'Preview'
		accessibility_value: if config.empty && !previewing {
			'none'
		} else {
			color_picker_hex_of(config, shown)
		}
	}
	children << inputs_field(
		id:                color_picker_hex_field_id(config.id)
		submit_id:         component_part_id(config.id, 'hex:submit')
		placeholder:       if config.alpha { '#RRGGBBAA' } else { '#RRGGBB' }
		text:              color_picker_hex_text(config)
		frame:             layout.hex
		font_size:         component_metrics(config.size).font_size
		enabled:           config.enabled
		autocorrect:       false
		role:              'textbox'
		label:             'Hex color'
		key:               'hex'
		standalone_radius: m.radius
		theme:             theme
	)
	return children
}

fn color_picker_description(config ColorPickerConfig) string {
	return if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else if config.label.len > 0 {
		config.label
	} else {
		'Color picker'
	}
}

// color_picker_inline is the panel at config.frame. A zero frame height
// takes the height the panel needs.
fn color_picker_inline(config ColorPickerConfig) Element {
	layout := color_picker_layout(config)
	m := color_picker_metrics(config.size)
	height := if config.frame.height > 0 { config.frame.height } else { layout.height }
	return Element{
		...view(config.id, rect(config.frame.x, config.frame.y, config.frame.width, height),
			component_box(config.theme.background, config.theme.border, m.radius), color_picker_panel_children(config,
				layout))
		accessibility_role:  'group'
		accessibility_label: color_picker_description(config)
		accessibility_value: if config.empty {
			'none'
		} else {
			color_picker_hex_of(config, config.value)
		}
	}
}
