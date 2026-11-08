module ui2

// ── Helpers ───────────────────────────────────────────────────────────────

fn editor_token_texts(text string, language CodeLanguage) []string {
	runes := text.runes()
	mut out := []string{}
	for t in code_tokens(text, language) {
		out << '${t.kind}:${runes[t.start..t.end].string()}'
	}
	return out
}

fn editor_kind_of(text string, language CodeLanguage, needle string) CodeTokenKind {
	runes := text.runes()
	index := text.index(needle) or { panic('no `${needle}` in the sample') }
	start := text[..index].runes().len
	for t in code_tokens(text, language) {
		if t.start <= start && start < t.end {
			return t.kind
		}
	}
	_ = runes
	return .plain
}

// editor_sel builds a selection from a text marked with `|` for the caret, or
// `[` and `]` for a selection, and returns the text without the marks.
fn editor_sel(marked string) (string, TextSelection) {
	runes := marked.runes()
	mut out := []rune{}
	mut anchor := -1
	mut caret := -1
	for r in runes {
		match r {
			`|` {
				anchor = out.len
				caret = out.len
			}
			`[` {
				anchor = out.len
			}
			`]` {
				caret = out.len
			}
			else {
				out << r
			}
		}
	}
	return out.string(), TextSelection{anchor, caret}
}

// editor_mark writes a text with its selection marked as editor_sel reads it.
fn editor_mark(text string, sel TextSelection) string {
	runes := text.runes()
	mut out := []rune{}
	for index in 0 .. runes.len + 1 {
		if sel.collapsed() && index == sel.caret {
			out << `|`
		} else if !sel.collapsed() {
			start, end := sel.ordered()
			if index == start {
				out << `[`
			}
			if index == end {
				out << `]`
			}
		}
		if index < runes.len {
			out << runes[index]
		}
	}
	return out.string()
}

fn editor_apply(marked string, f fn (string, TextSelection) ?CodeEdit) string {
	text, sel := editor_sel(marked)
	edit := f(text, sel) or { return 'none' }
	// The replacement must turn the old text into the new one.
	runes := text.runes()
	assert runes[..edit.start].string() + edit.insert + runes[edit.end..].string() == edit.text
	return editor_mark(edit.text, edit.selection)
}

fn editor_settings(language CodeLanguage) CodeEditSettings {
	return CodeEditSettings{
		language: language
		tab_size: 4
	}
}

fn editor_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := editor_find(child, id) {
			return found
		}
	}
	return none
}

fn editor_count_ids(el Element, prefix string) int {
	mut n := if el.id.starts_with(prefix) { 1 } else { 0 }
	for child in el.children {
		n += editor_count_ids(child, prefix)
	}
	return n
}

fn editor_primary(code KeyCode, shift bool, alt bool) KeyEvent {
	$if macos || ios {
		return KeyEvent{
			code:  code
			cmd:   true
			shift: shift
			alt:   alt
		}
	} $else {
		return KeyEvent{
			code:  code
			ctrl:  true
			shift: shift
			alt:   alt
		}
	}
}

const editor_v_sample = "module main\n\nfn main() {\n\tname := 'ui2'\n\tprintln('hi \${name}')\n}\n"

fn editor_config(text string) CodeEditorConfig {
	return CodeEditorConfig{
		id:       'ed'
		frame:    rect(0, 0, 640, 360)
		text:     text
		language: .v
		folding:  true
	}
}

// ── Languages and tokens ──────────────────────────────────────────────────

fn test_code_language_reads_names_aliases_and_paths() {
	assert code_language('V') == .v
	assert code_language('rs') == .rust
	assert code_language('TSX') == .typescript
	assert code_language('jsx') == .javascript
	assert code_language('pyi') == .python
	assert code_language('golang') == .go
	assert code_language('jsonc') == .json
	assert code_language('md') == .markdown
	assert code_language('zsh') == .shell
	assert code_language('cobol') == .plain
	assert code_language_from_path('src/main.rs') == .rust
	assert code_language_from_path('/a/b/Cargo.lock') == .toml
	assert code_language_from_path('notes.MD') == .markdown
	assert code_language_from_path('Makefile') == .plain
	for language in code_languages() {
		assert code_language(language.id()) == language
		assert language.title().len > 0
	}
}

fn test_code_tokens_v() {
	src := "@[heap]\nstruct Foo {\n\tbar []int = [1, 0x1F]\n}\n// note\nfn (mut f Foo) run(n int) string {\n\treturn 'a\${f.bar}b \$n' + `c`\n}\n#flag -lm\n\$if macos {}\nconst max = 1_000"
	assert editor_kind_of(src, .v, '@[heap]') == .attribute
	assert editor_kind_of(src, .v, 'struct') == .keyword
	assert editor_kind_of(src, .v, 'Foo {') == .type
	assert editor_kind_of(src, .v, 'int =') == .type
	assert editor_kind_of(src, .v, '0x1F') == .number
	assert editor_kind_of(src, .v, '// note') == .comment
	assert editor_kind_of(src, .v, 'run(') == .function
	assert editor_kind_of(src, .v, "'a") == .string
	assert editor_kind_of(src, .v, '\${') == .embedded
	assert editor_kind_of(src, .v, 'bar}') == .property
	assert editor_kind_of(src, .v, "n'") == .variable_special
	assert editor_kind_of(src, .v, '`c`') == .string
	assert editor_kind_of(src, .v, '#flag') == .attribute
	assert editor_kind_of(src, .v, '\$if') == .keyword
	assert editor_kind_of(src, .v, '1_000') == .number
}

