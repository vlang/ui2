module ui2

import macos

#flag darwin -framework Cocoa
#insert "@DIR/macos/native_helpers.h"

fn C.macos_objc_msg_id_rect_u64_u64_bool(obj macos.Id, selector macos.Sel, rect macos.Rect, a1 u64, a2 u64, a3 bool) macos.Id
fn C.ui2_nscolor_rgb(hex u32) macos.Id
fn C.ui2_app_did_finish_launching(self voidptr, cmd voidptr, notification voidptr)
fn C.ui2_app_should_terminate_after_last_window_closed(self voidptr, cmd voidptr, sender voidptr) bool
fn C.ui2_button_tap(self voidptr, cmd voidptr, sender voidptr)
fn C.ui2_view_is_flipped(self voidptr, cmd voidptr) bool

const ns_window_style_titled = u64(1)
const ns_window_style_closable = u64(2)
const ns_window_style_miniaturizable = u64(4)
const ns_window_style_resizable = u64(8)
const ns_backing_store_buffered = u64(2)

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
	build_screen   BuildFn = BuildFn(unsafe { nil })
	event_handler  EventFn = EventFn(unsafe { nil })
	window         NativeView
	root_view      NativeView
	button_handler NativeView
	views          map[string]NativeView
	nodes          map[string]NativeView
	node_kinds     map[string]Kind
	button_ids     []string
	run_config     RunConfig
}

const runtime_state_singleton = &RuntimeState{
	views:      map[string]NativeView{}
	nodes:      map[string]NativeView{}
	node_kinds: map[string]Kind{}
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
}

pub fn text(id string) string {
	st := state()
	native := st.views[id] or { return '' }
	return native_text(native)
}

pub fn set_text(id string, t string) {
	st := state()
	if id in st.views {
		native := st.views[id] or { return }
		native_set_text(native, t)
	}
}

pub fn focus(id string) {
	st := state()
	native := st.views[id] or { return }
	native_focus(native)
}

pub fn dismiss_keyboard() {
	st := state()
	if !native_is_nil(st.root_view) {
		native_end_editing(st.root_view)
	}
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

fn ensure_runtime_classes() {
	if macos.get_class('UI2FlippedView') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSView'), 'UI2FlippedView')
		macos.add_method(cls, 'isFlipped', voidptr(C.ui2_view_is_flipped), 'B@:')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2AppDelegate') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2AppDelegate')
		macos.add_method(cls, 'applicationDidFinishLaunching:',
			voidptr(C.ui2_app_did_finish_launching), 'v@:@')
		macos.add_method(cls, 'applicationShouldTerminateAfterLastWindowClosed:',
			voidptr(C.ui2_app_should_terminate_after_last_window_closed), 'B@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('UI2ButtonHandler') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2ButtonHandler')
		macos.add_method(cls, 'handleTap:', voidptr(C.ui2_button_tap), 'v@:@')
		macos.register_class_pair(cls)
	}
}

fn align_value(a Align) int {
	return match a {
		.left { 0 }
		.right { 1 }
		.center { 2 }
	}
}

fn element_rect(r Rect) NativeRect {
	return native_rect(r.x, r.y, r.width, r.height)
}

fn render_root(root Element) {
	mut st := state()
	st.views = map[string]NativeView{}
	st.button_ids = []string{}
	native_set_background(st.root_view, root.box.bg)
	mut active := map[string]bool{}
	for i, child in root.children {
		render_element(st.root_view, child, i.str(), mut active)
	}
	remove_stale_nodes(active)
}

