module ui2

import ios
import macos

fn C.vui_app_did_finish_launching(self voidptr, cmd voidptr, application voidptr, launch_options voidptr) bool

fn C.vui_button_tap(self voidptr, cmd voidptr, sender voidptr)

fn C.vui_text_field_changed(self voidptr, cmd voidptr, sender voidptr)

fn C.vui_text_field_submitted(self voidptr, cmd voidptr, sender voidptr)

fn C.vui_text_view_changed(self voidptr, cmd voidptr, sender voidptr)

fn C.vui_button_long_press(self voidptr, cmd voidptr, sender voidptr)

fn C.vui_swipe_left(self voidptr, cmd voidptr, sender voidptr)

fn C.vui_swipe_should_begin(self voidptr, cmd voidptr, sender voidptr) bool

fn C.vui_swipe_should_recognize_simultaneously(self voidptr, cmd voidptr, sender voidptr, other voidptr) bool

fn C.vui_dropdown_selected(self voidptr, cmd voidptr, sender voidptr)

fn C.vui_scanner_present(self voidptr, cmd voidptr, root voidptr)

const swipe_delete_threshold = f64(72)
const swipe_max_translation = f64(140)
const gesture_state_began = 1
const gesture_state_changed = 2
const gesture_state_ended = 3
const gesture_state_cancelled = 4
const gesture_state_failed = 5

type View = voidptr

struct ObjcPoint {
mut:
	x f64
	y f64
}

fn C.objc_msgSend()

type ObjcPointMsg1 = fn (voidptr, voidptr, voidptr) ObjcPoint

type ObjcPointMsg0 = fn (voidptr, voidptr) ObjcPoint

type ObjcVoidPointBoolMsg = fn (voidptr, voidptr, ObjcPoint, bool)

type ObjcVoidBoolIdMsg = fn (voidptr, voidptr, bool, voidptr)

__global g_build_screen = BuildFn(unsafe { nil })
__global g_event_handler = EventFn(unsafe { nil })
__global g_window = View(unsafe { nil })
__global g_root_vc = View(unsafe { nil })
__global g_root_view = View(unsafe { nil })
__global g_button_handler = View(unsafe { nil })
__global g_long_press_handler = View(unsafe { nil })
__global g_swipe_handler = View(unsafe { nil })
__global g_views = map[string]View{}
__global g_view_kinds = map[string]Kind{}
__global g_nodes = map[string]View{}
__global g_node_kinds = map[string]Kind{}
__global g_node_gestures = map[string]string{}
__global g_node_declared_text = map[string]string{}
__global g_action_ids = map[u64]string{}
__global g_text_change_ids = map[u64]string{}
__global g_text_submit_ids = map[u64]string{}
__global g_text_area_ids = map[u64]string{}
__global g_scroll_ids = map[string]bool{}
__global g_scroll_offsets = map[string]f64{}
__global g_view_translation_x = map[voidptr]f64{}

// ── Public API ─────────────────────────────────────────────────────

pub fn bounds() Rect {
	b := macos.msg_rect(macos.msg_id(macos.get_class('UIScreen'), 'mainScreen'), 'bounds')
	return Rect{
		x: b.x
		y: b.y
		width: b.width
		height: b.height
	}
}

pub fn run(build_screen BuildFn, event_handler EventFn) {
	g_build_screen = build_screen
	g_event_handler = event_handler
	ensure_runtime_classes()
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	code := ios.application_main(g_main_argc, &&char(g_main_argv), 'VuiAppDelegate')
	if code != 0 {
		exit(code)
	}
}

pub fn refresh() {
	if g_root_view == unsafe { nil } || voidptr(g_build_screen) == unsafe { nil } {
		return
	}
	root := g_build_screen()
	render_root(root)
}

pub fn text(id string) string {
	view := g_views[id] or { return '' }
	kind := g_view_kinds[id] or { Kind.view }
	ns_text := if kind == .dropdown {
		macos.msg_id(view, 'currentTitle')
	} else {
		macos.msg_id(view, 'text')
	}
	return macos.utf8_string(ns_text)
}

pub fn set_text(id string, t string) {
	if id in g_views {
		view := g_views[id] or { return }
		kind := g_view_kinds[id] or { Kind.view }
		if kind == .dropdown {
			macos.msg_void2(view, 'setTitle:forState:', macos.nsstring(t), macos.Id(usize(0)))
		} else {
			macos.msg_void1(view, 'setText:', macos.nsstring(t))
		}
	}
}

pub fn focus(id string) {
	view := g_views[id] or { return }
	macos.msg_bool(view, 'becomeFirstResponder')
}

pub fn focused_text_area_id() string {
	for id, native in g_views {
		if (g_view_kinds[id] or { Kind.view }) == .text_area && macos.msg_bool(native, 'isFirstResponder') {
			return id
		}
	}
	return ''
}

