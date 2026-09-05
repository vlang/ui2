module main

import ui2

const group_width = 380
const group_height = 350
const group_qml_source = $embed_file('group.qml').to_string()

pub struct GroupDemo {
pub mut:
	first_name    string
	last_name     string
	registration1 bool = true
	registration2 bool = true
	registration3 bool = true
	message       string = 'Enter a first and last name.'
}

pub fn (mut app GroupDemo) submit() {
	first := app.first_name.trim_space()
	last := app.last_name.trim_space()
	if first.len == 0 || last.len == 0 {
		app.message = 'Both names are required.'
		return
	}
	app.message = 'Added ${first} ${last}.'
}

fn main() {
	ui2.run_qml[GroupDemo](
		source: group_qml_source
		model: GroupDemo{}
		title: 'Group Demo'
		width: group_width
		height: group_height
	) or { panic(err) }
}
