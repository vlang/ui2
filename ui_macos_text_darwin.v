// vfmt off
module ui2

$if !ui2_custom_rendering ? {

import macos

const objc_attr_font = 'NSFont'
const objc_attr_foreground_color = 'NSColor'
const objc_attr_background_color = 'NSBackgroundColor'
const objc_attr_underline = 'NSUnderline'
const objc_attr_strikethrough = 'NSStrikethrough'
const objc_attr_superscript = 'NSSuperScript'
const objc_attr_paragraph_style = 'NSParagraphStyle'
const objc_attr_shadow = 'NSShadow'
const objc_attr_stroke_width = 'NSStrokeWidth'
const objc_attr_stroke_color = 'NSStrokeColor'
const objc_attr_link = 'NSLink'

fn native_font_with_format(font macos.Id, format int, enabled bool, fallback_size f64) macos.Id {
	mut current := objc_nil()
	current = font
	mut size := fallback_size
	if size <= 0 {
		size = macos.msg_f64(macos.get_class('NSFont'), 'systemFontSize')
	}
	if objc_is_nil(current) {
		current = macos.msg_id_f64(macos.get_class('NSFont'), 'systemFontOfSize:', size)
	}
	manager := macos.msg_id(macos.get_class('NSFontManager'), 'sharedFontManager')
	trait := if format == 0 { u64(2) } else { u64(1) }
	converted := macos.msg_id_id_u64(manager, if enabled { 'convertFont:toHaveTrait:' } else { 'convertFont:toNotHaveTrait:' }, current, trait)
	return if objc_is_nil(converted) { current } else { converted }
}

fn native_font_with_family(font macos.Id, family_name string, fallback_size f64) macos.Id {
	mut size := if objc_is_nil(font) { fallback_size } else { macos.msg_f64(font, 'pointSize') }
	if size <= 0 {
		size = macos.msg_f64(macos.get_class('NSFont'), 'systemFontSize')
	}
	if family_name.len == 0 {
		return if objc_is_nil(font) { macos.msg_id_f64(macos.get_class('NSFont'), 'systemFontOfSize:', size) } else { font }
	}
	family := macos.nsstring(family_name)
	mut base := macos.msg_id_id_f64(macos.get_class('NSFont'), 'fontWithName:size:', family, size)
	if objc_is_nil(base) {
		manager := macos.msg_id(macos.get_class('NSFontManager'), 'sharedFontManager')
		base = macos.msg_id_id_u64_i64_f64(manager, 'fontWithFamily:traits:weight:size:', family, 0, 5, size)
	}
	if objc_is_nil(base) {
		return if objc_is_nil(font) { macos.msg_id_f64(macos.get_class('NSFont'), 'systemFontOfSize:', size) } else { font }
	}
	if objc_is_nil(font) {
		return base
	}
	manager := macos.msg_id(macos.get_class('NSFontManager'), 'sharedFontManager')
	actual_traits := macos.msg_u64_id(manager, 'traitsOfFont:', font)
	mut converted := base
	if actual_traits & 2 != 0 {
		candidate := macos.msg_id_id_u64(manager, 'convertFont:toHaveTrait:', converted, 2)
		if !objc_is_nil(candidate) {
			converted = candidate
		}
	}
	if actual_traits & 1 != 0 {
		candidate := macos.msg_id_id_u64(manager, 'convertFont:toHaveTrait:', converted, 1)
		if !objc_is_nil(candidate) {
			converted = candidate
		}
	}
	return converted
}

fn native_font_with_size(font macos.Id, requested_size f64) macos.Id {
	mut size := requested_size
	if size <= 0 {
		size = macos.msg_f64(macos.get_class('NSFont'), 'systemFontSize')
	}
	if objc_is_nil(font) {
		return macos.msg_id_f64(macos.get_class('NSFont'), 'systemFontOfSize:', size)
	}
	manager := macos.msg_id(macos.get_class('NSFontManager'), 'sharedFontManager')
	converted := macos.msg_id_id_f64(manager, 'convertFont:toSize:', font, size)
	return if objc_is_nil(converted) { font } else { converted }
}

fn native_text_attributes(color u32, background_color u32, size f64, family_name string, bold bool, italic bool, underline bool, strikethrough bool, vertical_align string) macos.Id {
	mut font := native_font_object(size, bold, italic)
	font = native_font_with_family(font, family_name, size)
	attrs := objc_mutable_dictionary()
	objc_dict_set(attrs, objc_attr_font, font)
	objc_dict_set(attrs, objc_attr_foreground_color, native_color_from_hex(color))
	if underline {
		objc_dict_set(attrs, objc_attr_underline, objc_number_i64(1))
	}
	if strikethrough {
		objc_dict_set(attrs, objc_attr_strikethrough, objc_number_i64(1))
	}
	if background_color != 0 {
		objc_dict_set(attrs, objc_attr_background_color, native_color_from_hex(background_color))
	}
	align := native_vertical_align_value(vertical_align)
	if align != 0 {
		objc_dict_set(attrs, objc_attr_superscript, objc_number_i64(align))
	}
	return objc_autorelease(attrs)
}

fn native_vertical_align_value(align string) i64 {
	return match align {
		'superscript' { i64(1) }
		'subscript' { i64(-1) }
		else { i64(0) }
	}
}

fn native_vertical_align_name(value i64) string {
	return if value > 0 { 'superscript' } else if value < 0 { 'subscript' } else { '' }
}

fn native_text_shadow() macos.Id {
	shadow := objc_autorelease(macos.msg_id(macos.alloc('NSShadow'), 'init'))
	black := macos.msg_id(macos.get_class('NSColor'), 'blackColor')
	macos.msg_void1(shadow, 'setShadowColor:', macos.msg_id_f64(black, 'colorWithAlphaComponent:', 0.45))
	macos.msg_void_point(shadow, 'setShadowOffset:', macos.point(1.25, -1.25))
	macos.msg_void_f64(shadow, 'setShadowBlurRadius:', 1.0)
	return shadow
}

fn native_apply_text_effect_attributes(attrs macos.Id, effect int) {
	objc_dict_remove(attrs, objc_attr_shadow)
	objc_dict_remove(attrs, objc_attr_stroke_width)
	objc_dict_remove(attrs, objc_attr_stroke_color)
	if effect & 1 != 0 {
		objc_dict_set(attrs, objc_attr_shadow, native_text_shadow())
	}
	if effect & 2 != 0 {
		objc_dict_set(attrs, objc_attr_stroke_width, objc_number_f64(-2.0))
		mut color := objc_dict_get(attrs, objc_attr_foreground_color)
		if objc_is_nil(color) {
			color = macos.msg_id(macos.get_class('NSColor'), 'blackColor')
		}
		objc_dict_set(attrs, objc_attr_stroke_color, color)
	}
}

fn native_text_view_set_attributed_string(tv macos.Id, text string, color u32, background_color u32, size f64, family_name string, bold bool, italic bool, underline bool, strikethrough bool, vertical_align string) {
	if objc_is_nil(tv) {
		return
	}
	attrs := native_text_attributes(color, background_color, size, family_name, bold, italic, underline, strikethrough, vertical_align)
	attributed := macos.msg_id2(macos.alloc('NSMutableAttributedString'), 'initWithString:attributes:', macos.nsstring(text), attrs)
	macos.msg_void1(macos.msg_id(tv, 'textStorage'), 'setAttributedString:', attributed)
	macos.release(attributed)
}

fn native_text_view_set_paragraph_style(tv macos.Id, alignment int, head_indent f64, first_line_indent f64, hyphenation_factor f64) {
	if objc_is_nil(tv) {
		return
	}
	mut style := objc_nil()
	default_style := macos.msg_id(tv, 'defaultParagraphStyle')
	if !objc_is_nil(default_style) {
		style = macos.msg_id(default_style, 'mutableCopy')
	}
	if objc_is_nil(style) {
		style = macos.msg_id(macos.alloc('NSMutableParagraphStyle'), 'init')
	}
	native_alignment := if alignment == 1 { i64(1) } else if alignment == 2 { i64(2) } else { i64(0) }
	macos.msg_void_i64(style, 'setAlignment:', native_alignment)
	macos.msg_void_f64(style, 'setHeadIndent:', if head_indent > 0 { head_indent } else { 0 })
	macos.msg_void_f64(style, 'setFirstLineHeadIndent:', if first_line_indent > 0 { first_line_indent } else { 0 })
	macos.msg_void_f64(style, 'setTailIndent:', 0)
	mut hyphenation := hyphenation_factor
	if hyphenation < 0 { hyphenation = 0 }
	if hyphenation > 1 { hyphenation = 1 }
	macos.msg_void_f64(style, 'setHyphenationFactor:', hyphenation)
	macos.msg_void1(tv, 'setDefaultParagraphStyle:', style)
	storage := macos.msg_id(tv, 'textStorage')
	length := if objc_is_nil(storage) { u64(0) } else { macos.msg_u64(storage, 'length') }
	if length > 0 {
		macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(objc_attr_paragraph_style), style, macos.range(0, length))
	}
	typing := objc_mutable_copy_or_dictionary(macos.msg_id(tv, 'typingAttributes'))
	objc_dict_set(typing, objc_attr_paragraph_style, style)
	macos.msg_void1(tv, 'setTypingAttributes:', typing)
	macos.release(typing)
	macos.release(style)
}

