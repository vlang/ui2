// SPDX-License-Identifier: Apache-2.0
// The malformed hex strings in test_color_parse_hex_rejects_malformed_text and
// the translucent-only alpha case come from GPUI Kit's color picker tests
// (Longbridge, copyright 2024 - 2026); the other tests are new. See
// third_party/gpui-kit.
module ui2

import math

// ── Helpers ─────────────────────────────────────────────────────────

fn color_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := color_find(child, id) {
			return found
		}
	}
	return none
}

fn color_find_key(el Element, key string) ?Element {
	for child in el.children {
		if child.key == key {
			return child
		}
	}
	return none
}

fn color_assert_inside(el Element) {
	for child in el.children {
		if child.hidden {
			continue
		}
		assert child.frame.x >= -1e-9 && child.frame.y >= -1e-9, '${child.key} ${child.frame}'
		assert child.frame.x + child.frame.width <= el.frame.width + 1e-9, '${child.key} ${child.frame} in ${el.frame}'
		assert child.frame.y + child.frame.height <= el.frame.height + 1e-9, '${child.key} ${child.frame} in ${el.frame}'
		color_assert_inside(child)
	}
}

fn color_near(a f64, b f64) bool {
	return math.abs(a - b) < 1e-9
}

fn color_close(a f64, b f64, tolerance f64) bool {
	return math.abs(a - b) <= tolerance
}

fn color_inline(value ColorHsva) ColorPickerConfig {
	return ColorPickerConfig{
		id:    'pick'
		frame: rect(20, 30, 288, 0)
		value: value
	}
}

fn color_pointer(phase string, action string, x f64, y f64) string {
	return 'pointer:${phase}:${action}:${x}:${y}'
}

fn color_key(code KeyCode) KeyEvent {
	return KeyEvent{
		code: code
	}
}

// ── Model: hex ──────────────────────────────────────────────────────

fn test_color_hex_formats_alpha_only_when_translucent() {
	assert color_hex(0x3366ff, 1) == '#3366FF'
	assert color_hex(0xff0000, 1) == '#FF0000'
	assert color_hex(0x000000, 0) == '#00000000'
	// Alpha is rounded, so 0.5 writes 80 and parses back to the same byte.
	assert color_hex(0xff0000, 0.5) == '#FF000080'
	assert color_hex(0x0a0b0c, 0.999) == '#0A0B0C'
	assert color_hex(0x0a0b0c, 0.997) == '#0A0B0CFE'
	assert color_hex(0x123456, math.nan()) == '#123456'
	assert color_hex(0xff123456, 1) == '#123456'
	assert color_from_rgba(0x3366ff, 0.5).hex() == '#3366FF80'
	assert color_hsva(0, 1, 1, 1).hex() == '#FF0000'
}

fn test_color_parse_hex_reads_every_width() {
	white := color_parse_hex('#fff') or { panic('no #fff') }
	assert white.rgb() == 0xffffff && white.a == 1
	assert (color_parse_hex('ffffff') or { panic('no ffffff') }).rgb() == 0xffffff
	assert (color_parse_hex('  #3366FF\n') or { panic('no spaced') }).rgb() == 0x3366ff
	half := color_parse_hex('#ff000080') or { panic('no #ff000080') }
	assert half.rgb() == 0xff0000
	assert color_close(half.a, 0.5, 0.01)
	short := color_parse_hex('#f008') or { panic('no #f008') }
	assert short.rgb() == 0xff0000
	assert color_near(short.a, f64(0x88) / 255)
	mixed := color_parse_hex('#aBc') or { panic('no #aBc') }
	assert mixed.rgb() == 0xaabbcc
	for alpha_byte in [0, 1, 127, 128, 254, 255] {
		text := color_hex(0x102030, f64(alpha_byte) / 255)
		back := color_parse_hex(text) or { panic('no ${text}') }
		assert color_alpha_byte(back.a) == u8(alpha_byte), text
	}
}

fn test_color_parse_hex_rejects_malformed_text() {
	for bad in ['#nope', '#12', '#1234567', '', '#+f0000', '#-fffff', '##fff', '#ff ff00', '#',
		'fffff', '#ggg', '0x123456', '#123456789', '#é12'] {
		if parsed := color_parse_hex(bad) {
			assert false, '`${bad}` parsed as ${parsed}'
		}
		if _ := color_from_hex(bad) {
			assert false, '`${bad}` converted'
		}
	}
}

// ── Model: RGB and HSV ──────────────────────────────────────────────

fn test_color_rgb_to_hsv_known_colors() {
	red := color_from_rgb(0xff0000)
	assert red.h == 0 && red.s == 1 && red.v == 1 && red.a == 1
	assert color_from_rgb(0x00ff00).h == 120
	assert color_from_rgb(0x0000ff).h == 240
	assert color_from_rgb(0xffff00).h == 60
	assert color_from_rgb(0xff00ff).h == 300
	assert color_from_rgb(0x00ffff).h == 180
	brand := color_from_rgb(0x3366ff)
	assert color_close(brand.h, 225, 1e-9)
	assert color_close(brand.s, 0.8, 1e-9)
	assert brand.v == 1
	// Grays have no hue or saturation; black has no value either.
	for gray in [u32(0x000000), 0x808080, 0xffffff, 0x010101] {
		c := color_from_rgb(gray)
		assert c.h == 0 && c.s == 0
		assert color_near(c.v, f64(gray & 0xff) / 255)
	}
	// A hue just below red is not negative.
	pinkish := color_from_rgb(0xff0001)
	assert pinkish.h > 359 && pinkish.h < 360
}

fn test_color_hsv_to_rgb_known_colors() {
	assert color_hsva(0, 1, 1, 1).rgb() == 0xff0000
	assert color_hsva(120, 1, 1, 1).rgb() == 0x00ff00
	assert color_hsva(240, 1, 1, 1).rgb() == 0x0000ff
	assert color_hsva(360, 1, 1, 1).rgb() == 0xff0000
	assert color_hsva(30, 1, 1, 1).rgb() == 0xff8000
	assert color_hsva(210, 0, 0.5, 1).rgb() == 0x808080
	assert color_hsva(210, 1, 0, 1).rgb() == 0x000000
	assert color_hsva(210, 0, 1, 1).rgb() == 0xffffff
	// Rounding: 0.5 * 255 = 127.5 rounds up.
	assert color_hsva(0, 0, 0.5, 1).rgba().r == 128
}

