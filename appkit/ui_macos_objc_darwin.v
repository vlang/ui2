// vfmt off
module ui2

$if !ui2_custom_rendering ? {

import macos
import math

type VoidCallback = fn ()

@[inline]
fn objc_nil() macos.Id {
	return unsafe { nil }
}

@[inline]
fn objc_is_nil(object macos.Id) bool {
	return object == unsafe { nil }
}

@[inline]
fn objc_autorelease(object macos.Id) macos.Id {
	if objc_is_nil(object) {
		return object
	}
	return macos.msg_id(object, 'autorelease')
}

@[inline]
fn objc_number_i64(value i64) macos.Id {
	return macos.msg_id_u64(macos.get_class('NSNumber'), 'numberWithLongLong:', u64(value))
}

@[inline]
fn objc_number_f64(value f64) macos.Id {
	return macos.msg_id_f64(macos.get_class('NSNumber'), 'numberWithDouble:', value)
}

fn objc_array(values []macos.Id) macos.Id {
	array := macos.msg_id(macos.alloc('NSMutableArray'), 'init')
	for value in values {
		if !objc_is_nil(value) {
			macos.msg_void1(array, 'addObject:', value)
		}
	}
	return objc_autorelease(array)
}

fn objc_empty_dictionary() macos.Id {
	return macos.msg_id(macos.get_class('NSDictionary'), 'dictionary')
}

fn objc_mutable_dictionary() macos.Id {
	return macos.msg_id(macos.alloc('NSMutableDictionary'), 'init')
}

@[inline]
fn objc_dict_get(dictionary macos.Id, key string) macos.Id {
	if objc_is_nil(dictionary) {
		return objc_nil()
	}
	return macos.msg_id1(dictionary, 'objectForKey:', macos.nsstring(key))
}

@[inline]
fn objc_dict_set(dictionary macos.Id, key string, value macos.Id) {
	if !objc_is_nil(dictionary) && !objc_is_nil(value) {
		macos.msg_void2(dictionary, 'setObject:forKey:', value, macos.nsstring(key))
	}
}

@[inline]
fn objc_dict_remove(dictionary macos.Id, key string) {
	if !objc_is_nil(dictionary) {
		macos.msg_void1(dictionary, 'removeObjectForKey:', macos.nsstring(key))
	}
}

fn objc_mutable_copy_or_dictionary(dictionary macos.Id) macos.Id {
	if !objc_is_nil(dictionary) {
		copied := macos.msg_id(dictionary, 'mutableCopy')
		if !objc_is_nil(copied) {
			return copied
		}
	}
	return objc_mutable_dictionary()
}

@[heap]
struct NativeMacosHelperState {
mut:
	colors                  map[u32]macos.Id
	fonts                   map[string]macos.Id
	accessibility_role_key  u8
	accessibility_label_key u8
	accessibility_value_key u8
	dispatcher              macos.Id
}

const native_macos_helper_state = &NativeMacosHelperState{
	colors: map[u32]macos.Id{}
	fonts: map[string]macos.Id{}
}

fn native_macos_helpers() &NativeMacosHelperState {
	return unsafe { native_macos_helper_state }
}

fn native_color_from_hex(hex u32) macos.Id {
	mut helpers := native_macos_helpers()
	if cached := helpers.colors[hex] {
		return cached
	}
	r := f64((hex >> 16) & 0xff) / 255.0
	g := f64((hex >> 8) & 0xff) / 255.0
	b := f64(hex & 0xff) / 255.0
	color := macos.msg_id_four_f64(macos.get_class('NSColor'), 'colorWithCalibratedRed:green:blue:alpha:', r, g, b, 1.0)
	if !objc_is_nil(color) {
		helpers.colors[hex] = macos.retain(color)
	}
	return color
}

fn native_color_hex(color macos.Id, fallback u32) u32 {
	if objc_is_nil(color) {
		return fallback
	}
	space := macos.msg_id(macos.get_class('NSColorSpace'), 'deviceRGBColorSpace')
	rgb := macos.msg_id1(color, 'colorUsingColorSpace:', space)
	if objc_is_nil(rgb) {
		return fallback
	}
	r := u32(math.round(math.min(math.max(macos.msg_f64(rgb, 'redComponent'), 0.0), 1.0) * 255.0))
	g := u32(math.round(math.min(math.max(macos.msg_f64(rgb, 'greenComponent'), 0.0), 1.0) * 255.0))
	b := u32(math.round(math.min(math.max(macos.msg_f64(rgb, 'blueComponent'), 0.0), 1.0) * 255.0))
	return (r << 16) | (g << 8) | b
}

fn native_font_object(size f64, bold bool, italic bool) macos.Id {
	mut helpers := native_macos_helpers()
	key := '${size}:${bold}:${italic}'
	if cached := helpers.fonts[key] {
		return cached
	}
	font_class := macos.get_class('NSFont')
	mut font := macos.msg_id_f64(font_class, if bold { 'boldSystemFontOfSize:' } else { 'systemFontOfSize:' }, size)
	if italic && !objc_is_nil(font) {
		manager := macos.msg_id(macos.get_class('NSFontManager'), 'sharedFontManager')
		converted := macos.msg_id_id_u64(manager, 'convertFont:toHaveTrait:', font, u64(1))
		if !objc_is_nil(converted) {
			font = converted
		}
	}
	if !objc_is_nil(font) {
		helpers.fonts[key] = macos.retain(font)
	}
	return font
}

fn native_image_from_name(name string) macos.Id {
	if name.len == 0 {
		return objc_nil()
	}
	ns_name := macos.nsstring(name)
	if name.starts_with('symbol:') {
		symbol_name := macos.nsstring(name['symbol:'.len..])
		image_class := macos.get_class('NSImage')
		if macos.responds_to(image_class, 'imageWithSystemSymbolName:accessibilityDescription:') {
			symbol_image := macos.msg_id2(image_class, 'imageWithSystemSymbolName:accessibilityDescription:', symbol_name, objc_nil())
			if !objc_is_nil(symbol_image) {
				return symbol_image
			}
		}
	}
	file_image := macos.msg_id1(macos.alloc('NSImage'), 'initWithContentsOfFile:', ns_name)
	if !objc_is_nil(file_image) {
		return objc_autorelease(file_image)
	}
	return macos.msg_id1(macos.get_class('NSImage'), 'imageNamed:', ns_name)
}

fn native_image_from_name_sized(name string, width f64, height f64) macos.Id {
	source_image := native_image_from_name(name)
	if objc_is_nil(source_image) {
		return source_image
	}
	sized := objc_autorelease(macos.msg_id(source_image, 'copy'))
	macos.msg_void_point(sized, 'setSize:', macos.point(width, height))
	macos.msg_void_bool(sized, 'setTemplate:', macos.msg_bool(source_image, 'isTemplate'))
	return sized
}

fn native_utf16_length(text string) u64 {
	return macos.msg_u64(macos.nsstring(text), 'length')
}

fn native_cursor(name string) macos.Id {
	cursor_class := macos.get_class('NSCursor')
	return match name {
		'pointing_hand' { macos.msg_id(cursor_class, 'pointingHandCursor') }
		'resize_nwse' { native_private_cursor('_windowResizeNorthWestSouthEastCursor', macos.msg_id(cursor_class, 'crosshairCursor')) }
		'resize_nesw' { native_private_cursor('_windowResizeNorthEastSouthWestCursor', macos.msg_id(cursor_class, 'crosshairCursor')) }
		'resize_ew' { macos.msg_id(cursor_class, 'resizeLeftRightCursor') }
		'resize_ns' { macos.msg_id(cursor_class, 'resizeUpDownCursor') }
		'rotate' { macos.msg_id(cursor_class, 'openHandCursor') }
		else { macos.msg_id(cursor_class, 'arrowCursor') }
	}
}

fn native_private_cursor(selector string, fallback macos.Id) macos.Id {
	cursor_class := macos.get_class('NSCursor')
	if macos.responds_to(cursor_class, selector) {
		cursor := macos.msg_id(cursor_class, selector)
		if !objc_is_nil(cursor) {
			return cursor
		}
	}
	return fallback
}

fn native_add_cursor_rect(view macos.Id, name string) {
	if objc_is_nil(view) {
		return
	}
	macos.msg_void_rect_id(view, 'addCursorRect:cursor:', macos.msg_rect(view, 'bounds'), native_cursor(name))
}

fn objc_invalidate_cursor_rects(view macos.Id) {
	if objc_is_nil(view) {
		return
	}
	window := macos.msg_id(view, 'window')
	if !objc_is_nil(window) {
		macos.msg_void1(window, 'invalidateCursorRectsForView:', view)
	}
}

fn objc_place_subview(parent macos.Id, child macos.Id, previous macos.Id) {
	if objc_is_nil(parent) || objc_is_nil(child) {
		return
	}
	position := if objc_is_nil(previous) { i64(-1) } else { i64(1) }
	macos.msg_void_id_i64_id(parent, 'addSubview:positioned:relativeTo:', child, position, previous)
}

fn native_accessibility_role(role string) macos.Id {
	return match role {
		'' { objc_nil() }
		'button' { macos.nsstring('AXButton') }
		'text', 'label' { macos.nsstring('AXStaticText') }
		'text_field' { macos.nsstring('AXTextField') }
		'image' { macos.nsstring('AXImage') }
		'link' { macos.nsstring('AXLink') }
		'slider' { macos.nsstring('AXSlider') }
		else { macos.nsstring(role) }
	}
}

fn native_saved_accessibility_value(value macos.Id) macos.Id {
	return if objc_is_nil(value) { macos.msg_id(macos.get_class('NSNull'), 'null') } else { value }
}

fn native_restored_accessibility_value(value macos.Id) macos.Id {
	null_value := macos.msg_id(macos.get_class('NSNull'), 'null')
	return if value == null_value { objc_nil() } else { value }
}

fn native_apply_accessibility_value(view macos.Id, raw string, getter string, setter string, key voidptr) {
	value := if raw.len == 0 { objc_nil() } else { macos.nsstring(raw) }
	saved := macos.get_associated_object(view, key)
	if !objc_is_nil(value) {
		if objc_is_nil(saved) {
			macos.set_associated_object(view, key, native_saved_accessibility_value(macos.msg_id(view, getter)), macos.assoc_retain_nonatomic)
		}
		macos.msg_void1(view, setter, value)
	} else if !objc_is_nil(saved) {
		macos.msg_void1(view, setter, native_restored_accessibility_value(saved))
		macos.set_associated_object(view, key, objc_nil(), macos.assoc_retain_nonatomic)
	}
}

fn native_apply_common_view_state(view macos.Id, hidden bool, enabled bool, role string, label string, value string) {
	if objc_is_nil(view) {
		return
	}
	macos.msg_void_bool(view, 'setHidden:', hidden)
	if macos.responds_to(view, 'setEnabled:') {
		macos.msg_void_bool(view, 'setEnabled:', enabled)
	}
	mut helpers := native_macos_helpers()
	role_key := voidptr(&helpers.accessibility_role_key)
	saved_role := macos.get_associated_object(view, role_key)
	native_role := native_accessibility_role(role)
	if !objc_is_nil(native_role) {
		if objc_is_nil(saved_role) {
			macos.set_associated_object(view, role_key, native_saved_accessibility_value(macos.msg_id(view, 'accessibilityRole')), macos.assoc_retain_nonatomic)
		}
		macos.msg_void1(view, 'setAccessibilityRole:', native_role)
	} else if !objc_is_nil(saved_role) {
		macos.msg_void1(view, 'setAccessibilityRole:', native_restored_accessibility_value(saved_role))
		macos.set_associated_object(view, role_key, objc_nil(), macos.assoc_retain_nonatomic)
	}
	native_apply_accessibility_value(view, label, 'accessibilityLabel', 'setAccessibilityLabel:', voidptr(&helpers.accessibility_label_key))
	native_apply_accessibility_value(view, value, 'accessibilityValue', 'setAccessibilityValue:', voidptr(&helpers.accessibility_value_key))
}

fn objc_clear_control_state(control macos.Id) {
	if objc_is_nil(control) || !macos.msg_bool_id(control, 'isKindOfClass:', macos.get_class('NSButton')) {
		return
	}
	macos.msg_void_i64(control, 'setState:', 0)
	macos.msg_void_bool(control, 'highlight:', false)
}

fn native_control_is_editing(control macos.Id) bool {
	return !objc_is_nil(control) && !objc_is_nil(macos.msg_id(control, 'currentEditor'))
}

fn native_control_selected_range(control macos.Id) macos.Range {
	if objc_is_nil(control) {
		return macos.range(0, 0)
	}
	editor := macos.msg_id(control, 'currentEditor')
	return if objc_is_nil(editor) { macos.range(0, 0) } else { macos.msg_range(editor, 'selectedRange') }
}

fn native_focus_view(view macos.Id) bool {
	if objc_is_nil(view) {
		return false
	}
	window := macos.msg_id(view, 'window')
	return !objc_is_nil(window) && macos.msg_bool_id(window, 'makeFirstResponder:', view)
}

fn native_restore_control_selection(control macos.Id, location u64, length u64) {
	if objc_is_nil(control) || !native_focus_view(control) {
		return
	}
	text_length := macos.msg_u64(macos.msg_id(control, 'stringValue'), 'length')
	safe_location := if location < text_length { location } else { text_length }
	safe_length := if length < text_length - safe_location { length } else { text_length - safe_location }
	macos.msg_void_range(macos.msg_id(control, 'currentEditor'), 'setSelectedRange:', macos.range(safe_location, safe_length))
}

fn native_end_window_editing(window macos.Id) {
	if !objc_is_nil(window) {
		macos.msg_void1(window, 'makeFirstResponder:', objc_nil())
	}
}

fn native_register_drop_types(view macos.Id) {
	if !objc_is_nil(view) {
		macos.msg_void1(view, 'registerForDraggedTypes:', objc_array([macos.nsstring('public.file-url'), macos.nsstring('public.utf8-plain-text')]))
	}
}

fn native_dragging_pasteboard(info macos.Id) macos.Id {
	return if objc_is_nil(info) { objc_nil() } else { macos.msg_id(info, 'draggingPasteboard') }
}

fn native_dragging_file_urls(info macos.Id) macos.Id {
	pasteboard := native_dragging_pasteboard(info)
	if objc_is_nil(pasteboard) {
		return objc_array([]macos.Id{})
	}
	options := objc_mutable_dictionary()
	objc_dict_set(options, 'NSPasteboardURLReadingFileURLsOnlyKey', objc_number_i64(1))
	urls := macos.msg_id2(pasteboard, 'readObjectsForClasses:options:', objc_array([macos.get_class('NSURL')]), options)
	macos.release(options)
	return if objc_is_nil(urls) { objc_array([]macos.Id{}) } else { urls }
}

fn native_dragging_file_paths(info macos.Id, limit int) []string {
	urls := native_dragging_file_urls(info)
	available := int(macos.msg_u64(urls, 'count'))
	count := if available < limit { available } else { limit }
	mut paths := []string{cap: count}
	for index in 0 .. count {
		url := macos.msg_id_u64(urls, 'objectAtIndex:', u64(index))
		path := macos.utf8_string(macos.msg_id(url, 'path'))
		if path.len > 0 {
			paths << path
		}
	}
	return paths
}

fn native_dragging_text(info macos.Id) string {
	pasteboard := native_dragging_pasteboard(info)
	if objc_is_nil(pasteboard) {
		return ''
	}
	return macos.utf8_string(macos.msg_id1(pasteboard, 'stringForType:', macos.nsstring('public.utf8-plain-text')))
}

fn native_dragging_point(view macos.Id, info macos.Id) macos.Point {
	if objc_is_nil(view) || objc_is_nil(info) {
		return macos.point(0, 0)
	}
	return macos.msg_point_point_id(view, 'convertPoint:fromView:', macos.msg_point(info, 'draggingLocation'), objc_nil())
}

fn native_event_point(view macos.Id, event macos.Id) macos.Point {
	if objc_is_nil(view) || objc_is_nil(event) {
		return macos.point(0, 0)
	}
	return macos.msg_point_point_id(view, 'convertPoint:fromView:', macos.msg_point(event, 'locationInWindow'), objc_nil())
}

fn native_current_event_modifier_flags() u64 {
	event := macos.msg_id(native_current_app(), 'currentEvent')
	return if objc_is_nil(event) { u64(0) } else { macos.msg_u64(event, 'modifierFlags') }
}

fn native_app_send_edit_command(command int) bool {
	action := match command {
		0 { 'selectAll:' }
		1 { 'cut:' }
		2 { 'copy:' }
		3 { 'paste:' }
		4 { 'undo:' }
		5 { 'redo:' }
		else { return false }
	}
	return macos.msg_bool_sel_id_id(native_current_app(), 'sendAction:to:from:', macos.sel(action), objc_nil(), objc_nil())
}

fn native_pasteboard_image() macos.Id {
	pasteboard := macos.msg_id(macos.get_class('NSPasteboard'), 'generalPasteboard')
	objects := macos.msg_id2(pasteboard, 'readObjectsForClasses:options:', objc_array([macos.get_class('NSImage')]), objc_empty_dictionary())
	if objc_is_nil(objects) || macos.msg_u64(objects, 'count') == 0 {
		return objc_nil()
	}
	return macos.msg_id_u64(objects, 'objectAtIndex:', 0)
}

fn native_pasteboard_has_image() bool {
	return !objc_is_nil(native_pasteboard_image())
}

fn native_png_data(bitmap macos.Id) macos.Id {
	return macos.msg_id_u64_id(bitmap, 'representationUsingType:properties:', 4, objc_empty_dictionary())
}

fn native_write_data(data macos.Id, path string) bool {
	return !objc_is_nil(data) && macos.msg_u64(data, 'length') > 0 && macos.msg_bool_id_bool(data, 'writeToFile:atomically:', macos.nsstring(path), true)
}

fn native_pasteboard_write_image_png(path string) bool {
	if path.len == 0 {
		return false
	}
	clipboard_image := native_pasteboard_image()
	if objc_is_nil(clipboard_image) {
		return false
	}
	tiff := macos.msg_id(clipboard_image, 'TIFFRepresentation')
	if objc_is_nil(tiff) || macos.msg_u64(tiff, 'length') == 0 {
		return false
	}
	bitmap := macos.msg_id1(macos.get_class('NSBitmapImageRep'), 'imageRepWithData:', tiff)
	return !objc_is_nil(bitmap) && native_write_data(native_png_data(bitmap), path)
}

fn native_view_save_png(view macos.Id, path string) bool {
	if objc_is_nil(view) || path.len == 0 {
		return false
	}
	view_bounds := macos.msg_rect(view, 'bounds')
	if view_bounds.width <= 0 || view_bounds.height <= 0 {
		return false
	}
	macos.msg_void(view, 'layoutSubtreeIfNeeded')
	macos.msg_void(view, 'displayIfNeeded')
	bitmap := macos.msg_id_rect(view, 'bitmapImageRepForCachingDisplayInRect:', view_bounds)
	if objc_is_nil(bitmap) {
		return false
	}
	macos.msg_void_rect_id(view, 'cacheDisplayInRect:toBitmapImageRep:', view_bounds, bitmap)
	return native_write_data(native_png_data(bitmap), path)
}

fn native_layer_set_frame_geometry(layer macos.Id, frame macos.Rect) {
	macos.msg_void_point(layer, 'setAnchorPoint:', macos.point(0.5, 0.5))
	macos.msg_void_rect(layer, 'setBounds:', macos.rect(0, 0, frame.width, frame.height))
	macos.msg_void_point(layer, 'setPosition:', macos.point(frame.x + frame.width / 2.0, frame.y + frame.height / 2.0))
}

fn native_set_layer_rotation(layer macos.Id, radians f64) {
	macos.msg_void2(layer, 'setValue:forKeyPath:', objc_number_f64(radians), macos.nsstring('transform.rotation'))
}

fn native_view_set_rotation(view macos.Id, degrees f64) {
	if objc_is_nil(view) {
		return
	}
	frame := macos.msg_rect(view, 'frame')
	macos.msg_void_bool(view, 'setWantsLayer:', true)
	layer := macos.msg_id(view, 'layer')
	if objc_is_nil(layer) {
		return
	}
	transaction := macos.get_class('CATransaction')
	macos.msg_void(transaction, 'begin')
	macos.msg_void_bool(transaction, 'setDisableActions:', true)
	native_set_layer_rotation(layer, 0)
	native_layer_set_frame_geometry(layer, frame)
	native_set_layer_rotation(layer, degrees * math.pi / 180.0)
	macos.msg_void(transaction, 'commit')
}

fn native_view_reset_transform(view macos.Id) {
	if objc_is_nil(view) {
		return
	}
	frame := macos.msg_rect(view, 'frame')
	macos.msg_void_bool(view, 'setWantsLayer:', true)
	layer := macos.msg_id(view, 'layer')
	if objc_is_nil(layer) {
		return
	}
	transaction := macos.get_class('CATransaction')
	macos.msg_void(transaction, 'begin')
	macos.msg_void_bool(transaction, 'setDisableActions:', true)
	native_set_layer_rotation(layer, 0)
	native_layer_set_frame_geometry(layer, frame)
	macos.msg_void(transaction, 'commit')
	macos.msg_void_rect(view, 'setFrame:', frame)
}

fn native_view_clear_rotation(view macos.Id) {
	if objc_is_nil(view) || !macos.msg_bool(view, 'wantsLayer') {
		return
	}
	layer := macos.msg_id(view, 'layer')
	if objc_is_nil(layer) {
		return
	}
	transaction := macos.get_class('CATransaction')
	macos.msg_void(transaction, 'begin')
	macos.msg_void_bool(transaction, 'setDisableActions:', true)
	native_set_layer_rotation(layer, 0)
	native_layer_set_frame_geometry(layer, macos.msg_rect(view, 'frame'))
	macos.msg_void(transaction, 'commit')
}

fn ui2_dispatch_callback(_self voidptr, _cmd voidptr, boxed_callback voidptr) {
	callback_pointer := macos.msg_u64(unsafe { macos.Id(boxed_callback) }, 'unsignedLongLongValue')
	callback := unsafe { VoidCallback(voidptr(callback_pointer)) }
	callback()
}

fn native_dispatch_main(callback VoidCallback) {
	mut helpers := native_macos_helpers()
	if objc_is_nil(helpers.dispatcher) {
		helpers.dispatcher = macos.msg_id(macos.alloc('UI2MainDispatcher'), 'init')
	}
	boxed_callback := macos.msg_id_u64(macos.get_class('NSNumber'), 'numberWithUnsignedLongLong:', u64(voidptr(callback)))
	macos.msg_void_sel_id_bool(helpers.dispatcher, 'performSelectorOnMainThread:withObject:waitUntilDone:', macos.sel('runCallback:'), boxed_callback, false)
}

fn native_observe_bounds(observer macos.Id, view macos.Id) {
	center := macos.msg_id(macos.get_class('NSNotificationCenter'), 'defaultCenter')
	macos.msg_void_id_sel_id_id(center, 'addObserver:selector:name:object:', observer, macos.sel('ui2BoundsChanged:'), macos.nsstring('NSViewBoundsDidChangeNotification'), view)
}

fn native_unobserve_bounds(observer macos.Id, view macos.Id) {
	center := macos.msg_id(macos.get_class('NSNotificationCenter'), 'defaultCenter')
	macos.msg_void3(center, 'removeObserver:name:object:', observer, macos.nsstring('NSViewBoundsDidChangeNotification'), view)
}

}
