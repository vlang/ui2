module ui2

import math
import time

// ── Helpers ────────────────────────────────────────────────────────

fn plot_test_close(a f64, b f64) bool {
	return math.abs(a - b) < 1e-6
}

fn plot_test_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := plot_test_find(child, id) {
			return found
		}
	}
	return none
}

fn plot_test_ids(el Element, prefix string) []string {
	mut ids := []string{}
	if el.id.starts_with(prefix) {
		ids << el.id
	}
	for child in el.children {
		ids << plot_test_ids(child, prefix)
	}
	return ids
}

// plot_test_points are the end points of a path's commands.
fn plot_test_points(path []PathCommand) []PathPoint {
	mut out := []PathPoint{}
	for cmd in path {
		if cmd.verb != .close {
			out << path_point(cmd.x, cmd.y)
		}
	}
	return out
}

// plot_test_hit is what CSS :hover (and so every backend) takes as hovered at
// window point (x, y): the topmost element there, drawn last, and the
// hoverable actions of it and its ancestors.
fn plot_test_hit(el Element, ox f64, oy f64, x f64, y f64, chain []string, mut hit []string) {
	if el.hidden {
		return
	}
	ax, ay := ox + el.frame.x, oy + el.frame.y
	mut own := chain.clone()
	if el.hoverable {
		own << element_action_id(el)
	}
	if x >= ax && x < ax + el.frame.width && y >= ay && y < ay + el.frame.height {
		hit.clear()
		hit << own
	}
	for child in el.children {
		plot_test_hit(child, ax, ay, x, y, own, mut hit)
	}
}

fn plot_test_polygon_area(points []PathPoint) f64 {
	return math.abs(path_signed_area(points))
}

const plot_test_months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']

fn plot_test_series() []PlotSeries {
	return [
		PlotSeries{
			key:    'desktop'
			name:   'Desktop'
			values: [186.0, 305, 237, 73, 209, 214]
		},
		PlotSeries{
			key:    'mobile'
			values: [80.0, 200, 120, 190, 130, 140]
		},
	]
}

// ── Numbers and colors ─────────────────────────────────────────────

fn test_plot_number_formatting() {
	assert plot_format_number(1284, 0) == '1,284'
	assert plot_format_number(-1234567.891, 2) == '-1,234,567.89'
	assert plot_format_number(0.25, 2) == '0.25'
	assert plot_format_number(999.995, 2) == '1,000.00'
	assert plot_format_number(-0.0001, 2) == '0.00'
	assert plot_format_number(math.nan(), 2) == ''
	assert plot_format_compact(950) == '950'
	assert plot_format_compact(1000) == '1K'
	assert plot_format_compact(12900) == '12.9K'
	assert plot_format_compact(-4200000) == '-4.2M'
	assert plot_format_compact(999999) == '1M'
	assert plot_format_compact(2.5) == '2.5'
	assert plot_format_percent(0.25) == '25%'
	assert plot_format_percent(0.125) == '12.5%'
	assert plot_format_value(3.14159) == '3.14'
	assert plot_format_value(42) == '42'
	assert plot_tick_decimals(50) == 0
	assert plot_tick_decimals(0.5) == 1
	assert plot_tick_decimals(0.25) == 2
	assert plot_tick_decimals(0.1) == 1
	assert plot_call_format(unsafe { nil }, 2, 'fallback') == 'fallback'
	assert plot_call_format(fn (v f64) string {
		return 'v${v}'
	}, 2, 'fallback') == 'v2.0'
}

fn test_plot_palette_follows_the_theme() {
	light := component_theme(false)
	dark := component_theme(true)
	assert !plot_theme_is_dark(light)
	assert plot_theme_is_dark(dark)
	assert plot_chart_palette(light).len == 8
	assert plot_chart_palette(light) != plot_chart_palette(dark)
	assert plot_chart_color(light, 0) == plot_chart_palette(light)[0]
	assert plot_chart_color(dark, 9) == plot_chart_palette(dark)[1]
	assert plot_chart_color(light, -3) == plot_chart_palette(light)[0]
	// Grid lines sit between the border and the background.
	grid := plot_grid_color(light)
	assert grid != light.border && grid != light.background
}

// ── Scales ─────────────────────────────────────────────────────────

fn test_plot_linear_scale_maps_inverts_and_clamps() {
	s := plot_linear_scale(0, 100, 0, 500)
	assert s.position(50) == 250
	assert s.position(150) == 750
	assert s.invert(250) == 50
	clamped := s.with_clamp(true)
	assert clamped.position(150) == 500
	assert clamped.position(-10) == 0
	assert clamped.invert(900) == 100
	// A y scale runs backwards, larger values higher.
	y := plot_linear_scale(0, 200, 300, 0)
	assert y.position(0) == 300
	assert y.position(200) == 0
	assert y.position(50) == 225
	assert y.invert(225) == 50
	// A domain without extent puts everything in the middle.
	flat := plot_linear_scale(5, 5, 0, 100)
	assert flat.position(5) == 50
	assert flat.position(500) == 50
	assert plot_linear_scale(0, 1, 0, 0).invert(0) == 0
	moved := s.with_range(100, 200)
	assert moved.position(50) == 150
}

fn test_plot_linear_scale_ticks_and_nice_domains() {
	assert plot_tick_step(0, 186, 5) == 50
	assert plot_tick_step(0, 1, 5) == 0.2
	assert plot_tick_step(0, 10, 0) == 0
	assert plot_tick_step(3, 3, 5) == 0
	s := plot_linear_scale(0, 186, 300, 0)
	assert s.ticks(5) == [0.0, 50, 100, 150]
	nice := s.nice(5)
	assert nice.domain_min == 0 && nice.domain_max == 200
	assert nice.range_start == 300
	assert nice.ticks(5) == [0.0, 50, 100, 150, 200]
	// Fractional steps come out exact.
	assert plot_linear_scale(0, 1, 0, 1).ticks(5) == [0.0, 0.2, 0.4, 0.6, 0.8, 1]
	assert plot_linear_scale(0, 0.3, 0, 1).ticks(3) == [0.0, 0.1, 0.2, 0.3]
	// Negative and reversed domains tick in ascending order.
	assert plot_linear_scale(-35, 120, 0, 1).ticks(5) == [-40.0, -20, 0, 20, 40, 60, 80, 100, 120].filter(it >= -35)
	assert plot_linear_scale(120, -35, 0, 1).ticks(4) == [0.0, 50, 100]
	reversed := plot_linear_scale(186, 3, 0, 1).nice(5)
	assert reversed.domain_min == 200 && reversed.domain_max == 0
	assert plot_linear_scale(math.nan(), 1, 0, 1).ticks(5).len == 0
	assert plot_linear_scale(4, 4, 0, 1).ticks(5) == [4.0]
	assert plot_linear_scale(4, 4, 0, 1).nice(5).domain_max == 4
	assert plot_linear_scale(0, 1e9, 0, 1).ticks(2) == [0.0, 5e8, 1e9]
	lo, hi := plot_extent([3.0, math.nan(), -2, math.inf(1)], [0.0])
	assert lo == -2 && hi == 3
	lo2, hi2 := plot_extent([math.nan()], [])
	assert lo2 == 0 && hi2 == 0
}

