module ui2

import math

// Shape generators turn positions into paths and frames, as d3-shape (and
// GPUI Kit's plot shapes after it) do: bars, lines, areas, pie arcs and
// stacks. They are pure; draw what they return with `shape`.

// ── Bars ───────────────────────────────────────────────────────────

// PlotBarAlignment is the side a bar's baseline is on, and so its direction:
// vertical bars grow up from the bottom or down from the top, horizontal bars
// right from the left or left from the right.
pub enum PlotBarAlignment {
	bottom
	top
	left
	right
}

pub fn (alignment PlotBarAlignment) is_horizontal() bool {
	return alignment in [.left, .right]
}

// PlotCorners are the radii of a rectangle's four corners.
pub struct PlotCorners {
pub:
	top_left     f64
	top_right    f64
	bottom_right f64
	bottom_left  f64
}

// plot_corners rounds all four corners alike.
pub fn plot_corners(radius f64) PlotCorners {
	return PlotCorners{radius, radius, radius, radius}
}

// plot_tip_corners rounds only the two corners at a bar's tip, the end away
// from its baseline, so the bar stays square where it stands on the axis.
pub fn plot_tip_corners(alignment PlotBarAlignment, radius f64, base f64, tip f64) PlotCorners {
	if alignment.is_horizontal() {
		return if tip >= base {
			PlotCorners{
				top_right:    radius
				bottom_right: radius
			}
		} else {
			PlotCorners{
				top_left:    radius
				bottom_left: radius
			}
		}
	}
	return if tip <= base {
		PlotCorners{
			top_left:  radius
			top_right: radius
		}
	} else {
		PlotCorners{
			bottom_left:  radius
			bottom_right: radius
		}
	}
}

// plot_bar_rect is the frame of a bar `thickness` wide across the band axis,
// starting at `cross`, from `base` to `tip` along the value axis (positions,
// not values: a vertical bar's tip is above its base when its value is
// positive).
pub fn plot_bar_rect(alignment PlotBarAlignment, cross f64, thickness f64, base f64, tip f64) Rect {
	lo := math.min(base, tip)
	length := math.abs(tip - base)
	if alignment.is_horizontal() {
		return rect(lo, cross, length, thickness)
	}
	return rect(cross, lo, thickness, length)
}

// plot_bar_tip extends a bar shorter than `min_length` to that length, away
// from its base the way its value points (`positive` is the pixel direction,
// +1 or -1, of positive values, which a zero value takes too).
pub fn plot_bar_tip(base f64, tip f64, min_length f64, value f64, positive f64) f64 {
	if min_length <= 0 || math.abs(tip - base) >= min_length {
		return tip
	}
	direction := if value < 0 { -positive } else { positive }
	return base + direction * min_length
}

// plot_rounded_rect_path is a rectangle with each corner rounded by its own
// radius, limited to half the shorter side.
pub fn plot_rounded_rect_path(r Rect, corners PlotCorners) []PathCommand {
	limit := math.max(0.0, math.min(r.width, r.height) / 2)
	tl := math.max(0.0, math.min(corners.top_left, limit))
	tr := math.max(0.0, math.min(corners.top_right, limit))
	br := math.max(0.0, math.min(corners.bottom_right, limit))
	bl := math.max(0.0, math.min(corners.bottom_left, limit))
	if tl + tr + br + bl == 0 {
		return path_rect(r)
	}
	x0, y0 := r.x, r.y
	x1, y1 := r.x + r.width, r.y + r.height
	mut path := [path_move_to(x0 + tl, y0), path_line_to(x1 - tr, y0)]
	if tr > 0 {
		path << path_cubic_to(x1 - tr + tr * path_kappa, y0, x1, y0 + tr - tr * path_kappa,
			x1, y0 + tr)
	}
	path << path_line_to(x1, y1 - br)
	if br > 0 {
		path << path_cubic_to(x1, y1 - br + br * path_kappa, x1 - br + br * path_kappa, y1,
			x1 - br, y1)
	}
	path << path_line_to(x0 + bl, y1)
	if bl > 0 {
		path << path_cubic_to(x0 + bl - bl * path_kappa, y1, x0, y1 - bl + bl * path_kappa,
			x0, y1 - bl)
	}
	path << path_line_to(x0, y0 + tl)
	if tl > 0 {
		path << path_cubic_to(x0, y0 + tl - tl * path_kappa, x0 + tl - tl * path_kappa, y0,
			x0 + tl, y0)
	}
	path << path_close()
	return path
}