fn render_element(parent NativeView, el Element, key string, mut active map[string]bool) NativeView {
	active[key] = true
	mut st := state()
	mut native := st.nodes[key] or { native_nil_view() }
	existing_kind := st.node_kinds[key] or { Kind.screen }
	if native_is_nil(native) || existing_kind != el.kind {
		if !native_is_nil(native) {
			native_remove_from_superview(native)
		}
		native = native_create_element(el)
		st.nodes[key] = native
		st.node_kinds[key] = el.kind
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
				render_element(parent, child, child_key(key, i), mut active)
			}
		}
		.view {
			for i, child in el.children {
				render_element(native, child, child_key(key, i), mut active)
			}
		}
		.scroll {
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
				render_element(doc, child, child_key(doc_key, i), mut active)
			}
		}
		.button {
			register_button(native, el.id)
		}
		.text_field {
			if el.emit_change {
				register_control(native, el.id)
			}
		}
		.label {
			// Labels are updated by native_update_element.
		}
	}

	if el.id.len > 0 {
		st.views[el.id] = native
	}
	return native
}

fn native_create_element(el Element) NativeView {
	return match el.kind {
		.screen {
			native_nil_view()
		}
		.view {
			native_new_flipped_view(element_rect(el.frame), el.box.bg)
		}
		.scroll {
			native_new_scroll(element_rect(el.frame), el.box.bg)
		}
		.label {
			native_new_label(element_rect(el.frame), el.text, el.text_style.color,
				el.text_style.size, el.text_style.bold, align_value(el.text_style.align),
				el.text_style.lines)
		}
		.button {
			native_new_button(element_rect(el.frame), el.text, el.box.bg, el.text_style.color,
				el.text_style.size, el.text_style.bold, el.box.radius, el.text_style.lines)
		}
		.text_field {
			native_new_text_field(element_rect(el.frame), el.placeholder, el.text, el.box.bg,
				el.text_style.color, el.text_style.size, el.box.radius)
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
				el.text_style.size, el.text_style.bold, align_value(el.text_style.align),
				el.text_style.lines)
		}
		.button {
			native_update_button(native, element_rect(el.frame), el.text, el.box.bg,
				el.text_style.size, el.text_style.bold, el.box.radius, el.text_style.lines)
		}
		.text_field {
			native_update_text_field(native, element_rect(el.frame), el.placeholder, el.text,
				el.box.bg, el.text_style.color, el.text_style.size, el.box.radius)
		}
	}
}

fn child_key(parent string, index int) string {
	if parent.len == 0 {
		return index.str()
	}
	return parent + '/' + index.str()
}

fn register_button(native NativeView, id string) {
	mut st := state()
	tag := st.button_ids.len
	st.button_ids << id
	native_set_tag(native, tag)
	native_set_button_target(native, st.button_handler)
	native_set_associated_object(native, assoc_handler_key(), st.button_handler)
}