fn test_code_tokens_rust_go_js_ts() {
	rust := 'fn f<\'a>(x: &\'a str) -> Option<u8> { let c = \'\\n\'; println!("{}", r#"raw"#); self.x }'
	assert editor_kind_of(rust, .rust, "'a>") == .variable_special
	assert editor_kind_of(rust, .rust, 'str') == .type
	assert editor_kind_of(rust, .rust, 'Option') == .type
	assert editor_kind_of(rust, .rust, '\\n') == .string_escape
	assert editor_kind_of(rust, .rust, 'println!') == .function
	assert editor_kind_of(rust, .rust, 'r#"raw"#') == .string
	assert editor_kind_of(rust, .rust, 'self') == .variable_special
	golang := 'func (a *App) Run() error {\n\treturn fmt.Errorf(`raw\nstring`) // done\n}'
	assert editor_kind_of(golang, .go, 'Run') == .function
	assert editor_kind_of(golang, .go, 'error') == .type
	assert editor_kind_of(golang, .go, 'string`') == .string
	assert editor_kind_of(golang, .go, '// done') == .comment
	js := 'const s = `a\${b + 1}c`; class A extends B { get x() { return this.y ?? null } }'
	assert editor_kind_of(js, .javascript, 'const') == .keyword
	assert editor_kind_of(js, .javascript, '`a') == .string
	assert editor_kind_of(js, .javascript, '\${') == .embedded
	assert editor_kind_of(js, .javascript, '1}') == .number
	assert editor_kind_of(js, .javascript, 'B {') == .type
	assert editor_kind_of(js, .javascript, 'this') == .variable_special
	assert editor_kind_of(js, .javascript, 'null') == .constant
	ts := '@Component\ninterface Props { size: number; label?: string }\ntype Id = string'
	assert editor_kind_of(ts, .typescript, '@Component') == .attribute
	assert editor_kind_of(ts, .typescript, 'interface') == .keyword
	assert editor_kind_of(ts, .typescript, 'Props') == .type
	assert editor_kind_of(ts, .typescript, 'number') == .type
	assert editor_kind_of(ts, .typescript, 'Id') == .type
}

fn test_code_tokens_python_json_toml_shell() {
	py := '@dataclass\nclass A(B):\n    """Doc."""\n    def f(self, x=1):\n        return f"{x!r} \\n" + rb\'\\d\'  # note\nNone'
	assert editor_kind_of(py, .python, '@dataclass') == .attribute
	assert editor_kind_of(py, .python, 'A(') == .type
	assert editor_kind_of(py, .python, '"""Doc."""') == .string
	assert editor_kind_of(py, .python, 'f(self') == .function
	assert editor_kind_of(py, .python, 'self') == .variable_special
	assert editor_kind_of(py, .python, '{x') == .embedded
	assert editor_kind_of(py, .python, '\\n') == .string_escape
	assert editor_kind_of(py, .python, "rb'") == .string
	assert editor_kind_of(py, .python, '# note') == .comment
	assert editor_kind_of(py, .python, 'None') == .constant
	json := '{"a": [1.5e3, true, null], "b": "x\\n", "c": -2}'
	assert editor_kind_of(json, .json, '"a"') == .property
	assert editor_kind_of(json, .json, '1.5e3') == .number
	assert editor_kind_of(json, .json, 'true') == .constant
	assert editor_kind_of(json, .json, '"x') == .string
	assert editor_kind_of(json, .json, '-2') == .number
	toml := '[package]\nname = "x" # c\nversion.major = 1\nwhen = 1979-05-27T07:32:00Z\n[[bin]]\nok = true'
	assert editor_kind_of(toml, .toml, '[package]') == .title
	assert editor_kind_of(toml, .toml, 'name') == .property
	assert editor_kind_of(toml, .toml, 'version.major') == .property
	assert editor_kind_of(toml, .toml, '# c') == .comment
	assert editor_kind_of(toml, .toml, '1979') == .number
	assert editor_kind_of(toml, .toml, '[[bin]]') == .title
	assert editor_kind_of(toml, .toml, 'true') == .constant
	sh := '#!/bin/sh\nexport A=1\nif [ -f "\$HOME/x" ]; then echo "\${A}" | grep -v x; fi'
	assert editor_kind_of(sh, .shell, '#!/bin/sh') == .comment
	assert editor_kind_of(sh, .shell, 'export') == .keyword
	assert editor_kind_of(sh, .shell, 'A=') == .property
	assert editor_kind_of(sh, .shell, '-f') == .attribute
	assert editor_kind_of(sh, .shell, '\$HOME') == .variable_special
	assert editor_kind_of(sh, .shell, 'echo') == .function
	assert editor_kind_of(sh, .shell, 'grep') == .function
	assert editor_kind_of(sh, .shell, 'fi') == .keyword
}

fn test_code_tokens_markdown_with_fenced_code() {
	md := '# Title\n\nSome **bold**, *it*, `code` and [link](http://x).\n- item\n1. first\n> quote\n---\n```v\nfn main() {}\n```\n```\nplain\n```'
	assert editor_kind_of(md, .markdown, '# Title') == .title
	assert editor_kind_of(md, .markdown, '**bold**') == .strong
	assert editor_kind_of(md, .markdown, '*it*') == .emphasis
	assert editor_kind_of(md, .markdown, '`code`') == .code_span
	assert editor_kind_of(md, .markdown, '[link]') == .link_text
	assert editor_kind_of(md, .markdown, '(http') == .link_uri
	assert editor_kind_of(md, .markdown, '- item') == .tag
	assert editor_kind_of(md, .markdown, '1. first') == .tag
	assert editor_kind_of(md, .markdown, '> quote') == .tag
	assert editor_kind_of(md, .markdown, '---') == .tag
	// The fence's language highlights the block.
	assert editor_kind_of(md, .markdown, 'fn main') == .keyword
	assert editor_kind_of(md, .markdown, 'plain') == .code_span
}

fn test_code_tokens_are_ordered_disjoint_and_in_bounds() {
	samples := [editor_v_sample, 'fn f() { "unterminated', "'''\nopen", '/* open comment', '`a \${b',
		'\${', '"\\', 'r#"x', '[[', '```', '$(echo', '#']
	for language in code_languages() {
		for sample in samples {
			length := sample.runes().len
			mut previous := 0
			for t in code_tokens(sample, language) {
				assert t.start >= previous
				assert t.end > t.start
				assert t.end <= length
				previous = t.end
			}
		}
	}
	assert code_tokens('anything', .plain).len == 0
}

// ── Runs ──────────────────────────────────────────────────────────────────

fn test_code_highlight_runs_cover_the_text_and_color_tokens() {
	theme := code_editor_theme(false)
	base := TextStyle{
		color:       theme.foreground
		size:        13
		font_family: 'Menlo'
	}
	runs := code_highlight_runs(CodeHighlightConfig{
		text:     editor_v_sample
		language: .v
		base:     base
		theme:    theme
	})
	assert runs.map(it.text).join('') == editor_v_sample
	for index in 1 .. runs.len {
		assert runs[index].style != runs[index - 1].style
	}
	first := runs[0]
	assert first.text == 'module'
	assert first.style.color == theme.keyword
	assert first.style.font_family == 'Menlo'
	assert first.style.size == 13
	plain := code_highlight_runs(CodeHighlightConfig{
		text:      editor_v_sample
		language:  .v
		base:      base
		theme:     theme
		highlight: false
	})
	assert plain.len == 1
	assert plain[0].style == theme.token_style(.plain, base)
	assert code_highlight_runs(CodeHighlightConfig{
		text: ''
	}).len == 0
}

