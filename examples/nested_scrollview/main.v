module main

import ui2

const nested_scrollview_width = 620
const nested_scrollview_height = 400
const nested_scrollview_vml_source = $embed_file('nested_scrollview.vml').to_string()

pub struct NestedScrollBox {
pub:
	id      int
	title   string
	content string
}

pub struct NestedScrollviewDemo {
pub:
	boxes []NestedScrollBox
}

fn initial_nested_scrollview() NestedScrollviewDemo {
	mut boxes := []NestedScrollBox{cap: 12}
	for index in 0 .. 12 {
		number := index + 1
		boxes << NestedScrollBox{
			id: number
			title: 'Box ${number}'
			content: 'line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7\nline 8'
		}
	}
	return NestedScrollviewDemo{
		boxes: boxes
	}
}

fn main() {
	ui2.run_vml[NestedScrollviewDemo](
		source: nested_scrollview_vml_source
		model: initial_nested_scrollview()
		title: 'Nested Scrollviews'
		width: nested_scrollview_width
		height: nested_scrollview_height
	) or { panic(err) }
}
