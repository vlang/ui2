module main

import ui2

const accordion_width = 620
const accordion_height = 460
const accordion_vml_source = $embed_file('accordion.vml').to_string()

pub struct AccordionSection {
pub:
	id          int
	title       string
	description string
	detail      string
	color       string
}

pub struct AccordionDemo {
pub:
	sections []AccordionSection
pub mut:
	open_id int = 1
	status  string = 'Rectangle is open.'
}

fn initial_accordion() AccordionDemo {
	return AccordionDemo{
		sections: [
			AccordionSection{ id: 1, title: 'Rectangle', description: 'A responsive colored surface.', detail: 'The original page contains a simple red rectangle.', color: '#FEE2E2' },
			AccordionSection{ id: 2, title: 'Radio', description: 'A compact exclusive-choice group.', detail: 'This port uses ui2 portable selection controls.', color: '#DCFCE7' },
			AccordionSection{ id: 3, title: 'Slider', description: 'A compact value-control overview.', detail: 'The source accordion includes horizontal and vertical sliders.', color: '#DBEAFE' },
			AccordionSection{ id: 4, title: 'Group', description: 'Related controls presented together.', detail: 'See the dedicated group example for editable fields.', color: '#F3E8FF' },
			AccordionSection{ id: 5, title: 'Dropdown', description: 'Choose one item from a menu.', detail: 'See the dedicated dropdown example for live feedback.', color: '#FEF3C7' },
		]
	}
}

pub fn (mut app AccordionDemo) toggle_section(id int) {
	if app.open_id == id {
		app.open_id = -1
		app.status = 'All sections are collapsed.'
		return
	}
	for section in app.sections {
		if section.id == id {
			app.open_id = id
			app.status = '${section.title} is open.'
			return
		}
	}
}

fn main() {
	ui2.run_vml[AccordionDemo](
		source: accordion_vml_source
		model: initial_accordion()
		title: 'Accordion'
		width: accordion_width
		height: accordion_height
	) or { panic(err) }
}
