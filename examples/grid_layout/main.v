module main

import ui2

const grid_width = 360
const grid_height = 260
const grid_vml_source = $embed_file('grid_layout.vml').to_string()

pub struct GridLayoutDemo {}

fn main() {
	ui2.run_vml[GridLayoutDemo](
		source: grid_vml_source
		model: GridLayoutDemo{}
		title: 'Grid Layout'
		width: grid_width
		height: grid_height
	) or { panic(err) }
}
