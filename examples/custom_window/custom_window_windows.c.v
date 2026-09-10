module main

#include <windows.h>

#insert "@DIR/custom_window_windows.h"

fn C.ui2_example_configure_custom_window(width int, height int) bool

fn C.ui2_example_drag_custom_window()

fn windows_configure_custom_window(width int, height int) bool {
	return C.ui2_example_configure_custom_window(width, height)
}

fn windows_drag_custom_window() {
	C.ui2_example_drag_custom_window()
}