fn test_color_rgb_round_trips_through_hsv() {
	for r := 0; r < 256; r += 15 {
		for g := 0; g < 256; g += 17 {
			for b := 0; b < 256; b += 13 {
				rgb := (u32(r) << 16) | (u32(g) << 8) | u32(b)
				c := color_from_rgb(rgb)
				assert c.rgb() == rgb, '${rgb:06x} -> ${c}'
				assert c.h >= 0 && c.h < 360
				assert color_hex(rgb, 1) == c.hex()
				back := color_from_hex(c.hex()) or { panic('no hex') }
				assert back.rgb() == rgb
			}
		}
	}
}

fn test_color_hue_wraps_and_components_clamp() {
	assert color_wrap_hue(370) == 10
	assert color_wrap_hue(-30) == 330
	assert color_wrap_hue(360) == 360
	assert color_wrap_hue(0) == 0
	assert color_wrap_hue(720) == 0
	assert color_wrap_hue(-360) == 0
	assert !math.signbit(color_wrap_hue(-360))
	assert color_wrap_hue(-0.5) == 359.5
	assert color_wrap_hue(math.nan()) == 0
	assert color_wrap_hue(math.inf(1)) == 0
	c := color_hsva(-90, 2, -1, 7)
	assert c.h == 270 && c.s == 1 && c.v == 0 && c.a == 1
	n := color_hsva(math.nan(), math.nan(), math.nan(), math.nan())
	assert n.h == 0 && n.s == 0 && n.v == 0 && n.a == 1
	assert ColorHsva{
		h: 480
		s: 1
		v: 1
	}.rgb() == color_hsva(120, 1, 1, 1).rgb()
	assert color_from_rgb(0x3366ff).with_alpha(-1).a == 0
	assert color_from_rgb(0x3366ff).with_alpha(0.25).a == 0.25
}

fn test_color_with_rgba_keeps_what_the_channels_leave_open() {
	blue := color_hsva(220, 0.7, 0.8, 1)
	// A gray keeps the hue; black keeps hue and saturation.
	gray := blue.with_rgba(ColorRgba{
		r: 0x80
		g: 0x80
		b: 0x80
	})
	assert gray.h == 220 && gray.s == 0
	black := blue.with_rgba(ColorRgba{})
	assert black.h == 220 && black.s == 0.7 && black.v == 0
	// The same channels leave the color alone, only the alpha changes.
	same := blue.with_rgba(ColorRgba{
		...blue.rgba()
		a: 0.5
	})
	assert same.h == blue.h && same.s == blue.s && same.v == blue.v && same.a == 0.5
	other := blue.with_rgba(ColorRgba{
		r: 0xff
	})
	assert other.h == 0 && other.s == 1 && other.v == 1
}

// ── Model: HSL and CSS ──────────────────────────────────────────────

fn test_color_hsl_conversions() {
	brand := color_from_rgb(0x3366ff).hsla()
	assert color_close(brand.h, 225, 1e-9)
	assert color_close(brand.s, 1, 1e-9)
	assert color_close(brand.l, 0.6, 1e-9)
	assert color_from_hsla(225, 1, 0.6, 1).rgb() == 0x3366ff
	assert color_from_hsla(0, 1, 0.5, 1).rgb() == 0xff0000
	assert color_from_hsla(120, 1, 0.25, 1).rgb() == 0x008000
	assert color_from_hsla(0, 0, 0.5, 1).rgb() == 0x808080
	assert color_from_hsla(0, 0.5, 1, 1).rgb() == 0xffffff
	// Out-of-range input is clamped and wrapped.
	assert color_from_hsla(-120, 3, 0.5, 2).rgb() == 0x0000ff
	for r := 0; r < 256; r += 51 {
		for g := 0; g < 256; g += 51 {
			for b := 0; b < 256; b += 51 {
				rgb := (u32(r) << 16) | (u32(g) << 8) | u32(b)
				assert color_from_rgb(rgb).hsla().hsva().rgb() == rgb
			}
		}
	}
	// Black keeps its saturation through HSL, so a lightness slider dragged to
	// zero and back does not lose it; white has none.
	dark := color_hsva(30, 0.6, 0, 1)
	assert dark.hsla().s == 0.6
	assert dark.hsla().hsva().s == 0.6
	white := color_hsva(30, 0, 1, 1).hsla()
	assert white.l == 1 && white.s == 0
}

fn test_color_css_notation() {
	brand := color_from_rgb(0x3366ff)
	assert brand.css_rgb() == 'rgb(51, 102, 255)'
	assert brand.css_hsl() == 'hsl(225, 100%, 60%)'
	assert brand.with_alpha(0.5).css_rgb() == 'rgba(51, 102, 255, 0.5)'
	assert brand.with_alpha(0.25).css_hsl() == 'hsla(225, 100%, 60%, 0.25)'
	assert brand.with_alpha(0.1).css_rgb() == 'rgba(51, 102, 255, 0.1)'
	assert brand.with_alpha(0).css_rgb() == 'rgba(51, 102, 255, 0)'
	assert brand.with_alpha(0.12345).css_rgb() == 'rgba(51, 102, 255, 0.123)'
	// Hue 360 is written as 0; components round.
	assert color_hsva(360, 1, 1, 1).css_hsl() == 'hsl(0, 100%, 50%)'
	assert color_hsva(359.6, 1, 1, 1).css_hsl() == 'hsl(0, 100%, 50%)'
	assert color_from_rgb(0x808080).css_hsl() == 'hsl(0, 0%, 50%)'
}

fn test_color_contrast_foreground_and_compositing() {
	assert color_contrast_foreground(0xffffff) == 0x000000
	assert color_contrast_foreground(0x000000) == 0xffffff
	assert color_contrast_foreground(0xfacc15) == 0x000000
	assert color_contrast_foreground(0x1d4ed8) == 0xffffff
	assert color_over(0xff0000, 1, 0xffffff) == 0xff0000
	assert color_over(0xff0000, 0, 0xffffff) == 0xffffff
	assert color_over(0x000000, 0.5, 0xffffff) == 0x808080
	assert color_from_rgb(0x123456).same_rgb(color_from_rgba(0x123456, 0.1))
	assert !color_from_rgb(0x123456).same_rgb(color_from_rgb(0x123457))
}

