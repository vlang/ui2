// vfmt off
module ui2

#flag windows -lcomdlg32
#flag windows -lshell32
#flag windows -lole32

#insert "@VMODROOT/windows/file_dialog_windows.h"

// A multi-select response repeats the containing folder for every result on
// the V side, so leave room for up to twice the native common-dialog buffer.
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
	return unsafe { string_from_wide(&output[0]) }.split('\n')
}
