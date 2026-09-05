module ui2

import gg
import time

struct HitTarget {
	id          string
	action_id   string
	submit_id   string
	x           f64
	y           f64
	w           f64
	h           f64
	long_press  bool
	swipe_left  bool
	text_field  bool
	text_area   bool
	dropdown    bool
	options     []string
	emit_change bool
}

struct TouchState {
mut:
	down               bool
	start_x            f64
	start_y            f64
	current_x          f64
	current_y          f64
	start_time         i64
	moved              bool
	scroll_id          string
	scroll_start_off_y f64
	long_press_fired   bool
}

struct GgApp {
mut:
	ctx &gg.Context = unsafe { nil }
}

__global g_build_screen = BuildFn(unsafe { nil })
__global g_event_handler = EventFn(unsafe { nil })
__global g_gg_app = &GgApp{}
__global g_text_values = map[string]string{}
__global g_text_props = map[string]string{}
__global g_text_editors = map[string]TextEditor{}
__global g_text_kinds = map[string]Kind{}
__global g_focused_field = ''
__global g_scroll_offsets = map[string]f64{}
__global g_scroll_content_h = map[string]f64{}
__global g_hit_targets = []HitTarget{}
__global g_touch = TouchState{}
__global g_scroll_areas = map[string]Rect{}
__global g_active_fields = map[string]bool{}
__global g_active_scrolls = map[string]bool{}
__global g_image_ids = map[string]int{}
__global g_active_images = map[string]bool{}

// ── Public API ─────────────────────────────────────────────────────

pub fn bounds() Rect {
	if g_gg_app.ctx == unsafe { nil } {
		return Rect{
			width: 400
			height: 800
		}
	}
	return Rect{
		width: f64(g_gg_app.ctx.width)
		height: f64(g_gg_app.ctx.height)
	}
}

pub fn run(build_fn BuildFn, event_fn EventFn) {
	g_build_screen = build_fn
	g_event_handler = event_fn
	g_gg_app.ctx = gg.new_context(
		bg_color: hex_color(0xf4f6f8)
		width: 400
		height: 800
		create_window: true
		window_title: 'App'
		user_data: unsafe { voidptr(g_gg_app) }
		frame_fn: on_frame
		event_fn: on_event
	)
	g_gg_app.ctx.run()
}

pub fn refresh() {
}

pub fn text(id string) string {
	return g_text_values[id] or { '' }
}

pub fn set_text(id string, t string) {
	if id !in g_active_fields {
		return
	}
	g_text_values[id] = t
	mut editor := g_text_editors[id] or { text_editor(t) }
	editor.set_text(t)
	g_text_editors[id] = editor
}

pub fn focus(id string) {
	mut focusable := false
	for target in g_hit_targets {
		if target.id == id && (target.text_field || target.text_area) {
			focusable = true
			break
		}
	}
	if !focusable {
		return
	}
	g_focused_field = id
	mut editor := g_text_editors[id] or { text_editor(g_text_values[id] or { '' }) }
	editor.set_caret(rune_len(editor.text))
	g_text_editors[id] = editor
}

pub fn focused_text_area_id() string {
	for target in g_hit_targets {
		if target.id == g_focused_field && target.text_area {
			return g_focused_field
		}
	}
	return ''
}

pub fn dismiss_keyboard() {
	g_focused_field = ''
}

pub fn safe_area_top() f64 {
	return 0
}

pub fn start_barcode_scan() {
	if voidptr(g_event_handler) != unsafe { nil } {
		g_event_handler('scan_error:barcode scanner unavailable')
	}
}

// ── Frame & event loop ─────────────────────────────────────────────

fn on_frame(app &GgApp) {
	if app.ctx == unsafe { nil } {
		return
	}
	ctx := app.ctx
	ctx.begin()
	if voidptr(g_build_screen) != unsafe { nil } {
		g_hit_targets = []HitTarget{}
		g_scroll_areas = map[string]Rect{}
		g_active_fields = map[string]bool{}
		g_active_scrolls = map[string]bool{}
		g_active_images = map[string]bool{}
		root := g_build_screen()
		validate_element_tree(root) or {
			eprintln('ui2: ${err}')
			ctx.end()
			return
		}
		render_element(ctx, root, 0, 0, rect(0, 0, f64(ctx.width), f64(ctx.height)))
		prune_unmounted_state()
	}
	check_long_press()
	ctx.end()
}

