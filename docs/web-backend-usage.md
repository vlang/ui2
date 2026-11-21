# ui2 web backend — usage guide

The web backend runs the same `build()` / `on_event()` pair as a desktop ui2
app. V owns the model and the element tree; the browser is a thin DOM renderer.
Select the target at compile time with `-d ui2_headless`: the flag strips the
`gg`/Sokol windowing stack and includes a small `net`-based HTTP server with a
WebSocket-compatible frame layer instead. (`veb` and `net.websocket` crash when
started from a library module on V 0.5.2, so the backend speaks the protocol
directly; the wire format is unchanged.)

## 1. One app, two targets

`@[has_globals]` is required because `BuildFn` and `EventFn` are plain functions,
not closures. Keep state in a module global and read input back through the
`ui2.text()`, `ui2.slider_value()` and `ui2.scroll_offset()` accessors so the
same source works on both backends.

```v
@[has_globals]
module main

import ui2

struct Model {
mut:
	count int
	name  string = 'Ada'
}

__global mut g_model = Model{}

fn build() ui2.Element {
	return ui2.screen(0xf4f6f8, [
		ui2.label('value', 'count: ${g_model.count}', ui2.rect(24, 24, 220, 30), ui2.TextStyle{
			size: 16.0
		}),
		ui2.button('inc', '+', ui2.rect(24, 64, 56, 32), ui2.BoxStyle{
			bg: 0x2563eb
		}, ui2.TextStyle{color: 0xffffff}),
		ui2.text_field('name', 'Name', g_model.name, ui2.rect(24, 108, 220, 32),
			ui2.BoxStyle{}, ui2.TextStyle{}, ui2.keyboard_default),
	])
}

fn on_event(event string) {
	match event {
		'inc' {
			g_model.count++
		}
		'name' {
			g_model.name = ui2.text('name')
		}
		else {}
	}
}

fn main() {
	$if ui2_headless ? {
		ui2.run_web_window(ui2.WebOptions{
			title:  'My app'
			width:  500
			height: 400
		}, build, on_event)
	} $else {
		ui2.run_window('My app', 500, 400, build, on_event)
	}
}
```

A complete example lives in `examples/web_counter/main.v`.

## 2. Build and run

```sh
# Desktop
v run examples/web_counter/main.v

# Web (headless server + browser renderer)
v -d ui2_headless run examples/web_counter/main.v
```

On startup the web binary prints one JSON line to stdout:

```json
{"port":53791,"token":"8f14e45f-ea67-4bd2-a1c0-..."}
```

Open the printed address in a browser: `http://127.0.0.1:<port>/`. The page
loads without a query string — the server embeds the token in the page's
`#ui2-config` script, and the renderer appends `?token=<token>` to the
websocket URL itself. The `/events` websocket endpoint always requires a
matching `?token=`; direct clients must supply it.

To pin the port/host/token (useful for tooling):

```sh
v -d ui2_headless run examples/web_counter/main.v -- \
  --ui2-web-port 8080 --ui2-web-host 127.0.0.1 --ui2-web-token my-secret
```

The three CLI flags also accept `--flag=value`. They override the corresponding
`WebOptions` fields; use a free port (`port: 0`, the default) when the extension
picks the port for you.

`GET /snapshot` returns the current frame as JSON, which is handy for debugging
layout and the wire format without a browser.

## 3. Options

`ui2.WebOptions` fields:

| Field | Type | Default | CLI override | Notes |
|---|---|---|---|---|
| `title` | `string` | `'ui2'` | — | Browser/page title |
| `width` | `int` | `800` | — | Initial logical width; a resize event updates it |
| `height` | `int` | `600` | — | Initial logical height; a resize event updates it |
| `port` | `int` | `0` | `--ui2-web-port` | `0` picks a free port |
| `host` | `string` | `'127.0.0.1'` | `--ui2-web-host` | Bind address |
| `dpr` | `f64` | `1.0` | — | Initial device pixel ratio; the client reports the real value on resize |
| `token` | `string` | `''` | `--ui2-web-token` | Empty generates a random per-run UUID |
| `assets_dir` | `string` | `''` | — | Directory mounted at `/assets/*` (resolved with `os.resource_abs_path`) |
| `prod` | `bool` | `false` | — | Production-profile marker in server state; no toolchain/bundling is needed because the renderer is already embedded |

## 4. State accessors (desktop API parity)

| Call | Returns | Behavior |
|---|---|---|
| `ui2.text(id)` | `string` | Current value of a text field / text area / dropdown |
| `ui2.set_text(id, value)` | — | Sets the value and calls `refresh()` so the browser is updated |
| `ui2.slider_value(id)` | `f64` | Current slider value |
| `ui2.scroll_offset(id)` | `f64` | Current vertical scroll offset of a scroll element |

Values are updated before `on_event` runs, so handlers can read them directly.
After each event the server rebuilds the tree and broadcasts a patch; call
`refresh()` yourself only for model changes that happen outside an event.

## 5. Event mapping

Browser input is converted back to the exact strings a desktop `EventFn`
receives:

