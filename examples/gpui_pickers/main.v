module main

import os
import ui2

// A gallery of the pickers: selects, comboboxes and the command palette. The
// application owns every value and every popup's state. Each component emits
// actions that its decoder turns into the next state; on_key_event adds the
// keyboard: arrows, Enter and Escape in the popups, and ⌘K (Ctrl+K) for the
// palette. Start it with UI2_PICKERS_PALETTE=1 to open the palette at once.

const window_width = 1120
const window_height = 800

// The state of one select: its popup and its selection.
@[heap]
struct SelectSlot {
mut:
	state    ui2.SelectState
	selected []string
}

@[heap]
struct Gallery {
mut:
	dark   bool
	status string = 'Click, type and use the arrow keys; every choice is reported here.'
	// Selects, by id. The language select starts open.
	selects map[string]&SelectSlot
	// The city combobox starts with "san" typed and its list open.
	city       string = 'san'
	city_value string
	city_state ui2.ComboboxState = ui2.ComboboxState{
		open:      true
		highlight: 'san-francisco'
	}
	// The package combobox loads its options after a delay, as a search
	// against a server would.
	package       string
	package_value string
	package_state ui2.ComboboxState
	packages      []ui2.PickerOption
	loading       bool
	request       u64
	// The inline command panel starts with a query, the modal palette closed.
	panel   ui2.CommandPaletteState = ui2.CommandPaletteState{
		query:     'se'
		highlight: 'search'
	}
	palette ui2.CommandPaletteState
	recent  []string = ['open', 'settings', 'new']
	sidebar bool     = true
	// Work that has to wait for the rebuilt tree: focusing a field and
	// scrolling a highlighted row into view. Only keys and searches scroll:
	// scrolling to a row the pointer highlighted would slide the next row
	// under the pointer and highlight that one in turn.
	focus_id  string
	reveal_id string
}

const gallery_state = &Gallery{
	selects: {
		'fruit':     &SelectSlot{}
		'theme':     &SelectSlot{
			selected: ['system']
		}
		'labels':    &SelectSlot{
			selected: ['bug', 'feature', 'docs', 'help']
		}
		'reviewers': &SelectSlot{
			selected: ['ada', 'grace']
		}
		'small':     &SelectSlot{
			selected: ['s']
		}
		'large':     &SelectSlot{
			selected: ['l']
		}
		'disabled':  &SelectSlot{
			selected: ['locked']
		}
		'language':  &SelectSlot{
			state:    ui2.SelectState{
				open:      true
				highlight: 'go'
			}
			selected: ['v']
		}
	}
}

fn gallery() &Gallery {
	return unsafe { gallery_state }
}

// ── Data ───────────────────────────────────────────────────────────

fn fruits() []ui2.PickerOption {
	mut options := []ui2.PickerOption{}
	for name in ['Apple', 'Apricot', 'Banana', 'Blueberry', 'Cherry', 'Grape', 'Mango', 'Orange',
		'Peach', 'Pear', 'Pineapple', 'Plum'] {
		options << ui2.picker_option(name.to_lower(), name)
	}
	return options
}

fn themes() []ui2.PickerOption {
	return [
		ui2.PickerOption{
			value: 'light'
			label: 'Light'
			icon:  'sun.max'
		},
		ui2.PickerOption{
			value: 'dark'
			label: 'Dark'
			icon:  'moon'
		},
		ui2.PickerOption{
			value: 'system'
			label: 'System'
			icon:  'gearshape'
		},
	]
}

fn labels() []ui2.PickerOption {
	return [
		ui2.picker_option('bug', 'bug'),
		ui2.picker_option('feature', 'feature'),
		ui2.picker_option('docs', 'documentation'),
		ui2.picker_option('question', 'question'),
		ui2.picker_option('help', 'help wanted'),
		ui2.picker_option('wontfix', 'wontfix'),
	]
}

