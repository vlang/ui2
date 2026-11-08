import math
import time
import ui2
import sokol.gfx

#flag -lGL
#flag -DGL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>

const gl_color_buffer_bit = 0x00004000
const gl_texture_2d = 0x0de1
const gl_texture_min_filter = 0x2801
const gl_texture_mag_filter = 0x2800
const gl_linear = 0x2601
const gl_rgba = 0x1908
const gl_rgba8 = 0x8058
const gl_unsigned_byte = 0x1401
const gl_framebuffer = 0x8d40
const gl_color_attachment0 = 0x8ce0

fn C.glGenTextures(n i32, textures &u32)
fn C.glDeleteTextures(n i32, textures &u32)
fn C.glBindTexture(target u32, texture u32)
fn C.glTexImage2D(target u32, level i32, internal_format i32, width i32, height i32, border i32, format u32, typ u32, pixels voidptr)
fn C.glTexParameteri(target u32, pname u32, param i32)
fn C.glGenFramebuffers(n i32, framebuffers &u32)
fn C.glDeleteFramebuffers(n i32, framebuffers &u32)
fn C.glBindFramebuffer(target u32, framebuffer u32)
fn C.glFramebufferTexture2D(target u32, attachment u32, textarget u32, texture u32, level i32)
fn C.glClearColor(r f32, g f32, b f32, a f32)
fn C.glClear(mask u32)

// Surface is a GL texture of the element's size in pixels, with a framebuffer on it.
struct Surface {
mut:
	w   int
	h   int
	tex u32
	fbo u32
}

fn (mut s Surface) resize(w int, h int) {
	if s.fbo != 0 && s.w == w && s.h == h {
		return
	}
	if s.fbo != 0 {
		C.glDeleteFramebuffers(1, &s.fbo)
		C.glDeleteTextures(1, &s.tex)
	}
	s.w = w
	s.h = h
	C.glGenTextures(1, &s.tex)
	C.glBindTexture(gl_texture_2d, s.tex)
	C.glTexImage2D(gl_texture_2d, 0, gl_rgba8, i32(w), i32(h), 0, gl_rgba, gl_unsigned_byte,
		unsafe { nil })
	C.glTexParameteri(gl_texture_2d, gl_texture_min_filter, gl_linear)
	C.glTexParameteri(gl_texture_2d, gl_texture_mag_filter, gl_linear)
	C.glGenFramebuffers(1, &s.fbo)
	C.glBindFramebuffer(gl_framebuffer, s.fbo)
	C.glFramebufferTexture2D(gl_framebuffer, gl_color_attachment0, gl_texture_2d, s.tex, 0)
	C.glBindFramebuffer(gl_framebuffer, 0)
}

// draw paints the surface with a colour that cycles over time and hands the texture
// to ui2. It runs before each frame, with the GL context current.
fn (mut s Surface) draw(id string, frame ui2.Rect, scale f64, _ f64) {
	if id != 'gl_surface' {
		return
	}
	w := int(frame.width * scale)
	h := int(frame.height * scale)
	if w <= 0 || h <= 0 {
		return
	}
	s.resize(w, h)
	t := f64(time.ticks()) / 1000.0
	C.glBindFramebuffer(gl_framebuffer, s.fbo)
	C.glClearColor(f32(0.5 + 0.5 * math.sin(t)), f32(0.5 + 0.5 * math.sin(t + 2.1)),
		f32(0.5 + 0.5 * math.sin(t + 4.2)), 1)
	C.glClear(gl_color_buffer_bit)
	C.glBindFramebuffer(gl_framebuffer, 0)
	ui2.set_gl_surface_texture(id, s.tex, w, h)
	// GL changed state behind sokol's back; make sokol set its state again.
	gfx.reset_state_cache()
}

fn build() ui2.Element {
	return ui2.screen(0x1a1a2e, [
		ui2.label('', 'OpenGL surface', ui2.rect(20, 20, 360, 30), ui2.TextStyle{
			color: 0xffffff
			size:  18
			bold:  true
		}),
		ui2.opengl('gl_surface', ui2.rect(20, 100, 300, 300)),
	])
}

fn main() {
	mut surface := &Surface{}
	ui2.set_gl_surface_renderer(fn [mut surface] (id string, frame ui2.Rect, scale f64, height f64) {
		surface.draw(id, frame, scale, height)
	})
	ui2.run_window_with_options(ui2.WindowOptions{
		title: 'OpenGL Surface'
		width: 400
		height: 500
		refresh: .continuous
	}, build, fn (_ string) {})
}
