# Web backend (Flutter-style) — tracking issue

Goal: run any ui2 app in a browser with no app-code changes, the way
Flutter runs the same widgets on mobile/desktop/web.

```v
import ui2

fn build() ui2.Element { /* same tree as desktop */ return ui2.screen(...) }
fn on_event(e string) { /* same handler as desktop */ }

fn main() {
	$if ui2_headless ? {
		ui2.run_web_window(opts, build, on_event) // browser
	} $else {
		ui2.run_window('App', 800, 600, build, on_event) // desktop
	}
}
```

First consumer: component preview in the VS Code extension
(`vscode-vlang` webview panel). It is built as a real deployable target, not a
preview-only hack: `v -d ui2_headless run app.v` serves the same app from one
binary, with no run-time toolchain. See [web-backend-usage.md](web-backend-usage.md)
for the usage guide and [web-backend-vscode.md](web-backend-vscode.md) for the
VS Code preview spec.

## Why this shape (not WASM-first)

- `Element` (`ui/ui.v`) is already plain data: `Kind`, `Rect`, `BoxStyle`,
  `TextStyle`, `children`, etc. It JSON-encodes with no FFI.
- `-d ui2_headless` already strips `gg`/Sokol from the build, so a V
  server can own state + `BuildFn`/`EventFn` with no window.
- A headless V app can serve a snapshot over HTTP and stream patches/events
  over a socket. The backend uses V's `net` listener with a small HTTP/1.1 and
  WebSocket frame layer; `veb`/`net.websocket` could not be started from a
  library module on V 0.5.2 (verified with a minimal probe), so the protocol is
  spoken directly while keeping the wire format stable.
- Browser side is a small, type-checked JS DOM renderer (`web/renderer/`),
  embedded into the binary at compile time. No Emscripten/Sokol-WebGL
  dependency, accessible HTML for free, works inside a VS Code webview.
- WASM (compile the V app to the browser) stays an option later; the JSON
  protocol below is the contract either side would speak.

## Architecture

```text
V app (headless)            browser / VS Code webview
─────────────────           ─────────────────────────
build() -> Element
   │  validate_element_tree
   ▼
web_snapshot_message --HTTP GET /snapshot--> render DOM
   │                                          │ user input
refresh() -- WS full snapshot <── WS event json ┘
   │
web_diff_trees -- WS patch --> apply ops to DOM
```

- V owns all state. The browser never invents ids; it echoes action ids and
  pointer/text/key/scroll values as the existing `EventFn(string)` strings.
- A `refresh()` pushes a full snapshot; ordinary input events push a keyed
  patch from `web_diff_trees()`. A `resize` pushes a full snapshot because the
  viewport may change the layout. Scalar-only patches update a DOM node in
  place so typing, focus and scroll position survive.
- Text measurement: the server re-lays out from `build()` on every event. The
  client reports `devicePixelRatio` and viewport size on resize so the tree
  is built for the right geometry.

## Protocol (v0, implemented)

Three JSON envelopes share a `type` discriminator. `ElementDTO` is the 1:1 JSON
of `ui.v` `Element` — all its fields are data; enums (`Kind`, `Align`,
`ScrollMode`, `PatchOpKind`, …) encode as strings.

Server → client (over WS; `GET /snapshot` returns the same snapshot envelope over HTTP):

| Message | Shape |
|---|---|
| `snapshot` | `{ type:'snapshot', title, width, height, dpr, seq, root: ElementDTO }` — full frame |
| `patch` | `{ type:'patch', seq, ops: PatchOp[] }` — changes since the last frame |
| `error` | `{ type:'error', message }` — renderer shows an error overlay |

`PatchOp` entries:

| `kind` | Fields | Meaning |
|---|---|---|
| `update` | `path: int[]`, `element: ElementDTO` | Change scalar fields of the node at `path` in place; children are kept |
| `replace_children` | `path: int[]`, `children: ElementDTO[]` | Swap a node's whole child list when keys/ids/kind/order change; renderer re-renders the tree |

`path` is a list of child indices from the root; `[]` addresses the root itself.
Reconciliation identity mirrors the native backends: `Element.key`, then
`Element.id`, then child index.

Client → server (WS) is one `WebEvent`:
`{ type, id, action, value, x, y, dx, dy, key, code, shift, ctrl, alt, cmd, token }`.
`id` identifies the element for state lookup; `action` carries the desktop
`EventFn` identity (`action_id`, falling back to `id`).
Types: `tap`, `change`, `pointer`, `scroll`, `key`, `resize`, `focus`, `blur`.
Every event echoes `token`, which the server checks; the WS URL itself also
requires `?token=...`. `web_event_string()` maps events to the exact strings
`EventFn` receives on desktop:

