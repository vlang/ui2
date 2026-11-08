module main

import math
import os
import ui2

// GPUI Kit's Dock and Resizable panels. The Workspace page is an IDE built
// with dock_area: an explorer and search on the left, editor tabs in the
// center, an outline on the right and a terminal, problems and output at the
// bottom. Drag the dock edges and the dividers, close and reorder tabs from the
// tab bars and their "..." menus, move a panel to another dock, zoom one in,
// and save and restore the layout. The Resizable page nests a vertical group in
// a horizontal one, with fixed, collapsible, bounded and hidden panels.

enum Page {
	workspace
	resizable
}

@[heap]
struct App {
mut:
	dark     bool
	page     Page = .workspace
	layout   ui2.DockLayout
	dock     ui2.DockAreaState
	saved    string
	status   string = 'Drag an edge or a divider, or open a panel menu with "..."'
	selected string = 'main.v'
	expanded map[string]bool
	// The Resizable page: an outer row and the column inside its main panel.
	outer          ui2.ResizableState
	inner          ui2.ResizableState
	show_inspector bool = true
}

const app_state = &App{}

fn app() &App {
	return unsafe { app_state }
}

const layout_version = 1
const toolbar_height = 44.0
const status_height = 26.0
const area_id = 'workspace'
const outer_id = 'resizable-outer'
const inner_id = 'resizable-inner'
const files = ['main.v', 'dock.v', 'layout.v', 'README.md', 'v.mod']

fn default_layout() ui2.DockLayout {
	return ui2.DockLayout{
		version: layout_version
		center:  ui2.DockRegion{
			groups: [
				ui2.DockGroup{
					panels: ['main.v', 'dock.v', 'README.md']
				},
			]
		}
		left:    ui2.DockRegion{
			size:   260
			groups: [
				ui2.DockGroup{
					panels: ['explorer', 'search']
				},
			]
		}
		right:   ui2.DockRegion{
			size:   232
			groups: [
				ui2.DockGroup{
					panels: ['outline']
				},
			]
		}
		bottom:  ui2.DockRegion{
			size:   214
			groups: [
				ui2.DockGroup{
					panels: ['terminal', 'problems', 'output']
				},
			]
		}
	}
}

fn file_icon(name string) string {
	return if name.ends_with('.v') {
		'curlybraces'
	} else if name.ends_with('.md') {
		'doc.text.fill'
	} else {
		'doc'
	}
}

fn dock_panels() []ui2.DockPanel {
	mut panels := [
		ui2.DockPanel{
			id:    'explorer'
			title: 'Explorer'
			icon:  'folder'
		},
		ui2.DockPanel{
			id:    'search'
			title: 'Search'
			icon:  'magnifyingglass'
		},
		ui2.DockPanel{
			id:    'outline'
			title: 'Outline'
			icon:  'list.bullet'
		},
		ui2.DockPanel{
			id:          'terminal'
			title:       'Terminal'
			icon:        'chevron.right'
			zoom_button: true
		},
		ui2.DockPanel{
			id:    'problems'
			title: 'Problems'
			icon:  'exclamationmark.triangle'
		},
		ui2.DockPanel{
			id:    'output'
			title: 'Output'
			icon:  'text.alignleft'
		},
	]
	for name in files {
		panels << ui2.DockPanel{
			id:         name
			title:      name
			icon:       file_icon(name)
			menu_items: [
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('copy-path', 'Copy Path')
					icon: 'doc.on.doc'
				},
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('reveal', 'Reveal in Explorer')
					icon: 'folder'
				},
			]
		}
	}
	return panels
}

fn panel_ids() []string {
	return dock_panels().map(it.id)
}

// ── Colors ──────────────────────────────────────────────────────────

fn mix(a u32, b u32, t f64) u32 {
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := f64((a >> shift) & 0xff)
		to := f64((b >> shift) & 0xff)
		out |= u32(math.round(from + (to - from) * t)) << shift
	}
	return out
}

struct Palette {
	keyword  u32
	text     u32
	str      u32
	comment  u32
	number   u32
	function u32
	typ      u32
}

fn palette(dark bool) Palette {
	return if dark {
		Palette{
			keyword:  0xc4b5fd
			text:     0xe2e8f0
			str:      0x86efac
			comment:  0x7c8aa0
			number:   0xfdba74
			function: 0x93c5fd
			typ:      0x67e8f9
		}
	} else {
		Palette{
			keyword:  0x7c3aed
			text:     0x1e293b
			str:      0x15803d
			comment:  0x94a3b8
			number:   0xc2410c
			function: 0x2563eb
			typ:      0x0e7490
		}
	}
}

// A point is 4/3 of a pixel where the custom renderer draws text at 96 dpi.
fn mono_advance(size f64) f64 {
	$if linux || windows {
		return size * 0.6 * 96.0 / 72.0
	} $else {
		return size * 0.6
	}
}

