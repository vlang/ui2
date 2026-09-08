module main

import ui2

const textbox_width = 640
const textbox_height = 430
const textbox_vml_source = $embed_file('textbox.vml').to_string()

pub struct TextboxDemo {
pub mut:
	title        string = 'Release notes'
	notes        string = 'Type multiline text here.\nThe preview stays read-only.'
	show_preview bool = true
	status       string = '54 characters'
}

pub fn (mut app TextboxDemo) update_status() {
	app.status = '${app.notes.runes().len} characters'
}

pub fn (mut app TextboxDemo) clear() {
	app.notes = ''
	app.update_status()
}

fn main() {
	ui2.run_vml[TextboxDemo](
		source: textbox_vml_source
		model: TextboxDemo{}
		title: 'Textbox Demo'
		width: textbox_width
		height: textbox_height
	) or { panic(err) }
}
