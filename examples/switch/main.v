module main

import ui2

const switch_width = 320
const switch_height = 160
const switch_qml_source = $embed_file('switch.qml').to_string()

pub struct SwitchDemo {
pub mut:
	enabled bool = true
}

fn main() {
	ui2.run_qml[SwitchDemo](
		source: switch_qml_source
		model: SwitchDemo{}
		title: 'Switch'
		width: switch_width
		height: switch_height
	) or { panic(err) }
}