fn on_event(e &gg.Event, _ &GgApp) {
	match e.typ {
		.mouse_down {
			handle_touch_down(f64(e.mouse_x), f64(e.mouse_y))
		}
		.mouse_move {
			if g_touch.down {
				handle_touch_move(f64(e.mouse_x), f64(e.mouse_y))
			}
		}
		.mouse_up {
			handle_touch_up(f64(e.mouse_x), f64(e.mouse_y))
		}
		.touches_began {
			if e.num_touches > 0 {
				handle_touch_down(f64(e.touches[0].pos_x), f64(e.touches[0].pos_y))
			}
		}
		.touches_moved {
			if e.num_touches > 0 {
				handle_touch_move(f64(e.touches[0].pos_x), f64(e.touches[0].pos_y))
			}
		}
		.touches_ended {
			if e.num_touches > 0 {
				handle_touch_up(f64(e.touches[0].pos_x), f64(e.touches[0].pos_y))
			} else {
				handle_touch_up(g_touch.current_x, g_touch.current_y)
			}
		}
		.char {
			handle_char_input(e.char_code)
		}
		.key_down {
			handle_key_down(e.key_code)
		}
		else {}
	}
}

// ── Touch handling ─────────────────────────────────────────────────

fn handle_touch_down(x f64, y f64) {
	g_touch = TouchState{
		down: true
		start_x: x
		start_y: y
		current_x: x
		current_y: y
		start_time: time.ticks()
		moved: false
		long_press_fired: false
	}
	for id, area in g_scroll_areas {
		if x >= area.x && x <= area.x + area.width && y >= area.y && y <= area.y + area.height {
			g_touch.scroll_id = id
			g_touch.scroll_start_off_y = g_scroll_offsets[id] or { 0.0 }
			break
		}
	}
}

fn handle_touch_move(x f64, y f64) {
	if !g_touch.down {
		return
	}
	dx := x - g_touch.start_x
	dy := y - g_touch.start_y
	if dx * dx + dy * dy > 100 {
		g_touch.moved = true
	}
	g_touch.current_x = x
	g_touch.current_y = y
	if g_touch.scroll_id.len > 0 {
		delta := g_touch.start_y - y
		new_offset := g_touch.scroll_start_off_y + delta
		content_h := g_scroll_content_h[g_touch.scroll_id] or { 0.0 }
		scroll_area := g_scroll_areas[g_touch.scroll_id] or { Rect{} }
		max_scroll := content_h - scroll_area.height + 16
		if max_scroll < 0 {
			g_scroll_offsets[g_touch.scroll_id] = 0
		} else if new_offset < 0 {
			g_scroll_offsets[g_touch.scroll_id] = 0
		} else if new_offset > max_scroll {
			g_scroll_offsets[g_touch.scroll_id] = max_scroll
		} else {
			g_scroll_offsets[g_touch.scroll_id] = new_offset
		}
	}
}

fn handle_touch_up(x f64, y f64) {
	if !g_touch.down {
		return
	}
	g_touch.down = false
	if g_touch.long_press_fired {
		return
	}
	dx := x - g_touch.start_x
	if g_touch.moved && dx < -72 {
		target := hit_test(g_touch.start_x, g_touch.start_y)
		if target.action_id.len > 0 && target.swipe_left {
			fire_event('swipe_left:' + target.action_id)
			return
		}
	}
	if g_touch.moved {
		return
	}
	target := hit_test(x, y)
	if target.id.len == 0 && target.action_id.len == 0 {
		if g_focused_field.len > 0 {
			g_focused_field = ''
		}
		return
	}
	if target.text_field {
		g_focused_field = target.id
		mut editor := g_text_editors[target.id] or { text_editor(g_text_values[target.id] or { '' }) }
		editor.set_caret(rune_len(editor.text))
		g_text_editors[target.id] = editor
		return
	}
	if target.text_area {
		g_focused_field = target.id
		mut editor := g_text_editors[target.id] or { text_editor(g_text_values[target.id] or { '' }) }
		editor.set_caret(rune_len(editor.text))
		g_text_editors[target.id] = editor
		return
	}
	if target.dropdown {
		cycle_dropdown(target)
		return
	}
	fire_event(target.action_id)
}

