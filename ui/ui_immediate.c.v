// vfmt off
// Keep the imports inside the platform block. Hoisting gg imports makes the
// AppKit backend compile Sokol's ARC sources together with Objective-C MRC.
@[has_globals]
module ui2

$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import clipboard
	import fontstash
	import gg
	import math
	import os
	import sokol.gfx
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
		checkbox       bool
		checkbox_state bool
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
		clickable      bool
		button_behavior bool
		draggable      bool
	}

	struct TouchState {
	mut:
		// A rebuild can move a dragged view away from the initial press.
		// Keep its event identity until release instead of hit-testing it again.
		pointer_target     HitTarget
		// A slider owns its gesture through commit_slider, which returns before
		// any pointer_target capture is taken. Recording its id here gives the
		// same protection from the other side: an external write racing the drag
		// must not overwrite the value the pointer is holding.
		slider_drag_id     string
		down               bool
		start_x            f64
		start_y            f64
		current_x          f64
		current_y          f64
		start_time         i64
		moved              bool
		scroll_id          string
		scroll_chain       []string
		long_press_fired   bool
		scrollbar_drag     bool
		scrollbar_grab_y   f64
		// Which scroller a scrollbar drag holds: the one along the bottom when set.
		scrollbar_horizontal bool
		scrollbar_grab_x     f64
	}

	// GlSurfaceTexture wraps a GL texture the application renders into, as a sokol
	// image, so an `opengl` element is an ordinary textured quad in the UI's pass.
	struct GlSurfaceTexture {
		gl_texture u32
		width      int
		height     int
		image      gfx.Image
		sampler    gfx.Sampler
	}

	struct GgApp {
	mut:
		ctx &gg.Context = unsafe { nil }
		scheduler &FrameCoordinator = new_frame_coordinator()
		declared_root Element
		has_root bool
		iconified bool
		suspended bool
		dpi_scale f32
		draining_tasks bool
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

	// TooltipTarget is a region of the window with hover text: an element's
	// declared tooltip, or the full text of a line the renderer had to shorten
	// to fit it. A target without text is an opaque surface drawn over earlier
	// targets, which hides their tooltips just as it hides the targets.
	struct TooltipTarget {
		// key tells the pointer resting on one target apart from moving on to
		// another, across frames that rebuild every target from scratch.
		key   string
		text  string
		frame Rect
	}

	// TooltipState follows the pointer. Its cancelable deadline belongs to the
	// window coordinator, so a stationary pointer also works in on-demand mode.
	struct TooltipState {
	mut:
		pointer_x  f64
		pointer_y  f64
		pointer_in bool
		key        string
		rest_since i64
		// dismissed is a tooltip closed by a click or a key press. It stays
		// closed until the pointer reaches another target, so it does not pop
		// back up over what the user is now doing with this one.
		dismissed  bool
		visible    bool
		anchor_x   f64
		anchor_y   f64
		text       string
	}

	const tooltip_delay_ms = i64(500)
	const tooltip_offset_x = 12.0
	const tooltip_offset_y = 20.0
	const tooltip_gap = 6.0
	const tooltip_margin = 4.0
	const tooltip_padding = 6.0
	const tooltip_radius = 4.0
	const tooltip_text_size = 12.0
	const tooltip_max_text_width = 360.0
	const tooltip_max_lines = 12
	const tooltip_background = u32(0xfffff0)
	const tooltip_border = u32(0x94a3b8)
	const tooltip_shadow = u32(0xdbe2ea)
	const tooltip_text_color = u32(0x1f2937)

	__global g_build_screen = BuildFn(unsafe { nil })
	__global g_event_handler = EventFn(unsafe { nil })
	__global g_key_handler = KeyFn(unsafe { nil })
	__global g_key_event_handler = KeyEventFn(unsafe { nil })
	__global g_scroll_handler = ScrollFn(unsafe { nil })
	__global g_drop_handler = DropFn(unsafe { nil })
	__global g_window_ready_handler = WindowReadyFn(unsafe { nil })
	__global g_window_resize_handler = WindowResizeFn(unsafe { nil })
	__global g_key_consumed = false
	__global g_gg_app = &GgApp{}
	__global g_refresh_mode = RefreshMode.on_demand
	__global g_last_frame_ticks = i64(0)
	// The UI scale pin (set_scale_override): 0 follows the platform's own.
	__global g_scale_override = 0.0
	// WindowOptions.background's memory: hidden windows keep running their
	// frames instead of suspending.
	__global g_background_work = false
	// Reused by the rounded-corner drawing, so a frame's controls allocate no points.
	__global g_outline_points = []f64{}
	__global g_outline_outer = []f64{}
	__global g_outline_inner = []f64{}
	__global g_present_on_demand = false
	__global g_text_values = map[string]string{}
	__global g_clipboard = &clipboard.Clipboard(unsafe { nil })
	__global g_clipboard_override = ?TextClipboard(none)
	__global g_text_props = map[string]string{}
	__global g_text_editors = map[string]TextEditor{}
	__global g_text_kinds = map[string]Kind{}
	__global g_text_secure = map[string]bool{}
	__global g_slider_values = map[string]f64{}
	__global g_slider_declared = map[string]f64{}
	__global g_slider_specs = map[string]SliderSpec{}
	__global g_switch_values = map[string]bool{}
	__global g_switch_declared = map[string]bool{}
	__global g_checkbox_values = map[string]bool{}
	__global g_checkbox_declared = map[string]bool{}
	__global g_toggle_values = map[string]bool{}
	__global g_toggle_declared = map[string]bool{}
	__global g_toggle_groups = map[string]string{}
	__global g_toggle_allow_no_selection = map[string]bool{}
	__global g_focused_field = ''
	__global g_scroll_offsets = map[string]f64{}
	__global g_scroll_content_h = map[string]f64{}
	__global g_hit_targets = []HitTarget{}
	// The modifier keys of the last event sokol delivered, for key_modifiers on
	// platforms with no other way to ask.
	__global g_key_modifiers = KeyModifiers{}

	// HoverRegion is the visible part of an element drawn this frame and the
	// hoverable elements it belongs to, from the outermost in. The last region
	// under the pointer is the topmost element there, so its chain is what the
	// pointer hovers.
	struct HoverRegion {
		area  Rect
		chain []string
	}

	__global g_hover_regions = []HoverRegion{}
	__global g_hover_chain = []string{}
	__global g_hovered = []string{}
	__global g_hover_pointer = HoverPointer{}

	struct HoverPointer {
	mut:
		x      f64
		y      f64
		inside bool
	}
	__global g_touch = TouchState{}
	__global g_scroll_areas = map[string]Rect{}
	__global g_active_fields = map[string]bool{}
	__global g_active_sliders = map[string]bool{}
	__global g_active_switches = map[string]bool{}
	__global g_active_checkboxes = map[string]bool{}
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
	__global g_opengl_surface_frames = map[string]Rect{}
	__global g_gl_surface_textures = map[string]GlSurfaceTexture{}
	__global g_open_dropdown = ''
	__global g_dropdown_popup = DropdownPopup{}
	__global g_dropdown_hover = -1
	__global g_dropdown_scroll = 0.0
	__global g_tooltip_targets = []TooltipTarget{}
	__global g_tooltip = TooltipState{}
	// g_tooltip_owners counts the elements being rendered that declared a
	// tooltip. Their tooltip covers their descendants too, so a surface drawn
	// inside one must not hide it the way an unrelated overlay would.
	__global g_tooltip_owners = 0

	// Map values are copied byte-for-byte when an existing key is replaced.
	// Unlike keys, their nested strings are not released by map.set. The text
	// state below changes on every keystroke, so it owns clones explicitly and
	// disposes the previous value before overwriting it.
	@[manualfree]
	fn free_owned_string(value string) {
		unsafe { value.free() }
	}

	@[manualfree]
	fn replace_text_value(id string, value string) {
		owned := value.clone()
		if previous := g_text_values[id] {
			free_owned_string(previous)
		}
		g_text_values[id] = owned
	}

	@[manualfree]
	fn replace_text_prop(id string, value string) {
		owned := value.clone()
		if previous := g_text_props[id] {
			free_owned_string(previous)
		}
		g_text_props[id] = owned
	}

	@[manualfree]
	fn replace_text_editor(id string, editor TextEditor) {
		if previous := g_text_editors[id] {
			// Caret-only updates retain the editor's text allocation. Releasing
			// it in that case would leave the replacement editor pointing at
			// freed memory.
			if previous.text.str != editor.text.str {
				free_owned_string(previous.text)
			}
		}
		g_text_editors[id] = editor
	}

	@[manualfree]
	fn forget_text_state(id string) {
		if value := g_text_values[id] {
			free_owned_string(value)
		}
		if prop := g_text_props[id] {
			free_owned_string(prop)
		}
		if editor := g_text_editors[id] {
			free_owned_string(editor.text)
		}
		g_text_values.delete(id)
		g_text_props.delete(id)
		g_text_editors.delete(id)
		g_text_kinds.delete(id)
		g_text_secure.delete(id)
	}

	// ── Public API ─────────────────────────────────────────────────────

	pub fn bounds() Rect {
		if g_gg_app.ctx == unsafe { nil } {
			$if linux || freebsd || openbsd || netbsd || dragonfly || solaris || macos || windows {
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
		ctx := g_gg_app.ctx
		return Rect{
			width: layout_window_width(ctx)
			height: layout_window_height(ctx) - menu_bar_height()
		}
	}

	// gg keeps window dimensions as whole logical pixels. Dividing the
	// framebuffer by a fractional scale can produce a fractional layout size;
	// using ctx.width/height loses the remainder and leaves a physical edge
	// outside full-window elements and clips.
	fn layout_window_width(ctx &gg.Context) f64 {
		s := f64(ctx.scale)
		return if s > 0 { f64(sapp.width()) / s } else { f64(sapp.width()) }
	}

	fn layout_window_height(ctx &gg.Context) f64 {
		s := f64(ctx.scale)
		return if s > 0 { f64(sapp.height()) / s } else { f64(sapp.height()) }
	}

	// scale is the factor between framebuffer pixels and layout pixels: framebuffer
	// pixels divide by it to become layout pixels, the conversion between sapp's
	// pixel height and bounds()'s layout rect. It is the gg context's scale, which
	// is the DPI scale on desktop and the fit of the design size to the
	// framebuffer on Android, where sapp's own DPI scale is always 1. The two
	// agree at scale 1.
	pub fn scale() f64 {
		if g_scale_override > 0 {
			return g_scale_override
		}
		if g_gg_app.ctx != unsafe { nil } {
			return f64(g_gg_app.ctx.scale)
		}
		return f64(sapp.dpi_scale())
	}

	// apply_scale_override pins the gg context to the override's scale. gg
	// rewrites ctx.scale from the platform's DPI on window events, so this
	// re-runs on every event batch (on_event), on resize and once after the
	// context is created.
	fn apply_scale_override() {
		if g_scale_override <= 0 {
			return
		}
		mut ctx := g_gg_app.ctx
		if ctx == unsafe { nil } {
			return
		}
		ctx.scale = f32(g_scale_override)
		if ctx.font_inited {
			ctx.ft.scale = ctx.scale
		}
	}

	// set_scale_override pins the layout scale for the whole window: the
	// platform's own DPI is ignored while the value is above 0, and 0 returns
	// to following it. The video surface scales with the chrome; surfaces
	// rendered at the framebuffer's own resolution are unaffected.
	pub fn set_scale_override(s f64) {
		if s == g_scale_override {
			return
		}
		g_scale_override = s
		apply_scale_override()
		if g_gg_app.ctx != unsafe { nil } {
			g_gg_app.scheduler.invalidate(.surface)
		}
	}

	pub fn run(build_fn BuildFn, event_fn EventFn) {
		$if linux || freebsd || openbsd || netbsd || dragonfly || solaris || macos || windows {
			run_window('App', 800, 600, build_fn, event_fn)
		} $else {
			run_window('App', 400, 800, build_fn, event_fn)
		}
	}

	pub fn run_window(title string, width int, height int, build_fn BuildFn, event_fn EventFn) {
		run_window_with_min_size(title, width, height, 0, 0, build_fn, event_fn)
	}

	fn run_window_with_min_size(title string, width int, height int, min_width int, min_height int, build_fn BuildFn, event_fn EventFn) {
		run_window_with_options(WindowOptions{
			title:      title
			width:      width
			height:     height
			min_width:  min_width
			min_height: min_height
		}, build_fn, event_fn)
	}

// RefreshMode selects how a window decides to redraw.
//
// continuous rebuilds and repaints on every vsync, which is what the
// immediate backend has always done: anything can change between frames, so
// nothing has to remember to ask for a repaint.
//
// on_demand rebuilds only when something asks: window and input events, `after`
// timers, running animations, and application calls to request_refresh from
// its own threads. Between those the frame callback draws nothing, Sokol still
// throttles itself to the display, and the window idles at a fraction of the
// continuous cost. An application whose frames come from outside the window —
// a video surface fed by a player, for example — calls request_refresh from
// the player thread whenever new content is ready.
//
// manual suppresses the frame callback between explicit asks, like on_demand
// did before the frame scheduler took over: refresh and request_refresh wake
// the loop for exactly one coalesced frame, deadlines and running animations
// wake their own continuation, and nothing else draws — no per-vsync present,
// no keep-alive redraw.
	pub enum RefreshMode {
	continuous
	on_demand
	manual
	}

// WindowOptions carries the window creation knobs run_window_with_options
// accepts on top of what run_window takes positionally. gl_load scopes which
// EGL vendor libraries glvnd may load before the window's GL context
// initializes (Linux only; see GlLoad), and UI2_GL_VENDOR overrides it
// without a recompile.
	pub struct WindowOptions {
	pub:
		title      string
		width      int
		height     int
		min_width  int
		min_height int
	// sample_count is Sokol's antialiasing level for the window's framebuffer.
	// Flat immediate-mode geometry gains nothing visible from 4x, and weak GPUs
	// pay the fill rate for it; 1 turns antialiasing off.
		sample_count int = 4
		refresh    RefreshMode = .on_demand
		gl_load    GlLoad = .auto
	// background keeps the window's frames running while the window is
	// hidden — iconified, minimized, or parked on another workspace — instead
	// of suspending the frame coordinator. Nothing is presented while hidden;
	// the frames exist so the application keeps its own machinery fed: a
	// custom renderer whose surface is drained inside the frame (a video
	// player's mpv render call, say) must keep consuming frames, or the
	// source stalls and playback stops the moment the window is hidden.
	// Windows that only show UI pay nothing for this — leave it off and a
	// hidden window suspends, as before.
		background bool
	}

// run_window_with_options opens the window with per-application control over
// the antialiasing level, the refresh mode and the GL vendor scope.
// run_window and run default the custom renderer to on_demand, where the
// frame scheduler coalesces asks and leaves the retained tree untouched while
// nothing is pending; set refresh: .continuous to restore the historical
// per-vsync rebuild loop. The GL scope is applied before sokol can open its
// display: glvnd reads the vendor list at the first EGL call, and once a
// vendor's userspace stack is mapped the memory is spent for the lifetime of
// the process.
	pub fn run_window_with_options(opts WindowOptions, build_fn BuildFn, event_fn EventFn) {
		configure_gl_libraries(opts.gl_load)
		// A dispatcher retained by an old worker stays attached to its closed window.
		if g_gg_app.scheduler.is_closed() {
			g_gg_app = &GgApp{}
		}
		g_refresh_mode = opts.refresh
		g_background_work = opts.background
		// In manual mode gg suppresses the frame callback between asks, so the
		// scheduler's wake hook revives it whenever new work, a running
		// animation or an expired deadline needs a frame.
		g_gg_app.scheduler.set_wake_fn(wake_ui_loop)
		g_build_screen = build_fn
		g_event_handler = event_fn
		// In on_demand mode the loop sleeps between asks, so a running
		// animation drives it from a thread: each tick asks for a frame until
		// every animation has crossed its deadline. The continuous loop draws
		// anyway and needs no driver thread.
		configure_animation_driver(request_refresh, opts.refresh == .on_demand)
		publish_menu_context(event_fn, opts.title, unsafe { nil })
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
			width: opts.width
			height: opts.height
			min_width: opts.min_width
			min_height: opts.min_height
			sample_count: opts.sample_count
			// Manual mode suppresses the frame callback between asks; the
			// scheduler's wake hook revives it. The other modes keep the
			// callback flowing and gate builds/draws in the coordinator —
			// gg's ui_mode would suppress it before it can drain worker
			// messages or deadlines, and refresh_ui is not thread safe.
			ui_mode: opts.refresh == .manual
			create_window: true
			window_title: opts.title
			user_data: unsafe { voidptr(g_gg_app) }
			init_fn: on_init
			cleanup_fn: on_cleanup
			frame_fn: on_frame
			event_fn: on_event
			enable_dragndrop: true
			max_dropped_files: 32
			max_dropped_file_path_length: 4096
		)
		if opts.refresh == .on_demand {
			spawn idle_keepalive_waker()
		}
		apply_scale_override()
		g_gg_app.ctx.run()
	}

// idle_keepalive_waker redraws an idle on_demand window at a slow fixed
// rate. Every normal trigger — events, timers, animations, the application's
// threads — asks for a redraw itself; this thread is for the ones that cannot
// ask. On X11, sokol selects no Expose handling, so when a region of the window
// becomes visible again nothing tells the loop, and with no compositor the
// old pixels stay on screen. A repaint about every ten seconds bounds how long
// any surprise persists. It repaints the retained tree without rebuilding it:
// an idle window has nothing new to build.
	// The keep-alive checks the clock every idle_keepalive_check_ms and repaints once the
	// last presented frame is idle_keepalive_period_ms old.
	const idle_keepalive_check_ms = 5000
	const idle_keepalive_period_ms = 10000

	fn idle_keepalive_waker() {
		for {
			time.sleep(idle_keepalive_check_ms * time.millisecond)
			// Frames flowing for another reason keep g_last_frame_ticks fresh;
			// stepping over those intervals keeps the keep-alive from adding
			// work on top of live traffic.
			if time.ticks() - g_last_frame_ticks < idle_keepalive_period_ms {
				continue
			}
			invalidate_custom_paint()
		}
	}

	pub fn render_stats() RenderStats {
		return g_gg_app.scheduler.stats()
	}

	// Capture this handle on the UI thread. Workers post model mutations through
	// it instead of touching controls, gg, or a shared model themselves.
	pub fn ui_dispatcher() UiDispatcher {
		return UiDispatcher{coordinator: g_gg_app.scheduler}
	}

// wake_ui_loop hands gg's context a redraw ask and interrupts the loop's
// sleep. refresh_ui alone would leave the frame waiting for the loop's next
// deadline — with the deadline hook installed that can be never, since an
// idle window reports no deadline and no X event is coming. sapp_wake is a
// nonblocking pipe write, so it stays safe under the coordinator mutex.
	fn wake_ui_loop() {
		if g_gg_app.ctx == unsafe { nil } {
			return
		}
		g_gg_app.ctx.refresh_ui()
		C.sapp_wake()
	}

// refresh asks for a rebuild over whatever the application changed outside a
// frame. In on_demand mode the scheduler turns the ask into exactly one
// coalesced frame; the continuous loop was already drawing regardless.
	pub fn refresh() {
		g_gg_app.scheduler.invalidate(.build)
	}

// request_refresh asks for one more rebuild over whatever state the
// application changed off the UI thread — new video frames, worker-thread
// results. The scheduler's queue is mutex guarded, so unlike a refresh_ui
// flip this is safe to call from any thread.
	pub fn request_refresh() {
		g_gg_app.scheduler.invalidate(.build)
	}

// request_paint asks for one redraw of the retained element tree without
// rebuilding it: state that a build does not read — a custom renderer's
// surface contents, a live slider value — is presentable with it. Like
// request_refresh it is safe from any thread.
	pub fn request_paint() {
		g_gg_app.scheduler.invalidate(.paint)
	}

// refresh_on_demand reports whether the window redraws only when asked. It
// lets an application skip scheduling wake timers whose only job is a redraw
// ask: in continuous mode the loop reaches every state change within a frame
// anyway.
	pub fn refresh_on_demand() bool {
		return g_refresh_mode == .on_demand
	}

// set_refresh_mode switches the window's redraw policy after the window is
// up: continuous repaints the retained tree every vsync under sokol's own
// pacing, on_demand returns to strictly asked redraws where the X11 loop
// sleeps between asks. Everything init keyed to the mode is re-keyed here:
// sokol honors both present-on-demand and the deadline hook between loop
// iterations, and the animation driver follows the mode like at init. It
// must run on the UI thread, where the menu handlers live.
	pub fn set_refresh_mode(mode RefreshMode) {
		if mode == g_refresh_mode {
			return
		}
		g_refresh_mode = mode
		$if gg_record ? {
		} $else $if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
			// These run sokol's X11 loop, where the hooks below exist; the
			// patched sokol_app.h compiles them for any __unix__ target.
			if mode != .continuous {
				g_present_on_demand = C.sapp_set_present_on_demand(true)
				C.sapp_set_frame_deadline_cb(ui2_frame_deadline_cb)
			} else {
				// Continuous keeps sokol's stock pacing: the deadline hook
				// steps aside and present-on-demand stops gating the swap.
				C.sapp_set_present_on_demand(false)
				g_present_on_demand = false
				C.sapp_set_frame_deadline_cb(unsafe { nil })
			}
		}
		// A reference field of an immutable pointer cannot be popped through to
		// a mut method on V 0.5.2; bind it through a mutable local instead.
		mut scheduler := g_gg_app.scheduler
		scheduler.set_presentation_required(gfx.query_backend() != .metal_macos
			&& !g_present_on_demand)
		configure_animation_driver(request_refresh, mode == .on_demand)
		refresh()
	}

	pub fn refresh_element(_id string, _element Element) {
		refresh()
	}

	fn invalidate_custom_paint() {
		g_gg_app.scheduler.invalidate(.paint)
	}

	fn renderer_now_ms() i64 {
		return i64(time.sys_mono_now() / u64(time.millisecond))
	}

	pub fn on_key(handler KeyFn) {
		g_key_handler = handler
	}

	pub fn on_key_event(handler KeyEventFn) {
		g_key_event_handler = handler
	}

	pub fn on_scroll(handler ScrollFn) {
		g_scroll_handler = handler
	}

	pub fn on_drop(handler DropFn) {
		g_drop_handler = handler
	}

	// on_window_ready registers a handler called with nil inside gg's init
	// callback, after the screen has been built once and before the frame
	// loop. Embedding is not supported on the gg backends (custom renderer,
	// and Linux which shares this file), so the nil keeps embedder code
	// uniform across backends.
	pub fn on_window_ready(handler WindowReadyFn) {
		g_window_ready_handler = handler
	}

	// custom_fire_window_ready notifies the embedder registered through
	// on_window_ready, if any.
	fn custom_fire_window_ready() {
		if voidptr(g_window_ready_handler) == unsafe { nil } {
			return
		}
		g_window_ready_handler(unsafe { nil })
	}

	// on_window_resize only stores the handler: a documented no-op. The
	// immediate renderer backends (Linux, Android, and the custom renderer on
	// every platform) have no native child to resize — but accepting the
	// registration keeps embedder code uniform across backends.
	pub fn on_window_resize(handler WindowResizeFn) {
		g_window_resize_handler = handler
	}

	pub fn text(id string) string {
		// State maps store owned strings so that replacing their values can
		// release the previous allocation. Callers, in particular QML bindings,
		// may retain the returned value after the next edit, so give them their
		// own copy rather than exposing the map's storage.
		return (g_text_values[id] or { '' }).clone()
	}

	pub fn set_text(id string, t string) {
		if id !in g_active_fields {
			return
		}
		replace_text_value(id, t)
		mut editor := g_text_editors[id] or { text_editor(t.clone()) }
		editor.set_text(t.clone())
		replace_text_editor(id, editor)
		invalidate_custom_paint()
	}

	// slider_value returns the live value currently displayed by a mounted
	// slider, including a value changed by pointer input before the next build.
	pub fn slider_value(id string) f64 {
		return g_slider_values[id] or { 0 }
	}

	// slider_live_value merges a slider's freshly declared value with the live
	// state a previous build or an input gesture left behind. When the pointer
	// holds the slider, the gesture's value wins: the tree was built from
	// playback state that races the finger, and adopting the declaration would
	// snap the thumb back under it. When nothing holds it, a declared change
	// wins over a stale live value, and otherwise the live value is kept so
	// external writes survive between rebuilds.
	fn slider_live_value(id string, declared f64, spec SliderSpec) f64 {
		mut previous_value := g_slider_values[id] or { declared }
		if id == g_touch.slider_drag_id {
			return previous_value
		}
		previous_declared := g_slider_declared[id] or { declared }
		if id !in g_slider_values || (previous_declared != declared && previous_value != declared) {
			previous_value = declared
		}
		current := slider_clamped_value(previous_value, spec.min, spec.max)
		g_slider_values[id] = current
		return current
	}

	pub fn set_slider_value(id string, value f64) {
		if id !in g_active_sliders {
			return
		}
		spec := g_slider_specs[id] or { return }
		if id == g_touch.slider_drag_id {
			// A pointer holds this slider: it re-commits per move, and an
			// external write now would overwrite the value the pointer chose.
			return
		}
		g_slider_values[id] = slider_clamped_value(value, spec.min, spec.max)
		invalidate_custom_paint()
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
		invalidate_custom_paint()
	}

	// checkbox_checked returns the live value currently displayed by a mounted
	// checkbox, including a value changed by pointer input before the next build.
	fn checkbox_checked(id string) bool {
		return g_checkbox_values[id] or { false }
	}

	fn set_checkbox_checked(id string, checked bool) {
		if id !in g_active_checkboxes {
			return
		}
		g_checkbox_values[id] = checked
		invalidate_custom_paint()
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
		invalidate_custom_paint()
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
		mut editor := g_text_editors[id] or { text_editor((g_text_values[id] or { '' }).clone()) }
		editor.set_caret(rune_len(editor.text))
		replace_text_editor(id, editor)
		invalidate_custom_paint()
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
		invalidate_custom_paint()
	}

	pub fn quit() {
		if g_gg_app.scheduler.is_closed() {
			return
		}
		g_gg_app.scheduler.close()
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
		mut editor := g_text_editors[id] or { text_editor((g_text_values[id] or { '' }).clone()) }
		editor.insert_text(value)
		replace_text_value(id, editor.text)
		replace_text_editor(id, editor)
		fire_field_change(id)
		invalidate_custom_paint()
	}

	pub fn scroll_offset(id string) f64 {
		return g_scroll_offsets[id] or { 0.0 }
	}

	// scroll_to_offset puts a Scroll element at the given vertical offset. Before the
	// element has been laid out its range is not known yet, so the offset is stored as
	// asked and register_scroll_view clamps it to the real range on the next frame.
	// That is what lets a screen open where it was last left.
	pub fn scroll_to_offset(id string, offset f64) {
		if id.len == 0 {
			return
		}
		wanted := if offset < 0 { 0.0 } else { offset }
		if id in g_scroll_viewports {
			set_scroll_offset(id, wanted, scroll_maximum(id))
			return
		}
		// The view does not exist yet, so its range is unknown and the offset cannot be
		// stored as a live position: the next frame rendered without the view would
		// prune it. Hold the request until the view registers and can clamp it.
		g_pending_scroll[id] = wanted
		invalidate_custom_paint()
	}

	// scroll_horizontal_offset returns how far a Scroll element is scrolled sideways.
	// It stays zero for one whose scroll_mode leaves the horizontal axis out.
	pub fn scroll_horizontal_offset(id string) f64 {
		return g_scroll_offsets_x[id] or { 0.0 }
	}

	// scroll_to_horizontal_offset is scroll_to_offset for the sideways axis, with the
	// same promise: an offset asked for before the element is laid out is kept and
	// clamped once its range is known. An offset past the end of an element already on
	// screen is kept as well, since the frame that lays out a column added by the
	// event being handled has not been drawn yet.
	pub fn scroll_to_horizontal_offset(id string, offset f64) {
		if id.len == 0 {
			return
		}
		wanted := if offset < 0 { 0.0 } else { offset }
		g_pending_scroll_x.delete(id)
		if id in g_scroll_viewports {
			maximum := scroll_maximum_x(id)
			set_scroll_offset_x(id, wanted, maximum)
			if wanted <= maximum {
				return
			}
		}
		g_pending_scroll_x[id] = wanted
		invalidate_custom_paint()
	}

	pub fn scroll_to_rect(id string, x f64, y f64, width f64, height f64) {
		area := g_scroll_viewports[id] or { return }
		current := scroll_offset(id)
		mut next := current
		if y < current {
			next = y
		} else if y + height > current + area.height {
			next = y + height - area.height
		}
		set_scroll_offset(id, next, scroll_maximum(id))
		// A pane with no sideways range clamps this to where it already is.
		current_x := scroll_horizontal_offset(id)
		mut next_x := current_x
		if x < current_x {
			next_x = x
		} else if x + width > current_x + area.width {
			next_x = x + width - area.width
		}
		set_scroll_offset_x(id, next_x, scroll_maximum_x(id))
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

	fn C.sapp_set_present_on_demand(enabled bool) bool
	fn C.sapp_request_present()
	// The X11 loop's deadline hook: before each sleep sokol asks this function
	// how long it may wait. A negative return means nothing is scheduled, so
	// the loop waits on its poll set — an X event or a sapp_wake — alone.
	// Passing nil clears it, restoring sokol's stock per-frame pacing.
	type FrameDeadlineFn = fn () f64

	fn C.sapp_set_frame_deadline_cb(cb FrameDeadlineFn)
	// sapp_wake interrupts the loop's sleep from any thread. It is a plain
	// nonblocking write to a pipe in data-segment memory, so unlike the
	// scheduler's invalidate it is safe from threads the GC does not know.
	fn C.sapp_wake()

// ui2_frame_deadline_cb tells sokol how long the event loop may sleep before
// the next scheduled frame. It runs on the frame thread just before the loop
// sleeps, so the scheduler's deadline — set at the end of the last frame — is
// already current, and reading it needs no extra synchronization. A deadline
// the last frame already ran past must wake the loop now: sokol reads a
// negative return as "nothing scheduled" and would block on the poll set
// alone, never servicing the timer.
	fn ui2_frame_deadline_cb() f64 {
		stats := g_gg_app.scheduler.stats()
		if stats.next_deadline < 0 {
			return -1.0
		}
		delta := stats.next_deadline - renderer_now_ms()
		if delta <= 0 {
			return 0.0
		}
		return f64(delta) / 1000.0
	}

	fn on_init(app &GgApp) {
		// Sokol's loops swap even when frame_fn returns early, so an undrawn backbuffer
		// can be presented on drivers that discard it. Metal skips idle callbacks. X11
		// skips them too when sokol honors sapp_set_present_on_demand: frames UI2 did
		// not draw are not presented, so the window keeps its last picture. Other
		// backends repaint the retained tree on every callback.
		$if gg_record ? {
		} $else $if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
			g_present_on_demand = g_refresh_mode != .continuous && C.sapp_set_present_on_demand(true)
			// The deadline hook makes the X11 loop sleep until the earliest of
			// the scheduler's next deadline, an X event or a sapp_wake, instead
			// of pacing itself at the swap interval all night. Continuous mode
			// draws every frame and must keep the stock pacing.
			if g_refresh_mode != .continuous {
				C.sapp_set_frame_deadline_cb(ui2_frame_deadline_cb)
			}
		}
		// A reference field of an immutable pointer cannot be popped through to a
		// mut method on V 0.5.2; bind it through a mutable local instead.
		mut scheduler := app.scheduler
		scheduler.set_presentation_required(gfx.query_backend() != .metal_macos
			&& !g_present_on_demand)
		if voidptr(g_build_screen) == unsafe { nil } {
			custom_fire_window_ready()
			return
		}
		// gg/Sokol must receive images during initialization to make their GPU
		// textures available for the first rendered frame.
		g_gg_app.scheduler.record_build()
		preload_images(g_build_screen())
		custom_fire_window_ready()
	}

	fn on_cleanup(app &GgApp) {
		mut scheduler := app.scheduler
		scheduler.close()
		mut state := unsafe { app }
		state.ctx = unsafe { nil }
		state.declared_root = Element{}
		state.has_root = false
		configure_animation_driver(unsafe { nil }, false)
		reset_widget_animations()
		g_tooltip = TooltipState{}
		g_touch = TouchState{}
	}

	// The next visual deadline is replaced after every frame. A canceled hover,
	// unmounted target or released pointer therefore cannot leave a live timer.
	fn custom_visual_deadline() i64 {
		mut deadline := i64(-1)
		if g_tooltip.pointer_in && g_tooltip.key.len > 0 && !g_tooltip.dismissed
			&& !g_tooltip.visible && !g_touch.down && !menu_bar_open() && g_open_dropdown.len == 0 {
			deadline = g_tooltip.rest_since + tooltip_delay_ms
		}
		if g_touch.down && !g_touch.moved && !g_touch.long_press_fired && !g_touch.scrollbar_drag {
			target := hit_test(g_touch.start_x, g_touch.start_y)
			if target.long_press && target.action_id.len > 0 {
				press_deadline := g_touch.start_time + 450
				if deadline < 0 || press_deadline < deadline {
					deadline = press_deadline
				}
			}
		}
		return deadline
	}

	fn on_frame(mut app GgApp) {
		if app.scheduler.is_closed() || app.ctx == unsafe { nil } || app.draining_tasks {
			return
		}
		$if android {
			android_poll_file_dialog()
		}
		if !g_present_on_demand {
			g_last_frame_ticks = time.ticks()
		}
		g_frame_running = true
		defer {
			g_frame_running = false
		}
		// Callbacks run outside the coordinator lock, on this UI thread. Business
		// messages may run while minimized, but visual work stays suspended.
		app.draining_tasks = true
		for task in app.scheduler.take_tasks() {
			if app.scheduler.is_closed() {
				break
			}
			task()
		}
		app.draining_tasks = false
		mut ctx := app.ctx
		live_size := ctx.window_size()
		if live_size.width > 0 && live_size.height > 0
			&& (ctx.width != live_size.width || ctx.height != live_size.height) {
			ctx.width = live_size.width
			ctx.height = live_size.height
			ctx.window.width = live_size.width
			ctx.window.height = live_size.height
			app.scheduler.invalidate(.surface)
		}
		dpi := sapp.dpi_scale()
		if dpi != app.dpi_scale {
			app.dpi_scale = dpi
			app.scheduler.invalidate(.surface)
		}
		now := renderer_now_ms()
		work := app.scheduler.begin_frame(now) or { return }
		defer { app.scheduler.finish_frame(work) }
		ensure_symbol_fallbacks(ctx)
		// Manual mode suppresses the frame callback between asks, so a pending
		// visual deadline needs its own wake: schedule one one-shot timer that
		// lands on the deadline. The other modes re-check the deadline from the
		// flowing frame callback, and only long-press and tooltip rests set
		// deadlines, so this stays rare.
		if g_refresh_mode == .manual {
			deadline := app.scheduler.stats().next_deadline
			if deadline >= 0 {
				after(f64(deadline - now) / 1000.0, fn () {})
			}
		}
		if !text_measurement_exact() && ctx.font_inited {
			// Text is measured from the first frame with fonts and their symbol
			// fallbacks in place; measured earlier, a glyph only a fallback face
			// has, such as ⌘, was cached as the width of an empty box.
			configure_text_measurer(custom_measure_text_width)
		}
		if work.build && voidptr(g_build_screen) != unsafe { nil } {
			app.scheduler.record_build()
			declared := g_build_screen()
			validate_element_tree(declared) or {
				eprintln('ui2: ${err}')
				return
			}
			app.declared_root = declared
			app.has_root = true
		}
		// A background window runs its frames while hidden (the drains and
		// surface renders inside them are the point), so only a real suspend
		// or a window without the option stops here.
		if app.scheduler.is_closed() || app.suspended || (app.iconified && !g_background_work) {
			return
		}
		// The animation pass returns the tree the build just validated with
		// animation properties merged in: it keeps every id, key and child, so
		// revalidating the result would rescan the tree for no new information.
		root := apply_custom_widget_animations(app.declared_root)
		// Animation callbacks are user code and may close or suspend the window.
		if app.scheduler.is_closed() || app.suspended || (app.iconified && !g_background_work) {
			return
		}
		// Image resources must be available before starting the GPU pass.
		preload_images(root)
		if voidptr(g_gl_surface_renderer) != unsafe { nil } {
			for id, frame in g_opengl_surface_frames {
				g_gl_surface_renderer(id, frame, f64(ctx.scale), layout_window_height(ctx))
			}
		}
		sync_gl_surface_textures()
		g_opengl_surface_frames = map[string]Rect{}
		// The per-frame registration maps are cleared after the host's surface
		// renderer ran, not before it. That renderer is where the host drains
		// its player's events, and the writes it makes there — a slider value
		// through set_slider_value, say — must land in the frame that asks for
		// them: cleared first, the id is no longer registered and the write is
		// dropped on the floor. render_element registers the current tree below
		// either way, so what this clears is last frame's leftovers.
		g_hit_targets.clear()
		g_hover_regions.clear()
		g_hover_chain = []string{}
		g_tooltip_targets.clear()
		g_tooltip_owners = 0
		reset_scroll_frame()
		g_active_fields.clear()
		g_active_sliders.clear()
		g_active_switches.clear()
		g_active_checkboxes.clear()
		g_active_toggles.clear()
		g_active_scrolls.clear()
		g_active_images.clear()
		ctx.begin()
		if app.has_root {
			g_dropdown_popup.mounted = false
			top := menu_bar_height()
			render_element(ctx, root, 0, top, rect(0, top, layout_window_width(ctx),
				layout_window_height(ctx) - top), '')
			if g_open_dropdown.len > 0 {
				if g_dropdown_popup.mounted {
					draw_dropdown_popup(ctx)
				} else {
					close_dropdown()
				}
			}
			draw_menu_bar(ctx)
			update_tooltip(now)
			draw_tooltip(ctx)
			prune_unmounted_state()
			// Content can move under a pointer that stays put.
			update_hover()
		}
		check_long_press()
		// The atlas needs no flush here: gg's fontstash callbacks copy every
		// rasterized glyph region the moment it lands (update_image_region),
		// so nothing of this frame is left pending on the GPU side.
		ctx.end()
		app.scheduler.record_draw()
		// A hidden background window drew into its surfaces but presents
		// nothing: the swap would land in an unmapped window and only spend
		// the GPU's time. The keep-alive's clock keeps running from the last
		// presented frame, so a window that comes back also repaints at once.
		if g_present_on_demand && !(app.iconified && g_background_work) {
			C.sapp_request_present()
			g_last_frame_ticks = time.ticks()
		}
		app.scheduler.set_deadline(custom_visual_deadline())
		app.scheduler.set_animation_active(custom_animations_need_frame(app.declared_root))
	}

	// touch_to_layout maps a touch point from framebuffer pixels into the layout
	// pixels every other pointer event already uses.
	fn touch_to_layout(point gg.TouchPoint) (f64, f64) {
		s := scale()
		return f64(point.pos_x) / s, f64(point.pos_y) / s
	}

	// pointer_press_at handles a press of the pointer: a mouse button, or the
	// first finger on a touch screen. Both take this one path, so the menu bar,
	// the tooltip and the press handlers see a tap the way they see a click.
	fn pointer_press_at(x f64, y f64, button int) {
		if voidptr(g_mouse_button_handler) != unsafe { nil } {
			g_mouse_button_handler(button, true, x, y)
		}
		g_tooltip.dismiss()
		if menu_bar_handle_down(x, y) {
			return
		}
		handle_touch_down(x, y)
	}

	// pointer_move_to handles a move of the pointer or of the first finger.
	fn pointer_move_to(x f64, y f64) {
		// Recorded before any handler below can claim the move, so the
		// tooltip always knows where the pointer is.
		g_tooltip.pointer_moved(x, y, renderer_now_ms())
		if voidptr(g_pointer_move_handler) != unsafe { nil } {
			g_pointer_move_handler(x, y)
		}
		g_hover_pointer = HoverPointer{
			x: x
			y: y
			inside: true
		}
		update_hover()
		if g_touch.down && g_touch.pointer_target.action_id.len > 0 {
			handle_touch_move(x, y)
			return
		}
		if menu_bar_handle_move(x, y) {
			return
		}
		if g_open_dropdown.len > 0 {
			update_dropdown_hover(x, y)
		}
		if g_touch.down {
			handle_touch_move(x, y)
		}
	}

	// pointer_release_at handles a release of the pointer or of the first finger.
	fn pointer_release_at(x f64, y f64, button int) {
		if voidptr(g_mouse_button_handler) != unsafe { nil } {
			g_mouse_button_handler(button, false, x, y)
		}
		if g_touch.down && g_touch.pointer_target.action_id.len > 0 {
			handle_touch_up(x, y)
			return
		}
		if menu_bar_handle_up(x, y) {
			return
		}
		handle_touch_up(x, y)
	}

	fn on_event(e &gg.Event, app &GgApp) {
		mut state := unsafe { app }
		if state.scheduler.is_closed() {
			return
		}
		// Window events (resize, DPI change) rewrite gg's own scale; the pin
		// goes back on before anything reads it this batch.
		apply_scale_override()
		g_key_modifiers = KeyModifiers{
			shift: e.modifiers & u32(gg.Modifier.shift) != 0
			ctrl: e.modifiers & u32(gg.Modifier.ctrl) != 0
			alt: e.modifiers & u32(gg.Modifier.alt) != 0
			cmd: e.modifiers & u32(gg.Modifier.super) != 0
		}
		// All input can affect local interaction or invoke application handlers.
		// Legacy builds remain complete; paint-only setters/deadlines reuse root.
		state.scheduler.invalidate(.build)
		match e.typ {
			.mouse_down {
				pointer_press_at(f64(e.mouse_x), f64(e.mouse_y), int(e.mouse_button))
			}
			.mouse_move {
				pointer_move_to(f64(e.mouse_x), f64(e.mouse_y))
			}
			.mouse_scroll {
				// The content moves under a pointer that stays put, so whatever
				// ends up beneath it waits for a fresh rest.
				g_tooltip.restart(renderer_now_ms())
				if voidptr(g_wheel_handler) != unsafe { nil } {
					g_wheel_handler(f64(e.scroll_x), f64(e.scroll_y))
				}
				if menu_bar_open() {
					return
				}
				mut delta_x := f64(e.scroll_x)
				mut delta_y := f64(e.scroll_y)
				// Shift turns a plain wheel sideways, for a mouse with nothing
				// that reports a horizontal delta of its own.
				if delta_x == 0 && e.modifiers & u32(gg.Modifier.shift) != 0 {
					delta_x = delta_y
					delta_y = 0
				}
				handle_mouse_scroll(f64(e.mouse_x), f64(e.mouse_y), delta_y)
				handle_mouse_scroll_horizontal(f64(e.mouse_x), f64(e.mouse_y), delta_x)
			}
			.mouse_leave {
				g_tooltip.pointer_left()
				g_hover_pointer.inside = false
				update_hover()
			}
			.mouse_up {
				pointer_release_at(f64(e.mouse_x), f64(e.mouse_y), int(e.mouse_button))
			}
			// A touch screen's first finger is the pointer: it takes the mouse
			// path above, so embedders that decide over-video input themselves
			// see taps too.
			.touches_began {
				if e.num_touches > 0 {
					x, y := touch_to_layout(e.touches[0])
					pointer_press_at(x, y, 0)
				}
			}
			.touches_moved {
				if e.num_touches > 0 {
					x, y := touch_to_layout(e.touches[0])
					pointer_move_to(x, y)
				}
			}
			.touches_ended {
				if e.num_touches > 0 {
					x, y := touch_to_layout(e.touches[0])
					pointer_release_at(x, y, 0)
				} else {
					pointer_release_at(g_touch.current_x, g_touch.current_y, 0)
				}
			}
			.iconified, .suspended {
				if e.typ == .iconified {
					state.iconified = true
				} else {
					state.suspended = true
				}
				// A background window keeps its frames running while hidden,
				// so the application's own drains and render calls inside the
				// frame keep going; only windows without the option suspend.
				// A system suspend stops frames either way — that event says
				// the machine itself is going away.
				if !(e.typ == .iconified && g_background_work) {
					state.scheduler.suspend()
				}
				g_tooltip.pointer_left()
				cancel_touch()
			}
			.restored, .resumed {
				if e.typ == .restored {
					state.iconified = false
				} else {
					state.suspended = false
				}
				if !state.iconified && !state.suspended {
					state.scheduler.resume()
				}
			}
			.resized, .focused {
				state.scheduler.invalidate(.surface)
			}
			.touches_cancelled, .unfocused {
				g_tooltip.dismiss()
				cancel_touch()
			}
			.char {
				handle_char_input(e.char_code, e.modifiers)
			}
			.key_down {
				g_tooltip.dismiss()
				if menu_bar_handle_key(e) {
					return
				}
				if g_open_dropdown.len > 0 {
					if handle_dropdown_key(e.key_code) {
						return
					}
				}
				if !dispatch_key_event(e) {
					handle_key_down(e.key_code, e.modifiers)
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
			start_time: renderer_now_ms()
			moved: false
			long_press_fired: false
		}
		if g_open_dropdown.len > 0 {
			update_dropdown_hover(x, y)
			return
		}
		target := hit_test(x, y)
		if g_refresh_mode == .on_demand && target.long_press {
			// check_long_press fires from inside drawn frames, and after the
			// last input event only a few trailing frames follow; the ask keeps
			// a frame alive past the deadline so the hold is not forgotten.
			// Only long-press targets need it, so taps on everything else let
			// the window go back to sleep.
			after(0.55, fn () {})
		}
		if target.slider {
			// The slider takes the gesture without a pointer_target capture, so
			// mark the drag by id: until the release, external value writes for
			// it are held off in set_slider_value and the mount merge.
			g_touch.slider_drag_id = target.id
			commit_slider(target, x, y)
			return
		}
		if target.switch_control {
			return
		}
		g_touch.scroll_id = scroll_hit_test(x, y)
		g_touch.scroll_chain = scroll_ancestor_chain(g_touch.scroll_id)
		if begin_scrollbar_drag(x, y) {
			return
		}
		if target.action_id.len > 0
			&& (target.clickable || target.button_behavior || target.draggable) {
			g_touch.pointer_target = target
			if target.clickable || target.draggable {
				fire_event(pointer_event_id('down', target.action_id, x, y))
			}
		}
	}

	fn handle_touch_move(x f64, y f64) {
		if !g_touch.down {
			return
		}
		previous_x := g_touch.current_x
		previous_y := g_touch.current_y
		dx := x - g_touch.start_x
		dy := y - g_touch.start_y
		if dx * dx + dy * dy > 100 {
			g_touch.moved = true
		}
		g_touch.current_x = x
		g_touch.current_y = y
		target := if g_touch.pointer_target.action_id.len > 0 {
			g_touch.pointer_target
		} else {
			hit_test(g_touch.start_x, g_touch.start_y)
		}
		if target.slider {
			commit_slider(target, x, y)
			return
		}
		if target.switch_control {
			commit_switch(target, x >= target.x + target.w / 2)
			return
		}
		if g_touch.scrollbar_drag {
			drag_scrollbar(x, y)
			return
		}
		dragging := target.action_id.len > 0 && target.draggable
		// A press on something draggable drags it; the scroll around it stays put,
		// or reordering tabs in a strip that scrolls would also scroll the strip.
		if g_touch.scroll_chain.len > 0 && !dragging {
			apply_scroll_chain(g_touch.scroll_chain, previous_y - y, false)
			apply_scroll_chain(g_touch.scroll_chain, previous_x - x, true)
		}
		if dragging {
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
		apply_scroll_chain(scroll_ancestor_chain(id), -delta_y * 48, false)
	}

	fn handle_mouse_scroll_horizontal(x f64, y f64, delta_x f64) {
		if delta_x == 0 || g_open_dropdown.len > 0 {
			return
		}
		id := scroll_hit_test(x, y)
		if id.len == 0 {
			return
		}
		apply_scroll_chain(scroll_ancestor_chain(id), -delta_x * 48, true)
	}

	fn clamped_scroll_offset(requested f64, maximum f64) f64 {
		max_scroll := if maximum > 0 { maximum } else { 0.0 }
		return if requested < 0 {
			0.0
		} else if requested > max_scroll {
			max_scroll
		} else {
			requested
		}
	}

	fn set_scroll_offset(id string, requested f64, maximum f64) {
		next := clamped_scroll_offset(requested, maximum)
		previous := g_scroll_offsets[id] or { 0.0 }
		g_scroll_offsets[id] = next
		if next != previous {
			invalidate_custom_paint()
			if voidptr(g_scroll_handler) != unsafe { nil } {
				refresh()
				g_scroll_handler(id)
			}
		}
	}

	fn set_scroll_offset_x(id string, requested f64, maximum f64) {
		next := clamped_scroll_offset(requested, maximum)
		previous := g_scroll_offsets_x[id] or { 0.0 }
		g_scroll_offsets_x[id] = next
		if next != previous {
			invalidate_custom_paint()
			if voidptr(g_scroll_handler) != unsafe { nil } {
				refresh()
				g_scroll_handler(id)
			}
		}
	}

	fn handle_touch_up(x f64, y f64) {
		if !g_touch.down {
			return
		}
		release_dx := x - g_touch.start_x
		release_dy := y - g_touch.start_y
		if release_dx * release_dx + release_dy * release_dy > 100 {
			g_touch.moved = true
		}
		g_touch.current_x = x
		g_touch.current_y = y
		captured := g_touch.pointer_target
		g_touch.pointer_target = HitTarget{}
		g_touch.down = false
		g_touch.slider_drag_id = ''
		slider_target := if captured.action_id.len > 0 {
			captured
		} else {
			hit_test(g_touch.start_x, g_touch.start_y)
		}
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
		if g_open_dropdown.len > 0 && captured.action_id.len == 0 {
			handle_dropdown_release(x, y)
			return
		}
		mut target := if captured.action_id.len > 0 {
			captured
		} else {
			hit_test(g_touch.start_x, g_touch.start_y)
		}
		dx := x - g_touch.start_x
		if g_touch.moved && dx < -72 {
			if target.action_id.len > 0 && target.swipe_left {
				fire_event('swipe_left:' + target.action_id)
				return
			}
		}
		mut button_action := ''
		if target.action_id.len > 0 && target.button_behavior {
			if !g_touch.moved {
				if current := current_button_behavior_target(target) {
					if hit_target_contains(current, x, y) {
						button_action = target.action_id
					}
				}
			}
		}
		if target.action_id.len > 0 && (target.clickable || target.draggable) {
			fire_event(pointer_event_id('up', target.action_id, x, y))
		}
		if target.button_behavior {
			fire_event(button_action)
			return
		}
		if target.action_id.len > 0 && (target.clickable || target.draggable) {
			return
		}
		if g_touch.moved {
			return
		}
		target = hit_test(x, y)
		if target.checkbox {
			commit_checkbox(target)
			return
		}
		if target.id.len == 0 && target.action_id.len == 0 {
			if g_focused_field.len > 0 {
				g_focused_field = ''
			}
			return
		}
		if target.text_field {
			g_focused_field = target.id
			mut editor := g_text_editors[target.id] or {
				text_editor((g_text_values[target.id] or { '' }).clone())
			}
			editor.set_caret(rune_len(editor.text))
			replace_text_editor(target.id, editor)
			return
		}
		if target.text_area {
			g_focused_field = target.id
			mut editor := g_text_editors[target.id] or {
				text_editor((g_text_values[target.id] or { '' }).clone())
			}
			editor.set_caret(rune_len(editor.text))
			replace_text_editor(target.id, editor)
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

	// Finish a captured gesture on focus loss/cancellation so an IDE drag cannot
	// remain stuck. Ordinary taps are cancelled without activating a control.
	fn cancel_touch() {
		captured := g_touch.pointer_target
		x := g_touch.current_x
		y := g_touch.current_y
		g_touch = TouchState{}
		if captured.action_id.len > 0 && (captured.clickable || captured.draggable) {
			fire_event(pointer_event_id('up', captured.action_id, x, y))
		}
	}

	fn check_long_press() {
		if !g_touch.down || g_touch.moved || g_touch.long_press_fired || g_touch.scrollbar_drag {
			return
		}
		elapsed := renderer_now_ms() - g_touch.start_time
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

	fn hit_target_contains(target HitTarget, x f64, y f64) bool {
		return x >= target.x && x <= target.x + target.w && y >= target.y
			&& y <= target.y + target.h
	}

	// A semantic press keeps the action chosen on pointer-down, but the surface
	// must still exist and be enabled when it is released. Hit targets are rebuilt
	// every frame, so use the current geometry rather than the captured rectangle.
	fn current_button_behavior_target(captured HitTarget) ?HitTarget {
		if captured.id.len > 0 {
			for i := g_hit_targets.len - 1; i >= 0; i-- {
				current := g_hit_targets[i]
				if current.button_behavior && current.action_id.len > 0
					&& current.id == captured.id {
					return current
				}
			}
			return none
		}
		mut found := false
		mut matched := HitTarget{}
		for i := g_hit_targets.len - 1; i >= 0; i-- {
			current := g_hit_targets[i]
			if !current.button_behavior || current.action_id != captured.action_id {
				continue
			}
			if found {
				// Without a lookup id there is no stable way to distinguish two
				// surfaces that dispatch the same action after a rebuild.
				return none
			}
			found = true
			matched = current
		}
		if found {
			return matched
		}
		return none
	}

	fn fire_event(id string) {
		if id.len > 0 && voidptr(g_event_handler) != unsafe { nil } {
			refresh()
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

	fn commit_checkbox(target HitTarget) {
		if !target.checkbox {
			return
		}
		previous := if target.id.len > 0 { checkbox_checked(target.id) } else { target.checkbox_state }
		if target.id.len > 0 {
			g_checkbox_values[target.id] = !previous
		}
		fire_event(target.action_id)
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
		if voidptr(g_key_event_handler) != unsafe { nil } {
			g_key_consumed = false
			g_key_event_handler(immediate_key_event(e))
			if g_key_consumed {
				g_key_consumed = false
				return true
			}
		}
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

	fn immediate_key_event(e &gg.Event) KeyEvent {
		return KeyEvent{
			code: unsafe { KeyCode(int(e.key_code)) }
			shift: e.modifiers & u32(gg.Modifier.shift) != 0
			ctrl: e.modifiers & u32(gg.Modifier.ctrl) != 0
			alt: e.modifiers & u32(gg.Modifier.alt) != 0
			cmd: e.modifiers & u32(gg.Modifier.super) != 0
			repeat: e.key_repeat
		}
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

	fn handle_char_input(ch u32, modifiers u32) {
		if g_focused_field.len == 0 {
			return
		}
		// Control characters are never text. macOS additionally reports
		// Backspace as 0x7F (DEL) after the key event that already deleted.
		if ch < 32 || ch == 127 {
			return
		}
		// macOS (Cmd+V) and X11 (Ctrl+V) still deliver the chord's letter as
		// a character; the key handler owns those, not the text. Ctrl+Alt is
		// left alone because Windows reports AltGr that way, and AltGr
		// characters ('@', '€', ...) are genuine text.
		ctrl := modifiers & u32(gg.Modifier.ctrl) != 0
		alt := modifiers & u32(gg.Modifier.alt) != 0
		super_ := modifiers & u32(gg.Modifier.super) != 0
		if super_ || (ctrl && !alt) {
			return
		}
		mut editor := g_text_editors[g_focused_field] or {
			text_editor((g_text_values[g_focused_field] or { '' }).clone())
		}
		editor.insert_text(rune(ch).str())
		replace_text_value(g_focused_field, editor.text)
		replace_text_editor(g_focused_field, editor)
		fire_field_change(g_focused_field)
	}

	fn handle_key_down(key gg.KeyCode, modifiers u32) {
		if g_focused_field.len == 0 {
			return
		}
		mut editor := g_text_editors[g_focused_field] or {
			text_editor((g_text_values[g_focused_field] or { '' }).clone())
		}
		if handle_clipboard_shortcut(key, modifiers, mut editor) {
			return
		}
		if key == .backspace {
			if editor.backspace() {
				replace_text_value(g_focused_field, editor.text)
				replace_text_editor(g_focused_field, editor)
				fire_field_change(g_focused_field)
			}
		}
		if key == .delete {
			if editor.delete_forward() {
				replace_text_value(g_focused_field, editor.text)
				replace_text_editor(g_focused_field, editor)
				fire_field_change(g_focused_field)
			}
		}
		mut navigation_key := match key {
			.left { 'left' }
			.right { 'right' }
			.up { 'up' }
			.down { 'down' }
			.home { 'home' }
			.end { 'end' }
			.page_up { 'page_up' }
			.page_down { 'page_down' }
			.a { 'a' }
			else { '' }
		}
		mut focused_text_area := false
		for target in g_hit_targets {
			if target.id == g_focused_field {
				focused_text_area = target.text_area
				break
			}
		}
		if focused_text_area && (navigation_key == 'page_up' || navigation_key == 'page_down') {
			page_focused_text_area(if navigation_key == 'page_up' { -1 } else { 1 })
			return
		}
		primary_modifier := text_navigation_primary_modifier(
			modifiers & u32(gg.Modifier.ctrl) != 0,
			modifiers & u32(gg.Modifier.alt) != 0,
			modifiers & u32(gg.Modifier.super) != 0,
		)
		word_modifier := text_navigation_word_modifier(
			modifiers & u32(gg.Modifier.ctrl) != 0,
			modifiers & u32(gg.Modifier.alt) != 0,
		)
		boundary_modifier := text_navigation_boundary_modifier(
			modifiers & u32(gg.Modifier.super) != 0,
		)
		if focused_text_area && (navigation_key == 'up' || navigation_key == 'down') {
			if move_focused_text_area_caret(mut editor, if navigation_key == 'up' { -1 } else { 1 },
				modifiers & u32(gg.Modifier.shift) != 0) {
				g_text_editors[g_focused_field] = editor
			}
			return
		}
		if focused_text_area && (navigation_key == 'home' || navigation_key == 'end')
			&& !primary_modifier {
			if move_focused_text_area_line_boundary(mut editor, navigation_key == 'end',
				modifiers & u32(gg.Modifier.shift) != 0) {
				g_text_editors[g_focused_field] = editor
			}
			return
		}
		if boundary_modifier && navigation_key == 'left' {
			navigation_key = 'home'
		} else if boundary_modifier && navigation_key == 'right' {
			navigation_key = 'end'
		}
		navigation_modifier := if navigation_key == 'a' { primary_modifier } else { word_modifier }
		if navigation_key.len > 0 && apply_text_editor_navigation(mut editor, navigation_key,
			modifiers & u32(gg.Modifier.shift) != 0, navigation_modifier) {
			g_text_editors[g_focused_field] = editor
		}
		if key == .enter || key == .kp_enter {
			for target in g_hit_targets {
				if target.id == g_focused_field && target.text_area {
					editor.insert_text('\n')
					replace_text_value(g_focused_field, editor.text)
					replace_text_editor(g_focused_field, editor)
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

	// handle_clipboard_shortcut implements copy, cut and paste for the focused
	// field with the platform's primary modifier (Cmd on macOS, Ctrl elsewhere).
	// Single-line fields receive pasted newlines as spaces.
	fn handle_clipboard_shortcut(key gg.KeyCode, modifiers u32, mut editor TextEditor) bool {
		if key !in [gg.KeyCode.c, .x, .v] {
			return false
		}
		primary := text_navigation_primary_modifier(modifiers & u32(gg.Modifier.ctrl) != 0,
			modifiers & u32(gg.Modifier.alt) != 0, modifiers & u32(gg.Modifier.super) != 0)
		if !primary {
			return false
		}
		id := g_focused_field
		// A secure field keeps its plaintext in the editor and only masks at draw
		// time, so exporting the selection would publish the password. Consume the
		// chord without touching the clipboard, the text or the selection. Paste
		// stays available.
		if key != .v && (g_text_secure[id] or { false }) {
			return true
		}
		mut cb := system_clipboard()
		match key {
			.c {
				selected := editor_selected_text(editor)
				if selected.len > 0 {
					cb.copy(selected)
				}
			}
			.x {
				selected := editor_selected_text(editor)
				// A cut that could not reach the clipboard must not destroy the
				// text; the Windows backend returns false when it cannot lock the
				// clipboard or SetClipboardData fails.
				if selected.len > 0 && cb.copy(selected) {
					editor.replace_selection('')
					replace_text_value(id, editor.text)
					replace_text_editor(id, editor)
					fire_field_change(id)
				}
			}
			.v {
				mut pasted := cb.paste()
				if pasted.len == 0 {
					return true
				}
				if (g_text_kinds[id] or { Kind.text_field }) != .text_area {
					pasted = pasted.replace('\r\n', ' ').replace('\n', ' ').replace('\r', ' ')
				}
				editor.replace_selection(pasted)
				replace_text_value(id, editor.text)
				replace_text_editor(id, editor)
				fire_field_change(id)
			}
			else {}
		}
		return true
	}

	// TextClipboard is the part of clipboard.Clipboard the shortcuts use. Tests
	// install their own through g_clipboard_override to exercise failed copies
	// and pasted text without touching the system clipboard.
	interface TextClipboard {
	mut:
		copy(text string) bool
		paste() string
	}

	// system_clipboard returns the process-wide clipboard, created on first use.
	// The instance must outlive each copy: on X11 the clipboard owns a window
	// that holds CLIPBOARD selection ownership, and destroying it right after
	// a copy hands the selection back to nobody.
	fn system_clipboard() TextClipboard {
		if override := g_clipboard_override {
			return override
		}
		if isnil(g_clipboard) {
			g_clipboard = clipboard.new()
		}
		return g_clipboard
	}

	fn editor_selected_text(editor TextEditor) string {
		start, end := editor.selection.ordered()
		if start >= end {
			return ''
		}
		runes := editor.text.runes()
		if end > runes.len {
			return ''
		}
		return runes[start..end].string()
	}

	// text_navigation_primary_modifier keeps the native text-editing shortcuts
	// available without treating AltGr (reported as Ctrl+Alt on Windows) as
	// Control. Command is the primary modifier on macOS.
	fn text_navigation_primary_modifier(ctrl bool, alt bool, super_ bool) bool {
		$if macos {
			return super_
		} $else {
			return ctrl && !alt
		}
	}

	// text_navigation_word_modifier follows native word movement: Option on
	// macOS, and Control everywhere else. Excluding Alt on non-macOS systems
	// keeps AltGr from being interpreted as a Control shortcut.
fn text_navigation_word_modifier(ctrl bool, alt bool) bool {
		$if macos {
			return alt
		} $else {
			return ctrl && !alt
		}
}

// text_navigation_boundary_modifier maps Command+Arrow to line boundaries on
// macOS. On other platforms Ctrl+Arrow must remain word navigation.
fn text_navigation_boundary_modifier(super_ bool) bool {
	$if macos {
		return super_
	} $else {
		return false
	}
}

fn page_focused_text_area(direction int) {
		viewport := g_scroll_viewports[g_focused_field] or { return }
		set_scroll_offset(g_focused_field, scroll_offset(g_focused_field) + f64(direction) * viewport.height,
			scroll_maximum(g_focused_field))
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
		replace_text_value(id, value)
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
		window := rect(0, 0, layout_window_width(ctx), layout_window_height(ctx))
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
		window := rect(0, 0, layout_window_width(ctx), layout_window_height(ctx))
		apply_clip(ctx, window)
		draw_rect(ctx, dropdown_state.x + 1, dropdown_state.y + 2, dropdown_state.width,
			dropdown_state.height, 0xdbe2ea, dropdown_state.radius)
		draw_rect(ctx, dropdown_state.x, dropdown_state.y, dropdown_state.width,
			dropdown_state.height, 0xffffff, dropdown_state.radius)
		draw_outline(ctx, dropdown_state.x, dropdown_state.y, dropdown_state.width,
			dropdown_state.height, 0xb8c2cf, dropdown_state.radius)
		list_clip := intersect_rect(rect(dropdown_state.x + 1,
			dropdown_state.y + dropdown_popup_padding, dropdown_state.width - 2,
			dropdown_state.height - dropdown_popup_padding * 2), window)
		if list_clip.width <= 0 || list_clip.height <= 0 {
			return
		}
		apply_clip(ctx, list_clip)
		row_style := TextStyle{
			...dropdown_state.text_style
			align: .left
		}
		for index, option in dropdown_state.options {
			row_y := dropdown_state.y + dropdown_popup_padding + f64(index) * dropdown_state.row_height -
				g_dropdown_scroll
			if row_y + dropdown_state.row_height <= list_clip.y || row_y >= list_clip.y + list_clip.height {
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
			}, list_clip)
		}
		draw_scrollbar(ctx, dropdown_state.x, dropdown_state.y, dropdown_state.width,
			dropdown_state.height, f64(dropdown_state.options.len) * dropdown_state.row_height +
			dropdown_popup_padding * 2, g_dropdown_scroll, false, 0xffffff)
		apply_clip(ctx, window)
	}

	// ── Tooltips ───────────────────────────────────────────────────────

	// pointer_moved restarts the rest a tooltip waits for. One already showing
	// stays where it opened while the pointer moves within its target, as the
	// native ones do, rather than chasing the cursor.
	fn (mut state TooltipState) pointer_moved(x f64, y f64, now i64) {
		state.pointer_x = x
		state.pointer_y = y
		state.pointer_in = true
		if !state.visible {
			state.rest_since = now
		}
	}

	fn (mut state TooltipState) pointer_left() {
		state.pointer_in = false
		state.visible = false
		state.dismissed = false
		state.key = ''
	}

	fn (mut state TooltipState) dismiss() {
		state.visible = false
		state.dismissed = true
	}

	fn (mut state TooltipState) restart(now i64) {
		state.visible = false
		state.rest_since = now
	}

	// update settles the tooltip for a frame, given the target now under the
	// pointer. A blocked frame is one where something else holds the pointer's
	// attention; the rest only starts once it lets go.
	fn (mut state TooltipState) update(target TooltipTarget, blocked bool, now i64) {
		if !state.pointer_in || target.text.len == 0 {
			state.key = ''
			state.dismissed = false
			state.visible = false
			return
		}
		if target.key != state.key {
			state.key = target.key
			state.rest_since = now
			state.dismissed = false
			state.visible = false
		}
		if blocked {
			state.visible = false
			state.rest_since = now
			return
		}
		if state.dismissed {
			return
		}
		if !state.visible && now - state.rest_since >= tooltip_delay_ms {
			state.visible = true
			state.anchor_x = state.pointer_x
			state.anchor_y = state.pointer_y
		}
		// A label that changes while its tooltip is open shows the new text.
		state.text = target.text
	}

	// tooltip_target_at finds the target under a point. Targets are registered
	// in drawing order, so the last one containing the point is the one drawn
	// on top, whether it has text to show or only hides what is beneath it.
	fn tooltip_target_at(targets []TooltipTarget, x f64, y f64) TooltipTarget {
		for i := targets.len - 1; i >= 0; i-- {
			frame := targets[i].frame
			if x >= frame.x && x < frame.x + frame.width && y >= frame.y
				&& y < frame.y + frame.height {
				return targets[i]
			}
		}
		return TooltipTarget{}
	}

	// tooltip_key names an element's target. An id stays the same while the
	// element moves; an element without one is known by where it is drawn,
	// which holds for as long as nothing, such as a scroll, moves it.
	fn tooltip_key(el Element, area Rect) string {
		if el.id.len > 0 {
			return '${el.kind}#${el.id}'
		}
		return '${el.kind}@${area.x},${area.y},${area.width},${area.height}'
	}

	// add_tooltip_target registers the part of a target that is visible under
	// the clip it was drawn with, so a control scrolled out of its viewport
	// cannot answer for the pointer.
	fn add_hover_region(area Rect, clip Rect) {
		visible := intersect_rect(area, clip)
		if visible.width <= 0 || visible.height <= 0 {
			return
		}
		g_hover_regions << HoverRegion{
			area: visible
			chain: g_hover_chain
		}
	}

	fn hovered_chain_at(x f64, y f64) []string {
		for i := g_hover_regions.len - 1; i >= 0; i-- {
			region := g_hover_regions[i]
			if x >= region.area.x && x < region.area.x + region.area.width && y >= region.area.y
				&& y < region.area.y + region.area.height {
				return region.chain
			}
		}
		return []string{}
	}

	// update_hover reports the hoverable elements the pointer left and entered
	// since the last check, comparing what it hovers now with what it hovered.
	fn update_hover() {
		pointer := g_hover_pointer
		current := if pointer.inside { hovered_chain_at(pointer.x, pointer.y) } else { []string{} }
		left, entered := hover_transitions(g_hovered, current)
		unsafe {
			g_hovered = current
		}
		if voidptr(g_event_handler) == unsafe { nil } {
			return
		}
		for action in left {
			g_event_handler(pointer_event_id('leave', action, pointer.x, pointer.y))
		}
		for action in entered {
			g_event_handler(pointer_event_id('enter', action, pointer.x, pointer.y))
		}
	}

	fn add_tooltip_target(key string, text string, area Rect, clip Rect) {
		visible := intersect_rect(area, clip)
		if visible.width <= 0 || visible.height <= 0 {
			return
		}
		g_tooltip_targets << TooltipTarget{
			key: key
			text: text
			frame: visible
		}
	}

	// add_full_text_tooltip lets the pointer read text the renderer had to
	// shorten, the way a truncated cell expands to its full text on hover in
	// the native toolkits. A tooltip the element declared is more specific
	// about it and was registered already, so it is kept instead.
	fn add_full_text_tooltip(el Element, area Rect, clip Rect, full string, shortened bool) {
		if !shortened || el.tooltip.len > 0 || full.len == 0 {
			return
		}
		add_tooltip_target(tooltip_key(el, area), full, area, clip)
	}

	// tooltip_hides_beneath reports a surface that covers whatever was drawn
	// before it: a filled view, such as a dialog or its backdrop, or a scroll
	// view, which always paints its background. Without one, a truncated label
	// underneath would still answer for the pointer through it.
	fn tooltip_hides_beneath(el Element) bool {
		return (el.kind == .view && !el.box.transparent) || el.kind == .scroll
	}

	// element_area is where an element is drawn in the window. The screen
	// fills the window below its offset, whatever its frame says.
	fn element_area(ctx &gg.Context, el Element, off_x f64, off_y f64) Rect {
		if el.kind == .screen {
			return rect(off_x, off_y, layout_window_width(ctx) - off_x,
				layout_window_height(ctx) - off_y)
		}
		return rect(el.frame.x + off_x, el.frame.y + off_y, el.frame.width, el.frame.height)
	}

	// update_tooltip settles the tooltip once the frame's targets are known.
	// Nothing shows while an open dropdown list or menu has the pointer, or
	// while a press or a drag is still in progress.
	fn update_tooltip(now i64) {
		target := tooltip_target_at(g_tooltip_targets, g_tooltip.pointer_x, g_tooltip.pointer_y)
		blocked := g_open_dropdown.len > 0 || menu_bar_open() || g_touch.down
		g_tooltip.update(target, blocked, now)
	}

	// tooltip_lines wraps tooltip text to a readable measure and reports the
	// width of the widest line, so short help gets a snug bubble. The line cap
	// keeps a long string from filling the window; its last line carries the
	// rest and is shortened when drawn.
	fn tooltip_lines(text string, measure fn (string) f64) ([]string, f64) {
		lines := wrap_text_lines_measured(text.trim_right(' \t\r\n'), tooltip_max_text_width,
			tooltip_max_lines, measure)
		mut widest := 0.0
		for line in lines {
			width := measure(line)
			if width > widest {
				widest = width
			}
		}
		return lines, math.min(math.ceil(widest), tooltip_max_text_width)
	}

	// tooltip_frame puts a tooltip below and to the right of the pointer, clear
	// of the cursor, and keeps it inside the window: it is pushed in from the
	// right edge, and opens above the pointer when there is no room below.
	fn tooltip_frame(pointer_x f64, pointer_y f64, width f64, height f64, window Rect) Rect {
		right := window.x + window.width - tooltip_margin
		bottom := window.y + window.height - tooltip_margin
		mut x := pointer_x + tooltip_offset_x
		mut y := pointer_y + tooltip_offset_y
		if y + height > bottom {
			y = pointer_y - tooltip_gap - height
		}
		if x + width > right {
			x = right - width
		}
		if x < window.x + tooltip_margin {
			x = window.x + tooltip_margin
		}
		if y < window.y + tooltip_margin {
			y = window.y + tooltip_margin
		}
		return rect(x, y, width, height)
	}

	fn draw_tooltip(ctx &gg.Context) {
		if !g_tooltip.visible || g_tooltip.text.len == 0 {
			return
		}
		style := TextStyle{
			color: tooltip_text_color
			size: tooltip_text_size
			align: .left
		}
		// Measured with the configuration draw_text_in_box draws with, so no
		// line that fits here is shortened when it is drawn.
		ctx.set_text_cfg(gg.TextCfg{
			size: int(font_render_size(style.size, text_font_metrics('')) + 0.5)
			align: .left
			vertical_align: .middle
		})
		lines, text_width := tooltip_lines(g_tooltip.text, fn [ctx] (line string) f64 {
			return f64(ctx.text_width_f(line))
		})
		if lines.len == 0 {
			return
		}
		line_h := font_line_height(style.size)
		window := rect(0, 0, layout_window_width(ctx), layout_window_height(ctx))
		frame := tooltip_frame(g_tooltip.anchor_x, g_tooltip.anchor_y,
			text_width + tooltip_padding * 2, f64(lines.len) * line_h + tooltip_padding * 2, window)
		apply_clip(ctx, window)
		draw_rect(ctx, frame.x + 1, frame.y + 2, frame.width, frame.height, tooltip_shadow,
			tooltip_radius)
		draw_rect(ctx, frame.x, frame.y, frame.width, frame.height, tooltip_background,
			tooltip_radius)
		draw_outline(ctx, frame.x, frame.y, frame.width, frame.height, tooltip_border,
			tooltip_radius)
		for i, line in lines {
			draw_text_in_box(ctx, line, frame.x + tooltip_padding,
				frame.y + tooltip_padding + f64(i) * line_h, text_width, line_h, style, true, Rect{})
		}
	}

	fn prune_unmounted_state() {
		mut stale_fields := []string{}
		for id, _ in g_text_values {
			if id !in g_active_fields {
				stale_fields << id
			}
		}
		for id in stale_fields {
			forget_text_state(id)
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
		mut stale_checkboxes := []string{}
		for id, _ in g_checkbox_values {
			if id !in g_active_checkboxes {
				stale_checkboxes << id
			}
		}
		for id in stale_checkboxes {
			g_checkbox_values.delete(id)
			g_checkbox_declared.delete(id)
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
			g_scroll_offsets_x.delete(id)
			g_scroll_content_w.delete(id)
			// Auxiliary scroll state lives in separate maps; a dead id must
			// release every one of them or it leaks across frame lifetimes.
			g_scroll_viewports.delete(id)
			g_pending_scroll.delete(id)
			g_scrollbar_geometries.delete(id)
			g_pending_scroll_x.delete(id)
			g_scrollbar_geometries_x.delete(id)
			g_scroll_parents.delete(id)
			g_scroll_areas.delete(id)
		}
		// g_scroll_order survives only entries for live scroll areas; the
		// draw pass iterates it to keep stacking order stable.
		mut live_order := []string{}
		for id in g_scroll_order {
			if id in g_active_scrolls {
				live_order << id
			}
		}
		// The purge runs on the sweep path; the local array must not alias
		// the global that outlives this frame.
		g_scroll_order = live_order.clone()
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
		// Open dropdown state refers to an element id; if the id left the tree,
		// the popup can never close by itself.
		if g_open_dropdown.len > 0 && g_open_dropdown !in g_active_fields {
			close_dropdown()
		}
	}

	// ── Rendering ──────────────────────────────────────────────────────

	fn render_element(ctx &gg.Context, el Element, off_x f64, off_y f64, clip Rect, scroll_parent_id string) {
		if el.hidden {
			return
		}
		apply_clip(ctx, clip)
		area := element_area(ctx, el, off_x, off_y)
		// A chain is never changed once built — a hoverable element gets a new one —
		// so regions and the stack share them without copying.
		outer_hover_chain := g_hover_chain
		if el.hoverable && element_action_id(el).len > 0 {
			mut chain := outer_hover_chain.clone()
			chain << element_action_id(el)
			unsafe {
				g_hover_chain = chain
			}
		}
		add_hover_region(area, clip)
		defer {
			unsafe {
				g_hover_chain = outer_hover_chain
			}
		}
		// A declared tooltip covers the element's whole area and is registered
		// before its children, so a child with hover text of its own wins over
		// it where they overlap. A surface only has anything to hide once some
		// target has been registered before it.
		owns_tooltip := el.tooltip.len > 0
		if owns_tooltip {
			add_tooltip_target(tooltip_key(el, area), el.tooltip, area, clip)
			g_tooltip_owners++
		} else if g_tooltip_owners == 0 && g_tooltip_targets.len > 0 && tooltip_hides_beneath(el) {
			add_tooltip_target('', '', area, clip)
		}
		defer {
			if owns_tooltip {
				g_tooltip_owners--
			}
		}
		match el.kind {
			.screen {
				w := layout_window_width(ctx)
				h := layout_window_height(ctx)
				if !el.box.transparent {
					draw_rect(ctx, off_x, off_y, w - off_x, h - off_y, el.box.bg, 0)
				}
				draw_box_borders(ctx, off_x, off_y, w - off_x, h - off_y, el.box)
				for child in el.children {
					render_element(ctx, child, off_x, off_y, clip, scroll_parent_id)
				}
			}
			.view {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				draw_box_fill(ctx, x, y, el.frame.width, el.frame.height, el.box)
				// A shape is content: above the fill, beneath the borders, as the
				// native backends layer it.
				draw_shape(ctx, el, x, y, clip)
				draw_box_borders(ctx, x, y, el.frame.width, el.frame.height, el.box)
				if el.enabled && element_action_id(el).len > 0
					&& (el.clickable || el.button_behavior || el.draggable || el.long_press
					|| el.swipe_left) {
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
						button_behavior: el.button_behavior
						draggable: el.draggable
					}, clip)
				}
				for child in el.children {
					render_element(ctx, child, x, y, clip, scroll_parent_id)
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
				// An axis the mode leaves out has no content to cover, and so no range.
				scrolls_x := el.scroll_mode != .vertical_only
				scrolls_y := el.scroll_mode != .horizontal_only
				mut content_h := 0.0
				if scrolls_y {
					for child in el.children {
						if !child.hidden && child.frame.y + child.frame.height > content_h {
							content_h = child.frame.y + child.frame.height
						}
					}
					// Include the bottom inset in both the scroll range and thumb geometry.
					if content_h > 0 {
						content_h += 16
					}
				}
				content_w := if scrolls_x { scroll_content_width(el.children) } else { 0.0 }
				scroll_y := register_scroll_view_in_parent(el.id, scroll_parent_id, frame, clip, content_h, el.enabled,
					scrolls_y, el.persistent_scrollbars)
				beside_vertical := scrolls_y && scrollbar_geometry(frame, content_h, scroll_y,
					el.persistent_scrollbars).track.height > 0
				scroll_x := register_scroll_view_width(el.id, content_w, scrolls_x, el.persistent_scrollbars,
					beside_vertical)
				child_scroll_parent_id := if el.id.len > 0 { el.id } else { scroll_parent_id }
				child_clip := intersect_rect(frame, clip)
				for child in el.children {
					child_screen_y := child.frame.y - scroll_y
					if child_screen_y + child.frame.height < 0 || child_screen_y > el.frame.height {
						retain_culled_scroll_state(child)
						continue
					}
					if scrolls_x {
						child_screen_x := child.frame.x - scroll_x
						if child_screen_x + child.frame.width < 0 || child_screen_x > el.frame.width {
							retain_culled_scroll_state(child)
							continue
						}
					}
					 render_element(ctx, child, x - scroll_x, y - scroll_y, child_clip, child_scroll_parent_id)
				}
				if child_clip.width > 0 && child_clip.height > 0 {
					apply_clip(ctx, child_clip)
					if scrolls_y && !el.disable_scroll {
						// A transparent scroll still names the color it sits on.
						draw_scrollbar(ctx, x, y, el.frame.width, el.frame.height, content_h, scroll_y,
							el.persistent_scrollbars, el.box.bg)
					}
					if scrolls_x && !el.disable_scroll {
						draw_scrollbar_x(ctx, frame, content_w, scroll_x, el.persistent_scrollbars,
							beside_vertical, el.box.bg)
					}
				}
				apply_clip(ctx, clip)
			}
			.label {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				shortened := draw_label_text(ctx, el.text, x, y, el.frame.width, el.frame.height,
					el.text_style, clip)
				add_full_text_tooltip(el, area, clip, el.text, shortened)
			}
			.opengl {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				// Before the application's first texture arrives — the frame after
				// the element appears — the surface draws nothing, the way native
				// backends show it.
				if tex := g_gl_surface_textures[el.id] {
					draw_gl_surface_quad(ctx, tex, x, y, el.frame.width, el.frame.height)
				}
				if el.id.len > 0 {
					register_gl_surface(el.id, x, y, el.frame.width, el.frame.height)
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
			.image {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				if name := symbol_name(el.image_path) {
					draw_symbol_image(ctx, name, x, y, el.frame.width, el.frame.height, el.text_style.color)
				} else if el.image_path.trim_space().len > 0
					&& !draw_cached_image(ctx, el.image_path, x, y, el.frame.width, el.frame.height,
					el.rotation) {
					draw_rect(ctx, x, y, el.frame.width, el.frame.height, 0xe8ecef, 0)
				}
				if el.enabled && element_action_id(el).len > 0
					&& (el.clickable || el.draggable) {
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
				if el.native_style && el.box.bg == unstyled_box_bg {
					draw_button_bezel(ctx, x, y, el.frame.width, el.frame.height, el.box.radius,
						el.enabled)
				} else {
					// Gradients fill views; a button keeps its solid fill, as natively.
					draw_box_fill(ctx, x, y, el.frame.width, el.frame.height, BoxStyle{
						...el.box
						gradient: Gradient{}
					})
				}
				draw_box_borders(ctx, x, y, el.frame.width, el.frame.height, el.box)
				image_layout := button_image_layout(el.frame.width, el.frame.height, el.text,
					el.image_path)
				if image_layout.visible {
					draw_button_image(ctx, el.image_path, x + image_layout.image.x,
						y + image_layout.image.y, image_layout.image.width, image_layout.image.height,
						el.text_style)
				}
				if el.text.len > 0 && image_layout.has_title_area() {
					shortened := draw_text_centered(ctx, el.text, x + image_layout.text.x,
						y + image_layout.text.y, image_layout.text.width, image_layout.text.height,
						el.text_style)
					add_full_text_tooltip(el, area, clip, el.text, shortened)
				}
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
				if el.native_style && box.bg == unstyled_box_bg {
					draw_button_bezel(ctx, x, y, el.frame.width, el.frame.height, box.radius,
						el.enabled)
				} else {
					draw_box_fill(ctx, x, y, el.frame.width, el.frame.height, BoxStyle{
						...box
						gradient: Gradient{}
					})
				}
				draw_box_borders(ctx, x, y, el.frame.width, el.frame.height, box)
				shortened := draw_text_centered(ctx, el.text, x, y, el.frame.width, el.frame.height,
					style)
				add_full_text_tooltip(el, area, clip, el.text, shortened)
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
				mut checked := el.checked
				if el.id.len > 0 {
					previous_declared := g_checkbox_declared[el.id] or { el.checked }
					previous_value := g_checkbox_values[el.id] or { el.checked }
					if el.id !in g_checkbox_values
						|| (previous_declared != el.checked && previous_value != el.checked) {
						g_checkbox_values[el.id] = el.checked
					}
					checked = g_checkbox_values[el.id] or { el.checked }
					g_checkbox_declared[el.id] = el.checked
					g_active_checkboxes[el.id] = true
				}
				box_size := if el.frame.height < 18 { el.frame.height } else { 18.0 }
				box_y := y + (el.frame.height - box_size) / 2
				fill := if checked {
					if el.enabled { u32(0x3478d4) } else { u32(0x94a3b8) }
				} else {
					u32(0xffffff)
				}
				border := if checked {
					if el.enabled { u32(0x2f6fc4) } else { u32(0x94a3b8) }
				} else if el.enabled {
					u32(0x64748b)
				} else {
					u32(0xcbd5e1)
				}
				draw_rect(ctx, x, box_y, box_size, box_size, fill, 4)
				draw_outline(ctx, x, box_y, box_size, box_size, border, 4)
				if checked {
					draw_check_mark(ctx, x, box_y, box_size, if el.enabled { u32(0xffffff) } else { u32(0xf8fafc) })
				}
				shortened := draw_text(ctx, el.text, x + box_size + 8, y, el.frame.width - box_size - 8,
					el.frame.height, el.text_style)
				add_full_text_tooltip(el, area, clip, el.text, shortened)
				if el.enabled {
					add_hit_target(HitTarget{
						id: el.id
						action_id: element_action_id(el)
						x: x
						y: y
						w: el.frame.width
						h: el.frame.height
						checkbox: true
						checkbox_state: checked
					}, clip)
				}
			}
			.dropdown {
				x := el.frame.x + off_x
				y := el.frame.y + off_y
				previous_prop := g_text_props[el.id] or { el.text }
				kind_changed := el.id in g_text_kinds && (g_text_kinds[el.id] or { el.kind }) != el.kind
				if kind_changed || el.id !in g_text_values || (el.text != previous_prop && (g_text_values[el.id] or { '' }) != el.text) {
					replace_text_value(el.id, el.text)
				}
				if el.id !in g_text_props || el.text != previous_prop {
					replace_text_prop(el.id, el.text)
				}
				g_text_kinds[el.id] = el.kind
				g_active_fields[el.id] = true
				selected := g_text_values[el.id] or { el.text }
				list_open := el.enabled && el.id.len > 0 && g_open_dropdown == el.id
				draw_control_surface(ctx, x, y, el.frame.width, el.frame.height, el.box,
					list_open, el.enabled)
				padding := if el.padding_left > 0 { el.padding_left } else { 12.0 }
				text_width := if el.frame.width > padding + 32 { el.frame.width - padding - 32 } else { 0.0 }
				shortened := draw_text(ctx, selected, x + padding, y, text_width, el.frame.height,
					el.text_style)
				add_full_text_tooltip(el, area, clip, selected, shortened)
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
					replace_text_value(el.id, el.text)
					replace_text_editor(el.id, text_editor(el.text.clone()))
				}
				if el.id !in g_text_props || el.text != previous_prop {
					replace_text_prop(el.id, el.text)
				}
				g_text_kinds[el.id] = el.kind
				g_text_secure[el.id] = el.secure
				g_active_fields[el.id] = true
				current_text := g_text_values[el.id] or { el.text }
				mut editor := g_text_editors[el.id] or { text_editor(current_text.clone()) }
				if editor.text != current_text {
					editor.set_text(current_text.clone())
					replace_text_editor(el.id, editor)
				}
				display_text := text_field_display_text(current_text, el.secure)
				is_focused := g_focused_field == el.id
				draw_control_surface(ctx, x, y, el.frame.width, el.frame.height, el.box,
					is_focused, el.enabled)
				// Editable text is not ellipsized: keep its full value for caret and
				// selection measurement, but paint only inside the input's viewport.
				content_clip := intersect_rect(text_field_content_rect(rect(x, y,
					el.frame.width, el.frame.height), padding_left), clip)
				if content_clip.width > 0 && content_clip.height > 0 {
					apply_clip(ctx, content_clip)
					if is_focused && !editor.selection.collapsed() {
						draw_text_field_selection(ctx, display_text, editor.selection, x + padding_left,
							y, content_width, el.frame.height, el.text_style)
					}
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
						text_origin := text_field_aligned_text_origin(x + padding_left, content_width,
							f64(ctx.text_width(display_text)), el.text_style.align)
						cursor_x := text_origin + text_w
						cursor_y := y + el.frame.height * 0.2
						cursor_h := el.frame.height * 0.6
						draw_rect(ctx, cursor_x, cursor_y, 2, cursor_h, el.text_style.color, 0)
					}
					apply_clip(ctx, clip)
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
					replace_text_value(el.id, el.text)
					replace_text_editor(el.id, text_editor(el.text.clone()))
				}
				if el.id !in g_text_props || el.text != previous_prop {
					replace_text_prop(el.id, el.text)
				}
				g_text_kinds[el.id] = el.kind
				g_text_secure[el.id] = el.secure
				g_active_fields[el.id] = true
				current_text := g_text_values[el.id] or { el.text }
				if el.box.transparent {
					// A transparent text area sits on what is behind it, as on AppKit:
					// only its declared borders, and the focus outline while focused.
					draw_box_borders(ctx, x, y, el.frame.width, el.frame.height, el.box)
					if g_focused_field == el.id {
						draw_outline(ctx, x, y, el.frame.width, el.frame.height, 0x3478d4, el.box.radius)
					}
				} else {
					draw_control_surface(ctx, x, y, el.frame.width, el.frame.height, el.box,
						g_focused_field == el.id, el.enabled)
				}
				draw_text_area_content(ctx, el, current_text, x, y, clip, scroll_parent_id)
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
					current = slider_live_value(el.id, el.value, spec)
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
				thumb_size := if el.slider_style.thumb_size < 0 {
					0.0
				} else if el.slider_style.thumb_size > 0 {
					el.slider_style.thumb_size
				} else {
					20.0
				}
				// A disabled slider keeps its own colors, faded halfway into its track,
				// so it still suits a dark theme.
				track_color := el.slider_style.track_color
				value_color := if el.enabled {
					el.slider_style.value_track_color
				} else {
					slider_faded_color(el.slider_style.value_track_color, track_color)
				}
				thumb_color := if el.enabled {
					el.slider_style.thumb_color
				} else {
					slider_faded_color(el.slider_style.thumb_color, track_color)
				}
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
					if thumb_size > 0 {
						draw_rect(ctx, frame.x + (frame.width - thumb_size) / 2,
							thumb_y - thumb_size / 2, thumb_size, thumb_size, thumb_color,
							thumb_size / 2)
					}
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
					if thumb_size > 0 {
						draw_rect(ctx, thumb_x - thumb_size / 2,
							frame.y + (frame.height - thumb_size) / 2, thumb_size, thumb_size,
							thumb_color, thumb_size / 2)
					}
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
		// Round the physical clip edges outward as a pair. Casting the logical
		// origin and extent separately, then scaling both in gg, can drop up to
		// two pixels at fractional scales because the two truncations compound.
		ctx.scissor_rectf(clip.x, clip.y, clip.width, clip.height)
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

	fn register_gl_surface(id string, x f64, y f64, w f64, h f64) {
		g_opengl_surface_frames[id] = Rect{x: x, y: y, width: w, height: h}
	}

	// make_gl_surface_texture wraps a GL texture as a sokol image with its sampler.
	// The GL texture stays owned by the application.
	fn make_gl_surface_texture(request GlTextureRequest) GlSurfaceTexture {
		mut desc := gfx.ImageDesc{
			width:        request.width
			height:       request.height
			pixel_format: .rgba8
		}
		desc.gl_textures[0] = request.gl_texture
		return GlSurfaceTexture{
			gl_texture: request.gl_texture
			width:      request.width
			height:     request.height
			image:      gfx.make_image(&desc)
			sampler:    gfx.make_sampler(&gfx.SamplerDesc{
				min_filter: .linear
				mag_filter: .linear
				wrap_u:     .clamp_to_edge
				wrap_v:     .clamp_to_edge
			})
		}
	}

	fn release_gl_surface_texture(tex GlSurfaceTexture) {
		gfx.destroy_image(tex.image)
		gfx.destroy_sampler(tex.sampler)
	}

	// sync_gl_surface_textures runs before each frame, outside its render pass. It drops
	// the requests and textures of elements that were not drawn last frame, and wraps
	// new or changed requests as sokol images.
	fn sync_gl_surface_textures() {
		for id in g_gl_surface_requests.keys() {
			if id !in g_opengl_surface_frames {
				g_gl_surface_requests.delete(id)
			}
		}
		for id in g_gl_surface_textures.keys() {
			if id !in g_gl_surface_requests {
				release_gl_surface_texture(g_gl_surface_textures[id] or { continue })
				g_gl_surface_textures.delete(id)
			}
		}
		for id, request in g_gl_surface_requests {
			if current := g_gl_surface_textures[id] {
				if current.gl_texture == request.gl_texture && current.width == request.width
					&& current.height == request.height {
					continue
				}
				release_gl_surface_texture(current)
			}
			g_gl_surface_textures[id] = make_gl_surface_texture(request)
		}
	}

	// draw_gl_surface_quad draws the texture over the element's frame. Texture rows run
	// bottom-up, so the top edge of the frame takes the texture's top row at v = 1.
	// The renderer takes framebuffer pixels, the way gg's own draw helpers hand
	// it them: each layout coordinate is multiplied by the context's scale.
	// Skipping that drew the surface at 1/scale of its frame.
	// The quad covers exactly the texture's pixels, which are the frame's size
	// rounded down, so the sampler never reads past the texture's edge.
	fn draw_gl_surface_quad(ctx &gg.Context, tex GlSurfaceTexture, x f64, y f64, w f64, h f64) {
		s := f64(ctx.scale)
		x0 := x * s
		y0 := y * s
		x1 := x0 + f64(tex.width)
		y1 := y0 + f64(tex.height)
		ctx.r.enable_texture()
		ctx.r.texture(tex.image, tex.sampler)
		ctx.r.begin_quads()
		ctx.r.v2f_t2f_c4f(f32(x0), f32(y0), 0, 1, 1, 1, 1, 1)
		ctx.r.v2f_t2f_c4f(f32(x1), f32(y0), 1, 1, 1, 1, 1, 1)
		ctx.r.v2f_t2f_c4f(f32(x1), f32(y1), 1, 0, 1, 1, 1, 1)
		ctx.r.v2f_t2f_c4f(f32(x0), f32(y1), 0, 0, 1, 1, 1, 1)
		ctx.r.end()
		ctx.r.disable_texture()
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

	struct ButtonImageLayout {
		visible bool
		image   Rect
		text    Rect
	}

	fn (layout ButtonImageLayout) has_title_area() bool {
		return layout.text.width > 0 && layout.text.height > 0
	}

	// button_image_layout mirrors the native desktop button arrangements: compact
	// buttons put a 13-point image beside their title, while tall ribbon buttons
	// put a larger image above it. Image-only title-bar buttons stay centered.
	fn button_image_layout(width f64, height f64, title string, image_path string) ButtonImageLayout {
		if image_path.trim_space().len == 0 {
			return ButtonImageLayout{
				text: rect(0, 0, width, height)
			}
		}
		if title.len == 0 {
			// Image-only ribbon controls still use the large-button treatment when
			// they are tall. Compact controls need only a two-point inset on each
			// side; the previous four-point inset made 17px toolbar symbols nearly
			// illegible on Windows.
			size := if height >= 42 {
				math.min(32.0, math.max(math.min(width - 8.0, height - 12.0), 1.0))
			} else {
				math.min(18.0, math.max(math.min(width, height) - 4.0, 1.0))
			}
			return ButtonImageLayout{
				visible: true
				image: rect((width - size) / 2, (height - size) / 2, size, size)
				text: rect(0, 0, 0, 0)
			}
		}
		if height >= 42 {
			size := math.min(32.0, math.max(math.min(width, height - 22.0) - 8.0, 1.0))
			return ButtonImageLayout{
				visible: true
				image: rect((width - size) / 2, 4, size, size)
				text: rect(2, height - 23, math.max(width - 4.0, 0.0), 20)
			}
		}
		size := math.min(13.0, math.max(height - 8.0, 1.0))
		return ButtonImageLayout{
			visible: true
			image: rect(5, (height - size) / 2, size, size)
			text: rect(size + 9, 0, math.max(width - size - 13.0, 0.0), height)
		}
	}

	// draw_symbol_image draws a `symbol:` image as its Material Icons glyph, as large
	// as the frame allows and in the element's text color, which is what tints a
	// symbol image on every backend.
	// A Material glyph is as wide as its size. A fractional size is rounded when
	// the font is set, which could make the glyph wider than its frame and have
	// it cut down to an ellipsis, so symbols are sized in whole points.
	fn draw_symbol_image(ctx &gg.Context, name string, x f64, y f64, width f64, height f64, color u32) {
		size := math.floor(math.min(width, height))
		if size <= 0 {
			return
		}
		draw_text_centered(ctx, symbol_glyph(name), x, y, width, height, TextStyle{
			color:       color
			font_family: 'Material Icons'
			size:        size
		})
	}

	fn draw_button_image(ctx &gg.Context, image_path string, x f64, y f64, width f64, height f64, style TextStyle) {
		if image_path.starts_with('symbol:') {
			symbol := symbol_glyph(image_path['symbol:'.len..])
			draw_text_centered(ctx, symbol, x, y, width, height, TextStyle{
				...style
				font_family: 'Material Icons'
				size:        math.floor(math.max(math.min(width, height) * 0.75, 8.0))
			})
			return
		}
		if !draw_cached_image(ctx, image_path, x, y, width, height, 0) {
			draw_outline(ctx, x, y, width, height, 0x94a3b8, 2)
		}
	}

	fn preload_images(el Element) {
		if el.hidden {
			return
		}
		if (el.kind == .image || (el.kind == .button && el.image_path.trim_space().len > 0))
			&& !el.image_path.starts_with('symbol:') {
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
		// `create_image` keeps an uninitialized copy in gg's post-startup image
		// cache on the Linux renderer. Loading from bytes uses the initialized
		// cache path, so raster images added after startup are drawable too.
		image_bytes := os.read_bytes(path) or {
			eprintln('ui2: could not read image `${path}`: ${err}')
			return false
		}
		loaded_image := image_ctx.create_image_from_byte_array(image_bytes, gg.ImageConfig{}) or {
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
			fill_rounded_rect(ctx, x, y, w, h, radius, c)
		} else {
			ctx.draw_rect_filled(f32(x), f32(y), f32(w), f32(h), c)
		}
	}

	// fill_rounded_rect fills a rounded rectangle as a fan from its center. gg's
	// own spends a fixed few hundred vertices on each one whatever its size, and
	// sokol-gl draws at most 65536 a frame, so a window full of rounded controls
	// came out blank; here each corner gets as many segments as its radius needs
	// to look round, from 2 to 16.
	fn fill_rounded_rect(ctx &gg.Context, x f64, y f64, w f64, h f64, radius f64, c gg.Color) {
		if w <= 0 || h <= 0 {
			return
		}
		r := math.max(0, math.min(radius, math.min(w, h) / 2))
		scale := f64(ctx.scale)
		segments := int(math.min(math.max(math.sqrt(r * scale) * 1.5, 2), 16))
		mut points := g_outline_points
		points.clear()
		rounded_outline(mut points, x, y, w, h, r, segments)
		unsafe {
			g_outline_points = points
		}
		if c.a != 255 {
			ctx.r.load_pipeline(ctx.pipeline.alpha)
		}
		ctx.r.c4b(c.r, c.g, c.b, c.a)
		cx := f32((x + w / 2) * scale)
		cy := f32((y + h / 2) * scale)
		ctx.r.begin_triangles()
		count := points.len / 2
		for i in 0 .. count {
			j := (i + 1) % count
			ctx.r.v2f(cx, cy)
			ctx.r.v2f(f32(points[2 * i] * scale), f32(points[2 * i + 1] * scale))
			ctx.r.v2f(f32(points[2 * j] * scale), f32(points[2 * j + 1] * scale))
		}
		ctx.r.end()
	}

	fn draw_rect_alpha(ctx &gg.Context, x f64, y f64, w f64, h f64, color_hex u32, alpha f64, radius f64) {
		if w <= 0 || h <= 0 || alpha <= 0 {
			return
		}
		c := gg.Color{
			...hex_color(color_hex)
			a: u8(math.round(unit_clamp(alpha) * 255))
		}
		if radius > 0 {
			fill_rounded_rect(ctx, x, y, w, h, radius, c)
		} else {
			ctx.draw_rect_filled(f32(x), f32(y), f32(w), f32(h), c)
		}
	}

	// draw_box_fill paints what a BoxStyle puts beneath its borders: the drop
	// shadow, then the gradient or the solid color at the box's fill opacity.
	fn draw_box_fill(ctx &gg.Context, x f64, y f64, w f64, h f64, box BoxStyle) {
		if box_has_shadow(box) {
			draw_box_shadow(ctx, x, y, w, h, box.radius, box.shadow)
		}
		opacity := box_fill_opacity(box)
		if opacity <= 0 {
			return
		}
		if box_has_gradient(box) {
			draw_gradient_rect(ctx, x, y, w, h, box.radius, box.gradient, opacity)
		} else if opacity >= 1 {
			draw_rect(ctx, x, y, w, h, box.bg, box.radius)
		} else {
			draw_rect_alpha(ctx, x, y, w, h, box.bg, opacity, box.radius)
		}
	}

	// draw_box_shadow stands in for a Gaussian blur with a stack of translucent
	// rounded rectangles, from `blur / 2` outside the shadow's edge to `blur / 2`
	// inside it. Where k of the n layers overlap the alpha is 1 - (1 - a)^k, so
	// it rises across the blur and reaches the shadow's opacity inside it.
	fn draw_box_shadow(ctx &gg.Context, x f64, y f64, w f64, h f64, radius f64, shadow BoxShadow) {
		opacity := unit_clamp(shadow.opacity)
		sx := x + shadow.x - shadow.spread
		sy := y + shadow.y - shadow.spread
		sw := w + 2 * shadow.spread
		sh := h + 2 * shadow.spread
		sr := math.max(radius + shadow.spread, 0)
		blur := if math.is_nan(shadow.blur) { 0.0 } else { math.max(shadow.blur, 0) }
		if blur < 1 {
			draw_rect_alpha(ctx, sx, sy, sw, sh, shadow.color, opacity, sr)
			return
		}
		steps := int(math.min(math.max(blur / 2 + 2, 3), 10))
		per_layer := 1 - math.pow(1 - opacity, 1.0 / f64(steps))
		for i in 0 .. steps {
			grow := blur / 2 - blur * f64(i) / f64(steps - 1)
			layer_w := sw + 2 * grow
			layer_h := sh + 2 * grow
			if layer_w <= 0 || layer_h <= 0 {
				continue
			}
			layer_r := math.min(math.max(sr + grow, 0), math.min(layer_w, layer_h) / 2)
			draw_rect_alpha(ctx, sx - grow, sy - grow, layer_w, layer_h, shadow.color, per_layer,
				layer_r)
		}
	}

	// rounded_inset is how far in from the side a rounded box's edge is at height
	// `y` from its top, for corner radius r.
	fn rounded_inset(y f64, h f64, r f64) f64 {
		dy := if y < r { r - y } else if y > h - r { y - (h - r) } else { 0.0 }
		if dy <= 0 || r <= 0 {
			return 0
		}
		return r - math.sqrt(math.max(r * r - dy * dy, 0))
	}

	// draw_gradient_rect fills a (rounded) box with a linear gradient. The box is
	// cut into rows that follow its rounded edge and the rows into small cells,
	// each a quad whose corners take the gradient's color there; the GPU blends
	// across a cell, which is exact for a gradient between two stops and close for
	// more.
	fn draw_gradient_rect(ctx &gg.Context, x f64, y f64, w f64, h f64, radius f64, gradient Gradient, opacity f64) {
		if w <= 0 || h <= 0 {
			return
		}
		stops := gradient_sorted_stops(gradient)
		line := gradient_line(gradient.angle, w, h)
		r := math.max(0, math.min(radius, math.min(w, h) / 2))
		scale := f64(ctx.scale)
		if r < 0.5 && draw_square_gradient(ctx, x, y, w, h, line, stops, gradient.angle, opacity) {
			return
		}
		// About 16 cells each way, whatever the size, keeps a gradient to a few
		// thousand vertices of sokol-gl's 65536 a frame. Across the rounded corners
		// the rows are spaced by equal angles on the arc, as fill_rounded_rect places
		// its points, so they bunch up where the edge turns fastest.
		cell_w := math.max(4.0, w / 16)
		cell_h := math.max(4.0, (h - 2 * r) / 16)
		arc_rows := int(math.min(math.max(math.sqrt(r * scale) * 1.5, 2), 16))
		mut rows := [0.0]
		if r > 0 {
			for k in 1 .. arc_rows + 1 {
				rows << r - r * math.cos(math.pi / 2 * f64(k) / f64(arc_rows))
			}
		}
		for rows[rows.len - 1] + cell_h < h - r {
			rows << rows[rows.len - 1] + cell_h
		}
		if r > 0 {
			for k in 0 .. arc_rows + 1 {
				rows << h - r + r * math.sin(math.pi / 2 * f64(k) / f64(arc_rows))
			}
		} else {
			rows << h
		}
		ctx.r.load_pipeline(ctx.pipeline.alpha)
		ctx.r.begin_quads()
		for i in 1 .. rows.len {
			top := rows[i - 1]
			bottom := math.min(rows[i], h)
			if bottom <= top {
				continue
			}
			inset_top := rounded_inset(top, h, r)
			inset_bottom := rounded_inset(bottom, h, r)
			columns := int(math.ceil(w / cell_w))
			for c in 0 .. columns {
				f0 := f64(c) / f64(columns)
				f1 := f64(c + 1) / f64(columns)
				xt0 := inset_top + (w - 2 * inset_top) * f0
				xt1 := inset_top + (w - 2 * inset_top) * f1
				xb0 := inset_bottom + (w - 2 * inset_bottom) * f0
				xb1 := inset_bottom + (w - 2 * inset_bottom) * f1
				gradient_vertex(ctx, line, stops, opacity, x, y, xt0, top, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, xt1, top, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, xb1, bottom, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, xb0, bottom, scale)
			}
		}
		ctx.r.end()
	}

	// draw_square_gradient draws the exact gradient of a square-cornered box from a
	// handful of quads: one for two stops, whose color is linear across the whole
	// box, or one per stop for a horizontal or vertical gradient. It leaves other
	// gradients to the mesh and reports whether it drew.
	fn draw_square_gradient(ctx &gg.Context, x f64, y f64, w f64, h f64, line GradientLine, stops []GradientStop, angle f64, opacity f64) bool {
		scale := f64(ctx.scale)
		if stops.len == 2 {
			ctx.r.load_pipeline(ctx.pipeline.alpha)
			ctx.r.begin_quads()
			gradient_vertex(ctx, line, stops, opacity, x, y, 0, 0, scale)
			gradient_vertex(ctx, line, stops, opacity, x, y, w, 0, scale)
			gradient_vertex(ctx, line, stops, opacity, x, y, w, h, scale)
			gradient_vertex(ctx, line, stops, opacity, x, y, 0, h, scale)
			ctx.r.end()
			return true
		}
		turn := math.fmod(math.fmod(angle, 360) + 360, 360)
		if turn !in [0.0, 90.0, 180.0, 270.0] {
			return false
		}
		horizontal := turn == 0 || turn == 180
		extent := if horizontal { w } else { h }
		mut cuts := [0.0, 1.0]
		for stop in stops {
			cuts << stop.position
		}
		cuts.sort()
		ctx.r.load_pipeline(ctx.pipeline.alpha)
		ctx.r.begin_quads()
		for i in 1 .. cuts.len {
			// Positions run along the gradient, which may point back along the axis.
			a := if turn == 180 || turn == 270 { 1 - cuts[i] } else { cuts[i - 1] }
			b := if turn == 180 || turn == 270 { 1 - cuts[i - 1] } else { cuts[i] }
			if b - a <= 0 {
				continue
			}
			if horizontal {
				gradient_vertex(ctx, line, stops, opacity, x, y, a * extent, 0, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, b * extent, 0, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, b * extent, h, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, a * extent, h, scale)
			} else {
				gradient_vertex(ctx, line, stops, opacity, x, y, 0, a * extent, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, w, a * extent, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, w, b * extent, scale)
				gradient_vertex(ctx, line, stops, opacity, x, y, 0, b * extent, scale)
			}
		}
		ctx.r.end()
		return true
	}

	fn gradient_vertex(ctx &gg.Context, line GradientLine, stops []GradientStop, opacity f64, ox f64, oy f64, lx f64, ly f64, scale f64) {
		color, alpha := gradient_color_at(stops, gradient_position(line, lx, ly))
		ctx.r.c4b(u8((color >> 16) & 0xff), u8((color >> 8) & 0xff), u8(color & 0xff), u8(math.round(alpha * opacity * 255)))
		ctx.r.v2f(f32((ox + lx) * scale), f32((oy + ly) * scale))
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
		rounded := box_rounded_border(box)
		if rounded > 0 {
			draw_rounded_ring(ctx, x, y, w, h, box.radius, box_border_width(rounded, math.min(w,
				h) / 2), box.border_color)
			return
		}
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

	// rounded_outline lists points around a rounded rectangle, clockwise from the
	// start of its top-left corner, with the same count whatever the radius so
	// an outer and an inner outline pair up point for point.
	fn rounded_outline(mut points []f64, x f64, y f64, w f64, h f64, radius f64, segments int) {
		r := math.max(0, math.min(radius, math.min(w, h) / 2))
		for corner in 0 .. 4 {
			cx := if corner == 1 || corner == 2 { x + w - r } else { x + r }
			cy := if corner < 2 { y + r } else { y + h - r }
			start := math.pi * (1.0 + 0.5 * f64(corner))
			for i in 0 .. segments + 1 {
				angle := start + math.pi / 2 * f64(i) / f64(segments)
				points << cx + r * math.cos(angle)
				points << cy + r * math.sin(angle)
			}
		}
	}

	// draw_rounded_ring draws an even border that follows a box's rounded
	// corners: the band between its outline and the outline `width` inside it.
	fn draw_rounded_ring(ctx &gg.Context, x f64, y f64, w f64, h f64, radius f64, width f64, color_hex u32) {
		if width <= 0 || w <= 0 || h <= 0 {
			return
		}
		segments := int(math.max(4, math.min(16, radius / 2)))
		mut outer := g_outline_outer
		mut inner := g_outline_inner
		outer.clear()
		inner.clear()
		rounded_outline(mut outer, x, y, w, h, radius, segments)
		rounded_outline(mut inner, x + width, y + width, w - 2 * width, h - 2 * width, radius - width,
			segments)
		unsafe {
			g_outline_outer = outer
		}
		unsafe {
			g_outline_inner = inner
		}
		count := outer.len / 2
		c := hex_color(color_hex)
		scale := f64(ctx.scale)
		ctx.r.load_pipeline(ctx.pipeline.alpha)
		ctx.r.c4b(c.r, c.g, c.b, c.a)
		ctx.r.begin_triangle_strip()
		for i in 0 .. count + 1 {
			k := i % count
			ctx.r.v2f(f32(outer[2 * k] * scale), f32(outer[2 * k + 1] * scale))
			ctx.r.v2f(f32(inner[2 * k] * scale), f32(inner[2 * k + 1] * scale))
		}
		ctx.r.end()
	}

	fn draw_control_surface(ctx &gg.Context, x f64, y f64, w f64, h f64, box BoxStyle, focused bool, enabled bool) {
		draw_rect(ctx, x, y, w, h, box.bg, box.radius)
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
		// The check is the same two-segment stroke the styled checkboxes draw
		// (see checkbox_mark_path), so every renderer's mark matches. Stroked
		// as one polyline with round caps and joins rather than two gg lines,
		// whose thick-line path anchors its rect at logical coordinates inside
		// a rotation set up in device pixels: that left a seam at the elbow
		// even at scale 1 and displaces the strokes off their endpoints at
		// higher pixel densities.
		path := path_polyline([
			path_point(size * 0.26, size * 0.52)
			path_point(size * 0.43, size * 0.69)
			path_point(size * 0.75, size * 0.33)
		], false)
		contours := path_flatten(path, 0.3)
		triangles := path_stroke_triangles(contours, math.max(1.5, size / 8), .round, .round)
		shape_triangles(ctx, triangles, x, y, f64(ctx.scale), hex_color(color_hex))
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

	fn draw_scrollbar(ctx &gg.Context, x f64, y f64, width f64, height f64, content_height f64, offset f64, persistent bool, backdrop u32) {
		bar := scrollbar_geometry(rect(x, y, width, height), content_height, offset, persistent)
		if bar.track.width <= 0 || bar.track.height <= 0 {
			return
		}
		track, thumb := scrollbar_colors(backdrop)
		draw_rect(ctx, bar.track.x, bar.track.y, bar.track.width, bar.track.height, track, 2.5)
		draw_rect(ctx, bar.thumb.x, bar.thumb.y, bar.thumb.width, bar.thumb.height, thumb, 2.5)
	}

	fn draw_scrollbar_x(ctx &gg.Context, frame Rect, content_width f64, offset f64, persistent bool, beside_vertical bool, backdrop u32) {
		bar := scrollbar_geometry_x(frame, content_width, offset, persistent, beside_vertical)
		if bar.track.width <= 0 || bar.track.height <= 0 {
			return
		}
		track, thumb := scrollbar_colors(backdrop)
		draw_rect(ctx, bar.track.x, bar.track.y, bar.track.width, bar.track.height, track, 2.5)
		draw_rect(ctx, bar.thumb.x, bar.thumb.y, bar.thumb.width, bar.thumb.height, thumb, 2.5)
	}

	// text_font_file resolves a declared family to the file fontstash has to
	// load. gg reads TextCfg.family as a path and, when it cannot read one,
	// returns without touching the font state at all, leaving the string drawn
	// in whatever the previous element used. An unknown family therefore has to
	// come back empty so the default font is used instead.
	fn text_font_file(family string, bold bool, italic bool) string {
		if family.len == 0 {
			// gg draws the default font's regular and bold faces itself, but has no
			// italic of it, and bold italic came out bold only: those come from the
			// default font's own italic files when it has them.
			return if italic { default_italic_font_file(bold) } else { '' }
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

	// default_italic_font_file is the italic (or bold italic) file beside the
	// default font's regular one, as Roboto-Italic.ttf is beside
	// Roboto-Regular.ttf, or '' when there is none.
	fn default_italic_font_file(bold bool) string {
		key := ':default:${bold}:true'
		if path := g_font_family_files[key] {
			return path
		}
		regular, _ := font_paths()
		mut path := ''
		if regular.contains('Regular') {
			candidate := regular.replace('Regular', if bold { 'BoldItalic' } else { 'Italic' })
			if os.is_file(candidate) {
				path = candidate
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
			g_text_widths.clear()
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
	// Break text into the lines a multi-line label draws: on its own newlines, and on
	// spaces wherever a line would outgrow the width. A word wider than the line is
	// left whole and truncated when it is drawn, rather than split mid-word.
	fn wrap_text_lines(ctx &gg.Context, t string, w f64, limit int, cfg gg.TextCfg) []string {
		if limit <= 1 || w <= 0 {
			return t.split('\n')
		}
		ctx.set_text_cfg(cfg)
		return wrap_text_lines_measured(t, w, limit, fn [ctx] (line string) f64 {
			return f64(ctx.text_width_f(line))
		})
	}

	fn fit_text(ctx &gg.Context, t string, w f64, cfg gg.TextCfg) string {
		if w <= 0 {
			return t
		}
		ctx.set_text_cfg(cfg)
		if f64(ctx.text_width_f(t)) <= w {
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
			if f64(ctx.text_width_f(runes[..mid].string() + text_ellipsis)) <= w {
				kept = mid
			} else {
				high = mid - 1
			}
		}
		return runes[..kept].string() + text_ellipsis
	}

	// draw_text draws text that belongs to a box, shortening it when it does
	// not fit, and reports whether it had to. A control draws its text down the
	// middle of the box whatever the style says, because a label is the only
	// thing the native backends let place its text, and a style shared with one
	// must not move a button.
	fn draw_text(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle) bool {
		return draw_text_in_box(ctx, t, x, y, w, h, centered_text_style(style), true, Rect{})
	}

	// draw_label_text draws a label, the one control whose style says where its
	// text sits in a box with room to spare. It is drawn against the clip it was
	// rendered under, so a block of lines too tall for the label stops at the
	// label rather than running on over what comes after it.
	fn draw_label_text(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle, clip Rect) bool {
		return draw_text_in_box(ctx, t, x, y, w, h, style, true, clip)
	}

	// draw_editable_text draws the text of a field the caller can type in.
	// Those controls place the caret by measuring the whole string, so a
	// shortened line would leave the caret sitting past the end of it.
	fn draw_editable_text(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle) {
		draw_text_in_box(ctx, t, x, y, w, h, centered_text_style(style), false, Rect{})
	}

	// A style that draws down the middle of its box. The caret and the selection
	// of an editable field are measured from the middle, so its text has to be
	// drawn there too.
	fn centered_text_style(style TextStyle) TextStyle {
		return TextStyle{
			...style
			valign: .middle
		}
	}

	// draw_text_field_selection paints the selected rune range before its text.
	// The range is derived from the rendered string so secure fields highlight
	// their bullet characters instead of leaking the underlying value.
	fn draw_text_field_selection(ctx &gg.Context, display_text string, selection TextSelection, x f64, y f64, w f64, h f64, style TextStyle) {
		before, selected := text_field_selection_text(display_text, selection)
		if selected.len == 0 || w <= 0 {
			return
		}
		family := text_font_file(style.font_family, style.bold, style.italic)
		ensure_family_fallbacks(ctx, family)
		ctx.set_text_cfg(gg.TextCfg{
			color: hex_color(style.color)
			size: int(font_render_size(style.size, text_font_metrics(family)) + 0.5)
			bold: style.bold
			italic: style.italic
			family: family
			align: text_align(style.align)
			vertical_align: .middle
		})
		text_width := f64(ctx.text_width(display_text))
		text_origin := text_field_aligned_text_origin(x, w, text_width, style.align)
		mut left := text_origin + f64(ctx.text_width(before))
		mut right := left + f64(ctx.text_width(selected))
		if left < x {
			left = x
		}
		if right > x + w {
			right = x + w
		}
		if right > left {
			draw_rect(ctx, left, y + h * 0.2, right - left, h * 0.6, 0xb8d7ff, 0)
		}
	}

	fn text_field_aligned_text_origin(x f64, w f64, text_width f64, align Align) f64 {
		return match align {
			.left { x }
			.center { x + (w - text_width) / 2 }
			.right { x + w - text_width }
		}
	}

	fn text_field_selection_text(display_text string, selection TextSelection) (string, string) {
		runes := display_text.runes()
		start, end := selection.ordered()
		from := clamp_int(start, 0, runes.len)
		to := clamp_int(end, from, runes.len)
		return runes[..from].string(), runes[from..to].string()
	}

	// custom_measure_text_width measures with the font and size draw_text_in_box
	// draws in; a label draws its text with no inset.
	fn custom_measure_text_width(text string, style TextStyle) f64 {
		ctx := g_gg_app.ctx
		if ctx == unsafe { nil } {
			return text_width_estimate(text, style)
		}
		family := text_font_file(style.font_family, style.bold, style.italic)
		ensure_family_fallbacks(ctx, family)
		ctx.set_text_cfg(gg.TextCfg{
			size: int(font_render_size(style.size, text_font_metrics(family)) + 0.5)
			bold: style.bold
			italic: style.italic
			family: family
		})
		return f64(ctx.text_width_f(text))
	}

	// clip is the region the caller is drawn under, and is what a block of text too
	// tall for its box is held inside. An empty one is a caller that does not bound
	// its text, which draws under whatever clip is already in force.
	//
	// The result reports text the reader cannot see: a line cut short with the
	// ellipsis, or a line of a bounded block that falls mostly below its box and is
	// clipped away. A caller offers the full text on hover when there is any.
	fn draw_text_in_box(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle, fit bool, clip Rect) bool {
		if t.len == 0 {
			return false
		}
		text_x := match style.align {
			.left { int(x) }
			.center { int(x + w / 2) }
			.right { int(x + w) }
		}
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
		line_h := font_line_height(style.size)
		line_budget := text_line_budget(style)
		parts := if line_budget > 1 {
			wrap_text_lines(ctx, t, w, line_budget, cfg)
		} else {
			[t]
		}
		block_h := f64(parts.len) * line_h
		// A block with more lines than its box has room for is anchored at the top of
		// the box and would run on out of the bottom of it, over whatever is drawn
		// below. A native control draws only inside itself, so the lines that do not
		// fit are cut off at the box rather than drawn past it.
		bounded := block_h > h && clip.width > 0 && clip.height > 0
		if bounded {
			inside := intersect_rect(Rect{
				x:      x
				y:      y
				width:  w
				height: h
			}, clip)
			if inside.width <= 0 || inside.height <= 0 {
				return false
			}
			apply_clip(ctx, inside)
		}
		// The text block is as tall as the lines it ended up with, and valign says
		// where that block sits in a frame with room to spare. draw_text is given the
		// centre of each line because the config centres a line on its baseline box.
		start_y := text_block_top(y, h, block_h, style.valign) + line_h / 2
		mut shortened := false
		for i, part in parts {
			line_y := start_y + f64(i) * line_h
			line := if fit { fit_text(ctx, part, w, cfg) } else { part }
			if line != part || (bounded && line_y > y + h) {
				shortened = true
			}
			ctx.draw_text(int(text_x), int(line_y), line, cfg)
			if style.underline || style.strikethrough {
				draw_text_decorations(ctx, line, f64(text_x), line_y, cfg, style)
			}
		}
		if bounded {
			apply_clip(ctx, clip)
		}
		return shortened
	}

	// draw_text_decorations rules a line drawn at text_x (its anchor for the
	// line's alignment) and centred on line_y. Every backend's text style carries
	// underline and strikethrough, so a custom-rendered link is underlined too.
	fn draw_text_decorations(ctx &gg.Context, line string, text_x f64, line_y f64, cfg gg.TextCfg, style TextStyle) {
		ctx.set_text_cfg(cfg)
		width := f64(ctx.text_width_f(line))
		if width <= 0 {
			return
		}
		left := match style.align {
			.left { text_x }
			.center { text_x - width / 2 }
			.right { text_x - width }
		}
		size := f64(cfg.size)
		thickness := math.max(1.0, math.round(size / 14))
		if style.underline {
			draw_rect(ctx, left, line_y + size * 0.42, width, thickness, style.color, 0)
		}
		if style.strikethrough {
			draw_rect(ctx, left, line_y - thickness / 2, width, thickness, style.color, 0)
		}
	}

	fn draw_text_centered(ctx &gg.Context, t string, x f64, y f64, w f64, h f64, style TextStyle) bool {
		centered_style := TextStyle{
			...style
			align: .center
		}
		return draw_text(ctx, t, x, y, w, h, centered_style)
	}
}