fn people() []ui2.PickerOption {
	return [
		ui2.PickerOption{
			value:       'ada'
			label:       'Ada Lovelace'
			description: '@ada'
		},
		ui2.PickerOption{
			value:       'grace'
			label:       'Grace Hopper'
			description: '@grace'
		},
		ui2.PickerOption{
			value:       'ken'
			label:       'Ken Thompson'
			description: '@ken'
		},
		ui2.PickerOption{
			value:       'margaret'
			label:       'Margaret Hamilton'
			description: '@margaret'
		},
	]
}

fn size_options() []ui2.PickerOption {
	return [ui2.picker_option('s', 'Small'), ui2.picker_option('m', 'Medium'),
		ui2.picker_option('l', 'Large')]
}

fn languages() []ui2.PickerOption {
	return [
		ui2.PickerOption{
			value:       'v'
			label:       'V'
			description: 'Simple, fast, compiled'
			group:       'Compiled'
		},
		ui2.PickerOption{
			value:       'go'
			label:       'Go'
			description: 'Garbage collected, concurrent'
			group:       'Compiled'
		},
		ui2.PickerOption{
			value:       'rust'
			label:       'Rust'
			description: 'Ownership and borrowing'
			group:       'Compiled'
		},
		ui2.PickerOption{
			value:       'zig'
			label:       'Zig'
			description: 'Not installed on this machine'
			group:       'Compiled'
			enabled:     false
		},
		ui2.PickerOption{
			value:    'python'
			label:    'Python'
			group:    'Scripting'
			keywords: ['py']
		},
		ui2.PickerOption{
			value:    'javascript'
			label:    'JavaScript'
			group:    'Scripting'
			keywords: ['js', 'node']
		},
		ui2.PickerOption{
			value: 'lua'
			label: 'Lua'
			group: 'Scripting'
		},
	]
}

fn cities() []ui2.PickerOption {
	data := [
		['amsterdam', 'Amsterdam', 'Netherlands'],
		['barcelona', 'Barcelona', 'Spain'],
		['berlin', 'Berlin', 'Germany'],
		['lisbon', 'Lisbon', 'Portugal'],
		['london', 'London', 'United Kingdom'],
		['madrid', 'Madrid', 'Spain'],
		['paris', 'Paris', 'France'],
		['san-diego', 'San Diego', 'United States'],
		['san-francisco', 'San Francisco', 'United States'],
		['san-jose', 'San José', 'Costa Rica'],
		['santiago', 'Santiago', 'Chile'],
		['seattle', 'Seattle', 'United States'],
		['tokyo', 'Tokyo', 'Japan'],
		['toronto', 'Toronto', 'Canada'],
	]
	mut options := []ui2.PickerOption{}
	for row in data {
		options << ui2.PickerOption{
			value:       row[0]
			label:       row[1]
			description: row[2]
			icon:        'location'
		}
	}
	return options
}

// package_index stands in for a server the package search asks.
const package_index = ['gg', 'gx', 'json', 'math', 'net.http', 'net.websocket', 'os', 'regex',
	'sokol', 'strings', 'sync', 'term', 'time', 'toml', 'ui2', 'vweb', 'x.json2']

fn package_results(query string) []ui2.PickerOption {
	mut options := []ui2.PickerOption{}
	for name in package_index {
		if name.contains(query.to_lower()) {
			options << ui2.PickerOption{
				value: name
				label: name
				icon:  'cube.transparent'
			}
		}
	}
	return options
}