fn check_long_press() {
	if !g_touch.down || g_touch.moved || g_touch.long_press_fired {
		return
	}
	elapsed := time.ticks() - g_touch.start_time
	if elapsed < 450 {
		return
	}
	target := hit_test(g_touch.start_x, g_touch.start_y)
	if target.action_id.len > 0 && target.long_press {
		g_touch.long_press_fired = true
		fire_event('long:' + target.action_id)
	}
}

fn hit_test(x f64, y f64) HitTarget {
	for i := g_hit_targets.len - 1; i >= 0; i-- {
		t := g_hit_targets[i]
		if x >= t.x && x <= t.x + t.w && y >= t.y && y <= t.y + t.h {
			return t
		}
	}
	return HitTarget{}
}

fn fire_event(id string) {
	if id.len > 0 && voidptr(g_event_handler) != unsafe { nil } {
		g_event_handler(id)
	}
}

// ── Keyboard input ─────────────────────────────────────────────────

fn handle_char_input(ch u32) {
	if g_focused_field.len == 0 {
		return
	}
	if ch < 32 {
		return
	}
	mut editor := g_text_editors[g_focused_field] or {
		text_editor(g_text_values[g_focused_field] or { '' })
	}
	editor.insert_text(rune(ch).str())
	g_text_editors[g_focused_field] = editor
	g_text_values[g_focused_field] = editor.text
	fire_field_change(g_focused_field)
}

fn handle_key_down(key gg.KeyCode) {
	if g_focused_field.len == 0 {
		return
	}
	mut editor := g_text_editors[g_focused_field] or {
		text_editor(g_text_values[g_focused_field] or { '' })
	}
	if key == .backspace {
		if editor.backspace() {
			g_text_editors[g_focused_field] = editor
			g_text_values[g_focused_field] = editor.text
			fire_field_change(g_focused_field)
		}
	}
	if key == .delete {
		if editor.delete_forward() {
			g_text_editors[g_focused_field] = editor
			g_text_values[g_focused_field] = editor.text
			fire_field_change(g_focused_field)
		}
	}
	if key == .left || key == .right || key == .home || key == .end {
		if key == .left {
			editor.move_caret(-1, false)
		} else if key == .right {
			editor.move_caret(1, false)
		} else if key == .home {
			editor.set_caret(0)
		} else {
			editor.set_caret(rune_len(editor.text))
		}
		g_text_editors[g_focused_field] = editor
	}
	if key == .enter || key == .kp_enter {
		for target in g_hit_targets {
			if target.id == g_focused_field && target.text_area {
				editor.insert_text('\n')
				g_text_editors[g_focused_field] = editor
				g_text_values[g_focused_field] = editor.text
				fire_field_change(g_focused_field)
				return
			}
		}
		id := g_focused_field
		g_focused_field = ''
		for target in g_hit_targets {
			if target.id == id && target.text_field && target.submit_id.len > 0 {
				fire_event(target.submit_id)
				break
			}
		}
	}
}

fn fire_field_change(id string) {
	for target in g_hit_targets {
		if target.id == id && (target.text_field || target.text_area) && target.emit_change {
			fire_event(target.action_id)
			return
		}
	}
}

fn cycle_dropdown(target HitTarget) {
	if target.options.len == 0 {
		fire_event(target.action_id)
		return
	}
	current := g_text_values[target.id] or { '' }
	mut next := 0
	for index, option in target.options {
		if option == current {
			next = (index + 1) % target.options.len
			break
		}
	}
	g_text_values[target.id] = target.options[next]
	fire_event(target.action_id)
}

