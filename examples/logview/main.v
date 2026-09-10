module main

import ui2

const logview_width = 640
const logview_height = 420
const logview_vml_source = $embed_file('logview.vml').to_string()

pub struct LogviewDemo {
pub mut:
	log       string
	next_task int = 1
	status    string = 'Ready to scan.'
}

pub fn (mut app LogviewDemo) start_scan() {
	mut entries := []string{cap: 8}
	for _ in 0 .. 8 {
		entries << 'processing ... task ${app.next_task} complete'
		app.next_task++
	}
	separator := if app.log.len == 0 { '' } else { '\n' }
	app.log += separator + entries.join('\n')
	app.status = '${app.next_task - 1} tasks complete'
}

pub fn (mut app LogviewDemo) clear() {
	app.log = ''
	app.next_task = 1
	app.status = 'Log cleared.'
}

fn main() {
	ui2.run_vml[LogviewDemo](
		source: logview_vml_source
		model: LogviewDemo{}
		title: 'Log View'
		width: logview_width
		height: logview_height
	) or { panic(err) }
}
