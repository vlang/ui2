module main

import os
import ui2

fn find_editor_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_editor_element(child, id) {
			return found
		}
	}
	return none
}

fn test_editor_opens_edits_saves_and_creates_files() {
	root_path := os.join_path(os.temp_dir(), 'ui2-editor-${os.getpid()}')
	os.mkdir_all(root_path) or { panic(err) }
	os.write_file(os.join_path(root_path, 'alpha.txt'), 'hello') or { panic(err) }
	os.write_file(os.join_path(root_path, 'ignored.bin'), 'binary') or { panic(err) }
	defer {
		os.rmdir_all(root_path) or {}
	}
	mut app := editor_at(root_path)
	assert app.files.len == 1
	assert app.current_name == 'alpha.txt'
	assert app.text == 'hello'
	app.text = 'updated'
	app.mark_dirty()
	assert app.dirty
	app.save_file()
	assert os.read_file(app.current_path)! == 'updated'
	app.new_name = 'beta.v'
	app.create_file()
	assert app.current_name == 'beta.v'
	assert os.exists(os.join_path(root_path, 'beta.v'))
}

fn test_editor_rejects_unsafe_or_duplicate_names() {
	root_path := os.join_path(os.temp_dir(), 'ui2-editor-name-${os.getpid()}')
	os.mkdir_all(root_path) or { panic(err) }
	os.write_file(os.join_path(root_path, 'alpha.txt'), '') or { panic(err) }
	defer {
		os.rmdir_all(root_path) or {}
	}
	mut app := editor_at(root_path)
	app.new_name = '../escape.txt'
	app.create_file()
	assert app.status == 'Enter a valid file name.'
	app.new_name = 'alpha.txt'
	app.create_file()
	assert app.status == 'alpha.txt already exists.'
}

fn test_editor_vml_builds_keyed_file_list_and_responsive_editor() {
	app := EditorDemo{
		root_path: '/tmp'
		files: [EditorFile{ id: 1, name: 'demo.v', path: '/tmp/demo.v' }]
		current_path: '/tmp/demo.v'
		current_name: 'demo.v'
		text: 'fn main() {}'
	}
	root := ui2.element_from_vml_model(editor_vml_source, app, ui2.rect(0, 0, editor_width, editor_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	list := find_editor_element(root, 'editor_files') or { panic('missing file list') }
	area := find_editor_element(root, 'editor_text') or { panic('missing editor') }
	assert list.children.len == 1
	assert list.children[0].key == '/tmp/demo.v'
	assert list.children[0].native_style
	assert area.emit_change
	assert area.text_style.font_family == 'Courier New'
	assert (find_editor_element(root, 'save_file') or { panic('missing save') }).native_style
}
