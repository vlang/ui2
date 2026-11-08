// Tests for the window creation options: their defaults must keep the
// behaviour run_window has always had, so existing applications do not change
// appearance or redraw behaviour until they opt in.
module ui2

fn test_window_options_default_to_the_run_window_behaviour() {
	opts := WindowOptions{}
	assert opts.sample_count == 4
	assert opts.title == ''
	assert opts.width == 0
	assert opts.height == 0
	assert opts.min_width == 0
	assert opts.min_height == 0
}