// ── Lines and areas ────────────────────────────────────────────────

// plot_line_path runs a line through the points with the curve. A point with
// a non-finite coordinate is a gap: the line stops before it and starts again
// after it.
pub fn plot_line_path(points []PathPoint, curve PlotCurve) []PathCommand {
	mut path := []PathCommand{}
	for run in plot_point_runs(points) {
		path << plot_curve(run, curve, false)
	}
	return path
}

// plot_point_runs splits points at the ones that are not finite.
fn plot_point_runs(points []PathPoint) [][]PathPoint {
	mut runs := [][]PathPoint{}
	mut current := []PathPoint{}
	for p in points {
		if plot_finite(p.x) && plot_finite(p.y) {
			current << p
		} else if current.len > 0 {
			runs << current
			current = []PathPoint{}
		}
	}
	if current.len > 0 {
		runs << current
	}
	return runs
}

// plot_curve is one unbroken run of the curve, starting with a move to its
// first point, or a line to it when `connect` continues an existing path.
fn plot_curve(points []PathPoint, curve PlotCurve, connect bool) []PathCommand {
	if points.len == 0 {
		return []PathCommand{}
	}
	first := points[0]
	mut path := [
		if connect { path_line_to(first.x, first.y) } else { path_move_to(first.x, first.y) },
	]
	if points.len == 1 {
		return path
	}
	match curve {
		.smooth {
			smooth := path_smooth(points)
			path << smooth[1..]
		}
		.linear {
			for p in points[1..] {
				path << path_line_to(p.x, p.y)
			}
		}
		.step_after {
			for i in 1 .. points.len {
				path << path_line_to(points[i].x, points[i - 1].y)
				path << path_line_to(points[i].x, points[i].y)
			}
		}
		.step_before {
			for i in 1 .. points.len {
				path << path_line_to(points[i - 1].x, points[i].y)
				path << path_line_to(points[i].x, points[i].y)
			}
		}
		.step {
			for i in 1 .. points.len {
				mid := (points[i - 1].x + points[i].x) / 2
				path << path_line_to(mid, points[i - 1].y)
				path << path_line_to(mid, points[i].y)
				path << path_line_to(points[i].x, points[i].y)
			}
		}
	}
	return path
}

// plot_area_path fills from the curve through `top` down (or up) to the
// horizontal `baseline`, as one closed figure.
pub fn plot_area_path(top []PathPoint, baseline f64, curve PlotCurve) []PathCommand {
	if top.len == 0 {
		return []PathCommand{}
	}
	mut path := plot_curve(top, curve, false)
	path << path_line_to(top[top.len - 1].x, baseline)
	path << path_line_to(top[0].x, baseline)
	path << path_close()
	return path
}

// plot_band_area_path fills between two curves, such as one layer of a
// stacked area chart: along `top`, then back along `bottom`. Both run through
// the same x positions, in order.
pub fn plot_band_area_path(top []PathPoint, bottom []PathPoint, curve PlotCurve) []PathCommand {
	if top.len == 0 || bottom.len == 0 {
		return []PathCommand{}
	}
	mut path := plot_curve(top, curve, false)
	back := plot_path_reverse(plot_curve(bottom, curve, false))
	if back.len > 0 {
		path << path_line_to(back[0].x, back[0].y)
		path << back[1..]
	}
	path << path_close()
	return path
}

// plot_path_reverse runs a path's first subpath backwards: the same figure,
// drawn from its end to its start.
pub fn plot_path_reverse(path []PathCommand) []PathCommand {
	if path.len == 0 {
		return []PathCommand{}
	}
	mut ends := []PathPoint{}
	mut segments := []PathCommand{}
	for i, cmd in path {
		if i > 0 && cmd.verb in [.move_to, .close] {
			break
		}
		if i == 0 {
			ends << path_point(cmd.x, cmd.y)
			continue
		}
		ends << path_point(cmd.x, cmd.y)
		segments << cmd
	}
	last := ends[ends.len - 1]
	mut out := [path_move_to(last.x, last.y)]
	for i := segments.len - 1; i >= 0; i-- {
		cmd := segments[i]
		to := ends[i]
		out << match cmd.verb {
			.quad_to { path_quad_to(cmd.cx1, cmd.cy1, to.x, to.y) }
			.cubic_to { path_cubic_to(cmd.cx2, cmd.cy2, cmd.cx1, cmd.cy1, to.x, to.y) }
			else { path_line_to(to.x, to.y) }
		}
	}
	return out
}

