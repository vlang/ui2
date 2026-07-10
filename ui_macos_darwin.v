module ui2

import encoding.base64
import macos
import os

#flag darwin -framework Cocoa
#flag darwin -framework QuartzCore
#insert "@DIR/macos/native_helpers.h"

fn C.macos_objc_msg_id_rect_u64_u64_bool(obj macos.Id, selector macos.Sel, rect macos.Rect, a1 u64, a2 u64, a3 bool) macos.Id
fn C.ui2_image_from_name(raw &char) macos.Id
fn C.ui2_image_from_name_sized(raw &char, width f64, height f64) macos.Id
fn C.ui2_nscolor_rgb(hex u32) macos.Id
fn C.ui2_app_did_finish_launching(self voidptr, cmd voidptr, notification voidptr)
fn C.ui2_app_should_terminate_after_last_window_closed(self voidptr, cmd voidptr, sender voidptr) bool
fn C.ui2_button_tap(self voidptr, cmd voidptr, sender voidptr)
fn C.ui2_view_is_flipped(self voidptr, cmd voidptr) bool
fn C.ui2_window_key_down(self voidptr, cmd voidptr, event voidptr)
fn C.ui2_window_perform_key_equiv(self voidptr, cmd voidptr, event voidptr) bool
fn C.ui2_window_did_resize(self voidptr, cmd voidptr, notification voidptr)
fn C.ui2_control_text_changed(self voidptr, cmd voidptr, notification voidptr)
fn C.ui2_text_view_changed(self voidptr, cmd voidptr, notification voidptr)
fn C.ui2_text_view_do_command(self voidptr, cmd voidptr, text_view voidptr, command voidptr) bool
fn C.ui2_text_view_clicked_on_link(self voidptr, cmd voidptr, text_view voidptr, link voidptr, char_index u64) bool
fn C.ui2_bounds_changed(self voidptr, cmd voidptr, notification voidptr)
fn C.ui2_dispatch_main(cb voidptr)
fn C.ui2_observe_bounds(observer voidptr, view voidptr)
fn C.ui2_text_view_set_attributed_string(tv voidptr, utf8 &char, color u32, background_color u32, size f64, family &char, bold bool, italic bool, underline bool, strikethrough bool, vertical_align &char)
fn C.ui2_text_view_add_style(tv voidptr, location u64, length u64, color u32, background_color u32, size f64, family &char, bold bool, italic bool, underline bool, strikethrough bool, vertical_align &char)
fn C.ui2_text_view_add_link(tv voidptr, location u64, length u64, link &char)
fn C.ui2_text_view_runs(tv voidptr) macos.Id
fn C.ui2_control_set_attributed_title(control voidptr, utf8 &char, color u32, size f64, bold bool, italic bool, underline bool)
fn C.ui2_text_view_toggle_format(tv voidptr, format int)
fn C.ui2_text_view_set_font_family(tv voidptr, family &char)
fn C.ui2_text_view_set_font_size(tv voidptr, size f64)
fn C.ui2_text_view_set_color(tv voidptr, color u32)
fn C.ui2_text_view_set_background_color(tv voidptr, color u32)
fn C.ui2_text_view_format_active(tv voidptr, format int) bool
fn C.ui2_text_view_toggle_vertical_align(tv voidptr, align int)
fn C.ui2_text_view_vertical_align_active(tv voidptr) int
fn C.ui2_text_view_set_selected_range(tv voidptr, location u64, length u64)
fn C.ui2_text_view_selected_location(tv voidptr) u64
fn C.ui2_text_view_selected_length(tv voidptr) u64
fn C.ui2_text_view_insert_text(tv voidptr, utf8 &char)
fn C.ui2_text_view_text_length(tv voidptr) u64
fn C.ui2_selector_name(selector voidptr) macos.Id
fn C.ui2_view_save_png(view voidptr, path &char) bool
fn C.ui2_pasteboard_has_image() bool
fn C.ui2_pasteboard_write_image_png(path &char) bool
fn C.ui2_app_send_edit_command(command int) bool
fn C.ui2_current_event_modifier_flags() u64
fn C.ui2_utf16_length(utf8 &char) u64
fn C.ui2_event_x_in_view(view voidptr, event voidptr) f64
fn C.ui2_event_y_in_view(view voidptr, event voidptr) f64
fn C.ui2_view_clear_rotation(view voidptr)
fn C.ui2_view_reset_transform(view voidptr)
fn C.ui2_view_set_rotation(view voidptr, degrees f64)
fn C.ui2_pointer_mouse_down(self voidptr, cmd voidptr, event voidptr)
fn C.ui2_pointer_mouse_dragged(self voidptr, cmd voidptr, event voidptr)
fn C.ui2_pointer_mouse_up(self voidptr, cmd voidptr, event voidptr)
fn C.ui2_pointer_reset_cursor_rects(self voidptr, cmd voidptr)
fn C.ui2_add_cursor_rect(view voidptr, cursor &char)
fn C.ui2_invalidate_cursor_rects(view voidptr)

const ns_window_style_titled = u64(1)
const ns_window_style_closable = u64(2)
const ns_window_style_miniaturizable = u64(4)
const ns_window_style_resizable = u64(8)
const ns_backing_store_buffered = u64(2)
const ns_button_type_momentary_change = i64(5)

type NativeView = voidptr

struct NativeRect {
	x      f64
	y      f64
	width  f64
	height f64
}

struct RunConfig {
	title  string = 'App'
	width  int    = 400
	height int    = 800
}

@[heap]
struct RuntimeState {
mut:
	build_screen        BuildFn = BuildFn(unsafe { nil })
	event_handler       EventFn = EventFn(unsafe { nil })
	key_handler         KeyFn   = KeyFn(unsafe { nil })
	key_consumed        bool
	text_key_consumed   bool
	scroll_handler      ScrollFn = ScrollFn(unsafe { nil })
	window              NativeView
	root_view           NativeView
	button_handler      NativeView
	app_delegate        NativeView
	views               map[string]NativeView
	view_kinds          map[string]Kind
	text_area_direct    map[string]bool
	nodes               map[string]NativeView
	node_kinds          map[string]Kind
	node_text_direct    map[string]bool
	node_interactive    map[string]bool
	textview_ids        map[u64]string // NSTextView pointer -> element id (no tag on NSView)
	scroll_ids          map[u64]string // NSClipView pointer -> Scroll element id
	pointer_ids         map[u64]string // NSView pointer -> element id
	pointer_draggable   map[u64]bool
	cursor_ids          map[u64]string // NSView pointer -> cursor name
	control_ids         map[u64]string // NSControl pointer -> element id
	observed            map[u64]bool   // clip views we already observe for scroll changes
	button_ids          []string
	run_config          RunConfig
	screenshot_pending  bool
	screenshot_captured bool
}

const runtime_state_singleton = &RuntimeState{
	views:             map[string]NativeView{}
	view_kinds:        map[string]Kind{}
	text_area_direct:  map[string]bool{}
	nodes:             map[string]NativeView{}
	node_kinds:        map[string]Kind{}
	node_text_direct:  map[string]bool{}
	node_interactive:  map[string]bool{}
	textview_ids:      map[u64]string{}
	scroll_ids:        map[u64]string{}
	pointer_ids:       map[u64]string{}
	pointer_draggable: map[u64]bool{}
	cursor_ids:        map[u64]string{}
	control_ids:       map[u64]string{}
	observed:          map[u64]bool{}
}

fn state() &RuntimeState {
	return unsafe { runtime_state_singleton }
}

pub fn bounds() Rect {
	st := state()
	if native_is_nil(st.root_view) {
		return Rect{
			width:  f64(st.run_config.width)
			height: f64(st.run_config.height)
		}
	}
	b := native_bounds(st.root_view)
	return Rect{
		x:      b.x
		y:      b.y
		width:  b.width
		height: b.height
	}
}

