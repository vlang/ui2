module main

import ui2

const tabbed_width = 440
const tabbed_height = 300
const tabbed_vml_source = $embed_file('tabbed_panel.vml').to_string()

pub struct TabbedPanelDemo {
pub mut:
	current int
}

pub fn (mut app TabbedPanelDemo) show_overview() {
	app.current = 0
}

pub fn (mut app TabbedPanelDemo) show_activity() {
	app.current = 1
}

pub fn (mut app TabbedPanelDemo) show_security() {
	app.current = 2
}

fn main() {
	ui2.run_vml[TabbedPanelDemo](
		source: tabbed_vml_source
		model: TabbedPanelDemo{}
		title: 'Tabbed Panel'
		width: tabbed_width
		height: tabbed_height
	) or { panic(err) }
}