fn commands(app &Gallery) []ui2.CommandPaletteItem {
	return [
		ui2.CommandPaletteItem{
			id:       'calendar'
			label:    'Calendar'
			icon:     'calendar'
			group:    'Suggestions'
			keywords: ['date', 'schedule']
		},
		ui2.CommandPaletteItem{
			id:       'search'
			label:    'Search Emoji'
			icon:     'magnifyingglass'
			group:    'Suggestions'
			keywords: ['smiley']
		},
		ui2.CommandPaletteItem{
			id:      'calculator'
			label:   'Calculator'
			icon:    'function'
			group:   'Suggestions'
			enabled: false
		},
		ui2.CommandPaletteItem{
			id:       'new'
			label:    'New File'
			icon:     'doc.badge.plus'
			shortcut: 'cmd+n'
			group:    'Files'
		},
		ui2.CommandPaletteItem{
			id:       'open'
			label:    'Open File…'
			icon:     'folder'
			shortcut: 'cmd+o'
			group:    'Files'
		},
		ui2.CommandPaletteItem{
			id:       'save'
			label:    'Save'
			icon:     'square.and.arrow.down'
			shortcut: 'cmd+s'
			group:    'Files'
		},
		ui2.CommandPaletteItem{
			id:       'save-as'
			label:    'Save As…'
			shortcut: 'cmd+shift+s'
			group:    'Files'
		},
		ui2.CommandPaletteItem{
			id:          'profile'
			label:       'Profile'
			description: 'Name, avatar and email'
			icon:        'person'
			shortcut:    'cmd+p'
			group:       'Settings'
			keywords:    ['account', 'user']
		},
		ui2.CommandPaletteItem{
			id:       'billing'
			label:    'Billing'
			icon:     'creditcard'
			shortcut: 'cmd+b'
			group:    'Settings'
		},
		ui2.CommandPaletteItem{
			id:       'settings'
			label:    'Settings'
			icon:     'gearshape'
			shortcut: 'cmd+,'
			group:    'Settings'
			keywords: ['preferences']
		},
		ui2.CommandPaletteItem{
			id:      'sidebar'
			label:   'Show Sidebar'
			icon:    'sidebar.right'
			group:   'View'
			checked: app.sidebar
		},
		ui2.CommandPaletteItem{
			id:    'theme'
			label: 'Toggle Dark Mode'
			icon:  'moon'
			group: 'View'
		},
	]
}

// ── Layout ─────────────────────────────────────────────────────────

struct Layout {
	width   f64
	height  f64
	left_x  f64
	right_x f64
	column  f64
}

fn layout() Layout {
	win := ui2.bounds()
	return Layout{
		width:   win.width
		height:  win.height
		left_x:  24
		right_x: win.width / 2 + 12
		column:  win.width / 2 - 36
	}
}

fn window_rect(l Layout) ui2.Rect {
	return ui2.rect(0, 0, l.width, l.height)
}

// select_frames places every select; all are direct children of the screen,
// so a frame is also the anchor its popup opens from.
fn select_frame(l Layout, id string) ui2.Rect {
	x := l.left_x
	return match id {
		'fruit' { ui2.rect(x, 172, 200, 32) }
		'theme' { ui2.rect(x + 216, 172, 200, 32) }
		'labels' { ui2.rect(x, 252, 300, 32) }
		'reviewers' { ui2.rect(x + 316, 252, 180, 32) }
		'small' { ui2.rect(x, 334, 120, 24) }
		'large' { ui2.rect(x + 136, 330, 150, 40) }
		'disabled' { ui2.rect(x + 302, 334, 190, 32) }
		'language' { ui2.rect(x, 436, 260, 32) }
		else { ui2.Rect{} }
	}
}

