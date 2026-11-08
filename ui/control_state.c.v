module ui2

$if macos && !ui2_custom_rendering ? {
	import macos
}

// control_checked returns a checkbox, switch or toggle button's live mounted state.
// Missing IDs and other widget kinds return false.
pub fn control_checked(id string) bool {
	$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
		if id in g_active_checkboxes { return checkbox_checked(id) }
		if id in g_active_switches { return switch_active(id) }
		if id in g_active_toggles { return toggle_button_pressed(id) }
	} $else $if macos {
		st := state()
		if (st.view_kinds[id] or { Kind.view }) !in [.checkbox, .switch_control, .toggle_button] {
			return false
		}
		native := st.views[id] or { return false }
		return macos.msg_i64(native, 'state') != 0
	} $else $if windows {
		st := windows_state()
		if (st.view_kinds[id] or { Kind.view }) !in [.checkbox, .switch_control, .toggle_button] {
			return false
		}
		hwnd := st.views[id] or { return false }
		return C.ui2_win_get_checked(hwnd) != 0
	}
	return false
}

// set_control_checked updates live state without emitting an event. Declare the new
// value on the next build to keep application state and the control in sync.
pub fn set_control_checked(id string, value bool) {
	$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
		if id in g_active_checkboxes { set_checkbox_checked(id, value) }
		if id in g_active_switches { set_switch_active(id, value) }
		if id in g_active_toggles { set_toggle_button_pressed(id, value) }
	} $else $if macos {
		st := state()
		kind := st.view_kinds[id] or { return }
		if kind == .switch_control { set_switch_active(id, value) }
		if kind == .toggle_button { set_toggle_button_pressed(id, value) }
		if kind == .checkbox {
			native := st.views[id] or { return }
			macos.msg_void_i64(native, 'setState:', if value { i64(1) } else { i64(0) })
		}
	} $else $if windows {
		st := windows_state()
		kind := st.view_kinds[id] or { return }
		if kind == .switch_control { set_switch_active(id, value) }
		if kind == .toggle_button { set_toggle_button_pressed(id, value) }
		if kind == .checkbox {
			hwnd := st.views[id] or { return }
			C.ui2_win_set_checked(hwnd, windows_bool(value))
		}
	}
}
