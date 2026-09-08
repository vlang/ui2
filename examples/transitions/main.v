module main

import math
import ui2

const transitions_width = 640
const transitions_height = 500
const transitions_vml_source = $embed_file('transitions.vml').to_string()
const transition_logo_size = 82.0

@[heap]
pub struct TransitionsDemo {
pub mut:
	progress     f64
	moving       bool
	target_label string = 'Top left'
	status       string = 'Press Slide to move through the canvas.'
mut:
	target_x     f64 = 24
	target_y     f64 = 24
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

fn (mut app TransitionsDemo) select_target(stage_width f64, stage_height f64) {
	app.target_index = (app.target_index + 1) % 5
	app.target_x, app.target_y, app.target_label = transition_target(app.target_index, stage_width, stage_height)
	app.progress = 0
	app.moving = true
	app.status = 'Moving to ${app.target_label.to_lower()}…'
}

fn transition_animation_event(event ui2.AnimationEvent) {
	mut state := unsafe { transitions_state }
	match event.kind {
		.progress {
			state.progress = event.progress
		}
		.complete {
			state.progress = 1
			state.moving = false
			state.status = 'Arrived at ${state.target_label.to_lower()}.'
		}
		else {}
	}
}

fn transition_stage_size(frame ui2.Rect) (f64, f64) {
	return frame.width - 68.0, frame.height - 178.0
}

fn build_transitions_screen() ui2.Element {
	mut state := unsafe { transitions_state }
	info := ui2.animation_info('moving_tile')
	if info.status == .running {
		state.progress = info.progress
	}
	return ui2.element_from_vml_model(transitions_vml_source, *state, ui2.bounds()) or {
		eprintln('transitions VML failed: ${err}')
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
	state.select_target(stage_width, stage_height)
	ui2.animation(
		duration: 0.75
		transition: .in_out_cubic
		x: state.target_x
		y: state.target_y
		on_event: transition_animation_event
	).start('moving_tile')
	ui2.refresh()
}

fn main() {
	ui2.run_window('Transitions', transitions_width, transitions_height, build_transitions_screen, handle_transitions_event)
}
