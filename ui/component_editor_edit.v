module ui2

// Language editing rules for the code editor, as pure functions of a text and
// a selection: auto-indent on Enter, automatic pairs and typing over a closer,
// Tab and Shift+Tab on whole lines, line comments, and the line commands
// (duplicate, move, delete, select). Each returns a CodeEdit, the change to
// apply to the text area; see code_edit_native for applying it.

// CodeEditSettings are the editing preferences the rules follow.
pub struct CodeEditSettings {
pub:
	language CodeLanguage
	// rules replaces the language's default rules (code_language_rules).
	rules        ?CodeLanguageRules
	tab_size     int = 4
	hard_tabs    bool // Indent with tab characters rather than spaces.
	auto_close   bool = true // Close brackets and quotes as they are typed.
	smart_indent bool = true // Indent after an opening bracket, outdent before a closer.
}

// language_rules is the rules in force: the custom ones or the language's.
pub fn (s CodeEditSettings) language_rules() CodeLanguageRules {
	return s.rules or { code_language_rules(s.language) }
}

fn (s CodeEditSettings) tab_width() int {
	return if s.tab_size > 0 { s.tab_size } else { 4 }
}

// indent_unit is one level of indentation: a tab, or tab_size spaces.
pub fn (s CodeEditSettings) indent_unit() string {
	return if s.hard_tabs { '\t' } else { ' '.repeat(s.tab_width()) }
}

// CodeEdit is a change to apply to the editor: runes [start, end) of the text
// before it become `insert`, which gives `text`, with `selection` afterwards.
// An edit that only moves the selection has start == end and no insert.
pub struct CodeEdit {
pub:
	text      string
	selection TextSelection
	start     int
	end       int
	insert    string
}

// changes_text reports whether the edit changes the text, not only the
// selection.
pub fn (e CodeEdit) changes_text() bool {
	return e.start != e.end || e.insert.len > 0
}

fn code_edit_replace(runes []rune, start int, end int, insert string, selection TextSelection) CodeEdit {
	s := clamp_int(start, 0, runes.len)
	e := clamp_int(end, s, runes.len)
	joined := runes[..s].string() + insert + runes[e..].string()
	length := runes.len - (e - s) + insert.runes().len
	return CodeEdit{
		text:      joined
		selection: TextSelection{
			anchor: clamp_int(selection.anchor, 0, length)
			caret:  clamp_int(selection.caret, 0, length)
		}
		start:     s
		end:       e
		insert:    insert
	}
}

fn code_edit_select(text string, selection TextSelection) CodeEdit {
	return CodeEdit{
		text:      text
		selection: selection
	}
}

// CodeNativeEdit is a CodeEdit in the UTF-16 offsets native text areas use.
// Apply it with
//
//	ui2.text_area_set_selection(id, e.location, e.length)
//	ui2.insert_text_area_text(id, e.insert)
//	ui2.text_area_set_selection(id, e.select_location, e.select_length)
//
// which keeps the change undoable on AppKit. Skip the first two calls when the
// edit does not change the text.
pub struct CodeNativeEdit {
pub:
	location        int
	length          int
	insert          string
	select_location int
	select_length   int
}

// code_edit_native converts an edit of `before` to UTF-16 offsets.
pub fn code_edit_native(before string, edit CodeEdit) CodeNativeEdit {
	location := rune_index_to_utf16_offset(before, edit.start)
	end := rune_index_to_utf16_offset(before, edit.end)
	select_location, select_length := code_editor_selection_to_native(edit.text, edit.selection)
	return CodeNativeEdit{
		location:        location
		length:          end - location
		insert:          edit.insert
		select_location: select_location
		select_length:   select_length
	}
}

// code_editor_selection_from_native reads a text area's selection, a UTF-16
// start and length (text_area_caret and text_area_selection_length on AppKit),
// as rune offsets with the caret at its end.
pub fn code_editor_selection_from_native(text string, location int, length int) TextSelection {
	start := utf16_offset_to_rune_index(text, location)
	end := utf16_offset_to_rune_index(text, location + if length > 0 { length } else { 0 })
	return TextSelection{
		anchor: start
		caret:  end
	}
}

// code_editor_selection_to_native returns a selection's UTF-16 start and
// length, for text_area_set_selection.
pub fn code_editor_selection_to_native(text string, selection TextSelection) (int, int) {
	start, end := selection.ordered()
	location := rune_index_to_utf16_offset(text, start)
	return location, rune_index_to_utf16_offset(text, end) - location
}

// code_edit_between describes how `after` differs from `before` as one
// replacement (the common start and end kept), for a change the text area made
// itself, such as typing or a paste. The selection is left empty.
pub fn code_edit_between(before string, after string) CodeEdit {
	old := before.runes()
	new := after.runes()
	mut prefix := 0
	for prefix < old.len && prefix < new.len && old[prefix] == new[prefix] {
		prefix++
	}
	mut suffix := 0
	for suffix < old.len - prefix && suffix < new.len - prefix
		&& old[old.len - 1 - suffix] == new[new.len - 1 - suffix] {
		suffix++
	}
	return CodeEdit{
		text:   after
		start:  prefix
		end:    old.len - suffix
		insert: new[prefix..new.len - suffix].string()
	}
}

