module main

import ui2

const tabbed_width = 440
const tabbed_height = 300
const tabbed_qml_source = $embed_file('tabbed_panel.qml').to_string()

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
	ui2.run_qml[TabbedPanelDemo](
		source: tabbed_qml_source
		model: TabbedPanelDemo{}
		title: 'Tabbed Panel'
		width: tabbed_width
		height: tabbed_height
	) or { panic(err) }
}
