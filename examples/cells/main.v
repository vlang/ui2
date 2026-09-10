module main

import ui2

const cells_width = 780
const cells_height = 560
const cells_vml_source = $embed_file('cells.vml').to_string()

pub struct SheetColumn {
pub:
	id     int
	label  string
	column int
}

pub struct SheetRow {
pub:
	id    int
	row   int
	label string
}

pub struct SheetCell {
pub:
	id      int
	address string
	row     int
	column  int
pub mut:
	raw     string
	display string
	formula bool
}

pub struct CellsDemo {
pub:
	columns []SheetColumn
	rows    []SheetRow
pub mut:
	cells            []SheetCell
	selected_id      int = -1
	selected_address string
	edit_value       string
	status           string = 'Select a cell to inspect or edit its value.'
}

fn sheet_address(column int, row int) string {
	return '${rune(`A` + column)}${row + 1}'
}

fn sheet_coordinates(address string) !(int, int) {
	trimmed := address.trim_space().to_upper()
	if trimmed.len < 2 || trimmed[0] < `A` || trimmed[0] > `E` {
		return error('invalid cell `${address}`')
	}
	row := trimmed[1..].int() - 1
	if row < 0 || row >= 6 {
		return error('invalid cell `${address}`')
	}
	return int(trimmed[0] - `A`), row
}

fn initial_cells() CellsDemo {
	mut columns := []SheetColumn{}
	for column in 0 .. 5 {
		columns << SheetColumn{ id: column, label: rune(`A` + column).str(), column: column }
	}
	mut rows := []SheetRow{}
	mut cells := []SheetCell{}
	for row in 0 .. 6 {
		rows << SheetRow{ id: row, row: row, label: (row + 1).str() }
		for column in 0 .. 5 {
			cells << SheetCell{
				id: row * 5 + column
				address: sheet_address(column, row)
				row: row
				column: column
			}
		}
	}
	mut app := CellsDemo{ columns: columns, rows: rows, cells: cells }
	app.set_raw('A1', 'Sum B2:C5 + D2')
	app.set_raw('B1', '=sum(B2:C5, D2)')
	app.set_raw('B2', '12')
	app.set_raw('B3', '1')
	app.set_raw('B4', '1')
	app.set_raw('B5', '23')
	app.set_raw('C2', '13')
	app.set_raw('C3', '-1')
	app.set_raw('C4', '31')
	app.set_raw('C5', '=sum(D2:D5)')
	app.set_raw('D2', '3')
	app.set_raw('D3', '10')
	app.set_raw('D4', '1')
	app.set_raw('D5', '24')
	app.set_raw('A4', '=sum(B4:D4)')
	app.recalculate()
	return app
}

fn (mut app CellsDemo) set_raw(address string, value string) {
	for index, cell in app.cells {
		if cell.address == address {
			app.cells[index].raw = value
			app.cells[index].display = value
			app.cells[index].formula = value.starts_with('=')
			return
		}
	}
}

fn (app &CellsDemo) numeric_value(address string) f64 {
	for cell in app.cells {
		if cell.address == address {
			return cell.display.f64()
		}
	}
	return 0
}

fn format_sheet_number(value f64) string {
	if value == f64(int(value)) {
		return int(value).str()
	}
	return '${value:.6f}'.trim_right('0').trim_right('.')
}

fn (app &CellsDemo) evaluate_formula(formula string) !f64 {
	trimmed := formula.trim_space()
	if !trimmed.to_lower().starts_with('=sum(') || !trimmed.ends_with(')') {
		return error('only sum formulas are supported')
	}
	body := trimmed[5..trimmed.len - 1]
	mut total := 0.0
	for raw_part in body.split(',') {
		part := raw_part.trim_space()
		if part.contains(':') {
			bounds := part.split(':')
			if bounds.len != 2 {
				return error('invalid range `${part}`')
			}
			start_column, start_row := sheet_coordinates(bounds[0])!
			end_column, end_row := sheet_coordinates(bounds[1])!
			for row in start_row .. end_row + 1 {
				for column in start_column .. end_column + 1 {
					total += app.numeric_value(sheet_address(column, row))
				}
			}
		} else {
			sheet_coordinates(part)!
			total += app.numeric_value(part.to_upper())
		}
	}
	return total
}

fn (mut app CellsDemo) recalculate() {
	for _ in 0 .. app.cells.len {
		for index, cell in app.cells {
			if !cell.formula {
				app.cells[index].display = cell.raw
				continue
			}
			value := app.evaluate_formula(cell.raw) or {
				app.cells[index].display = '#ERR'
				continue
			}
			app.cells[index].display = format_sheet_number(value)
		}
	}
}

pub fn (mut app CellsDemo) select_cell(id int) {
	for cell in app.cells {
		if cell.id == id {
			app.selected_id = id
			app.selected_address = cell.address
			app.edit_value = cell.raw
			app.status = '${cell.address} selected.'
			return
		}
	}
}

pub fn (mut app CellsDemo) apply_edit() {
	if app.selected_id < 0 {
		app.status = 'Select a cell first.'
		return
	}
	for index, cell in app.cells {
		if cell.id == app.selected_id {
			app.cells[index].raw = app.edit_value
			app.cells[index].formula = app.edit_value.trim_space().starts_with('=')
			app.recalculate()
			app.status = '${cell.address} updated.'
			return
		}
	}
}

fn main() {
	ui2.run_vml[CellsDemo](
		source: cells_vml_source
		model: initial_cells()
		title: 'Cells'
		width: cells_width
		height: cells_height
	) or {
		panic(err)
	}
}