// code_map_range carries a range through an edit, as GPUI Kit's decorations
// follow edits: text inserted at either edge does not grow it and text inserted
// inside does; an edge inside a replaced stretch is clipped to the
// replacement's edge; a range the edit removes entirely is gone (none).
pub fn code_map_range(r CodeRange, edit CodeEdit) ?CodeRange {
	s := edit.start
	e := edit.end
	n := edit.insert.runes().len
	delta := n - (e - s)
	if r.end <= r.start {
		return none
	}
	if e <= r.start {
		return CodeRange{r.start + delta, r.end + delta}
	}
	if s >= r.end {
		return r
	}
	if s <= r.start && e >= r.end && e > s {
		return none
	}
	start := if r.start > s && r.start < e {
		s + n
	} else if r.start >= e {
		r.start + delta
	} else {
		r.start
	}
	end := if r.end > s && r.end < e {
		s
	} else if r.end >= e {
		r.end + delta
	} else {
		r.end
	}
	if end <= start {
		return none
	}
	return CodeRange{start, end}
}

// code_diagnostics_after_edit carries diagnostics through an edit (see
// code_map_range), dropping the ones it removed.
pub fn code_diagnostics_after_edit(diagnostics []CodeDiagnostic, edit CodeEdit) []CodeDiagnostic {
	mut out := []CodeDiagnostic{cap: diagnostics.len}
	for d in diagnostics {
		r := code_map_range(CodeRange{d.start, d.end}, edit) or { continue }
		out << CodeDiagnostic{
			...d
			start: r.start
			end:   r.end
		}
	}
	return out
}

// code_decorations_after_edit carries decorations through an edit (see
// code_map_range), dropping the ones it removed.
pub fn code_decorations_after_edit(decorations []CodeDecoration, edit CodeEdit) []CodeDecoration {
	mut out := []CodeDecoration{cap: decorations.len}
	for d in decorations {
		r := code_map_range(CodeRange{d.start, d.end}, edit) or { continue }
		out << CodeDecoration{
			...d
			start: r.start
			end:   r.end
		}
	}
	return out
}

// ── Lines and positions ───────────────────────────────────────────────────

// CodePosition is a zero-based line and a column in runes.
pub struct CodePosition {
pub:
	line   int
	column int
}

fn code_line_start(runes []rune, pos int) int {
	mut i := clamp_int(pos, 0, runes.len)
	for i > 0 && runes[i - 1] != `\n` {
		i--
	}
	return i
}

fn code_line_end(runes []rune, pos int) int {
	mut i := clamp_int(pos, 0, runes.len)
	for i < runes.len && runes[i] != `\n` {
		i++
	}
	return i
}

// code_line_starts returns the rune offset each line starts at.
fn code_line_starts(runes []rune) []int {
	mut starts := [0]
	for index, r in runes {
		if r == `\n` {
			starts << index + 1
		}
	}
	return starts
}

// code_line_count is how many lines a text has; an empty text has one.
pub fn code_line_count(text string) int {
	return text.count('\n') + 1
}

// code_position returns the line and column of a rune offset.
pub fn code_position(text string, offset int) CodePosition {
	runes := text.runes()
	pos := clamp_int(offset, 0, runes.len)
	mut line := 0
	mut start := 0
	for index in 0 .. pos {
		if runes[index] == `\n` {
			line++
			start = index + 1
		}
	}
	return CodePosition{
		line:   line
		column: pos - start
	}
}

// code_offset returns the rune offset of a line and column, clamped to the
// text and to the line's length.
pub fn code_offset(text string, line int, column int) int {
	runes := text.runes()
	starts := code_line_starts(runes)
	l := clamp_int(line, 0, starts.len - 1)
	start := starts[l]
	return clamp_int(start + column, start, code_line_end(runes, start))
}

fn code_leading_whitespace(runes []rune, line_start int) int {
	mut i := line_start
	for i < runes.len && (runes[i] == ` ` || runes[i] == `\t`) {
		i++
	}
	return i - line_start
}

// code_visual_column is the column of pos counting tabs to the next tab stop.
fn code_visual_column(runes []rune, line_start int, pos int, tab int) int {
	mut col := 0
	for i in line_start .. pos {
		col = if runes[i] == `\t` { (col / tab + 1) * tab } else { col + 1 }
	}
	return col
}

// code_block returns the start of the first and the end of the last line a
// selection touches. A selection that ends at the very start of a line does
// not take that line in.
fn code_block(runes []rune, selection TextSelection) (int, int) {
	start, mut end := selection.ordered()
	if end > start && end > 0 && runes[end - 1] == `\n` {
		end--
	}
	return code_line_start(runes, start), code_line_end(runes, end)
}

fn code_block_line_starts(runes []rune, first int, last int) []int {
	mut starts := [first]
	for i in first .. last {
		if runes[i] == `\n` {
			starts << i + 1
		}
	}
	return starts
}

