module main

import time
import ui2

const iterations = 10_000
const calculator_qml = $embed_file('form.qml').to_string()

struct Key {
pub:
	text   string
	role   string
	row    int
	column int
}

pub struct Calculator {
pub mut:
	display string
	keys    []Key
}

fn benchmark_model() Calculator {
	mut keys := []Key{cap: 20}
	for row in 0 .. 5 {
		for column in 0 .. 4 {
			keys << Key{
				text: '${row * 4 + column}'
				role: if column == 3 { 'operator' } else { 'digit' }
				row: row
				column: column
			}
		}
	}
	return Calculator{
		display: '12345'
		keys: keys
	}
}

fn build_compiled(app &Calculator) ui2.Element {
	return $qml('form.qml')
}

fn main() {
	app := benchmark_model()
	frame := ui2.rect(0, 0, 800, 600)
	mut runtime_app := ui2.new_qml_app(calculator_qml, app) or { panic(err) }
	_ = build_compiled(&app)
	_ = runtime_app.build(frame) or { panic(err) }

	mut checksum := 0
	mut watch := time.new_stopwatch()
	for _ in 0 .. iterations {
		root := runtime_app.build(frame) or { panic(err) }
		checksum += root.children[0].children.len
	}
	runtime_elapsed := watch.elapsed()

	watch.restart()
	for _ in 0 .. iterations {
		root := build_compiled(&app)
		checksum += root.children[0].children.len
	}
	compiled_elapsed := watch.elapsed()

	println('iterations: ${iterations}')
	println('runtime QML:  ${f64(runtime_elapsed) / f64(time.millisecond):.3f} ms')
	println('compiled QML: ${f64(compiled_elapsed) / f64(time.millisecond):.3f} ms')
	println('speedup:      ${f64(runtime_elapsed) / f64(compiled_elapsed):.2f}x')
	println('checksum:     ${checksum}')
}
