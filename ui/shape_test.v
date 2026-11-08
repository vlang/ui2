module ui2

import math

fn shape_close(a f64, b f64) bool {
	return math.abs(a - b) < 1e-6
}

fn test_shape_is_a_transparent_view_carrying_its_path() {
	el := shape('s', rect(0, 0, 40, 40), path_rect(rect(0, 0, 10, 10)), ShapeStyle{
		fill: u32(0xff0000)
	})
	assert el.kind == .view
	assert el.box.transparent
	assert el.path.len == 5
	assert element_has_shape(el)
	// Nothing to fill or stroke draws nothing.
	assert !element_has_shape(shape('t', rect(0, 0, 40, 40), path_rect(rect(0, 0, 10, 10)),
		ShapeStyle{}))
	assert !element_has_shape(shape('u', rect(0, 0, 40, 40), []PathCommand{}, ShapeStyle{
		fill: u32(0xff0000)
	}))
	assert !element_has_shape(shape('v', rect(0, 0, 40, 40), path_rect(rect(0, 0, 10, 10)),
		ShapeStyle{
			stroke:       u32(0)
			stroke_width: 0
		}))
}

fn test_path_arc_ends_where_its_angles_say() {
	path := path_arc(10, 10, 5, 0, math.pi, false)
	assert path[0].verb == .move_to
	assert shape_close(path[0].x, 15) && shape_close(path[0].y, 10)
	// Half a turn is two quarter cubics, ending on the far side; y grows down,
	// so the arc passes below the center.
	assert path.len == 3
	assert shape_close(path[1].x, 10) && shape_close(path[1].y, 15)
	assert shape_close(path[2].x, 5) && shape_close(path[2].y, 10)
	// Flattened, every point stays on the circle.
	for contour in path_flatten(path, 0.01) {
		for p in contour.points {
			assert math.abs(math.hypot(p.x - 10, p.y - 10) - 5) < 0.01
		}
	}
}

fn test_path_sector_and_annular_sector_close_their_figures() {
	pie := path_sector(0, 0, 10, 0, math.pi / 2)
	assert pie[0].verb == .move_to && pie[0].x == 0 && pie[0].y == 0
	assert pie[pie.len - 1].verb == .close
	ring := path_annular_sector(0, 0, 5, 10, 0, math.pi / 2)
	contours := path_flatten(ring, 0.05)
	assert contours.len == 1 && contours[0].closed
	// The inner arc runs back, so the figure is one simple ring slice.
	area := math.abs(path_signed_area(contours[0].points))
	expected := math.pi * (100 - 25) / 4
	assert math.abs(area - expected) / expected < 0.01
}

fn test_path_smooth_passes_through_its_points_without_overshooting() {
	points := [path_point(0, 10), path_point(10, 0), path_point(20, 0), path_point(30, 10)]
	path := path_smooth(points)
	assert path.len == 4
	for i, p in points[1..] {
		assert path[i + 1].x == p.x && path[i + 1].y == p.y
	}
	// The flat middle stays flat: monotone interpolation adds no bump.
	for contour in path_flatten(path, 0.01) {
		for p in contour.points {
			assert p.y >= -1e-9 && p.y <= 10 + 1e-9
		}
	}
}

fn test_path_bounds_cover_points_and_controls() {
	b := path_bounds([path_move_to(5, 5), path_quad_to(20, -5, 10, 10)])
	assert b == rect(5, -5, 15, 15)
	assert path_bounds([]PathCommand{}) == Rect{}
}

fn test_path_triangulate_covers_a_concave_polygon() {
	// An L shape: concave, area 3.
	l := [path_point(0, 0), path_point(2, 0), path_point(2, 1), path_point(1, 1), path_point(1, 2),
		path_point(0, 2)]
	for points in [l, l.reverse()] {
		tris := path_triangulate(points) or { panic('no triangles') }
		assert tris.len == 4 * 3
		mut area := 0.0
		for i := 0; i < tris.len; i += 3 {
			area += math.abs(path_signed_area([points[tris[i]], points[tris[i + 1]],
				points[tris[i + 2]]]))
		}
		assert shape_close(area, 3)
	}
	// A pentagram crosses itself: no triangles, so it is filled by rule.
	mut star := []PathPoint{}
	for i in 0 .. 5 {
		t := -math.pi / 2 + f64(i * 2) * 2 * math.pi / 5
		star << path_point(10 * math.cos(t), 10 * math.sin(t))
	}
	if _ := path_triangulate(star) {
		assert false
	}
	// Even-odd leaves the middle pentagon empty; nonzero fills it.
	contour := PathContour{star, true}
	assert path_fill_spans([contour], .even_odd, 0).len == 4
	assert path_fill_spans([contour], .nonzero, 0).len == 2
	// Too few points is not a polygon.
	if _ := path_triangulate([path_point(0, 0), path_point(1, 1)]) {
		assert false
	}
}

fn test_path_fill_spans_follow_the_fill_rule() {
	outer := PathContour{[path_point(0, 0), path_point(10, 0), path_point(10, 10), path_point(0, 10)], true}
	inner_same := PathContour{[path_point(3, 3), path_point(7, 3), path_point(7, 7), path_point(3, 7)], true}
	inner_reversed := PathContour{inner_same.points.reverse(), true}
	// Even-odd leaves a hole whichever way the inner square runs.
	assert path_fill_spans([outer, inner_same], .even_odd, 5) == [0.0, 3, 7, 10]
	assert path_fill_spans([outer, inner_reversed], .even_odd, 5) == [0.0, 3, 7, 10]
	// Nonzero leaves one only where the inner square winds the other way.
	assert path_fill_spans([outer, inner_same], .nonzero, 5) == [0.0, 10]
	assert path_fill_spans([outer, inner_reversed], .nonzero, 5) == [0.0, 3, 7, 10]
	assert path_fill_spans([outer], .nonzero, 20).len == 0
}

fn test_path_stroke_triangles_outline_a_segment() {
	line := PathContour{[path_point(0, 0), path_point(10, 0)], false}
	butt := path_stroke_triangles([line], 2, .miter, .butt)
	assert butt.len == 6
	for p in butt {
		assert p.x >= 0 && p.x <= 10 && math.abs(p.y) <= 1 + 1e-9
	}
	square := path_stroke_triangles([line], 2, .miter, .square)
	mut min_x := 0.0
	for p in square {
		min_x = math.min(min_x, p.x)
	}
	assert shape_close(min_x, -1)
	// Round caps add a disc at each end.
	assert path_stroke_triangles([line], 2, .round, .round).len > 6
	// A right-angle corner gets a miter tip one half-width out on each axis.
	corner := PathContour{[path_point(0, 0), path_point(10, 0), path_point(10, 10)], false}
	tris := path_stroke_triangles([corner], 2, .miter, .butt)
	mut found_tip := false
	for p in tris {
		if shape_close(p.x, 11) && shape_close(p.y, -1) {
			found_tip = true
		}
	}
	assert found_tip
	assert path_stroke_triangles([line], 0, .round, .round).len == 0
}