fn native_text_view_add_style(tv macos.Id, location u64, length u64, color u32, background_color u32, size f64, family_name string, bold bool, italic bool, underline bool, strikethrough bool, vertical_align string) {
	if objc_is_nil(tv) || length == 0 {
		return
	}
	storage := macos.msg_id(tv, 'textStorage')
	storage_length := if objc_is_nil(storage) { u64(0) } else { macos.msg_u64(storage, 'length') }
	if location >= storage_length {
		return
	}
	safe_length := if length < storage_length - location { length } else { storage_length - location }
	attrs := native_text_attributes(color, background_color, size, family_name, bold, italic, underline, strikethrough, vertical_align)
	macos.msg_void_id_range(storage, 'addAttributes:range:', attrs, macos.range(location, safe_length))
}

fn native_text_view_add_link(tv macos.Id, location u64, length u64, link string) {
	if objc_is_nil(tv) || length == 0 || link.len == 0 {
		return
	}
	storage := macos.msg_id(tv, 'textStorage')
	storage_length := if objc_is_nil(storage) { u64(0) } else { macos.msg_u64(storage, 'length') }
	if location >= storage_length {
		return
	}
	safe_length := if length < storage_length - location { length } else { storage_length - location }
	macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(objc_attr_link), macos.nsstring(link), macos.range(location, safe_length))
	attrs := objc_mutable_dictionary()
	objc_dict_set(attrs, objc_attr_foreground_color, native_color_from_hex(0x0563c1))
	objc_dict_set(attrs, objc_attr_underline, objc_number_i64(1))
	macos.msg_void1(tv, 'setLinkTextAttributes:', attrs)
	macos.release(attrs)
}

