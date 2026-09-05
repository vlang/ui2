module main

import ui2

fn find_files_dropped_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_files_dropped_element(child, id) {
			return found
		}
	}
	return none
}

fn test_files_dropped_collects_paths_and_plain_text() {
	mut app := FilesDroppedDemo{}
	app.receive(['/tmp/report.pdf', r'C:\Users\alex\notes.txt'], '')
	assert app.files.len == 2
	assert app.files[0].name == 'report.pdf'
	assert app.files[1].name == 'notes.txt'
	assert app.status == '2 dropped items'
	app.receive([], 'hello')
	assert app.files[2].name == 'Dropped text'
	assert app.files[2].path == 'hello'
}

fn test_files_dropped_qml_builds_keyed_scroll_rows() {
	mut app := FilesDroppedDemo{}
	app.receive(['/tmp/one.txt', '/tmp/two.txt'], '')
	root := ui2.element_from_qml_model(files_dropped_qml_source, app, ui2.rect(0, 0, files_dropped_width, files_dropped_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	list := find_files_dropped_element(root, 'file_list') or { panic('missing file list') }
	assert list.children.len == 3
	assert list.children[0].key == '1'
	assert list.children[1].children[0].text == 'two.txt'
	assert (find_files_dropped_element(root, 'empty_hint') or {
		panic('missing empty hint')
	}).hidden
}
