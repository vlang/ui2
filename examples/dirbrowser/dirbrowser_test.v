module main

import os
import ui2

fn find_dirbrowser_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_dirbrowser_element(child, id) {
			return found
		}
	}
	return none
}

fn test_dirbrowser_lists_only_folders_and_navigates() {
	root_path := os.join_path(os.temp_dir(), 'ui2-dirbrowser-${os.getpid()}')
	os.mkdir_all(os.join_path(root_path, 'bravo')) or { panic(err) }
	os.mkdir_all(os.join_path(root_path, 'alpha', 'nested')) or { panic(err) }
	os.write_file(os.join_path(root_path, 'ignored.txt'), 'file') or { panic(err) }
	defer {
		os.rmdir_all(root_path) or {}
	}
	mut app := directory_browser_at(root_path)
	assert app.entries.map(it.name) == ['alpha', 'bravo']
	app.open_entry(1)
	assert app.path.ends_with(os.join_path('alpha'))
	assert app.entries.len == 1
	assert app.entries[0].name == 'nested'
	app.choose_current()
	assert app.status.starts_with('Selected folder:')
	app.go_parent()
	assert app.entries.len == 2
}

fn test_dirbrowser_qml_builds_keyed_native_folder_rows() {
	app := directory_browser_at(os.getwd())
	root := ui2.element_from_qml_model(dirbrowser_qml_source, app, ui2.rect(0, 0, dirbrowser_width, dirbrowser_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	list := find_dirbrowser_element(root, 'folder_list') or { panic('missing folder list') }
	assert list.children.len == app.entries.len + 1
	if app.entries.len > 0 {
		assert list.children[0].key == app.entries[0].path
		assert list.children[0].native_style
	}
	assert (find_dirbrowser_element(root, 'parent') or { panic('missing parent button') }).native_style
	assert (find_dirbrowser_element(root, 'choose') or { panic('missing choose button') }).native_style
}
