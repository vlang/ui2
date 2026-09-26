module ui2

import os

// FilePickerConfig configures the in-window picker. It uses the same modes and
// filters as the synchronous platform dialogs, but never starts another process.
pub struct FilePickerConfig {
pub:
	id          string = 'file_picker'
	dialog      FileDialogConfig
	show_hidden bool
}

pub struct FilePickerEntry {
pub:
	name      string
	path      string
	directory bool
}

// FilePickerResult is returned for every event. A completed cancellation has
// done set and an empty paths array.
pub struct FilePickerResult {
pub:
	handled bool
	done    bool
	paths   []string
}

// FilePicker owns directory and selection state. Keep it alive between builds,
// add render() as the last child of a screen, and forward events to handle().
pub struct FilePicker {
pub:
	config FilePickerConfig
pub mut:
	directory string
	entries   []FilePickerEntry
	selected  []string
	filename  string
	status    string
	visible   bool
	// The first Save on an existing file requests confirmation. A second Save
	// on that same path accepts it.
	overwrite_path string
}

pub fn new_file_picker(config FilePickerConfig) !FilePicker {
	if config.id.len == 0 {
		return error('file picker id cannot be empty')
	}
	mut picker := FilePicker{
		config:   config
		filename: config.dialog.filename
	}
	start := if config.dialog.directory.len > 0 { config.dialog.directory } else { os.getwd() }
	picker.load_directory(start)!
	return picker
}

// open refreshes the directory before showing the picker. It returns an error
// if the location is no longer readable, leaving the previous state intact.
pub fn (mut picker FilePicker) open() ! {
	picker.load_directory(picker.directory)!
	picker.visible = true
}

pub fn (mut picker FilePicker) load_directory(path string) ! {
	absolute := os.abs_path(path)
	if !os.is_dir(absolute) {
		return error('not a directory: ${absolute}')
	}
	real := os.real_path(absolute)
	mut names := os.ls(real)!
	names.sort()
	mut entries := []FilePickerEntry{}
	for want_directory in [true, false] {
		for name in names {
			if !picker.config.show_hidden && name.starts_with('.') {
				continue
			}
			full_path := os.join_path(real, name)
			is_directory := os.is_dir(full_path)
			if is_directory != want_directory {
				continue
			}
			if !is_directory {
				if picker.config.dialog.kind == .folder
					|| !file_picker_matches_filter(name, picker.config.dialog.filters) {
					continue
				}
			}
			entries << FilePickerEntry{
				name:      name
				path:      full_path
				directory: is_directory
			}
		}
	}
	picker.directory = real
	picker.entries = entries
	picker.selected = []string{}
	picker.status = ''
	picker.overwrite_path = ''
}

fn file_picker_matches_filter(name string, filters []FileDialogFilter) bool {
	if filters.len == 0 {
		return true
	}
	for filter in filters {
		for extension in filter.extensions {
			if extension.trim_space() in ['*', '*.*'] {
				return true
			}
		}
	}
	extensions := file_dialog_extensions(filters)
	if extensions.len == 0 {
		return true
	}
	lower := name.to_lower()
	for extension in extensions {
		if lower.ends_with('.' + extension.to_lower()) {
			return true
		}
	}
	return false
}

pub fn (mut picker FilePicker) select_entry(index int) ! {
	if index < 0 || index >= picker.entries.len {
		return error('file picker entry is out of range')
	}
	entry := picker.entries[index]
	if entry.directory {
		picker.load_directory(entry.path)!
		return
	}
	if picker.config.dialog.kind == .folder {
		return
	}
	if picker.config.dialog.kind == .save {
		picker.filename = entry.name
		picker.selected = [entry.path]
		picker.overwrite_path = ''
		return
	}
	if picker.config.dialog.multiple {
		for selected_index, path in picker.selected {
			if path == entry.path {
				picker.selected.delete(selected_index)
				return
			}
		}
		picker.selected << entry.path
	} else {
		picker.selected = [entry.path]
	}
}

