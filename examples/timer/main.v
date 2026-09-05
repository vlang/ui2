module main

import math
import time
import ui2

const timer_width = 600
const timer_height = 380
const timer_qml_source = $embed_file('timer.qml').to_string()
const timer_track_root_x = 52.0

@[heap]
pub struct TimerDemo {
pub mut:
	duration       f64 = 15
	duration_label string = '15 seconds'
	duration_ratio f64 = 0.5
	elapsed        f64
	elapsed_label  string = '0.0 s'
	progress       f64
	running        bool
	start_label    string = 'Start'
	status         string = 'Choose a duration, then start the timer.'
mut:
	started_at   i64
	base_elapsed f64
}

const timer_state = &TimerDemo{}

fn (mut app TimerDemo) update_labels() {
	app.duration_label = '${int(math.round(app.duration))} seconds'
	app.duration_ratio = app.duration / 30.0
	app.elapsed_label = '${app.elapsed:.1f} s'
	app.progress = if app.duration <= 0 { 1.0 } else { app.elapsed / app.duration }
	if app.progress > 1 {
		app.progress = 1
	}
}

fn (mut app TimerDemo) set_duration_fraction(fraction f64) {
	clamped := math.max(0.0, math.min(1.0, fraction))
	app.duration = math.round(clamped * 29.0 + 1.0)
	if app.elapsed > app.duration {
		app.elapsed = app.duration
		app.base_elapsed = app.elapsed
		app.running = false
		app.start_label = 'Restart'
		app.status = 'Timer complete.'
	} else {
		app.status = 'Duration set to ${int(app.duration)} seconds.'
	}
	app.update_labels()
}

fn (mut app TimerDemo) start_at(now i64) {
	app.elapsed = 0
	app.base_elapsed = 0
	app.started_at = now
	app.running = true
	app.start_label = 'Restart'
	app.status = 'Timer running…'
	app.update_labels()
}

fn (mut app TimerDemo) pause_at(now i64) {
	app.sync_at(now)
	if app.running {
		app.base_elapsed = app.elapsed
		app.running = false
		app.start_label = 'Restart'
		app.status = 'Timer paused.'
	}
}

fn (mut app TimerDemo) resume_at(now i64) {
	if app.elapsed >= app.duration {
		app.start_at(now)
		return
	}
	app.base_elapsed = app.elapsed
	app.started_at = now
	app.running = true
	app.start_label = 'Restart'
	app.status = 'Timer running…'
}

fn (mut app TimerDemo) sync_at(now i64) {
	if !app.running {
		app.update_labels()
		return
	}
	app.elapsed = app.base_elapsed + f64(now - app.started_at) / 1000.0
	if app.elapsed >= app.duration {
		app.elapsed = app.duration
		app.base_elapsed = app.elapsed
		app.running = false
		app.start_label = 'Restart'
		app.status = 'Timer complete.'
	}
	app.update_labels()
}

fn refresh_timer_for_duration() {
	for _ in 0 .. 620 {
		time.sleep(50 * time.millisecond)
		ui2.request_refresh()
	}
}

fn timer_pointer_x(event string) ?f64 {
	parts := event.split(':')
	if parts.len < 5 || parts[0] != 'pointer' || parts[2] != 'duration_track' {
		return none
	}
	return parts[3].f64()
}

fn build_timer_screen() ui2.Element {
	mut state := unsafe { timer_state }
	state.sync_at(time.ticks())
	return ui2.element_from_qml_model(timer_qml_source, *state, ui2.bounds()) or {
		eprintln('timer QML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_timer_event(event string) {
	mut state := unsafe { timer_state }
	match event {
		'start' {
			state.start_at(time.ticks())
			spawn refresh_timer_for_duration()
		}
		'pause' {
			if state.running {
				state.pause_at(time.ticks())
			} else {
				state.resume_at(time.ticks())
				spawn refresh_timer_for_duration()
			}
		}
		else {
			x := timer_pointer_x(event) or { return }
			track_width := ui2.bounds().width - 104.0
			state.set_duration_fraction((x - timer_track_root_x) / track_width)
		}
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('Timer', timer_width, timer_height, build_timer_screen, handle_timer_event)
}
