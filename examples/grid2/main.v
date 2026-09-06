module main

import ui2

const grid2_width = 880
const grid2_height = 640
const grid2_qml_source = $embed_file('grid2.qml').to_string()
const grid2_row_count = 32
const grid2_sex_levels = ['Male', 'Female']
const grid2_csp_levels = ['job1', 'job2', 'other']

// GridColumn is one sortable header. `index` places it, `key` names the record
// field it sorts on, and `label` carries the current sort marker.
pub struct GridColumn {
pub:
	id    int
	key   string
	name  string
	index int
pub mut:
	label string
}

// GridRow is the projection the QML repeater draws: already sorted, already
// numbered, and already told whether it is the selected record.
pub struct GridRow {
pub:
	id       int
	key      string
	number   string
	v1       string
	v2       string
	sex      string
	worker   string
	csp      string
	selected bool
	stripe   string
}

struct GridRecord {
	id int
mut:
	v1     string
	v2     string
	sex    string
	worker bool
	csp    string
}

@[heap]
pub struct Grid2Demo {
pub mut:
	columns     []GridColumn
	rows        []GridRow
	selected    int = 1
	edit_v1     string
	edit_v2     string
	edit_sex    string
	edit_csp    string
	edit_worker bool
	status      string
mut:
	records    []GridRecord
	sort_key   string = 'id'
	descending bool
}

fn grid2_columns() []GridColumn {
	names := [['v1', 'v1'], ['v2', 'v2'], ['sex', 'sex'], ['worker', 'worker'], ['csp', 'csp']]
	mut columns := []GridColumn{cap: names.len}
	for index, entry in names {
		columns << GridColumn{
			id: index + 1
			key: entry[0]
			name: entry[1]
			index: index
			label: entry[1]
		}
	}
	return columns
}

fn grid2_demo() Grid2Demo {
	mut app := Grid2Demo{
		columns: grid2_columns()
	}
	v1_values := ['toto', 'titi', 'tata']
	v2_values := ['toti', 'tito', 'tato']
	sex_pattern := [0, 0, 1]
	worker_pattern := [true, true, false]
	csp_pattern := [0, 1, 2]
	for index in 0 .. grid2_row_count {
		app.records << GridRecord{
			id: index + 1
			v1: v1_values[index % v1_values.len]
			v2: v2_values[index % v2_values.len]
			sex: grid2_sex_levels[sex_pattern[index % sex_pattern.len]]
			worker: worker_pattern[index % worker_pattern.len]
			csp: grid2_csp_levels[csp_pattern[index % csp_pattern.len]]
		}
	}
	app.load_selection()
	app.rebuild()
	return app
}

fn (app &Grid2Demo) record_index(id int) int {
	for index, record in app.records {
		if record.id == id {
			return index
		}
	}
	return -1
}

// sort_value keeps every column comparable as text: the factor and boolean
// columns sort by their displayed level, the way the original data grid does.
fn (app &Grid2Demo) sort_value(record GridRecord) string {
	return match app.sort_key {
		'v1' { record.v1 }
		'v2' { record.v2 }
		'sex' { record.sex }
		'worker' {
			if record.worker { 'yes' } else { 'no' }
		}
		'csp' { record.csp }
		else { '${record.id:04}' }
	}
}

fn (mut app Grid2Demo) rebuild() {
	mut ordered := app.records.clone()
	ordered.sort_with_compare(fn [app] (a &GridRecord, b &GridRecord) int {
		left := app.sort_value(a)
		right := app.sort_value(b)
		mut order := if left < right {
			-1
		} else if left > right { 1 } else { 0 }
		if order == 0 {
			// Ties keep the original row order, so a sort never shuffles equals.
			order = if a.id < b.id {
				-1
			} else if a.id > b.id { 1 } else { 0 }
		}
		return if app.descending { -order } else { order }
	})
	mut rows := []GridRow{cap: ordered.len}
	for index, record in ordered {
		rows << GridRow{
			id: record.id
			key: 'row-${record.id}'
			number: '${index + 1}'
			v1: record.v1
			v2: record.v2
			sex: record.sex
			worker: if record.worker { 'yes' } else { 'no' }
			csp: record.csp
			selected: record.id == app.selected
			stripe: if index % 2 == 0 { '#FFFFFF' } else { '#F8FAFC' }
		}
	}
	app.rows = rows
	marker := if app.descending { ' ▼' } else { ' ▲' }
	for index, column in app.columns {
		app.columns[index].label = if column.key == app.sort_key {
			column.name + marker
		} else {
			column.name
		}
	}
	sorted_by := if app.sort_key == 'id' { 'row order' } else { app.sort_key + marker }
	app.status = '${app.rows.len} rows · sorted by ${sorted_by} · row ${app.selected} selected'
}

fn (mut app Grid2Demo) load_selection() {
	index := app.record_index(app.selected)
	if index < 0 {
		return
	}
	record := app.records[index]
	app.edit_v1 = record.v1
	app.edit_v2 = record.v2
	app.edit_sex = record.sex
	app.edit_csp = record.csp
	app.edit_worker = record.worker
}

pub fn (mut app Grid2Demo) sort_by(key string) {
	if app.sort_key == key {
		app.descending = !app.descending
	} else {
		app.sort_key = key
		app.descending = false
	}
	app.rebuild()
}

pub fn (mut app Grid2Demo) reset_sort() {
	app.sort_key = 'id'
	app.descending = false
	app.rebuild()
}

pub fn (mut app Grid2Demo) select_row(id int) {
	if app.record_index(id) < 0 {
		return
	}
	app.selected = id
	app.load_selection()
	app.rebuild()
}

pub fn (mut app Grid2Demo) apply_edits() {
	index := app.record_index(app.selected)
	if index < 0 {
		return
	}
	app.records[index].v1 = app.edit_v1
	app.records[index].v2 = app.edit_v2
	if app.edit_sex in grid2_sex_levels {
		app.records[index].sex = app.edit_sex
	}
	if app.edit_csp in grid2_csp_levels {
		app.records[index].csp = app.edit_csp
	}
	app.records[index].worker = app.edit_worker
	app.rebuild()
	app.status = 'Row ${app.selected} updated · ' + app.status
}

fn main() {
	ui2.run_qml[Grid2Demo](
		source: grid2_qml_source
		model: grid2_demo()
		title: 'Grid 2'
		width: grid2_width
		height: grid2_height
	) or { panic(err) }
}
