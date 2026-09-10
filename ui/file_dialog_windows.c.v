// vfmt off
module ui2

import os

#flag windows -lcomdlg32
#flag windows -lshell32
#flag windows -lole32

#insert "@VMODROOT/windows/file_dialog_windows.h"

// The native common dialog uses a maximum 32,768 UTF-16 character result
// buffer. Multi-select responses retain that compact folder-plus-filenames
// representation until V expands it below.
const file_dialog_windows_buffer_size = 65536

fn C.ui2_win_file_dialog(output &u16, output_capacity u32, title &u16, directory &u16, filename &u16, filter_spec &u16, kind int, multiple int) int

fn native_file_dialog_supported() bool {
	return true
}

fn native_file_dialog(cfg FileDialogConfig) []string {
	mut output := []u16{len: file_dialog_windows_buffer_size}
	title := cfg.title.to_wide()
	directory := cfg.directory.to_wide()
	filename := cfg.filename.to_wide()
	filter_spec := file_dialog_filter_spec(cfg.filters).to_wide()
	accepted := C.ui2_win_file_dialog(unsafe { &output[0] }, file_dialog_windows_buffer_size,
		title, directory, filename, filter_spec, int(cfg.kind), if cfg.kind == .open && cfg.multiple {
		1
	} else {
		0
	})
	unsafe {
		free(title)
		free(directory)
		free(filename)
		free(filter_spec)
	}
	if accepted == 0 || output[0] == 0 {
		return []string{}
	}
	paths := unsafe { string_from_wide(&output[0]) }.split('\n')
	if cfg.kind == .open && cfg.multiple && paths.len > 1 {
		return paths[1..].map(os.join_path(paths[0], it))
	}
	return paths
}
