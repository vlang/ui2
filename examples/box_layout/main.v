module main

import ui2

const box_layout_width = 520
const box_layout_height = 360
const box_layout_qml_source = $embed_file('box_layout.qml').to_string()

pub struct BoxLayoutDemo {}

fn main() {
	ui2.run_qml[BoxLayoutDemo](
		source: box_layout_qml_source
		model: BoxLayoutDemo{}
		title: 'Box Layout'
		width: box_layout_width
		height: box_layout_height
	) or { panic(err) }
}