pub fn run(build_fn BuildFn, event_fn EventFn) {
	run_window('App', 400, 800, build_fn, event_fn)
}

pub fn run_window(title string, width int, height int, build_fn BuildFn, event_fn EventFn) {
	mut st := state()
	st.build_screen = build_fn
	st.event_handler = event_fn
	st.run_config = RunConfig{
		title:  title
		width:  width
		height: height
	}
	ensure_runtime_classes()
	native_set_activation_policy_regular()
	delegate := native_new_object('UI2AppDelegate')
	st.app_delegate = delegate
	native_set_delegate(delegate)
	native_run_app()
}

pub fn refresh() {
	st := state()
	if native_is_nil(st.root_view) || voidptr(st.build_screen) == unsafe { nil } {
		return
	}
	root := st.build_screen()
	render_root(root)
	schedule_screenshot_capture()
}

// on_key registers a handler for key events that reach the window
// (i.e. not consumed by a focused text field). Keys arrive normalized:
// 'up', 'forward_delete', 'escape', 'cmd+shift+r', 'f5', ...
pub fn on_key(handler KeyFn) {
	mut st := state()
	st.key_handler = handler
}

// on_scroll registers a handler called with a Scroll element's id whenever
// its scroll position changes (used for list virtualization).
pub fn on_scroll(handler ScrollFn) {
	mut st := state()
	st.scroll_handler = handler
}

fn refresh_on_main() {
	refresh()
}

// request_refresh schedules a rebuild on the main thread; safe to call from
// background threads (sync loops, network fetches).
pub fn request_refresh() {
	cb := refresh_on_main
	C.ui2_dispatch_main(voidptr(cb))
}

// scroll_offset returns the current vertical scroll position of a Scroll element.
pub fn scroll_offset(id string) f64 {
	st := state()
	scrollv := st.views[id] or { return 0 }
	r := macos.msg_rect(scrollv, 'documentVisibleRect')
	return r.y
}

// scroll_to_rect scrolls a Scroll element so the given document rect is visible.
pub fn scroll_to_rect(id string, x f64, y f64, width f64, height f64) {
	st := state()
	scrollv := st.views[id] or { return }
	doc := macos.msg_id(scrollv, 'documentView')
	if native_is_nil(doc) {
		return
	}
	macos.msg_void_rect(doc, 'scrollRectToVisible:', macos.rect(x, y, width, height))
}

pub fn text(id string) string {
	st := state()
	native := st.views[id] or { return '' }
	kind := st.view_kinds[id] or { Kind.view }
	if kind == .text_area {
		tv := text_area_text_view(native, st.text_area_direct[id] or { false })
		return macos.utf8_string(macos.msg_id(tv, 'string'))
	}
	if kind == .dropdown {
		return native_dropdown_text(native)
	}
	return native_text(native)
}

pub fn set_text(id string, t string) {
	st := state()
	native := st.views[id] or { return }
	kind := st.view_kinds[id] or { Kind.view }
	if kind == .text_area {
		tv := text_area_text_view(native, st.text_area_direct[id] or { false })
		macos.msg_void1(tv, 'setString:', macos.nsstring(t))
		return
	}
	if kind == .dropdown {
		native_select_dropdown_item(native, t)
		return
	}
	native_set_text(native, t)
}

pub fn focus(id string) {
	st := state()
	native := st.views[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) == .text_area {
		tv := text_area_text_view(native, st.text_area_direct[id] or { false })
		native_focus(tv)
		return
	}
	native_focus(native)
}

// text_area_set_caret positions the caret by UTF-16 offset, matching
// NSTextView's native selection storage.
pub fn text_area_set_caret(id string, pos int) {
	tv := text_area_document_view(id) or { return }
	location := if pos < 0 { u64(0) } else { u64(pos) }
	C.ui2_text_view_set_selected_range(voidptr(tv), location, u64(0))
}

pub fn text_area_caret(id string) int {
	tv := text_area_document_view(id) or { return 0 }
	return int(C.ui2_text_view_selected_location(voidptr(tv)))
}

pub fn text_area_selection_length(id string) int {
	tv := text_area_document_view(id) or { return 0 }
	return int(C.ui2_text_view_selected_length(voidptr(tv)))
}

pub fn insert_text_area_text(id string, text string) {
	tv := text_area_document_view(id) or { return }
	C.ui2_text_view_insert_text(voidptr(tv), &char(text.str))
}

// consume_text_key tells the current text-view key delegate call that the app
// handled the key and native NSTextView deletion should not also run.
pub fn consume_text_key() {
	mut st := state()
	st.text_key_consumed = true
}

// consume_key tells the current key handler dispatch that the app handled the
// key and ui2 should not run its default native command.
pub fn consume_key() {
	mut st := state()
	st.key_consumed = true
}

pub fn clipboard_has_image() bool {
	return C.ui2_pasteboard_has_image()
}

pub fn save_clipboard_image_png(path string) bool {
	return C.ui2_pasteboard_write_image_png(&char(path.str))
}

pub fn dismiss_keyboard() {
	st := state()
	if !native_is_nil(st.root_view) {
		native_end_editing(st.root_view)
	}
}

pub fn quit() {
	native_terminate_app()
}

pub fn safe_area_top() f64 {
	return 0
}

pub fn start_barcode_scan() {
	st := state()
	if voidptr(st.event_handler) != unsafe { nil } {
		st.event_handler('scan_error:barcode scanner unavailable')
	}
}

fn screenshot_path() string {
	office_path := os.getenv('OFFICE_SCREENSHOT_PATH')
	if office_path.trim_space() != '' {
		return office_path
	}
	return os.getenv('UI2_SCREENSHOT_PATH')
}

fn screenshot_should_exit() bool {
	return (os.getenv_opt('OFFICE_EXIT_AFTER_SCREENSHOT') or { '0' }) == '1' || (os.getenv_opt('UI2_EXIT_AFTER_SCREENSHOT') or {
		'0'
	}) == '1'
}

fn schedule_screenshot_capture() {
	mut st := state()
	if st.screenshot_captured || st.screenshot_pending || screenshot_path().trim_space() == '' {
		return
	}
	st.screenshot_pending = true
	cb := capture_screenshot_on_main
	C.ui2_dispatch_main(voidptr(cb))
}

fn capture_screenshot_on_main() {
	mut st := state()
	st.screenshot_pending = false
	if st.screenshot_captured || native_is_nil(st.root_view) {
		return
	}
	path := screenshot_path().trim_space()
	if path == '' {
		return
	}
	if os.exists(path) {
		os.rm(path) or {}
	}
	if !C.ui2_view_save_png(voidptr(st.root_view), &char(path.str)) {
		eprintln('ui2 screenshot failed: ${path}')
	}
	st.screenshot_captured = true
	if screenshot_should_exit() {
		native_terminate_app()
	}
}

pub fn toggle_text_area_format(id string, format TextFormat) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	C.ui2_text_view_toggle_format(voidptr(tv), int(format))
	return text_area_format_state(id)
}

pub fn set_text_area_font_family(id string, family string) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	C.ui2_text_view_set_font_family(voidptr(tv), &char(family.str))
	return text_area_format_state(id)
}

pub fn set_text_area_font_size(id string, size f64) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	C.ui2_text_view_set_font_size(voidptr(tv), size)
	return text_area_format_state(id)
}

pub fn set_text_area_color(id string, color u32) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	C.ui2_text_view_set_color(voidptr(tv), color)
	return text_area_format_state(id)
}

pub fn set_text_area_background_color(id string, color u32) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	C.ui2_text_view_set_background_color(voidptr(tv), color)
	return text_area_format_state(id)
}

