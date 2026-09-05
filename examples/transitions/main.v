module main

import math
import time
import ui2

const transitions_width = 640
const transitions_height = 500
const transitions_qml_source = $embed_file('transitions.qml').to_string()
const transition_logo_size = 82.0

@[heap]
pub struct TransitionsDemo {
pub mut:
	x            f64 = 24
	y            f64 = 24
	progress     f64
	moving       bool
	target_label string = 'Top left'
	status       string = 'Press Slide to move through the canvas.'
mut:
	start_x      f64
	start_y      f64
	target_x     f64 = 24
	target_y     f64 = 24
	started_at   i64
	duration_ms  i64 = 750
	target_index int
}

const transitions_state = &TransitionsDemo{}

fn transition_target(index int, width f64, height f64) (f64, f64, string) {
	max_x := math.max(24.0, width - transition_logo_size - 24.0)
	max_y := math.max(24.0, height - transition_logo_size - 24.0)
	return match index {
		1 { max_x, max_y, 'Bottom right' }
		2 { max_x, 24.0, 'Top right' }
		3 { 24.0, max_y, 'Bottom left' }
		4 { (width - transition_logo_size) / 2.0, (height - transition_logo_size) / 2.0, 'Center' }
		else { 24.0, 24.0, 'Top left' }
	}
}

fn transition_ease(value f64) f64 {
	t := math.max(0.0, math.min(1.0, value))
	return if t < 0.5 { 4.0 * t * t * t } else { 1.0 - math.pow(-2.0 * t + 2.0, 3) / 2.0 }
}

fn (mut app TransitionsDemo) sync_at(now i64) {
	if !app.moving {
		return
	}
	raw := f64(now - app.started_at) / f64(app.duration_ms)
	app.progress = math.max(0.0, math.min(1.0, raw))
	eased := transition_ease(app.progress)
	app.x = app.start_x + (app.target_x - app.start_x) * eased
	app.y = app.start_y + (app.target_y - app.start_y) * eased
	if raw >= 1 {
		app.x = app.target_x
		app.y = app.target_y
		app.progress = 1
		app.moving = false
		app.status = 'Arrived at ${app.target_label.to_lower()}.'
	}
}

fn (mut app TransitionsDemo) begin_at(now i64, stage_width f64, stage_height f64) {
	app.sync_at(now)
	app.start_x = app.x
	app.start_y = app.y
	app.target_index = (app.target_index + 1) % 5
	app.target_x, app.target_y, app.target_label = transition_target(app.target_index, stage_width, stage_height)
	app.started_at = now
	app.progress = 0
	app.moving = true
	app.status = 'Moving to ${app.target_label.to_lower()}…'
}

fn refresh_transition() {
	for _ in 0 .. 55 {
		time.sleep(16 * time.millisecond)
		ui2.request_refresh()
	}
}

fn transition_stage_size(frame ui2.Rect) (f64, f64) {
	return frame.width - 68.0, frame.height - 178.0
}

fn build_transitions_screen() ui2.Element {
	mut state := unsafe { transitions_state }
	state.sync_at(time.ticks())
	return ui2.element_from_qml_model(transitions_qml_source, *state, ui2.bounds()) or {
		eprintln('transitions QML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_transitions_event(event string) {
	if event != 'slide' {
		return
	}
	frame := ui2.bounds()
	stage_width, stage_height := transition_stage_size(frame)
	mut state := unsafe { transitions_state }
	state.begin_at(time.ticks(), stage_width, stage_height)
	spawn refresh_transition()
	ui2.refresh()
}

fn main() {
	ui2.run_window('Transitions', transitions_width, transitions_height, build_transitions_screen, handle_transitions_event)
}
