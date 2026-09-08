module main

import ui2

fn test_popup_demo_opens_and_closes_editor() {
	mut app := ui2.new_qml_app(popup_qml_source, PopupDemo{}) or { panic(err) }
	initial := app.build(ui2.rect(0, 0, popup_width, popup_height)) or { panic(err) }
	assert initial.children[2].hidden
	app.handle(initial.children[1].action_id) or { panic(err) }
	assert app.state().editing

	opened := app.build(ui2.rect(0, 0, popup_width, popup_height)) or { panic(err) }
	popup_element := opened.children[2]
	assert !popup_element.hidden
	assert popup_element.children[2].children[0].text == 'Edit profile'
	app.handle(popup_element.children[2].children[2].children[3].action_id) or { panic(err) }
	assert !app.state().editing
}