fn test_code_highlight_runs_paint_matches_diagnostics_and_fills() {
	theme := code_editor_theme(false)
	text := 'ab ab\nab'
	runs := code_highlight_runs(CodeHighlightConfig{
		text:        text
		language:    .plain
		theme:       theme
		matches:     [CodeRange{0, 2}, CodeRange{3, 8}]
		current:     1
		diagnostics: [CodeDiagnostic{
			start:    6
			end:      8
			severity: .error
		}]
		decorations: [CodeDecoration{
			start: 0
			end:   1
			style: .fill
			color: 0x0000ff
		}]
	})
	assert runs.map(it.text).join('') == text
	// The fill lies under the first match, which wins.
	assert runs[0].text == 'ab'
	assert runs[0].style.background_color == theme.match_background
	// The current match crosses the newline, which stays unpainted.
	mut newline_bg := u32(1)
	mut underlined := ''
	for run in runs {
		if run.text == '\n' {
			newline_bg = run.style.background_color
		}
		if run.style.underline {
			underlined += run.text
		}
	}
	assert newline_bg == 0
	assert underlined == 'ab'
	current := runs.filter(it.style.background_color == theme.current_match_background)
	assert current.map(it.text).join('') == 'abab'
	fill := code_highlight_runs(CodeHighlightConfig{
		text:        'abc'
		theme:       theme
		decorations: [CodeDecoration{
			start: 0
			end:   3
			style: .fill
		}]
	})
	assert fill.len == 1
	assert fill[0].style.background_color == code_blend(theme.background, theme.foreground,
		0.12)
}

fn test_code_editor_theme_light_and_dark() {
	light := code_editor_theme(false)
	dark := code_editor_theme(true)
	assert !light.dark && dark.dark
	assert light.background != dark.background
	assert light.keyword != dark.keyword
	assert light.token_style(.strong, TextStyle{}).bold
	assert light.token_style(.emphasis, TextStyle{}).italic
	assert light.token_style(.comment, TextStyle{}).color == light.comment
	color, tint := dark.severity_colors(.warning)
	assert color == dark.warning && tint == dark.warning_background
	assert code_blend(0x000000, 0xffffff, 0.5) == 0x808080
	opacity := code_overlay_opacity(light.background, light.foreground, light.active_line_background)
	assert opacity > 0.02 && opacity < 0.06
}

// ── Editing rules ─────────────────────────────────────────────────────────

fn test_code_edit_newline_keeps_and_adds_indentation() {
	v := editor_settings(.v)
	newline := fn [v] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_newline(text, sel, v)
	}
	assert editor_apply('\tx := 1|', newline) == '\tx := 1\n\t|'
	assert editor_apply('fn main() {|', newline) == 'fn main() {\n    |'
	assert editor_apply('fn main() {|}', newline) == 'fn main() {\n    |\n}'
	assert editor_apply('\tf(|)', newline) == '\tf(\n\t    |\n\t)'
	assert editor_apply('\tx|  }', newline) == '\tx\n|}'
	assert editor_apply('a[bc]d', newline) == 'a\n|d'
	hard := CodeEditSettings{
		language:  .v
		hard_tabs: true
	}
	assert editor_apply('{|', fn [hard] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_newline(text, sel, hard)
	}) == '{\n\t|'
	py := editor_settings(.python)
	assert editor_apply('    if x:|', fn [py] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_newline(text, sel, py)
	}) == '    if x:\n        |'
	plain := CodeEditSettings{
		language:     .v
		smart_indent: false
	}
	assert editor_apply('\tf {|}', fn [plain] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_newline(text, sel, plain)
	}) == '\tf {\n\t|}'
}

fn test_code_edit_after_input_closes_pairs() {
	v := editor_settings(.v)
	typed := fn [v] (before string, after string) string {
		b, _ := editor_sel(before)
		a, as_ := editor_sel(after)
		edit := code_edit_after_input(b, a, as_, v) or { return 'none' }
		return editor_mark(edit.text, edit.selection)
	}
	assert typed('f|', 'f(|') == 'f(|)'
	assert typed('x = |;', 'x = {|;') == 'x = {|};'
	// Not in front of a word, inside a string or a comment.
	assert typed('|abc', '(|abc') == 'none'
	assert typed("s := 'a|'", "s := 'a(|'") == 'none'
	assert typed('// a|', '// a(|') == 'none'
	// Quotes pair, but not right after a word character.
	assert typed('x := |', "x := '|") == "x := '|'"
	assert typed('don|', "don'|") == 'none'
	// Typing a closer in front of the same closer types over it.
	assert typed('f(|)', 'f()|)') == 'f()|'
	assert typed('f(g(|)', 'f(g()|)') == 'none'
	assert typed("x := '|'", "x := ''|'") == "x := ''|"
	// An opener over a one-line selection wraps it.
	assert typed('[abc]', '(|') == '([abc])'
	assert typed('[a\nb]', '(|') == 'none'
	// Pastes, deletions and edits elsewhere are not typing.
	assert typed('f|', 'f()|') == 'none'
	assert typed('f(|', 'f|') == 'none'
	assert typed('ab|', 'xab(|') == 'none'
	// A caret the application had not caught up with does not matter.
	assert typed('|f', 'f(|') == 'f(|)'
	off := CodeEditSettings{
		language:   .v
		auto_close: false
	}
	b, _ := editor_sel('f|')
	a, as_ := editor_sel('f(|')
	assert code_edit_after_input(b, a, as_, off) == none
	// JSON closes only its own delimiters.
	json := editor_settings(.json)
	ja, jas := editor_sel('(|')
	assert code_edit_after_input('', ja, jas, json) == none
}

