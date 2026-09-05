// vfmt off
module main

$if !ui2_custom_rendering ? {
	#flag darwin -framework Cocoa
	#include "@VMODROOT/examples/change_title/window_title_darwin.h"

	fn C.ui2_example_set_window_title(&char)

	fn apply_window_title(title string) {
		C.ui2_example_set_window_title(&char(title.str))
	}
}
