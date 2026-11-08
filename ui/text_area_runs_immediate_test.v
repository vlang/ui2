// vfmt off
module ui2

// Rich text areas take their runs as consecutive stretches from the start on
// every backend; this part runs natively too (and keeps the file from being
// empty there).
fn test_rich_text_area_keeps_its_runs() {
	el := rich_text_area('code', 'fn main', [TextRun{ text: 'fn', style: TextStyle{ color: 0xff0000 } }],
		rect(0, 0, 100, 40), BoxStyle{}, TextStyle{})
	assert el.text_runs.len == 1
}

$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	fn test_text_area_run_spans_follow_the_runes_of_the_text() {
		red := TextStyle{ color: 0xff0000 }
		blue := TextStyle{ color: 0x0000ff }
		spans := text_area_run_spans([TextRun{ text: 'héllo', style: red }, TextRun{ text: ' ', style: TextStyle{} },
			TextRun{ text: 'wörld', style: blue }], 'héllo wörld!')
		assert spans.len == 3
		assert spans[0].start == 0 && spans[0].end == 5
		assert spans[1].start == 5 && spans[1].end == 6
		assert spans[2].start == 6 && spans[2].end == 11
		assert spans[2].style.color == 0x0000ff
	}

	fn test_text_area_run_spans_drop_runs_the_text_no_longer_matches() {
		red := TextStyle{ color: 0xff0000 }
		// Edited since the runs were declared: drawn plain until new runs come.
		assert text_area_run_spans([TextRun{ text: 'fn', style: red }], 'fx main').len == 0
		assert text_area_run_spans([TextRun{ text: 'fn main()', style: red }], 'fn').len == 0
		assert text_area_run_spans([]TextRun{}, 'fn').len == 0
		// Empty runs take no room.
		spans := text_area_run_spans([TextRun{ text: '', style: red }, TextRun{ text: 'fn', style: red }], 'fn x')
		assert spans.len == 1 && spans[0].end == 2
	}
}
