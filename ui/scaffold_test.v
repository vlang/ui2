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
	assert snack.frame == rect(16, 680, 368, 40)
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
	assert el.children[0].children[0].text == 'Hello'
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
	assert el.children[3].frame == rect(328, 664, 56, 56)
}

fn test_vml_scaffold_rejects_duplicate_and_unknown_slots() {
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
