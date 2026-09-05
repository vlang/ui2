module main

import ui2

fn find_box_row_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_box_row_element(child, id) {
			return found
		}
	}
	return none
}

fn test_box_layout_inside_row_toggles_bounds() {
	mut app := initial_box_layout_inside_row()
	assert !app.moved
	app.toggle_position()
	assert app.moved
	assert app.status.contains('80%')
	app.toggle_position()
	assert !app.moved
}

fn test_box_layout_inside_row_qml_updates_percentage_geometry() {
	mut app := initial_box_layout_inside_row()
	initial_root := ui2.element_from_qml_model(box_row_qml_source, app, ui2.rect(0, 0, box_row_width, box_row_height)) or { panic(err) }
	stage := find_box_row_element(initial_root, 'stage') or { panic('missing stage') }
	initial_text := find_box_row_element(initial_root, 'moving_text') or {
		panic('missing moving text')
	}
	assert initial_text.frame.x == stage.frame.width * 0.7
	assert initial_text.frame.width == stage.frame.width * 0.3

	app.toggle_position()
	moved_root := ui2.element_from_qml_model(box_row_qml_source, app, ui2.rect(0, 0, box_row_width, box_row_height)) or { panic(err) }
	moved_text := find_box_row_element(moved_root, 'moving_text') or {
		panic('missing moved text')
	}
	assert moved_text.frame.x == stage.frame.width * 0.8
	assert moved_text.frame.width == stage.frame.width * 0.2
	assert (find_box_row_element(moved_root, 'move_text') or {
		panic('missing move button')
	}).native_style
}
