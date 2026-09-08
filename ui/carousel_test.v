module ui2

fn carousel_test_slides(count int) []Element {
	mut slides := []Element{cap: count}
	for index in 0 .. count {
		slides << view('slide_${index}', rect(0, 0, 1, 1), BoxStyle{}, [])
	}
	return slides
}

fn test_carousel_frames_follow_all_directions() {
	slides := carousel_test_slides(3)
	right := carousel_frames(
		frame: rect(0, 0, 300, 160)
		index: 1
		slides: slides
	) or { panic(err) }
	assert right == [rect(-300, 0, 300, 160), rect(0, 0, 300, 160), rect(300, 0, 300, 160)]
	left := carousel_frames(
		frame: rect(0, 0, 300, 160)
		index: 1
		direction: .left
		slides: slides
	) or { panic(err) }
	assert left == [rect(300, 0, 300, 160), rect(0, 0, 300, 160), rect(-300, 0, 300, 160)]
	top := carousel_frames(
		frame: rect(0, 0, 300, 160)
		index: 1
		direction: .top
		slides: slides
	) or { panic(err) }
	assert top == [rect(0, 160, 300, 160), rect(0, 0, 300, 160), rect(0, -160, 300, 160)]
	bottom := carousel_frames(
		frame: rect(0, 0, 300, 160)
		index: 1
		direction: .bottom
		slides: slides
	) or { panic(err) }
	assert bottom == [rect(0, -160, 300, 160), rect(0, 0, 300, 160), rect(0, 160, 300, 160)]
}

fn test_carousel_index_navigation_clamps_or_loops() {
	assert carousel_index(-2, 3, false) == 0
	assert carousel_index(8, 3, false) == 2
	assert carousel_index(-1, 3, true) == 2
	assert carousel_next(2, 3, false) == 2
	assert carousel_next(2, 3, true) == 0
	assert carousel_previous(0, 3, false) == 0
	assert carousel_previous(0, 3, true) == 2
}

fn test_looping_carousel_places_wrapped_neighbors_on_each_side() {
	frames := carousel_frames(
		frame: rect(0, 0, 300, 160)
		loop: true
		slides: carousel_test_slides(3)
	) or { panic(err) }
	assert frames[0] == rect(0, 0, 300, 160)
	assert frames[1] == rect(300, 0, 300, 160)
	assert frames[2] == rect(-300, 0, 300, 160)
}

fn test_carousel_swipe_threshold_and_direction() {
	config := CarouselConfig{
		frame: rect(0, 0, 300, 160)
		index: 1
		min_move: 0.2
		slides: carousel_test_slides(3)
	}
	assert carousel_index_after_swipe(config, -61, 0)! == 2
	assert carousel_index_after_swipe(config, 61, 0)! == 0
	assert carousel_index_after_swipe(config, -60, 0)! == 1
	assert carousel_index_after_swipe(CarouselConfig{
		...config
		direction: .top
	}, 0, 33)! == 2
	assert carousel_index_after_swipe(CarouselConfig{
		...config
		ignore_perpendicular_swipes: true
	}, -100, 150)! == 1
}

fn test_carousel_constructor_hides_inactive_slides() {
	result := carousel(
		id: 'gallery'
		frame: rect(10, 20, 300, 160)
		index: 1
		slides: carousel_test_slides(3)
	) or { panic(err) }
	assert result.frame == rect(10, 20, 300, 160)
	assert result.children.len == 3
	assert result.children[0].hidden
	assert !result.children[1].hidden
	assert result.children[2].hidden
	assert result.accessibility_value == 'Slide 2 of 3'
}

fn test_carousel_preserves_explicitly_hidden_active_slide() {
	result := carousel(
		frame: rect(0, 0, 100, 100)
		slides: [Element{
			...view('hidden', rect(0, 0, 1, 1), BoxStyle{}, [])
			hidden: true
		}]
	) or { panic(err) }
	assert result.children[0].hidden
}

fn test_carousel_validates_direction_and_minimum_move() {
	assert carousel_direction('bottom')! == .bottom
	if _ := carousel_direction('diagonal') {
		assert false, 'unknown directions must fail'
	} else {
		assert err.msg().contains('diagonal')
	}
	if _ := carousel_frames(frame: rect(0, 0, 100, 100), min_move: -0.1) {
		assert false, 'negative minimum move must fail'
	} else {
		assert err.msg().contains('minimum move')
	}
}
