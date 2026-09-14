// vfmt off
// Keep Win32 declarations out of opt-in custom-renderer builds.
module ui2

$if !ui2_custom_rendering ? {

#flag windows -luser32

#flag windows -lgdi32

#flag windows -lcomctl32

#flag windows -lshell32

#insert "@VMODROOT/windows/native_helpers_windows.h"

fn C.ui2_win_register_classes() int

fn C.ui2_win_visual_styles_enabled() int

fn C.ui2_win_create_main_window(title &u16, width int, height int) voidptr

fn C.ui2_win_apply_min_size(hwnd voidptr, lparam isize, width int, height int)

fn C.ui2_win_set_window_title(hwnd voidptr, title &u16)

fn C.ui2_win_create_widget(kind int, parent voidptr, x int, y int, width int, height int, text &u16, alignment int, secure int, readonly int, disable_scroll int, vertical int) voidptr
fn C.ui2_win_label_content_height(hwnd voidptr, width int, lines int) int
fn C.ui2_win_label_text_hwnd(hwnd voidptr) voidptr

fn C.ui2_win_show_main_window(hwnd voidptr)

fn C.ui2_win_message_loop() int

fn C.ui2_win_default_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize

fn C.ui2_win_post_quit(code int)

fn C.ui2_win_post_refresh(hwnd voidptr)

fn C.ui2_win_close(hwnd voidptr)

fn C.ui2_win_destroy(hwnd voidptr)

fn C.ui2_win_is_window(hwnd voidptr) int

fn C.ui2_win_parent(hwnd voidptr) voidptr

fn C.ui2_win_set_parent(hwnd voidptr, parent voidptr)

fn C.ui2_win_set_widget_frame(hwnd voidptr, kind int, x int, y int, width int, height int)

fn C.ui2_win_place_after(hwnd voidptr, previous voidptr)

fn C.ui2_win_show(hwnd voidptr, visible int)

fn C.ui2_win_enable(hwnd voidptr, enabled int)

fn C.ui2_win_create_tooltip(hwnd voidptr, text &u16) voidptr

fn C.ui2_win_tooltip_add_target(tooltip voidptr, target voidptr) int

fn C.ui2_win_border_width(width f64, extent int) int

fn C.ui2_win_destroy_tooltip(tooltip voidptr)

fn C.ui2_win_focus(hwnd voidptr)

fn C.ui2_win_focus_handle() voidptr

fn C.ui2_win_clear_focus(root voidptr)

fn C.ui2_win_client_width(hwnd voidptr) int

fn C.ui2_win_client_height(hwnd voidptr) int

fn C.ui2_win_text_length(hwnd voidptr) int

fn C.ui2_win_get_text(hwnd voidptr, buffer &u16, capacity int) int

fn C.ui2_win_set_text(hwnd voidptr, text &u16)

fn C.ui2_win_set_checked(hwnd voidptr, checked int)

fn C.ui2_win_get_checked(hwnd voidptr) int

fn C.ui2_win_slider_set_normalized(hwnd voidptr, normalized f64, vertical int)

fn C.ui2_win_slider_normalized(hwnd voidptr, vertical int) f64

fn C.ui2_win_set_edit_options(hwnd voidptr, placeholder &u16, readonly int, padding_left int)

fn C.ui2_win_placeholder_matches(hwnd voidptr, expected &u16) int

fn C.ui2_win_widget_style(hwnd voidptr) usize

fn C.ui2_win_get_selection(hwnd voidptr, start &u32, end &u32)

fn C.ui2_win_set_selection(hwnd voidptr, start u32, end u32, focus int)

fn C.ui2_win_replace_selection(hwnd voidptr, text &u16)

fn C.ui2_win_combo_reset(hwnd voidptr)

fn C.ui2_win_combo_add(hwnd voidptr, text &u16)

fn C.ui2_win_combo_select_text(hwnd voidptr, text &u16)

fn C.ui2_win_create_font(hwnd voidptr, point_size f64, family &u16, bold int, italic int, underline int, strikeout int, text &u16) voidptr

fn C.ui2_win_apply_text_font(hwnd voidptr, text &u16)

fn C.ui2_win_font_missing_glyphs(font voidptr, text &u16) int

fn C.ui2_win_font_family(font voidptr, buffer &u16, capacity int)

fn C.ui2_win_widget_font(hwnd voidptr) voidptr

fn C.ui2_win_apply_font(hwnd voidptr, font voidptr)

fn C.ui2_win_create_brush(color u32) voidptr

fn C.ui2_win_delete_object(object voidptr)

fn C.ui2_win_apply_control_colors(dc voidptr, foreground u32, background u32, transparent int, brush voidptr) isize

fn C.ui2_win_paint_background(hwnd voidptr, background u32, radius f64, transparent int, border_color u32, border_left f64, border_top f64, border_right f64, border_bottom f64)

fn C.ui2_win_paint_background_into(hwnd voidptr, dc voidptr, background u32, radius f64, transparent int, border_color u32, border_left f64, border_top f64, border_right f64, border_bottom f64)

fn C.ui2_win_paint_transparent_button(hwnd voidptr, foreground u32, radius f64, border_color u32, border_left f64, border_top f64, border_right f64, border_bottom f64)

fn C.ui2_win_paint_control_border(hwnd voidptr, color u32, radius f64, left f64, top f64, right f64, bottom f64)

fn C.ui2_win_invalidate(hwnd voidptr)

fn C.ui2_win_invalidate_parent(hwnd voidptr)

fn C.ui2_win_set_bitmap(hwnd voidptr, path &u16, width int, height int) voidptr

fn C.ui2_win_clear_bitmap(hwnd voidptr)

fn C.ui2_win_set_scroll(hwnd voidptr, content_height int, position int) int

fn C.ui2_win_scroll_message(hwnd voidptr, wparam usize) int

fn C.ui2_win_scroll_wheel(hwnd voidptr, wparam usize) int

fn C.ui2_win_scroll_to_rect(hwnd voidptr, top int, bottom int) int
fn C.ui2_win_set_scroll_position(hwnd voidptr, position int) int

fn C.ui2_win_capture_mouse(hwnd voidptr)

fn C.ui2_win_release_mouse()

fn C.ui2_win_ticks() u64

fn C.ui2_win_point_to_root(hwnd voidptr, root voidptr, x &int, y &int)

fn C.ui2_win_menu_create() voidptr

fn C.ui2_win_menu_add(menu voidptr, command u32, title &u16, enabled int)

fn C.ui2_win_menu_track(menu voidptr, hwnd voidptr, x int, y int) u32

fn C.ui2_win_menu_destroy(menu voidptr)

fn C.ui2_win_drop_count(drop voidptr) u32

fn C.ui2_win_drop_path_length(drop voidptr, index u32) u32

fn C.ui2_win_drop_path(drop voidptr, index u32, buffer &u16, capacity u32)

fn C.ui2_win_drop_point(drop voidptr, x &int, y &int)

fn C.ui2_win_drop_finish(drop voidptr)

fn C.ui2_win_key_down(virtual_key int) int

const win_wm_destroy = u32(0x0002)
const win_wm_size = u32(0x0005)
const win_wm_paint = u32(0x000f)
const win_wm_close = u32(0x0010)
const win_wm_erase_background = u32(0x0014)
const win_wm_key_down = u32(0x0100)
const win_wm_command = u32(0x0111)
const win_wm_hscroll = u32(0x0114)
const win_wm_vscroll = u32(0x0115)
const win_wm_ctlcolor_edit = u32(0x0133)
const win_wm_ctlcolor_listbox = u32(0x0134)
const win_wm_ctlcolor_button = u32(0x0135)
const win_wm_ctlcolor_static = u32(0x0138)
const win_wm_mouse_move = u32(0x0200)
const win_wm_lbutton_down = u32(0x0201)
const win_wm_lbutton_up = u32(0x0202)
const win_wm_mouse_wheel = u32(0x020a)
const win_wm_dropfiles = u32(0x0233)
const win_wm_refresh = u32(0x8000 + 77)
const win_wm_paint_background = u32(0x8000 + 79)
const win_wm_getminmaxinfo = u32(0x0024)

const win_bn_clicked = 0
const win_cbn_selchange = 1
const win_en_change = 0x0300

struct WindowsRunConfig {
	title  string = 'App'
	width  int = 400
	height int = 800
	min_width  int
	min_height int
}

struct WindowsPointerBinding {
	id         string
	clickable  bool
	draggable  bool
	long_press bool
	swipe_left bool
}

@[heap]
struct WindowsState {
mut:
	build_screen       BuildFn = BuildFn(unsafe { nil })
	event_handler      EventFn = EventFn(unsafe { nil })
	key_handler        KeyFn = KeyFn(unsafe { nil })
	key_event_handler  KeyEventFn = KeyEventFn(unsafe { nil })
	scroll_handler     ScrollFn = ScrollFn(unsafe { nil })
	drop_handler       DropFn = DropFn(unsafe { nil })
	root               voidptr
	nodes              map[string]voidptr
	node_kinds         map[string]Kind
	node_parents       map[string]string
	node_frames        map[string]Rect
	node_structural    map[string]string
	node_declared_text map[string]string
	node_option_sig    map[string]string
	node_image_path    map[string]string
	node_ids           map[string]string
	node_boxes         map[string]BoxStyle
	node_text_styles   map[string]TextStyle
	fonts              map[string]voidptr
	font_sigs          map[string]string
	brushes            map[string]voidptr
	brush_sigs         map[string]u32
	images             map[string]voidptr
	tooltips           map[string]voidptr
	tooltip_sigs       map[string]string
	views              map[string]voidptr
	view_keys          map[string]string
	view_kinds         map[string]Kind
	label_frames       map[string]Rect
	handle_keys        map[u64]string
	action_ids         map[u64]string
	change_ids         map[u64]string
	submit_ids         map[u64]string
	pointer_bindings   map[u64]WindowsPointerBinding
	menus              map[u64][]MenuEntry
	cursors            map[u64]int
	scroll_ids         map[u64]string
	slider_specs       map[u64]SliderSpec
	toggle_groups      map[u64]string
	toggle_allow_no_selection map[u64]bool
	toggle_ids         map[u64]string
	toggle_views       map[u64]voidptr
	scroll_positions   map[string]int
	node_label_boxed   map[string]bool
	pending_scroll     map[string]int // Scroll element id -> offset to apply when it renders
	run_config         WindowsRunConfig
	rendering          bool
	key_consumed       bool
	pointer_handle     voidptr
	pointer_start_x    int
	pointer_start_y    int
	pointer_started    u64
	pointer_moved      bool
	suppress_click     map[u64]bool
}

const windows_state_singleton = &WindowsState{
	nodes: map[string]voidptr{}
	node_kinds: map[string]Kind{}
	node_parents: map[string]string{}
	node_frames: map[string]Rect{}
	node_structural: map[string]string{}
	node_declared_text: map[string]string{}
	node_option_sig: map[string]string{}
	node_image_path: map[string]string{}
	node_ids: map[string]string{}
	node_boxes: map[string]BoxStyle{}
	node_text_styles: map[string]TextStyle{}
	fonts: map[string]voidptr{}
	font_sigs: map[string]string{}
	brushes: map[string]voidptr{}
	brush_sigs: map[string]u32{}
	images: map[string]voidptr{}
	tooltips: map[string]voidptr{}
	tooltip_sigs: map[string]string{}
	views: map[string]voidptr{}
	view_keys: map[string]string{}
	view_kinds: map[string]Kind{}
	handle_keys: map[u64]string{}
	action_ids: map[u64]string{}
	change_ids: map[u64]string{}
	submit_ids: map[u64]string{}
	pointer_bindings: map[u64]WindowsPointerBinding{}
	menus: map[u64][]MenuEntry{}
	cursors: map[u64]int{}
	scroll_ids: map[u64]string{}
	slider_specs: map[u64]SliderSpec{}
	toggle_groups: map[u64]string{}
	toggle_allow_no_selection: map[u64]bool{}
	toggle_ids: map[u64]string{}
	toggle_views: map[u64]voidptr{}
	scroll_positions: map[string]int{}
	node_label_boxed: map[string]bool{}
	pending_scroll: map[string]int{}
	suppress_click: map[u64]bool{}
}

fn windows_state() &WindowsState {
	return unsafe { windows_state_singleton }
}

fn windows_handle_id(hwnd voidptr) u64 {
	return u64(hwnd)
}

fn windows_bool(value bool) int {
	return if value { 1 } else { 0 }
}

fn windows_uses_transparent_button_paint(kind Kind, box BoxStyle) bool {
	return box.transparent && kind in [.button, .toggle_button]
}

// Whether a window leaves the background behind it alone. A label paints none of its
// own on Windows: what shows behind its text is whatever its parent put there, which
// is what the control colour handler has always answered. The view holding a label
// has to answer the same, or a label given a border, a tooltip or a menu — any of
// which is enough to put it in one — would come out white on a parent that is not.
fn windows_draws_no_background(kind Kind, box BoxStyle) bool {
	return box.transparent || kind in [.label, .checkbox]
}

// A static control centres one line of text for itself and can do nothing about a
// wrapped block, so a label is measured and given the rectangle its text really
// needs. Every label is, not only one placed away from the top: a static draws as
// many lines as its rectangle has room for, so a frame taller than the line budget
// would otherwise show more lines than were asked for. Measuring holds it to the
// budget, and the top of the rectangle is where the alignment puts it.
//
// The measured rectangle is what gets remembered, so scrolling the pane it sits in
// takes the label with it rather than putting it back where it was laid out.
fn windows_place_label(key string, hwnd voidptr, el Element, y_offset int) {
	mut st := windows_state()
	if C.ui2_win_label_text_hwnd(hwnd) != hwnd {
		windows_place_held_label(hwnd, el)
		return
	}
	mut placed := el.frame
	if el.frame.height > 0 && el.text.len > 0 {
		content := f64(C.ui2_win_label_content_height(hwnd, int(el.frame.width), el.text_style.lines))
		if content > 0 && content < el.frame.height {
			placed = Rect{
				x:      el.frame.x
				y:      text_block_top(el.frame.y, el.frame.height, content, el.text_style.valign)
				width:  el.frame.width
				height: content
			}
		}
	}
	st.node_frames[key] = placed
	C.ui2_win_set_widget_frame(hwnd, windows_widget_kind(el.kind), int(placed.x), int(placed.y) +
		y_offset, int(placed.width), int(placed.height))
}

// Setting a label's text has to place it again. The label sits on the rectangle the
// text before it needed, so left alone it clips text that is taller and holds text
// that is shorter where it no longer belongs.
fn windows_place_label_text(id string, hwnd voidptr, value string) {
	st := windows_state()
	key := st.view_keys[id] or { return }
	frame := st.label_frames[id] or { return }
	parent_key := st.node_parents[key] or { '' }
	mut y_offset := 0
	if (st.node_kinds[parent_key] or { Kind.view }) == .scroll {
		y_offset = -(st.scroll_positions[parent_key] or { 0 })
	}
	windows_place_label(key, hwnd, Element{
		kind:       .label
		text:       value
		frame:      frame
		box:        st.node_boxes[key] or { BoxStyle{} }
		text_style: st.node_text_styles[key] or { TextStyle{} }
	}, y_offset)
}

fn windows_align(align Align) int {
	return match align {
		.left { 0 }
		.center { 1 }
		.right { 2 }
	}
}

fn windows_native_text(hwnd voidptr) string {
	length := C.ui2_win_text_length(hwnd)
	if length <= 0 {
		return ''
	}
	mut buffer := []u16{len: length + 1}
	read := C.ui2_win_get_text(hwnd, unsafe { &buffer[0] }, length + 1)
	if read <= 0 {
		return ''
	}
	return unsafe { string_from_wide2(&buffer[0], read) }
}

fn windows_set_native_text(hwnd voidptr, value string) {
	wide := value.to_wide()
	C.ui2_win_set_text(hwnd, wide)
	unsafe { free(wide) }
}

pub fn bounds() Rect {
	st := windows_state()
	if st.root == unsafe { nil } || C.ui2_win_is_window(st.root) == 0 {
		return Rect{
			width: f64(st.run_config.width)
			height: f64(st.run_config.height)
		}
	}
	return Rect{
		width: f64(C.ui2_win_client_width(st.root))
		height: f64(C.ui2_win_client_height(st.root))
	}
}

pub fn run(build_fn BuildFn, event_fn EventFn) {
	run_window('App', 400, 800, build_fn, event_fn)
}

pub fn run_window(title string, width int, height int, build_fn BuildFn, event_fn EventFn) {
	run_window_with_min_size(title, width, height, 0, 0, build_fn, event_fn)
}

fn run_window_with_min_size(title string, width int, height int, min_width int, min_height int, build_fn BuildFn, event_fn EventFn) {
	mut st := windows_state()
	st.build_screen = build_fn
	st.event_handler = event_fn
	configure_animation_driver(request_refresh, true)
	st.run_config = WindowsRunConfig{
		title: title
		width: width
		height: height
		min_width: min_width
		min_height: min_height
	}
	if C.ui2_win_register_classes() == 0 {
		eprintln('ui2: failed to register Win32 window classes')
		return
	}
	wide_title := title.to_wide()
	root := C.ui2_win_create_main_window(wide_title, width, height)
	unsafe { free(wide_title) }
	if root == unsafe { nil } {
		eprintln('ui2: failed to create the Win32 window')
		return
	}
	st.root = root
	// The menu bar and the tray can be declared before the window exists;
	// attach whatever was declared now that there is a window to attach to.
	publish_menu_context(event_fn, title, root)
	install_declared_menus()
	refresh()
	C.ui2_win_show_main_window(root)
	C.ui2_win_message_loop()
	native_remove_tray()
	windows_dispose_all()
}

pub fn refresh() {
	mut st := windows_state()
	if st.root == unsafe { nil } || st.rendering || voidptr(st.build_screen) == unsafe { nil } {
		return
	}
	declared := st.build_screen()
	root := apply_widget_animations(declared)
	validate_element_tree(root) or {
		eprintln('ui2: ${err}')
		return
	}
	st.rendering = true
	st.views = map[string]voidptr{}
	st.view_keys = map[string]string{}
	st.view_kinds = map[string]Kind{}
	st.label_frames = map[string]Rect{}
	st.handle_keys = map[u64]string{}
	st.action_ids = map[u64]string{}
	st.change_ids = map[u64]string{}
	st.submit_ids = map[u64]string{}
	st.pointer_bindings = map[u64]WindowsPointerBinding{}
	st.menus = map[u64][]MenuEntry{}
	st.cursors = map[u64]int{}
	st.scroll_ids = map[u64]string{}
	st.slider_specs = map[u64]SliderSpec{}
	st.toggle_groups = map[u64]string{}
	st.toggle_allow_no_selection = map[u64]bool{}
	st.toggle_ids = map[u64]string{}
	st.toggle_views = map[u64]voidptr{}
	mut active := map[string]bool{}
	if root.kind == .screen {
		st.node_boxes[''] = root.box
		windows_render_children(st.root, root.children, '', 0, mut active)
	} else {
		st.node_boxes[''] = BoxStyle{}
		windows_render_element(st.root, root, reconciliation_child_key('', 0, root), '', 0, mut active)
	}
	windows_remove_stale(active)
	st.rendering = false
	C.ui2_win_invalidate(st.root)
}

pub fn request_refresh() {
	st := windows_state()
	if st.root != unsafe { nil } {
		C.ui2_win_post_refresh(st.root)
	}
}

pub fn on_key(handler KeyFn) {
	mut st := windows_state()
	st.key_handler = handler
}

pub fn on_key_event(handler KeyEventFn) {
	mut st := windows_state()
	st.key_event_handler = handler
}

pub fn on_scroll(handler ScrollFn) {
	mut st := windows_state()
	st.scroll_handler = handler
}

pub fn on_drop(handler DropFn) {
	mut st := windows_state()
	st.drop_handler = handler
}

// set_window_title updates the current Win32 window title.
pub fn set_window_title(title string) {
	st := windows_state()
	if st.root != unsafe { nil } {
		wide_title := title.to_wide()
		C.ui2_win_set_window_title(st.root, wide_title)
		unsafe { free(wide_title) }
	}
}

pub fn text(id string) string {
	st := windows_state()
	hwnd := st.views[id] or { return '' }
	if (st.view_kinds[id] or { Kind.view }) == .label {
		// A label is its static control, or the view holding one.
		return windows_native_text(C.ui2_win_label_text_hwnd(hwnd))
	}
	return windows_native_text(hwnd)
}

pub fn set_text(id string, value string) {
	mut st := windows_state()
	outer := st.views[id] or { return }
	kind := st.view_kinds[id] or { Kind.view }
	mut hwnd := outer
	if kind == .label {
		hwnd = C.ui2_win_label_text_hwnd(outer)
	}
	was_rendering := st.rendering
	st.rendering = true
	if kind == .dropdown {
		wide_value := value.to_wide()
		C.ui2_win_combo_select_text(hwnd, wide_value)
		unsafe { free(wide_value) }
	} else {
		windows_set_native_text(hwnd, value)
	}
	if kind == .label {
		windows_place_label_text(id, outer, value)
	}
	st.rendering = was_rendering
}

pub fn slider_value(id string) f64 {
	st := windows_state()
	hwnd := st.views[id] or { return 0 }
	if (st.view_kinds[id] or { Kind.view }) != .slider {
		return 0
	}
	spec := st.slider_specs[windows_handle_id(hwnd)] or { return 0 }
	return windows_snap_slider_value(hwnd, spec)
}

pub fn set_slider_value(id string, value f64) {
	st := windows_state()
	hwnd := st.views[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) != .slider {
		return
	}
	spec := st.slider_specs[windows_handle_id(hwnd)] or { return }
	normalized := slider_value_normalized(slider_clamped_value(value, spec.min, spec.max),
		spec.min, spec.max)
	C.ui2_win_slider_set_normalized(hwnd, normalized,
		windows_bool(spec.orientation == .vertical))
}

pub fn switch_active(id string) bool {
	st := windows_state()
	hwnd := st.views[id] or { return false }
	if (st.view_kinds[id] or { Kind.view }) != .switch_control {
		return false
	}
	return C.ui2_win_get_checked(hwnd) != 0
}

pub fn set_switch_active(id string, active bool) {
	st := windows_state()
	hwnd := st.views[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) != .switch_control {
		return
	}
	C.ui2_win_set_checked(hwnd, windows_bool(active))
}

pub fn toggle_button_pressed(id string) bool {
	st := windows_state()
	hwnd := st.views[id] or { return false }
	if (st.view_kinds[id] or { Kind.view }) != .toggle_button {
		return false
	}
	return C.ui2_win_get_checked(hwnd) != 0
}

pub fn set_toggle_button_pressed(id string, pressed bool) {
	st := windows_state()
	hwnd := st.views[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) != .toggle_button {
		return
	}
	if pressed {
		release_windows_toggle_group(windows_handle_id(hwnd))
	}
	C.ui2_win_set_checked(hwnd, windows_bool(pressed))
}

pub fn toggle_button_group_members(id string) []string {
	st := windows_state()
	hwnd := st.views[id] or { return [] }
	handle := windows_handle_id(hwnd)
	group := st.toggle_groups[handle] or { return [id] }
	if group.len == 0 {
		return [id]
	}
	mut members := []string{}
	for member_handle, member_group in st.toggle_groups {
		if member_group == group {
			member_id := st.toggle_ids[member_handle] or { continue }
			if member_id.len > 0 {
				members << member_id
			}
		}
	}
	return members
}

fn release_windows_toggle_group(handle u64) {
	st := windows_state()
	group := st.toggle_groups[handle] or { return }
	if group.len == 0 {
		return
	}
	for member_handle, member_group in st.toggle_groups {
		if member_handle == handle || member_group != group {
			continue
		}
		native := st.toggle_views[member_handle] or { continue }
		C.ui2_win_set_checked(native, 0)
	}
}

fn commit_windows_toggle_button(handle u64, hwnd voidptr) {
	st := windows_state()
	group := st.toggle_groups[handle] or { return }
	if group.len == 0 {
		return
	}
	if C.ui2_win_get_checked(hwnd) != 0 {
		release_windows_toggle_group(handle)
	} else if !(st.toggle_allow_no_selection[handle] or { true }) {
		C.ui2_win_set_checked(hwnd, 1)
	}
}

pub fn focus(id string) {
	st := windows_state()
	hwnd := st.views[id] or { return }
	C.ui2_win_focus(hwnd)
}

pub fn focused_id() string {
	st := windows_state()
	focused := C.ui2_win_focus_handle()
	if focused == unsafe { nil } {
		return ''
	}
	key := st.handle_keys[windows_handle_id(focused)] or { return '' }
	return st.node_ids[key] or { '' }
}

pub fn focused_text_area_id() string {
	st := windows_state()
	focused := C.ui2_win_focus_handle()
	if focused == unsafe { nil } {
		return ''
	}
	key := st.handle_keys[windows_handle_id(focused)] or { return '' }
	if (st.node_kinds[key] or { Kind.view }) != .text_area {
		return ''
	}
	for id, view_key in st.view_keys {
		if view_key == key {
			return id
		}
	}
	return ''
}

pub fn dismiss_keyboard() {
	st := windows_state()
	C.ui2_win_clear_focus(st.root)
}

pub fn safe_area_top() f64 {
	return 0
}

pub fn start_barcode_scan() {
	st := windows_state()
	if voidptr(st.event_handler) != unsafe { nil } {
		st.event_handler('scan_error:barcode scanner unavailable')
	}
}

pub fn quit() {
	st := windows_state()
	C.ui2_win_close(st.root)
}

pub fn consume_key() {
	mut st := windows_state()
	st.key_consumed = true
}

pub fn consume_text_key() {
	consume_key()
}

pub fn insert_text_area_text(id string, value string) {
	hwnd := windows_text_area_handle(id) or { return }
	wide_value := value.to_wide()
	C.ui2_win_replace_selection(hwnd, wide_value)
	unsafe { free(wide_value) }
}

pub fn scroll_offset(id string) f64 {
	st := windows_state()
	key := st.view_keys[id] or { return 0 }
	return f64(st.scroll_positions[key] or { 0 })
}

// scroll_to_offset puts a Scroll element at the given vertical offset. An element on
// screen moves at once. One that does not exist yet has no range to clamp against, so
// the request is kept and taken up the next time the element is laid out — that is
// what lets a screen open where it was last left.
pub fn scroll_to_offset(id string, offset f64) {
	mut st := windows_state()
	if id.len == 0 {
		return
	}
	wanted := if offset < 0 { 0 } else { int(offset) }
	if (st.view_kinds[id] or { Kind.view }) == .scroll {
		key := st.view_keys[id] or { '' }
		if key.len > 0 {
			if hwnd := st.views[id] {
				position := C.ui2_win_set_scroll_position(hwnd, wanted)
				st.scroll_positions[key] = position
				windows_reposition_scroll_children(key, position)
				st.pending_scroll.delete(id)
				return
			}
		}
	}
	st.pending_scroll[id] = wanted
}

pub fn scroll_to_rect(id string, _x f64, y f64, _width f64, height f64) {
	mut st := windows_state()
	key := st.view_keys[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) != .scroll {
		return
	}
	hwnd := st.views[id] or { return }
	position := C.ui2_win_scroll_to_rect(hwnd, int(y), int(y + height))
	st.scroll_positions[key] = position
	windows_reposition_scroll_children(key, position)
}

fn windows_render_children(parent voidptr, children []Element, parent_key string, y_offset int, mut active map[string]bool) {
	mut previous := voidptr(unsafe { nil })
	for index, child in children {
		key := reconciliation_child_key(parent_key, index, child)
		hwnd := windows_render_element(parent, child, key, parent_key, y_offset, mut active)
		if hwnd != unsafe { nil } {
			C.ui2_win_place_after(hwnd, previous)
			previous = hwnd
		}
	}
}

fn windows_render_element(parent voidptr, el Element, key string, parent_key string, y_offset int, mut active map[string]bool) voidptr {
	mut st := windows_state()
	active[key] = true
	structural := windows_structural_signature(el)
	mut hwnd := st.nodes[key] or { voidptr(unsafe { nil }) }
	old_kind := st.node_kinds[key] or { Kind.screen }
	old_structural := st.node_structural[key] or { '' }
	must_create := hwnd == unsafe { nil } || C.ui2_win_is_window(hwnd) == 0 || old_kind != el.kind
		|| old_structural != structural
	mut restore_text := ''
	mut restore_start := u32(0)
	mut restore_end := u32(0)
	mut restore_focus := false
	mut restore_edit := false
	if must_create && hwnd != unsafe { nil } {
		if (old_kind == .text_field || old_kind == .text_area)
			&& (st.node_declared_text[key] or { '' }) == el.text {
			restore_edit = true
			restore_text = windows_native_text(hwnd)
			C.ui2_win_get_selection(hwnd, &restore_start, &restore_end)
			restore_focus = C.ui2_win_focus_handle() == hwnd
		}
	}
	if must_create {
		created := windows_create_element(parent, el, y_offset)
		if created == unsafe { nil } {
			eprintln('ui2: failed to create native Windows control `${el.id}` (${el.kind})')
			return hwnd
		}
		if hwnd != unsafe { nil } {
			windows_reparent_direct_children(key, created)
			windows_cleanup_node_resources(key, hwnd, old_kind)
			C.ui2_win_destroy(hwnd)
		}
		hwnd = created
		st.nodes[key] = hwnd
		st.node_kinds[key] = el.kind
		st.node_structural[key] = structural
		if restore_edit {
			if restore_text != el.text {
				windows_set_native_text(hwnd, restore_text)
			}
			C.ui2_win_set_selection(hwnd, restore_start, restore_end, windows_bool(restore_focus))
		}
	} else if C.ui2_win_parent(hwnd) != parent {
		C.ui2_win_set_parent(hwnd, parent)
	}
	st.node_parents[key] = parent_key
	st.node_frames[key] = el.frame
	visual_box := if el.kind == .toggle_button && el.checked { el.toggle_down_box } else { el.box }
	visual_text_style := if el.kind == .toggle_button && el.checked {
		el.toggle_down_text_style
	} else {
		el.text_style
	}
	st.node_boxes[key] = visual_box
	st.node_text_styles[key] = visual_text_style
	st.node_ids[key] = el.id
	st.handle_keys[windows_handle_id(hwnd)] = key
	if el.kind == .label {
		// A held label's static sends its own WM_CTLCOLORSTATIC, so it has to lead
		// back to the same node or the label loses its colours to the default handler.
		text_hwnd := C.ui2_win_label_text_hwnd(hwnd)
		if text_hwnd != hwnd {
			st.handle_keys[windows_handle_id(text_hwnd)] = key
		}
	}
	if el.id.len > 0 {
		st.views[el.id] = hwnd
		st.view_keys[el.id] = key
		st.view_kinds[el.id] = el.kind
		if el.kind == .label {
			// The area the label was laid out with, as against the rectangle its text
			// ends up on, so text set over it later can be placed the same way.
			st.label_frames[el.id] = el.frame
		}
	}
	windows_update_element(key, hwnd, Element{
		...el
		box: visual_box
		text_style: visual_text_style
	}, y_offset, must_create)
	if el.kind == .label {
		windows_place_label(key, hwnd, Element{
			...el
			text_style: visual_text_style
		}, y_offset)
	}
	windows_register_bindings(hwnd, el)
	if el.children.len > 0 {
		if el.kind == .scroll {
			content_height := windows_content_height(el.children)
			mut requested := st.scroll_positions[key] or { 0 }
			if el.id.len > 0 {
				if pending := st.pending_scroll[el.id] {
					requested = pending
					st.pending_scroll.delete(el.id)
				}
			}
			position := C.ui2_win_set_scroll(hwnd, content_height, requested)
			st.scroll_positions[key] = position
			windows_render_children(hwnd, el.children, key, -position, mut active)
		} else {
			windows_render_children(hwnd, el.children, key, 0, mut active)
		}
	} else if el.kind == .scroll {
		st.scroll_positions[key] = C.ui2_win_set_scroll(hwnd, 0, 0)
	}
	return hwnd
}

fn windows_create_element(parent voidptr, el Element, y_offset int) voidptr {
	wide := el.text.to_wide()
	boxed := label_needs_container(el)
	mut host := parent
	mut x := int(el.frame.x)
	mut y := int(el.frame.y) + y_offset
	mut container := voidptr(unsafe { nil })
	if boxed {
		empty := ''.to_wide()
		container = C.ui2_win_create_widget(windows_widget_kind(.view), parent, x, y,
			int(el.frame.width), int(el.frame.height), empty, 0, 0, 0, 0, 0)
		unsafe { free(empty) }
		host = container
		x = 0
		y = 0
	}
	hwnd := C.ui2_win_create_widget(windows_widget_kind(el.kind), host, x, y, int(el.frame.width),
		windows_native_height(el), wide, windows_align(el.text_style.align), windows_bool(el.secure),
		windows_bool(el.readonly), windows_bool(el.disable_scroll), windows_bool(el.orientation == .vertical))
	unsafe { free(wide) }
	if boxed {
		return container
	}
	return hwnd
}

// The holder covers the declared frame and is what draws the background and the
// border, so the static inside it starts past the border and only ever draws text.
// It is placed again on every pass, because the holder is the window the layout
// resizes and the static would otherwise keep the size it was made at.
fn windows_place_held_label(hwnd voidptr, el Element) {
	text_hwnd := C.ui2_win_label_text_hwnd(hwnd)
	if text_hwnd == hwnd {
		return
	}
	frame_width := int(el.frame.width)
	frame_height := int(el.frame.height)
	// Where the border really ends, asked of the same rounding that paints it: any
	// border at all covers a whole pixel, so an inset taken by truncating would leave
	// the control drawing over the border it was moved aside for.
	left := C.ui2_win_border_width(el.box.border_left, frame_width)
	top := C.ui2_win_border_width(el.box.border_top, frame_height)
	right := C.ui2_win_border_width(el.box.border_right, frame_width)
	bottom := C.ui2_win_border_width(el.box.border_bottom, frame_height)
	// Borders wide enough to meet leave nothing to draw text on. The control is still
	// given that nothing, because a control left at the size it had is a control
	// drawing over them.
	mut width := frame_width - left - right
	if width < 0 {
		width = 0
	}
	mut height := frame_height - top - bottom
	if height < 0 {
		height = 0
	}
	mut y := top
	mut drawn := height
	if el.text.len > 0 && width > 0 && height > 0 {
		content := int(C.ui2_win_label_content_height(text_hwnd, width, el.text_style.lines))
		if content > 0 && content < height {
			drawn = content
			y = int(text_block_top(f64(top), f64(height), f64(content), el.text_style.valign))
		}
	}
	C.ui2_win_set_widget_frame(text_hwnd, windows_widget_kind(el.kind), left, y, width,
		drawn)
}

fn windows_native_height(el Element) int {
	height := int(el.frame.height)
	return if el.kind == .dropdown { height + 240 } else { height }
}

fn windows_widget_kind(kind Kind) int {
	return match kind {
		.view { 1 }
		.scroll { 2 }
		.label { 3 }
		.image { 4 }
		.button { 5 }
		.dropdown { 6 }
		.text_field { 7 }
		.text_area { 8 }
		.checkbox { 9 }
		.slider { 10 }
		.switch_control { 11 }
		.toggle_button { 12 }
		.screen { 0 }
	}
}

fn windows_structural_signature(el Element) string {
	return '${int(el.kind)}:${windows_bool(el.secure)}:${windows_align(el.text_style.align)}:${windows_bool(label_needs_container(el))}:${windows_bool(el.disable_scroll)}:${windows_bool(el.native_style)}:${int(el.orientation)}'
}

fn windows_content_height(children []Element) int {
	mut height := 0
	for child in children {
		bottom := int(child.frame.y + child.frame.height)
		if bottom > height {
			height = bottom
		}
	}
	return height
}

fn windows_options_signature(entries []MenuEntry) string {
	mut parts := []string{cap: entries.len}
	for entry in entries {
		parts << entry.id.bytes().hex() + ':' + entry.title.bytes().hex()
	}
	return parts.join('|')
}

fn windows_update_element(key string, hwnd voidptr, el Element, y_offset int, created bool) {
	mut st := windows_state()
	C.ui2_win_set_widget_frame(hwnd, windows_widget_kind(el.kind), int(el.frame.x), int(el.frame.y) + y_offset, int(el.frame.width), int(el.frame.height))
	C.ui2_win_show(hwnd, windows_bool(!el.hidden))
	C.ui2_win_enable(hwnd, windows_bool(el.enabled))
	declared_changed := (st.node_declared_text[key] or { '' }) != el.text
	// A held label draws with the control inside it; everything else draws with itself.
	mut text_hwnd := hwnd
	if el.kind == .label {
		text_hwnd = C.ui2_win_label_text_hwnd(hwnd)
	}
	match el.kind {
		.label, .button, .checkbox, .switch_control, .toggle_button {
			if declared_changed || windows_native_text(text_hwnd) != el.text {
				windows_set_native_text(text_hwnd, el.text)
			}
			if el.kind in [.checkbox, .switch_control, .toggle_button] {
				C.ui2_win_set_checked(hwnd, windows_bool(el.checked))
			}
		}
		.dropdown {
			option_sig := windows_options_signature(el.menu)
			if created || (st.node_option_sig[key] or { '' }) != option_sig {
				C.ui2_win_combo_reset(hwnd)
				for entry in el.menu {
					wide_entry := entry.title.to_wide()
					C.ui2_win_combo_add(hwnd, wide_entry)
					unsafe { free(wide_entry) }
				}
				st.node_option_sig[key] = option_sig
			}
			if declared_changed || windows_native_text(hwnd) != el.text {
				wide_selected := el.text.to_wide()
				C.ui2_win_combo_select_text(hwnd, wide_selected)
				unsafe { free(wide_selected) }
			}
		}
		.text_field, .text_area {
			if declared_changed && windows_native_text(hwnd) != el.text {
				windows_set_native_text(hwnd, el.text)
			}
			wide_placeholder := el.placeholder.to_wide()
			C.ui2_win_set_edit_options(hwnd, wide_placeholder, windows_bool(el.readonly), int(el.padding_left))
			unsafe { free(wide_placeholder) }
		}
		.image {
			image_sig := '${el.image_path.bytes().hex()}:${int(el.frame.width)}:${int(el.frame.height)}'
			if created || (st.node_image_path[key] or { '' }) != image_sig {
				wide_path := el.image_path.to_wide()
				bitmap := C.ui2_win_set_bitmap(hwnd, wide_path, int(el.frame.width), int(el.frame.height))
				if bitmap == unsafe { nil } && el.image_path.len > 0 {
					eprintln('ui2: Windows native images currently require a BMP file: ${el.image_path}')
				}
				if bitmap == unsafe { nil } {
					st.images.delete(key)
				} else {
					st.images[key] = bitmap
				}
				unsafe { free(wide_path) }
				st.node_image_path[key] = image_sig
			}
		}
		.slider {
			C.ui2_win_slider_set_normalized(hwnd, slider_value_normalized(el.value,
				el.min_value, el.max_value), windows_bool(el.orientation == .vertical))
		}
		.view, .scroll, .screen {}
	}
	st.node_declared_text[key] = el.text
	windows_update_style(key, text_hwnd, el)
	// The tooltip goes on the outer window, which is the declared frame, and on the
	// control inside it, which is what the pointer actually lands on.
	windows_update_tooltip(key, hwnd, text_hwnd, el.tooltip)
	if el.kind == .label {
		C.ui2_win_invalidate_parent(hwnd)
		C.ui2_win_invalidate(text_hwnd)
	}
	C.ui2_win_invalidate(hwnd)
}

fn windows_update_tooltip(key string, hwnd voidptr, text_hwnd voidptr, tooltip string) {
	mut st := windows_state()
	if (st.tooltip_sigs[key] or { '' }) == tooltip {
		return
	}
	old_tooltip := st.tooltips[key] or { voidptr(unsafe { nil }) }
	if old_tooltip != unsafe { nil } {
		C.ui2_win_destroy_tooltip(old_tooltip)
		st.tooltips.delete(key)
	}
	if tooltip.len == 0 {
		st.tooltip_sigs[key] = tooltip
		return
	}
	wide_tooltip := tooltip.to_wide()
	native_tooltip := C.ui2_win_create_tooltip(hwnd, wide_tooltip)
	unsafe { free(wide_tooltip) }
	if native_tooltip != unsafe { nil } {
		if text_hwnd != hwnd {
			// A held label's static covers the text, so the mouse moves over it and
			// never over the holder the tooltip was put on. It is a target too.
			C.ui2_win_tooltip_add_target(native_tooltip, text_hwnd)
		}
		st.tooltips[key] = native_tooltip
		st.tooltip_sigs[key] = tooltip
	}
}

// windows_font_text returns every string the control draws with its own font,
// so a fallback family is picked for placeholders and dropdown items too.
fn windows_font_text(el Element) string {
	mut drawn := el.text
	drawn += el.placeholder
	if el.kind == .dropdown {
		for entry in el.menu {
			drawn += entry.title
		}
	}
	return drawn
}

// windows_font_glyph_key keeps the font signature stable for ordinary text and
// only changes when characters that may need a fallback family come and go.
fn windows_font_glyph_key(text string) string {
	mut codes := map[u32]bool{}
	for letter in text.runes() {
		code := u32(letter)
		if code >= 0x2000 {
			codes[code] = true
		}
	}
	if codes.len == 0 {
		return ''
	}
	mut sorted := codes.keys()
	sorted.sort()
	return sorted.map(it.hex()).join('.')
}

fn windows_update_style(key string, hwnd voidptr, el Element) {
	mut st := windows_state()
	if el.kind == .button && el.native_style {
		// Native buttons keep the system font. Only its family may have to
		// change, so a check mark is not painted as an empty box.
		font_sig := 'native:${windows_font_glyph_key(el.text)}'
		if (st.font_sigs[key] or { '' }) != font_sig {
			wide_text := el.text.to_wide()
			C.ui2_win_apply_text_font(hwnd, wide_text)
			unsafe { free(wide_text) }
			st.font_sigs[key] = font_sig
		}
	} else if el.kind !in [.view, .scroll, .image, .slider, .switch_control] {
		font_text := windows_font_text(el)
		font_sig := '${el.text_style.size}:${el.text_style.font_family.bytes().hex()}:${windows_bool(el.text_style.bold)}:${windows_bool(el.text_style.italic)}:${windows_bool(el.text_style.underline)}:${windows_bool(el.text_style.strikethrough)}:${windows_font_glyph_key(font_text)}'
		if (st.font_sigs[key] or { '' }) != font_sig {
			wide_family := el.text_style.font_family.to_wide()
			wide_text := font_text.to_wide()
			font := C.ui2_win_create_font(hwnd, el.text_style.size, wide_family, windows_bool(el.text_style.bold), windows_bool(el.text_style.italic), windows_bool(el.text_style.underline), windows_bool(el.text_style.strikethrough), wide_text)
			unsafe { free(wide_family) }
			unsafe { free(wide_text) }
			if font != unsafe { nil } {
				C.ui2_win_apply_font(hwnd, font)
				old_font := st.fonts[key] or { voidptr(unsafe { nil }) }
				if old_font != unsafe { nil } {
					C.ui2_win_delete_object(old_font)
				}
				st.fonts[key] = font
				st.font_sigs[key] = font_sig
			}
		}
	}
	if el.kind !in [.view, .scroll, .image, .slider, .switch_control] {
		old_brush := st.brushes[key] or { voidptr(unsafe { nil }) }
		if old_brush == unsafe { nil } || (st.brush_sigs[key] or { u32(0xffffffff) }) != el.box.bg {
			brush := C.ui2_win_create_brush(el.box.bg)
			if brush != unsafe { nil } {
				if old_brush != unsafe { nil } {
					C.ui2_win_delete_object(old_brush)
				}
				st.brushes[key] = brush
				st.brush_sigs[key] = el.box.bg
			}
		}
	}
}

fn windows_register_bindings(hwnd voidptr, el Element) {
	mut st := windows_state()
	handle := windows_handle_id(hwnd)
	action_id := element_action_id(el)
	if action_id.len > 0
		&& el.kind in [.button, .checkbox, .dropdown, .slider, .switch_control, .toggle_button] {
		st.action_ids[handle] = action_id
	}
	if el.kind == .slider {
		st.slider_specs[handle] = slider_spec(el)
	}
	if el.kind == .toggle_button {
		st.toggle_groups[handle] = el.toggle_group
		st.toggle_allow_no_selection[handle] = el.toggle_allow_no_selection
		st.toggle_ids[handle] = el.id
		st.toggle_views[handle] = hwnd
		if C.ui2_win_get_checked(hwnd) != 0 {
			release_windows_toggle_group(handle)
		}
	}
	if action_id.len > 0 && ((el.kind == .text_field && el.emit_change) || el.kind == .text_area) {
		st.change_ids[handle] = action_id
	}
	if el.submit_id.len > 0 && el.kind == .text_field {
		st.submit_ids[handle] = el.submit_id
	}
	if el.clickable || el.draggable || el.long_press || el.swipe_left {
		st.pointer_bindings[handle] = WindowsPointerBinding{
			id: action_id
			clickable: el.clickable
			draggable: el.draggable
			long_press: el.long_press
			swipe_left: el.swipe_left
		}
	}
	if el.menu.len > 0 {
		st.menus[handle] = el.menu.clone()
	}
	cursor := windows_cursor_code(el.cursor)
	if cursor != 0 {
		st.cursors[handle] = cursor
	}
	if el.kind == .scroll {
		st.scroll_ids[handle] = el.id
	}
}

fn windows_cursor_code(cursor string) int {
	return match cursor {
		cursor_pointing_hand { 1 }
		cursor_resize_nwse { 2 }
		cursor_resize_nesw { 3 }
		cursor_resize_ew { 4 }
		cursor_resize_ns { 5 }
		else { 0 }
	}
}

fn windows_reparent_direct_children(key string, new_parent voidptr) {
	st := windows_state()
	for child_key, parent_key in st.node_parents {
		if parent_key == key {
			child := st.nodes[child_key] or { continue }
			C.ui2_win_set_parent(child, new_parent)
		}
	}
}

fn windows_cleanup_node_resources(key string, hwnd voidptr, kind Kind) {
	mut st := windows_state()
	if kind == .image {
		bitmap := st.images[key] or { voidptr(unsafe { nil }) }
		if hwnd != unsafe { nil } && C.ui2_win_is_window(hwnd) != 0 {
			C.ui2_win_clear_bitmap(hwnd)
		} else if bitmap != unsafe { nil } {
			C.ui2_win_delete_object(bitmap)
		}
		st.images.delete(key)
	}
	font := st.fonts[key] or { voidptr(unsafe { nil }) }
	if font != unsafe { nil } {
		C.ui2_win_delete_object(font)
	}
	brush := st.brushes[key] or { voidptr(unsafe { nil }) }
	if brush != unsafe { nil } {
		C.ui2_win_delete_object(brush)
	}
	st.fonts.delete(key)
	st.font_sigs.delete(key)
	st.brushes.delete(key)
	st.brush_sigs.delete(key)
	tooltip := st.tooltips[key] or { voidptr(unsafe { nil }) }
	if tooltip != unsafe { nil } {
		C.ui2_win_destroy_tooltip(tooltip)
	}
	st.tooltips.delete(key)
	st.tooltip_sigs.delete(key)
}

fn windows_remove_stale(active map[string]bool) {
	mut st := windows_state()
	mut stale := map[string]bool{}
	for key, _ in st.nodes {
		if key !in active {
			stale[key] = true
		}
	}
	for key, _ in stale {
		hwnd := st.nodes[key] or { continue }
		kind := st.node_kinds[key] or { Kind.view }
		windows_cleanup_node_resources(key, hwnd, kind)
	}
	for key, _ in stale {
		parent_key := st.node_parents[key] or { '' }
		if parent_key !in stale {
			hwnd := st.nodes[key] or { continue }
			C.ui2_win_destroy(hwnd)
		}
	}
	for key, _ in stale {
		old_id := st.node_ids[key] or { '' }
		if old_id.len > 0 {
			forget_portable_text_area_selection(old_id)
		}
		st.nodes.delete(key)
		st.node_kinds.delete(key)
		st.node_parents.delete(key)
		st.node_frames.delete(key)
		st.node_structural.delete(key)
		st.node_declared_text.delete(key)
		st.node_option_sig.delete(key)
		st.node_image_path.delete(key)
		st.node_ids.delete(key)
		st.node_boxes.delete(key)
		st.node_label_boxed.delete(key)
		st.node_text_styles.delete(key)
		st.scroll_positions.delete(key)
	}
}

fn windows_dispose_all() {
	mut st := windows_state()
	windows_release_all_node_resources()
	st.nodes = map[string]voidptr{}
	st.root = unsafe { nil }
}

fn windows_release_all_node_resources() {
	st := windows_state()
	for key, hwnd in st.nodes {
		windows_cleanup_node_resources(key, hwnd, st.node_kinds[key] or { Kind.view })
	}
}

fn windows_reposition_scroll_children(scroll_key string, position int) {
	st := windows_state()
	for child_key, parent_key in st.node_parents {
		if parent_key != scroll_key {
			continue
		}
		hwnd := st.nodes[child_key] or { continue }
		frame := st.node_frames[child_key] or { continue }
		kind := st.node_kinds[child_key] or { Kind.view }
		C.ui2_win_set_widget_frame(hwnd, windows_widget_kind(kind), int(frame.x), int(frame.y) - position, int(frame.width), int(frame.height))
	}
	C.ui2_win_invalidate(st.nodes[scroll_key] or { return })
}

fn windows_handle_scroll(hwnd voidptr, wparam usize, wheel bool) {
	mut st := windows_state()
	key := st.handle_keys[windows_handle_id(hwnd)] or { return }
	if (st.node_kinds[key] or { Kind.view }) != .scroll {
		return
	}
	old_position := st.scroll_positions[key] or { 0 }
	position := if wheel {
		C.ui2_win_scroll_wheel(hwnd, wparam)
	} else {
		C.ui2_win_scroll_message(hwnd, wparam)
	}
	if position == old_position {
		return
	}
	st.scroll_positions[key] = position
	windows_reposition_scroll_children(key, position)
	id := st.scroll_ids[windows_handle_id(hwnd)] or { '' }
	if id.len > 0 && voidptr(st.scroll_handler) != unsafe { nil } {
		st.scroll_handler(id)
	}
}

fn windows_emit_action(id string) {
	st := windows_state()
	if id.len > 0 && voidptr(st.event_handler) != unsafe { nil } {
		st.event_handler(id)
	}
}

fn windows_snap_slider_value(hwnd voidptr, spec SliderSpec) f64 {
	raw_normalized := C.ui2_win_slider_normalized(hwnd,
		windows_bool(spec.orientation == .vertical))
	value := slider_value_from_normalized(raw_normalized, spec.min, spec.max, spec.step)
	exact_normalized := slider_value_normalized(value, spec.min, spec.max)
	if exact_normalized != raw_normalized {
		C.ui2_win_slider_set_normalized(hwnd, exact_normalized,
			windows_bool(spec.orientation == .vertical))
	}
	return value
}

fn windows_key_code(virtual_key u32) KeyCode {
	if (virtual_key >= 0x30 && virtual_key <= 0x39)
		|| (virtual_key >= 0x41 && virtual_key <= 0x5a) {
		return unsafe { KeyCode(virtual_key) }
	}
	if virtual_key >= 0x70 && virtual_key <= 0x87 {
		return unsafe { KeyCode(int(KeyCode.f1) + int(virtual_key - 0x70)) }
	}
	if virtual_key >= 0x60 && virtual_key <= 0x69 {
		return unsafe { KeyCode(int(KeyCode.kp_0) + int(virtual_key - 0x60)) }
	}
	return match virtual_key {
		0x08 { .backspace }
		0x09 { .tab }
		0x0d { .enter }
		0x1b { .escape }
		0x20 { .space }
		0x21 { .page_up }
		0x22 { .page_down }
		0x23 { .end }
		0x24 { .home }
		0x25 { .left }
		0x26 { .up }
		0x27 { .right }
		0x28 { .down }
		0x2d { .insert }
		0x2e { .delete }
		0x6a { .kp_multiply }
		0x6b { .kp_add }
		0x6d { .kp_subtract }
		0x6e { .kp_decimal }
		0x6f { .kp_divide }
		0xba { .semicolon }
		0xbb { .equal }
		0xbc { .comma }
		0xbd { .minus }
		0xbe { .period }
		0xbf { .slash }
		0xc0 { .grave_accent }
		0xdb { .left_bracket }
		0xdc { .backslash }
		0xdd { .right_bracket }
		0xde { .apostrophe }
		else { .invalid }
	}
}

fn windows_key_event(virtual_key u32) KeyEvent {
	return KeyEvent{
		code: windows_key_code(virtual_key)
		ctrl: C.ui2_win_key_down(0x11) != 0
		alt: C.ui2_win_key_down(0x12) != 0
		shift: C.ui2_win_key_down(0x10) != 0
		cmd: C.ui2_win_key_down(0x5b) != 0 || C.ui2_win_key_down(0x5c) != 0
	}
}

fn windows_normalized_key(virtual_key u32) string {
	key_event := windows_key_event(virtual_key)
	mut key := key_event.code.name()
	if key.len == 0 {
		return ''
	}
	mut modifiers := []string{}
	if key_event.ctrl {
		modifiers << 'ctrl'
	}
	if key_event.alt {
		modifiers << 'alt'
	}
	if key_event.shift {
		modifiers << 'shift'
	}
	if key_event.cmd {
		modifiers << 'cmd'
	}
	if modifiers.len > 0 {
		key = modifiers.join('+') + '+' + key
	}
	return key
}

fn windows_dispatch_typed_key(virtual_key u32) bool {
	mut st := windows_state()
	if voidptr(st.key_event_handler) == unsafe { nil } {
		return false
	}
	st.key_consumed = false
	st.key_event_handler(windows_key_event(virtual_key))
	consumed := st.key_consumed
	st.key_consumed = false
	return consumed
}

fn windows_dispatch_key_string(virtual_key u32) bool {
	mut st := windows_state()
	if voidptr(st.key_handler) == unsafe { nil } {
		return false
	}
	key := windows_normalized_key(virtual_key)
	if key.len == 0 {
		return false
	}
	st.key_consumed = false
	st.key_handler(key)
	return st.key_consumed
}

fn windows_dispatch_key(virtual_key u32) bool {
	if windows_dispatch_typed_key(virtual_key) {
		return true
	}
	return windows_dispatch_key_string(virtual_key)
}

fn windows_dispatch_control_key(hwnd voidptr, virtual_key u32) bool {
	if windows_dispatch_typed_key(virtual_key) {
		return true
	}
	mut st := windows_state()
	if voidptr(st.key_handler) == unsafe { nil } {
		return false
	}
	key_name := windows_normalized_key(virtual_key)
	if key_name.len == 0 {
		return false
	}
	key := st.handle_keys[windows_handle_id(hwnd)] or {
		return windows_dispatch_key_string(virtual_key)
	}
	if (st.node_kinds[key] or { Kind.view }) != .text_area {
		return windows_dispatch_key_string(virtual_key)
	}
	id := st.node_ids[key] or { '' }
	if id.len == 0 {
		return windows_dispatch_key_string(virtual_key)
	}
	st.key_consumed = false
	st.key_handler('text:${id}:${key_name}')
	return st.key_consumed
}

fn windows_handle_drop(drop voidptr) {
	st := windows_state()
	if voidptr(st.drop_handler) == unsafe { nil } {
		C.ui2_win_drop_finish(drop)
		return
	}
	count := C.ui2_win_drop_count(drop)
	mut paths := []string{cap: int(count)}
	for index := u32(0); index < count; index++ {
		length := C.ui2_win_drop_path_length(drop, index)
		mut buffer := []u16{len: int(length) + 1}
		C.ui2_win_drop_path(drop, index, unsafe { &buffer[0] }, length + 1)
		paths << unsafe { string_from_wide2(&buffer[0], int(length)) }
	}
	mut x := 0
	mut y := 0
	C.ui2_win_drop_point(drop, &x, &y)
	C.ui2_win_drop_finish(drop)
	st.drop_handler(DropEvent{
		paths: paths
		x: f64(x)
		y: f64(y)
	})
}

@[export: 'ui2_windows_window_proc']
fn ui2_windows_window_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	mut st := windows_state()
	match message {
		win_wm_getminmaxinfo {
			C.ui2_win_apply_min_size(hwnd, lparam, st.run_config.min_width,
				st.run_config.min_height)
			return 0
		}
		win_wm_command {
			child := voidptr(usize(lparam))
			if child == unsafe { nil } {
				// A menu bar row and an accelerator both arrive without a
				// control handle; the command id names the row.
				windows_handle_menu_command(u32(wparam & 0xffff))
				return 0
			}
			handle := windows_handle_id(child)
			code := int((wparam >> 16) & 0xffff)
			if code == win_en_change {
				if !st.rendering {
					windows_emit_action(st.change_ids[handle] or { '' })
				}
				return 0
			}
			if code == win_cbn_selchange {
				windows_emit_action(st.action_ids[handle] or { '' })
				return 0
			}
			if code == win_bn_clicked {
				if st.suppress_click[handle] or { false } {
					st.suppress_click.delete(handle)
					return 0
				}
				commit_windows_toggle_button(handle, child)
				windows_emit_action(st.action_ids[handle] or { '' })
				return 0
			}
		}
		win_wm_ctlcolor_edit, win_wm_ctlcolor_listbox, win_wm_ctlcolor_button, win_wm_ctlcolor_static {
			child := voidptr(usize(lparam))
			key := st.handle_keys[windows_handle_id(child)] or {
				return C.ui2_win_default_proc(hwnd, message, wparam, lparam)
			}
			style := st.node_text_styles[key] or { TextStyle{} }
			box := st.node_boxes[key] or { BoxStyle{} }
			kind := st.node_kinds[key] or { Kind.view }
			brush := st.brushes[key] or { voidptr(unsafe { nil }) }
			return C.ui2_win_apply_control_colors(voidptr(wparam), style.color, box.bg,
				windows_bool(windows_draws_no_background(kind, box)), brush)
		}
		win_wm_paint_background {
			mut box := BoxStyle{}
			mut kind := Kind.screen
			if hwnd == st.root {
				box = st.node_boxes[''] or { BoxStyle{} }
			} else {
				key := st.handle_keys[windows_handle_id(hwnd)] or { return 0 }
				box = st.node_boxes[key] or { return 0 }
				kind = st.node_kinds[key] or { Kind.screen }
			}
			C.ui2_win_paint_background_into(hwnd, voidptr(wparam), box.bg, box.radius,
				windows_bool(windows_draws_no_background(kind, box)), box.border_color,
				box.border_left, box.border_top, box.border_right, box.border_bottom)
			return 0
		}
		win_wm_paint {
			if hwnd == st.root {
				box := st.node_boxes[''] or { BoxStyle{} }
				C.ui2_win_paint_background(hwnd, box.bg, box.radius, windows_bool(box.transparent),
					box.border_color, box.border_left, box.border_top, box.border_right,
					box.border_bottom)
				return 0
			}
			key := st.handle_keys[windows_handle_id(hwnd)] or {
				return C.ui2_win_default_proc(hwnd, message, wparam, lparam)
			}
			kind := st.node_kinds[key] or { Kind.screen }
			if kind == .view || kind == .scroll || windows_is_label_container(key, hwnd) {
				box := st.node_boxes[key] or { BoxStyle{} }
				transparent := windows_bool(windows_draws_no_background(kind, box))
				C.ui2_win_paint_background(hwnd, box.bg, box.radius, transparent,
					box.border_color, box.border_left, box.border_top, box.border_right,
					box.border_bottom)
				return 0
			}
		}
		win_wm_erase_background {
			if hwnd == st.root {
				return 1
			}
			key := st.handle_keys[windows_handle_id(hwnd)] or { '' }
			kind := st.node_kinds[key] or { Kind.screen }
			if kind == .view || kind == .scroll || windows_is_label_container(key, hwnd) {
				return 1
			}
		}
		win_wm_hscroll, win_wm_vscroll {
			child := voidptr(usize(lparam))
			if child != unsafe { nil } {
				handle := windows_handle_id(child)
				if spec := st.slider_specs[handle] {
					windows_snap_slider_value(child, spec)
					windows_emit_action(st.action_ids[handle] or { '' })
					return 0
				}
			}
			if message == win_wm_hscroll {
				return C.ui2_win_default_proc(hwnd, message, wparam, lparam)
			}
			windows_handle_scroll(hwnd, wparam, false)
			return 0
		}
		win_wm_mouse_wheel {
			windows_handle_scroll(hwnd, wparam, true)
			return 0
		}
		win_wm_key_down {
			if windows_dispatch_key(u32(wparam)) {
				return 0
			}
		}
		win_wm_dropfiles {
			windows_handle_drop(voidptr(wparam))
			return 0
		}
		win_wm_size {
			if hwnd == st.root && !st.rendering {
				refresh()
			}
			return 0
		}
		win_wm_refresh {
			refresh()
			return 0
		}
		win_wm_tray {
			// The low word is the mouse message; the high word is the icon id
			// once the notification area is asked for version 4 behavior.
			windows_handle_tray_message(u32(lparam) & 0xffff)
			return 0
		}
		win_wm_close {
			windows_release_all_node_resources()
			C.ui2_win_destroy(hwnd)
			return 0
		}
		win_wm_destroy {
			if hwnd == st.root {
				windows_release_all_node_resources()
				C.ui2_win_post_quit(0)
			}
			return 0
		}
		else {}
	}
	return C.ui2_win_default_proc(hwnd, message, wparam, lparam)
}

