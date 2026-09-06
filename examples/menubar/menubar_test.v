module main

import ui2

fn find_menubar_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_menubar_element(child, id) {
			return found
		}
	}
	return none
}

fn test_menubar_declaration_is_valid_and_complete() {
	app := MenubarDemo{}
	menus := app.menus()
	ui2.validate_menus(menus) or { panic(err) }
	assert menus.map(it.title) == ['File', 'Edit', 'View', 'Help']
	// Every emitting row has a title to log it under, and nothing else does.
	mut ids := []string{}
	for m in menus {
		ids << ui2.menu_item_ids(m.items)
	}
	assert ids.len == menubar_action_titles.len
	for id in ids {
		assert id in menubar_action_titles, 'row `${id}` has no log title'
	}
}

fn test_menubar_declares_shortcuts_a_backend_can_bind() {
	menus := MenubarDemo{}.menus()
	save := ui2.find_menu_item(menus[0].items, 'file_save') or { panic('missing Save') }
	assert ui2.menu_shortcut_bindable(ui2.parse_menu_shortcut(save.shortcut))
	redo := ui2.find_menu_item(menus[1].items, 'edit_redo') or { panic('missing Redo') }
	parsed := ui2.parse_menu_shortcut(redo.shortcut)
	assert parsed.cmd && parsed.shift && parsed.key == 'z'
	// Find lives one level down, so the lookup has to walk into the submenu.
	assert (ui2.find_menu_item(menus[1].items, 'find_next') or { panic('missing Find Next') }).title == 'Find Next'
	assert !(ui2.find_menu_item(menus[0].items, 'file_revert') or { panic('missing Revert') }).enabled
}

fn test_menubar_check_rows_follow_the_model() {
	mut app := MenubarDemo{}
	details := ui2.find_menu_item(app.menus()[2].items, 'view_details') or {
		panic('missing Show Details')
	}
	assert details.checked
	assert app.choose('view_details')
	assert !app.show_details
	assert !(ui2.find_menu_item(app.menus()[2].items, 'view_details') or {
		panic('missing Show Details')
	}).checked
	assert menu_bar_rows_changed('view_details')
	assert !menu_bar_rows_changed('file_new')
}

fn test_menubar_choose_logs_and_ignores_unknown_ids() {
	mut app := MenubarDemo{}
	assert !app.choose('not_a_row')
	assert app.chosen == 0
	assert app.choose('file_new')
	assert app.last_action == 'New Note'
	assert app.log.contains('New Note')
	assert app.chosen == 1
	assert app.choose('zoom_out')
	assert app.zoom == 90
	assert app.last_action == 'Zoomed to 90%'
	assert app.choose('zoom_reset')
	assert app.zoom == 100
	app.reset()
	assert app.chosen == 0
	assert app.log == ''
}

fn test_menubar_zoom_stays_within_its_range() {
	mut app := MenubarDemo{}
	for _ in 0 .. 20 {
		app.choose('zoom_in')
	}
	assert app.zoom == 200
	for _ in 0 .. 40 {
		app.choose('zoom_out')
	}
	assert app.zoom == 50
}

fn test_menubar_log_keeps_only_the_recent_rows() {
	mut app := MenubarDemo{}
	for _ in 0 .. 20 {
		app.choose('file_save')
	}
	assert app.log.split_into_lines().len == 12
	assert app.log.split_into_lines()[0].contains('20.')
}

fn test_menubar_qml_shows_the_model_state() {
	root := ui2.element_from_qml_model(menubar_qml_source, MenubarDemo{}, ui2.rect(0, 0,
		menubar_width, menubar_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	assert (find_menubar_element(root, 'details_state') or { panic('missing details chip') }).text == 'on'
	assert (find_menubar_element(root, 'zoom_state') or { panic('missing zoom chip') }).text == '100%'
	assert (find_menubar_element(root, 'menu_log') or { panic('missing log') }).readonly
	reset := find_menubar_element(root, 'reset') or { panic('missing reset button') }
	assert reset.native_style
	// Nothing has been chosen yet, so clearing the log is not offered.
	assert !reset.enabled
}
