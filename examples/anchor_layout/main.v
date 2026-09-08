module main

import ui2

const anchor_width = 380
const anchor_height = 320
const anchor_qml_source = $embed_file('anchor_layout.qml').to_string()

pub struct AnchorLayoutDemo {}

fn main() {
	ui2.run_qml[AnchorLayoutDemo](
		source: anchor_qml_source
		model: AnchorLayoutDemo{}
		title: 'Anchor Layout'
		width: anchor_width
		height: anchor_height
	) or { panic(err) }
}