| Browser source | Wire `type` | `EventFn` string |
|---|---|---|
| Button / toggle / switch click | `tap` | bare action id (`action_id`, else `id`) |
| Text field / text area input | `change` | bare id; read value with `ui2.text(id)` |
| Text field / text area Enter | `key` | `enter` |
| Checkbox change | `change` | bare id; `value` is `'true'`/`'false'` |
| Dropdown change | `change` | bare id; selection via `ui2.text(id)` |
| Slider input | `change` | bare id; value via `ui2.slider_value(id)` |
| Scroll | `scroll` | `scroll:<id>:<dx>:<dy>`; offset via `ui2.scroll_offset(id)` |
| Pointer (clickable / hoverable / draggable elements) | `pointer` | `pointer:<phase>:<id>:<x>:<y>`; phase ∈ down/up/move/enter/leave/drag; coordinates are logical × dpr |
| Window keydown | `key` | normalized shortcut, modifiers in `cmd+ctrl+alt+shift` order, e.g. `cmd+shift+n` |
| Window resize | `resize` | `resize:<w>:<h>` (also updates server width/height/dpr; not forwarded to `EventFn`) |
| Focus / blur | `focus`, `blur` | `focus:<id>`, `blur:<id>` (mapped by the server; not yet emitted by the JS renderer) |

## 6. Element → DOM mapping

| Kind | DOM |
|---|---|
| screen / view | absolutely positioned `<div>`; `BoxStyle` → CSS (bg, gradient, per-edge borders, radius, opacity, shadow) |
| label | `<div>` (flex) + `TextStyle` (color, size, bold/italic/underline/strikethrough, align/valign) |
| button / toggle_button | `<button>` (`native_style` ignored) |
| text_field | `<input type=text>` (`secure` → password) |
| text_area | `<textarea>` (plain text) |
| checkbox | `<input type=checkbox>` |
| switch_control | `<button role=switch>` with `aria-checked` |
| dropdown | `<select>` populated from `menu` entries |
| slider | `<input type=range>` |
| scroll | overflow `<div>` from `scroll_mode`; emits scroll events |
| image | `<img>` from `image_path` (relative paths get a leading `/`) |
| opengl | placeholder `<canvas>` with a message |

Accessibility: `accessibility_role` → `role`, `accessibility_label` →
`aria-label`, `accessibility_value` → `aria-valuenow`.

## 7. Limitations and degradation

Unsupported platform APIs degrade explicitly; they never fail silently.

| API | Web behavior | Guidance |
|---|---|---|
| Menu bar / context menus | No native OS menu. A dropdown's `menu` becomes `<select>` options; context menus are not rendered by the renderer v1 | Build an in-page menu from views/buttons |
| System tray | No browser API; no-op | Use an in-page status area or host integration |
| `message_box` | No native dialog. Server-side errors appear in the renderer's in-page error overlay (`{type:'error'}`) | Implement dialogs as ui2 views; log details to stderr |
| `file_dialog` | No native picker. `assets_dir` serves static files at `/assets/*`; the renderer does not create `<input type=file>` in v1 | Ship assets up front or use host integration |
| Clipboard | No clipboard API wired in the renderer v1 | Rely on browser copy/paste inside text fields |
| OpenGL | Placeholder `<canvas>` | Provide a 2D fallback representation |
| Rich text runs (`text_runs`) | Ignored; plain text only | Use a single plain string |
| Vector `path` / `shape_style`, charts | Not rendered on web v1 (plain `<div>`) | Compose from views with `BoxStyle` |
| `native_style` | Ignored | Style with `BoxStyle`/`TextStyle` |
| Keyboard shortcuts | Normalized strings are sent, but the renderer does not call `preventDefault`, so browser-reserved combos may be intercepted | Prefer app-safe combinations |
| Screenshot tests | Out of scope for this milestone | Verify visually or with a future harness |

## 8. Troubleshooting

- **Blank page / "Snapshot failed"** — confirm the server is still running and
  visit `/snapshot`; it should return JSON. Check the terminal for a startup
  panic.
- **"invalid ui2 websocket token" / 403** — the WS URL token does not match the
  server's. Load the page from the same server (the token is embedded) or pass
  the exact token with `--ui2-web-token`; if you connect your own WS client,
  include `?token=...`.
- **Page loads but events do nothing** — the websocket must be in the OPEN
  state; check the browser console. Events are dropped while disconnected and
  the renderer reconnects automatically.
- **UI not updating after an out-of-band model change** — call `ui2.refresh()`
  after mutating state outside `on_event`; events already trigger a rebuild and
  patch on their own.
- **Focus or caret jumps while typing** — only scalar patches update nodes in
  place; a `replace_children` op (changed key/id/order) re-renders the tree.
  Give list children stable `key`/`id` values.
- **Fonts / spacing differ from desktop** — the browser uses a
  `system-ui, -apple-system, sans-serif` stack; set `TextStyle.font_family`
  explicitly for exact parity.
- **Blurry or mis-scaled UI on HiDPI** — set `WebOptions.dpr` for the initial
  frame; the client reports `window.devicePixelRatio` on resize and the server
  re-lays out.
- **Errors at the bottom of the page** — the renderer's red in-page overlay
  shows malformed config, failed snapshots, bad WS messages and server
  `{type:'error'}` messages.
