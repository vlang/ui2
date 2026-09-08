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
	assert parse_hex_color('#GGGGGG') == u32(0xFFFFFF)
}

fn test_parse_requires_a_single_complete_root() {
	if _ := parse_qml('Label {} Button {}') {
		assert false, 'a second root must be rejected'
	}
	if _ := parse_qml('Label {} }') {
		assert false, 'a trailing brace must be rejected'
	}
}

fn test_plain_container_children_use_resolved_local_frame() {
	node := parse_qml('View { x: 30 y: 40 width: 200 height: 100 Label {} }') or {
		panic(err)
	}
	el := element_from_qnode(node, rect(0, 0, 800, 600)) or { panic(err) }
	assert el.frame == rect(30, 40, 200, 100)
	assert el.children[0].frame == rect(0, 0, 200, 100)
}

fn test_nested_child_coordinates_are_parent_local() {
	node := parse_qml('View { x: 30 y: 40 width: 200 height: 100 Label { x: 7 y: 9 width: 50 height: 20 } }') or {
		panic(err)
	}
	el := element_from_qnode(node, rect(0, 0, 800, 600)) or { panic(err) }
	assert el.children[0].frame == rect(7, 9, 50, 20)
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
		on_change: body_changed
		editable: false
		background: #FAFAFA
	}'
	node := parse_qml(source) or { panic(err) }
	assert node.tag == 'TextArea'
	el := element_from_qnode(node, rect(0, 0, 400, 300)) or { panic(err) }
	assert el.id == 'body'
	assert el.action_id == 'body_changed'
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
	assert el.id == ''
	assert el.action_id == 'open_row'
	assert el.menu.len == 2
	assert el.menu[0].title == 'Reply'
	assert el.menu[0].id == 'ctx_reply'
	assert el.menu[1].id == 'ctx_delete'
	// MenuItem children must not become subviews
	assert el.children.len == 0
}

fn test_qml_applies_shared_control_state_properties() {
	node := parse_qml('TextField { id: email hidden: true enabled: false autocorrect: false pad_left: 20 accessibility_role: text_field accessibility_label: "Email" }') or {
		panic(err)
	}
	el := element_from_qnode(node, rect(0, 0, 200, 40)) or { panic(err) }
	assert el.hidden
	assert !el.enabled
	assert !el.autocorrect
	assert el.padding_left == 20
	assert el.accessibility_role == 'text_field'
	assert el.accessibility_label == 'Email'
}

fn test_qml_applies_independent_box_borders() {
	node := parse_qml('Rectangle {
		background: #10131F
		border_color: #28314A
		border_left: 1
		border_top: 2.5
		border_right: 3
		border_bottom: 4
	}') or { panic(err) }
	el := element_from_qnode(node, rect(0, 0, 200, 100)) or { panic(err) }
	assert el.box.border_color == 0x28314a
	assert el.box.border_left == 1
	assert el.box.border_top == 2.5
	assert el.box.border_right == 3
	assert el.box.border_bottom == 4
}

fn test_qml_border_width_is_an_all_sides_shorthand_with_edge_overrides() {
	node := parse_qml('Button {
		text: "Panel"
		border_width: 2
		border_left: 0
		border_bottom: 5
	}') or { panic(err) }
	el := element_from_qnode(node, rect(0, 0, 120, 32)) or { panic(err) }
	assert el.box.border_left == 0
	assert el.box.border_top == 2
	assert el.box.border_right == 2
	assert el.box.border_bottom == 5
}

fn test_qml_scroll_preserves_box_borders() {
	node := parse_qml('Scroll {
		border_color: #334155
		border_left: 1
		border_right: 2
	}') or { panic(err) }
	el := element_from_qnode(node, rect(0, 0, 120, 80)) or { panic(err) }
	assert el.kind == .scroll
	assert el.box.border_color == 0x334155
	assert el.box.border_left == 1
	assert el.box.border_right == 2
}

fn test_qml_applies_pointer_and_transform_properties() {
	node := parse_qml('Image {
		id: movable_logo
		path: "logo.png"
		on_tap: move_logo
		clickable: true
		draggable: true
		long_press: true
		swipe_left: true
		rotation: 37.5
		cursor: "rotate"
	}') or { panic(err) }
	el := element_from_qnode(node, rect(0, 0, 100, 100)) or { panic(err) }
	assert el.action_id == 'move_logo'
	assert el.clickable
	assert el.draggable
	assert el.long_press
	assert el.swipe_left
	assert el.rotation == 37.5
	assert el.cursor == cursor_rotate
}

