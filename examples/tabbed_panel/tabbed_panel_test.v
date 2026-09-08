module main

import ui2

fn test_tabbed_panel_demo_switches_active_content() {
	mut app := ui2.new_qml_app(tabbed_qml_source, TabbedPanelDemo{}) or { panic(err) }
	initial := app.build(ui2.rect(0, 0, tabbed_width, tabbed_height)) or { panic(err) }
	settings := initial.children[1]
	assert settings.children[0].children[0].text == 'Account overview'

	security := settings.children[3]
	app.handle(security.action_id) or { panic(err) }
	assert app.state().current == 2
	rebuilt := app.build(ui2.rect(0, 0, tabbed_width, tabbed_height)) or { panic(err) }
	assert rebuilt.children[1].children[0].children[0].text == 'Security options'
}
