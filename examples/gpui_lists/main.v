module main

import ui2

// A gallery of the list components: a sectioned list with multiple selection,
// a virtual list of 10,000 rows that builds only the ones in view, and
// searchable lists. The application owns every state. Events go to each
// component's decoder, keys to its key helper, and scroll positions come from
// on_scroll.

const people_count = 10_000
const people_header_every = 100
const people_overscan = 4

const first_names = ['Ada', 'Alan', 'Grace', 'Linus', 'Margaret', 'Dennis', 'Barbara', 'Ken', 'Frances',
	'Edsger', 'Radia', 'Niklaus', 'Hedy', 'Donald', 'Katherine', 'Tim']
const last_names = ['Lovelace', 'Turing', 'Hopper', 'Torvalds', 'Hamilton', 'Ritchie', 'Liskov',
	'Thompson', 'Allen', 'Dijkstra', 'Perlman', 'Wirth', 'Lamarr', 'Knuth', 'Johnson', 'Berners-Lee',
	'Kay', 'Backus', 'Hoare', 'McCarthy']
const teams = ['Compiler', 'Runtime', 'Graphics', 'Networking', 'Docs', 'Tooling']

enum ClickMode {
	plain
	toggle
	extend
}

@[heap]
struct Gallery {
mut:
	dark   bool
	status string = 'Click, hover and use the arrow keys; Shift extends, Space toggles, Cmd/Ctrl+A selects all.'
	focus  string = 'files'
	// The document list starts with two rows selected and one hovered.
	click_mode   ClickMode
	files        ui2.ListState = ui2.ListState{
		selected: ['readme', 'roadmap']
		active:   'roadmap'
		anchor:   'readme'
		hovered:  'budget'
	}
	files_offset f64
	// The virtual list starts scrolled to row 5,000.
	people_layout ui2.VirtualListLayout
	people_offset f64
	people_built  ui2.VirtualListRange
	people_active int = 5003
	people_hover  int = -1
	// The searchable list starts filtered.
	pantry        ui2.ListState
	pantry_query  string            = 'an'
	pantry_mode   ui2.ListMatchMode = .substring
	pantry_offset f64
	// The second searchable list shows its empty results.
	travel       ui2.ListState
	travel_query string = 'durian'
	// Work for after the rebuild.
	sync_id     string
	sync_text   string
	focus_id    string
	scroll_id   string
	scroll_to   f64
	scroll_wait bool
}

const gallery_state = &Gallery{}

fn gallery() &Gallery {
	return unsafe { gallery_state }
}

// ── Layout ──────────────────────────────────────────────────────────

struct Layout {
	width  f64
	height f64
	column f64
	x1     f64
	x2     f64
	x3     f64
}

const top = 196.0
const main_height = 340.0
const small_top = 576.0

fn layout() Layout {
	win := ui2.bounds()
	column := (win.width - 96) / 3
	return Layout{
		width:  win.width
		height: win.height
		column: column
		x1:     24
		x2:     48 + column
		x3:     72 + column * 2
	}
}

fn files_frame(l Layout) ui2.Rect {
	return ui2.rect(l.x1, top, l.column, main_height)
}

fn people_frame(l Layout) ui2.Rect {
	return ui2.rect(l.x2, top, l.column, l.height - top - 24)
}

fn pantry_frame(l Layout) ui2.Rect {
	return ui2.rect(l.x3, top, l.column, main_height)
}

fn travel_frame(l Layout) ui2.Rect {
	return ui2.rect(l.x3, small_top, l.column, l.height - small_top - 24)
}

fn small_frame(l Layout, index int) ui2.Rect {
	width := (l.column - 16) / 2
	return ui2.rect(l.x1 + f64(index) * (width + 16), small_top, width, l.height - small_top - 24)
}

// ── Data ────────────────────────────────────────────────────────────

