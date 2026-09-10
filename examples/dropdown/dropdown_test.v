module main

import ui2

fn find_dropdown_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_dropdown_element(child, id) {
			return found
		}
	}
	return none
}

fn test_dropdown_updates_visible_feedback() {
	mut app := DropdownDemo{}
	app.selection = 'Export users'
	app.selection_changed()
	assert app.message == 'Export users selected.'
}

fn test_dropdown_vml_contains_all_options() {
	app := DropdownDemo{}
	root := ui2.element_from_vml_model(dropdown_vml_source, app, ui2.rect(0, 0, dropdown_width, dropdown_height)) or { panic(err) }
	actions := find_dropdown_element(root, 'actions') or { panic('missing actions dropdown') }
	assert actions.text == 'Select an option'
	assert actions.menu.len == 3
	assert actions.menu[0].title == 'Delete all users'
	assert actions.menu[2].title == 'Exit'
	assert actions.action_id.len > 0
	message := find_dropdown_element(root, 'selection-message') or {
		panic('missing selection message')
	}
	assert message.frame.y == 19
	assert message.frame.height == 18
}
