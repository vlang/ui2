module ui2

fn test_safe_side_prefers_larger_of_system_and_minimum() {
	assert safe_side(20, 8, true) == 20
	assert safe_side(4, 8, true) == 8
	assert safe_side(20, 8, false) == 8
	assert safe_side(-5, 8, true) == 8
	assert safe_side(20, -1, true) == 20
}

fn test_safe_area_top_matches_insets_top() {
	assert safe_area_top() == safe_area_insets().top
}

fn test_safe_area_padding_keeps_minimum_without_system_intrusions() {
	minimum := LayoutPadding{
		left:   4
		top:    8
		right:  6
		bottom: 12
	}
	pad := safe_area_padding(true, true, true, true, minimum)
	// This backend reports no intrusions, so the minimum wins on every side.
	assert pad == minimum
}

fn test_safe_area_padding_skipped_side_keeps_minimum() {
	pad := safe_area_padding(false, true, false, true, LayoutPadding{
		left:   2
		top:    3
		right:  5
		bottom: 7
	})
	assert pad == LayoutPadding{
		left:   2
		top:    3
		right:  5
		bottom: 7
	}
}

fn test_safe_content_rect_insets_frame() {
	content := safe_content_rect(rect(0, 0, 400, 800), LayoutPadding{
		left:   10
		top:    20
		right:  10
		bottom: 30
	})
	assert content == rect(10, 20, 380, 750)
}

fn test_safe_content_rect_clamps_at_zero() {
	content := safe_content_rect(rect(0, 0, 10, 10), LayoutPadding{
		left:   8
		top:    8
		right:  8
		bottom: 8
	})
	assert content == rect(8, 8, 0, 0)
}

fn test_safe_area_wraps_children_in_padded_content_view() {
	el := safe_area(
		id:       'safe'
		frame:    rect(0, 0, 400, 800)
		minimum:  LayoutPadding{
			left:   10
			top:    20
			right:  10
			bottom: 30
		}
		children: [label('title', 'Hello', rect(0, 0, 100, 24), TextStyle{})]
	) or { panic(err) }
	assert el.kind == .view
	assert el.id == 'safe'
	assert el.box.transparent
	assert el.accessibility_role == 'group'
	assert el.children.len == 1
	content := el.children[0]
	assert content.frame == rect(10, 20, 380, 750)
	assert content.children.len == 1
	assert content.children[0].id == 'title'
}

fn test_safe_area_background_paints_outer_frame() {
	el := safe_area(
		frame:      rect(0, 0, 400, 800)
		background: 0x0b1020
	) or { panic(err) }
	assert !el.box.transparent
	assert el.box.bg == 0x0b1020
	assert el.children[0].box.transparent
}

fn test_safe_area_rejects_bad_frames_and_minimums() {
	if _ := safe_area(frame: rect(0, 0, -1, 10)) {
		assert false, 'negative frame accepted'
	}
	if _ := safe_area(frame: rect(0, 0, 10, 10), minimum: LayoutPadding{ top: -1 }) {
		assert false, 'negative minimum accepted'
	}
}

fn test_safe_viewport_shifts_children_and_extends_range() {
	el := safe_viewport(
		id:       'list'
		frame:    rect(0, 0, 400, 800)
		minimum:  LayoutPadding{
			left:   10
			top:    20
			right:  10
			bottom: 30
		}
		children: [label('row', 'Row', rect(0, 0, 200, 40), TextStyle{})]
	) or { panic(err) }
	assert el.kind == .scroll
	assert el.id == 'list'
	assert el.frame == rect(0, 0, 400, 800)
	assert el.scroll_mode == .vertical_only
	assert el.children.len == 2
	assert el.children[0].frame == rect(10, 20, 200, 40)
	// The child reaches (210, 60); the trailing padding extends the range.
	assert el.children[1].frame == rect(219, 89, 1, 1)
}

fn test_safe_viewport_ignores_hidden_children_in_range() {
	el := safe_viewport(
		id:       'list'
		frame:    rect(0, 0, 400, 800)
		minimum:  LayoutPadding{
			top:    20
			bottom: 30
		}
		children: [
			Element{
				...label('gone', 'Gone', rect(0, 0, 500, 500), TextStyle{})
				hidden: true
			},
			label('row', 'Row', rect(0, 0, 200, 40), TextStyle{}),
		]
	) or { panic(err) }
	assert el.children.len == 3
	assert el.children[2].frame == rect(199, 89, 1, 1)
}

fn test_safe_viewport_axis_and_scroller_options() {
	el := safe_viewport(
		id:                    'columns'
		frame:                 rect(0, 0, 400, 800)
		axis:                  .horizontal_only
		persistent_scrollbars: true
		label:                 'Columns'
	) or { panic(err) }
	assert el.scroll_mode == .horizontal_only
	assert el.persistent_scrollbars
	assert el.accessibility_label == 'Columns'
}

fn test_safe_viewport_rejects_bad_frames_and_minimums() {
	if _ := safe_viewport(id: 'x', frame: rect(0, 0, -1, 10)) {
		assert false, 'negative frame accepted'
	}
	if _ := safe_viewport(
		id:      'x'
		frame:   rect(0, 0, 10, 10)
		minimum: LayoutPadding{
			bottom: -2
		}
	) {
		assert false, 'negative minimum accepted'
	}
}

fn test_vml_safe_area_builds_padded_content() {
	el := element_from_vml('SafeArea {
		id: safe
		minimum_top: 20
		minimum_bottom: 30
		Label {
			text: "Hello"
		}
	}', rect(0, 0, 400, 800)) or { panic(err) }
	assert el.kind == .view
	assert el.children.len == 1
	assert el.children[0].frame == rect(0, 20, 400, 750)
	assert el.children[0].children.len == 1
	assert el.children[0].children[0].text == 'Hello'
}

fn test_vml_safe_viewport_builds_padded_scroll() {
	el := element_from_vml('SafeViewport {
		id: list
		minimum_left: 10
		minimum_top: 20
		scroll_mode: horizontal_only
		persistent: true
		Label {
			text: "Row"
			x: 0
			y: 0
			width: 200
			height: 40
		}
	}', rect(0, 0, 400, 800)) or { panic(err) }
	assert el.kind == .scroll
	assert el.scroll_mode == .horizontal_only
	assert el.persistent_scrollbars
	assert el.children[0].frame == rect(10, 20, 200, 40)
}

fn test_vml_safe_area_rejects_bad_minimum() {
	element_from_vml('SafeArea { minimum_top: -4 }', rect(0, 0, 300, 200)) or {
		assert err.msg().contains('minimum insets')
		return
	}
	assert false
}
