module ui2

import math

// Find and replace for the code editor: a pure search over the text (plain,
// whole word, case-sensitive, or a small regular-expression language), the
// replace edits, and the search bar the editor floats over its top-right
// corner, after GPUI Kit's built-in search panel.

// CodeSearchOptions are the search bar's three toggles.
pub struct CodeSearchOptions {
pub:
	match_case bool // Off: `a` matches `A`.
	whole_word bool // Only matches with no word character on either side.
	regex      bool // The query is a regular expression (see code_search).
}

// code_search finds every non-overlapping match of query in text, in order, as
// rune ranges. An empty query finds nothing. With `regex`, the query is a
// regular expression of this subset: literals and `\` escapes, `.`, classes
// `[a-z]` `[^...]`, `\d \w \s` and their negations, `^` and `$` at line
// boundaries, `\b \B`, groups `(...)` and `(?:...)`, `|`, and the quantifiers
// `* + ? {n} {n,} {n,m}` with lazy `?` forms. It runs in time linear in the
// text (a Pike VM, no backtracking), and an invalid expression is an error.
// Empty matches are skipped.
pub fn code_search(text string, query string, options CodeSearchOptions) ![]CodeRange {
	if query.len == 0 {
		return []CodeRange{}
	}
	runes := text.runes()
	mut found := if options.regex {
		program := code_regex_compile(query, !options.match_case)!
		code_regex_find_all(program, runes, !options.match_case)
	} else {
		code_literal_find_all(runes, query.runes(), options.match_case)
	}
	if options.whole_word {
		found = found.filter(code_whole_word(runes, it))
	}
	return found
}

fn code_whole_word(runes []rune, r CodeRange) bool {
	clear_before := r.start == 0 || !is_word_rune(runes[r.start - 1])
	clear_after := r.end >= runes.len || !is_word_rune(runes[r.end])
	return clear_before && clear_after
}

fn code_fold_rune(r rune) rune {
	return r.to_lower()
}

fn code_literal_find_all(runes []rune, needle []rune, match_case bool) []CodeRange {
	mut out := []CodeRange{}
	if needle.len == 0 || needle.len > runes.len {
		return out
	}
	mut folded_needle := needle.clone()
	if !match_case {
		for k in 0 .. folded_needle.len {
			folded_needle[k] = code_fold_rune(folded_needle[k])
		}
	}
	mut i := 0
	for i + needle.len <= runes.len {
		mut ok := true
		for k in 0 .. needle.len {
			r := if match_case { runes[i + k] } else { code_fold_rune(runes[i + k]) }
			if r != folded_needle[k] {
				ok = false
				break
			}
		}
		if ok {
			out << CodeRange{i, i + needle.len}
			i += needle.len
		} else {
			i++
		}
	}
	return out
}

// code_search_next_index returns the index of the match a search moves to
// from pos: forward, the first that starts at or after pos; backward, the last
// that starts before pos. It wraps round, and is -1 without matches.
pub fn code_search_next_index(matches []CodeRange, pos int, forward bool) int {
	if matches.len == 0 {
		return -1
	}
	if forward {
		for index, m in matches {
			if m.start >= pos {
				return index
			}
		}
		return 0
	}
	for index := matches.len - 1; index >= 0; index-- {
		if matches[index].start < pos {
			return index
		}
	}
	return matches.len - 1
}

// code_search_replace replaces one match and selects the replacement.
pub fn code_search_replace(text string, matches []CodeRange, index int, replacement string) ?CodeEdit {
	if index < 0 || index >= matches.len {
		return none
	}
	runes := text.runes()
	m := matches[index]
	if m.start < 0 || m.end > runes.len || m.end < m.start {
		return none
	}
	end := m.start + replacement.runes().len
	return code_edit_replace(runes, m.start, m.end, replacement, TextSelection{m.start, end})
}

// code_search_replace_all replaces every match as one edit, with the caret
// after the last replacement.
pub fn code_search_replace_all(text string, matches []CodeRange, replacement string) ?CodeEdit {
	if matches.len == 0 {
		return none
	}
	runes := text.runes()
	first := matches[0].start
	last := matches[matches.len - 1].end
	if first < 0 || last > runes.len {
		return none
	}
	mut out := []rune{cap: last - first}
	repl := replacement.runes()
	mut k := first
	for m in matches {
		if m.start < k || m.end < m.start {
			return none
		}
		out << runes[k..m.start]
		out << repl
		k = m.end
	}
	caret := first + out.len
	return code_edit_replace(runes, first, last, out.string(), TextSelection{caret, caret})
}

