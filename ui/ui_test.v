module ui2

fn test_box_border_width_stays_inside_the_element() {
	assert box_border_width(-1, 20) == 0
	assert box_border_width(0, 20) == 0
	assert box_border_width(1.5, 20) == 1.5
	assert box_border_width(30, 20) == 20
	assert box_border_width(1, 0) == 0
}

fn test_with_secure_entry_preserves_text_field_configuration() {
	field := text_field_with_change_and_submit('password', 'sign-in', 'Password', 'secret', rect(1, 2, 200, 32), BoxStyle{
		bg: 0xfafafa
	}, TextStyle{
		size: 14
	}, keyboard_default)
	secure := with_secure_entry(field)

	assert secure.kind == .text_field
	assert secure.id == 'password'
	assert secure.submit_id == 'sign-in'
	assert secure.emit_change
	assert secure.text == 'secret'
	assert secure.secure
}

fn test_checkbox_constructor_preserves_native_state_and_accessibility() {
	el := checkbox('terms', 'Accept terms', true, rect(4, 8, 180, 24), TextStyle{
		size: 13
	})

	assert el.kind == .checkbox
	assert el.id == 'terms'
	assert el.text == 'Accept terms'
	assert el.checked
	assert el.box.transparent
	assert el.accessibility_role == 'checkbox'
	assert el.accessibility_value == 'checked'
}
