module ui2

fn test_key_code_names_match_normalized_shortcut_names() {
	assert KeyCode.n.name() == 'n'
	assert KeyCode.comma.name() == ','
	assert KeyCode._7.name() == '7'
	assert KeyCode.delete.name() == 'forward_delete'
	assert KeyCode.kp_7.name() == '7'
	assert KeyCode.kp_enter.name() == 'enter'
	assert KeyCode.invalid.name() == ''
}

fn test_transparent_box_does_not_draw_a_fill() {
	assert box_draws_fill(BoxStyle{})
	assert !box_draws_fill(BoxStyle{
		bg: 0xff00ff
		transparent: true
	})
}

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

fn test_button_view_preserves_its_composite_content() {
	caption := label('caption', 'Save', rect(12, 8, 96, 24), TextStyle{
		color: 0xffffff
		bold:  true
	})
	el := button_view('save', rect(20, 30, 120, 40), BoxStyle{
		bg:     0x2563eb
		radius: 8
	}, [caption])

	assert el.kind == .view
	assert el.id == 'save'
	assert el.frame == rect(20, 30, 120, 40)
	assert el.box.bg == 0x2563eb
	assert el.box.radius == 8
	assert el.button_behavior
	assert !el.clickable
	assert el.accessibility_role == 'button'
	assert el.accessibility_label == 'Save'
	assert el.children.len == 1
	assert el.children[0].id == 'caption'
	assert el.children[0].text == 'Save'
}

fn test_with_button_behavior_preserves_a_view_and_explicit_accessibility_role() {
	base := with_action(view('save_card', rect(4, 6, 180, 56), BoxStyle{
		bg: 0xf8fafc
	}, [label('save_card_title', 'Save changes', rect(16, 12, 148, 24), TextStyle{})]),
		'persist_changes')
	el := with_button_behavior(base)

	assert el.kind == .view
	assert el.id == 'save_card'
	assert el.action_id == 'persist_changes'
	assert el.frame == base.frame
	assert el.box == base.box
	assert el.children == base.children
	assert el.button_behavior
	assert !el.clickable
	assert el.accessibility_role == 'button'

	link := with_button_behavior(Element{
		...base
		accessibility_role: 'link'
	})
	assert link.button_behavior
	assert link.accessibility_role == 'link'
}

fn test_button_behavior_only_decorates_views_and_skips_interactive_child_labels() {
	ordinary_button := button('save', 'Save', rect(0, 0, 80, 32), BoxStyle{}, TextStyle{})
	assert !with_button_behavior(ordinary_button).button_behavior

	composite := button_view('card', rect(0, 0, 160, 48), BoxStyle{}, [
		Element{
			...label('hidden', 'Hidden caption', rect(0, 0, 100, 20), TextStyle{})
			hidden: true
		},
		button('nested', 'Nested action', rect(0, 0, 100, 20), BoxStyle{}, TextStyle{}),
		label('caption', 'Card action', rect(0, 20, 100, 20), TextStyle{}),
	])
	assert composite.accessibility_label == 'Card action'
}

fn test_scroll_mode_defaults_to_vertical_and_content_width_follows_the_children() {
	assert scroll('list', rect(0, 0, 100, 100), 0xffffff, []).scroll_mode == .vertical_only
	columns := scroll_with_mode('columns', rect(0, 0, 100, 100), 0xffffff, .horizontal_only, [
		view('', rect(0, 0, 180, 100), BoxStyle{}, []),
		view('', rect(180, 0, 180, 100), BoxStyle{}, []),
		Element{
			kind: .view
			frame: rect(360, 0, 180, 100)
			hidden: true
		},
	])
	assert columns.kind == .scroll
	assert columns.scroll_mode == .horizontal_only
	assert scroll_content_width(columns.children) == 360
	assert scroll_content_width([]) == 0
	assert scroll_mode('horizontal')! == .horizontal_only
	assert scroll_mode('both')! == .both
}

fn test_scroll_mode_offset_keeps_only_the_axes_the_mode_scrolls() {
	x, y := scroll_mode_offset(.both, 120, 80)
	assert x == 120
	assert y == 80
	// A view scrolled both ways and then switched to one axis is brought back to the
	// start of the other.
	strip_x, strip_y := scroll_mode_offset(.horizontal_only, 120, 80)
	assert strip_x == 120
	assert strip_y == 0
	list_x, list_y := scroll_mode_offset(.vertical_only, 120, 80)
	assert list_x == 0
	assert list_y == 80
}
