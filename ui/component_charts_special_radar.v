module ui2

import math

// RadarAxis is one dimension of a radar chart: a spoke, placed clockwise from
// twelve o'clock in the order given.
pub struct RadarAxis {
pub:
	key   string // Stable identity for hover; defaults to the label.
	label string
}

// RadarSeries is one polygon of a radar chart: a value on every axis.
pub struct RadarSeries {
pub:
	key    string // Stable identity for hover and element ids; defaults to the name.
	name   string
	values []f64 // One per axis, in axis order. A missing value counts as the minimum.
	color  ?u32  // Stroke, and fill at fill_opacity; defaults to the theme palette.
	// fill_opacity overrides the chart's for this series; zero draws an outline.
	fill_opacity ?f64
}

// RadarChartGrid is the shape of a radar chart's concentric grid.
pub enum RadarChartGrid {
	polygon
	circle
	none
}

// RadarChartHoverMode says what the plot answers the pointer with.
pub enum RadarChartHoverMode {
	axis   // The nearest spoke: a dot on every series there, and one tooltip row each.
	series // The polygon under the pointer: it stands out, with its values listed.
}

// RadarChartHover is what is hovered: a spoke, a series (from the plot in
// .series mode or from the legend), or neither.
pub struct RadarChartHover {
pub:
	axis   string // Key of the hovered axis, or ''.
	series string // Key of the hovered series, or ''.
}

pub struct RadarChartConfig {
pub:
	id     string // Required: hover targets, dots and the appear use parts of it.
	frame  Rect
	axes   []RadarAxis
	series []RadarSeries
	// min_value is the value at the center; max_value the value at the outer
	// ring, zero to round the largest value up so the rings fall on round
	// numbers. Values outside the range are clamped to it.
	min_value    f64
	max_value    f64
	grid         RadarChartGrid = .polygon
	grid_levels  int            = 4
	level_labels bool // Write each ring's value beside the first spoke.
	dots         bool // A dot on every vertex of every series.
	fill_opacity f64 = 0.15
	stroke_width f64 = 2
	outer_radius f64 // Zero fits the chart and its axis labels in the frame.
	label_gap    f64 = 10 // Between the outer ring and the axis labels.
	label_color  ?u32 // Axis labels; the theme's muted foreground by default.
	legend       SpecialChartLegendPosition = .bottom
	hover_mode   RadarChartHoverMode        = .axis
	// hover is what the pointer is over; keep it with radar_chart_hover_from_event.
	hover           RadarChartHover
	interactive     bool = true
	appear          bool = true // Grow the polygons out of the center the first time.
	appear_key      string
	appear_duration f64 = 1.0
	reduce_motion   bool
	title           string // Accessibility label; "Radar chart" by default.
	size            ComponentSize = .medium
	theme           ComponentTheme
}

fn radar_chart_axis_keys(axes []RadarAxis) ![]string {
	return special_chart_keys(axes.map(it.key), axes.map(it.label), 'radar axis')
}

fn radar_chart_series_keys(series []RadarSeries) ![]string {
	return special_chart_keys(series.map(it.key), series.map(it.name), 'radar series')
}

// radar_chart_domain is the value range from the center to the outer ring:
// min_value up to max_value, or up to the largest value rounded so that each
// of `levels` rings falls on a round number.
pub fn radar_chart_domain(series []RadarSeries, min_value f64, max_value f64, levels int) (f64, f64) {
	if max_value > min_value {
		return min_value, max_value
	}
	mut top := min_value
	for s in series {
		for v in s.values {
			if component_finite(v) && v > top {
				top = v
			}
		}
	}
	if top <= min_value {
		return min_value, min_value + 1
	}
	count := if levels > 0 { levels } else { 4 }
	step := special_chart_nice_step(top - min_value, count)
	return min_value, min_value + step * f64(count)
}

// radar_chart_direction is the unit vector of spoke `index` of `count`,
// clockwise from twelve o'clock.
pub fn radar_chart_direction(index int, count int) PathPoint {
	angle := 2 * math.pi * f64(index) / f64(if count > 0 { count } else { 1 }) - math.pi / 2
	return path_point(math.cos(angle), math.sin(angle))
}

// radar_chart_polygon is where a series' vertices lie for a ring `radius`
// across, from center (cx, cy), with the values scaled into lo...hi.
pub fn radar_chart_polygon(values []f64, count int, cx f64, cy f64, radius f64, lo f64, hi f64) []PathPoint {
	mut points := []PathPoint{cap: count}
	span := hi - lo
	for i in 0 .. count {
		v := if i < values.len && component_finite(values[i]) { values[i] } else { lo }
		t := if span > 0 { math.clamp((v - lo) / span, 0.0, 1.0) } else { 0.0 }
		d := radar_chart_direction(i, count)
		points << path_point(cx + d.x * radius * t, cy + d.y * radius * t)
	}
	return points
}