pub fn toggle_text_area_superscript(id string) TextFormatState {
	return toggle_text_area_vertical_align(id, 'superscript')
}

pub fn toggle_text_area_subscript(id string) TextFormatState {
	return toggle_text_area_vertical_align(id, 'subscript')
}

pub fn toggle_text_area_vertical_align(id string, align string) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	C.ui2_text_view_toggle_vertical_align(voidptr(tv), vertical_align_value(align))
	return text_area_format_state(id)
}

fn vertical_align_value(align string) int {
	return match align {
		'superscript' { 1 }
		'subscript' { -1 }
		else { 0 }
	}
}

pub fn text_area_runs(id string) []TextRun {
	tv := text_area_document_view(id) or { return []TextRun{} }
	raw := macos.utf8_string(C.ui2_text_view_runs(voidptr(tv)))
	return parse_text_area_runs(raw)
}

fn parse_text_area_runs(raw string) []TextRun {
	mut runs := []TextRun{}
	for line in raw.split_into_lines() {
		if line.len == 0 {
			continue
		}
		parts := line.split('\t')
		if parts.len < 6 {
			continue
		}
		run_text := base64.decode_str(parts[0])
		if run_text.len == 0 {
			continue
		}
		runs << TextRun{
			text:  run_text
			style: TextStyle{
				font_family:      base64.decode_str(parts[1])
				size:             parts[2].f64()
				bold:             parts[3] == '1'
				italic:           parts[4] == '1'
				underline:        parts[5] == '1'
				vertical_align:   text_run_vertical_align(if parts.len > 6 { parts[6] } else { '' })
				strikethrough:    parts.len > 7 && parts[7] == '1'
				color:            if parts.len > 8 { u32(parts[8].u64()) } else { u32(0x111111) }
				background_color: if parts.len > 9 { u32(parts[9].u64()) } else { u32(0) }
			}
		}
	}
	return runs
}

fn text_run_vertical_align(value string) string {
	return match value {
		'superscript', 'subscript' { value }
		else { '' }
	}
}

pub fn text_area_format_state(id string) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	vertical := C.ui2_text_view_vertical_align_active(voidptr(tv))
	return TextFormatState{
		bold:          C.ui2_text_view_format_active(voidptr(tv), int(TextFormat.bold))
		italic:        C.ui2_text_view_format_active(voidptr(tv), int(TextFormat.italic))
		underline:     C.ui2_text_view_format_active(voidptr(tv), int(TextFormat.underline))
		strikethrough: C.ui2_text_view_format_active(voidptr(tv), int(TextFormat.strikethrough))
		subscript:     vertical < 0
		superscript:   vertical > 0
	}
}

fn text_area_document_view(id string) ?NativeView {
	st := state()
	native := st.views[id] or { return none }
	if (st.view_kinds[id] or { Kind.view }) != .text_area {
		return none
	}
	tv := text_area_text_view(native, st.text_area_direct[id] or { false })
	if native_is_nil(tv) {
		return none
	}
	return tv
}

fn text_area_text_view(native NativeView, direct bool) NativeView {
	if direct {
		return native
	}
	return macos.msg_id(native, 'documentView')
}

fn ensure_runtime_classes() {
	if macos.get_class('UI2FlippedView') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSView'), 'UI2FlippedView')
		macos.add_method(cls, 'isFlipped', voidptr(C.ui2_view_is_flipped), 'B@:')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2PointerView') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSView'), 'UI2PointerView')
		macos.add_method(cls, 'isFlipped', voidptr(C.ui2_view_is_flipped), 'B@:')
		macos.add_method(cls, 'mouseDown:', voidptr(C.ui2_pointer_mouse_down), 'v@:@')
		macos.add_method(cls, 'mouseDragged:', voidptr(C.ui2_pointer_mouse_dragged), 'v@:@')
		macos.add_method(cls, 'mouseUp:', voidptr(C.ui2_pointer_mouse_up), 'v@:@')
		macos.add_method(cls, 'resetCursorRects', voidptr(C.ui2_pointer_reset_cursor_rects), 'v@:')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2PointerImageView') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSImageView'), 'UI2PointerImageView')
		macos.add_method(cls, 'mouseDown:', voidptr(C.ui2_pointer_mouse_down), 'v@:@')
		macos.add_method(cls, 'mouseDragged:', voidptr(C.ui2_pointer_mouse_dragged), 'v@:@')
		macos.add_method(cls, 'mouseUp:', voidptr(C.ui2_pointer_mouse_up), 'v@:@')
		macos.add_method(cls, 'resetCursorRects', voidptr(C.ui2_pointer_reset_cursor_rects), 'v@:')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2AppDelegate') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2AppDelegate')
		macos.add_method(cls, 'applicationDidFinishLaunching:',
			voidptr(C.ui2_app_did_finish_launching), 'v@:@')
		macos.add_method(cls, 'applicationShouldTerminateAfterLastWindowClosed:',
			voidptr(C.ui2_app_should_terminate_after_last_window_closed), 'B@:@')
		macos.add_method(cls, 'windowDidResize:', voidptr(C.ui2_window_did_resize), 'v@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2ButtonHandler') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2ButtonHandler')
		macos.add_method(cls, 'handleTap:', voidptr(C.ui2_button_tap), 'v@:@')
		macos.add_method(cls, 'controlTextDidChange:', voidptr(C.ui2_control_text_changed), 'v@:@')
		macos.add_method(cls, 'textDidChange:', voidptr(C.ui2_text_view_changed), 'v@:@')
		macos.add_method(cls, 'textView:doCommandBySelector:', voidptr(C.ui2_text_view_do_command),
			'B@:@:')
		macos.add_method(cls, 'textView:clickedOnLink:atIndex:',
			voidptr(C.ui2_text_view_clicked_on_link), 'B@:@@Q')
		macos.add_method(cls, 'ui2BoundsChanged:', voidptr(C.ui2_bounds_changed), 'v@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2Window') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSWindow'), 'UI2Window')
		macos.add_method(cls, 'keyDown:', voidptr(C.ui2_window_key_down), 'v@:@')
		macos.add_method(cls, 'performKeyEquivalent:', voidptr(C.ui2_window_perform_key_equiv),
			'B@:@')
		macos.register_class_pair(cls)
	}
}

fn align_value(a Align) int {
	return match a {
		.left { 0 }
		.center { 1 }
		.right { 2 }
	}
}

fn element_rect(r Rect) NativeRect {
	return native_rect(r.x, r.y, r.width, r.height)
}

fn render_root(root Element) {
	mut st := state()
	st.views = map[string]NativeView{}
	st.view_kinds = map[string]Kind{}
	st.text_area_direct = map[string]bool{}
	st.pointer_ids = map[u64]string{}
	st.pointer_draggable = map[u64]bool{}
	st.cursor_ids = map[u64]string{}
	st.control_ids = map[u64]string{}
	st.button_ids = []string{}
	native_set_background(st.root_view, root.box.bg)
	mut active := map[string]bool{}
	for i, child in root.children {
		render_element(st.root_view, child, child_key('', i, child), mut active)
	}
	remove_stale_nodes(active)
}