fn native_control_set_attributed_title(control macos.Id, text string, color u32, size f64, bold bool, italic bool, underline bool) {
	if objc_is_nil(control) {
		return
	}
	attrs := native_text_attributes(color, 0, size, '', bold, italic, underline, false, '')
	attributed := macos.msg_id2(macos.alloc('NSAttributedString'), 'initWithString:attributes:', macos.nsstring(text), attrs)
	if macos.responds_to(control, 'setAttributedTitle:') {
		macos.msg_void1(control, 'setAttributedTitle:', attributed)
	} else if macos.responds_to(control, 'setAttributedStringValue:') {
		macos.msg_void1(control, 'setAttributedStringValue:', attributed)
	}
	macos.release(attributed)
}

fn native_text_view_object(tv macos.Id) macos.Id {
	if objc_is_nil(tv) {
		return tv
	}
	macos.msg_void_bool(tv, 'setRichText:', true)
	window := macos.msg_id(tv, 'window')
	if !objc_is_nil(window) {
		macos.msg_bool_id(window, 'makeFirstResponder:', tv)
	}
	return tv
}

fn native_text_view_safe_range(tv macos.Id, location u64, length u64) macos.Range {
	text_length := native_text_view_text_length(tv)
	safe_location := if location < text_length { location } else { text_length }
	safe_length := if length < text_length - safe_location { length } else { text_length - safe_location }
	return macos.range(safe_location, safe_length)
}

