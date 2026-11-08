module main

import math
import ui2

// A gallery of the table components. Two simple tables show the styled Table:
// a header, rows, a footer and a caption, row hover, stripes, column dividers,
// custom cells and clickable rows. Below them a DataTable holds 5,000 people:
// click a header to sort, drag a header divider to resize, tick rows or click
// one to select it, and scroll both ways while the header follows. Only the rows
// in view are built. The keyboard moves the selection (arrows, Page Up/Down,
// Home/End, Space, Cmd/Ctrl+A, Escape).

struct Person {
	id       int
	name     string
	email    string
	role     string
	status   string
	amount   f64
	progress f64
	joined   string
	country  string
}

@[heap]
struct Gallery {
mut:
	dark           bool
	loading        bool
	empty          bool
	striped        bool              = true
	size           ui2.ComponentSize = .medium
	people         []Person
	order          []int // Display index to people index.
	position       []int // People index to display index.
	sort_column    int = -1
	sort_direction ui2.TableSortDirection
	selected       map[int]bool // By person id.
	active_id      int = -1
	widths         []f64
	drag           ui2.TableResizeDrag
	hovered        int = -1
	invoice_hover  int = -1
	team_hover     int = -1
	team_clicked   string
}

const gallery = &Gallery{}

const window_width = 1200
const window_height = 860
const people_count = 5000
const people_id = 'people'

const first_names = ['Ava', 'Liam', 'Mia', 'Noah', 'Zoe', 'Ethan', 'Isla', 'Lucas', 'Aria', 'Mateo',
	'Nora', 'Leo', 'Ivy', 'Hugo', 'Elena', 'Kai', 'Sofia', 'Omar', 'Yuki', 'Ines']
const last_names = ['Smith', 'Garcia', 'Chen', 'Weber', 'Rossi', 'Kowalski', 'Novak', 'Silva',
	'Tanaka', 'Haddad', 'Larsen', 'Dubois', 'Okafor', 'Petrov', 'Nguyen', 'Costa', 'Ivanova', 'Kim',
	'Moreau', 'Singh']
const roles = ['Owner', 'Admin', 'Editor', 'Viewer', 'Viewer', 'Editor']
const statuses = ['Active', 'Active', 'Active', 'Invited', 'Suspended']
const countries = ['Australia', 'Brazil', 'Canada', 'France', 'Germany', 'India', 'Japan', 'Kenya',
	'Mexico', 'Norway', 'Spain', 'Vietnam']

// The data table's columns at their starting widths; the gallery keeps the
// widths the user drags them to.
fn people_columns() []ui2.TableColumn {
	return [
		ui2.TableColumn{
			key:       'id'
			title:     'ID'
			width:     72
			min_width: 56
			align:     .right
			sortable:  true
		},
		ui2.TableColumn{
			key:      'name'
			title:    'Name'
			width:    180
			sortable: true
		},
		ui2.TableColumn{
			key:   'email'
			title: 'Email'
			width: 250
		},
		ui2.TableColumn{
			key:      'role'
			title:    'Role'
			width:    100
			sortable: true
		},
		ui2.TableColumn{
			key:       'status'
			title:     'Status'
			width:     112
			min_width: 96
			sortable:  true
		},
		ui2.TableColumn{
			key:      'amount'
			title:    'Amount'
			width:    120
			align:    .right
			sortable: true
		},
		ui2.TableColumn{
			key:      'progress'
			title:    'Progress'
			width:    150
			sortable: true
		},
		ui2.TableColumn{
			key:      'joined'
			title:    'Joined'
			width:    110
			sortable: true
		},
		ui2.TableColumn{
			key:      'country'
			title:    'Country'
			width:    130
			sortable: true
		},
	]
}

fn make_people() []Person {
	mut people := []Person{cap: people_count}
	mut seed := u32(20261017)
	for i in 0 .. people_count {
		seed = seed * 1664525 + 1013904223
		a := int(seed >> 8)
		first := first_names[a % first_names.len]
		last := last_names[(a / 20) % last_names.len]
		people << Person{
			id:       i + 1
			name:     '${first} ${last}'
			email:    '${first.to_lower()}.${last.to_lower()}${i + 1}@example.com'
			role:     roles[(a / 400) % roles.len]
			status:   statuses[(a / 2400) % statuses.len]
			amount:   f64((a / 7) % 500000) / 100
			progress: f64((a / 13) % 101)
			joined:   '20${19 + (a / 31) % 7}-${pad2(1 + (a / 17) % 12)}-${pad2(1 + (a / 23) % 28)}'
			country:  countries[(a / 29) % countries.len]
		}
	}
	return people
}

