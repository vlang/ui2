module main

import ui2

fn test_file_dialog_example_declares_native_actions() {
	root := ui2.element_from_qml_model(file_dialog_qml_source, FileDialogDemo{}, ui2.rect(0, 0, file_dialog_width, file_dialog_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	assert root.id == 'root'
}
