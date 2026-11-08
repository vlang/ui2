module main

$if !macos {
	// Real lifecycle automation currently uses the macOS public window handle.
	fn schedule_real_window_lifecycle(_delay_ms int) bool {
		return false
	}
}
