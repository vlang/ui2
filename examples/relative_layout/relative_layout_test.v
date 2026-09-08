module main

import ui2

fn find_relative_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_relative_element(child, id) {
			return found
		}
	}
	return none
}

fn test_relative_layout_demo_keeps_centered_action_local() {
	root := ui2.element_from_qml_model(relative_qml_source, RelativeLayoutDemo{}, ui2.rect(0, 0, relative_width, relative_height)) or { panic(err) }
	panel := find_relative_element(root, 'panel') or { panic('missing relative panel') }
	action := find_relative_element(root, 'centered_action') or { panic('missing action') }
	assert panel.frame == ui2.rect(70, 64, 260, 150)
	assert action.frame == ui2.rect(75, 71, 110, 38)
}