fn test_color_default_palettes() {
	palettes := color_default_palettes()
	assert palettes.len == 9
	assert palettes.map(it.name) == ['Stone', 'Red', 'Orange', 'Yellow', 'Green', 'Cyan', 'Blue',
		'Purple', 'Pink']
	for palette in palettes {
		assert palette.colors.len == 11
		// Light to dark.
		for i in 1 .. palette.colors.len {
			assert choice_luminance(palette.colors[i]) < choice_luminance(palette.colors[i - 1]), palette.name
		}
	}
	featured := color_default_featured()
	assert featured.len == 11
	assert featured[9] == 0x000000 && featured[10] == 0xffffff
	assert featured[0] == palettes[1].colors[5]
}

// ── Layout ──────────────────────────────────────────────────────────

fn test_color_picker_layout_is_as_tall_on_every_tab() {
	base := color_inline(color_from_rgb(0x3366ff))
	mut heights := []f64{}
	for item in [ColorPickerPanel.spectrum, .palette, .sliders] {
		layout := color_picker_layout(ColorPickerConfig{
			...base
			panel: item
		})
		assert layout.panel == item
		assert layout.width == 288
		assert layout.tabs.height == component_metrics(.medium).height
		heights << layout.height
		// The tabs, content and footer stay inside the padding.
		for r in [layout.tabs, layout.area, layout.footer, layout.preview, layout.hex] {
			if r.width > 0 {
				assert r.x >= 12 && r.x + r.width <= 276 + 1e-9, '${r}'
			}
		}
		for swatch in layout.swatches {
			assert swatch.frame.x >= 12 && swatch.frame.x + swatch.frame.width <= 276
			assert swatch.frame.y + swatch.frame.height < layout.footer.y
		}
	}
	assert heights[0] == heights[1] && heights[1] == heights[2]
	assert color_picker_height(base) == heights[0]
	spectrum := color_picker_layout(base)
	assert spectrum.area == rect(12, 54, 264, spectrum.area.height)
	assert spectrum.area.height >= math.round(264 * 0.6)
	assert spectrum.sliders.map(it.part) == [ColorPickerPart.hue, .alpha]
	assert spectrum.swatches.len == 11
	assert spectrum.swatches[0].part == 'f:0'
	palette := color_picker_layout(ColorPickerConfig{
		...base
		panel: .palette
	})
	assert palette.swatches.len == 11 + 9 * 11
	assert palette.divider.height == 1
	assert palette.swatches[11].part == 'p:0:0'
	assert palette.swatches[11].name == 'Stone ' + color_hex(color_default_palettes()[0].colors[0], 1)
	sliders := color_picker_layout(ColorPickerConfig{
		...base
		panel: .sliders
	})
	assert sliders.sliders.map(it.part) == [ColorPickerPart.hue, .saturation, .lightness, .alpha]
	for slot in sliders.sliders {
		assert slot.caption.x + slot.caption.width < slot.track.x
		assert slot.track.x + slot.track.width < slot.readout.x
	}
	// Without alpha there is no alpha slider anywhere.
	opaque := color_picker_layout(ColorPickerConfig{
		...base
		alpha: false
		panel: .sliders
	})
	assert opaque.sliders.len == 3
}

fn test_color_picker_layout_options() {
	base := color_inline(color_from_rgb(0x3366ff))
	single := color_picker_layout(ColorPickerConfig{
		...base
		panels: [ColorPickerPanel.sliders]
	})
	assert single.tabs == Rect{}
	assert single.panel == .sliders
	// A panel that is not a tab falls back to the first tab.
	fallback := color_picker_layout(ColorPickerConfig{
		...base
		panel:  .palette
		panels: [ColorPickerPanel.sliders, .spectrum, .sliders]
	})
	assert fallback.panel == .sliders
	assert color_picker_panels(ColorPickerConfig{
		...base
		panels: [ColorPickerPanel.sliders, .spectrum, .sliders]
	}) == [ColorPickerPanel.sliders, .spectrum]
	none_listed := color_picker_layout(ColorPickerConfig{
		...base
		panel:  .palette
		panels: []
	})
	assert none_listed.panel == .palette && none_listed.tabs == Rect{}
	tall := color_picker_layout(ColorPickerConfig{
		...base
		area_height: 300
	})
	assert tall.area.height == 300
	// Custom featured colors wrap on the palette tab and are cut to one row on
	// the spectrum tab.
	many := []u32{len: 15, init: u32(index * 0x111111)}
	wrapped := color_picker_layout(ColorPickerConfig{
		...base
		featured: many
		panel:    .palette
	})
	assert wrapped.swatches.filter(it.part.starts_with('f:')).len == 15
	assert wrapped.swatches[11].frame.y > wrapped.swatches[0].frame.y
	assert color_picker_layout(ColorPickerConfig{
		...base
		featured: many
	}).swatches.len == 11
	// Small and large sizes keep everything inside.
	for size in [ComponentSize.small, .large] {
		for item in [ColorPickerPanel.spectrum, .palette, .sliders] {
			el := color_picker(ColorPickerConfig{
				...base
				size:  size
				panel: item
			}) or { panic(err) }
			color_assert_inside(el)
		}
	}
}

// ── Elements ────────────────────────────────────────────────────────

