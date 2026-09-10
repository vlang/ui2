module main

import ui2

const stack_width = 380
const stack_height = 240
const stack_vml_source = $embed_file('stack_layout.vml').to_string()

pub struct StackLayoutDemo {}

fn main() {
	ui2.run_vml[StackLayoutDemo](
		source: stack_vml_source
		model: StackLayoutDemo{}
		title: 'Stack Layout'
		width: stack_width
		height: stack_height
	) or { panic(err) }
}
