module main

import ui2

const demo_label_width = 420
const demo_label_height = 220
const demo_label_vml_source = $embed_file('demo_label.vml').to_string()

pub struct DemoLabel {}

fn main() {
	ui2.run_vml[DemoLabel](
		source: demo_label_vml_source
		model: DemoLabel{}
		title: 'Label'
		width: demo_label_width
		height: demo_label_height
	) or { panic(err) }
}