fn test_color_picker_inline_elements() {
	value := color_hsva(200, 0.5, 0.75, 0.6)
	base := color_inline(value)
	el := color_picker(base) or { panic(err) }
	assert el.id == 'pick'
	assert el.frame == rect(20, 30, 288, color_picker_height(base))
	assert el.accessibility_role == 'group'
	assert el.accessibility_value == value.hex()
	color_assert_inside(el)
	area := color_find(el, 'pick:component:area') or { panic('no area') }
	assert area.draggable && area.cursor == cursor_crosshair
	assert area.accessibility_value == 'Saturation 50%, brightness 75%'
	layout := color_picker_layout(base)
	r := color_picker_metrics(.medium).thumb / 2
	assert area.frame == rect(layout.area.x - r, layout.area.y - r, layout.area.width + 2 * r,
		layout.area.height + 2 * r)
	hue := color_find(el, 'pick:component:hue') or { panic('no hue') }
	assert hue.draggable && hue.accessibility_role == 'slider'
	assert hue.accessibility_value == '200°'
	alpha := color_find(el, 'pick:component:alpha') or { panic('no alpha') }
	assert alpha.accessibility_value == '60%'
	hex := color_find(el, color_picker_hex_field_id('pick')) or { panic('no hex') }
	assert hex.kind == .text_field
	assert hex.text == value.hex()
	assert hex.submit_id == 'pick:component:hex:submit'
	assert hex.emit_change && !hex.autocorrect
	tabs := color_find_key(el, 'tabs') or { panic('no tabs') }
	tab_actions := color_picker_collect(tabs).filter(it.button_behavior).map(it.action_id)
	assert tab_actions == ['pick:component:panel:spectrum', 'pick:component:panel:palette',
		'pick:component:panel:sliders']
	// The current color's swatch is checked.
	red := color_inline(color_from_rgb(color_default_featured()[0]))
	with_red := color_picker(red) or { panic(err) }
	swatch := color_find(with_red, 'pick:component:swatch:f:0') or { panic('no swatch') }
	assert swatch.button_behavior && swatch.hoverable
	assert swatch.accessibility_role == 'radio'
	assert swatch.accessibility_value == 'checked'
	assert swatch.children.len == 1 && swatch.children[0].image_path == 'symbol:checkmark'
	other := color_find(with_red, 'pick:component:swatch:f:1') or { panic('no swatch') }
	assert other.accessibility_value == 'unchecked' && other.children.len == 0
	// An empty picker checks nothing and leaves the hex field blank.
	empty := color_picker(ColorPickerConfig{
		...red
		empty: true
	}) or { panic(err) }
	assert (color_find(empty, 'pick:component:swatch:f:0') or { panic('') }).accessibility_value == 'unchecked'
	assert (color_find(empty, color_picker_hex_field_id('pick')) or { panic('') }).text == ''
	// While the user types, the field keeps the draft; a preview shows the
	// previewed color in the field.
	typing := color_picker(ColorPickerConfig{
		...base
		hex_text: '#12'
	}) or { panic(err) }
	assert (color_find(typing, color_picker_hex_field_id('pick')) or { panic('') }).text == '#12'
	previewing := color_picker(ColorPickerConfig{
		...base
		preview: color_from_rgb(0x00ff00)
	}) or { panic(err) }
	assert (color_find(previewing, color_picker_hex_field_id('pick')) or { panic('') }).text == '#00FF00'
	assert (color_find_key(previewing, 'preview') or { panic('') }).accessibility_value == '#00FF00'
}

fn color_picker_collect(el Element) []Element {
	mut out := [el]
	for child in el.children {
		out << color_picker_collect(child)
	}
	return out
}

fn test_color_picker_area_layers_or_bands() {
	value := color_hsva(120, 0.5, 0.5, 1)
	layered := ColorPickerConfig{
		...color_inline(value)
		area_height: 100
	}
	area := color_find(color_picker(layered) or { panic(err) }, 'pick:component:area') or {
		panic('no area')
	}
	if color_picker_banded(layered) {
		// The custom renderer draws bands even when not asked to.
		assert area.children.len > 8
	} else {
		// Pure hue, white fading out to the right, black fading in downwards.
		assert area.children[0].box.bg == 0x00ff00
		white := area.children[1].box.gradient
		assert white.angle == 0 && white.stops[0].opacity == 1 && white.stops[1].opacity == 0
		black := area.children[2].box.gradient
		assert black.angle == 90 && black.stops[0].opacity == 0 && black.stops[1].opacity == 1
	}
	banded := ColorPickerConfig{
		...layered
		opaque_gradients: true
	}
	assert color_picker_banded(banded)
	bands_el := color_find(color_picker(banded) or { panic(err) }, 'pick:component:area') or {
		panic('no area')
	}
	count := color_picker_area_bands(100)
	assert count >= 25 && count <= 50
	bands := bands_el.children[..count]
	r := color_picker_metrics(.medium).thumb / 2
	assert bands[0].frame.y == r
	last := bands[count - 1]
	assert color_near(last.frame.y + last.frame.height, r + 100)
	for index, band in bands {
		stops := band.box.gradient.stops
		assert stops.len == 2
		assert stops.all(it.opacity == 1)
		v := 1 - (f64(index) + 0.5) / f64(count)
		assert stops[0].color == color_hsva(120, 0, v, 1).rgb()
		assert stops[1].color == color_hsva(120, 1, v, 1).rgb()
		if index > 0 {
			// Each band starts where the previous one would end, overlapping it.
			prev := bands[index - 1]
			assert prev.frame.y + prev.frame.height > band.frame.y
		}
	}
}

fn test_color_picker_alpha_track_composites_without_per_stop_opacity() {
	config := ColorPickerConfig{
		...color_inline(color_from_rgba(0x3366ff, 0.5))
		opaque_gradients: true
	}
	assert color_picker_composited(config)
	layout := color_picker_layout(config)
	track := layout.sliders[1].track
	cells := color_picker_alpha_track(config, rect(0, 0, track.width, track.height), 0x3366ff)
	light, dark := color_picker_checker_colors(config.theme)
	assert cells.len == int(math.ceil(track.width / 5)) * 2
	mut covered := 0.0
	for index, cell in cells {
		stops := cell.box.gradient.stops
		assert stops.all(it.opacity == 1)
		row := if cell.frame.y > 0 { 1 } else { 0 }
		col := int(math.round(cell.frame.x / 5))
		base := if (row + col) % 2 == 0 { light } else { dark }
		assert stops[0].color == color_over(0x3366ff, cell.frame.x / track.width, base), '${index}'
		assert stops[1].color == color_over(0x3366ff, (cell.frame.x + cell.frame.width) / track.width,
			base)
		if row == 0 {
			covered += cell.frame.width
		}
	}
	assert color_near(covered, track.width)
	// Layered: a checkerboard under one gradient from clear to opaque.
	layered := color_picker_alpha_track(ColorPickerConfig{
		...config
		opaque_gradients: false
	}, rect(0, 0, 100, 10), 0x3366ff)
	if !color_picker_composited(ColorPickerConfig{
		...config
		opaque_gradients: false
	}) {
		overlay := layered[layered.len - 1].box.gradient
		assert overlay.stops[0].opacity == 0 && overlay.stops[1].opacity == 1
		assert layered[0].box.bg == light
	}
}

fn test_color_picker_hue_gradient_is_exact() {
	g := color_picker_hue_gradient()
	assert g.stops.len == 7
	stops := gradient_sorted_stops(g)
	for i in 0 .. 361 {
		t := f64(i) / 360
		color, alpha := gradient_color_at(stops, t)
		assert alpha == 1
		expected := color_hsva(f64(i), 1, 1, 1).rgb()
		for shift in [u32(16), 8, 0] {
			a := int((color >> shift) & 0xff)
			b := int((expected >> shift) & 0xff)
			assert math.abs(a - b) <= 1, '${i}: ${color:06x} vs ${expected:06x}'
		}
	}
}

