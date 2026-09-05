module main

import ui2

const splitpanel_width = 800
const splitpanel_height = 600
const splitpanel_qml_source = $embed_file('splitpanel.qml').to_string()

pub struct SplitRow {
pub:
	id   int
	name string
	role string
	team string
}

pub struct SplitPanelDemo {
pub:
	rows []SplitRow
pub mut:
	top_weight  f64 = 0.28
	left_weight f64 = 0.34
	notes       string = 'This editable pane mirrors the text area in the original split-panel demo.\n\nUse the controls above to resize both split axes.'
	status      string = 'Top 28% · left 34%'
}

fn initial_splitpanel() SplitPanelDemo {
	return SplitPanelDemo{
		rows: [
			SplitRow{ id: 1, name: 'Toto', role: 'Developer', team: 'Core' },
			SplitRow{ id: 2, name: 'Titi', role: 'Designer', team: 'UI' },
			SplitRow{ id: 3, name: 'Tata', role: 'Tester', team: 'Tools' },
			SplitRow{ id: 4, name: 'Tutu', role: 'Writer', team: 'Docs' },
			SplitRow{ id: 5, name: 'Tete', role: 'Manager', team: 'Release' },
		]
	}
}

fn split_clamp(value f64) f64 {
	return if value < 0.18 {
		0.18
	} else if value > 0.62 { 0.62 } else { value }
}

fn (mut app SplitPanelDemo) update_status() {
	app.status = 'Top ${int(app.top_weight * 100)}% · left ${int(app.left_weight * 100)}%'
}

pub fn (mut app SplitPanelDemo) top_less() {
	app.top_weight = split_clamp(app.top_weight - 0.05)
	app.update_status()
}

pub fn (mut app SplitPanelDemo) top_more() {
	app.top_weight = split_clamp(app.top_weight + 0.05)
	app.update_status()
}

pub fn (mut app SplitPanelDemo) left_less() {
	app.left_weight = split_clamp(app.left_weight - 0.05)
	app.update_status()
}

pub fn (mut app SplitPanelDemo) left_more() {
	app.left_weight = split_clamp(app.left_weight + 0.05)
	app.update_status()
}

pub fn (mut app SplitPanelDemo) reset_splits() {
	app.top_weight = 0.28
	app.left_weight = 0.34
	app.update_status()
}

fn main() {
	ui2.run_qml[SplitPanelDemo](
		source: splitpanel_qml_source
		model: initial_splitpanel()
		title: 'Split Panel'
		width: splitpanel_width
		height: splitpanel_height
	) or {
		panic(err)
	}
}
