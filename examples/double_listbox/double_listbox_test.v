module main

import ui2

fn find_double_list_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_double_list_element(child, id) {
			return found
		}
	}
	return none
}

fn test_double_listbox_moves_values_both_directions() {
	mut app := initial_double_listbox()
	app.move_right(2)
	app.move_right(4)
	assert app.available.map(it.id) == [1, 3, 5]
	assert app.selected.map(it.id) == [2, 4]
	app.move_left(2)
	assert app.available.map(it.id) == [1, 3, 5, 2]
	assert app.selected.map(it.id) == [4]
	app.show_values()
	assert app.status == 'Selected: Delta'
	app.reset()
	assert app.available.len == 5
	assert app.selected.len == 0
}

fn test_double_listbox_vml_builds_keyed_native_rows() {
	mut app := initial_double_listbox()
	app.move_right(3)
	root := ui2.element_from_vml_model(double_list_vml_source, app, ui2.rect(0, 0, double_list_width, double_list_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	available := find_double_list_element(root, 'available_list') or {
		panic('missing available list')
	}
	selected := find_double_list_element(root, 'selected_list') or {
		panic('missing selected list')
	}
	assert available.children.len == 4
	assert selected.children.len == 1
	assert selected.children[0].key == '3'
	assert selected.children[0].native_style
	assert (find_double_list_element(root, 'reset_lists') or {
		panic('missing reset button')
	}).native_style
	assert (find_double_list_element(root, 'show_values') or {
		panic('missing values button')
	}).native_style
}