fn prune_unmounted_state() {
	mut stale_fields := []string{}
	for id, _ in g_text_values {
		if id !in g_active_fields {
			stale_fields << id
		}
	}
	for id in stale_fields {
		g_text_values.delete(id)
		g_text_props.delete(id)
		g_text_editors.delete(id)
		g_text_kinds.delete(id)
		forget_portable_text_area_selection(id)
		if g_focused_field == id {
			g_focused_field = ''
		}
	}
	mut stale_scrolls := []string{}
	for id, _ in g_scroll_offsets {
		if id !in g_active_scrolls {
			stale_scrolls << id
		}
	}
	for id in stale_scrolls {
		g_scroll_offsets.delete(id)
		g_scroll_content_h.delete(id)
	}
	mut stale_images := []string{}
	for path, _ in g_image_ids {
		if path !in g_active_images {
			stale_images << path
		}
	}
	mut image_ctx := g_gg_app.ctx
	for path in stale_images {
		image_id := g_image_ids[path] or { continue }
		image_ctx.remove_cached_image_by_idx(image_id)
		g_image_ids.delete(path)
	}
}

// ── Rendering ──────────────────────────────────────────────────────

fn render_element(ctx &gg.Context, el Element, off_x f64, off_y f64, clip Rect) {
	if el.hidden {
		return
	}
	apply_clip(ctx, clip)
	match el.kind {
		.screen {
			w := f64(ctx.width)
			h := f64(ctx.height)
			if !el.box.transparent {
				draw_rect(ctx, 0, 0, w, h, el.box.bg, 0)
			}
			for child in el.children {
				render_element(ctx, child, 0, 0, clip)
			}
		}
		.view {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			if !el.box.transparent {
				draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
			}
			if el.enabled && element_action_id(el).len > 0
				&& (el.clickable || el.draggable || el.long_press || el.swipe_left) {
				add_hit_target(HitTarget{
					id: el.id
					action_id: element_action_id(el)
					x: x
					y: y
					w: el.frame.width
					h: el.frame.height
					long_press: el.long_press
					swipe_left: el.swipe_left
				}, clip)
			}
			for child in el.children {
				render_element(ctx, child, x, y, clip)
			}
		}
		.scroll {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, 0)
			scroll_y := g_scroll_offsets[el.id] or { 0.0 }
			if el.id.len > 0 {
				area := intersect_rect(Rect{
					x: x
					y: y
					width: el.frame.width
					height: el.frame.height
				}, clip)
				if area.width > 0 && area.height > 0 {
					g_scroll_areas[el.id] = area
					g_active_scrolls[el.id] = true
				}
			}
			child_clip := intersect_rect(Rect{
				x: x
				y: y
				width: el.frame.width
				height: el.frame.height
			}, clip)
			mut content_h := f64(0)
			for child in el.children {
				child_screen_y := child.frame.y - scroll_y
				bottom := child.frame.y + child.frame.height
				if bottom > content_h {
					content_h = bottom
				}
				if child_screen_y + child.frame.height < 0 || child_screen_y > el.frame.height {
					continue
				}
				render_element(ctx, child, x, y - scroll_y, child_clip)
			}
			if el.id.len > 0 {
				g_scroll_content_h[el.id] = content_h
			}
			apply_clip(ctx, clip)
		}
		.label {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_text(ctx, el.text, x, y, el.frame.width, el.frame.height, el.text_style)
		}
		.image {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			if !draw_cached_image(ctx, el.image_path, x, y, el.frame.width, el.frame.height, el.rotation) {
				draw_rect(ctx, x, y, el.frame.width, el.frame.height, 0xe8ecef, 0)
			}
			if el.enabled && element_action_id(el).len > 0 && (el.clickable || el.draggable) {
				add_hit_target(HitTarget{
					id: el.id
					action_id: element_action_id(el)
					x: x
					y: y
					w: el.frame.width
					h: el.frame.height
				}, clip)
			}
		}
		.button {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
			draw_text_centered(ctx, el.text, x, y, el.frame.width, el.frame.height, el.text_style)
			if el.enabled {
				add_hit_target(HitTarget{
					id: el.id
					action_id: element_action_id(el)
					x: x
					y: y
					w: el.frame.width
					h: el.frame.height
					long_press: el.long_press
				}, clip)
			}
		}
		.checkbox {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			box_size := if el.frame.height < 20 { el.frame.height } else { 20.0 }
			box_y := y + (el.frame.height - box_size) / 2
			draw_rect(ctx, x, box_y, box_size, box_size, 0x59636e, 4)
			draw_rect(ctx, x + 2, box_y + 2, box_size - 4, box_size - 4, 0xffffff, 2)
			if el.checked {
				draw_text_centered(ctx, '✓', x, box_y - 1, box_size, box_size, TextStyle{
					color: 0x1769aa
					size: 16
					bold: true
					align: .center
				})
			}
			draw_text(ctx, el.text, x + box_size + 8, y, el.frame.width - box_size - 8, el.frame.height, el.text_style)
			if el.enabled {
				add_hit_target(HitTarget{
					id: el.id
					action_id: element_action_id(el)
					x: x
					y: y
					w: el.frame.width
					h: el.frame.height
				}, clip)
			}
		}
		.dropdown {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			previous_prop := g_text_props[el.id] or { el.text }
			kind_changed := el.id in g_text_kinds && (g_text_kinds[el.id] or { el.kind }) != el.kind
			if kind_changed || el.id !in g_text_values || (el.text != previous_prop && (g_text_values[el.id] or { '' }) != el.text) {
				g_text_values[el.id] = el.text
			}
			g_text_props[el.id] = el.text
			g_text_kinds[el.id] = el.kind
			g_active_fields[el.id] = true
			selected := g_text_values[el.id] or { el.text }
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
			draw_text_centered(ctx, selected, x, y, el.frame.width, el.frame.height, el.text_style)
			if el.enabled {
				mut options := []string{cap: el.menu.len}
				for entry in el.menu {
					options << entry.title
				}
				add_hit_target(HitTarget{
					id: el.id
					action_id: element_action_id(el)
					x: x
					y: y
					w: el.frame.width
					h: el.frame.height
					dropdown: true
					options: options
				}, clip)
			}
		}
		.text_field {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			padding_left := if el.padding_left > 0 { el.padding_left } else { f64(0) }
			content_width := if el.frame.width > padding_left + 8 {
				el.frame.width - padding_left - 8
			} else {
				f64(0)
			}
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
			previous_prop := g_text_props[el.id] or { el.text }
			kind_changed := el.id in g_text_kinds && (g_text_kinds[el.id] or { el.kind }) != el.kind
			if kind_changed || el.id !in g_text_values || (el.text != previous_prop && (g_text_values[el.id] or { '' }) != el.text) {
				g_text_values[el.id] = el.text
				g_text_editors[el.id] = text_editor(el.text)
			}
			g_text_props[el.id] = el.text
			g_text_kinds[el.id] = el.kind
			g_active_fields[el.id] = true
			current_text := g_text_values[el.id] or { el.text }
			mut editor := g_text_editors[el.id] or { text_editor(current_text) }
			if editor.text != current_text {
				editor.set_text(current_text)
				g_text_editors[el.id] = editor
			}
			display_text := text_field_display_text(current_text, el.secure)
			is_focused := g_focused_field == el.id
			if current_text.len > 0 {
				draw_text(ctx, display_text, x + padding_left, y, content_width, el.frame.height, el.text_style)
			} else if el.placeholder.len > 0 {
				placeholder_style := TextStyle{
					...el.text_style
					color: 0x999999
				}
				draw_text(ctx, el.placeholder, x + padding_left, y, content_width, el.frame.height, placeholder_style)
			}
			if is_focused {
				before := editor.text.runes()[..editor.selection.caret].string()
				caret_text := text_field_display_text(before, el.secure)
				text_w := f64(ctx.text_width(caret_text))
				cursor_x := x + padding_left + text_w
				cursor_y := y + el.frame.height * 0.2
				cursor_h := el.frame.height * 0.6
				draw_rect(ctx, cursor_x, cursor_y, 2, cursor_h, el.text_style.color, 0)
			}
			if el.enabled {
				add_hit_target(HitTarget{
					id: el.id
					action_id: element_action_id(el)
					submit_id: el.submit_id
					x: x
					y: y
					w: el.frame.width
					h: el.frame.height
					text_field: true
					emit_change: el.emit_change
				}, clip)
			}
		}
		.text_area {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
			previous_prop := g_text_props[el.id] or { el.text }
			kind_changed := el.id in g_text_kinds && (g_text_kinds[el.id] or { el.kind }) != el.kind
			if kind_changed || el.id !in g_text_values || (el.text != previous_prop && (g_text_values[el.id] or { '' }) != el.text) {
				g_text_values[el.id] = el.text
				g_text_editors[el.id] = text_editor(el.text)
			}
			g_text_props[el.id] = el.text
			g_text_kinds[el.id] = el.kind
			g_active_fields[el.id] = true
			current_text := g_text_values[el.id] or { el.text }
			draw_text(ctx, current_text, x + el.padding_left, y, el.frame.width - el.padding_left - 8, el.frame.height, TextStyle{
				...el.text_style
				lines: if el.text_style.lines > 1 { el.text_style.lines } else { 1000 }
			})
			if el.enabled && !el.readonly {
				add_hit_target(HitTarget{
					id: el.id
					action_id: element_action_id(el)
					x: x
					y: y
					w: el.frame.width
					h: el.frame.height
					text_area: true
					emit_change: true
				}, clip)
			}
		}
	}
}

