module main

import ui2

const columns_window_width = 720
const columns_window_height = 440
const columns_toolbar_height = 48
const columns_column_width = 190
const columns_row_height = 28
const columns_max_depth = 12
const columns_names = ['Applications', 'Archive', 'Desktop', 'Documents', 'Downloads', 'Library',
	'Movies', 'Music', 'Pictures', 'Projects', 'Public', 'Sites', 'Templates', 'Work']

// ColumnBrowser is a path through a made-up folder tree: one chosen row per
// column, with the column after the last choice listing what that folder holds.
struct ColumnBrowser {
mut:
	selected []int
}

const column_browser = &ColumnBrowser{
	selected: [3, 2, 6, 1]
}

// folder_names lists a folder's children. The tree is generated rather than
// stored, so every folder has contents and the columns can go on opening.
fn folder_names(depth int, parent int) []string {
	count := 8 + (depth * 5 + parent * 3) % 12
	mut names := []string{cap: count}
	for index in 0 .. count {
		names << columns_names[(index + depth * 3 + parent) % columns_names.len]
	}
	return names
}

fn (browser &ColumnBrowser) column_count() int {
	return browser.selected.len + 1
}

fn (browser &ColumnBrowser) content_width() f64 {
	return f64(browser.column_count() * columns_column_width)
}

fn (browser &ColumnBrowser) path() string {
	mut parts := []string{}
	for depth, row in browser.selected {
		parent := if depth == 0 { 0 } else { browser.selected[depth - 1] }
		parts << folder_names(depth, parent)[row]
	}
	return '/' + parts.join('/')
}

// open chooses a row, which drops every column to its right and opens the
// chosen folder in a new one.
fn (mut browser ColumnBrowser) open(column int, row int) {
	if column < 0 || column > browser.selected.len || column >= columns_max_depth {
		return
	}
	parent := if column == 0 { 0 } else { browser.selected[column - 1] }
	if row < 0 || row >= folder_names(column, parent).len {
		return
	}
	browser.selected = browser.selected[..column].clone()
	browser.selected << row
}

fn column_rows(browser &ColumnBrowser, column int) []ui2.Element {
	parent := if column == 0 { 0 } else { browser.selected[column - 1] }
	mut rows := []ui2.Element{}
	for row, name in folder_names(column, parent) {
		chosen := column < browser.selected.len && browser.selected[column] == row
		rows << ui2.button('open:${column}:${row}', name, ui2.rect(0, row * columns_row_height,
			columns_column_width - 1, columns_row_height), ui2.BoxStyle{
			bg: if chosen { u32(0x2563eb) } else { u32(0xffffff) }
		}, ui2.TextStyle{
			color: if chosen { u32(0xffffff) } else { u32(0x1e293b) }
			size:  13
			align: .center
		})
	}
	return rows
}

fn browser_screen(browser &ColumnBrowser, bounds ui2.Rect) ui2.Element {
	pane_height := bounds.height - columns_toolbar_height
	mut columns := []ui2.Element{}
	for column in 0 .. browser.column_count() {
		x := f64(column * columns_column_width)
		// Each column scrolls its own rows; the strip they sit in scrolls sideways.
		columns << ui2.scroll('column_${column}', ui2.rect(x, 0, columns_column_width - 1,
			pane_height), 0xffffff, column_rows(browser, column))
		columns << ui2.view('', ui2.rect(x + columns_column_width - 1, 0, 1, pane_height),
			ui2.BoxStyle{
			bg: 0xe2e8f0
		}, [])
	}
	button_box := ui2.BoxStyle{
		bg:     0xe2e8f0
		radius: 6
	}
	button_text := ui2.TextStyle{
		color: 0x1e293b
		size:  13
		align: .center
	}
	return ui2.screen(0xf8fafc, [
		ui2.button('first', 'First', ui2.rect(12, 10, 64, 28), button_box, button_text),
		ui2.button('last', 'Last', ui2.rect(84, 10, 64, 28), button_box, button_text),
		ui2.label('path', browser.path(), ui2.rect(164, 0, bounds.width - 176, columns_toolbar_height),
			ui2.TextStyle{
			color: 0x475569
			size:  13
		}),
		ui2.scroll_with_mode('columns', ui2.rect(0, columns_toolbar_height, bounds.width,
			pane_height), 0xffffff, .horizontal_only, columns),
	])
}

fn build_browser() ui2.Element {
	return browser_screen(column_browser, ui2.bounds())
}

fn handle_browser_event(event string) {
	mut browser := unsafe { column_browser }
	match event {
		'first' {
			ui2.scroll_to_horizontal_offset('columns', 0)
		}
		'last' {
			ui2.scroll_to_horizontal_offset('columns', browser.content_width())
		}
		else {
			if !event.starts_with('open:') {
				return
			}
			parts := event.split(':')
			browser.open(parts[1].int(), parts[2].int())
			// The column just opened lies past the old end of the strip, so ask for
			// the far end once the tree has it.
			ui2.refresh()
			ui2.scroll_to_horizontal_offset('columns', browser.content_width())
		}
	}
}

fn main() {
	// Asked before the window exists: the strip opens on its deepest column.
	ui2.scroll_to_horizontal_offset('columns', column_browser.content_width())
	ui2.run_window('Horizontal Scroll', columns_window_width, columns_window_height, build_browser,
		handle_browser_event)
}
