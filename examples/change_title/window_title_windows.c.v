module main

$if !ui2_custom_rendering ? {
	#flag windows -luser32
	#include <windows.h>

	fn C.GetActiveWindow() voidptr
	fn C.SetWindowTextW(voidptr, &u16) int

	fn apply_window_title(title string) {
		window := C.GetActiveWindow()
		if window != unsafe { nil } {
			wide_title := title.to_wide()
			C.SetWindowTextW(window, wide_title)
			unsafe { free(wide_title) }
		}
	}
}
