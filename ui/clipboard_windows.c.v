// vfmt off
// The Win32 clipboard needs nothing from the view backend, so unlike
// windows/ui_windows.v this file stays outside the ui2_custom_rendering
// switch: custom-rendered Windows apps get the same clipboard.
module ui2

#flag windows -luser32

#insert "@VMODROOT/windows/clipboard_windows.h"

fn C.ui2_win_set_clipboard_text(text &u16, units int) int
fn C.ui2_win_clipboard_text() &u16
fn C.wcslen(text &u16) uint

fn native_clipboard_supported() bool {
	return true
}

fn native_set_clipboard_text(text string) bool {
	wide := text.to_wide()
	defer {
		unsafe { free(wide) }
	}
	return C.ui2_win_set_clipboard_text(wide, int(C.wcslen(wide))) != 0
}

fn native_clipboard_text() ?string {
	wide := C.ui2_win_clipboard_text()
	if wide == unsafe { nil } {
		return none
	}
	value := unsafe { string_from_wide(wide) }
	unsafe { C.free(wide) }
	return value
}

// Windows has no X11-style primary selection; both halves answer unsupported.
fn native_set_primary_text(_ string) bool {
	return false
}

fn native_primary_text() ?string {
	return none
}