fn symbol(name string, frame ui2.Rect, color u32) ui2.Element {
	return ui2.Element{
		...ui2.image('', 'symbol:' + name, frame)
		text_style: ui2.TextStyle{
			color: color
		}
	}
}

fn text(value string, frame ui2.Rect, color u32, size f64, bold bool) ui2.Element {
	return ui2.label('', value, frame, ui2.TextStyle{
		color: color
		size:  size
		bold:  bold
	})
}

fn fill(frame ui2.Rect, color u32) ui2.Element {
	return ui2.view('', frame, ui2.BoxStyle{ bg: color }, []ui2.Element{})
}

// ── Editor ──────────────────────────────────────────────────────────

const main_source = "module main

import ui2

// App keeps the layout the user arranged.
struct App {
mut:
	layout ui2.DockLayout
	state  ui2.DockAreaState
	dark   bool
}

fn build() ui2.Element {
	win := ui2.bounds()
	return ui2.screen(0xffffff, [
		ui2.dock_area(config(win)) or { panic(err) },
	])
}

fn on_event(event string) {
	if e := ui2.dock_area_event(config(ui2.bounds()), event) {
		app.layout = e.layout
		app.state = e.state
		ui2.refresh()
	}
}

fn save() {
	text := ui2.dock_layout_encode(app.layout)
	os.write_file('layout.txt', text) or {}
}

fn main() {
	ui2.run_window('Studio', 1280, 800, build, on_event)
}"

const dock_source = 'module ui2

// dock_layout_move moves a panel to another region.
pub fn dock_layout_move(layout DockLayout, panel string,
	placement DockPlacement) ?DockLayout {
	at := dock_layout_find(layout, panel)?
	if at.placement == placement {
		return none
	}
	return dock_layout_add(layout, panel, placement)
}

// dock_layout_toggle opens or closes a dock.
pub fn dock_layout_toggle(layout DockLayout,
	placement DockPlacement) ?DockLayout {
	region := layout.region(placement)
	if placement == .center || !region.has_panels() {
		return none
	}
	return layout.with_open(placement, !region.open)
}'

const layout_source = 'module main

const sidebar = 240
const inspector = 280

fn sizes(width f64) []f64 {
	main := width - sidebar - inspector - 2
	return [f64(sidebar), main, inspector]
}'

const readme_source = "# ui2 Studio

A small IDE layout built with ui2's dock area.

- Drag the edges of the docks to resize them.
- Drag a dock edge past half its minimum to close it.
- Use the ... menu to move a panel to another dock.
- Zoom a panel to fill the window; Escape zooms out.
- Save the layout and restore it later.

The layout is a plain value: encode it to text,
store it anywhere, decode it on the next launch."

const vmod_source = "Module {
	name: 'studio'
	description: 'A ui2 dock area demo'
	version: '0.1.0'
	license: 'MIT'
	dependencies: ['ui2']
}"

fn source_of(name string) string {
	return match name {
		'main.v' { main_source }
		'dock.v' { dock_source }
		'layout.v' { layout_source }
		'README.md' { readme_source }
		else { vmod_source }
	}
}

const keywords = ['module', 'import', 'struct', 'mut', 'pub', 'fn', 'return', 'if', 'else', 'or',
	'for', 'in', 'const', 'match', 'none']

// Token is a run of source text and its color.
struct Token {
	text  string
	color u32
}

fn tokens_of(line string, markdown bool, pal Palette) []Token {
	if markdown {
		color := if line.starts_with('#') {
			pal.keyword
		} else if line.starts_with('-') {
			pal.function
		} else {
			pal.text
		}
		return [Token{
			text:  line
			color: color
		}]
	}
	mut out := []Token{}
	mut i := 0
	for i < line.len {
		ch := line[i]
		if ch == `/` && i + 1 < line.len && line[i + 1] == `/` {
			out << Token{
				text:  line[i..]
				color: pal.comment
			}
			break
		}
		if ch == `'` || ch == `"` {
			mut j := i + 1
			for j < line.len && line[j] != ch {
				j++
			}
			j = math.min(j + 1, line.len)
			out << Token{
				text:  line[i..j]
				color: pal.str
			}
			i = j
			continue
		}
		if ch.is_letter() || ch == `_` {
			mut j := i
			for j < line.len && (line[j].is_letter() || line[j].is_digit() || line[j] == `_`) {
				j++
			}
			word := line[i..j]
			color := if word in keywords {
				pal.keyword
			} else if j < line.len && line[j] == `(` {
				pal.function
			} else if word[0] >= `A` && word[0] <= `Z` {
				pal.typ
			} else {
				pal.text
			}
			out << Token{
				text:  word
				color: color
			}
			i = j
			continue
		}
		if ch.is_digit() {
			mut j := i
			for j < line.len && (line[j].is_digit() || line[j] == `x` || line[j] == `.`) {
				j++
			}
			out << Token{
				text:  line[i..j]
				color: pal.number
			}
			i = j
			continue
		}
		mut j := i
		for j < line.len && !(line[j].is_letter() || line[j].is_digit() || line[j] in [
			`_`,
			`'`,
			`"`,
			`/`,
		]) {
			j++
		}
		if j == i {
			j++
		}
		out << Token{
			text:  line[i..j]
			color: pal.text
		}
		i = j
	}
	return out
}

