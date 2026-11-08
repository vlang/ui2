module ui2

import math

fn test_gradient_colors_interpolate_between_sorted_stops() {
	stops := gradient_sorted_stops(linear_gradient(0, gradient_stop(0xffffff, 1), gradient_stop(0x000000,
		0), GradientStop{ color: 0xff0000, position: 0.5, opacity: 0.5 }))
	assert stops.map(it.position) == [0.0, 0.5, 1.0]
	mut color, mut opacity := gradient_color_at(stops, 0)
	assert color == 0x000000 && opacity == 1
	color, opacity = gradient_color_at(stops, 0.25)
	assert color == 0x800000 && opacity == 0.75
	color, opacity = gradient_color_at(stops, 0.75)
	assert color == 0xff8080 && opacity == 0.75
	color, _ = gradient_color_at(stops, 2)
	assert color == 0xffffff
	// A hard stop: both sides of 0.5 keep their own colors.
	hard := gradient_sorted_stops(linear_gradient(0, gradient_stop(0x0000ff, 0), gradient_stop(0x0000ff,
		0.5), gradient_stop(0x00ff00, 0.5), gradient_stop(0x00ff00, 1)))
	color, _ = gradient_color_at(hard, 0.49)
	assert color == 0x0000ff
	color, _ = gradient_color_at(hard, 0.51)
	assert color == 0x00ff00
}

fn test_gradient_line_reaches_the_corners_like_css() {
	horizontal := gradient_line(0, 200, 100)
	assert math.abs(gradient_position(horizontal, 0, 50)) < 1e-9
	assert math.abs(gradient_position(horizontal, 200, 0) - 1) < 1e-9
	vertical := gradient_line(90, 200, 100)
	assert math.abs(gradient_position(vertical, 100, 0)) < 1e-9
	assert math.abs(gradient_position(vertical, 0, 100) - 1) < 1e-9
	diagonal := gradient_line(45, 100, 100)
	assert math.abs(gradient_position(diagonal, 0, 0)) < 1e-9
	assert math.abs(gradient_position(diagonal, 100, 100) - 1) < 1e-9
	assert math.abs(gradient_position(diagonal, 100, 0) - 0.5) < 1e-9
}

fn test_box_effects_defaults_change_nothing() {
	plain := BoxStyle{}
	assert box_fill_opacity(plain) == 1
	assert !box_has_gradient(plain)
	assert !box_has_shadow(plain)
	assert box_fill_opacity(BoxStyle{ transparent: true }) == 0
	assert box_fill_opacity(BoxStyle{ opacity: 7 }) == 1
	assert box_fill_opacity(BoxStyle{ opacity: math.nan() }) == 0
	assert !box_has_gradient(BoxStyle{ gradient: linear_gradient(0, gradient_stop(0, 0)) })
	assert box_has_shadow(BoxStyle{ shadow: box_shadow(0, 0.3, 8, 2) })
}

fn test_box_effects_numbers_are_animatable() {
	assert is_animatable_property('box.opacity', .number)
	assert is_animatable_property('box.shadow.opacity', .number)
	assert is_animatable_property('box.shadow.blur', .number)
	assert is_animatable_property('box.shadow.color', .color)
}

fn test_box_effects_animate_through_the_generic_api() {
	el := view('fade', rect(0, 0, 10, 10), BoxStyle{
		opacity: 1
		shadow:  box_shadow(0x000000, 0, 0, 0)
	}, []Element{})
	faded := set_number_animation_property(el, 'box.opacity', 0.25)
	assert faded.box.opacity == 0.25
	lifted := set_number_animation_property(el, 'box.shadow.blur', 16)
	assert lifted.box.shadow.blur == 16
	assert animation_number_property_value(lifted, 'box.shadow.blur') == 16
	tinted := set_color_animation_property(el, 'box.shadow.color', 0x2563eb)
	assert animation_color_property_value(tinted, 'box.shadow.color') == 0x2563eb
}

fn test_box_rounded_border_needs_a_radius_and_even_sides() {
	even := BoxStyle{
		radius:        8
		border_left:   2
		border_top:    2
		border_right:  2
		border_bottom: 2
	}
	assert box_rounded_border(even) == 2
	assert box_rounded_border(BoxStyle{ ...even, radius: 0 }) == 0
	assert box_rounded_border(BoxStyle{ ...even, border_bottom: 1 }) == 0
	assert box_rounded_border(BoxStyle{ radius: 8 }) == 0
}

fn test_zero_lines_reach_the_renderers_as_unlimited() {
	wrapped := label('l', 'text', rect(0, 0, 10, 10), TextStyle{ lines: 0 })
	single := label('s', 'text', rect(0, 0, 10, 10), TextStyle{})
	root := apply_widget_animations(screen(0xffffff, [wrapped, single,
		label('n', 'text', rect(0, 0, 10, 10), TextStyle{ lines: -3 })]))
	assert root.children[0].text_style.lines == text_lines_unlimited
	assert root.children[1].text_style.lines == 1
	assert root.children[2].text_style.lines == text_lines_unlimited
}

fn test_scrollbar_colors_follow_a_dark_backdrop() {
	// Light backdrops keep the familiar light grays.
	track, thumb := scrollbar_colors(0xffffff)
	assert track == 0xf1f5f9 && thumb == 0xcbd5e1
	// A dark backdrop gets lighter shades of itself, the thumb lighter than the track.
	dark_track, dark_thumb := scrollbar_colors(0x0f172a)
	assert dark_track != 0xf1f5f9
	assert (dark_track & 0xff) > 0x2a && (dark_thumb & 0xff) > (dark_track & 0xff)
	assert scrollbar_tint(0x000000, 1.0) == 0xffffff
	assert scrollbar_tint(0x102030, 0) == 0x102030
}

fn test_gradient_unit_points_keep_bands_perpendicular_on_a_wide_box() {
	w, h := 300.0, 100.0
	line := gradient_line(45, w, h)
	sx, sy, ex, ey := gradient_unit_points(line, w, h)
	ux, uy := ex - sx, ey - sy
	// Where CoreAnimation puts a point along its unit-square line has to match
	// where the gradient line in points puts it, all over the box.
	for p in [[0.0, 0.0], [300.0, 100.0], [150.0, 50.0], [300.0, 0.0], [40.0, 90.0]] {
		ca := ((p[0] / w - sx) * ux + (p[1] / h - sy) * uy) / (ux * ux + uy * uy)
		assert math.abs(unit_clamp(ca) - gradient_position(line, p[0], p[1])) < 1e-9
	}
	// A square box keeps the plain fractions.
	square := gradient_line(30, 100, 100)
	a, b, c, d := gradient_unit_points(square, 100, 100)
	assert math.abs(a - square.x0 / 100) < 1e-12 && math.abs(c - square.x1 / 100) < 1e-12
	assert math.abs(b - square.y0 / 100) < 1e-12 && math.abs(d - square.y1 / 100) < 1e-12
}
