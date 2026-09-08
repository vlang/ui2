module main

import ui2

const grid_width = 360
const grid_height = 260
const grid_qml_source = $embed_file('grid_layout.qml').to_string()

pub struct GridLayoutDemo {}

fn main() {
	ui2.run_qml[GridLayoutDemo](
		source: grid_qml_source
		model: GridLayoutDemo{}
		title: 'Grid Layout'
		width: grid_width
		height: grid_height
	) or { panic(err) }
}