fn test_qml_applies_extended_text_style_properties() {
	node := parse_qml('Label {
		text: "Styled"
		color: #123456
		background_color: #F0F1F2
		font_size: 22
		font_family: "Courier New"
		bold: true
		italic: true
		underline: true
		strikethrough: true
		shadow: true
		outline: true
		vertical_align: superscript
		link: "https://vlang.io"
		head_indent: 12
		first_line_indent: 4
		hyphenation_factor: 0.5
	}') or { panic(err) }
	el := element_from_qnode(node, rect(0, 0, 200, 40)) or { panic(err) }
	assert el.text_style.color == 0x123456
	assert el.text_style.background_color == 0xf0f1f2
	assert el.text_style.size == 22
	assert el.text_style.font_family == 'Courier New'
	assert el.text_style.bold
	assert el.text_style.italic
	assert el.text_style.underline
	assert el.text_style.strikethrough
	assert el.text_style.shadow
	assert el.text_style.outline
	assert el.text_style.vertical_align == 'superscript'
	assert el.text_style.link == 'https://vlang.io'
	assert el.text_style.head_indent == 12
	assert el.text_style.first_line_indent == 4
	assert el.text_style.hyphenation_factor == 0.5
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
	assert el.id == 'message'
	assert el.action_id == 'message_changed'
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

fn test_qml_dropdown_options_persistent_scroll_and_tooltip() {
	source := 'Scroll {
		id: users
		persistent: true
		Dropdown {
			id: country
			text: "Canada"
			on_change: country_changed
			tooltip: "Choose a country"
			Option { text: "United States" }
			Option { text: "Canada" }
		}
	}'
	el := element_from_qml(source, rect(0, 0, 300, 200)) or { panic(err) }
	assert el.kind == .scroll
	assert el.persistent_scrollbars
	assert el.children.len == 1
	dropdown_el := el.children[0]
	assert dropdown_el.kind == .dropdown
	assert dropdown_el.id == 'country'
	assert dropdown_el.action_id == 'country_changed'
	assert dropdown_el.text == 'Canada'
	assert dropdown_el.tooltip == 'Choose a country'
	assert dropdown_el.menu.len == 2
	assert dropdown_el.menu[0].title == 'United States'
	assert dropdown_el.menu[1].title == 'Canada'
}

fn test_qml_decimal_keyboard() {
	el := element_from_qml('TextField { id: age keyboard: decimal }', rect(0, 0, 120, 32)) or { panic(err) }
	assert el.keyboard == keyboard_decimal
}

fn test_qml_progress_bar_uses_bounded_value_semantics() {
	el := element_from_qml('ProgressBar {
		id: loading
		value: 75
		max: 200
		background: #111827
		color: #22C55E
		corner_radius: 6
	}', rect(0, 0, 240, 16)) or { panic(err) }

	assert el.kind == .view
	assert el.id == 'loading'
	assert el.box.bg == u32(0x111827)
	assert el.box.radius == 6
	assert el.children.len == 1
	assert el.children[0].frame.width == 90
	assert el.children[0].box.bg == u32(0x22c55e)
	assert el.accessibility_role == 'progressbar'
	assert el.accessibility_value == '75 of 200'
}

fn test_qml_slider_exposes_range_orientation_and_style() {
	el := element_from_qml('Slider {
		id: volume
		on_change: volume_changed
		min: -20
		max: 80
		value: 55
		step: 5
		orientation: vertical
		padding: 10
		value_track: true
		background: #111827
		value_track_color: #22C55E
		thumb_color: #F8FAFC
		track_width: 6
		thumb_size: 24
	}', rect(0, 0, 32, 240)) or { panic(err) }

	assert el.kind == .slider
	assert el.id == 'volume'
	assert el.action_id == 'volume_changed'
	assert el.min_value == -20
	assert el.max_value == 80
	assert el.value == 55
	assert el.step == 5
	assert el.orientation == .vertical
	assert el.padding == 10
	assert el.value_track
	assert el.slider_style.track_color == u32(0x111827)
	assert el.slider_style.value_track_color == u32(0x22c55e)
	assert el.slider_style.thumb_color == u32(0xf8fafc)
	assert el.slider_style.track_width == 6
	assert el.slider_style.thumb_size == 24
	assert el.accessibility_role == 'slider'
	assert el.accessibility_value == '55'
}