fn select_config(app &Gallery, id string) ui2.SelectConfig {
	l := layout()
	slot := app.selects[id] or { &SelectSlot{} }
	theme := ui2.component_theme(app.dark)
	base := ui2.SelectConfig{
		id:       id
		frame:    select_frame(l, id)
		window:   window_rect(l)
		state:    slot.state
		selected: slot.selected
		theme:    theme
	}
	return match id {
		'fruit' {
			ui2.SelectConfig{
				...base
				options:     fruits()
				placeholder: 'Pick a fruit'
				max_height:  220
			}
		}
		'theme' {
			ui2.SelectConfig{
				...base
				options:      themes()
				title_prefix: 'Theme: '
			}
		}
		'labels' {
			ui2.SelectConfig{
				...base
				options:     labels()
				multiple:    true
				clearable:   true
				placeholder: 'Add labels'
			}
		}
		'reviewers' {
			ui2.SelectConfig{
				...base
				options:      people()
				multiple:     true
				display:      .count
				count_format: '{count} reviewers'
				placeholder:  'Reviewers'
			}
		}
		'small', 'large' {
			ui2.SelectConfig{
				...base
				options: size_options()
				size:    if id == 'small' { ui2.ComponentSize.small } else { .large }
			}
		}
		'disabled' {
			ui2.SelectConfig{
				...base
				options: [ui2.picker_option('locked', 'Managed by an admin')]
				enabled: false
			}
		}
		else {
			ui2.SelectConfig{
				...base
				options:             languages()
				searchable:          true
				clearable:           true
				separators:          true
				placeholder:         'Choose a language'
				search_placeholder:  'Search languages'
				menu_width:          300
				accessibility_label: 'Programming language'
			}
		}
	}
}

const select_ids = ['fruit', 'theme', 'labels', 'reviewers', 'small', 'large', 'disabled', 'language']

fn city_frame(l Layout) ui2.Rect {
	return ui2.rect(l.right_x, 172, 280, 32)
}

fn package_frame(l Layout) ui2.Rect {
	return ui2.rect(l.right_x + 296, 172, l.column - 296, 32)
}

fn city_config(app &Gallery) ui2.ComboboxConfig {
	l := layout()
	return ui2.ComboboxConfig{
		id:          'city'
		frame:       city_frame(l)
		window:      window_rect(l)
		text:        app.city
		value:       app.city_value
		options:     cities()
		state:       app.city_state
		placeholder: 'Search a city'
		icon:        'location'
		clearable:   true
		max_height:  200
		theme:       ui2.component_theme(app.dark)
	}
}

fn package_config(app &Gallery) ui2.ComboboxConfig {
	l := layout()
	return ui2.ComboboxConfig{
		id:          'package'
		frame:       package_frame(l)
		window:      window_rect(l)
		text:        app.package
		value:       app.package_value
		options:     app.packages
		state:       app.package_state
		placeholder: 'Find a module'
		match_mode:  .fuzzy
		sort:        true
		min_chars:   1
		loading:     app.loading
		empty_text:  'No module matches'
		theme:       ui2.component_theme(app.dark)
	}
}

fn panel_frame(l Layout) ui2.Rect {
	return ui2.rect(l.right_x, 466, l.column, l.height - 466 - 24)
}

fn panel_config(app &Gallery) ui2.CommandPaletteConfig {
	return ui2.CommandPaletteConfig{
		id:     'panel'
		modal:  false
		frame:  panel_frame(layout())
		state:  app.panel
		items:  commands(app)
		recent: app.recent
		theme:  ui2.component_theme(app.dark)
	}
}

fn palette_config(app &Gallery) ui2.CommandPaletteConfig {
	return ui2.CommandPaletteConfig{
		id:     'palette'
		window: window_rect(layout())
		state:  app.palette
		items:  commands(app)
		recent: app.recent
		theme:  ui2.component_theme(app.dark)
	}
}

// ── Building ───────────────────────────────────────────────────────

fn caption(text string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color: theme.muted_foreground
		size:  13
	})
}

fn heading(text string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color: theme.foreground
		size:  17
		bold:  true
	})
}

fn note(text string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color:  theme.muted_foreground
		size:   13
		lines:  2
		valign: .top
	})
}

