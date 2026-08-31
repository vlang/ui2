module ui2

import macos
import ios

#insert "@DIR/native_bridge.h"

fn C.vui_app_did_finish_launching(self voidptr, cmd voidptr, application voidptr, launch_options voidptr) bool
fn C.vui_button_tap(self voidptr, cmd voidptr, sender voidptr)
fn C.vui_text_field_changed(self voidptr, cmd voidptr, sender voidptr)
fn C.vui_text_field_submitted(self voidptr, cmd voidptr, sender voidptr)
fn C.vui_button_long_press(self voidptr, cmd voidptr, sender voidptr)
fn C.vui_swipe_left(self voidptr, cmd voidptr, sender voidptr)
fn C.vui_swipe_should_begin(self voidptr, cmd voidptr, sender voidptr) bool
fn C.vui_swipe_should_recognize_simultaneously(self voidptr, cmd voidptr, sender voidptr, other voidptr) bool
fn C.vui_present_barcode_scanner(root voidptr)

const swipe_delete_threshold = f64(72)
const swipe_max_translation = f64(140)

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

__global g_build_screen = BuildFn(unsafe { nil })
__global g_event_handler = EventFn(unsafe { nil })
__global g_window = View(unsafe { nil })
__global g_root_vc = View(unsafe { nil })
__global g_root_view = View(unsafe { nil })
__global g_button_handler = View(unsafe { nil })
__global g_long_press_handler = View(unsafe { nil })
__global g_swipe_handler = View(unsafe { nil })
__global g_views = map[string]View{}
__global g_button_ids = []string{}
__global g_text_change_ids = map[u64]string{}
__global g_text_submit_ids = map[u64]string{}
__global g_scroll_ids = map[string]bool{}
__global g_scroll_offsets = map[string]f64{}
__global g_view_translation_x = map[voidptr]f64{}

// ── Public API ─────────────────────────────────────────────────────

