module main

import ui2

fn find_grid_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_grid_element(child, id) {
			return found
		}
	}
	return none
}

fn test_grid_layout_demo_uses_responsive_equal_cells() {
	root := ui2.element_from_qml_model(grid_qml_source, GridLayoutDemo{}, ui2.rect(0, 0,
		grid_width, grid_height)) or { panic(err) }
	grid := find_grid_element(root, 'dashboard') or { panic('missing dashboard grid') }
	assert grid.children.len == 6
	assert grid.children[0].frame == ui2.rect(8, 8, 96, 78)
	assert grid.children[2].frame == ui2.rect(216, 8, 96, 78)
	assert grid.children[3].frame == ui2.rect(8, 94, 96, 78)
}