// A held label is the container covering the declared frame; the static inside it is
// mapped to the same node so its colours can be found, but it is not what that node's
// border belongs to — drawn there the border would close around the text rather than
// around the label. Only the window a node actually is draws that node's border.
fn windows_is_label_container(key string, hwnd voidptr) bool {
	st := windows_state()
	if (st.node_kinds[key] or { Kind.screen }) != .label {
		return false
	}
	node := st.nodes[key] or { return false }
	return node == hwnd && C.ui2_win_label_text_hwnd(hwnd) != hwnd
}

@[export: 'ui2_windows_control_border']
fn ui2_windows_control_border(hwnd voidptr) {
	st := windows_state()
	key := st.handle_keys[windows_handle_id(hwnd)] or { return }
	if node := st.nodes[key] {
		if node != hwnd {
			return
		}
	}
	box := st.node_boxes[key] or { return }
	C.ui2_win_paint_control_border(hwnd, box.border_color, box.radius, box.border_left,
		box.border_top, box.border_right, box.border_bottom)
}

@[export: 'ui2_windows_paint_transparent_button']
fn ui2_windows_paint_transparent_button(hwnd voidptr) int {
	st := windows_state()
	key := st.handle_keys[windows_handle_id(hwnd)] or { return 0 }
	kind := st.node_kinds[key] or { return 0 }
	box := st.node_boxes[key] or { return 0 }
	if !windows_uses_transparent_button_paint(kind, box) {
		return 0
	}
	style := st.node_text_styles[key] or { TextStyle{} }
	C.ui2_win_paint_transparent_button(hwnd, style.color, box.radius, box.border_color,
		box.border_left, box.border_top, box.border_right, box.border_bottom)
	return 1
}