// accept validates the current choice and returns absolute paths. A save
// destination may be new; an existing directory is never accepted as a file.
pub fn (mut picker FilePicker) accept() ![]string {
	match picker.config.dialog.kind {
		.folder { return [picker.directory] }
		.open {
			if picker.selected.len == 0 {
				return error('Select a file first.')
			}
			for path in picker.selected {
				if !os.is_file(path) {
					return error('Selected file is no longer available: ${path}')
				}
			}
			return picker.selected.clone()
		}
		.save {
			name := picker.filename.trim_space()
			if name.len == 0 || name == '.' || name == '..' || name.contains('/')
				|| name.contains('\\') {
				return error('Enter a filename without path separators.')
			}
			path := os.join_path(picker.directory, name)
			if os.is_dir(path) {
				return error('The destination is a directory.')
			}
			return [path]
		}
	}
}

// handle consumes picker event ids. Pass ui2.text(event_id_for_path/filename)
// as value for input submissions. The returned paths are ready when done is
// true; an empty array means Cancel. Unrelated ids return handled=false.
pub fn (mut picker FilePicker) handle(event string, value string) FilePickerResult {
	if !picker.visible {
		return FilePickerResult{}
	}
	base := picker.config.id + '__'
	if !event.starts_with(base) {
		return FilePickerResult{}
	}
	action := event[base.len..]
	match action {
		'cancel' {
			picker.visible = false
			return FilePickerResult{ handled: true, done: true }
		}
		'accept' {
			paths := picker.accept() or {
				picker.status = err.msg()
				return FilePickerResult{ handled: true }
			}
			if picker.config.dialog.kind == .save && os.exists(paths[0])
				&& picker.overwrite_path != paths[0] {
				picker.overwrite_path = paths[0]
				picker.status = 'File exists. Press Save again to replace it.'
				return FilePickerResult{ handled: true }
			}
			picker.visible = false
			return FilePickerResult{ handled: true, done: true, paths: paths }
		}
		'up' {
			picker.load_directory(os.dir(picker.directory)) or { picker.status = err.msg() }
		}
		'home' {
			picker.load_directory(os.home_dir()) or { picker.status = err.msg() }
		}
		'go' {
			path := if os.is_abs_path(value) {
				value
			} else {
				os.join_path(picker.directory, value)
			}
			picker.load_directory(path) or { picker.status = err.msg() }
		}
		'filename' {
			picker.filename = value
			picker.overwrite_path = ''
			picker.status = ''
		}
		else {
			if !action.starts_with('entry_') {
				return FilePickerResult{}
			}
			index_text := action['entry_'.len..]
			if index_text.len == 0 || !index_text.bytes().all(it.is_digit()) {
				return FilePickerResult{}
			}
			picker.select_entry(index_text.int()) or { picker.status = err.msg() }
		}
	}
	return FilePickerResult{ handled: true }
}

pub fn (picker &FilePicker) path_id() string {
	return picker.config.id + '__path'
}

pub fn (picker &FilePicker) filename_id() string {
	return picker.config.id + '__filename'
}

