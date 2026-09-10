module main

import macos

#flag darwin -framework AppKit

const ns_window_style_borderless = u64(0)

@[markused]
fn macos_configure_custom_window() bool {
	window := macos_custom_window()
	if macos_custom_window_is_nil(window) {
		return false
	}
	// Borderless NSWindows normally refuse to become key windows. UI2 creates a
	// small NSWindow subclass, so add the capability before dropping its frame.
	window_class := macos.get_class('UI2Window')
	if !macos_custom_window_is_nil(window_class) {
		macos.add_method(window_class, 'canBecomeKeyWindow', voidptr(custom_window_can_become_key), 'B@:')
		macos.add_method(window_class, 'canBecomeMainWindow', voidptr(custom_window_can_become_key), 'B@:')
	}
	macos.msg_void_u64(window, 'setStyleMask:', ns_window_style_borderless)
	macos.msg_void_bool(window, 'setOpaque:', false)
	macos.msg_void_bool(window, 'setHasShadow:', true)
	macos.msg_void1(window, 'setBackgroundColor:', macos.msg_id(macos.get_class('NSColor'), 'clearColor'))
	return true
}

@[markused]
fn macos_drag_custom_window() {
	window := macos_custom_window()
	event := macos.msg_id(macos_custom_window_application(), 'currentEvent')
	if macos_custom_window_is_nil(window) || macos_custom_window_is_nil(event) {
		return
	}
	macos.msg_void1(window, 'performWindowDragWithEvent:', event)
}

fn macos_custom_window() macos.Id {
	app := macos_custom_window_application()
	if macos_custom_window_is_nil(app) {
		return macos_custom_window_nil()
	}
	for selector in ['keyWindow', 'mainWindow'] {
		window := macos.msg_id(app, selector)
		if !macos_custom_window_is_nil(window) {
			return window
		}
	}
	windows := macos.msg_id(app, 'windows')
	if macos_custom_window_is_nil(windows) || macos.msg_u64(windows, 'count') == 0 {
		return macos_custom_window_nil()
	}
	return macos.msg_id_u64(windows, 'objectAtIndex:', u64(0))
}

fn macos_custom_window_application() macos.Id {
	return macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
}

fn macos_custom_window_is_nil(value macos.Id) bool {
	return value == macos_custom_window_nil()
}

fn macos_custom_window_nil() macos.Id {
	return unsafe { nil }
}

@[export: 'ui2_example_custom_window_can_become_key']
fn custom_window_can_become_key(_self voidptr, _cmd voidptr) bool {
	return true
}