fn editor_panel(name string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	pal := palette(app().dark)
	size := 12.5
	line_height := 20.0
	advance := mono_advance(size)
	gutter := 46.0
	lines := source_of(name).split_into_lines()
	current := 11
	mut rows := []ui2.Element{}
	for n, source in lines {
		y := 8 + f64(n) * line_height
		mut cells := []ui2.Element{}
		if n == current {
			cells << fill(ui2.rect(0, 0, math.max(frame.width, 600), line_height), mix(theme.background,
				theme.primary, 0.07))
		}
		cells << ui2.label('', '${n + 1}', ui2.rect(0, 0, gutter - 14, line_height), ui2.TextStyle{
			color:       if n == current { theme.foreground } else { theme.muted_foreground }
			size:        size - 1
			align:       .right
			font_family: 'Menlo'
		})
		mut column := 0
		for token in tokens_of(source.replace('\t', '    '), name.ends_with('.md'), pal) {
			if token.text.trim_space().len > 0 {
				// Generous widths: a native label insets its text a little, and a
				// label too narrow for its text would cut it short.
				cells << ui2.label('', token.text, ui2.rect(gutter + f64(column) * advance,
					0, f64(token.text.len + 4) * advance, line_height), ui2.TextStyle{
					color:       token.color
					size:        size
					font_family: 'Menlo'
				})
			}
			column += token.text.len
		}
		rows << ui2.Element{
			...ui2.view('', ui2.rect(0, y, math.max(frame.width, 600), line_height), ui2.BoxStyle{
				transparent: true
			}, cells)
			key: 'line:${n}'
		}
	}
	return ui2.scroll('editor-' + name.replace('.', '-'), frame, theme.background, rows)
}

// ── Explorer, search and outline ────────────────────────────────────

struct TreeRow {
	name   string
	depth  int
	folder bool
}

fn tree_row(name string, depth int, folder bool) TreeRow {
	return TreeRow{
		name:   name
		depth:  depth
		folder: folder
	}
}

fn tree_rows(state &App) []TreeRow {
	mut rows := [tree_row('ui2-studio', 0, true)]
	if state.expanded['ui2-studio'] {
		rows << tree_row('src', 1, true)
		if state.expanded['src'] {
			for name in ['main.v', 'dock.v', 'layout.v'] {
				rows << tree_row(name, 2, false)
			}
		}
		rows << tree_row('assets', 1, true)
		if state.expanded['assets'] {
			rows << tree_row('icon.png', 2, false)
		}
		rows << tree_row('README.md', 1, false)
		rows << tree_row('v.mod', 1, false)
	}
	return rows
}

fn explorer_panel(frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	state := app()
	row_height := 26.0
	mut rows := []ui2.Element{}
	for n, row in tree_rows(state) {
		x := 10 + f64(row.depth) * 16
		selected := !row.folder && row.name == state.selected
		mut cells := []ui2.Element{}
		if row.folder {
			cells << symbol(if state.expanded[row.name] { 'chevron.down' } else { 'chevron.right' },
				ui2.rect(x, 8, 10, 10), theme.muted_foreground)
		}
		cells << symbol(if row.folder { 'folder.fill' } else { file_icon(row.name) }, ui2.rect(x + 14,
			6, 14, 14), if row.folder {
			theme.primary
		} else if selected {
			theme.primary
		} else {
			theme.muted_foreground
		})
		cells << text(row.name, ui2.rect(x + 34, 0, math.max(frame.width - x - 44, 0), row_height),
			if selected {
				theme.foreground
			} else {
				mix(theme.foreground, theme.muted_foreground, 0.3)
			},
			13, selected)
		action := if row.folder { 'folder:' + row.name } else { 'open:' + row.name }
		rows << ui2.Element{
			...ui2.button_view('tree-' + n.str(), ui2.rect(4, 6 + f64(n) * row_height,
				math.max(frame.width - 8, 0), row_height), if selected {
				ui2.BoxStyle{
					bg:     mix(theme.background, theme.primary, 0.12)
					radius: 5
				}
			} else {
				ui2.BoxStyle{
					transparent: true
					radius:      5
				}
			}, cells)
			key:       'row:' + row.name
			action_id: action
		}
	}
	return ui2.scroll('explorer-tree', frame, theme.background, rows)
}