fn test_qml_switch_exposes_active_state_action_and_style() {
	el := element_from_qml('Switch {
		id: airplane_mode
		on_active: airplane_mode_changed
		active: true
		inactive_color: #334155
		active_color: #16A34A
		thumb_color: #F8FAFC
		disabled_track_color: #64748B
		disabled_thumb_color: #CBD5E1
	}', rect(0, 0, 83, 32)) or { panic(err) }

	assert el.kind == .switch_control
	assert el.id == 'airplane_mode'
	assert el.action_id == 'airplane_mode_changed'
	assert el.checked
	assert el.switch_style.inactive_track_color == u32(0x334155)
	assert el.switch_style.active_track_color == u32(0x16a34a)
	assert el.switch_style.thumb_color == u32(0xf8fafc)
	assert el.switch_style.disabled_track_color == u32(0x64748b)
	assert el.switch_style.disabled_thumb_color == u32(0xcbd5e1)
	assert el.accessibility_role == 'switch'
	assert el.accessibility_value == 'on'
}

fn test_qml_spinner_exposes_values_selection_and_style() {
	el := element_from_qml('Spinner {
		id: location
		on_text: location_changed
		text_autoupdate: true
		background: #DBEAFE
		color: #1D4ED8
		corner_radius: 7
		Option { text: "Home" }
		Option { text: "Work" }
	}', rect(0, 0, 160, 42)) or { panic(err) }

	assert el.kind == .dropdown
	assert el.id == 'location'
	assert el.action_id == 'location_changed'
	assert el.text == 'Home'
	assert el.menu.len == 2
	assert el.menu[1].title == 'Work'
	assert el.box.bg == u32(0xdbeafe)
	assert el.text_style.color == u32(0x1d4ed8)
	assert el.accessibility_role == 'combobox'
	assert el.accessibility_value == 'Home'
}

fn test_qml_toggle_button_exposes_pressed_and_released_styles() {
	el := element_from_qml('ToggleButton {
		id: bold
		text: "Bold"
		on_state: bold_changed
		pressed: true
		background: #E2E8F0
		color: #1E293B
		down_background: #1D4ED8
		down_color: #FFFFFF
		group: formatting
		allow_no_selection: false
		corner_radius: 6
	}', rect(0, 0, 100, 40)) or { panic(err) }

	assert el.kind == .toggle_button
	assert el.action_id == 'bold_changed'
	assert el.checked
	assert el.toggle_group == 'formatting'
	assert !el.toggle_allow_no_selection
	assert el.box.bg == u32(0xe2e8f0)
	assert el.text_style.color == u32(0x1e293b)
	assert el.toggle_down_box.bg == u32(0x1d4ed8)
	assert el.toggle_down_box.radius == 6
	assert el.toggle_down_text_style.color == u32(0xffffff)
	assert el.accessibility_value == 'pressed'
}

fn test_qml_box_layout_combines_fixed_and_proportional_children() {
	el := element_from_qml('BoxLayout {
		id: actions
		padding: 10
		spacing: 10
		Button { text: "Fixed" width: 80 size_hint_x: -1 }
		Button { text: "Wide" size_hint_x: 2 }
		Button { text: "Narrow" size_hint_x: 1 }
	}', rect(20, 30, 330, 80)) or { panic(err) }
	assert el.frame == rect(20, 30, 330, 80)
	assert el.children[0].frame == rect(10, 10, 80, 60)
	assert el.children[1].frame == rect(100, 10, 140, 60)
	assert el.children[2].frame == rect(250, 10, 70, 60)
}

fn test_qml_vertical_box_layout_aligns_fixed_width_children() {
	el := element_from_qml('BoxLayout {
		orientation: vertical
		padding: 10
		spacing: 4
		Button { text: "Centered" width: 60 height: 20 size_hint_x: -1 size_hint_y: -1 align_x: center }
		Button { text: "Fill" }
	}', rect(0, 0, 200, 120)) or { panic(err) }
	assert el.children[0].frame == rect(70, 10, 60, 20)
	assert el.children[1].frame == rect(10, 34, 180, 76)
}

