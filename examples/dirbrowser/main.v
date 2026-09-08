module main

import os
import ui2

const dirbrowser_width = 720
const dirbrowser_height = 480
const dirbrowser_vml_source = $embed_file('dirbrowser.vml').to_string()

pub struct DirectoryEntry {
pub:
	id   int
	name string
	path string
}

pub struct DirectoryBrowserDemo {
pub mut:
	path    string
	entries []DirectoryEntry
	status  string
}

fn directory_browser_at(path string) DirectoryBrowserDemo {
	mut app := DirectoryBrowserDemo{}
	app.load_directory(path) or { app.status = 'Cannot open ${path}: ${err}' }
	return app
}

fn (mut app DirectoryBrowserDemo) load_directory(path string) ! {
	real_path := os.real_path(path)
	mut names := os.ls(real_path)!
	names.sort()
	mut entries := []DirectoryEntry{}
	for name in names {
		full_path := os.join_path(real_path, name)
		if os.is_dir(full_path) {
			entries << DirectoryEntry{
				id: entries.len + 1
				name: name
				path: full_path
			}
		}
	}
	app.path = real_path
	app.entries = entries
	app.status = '${entries.len} folders in ${os.file_name(real_path)}.'
}

pub fn (mut app DirectoryBrowserDemo) open_entry(id int) {
	for entry in app.entries {
		if entry.id == id {
			app.load_directory(entry.path) or { app.status = 'Cannot open ${entry.name}: ${err}' }
			return
		}
	}
}

pub fn (mut app DirectoryBrowserDemo) go_parent() {
	parent := os.dir(app.path)
	if parent == app.path {
		app.status = 'Already at the filesystem root.'
		return
	}
	app.load_directory(parent) or { app.status = 'Cannot open parent: ${err}' }
}

pub fn (mut app DirectoryBrowserDemo) choose_current() {
	app.status = 'Selected folder: ${app.path}'
}

fn main() {
	ui2.run_vml[DirectoryBrowserDemo](
		source: dirbrowser_vml_source
		model: directory_browser_at(os.getwd())
		title: 'Directory Browser'
		width: dirbrowser_width
		height: dirbrowser_height
	) or { panic(err) }
}
