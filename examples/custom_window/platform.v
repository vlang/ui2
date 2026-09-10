module main

fn configure_custom_window() bool {
	$if macos && !ui2_custom_rendering ? {
		return macos_configure_custom_window()
	} $else $if windows && !ui2_custom_rendering ? {
		return windows_configure_custom_window(custom_window_width, custom_window_height)
	} $else {
		return true
	}
}

fn drag_custom_window() {
	$if macos && !ui2_custom_rendering ? {
		macos_drag_custom_window()
	} $else $if windows && !ui2_custom_rendering ? {
		windows_drag_custom_window()
	}
}

fn custom_window_uses_transparent_screen() bool {
	$if macos && !ui2_custom_rendering ? {
		return true
	} $else {
		return false
	}
}

fn custom_window_screen_background() string {
	$if windows && !ui2_custom_rendering ? {
		// The Win32 adapter treats this otherwise-unused color as transparent.
		return '#010203'
	} $else {
		return '#0F172A'
	}
}

fn custom_window_platform_note() string {
	$if ( macos || windows ) && !ui2_custom_rendering ? {
		return 'The empty area around these cards is the desktop.'
	} $else {
		return 'Frameless transparency is demonstrated by the native macOS and Windows backends.'
	}
}