fn native_text_view_set_selected_range(tv macos.Id, location u64, length u64) {
	if objc_is_nil(tv) {
		return
	}
	range := native_text_view_safe_range(tv, location, length)
	window := macos.msg_id(tv, 'window')
	if !objc_is_nil(window) {
		macos.msg_bool_id(window, 'makeFirstResponder:', tv)
	}
	macos.msg_void_range(tv, 'setSelectedRange:', range)
	macos.msg_void_range(tv, 'scrollRangeToVisible:', range)
}

fn native_text_view_restore_selected_range(tv macos.Id, location u64, length u64, restore_focus bool) {
	if objc_is_nil(tv) {
		return
	}
	range := native_text_view_safe_range(tv, location, length)
	window := macos.msg_id(tv, 'window')
	if restore_focus && !objc_is_nil(window) {
		macos.msg_bool_id(window, 'makeFirstResponder:', tv)
	}
	macos.msg_void_range(tv, 'setSelectedRange:', range)
}

fn native_text_view_selected_range(tv macos.Id) macos.Range {
	if objc_is_nil(tv) {
		return macos.range(0, 0)
	}
	range := macos.msg_range(tv, 'selectedRange')
	return if range.location == u64(-1) { macos.range(0, 0) } else { range }
}

fn native_text_view_insert_text(tv macos.Id, text string) {
	text_view := native_text_view_object(tv)
	if objc_is_nil(text_view) {
		return
	}
	macos.msg_void_id_range(text_view, 'insertText:replacementRange:', macos.nsstring(text), native_text_view_selected_range(text_view))
}

fn native_text_view_text_length(tv macos.Id) u64 {
	if objc_is_nil(tv) {
		return 0
	}
	native_string := macos.msg_id(tv, 'string')
	return if objc_is_nil(native_string) { u64(0) } else { macos.msg_u64(native_string, 'length') }
}

fn native_text_view_current_attributes(tv macos.Id) macos.Id {
	if objc_is_nil(tv) {
		return objc_nil()
	}
	selected := native_text_view_selected_range(tv)
	storage := macos.msg_id(tv, 'textStorage')
	if selected.length == 0 {
		typing := macos.msg_id(tv, 'typingAttributes')
		if !objc_is_nil(typing) && macos.msg_u64(typing, 'count') > 0 {
			return typing
		}
	}
	storage_length := if objc_is_nil(storage) { u64(0) } else { macos.msg_u64(storage, 'length') }
	if storage_length > 0 {
		index := if selected.location < storage_length { selected.location } else { storage_length - 1 }
		return macos.msg_id_u64_range_ptr(storage, 'attributesAtIndex:effectiveRange:', index, unsafe { nil })
	}
	return macos.msg_id(tv, 'typingAttributes')
}

fn native_text_view_format_active(tv macos.Id, format int) bool {
	attrs := native_text_view_current_attributes(tv)
	if objc_is_nil(attrs) {
		return false
	}
	if format == 2 {
		value := objc_dict_get(attrs, objc_attr_underline)
		return !objc_is_nil(value) && macos.msg_i64(value, 'integerValue') != 0
	}
	if format == 3 {
		value := objc_dict_get(attrs, objc_attr_strikethrough)
		return !objc_is_nil(value) && macos.msg_i64(value, 'integerValue') != 0
	}
	font := objc_dict_get(attrs, objc_attr_font)
	if objc_is_nil(font) {
		return false
	}
	traits := macos.msg_u64_id(macos.msg_id(macos.get_class('NSFontManager'), 'sharedFontManager'), 'traitsOfFont:', font)
	return if format == 0 { traits & 2 != 0 } else if format == 1 { traits & 1 != 0 } else { false }
}