// ── Regular expressions ───────────────────────────────────────────────────

enum CodeRegexOp {
	char
	any
	class
	split
	jmp
	match
	bol
	eol
	word_boundary
	not_word_boundary
}

struct CodeRegexInst {
mut:
	op     CodeRegexOp
	r      rune
	ranges []rune // pairs of inclusive bounds
	negate bool
	x      int
	y      int
}

// CodeRegexNode is the parsed expression.
struct CodeRegexNode {
	kind     u8 // `c` char, `.` any, `[` class, `^`, `$`, `b`, `B`, `s` sequence, `|` alternation, `*` repeat
	r        rune
	ranges   []rune
	negate   bool
	children []CodeRegexNode
	min      int
	max      int // -1 for no limit
	lazy     bool
}

struct CodeRegexParser {
	src []rune
mut:
	pos  int
	fold bool
}

const code_regex_max_repeat = 256

fn code_regex_compile(pattern string, fold bool) ![]CodeRegexInst {
	mut p := CodeRegexParser{
		src:  pattern.runes()
		fold: fold
	}
	node := p.parse_alternation()!
	if p.pos < p.src.len {
		return error('unmatched `)` in the regular expression')
	}
	mut program := []CodeRegexInst{}
	code_regex_emit(node, mut program)!
	program << CodeRegexInst{
		op: .match
	}
	if program.len > 20000 {
		return error('the regular expression is too large')
	}
	return program
}

fn (mut p CodeRegexParser) parse_alternation() !CodeRegexNode {
	mut branches := [p.parse_sequence()!]
	for p.pos < p.src.len && p.src[p.pos] == `|` {
		p.pos++
		branches << p.parse_sequence()!
	}
	if branches.len == 1 {
		return branches[0]
	}
	return CodeRegexNode{
		kind:     `|`
		children: branches
	}
}

fn (mut p CodeRegexParser) parse_sequence() !CodeRegexNode {
	mut items := []CodeRegexNode{}
	for p.pos < p.src.len && p.src[p.pos] != `|` && p.src[p.pos] != `)` {
		atom := p.parse_atom()!
		items << p.parse_quantifier(atom)!
	}
	return CodeRegexNode{
		kind:     `s`
		children: items
	}
}

fn (mut p CodeRegexParser) parse_quantifier(atom CodeRegexNode) !CodeRegexNode {
	if p.pos >= p.src.len {
		return atom
	}
	mut min := 0
	mut max := -1
	c := p.src[p.pos]
	match c {
		`*` {
			min, max = 0, -1
			p.pos++
		}
		`+` {
			min, max = 1, -1
			p.pos++
		}
		`?` {
			min, max = 0, 1
			p.pos++
		}
		`{` {
			saved := p.pos
			p.pos++
			lo := p.parse_number()
			if lo < 0 {
				// Not a quantifier: a literal brace.
				p.pos = saved
				return atom
			}
			min = lo
			max = lo
			if p.pos < p.src.len && p.src[p.pos] == `,` {
				p.pos++
				hi := p.parse_number()
				max = hi
			}
			if p.pos >= p.src.len || p.src[p.pos] != `}` {
				p.pos = saved
				return atom
			}
			p.pos++
			if (max >= 0 && max < min) || min > code_regex_max_repeat || max > code_regex_max_repeat {
				return error('bad repetition count in the regular expression')
			}
		}
		else {
			return atom
		}
	}
	if atom.kind in [`^`, `$`, `b`, `B`] {
		return error('nothing to repeat in the regular expression')
	}
	mut lazy := false
	if p.pos < p.src.len && p.src[p.pos] == `?` {
		lazy = true
		p.pos++
	}
	if p.pos < p.src.len && p.src[p.pos] in [`*`, `+`, `?`] {
		return error('nested quantifier in the regular expression')
	}
	return CodeRegexNode{
		kind:     `*`
		children: [atom]
		min:      min
		max:      max
		lazy:     lazy
	}
}

fn (mut p CodeRegexParser) parse_number() int {
	mut value := -1
	for p.pos < p.src.len && code_digit(p.src[p.pos]) {
		value = (if value < 0 { 0 } else { value }) * 10 + int(p.src[p.pos] - `0`)
		if value > 100000 {
			value = 100000
		}
		p.pos++
	}
	return value
}

