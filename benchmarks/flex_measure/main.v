// Times runtime VML constructions that measure intrinsic Flex/Grid sizes:
// the responsive example, a flat wrapping Flex, and nested Flex containers.
// From the repository root:
//   v -prod -path "$(dirname "$PWD")|@vlib|@vmodules" -o /tmp/ui2-flex-bench benchmarks/flex_measure/main.v
//   /tmp/ui2-flex-bench [name-filter]
module main

import os
import time
import ui2

const responsive_vml = $embed_file('../../examples/responsive_layout/responsive_layout.vml').to_string()
const runs = 7

pub struct Project {
pub:
	id          int
	title       string
	description string
}

pub struct BenchApp {
pub mut:
	created  int
	projects []Project
}

pub fn (mut app BenchApp) create_project() {
	app.created++
}

struct Case {
	name   string
	source string
	frame  ui2.Rect
	model  bool
}

// nested alternates orientations so every level changes the width available
// to its subtree, the shape that made intrinsic measurement repeat work.
fn nested(depth int) string {
	mut source := 'Label { text: "content that can wrap at a narrow width" lines: 3 }'
	for level in 0 .. depth {
		orientation := if level % 2 == 0 { 'horizontal' } else { 'vertical' }
		source = 'FlexLayout { orientation: ${orientation} gap: 4\n Label { text: "level ${level}" }\n ${source} }'
	}
	return 'Screen {\n ${source} }'
}

fn flat(count int) string {
	mut labels := []string{cap: count}
	for index in 0 .. count {
		labels << 'Label { text: "item ${index}" }'
	}
	return 'Screen {\n FlexLayout { wrap: true gap: 6\n ${labels.join('\n')} } }'
}

fn model() BenchApp {
	mut projects := []Project{cap: 12}
	for id in 1 .. 13 {
		projects << Project{
			id:          id
			title:       'Project ${id}'
			description: 'A description that is long enough to wrap in narrow cards'
		}
	}
	return BenchApp{
		projects: projects
	}
}

fn build(case Case, mut app ui2.VmlApp[BenchApp]) !int {
	root := if case.model {
		app.build(case.frame)!
	} else {
		ui2.element_from_vml(case.source,
			case.frame)!
	}
	return root.children.len
}

fn median(values []f64) f64 {
	mut sorted := values.clone()
	sorted.sort(a < b)
	return sorted[sorted.len / 2]
}

fn main() {
	wide := ui2.rect(0, 0, 1000, 780)
	compact := ui2.rect(0, 0, 390, 780)
	cases := [
		Case{'responsive wide (model)', responsive_vml, wide, true},
		Case{'responsive compact (model)', responsive_vml, compact, true},
		Case{'flat wrap 200 (static)', flat(200), wide, false},
		Case{'flat wrap 200 (model)', flat(200), wide, true},
		Case{'nested 4 (static)', nested(4), wide, false},
		Case{'nested 4 (model)', nested(4), wide, true},
		Case{'nested 8 (static)', nested(8), wide, false},
		Case{'nested 8 (model)', nested(8), wide, true},
		Case{'nested 10 (static)', nested(10), wide, false},
		Case{'nested 10 (model)', nested(10), wide, true},
	]
	filter := if os.args.len > 1 { os.args[1] } else { '' }
	mut checksum := 0
	for case in cases {
		if filter.len > 0 && !case.name.contains(filter) {
			continue
		}
		mut app := ui2.new_vml_app(case.source, model())!
		checksum += build(case, mut app)! // warm fonts and caches outside timing
		mut iterations := 1
		for {
			mut watch := time.new_stopwatch()
			for _ in 0 .. iterations {
				checksum += build(case, mut app)!
			}
			if watch.elapsed().milliseconds() >= 100 || iterations >= 100_000 {
				break
			}
			iterations *= 2
		}
		mut samples := []f64{cap: runs}
		for _ in 0 .. runs {
			mut watch := time.new_stopwatch()
			for _ in 0 .. iterations {
				checksum += build(case, mut app)!
			}
			samples << f64(watch.elapsed().microseconds()) / f64(iterations)
		}
		println('${case.name:-28} ${median(samples):12.1f} us/build')
	}
	println('checksum ${checksum}')
}
