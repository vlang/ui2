// The Win32 desktop has no haptics engine, no icon badge and no share
// contract this layer can drive; opening URLs through ShellExecute is the
// one integration it owns. As with the clipboard this file stays outside the
// ui2_custom_rendering switch, so custom-rendered Windows apps open links too.
module ui2

#flag windows -lshell32

#insert "@VMODROOT/windows/platform_windows.h"

fn C.ui2_win_open_url(url &u16) int

fn native_haptic_supported() bool {
	return false
}

fn native_haptic(_style HapticStyle) bool {
	return false
}

fn native_app_badge_supported() bool {
	return false
}

fn native_set_app_badge(_count int) bool {
	return false
}

fn native_open_url_supported() bool {
	return true
}

fn native_open_url(url string) bool {
	wide := url.to_wide()
	opened := C.ui2_win_open_url(wide)
	unsafe { free(wide) }
	return opened != 0
}

// DataTransferManager.ShowShareUI needs WinRT activation the Win32 message
// loop does not do, so sharing answers unsupported on Windows.
fn native_share_supported() bool {
	return false
}

fn native_share_text(_text string) bool {
	return false
}
