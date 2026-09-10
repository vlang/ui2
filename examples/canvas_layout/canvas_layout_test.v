module main

import ui2

fn find_canvas_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_canvas_element(child, id) {
			return found
		}
	}
	return none
}

fn test_canvas_tile_drag_keeps_its_grab_offset_and_stays_on_the_sheet() {
	mut app := CanvasLayoutDemo{}
	// Grab the tile 10 px inside its top left corner, with the sheet scrolled.
	app.grab_tile(canvas_sheet_root_x + 34, canvas_sheet_root_y + 34, 40)
	assert app.grab_x == 10
	assert app.grab_y == 50
	app.drag_tile(canvas_sheet_root_x + 234, canvas_sheet_root_y + 134, 40, 800)
	assert app.tile_x == 224
	assert app.tile_y == 124
	assert app.pointer_text == '(234, 174)'
	// Dragging past the sheet stops at its edges instead of losing the tile.
	app.drag_tile(canvas_sheet_root_x + 5000, canvas_sheet_root_y + 5000, 0, 800)
	assert app.tile_x == 630
	assert app.tile_y == 670
	app.reset_tile()
	assert app.tile_x == 24 && app.tile_y == 24
}

fn test_canvas_theme_menu_and_notes_react_to_events() {
	mut app := CanvasLayoutDemo{}
	app.apply_theme('Red')
	assert app.tile_color == '#B91C1C'
	assert app.tile_text == '#FFFFFF'
	app.toggle_menu()
	assert !app.menu_hidden
	assert app.menu_label == 'Hide menu'
	app.choose_menu_item('Export users')
	assert app.status == 'Menu item: Export users.'
	app.add_note()
	app.add_note()
	app.add_note()
	app.add_note()
	assert app.notes.map(it.key) == ['note-1', 'note-2', 'note-3', 'note-4']
	assert app.notes[3].x == 24 && app.notes[3].y == 390
	app.clear_notes()
	assert app.notes.len == 0
}

fn test_canvas_layout_vml_builds_a_scrolling_sheet_with_a_draggable_tile() {
	mut app := CanvasLayoutDemo{}
	app.add_note()
	app.toggle_menu()
	frame := ui2.rect(0, 0, canvas_layout_width, canvas_layout_height)
	root := ui2.element_from_vml_model(canvas_layout_vml_source, app, frame) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	canvas := find_canvas_element(root, 'canvas') or { panic('missing canvas') }
	assert canvas.frame.x == 18
	sheet := find_canvas_element(root, 'sheet') or { panic('missing sheet') }
	// The sheet is taller than its viewport, which is what makes it scroll.
	assert sheet.frame.height == canvas_sheet_height
	assert sheet.frame.height > canvas.frame.height
	assert sheet.frame.width == canvas_sheet_width(frame)
	assert sheet.draggable && sheet.action_id == 'canvas_sheet'
	tile := find_canvas_element(root, 'canvas_tile') or { panic('missing tile') }
	assert tile.draggable
	assert tile.cursor == ui2.cursor_pointing_hand
	assert !(find_canvas_element(root, 'canvas_menu') or { panic('missing menu') }).hidden
	assert (find_canvas_element(root, 'theme_dropdown') or { panic('missing dropdown') }).action_id == 'theme_dropdown'
}