// radar_chart_label_box is where axis label `index` sits for a ring `radius`
// across: pushed out from the ring by `gap` along its spoke, aligned away from
// the center, and moved outward by half its height above and below.
fn radar_chart_label_box(index int, count int, cx f64, cy f64, radius f64, gap f64, width f64, line f64) Rect {
	d := radar_chart_direction(index, count)
	ax := cx + (radius + gap) * d.x
	ay := cy + (radius + gap) * d.y
	x := if d.x > 1e-3 {
		ax
	} else if d.x < -1e-3 {
		ax - width
	} else {
		ax - width / 2
	}
	return rect(x, ay + d.y * line / 2 - line / 2, width, line)
}

// radar_chart_fit_radius is the largest ring that keeps itself and every axis
// label (widths[i] wide, `line` tall, `gap` out) inside `plot`.
pub fn radar_chart_fit_radius(plot Rect, widths []f64, line f64, gap f64) f64 {
	cx, cy := plot.x + plot.width / 2, plot.y + plot.height / 2
	mut r := math.min(plot.width, plot.height) / 2
	n := widths.len
	for i in 0 .. n {
		d := radar_chart_direction(i, n)
		box := radar_chart_label_box(i, n, cx, cy, 0, 0, widths[i], line)
		// box is the label at radius 0 with no gap; it moves by (r + gap) * d.
		ox0, ox1 := box.x - cx, box.x + box.width - cx
		oy0, oy1 := box.y - cy, box.y + box.height - cy
		if d.x > 1e-9 {
			r = math.min(r, (plot.x + plot.width - cx - ox1) / d.x - gap)
		} else if d.x < -1e-9 {
			r = math.min(r, (plot.x - cx - ox0) / d.x - gap)
		}
		if d.y > 1e-9 {
			r = math.min(r, (plot.y + plot.height - cy - oy1) / d.y - gap)
		} else if d.y < -1e-9 {
			r = math.min(r, (plot.y - cy - oy0) / d.y - gap)
		}
	}
	return math.max(r, 0.0)
}

// radar_chart_tooltip_corner puts the tooltip of a hovered spoke pointing
// along `d` in a corner of `plot`: the one across from the spoke, or else the
// nearest corner that is clear of `obstacles` (the axis labels and the hovered
// dots), so it does not cover what it describes.
pub fn radar_chart_tooltip_corner(d PathPoint, width f64, height f64, plot Rect, obstacles []Rect) Rect {
	left := d.x > 0.05
	top := d.y > 0.05 || (math.abs(d.y) <= 0.05 && d.x < 0)
	mut first := Rect{}
	for k, flips in [[false, false], [false, true], [true, false], [true, true]] {
		l := if flips[0] { !left } else { left }
		t := if flips[1] { !top } else { top }
		x := if l { plot.x } else { plot.x + plot.width - width }
		y := if t { plot.y } else { plot.y + plot.height - height }
		candidate := rect(math.max(plot.x, x), math.max(plot.y, y), width, height)
		if k == 0 {
			first = candidate
		}
		mut clear := true
		for o in obstacles {
			if radar_chart_overlaps(candidate, o) {
				clear = false
				break
			}
		}
		if clear {
			return candidate
		}
	}
	return first
}

fn radar_chart_overlaps(a Rect, b Rect) bool {
	return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height
		&& b.y < a.y + a.height
}

// radar_chart_axis_at is the spoke nearest the point (dx, dy) from the
// center, or -1 farther than `reach` from it.
pub fn radar_chart_axis_at(count int, dx f64, dy f64, reach f64) int {
	if count <= 0 || math.hypot(dx, dy) > reach {
		return -1
	}
	mut angle := math.atan2(dy, dx) + math.pi / 2
	angle = math.fmod(math.fmod(angle, 2 * math.pi) + 2 * math.pi, 2 * math.pi)
	return int(math.round(angle * f64(count) / (2 * math.pi))) % count
}

