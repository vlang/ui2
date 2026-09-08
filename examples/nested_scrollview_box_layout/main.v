module main

import ui2

const nested_box_width = 660
const nested_box_height = 430
const nested_box_vml_source = $embed_file('nested_scrollview_box_layout.vml').to_string()

pub struct ScrollGridBox {
pub:
	id      int
	row     int
	column  int
	content string
}

pub struct NestedScrollBoxLayoutDemo {
pub:
	boxes []ScrollGridBox
}

fn initial_nested_scroll_box_layout() NestedScrollBoxLayoutDemo {
	mut boxes := []ScrollGridBox{cap: 25}
	for row in 0 .. 5 {
		for column in 0 .. 5 {
			boxes << ScrollGridBox{
				id: row * 5 + column
				row: row
				column: column
				content: 'box ${row}${column}\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7\nline 8'
			}
		}
	}
	return NestedScrollBoxLayoutDemo{ boxes: boxes }
}

fn main() {
	ui2.run_vml[NestedScrollBoxLayoutDemo](
		source: nested_box_vml_source
		model: initial_nested_scroll_box_layout()
		title: 'Nested Scrollviews in Box Layout'
		width: nested_box_width
		height: nested_box_height
	) or { panic(err) }
}
