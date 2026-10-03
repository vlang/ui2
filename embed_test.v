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

	fn window_ready_test_handler(handle voidptr) {
		// Report through the menu state so the test needs no globals.
		menu_update_window(handle)
	}

	// The ready hook delivers the window's own handle, and is a silent no-op
	// when no handler is registered.
	fn test_windows_window_ready_hook_fires_with_main_hwnd() {
		previous_window := menu_window()
		mut st := windows_state()
		previous_root := st.root
		previous_handler := st.window_ready_handler
		fake := voidptr(usize(0x5678))
		st.root = fake
		on_window_ready(window_ready_test_handler)
		windows_fire_window_ready()
		assert native_window_handle() == fake
		on_window_ready(WindowReadyFn(unsafe { nil }))
		menu_update_window(previous_window)
		windows_fire_window_ready()
		assert native_window_handle() == previous_window
		st.root = previous_root
		st.window_ready_handler = previous_handler
	}

	fn window_resize_test_handler(width int, height int) {
		// Report through the state so the test needs no globals.
		mut st := windows_state()
		st.scroll_positions['resize_test_w'] = width
		st.scroll_positions['resize_test_h'] = height
	}

	// The resize hook reports the size it is handed, and is a silent no-op when
	// no handler is registered.
	fn test_windows_window_resize_hook_reports_client_size() {
		mut st := windows_state()
		previous_handler := st.window_resize_handler
		st.scroll_positions.delete('resize_test_w')
		st.scroll_positions.delete('resize_test_h')
		on_window_resize(window_resize_test_handler)
		windows_fire_window_resize(800, 600)
		assert st.scroll_positions['resize_test_w'] or { -1 } == 800
		assert st.scroll_positions['resize_test_h'] or { -1 } == 600
		on_window_resize(WindowResizeFn(unsafe { nil }))
		windows_fire_window_resize(1, 2)
		assert st.scroll_positions['resize_test_w'] or { -1 } == 800
		assert st.scroll_positions['resize_test_h'] or { -1 } == 600
		st.scroll_positions.delete('resize_test_w')
		st.scroll_positions.delete('resize_test_h')
		st.window_resize_handler = previous_handler
	}

	// End-to-end wiring: a real WM_SIZE delivered to the window proc reaches
	// the registered handler with the window's actual client size. Calling
	// windows_fire_window_resize directly would not prove the WM_SIZE branch is
	// wired up.
	fn test_windows_real_wm_size_reaches_the_resize_hook() {
		mut st := windows_state()
		previous_root := st.root
		previous_handler := st.window_resize_handler
		assert C.ui2_win_register_classes() != 0
		title := 'resize test'.to_wide()
		root := C.ui2_win_create_main_window(title, 320, 200)
		unsafe {
			free(title)
		}
		assert root != unsafe { nil }
		defer {
			C.ui2_win_destroy(root)
		}
		st.root = root
		on_window_resize(window_resize_test_handler)
		st.scroll_positions.delete('resize_test_w')
		st.scroll_positions.delete('resize_test_h')
		ui2_windows_window_proc(root, win_wm_size, 0, 0)
		assert st.scroll_positions['resize_test_w'] or { -1 } == C.ui2_win_client_width(root)
		assert st.scroll_positions['resize_test_h'] or { -1 } == C.ui2_win_client_height(root)
		assert (st.scroll_positions['resize_test_w'] or { -1 }) > 0
		st.scroll_positions.delete('resize_test_w')
		st.scroll_positions.delete('resize_test_h')
		st.root = previous_root
		st.window_resize_handler = previous_handler
	}
}

$if ui2_custom_rendering ? {
	// The custom renderer draws inside its own window and has no native handle
	// to embed into, so the hook still fires but with nil.
	fn window_ready_custom_test_handler(handle voidptr) {
		// Report through the menu state so the test needs no globals.
		assert handle == unsafe { nil }
		menu_update_window(voidptr(usize(0x9abc)))
	}

	fn test_custom_window_ready_hook_fires_with_nil_handle() {
		previous_window := menu_window()
		previous_handler := g_window_ready_handler
		on_window_ready(window_ready_custom_test_handler)
		custom_fire_window_ready()
		assert native_window_handle() == voidptr(usize(0x9abc))
		// Without a handler firing is a silent no-op.
		on_window_ready(WindowReadyFn(unsafe { nil }))
		menu_update_window(previous_window)
		custom_fire_window_ready()
		assert native_window_handle() == previous_window
		g_window_ready_handler = previous_handler
	}
}

$if ui2_custom_rendering ? {
	fn window_resize_custom_test_handler(_width int, _height int) {}

	// The custom renderer has no native child to size, so the hook is a
	// documented no-op that still accepts a registration.
	fn test_custom_window_resize_hook_is_a_documented_noop() {
		previous_handler := g_window_resize_handler
		on_window_resize(window_resize_custom_test_handler)
		assert voidptr(g_window_resize_handler) != unsafe { nil }
		on_window_resize(WindowResizeFn(unsafe { nil }))
		assert voidptr(g_window_resize_handler) == unsafe { nil }
		g_window_resize_handler = previous_handler
	}
}