fn pad2(value int) string {
	return if value < 10 { '0${value}' } else { value.str() }
}

// money formats 1234.5 as $1,234.50.
fn money(value f64) string {
	cents := i64(math.round(value * 100))
	whole := cents / 100
	mut digits := whole.str()
	mut grouped := ''
	for digits.len > 3 {
		grouped = ',' + digits[digits.len - 3..] + grouped
		digits = digits[..digits.len - 3]
	}
	return '$' + digits + grouped + '.' + pad2(int(cents % 100))
}

fn count_text(value int) string {
	return if value >= 1000 { '${value / 1000},${value % 1000:03}' } else { value.str() }
}

fn init_gallery() {
	mut state := unsafe { gallery }
	state.people = make_people()
	state.widths = people_columns().map(it.width)
	resort(mut state)
}

// resort recomputes the display order with the stable sort helpers.
fn resort(mut state Gallery) {
	direction := if state.sort_column < 0 {
		ui2.TableSortDirection.none
	} else {
		state.sort_direction
	}
	people := state.people
	state.order = match state.sort_column {
		0 { ui2.table_sort_order_numbers(people.map(f64(it.id)), direction) }
		1 { ui2.table_sort_order_text(people.map(it.name), direction) }
		3 { ui2.table_sort_order_text(people.map(it.role), direction) }
		4 { ui2.table_sort_order_text(people.map(it.status), direction) }
		5 { ui2.table_sort_order_numbers(people.map(it.amount), direction) }
		6 { ui2.table_sort_order_numbers(people.map(it.progress), direction) }
		7 { ui2.table_sort_order_text(people.map(it.joined), direction) }
		8 { ui2.table_sort_order_text(people.map(it.country), direction) }
		else { ui2.table_sort_order_text([]string{len: people.len}, .none) }
	}
	state.position = []int{len: people.len}
	for display, index in state.order {
		state.position[index] = display
	}
}

fn mix(a u32, b u32, t f64) u32 {
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := f64((a >> shift) & 0xff)
		to := f64((b >> shift) & 0xff)
		out |= u32(math.round(from + (to - from) * t)) << shift
	}
	return out
}

// pill is a status badge drawn into a cell's content box.
fn pill(text string, tone ui2.ComponentTone, box_height f64, size f64, theme ui2.ComponentTheme) ui2.Element {
	tone_color, _ := theme.colors(tone)
	color := if tone == .neutral { theme.muted_foreground } else { tone_color }
	height := math.min(box_height - 8, size + 8)
	width := f64(text.len) * size * 0.62 + 16
	return ui2.view('', ui2.rect(0, (box_height - height) / 2, width, height), ui2.BoxStyle{
		bg:     mix(theme.background, color, if theme.background == 0xffffff { 0.14 } else { 0.28 })
		radius: height / 2
	}, [
		ui2.label('', text, ui2.rect(0, 0, width, height), ui2.TextStyle{
			color: if theme.background == 0xffffff {
				mix(color, theme.foreground, 0.35)
			} else {
				color
			}
			size:  size - 1
			align: .center
		}),
	])
}

fn status_tone(status string) ui2.ComponentTone {
	return match status {
		'Active', 'Paid' { .success }
		'Invited', 'Pending' { .warning }
		'Suspended', 'Unpaid' { .danger }
		else { .neutral }
	}
}

// progress_bar is a thin bar and a percentage, drawn into a cell's content box.
fn progress_bar(value f64, width f64, box_height f64, size f64, theme ui2.ComponentTheme) ui2.Element {
	track := math.max(0.0, width - 40)
	y := (box_height - 6) / 2
	return ui2.view('', ui2.rect(0, 0, width, box_height), ui2.BoxStyle{ transparent: true }, [
		ui2.view('', ui2.rect(0, y, track, 6), ui2.BoxStyle{
			bg:     theme.muted
			radius: 3
		}, [
			ui2.view('', ui2.rect(0, 0, track * value / 100, 6), ui2.BoxStyle{
				bg:     theme.primary
				radius: 3
			}, []ui2.Element{}),
		]),
		ui2.label('', '${int(value)}%', ui2.rect(track, 0, 40, box_height), ui2.TextStyle{
			color: theme.muted_foreground
			size:  size - 1
			align: .right
		}),
	])
}