fn search_panel(frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	results := [
		['main.v', '12', 'fn build() ui2.Element {'],
		['main.v', '19', 'fn on_event(event string) {'],
		['dock.v', '4', 'pub fn dock_layout_move(layout DockLayout,'],
		['dock.v', '13', 'pub fn dock_layout_toggle(layout DockLayout,'],
	]
	mut children := [
		ui2.text_field('search-field', 'Search files', 'fn ', ui2.rect(10, 10, math.max(frame.width - 20,
			0), 28), ui2.BoxStyle{
			bg:            theme.background
			radius:        6
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, ui2.TextStyle{
			color: theme.foreground
			size:  13
		}, ui2.keyboard_default),
		text('4 results in 2 files', ui2.rect(12, 44, math.max(frame.width - 24, 0), 20), theme.muted_foreground,
			12, false),
	]
	for n, result in results {
		y := 70 + f64(n) * 42
		children << symbol(file_icon(result[0]), ui2.rect(12, y + 3, 13, 13), theme.primary)
		children << text('${result[0]}:${result[1]}', ui2.rect(32, y, frame.width - 44, 20), theme.foreground,
			12, true)
		children << ui2.label('', result[2], ui2.rect(32, y + 18, math.max(frame.width - 44, 0),
			18), ui2.TextStyle{
			color:       theme.muted_foreground
			size:        11.5
			font_family: 'Menlo'
		})
	}
	return ui2.view('search-body', frame, ui2.BoxStyle{ transparent: true }, children)
}

fn outline_panel(frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	entries := [['curlybraces', 'App', 'struct'], ['function', 'build', 'fn'],
		['function', 'on_event', 'fn'], ['function', 'save', 'fn'], ['function', 'main', 'fn']]
	mut children := [
		text(app().selected, ui2.rect(12, 8, math.max(frame.width - 24, 0), 22), theme.muted_foreground,
			12, true),
	]
	for n, entry in entries {
		y := 34 + f64(n) * 26
		color := if entry[2] == 'struct' { theme.warning } else { theme.primary }
		children << symbol(entry[0], ui2.rect(14, y + 6, 14, 14), color)
		children << text(entry[1], ui2.rect(36, y, math.max(frame.width - 90, 0), 26), theme.foreground,
			13, false)
		children << ui2.label('', entry[2], ui2.rect(frame.width - 60, y, 48, 26), ui2.TextStyle{
			color: theme.muted_foreground
			size:  11
			align: .right
		})
	}
	return ui2.view('outline-body', frame, ui2.BoxStyle{ transparent: true }, children)
}

// ── Bottom panels ───────────────────────────────────────────────────

fn terminal_panel(frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	pal := palette(app().dark)
	lines := [
		['$ ', 'v run examples/gpui_panels'],
		['', 'Building gpui_panels (native)...'],
		['', 'Built in 1.84 s'],
		['$ ', 'v test ui/component_panels_test.v'],
		['', 'OK  ui/component_panels_test.v'],
		['$ ', ''],
	]
	mut children := []ui2.Element{}
	for n, line in lines {
		y := 8 + f64(n) * 20
		children << ui2.label('', line[0], ui2.rect(12, y, 16, 20), ui2.TextStyle{
			color:       pal.str
			size:        12.5
			bold:        true
			font_family: 'Menlo'
		})
		children << ui2.label('', line[1], ui2.rect(if line[0].len > 0 { 28.0 } else { 12.0 },
			y, math.max(frame.width - 40, 0), 20), ui2.TextStyle{
			color:       if line[0].len > 0 { theme.foreground } else { theme.muted_foreground }
			size:        12.5
			font_family: 'Menlo'
		})
	}
	children << fill(ui2.rect(28, 8 + 5 * 20 + 3, 8, 15), theme.foreground)
	return ui2.view('terminal-body', frame, ui2.BoxStyle{ transparent: true }, children)
}

fn problems_panel(frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	problems := [
		['xmark.circle', 'unknown field `drag` in DockAreaState', 'main.v', '18:5'],
		['exclamationmark.triangle', 'variable `text` shadows a function declaration', 'main.v',
			'28:2'],
		['exclamationmark.triangle', 'unused parameter `placement`', 'dock.v', '14:2'],
	]
	mut children := []ui2.Element{}
	for n, problem in problems {
		y := 6 + f64(n) * 28
		children << symbol(problem[0], ui2.rect(14, y + 7, 14, 14), if problem[0] == 'xmark.circle' {
			theme.danger
		} else {
			mix(theme.warning, theme.foreground, 0.25)
		})
		children << text(problem[1], ui2.rect(38, y, math.max(frame.width - 200, 0), 28), theme.foreground,
			13, false)
		children << ui2.label('', '${problem[2]}  ${problem[3]}', ui2.rect(frame.width - 150,
			y, 136, 28), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
			align: .right
		})
	}
	return ui2.view('problems-body', frame, ui2.BoxStyle{ transparent: true }, children)
}

