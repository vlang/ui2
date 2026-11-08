module ui2

import math

// PathPoint is a point in a shape's frame-local coordinates: x to the right, y
// down, as everywhere in ui2.
pub struct PathPoint {
pub:
	x f64
	y f64
}

pub fn path_point(x f64, y f64) PathPoint {
	return PathPoint{x, y}
}

// PathVerb says what one PathCommand does.
pub enum PathVerb {
	move_to  // start a subpath at (x, y)
	line_to  // a straight line to (x, y)
	quad_to  // a quadratic curve through (cx1, cy1) to (x, y)
	cubic_to // a cubic curve through (cx1, cy1) and (cx2, cy2) to (x, y)
	close    // a straight line back to where the subpath started
}

// PathCommand is one step of a path; build them with path_move_to and friends.
pub struct PathCommand {
pub:
	verb PathVerb
	x    f64
	y    f64
	cx1  f64
	cy1  f64
	cx2  f64
	cy2  f64
}

pub fn path_move_to(x f64, y f64) PathCommand {
	return PathCommand{
		verb: .move_to
		x:    x
		y:    y
	}
}

pub fn path_line_to(x f64, y f64) PathCommand {
	return PathCommand{
		verb: .line_to
		x:    x
		y:    y
	}
}

pub fn path_quad_to(cx f64, cy f64, x f64, y f64) PathCommand {
	return PathCommand{
		verb: .quad_to
		x:    x
		y:    y
		cx1:  cx
		cy1:  cy
	}
}

pub fn path_cubic_to(c1x f64, c1y f64, c2x f64, c2y f64, x f64, y f64) PathCommand {
	return PathCommand{
		verb: .cubic_to
		x:    x
		y:    y
		cx1:  c1x
		cy1:  c1y
		cx2:  c2x
		cy2:  c2y
	}
}

pub fn path_close() PathCommand {
	return PathCommand{
		verb: .close
	}
}

pub enum LineJoin {
	round
	miter
	bevel
}

pub enum LineCap {
	round
	butt
	square
}

// FillRule decides which parts of a self-overlapping path, or of one with
// holes, are inside it.
pub enum FillRule {
	nonzero  // inside where the path winds around the point at all
	even_odd // inside where an odd number of edges lie to one side
}

// ShapeStyle paints a path: a fill, a stroke along it, or both. Opacities run
// from 0 to 1 and apply to their own color only.
pub struct ShapeStyle {
pub:
	fill           ?u32
	fill_opacity   f64 = 1.0
	stroke         ?u32
	stroke_width   f64 = 1.0
	stroke_opacity f64 = 1.0
	line_join      LineJoin
	line_cap       LineCap
	fill_rule      FillRule
}

// shape draws a vector path inside `frame`. The path's coordinates are local
// to the frame, and what falls outside it is clipped. It is a view, so it can
// hold children drawn above the shape.
pub fn shape(id string, frame Rect, path []PathCommand, style ShapeStyle) Element {
	return Element{
		kind:        .view
		id:          id
		frame:       frame
		box:         BoxStyle{
			transparent: true
		}
		path:        path
		shape_style: style
	}
}

// element_has_shape reports whether a view draws a path.
fn element_has_shape(el Element) bool {
	if el.path.len == 0 {
		return false
	}
	style := el.shape_style
	return (style.fill != none && style.fill_opacity > 0)
		|| (style.stroke != none && style.stroke_width > 0 && style.stroke_opacity > 0)
}

// ── Path builders ──────────────────────────────────────────────────

// path_polyline joins points with straight lines, closing the figure if asked.
pub fn path_polyline(points []PathPoint, closed bool) []PathCommand {
	mut path := []PathCommand{cap: points.len + 1}
	for i, p in points {
		path << if i == 0 { path_move_to(p.x, p.y) } else { path_line_to(p.x, p.y) }
	}
	if closed && points.len > 1 {
		path << path_close()
	}
	return path
}

