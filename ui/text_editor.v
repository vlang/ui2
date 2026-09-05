module ui2

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

fn replace_rune_range(text string, start int, end int, value string) string {
	runes := text.runes()
	from := clamp_int(start, 0, runes.len)
	to := clamp_int(end, from, runes.len)
	return runes[..from].string() + value + runes[to..].string()
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
