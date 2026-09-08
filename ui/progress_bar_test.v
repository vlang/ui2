module ui2

fn test_progress_bar_normalizes_and_clamps_values() {
	assert progress_bar_value_normalized(25, 100) == 0.25
	assert progress_bar_value_normalized(-1, 100) == 0
	assert progress_bar_value_normalized(101, 100) == 1
	assert progress_bar_value_normalized(1, 0) == 0
	assert progress_bar_value_normalized(1, -10) == 0
}

fn test_progress_bar_builds_portable_accessible_geometry() {
	el := progress_bar(
		id: 'upload'
		frame: rect(5, 7, 240, 18)
		value: 75
		max: 200
		background: 0x111827
		color: 0x22c55e
		radius: 9
	)

	assert el.kind == .view
	assert el.id == 'upload'
	assert el.frame == rect(5, 7, 240, 18)
	assert el.box.bg == u32(0x111827)
	assert el.box.radius == 9
	assert el.children.len == 1
	assert el.children[0].frame == rect(0, 0, 90, 18)
	assert el.children[0].box.bg == u32(0x22c55e)
	assert el.accessibility_role == 'progressbar'
	assert el.accessibility_label == 'Progress'
	assert el.accessibility_value == '75 of 200'
	assert !el.clickable
	assert !el.draggable
}

fn test_progress_bar_defaults_to_kivy_max_and_clamps_full_width() {
	el := progress_bar(
		frame: rect(0, 0, 80, 8)
		value: 120
	)

	assert el.children[0].frame.width == 80
	assert el.accessibility_value == '100 of 100'
}