@[export: 'ui2_windows_is_transparent_button']
fn ui2_windows_is_transparent_button(hwnd voidptr) int {
	st := windows_state()
	key := st.handle_keys[windows_handle_id(hwnd)] or { return 0 }
	kind := st.node_kinds[key] or { return 0 }
	box := st.node_boxes[key] or { return 0 }
	return windows_bool(windows_uses_transparent_button_paint(kind, box))
}

@[export: 'ui2_windows_edit_submit']
fn ui2_windows_edit_submit(hwnd voidptr) int {
	st := windows_state()
	id := st.submit_ids[windows_handle_id(hwnd)] or { return 0 }
	windows_emit_action(id)
	return 1
}

@[export: 'ui2_windows_control_key']
fn ui2_windows_control_key(hwnd voidptr, virtual_key u32) int {
	return windows_bool(windows_dispatch_control_key(hwnd, virtual_key))
}

@[export: 'ui2_windows_context_menu']
fn ui2_windows_context_menu(hwnd voidptr, screen_x int, screen_y int) int {
	st := windows_state()
	mut target := hwnd
	mut entries := []MenuEntry{}
	for target != unsafe { nil } {
		entries = st.menus[windows_handle_id(target)] or { []MenuEntry{} }
		if entries.len > 0 || target == st.root {
			break
		}
		target = C.ui2_win_parent(target)
	}
	if entries.len == 0 {
		return 0
	}
	menu := C.ui2_win_menu_create()
	if menu == unsafe { nil } {
		return 0
	}
	for index, entry in entries {
		wide_title := entry.title.to_wide()
		C.ui2_win_menu_add(menu, u32(index + 1), wide_title, 1)
		unsafe { free(wide_title) }
	}
	command := C.ui2_win_menu_track(menu, target, screen_x, screen_y)
	C.ui2_win_menu_destroy(menu)
	if command > 0 && int(command) <= entries.len {
		windows_emit_action(entries[int(command) - 1].id)
	}
	return 1
}

