module main

import os
import ui2

const editor_width = 900
const editor_height = 600
const editor_qml_source = $embed_file('editor.qml').to_string()

pub struct EditorFile {
pub:
	id   int
	name string
	path string
}

pub struct EditorDemo {
pub mut:
	root_path    string
	files        []EditorFile
	current_path string
	current_name string
	text         string
	new_name     string
	dirty        bool
	sidebar_open bool = true
	status       string
}

fn editor_at(path string) EditorDemo {
	mut app := EditorDemo{ root_path: os.real_path(path) }
	app.refresh_files() or { app.status = 'Cannot list ${path}: ${err}' }
	if app.files.len > 0 {
		app.open_file(app.files[0].id)
	} else if app.status.len == 0 {
		app.status = 'No editable files in this folder.'
	}
	return app
}

fn editor_file_supported(name string) bool {
	extension := os.file_ext(name).to_lower()
	return extension in ['', '.v', '.md', '.txt', '.json', '.toml', '.yaml', '.yml', '.qml', '.c',
		'.h']
}

fn (mut app EditorDemo) refresh_files() ! {
	mut names := os.ls(app.root_path)!
	names.sort()
	mut files := []EditorFile{}
	for name in names {
		path := os.join_path(app.root_path, name)
		if os.is_file(path) && editor_file_supported(name) {
			files << EditorFile{
				id: files.len + 1
				name: name
				path: path
			}
		}
		if files.len == 40 {
			break
		}
	}
	app.files = files
}

pub fn (mut app EditorDemo) open_file(id int) {
	for file in app.files {
		if file.id != id {
			continue
		}
		contents := os.read_file(file.path) or {
			app.status = 'Cannot open ${file.name}: ${err}'
			return
		}
		if contents.len > 1024 * 1024 {
			app.status = '${file.name} is larger than 1 MB.'
			return
		}
		app.current_path = file.path
		app.current_name = file.name
		app.text = contents
		app.dirty = false
		app.status = '${file.name} opened.'
		return
	}
}

pub fn (mut app EditorDemo) mark_dirty() {
	if app.current_path.len > 0 {
		app.dirty = true
		app.status = '${app.current_name} has unsaved changes.'
	}
}

pub fn (mut app EditorDemo) save_file() {
	if app.current_path.len == 0 {
		app.status = 'Open or create a file first.'
		return
	}
	os.write_file(app.current_path, app.text) or {
		app.status = 'Cannot save ${app.current_name}: ${err}'
		return
	}
	app.dirty = false
	app.status = '${app.current_name} saved.'
}

pub fn (mut app EditorDemo) create_file() {
	name := app.new_name.trim_space()
	if name.len == 0 || os.file_name(name) != name || name in ['.', '..'] {
		app.status = 'Enter a valid file name.'
		return
	}
	path := os.join_path(app.root_path, name)
	if os.exists(path) {
		app.status = '${name} already exists.'
		return
	}
	os.write_file(path, '') or {
		app.status = 'Cannot create ${name}: ${err}'
		return
	}
	app.refresh_files() or {
		app.status = 'Created ${name}, but cannot refresh the file list: ${err}'
		return
	}
	app.new_name = ''
	for file in app.files {
		if file.path == path {
			app.open_file(file.id)
			app.status = '${name} created.'
			return
		}
	}
}

fn main() {
	ui2.run_qml[EditorDemo](
		source: editor_qml_source
		model: editor_at(os.getwd())
		title: 'Editor'
		width: editor_width
		height: editor_height
	) or {
		panic(err)
	}
}
