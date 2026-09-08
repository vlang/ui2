module main

import ui2

const modal_view_width = 460
const modal_view_height = 340
const modal_view_qml_source = $embed_file('modal_view.qml').to_string()

pub struct ModalViewDemo {
pub mut:
	confirming bool
	status     string = 'No pending action.'
}

pub fn (mut app ModalViewDemo) open_confirmation() {
	app.confirming = true
	app.status = 'Waiting for confirmation.'
}

pub fn (mut app ModalViewDemo) close_confirmation() {
	app.confirming = false
	app.status = 'Action cancelled.'
}

pub fn (mut app ModalViewDemo) confirm() {
	app.confirming = false
	app.status = 'Action confirmed.'
}

fn main() {
	ui2.run_qml[ModalViewDemo](
		source: modal_view_qml_source
		model: ModalViewDemo{}
		title: 'Modal View'
		width: modal_view_width
		height: modal_view_height
	) or { panic(err) }
}
