module ui2

fn test_stack_layout_wraps_variable_width_children() {
	config := StackLayoutConfig{
		frame: rect(0, 0, 180, 120)
		padding: StackPadding{ left: 10, top: 8, right: 10, bottom: 8 }
		spacing: StackSpacing{ horizontal: 6, vertical: 4 }
	}
	sizes := [rect(0, 0, 70, 20), rect(0, 0, 80, 30), rect(0, 0, 90, 24)]
	frames := stack_layout_frames(config, sizes) or { panic(err) }
	assert frames == [rect(10, 8, 70, 20), rect(86, 8, 80, 30), rect(10, 42, 90, 24)]
	assert stack_layout_minimum_size(config, sizes)! == rect(0, 0, 176, 74)
}

fn test_stack_layout_supports_reverse_horizontal_and_vertical_flow() {
	config := StackLayoutConfig{
		frame: rect(0, 0, 180, 120)
		orientation: .right_to_left_bottom_to_top
		padding: StackPadding{ left: 10, top: 8, right: 10, bottom: 8 }
		spacing: StackSpacing{ horizontal: 6, vertical: 4 }
	}
	sizes := [rect(0, 0, 70, 20), rect(0, 0, 80, 30), rect(0, 0, 90, 24)]
	frames := stack_layout_frames(config, sizes) or { panic(err) }
	assert frames == [rect(100, 92, 70, 20), rect(14, 82, 80, 30), rect(80, 54, 90, 24)]
}

fn test_stack_layout_wraps_column_major_children() {
	config := StackLayoutConfig{
		frame: rect(0, 0, 160, 100)
		orientation: .top_to_bottom_left_to_right
		spacing: StackSpacing{ horizontal: 5, vertical: 4 }
	}
	sizes := [rect(0, 0, 30, 40), rect(0, 0, 50, 50), rect(0, 0, 40, 30)]
	frames := stack_layout_frames(config, sizes) or { panic(err) }
	assert frames == [rect(0, 0, 30, 40), rect(0, 44, 50, 50), rect(55, 0, 40, 30)]
}

fn test_stack_layout_preserves_sizes_and_content() {
	stack := stack_layout(
		id: 'tags'
		frame: rect(0, 0, 150, 80)
		spacing: StackSpacing{ horizontal: 4 }
		children: [
			button('one', 'One', rect(0, 0, 70, 30), BoxStyle{}, TextStyle{}),
			button('two', 'Two', rect(0, 0, 80, 30), BoxStyle{}, TextStyle{}),
		]
	) or { panic(err) }
	assert stack.children[0].frame == rect(0, 0, 70, 30)
	assert stack.children[1].frame == rect(0, 30, 80, 30)
	assert stack.children[1].text == 'Two'
}
