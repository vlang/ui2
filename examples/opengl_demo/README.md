# OpenGL Widget (gg) Demo

`opengl(id, frame)` reserves a surface in the `gg` renderer. Until the application
supplies a texture the surface is empty, the way native backends show it. The
application renders into a GL texture
from `set_gl_surface_renderer`, which runs before each frame on the UI thread with
the GL context current, and passes the texture with `set_gl_surface_texture`.
ui2 draws it as a quad in the UI's own pass, so menus and other overlays draw
above it. A media player can use this to show video.

Two things the renderer has to mind for:

- It runs inside the frame sokol is driving. GL state it changes behind sokol's
  back — this demo binds a framebuffer and textures — must be handed back with
  `gfx.reset_state_cache()` before returning, or sokol may keep using stale
  bindings and draw the UI with them.
- The GL texture wrap is a feature of sokol's OpenGL backends (Linux, the
  BSDs, Android).
  Custom-rendered desktop builds run Metal or D3D11, which have no GL texture to
  wrap, so the texture draws as an empty quad there.

```sh
v -d ui2_custom_rendering run main.v
```