fn test_plot_band_scale_lays_out_bands_like_d3() {
	// GPUI Kit's own case: three bands across 90 without padding.
	plain := plot_band_scale(['1', '2', '3'], 0, 90)
	assert plain.position('1')? == 0
	assert plain.position('2')? == 30
	assert plain.position('3')? == 60
	assert plain.bandwidth() == 30
	assert plain.step() == 30
	// d3: paddingInner 0.2, paddingOuter 0.1 over [0, 120].
	padded := plot_band_scale(['a', 'b', 'c'], 0, 120).with_padding(0.2, 0.1)
	assert plot_test_close(padded.step(), 40)
	assert plot_test_close(padded.bandwidth(), 32)
	assert plot_test_close(padded.position_at(0), 4)
	assert plot_test_close(padded.position_at(2), 84)
	assert plot_test_close(padded.center_at(1), 60)
	assert padded.position('z') == none
	assert padded.index_of('c')? == 2
	// Repeated values (a grouped chart's rows) are one band each.
	assert plot_band_scale(['a', 'b', 'a', 'b'], 0, 100).band_count() == 2
	// A backwards range runs the bands backwards.
	back := plot_band_scale(['a', 'b', 'c'], 90, 0)
	assert back.position_at(0) == 60
	assert back.position_at(2) == 0
	// band_count keeps the width of a short series.
	full := PlotBandScale{
		domain:        ['a', 'b', 'c', 'd']
		range_end:     100
		padding_inner: 0.4
		padding_outer: 0.2
	}
	short := PlotBandScale{
		...full
		domain: ['a', 'b']
		count:  4
	}
	assert short.bandwidth() == full.bandwidth()
	assert short.position_at(1) == full.position_at(1)
	assert short.nearest_index(full.center_at(3)) == 3
	// A capped band stays centered in its slot.
	capped := PlotBandScale{
		...full
		max_bandwidth: 5
	}
	assert capped.bandwidth() == 5
	assert plot_test_close(capped.center_at(2), full.center_at(2))
	assert full.nearest_index(-50) == 0
	assert full.nearest_index(1000) == 3
	assert PlotBandScale{}.nearest_index(10) == -1
	assert PlotBandScale{}.bandwidth() == 0
}

fn test_plot_point_and_ordinal_scales() {
	p := plot_point_scale(['a', 'b', 'c'], 0, 100)
	assert p.position('a')? == 0
	assert p.position('b')? == 50
	assert p.position('c')? == 100
	assert p.position('d') == none
	assert p.step() == 50
	assert p.nearest_index(70) == 1
	assert p.nearest_index(-10) == 0
	assert p.nearest_index(400) == 2
	// One point sits in the middle; padding keeps the ends in (d3's point
	// padding).
	assert plot_point_scale(['a'], 0, 100).position_at(0) == 50
	padded := PlotPointScale{
		domain:    ['a', 'b', 'c']
		range_end: 120
		padding:   0.5
	}
	assert plot_test_close(padded.step(), 40)
	assert plot_test_close(padded.position_at(0), 20)
	// count lays the axis out for points still to come.
	partial := PlotPointScale{
		domain:    ['a', 'b']
		range_end: 90
		count:     4
	}
	assert partial.position_at(1) == 30
	assert PlotPointScale{}.nearest_index(3) == -1
	colors := PlotOrdinalScale{
		domain:  ['a', 'b', 'c']
		range:   [u32(1), 2]
		unknown: u32(9)
	}
	assert colors.get('a')? == 1
	assert colors.get('c')? == 1
	assert colors.get('z')? == 9
	assert PlotOrdinalScale{
		domain: ['a']
	}.get('a') == none
	assert PlotOrdinalScale{}.get('a') == none
	theme := component_theme(false)
	assert plot_color_scale(['x', 'y'], theme).get('y')? == plot_chart_color(theme, 1)
}

// ── Shapes ─────────────────────────────────────────────────────────

fn test_plot_bars_and_rounded_rects() {
	up := plot_bar_rect(.bottom, 10, 20, 100, 40)
	assert up == rect(10, 40, 20, 60)
	down := plot_bar_rect(.bottom, 10, 20, 100, 130)
	assert down == rect(10, 100, 20, 30)
	across := plot_bar_rect(.left, 5, 12, 0, 80)
	assert across == rect(0, 5, 80, 12)
	assert PlotBarAlignment.right.is_horizontal()
	assert !PlotBarAlignment.top.is_horizontal()
	// The tip is rounded and the base stays square.
	assert plot_tip_corners(.bottom, 4, 100, 40) == PlotCorners{
		top_left:  4
		top_right: 4
	}
	assert plot_tip_corners(.bottom, 4, 100, 130) == PlotCorners{
		bottom_left:  4
		bottom_right: 4
	}
	assert plot_tip_corners(.left, 4, 0, 80) == PlotCorners{
		top_right:    4
		bottom_right: 4
	}
	assert plot_tip_corners(.right, 4, 80, 0) == PlotCorners{
		top_left:    4
		bottom_left: 4
	}
	// min_length grows a short bar away from zero, the way its value points.
	assert plot_bar_tip(100, 100, 2, 0, -1) == 98
	assert plot_bar_tip(100, 101, 2, -3, -1) == 102
	assert plot_bar_tip(100, 40, 2, 60, -1) == 40
	assert plot_bar_tip(100, 100, 0, 0, -1) == 100
	r := rect(2, 3, 10, 20)
	assert plot_rounded_rect_path(r, PlotCorners{}) == path_rect(r)
	rounded := plot_rounded_rect_path(r, plot_corners(100))
	assert rounded.len == 10
	assert path_bounds(rounded) == r
	tip := plot_rounded_rect_path(r, plot_tip_corners(.bottom, 4, 23, 3))
	// Two curves at the top, square corners at the bottom.
	assert tip.filter(it.verb == .cubic_to).len == 2
	assert path_bounds(tip) == r
	assert tip[0] == path_move_to(6, 3)
}

fn test_plot_lines_curves_and_gaps() {
	pts := [path_point(0, 10), path_point(10, 20), path_point(20, 5), path_point(30, 15)]
	linear := plot_line_path(pts, .linear)
	assert linear.len == 4
	assert linear[0].verb == .move_to
	assert plot_test_points(linear) == pts
	smooth := plot_line_path(pts, .smooth)
	assert smooth.len == 4
	assert smooth[1].verb == .cubic_to
	// The curve passes through every point.
	assert plot_test_points(smooth) == pts
	after := plot_line_path(pts[..2], .step_after)
	assert plot_test_points(after) == [path_point(0, 10), path_point(10, 10), path_point(10,
		20)]
	before := plot_line_path(pts[..2], .step_before)
	assert plot_test_points(before) == [path_point(0, 10), path_point(0, 20), path_point(10,
		20)]
	mid := plot_line_path(pts[..2], .step)
	assert plot_test_points(mid) == [path_point(0, 10), path_point(5, 10), path_point(5, 20),
		path_point(10, 20)]
	// A missing value breaks the line in two.
	gappy := plot_line_path([path_point(0, 1), path_point(1, 2), path_point(2, math.nan()),
		path_point(3, 4), path_point(4, 5)], .smooth)
	assert gappy.filter(it.verb == .move_to).len == 2
	assert plot_line_path([]PathPoint{}, .linear).len == 0
	assert plot_line_path([path_point(1, 1)], .smooth) == [path_move_to(1, 1)]
}

fn test_plot_areas_close_to_a_baseline_or_a_lower_series() {
	top := [path_point(0, 10), path_point(10, 5), path_point(20, 8)]
	area := plot_area_path(top, 30, .linear)
	assert area[area.len - 1].verb == .close
	assert plot_test_points(area) == [path_point(0, 10), path_point(10, 5), path_point(20, 8),
		path_point(20, 30), path_point(0, 30)]
	assert plot_test_close(plot_test_polygon_area(plot_test_points(area)), 20 * 30 - (10 + 5) * 5 -
		(5 + 8) * 5)
	bottom := [path_point(0, 20), path_point(10, 15), path_point(20, 18)]
	band := plot_band_area_path(top, bottom, .step_after)
	pts := plot_test_points(band)
	assert pts[0] == top[0]
	// Along the top, then back along the bottom (its step reversed exactly).
	assert pts[pts.len - 1] == path_point(0, 20)
	assert path_point(20, 18) in pts && path_point(10, 20) in pts
	assert plot_area_path([]PathPoint{}, 0, .linear).len == 0
	// Closing a clipped or broken line closes each piece.
	closed := plot_close_to_baseline([path_move_to(0, 1), path_line_to(1, 2), path_move_to(3, 4),
		path_line_to(4, 5)], 10)
	assert closed.filter(it.verb == .close).len == 2
	assert plot_close_between([]PathCommand{}, [path_move_to(0, 0)]).len == 0
}