fn (mut p CodeRegexParser) char_node(r rune) CodeRegexNode {
	return CodeRegexNode{
		kind: `c`
		r:    if p.fold { code_fold_rune(r) } else { r }
	}
}

fn (mut p CodeRegexParser) parse_atom() !CodeRegexNode {
	c := p.src[p.pos]
	p.pos++
	match c {
		`(` {
			if p.pos + 1 < p.src.len && p.src[p.pos] == `?` && p.src[p.pos + 1] == `:` {
				p.pos += 2
			}
			inner := p.parse_alternation()!
			if p.pos >= p.src.len || p.src[p.pos] != `)` {
				return error('missing `)` in the regular expression')
			}
			p.pos++
			return inner
		}
		`.` {
			return CodeRegexNode{
				kind: `.`
			}
		}
		`^` {
			return CodeRegexNode{
				kind: `^`
			}
		}
		`$` {
			return CodeRegexNode{
				kind: `$`
			}
		}
		`[` {
			return p.parse_class()!
		}
		`\\` {
			return p.parse_escape(false)!
		}
		`*`, `+`, `?` {
			return error('nothing to repeat in the regular expression')
		}
		else {
			return p.char_node(c)
		}
	}
}

fn code_class_digit() []rune {
	return [`0`, `9`]
}

fn code_class_word() []rune {
	return [`a`, `z`, `A`, `Z`, `0`, `9`, `_`, `_`]
}

fn code_class_space() []rune {
	return [` `, ` `, `\t`, `\t`, `\n`, `\n`, `\r`, `\r`, `\f`, `\f`, `\v`, `\v`]
}

fn (mut p CodeRegexParser) parse_escape(in_class bool) !CodeRegexNode {
	if p.pos >= p.src.len {
		return error('trailing `\\` in the regular expression')
	}
	c := p.src[p.pos]
	p.pos++
	match c {
		`d`, `D` {
			return CodeRegexNode{
				kind:   `[`
				ranges: code_class_digit()
				negate: c == `D`
			}
		}
		`w`, `W` {
			return CodeRegexNode{
				kind:   `[`
				ranges: code_class_word()
				negate: c == `W`
			}
		}
		`s`, `S` {
			return CodeRegexNode{
				kind:   `[`
				ranges: code_class_space()
				negate: c == `S`
			}
		}
		`b`, `B` {
			if in_class {
				return p.char_node(if c == `b` { rune(8) } else { c })
			}
			return CodeRegexNode{
				kind: if c == `b` { u8(`b`) } else { u8(`B`) }
			}
		}
		`t` {
			return p.char_node(`\t`)
		}
		`n` {
			return p.char_node(`\n`)
		}
		`r` {
			return p.char_node(`\r`)
		}
		else {
			if code_ident_rune(c) && !code_digit(c) && c < 0x80 {
				return error('unknown escape `\\${c}` in the regular expression')
			}
			return p.char_node(c)
		}
	}
}

fn (mut p CodeRegexParser) parse_class() !CodeRegexNode {
	mut negate := false
	if p.pos < p.src.len && p.src[p.pos] == `^` {
		negate = true
		p.pos++
	}
	mut ranges := []rune{}
	mut first := true
	for {
		if p.pos >= p.src.len {
			return error('missing `]` in the regular expression')
		}
		c := p.src[p.pos]
		if c == `]` && !first {
			p.pos++
			break
		}
		first = false
		p.pos++
		mut lo := c
		if c == `\\` {
			esc := p.parse_escape(true)!
			if esc.kind == `[` {
				if esc.negate {
					return error('negated escapes are not supported inside `[]`')
				}
				ranges << esc.ranges
				continue
			}
			lo = esc.r
		}
		mut hi := lo
		if p.pos + 1 < p.src.len && p.src[p.pos] == `-` && p.src[p.pos + 1] != `]` {
			p.pos++
			mut h := p.src[p.pos]
			p.pos++
			if h == `\\` {
				esc := p.parse_escape(true)!
				if esc.kind != `c` {
					return error('bad range in the regular expression')
				}
				h = esc.r
			}
			hi = h
			if hi < lo {
				return error('bad range in the regular expression')
			}
		}
		ranges << lo
		ranges << hi
	}
	return CodeRegexNode{
		kind:   `[`
		ranges: ranges
		negate: negate
	}
}

