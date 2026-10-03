module ui2

import os

fn file_picker_test_dir(name string) string {
	dir := os.join_path(os.temp_dir(), 'ui2_file_picker_test', name)
	os.rmdir_all(dir) or {}
	os.mkdir_all(os.join_path(dir, 'sub')) or { panic(err) }
	os.write_file(os.join_path(dir, 'a.V'), 'a') or { panic(err) }
	os.write_file(os.join_path(dir, 'b.txt'), 'b') or { panic(err) }
	os.write_file(os.join_path(dir, 'c.v'), 'c') or { panic(err) }
	os.write_file(os.join_path(dir, '.hidden.v'), 'hidden') or { panic(err) }
	return dir
}

fn test_file_picker_filters_and_navigates_directories() {
	dir := file_picker_test_dir('navigation')
	defer { os.rmdir_all(dir) or {} }
	mut picker := new_file_picker(
		id:     'choose'
		dialog: FileDialogConfig{
			directory: dir
			filters:   [FileDialogFilter{ extensions: ['*.v'] }]
		}
	) or { panic(err) }
	assert picker.entries.map(it.name) == ['sub', 'a.V', 'c.v']
	picker.open() or { panic(err) }
	result := picker.handle('choose__entry_0', '')
	assert result.handled && !result.done
	assert picker.directory == os.real_path(os.join_path(dir, 'sub'))
	assert picker.entries.len == 0
	assert picker.handle('choose__up', '').handled
	assert picker.directory == os.real_path(dir)
	assert picker.handle('choose__go', 'sub').handled
	assert picker.directory == os.real_path(os.join_path(dir, 'sub'))
	assert picker.handle('choose__go', 'missing').handled
	assert picker.status.len > 0
	assert picker.directory == os.real_path(os.join_path(dir, 'sub'))
}

fn test_file_picker_wildcard_filter_shows_every_file() {
	assert file_picker_matches_filter('anything.bin', [FileDialogFilter{
		extensions: ['*.v', '*.*']
	}])
	assert !file_picker_matches_filter('anything.bin', [FileDialogFilter{
		extensions: ['*.v']
	}])
}

fn test_file_picker_open_selection_and_completion() {
	dir := file_picker_test_dir('selection')
	defer { os.rmdir_all(dir) or {} }
	mut picker := new_file_picker(
		id:     'files'
		dialog: FileDialogConfig{ directory: dir, multiple: true }
	) or { panic(err) }
	picker.open() or { panic(err) }
	assert picker.handle('files__accept', '').handled
	assert picker.status.len > 0
	assert picker.visible
	assert picker.handle('files__entry_1', '').handled
	assert picker.handle('files__entry_2', '').handled
	assert picker.selected.len == 2
	assert picker.handle('files__entry_1', '').handled
	assert picker.selected.len == 1
	assert picker.handle('other__cancel', '').handled == false
	assert picker.handle('files__entry_bad', '').handled == false
	result := picker.handle('files__accept', '')
	assert result.handled && result.done
	assert result.paths == [os.join_path(os.real_path(dir), 'b.txt')]
	assert !picker.visible
	picker.open() or { panic(err) }
	cancelled := picker.handle('files__cancel', '')
	assert cancelled.handled && cancelled.done && cancelled.paths.len == 0
}

fn test_file_picker_save_and_folder_validation() {
	dir := file_picker_test_dir('save')
	defer { os.rmdir_all(dir) or {} }
	mut save := new_file_picker(
		id:     'save'
		dialog: FileDialogConfig{ kind: .save, directory: dir, filename: 'new.txt' }
	) or { panic(err) }
	save.open() or { panic(err) }
	assert save.handle('save__filename', '../escape').handled
	assert save.handle('save__accept', '').done == false
	assert save.status.len > 0
	assert save.handle('save__filename', 'report.txt').handled
	result := save.handle('save__accept', '')
	assert result.done
	assert result.paths == [os.join_path(os.real_path(dir), 'report.txt')]
	save.open() or { panic(err) }
	assert save.handle('save__filename', 'b.txt').handled
	first_save := save.handle('save__accept', '')
	assert first_save.handled && !first_save.done
	assert save.status.contains('replace')
	second_save := save.handle('save__accept', '')
	assert second_save.done
	assert second_save.paths == [os.join_path(os.real_path(dir), 'b.txt')]
	mut folder := new_file_picker(
		id:     'folder'
		dialog: FileDialogConfig{ kind: .folder, directory: dir }
	) or { panic(err) }
	assert folder.entries.map(it.name) == ['sub']
	folder.open() or { panic(err) }
	assert folder.handle('folder__entry_0', '').handled
	result_folder := folder.handle('folder__accept', '')
	assert result_folder.done
	assert result_folder.paths == [os.real_path(os.join_path(dir, 'sub'))]
}

fn test_file_picker_builds_valid_element_tree() {
	dir := file_picker_test_dir('render')
	defer { os.rmdir_all(dir) or {} }
	mut picker := new_file_picker(
		id:     'picker'
		dialog: FileDialogConfig{ kind: .save, directory: dir }
	) or { panic(err) }
	picker.open() or { panic(err) }
	panel := picker.render(rect(0, 0, 640, 480))
	assert !panel.hidden
	validate_element_tree(panel) or { panic(err) }
	assert panel.children[0].children.any(it.id == picker.filename_id())
}