pub fn path_rect(r Rect) []PathCommand {
	return path_polyline([path_point(r.x, r.y), path_point(r.x + r.width, r.y),
		path_point(r.x + r.width, r.y + r.height), path_point(r.x, r.y + r.height)], true)
}

// path_kappa places the control points of the cubic that best follows a
// quarter circle.
const path_kappa = 0.5522847498307936

pub fn path_rounded_rect(r Rect, radius f64) []PathCommand {
	rad := math.max(0.0, math.min(radius, math.min(r.width, r.height) / 2))
	if rad <= 0 {
		return path_rect(r)
	}
	k := rad * path_kappa
	x0, y0 := r.x, r.y
	x1, y1 := r.x + r.width, r.y + r.height
	return [
		path_move_to(x0 + rad, y0),
		path_line_to(x1 - rad, y0),
		path_cubic_to(x1 - rad + k, y0, x1, y0 + rad - k, x1, y0 + rad),
		path_line_to(x1, y1 - rad),
		path_cubic_to(x1, y1 - rad + k, x1 - rad + k, y1, x1 - rad, y1),
		path_line_to(x0 + rad, y1),
		path_cubic_to(x0 + rad - k, y1, x0, y1 - rad + k, x0, y1 - rad),
		path_line_to(x0, y0 + rad),
		path_cubic_to(x0, y0 + rad - k, x0 + rad - k, y0, x0 + rad, y0),
		path_close(),
	]
}

pub fn path_ellipse(r Rect) []PathCommand {
	cx, cy := r.x + r.width / 2, r.y + r.height / 2
	rx, ry := r.width / 2, r.height / 2
	kx, ky := rx * path_kappa, ry * path_kappa
	return [
		path_move_to(cx + rx, cy),
		path_cubic_to(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry),
		path_cubic_to(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy),
		path_cubic_to(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry),
		path_cubic_to(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy),
		path_close(),
	]
}

pub fn path_circle(cx f64, cy f64, radius f64) []PathCommand {
	return path_ellipse(rect(cx - radius, cy - radius, radius * 2, radius * 2))
}

// path_arc is the arc of a circle from angle `start` to `end`, in radians
// measured from the positive x axis and growing clockwise on screen (y points
// down). It begins with a move to its first point unless `connect` asks for a
// line from wherever the path already is. Each quarter turn is one cubic.
pub fn path_arc(cx f64, cy f64, radius f64, start f64, end f64, connect bool) []PathCommand {
	mut path := []PathCommand{}
	sx, sy := cx + radius * math.cos(start), cy + radius * math.sin(start)
	path << if connect { path_line_to(sx, sy) } else { path_move_to(sx, sy) }
	sweep := end - start
	if radius <= 0 || sweep == 0 {
		return path
	}
	segments := int(math.ceil(math.abs(sweep) / (math.pi / 2) - 1e-9))
	step := sweep / f64(segments)
	alpha := 4.0 / 3.0 * math.tan(step / 4)
	mut a := start
	for _ in 0 .. segments {
		b := a + step
		ax, ay := math.cos(a), math.sin(a)
		bx, by := math.cos(b), math.sin(b)
		path << path_cubic_to(cx + radius * (ax - alpha * ay), cy + radius * (ay + alpha * ax),
			cx + radius * (bx + alpha * by), cy + radius * (by - alpha * bx), cx + radius * bx,
			cy + radius * by)
		a = b
	}
	return path
}

// path_sector is a pie slice: from the center out along `start`, around the
// arc to `end`, and back. Angles are as for path_arc.
pub fn path_sector(cx f64, cy f64, radius f64, start f64, end f64) []PathCommand {
	mut path := [path_move_to(cx, cy)]
	path << path_arc(cx, cy, radius, start, end, true)
	path << path_close()
	return path
}

// path_annular_sector is a slice of a ring, as a doughnut chart draws one.
pub fn path_annular_sector(cx f64, cy f64, inner f64, outer f64, start f64, end f64) []PathCommand {
	if inner <= 0 {
		return path_sector(cx, cy, outer, start, end)
	}
	mut path := path_arc(cx, cy, outer, start, end, false)
	path << path_arc(cx, cy, inner, end, start, true)
	path << path_close()
	return path
}

