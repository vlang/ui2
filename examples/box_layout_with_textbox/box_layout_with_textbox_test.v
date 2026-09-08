module main

import ui2

fn find_box_textbox_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_box_textbox_element(child, id) {
			return found
		}
	}
	return none
}

fn test_box_layout_textbox_updates_status() {
	mut app := initial_box_layout_textbox()
	app.text = 'first\nsecond'
	app.text_changed()
	assert app.status == '2 lines, 12 characters'
	app.show_message()
	assert app.status == 'coucou toto!'
}

fn test_box_layout_textbox_vml_keeps_percentage_geometry() {
	root := ui2.element_from_vml_model(box_textbox_vml_source, initial_box_layout_textbox(), ui2.rect(0, 0, box_textbox_width, box_textbox_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	canvas := find_box_textbox_element(root, 'canvas') or { panic('missing canvas') }
	notes := find_box_textbox_element(root, 'notes') or { panic('missing notes') }
	assert notes.frame.x == canvas.frame.width / 2
	assert notes.frame.y == canvas.frame.height / 2
	assert !notes.readonly
	assert (find_box_textbox_element(root, 'show_message') or {
		panic('missing message button')
	}).native_style
	assert (find_box_textbox_element(root, 'nested_anchor') or {
		panic('missing nested anchor')
	}).frame.width == 38
}
