module main

import ui2

fn find_gradient_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_gradient_element(child, id) {
			return found
		}
	}
	return none
}

fn test_gradient_texture_generates_expected_hsv_corners_and_cycles() {
	mut app := gradient_demo(0)
	assert app.cells.len == gradient_columns * gradient_rows
	assert app.cells[0].color == '#FFFFFF'
	assert app.cells[gradient_columns - 1].color == '#000000'
	assert app.cells[(gradient_rows - 1) * gradient_columns].color == '#FF0000'
	app.previous_hue()
	assert app.hue_name == 'Magenta'
	assert app.hue_color == '#FF00FF'
	app.next_hue()
	assert app.hue_name == 'Red'
}

fn test_gradient_texture_vml_builds_keyed_tiles_and_native_controls() {
	app := gradient_demo(0)
	root := ui2.element_from_vml_model(gradient_texture_vml_source, app, ui2.rect(0, 0, gradient_texture_width, gradient_texture_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	gradient := find_gradient_element(root, 'gradient') or { panic('missing gradient') }
	assert gradient.children.len == gradient_columns * gradient_rows
	assert gradient.children[0].key == '0'
	assert (find_gradient_element(root, 'previous_hue') or { panic('missing previous') }).native_style
	assert (find_gradient_element(root, 'next_hue') or { panic('missing next') }).native_style
}