fn test_code_edit_backspace_deletes_pairs_and_indent_levels() {
	v := editor_settings(.v)
	backspace := fn [v] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_backspace(text, sel, v)
	}
	assert editor_apply('f(|)', backspace) == 'f|'
	assert editor_apply('a = "|"', backspace) == 'a = |'
	assert editor_apply('      |x', backspace) == '    |x'
	assert editor_apply('    |x', backspace) == '|x'
	assert editor_apply('ab|', backspace) == 'none'
	assert editor_apply('[ab]', backspace) == 'none'
	assert editor_apply('|', backspace) == 'none'
	hard := CodeEditSettings{
		language:  .v
		hard_tabs: true
	}
	assert editor_apply('    |', fn [hard] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_backspace(text, sel, hard)
	}) == 'none'
}

fn test_code_edit_indent_and_outdent() {
	v := editor_settings(.v)
	indent := fn [v] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_indent(text, sel, v)
	}
	outdent := fn [v] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_outdent(text, sel, v)
	}
	assert editor_apply('ab|c', indent) == 'ab  |c'
	assert editor_apply('|x', indent) == '    |x'
	assert editor_apply('[a\n\nb]', indent) == '[    a\n\n    b]'
	assert editor_apply('x[a\nb]\nc', indent) == '    x[a\n    b]\nc'
	// A selection ending at a line start leaves that line alone.
	assert editor_apply('[a\n]b', indent) == '[    a\n]b'
	assert editor_apply('    a|', outdent) == 'a|'
	assert editor_apply('\t\ta|', outdent) == '\ta|'
	assert editor_apply('  [a\n      b]', outdent) == '[a\n  b]'
	assert editor_apply('a|', outdent) == 'none'
	hard := CodeEditSettings{
		language:  .v
		hard_tabs: true
	}
	assert editor_apply('[a\nb]', fn [hard] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_indent(text, sel, hard)
	}) == '[\ta\n\tb]'
}

fn test_code_edit_toggle_comment() {
	v := editor_settings(.v)
	toggle := fn [v] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_toggle_comment(text, sel, v)
	}
	assert editor_apply('\tx|', toggle) == '\t// x|'
	assert editor_apply('\t// x|', toggle) == '\tx|'
	assert editor_apply('[\ta\n\t\tb\n\n\tc]', toggle) == '[\t// a\n\t// \tb\n\n\t// c]'
	assert editor_apply('[// a\nb]', toggle) == '[// // a\n// b]'
	assert editor_apply('[// a\n//b]', toggle) == '[a\nb]'
	assert editor_apply('   |', toggle) == 'none'
	py := editor_settings(.python)
	assert editor_apply('x = 1|', fn [py] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_toggle_comment(text, sel, py)
	}) == '# x = 1|'
	md := editor_settings(.markdown)
	md_toggle := fn [md] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_toggle_comment(text, sel, md)
	}
	assert editor_apply('Hello|', md_toggle) == '<!-- Hello| -->'
	assert editor_apply('<!-- Hello| -->', md_toggle) == 'Hello|'
	json := editor_settings(.json)
	assert editor_apply('{}|', fn [json] (text string, sel TextSelection) ?CodeEdit {
		return code_edit_toggle_comment(text, sel, json)
	}) == 'none'
}

fn test_code_line_commands() {
	dup := fn (text string, sel TextSelection) ?CodeEdit {
		return code_edit_duplicate_lines(text, sel)
	}
	assert editor_apply('a\nb|c\nd', dup) == 'a\nbc\nb|c\nd'
	assert editor_apply('a|', dup) == 'a\na|'
	up := fn (text string, sel TextSelection) ?CodeEdit {
		return code_edit_move_lines(text, sel, true)
	}
	down := fn (text string, sel TextSelection) ?CodeEdit {
		return code_edit_move_lines(text, sel, false)
	}
	assert editor_apply('a\nb|\nc', up) == 'b|\na\nc'
	assert editor_apply('a\nb|\nc', down) == 'a\nc\nb|'
	assert editor_apply('a|\nb', up) == 'none'
	assert editor_apply('a\nb|', down) == 'none'
	assert editor_apply('[a\nb]\nc', down) == 'c\n[a\nb]'
	del := fn (text string, sel TextSelection) ?CodeEdit {
		return code_edit_delete_lines(text, sel)
	}
	assert editor_apply('ab\nc|d\nef', del) == 'ab\ne|f'
	assert editor_apply('ab\ncd|', del) == 'ab|'
	assert editor_apply('a|bc\nd', del) == 'd|'
	text, sel := editor_sel('a\nb|c\nd')
	line := code_select_line(text, sel)
	assert editor_mark(text, line) == 'a\n[bc\n]d'
	assert editor_mark(text, code_select_line(text, line)) == 'a\n[bc\nd]'
	w, ws := editor_sel('let foo_bar| = foo_bar')
	word := code_select_word(w, ws, editor_settings(.v))
	assert editor_mark(w, word) == 'let [foo_bar] = foo_bar'
	assert editor_mark(w, code_select_word(w, word, editor_settings(.v))) == 'let foo_bar = [foo_bar]'
	sh, shs := editor_sel('echo \$HO|ME')
	assert editor_mark(sh, code_select_word(sh, shs, editor_settings(.shell))) == 'echo [\$HOME]'
}

fn test_code_positions_and_native_offsets() {
	text := 'ab\n😀c\nd'
	assert code_line_count(text) == 3
	assert code_position(text, 4) == CodePosition{1, 1}
	assert code_offset(text, 1, 1) == 4
	assert code_offset(text, 1, 99) == 5
	assert code_offset(text, 9, 0) == 6
	// The emoji is one rune but two UTF-16 units.
	location, length := code_editor_selection_to_native(text, TextSelection{3, 5})
	assert location == 3 && length == 3
	assert code_editor_selection_from_native(text, 3, 3) == TextSelection{3, 5}
	edit := code_edit_replace(text.runes(), 4, 5, 'xy', TextSelection{6, 6})
	native := code_edit_native(text, edit)
	assert native.location == 5 && native.length == 1 && native.insert == 'xy'
	assert native.select_location == 7 && native.select_length == 0
	between := code_edit_between('hello world', 'hello brave world')
	assert between.start == 6 && between.end == 6 && between.insert == 'brave '
}

