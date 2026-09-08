module main

import ui2

fn find_clipping_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_clipping_element(child, id) {
			return found
		}
	}
	return none
}

fn test_nested_clipping_starts_fully_clipped_in_drawing_order() {
	app := nested_clipping_demo()
	assert app.boxes.len == 16
	assert app.boxes.map(it.order)[..5] == ['1st', '2nd', '3rd', '4th', '5th']
	assert app.boxes[0].column == 0 && app.boxes[0].row == 0
	assert app.boxes[3].column == 1 && app.boxes[3].row == 1
	assert app.boxes[15].column == 3 && app.boxes[15].row == 3
	assert app.boxes.all(it.clipping)
	assert app.status == 'Clipped boxes per quadrant — 1: 4/4 · 2: 4/4 · 3: 4/4 · 4: 4/4'
}

fn test_nested_clipping_toggles_single_boxes_and_whole_quadrants() {
	mut app := nested_clipping_demo()
	app.toggle_box(6)
	assert !app.boxes[5].clipping
	assert app.status.contains('2: 3/4')
	// A partly clipped quadrant clips as a whole before it unclips.
	app.toggle_quadrant(2)
	assert app.boxes.filter(it.quadrant == 2).all(it.clipping)
	app.toggle_quadrant(2)
	assert app.boxes.filter(it.quadrant == 2).all(!it.clipping)
	assert app.status.contains('2: 0/4')
	app.clip_none()
	assert app.boxes.all(!it.clipping)
	app.clip_all()
	assert app.boxes.all(it.clipping)
}

fn test_nested_clipping_vml_swaps_a_scroll_viewport_for_the_spilling_bars() {
	mut app := nested_clipping_demo()
	app.toggle_box(1)
	frame := ui2.rect(0, 0, nested_clipping_width, nested_clipping_height)
	root := ui2.element_from_vml_model(nested_clipping_vml_source, app, frame) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	stage := find_clipping_element(root, 'stage') or { panic('missing stage') }
	assert stage.children.len == 16
	first := stage.children[0]
	assert first.key == 'box-1'
	// The 4x4 grid has to stay inside the stage it is padded into.
	last := stage.children[15]
	assert last.frame.x + last.frame.width <= stage.frame.width - 10
	assert last.frame.y + last.frame.height <= stage.frame.height - 10
	// The first box was unclipped, so its viewport is hidden and the bare bars show.
	assert first.children[0].hidden
	assert !first.children[1].hidden
	assert first.children[1].frame.x == -70
	second := stage.children[1]
	assert !second.children[0].hidden
	assert second.children[1].hidden
	assert (find_clipping_element(root, 'quadrant3') or { panic('missing quadrant button') }).native_style
}
