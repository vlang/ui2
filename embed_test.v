module ui2

// Tests for the embedder-facing window API.
//
// These live at the module root rather than beside the code because V resolves
// a module root from the input file's directory: a test under ui/ cannot see
// windows/, and a test under windows/ cannot see ui/. A test file at the root
// sees the whole module, so these actually compile and run.

// The accessor reports whatever handle the backend published, on every backend.
fn test_native_window_handle_reports_the_published_handle() {
	previous := menu_window()
	fake := voidptr(usize(0x1234))
	menu_update_window(fake)
	assert native_window_handle() == fake
	menu_update_window(unsafe { nil })
	assert native_window_handle() == unsafe { nil }
	menu_update_window(previous)
	assert native_window_handle() == previous
}

$if windows && !ui2_custom_rendering ? {
	// On Windows the published handle is the real HWND of the main window.
	fn test_windows_native_window_handle_reports_the_main_hwnd() {
		previous := menu_window()
		assert C.ui2_win_register_classes() != 0
		title := 'handle test'.to_wide()
		root := C.ui2_win_create_main_window(title, 320, 200)
		unsafe {
			free(title)
		}
		assert root != unsafe { nil }
		defer {
			C.ui2_win_destroy(root)
		}
		menu_update_window(root)
		assert native_window_handle() == root
		menu_update_window(previous)
		assert native_window_handle() == previous
	}
}
