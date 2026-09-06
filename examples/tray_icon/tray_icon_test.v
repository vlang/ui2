module main

import ui2

fn find_tray_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_tray_element(child, id) {
			return found
		}
	}
	return none
}

fn test_tray_declaration_is_valid_and_reaches_every_status() {
	cfg := TrayDemo{}.tray_config()
	mut ids := map[string]bool{}
	ui2.validate_menu_items(cfg.menu, 'tray', mut ids) or { panic(err) }
	assert cfg.tooltip.contains('Available')
	assert ui2.menu_item_ids(cfg.menu) == ['tray_status', 'status_available', 'status_busy',
		'status_away', 'tray_notifications', 'tray_hide', 'tray_quit']
}

fn test_tray_check_rows_follow_the_model() {
	mut app := TrayDemo{}
	available := ui2.find_menu_item(app.tray_config().menu, 'status_available') or {
		panic('missing Available')
	}
	assert available.checked
	assert app.choose('status_busy')
	assert app.status == 'Busy'
	assert !(ui2.find_menu_item(app.tray_config().menu, 'status_available') or {
		panic('missing Available')
	}).checked
	assert (ui2.find_menu_item(app.tray_config().menu, 'status_busy') or {
		panic('missing Busy')
	}).checked
	assert tray_rows_changed('status_busy')
	assert tray_rows_changed('tray_notifications')
	assert !tray_rows_changed('tray_hide')
}

fn test_tray_choose_logs_and_ignores_unknown_ids() {
	mut app := TrayDemo{
		supported: true
	}
	assert !app.choose('not_a_row')
	assert app.opened == 0
	assert app.choose('tray_status')
	assert app.last_action == 'Status is Available, notifications on.'
	assert app.choose('tray_notifications')
	assert !app.notifications
	assert app.choose('tray_hide')
	assert !app.docked
	assert app.choose('tray_show')
	assert app.docked
	assert app.log.split_into_lines().len == 4
}

fn test_tray_does_not_claim_to_dock_without_a_status_area() {
	mut app := TrayDemo{
		docked: false
		supported: false
	}
	assert app.choose('tray_show')
	assert !app.docked
	assert app.last_action.contains('no status area')
}

fn test_tray_status_from_id_only_matches_status_rows() {
	assert tray_status_from_id('status_away') or { '' } == 'Away'
	if _ := tray_status_from_id('tray_hide') {
		assert false, 'a non-status row should not resolve to a status'
	}
}

fn test_tray_qml_offers_the_same_rows_where_there_is_no_status_area() {
	root := ui2.element_from_qml_model(tray_icon_qml_source, TrayDemo{
		supported: false
		docked: false
	}, ui2.rect(0, 0, tray_icon_width, tray_icon_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	// The fallback buttons carry the very ids the tray menu rows emit.
	for id, action in {
		'fallback_status':        'tray_status'
		'fallback_notifications': 'tray_notifications'
		'fallback_available':     'status_available'
		'fallback_busy':          'status_busy'
		'fallback_away':          'status_away'
	} {
		button := find_tray_element(root, id) or { panic('missing ${id}') }
		assert !button.hidden
		assert button.action_id == action
	}
	// Docking is not on offer where it cannot happen.
	assert !(find_tray_element(root, 'tray_show') or { panic('missing dock button') }).enabled
	assert !(find_tray_element(root, 'tray_hide') or { panic('missing hide button') }).enabled
}

fn test_tray_qml_hides_the_fallback_rows_where_the_status_area_is_real() {
	root := ui2.element_from_qml_model(tray_icon_qml_source, TrayDemo{
		supported: true
	}, ui2.rect(0, 0, tray_icon_width, tray_icon_height)) or { panic(err) }
	assert (find_tray_element(root, 'fallback_status') or { panic('missing fallback') }).hidden
	assert (find_tray_element(root, 'status_state') or { panic('missing status chip') }).text == 'Available'
	assert (find_tray_element(root, 'tray_hide') or { panic('missing hide button') }).enabled
}