fn test_plot_path_reverse_and_clip() {
	path := [path_move_to(0, 0), path_cubic_to(1, 2, 3, 4, 5, 6), path_line_to(10, 0)]
	back := plot_path_reverse(path)
	assert back[0] == path_move_to(10, 0)
	assert back[1] == path_line_to(5, 6)
	assert back[2] == path_cubic_to(3, 4, 1, 2, 0, 0)
	assert plot_path_reverse(back) == path
	assert plot_path_reverse([]PathCommand{}).len == 0
	// A line clipped halfway stops on the cut, at the line's own height.
	line := plot_line_path([path_point(0, 0), path_point(10, 10), path_point(20, 0)], .linear)
	half := plot_path_clip_right(line, 15)
	assert half.len == 3
	assert plot_test_close(half[2].x, 15) && plot_test_close(half[2].y, 5)
	assert plot_path_clip_right(line, 100) == line
	assert plot_path_clip_right(line, -1).len == 0
	// A smooth curve is split exactly where it crosses the cut.
	pts := [path_point(0, 10), path_point(30, 40), path_point(60, 0)]
	curve := plot_line_path(pts, .smooth)
	cut := plot_path_clip_right(curve, 45)
	end := cut[cut.len - 1]
	assert plot_test_close(end.x, 45)
	full := curve[2]
	t := (45.0 - 30) / 30
	assert math.abs(end.y - plot_cubic_at(40, full.cy1, full.cy2, full.y, t)) < 1e-6
	// A quadratic too.
	quad := plot_path_clip_right([path_move_to(0, 0), path_quad_to(5, 10, 10, 0)], 5)
	assert plot_test_close(quad[1].x, 5) && plot_test_close(quad[1].y, 5)
}

fn test_plot_clip_polygon_to_a_slab() {
	square := [path_point(0, 0), path_point(10, 0), path_point(10, 10), path_point(0, 10)]
	slab := plot_clip_polygon_y(square, 2, 5)
	assert plot_test_close(plot_test_polygon_area(slab), 30)
	for p in slab {
		assert p.y >= 2 && p.y <= 5
	}
	triangle := [path_point(0, 10), path_point(10, 0), path_point(20, 10)]
	upper := plot_clip_polygon_y(triangle, 0, 5)
	assert plot_test_close(plot_test_polygon_area(upper), 25)
	assert plot_clip_polygon_y(square, 20, 30).len == 0
	assert plot_clip_polygon_y([]PathPoint{}, 0, 1).len == 0
}

fn test_plot_pie_and_arcs() {
	arcs := plot_pie([1.0, 1, 2], PlotPieConfig{})
	assert arcs.len == 3
	assert arcs[0].start_angle == 0
	assert plot_test_close(arcs[0].end_angle, math.pi / 2)
	assert plot_test_close(arcs[1].end_angle, math.pi)
	assert plot_test_close(arcs[2].end_angle, 2 * math.pi)
	// Zero, negative and missing values get no slice but keep their index.
	sparse := plot_pie([0.0, 3, -1, math.nan(), 1], PlotPieConfig{})
	assert sparse.map(it.index) == [1, 4]
	assert plot_pie([0.0], PlotPieConfig{}).len == 0
	// The pad is part of each span and the spans still fill the circle.
	padded := plot_pie([1.0, 1], pad_angle: 0.1)
	assert padded[0].pad_angle == 0.1
	assert plot_test_close(padded[1].end_angle, 2 * math.pi)
	assert plot_test_close(padded[0].end_angle - padded[0].start_angle, math.pi)
	// Half a circle from 12 o'clock clockwise ends at 6 o'clock.
	half := plot_pie([1.0], end_angle: math.pi)
	assert plot_test_close(half[0].end_angle, math.pi)
	slice := plot_arc_path(arcs[0], 50, 50, 0, 40)
	b := path_bounds(slice)
	// A quarter from 12 to 3 o'clock lies right of center and above it.
	assert b.x >= 50 - 1e-6 && b.y >= 10 - 1e-6 && b.x + b.width <= 90 + 1e-6
	assert b.y + b.height <= 50 + 1e-6
	assert slice[0] == path_move_to(50, 10)
	ring := plot_arc_path(padded[0], 50, 50, 20, 40)
	start := ring[0]
	// The pad moves the slice's first edge off 12 o'clock.
	assert start.x > 50
	full := plot_arc_path(PlotArc{
		end_angle: 2 * math.pi
	}, 50, 50, 20, 40)
	assert full.filter(it.verb == .move_to).len == 2
	assert plot_arc_path(PlotArc{}, 0, 0, 0, 10).len == 0
	c := plot_arc_centroid(arcs[0], 0, 40)
	assert plot_test_close(c.x, 20 * math.cos(-math.pi / 4))
	assert plot_test_close(c.y, 20 * math.sin(-math.pi / 4))
}

fn test_plot_stack_offsets() {
	keys := ['a', 'b', 'c']
	values := [[1.0, 2, -1], [3.0, math.nan(), 2], [4.0]]
	none_ := plot_stack(keys, values, .none)
	assert none_.len == 3
	assert none_[0].points.map(it.y1) == [1.0, 2, -1]
	assert none_[1].points[0] == PlotStackPoint{1, 4, 3}
	assert none_[1].points[1] == PlotStackPoint{2, 2, 0}
	assert none_[2].points[2] == PlotStackPoint{1, 1, 0}
	assert none_[2].key == 'c' && none_[2].index == 2
	expand := plot_stack(keys, values, .expand)
	assert plot_test_close(expand[2].points[0].y1, 1)
	assert plot_test_close(expand[0].points[0].y1, 0.125)
	diverging := plot_stack(keys, values, .diverging)
	assert diverging[0].points[2] == PlotStackPoint{0, -1, -1}
	assert diverging[1].points[2] == PlotStackPoint{0, 2, 2}
	lo, hi := plot_stack_extent(diverging)
	assert lo == -1 && hi == 8
	assert plot_stack([]string{}, values, .none).len == 0
	assert plot_stack(['a'], [][]f64{}, .none)[0].points.len == 0
}

// ── Axis ───────────────────────────────────────────────────────────

fn test_plot_ticks_and_label_strides() {
	y := plot_linear_scale(0, 1, 100, 0)
	ticks := plot_linear_ticks(y, 2, unsafe { nil })
	// One precision for every label of an axis, as d3's tick format writes them.
	assert ticks.map(it.text) == ['0.0', '0.5', '1.0']
	assert ticks.map(it.position) == [100.0, 50, 0]
	money := plot_linear_ticks(y, 2, fn (v f64) string {
		return '$${v}'
	})
	assert money[2].text == '$1.0'
	band := plot_band_scale(['a', 'b', 'c', 'd'], 0, 40)
	assert plot_band_ticks(band, 2).map(it.text) == ['a', 'c']
	assert plot_band_ticks(band, 0).len == 4
	assert plot_band_ticks(band, 1)[0].position == 5
	point := plot_point_scale(['a', 'b', 'c'], 0, 100)
	pts := plot_point_ticks(point, 1)
	assert pts.map(it.align) == [PlotTickAlign.start, .center, .end]
	assert plot_point_ticks_at(point, [5, -1]).len == 0
	assert plot_spread_indices(12, 3) == [0, 6, 11]
	assert plot_spread_indices(5, 1) == [0]
	assert plot_spread_indices(3, 5) == [0, 1, 2]
	assert plot_spread_indices(0, 5).len == 0
	style := TextStyle{
		size: 11
	}
	wide := measure_text_width('September', style)
	assert plot_label_stride(['September'], wide + 20, style, 8) == 1
	assert plot_label_stride(['September'], (wide + 8) / 3, style, 8) == 3
	assert plot_label_stride([]string{}, 10, style, 8) == 1
}

