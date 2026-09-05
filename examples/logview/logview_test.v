module main

import ui2

fn find_logview_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_logview_element(child, id) {
			return found
		}
	}
	return none
}

fn test_logview_appends_batches_and_clears() {
	mut app := LogviewDemo{}
	app.start_scan()
	assert app.log.contains('task 1 complete')
	assert app.log.contains('task 8 complete')
	assert app.next_task == 9
	assert app.status == '8 tasks complete'
	app.start_scan()
	assert app.log.contains('task 16 complete')
	app.clear()
	assert app.log == ''
	assert app.next_task == 1
}

fn test_logview_qml_uses_readonly_log_and_native_actions() {
	root := ui2.element_from_qml_model(logview_qml_source, LogviewDemo{}, ui2.rect(0, 0, logview_width, logview_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	log := find_logview_element(root, 'log') or { panic('missing log area') }
	assert log.readonly
	assert (find_logview_element(root, 'start_scan') or { panic('missing scan button') }).native_style
	clear := find_logview_element(root, 'clear') or { panic('missing Clear button') }
	assert clear.native_style
	assert !clear.enabled
}
