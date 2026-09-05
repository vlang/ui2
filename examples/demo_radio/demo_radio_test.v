module main

import ui2

fn find_radio_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_radio_element(child, id) {
			return found
		}
	}
	return none
}

fn test_radio_demo_keeps_one_country_selected() {
	mut app := initial_radio_demo()
	app.select_country('Australia')
	assert app.selected_country == 'Australia'
	assert app.message == 'Country: Australia'
}

fn test_radio_qml_reflects_exclusive_and_compact_selection() {
	mut app := initial_radio_demo()
	app.select_country('Canada')
	root := ui2.element_from_qml_model(radio_qml_source, app, ui2.rect(0, 0, radio_width, radio_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	choices := find_radio_element(root, 'choices') or { panic('missing choices') }
	assert choices.children.len == 4
	assert !choices.children[0].checked
	assert choices.children[1].checked
	assert !choices.children[2].checked
	assert choices.children[0].frame.y == 18
	assert (find_radio_element(root, 'compact_switch') or {
		panic('missing compact switch')
	}).checked
	assert (find_radio_element(root, 'selected_country') or {
		panic('missing country status')
	}).text == 'Country: Canada'
}

fn test_radio_vertical_layout_stays_inside_card() {
	mut app := initial_radio_demo()
	app.compact = false
	root := ui2.element_from_qml_model(radio_qml_source, app, ui2.rect(0, 0, radio_width, radio_height)) or { panic(err) }
	card := find_radio_element(root, 'card') or { panic('missing card') }
	choices := find_radio_element(root, 'choices') or { panic('missing choices') }
	status := find_radio_element(root, 'selected_country') or { panic('missing status') }
	assert choices.frame.height == 158
	assert choices.children[3].frame.y == 118
	assert status.frame.y + status.frame.height <= card.frame.height
}
