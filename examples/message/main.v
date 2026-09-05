module main

import ui2

const message_width = 420
const message_height = 320
const message_qml_source = $embed_file('message.qml').to_string()

pub struct MessageDemo {
pub mut:
	visible bool
	answer  string = 'No answer yet.'
}

pub fn (mut app MessageDemo) show_message() {
	app.visible = true
}

pub fn (mut app MessageDemo) close_message() {
	app.visible = false
}

// show_native_message blocks in the platform's own alert until it is dismissed.
pub fn (mut app MessageDemo) show_native_message() {
	ui2.message_box(
		title: 'Hello World'
		text:  'This message came from the ui example.'
	)
	app.answer = 'Native message acknowledged.'
}

pub fn (mut app MessageDemo) ask_native_question() {
	choice := ui2.message_box(
		title:   'Save changes?'
		text:    'The document has unsaved edits.'
		style:   .question
		buttons: .yes_no_cancel
	)
	app.answer = 'You chose ${choice}.'
}

fn main() {
	ui2.run_qml[MessageDemo](
		source: message_qml_source
		model: MessageDemo{}
		title: 'Message'
		width: message_width
		height: message_height
	) or { panic(err) }
}