fn render_element(parent NativeView, el Element, key string, mut active map[string]bool) NativeView {
	active[key] = true
	mut st := state()
	mut native := st.nodes[key] or { native_nil_view() }
	existing_kind := st.node_kinds[key] or { Kind.screen }
	existing_direct := st.node_text_direct[key] or { false }
	existing_interactive := st.node_interactive[key] or { false }
	interactive := element_interactive(el)
	text_area_mode_changed := el.kind == .text_area && existing_kind == .text_area
		&& existing_direct != el.disable_scroll
	interactive_changed := (el.kind == .view || el.kind == .image) && existing_kind == el.kind
		&& existing_interactive != interactive
	if native_is_nil(native) || existing_kind != el.kind || text_area_mode_changed
		|| interactive_changed {
		if !native_is_nil(native) {
			native_remove_from_superview(native)
		}
		native = native_create_element(el)
		st.nodes[key] = native
		st.node_kinds[key] = el.kind
		st.node_interactive[key] = interactive
		if el.kind == .text_area {
			st.node_text_direct[key] = el.disable_scroll
		}
		if el.kind != .screen {
			native_add_subview(parent, native)
		}
	} else {
		native_update_element(native, el)
	}

	match el.kind {
		.screen {
			native = parent
			for i, child in el.children {
				render_element(parent, child, child_key(key, i, child), mut active)
			}
		}
		.view {
			register_pointer(native, el)
			for i, child in el.children {
				render_element(native, child, child_key(key, i, child), mut active)
			}
		}
		.scroll {
			// Observe scroll position changes for virtualized lists
			clip := macos.msg_id(native, 'contentView')
			if el.id.len > 0 {
				st.scroll_ids[u64(voidptr(clip))] = el.id
			}
			if u64(voidptr(clip)) !in st.observed {
				st.observed[u64(voidptr(clip))] = true
				macos.msg_void_bool(clip, 'setPostsBoundsChangedNotifications:', true)
				C.ui2_observe_bounds(voidptr(st.button_handler), voidptr(clip))
			}
			doc_key := key + '/document'
			active[doc_key] = true
			doc_h := content_height(el.children) + 16
			mut doc := st.nodes[doc_key] or { native_nil_view() }
			if native_is_nil(doc) {
				doc = native_new_flipped_view(native_rect(0, 0, el.frame.width, doc_h), el.box.bg)
				st.nodes[doc_key] = doc
				st.node_kinds[doc_key] = .view
				native_set_document_view(native, doc)
			} else {
				native_set_frame(doc, native_rect(0, 0, el.frame.width, doc_h))
				native_set_background(doc, el.box.bg)
			}
			for i, child in el.children {
				render_element(doc, child, child_key(doc_key, i, child), mut active)
			}
		}
		.button {
			register_button(native, el.id)
		}
		.dropdown {
			register_action_control(native, el.id)
		}
		.text_field {
			if el.emit_change {
				register_control(native, el.id)
			}
		}
		.text_area {
			if el.id.len > 0 {
				tv := text_area_text_view(native, el.disable_scroll)
				st.textview_ids[u64(voidptr(tv))] = el.id
				st.text_area_direct[el.id] = el.disable_scroll
			}
		}
		.label {
			// Labels are updated by native_update_element.
		}
		.image {
			register_pointer(native, el)
		}
	}

	if el.menu.len > 0 && el.kind != .dropdown {
		attach_menu(native, el.menu)
	}

	if el.id.len > 0 {
		st.views[el.id] = native
		st.view_kinds[el.id] = el.kind
	}
	return native
}

// attach_menu builds a right-click context menu for an element. Item taps
// arrive through the same handler/tag registry as buttons.
fn attach_menu(native NativeView, entries []MenuEntry) {
	mut st := state()
	menu := macos.msg_id(macos.alloc('NSMenu'), 'init')
	for e in entries {
		tag := st.button_ids.len
		st.button_ids << e.id
		item := macos.msg_id3(macos.alloc('NSMenuItem'), 'initWithTitle:action:keyEquivalent:',
			macos.nsstring(e.title), macos.Id(voidptr(macos.sel('handleTap:'))), macos.nsstring(''))
		macos.msg_void1(item, 'setTarget:', st.button_handler)
		macos.msg_void_i64(item, 'setTag:', i64(tag))
		macos.msg_void1(menu, 'addItem:', item)
	}
	macos.msg_void1(native, 'setMenu:', menu)
}

fn native_create_element(el Element) NativeView {
	return match el.kind {
		.screen {
			native_nil_view()
		}
		.view {
			native_new_view(element_rect(el.frame), el.box.bg, element_interactive(el))
		}
		.scroll {
			native_new_scroll(element_rect(el.frame), el.box.bg)
		}
		.label {
			native_new_label(element_rect(el.frame), el.text, el.text_style.color,
				el.text_style.size, el.text_style.bold, el.text_style.italic,
				el.text_style.underline, align_value(el.text_style.align), el.text_style.lines)
		}
		.image {
			native_new_image(element_rect(el.frame), el.image_path, el.rotation)
		}
		.button {
			native_new_button(element_rect(el.frame), el.text, el.box.bg, el.text_style.color,
				el.text_style.size, el.text_style.bold, el.text_style.italic,
				el.text_style.underline, el.box.radius, el.text_style.lines, el.image_path)
		}
		.dropdown {
			native_new_dropdown(el)
		}
		.text_field {
			native_new_text_field(el)
		}
		.text_area {
			native_new_text_area(el)
		}
	}
}

fn native_update_element(native NativeView, el Element) {
	match el.kind {
		.screen {}
		.view {
			native_set_frame(native, element_rect(el.frame))
			native_set_background(native, el.box.bg)
			native_set_corner_radius(native, el.box.radius)
		}
		.scroll {
			native_set_frame(native, element_rect(el.frame))
			native_set_scroll_background(native, el.box.bg)
		}
		.label {
			native_update_label(native, element_rect(el.frame), el.text, el.text_style.color,
				el.text_style.size, el.text_style.bold, el.text_style.italic,
				el.text_style.underline, align_value(el.text_style.align), el.text_style.lines)
		}
		.image {
			native_update_image(native, element_rect(el.frame), el.image_path, el.rotation)
		}
		.button {
			native_update_button(native, element_rect(el.frame), el.text, el.box.bg,
				el.text_style.color, el.text_style.size, el.text_style.bold, el.text_style.italic,
				el.text_style.underline, el.box.radius, el.text_style.lines, el.image_path)
		}
		.dropdown {
			native_update_dropdown(native, el)
		}
		.text_field {
			native_update_text_field(native, element_rect(el.frame), el.placeholder, el.text,
				el.box.bg, el.text_style.color, el.text_style.size, el.box.radius)
		}
		.text_area {
			native_update_text_area(native, el)
		}
	}
}

fn element_interactive(el Element) bool {
	return el.clickable || el.draggable || el.cursor.len > 0
}

// child_key prefers the element's explicit key over its index, so windowed
// lists keep native-view identity while scrolling.
fn child_key(parent string, index int, el Element) string {
	suffix := if el.key.len > 0 { 'k:' + el.key } else { index.str() }
	if parent.len == 0 {
		return suffix
	}
	return parent + '/' + suffix
}

fn register_pointer(native NativeView, el Element) {
	if el.id.len == 0 || !element_interactive(el) {
		return
	}
	mut st := state()
	key := u64(voidptr(native))
	if el.clickable || el.draggable {
		st.pointer_ids[key] = el.id
		st.pointer_draggable[key] = el.draggable
	}
	if el.cursor.len > 0 {
		st.cursor_ids[key] = el.cursor
	}
	native_invalidate_cursor_rects(native)
}

fn register_button(native NativeView, id string) {
	mut st := state()
	tag := st.button_ids.len
	st.button_ids << id
	st.control_ids[u64(voidptr(native))] = id
	native_set_tag(native, tag)
	native_set_button_target(native, st.button_handler)
	native_set_associated_object(native, assoc_handler_key(), st.button_handler)
}

fn register_action_control(native NativeView, id string) {
	mut st := state()
	tag := st.button_ids.len
	st.button_ids << id
	st.control_ids[u64(voidptr(native))] = id
	native_set_tag(native, tag)
	native_set_control_target(native, st.button_handler)
	native_set_associated_object(native, assoc_handler_key(), st.button_handler)
}

