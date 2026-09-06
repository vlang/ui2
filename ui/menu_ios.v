// iOS has neither a window menu bar nor a status area an app can dock an icon
// into, so the menu API is accepted and ignored there. Check menu_bar_supported
// and tray_supported before offering either in a shared UI.
module ui2

fn native_menu_bar_supported() bool {
	return false
}

fn native_tray_supported() bool {
	return false
}

fn native_set_menu_bar(_menus []Menu) {}

fn native_set_tray(_cfg TrayConfig) {}

fn native_remove_tray() {}