fn test_color_picker_focus_ring_and_disabled() {
	focused := color_picker(ColorPickerConfig{
		...color_inline(color_from_rgb(0x3366ff))
		focused_part: .hue
	}) or { panic(err) }
	hue := color_find(focused, 'pick:component:hue') or { panic('') }
	plain := color_find(color_picker(color_inline(color_from_rgb(0x3366ff))) or { panic(err) },
		'pick:component:hue') or { panic('') }
	assert hue.children.len == plain.children.len + 1
	disabled := color_picker(ColorPickerConfig{
		...color_inline(color_from_rgb(0x3366ff))
		enabled: false
	}) or { panic(err) }
	for part in ['area', 'hue', 'alpha', 'swatch:f:0', 'hex'] {
		found := color_find(disabled, 'pick:component:${part}') or { panic(part) }
		assert !found.enabled, part
	}
}

fn test_color_picker_validation() {
	base := color_inline(color_from_rgb(0x3366ff))
	bad := [
		ColorPickerConfig{
			...base
			id: ' '
		},
		ColorPickerConfig{
			...base
			frame: rect(0, 0, -1, 10)
		},
		ColorPickerConfig{
			...base
			origin_x: math.nan()
		},
		ColorPickerConfig{
			...base
			area_height: -1
		},
		ColorPickerConfig{
			...base
			panel_width: 0
		},
		ColorPickerConfig{
			...base
			icon: 'no.such.symbol'
		},
		ColorPickerConfig{
			...base
			featured: []u32{len: color_picker_max_swatches + 1}
		},
		ColorPickerConfig{
			...base
			window: rect(0, 0, math.inf(1), 10)
		},
	]
	for config in bad {
		if _ := color_picker(config) {
			assert false, 'accepted ${config.id} ${config.frame} ${config.icon}'
		}
		if _ := color_picker_popover(config) {
			assert false, 'popover accepted ${config.id}'
		}
	}
	color_picker(ColorPickerConfig{
		...base
		icon:    'paintbrush'
		variant: .swatch
	}) or { panic(err) }
}

// ── Pointer events ──────────────────────────────────────────────────

fn test_color_picker_pointer_maps_window_points_onto_parts() {
	value := color_hsva(200, 0.5, 0.5, 0.8)
	base := ColorPickerConfig{
		...color_inline(value)
		origin_x: 100
		origin_y: 50
	}
	area := color_picker_part_frame(base, .area) or { panic('no area') }
	layout := color_picker_layout(base)
	// The frame is offset by the origin and the panel's position.
	assert area.x == 100 + 20 + layout.area.x && area.y == 50 + 30 + layout.area.y
	action := 'pick:component:area'
	top_right := color_picker_event(base, color_pointer('down', action, area.x + area.width,
		area.y)) or { panic('no event') }
	assert top_right.kind == .change && top_right.part == .area && !top_right.done
	assert top_right.value.s == 1 && top_right.value.v == 1
	assert top_right.value.h == 200 && top_right.value.a == 0.8
	middle := color_picker_value_from_pointer(base, color_pointer('drag', action, area.x +
		area.width / 4, area.y + area.height * 0.75)) or { panic('no value') }
	assert color_near(middle.s, 0.25) && color_near(middle.v, 0.25)
	// Points outside clamp to the edge, so a drag can leave the area.
	outside := color_picker_value_from_pointer(base, color_pointer('drag', action, area.x - 500,
		area.y + 9000)) or { panic('no value') }
	assert outside.s == 0 && outside.v == 0
	released := color_picker_event(base, color_pointer('up', action, area.x, area.y)) or {
		panic('no up')
	}
	assert released.done
	hue := color_picker_part_frame(base, .hue) or { panic('no hue') }
	end := color_picker_value_from_pointer(base, color_pointer('down', 'pick:component:hue',
		hue.x + hue.width + 40, hue.y)) or { panic('no hue value') }
	assert end.h == 360 && end.s == 0.5
	quarter := color_picker_value_from_pointer(base, color_pointer('drag', 'pick:component:hue',
		hue.x + hue.width / 4, hue.y)) or { panic('no hue value') }
	assert quarter.h == 90
	alpha := color_picker_part_frame(base, .alpha) or { panic('no alpha') }
	clear := color_picker_value_from_pointer(base, color_pointer('drag', 'pick:component:alpha',
		alpha.x, alpha.y)) or { panic('no alpha value') }
	assert clear.a == 0 && clear.h == 200
}

fn test_color_picker_pointer_on_the_sliders_panel() {
	value := color_from_hsla(30, 0.5, 0.5, 1)
	config := ColorPickerConfig{
		...color_inline(value)
		panel: .sliders
	}
	saturation := color_picker_part_frame(config, .saturation) or { panic('no saturation') }
	full := color_picker_value_from_pointer(config, color_pointer('down', 'pick:component:saturation',
		saturation.x + saturation.width, saturation.y)) or { panic('no value') }
	assert color_close(full.hsla().s, 1, 1e-9) && color_close(full.hsla().l, 0.5, 1e-9)
	lightness := color_picker_part_frame(config, .lightness) or { panic('no lightness') }
	black := color_picker_value_from_pointer(config, color_pointer('down', 'pick:component:lightness',
		lightness.x, lightness.y)) or { panic('no value') }
	assert black.v == 0 && black.h == 30
	// Lightness back up from black keeps the saturation.
	back := color_picker_value_from_pointer(ColorPickerConfig{
		...config
		value: black
	}, color_pointer('down', 'pick:component:lightness', lightness.x + lightness.width / 2,
		lightness.y)) or { panic('no value') }
	assert color_close(back.hsla().s, 0.5, 1e-9)
	// The area is not on this panel.
	if _ := color_picker_event(config, color_pointer('down', 'pick:component:area', 0, 0)) {
		assert false, 'area accepted on the sliders panel'
	}
}