pub fn dismiss_keyboard() {
	if g_root_view != unsafe { nil } {
		macos.msg_void_bool(g_root_view, 'endEditing:', true)
	}
}

pub fn safe_area_top() f64 {
	if g_root_view == unsafe { nil } {
		return 0
	}
	insets := macos.msg_rect(g_root_view, 'safeAreaInsets')
	return insets.x
}

pub fn start_barcode_scan() {
	if g_root_vc == unsafe { nil } {
		return
	}
	native_present_barcode_scanner(g_root_vc)
}

// ── Native bridge helpers ──────────────────────────────────────────

fn native_rect(r Rect) macos.Rect {
	return macos.rect(r.x, r.y, r.width, r.height)
}

fn font(size f64, bold bool) macos.Id {
	if bold {
		return macos.msg_id_f64(macos.get_class('UIFont'), 'boldSystemFontOfSize:', size)
	}
	return macos.msg_id_f64(macos.get_class('UIFont'), 'systemFontOfSize:', size)
}

fn set_background(view View, hex u32) {
	macos.msg_void1(view, 'setBackgroundColor:', ios.color(hex))
}

fn set_corner_radius(view View, radius f64) {
	layer := macos.msg_id(view, 'layer')
	macos.msg_void_f64(layer, 'setCornerRadius:', radius)
	macos.msg_void_bool(layer, 'setMasksToBounds:', true)
}

fn add_button_target(btn View, target View) {
	macos.msg_void3(btn, 'addTarget:action:forControlEvents:', target, macos.sel('handleTap:'), macos.Id(usize(64)))
}

fn add_control_target_action(control View, target View, action string, event_mask u64) {
	macos.msg_void3(control, 'addTarget:action:forControlEvents:', target, macos.sel(action), macos.Id(usize(event_mask)))
}

fn remove_control_target_action(control View, target View, action string, event_mask u64) {
	macos.msg_void3(control, 'removeTarget:action:forControlEvents:', target, macos.sel(action), macos.Id(usize(event_mask)))
}

fn add_long_press_target(view View, target View) {
	recognizer := macos.msg_id2(macos.alloc('UILongPressGestureRecognizer'), 'initWithTarget:action:', target, macos.sel('handleLongPress:'))
	macos.msg_void_f64(recognizer, 'setMinimumPressDuration:', 0.45)
	macos.msg_void1(view, 'addGestureRecognizer:', recognizer)
	macos.release(recognizer)
}

fn add_swipe_left_target(view View, target View) {
	recognizer := macos.msg_id2(macos.alloc('UIPanGestureRecognizer'), 'initWithTarget:action:', target, macos.sel('handleSwipe:'))
	macos.msg_void_bool(recognizer, 'setCancelsTouchesInView:', false)
	macos.msg_void1(recognizer, 'setDelegate:', target)
	macos.msg_void1(view, 'addGestureRecognizer:', recognizer)
	macos.release(recognizer)
}

fn gesture_state(gesture View) int {
	return int(macos.msg_i64(gesture, 'state'))
}

fn gesture_view(gesture View) View {
	return macos.msg_id(gesture, 'view')
}

fn pan_base_view(view View) View {
	superview := macos.msg_id(view, 'superview')
	if superview == unsafe { nil } {
		return view
	}
	return superview
}

fn pan_point(gesture View, selector string, view View) ObjcPoint {
	if gesture == unsafe { nil } || view == unsafe { nil } {
		return ObjcPoint{}
	}
	sender := unsafe { ObjcPointMsg1(C.objc_msgSend) }
	base := pan_base_view(view)
	return sender(voidptr(gesture), voidptr(macos.sel(selector)), voidptr(base))
}

fn pan_translation_x(gesture View, view View) f64 {
	return pan_point(gesture, 'translationInView:', view).x
}

fn pan_translation_y(gesture View, view View) f64 {
	return pan_point(gesture, 'translationInView:', view).y
}

fn pan_velocity_x(gesture View, view View) f64 {
	return pan_point(gesture, 'velocityInView:', view).x
}

fn pan_velocity_y(gesture View, view View) f64 {
	return pan_point(gesture, 'velocityInView:', view).y
}

fn set_view_translation_x(view View, x f64) {
	if view == unsafe { nil } {
		return
	}
	key := voidptr(view)
	current := g_view_translation_x[key] or { f64(0) }
	delta := x - current
	if delta == 0 {
		return
	}
	mut frame := macos.msg_rect(view, 'frame')
	frame.x += delta
	macos.msg_void_rect(view, 'setFrame:', frame)
	if x == 0 {
		g_view_translation_x.delete(key)
	} else {
		g_view_translation_x[key] = x
	}
}

fn point_message0(view View, selector string) ObjcPoint {
	if view == unsafe { nil } {
		return ObjcPoint{}
	}
	sender := unsafe { ObjcPointMsg0(C.objc_msgSend) }
	return sender(voidptr(view), voidptr(macos.sel(selector)))
}

