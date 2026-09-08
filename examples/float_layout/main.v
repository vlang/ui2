module main

import ui2

const float_width = 400
const float_height = 260
const float_vml_source = $embed_file('float_layout.vml').to_string()

pub struct FloatLayoutDemo {}

fn main() {
	ui2.run_vml[FloatLayoutDemo](
		source: float_vml_source
		model: FloatLayoutDemo{}
		title: 'Float Layout'
		width: float_width
		height: float_height
	) or { panic(err) }
}
