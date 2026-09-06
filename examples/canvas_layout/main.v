module main

import ui2

const canvas_layout_width = 900
const canvas_layout_height = 660
const canvas_layout_qml_source = $embed_file('canvas_layout.qml').to_string()
const canvas_sheet_root_x = 34.0
const canvas_sheet_root_y = 100.0
const canvas_sheet_height = 760.0
const canvas_tile_width = 150.0
const canvas_tile_height = 70.0

pub struct CanvasNote {
pub:
	id    int
	key   string
	label string
	x     f64
	y     f64
}

@[heap]
pub struct CanvasLayoutDemo {
pub mut:
	tile_x       f64 = 24
	tile_y       f64 = 24
	theme        string = 'Classic'
	tile_color   string = '#E2E8F0'
	tile_text    string = '#0F172A'
	pointer_text string = '(0, 0)'
	menu_hidden  bool = true
	menu_label   string = 'Show menu'
	notes        []CanvasNote
	text         string = 'A canvas places every child at its own\ncoordinates, so this text area keeps its\nspot while the sheet scrolls.'
	status       string = 'Drag the tile, or drag the sheet to read canvas coordinates.'
mut:
	next_note int = 1
	grab_x    f64
	grab_y    f64
}

const canvas_layout_state = &CanvasLayoutDemo{}

fn canvas_theme_colors(theme string) (string, string) {
	return match theme {
		'Blue' { '#1D4ED8', '#FFFFFF' }
		'Red' { '#B91C1C', '#FFFFFF' }
		'Green' { '#15803D', '#FFFFFF' }
		'Slate' { '#334155', '#FFFFFF' }
		else { '#E2E8F0', '#0F172A' }
	}
}

pub fn (mut app CanvasLayoutDemo) apply_theme(theme string) {
	app.theme = theme
	app.tile_color, app.tile_text = canvas_theme_colors(theme)
	app.status = '${theme} theme applied to the movable tile.'
}

// canvas_sheet_point converts a root-view pointer position into sheet
// coordinates. The sheet scrolls, so its origin moves with the viewport.
fn canvas_sheet_point(x f64, y f64, scroll f64) (f64, f64) {
	return x - canvas_sheet_root_x, y - canvas_sheet_root_y + scroll
}

pub fn (mut app CanvasLayoutDemo) track_pointer(x f64, y f64, scroll f64) {
	sheet_x, sheet_y := canvas_sheet_point(x, y, scroll)
	app.pointer_text = '(${int(sheet_x)}, ${int(sheet_y)})'
}

pub fn (mut app CanvasLayoutDemo) grab_tile(x f64, y f64, scroll f64) {
	sheet_x, sheet_y := canvas_sheet_point(x, y, scroll)
	app.grab_x = sheet_x - app.tile_x
	app.grab_y = sheet_y - app.tile_y
}

pub fn (mut app CanvasLayoutDemo) drag_tile(x f64, y f64, scroll f64, sheet_width f64) {
	sheet_x, sheet_y := canvas_sheet_point(x, y, scroll)
	max_x := sheet_width - canvas_tile_width - 20
	max_y := canvas_sheet_height - canvas_tile_height - 20
	app.tile_x = clamp_canvas(sheet_x - app.grab_x, 20, max_x)
	app.tile_y = clamp_canvas(sheet_y - app.grab_y, 20, max_y)
	app.pointer_text = '(${int(sheet_x)}, ${int(sheet_y)})'
	app.status = 'Tile at (${int(app.tile_x)}, ${int(app.tile_y)}).'
}

fn clamp_canvas(value f64, low f64, high f64) f64 {
	if high < low {
		return low
	}
	if value < low {
		return low
	}
	return if value > high { high } else { value }
}

pub fn (mut app CanvasLayoutDemo) reset_tile() {
	app.tile_x = 24
	app.tile_y = 24
	app.status = 'Tile returned to the top left of the sheet.'
}

pub fn (mut app CanvasLayoutDemo) add_note() {
	id := app.next_note
	app.notes << CanvasNote{
		id: id
		key: 'note-${id}'
		label: 'Note ${id}'
		// Notes walk down the sheet in a fixed pattern, so a rebuild puts every
		// keyed card back where it was.
		x: 24 + f64((id - 1) % 3) * 150
		y: 300 + f64((id - 1) / 3) * 90
	}
	app.next_note++
	app.status = 'Added note ${id}; the sheet keeps growing past the viewport.'
}

pub fn (mut app CanvasLayoutDemo) clear_notes() {
	app.notes = []
	app.status = 'Notes cleared.'
}

pub fn (mut app CanvasLayoutDemo) toggle_menu() {
	app.menu_hidden = !app.menu_hidden
	app.menu_label = if app.menu_hidden { 'Show menu' } else { 'Hide menu' }
	app.status = if app.menu_hidden { 'Menu hidden.' } else { 'Menu shown on the sheet.' }
}

pub fn (mut app CanvasLayoutDemo) choose_menu_item(title string) {
	app.status = 'Menu item: ${title}.'
}

fn canvas_pointer(event string) ?(string, string, f64, f64) {
	parts := event.split(':')
	if parts.len < 5 || parts[0] != 'pointer' {
		return none
	}
	return parts[1], parts[2], parts[3].f64(), parts[4].f64()
}

fn (mut app CanvasLayoutDemo) handle_event(event string, sheet_width f64, scroll f64) {
	match event {
		'theme_dropdown' { app.apply_theme(ui2.text('theme_dropdown')) }
		'reset_tile' { app.reset_tile() }
		'add_note' { app.add_note() }
		'clear_notes' { app.clear_notes() }
		'toggle_menu' { app.toggle_menu() }
		'menu_delete' { app.choose_menu_item('Delete all users') }
		'menu_export' { app.choose_menu_item('Export users') }
		'menu_exit' { app.choose_menu_item('Exit') }
		'about' { ui2.alert('Canvas layout', 'Built with V UI') }
		else {
			phase, id, x, y := canvas_pointer(event) or { return }
			match id {
				'canvas_tile' {
					if phase == 'down' {
						app.grab_tile(x, y, scroll)
					} else {
						app.drag_tile(x, y, scroll, sheet_width)
					}
				}
				'canvas_sheet' {
					app.track_pointer(x, y, scroll)
				}
				else {}
			}
		}
	}
}

fn canvas_sheet_width(frame ui2.Rect) f64 {
	return frame.width - 68.0
}

fn build_canvas_layout_screen() ui2.Element {
	state := unsafe { canvas_layout_state }
	return ui2.element_from_qml_model(canvas_layout_qml_source, *state, ui2.bounds()) or {
		eprintln('canvas-layout QML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_canvas_layout_event(event string) {
	mut state := unsafe { canvas_layout_state }
	state.handle_event(event, canvas_sheet_width(ui2.bounds()), ui2.scroll_offset('canvas'))
	ui2.refresh()
}

fn main() {
	ui2.run_window('Canvas Layout', canvas_layout_width, canvas_layout_height, build_canvas_layout_screen, handle_canvas_layout_event)
}
