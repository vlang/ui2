module main

import ui2

const accordion_width = 440
const accordion_height = 320
const accordion_vml_source = $embed_file('accordion_widget.vml').to_string()

pub struct AccordionDemo {
pub mut:
	current int
}

pub fn (mut app AccordionDemo) show_profile() {
	app.current = 0
}

pub fn (mut app AccordionDemo) show_notifications() {
	app.current = 1
}

pub fn (mut app AccordionDemo) show_security() {
	app.current = 2
}

fn main() {
	ui2.run_vml[AccordionDemo](
		source: accordion_vml_source
		model: AccordionDemo{}
		title: 'Accordion'
		width: accordion_width
		height: accordion_height
	) or { panic(err) }
}
