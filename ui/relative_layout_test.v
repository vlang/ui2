module ui2

fn test_relative_layout_keeps_children_in_local_coordinates() {
	config := RelativeLayoutConfig{
		frame: rect(80, 60, 240, 120)
		children: [FloatLayoutChild{
			element: view('child', rect(20, 15, 80, 30), BoxStyle{}, [])
			size_hint_x: -1
			size_hint_y: -1
		}]
	}
	frames := relative_layout_frames(config) or { panic(err) }
	assert frames == [rect(20, 15, 80, 30)]
}

fn test_relative_layout_supports_parent_relative_hints() {
	config := RelativeLayoutConfig{
		frame: rect(80, 60, 240, 120)
		children: [FloatLayoutChild{
			element: view('child', rect(0, 0, 80, 30), BoxStyle{}, [])
			size_hint_x: -1
			size_hint_y: -1
			x_hint: FloatAxisHint{ anchor: .center, value: 0.5 }
			y_hint: FloatAxisHint{ anchor: .end, value: 1 }
		}]
	}
	assert relative_layout_frames(config)! == [rect(80, 90, 80, 30)]
}

fn test_relative_layout_constructor_preserves_parent_and_child_frames() {
	layout := relative_layout(
		id: 'panel'
		frame: rect(40, 50, 200, 100)
		children: [FloatLayoutChild{
			element: button('action', 'Action', rect(8, 10, 72, 30), BoxStyle{}, TextStyle{})
			size_hint_x: -1
			size_hint_y: -1
		}]
	) or { panic(err) }
	assert layout.frame == rect(40, 50, 200, 100)
	assert layout.children[0].frame == rect(8, 10, 72, 30)
	assert layout.children[0].text == 'Action'
}
