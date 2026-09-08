module ui2

fn test_toggle_button_constructor_keeps_both_visual_states() {
	el := toggle_button(
		id: 'bold'
		action_id: 'bold_changed'
		title: 'Bold'
		frame: rect(10, 20, 100, 40)
		pressed: true
		box: BoxStyle{ bg: 0xe2e8f0, radius: 6 }
		down_box: BoxStyle{ bg: 0x1d4ed8, radius: 6 }
		text_style: TextStyle{ color: 0x1e293b }
		down_text_style: TextStyle{ color: 0xffffff, bold: true }
	)
	assert el.kind == .toggle_button
	assert el.checked
	assert el.box.bg == u32(0xe2e8f0)
	assert el.toggle_down_box.bg == u32(0x1d4ed8)
	assert el.toggle_down_text_style.bold
	assert el.accessibility_role == 'button'
	assert el.accessibility_label == 'Bold'
	assert el.accessibility_value == 'pressed'
}
