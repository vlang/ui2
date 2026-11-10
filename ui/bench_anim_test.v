module ui2

import os
import time

fn bench_anim_sheet() Stylesheet {
	mut src := []string{}
	src << '@accent: #2563eb;'
	src << '@keyframes pulse { from { opacity: 1; } to { opacity: 0.5; } }'
	for i in 0 .. 60 {
		src << 'Button.b${i} { transition: background 0.2s ease, opacity 0.15s; }'
		src << 'Button.b${i}:hover { background: #1d4ed8; opacity: 0.9; }'
		src << 'Button.b${i}.loading { animation: pulse 1s ease-in-out infinite; }'
	}
	src << 'View.card { background: #ffffff; border-radius: 10px; transition: opacity 0.3s; }'
	return parse_stylesheet(src.join('\n')) or { panic(err) }
}

fn bench_anim_tree() Element {
	mut children := []Element{}
	for i in 0 .. 60 {
		children << with_classes(button('b${i}', 'Go', rect(10, 10 + i * 20, 96, 30), BoxStyle{}, TextStyle{}), 'b${i}')
	}
	mut root := view('root', rect(0, 0, 400, 1200), BoxStyle{}, children)
	root = with_classes(root, 'card')
	return root
}

fn test_bench_anim_tmp() {
	sheet := bench_anim_sheet()
	set_global_stylesheet(sheet)
	tree := bench_anim_tree()
	env := StyleMatchEnv{dark: false, dpi: 2.0}
	// warmup
	_ := stylesheet_apply_frame(tree, env)
	iterations := 20
	mut sw := time.new_stopwatch()
	for _ in 0 .. iterations {
		_ := stylesheet_apply_frame(tree, env)
	}
	ms := sw.elapsed().milliseconds()
	// second variant: flip a class to trigger transitions
	mut tree2_children := []Element{}
	for i in 0 .. 60 {
		tree2_children << with_classes(button('b${i}', 'Go', rect(10, 10 + i * 20, 96, 30), BoxStyle{}, TextStyle{}), 'b${i}', 'loading')
	}
	tree2 := view('root', rect(0, 0, 400, 1200), BoxStyle{}, tree2_children)
	sw = time.new_stopwatch()
	for _ in 0 .. iterations {
		_ := stylesheet_apply_frame(tree2, env)
	}
	ms2 := sw.elapsed().milliseconds()
	// also measure cascade alone
	mut sw3 := time.new_stopwatch()
	for _ in 0 .. iterations {
		_ := apply_stylesheet(tree, sheet, env)
	}
	ms3 := sw3.elapsed().milliseconds()
	os.write_file(os.join_path(os.temp_dir(), 'ui2_bench_anim.txt'), 'nodes=${60} apply=${ms}ms apply_loading=${ms2}ms cascade_only=${ms3}ms\n') or {}
	assert true
}