fn code_regex_emit(node CodeRegexNode, mut program []CodeRegexInst) ! {
	if program.len > 20000 {
		return error('the regular expression is too large')
	}
	match node.kind {
		`c` {
			program << CodeRegexInst{
				op: .char
				r:  node.r
			}
		}
		`.` {
			program << CodeRegexInst{
				op: .any
			}
		}
		`[` {
			program << CodeRegexInst{
				op:     .class
				ranges: node.ranges
				negate: node.negate
			}
		}
		`^` {
			program << CodeRegexInst{
				op: .bol
			}
		}
		`$` {
			program << CodeRegexInst{
				op: .eol
			}
		}
		`b` {
			program << CodeRegexInst{
				op: .word_boundary
			}
		}
		`B` {
			program << CodeRegexInst{
				op: .not_word_boundary
			}
		}
		`s` {
			for child in node.children {
				code_regex_emit(child, mut program)!
			}
		}
		`|` {
			// split L1, next; L1: a; jmp end; next: split L2, ...
			mut jumps := []int{}
			for index, child in node.children {
				if index < node.children.len - 1 {
					split := program.len
					program << CodeRegexInst{
						op: .split
						x:  split + 1
					}
					code_regex_emit(child, mut program)!
					jumps << program.len
					program << CodeRegexInst{
						op: .jmp
					}
					program[split].y = program.len
				} else {
					code_regex_emit(child, mut program)!
				}
			}
			for j in jumps {
				program[j].x = program.len
			}
		}
		`*` {
			atom := node.children[0]
			for _ in 0 .. node.min {
				code_regex_emit(atom, mut program)!
			}
			if node.max < 0 {
				// L1: split L2, L3; L2: atom; jmp L1; L3:
				l1 := program.len
				program << CodeRegexInst{
					op: .split
				}
				code_regex_emit(atom, mut program)!
				program << CodeRegexInst{
					op: .jmp
					x:  l1
				}
				l3 := program.len
				if node.lazy {
					program[l1].x = l3
					program[l1].y = l1 + 1
				} else {
					program[l1].x = l1 + 1
					program[l1].y = l3
				}
			} else {
				mut splits := []int{}
				for _ in node.min .. node.max {
					splits << program.len
					program << CodeRegexInst{
						op: .split
					}
					code_regex_emit(atom, mut program)!
				}
				end := program.len
				for s in splits {
					if node.lazy {
						program[s].x = end
						program[s].y = s + 1
					} else {
						program[s].x = s + 1
						program[s].y = end
					}
				}
			}
		}
		else {}
	}
}

fn code_regex_class_has(ranges []rune, r rune) bool {
	for k := 0; k + 1 < ranges.len; k += 2 {
		if r >= ranges[k] && r <= ranges[k + 1] {
			return true
		}
	}
	return false
}

fn code_regex_matches(inst CodeRegexInst, r rune, fold bool) bool {
	match inst.op {
		.char {
			return (if fold { code_fold_rune(r) } else { r }) == inst.r
		}
		.any {
			return r != `\n`
		}
		.class {
			mut has := code_regex_class_has(inst.ranges, r)
			if !has && fold {
				lower := r.to_lower()
				upper := r.to_upper()
				has = code_regex_class_has(inst.ranges, lower)
					|| code_regex_class_has(inst.ranges, upper)
			}
			return has != inst.negate
		}
		else {
			return false
		}
	}
}

struct CodeRegexThread {
	pc    int
	start int
}

struct CodeRegexList {
mut:
	threads []CodeRegexThread
	seen    []int // generation each pc was last added in
}

fn code_regex_word_at(runes []rune, i int) bool {
	return i >= 0 && i < runes.len && is_word_rune(runes[i])
}

fn code_regex_add(program []CodeRegexInst, mut list CodeRegexList, generation int, pc int, start int, runes []rune, pos int) {
	if list.seen[pc] == generation {
		return
	}
	list.seen[pc] = generation
	inst := program[pc]
	match inst.op {
		.jmp {
			code_regex_add(program, mut list, generation, inst.x, start, runes, pos)
		}
		.split {
			code_regex_add(program, mut list, generation, inst.x, start, runes, pos)
			code_regex_add(program, mut list, generation, inst.y, start, runes, pos)
		}
		.bol {
			if pos == 0 || runes[pos - 1] == `\n` {
				code_regex_add(program, mut list, generation, pc + 1, start, runes, pos)
			}
		}
		.eol {
			if pos == runes.len || runes[pos] == `\n` {
				code_regex_add(program, mut list, generation, pc + 1, start, runes, pos)
			}
		}
		.word_boundary, .not_word_boundary {
			boundary := code_regex_word_at(runes, pos - 1) != code_regex_word_at(runes, pos)
			if boundary == (inst.op == .word_boundary) {
				code_regex_add(program, mut list, generation, pc + 1, start, runes, pos)
			}
		}
		else {
			list.threads << CodeRegexThread{pc, start}
		}
	}
}