@[export: 'ui2_windows_cursor']
fn ui2_windows_cursor(hwnd voidptr) int {
	st := windows_state()
	mut target := hwnd
	for target != unsafe { nil } {
		cursor := st.cursors[windows_handle_id(target)] or { 0 }
		if cursor != 0 {
			return cursor
		}
		if target == st.root {
			break
		}
		target = C.ui2_win_parent(target)
	}
	return 0
}

@[export: 'ui2_windows_control_pointer']
fn ui2_windows_control_pointer(hwnd voidptr, message u32, local_x int, local_y int) {
	mut st := windows_state()
	mut target := hwnd
	mut binding := WindowsPointerBinding{}
	for target != unsafe { nil } {
		binding = st.pointer_bindings[windows_handle_id(target)] or { WindowsPointerBinding{} }
		if binding.id.len > 0 || target == st.root {
			break
		}
		target = C.ui2_win_parent(target)
	}
	if binding.id.len == 0 {
		return
	}
	mut x := local_x
	mut y := local_y
	C.ui2_win_point_to_root(hwnd, st.root, &x, &y)
	if message == win_wm_lbutton_down {
		st.pointer_handle = target
		st.pointer_start_x = x
		st.pointer_start_y = y
		st.pointer_started = C.ui2_win_ticks()
		st.pointer_moved = false
		C.ui2_win_capture_mouse(target)
		if binding.clickable || binding.draggable {
			windows_emit_action('pointer:down:${binding.id}:${x}:${y}')
		}
		return
	}
	if st.pointer_handle != target {
		return
	}
	if message == win_wm_mouse_move {
		move_x := x - st.pointer_start_x
		move_y := y - st.pointer_start_y
		if move_x < -8 || move_x > 8 || move_y < -8 || move_y > 8 {
			st.pointer_moved = true
		}
		if binding.draggable {
			windows_emit_action('pointer:drag:${binding.id}:${x}:${y}')
		}
		return
	}
	if message != win_wm_lbutton_up {
		return
	}
	C.ui2_win_release_mouse()
	st.pointer_handle = unsafe { nil }
	delta_x := x - st.pointer_start_x
	delta_y := y - st.pointer_start_y
	duration := C.ui2_win_ticks() - st.pointer_started
	mut gesture := false
	if binding.swipe_left && delta_x <= -60 && delta_y >= -40 && delta_y <= 40 {
		windows_emit_action('swipe_left:' + binding.id)
		gesture = true
	} else if binding.long_press && !st.pointer_moved && duration >= 500 && delta_x >= -8 && delta_x <= 8
		&& delta_y >= -8 && delta_y <= 8 {
		windows_emit_action('long:' + binding.id)
		gesture = true
	}
	if binding.clickable || binding.draggable {
		windows_emit_action('pointer:up:${binding.id}:${x}:${y}')
	}
	if gesture {
		st.suppress_click[windows_handle_id(target)] = true
	}
}

fn windows_text_area_handle(id string) ?voidptr {
	st := windows_state()
	hwnd := st.views[id] or { return none }
	if (st.view_kinds[id] or { Kind.view }) != .text_area {
		return none
	}
	return hwnd
}

fn windows_native_get_selection(hwnd voidptr) TextAreaSelectionRange {
	mut start := u32(0)
	mut end := u32(0)
	C.ui2_win_get_selection(hwnd, &start, &end)
	return TextAreaSelectionRange{
		location: int(start)
		length: if end >= start { int(end - start) } else { 0 }
	}
}

fn windows_native_set_selection(hwnd voidptr, selection TextAreaSelectionRange) {
	start := u32(selection.location)
	C.ui2_win_set_selection(hwnd, start, start + u32(selection.length), 0)
}
}
