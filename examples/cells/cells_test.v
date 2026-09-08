module main

import ui2

fn find_cells_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_cells_element(child, id) {
			return found
		}
	}
	return none
}

fn cell_by_address(app CellsDemo, address string) SheetCell {
	for cell in app.cells {
		if cell.address == address {
			return cell
		}
	}
	panic('missing cell ${address}')
}

fn test_cells_calculates_original_sum_formulas() {
	app := initial_cells()
	assert app.rows.map(it.label) == ['1', '2', '3', '4', '5', '6']
	assert cell_by_address(app, 'B1').display == '121'
	assert cell_by_address(app, 'C5').display == '38'
	assert cell_by_address(app, 'A4').display == '33'
}

fn test_cells_edit_recalculates_dependent_formula() {
	mut app := initial_cells()
	app.select_cell(6)
	assert app.selected_address == 'B2'
	app.edit_value = '20'
	app.apply_edit()
	assert cell_by_address(app, 'B1').display == '129'
	assert app.status == 'B2 updated.'
}

fn test_cells_vml_builds_keyed_native_spreadsheet_cells() {
	app := initial_cells()
	root := ui2.element_from_vml_model(cells_vml_source, app, ui2.rect(0, 0, cells_width, cells_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	sheet := find_cells_element(root, 'sheet') or { panic('missing sheet') }
	assert sheet.children.len == 42
	first_cell := sheet.children[12]
	assert first_cell.key == 'A1'
	assert first_cell.native_style
	assert (find_cells_element(root, 'cell_input') or { panic('missing cell input') }).submit_id.len > 0
	assert (find_cells_element(root, 'apply_cell') or { panic('missing apply') }).native_style
}