fn file_sections() []ui2.ListSection {
	trash := ui2.ListItemAction{
		id:    'delete'
		icon:  'trash'
		label: 'Delete'
	}
	share := ui2.ListItemAction{
		id:    'share'
		icon:  'square.and.arrow.up'
		label: 'Share'
	}
	return [
		ui2.ListSection{
			title: 'Pinned'
			icon:  'star'
			items: [
				ui2.ListItem{
					id:          'readme'
					title:       'README.md'
					description: 'Edited 2 hours ago'
					icon:        'doc.text.fill'
					trailing:    '4 KB'
					actions:     [share]
				},
				ui2.ListItem{
					id:          'roadmap'
					title:       'Roadmap 2027'
					description: 'Shared with the team'
					icon:        'map'
					badge:       'New'
					badge_tone:  .primary
					actions:     [share]
				},
			]
		},
		ui2.ListSection{
			title:  'Documents'
			icon:   'folder'
			footer: '1 file is locked'
			items:  [
				ui2.ListItem{
					id:       'budget'
					title:    'Budget.numbers'
					icon:     'chart.bar'
					trailing: '120 KB'
					actions:  [trash]
				},
				ui2.ListItem{
					id:       'notes'
					title:    'Meeting notes'
					icon:     'doc'
					trailing: 'Yesterday'
					actions:  [trash]
				},
				ui2.list_separator(),
				ui2.ListItem{
					id:       'contract'
					title:    'Contract.pdf'
					icon:     'lock.doc'
					trailing: 'Locked'
					enabled:  false
				},
			]
		},
		ui2.ListSection{
			title: 'People'
			icon:  'person.2'
			items: [
				ui2.ListItem{
					id:          'ada'
					title:       'Ada Lovelace'
					description: 'ada@example.com'
					avatar:      'Ada Lovelace'
					badge:       '3'
				},
				ui2.ListItem{
					id:          'grace'
					title:       'Grace Hopper'
					description: 'grace@example.com'
					avatar:      'Grace Hopper'
				},
			]
		},
		// No rows, so neither its header nor its footer is drawn.
		ui2.ListSection{
			title:  'Archived'
			footer: 'Nothing archived'
		},
	]
}

fn files_config(app &Gallery, theme ui2.ComponentTheme) ui2.ListConfig {
	return ui2.ListConfig{
		id:                  'files'
		frame:               files_frame(layout())
		sections:            file_sections()
		state:               app.files
		selection:           .multiple
		offset:              app.files_offset
		accessibility_label: 'Files'
		theme:               theme
	}
}

fn pantry_sections() []ui2.ListSection {
	return [
		ui2.ListSection{
			title: 'Fruits'
			items: [
				pantry_item('apple', 'Apple', '52 kcal'),
				pantry_item('banana', 'Banana', '89 kcal'),
				pantry_item('orange', 'Orange', '47 kcal'),
				pantry_item('mango', 'Mango', '60 kcal'),
				pantry_item('grape', 'Grape', '69 kcal'),
			]
		},
		ui2.ListSection{
			title: 'Vegetables'
			items: [
				pantry_item('carrot', 'Carrot', '41 kcal'),
				pantry_item('spinach', 'Spinach', '23 kcal'),
				pantry_item('eggplant', 'Eggplant', '25 kcal'),
			]
		},
		ui2.ListSection{
			title: 'Nuts'
			items: [
				pantry_item('almond', 'Almond', '579 kcal'),
				pantry_item('pecan', 'Pecan', '691 kcal'),
			]
		},
	]
}

fn pantry_item(id string, title string, energy string) ui2.ListItem {
	return ui2.ListItem{
		id:       id
		title:    title
		trailing: energy
	}
}

fn pantry_config(app &Gallery, theme ui2.ComponentTheme) ui2.SearchableListConfig {
	return ui2.SearchableListConfig{
		id:                  'pantry'
		frame:               pantry_frame(layout())
		query:               app.pantry_query
		placeholder:         'Search the pantry…'
		sections:            pantry_sections()
		state:               app.pantry
		match_mode:          app.pantry_mode
		offset:              app.pantry_offset
		accessibility_label: 'Pantry'
		theme:               theme
	}
}

fn travel_config(app &Gallery, theme ui2.ComponentTheme) ui2.SearchableListConfig {
	return ui2.SearchableListConfig{
		id:                  'travel'
		frame:               travel_frame(layout())
		query:               app.travel_query
		placeholder:         'Search destinations…'
		items:               [
			ui2.ListItem{
				id:    'lisbon'
				title: 'Lisbon'
				icon:  'location'
			},
			ui2.ListItem{
				id:    'kyoto'
				title: 'Kyoto'
				icon:  'location'
			},
			ui2.ListItem{
				id:    'quito'
				title: 'Quito'
				icon:  'location'
			},
		]
		state:               app.travel
		match_mode:          .fuzzy
		accessibility_label: 'Destinations'
		theme:               theme
	}
}

