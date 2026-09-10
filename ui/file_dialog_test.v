module ui2

fn test_file_dialog_normalizes_extensions_and_deduplicates_them() {
	filters := [
		FileDialogFilter{
			name: 'V source'
			extensions: ['v', '.v', '*.vv', '*.*']
		},
		FileDialogFilter{
			name: 'Text'
			extensions: ['txt', ' .md ']
		},
	]
	assert file_dialog_extensions(filters) == ['v', 'vv', 'txt', 'md']
}

fn test_file_dialog_filter_spec_uses_native_wildcards_and_has_a_fallback() {
	assert file_dialog_filter_spec([
		FileDialogFilter{
			name: 'V source'
			extensions: ['v', '.vv']
		},
	]) == 'V source|*.v;*.vv|All files|*.*'
	assert file_dialog_filter_spec([]) == 'All files|*.*'
}

fn test_file_dialog_convenience_functions_choose_their_expected_kind() {
	text_filter := FileDialogFilter{
		name: 'Text'
		extensions: ['txt']
	}
	cfg := FileDialogConfig{
		title: 'Choose a document'
		directory: '/tmp'
		filename: 'draft.txt'
		multiple: true
		filters: [text_filter]
	}
	assert open_file_dialog_config(cfg).kind == .open
	assert save_file_dialog_config(cfg).kind == .save
	assert open_folder_dialog_config(cfg).kind == .folder
}
