// Windows has a real menu bar on the window and a real notification area, but
// only when the native backend is in use; a custom-rendered Windows build
// draws its own bar and owns nothing outside its window. The Win32 side lives
// in windows/menu_windows.v, next to the header it needs — keeping it out of
// this file is what keeps windows.h out of a gg/Sokol build.
module ui2

fn native_menu_bar_supported() bool {
	return true
}

fn native_tray_supported() bool {
	$if ui2_custom_rendering ? {
		return false
	} $else {
		return true
	}
}

fn native_set_menu_bar(menus []Menu) {
	$if ui2_custom_rendering ? {
		close_menu_bar()
	} $else {
		menu_win32_set_menu_bar(menus)
	}
}

fn native_set_tray(cfg TrayConfig) {
	$if !ui2_custom_rendering ? {
		menu_win32_set_tray(cfg)
	}
}

fn native_remove_tray() {
	$if !ui2_custom_rendering ? {
		menu_win32_remove_tray()
	}
}