fn test_color_picker_pointer_rejections() {
	value := color_hsva(200, 0.5, 0.5, 1)
	base := color_inline(value)
	area := color_picker_part_frame(base, .area) or { panic('') }
	x := area.x + area.width / 2
	y := area.y + area.height / 2
	// A drag that does not change the color is dropped; a press and a release
	// are kept.
	if _ := color_picker_event(base, color_pointer('drag', 'pick:component:area', x, y)) {
		assert false, 'no-op drag reported'
	}
	assert color_picker_event(base, color_pointer('down', 'pick:component:area', x, y)) != none
	assert color_picker_event(base, color_pointer('up', 'pick:component:area', x, y)) != none
	for event in [
		color_pointer('down', 'other:component:area', x, y),
		color_pointer('down', 'pick:component:nope', x, y),
		color_pointer('down', 'pick:component:', x, y),
		color_pointer('enter', 'pick:component:area', x, y),
		color_pointer('down', 'pick:component:swatch:f:0', x, y),
		'pointer:down:pick:component:area:x:1',
		'pointer:down:pick:component:area:1',
		'pick:component:area',
		'',
	] {
		if got := color_picker_event(base, event) {
			assert false, '`${event}` decoded as ${got.kind}'
		}
	}
	// No alpha slider, no alpha events.
	no_alpha := ColorPickerConfig{
		...base
		alpha: false
	}
	if _ := color_picker_value_at(no_alpha, .alpha, x, y) {
		assert false, 'alpha without the slider'
	}
	if _ := color_picker_value_at(base, .hue, math.nan(), y) {
		assert false, 'NaN accepted'
	}
	disabled := ColorPickerConfig{
		...base
		enabled: false
	}
	if _ := color_picker_event(disabled, color_pointer('down', 'pick:component:area', x, y)) {
		assert false, 'disabled picker reported'
	}
}

// ── Actions ─────────────────────────────────────────────────────────

fn test_color_picker_swatch_actions() {
	value := color_from_rgba(0x3366ff, 0.4)
	base := color_inline(value)
	featured := color_default_featured()
	picked := color_picker_event(base, 'pick:component:swatch:f:2') or { panic('no select') }
	assert picked.kind == .select
	// The swatch's color with the current alpha.
	assert picked.value.rgb() == featured[2] && color_near(picked.value.a, 0.4)
	assert !picked.open
	// Picking white keeps the hue a gray cannot carry.
	white := color_picker_event(base, 'pick:component:swatch:f:10') or { panic('no white') }
	assert white.value.rgb() == 0xffffff && white.value.h == value.h
	// Palette swatches are only on the palette panel.
	if _ := color_picker_event(base, 'pick:component:swatch:p:1:3') {
		assert false, 'palette swatch on the spectrum panel'
	}
	palette := ColorPickerConfig{
		...base
		panel: .palette
	}
	red := color_picker_event(palette, 'pick:component:swatch:p:1:3') or { panic('no palette') }
	assert red.value.rgb() == color_default_palettes()[1].colors[3]
	for forged in ['pick:component:swatch:f:11', 'pick:component:swatch:f:-1',
		'pick:component:swatch:f:01', 'pick:component:swatch:p:9:0', 'pick:component:swatch:p:1:11',
		'pick:component:swatch:', 'pick:component:swatch:x'] {
		if _ := color_picker_event(palette, forged) {
			assert false, '`${forged}` accepted'
		}
	}
	// The spectrum panel only shows the first row of featured colors.
	many := ColorPickerConfig{
		...base
		featured: []u32{len: 14, init: u32(index * 0x101010)}
	}
	if _ := color_picker_event(many, 'pick:component:swatch:f:12') {
		assert false, 'hidden featured color accepted'
	}
	assert color_picker_event(ColorPickerConfig{
		...many
		panel: .palette
	}, 'pick:component:swatch:f:12') != none
	// Without alpha, a swatch selects an opaque color.
	opaque := color_picker_event(ColorPickerConfig{
		...base
		alpha: false
	}, 'pick:component:swatch:f:0') or { panic('') }
	assert opaque.value.a == 1
	// Hovering a swatch previews it.
	enter := color_picker_event(base, color_pointer('enter', 'pick:component:swatch:f:1',
		10, 10)) or { panic('no preview') }
	assert enter.kind == .preview && enter.value.rgb() == featured[1]
	leave := color_picker_event(base, color_pointer('leave', 'pick:component:swatch:f:1',
		10, 10)) or { panic('no preview end') }
	assert leave.kind == .preview_end
}

fn test_color_picker_tab_hex_and_trigger_actions() {
	base := color_inline(color_from_rgb(0x3366ff))
	tab := color_picker_event(base, 'pick:component:panel:palette') or { panic('no tab') }
	assert tab.kind == .panel && tab.panel == .palette
	for rejected in ['pick:component:panel:spectrum', 'pick:component:panel:nope',
		'pick:component:panel:'] {
		if _ := color_picker_event(base, rejected) {
			assert false, '`${rejected}` accepted'
		}
	}
	if _ := color_picker_event(ColorPickerConfig{
		...base
		panels: [ColorPickerPanel.spectrum, .sliders]
	}, 'pick:component:panel:palette') {
		assert false, 'a panel that is not a tab was chosen'
	}
	edit := color_picker_event(base, color_picker_hex_field_id('pick')) or { panic('no edit') }
	assert edit.kind == .hex_change
	submit := color_picker_event(base, 'pick:component:hex:submit') or { panic('no submit') }
	assert submit.kind == .hex_submit && !submit.open
	// The inline panel has no trigger and nothing to dismiss.
	for inline_only in ['pick:component:trigger', 'pick:component:dismiss', 'pick:component:panel'] {
		if _ := color_picker_event(base, inline_only) {
			assert false, '`${inline_only}` accepted inline'
		}
	}
	closed := ColorPickerConfig{
		...base
		variant: .swatch
	}
	toggle := color_picker_event(closed, 'pick:component:trigger') or { panic('no toggle') }
	assert toggle.kind == .toggle && toggle.open
	// While closed, nothing inside the panel reaches the application.
	for hidden in ['pick:component:dismiss', 'pick:component:swatch:f:0',
		color_picker_hex_field_id('pick'), 'pick:component:panel:palette'] {
		if _ := color_picker_event(closed, hidden) {
			assert false, '`${hidden}` accepted while closed'
		}
	}
	open := ColorPickerConfig{
		...closed
		open: true
	}
	assert (color_picker_event(open, 'pick:component:trigger') or { panic('') }).open == false
	dismiss := color_picker_event(open, 'pick:component:dismiss') or { panic('no dismiss') }
	assert dismiss.kind == .dismiss && !dismiss.open
	kept := color_picker_event(open, 'pick:component:panel:sliders') or { panic('') }
	assert kept.open
	assert !(color_picker_event(open, 'pick:component:swatch:f:0') or { panic('') }).open
	disabled := ColorPickerConfig{
		...open
		enabled: false
	}
	if _ := color_picker_event(disabled, 'pick:component:trigger') {
		assert false, 'disabled trigger toggled'
	}
}

