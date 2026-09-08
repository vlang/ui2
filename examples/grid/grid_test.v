module main

import ui2

fn find_grid_text(element ui2.Element, value string) ?ui2.Element {
	if element.text == value {
		return element
	}
	for child in element.children {
		if found := find_grid_text(child, value) {
			return found
		}
	}
	return none
}

fn test_grid_model_flattens_headers_and_rows() {
	app := initial_grid()
	assert app.cells.len == 9
	assert app.cells[0].header
	assert app.cells[0].text == 'One'
	assert !app.cells[3].header
	assert app.cells[8].text == 'Beautiful'
}

fn test_grid_vml_renders_every_cell_in_a_responsive_table() {
	root := ui2.element_from_vml_model(grid_vml_source, initial_grid(), ui2.rect(0, 0, grid_width, grid_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	header := find_grid_text(root, 'One') or { panic('missing first header') }
	assert header.text_style.bold
	assert header.text_style.color == 0xffffff
	last := find_grid_text(root, 'Beautiful') or { panic('missing final cell') }
	assert last.frame.height == 42
}
