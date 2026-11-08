// vfmt off
@[has_globals]
module ui2

// gl_surface.v is the platform-neutral side of `opengl` elements. The gg renderer
// draws them, and native backends show them as transparent views, so applications
// can call these functions on every platform. Wrapping a GL texture is a feature of
// sokol's OpenGL backends — Linux and Android; custom-rendered desktop builds run
// Metal or D3D11, which have no GL texture to wrap, so a texture handed over there
// draws as an empty quad.

// GlTextureRequest names a GL texture that the application renders into for one
// `opengl` element. The texture stays owned by the application.
pub struct GlTextureRequest {
pub:
	gl_texture u32
	width      int
	height     int
}

__global g_gl_surface_renderer = GlSurfaceFn(unsafe { nil })
__global g_gl_surface_requests = map[string]GlTextureRequest{}
// g_frame_running is true while ui2's on_frame is building and drawing the
// window. request_refresh below reads it so a producer inside the surface
// renderer does not schedule a second frame, and menu_default reads it so a
// menu bar set during the frame does not ask for another one. Declared here,
// outside the guarded platform block of ui_immediate.c.v, because its readers
// compile on every platform while its writer (on_frame) exists only in the
// guarded block.
__global g_frame_running = false

// set_gl_surface_renderer installs the function that renders into each `opengl`
// element. It runs before every frame, on the UI thread, with the GL context current,
// for the elements drawn in the previous frame. A new element is therefore first
// rendered one frame after it appears.
//
// The renderer runs inside the frame sokol is already driving. GL state it changes
// behind sokol's back — a framebuffer or texture it binds — has to be handed back
// with gfx.reset_state_cache() before returning, or sokol may skip reapplying
// bindings and draw the UI with stale ones.
pub fn set_gl_surface_renderer(renderer GlSurfaceFn) {
	g_gl_surface_renderer = renderer
}

// set_gl_surface_texture shows gl_texture, a GL texture of width x height pixels, in
// the `opengl` element with this id. Call it from the surface renderer. Requests for
// elements that are no longer drawn are dropped.
pub fn set_gl_surface_texture(id string, gl_texture u32, width int, height int) {
	g_gl_surface_requests[id] = GlTextureRequest{
		gl_texture: gl_texture
		width:      width
		height:     height
	}
	// A producer that runs outside the frame — its render thread handed the
	// texture over through another channel, or native backends let the
	// application call here between frames — needs this ask: without it, on
	// Metal an idle window draws nothing and the update would never reach the
	// screen. A producer inside the surface renderer runs in the frame ui2 is
	// already building, whose sync consumes the request; an ask there
	// schedules a second frame with nothing new to show, which loops for as
	// long as the surface is handed over every frame. The scheduler's queue is
	// mutex guarded, so this is safe off the UI thread.
	if g_frame_running {
		return
	}
	request_refresh()
}
