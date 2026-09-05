module main

import ui2

const counter_width = 280
const counter_height = 120
const counter_qml_source = $embed_file('counter.qml').to_string()

pub struct CounterApp {
pub mut:
	count int
}

pub fn (mut app CounterApp) increment() {
	app.count++
}

fn main() {
	ui2.run_qml[CounterApp](
		source: counter_qml_source
		model: CounterApp{}
		title: 'Counter'
		width: counter_width
		height: counter_height
	) or { panic(err) }
}
