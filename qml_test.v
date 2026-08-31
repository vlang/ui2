module ui2

fn testsuite_begin() {
	println('--- QML parser tests ---')
}

fn test_parse_simple_label() {
	source := 'Label {
		text: "Hello"
		color: #ECECEC
		font_size: 32
		bold: true
	}'
	node := parse_qml(source) or { panic(err) }
	assert node.tag == 'Label'
	assert node.prop('text') == 'Hello'
	assert node.prop('color') == '#ECECEC'
	assert node.prop_int('font_size') == 32
	assert node.prop_bool('bold') == true
}

fn test_parse_nested() {
	source := 'Column {
		spacing: 12
		padding: 20

		Label {
			text: "Title"
			align: center
		}

		Button {
			text: "OK"
			on_tap: handle_ok
		}
	}'
	node := parse_qml(source) or { panic(err) }
	assert node.tag == 'Column'
	assert node.prop_int('spacing') == 12
	assert node.children.len == 2
	assert node.children[0].tag == 'Label'
	assert node.children[0].prop('text') == 'Title'
	assert node.children[1].tag == 'Button'
	assert node.children[1].prop('on_tap') == 'handle_ok'
}

fn test_find_by_id() {
	source := 'Column {
		TextField {
			id: username
			placeholder: "Username"
		}
		TextField {
			id: password
			placeholder: "Password"
			secure: true
		}
		Button {
			id: login_btn
			text: "Log In"
		}
	}'
	node := parse_qml(source) or { panic(err) }
	pwd := node.find('password') or { panic('not found') }
	assert pwd.prop('placeholder') == 'Password'
	assert pwd.prop_bool('secure') == true
	btn := node.find('login_btn') or { panic('not found') }
	assert btn.prop('text') == 'Log In'
}

fn test_parse_comments() {
	source := '// Login screen
	Column {
		// Title
		Label {
			text: "Volt"
		}
		// Submit
		Button {
			text: "Go"
		}
	}'
	node := parse_qml(source) or { panic(err) }
	assert node.children.len == 2
}

fn test_parse_login_screen() {
	source := 'Column {
		background: #303338
		padding: 40
		spacing: 12

		Label {
			text: "Volt"
			color: #ECECEC
			font_size: 32
			bold: true
			align: center
			height: 40
		}

		TextField {
			id: username
			placeholder: "Username"
			background: #383A40
			color: #ECECEC
			corner_radius: 8
			height: 44
			autocapitalize: none
			autocorrect: false
			pad_left: 12
		}

		TextField {
			id: password
			placeholder: "Password"
			background: #383A40
			color: #ECECEC
			corner_radius: 8
			height: 44
			secure: true
			pad_left: 12
		}

		Label {
			id: error_label
			color: #F23F42
			font_size: 14
			align: center
			hidden: true
			height: 30
		}

		Button {
			text: "Log In"
			color: #ECECEC
			background: #05A7FC
			corner_radius: 8
			height: 44
			on_tap: do_login
		}
	}'
	node := parse_qml(source) or { panic(err) }
	assert node.tag == 'Column'
	assert node.children.len == 5
	assert node.prop('background') == '#303338'

	user_field := node.find('username') or { panic('username not found') }
	assert user_field.tag == 'TextField'
	assert user_field.prop('placeholder') == 'Username'

	err_label := node.find('error_label') or { panic('error_label not found') }
	assert err_label.prop_bool('hidden') == true
}

fn test_parse_hex_color() {
	assert parse_hex_color('#303338') == u32(0x303338)
	assert parse_hex_color('#FFFFFF') == u32(0xFFFFFF)
	assert parse_hex_color('#05A7FC') == u32(0x05A7FC)
	assert parse_hex_color('FF0000') == u32(0xFF0000)
}

fn test_parse_escaped_string() {
	source := 'Label {
		text: "Hello \\"World\\""
	}'
	node := parse_qml(source) or { panic(err) }
	assert node.prop('text') == 'Hello "World"'
}

fn test_parse_row() {
	source := 'Row {
		spacing: 10

		Button {
			text: "Accept"
			width: 100
		}

		Button {
			text: "Decline"
			width: 100
		}
	}'
	node := parse_qml(source) or { panic(err) }
	assert node.tag == 'Row'
	assert node.children.len == 2
	assert node.children[0].prop('text') == 'Accept'
	assert node.children[1].prop('text') == 'Decline'
}

fn test_parse_text_area() {
	source := 'TextArea {
		id: body
		text: "line one\\nline two"
		editable: false
		background: #FAFAFA
	}'
	node := parse_qml(source) or { panic(err) }
	assert node.tag == 'TextArea'
	el := element_from_qnode(node, rect(0, 0, 400, 300)) or { panic(err) }
	assert el.id == 'body'
	assert el.readonly == true
	assert el.text.contains('line two')
}

fn test_parse_menu_items() {
	source := 'Button {
		text: "Row"
		on_tap: open_row
		key: row42

		MenuItem {
			text: "Reply"
			on_tap: ctx_reply
		}
		MenuItem {
			text: "Delete"
			on_tap: ctx_delete
		}
	}'
	node := parse_qml(source) or { panic(err) }
	el := element_from_qnode(node, rect(0, 0, 100, 30)) or { panic(err) }
	assert el.key == 'row42'
	assert el.menu.len == 2
	assert el.menu[0].title == 'Reply'
	assert el.menu[0].id == 'ctx_reply'
	assert el.menu[1].id == 'ctx_delete'
	// MenuItem children must not become subviews
	assert el.children.len == 0
}

fn test_parse_text_field_change_and_submit_events() {
	source := 'TextField {
		id: message
		text: "hello"
		on_change: message_changed
		on_submit: send_message
		secure: true
	}'
	node := parse_qml(source) or { panic(err) }
	el := element_from_qnode(node, rect(0, 0, 200, 40)) or { panic(err) }
	assert el.kind == .text_field
	assert el.id == 'message_changed'
	assert el.submit_id == 'send_message'
	assert el.emit_change
	assert el.secure
}

fn test_parse_submit_only_text_field() {
	source := 'TextField {
		id: search
		on_submit: run_search
	}'
	node := parse_qml(source) or { panic(err) }
	el := element_from_qnode(node, rect(0, 0, 200, 40)) or { panic(err) }
	assert el.id == 'search'
	assert el.submit_id == 'run_search'
	assert !el.emit_change
}
