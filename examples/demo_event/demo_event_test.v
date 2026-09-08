module main

import ui2

fn find_demo_event_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_demo_event_element(child, id) {
			return found
		}
	}
	return none
}

fn test_demo_event_records_pointer_keys_and_clear() {
	mut app := DemoEvent{}
	app.record_event('pointer:down:event_surface:120:88')
	assert app.pointer_events == 1
	assert app.last_event == 'Pointer down at (120, 88).'
	app.record_key('cmd+shift+r')
	assert app.key_events == 1
	assert app.history.contains('Key: cmd+shift+r')
	app.record_event('clear')
	assert app.history == ''
	assert app.pointer_events == 0
	assert app.key_events == 0
}

fn test_demo_event_vml_builds_draggable_surface_and_native_buttons() {
	root := ui2.element_from_vml_model(demo_event_vml_source, DemoEvent{}, ui2.rect(0, 0, demo_event_width, demo_event_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	surface := find_demo_event_element(root, 'event_surface') or { panic('missing event surface') }
	assert surface.clickable
	assert surface.draggable
	assert surface.cursor == ui2.cursor_pointing_hand
	assert surface.action_id == 'event_surface'
	assert (find_demo_event_element(root, 'sample_button') or { panic('missing sample button') }).native_style
	assert (find_demo_event_element(root, 'event_history') or { panic('missing history') }).readonly
}