fn build() ui2.Element {
	app := gallery()
	theme := ui2.component_theme(app.dark)
	l := layout()
	mut children := [
		ui2.label('', 'Select, combobox and command palette', ui2.rect(24, 16, 600, 30),
			ui2.TextStyle{
				color: theme.foreground
				size:  22
				bold:  true
			}),
		ui2.link(
			id:    'theme-link'
			text:  'Light / dark'
			frame: ui2.rect(l.width - 124, 18, 100, 28)
			theme: theme
		) or { panic(err) },
		caption(app.status, ui2.rect(24, 52, l.width - 48, 20), theme),
		heading('Select', ui2.rect(l.left_x, 92, l.column, 24), theme),
		note('A trigger and a popup of options: icons, a prefix, tags or a count for several choices, sizes, and a disabled state.',
			ui2.rect(l.left_x, 114, l.column, 34), theme),
		caption('Placeholder', ui2.rect(l.left_x, 150, 200, 18), theme),
		caption('Icons and a prefix', ui2.rect(l.left_x + 216, 150, 200, 18), theme),
		caption('Several, as tags (clearable)', ui2.rect(l.left_x, 230, 300, 18), theme),
		caption('Several, as a count', ui2.rect(l.left_x + 316, 230, 180, 18), theme),
		caption('Small, large and disabled', ui2.rect(l.left_x, 312, 300, 18), theme),
		heading('Searchable, grouped, with descriptions', ui2.rect(l.left_x, 404, l.column,
			24), theme),
		caption('↑ ↓ move, Enter chooses, Esc closes.', ui2.rect(l.left_x + 276, 443, l.column - 276,
			18), theme),
	]
	for id in select_ids {
		children << ui2.select_box(select_config(app, id)) or { panic(err) }
	}

	children << heading('Combobox', ui2.rect(l.right_x, 92, l.column, 24), theme)
	children << note('Type to filter; the field keeps the focus while the arrows move through the list and Enter picks.',
		ui2.rect(l.right_x, 114, l.column, 34), theme)
	children << caption('Substring match', ui2.rect(l.right_x, 150, 280, 18), theme)
	children << caption('Fuzzy, loaded on demand', ui2.rect(l.right_x + 296, 150, l.column - 296,
		18), theme)
	children << ui2.combobox(city_config(app)) or { panic(err) }
	children << ui2.combobox(package_config(app)) or { panic(err) }

	children << heading('Command', ui2.rect(l.right_x, 404, l.column, 24), theme)
	children << caption('Fuzzy search with highlighted matches. ${ui2.command_palette_shortcut_label()} opens it as a palette.',
		ui2.rect(l.right_x, 428, l.column - 120, 34), theme)
	children << ui2.button('open-palette', 'Open ${ui2.command_palette_shortcut_label()}',
		ui2.rect(l.right_x + l.column - 108, 420, 108, 30), ui2.BoxStyle{
			bg:     theme.muted
			radius: 6
		}, ui2.TextStyle{
			color: theme.foreground
			size:  13
			align: .center
		})
	children << ui2.command_palette(panel_config(app)) or { panic(err) }

	// Overlays last, so they are drawn over everything else.
	for id in select_ids {
		children << ui2.select_popup(select_config(app, id)) or { panic(err) }
	}
	children << ui2.combobox_popup(city_config(app)) or { panic(err) }
	children << ui2.combobox_popup(package_config(app)) or { panic(err) }
	children << ui2.command_palette(palette_config(app)) or { panic(err) }
	return ui2.screen(theme.background, children)
}

// ── Events ─────────────────────────────────────────────────────────

fn (mut app Gallery) apply_select(id string, step ui2.SelectStep) {
	mut slot := app.selects[id] or { return }
	slot.state = step.state
	if step.changed {
		slot.selected = step.selected
		cfg := select_config(app, id)
		shown := ui2.select_display_text(cfg)
		app.status = if shown.len > 0 { '${id}: ${shown}' } else { '${id}: cleared' }
	}
	if step.focus.len > 0 {
		app.focus_id = step.focus
	}
}

fn (mut app Gallery) apply_combobox(id string, step ui2.ComboboxStep) {
	if id == 'city' {
		app.city = step.text
		app.city_value = step.value
		app.city_state = step.state
	} else {
		app.package = step.text
		app.package_value = step.value
		app.package_state = step.state
	}
	match step.change {
		.picked { app.status = '${id}: picked “${step.text}” (${step.value})' }
		.submitted { app.status = '${id}: submitted the text “${step.text}”' }
		.cleared { app.status = '${id}: cleared' }
		else {}
	}
	if step.focus.len > 0 {
		app.focus_id = step.focus
	}
}

