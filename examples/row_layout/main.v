module main

import ui2

const row_layout_width = 760
const row_layout_height = 420
const row_layout_qml_source = $embed_file('row_layout.qml').to_string()

pub struct RowLayoutDemo {
pub mut:
	width_choice   string = '30 / 70'
	margin_choice  string = '24'
	spacing_choice string = '20'
	height_choice  string = '44'
	first_ratio    f64 = 0.3
	row_margin     f64 = 24
	row_spacing    f64 = 20
	button_height  f64 = 44
	status         string = '30 / 70 · margin 24 · spacing 20 · height 44'
}

pub fn (mut app RowLayoutDemo) layout_changed() {
	app.first_ratio = match app.width_choice {
		'50 / 50' { 0.5 }
		'70 / 30' { 0.7 }
		else { 0.3 }
	}
	app.row_margin = app.margin_choice.f64()
	app.row_spacing = app.spacing_choice.f64()
	app.button_height = app.height_choice.f64()
	app.status = '${app.width_choice} · margin ${app.margin_choice} · spacing ${app.spacing_choice} · height ${app.height_choice}'
}

pub fn (mut app RowLayoutDemo) reset_layout() {
	app.width_choice = '30 / 70'
	app.margin_choice = '24'
	app.spacing_choice = '20'
	app.height_choice = '44'
	app.layout_changed()
}

fn main() {
	ui2.run_qml[RowLayoutDemo](
		source: row_layout_qml_source
		model: RowLayoutDemo{}
		title: 'Row Layout'
		width: row_layout_width
		height: row_layout_height
	) or {
		panic(err)
	}
}
