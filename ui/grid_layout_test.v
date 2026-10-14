module ui2

import math

fn test_grid_layout_requires_a_row_or_column_constraint() {
	if _ := grid_frames(GridConfig{}, 1) {
		assert false, 'an unconstrained grid must fail'
	} else {
		assert err.msg().contains('requires columns or rows')
	}
}

fn test_grid_layout_rejects_children_beyond_fixed_capacity() {
	if _ := grid_frames(GridConfig{ columns: 2, rows: 2 }, 5) {
		assert false, 'a fixed grid must reject excess children'
	} else {
		assert err.msg().contains('only 4 cells')
	}
}

fn test_grid_layout_distributes_space_with_padding_spacing_and_minimums() {
	frames := grid_frames(GridConfig{
		frame:              rect(0, 0, 230, 110)
		columns:            2
		padding:            GridPadding{ left: 10, top: 8, right: 10, bottom: 8 }
		spacing:            GridSpacing{ horizontal: 10, vertical: 6 }
		columns_minimum:    {
			0: 60.0
			1: 80.0
		}
		row_default_height: 20
	}, 4) or { panic(err) }
	assert frames == [rect(10, 8, 90, 44), rect(110, 8, 110, 44), rect(10, 58, 90, 44),
		rect(110, 58, 110, 44)]
}

fn test_grid_layout_can_force_default_axis_sizes() {
	frames := grid_frames(GridConfig{
		frame:                rect(0, 0, 300, 200)
		columns:              2
		column_default_width: 60
		row_default_height:   40
		force_column_width:   true
		force_row_height:     true
		columns_minimum:      {
			1: 80.0
		}
	}, 2) or { panic(err) }
	assert frames == [rect(0, 0, 60, 40), rect(60, 0, 80, 40)]
}

