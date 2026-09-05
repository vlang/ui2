module main

import ui2

fn find_counter_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_counter_element(child, id) {
			return found
		}
	}
	return none
}

fn test_counter_increments() {
	mut app := CounterApp{}
	app.increment()
	app.increment()
	assert app.count == 2
}

fn test_counter_qml_builds_valid_ui() {
	app := CounterApp{
		count: 7
	}
	root := ui2.element_from_qml_model(counter_qml_source, app, ui2.rect(0, 0, counter_width, counter_height)) or { panic(err) }
	assert (find_counter_element(root, 'count') or { panic('missing count') }).text == '7'
	button := find_counter_element(root, 'increment') or { panic('missing Count button') }
	assert button.text == 'Count'
	assert button.action_id.len > 0
	assert button.native_style
}
