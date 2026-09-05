module main

import ui2

const rectangles_width = 360
const rectangles_height = 180
const rectangles_qml_source = $embed_file('rectangles.qml').to_string()

pub struct RectanglesDemo {}

fn main() {
	ui2.run_qml[RectanglesDemo](
		source: rectangles_qml_source
		model: RectanglesDemo{}
		title: 'Rectangles'
		width: rectangles_width
		height: rectangles_height
	) or { panic(err) }
}
