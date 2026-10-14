# Render scheduling

The custom renderer builds its initial element tree and then updates it when
application work invalidates the window. A static window reuses its retained tree.
Input, model actions, resize, worker deliveries and animations request the work
they need. Requests raised during a frame are kept for the next frame.

Call `ui2.refresh()` or `ui2.request_refresh()` after changing model data outside
an input or animation callback. Control setters such as `set_text` request a paint
and preserve other controls' current editing state.

Capture `ui2.ui_dispatcher()` on the UI thread and pass the handle to workers.
Its `post(fn () { ... })` method queues model work on the UI thread and requests a
frame. The handle belongs to that window; after close, `post` returns `false`.

`ui2.render_stats()` reports callbacks, builds, draws, flushes and pending work.
On Metal, idle callbacks skip both builds and draws. GL, EGL and D3D present after
each platform callback, so idle callbacks repaint the retained tree. Native
backends use their platform refresh mechanisms.

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