fn person_name(index int) string {
	return '${first_names[index % first_names.len]} ${last_names[(index / first_names.len) % last_names.len]}'
}

fn person_is_header(index int) bool {
	return index % people_header_every == 0
}

fn person_item(index int) ui2.ListItem {
	name := person_name(index)
	return ui2.ListItem{
		id:          'p${index}'
		title:       name
		description: if index % 3 == 0 { '${teams[index % teams.len]} team' } else { '' }
		avatar:      name
		trailing:    '#${group_digits(index)}'
	}
}

// people_sizes gives every hundredth row a short group header and the rows
// with a description more room, so the list's rows are not all one height.
fn people_sizes() []f64 {
	mut sizes := []f64{cap: people_count}
	for index in 0 .. people_count {
		sizes << if person_is_header(index) {
			28.0
		} else {
			ui2.list_row_height(person_item(index), .medium)
		}
	}
	return sizes
}

fn group_digits(value int) string {
	digits := value.str()
	mut out := ''
	for index, ch in digits {
		if index > 0 && (digits.len - index) % 3 == 0 {
			out += ','
		}
		out += ch.ascii_str()
	}
	return out
}

fn person_row(app &Gallery, theme ui2.ComponentTheme, index int, frame ui2.Rect) ui2.Element {
	if person_is_header(index) {
		last := if index + people_header_every - 1 < people_count {
			index + people_header_every - 1
		} else {
			people_count - 1
		}
		return ui2.view('', frame, ui2.BoxStyle{ bg: theme.muted }, [
			ui2.label('', 'Rows ${group_digits(index)} – ${group_digits(last)}', ui2.rect(12,
				0, frame.width - 24, frame.height), ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
				bold:  true
			}),
		])
	}
	row := ui2.list_row(
		list_id:  'people'
		item:     person_item(index)
		frame:    ui2.rect(frame.x + 4, frame.y, frame.width - 8, frame.height)
		selected: index == app.people_active
		hovered:  index == app.people_hover
		theme:    theme
	) or { panic(err) }
	return row
}

fn people_viewport() f64 {
	return people_frame(layout()).height
}

fn people_range(app &Gallery) ui2.VirtualListRange {
	return app.people_layout.range(people_viewport(), app.people_offset, people_overscan)
}

// ── Building ────────────────────────────────────────────────────────

fn text_style(theme ui2.ComponentTheme, size f64, bold bool, muted bool) ui2.TextStyle {
	return ui2.TextStyle{
		color: if muted { theme.muted_foreground } else { theme.foreground }
		size:  size
		bold:  bold
	}
}

fn note(theme ui2.ComponentTheme, text string, frame ui2.Rect) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color:  theme.muted_foreground
		size:   13
		lines:  2
		valign: .top
	})
}

fn heading(theme ui2.ComponentTheme, text string, x f64, y f64, width f64) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, width, 24), text_style(theme, 17, true, false))
}

fn click_modes(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:                  'click-mode'
		frame:               ui2.rect(l.x1, 152, l.column, 32)
		items:               [
			ui2.ButtonGroupItem{
				value:    'plain'
				label:    'Click'
				selected: app.click_mode == .plain
			},
			ui2.ButtonGroupItem{
				value:    'toggle'
				label:    'Toggle'
				selected: app.click_mode == .toggle
			},
			ui2.ButtonGroupItem{
				value:    'extend'
				label:    'Range'
				selected: app.click_mode == .extend
			},
		]
		outline:             true
		size:                .small
		accessibility_label: 'Click selects'
		theme:               theme
	}
}

fn match_modes(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:                  'match-mode'
		frame:               ui2.rect(l.x3, 152, l.column, 32)
		items:               [
			ui2.ButtonGroupItem{
				value:    'substring'
				label:    'Substring'
				selected: app.pantry_mode == .substring
			},
			ui2.ButtonGroupItem{
				value:    'fuzzy'
				label:    'Fuzzy'
				selected: app.pantry_mode == .fuzzy
			},
		]
		outline:             true
		size:                .small
		accessibility_label: 'Matching'
		theme:               theme
	}
}

