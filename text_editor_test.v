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
			text:  'Hello '
			style: TextStyle{}
		},
		TextRun{
			text:  'world'
			style: TextStyle{
				bold:      true
				italic:    true
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

fn test_image_element_keeps_path() {
	el := image('preview', '/tmp/preview.png', rect(1, 2, 300, 200))
	assert el.kind == .image
	assert el.id == 'preview'
	assert el.image_path == '/tmp/preview.png'
	assert el.frame.width == 300
	assert el.frame.height == 200
}
