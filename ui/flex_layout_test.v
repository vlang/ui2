module ui2

import math

fn flex_test_child(width f64, height f64) Element {
	return view('child', rect(17, 23, width, height), BoxStyle{}, [])
}

fn flex_test_near(actual f64, expected f64) {
	assert math.abs(actual - expected) < 0.000001, 'expected ${expected}, got ${actual}'
}

fn test_flex_grow_preserves_bases_and_redistributes_at_multiple_bounds() {
	frames := flex_frames(FlexConfig{
		frame:    rect(100, 200, 420, 80)
		padding:  LayoutPadding{ left: 10, top: 5, right: 10, bottom: 5 }
		gap:      10
		children: [
			FlexChild{ element: flex_test_child(40, 20), grow: 1, maximum_width: 60 },
			FlexChild{ element: flex_test_child(40, 20), grow: 1, maximum_width: 100 },
			FlexChild{ element: flex_test_child(40, 20), grow: 2 },
		]
	}) or { panic(err) }
	assert frames == [rect(10, 5, 60, 70), rect(80, 5, 100, 70), rect(190, 5, 220, 70)]
}

fn test_flex_shrink_is_basis_weighted_and_redistributes_at_minimum() {
	frames := flex_frames(FlexConfig{
		frame:    rect(0, 0, 150, 30)
		children: [
			FlexChild{ element: flex_test_child(100, 10), minimum_width: 80 },
			FlexChild{ element: flex_test_child(200, 10) },
		]
	}) or { panic(err) }
	assert frames == [rect(0, 0, 80, 30), rect(80, 0, 70, 30)]
	weighted := flex_frames(FlexConfig{
		frame:    rect(0, 0, 225, 30)
		children: [
			FlexChild{ element: flex_test_child(100, 10) },
			FlexChild{ element: flex_test_child(200, 10) },
		]
	}) or { panic(err) }
	assert weighted[0].width == 75
	assert weighted[1].width == 150
}

fn test_flex_shrink_respects_weights_disabled_shrink_and_explicit_basis() {
	frames := flex_frames(FlexConfig{
		frame:    rect(0, 0, 250, 30)
		children: [
			FlexChild{ element: flex_test_child(20, 10), basis: 100, shrink: 0 },
			FlexChild{ element: flex_test_child(100, 10), shrink: 1 },
			FlexChild{ element: flex_test_child(100, 10), shrink: 3 },
		]
	}) or { panic(err) }
	assert frames[0].width == 100
	assert frames[1].width == 87.5
	assert frames[2].width == 62.5
}

fn test_flex_wrap_uses_bounded_bases_and_grows_each_line_independently() {
	frames := flex_frames(FlexConfig{
		frame:    rect(0, 0, 210, 200)
		gap:      10
		line_gap: 7
		wrap:     true
		align:    .center
		children: [
			FlexChild{ element: flex_test_child(100, 20), grow: 1 },
			FlexChild{ element: flex_test_child(100, 40), grow: 1 },
			FlexChild{ element: flex_test_child(130, 30), maximum_width: 100, grow: 1 },
		]
	}) or { panic(err) }
	assert frames == [rect(0, 10, 100, 20), rect(110, 0, 100, 40), rect(0, 47, 100, 30)]
}

fn test_flex_wrap_shrinks_oversized_item_without_empty_line() {
	frames := flex_frames(FlexConfig{
		frame:    rect(0, 0, 100, 100)
		gap:      8
		wrap:     true
		children: [
			FlexChild{ element: flex_test_child(200, 20) },
			FlexChild{ element: flex_test_child(40, 30), grow: 1 },
		]
	}) or { panic(err) }
	assert frames == [rect(0, 0, 100, 20), rect(0, 28, 100, 30)]
}

fn test_vertical_flex_wrap_and_alignment_are_axis_independent() {
	frames := flex_frames(FlexConfig{
		frame:       rect(20, 20, 200, 130)
		orientation: .vertical
		padding:     LayoutPadding{ left: 5, top: 10, right: 5, bottom: 10 }
		gap:         10
		line_gap:    15
		wrap:        true
		align:       .end
		children:    [
			FlexChild{ element: flex_test_child(20, 50) },
			FlexChild{ element: flex_test_child(40, 50) },
			FlexChild{ element: flex_test_child(30, 50), grow: 1 },
		]
	}) or { panic(err) }
	assert frames == [rect(25, 10, 20, 50), rect(5, 70, 40, 50), rect(60, 10, 30, 110)]
}

