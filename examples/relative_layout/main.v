module main

import ui2

const relative_width = 400
const relative_height = 250
const relative_qml_source = $embed_file('relative_layout.qml').to_string()

pub struct RelativeLayoutDemo {}

fn main() {
	ui2.run_qml[RelativeLayoutDemo](
		source: relative_qml_source
		model: RelativeLayoutDemo{}
		title: 'Relative Layout'
		width: relative_width
		height: relative_height
	) or { panic(err) }
}