fn register_control(native NativeView, id string) {
	mut st := state()
	tag := st.button_ids.len
	st.button_ids << id
	st.control_ids[u64(voidptr(native))] = id
	native_set_tag(native, tag)
	native_set_control_target(native, st.button_handler)
	// Delegate delivers controlTextDidChange: for per-keystroke events
	macos.msg_void1(native, 'setDelegate:', st.button_handler)
	native_set_associated_object(native, assoc_handler_key(), st.button_handler)
}

fn remove_stale_nodes(active map[string]bool) {
	mut st := state()
	mut stale := []string{}
	for key, _ in st.nodes {
		if key !in active {
			stale << key
		}
	}
	for key in stale {
		native := st.nodes[key] or { continue }
		native_remove_from_superview(native)
		st.nodes.delete(key)
		st.node_kinds.delete(key)
		st.node_interactive.delete(key)
	}
}

fn content_height(children []Element) f64 {
	mut h := f64(0)
	for child in children {
		bottom := child.frame.y + child.frame.height
		if bottom > h {
			h = bottom
		}
	}
	return h
}

fn assoc_handler_key() voidptr {
	return voidptr(macos.sel('ui2_button_handler_assoc'))
}

fn native_rect(x f64, y f64, width f64, height f64) NativeRect {
	return NativeRect{
		x:      x
		y:      y
		width:  width
		height: height
	}
}

fn appkit_rect(r NativeRect) macos.Rect {
	return macos.rect(r.x, r.y, r.width, r.height)
}

fn native_nil_view() NativeView {
	return NativeView(unsafe { nil })
}

fn native_is_nil(v NativeView) bool {
	return voidptr(v) == unsafe { nil }
}

fn native_color(hex u32) macos.Id {
	return C.ui2_nscolor_rgb(hex)
}

fn native_run_app() {
	macos.msg_void(native_current_app(), 'run')
}

fn native_current_app() macos.Id {
	return macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
}

fn native_activate() {
	macos.msg_void_bool(native_current_app(), 'activateIgnoringOtherApps:', true)
}

fn native_set_activation_policy_regular() {
	macos.msg_void_i64(native_current_app(), 'setActivationPolicy:', 0)
}

fn native_set_delegate(delegate NativeView) {
	macos.msg_void1(native_current_app(), 'setDelegate:', delegate)
}

fn native_new_window(frame NativeRect, title string) NativeView {
	style := ns_window_style_titled | ns_window_style_closable | ns_window_style_miniaturizable | ns_window_style_resizable
	window := C.macos_objc_msg_id_rect_u64_u64_bool(macos.alloc('UI2Window'),
		macos.sel('initWithContentRect:styleMask:backing:defer:'), appkit_rect(frame), style,
		ns_backing_store_buffered, false)
	macos.msg_void1(window, 'setTitle:', macos.nsstring(title))
	macos.msg_void_bool(window, 'setReleasedWhenClosed:', false)
	return window
}

fn native_make_key_and_order_front(window NativeView) {
	macos.msg_void1(window, 'makeKeyAndOrderFront:', native_nil_view())
}

fn native_set_content_view(window NativeView, view NativeView) {
	macos.msg_void1(window, 'setContentView:', view)
}

fn native_bounds(view NativeView) NativeRect {
	b := macos.msg_rect(view, 'bounds')
	return native_rect(b.x, b.y, b.width, b.height)
}

fn native_add_subview(parent NativeView, child NativeView) {
	macos.msg_void1(parent, 'addSubview:', child)
}

fn native_remove_from_superview(view NativeView) {
	if native_is_nil(view) {
		return
	}
	macos.msg_void(view, 'removeFromSuperview')
}

fn native_invalidate_cursor_rects(view NativeView) {
	if native_is_nil(view) {
		return
	}
	C.ui2_invalidate_cursor_rects(voidptr(view))
}

fn native_new_object(class_name string) NativeView {
	return macos.msg_id(macos.alloc(class_name), 'init')
}

fn native_set_tag(view NativeView, tag int) {
	macos.msg_void_i64(view, 'setTag:', i64(tag))
}

fn native_tag(view NativeView) int {
	return int(macos.msg_i64(view, 'tag'))
}

fn native_set_associated_object(obj NativeView, key voidptr, value NativeView) {
	macos.set_associated_object(obj, key, value, macos.assoc_retain_nonatomic)
}

fn native_new_flipped_view(frame NativeRect, bg u32) NativeView {
	native := macos.msg_id_rect(macos.alloc('UI2FlippedView'), 'initWithFrame:', appkit_rect(frame))
	native_set_background(native, bg)
	return native
}

fn native_new_view(frame NativeRect, bg u32, interactive bool) NativeView {
	class_name := if interactive { 'UI2PointerView' } else { 'UI2FlippedView' }
	native := macos.msg_id_rect(macos.alloc(class_name), 'initWithFrame:', appkit_rect(frame))
	native_set_background(native, bg)
	return native
}

fn native_new_scroll(frame NativeRect, bg u32) NativeView {
	scroll_view := macos.msg_id_rect(macos.alloc('NSScrollView'), 'initWithFrame:',
		appkit_rect(frame))
	macos.msg_void_bool(scroll_view, 'setHasVerticalScroller:', true)
	macos.msg_void_bool(scroll_view, 'setAutohidesScrollers:', true)
	macos.msg_void_bool(scroll_view, 'setDrawsBackground:', true)
	native_set_scroll_background(scroll_view, bg)
	return scroll_view
}

fn native_set_document_view(scroll NativeView, view NativeView) {
	macos.msg_void1(scroll, 'setDocumentView:', view)
}

fn native_set_scroll_background(scroll NativeView, bg u32) {
	macos.msg_void_bool(scroll, 'setDrawsBackground:', true)
	macos.msg_void1(scroll, 'setBackgroundColor:', native_color(bg))
}

fn native_new_image(frame NativeRect, path string, rotation f64) NativeView {
	image_view := macos.msg_id_rect(macos.alloc('UI2PointerImageView'), 'initWithFrame:',
		appkit_rect(frame))
	native_update_image(image_view, frame, path, rotation)
	return image_view
}

fn native_update_image(image_view NativeView, frame NativeRect, path string, rotation f64) {
	rotated := rotation < -0.001 || rotation > 0.001
	C.ui2_view_reset_transform(voidptr(image_view))
	native_set_frame(image_view, frame)
	macos.msg_void_i64(image_view, 'setImageScaling:', 3)
	if rotated {
		C.ui2_view_set_rotation(voidptr(image_view), rotation)
	} else {
		C.ui2_view_clear_rotation(voidptr(image_view))
	}
	if path.trim_space() == '' {
		macos.msg_void1(image_view, 'setImage:', macos.Id(unsafe { nil }))
		return
	}
	img := macos.msg_id1(macos.alloc('NSImage'), 'initWithContentsOfFile:', macos.nsstring(path))
	macos.msg_void1(image_view, 'setImage:', img)
}

fn native_new_label(frame NativeRect, text string, text_hex u32, size f64, bold bool, italic bool, underline bool, align int, lines int) NativeView {
	label_view := macos.msg_id_rect(macos.alloc('NSTextField'), 'initWithFrame:',
		appkit_rect(frame))
	native_update_label(label_view, frame, text, text_hex, size, bold, italic, underline, align,
		lines)
	return label_view
}