fn jump_button(id string, caption string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.styled_button(
		id:      id
		label:   caption
		frame:   frame
		variant: .secondary
		outline: true
		size:    .small
		theme:   theme
	) or { panic(err) }
}

fn build() ui2.Element {
	mut app := gallery()
	theme := ui2.component_theme(app.dark)
	l := layout()
	people := people_range(app)
	app.people_built = people
	mut children := [
		ui2.label('', 'Lists, virtual lists and searchable lists', ui2.rect(24, 16, 560, 30),
			text_style(theme, 22, true, false)),
		ui2.link(
			id:    'theme'
			text:  'Light / dark'
			frame: ui2.rect(l.width - 124, 18, 100, 28)
			theme: theme
		) or { panic(err) },
		ui2.label('', app.status, ui2.rect(24, 52, l.width - 48, 20), text_style(theme, 13,
			false, true)),
	]

	// List.
	children << heading(theme, 'List', l.x1, 88, l.column)
	children << note(theme, 'Sections, icons, avatars, badges and row actions. Cmd-click toggles and Shift-click extends; a plain click does:',
		ui2.rect(l.x1, 112, l.column, 36))
	children << ui2.button_group(click_modes(app, theme, l)) or { panic(err) }
	children << ui2.list(files_config(app, theme)) or { panic(err) }
	children << heading(theme, 'Loading', l.x1, 552, 160)
	children << heading(theme, 'Empty', small_frame(l, 1).x, 552, 160)
	children << ui2.list(
		id:                  'loading'
		frame:               small_frame(l, 0)
		loading:             true
		accessibility_label: 'Inbox'
		theme:               theme
	) or { panic(err) }
	children << ui2.list(
		id:                  'empty'
		frame:               small_frame(l, 1)
		empty_title:         'No messages'
		empty_description:   'New messages show up here.'
		empty_icon:          'envelope'
		accessibility_label: 'Messages'
		theme:               theme
	) or { panic(err) }

	// Virtual list.
	children << heading(theme, 'Virtual list: ${group_digits(people_count)} rows', l.x2, 88,
		l.column)
	children << note(theme, 'Only the rows in view are built: ${people.len()} now, rows ${group_digits(people.visible_start)} to ${group_digits(people.visible_end - 1)}. Rows vary in height.',
		ui2.rect(l.x2, 112, l.column, 36))
	jump_width := (l.column - 16) / 3
	for index, jump in [['jump-top', 'Top'], ['jump-middle', 'Row 5,000'], ['jump-bottom', 'Bottom']] {
		children << jump_button(jump[0], jump[1], ui2.rect(l.x2 + f64(index) * (jump_width + 8),
			152, jump_width, 32), theme)
	}
	children << ui2.virtual_list(
		id:                  'people'
		frame:               people_frame(l)
		layout:              app.people_layout
		offset:              app.people_offset
		overscan:            people_overscan
		item:                fn [app, theme] (index int, frame ui2.Rect) ui2.Element {
			return person_row(app, theme, index, frame)
		}
		accessibility_label: 'People'
		theme:               theme
	) or { panic(err) }

	// Searchable lists.
	children << heading(theme, 'Searchable list', l.x3, 88, l.column)
	children << note(theme, 'Type to filter. Up and Down move the highlight while the field keeps focus; Return chooses.',
		ui2.rect(l.x3, 112, l.column, 36))
	children << ui2.button_group(match_modes(app, theme, l)) or { panic(err) }
	children << ui2.searchable_list(pantry_config(app, theme)) or { panic(err) }
	children << heading(theme, 'No results', l.x3, 552, l.column)
	children << ui2.searchable_list(travel_config(app, theme)) or { panic(err) }
	return ui2.screen(theme.background, children)
}

// ── Events ──────────────────────────────────────────────────────────

// modifiers are the keys held during the click, or what the click-mode switch
// makes a plain click do (for touch screens).
fn (app &Gallery) modifiers() ui2.ListModifiers {
	held := ui2.list_held_modifiers()
	return ui2.ListModifiers{
		toggle: held.toggle || app.click_mode == .toggle
		extend: held.extend || app.click_mode == .extend
	}
}

