module main

import ui2

fn find_grid2_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_grid2_element(child, id) {
			return found
		}
	}
	return none
}

fn test_grid2_builds_typed_columns_for_every_record() {
	app := grid2_demo()
	assert app.rows.len == grid2_row_count
	assert app.columns.map(it.key) == ['v1', 'v2', 'sex', 'worker', 'csp']
	assert app.rows[0].v1 == 'toto'
	assert app.rows[0].sex == 'Male'
	assert app.rows[0].worker == 'yes'
	assert app.rows[0].csp == 'job1'
	assert app.rows[2].worker == 'no'
	assert app.rows[1].stripe == '#F8FAFC'
	assert app.status == '32 rows · sorted by row order · row 1 selected'
}

fn test_grid2_sorting_toggles_direction_and_renumbers_rows() {
	mut app := grid2_demo()
	app.sort_by('sex')
	assert app.rows.first().sex == 'Female'
	assert app.rows.last().sex == 'Male'
	assert app.rows.first().number == '1'
	assert app.columns[2].label == 'sex ▲'
	// Ties keep the original record order.
	assert app.rows[0].id == 3
	assert app.rows[1].id == 6
	app.sort_by('sex')
	assert app.columns[2].label == 'sex ▼'
	assert app.rows.first().sex == 'Male'
	app.reset_sort()
	assert app.rows.map(it.id)[..3] == [1, 2, 3]
	assert app.columns[2].label == 'sex'
}

fn test_grid2_editing_writes_back_to_the_selected_record() {
	mut app := grid2_demo()
	app.select_row(7)
	assert app.selected == 7
	assert app.edit_v1 == 'toto'
	assert app.edit_worker
	app.edit_v1 = 'tutu'
	app.edit_csp = 'other'
	app.edit_worker = false
	app.apply_edits()
	assert app.rows[6].v1 == 'tutu'
	assert app.rows[6].csp == 'other'
	assert app.rows[6].worker == 'no'
	assert app.rows[6].selected
	assert app.status.starts_with('Row 7 updated ·')
	// A value outside the factor's levels is refused instead of corrupting it.
	app.edit_sex = 'Other'
	app.apply_edits()
	assert app.rows[6].sex == 'Male'
}

fn test_grid2_qml_scrolls_the_body_and_repeats_sortable_headers() {
	app := grid2_demo()
	frame := ui2.rect(0, 0, grid2_width, grid2_height)
	root := ui2.element_from_qml_model(grid2_qml_source, app, frame) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	header := find_grid2_element(root, 'header') or { panic('missing header') }
	assert header.children.len == 6
	assert header.children[1].text == 'v1'
	body := find_grid2_element(root, 'body') or { panic('missing body') }
	assert body.persistent_scrollbars
	assert body.children.len == grid2_row_count
	first := body.children[0]
	assert first.key == 'row-1'
	assert first.frame.y == 0
	assert body.children[1].frame.y == 32
	// The rows are taller than the viewport, which is what makes the body scroll.
	assert f64(grid2_row_count) * 32 > body.frame.height
	csp := find_grid2_element(root, 'edit_csp') or { panic('missing csp dropdown') }
	worker := find_grid2_element(root, 'edit_worker') or { panic('missing checkbox') }
	editor := find_grid2_element(root, 'editor') or { panic('missing editor') }
	assert worker.checked
	assert worker.frame.x >= csp.frame.x + csp.frame.width
	assert worker.frame.x + worker.frame.width <= editor.frame.width
}

fn test_grid2_qml_compact_editor_keeps_fields_and_worker_checkbox_separate() {
	app := grid2_demo()
	root := ui2.element_from_qml_model(grid2_qml_source, app, ui2.rect(0, 0, 524, grid2_height)) or {
		panic(err)
	}
	ui2.validate_element_tree(root) or { panic(err) }
	v1 := find_grid2_element(root, 'edit_v1') or { panic('missing first editor field') }
	v2 := find_grid2_element(root, 'edit_v2') or { panic('missing second editor field') }
	sex := find_grid2_element(root, 'edit_sex') or { panic('missing sex dropdown') }
	csp := find_grid2_element(root, 'edit_csp') or { panic('missing csp dropdown') }
	worker := find_grid2_element(root, 'edit_worker') or { panic('missing worker checkbox') }
	editor := find_grid2_element(root, 'editor') or { panic('missing editor') }

	assert v1.frame.y == v2.frame.y
	assert sex.frame.y == csp.frame.y
	assert v1.frame.y < sex.frame.y
	assert v2.frame.x >= v1.frame.x + v1.frame.width
	assert csp.frame.x >= sex.frame.x + sex.frame.width
	assert worker.frame.x >= csp.frame.x + csp.frame.width
	assert worker.frame.x + worker.frame.width <= editor.frame.width
}