// render builds a modal picker inside the supplied screen bounds. The picker
// works with the custom renderer and with native ui2 controls.
pub fn (picker &FilePicker) render(frame Rect) Element {
	mut width := frame.width - 32
	if width > 720 { width = 720 }
	if width < 0 { width = 0 }
	mut height := frame.height - 32
	if height > 560 { height = 560 }
	if height < 0 { height = 0 }
	left := (frame.width - width) / 2
	top := (frame.height - height) / 2
	padding := f64(16)
	inner_width := if width > padding * 2 { width - padding * 2 } else { 0.0 }
	button_width := f64(72)
	button_height := f64(32)
	mut children := []Element{}
	title := if picker.config.dialog.title.len > 0 {
		picker.config.dialog.title
	} else {
		match picker.config.dialog.kind {
			.open { 'Open file' }
			.save { 'Save file' }
			.folder { 'Choose folder' }
		}
	}
	children << label(picker.config.id + '__title', title, rect(padding, 12, inner_width, 28),
		TextStyle{ size: 19, bold: true, color: 0x111827 })
	children << button(picker.config.id + '__up', 'Up', rect(padding, 52, 56, button_height),
		BoxStyle{ bg: 0xe2e8f0, radius: 5 }, TextStyle{ color: 0x1e293b })
	children << button(picker.config.id + '__home', 'Home', rect(padding + 64, 52, 64,
		button_height), BoxStyle{ bg: 0xe2e8f0, radius: 5 }, TextStyle{ color: 0x1e293b })
	path_width := if inner_width > 202 { inner_width - 202 } else { 0.0 }
	children << text_field_with_submit(picker.path_id(), picker.config.id + '__go',
		'Directory', picker.directory, rect(padding + 136, 52, path_width, button_height),
		BoxStyle{
			bg:            0xffffff
			border_color:  0xcbd5e1
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, TextStyle{ color: 0x111827, size: 13 },
		keyboard_default)
	children << button(picker.config.id + '__go', 'Go', rect(width - padding - 58, 52, 58,
		button_height), BoxStyle{ bg: 0xe2e8f0, radius: 5 }, TextStyle{ color: 0x1e293b })
	list_top := f64(96)
	footer_height := if picker.config.dialog.kind == .save { f64(132) } else { f64(92) }
	list_height := if height > list_top + footer_height {
		height - list_top - footer_height
	} else {
		0.0
	}
	mut rows := []Element{}
	for index, entry in picker.entries {
		mut selected := false
		for path in picker.selected {
			if path == entry.path {
				selected = true
				break
			}
		}
		row_color := if selected {
			u32(0xbfdbfe)
		} else if index % 2 == 0 {
			u32(0xffffff)
		} else {
			u32(0xf8fafc)
		}
		prefix := if entry.directory { '[DIR] ' } else { '      ' }
		rows << Element{
			...button('${picker.config.id}__entry_${index}', prefix + entry.name,
				rect(0, f64(index) * 34, inner_width, 34), BoxStyle{ bg: row_color },
				TextStyle{ color: 0x111827, size: 14, align: .left })
			accessibility_role:  'listitem'
			accessibility_label: entry.name
			accessibility_value: if selected { 'selected' } else { '' }
		}
	}
	children << scroll(picker.config.id + '__list', rect(padding, list_top, inner_width,
		list_height), 0xffffff, rows)
	if picker.config.dialog.kind == .save {
		children << label(picker.config.id + '__filename_label', 'File name',
			rect(padding, height - 120, 90, 32), TextStyle{ color: 0x334155 })
		children << text_field_with_change_and_submit(picker.filename_id(), picker.config.id + '__accept',
			'File name', picker.filename, rect(padding + 94, height - 120, inner_width - 94, 32),
			BoxStyle{
				bg:            0xffffff
				border_color:  0xcbd5e1
				border_left:   1
				border_top:    1
				border_right:  1
				border_bottom: 1
			}, TextStyle{ color: 0x111827 },
			keyboard_default)
	}
	children << label(picker.config.id + '__status', picker.status,
		rect(padding, height - 80, inner_width - 180, 28), TextStyle{ color: 0xb91c1c, size: 12 })
	children << button(picker.config.id + '__cancel', 'Cancel',
		rect(width - padding - button_width * 2 - 8, height - 56, button_width,
			button_height), BoxStyle{ bg: 0xe2e8f0, radius: 5 }, TextStyle{ color: 0x1e293b })
	accept_title := if picker.config.dialog.kind == .save {
		'Save'
	} else if picker.config.dialog.kind == .folder {
		'Choose'
	} else {
		'Open'
	}
	children << button(picker.config.id + '__accept', accept_title,
		rect(width - padding - button_width, height - 56, button_width, button_height),
		BoxStyle{ bg: 0x2563eb, radius: 5 }, TextStyle{ color: 0xffffff })
	panel := view(picker.config.id + '__panel', rect(left, top, width, height),
		BoxStyle{ bg: 0xffffff, radius: 10 }, children)
	return Element{
		...clickable_view(picker.config.id, frame, BoxStyle{ bg: 0x94a3b8 }, [panel])
		hidden: !picker.visible
	}
}
