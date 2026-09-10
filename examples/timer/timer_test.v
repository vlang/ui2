module main

import ui2

fn find_timer_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_timer_element(child, id) {
			return found
		}
	}
	return none
}

fn test_timer_tracks_elapsed_pause_resume_and_completion() {
	mut app := TimerDemo{ duration: 10 }
	app.start_at(1_000)
	app.sync_at(3_500)
	assert app.running
	assert app.elapsed == 2.5
	assert app.progress == 0.25
	app.pause_at(4_000)
	assert !app.running
	assert app.elapsed == 3
	app.resume_at(5_000)
	app.sync_at(12_000)
	assert !app.running
	assert app.elapsed == 10
	assert app.status == 'Timer complete.'
}

fn test_timer_duration_mapping_and_vml_controls() {
	mut app := TimerDemo{}
	app.set_duration_fraction(0)
	assert app.duration == 1
	app.set_duration_fraction(1)
	assert app.duration == 30
	root := ui2.element_from_vml_model(timer_vml_source, app, ui2.rect(0, 0, timer_width, timer_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	progress := find_timer_element(root, 'elapsed_progress') or { panic('missing progress bar') }
	assert progress.accessibility_role == 'progressbar'
	assert progress.accessibility_label == 'Elapsed time'
	assert progress.children.len == 1
	assert progress.children[0].frame.width == 0
	slider := find_timer_element(root, 'duration_slider') or { panic('missing duration slider') }
	assert slider.kind == .slider
	assert slider.min_value == 1
	assert slider.max_value == 30
	assert slider.step == 1
	assert slider.accessibility_label == 'Timer duration'
	assert (find_timer_element(root, 'start') or { panic('missing start') }).native_style
}
