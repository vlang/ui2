// Targets whose windows the custom renderer draws itself — Linux and Android.
// There is no platform menu bar to hand a declaration to, so the renderer
// draws one across the top of the window (see menu_custom.c.v), and there is
// no status area outside that window for a tray icon to dock into.
module ui2

fn native_menu_bar_supported() bool {
	$if ( android || linux ) && !ui2_headless ? {
		return true
	} $else {
		return false
	}
}

fn native_tray_supported() bool {
	return false
}

fn native_set_menu_bar(_menus []Menu) {
	$if ( android || linux ) && !ui2_headless ? {
		// Rebuild bounds and paint after replacing the menu declaration.
		close_menu_bar()
		refresh()
	}
}

fn native_set_tray(_cfg TrayConfig) {}

fn native_remove_tray() {}
