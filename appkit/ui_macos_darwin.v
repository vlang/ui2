// vfmt off
// Keep native imports and declarations inside the backend switch. Hoisting
// them makes AppKit's MRC bridge conflict with gg/Sokol's ARC build.
module ui2

$if !ui2_custom_rendering ? {

import encoding.base64
import macos
import os
import time

#flag darwin -framework Cocoa

#flag darwin -framework QuartzCore

const ns_window_style_titled = u64(1)
const ns_window_style_closable = u64(2)
const ns_window_style_miniaturizable = u64(4)
const ns_window_style_resizable = u64(8)
const ns_backing_store_buffered = u64(2)
const ns_button_type_momentary_change = i64(5)
const ns_button_type_momentary_push_in = i64(7)
const ns_button_type_switch = i64(3)
const ns_button_type_push_on_push_off = i64(1)

type NativeView = voidptr

struct NativeRect {
	x      f64
	y      f64
	width  f64
	height f64
}

struct RunConfig {
	title  string = 'App'
	width  int = 400
	height int = 800
	min_width  int
	min_height int
}

struct RefreshDebug {
mut:
	active           bool
	nodes_visited    int
	nodes_created    int
	nodes_updated    int
	tooltips_set     int
	native_create_ns u64
	native_update_ns u64
	label_update_ns  u64
	view_update_ns   u64
	other_update_ns  u64
}

@[heap]
struct RuntimeState {
mut:
	build_screen        BuildFn = BuildFn(unsafe { nil })
	event_handler       EventFn = EventFn(unsafe { nil })
	key_handler         KeyFn = KeyFn(unsafe { nil })
	key_consumed        bool
	text_key_consumed   bool
	scroll_handler      ScrollFn = ScrollFn(unsafe { nil })
	drop_handler        DropFn = DropFn(unsafe { nil })
	window              NativeView
	root_view           NativeView
	button_handler      NativeView
	app_delegate        NativeView
	views               map[string]NativeView
	view_keys           map[string]string
	view_kinds          map[string]Kind
	text_area_direct    map[string]bool
	nodes               map[string]NativeView
	node_kinds          map[string]Kind
	node_text_direct    map[string]bool
	node_interactive    map[string]bool
	node_secure         map[string]bool
	node_declared_text  map[string]string
	node_content_sig    map[string]string
	node_tooltips       map[string]string
	node_menu_sig       map[string]string
	node_menu_items     map[string][]u64
	textview_ids        map[u64]string // NSTextView pointer -> lookup id (no tag on NSView)
	textview_action_ids map[u64]string // NSTextView pointer -> change event id
	scroll_ids          map[u64]string // NSClipView pointer -> Scroll element id
	pointer_ids         map[u64]string // NSView pointer -> element id
	pointer_draggable   map[u64]bool
	cursor_ids          map[u64]string // NSView pointer -> cursor name
	control_ids         map[u64]string // NSControl pointer -> action event id
	checkbox_controls   map[u64]bool // NSButton pointers whose state is persistent
	toggle_groups       map[u64]string
	toggle_allow_no_selection map[u64]bool
	toggle_ids          map[u64]string
	toggle_views        map[u64]NativeView
	slider_specs        map[u64]SliderSpec // NSSlider pointer -> range behavior
	control_change_ids  map[u64]string // NSTextField pointer -> change event id
	observed            map[u64]bool // clip views we already observe for scroll changes
	run_config          RunConfig
	screenshot_pending  bool
	screenshot_captured bool
	refresh_debug       RefreshDebug
}

const runtime_state_singleton = &RuntimeState{
	views: map[string]NativeView{}
	view_keys: map[string]string{}
	view_kinds: map[string]Kind{}
	text_area_direct: map[string]bool{}
	nodes: map[string]NativeView{}
	node_kinds: map[string]Kind{}
	node_text_direct: map[string]bool{}
	node_interactive: map[string]bool{}
	node_secure: map[string]bool{}
	node_declared_text: map[string]string{}
	node_content_sig: map[string]string{}
	node_tooltips: map[string]string{}
	node_menu_sig: map[string]string{}
	node_menu_items: map[string][]u64{}
	textview_ids: map[u64]string{}
	textview_action_ids: map[u64]string{}
	scroll_ids: map[u64]string{}
	pointer_ids: map[u64]string{}
	pointer_draggable: map[u64]bool{}
	cursor_ids: map[u64]string{}
	control_ids: map[u64]string{}
	checkbox_controls: map[u64]bool{}
	toggle_groups: map[u64]string{}
	toggle_allow_no_selection: map[u64]bool{}
	toggle_ids: map[u64]string{}
	toggle_views: map[u64]NativeView{}
	slider_specs: map[u64]SliderSpec{}
	control_change_ids: map[u64]string{}
	observed: map[u64]bool{}
}

fn state() &RuntimeState {
	return unsafe { runtime_state_singleton }
}

pub fn bounds() Rect {
	st := state()
	if native_is_nil(st.root_view) {
		return Rect{
			width: f64(st.run_config.width)
			height: f64(st.run_config.height)
		}
	}
	b := native_bounds(st.root_view)
	return Rect{
		x: b.x
		y: b.y
		width: b.width
		height: b.height
	}
}

pub fn run(build_fn BuildFn, event_fn EventFn) {
	run_window('App', 400, 800, build_fn, event_fn)
}

pub fn run_window(title string, width int, height int, build_fn BuildFn, event_fn EventFn) {
	run_window_with_min_size(title, width, height, 0, 0, build_fn, event_fn)
}

fn run_window_with_min_size(title string, width int, height int, min_width int, min_height int, build_fn BuildFn, event_fn EventFn) {
	mut st := state()
	st.build_screen = build_fn
	st.event_handler = event_fn
	configure_animation_driver(request_refresh, true)
	st.run_config = RunConfig{
		title: title
		width: width
		height: height
		min_width: min_width
		min_height: min_height
	}
	publish_menu_context(event_fn, title, unsafe { nil })
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

// refresh_element reconciles one existing keyed subtree without rebuilding the
// rest of the window. It is intended for high-frequency virtualized content
// such as a spreadsheet surface during native scrollbar tracking.
pub fn refresh_element(id string, element Element) {
	mut st := state()
	key := st.view_keys[id] or { return }
	native := st.nodes[key] or { return }
	parent := NativeView(macos.msg_id(native, 'superview'))
	if native_is_nil(parent) {
		return
	}
	animated := apply_widget_animations(element)
	validate_refresh_element_identity(key, animated) or {
		eprintln('ui2: ${err}')
		return
	}
	started := time.sys_mono_now()
	st.refresh_debug = RefreshDebug{
		active: true
	}
	clear_subtree_registrations(key)
	cleared := time.sys_mono_now()
	mut active := map[string]bool{}
	render_element(parent, animated, key, mut active)
	rendered := time.sys_mono_now()
	remove_stale_nodes_below(key, active)
	finished := time.sys_mono_now()
	st.refresh_debug.active = false
	schedule_screenshot_capture()
	total_ns := finished - started
	budget := if total_ns > u64(16_666_667) { 'OVER' } else { 'ok' }
	if os.getenv('UI2_DEBUG_REFRESH') == '1' {
		println('[ui2 subtree] id=${id} total=${debug_milliseconds(total_ns):.2f}ms ${budget} clear=${debug_milliseconds(cleared - started):.2f}ms render=${debug_milliseconds(rendered - cleared):.2f}ms stale=${debug_milliseconds(finished - rendered):.2f}ms nodes=${st.refresh_debug.nodes_visited} create=${st.refresh_debug.nodes_created}/${debug_milliseconds(st.refresh_debug.native_create_ns):.2f}ms update=${st.refresh_debug.nodes_updated}/${debug_milliseconds(st.refresh_debug.native_update_ns):.2f}ms labels=${debug_milliseconds(st.refresh_debug.label_update_ns):.2f}ms views=${debug_milliseconds(st.refresh_debug.view_update_ns):.2f}ms other=${debug_milliseconds(st.refresh_debug.other_update_ns):.2f}ms tooltips=${st.refresh_debug.tooltips_set}')
	}
}

fn validate_refresh_element_identity(root_key string, element Element) ! {
	validate_element_tree(element)!
	st := state()
	prefix := root_key + '/'
	mut ids := []string{}
	collect_element_ids(element, mut ids)
	for id in ids {
		existing_key := st.view_keys[id] or { continue }
		if existing_key != root_key && !existing_key.starts_with(prefix) {
			return error('duplicate element id `${id}` outside refreshed subtree')
		}
	}
}

fn collect_element_ids(element Element, mut ids []string) {
	if element.id.len > 0 {
		ids << element.id
	}
	for child in element.children {
		collect_element_ids(child, mut ids)
	}
}

fn debug_milliseconds(nanoseconds u64) f64 {
	return f64(nanoseconds) / 1_000_000.0
}

// on_key registers a handler for key events that reach the window, plus
// intercepted editing commands such as Tab. Keys arrive normalized:
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

// on_drop registers a handler for files or plain text dropped on the window.
pub fn on_drop(handler DropFn) {
	mut st := state()
	st.drop_handler = handler
}

// set_window_title updates the current AppKit window title.
pub fn set_window_title(title string) {
	st := state()
	if !native_is_nil(st.window) {
		macos.msg_void1(st.window, 'setTitle:', macos.nsstring(title))
	}
}

fn refresh_on_main() {
	refresh()
}

// request_refresh schedules a rebuild on the main thread; safe to call from
// background threads (sync loops, network fetches).
pub fn request_refresh() {
	cb := refresh_on_main
	native_dispatch_main(cb)
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

pub fn slider_value(id string) f64 {
	st := state()
	native := st.views[id] or { return 0 }
	if (st.view_kinds[id] or { Kind.view }) != .slider {
		return 0
	}
	spec := st.slider_specs[u64(voidptr(native))] or { return 0 }
	return native_snap_slider_value(native, spec)
}

pub fn set_slider_value(id string, value f64) {
	st := state()
	native := st.views[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) != .slider {
		return
	}
	spec := st.slider_specs[u64(voidptr(native))] or { return }
	macos.msg_void_f64(native, 'setDoubleValue:', slider_clamped_value(value, spec.min,
		spec.max))
}

pub fn switch_active(id string) bool {
	st := state()
	native := st.views[id] or { return false }
	if (st.view_kinds[id] or { Kind.view }) != .switch_control {
		return false
	}
	return macos.msg_i64(native, 'state') != 0
}

pub fn set_switch_active(id string, active bool) {
	st := state()
	native := st.views[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) != .switch_control {
		return
	}
	macos.msg_void_i64(native, 'setState:', if active { i64(1) } else { i64(0) })
}

pub fn toggle_button_pressed(id string) bool {
	st := state()
	native := st.views[id] or { return false }
	if (st.view_kinds[id] or { Kind.view }) != .toggle_button {
		return false
	}
	return macos.msg_i64(native, 'state') != 0
}

pub fn set_toggle_button_pressed(id string, pressed bool) {
	st := state()
	native := st.views[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) != .toggle_button {
		return
	}
	if pressed {
		release_macos_toggle_group(u64(voidptr(native)))
	}
	macos.msg_void_i64(native, 'setState:', if pressed { i64(1) } else { i64(0) })
}

pub fn toggle_button_group_members(id string) []string {
	st := state()
	native := st.views[id] or { return [] }
	pointer := u64(voidptr(native))
	group := st.toggle_groups[pointer] or { return [id] }
	if group.len == 0 {
		return [id]
	}
	mut members := []string{}
	for member_pointer, member_group in st.toggle_groups {
		if member_group == group {
			member_id := st.toggle_ids[member_pointer] or { continue }
			if member_id.len > 0 {
				members << member_id
			}
		}
	}
	return members
}

pub fn focus(id string) {
	st := state()
	native := st.views[id] or { return }
	if (st.view_kinds[id] or { Kind.view }) == .text_area {
		tv := text_area_text_view(native, st.text_area_direct[id] or { false })
		if !native_focus(tv) {
			return
		}
		return
	}
	if !native_focus(native) {
		return
	}
}

// focused_id returns the declarative id of the control that currently owns
// keyboard focus. NSTextField edits through a shared field editor, so compare
// that responder with each field's currentEditor as well as direct responders.
pub fn focused_id() string {
	st := state()
	if native_is_nil(st.window) {
		return ''
	}
	responder := macos.msg_id(st.window, 'firstResponder')
	if native_is_nil(NativeView(responder)) {
		return ''
	}
	if id := st.textview_ids[u64(voidptr(responder))] {
		return id
	}
	for id, native in st.views {
		if native == NativeView(responder) {
			return id
		}
		if (st.view_kinds[id] or { Kind.view }) == .text_field
			&& macos.msg_id(native, 'currentEditor') == responder {
			return id
		}
	}
	return ''
}

// focused_text_area_id returns the id of the text area that currently holds
// keyboard focus (is the window's first responder), or '' when no registered
// text view is focused. Clicking or selecting inside a text view emits no app
// event, so this lets callers target the editor the user is actually editing
// instead of tracking focus changes manually.
pub fn focused_text_area_id() string {
	st := state()
	if native_is_nil(st.window) {
		return ''
	}
	responder := macos.msg_id(st.window, 'firstResponder')
	if native_is_nil(NativeView(responder)) {
		return ''
	}
	return st.textview_ids[u64(voidptr(responder))] or { '' }
}

// text_area_set_selection selects a UTF-16 range, matching NSTextView's native
// selection storage and the offsets exposed by text_area_caret.
pub fn text_area_set_selection(id string, location int, length int) {
	tv := text_area_document_view(id) or { return }
	start := if location < 0 { u64(0) } else { u64(location) }
	selection_length := if length < 0 { u64(0) } else { u64(length) }
	native_text_view_set_selected_range(tv, start, selection_length)
}

// text_area_set_caret positions and collapses the selection at a UTF-16 offset.
pub fn text_area_set_caret(id string, pos int) {
	text_area_set_selection(id, pos, 0)
}

pub fn text_area_caret(id string) int {
	tv := text_area_document_view(id) or { return 0 }
	return int(native_text_view_selected_range(tv).location)
}

pub fn text_area_selection_length(id string) int {
	tv := text_area_document_view(id) or { return 0 }
	return int(native_text_view_selected_range(tv).length)
}

pub fn insert_text_area_text(id string, text string) {
	tv := text_area_document_view(id) or { return }
	native_text_view_insert_text(tv, text)
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
	return native_pasteboard_has_image()
}

pub fn save_clipboard_image_png(path string) bool {
	return native_pasteboard_write_image_png(path)
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
	native_dispatch_main(cb)
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
	if !native_view_save_png(st.root_view, path) {
		eprintln('ui2 screenshot failed: ${path}')
		return
	}
	st.screenshot_captured = true
	if screenshot_should_exit() {
		native_terminate_app()
	}
}

pub fn toggle_text_area_format(id string, format TextFormat) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	native_text_view_toggle_format(tv, int(format))
	return text_area_format_state(id)
}

pub fn set_text_area_font_family(id string, family string) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	native_text_view_set_font_family(tv, family)
	return text_area_format_state(id)
}

pub fn set_text_area_font_size(id string, size f64) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	native_text_view_set_font_size(tv, size)
	return text_area_format_state(id)
}

