module main

import ui2

const files_dropped_width = 620
const files_dropped_height = 400
const files_dropped_qml_source = $embed_file('files_dropped.qml').to_string()

pub struct DroppedFile {
pub:
	id   int
	name string
	path string
}

@[heap]
pub struct FilesDroppedDemo {
pub mut:
	files   []DroppedFile
	next_id int = 1
	status  string = 'Drop files anywhere in this window.'
}

const files_dropped_state = &FilesDroppedDemo{}

fn dropped_name(path string) string {
	name := path.replace('\\', '/').all_after_last('/')
	return if name.len > 0 { name } else { path }
}

fn (mut app FilesDroppedDemo) receive(paths []string, dropped_text string) {
	for path in paths {
		app.files << DroppedFile{
			id: app.next_id
			name: dropped_name(path)
			path: path
		}
		app.next_id++
	}
	if paths.len == 0 && dropped_text.len > 0 {
		app.files << DroppedFile{
			id: app.next_id
			name: 'Dropped text'
			path: dropped_text
		}
		app.next_id++
	}
	app.status = match app.files.len {
		0 { 'Drop files anywhere in this window.' }
		1 { '1 dropped item' }
		else { '${app.files.len} dropped items' }
	}
}

fn build_files_dropped_screen() ui2.Element {
	state := unsafe { files_dropped_state }
	return ui2.element_from_qml_model(files_dropped_qml_source, *state, ui2.bounds()) or {
		eprintln('files-dropped QML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_files_dropped_event(_event string) {}

fn handle_files_drop(event ui2.DropEvent) {
	mut state := unsafe { files_dropped_state }
	state.receive(event.paths, event.text)
	ui2.refresh()
}

fn main() {
	ui2.on_drop(handle_files_drop)
	ui2.run_window('Dropped Files', files_dropped_width, files_dropped_height, build_files_dropped_screen, handle_files_dropped_event)
}
