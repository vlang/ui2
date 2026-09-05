module main

import ui2

const box_textbox_width = 560
const box_textbox_height = 400
const box_textbox_qml_source = $embed_file('box_layout_with_textbox.qml').to_string()

pub struct BoxLayoutTextboxDemo {
pub mut:
	text   string
	status string
}

fn initial_box_layout_textbox() BoxLayoutTextboxDemo {
	return BoxLayoutTextboxDemo{
		text: 'blah blah blah\n'.repeat(10).trim_right('\n')
		status: 'Edit the yellow text area, or show the original message.'
	}
}

pub fn (mut app BoxLayoutTextboxDemo) text_changed() {
	lines := if app.text.len == 0 { 0 } else { app.text.split_into_lines().len }
	app.status = '${lines} lines, ${app.text.runes().len} characters'
}

pub fn (mut app BoxLayoutTextboxDemo) show_message() {
	app.status = 'coucou toto!'
}

fn main() {
	ui2.run_qml[BoxLayoutTextboxDemo](
		source: box_textbox_qml_source
		model: initial_box_layout_textbox()
		title: 'Box Layout with Textbox'
		width: box_textbox_width
		height: box_textbox_height
	) or {
		panic(err)
	}
}
