# Web backend (Flutter-style) — tracking issue

Goal: run any ui2 app in a browser with no app-code changes, the way
Flutter runs the same widgets on mobile/desktop/web.

```v
import ui2

fn build() ui2.Element { /* same tree as desktop */ return ui2.screen(...) }
fn on_event(e string) { /* same handler as desktop */ }

ui2.run_window('App', 800, 600, build, on_event) // desktop
ui2.run_web_window(opts, build, on_event)        // browser (new)
```

First consumer: component preview in the VS Code extension
(`vscode-vlang` webview panel). Built for real use from day one, not a
preview-only hack: `v run app.v --web` must be a deployable web app.

## Why this shape (not WASM-first)

- `Element` (`ui/ui.v`) is already plain data: `Kind`, `Rect`, `BoxStyle`,
  `TextStyle`, `children`, etc. It JSON-encodes with no FFI.
- `-d ui2_headless` already strips `gg`/Sokol from the build, so a V
  server can own state + `BuildFn`/`EventFn` with no window.
- V stdlib has `veb` + `net.websocket`: a headless V app can serve a
  snapshot over HTTP and stream patches/events over a socket.
- Browser side is a small TS DOM renderer. No Emscripten/Sokol-WebGL
  dependency, accessible HTML for free, works inside a VS Code webview.
- WASM (compile the V app to the browser) stays an option later; the
  JSON protocol below is the contract either side would speak.

## Architecture

```text
V app (headless)            browser / vscode webview
─────────────────           ────────────────────────
build() -> Element
   │  validate_element_tree
   ▼
to_json(snapshot) --HTTP GET /snapshot--> render DOM
   │                                         │ user input
refresh()/event loop <--WS event json -------┘
   ▼
patch/diff --WS patch json--> apply to DOM
```

- V owns all state. Browser never invents ids; it echoes `action_id`/pointer/
  text/key/scroll events as the existing `EventFn(string)` strings.
- v1 sends full snapshots on every `refresh()`; diffing is an optimization
  (M3), not a correctness requirement.
- Text measurement: server uses `measure_layout_element` CPU fallback
  (`ui/layout_measure.v`, no window needed); client measures with canvas and
  reports `devicePixelRatio`/viewport so server can re-layout.

## Protocol v0 (to stabilize in M1)

- `GET /snapshot -> { title, width, height, dpr, root: ElementDTO }`
- `WS /events  client -> server: { type: 'tap'|'change'|'pointer'|'scroll'|'key'|'resize', id, value, x, y, ... }`
  reusing the exact strings `EventFn` already receives
  (`pointer:down:<action>:<x>:<y>`, `text:editor:*`, `cmd+n`, …).
- `WS server -> client: { type: 'snapshot'|'patch', root | ops, seq }`
- `ElementDTO` = 1:1 JSON of `Element` minus function fields (all fields in
  `ui.v` `pub struct Element` are data). Enums (`Kind`, `Align`, `ScrollMode`)
  encode as strings.

## Element -> DOM mapping (v1)

| Kind | DOM |
|---|---|
| screen/view | `<div>` absolute-positioned from `frame`; `BoxStyle` -> CSS (bg, radius, per-edge border, opacity, gradient, shadow) |
| label | `<div>` + `TextStyle` (color, size, bold/italic/underline, align/valign) |
| button (+`button_behavior`, `native_style` ignored on web) | `<button>` |
| text_field/submit/change | `<input>` (controlled-on-change semantics preserved) |
| text_area/rich runs | `<textarea>` plain first; runs rendered read-only later |
| checkbox/switch/slider/toggle | `<input type=checkbox>` / switch `<button role=switch>` / `<input type=range>` |
| dropdown | `<select>` (native listbox; custom popup parity later) |
| scroll | overflow `<div>`, report `scroll_offset` events |
| image | `<img src=/assets/...>`; BMP-only limits of Win32 backend do not apply |
| shape/path/chart | `<svg>` (`path_*` verbs map directly; chart composes views+labels already) |
| opengl | placeholder `<canvas>` + message (no GL texture on web v1) |
| menu/tray/message_box/file_dialog/clipboard | degraded: in-page menu bar, toast/dialog, `<input type=file>`, async clipboard; document per-API table |

Events map back to `on_event`, `on_key`, `on_scroll`, `on_drop` strings the
app already handles. Hover/clickable/draggable/long_press reuse the
`pointer:*` string format from `ui_immediate.c.v`.

## VS Code integration (`vscode-vlang`, separate repo)

- Command `V: Preview ui2 component` on `*.v` / `*.vml` files.
- Extension spawns `v -d ui2_headless run <preview_main>.v -- --ui2-web-port <free>` (stdout prints port), opens `WebviewPanel` pointing at it.
- Watch mode: save -> rebuild/restart server (or `refresh()` if we add a file-watcher hook later); errors render in-panel, not just the terminal.
- Multi-preview: one server per preview file, port per panel.

## Milestones (tracking)

- [x] M0 — this doc + protocol sketch + `control_support(.web)` decision table
- [x] M1 — `ui/web_snapshot.v` (+`web_snapshot_test.v`): `Element -> JSON` round-trip for every `Kind`, golden wire assertions
- [ ] M2 — `ui/web.v`: `run_web_window(opts, build, event)` on `veb` + websocket; `GET /`, `/snapshot`, `/assets/*`; `refresh()` pushes snapshot; manual browser test
- [ ] M3 — diff/patch (`seq`, keyed `key`/`id` reconciliation reuse), scroll/key/pointer/text event ingress, `examples/web_counter`
- [ ] M4 — `web/renderer/` TS DOM renderer (no framework): snapshot render, patch apply, event send, resize/dpr, error overlay
- [ ] M5 — VS Code preview spec implemented against `vscode-vlang` (command, panel, task, hot-reload)
- [ ] M6 — real-use hardening: prod flag, asset serving, a11y roles/labels, keyboard parity, dialog/menu/clipboard degradation table, screenshot tests, `docs/web-backend-usage.md`

## Acceptance

- Same `build`/`on_event` source runs on desktop and `--web` with no edits.
- Typing/click/scroll in browser updates V model and re-renders < 100 ms on localhost.
- VS Code preview opens from a `.vml`/component file and live-reloads on save.
- `control_support` documents `.web`; unsupported plat APIs degrade explicitly, never silently.
- Follow-up (out of scope here): WASM renderer investigation.

## Open questions

1. DOM+SVG v1 vs canvas-only Flutter-faithful renderer? Proposal: DOM+SVG (a11y + preview text selection win).
2. Port discovery: stdout JSON `{"port":…}` vs fixed port + token? Proposal: free port + token printed to stdout for the extension to read.
3. Auth on localhost WS when used outside VS Code? Proposal: random token per run, required as query param.
