// A window with a top level menu bar.
//
// set_menu_bar hands ui2 a plain declaration; the backend turns it into the
// system menu bar on macOS, the window's own menu bar on Windows, and a bar
// the custom renderer draws across the top of the window on Linux. Rows emit
// through the same event handler run_window was given, so a menu row and a
// button in the window can run the same code.
//
// Rows with a check mark hold declared state, not remembered state: after
// toggling one the menu bar is installed again with the new value.
module main

import ui2

const menubar_width = 660
const menubar_height = 470
const menubar_vml_source = $embed_file('menubar.vml').to_string()

// menubar_action_titles is what each row is called in the log. Every row of
// the declaration below has an entry, so an id that is missing here is a typo
// rather than a silent no-op.
const menubar_action_titles = {
	'file_new':      'New Note'
	'file_open':     'Open…'
	'file_save':     'Save'
	'file_revert':   'Revert'
	'file_close':    'Close Window'
	'edit_undo':     'Undo'
	'edit_redo':     'Redo'
	'find_open':     'Find…'
	'find_next':     'Find Next'
	'find_previous': 'Find Previous'
	'view_details':  'Show Details'
	'view_wrap':     'Word Wrap'
	'zoom_in':       'Zoom In'
	'zoom_out':      'Zoom Out'
	'zoom_reset':    'Actual Size'
	'help_about':    'About This Demo'
}

@[heap]
pub struct MenubarDemo {
pub mut:
	last_action  string = 'Choose something from the menu bar.'
	log          string
	chosen       int
	show_details bool = true
	word_wrap    bool
	zoom         int = 100
	backend_note string
}

const menubar_state = &MenubarDemo{}

// menus is the whole declaration. It is a function of the model rather than a
// constant because the two View rows show their state as a check mark.
pub fn (app &MenubarDemo) menus() []ui2.Menu {
	return [
		ui2.Menu{
			title: 'File'
			items: [
				ui2.menu_item_with_shortcut('file_new', 'New Note', 'cmd+n'),
				ui2.menu_item_with_shortcut('file_open', 'Open…', 'cmd+o'),
				ui2.menu_separator(),
				ui2.menu_item_with_shortcut('file_save', 'Save', 'cmd+s'),
				ui2.disabled(ui2.menu_item('file_revert', 'Revert')),
				ui2.menu_separator(),
				ui2.menu_item_with_shortcut('file_close', 'Close Window', 'cmd+w'),
			]
		},
		ui2.Menu{
			title: 'Edit'
			items: [
				ui2.menu_item_with_shortcut('edit_undo', 'Undo', 'cmd+z'),
				ui2.menu_item_with_shortcut('edit_redo', 'Redo', 'cmd+shift+z'),
				ui2.menu_separator(),
				ui2.submenu('Find', [
					ui2.menu_item_with_shortcut('find_open', 'Find…', 'cmd+f'),
					ui2.menu_item_with_shortcut('find_next', 'Find Next', 'cmd+g'),
					ui2.menu_item_with_shortcut('find_previous', 'Find Previous', 'cmd+shift+g'),
				]),
			]
		},
		ui2.Menu{
			title: 'View'
			items: [
				ui2.menu_check_item('view_details', 'Show Details', app.show_details),
				ui2.menu_check_item('view_wrap', 'Word Wrap', app.word_wrap),
				ui2.menu_separator(),
				ui2.submenu('Zoom', [
					ui2.menu_item_with_shortcut('zoom_in', 'Zoom In', 'cmd+='),
					ui2.menu_item_with_shortcut('zoom_out', 'Zoom Out', 'cmd+-'),
					ui2.menu_item_with_shortcut('zoom_reset', 'Actual Size', 'cmd+0'),
				]),
			]
		},
		ui2.Menu{
			title: 'Help'
			items: [
				ui2.menu_item('help_about', 'About This Demo'),
			]
		},
	]
}

// choose applies one menu row and reports whether the id belonged to the menu
// bar at all, so the window's own buttons can be told apart from it.
pub fn (mut app MenubarDemo) choose(id string) bool {
	title := menubar_action_titles[id] or { return false }
	app.chosen++
	mut detail := title
	match id {
		'view_details' {
			app.show_details = !app.show_details
			detail = '${title} is now ${on_off(app.show_details)}'
		}
		'view_wrap' {
			app.word_wrap = !app.word_wrap
			detail = '${title} is now ${on_off(app.word_wrap)}'
		}
		'zoom_in' {
			app.zoom = if app.zoom < 200 { app.zoom + 10 } else { 200 }
			detail = 'Zoomed to ${app.zoom}%'
		}
		'zoom_out' {
			app.zoom = if app.zoom > 50 { app.zoom - 10 } else { 50 }
			detail = 'Zoomed to ${app.zoom}%'
		}
		'zoom_reset' {
			app.zoom = 100
			detail = 'Zoom reset to 100%'
		}
		else {}
	}
	app.last_action = detail
	app.prepend_log('${app.chosen:2}. ${detail}')
	return true
}

pub fn (mut app MenubarDemo) reset() {
	app.chosen = 0
	app.log = ''
	app.last_action = 'Choose something from the menu bar.'
}

// menu_bar_rows_changed reports whether the row that just ran shows state in
// the menu, which is when the declaration has to be installed again.
pub fn menu_bar_rows_changed(id string) bool {
	return id in ['view_details', 'view_wrap']
}

fn (mut app MenubarDemo) prepend_log(line string) {
	mut lines := if app.log.len == 0 { []string{} } else { app.log.split_into_lines() }
	lines.insert(0, line)
	if lines.len > 12 {
		lines = lines[..12].clone()
	}
	app.log = lines.join('\n')
}

fn on_off(value bool) string {
	return if value { 'on' } else { 'off' }
}

fn build_menubar_screen() ui2.Element {
	state := unsafe { menubar_state }
	return ui2.element_from_vml_model(menubar_vml_source, *state, ui2.bounds()) or {
		eprintln('menubar VML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_menubar_event(event string) {
	mut state := unsafe { menubar_state }
	if event == 'reset' {
		state.reset()
	} else if state.choose(event) && menu_bar_rows_changed(event) {
		// The check marks live in the declaration, so re-install it.
		ui2.set_menu_bar(state.menus())
	}
	ui2.refresh()
}

fn main() {
	mut state := unsafe { menubar_state }
	state.backend_note = if ui2.menu_bar_supported() {
		'This backend has a real menu bar.'
	} else {
		'This backend has no menu bar; the declaration is ignored.'
	}
	// Declaring the menu bar before the window exists is fine: it is installed
	// as soon as there is something to attach it to.
	ui2.set_menu_bar(state.menus())
	ui2.run_window('Menu Bar', menubar_width, menubar_height, build_menubar_screen, handle_menubar_event)
}