fn output_panel(frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	state := app()
	saved := if state.saved.len > 0 { '${state.saved.len} bytes' } else { 'nothing yet' }
	lines := [
		'[layout] ${ui2.dock_layout_panels(state.layout).len} panels open',
		'[layout] saved: ${saved}',
		'[status] ${state.status}',
	]
	mut children := []ui2.Element{}
	for n, line in lines {
		children << ui2.label('', line, ui2.rect(12, 8 + f64(n) * 20, math.max(frame.width - 24,
			0), 20), ui2.TextStyle{
			color:       theme.muted_foreground
			size:        12
			font_family: 'Menlo'
		})
	}
	return ui2.view('output-body', frame, ui2.BoxStyle{ transparent: true }, children)
}

fn build_panel(panel string, frame ui2.Rect) ui2.Element {
	theme := ui2.component_theme(app().dark)
	return match panel {
		'explorer' { explorer_panel(frame, theme) }
		'search' { search_panel(frame, theme) }
		'outline' { outline_panel(frame, theme) }
		'terminal' { terminal_panel(frame, theme) }
		'problems' { problems_panel(frame, theme) }
		'output' { output_panel(frame, theme) }
		else { editor_panel(panel, frame, theme) }
	}
}

fn dock_config(state &App) ui2.DockAreaConfig {
	win := ui2.bounds()
	return ui2.DockAreaConfig{
		id:      area_id
		frame:   ui2.rect(0, toolbar_height, win.width, math.max(win.height - toolbar_height - status_height,
			0))
		layout:  state.layout
		state:   state.dock
		panels:  dock_panels()
		content: build_panel
		theme:   ui2.component_theme(state.dark)
	}
}

// ── Resizable page ──────────────────────────────────────────────────

fn size_text(frame ui2.Rect) string {
	return '${int(math.round(frame.width))} × ${int(math.round(frame.height))}'
}

// panel_card is what each resizable panel shows: its name, its size as laid
// out, and its constraints.
fn panel_card(title string, icon string, rules string, frame ui2.Rect, tint u32) ui2.Element {
	theme := ui2.component_theme(app().dark)
	bg := mix(theme.background, tint, if app().dark { 0.16 } else { 0.07 })
	w := frame.width
	h := frame.height
	top := math.max(math.round(h / 2 - 46), 8)
	mut children := []ui2.Element{}
	if w >= 60 && h >= 80 {
		children << symbol(icon, ui2.rect(math.round(w / 2 - 11), top, 22, 22), tint)
		children << ui2.label('', title, ui2.rect(8, top + 28, math.max(w - 16, 0), 22), ui2.TextStyle{
			color: theme.foreground
			size:  14
			bold:  true
			align: .center
		})
		children << ui2.label('', size_text(frame), ui2.rect(8, top + 52, math.max(w - 16, 0),
			28), ui2.TextStyle{
			color:       tint
			size:        20
			bold:        true
			align:       .center
			font_family: 'Menlo'
		})
		children << ui2.label('', rules, ui2.rect(8, top + 82, math.max(w - 16, 0), 18), ui2.TextStyle{
			color: theme.muted_foreground
			size:  11.5
			align: .center
		})
	}
	return ui2.view('', frame, ui2.BoxStyle{ bg: bg }, children)
}

fn inner_config(state &App, frame ui2.Rect) ui2.ResizablePanelsConfig {
	theme := ui2.component_theme(state.dark)
	return ui2.ResizablePanelsConfig{
		id:     inner_id
		frame:  frame
		axis:   .vertical
		state:  state.inner
		panels: [
			ui2.ResizablePanel{
				key:      'preview'
				label:    'Preview'
				min_size: 120
				build:    fn [theme] (frame ui2.Rect) ui2.Element {
					return panel_card('Preview', 'photo', 'flexible · min 120', frame, theme.primary)
				}
			},
			ui2.ResizablePanel{
				key:            'console'
				label:          'Console'
				size:           170
				min_size:       90
				max_size:       320
				collapsible:    true
				collapsed_size: 28
				build:          fn [theme] (frame ui2.Rect) ui2.Element {
					return console_card(frame, theme)
				}
			},
		]
		theme:  theme
	}
}

// console_card shows the console, or the strip it collapses to.
fn console_card(frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	if frame.height < 40 {
		bg := mix(theme.background, theme.success, if app().dark { 0.16 } else { 0.07 })
		return ui2.view('', frame, ui2.BoxStyle{ bg: bg }, [
			symbol('chevron.up', ui2.rect(12, 8, 12, 12), theme.success),
			text('Console (collapsed): drag its divider up or press Enter on it', ui2.rect(32,
				0, math.max(frame.width - 40, 0), frame.height), theme.muted_foreground, 12, false),
		])
	}
	return panel_card('Console', 'chevron.right', '170 · min 90 · max 320 · collapsible',
		frame, theme.success)
}

