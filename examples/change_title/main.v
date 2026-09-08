module main

import ui2

const change_title_width = 520
const change_title_height = 250
const change_title_vml_source = $embed_file('change_title.vml').to_string()

pub struct ChangeTitleDemo {
pub mut:
	title         string = 'Name'
	applied_title string = 'Name'
	valid         bool = true
	status        string = 'Enter a new window title.'
}

pub fn (mut app ChangeTitleDemo) apply_title() {
	title := app.title.trim_space()
	if title.len == 0 {
		app.valid = false
		app.status = 'The window title cannot be empty.'
		return
	}
	app.title = title
	app.applied_title = title
	app.valid = true
	app.status = 'Window title changed to “${title}”.'
	apply_window_title(title)
}

fn main() {
	ui2.run_vml[ChangeTitleDemo](
		source: change_title_vml_source
		model: ChangeTitleDemo{}
		title: 'Name'
		width: change_title_width
		height: change_title_height
	) or { panic(err) }
}