fn apply_clip(ctx &gg.Context, clip Rect) {
	ctx.scissor_rect(int(clip.x), int(clip.y), int(clip.width), int(clip.height))
}

fn add_hit_target(target HitTarget, clip Rect) {
	visible := intersect_rect(Rect{
		x: target.x
		y: target.y
		width: target.w
		height: target.h
	}, clip)
	if visible.width <= 0 || visible.height <= 0 {
		return
	}
	g_hit_targets << HitTarget{
		...target
		x: visible.x
		y: visible.y
		w: visible.width
		h: visible.height
	}
}

fn draw_cached_image(ctx &gg.Context, path string, x f64, y f64, width f64, height f64, rotation f64) bool {
	if path.trim_space() == '' {
		return false
	}
	g_active_images[path] = true
	mut image_id := g_image_ids[path] or { -1 }
	if image_id < 0 {
		mut image_ctx := ctx
		image := image_ctx.create_image(path) or { return false }
		image_id = image.id
		g_image_ids[path] = image_id
	}
	image := ctx.get_cached_image_by_idx(image_id)
	if !image.ok {
		return false
	}
	ctx.draw_image_with_config(
		img: image
		img_rect: gg.Rect{
			x: f32(x)
			y: f32(y)
			width: f32(width)
			height: f32(height)
		}
		rotation: f32(-rotation)
	)
	return true
}