fn native_update_label(label_view NativeView, frame NativeRect, text string, text_hex u32, size f64, bold bool, italic bool, underline bool, align int, lines int) {
	native_set_frame(label_view, frame)
	macos.msg_void1(label_view, 'setStringValue:', macos.nsstring(text))
	macos.msg_void_bool(label_view, 'setEditable:', false)
	macos.msg_void_bool(label_view, 'setSelectable:', false)
	macos.msg_void_bool(label_view, 'setBordered:', false)
	macos.msg_void_bool(label_view, 'setBezeled:', false)
	macos.msg_void_bool(label_view, 'setDrawsBackground:', false)
	macos.msg_void1(label_view, 'setTextColor:', native_color(text_hex))
	macos.msg_void1(label_view, 'setFont:', native_font(size, bold, italic))
	if italic || underline {
		C.ui2_control_set_attributed_title(voidptr(label_view), &char(text.str), text_hex, size,
			bold, italic, underline)
	}
	macos.msg_void_i64(label_view, 'setAlignment:', i64(align))
	cell := macos.msg_id(label_view, 'cell')
	macos.msg_void_i64(cell, 'setLineBreakMode:', 4)
	macos.msg_void_bool(cell, 'setUsesSingleLineMode:', lines == 1)
}

fn native_new_button(frame NativeRect, title string, bg_hex u32, text_hex u32, size f64, bold bool, italic bool, underline bool, radius f64, lines int, image_name string) NativeView {
	button_view := macos.msg_id_rect(macos.alloc('NSButton'), 'initWithFrame:', appkit_rect(frame))
	native_update_button(button_view, frame, title, bg_hex, text_hex, size, bold, italic,
		underline, radius, lines, image_name)
	return button_view
}

fn native_update_button(button_view NativeView, frame NativeRect, title string, bg_hex u32, text_hex u32, size f64, bold bool, italic bool, underline bool, radius f64, lines int, image_name string) {
	native_set_frame(button_view, frame)
	macos.msg_void_i64(button_view, 'setButtonType:', ns_button_type_momentary_change)
	macos.msg_void1(button_view, 'setTitle:', macos.nsstring(title))
	macos.msg_void_u64(button_view, 'setBezelStyle:', 1)
	macos.msg_void_bool(button_view, 'setBordered:', false)
	macos.msg_void1(button_view, 'setFont:', native_font(size, bold, italic))
	C.ui2_control_set_attributed_title(voidptr(button_view), &char(title.str), text_hex, size,
		bold, italic, underline)
	native_set_background(button_view, bg_hex)
	native_set_corner_radius(button_view, radius)
	cell := macos.msg_id(button_view, 'cell')
	macos.msg_void_i64(cell, 'setLineBreakMode:', 4)
	macos.msg_void_bool(cell, 'setUsesSingleLineMode:', lines == 1)
	native_update_button_image(button_view, frame, image_name)
	native_clear_control_state(button_view)
}

fn native_update_button_image(button_view NativeView, frame NativeRect, image_name string) {
	if image_name.trim_space() == '' {
		macos.msg_void1(button_view, 'setImage:', macos.Id(unsafe { nil }))
		macos.msg_void_i64(button_view, 'setImagePosition:', 0)
		return
	}
	icon_size := if frame.height >= 42 {
		if frame.height - 12 < 46.0 { frame.height - 12 } else { 46.0 }
	} else {
		13.0
	}
	icon_image := C.ui2_image_from_name_sized(&char(image_name.str), icon_size, icon_size)
	macos.msg_void1(button_view, 'setImage:', icon_image)
	macos.msg_void_i64(button_view, 'setImagePosition:', if frame.height >= 42 {
		i64(5)
	} else {
		i64(2)
	})
	macos.msg_void_i64(button_view, 'setImageScaling:', 3)
}

fn native_new_dropdown(el Element) NativeView {
	popup := macos.msg_id_rect(macos.alloc('NSPopUpButton'), 'initWithFrame:',
		appkit_rect(element_rect(el.frame)))
	native_update_dropdown(popup, el)
	return popup
}

fn native_update_dropdown(popup NativeView, el Element) {
	native_set_frame(popup, element_rect(el.frame))
	macos.msg_void(popup, 'removeAllItems')
	for item in el.menu {
		macos.msg_void1(popup, 'addItemWithTitle:', macos.nsstring(item.title))
	}
	native_select_dropdown_item(popup, el.text)
	macos.msg_void1(popup, 'setFont:', native_font(el.text_style.size, el.text_style.bold,
		el.text_style.italic))
	macos.msg_void_bool(popup, 'setBordered:', true)
	macos.msg_void_u64(popup, 'setBezelStyle:', 1)
}

fn native_new_text_field(el Element) NativeView {
	frame := element_rect(el.frame)
	cls := if el.secure { 'NSSecureTextField' } else { 'NSTextField' }
	field := macos.msg_id_rect(macos.alloc(cls), 'initWithFrame:', appkit_rect(frame))
	native_update_text_field(field, frame, el.placeholder, el.text, el.box.bg, el.text_style.color,
		el.text_style.size, el.box.radius)
	return field
}

fn native_update_text_field(field NativeView, frame NativeRect, placeholder string, text string, bg_hex u32, text_hex u32, size f64, radius f64) {
	native_set_frame(field, frame)
	// Only replace the value when it actually changed — a rebuild during
	// editing must not reset the cursor or editing session.
	cur := macos.utf8_string(macos.msg_id(field, 'stringValue'))
	if cur != text {
		macos.msg_void1(field, 'setStringValue:', macos.nsstring(text))
	}
	macos.msg_void1(field, 'setPlaceholderString:', macos.nsstring(placeholder))
	macos.msg_void1(field, 'setTextColor:', native_color(text_hex))
	macos.msg_void1(field, 'setFont:', native_font(size, false, false))
	macos.msg_void_bool(field, 'setBordered:', true)
	macos.msg_void_bool(field, 'setDrawsBackground:', true)
	macos.msg_void1(field, 'setBackgroundColor:', native_color(bg_hex))
	native_set_corner_radius(field, radius)
}

// native_new_text_area builds an NSScrollView wrapping an NSTextView —
// native multi-line editing with wrapping, selection, clipboard and undo.
fn native_new_text_area(el Element) NativeView {
	frame := element_rect(el.frame)
	if el.disable_scroll {
		tv := native_new_text_view(appkit_rect(frame), el)
		return tv
	}
	scroll_view := macos.msg_id_rect(macos.alloc('NSScrollView'), 'initWithFrame:',
		appkit_rect(frame))
	macos.msg_void_bool(scroll_view, 'setHasVerticalScroller:', true)
	macos.msg_void_bool(scroll_view, 'setAutohidesScrollers:', true)
	tv := native_new_text_view(macos.rect(0, 0, frame.width, frame.height), el)
	macos.msg_void1(scroll_view, 'setDocumentView:', tv)
	native_set_corner_radius(scroll_view, el.box.radius)
	return scroll_view
}

fn native_new_text_view(frame macos.Rect, el Element) NativeView {
	tv := macos.msg_id_rect(macos.alloc('NSTextView'), 'initWithFrame:', frame)
	macos.msg_void1(tv, 'setFont:', native_font(el.text_style.size, el.text_style.bold,
		el.text_style.italic))
	macos.msg_void_bool(tv, 'setRichText:', el.text_runs.len > 0)
	macos.msg_void_bool(tv, 'setAllowsUndo:', true)
	macos.msg_void_bool(tv, 'setVerticallyResizable:', true)
	macos.msg_void_bool(tv, 'setHorizontallyResizable:', false)
	macos.msg_void_u64(tv, 'setAutoresizingMask:', 2) // NSViewWidthSizable
	macos.msg_void_bool(tv, 'setDrawsBackground:', !el.box.transparent)
	if !el.box.transparent {
		macos.msg_void1(tv, 'setBackgroundColor:', native_color(el.box.bg))
	}
	macos.msg_void1(tv, 'setTextColor:', native_color(el.text_style.color))
	macos.msg_void_bool(tv, 'setEditable:', !el.readonly)
	macos.msg_void_bool(tv, 'setSelectable:', true)
	native_set_text_area_content(tv, el)
	st := state()
	macos.msg_void1(tv, 'setDelegate:', st.button_handler)
	return tv
}

