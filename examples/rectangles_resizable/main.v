module main

import ui2

const resizable_rectangles_width = 560
const resizable_rectangles_height = 220
const resizable_rectangles_vml_source = $embed_file('rectangles_resizable.vml').to_string()

pub struct ResizableColorBox {
pub:
	id         int
	name       string
	color      string
	text_color string
}

pub struct ResizableRectanglesDemo {
pub:
	colors []ResizableColorBox
}

fn initial_resizable_rectangles() ResizableRectanglesDemo {
	return ResizableRectanglesDemo{
		colors: [
			ResizableColorBox{ id: 1, name: 'Red', color: '#FF6464', text_color: '#5F1111' },
			ResizableColorBox{ id: 2, name: 'Green', color: '#64FF64', text_color: '#14532D' },
			ResizableColorBox{ id: 3, name: 'Blue', color: '#6464FF', text_color: '#FFFFFF' },
			ResizableColorBox{ id: 4, name: 'Pink', color: '#FF64FF', text_color: '#701A75' },
		]
	}
}

fn main() {
	ui2.run_vml[ResizableRectanglesDemo](
		source: resizable_rectangles_vml_source
		model: initial_resizable_rectangles()
		title: 'Resizable Rectangles'
		width: resizable_rectangles_width
		height: resizable_rectangles_height
	) or { panic(err) }
}