fn test_plot_axis_lays_out_labels_lines_and_grid() {
	theme := component_theme(false)
	plot := rect(40, 10, 200, 100)
	ticks := [PlotAxisTick{
		position: 0
		text:     'A'
		align:    .start
	}, PlotAxisTick{
		position: 100
		text:     'Middle'
	}, PlotAxisTick{
		position: 200
		text:     'End'
		align:    .end
	}]
	bottom := PlotAxisConfig{
		id:    'axis'
		plot:  plot
		ticks: ticks
		grid:  true
		theme: theme
	}
	label_h := plot_label_height(11)
	assert plot_axis_size(bottom) == 6 + label_h
	frames := plot_axis_label_frames(bottom)
	assert frames[0].x == 0
	assert frames[1].x + frames[1].width / 2 == 100
	assert frames[2].x + frames[2].width == 200
	assert frames[0].y == plot.height + 6
	el := plot_axis(bottom)!
	assert el.frame == plot_axis_frame(bottom)
	assert el.frame.y == plot.y && el.frame.height == plot.height + 6 + label_h
	grid := plot_test_find(el, component_part_id('axis', 'grid'))?
	// A vertical line across the plot at each tick, on a pixel center.
	assert grid.path.filter(it.verb == .move_to).len == 3
	assert grid.path[2] == path_move_to(100.5 + 40 - el.frame.x, 10 - el.frame.y)
	line := plot_test_find(el, component_part_id('axis', 'line'))?
	assert line.shape_style.stroke? == theme.border
	labels := el.children.filter(it.kind == .label)
	assert labels.map(it.text) == ['A', 'Middle', 'End']
	// Labels are left aligned in frames placed as the tick asks (AppKit cuts
	// short a centered label exactly as wide as its text).
	assert labels.all(it.text_style.align == .left)
	// A left axis right-aligns its labels in a gutter as wide as the widest.
	left := PlotAxisConfig{
		...bottom
		orientation: .left
		ticks:       [PlotAxisTick{
			position: 0
			text:     '1,000'
		}, PlotAxisTick{
			position: 100
			text:     '0'
		}]
		line:        false
	}
	widest := math.ceil(measure_text_width('1,000', TextStyle{ size: 11 }))
	assert plot_axis_size(left) == 6 + widest
	left_frames := plot_axis_label_frames(left)
	assert left_frames[1].x == -6 - widest && left_frames[1].width == widest
	assert left_frames[1].y == 100 - label_h / 2
	left_el := plot_axis(left)!
	assert plot_test_find(left_el, component_part_id('axis', 'line')) == none
	assert left_el.children.filter(it.kind == .label).all(it.text_style.align == .right)
	// A left axis' grid runs across, on the same pixel row a bottom axis'
	// line takes at that height.
	across := plot_grid_path(PlotAxisConfig{
		...bottom
		orientation: .left
		ticks:       [PlotAxisTick{
			position: 100
		}]
	})
	assert across == [path_move_to(0, 100.5), path_line_to(200, 100.5)]
	assert plot_axis_line_path(bottom)[0].y == across[0].y
	dashed := plot_grid_path(PlotAxisConfig{
		...bottom
		grid_dashed: true
	})
	assert dashed.filter(it.verb == .move_to).len > 3
	// Labels inside the plot take no gutter and sit beside their lines.
	inside := PlotAxisConfig{
		...left
		labels_inside: true
	}
	assert plot_axis_size(inside) == 0
	inside_frames := plot_axis_label_frames(inside)
	assert inside_frames[0].x == 2 && inside_frames[0].y == 1
	assert inside_frames[1].y == 100 - label_h
	assert plot_axis(inside)!.children.filter(it.kind == .label).all(it.text_style.align == .left)
	// Without labels the axis takes no room outside the plot.
	bare := PlotAxisConfig{
		...bottom
		labels: false
	}
	assert plot_axis_size(bare) == 0
	assert plot_axis_frame(bare) == plot
	// Lines go on pixel centers.
	assert plot_axis_line_path(bottom)[0] == path_move_to(0, 100.5)
	if _ := plot_axis(PlotAxisConfig{
		plot: plot
	}) {
		assert false
	}
	if _ := plot_axis(PlotAxisConfig{
		...bottom
		label_size: 0
	}) {
		assert false
	}
}

// ── Chart helpers ──────────────────────────────────────────────────

fn test_plot_hover_events_decode_to_an_index() {
	enter := 'pointer:enter:${component_part_id('sales:q', 'hover:3')}:10.5:20'
	leave := 'pointer:leave:${component_part_id('sales:q', 'hover:3')}:10.5:20'
	assert plot_hover_from_event('sales:q', -1, 12, enter)? == 3
	// No change, a stale leave, and the leave of the hovered category.
	assert plot_hover_from_event('sales:q', 3, 12, enter) == none
	assert plot_hover_from_event('sales:q', 4, 12, leave) == none
	assert plot_hover_from_event('sales:q', 3, 12, leave)? == -1
	// Foreign, forged and malformed events.
	assert plot_hover_from_event('other', -1, 12, enter) == none
	assert plot_hover_from_event('sales:q', -1, 3, enter) == none
	assert plot_hover_from_event('sales:q', -1, 0, enter) == none
	assert plot_hover_from_event('sales:q', -1, 12, component_part_id('sales:q', 'hover:3')) == none
	for bad in ['hover:03', 'hover:-1', 'hover:', 'hover:x', 'legend:1'] {
		assert plot_hover_from_event('sales:q', -1, 12, 'pointer:enter:${component_part_id('sales:q', bad)}:1:1') == none
	}
	assert plot_hover_from_event('sales:q', -1, 12, 'pointer:down:${component_part_id('sales:q', 'hover:3')}:1:1') == none
	assert plot_hover_from_event('', -1, 12, enter) == none
}

fn test_plot_legend_actions_and_hidden_series() {
	series := plot_test_series()
	assert plot_legend_key_from_action('c', series, component_part_id('c', 'legend:1'))? == 'mobile'
	assert plot_legend_key_from_action('c', series, component_part_id('c', 'legend:2')) == none
	assert plot_legend_key_from_action('c', series, component_part_id('c', 'legend:01')) == none
	assert plot_legend_key_from_action('c', series, component_part_id('d', 'legend:1')) == none
	assert plot_legend_key_from_action('c', series, component_part_id('c', 'hover:1')) == none
	hidden := plot_toggle_hidden([], 'mobile')
	assert hidden == ['mobile']
	assert plot_toggle_hidden(hidden, 'mobile').len == 0
	assert plot_toggle_hidden(hidden, 'desktop') == ['mobile', 'desktop']
}

fn test_cartesian_series_keep_identity_and_colors() {
	theme := component_theme(false)
	resolved := cartesian_series(plot_test_series(), ['desktop'], theme)!
	assert resolved[0].hidden && !resolved[1].hidden
	assert resolved[0].name == 'Desktop' && resolved[1].name == 'mobile'
	// Hiding a series does not repaint the others.
	assert resolved[1].color == plot_chart_color(theme, 1)
	custom := cartesian_series([PlotSeries{
		key:   'x'
		color: u32(0x123456)
	}], [], theme)!
	assert custom[0].color == 0x123456
	if _ := cartesian_series([PlotSeries{
		key: 'x'
	}, PlotSeries{
		key: 'x'
	}], [], theme) {
		assert false
	}
	if _ := cartesian_series([PlotSeries{
		key: ' '
	}], [], theme) {
		assert false
	}
	assert math.is_nan(cartesian_value(resolved[0], 99))
	assert math.is_nan(cartesian_value(resolved[0], -1))
}

