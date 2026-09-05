module main

import ui2

fn find_slider_textbox_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_slider_textbox_element(child, id) {
			return found
		}
	}
	return none
}

fn test_slider_textbox_synchronizes_ranges_and_validates_text() {
	mut app := slider_textbox_demo()
	app.set_horizontal_fraction(1)
	assert app.horizontal_value == 100
	assert app.horizontal_text == '100'
	app.set_vertical_fraction(0)
	assert app.vertical_value == -100
	app.apply_horizontal_text(' 25 ')
	assert app.horizontal_value == 25
	assert app.horizontal_valid
	app.apply_vertical_text('-12')
	assert !app.vertical_valid
	assert app.vertical_value == -100
}

fn test_slider_textbox_pointer_parser_and_qml_controls() {
	id, x, y := slider_pointer_coordinates('pointer:drag:horizontal_track:120.5:80.0') or {
		panic('pointer event did not parse')
	}
	assert id == 'horizontal_track'
	assert x == 120.5
	assert y == 80
	app := slider_textbox_demo()
	root := ui2.element_from_qml_model(slider_textbox_qml_source, app, ui2.rect(0, 0, slider_textbox_width, slider_textbox_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	track := find_slider_textbox_element(root, 'horizontal_track') or { panic('missing track') }
	assert track.clickable
	assert track.draggable
	assert (find_slider_textbox_element(root, 'reset') or { panic('missing reset') }).native_style
}