fn test_qml_box_layout_validates_orientation_names() {
	if _ := element_from_qml('BoxLayout { orientation: diagonal }', rect(0, 0, 100, 100)) {
		assert false, 'unknown box orientations must fail'
	} else {
		assert err.msg().contains('diagonal')
	}
}

fn test_qml_float_layout_applies_independent_size_and_position_hints() {
	el := element_from_qml('FloatLayout {
		Rectangle {
			id: card
			size_hint_x: 0.5
			size_hint_y: 0.25
			pos_hint_center_x: 0.5
			pos_hint_center_y: 0.5
		}
		Button {
			id: fixed
			x: 20
			y: 30
			width: 80
			height: 40
			size_hint_x: -1
			size_hint_y: -1
		}
	}', rect(10, 20, 300, 200)) or { panic(err) }
	assert el.children[0].frame == rect(75, 75, 150, 50)
	assert el.children[1].frame == rect(20, 30, 80, 40)
}

fn test_qml_float_layout_supports_edge_hints_and_bounds() {
	el := element_from_qml('FloatLayout {
		Button {
			size_hint_x: 0.9
			size_hint_y: 0.1
			size_hint_max_x: 120
			size_hint_min_y: 32
			pos_hint_right: 1
			pos_hint_bottom: 1
		}
	}', rect(0, 0, 300, 200)) or { panic(err) }
	assert el.children[0].frame == rect(180, 168, 120, 32)
}

fn test_qml_relative_layout_keeps_child_frames_local() {
	el := element_from_qml('RelativeLayout {
		x: 80
		y: 60
		width: 240
		height: 120
		Button {
			x: 20
			y: 15
			width: 80
			height: 30
			size_hint_x: -1
			size_hint_y: -1
		}
	}', rect(0, 0, 400, 240)) or { panic(err) }
	assert el.frame == rect(80, 60, 240, 120)
	assert el.children[0].frame == rect(20, 15, 80, 30)
}

fn test_qml_grid_layout_assigns_cells_in_the_requested_orientation() {
	el := element_from_qml('GridLayout {
		id: tools
		columns: 2
		orientation: rl-bt
		padding: 10
		spacing: 10
		Button { id: one text: "One" }
		Button { id: two text: "Two" }
		Button { id: three text: "Three" }
	}', rect(20, 30, 210, 110)) or { panic(err) }
	assert el.kind == .view
	assert el.frame == rect(20, 30, 210, 110)
	assert el.children.len == 3
	assert el.children[0].frame == rect(110, 60, 90, 40)
	assert el.children[1].frame == rect(10, 60, 90, 40)
	assert el.children[2].frame == rect(110, 10, 90, 40)
}

fn test_qml_grid_layout_requires_a_constraint() {
	if _ := element_from_qml('GridLayout { Button { text: "Missing constraint" } }', rect(0, 0, 200, 100)) {
		assert false, 'an unconstrained QML grid must fail'
	} else {
		assert err.msg().contains('requires columns or rows')
	}
}

fn test_qml_anchor_layout_positions_children_with_per_edge_padding() {
	el := element_from_qml('AnchorLayout {
		id: footer
		anchor_x: right
		anchor_y: bottom
		padding_left: 4
		padding_top: 6
		padding_right: 10
		padding_bottom: 12
		Button { id: save text: "Save" width: 72 height: 32 }
	}', rect(20, 30, 200, 100)) or { panic(err) }
	assert el.kind == .view
	assert el.frame == rect(20, 30, 200, 100)
	assert el.children.len == 1
	assert el.children[0].frame == rect(118, 56, 72, 32)
}

fn test_qml_anchor_layout_validates_anchor_names() {
	if _ := element_from_qml('AnchorLayout { anchor_x: middle }', rect(0, 0, 100, 100)) {
		assert false, 'unknown anchor names must fail'
	} else {
		assert err.msg().contains('middle')
	}
}

