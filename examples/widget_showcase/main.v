module main

import ui2

const showcase_width = 900
const showcase_height = 640
const showcase_vml_source = $embed_file('widget_showcase.vml').to_string()

pub struct ShowcaseApp {
pub mut:
}

fn main() {
	ui2.run_vml[ShowcaseApp](
		source: showcase_vml_source
		model:  ShowcaseApp{}
		title:  'UI2 Widget Showcase'
		width:  showcase_width
		height: showcase_height
	) or { panic(err) }
}