// code_regex_find runs the program over runes from `from` and returns the
// leftmost match, preferring the alternatives and repetition counts the
// expression lists first, as Perl-style engines do.
fn code_regex_find(program []CodeRegexInst, runes []rune, from int, fold bool) ?CodeRange {
	// A thread's place in its list is its priority. Positions double as the
	// generation that marks which program counters a list already holds.
	mut current := CodeRegexList{
		seen: []int{len: program.len, init: -1}
	}
	mut next := CodeRegexList{
		seen: []int{len: program.len, init: -1}
	}
	mut found := false
	mut best := CodeRange{}
	for pos := from; pos <= runes.len; pos++ {
		if !found {
			code_regex_add(program, mut current, pos, 0, pos, runes, pos)
		}
		if current.threads.len == 0 {
			if found {
				break
			}
			continue
		}
		for t in current.threads {
			inst := program[t.pc]
			if inst.op == .match {
				found = true
				best = CodeRange{t.start, pos}
				// Lower-priority threads lose to this one.
				break
			}
			if pos < runes.len && code_regex_matches(inst, runes[pos], fold) {
				code_regex_add(program, mut next, pos + 1, t.pc + 1, t.start, runes, pos + 1)
			}
		}
		current.threads.clear()
		current, next = next, current
	}
	if found {
		return best
	}
	return none
}

fn code_regex_find_all(program []CodeRegexInst, runes []rune, fold bool) []CodeRange {
	mut out := []CodeRange{}
	mut from := 0
	for from <= runes.len {
		m := code_regex_find(program, runes, from, fold) or { break }
		if m.end > m.start {
			out << m
			from = m.end
		} else {
			from = m.start + 1
		}
		if out.len > 100000 {
			break
		}
	}
	return out
}

// ── Search state and the search bar ───────────────────────────────────────

// CodeSearchState is the application's search: whether the bar is open (and
// with its replace row), the query and replacement, the toggles, and which
// match is current.
pub struct CodeSearchState {
pub:
	open        bool
	replace     bool // The replace row is showing.
	query       string
	replacement string
	options     CodeSearchOptions
	current     int = -1
}

// code_search_matches is the matches of the state's query, or none while the
// query is empty or not a valid expression.
pub fn code_search_matches(text string, state CodeSearchState) []CodeRange {
	return code_search(text, state.query, state.options) or { []CodeRange{} }
}

// code_search_error is the message for an invalid regular expression, empty
// when the query is fine.
pub fn code_search_error(state CodeSearchState) string {
	if !state.options.regex || state.query.len == 0 {
		return ''
	}
	code_regex_compile(state.query, !state.options.match_case) or { return err.msg() }
	return ''
}

// code_search_field_id is the id of the search bar's query field: focus it
// after opening the bar, and read it with text() when it reports an edit.
pub fn code_search_field_id(id string) string {
	return input_group_field_id(component_part_id(id, 'search:query'))
}

// code_search_replace_field_id is the id of the replacement field.
pub fn code_search_replace_field_id(id string) string {
	return input_group_field_id(component_part_id(id, 'search:replace'))
}

// CodeSearchStep is what a search action or key did: the state to store, a
// replacement to apply, whether to scroll the current match into view
// (code_editor_reveal) or to select it in the text area (after closing the
// bar), and a field to focus after the rebuild.
pub struct CodeSearchStep {
pub:
	state  CodeSearchState
	edit   ?CodeEdit
	reveal bool
	select bool
	focus  string
}

fn code_search_current_range(config CodeEditorConfig, state CodeSearchState) ?CodeRange {
	matches := code_search_matches(config.text, state)
	if state.current < 0 || state.current >= matches.len {
		return none
	}
	return matches[state.current]
}

// code_search_with_query is the state after the query or options change: the
// current match is the first at or after the selection.
fn code_search_requery(config CodeEditorConfig, state CodeSearchState) CodeSearchState {
	matches := code_search_matches(config.text, state)
	start, _ := config.selection.ordered()
	return CodeSearchState{
		...state
		current: code_search_next_index(matches, start, true)
	}
}