fn test_code_ranges_follow_edits() {
	r := CodeRange{4, 8}
	insert := fn (at int, s string) CodeEdit {
		return CodeEdit{
			start:  at
			end:    at
			insert: s
		}
	}
	assert code_map_range(r, insert(0, 'ab'))? == CodeRange{6, 10}
	assert code_map_range(r, insert(4, 'ab'))? == CodeRange{6, 10} // at the start: does not grow
	assert code_map_range(r, insert(8, 'ab'))? == r // at the end: does not grow
	assert code_map_range(r, insert(6, 'ab'))? == CodeRange{4, 10} // inside: grows
	assert code_map_range(r, CodeEdit{ start: 2, end: 6, insert: 'x' })? == CodeRange{3, 5}
	assert code_map_range(r, CodeEdit{ start: 6, end: 10, insert: 'x' })? == CodeRange{4, 6}
	assert code_map_range(r, CodeEdit{ start: 3, end: 9 }) == none
	diagnostics := code_diagnostics_after_edit([
		CodeDiagnostic{
			start:   4
			end:     8
			message: 'kept'
		},
		CodeDiagnostic{
			start:   20
			end:     22
			message: 'gone'
		},
	], CodeEdit{
		start:  10
		end:    30
		insert: ''
	})
	assert diagnostics.len == 1 && diagnostics[0].message == 'kept'
	decorations := code_decorations_after_edit([CodeDecoration{
		start: 4
		end:   8
	}], insert(0, 'abc'))
	assert decorations[0].start == 7 && decorations[0].end == 11
}

// ── Commands and keys ─────────────────────────────────────────────────────

fn test_code_command_for_key_maps_the_editor_shortcuts() {
	assert code_command_for_key(KeyEvent{ code: .enter })? == .newline
	assert code_command_for_key(KeyEvent{ code: .tab })? == .indent
	assert code_command_for_key(KeyEvent{ code: .tab, shift: true })? == .outdent
	assert code_command_for_key(KeyEvent{ code: .backspace })? == .backspace
	assert code_command_for_key(editor_primary(.slash, false, false))? == .toggle_comment
	assert code_command_for_key(editor_primary(.right_bracket, false, false))? == .indent
	assert code_command_for_key(editor_primary(.left_bracket, false, false))? == .outdent
	assert code_command_for_key(KeyEvent{ code: .up, alt: true })? == .move_lines_up
	assert code_command_for_key(KeyEvent{ code: .down, alt: true })? == .move_lines_down
	assert code_command_for_key(KeyEvent{ code: .down, alt: true, shift: true })? == .duplicate_lines
	assert code_command_for_key(editor_primary(.d, true, false))? == .duplicate_lines
	assert code_command_for_key(editor_primary(.d, false, false))? == .select_word
	assert code_command_for_key(editor_primary(.k, true, false))? == .delete_lines
	assert code_command_for_key(editor_primary(.l, false, false))? == .select_line
	assert code_command_for_key(editor_primary(.f, false, false))? == .find
	assert code_command_for_key(editor_primary(.g, false, false))? == .find_next
	assert code_command_for_key(editor_primary(.g, true, false))? == .find_previous
	assert code_command_for_key(KeyEvent{ code: .f3 })? == .find_next
	assert code_command_for_key(KeyEvent{ code: .f3, shift: true })? == .find_previous
	$if macos || ios {
		assert code_command_for_key(editor_primary(.f, false, true))? == .find_replace
	} $else {
		assert code_command_for_key(editor_primary(.h, false, false))? == .find_replace
	}
	assert code_command_for_key(KeyEvent{ code: .a }) == none
	assert code_command_for_key(KeyEvent{ code: .up }) == none
	assert code_command_for_key(KeyEvent{ code: .enter, ctrl: true }) == none
	assert code_command_for_text_key('enter')? == .newline
	assert code_command_for_text_key('shift+tab')? == .outdent
	assert code_command_for_text_key('backspace')? == .backspace
	assert code_command_for_text_key('up') == none
	assert code_editor_text_command('ed', 'text:${code_editor_text_id('ed')}:tab')? == .indent
	assert code_editor_text_command('ed', 'text:other:tab') == none
	assert code_editor_text_command('', 'text::tab') == none
}

fn test_code_editor_command_respects_read_only() {
	text, sel := editor_sel('fn main() {|}')
	cfg := CodeEditorConfig{
		...editor_config(text)
		selection: sel
	}
	edit := code_editor_command(cfg, .newline)?
	assert edit.changes_text()
	read_only := CodeEditorConfig{
		...cfg
		read_only: true
	}
	assert code_editor_command(read_only, .newline) == none
	assert code_editor_command(read_only, .toggle_comment) == none
	selected := code_editor_command(read_only, .select_line)?
	assert !selected.changes_text()
	assert selected.selection == TextSelection{0, text.runes().len}
	assert code_editor_command(cfg, .find) == none
	assert code_editor_after_input(read_only, 'x', TextSelection{1, 1}) == none
}

// ── Search ────────────────────────────────────────────────────────────────

fn editor_found(text string, query string, options CodeSearchOptions) []string {
	runes := text.runes()
	matches := code_search(text, query, options) or { return ['error: ${err.msg()}'] }
	return matches.map(runes[it.start..it.end].string())
}

fn test_code_search_plain_case_and_whole_word() {
	text := 'Count count recount COUNT'
	assert editor_found(text, 'count', CodeSearchOptions{}) == ['Count', 'count', 'count', 'COUNT']
	assert editor_found(text, 'count', CodeSearchOptions{ match_case: true }) == [
		'count',
		'count',
	]
	assert editor_found(text, 'count', CodeSearchOptions{ whole_word: true }) == [
		'Count',
		'count',
		'COUNT',
	]
	assert editor_found('aaaa', 'aa', CodeSearchOptions{}) == ['aa', 'aa']
	assert editor_found('ÄÖ äö', 'äö', CodeSearchOptions{}) == ['ÄÖ', 'äö']
	assert code_search('abc', '', CodeSearchOptions{})!.len == 0
}

