module ui2

fn box_test_child(id string, width f64, height f64) Element {
	return view(id, rect(0, 0, width, height), BoxStyle{}, [])
}

fn test_box_layout_distributes_space_after_fixed_children() {
	config := BoxLayoutConfig{
		frame: rect(0, 0, 330, 80)
		padding: BoxPadding{ left: 10, top: 5, right: 10, bottom: 5 }
		spacing: 10
		children: [
			BoxLayoutChild{ element: box_test_child('fixed', 80, 20), size_hint_x: -1 },
			BoxLayoutChild{ element: box_test_child('wide', 1, 20), size_hint_x: 2 },
			BoxLayoutChild{ element: box_test_child('narrow', 1, 20), size_hint_x: 1 },
		]
	}
	frames := box_layout_frames(config) or { panic(err) }
	assert frames == [rect(10, 5, 80, 70), rect(100, 5, 140, 70), rect(250, 5, 70, 70)]
}

fn test_box_layout_honors_bounds_and_redistributes_remaining_space() {
	config := BoxLayoutConfig{
		frame: rect(0, 0, 300, 60)
		children: [
			BoxLayoutChild{ element: box_test_child('limited', 1, 20), maximum_width: 80 },
			BoxLayoutChild{ element: box_test_child('remaining', 1, 20) },
		]
	}
	frames := box_layout_frames(config) or { panic(err) }
	assert frames[0].width == 80
	assert frames[1].width == 220
}

fn test_vertical_box_layout_supports_fixed_cross_size_and_alignment() {
	config := BoxLayoutConfig{
		frame: rect(0, 0, 200, 120)
		orientation: .vertical
		padding: BoxPadding{ left: 10, top: 10, right: 10, bottom: 10 }
		spacing: 4
		children: [
			BoxLayoutChild{
				element: box_test_child('centered', 60, 20)
				size_hint_x: -1
				size_hint_y: -1
				horizontal_align: .center
			},
			BoxLayoutChild{ element: box_test_child('fill', 1, 1) },
		]
	}
	frames := box_layout_frames(config) or { panic(err) }
	assert frames == [rect(70, 10, 60, 20), rect(10, 34, 180, 76)]
}

fn test_box_layout_reports_minimum_size_and_preserves_content() {
	config := BoxLayoutConfig{
		frame: rect(0, 0, 200, 80)
		padding: BoxPadding{ left: 5, top: 6, right: 7, bottom: 8 }
		spacing: 4
		children: [
			BoxLayoutChild{
				element: button('fixed', 'Fixed', rect(0, 0, 60, 30), BoxStyle{}, TextStyle{})
				size_hint_x: -1
				size_hint_y: -1
			},
			BoxLayoutChild{
				element: button('flex', 'Flexible', rect(0, 0, 10, 20), BoxStyle{}, TextStyle{})
				minimum_width: 40
				minimum_height: 24
			},
		]
	}
	assert box_layout_minimum_size(config)! == rect(0, 0, 116, 44)
	box := box_layout(config) or { panic(err) }
	assert box.children[0].text == 'Fixed'
	assert box.children[1].frame.width == 124
}

fn test_box_layout_rejects_invalid_bounds() {
	config := BoxLayoutConfig{
		frame: rect(0, 0, 100, 40)
		children: [BoxLayoutChild{
			element: box_test_child('invalid', 10, 10)
			minimum_width: 30
			maximum_width: 20
		}]
	}
	if _ := box_layout_frames(config) {
		assert false, 'invalid bounds must fail'
	} else {
		assert err.msg().contains('minimum width')
	}
}

fn test_box_layout_never_assigns_negative_space_after_fixed_overflow() {
	config := BoxLayoutConfig{
		frame: rect(0, 0, 100, 40)
		children: [
			BoxLayoutChild{
				element: box_test_child('oversized', 120, 20)
				size_hint_x: -1
			},
			BoxLayoutChild{ element: box_test_child('flexible', 1, 20) },
		]
	}
	frames := box_layout_frames(config) or { panic(err) }
	assert frames[0].width == 120
	assert frames[1].width == 0
}
