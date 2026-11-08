// Linux (whose window sokol makes, with decorations from the window manager),
// Android and iOS keep their frame: there is no title bar to replace.
module ui2

fn native_window_chrome_supported() bool {
	return false
}

fn native_set_window_chrome(_chrome WindowChrome) bool {
	return false
}

fn native_start_window_drag() bool {
	return false
}

fn native_minimize_window() bool {
	return false
}

fn native_toggle_maximize_window() bool {
	return false
}

fn native_window_is_maximized() bool {
	return false
}

fn native_window_controls_leading_inset() f64 {
	return 0
}

fn native_window_draws_own_controls() bool {
	return false
}
