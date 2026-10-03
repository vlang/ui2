module ui2

fn test_grid_layout_requires_a_row_or_column_constraint() {
	if _ := grid_layout_frames(GridLayoutConfig{}, 1) {
		assert false, 'an unconstrained grid must fail'
	} else {
		assert err.msg().contains('requires columns or rows')
	}
}

fn test_grid_layout_rejects_children_beyond_fixed_capacity() {
	if _ := grid_layout_frames(GridLayoutConfig{ columns: 2, rows: 2 }, 5) {
		assert false, 'a fixed grid must reject excess children'
	} else {
		assert err.msg().contains('only 4 cells')
	}
}

fn test_grid_layout_distributes_space_with_padding_spacing_and_minimums() {
	frames := grid_layout_frames(GridLayoutConfig{
		frame: rect(0, 0, 230, 110)
		columns: 2
		padding: GridPadding{ left: 10, top: 8, right: 10, bottom: 8 }
		spacing: GridSpacing{ horizontal: 10, vertical: 6 }
		columns_minimum: {
			0: 60.0
			1: 80.0
		}
		row_default_height: 20
	}, 4) or { panic(err) }
	assert frames == [rect(10, 8, 90, 44), rect(110, 8, 110, 44), rect(10, 58, 90, 44),
		rect(110, 58, 110, 44)]
}

fn test_grid_layout_can_force_default_axis_sizes() {
	frames := grid_layout_frames(GridLayoutConfig{
		frame: rect(0, 0, 300, 200)
		columns: 2
		column_default_width: 60
		row_default_height: 40
		force_column_width: true
		force_row_height: true
		columns_minimum: {
			1: 80.0
		}
	}, 2) or { panic(err) }
	assert frames == [rect(0, 0, 60, 40), rect(60, 0, 80, 40)]
}

fn test_grid_layout_supports_rows_and_reverse_column_major_flow() {
	frames := grid_layout_frames(GridLayoutConfig{
		frame: rect(0, 0, 200, 100)
		rows: 2
		orientation: .bottom_to_top_right_to_left
	}, 4) or { panic(err) }
	assert frames == [rect(100, 50, 100, 50), rect(100, 0, 100, 50), rect(0, 50, 100, 50),
		rect(0, 0, 100, 50)]
}

fn grid_test_cell_order(orientation GridOrientation) []int {
	mut order := []int{cap: 6}
	for index in 0 .. 6 {
		column, row := grid_cell_coordinates(index, 3, 2, orientation)
		order << row * 3 + column
	}
	return order
}

fn test_grid_layout_supports_all_fill_orientations() {
	assert grid_test_cell_order(.left_to_right_top_to_bottom) == [0, 1, 2, 3, 4, 5]
	assert grid_test_cell_order(.top_to_bottom_left_to_right) == [0, 3, 1, 4, 2, 5]
	assert grid_test_cell_order(.right_to_left_top_to_bottom) == [2, 1, 0, 5, 4, 3]
	assert grid_test_cell_order(.top_to_bottom_right_to_left) == [2, 5, 1, 4, 0, 3]
	assert grid_test_cell_order(.left_to_right_bottom_to_top) == [3, 4, 5, 0, 1, 2]
	assert grid_test_cell_order(.bottom_to_top_left_to_right) == [3, 0, 4, 1, 5, 2]
	assert grid_test_cell_order(.right_to_left_bottom_to_top) == [5, 4, 3, 2, 1, 0]
	assert grid_test_cell_order(.bottom_to_top_right_to_left) == [5, 2, 4, 1, 3, 0]
}

fn test_grid_layout_replaces_child_frames_and_preserves_content() {
	grid := grid_layout(
		id: 'actions'
		frame: rect(20, 30, 200, 80)
		columns: 2
		children: [
			button('one', 'One', Rect{}, BoxStyle{}, TextStyle{}),
			button('two', 'Two', Rect{}, BoxStyle{}, TextStyle{}),
		]
	) or { panic(err) }
	assert grid.kind == .view
	assert grid.frame == rect(20, 30, 200, 80)
	assert grid.children[0].text == 'One'
	assert grid.children[0].frame == rect(0, 0, 100, 80)
	assert grid.children[1].frame == rect(100, 0, 100, 80)
}