fn code_search_move(config CodeEditorConfig, forward bool) ?CodeSearchStep {
	search := config.search
	matches := code_search_matches(config.text, search)
	if matches.len == 0 {
		return none
	}
	current := if search.current >= 0 && search.current < matches.len {
		if forward {
			(search.current + 1) % matches.len
		} else {
			(search.current - 1 + matches.len) % matches.len
		}
	} else {
		start, end := config.selection.ordered()
		code_search_next_index(matches, if forward { end } else { start }, forward)
	}
	return CodeSearchStep{
		state:  CodeSearchState{
			...search
			current: current
		}
		reveal: true
	}
}

fn code_search_open(config CodeEditorConfig, replace bool) CodeSearchStep {
	runes := config.text.runes()
	start, end := config.selection.ordered()
	mut query := config.search.query
	if end > start && end <= runes.len {
		selected := runes[start..end].string()
		if !selected.contains('\n') {
			query = selected
		}
	}
	next := code_search_requery(config, CodeSearchState{
		...config.search
		open:    true
		replace: replace && !config.read_only && !config.disabled
		query:   query
	})
	return CodeSearchStep{
		state:  next
		reveal: next.current >= 0
		focus:  if replace && query.len > 0 && !config.read_only {
			code_search_replace_field_id(config.id)
		} else {
			code_search_field_id(config.id)
		}
	}
}

// code_search_command runs the search commands of code_command_for_key: Find
// opens the bar (with the selected text as the query), Find and Replace opens
// it with the replace row, and Find Next and Find Previous move the current
// match even while the bar is closed. Other commands give none.
pub fn code_search_command(config CodeEditorConfig, command CodeCommand) ?CodeSearchStep {
	return match command {
		.find { code_search_open(config, false) }
		.find_replace { code_search_open(config, true) }
		.find_next { code_search_move(config, true) }
		.find_previous { code_search_move(config, false) }
		else { none }
	}
}

// code_search_close closes the bar; the step selects the current match in the
// text area, which also takes the focus back.
pub fn code_search_close(config CodeEditorConfig) CodeSearchStep {
	return CodeSearchStep{
		state:  CodeSearchState{
			...config.search
			open: false
		}
		select: code_search_current_range(config, config.search) != none
		focus:  code_editor_text_id(config.id)
	}
}

// code_search_key handles keys for an open search bar from on_key_event:
// Escape closes it, and Enter (Shift+Enter) in the query field moves to the
// next (previous) match on renderers that offer Return to on_key_event before
// the field. Consume the key when a step comes back.
pub fn code_search_key(config CodeEditorConfig, event KeyEvent) ?CodeSearchStep {
	if !config.search.open || event.cmd || event.ctrl || event.alt {
		return none
	}
	match event.code {
		.escape {
			if event.shift {
				return none
			}
			return code_search_close(config)
		}
		else {
			return none
		}
	}
}

