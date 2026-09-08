module main

import ui2

fn find_switch_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_switch_element(child, id) {
			return found
		}
	}
	return none
}

fn test_switch_qml_reflects_both_states() {
	mut app := SwitchDemo{}
	enabled_root := ui2.element_from_qml_model(switch_qml_source, app, ui2.rect(0, 0, switch_width, switch_height)) or { panic(err) }
	assert (find_switch_element(enabled_root, 'state') or { panic('missing state label') }).text == 'Enabled'
	enabled_switch := find_switch_element(enabled_root, 'switch-control') or {
		panic('missing switch control')
	}
	assert enabled_switch.kind == .switch_control
	assert enabled_switch.checked

	app.enabled = false
	disabled_root := ui2.element_from_qml_model(switch_qml_source, app, ui2.rect(0, 0, switch_width, switch_height)) or { panic(err) }
	assert (find_switch_element(disabled_root, 'state') or { panic('missing state label') }).text == 'Disabled'
	disabled_switch := find_switch_element(disabled_root, 'switch-control') or {
		panic('missing switch control')
	}
	assert disabled_switch.kind == .switch_control
	assert !disabled_switch.checked
}
