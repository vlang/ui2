module main

import ui2

const queue_width = 560
const queue_height = 470
const queue_id = 'queue'
const queue_frame = ui2.rect(24, 84, 512, 300)
const queue_card_height = 52

// Each job is keyed, so the queue keeps a job's native state as the job moves.
pub struct PrintJob {
pub:
	key   string
	title string
	pages int
}

@[heap]
pub struct QueueDemo {
pub mut:
	jobs   []PrintJob
	state  ui2.ReorderState
	offset f64
	status string
}

const queue_demo_state = &QueueDemo{}

fn initial_queue() QueueDemo {
	return QueueDemo{
		jobs:   [
			PrintJob{
				key:   'report'
				title: 'Quarterly report.pdf'
				pages: 24
			},
			PrintJob{
				key:   'invoice'
				title: 'Invoice 2041.pdf'
				pages: 2
			},
			PrintJob{
				key:   'poster'
				title: 'Summer poster.png'
				pages: 1
			},
			PrintJob{
				key:   'manual'
				title: 'Printer manual.pdf'
				pages: 96
			},
			PrintJob{
				key:   'agenda'
				title: 'Board agenda.docx'
				pages: 6
			},
			PrintJob{
				key:   'labels'
				title: 'Shipping labels.pdf'
				pages: 4
			},
			PrintJob{
				key:   'notes'
				title: 'Meeting notes.txt'
				pages: 3
			},
		]
		status: 'Drag a job to move it, or select it and press Alt+Up or Alt+Down.'
	}
}

fn job_card(job PrintJob) ui2.Element {
	card := ui2.view('card_${job.key}', ui2.rect(0, 0, queue_frame.width, queue_card_height),
		ui2.BoxStyle{
			bg:            0xffffff
			radius:        8
			border_color:  0xcbd5e1
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, [
			ui2.label('', job.title, ui2.rect(16, 9, 340, 20), ui2.TextStyle{
				color: 0x172033
				size:  14
				bold:  true
			}),
			ui2.label('', '${job.pages} pages', ui2.rect(16, 29, 340, 18), ui2.TextStyle{
				color: 0x64748b
				size:  12
			}),
			ui2.button('remove_${job.key}', 'Remove', ui2.rect(412, 12, 84, 28), ui2.BoxStyle{
				bg:     0xfee2e2
				radius: 6
			}, ui2.TextStyle{
				color: 0xb91c1c
				size:  12
				align: .center
			}),
		])
	return ui2.Element{
		...card
		key: job.key
	}
}

fn (app QueueDemo) config() ui2.ReorderConfig {
	mut items := []ui2.Element{cap: app.jobs.len}
	for job in app.jobs {
		items << job_card(job)
	}
	return ui2.ReorderConfig{
		id:                  queue_id
		frame:               queue_frame
		items:               items
		state:               app.state
		gap:                 8
		padding:             4
		offset:              app.offset
		accessibility_label: 'Print queue'
	}
}

fn (app QueueDemo) title_of(key string) string {
	for job in app.jobs {
		if job.key == key {
			return job.title
		}
	}
	return key
}

fn (mut app QueueDemo) remove(key string) {
	for index, job in app.jobs {
		if job.key == key {
			app.jobs.delete(index)
			app.status = 'Removed ${job.title}.'
			if app.state.active == key {
				app.state = ui2.ReorderState{}
			}
			return
		}
	}
}

// apply stores a step from the queue. The caller rebuilds afterwards.
fn (mut app QueueDemo) apply(step ui2.ReorderStep) {
	app.state = step.state
	if step.moved {
		app.jobs = ui2.reorder_move(app.jobs, step.from, step.to)
		app.status = 'Moved ${app.title_of(step.state.active)} to position ${step.to + 1}.'
	} else if step.clicked.len > 0 {
		app.status = 'Selected ${app.title_of(step.clicked)}. Alt+Up and Alt+Down move it.'
	}
}

fn (mut app QueueDemo) handle_event(event string) {
	if event.starts_with('remove_') {
		app.remove(event['remove_'.len..])
		return
	}
	if step := ui2.reorder_update(app.config(), event) {
		app.apply(step)
	}
}

fn (mut app QueueDemo) handle_key(event ui2.KeyEvent) ?ui2.ReorderStep {
	step := ui2.reorder_key(app.config(), event)?
	app.apply(step)
	return step
}

fn build_queue_screen() ui2.Element {
	app := unsafe { queue_demo_state }
	container := ui2.reorder_container(app.config()) or {
		eprintln('queue failed: ${err}')
		return ui2.screen(0xf1f5f9, [])
	}
	return ui2.screen(0xf1f5f9, [
		ui2.label('title', 'Print queue', ui2.rect(24, 20, 512, 28), ui2.TextStyle{
			color: 0x172033
			size:  20
			bold:  true
		}),
		ui2.label('hint', 'Drag a job to reorder it. Remove takes it out of the queue.',
			ui2.rect(24, 52, 512, 20), ui2.TextStyle{
				color: 0x64748b
				size:  12
			}),
		container,
		ui2.label('status', app.status, ui2.rect(24, 402, 512, 20), ui2.TextStyle{
			color: 0x172033
			size:  13
		}),
	])
}

fn handle_queue_event(event string) {
	mut app := unsafe { queue_demo_state }
	app.handle_event(event)
	ui2.refresh()
}

fn handle_queue_key(event ui2.KeyEvent) {
	mut app := unsafe { queue_demo_state }
	step := app.handle_key(event) or { return }
	ui2.consume_key()
	if step.reveal {
		if offset := ui2.reorder_reveal_offset(app.config(), app.state.active) {
			ui2.scroll_to_offset(ui2.reorder_scroll_id(queue_id), offset)
		}
	}
	ui2.refresh()
}

fn handle_queue_scroll(id string) {
	if id == ui2.reorder_scroll_id(queue_id) {
		mut app := unsafe { queue_demo_state }
		app.offset = ui2.scroll_offset(id)
	}
}

fn main() {
	mut app := unsafe { queue_demo_state }
	unsafe {
		*app = initial_queue()
	}
	ui2.on_scroll(handle_queue_scroll)
	ui2.on_key_event(handle_queue_key)
	ui2.run_window('Print Queue', queue_width, queue_height, build_queue_screen,
		handle_queue_event)
}
