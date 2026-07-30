module ui2

import gg
import time

struct HitTarget {
	id          string
	x           f64
	y           f64
	w           f64
	h           f64
	long_press  bool
	swipe_left  bool
	text_field  bool
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
__global g_focused_field = ''
__global g_scroll_offsets = map[string]f64{}
__global g_scroll_content_h = map[string]f64{}
__global g_hit_targets = []HitTarget{}
__global g_touch = TouchState{}
__global g_scroll_areas = map[string]Rect{}

// ── Public API ─────────────────────────────────────────────────────

pub fn bounds() Rect {
	if g_gg_app.ctx == unsafe { nil } {
		return Rect{
			width:  400
			height: 800
		}
	}
	return Rect{
		width:  f64(g_gg_app.ctx.width)
		height: f64(g_gg_app.ctx.height)
	}
}

pub fn run(build_fn BuildFn, event_fn EventFn) {
	g_build_screen = build_fn
	g_event_handler = event_fn
	g_gg_app.ctx = gg.new_context(
		bg_color:      hex_color(0xf4f6f8)
		width:         400
		height:        800
		create_window: true
		window_title:  'App'
		user_data:     unsafe { voidptr(g_gg_app) }
		frame_fn:      on_frame
		event_fn:      on_event
	)
	g_gg_app.ctx.run()
}

pub fn refresh() {
}

pub fn text(id string) string {
	return g_text_values[id] or { '' }
}

pub fn set_text(id string, t string) {
	g_text_values[id] = t
}

pub fn focus(id string) {
	g_focused_field = id
}

pub fn focused_text_area_id() string {
	return g_focused_field
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
		root := g_build_screen()
		render_element(ctx, root, 0, 0)
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
		down:             true
		start_x:          x
		start_y:          y
		current_x:        x
		current_y:        y
		start_time:       time.ticks()
		moved:            false
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
		if target.id.len > 0 && target.swipe_left {
			fire_event('swipe_left:' + target.id)
			return
		}
	}
	if g_touch.moved {
		return
	}
	target := hit_test(x, y)
	if target.id.len == 0 {
		if g_focused_field.len > 0 {
			g_focused_field = ''
		}
		return
	}
	if target.text_field {
		g_focused_field = target.id
		return
	}
	fire_event(target.id)
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
	if target.id.len > 0 && target.long_press {
		g_touch.long_press_fired = true
		fire_event('long:' + target.id)
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
	if voidptr(g_event_handler) != unsafe { nil } {
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
	current := g_text_values[g_focused_field] or { '' }
	g_text_values[g_focused_field] = current + rune(ch).str()
	fire_field_change(g_focused_field)
}

fn handle_key_down(key gg.KeyCode) {
	if g_focused_field.len == 0 {
		return
	}
	if key == .backspace {
		current := g_text_values[g_focused_field] or { '' }
		if current.len > 0 {
			g_text_values[g_focused_field] = current[..current.len - 1]
			fire_field_change(g_focused_field)
		}
	}
	if key == .enter || key == .kp_enter {
		g_focused_field = ''
	}
}

fn fire_field_change(id string) {
	for target in g_hit_targets {
		if target.id == id && target.text_field && target.emit_change {
			fire_event(id)
			return
		}
	}
}

// ── Rendering ──────────────────────────────────────────────────────

fn render_element(ctx &gg.Context, el Element, off_x f64, off_y f64) {
	match el.kind {
		.screen {
			w := f64(ctx.width)
			h := f64(ctx.height)
			draw_rect(ctx, 0, 0, w, h, el.box.bg, 0)
			for child in el.children {
				render_element(ctx, child, 0, 0)
			}
		}
		.view {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
			if el.id.len > 0 && (el.long_press || el.swipe_left) {
				g_hit_targets << HitTarget{
					id:         el.id
					x:          x
					y:          y
					w:          el.frame.width
					h:          el.frame.height
					long_press: el.long_press
					swipe_left: el.swipe_left
				}
			}
			for child in el.children {
				render_element(ctx, child, x, y)
			}
		}
		.scroll {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, 0)
			scroll_y := g_scroll_offsets[el.id] or { 0.0 }
			if el.id.len > 0 {
				g_scroll_areas[el.id] = Rect{
					x:      x
					y:      y
					width:  el.frame.width
					height: el.frame.height
				}
			}
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
				render_element(ctx, child, x, y - scroll_y)
			}
			if el.id.len > 0 {
				g_scroll_content_h[el.id] = content_h
			}
		}
		.label {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_text(ctx, el.text, x, y, el.frame.width, el.frame.height, el.text_style)
		}
		.image {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, 0xe8ecef, 0)
		}
		.button {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
			draw_text_centered(ctx, el.text, x, y, el.frame.width, el.frame.height, el.text_style)
			g_hit_targets << HitTarget{
				id:         el.id
				x:          x
				y:          y
				w:          el.frame.width
				h:          el.frame.height
				long_press: el.long_press
			}
		}
		.text_field {
			x := el.frame.x + off_x
			y := el.frame.y + off_y
			draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
			current_text := g_text_values[el.id] or { el.text }
			is_focused := g_focused_field == el.id
			if current_text.len > 0 {
				draw_text(ctx, current_text, x + 12, y, el.frame.width - 24, el.frame.height,
					el.text_style)
			} else if el.placeholder.len > 0 {
				placeholder_style := TextStyle{
					...el.text_style
					color: 0x999999
				}
				draw_text(ctx, el.placeholder, x + 12, y, el.frame.width - 24, el.frame.height,
					placeholder_style)
			}
			if is_focused {
				text_w := estimate_text_width(current_text, el.text_style.size)
				cursor_x := x + 12 + text_w
				cursor_y := y + el.frame.height * 0.2
				cursor_h := el.frame.height * 0.6
				draw_rect(ctx, cursor_x, cursor_y, 2, cursor_h, el.text_style.color, 0)
			}
			g_hit_targets << HitTarget{
				id:          el.id
				x:           x
				y:           y
				w:           el.frame.width
				h:           el.frame.height
				text_field:  true
				emit_change: el.emit_change
			}
		}
	}
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
		color:          hex_color(style.color)
		size:           int(style.size)
		bold:           style.bold
		align:          text_align(style.align)
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

fn estimate_text_width(t string, font_size f64) f64 {
	return f64(t.len) * font_size * 0.55
}
