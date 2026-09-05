module main

import ui2

const demo_event_width = 680
const demo_event_height = 500
const demo_event_qml_source = $embed_file('demo_event.qml').to_string()

@[heap]
pub struct DemoEvent {
pub mut:
	last_event     string = 'Interact with the blue surface or press a key.'
	history        string
	pointer_events int
	key_events     int
}

const demo_event_state = &DemoEvent{}

fn (mut app DemoEvent) append_history(line string) {
	mut lines := if app.history.len == 0 { []string{} } else { app.history.split_into_lines() }
	lines.insert(0, line)
	if lines.len > 10 {
		lines = lines[..10].clone()
	}
	app.history = lines.join('\n')
}

fn (mut app DemoEvent) record_event(event string) {
	if event == 'clear' {
		app.last_event = 'Event log cleared.'
		app.history = ''
		app.pointer_events = 0
		app.key_events = 0
		return
	}
	if event == 'sample_button' {
		app.last_event = 'Native button tapped.'
		app.append_history(app.last_event)
		return
	}
	if event.starts_with('pointer:') {
		parts := event.split(':')
		if parts.len >= 5 {
			app.last_event = 'Pointer ${parts[1]} at (${parts[3]}, ${parts[4]}).'
		} else {
			app.last_event = event
		}
		app.pointer_events++
		app.append_history(app.last_event)
	}
}

fn (mut app DemoEvent) record_key(key string) {
	app.last_event = 'Key: ${key}'
	app.key_events++
	app.append_history(app.last_event)
}

fn build_demo_event_screen() ui2.Element {
	state := unsafe { demo_event_state }
	return ui2.element_from_qml_model(demo_event_qml_source, *state, ui2.bounds()) or {
		eprintln('event-demo QML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_demo_event(event string) {
	mut state := unsafe { demo_event_state }
	state.record_event(event)
	ui2.refresh()
}

fn handle_demo_key(key string) {
	mut state := unsafe { demo_event_state }
	state.record_key(key)
	ui2.refresh()
}

fn main() {
	ui2.on_key(handle_demo_key)
	ui2.run_window('Event Inspector', demo_event_width, demo_event_height, build_demo_event_screen, handle_demo_event)
}