fn outer_config(state &App, frame ui2.Rect) ui2.ResizablePanelsConfig {
	theme := ui2.component_theme(state.dark)
	return ui2.ResizablePanelsConfig{
		id:     outer_id
		frame:  frame
		state:  state.outer
		panels: [
			ui2.ResizablePanel{
				key:         'sidebar'
				label:       'Sidebar'
				size:        230
				min_size:    160
				max_size:    360
				collapsible: true
				build:       fn [theme] (frame ui2.Rect) ui2.Element {
					return panel_card('Sidebar', 'sidebar.right', '230 · min 160 · max 360 · collapsible',
						frame, theme.primary)
				}
			},
			ui2.ResizablePanel{
				key:      'main'
				label:    'Main'
				min_size: 240
				build:    fn [state] (frame ui2.Rect) ui2.Element {
					return ui2.resizable_panels(inner_config(state, frame)) or {
						ui2.view('', frame, ui2.BoxStyle{ transparent: true }, []ui2.Element{})
					}
				}
			},
			ui2.ResizablePanel{
				key:      'inspector'
				label:    'Inspector'
				size:     250
				min_size: 180
				fixed:    true
				visible:  state.show_inspector
				build:    fn [theme] (frame ui2.Rect) ui2.Element {
					return panel_card('Inspector', 'slider.horizontal.3', '250 · min 180 · fixed',
						frame, theme.warning)
				}
			},
		]
		theme:  theme
	}
}

fn resizable_frame() ui2.Rect {
	win := ui2.bounds()
	top := toolbar_height + 64
	return ui2.rect(20, top, math.max(win.width - 40, 0), math.max(win.height - top - status_height - 20,
		0))
}

fn resizable_page(state &App, theme ui2.ComponentTheme) []ui2.Element {
	frame := resizable_frame()
	win := ui2.bounds()
	sidebar_collapsed := state.outer.collapsed.len > 0 && state.outer.collapsed[0]
	mut children := [
		text('Resizable panels', ui2.rect(20, toolbar_height + 12, 300, 22), theme.foreground, 16,
			true),
		text('Drag a divider. Press one, then use the arrows, Home/End, or Enter to collapse.',
			ui2.rect(20, toolbar_height + 34, math.max(win.width - 480, 0), 18), theme.muted_foreground,
			12, false),
		ui2.styled_button(
			id:      'collapse-sidebar'
			frame:   ui2.rect(win.width - 440, toolbar_height + 16, 150, 28)
			label:   if sidebar_collapsed { 'Expand sidebar' } else { 'Collapse sidebar' }
			icon:    'sidebar.right'
			size:    .small
			outline: true
			theme:   theme
		) or { panic(err) },
		ui2.styled_button(
			id:      'toggle-inspector'
			frame:   ui2.rect(win.width - 282, toolbar_height + 16, 150, 28)
			label:   if state.show_inspector { 'Hide inspector' } else { 'Show inspector' }
			icon:    if state.show_inspector { 'eye.slash' } else { 'eye' }
			size:    .small
			outline: true
			theme:   theme
		) or { panic(err) },
		ui2.styled_button(
			id:      'reset-sizes'
			frame:   ui2.rect(win.width - 124, toolbar_height + 16, 104, 28)
			label:   'Reset'
			icon:    'arrow.uturn.backward'
			size:    .small
			outline: true
			theme:   theme
		) or { panic(err) },
	]
	// A border around the group, drawn as a border-colored box under it so the
	// corners stay round on every renderer.
	children << ui2.view('', ui2.rect(frame.x - 1, frame.y - 1, frame.width + 2, frame.height + 2),
		ui2.BoxStyle{
			bg:     theme.border
			radius: 2
		}, []ui2.Element{})
	children << ui2.resizable_panels(outer_config(state, frame)) or { panic(err) }
	return children
}

// ── Chrome ──────────────────────────────────────────────────────────

fn toolbar(state &App, theme ui2.ComponentTheme) []ui2.Element {
	win := ui2.bounds()
	bar_bg := mix(theme.background, theme.muted, 0.6)
	mut children := [
		ui2.view('toolbar', ui2.rect(0, 0, win.width, toolbar_height), ui2.BoxStyle{ bg: bar_bg },
			[
				fill(ui2.rect(0, toolbar_height - 1, win.width, 1), theme.border),
			]),
		symbol('square.stack.3d.up', ui2.rect(16, 13, 18, 18), theme.primary),
		text('Panels', ui2.rect(42, 0, 120, toolbar_height), theme.foreground, 15, true),
		ui2.button_group(
			id:    'page'
			frame: ui2.rect(130, 10, 220, 24)
			items: [
				ui2.ButtonGroupItem{
					value:    'workspace'
					label:    'Workspace'
					icon:     'rectangle.3.group'
					selected: state.page == .workspace
				},
				ui2.ButtonGroupItem{
					value:    'resizable'
					label:    'Resizable'
					icon:     'rectangle.split.3x1'
					selected: state.page == .resizable
				},
			]
			size:  .small
			theme: theme
		) or { panic(err) },
	]
	mut x := win.width - 16
	x -= 32
	children << ui2.toggle(
		id:                  'theme'
		frame:               ui2.rect(x, 10, 26, 24)
		icon:                if state.dark { 'sun.max' } else { 'moon' }
		pressed:             state.dark
		accessibility_label: 'Dark theme'
		size:                .small
		theme:               theme
	) or { panic(err) }
	if state.page == .workspace {
		for spec in [['reset', 'Reset', 'arrow.uturn.backward'],
			['restore', 'Restore', 'arrow.down.to.line'],
			['save', 'Save layout', 'square.and.arrow.down']] {
			width := ui2.styled_button_width(spec[1], spec[2], .small)
			x -= width + 8
			children << ui2.styled_button(
				id:      spec[0]
				frame:   ui2.rect(x, 10, width, 24)
				label:   spec[1]
				icon:    spec[2]
				enabled: spec[0] != 'restore' || state.saved.len > 0
				outline: true
				size:    .small
				theme:   theme
			) or { panic(err) }
		}
	}
	return children
}