pub fn bounds() Rect {
	b := macos.msg_rect(macos.msg_id(macos.get_class('UIScreen'), 'mainScreen'), 'bounds')
	return Rect{
		x:      b.x
		y:      b.y
		width:  b.width
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
	ns_text := macos.msg_id(view, 'text')
	return macos.utf8_string(ns_text)
}

pub fn set_text(id string, t string) {
	if id in g_views {
		view := g_views[id] or { return }
		macos.msg_void1(view, 'setText:', macos.nsstring(t))
	}
}

pub fn focus(id string) {
	view := g_views[id] or { return }
	macos.msg_bool(view, 'becomeFirstResponder')
}

pub fn focused_text_area_id() string {
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
	C.vui_present_barcode_scanner(g_root_vc)
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

fn set_tag(view View, tag int) {
	macos.msg_void_i64(view, 'setTag:', i64(tag))
}

fn get_tag(view View) int {
	return int(macos.msg_i64(view, 'tag'))
}

fn add_button_target(btn View, target View) {
	macos.msg_void3(btn, 'addTarget:action:forControlEvents:', target, macos.sel('handleTap:'),
		macos.Id(usize(64)))
}

fn add_control_target_action(control View, target View, action string, event_mask u64) {
	macos.msg_void3(control, 'addTarget:action:forControlEvents:', target, macos.sel(action),
		macos.Id(usize(event_mask)))
}

fn add_long_press_target(view View, target View) {
	recognizer := macos.msg_id2(macos.alloc('UILongPressGestureRecognizer'),
		'initWithTarget:action:', target, macos.sel('handleLongPress:'))
	macos.msg_void_f64(recognizer, 'setMinimumPressDuration:', 0.45)
	macos.msg_void1(view, 'addGestureRecognizer:', recognizer)
}

fn add_swipe_left_target(view View, target View) {
	recognizer := macos.msg_id2(macos.alloc('UIPanGestureRecognizer'), 'initWithTarget:action:',
		target, macos.sel('handleSwipe:'))
	macos.msg_void_bool(recognizer, 'setCancelsTouchesInView:', false)
	macos.msg_void1(recognizer, 'setDelegate:', target)
	macos.msg_void1(view, 'addGestureRecognizer:', recognizer)
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

fn new_native_view(frame Rect, bg_hex u32) View {
	view := macos.msg_id_rect(macos.alloc('UIView'), 'initWithFrame:', native_rect(frame))
	set_background(view, bg_hex)
	return view
}

fn new_scroll_view(frame Rect, bg_hex u32) View {
	scroll := macos.msg_id_rect(macos.alloc('UIScrollView'), 'initWithFrame:', native_rect(frame))
	set_background(scroll, bg_hex)
	macos.msg_void_bool(scroll, 'setAlwaysBounceVertical:', true)
	macos.msg_void_i64(scroll, 'setKeyboardDismissMode:', 1)
	macos.msg_void_i64(scroll, 'setContentInsetAdjustmentBehavior:', 2)
	return scroll
}

fn new_label_view(frame Rect, t string, text_hex u32, size f64, bold bool, align int, lines int) View {
	lbl := macos.msg_id_rect(macos.alloc('UILabel'), 'initWithFrame:', native_rect(frame))
	macos.msg_void1(lbl, 'setText:', macos.nsstring(t))
	macos.msg_void1(lbl, 'setTextColor:', ios.color(text_hex))
	macos.msg_void1(lbl, 'setFont:', font(size, bold))
	macos.msg_void_i64(lbl, 'setTextAlignment:', i64(align))
	macos.msg_void_i64(lbl, 'setNumberOfLines:', i64(lines))
	macos.msg_void_i64(lbl, 'setLineBreakMode:', 4)
	return lbl
}

fn new_button_view(frame Rect, title string, bg_hex u32, text_hex u32, size f64, bold bool, radius f64, lines int) View {
	btn := macos.msg_id_u64(macos.get_class('UIButton'), 'buttonWithType:', u64(0))
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
	return btn
}

fn new_text_field_view(frame Rect, placeholder string, t string, bg_hex u32, text_hex u32, size f64, radius f64, keyboard int, secure bool) View {
	field := macos.msg_id_rect(macos.alloc('UITextField'), 'initWithFrame:', native_rect(frame))
	set_background(field, bg_hex)
	macos.msg_void1(field, 'setTextColor:', ios.color(text_hex))
	macos.msg_void1(field, 'setFont:', font(size, false))
	macos.msg_void1(field, 'setPlaceholder:', macos.nsstring(placeholder))
	macos.msg_void1(field, 'setText:', macos.nsstring(t))
	macos.msg_void_i64(field, 'setKeyboardType:', i64(keyboard))
	macos.msg_void_bool(field, 'setSecureTextEntry:', secure)
	macos.msg_void_i64(field, 'setClearButtonMode:', 1)
	set_corner_radius(field, radius)
	pad := macos.msg_id_rect(macos.alloc('UIView'), 'initWithFrame:', macos.rect(0, 0, 12,
		frame.height))
	macos.msg_void1(field, 'setLeftView:', pad)
	macos.msg_void_i64(field, 'setLeftViewMode:', 3)
	macos.release(pad)
	return field
}

fn remove_all_subviews(view View) {
	g_view_translation_x = map[voidptr]f64{}
	if view == unsafe { nil } {
		return
	}
	subviews := macos.msg_id(macos.msg_id(view, 'subviews'), 'copy')
	defer {
		macos.release(subviews)
	}
	count := int(macos.msg_u64(subviews, 'count'))
	for i in 0 .. count {
		subview := macos.msg_id_u64(subviews, 'objectAtIndex:', u64(i))
		macos.msg_void(subview, 'removeFromSuperview')
	}
}

// ── Runtime class registration ─────────────────────────────────────

fn ensure_runtime_classes() {
	if macos.get_class('VuiAppDelegate') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('UIResponder'), 'VuiAppDelegate')
		macos.add_protocol(cls, macos.get_protocol('UIApplicationDelegate'))
		macos.add_method(cls, 'application:didFinishLaunchingWithOptions:',
			voidptr(C.vui_app_did_finish_launching), 'B@:@@')
		macos.register_class_pair(cls)
	}
	if macos.get_class('VuiButtonHandler') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'VuiButtonHandler')
		macos.add_method(cls, 'handleTap:', voidptr(C.vui_button_tap), 'v@:@')
		macos.add_method(cls, 'handleTextChange:', voidptr(C.vui_text_field_changed), 'v@:@')
		macos.add_method(cls, 'handleTextSubmit:', voidptr(C.vui_text_field_submitted), 'v@:@')
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
		macos.add_method(cls, 'gestureRecognizerShouldBegin:', voidptr(C.vui_swipe_should_begin),
			'B@:@')
		macos.add_method(cls,
			'gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:',
			voidptr(C.vui_swipe_should_recognize_simultaneously), 'B@:@@')
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
	remember_scroll_offsets()
	remove_all_subviews(g_root_view)
	g_views = map[string]View{}
	g_button_ids = []string{}
	g_text_change_ids = map[u64]string{}
	g_text_submit_ids = map[u64]string{}
	g_scroll_ids = map[string]bool{}
	set_background(g_root_view, root.box.bg)
	for child in root.children {
		render_element(g_root_view, child)
	}
}

