module main

import ui2

fn test_modal_view_demo_opens_confirms_and_dismisses() {
	mut app := ui2.new_qml_app(modal_view_qml_source, ModalViewDemo{}) or { panic(err) }
	initial := app.build(ui2.rect(0, 0, modal_view_width, modal_view_height)) or { panic(err) }
	assert initial.children[3].hidden
	app.handle(initial.children[2].action_id) or { panic(err) }
	assert app.state().confirming

	opened := app.build(ui2.rect(0, 0, modal_view_width, modal_view_height)) or { panic(err) }
	modal := opened.children[3]
	assert !modal.hidden
	assert modal.children[2].children[0].text == 'Confirm action'
	app.handle(modal.children[2].children[3].action_id) or { panic(err) }
	assert !app.state().confirming
	assert app.state().status == 'Action confirmed.'

	app.handle(modal.children[2].children[2].action_id) or { panic(err) }
	assert app.state().status == 'Action cancelled.'
}
