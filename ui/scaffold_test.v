module ui2

fn test_scaffold_content_rect_sits_between_bars() {
	content := scaffold_content_rect(rect(0, 0, 400, 800), 56, 64)
	assert content == rect(0, 56, 400, 680)
}

fn test_scaffold_content_rect_clamps_over_tall_bars() {
	content := scaffold_content_rect(rect(10, 20, 100, 100), 80, 60)
	assert content == rect(10, 100, 100, 0)
}

fn test_scaffold_arranges_bars_content_and_overlays() {
	el := scaffold(
		id:                'app'
		frame:             rect(0, 0, 400, 800)
		top_bar_height:    56
		bottom_bar_height: 64
		top_bar:           [label('title', 'App', rect(16, 0, 200, 56), TextStyle{})]
		content:           [label('body', 'Hi', rect(8, 8, 100, 24), TextStyle{})]
		bottom_bar:        [label('nav', 'Nav', rect(16, 0, 200, 64), TextStyle{})]
		floating_action:   button('add', '+', rect(0, 0, 56, 56), BoxStyle{
			bg: 0x2563eb
		}, TextStyle{})
		snackbar:          label('snack', 'Saved', rect(0, 0, 100, 40), TextStyle{})
	) or { panic(err) }
	assert el.kind == .view
	assert el.id == 'app'
	assert el.children.len == 5
	top := el.children[0]
	assert top.frame == rect(0, 0, 400, 56)
	assert top.children[0].id == 'title'
	body := el.children[1]
	assert body.frame == rect(0, 56, 400, 680)
	assert body.children[0].frame == rect(8, 8, 100, 24)
	nav := el.children[2]
	assert nav.frame == rect(0, 736, 400, 64)
	fab := el.children[3]
	assert fab.id == 'add'
	assert fab.frame == rect(328, 664, 56, 56)
	snack := el.children[4]
	assert snack.id == 'snack'
	assert snack.frame == rect(16, 608, 368, 40)
	assert snack.frame.y + snack.frame.height + 16 == fab.frame.y
}

fn test_scaffold_skips_empty_strips_and_overlays() {
	el := scaffold(
		frame:   rect(0, 0, 400, 800)
		content: [label('body', 'Hi', rect(0, 0, 100, 24), TextStyle{})]
	) or { panic(err) }
	assert el.children.len == 1
	assert el.children[0].frame == rect(0, 0, 400, 800)
	assert el.box.transparent
}

fn test_scaffold_background_paints_outer_frame() {
	el := scaffold(frame: rect(0, 0, 400, 800), background: 0x0b1020) or { panic(err) }
	assert !el.box.transparent
	assert el.box.bg == 0x0b1020
	assert el.children[0].box.transparent
}

fn test_scaffold_rejects_bad_sizes() {
	if _ := scaffold(frame: rect(0, 0, -1, 10)) {
		assert false, 'negative frame accepted'
	}
	if _ := scaffold(frame: rect(0, 0, 10, 10), top_bar_height: -1) {
		assert false, 'negative top bar accepted'
	}
	if _ := scaffold(frame: rect(0, 0, 10, 10), fab_margin: -2) {
		assert false, 'negative fab margin accepted'
	}
}

fn test_vml_plain_scaffold_keeps_children_in_full_frame() {
	el := element_from_vml('Scaffold {
		id: app
		Label {
			text: "Hello"
		}
	}', rect(0, 0, 400, 800)) or { panic(err) }
	assert el.kind == .view
	assert el.children.len == 1
	assert el.children[0].frame == rect(0, 0, 400, 800)
	assert el.children[0].text == 'Hello'
}

fn test_vml_scaffold_routes_slots() {
	el := element_from_vml('Scaffold {
		id: app
		top_bar_height: 56
		bottom_bar_height: 64
		Label {
			slot: top
			text: "Title"
		}
		Label {
			text: "Body"
		}
		Label {
			slot: bottom
			text: "Nav"
		}
		Button {
			slot: fab
			text: "+"
			x: 0
			y: 0
			width: 56
			height: 56
		}
	}', rect(0, 0, 400, 800)) or { panic(err) }
	assert el.children.len == 4
	assert el.children[0].frame == rect(0, 0, 400, 56)
	assert el.children[0].children[0].text == 'Title'
	assert el.children[1].frame == rect(0, 56, 400, 680)
	assert el.children[2].frame == rect(0, 736, 400, 64)
	// Bottom children resolve against the slot-local rect; the bar wrapper
	// supplies the absolute y, so the child's y stays at zero.
	assert el.children[2].children[0].frame == rect(0, 0, 400, 64)
	assert el.children[3].frame == rect(328, 664, 56, 56)
}