// ── Drawing helpers ────────────────────────────────────────────────

fn hex_color(hex u32) gg.Color {
	return gg.Color{
		r: u8((hex >> 16) & 0xFF)
		g: u8((hex >> 8) & 0xFF)
		b: u8(hex & 0xFF)
		a: 255
	}
}

fn draw_rect(ctx &gg.Context, x f64, y f64, w f64, h f64, color_hex u32, radius f64) {
	c := hex_color(color_hex)
	if radius > 0 {
		ctx.draw_rounded_rect_filled(f32(x), f32(y), f32(w), f32(h), f32(radius), c)
	} else {
		ctx.draw_rect_filled(f32(x), f32(y), f32(w), f32(h), c)
	}
}

fn text_align(a Align) gg.HorizontalAlign {
	return match a {
		.left { .left }
		.center { .center }
		.right { .right }
	}
}

fn draw_text(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle) {
	if t.len == 0 {
		return
	}
	text_x := match style.align {
		.left { int(x) }
		.center { int(x + w / 2) }
		.right { int(x + w) }
	}

	text_y := int(y + h / 2)
	cfg := gg.TextCfg{
		color: hex_color(style.color)
		size: int(style.size)
		bold: style.bold
		align: text_align(style.align)
		vertical_align: .middle
	}
	if style.lines > 1 && t.contains('\n') {
		parts := t.split('\n')
		line_h := style.size + 4
		total_h := f64(parts.len) * line_h
		start_y := y + (h - total_h) / 2 + line_h / 2
		for i, part in parts {
			if i >= style.lines {
				break
			}
			ctx.draw_text(int(text_x), int(start_y + f64(i) * line_h), part, cfg)
		}
	} else {
		ctx.draw_text(text_x, text_y, t, cfg)
	}
}

fn draw_text_centered(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle) {
	centered_style := TextStyle{
		...style
		align: .center
	}
	draw_text(ctx, t, x, y, w, h, centered_style)
}
