module main

import ui2

fn test_screen_manager_demo_navigates_between_named_screens() {
	mut app := ui2.new_qml_app(screen_manager_qml_source, ScreenManagerDemo{}) or {
		panic(err)
	}
	initial := app.build(ui2.rect(0, 0, screen_manager_width, screen_manager_height)) or {
		panic(err)
	}
	manager := initial.children[1]
	assert manager.children[0].id == 'home'
	app.handle(manager.children[0].children[2].action_id) or { panic(err) }
	assert app.state().current == 'details'

	rebuilt := app.build(ui2.rect(0, 0, screen_manager_width, screen_manager_height)) or {
		panic(err)
	}
	assert rebuilt.children[1].children[0].id == 'details'
	assert rebuilt.children[1].children[0].children[0].text == 'Details'
}
