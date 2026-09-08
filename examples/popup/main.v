module main

import ui2

const popup_width = 460
const popup_height = 340
const popup_vml_source = $embed_file('popup.vml').to_string()

pub struct PopupDemo {
pub mut:
	editing bool
	name    string = 'Ada'
}

pub fn (mut app PopupDemo) open_editor() {
	app.editing = true
}

pub fn (mut app PopupDemo) close_editor() {
	app.editing = false
}

pub fn (mut app PopupDemo) save_editor() {
	app.editing = false
}

fn main() {
	ui2.run_vml[PopupDemo](
		source: popup_vml_source
		model: PopupDemo{}
		title: 'Popup'
		width: popup_width
		height: popup_height
	) or { panic(err) }
}
