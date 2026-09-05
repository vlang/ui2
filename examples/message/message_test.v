module main

import ui2

fn find_message_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_message_element(child, id) {
			return found
		}
	}
	return none
}

fn test_message_demo_opens_and_closes() {
	mut app := MessageDemo{}
	assert app.visible
	app.close_message()
	assert !app.visible
	app.show_message()
	assert app.visible
}

fn test_message_qml_contains_visible_dialog_and_native_actions() {
	root := ui2.element_from_qml_model(message_qml_source, MessageDemo{}, ui2.rect(0, 0, message_width, message_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	overlay := find_message_element(root, 'overlay') or { panic('missing overlay') }
	assert !overlay.hidden
	assert (find_message_element(root, 'show_message') or { panic('missing show button') }).native_style
	assert (find_message_element(root, 'close_message') or { panic('missing close button') }).native_style

	mut closed := MessageDemo{}
	closed.close_message()
	closed_root := ui2.element_from_qml_model(message_qml_source, closed, ui2.rect(0, 0, message_width, message_height)) or { panic(err) }
	assert (find_message_element(closed_root, 'overlay') or { panic('missing closed overlay') }).hidden
}
