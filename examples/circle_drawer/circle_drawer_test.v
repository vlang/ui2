module main

import ui2

fn find_circle_drawer_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_circle_drawer_element(child, id) {
			return found
		}
	}
	return none
}

fn test_circle_drawer_add_select_resize_undo_and_redo() {
	mut app := CircleDrawerDemo{}
	app.add_or_select(100, 80)
	app.add_or_select(220, 160)
	assert app.circles.len == 2
	app.add_or_select(100, 80)
	assert app.selected_id == 1
	app.adjust_radius(4)
	assert app.circles[0].radius == 28
	app.undo()
	assert app.circles[0].radius == 24
	app.undo()
	assert app.circles.len == 1
	app.redo()
	assert app.circles.len == 2
}

fn test_circle_drawer_vml_builds_clickable_canvas_and_keyed_circles() {
	mut app := CircleDrawerDemo{}
	app.add_or_select(120, 100)
	root := ui2.element_from_vml_model(circle_drawer_vml_source, app, ui2.rect(0, 0, circle_drawer_width, circle_drawer_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	canvas := find_circle_drawer_element(root, 'circle_canvas') or { panic('missing canvas') }
	assert canvas.clickable
	assert canvas.action_id == 'circle_canvas'
	assert canvas.children.len == 2
	assert canvas.children[1].key == '1'
	assert canvas.children[1].box.radius == 27
	assert (find_circle_drawer_element(root, 'undo') or { panic('missing undo') }).native_style
}
