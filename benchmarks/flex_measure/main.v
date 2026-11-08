// Measures intrinsic text and Flex/Grid placement through the V API.
// Run with the compiler and module path documented in README.md.
module main

import os
import time
import ui2

const runs = 7

struct Case {
	name  string
	width f64
	depth int
	grid  bool
}

fn measured_label(text string, width f64) !ui2.Element {
	element := ui2.label('', text, ui2.Rect{}, ui2.TextStyle{ lines: 3 })
	size := ui2.measure_layout_element(element, ui2.LayoutConstraints{ max_width: width }, ui2.measure_layout_text)!
	return ui2.Element{ ...element, frame: ui2.rect(0, 0, size.width, size.height) }
}

fn build(case Case) !int {
	if case.grid {
		mut children := []ui2.Element{}
		for index in 0 .. 12 {
			children << measured_label('Project ${index}: a description that wraps in narrow cards', case.width / 3)!
		}
		config := ui2.GridConfig{
			frame:                  ui2.rect(0, 0, case.width, 780)
			auto_columns_min_width: 240
			max_columns:            3
			spacing:                ui2.GridSpacing{ horizontal: 16, vertical: 16 }
			child_spans:            [ui2.GridSpan{ column_span: 2 }]
			children:               children
		}
		return ui2.grid(config)!.children.len
	}
	if case.depth == 0 {
		mut children := []ui2.FlexChild{}
		for index in 0 .. 200 {
			children << ui2.FlexChild{ element: measured_label('Item ${index}', case.width)! }
		}
		return ui2.flex(ui2.FlexConfig{ frame: ui2.rect(0, 0, case.width, 780), gap: 6, wrap: true, children: children })!.children.len
	}
	mut element := measured_label('Content that can wrap at a narrow width', case.width)!
	for level in 0 .. case.depth {
		config := ui2.FlexConfig{
			orientation: if level % 2 == 0 {
				ui2.LayoutOrientation.horizontal
			} else {
				ui2.LayoutOrientation.vertical
			}
			gap:         4
			children:    [
				ui2.FlexChild{ element: measured_label('Level ${level}', case.width)! },
				ui2.FlexChild{ element: element },
			]
		}
		preferred := ui2.flex_preferred_size(config)!
		element = ui2.flex(ui2.FlexConfig{ ...config, frame: preferred })!
	}
	return element.children.len
}

fn median(values []f64) f64 {
	mut sorted := values.clone()
	sorted.sort(a < b)
	return sorted[sorted.len / 2]
}

fn main() {
	cases := [
		Case{ name: 'grid wide', width: 1000, grid: true },
		Case{ name: 'grid compact', width: 390, grid: true },
		Case{ name: 'flat wrap 200', width: 1000 },
		Case{ name: 'nested 4', width: 1000, depth: 4 },
		Case{ name: 'nested 8', width: 1000, depth: 8 },
		Case{ name: 'nested 10', width: 1000, depth: 10 },
	]
	filter := if os.args.len > 1 { os.args[1] } else { '' }
	mut checksum := 0
	for case in cases {
		if filter.len > 0 && !case.name.contains(filter) { continue }
		checksum += build(case)!
		mut iterations := 1
		for {
			watch := time.new_stopwatch()
			for _ in 0 .. iterations { checksum += build(case)! }
			if watch.elapsed().milliseconds() >= 100 || iterations >= 100_000 { break }
			iterations *= 2
		}
		mut samples := []f64{cap: runs}
		for _ in 0 .. runs {
			watch := time.new_stopwatch()
			for _ in 0 .. iterations { checksum += build(case)! }
			samples << f64(watch.elapsed().microseconds()) / f64(iterations)
		}
		println('${case.name:-28} ${median(samples):12.1f} us/build')
	}
	println('checksum ${checksum}')
}