fn test_cartesian_legend_wraps_and_toggles() {
	items := [CartesianLegendItem{'Desktop', 1, false, 0}, CartesianLegendItem{'Mobile', 2, true, 1},
		CartesianLegendItem{'Tablet', 3, false, 2}]
	frames, height := cartesian_legend_frames(items, 1000, 12)
	assert height == plot_legend_row
	// One centered row.
	assert plot_test_close(frames[0].x, 1000 - (frames[2].x + frames[2].width))
	narrow, tall := cartesian_legend_frames(items, frames[0].width + 1, 12)
	assert tall == 3 * plot_legend_row
	assert narrow[2].y == 2 * plot_legend_row
	theme := component_theme(false)
	el := cartesian_legend('c', items, rect(0, 0, 400, 20), 12, true, theme)
	button := plot_test_find(el, component_part_id('c', 'legend:1'))?
	assert button.button_behavior
	assert button.accessibility_value == 'hidden'
	assert button.children[0].box.bg == theme.border
	plain := cartesian_legend('c', items, rect(0, 0, 400, 20), 12, false, theme)
	assert plot_test_ids(plain, component_part_id('c', 'legend:')).len == 0
	assert cartesian_legend_shown(.auto, 1) == false
	assert cartesian_legend_shown(.auto, 2)
	assert cartesian_legend_shown(.top, 1)
	assert !cartesian_legend_shown(.hidden, 5)
}

fn test_plot_tooltip_placement_stays_inside() {
	area := rect(0, 0, 400, 300)
	beside := plot_tooltip_place(rect(100, 50, 10, 40), 120, 80, area, false)
	assert beside == rect(120, 50, 120, 80)
	// No room on the right: to the left.
	flipped := plot_tooltip_place(rect(350, 50, 10, 40), 120, 80, area, false)
	assert flipped == rect(220, 50, 120, 80)
	// Pushed back inside at the bottom.
	low := plot_tooltip_place(rect(100, 280, 10, 10), 120, 80, area, false)
	assert low.y == 220
	below := plot_tooltip_place(rect(0, 100, 300, 20), 120, 80, area, true)
	assert below == rect(180, 130, 120, 80)
	above := plot_tooltip_place(rect(0, 250, 300, 20), 120, 80, area, true)
	assert above.y == 160
	w, h := cartesian_tooltip_size('Aug', [CartesianTooltipRow{
		color: u32(1)
		name:  'Desktop'
		value: '298'
	}], 12)
	assert w >= plot_tooltip_min_width
	assert h == 2 * plot_tooltip_padding + plot_label_height(12) + 2 + plot_label_height(12)
}

fn test_plot_glide_records_then_animates_and_releases() {
	id := 'plot-test:glide'
	plot_glide(id, 10, 20, true)
	first := animation_info(id)
	assert first.status == .running && first.duration == 0
	assert plot_glide_target(id)? == path_point(10, 20)
	// The same place again leaves the run alone; a new one glides there.
	plot_glide(id, 10, 20, true)
	assert animation_info(id).duration == 0
	plot_glide(id, 40, 20, true)
	assert animation_info(id).duration == plot_glide_seconds
	assert plot_glide_target(id)? == path_point(40, 20)
	plot_glide(id, 40, 20, false)
	assert animation_info(id).status == .idle
	assert plot_glide_target(id) == none
	// Hover marks gone briefly glide on; gone for long, they start over.
	chart := 'plot-test:continuity'
	assert plot_hover_continues(chart, true)
	assert plot_hover_continues(chart, false)
	assert plot_hover_continues(chart, true)
	stamp := component_part_id(chart, 'hover-gone')
	assert animation_info(stamp).status == .idle
	start_widget_animation_at(stamp, animation(duration: 0, x: 0), time.ticks() - 1000, false)
	assert !plot_hover_continues(chart, true)
}

fn test_plot_appear_runs_once_per_key() {
	off, none_marker := plot_appear('plot-test:a', false, '', 1, false)
	assert off == 1 && none_marker.len == 0
	reduced, _ := plot_appear('plot-test:a', true, '', 1, true)
	assert reduced == 1
	start, markers := plot_appear('plot-test:a', true, 'k1', 0.5, false)
	assert start == 0 && markers.len == 1 && markers[0].hidden
	marker := markers[0].id
	assert animation_info(marker).status == .running
	// Halfway through the eased curve is far along.
	runtime := g_animation_runtime
	runtime.mutex.lock()
	began := runtime.runs[marker].started_at
	runtime.mutex.unlock()
	apply_widget_animations_at(screen(0xffffff, markers), began + 250)
	mid, _ := plot_appear('plot-test:a', true, 'k1', 0.5, false)
	assert plot_test_close(mid, plot_ease_out_quart(0.5))
	apply_widget_animations_at(screen(0xffffff, markers), began + 600)
	done, gone := plot_appear('plot-test:a', true, 'k1', 0.5, false)
	assert done == 1 && gone.len == 0
	// A new key draws in again.
	again, _ := plot_appear('plot-test:a', true, 'k2', 0.5, false)
	assert again == 0
	assert plot_ease_out_quart(0) == 0 && plot_ease_out_quart(1) == 1
	assert plot_ease_out_quart(2) == 1
}

// ── Line and area charts ───────────────────────────────────────────

fn plot_test_line(config LineChartConfig) LineChartConfig {
	return LineChartConfig{
		...config
		frame:      rect(10, 20, 600, 300)
		categories: plot_test_months
		series:     plot_test_series()
		appear:     false
		theme:      component_theme(false)
	}
}

fn plot_test_spec(kind PointChartKind, layout PlotAreaLayout) PointChartSpec {
	return PointChartSpec{
		kind:                 kind
		id:                   'spec'
		frame:                rect(0, 0, 600, 300)
		categories:           plot_test_months
		series:               plot_test_series()
		area_layout:          layout
		curve:                .smooth
		stroke_width:         2
		dot_size:             6
		fill_opacity:         0.4
		gradient_end_opacity: 0.05
		hovered:              -1
		interactive:          true
		x_axis:               true
		y_axis:               true
		grid:                 true
		y_tick_count:         5
		appear_duration:      1
		size:                 .medium
		theme:                component_theme(false)
	}
}

fn test_point_chart_geometry_lays_out_the_plot() {
	g := point_chart_geometry(plot_test_spec(.line, .overlap))!
	plot := g.plot
	// Inside the frame, past the y labels, above the x labels and the legend.
	assert plot.x > 0 && plot.y > 0
	assert plot.x + plot.width <= 600 && plot.y + plot.height <= 300
	assert g.legend.height == plot_legend_row
	assert g.legend.y + g.legend.height <= 300
	assert plot.y + plot.height + 6 + plot_label_height(11) <= g.legend.y
	// The y axis fits the data from zero, rounded out to ticks.
	assert g.y.domain_min == 0 && g.y.domain_max == 350
	assert g.y.position(0) == plot.height && g.y.position(350) == 0
	assert g.y_ticks.map(it.text) == ['0', '50', '100', '150', '200', '250', '300', '350']
	// Categories from edge to edge, the end labels kept over the plot.
	assert plot_test_close(g.x.position_at(0), 0)
	assert plot_test_close(g.x.position_at(5), plot.width)
	assert g.x_ticks[0].align == .start && g.x_ticks[g.x_ticks.len - 1].align == .end
	assert g.tops.len == 2 && g.bottoms.len == 0
	// Pinned values stop at the plot's edge.
	pinned := point_chart_geometry(PointChartSpec{
		...plot_test_spec(.line, .overlap)
		y_min: 100
		y_max: 200
	})!
	assert pinned.y.domain_min == 100 && pinned.y.domain_max == 200
	assert pinned.y.position(305) == 0
	pinned_chart := line_chart(plot_test_line(LineChartConfig{
		id:              'pinned'
		y_min:           100
		y_max:           200
		reference_lines: [150.0, 250]
	}))!
	reference := plot_test_find(pinned_chart, component_part_id('pinned', 'reference'))?
	assert reference.path.filter(it.verb == .move_to).len > 0
	assert reference.path.all(plot_test_close(it.y, reference.path[0].y))
	// Fills come before every line.
	overlap := area_chart(AreaChartConfig{
		id:         'order'
		frame:      rect(0, 0, 400, 200)
		categories: plot_test_months
		series:     plot_test_series()
		appear:     false
	})!
	ids := overlap.children.map(it.id)
	assert ids.index(component_part_id('order', 'area:mobile')) < ids.index(component_part_id('order',
		'area-line:desktop'))
	// point_count leaves room for points to come.
	partial := point_chart_geometry(PointChartSpec{
		...plot_test_spec(.line, .overlap)
		point_count: 12
	})!
	assert plot_test_close(partial.x.position_at(5), partial.plot.width * 5 / 11)
	// Without axes or legend the plot takes nearly the whole frame.
	bare := point_chart_geometry(PointChartSpec{
		...plot_test_spec(.line, .overlap)
		x_axis: false
		y_axis: false
		legend: .hidden
	})!
	assert bare.plot.width == 600 - bare.plot.x - PlotMargin{}.right
	assert bare.legend.height == 0
	// x_tick_count and tick_margin pick which categories are labeled.
	spread := point_chart_geometry(PointChartSpec{
		...plot_test_spec(.line, .overlap)
		x_tick_count: 3
	})!
	assert spread.x_ticks.map(it.text) == ['Jan', 'Apr', 'Jun']
	every_other := point_chart_geometry(PointChartSpec{
		...plot_test_spec(.line, .overlap)
		tick_margin: 2
	})!
	assert every_other.x_ticks.map(it.text) == ['Jan', 'Mar', 'May']
}

