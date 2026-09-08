module main

import ui2

fn test_accordion_demo_switches_active_content() {
	mut app := ui2.new_qml_app(accordion_qml_source, AccordionDemo{}) or { panic(err) }
	initial := app.build(ui2.rect(0, 0, accordion_width, accordion_height)) or { panic(err) }
	preferences := initial.children[1]
	assert preferences.children[0].children[0].text == 'Update your public profile.'

	security := preferences.children[3]
	app.handle(security.action_id) or { panic(err) }
	assert app.state().current == 2
	rebuilt := app.build(ui2.rect(0, 0, accordion_width, accordion_height)) or { panic(err) }
	assert rebuilt.children[1].children[0].children[0].text == 'Review passwords and active sessions.'
}