fn (mut app Gallery) files_step(step ui2.ListStep) {
	app.files = step.state
	app.focus = 'files'
	if step.action.len > 0 {
		app.status = '${step.action.capitalize()} “${step.item.title}”.'
	} else if step.confirmed {
		app.status = 'Opened “${step.item.title}”; ${app.files.selected.len} selected.'
	} else if step.cancelled {
		app.status = 'Cancelled.'
	} else if step.state.selected.len > 0 {
		app.status = 'Selected: ${step.state.selected.join(', ')}.'
	}
	if step.reveal {
		config := files_config(app, ui2.component_theme(app.dark))
		if offset := ui2.list_reveal_offset(config, step.state.active) {
			app.scroll_later(ui2.list_scroll_id('files'), offset)
		}
	}
}

fn (mut app Gallery) searchable_step(which string, step ui2.SearchableListStep) {
	theme := ui2.component_theme(app.dark)
	config := if which == 'pantry' {
		app.pantry_query = step.query
		app.pantry = step.state
		pantry_config(app, theme)
	} else {
		app.travel_query = step.query
		app.travel = step.state
		travel_config(app, theme)
	}
	app.focus = which
	if step.confirmed {
		app.status = 'Chose “${step.item.title}”.'
	} else if step.cancelled {
		app.status = 'Cancelled.'
	}
	if step.sync_field {
		app.sync_id = ui2.searchable_list_field_id(which)
		app.sync_text = step.query
		app.focus_id = app.sync_id
	}
	if step.reveal {
		list_config := ui2.searchable_list_list_config(config) or { return }
		if offset := ui2.list_reveal_offset(list_config, step.state.active) {
			app.scroll_later(ui2.searchable_list_scroll_id(which), offset)
		}
	}
}

fn (mut app Gallery) scroll_later(id string, offset f64) {
	app.scroll_id = id
	app.scroll_to = offset
}

fn (mut app Gallery) people_jump(index int, align ui2.VirtualListAlign) {
	offset := app.people_layout.scroll_offset_for(index, people_viewport(), app.people_offset,
		align)
	app.people_offset = offset
	app.scroll_later('people', offset)
}

fn person_index(id string) ?int {
	if !id.starts_with('p') {
		return none
	}
	index := id[1..].int()
	return if index >= 0 && index < people_count && !person_is_header(index) {
		index
	} else {
		none
	}
}

fn (mut app Gallery) handle_people(event string) bool {
	if pointer := ui2.parse_pointer_event(event) {
		press := ui2.list_press('people', pointer.action) or { return false }
		index := person_index(press.item_id) or { return false }
		if pointer.phase == 'enter' {
			app.people_hover = index
		} else if pointer.phase == 'leave' && app.people_hover == index {
			app.people_hover = -1
		} else {
			return false
		}
		return true
	}
	press := ui2.list_press('people', event) or { return false }
	index := person_index(press.item_id) or { return false }
	app.people_active = index
	app.focus = 'people'
	app.status = 'Selected ${person_name(index)}, row ${group_digits(index)}.'
	return true
}

// handle returns whether the event changed anything.
fn (mut app Gallery) handle(event string) bool {
	theme := ui2.component_theme(app.dark)
	if step := ui2.list_update(files_config(app, theme), event, app.modifiers()) {
		app.files_step(step)
		return true
	}
	if app.handle_people(event) {
		return true
	}
	pantry := pantry_config(app, theme)
	if step := ui2.searchable_list_update(pantry, event, ui2.text(ui2.searchable_list_field_id('pantry'))) {
		app.searchable_step('pantry', step)
		return true
	}
	travel := travel_config(app, theme)
	if step := ui2.searchable_list_update(travel, event, ui2.text(ui2.searchable_list_field_id('travel'))) {
		app.searchable_step('travel', step)
		return true
	}
	if value := ui2.button_group_value_from_action(click_modes(app, theme, layout()), event) {
		app.click_mode = match value {
			'toggle' { ClickMode.toggle }
			'extend' { ClickMode.extend }
			else { ClickMode.plain }
		}
		return true
	}
	if value := ui2.button_group_value_from_action(match_modes(app, theme, layout()), event) {
		app.pantry_mode = if value == 'fuzzy' { ui2.ListMatchMode.fuzzy } else { .substring }
		app.pantry = ui2.searchable_list_query_state(pantry_config(app, theme), app.pantry_query)
		return true
	}
	match event {
		'theme' {
			app.dark = !app.dark
		}
		'jump-top' {
			app.people_jump(0, .start)
		}
		'jump-middle' {
			app.people_jump(5000, .start)
		}
		'jump-bottom' {
			app.people_jump(people_count - 1, .end)
		}
		else {
			return false
		}
	}
	return true
}

