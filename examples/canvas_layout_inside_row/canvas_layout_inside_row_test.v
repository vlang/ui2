module main

import os
import ui2

fn find_inside_row_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_inside_row_element(child, id) {
			return found
		}
	}
	return none
}

fn test_inside_row_reports_the_logo_in_both_pane_spaces() {
	mut app := inside_row_demo()
	// The same point is 74 px into the tray and 158 px short of the canvas.
	assert app.tray_text == '(74, 54)'
	assert app.canvas_text == '(-158, 54)'
	assert app.pane_name == 'tray'
	assert !app.over_canvas
	app.logo_x = 300
	app.describe()
	assert app.pane_name == 'canvas'
	assert app.over_canvas
	assert app.canvas_text == '(50, 54)'
	assert app.tray_text == '(282, 54)'
	// The pane a logo belongs to is decided by its centre, not its left edge.
	app.logo_x = canvas_x - logo_size / 2
	app.describe()
	assert app.over_canvas
	app.logo_x = canvas_x - logo_size / 2 - 1
	app.describe()
	assert !app.over_canvas
}

fn test_inside_row_drag_keeps_its_grab_offset_and_stays_on_the_card() {
	mut app := inside_row_demo()
	app.grab_logo(card_root_x + 100, card_root_y + 170)
	assert app.grab_x == 8
	assert app.grab_y == 20
	app.drag_logo(card_root_x + 400, card_root_y + 300, 800, 500)
	assert app.logo_x == 392
	assert app.logo_y == 280
	app.drag_logo(card_root_x + 5000, card_root_y + 5000, 800, 500)
	assert app.logo_x == 800 - logo_size - 18
	assert app.logo_y == 500 - logo_size - 60
	// Neither pane starts before the tray's own origin.
	app.drag_logo(0, 0, 800, 500)
	assert app.logo_x == tray_x
	assert app.logo_y == pane_y
}

fn test_inside_row_rotation_cycles_through_four_quarters() {
	mut app := inside_row_demo()
	assert app.rotation == 0
	app.rotate()
	assert app.rotation == 90
	app.rotate()
	app.rotate()
	assert app.rotation == 270
	app.rotate()
	assert app.rotation == 0
	app.logo_x = 400
	app.return_to_tray()
	assert app.logo_x == 92 && app.logo_y == 150
	assert app.pane_name == 'tray'
}

fn test_inside_row_vml_builds_two_panes_and_a_draggable_image() {
	mut app := inside_row_demo()
	app.rotate()
	frame := ui2.rect(0, 0, inside_row_width, inside_row_height)
	root := ui2.element_from_vml_model(inside_row_vml_source, app, frame) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	tray := find_inside_row_element(root, 'tray') or { panic('missing tray') }
	canvas := find_inside_row_element(root, 'canvas') or { panic('missing canvas') }
	assert tray.frame.x == tray_x
	assert canvas.frame.x == canvas_x
	// The panes sit side by side without overlapping.
	assert tray.frame.x + tray.frame.width <= canvas.frame.x
	logo := find_inside_row_element(root, 'logo') or { panic('missing logo') }
	assert logo.draggable && logo.action_id == 'logo'
	assert logo.rotation == 90
	assert logo.tooltip == 'Drag me across the divider'
	assert logo.cursor == ui2.cursor_pointing_hand
	assert os.exists(logo.image_path)
}
