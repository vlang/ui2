module main

import ui2

const custom_window_width = 440
const custom_window_height = 210
const custom_window_qml_source = $embed_file('custom_window.qml').to_string()

@[heap]
pub struct CustomWindowDemo {
pub mut:
	completed          int
	completed_label    string = 'Nothing completed yet'
	platform_note      string
	transparent_screen bool
	screen_background  string = '#0F172A'
mut:
	window_ready bool
}

const custom_window_state = &CustomWindowDemo{}

fn (mut app CustomWindowDemo) prepare_window() {
	if !app.window_ready {
		app.window_ready = configure_custom_window()
		if !app.window_ready {
			ui2.request_refresh()
		}
	}
	app.transparent_screen = custom_window_uses_transparent_screen()
	app.screen_background = custom_window_screen_background()
	app.platform_note = custom_window_platform_note()
}

pub fn (mut app CustomWindowDemo) add_completed() {
	app.completed++
	app.update_completed_label()
}

pub fn (mut app CustomWindowDemo) remove_completed() {
	if app.completed > 0 {
		app.completed--
	}
	app.update_completed_label()
}

pub fn (mut app CustomWindowDemo) reset() {
	app.completed = 0
	app.update_completed_label()
}

fn (mut app CustomWindowDemo) update_completed_label() {
	app.completed_label = match app.completed {
		0 { 'Nothing completed yet' }
		1 { '1 focus session completed' }
		else { '${app.completed} focus sessions completed' }
	}
}

fn custom_window_pointer(raw string) ?(string, string) {
	parts := raw.split(':')
	if parts.len < 3 || parts[0] != 'pointer' {
		return none
	}
	return parts[1], parts[2]
}

fn build_custom_window_screen() ui2.Element {
	mut state := unsafe { custom_window_state }
	state.prepare_window()
	return ui2.element_from_qml_model(custom_window_qml_source, *state, ui2.bounds()) or {
		eprintln('custom-window QML failed: ${err}')
		ui2.screen(0x0f172a, [])
	}
}

fn handle_custom_window_event(event string) {
	mut state := unsafe { custom_window_state }
	match event {
		'increment' { state.add_completed() }
		'decrement' { state.remove_completed() }
		'reset' { state.reset() }
		'close' {
			ui2.quit()
			return
		}
		else {
			phase, id := custom_window_pointer(event) or { return }
			if phase == 'down' && id == 'window_drag' {
				drag_custom_window()
			}
		}
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('ui2 custom window', custom_window_width, custom_window_height, build_custom_window_screen, handle_custom_window_event)
}
