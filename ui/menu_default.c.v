// Targets whose windows the custom renderer draws itself — Linux, Android and
// the BSDs. There is no platform menu bar to hand a declaration to, so the
// renderer draws one across the top of the window (see menu_custom.c.v), and
// there is no status area outside that window for a tray icon to dock into.
module ui2

fn native_menu_bar_supported() bool {
	$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris) && !ui2_headless ? {
		return true
	} $else {
		return false
	}
}

fn native_tray_supported() bool {
	return false
}

fn native_set_menu_bar(_menus []Menu) {
	$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris) && !ui2_headless ? {
		// Rebuild bounds and paint after replacing the menu declaration.
		close_menu_bar()
		// The drawn bar only exists during frames, so a call from a thread or
		// before the first frame needs one ask to show up in on_demand refresh
		// mode. A call from inside the frame being built is already covered by
		// that frame and the trailing frames after it, and asking there would
		// keep an on_demand window redrawing forever.
		if !g_frame_running {
			request_refresh()
		}
		refresh()
	}
}

fn native_set_tray(_cfg TrayConfig) {}

fn native_remove_tray() {}