fn test_qml_stack_layout_wraps_variable_size_children() {
	el := element_from_qml('StackLayout {
		id: tags
		padding: 10
		spacing_x: 6
		spacing_y: 4
		Button { text: "One" width: 70 height: 20 }
		Button { text: "Two" width: 80 height: 30 }
		Button { text: "Three" width: 90 height: 24 }
	}', rect(20, 30, 180, 120)) or { panic(err) }
	assert el.children[0].frame == rect(10, 10, 70, 20)
	assert el.children[1].frame == rect(86, 10, 80, 30)
	assert el.children[2].frame == rect(10, 44, 90, 24)
}

fn test_qml_stack_layout_validates_orientation_names() {
	if _ := element_from_qml('StackLayout { orientation: sideways }', rect(0, 0, 100, 100)) {
		assert false, 'unknown stack orientations must fail'
	} else {
		assert err.msg().contains('sideways')
	}
}

fn test_qml_page_layout_exposes_adjacent_page_borders() {
	el := element_from_qml('PageLayout {
		page: 1
		border: 40
		Rectangle { id: first }
		Rectangle { id: second }
		Rectangle { id: third }
	}', rect(10, 20, 300, 160)) or { panic(err) }
	assert el.frame == rect(10, 20, 300, 160)
	assert el.children[0].frame == rect(0, 0, 260, 160)
	assert el.children[1].frame == rect(20, 0, 260, 160)
	assert el.children[2].frame == rect(280, 0, 260, 160)
}

fn test_qml_page_layout_validates_border() {
	if _ := element_from_qml('PageLayout { border: 120 Rectangle {} }', rect(0, 0, 100, 100)) {
		assert false, 'a border wider than the page layout must fail'
	} else {
		assert err.msg().contains('border')
	}
}

fn test_qml_widget_accessibility_defaults_survive_conversion() {
	checkbox_el := element_from_qml('Checkbox { text: "Ready" checked: true }', rect(0, 0, 120, 24)) or {
		panic(err)
	}
	assert checkbox_el.accessibility_role == 'checkbox'
	assert checkbox_el.accessibility_label == 'Ready'
	assert checkbox_el.accessibility_value == 'checked'

	progress_el := element_from_qml('ProgressBar { value: 150 }', rect(0, 0, 100, 8)) or {
		panic(err)
	}
	assert progress_el.children[0].frame.width == 100
	assert progress_el.accessibility_value == '100 of 100'
}

fn test_qml_text_input_defaults_to_multiline() {
	el := element_from_qml('TextInput {
		id: notes
		text: "One\\nTwo"
		hint_text: "Notes"
		on_text: notes_changed
		readonly: true
		disable_scroll: true
	}', rect(0, 0, 240, 120)) or { panic(err) }
	assert el.kind == .text_area
	assert el.text == 'One\nTwo'
	assert el.placeholder == 'Notes'
	assert el.action_id == 'notes_changed'
	assert el.readonly
	assert el.disable_scroll
}

fn test_qml_text_input_supports_single_line_password_submission() {
	el := element_from_qml('TextInput {
		id: password
		multiline: false
		password: true
		hint_text: "Password"
		on_text_validate: sign_in
		autocorrect: false
		padding: 8
	}', rect(0, 0, 200, 36)) or { panic(err) }
	assert el.kind == .text_field
	assert el.secure
	assert el.placeholder == 'Password'
	assert el.submit_id == 'sign_in'
	assert !el.autocorrect
	assert el.padding_left == 8
}

fn test_qml_tabbed_panel_builds_headers_and_active_content() {
	el := element_from_qml('TabbedPanel {
		id: settings
		current: 1
		tab_pos: bottom_right
		tab_width: 100
		active_tab_background: #2563EB
		Tab { id: general text: "General" Label { text: "General content" } }
		Tab { id: account text: "Account" on_select: select_account Label { text: "Account content" } }
		Tab { id: privacy text: "Privacy" Label { text: "Privacy content" } }
	}', rect(10, 20, 360, 200)) or { panic(err) }
	assert el.frame == rect(10, 20, 360, 200)
	assert el.children.len == 4
	assert el.children[0].children[0].text == 'Account content'
	assert el.children[1].frame == rect(60, 160, 100, 40)
	assert el.children[2].frame == rect(160, 160, 100, 40)
	assert el.children[2].box.bg == u32(0x2563eb)
	assert el.children[2].action_id == 'select_account'
	assert el.children[2].accessibility_value == 'selected'
}