fn native_text_view_vertical_align_active(tv macos.Id) int {
	value := objc_dict_get(native_text_view_current_attributes(tv), objc_attr_superscript)
	if objc_is_nil(value) {
		return 0
	}
	align := macos.msg_i64(value, 'integerValue')
	return if align > 0 { 1 } else if align < 0 { -1 } else { 0 }
}

fn native_text_view_effect_active(tv macos.Id) int {
	attrs := native_text_view_current_attributes(tv)
	if objc_is_nil(attrs) {
		return 0
	}
	mut effect := if objc_is_nil(objc_dict_get(attrs, objc_attr_shadow)) { 0 } else { 1 }
	stroke_width := objc_dict_get(attrs, objc_attr_stroke_width)
	if !objc_is_nil(stroke_width) && macos.msg_f64(stroke_width, 'doubleValue') != 0 {
		effect |= 2
	}
	return effect
}

fn native_text_view_font_size(tv macos.Id) f64 {
	font := macos.msg_id(tv, 'font')
	return if objc_is_nil(font) { macos.msg_f64(macos.get_class('NSFont'), 'systemFontSize') } else { macos.msg_f64(font, 'pointSize') }
}

fn native_apply_typing_format(tv macos.Id, format int, enabled bool) {
	attrs := objc_mutable_copy_or_dictionary(macos.msg_id(tv, 'typingAttributes'))
	if format == 2 {
		if enabled { objc_dict_set(attrs, objc_attr_underline, objc_number_i64(1)) } else { objc_dict_remove(attrs, objc_attr_underline) }
	} else if format == 3 {
		if enabled { objc_dict_set(attrs, objc_attr_strikethrough, objc_number_i64(1)) } else { objc_dict_remove(attrs, objc_attr_strikethrough) }
	} else {
		mut font := objc_dict_get(attrs, objc_attr_font)
		if objc_is_nil(font) { font = macos.msg_id(tv, 'font') }
		objc_dict_set(attrs, objc_attr_font, native_font_with_format(font, format, enabled, native_text_view_font_size(tv)))
	}
	macos.msg_void1(tv, 'setTypingAttributes:', attrs)
	macos.release(attrs)
}

fn native_apply_typing_color(tv macos.Id, color u32, background bool) {
	attrs := objc_mutable_copy_or_dictionary(macos.msg_id(tv, 'typingAttributes'))
	key := if background { objc_attr_background_color } else { objc_attr_foreground_color }
	if background && color == 0 { objc_dict_remove(attrs, key) } else { objc_dict_set(attrs, key, native_color_from_hex(color)) }
	macos.msg_void1(tv, 'setTypingAttributes:', attrs)
	macos.release(attrs)
}

fn native_apply_typing_effect(tv macos.Id, effect int) {
	attrs := objc_mutable_copy_or_dictionary(macos.msg_id(tv, 'typingAttributes'))
	native_apply_text_effect_attributes(attrs, effect)
	macos.msg_void1(tv, 'setTypingAttributes:', attrs)
	macos.release(attrs)
}

fn native_apply_typing_font_family(tv macos.Id, family_name string) {
	attrs := objc_mutable_copy_or_dictionary(macos.msg_id(tv, 'typingAttributes'))
	mut font := objc_dict_get(attrs, objc_attr_font)
	if objc_is_nil(font) { font = macos.msg_id(tv, 'font') }
	objc_dict_set(attrs, objc_attr_font, native_font_with_family(font, family_name, native_text_view_font_size(tv)))
	macos.msg_void1(tv, 'setTypingAttributes:', attrs)
	macos.release(attrs)
}

fn native_apply_typing_font_size(tv macos.Id, size f64) {
	attrs := objc_mutable_copy_or_dictionary(macos.msg_id(tv, 'typingAttributes'))
	mut font := objc_dict_get(attrs, objc_attr_font)
	if objc_is_nil(font) { font = macos.msg_id(tv, 'font') }
	objc_dict_set(attrs, objc_attr_font, native_font_with_size(font, size))
	macos.msg_void1(tv, 'setTypingAttributes:', attrs)
	macos.release(attrs)
}

