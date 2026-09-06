// A status area ("system tray") icon with its own menu.
//
// set_tray docks an icon in the menu bar's status area on macOS and in the
// notification area on Windows; clicking it opens the declared menu, whose
// rows emit through the same event handler run_window was given. remove_tray
// takes it away again.
//
// The custom renderer draws inside its own window and owns nothing outside it,
// so tray_supported is false there. This example keeps working: the same rows
// are offered as buttons in the window, bound to the very same action ids.
module main

import ui2

const tray_icon_width = 640
const tray_icon_height = 460
const tray_icon_qml_source = $embed_file('tray_icon.qml').to_string()

const tray_statuses = ['Available', 'Busy', 'Away']

@[heap]
pub struct TrayDemo {
pub mut:
	docked        bool = true
	status        string = 'Available'
	notifications bool = true
	last_action   string = 'Open the tray menu from the status area.'
	log           string
	opened        int
	supported     bool
	backend_note  string
}

const tray_demo_state = &TrayDemo{}

// tray_config is a function of the model rather than a constant: the status
// rows and the notifications row show their state as a check mark, so the
// declaration is installed again whenever one of them changes.
pub fn (app &TrayDemo) tray_config() ui2.TrayConfig {
	mut statuses := []ui2.MenuItem{cap: tray_statuses.len}
	for status in tray_statuses {
		statuses << ui2.menu_check_item('status_${status.to_lower()}', status, app.status == status)
	}
	return ui2.TrayConfig{
		// The title keeps the item visible even where the icon cannot be
		// resolved; the id is only reached by a tray with no menu at all.
		id: 'tray_clicked'
		title: 'ui2'
		icon: 'symbol:cup.and.saucer.fill'
		tooltip: 'ui2 tray demo — ${app.status}'
		menu: [
			ui2.menu_item('tray_status', 'Show current status'),
			ui2.menu_separator(),
			ui2.submenu('Set status', statuses),
			ui2.menu_check_item('tray_notifications', 'Notifications', app.notifications),
			ui2.menu_separator(),
			ui2.menu_item('tray_hide', 'Hide tray icon'),
			ui2.menu_item('tray_quit', 'Quit'),
		]
	}
}

// choose applies one tray row and reports whether the id belonged to the tray
// menu. `tray_quit` is answered by the caller, which owns the window.
pub fn (mut app TrayDemo) choose(id string) bool {
	mut detail := ''
	match id {
		'tray_clicked' {
			detail = 'Tray icon clicked.'
		}
		'tray_status' {
			detail = 'Status is ${app.status}, notifications ${on_off(app.notifications)}.'
		}
		'tray_notifications' {
			app.notifications = !app.notifications
			detail = 'Notifications turned ${on_off(app.notifications)}.'
		}
		'tray_hide' {
			app.docked = false
			detail = 'Tray icon hidden.'
		}
		'tray_show' {
			// Docking is only ever real where there is a status area, so say so
			// rather than claiming an icon nobody can see.
			app.docked = app.supported
			detail = if app.supported {
				'Tray icon docked again.'
			} else {
				'This backend has no status area to dock into.'
			}
		}
		'tray_quit' {
			detail = 'Quitting.'
		}
		else {
			status := tray_status_from_id(id) or { return false }
			app.status = status
			detail = 'Status set to ${status}.'
		}
	}
	app.opened++
	app.last_action = detail
	app.prepend_log('${app.opened:2}. ${detail}')
	return true
}

// tray_status_from_id maps a `Set status` row back onto its status name.
pub fn tray_status_from_id(id string) ?string {
	for status in tray_statuses {
		if id == 'status_${status.to_lower()}' {
			return status
		}
	}
	return none
}

// tray_rows_changed reports whether the row that just ran shows state in the
// menu, which is when the declaration has to be installed again.
pub fn tray_rows_changed(id string) bool {
	return id == 'tray_notifications' || tray_status_from_id(id) != none
}

fn (mut app TrayDemo) prepend_log(line string) {
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

fn build_tray_icon_screen() ui2.Element {
	state := unsafe { tray_demo_state }
	return ui2.element_from_qml_model(tray_icon_qml_source, *state, ui2.bounds()) or {
		eprintln('tray QML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_tray_icon_event(event string) {
	mut state := unsafe { tray_demo_state }
	if !state.choose(event) {
		return
	}
	if event == 'tray_quit' {
		ui2.remove_tray()
		ui2.quit()
		return
	}
	// Docking and the check marks both live in the declaration, so re-install
	// it rather than trying to patch the native menu in place.
	if state.docked {
		ui2.set_tray(state.tray_config())
	} else {
		ui2.remove_tray()
	}
	ui2.refresh()
}

fn main() {
	mut state := unsafe { tray_demo_state }
	state.supported = ui2.tray_supported()
	state.backend_note = if state.supported {
		'Click the ui2 item in the status area to open its menu.'
	} else {
		'This backend has no status area, so the same rows are offered below.'
	}
	if !state.supported {
		state.docked = false
		state.last_action = 'No status area on this backend.'
	}
	// Declaring the tray before the window exists is fine: it is docked as
	// soon as the application is up.
	if state.docked {
		ui2.set_tray(state.tray_config())
	}
	ui2.run_window('Tray Icon', tray_icon_width, tray_icon_height, build_tray_icon_screen,
		handle_tray_icon_event)
}
