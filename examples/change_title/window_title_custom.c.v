// vfmt off
module main

$if android || linux || ((macos || windows) && ui2_custom_rendering ?) {
	import gg

	fn apply_window_title(title string) {
		gg.set_window_title(title)
	}
}
