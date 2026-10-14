module ui2

fn flex_intrinsic_fixture_measure(_text string, _style TextStyle, width f64) !LayoutSize {
	return if width < 0 {
		LayoutSize{ width: 120, height: 20 }
	} else {
		LayoutSize{ width: width, height: if width < 60 { 40.0 } else { 20.0 } }
	}
}

fn test_flex_intrinsic_children_are_remeasured_at_assigned_width() {
	label := label('description', 'wraps at narrow widths', Rect{}, TextStyle{ lines: 3 })
	preferred := measure_layout_element(label, LayoutConstraints{}, flex_intrinsic_fixture_measure)!
	config := FlexConfig{
		frame:    rect(0, 0, 100, 50)
		gap:      10
		align:    .start
		children: [
			FlexChild{ element: Element{ ...label, frame: rect(0, 0, preferred.width, preferred.height) }, basis: 0, grow: 1 },
			FlexChild{ element: view('peer', rect(0, 0, 100, 20), BoxStyle{}, []Element{}), basis: 0, grow: 1 },
		]
	}
	assigned := flex_frames(config)!
	assert assigned[0].width == 45 && assigned[1].x == 55
	measured := measure_layout_element(label, LayoutConstraints{ max_width: assigned[0].width }, flex_intrinsic_fixture_measure)!
	assert measured.width == 45 && measured.height == 40
	root := flex(FlexConfig{
		...config
		children: [
			FlexChild{ ...config.children[0], element: Element{ ...label, frame: rect(0, 0, measured.width, measured.height) } },
			config.children[1],
		]
	})!
	assert root.children[0].frame == rect(0, 0, 45, 40)
	assert root.children[1].frame == rect(55, 0, 45, 20)
	assert root.children[0].id == 'description' && root.children[0].text == label.text
}