fn native_update_text_area(native NativeView, el Element) {
	frame := element_rect(el.frame)
	native_set_frame(native, frame)
	if !el.disable_scroll {
		macos.msg_void_bool(native, 'setHasVerticalScroller:', true)
		macos.msg_void_bool(native, 'setAutohidesScrollers:', true)
	}
	tv := text_area_text_view(native, el.disable_scroll)
	if native_is_nil(tv) {
		return
	}
	macos.msg_void_bool(tv, 'setEditable:', !el.readonly)
	macos.msg_void_bool(tv, 'setDrawsBackground:', !el.box.transparent)
	if !el.box.transparent {
		macos.msg_void1(tv, 'setBackgroundColor:', native_color(el.box.bg))
	}
	// Same guard as text fields: don't clobber an active editing session
	cur := macos.utf8_string(macos.msg_id(tv, 'string'))
	if cur != el.text {
		native_set_text_area_content(tv, el)
	}
}

fn native_set_text_area_content(tv NativeView, el Element) {
	if el.text_runs.len == 0 {
		macos.msg_void_bool(tv, 'setRichText:', false)
		macos.msg_void1(tv, 'setString:', macos.nsstring(el.text))
		return
	}
	macos.msg_void_bool(tv, 'setRichText:', true)
	C.ui2_text_view_set_attributed_string(voidptr(tv), &char(el.text.str), el.text_style.color,
		el.text_style.background_color, el.text_style.size, &char(el.text_style.font_family.str),
		el.text_style.bold, el.text_style.italic, el.text_style.underline,
		el.text_style.strikethrough, &char(el.text_style.vertical_align.str))
	mut location := u64(0)
	for run in el.text_runs {
		length := C.ui2_utf16_length(&char(run.text.str))
		if length > 0 {
			C.ui2_text_view_add_style(voidptr(tv), location, length, run.style.color,
				run.style.background_color, run.style.size, &char(run.style.font_family.str),
				run.style.bold, run.style.italic, run.style.underline, run.style.strikethrough,
				&char(run.style.vertical_align.str))
			if run.style.link.len > 0 {
				C.ui2_text_view_add_link(voidptr(tv), location, length, &char(run.style.link.str))
			}
		}
		location += length
	}
}

fn native_set_button_target(button NativeView, target NativeView) {
	macos.msg_void1(button, 'setTarget:', target)
	macos.msg_void1(button, 'setAction:', macos.sel('handleTap:'))
}

fn native_set_control_target(control NativeView, target NativeView) {
	macos.msg_void1(control, 'setTarget:', target)
	macos.msg_void1(control, 'setAction:', macos.sel('handleTap:'))
}

fn native_clear_control_state(control NativeView) {
	macos.msg_void_i64(control, 'setState:', 0)
	macos.msg_void_bool(control, 'highlight:', false)
}

fn native_text(view NativeView) string {
	return macos.utf8_string(macos.msg_id(view, 'stringValue'))
}

fn native_dropdown_text(view NativeView) string {
	item := macos.msg_id(view, 'selectedItem')
	if native_is_nil(item) {
		return ''
	}
	return macos.utf8_string(macos.msg_id(item, 'title'))
}

fn native_set_text(view NativeView, text string) {
	macos.msg_void1(view, 'setStringValue:', macos.nsstring(text))
}

fn native_select_dropdown_item(view NativeView, text string) {
	macos.msg_void1(view, 'selectItemWithTitle:', macos.nsstring(text))
}

fn native_focus(view NativeView) {
	macos.msg_bool(view, 'becomeFirstResponder')
}

fn native_end_editing(view NativeView) {
	macos.msg_bool(view, 'resignFirstResponder')
}

fn native_terminate_app() {
	macos.msg_void1(native_current_app(), 'terminate:', macos.Id(unsafe { nil }))
}

fn native_set_frame(view NativeView, frame NativeRect) {
	macos.msg_void_rect(view, 'setFrame:', appkit_rect(frame))
}

fn native_set_background(view NativeView, hex u32) {
	macos.msg_void_bool(view, 'setWantsLayer:', true)
	layer := macos.msg_id(view, 'layer')
	macos.msg_void1(layer, 'setBackgroundColor:', macos.msg_id(native_color(hex), 'CGColor'))
}

fn native_set_corner_radius(view NativeView, radius f64) {
	macos.msg_void_bool(view, 'setWantsLayer:', true)
	layer := macos.msg_id(view, 'layer')
	macos.msg_void_f64(layer, 'setCornerRadius:', radius)
	macos.msg_void_bool(layer, 'setMasksToBounds:', radius > 0)
}

fn native_font(size f64, bold bool, italic bool) NativeView {
	_ = italic
	if bold {
		return macos.msg_id_f64(macos.get_class('NSFont'), 'boldSystemFontOfSize:', size)
	}
	return macos.msg_id_f64(macos.get_class('NSFont'), 'systemFontOfSize:', size)
}

@[export: 'ui2_view_is_flipped']
fn ui2_view_is_flipped(_self voidptr, _cmd voidptr) bool {
	return true
}

@[export: 'ui2_app_should_terminate_after_last_window_closed']
fn ui2_app_should_terminate_after_last_window_closed(_self voidptr, _cmd voidptr, _sender voidptr) bool {
	return true
}

@[export: 'ui2_app_did_finish_launching']
fn ui2_app_did_finish_launching(_self voidptr, _cmd voidptr, _notification voidptr) {
	mut st := state()
	frame := native_rect(120, 120, f64(st.run_config.width), f64(st.run_config.height))
	st.window = native_new_window(frame, st.run_config.title)
	// The app delegate doubles as window delegate for windowDidResize:
	macos.msg_void1(st.window, 'setDelegate:', st.app_delegate)
	root_frame := native_rect(0, 0, f64(st.run_config.width), f64(st.run_config.height))
	st.root_view = native_new_flipped_view(root_frame, 0xffffff)
	native_set_content_view(st.window, st.root_view)
	if native_is_nil(st.button_handler) {
		st.button_handler = native_new_object('UI2ButtonHandler')
	}
	native_make_key_and_order_front(st.window)
	native_activate()
	refresh()
}

fn fire_pointer_event(native NativeView, phase string, event voidptr) {
	st := state()
	id := st.pointer_ids[u64(voidptr(native))] or { return }
	if phase == 'drag' && !(st.pointer_draggable[u64(voidptr(native))] or { false }) {
		return
	}
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	x := C.ui2_event_x_in_view(voidptr(st.root_view), event)
	y := C.ui2_event_y_in_view(voidptr(st.root_view), event)
	st.event_handler('pointer:${phase}:${id}:${x}:${y}')
}

@[export: 'ui2_pointer_mouse_down']
fn ui2_pointer_mouse_down(self voidptr, _cmd voidptr, event voidptr) {
	fire_pointer_event(NativeView(self), 'down', event)
}

@[export: 'ui2_pointer_mouse_dragged']
fn ui2_pointer_mouse_dragged(self voidptr, _cmd voidptr, event voidptr) {
	fire_pointer_event(NativeView(self), 'drag', event)
}

@[export: 'ui2_pointer_mouse_up']
fn ui2_pointer_mouse_up(self voidptr, _cmd voidptr, event voidptr) {
	fire_pointer_event(NativeView(self), 'up', event)
}

@[export: 'ui2_pointer_reset_cursor_rects']
fn ui2_pointer_reset_cursor_rects(self voidptr, _cmd voidptr) {
	st := state()
	cursor := st.cursor_ids[u64(self)] or { return }
	if cursor.len == 0 {
		return
	}
	C.ui2_add_cursor_rect(self, &char(cursor.str))
}

