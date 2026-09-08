module ui2

fn float_test_child(id string, frame Rect) Element {
	return view(id, frame, BoxStyle{}, [])
}

fn test_float_layout_applies_size_and_position_hints() {
	config := FloatLayoutConfig{
		frame: rect(0, 0, 300, 200)
		children: [
			FloatLayoutChild{
				element: float_test_child('card', rect(12, 18, 40, 30))
				size_hint_x: 0.5
				size_hint_y: 0.25
				x_hint: FloatAxisHint{ anchor: .center, value: 0.5 }
				y_hint: FloatAxisHint{ anchor: .center, value: 0.5 }
			},
		]
	}
	assert float_layout_frames(config)! == [rect(75, 75, 150, 50)]
}

fn test_float_layout_preserves_declared_axes_without_hints() {
	config := FloatLayoutConfig{
		frame: rect(0, 0, 300, 200)
		children: [
			FloatLayoutChild{
				element: float_test_child('fixed', rect(20, 30, 80, 40))
				size_hint_x: -1
				size_hint_y: -1
			},
		]
	}
	assert float_layout_frames(config)! == [rect(20, 30, 80, 40)]
}

fn test_float_layout_supports_edge_hints_and_size_bounds() {
	config := FloatLayoutConfig{
		frame: rect(0, 0, 300, 200)
		children: [
			FloatLayoutChild{
				element: float_test_child('bounded', rect(0, 0, 20, 20))
				size_hint_x: 0.9
				size_hint_y: 0.1
				maximum_width: 120
				minimum_height: 32
				x_hint: FloatAxisHint{ anchor: .end, value: 1 }
				y_hint: FloatAxisHint{ anchor: .end, value: 1 }
			},
		]
	}
	assert float_layout_frames(config)! == [rect(180, 168, 120, 32)]
}

fn test_float_layout_constructor_preserves_child_content() {
	child := button('save', 'Save', rect(0, 0, 80, 32), BoxStyle{}, TextStyle{})
	layout := float_layout(
		id: 'canvas'
		frame: rect(0, 0, 200, 100)
		children: [FloatLayoutChild{
			element: child
			size_hint_x: -1
			size_hint_y: -1
			x_hint: FloatAxisHint{ anchor: .end, value: 1 }
		}]
	) or { panic(err) }
	assert layout.children[0].text == 'Save'
	assert layout.children[0].frame == rect(120, 0, 80, 32)
}