pub fn set_text_area_color(id string, color u32) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	native_text_view_set_color(tv, color)
	return text_area_format_state(id)
}

pub fn set_text_area_background_color(id string, color u32) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	native_text_view_set_background_color(tv, color)
	return text_area_format_state(id)
}

pub fn set_text_area_effect(id string, effect string) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	native_text_view_set_effect(tv, text_effect_value(effect))
	return text_area_format_state(id)
}

fn text_effect_value(effect string) int {
	return match effect {
		'shadow' { 1 }
		'outline' { 2 }
		else { 0 }
	}
}

pub fn toggle_text_area_superscript(id string) TextFormatState {
	return toggle_text_area_vertical_align(id, 'superscript')
}

pub fn toggle_text_area_subscript(id string) TextFormatState {
	return toggle_text_area_vertical_align(id, 'subscript')
}

pub fn toggle_text_area_vertical_align(id string, align string) TextFormatState {
	tv := text_area_document_view(id) or { return TextFormatState{} }
	native_text_view_toggle_vertical_align(tv, vertical_align_value(align))
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
	return native_text_view_runs(tv)
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
			text: run_text
			style: TextStyle{
				font_family: base64.decode_str(parts[1])
				size: parts[2].f64()
				bold: parts[3] == '1'
				italic: parts[4] == '1'
				underline: parts[5] == '1'
				vertical_align: text_run_vertical_align(if parts.len > 6 { parts[6] } else { '' })
				strikethrough: parts.len > 7 && parts[7] == '1'
				color: if parts.len > 8 { u32(parts[8].u64()) } else { u32(0x111111) }
				background_color: if parts.len > 9 { u32(parts[9].u64()) } else { u32(0) }
				shadow: parts.len > 10 && (parts[10].int() & 1) != 0
				outline: parts.len > 10 && (parts[10].int() & 2) != 0
				link: if parts.len > 11 { base64.decode_str(parts[11]) } else { '' }
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
	vertical := native_text_view_vertical_align_active(tv)
	effect := native_text_view_effect_active(tv)
	return TextFormatState{
		bold: native_text_view_format_active(tv, int(TextFormat.bold))
		italic: native_text_view_format_active(tv, int(TextFormat.italic))
		underline: native_text_view_format_active(tv, int(TextFormat.underline))
		strikethrough: native_text_view_format_active(tv, int(TextFormat.strikethrough))
		shadow: (effect & 1) != 0
		outline: (effect & 2) != 0
		subscript: vertical < 0
		superscript: vertical > 0
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
		macos.add_method(cls, 'isFlipped', voidptr(ui2_view_is_flipped), 'B@:')
		macos.add_method(cls, 'draggingEntered:', voidptr(ui2_dragging_entered), 'Q@:@')
		macos.add_method(cls, 'performDragOperation:', voidptr(ui2_perform_drag_operation), 'B@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2PointerView') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSView'), 'UI2PointerView')
		macos.add_method(cls, 'isFlipped', voidptr(ui2_view_is_flipped), 'B@:')
		macos.add_method(cls, 'mouseDown:', voidptr(ui2_pointer_mouse_down), 'v@:@')
		macos.add_method(cls, 'mouseDragged:', voidptr(ui2_pointer_mouse_dragged), 'v@:@')
		macos.add_method(cls, 'mouseUp:', voidptr(ui2_pointer_mouse_up), 'v@:@')
		macos.add_method(cls, 'resetCursorRects', voidptr(ui2_pointer_reset_cursor_rects), 'v@:')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2PointerImageView') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSImageView'), 'UI2PointerImageView')
		macos.add_method(cls, 'mouseDown:', voidptr(ui2_pointer_mouse_down), 'v@:@')
		macos.add_method(cls, 'mouseDragged:', voidptr(ui2_pointer_mouse_dragged), 'v@:@')
		macos.add_method(cls, 'mouseUp:', voidptr(ui2_pointer_mouse_up), 'v@:@')
		macos.add_method(cls, 'resetCursorRects', voidptr(ui2_pointer_reset_cursor_rects), 'v@:')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2AppDelegate') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2AppDelegate')
		macos.add_method(cls, 'applicationDidFinishLaunching:', voidptr(ui2_app_did_finish_launching), 'v@:@')
		macos.add_method(cls, 'applicationShouldTerminateAfterLastWindowClosed:', voidptr(ui2_app_should_terminate_after_last_window_closed), 'B@:@')
		macos.add_method(cls, 'windowDidResize:', voidptr(ui2_window_did_resize), 'v@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2ButtonHandler') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2ButtonHandler')
		macos.add_method(cls, 'handleTap:', voidptr(ui2_button_tap), 'v@:@')
		macos.add_method(cls, 'controlTextDidChange:', voidptr(ui2_control_text_changed), 'v@:@')
		macos.add_method(cls, 'control:textView:doCommandBySelector:', voidptr(ui2_control_do_command), 'B@:@@:')
		macos.add_method(cls, 'textDidChange:', voidptr(ui2_text_view_changed), 'v@:@')
		macos.add_method(cls, 'textView:doCommandBySelector:', voidptr(ui2_text_view_do_command), 'B@:@:')
		macos.add_method(cls, 'textView:clickedOnLink:atIndex:', voidptr(ui2_text_view_clicked_on_link), 'B@:@@Q')
		macos.add_method(cls, 'ui2BoundsChanged:', voidptr(ui2_bounds_changed), 'v@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2Window') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSWindow'), 'UI2Window')
		macos.add_method(cls, 'keyDown:', voidptr(ui2_window_key_down), 'v@:@')
		macos.add_method(cls, 'performKeyEquivalent:', voidptr(ui2_window_perform_key_equiv), 'B@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2MainDispatcher') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2MainDispatcher')
		macos.add_method(cls, 'runCallback:', voidptr(ui2_dispatch_callback), 'v@:@')
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

