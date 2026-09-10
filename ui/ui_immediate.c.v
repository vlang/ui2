// vfmt off
// Keep the imports inside the platform block. Hoisting gg imports makes the
// AppKit backend compile Sokol's ARC sources together with Objective-C MRC.
@[has_globals]
module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import fontstash
	import gg
	import os
	import sokol.sapp
	import time

	struct HitTarget {
		id             string
		action_id      string
		submit_id      string
		x              f64
		y              f64
		w              f64
		h              f64
		long_press     bool
		swipe_left     bool
		text_field     bool
		text_area      bool
		dropdown       bool
		slider         bool
		switch_control bool
		switch_state   bool
		toggle_button  bool
		toggle_group   string
		toggle_allow_no_selection bool
		slider_frame   Rect
		slider_padding f64
		slider_spec    SliderSpec
		options        []string
		// dropdown_option marks one row of the open dropdown list; id names the
		// owning dropdown and option_index the value the row selects.
		dropdown_option bool
		option_index    int
		emit_change bool
		clickable   bool
		draggable   bool
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
		scrollbar_drag     bool
		scrollbar_grab_y   f64
	}

	struct GgApp {
	mut:
		ctx &gg.Context = unsafe { nil }
	}

	// DropdownPopup caches the geometry of the open dropdown list. The list is
	// drawn after the element tree so it floats above every other control, and
	// it is recomputed each frame to stay anchored to a moving control.
	struct DropdownPopup {
	mut:
		id         string
		action_id  string
		x          f64
		y          f64
		width      f64
		height     f64
		row_height f64
		options    []string
		selected   int = -1
		text_style TextStyle
		radius     f64
		max_scroll f64
		mounted    bool
	}

	const dropdown_popup_padding = 4.0
	const dropdown_popup_gap = 4.0
	const dropdown_popup_margin = 4.0
	const dropdown_popup_min_row_height = 24.0

	__global g_build_screen = BuildFn(unsafe { nil })
	__global g_event_handler = EventFn(unsafe { nil })
	__global g_key_handler = KeyFn(unsafe { nil })
	__global g_scroll_handler = ScrollFn(unsafe { nil })
	__global g_drop_handler = DropFn(unsafe { nil })
	__global g_key_consumed = false
	__global g_gg_app = &GgApp{}
	__global g_text_values = map[string]string{}
	__global g_text_props = map[string]string{}
	__global g_text_editors = map[string]TextEditor{}
	__global g_text_kinds = map[string]Kind{}
	__global g_slider_values = map[string]f64{}
	__global g_slider_declared = map[string]f64{}
	__global g_slider_specs = map[string]SliderSpec{}
	__global g_switch_values = map[string]bool{}
	__global g_switch_declared = map[string]bool{}
	__global g_toggle_values = map[string]bool{}
	__global g_toggle_declared = map[string]bool{}
	__global g_toggle_groups = map[string]string{}
	__global g_toggle_allow_no_selection = map[string]bool{}
	__global g_focused_field = ''
	__global g_scroll_offsets = map[string]f64{}
	__global g_scroll_content_h = map[string]f64{}
	__global g_hit_targets = []HitTarget{}
	__global g_touch = TouchState{}
	__global g_scroll_areas = map[string]Rect{}
	__global g_active_fields = map[string]bool{}
	__global g_active_sliders = map[string]bool{}
	__global g_active_switches = map[string]bool{}
	__global g_active_toggles = map[string]bool{}
	__global g_active_scrolls = map[string]bool{}
	__global g_image_ids = map[string]int{}
	__global g_font_metrics = FontMetrics{}
	__global g_font_files = map[string]string{}
	__global g_font_indexed = false
	__global g_font_family_files = map[string]string{}
	__global g_font_family_metrics = map[string]FontMetrics{}
	__global g_font_symbol_ids = []int{}
	__global g_font_symbol_bases = map[int]bool{}
	__global g_font_symbol_fons = voidptr(unsafe { nil })
	__global g_active_images = map[string]bool{}
	__global g_open_dropdown = ''
	__global g_dropdown_popup = DropdownPopup{}
	__global g_dropdown_hover = -1
	__global g_dropdown_scroll = 0.0

	// ── Public API ─────────────────────────────────────────────────────

	pub fn bounds() Rect {
		if g_gg_app.ctx == unsafe { nil } {
			$if linux || macos || windows {
				return Rect{
					width: 800
					height: 600
				}
			}
			return Rect{
				width: 400
				height: 800
			}
		}
		// The drawn menu bar owns the top strip of the window, so the screen
		// an app lays out is the rest of it.
		return Rect{
			width: f64(g_gg_app.ctx.width)
			height: f64(g_gg_app.ctx.height) - menu_bar_height()
		}
	}

	pub fn run(build_fn BuildFn, event_fn EventFn) {
		$if linux || macos || windows {
			run_window('App', 800, 600, build_fn, event_fn)
		} $else {
			run_window('App', 400, 800, build_fn, event_fn)
		}
	}

	pub fn run_window(title string, width int, height int, build_fn BuildFn, event_fn EventFn) {
		g_build_screen = build_fn
		g_event_handler = event_fn
		configure_animation_driver(request_refresh, false)
		publish_menu_context(event_fn, title, unsafe { nil })
		// Choosing the font here rather than letting gg ask `fc-match` for one
		// keeps the window legible and identical across distributions, and
		// gives draw_text the metrics it needs to size text in points.
		font_regular, font_bold := font_paths()
		if font_regular.len > 0 {
			g_font_metrics = font_file_metrics(font_regular) or { FontMetrics{} }
		}
		g_gg_app.ctx = gg.new_context(
			bg_color: hex_color(0xf4f6f8)
			font_path: font_regular
			custom_bold_font_path: font_bold
			width: width
			height: height
			sample_count: 4
			create_window: true
			window_title: title
			user_data: unsafe { voidptr(g_gg_app) }
			init_fn: on_init
			frame_fn: on_frame
			event_fn: on_event
			enable_dragndrop: true
			max_dropped_files: 32
			max_dropped_file_path_length: 4096
		)
		g_gg_app.ctx.run()
	}

	pub fn refresh() {
	}

	// The immediate backend already rebuilds every frame, so both refresh entry
	// points are intentionally scheduling no-ops.
	pub fn request_refresh() {
	}

	pub fn refresh_element(_id string, _element Element) {
	}

	pub fn on_key(handler KeyFn) {
		g_key_handler = handler
	}

	pub fn on_scroll(handler ScrollFn) {
		g_scroll_handler = handler
	}

	pub fn on_drop(handler DropFn) {
		g_drop_handler = handler
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

	// slider_value returns the live value currently displayed by a mounted
	// slider, including a value changed by pointer input before the next build.
	pub fn slider_value(id string) f64 {
		return g_slider_values[id] or { 0 }
	}

	pub fn set_slider_value(id string, value f64) {
		if id !in g_active_sliders {
			return
		}
		spec := g_slider_specs[id] or { return }
		g_slider_values[id] = slider_clamped_value(value, spec.min, spec.max)
	}

	// switch_active returns the live value, including a pointer change made
	// before the declarative tree is rebuilt.
	pub fn switch_active(id string) bool {
		return g_switch_values[id] or { false }
	}

	pub fn set_switch_active(id string, active bool) {
		if id !in g_active_switches {
			return
		}
		g_switch_values[id] = active
	}

	pub fn toggle_button_pressed(id string) bool {
		return g_toggle_values[id] or { false }
	}

	pub fn set_toggle_button_pressed(id string, pressed bool) {
		if id !in g_active_toggles {
			return
		}
		if pressed {
			release_custom_toggle_group(id)
		}
		g_toggle_values[id] = pressed
	}

	pub fn toggle_button_group_members(id string) []string {
		group := g_toggle_groups[id] or { return [] }
		if group.len == 0 {
			return [id]
		}
		mut members := []string{}
		for member, member_group in g_toggle_groups {
			if member_group == group && member in g_active_toggles {
				members << member
			}
		}
		return members
	}

	fn release_custom_toggle_group(id string) {
		group := g_toggle_groups[id] or { return }
		if group.len == 0 {
			return
		}
		for member, member_group in g_toggle_groups {
			if member != id && member_group == group {
				g_toggle_values[member] = false
			}
		}
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

	pub fn focused_id() string {
		return g_focused_field
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

	pub fn quit() {
		if g_gg_app.ctx != unsafe { nil } {
			g_gg_app.ctx.quit()
		}
	}

	pub fn consume_key() {
		g_key_consumed = true
	}

	pub fn consume_text_key() {
		consume_key()
	}

	pub fn safe_area_top() f64 {
		return 0
	}

	pub fn start_barcode_scan() {
		if voidptr(g_event_handler) != unsafe { nil } {
			g_event_handler('scan_error:barcode scanner unavailable')
		}
	}

	pub fn insert_text_area_text(id string, value string) {
		if id !in g_active_fields || (g_text_kinds[id] or { Kind.screen }) != .text_area {
			return
		}
		mut editor := g_text_editors[id] or { text_editor(g_text_values[id] or { '' }) }
		editor.insert_text(value)
		g_text_editors[id] = editor
		g_text_values[id] = editor.text
		fire_field_change(id)
	}

	pub fn scroll_offset(id string) f64 {
		return g_scroll_offsets[id] or { 0.0 }
	}

	pub fn scroll_to_rect(id string, _x f64, y f64, _width f64, height f64) {
		area := g_scroll_viewports[id] or { return }
		current := scroll_offset(id)
		mut next := current
		if y < current {
			next = y
		} else if y + height > current + area.height {
			next = y + height - area.height
		}
		set_scroll_offset(id, next, scroll_maximum(id))
	}

	pub fn clipboard_has_image() bool {
		return false
	}

	pub fn save_clipboard_image_png(_path string) bool {
		return false
	}

	pub fn text_area_runs(id string) []TextRun {
		value := text(id)
		return if value.len == 0 { []TextRun{} } else { [TextRun{text: value}] }
	}

	pub fn text_area_format_state(_id string) TextFormatState {
		return TextFormatState{}
	}

	pub fn toggle_text_area_format(id string, _format TextFormat) TextFormatState {
		return text_area_format_state(id)
	}

	pub fn set_text_area_font_family(id string, _family string) TextFormatState {
		return text_area_format_state(id)
	}

	pub fn set_text_area_font_size(id string, _size f64) TextFormatState {
		return text_area_format_state(id)
	}

	pub fn set_text_area_color(id string, _color u32) TextFormatState {
		return text_area_format_state(id)
	}

	pub fn set_text_area_background_color(id string, _color u32) TextFormatState {
		return text_area_format_state(id)
	}

	pub fn set_text_area_effect(id string, _effect string) TextFormatState {
		return text_area_format_state(id)
	}

	pub fn toggle_text_area_superscript(id string) TextFormatState {
		return text_area_format_state(id)
	}

	pub fn toggle_text_area_subscript(id string) TextFormatState {
		return text_area_format_state(id)
	}

	pub fn toggle_text_area_vertical_align(id string, _align string) TextFormatState {
		return text_area_format_state(id)
	}

	// ── Frame & event loop ─────────────────────────────────────────────

	fn on_init(_ &GgApp) {
		if voidptr(g_build_screen) == unsafe { nil } {
			return
		}
		// gg/Sokol must receive images during initialization to make their GPU
		// textures available for the first rendered frame.
		preload_images(g_build_screen())
	}

	fn on_frame(app &GgApp) {
		if app.ctx == unsafe { nil } {
			return
		}
		mut ctx := app.ctx
		// Some window managers can choose a client size different from the one
		// requested in gg.Config before gg's cached resize event catches up. UI2
		// lays out and clips against that cache, so synchronize it from Sokol's
		// live logical window size before building the frame.
		live_size := ctx.window_size()
		if live_size.width > 0 && live_size.height > 0
			&& (ctx.width != live_size.width || ctx.height != live_size.height) {
			ctx.width = live_size.width
			ctx.height = live_size.height
			ctx.window.width = live_size.width
			ctx.window.height = live_size.height
		}
		// gg builds its fonts in the sokol init callback, after the window has
		// been created, so the fallback chain is attached on the way into the
		// first frame rather than in run_window.
		ensure_symbol_fallbacks(ctx)
		mut root := Element{}
		mut has_root := false
		if voidptr(g_build_screen) != unsafe { nil } {
			g_hit_targets = []HitTarget{}
			reset_scroll_frame()
			g_active_fields = map[string]bool{}
			g_active_sliders = map[string]bool{}
			g_active_switches = map[string]bool{}
			g_active_toggles = map[string]bool{}
			g_active_scrolls = map[string]bool{}
			g_active_images = map[string]bool{}
			root = apply_widget_animations(g_build_screen())
			validate_element_tree(root) or {
				eprintln('ui2: ${err}')
				return
			}
			// Sokol resources must be created before ctx.begin() starts its draw
			// pass. Loading here lets the Linux/custom renderer draw PNGs and BMPs
			// on the same frame they first appear.
			preload_images(root)
			has_root = true
		}
		ctx.begin()
		if has_root {
			g_dropdown_popup.mounted = false
			top := menu_bar_height()
			render_element(ctx, root, 0, top, rect(0, top, f64(ctx.width), f64(ctx.height) - top))
			if g_open_dropdown.len > 0 {
				if g_dropdown_popup.mounted {
					draw_dropdown_popup(ctx)
				} else {
					close_dropdown()
				}
			}
			// The bar and its panels float above every control in the window.
			draw_menu_bar(ctx)
			prune_unmounted_state()
		}
		check_long_press()
		ctx.end()
	}

	fn on_event(e &gg.Event, _ &GgApp) {
		match e.typ {
			.mouse_down {
				if menu_bar_handle_down(f64(e.mouse_x), f64(e.mouse_y)) {
					return
				}
				handle_touch_down(f64(e.mouse_x), f64(e.mouse_y))
			}
			.mouse_move {
				if menu_bar_handle_move(f64(e.mouse_x), f64(e.mouse_y)) {
					return
				}
				if g_open_dropdown.len > 0 {
					update_dropdown_hover(f64(e.mouse_x), f64(e.mouse_y))
				}
				if g_touch.down {
					handle_touch_move(f64(e.mouse_x), f64(e.mouse_y))
				}
			}
			.mouse_scroll {
				if menu_bar_open() {
					return
				}
				handle_mouse_scroll(f64(e.mouse_x), f64(e.mouse_y), f64(e.scroll_y))
			}
			.mouse_up {
				if menu_bar_handle_up(f64(e.mouse_x), f64(e.mouse_y)) {
					return
				}
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
				if menu_bar_handle_key(e) {
					return
				}
				if g_open_dropdown.len > 0 {
					if handle_dropdown_key(e.key_code) {
						return
					}
				}
				if !dispatch_key_event(e) {
					handle_key_down(e.key_code)
				}
			}
			.files_dropped {
				handle_files_dropped(e)
			}
			else {}
		}
	}

	// ── Touch handling ─────────────────────────────────────────────────

	fn pointer_event_id(phase string, action_id string, x f64, y f64) string {
		return 'pointer:${phase}:${action_id}:${x}:${y}'
	}

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
		if g_open_dropdown.len > 0 {
			update_dropdown_hover(x, y)
			return
		}
		target := hit_test(x, y)
		if target.slider {
			commit_slider(target, x, y)
			return
		}
		if target.switch_control {
			return
		}
		g_touch.scroll_id = scroll_hit_test(x, y)
		g_touch.scroll_start_off_y = scroll_offset(g_touch.scroll_id)
		if begin_scrollbar_drag(x, y) {
			return
		}
		if target.action_id.len > 0 && (target.clickable || target.draggable) {
			fire_event(pointer_event_id('down', target.action_id, x, y))
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
		target := hit_test(g_touch.start_x, g_touch.start_y)
		if target.slider {
			commit_slider(target, x, y)
			return
		}
		if target.switch_control {
			commit_switch(target, x >= target.x + target.w / 2)
			return
		}
		if g_touch.scrollbar_drag {
			drag_scrollbar(y)
			return
		}
		if g_touch.scroll_id.len > 0 {
			delta := g_touch.start_y - y
			new_offset := g_touch.scroll_start_off_y + delta
			set_scroll_offset(g_touch.scroll_id, new_offset, scroll_maximum(g_touch.scroll_id))
		}
		if target.action_id.len > 0 && target.draggable {
			fire_event(pointer_event_id('drag', target.action_id, x, y))
		}
	}

	fn handle_mouse_scroll(x f64, y f64, delta_y f64) {
		if g_open_dropdown.len > 0 {
			g_dropdown_scroll = clamped_dropdown_scroll(g_dropdown_scroll - delta_y * 24)
			update_dropdown_hover(x, y)
			return
		}
		id := scroll_hit_test(x, y)
		if id.len == 0 {
			return
		}
		set_scroll_offset(id, scroll_offset(id) - delta_y * 48, scroll_maximum(id))
	}

	fn set_scroll_offset(id string, requested f64, maximum f64) {
		max_scroll := if maximum > 0 { maximum } else { 0.0 }
		next := if requested < 0 {
			0.0
		} else if requested > max_scroll {
			max_scroll
		} else {
			requested
		}
		previous := g_scroll_offsets[id] or { 0.0 }
		g_scroll_offsets[id] = next
		if next != previous && voidptr(g_scroll_handler) != unsafe { nil } {
			g_scroll_handler(id)
		}
	}

	fn handle_touch_up(x f64, y f64) {
		if !g_touch.down {
			return
		}
		g_touch.down = false
		slider_target := hit_test(g_touch.start_x, g_touch.start_y)
		if slider_target.slider {
			commit_slider(slider_target, x, y)
			return
		}
		if slider_target.switch_control {
			if g_touch.moved {
				commit_switch(slider_target, x >= slider_target.x + slider_target.w / 2)
			} else {
				current := if slider_target.id.len > 0 {
					switch_active(slider_target.id)
				} else {
					slider_target.switch_state
				}
				commit_switch(slider_target, !current)
			}
			return
		}
		if g_touch.long_press_fired || g_touch.scrollbar_drag {
			return
		}
		if g_open_dropdown.len > 0 {
			handle_dropdown_release(x, y)
			return
		}
		mut target := hit_test(g_touch.start_x, g_touch.start_y)
		dx := x - g_touch.start_x
		if g_touch.moved && dx < -72 {
			if target.action_id.len > 0 && target.swipe_left {
				fire_event('swipe_left:' + target.action_id)
				return
			}
		}
		if target.action_id.len > 0 && (target.clickable || target.draggable) {
			fire_event(pointer_event_id('up', target.action_id, x, y))
			return
		}
		if g_touch.moved {
			return
		}
		target = hit_test(x, y)
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
			open_dropdown(target)
			return
		}
		if target.toggle_button {
			commit_toggle_button(target)
			return
		}
		fire_event(target.action_id)
	}

	fn check_long_press() {
		if !g_touch.down || g_touch.moved || g_touch.long_press_fired || g_touch.scrollbar_drag {
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

	fn slider_target_value(target HitTarget, x f64, y f64) f64 {
		normalized := slider_normalized_from_point(target.slider_frame,
			target.slider_spec.orientation, target.slider_padding, x, y)
		return slider_value_from_normalized(normalized, target.slider_spec.min,
			target.slider_spec.max, target.slider_spec.step)
	}

	fn commit_slider(target HitTarget, x f64, y f64) {
		if !target.slider {
			return
		}
		next := slider_target_value(target, x, y)
		previous := g_slider_values[target.id] or { target.slider_spec.min }
		if target.id.len > 0 {
			g_slider_values[target.id] = next
		}
		if next != previous {
			fire_event(target.action_id)
		}
	}

	fn commit_switch(target HitTarget, active bool) {
		if !target.switch_control {
			return
		}
		previous := if target.id.len > 0 { switch_active(target.id) } else { target.switch_state }
		if target.id.len > 0 {
			g_switch_values[target.id] = active
		}
		if active != previous {
			fire_event(target.action_id)
		}
	}

	fn commit_toggle_button(target HitTarget) {
		if !target.toggle_button {
			return
		}
		previous := toggle_button_pressed(target.id)
		mut pressed := !previous
		if target.toggle_group.len > 0 && previous && !target.toggle_allow_no_selection {
			pressed = true
		}
		if target.id.len > 0 {
			if pressed {
				release_custom_toggle_group(target.id)
			}
			g_toggle_values[target.id] = pressed
		}
		fire_event(target.action_id)
	}

	fn handle_files_dropped(e &gg.Event) {
		if voidptr(g_drop_handler) == unsafe { nil } {
			return
		}
		mut paths := []string{cap: sapp.get_num_dropped_files()}
		for index in 0 .. sapp.get_num_dropped_files() {
			path := sapp.get_dropped_file_path(index)
			if path.len > 0 {
				paths << path
			}
		}
		g_drop_handler(DropEvent{
			paths: paths
			x: f64(e.mouse_x)
			y: f64(e.mouse_y)
		})
	}

	// ── Keyboard input ─────────────────────────────────────────────────

	fn dispatch_key_event(e &gg.Event) bool {
		if voidptr(g_key_handler) == unsafe { nil } {
			return false
		}
		key := immediate_normalized_key(e)
		if key.len == 0 {
			return false
		}
		mut event_key := key
		for target in g_hit_targets {
			if target.id == g_focused_field && target.text_area {
				event_key = 'text:${target.id}:${key}'
				break
			}
		}
		g_key_consumed = false
		g_key_handler(event_key)
		consumed := g_key_consumed
		g_key_consumed = false
		return consumed
	}

	fn immediate_normalized_key(e &gg.Event) string {
		code := int(e.key_code)
		mut key := match e.key_code {
			.backspace { 'backspace' }
			.tab { 'tab' }
			.enter, .kp_enter { 'enter' }
			.escape { 'escape' }
			.page_up { 'page_up' }
			.page_down { 'page_down' }
			.end { 'end' }
			.home { 'home' }
			.left { 'left' }
			.up { 'up' }
			.right { 'right' }
			.down { 'down' }
			.delete { 'forward_delete' }
			else {
				if code >= int(gg.KeyCode.f1) && code <= int(gg.KeyCode.f25) {
					'f${code - int(gg.KeyCode.f1) + 1}'
				} else if code >= int(gg.KeyCode.space) && code <= int(gg.KeyCode.z) {
					rune(code).str().to_lower()
				} else {
					''
				}
			}
		}
		if key.len == 0 {
			return ''
		}
		mut modifiers := []string{}
		if e.modifiers & u32(gg.Modifier.super) != 0 {
			modifiers << 'cmd'
		}
		if e.modifiers & u32(gg.Modifier.ctrl) != 0 {
			modifiers << 'ctrl'
		}
		if e.modifiers & u32(gg.Modifier.alt) != 0 {
			modifiers << 'alt'
		}
		if e.modifiers & u32(gg.Modifier.shift) != 0 {
			modifiers << 'shift'
		}
		if modifiers.len > 0 {
			key = modifiers.join('+') + '+' + key
		}
		return key
	}

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

	// ── Dropdown popup ─────────────────────────────────────────────────

	// A dropdown click opens a floating list of its options. Without an id there
	// is nowhere to keep the selection, so such a control only reports the tap.
	fn open_dropdown(target HitTarget) {
		if target.id.len == 0 || target.options.len == 0 {
			fire_event(target.action_id)
			return
		}
		close_dropdown()
		g_open_dropdown = target.id
		g_focused_field = ''
	}

	fn close_dropdown() {
		g_open_dropdown = ''
		g_dropdown_hover = -1
		g_dropdown_scroll = 0.0
		g_dropdown_popup = DropdownPopup{}
	}

	// While the list is open it owns every release: pick the row under the
	// pointer, or dismiss on any release outside it (including the control).
	fn handle_dropdown_release(x f64, y f64) {
		release := hit_test(x, y)
		if release.dropdown_option && release.id == g_open_dropdown {
			select_dropdown_option(release)
			return
		}
		close_dropdown()
	}

	fn select_dropdown_option(target HitTarget) {
		if target.option_index < 0 || target.option_index >= target.options.len {
			close_dropdown()
			return
		}
		commit_dropdown(target.id, target.action_id, target.options[target.option_index])
	}

	fn commit_dropdown(id string, action_id string, value string) {
		close_dropdown()
		g_text_values[id] = value
		fire_event(action_id)
	}

	fn handle_dropdown_key(key gg.KeyCode) bool {
		dropdown_state := g_dropdown_popup
		if dropdown_state.options.len == 0 {
			return false
		}
		highlighted := if g_dropdown_hover >= 0 { g_dropdown_hover } else { dropdown_state.selected }
		match key {
			.escape {
				close_dropdown()
				return true
			}
			.up, .down {
				step := if key == .down { 1 } else { -1 }
				mut next := highlighted + step
				if next < 0 {
					next = dropdown_state.options.len - 1
				} else if next >= dropdown_state.options.len {
					next = 0
				}
				g_dropdown_hover = next
				reveal_dropdown_row(next)
				return true
			}
			.enter, .kp_enter {
				if highlighted < 0 || highlighted >= dropdown_state.options.len {
					close_dropdown()
					return true
				}
				commit_dropdown(dropdown_state.id, dropdown_state.action_id,
					dropdown_state.options[highlighted])
				return true
			}
			else {
				return false
			}
		}
	}

	fn update_dropdown_hover(x f64, y f64) {
		mut hover := -1
		for target in g_hit_targets {
			if !target.dropdown_option || target.id != g_open_dropdown {
				continue
			}
			if x >= target.x && x <= target.x + target.w && y >= target.y && y <= target.y + target.h {
				hover = target.option_index
			}
		}
		g_dropdown_hover = hover
	}

	fn clamped_dropdown_scroll(offset f64) f64 {
		if offset < 0 {
			return 0.0
		}
		max_scroll := g_dropdown_popup.max_scroll
		return if offset > max_scroll { max_scroll } else { offset }
	}

	fn reveal_dropdown_row(index int) {
		dropdown_state := g_dropdown_popup
		if index < 0 || dropdown_state.max_scroll <= 0 {
			g_dropdown_scroll = clamped_dropdown_scroll(g_dropdown_scroll)
			return
		}
		view_height := dropdown_state.height - dropdown_popup_padding * 2
		row_top := f64(index) * dropdown_state.row_height
		row_bottom := row_top + dropdown_state.row_height
		mut offset := g_dropdown_scroll
		if row_top < offset {
			offset = row_top
		} else if row_bottom > offset + view_height {
			offset = row_bottom - view_height
		}
		g_dropdown_scroll = clamped_dropdown_scroll(offset)
	}

	fn dropdown_row_height(style TextStyle) f64 {
		row_height := style.size + 13
		return if row_height < dropdown_popup_min_row_height {
			dropdown_popup_min_row_height
		} else {
			row_height
		}
	}

	// dropdown_popup_frame drops the list below its control, flips it above when
	// more rows fit there, and keeps whole rows inside the window so a clipped
	// half row never looks selectable.
	fn dropdown_popup_frame(anchor Rect, options int, row_height f64, window Rect) Rect {
		chrome := dropdown_popup_padding * 2
		below := window.height - (anchor.y + anchor.height) - dropdown_popup_gap - dropdown_popup_margin
		above := anchor.y - dropdown_popup_gap - dropdown_popup_margin
		rows_below := int((below - chrome) / row_height)
		rows_above := int((above - chrome) / row_height)
		flip := rows_above > rows_below
		mut rows := if flip { rows_above } else { rows_below }
		if rows > options {
			rows = options
		}
		if rows < 1 {
			rows = 1
		}
		height := f64(rows) * row_height + chrome
		mut x := anchor.x
		if x + anchor.width > window.width - dropdown_popup_margin {
			x = window.width - dropdown_popup_margin - anchor.width
		}
		if x < dropdown_popup_margin {
			x = dropdown_popup_margin
		}
		mut y := if flip {
			anchor.y - dropdown_popup_gap - height
		} else {
			anchor.y + anchor.height + dropdown_popup_gap
		}
		if y + height > window.height - dropdown_popup_margin {
			y = window.height - dropdown_popup_margin - height
		}
		if y < dropdown_popup_margin {
			y = dropdown_popup_margin
		}
		return rect(x, y, anchor.width, height)
	}

	fn track_dropdown_popup(el Element, x f64, y f64, options []string, selected string) {
		ctx := g_gg_app.ctx
		if ctx == unsafe { nil } {
			return
		}
		mut selected_index := -1
		for index, option in options {
			if option == selected {
				selected_index = index
				break
			}
		}
		row_height := dropdown_row_height(el.text_style)
		anchor := rect(x, y, el.frame.width, el.frame.height)
		window := rect(0, 0, f64(ctx.width), f64(ctx.height))
		frame := dropdown_popup_frame(anchor, options.len, row_height, window)
		content_height := f64(options.len) * row_height
		view_height := frame.height - dropdown_popup_padding * 2
		opening := g_dropdown_popup.id != el.id
		g_dropdown_popup = DropdownPopup{
			id: el.id
			action_id: element_action_id(el)
			x: frame.x
			y: frame.y
			width: frame.width
			height: frame.height
			row_height: row_height
			options: options
			selected: selected_index
			text_style: el.text_style
			radius: el.box.radius
			max_scroll: if content_height > view_height { content_height - view_height } else { 0.0 }
			mounted: true
		}
		if opening {
			g_dropdown_scroll = 0.0
			g_dropdown_hover = -1
			reveal_dropdown_row(selected_index)
		} else {
			g_dropdown_scroll = clamped_dropdown_scroll(g_dropdown_scroll)
		}
	}

	fn draw_dropdown_popup(ctx &gg.Context) {
		dropdown_state := g_dropdown_popup
		if dropdown_state.options.len == 0 || dropdown_state.width <= 0
			|| dropdown_state.height <= 0 {
			return
		}
		window := rect(0, 0, f64(ctx.width), f64(ctx.height))
		apply_clip(ctx, window)
		draw_rect(ctx, dropdown_state.x + 1, dropdown_state.y + 2, dropdown_state.width,
			dropdown_state.height, 0xdbe2ea, dropdown_state.radius)
		draw_rect(ctx, dropdown_state.x, dropdown_state.y, dropdown_state.width,
			dropdown_state.height, 0xffffff, dropdown_state.radius)
		draw_outline(ctx, dropdown_state.x, dropdown_state.y, dropdown_state.width,
			dropdown_state.height, 0xb8c2cf, dropdown_state.radius)
		list := intersect_rect(rect(dropdown_state.x + 1,
			dropdown_state.y + dropdown_popup_padding, dropdown_state.width - 2,
			dropdown_state.height - dropdown_popup_padding * 2), window)
		if list.width <= 0 || list.height <= 0 {
			return
		}
		apply_clip(ctx, list)
		row_style := TextStyle{
			...dropdown_state.text_style
			align: .left
		}
		for index, option in dropdown_state.options {
			row_y := dropdown_state.y + dropdown_popup_padding + f64(index) * dropdown_state.row_height -
				g_dropdown_scroll
			if row_y + dropdown_state.row_height <= list.y || row_y >= list.y + list.height {
				continue
			}
			if index == g_dropdown_hover {
				draw_rect(ctx, dropdown_state.x + 2, row_y, dropdown_state.width - 4,
					dropdown_state.row_height, 0xdbeafe, 4)
			} else if index == dropdown_state.selected {
				draw_rect(ctx, dropdown_state.x + 2, row_y, dropdown_state.width - 4,
					dropdown_state.row_height, 0xf1f5f9, 4)
			}
			if index == dropdown_state.selected {
				mark := if dropdown_state.row_height < 13 { dropdown_state.row_height } else { 13.0 }
				draw_check_mark(ctx, dropdown_state.x + 7,
					row_y + (dropdown_state.row_height - mark) / 2, mark, row_style.color)
			}
			draw_text(ctx, option, dropdown_state.x + 26, row_y, dropdown_state.width - 34,
				dropdown_state.row_height, row_style)
			add_hit_target(HitTarget{
				id: dropdown_state.id
				action_id: dropdown_state.action_id
				x: dropdown_state.x
				y: row_y
				w: dropdown_state.width
				h: dropdown_state.row_height
				dropdown_option: true
				option_index: index
				options: dropdown_state.options
			}, list)
		}
		draw_scrollbar(ctx, dropdown_state.x, dropdown_state.y, dropdown_state.width,
			dropdown_state.height, f64(dropdown_state.options.len) * dropdown_state.row_height +
			dropdown_popup_padding * 2, g_dropdown_scroll, false)
		apply_clip(ctx, window)
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
		mut stale_sliders := []string{}
		for id, _ in g_slider_values {
			if id !in g_active_sliders {
				stale_sliders << id
			}
		}
		for id in stale_sliders {
			g_slider_values.delete(id)
			g_slider_declared.delete(id)
			g_slider_specs.delete(id)
		}
		mut stale_switches := []string{}
		for id, _ in g_switch_values {
			if id !in g_active_switches {
				stale_switches << id
			}
		}
		for id in stale_switches {
			g_switch_values.delete(id)
			g_switch_declared.delete(id)
		}
		mut stale_toggles := []string{}
		for id, _ in g_toggle_values {
			if id !in g_active_toggles {
				stale_toggles << id
			}
		}
		for id in stale_toggles {
			g_toggle_values.delete(id)
			g_toggle_declared.delete(id)
			g_toggle_groups.delete(id)
			g_toggle_allow_no_selection.delete(id)
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
		for id in g_text_area_layouts.keys() {
			if id !in g_active_fields || (g_text_kinds[id] or { Kind.screen }) != .text_area {
				g_text_area_layouts.delete(id)
			}
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
				if box_draws_fill(el.box) {
					draw_rect(ctx, off_x, off_y, w - off_x, h - off_y, el.box.bg, 0)
				}
				draw_box_borders(ctx, off_x, off_y, w - off_x, h - off_y, el.box)
				for child in el.children {
					render_element(ctx, child, off_x, off_y, clip)
				}
			}
			.view {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				if box_draws_fill(el.box) {
					draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)
				}
				draw_box_borders(ctx, x, y, el.frame.width, el.frame.height, el.box)
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
						clickable: el.clickable
						draggable: el.draggable
					}, clip)
				}
				for child in el.children {
					render_element(ctx, child, x, y, clip)
				}
			}
			.scroll {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				frame := rect(x, y, el.frame.width, el.frame.height)
				if box_draws_fill(el.box) {
					draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, 0)
				}
				draw_box_borders(ctx, x, y, el.frame.width, el.frame.height, el.box)
				mut content_h := 0.0
				for child in el.children {
					if !child.hidden && child.frame.y + child.frame.height > content_h {
						content_h = child.frame.y + child.frame.height
					}
				}
				// Include the bottom inset in both the scroll range and thumb geometry.
				if content_h > 0 {
					content_h += 16
				}
				scroll_y := register_scroll_view(el.id, frame, clip, content_h, el.enabled,
					true, el.persistent_scrollbars)
				child_clip := intersect_rect(frame, clip)
				for child in el.children {
					child_screen_y := child.frame.y - scroll_y
					if child_screen_y + child.frame.height < 0 || child_screen_y > el.frame.height {
						continue
					}
					render_element(ctx, child, x, y - scroll_y, child_clip)
				}
				if child_clip.width > 0 && child_clip.height > 0 {
					apply_clip(ctx, child_clip)
					draw_scrollbar(ctx, x, y, el.frame.width, el.frame.height, content_h, scroll_y,
						el.persistent_scrollbars)
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
						clickable: el.clickable
						draggable: el.draggable
					}, clip)
				}
			}
			.button {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				if box_draws_fill(el.box) {
					if el.native_style && el.box.bg == unstyled_box_bg {
						draw_button_bezel(ctx, x, y, el.frame.width, el.frame.height, el.box.radius,
							el.enabled)
					} else {
						draw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg,
							el.box.radius)
					}
				}
				draw_box_borders(ctx, x, y, el.frame.width, el.frame.height, el.box)
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
			.toggle_button {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				mut pressed := el.checked
				if el.id.len > 0 {
					g_toggle_groups[el.id] = el.toggle_group
					g_toggle_allow_no_selection[el.id] = el.toggle_allow_no_selection
					previous_declared := g_toggle_declared[el.id] or { el.checked }
					previous_value := g_toggle_values[el.id] or { el.checked }
					if el.id !in g_toggle_values
						|| (previous_declared != el.checked && previous_value != el.checked) {
						g_toggle_values[el.id] = el.checked
					}
					pressed = g_toggle_values[el.id] or { el.checked }
					if pressed {
						release_custom_toggle_group(el.id)
					}
					g_toggle_declared[el.id] = el.checked
					g_active_toggles[el.id] = true
				}
				box := if pressed { el.toggle_down_box } else { el.box }
				style := if pressed { el.toggle_down_text_style } else { el.text_style }
				if box_draws_fill(box) {
					if el.native_style && box.bg == unstyled_box_bg {
						draw_button_bezel(ctx, x, y, el.frame.width, el.frame.height, box.radius,
							el.enabled)
					} else {
						draw_rect(ctx, x, y, el.frame.width, el.frame.height, box.bg, box.radius)
					}
				}
				draw_box_borders(ctx, x, y, el.frame.width, el.frame.height, box)
				draw_text_centered(ctx, el.text, x, y, el.frame.width, el.frame.height, style)
				if el.enabled {
					add_hit_target(HitTarget{
						id: el.id
						action_id: element_action_id(el)
						x: x
						y: y
						w: el.frame.width
						h: el.frame.height
						toggle_button: true
						toggle_group: el.toggle_group
						toggle_allow_no_selection: el.toggle_allow_no_selection
					}, clip)
				}
			}
			.checkbox {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				box_size := if el.frame.height < 18 { el.frame.height } else { 18.0 }
				box_y := y + (el.frame.height - box_size) / 2
				fill := if el.checked {
					if el.enabled { u32(0x3478d4) } else { u32(0x94a3b8) }
				} else {
					u32(0xffffff)
				}
				border := if el.checked {
					if el.enabled { u32(0x2f6fc4) } else { u32(0x94a3b8) }
				} else if el.enabled {
					u32(0x64748b)
				} else {
					u32(0xcbd5e1)
				}
				draw_rect(ctx, x, box_y, box_size, box_size, fill, 4)
				draw_outline(ctx, x, box_y, box_size, box_size, border, 4)
				if el.checked {
					draw_check_mark(ctx, x, box_y, box_size, if el.enabled { u32(0xffffff) } else { u32(0xf8fafc) })
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
				list_open := el.enabled && el.id.len > 0 && g_open_dropdown == el.id
				draw_control_surface(ctx, x, y, el.frame.width, el.frame.height, el.box,
					list_open, el.enabled)
				padding := if el.padding_left > 0 { el.padding_left } else { 12.0 }
				text_width := if el.frame.width > padding + 32 { el.frame.width - padding - 32 } else { 0.0 }
				draw_text(ctx, selected, x + padding, y, text_width, el.frame.height, el.text_style)
				draw_chevron_down(ctx, x + el.frame.width - 17, y + el.frame.height / 2,
					if el.enabled { u32(0x475569) } else { u32(0x94a3b8) })
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
					if list_open {
						visible := intersect_rect(rect(x, y, el.frame.width, el.frame.height),
							clip)
						if options.len > 0 && visible.width > 0 && visible.height > 0 {
							track_dropdown_popup(el, x, y, options, selected)
						} else {
							close_dropdown()
						}
					}
				} else if el.id.len > 0 && g_open_dropdown == el.id {
					close_dropdown()
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
				draw_control_surface(ctx, x, y, el.frame.width, el.frame.height, el.box,
					is_focused, el.enabled)
				if current_text.len > 0 {
					draw_editable_text(ctx, display_text, x + padding_left, y, content_width, el.frame.height, el.text_style)
				} else if el.placeholder.len > 0 {
					placeholder_style := TextStyle{
						...el.text_style
						color: 0x999999
					}
					draw_editable_text(ctx, el.placeholder, x + padding_left, y, content_width, el.frame.height, placeholder_style)
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
				if el.enabled && !el.readonly {
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
				draw_control_surface(ctx, x, y, el.frame.width, el.frame.height, el.box,
					g_focused_field == el.id, el.enabled)
				draw_text_area_content(ctx, el, current_text, x, y, clip)
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
			.slider {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				frame := rect(x, y, el.frame.width, el.frame.height)
				spec := slider_spec(el)
				mut current := el.value
				if el.id.len > 0 {
					previous_declared := g_slider_declared[el.id] or { el.value }
					previous_value := g_slider_values[el.id] or { el.value }
					if el.id !in g_slider_values
						|| (previous_declared != el.value && previous_value != el.value) {
						g_slider_values[el.id] = el.value
					}
					current = slider_clamped_value(g_slider_values[el.id] or { el.value },
						spec.min, spec.max)
					g_slider_values[el.id] = current
					g_slider_declared[el.id] = el.value
					g_slider_specs[el.id] = spec
					g_active_sliders[el.id] = true
				}
				normalized := slider_value_normalized(current, spec.min, spec.max)
				track_width := if el.slider_style.track_width > 0 {
					el.slider_style.track_width
				} else {
					4.0
				}
				thumb_size := if el.slider_style.thumb_size > 0 {
					el.slider_style.thumb_size
				} else {
					20.0
				}
				track_color := if el.enabled { el.slider_style.track_color } else { u32(0xe2e8f0) }
				value_color := if el.enabled {
					el.slider_style.value_track_color
				} else {
					u32(0x94a3b8)
				}
				thumb_color := if el.enabled { el.slider_style.thumb_color } else { u32(0x94a3b8) }
				if el.orientation == .vertical {
					inset := slider_track_padding(el.padding, frame.height)
					extent := frame.height - inset * 2
					track_x := frame.x + (frame.width - track_width) / 2
					track_y := frame.y + inset
					draw_rect(ctx, track_x, track_y, track_width, extent, track_color,
						track_width / 2)
					thumb_y := track_y + (1 - normalized) * extent
					if el.value_track {
						draw_rect(ctx, track_x, thumb_y, track_width, track_y + extent - thumb_y,
							value_color, track_width / 2)
					}
					draw_rect(ctx, frame.x + (frame.width - thumb_size) / 2,
						thumb_y - thumb_size / 2, thumb_size, thumb_size, thumb_color,
						thumb_size / 2)
				} else {
					inset := slider_track_padding(el.padding, frame.width)
					extent := frame.width - inset * 2
					track_x := frame.x + inset
					track_y := frame.y + (frame.height - track_width) / 2
					draw_rect(ctx, track_x, track_y, extent, track_width, track_color,
						track_width / 2)
					thumb_x := track_x + normalized * extent
					if el.value_track {
						draw_rect(ctx, track_x, track_y, thumb_x - track_x, track_width,
							value_color, track_width / 2)
					}
					draw_rect(ctx, thumb_x - thumb_size / 2,
						frame.y + (frame.height - thumb_size) / 2, thumb_size, thumb_size,
						thumb_color, thumb_size / 2)
				}
				if el.enabled {
					add_hit_target(HitTarget{
						id: el.id
						action_id: element_action_id(el)
						x: frame.x
						y: frame.y
						w: frame.width
						h: frame.height
						slider: true
						slider_frame: frame
						slider_padding: el.padding
						slider_spec: spec
					}, clip)
				}
			}
			.switch_control {
				frame := rect(el.frame.x + off_x, el.frame.y + off_y, el.frame.width,
					el.frame.height)
				mut active := el.checked
				if el.id.len > 0 {
					previous_declared := g_switch_declared[el.id] or { el.checked }
					previous_value := g_switch_values[el.id] or { el.checked }
					if el.id !in g_switch_values
						|| (previous_declared != el.checked && previous_value != el.checked) {
						g_switch_values[el.id] = el.checked
					}
					active = g_switch_values[el.id] or { el.checked }
					g_switch_declared[el.id] = el.checked
					g_active_switches[el.id] = true
				}
				track := switch_track_frame(frame)
				thumb := switch_thumb_frame(track, active)
				track_color := if el.enabled {
					if active {
						el.switch_style.active_track_color
					} else {
						el.switch_style.inactive_track_color
					}
				} else {
					el.switch_style.disabled_track_color
				}
				thumb_color := if el.enabled {
					el.switch_style.thumb_color
				} else {
					el.switch_style.disabled_thumb_color
				}
				draw_rect(ctx, track.x, track.y, track.width, track.height, track_color,
					track.height / 2)
				draw_rect(ctx, thumb.x, thumb.y, thumb.width, thumb.height, thumb_color,
					thumb.height / 2)
				if el.enabled {
					add_hit_target(HitTarget{
						id: el.id
						action_id: element_action_id(el)
						x: frame.x
						y: frame.y
						w: frame.width
						h: frame.height
						switch_control: true
						switch_state: active
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
		if !cache_image(path) { return false }
		image_id := g_image_ids[path] or { return false }
		mut image_ctx := g_gg_app.ctx
		cached_image := image_ctx.get_cached_image_by_idx(image_id)
		if !cached_image.ok {
			return false
		}
		ctx.draw_image_with_config(
			img: cached_image
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

	fn preload_images(el Element) {
		if el.hidden {
			return
		}
		if el.kind == .image {
			cache_image(el.image_path)
		}
		for child in el.children {
			preload_images(child)
		}
	}

	fn cache_image(path string) bool {
		if path.trim_space() == '' {
			return false
		}
		g_active_images[path] = true
		if path in g_image_ids {
			return true
		}
		mut image_ctx := g_gg_app.ctx
		loaded_image := image_ctx.create_image(path) or {
			eprintln('ui2: could not load image `${path}`: ${err}')
			return false
		}
		g_image_ids[path] = loaded_image.id
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

	fn draw_outline(ctx &gg.Context, x f64, y f64, w f64, h f64, color_hex u32, radius f64) {
		if w <= 0 || h <= 0 {
			return
		}
		c := hex_color(color_hex)
		if radius > 0 {
			ctx.draw_rounded_rect_empty(f32(x), f32(y), f32(w), f32(h), f32(radius), c)
		} else {
			ctx.draw_rect_empty(f32(x), f32(y), f32(w), f32(h), c)
		}
	}

	fn draw_box_borders(ctx &gg.Context, x f64, y f64, w f64, h f64, box BoxStyle) {
		left := box_border_width(box.border_left, w)
		top := box_border_width(box.border_top, h)
		right := box_border_width(box.border_right, w)
		bottom := box_border_width(box.border_bottom, h)
		if left > 0 {
			draw_rect(ctx, x, y, left, h, box.border_color, 0)
		}
		if top > 0 {
			draw_rect(ctx, x, y, w, top, box.border_color, 0)
		}
		if right > 0 {
			draw_rect(ctx, x + w - right, y, right, h, box.border_color, 0)
		}
		if bottom > 0 {
			draw_rect(ctx, x, y + h - bottom, w, bottom, box.border_color, 0)
		}
	}

	fn draw_control_surface(ctx &gg.Context, x f64, y f64, w f64, h f64, box BoxStyle, focused bool, enabled bool) {
		if box_draws_fill(box) {
			draw_rect(ctx, x, y, w, h, box.bg, box.radius)
		}
		border := if focused {
			u32(0x3478d4)
		} else if enabled {
			u32(0xd7dee8)
		} else {
			u32(0xe2e8f0)
		}
		draw_outline(ctx, x, y, w, h, border, box.radius)
		if focused && w > 2 && h > 2 {
			inner_radius := if box.radius > 1 { box.radius - 1 } else { 0.0 }
			draw_outline(ctx, x + 1, y + 1, w - 2, h - 2, border, inner_radius)
		}
		draw_box_borders(ctx, x, y, w, h, box)
	}

	// unstyled_box_bg is BoxStyle's default background: the button was left
	// the colour it was given rather than painted by the application.
	const unstyled_box_bg = u32(0xffffff)
	const button_bezel_radius = f64(6)

	// A button that asked for the platform's styling gets its bezel from
	// AppKit or Win32 on the native backends. The immediate renderer is the
	// platform in its own window, so it draws one itself; without it a
	// `native` button that was never painted is a bare caption, invisible on a
	// white card. A button the application did colour keeps that colour, since
	// the styling it asked the platform for stops where its own begins.
	fn draw_button_bezel(ctx &gg.Context, x f64, y f64, w f64, h f64, radius f64, enabled bool) {
		mut fill := u32(0xeef2f7)
		mut border := u32(0xb4bfcd)
		if !enabled {
			fill = 0xf6f8fa
			border = 0xdde4ec
		} else if touch_is_held_inside(x, y, w, h) {
			fill = 0xdbe3ec
			border = 0x94a3b8
		}
		bezel_radius := if radius > 0 { radius } else { button_bezel_radius }
		draw_rect(ctx, x, y, w, h, fill, bezel_radius)
		draw_outline(ctx, x, y, w, h, border, bezel_radius)
	}

	// touch_is_held_inside reports the pointer being down on this box, which
	// is what a pressed button looks like. The press has to have started there
	// too, so dragging across the window does not light up everything it
	// passes over.
	fn touch_is_held_inside(x f64, y f64, w f64, h f64) bool {
		if !g_touch.down {
			return false
		}
		inside_start := g_touch.start_x >= x && g_touch.start_x <= x + w && g_touch.start_y >= y
			&& g_touch.start_y <= y + h
		inside_now := g_touch.current_x >= x && g_touch.current_x <= x + w
			&& g_touch.current_y >= y && g_touch.current_y <= y + h
		return inside_start && inside_now
	}

	fn draw_check_mark(ctx &gg.Context, x f64, y f64, size f64, color_hex u32) {
		pen := gg.PenConfig{
			color: hex_color(color_hex)
			thickness: 2
		}
		ctx.draw_line_with_config(f32(x + size * 0.22), f32(y + size * 0.50),
			f32(x + size * 0.42), f32(y + size * 0.70), pen)
		ctx.draw_line_with_config(f32(x + size * 0.40), f32(y + size * 0.69),
			f32(x + size * 0.79), f32(y + size * 0.29), pen)
	}

	fn draw_chevron_down(ctx &gg.Context, center_x f64, center_y f64, color_hex u32) {
		pen := gg.PenConfig{
			color: hex_color(color_hex)
			thickness: 1.5
		}
		ctx.draw_line_with_config(f32(center_x - 4), f32(center_y - 2), f32(center_x),
			f32(center_y + 2), pen)
		ctx.draw_line_with_config(f32(center_x), f32(center_y + 2), f32(center_x + 4),
			f32(center_y - 2), pen)
	}

	fn draw_scrollbar(ctx &gg.Context, x f64, y f64, width f64, height f64, content_height f64, offset f64, persistent bool) {
		bar := scrollbar_geometry(rect(x, y, width, height), content_height, offset, persistent)
		if bar.track.width <= 0 || bar.track.height <= 0 {
			return
		}
		draw_rect(ctx, bar.track.x, bar.track.y, bar.track.width, bar.track.height, 0xf1f5f9, 2.5)
		draw_rect(ctx, bar.thumb.x, bar.thumb.y, bar.thumb.width, bar.thumb.height, 0xcbd5e1, 2.5)
	}

	// text_font_file resolves a declared family to the file fontstash has to
	// load. gg reads TextCfg.family as a path and, when it cannot read one,
	// returns without touching the font state at all, leaving the string drawn
	// in whatever the previous element used. An unknown family therefore has to
	// come back empty so the default font is used instead.
	fn text_font_file(family string, bold bool, italic bool) string {
		if family.len == 0 {
			return ''
		}
		key := '${family}:${bold}:${italic}'
		if path := g_font_family_files[key] {
			return path
		}
		mut path := ''
		if os.is_file(family) {
			path = family
		} else {
			if !g_font_indexed {
				mut dirs := font_bundle_dirs()
				dirs << font_system_dirs()
				g_font_files = font_index(dirs)
				g_font_indexed = true
			}
			path = font_lookup(g_font_files, family, bold, italic)
			if path.len == 0 && (bold || italic) {
				// A family with no bold or italic file of its own still reads
				// better in its regular weight than in the default font.
				path = font_lookup(g_font_files, family, false, false)
			}
			if path.len == 0 && font_is_mono_family(family) {
				// Falling back to the proportional default would break the
				// column alignment the element asked for in the first place.
				path = font_mono_path(g_font_files, family, bold, italic)
			}
		}
		g_font_family_files[key] = path
		return path
	}

	// ensure_symbol_fallbacks hands fontstash the faces to look in when the font
	// a string is drawn in has no outline for one of its code points. fontstash
	// walks a font's fallback list whenever a glyph lookup lands on index 0 —
	// the empty box, or tofu — and rasterizes the first face that does have the
	// code point, so a label mixing letters and symbols is still drawn in one
	// pass and measured exactly the way it is drawn.
	//
	// The ids belong to the fontstash context gg loaded its fonts into. Sokol
	// builds a new one whenever the window is recreated, on an Android resume
	// among others, so the loaded faces are tracked against the context they
	// came from rather than behind a flag that a new context would not clear.
	fn ensure_symbol_fallbacks(ctx &gg.Context) {
		if !ctx.font_inited || ctx.ft == unsafe { nil } || ctx.ft.fons == unsafe { nil } {
			return
		}
		fons := ctx.ft.fons
		if g_font_symbol_fons != voidptr(fons) {
			g_font_symbol_fons = voidptr(fons)
			g_text_area_layouts = map[string]TextAreaLayout{}
			g_font_symbol_ids = []int{}
			g_font_symbol_bases = map[int]bool{}
			for path in font_symbol_paths() {
				bytes := os.read_bytes(path) or { continue }
				id := fons.add_font_mem(path, bytes, true)
				if id != fontstash.invalid {
					g_font_symbol_ids << id
				}
			}
		}
		for base in [ctx.ft.font_normal, ctx.ft.font_bold, ctx.ft.font_mono, ctx.ft.font_italic] {
			add_symbol_fallbacks(fons, base)
		}
	}

	// add_symbol_fallbacks attaches the chain to one font, once. fontstash gives
	// a font a fixed number of fallback slots and appends to them blindly, so
	// registering the same face twice would spend them for nothing.
	fn add_symbol_fallbacks(fons &fontstash.Context, base int) {
		if base == fontstash.invalid || g_font_symbol_ids.len == 0 || base in g_font_symbol_bases {
			return
		}
		g_font_symbol_bases[base] = true
		for id in g_font_symbol_ids {
			if id != base {
				fons.add_fallback_font(base, id)
			}
		}
	}

	// ensure_family_fallbacks gives a face named by TextStyle.font_family the
	// same chain. gg loads such a file itself, on the first draw that asks for
	// it, and keeps the id in a map of its own; loading it here first puts the
	// id in that map before any glyph is rasterized from it, which is the only
	// moment the fallbacks can still be attached.
	fn ensure_family_fallbacks(ctx &gg.Context, path string) {
		if path.len == 0 || g_font_symbol_ids.len == 0 || !ctx.font_inited {
			return
		}
		mut id := ctx.ft.fonts_map[path]
		if id == 0 {
			bytes := os.read_bytes(path) or { return }
			id = ctx.ft.fons.add_font_mem(path, bytes, true)
			if id == fontstash.invalid {
				return
			}
			unsafe {
				ctx.ft.fonts_map[path] = id
			}
		}
		add_symbol_fallbacks(ctx.ft.fons, id)
	}

	// text_font_metrics reports the metrics to size a string with: the chosen
	// family's own, or the window font's when the element declared none.
	fn text_font_metrics(path string) FontMetrics {
		if path.len == 0 {
			return g_font_metrics
		}
		if metrics := g_font_family_metrics[path] {
			return metrics
		}
		metrics := font_file_metrics(path) or { g_font_metrics }
		g_font_family_metrics[path] = metrics
		return metrics
	}

	fn text_align(a Align) gg.HorizontalAlign {
		return match a {
			.left { .left }
			.center { .center }
			.right { .right }
		}
	}

	// text_ellipsis marks a line the renderer had to shorten. AppKit's cells
	// truncate with this glyph too, and the bundled Roboto always has it.
	const text_ellipsis = '\u2026'

	// fit_text shortens a line that is wider than the box it was given. Both
	// native backends hand their labels NSLineBreakByTruncatingTail, so a long
	// string ends in an ellipsis there; the immediate renderer draws straight
	// into the window and would otherwise run the tail over its neighbours and
	// off the window edge.
	fn fit_text(ctx &gg.Context, t string, w f64, cfg gg.TextCfg) string {
		if w <= 0 {
			return t
		}
		ctx.set_text_cfg(cfg)
		return fit_text_to_width(t, w, fn [ctx] (line string) f64 {
			return f64(ctx.text_width_f(line))
		})
	}

	// fit_text_to_width is the search fit_text runs. It takes the measurement
	// as an argument so it can be tested without a window to measure in.
	fn fit_text_to_width(t string, w f64, text_width fn (string) f64) string {
		if text_width(t) <= w {
			return t
		}
		runes := t.runes()
		// The longest head that still fits, found by halving rather than by
		// dropping one rune at a time, so a long line costs a handful of
		// measurements instead of one per character.
		mut kept := 0
		mut high := runes.len
		for kept < high {
			mid := (kept + high + 1) / 2
			if text_width(runes[..mid].string() + text_ellipsis) <= w {
				kept = mid
			} else {
				high = mid - 1
			}
		}
		return runes[..kept].string() + text_ellipsis
	}

	// draw_text draws text that belongs to a box, shortening it when it does
	// not fit.
	fn draw_text(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle) {
		draw_text_in_box(ctx, t, x, y, w, h, style, true)
	}

	// draw_editable_text draws the text of a field the caller can type in.
	// Those controls place the caret by measuring the whole string, so a
	// shortened line would leave the caret sitting past the end of it.
	fn draw_editable_text(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle) {
		draw_text_in_box(ctx, t, x, y, w, h, style, false)
	}

	fn draw_text_in_box(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle, fit bool) {
		if t.len == 0 {
			return
		}
		text_x := match style.align {
			.left { int(x) }
			.center { int(x + w / 2) }
			.right { int(x + w) }
		}

		text_y := int(y + h / 2)
		family := text_font_file(style.font_family, style.bold, style.italic)
		ensure_family_fallbacks(ctx, family)
		cfg := gg.TextCfg{
			color: hex_color(style.color)
			size: int(font_render_size(style.size, text_font_metrics(family)) + 0.5)
			bold: style.bold
			italic: style.italic
			family: family
			align: text_align(style.align)
			vertical_align: .middle
		}
		if style.lines > 1 && t.contains('\n') {
			parts := t.split('\n')
			line_h := font_line_height(style.size)
			total_h := f64(parts.len) * line_h
			start_y := y + (h - total_h) / 2 + line_h / 2
			for i, part in parts {
				if i >= style.lines {
					break
				}
				line := if fit { fit_text(ctx, part, w, cfg) } else { part }
				ctx.draw_text(int(text_x), int(start_y + f64(i) * line_h), line, cfg)
			}
		} else {
			ctx.draw_text(text_x, text_y, if fit { fit_text(ctx, t, w, cfg) } else { t },
				cfg)
		}
	}

	fn draw_text_centered(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle) {
		centered_style := TextStyle{
			...style
			align: .center
		}
		draw_text(ctx, t, x, y, w, h, centered_style)
	}
}