fn attach_view_gestures(native View, id string, long_press bool, swipe_left bool) {
	if id.len == 0 {
		return
	}
	tag := g_button_ids.len
	g_button_ids << id
	set_tag(native, tag)
	if long_press {
		add_long_press_target(native, g_long_press_handler)
		macos.set_associated_object(native, assoc_long_handler_key(), g_long_press_handler,
			macos.assoc_retain_nonatomic)
	}
	if swipe_left {
		add_swipe_left_target(native, g_swipe_handler)
		macos.set_associated_object(native, assoc_swipe_handler_key(), g_swipe_handler,
			macos.assoc_retain_nonatomic)
	}
}

fn render_element(parent View, el Element) View {
	mut native := View(unsafe { nil })
	match el.kind {
		.screen {
			native = parent
		}
		.view {
			native = new_native_view(el.frame, el.box.bg)
			if el.box.radius > 0 {
				set_corner_radius(native, el.box.radius)
			}
			if el.long_press || el.swipe_left {
				attach_view_gestures(native, el.id, el.long_press, el.swipe_left)
			}
			macos.msg_void1(parent, 'addSubview:', native)
			for child in el.children {
				render_element(native, child)
			}
		}
		.scroll {
			native = new_scroll_view(el.frame, el.box.bg)
			macos.msg_void1(parent, 'addSubview:', native)
			mut content_h := f64(0)
			for child in el.children {
				render_element(native, child)
				bottom := child.frame.y + child.frame.height
				if bottom > content_h {
					content_h = bottom
				}
			}
			macos.msg_void_rect(native, 'setContentSize:', macos.rect(el.frame.width,
				content_h + 16, 0, 0))
			if el.id.len > 0 {
				if el.id in g_scroll_offsets {
					set_scroll_content_offset_y(native, g_scroll_offsets[el.id])
				}
				g_scroll_ids[el.id] = true
			}
		}
		.label {
			native = new_label_view(el.frame, el.text, el.text_style.color, el.text_style.size,
				el.text_style.bold, align_value(el.text_style.align), el.text_style.lines)
			macos.msg_void1(parent, 'addSubview:', native)
		}
		.image {
			native = new_native_view(el.frame, 0xe8ecef)
			macos.msg_void1(parent, 'addSubview:', native)
		}
		.button {
			native = new_button_view(el.frame, el.text, el.box.bg, el.text_style.color,
				el.text_style.size, el.text_style.bold, el.box.radius, el.text_style.lines)
			tag := g_button_ids.len
			g_button_ids << el.id
			set_tag(native, tag)
			add_button_target(native, g_button_handler)
			macos.set_associated_object(native, assoc_handler_key(), g_button_handler,
				macos.assoc_retain_nonatomic)
			if el.long_press {
				add_long_press_target(native, g_long_press_handler)
				macos.set_associated_object(native, assoc_long_handler_key(), g_long_press_handler,
					macos.assoc_retain_nonatomic)
			}
			macos.msg_void1(parent, 'addSubview:', native)
		}
		.text_field {
			native = new_text_field_view(el.frame, el.placeholder, el.text, el.box.bg,
				el.text_style.color, el.text_style.size, el.box.radius, el.keyboard, el.secure)
			pointer := u64(native)
			if el.emit_change {
				g_text_change_ids[pointer] = el.id
				add_control_target_action(native, g_button_handler, 'handleTextChange:', 131072)
			}
			if el.submit_id.len > 0 {
				g_text_submit_ids[pointer] = el.submit_id
				add_control_target_action(native, g_button_handler, 'handleTextSubmit:', 524288)
			}
			if el.emit_change || el.submit_id.len > 0 {
				macos.set_associated_object(native, assoc_handler_key(), g_button_handler,
					macos.assoc_retain_nonatomic)
			}
			macos.msg_void1(parent, 'addSubview:', native)
		}
	}

	remember(el.id, native)
	return native
}