// path_smooth runs a curve through the points that never overshoots them:
// monotone cubic interpolation over x (Fritsch–Carlson), as line and area
// charts draw a smooth series. The points must be ordered by x.
pub fn path_smooth(points []PathPoint) []PathCommand {
	n := points.len
	if n < 3 {
		return path_polyline(points, false)
	}
	mut slopes := []f64{len: n - 1}
	for i in 0 .. n - 1 {
		dx := points[i + 1].x - points[i].x
		slopes[i] = if dx == 0 { 0.0 } else { (points[i + 1].y - points[i].y) / dx }
	}
	mut tangents := []f64{len: n}
	tangents[0] = slopes[0]
	tangents[n - 1] = slopes[n - 2]
	for i in 1 .. n - 1 {
		if slopes[i - 1] * slopes[i] <= 0 {
			tangents[i] = 0
		} else {
			tangents[i] = (slopes[i - 1] + slopes[i]) / 2
		}
	}
	for i in 0 .. n - 1 {
		if slopes[i] == 0 {
			tangents[i] = 0
			tangents[i + 1] = 0
			continue
		}
		a := tangents[i] / slopes[i]
		b := tangents[i + 1] / slopes[i]
		h := a * a + b * b
		if h > 9 {
			t := 3 / math.sqrt(h)
			tangents[i] = t * a * slopes[i]
			tangents[i + 1] = t * b * slopes[i]
		}
	}
	mut path := [path_move_to(points[0].x, points[0].y)]
	for i in 0 .. n - 1 {
		p0, p1 := points[i], points[i + 1]
		third := (p1.x - p0.x) / 3
		path << path_cubic_to(p0.x + third, p0.y + tangents[i] * third, p1.x - third,
			p1.y - tangents[i + 1] * third, p1.x, p1.y)
	}
	return path
}

// path_bounds is the smallest rectangle around a path's points and control
// points.
pub fn path_bounds(path []PathCommand) Rect {
	if path.len == 0 {
		return Rect{}
	}
	mut min_x, mut min_y := math.max_f64, math.max_f64
	mut max_x, mut max_y := -math.max_f64, -math.max_f64
	for cmd in path {
		if cmd.verb == .close {
			continue
		}
		mut xs := [cmd.x]
		mut ys := [cmd.y]
		if cmd.verb in [.quad_to, .cubic_to] {
			xs << cmd.cx1
			ys << cmd.cy1
		}
		if cmd.verb == .cubic_to {
			xs << cmd.cx2
			ys << cmd.cy2
		}
		for x in xs {
			min_x = math.min(min_x, x)
			max_x = math.max(max_x, x)
		}
		for y in ys {
			min_y = math.min(min_y, y)
			max_y = math.max(max_y, y)
		}
	}
	if min_x > max_x {
		return Rect{}
	}
	return rect(min_x, min_y, max_x - min_x, max_y - min_y)
}

// ── Geometry for renderers that draw triangles ─────────────────────

// PathContour is one subpath flattened to straight segments.
pub struct PathContour {
pub:
	points []PathPoint
	closed bool
}

