module main

import ui2

fn find_colorbox_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_colorbox_element(child, id) {
			return found
		}
	}
	return none
}

fn test_colorbox_round_trips_between_hsv_and_rgb() {
	mut app := colorbox_demo()
	app.set_hue(210)
	assert app.hue == 210
	assert app.hue_color == '#0080FF'
	app.set_saturation_value(1.0, 1.0)
	assert app.color == '#0080FF'
	assert app.red == 0 && app.green == 128 && app.blue == 255
	// Typing the same channels back must land on the same hue.
	app.apply_channel('red', '0')
	app.apply_channel('green', '128')
	app.apply_channel('blue', '255')
	assert app.valid
	assert int(app.hue) == 209
	assert app.color == '#0080FF'
}

fn test_colorbox_rejects_channels_outside_the_byte_range() {
	mut app := colorbox_demo()
	app.apply_channel('red', '300')
	assert !app.valid
	assert app.status == 'Each channel must be a number between 0 and 255.'
	app.apply_channel('red', '12')
	assert app.valid
	assert app.red == 12
}

fn test_colorbox_stores_and_recalls_swatch_slots() {
	mut app := colorbox_demo()
	assert app.swatches.len == 6
	assert app.swatches[0].selected
	recalled := app.swatches[3].color
	app.select_swatch(3)
	assert app.swatches[3].selected
	assert !app.swatches[0].selected
	assert app.color == recalled
	app.set_hue(0)
	app.set_saturation_value(1.0, 1.0)
	app.store_swatch()
	assert app.swatches[3].color == '#FF0000'
	assert app.status == 'Stored #FF0000 in slot 4.'
	// A press outside the grid selects nothing.
	assert app.swatch_at(swatch_root_x - 20, swatch_root_y + 10) == -1
	assert app.swatch_at(swatch_root_x + 90, swatch_root_y + 50) == 3
	assert app.swatch_at(swatch_root_x + 76, swatch_root_y + 10) == -1
}

fn test_colorbox_vml_paints_both_canvases_and_tracks_the_markers() {
	mut app := colorbox_demo()
	app.set_hue(180)
	app.set_saturation_value(0.5, 0.25)
	frame := ui2.rect(0, 0, colorbox_width, colorbox_height)
	root := ui2.element_from_vml_model(colorbox_vml_source, app, frame) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	hue := find_colorbox_element(root, 'hue_strip') or { panic('missing hue strip') }
	assert hue.draggable && hue.action_id == 'hue_strip'
	assert hue.children.len == hue_bands + 1
	// The marker is the last child, so it stays on top of the bands.
	assert hue.children.last().frame.y == 180.0 / 360.0 * picker_side - 2
	square := find_colorbox_element(root, 'sv_square') or { panic('missing sv square') }
	assert square.children.len == sv_side * sv_side + 1
	assert square.children.last().frame.x == 0.5 * picker_side - 7
	assert square.children.last().frame.y == 0.75 * picker_side - 7
	// Every tile of the square is repainted from the current hue.
	assert app.sv_cells.last().color == '#000808'
	assert (find_colorbox_element(root, 'red_input') or { panic('missing input') }).text == app.red_text
}
