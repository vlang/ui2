module main

import ui2

const label_justify_width = 520
const label_justify_height = 330
const label_justify_qml_source = $embed_file('label_justify.qml').to_string()

pub struct LabelJustifyDemo {}

fn main() {
	ui2.run_qml[LabelJustifyDemo](
		source: label_justify_qml_source
		model: LabelJustifyDemo{}
		title: 'Label Justify'
		width: label_justify_width
		height: label_justify_height
	) or { panic(err) }
}