fn test_flex_justification_and_child_alignment() {
	base := FlexConfig{
		frame:    rect(0, 0, 200, 80)
		gap:      10
		align:    .center
		children: [
			FlexChild{ element: flex_test_child(40, 20) },
			FlexChild{ element: flex_test_child(40, 20), align_self: .end },
		]
	}
	expected_x := [[0.0, 50.0], [55.0, 105.0], [110.0, 160.0], [0.0, 160.0], [27.5, 132.5],
		[110.0 / 3, 50.0 + 220.0 / 3]]
	for index, justify in [FlexJustify.start, .center, .end, .space_between, .space_around,
		.space_evenly] {
		frames := flex_frames(FlexConfig{ ...base, justify: justify }) or { panic(err) }
		flex_test_near(frames[0].x, expected_x[index][0])
		flex_test_near(frames[1].x, expected_x[index][1])
		assert frames[0].y == 30
		assert frames[1].y == 60
	}
	stretched := flex_frames(FlexConfig{
		...base
		children: [FlexChild{
			element:        flex_test_child(40, 20)
			align_self:     .stretch
			maximum_height: 50
		}]
	}) or { panic(err) }
	assert stretched == [rect(0, 0, 40, 50)]
}

fn test_flex_small_viewports_keep_nonnegative_sizes_and_explicit_minimum_overflow() {
	frames := flex_frames(FlexConfig{
		frame:    rect(0, 0, 0, 0)
		padding:  LayoutPadding{ left: 10, top: 10, right: 10, bottom: 10 }
		gap:      10
		justify:  .center
		children: [
			FlexChild{ element: flex_test_child(100, 20), minimum_width: 20, minimum_height: 5 },
			FlexChild{ element: flex_test_child(100, 20) },
		]
	}) or { panic(err) }
	assert frames == [rect(10, 10, 20, 5), rect(40, 10, 0, 0)]
}

fn test_flex_preferred_size_and_element_preserve_declared_content() {
	config := FlexConfig{
		id:       'flex'
		frame:    rect(20, 30, 300, 60)
		padding:  LayoutPadding{ left: 5, top: 6, right: 7, bottom: 8 }
		gap:      10
		children: [
			FlexChild{
				element: button('a', 'Accept', rect(4, 8, 60, 20), BoxStyle{}, TextStyle{})
				basis:   80
				grow:    1
			},
			FlexChild{
				element: button('b', 'Cancel', rect(4, 8, 70, 30), BoxStyle{}, TextStyle{})
				grow:    1
			},
		]
	}
	assert flex_preferred_size(config)! == rect(0, 0, 172, 44)
	layout := flex(config) or { panic(err) }
	assert layout.id == 'flex'
	assert layout.frame == config.frame
	assert layout.children[0].id == 'a'
	assert layout.children[0].text == 'Accept'
	assert layout.children[1].text == 'Cancel'
	assert layout.children[0].frame == rect(5, 6, 144, 46)
	assert layout.children[1].frame == rect(159, 6, 134, 46)
}

fn test_flex_empty_and_single_item_justification() {
	assert flex_frames(FlexConfig{})! == []Rect{}
	assert flex_preferred_size(FlexConfig{})! == rect(0, 0, 0, 0)
	for justify in [FlexJustify.space_around, .space_evenly] {
		frames := flex_frames(FlexConfig{
			frame:    rect(0, 0, 100, 40)
			justify:  justify
			children: [FlexChild{ element: flex_test_child(20, 10) }]
		}) or { panic(err) }
		assert frames == [rect(40, 0, 20, 40)]
	}
}

fn test_flex_large_weights_stay_finite() {
	frames := flex_frames(FlexConfig{
		frame:    rect(0, 0, 50, 30)
		children: [
			FlexChild{ element: flex_test_child(100, 10), shrink: 1.0e308 },
			FlexChild{ element: flex_test_child(100, 10), shrink: 1.0e308 },
		]
	}) or { panic(err) }
	assert frames == [rect(0, 0, 25, 30), rect(25, 0, 25, 30)]
}

fn test_flex_rejects_invalid_numeric_inputs_and_bounds() {
	base := FlexConfig{ frame: rect(0, 0, 100, 40) }
	invalid_configs := [
		FlexConfig{ ...base, frame: rect(0, 0, -1, 40) },
		FlexConfig{ ...base, frame: rect(0, 0, math.inf(1), 40) },
		FlexConfig{ ...base, padding: LayoutPadding{ left: -1 } },
		FlexConfig{ ...base, padding: LayoutPadding{ top: math.nan() } },
		FlexConfig{ ...base, gap: -1 },
		FlexConfig{ ...base, line_gap: -2 },
		FlexConfig{ ...base, align: .auto },
	]
	for config in invalid_configs {
		if _ := flex_frames(config) {
			assert false, 'invalid config must fail'
		}
	}
	child := FlexChild{ element: flex_test_child(10, 10) }
	invalid_children := [
		FlexChild{ ...child, basis: -2 },
		FlexChild{ ...child, basis: math.nan() },
		FlexChild{ ...child, grow: -1 },
		FlexChild{ ...child, shrink: math.inf(1) },
		FlexChild{ ...child, minimum_width: -1 },
		FlexChild{ ...child, maximum_height: -2 },
		FlexChild{ ...child, minimum_width: 20, maximum_width: 10 },
		FlexChild{ ...child, minimum_height: 20, maximum_height: 10 },
	]
	for invalid in invalid_children {
		if _ := flex_frames(FlexConfig{ ...base, children: [invalid] }) {
			assert false, 'invalid child must fail'
		}
	}
}
