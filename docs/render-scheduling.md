# Render scheduling

The custom renderer is demand driven by default: it builds its initial element
tree and then updates it when application work invalidates the window, and a
static window reuses its retained tree. Input, model actions, resize, worker
deliveries and animations request the work they need. Requests raised during a
frame are kept for the next frame. `.continuous` restores the historical
per-vsync rebuild loop, and `.manual` goes further: the frame callback stays
suppressed between explicit `refresh`/`request_refresh` asks, with deadlines
and running animations waking their own continuation:

```v
ui2.run_window_with_options(ui2.WindowOptions{
	title:   'App'
	width:   640
	height:  480
	refresh: .manual
}, build, event)
```

Call `ui2.refresh()` or `ui2.request_refresh()` after changing model data outside
an input or animation callback. Control setters such as `set_text` request a paint
and preserve other controls' current editing state.

Capture `ui2.ui_dispatcher()` on the UI thread and pass the handle to workers.
Its `post(fn () { ... })` method queues model work on the UI thread and requests a
frame. The handle belongs to that window; after close, `post` returns `false`.

`ui2.render_stats()` reports callbacks, builds, draws, flushes and pending work.
On Metal, idle callbacks skip both builds and draws. On X11 with EGL or GLX they skip
them too, once sokol honors `sapp_set_present_on_demand`: a frame that was not drawn
is not presented. The keep-alive repaints the retained tree about every ten seconds, so
Expose is served. Linux and BSD builds need a sokol that exports that function;
stock V does not have it yet. GL, EGL and D3D elsewhere present after each platform
callback, so
idle callbacks repaint the retained tree. Native
backends keep their platform refresh mechanisms; `refresh_on_demand()` reports
whether the window redraws only when asked.

The scheduler suspends painting while the window is iconified or suspended,
continues to deliver queued business work, and refreshes the surface on restore.
Close cancels queued work and visual timers.

## Acceptance fixture

Build and run the custom renderer acceptance fixture on macOS:

```sh
v -b c -cc clang -enable-globals -d ui2_custom_rendering run tests/render_scheduler --seconds 3
```

The fixture checks static reuse, worker delivery, request coalescing, a request
issued during a build, animation completion and return to idle. Add `--lifecycle`
to exercise real window minimize and restore on macOS, or `--interactive` to
inspect editing, scrolling and tooltips with counter output.
