module main

import ui2

fn find_transitions_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_transitions_element(child, id) {
			return found
		}
	}
	return none
}

fn test_transition_selects_each_canvas_target() {
	mut app := TransitionsDemo{}
	app.select_target(500, 300)
	assert app.target_label == 'Bottom right'
	assert app.target_x == 394
	assert app.target_y == 194
	assert app.moving
}

fn test_transitions_vml_has_moving_logo_and_native_slide_button() {
	app := TransitionsDemo{}
	root := ui2.element_from_vml_model(transitions_vml_source, app, ui2.rect(0, 0, transitions_width, transitions_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	stage := find_transitions_element(root, 'stage') or { panic('missing stage') }
	assert stage.children.len == 2
	assert stage.children[1].frame.x == 24
	assert stage.children[1].id == 'moving_tile'
	assert (find_transitions_element(root, 'slide') or { panic('missing slide') }).native_style
}
