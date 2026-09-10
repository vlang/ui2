module main

import os
import ui2

fn find_filebrowser_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_filebrowser_element(child, id) {
			return found
		}
	}
	return none
}

fn test_filebrowser_orders_folders_before_files_and_selects() {
	root_path := os.join_path(os.temp_dir(), 'ui2-filebrowser-${os.getpid()}')
	os.mkdir_all(os.join_path(root_path, 'alpha')) or { panic(err) }
	os.write_file(os.join_path(root_path, 'bravo.txt'), 'bravo') or { panic(err) }
	os.write_file(os.join_path(root_path, 'alpha.txt'), 'alpha') or { panic(err) }
	defer {
		os.rmdir_all(root_path) or {}
	}
	mut app := file_browser_at(root_path)
	assert app.entries.map(it.name) == ['alpha', 'alpha.txt', 'bravo.txt']
	assert app.entries[0].directory
	app.activate(2)
	assert app.selected_name == 'alpha.txt'
	app.confirm_selection()
	assert app.status.starts_with('Selected file:')
	app.cancel_selection()
	assert app.selected_path == ''
}

fn test_filebrowser_opens_folders_and_builds_native_rows() {
	root_path := os.join_path(os.temp_dir(), 'ui2-filebrowser-nav-${os.getpid()}')
	os.mkdir_all(os.join_path(root_path, 'child')) or { panic(err) }
	defer {
		os.rmdir_all(root_path) or {}
	}
	mut app := file_browser_at(root_path)
	root := ui2.element_from_vml_model(filebrowser_vml_source, app, ui2.rect(0, 0, filebrowser_width, filebrowser_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	list := find_filebrowser_element(root, 'browser_list') or { panic('missing browser list') }
	assert list.children.len == 2
	assert list.children[0].native_style
	assert list.children[0].key == app.entries[0].path
	assert (find_filebrowser_element(root, 'open') or { panic('missing open button') }).native_style
	app.activate(1)
	assert app.path.ends_with('child')
}
