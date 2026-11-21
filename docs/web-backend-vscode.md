# VS Code ui2 preview — M5 specification

**Status: specification only.** There is no extension code in this repository.
The implementation belongs to the separate `vscode-vlang` repository. This
document is the contract the extension should implement against the web backend
shipped here (`ui/web*.v`, `web/renderer/renderer.js`).

## Goal

From a `.v` or `.vml` ui2 component, run one command that opens a live,
interactive preview in a VS Code `WebviewPanel`. The app source must not be
modified: the preview harness supplies the same `BuildFn`/`EventFn` the app
uses on desktop.

## Command

- **ID / title:** `V: Preview ui2 component`
- **Activation:** available when the active editor is `*.v` or `*.vml`.
- **Action:** create (or focus) one `WebviewPanel` per previewed file and start
  a dedicated server process for it.

## Preview main

The extension generates a small temporary `preview_main.v` that imports `ui2`
and the component under preview, then calls:

```v
$if ui2_headless ? {
	ui2.run_web_window(opts, build, on_event)
} $else {
	ui2.run_window('preview', width, height, build, on_event)
}
```

It must declare `@[has_globals]` at module level (the callbacks are plain
functions) and must be run with the `-d ui2_headless` flag so the web server is
compiled in. The generated file is an implementation detail of the extension,
not part of this repository.

## Process lifecycle

Spawn:

```text
v -d ui2_headless run <preview_main>.v -- \
  --ui2-web-port <free-port> --ui2-web-token <random-token>
```

- Pick a free TCP port up front and pass it with `--ui2-web-port`; the server
  also picks one itself (and prints it) when port `0` is used, but an explicit
  port avoids races.
- Generate a fresh random token per process and pass it with
  `--ui2-web-token`. The websocket endpoint requires it as a `?token=` query
  parameter; the page itself embeds it.
- Host defaults to `127.0.0.1` and can be pinned with `--ui2-web-host`.
- Capture stdout and stderr. On save or on panel close, terminate the process
  tree (the `v run` wrapper and its compiled child), and release the port.

## Discovery handshake

The server prints exactly one JSON line to stdout once it is ready:

```json
{"port":53791,"token":"8f14e45f-ea67-4bd2-a1c0-..."}
```

The extension reads that line, parses `port` and `token`, and only then reveals
the webview. If the line never arrives (build error, timeout) the panel shows
the captured stderr instead of an empty frame.

## WebviewPanel

- One panel per previewed file; panel title includes the file name.
- Navigate the webview to:

  ```text
  http://127.0.0.1:<port>/?token=<token>
  ```

  Current behavior to be aware of: the page loads without the token query
  because the server embeds the token in the `#ui2-config` JSON script and the
  renderer appends `?token=` to the websocket URL itself. Including `?token=`
  on the page URL is harmless and keeps the preview URL self-describing; the
  `/events` WS endpoint always requires a matching token.
- Allow the loopback origin in the webview's `localResourceRoots`/CSP, and
  allow `ws:`/`wss:` connections to `127.0.0.1:<port>`. The renderer needs no
  external scripts, fonts or network assets (it is embedded in the served
  HTML); a static asset folder, if the app uses one, is served from
  `/assets/*`.
- Keep the panel open across saves by reusing it and navigating to the same
  URL after each restart.

## Hot reload on save

- Watch saves of the previewed file and its local imports.
- On save: terminate the current preview process, regenerate/rebuild the
  preview main, spawn a new server (same or new free port/token), then reload
  the webview from the new stdout JSON.
- Debounce bursts of saves; show a transient "rebuilding…" state in the panel.
- If the rebuild fails, keep the last working frame visible and report the
  compiler output in the panel's error area.

## Multi-preview

- Maintain a map of `document URI -> { panel, process, port, token }`.
- Each panel owns exactly one server process on its own port with its own
  token; previews never share state or sockets.
- Focus an existing panel instead of spawning a duplicate when the command is
  invoked again for the same file.
- Disposing a panel disposes only its own process and map entry.

## Error rendering in-panel

Errors must be visible inside the preview, not only in the output channel:

- **Build/startup failure:** render captured compiler/stderr text in the
  webview (plain `<pre>`-style area), with a "show output channel" link.
- **Server-side runtime error:** the server broadcasts
  `{ type: 'error', message }`; the shipped renderer already shows this in its
  red in-page overlay, so the extension gets this for free.
- **Snapshot / websocket failure:** the renderer's own overlay reports it; the
  extension should also surface a compact status in the panel title (e.g.
  "disconnected — retrying").

## Out of scope for M5

- Implementing the extension in this repository.
- WASM preview mode.
- Screenshot/golden-image tests (follow-up).
- Any change to the wire protocol; this spec consumes the protocol documented
  in [web-backend.md](web-backend.md) as implemented.
