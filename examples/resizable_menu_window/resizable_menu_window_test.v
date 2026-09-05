module main

import ui2

fn find_menu_window_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_menu_window_element(child, id) {
			return found
		}
	}
	return none
}

fn test_resizable_menu_actions_update_feedback() {
	mut app := ResizableMenuDemo{}
	app.export_users()
	assert app.status == 'Export users selected.'
	app.delete_users()
	assert app.status == 'Delete users selected.'
	app.add_user()
	assert app.status == 'Add user selected.'
}

fn test_resizable_menu_qml_builds_native_context_menu() {
	app := ResizableMenuDemo{}
	root := ui2.element_from_qml_model(menu_window_qml_source, app, ui2.rect(0, 0, menu_window_width, menu_window_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	actions := find_menu_window_element(root, 'actions') or { panic('missing actions') }
	assert actions.native_style
	assert actions.menu.len == 4
	assert actions.menu[0].title == 'Delete all developers'
	assert actions.menu[2].title == 'Export users'
	assert actions.menu.all(it.id.len > 0)
	assert (find_menu_window_element(root, 'add_user') or {
		panic('missing add user')
	}).native_style
}
