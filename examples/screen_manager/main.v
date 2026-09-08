module main

import ui2

const screen_manager_width = 440
const screen_manager_height = 320
const screen_manager_qml_source = $embed_file('screen_manager.qml').to_string()

pub struct ScreenManagerDemo {
pub mut:
	current string
}

pub fn (mut app ScreenManagerDemo) show_home() {
	app.current = 'home'
}

pub fn (mut app ScreenManagerDemo) show_details() {
	app.current = 'details'
}

fn main() {
	ui2.run_qml[ScreenManagerDemo](
		source: screen_manager_qml_source
		model: ScreenManagerDemo{}
		title: 'Screen Manager'
		width: screen_manager_width
		height: screen_manager_height
	) or { panic(err) }
}