fn test_grid_layout_supports_rows_and_reverse_column_major_flow() {
	frames := grid_frames(GridConfig{
		frame:       rect(0, 0, 200, 100)
		rows:        2
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
	grid := grid(
		id:       'actions'
		frame:    rect(20, 30, 200, 80)
		columns:  2
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

fn test_grid_automatic_columns_follow_width_thresholds_and_shrink_to_one_column() {
	config := GridConfig{
		frame:                  rect(0, 0, 310, 200)
		auto_columns_min_width: 90
		padding:                GridPadding{ left: 10, right: 10 }
		spacing:                GridSpacing{ horizontal: 10 }
	}
	wide := grid_frames(config, 6) or { panic(err) }
	assert wide[0] == rect(10, 0, 90, 100)
	assert wide[2] == rect(210, 0, 90, 100)
	assert wide[3] == rect(10, 100, 90, 100)
	medium := grid_frames(GridConfig{ ...config, frame: rect(0, 0, 309, 210) }, 6) or { panic(err) }
	assert medium[0] == rect(10, 0, 139.5, 70)
	assert medium[2] == rect(10, 70, 139.5, 70)
	narrow := grid_frames(GridConfig{ ...config, frame: rect(0, 0, 100, 240) }, 6) or { panic(err) }
	assert narrow[0] == rect(10, 0, 80, 40)
	assert narrow[5] == rect(10, 200, 80, 40)
}

fn test_grid_automatic_columns_are_limited_to_children_and_maximum() {
	config := GridConfig{
		frame:                  rect(0, 0, 800, 200)
		auto_columns_min_width: 100
	}
	frames := grid_frames(config, 2) or { panic(err) }
	assert frames == [rect(0, 0, 400, 200), rect(400, 0, 400, 200)]
	capped := grid_frames(GridConfig{ ...config, max_columns: 2 }, 5) or { panic(err) }
	assert capped[0].width == 400
	assert capped[2].x == 0
	assert capped[4].y > capped[2].y
	empty := grid_frames(config, 0) or { panic(err) }
	assert empty == []Rect{}
}

fn test_grid_explicit_dimensions_take_precedence_over_automatic_columns() {
	frames := grid_frames(GridConfig{
		frame:                  rect(0, 0, 600, 100)
		columns:                2
		auto_columns_min_width: 50
		max_columns:            1
	}, 2) or { panic(err) }
	assert frames == [rect(0, 0, 300, 100), rect(300, 0, 300, 100)]
}

fn test_grid_automatic_layout_fits_even_below_padding_and_gap_sizes() {
	frames := grid_frames(GridConfig{
		frame:                  rect(0, 0, 6, 10)
		auto_columns_min_width: 100
		padding:                GridPadding{ left: 10, right: 10 }
		spacing:                GridSpacing{ horizontal: 20, vertical: 40 }
		row_default_height:     50
		column_default_width:   100
		columns_minimum:        {
			1: 80.0
		}
	}, 3) or { panic(err) }
	assert frames == [rect(3, 0, 0, 0), rect(3, 5, 0, 0), rect(3, 10, 0, 0)]
	zero := grid_frames(GridConfig{
		frame:                  Rect{}
		auto_columns_min_width: 100
		padding:                GridPadding{ left: 10, top: 8, right: 10, bottom: 8 }
		spacing:                GridSpacing{ horizontal: 20, vertical: 40 }
	}, 3) or { panic(err) }
	assert zero == [Rect{}, Rect{}, Rect{}]
}

fn test_grid_spans_include_gaps_and_fill_available_holes() {
	frames := grid_frames(GridConfig{
		frame:       rect(0, 0, 320, 230)
		columns:     3
		spacing:     GridSpacing{ horizontal: 10, vertical: 10 }
		child_spans: [GridSpan{ column_span: 2, row_span: 2 }]
	}, 5) or { panic(err) }
	assert frames == [rect(0, 0, 210, 150), rect(220, 0, 100, 70), rect(220, 80, 100, 70),
		rect(0, 160, 100, 70), rect(110, 160, 100, 70)]
}

fn test_grid_spans_grow_rows_until_rectangular_children_fit() {
	frames := grid_frames(GridConfig{
		frame:       rect(0, 0, 300, 200)
		columns:     3
		child_spans: [GridSpan{ column_span: 2 }, GridSpan{ column_span: 2 },
			GridSpan{ column_span: 2 }]
	}, 3) or { panic(err) }
	assert frames[0].y == 0
	assert math.abs(frames[1].y - 200.0 / 3) < 0.00001
	assert math.abs(frames[2].y - 400.0 / 3) < 0.00001
	assert frames[2].width == 200
}

fn test_grid_spans_can_grow_columns_and_reverse_column_major_order() {
	frames := grid_frames(GridConfig{
		frame:       rect(0, 0, 300, 200)
		rows:        2
		orientation: .bottom_to_top_right_to_left
		child_spans: [GridSpan{ row_span: 2 }, GridSpan{ column_span: 2 }]
	}, 3) or { panic(err) }
	assert frames == [rect(200, 0, 100, 200), rect(0, 100, 200, 100), rect(100, 0, 100, 100)]
}

fn test_grid_spans_honor_every_orientation() {
	orientations := [GridOrientation.left_to_right_top_to_bottom, .top_to_bottom_left_to_right,
		.right_to_left_top_to_bottom, .top_to_bottom_right_to_left, .left_to_right_bottom_to_top,
		.bottom_to_top_left_to_right, .right_to_left_bottom_to_top, .bottom_to_top_right_to_left]
	first := [rect(0, 0, 200, 100), rect(0, 0, 200, 100), rect(100, 0, 200, 100),
		rect(100, 0, 200, 100), rect(0, 100, 200, 100), rect(0, 100, 200, 100),
		rect(100, 100, 200, 100), rect(100, 100, 200, 100)]
	second := [rect(200, 0, 100, 100), rect(0, 100, 100, 100), rect(0, 0, 100, 100),
		rect(200, 100, 100, 100), rect(200, 100, 100, 100), rect(0, 0, 100, 100),
		rect(0, 100, 100, 100), rect(200, 0, 100, 100)]
	for index, orientation in orientations {
		frames := grid_frames(GridConfig{
			frame:       rect(0, 0, 300, 200)
			columns:     3
			rows:        2
			orientation: orientation
			child_spans: [GridSpan{ column_span: 2 }]
		}, 2) or { panic(err) }
		assert frames == [first[index], second[index]]
	}
}

fn test_grid_automatic_column_spans_contract_on_narrow_windows() {
	config := GridConfig{
		frame:                  rect(0, 0, 300, 200)
		auto_columns_min_width: 100
		child_spans:            [GridSpan{ column_span: 2 }]
	}
	wide := grid_frames(config, 3) or { panic(err) }
	assert wide == [rect(0, 0, 200, 100), rect(200, 0, 100, 100), rect(0, 100, 100, 100)]
	narrow := grid_frames(GridConfig{ ...config, frame: rect(0, 0, 80, 300) }, 3) or { panic(err) }
	assert narrow == [rect(0, 0, 80, 100), rect(0, 100, 80, 100), rect(0, 200, 80, 100)]
}

fn test_grid_rejects_spans_that_cannot_fit_explicit_dimensions() {
	for config in [
		GridConfig{ columns: 2, child_spans: [GridSpan{ column_span: 3 }] },
		GridConfig{ rows: 2, child_spans: [GridSpan{ row_span: 3 }] },
		GridConfig{
			columns:     3
			rows:        2
			child_spans: [GridSpan{ column_span: 2, row_span: 2 }, GridSpan{ column_span: 2 }]
		},
	] {
		count := config.child_spans.len
		if _ := grid_frames(config, count) {
			assert false, 'invalid fixed grid must fail'
		}
	}
}

fn test_grid_rejects_non_finite_dimensions_and_invalid_spans() {
	for config in [
		GridConfig{ columns: 1, frame: rect(0, 0, math.inf(1), 100) },
		GridConfig{ columns: 1, padding: GridPadding{ left: math.nan() } },
		GridConfig{ columns: 1, spacing: GridSpacing{ horizontal: -1 } },
		GridConfig{ columns: 1, auto_columns_min_width: math.nan() },
		GridConfig{ columns: 1, max_columns: -1 },
		GridConfig{ columns: 1, child_spans: [GridSpan{ column_span: 0 }] },
		GridConfig{ columns: 1, child_spans: [GridSpan{ row_span: -1 }] },
		GridConfig{ columns: 1, child_spans: [GridSpan{}, GridSpan{}] },
	] {
		if _ := grid_frames(config, 1) {
			assert false, 'invalid grid input must fail'
		}
	}
}

fn test_grid_rejects_span_area_overflow_before_allocating_occupancy() {
	if _ := grid_frames(GridConfig{
		columns:     50000
		child_spans: [GridSpan{ column_span: 50000, row_span: 50000 }]
	}, 1) {
		assert false, 'span area beyond the array index range must fail'
	} else {
		assert err.msg().contains('too large')
	}
}

fn test_grid_preferred_size_measures_children_and_spans_at_responsive_width() {
	config := GridConfig{
		frame:                  rect(0, 0, 310, 0)
		auto_columns_min_width: 90
		padding:                GridPadding{ left: 10, top: 5, right: 10, bottom: 5 }
		spacing:                GridSpacing{ horizontal: 10, vertical: 10 }
		child_spans:            [GridSpan{ column_span: 2 }]
	}
	sizes := [rect(0, 0, 190, 40), rect(0, 0, 90, 20), rect(0, 0, 90, 30)]
	wide := grid_preferred_size(config, sizes) or { panic(err) }
	assert wide == rect(0, 0, 310, 100)
	narrow := grid_preferred_size(GridConfig{ ...config, frame: rect(0, 0, 100, 0) }, sizes) or { panic(err) }
	assert narrow == rect(0, 0, 210, 150)
	placed := grid_frames(GridConfig{ ...config, frame: wide }, sizes.len) or { panic(err) }
	for index, frame in placed {
		assert frame.width >= sizes[index].width
		assert frame.height >= sizes[index].height
	}
}

fn test_grid_preferred_size_respects_forced_tracks_and_minimums() {
	preferred := grid_preferred_size(GridConfig{
		columns:              2
		column_default_width: 50
		row_default_height:   20
		force_column_width:   true
		force_row_height:     true
		columns_minimum:      {
			1: 80.0
		}
		rows_minimum:         {
			1: 30.0
		}
		spacing:              GridSpacing{ horizontal: 10, vertical: 5 }
	}, [rect(0, 0, 200, 100), rect(0, 0, 200, 100), rect(0, 0, 200, 100)]) or { panic(err) }
	assert preferred == rect(0, 0, 140, 55)
}

fn test_automatic_grid_preserves_fractional_capacity_and_edges() {
	frames := grid_frames(GridConfig{ frame: rect(0, 0, 100.5, 20.5), auto_columns_min_width: 50.25 }, 2)!
	assert frames == [rect(0, 0, 50.25, 20.5), rect(50.25, 0, 50.25, 20.5)]
	tiny := grid_frames(GridConfig{ frame: rect(0, 0, 0.75, 0.5), auto_columns_min_width: 0.1, spacing: GridSpacing{ horizontal: 0.5 } }, 2)!
	assert tiny == [rect(0, 0, 0.125, 0.5), rect(0.625, 0, 0.125, 0.5)]
}

fn test_grid_intrinsic_spans_keep_fractional_content_size() {
	preferred := grid_preferred_size(GridConfig{ columns: 2, child_spans: [GridSpan{ column_span: 2 }] }, [rect(0, 0, 3.5, 2.25)])!
	assert preferred == rect(0, 0, 3.5, 2.25)
}
