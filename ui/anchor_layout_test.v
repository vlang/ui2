module ui2

fn test_anchor_layout_centers_children_inside_asymmetric_padding() {
	config := AnchorLayoutConfig{
		frame: rect(20, 30, 240, 140)
		padding: AnchorPadding{ left: 10, top: 20, right: 30, bottom: 40 }
	}
	assert anchor_layout_frame(config, rect(0, 0, 80, 30)) == rect(70, 45, 80, 30)
}

fn test_anchor_layout_places_children_at_each_edge() {
	child := rect(0, 0, 50, 20)
	top_left := AnchorLayoutConfig{
		frame: rect(0, 0, 200, 100)
		anchor_x: .left
		anchor_y: .top
		padding: AnchorPadding{ left: 8, top: 6, right: 10, bottom: 12 }
	}
	assert anchor_layout_frame(top_left, child) == rect(8, 6, 50, 20)
	bottom_right := AnchorLayoutConfig{
		...top_left
		anchor_x: .right
		anchor_y: .bottom
	}
	assert anchor_layout_frame(bottom_right, child) == rect(140, 68, 50, 20)
}

fn test_anchor_layout_preserves_child_sizes_and_content() {
	anchored := anchor_layout(
		id: 'footer'
		frame: rect(10, 10, 200, 80)
		anchor_x: .right
		anchor_y: .bottom
		children: [
			button('save', 'Save', rect(4, 5, 72, 32), BoxStyle{}, TextStyle{}),
		]
	)
	assert anchored.kind == .view
	assert anchored.children[0].text == 'Save'
	assert anchored.children[0].frame == rect(128, 48, 72, 32)
}

fn test_anchor_names_are_validated() {
	assert horizontal_anchor('left')! == .left
	assert vertical_anchor('bottom')! == .bottom
	if _ := horizontal_anchor('middle') {
		assert false, 'unknown anchors must fail'
	} else {
		assert err.msg().contains('middle')
	}
}