@[export: 'ui2_button_tap']
fn ui2_button_tap(_self voidptr, _cmd voidptr, sender voidptr) {
	st := state()
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	native := NativeView(sender)
	id := st.control_ids[u64(voidptr(native))] or { '' }
	if id.len > 0 {
		native_clear_control_state(native)
		st.event_handler(id)
		native_clear_control_state(native)
		return
	}
	tag := native_tag(native)
	if tag < 0 || tag >= st.button_ids.len {
		return
	}
	st.event_handler(st.button_ids[tag])
}

@[export: 'ui2_control_text_changed']
fn ui2_control_text_changed(_self voidptr, _cmd voidptr, notification voidptr) {
	st := state()
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	field := macos.msg_id(macos.Id(notification), 'object')
	id := st.control_ids[u64(voidptr(field))] or { '' }
	if id.len > 0 {
		st.event_handler(id)
		return
	}
	tag := int(macos.msg_i64(field, 'tag'))
	if tag < 0 || tag >= st.button_ids.len {
		return
	}
	st.event_handler(st.button_ids[tag])
}

@[export: 'ui2_text_view_changed']
fn ui2_text_view_changed(_self voidptr, _cmd voidptr, notification voidptr) {
	st := state()
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	tv := macos.msg_id(macos.Id(notification), 'object')
	id := st.textview_ids[u64(voidptr(tv))] or { return }
	st.event_handler(id)
}

@[export: 'ui2_text_view_do_command']
fn ui2_text_view_do_command(_self voidptr, _cmd voidptr, text_view voidptr, command voidptr) bool {
	mut st := state()
	if voidptr(st.key_handler) == unsafe { nil } {
		return false
	}
	key := text_command_key(command, C.ui2_current_event_modifier_flags()) or { return false }
	id := st.textview_ids[u64(text_view)] or { return false }
	boundary_noop := text_command_boundary_noop(text_view, key)
	st.text_key_consumed = false
	st.key_handler('text:${id}:${key}')
	consumed := st.text_key_consumed || boundary_noop
	st.text_key_consumed = false
	return consumed
}

@[export: 'ui2_text_view_clicked_on_link']
fn ui2_text_view_clicked_on_link(_self voidptr, _cmd voidptr, text_view voidptr, link voidptr, _char_index u64) bool {
	st := state()
	if voidptr(st.event_handler) == unsafe { nil } {
		return false
	}
	id := st.textview_ids[u64(text_view)] or { return false }
	target := macos.utf8_string(macos.msg_id(macos.Id(link), 'description'))
	if target.len == 0 {
		return false
	}
	st.event_handler('link:${id}:${base64.encode_str(target)}')
	return true
}

fn text_command_key(command voidptr, modifiers u64) ?string {
	name := macos.utf8_string(C.ui2_selector_name(command))
	shift := modifiers & 0x20000 != 0
	return match name {
		'deleteBackward:' {
			'backspace'
		}
		'deleteForward:' {
			'forward_delete'
		}
		'insertLineBreak:' {
			'line_break'
		}
		'insertNewline:', 'insertParagraphSeparator:' {
			if shift {
				'line_break'
			} else {
				'enter'
			}
		}
		else {
			none
		}
	}
}

fn text_command_boundary_noop(text_view voidptr, key string) bool {
	selected_length := C.ui2_text_view_selected_length(text_view)
	if selected_length > 0 {
		return false
	}
	location := C.ui2_text_view_selected_location(text_view)
	text_length := C.ui2_text_view_text_length(text_view)
	return match key {
		'backspace' { location == 0 }
		'forward_delete' { location >= text_length }
		else { false }
	}
}

@[export: 'ui2_bounds_changed']
fn ui2_bounds_changed(_self voidptr, _cmd voidptr, notification voidptr) {
	st := state()
	if voidptr(st.scroll_handler) == unsafe { nil } {
		return
	}
	clip := macos.msg_id(macos.Id(notification), 'object')
	id := st.scroll_ids[u64(voidptr(clip))] or { return }
	st.scroll_handler(id)
}

@[export: 'ui2_window_did_resize']
fn ui2_window_did_resize(_self voidptr, _cmd voidptr, _notification voidptr) {
	refresh()
}

@[export: 'ui2_window_key_down']
fn ui2_window_key_down(_self voidptr, _cmd voidptr, event voidptr) {
	st := state()
	if voidptr(st.key_handler) == unsafe { nil } {
		return
	}
	st.key_handler(key_event_string(macos.Id(event)))
}

@[export: 'ui2_window_perform_key_equiv']
fn ui2_window_perform_key_equiv(_self voidptr, _cmd voidptr, event voidptr) bool {
	s := key_event_string(macos.Id(event))
	if s == 'cmd+v' && C.ui2_pasteboard_has_image() {
		st := state()
		if voidptr(st.key_handler) != unsafe { nil } {
			st.key_handler(s)
			return true
		}
	}
	if dispatch_pre_native_command_key(s) {
		return true
	}
	if handle_native_edit_key(s) {
		return true
	}
	st := state()
	if voidptr(st.key_handler) == unsafe { nil } || !s.starts_with('cmd+') || s == 'cmd+q' {
		return false
	}
	st.key_handler(s)
	return true
}

fn dispatch_pre_native_command_key(key string) bool {
	if key != 'cmd+z' && key != 'cmd+shift+z' && key != 'cmd+y' && key != 'cmd+q' {
		return false
	}
	mut st := state()
	if voidptr(st.key_handler) == unsafe { nil } {
		return false
	}
	st.key_consumed = false
	st.key_handler(key)
	consumed := st.key_consumed
	st.key_consumed = false
	return consumed
}

fn handle_native_edit_key(key string) bool {
	command := match key {
		'cmd+a' { 0 }
		'cmd+x' { 1 }
		'cmd+c' { 2 }
		'cmd+v' { 3 }
		'cmd+z' { 4 }
		'cmd+y', 'cmd+shift+z' { 5 }
		else { return false }
	}

	return C.ui2_app_send_edit_command(command)
}

// key_event_string normalizes an NSEvent into 'cmd+shift+r' style strings.
fn key_event_string(event macos.Id) string {
	chars := macos.utf8_string(macos.msg_id(event, 'charactersIgnoringModifiers'))
	mods := macos.msg_u64(event, 'modifierFlags')
	mut name := ''
	if chars.len > 0 {
		r := u32(chars.runes()[0])
		name = match r {
			0xF700 { 'up' }
			0xF701 { 'down' }
			0xF702 { 'left' }
			0xF703 { 'right' }
			0xF704 { 'f1' }
			0xF705 { 'f2' }
			0xF706 { 'f3' }
			0xF707 { 'f4' }
			0xF708 { 'f5' }
			0xF709 { 'f6' }
			0xF70A { 'f7' }
			0xF70B { 'f8' }
			0xF70C { 'f9' }
			0xF70D { 'f10' }
			0xF70E { 'f11' }
			0xF70F { 'f12' }
			0xF728 { 'forward_delete' }
			0xF729 { 'home' }
			0xF72B { 'end' }
			0xF72C { 'page_up' }
			0xF72D { 'page_down' }
			0x7F { 'backspace' }
			0x0D, 0x03 { 'enter' }
			0x1B { 'escape' }
			0x09 { 'tab' }
			0x20 { 'space' }
			else { chars.to_lower() }
		}
	}
	mut prefix := ''
	if mods & 0x100000 != 0 {
		prefix += 'cmd+'
	}
	if mods & 0x40000 != 0 {
		prefix += 'ctrl+'
	}
	if mods & 0x80000 != 0 {
		prefix += 'alt+'
	}
	if mods & 0x20000 != 0 {
		prefix += 'shift+'
	}
	return prefix + name
}
