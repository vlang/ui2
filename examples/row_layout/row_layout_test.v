module main

import ui2

fn find_row_layout_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_row_layout_element(child, id) {
			return found
		}
	}
	return none
}

fn test_row_layout_updates_and_resets_all_dimensions() {
	mut app := RowLayoutDemo{}
	app.width_choice = '70 / 30'
	app.margin_choice = '40'
	app.spacing_choice = '36'
	app.height_choice = '60'
	app.layout_changed()
	assert app.first_ratio == 0.7
	assert app.row_margin == 40
	assert app.row_spacing == 36
	assert app.button_height == 60
	app.reset_layout()
	assert app.first_ratio == 0.3
	assert app.row_margin == 24
}

fn test_row_layout_vml_distributes_responsive_space() {
	app := RowLayoutDemo{}
	root := ui2.element_from_vml_model(row_layout_vml_source, app, ui2.rect(0, 0, row_layout_width, row_layout_height)) or { panic(err) }
	wide := ui2.element_from_vml_model(row_layout_vml_source, app, ui2.rect(0, 0, 960, row_layout_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	stage := find_row_layout_element(root, 'row_stage') or { panic('missing row stage') }
	first := find_row_layout_element(root, 'first_button') or { panic('missing first button') }
	second := find_row_layout_element(root, 'second_button') or { panic('missing second button') }
	wide_first := find_row_layout_element(wide, 'first_button') or { panic('missing wide button') }
	assert first.frame.x == app.row_margin
	assert second.frame.x == app.row_margin + first.frame.width + app.row_spacing
	assert first.frame.width + second.frame.width + app.row_spacing == stage.frame.width - app.row_margin * 2
	assert wide_first.frame.width > first.frame.width
	assert first.native_style
	assert (find_row_layout_element(root, 'reset_layout') or { panic('missing reset') }).native_style
}
