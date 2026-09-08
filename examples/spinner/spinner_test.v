module main

import ui2

fn find_spinner_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_spinner_element(child, id) {
			return found
		}
	}
	return none
}

fn test_spinner_demo_exposes_values_and_selection_feedback() {
	mut app := SpinnerDemo{}
	root := ui2.element_from_vml_model(spinner_vml_source, app, ui2.rect(0, 0, spinner_width, spinner_height)) or { panic(err) }
	control := find_spinner_element(root, 'location') or { panic('missing spinner') }
	assert control.kind == .dropdown
	assert control.text == 'Home'
	assert control.menu.map(it.title) == ['Home', 'Work', 'Other']
	assert control.accessibility_role == 'combobox'

	app.selection = 'Work'
	app.selection_changed()
	assert app.message == 'Work selected.'
}
