module main

import ui2

const toggle_width = 340
const toggle_height = 180
const toggle_vml_source = $embed_file('toggle_button.vml').to_string()

pub struct ToggleButtonDemo {
pub mut:
	bold   bool = true
	italic bool
}

fn main() {
	ui2.run_vml[ToggleButtonDemo](
		source: toggle_vml_source
		model: ToggleButtonDemo{}
		title: 'Toggle Button'
		width: toggle_width
		height: toggle_height
	) or { panic(err) }
}