fn test_vml_scaffold_preserves_box_styling() {
	el := element_from_vml('Scaffold {
		corner_radius: 12
		border_width: 2
		background: "#112233"
		Label {
			text: "Body"
		}
	}', rect(0, 0, 300, 200)) or { panic(err) }
	assert !el.box.transparent
	assert el.box.bg == 0x112233
	assert el.box.radius == 12
	assert el.box.border_left == 2
	assert el.box.border_top == 2
	assert el.box.border_right == 2
	assert el.box.border_bottom == 2
}

fn test_vml_scaffold_rejects_duplicate_fab() {
	element_from_vml('Scaffold {
		Button {
			slot: fab
			text: "+"
		}
		Button {
			slot: fab
			text: "++"
		}
	}', rect(0, 0, 300, 200)) or {
		assert err.msg().contains('at most one fab')
		return
	}
	assert false
}

fn test_vml_scaffold_rejects_unknown_slot() {
	element_from_vml('Scaffold {
		Label {
			slot: sidebar
			text: "?"
		}
	}', rect(0, 0, 300, 200)) or {
		assert err.msg().contains('unknown scaffold slot')
		return
	}
	assert false
}

fn test_scaffold_bottom_bar_stays_at_bottom_when_bars_overlap() {
	el := scaffold(
		frame:             rect(10, 20, 200, 100)
		top_bar_height:    80
		bottom_bar_height: 60
	) or { panic(err) }
	assert el.frame == rect(10, 20, 200, 100)
	assert el.children[0].frame == rect(0, 0, 200, 80)
	assert el.children[1].frame == rect(0, 80, 200, 0)
	assert el.children[2].frame == rect(0, 40, 200, 60)
}

fn test_scaffold_snackbar_margin_clamps_on_narrow_frames() {
	for width in [0.0, 10.0, 32.0] {
		el := scaffold(
			frame:    rect(10, 20, width, 100)
			snackbar: label('snack', 'Saved', rect(0, 0, 100, 40), TextStyle{})
		) or { panic(err) }
		snack := el.children[1]
		assert snack.frame == rect(width / 2, 44, 0, 40)
		assert snack.frame.x + snack.frame.width <= width
	}
}

fn test_vml_plain_scaffold_preserves_direct_child_styles() {
	el := element_from_vml('Scaffold {
		id: app
		Style {
			#app > Label { color: #123456; }
			#app > Label:nth-child(2) { font-size: 22px; }
		}
		Label { id: first text: "One" }
		Label { id: second text: "Two" }
	}', rect(10, 20, 300, 200)) or { panic(err) }
	assert el.children.len == 2
	assert el.children[0].text_style.color == 0x123456
	assert el.children[1].text_style.color == 0x123456
	assert el.children[1].text_style.size == 22
}

fn test_vml_scaffold_snackbar_children_fit_in_inset_width() {
	el := element_from_vml('Scaffold {
		top_bar_height: 56
		bottom_bar_height: 64
		snackbar_margin: 20
		View {
			slot: snackbar
			width: 100
			height: 40
			Label { text: "Saved" }
		}
	}', rect(10, 20, 400, 800)) or { panic(err) }
	snack := el.children[3]
	assert snack.frame == rect(20, 676, 360, 40)
	assert snack.children[0].frame == rect(0, 0, 360, 40)
}

fn test_vml_scaffold_rejects_duplicate_snackbar() {
	if _ := element_from_vml('Scaffold {
		Label { slot: snackbar text: "First" }
		Label { slot: snackbar text: "Second" }
	}', rect(0, 0, 300, 200)) {
		assert false, 'duplicate snackbar accepted'
	} else {
		assert err.msg().contains('at most one snackbar')
	}
}

fn test_vml_scaffold_rejects_bad_sizes_even_without_slots() {
	if _ := element_from_vml('Scaffold { snackbar_margin: -1 }', rect(0, 0, 300, 200)) {
		assert false, 'negative margin accepted'
	} else {
		assert err.msg().contains('finite and non-negative')
	}
}

fn test_scaffold_hidden_fab_does_not_reserve_snackbar_space() {
	el := scaffold(
		frame:           rect(0, 0, 400, 800)
		floating_action: Element{
			...button('add', '+', rect(0, 0, 56, 56), BoxStyle{}, TextStyle{})
			hidden: true
		}
		snackbar:        label('snack', 'Saved', rect(0, 0, 100, 40), TextStyle{})
	) or { panic(err) }
	assert el.children[2].frame == rect(16, 744, 368, 40)
}
