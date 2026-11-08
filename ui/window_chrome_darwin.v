// NSWindow only needs the Objective-C runtime bridge, so this file serves
// custom-rendered macOS windows as well as the AppKit backend.
module ui2

import macos

#flag darwin -framework AppKit

const ns_window_style_full_size_content_view = u64(1) << 15
const ns_window_title_hidden = i64(1)

// The main window: the key window, else the main one, else the first.
fn chrome_main_window() macos.Id {
	app := macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	for selector in ['keyWindow', 'mainWindow'] {
		window := macos.msg_id(app, selector)
		if window != unsafe { nil } {
			return window
		}
	}
	windows := macos.msg_id(app, 'windows')
	if windows == unsafe { nil } || macos.msg_u64(windows, 'count') == 0 {
		return unsafe { nil }
	}
	return macos.msg_id_u64(windows, 'objectAtIndex:', 0)
}

fn native_window_chrome_supported() bool {
	return true
}

fn native_set_window_chrome(chrome WindowChrome) bool {
	window := chrome_main_window()
	if window == unsafe { nil } {
		return false
	}
	mask := macos.msg_u64(window, 'styleMask')
	hidden := chrome == .hidden_titlebar
	macos.msg_void_u64(window, 'setStyleMask:', if hidden {
		mask | ns_window_style_full_size_content_view
	} else {
		mask & ~ns_window_style_full_size_content_view
	})
	macos.msg_void_bool(window, 'setTitlebarAppearsTransparent:', hidden)
	macos.msg_void_i64(window, 'setTitleVisibility:', if hidden {
		ns_window_title_hidden
	} else {
		0
	})
	return true
}

// The press that asked for the drag is still the application's current event.
fn native_start_window_drag() bool {
	window := chrome_main_window()
	app := macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	event := macos.msg_id(app, 'currentEvent')
	// Only a press or a drag can start one (NSEventTypeLeftMouseDown, Dragged).
	if window == unsafe { nil } || event == unsafe { nil }
		|| macos.msg_u64(event, 'type') !in [u64(1), 6] {
		return false
	}
	macos.msg_void1(window, 'performWindowDragWithEvent:', event)
	return true
}

fn native_minimize_window() bool {
	window := chrome_main_window()
	if window == unsafe { nil } {
		return false
	}
	macos.msg_void1(window, 'miniaturize:', unsafe { nil })
	return true
}

fn native_toggle_maximize_window() bool {
	window := chrome_main_window()
	if window == unsafe { nil } {
		return false
	}
	macos.msg_void1(window, 'zoom:', unsafe { nil })
	return true
}

fn native_window_is_maximized() bool {
	window := chrome_main_window()
	return window != unsafe { nil } && macos.msg_bool(window, 'isZoomed')
}

// The traffic lights take about 70 points from the leading edge of a hidden
// title bar; measuring the zoom button keeps it right if that changes.
fn native_window_controls_leading_inset() f64 {
	window := chrome_main_window()
	if window == unsafe { nil } {
		return 78
	}
	zoom := macos.msg_id_u64(window, 'standardWindowButton:', 2)
	if zoom == unsafe { nil } {
		return 78
	}
	frame := macos.msg_rect(zoom, 'frame')
	return frame.x + frame.width + 12
}

fn native_window_draws_own_controls() bool {
	return false
}