fn test_qml_tabbed_panel_validates_tab_position() {
	if _ := element_from_qml('TabbedPanel { tab_pos: diagonal }', rect(0, 0, 300, 200)) {
		assert false, 'invalid tab positions must fail'
	} else {
		assert err.msg().contains('diagonal')
	}
}

fn test_qml_accordion_builds_headers_and_active_content() {
	el := element_from_qml('Accordion {
		id: help
		current: 1
		orientation: vertical
		min_space: 40
		active_title_background: #2563EB
		AccordionItem { id: start title: "Getting started" Label { text: "Start content" } }
		AccordionItem { id: account title: "Account" on_select: select_account Label { text: "Account content" } }
		AccordionItem { id: privacy title: "Privacy" Label { text: "Privacy content" } }
	}', rect(10, 20, 300, 240)) or { panic(err) }
	assert el.frame == rect(10, 20, 300, 240)
	assert el.children.len == 4
	assert el.children[0].children[0].text == 'Account content'
	assert el.children[1].frame == rect(0, 0, 300, 40)
	assert el.children[2].frame == rect(0, 40, 300, 40)
	assert el.children[2].box.bg == u32(0x2563eb)
	assert el.children[2].action_id == 'select_account'
	assert el.children[2].accessibility_value == 'expanded'
	assert el.children[3].frame == rect(0, 200, 300, 40)
}

fn test_qml_accordion_validates_available_title_space() {
	if _ := element_from_qml('Accordion {
		orientation: vertical
		min_space: 40
		AccordionItem {}
		AccordionItem {}
		AccordionItem {}
	}', rect(0, 0, 200, 100)) {
		assert false, 'insufficient accordion title space must fail'
	} else {
		assert err.msg().contains('enough space')
	}
}

fn test_qml_tree_view_flattens_expanded_nodes_and_styles_selection() {
	el := element_from_qml('TreeView {
		id: navigation
		row_height: 32
		spacing: 4
		indent: 20
		disclosure_width: 24
		selected_background: #DBEAFE
		TreeNode {
			id: docs
			text: "Documentation"
			expanded: true
			on_toggle: toggle_docs
			TreeNode { id: guide text: "Guide" TreeNode { id: install text: "Install" } }
			TreeNode { id: api text: "API" selected: true on_select: select_api }
		}
		TreeNode { id: license text: "License" }
	}', rect(10, 20, 300, 200)) or { panic(err) }
	assert el.frame == rect(10, 20, 300, 200)
	assert el.accessibility_role == 'tree'
	assert el.children.len == 4
	assert el.children[0].children[0].action_id == 'toggle_docs'
	assert el.children[0].children[0].accessibility_value == 'expanded'
	assert el.children[1].children[1].frame == rect(44, 0, 256, 32)
	assert el.children[2].frame == rect(0, 72, 300, 32)
	assert el.children[2].children[1].box.bg == u32(0xdbeafe)
	assert el.children[2].children[1].action_id == 'select_api'
	assert el.children[2].children[1].accessibility_value == 'selected'
}

fn test_qml_tree_view_validates_geometry() {
	if _ := element_from_qml('TreeView { row_height: -1 }', rect(0, 0, 300, 200)) {
		assert false, 'negative tree row height must fail'
	} else {
		assert err.msg().contains('geometry')
	}
}

fn test_qml_screen_manager_renders_only_named_active_screen() {
	el := element_from_qml('ScreenManager {
		id: navigation
		current: details
		Screen { id: home Label { text: "Home content" } }
		Screen { id: details background: #EFF6FF Label { text: "Details content" } }
		Screen { id: settings Label { text: "Settings content" } }
	}', rect(10, 20, 320, 200)) or { panic(err) }
	assert el.frame == rect(10, 20, 320, 200)
	assert el.children.len == 1
	assert el.children[0].id == 'details'
	assert el.children[0].frame == rect(0, 0, 320, 200)
	assert el.children[0].box.bg == u32(0xeff6ff)
	assert el.children[0].children[0].text == 'Details content'
}

fn test_qml_screen_manager_validates_current_name() {
	if _ := element_from_qml('ScreenManager {
		current: missing
		Screen { id: home }
	}', rect(0, 0, 300, 200)) {
		assert false, 'unknown current screens must fail'
	} else {
		assert err.msg().contains('missing')
	}
}
