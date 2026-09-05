// vfmt off
module ui2

$if !ui2_custom_rendering ? {

import macos
import math

fn test_macos_v_objc_rich_text_bridge_round_trips_attributes() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	tv := macos.msg_id_rect(macos.alloc('NSTextView'), 'initWithFrame:', macos.rect(0, 0, 240, 80))
	defer {
		macos.release(tv)
	}

	native_text_view_set_attributed_string(tv, 'abc', 0x123456, 0, 15, '', true, false, true, false, '')
	native_text_view_add_style(tv, 1, 1, 0xa1b2c3, 0xddeeff, 18, '', false, true, false, true, 'superscript')
	native_text_view_add_effect(tv, 1, 1, 3)
	native_text_view_add_link(tv, 1, 1, 'https://example.test')
	native_text_view_set_paragraph_style(tv, 1, 12, 4, 0.5)

	runs := native_text_view_runs(tv)
	assert runs.map(it.text).join('') == 'abc'
	middle := runs.filter(it.text == 'b')
	assert middle.len == 1
	assert middle[0].style.color == native_color_hex(native_color_from_hex(0xa1b2c3), 0)
	assert middle[0].style.background_color == native_color_hex(native_color_from_hex(0xddeeff), 0)
	assert middle[0].style.italic
	assert middle[0].style.strikethrough
	assert middle[0].style.vertical_align == 'superscript'
	assert middle[0].style.shadow
	assert middle[0].style.outline
	assert middle[0].style.link == 'https://example.test'
}

fn test_macos_v_objc_range_bridge_updates_selection_and_text() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	tv := macos.msg_id_rect(macos.alloc('NSTextView'), 'initWithFrame:', macos.rect(0, 0, 240, 80))
	defer {
		macos.release(tv)
	}
	macos.msg_void1(tv, 'setString:', macos.nsstring('hello'))

	native_text_view_set_selected_range(tv, 1, 3)
	selected := native_text_view_selected_range(tv)
	assert selected.location == 1
	assert selected.length == 3
	native_text_view_insert_text(tv, 'i')
	assert macos.utf8_string(macos.msg_id(tv, 'string')) == 'hio'
}

fn test_macos_v_objc_range_formatting_commands_apply_to_selection() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	tv := macos.msg_id_rect(macos.alloc('NSTextView'), 'initWithFrame:', macos.rect(0, 0, 240, 80))
	defer {
		macos.release(tv)
	}
	native_text_view_set_attributed_string(tv, 'format', 0x111111, 0, 15, '', false, false, false, false, '')
	native_text_view_set_selected_range(tv, 0, 6)

	native_text_view_toggle_format(tv, int(TextFormat.bold))
	native_text_view_set_font_family(tv, 'Menlo')
	native_text_view_set_font_size(tv, 19)
	native_text_view_set_color(tv, 0x345678)
	native_text_view_set_background_color(tv, 0xabcdef)
	native_text_view_set_effect(tv, 1)
	native_text_view_toggle_vertical_align(tv, 1)

	assert native_text_view_format_active(tv, int(TextFormat.bold))
	assert native_text_view_vertical_align_active(tv) == 1
	assert native_text_view_effect_active(tv) == 1
	runs := native_text_view_runs(tv)
	assert runs.len == 1
	assert runs[0].style.bold
	assert runs[0].style.font_family == 'Menlo'
	assert runs[0].style.size == 19
	assert runs[0].style.vertical_align == 'superscript'
	assert runs[0].style.shadow
}

fn test_macos_v_objc_accessibility_state_restores_native_values() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	field := macos.msg_id_rect(macos.alloc('NSTextField'), 'initWithFrame:', macos.rect(0, 0, 120, 24))
	defer {
		macos.release(field)
	}
	original_role := macos.utf8_string(macos.msg_id(field, 'accessibilityRole'))

	native_apply_common_view_state(field, true, false, 'button', 'Save', 'Ready')
	assert macos.msg_bool(field, 'isHidden')
	assert !macos.msg_bool(field, 'isEnabled')
	assert macos.utf8_string(macos.msg_id(field, 'accessibilityRole')) == 'AXButton'
	assert macos.utf8_string(macos.msg_id(field, 'accessibilityLabel')) == 'Save'

	native_apply_common_view_state(field, false, true, '', '', '')
	assert !macos.msg_bool(field, 'isHidden')
	assert macos.msg_bool(field, 'isEnabled')
	assert macos.utf8_string(macos.msg_id(field, 'accessibilityRole')) == original_role
}

fn test_macos_v_objc_rotation_bridge_updates_layer_transform() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	view := macos.msg_id_rect(macos.alloc('NSView'), 'initWithFrame:', macos.rect(10, 20, 100, 40))
	defer {
		macos.release(view)
	}

	native_view_set_rotation(view, 45)
	layer := macos.msg_id(view, 'layer')
	rotation := macos.msg_id1(layer, 'valueForKeyPath:', macos.nsstring('transform.rotation'))
	assert math.abs(macos.msg_f64(rotation, 'doubleValue') - math.pi / 4.0) < 0.000001
	native_view_clear_rotation(view)
	cleared := macos.msg_id1(layer, 'valueForKeyPath:', macos.nsstring('transform.rotation'))
	assert math.abs(macos.msg_f64(cleared, 'doubleValue')) < 0.000001
}

}