fn radar_chart_contains(points []PathPoint, x f64, y f64) bool {
	mut inside := false
	n := points.len
	for i in 0 .. n {
		a := points[i]
		b := points[(i + n - 1) % n]
		if (a.y > y) != (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x {
			inside = !inside
		}
	}
	return inside
}

// radar_chart_series_at is the series whose polygon is under (x, y): the
// smallest one containing it, so a polygon inside another stays reachable.
// It is -1 outside every polygon.
pub fn radar_chart_series_at(polygons [][]PathPoint, x f64, y f64) int {
	mut best := -1
	mut best_area := math.max_f64
	for i, points in polygons {
		if points.len < 3 || !radar_chart_contains(points, x, y) {
			continue
		}
		area := math.abs(path_signed_area(points))
		if area < best_area {
			best = i
			best_area = area
		}
	}
	return best
}

fn radar_chart_validate(config RadarChartConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	radar_chart_axis_keys(config.axes)!
	radar_chart_series_keys(config.series)!
	for s in config.series {
		for v in s.values {
			if !component_finite(v) {
				return error('radar values must be finite')
			}
		}
		if f := s.fill_opacity {
			if !component_finite(f) || f < 0 || f > 1 {
				return error('radar series fill_opacity must be in [0, 1]')
			}
		}
	}
	if !component_finite(config.min_value) || !component_finite(config.max_value) {
		return error('radar min_value and max_value must be finite')
	}
	if config.grid_levels < 1 || config.grid_levels > 20 {
		return error('radar grid_levels must be from 1 through 20')
	}
	if !component_finite(config.fill_opacity) || config.fill_opacity < 0 || config.fill_opacity > 1 {
		return error('radar fill_opacity must be in [0, 1]')
	}
	special_chart_validate_length('radar stroke_width', config.stroke_width)!
	special_chart_validate_length('radar outer_radius', config.outer_radius)!
	special_chart_validate_length('radar label_gap', config.label_gap)!
	special_chart_validate_length('radar appear_duration', config.appear_duration)!
}

fn radar_chart_series_color(config RadarChartConfig, colors SpecialChartColors, index int) u32 {
	return config.series[index].color or { special_chart_series_color(colors, index) }
}

fn radar_chart_value(s RadarSeries, index int) f64 {
	return if index < s.values.len { s.values[index] } else { 0.0 }
}

// radar_chart builds GPUI Kit's RadarChart: one polygon per series over a
// grid of rings and spokes, with axis labels, a legend and hover. It is
// controlled: keep `hover` with radar_chart_hover_from_event.
pub fn radar_chart(config RadarChartConfig) !Element {
	radar_chart_validate(config)!
	axis_keys := radar_chart_axis_keys(config.axes)!
	series_keys := radar_chart_series_keys(config.series)!
	colors := special_chart_colors(config.theme)
	font := special_chart_font(config.size)
	line := special_chart_line(font)
	local := component_local(config.frame)
	n := config.axes.len
	progress, driver := special_chart_appear(config.id, config.appear_key, config.appear,
		config.reduce_motion, config.appear_duration)
	whole := progress >= 1
	active := config.interactive && whole
	hovered_axis := if active && config.hover.axis.len > 0 {
		axis_keys.index(config.hover.axis)
	} else {
		-1
	}
	hovered_series := if active && config.hover.series.len > 0 {
		series_keys.index(config.hover.series)
	} else {
		-1
	}
	mut legend_items := []SpecialChartLegendItem{}
	if config.legend != .none {
		for i, s in config.series {
			legend_items << SpecialChartLegendItem{
				label:  s.name
				color:  radar_chart_series_color(config, colors, i)
				action: if config.interactive {
					special_chart_hover_action(config.id, 'series:${series_keys[i]}')
				} else {
					''
				}
				dimmed: hovered_series >= 0 && i != hovered_series
			}
		}
	}
	plot, legend_area, legend_frames := special_chart_legend_area(local, legend_items, config.legend,
		font)
	// A hovered axis label is bold; leave it room for either weight.
	widths := config.axes.map(math.ceil(math.max(special_chart_text_width(it.label, font, true),
		special_chart_text_width(it.label, font, false))))
	radius := if config.outer_radius > 0 {
		config.outer_radius
	} else {
		radar_chart_fit_radius(plot, widths, line, config.label_gap)
	}
	cx, cy := plot.x + plot.width / 2, plot.y + plot.height / 2
	lo, hi := radar_chart_domain(config.series, config.min_value, config.max_value, config.grid_levels)
	mut children := []Element{}
	children << driver
	if n >= 3 && radius > 0 && config.grid != .none {
		mut grid_path := []PathCommand{}
		for level in 1 .. config.grid_levels + 1 {
			r := radius * f64(level) / f64(config.grid_levels)
			if config.grid == .circle {
				grid_path << path_circle(cx, cy, r)
			} else {
				grid_path << path_polyline(radar_chart_polygon([]f64{len: n, init: hi}, n, cx,
					cy, r, lo, hi), true)
			}
		}
		for i in 0 .. n {
			d := radar_chart_direction(i, n)
			grid_path << path_move_to(cx, cy)
			grid_path << path_line_to(cx + d.x * radius, cy + d.y * radius)
		}
		children << shape(component_part_id(config.id, 'grid'), local, grid_path, ShapeStyle{
			stroke:       colors.grid
			stroke_width: 1
		})
		if hovered_axis >= 0 {
			d := radar_chart_direction(hovered_axis, n)
			children << shape(component_part_id(config.id, 'spoke'), local, [
				path_move_to(cx, cy),
				path_line_to(cx + d.x * radius, cy + d.y * radius),
			], ShapeStyle{
				stroke:       colors.axis
				stroke_width: 1.5
			})
		}
	}
	mut polygons := [][]PathPoint{}
	for s in config.series {
		polygons << radar_chart_polygon(s.values, n, cx, cy, radius, lo, hi)
	}
	if n >= 3 && radius > 0 {
		mut order := []int{len: config.series.len, init: index}
		if hovered_series >= 0 {
			order.delete(hovered_series)
			order << hovered_series
		}
		for i in order {
			color := radar_chart_series_color(config, colors, i)
			dim := hovered_series >= 0 && i != hovered_series
			fill := config.series[i].fill_opacity or { config.fill_opacity }
			grown := radar_chart_polygon(config.series[i].values, n, cx, cy, radius * progress,
				lo, hi)
			children << shape(component_part_id(config.id, 'series:${series_keys[i]}'), local,
				path_polyline(grown, true), ShapeStyle{
					fill:           color
					fill_opacity:   if dim {
						fill * 0.4
					} else if i == hovered_series {
						math.min(1.0, fill + 0.15)
					} else {
						fill
					}
					stroke:         color
					stroke_width:   config.stroke_width
					stroke_opacity: if dim { 0.35 } else { 1.0 }
					line_join:      .round
				})
			if config.dots || i == hovered_series {
				mut dots_path := []PathCommand{}
				for p in grown {
					dots_path << path_circle(p.x, p.y, 3.5)
				}
				children << shape(component_part_id(config.id, 'dots:${series_keys[i]}'), local,
					dots_path, ShapeStyle{
						fill:           color
						fill_opacity:   if dim { 0.35 } else { 1.0 }
						stroke:         colors.surface
						stroke_width:   1.5
						stroke_opacity: if dim { 0.35 } else { 1.0 }
					})
			}
		}
	}
	if config.level_labels && n >= 3 && radius > 0 {
		step_value := (hi - lo) / f64(config.grid_levels)
		decimals := special_chart_decimals(step_value)
		small := math.max(font - 2, 9.0)
		small_line := special_chart_line(small)
		for level in 1 .. config.grid_levels + 1 {
			r := radius * f64(level) / f64(config.grid_levels)
			level_text := special_chart_format(lo + step_value * f64(level), decimals)
			w := special_chart_text_width(level_text, small, false)
			children << special_chart_text(level_text, rect(cx + 4, cy - r + 1, w, small_line),
				colors.muted_text, small, false, .left)
		}
	}
	if n >= 1 && radius > 0 {
		for i, a in config.axes {
			box := radar_chart_label_box(i, n, cx, cy, radius, config.label_gap, widths[i],
				line)
			children << special_chart_text(a.label, box, if i == hovered_axis {
				colors.text
			} else {
				config.label_color or { colors.muted_text }
			}, font, i == hovered_axis, .center)
		}
	}
	children << special_chart_legend(legend_area, legend_frames, legend_items, colors, font)
	// Hover marks: a dot per series on the hovered spoke, gliding between spokes.
	glide := if config.reduce_motion { 0.0 } else { special_chart_glide_seconds }
	for i, _ in config.series {
		dot_id := component_part_id(config.id, 'hover-dot:${series_keys[i]}')
		if hovered_axis < 0 || n < 3 || radius <= 0 {
			special_chart_glide_reset(dot_id)
			continue
		}
		p := polygons[i][hovered_axis]
		size := 10.0
		special_chart_glide(dot_id, p.x - size / 2, p.y - size / 2, glide)
		children << view(dot_id, rect(p.x - size / 2, p.y - size / 2, size, size), BoxStyle{
			bg:            radar_chart_series_color(config, colors, i)
			radius:        size / 2
			border_color:  colors.surface
			border_left:   2
			border_top:    2
			border_right:  2
			border_bottom: 2
		}, []Element{})
	}
	tooltip_id := component_part_id(config.id, 'tooltip')
	if hovered_axis >= 0 && n >= 3 && radius > 0 && config.series.len > 0 {
		mut rows := []SpecialChartTooltipRow{}
		for i, s in config.series {
			rows << SpecialChartTooltipRow{
				color: radar_chart_series_color(config, colors, i)
				name:  s.name
				value: special_chart_auto_format(radar_chart_value(s, hovered_axis))
			}
		}
		title := config.axes[hovered_axis].label
		w, h := special_chart_tooltip_size(title, rows, font)
		mut obstacles := []Rect{}
		for i, _ in config.axes {
			obstacles << radar_chart_label_box(i, n, cx, cy, radius, config.label_gap, widths[i],
				line)
		}
		mut marks := []PathPoint{}
		for points in polygons {
			marks << points[hovered_axis]
		}
		d := radar_chart_direction(hovered_axis, n)
		marks << path_point(cx + d.x * radius, cy + d.y * radius)
		reach := path_bounds(path_polyline(marks, false))
		obstacles << rect(reach.x - 8, reach.y - 8, reach.width + 16, reach.height + 16)
		frame := radar_chart_tooltip_corner(d, w, h, plot, obstacles)
		children << special_chart_tooltip(tooltip_id, frame, title, rows, colors, font)
	} else if hovered_series >= 0 && n >= 1 && radius > 0 {
		s := config.series[hovered_series]
		mut rows := []SpecialChartTooltipRow{}
		for i, a in config.axes {
			rows << SpecialChartTooltipRow{
				name:  a.label
				value: special_chart_auto_format(radar_chart_value(s, i))
			}
		}
		w, h := special_chart_tooltip_size(s.name, rows, font)
		extent := path_bounds(path_polyline(polygons[hovered_series], true))
		frame := special_chart_tooltip_place(rect(extent.x + extent.width, cy, 0, 0), w, h,
			local, 12, false)
		children << special_chart_tooltip(tooltip_id, frame, s.name, rows, colors, font)
	}
	if active && n >= 3 && radius > 0 {
		reach := radius + config.label_gap
		box := rect(cx - reach, cy - reach, 2 * reach, 2 * reach)
		if config.hover_mode == .axis {
			actions := axis_keys.map(special_chart_hover_action(config.id, 'axis:${it}'))
			for hit in special_chart_hit_strips(box, 6, 3, fn [n, cx, cy, reach] (x f64, y f64) int {
				return radar_chart_axis_at(n, x - cx, y - cy, reach)
			}) {
				children << special_chart_hit_view(hit.frame, actions[hit.index])
			}
		} else {
			actions := series_keys.map(special_chart_hover_action(config.id, 'series:${it}'))
			hit_polygons := polygons.clone()
			for hit in special_chart_hit_strips(box, 6, 3, fn [hit_polygons] (x f64, y f64) int {
				return radar_chart_series_at(hit_polygons, x, y)
			}) {
				children << special_chart_hit_view(hit.frame, actions[hit.index])
			}
		}
	}
	mut summary := []string{}
	for s in config.series {
		mut parts := []string{}
		for i, a in config.axes {
			parts << '${a.label} ${special_chart_auto_format(radar_chart_value(s, i))}'
		}
		summary << '${s.name}: ${parts.join(', ')}'
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'img'
		accessibility_label: if config.title.len > 0 { config.title } else { 'Radar chart' }
		accessibility_value: summary.join('; ')
	})
}

// radar_chart_hover_from_event returns the next `hover` when the pointer
// enters or leaves a spoke's sector, a series' polygon or a legend item, and
// none for any other event.
pub fn radar_chart_hover_from_event(config RadarChartConfig, event string) ?RadarChartHover {
	entered, target := special_chart_hover_event(config.id, event) or { return none }
	if target.starts_with('axis:') {
		key := target['axis:'.len..]
		keys := radar_chart_axis_keys(config.axes) or { return none }
		if key !in keys {
			return none
		}
		if entered {
			return if key == config.hover.axis {
				none
			} else {
				RadarChartHover{
					...config.hover
					axis: key
				}
			}
		}
		return if key == config.hover.axis {
			RadarChartHover{
				...config.hover
				axis: ''
			}
		} else {
			none
		}
	}
	if target.starts_with('series:') {
		key := target['series:'.len..]
		keys := radar_chart_series_keys(config.series) or { return none }
		if key !in keys {
			return none
		}
		if entered {
			return if key == config.hover.series {
				none
			} else {
				RadarChartHover{
					...config.hover
					series: key
				}
			}
		}
		return if key == config.hover.series {
			RadarChartHover{
				...config.hover
				series: ''
			}
		} else {
			none
		}
	}
	return none
}
