module main

import ui2

const scrollview_width = 720
const scrollview_height = 430
const scrollview_vml_source = $embed_file('scrollview.vml').to_string()

pub struct ScrollviewDemo {
pub:
	info string
	text string
}

fn initial_scrollview() ScrollviewDemo {
	mut lines := []string{cap: 100}
	for index in 0 .. 100 {
		lines << 'line ${index:02}  ·  V UI scrollable content'
	}
	return ScrollviewDemo{
		info: 'Both panes use native multiline scrolling.\n\nThe right pane contains 100 generated lines. Each pane keeps its own scroll position while the window resizes.'
		text: lines.join('\n')
	}
}

fn main() {
	ui2.run_vml[ScrollviewDemo](
		source: scrollview_vml_source
		model: initial_scrollview()
		title: 'Scrollview'
		width: scrollview_width
		height: scrollview_height
	) or { panic(err) }
}
