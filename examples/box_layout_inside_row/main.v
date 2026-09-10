module main

import ui2

const box_row_width = 560
const box_row_height = 400
const box_row_vml_source = $embed_file('box_layout_inside_row.vml').to_string()

pub struct BoxLayoutInsideRowDemo {
pub mut:
	text   string
	moved  bool
	status string = 'The text area starts at 70% of the inset stage.'
}

fn initial_box_layout_inside_row() BoxLayoutInsideRowDemo {
	return BoxLayoutInsideRowDemo{
		text: 'blah3 blah blah\n'.repeat(10).trim_right('\n')
	}
}

pub fn (mut app BoxLayoutInsideRowDemo) toggle_position() {
	app.moved = !app.moved
	app.status = if app.moved {
		'The text area now starts at 80% and occupies 20%.'
	} else {
		'The text area starts at 70% of the inset stage.'
	}
}

fn main() {
	ui2.run_vml[BoxLayoutInsideRowDemo](
		source: box_row_vml_source
		model: initial_box_layout_inside_row()
		title: 'Box Layout inside Row'
		width: box_row_width
		height: box_row_height
	) or { panic(err) }
}
