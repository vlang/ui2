module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import math
}

fn layout_measure_fixture_width(text string) f64 {
	mut width := 0.0
	for character in text.runes() {
		width += match character {
			`W` { 12.0 }
			`i` { 3.0 }
			` ` { 4.0 }
			else { 8.0 }
		}
	}
	return width
}

fn layout_measure_fixture_text(text string, style TextStyle, width f64) !LayoutSize {
	return layout_measure_text_lines(text, style, width, 20, layout_measure_fixture_width)
}

fn layout_measure_unexpected_text(_text string, _style TextStyle, _width f64) !LayoutSize {
	return error('fixed and hidden elements must not request text measurement')
}

fn test_layout_constraints_distinguish_zero_from_unbounded_and_validate() {
	unbounded := LayoutConstraints{ min_width: 10 }
	assert unbounded.constrain(LayoutSize{ width: 200, height: 50 })! == LayoutSize{ width: 200, height: 50 }
	assert unbounded.constrain(LayoutSize{ width: 2, height: -3 })! == LayoutSize{ width: 10 }
	zero := LayoutConstraints{ max_width: 0, max_height: 0 }
	assert zero.constrain(LayoutSize{ width: 200, height: 50 })! == LayoutSize{}
	if _ := (LayoutConstraints{ min_width: 20, max_width: 10 }).constrain(LayoutSize{}) {
		assert false, 'contradictory constraints must be rejected'
	}
	if _ := (LayoutConstraints{ max_height: -2 }).constrain(LayoutSize{}) {
		assert false, 'only -1 represents an unbounded maximum'
	}
	tight := LayoutConstraints{ min_width: 100, max_width: 100, min_height: 40, max_height: 40 }
	assert tight.loosen() == LayoutConstraints{ max_width: 100, max_height: 40 }
	assert tight.deflate(LayoutPadding{ left: 20, right: 30, top: 50 })! == LayoutConstraints{
		min_width:  50
		max_width:  50
		max_height: 0
	}
	if _ := tight.deflate(LayoutPadding{ left: -1 }) {
		assert false, 'negative padding must be rejected'
	}
}

fn test_layout_measure_text_uses_available_content_width_and_preserves_point_style() {
	label_inset := $if macos && !ui2_custom_rendering ?&& !ui2_headless ? { 4.0 } $else { 0.0 }
	style := TextStyle{ size: 14, lines: 3 }
	label := label('description', 'WW WW', Rect{}, style)
	unbounded := measure_layout_element(label, LayoutConstraints{}, layout_measure_fixture_text)!
	assert unbounded == LayoutSize{ width: 52 + label_inset, height: 20 }
	narrow := measure_layout_element(label, LayoutConstraints{ max_width: 30 }, layout_measure_fixture_text)!
	assert narrow == LayoutSize{ width: 24 + label_inset, height: 40 }
	assert label.text_style.size == 14
	assert label.frame == Rect{}
	fixed_width := Element{ ...label, frame: rect(0, 0, 30, 0) }
	assert measure_layout_element(fixed_width, LayoutConstraints{}, layout_measure_fixture_text)! == LayoutSize{ width: 30, height: 40 }
	button := button('action', 'WW WW', Rect{}, BoxStyle{}, style)
	// Control insets are removed before wrapping, then added to its answer.
	assert measure_layout_element(button, LayoutConstraints{ max_width: 54 }, layout_measure_fixture_text)! == LayoutSize{ width: 48, height: 52 }
}

fn test_layout_measure_declared_sizes_hidden_nodes_and_nested_extents() {
	label_inset := $if macos && !ui2_custom_rendering ?&& !ui2_headless ? { 4.0 } $else { 0.0 }
	fixed := label('fixed', 'text', rect(7, 3, 40, 30), TextStyle{})
	assert measure_layout_element(fixed, LayoutConstraints{ max_width: 20 }, layout_measure_unexpected_text)! == LayoutSize{ width: 20, height: 30 }
	hidden := Element{ ...fixed, hidden: true }
	assert measure_layout_element(hidden, LayoutConstraints{}, layout_measure_unexpected_text)! == LayoutSize{}
	child := label('intrinsic', 'WWW', rect(7, 3, 0, 0), TextStyle{})
	container := view('root', Rect{}, BoxStyle{}, [
		view('nested', rect(10, 5, 0, 0), BoxStyle{}, [child]),
		Element{ ...fixed, frame: rect(1_000, 1_000, 400, 400), hidden: true },
	])
	assert measure_layout_element(container, LayoutConstraints{}, layout_measure_fixture_text)! == LayoutSize{ width: 53 + label_inset, height: 28 }
}

