module main

import ui2

const rectangles_width = 360
const rectangles_height = 180
const rectangles_vml_source = $embed_file('rectangles.vml').to_string()

pub struct RectanglesDemo {}

fn main() {
	ui2.run_vml[RectanglesDemo](
		source: rectangles_vml_source
		model: RectanglesDemo{}
		title: 'Rectangles'
		width: rectangles_width
		height: rectangles_height
	) or { panic(err) }
}