fn native_apply_typing_vertical_align(tv macos.Id, align int) {
	current := native_text_view_current_attributes(tv)
	attrs := objc_mutable_copy_or_dictionary(if objc_is_nil(current) { macos.msg_id(tv, 'typingAttributes') } else { current })
	if objc_is_nil(objc_dict_get(attrs, objc_attr_font)) {
		font := macos.msg_id(tv, 'font')
		if !objc_is_nil(font) { objc_dict_set(attrs, objc_attr_font, font) }
	}
	if align == 0 { objc_dict_remove(attrs, objc_attr_superscript) } else { objc_dict_set(attrs, objc_attr_superscript, objc_number_i64(i64(align))) }
	macos.msg_void1(tv, 'setTypingAttributes:', attrs)
	macos.release(attrs)
}

fn native_safe_storage_range(tv macos.Id, range macos.Range) ?(macos.Id, macos.Range) {
	storage := macos.msg_id(tv, 'textStorage')
	length := if objc_is_nil(storage) { u64(0) } else { macos.msg_u64(storage, 'length') }
	if length == 0 || range.length == 0 || range.location >= length {
		return none
	}
	safe_length := if range.length < length - range.location { range.length } else { length - range.location }
	return storage, macos.range(range.location, safe_length)
}

fn native_apply_range_format(tv macos.Id, requested macos.Range, format int, enabled bool) {
	storage, range := native_safe_storage_range(tv, requested) or { return }
	macos.msg_void(storage, 'beginEditing')
	if format == 2 || format == 3 {
		key := if format == 2 { objc_attr_underline } else { objc_attr_strikethrough }
		if enabled {
			macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(key), objc_number_i64(1), range)
		} else {
			macos.msg_void_id_range(storage, 'removeAttribute:range:', macos.nsstring(key), range)
		}
	} else {
		end := range.location + range.length
		mut cursor := range.location
		for cursor < end {
			mut effective := macos.range(cursor, end - cursor)
			mut font := macos.msg_id_id_u64_range_ptr(storage, 'attribute:atIndex:effectiveRange:', macos.nsstring(objc_attr_font), cursor, &effective)
			if objc_is_nil(font) { font = macos.msg_id(tv, 'font') }
			apply_length := if effective.length == 0 { u64(1) } else if effective.location + effective.length > end { end - cursor } else { effective.location + effective.length - cursor }
			apply := macos.range(cursor, apply_length)
			macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(objc_attr_font), native_font_with_format(font, format, enabled, native_text_view_font_size(tv)), apply)
			cursor += apply.length
		}
	}
	macos.msg_void(storage, 'endEditing')
	macos.msg_void_range(tv, 'setSelectedRange:', range)
}

fn native_apply_range_color(tv macos.Id, requested macos.Range, color u32, background bool) {
	storage, range := native_safe_storage_range(tv, requested) or { return }
	key := if background { objc_attr_background_color } else { objc_attr_foreground_color }
	if background && color == 0 {
		macos.msg_void_id_range(storage, 'removeAttribute:range:', macos.nsstring(key), range)
	} else {
		macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(key), native_color_from_hex(color), range)
	}
	macos.msg_void_range(tv, 'setSelectedRange:', range)
}

fn native_apply_range_effect(tv macos.Id, requested macos.Range, effect int) {
	storage, range := native_safe_storage_range(tv, requested) or { return }
	for key in [objc_attr_shadow, objc_attr_stroke_width, objc_attr_stroke_color] {
		macos.msg_void_id_range(storage, 'removeAttribute:range:', macos.nsstring(key), range)
	}
	if effect & 1 != 0 {
		macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(objc_attr_shadow), native_text_shadow(), range)
	}
	if effect & 2 != 0 {
		macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(objc_attr_stroke_width), objc_number_f64(-2.0), range)
		macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(objc_attr_stroke_color), macos.msg_id(macos.get_class('NSColor'), 'blackColor'), range)
	}
	macos.msg_void_range(tv, 'setSelectedRange:', range)
}

