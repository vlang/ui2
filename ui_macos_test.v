// vfmt off
// These tests exercise the native backend and do not apply to custom builds.
module ui2

$if !ui2_custom_rendering ? {

import internal.macos

fn test_macos_checkbox_uses_native_switch_and_retains_state() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	checkbox_view := native_new_checkbox(checkbox('native-check', 'Native checkbox', true, rect(0, 0, 180, 24), TextStyle{}))
	defer {
		macos.release(checkbox_view)
	}

	assert macos.msg_i64(checkbox_view, 'state') == 1
	native_finish_button_action(checkbox_view, true)
	assert macos.msg_i64(checkbox_view, 'state') == 1
}

fn test_macos_native_style_button_keeps_appkit_bezel_and_press_state() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	button_view := native_new_button(native_rect(0, 0, 96, 40), 'Count', 0x3478d4,
		0xffffff, 15, true, false, false, 7, 1, '', true)
	defer {
		macos.release(button_view)
	}

	assert macos.msg_bool(button_view, 'isBordered')
	assert macos.msg_u64(macos.msg_id(button_view, 'cell'), 'highlightsBy') & u64(2) != 0
	assert !macos.msg_bool(button_view, 'wantsLayer')
}

fn test_macos_text_field_uses_native_bezel_without_layer_mask() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	field := native_new_text_field(text_field('field', 'Name', '', rect(0, 0, 200, 32), BoxStyle{
		radius: 6
	}, TextStyle{}, keyboard_default))
	defer {
		macos.release(field)
	}

	// AppKit owns the bezel shape. A custom backing layer was what produced
	// the clipped corner gaps in the rendered field.
	assert !macos.msg_bool(field, 'wantsLayer')
}
}