fn render_root(declared Element) {
	root := apply_widget_animations(declared)
	validate_element_tree(root) or {
		eprintln('ui2: ${err}')
		return
	}
	mut st := state()
	st.views = map[string]NativeView{}
	st.view_keys = map[string]string{}
	st.view_kinds = map[string]Kind{}
	st.text_area_direct = map[string]bool{}
	st.pointer_ids = map[u64]string{}
	st.pointer_draggable = map[u64]bool{}
	st.cursor_ids = map[u64]string{}
	st.control_ids = map[u64]string{}
	st.checkbox_controls = map[u64]bool{}
	st.toggle_groups = map[u64]string{}
	st.toggle_allow_no_selection = map[u64]bool{}
	st.toggle_ids = map[u64]string{}
	st.toggle_views = map[u64]NativeView{}
	st.slider_specs = map[u64]SliderSpec{}
	st.control_change_ids = map[u64]string{}
	st.textview_ids = map[u64]string{}
	st.textview_action_ids = map[u64]string{}
	st.scroll_ids = map[u64]string{}
	native_set_box_background(st.root_view, root.box)
	mut active := map[string]bool{}
	render_children(st.root_view, root.children, '', mut active)
	remove_stale_nodes(active)
}

fn render_children(parent NativeView, children []Element, parent_key string, mut active map[string]bool) {
	mut previous := native_nil_view()
	for i, child in children {
		key := reconciliation_child_key(parent_key, i, child)
		native := render_element(parent, child, key, mut active)
		if child.kind == .screen {
			continue
		}
		native_place_subview(parent, native, previous)
		previous = native
	}
}

fn render_element(parent NativeView, el Element, key string, mut active map[string]bool) NativeView {
	active[key] = true
	mut st := state()
	if st.refresh_debug.active {
		st.refresh_debug.nodes_visited++
	}
	mut native := st.nodes[key] or { native_nil_view() }
	existing_kind := st.node_kinds[key] or { Kind.screen }
	existing_direct := st.node_text_direct[key] or { false }
	existing_interactive := st.node_interactive[key] or { false }
	existing_secure := st.node_secure[key] or { false }
	interactive := element_interactive(el)
	text_area_mode_changed := el.kind == .text_area && existing_kind == .text_area
		&& existing_direct != el.disable_scroll
	interactive_changed := (el.kind == .view || el.kind == .image) && existing_kind == el.kind
		&& existing_interactive != interactive
	secure_changed := el.kind == .text_field && existing_kind == .text_field
		&& existing_secure != el.secure
	declared_text_changed := key !in st.node_declared_text || (st.node_declared_text[key] or { '' }) != el.text
	content_sig := text_area_content_signature(el)
	content_changed := key !in st.node_content_sig || (st.node_content_sig[key] or { '' }) != content_sig
	if native_is_nil(native) || existing_kind != el.kind || text_area_mode_changed
		|| interactive_changed || secure_changed {
		old_native := native
		mut create_el := el
		mut restore_editing := false
		mut restore_location := u64(0)
		mut restore_length := u64(0)
		if !native_is_nil(old_native) && existing_kind == .text_field && el.kind == .text_field {
			current := native_text(old_native)
			if !declared_text_changed {
				create_el = Element{
					...el
					text: current
				}
			}
			restore_editing = native_control_is_editing(old_native)
			selected := native_control_selected_range(old_native)
			restore_location = selected.location
			restore_length = selected.length
		} else if !native_is_nil(old_native) && existing_kind == .text_area
			&& el.kind == .text_area {
			old_tv := text_area_text_view(old_native, existing_direct)
			if !declared_text_changed {
				create_el = Element{
					...el
					text: macos.utf8_string(macos.msg_id(old_tv, 'string'))
				}
			}
			restore_editing = native_is_first_responder(old_tv)
			selected := native_text_view_selected_range(old_tv)
			restore_location = selected.location
			restore_length = selected.length
		}
		if !native_is_nil(old_native) {
			unregister_node(key, old_native, existing_kind, existing_direct)
			if !interactive_changed && existing_kind in [.view, .scroll] {
				forget_descendant_nodes(key)
			}
		}
		st.node_tooltips.delete(key)
		create_started := if st.refresh_debug.active { time.sys_mono_now() } else { u64(0) }
		native = native_create_element(create_el)
		if st.refresh_debug.active {
			st.refresh_debug.nodes_created++
			st.refresh_debug.native_create_ns += time.sys_mono_now() - create_started
		}
		st.nodes[key] = native
		st.node_kinds[key] = el.kind
		st.node_interactive[key] = interactive
		st.node_secure[key] = el.secure
		if el.kind == .text_area {
			st.node_text_direct[key] = el.disable_scroll
		} else {
			st.node_text_direct.delete(key)
		}
		if el.kind != .screen {
			native_add_subview(parent, native)
			if interactive_changed && !native_is_nil(old_native) {
				reparent_direct_children(key, native)
			}
			macos.release(native)
		}
		if !native_is_nil(old_native) {
			native_remove_from_superview(old_native)
		}
		if restore_editing {
			if el.kind == .text_field {
				native_restore_control_selection(native, restore_location, restore_length)
			} else if el.kind == .text_area {
				tv := text_area_text_view(native, el.disable_scroll)
				if native_focus(tv) {
					native_text_view_set_selected_range(tv, restore_location, restore_length)
				}
			}
		}
	} else {
		update_started := if st.refresh_debug.active { time.sys_mono_now() } else { u64(0) }
		native_update_element(native, el, declared_text_changed, content_changed)
		if st.refresh_debug.active {
			elapsed := time.sys_mono_now() - update_started
			st.refresh_debug.nodes_updated++
			st.refresh_debug.native_update_ns += elapsed
			match el.kind {
				.label {
					st.refresh_debug.label_update_ns += elapsed
				}
				.view {
					st.refresh_debug.view_update_ns += elapsed
				}
				else {
					st.refresh_debug.other_update_ns += elapsed
				}
			}
		}
	}
	if el.kind != .screen {
		border_box := if el.kind == .toggle_button && el.checked {
			el.toggle_down_box
		} else {
			el.box
		}
		native_set_box_borders(native, border_box)
	}

	match el.kind {
		.screen {
			native = parent
			render_children(parent, el.children, key, mut active)
		}
		.view {
			register_pointer(native, el)
			render_children(native, el.children, key, mut active)
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
				native_observe_bounds(st.button_handler, clip)
			}
			doc_key := key + '/document'
			active[doc_key] = true
			doc_h := content_height(el.children) + 16
			mut doc := st.nodes[doc_key] or { native_nil_view() }
			if native_is_nil(doc) {
				doc = native_new_flipped_view(native_rect(0, 0, el.frame.width, doc_h), el.box)
				st.nodes[doc_key] = doc
				st.node_kinds[doc_key] = .view
				native_set_document_view(native, doc)
				macos.release(doc)
			} else {
				native_set_frame(doc, native_rect(0, 0, el.frame.width, doc_h))
				native_set_box_background(doc, el.box)
			}
			render_children(doc, el.children, doc_key, mut active)
		}
		.button {
			register_button(native, element_action_id(el))
		}
		.checkbox {
			register_checkbox(native, element_action_id(el))
		}
		.switch_control {
			register_checkbox(native, element_action_id(el))
		}
		.toggle_button {
			register_toggle_button(native, el)
		}
		.dropdown {
			register_action_control(native, element_action_id(el))
		}
		.slider {
			register_slider(native, el)
		}
		.text_field {
			register_control(native, element_action_id(el), el.submit_id, el.emit_change)
		}
		.text_area {
			tv := text_area_text_view(native, el.disable_scroll)
			if el.id.len > 0 {
				st.textview_ids[u64(voidptr(tv))] = el.id
				st.text_area_direct[el.id] = el.disable_scroll
			}
			if element_action_id(el).len > 0 {
				st.textview_action_ids[u64(voidptr(tv))] = element_action_id(el)
			}
		}
		.label {
			// Labels are updated by native_update_element.
		}
		.image {
			register_pointer(native, el)
		}
	}

	if el.kind != .dropdown && el.enabled {
		reconcile_menu(key, native, el.menu)
	} else if el.kind != .dropdown {
		clear_menu(key, native)
	}
	if el.kind != .screen {
		previous_tooltip := st.node_tooltips[key] or { '' }
		if previous_tooltip != el.tooltip {
			macos.msg_void1(native, 'setToolTip:', macos.nsstring(el.tooltip))
			if st.refresh_debug.active {
				st.refresh_debug.tooltips_set++
			}
		}
		if el.tooltip.len > 0 {
			st.node_tooltips[key] = el.tooltip
		} else {
			// Do not cache the default empty value. Apart from avoiding a map entry
			// per node, this keeps newly-created views from installing thousands of
			// empty AppKit tooltip tracking areas during virtual-list refreshes.
			st.node_tooltips.delete(key)
		}
	}

	if el.id.len > 0 {
		st.views[el.id] = native
		st.view_keys[el.id] = key
		st.view_kinds[el.id] = el.kind
	}
	st.node_declared_text[key] = el.text
	st.node_content_sig[key] = content_sig
	apply_common_native_state(native, el)
	return native
}

