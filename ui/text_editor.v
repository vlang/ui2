module ui2

import strings
import encoding.utf8

const unicode_mark_ranges = [
	u32(0x0300),
	0x036f,
	0x0483,
	0x0489,
	0x0591,
	0x05bd,
	0x05bf,
	0x05bf,
	0x05c1,
	0x05c2,
	0x05c4,
	0x05c5,
	0x05c7,
	0x05c7,
	0x0610,
	0x061a,
	0x064b,
	0x065f,
	0x0670,
	0x0670,
	0x06d6,
	0x06dc,
	0x06df,
	0x06e4,
	0x06e7,
	0x06e8,
	0x06ea,
	0x06ed,
	0x0711,
	0x0711,
	0x0730,
	0x074a,
	0x07a6,
	0x07b0,
	0x07eb,
	0x07f3,
	0x07fd,
	0x07fd,
	0x0816,
	0x0819,
	0x081b,
	0x0823,
	0x0825,
	0x0827,
	0x0829,
	0x082d,
	0x0859,
	0x085b,
	0x08d3,
	0x08e1,
	0x08e3,
	0x0903,
	0x093a,
	0x093c,
	0x093e,
	0x094f,
	0x0951,
	0x0957,
	0x0962,
	0x0963,
	0x0981,
	0x0983,
	0x09bc,
	0x09bc,
	0x09be,
	0x09c4,
	0x09c7,
	0x09c8,
	0x09cb,
	0x09cd,
	0x09d7,
	0x09d7,
	0x09e2,
	0x09e3,
	0x09fe,
	0x09fe,
	0x0a01,
	0x0a03,
	0x0a3c,
	0x0a3c,
	0x0a3e,
	0x0a42,
	0x0a47,
	0x0a48,
	0x0a4b,
	0x0a4d,
	0x0a51,
	0x0a51,
	0x0a70,
	0x0a71,
	0x0a75,
	0x0a75,
	0x0a81,
	0x0a83,
	0x0abc,
	0x0abc,
	0x0abe,
	0x0ac5,
	0x0ac7,
	0x0ac9,
	0x0acb,
	0x0acd,
	0x0ae2,
	0x0ae3,
	0x0afa,
	0x0aff,
	0x0b01,
	0x0b03,
	0x0b3c,
	0x0b3c,
	0x0b3e,
	0x0b44,
	0x0b47,
	0x0b48,
	0x0b4b,
	0x0b4d,
	0x0b55,
	0x0b57,
	0x0b62,
	0x0b63,
	0x0b82,
	0x0b82,
	0x0bbe,
	0x0bc2,
	0x0bc6,
	0x0bc8,
	0x0bca,
	0x0bcd,
	0x0bd7,
	0x0bd7,
	0x0c00,
	0x0c04,
	0x0c3e,
	0x0c44,
	0x0c46,
	0x0c48,
	0x0c4a,
	0x0c4d,
	0x0c55,
	0x0c56,
	0x0c62,
	0x0c63,
	0x0c81,
	0x0c83,
	0x0cbc,
	0x0cbc,
	0x0cbe,
	0x0cc4,
	0x0cc6,
	0x0cc8,
	0x0cca,
	0x0ccd,
	0x0cd5,
	0x0cd6,
	0x0ce2,
	0x0ce3,
	0x0d00,
	0x0d03,
	0x0d3b,
	0x0d3c,
	0x0d3e,
	0x0d44,
	0x0d46,
	0x0d48,
	0x0d4a,
	0x0d4d,
	0x0d57,
	0x0d57,
	0x0d62,
	0x0d63,
	0x0d81,
	0x0d83,
	0x0dca,
	0x0dca,
	0x0dcf,
	0x0dd4,
	0x0dd6,
	0x0dd6,
	0x0dd8,
	0x0ddf,
	0x0df2,
	0x0df3,
	0x0e31,
	0x0e31,
	0x0e34,
	0x0e3a,
	0x0e47,
	0x0e4e,
	0x0eb1,
	0x0eb1,
	0x0eb4,
	0x0ebc,
	0x0ec8,
	0x0ecd,
	0x0f18,
	0x0f19,
	0x0f35,
	0x0f35,
	0x0f37,
	0x0f37,
	0x0f39,
	0x0f39,
	0x0f3e,
	0x0f3f,
	0x0f71,
	0x0f84,
	0x0f86,
	0x0f87,
	0x0f8d,
	0x0f97,
	0x0f99,
	0x0fbc,
	0x0fc6,
	0x0fc6,
	0x102b,
	0x103e,
	0x1056,
	0x1059,
	0x105e,
	0x1060,
	0x1062,
	0x1064,
	0x1067,
	0x106d,
	0x1071,
	0x1074,
	0x1082,
	0x108d,
	0x108f,
	0x108f,
	0x109a,
	0x109d,
	0x135d,
	0x135f,
	0x1712,
	0x1714,
	0x1732,
	0x1734,
	0x1752,
	0x1753,
	0x1772,
	0x1773,
	0x17b4,
	0x17d3,
	0x17dd,
	0x17dd,
	0x180b,
	0x180d,
	0x1885,
	0x1886,
	0x18a9,
	0x18a9,
	0x1920,
	0x192b,
	0x1930,
	0x193b,
	0x1a17,
	0x1a1b,
	0x1a55,
	0x1a5e,
	0x1a60,
	0x1a7c,
	0x1a7f,
	0x1a7f,
	0x1ab0,
	0x1ac0,
	0x1b00,
	0x1b04,
	0x1b34,
	0x1b44,
	0x1b6b,
	0x1b73,
	0x1b80,
	0x1b82,
	0x1ba1,
	0x1bad,
	0x1be6,
	0x1bf3,
	0x1c24,
	0x1c37,
	0x1cd0,
	0x1cd2,
	0x1cd4,
	0x1ce8,
	0x1ced,
	0x1ced,
	0x1cf4,
	0x1cf4,
	0x1cf7,
	0x1cf9,
	0x1dc0,
	0x1df9,
	0x1dfb,
	0x1dff,
	0x20d0,
	0x20f0,
	0x2cef,
	0x2cf1,
	0x2d7f,
	0x2d7f,
	0x2de0,
	0x2dff,
	0x302a,
	0x302f,
	0x3099,
	0x309a,
	0xa66f,
	0xa672,
	0xa674,
	0xa67d,
	0xa69e,
	0xa69f,
	0xa6f0,
	0xa6f1,
	0xa802,
	0xa802,
	0xa806,
	0xa806,
	0xa80b,
	0xa80b,
	0xa823,
	0xa827,
	0xa82c,
	0xa82c,
	0xa880,
	0xa881,
	0xa8b4,
	0xa8c5,
	0xa8e0,
	0xa8f1,
	0xa8ff,
	0xa8ff,
	0xa926,
	0xa92d,
	0xa947,
	0xa953,
	0xa980,
	0xa983,
	0xa9b3,
	0xa9c0,
	0xa9e5,
	0xa9e5,
	0xaa29,
	0xaa36,
	0xaa43,
	0xaa43,
	0xaa4c,
	0xaa4d,
	0xaa7b,
	0xaa7d,
	0xaab0,
	0xaab0,
	0xaab2,
	0xaab4,
	0xaab7,
	0xaab8,
	0xaabe,
	0xaabf,
	0xaac1,
	0xaac1,
	0xaaeb,
	0xaaef,
	0xaaf5,
	0xaaf6,
	0xabe3,
	0xabea,
	0xabec,
	0xabed,
	0xfb1e,
	0xfb1e,
	0xfe00,
	0xfe0f,
	0xfe20,
	0xfe2f,
	0x101fd,
	0x101fd,
	0x102e0,
	0x102e0,
	0x10376,
	0x1037a,
	0x10a01,
	0x10a03,
	0x10a05,
	0x10a06,
	0x10a0c,
	0x10a0f,
	0x10a38,
	0x10a3a,
	0x10a3f,
	0x10a3f,
	0x10ae5,
	0x10ae6,
	0x10d24,
	0x10d27,
	0x10eab,
	0x10eac,
	0x10f46,
	0x10f50,
	0x11000,
	0x11002,
	0x11038,
	0x11046,
	0x1107f,
	0x11082,
	0x110b0,
	0x110ba,
	0x11100,
	0x11102,
	0x11127,
	0x11134,
	0x11145,
	0x11146,
	0x11173,
	0x11173,
	0x11180,
	0x11182,
	0x111b3,
	0x111c0,
	0x111c9,
	0x111cc,
	0x111ce,
	0x111cf,
	0x1122c,
	0x11237,
	0x1123e,
	0x1123e,
	0x112df,
	0x112ea,
	0x11300,
	0x11303,
	0x1133b,
	0x1133c,
	0x1133e,
	0x11344,
	0x11347,
	0x11348,
	0x1134b,
	0x1134d,
	0x11357,
	0x11357,
	0x11362,
	0x11363,
	0x11366,
	0x1136c,
	0x11370,
	0x11374,
	0x11435,
	0x11446,
	0x1145e,
	0x1145e,
	0x114b0,
	0x114c3,
	0x115af,
	0x115b5,
	0x115b8,
	0x115c0,
	0x115dc,
	0x115dd,
	0x11630,
	0x11640,
	0x116ab,
	0x116b7,
	0x1171d,
	0x1172b,
	0x1182c,
	0x1183a,
	0x11930,
	0x11935,
	0x11937,
	0x11938,
	0x1193b,
	0x1193e,
	0x11940,
	0x11940,
	0x11942,
	0x11943,
	0x119d1,
	0x119d7,
	0x119da,
	0x119e0,
	0x119e4,
	0x119e4,
	0x11a01,
	0x11a0a,
	0x11a33,
	0x11a39,
	0x11a3b,
	0x11a3e,
	0x11a47,
	0x11a47,
	0x11a51,
	0x11a5b,
	0x11a8a,
	0x11a99,
	0x11c2f,
	0x11c36,
	0x11c38,
	0x11c3f,
	0x11c92,
	0x11ca7,
	0x11ca9,
	0x11cb6,
	0x11d31,
	0x11d36,
	0x11d3a,
	0x11d3a,
	0x11d3c,
	0x11d3d,
	0x11d3f,
	0x11d45,
	0x11d47,
	0x11d47,
	0x11d8a,
	0x11d8e,
	0x11d90,
	0x11d91,
	0x11d93,
	0x11d97,
	0x11ef3,
	0x11ef6,
	0x16af0,
	0x16af4,
	0x16b30,
	0x16b36,
	0x16f4f,
	0x16f4f,
	0x16f51,
	0x16f87,
	0x16f8f,
	0x16f92,
	0x16fe4,
	0x16fe4,
	0x16ff0,
	0x16ff1,
	0x1bc9d,
	0x1bc9e,
	0x1d165,
	0x1d169,
	0x1d16d,
	0x1d172,
	0x1d17b,
	0x1d182,
	0x1d185,
	0x1d18b,
	0x1d1aa,
	0x1d1ad,
	0x1d242,
	0x1d244,
	0x1da00,
	0x1da36,
	0x1da3b,
	0x1da6c,
	0x1da75,
	0x1da75,
	0x1da84,
	0x1da84,
	0x1da9b,
	0x1da9f,
	0x1daa1,
	0x1daaf,
	0x1e000,
	0x1e006,
	0x1e008,
	0x1e018,
	0x1e01b,
	0x1e021,
	0x1e023,
	0x1e024,
	0x1e026,
	0x1e02a,
	0x1e130,
	0x1e136,
	0x1e2ec,
	0x1e2ef,
	0x1e8d0,
	0x1e8d6,
	0x1e944,
	0x1e94a,
	0xe0100,
	0xe01ef,
]

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
	return utf8.is_letter(value) || utf8.is_number(value) || value == `_` || is_unicode_mark(value)
}

// is_unicode_mark reports whether value belongs to a Unicode Mark category
// (Mn, Mc, or Me). The table is generated from Unicode general categories.
fn is_unicode_mark(value rune) bool {
	for index := 0; index < unicode_mark_ranges.len; index += 2 {
		if u32(value) >= unicode_mark_ranges[index] && u32(value) <= unicode_mark_ranges[index + 1] {
			return true
		}
	}
	return false
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
