module main

import ui2

fn find_toggle_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_toggle_element(child, id) {
			return found
		}
	}
	return none
}

fn test_toggle_button_demo_reflects_pressed_state() {
	mut app := ToggleButtonDemo{}
	released := ui2.element_from_qml_model(toggle_qml_source, app, ui2.rect(0, 0, toggle_width, toggle_height)) or { panic(err) }
	button := find_toggle_element(released, 'bold') or { panic('missing toggle button') }
	assert button.kind == .toggle_button
	assert !button.checked
	assert (find_toggle_element(released, 'state') or { panic('missing state') }).text == 'Released'

	app.bold = true
	pressed := ui2.element_from_qml_model(toggle_qml_source, app, ui2.rect(0, 0, toggle_width, toggle_height)) or { panic(err) }
	assert (find_toggle_element(pressed, 'bold') or { panic('missing toggle button') }).checked
	assert (find_toggle_element(pressed, 'state') or { panic('missing state') }).text == 'Pressed'
}