| `WebEvent.type` | `EventFn` string |
|---|---|
| `tap`, `change` | bare action id (`action_id`, falling back to `id`) |
| `pointer` | `pointer:<phase>:<id>:<x>:<y>`; phase ∈ down/up/move/enter/leave/drag; coords are logical × dpr, formatted like desktop f64 (e.g. `7.0`) |
| `scroll` | `scroll:<id>:<dx>:<dy>` |
| `key` | normalized shortcut with modifiers in `cmd+ctrl+alt+shift` order (e.g. `cmd+shift+n`) |
| `focus`, `blur` | `focus:<id>`, `blur:<id>` (mapped by the server; not yet emitted by the JS renderer) |
| `resize` | `resize:<w>:<h>`; also updates server width/height/dpr, and is not forwarded to `EventFn` |

## Element → DOM mapping (implemented)

| Kind | DOM |
|---|---|
| screen / view | absolutely positioned `<div>`; `BoxStyle` → CSS (bg, gradient, per-edge borders, radius, opacity, shadow) |
| label | `<div>` (flex) + `TextStyle` (color, size, bold/italic/underline/strikethrough, align/valign) |
| button / toggle_button | `<button>` (`native_style` ignored on web) |
| text_field | `<input type=text>` (`secure` → `type=password`); input emits `change`, Enter emits a `key` event (`enter`) |
| text_area | `<textarea>` (plain text only; rich runs are not rendered) |
| checkbox | `<input type=checkbox>` |
| switch_control | `<button role=switch>` with `aria-checked` |
| dropdown | `<select>` populated from `menu` entries |
| slider | `<input type=range>` |
| scroll | overflow `<div>`, axis from `scroll_mode`; emits scroll events |
| image | `<img>` from `image_path` (relative paths prefixed with `/`); Win32 BMP-only limits do not apply |
| opengl | placeholder `<canvas>` with a message; no GL texture on web v1 |

Not rendered on web v1: vector `path`/`shape_style` and charts built from them
fall back to plain `<div>`s (no SVG/canvas shape renderer), and rich text runs
are ignored. `text_area`, `dropdown` and `opengl` are `.partial` in the
documented web `control_support` table.
Accessibility fields (`accessibility_role`, `accessibility_label`,
`accessibility_value`) map to `role`, `aria-label` and `aria-valuenow`.

Platform APIs that are not `Kind` values — menu bar, system tray, `message_box`,
`file_dialog`, `clipboard` — degrade per API; see the degradation table in
[web-backend-usage.md](web-backend-usage.md). They never fail silently.

## VS Code integration (`vscode-vlang`, separate repo)

There is no extension code in this repository. The command, panel, hot-reload
and error-rendering contract is specified in
[web-backend-vscode.md](web-backend-vscode.md); the extension itself is tracked
in the `vscode-vlang` repository.

## Milestones (tracking)

- [x] M0 — this doc + protocol sketch + web `control_support` decision table
- [x] M1 — `ui/web_snapshot.v`: `WebSnapshot`, `web_snapshot()`/`web_snapshot_decode()` and golden wire assertions
- [x] M2 — `ui/web.v`: `run_web_window(opts, build, event)` on a `net`-based HTTP + WebSocket server; `GET /`, `/snapshot`, `/events`; optional `/assets/*`; `refresh()`; CLI flags and stdout port/token line
- [x] M3 — `ui/web_protocol.v` + `ui/web_diff.v`: `type`-discriminated messages, `update`/`replace_children` patch ops, event ingress, `examples/web_counter`
- [x] M4 — `web/renderer/renderer.js`: type-checked, framework-free DOM renderer embedded at compile time; events, resize/dpr, error overlay, reconnect
- [x] M5 — spec in [docs/web-backend-vscode.md](web-backend-vscode.md); extension work tracked separately in `vscode-vlang`
- [x] M6 — prod flag, asset serving, a11y roles/labels, keyboard parity, per-API degradation table and [usage guide](web-backend-usage.md); screenshot tests remain a follow-up (out of scope here)

## Acceptance

- Same `build`/`on_event` source runs with and without `-d ui2_headless`, with no edits.
- Typing/click/scroll in browser updates the V model and re-renders < 100 ms on localhost.
- VS Code preview opens from a `.vml`/component file and live-reloads on save (per the M5 spec; implemented in `vscode-vlang`).
- `control_support` documents the web decision table; unsupported platform APIs degrade explicitly, never silently.
- Follow-up (out of scope here): WASM renderer investigation, screenshot tests.

## Decisions (original open questions, resolved)

1. DOM renderer, not canvas-only: DOM + CSS for elements, placeholder canvas for `opengl`. Chosen for a11y and text selection.
2. Port discovery: free port + random token printed to stdout as `{"port":…,"token":"…"}` for the VS Code extension to read.
3. Auth on localhost WS: random token per run, required as `?token=` on the websocket URL; the page HTML embeds the same token so a normal page load works.
