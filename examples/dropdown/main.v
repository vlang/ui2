module main

import ui2

const dropdown_width = 360
const dropdown_height = 220
const dropdown_vml_source = $embed_file('dropdown.vml').to_string()

pub struct DropdownDemo {
pub mut:
	selection string = 'Select an option'
	message   string = 'Choose an action from the menu.'
}

pub fn (mut app DropdownDemo) selection_changed() {
	app.message = match app.selection {
		'Delete all users' { 'Delete all users selected.' }
		'Export users' { 'Export users selected.' }
		'Exit' { 'Exit selected.' }
		else { 'Choose an action from the menu.' }
	}
}

fn main() {
	ui2.run_vml[DropdownDemo](
		source: dropdown_vml_source
		model: DropdownDemo{}
		title: 'Dropdown'
		width: dropdown_width
		height: dropdown_height
	) or { panic(err) }
}
