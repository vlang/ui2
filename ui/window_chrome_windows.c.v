// vfmt off
// Window chrome needs nothing from the Win32 view backend, so unlike
// windows/ui_windows.v this file stays outside the ui2_custom_rendering
// switch: custom-rendered Windows apps get the same title bar control.
module ui2

#flag windows -luser32
#flag windows -lcomctl32
#flag windows -I @VMODROOT/windows

#insert "@VMODROOT/windows/window_chrome_windows.h"

fn C.ui2_chrome_set(hidden int) int
fn C.ui2_chrome_start_drag() int
fn C.ui2_chrome_minimize() int
fn C.ui2_chrome_toggle_maximize() int
fn C.ui2_chrome_is_maximized() int

fn native_window_chrome_supported() bool {
	return true
}

fn native_set_window_chrome(chrome WindowChrome) bool {
	return C.ui2_chrome_set(if chrome == .hidden_titlebar { 1 } else { 0 }) != 0
}

fn native_start_window_drag() bool {
	return C.ui2_chrome_start_drag() != 0
}

fn native_minimize_window() bool {
	return C.ui2_chrome_minimize() != 0
}

fn native_toggle_maximize_window() bool {
	return C.ui2_chrome_toggle_maximize() != 0
}

fn native_window_is_maximized() bool {
	return C.ui2_chrome_is_maximized() != 0
}

fn native_window_controls_leading_inset() f64 {
	return 0
}

fn native_window_draws_own_controls() bool {
	return true
}
