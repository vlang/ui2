module main

import ui2

const message_width = 420
const message_height = 260
const message_qml_source = $embed_file('message.qml').to_string()

pub struct MessageDemo {
pub mut:
	visible bool = true
}

pub fn (mut app MessageDemo) show_message() {
	app.visible = true
}

pub fn (mut app MessageDemo) close_message() {
	app.visible = false
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
