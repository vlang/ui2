module main

import ui2

fn find_pc_specs_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_pc_specs_element(child, id) {
			return found
		}
	}
	return none
}

fn test_pc_specs_collects_expected_rows() {
	rows := collect_rows()
	assert rows.len == 8
	labels := rows.map(it.label)
	assert labels[0] == 'Hostname'
	assert labels[1] == 'Operating system'
	assert labels[2] == 'Kernel'
	assert labels[3] == 'Architecture'
	assert labels[4] == 'CPU'
	assert labels[5] == 'Logical cores'
	assert labels[6] == 'Total memory'
	assert labels[7].starts_with('Disk ')
	hostname := rows[0].value
	assert hostname.len > 0
	cores := rows[5].value.int()
	assert cores > 0
	for index, row in rows {
		assert row.index == index
		assert row.value.trim_space().len > 0
	}
}

fn test_pc_specs_formats_gigabytes() {
	assert format_gigabytes(u64(1024) * 1024 * 1024) == '1.0 GiB'
	assert format_gigabytes(u64(16) * 1024 * 1024 * 1024) == '16.0 GiB'
}

fn test_pc_specs_refresh_updates_status() {
	mut app := PcSpecsDemo{
		rows: collect_rows()
	}
	app.status = ''
	app.refresh()
	assert app.status.starts_with('Specs refreshed at ')
	assert app.rows.len == 8
}

fn test_pc_specs_vml_builds_table_rows() {
	app := PcSpecsDemo{
		rows: collect_rows()
	}
	root := ui2.element_from_vml_model(pc_specs_vml_source, app, ui2.rect(0, 0, pc_specs_width, pc_specs_height)) or {
		panic(err)
	}
	ui2.validate_element_tree(root) or { panic(err) }
	table := find_pc_specs_element(root, 'table') or { panic('missing table') }
	// one header row plus one keyed row per spec entry
	assert table.children.len == 1 + app.rows.len
	assert (find_pc_specs_element(root, 'refresh_button') or { panic('missing refresh') }).native_style
}