// plot_path_clip_right keeps the part of a path left of `x_max`: how a line
// draws in from the left. Each segment must run rightward (as chart curves
// do); one that crosses x_max is split exactly there and ends its subpath.
pub fn plot_path_clip_right(path []PathCommand, x_max f64) []PathCommand {
	mut out := []PathCommand{}
	mut current := PathPoint{}
	mut active := false
	for cmd in path {
		match cmd.verb {
			.move_to {
				current = path_point(cmd.x, cmd.y)
				active = cmd.x <= x_max
				if active {
					out << cmd
				}
			}
			.close {
				if active {
					out << cmd
				}
			}
			else {
				end := path_point(cmd.x, cmd.y)
				if !active {
					current = end
					continue
				}
				if end.x <= x_max {
					out << cmd
				} else {
					out << plot_split_segment(current, cmd, x_max)
					active = false
				}
				current = end
			}
		}
	}
	return out
}

// plot_split_segment is the part of a segment from `from` up to where it
// reaches x, found by bisection along the curve.
fn plot_split_segment(from PathPoint, cmd PathCommand, x f64) PathCommand {
	match cmd.verb {
		.cubic_to {
			mut lo, mut hi := 0.0, 1.0
			for _ in 0 .. 40 {
				t := (lo + hi) / 2
				if plot_cubic_at(from.x, cmd.cx1, cmd.cx2, cmd.x, t) < x {
					lo = t
				} else {
					hi = t
				}
			}
			t := (lo + hi) / 2
			// de Casteljau: the first part's control points.
			ax, ay := from.x + (cmd.cx1 - from.x) * t, from.y + (cmd.cy1 - from.y) * t
			bx, by := cmd.cx1 + (cmd.cx2 - cmd.cx1) * t, cmd.cy1 + (cmd.cy2 - cmd.cy1) * t
			cx, cy := cmd.cx2 + (cmd.x - cmd.cx2) * t, cmd.cy2 + (cmd.y - cmd.cy2) * t
			dx, dy := ax + (bx - ax) * t, ay + (by - ay) * t
			ex, ey := bx + (cx - bx) * t, by + (cy - by) * t
			return path_cubic_to(ax, ay, dx, dy, dx + (ex - dx) * t, dy + (ey - dy) * t)
		}
		.quad_to {
			mut lo, mut hi := 0.0, 1.0
			for _ in 0 .. 40 {
				t := (lo + hi) / 2
				u := 1 - t
				px := u * u * from.x + 2 * u * t * cmd.cx1 + t * t * cmd.x
				if px < x {
					lo = t
				} else {
					hi = t
				}
			}
			t := (lo + hi) / 2
			ax, ay := from.x + (cmd.cx1 - from.x) * t, from.y + (cmd.cy1 - from.y) * t
			bx, by := cmd.cx1 + (cmd.x - cmd.cx1) * t, cmd.cy1 + (cmd.y - cmd.cy1) * t
			return path_quad_to(ax, ay, ax + (bx - ax) * t, ay + (by - ay) * t)
		}
		else {
			span := cmd.x - from.x
			t := if span == 0 { 1.0 } else { math.max(0.0, math.min(1.0, (x - from.x) / span)) }
			return path_line_to(from.x + span * t, from.y + (cmd.y - from.y) * t)
		}
	}
}

fn plot_cubic_at(p0 f64, p1 f64, p2 f64, p3 f64, t f64) f64 {
	u := 1 - t
	return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
}

// plot_clip_polygon_y is the part of a polygon between the horizontal lines
// y_top and y_bottom (Sutherland–Hodgman), which is how an area fill fades:
// one slice per band of height, each a little more transparent.
pub fn plot_clip_polygon_y(points []PathPoint, y_top f64, y_bottom f64) []PathPoint {
	below := plot_clip_half(points, y_top, true)
	return plot_clip_half(below, y_bottom, false)
}

