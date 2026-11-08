// Linux and Android. Linux desktops publish their color scheme through the
// XDG settings portal (org.freedesktop.appearance color-scheme, over D-Bus),
// which ui2 does not speak; GTK_THEME, when the user forces a dark variant
// with it, is the one setting a process can read cheaply.
module ui2

import os

fn native_system_appearance() SystemAppearance {
	gtk := os.getenv('GTK_THEME').to_lower()
	if gtk.ends_with(':dark') || gtk.ends_with('-dark') {
		return .dark
	}
	return .unknown
}