// person_row builds the row shown at a display index. The data table calls it
// only for the rows in view.
fn person_row(index int) ui2.TableRow {
	state := unsafe { gallery }
	person := state.people[state.order[index]]
	theme := ui2.component_theme(state.dark)
	metrics := ui2.table_metrics(state.size)
	box_height := metrics.row_height
	progress_width := state.widths[6] - 2 * metrics.padding
	return ui2.TableRow{
		key:      person.id.str()
		selected: person.id in state.selected
		enabled:  person.status != 'Suspended' || person.id % 7 != 0
		cells:    [
			ui2.TableCell{
				text:  person.id.str()
				color: theme.muted_foreground
			},
			ui2.TableCell{
				text: person.name
			},
			ui2.TableCell{
				text: person.email
			},
			ui2.TableCell{
				text: person.role
				bold: person.role == 'Owner'
			},
			ui2.TableCell{
				text:    person.status
				content: [pill(person.status, status_tone(person.status), box_height, metrics.font_size,
					theme)]
			},
			ui2.TableCell{
				text: money(person.amount)
			},
			ui2.TableCell{
				content: [progress_bar(person.progress, progress_width, box_height, metrics.font_size,
					theme)]
			},
			ui2.TableCell{
				text: person.joined
			},
			ui2.TableCell{
				text: person.country
			},
		]
	}
}

fn people_config(state &Gallery) ui2.DataTableConfig {
	body := ui2.data_table_body_id(people_id)
	base := people_columns()
	mut columns := []ui2.TableColumn{cap: base.len}
	for i, column in base {
		columns << ui2.TableColumn{
			...column
			width: state.widths[i]
		}
	}
	count := if state.empty { 0 } else { state.people.len }
	mut total := 0.0
	mut progress := 0.0
	for person in state.people {
		total += person.amount
		progress += person.progress
	}
	range := ui2.data_table_layout(ui2.DataTableConfig{
		frame:     people_frame()
		columns:   columns
		row_count: count
		selection: .multiple
		scroll_y:  ui2.scroll_offset(body)
		size:      state.size
		overscan:  0
	}).rows
	sorted := if state.sort_column >= 0 && state.sort_direction != .none {
		' · sorted by ${base[state.sort_column].title.to_lower()}, ${state.sort_direction}'
	} else {
		''
	}
	return ui2.DataTableConfig{
		id:             people_id
		frame:          people_frame()
		columns:        columns
		row_count:      count
		row:            person_row
		footer:         if state.empty {
			[]ui2.TableRow{}
		} else {
			[
				ui2.TableRow{
					cells: [ui2.TableCell{}, ui2.TableCell{
						text: '${count_text(count)} people'
						bold: true
					}, ui2.TableCell{}, ui2.TableCell{}, ui2.TableCell{}, ui2.TableCell{
						text: '$${total / 1e6:.2f}M'
						bold: true
					}, ui2.TableCell{
						text: 'average ${int(progress / f64(state.people.len))}%'
					}]
				},
			]
		}
		caption:        if state.loading {
			'Loading…'
		} else if count == 0 {
			'Nothing to show'
		} else {
			'Rows ${count_text(range.start + 1)}–${count_text(range.end)} of ${count_text(count)} on screen · ${count_text(state.selected.len)} selected${sorted}'
		}
		scroll_x:       ui2.scroll_horizontal_offset(body)
		scroll_y:       ui2.scroll_offset(body)
		sort_column:    state.sort_column
		sort_direction: state.sort_direction
		selection:      .multiple
		selected_count: if state.empty { 0 } else { state.selected.len }
		active_row:     if state.active_id > 0 { state.position[state.active_id - 1] } else { -1 }
		resize_drag:    state.drag
		hovered_row:    state.hovered
		loading:        state.loading
		striped:        state.striped
		empty_text:     'No people match'
		size:           state.size
		theme:          ui2.component_theme(state.dark)
	}
}

fn people_frame() ui2.Rect {
	return ui2.rect(24, 396, window_width - 48, 440)
}

// sized gives a simple table the height its rows, footer and caption take.
fn sized(config ui2.TableConfig) ui2.TableConfig {
	return ui2.TableConfig{
		...config
		frame: ui2.rect(config.frame.x, config.frame.y, config.frame.width, ui2.table_height(config))
	}
}

