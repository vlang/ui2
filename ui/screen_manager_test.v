module ui2

fn screen_manager_test_screens() []ManagedScreen {
	return [
		ManagedScreen{
			name: 'home'
			content: view('home', rect(4, 5, 10, 10), BoxStyle{}, [])
		},
		ManagedScreen{
			name: 'details'
			content: view('details', rect(4, 5, 10, 10), BoxStyle{}, [])
		},
		ManagedScreen{
			name: 'settings'
			content: view('settings', rect(4, 5, 10, 10), BoxStyle{}, [])
		},
	]
}

fn test_screen_manager_selects_named_screen() {
	config := ScreenManagerConfig{
		frame: rect(0, 0, 320, 200)
		current: 'details'
		screens: screen_manager_test_screens()
	}
	assert screen_manager_index(config)! == 1
	assert screen_manager_current(config)! == 'details'
	manager := screen_manager(config) or { panic(err) }
	assert manager.children.len == 1
	assert manager.children[0].id == 'details'
	assert manager.children[0].frame == rect(0, 0, 320, 200)
}

fn test_screen_manager_defaults_to_first_screen() {
	config := ScreenManagerConfig{
		frame: rect(0, 0, 320, 200)
		screens: screen_manager_test_screens()
	}
	assert screen_manager_index(config)! == 0
	assert screen_manager_current(config)! == 'home'
}

fn test_screen_manager_navigation_wraps() {
	screens := screen_manager_test_screens()
	assert screen_manager_next(frame: rect(0, 0, 1, 1), current: 'settings', screens: screens)! == 'home'
	assert screen_manager_previous(frame: rect(0, 0, 1, 1), current: 'home', screens: screens)! == 'settings'
}

fn test_screen_manager_rejects_unknown_or_duplicate_names() {
	if _ := screen_manager_index(
		frame: rect(0, 0, 100, 100)
		current: 'missing'
		screens: screen_manager_test_screens()
	) {
		assert false, 'unknown screen names must fail'
	} else {
		assert err.msg().contains('missing')
	}
	if _ := screen_manager(
		frame: rect(0, 0, 100, 100)
		screens: [ManagedScreen{ name: 'same' }, ManagedScreen{ name: 'same' }]
	) {
		assert false, 'duplicate screen names must fail'
	} else {
		assert err.msg().contains('duplicate')
	}
}

fn test_empty_screen_manager_has_no_active_child() {
	config := ScreenManagerConfig{ frame: rect(0, 0, 100, 100) }
	assert screen_manager_current(config)! == ''
	assert screen_manager_next(config)! == ''
	assert screen_manager_previous(config)! == ''
	assert screen_manager(config)!.children.len == 0
}
