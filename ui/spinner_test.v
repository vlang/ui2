module ui2

fn test_spinner_autoselects_first_value_when_requested() {
	assert spinner_selected_text('', ['Home', 'Work'], true) == 'Home'
	assert spinner_selected_text('Work', ['Home', 'Work'], true) == 'Home'
	assert spinner_selected_text('', ['Home', 'Work'], false) == ''
	assert spinner_selected_text('', []string{}, true) == ''
}

fn test_spinner_reuses_dropdown_behavior_with_accessibility_defaults() {
	el := spinner(
		id: 'location'
		action_id: 'location_changed'
		frame: rect(10, 20, 160, 42)
		values: ['Home', 'Work', 'Other']
		text_autoupdate: true
		box: BoxStyle{
			bg: 0xdbeafe
			radius: 7
		}
	)
	assert el.kind == .dropdown
	assert el.id == 'location'
	assert el.action_id == 'location_changed'
	assert el.text == 'Home'
	assert el.menu.len == 3
	assert el.menu[2].title == 'Other'
	assert el.accessibility_role == 'combobox'
	assert el.accessibility_value == 'Home'
}