fn scroll_content_offset_y(scroll View) f64 {
	return point_message0(scroll, 'contentOffset').y
}

fn set_scroll_content_offset_y(scroll View, y f64) {
	if scroll == unsafe { nil } {
		return
	}
	mut offset := point_message0(scroll, 'contentOffset')
	offset.y = y
	sender := unsafe { ObjcVoidPointBoolMsg(C.objc_msgSend) }
	sender(voidptr(scroll), voidptr(macos.sel('setContentOffset:animated:')), offset, false)
}

fn new_native_view(frame Rect, bg_hex u32, radius f64) View {
	view := macos.msg_id_rect(macos.alloc('UIView'), 'initWithFrame:', native_rect(frame))
	set_background(view, bg_hex)
	set_corner_radius(view, radius)
	return view
}

fn new_scroll_view(frame Rect, bg_hex u32, radius f64) View {
	scroll := macos.msg_id_rect(macos.alloc('UIScrollView'), 'initWithFrame:', native_rect(frame))
	set_background(scroll, bg_hex)
	set_corner_radius(scroll, radius)
	macos.msg_void_bool(scroll, 'setAlwaysBounceVertical:', true)
	macos.msg_void_i64(scroll, 'setKeyboardDismissMode:', 1)
	macos.msg_void_i64(scroll, 'setContentInsetAdjustmentBehavior:', 2)
	return scroll
}

fn new_label_view(frame Rect, t string, text_hex u32, size f64, bold bool, align int, lines int) View {
	lbl := macos.msg_id_rect(macos.alloc('UILabel'), 'initWithFrame:', native_rect(frame))
	update_label_view(lbl, frame, t, text_hex, size, bold, align, lines)
	return lbl
}

fn update_label_view(lbl View, frame Rect, t string, text_hex u32, size f64, bold bool, align int, lines int) {
	macos.msg_void_rect(lbl, 'setFrame:', native_rect(frame))
	macos.msg_void1(lbl, 'setText:', macos.nsstring(t))
	macos.msg_void1(lbl, 'setTextColor:', ios.color(text_hex))
	macos.msg_void1(lbl, 'setFont:', font(size, bold))
	macos.msg_void_i64(lbl, 'setTextAlignment:', i64(align))
	macos.msg_void_i64(lbl, 'setNumberOfLines:', i64(lines))
	macos.msg_void_i64(lbl, 'setLineBreakMode:', 4)
}

fn new_image_view(frame Rect, path string, rotation f64) View {
	image_view := macos.msg_id_rect(macos.alloc('UIImageView'), 'initWithFrame:', native_rect(frame))
	update_image_view(image_view, frame, path, rotation)
	return image_view
}

fn update_image_view(image_view View, frame Rect, path string, rotation f64) {
	native_set_view_rotation(image_view, 0)
	macos.msg_void_rect(image_view, 'setFrame:', native_rect(frame))
	macos.msg_void_i64(image_view, 'setContentMode:', 1)
	native_set_view_rotation(image_view, rotation)
	image := if path.trim_space().len == 0 {
		View(unsafe { nil })
	} else {
		macos.msg_id1(macos.get_class('UIImage'), 'imageWithContentsOfFile:', macos.nsstring(path))
	}
	macos.msg_void1(image_view, 'setImage:', image)
}

fn new_text_area_view(el Element) View {
	view := macos.msg_id_rect(macos.alloc('UITextView'), 'initWithFrame:', native_rect(el.frame))
	update_text_area_view(view, el, true)
	return view
}

fn update_text_area_view(view View, el Element, declared_text_changed bool) {
	macos.msg_void_rect(view, 'setFrame:', native_rect(el.frame))
	set_background(view, el.box.bg)
	macos.msg_void1(view, 'setTextColor:', ios.color(el.text_style.color))
	macos.msg_void1(view, 'setFont:', font(el.text_style.size, el.text_style.bold))
	macos.msg_void_bool(view, 'setEditable:', !el.readonly && el.enabled)
	macos.msg_void_bool(view, 'setSelectable:', true)
	macos.msg_void_bool(view, 'setScrollEnabled:', !el.disable_scroll)
	if declared_text_changed && macos.utf8_string(macos.msg_id(view, 'text')) != el.text {
		macos.msg_void1(view, 'setText:', macos.nsstring(el.text))
	}
	set_corner_radius(view, el.box.radius)
}

fn new_dropdown_view(el Element) View {
	view := new_button_view(el.frame, el.text, el.box.bg, el.text_style.color, el.text_style.size, el.text_style.bold, el.box.radius, el.text_style.lines)
	update_dropdown_view(view, el, true)
	return view
}

