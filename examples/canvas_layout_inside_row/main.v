module main

import os
import ui2

const inside_row_width = 880
const inside_row_height = 580
const inside_row_vml_source = $embed_file('canvas_layout_inside_row.vml').to_string()
const card_root_x = 16.0
const card_root_y = 16.0
const tray_x = 18.0
const canvas_x = 250.0
const pane_y = 96.0
const logo_size = 72.0

@[heap]
pub struct InsideRowDemo {
pub mut:
	logo_path   string
	logo_x      f64 = 92
	logo_y      f64 = 150
	rotation    f64
	over_canvas bool
	pane_name   string = 'tray'
	tray_text   string
	canvas_text string
	status      string = 'Drag the logo between the two panes.'
mut:
	grab_x f64
	grab_y f64
}

const inside_row_state = &InsideRowDemo{}

fn inside_row_logo_path() string {
	// The Windows image control reads BMP, the others read PNG.
	$if windows {
		return os.real_path(os.join_path(os.dir(@FILE), '..', 'users', 'logo.bmp'))
	} $else {
		return os.real_path(os.join_path(os.dir(@FILE), '..', 'users', 'logo.png'))
	}
}

fn inside_row_demo() InsideRowDemo {
	mut app := InsideRowDemo{
		logo_path: inside_row_logo_path()
	}
	app.describe()
	return app
}

// describe reports the logo in both local spaces at once, which is the point of
// nesting a canvas in a row: the same pointer sits at different coordinates in
// every pane it crosses.
fn (mut app InsideRowDemo) describe() {
	center_x := app.logo_x + logo_size / 2
	app.over_canvas = center_x >= canvas_x
	app.pane_name = if app.over_canvas { 'canvas' } else { 'tray' }
	app.tray_text = '(${int(app.logo_x - tray_x)}, ${int(app.logo_y - pane_y)})'
	app.canvas_text = '(${int(app.logo_x - canvas_x)}, ${int(app.logo_y - pane_y)})'
}

pub fn (mut app InsideRowDemo) grab_logo(x f64, y f64) {
	app.grab_x = x - card_root_x - app.logo_x
	app.grab_y = y - card_root_y - app.logo_y
}

pub fn (mut app InsideRowDemo) drag_logo(x f64, y f64, card_width f64, card_height f64) {
	app.logo_x = clamp_inside(x - card_root_x - app.grab_x, tray_x, card_width - logo_size - 18)
	app.logo_y = clamp_inside(y - card_root_y - app.grab_y, pane_y, card_height - logo_size - 60)
	app.describe()
	app.status = 'Logo is over the ${app.pane_name} pane.'
}

fn clamp_inside(value f64, low f64, high f64) f64 {
	if high < low {
		return low
	}
	if value < low {
		return low
	}
	return if value > high { high } else { value }
}

pub fn (mut app InsideRowDemo) return_to_tray() {
	app.logo_x = 92
	app.logo_y = 150
	app.describe()
	app.status = 'Logo returned to the tray.'
}

pub fn (mut app InsideRowDemo) rotate() {
	app.rotation = if app.rotation >= 270 { 0.0 } else { app.rotation + 90 }
	app.status = 'Logo rotated to ${int(app.rotation)}°.'
}

fn inside_row_card_size(frame ui2.Rect) (f64, f64) {
	return frame.width - 32.0, frame.height - 32.0
}

fn inside_row_pointer(event string) ?(string, string, f64, f64) {
	parts := event.split(':')
	if parts.len < 5 || parts[0] != 'pointer' {
		return none
	}
	return parts[1], parts[2], parts[3].f64(), parts[4].f64()
}

fn (mut app InsideRowDemo) handle_event(event string, card_width f64, card_height f64) {
	match event {
		'return' {
			app.return_to_tray()
		}
		'rotate' {
			app.rotate()
		}
		else {
			phase, id, x, y := inside_row_pointer(event) or { return }
			if id != 'logo' {
				return
			}
			if phase == 'down' {
				app.grab_logo(x, y)
			} else {
				app.drag_logo(x, y, card_width, card_height)
			}
		}
	}
}

fn build_inside_row_screen() ui2.Element {
	state := unsafe { inside_row_state }
	return ui2.element_from_vml_model(inside_row_vml_source, *state, ui2.bounds()) or {
		eprintln('canvas-layout-inside-row VML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_inside_row_event(event string) {
	mut state := unsafe { inside_row_state }
	card_width, card_height := inside_row_card_size(ui2.bounds())
	state.handle_event(event, card_width, card_height)
	ui2.refresh()
}

fn main() {
	mut state := unsafe { inside_row_state }
	unsafe {
		*state = inside_row_demo()
	}
	ui2.run_window('Canvas Layout Inside Row', inside_row_width, inside_row_height, build_inside_row_screen, handle_inside_row_event)
}