// code_search_update applies a search-bar event: an edit of the query or the
// replacement (field_text is what the field now holds: text(event)), Return in
// either field, the toggles, previous, next, replace, replace all, the replace
// row's disclosure and close. It returns none for events that are not the bar's
// or change nothing.
pub fn code_search_update(config CodeEditorConfig, event string, field_text string) ?CodeSearchStep {
	part := component_action_part(config.id, event) or { return none }
	search := config.search
	if !search.open {
		return none
	}
	editable := !config.read_only && !config.disabled
	query_group := 'search:query'
	replace_group := 'search:replace'
	match part {
		'${query_group}:component:field' {
			if field_text == search.query {
				return none
			}
			next := code_search_requery(config, CodeSearchState{
				...search
				query: field_text
			})
			return CodeSearchStep{
				state:  next
				reveal: next.current >= 0
			}
		}
		'${query_group}:component:submit' {
			mods := key_modifiers()
			return code_search_move(config, !mods.shift)
		}
		'${replace_group}:component:field' {
			if field_text == search.replacement {
				return none
			}
			return CodeSearchStep{
				state: CodeSearchState{
					...search
					replacement: field_text
				}
			}
		}
		'${replace_group}:component:submit', 'search:replace_one' {
			if !editable {
				return none
			}
			matches := code_search_matches(config.text, search)
			mut index := search.current
			if index < 0 || index >= matches.len {
				index = code_search_next_index(matches, config.selection.caret, true)
			}
			edit := code_search_replace(config.text, matches, index, search.replacement) or {
				return none
			}
			// The next match is the one that now follows the replacement.
			later := code_search(edit.text, search.query, search.options) or { []CodeRange{} }
			next_index := code_search_next_index(later, edit.selection.caret, true)
			return CodeSearchStep{
				state:  CodeSearchState{
					...search
					current: next_index
				}
				edit:   edit
				reveal: next_index >= 0
			}
		}
		'search:replace_all' {
			if !editable {
				return none
			}
			edit := code_search_replace_all(config.text, code_search_matches(config.text, search),
				search.replacement) or { return none }
			return CodeSearchStep{
				state: CodeSearchState{
					...search
					current: -1
				}
				edit:  edit
			}
		}
		'search:previous', 'search:next' {
			return code_search_move(config, part == 'search:next')
		}
		'search:close' {
			return code_search_close(config)
		}
		'search:expand' {
			if !editable {
				return none
			}
			return CodeSearchStep{
				state: CodeSearchState{
					...search
					replace: !search.replace
				}
				focus: if !search.replace { code_search_replace_field_id(config.id) } else { '' }
			}
		}
		else {}
	}
	toggle_prefix := '${query_group}:component:addon:'
	if part.starts_with(toggle_prefix) {
		addon := code_hex_decode(part[toggle_prefix.len..]) or { return none }
		options := search.options
		next_options := match addon {
			'case' {
				CodeSearchOptions{
					...options
					match_case: !options.match_case
				}
			}
			'word' {
				CodeSearchOptions{
					...options
					whole_word: !options.whole_word
				}
			}
			'regex' {
				CodeSearchOptions{
					...options
					regex: !options.regex
				}
			}
			else { return none }
		}
		next := code_search_requery(config, CodeSearchState{
			...search
			options: next_options
		})
		return CodeSearchStep{
			state:  next
			reveal: next.current >= 0
		}
	}
	return none
}

fn code_hex_decode(hex string) ?string {
	if hex.len == 0 || hex.len % 2 != 0 {
		return none
	}
	mut out := []u8{cap: hex.len / 2}
	for k := 0; k < hex.len; k += 2 {
		hi := picker_hex_digit(hex[k]) or { return none }
		lo := picker_hex_digit(hex[k + 1]) or { return none }
		out << u8(hi * 16 + lo)
	}
	return out.bytestr()
}

// code_search_bar_size is the width and height the search bar takes for a
// state: one row, or two with the replace row.
pub fn code_search_bar_size(state CodeSearchState, editable bool, size ComponentSize) (f64, f64) {
	m := component_metrics(size)
	rows := if state.replace && editable { 2 } else { 1 }
	return 440.0, f64(rows) * m.height + f64(rows - 1) * m.gap + 2 * m.gap + 2
}

// CodeSearchBarConfig draws the search bar on its own, for an application
// that places it itself; code_editor draws it inside the editor while
// search.open.
pub struct CodeSearchBarConfig {
pub:
	id       string // The editor's id: the bar's actions are named after it.
	frame    Rect
	state    CodeSearchState
	matches  int    // How many matches the query has.
	error    string // An invalid expression, shown instead of the count.
	editable bool          = true // Show the replace row's disclosure.
	size     ComponentSize = .small
	theme    ComponentTheme
}

fn code_search_toggle(addon string, title string, tooltip string, on bool) InputGroupAddon {
	return InputGroupAddon{
		id:                  addon
		kind:                .button
		text:                title
		side:                .trailing
		primary:             on
		tooltip:             tooltip
		accessibility_label: tooltip
	}
}

fn code_search_icon_button(id string, part string, icon string, frame Rect, tooltip string, enabled bool, theme ComponentTheme, size f64) Element {
	color := if enabled { theme.foreground } else { theme.muted_foreground }
	return Element{
		...button_view(component_part_id(id, part), frame, BoxStyle{
			transparent: true
			radius:      4
		}, [
			inputs_symbol(icon, inputs_centered_square(component_local(frame), size), color),
		])
		key:                 part
		enabled:             enabled
		tooltip:             tooltip
		accessibility_label: tooltip
	}
}