// plot_clip_half keeps the part of a polygon at or below the line y = bound
// (`keep_below`, larger y) or at or above it.
fn plot_clip_half(points []PathPoint, bound f64, keep_below bool) []PathPoint {
	if points.len == 0 {
		return []PathPoint{}
	}
	inside := fn [bound, keep_below] (p PathPoint) bool {
		return if keep_below { p.y >= bound } else { p.y <= bound }
	}
	mut out := []PathPoint{cap: points.len + 4}
	for i in 0 .. points.len {
		a := points[i]
		b := points[(i + 1) % points.len]
		a_in := inside(a)
		b_in := inside(b)
		if a_in {
			out << a
		}
		if a_in != b_in && b.y != a.y {
			t := (bound - a.y) / (b.y - a.y)
			out << path_point(a.x + (b.x - a.x) * t, bound)
		}
	}
	return out
}

// ── Pies and arcs ──────────────────────────────────────────────────

// PlotArc is one slice of a pie: the datum's index and value and the angles it
// spans, in radians from 12 o'clock growing clockwise, as d3 measures them.
// pad_angle is the gap the arc path leaves inside those angles.
pub struct PlotArc {
pub:
	index       int
	value       f64
	start_angle f64
	end_angle   f64
	pad_angle   f64
}

@[params]
pub struct PlotPieConfig {
pub:
	start_angle f64
	end_angle   f64 = 2 * math.pi
	pad_angle   f64 // radians between neighboring slices
}

// plot_pie divides the angle between the positive values in proportion, in
// data order. Zero, negative and missing values get no slice.
pub fn plot_pie(values []f64, config PlotPieConfig) []PlotArc {
	mut sum := 0.0
	mut count := 0
	for value in values {
		if plot_finite(value) && value > 0 {
			sum += value
			count++
		}
	}
	if count == 0 {
		return []PlotArc{}
	}
	span := config.end_angle - config.start_angle
	pad := math.min(math.abs(span) / f64(count), math.max(0.0, config.pad_angle))
	direction := if span < 0 { -1.0 } else { 1.0 }
	share := (math.abs(span) - pad * f64(count)) / sum
	mut angle := config.start_angle
	mut arcs := []PlotArc{cap: count}
	for i, value in values {
		if !plot_finite(value) || value <= 0 {
			continue
		}
		next := angle + direction * (value * share + pad)
		arcs << PlotArc{
			index:       i
			value:       value
			start_angle: angle
			end_angle:   next
			pad_angle:   pad
		}
		angle = next
	}
	return arcs
}

// plot_arc_path is the slice of a ring between `inner` and `outer` radii
// (a pie slice when inner is 0) around (cx, cy), with its pad angle taken
// out as a gap of even width, as d3's arc draws it.
pub fn plot_arc_path(arc PlotArc, cx f64, cy f64, inner f64, outer f64) []PathCommand {
	r0 := math.max(0.0, math.min(inner, outer))
	r1 := math.max(0.0, math.max(inner, outer))
	a0 := arc.start_angle - math.pi / 2
	a1 := arc.end_angle - math.pi / 2
	da := math.abs(a1 - a0)
	if r1 < 1e-9 || da < 1e-9 {
		return []PathCommand{}
	}
	if da >= 2 * math.pi - 1e-9 {
		mut ring := path_arc(cx, cy, r1, a0, a0 + 2 * math.pi, false)
		ring << path_close()
		if r0 > 1e-9 {
			ring << path_arc(cx, cy, r0, a0 + 2 * math.pi, a0, false)
			ring << path_close()
		}
		return ring
	}
	cw := if a1 > a0 { 1.0 } else { -1.0 }
	half_pad := arc.pad_angle / 2
	rp := math.sqrt(r0 * r0 + r1 * r1)
	mut a00, mut a10 := a0, a1
	mut a01, mut a11 := a0, a1
	if half_pad > 1e-9 && rp > 1e-9 {
		p1 := math.asin(math.min(1.0, rp / r1 * math.sin(half_pad)))
		if da - 2 * p1 > 1e-9 {
			a01 += p1 * cw
			a11 -= p1 * cw
		} else {
			a01 = (a0 + a1) / 2
			a11 = a01
		}
		if r0 > 1e-9 {
			p0 := math.asin(math.min(1.0, rp / r0 * math.sin(half_pad)))
			if da - 2 * p0 > 1e-9 {
				a00 += p0 * cw
				a10 -= p0 * cw
			} else {
				a00 = (a0 + a1) / 2
				a10 = a00
			}
		}
	}
	mut path := path_arc(cx, cy, r1, a01, a11, false)
	if r0 > 1e-9 {
		path << path_arc(cx, cy, r0, a10, a00, true)
	} else {
		path << path_line_to(cx, cy)
	}
	path << path_close()
	return path
}

