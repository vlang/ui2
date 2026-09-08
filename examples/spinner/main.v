module main

import ui2

const spinner_width = 360
const spinner_height = 190
const spinner_qml_source = $embed_file('spinner.qml').to_string()

pub struct SpinnerDemo {
pub mut:
	selection string = 'Home'
	message   string = 'Home selected.'
}

pub fn (mut app SpinnerDemo) selection_changed() {
	app.message = '${app.selection} selected.'
}

fn main() {
	ui2.run_qml[SpinnerDemo](
		source: spinner_qml_source
		model: SpinnerDemo{}
		title: 'Spinner'
		width: spinner_width
		height: spinner_height
	) or { panic(err) }
}
