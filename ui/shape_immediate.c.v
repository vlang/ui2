// vfmt off
// Keep gg imports out of the native AppKit/Win32 and headless builds.
@[has_globals]
module ui2

$if (android || linux || freebsd || openbsd || netbsd || dragonfly || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg
	import math

	// ShapeGeometry is a shape turned into triangles in its frame's coordinates,
	// kept per element id: the custom renderer draws every frame, and ear clipping
	// a long area chart each time would cost more than the drawing.
	struct ShapeGeometry {
		signature u64
		fill      []PathPoint
		stroke    []PathPoint
	}

	__global g_shape_geometry = map[string]ShapeGeometry{}

	const shape_geometry_cache_limit = 1024

	// draw_shape paints a view's path at (x, y), clipped to the view's frame.
	fn draw_shape(ctx &gg.Context, el Element, x f64, y f64, clip Rect) {
		if !element_has_shape(el) {
			return
		}
		frame_clip := intersect_rect(rect(x, y, el.frame.width, el.frame.height), clip)
		if frame_clip.width <= 0 || frame_clip.height <= 0 {
			return
		}
		scale := math.max(f64(ctx.scale), 1.0)
		geometry := shape_geometry(el, scale)
		style := el.shape_style
		apply_clip(ctx, frame_clip)
		if fill := style.fill {
			shape_triangles(ctx, geometry.fill, x, y, f64(ctx.scale), shape_color(fill, style.fill_opacity))
		}
		if stroke := style.stroke {
			shape_triangles(ctx, geometry.stroke, x, y, f64(ctx.scale), shape_color(stroke,
				style.stroke_opacity))
		}
		apply_clip(ctx, clip)
	}

	fn shape_geometry(el Element, scale f64) ShapeGeometry {
		signature := shape_signature(el, scale)
		if el.id.len > 0 {
			if cached := g_shape_geometry[el.id] {
				if cached.signature == signature {
					return cached
				}
			}
		}
		style := el.shape_style
		contours := path_flatten(el.path, 0.3 / scale)
		mut fill := []PathPoint{}
		if style.fill != none && style.fill_opacity > 0 {
			fill = shape_fill_triangles(contours, style.fill_rule, scale)
		}
		mut stroke := []PathPoint{}
		if style.stroke != none && style.stroke_width > 0 && style.stroke_opacity > 0 {
			stroke = path_stroke_triangles(contours, style.stroke_width, style.line_join,
				style.line_cap)
		}
		geometry := ShapeGeometry{signature, fill, stroke}
		if el.id.len > 0 {
			if g_shape_geometry.len >= shape_geometry_cache_limit {
				g_shape_geometry.clear()
			}
			g_shape_geometry[el.id] = geometry
		}
		return geometry
	}

	// shape_signature hashes everything the geometry depends on (FNV-1a over the
	// path's numbers), so a cached shape is rebuilt exactly when it changes.
	fn shape_signature(el Element, scale f64) u64 {
		mut h := u64(0xcbf29ce484222325)
		h = shape_hash_mix(h, math.f64_bits(scale))
		h = shape_hash_mix(h, math.f64_bits(el.shape_style.stroke_width))
		h = shape_hash_mix(h, u64(el.shape_style.line_join) << 8 | u64(el.shape_style.line_cap) << 4 | u64(el.shape_style.fill_rule))
		h = shape_hash_mix(h, u64(if el.shape_style.fill != none { 1 } else { 0 }) | u64(if el.shape_style.stroke != none { 2 } else { 0 }))
		for cmd in el.path {
			h = shape_hash_mix(h, u64(cmd.verb))
			for value in [cmd.x, cmd.y, cmd.cx1, cmd.cy1, cmd.cx2, cmd.cy2] {
				h = shape_hash_mix(h, math.f64_bits(value))
			}
		}
		return h
	}

	// A named function rather than a closure: V's Windows C for a closure here
	// declared one of its temporaries with the wrong function type.
	fn shape_hash_mix(h u64, value u64) u64 {
		return (h ^ value) * 1099511628211
	}

	// shape_fill_triangles fills one simple polygon (the usual chart shape) with
	// triangles, so the multisampled edges come out smooth. Holes and figures that
	// cross themselves are filled row by row, one device pixel at a time.
	fn shape_fill_triangles(contours []PathContour, rule FillRule, scale f64) []PathPoint {
		mut tris := []PathPoint{}
		if contours.len == 0 {
			return tris
		}
		if contours.len == 1 {
			points := contours[0].points
			if indices := path_triangulate(points) {
				tris = []PathPoint{cap: indices.len}
				for i in indices {
					tris << points[i]
				}
				return tris
			}
		}
		mut top, mut bottom := math.max_f64, -math.max_f64
		for contour in contours {
			for p in contour.points {
				top = math.min(top, p.y)
				bottom = math.max(bottom, p.y)
			}
		}
		step := 1.0 / scale
		mut row := math.floor(top * scale) / scale
		for row < bottom {
			spans := path_fill_spans(contours, rule, row + step / 2)
			for i := 0; i + 1 < spans.len; i += 2 {
				a, b := spans[i], spans[i + 1]
				tris << path_point(a, row)
				tris << path_point(b, row)
				tris << path_point(b, row + step)
				tris << path_point(a, row)
				tris << path_point(b, row + step)
				tris << path_point(a, row + step)
			}
			row += step
		}
		return tris
	}

	fn shape_color(hex u32, opacity f64) gg.Color {
		return gg.Color{
			...hex_color(hex)
			a: u8(math.round(unit_clamp(opacity) * 255))
		}
	}

	fn shape_triangles(ctx &gg.Context, tris []PathPoint, x f64, y f64, scale f64, c gg.Color) {
		if tris.len < 3 || c.a == 0 {
			return
		}
		if c.a != 255 {
			ctx.r.load_pipeline(ctx.pipeline.alpha)
		}
		ctx.r.c4b(c.r, c.g, c.b, c.a)
		ctx.r.begin_triangles()
		for p in tris {
			ctx.r.v2f(f32((x + p.x) * scale), f32((y + p.y) * scale))
		}
		ctx.r.end()
	}
}
