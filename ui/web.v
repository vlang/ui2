@[has_globals]
module ui2

$if ui2_headless ? {
	import crypto.sha1
	import encoding.base64
	import net
	import os
	import rand
	import sync

	$if windows {
		// V only emits net's WSAStartup when `net` is imported by the main
		// module. A library module (ui2) that opens the listener itself has to
		// initialise Winsock explicitly.
		fn C.WSAStartup(w_version_requested u16, lp_wsa_data voidptr) int

		fn web_init_network() {
			mut data := []u8{len: 512}
			if C.WSAStartup(0x0202, data.data) != 0 {
				panic('ui2 web: WSAStartup failed')
			}
		}
	} $else {
		fn web_init_network() {}
	}

	// WebClientConn is one live browser connection.
	struct WebClientConn {
	mut:
		conn net.TcpConn
	}

	// WebState is the single owner of ui2 state for a headless web app. Every
	// read and write goes through its mutex: HTTP requests and websocket frames
	// are served on different threads.
	struct WebState {
	mut:
		mu             &sync.Mutex = sync.new_mutex()
		title          string
		width          int
		height         int
		dpr            f64 = 1.0
		seq            u64
		root           Element
		text_values    map[string]string
		slider_values  map[string]f64
		scroll_offsets map[string]f64
		checked_values map[string]bool
		clients        []&WebClientConn
		token          string
		assets_dir     string
		prod           bool
	}

	// Allocate the state at startup rather than as a global initializer: a
	// global containing sync.new_mutex() crashes before main on V 0.5.2.
	__global g_web_state &WebState = unsafe { nil }
	// V 0.5.2 mis-codegens `?fn` globals into an incompatible __v_option C
	// type, so use the same unsafe-nil sentinel the native backends use.
	__global g_web_build_fn BuildFn = unsafe { nil }
	__global g_web_event_fn EventFn = unsafe { nil }

	pub struct WebOptions {
	pub:
		title      string = 'ui2'
		width      int    = 800
		height     int    = 600
		port       int // 0 picks a free port
		host       string = '127.0.0.1'
		dpr        f64    = 1.0
		token      string // empty generates a random per-run token
		assets_dir string // optional directory served at /assets/*
		prod       bool
	}

	// ── state accessors used by BuildFn/EventFn (desktop API parity) ────────

	// text returns the current value of a text field, so the same build/event
	// source reads typed input on both desktop and web.
	pub fn text(id string) string {
		mut state := g_web_state
		state.mu.lock()
		defer {
			state.mu.unlock()
		}
		return (state.text_values[id] or { '' }).clone()
	}

	pub fn set_text(id string, value string) {
		mut state := g_web_state
		state.mu.lock()
		state.text_values[id] = value.clone()
		state.mu.unlock()
		refresh()
	}

	pub fn slider_value(id string) f64 {
		mut state := g_web_state
		state.mu.lock()
		defer {
			state.mu.unlock()
		}
		return state.slider_values[id] or { 0 }
	}

	pub fn scroll_offset(id string) f64 {
		mut state := g_web_state
		state.mu.lock()
		defer {
			state.mu.unlock()
		}
		return state.scroll_offsets[id] or { 0 }
	}

	// web_bounds reports the logical framebuffer size that stylesheet media
	// queries evaluate against.
	pub fn web_bounds() Rect {
		mut state := g_web_state
		state.mu.lock()
		defer {
			state.mu.unlock()
		}
		return rect(0, 0, f64(state.width), f64(state.height))
	}

	// ── build, refresh and broadcast ───────────────────────────────────────

	fn web_build_tree() Element {
		if voidptr(g_web_build_fn) != unsafe { nil } {
			return g_web_build_fn()
		}
		return screen(0xffffff, [])
	}

	fn web_snapshot_payload() string {
		mut state := g_web_state
		state.mu.lock()
		defer {
			state.mu.unlock()
		}
		return web_snapshot_message(state.title, state.width, state.height, state.dpr, state.seq,
			state.root)
	}

	fn web_broadcast(payload string) {
		mut state := g_web_state
		state.mu.lock()
		clients := state.clients.clone()
		state.mu.unlock()
		for client in clients {
			web_ws_send(client, payload) or {}
		}
	}

	// refresh rebuilds the tree from BuildFn, advances the sequence and pushes a
	// full snapshot. It is the web counterpart of the desktop refresh() ask.
	pub fn refresh() {
		root := web_build_tree()
		mut state := g_web_state
		state.mu.lock()
		state.seq++
		state.root = root
		state.mu.unlock()
		web_broadcast(web_snapshot_payload())
	}

	fn web_find_element(root Element, id string) ?Element {
		if id.len > 0 && root.id == id {
			return root
		}
		for child in root.children {
			if found := web_find_element(child, id) {
				return found
			}
		}
		return none
	}

	fn web_update_state(event WebEvent) {
		mut state := g_web_state
		state.mu.lock()
		defer {
			state.mu.unlock()
		}
		match event.typ {
			web_event_change {
				if target := web_find_element(state.root, event.id) {
					match target.kind {
						.checkbox {
							state.checked_values[event.id] = event.value == 'true'
						}
						.slider {
							state.slider_values[event.id] = event.value.f64()
						}
						else {
							state.text_values[event.id] = event.value.clone()
						}
					}
				} else {
					state.text_values[event.id] = event.value.clone()
				}
			}
			web_event_scroll {
				state.scroll_offsets[event.id] = event.value.f64()
			}
			web_event_resize {
				if event.x > 0 {
					state.width = int(event.x)
				}
				if event.y > 0 {
					state.height = int(event.y)
				}
				if event.value.len > 0 {
					state.dpr = event.value.f64()
				}
			}
			else {}
		}
	}

	fn web_process_event(event WebEvent) {
		if event.token != g_web_state.token {
			web_broadcast(web_error_message('invalid websocket token'))
			return
		}

		web_update_state(event)
		if voidptr(g_web_event_fn) != unsafe { nil } && event.typ != web_event_resize {
			g_web_event_fn(web_event_string(event))
		}

		// One build after the handler captures the final tree. State reads
		// inside EventFn use the values web_update_state already applied.
		new_root := web_build_tree()
		mut state := g_web_state
		state.mu.lock()
		old_root := state.root
		state.root = new_root
		state.seq++
		seq := state.seq
		state.mu.unlock()

		if event.typ == web_event_resize {
			web_broadcast(web_snapshot_payload())
			return
		}
		web_broadcast(web_patch_message(seq, web_diff_trees(old_root, new_root)))
	}

	fn web_error_message(message string) string {
		return '{"type":"error","message":"${message.replace('"', '\\"')}"}'
	}

	// ── minimal HTTP/1.1 server ─────────────────────────────────────────────
	// veb and net.websocket both crash when started from a library module on
	// V 0.5.2 (verified with a minimal probe). A small net.TcpConn loop for the
	// three read-only routes plus a ~120-line websocket handshake/framing layer
	// keeps the whole backend in one deployable binary with no such dependency.

	fn web_http_response(status string, content_type string, body string) string {
		return 'HTTP/1.1 ${status}\r\nContent-Type: ${content_type}\r\nContent-Length: ${body.len}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n${body}'
	}

	fn web_header(raw string, name string) string {
		prefix := name.to_lower() + ':'
		for line in raw.split('\r\n') {
			if line.to_lower().trim_space().starts_with(prefix) {
				colon := line.index(':') or { return '' }
				return line[colon + 1..].trim_space()
			}
		}
		return ''
	}

	fn web_query_value(query string, name string) string {
		for pair in query.split('&') {
			if pair.len == 0 || !pair.contains('=') {
				continue
			}
			eq := pair.index('=') or { continue }
			if pair[..eq] == name {
				return pair[eq + 1..]
			}
		}
		return ''
	}

	fn web_mime(path string) string {
		return match path.all_after_last('.') {
			'js' { 'application/javascript; charset=utf-8' }
			'css' { 'text/css; charset=utf-8' }
			'json' { 'application/json' }
			'svg' { 'image/svg+xml' }
			'png' { 'image/png' }
			'jpg', 'jpeg' { 'image/jpeg' }
			'gif' { 'image/gif' }
			'ico' { 'image/x-icon' }
			else { 'application/octet-stream' }
		}
	}

	fn web_asset(assets_dir string, requested string) string {
		if assets_dir.len == 0 || !requested.starts_with('/assets/') {
			return ''
		}
		relative := requested['/assets/'.len..]
		if relative.len == 0 || relative.starts_with('/') || relative.contains('..') {
			return ''
		}
		path := os.join_path(assets_dir, relative)
		if !os.exists(path) || os.is_dir(path) {
			return ''
		}
		return os.read_file(path) or { '' }
	}

	// ── websocket frames ────────────────────────────────────────────────────

	fn web_ws_accept(key string) string {
		guid := '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
		return base64.encode(sha1.sum((key + guid).bytes()))
	}

	fn web_ws_send_frame(client &WebClientConn, payload string, opcode u8) ! {
		bytes := payload.bytes()
		n := bytes.len
		mut header := []u8{}
		header << u8(0x80 | opcode)
		if n < 126 {
			header << u8(n)
		} else if n < 65536 {
			header << u8(126)
			header << u8(n >> 8)
			header << u8(n & 0xff)
		} else {
			header << u8(127)
			for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
				header << u8(n >> shift)
			}
		}
		client.conn.write(header) or { return err }
		client.conn.write(bytes) or { return err }
	}

	fn web_ws_send(client &WebClientConn, payload string) ! {
		return web_ws_send_frame(client, payload, 1)
	}

	fn web_read_exact(client &WebClientConn, mut buffer []u8, want int) ! {
		mut got := 0
		for got < want {
			n := client.conn.read(mut buffer[got..want]) or { return err }
			if n <= 0 {
				return error('websocket connection closed')
			}
			got += n
		}
	}

	fn web_ws_serve(client &WebClientConn) {
		for {
			mut two := []u8{len: 2}
			web_read_exact(client, mut two, 2) or { break }
			opcode := two[0] & 0x0f
			masked := (two[1] & 0x80) != 0
			mut length := int(two[1] & 0x7f)
			if length == 126 {
				mut ext := []u8{len: 2}
				web_read_exact(client, mut ext, 2) or { break }
				length = (int(ext[0]) << 8) | int(ext[1])
			} else if length == 127 {
				mut ext := []u8{len: 8}
				web_read_exact(client, mut ext, 8) or { break }
				length = 0
				for b in ext {
					length = (length << 8) | int(b)
				}
			}
			mut mask := []u8{len: 4}
			if masked {
				web_read_exact(client, mut mask, 4) or { break }
			}
			if length > 1024 * 1024 {
				break
			}
			mut payload := []u8{len: length}
			if length > 0 {
				web_read_exact(client, mut payload, length) or { break }
			}
			if masked {
				for i, b in payload {
					payload[i] = b ^ mask[i % 4]
				}
			}
			if opcode == 8 {
				break
			}
			if opcode == 9 {
				web_ws_send_frame(client, payload.bytestr(), 10) or { break }
				continue
			}
			if opcode == 1 {
				event := web_event_decode(payload.bytestr()) or { continue }
				web_process_event(event)
			}
		}
		mut state := g_web_state
		state.mu.lock()
		for i, other in state.clients {
			if other == client {
				state.clients.delete(i)
				break
			}
		}
		state.mu.unlock()
	}

	fn web_serve_connection(mut conn net.TcpConn) {
		mut buffer := []u8{len: 16384}
		mut received := 0
		mut request := ''
		for _ in 0 .. 8 {
			n := conn.read(mut buffer) or { break }
			if n <= 0 {
				break
			}
			request += buffer[..n].bytestr()
			received += n
			if request.contains('\r\n\r\n') || received >= buffer.len {
				break
			}
		}
		if request.len == 0 {
			conn.close() or {}
			return
		}
		end := request.index('\r\n\r\n') or { request.len }
		head := request[..end]
		lines := head.split('\r\n')
		words := lines[0].split(' ')
		if words.len < 2 {
			conn.close() or {}
			return
		}
		target := words[1]
		question := target.index('?') or { -1 }
		path := if question >= 0 { target[..question] } else { target }
		query := if question >= 0 { target[question + 1..] } else { '' }

		if web_header(head, 'Upgrade').to_lower().contains('websocket') {
			key := web_header(head, 'Sec-WebSocket-Key')
			if key.len == 0 || web_query_value(query, 'token') != g_web_state.token {
				conn.write_string(web_http_response('403 Forbidden', 'text/plain', 'forbidden')) or {}
				conn.close() or {}
				return
			}
			accept := web_ws_accept(key)
			response := 'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n'
			conn.write_string(response) or {
				conn.close() or {}
				return
			}
			client := &WebClientConn{ conn: conn }
			mut state := g_web_state
			state.mu.lock()
			state.clients << client
			state.mu.unlock()
			web_ws_serve(client)
			return
		}

		mut body := ''
		mut content_type := 'text/plain; charset=utf-8'
		mut status := '200 OK'
		match path {
			'/' {
				mut state := g_web_state
				state.mu.lock()
				body = web_html_page(WebPageConfig{
					title:        state.title
					token:        state.token
					width:        state.width
					height:       state.height
					dpr:          state.dpr
					ws_path:      '/events'
					snapshot_url: '/snapshot'
				})
				state.mu.unlock()
				content_type = 'text/html; charset=utf-8'
			}
			'/snapshot' {
				body = web_snapshot_payload()
				content_type = 'application/json'
			}
			else {
				if path.starts_with('/assets/') && g_web_state.assets_dir.len > 0 {
					asset := web_asset(g_web_state.assets_dir, path)
					if asset.len > 0 {
						body = asset
						content_type = web_mime(path)
					} else {
						status = '404 Not Found'
						body = 'asset not found'
					}
				} else {
					status = '404 Not Found'
					body = 'not found'
				}
			}
		}
		conn.write_string(web_http_response(status, content_type, body)) or {}
		conn.close() or {}
	}

	fn web_http_loop(host string, port int) {
		mut listener := net.listen_tcp(.ip, '${host}:${port}') or { panic(err) }
		for {
			mut conn := listener.accept() or { continue }
			spawn web_serve_connection(mut conn)
		}
	}

	// ── startup ────────────────────────────────────────────────────────────

	fn web_cli_port(fallback int) int {
		for i, arg in os.args {
			if arg == '--ui2-web-port' && i + 1 < os.args.len {
				return os.args[i + 1].int()
			}
			if arg.starts_with('--ui2-web-port=') {
				return arg[15..].int()
			}
		}
		return fallback
	}

	fn web_cli_value(name string) string {
		for i, arg in os.args {
			if arg == name && i + 1 < os.args.len {
				return os.args[i + 1]
			}
			if arg.starts_with(name + '=') {
				return arg[name.len + 1..]
			}
		}
		return ''
	}

	fn web_free_port() !int {
		mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
		defer {
			listener.close() or {}
		}
		return listener.addr()!.port()!
	}

	// run_web_window serves one ui2 app in the browser with no app-code changes.
	// BuildFn and EventFn are the exact callbacks a desktop window receives.
	pub fn run_web_window(opts WebOptions, build_fn BuildFn, event_fn EventFn) {
		web_init_network()
		g_web_state = &WebState{}
		g_web_build_fn = build_fn
		g_web_event_fn = event_fn

		port := web_cli_port(opts.port)
		chosen_port := if port > 0 { port } else { web_free_port() or { 8080 } }
		mut host := web_cli_value('--ui2-web-host')
		if host.len == 0 {
			host = opts.host
		}
		mut token := web_cli_value('--ui2-web-token')
		if token.len == 0 {
			token = if opts.token.len > 0 { opts.token } else { rand.uuid_v4() }
		}

		root := web_build_tree()
		mut state := g_web_state
		state.mu.lock()
		state.title = opts.title
		state.width = opts.width
		state.height = opts.height
		state.dpr = if opts.dpr > 0 { opts.dpr } else { 1.0 }
		state.root = root
		state.seq = 0
		state.token = token
		state.assets_dir = opts.assets_dir
		state.prod = opts.prod
		state.mu.unlock()

		// The VS Code extension reads this line to discover the port and token.
		println('{"port":${chosen_port},"token":"${token}"}')
		flush_stdout()
		web_http_loop(host, chosen_port)
	}
}