fn invoices_config(state &Gallery) ui2.TableConfig {
	return sized(ui2.TableConfig{
		id:          'invoices'
		frame:       ui2.rect(24, 92, 560, 0)
		columns:     [
			ui2.TableColumn{
				title: 'Invoice'
				width: 100
			},
			ui2.TableColumn{
				title: 'Status'
			},
			ui2.TableColumn{
				title: 'Method'
			},
			ui2.TableColumn{
				title: 'Amount'
				width: 110
				align: .right
			},
		]
		rows:        if state.empty {
			[]ui2.TableRow{}
		} else {
			[
				ui2.table_text_row(['INV001', 'Paid', 'Credit card', '$250.00']),
				ui2.table_text_row(['INV002', 'Pending', 'PayPal', '$150.00']),
				ui2.table_text_row(['INV003', 'Unpaid', 'Bank transfer', '$350.00']),
				ui2.table_text_row(['INV004', 'Paid', 'Credit card', '$450.00']),
				ui2.table_text_row(['INV005', 'Paid', 'PayPal', '$550.00']),
			]
		}
		footer:      [
			ui2.TableRow{
				cells: [ui2.TableCell{
					text: 'Total'
					bold: true
				}, ui2.TableCell{}, ui2.TableCell{}, ui2.TableCell{
					text: if state.empty { '$0.00' } else { '$1,750.00' }
					bold: true
				}]
			},
		]
		caption:     'A list of your recent invoices.'
		hoverable:   true
		hovered_row: state.invoice_hover
		empty_text:  'No invoices yet'
		theme:       ui2.component_theme(state.dark)
	})
}

struct Member {
	name      string
	role      string
	email     string
	last_seen string
}

const members = [
	Member{'Olivia Martin', 'Owner', 'olivia@example.com', 'now'},
	Member{'Jackson Lee', 'Admin', 'jackson@example.com', '5 min ago'},
	Member{'Isabella Nguyen', 'Editor', 'isabella@example.com', '2 h ago'},
	Member{'William Kim', 'Viewer', 'will@example.com', 'yesterday'},
	Member{'Sofia Davis', 'Editor', 'sofia@example.com', '3 days ago'},
]

fn team_config(state &Gallery) ui2.TableConfig {
	theme := ui2.component_theme(state.dark)
	metrics := ui2.table_metrics(.small)
	mut rows := []ui2.TableRow{}
	for member in members {
		avatar := ui2.avatar(
			frame: ui2.rect(0, (metrics.row_height - 26) / 2, 26, 26)
			name:  member.name
			theme: theme
		) or { panic(err) }
		rows << ui2.TableRow{
			key:   member.email
			cells: [
				ui2.TableCell{
					text:    member.name
					content: [avatar, ui2.label('', member.name, ui2.rect(34, 0, 150, metrics.row_height),
						ui2.TextStyle{
							color: theme.foreground
							size:  metrics.font_size
						})]
				},
				ui2.TableCell{
					text:    member.role
					content: [pill(member.role, if member.role == 'Owner' {
						ui2.ComponentTone.primary
					} else {
						ui2.ComponentTone.neutral
					}, metrics.row_height, metrics.font_size, theme)]
				},
				ui2.TableCell{
					text: member.email
				},
				ui2.TableCell{
					text:  member.last_seen
					color: theme.muted_foreground
				},
			]
		}
	}
	return sized(ui2.TableConfig{
		id:              'team'
		frame:           ui2.rect(616, 92, 560, 0)
		columns:         [
			ui2.TableColumn{
				title: 'Member'
				flex:  2
			},
			ui2.TableColumn{
				title: 'Role'
				width: 90
			},
			ui2.TableColumn{
				title: 'Email'
				flex:  2
			},
			ui2.TableColumn{
				title: 'Last seen'
				width: 96
				align: .right
			},
		]
		rows:            rows
		caption:         if state.team_clicked.len > 0 {
			'Clicked ${state.team_clicked}'
		} else {
			'Rows are buttons here: click one.'
		}
		striped:         true
		column_dividers: true
		hoverable:       true
		hovered_row:     state.team_hover
		clickable_rows:  true
		size:            .small
		theme:           theme
	})
}

fn section_title(text string, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, 560, 24), ui2.TextStyle{
		color: theme.foreground
		size:  16
		bold:  true
	})
}

