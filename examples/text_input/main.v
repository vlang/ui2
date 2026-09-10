module main

import ui2

const text_input_width = 430
const text_input_height = 300
const text_input_vml_source = $embed_file('text_input.vml').to_string()

pub struct TextInputDemo {
pub mut:
	title string = 'Draft'
	notes string = 'Unicode, selection, clipboard, and undo are handled by the native editor.'
	saved string
}

pub fn (mut app TextInputDemo) save() {
	app.saved = app.title
}

fn main() {
	ui2.run_vml[TextInputDemo](
		source: text_input_vml_source
		model: TextInputDemo{}
		title: 'Text Input'
		width: text_input_width
		height: text_input_height
	) or { panic(err) }
}