// search_packages asks the stand-in server for modules matching the text;
// only the latest request is shown when it answers.
fn (mut app Gallery) search_packages() {
	app.request++
	request := app.request
	query := app.package
	app.loading = query.len > 0
	if !app.loading {
		app.packages = []
		return
	}
	ui2.after(0.6, fn [request, query] () {
		mut latest := gallery()
		if latest.request != request {
			return
		}
		latest.loading = false
		latest.packages = package_results(query)
		latest.package_state = ui2.combobox_input(package_config(latest), latest.package).state
	})
}

fn (mut app Gallery) apply_command(step ui2.CommandPaletteStep, modal bool) {
	if modal {
		app.palette = step.state
	} else {
		app.panel = step.state
	}
	if step.focus.len > 0 {
		app.focus_id = step.focus
	}
	if step.chosen {
		app.recent = ui2.command_palette_remember(app.recent, step.item.id, 3)
		match step.item.id {
			'theme' { app.dark = !app.dark }
			'sidebar' { app.sidebar = !app.sidebar }
			else {}
		}
		app.status = 'Ran “${step.item.label}”.'
	}
}

// handle returns whether the event changed anything.
fn (mut app Gallery) handle(event string) bool {
	// Edits of the search fields and the combobox fields carry their text.
	for id in select_ids {
		if event == ui2.select_search_id(id) {
			app.apply_select(id, ui2.select_search(select_config(app, id), ui2.text(event)))
			app.reveal_id = id
			return true
		}
	}
	if event == ui2.combobox_field_id('city') {
		app.apply_combobox('city', ui2.combobox_input(city_config(app), ui2.text(event)))
		app.reveal_id = 'city'
		return true
	}
	if event == ui2.combobox_field_id('package') {
		app.apply_combobox('package', ui2.combobox_input(package_config(app), ui2.text(event)))
		app.search_packages()
		app.reveal_id = 'package'
		return true
	}
	if event == ui2.command_palette_search_id('palette') {
		app.apply_command(ui2.command_palette_search(palette_config(app), ui2.text(event)),
			true)
		app.reveal_id = 'palette'
		return true
	}
	if event == ui2.command_palette_search_id('panel') {
		app.apply_command(ui2.command_palette_search(panel_config(app), ui2.text(event)),
			false)
		app.reveal_id = 'panel'
		return true
	}
	for id in select_ids {
		if step := ui2.select_update(select_config(app, id), event) {
			app.apply_select(id, step)
			return true
		}
	}
	if step := ui2.combobox_update(city_config(app), event) {
		app.apply_combobox('city', step)
		return true
	}
	if step := ui2.combobox_update(package_config(app), event) {
		app.apply_combobox('package', step)
		return true
	}
	if step := ui2.command_palette_update(palette_config(app), event) {
		app.apply_command(step, true)
		return true
	}
	if step := ui2.command_palette_update(panel_config(app), event) {
		app.apply_command(step, false)
		return true
	}
	match event {
		'theme-link' {
			app.dark = !app.dark
		}
		'open-palette' {
			app.apply_command(ui2.command_palette_open(palette_config(app)), true)
		}
		else {
			return false
		}
	}
	return true
}

