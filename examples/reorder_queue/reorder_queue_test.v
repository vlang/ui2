module main

import ui2

fn queue_test_pointer(phase string, key string, x f64, y f64) string {
	action := ui2.reorder_item_action(queue_id, key)
	return 'pointer:${phase}:${action}:${x}:${y}'
}

fn queue_test_keys(app QueueDemo) []string {
	mut keys := []string{}
	for job in app.jobs {
		keys << job.key
	}
	return keys
}

// queue_test_drop presses a job at (x, y), drags it by travel and releases it.
fn queue_test_drop(mut app QueueDemo, key string, x f64, y f64, travel f64) {
	app.handle_event(queue_test_pointer('down', key, x, y))
	app.handle_event(queue_test_pointer('drag', key, x, y + travel))
	app.handle_event(queue_test_pointer('up', key, x, y + travel))
}

fn test_queue_builds_a_scrolling_list_of_draggable_jobs() {
	app := initial_queue()
	assert app.config().items.len == 7
	root := ui2.reorder_container(app.config()) or { panic(err) }
	assert root.accessibility_role == 'list'
	// Seven 52 point jobs with gaps do not fit the 300 point frame, so the list scrolls.
	assert root.children[0].kind == .scroll
}

fn test_queue_drag_moves_a_job_and_reports_it() {
	mut app := initial_queue()
	// Press the manual, which sits 190 points into the queue, and drag it up past the report.
	queue_test_drop(mut app, 'manual', 100, queue_frame.y + 190, -150)
	assert queue_test_keys(app) == ['report', 'manual', 'invoice', 'poster', 'agenda', 'labels',
		'notes']
	assert app.status == 'Moved Printer manual.pdf to position 2.'
	assert app.state.drag.item == ''
	assert app.state.active == 'manual'
}

fn test_queue_click_selects_and_alt_arrows_nudge_the_selection() {
	mut app := initial_queue()
	y := queue_frame.y + 244 + 26
	app.handle_event(queue_test_pointer('down', 'agenda', 100, y))
	app.handle_event(queue_test_pointer('up', 'agenda', 100, y))
	assert app.state.active == 'agenda'
	assert app.status == 'Selected Board agenda.docx. Alt+Up and Alt+Down move it.'
	up := app.handle_key(ui2.KeyEvent{
		code: .up
		alt:  true
	}) or { panic('key ignored') }
	assert up.moved && up.reveal
	assert queue_test_keys(app) == ['report', 'invoice', 'poster', 'agenda', 'manual', 'labels',
		'notes']
	_ := app.handle_key(ui2.KeyEvent{
		code: .home
		alt:  true
	}) or { panic('key ignored') }
	assert queue_test_keys(app)[0] == 'agenda'
	// End sends it to the bottom, and the reveal offset scrolls the list to show it.
	_ := app.handle_key(ui2.KeyEvent{
		code: .end
		alt:  true
	}) or { panic('key ignored') }
	assert queue_test_keys(app)[6] == 'agenda'
	offset := ui2.reorder_reveal_offset(app.config(), app.state.active) or { panic('no offset') }
	assert offset == 120
	// Without a selection the keys are not ours.
	app.state = ui2.ReorderState{}
	assert app.handle_key(ui2.KeyEvent{
		code: .down
		alt:  true
	}) == none
}

fn test_queue_remove_takes_a_job_out() {
	mut app := initial_queue()
	app.handle_event('remove_invoice')
	assert queue_test_keys(app) == ['report', 'poster', 'manual', 'agenda', 'labels', 'notes']
	assert app.status == 'Removed Invoice 2041.pdf.'
}
