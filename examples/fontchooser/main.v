module main

import ui2

const fontchooser_width = 720
const fontchooser_height = 460
const fontchooser_vml_source = $embed_file('fontchooser.vml').to_string()

pub struct FontChooserDemo {
pub mut:
	font_choice  string = 'System'
	font_family  string
	size_choice  string = '30'
	font_size    f64 = 30
	color_choice string = 'Red'
	text_color   string = '#B91C1C'
	bold         bool = true
	italic       bool
	text         string = 'il était une fois V ....\nLa vie est belle...'
	status       string = 'System, 30 pt, red'
}

pub fn (mut app FontChooserDemo) style_changed() {
	app.font_family = match app.font_choice {
		'Serif' { 'Times New Roman' }
		'Monospace' { 'Courier New' }
		'Arial' { 'Arial' }
		else { '' }
	}
	app.font_size = app.size_choice.f64()
	app.text_color = match app.color_choice {
		'Blue' { '#1D4ED8' }
		'Green' { '#15803D' }
		'Purple' { '#7E22CE' }
		else { '#B91C1C' }
	}
	app.status = '${app.font_choice}, ${app.size_choice} pt, ${app.color_choice.to_lower()}'
}

pub fn (mut app FontChooserDemo) reset_style() {
	app.font_choice = 'System'
	app.font_family = ''
	app.size_choice = '30'
	app.font_size = 30
	app.color_choice = 'Red'
	app.text_color = '#B91C1C'
	app.bold = true
	app.italic = false
	app.status = 'System, 30 pt, red'
}

fn main() {
	ui2.run_vml[FontChooserDemo](
		source: fontchooser_vml_source
		model: FontChooserDemo{}
		title: 'Font Chooser'
		width: fontchooser_width
		height: fontchooser_height
	) or {
		panic(err)
	}
}
