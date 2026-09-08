module main

import ui2

const page_width = 420
const page_height = 280
const page_qml_source = $embed_file('page_layout.qml').to_string()

pub struct PageLayoutDemo {
pub mut:
	page int
}

pub fn (mut app PageLayoutDemo) previous() {
	app.page = ui2.page_layout_previous(app.page, 3)
}

pub fn (mut app PageLayoutDemo) next() {
	app.page = ui2.page_layout_next(app.page, 3)
}

fn main() {
	ui2.run_qml[PageLayoutDemo](
		source: page_qml_source
		model: PageLayoutDemo{}
		title: 'Page Layout'
		width: page_width
		height: page_height
	) or { panic(err) }
}
