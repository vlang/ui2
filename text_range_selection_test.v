module ui2

fn fixed_width_column(_ SelectableTextLine, offset f64) int {
	return int(offset / 10.0 + 0.5)
}

fn selected_columns(s TextRangeSelection, block int, line int, rune_len int) []int {
	from, to := s.line_columns(block, line, rune_len) or { return []int{} }
	return [from, to]
}

fn word_range(text string, column int) []int {
	start, end := text_word_range(text, column)
	return [start, end]
}

fn two_line_layout() []SelectableTextLine {
	return [
		SelectableTextLine{
			block:    0
			line:     0
			x:        10
			y:        0
			width:    50
			height:   20
			rune_len: 5
		},
		SelectableTextLine{
			block:    1
			line:     0
			x:        10
			y:        40
			width:    30
			height:   20
			rune_len: 3
		},
	]
}

fn test_text_position_compare_orders_block_line_column() {
	a := TextPosition{
		block:  1
		line:   2
		column: 3
	}
	assert a.compare(a) == 0
	assert a.compare(TextPosition{ block: 2 }) == -1
	assert a.compare(TextPosition{ block: 1, line: 1, column: 9 }) == 1
	assert a.compare(TextPosition{ block: 1, line: 2, column: 4 }) == -1
}

fn test_press_without_drag_past_threshold_stays_a_click() {
	mut s := TextRangeSelection{}
	s.press(TextPosition{ column: 1 }, 100, 100, false)
	assert !s.drag(TextPosition{ column: 2 }, 101, 101)
	assert s.is_empty()
	assert !s.release()
}

fn test_drag_extends_selection_and_release_reports_it() {
	mut s := TextRangeSelection{}
	s.press(TextPosition{ block: 1, column: 4 }, 100, 100, false)
	assert s.drag(TextPosition{ block: 0, column: 2 }, 50, 60)
	start, end := s.ordered()
	assert start == TextPosition{
		block:  0
		column: 2
	}
	assert end == TextPosition{
		block:  1
		column: 4
	}
	assert s.release()
	assert !s.is_empty()
	assert !s.drag(TextPosition{ block: 2 }, 0, 0)
}

fn test_shift_press_extends_from_existing_anchor() {
	mut s := TextRangeSelection{}
	s.select(TextPosition{ column: 2 }, TextPosition{ column: 3 })
	s.press(TextPosition{ line: 1, column: 1 }, 5, 5, true)
	assert s.anchor == TextPosition{
		column: 2
	}
	assert s.caret == TextPosition{
		line:   1
		column: 1
	}
	assert s.release()
}

fn test_line_columns_for_first_middle_last_and_outside_lines() {
	mut s := TextRangeSelection{}
	s.select(TextPosition{ block: 0, line: 1, column: 3 }, TextPosition{ block: 2, line: 0, column: 2 })
	assert selected_columns(s, 0, 0, 10) == []int{}
	assert selected_columns(s, 0, 1, 10) == [3, 10]
	assert selected_columns(s, 1, 4, 7) == [0, 7]
	assert selected_columns(s, 1, 5, 0) == [0, 0]
	assert selected_columns(s, 2, 0, 8) == [0, 2]
	assert selected_columns(s, 2, 1, 8) == []int{}
}

fn test_line_columns_excludes_line_where_selection_ends_at_column_zero() {
	mut s := TextRangeSelection{}
	s.select(TextPosition{ block: 0, column: 1 }, TextPosition{ block: 1 })
	assert selected_columns(s, 1, 0, 4) == []int{}
	assert selected_columns(s, 0, 0, 5) == [1, 5]
}

fn test_text_position_at_resolves_inside_and_clamps_outside_lines() {
	lines := two_line_layout()
	inside := text_position_at(lines, 32, 10, fixed_width_column) or { panic('no position') }
	assert inside == TextPosition{
		block:  0
		column: 2
	}
	left := text_position_at(lines, 0, 45, fixed_width_column) or { panic('no position') }
	assert left == TextPosition{
		block: 1
	}
	right := text_position_at(lines, 500, 10, fixed_width_column) or { panic('no position') }
	assert right.column == 5
	gap := text_position_at(lines, 30, 30, fixed_width_column) or { panic('no position') }
	assert gap == TextPosition{
		block: 1
	}
	above := text_position_at(lines, 30, -20, fixed_width_column) or { panic('no position') }
	assert above == TextPosition{}
	below := text_position_at(lines, 30, 200, fixed_width_column) or { panic('no position') }
	assert below == TextPosition{
		block:  1
		column: 3
	}
	missing := text_position_at([]SelectableTextLine{}, 0, 0, fixed_width_column) or {
		TextPosition{
			block: -1
		}
	}
	assert missing.block == -1
}

fn test_text_column_at_x_picks_nearest_rune_boundary() {
	measure := fn (prefix string) f64 {
		return f64(prefix.runes().len) * 10.0
	}
	assert text_column_at_x('héllo', -5, measure) == 0
	assert text_column_at_x('héllo', 4, measure) == 0
	assert text_column_at_x('héllo', 6, measure) == 1
	assert text_column_at_x('héllo', 14, measure) == 1
	assert text_column_at_x('héllo', 16, measure) == 2
	assert text_column_at_x('héllo', 90, measure) == 5
	assert text_column_at_x('', 20, measure) == 0
}

fn test_text_word_range_selects_word_spaces_or_symbol() {
	text := 'foo_bar  baz, qüx'
	assert word_range(text, 2) == [0, 7]
	assert word_range(text, 7) == [7, 9]
	assert word_range(text, 12) == [12, 13]
	assert word_range(text, 15) == [14, 17]
	assert word_range(text, 99) == [14, 17]
	assert word_range('', 0) == [0, 0]
}

fn test_text_rune_slice_clamps_utf8() {
	assert text_rune_slice('a🙂bc', 1, 3) == '🙂b'
	assert text_rune_slice('abc', -1, 99) == 'abc'
	assert text_rune_slice('abc', 2, 1) == ''
}

fn test_click_counter_counts_quick_nearby_presses() {
	mut c := ClickCounter{}
	assert c.press(10, 10, 1000) == 1
	assert c.press(11, 10, 1200) == 2
	assert c.press(11, 11, 1400) == 3
	assert c.press(11, 11, 1500) == 1
	assert c.press(11, 11, 2500) == 1
	assert c.press(40, 11, 2600) == 1
}