fn test_color_picker_hex_value() {
	value := color_hsva(210, 0.5, 0.5, 0.5)
	config := color_inline(value)
	typed := color_picker_hex_value(config, '#ff0000') or { panic('no value') }
	assert typed.rgb() == 0xff0000 && typed.a == 1
	short := color_picker_hex_value(config, 'f00c') or { panic('no value') }
	assert short.rgb() == 0xff0000 && color_near(short.a, f64(0xcc) / 255)
	gray := color_picker_hex_value(config, '#808080') or { panic('no value') }
	assert gray.h == 210 && gray.s == 0
	// The hex the picker shows gives the picker back its own state.
	same := color_picker_hex_value(config, value.hex()) or { panic('no value') }
	assert same.h == value.h && same.s == value.s && same.v == value.v
	assert color_alpha_byte(same.a) == color_alpha_byte(value.a)
	opaque := color_picker_hex_value(ColorPickerConfig{
		...config
		alpha: false
	}, '#ff000080') or { panic('no value') }
	assert opaque.a == 1
	for partial in ['#', '#ff', '#ff00', '#ff000', 'red'] {
		if partial == '#ff00' {
			// Four digits are #rgba.
			assert color_picker_hex_value(config, partial) != none
			continue
		}
		if _ := color_picker_hex_value(config, partial) {
			assert false, '`${partial}` accepted'
		}
	}
}

// ── Keyboard ────────────────────────────────────────────────────────

fn test_color_picker_keys_nudge_the_focused_part() {
	value := color_hsva(200, 0.5, 0.5, 0.5)
	config := color_inline(value)
	right := color_picker_value_after_key(config, .area, color_key(.right)) or { panic('') }
	assert color_near(right.s, 0.51) && right.v == 0.5
	up := color_picker_value_after_key(config, .area, KeyEvent{
		code:  .up
		shift: true
	}) or { panic('') }
	assert color_near(up.v, 0.6) && up.s == 0.5
	down := color_picker_value_after_key(config, .area, color_key(.down)) or { panic('') }
	assert color_near(down.v, 0.49)
	hue := color_picker_value_after_key(config, .hue, color_key(.right)) or { panic('') }
	assert hue.h == 201
	big := color_picker_value_after_key(config, .hue, KeyEvent{
		code:  .left
		shift: true
	}) or { panic('') }
	assert big.h == 190
	assert (color_picker_value_after_key(config, .hue, color_key(.home)) or { panic('') }).h == 0
	assert (color_picker_value_after_key(config, .hue, color_key(.end)) or { panic('') }).h == 360
	// Hue stops at the ends of its slider.
	at_end := ColorPickerConfig{
		...config
		value: color_hsva(360, 1, 1, 1)
	}
	if _ := color_picker_value_after_key(at_end, .hue, color_key(.right)) {
		assert false, 'hue stepped past 360'
	}
	alpha := color_picker_value_after_key(config, .alpha, color_key(.left)) or { panic('') }
	assert color_near(alpha.a, 0.49)
	// Off-grid values snap to whole percent.
	odd := ColorPickerConfig{
		...config
		value: color_hsva(200, 0.4637, 0.5, 1)
	}
	assert color_near((color_picker_value_after_key(odd, .area, color_key(.right)) or {
		panic('')
	}).s, 0.47)
	sliders := ColorPickerConfig{
		...config
		panel: .sliders
	}
	lighter := color_picker_value_after_key(sliders, .lightness, color_key(.up)) or { panic('') }
	assert color_close(lighter.hsla().l, value.hsla().l + 0.01, 0.0051)
	desaturated := color_picker_value_after_key(sliders, .saturation, color_key(.home)) or {
		panic('')
	}
	assert desaturated.hsla().s == 0 && desaturated.h == 200
	for event in [KeyEvent{
		code: .right
		cmd:  true
	}, KeyEvent{
		code: .right
		ctrl: true
	}, KeyEvent{
		code: .right
		alt:  true
	}, color_key(.a), color_key(.enter)] {
		if _ := color_picker_value_after_key(config, .hue, event) {
			assert false, '${event} nudged'
		}
	}
	// Parts not on the current panel, a missing alpha slider and disabled
	// pickers ignore keys.
	if _ := color_picker_value_after_key(config, .lightness, color_key(.up)) {
		assert false, 'lightness on the spectrum panel'
	}
	if _ := color_picker_value_after_key(ColorPickerConfig{
		...config
		alpha: false
	}, .alpha, color_key(.up)) {
		assert false, 'alpha without a slider'
	}
	if _ := color_picker_value_after_key(ColorPickerConfig{
		...config
		enabled: false
	}, .hue, color_key(.up)) {
		assert false, 'disabled picker nudged'
	}
	// Home on the area does nothing.
	if _ := color_picker_value_after_key(config, .area, color_key(.home)) {
		assert false, 'home moved the area'
	}
}

fn test_color_picker_escape_dismisses_an_open_popover() {
	open := ColorPickerConfig{
		...color_inline(color_from_rgb(0x3366ff))
		variant: .field
		open:    true
	}
	assert color_picker_dismiss_on_key(open, color_key(.escape))
	assert !color_picker_dismiss_on_key(open, KeyEvent{
		code:  .escape
		shift: true
	})
	assert !color_picker_dismiss_on_key(open, color_key(.enter))
	assert !color_picker_dismiss_on_key(ColorPickerConfig{
		...open
		open: false
	}, color_key(.escape))
	assert !color_picker_dismiss_on_key(ColorPickerConfig{
		...open
		variant: .inline
	}, color_key(.escape))
}

// ── Triggers and popover ────────────────────────────────────────────

