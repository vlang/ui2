module main

import ui2

const grid_width = 600
const grid_height = 300
const grid_vml_source = $embed_file('grid.vml').to_string()

pub struct GridCell {
pub:
	id     int
	row    int
	column int
	text   string
	header bool
}

pub struct GridDemo {
pub:
	cells []GridCell
}

fn initial_grid() GridDemo {
	rows := [
		['One', 'Two', 'Three'],
		['body one', 'body two', 'body three'],
		['V', 'UI is', 'Beautiful'],
	]
	mut cells := []GridCell{cap: 9}
	for row, values in rows {
		for column, value in values {
			cells << GridCell{
				id: row * 3 + column
				row: row
				column: column
				text: value
				header: row == 0
			}
		}
	}
	return GridDemo{
		cells: cells
	}
}

fn main() {
	ui2.run_vml[GridDemo](
		source: grid_vml_source
		model: initial_grid()
		title: 'Grid'
		width: grid_width
		height: grid_height
	) or { panic(err) }
}
