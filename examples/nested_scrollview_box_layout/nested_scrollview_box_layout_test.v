module main

import ui2

fn find_nested_box_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_nested_box_element(child, id) {
			return found
		}
	}
	return none
}

fn test_nested_scroll_box_layout_builds_five_by_five_grid() {
	app := initial_nested_scroll_box_layout()
	assert app.boxes.len == 25
	assert app.boxes[0].row == 0
	assert app.boxes[0].column == 0
	assert app.boxes[24].row == 4
	assert app.boxes[24].column == 4
	assert app.boxes[24].content.starts_with('box 44')
}

fn test_nested_scroll_box_layout_vml_positions_editable_areas() {
	root := ui2.element_from_vml_model(nested_box_vml_source, initial_nested_scroll_box_layout(), ui2.rect(0, 0, nested_box_width, nested_box_height)) or {
		panic(err)
	}
	ui2.validate_element_tree(root) or { panic(err) }
	grid := find_nested_box_element(root, 'box_grid') or { panic('missing box grid') }
	assert grid.children.len == 25
	assert grid.children[0].key == '0'
	assert !grid.children[0].readonly
	assert grid.children[0].text.starts_with('box 00')
	assert grid.children[5].frame.y == 120
	assert grid.children[24].frame.y == 456
}