// code_shift maps a position through insertions (positive) and removals
// (negative counts) made at line starts; a position at a line start stays put
// for an insertion when `stick` and moves for a removal into the removed run.
fn code_shift(pos int, line_starts []int, counts []int, stick bool) int {
	mut delta := 0
	for index, at in line_starts {
		n := counts[index]
		if n == 0 {
			continue
		}
		if n > 0 {
			if pos > at || (pos == at && !stick) {
				delta += n
			}
		} else {
			removed := -n
			if pos >= at + removed {
				delta -= removed
			} else if pos > at {
				delta -= pos - at
			}
		}
	}
	return pos + delta
}

// ── Enter ─────────────────────────────────────────────────────────────────

fn code_rune_str_ends_with(runes []rune, end int, suffix string) bool {
	s := suffix.runes()
	if s.len == 0 || s.len > end {
		return false
	}
	for k, r in s {
		if runes[end - s.len + k] != r {
			return false
		}
	}
	return true
}

fn code_rune_str_starts_with(runes []rune, start int, prefix string) bool {
	p := prefix.runes()
	if p.len == 0 || start + p.len > runes.len {
		return false
	}
	for k, r in p {
		if runes[start + k] != r {
			return false
		}
	}
	return true
}

fn code_outdent_string(indent string, settings CodeEditSettings) string {
	if indent.len == 0 {
		return indent
	}
	if indent.ends_with('\t') {
		return indent[..indent.len - 1]
	}
	mut spaces := 0
	for spaces < indent.len && indent[indent.len - 1 - spaces] == ` ` {
		spaces++
	}
	remove := if spaces >= settings.tab_width() { settings.tab_width() } else { spaces }
	return indent[..indent.len - remove]
}

// code_edit_newline is Enter: a new line indented like the current one, one
// level deeper after an opening bracket (or a language's block opener such as
// Python's colon), and split into two lines when the caret sits between a
// bracket pair, the closer back at the outer indentation. With smart_indent
// off the indentation is only kept.
pub fn code_edit_newline(text string, selection TextSelection, settings CodeEditSettings) CodeEdit {
	runes := text.runes()
	start, end := selection.ordered()
	s := clamp_int(start, 0, runes.len)
	e := clamp_int(end, s, runes.len)
	line_start := code_line_start(runes, s)
	ws := math_min_int(code_leading_whitespace(runes, line_start), s - line_start)
	indent := runes[line_start..line_start + ws].string()
	rules := settings.language_rules()
	unit := settings.indent_unit()
	if !settings.smart_indent {
		insert := '\n' + indent
		caret := s + insert.runes().len
		return code_edit_replace(runes, s, e, insert, TextSelection{caret, caret})
	}
	// Text before the caret, without trailing blanks; text after, without
	// leading blanks.
	mut before_end := s
	for before_end > line_start && (runes[before_end - 1] == ` ` || runes[before_end - 1] == `\t`) {
		before_end--
	}
	line_end := code_line_end(runes, e)
	mut after_start := e
	for after_start < line_end && (runes[after_start] == ` ` || runes[after_start] == `\t`) {
		after_start++
	}
	mut opener := ''
	for pair in rules.brackets {
		if code_rune_str_ends_with(runes, before_end, pair.open) && before_end - pair.open.runes().len >= line_start {
			opener = pair.open
			break
		}
	}
	mut opens := opener.len > 0
	if !opens {
		for suffix in rules.indent_after {
			if code_rune_str_ends_with(runes, before_end, suffix) && before_end > line_start {
				opens = true
				break
			}
		}
	}
	mut closer := ''
	for pair in rules.brackets {
		if code_rune_str_starts_with(runes, after_start, pair.close) && after_start < line_end {
			closer = pair.close
			break
		}
	}
	if opens && closer.len > 0 {
		// Between a pair: open a line inside it and put the closer on its own.
		mut matched := opener.len == 0
		for pair in rules.brackets {
			if pair.open == opener && pair.close == closer {
				matched = true
			}
		}
		if matched {
			inner := '\n' + indent + unit
			insert := inner + '\n' + indent
			caret := s - (s - before_end) + inner.runes().len
			return code_edit_replace(runes, before_end, after_start, insert, TextSelection{caret, caret})
		}
	}
	if opens {
		insert := '\n' + indent + unit
		caret := before_end + insert.runes().len
		return code_edit_replace(runes, before_end, after_start, insert, TextSelection{caret, caret})
	}
	if closer.len > 0 && after_start > e {
		// Only blanks between the caret and a closer: the closer outdents.
		insert := '\n' + code_outdent_string(indent, settings)
		caret := s + insert.runes().len
		return code_edit_replace(runes, s, after_start, insert, TextSelection{caret, caret})
	}
	if closer.len > 0 {
		insert := '\n' + code_outdent_string(indent, settings)
		caret := s + insert.runes().len
		return code_edit_replace(runes, s, e, insert, TextSelection{caret, caret})
	}
	insert := '\n' + indent
	caret := s + insert.runes().len
	return code_edit_replace(runes, s, e, insert, TextSelection{caret, caret})
}

// ── Typing: automatic pairs ───────────────────────────────────────────────

