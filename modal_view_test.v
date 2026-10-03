module ui2

fn test_modal_view_centers_hint_sized_content() {
	geometry := modal_view_geometry(
		frame: rect(0, 0, 500, 300)
		size_hint_x: 0.8
		size_hint_y: 0.6
	) or { panic(err) }
	assert geometry.overlay == rect(0, 0, 500, 300)
	assert geometry.content == rect(50, 60, 400, 180)
}

fn test_modal_view_fixed_content_is_clamped_to_overlay() {
	geometry := modal_view_geometry(
		frame: rect(0, 0, 320, 200)
		content_width: 500
		content_height: 120
	) or { panic(err) }
	assert geometry.content == rect(0, 40, 320, 120)
}

fn test_modal_view_constructor_builds_blocking_layers_and_content() {
	modal := modal_view(
		id: 'confirm'
		frame: rect(0, 0, 500, 300)
		open: true
		dismiss_action_id: 'close_modal'
		content_width: 300
		content_height: 160
		overlay_box: BoxStyle{ bg: 0x475569 }
		content_box: BoxStyle{ bg: 0xffffff, radius: 10 }
		content: view('dialog_content', rect(0, 0, 1, 1), BoxStyle{ transparent: true }, [])
	) or { panic(err) }
	assert !modal.hidden
	assert modal.accessibility_role == 'dialog'
	assert modal.children.len == 3
	assert modal.children[0].id == 'confirm__backdrop'
	assert modal.children[0].action_id == 'close_modal'
	assert modal.children[0].frame == rect(0, 0, 500, 300)
	assert modal.children[1].id == 'confirm__surface'
	assert modal.children[1].frame == rect(100, 70, 300, 160)
	assert modal.children[2].id == 'dialog_content'
	assert modal.children[2].frame == rect(100, 70, 300, 160)
}

fn test_modal_view_can_disable_outside_dismissal() {
	modal := modal_view(
		id: 'required'
		frame: rect(0, 0, 300, 200)
		open: true
		auto_dismiss: false
		dismiss_action_id: 'should_not_fire'
	) or { panic(err) }
	assert modal.children[0].action_id == ''
	assert modal.children[0].id == 'required__backdrop'
}

fn test_closed_modal_view_keeps_tree_hidden() {
	modal := modal_view(frame: rect(0, 0, 300, 200)) or { panic(err) }
	assert modal.hidden
	assert modal.children.len == 3
}

fn test_modal_view_rejects_invalid_geometry() {
	if _ := modal_view_geometry(frame: rect(0, 0, 100, 100), size_hint_x: -0.1) {
		assert false, 'negative modal size hints must fail'
	} else {
		assert err.msg().contains('size hints')
	}
}
