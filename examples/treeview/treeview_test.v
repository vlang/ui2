module main

import ui2

fn find_treeview_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_treeview_element(child, id) {
			return found
		}
	}
	return none
}

fn test_treeview_expands_nested_folder_and_selects_file() {
	mut app := initial_treeview()
	assert app.visible.len == 10
	app.select_node(4)
	assert app.visible.len == 12
	assert app.status == 'tttytyty1 expanded.'
	app.select_node(5)
	assert app.status == 'file: tutu2 selected.'
	app.select_node(1)
	assert app.visible.len == 7
	assert app.status == 'toto1 collapsed.'
}

fn test_treeview_vml_builds_indented_native_rows() {
	mut app := initial_treeview()
	app.select_node(4)
	root := ui2.element_from_vml_model(treeview_vml_source, app, ui2.rect(0, 0, treeview_width, treeview_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	list := find_treeview_element(root, 'tree_list') or { panic('missing tree list') }
	assert list.children.len == 12
	assert list.children[0].native_style
	assert list.children[0].text.starts_with('▾')
	assert list.children[4].frame.x == 56
	assert list.children[4].key == '5'
}