fn status_bar(state &App, theme ui2.ComponentTheme) []ui2.Element {
	win := ui2.bounds()
	y := win.height - status_height
	bar_bg := mix(theme.background, theme.muted, 0.6)
	right := if state.page == .workspace && state.layout.zoomed.len > 0 {
		'zoomed ${state.layout.zoomed}'
	} else if state.page == .workspace {
		geometry := ui2.dock_area_layout(dock_config(state)) or { ui2.DockAreaLayout{} }
		mut parts := []string{}
		for placement in [ui2.DockPlacement.left, .bottom, .right] {
			if !state.layout.region(placement).has_panels() {
				continue
			}
			size := match placement {
				.left { geometry.left.width }
				.right { geometry.right.width }
				else { geometry.bottom.height }
			}
			shown := if ui2.dock_layout_is_open(state.layout, placement) {
				int(size).str()
			} else {
				'closed'
			}
			parts << '${placement.name()} ${shown}'
		}
		parts.join('  ·  ')
	} else {
		outer := ui2.resizable_panels_layout(outer_config(state, resizable_frame())) or {
			ui2.ResizableLayout{}
		}
		inner := ui2.resizable_panels_layout(inner_config(state, inner_frame(state))) or {
			ui2.ResizableLayout{}
		}
		'row ' + outer.sizes.map(int(math.round(it)).str()).join(' / ') + '  ·  column ' +
			inner.sizes.map(int(math.round(it)).str()).join(' / ')
	}
	return [
		ui2.view('status', ui2.rect(0, y, win.width, status_height), ui2.BoxStyle{ bg: bar_bg }, [
			fill(ui2.rect(0, 0, win.width, 1), theme.border),
			symbol('checkmark.circle', ui2.rect(12, 7, 13, 13), theme.success),
			text(state.status, ui2.rect(32, 1, math.max(win.width - 400, 0), status_height - 1),
				theme.muted_foreground, 12, false),
			ui2.label('', right, ui2.rect(win.width - 372, 1, 360, status_height - 1), ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
				align: .right
			}),
		]),
	]
}

fn build() ui2.Element {
	state := app()
	theme := ui2.component_theme(state.dark)
	mut children := []ui2.Element{}
	if state.page == .workspace {
		children << ui2.dock_area(dock_config(state)) or { panic(err) }
	} else {
		children << resizable_page(state, theme)
	}
	children << toolbar(state, theme)
	children << status_bar(state, theme)
	return ui2.screen(theme.background, children)
}

// ── Events ──────────────────────────────────────────────────────────

fn describe(e ui2.DockAreaEvent) string {
	return match e.kind {
		.activate { 'Showing ${e.panel}' }
		.close { 'Closed ${e.panel}' }
		.move { 'Moved ${e.panel} to the ${e.placement.title().to_lower()}' }
		.split { 'Split ${e.panel} into a group of its own' }
		.toggle_dock {
			verb := if ui2.dock_layout_is_open(e.layout, e.placement) { 'Opened' } else { 'Closed' }
			'${verb} the ${e.placement.title().to_lower()}'
		}
		.zoom {
			if e.layout.zoomed.len > 0 {
				'Zoomed ${e.layout.zoomed}; Escape zooms out'
			} else {
				'Zoomed out'
			}
		}
		.resize_end { 'Resized; the layout is saved with Save layout' }
		else { app().status }
	}
}

fn open_file(mut state App, name string) {
	state.selected = name
	if _ := ui2.dock_layout_find(state.layout, name) {
		if next := ui2.dock_layout_activate(state.layout, name) {
			state.layout = next
		}
	} else {
		state.layout = ui2.dock_layout_add(state.layout, name, .center)
	}
	state.dock = ui2.DockAreaState{
		...state.dock
		current: name
	}
	state.status = 'Opened ${name}'
}