fn code_search_text_button(id string, part string, title string, frame Rect, enabled bool, theme ComponentTheme, font f64) Element {
	return Element{
		...button_view(component_part_id(id, part), frame, BoxStyle{
			bg:            theme.muted
			radius:        4
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, [
			label('', title, component_local(frame), TextStyle{
				color: if enabled { theme.foreground } else { theme.muted_foreground }
				size:  font
				align: .center
			}),
		])
		key:                 part
		enabled:             enabled
		accessibility_label: title
	}
}

// code_search_bar is the find (and replace) panel: a query field with the
// match-case, whole-word and regex toggles, the match count, previous, next and
// close, and below it while state.replace the replacement field with Replace
// and Replace All. Decode its events with code_search_update.
pub fn code_search_bar(config CodeSearchBarConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	m := component_metrics(config.size)
	theme := config.theme
	bar := config.state
	width := config.frame.width
	pad := m.gap
	row_h := m.height
	icon := m.font_size + 2
	mut children := []Element{}
	mut x := pad
	if config.editable {
		disclosure := rect(x, pad, 18, row_h)
		children << code_search_icon_button(config.id, 'search:expand', if bar.replace {
			'chevron.down'
		} else {
			'chevron.right'
		}, disclosure, if bar.replace { 'Hide replace' } else { 'Show replace' }, true,
			theme, icon - 2)
		x += 18 + m.gap / 2
	}
	buttons_w := 3 * row_h + 2
	count_w := 72.0
	field_w := math.max(width - x - pad - count_w - buttons_w - m.gap, 80)
	opts := bar.options
	query := input_group(InputGroupConfig{
		id:                  component_part_id(config.id, 'search:query')
		frame:               rect(x, pad, field_w, row_h)
		text:                bar.query
		placeholder:         'Find'
		invalid:             config.error.len > 0
		addons:              [
			code_search_toggle('case', 'Aa', 'Match case', opts.match_case),
			code_search_toggle('word', 'ab', 'Match whole word', opts.whole_word),
			code_search_toggle('regex', '.*', 'Use regular expression', opts.regex),
		]
		accessibility_label: 'Find'
		size:                config.size
		theme:               theme
	})!
	children << Element{
		...query
		key: 'query'
	}
	count_x := x + field_w + m.gap
	count := if config.error.len > 0 {
		'Invalid'
	} else if bar.query.len == 0 {
		''
	} else if config.matches == 0 {
		'No results'
	} else if bar.current >= 0 && bar.current < config.matches {
		'${bar.current + 1} of ${config.matches}'
	} else {
		'${config.matches} found'
	}
	children << Element{
		...label('', count, rect(count_x, pad, count_w, row_h), TextStyle{
			color: if config.error.len > 0 || (bar.query.len > 0 && config.matches == 0) {
				theme.danger
			} else {
				theme.muted_foreground
			}
			size:  m.font_size
		})
		key:                 'count'
		tooltip:             config.error
		accessibility_role:  'status'
		accessibility_label: count
	}
	bx := count_x + count_w
	has := config.matches > 0
	children << code_search_icon_button(config.id, 'search:previous', 'arrow.up', rect(bx,
		pad, row_h, row_h), 'Previous match', has, theme, icon)
	children << code_search_icon_button(config.id, 'search:next', 'arrow.down', rect(bx +
		row_h, pad, row_h, row_h), 'Next match', has, theme, icon)
	children << code_search_icon_button(config.id, 'search:close', 'xmark', rect(bx + 2 * row_h,
		pad, row_h, row_h), 'Close', true, theme, icon - 2)
	if bar.replace && config.editable {
		y := pad + row_h + m.gap
		replace := input_group(InputGroupConfig{
			id:                  component_part_id(config.id, 'search:replace')
			frame:               rect(x, y, field_w, row_h)
			text:                bar.replacement
			placeholder:         'Replace'
			accessibility_label: 'Replace'
			size:                config.size
			theme:               theme
		})!
		children << Element{
			...replace
			key: 'replace'
		}
		one_w := measure_text_width('Replace', TextStyle{ size: m.font_size }) + 2 * m.padding
		all_w := measure_text_width('All', TextStyle{ size: m.font_size }) + 2 * m.padding
		children << code_search_text_button(config.id, 'search:replace_one', 'Replace', rect(count_x,
			y, one_w, row_h), has, theme, m.font_size)
		children << code_search_text_button(config.id, 'search:replace_all', 'All', rect(count_x +
			one_w + m.gap, y, all_w, row_h), has, theme, m.font_size)
	}
	box, mut panel := popover_panel(config.frame, theme.background, theme.border, m.radius,
		true)
	panel << children
	return component_finish(Element{
		...view(component_part_id(config.id, 'search'), config.frame, box, panel)
		clickable:           true
		accessibility_role:  'search'
		accessibility_label: 'Find'
	})
}