fn update_dropdown_view(view View, el Element, declared_text_changed bool) {
	macos.msg_void_rect(view, 'setFrame:', native_rect(el.frame))
	if declared_text_changed && macos.utf8_string(macos.msg_id(view, 'currentTitle')) != el.text {
		macos.msg_void2(view, 'setTitle:forState:', macos.nsstring(el.text), macos.Id(usize(0)))
	}
	set_background(view, el.box.bg)
	set_corner_radius(view, el.box.radius)
	native_configure_dropdown(view, el.menu)
}

fn new_button_view(frame Rect, title string, bg_hex u32, text_hex u32, size f64, bold bool, radius f64, lines int) View {
	btn := macos.msg_id_u64(macos.get_class('UIButton'), 'buttonWithType:', u64(0))
	// buttonWithType: is autoreleased. Retain so all native_create_element
	// results follow the same +1 ownership contract.
	macos.msg_id(btn, 'retain')
	update_button_view(btn, frame, title, bg_hex, text_hex, size, bold, radius, lines)
	return btn
}

fn update_button_view(btn View, frame Rect, title string, bg_hex u32, text_hex u32, size f64, bold bool, radius f64, lines int) {
	macos.msg_void_rect(btn, 'setFrame:', native_rect(frame))
	macos.msg_void2(btn, 'setTitle:forState:', macos.nsstring(title), macos.Id(usize(0)))
	macos.msg_void2(btn, 'setTitleColor:forState:', ios.color(text_hex), macos.Id(usize(0)))
	set_background(btn, bg_hex)
	title_label := macos.msg_id(btn, 'titleLabel')
	macos.msg_void1(title_label, 'setFont:', font(size, bold))
	set_corner_radius(btn, radius)
	macos.msg_void_i64(title_label, 'setNumberOfLines:', i64(lines))
	macos.msg_void_i64(title_label, 'setTextAlignment:', 1)
	macos.msg_void_i64(title_label, 'setLineBreakMode:', 4)
	macos.msg_void_rect(btn, 'setContentEdgeInsets:', macos.rect(6, 8, 6, 8))
}

fn checkbox_title(el Element) string {
	return '${if el.checked { '☑' } else { '☐' }}  ${el.text}'
}

fn new_checkbox_view(el Element) View {
	view := new_button_view(el.frame, checkbox_title(el), el.box.bg, el.text_style.color, el.text_style.size, el.text_style.bold, 0, el.text_style.lines)
	update_checkbox_view(view, el)
	return view
}

fn update_checkbox_view(view View, el Element) {
	update_button_view(view, el.frame, checkbox_title(el), el.box.bg, el.text_style.color, el.text_style.size, el.text_style.bold, 0, el.text_style.lines)
	macos.msg_void1(view, 'setBackgroundColor:', macos.msg_id(macos.get_class('UIColor'), 'clearColor'))
	macos.msg_void_i64(view, 'setContentHorizontalAlignment:', 1)
}

fn new_text_field_view(frame Rect, placeholder string, t string, bg_hex u32, text_hex u32, size f64, radius f64, keyboard int, secure bool) View {
	field := macos.msg_id_rect(macos.alloc('UITextField'), 'initWithFrame:', native_rect(frame))
	update_text_field_view(field, frame, placeholder, t, bg_hex, text_hex, size, radius, keyboard, secure, true, true, 12)
	return field
}

fn update_text_field_view(field View, frame Rect, placeholder string, t string, bg_hex u32, text_hex u32, size f64, radius f64, keyboard int, secure bool, autocorrect bool, declared_text_changed bool, padding_left f64) {
	macos.msg_void_rect(field, 'setFrame:', native_rect(frame))
	set_background(field, bg_hex)
	macos.msg_void1(field, 'setTextColor:', ios.color(text_hex))
	macos.msg_void1(field, 'setFont:', font(size, false))
	macos.msg_void1(field, 'setPlaceholder:', macos.nsstring(placeholder))
	if declared_text_changed && macos.utf8_string(macos.msg_id(field, 'text')) != t {
		macos.msg_void1(field, 'setText:', macos.nsstring(t))
	}
	macos.msg_void_i64(field, 'setKeyboardType:', i64(keyboard))
	if macos.msg_bool(field, 'isSecureTextEntry') != secure {
		macos.msg_void_bool(field, 'setSecureTextEntry:', secure)
	}
	macos.msg_void_i64(field, 'setAutocorrectionType:', if autocorrect { i64(0) } else { i64(1) })
	macos.msg_void_i64(field, 'setClearButtonMode:', 1)
	set_corner_radius(field, radius)
	mut pad := macos.msg_id(field, 'leftView')
	if pad == unsafe { nil } {
		pad = macos.msg_id_rect(macos.alloc('UIView'), 'initWithFrame:', macos.rect(0, 0, padding_left, frame.height))
		macos.msg_void1(field, 'setLeftView:', pad)
		macos.release(pad)
	} else {
		macos.msg_void_rect(pad, 'setFrame:', macos.rect(0, 0, padding_left, frame.height))
	}
	macos.msg_void_i64(field, 'setLeftViewMode:', 3)
}

