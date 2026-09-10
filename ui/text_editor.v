module ui2

import strings
import encoding.utf8

// TextSelection stores positions as rune offsets, so cursor movement is stable
// for UTF-8 text. The selection is collapsed when anchor == caret.
pub struct TextSelection {
pub mut:
	anchor int
	caret  int
}

pub fn (s TextSelection) collapsed() bool {
	return s.anchor == s.caret
}

pub fn (s TextSelection) ordered() (int, int) {
	if s.anchor <= s.caret {
		return s.anchor, s.caret
	}
	return s.caret, s.anchor
}

pub struct TextEditor {
pub mut:
	text      string
	selection TextSelection
}

pub fn text_editor(text string) TextEditor {
	length := rune_len(text)
	return TextEditor{
		text: text
		selection: TextSelection{
			anchor: length
			caret: length
		}
	}
}

pub fn (mut e TextEditor) set_text(text string) {
	e.text = text
	e.clamp_selection()
}

pub fn (mut e TextEditor) set_caret(pos int) {
	caret := clamp_int(pos, 0, rune_len(e.text))
	e.selection = TextSelection{
		anchor: caret
		caret: caret
	}
}

pub fn (mut e TextEditor) set_selection(anchor int, caret int) {
	length := rune_len(e.text)
	e.selection = TextSelection{
		anchor: clamp_int(anchor, 0, length)
		caret: clamp_int(caret, 0, length)
	}
}

pub fn (mut e TextEditor) select_all() {
	e.selection = TextSelection{
		anchor: 0
		caret: rune_len(e.text)
	}
}

pub fn (mut e TextEditor) move_caret(delta int, extend bool) {
	length := rune_len(e.text)
	if !extend && !e.selection.collapsed() {
		start, end := e.selection.ordered()
		e.set_caret(if delta < 0 { start } else { end })
		return
	}
	next := clamp_int(e.selection.caret + delta, 0, length)
	if extend {
		e.selection.caret = next
		return
	}
	e.selection = TextSelection{
		anchor: next
		caret: next
	}
}

// move_word_caret moves to the beginning of the previous or next word. Word
// positions are rune offsets, so Ctrl+Arrow remains safe for Unicode input.
pub fn (mut e TextEditor) move_word_caret(direction int, extend bool) {
	if !extend && !e.selection.collapsed() {
		start, end := e.selection.ordered()
		e.set_caret(if direction < 0 { start } else { end })
		return
	}
	runes := e.text.runes()
	next := if direction < 0 {
		previous_word_boundary(runes, e.selection.caret)
	} else {
		next_word_boundary(runes, e.selection.caret)
	}
	e.move_caret_to(next, extend)
}

// move_caret_to moves or extends the selection to an absolute rune offset.
pub fn (mut e TextEditor) move_caret_to(pos int, extend bool) {
	next := clamp_int(pos, 0, rune_len(e.text))
	if extend {
		e.selection.caret = next
		return
	}
	e.set_caret(next)
}

// apply_text_editor_navigation is shared by the custom renderer and tests.
// A single-line field treats Page Up/Down like Home/End, matching the useful
// boundary navigation users expect when there is no vertical viewport.
fn apply_text_editor_navigation(mut editor TextEditor, key string, extend bool, ctrl bool) bool {
	match key {
		'left' {
			if ctrl {
				editor.move_word_caret(-1, extend)
			} else {
				editor.move_caret(-1, extend)
			}
		}
		'right' {
			if ctrl {
				editor.move_word_caret(1, extend)
			} else {
				editor.move_caret(1, extend)
			}
		}
		'home', 'page_up' {
			editor.move_caret_to(0, extend)
		}
		'end', 'page_down' {
			editor.move_caret_to(rune_len(editor.text), extend)
		}
		'a' {
			if !ctrl {
				return false
			}
			editor.select_all()
		}
		else {
			return false
		}
	}
	return true
}

pub fn (mut e TextEditor) insert_text(value string) {
	e.replace_selection(value)
}

pub fn (mut e TextEditor) replace_selection(value string) {
	e.clamp_selection()
	start, end := e.selection.ordered()
	e.text = replace_rune_range(e.text, start, end, value)
	next := start + rune_len(value)
	e.selection = TextSelection{
		anchor: next
		caret: next
	}
}

pub fn (mut e TextEditor) backspace() bool {
	e.clamp_selection()
	if !e.selection.collapsed() {
		e.replace_selection('')
		return true
	}
	if e.selection.caret == 0 {
		return false
	}
	caret := e.selection.caret
	e.text = replace_rune_range(e.text, caret - 1, caret, '')
	e.set_caret(caret - 1)
	return true
}

pub fn (mut e TextEditor) delete_forward() bool {
	e.clamp_selection()
	if !e.selection.collapsed() {
		e.replace_selection('')
		return true
	}
	length := rune_len(e.text)
	if e.selection.caret >= length {
		return false
	}
	caret := e.selection.caret
	e.text = replace_rune_range(e.text, caret, caret + 1, '')
	e.set_caret(caret)
	return true
}

fn (mut e TextEditor) clamp_selection() {
	length := rune_len(e.text)
	e.selection.anchor = clamp_int(e.selection.anchor, 0, length)
	e.selection.caret = clamp_int(e.selection.caret, 0, length)
}

pub fn rune_len(text string) int {
	return text.runes().len
}

@[manualfree]
fn replace_rune_range(text string, start int, end int, value string) string {
	mut runes := text.runes()
	defer {
		unsafe { runes.free() }
	}
	from := clamp_int(start, 0, runes.len)
	to := clamp_int(end, from, runes.len)
	mut result := strings.new_builder(text.len + value.len)
	defer {
		unsafe { result.free() }
	}
	result.write_runes(runes[..from])
	result.write_string(value)
	result.write_runes(runes[to..])
	return result.str()
}

fn clamp_int(value int, min int, max int) int {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}

fn is_word_rune(value rune) bool {
	return utf8.is_letter(value) || utf8.is_number(value) || value == `_`
}

fn previous_word_boundary(runes []rune, caret int) int {
	mut position := clamp_int(caret, 0, runes.len)
	for position > 0 && !is_word_rune(runes[position - 1]) {
		position--
	}
	for position > 0 && is_word_rune(runes[position - 1]) {
		position--
	}
	return position
}

fn next_word_boundary(runes []rune, caret int) int {
	mut position := clamp_int(caret, 0, runes.len)
	for position < runes.len && is_word_rune(runes[position]) {
		position++
	}
	for position < runes.len && !is_word_rune(runes[position]) {
		position++
	}
	return position
}