// code_context_at reports whether a position is inside a string or comment,
// where automatic pairs are not inserted (GPUI Kit's `not_in`).
fn code_context_at(text string, language CodeLanguage, pos int) CodeTokenKind {
	runes := text.runes()
	for token in code_tokens(text, language) {
		if token.start < pos && pos < token.end {
			return token.kind
		}
		if token.end == pos && pos > token.start && !code_token_closed(runes, token) {
			// A line comment, or a string left open, goes on at its end.
			return token.kind
		}
		if token.start >= pos {
			break
		}
	}
	return .plain
}

// code_token_closed reports whether a comment or string token ends with its
// closing delimiter, so a position right after it is outside.
fn code_token_closed(runes []rune, token CodeToken) bool {
	last := runes[token.end - 1]
	return match token.kind {
		.comment, .comment_doc {
			token.end - token.start >= 2 && ((last == `/` && runes[token.end - 2] == `*`)
				|| (last == `>` && runes[token.end - 2] == `-`))
		}
		.string, .string_escape {
			token.end - token.start >= 2 && last in [`'`, `"`, `\``]
		}
		else {
			true
		}
	}
}

fn code_in_string_or_comment(kind CodeTokenKind) bool {
	return kind in [.string, .string_escape, .comment, .comment_doc, .code_span]
}

fn code_may_close_before(runes []rune, pos int, rules CodeLanguageRules) bool {
	if pos >= runes.len {
		return true
	}
	r := runes[pos]
	return r == ` ` || r == `\t` || r == `\n` || r == `\r` || rules.auto_close_before.contains(r.str())
}

// code_edit_after_input looks at what the person just typed and finishes it,
// the way an editor does as keys go in. Text areas insert typed characters
// themselves, so call it from the text area's change event with the text from
// before the change, the new text and the new selection:
//
//   - an opening bracket or quote gets its closer after the caret (with
//     auto_close, where the next character allows it and not inside a string
//     or comment; a quote not right after a word character);
//   - a closer typed in front of the same closer types over it when the line's
//     pairs balance;
//   - an opener typed over a selection on one line wraps it instead.
//
// What was typed is read off the two texts and the caret after it, so a
// selection the application has not caught up with does not matter. It returns
// none when the change was anything else (a paste, a deletion, several
// characters), so applying its result can never call it again.
pub fn code_edit_after_input(before string, after string, selection TextSelection, settings CodeEditSettings) ?CodeEdit {
	old := before.runes()
	new := after.runes()
	rules := settings.language_rules()
	// The change must be one character typed just before the caret, over
	// whatever stretch of the old text it replaced.
	if !selection.collapsed() || selection.caret < 1 || selection.caret > new.len {
		return none
	}
	s := selection.caret - 1
	tail := new.len - selection.caret
	e := old.len - tail
	if e < s {
		return none
	}
	for k in 0 .. s {
		if old[k] != new[k] {
			return none
		}
	}
	for k in 0 .. tail {
		if old[e + k] != new[selection.caret + k] {
			return none
		}
	}
	typed := new[s]
	typed_str := typed.str()
	if e > s {
		// Wrap a one-line selection in the pair.
		if !settings.auto_close {
			return none
		}
		selected := old[s..e]
		if `\n` in selected {
			return none
		}
		for pair in rules.auto_pairs {
			if pair.open == typed_str && pair.close.len > 0 {
				inner := selected.string()
				insert := pair.open + inner + pair.close
				first := s + 1
				return code_edit_replace(new, s, s + 1, insert, TextSelection{first, first +
					selected.len})
			}
		}
		return none
	}
	// Type over a closer.
	if s + 1 < new.len && new[s + 1] == typed {
		for pair in rules.auto_pairs {
			if pair.close != typed_str {
				continue
			}
			if pair.open == pair.close {
				// A quote: type over it when it closes a string.
				if s > 0 && old[s - 1] == `\\` {
					continue
				}
				return code_edit_replace(new, s + 1, s + 2, '', TextSelection{s + 1, s + 1})
			}
			line_start := code_line_start(old, s)
			line_end := code_line_end(old, s)
			mut opens := 0
			mut closes := 0
			for k in line_start .. line_end {
				if old[k].str() == pair.open {
					opens++
				} else if old[k].str() == pair.close {
					closes++
				}
			}
			if opens <= closes {
				return code_edit_replace(new, s + 1, s + 2, '', TextSelection{s + 1, s + 1})
			}
		}
	}
	if !settings.auto_close {
		return none
	}
	for pair in rules.auto_pairs {
		if pair.open != typed_str || pair.close.len == 0 {
			continue
		}
		if !code_may_close_before(new, s + 1, rules) {
			return none
		}
		if code_in_string_or_comment(code_context_at(before, settings.language, s)) {
			return none
		}
		if pair.open == pair.close && s > 0 && (is_word_rune(old[s - 1]) || old[s - 1] == `\\`) {
			return none
		}
		return code_edit_replace(new, s + 1, s + 1, pair.close, TextSelection{s + 1, s + 1})
	}
	return none
}

// ── Backspace, Tab, Shift+Tab ─────────────────────────────────────────────