// path_flatten turns a path into polylines whose segments stray from the
// curves by at most `tolerance`.
pub fn path_flatten(path []PathCommand, tolerance f64) []PathContour {
	tol := if tolerance > 0 { tolerance } else { 0.25 }
	mut contours := []PathContour{}
	mut points := []PathPoint{}
	mut start := PathPoint{}
	mut current := PathPoint{}
	for cmd in path {
		match cmd.verb {
			.move_to {
				if points.len > 1 {
					contours << PathContour{points, false}
				}
				points = [path_point(cmd.x, cmd.y)]
				start = points[0]
				current = start
			}
			.line_to {
				if points.len == 0 {
					points << current
					start = current
				}
				current = path_point(cmd.x, cmd.y)
				points << current
			}
			.quad_to, .cubic_to {
				if points.len == 0 {
					points << current
					start = current
				}
				c1 := path_point(cmd.cx1, cmd.cy1)
				c2 := if cmd.verb == .quad_to { c1 } else { path_point(cmd.cx2, cmd.cy2) }
				end := path_point(cmd.x, cmd.y)
				// A quadratic is a cubic with both controls two thirds of the way
				// from its ends to its control point.
				q1, q2 := if cmd.verb == .quad_to {
					path_point(current.x + 2.0 / 3.0 * (c1.x - current.x), current.y +
						2.0 / 3.0 * (c1.y - current.y)), path_point(end.x + 2.0 / 3.0 * (c1.x - end.x),
						end.y + 2.0 / 3.0 * (c1.y - end.y))
				} else {
					c1, c2
				}
				// Enough segments that the chord error stays under the tolerance.
				span := math.hypot(q1.x - current.x, q1.y - current.y) + math.hypot(q2.x - q1.x,
					q2.y - q1.y) + math.hypot(end.x - q2.x, end.y - q2.y)
				steps := int(math.min(math.max(math.ceil(math.sqrt(span / tol) * 0.75), 1), 256))
				for i in 1 .. steps + 1 {
					t := f64(i) / f64(steps)
					u := 1 - t
					x := u * u * u * current.x + 3 * u * u * t * q1.x + 3 * u * t * t * q2.x +
						t * t * t * end.x
					y := u * u * u * current.y + 3 * u * u * t * q1.y + 3 * u * t * t * q2.y +
						t * t * t * end.y
					points << path_point(x, y)
				}
				current = end
			}
			.close {
				if points.len > 1 {
					contours << PathContour{points, true}
				}
				points = []PathPoint{}
				current = start
			}
		}
	}
	if points.len > 1 {
		contours << PathContour{points, false}
	}
	return contours
}

fn path_signed_area(points []PathPoint) f64 {
	mut area := 0.0
	for i in 0 .. points.len {
		a := points[i]
		b := points[(i + 1) % points.len]
		area += a.x * b.y - b.x * a.y
	}
	return area / 2
}

