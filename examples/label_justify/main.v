module main

import ui2

const label_justify_width = 520
const label_justify_height = 330
const label_justify_vml_source = $embed_file('label_justify.vml').to_string()

pub struct LabelJustifyDemo {}

fn main() {
	ui2.run_vml[LabelJustifyDemo](
		source: label_justify_vml_source
		model: LabelJustifyDemo{}
		title: 'Label Justify'
		width: label_justify_width
		height: label_justify_height
	) or { panic(err) }
}