fn test_code_search_regular_expressions() {
	re := CodeSearchOptions{
		regex: true
	}
	assert editor_found('a1 b22 c333', '\\d+', re) == ['1', '22', '333']
	assert editor_found('fn foo() fn bar()', 'fn \\w+', re) == ['fn foo', 'fn bar']
	assert editor_found('cat cot cut', 'c[ao]t', re) == ['cat', 'cot']
	assert editor_found('cat cot cut', 'c[^ao]t', re) == ['cut']
	assert editor_found('one\ntwo\nthree', '^t\\w*$', re) == ['two', 'three']
	assert editor_found('ab abc', 'abc|ab', re) == ['ab', 'abc']
	assert editor_found('<a><b>', '<.+>', re) == ['<a><b>']
	assert editor_found('<a><b>', '<.+?>', re) == ['<a>', '<b>']
	assert editor_found('aaaaa', 'a{2,3}', re) == ['aaa', 'aa']
	assert editor_found('x catalog cat', '\\bcat\\b', re) == ['cat']
	assert editor_found('a.b', 'a\\.b', re) == ['a.b']
	assert editor_found('colour color', 'colou?r', re) == ['colour', 'color']
	assert editor_found('AbC', 'abc', re) == ['AbC']
	assert editor_found('AbC', '[a-c]+', re) == ['AbC']
	assert editor_found('AbC', 'abc', CodeSearchOptions{ regex: true, match_case: true }) == []string{}
	assert editor_found('ab', 'x*', re) == []string{}
	for bad in ['(', 'a)', '[a', '*a', 'a**', '\\q', 'a{3,1}'] {
		assert editor_found('abc', bad, re)[0].starts_with('error')
	}
	// Linear time: no catastrophic backtracking.
	long := 'a'.repeat(2000)
	assert code_search(long, '(a*)*b', re)!.len == 0
}

fn test_code_search_navigation_and_replace() {
	matches := [CodeRange{2, 4}, CodeRange{8, 10}, CodeRange{14, 16}]
	assert code_search_next_index(matches, 0, true) == 0
	assert code_search_next_index(matches, 5, true) == 1
	assert code_search_next_index(matches, 15, true) == 0
	assert code_search_next_index(matches, 8, false) == 0
	assert code_search_next_index(matches, 1, false) == 2
	assert code_search_next_index([]CodeRange{}, 0, true) == -1
	text := 'foo bar foo'
	found := code_search(text, 'foo', CodeSearchOptions{})!
	one := code_search_replace(text, found, 1, 'baz')?
	assert one.text == 'foo bar baz'
	assert one.selection == TextSelection{8, 11}
	all := code_search_replace_all(text, found, 'x')?
	assert all.text == 'x bar x'
	assert all.start == 0 && all.end == 11
	assert code_search_replace(text, found, 5, 'x') == none
	assert code_search_replace_all(text, []CodeRange{}, 'x') == none
}

fn editor_search_config(text string, search CodeSearchState) CodeEditorConfig {
	return CodeEditorConfig{
		...editor_config(text)
		search: search
	}
}

fn test_code_search_update_decodes_the_search_bar() {
	text := 'foo bar foo baz foo'
	cfg := editor_search_config(text, CodeSearchState{
		open:  true
		query: 'fo'
	})
	field := code_search_field_id('ed')
	step := code_search_update(cfg, field, 'foo')?
	assert step.state.query == 'foo'
	assert step.state.current == 0
	assert step.reveal
	assert code_search_update(cfg, field, 'fo') == none
	at_three := editor_search_config(text, CodeSearchState{
		open:    true
		query:   'foo'
		current: 2
	})
	next := code_search_update(at_three, component_part_id('ed', 'search:next'), '')?
	assert next.state.current == 0
	previous := code_search_update(at_three, component_part_id('ed', 'search:previous'),
		'')?
	assert previous.state.current == 1
	toggle := component_part_id('ed', 'search:query:component:addon:' + 'word'.bytes().hex())
	word := code_search_update(at_three, toggle, '')?
	assert word.state.options.whole_word
	replace_field := code_search_replace_field_id('ed')
	typed := code_search_update(at_three, replace_field, 'qux')?
	assert typed.state.replacement == 'qux'
	with_replacement := editor_search_config(text, CodeSearchState{
		...at_three.search
		replacement: 'qux'
	})
	replaced := code_search_update(with_replacement, component_part_id('ed', 'search:replace_one'),
		'')?
	edit := replaced.edit?
	assert edit.text == 'foo bar foo baz qux'
	assert replaced.state.current == 0
	all := code_search_update(with_replacement, component_part_id('ed', 'search:replace_all'),
		'')?
	assert all.edit?.text == 'qux bar qux baz qux'
	closed := code_search_update(at_three, component_part_id('ed', 'search:close'), '')?
	assert !closed.state.open
	assert closed.select
	assert closed.focus == code_editor_text_id('ed')
	// Read-only editors search but do not replace.
	read_only := CodeEditorConfig{
		...with_replacement
		read_only: true
	}
	assert code_search_update(read_only, component_part_id('ed', 'search:replace_all'), '') == none
	assert code_search_update(read_only, component_part_id('ed', 'search:expand'), '') == none
	// Foreign, forged and closed-bar events are not the bar's.
	assert code_search_update(at_three, 'other', '') == none
	assert code_search_update(at_three, component_part_id('ed', 'search:bogus'), '') == none
	assert code_search_update(at_three, component_part_id('ed', 'search:query:component:addon:zz'),
		'') == none
	closed_cfg := editor_search_config(text, CodeSearchState{
		query: 'foo'
	})
	assert code_search_update(closed_cfg, component_part_id('ed', 'search:next'), '') == none
}

fn test_code_search_commands_open_and_move() {
	text, sel := editor_sel('let [value] = value + value')
	cfg := CodeEditorConfig{
		...editor_config(text)
		selection: sel
	}
	opened := code_search_command(cfg, .find)?
	assert opened.state.open
	assert opened.state.query == 'value'
	assert opened.state.current == 0
	assert opened.focus == code_search_field_id('ed')
	replace := code_search_command(cfg, .find_replace)?
	assert replace.state.replace
	assert replace.focus == code_search_replace_field_id('ed')
	searching := CodeEditorConfig{
		...cfg
		search: CodeSearchState{
			query:   'value'
			current: 0
		}
	}
	assert code_search_command(searching, .find_next)?.state.current == 1
	assert code_search_command(searching, .find_previous)?.state.current == 2
	assert code_search_command(searching, .newline) == none
	escape := code_search_key(CodeEditorConfig{
		...searching
		search: CodeSearchState{
			...searching.search
			open: true
		}
	}, KeyEvent{ code: .escape })?
	assert !escape.state.open
	assert code_search_key(searching, KeyEvent{ code: .escape }) == none
	assert code_search_error(CodeSearchState{
		query:   '(a'
		options: CodeSearchOptions{
			regex: true
		}
	}).len > 0
	assert code_search_error(CodeSearchState{ query: '(a' }) == ''
}

