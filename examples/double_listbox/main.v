module main

import ui2

const double_list_width = 700
const double_list_height = 460
const double_list_vml_source = $embed_file('double_listbox.vml').to_string()

pub struct TransferChoice {
pub:
	id    int
	label string
}

pub struct DoubleListboxDemo {
pub mut:
	available []TransferChoice
	selected  []TransferChoice
	status    string = 'Click an item to move it between lists.'
}

fn initial_double_listbox() DoubleListboxDemo {
	return DoubleListboxDemo{
		available: [
			TransferChoice{ id: 1, label: 'Alpha' },
			TransferChoice{ id: 2, label: 'Bravo' },
			TransferChoice{ id: 3, label: 'Charlie' },
			TransferChoice{ id: 4, label: 'Delta' },
			TransferChoice{ id: 5, label: 'Echo' },
		]
	}
}

pub fn (mut app DoubleListboxDemo) move_right(id int) {
	for index, item in app.available {
		if item.id == id {
			app.selected << item
			app.available.delete(index)
			app.status = 'Moved ${item.label} to selected.'
			return
		}
	}
}

pub fn (mut app DoubleListboxDemo) move_left(id int) {
	for index, item in app.selected {
		if item.id == id {
			app.available << item
			app.selected.delete(index)
			app.status = 'Moved ${item.label} to available.'
			return
		}
	}
}

pub fn (mut app DoubleListboxDemo) reset() {
	initial := initial_double_listbox()
	app.available = initial.available
	app.selected = []
	app.status = 'Lists reset.'
}

pub fn (mut app DoubleListboxDemo) show_values() {
	values := app.selected.map(it.label).join(', ')
	app.status = if values.len > 0 { 'Selected: ${values}' } else { 'Selected: none' }
}

fn main() {
	ui2.run_vml[DoubleListboxDemo](
		source: double_list_vml_source
		model: initial_double_listbox()
		title: 'Double Listbox'
		width: double_list_width
		height: double_list_height
	) or { panic(err) }
}
