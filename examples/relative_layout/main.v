module main

import ui2

const relative_width = 400
const relative_height = 250
const relative_vml_source = $embed_file('relative_layout.vml').to_string()

pub struct RelativeLayoutDemo {}

fn main() {
	ui2.run_vml[RelativeLayoutDemo](
		source: relative_vml_source
		model: RelativeLayoutDemo{}
		title: 'Relative Layout'
		width: relative_width
		height: relative_height
	) or { panic(err) }
}