// ── Runtime class registration ─────────────────────────────────────

fn ensure_runtime_classes() {
	if macos.get_class('VuiAppDelegate') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('UIResponder'), 'VuiAppDelegate')
		macos.add_protocol(cls, macos.get_protocol('UIApplicationDelegate'))
		macos.add_method(cls, 'application:didFinishLaunchingWithOptions:', voidptr(C.vui_app_did_finish_launching), 'B@:@@')
		// A dropdown's UICommand sends its selector up the responder chain,
		// which ends at the application delegate.
		macos.add_method(cls, 'vuiDropdownSelected:', voidptr(C.vui_dropdown_selected), 'v@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('VuiButtonHandler') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'VuiButtonHandler')
		macos.add_method(cls, 'handleTap:', voidptr(C.vui_button_tap), 'v@:@')
		macos.add_method(cls, 'handleTextChange:', voidptr(C.vui_text_field_changed), 'v@:@')
		macos.add_method(cls, 'handleTextSubmit:', voidptr(C.vui_text_field_submitted), 'v@:@')
		macos.add_method(cls, 'textViewDidChange:', voidptr(C.vui_text_view_changed), 'v@:@')
		macos.add_method(cls, 'vuiPresentScanner:', voidptr(C.vui_scanner_present), 'v@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('VuiLongPressHandler') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'VuiLongPressHandler')
		macos.add_method(cls, 'handleLongPress:', voidptr(C.vui_button_long_press), 'v@:@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('VuiSwipeHandler') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'VuiSwipeHandler')
		macos.add_protocol(cls, macos.get_protocol('UIGestureRecognizerDelegate'))
		macos.add_method(cls, 'handleSwipe:', voidptr(C.vui_swipe_left), 'v@:@')
		macos.add_method(cls, 'gestureRecognizerShouldBegin:', voidptr(C.vui_swipe_should_begin), 'B@:@')
		macos.add_method(cls, 'gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:', voidptr(C.vui_swipe_should_recognize_simultaneously), 'B@:@@')
		macos.register_class_pair(cls)
	}
}

// ── Association keys ───────────────────────────────────────────────

fn assoc_window_key() voidptr {
	return voidptr(C.vui_app_did_finish_launching)
}

fn assoc_handler_key() voidptr {
	return voidptr(C.vui_button_tap)
}

fn assoc_long_handler_key() voidptr {
	return voidptr(C.vui_button_long_press)
}

fn assoc_swipe_handler_key() voidptr {
	return voidptr(C.vui_swipe_left)
}

// ── Rendering ──────────────────────────────────────────────────────

fn align_value(a Align) int {
	return match a {
		.left { 0 }
		.center { 1 }
		.right { 2 }
	}
}

fn remember(id string, native View) {
	if id.len > 0 {
		g_views[id] = native
	}
}

fn remember_scroll_offsets() {
	for id, _ in g_scroll_ids {
		view := g_views[id] or { continue }
		g_scroll_offsets[id] = scroll_content_offset_y(view)
	}
}

fn render_root(root Element) {
	validate_element_tree(root) or {
		eprintln('ui2: ${err}')
		return
	}
	remember_scroll_offsets()
	g_views = map[string]View{}
	g_view_kinds = map[string]Kind{}
	g_action_ids = map[u64]string{}
	g_text_change_ids = map[u64]string{}
	g_text_submit_ids = map[u64]string{}
	g_text_area_ids = map[u64]string{}
	g_scroll_ids = map[string]bool{}
	set_background(g_root_view, root.box.bg)
	mut active := map[string]bool{}
	render_children(g_root_view, root.children, '', mut active)
	remove_stale_nodes(active)
	mut removed_scrolls := []string{}
	for id, _ in g_scroll_offsets {
		if id !in g_scroll_ids {
			removed_scrolls << id
		}
	}
	for id in removed_scrolls {
		g_scroll_offsets.delete(id)
	}
}

fn gesture_signature(el Element) string {
	return '${el.long_press}:${el.swipe_left}'
}

fn attach_view_gestures(native View, id string, long_press bool, swipe_left bool) {
	if id.len == 0 {
		return
	}
	g_action_ids[u64(native)] = id
	if long_press {
		add_long_press_target(native, g_long_press_handler)
		macos.set_associated_object(native, assoc_long_handler_key(), g_long_press_handler, macos.assoc_retain_nonatomic)
	}
	if swipe_left {
		add_swipe_left_target(native, g_swipe_handler)
		macos.set_associated_object(native, assoc_swipe_handler_key(), g_swipe_handler, macos.assoc_retain_nonatomic)
	}
}

fn render_children(parent View, children []Element, parent_key string, mut active map[string]bool) {
	for index, child in children {
		native := render_element(parent, child, reconciliation_child_key(parent_key, index, child), mut active)
		if child.kind == .screen {
			continue
		}
		// UIKit moves an existing child to the end, reconciling visual and hit-test order.
		macos.msg_void1(parent, 'addSubview:', native)
	}
}

fn native_create_element(el Element) View {
	return match el.kind {
		.screen { View(unsafe { nil }) }
		.view { new_native_view(el.frame, el.box.bg, el.box.radius) }
		.scroll { new_scroll_view(el.frame, el.box.bg, el.box.radius) }
		.label {
			new_label_view(el.frame, el.text, el.text_style.color, el.text_style.size, el.text_style.bold, align_value(el.text_style.align), el.text_style.lines)
		}
		.image { new_image_view(el.frame, el.image_path, el.rotation) }
		.button {
			new_button_view(el.frame, el.text, el.box.bg, el.text_style.color, el.text_style.size, el.text_style.bold, el.box.radius, el.text_style.lines)
		}
		.checkbox { new_checkbox_view(el) }
		.dropdown { new_dropdown_view(el) }
		.text_field {
			field := new_text_field_view(el.frame, el.placeholder, el.text, el.box.bg, el.text_style.color, el.text_style.size, el.box.radius, el.keyboard, el.secure)
			update_text_field_view(field, el.frame, el.placeholder, el.text, el.box.bg, el.text_style.color, el.text_style.size, el.box.radius, el.keyboard, el.secure, el.autocorrect, true, el.padding_left)
			field
		}
		.text_area { new_text_area_view(el) }
	}
}

fn native_update_element(native View, el Element, declared_text_changed bool) {
	match el.kind {
		.screen {}
		.view {
			macos.msg_void_rect(native, 'setFrame:', native_rect(el.frame))
			set_background(native, el.box.bg)
			set_corner_radius(native, el.box.radius)
		}
		.scroll {
			macos.msg_void_rect(native, 'setFrame:', native_rect(el.frame))
			set_background(native, el.box.bg)
			set_corner_radius(native, el.box.radius)
		}
		.label {
			update_label_view(native, el.frame, el.text, el.text_style.color, el.text_style.size, el.text_style.bold, align_value(el.text_style.align), el.text_style.lines)
		}
		.image { update_image_view(native, el.frame, el.image_path, el.rotation) }
		.button {
			update_button_view(native, el.frame, el.text, el.box.bg, el.text_style.color, el.text_style.size, el.text_style.bold, el.box.radius, el.text_style.lines)
		}
		.checkbox { update_checkbox_view(native, el) }
		.dropdown { update_dropdown_view(native, el, declared_text_changed) }
		.text_field {
			update_text_field_view(native, el.frame, el.placeholder, el.text, el.box.bg, el.text_style.color, el.text_style.size, el.box.radius, el.keyboard, el.secure, el.autocorrect, declared_text_changed, el.padding_left)
		}
		.text_area { update_text_area_view(native, el, declared_text_changed) }
	}
}

fn reparent_direct_children(key string, new_parent View) {
	prefix := key + '/'
	for child_key_, child in g_nodes {
		if child_key_.starts_with(prefix) && !child_key_[prefix.len..].contains('/') {
			macos.msg_void1(new_parent, 'addSubview:', child)
		}
	}
}

fn forget_descendant_nodes(key string) {
	prefix := key + '/'
	mut descendants := []string{}
	for child_key_, _ in g_nodes {
		if child_key_.starts_with(prefix) {
			descendants << child_key_
		}
	}
	for child_key_ in descendants {
		child := g_nodes[child_key_] or { continue }
		g_action_ids.delete(u64(child))
		g_text_change_ids.delete(u64(child))
		g_text_submit_ids.delete(u64(child))
		g_text_area_ids.delete(u64(child))
		g_view_translation_x.delete(voidptr(child))
		g_nodes.delete(child_key_)
		g_node_kinds.delete(child_key_)
		g_node_gestures.delete(child_key_)
		g_node_declared_text.delete(child_key_)
	}
}

fn register_native_handlers(native View, el Element) {
	pointer := u64(native)
	action_id := element_action_id(el)
	if action_id.len > 0 && el.kind in [.view, .button] && (el.long_press || el.swipe_left) {
		g_action_ids[pointer] = action_id
	}
	if el.kind in [.button, .checkbox] {
		remove_control_target_action(native, g_button_handler, 'handleTap:', 64)
		if action_id.len > 0 {
			g_action_ids[pointer] = action_id
			add_button_target(native, g_button_handler)
			macos.set_associated_object(native, assoc_handler_key(), g_button_handler, macos.assoc_retain_nonatomic)
		} else {
			macos.set_associated_object(native, assoc_handler_key(), View(unsafe { nil }), macos.assoc_retain_nonatomic)
		}
	} else if el.kind == .dropdown {
		remove_control_target_action(native, g_button_handler, 'handleTap:', 64)
		if action_id.len > 0 {
			g_action_ids[pointer] = action_id
			add_button_target(native, g_button_handler)
			macos.set_associated_object(native, assoc_handler_key(), g_button_handler, macos.assoc_retain_nonatomic)
		} else {
			macos.set_associated_object(native, assoc_handler_key(), View(unsafe { nil }), macos.assoc_retain_nonatomic)
		}
	} else if el.kind == .text_field {
		remove_control_target_action(native, g_button_handler, 'handleTextChange:', 131072)
		remove_control_target_action(native, g_button_handler, 'handleTextSubmit:', 524288)
		if el.emit_change && action_id.len > 0 {
			g_text_change_ids[pointer] = action_id
			add_control_target_action(native, g_button_handler, 'handleTextChange:', 131072)
		}
		if el.submit_id.len > 0 {
			g_text_submit_ids[pointer] = el.submit_id
			add_control_target_action(native, g_button_handler, 'handleTextSubmit:', 524288)
		}
		if (el.emit_change && action_id.len > 0) || el.submit_id.len > 0 {
			macos.set_associated_object(native, assoc_handler_key(), g_button_handler, macos.assoc_retain_nonatomic)
		} else {
			macos.set_associated_object(native, assoc_handler_key(), View(unsafe { nil }), macos.assoc_retain_nonatomic)
		}
	} else if el.kind == .text_area {
		if action_id.len > 0 {
			g_text_area_ids[pointer] = action_id
			macos.msg_void1(native, 'setDelegate:', g_button_handler)
		} else {
			macos.msg_void1(native, 'setDelegate:', View(unsafe { nil }))
		}
	}
}

fn render_element(parent View, el Element, key string, mut active map[string]bool) View {
	active[key] = true
	if el.kind == .screen {
		set_background(parent, el.box.bg)
		render_children(parent, el.children, key, mut active)
		return parent
	}
	mut native := g_nodes[key] or { View(unsafe { nil }) }
	existing_kind := g_node_kinds[key] or { Kind.screen }
	old_gestures := g_node_gestures[key] or { '' }
	new_gestures := gesture_signature(el)
	gesture_changed := existing_kind == el.kind && el.kind in [.view, .button]
		&& old_gestures != new_gestures
	created := native == unsafe { nil } || existing_kind != el.kind || gesture_changed
	declared_text_changed := key !in g_node_declared_text || (g_node_declared_text[key] or { '' }) != el.text
	if created {
		old_native := native
		can_reparent := old_native != unsafe { nil } && existing_kind in [.view, .scroll]
			&& el.kind in [.view, .scroll]
		native = native_create_element(el)
		g_nodes[key] = native
		g_node_kinds[key] = el.kind
		g_node_gestures[key] = new_gestures
		macos.msg_void1(parent, 'addSubview:', native)
		if can_reparent {
			reparent_direct_children(key, native)
		} else if old_native != unsafe { nil } {
			forget_descendant_nodes(key)
		}
		macos.release(native)
		if old_native != unsafe { nil } {
			g_view_translation_x.delete(voidptr(old_native))
			macos.msg_void(old_native, 'removeFromSuperview')
		}
		if el.long_press || el.swipe_left {
			attach_view_gestures(native, element_action_id(el), el.long_press, el.swipe_left)
		}
	} else {
		native_update_element(native, el, declared_text_changed)
	}

	match el.kind {
		.screen {}
		.view { render_children(native, el.children, key, mut active) }
		.scroll {
			render_children(native, el.children, key, mut active)
			mut content_h := f64(0)
			for child in el.children {
				bottom := child.frame.y + child.frame.height
				if bottom > content_h {
					content_h = bottom
				}
			}
			macos.msg_void_rect(native, 'setContentSize:', macos.rect(el.frame.width, content_h + 16, 0, 0))
			if el.id.len > 0 {
				if created && el.id in g_scroll_offsets {
					set_scroll_content_offset_y(native, g_scroll_offsets[el.id])
				}
				g_scroll_ids[el.id] = true
			}
		}
		else {}
	}

	register_native_handlers(native, el)
	native_apply_common_view_state(native, el.hidden, el.enabled, el.accessibility_role, el.accessibility_label, el.accessibility_value)
	if el.id.len > 0 {
		remember(el.id, native)
		g_view_kinds[el.id] = el.kind
	}
	g_node_declared_text[key] = el.text
	return native
}

fn remove_stale_nodes(active map[string]bool) {
	mut stale := []string{}
	mut stale_set := map[string]bool{}
	for key, _ in g_nodes {
		if key !in active {
			stale << key
			stale_set[key] = true
		}
	}
	for key in stale {
		native := g_nodes[key] or { continue }
		if !node_has_ancestor_in_set(key, stale_set) {
			macos.msg_void(native, 'removeFromSuperview')
		}
		g_action_ids.delete(u64(native))
		g_text_change_ids.delete(u64(native))
		g_text_submit_ids.delete(u64(native))
		g_text_area_ids.delete(u64(native))
		g_view_translation_x.delete(voidptr(native))
		g_nodes.delete(key)
		g_node_kinds.delete(key)
		g_node_gestures.delete(key)
		g_node_declared_text.delete(key)
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

// ── App lifecycle ──────────────────────────────────────────────────

@[export: 'vui_app_did_finish_launching']
fn vui_app_did_finish_launching(self voidptr, _cmd voidptr, _application voidptr, _launch_options voidptr) bool {
	b := bounds()
	g_window = macos.msg_id_rect(macos.alloc('UIWindow'), 'initWithFrame:', macos.rect(b.x, b.y, b.width, b.height))
	g_root_vc = macos.msg_id(macos.alloc('UIViewController'), 'init')
	g_root_view = macos.msg_id(g_root_vc, 'view')
	if g_button_handler == unsafe { nil } {
		g_button_handler = macos.msg_id(macos.alloc('VuiButtonHandler'), 'init')
	}
	if g_long_press_handler == unsafe { nil } {
		g_long_press_handler = macos.msg_id(macos.alloc('VuiLongPressHandler'), 'init')
	}
	if g_swipe_handler == unsafe { nil } {
		g_swipe_handler = macos.msg_id(macos.alloc('VuiSwipeHandler'), 'init')
	}
	macos.msg_void1(g_window, 'setRootViewController:', g_root_vc)
	macos.msg_void(g_window, 'makeKeyAndVisible')
	macos.set_associated_object(View(self), assoc_window_key(), g_window, macos.assoc_retain_nonatomic)
	refresh()
	return true
}

// ── Event handlers ─────────────────────────────────────────────────

@[export: 'vui_button_tap']
fn vui_button_tap(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	id := g_action_ids[u64(sender)] or { return }
	g_event_handler(id)
}

@[export: 'vui_text_field_changed']
fn vui_text_field_changed(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	id := g_text_change_ids[u64(sender)] or { return }
	g_event_handler(id)
}

@[export: 'vui_text_field_submitted']
fn vui_text_field_submitted(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	id := g_text_submit_ids[u64(sender)] or { return }
	g_event_handler(id)
}

@[export: 'vui_text_view_changed']
fn vui_text_view_changed(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	id := g_text_area_ids[u64(sender)] or { return }
	g_event_handler(id)
}

@[export: 'vui_button_long_press']
fn vui_button_long_press(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	if gesture_state(View(sender)) != gesture_state_began {
		return
	}
	view := gesture_view(View(sender))
	id := g_action_ids[u64(view)] or { return }
	g_event_handler('long:' + id)
}

@[export: 'vui_swipe_left']
fn vui_swipe_left(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	gesture := View(sender)
	view := gesture_view(gesture)
	id := g_action_ids[u64(view)] or { return }
	state := gesture_state(gesture)
	x := pan_translation_x(gesture, view)
	if state == gesture_state_began || state == gesture_state_changed {
		mut shift := x
		if shift > 0 {
			shift = 0
		}
		if shift < -swipe_max_translation {
			shift = -swipe_max_translation
		}
		set_view_translation_x(view, shift)
		return
	}
	if state == gesture_state_ended {
		if x < -swipe_delete_threshold {
			set_view_translation_x(view, -swipe_max_translation)
			g_event_handler('swipe_left:' + id)
		} else {
			set_view_translation_x(view, 0)
		}
		return
	}
	if state == gesture_state_cancelled || state == gesture_state_failed {
		set_view_translation_x(view, 0)
		return
	}
	set_view_translation_x(view, 0)
}

@[export: 'vui_swipe_should_begin']
fn vui_swipe_should_begin(_self voidptr, _cmd voidptr, sender voidptr) bool {
	gesture := View(sender)
	view := gesture_view(gesture)
	tx := pan_translation_x(gesture, view)
	ty := pan_translation_y(gesture, view)
	vx := pan_velocity_x(gesture, view)
	vy := pan_velocity_y(gesture, view)
	abs_tx := if tx < 0 { -tx } else { tx }
	abs_ty := if ty < 0 { -ty } else { ty }
	abs_vx := if vx < 0 { -vx } else { vx }
	abs_vy := if vy < 0 { -vy } else { vy }
	return (tx < 0 && abs_tx > abs_ty) || (vx < 0 && abs_vx > abs_vy)
}

@[export: 'vui_swipe_should_recognize_simultaneously']
fn vui_swipe_should_recognize_simultaneously(_self voidptr, _cmd voidptr, _sender voidptr, _other voidptr) bool {
	return true
}