fn note(text string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn toolbar_button(id string, text string, x f64, width f64, theme ui2.ComponentTheme, active bool) ui2.Element {
	return ui2.button(id, text, ui2.rect(x, 18, width, 28), ui2.BoxStyle{
		bg:     if active { theme.primary } else { theme.muted }
		radius: 6
	}, ui2.TextStyle{
		color: if active { theme.primary_foreground } else { theme.foreground }
		size:  13
		align: .center
	})
}

fn build() ui2.Element {
	state := unsafe { gallery }
	theme := ui2.component_theme(state.dark)
	size_name := match state.size {
		.small { 'Small' }
		.medium { 'Medium' }
		.large { 'Large' }
	}
	mut children := [
		ui2.label('', 'Table components', ui2.rect(24, 18, 300, 28), ui2.TextStyle{
			color: theme.foreground
			size:  20
			bold:  true
		}),
		toolbar_button('striped', 'Striped', 640, 80, theme, state.striped),
		toolbar_button('size', 'Size: ${size_name}', 726, 110, theme, false),
		toolbar_button('loading', 'Loading', 842, 80, theme, state.loading),
		toolbar_button('empty', 'Empty', 928, 80, theme, state.empty),
		toolbar_button('theme', 'Dark theme', 1014, 100, theme, state.dark),
		section_title('Table', 24, 60, theme),
		note('Header, footer, caption and row hover', ui2.rect(80, 64, 400, 18), theme),
		section_title('Small, striped, dividers, custom cells', 616, 60, theme),
		ui2.table(invoices_config(state)) or { panic(err) },
		ui2.table(team_config(state)) or { panic(err) },
		section_title('Data table: ${count_text(state.people.len)} rows', 24, 366, theme),
		note('Sort: click a header · resize: drag a divider · keys: arrows, Page Up/Down, Home/End, Space, Cmd+A, Esc',
			ui2.rect(260, 370, 916, 18), theme),
		ui2.data_table(people_config(state)) or { panic(err) },
	]
	return ui2.screen(theme.background, children)
}

fn apply_people(mut state Gallery, event ui2.DataTableEvent) {
	match event.kind {
		.sort {
			state.sort_column = if event.direction == .none { -1 } else { event.column }
			state.sort_direction = event.direction
			resort(mut state)
		}
		.select_row {
			id := state.people[state.order[event.row]].id
			state.selected = {
				id: true
			}
			state.active_id = id
		}
		.toggle_row {
			id := state.people[state.order[event.row]].id
			if event.checked {
				state.selected[id] = true
			} else {
				state.selected.delete(id)
			}
			state.active_id = id
		}
		.select_all {
			state.selected = map[int]bool{}
			if event.checked {
				for person in state.people {
					state.selected[person.id] = true
				}
			}
		}
		.clear_selection {
			state.selected = map[int]bool{}
		}
		.hover_row {
			state.hovered = event.row
		}
		.resize_start {
			state.drag = event.drag
		}
		.resize {
			state.widths = event.widths
		}
		.resize_end {
			state.widths = event.widths
			state.drag = ui2.TableResizeDrag{}
		}
	}
}

fn on_event(event string) {
	mut state := unsafe { gallery }
	match event {
		'theme' {
			state.dark = !state.dark
		}
		'loading' {
			state.loading = !state.loading
		}
		'empty' {
			state.empty = !state.empty
			state.hovered = -1
			state.invoice_hover = -1
		}
		'striped' {
			state.striped = !state.striped
		}
		'size' {
			state.size = match state.size {
				.small { .medium }
				.medium { .large }
				.large { .small }
			}
		}
		else {
			if e := ui2.data_table_event(people_config(state), event) {
				apply_people(mut state, e)
			} else if e := ui2.table_event(invoices_config(state), event) {
				state.invoice_hover = e.row
			} else if e := ui2.table_event(team_config(state), event) {
				if e.kind == .hover_row {
					state.team_hover = e.row
				} else {
					state.team_clicked = members[e.row].name
				}
			} else {
				return
			}
		}
	}
	ui2.refresh()
}

fn on_key_event(event ui2.KeyEvent) {
	mut state := unsafe { gallery }
	config := people_config(state)
	e := ui2.data_table_event_from_key(config, event) or { return }
	ui2.consume_key()
	apply_people(mut state, e)
	if e.kind in [.select_row, .toggle_row] {
		if offset := ui2.data_table_scroll_to_row(config, e.row) {
			ui2.scroll_to_offset(ui2.data_table_body_id(people_id), offset)
		}
	}
	ui2.refresh()
}

fn on_scroll(id string) {
	// The rows built follow the body's offset, so a scroll rebuilds. A scroll can
	// be reported while a build is being put on screen, so ask for the rebuild
	// rather than running it here. (The custom renderer rebuilds every frame.)
	if id == ui2.data_table_body_id(people_id) {
		ui2.request_refresh()
	}
}

fn main() {
	init_gallery()
	ui2.on_key_event(on_key_event)
	ui2.on_scroll(on_scroll)
	ui2.run_window('UI2 Table Components', window_width, window_height, build, on_event)
}