// ── Folding and the gutter ────────────────────────────────────────────────

fn test_code_fold_ranges() {
	v := 'fn a() {\n\tx := "{"\n\tif y {\n\t\tz()\n\t}\n}\n'
	assert code_fold_ranges(v, .v) == [CodeFoldRange{0, 4}, CodeFoldRange{2, 3}]
	py := 'def f():\n    if x:\n        y()\n\n    return 1\nz = 2'
	assert code_fold_ranges(py, .python) == [CodeFoldRange{0, 4}, CodeFoldRange{1, 2}]
	md := '# A\ntext\n## B\nmore\n\n# C\nend'
	assert code_fold_ranges(md, .markdown) == [CodeFoldRange{0, 3}, CodeFoldRange{2, 3},
		CodeFoldRange{5, 6}]
	assert code_fold_ranges('{ }', .json).len == 0
	assert code_fold_ranges('a\nb', .plain).len == 0
}

fn test_code_editor_update_selects_lines_and_blocks() {
	cfg := editor_config(editor_v_sample)
	line := code_editor_update(cfg, code_editor_line_action('ed', 2))?
	assert line.selection == TextSelection{13, 25}
	assert line.focus == code_editor_text_id('ed')
	fold := code_editor_update(cfg, code_editor_fold_action('ed', 2))?
	assert fold.fold
	assert fold.selection.anchor == 13
	assert editor_v_sample.runes()[fold.selection.caret - 1] == `}`
	assert code_editor_update(cfg, code_editor_line_action('ed', 99)) == none
	assert code_editor_update(cfg, component_part_id('ed', 'line:02')) == none
	assert code_editor_update(cfg, component_part_id('ed', 'line:-1')) == none
	assert code_editor_update(cfg, code_editor_fold_action('ed', 0)) == none
	assert code_editor_update(CodeEditorConfig{
		...cfg
		folding: false
	}, code_editor_fold_action('ed', 2)) == none
	assert code_editor_update(cfg, 'other') == none
}

// ── The editor ────────────────────────────────────────────────────────────

fn test_code_editor_builds_a_gutter_and_a_rich_text_area() {
	cfg := CodeEditorConfig{
		...editor_config(editor_v_sample)
		selection:   TextSelection{14, 14}
		diagnostics: [CodeDiagnostic{
			start:    16
			end:      20
			severity: .error
			message:  'bad'
		}]
		decorations: [CodeDecoration{
			start: 0
			end:   6
		}]
	}
	el := code_editor(cfg)!
	validate_element_tree(el)!
	assert el.id == 'ed'
	area := editor_find(el, code_editor_text_id('ed'))?
	assert area.kind == .text_area
	assert area.disable_scroll
	assert area.text == editor_v_sample
	assert area.text_runs.map(it.text).join('') == editor_v_sample
	assert area.text_style.font_family == code_editor_font_family()
	assert editor_find(el, code_editor_scroll_id('ed'))?.kind == .scroll
	// Without soft wrap the text scrolls sideways in a scroll of its own.
	hscroll := editor_find(el, code_editor_hscroll_id('ed'))?
	assert hscroll.scroll_mode == .horizontal_only
	assert editor_count_ids(el, component_part_id('ed', 'line:')) == code_line_count(editor_v_sample)
	assert editor_count_ids(el, component_part_id('ed', 'fold:')) == 1
	assert editor_find(el, component_part_id('ed', 'search')) == none
	wrapped := code_editor(CodeEditorConfig{
		...cfg
		soft_wrap:    true
		line_numbers: false
		folding:      false
	})!
	assert editor_find(wrapped, code_editor_hscroll_id('ed')) == none
	assert editor_count_ids(wrapped, component_part_id('ed', 'line:')) == 0
	// The search bar floats in the editor while open.
	searching := code_editor(CodeEditorConfig{
		...cfg
		search: CodeSearchState{
			open:    true
			replace: true
			query:   'main'
		}
	})!
	bar := editor_find(searching, component_part_id('ed', 'search'))?
	assert bar.frame.x + bar.frame.width <= cfg.frame.width
	assert editor_find(searching, code_search_field_id('ed')) != none
	assert editor_find(searching, code_search_replace_field_id('ed')) != none
	// An application's own search UI: the matches still show, the bar does not.
	custom_ui := code_editor(CodeEditorConfig{
		...cfg
		search_bar: false
		search:     CodeSearchState{
			open:  true
			query: 'main'
		}
	})!
	assert editor_find(custom_ui, component_part_id('ed', 'search')) == none
	custom_area := editor_find(custom_ui, code_editor_text_id('ed'))?
	assert custom_area.text_runs.any(it.style.background_color == cfg.theme.match_background)
	read_only_bar := code_editor(CodeEditorConfig{
		...cfg
		read_only: true
		search:    CodeSearchState{
			open:    true
			replace: true
			query:   'main'
		}
	})!
	assert editor_find(read_only_bar, code_search_replace_field_id('ed')) == none
	assert editor_find(read_only_bar, code_editor_text_id('ed'))?.readonly
	assert code_editor(CodeEditorConfig{ frame: rect(0, 0, 10, 10) }) or { Element{} } == Element{}
	assert code_editor(CodeEditorConfig{
		id:    'x'
		frame: rect(0, 0, -1, 10)
	}) or { Element{} } == Element{}
}

fn test_code_editor_geometry() {
	cfg := CodeEditorConfig{
		...editor_config('a\n\tbc\nlonger line here')
		selection: TextSelection{5, 5}
	}
	m := code_editor_metrics(cfg)
	assert m.line_height > 0 && m.char_width > 0
	caret := code_editor_caret_rect(cfg)
	first := code_editor_range_rect(cfg, CodeRange{0, 1})
	// Line 2, after the tab and `b`.
	assert caret.y == first.y + 2 * m.line_height - m.line_height
	assert caret.x > first.x
	assert caret.height == m.line_height
	requests := code_editor_reveal(cfg, CodeRange{5, 5})
	assert requests.len == 2
	assert requests[0].id == code_editor_scroll_id('ed')
	assert requests[1].id == code_editor_hscroll_id('ed')
	assert code_editor_reveal(CodeEditorConfig{
		...cfg
		soft_wrap: true
	}, CodeRange{5, 5}).len == 1
	// Sizing to content: one more line is one more line height.
	one := code_editor_content_height(editor_config('a'))
	two := code_editor_content_height(editor_config('a\nb'))
	assert two - one >= m.line_height - 1 && two - one <= m.line_height + 1
	// Soft wrap breaks a long line into rows at a blank.
	narrow := CodeEditorConfig{
		...editor_config('word '.repeat(40))
		frame:     rect(0, 0, 200, 300)
		soft_wrap: true
	}
	assert code_editor_row_count(narrow) > 1
	assert code_editor_row_count(CodeEditorConfig{
		...narrow
		soft_wrap: false
	}) == 1
}