fn native_apply_range_vertical_align(tv macos.Id, requested macos.Range, align int) {
	storage, range := native_safe_storage_range(tv, requested) or { return }
	macos.msg_void(storage, 'beginEditing')
	if align == 0 {
		macos.msg_void_id_range(storage, 'removeAttribute:range:', macos.nsstring(objc_attr_superscript), range)
	} else {
		macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(objc_attr_superscript), objc_number_i64(i64(align)), range)
	}
	macos.msg_void(storage, 'endEditing')
	macos.msg_void_range(tv, 'setSelectedRange:', range)
}

fn native_apply_range_font(tv macos.Id, requested macos.Range, family_name string, size f64, change_family bool) {
	storage, range := native_safe_storage_range(tv, requested) or { return }
	macos.msg_void(storage, 'beginEditing')
	end := range.location + range.length
	mut cursor := range.location
	for cursor < end {
		mut effective := macos.range(cursor, end - cursor)
		mut font := macos.msg_id_id_u64_range_ptr(storage, 'attribute:atIndex:effectiveRange:', macos.nsstring(objc_attr_font), cursor, &effective)
		if objc_is_nil(font) { font = macos.msg_id(tv, 'font') }
		apply_length := if effective.length == 0 { u64(1) } else if effective.location + effective.length > end { end - cursor } else { effective.location + effective.length - cursor }
		apply := macos.range(cursor, apply_length)
		converted := if change_family { native_font_with_family(font, family_name, native_text_view_font_size(tv)) } else { native_font_with_size(font, size) }
		macos.msg_void_id_id_range(storage, 'addAttribute:value:range:', macos.nsstring(objc_attr_font), converted, apply)
		cursor += apply.length
	}
	macos.msg_void(storage, 'endEditing')
	macos.msg_void_range(tv, 'setSelectedRange:', range)
}

fn native_text_view_toggle_format(tv_ptr macos.Id, format int) {
	tv := native_text_view_object(tv_ptr)
	if objc_is_nil(tv) { return }
	enabled := !native_text_view_format_active(tv, format)
	selected := native_text_view_selected_range(tv)
	if selected.length == 0 { native_apply_typing_format(tv, format, enabled) } else { native_apply_range_format(tv, selected, format, enabled) }
}

fn native_text_view_set_font_family(tv_ptr macos.Id, family_name string) {
	tv := native_text_view_object(tv_ptr)
	if objc_is_nil(tv) { return }
	selected := native_text_view_selected_range(tv)
	if selected.length == 0 { native_apply_typing_font_family(tv, family_name) } else { native_apply_range_font(tv, selected, family_name, 0, true) }
}

fn native_text_view_set_font_size(tv_ptr macos.Id, size f64) {
	tv := native_text_view_object(tv_ptr)
	if objc_is_nil(tv) { return }
	selected := native_text_view_selected_range(tv)
	if selected.length == 0 { native_apply_typing_font_size(tv, size) } else { native_apply_range_font(tv, selected, '', size, false) }
}

fn native_text_view_set_color(tv_ptr macos.Id, color u32) {
	tv := native_text_view_object(tv_ptr)
	if objc_is_nil(tv) { return }
	selected := native_text_view_selected_range(tv)
	if selected.length == 0 { native_apply_typing_color(tv, color, false) } else { native_apply_range_color(tv, selected, color, false) }
}

fn native_text_view_set_background_color(tv_ptr macos.Id, color u32) {
	tv := native_text_view_object(tv_ptr)
	if objc_is_nil(tv) { return }
	selected := native_text_view_selected_range(tv)
	if selected.length == 0 { native_apply_typing_color(tv, color, true) } else { native_apply_range_color(tv, selected, color, true) }
}

fn native_text_view_add_effect(tv macos.Id, location u64, length u64, effect int) {
	if !objc_is_nil(tv) && length > 0 { native_apply_range_effect(tv, macos.range(location, length), effect) }
}