// ── App lifecycle ──────────────────────────────────────────────────

@[export: 'vui_app_did_finish_launching']
fn vui_app_did_finish_launching(self voidptr, _cmd voidptr, _application voidptr, _launch_options voidptr) bool {
	b := bounds()
	g_window = macos.msg_id_rect(macos.alloc('UIWindow'), 'initWithFrame:', macos.rect(b.x, b.y,
		b.width, b.height))
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
	macos.set_associated_object(View(self), assoc_window_key(), g_window,
		macos.assoc_retain_nonatomic)
	refresh()
	return true
}

// ── Event handlers ─────────────────────────────────────────────────

@[export: 'vui_button_tap']
fn vui_button_tap(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	tag := get_tag(View(sender))
	if tag < 0 || tag >= g_button_ids.len {
		return
	}
	g_event_handler(g_button_ids[tag])
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

@[export: 'vui_button_long_press']
fn vui_button_long_press(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	if gesture_state(View(sender)) != 1 {
		return
	}
	view := gesture_view(View(sender))
	tag := get_tag(view)
	if tag < 0 || tag >= g_button_ids.len {
		return
	}
	g_event_handler('long:' + g_button_ids[tag])
}

@[export: 'vui_swipe_left']
fn vui_swipe_left(_self voidptr, _cmd voidptr, sender voidptr) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	gesture := View(sender)
	view := gesture_view(gesture)
	tag := get_tag(view)
	if tag < 0 || tag >= g_button_ids.len {
		return
	}
	state := gesture_state(gesture)
	x := pan_translation_x(gesture, view)
	if state == 1 || state == 2 {
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
	if state == 3 || state == 4 {
		if x < -swipe_delete_threshold {
			set_view_translation_x(view, -swipe_max_translation)
			g_event_handler('swipe_left:' + g_button_ids[tag])
		} else {
			set_view_translation_x(view, 0)
		}
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

// ── Barcode scanner callbacks ──────────────────────────────────────

fn cstring_to_v(value &char) string {
	if value == unsafe { nil } {
		return ''
	}
	return unsafe { value.vstring().clone() }
}

@[export: 'vui_barcode_scanned']
fn vui_barcode_scanned(code &char) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	g_event_handler('scan_code:' + cstring_to_v(code))
}

@[export: 'vui_barcode_error']
fn vui_barcode_error(message &char) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	g_event_handler('scan_error:' + cstring_to_v(message))
}

@[export: 'vui_barcode_cancelled']
fn vui_barcode_cancelled() {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	g_event_handler('scan_cancelled')
}
