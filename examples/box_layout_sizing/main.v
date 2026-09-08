module main

import ui2

const box_sizing_width = 410
const box_sizing_height = 220
const box_sizing_qml_source = $embed_file('box_layout_sizing.qml').to_string()

pub struct BoxLayoutSizingDemo {}

fn main() {
	ui2.run_qml[BoxLayoutSizingDemo](
		source: box_sizing_qml_source
		model: BoxLayoutSizingDemo{}
		title: 'Box Layout Sizing'
		width: box_sizing_width
		height: box_sizing_height
	) or { panic(err) }
}
