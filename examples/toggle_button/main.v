module main

import ui2

const toggle_width = 340
const toggle_height = 180
const toggle_qml_source = $embed_file('toggle_button.qml').to_string()

pub struct ToggleButtonDemo {
pub mut:
	bold bool
}

fn main() {
	ui2.run_qml[ToggleButtonDemo](
		source: toggle_qml_source
		model: ToggleButtonDemo{}
		title: 'Toggle Button'
		width: toggle_width
		height: toggle_height
	) or { panic(err) }
}