fn path_point_in_triangle(p PathPoint, a PathPoint, b PathPoint, c PathPoint) bool {
	d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	d2 := (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	d3 := (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	negative := d1 < 0 || d2 < 0 || d3 < 0
	positive := d1 > 0 || d2 > 0 || d3 > 0
	return !(negative && positive)
}

// path_triangulate splits a simple polygon into triangles by ear clipping and
// returns their corners as index triples. A polygon that crosses itself has no
// ears left at some point, and gives none: draw it with path_fill_spans.
pub fn path_triangulate(points []PathPoint) ?[]int {
	mut pts := points.clone()
	// A closing point equal to the first adds nothing.
	if pts.len > 1 && pts[0] == pts[pts.len - 1] {
		pts.delete_last()
	}
	n := pts.len
	if n < 3 {
		return none
	}
	area := path_signed_area(pts)
	if area == 0 {
		return []int{}
	}
	// Work counterclockwise in the y-down plane, where convex corners turn with
	// a positive cross product.
	mut ring := []int{len: n, init: index}
	if area < 0 {
		ring.reverse_in_place()
	}
	mut triangles := []int{cap: (n - 2) * 3}
	mut guard := 0
	mut i := 0
	for ring.len > 3 {
		if guard > ring.len {
			return none
		}
		ia := ring[(i + ring.len - 1) % ring.len]
		ib := ring[i % ring.len]
		ic := ring[(i + 1) % ring.len]
		a, b, c := pts[ia], pts[ib], pts[ic]
		cross := (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
		mut ear := cross > 1e-12
		if ear {
			for j in ring {
				if j == ia || j == ib || j == ic {
					continue
				}
				p := pts[j]
				if p == a || p == b || p == c {
					continue
				}
				if path_point_in_triangle(p, a, b, c) {
					ear = false
					break
				}
			}
		} else if math.abs(cross) <= 1e-12 {
			// A straight-through corner: drop it without a triangle.
			ring.delete(i % ring.len)
			guard = 0
			continue
		}
		if ear {
			triangles << ia
			triangles << ib
			triangles << ic
			ring.delete(i % ring.len)
			guard = 0
		} else {
			i = (i + 1) % ring.len
			guard++
		}
	}
	if ring.len == 3 {
		triangles << ring[0]
		triangles << ring[1]
		triangles << ring[2]
	}
	// The triangles of a simple polygon add up to its area. A figure that
	// crosses itself can still lose all its corners as ears, but its triangles
	// then cover more than it does, and it has to be filled by rule instead.
	mut covered := 0.0
	for t := 0; t < triangles.len; t += 3 {
		covered += math.abs(path_signed_area([pts[triangles[t]], pts[triangles[t + 1]],
			pts[triangles[t + 2]]]))
	}
	if math.abs(covered - math.abs(area)) > 1e-6 * math.abs(area) + 1e-9 {
		return none
	}
	return triangles
}

// path_fill_spans is where the row at height `y` is inside the contours under
// the fill rule, as pairs of x positions from left to right. Every contour
// counts as closed.
pub fn path_fill_spans(contours []PathContour, rule FillRule, y f64) []f64 {
	mut crossings := []PathCrossing{}
	for contour in contours {
		pts := contour.points
		for i in 0 .. pts.len {
			a := pts[i]
			b := pts[(i + 1) % pts.len]
			if (a.y <= y && b.y > y) || (b.y <= y && a.y > y) {
				t := (y - a.y) / (b.y - a.y)
				crossings << PathCrossing{
					x:       a.x + t * (b.x - a.x)
					winding: if b.y > a.y { 1 } else { -1 }
				}
			}
		}
	}
	crossings.sort(a.x < b.x)
	mut spans := []f64{}
	mut winding := 0
	for crossing in crossings {
		was_inside := if rule == .nonzero { winding != 0 } else { winding % 2 != 0 }
		winding += crossing.winding
		inside := if rule == .nonzero { winding != 0 } else { winding % 2 != 0 }
		if !was_inside && inside {
			spans << crossing.x
		} else if was_inside && !inside {
			spans << crossing.x
		}
	}
	return spans
}

struct PathCrossing {
	x       f64
	winding int
}

// path_stroke_triangles is the outline of a stroke along the contours, as
// triangles (every three points one triangle): a quad per segment, plus joins
// and caps.
pub fn path_stroke_triangles(contours []PathContour, width f64, join LineJoin, cap LineCap) []PathPoint {
	mut tris := []PathPoint{}
	half := width / 2
	if half <= 0 {
		return tris
	}
	round_steps := int(math.min(math.max(math.ceil(half * 1.5), 3), 16))
	for contour in contours {
		mut pts := []PathPoint{cap: contour.points.len}
		for p in contour.points {
			if pts.len == 0 || pts[pts.len - 1] != p {
				pts << p
			}
		}
		if contour.closed && pts.len > 2 && pts[0] == pts[pts.len - 1] {
			pts.delete_last()
		}
		if pts.len < 2 {
			if pts.len == 1 && cap == .round {
				path_stroke_disc(mut tris, pts[0], half, round_steps * 2)
			}
			continue
		}
		segments := if contour.closed { pts.len } else { pts.len - 1 }
		for s in 0 .. segments {
			a := pts[s]
			b := pts[(s + 1) % pts.len]
			dx, dy := b.x - a.x, b.y - a.y
			length := math.hypot(dx, dy)
			if length == 0 {
				continue
			}
			nx, ny := -dy / length * half, dx / length * half
			mut a0, mut b0 := a, b
			if !contour.closed && cap == .square {
				ex, ey := dx / length * half, dy / length * half
				if s == 0 {
					a0 = path_point(a.x - ex, a.y - ey)
				}
				if s == segments - 1 {
					b0 = path_point(b.x + ex, b.y + ey)
				}
			}
			p1 := path_point(a0.x + nx, a0.y + ny)
			p2 := path_point(b0.x + nx, b0.y + ny)
			p3 := path_point(b0.x - nx, b0.y - ny)
			p4 := path_point(a0.x - nx, a0.y - ny)
			tris << p1
			tris << p2
			tris << p3
			tris << p1
			tris << p3
			tris << p4
		}
		// Joins at the inner corners, and at the start of a closed contour.
		first_join := if contour.closed { 0 } else { 1 }
		last_join := if contour.closed { pts.len } else { pts.len - 1 }
		for j in first_join .. last_join {
			prev := pts[(j + pts.len - 1) % pts.len]
			at := pts[j]
			next := pts[(j + 1) % pts.len]
			path_stroke_join(mut tris, prev, at, next, half, join, round_steps)
		}
		if !contour.closed && cap == .round {
			path_stroke_disc(mut tris, pts[0], half, round_steps * 2)
			path_stroke_disc(mut tris, pts[pts.len - 1], half, round_steps * 2)
		}
	}
	return tris
}

fn path_stroke_disc(mut tris []PathPoint, c PathPoint, r f64, steps int) {
	for i in 0 .. steps {
		a0 := 2 * math.pi * f64(i) / f64(steps)
		a1 := 2 * math.pi * f64(i + 1) / f64(steps)
		tris << c
		tris << path_point(c.x + r * math.cos(a0), c.y + r * math.sin(a0))
		tris << path_point(c.x + r * math.cos(a1), c.y + r * math.sin(a1))
	}
}

// path_stroke_join fills the wedge between two segments' quads on the outer
// side of the corner: a fan for round joins, a point for miters short enough,
// and a triangle across for bevels.
fn path_stroke_join(mut tris []PathPoint, prev PathPoint, at PathPoint, next PathPoint, half f64, join LineJoin, steps int) {
	d1x, d1y := at.x - prev.x, at.y - prev.y
	d2x, d2y := next.x - at.x, next.y - at.y
	l1, l2 := math.hypot(d1x, d1y), math.hypot(d2x, d2y)
	if l1 == 0 || l2 == 0 {
		return
	}
	cross := d1x * d2y - d1y * d2x
	if math.abs(cross) < 1e-9 * l1 * l2 {
		return
	}
	// The outer side is the one the path turns away from.
	side := if cross > 0 { -1.0 } else { 1.0 }
	n1x, n1y := -d1y / l1 * half * side, d1x / l1 * half * side
	n2x, n2y := -d2y / l2 * half * side, d2x / l2 * half * side
	o1 := path_point(at.x + n1x, at.y + n1y)
	o2 := path_point(at.x + n2x, at.y + n2y)
	match join {
		.bevel {
			tris << at
			tris << o1
			tris << o2
		}
		.miter {
			// The miter tip, where the two outer edges meet; past four widths it
			// becomes a bevel, as in SVG's default miter limit.
			bx, by := n1x / half + n2x / half, n1y / half + n2y / half
			bl := math.hypot(bx, by)
			cos_half := bl / 2
			if bl == 0 || cos_half < 0.25 {
				tris << at
				tris << o1
				tris << o2
				return
			}
			tip := path_point(at.x + bx / bl * half / cos_half, at.y + by / bl * half / cos_half)
			tris << at
			tris << o1
			tris << tip
			tris << at
			tris << tip
			tris << o2
		}
		.round {
			a0 := math.atan2(n1y, n1x)
			a1 := math.atan2(n2y, n2x)
			mut sweep := a1 - a0
			for sweep > math.pi {
				sweep -= 2 * math.pi
			}
			for sweep < -math.pi {
				sweep += 2 * math.pi
			}
			count := int(math.max(1, math.ceil(math.abs(sweep) / (math.pi / 2) * f64(steps) / 4)))
			for i in 0 .. count {
				t0 := a0 + sweep * f64(i) / f64(count)
				t1 := a0 + sweep * f64(i + 1) / f64(count)
				tris << at
				tris << path_point(at.x + half * math.cos(t0), at.y + half * math.sin(t0))
				tris << path_point(at.x + half * math.cos(t1), at.y + half * math.sin(t1))
			}
		}
	}
}