fn menu_signature(entries []MenuEntry) string {
	mut signature := ''
	for entry in entries {
		signature += '${entry.id.len}:${entry.id}${entry.title.len}:${entry.title};'
	}
	return signature
}

fn clear_menu(key string, native NativeView) {
	mut st := state()
	for pointer in st.node_menu_items[key] or { []u64{} } {
		st.control_ids.delete(pointer)
	}
	st.node_menu_items.delete(key)
	st.node_menu_sig.delete(key)
	macos.msg_void1(native, 'setMenu:', native_nil_view())
}

fn reconcile_menu(key string, native NativeView, entries []MenuEntry) {
	signature := menu_signature(entries)
	mut st := state()
	if (st.node_menu_sig[key] or { '' }) == signature {
		pointers := st.node_menu_items[key] or { []u64{} }
		for index, pointer in pointers {
			if index < entries.len {
				st.control_ids[pointer] = entries[index].id
			}
		}
		return
	}
	clear_menu(key, native)
	if entries.len == 0 {
		return
	}
	attach_menu(key, native, entries, signature)
}

// attach_menu uses sender-pointer bindings, so a retained old item can never
// dispatch through a refresh-local positional tag.
fn attach_menu(key string, native NativeView, entries []MenuEntry, signature string) {
	mut st := state()
	menu := macos.msg_id(macos.alloc('NSMenu'), 'init')
	mut pointers := []u64{cap: entries.len}
	for e in entries {
		item := macos.msg_id3(macos.alloc('NSMenuItem'), 'initWithTitle:action:keyEquivalent:', macos.nsstring(e.title), macos.Id(voidptr(macos.sel('handleTap:'))), macos.nsstring(''))
		macos.msg_void1(item, 'setTarget:', st.button_handler)
		pointer := u64(voidptr(item))
		st.control_ids[pointer] = e.id
		pointers << pointer
		macos.msg_void1(menu, 'addItem:', item)
		macos.release(item)
	}
	macos.msg_void1(native, 'setMenu:', menu)
	macos.release(menu)
	st.node_menu_items[key] = pointers
	st.node_menu_sig[key] = signature
}

