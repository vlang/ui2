module ui2

// Coverage for the menu bar and notification-area scenarios an embedder needs:
// a menu bar that can be replaced at runtime, a command that reaches the app's
// handler, a tray tooltip that can be updated, and a tray icon clicked with no
// menu attached.
//
// Like embed_test.v these live at the module root: V resolves a module root from
// the input file's directory, so a test under windows/ cannot see ui/, where the
// menu and tray declarations and their accessors live.

// The declaration layer is portable: set_menu_bar records what it was given and
// menu_bar reports it back. The Windows test below covers the native side.
fn test_menu_bar_declaration_round_trips() {
	previous := menu_bar()
	set_menu_bar([Menu{
		title: 'File'
		items: [menu_item('new', 'New')]
	}])
	assert menu_bar().len == 1
	assert menu_bar()[0].title == 'File'
	assert menu_bar()[0].items[0].id == 'new'
	set_menu_bar(previous)
	assert menu_bar().len == previous.len
}

$if windows && !ui2_custom_rendering ? {
	fn menu_command_test_handler(id string) {
		// Report through the menu state so the test needs no globals.
		set_menu_bar([Menu{
			title: 'got:' + id
			items: [menu_item('x', 'X')]
		}])
	}

	fn test_windows_menu_bar_and_tray_cover_embedder_scenarios() {
		previous_window := menu_window()
		previous_app := menu_app_name()
		previous_menus := menu_bar()
		previous_tray := tray()
		previous_tray_visible := tray_visible()
		assert C.ui2_win_register_classes() != 0
		title := 'menu test'.to_wide()
		root := C.ui2_win_create_main_window(title, 320, 200)
		unsafe {
			free(title)
		}
		assert root != unsafe { nil }
		defer {
			C.ui2_win_destroy(root)
		}
		publish_menu_context(menu_command_test_handler, 'MenuTest', root)
		// A dynamic menu bar: installing twice replaces the declaration.
		set_menu_bar([Menu{
			title: 'File'
			items: [menu_item('new', 'New')]
		}])
		assert menu_bar()[0].title == 'File'
		set_menu_bar([Menu{
			title: 'Edit'
			items: [menu_item('copy', 'Copy')]
		}])
		assert menu_bar()[0].title == 'Edit'
		// A menu bar command reaches the window event handler: 'copy' is the
		// first emitting row, so it owns win_menu_command_base.
		windows_handle_menu_command(win_menu_command_base)
		assert menu_bar()[0].title == 'got:copy'
		// Tray tooltip updates replace the declaration.
		set_tray(TrayConfig{
			id: 'tray_open'
			title: 'App'
			tooltip: 'v1'
		})
		assert tray_visible()
		assert tray().tooltip == 'v1'
		set_tray(TrayConfig{
			id: 'tray_open'
			title: 'App'
			tooltip: 'v2'
		})
		assert tray().tooltip == 'v2'
		// A tray icon without a menu emits its id on left-click...
		set_menu_bar([Menu{
			title: 'Edit'
			items: [menu_item('copy', 'Copy')]
		}])
		windows_handle_tray_message(win_wm_lbutton_up)
		assert menu_bar()[0].title == 'got:tray_open'
		// ...and emits nothing on right-click.
		set_menu_bar([Menu{
			title: 'Edit'
			items: [menu_item('copy', 'Copy')]
		}])
		windows_handle_tray_message(win_wm_rbutton_up)
		assert menu_bar()[0].title == 'Edit'
		remove_tray()
		assert !tray_visible()
		set_menu_bar(previous_menus)
		if previous_tray_visible {
			set_tray(previous_tray)
		} else {
			remove_tray()
		}
		publish_menu_context(EventFn(unsafe { nil }), previous_app, previous_window)
	}
}
