module main

import ui2

fn find_dynamic_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_dynamic_element(child, id) {
			return found
		}
	}
	return none
}

fn test_dynamic_layout_adds_removes_moves_hides_and_renames() {
	mut app := initial_dynamic_layout()
	app.add_two()
	assert app.items.map(it.id) == [1, 2, 3]
	assert app.status == '3 buttons'
	app.remove_second()
	assert app.items.map(it.id) == [1, 3]
	app.move_first()
	assert app.items.map(it.id) == [3, 1]
	app.rename(3)
	assert app.items[0].label == 'Button 3 ✓'
	app.toggle_items()
	assert app.items_hidden
	app.remove_last()
	assert app.status == '1 button'
}

fn test_dynamic_layout_vml_builds_keyed_native_buttons() {
	mut app := initial_dynamic_layout()
	app.add_two()
	root := ui2.element_from_vml_model(dynamic_layout_vml_source, app, ui2.rect(0, 0, dynamic_layout_width, dynamic_layout_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	list := find_dynamic_element(root, 'item_list') or { panic('missing generated list') }
	assert list.children.len == 3
	assert list.children[0].key == '1'
	assert list.children[0].native_style
	assert (find_dynamic_element(root, 'add_last') or { panic('missing add button') }).native_style
	assert (find_dynamic_element(root, 'remove_second') or { panic('missing remove button') }).enabled

	app.toggle_items()
	hidden_root := ui2.element_from_vml_model(dynamic_layout_vml_source, app, ui2.rect(0, 0, dynamic_layout_width, dynamic_layout_height)) or { panic(err) }
	assert (find_dynamic_element(hidden_root, 'item_list') or { panic('missing hidden list') }).hidden
	assert !(find_dynamic_element(hidden_root, 'hidden_message') or {
		panic('missing hidden-state message')
	}).hidden
}
