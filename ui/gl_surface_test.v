@[has_globals]
module ui2

fn test_opengl_element_is_a_transparent_surface_at_its_frame() {
	el := opengl('video', rect(1, 2, 3, 4))
	assert el.kind == .opengl
	assert el.id == 'video'
	assert el.frame == rect(1, 2, 3, 4)
	assert el.box.transparent
}

fn test_set_gl_surface_texture_records_the_request() {
	set_gl_surface_texture('video', 7, 640, 480)
	request := g_gl_surface_requests['video'] or { panic('no request recorded') }
	assert request.gl_texture == 7
	assert request.width == 640
	assert request.height == 480
	g_gl_surface_requests.delete('video')
}

fn test_set_gl_surface_renderer_installs_and_clears_the_renderer() {
	set_gl_surface_renderer(fn (id string, frame Rect, scale f64, height f64) {})
	assert voidptr(g_gl_surface_renderer) != unsafe { nil }
	set_gl_surface_renderer(GlSurfaceFn(unsafe { nil }))
	assert voidptr(g_gl_surface_renderer) == unsafe { nil }
}
