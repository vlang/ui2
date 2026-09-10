module main

import os
import ui2

const file_dialog_width = 620
const file_dialog_height = 290
const file_dialog_qml_source = $embed_file('file_dialog.qml').to_string()

pub struct FileDialogDemo {
pub mut:
	selection string = 'Choose a file, a destination, or a folder.'
}

pub fn (mut app FileDialogDemo) open_source() {
	paths := ui2.open_file_dialog(
		title: 'Open a V source file'
		filters: [
			ui2.FileDialogFilter{
				name: 'V source'
				extensions: ['v', 'vv']
			},
		]
	)
	app.selection = if paths.len > 0 { 'Open: ${paths[0]}' } else { 'Open cancelled.' }
}

pub fn (mut app FileDialogDemo) save_text() {
	paths := ui2.save_file_dialog(
		title: 'Save text file'
		filename: 'notes.txt'
		filters: [ui2.FileDialogFilter{
			name: 'Text'
			extensions: ['txt']
		}]
	)
	app.selection = if paths.len > 0 { 'Save: ${paths[0]}' } else { 'Save cancelled.' }
}

pub fn (mut app FileDialogDemo) choose_folder() {
	paths := ui2.open_folder_dialog(
		title: 'Choose a folder'
		directory: os.home_dir()
	)
	app.selection = if paths.len > 0 {
		'Folder: ${paths[0]}'
	} else {
		'Folder selection cancelled.'
	}
}

fn main() {
	ui2.run_qml[FileDialogDemo](
		source: file_dialog_qml_source
		model: FileDialogDemo{}
		title: 'Native file dialog'
		width: file_dialog_width
		height: file_dialog_height
	) or { panic(err) }
}