// code_edit_backspace is Backspace where an editor does more than delete a
// character: between an empty pair (after typing an opener) both go, and in
// indentation made of spaces it deletes back to the previous tab stop. It
// returns none when the text area's own Backspace is right.
pub fn code_edit_backspace(text string, selection TextSelection, settings CodeEditSettings) ?CodeEdit {
	if !selection.collapsed() {
		return none
	}
	runes := text.runes()
	pos := clamp_int(selection.caret, 0, runes.len)
	if pos == 0 {
		return none
	}
	rules := settings.language_rules()
	if pos < runes.len {
		for pair in rules.auto_pairs {
			if runes[pos - 1].str() == pair.open && runes[pos].str() == pair.close {
				return code_edit_replace(runes, pos - 1, pos + 1, '', TextSelection{pos - 1, pos - 1})
			}
		}
	}
	if settings.hard_tabs {
		return none
	}
	line_start := code_line_start(runes, pos)
	if pos - line_start < 2 {
		return none
	}
	for k in line_start .. pos {
		if runes[k] != ` ` {
			return none
		}
	}
	tab := settings.tab_width()
	column := pos - line_start
	target := ((column - 1) / tab) * tab
	from := line_start + target
	return code_edit_replace(runes, from, pos, '', TextSelection{from, from})
}

// code_edit_indent is Tab: with a selection over several lines it indents each
// non-blank line one level and keeps them selected; otherwise it replaces the
// selection with indentation to the next tab stop.
pub fn code_edit_indent(text string, selection TextSelection, settings CodeEditSettings) CodeEdit {
	runes := text.runes()
	start, end := selection.ordered()
	first, last := code_block(runes, selection)
	// A selection with a line break in it indents whole lines.
	multi := start != end && `\n` in runes[clamp_int(start, 0, runes.len)..clamp_int(end, 0, runes.len)]
	if !multi {
		s := clamp_int(start, 0, runes.len)
		e := clamp_int(end, s, runes.len)
		insert := if settings.hard_tabs {
			'\t'
		} else {
			tab := settings.tab_width()
			col := code_visual_column(runes, code_line_start(runes, s), s, tab)
			' '.repeat(tab - col % tab)
		}
		caret := s + insert.runes().len
		return code_edit_replace(runes, s, e, insert, TextSelection{caret, caret})
	}
	unit := settings.indent_unit()
	unit_len := unit.runes().len
	starts := code_block_line_starts(runes, first, last)
	mut counts := []int{len: starts.len}
	mut out := []rune{cap: runes.len + starts.len * unit_len}
	mut line_index := 0
	for k in first .. last + 1 {
		if line_index < starts.len && k == starts[line_index] {
			line_end := code_line_end(runes, k)
			if line_end > k {
				out << unit.runes()
				counts[line_index] = unit_len
			}
			line_index++
		}
		if k < last {
			out << runes[k]
		}
	}
	insert := out.string()
	selection_after := TextSelection{
		anchor: code_shift(selection.anchor, starts, counts, selection.anchor == start)
		caret:  code_shift(selection.caret, starts, counts, selection.caret == start)
	}
	return code_edit_replace(runes, first, last, insert, selection_after)
}

// code_edit_outdent is Shift+Tab: each line the selection touches (or the
// caret's line) loses one level of indentation, a tab or up to tab_size spaces.
// It returns none when no line is indented.
pub fn code_edit_outdent(text string, selection TextSelection, settings CodeEditSettings) ?CodeEdit {
	runes := text.runes()
	first, last := code_block(runes, selection)
	starts := code_block_line_starts(runes, first, last)
	tab := settings.tab_width()
	mut counts := []int{len: starts.len}
	mut any := false
	for index, at in starts {
		if at < runes.len && runes[at] == `\t` {
			counts[index] = -1
			any = true
			continue
		}
		mut spaces := 0
		for at + spaces < runes.len && runes[at + spaces] == ` ` && spaces < tab {
			spaces++
		}
		if spaces > 0 {
			counts[index] = -spaces
			any = true
		}
	}
	if !any {
		return none
	}
	mut out := []rune{cap: runes.len}
	mut line_index := 0
	mut skip := 0
	for k in first .. last {
		if line_index < starts.len && k == starts[line_index] {
			skip = -counts[line_index]
			line_index++
		}
		if skip > 0 {
			skip--
			continue
		}
		out << runes[k]
	}
	selection_after := TextSelection{
		anchor: code_shift(selection.anchor, starts, counts, false)
		caret:  code_shift(selection.caret, starts, counts, false)
	}
	return code_edit_replace(runes, first, last, out.string(), selection_after)
}

// ── Comments ──────────────────────────────────────────────────────────────