// settle rebuilds, then does what has to wait for the new tree: putting a
// field's text back, moving focus and scrolling.
fn (mut app Gallery) settle() {
	ui2.refresh()
	if app.sync_id.len > 0 {
		if ui2.text(app.sync_id) != app.sync_text {
			ui2.set_text(app.sync_id, app.sync_text)
		}
		app.sync_id = ''
	}
	if app.focus_id.len > 0 {
		ui2.focus(app.focus_id)
		app.focus_id = ''
	}
	if app.scroll_id.len > 0 {
		ui2.scroll_to_offset(app.scroll_id, app.scroll_to)
		app.scroll_id = ''
	}
}

fn on_event(event string) {
	mut app := gallery()
	if app.handle(event) {
		app.settle()
	}
}

fn on_key(event ui2.KeyEvent) {
	mut app := gallery()
	theme := ui2.component_theme(app.dark)
	focused := ui2.focused_id()
	which := if focused == ui2.searchable_list_field_id('pantry') {
		'pantry'
	} else if focused == ui2.searchable_list_field_id('travel') {
		'travel'
	} else {
		app.focus
	}
	match which {
		'pantry', 'travel' {
			config := if which == 'pantry' {
				pantry_config(app, theme)
			} else {
				travel_config(app, theme)
			}
			step := ui2.searchable_list_key(config, event) or { return }
			app.searchable_step(which, step)
		}
		'people' {
			index := app.people_layout.index_after_key(app.people_active, people_viewport(),
				event) or { return }
			if person_is_header(index) {
				// Step over a group header in the direction of travel.
				next := if index > app.people_active || index == 0 { index + 1 } else { index - 1 }
				app.people_active = next
			} else {
				app.people_active = index
			}
			app.status = 'Selected ${person_name(app.people_active)}, row ${group_digits(app.people_active)}.'
			app.people_jump(app.people_active, .nearest)
		}
		else {
			step := ui2.list_key(files_config(app, theme), event) or { return }
			app.files_step(step)
		}
	}
	ui2.consume_key()
	app.settle()
}

// on_scroll keeps the stored offsets current and rebuilds the virtual list
// only when the rows it should show change. The rebuild is requested rather
// than run here, since a scroll can be reported while a rebuild is under way.
fn on_scroll(id string) {
	mut app := gallery()
	if id == 'people' {
		app.people_offset = ui2.scroll_offset(id)
		next := people_range(app)
		if next.start != app.people_built.start || next.end != app.people_built.end {
			ui2.request_refresh()
		}
	} else if id == ui2.list_scroll_id('files') {
		app.files_offset = ui2.scroll_offset(id)
	} else if id == ui2.searchable_list_scroll_id('pantry') {
		app.pantry_offset = ui2.scroll_offset(id)
	}
}

fn main() {
	mut app := gallery()
	app.people_layout = ui2.virtual_list_sized(people_sizes(), 0) or { panic(err) }
	app.pantry = ui2.searchable_list_query_state(pantry_config(app, ui2.component_theme(false)),
		app.pantry_query)
	app.pantry = ui2.ListState{
		...app.pantry
		selected: ['banana']
	}
	// Open the virtual list at row 5,000; the offset is taken up when the
	// scroll is first laid out.
	app.people_offset = app.people_layout.scroll_offset_for(5000, 800 - top - 24, 0, .start)
	ui2.scroll_to_offset('people', app.people_offset)
	ui2.on_key_event(on_key)
	ui2.on_scroll(on_scroll)
	ui2.run_window('GPUI Kit lists', 1200, 800, build, on_event)
}
