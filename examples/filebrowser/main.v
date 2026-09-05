module main

import os
import ui2

const filebrowser_width = 760
const filebrowser_height = 520
const filebrowser_qml_source = $embed_file('filebrowser.qml').to_string()

pub struct BrowserEntry {
pub:
	id        int
	name      string
	path      string
	directory bool
}

pub struct FileBrowserDemo {
pub mut:
	path          string
	entries       []BrowserEntry
	selected_path string
	selected_name string
	status        string
}

fn file_browser_at(path string) FileBrowserDemo {
	mut app := FileBrowserDemo{}
	app.load_directory(path) or { app.status = 'Cannot open ${path}: ${err}' }
	return app
}

fn (mut app FileBrowserDemo) load_directory(path string) ! {
	real_path := os.real_path(path)
	mut names := os.ls(real_path)!
	names.sort()
	mut entries := []BrowserEntry{}
	for want_directory in [true, false] {
		for name in names {
			full_path := os.join_path(real_path, name)
			is_directory := os.is_dir(full_path)
			if is_directory != want_directory {
				continue
			}
			entries << BrowserEntry{
				id: entries.len + 1
				name: name
				path: full_path
				directory: is_directory
			}
		}
	}
	app.path = real_path
	app.entries = entries
	app.selected_path = ''
	app.selected_name = ''
	location := if os.file_name(real_path).len > 0 { os.file_name(real_path) } else { real_path }
	app.status = '${entries.len} items in ${location}.'
}

pub fn (mut app FileBrowserDemo) activate(id int) {
	for entry in app.entries {
		if entry.id != id {
			continue
		}
		if entry.directory {
			app.load_directory(entry.path) or { app.status = 'Cannot open ${entry.name}: ${err}' }
		} else {
			app.selected_path = entry.path
			app.selected_name = entry.name
			app.status = '${entry.name} selected.'
		}
		return
	}
}

pub fn (mut app FileBrowserDemo) go_parent() {
	parent := os.dir(app.path)
	if parent == app.path {
		app.status = 'Already at the filesystem root.'
		return
	}
	app.load_directory(parent) or { app.status = 'Cannot open parent: ${err}' }
}

pub fn (mut app FileBrowserDemo) confirm_selection() {
	if app.selected_path.len == 0 {
		app.status = 'Select a file first.'
		return
	}
	app.status = 'Selected file: ${app.selected_path}'
}

pub fn (mut app FileBrowserDemo) cancel_selection() {
	app.selected_path = ''
	app.selected_name = ''
	app.status = 'Selection cancelled.'
}

fn main() {
	ui2.run_qml[FileBrowserDemo](
		source: filebrowser_qml_source
		model: file_browser_at(os.getwd())
		title: 'File Browser'
		width: filebrowser_width
		height: filebrowser_height
	) or {
		panic(err)
	}
}