fn test_stacked_area_geometry() {
	g := point_chart_geometry(plot_test_spec(.area, .stacked))!
	assert g.stacked
	// Each layer starts where the one below ends.
	assert g.bottoms[0] == []f64{len: 6, init: 0}
	assert g.bottoms[1] == g.tops[0]
	assert g.tops[1][0] == 266
	assert g.y.domain_max >= 505
	expand := point_chart_geometry(plot_test_spec(.area, .expand))!
	assert expand.y.domain_min == 0 && expand.y.domain_max == 1
	assert expand.tops[1].all(plot_test_close(it, 1))
	assert expand.y_ticks[expand.y_ticks.len - 1].text == '100%'
	// Hidden series leave the stack.
	hidden := point_chart_geometry(PointChartSpec{
		...plot_test_spec(.area, .stacked)
		hidden_series: ['desktop']
	})!
	assert hidden.visible.len == 1
	assert hidden.bottoms[0] == []f64{len: 6, init: 0}
}

fn test_line_chart_builds_series_hover_bands_and_tooltip() {
	el := line_chart(plot_test_line(LineChartConfig{
		id:      'traffic'
		hovered: 2
	}))!
	assert el.frame == rect(10, 20, 600, 300)
	assert el.accessibility_role == 'group'
	assert el.accessibility_value.contains('Desktop, mobile')
	assert plot_test_ids(el, component_part_id('traffic', 'line:')).len == 2
	line := plot_test_find(el, component_part_id('traffic', 'line:desktop'))?
	assert line.shape_style.stroke? == plot_chart_color(component_theme(false), 0)
	assert line.shape_style.fill == none
	// One hover band per category, drawn last.
	bands := plot_test_ids(el, component_part_id('traffic', 'hover:'))
	assert bands.len == 6
	last := el.children[el.children.len - 1]
	assert last.id == component_part_id('traffic', 'hover:5') && last.hoverable
	// The hovered category's crosshair, dots and card.
	cross := plot_test_find(el, component_part_id('traffic', 'crosshair'))?
	g := point_chart_geometry(plot_test_spec(.line, .overlap))!
	assert plot_test_close(cross.frame.x, math.floor(g.plot.x + g.x.position_at(2)))
	assert plot_test_find(el, component_part_id('traffic', 'dot:mobile')) != none
	assert plot_test_find(el, component_part_id('traffic', 'halo:desktop')) != none
	card := plot_test_find(el, component_part_id('traffic', 'tooltip'))?
	assert card.frame.x >= 0 && card.frame.y >= 0
	assert card.frame.x + card.frame.width <= 600 && card.frame.y + card.frame.height <= 300
	texts := card.children.filter(it.kind == .label).map(it.text)
	assert texts == ['Mar', 'Desktop', '237', 'mobile', '120']
	// The bands sit over the card, so the pointer on the card still hovers a
	// category and the card cannot flicker away from under it.
	mut hit := []string{}
	plot_test_hit(screen(0xffffff, [el]), 0, 0, 10 + card.frame.x + 5, 20 + card.frame.y + 5, []string{}, mut
		hit)
	assert hit.len == 1 && hit[0].starts_with(component_part_id('traffic', 'hover:'))
	// The band's accessibility label reads the tooltip.
	band := plot_test_find(el, component_part_id('traffic', 'hover:2'))?
	assert band.accessibility_label == 'Mar: Desktop 237, mobile 120'
	validate_element_tree(screen(0xffffff, [el]))!
}

fn test_line_chart_options_change_what_is_drawn() {
	quiet := line_chart(plot_test_line(LineChartConfig{
		id:          'quiet'
		hovered:     2
		interactive: false
		dots:        true
	}))!
	assert plot_test_ids(quiet, component_part_id('quiet', 'hover:')).len == 0
	assert plot_test_find(quiet, component_part_id('quiet', 'tooltip')) == none
	dots := plot_test_find(quiet, component_part_id('quiet', 'dots:desktop'))?
	assert dots.path.filter(it.verb == .move_to).len == 6
	hidden := line_chart(plot_test_line(LineChartConfig{
		id:            'hide'
		hidden_series: ['mobile']
		legend_toggle: true
		hovered:       1
	}))!
	assert plot_test_find(hidden, component_part_id('hide', 'line:mobile')) == none
	assert plot_test_find(hidden, component_part_id('hide', 'dot:mobile')) == none
	toggle := plot_test_find(hidden, component_part_id('hide', 'legend:1'))?
	assert toggle.button_behavior && toggle.accessibility_value == 'hidden'
	card := plot_test_find(hidden, component_part_id('hide', 'tooltip'))?
	assert !card.children.any(it.text == 'mobile')
	stepped := line_chart(plot_test_line(LineChartConfig{
		id:              'steps'
		curve:           .step_after
		reference_lines: [100.0, 9999]
		grid_columns:    4
	}))!
	step_line := plot_test_find(stepped, component_part_id('steps', 'line:desktop'))?
	assert step_line.path.all(it.verb in [.move_to, .line_to])
	reference := plot_test_find(stepped, component_part_id('steps', 'reference'))?
	assert reference.shape_style.stroke? == component_theme(false).muted_foreground
	columns := plot_test_find(stepped, component_part_id('steps', 'grid-columns'))?
	assert columns.path.filter(it.verb == .move_to).len == 4
	// A hovered index out of range shows nothing.
	far := line_chart(plot_test_line(LineChartConfig{
		id:      'far'
		hovered: 6
	}))!
	assert plot_test_find(far, component_part_id('far', 'crosshair')) == none
	empty := line_chart(LineChartConfig{
		id:    'empty'
		frame: rect(0, 0, 200, 100)
	})!
	assert plot_test_ids(empty, component_part_id('empty', 'hover:')).len == 0
	formatted := line_chart(plot_test_line(LineChartConfig{
		id:                   'fmt'
		hovered:              0
		y_tick_format:        fn (v f64) string {
			return '${int(v)}k'
		}
		tooltip_value_format: fn (v f64) string {
			return '#${int(v)}'
		}
		tooltip_title:        fn (i int) string {
			return 'Month ${i + 1}'
		}
	}))!
	inside := point_chart_geometry(PointChartSpec{
		...plot_test_spec(.line, .overlap)
		y_axis_inside: true
	})!
	assert inside.plot.x == PlotMargin{}.left
	colored := line_chart(plot_test_line(LineChartConfig{
		id:                  'colors'
		hovered:             0
		tooltip_value_color: fn (series int, index int, value f64) u32 {
			return if series == 1 { u32(0x00aa00) } else { u32(0xaa0000) }
		}
	}))!
	colored_card := plot_test_find(colored, component_part_id('colors', 'tooltip'))?
	value_colors := colored_card.children.filter(it.text in ['186', '80']).map(it.text_style.color)
	assert value_colors == [u32(0xaa0000), 0x00aa00]
	fmt_card := plot_test_find(formatted, component_part_id('fmt', 'tooltip'))?
	assert fmt_card.children.map(it.text).contains('Month 1')
	assert fmt_card.children.map(it.text).contains('#186')
	y_axis := plot_test_find(formatted, component_part_id('fmt', 'y-axis'))?
	assert y_axis.children.any(it.text == '350k')
}