// code_edit_toggle_comment comments out the lines the selection touches with
// the language's line comment, or uncomments them when every non-blank one is
// commented. Languages with only a block comment (Markdown's `<!-- -->`) wrap
// the lines instead. It returns none for a language without comments (JSON,
// plain text).
pub fn code_edit_toggle_comment(text string, selection TextSelection, settings CodeEditSettings) ?CodeEdit {
	runes := text.runes()
	rules := settings.language_rules()
	first, last := code_block(runes, selection)
	starts := code_block_line_starts(runes, first, last)
	if rules.line_comment.len == 0 {
		if rules.block_comment.open.len == 0 {
			return none
		}
		return code_toggle_block_comment(runes, selection, first, last, rules.block_comment)
	}
	token := rules.line_comment.runes()
	mut min_indent := -1
	mut all_commented := true
	mut any_text := false
	for at in starts {
		ws := code_leading_whitespace(runes, at)
		line_end := code_line_end(runes, at)
		if at + ws >= line_end {
			continue
		}
		any_text = true
		if min_indent < 0 || ws < min_indent {
			min_indent = ws
		}
		if !code_rune_str_starts_with(runes, at + ws, rules.line_comment) {
			all_commented = false
		}
	}
	if !any_text {
		return none
	}
	mut counts := []int{len: starts.len}
	mut at_offsets := []int{len: starts.len}
	for index, at in starts {
		ws := code_leading_whitespace(runes, at)
		line_end := code_line_end(runes, at)
		if at + ws >= line_end {
			continue
		}
		if all_commented {
			mut remove := token.len
			if at + ws + remove < line_end && runes[at + ws + remove] == ` ` {
				remove++
			}
			counts[index] = -remove
			at_offsets[index] = at + ws
		} else {
			counts[index] = token.len + 1
			at_offsets[index] = at + min_indent
		}
	}
	mut out := []rune{cap: runes.len + starts.len * (token.len + 1)}
	mut k := first
	for index, at in at_offsets {
		if counts[index] == 0 {
			continue
		}
		for k < at {
			out << runes[k]
			k++
		}
		if counts[index] > 0 {
			out << token
			out << ` `
		} else {
			k += -counts[index]
		}
	}
	for k < last {
		out << runes[k]
		k++
	}
	start, _ := selection.ordered()
	selection_after := TextSelection{
		anchor: code_shift(selection.anchor, at_offsets, counts, selection.anchor == start
			&& counts.len > 0 && selection.anchor <= first)
		caret:  code_shift(selection.caret, at_offsets, counts, selection.caret == start
			&& counts.len > 0 && selection.caret <= first)
	}
	return code_edit_replace(runes, first, last, out.string(), selection_after)
}

fn code_toggle_block_comment(runes []rune, selection TextSelection, first int, last int, pair CodePair) ?CodeEdit {
	mut a := first
	for a < last && (runes[a] == ` ` || runes[a] == `\t` || runes[a] == `\n`) {
		a++
	}
	mut b := last
	for b > a && (runes[b - 1] == ` ` || runes[b - 1] == `\t` || runes[b - 1] == `\n`) {
		b--
	}
	if a >= b {
		return none
	}
	open := pair.open.runes()
	close := pair.close.runes()
	if code_rune_str_starts_with(runes, a, pair.open) && code_rune_str_ends_with(runes, b, pair.close)
		&& b - a >= open.len + close.len {
		mut inner_start := a + open.len
		if inner_start < b && runes[inner_start] == ` ` {
			inner_start++
		}
		mut inner_end := b - close.len
		if inner_end > inner_start && runes[inner_end - 1] == ` ` {
			inner_end--
		}
		inner := runes[inner_start..inner_end].string()
		removed_front := inner_start - a
		start, end := selection.ordered()
		new_start := if start > a { math_max_int(a, start - removed_front) } else { start }
		new_end := math_max_int(new_start, math_min_int(end - removed_front, a + inner_end - inner_start))
		return code_edit_replace(runes, a, b, inner, TextSelection{new_start, new_end})
	}
	insert := pair.open + ' ' + runes[a..b].string() + ' ' + pair.close
	start, end := selection.ordered()
	front := open.len + 1
	new_start := if start >= a { start + front } else { start }
	new_end := if end >= a { math_min_int(end + front, a + front + (b - a)) } else { end }
	return code_edit_replace(runes, a, b, insert, TextSelection{new_start, new_end})
}

// ── Line commands ─────────────────────────────────────────────────────────

// code_edit_duplicate_lines copies the lines the selection touches below
// themselves and moves the selection onto the copy.
pub fn code_edit_duplicate_lines(text string, selection TextSelection) CodeEdit {
	runes := text.runes()
	first, last := code_block(runes, selection)
	block := runes[first..last].string()
	length := last - first + 1
	return code_edit_replace(runes, last, last, '\n' + block, TextSelection{selection.anchor +
		length, selection.caret + length})
}

// code_edit_move_lines moves the lines the selection touches one line up or
// down, past their neighbour, keeping them selected. It returns none at the
// first or last line.
pub fn code_edit_move_lines(text string, selection TextSelection, up bool) ?CodeEdit {
	runes := text.runes()
	first, last := code_block(runes, selection)
	block := runes[first..last].string()
	if up {
		if first == 0 {
			return none
		}
		prev_start := code_line_start(runes, first - 1)
		prev := runes[prev_start..first - 1].string()
		shift := first - prev_start
		return code_edit_replace(runes, prev_start, last, block + '\n' + prev, TextSelection{selection.anchor - shift, selection.caret - shift})
	}
	if last >= runes.len {
		return none
	}
	next_end := code_line_end(runes, last + 1)
	next := runes[last + 1..next_end].string()
	shift := next_end - last
	return code_edit_replace(runes, first, next_end, next + '\n' + block, TextSelection{selection.anchor + shift, selection.caret + shift})
}