fn test_layout_default_text_measurement_uses_real_fonts_before_window_creation() {
	style := TextStyle{ size: 16 }
	wide := measure_layout_text('WWW', style, -1)!
	narrow := measure_layout_text('iii', style, -1)!
	assert wide.width > narrow.width * 1.5
	assert narrow.width > 0
	assert wide.height > 0
	larger := measure_layout_text('WWW', TextStyle{ size: 32 }, -1)!
	assert larger.width > wide.width * 1.7
	assert larger.height > wide.height * 1.7
	wrapped := measure_layout_text('WWW WWW', TextStyle{ ...style, lines: 3 }, wide.width + 1)!
	assert wrapped.width <= wide.width + 1
	assert wrapped.height > wide.height
}

fn test_layout_editor_measurement_preserves_rows_and_splits_overlong_words() {
	// Independent advances: W=12, i=3. Two Ws fill the first 24-unit row;
	// three i glyphs fill the next, followed by an empty paragraph and one W.
	style := TextStyle{ lines: 1 }
	assert layout_measure_text_area_lines('WWiii\r\n\r\nW', style, 24, 20,
		layout_measure_fixture_width)! == LayoutSize{ width: 24, height: 80 }
	assert layout_measure_text_area_lines('WWiii\r\n\r\nW', style, -1, 20,
		layout_measure_fixture_width)! == LayoutSize{ width: 33, height: 60 }
	assert layout_measure_text_area_lines('ab cd\tef\n', style, 24, 20,
		layout_measure_fixture_width)! == LayoutSize{ width: 16, height: 80 }
	assert layout_measure_text_area_lines('WW', style, 0, 20,
		layout_measure_fixture_width)! == LayoutSize{}
	assert style.lines == 1
}

fn layout_measure_require_declared_editor_style(_text string, style TextStyle, _width f64) !LayoutSize {
	if style.lines != 1 || style.size != 16 || style.font_family != 'Roboto Mono' {
		return error('external callbacks must receive the declared editor style')
	}
	return LayoutSize{ width: 16, height: 20 }
}

fn test_custom_intrinsic_editor_matches_wrapping_content_width_before_window_creation() {
	$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
		style := TextStyle{ size: 16, font_family: 'Roboto Mono', lines: 1 }
		advance := measure_layout_text('M', style, -1)!.width
		// With two monospaced glyphs per row, five Ms occupy three rows.
		// CRLF blank, final M and trailing newline contribute three more.
		content_width := advance * 2 + 0.05
		for padding_left in [0.0, 12.0] {
			for scrolling in [true, false] {
				area := Element{
					...text_area('notes', 'MMMMM\r\n\r\nM\n', Rect{}, BoxStyle{}, style)
					padding_left:   padding_left
					disable_scroll: !scrolling
				}
				gutter := if scrolling { 12.0 } else { 8.0 }
				left := if padding_left == 0 { 2.0 } else { 12.0 }
				available := content_width + left + gutter
				measured := measure_layout_element(area, LayoutConstraints{ max_width: available },
					measure_layout_text)!
				assert math.abs(measured.height - (font_line_height(style.size) * 6 + 16)) < 0.01
				assert math.abs(measured.width - (advance * 2 + left + gutter)) < 0.01
				assert area.text_style == style
				custom := measure_layout_element(area, LayoutConstraints{},
					layout_measure_require_declared_editor_style)!
				assert custom == LayoutSize{ width: 16 + left + gutter, height: 36 }
				fixed := Element{ ...area, frame: rect(0, 0, 90, 30) }
				assert measure_layout_element(fixed, LayoutConstraints{}, layout_measure_unexpected_text)! == LayoutSize{ width: 90, height: 30 }
				zero_content := measure_layout_element(area,
					LayoutConstraints{ max_width: left + gutter }, measure_layout_text)!
				assert zero_content == LayoutSize{ width: left + gutter, height: 16 }
			}
		}
	}
}
