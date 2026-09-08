module ui2

fn test_text_input_defaults_to_multiline_editor() {
	el := text_input(
		id: 'notes'
		frame: rect(0, 0, 240, 120)
		text: 'One\nTwo'
		hint_text: 'Notes'
		action_id: 'notes_changed'
	) or { panic(err) }
	assert el.kind == .text_area
	assert el.text == 'One\nTwo'
	assert el.placeholder == 'Notes'
	assert el.action_id == 'notes_changed'
	assert el.emit_change
}

fn test_text_input_single_line_supports_submit_and_password() {
	el := text_input(
		id: 'password'
		frame: rect(0, 0, 200, 36)
		text: 'secret'
		hint_text: 'Password'
		multiline: false
		password: true
		submit_id: 'sign_in'
		autocorrect: false
		padding_left: 8
	) or { panic(err) }
	assert el.kind == .text_field
	assert el.secure
	assert el.submit_id == 'sign_in'
	assert !el.emit_change
	assert !el.autocorrect
	assert el.padding_left == 8
}

fn test_text_input_preserves_readonly_and_disabled_state() {
	el := text_input(
		id: 'preview'
		frame: rect(0, 0, 200, 36)
		multiline: false
		readonly: true
		enabled: false
	) or { panic(err) }
	assert el.kind == .text_field
	assert el.readonly
	assert !el.enabled
}

fn test_text_input_rejects_multiline_password_mode() {
	if _ := text_input(TextInputConfig{ password: true }) {
		assert false, 'multiline secure entry must fail explicitly'
	} else {
		assert err.msg().contains('single-line')
	}
}