// settle rebuilds, then does what has to wait for the new tree: focusing a
// field that just appeared and scrolling the highlighted row into view.
fn settle(mut app Gallery) {
	ui2.refresh()
	if app.focus_id.len > 0 {
		ui2.focus(app.focus_id)
		app.focus_id = ''
	}
	id := app.reveal_id
	app.reveal_id = ''
	mut list := ''
	mut row := ?ui2.Rect(none)
	if id in select_ids {
		list = ui2.select_list_id(id)
		row = ui2.select_highlight_rect(select_config(app, id))
	} else if id == 'city' || id == 'package' {
		list = ui2.combobox_list_id(id)
		row = ui2.combobox_highlight_rect(if id == 'city' {
			city_config(app)
		} else {
			package_config(app)
		})
	} else if id == 'palette' || id == 'panel' {
		list = ui2.command_palette_list_id(id)
		row = ui2.command_palette_highlight_rect(if id == 'palette' {
			palette_config(app)
		} else {
			panel_config(app)
		})
	}
	if r := row {
		ui2.scroll_to_rect(list, r.x, r.y, r.width, r.height)
	}
}

fn on_event(event string) {
	mut app := gallery()
	if app.handle(event) {
		settle(mut app)
	}
}

// key_step routes a key to whatever has the keyboard: the open palette, a
// focused combobox or command panel field, or an open select. It reports
// whether the key changed anything and whether it is used up.
fn (mut app Gallery) key_step(event ui2.KeyEvent) (bool, bool) {
	if step := ui2.command_palette_toggle_key(palette_config(app), event) {
		app.apply_command(step, true)
		return true, true
	}
	if app.palette.open {
		if step := ui2.command_palette_key(palette_config(app), event) {
			app.apply_command(step, true)
			app.reveal_id = 'palette'
			return true, true
		}
		// Tab stays on the palette's field.
		if backwards := ui2.focus_trap_direction(event) {
			if next := ui2.focus_trap_target([ui2.command_palette_focus_trap(palette_config(app))],
				ui2.focused_id(), backwards)
			{
				app.focus_id = next
				return true, true
			}
		}
		return false, false
	}
	focused := ui2.focused_id()
	if focused == ui2.combobox_field_id('city') {
		if step := ui2.combobox_key(city_config(app), event) {
			app.apply_combobox('city', step)
			app.reveal_id = 'city'
			return true, !step.propagate
		}
	}
	if focused == ui2.combobox_field_id('package') {
		if step := ui2.combobox_key(package_config(app), event) {
			app.apply_combobox('package', step)
			app.reveal_id = 'package'
			return true, !step.propagate
		}
	}
	if focused == ui2.command_palette_search_id('panel') {
		if step := ui2.command_palette_key(panel_config(app), event) {
			app.apply_command(step, false)
			app.reveal_id = 'panel'
			return true, true
		}
	}
	for id in select_ids {
		if step := ui2.select_key(select_config(app, id), event) {
			app.apply_select(id, step)
			app.reveal_id = id
			return true, !step.propagate
		}
	}
	return false, false
}

fn on_key(event ui2.KeyEvent) {
	mut app := gallery()
	changed, used := app.key_step(event)
	if used {
		ui2.consume_key()
	}
	if changed {
		settle(mut app)
	}
}

// on_tab catches Tab in a focused AppKit field, which reaches on_key only, as
// 'tab' or 'shift+tab' (on_key_event gets it first everywhere else), and
// routes it like any other key: the palette's focus trap keeps it on its field,
// and an open combobox list closes as the focus leaves.
fn on_tab(key string) {
	backwards := ui2.focus_trap_key_direction(key) or { return }
	mut app := gallery()
	changed, used := app.key_step(ui2.KeyEvent{
		code:  .tab
		shift: backwards
	})
	if used {
		ui2.consume_key()
	}
	if changed {
		settle(mut app)
	}
}

fn main() {
	mut app := gallery()
	if os.getenv('UI2_PICKERS_PALETTE') == '1' {
		// Show the palette alone, over the page with every other popup closed.
		app.palette = ui2.command_palette_open(palette_config(app)).state
		app.city_state = ui2.ComboboxState{}
		mut language := app.selects['language'] or { &SelectSlot{} }
		language.state = ui2.SelectState{}
	}
	ui2.on_key_event(on_key)
	ui2.on_key(on_tab)
	ui2.run_window('GPUI Kit pickers', window_width, window_height, build, on_event)
}
