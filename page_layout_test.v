module ui2

fn page_test_children(count int) []Element {
	mut children := []Element{cap: count}
	for index in 0 .. count {
		children << view('page_${index}', rect(0, 0, 1, 1), BoxStyle{}, [])
	}
	return children
}

fn test_page_layout_positions_first_page_and_next_border() {
	config := PageLayoutConfig{
		frame: rect(0, 0, 300, 160)
		border: 40
		children: page_test_children(3)
	}
	assert page_layout_frames(config)! == [rect(0, 0, 260, 160), rect(260, 0, 260, 160),
		rect(300, 0, 260, 160)]
}

fn test_page_layout_positions_middle_page_between_two_borders() {
	config := PageLayoutConfig{
		frame: rect(0, 0, 300, 160)
		page: 1
		border: 40
		children: page_test_children(3)
	}
	assert page_layout_frames(config)! == [rect(0, 0, 260, 160), rect(20, 0, 260, 160),
		rect(280, 0, 260, 160)]
}

fn test_page_layout_clamps_page_and_navigation() {
	assert page_layout_page(8, 3) == 2
	assert page_layout_page(-4, 3) == 0
	assert page_layout_next(2, 3) == 2
	assert page_layout_previous(0, 3) == 0
	assert page_layout_previous(2, 3) == 1
}

fn test_page_layout_swipe_threshold_changes_page() {
	assert page_layout_page_after_swipe(1, 3, -151, 300, 0.5) == 2
	assert page_layout_page_after_swipe(1, 3, 151, 300, 0.5) == 0
	assert page_layout_page_after_swipe(1, 3, -150, 300, 0.5) == 1
}

fn test_page_layout_constructor_preserves_page_content() {
	config := PageLayoutConfig{
		id: 'pager'
		frame: rect(10, 20, 200, 100)
		page: 1
		border: 20
		children: [
			button('one', 'One', rect(0, 0, 1, 1), BoxStyle{}, TextStyle{}),
			button('two', 'Two', rect(0, 0, 1, 1), BoxStyle{}, TextStyle{}),
		]
	}
	pager := page_layout(config) or { panic(err) }
	assert pager.frame == rect(10, 20, 200, 100)
	assert pager.children[1].text == 'Two'
	assert pager.children[1].frame == rect(20, 0, 180, 100)
}