fn test_point_charts_validate() {
	if _ := line_chart(LineChartConfig{
		frame: rect(0, 0, 10, 10)
	}) {
		assert false
	}
	if _ := line_chart(LineChartConfig{
		id:    'x'
		frame: rect(0, 0, -1, 10)
	}) {
		assert false
	}
	if _ := line_chart(LineChartConfig{
		id:           'x'
		frame:        rect(0, 0, 10, 10)
		y_tick_count: 1
	}) {
		assert false
	}
	if _ := area_chart(AreaChartConfig{
		id:           'x'
		frame:        rect(0, 0, 10, 10)
		fill_opacity: math.nan()
	}) {
		assert false
	}
	// Tiny frames still build.
	line_chart(LineChartConfig{
		id:         'tiny'
		frame:      rect(0, 0, 4, 4)
		categories: ['a', 'b']
		series:     plot_test_series()
		hovered:    1
		appear:     false
	})!
}

fn test_area_chart_fills_fades_and_totals() {
	theme := component_theme(false)
	base := AreaChartConfig{
		id:         'signups'
		frame:      rect(0, 0, 600, 300)
		categories: plot_test_months
		series:     plot_test_series()
		appear:     false
		theme:      theme
	}
	overlap := area_chart(base)!
	fill := plot_test_find(overlap, component_part_id('signups', 'area:desktop'))?
	assert fill.shape_style.fill? == plot_chart_color(theme, 0)
	assert fill.shape_style.fill_opacity == 0.35
	assert fill.path[fill.path.len - 1].verb == .close
	edge := plot_test_find(overlap, component_part_id('signups', 'area-line:mobile'))?
	assert edge.shape_style.stroke? == plot_chart_color(theme, 1)
	faded := area_chart(AreaChartConfig{
		...base
		id:       'faded'
		gradient: true
	})!
	slices := plot_test_ids(faded, component_part_id('faded', 'area:desktop:fade'))
	assert slices.len > 3
	first := plot_test_find(faded, slices[0])?
	last := plot_test_find(faded, slices[slices.len - 1])?
	assert first.shape_style.fill_opacity > last.shape_style.fill_opacity
	assert plot_fade_slices(60) == 10 && plot_fade_slices(10) == 8 && plot_fade_slices(900) == 32
	stacked := area_chart(AreaChartConfig{
		...base
		id:      'stack'
		layout:  .stacked
		hovered: 1
	})!
	card := plot_test_find(stacked, component_part_id('stack', 'tooltip'))?
	labels := card.children.map(it.text)
	assert labels.contains('Total') && labels.contains('505')
	// The dot of a stacked series sits on its layer's top edge.
	g := point_chart_geometry(plot_test_spec(.area, .stacked))!
	dot := plot_test_find(stacked, component_part_id('stack', 'dot:mobile'))?
	assert plot_test_close(dot.frame.y + 6, g.plot.y + g.y.position(505))
	expand := area_chart(AreaChartConfig{
		...base
		id:      'expand'
		layout:  .expand
		hovered: 0
	})!
	expand_card := plot_test_find(expand, component_part_id('expand', 'tooltip'))?
	assert expand_card.children.map(it.text).contains('186')
	validate_element_tree(screen(0xffffff, [overlap, faded, stacked, expand]))!
}

fn test_point_chart_draws_in_from_the_left() {
	spec := PointChartSpec{
		...plot_test_spec(.area, .stacked)
		id:     'reveal'
		appear: true
	}
	el := point_chart(spec)!
	// The first build is the first frame: nothing drawn yet, no hover marks.
	line := plot_test_find(el, component_part_id('reveal', 'area-line:desktop'))?
	assert line.path.all(it.x <= plot_bleed + 1e-6)
	marker := plot_test_ids(el, component_part_id('reveal', 'appear:'))
	assert marker.len == 1
	g := point_chart_geometry(spec)!
	// Partway through, every edge stops at the same x.
	top := plot_path_clip_right(plot_line_path(point_chart_points(g, g.tops[0]), .smooth),
		plot_bleed + g.plot.width * 0.4)
	assert plot_test_close(top[top.len - 1].x, plot_bleed + g.plot.width * 0.4)
}

// ── Bar charts ─────────────────────────────────────────────────────

fn plot_test_bars(config BarChartConfig) BarChartConfig {
	return BarChartConfig{
		...config
		frame:      rect(0, 0, 500, 300)
		categories: plot_test_months
		series:     plot_test_series()
		appear:     false
		theme:      component_theme(false)
	}
}

fn test_grouped_bars_share_their_band() {
	config := plot_test_bars(BarChartConfig{
		id: 'grouped'
	})
	g := bar_chart_geometry(config)!
	assert g.bars.len == 12
	plot := g.plot
	for b in g.bars {
		assert b.frame.x >= plot.x - 1e-6 && b.frame.x + b.frame.width <= plot.x + plot.width + 1e-6
		assert b.frame.y >= plot.y - 1e-6 && b.frame.y + b.frame.height <= plot.y + plot.height + 1e-6
	}
	a, b := g.bars[0], g.bars[1]
	assert a.index == 0 && b.index == 0 && a.key == 'desktop' && b.key == 'mobile'
	assert a.frame.width == b.frame.width
	assert plot_test_close(b.frame.x - (a.frame.x + a.frame.width), config.bar_gap)
	// The group is centered on its band and stands on the zero line.
	assert plot_test_close((a.frame.x + b.frame.x + b.frame.width) / 2, plot.x + g.band.center_at(0))
	assert plot_test_close(a.frame.y + a.frame.height, plot.y + plot.height)
	assert plot_test_close(a.base, plot.y + plot.height)
	assert a.corners.top_left == 4 && a.corners.bottom_left == 0
	// Taller values make taller bars.
	assert g.bars[2].frame.height > a.frame.height
	// The cap keeps bars thin in a wide band.
	wide := bar_chart_geometry(BarChartConfig{
		...config
		frame:         rect(0, 0, 2000, 300)
		max_bar_width: 12
	})!
	assert wide.bars[0].frame.width == 12
	assert bar_chart_bars(config)! == g.bars
	// Value labels need room above the tallest bar.
	labeled := bar_chart_geometry(BarChartConfig{
		...config
		value_labels: true
	})!
	assert labeled.plot.y > g.plot.y
}

fn test_bars_with_negative_values_grow_down_from_zero() {
	g := bar_chart_geometry(BarChartConfig{
		...plot_test_bars(BarChartConfig{
			id: 'neg'
		})
		series:     [PlotSeries{
			key:    'growth'
			values: [12.0, -8, 0, 5, -3, 7]
		}]
		min_length: 2
	})!
	zero := g.plot.y + g.zero
	assert g.zero < g.plot.height
	down := g.bars[1]
	assert plot_test_close(down.frame.y, zero) && down.frame.height > 0
	assert down.corners.bottom_left == 4 && down.corners.top_left == 0
	// A zero still shows a stub, on the positive side.
	stub := g.bars[2]
	assert plot_test_close(stub.frame.height, 2) && plot_test_close(stub.frame.y, zero - 2)
	// A single series is one bar per band, capped.
	assert g.bars[0].frame.width <= 30
}

