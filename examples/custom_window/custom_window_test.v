module main

import ui2

fn find_custom_window_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_custom_window_element(child, id) {
			return found
		}
	}
	return none
}

fn test_custom_window_counter_never_becomes_negative() {
	mut app := CustomWindowDemo{}
	app.remove_completed()
	assert app.completed == 0
	assert app.completed_label == 'Nothing completed yet'
	app.add_completed()
	assert app.completed == 1
	assert app.completed_label == '1 focus session completed'
	app.add_completed()
	assert app.completed_label == '2 focus sessions completed'
	app.reset()
	assert app.completed == 0
}

fn test_custom_window_vml_exposes_clear_space_and_custom_chrome() {
	app := CustomWindowDemo{
		transparent_screen: true
		screen_background: '#010203'
	}
	root := ui2.element_from_vml_model(custom_window_vml_source, app, ui2.rect(0, 0, custom_window_width, custom_window_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	assert root.box.transparent
	drag := find_custom_window_element(root, 'window_drag') or { panic('missing drag surface') }
	assert drag.draggable && drag.clickable
	assert drag.box.transparent
	card := find_custom_window_element(root, 'card') or { panic('missing widget card') }
	actions := find_custom_window_element(root, 'actions') or { panic('missing action island') }
	assert card.frame.y + card.frame.height < actions.frame.y
	assert card.box.radius == 22
	assert (find_custom_window_element(root, 'close') or { panic('missing close control') }).action_id == 'close'
}