// code_edit_delete_lines removes the lines the selection touches, newline
// included, and leaves the caret at the same column of the line that takes
// their place.
pub fn code_edit_delete_lines(text string, selection TextSelection) CodeEdit {
	runes := text.runes()
	first, last := code_block(runes, selection)
	column := clamp_int(selection.caret, first, last) - code_line_start(runes, clamp_int(selection.caret,
		first, last))
	mut from := first
	mut to := last
	if to < runes.len {
		to++
	} else if from > 0 {
		from--
	}
	rest := runes[..from].string() + runes[to..].string()
	rest_runes := rest.runes()
	line_start := if from < first { code_line_start(rest_runes, from) } else { from }
	caret := math_min_int(line_start + column, code_line_end(rest_runes, line_start))
	return code_edit_replace(runes, from, to, '', TextSelection{caret, caret})
}

// code_select_line selects the lines the selection touches, newline included.
// Asked again with whole lines selected, it takes in the next line too.
pub fn code_select_line(text string, selection TextSelection) TextSelection {
	runes := text.runes()
	start, end := selection.ordered()
	first := code_line_start(runes, start)
	whole := start == first && end > start && (end == runes.len || runes[end - 1] == `\n`)
	mut last := if whole { code_line_end(runes, end) } else { code_line_end(runes, end) }
	if whole && end == runes.len {
		last = runes.len
	}
	stop := if last < runes.len { last + 1 } else { last }
	return TextSelection{
		anchor: first
		caret:  stop
	}
}

fn code_word_rune(r rune, rules CodeLanguageRules) bool {
	return is_word_rune(r) || (rules.word_extra.len > 0 && rules.word_extra.contains(r.str()))
}

// code_word_at returns the word around a position (letters, digits, `_` and
// the language's extra word characters), empty when there is none.
pub fn code_word_at(text string, pos int, settings CodeEditSettings) CodeRange {
	runes := text.runes()
	rules := settings.language_rules()
	p := clamp_int(pos, 0, runes.len)
	mut a := p
	for a > 0 && code_word_rune(runes[a - 1], rules) {
		a--
	}
	mut b := p
	for b < runes.len && code_word_rune(runes[b], rules) {
		b++
	}
	return CodeRange{a, b}
}

// code_select_word selects the word at the caret. With text already selected
// it moves the selection to the next place that text occurs, wrapping round,
// which is what Cmd+D does here without multiple cursors.
pub fn code_select_word(text string, selection TextSelection, settings CodeEditSettings) TextSelection {
	if selection.collapsed() {
		word := code_word_at(text, selection.caret, settings)
		if word.is_empty() {
			return selection
		}
		return TextSelection{word.start, word.end}
	}
	runes := text.runes()
	start, end := selection.ordered()
	needle := runes[start..end].string()
	matches := code_search(text, needle, CodeSearchOptions{ match_case: true }) or { return selection }
	if matches.len == 0 {
		return selection
	}
	index := code_search_next_index(matches, end, true)
	m := matches[index]
	return TextSelection{m.start, m.end}
}

// ── Commands and keys ─────────────────────────────────────────────────────

// CodeCommand is an editor command a key can ask for.
pub enum CodeCommand {
	newline          // Enter
	indent           // Tab, Cmd+]
	outdent          // Shift+Tab, Cmd+[
	backspace        // Backspace
	toggle_comment   // Cmd+/
	duplicate_lines  // Cmd+Shift+D, Shift+Alt+Down
	move_lines_up    // Alt+Up
	move_lines_down  // Alt+Down
	delete_lines     // Cmd+Shift+K
	select_line      // Cmd+L
	select_word      // Cmd+D
	find             // Cmd+F
	find_replace     // Cmd+Alt+F on macOS, Ctrl+H elsewhere
	find_next        // Cmd+G, F3
	find_previous    // Cmd+Shift+G, Shift+F3
	show_completions // No default key: bind one that suits the platform.
}

// code_primary_modifier reports whether an event holds the platform's command
// modifier, and no other besides Shift and the ones allowed.
fn code_primary(event KeyEvent) bool {
	$if macos || ios {
		return event.cmd && !event.ctrl
	} $else {
		return event.ctrl && !event.cmd
	}
}