fn native_create_element(el Element) NativeView {
	return match el.kind {
		.screen {
			native_nil_view()
		}
		.view {
			native_new_view(element_rect(el.frame), el.box, element_interactive(el))
		}
		.scroll {
			native_new_scroll(element_rect(el.frame), el.box, el.persistent_scrollbars)
		}
		.label {
			native_new_label(element_rect(el.frame), el.text, el.text_style.color, el.text_style.size, el.text_style.bold, el.text_style.italic, el.text_style.underline, align_value(el.text_style.align), el.text_style.lines)
		}
		.image {
			native_new_image(element_rect(el.frame), el.image_path, el.rotation)
		}
		.button {
			native_new_button(element_rect(el.frame), el.text, el.box, el.text_style.color, el.text_style.size, el.text_style.bold, el.text_style.italic, el.text_style.underline, el.text_style.lines, el.image_path, el.native_style)
		}
		.checkbox {
			native_new_checkbox(el)
		}
		.switch_control {
			native_new_switch_control(el)
		}
		.toggle_button {
			native_new_toggle_button(el)
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
		.slider {
			native_new_slider(el)
		}
	}
}

fn native_update_element(native NativeView, el Element, declared_text_changed bool, content_changed bool) {
	match el.kind {
		.screen {}
		.view {
			native_set_frame(native, element_rect(el.frame))
			native_set_box_background(native, el.box)
			native_set_corner_radius(native, el.box.radius)
		}
		.scroll {
			native_set_frame(native, element_rect(el.frame))
			native_set_scroll_background(native, el.box)
			native_set_scrollbar_mode(native, el.persistent_scrollbars)
		}
		.label {
			native_update_label(native, element_rect(el.frame), el.text, el.text_style.color, el.text_style.size, el.text_style.bold, el.text_style.italic, el.text_style.underline, align_value(el.text_style.align), el.text_style.lines)
		}
		.image {
			native_update_image(native, element_rect(el.frame), el.image_path, el.rotation)
		}
		.button {
			native_update_button(native, element_rect(el.frame), el.text, el.box, el.text_style.color, el.text_style.size, el.text_style.bold, el.text_style.italic, el.text_style.underline, el.text_style.lines, el.image_path, el.native_style)
		}
		.checkbox {
			native_update_checkbox(native, el)
		}
		.switch_control {
			native_update_switch_control(native, el)
		}
		.toggle_button {
			native_update_toggle_button(native, el)
		}
		.dropdown {
			native_update_dropdown(native, el)
		}
		.text_field {
			native_update_text_field(native, element_rect(el.frame), el.placeholder, el.text,
				el.box, el.text_style.color, el.text_style.size,
				declared_text_changed, el.readonly, el.enabled)
		}
		.text_area {
			native_update_text_area(native, el, declared_text_changed, content_changed)
		}
		.slider {
			native_update_slider(native, el)
		}
	}
}

fn element_interactive(el Element) bool {
	return el.clickable || el.draggable || el.cursor.len > 0
}

fn register_pointer(native NativeView, el Element) {
	mut st := state()
	key := u64(voidptr(native))
	st.pointer_ids.delete(key)
	st.pointer_draggable.delete(key)
	st.cursor_ids.delete(key)
	if el.enabled && element_action_id(el).len > 0 && (el.clickable || el.draggable) {
		st.pointer_ids[key] = element_action_id(el)
		st.pointer_draggable[key] = el.draggable
	}
	if el.cursor.len > 0 {
		st.cursor_ids[key] = el.cursor
	}
	if element_interactive(el) {
		native_invalidate_cursor_rects(native)
	}
}

fn register_button(native NativeView, id string) {
	mut st := state()
	pointer := u64(voidptr(native))
	st.control_ids[pointer] = id
	st.checkbox_controls.delete(pointer)
	native_set_button_target(native, st.button_handler)
	native_set_associated_object(native, assoc_handler_key(), st.button_handler)
}

fn register_checkbox(native NativeView, id string) {
	mut st := state()
	pointer := u64(voidptr(native))
	st.control_ids[pointer] = id
	st.checkbox_controls[pointer] = true
	native_set_button_target(native, st.button_handler)
	native_set_associated_object(native, assoc_handler_key(), st.button_handler)
}

fn register_toggle_button(native NativeView, el Element) {
	register_checkbox(native, element_action_id(el))
	mut st := state()
	pointer := u64(voidptr(native))
	st.toggle_groups[pointer] = el.toggle_group
	st.toggle_allow_no_selection[pointer] = el.toggle_allow_no_selection
	st.toggle_ids[pointer] = el.id
	st.toggle_views[pointer] = native
	if macos.msg_i64(native, 'state') != 0 {
		release_macos_toggle_group(pointer)
	}
}

fn release_macos_toggle_group(pointer u64) {
	st := state()
	group := st.toggle_groups[pointer] or { return }
	if group.len == 0 {
		return
	}
	for member_pointer, member_group in st.toggle_groups {
		if member_pointer == pointer || member_group != group {
			continue
		}
		native := st.toggle_views[member_pointer] or { continue }
		macos.msg_void_i64(native, 'setState:', i64(0))
	}
}

fn commit_macos_toggle_button(pointer u64, native NativeView) {
	st := state()
	group := st.toggle_groups[pointer] or { return }
	if group.len == 0 {
		return
	}
	if macos.msg_i64(native, 'state') != 0 {
		release_macos_toggle_group(pointer)
	} else if !(st.toggle_allow_no_selection[pointer] or { true }) {
		macos.msg_void_i64(native, 'setState:', i64(1))
	}
}

fn register_action_control(native NativeView, id string) {
	mut st := state()
	pointer := u64(voidptr(native))
	st.control_ids[pointer] = id
	native_set_control_target(native, st.button_handler)
	native_set_associated_object(native, assoc_handler_key(), st.button_handler)
}

fn register_slider(native NativeView, el Element) {
	mut st := state()
	pointer := u64(voidptr(native))
	st.slider_specs[pointer] = slider_spec(el)
	register_action_control(native, element_action_id(el))
}

fn register_control(native NativeView, id string, submit_id string, emit_change bool) {
	mut st := state()
	pointer := u64(voidptr(native))
	st.control_ids.delete(pointer)
	st.control_change_ids.delete(pointer)
	native_set_associated_object(native, assoc_handler_key(), native_nil_view())
	if submit_id.len > 0 {
		st.control_ids[pointer] = submit_id
	}
	if emit_change {
		st.control_change_ids[pointer] = id
	}
	if submit_id.len > 0 {
		native_set_control_target(native, st.button_handler)
	} else {
		native_clear_control_target(native)
	}
	if emit_change {
		// Delegate delivers controlTextDidChange: for per-keystroke events.
		macos.msg_void1(native, 'setDelegate:', st.button_handler)
	} else {
		macos.msg_void1(native, 'setDelegate:', native_nil_view())
	}
	if emit_change || submit_id.len > 0 {
		native_set_associated_object(native, assoc_handler_key(), st.button_handler)
	} else {
		native_set_associated_object(native, assoc_handler_key(), native_nil_view())
	}
}

fn unregister_node(key string, native NativeView, kind Kind, text_direct bool) {
	mut st := state()
	pointer := u64(voidptr(native))
	st.pointer_ids.delete(pointer)
	st.pointer_draggable.delete(pointer)
	st.cursor_ids.delete(pointer)
	st.control_ids.delete(pointer)
	st.checkbox_controls.delete(pointer)
	st.toggle_groups.delete(pointer)
	st.toggle_allow_no_selection.delete(pointer)
	st.toggle_ids.delete(pointer)
	st.toggle_views.delete(pointer)
	st.slider_specs.delete(pointer)
	st.control_change_ids.delete(pointer)
	if kind == .text_field {
		native_clear_control_target(native)
		macos.msg_void1(native, 'setDelegate:', native_nil_view())
	}
	if kind == .text_area {
		tv := text_area_text_view(native, text_direct)
		if !native_is_nil(tv) {
			st.textview_ids.delete(u64(voidptr(tv)))
			st.textview_action_ids.delete(u64(voidptr(tv)))
			macos.msg_void1(tv, 'setDelegate:', native_nil_view())
		}
	}
	if kind == .scroll {
		clip := macos.msg_id(native, 'contentView')
		clip_pointer := u64(voidptr(clip))
		st.scroll_ids.delete(clip_pointer)
		if clip_pointer in st.observed {
			native_unobserve_bounds(st.button_handler, clip)
			st.observed.delete(clip_pointer)
		}
	}
	clear_menu(key, native)
}

fn reparent_direct_children(key string, new_parent NativeView) {
	st := state()
	prefix := key + '/'
	for child_key_, child in st.nodes {
		if !child_key_.starts_with(prefix) {
			continue
		}
		remainder := child_key_[prefix.len..]
		if !remainder.contains('/') {
			native_add_subview(new_parent, child)
		}
	}
}

fn forget_descendant_nodes(key string) {
	mut st := state()
	prefix := key + '/'
	mut descendants := []string{}
	for child_key_, _ in st.nodes {
		if child_key_.starts_with(prefix) {
			descendants << child_key_
		}
	}
	for child_key_ in descendants {
		child := st.nodes[child_key_] or { continue }
		unregister_node(child_key_, child, st.node_kinds[child_key_] or { Kind.view }, st.node_text_direct[child_key_] or { false })
		st.nodes.delete(child_key_)
		st.node_kinds.delete(child_key_)
		st.node_text_direct.delete(child_key_)
		st.node_interactive.delete(child_key_)
		st.node_secure.delete(child_key_)
		st.node_declared_text.delete(child_key_)
		st.node_content_sig.delete(child_key_)
		st.node_tooltips.delete(child_key_)
	}
}

fn native_is_first_responder(view NativeView) bool {
	st := state()
	if native_is_nil(st.window) || native_is_nil(view) {
		return false
	}
	return macos.msg_id(st.window, 'firstResponder') == view
}

fn text_area_content_signature(el Element) string {
	if el.kind != .text_area {
		return ''
	}
	return '${el.text_style}|${el.text_runs}'
}

fn apply_common_native_state(native NativeView, el Element) {
	if native_is_nil(native) || el.kind == .screen {
		return
	}
	native_apply_common_view_state(native, el.hidden, el.enabled, el.accessibility_role, el.accessibility_label, el.accessibility_value)
}

fn remove_stale_nodes(active map[string]bool) {
	mut st := state()
	mut stale := []string{}
	mut stale_set := map[string]bool{}
	for key, _ in st.nodes {
		if key !in active {
			stale << key
			stale_set[key] = true
		}
	}
	for key in stale {
		native := st.nodes[key] or { continue }
		kind := st.node_kinds[key] or { Kind.view }
		direct := st.node_text_direct[key] or { false }
		unregister_node(key, native, kind, direct)
	}
	for key in stale {
		native := st.nodes[key] or { continue }
		if !node_has_ancestor_in_set(key, stale_set) {
			// Removing a native parent already removes its whole subtree. Avoid
			// making the same AppKit call again for every stale descendant.
			native_remove_from_superview(native)
		}
	}
	for key in stale {
		st.nodes.delete(key)
		st.node_kinds.delete(key)
		st.node_text_direct.delete(key)
		st.node_interactive.delete(key)
		st.node_secure.delete(key)
		st.node_declared_text.delete(key)
		st.node_content_sig.delete(key)
		st.node_tooltips.delete(key)
	}
}

fn clear_subtree_registrations(root_key string) {
	mut st := state()
	prefix := root_key + '/'
	for key, native in st.nodes {
		if key == root_key || key.starts_with(prefix) {
			unregister_node(key, native, st.node_kinds[key] or { Kind.view }, st.node_text_direct[key] or { false })
		}
	}
	mut ids := []string{}
	for id, key in st.view_keys {
		if key == root_key || key.starts_with(prefix) {
			ids << id
		}
	}
	for id in ids {
		st.views.delete(id)
		st.view_keys.delete(id)
		st.view_kinds.delete(id)
		st.text_area_direct.delete(id)
	}
}

fn remove_stale_nodes_below(root_key string, active map[string]bool) {
	mut st := state()
	prefix := root_key + '/'
	mut stale := []string{}
	mut stale_set := map[string]bool{}
	for key, _ in st.nodes {
		if key.starts_with(prefix) && key !in active {
			stale << key
			stale_set[key] = true
		}
	}
	for key in stale {
		native := st.nodes[key] or { continue }
		kind := st.node_kinds[key] or { Kind.view }
		direct := st.node_text_direct[key] or { false }
		unregister_node(key, native, kind, direct)
	}
	for key in stale {
		native := st.nodes[key] or { continue }
		if !node_has_ancestor_in_set(key, stale_set) {
			native_remove_from_superview(native)
		}
	}
	for key in stale {
		st.nodes.delete(key)
		st.node_kinds.delete(key)
		st.node_text_direct.delete(key)
		st.node_interactive.delete(key)
		st.node_secure.delete(key)
		st.node_declared_text.delete(key)
		st.node_content_sig.delete(key)
		st.node_tooltips.delete(key)
	}
}

fn node_has_ancestor_in_set(key string, keys map[string]bool) bool {
	mut ancestor := key
	for {
		separator := ancestor.last_index('/') or { return false }
		ancestor = ancestor[..separator]
		if ancestor in keys {
			return true
		}
	}
	return false
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

fn native_border_key(side string) voidptr {
	return voidptr(macos.sel('ui2_border_${side}_assoc'))
}

fn native_rect(x f64, y f64, width f64, height f64) NativeRect {
	return NativeRect{
		x: x
		y: y
		width: width
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
	return native_color_from_hex(hex)
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
	window := macos.msg_id_rect_u64_u64_bool(macos.alloc('UI2Window'), 'initWithContentRect:styleMask:backing:defer:', appkit_rect(frame), style, ns_backing_store_buffered, false)
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

fn native_set_content_min_size(window NativeView, width f64, height f64) {
	macos.msg_void_point(window, 'setContentMinSize:', macos.point(width, height))
}

fn native_bounds(view NativeView) NativeRect {
	b := macos.msg_rect(view, 'bounds')
	return native_rect(b.x, b.y, b.width, b.height)
}

fn native_add_subview(parent NativeView, child NativeView) {
	macos.msg_void1(parent, 'addSubview:', child)
}

fn native_place_subview(parent NativeView, child NativeView, previous NativeView) {
	if native_is_nil(parent) || native_is_nil(child) {
		return
	}
	objc_place_subview(parent, child, previous)
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
	objc_invalidate_cursor_rects(view)
}

fn native_new_object(class_name string) NativeView {
	return macos.msg_id(macos.alloc(class_name), 'init')
}

fn native_set_associated_object(obj NativeView, key voidptr, value NativeView) {
	macos.set_associated_object(obj, key, value, macos.assoc_retain_nonatomic)
}

fn native_new_flipped_view(frame NativeRect, box BoxStyle) NativeView {
	native := macos.msg_id_rect(macos.alloc('UI2FlippedView'), 'initWithFrame:', appkit_rect(frame))
	native_set_box_background(native, box)
	return native
}

fn native_new_view(frame NativeRect, box BoxStyle, interactive bool) NativeView {
	class_name := if interactive { 'UI2PointerView' } else { 'UI2FlippedView' }
	native := macos.msg_id_rect(macos.alloc(class_name), 'initWithFrame:', appkit_rect(frame))
	native_set_box_background(native, box)
	native_set_corner_radius(native, box.radius)
	return native
}

fn native_new_scroll(frame NativeRect, box BoxStyle, persistent_scrollbars bool) NativeView {
	scroll_view := macos.msg_id_rect(macos.alloc('NSScrollView'), 'initWithFrame:', appkit_rect(frame))
	macos.msg_void_bool(scroll_view, 'setHasVerticalScroller:', true)
	native_set_scrollbar_mode(scroll_view, persistent_scrollbars)
	native_set_scroll_background(scroll_view, box)
	return scroll_view
}

fn native_set_scrollbar_mode(scroll NativeView, persistent bool) {
	// NSScrollerStyleLegacy is 0 and overlay is 1.
	macos.msg_void_i64(scroll, 'setScrollerStyle:', if persistent { i64(0) } else { i64(1) })
	macos.msg_void_bool(scroll, 'setAutohidesScrollers:', !persistent)
}

fn native_set_document_view(scroll NativeView, view NativeView) {
	macos.msg_void1(scroll, 'setDocumentView:', view)
}

fn native_set_scroll_background(scroll NativeView, box BoxStyle) {
	draws_background := box_draws_fill(box)
	macos.msg_void_bool(scroll, 'setDrawsBackground:', draws_background)
	if draws_background {
		macos.msg_void1(scroll, 'setBackgroundColor:', native_color(box.bg))
	}
}

fn native_new_image(frame NativeRect, path string, rotation f64) NativeView {
	image_view := macos.msg_id_rect(macos.alloc('UI2PointerImageView'), 'initWithFrame:', appkit_rect(frame))
	native_update_image(image_view, frame, path, rotation)
	return image_view
}

fn native_update_image(image_view NativeView, frame NativeRect, path string, rotation f64) {
	rotated := rotation < -0.001 || rotation > 0.001
	native_view_reset_transform(image_view)
	native_set_frame(image_view, frame)
	macos.msg_void_i64(image_view, 'setImageScaling:', 3)
	if rotated {
		native_view_set_rotation(image_view, rotation)
	} else {
		native_view_clear_rotation(image_view)
	}
	if path.trim_space() == '' {
		macos.msg_void1(image_view, 'setImage:', macos.Id(unsafe { nil }))
		return
	}
	img := macos.msg_id1(macos.alloc('NSImage'), 'initWithContentsOfFile:', macos.nsstring(path))
	macos.msg_void1(image_view, 'setImage:', img)
	if !native_is_nil(img) {
		macos.release(img)
	}
}

fn native_new_label(frame NativeRect, text string, text_hex u32, size f64, bold bool, italic bool, underline bool, align int, lines int) NativeView {
	label_view := macos.msg_id_rect(macos.alloc('NSTextField'), 'initWithFrame:', appkit_rect(frame))
	native_update_label(label_view, frame, text, text_hex, size, bold, italic, underline, align, lines)
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
		native_control_set_attributed_title(label_view, text, text_hex, size, bold, italic, underline)
	}
	macos.msg_void_i64(label_view, 'setAlignment:', i64(align))
	cell := macos.msg_id(label_view, 'cell')
	macos.msg_void_i64(cell, 'setLineBreakMode:', 4)
	macos.msg_void_bool(cell, 'setUsesSingleLineMode:', lines == 1)
}

fn native_new_button(frame NativeRect, title string, box BoxStyle, text_hex u32, size f64, bold bool, italic bool, underline bool, lines int, image_name string, native_style bool) NativeView {
	button_view := macos.msg_id_rect(macos.alloc('NSButton'), 'initWithFrame:', appkit_rect(frame))
	native_update_button(button_view, frame, title, box, text_hex, size, bold, italic, underline,
		lines, image_name, native_style)
	return button_view
}

fn native_update_button(button_view NativeView, frame NativeRect, title string, box BoxStyle, text_hex u32, size f64, bold bool, italic bool, underline bool, lines int, image_name string, native_style bool) {
	native_set_frame(button_view, frame)
	macos.msg_void1(button_view, 'setTitle:', macos.nsstring(title))
	macos.msg_void_u64(button_view, 'setBezelStyle:', 1)
	if native_style && box_draws_fill(box) {
		macos.msg_void_i64(button_view, 'setButtonType:', ns_button_type_momentary_push_in)
		macos.msg_void_bool(button_view, 'setBordered:', true)
		macos.msg_void_bool(button_view, 'setWantsLayer:', false)
	} else {
		macos.msg_void_i64(button_view, 'setButtonType:', ns_button_type_momentary_change)
		macos.msg_void_bool(button_view, 'setBordered:', false)
		macos.msg_void1(button_view, 'setFont:', native_font(size, bold, italic))
		native_control_set_attributed_title(button_view, title, text_hex, size, bold, italic, underline)
		native_set_box_background(button_view, box)
		native_set_corner_radius(button_view, box.radius)
	}
	cell := macos.msg_id(button_view, 'cell')
	macos.msg_void_i64(cell, 'setLineBreakMode:', 4)
	macos.msg_void_bool(cell, 'setUsesSingleLineMode:', lines == 1)
	native_update_button_image(button_view, frame, image_name)
	native_clear_control_state(button_view)
}

fn native_new_checkbox(el Element) NativeView {
	checkbox_view := macos.msg_id_rect(macos.alloc('NSButton'), 'initWithFrame:', appkit_rect(element_rect(el.frame)))
	native_update_checkbox(checkbox_view, el)
	return checkbox_view
}

fn native_update_checkbox(checkbox_view NativeView, el Element) {
	native_set_frame(checkbox_view, element_rect(el.frame))
	macos.msg_void_i64(checkbox_view, 'setButtonType:', ns_button_type_switch)
	macos.msg_void1(checkbox_view, 'setTitle:', macos.nsstring(el.text))
	macos.msg_void_i64(checkbox_view, 'setState:', if el.checked { i64(1) } else { i64(0) })
	macos.msg_void_bool(checkbox_view, 'setAllowsMixedState:', false)
	macos.msg_void1(checkbox_view, 'setFont:', native_font(el.text_style.size, el.text_style.bold, el.text_style.italic))
}

fn native_new_switch_control(el Element) NativeView {
	class_name := if macos.get_class('NSSwitch') == unsafe { nil } { 'NSButton' } else { 'NSSwitch' }
	switch_view := macos.msg_id_rect(macos.alloc(class_name), 'initWithFrame:', appkit_rect(element_rect(el.frame)))
	native_update_switch_control(switch_view, el)
	return switch_view
}

fn native_update_switch_control(view NativeView, el Element) {
	native_set_frame(view, element_rect(el.frame))
	if macos.msg_bool_id(view, 'isKindOfClass:', macos.get_class('NSButton')) {
		macos.msg_void_i64(view, 'setButtonType:', ns_button_type_switch)
		macos.msg_void1(view, 'setTitle:', macos.nsstring(''))
		macos.msg_void_bool(view, 'setAllowsMixedState:', false)
	}
	macos.msg_void_i64(view, 'setState:', if el.checked { i64(1) } else { i64(0) })
}

fn native_new_toggle_button(el Element) NativeView {
	native := native_new_button(element_rect(el.frame), el.text, el.box, el.text_style.color,
		el.text_style.size, el.text_style.bold, el.text_style.italic, el.text_style.underline,
		el.text_style.lines, el.image_path, el.native_style)
	native_update_toggle_button(native, el)
	return native
}

fn native_update_toggle_button(native NativeView, el Element) {
	box := if el.checked { el.toggle_down_box } else { el.box }
	style := if el.checked { el.toggle_down_text_style } else { el.text_style }
	native_update_button(native, element_rect(el.frame), el.text, box, style.color, style.size,
		style.bold, style.italic, style.underline, style.lines, el.image_path,
		el.native_style)
	macos.msg_void_i64(native, 'setButtonType:', ns_button_type_push_on_push_off)
	macos.msg_void_i64(native, 'setState:', if el.checked { i64(1) } else { i64(0) })
}

fn native_new_slider(el Element) NativeView {
	slider_view := macos.msg_id_rect(macos.alloc('NSSlider'), 'initWithFrame:', appkit_rect(element_rect(el.frame)))
	native_update_slider(slider_view, el)
	return slider_view
}

fn native_update_slider(slider_view NativeView, el Element) {
	native_set_frame(slider_view, element_rect(el.frame))
	maximum := if el.max_value > el.min_value { el.max_value } else { el.min_value }
	macos.msg_void_f64(slider_view, 'setMinValue:', el.min_value)
	macos.msg_void_f64(slider_view, 'setMaxValue:', maximum)
	macos.msg_void_f64(slider_view, 'setDoubleValue:', slider_clamped_value(el.value,
		el.min_value, el.max_value))
	macos.msg_void_bool(slider_view, 'setContinuous:', true)
	if macos.responds_to(slider_view, 'setVertical:') {
		macos.msg_void_bool(slider_view, 'setVertical:', el.orientation == .vertical)
	}
}

fn native_snap_slider_value(slider_view NativeView, spec SliderSpec) f64 {
	raw := macos.msg_f64(slider_view, 'doubleValue')
	normalized := slider_value_normalized(raw, spec.min, spec.max)
	value := slider_value_from_normalized(normalized, spec.min, spec.max, spec.step)
	if value != raw {
		macos.msg_void_f64(slider_view, 'setDoubleValue:', value)
	}
	return value
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
	icon_image := native_image_from_name_sized(image_name, icon_size, icon_size)
	macos.msg_void1(button_view, 'setImage:', icon_image)
	macos.msg_void_i64(button_view, 'setImagePosition:', if frame.height >= 42 {
		i64(5)
	} else {
		i64(2)
	})
	macos.msg_void_i64(button_view, 'setImageScaling:', 3)
}

fn native_new_dropdown(el Element) NativeView {
	dropdown_view := macos.msg_id_rect(macos.alloc('NSPopUpButton'), 'initWithFrame:', appkit_rect(element_rect(el.frame)))
	native_update_dropdown(dropdown_view, el)
	return dropdown_view
}

fn native_update_dropdown(popup NativeView, el Element) {
	native_set_frame(popup, element_rect(el.frame))
	macos.msg_void(popup, 'removeAllItems')
	for item in el.menu {
		macos.msg_void1(popup, 'addItemWithTitle:', macos.nsstring(item.title))
	}
	native_select_dropdown_item(popup, el.text)
	macos.msg_void1(popup, 'setFont:', native_font(el.text_style.size, el.text_style.bold, el.text_style.italic))
	macos.msg_void_bool(popup, 'setBordered:', box_draws_fill(el.box))
	macos.msg_void_u64(popup, 'setBezelStyle:', 1)
}

fn native_new_text_field(el Element) NativeView {
	frame := element_rect(el.frame)
	cls := if el.secure { 'NSSecureTextField' } else { 'NSTextField' }
	field := macos.msg_id_rect(macos.alloc(cls), 'initWithFrame:', appkit_rect(frame))
	native_update_text_field(field, frame, el.placeholder, el.text, el.box, el.text_style.color,
		el.text_style.size, true, el.readonly, el.enabled)
	return field
}

fn native_update_text_field(field NativeView, frame NativeRect, placeholder string, text string, box BoxStyle, text_hex u32, size f64, declared_text_changed bool, readonly bool, enabled bool) {
	native_set_frame(field, frame)
	// Unrelated refreshes preserve native edits. A changed declaration remains
	// controlled and is applied explicitly.
	if declared_text_changed && native_text(field) != text {
		macos.msg_void1(field, 'setStringValue:', macos.nsstring(text))
	}
	macos.msg_void1(field, 'setPlaceholderString:', macos.nsstring(placeholder))
	macos.msg_void1(field, 'setTextColor:', native_color(text_hex))
	macos.msg_void1(field, 'setFont:', native_font(size, false, false))
	macos.msg_void_bool(field, 'setBordered:', true)
	macos.msg_void_bool(field, 'setBezeled:', true)
	macos.msg_void_u64(field, 'setBezelStyle:', 1)
	draws_background := box_draws_fill(box)
	macos.msg_void_bool(field, 'setDrawsBackground:', draws_background)
	if draws_background {
		macos.msg_void1(field, 'setBackgroundColor:', native_color(box.bg))
	}
	macos.msg_void_bool(field, 'setEditable:', !readonly && enabled)
	macos.msg_void_bool(field, 'setSelectable:', true)
	macos.msg_void_bool(field, 'setEnabled:', enabled)
}

// native_new_text_area builds an NSScrollView wrapping an NSTextView —
// native multi-line editing with wrapping, selection, clipboard and undo.
fn native_new_text_area(el Element) NativeView {
	frame := element_rect(el.frame)
	if el.disable_scroll {
		tv := native_new_text_view(appkit_rect(frame), el)
		return tv
	}
	scroll_view := macos.msg_id_rect(macos.alloc('NSScrollView'), 'initWithFrame:', appkit_rect(frame))
	macos.msg_void_bool(scroll_view, 'setHasVerticalScroller:', true)
	macos.msg_void_bool(scroll_view, 'setAutohidesScrollers:', true)
	native_set_scroll_background(scroll_view, el.box)
	tv := native_new_text_view(macos.rect(0, 0, frame.width, frame.height), el)
	macos.msg_void1(scroll_view, 'setDocumentView:', tv)
	macos.release(tv)
	native_set_corner_radius(scroll_view, el.box.radius)
	return scroll_view
}

fn native_new_text_view(frame macos.Rect, el Element) NativeView {
	tv := macos.msg_id_rect(macos.alloc('NSTextView'), 'initWithFrame:', frame)
	macos.msg_void1(tv, 'setFont:', native_text_style_font(el.text_style))
	macos.msg_void_bool(tv, 'setRichText:', el.text_runs.len > 0)
	macos.msg_void_bool(tv, 'setAllowsUndo:', true)
	macos.msg_void_bool(tv, 'setVerticallyResizable:', true)
	macos.msg_void_bool(tv, 'setHorizontallyResizable:', false)
	macos.msg_void_u64(tv, 'setAutoresizingMask:', 2) // NSViewWidthSizable
	macos.msg_void_bool(tv, 'setDrawsBackground:', box_draws_fill(el.box))
	if box_draws_fill(el.box) {
		macos.msg_void1(tv, 'setBackgroundColor:', native_color(el.box.bg))
	}
	macos.msg_void1(tv, 'setTextColor:', native_color(el.text_style.color))
	macos.msg_void_bool(tv, 'setEditable:', !el.readonly && el.enabled)
	macos.msg_void_bool(tv, 'setSelectable:', true)
	native_set_text_area_content(tv, el)
	native_text_view_set_paragraph_style(tv, align_value(el.text_style.align), el.text_style.head_indent, el.text_style.first_line_indent, el.text_style.hyphenation_factor)
	st := state()
	macos.msg_void1(tv, 'setDelegate:', st.button_handler)
	return tv
}

fn native_update_text_area(native NativeView, el Element, declared_text_changed bool, content_changed bool) {
	frame := element_rect(el.frame)
	native_set_frame(native, frame)
	if !el.disable_scroll {
		macos.msg_void_bool(native, 'setHasVerticalScroller:', true)
		macos.msg_void_bool(native, 'setAutohidesScrollers:', true)
		native_set_scroll_background(native, el.box)
	}
	tv := text_area_text_view(native, el.disable_scroll)
	if native_is_nil(tv) {
		return
	}
	macos.msg_void_bool(tv, 'setEditable:', !el.readonly && el.enabled)
	macos.msg_void_bool(tv, 'setSelectable:', true)
	macos.msg_void1(tv, 'setFont:', native_text_style_font(el.text_style))
	macos.msg_void1(tv, 'setTextColor:', native_color(el.text_style.color))
	macos.msg_void_bool(tv, 'setDrawsBackground:', box_draws_fill(el.box))
	if box_draws_fill(el.box) {
		macos.msg_void1(tv, 'setBackgroundColor:', native_color(el.box.bg))
	}
	current := macos.utf8_string(macos.msg_id(tv, 'string'))
	replace_text := declared_text_changed && current != el.text
	if replace_text || content_changed {
		was_editing := native_is_first_responder(tv)
		selection := native_text_view_selected_range(tv)
		native_set_text_area_content(tv, Element{
			...el
			text: if replace_text { el.text } else { current }
		})
		native_text_view_restore_selected_range(tv, selection.location, selection.length, was_editing)
	}
	native_text_view_set_paragraph_style(tv, align_value(el.text_style.align), el.text_style.head_indent, el.text_style.first_line_indent, el.text_style.hyphenation_factor)
}

fn native_set_text_area_content(tv NativeView, el Element) {
	if el.text_runs.len == 0 {
		macos.msg_void_bool(tv, 'setRichText:', false)
		macos.msg_void1(tv, 'setString:', macos.nsstring(el.text))
		return
	}
	macos.msg_void_bool(tv, 'setRichText:', true)
	native_text_view_set_attributed_string(tv, el.text, el.text_style.color, el.text_style.background_color, el.text_style.size, el.text_style.font_family, el.text_style.bold, el.text_style.italic, el.text_style.underline, el.text_style.strikethrough, el.text_style.vertical_align)
	base_length := native_utf16_length(el.text)
	if base_length > 0 {
		native_text_view_add_effect(tv, 0, base_length, text_style_effect_value(el.text_style))
	}
	mut location := u64(0)
	for run in el.text_runs {
		length := native_utf16_length(run.text)
		if length > 0 {
			native_text_view_add_style(tv, location, length, run.style.color, run.style.background_color, run.style.size, run.style.font_family, run.style.bold, run.style.italic, run.style.underline, run.style.strikethrough, run.style.vertical_align)
			native_text_view_add_effect(tv, location, length, text_style_effect_value(run.style))
			if run.style.link.len > 0 {
				native_text_view_add_link(tv, location, length, run.style.link)
			}
		}
		location += length
	}
}

fn text_style_effect_value(style TextStyle) int {
	return (if style.shadow {
		1
	} else {
		0
	}) | (if style.outline {
		2
	} else {
		0
	})
}

fn native_set_button_target(button NativeView, target NativeView) {
	macos.msg_void1(button, 'setTarget:', target)
	macos.msg_void1(button, 'setAction:', macos.sel('handleTap:'))
}

fn native_set_control_target(control NativeView, target NativeView) {
	macos.msg_void1(control, 'setTarget:', target)
	macos.msg_void1(control, 'setAction:', macos.sel('handleTap:'))
}

fn native_clear_control_target(control NativeView) {
	macos.msg_void1(control, 'setTarget:', native_nil_view())
	macos.msg_void1(control, 'setAction:', macos.Id(unsafe { nil }))
}

fn native_clear_control_state(control NativeView) {
	objc_clear_control_state(control)
}

fn native_finish_button_action(control NativeView, persistent_state bool) {
	if !persistent_state {
		native_clear_control_state(control)
	}
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

fn native_focus(view NativeView) bool {
	return native_focus_view(view)
}

fn native_end_editing(view NativeView) {
	window := macos.msg_id(view, 'window')
	native_end_window_editing(window)
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

fn native_set_box_background(view NativeView, box BoxStyle) {
	if box_draws_fill(box) {
		native_set_background(view, box.bg)
		return
	}
	macos.msg_void_bool(view, 'setWantsLayer:', true)
	layer := macos.msg_id(view, 'layer')
	macos.msg_void1(layer, 'setBackgroundColor:', macos.Id(unsafe { nil }))
}

fn native_set_corner_radius(view NativeView, radius f64) {
	macos.msg_void_bool(view, 'setWantsLayer:', true)
	layer := macos.msg_id(view, 'layer')
	macos.msg_void_f64(layer, 'setCornerRadius:', radius)
	macos.msg_void_bool(layer, 'setMasksToBounds:', radius > 0)
}

fn native_set_border_layer(view NativeView, side string, frame NativeRect, color u32, visible bool) {
	key := native_border_key(side)
	mut border := NativeView(macos.get_associated_object(view, key))
	if !visible {
		if !native_is_nil(border) {
			macos.msg_void_bool(border, 'setHidden:', true)
		}
		return
	}
	parent_layer := macos.msg_id(view, 'layer')
	if native_is_nil(border) {
		border = macos.msg_id(macos.alloc('CALayer'), 'init')
		native_set_associated_object(view, key, border)
		macos.release(border)
	}
	// A native control can replace its backing layer while its style changes.
	// Attach only when needed so routine refreshes do not reorder sublayers.
	if macos.msg_id(border, 'superlayer') != parent_layer {
		macos.msg_void1(parent_layer, 'addSublayer:', border)
	}
	macos.msg_void_rect(border, 'setFrame:', appkit_rect(frame))
	macos.msg_void1(border, 'setBackgroundColor:', macos.msg_id(native_color(color), 'CGColor'))
	macos.msg_void_bool(border, 'setHidden:', false)
}

fn native_set_box_borders(view NativeView, box BoxStyle) {
	view_bounds := macos.msg_rect(view, 'bounds')
	left := box_border_width(box.border_left, view_bounds.width)
	top := box_border_width(box.border_top, view_bounds.height)
	right := box_border_width(box.border_right, view_bounds.width)
	bottom := box_border_width(box.border_bottom, view_bounds.height)
	if left <= 0 && top <= 0 && right <= 0 && bottom <= 0 {
		for side in ['left', 'top', 'right', 'bottom'] {
			native_set_border_layer(view, side, NativeRect{}, box.border_color, false)
		}
		return
	}
	macos.msg_void_bool(view, 'setWantsLayer:', true)
	if box.radius > 0 {
		layer := macos.msg_id(view, 'layer')
		macos.msg_void_f64(layer, 'setCornerRadius:', box.radius)
		macos.msg_void_bool(layer, 'setMasksToBounds:', true)
	}
	transaction := macos.Id(macos.get_class('CATransaction'))
	macos.msg_void(transaction, 'begin')
	macos.msg_void_bool(transaction, 'setDisableActions:', true)
	flipped := macos.msg_bool(view, 'isFlipped')
	top_y := if flipped { 0.0 } else { view_bounds.height - top }
	bottom_y := if flipped { view_bounds.height - bottom } else { 0.0 }
	native_set_border_layer(view, 'left', native_rect(0, 0, left, view_bounds.height),
		box.border_color, left > 0)
	native_set_border_layer(view, 'top', native_rect(0, top_y, view_bounds.width, top),
		box.border_color, top > 0)
	native_set_border_layer(view, 'right', native_rect(view_bounds.width - right, 0, right,
		view_bounds.height), box.border_color, right > 0)
	native_set_border_layer(view, 'bottom', native_rect(0, bottom_y, view_bounds.width, bottom),
		box.border_color, bottom > 0)
	macos.msg_void(transaction, 'commit')
}

fn native_font(size f64, bold bool, italic bool) NativeView {
	return NativeView(native_font_object(size, bold, italic))
}

// Native text areas used to ignore TextStyle.font_family and always install
// the system face. Keep the same weight/italic base, then resolve the declared
// family through the text formatting helper used by rich text operations.
fn native_text_style_font(style TextStyle) NativeView {
	base := macos.Id(native_font(style.size, style.bold, style.italic))
	return NativeView(native_font_with_family(base, style.font_family, style.size))
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
	// The menu bar and the tray can be declared before the app is up; install
	// whatever was declared now that AppKit can accept it. The menu bar goes in
	// either way, since macOS needs its application menu to handle Cmd+Q.
	install_declared_menus()
	frame := native_rect(120, 120, f64(st.run_config.width), f64(st.run_config.height))
	st.window = native_new_window(frame, st.run_config.title)
	native_set_content_min_size(st.window, f64(st.run_config.min_width),
		f64(st.run_config.min_height))
	// The app delegate doubles as window delegate for windowDidResize:
	macos.msg_void1(st.window, 'setDelegate:', st.app_delegate)
	root_frame := native_rect(0, 0, f64(st.run_config.width), f64(st.run_config.height))
	st.root_view = native_new_flipped_view(root_frame, BoxStyle{
		bg: 0xffffff
	})
	native_register_drop_types(st.root_view)
	native_set_content_view(st.window, st.root_view)
	macos.release(st.root_view)
	if native_is_nil(st.button_handler) {
		st.button_handler = native_new_object('UI2ButtonHandler')
	}
	native_make_key_and_order_front(st.window)
	native_activate()
	refresh()
}

fn fire_pointer_event(native NativeView, phase string, event voidptr) {
	st := state()
	// A non-interactive child (e.g. an icon image) sits on top of its pointer
	// view and receives the click first. Walk up the view hierarchy to the
	// nearest registered pointer target so the enclosing button still fires.
	mut target := native
	mut id := st.pointer_ids[u64(voidptr(target))] or { '' }
	for id.len == 0 {
		target = NativeView(macos.msg_id(target, 'superview'))
		if native_is_nil(target) {
			return
		}
		id = st.pointer_ids[u64(voidptr(target))] or { '' }
	}
	if phase == 'drag' && !(st.pointer_draggable[u64(voidptr(target))] or { false }) {
		return
	}
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	point := native_event_point(st.root_view, event)
	st.event_handler('pointer:${phase}:${id}:${point.x}:${point.y}')
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
	native_add_cursor_rect(self, cursor)
}

@[export: 'ui2_dragging_entered']
fn ui2_dragging_entered(_self voidptr, _cmd voidptr, _dragging_info voidptr) u64 {
	st := state()
	return if voidptr(st.drop_handler) == unsafe { nil } { u64(0) } else { u64(1) }
}

@[export: 'ui2_perform_drag_operation']
fn ui2_perform_drag_operation(self voidptr, _cmd voidptr, dragging_info voidptr) bool {
	st := state()
	if voidptr(st.drop_handler) == unsafe { nil } {
		return false
	}
	paths := native_dragging_file_paths(dragging_info, 256)
	dropped_text := native_dragging_text(dragging_info)
	point := native_dragging_point(self, dragging_info)
	st.drop_handler(DropEvent{
		paths: paths
		text: dropped_text
		x: point.x
		y: point.y
	})
	return paths.len > 0 || dropped_text.len > 0
}

@[export: 'ui2_button_tap']
fn ui2_button_tap(_self voidptr, _cmd voidptr, sender voidptr) {
	st := state()
	native := NativeView(sender)
	pointer := u64(voidptr(native))
	commit_macos_toggle_button(pointer, native)
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	id := st.control_ids[pointer] or { '' }
	if id.len > 0 {
		if spec := st.slider_specs[pointer] {
			native_snap_slider_value(native, spec)
		}
		native_finish_button_action(native, st.checkbox_controls[pointer] or { false })
		st.event_handler(id)
		return
	}
}

@[export: 'ui2_control_text_changed']
fn ui2_control_text_changed(_self voidptr, _cmd voidptr, notification voidptr) {
	st := state()
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	field := macos.msg_id(macos.Id(notification), 'object')
	id := st.control_change_ids[u64(voidptr(field))] or { '' }
	if id.len > 0 {
		st.event_handler(id)
	}
}

@[export: 'ui2_control_do_command']
fn ui2_control_do_command(_self voidptr, _cmd voidptr, control voidptr, _text_view voidptr, command voidptr) bool {
	mut st := state()
	if voidptr(st.key_handler) == unsafe { nil }
		|| u64(control) !in st.control_change_ids {
		return false
	}
	key := text_command_key(command, native_current_event_modifier_flags()) or { return false }
	if key != 'tab' && key != 'shift+tab' {
		return false
	}
	st.key_consumed = false
	st.key_handler(key)
	consumed := st.key_consumed
	st.key_consumed = false
	return consumed
}

@[export: 'ui2_text_view_changed']
fn ui2_text_view_changed(_self voidptr, _cmd voidptr, notification voidptr) {
	st := state()
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	tv := macos.msg_id(macos.Id(notification), 'object')
	id := st.textview_action_ids[u64(voidptr(tv))] or { return }
	st.event_handler(id)
}

@[export: 'ui2_text_view_do_command']
fn ui2_text_view_do_command(_self voidptr, _cmd voidptr, text_view voidptr, command voidptr) bool {
	mut st := state()
	if voidptr(st.key_handler) == unsafe { nil } {
		return false
	}
	key := text_command_key(command, native_current_event_modifier_flags()) or { return false }
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
	selector := macos.Sel(command)
	shift := modifiers & 0x20000 != 0
	if selector == macos.sel('deleteBackward:') {
		return 'backspace'
	}
	if selector == macos.sel('deleteForward:') {
		return 'forward_delete'
	}
	if selector == macos.sel('insertLineBreak:') {
		return 'line_break'
	}
	if selector == macos.sel('insertNewline:') || selector == macos.sel('insertParagraphSeparator:') {
		return if shift { 'line_break' } else { 'enter' }
	}
	if selector == macos.sel('insertTab:') {
		return if shift { 'shift+tab' } else { 'tab' }
	}
	if selector == macos.sel('insertBacktab:') {
		return 'shift+tab'
	}
	return none
}

fn text_command_boundary_noop(text_view voidptr, key string) bool {
	selected := native_text_view_selected_range(text_view)
	if selected.length > 0 {
		return false
	}
	text_length := native_text_view_text_length(text_view)
	return match key {
		'backspace' { selected.location == 0 }
		'forward_delete' { selected.location >= text_length }
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
	if s == 'cmd+v' && native_pasteboard_has_image() {
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
		else {
			return false
		}
	}

	return native_app_send_edit_command(command)
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
}
