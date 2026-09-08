// vfmt off
// These tests exercise the native backend and do not apply to custom builds.
module ui2

$if !ui2_custom_rendering ? {

import macos

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

fn test_macos_switch_uses_native_boolean_state() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	view := native_new_switch_control(switch_control(
		id: 'native-switch'
		frame: rect(0, 0, 83, 32)
		active: true
	))
	defer {
		macos.release(view)
	}

	assert macos.msg_i64(view, 'state') == 1
	macos.msg_void_i64(view, 'setState:', 0)
	assert macos.msg_i64(view, 'state') == 0
}

fn test_macos_toggle_button_retains_pressed_state() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	native := native_new_toggle_button(toggle_button(
		id: 'native-toggle'
		title: 'Bold'
		frame: rect(0, 0, 100, 32)
		pressed: true
	))
	defer {
		macos.release(native)
	}

	assert macos.msg_i64(native, 'state') == 1
	native_finish_button_action(native, true)
	assert macos.msg_i64(native, 'state') == 1
}

fn test_macos_slider_uses_native_range_and_snaps_live_values() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	slider_view := native_new_slider(slider(
		id: 'native-slider'
		frame: rect(0, 0, 240, 28)
		min: -20
		max: 100
		value: 42
		step: 5
	))
	defer {
		macos.release(slider_view)
	}

	assert macos.msg_f64(slider_view, 'minValue') == -20
	assert macos.msg_f64(slider_view, 'maxValue') == 100
	assert macos.msg_f64(slider_view, 'doubleValue') == 42
	macos.msg_void_f64(slider_view, 'setDoubleValue:', 43)
	assert native_snap_slider_value(slider_view, SliderSpec{
		min: -20
		max: 100
		step: 5
	}) == 45
	assert macos.msg_f64(slider_view, 'doubleValue') == 45
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

fn test_macos_independent_borders_follow_the_view_bounds() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	ensure_runtime_classes()
	view := native_new_view(native_rect(0, 0, 120, 80), BoxStyle{}, false)
	defer {
		macos.release(view)
	}
	box := BoxStyle{
		border_color:  0x28314a
		border_left:   1
		border_top:    2
		border_right:  3
		border_bottom: 4
	}
	native_set_box_borders(view, box)

	left := macos.get_associated_object(view, native_border_key('left'))
	top := macos.get_associated_object(view, native_border_key('top'))
	right := macos.get_associated_object(view, native_border_key('right'))
	bottom := macos.get_associated_object(view, native_border_key('bottom'))
	assert left != unsafe { nil }
	assert top != unsafe { nil }
	assert right != unsafe { nil }
	assert bottom != unsafe { nil }
	assert macos.msg_rect(left, 'frame') == macos.rect(0, 0, 1, 80)
	assert macos.msg_rect(top, 'frame') == macos.rect(0, 0, 120, 2)
	assert macos.msg_rect(right, 'frame') == macos.rect(117, 0, 3, 80)
	assert macos.msg_rect(bottom, 'frame') == macos.rect(0, 76, 120, 4)

	native_set_box_borders(view, BoxStyle{})
	assert macos.msg_bool(left, 'isHidden')
	assert macos.msg_bool(top, 'isHidden')
	assert macos.msg_bool(right, 'isHidden')
	assert macos.msg_bool(bottom, 'isHidden')
}

fn test_macos_text_commands_report_forward_and_reverse_tab() {
	assert text_command_key(voidptr(macos.sel('insertTab:')), 0)? == 'tab'
	assert text_command_key(voidptr(macos.sel('insertTab:')), 0x20000)? == 'shift+tab'
	assert text_command_key(voidptr(macos.sel('insertBacktab:')), 0)? == 'shift+tab'
}
}