fn apply_dock(mut state App, e ui2.DockAreaEvent) {
	state.layout = e.layout
	state.dock = e.state
	if e.kind == .menu_item {
		if e.item == 'copy-path' {
			path := 'src/' + e.panel
			ui2.set_clipboard_text(path)
			state.status = 'Copied ${path}'
		} else {
			state.selected = e.panel
			state.expanded['src'] = true
			state.status = 'Revealed ${e.panel} in the explorer'
		}
		return
	}
	if e.kind == .activate && e.panel in files {
		state.selected = e.panel
	}
	state.status = describe(e)
}

fn apply_resizable(mut state App, outer bool, step ui2.ResizablePanelsStep) {
	if outer {
		state.outer = step.state
		if step.kind == .resize_start {
			state.inner = ui2.ResizableState{
				...state.inner
				focused: -1
			}
		}
	} else {
		state.inner = step.state
		if step.kind == .resize_start {
			state.outer = ui2.ResizableState{
				...state.outer
				focused: -1
			}
		}
	}
	match step.kind {
		.collapse { state.status = 'Collapsed a panel; drag its divider back or press Enter' }
		.expand { state.status = 'Restored a panel' }
		.resize_end { state.status = 'Resized' }
		else {}
	}
}

fn inner_frame(state &App) ui2.Rect {
	l := ui2.resizable_panels_layout(outer_config(state, resizable_frame())) or { return ui2.Rect{} }
	f := l.frames[1]
	return ui2.rect(0, 0, f.width, f.height)
}

fn on_event(event string) {
	mut state := app()
	match event {
		'theme' {
			state.dark = !state.dark
		}
		'save' {
			state.saved = ui2.dock_layout_encode(state.layout)
			state.status = 'Saved the layout (${state.saved.len} bytes)'
		}
		'restore' {
			if restored := ui2.dock_layout_decode(state.saved) {
				if restored.version == layout_version {
					state.layout = ui2.dock_layout_retain(restored, panel_ids())
					state.dock = ui2.DockAreaState{}
					state.status = 'Restored the saved layout'
				}
			}
		}
		'reset' {
			state.layout = default_layout()
			state.dock = ui2.DockAreaState{
				current: 'main.v'
			}
			state.status = 'Reset the layout'
		}
		'collapse-sidebar' {
			if next := ui2.resizable_panels_toggle(outer_config(state, resizable_frame()), 0) {
				state.outer = next
			}
		}
		'toggle-inspector' {
			state.show_inspector = !state.show_inspector
		}
		'reset-sizes' {
			state.outer = ui2.ResizableState{}
			state.inner = ui2.ResizableState{}
			state.show_inspector = true
			state.status = 'Reset the panel sizes'
		}
		else {
			if event.starts_with('open:') {
				open_file(mut state, event['open:'.len..])
			} else if event.starts_with('folder:') {
				name := event['folder:'.len..]
				state.expanded[name] = !state.expanded[name]
			} else if value := ui2.button_group_value_from_action(ui2.ButtonGroupConfig{
				id:    'page'
				items: [ui2.ButtonGroupItem{
					value: 'workspace'
				}, ui2.ButtonGroupItem{
					value: 'resizable'
				}]
			}, event)
			{
				state.page = if value == 'resizable' { Page.resizable } else { Page.workspace }
			} else if state.page == .workspace {
				e := ui2.dock_area_event(dock_config(state), event) or { return }
				apply_dock(mut state, e)
			} else if step := ui2.resizable_panels_event(outer_config(state, resizable_frame()),
				event)
			{
				apply_resizable(mut state, true, step)
			} else if step := ui2.resizable_panels_event(inner_config(state, inner_frame(state)),
				event)
			{
				apply_resizable(mut state, false, step)
			} else {
				return
			}
		}
	}
	ui2.refresh()
}

fn on_key_event(event ui2.KeyEvent) {
	mut state := app()
	if state.page == .workspace {
		e := ui2.dock_area_key(dock_config(state), event) or { return }
		ui2.consume_key()
		apply_dock(mut state, e)
	} else if step := ui2.resizable_panels_key(outer_config(state, resizable_frame()), event) {
		ui2.consume_key()
		apply_resizable(mut state, true, step)
	} else if step := ui2.resizable_panels_key(inner_config(state, inner_frame(state)), event) {
		ui2.consume_key()
		apply_resizable(mut state, false, step)
	} else {
		return
	}
	ui2.refresh()
}

fn main() {
	mut state := app()
	state.layout = default_layout()
	state.dock = ui2.DockAreaState{
		current: 'main.v'
	}
	state.expanded['ui2-studio'] = true
	state.expanded['src'] = true
	// UI2_PANELS_PAGE=resizable opens the Resizable page first.
	if os.getenv('UI2_PANELS_PAGE') == 'resizable' {
		state.page = .resizable
	}
	if os.getenv('UI2_PANELS_DARK') == '1' {
		state.dark = true
	}
	ui2.on_key_event(on_key_event)
	ui2.run_window('UI2 Dock and Resizable Panels', 1280, 800, build, on_event)
}
