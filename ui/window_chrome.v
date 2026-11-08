module ui2

// WindowChrome is how much of the platform's window frame a window keeps.
pub enum WindowChrome {
	native          // the platform's title bar and frame
	hidden_titlebar // content runs under a transparent title bar; draw your own (title_bar)
}

// set_window_chrome changes the main window's frame. With `hidden_titlebar` the
// application draws its own title bar at the top of the window: macOS keeps its
// window controls over the content's leading corner (see
// window_controls_leading_inset), Windows removes the caption but keeps the
// resizable border, and the application draws the window buttons
// (window_draws_own_controls). It reports whether the platform did it; Linux,
// Android and iOS keep their frame.
pub fn set_window_chrome(chrome WindowChrome) bool {
	return native_set_window_chrome(chrome)
}

// window_chrome_supported reports whether set_window_chrome can apply chrome.
pub fn window_chrome_supported(chrome WindowChrome) bool {
	return chrome == .native || native_window_chrome_supported()
}

// start_window_drag lets the platform move the window with the pointer, as a
// press on a title bar does. Call it while handling a `pointer:down` event from
// your own title bar; it reports whether a drag started.
pub fn start_window_drag() bool {
	return native_start_window_drag()
}

// minimize_window sends the main window to the Dock or taskbar.
pub fn minimize_window() bool {
	return native_minimize_window()
}

// toggle_maximize_window maximizes the main window, or restores it when it
// already is (zoom on macOS), as a double click on a title bar does.
pub fn toggle_maximize_window() bool {
	return native_toggle_maximize_window()
}

// window_is_maximized reports whether the main window is maximized (zoomed).
pub fn window_is_maximized() bool {
	return native_window_is_maximized()
}

// window_controls_leading_inset is how much room the platform's own window
// controls take at the leading edge of a hidden title bar: macOS's close,
// minimize and zoom buttons. Elsewhere it is zero.
pub fn window_controls_leading_inset() f64 {
	return native_window_controls_leading_inset()
}

// window_draws_own_controls reports whether an application with a hidden title
// bar must draw the minimize, maximize and close buttons itself (Windows).
pub fn window_draws_own_controls() bool {
	return native_window_draws_own_controls()
}
