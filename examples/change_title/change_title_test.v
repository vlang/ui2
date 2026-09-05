module main

import ui2

fn find_change_title_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_change_title_element(child, id) {
			return found
		}
	}
	return none
}

fn test_change_title_validates_and_applies_trimmed_title() {
	mut app := ChangeTitleDemo{ title: '   ' }
	app.apply_title()
	assert !app.valid
	assert app.applied_title == 'Name'
	app.title = '  Project dashboard  '
	app.apply_title()
	assert app.valid
	assert app.title == 'Project dashboard'
	assert app.applied_title == 'Project dashboard'
}

fn test_change_title_qml_has_submit_and_native_action() {
	root := ui2.element_from_qml_model(change_title_qml_source, ChangeTitleDemo{}, ui2.rect(0, 0, change_title_width, change_title_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	field := find_change_title_element(root, 'title') or { panic('missing title field') }
	button := find_change_title_element(root, 'apply_title') or { panic('missing title button') }
	assert field.submit_id.len > 0
	assert button.native_style
}