fn register_control(native NativeView, id string) {
	mut st := state()
	tag := st.button_ids.len
	st.button_ids << id
	native_set_tag(native, tag)
	native_set_control_target(native, st.button_handler)
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
	window := C.macos_objc_msg_id_rect_u64_u64_bool(macos.alloc('NSWindow'),
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

fn native_new_label(frame NativeRect, text string, text_hex u32, size f64, bold bool, align int, lines int) NativeView {
	label_view := macos.msg_id_rect(macos.alloc('NSTextField'), 'initWithFrame:',
		appkit_rect(frame))
	native_update_label(label_view, frame, text, text_hex, size, bold, align, lines)
	return label_view
}

fn native_update_label(label_view NativeView, frame NativeRect, text string, text_hex u32, size f64, bold bool, align int, lines int) {
	native_set_frame(label_view, frame)
	macos.msg_void1(label_view, 'setStringValue:', macos.nsstring(text))
	macos.msg_void_bool(label_view, 'setEditable:', false)
	macos.msg_void_bool(label_view, 'setSelectable:', false)
	macos.msg_void_bool(label_view, 'setBordered:', false)
	macos.msg_void_bool(label_view, 'setBezeled:', false)
	macos.msg_void_bool(label_view, 'setDrawsBackground:', false)
	macos.msg_void1(label_view, 'setTextColor:', native_color(text_hex))
	macos.msg_void1(label_view, 'setFont:', native_font(size, bold))
	macos.msg_void_i64(label_view, 'setAlignment:', i64(align))
	cell := macos.msg_id(label_view, 'cell')
	macos.msg_void_i64(cell, 'setLineBreakMode:', 4)
	macos.msg_void_bool(cell, 'setUsesSingleLineMode:', lines == 1)
}

fn native_new_button(frame NativeRect, title string, bg_hex u32, text_hex u32, size f64, bold bool, radius f64, lines int) NativeView {
	button_view := macos.msg_id_rect(macos.alloc('NSButton'), 'initWithFrame:', appkit_rect(frame))
	native_update_button(button_view, frame, title, bg_hex, size, bold, radius, lines)
	_ = text_hex
	return button_view
}

fn native_update_button(button_view NativeView, frame NativeRect, title string, bg_hex u32, size f64, bold bool, radius f64, lines int) {
	native_set_frame(button_view, frame)
	macos.msg_void1(button_view, 'setTitle:', macos.nsstring(title))
	macos.msg_void_u64(button_view, 'setBezelStyle:', 1)
	macos.msg_void_bool(button_view, 'setBordered:', true)
	macos.msg_void1(button_view, 'setFont:', native_font(size, bold))
	native_set_background(button_view, bg_hex)
	native_set_corner_radius(button_view, radius)
	cell := macos.msg_id(button_view, 'cell')
	macos.msg_void_i64(cell, 'setLineBreakMode:', 4)
	macos.msg_void_bool(cell, 'setUsesSingleLineMode:', lines == 1)
}

fn native_new_text_field(frame NativeRect, placeholder string, text string, bg_hex u32, text_hex u32, size f64, radius f64) NativeView {
	field := macos.msg_id_rect(macos.alloc('NSTextField'), 'initWithFrame:', appkit_rect(frame))
	native_update_text_field(field, frame, placeholder, text, bg_hex, text_hex, size, radius)
	return field
}

fn native_update_text_field(field NativeView, frame NativeRect, placeholder string, text string, bg_hex u32, text_hex u32, size f64, radius f64) {
	native_set_frame(field, frame)
	macos.msg_void1(field, 'setStringValue:', macos.nsstring(text))
	macos.msg_void1(field, 'setPlaceholderString:', macos.nsstring(placeholder))
	macos.msg_void1(field, 'setTextColor:', native_color(text_hex))
	macos.msg_void1(field, 'setFont:', native_font(size, false))
	macos.msg_void_bool(field, 'setBordered:', true)
	macos.msg_void_bool(field, 'setDrawsBackground:', true)
	macos.msg_void1(field, 'setBackgroundColor:', native_color(bg_hex))
	native_set_corner_radius(field, radius)
}

fn native_set_button_target(button NativeView, target NativeView) {
	macos.msg_void1(button, 'setTarget:', target)
	macos.msg_void1(button, 'setAction:', macos.sel('handleTap:'))
}

fn native_set_control_target(control NativeView, target NativeView) {
	macos.msg_void1(control, 'setTarget:', target)
	macos.msg_void1(control, 'setAction:', macos.sel('handleTap:'))
}

fn native_text(view NativeView) string {
	return macos.utf8_string(macos.msg_id(view, 'stringValue'))
}

fn native_set_text(view NativeView, text string) {
	macos.msg_void1(view, 'setStringValue:', macos.nsstring(text))
}

fn native_focus(view NativeView) {
	macos.msg_bool(view, 'becomeFirstResponder')
}

fn native_end_editing(view NativeView) {
	macos.msg_bool(view, 'resignFirstResponder')
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

fn native_font(size f64, bold bool) NativeView {
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

@[export: 'ui2_button_tap']
fn ui2_button_tap(_self voidptr, _cmd voidptr, sender voidptr) {
	st := state()
	if voidptr(st.event_handler) == unsafe { nil } {
		return
	}
	tag := native_tag(NativeView(sender))
	if tag < 0 || tag >= st.button_ids.len {
		return
	}
	st.event_handler(st.button_ids[tag])
}