fn test_stacked_and_expanded_bars() {
	config := plot_test_bars(BarChartConfig{
		id:     'stack'
		layout: .stacked
	})
	g := bar_chart_geometry(config)!
	lower := g.bars.filter(it.index == 0 && it.key == 'desktop')[0]
	upper := g.bars.filter(it.index == 0 && it.key == 'mobile')[0]
	// One column, the upper segment on the lower with a gap between.
	assert lower.frame.x == upper.frame.x && lower.frame.width == upper.frame.width
	assert plot_test_close(lower.frame.y - (upper.frame.y + upper.frame.height), config.bar_gap)
	// Only the outer segment is rounded.
	assert lower.corners == PlotCorners{}
	assert upper.corners.top_left == 4
	assert g.totals[0] == 266
	assert g.value.domain_max >= 505
	expand := bar_chart_geometry(BarChartConfig{
		...config
		layout: .expand
	})!
	assert expand.value.domain_max == 1
	assert expand.value_ticks[expand.value_ticks.len - 1].text == '100%'
	top := expand.bars.filter(it.index == 3 && it.key == 'mobile')[0]
	assert plot_test_close(top.frame.y, expand.plot.y)
	el := bar_chart(BarChartConfig{
		...config
		layout:  .expand
		hovered: 3
	})!
	card := plot_test_find(el, component_part_id('stack', 'tooltip'))?
	assert card.children.map(it.text).contains('190 (72.2%)')
	assert card.children.map(it.text).contains('Total')
	// Diverging: negative segments stack down from zero.
	mixed := bar_chart_geometry(BarChartConfig{
		...config
		series: [PlotSeries{
			key:    'in'
			values: [5.0]
		}, PlotSeries{
			key:    'out'
			values: [-3.0]
		}]
	})!
	inflow := mixed.bars.filter(it.key == 'in')[0]
	outflow := mixed.bars.filter(it.key == 'out')[0]
	zero := mixed.plot.y + mixed.zero
	assert plot_test_close(inflow.frame.y + inflow.frame.height, zero)
	assert plot_test_close(outflow.frame.y, zero)
	assert outflow.corners.bottom_left == 4 && inflow.corners.top_left == 4
}

fn test_horizontal_bars_grow_from_the_left() {
	config := plot_test_bars(BarChartConfig{
		id:           'across'
		alignment:    .left
		value_labels: true
		hovered:      1
	})
	g := bar_chart_geometry(config)!
	assert g.horizontal
	for b in g.bars {
		assert plot_test_close(b.frame.x, g.plot.x)
		assert b.corners.top_right == 4 && b.corners.top_left == 0
	}
	// Categories run down the band axis.
	assert g.bars[0].frame.y < g.bars[2].frame.y
	el := bar_chart(config)!
	band_axis := plot_test_find(el, component_part_id('across', 'band-axis'))?
	assert band_axis.children.filter(it.kind == .label).map(it.text) == plot_test_months
	// Value labels sit past each tip and inside the chart.
	labels := el.children.filter(it.kind == .label)
	assert labels.len == 12
	for l in labels {
		assert l.frame.x + l.frame.width <= 500 + 1e-6
	}
	right := bar_chart_geometry(BarChartConfig{
		...config
		alignment: .right
	})!
	for b in right.bars {
		assert plot_test_close(b.frame.x + b.frame.width, right.plot.x + right.plot.width)
	}
	top := bar_chart_geometry(BarChartConfig{
		...config
		alignment: .top
	})!
	for b in top.bars {
		assert plot_test_close(b.frame.y, top.plot.y)
	}
}

fn test_bar_chart_hover_highlights_and_fades() {
	el := bar_chart(plot_test_bars(BarChartConfig{
		id:      'hover'
		hovered: 2
	}))!
	g := bar_chart_geometry(plot_test_bars(BarChartConfig{
		id: 'hover'
	}))!
	highlight := plot_test_find(el, component_part_id('hover', 'highlight'))?
	group := g.groups[2]
	assert highlight.frame.x < group.x && highlight.frame.x + highlight.frame.width > group.x + group.width
	hovered := plot_test_find(el, component_part_id('hover', 'bar:desktop:2'))?
	other := plot_test_find(el, component_part_id('hover', 'bar:desktop:0'))?
	assert hovered.shape_style.fill_opacity == 1 && other.shape_style.fill_opacity < 1
	card := plot_test_find(el, component_part_id('hover', 'tooltip'))?
	assert card.children.filter(it.kind == .label).map(it.text) == ['Mar', 'Desktop', '237', 'mobile',
		'120']
	assert card.frame.x + card.frame.width <= 500 && card.frame.x >= 0
	// The highlight is drawn under the bars, the bands over everything.
	highlight_at := el.children.index(highlight)
	assert highlight_at < el.children.index(hovered)
	assert el.children[el.children.len - 1].id == component_part_id('hover', 'hover:5')
	slots := g.slots
	assert slots.len == 6
	assert plot_test_close(slots[0].x + slots[0].width, slots[1].x)
	// Bars may take a color each, as upstream's fill closure gives them.
	colored := bar_chart(BarChartConfig{
		...plot_test_bars(BarChartConfig{
			id:      'colored'
			hovered: 1
		})
		series: [PlotSeries{
			key:    'v'
			values: [1.0, 2, 3]
			colors: [u32(0xff0000), 0x00ff00]
		}]
	})!
	assert plot_test_find(colored, component_part_id('colored', 'bar:v:1'))?.shape_style.fill? == 0x00ff00
	assert plot_test_find(colored, component_part_id('colored', 'bar:v:2'))?.shape_style.fill? == plot_chart_color(component_theme(false),
		0)
	colored_card := plot_test_find(colored, component_part_id('colored', 'tooltip'))?
	assert colored_card.children.any(it.kind == .view && it.box.bg == 0x00ff00)
	quiet := bar_chart(plot_test_bars(BarChartConfig{
		id:          'quiet-bars'
		hovered:     2
		interactive: false
	}))!
	assert plot_test_find(quiet, component_part_id('quiet-bars', 'highlight')) == none
	assert plot_test_ids(quiet, component_part_id('quiet-bars', 'hover:')).len == 0
	validate_element_tree(screen(0xffffff, [el, quiet]))!
}

fn test_bars_grow_out_of_the_zero_line() {
	config := plot_test_bars(BarChartConfig{
		id:     'grow'
		layout: .stacked
	})
	g := bar_chart_geometry(config)!
	zero := g.plot.y + g.zero
	for b in g.bars {
		half := bar_chart_grown(b, .bottom, 4, zero, 0.5)
		// Each edge halfway to the zero line, so the stack stays one piece.
		assert plot_test_close(half.base, zero + (b.base - zero) / 2)
		assert plot_test_close(half.tip, zero + (b.tip - zero) / 2)
		assert bar_chart_grown(b, .bottom, 4, zero, 1) == b
	}
	first := bar_chart(BarChartConfig{
		...config
		id:     'grow-live'
		appear: true
	})!
	assert plot_test_ids(first, component_part_id('grow-live', 'bar:')).len == 0
	assert plot_test_ids(first, component_part_id('grow-live', 'appear:')).len == 1
}

fn test_bar_charts_validate() {
	base := plot_test_bars(BarChartConfig{
		id: 'v'
	})
	for bad in [BarChartConfig{
		...base
		id: ''
	}, BarChartConfig{
		...base
		padding_inner: 1
	}, BarChartConfig{
		...base
		bar_gap: -1
	}, BarChartConfig{
		...base
		value_tick_count: 30
	}, BarChartConfig{
		...base
		corner_radius: math.inf(1)
	}] {
		if _ := bar_chart(bad) {
			assert false
		}
	}
	bar_chart(BarChartConfig{
		...base
		id:    'small'
		frame: rect(0, 0, 3, 3)
	})!
	bar_chart(BarChartConfig{
		id:    'nothing'
		frame: rect(0, 0, 100, 100)
	})!
}