fn native_text_view_set_effect(tv_ptr macos.Id, effect int) {
	tv := native_text_view_object(tv_ptr)
	if objc_is_nil(tv) { return }
	selected := native_text_view_selected_range(tv)
	if selected.length == 0 { native_apply_typing_effect(tv, effect) } else { native_apply_range_effect(tv, selected, effect) }
}

fn native_text_view_toggle_vertical_align(tv_ptr macos.Id, align int) {
	tv := native_text_view_object(tv_ptr)
	if objc_is_nil(tv) || align == 0 { return }
	next := if native_text_view_vertical_align_active(tv) == align { 0 } else { align }
	selected := native_text_view_selected_range(tv)
	if selected.length == 0 { native_apply_typing_vertical_align(tv, next) } else { native_apply_range_vertical_align(tv, selected, next) }
}

fn native_text_view_runs(tv macos.Id) []TextRun {
	if objc_is_nil(tv) { return []TextRun{} }
	storage := macos.msg_id(tv, 'textStorage')
	length := if objc_is_nil(storage) { u64(0) } else { macos.msg_u64(storage, 'length') }
	full := if objc_is_nil(storage) { objc_nil() } else { macos.msg_id(storage, 'string') }
	if length == 0 || objc_is_nil(full) { return []TextRun{} }
	manager := macos.msg_id(macos.get_class('NSFontManager'), 'sharedFontManager')
	mut runs := []TextRun{}
	mut cursor := u64(0)
	for cursor < length {
		mut effective := macos.range(cursor, length - cursor)
		attrs := macos.msg_id_u64_range_ptr(storage, 'attributesAtIndex:effectiveRange:', cursor, &effective)
		mut effective_end := effective.location + effective.length
		if effective.length == 0 || effective_end <= cursor { effective_end = cursor + 1 }
		effective.location = cursor
		effective.length = if effective_end < length { effective_end - cursor } else { length - cursor }
		run_text := macos.utf8_string(macos.msg_id_range(full, 'substringWithRange:', effective))
		mut font := objc_dict_get(attrs, objc_attr_font)
		if objc_is_nil(font) { font = macos.msg_id(tv, 'font') }
		traits := if objc_is_nil(font) { u64(0) } else { macos.msg_u64_id(manager, 'traitsOfFont:', font) }
		underline := objc_dict_get(attrs, objc_attr_underline)
		strike := objc_dict_get(attrs, objc_attr_strikethrough)
		stroke := objc_dict_get(attrs, objc_attr_stroke_width)
		superscript := objc_dict_get(attrs, objc_attr_superscript)
		link_value := objc_dict_get(attrs, objc_attr_link)
		mut effect := if objc_is_nil(objc_dict_get(attrs, objc_attr_shadow)) { 0 } else { 1 }
		if !objc_is_nil(stroke) && macos.msg_f64(stroke, 'doubleValue') != 0 { effect |= 2 }
		if run_text.len > 0 {
			runs << TextRun{
				text: run_text
				style: TextStyle{
					font_family: if objc_is_nil(font) { '' } else { macos.utf8_string(macos.msg_id(font, 'familyName')) }
					size: if objc_is_nil(font) { 0 } else { macos.msg_f64(font, 'pointSize') }
					bold: traits & 2 != 0
					italic: traits & 1 != 0
					underline: !objc_is_nil(underline) && macos.msg_i64(underline, 'integerValue') != 0
					strikethrough: !objc_is_nil(strike) && macos.msg_i64(strike, 'integerValue') != 0
					color: native_color_hex(objc_dict_get(attrs, objc_attr_foreground_color), 0x111111)
					background_color: native_color_hex(objc_dict_get(attrs, objc_attr_background_color), 0)
					shadow: effect & 1 != 0
					outline: effect & 2 != 0
					vertical_align: native_vertical_align_name(if objc_is_nil(superscript) { 0 } else { macos.msg_i64(superscript, 'integerValue') })
					link: if objc_is_nil(link_value) { '' } else { macos.description_string(link_value) }
				}
			}
		}
		cursor = effective.location + effective.length
	}
	return runs
}

}
