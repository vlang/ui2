module ui2

fn test_text_editor_insert_and_replace_selection() {
	mut editor := text_editor('Hello world')
	editor.set_selection(6, 11)
	editor.insert_text('V')
	assert editor.text == 'Hello V'
	assert editor.selection.caret == 7
	assert editor.selection.collapsed()
}

fn test_text_editor_deletes_utf8_by_rune() {
	mut editor := text_editor('a🙂b')
	editor.set_caret(2)
	assert editor.backspace()
	assert editor.text == 'ab'
	assert editor.selection.caret == 1
	assert editor.delete_forward()
	assert editor.text == 'a'
}

fn test_rune_len_counts_utf8_code_points() {
	assert rune_len('a🙂é') == 3
}

fn test_text_editor_clamps_publicly_mutated_selection_before_editing() {
	mut editor := text_editor('a')
	editor.selection.anchor = 100
	editor.selection.caret = 100
	editor.insert_text('x')
	assert editor.text == 'ax'
	assert editor.selection.caret == 2

	editor.selection.anchor = -20
	editor.selection.caret = -10
	assert !editor.backspace()
	assert editor.selection.caret == 0
}

fn test_reconciliation_keys_escape_path_separators_and_validate_duplicates() {
	a := Element{ kind: .view, key: 'a/k:b' }
	b := Element{ kind: .view, key: 'a', children: [Element{ kind: .label, key: 'b' }] }
	assert reconciliation_child_key('', 0, a) != reconciliation_child_key(reconciliation_child_key('', 0, b), 0, b.children[0])

	duplicate := screen(0xffffff, [Element{ kind: .view, key: 'same' },
		Element{ kind: .label, key: 'same' }])
	if _ := validate_element_tree(duplicate) {
		assert false, 'duplicate sibling keys must be rejected'
	}
	duplicate_id := screen(0xffffff, [
		label('same', 'one', rect(0, 0, 10, 10), TextStyle{}),
		button('same', 'two', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}),
	])
	if _ := validate_element_tree(duplicate_id) {
		assert false, 'duplicate ids must be rejected'
	}
}

fn test_rect_intersection_clips_partial_and_disjoint_bounds() {
	assert intersect_rect(rect(0, 0, 100, 100), rect(50, 20, 100, 30)) == rect(50, 20, 50, 30)
	assert intersect_rect(rect(0, 0, 10, 10), rect(20, 20, 5, 5)).width == 0
}

fn test_native_rich_text_run_decoder_preserves_link_metadata() {
	$if macos && !ui2_custom_rendering ? {
		raw := 'SGVsbG8=\tSGVsdmV0aWNh\t15.000\t0\t0\t1\t\t0\t1118481\t0\t0\taHR0cHM6Ly9leGFtcGxlLmNvbQ==\n'
		runs := parse_text_area_runs(raw)
		assert runs.len == 1
		assert runs[0].text == 'Hello'
		assert runs[0].style.link == 'https://example.com'
	}
}

fn test_text_editor_move_and_select_all() {
	mut editor := text_editor('abc')
	editor.set_caret(1)
	editor.move_caret(1, true)
	start, end := editor.selection.ordered()
	assert start == 1
	assert end == 2
	editor.select_all()
	start2, end2 := editor.selection.ordered()
	assert start2 == 0
	assert end2 == 3
}

fn test_rich_text_area_keeps_runs() {
	runs := [
		TextRun{
			text: 'Hello '
			style: TextStyle{}
		},
		TextRun{
			text: 'world'
			style: TextStyle{
				bold: true
				italic: true
				underline: true
			}
		},
	]
	el := rich_text_area('body', 'Hello world', runs, rect(0, 0, 200, 80), BoxStyle{}, TextStyle{})
	assert el.kind == .text_area
	assert el.text == 'Hello world'
	assert el.text_runs.len == 2
	assert el.text_runs[1].style.bold
	assert el.text_runs[1].style.italic
	assert el.text_runs[1].style.underline
}

fn test_text_area_without_scroll_sets_disable_scroll() {
	el := text_area_without_scroll('body', 'Hello', rect(0, 0, 200, 80), BoxStyle{}, TextStyle{})
	assert el.kind == .text_area
	assert el.disable_scroll
	rich :=
		rich_text_area_without_scroll('rich', 'Hello', []TextRun{}, rect(0, 0, 200, 80), BoxStyle{}, TextStyle{})
	assert rich.kind == .text_area
	assert rich.disable_scroll
}

fn test_image_element_keeps_path() {
	el := image('preview', '/tmp/preview.png', rect(1, 2, 300, 200))
	assert el.kind == .image
	assert el.id == 'preview'
	assert el.image_path == '/tmp/preview.png'
	assert el.frame.width == 300
	assert el.frame.height == 200
}

fn test_portable_text_area_range_uses_utf16_and_keeps_selection_length() {
	selection := clamped_text_area_selection('A🙂BC', 1, 2)
	assert selection.location == 1
	assert selection.length == 2
	assert text_area_utf16_length('A🙂BC') == 5

	clamped := clamped_text_area_selection('A🙂BC', 4, 99)
	assert clamped.location == 4
	assert clamped.length == 1
	record_portable_text_area_selection('portable-editor', clamped)
	assert portable_text_area_selection('portable-editor') == clamped
	assert utf16_offset_to_rune_index('A🙂BC', 3) == 2
	assert rune_index_to_utf16_offset('A🙂BC', 2) == 3
	forget_portable_text_area_selection('portable-editor')
	assert portable_text_area_selection('portable-editor') == TextAreaSelectionRange{}
}

fn test_submit_only_text_field_and_secure_display_text() {
	el := text_field_with_submit('message', 'send_message', 'Message', 'Привет🙂', rect(0, 0, 200, 40), BoxStyle{}, TextStyle{}, keyboard_default)
	assert el.kind == .text_field
	assert el.submit_id == 'send_message'
	assert !el.emit_change
	assert text_field_display_text(el.text, false) == 'Привет🙂'
	assert text_field_display_text(el.text, true) == '•••••••'
}