fn test_code_editor_wrap_rows_break_at_blanks() {
	m := CodeEditorMetrics{
		line_height: 10
		char_width:  1
		tab_advance: 1
	}
	runes := 'aaa bbb cccccccc'.runes()
	rows := code_editor_wrap_rows(runes, 0, 0, runes.len, 7, m)
	assert rows.map(runes[it.start..it.end].string()) == ['aaa bbb', 'ccccccc', 'c']
	tabs := CodeEditorMetrics{
		char_width: 2
		tab_stop:   8
	}
	assert tabs.advance(0, `\t`) == 8
	assert tabs.advance(3, `\t`) == 8
	assert tabs.advance(8, `\t`) == 16
	assert tabs.advance(0, `x`) == 2
	assert tabs.advance(0, `漢`) == 4
}

// ── Completions ───────────────────────────────────────────────────────────

fn editor_items() []CodeCompletionItem {
	return [
		CodeCompletionItem{
			label: 'count'
			kind:  .field
		},
		CodeCompletionItem{
			label:  'increment'
			kind:   .method
			insert: 'increment()'
		},
		CodeCompletionItem{
			label: 'Counter'
			kind:  .type
		},
		CodeCompletionItem{
			label: 'reset'
			kind:  .method
		},
	]
}

fn editor_completion(marked string, state CodeCompletionState) CodeCompletionConfig {
	text, sel := editor_sel(marked)
	return CodeCompletionConfig{
		editor: CodeEditorConfig{
			...editor_config(text)
			selection: sel
		}
		origin: rect(10, 20, 640, 360)
		window: rect(0, 0, 900, 700)
		items:  editor_items()
		state:  state
	}
}

fn test_code_completion_filters_by_the_prefix() {
	text, sel := editor_sel('c.cou|')
	prefix := code_completion_prefix(text, sel, editor_settings(.v))
	assert prefix == CodeRange{2, 5}
	labels := code_completion_filter(editor_items(), 'cou').map(it.label)
	assert labels == ['count', 'Counter']
	assert code_completion_filter(editor_items(), 'Cou').map(it.label) == ['Counter', 'count']
	assert code_completion_filter(editor_items(), 'inc').map(it.label) == ['increment']
	assert code_completion_filter(editor_items(), 'rst').map(it.label) == ['reset']
	assert code_completion_filter(editor_items(), '').len == 4
	assert code_completion_filter(editor_items(), 'zz').len == 0
}

fn test_code_completion_keys_accept_and_close() {
	closed := editor_completion('c.|', CodeCompletionState{})
	shown := code_completion_show(closed)?
	assert shown.state.open && shown.state.active == 0
	read_only := CodeCompletionConfig{
		...closed
		editor: CodeEditorConfig{
			...closed.editor
			read_only: true
		}
	}
	assert code_completion_show(read_only) == none
	assert code_completion_show(editor_completion('c.zz|', CodeCompletionState{})) == none
	open := editor_completion('c.|', CodeCompletionState{
		open:   true
		active: 0
	})
	assert code_completion_key(open, KeyEvent{ code: .up })?.state.active == 3
	assert code_completion_key(open, KeyEvent{ code: .down })?.state.active == 1
	assert code_completion_key(open, KeyEvent{ code: .page_down })?.state.active == 3
	assert !code_completion_key(open, KeyEvent{ code: .escape })?.state.open
	assert code_completion_key(open, KeyEvent{ code: .a }) == none
	assert code_completion_key(closed, KeyEvent{ code: .down }) == none
	second := editor_completion('c.in|', CodeCompletionState{
		open: true
	})
	accepted := code_completion_key(second, KeyEvent{ code: .enter })?
	assert accepted.accepted
	assert accepted.item.label == 'increment'
	edit := accepted.edit?
	assert editor_mark(edit.text, edit.selection) == 'c.increment()|'
	assert !accepted.state.open
	by_text := code_completion_text_key(second, 'text:${code_editor_text_id('ed')}:tab')?
	assert by_text.edit?.text == 'c.increment()'
	assert code_completion_text_key(second, 'text:${code_editor_text_id('ed')}:backspace') == none
	clicked := code_completion_update(open, component_part_id('ed', 'completion:2'))?
	assert clicked.edit?.text == 'c.Counter'
	assert code_completion_update(open, component_part_id('ed', 'completion:9')) == none
	assert code_completion_update(open, component_part_id('ed', 'completion:01')) == none
	assert code_completion_update(closed, component_part_id('ed', 'completion:0')) == none
	// After an edit the menu stays open while the prefix matches.
	assert code_completion_sync(editor_completion('c.res|', CodeCompletionState{
		open:   true
		active: 3
	})) == CodeCompletionState{
		open:   true
		active: 0
	}
	assert !code_completion_sync(editor_completion('c.zz|', CodeCompletionState{ open: true })).open
	assert !code_completion_sync(editor_completion('c.[re]', CodeCompletionState{ open: true })).open
}

fn test_code_completion_popup_opens_at_the_caret() {
	open := editor_completion('c.\n\tco|', CodeCompletionState{
		open: true
	})
	el := code_completion(open)!
	validate_element_tree(el)!
	assert !el.hidden
	assert editor_count_ids(el, component_part_id('ed', 'completion:')) == 2
	anchor := code_completion_anchor(open)
	assert el.frame.y >= anchor.y + anchor.height
	assert el.frame.x + el.frame.width <= open.window.width
	scrolled := code_completion_anchor(CodeCompletionConfig{
		...open
		scroll_offset: 10
	})
	assert scrolled.y == anchor.y - 10
	closed := code_completion(editor_completion('c.|', CodeCompletionState{}))!
	assert closed.hidden
	none_match := code_completion(editor_completion('c.zz|', CodeCompletionState{ open: true }))!
	assert none_match.hidden
}
