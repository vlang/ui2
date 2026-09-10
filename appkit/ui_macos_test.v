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

fn test_macos_toggle_button_groups_are_exclusive() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	left := native_new_toggle_button(toggle_button(
		id: 'left'
		title: 'Left'
		pressed: true
		group: 'alignment'
		allow_no_selection: false
	))
	right := native_new_toggle_button(toggle_button(
		id: 'right'
		title: 'Right'
		group: 'alignment'
		allow_no_selection: false
	))
	defer {
		macos.release(left)
		macos.release(right)
	}
	mut st := state()
	st.toggle_groups = map[u64]string{}
	st.toggle_allow_no_selection = map[u64]bool{}
	st.toggle_ids = map[u64]string{}
	st.toggle_views = map[u64]NativeView{}
	left_pointer := u64(voidptr(left))
	right_pointer := u64(voidptr(right))
	st.toggle_groups[left_pointer] = 'alignment'
	st.toggle_groups[right_pointer] = 'alignment'
	st.toggle_allow_no_selection[left_pointer] = false
	st.toggle_allow_no_selection[right_pointer] = false
	st.toggle_ids[left_pointer] = 'left'
	st.toggle_ids[right_pointer] = 'right'
	st.toggle_views[left_pointer] = left
	st.toggle_views[right_pointer] = right
	st.views['left'] = left
	st.views['right'] = right
	st.view_kinds['left'] = .toggle_button
	st.view_kinds['right'] = .toggle_button
	macos.msg_void_i64(right, 'setState:', i64(1))
	release_macos_toggle_group(right_pointer)
	assert macos.msg_i64(left, 'state') == 0
	assert macos.msg_i64(right, 'state') == 1
	macos.msg_void_i64(right, 'setState:', i64(0))
	commit_macos_toggle_button(right_pointer, right)
	assert macos.msg_i64(right, 'state') == 1
	mut members := toggle_button_group_members('right')
	members.sort()
	assert members == ['left', 'right']
	st.views.delete('left')
	st.views.delete('right')
	st.view_kinds.delete('left')
	st.view_kinds.delete('right')
	st.toggle_groups = map[u64]string{}
	st.toggle_allow_no_selection = map[u64]bool{}
	st.toggle_ids = map[u64]string{}
	st.toggle_views = map[u64]NativeView{}
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
	button_view := native_new_button(native_rect(0, 0, 96, 40), 'Count', BoxStyle{
		bg: 0x3478d4
		radius: 7
	}, 0xffffff, 15, true, false, false, 1, '', true)
	defer {
		macos.release(button_view)
	}

	assert macos.msg_bool(button_view, 'isBordered')
	assert macos.msg_u64(macos.msg_id(button_view, 'cell'), 'highlightsBy') & u64(2) != 0
	assert !macos.msg_bool(button_view, 'wantsLayer')
}

fn test_macos_transparent_box_controls_disable_native_backgrounds() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	transparent_box := BoxStyle{
		bg: 0xff00ff
		transparent: true
	}
	button_view := native_new_button(native_rect(0, 0, 96, 40), 'Clear', BoxStyle{},
		0xffffff, 15, false, false, false, 0, '', true)
	scroll_view := native_new_scroll(native_rect(0, 0, 120, 80), BoxStyle{}, false)
	toggle_view := native_new_toggle_button(toggle_button(
		title: 'Clear toggle'
		box: transparent_box
		native_style: true
	))
	dropdown_view := native_new_dropdown(dropdown('clear-dropdown', 'One', ['One'], rect(0,
		0, 120, 32), transparent_box, TextStyle{}))
	field := native_new_text_field(text_field('clear-field', '', '', rect(0, 0, 120, 32),
		transparent_box, TextStyle{}, keyboard_default))
	text_area_view := native_new_text_area(text_area('clear-area', '', rect(0, 0, 120, 80),
		transparent_box, TextStyle{}))
	defer {
		macos.release(button_view)
		macos.release(scroll_view)
		macos.release(toggle_view)
		macos.release(dropdown_view)
		macos.release(field)
		macos.release(text_area_view)
	}

	native_update_button(button_view, native_rect(0, 0, 96, 40), 'Clear', transparent_box,
		0xffffff, 15, false, false, false, 0, '', true)
	native_set_scroll_background(scroll_view, transparent_box)

	assert !macos.msg_bool(button_view, 'isBordered')
	assert macos.msg_bool(button_view, 'wantsLayer')
	layer := macos.msg_id(button_view, 'layer')
	assert native_is_nil(macos.msg_id(layer, 'backgroundColor'))
	assert !macos.msg_bool(scroll_view, 'drawsBackground')
	assert !macos.msg_bool(toggle_view, 'isBordered')
	assert !macos.msg_bool(dropdown_view, 'isBordered')
	assert !macos.msg_bool(field, 'drawsBackground')
	assert !macos.msg_bool(text_area_view, 'drawsBackground')
	text_view := text_area_text_view(text_area_view, false)
	assert !macos.msg_bool(text_view, 'drawsBackground')
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