fn test_color_picker_popover_frame_placement() {
	window := rect(0, 0, 800, 600)
	anchor := rect(100, 100, 120, 32)
	assert color_picker_popover_frame(anchor, window, 288, 300, .top_left) == rect(100, 136,
		288, 300)
	assert color_picker_popover_frame(anchor, window, 288, 300, .top_right) == rect(8, 136,
		288, 300)
	// No room above: bottom anchors open downwards instead.
	assert color_picker_popover_frame(anchor, window, 288, 300, .bottom_left) == rect(100,
		136, 288, 300)
	low := rect(100, 500, 120, 32)
	assert color_picker_popover_frame(low, window, 288, 300, .top_left) == rect(100, 196, 288,
		300)
	assert color_picker_popover_frame(low, window, 288, 300, .bottom_right) == rect(8, 196,
		288, 300)
	// Slid back inside the right edge.
	right := rect(700, 100, 40, 32)
	assert color_picker_popover_frame(right, window, 288, 300, .top_left).x == 800 - 8 - 288
	// Taller than the window: the top wins.
	assert color_picker_popover_frame(anchor, window, 288, 900, .top_left).y == 8
	// Neither side has room: the roomier side, then clamped.
	middle := rect(100, 280, 120, 32)
	assert color_picker_popover_frame(middle, window, 288, 400, .top_left).y == 600 - 8 - 400
	// Without a window the popover is placed as anchored, unclamped.
	assert color_picker_popover_frame(right, Rect{}, 288, 300, .bottom_left) == rect(700, 96 - 300,
		288, 300)
}

fn test_color_picker_triggers() {
	value := color_from_rgba(0x3366ff, 0.5)
	swatch_config := ColorPickerConfig{
		id:      'bg'
		frame:   rect(10, 10, 140, 32)
		value:   value
		variant: .swatch
		label:   'Background'
	}
	trigger := color_picker(swatch_config) or { panic(err) }
	assert trigger.id == 'bg' && trigger.button_behavior
	assert trigger.action_id == 'bg:component:trigger'
	assert trigger.accessibility_label == 'Background'
	assert trigger.accessibility_value == value.hex()
	color_assert_inside(trigger)
	labels := color_picker_collect(trigger).filter(it.kind == .label)
	assert labels.len == 1 && labels[0].text == 'Background'
	// A translucent color is drawn over a checkerboard.
	assert color_picker_collect(trigger).filter(it.box.opacity < 1).len == 1
	icon := color_picker(ColorPickerConfig{
		...swatch_config
		icon:  'paintbrush'
		label: ''
	}) or { panic(err) }
	assert color_picker_collect(icon).filter(it.image_path == 'symbol:paintbrush').len == 1
	assert icon.tooltip == value.hex()
	field := color_picker(ColorPickerConfig{
		...swatch_config
		variant: .field
		frame:   rect(0, 0, 240, 32)
	}) or { panic(err) }
	assert field.accessibility_role == 'combobox'
	field_labels := color_picker_collect(field).filter(it.kind == .label)
	assert field_labels.len == 1 && field_labels[0].text == value.hex()
	assert color_picker_collect(field).filter(it.image_path == 'symbol:chevron.down').len == 1
	color_assert_inside(field)
	empty_field := color_picker(ColorPickerConfig{
		...swatch_config
		variant:     .field
		empty:       true
		placeholder: 'Pick a color'
	}) or { panic(err) }
	assert color_picker_collect(empty_field).filter(it.kind == .label)[0].text == 'Pick a color'
	assert empty_field.accessibility_value == 'none'
}

fn test_color_picker_popover_element() {
	config := ColorPickerConfig{
		id:       'bg'
		frame:    rect(10, 20, 140, 32)
		origin_x: 30
		origin_y: 40
		value:    color_from_rgb(0x3366ff)
		variant:  .swatch
		window:   rect(0, 0, 900, 700)
	}
	closed := color_picker_popover(config) or { panic(err) }
	assert closed.hidden && closed.children.len == 0 && closed.id == 'bg:component:popover'
	inline := color_picker_popover(color_inline(color_from_rgb(0x3366ff))) or { panic(err) }
	assert inline.hidden
	open := ColorPickerConfig{
		...config
		open: true
	}
	el := color_picker_popover(open) or { panic(err) }
	assert !el.hidden && el.id == 'bg:component:popover'
	assert el.frame == rect(0, 0, 900, 700)
	backdrop := el.children[0]
	assert backdrop.id == 'bg:component:dismiss' && backdrop.button_behavior
	assert backdrop.frame == rect(0, 0, 900, 700)
	panel := el.children[1]
	expected := color_picker_popover_frame(rect(40, 60, 140, 32), open.window, 288, color_picker_height(open),
		.top_left)
	assert panel.frame == expected
	assert panel.frame == color_picker_panel_frame(open)
	assert panel.accessibility_role == 'dialog' && panel.button_behavior
	assert panel.box.shadow.opacity > 0
	color_assert_inside(panel)
	// The area in the popover maps window points through the placement.
	area := color_picker_part_frame(open, .area) or { panic('no area') }
	assert area.x == expected.x + 12
	corner := color_picker_value_from_pointer(open, color_pointer('down', 'bg:component:area',
		area.x, area.y + area.height)) or { panic('no value') }
	assert corner.s == 0 && corner.v == 0
	// Without a window there is no backdrop and the popover is the panel.
	bare := color_picker_popover(ColorPickerConfig{
		...open
		window: Rect{}
	}) or { panic(err) }
	assert bare.children.len == 1 && bare.frame == color_picker_panel_frame(ColorPickerConfig{
		...open
		window: Rect{}
	})
	assert bare.children[0].frame.x == 0 && bare.children[0].frame.y == 0
	// A disabled picker does not open.
	assert (color_picker_popover(ColorPickerConfig{
		...open
		enabled: false
	}) or { panic(err) }).hidden
}

fn test_color_picker_without_alpha_writes_opaque_hex() {
	config := ColorPickerConfig{
		...color_inline(color_from_rgba(0x3366ff, 0.5))
		alpha: false
	}
	el := color_picker(config) or { panic(err) }
	assert (color_find(el, color_picker_hex_field_id('pick')) or { panic('') }).text == '#3366FF'
	assert el.accessibility_value == '#3366FF'
	if _ := color_find(el, 'pick:component:alpha') {
		assert false, 'alpha slider without alpha'
	}
	field := color_picker(ColorPickerConfig{
		...config
		variant: .field
		frame:   rect(0, 0, 200, 32)
	}) or { panic(err) }
	assert color_picker_collect(field).filter(it.kind == .label)[0].text == '#3366FF'
	// Translucency is not drawn either.
	assert color_picker_collect(field).filter(it.box.opacity < 1).len == 0
}
