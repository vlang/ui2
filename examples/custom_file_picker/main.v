module main

import os
import ui2

const picker_width = 720
const picker_height = 520

struct PickerDemo {
mut:
	picker    ui2.FilePicker
	selection string = 'Choose a mode to open the in-window picker.'
}

const picker_demo = &PickerDemo{}

fn build_picker_demo() ui2.Element {
	state := unsafe { picker_demo }
	button_box := ui2.BoxStyle{ bg: 0x2563eb, radius: 6 }
	button_text := ui2.TextStyle{ color: 0xffffff }
	return ui2.screen(0xf1f5f9, [
		ui2.label('heading', 'Custom file picker', ui2.rect(24, 20, 660, 32),
			ui2.TextStyle{ size: 22, bold: true }),
		ui2.label('description', 'Browse files inside this window, without desktop dialog helpers.',
			ui2.rect(24, 58, 660, 24), ui2.TextStyle{ color: 0x475569, size: 13 }),
		ui2.button('open', 'Open files', ui2.rect(24, 112, 140, 38), button_box, button_text),
		ui2.button('save', 'Save file', ui2.rect(176, 112, 140, 38), button_box, button_text),
		ui2.button('folder', 'Choose folder', ui2.rect(328, 112, 160, 38), button_box,
			button_text),
		ui2.label('selection', state.selection, ui2.rect(24, 180, 670, 80),
			ui2.TextStyle{ color: 0x166534, size: 14 }),
		state.picker.render(ui2.rect(0, 0, picker_width, picker_height)),
	])
}

fn handle_picker_demo(event string) {
	mut state := unsafe { picker_demo }
	value := if event == state.picker.config.id + '__go' {
		ui2.text(state.picker.path_id())
	} else if event == state.picker.filename_id() {
		ui2.text(state.picker.filename_id())
	} else {
		''
	}
	result := state.picker.handle(event, value)
	if result.handled {
		if result.done {
			state.selection = if result.paths.len > 0 {
				result.paths.join('\n')
			} else {
				'Cancelled.'
			}
		}
		ui2.refresh()
		return
	}
	kind := match event {
		'open' { ui2.FileDialogKind.open }
		'save' { ui2.FileDialogKind.save }
		'folder' { ui2.FileDialogKind.folder }
		else { return }
	}
	state.picker = ui2.new_file_picker(
		id:     'demo_picker'
		dialog: ui2.FileDialogConfig{
			kind:      kind
			directory: os.getwd()
			filename:  'new_file.txt'
			multiple:  true
		}
	) or {
		state.selection = 'Cannot open picker: ${err}'
		ui2.refresh()
		return
	}
	state.picker.open() or { state.selection = 'Cannot open picker: ${err}' }
	ui2.refresh()
}

fn main() {
	ui2.run_window('Custom file picker', picker_width, picker_height, build_picker_demo,
		handle_picker_demo)
}