// plot_arc_centroid is the middle of a slice, halfway between its radii and
// its angles, relative to the center: where a slice's label goes.
pub fn plot_arc_centroid(arc PlotArc, inner f64, outer f64) PathPoint {
	r := (inner + outer) / 2
	a := (arc.start_angle + arc.end_angle) / 2 - math.pi / 2
	return path_point(r * math.cos(a), r * math.sin(a))
}

// ── Stacks ─────────────────────────────────────────────────────────

// PlotStackOffset decides where each column of a stack starts.
pub enum PlotStackOffset {
	none      // every series on the one before it, from zero
	expand    // the same, divided by the column's total so it reaches 1
	diverging // positive values stack up from zero and negative ones down
}

// PlotStackPoint is one series' share of one column: from y0, the end nearer
// zero, to y1, so y1 - y0 is the value (a share for .expand).
pub struct PlotStackPoint {
pub:
	y0    f64
	y1    f64
	value f64 // the series' own value; missing values count as zero
}

pub struct PlotStackSeries {
pub:
	key    string
	index  int
	points []PlotStackPoint
}

// plot_stack stacks `values[series][column]` series by series, in the order of
// `keys`. Columns missing from a series count as zero.
pub fn plot_stack(keys []string, values [][]f64, offset PlotStackOffset) []PlotStackSeries {
	mut columns := 0
	for i in 0 .. keys.len {
		if i < values.len && values[i].len > columns {
			columns = values[i].len
		}
	}
	mut points := [][]PlotStackPoint{len: keys.len, init: []PlotStackPoint{cap: columns}}
	for j in 0 .. columns {
		mut column := []f64{len: keys.len}
		mut total := 0.0
		for i in 0 .. keys.len {
			value := if i < values.len && j < values[i].len && plot_finite(values[i][j]) {
				values[i][j]
			} else {
				0.0
			}
			column[i] = value
			total += value
		}
		mut up := 0.0
		mut down := 0.0
		for i, value in column {
			if offset == .diverging {
				if value >= 0 {
					points[i] << PlotStackPoint{up, up + value, value}
					up += value
				} else {
					points[i] << PlotStackPoint{down, down + value, value}
					down += value
				}
				continue
			}
			scale := if offset == .expand && total != 0 { 1 / total } else { 1.0 }
			points[i] << PlotStackPoint{up * scale, (up + value) * scale, value}
			up += value
		}
	}
	mut series := []PlotStackSeries{cap: keys.len}
	for i, key in keys {
		series << PlotStackSeries{
			key:    key
			index:  i
			points: points[i]
		}
	}
	return series
}

// plot_stack_extent is the lowest and highest edge of a stack, zero included:
// the domain its value axis has to cover.
pub fn plot_stack_extent(series []PlotStackSeries) (f64, f64) {
	mut lo, mut hi := 0.0, 0.0
	for s in series {
		for p in s.points {
			lo = math.min(lo, math.min(p.y0, p.y1))
			hi = math.max(hi, math.max(p.y0, p.y1))
		}
	}
	return lo, hi
}

// plot_close_to_baseline closes every subpath of a line down to the horizontal
// baseline, so a line (clipped or with gaps) becomes the area under it.
fn plot_close_to_baseline(path []PathCommand, baseline f64) []PathCommand {
	mut out := []PathCommand{cap: path.len + 8}
	mut first := PathPoint{}
	mut last := PathPoint{}
	mut open := false
	for cmd in path {
		if cmd.verb == .move_to {
			if open {
				out << path_line_to(last.x, baseline)
				out << path_line_to(first.x, baseline)
				out << path_close()
			}
			first = path_point(cmd.x, cmd.y)
			open = true
		}
		if cmd.verb != .close {
			last = path_point(cmd.x, cmd.y)
			out << cmd
		}
	}
	if open {
		out << path_line_to(last.x, baseline)
		out << path_line_to(first.x, baseline)
		out << path_close()
	}
	return out
}

// plot_close_between joins an upper edge and a lower edge (each one
// subpath, running rightward over the same span) into the band between them.
fn plot_close_between(top []PathCommand, bottom []PathCommand) []PathCommand {
	if top.len == 0 || bottom.len == 0 {
		return []PathCommand{}
	}
	mut out := top.clone()
	back := plot_path_reverse(bottom)
	out << path_line_to(back[0].x, back[0].y)
	out << back[1..]
	out << path_close()
	return out
}
