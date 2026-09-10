module main

import ui2

fn find_child_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_child_element(child, id) {
			return found
		}
	}
	return none
}

fn test_child_window_greeting_follows_the_checkbox() {
	assert greeting('Ada', true) == 'Hello, miss Ada!'
	assert greeting('Ada', false) == 'Hello, mister Ada!'
	assert greeting('  ', false) == 'Hello, mister anonymous!'
	mut app := ChildWindowDemo{}
	app.set_name(' Grace ')
	app.toggle_woman()
	assert greeting(app.name, app.woman) == 'Hello, miss Grace!'
}

fn test_child_window_opens_closes_and_cascades() {
	mut app := ChildWindowDemo{}
	assert !app.open
	app.create_window()
	assert app.open
	assert app.title == 'Child window 1'
	assert app.panel_x == 40 && app.panel_y == 96
	app.create_window()
	assert app.title == 'Child window 2'
	assert app.panel_x == 66 && app.panel_y == 122
	// The cascade wraps instead of walking off the card.
	app.create_window()
	app.create_window()
	app.create_window()
	app.create_window()
	assert app.title == 'Child window 6'
	assert app.panel_x == 40 && app.panel_y == 96
	app.close_window()
	assert !app.open
}

fn test_child_window_drag_keeps_the_panel_inside_the_card() {
	mut app := ChildWindowDemo{}
	app.create_window()
	app.grab_panel(child_card_root_x + 60, child_card_root_y + 106)
	assert app.grab_x == 20
	assert app.grab_y == 10
	app.drag_panel(child_card_root_x + 200, child_card_root_y + 200, 600, 600)
	assert app.panel_x == 180
	assert app.panel_y == 190
	app.drag_panel(child_card_root_x + 5000, child_card_root_y + 5000, 600, 600)
	assert app.panel_x == 600 - child_panel_width - 12
	assert app.panel_y == 600 - child_panel_height - 12
	app.drag_panel(0, 0, 600, 600)
	assert app.panel_x == 12 && app.panel_y == 12
}

fn test_child_window_vml_hides_the_panel_until_it_is_created() {
	frame := ui2.rect(0, 0, child_window_width, child_window_height)
	closed := ui2.element_from_vml_model(child_window_vml_source, ChildWindowDemo{}, frame) or {
		panic(err)
	}
	ui2.validate_element_tree(closed) or { panic(err) }
	assert (find_child_element(closed, 'child_panel') or { panic('missing panel') }).hidden

	mut app := ChildWindowDemo{}
	app.create_window()
	app.toggle_woman()
	open := ui2.element_from_vml_model(child_window_vml_source, app, frame) or { panic(err) }
	ui2.validate_element_tree(open) or { panic(err) }
	panel := find_child_element(open, 'child_panel') or { panic('missing panel') }
	assert !panel.hidden
	assert panel.frame.x == 40 && panel.frame.y == 96
	titlebar := find_child_element(open, 'child_titlebar') or { panic('missing title bar') }
	assert titlebar.draggable && titlebar.action_id == 'child_titlebar'
	assert (find_child_element(open, 'genre') or { panic('missing checkbox') }).checked
	assert (find_child_element(open, 'greet') or { panic('missing greet button') }).native_style
	// The parent field is a separate control, so the child never steals its text.
	assert (find_child_element(open, 'parent_input') or { panic('missing parent field') }).text == ''
}