// code_command_for_key maps a key to the editor command it is bound to: the
// usual code-editor shortcuts, with Command on Apple platforms where others
// use Control. Call it from on_key_event while the editor's text area has focus
// (focused_text_area_id() == code_editor_text_id(id)), run the command, and
// consume the key when the command did something. Which keys reach
// on_key_event while a text area has focus differs by backend: see
// code_command_for_text_key.
pub fn code_command_for_key(event KeyEvent) ?CodeCommand {
	primary := code_primary(event)
	plain := !event.cmd && !event.ctrl && !event.alt
	match event.code {
		.enter, .kp_enter {
			if plain {
				return .newline
			}
		}
		.tab {
			if plain {
				return if event.shift { CodeCommand.outdent } else { CodeCommand.indent }
			}
		}
		.backspace {
			if plain && !event.shift {
				return .backspace
			}
		}
		.slash {
			if primary && !event.alt && !event.shift {
				return .toggle_comment
			}
		}
		.right_bracket {
			if primary && !event.alt && !event.shift {
				return .indent
			}
		}
		.left_bracket {
			if primary && !event.alt && !event.shift {
				return .outdent
			}
		}
		.up, .down {
			if event.alt && !event.cmd && !event.ctrl {
				return if event.shift {
					CodeCommand.duplicate_lines
				} else if event.code == .up {
					CodeCommand.move_lines_up
				} else {
					CodeCommand.move_lines_down
				}
			}
		}
		.d {
			if primary && !event.alt {
				return if event.shift {
					CodeCommand.duplicate_lines
				} else {
					CodeCommand.select_word
				}
			}
		}
		.k {
			if primary && event.shift && !event.alt {
				return .delete_lines
			}
		}
		.l {
			if primary && !event.alt && !event.shift {
				return .select_line
			}
		}
		.f {
			if primary && !event.shift {
				$if macos || ios {
					return if event.alt { CodeCommand.find_replace } else { CodeCommand.find }
				} $else {
					if !event.alt {
						return .find
					}
				}
			}
		}
		.h {
			$if !macos && !ios {
				if primary && !event.alt && !event.shift {
					return .find_replace
				}
			}
		}
		.g {
			if primary && !event.alt {
				return if event.shift { CodeCommand.find_previous } else { CodeCommand.find_next }
			}
		}
		.f3 {
			if !event.cmd && !event.ctrl && !event.alt {
				return if event.shift { CodeCommand.find_previous } else { CodeCommand.find_next }
			}
		}
		else {}
	}
	return none
}

// code_command_for_text_key maps the keys a focused text area reports through
// on_key as `text:<id>:<key>` to commands. On AppKit, Enter, Tab, Shift+Tab and
// Backspace arrive only that way (the text view takes them before
// on_key_event); call consume_text_key when the command did something. The
// custom renderer offers them to on_key_event first, so a handler that
// consumed them there never sees them here.
pub fn code_command_for_text_key(key string) ?CodeCommand {
	return match key {
		'enter', 'line_break' { .newline }
		'tab' { .indent }
		'shift+tab' { .outdent }
		'backspace' { .backspace }
		else { none }
	}
}

// code_editor_text_command decodes an on_key string for a code editor's text
// area, `text:<code_editor_text_id(id)>:<key>`, into a command.
pub fn code_editor_text_command(id string, key string) ?CodeCommand {
	prefix := 'text:' + code_editor_text_id(id) + ':'
	if id.len == 0 || !key.starts_with(prefix) {
		return none
	}
	return code_command_for_text_key(key[prefix.len..])
}

// code_editor_settings is the editing part of an editor's configuration.
pub fn code_editor_settings(config CodeEditorConfig) CodeEditSettings {
	return CodeEditSettings{
		language:     config.language
		rules:        config.rules
		tab_size:     config.tab_size
		hard_tabs:    config.hard_tabs
		auto_close:   config.auto_close
		smart_indent: config.smart_indent
	}
}

// code_editor_command runs an editing command against the editor's text and
// selection and returns the edit to apply. It returns none for commands that
// are not edits (find, completions), for edits a read-only or disabled editor
// refuses, and where the text area's own handling is right (Backspace with
// nothing special to delete).
pub fn code_editor_command(config CodeEditorConfig, command CodeCommand) ?CodeEdit {
	prefs := code_editor_settings(config)
	source := config.text
	sel := config.selection
	editable := !config.read_only && !config.disabled
	match command {
		.select_line {
			return code_edit_select(source, code_select_line(source, sel))
		}
		.select_word {
			next := code_select_word(source, sel, prefs)
			if next == sel {
				return none
			}
			return code_edit_select(source, next)
		}
		else {}
	}
	if !editable {
		return none
	}
	return match command {
		.newline { code_edit_newline(source, sel, prefs) }
		.indent { code_edit_indent(source, sel, prefs) }
		.outdent { code_edit_outdent(source, sel, prefs) }
		.backspace { code_edit_backspace(source, sel, prefs) }
		.toggle_comment { code_edit_toggle_comment(source, sel, prefs) }
		.duplicate_lines { code_edit_duplicate_lines(source, sel) }
		.move_lines_up { code_edit_move_lines(source, sel, true) }
		.move_lines_down { code_edit_move_lines(source, sel, false) }
		.delete_lines { code_edit_delete_lines(source, sel) }
		else { none }
	}
}

// code_editor_after_input is code_edit_after_input for an editor whose config
// still holds the text from before the change.
pub fn code_editor_after_input(config CodeEditorConfig, text string, selection TextSelection) ?CodeEdit {
	if config.read_only || config.disabled {
		return none
	}
	return code_edit_after_input(config.text, text, selection, code_editor_settings(config))
}
