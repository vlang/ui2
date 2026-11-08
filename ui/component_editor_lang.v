module ui2

// Languages the code editor knows, their editing rules, and a small tokenizer
// per language family for syntax highlighting. Everything here is pure: text
// in, tokens or rules out, so it is tested without a window.
//
// Offsets are rune offsets, as in TextSelection, so they stay valid for UTF-8
// text. Native text-area selections are UTF-16; convert with
// code_editor_selection_from_native and code_edit_native.

pub enum CodeLanguage {
	plain
	v
	rust
	javascript
	typescript
	python
	go
	json
	toml
	markdown
	shell
}

// code_languages lists the languages with highlighting and editing rules, plain
// text first.
pub fn code_languages() []CodeLanguage {
	return [CodeLanguage.plain, .v, .rust, .javascript, .typescript, .python, .go, .json, .toml,
		.markdown, .shell]
}

// code_language reads a language from its name or a common alias: `v`, `rs`,
// `js`, `jsx`, `ts`, `tsx`, `py`, `pyi`, `golang`, `jsonc`, `md`, `sh`, `bash`,
// `zsh`, ... Case is ignored. Anything unknown is plain text, as an unknown
// language gets the default rules upstream.
pub fn code_language(name string) CodeLanguage {
	return match name.trim_space().to_lower() {
		'v', 'vlang', 'vsh', 'vv' { .v }
		'rust', 'rs' { .rust }
		'javascript', 'js', 'jsx', 'mjs', 'cjs', 'node' { .javascript }
		'typescript', 'ts', 'tsx', 'mts', 'cts' { .typescript }
		'python', 'py', 'pyi', 'python3', 'py3' { .python }
		'go', 'golang' { .go }
		'json', 'jsonc', 'json5' { .json }
		'toml' { .toml }
		'markdown', 'md', 'mdx' { .markdown }
		'shell', 'sh', 'bash', 'zsh', 'ksh', 'shellscript', 'console' { .shell }
		else { .plain }
	}
}

// code_language_from_path picks a language from a file name's extension (or a
// well-known file name such as `Cargo.lock` or `.bashrc`).
pub fn code_language_from_path(path string) CodeLanguage {
	base := path.all_after_last('/').all_after_last('\\')
	match base.to_lower() {
		'cargo.lock', 'pipfile', 'poetry.lock' { return .toml }
		'.bashrc', '.zshrc', '.profile', '.bash_profile', 'makefile.sh' { return .shell }
		'v.mod' { return .v }
		else {}
	}
	if !base.contains('.') {
		return .plain
	}
	return code_language(base.all_after_last('.'))
}

// id is the canonical lowercase name, the one code_language reads back.
pub fn (language CodeLanguage) id() string {
	return match language {
		.plain { 'text' }
		.v { 'v' }
		.rust { 'rust' }
		.javascript { 'javascript' }
		.typescript { 'typescript' }
		.python { 'python' }
		.go { 'go' }
		.json { 'json' }
		.toml { 'toml' }
		.markdown { 'markdown' }
		.shell { 'shell' }
	}
}

// title is the name to show a person, for a language menu or a status bar.
pub fn (language CodeLanguage) title() string {
	return match language {
		.plain { 'Plain Text' }
		.v { 'V' }
		.rust { 'Rust' }
		.javascript { 'JavaScript' }
		.typescript { 'TypeScript' }
		.python { 'Python' }
		.go { 'Go' }
		.json { 'JSON' }
		.toml { 'TOML' }
		.markdown { 'Markdown' }
		.shell { 'Shell' }
	}
}

// CodePair is a pair of delimiters; either side may be several characters.
pub struct CodePair {
pub:
	open  string
	close string
}

// CodeLanguageRules are a language's editing rules, after GPUI Kit's
// LanguageConfig: the structural brackets Enter indents after and splits, the
// pairs typing closes automatically, which characters may follow a pair for it
// to be closed, the comment tokens, and the line endings that open an indented
// block (Python's colon).
pub struct CodeLanguageRules {
pub:
	brackets   []CodePair
	auto_pairs []CodePair
	// auto_close_before lists the characters a pair may be closed in front of,
	// besides whitespace and the end of the text.
	auto_close_before string = ';:.,=}])>'
	line_comment      string   // `//` or `#`; empty when the language has none.
	block_comment     CodePair // `/*` `*/`, `<!--` `-->`; empty when none.
	// indent_after lists the line endings, besides an opening bracket, after
	// which Enter indents one level (Python and YAML-like `:`).
	indent_after []string
	// word_extra lists characters that are part of a word besides letters,
	// digits and `_` (`$` in shell and JavaScript, `-` in TOML keys).
	word_extra string
}

fn code_default_brackets() []CodePair {
	return [CodePair{'(', ')'}, CodePair{'[', ']'}, CodePair{'{', '}'}]
}

fn code_default_pairs() []CodePair {
	return [CodePair{'(', ')'}, CodePair{'[', ']'}, CodePair{'{', '}'}, CodePair{'"', '"'},
		CodePair{"'", "'"}]
}

// code_language_rules returns a language's default editing rules. Plain text
// has neither brackets nor automatic pairs; JSON closes only its own
// delimiters; Python also indents after a trailing colon.
pub fn code_language_rules(language CodeLanguage) CodeLanguageRules {
	return match language {
		.plain {
			CodeLanguageRules{}
		}
		.v {
			CodeLanguageRules{
				brackets:      code_default_brackets()
				auto_pairs:    [CodePair{'(', ')'}, CodePair{'[', ']'}, CodePair{'{', '}'},
					CodePair{'"', '"'}, CodePair{"'", "'"}, CodePair{'`', '`'}]
				line_comment:  '//'
				block_comment: CodePair{'/*', '*/'}
			}
		}
		.rust {
			CodeLanguageRules{
				brackets:      code_default_brackets()
				auto_pairs:    [CodePair{'(', ')'}, CodePair{'[', ']'}, CodePair{'{', '}'},
					CodePair{'"', '"'}]
				line_comment:  '//'
				block_comment: CodePair{'/*', '*/'}
			}
		}
		.javascript, .typescript {
			CodeLanguageRules{
				brackets:      code_default_brackets()
				auto_pairs:    [CodePair{'(', ')'}, CodePair{'[', ']'}, CodePair{'{', '}'},
					CodePair{'"', '"'}, CodePair{"'", "'"}, CodePair{'`', '`'}]
				line_comment:  '//'
				block_comment: CodePair{'/*', '*/'}
				word_extra:    '$'
			}
		}
		.go {
			CodeLanguageRules{
				brackets:      code_default_brackets()
				auto_pairs:    [CodePair{'(', ')'}, CodePair{'[', ']'}, CodePair{'{', '}'},
					CodePair{'"', '"'}, CodePair{"'", "'"}, CodePair{'`', '`'}]
				line_comment:  '//'
				block_comment: CodePair{'/*', '*/'}
			}
		}
		.python {
			CodeLanguageRules{
				brackets:     code_default_brackets()
				auto_pairs:   code_default_pairs()
				line_comment: '#'
				indent_after: [':']
			}
		}
		.json {
			CodeLanguageRules{
				brackets:   [CodePair{'{', '}'}, CodePair{'[', ']'}]
				auto_pairs: [CodePair{'{', '}'}, CodePair{'[', ']'}, CodePair{'"', '"'}]
			}
		}
		.toml {
			CodeLanguageRules{
				brackets:     [CodePair{'[', ']'}, CodePair{'{', '}'}]
				auto_pairs:   [CodePair{'[', ']'}, CodePair{'{', '}'}, CodePair{'"', '"'},
					CodePair{"'", "'"}]
				line_comment: '#'
				word_extra:   '-'
			}
		}
		.markdown {
			CodeLanguageRules{
				brackets:      [CodePair{'(', ')'}, CodePair{'[', ']'}]
				auto_pairs:    [CodePair{'(', ')'}, CodePair{'[', ']'}, CodePair{'`', '`'}]
				block_comment: CodePair{'<!--', '-->'}
			}
		}
		.shell {
			CodeLanguageRules{
				brackets:     code_default_brackets()
				auto_pairs:   code_default_pairs()
				line_comment: '#'
				word_extra:   '$'
			}
		}
	}
}

// CodeTokenKind names what a stretch of source is, after the capture names of
// GPUI Kit's highlight themes.
pub enum CodeTokenKind {
	plain
	comment
	comment_doc
	keyword
	string
	string_escape
	number
	constant // true, false, null, nil, ALL_CAPS names
	type
	function
	property
	attribute // @[attr], #[attr], @decorator, #flag
	operator
	punctuation
	variable_special // self, this, $VAR, lifetimes
	embedded         // ${...} interpolation delimiters
	title            // Markdown headings, TOML tables
	emphasis
	strong
	link_text
	link_uri
	code_span // Markdown code spans and fenced blocks without a known language
	tag       // Markdown list markers, block quotes and rules
}

// CodeToken is a stretch of runes [start, end) of one kind. Text no token
// covers is plain.
pub struct CodeToken {
pub:
	start int
	end   int
	kind  CodeTokenKind
}

// code_tokens splits text into highlight tokens for a language, in order and
// without overlap. Plain text gives none.
pub fn code_tokens(text string, language CodeLanguage) []CodeToken {
	runes := text.runes()
	mut lexer := CodeLexer{
		src: runes
	}
	lexer.run(language, 0, runes.len)
	return code_merge_tokens(lexer.tokens)
}

// code_merge_tokens joins touching tokens of the same kind, which keeps the
// run count (and so the work a backend does per run) down.
fn code_merge_tokens(tokens []CodeToken) []CodeToken {
	mut out := []CodeToken{cap: tokens.len}
	for token in tokens {
		if token.end <= token.start {
			continue
		}
		if out.len > 0 && out[out.len - 1].kind == token.kind && out[out.len - 1].end == token.start {
			out[out.len - 1] = CodeToken{out[out.len - 1].start, token.end, token.kind}
			continue
		}
		out << token
	}
	return out
}

struct CodeLexer {
	src []rune
mut:
	tokens []CodeToken
}

fn (mut l CodeLexer) add(start int, end int, kind CodeTokenKind) {
	if end > start && kind != .plain {
		l.tokens << CodeToken{start, end, kind}
	}
}

fn (l &CodeLexer) at(i int) rune {
	return if i >= 0 && i < l.src.len { l.src[i] } else { rune(0) }
}

fn (l &CodeLexer) starts(i int, s string) bool {
	runes := s.runes()
	if i < 0 || i + runes.len > l.src.len {
		return false
	}
	for k, r in runes {
		if l.src[i + k] != r {
			return false
		}
	}
	return true
}

fn (l &CodeLexer) line_end(i int, limit int) int {
	mut j := i
	for j < limit && l.src[j] != `\n` {
		j++
	}
	return j
}

fn (l &CodeLexer) next_non_space(i int, limit int) int {
	mut j := i
	for j < limit && (l.src[j] == ` ` || l.src[j] == `\t`) {
		j++
	}
	return j
}

fn (l &CodeLexer) word(start int, limit int) string {
	mut j := start
	for j < limit && code_ident_rune(l.src[j]) {
		j++
	}
	return l.src[start..j].string()
}

fn code_ident_start(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || r == `_` || r >= 0x80
}

fn code_ident_rune(r rune) bool {
	return code_ident_start(r) || (r >= `0` && r <= `9`)
}

fn code_digit(r rune) bool {
	return r >= `0` && r <= `9`
}

fn code_hex_digit(r rune) bool {
	return code_digit(r) || (r >= `a` && r <= `f`) || (r >= `A` && r <= `F`)
}

fn code_all_caps(word string) bool {
	if word.len < 2 {
		return false
	}
	mut letters := 0
	for ch in word.bytes() {
		if ch >= `a` && ch <= `z` {
			return false
		}
		if ch >= `A` && ch <= `Z` {
			letters++
		}
	}
	return letters > 0
}

fn code_capitalized(word string) bool {
	return word.len > 0 && word[0] >= `A` && word[0] <= `Z`
}

fn (mut l CodeLexer) run(language CodeLanguage, start int, end int) {
	match language {
		.plain {}
		.json { l.lex_json(start, end) }
		.toml { l.lex_toml(start, end) }
		.markdown { l.lex_markdown(start, end) }
		.shell { l.lex_shell(start, end) }
		.python { l.lex_python(start, end) }
		else { l.lex_c_like(code_c_spec(language), start, end) }
	}
}

// ── C-like languages: V, Rust, JavaScript, TypeScript, Go ─────────────────

struct CodeCSpec {
	language       CodeLanguage
	keywords       []string
	types          []string
	constants      []string
	specials       []string
	declarations   []string // keywords followed by a type name
	function_words []string // keywords followed by a function name
	nested_comment bool
}

const code_v_keywords = ['as', 'asm', 'assert', 'atomic', 'break', 'const', 'continue', 'defer',
	'else', 'enum', 'fn', 'for', 'go', 'goto', 'if', 'implements', 'import', 'in', 'interface',
	'is', 'isreftype', 'lock', 'match', 'module', 'mut', 'or', 'pub', 'return', 'rlock', 'select',
	'shared', 'sizeof', 'spawn', 'static', 'struct', 'type', 'typeof', 'union', 'unsafe', 'volatile',
	'__global', '__offsetof']
const code_v_types = ['bool', 'string', 'i8', 'i16', 'int', 'i32', 'i64', 'isize', 'u8', 'u16',
	'u32', 'u64', 'usize', 'f32', 'f64', 'rune', 'voidptr', 'byteptr', 'charptr', 'byte', 'map',
	'chan', 'thread', 'any']
const code_rust_keywords = ['as', 'async', 'await', 'break', 'const', 'continue', 'crate', 'dyn',
	'else', 'enum', 'extern', 'fn', 'for', 'if', 'impl', 'in', 'let', 'loop', 'match', 'mod', 'move',
	'mut', 'pub', 'ref', 'return', 'static', 'struct', 'super', 'trait', 'type', 'unsafe', 'use',
	'where', 'while', 'yield']
const code_rust_types = ['i8', 'i16', 'i32', 'i64', 'i128', 'isize', 'u8', 'u16', 'u32', 'u64',
	'u128', 'usize', 'f32', 'f64', 'bool', 'char', 'str']
const code_js_keywords = ['async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
	'debugger', 'default', 'delete', 'do', 'else', 'export', 'extends', 'finally', 'for', 'from',
	'function', 'get', 'if', 'import', 'in', 'instanceof', 'let', 'new', 'of', 'return', 'set',
	'static', 'super', 'switch', 'throw', 'try', 'typeof', 'var', 'void', 'while', 'with', 'yield']
const code_ts_keywords = ['abstract', 'as', 'asserts', 'declare', 'enum', 'implements', 'infer',
	'interface', 'is', 'keyof', 'module', 'namespace', 'override', 'private', 'protected', 'public',
	'readonly', 'satisfies', 'type']
const code_ts_types = ['string', 'number', 'boolean', 'any', 'unknown', 'never', 'void', 'object',
	'symbol', 'bigint']
const code_go_keywords = ['break', 'case', 'chan', 'const', 'continue', 'default', 'defer', 'else',
	'fallthrough', 'for', 'func', 'go', 'goto', 'if', 'import', 'interface', 'map', 'package',
	'range', 'return', 'select', 'struct', 'switch', 'type', 'var']
const code_go_types = ['bool', 'byte', 'complex64', 'complex128', 'error', 'float32', 'float64',
	'int', 'int8', 'int16', 'int32', 'int64', 'rune', 'string', 'uint', 'uint8', 'uint16', 'uint32',
	'uint64', 'uintptr', 'any']

fn code_c_spec(language CodeLanguage) CodeCSpec {
	return match language {
		.v {
			CodeCSpec{
				language:       language
				keywords:       code_v_keywords
				types:          code_v_types
				constants:      ['true', 'false', 'none', 'nil']
				specials:       []string{}
				declarations:   ['struct', 'enum', 'interface', 'type', 'union']
				function_words: ['fn']
				nested_comment: true
			}
		}
		.rust {
			CodeCSpec{
				language:       language
				keywords:       code_rust_keywords
				types:          code_rust_types
				constants:      ['true', 'false']
				specials:       ['self', 'Self']
				declarations:   ['struct', 'enum', 'trait', 'type', 'union', 'impl']
				function_words: ['fn']
				nested_comment: true
			}
		}
		.typescript {
			mut keywords := code_js_keywords.clone()
			keywords << code_ts_keywords
			CodeCSpec{
				language:       language
				keywords:       keywords
				types:          code_ts_types
				constants:      ['true', 'false', 'null', 'undefined', 'NaN', 'Infinity']
				specials:       ['this']
				declarations:   ['class', 'interface', 'type', 'enum', 'extends', 'implements',
					'new']
				function_words: ['function']
			}
		}
		.go {
			CodeCSpec{
				language:       language
				keywords:       code_go_keywords
				types:          code_go_types
				constants:      ['true', 'false', 'nil', 'iota']
				specials:       []string{}
				declarations:   ['type']
				function_words: ['func']
			}
		}
		else {
			CodeCSpec{
				language:       .javascript
				keywords:       code_js_keywords
				types:          []string{}
				constants:      ['true', 'false', 'null', 'undefined', 'NaN', 'Infinity']
				specials:       ['this']
				declarations:   ['class', 'extends', 'new']
				function_words: ['function']
			}
		}
	}
}

fn (mut l CodeLexer) lex_c_like(spec CodeCSpec, start int, end int) {
	mut i := start
	mut after_dot := false
	mut pending := CodeTokenKind.plain // what the next identifier is, after `fn` or `struct`
	for i < end {
		c := l.src[i]
		if c == ` ` || c == `\t` || c == `\r` || c == `\n` {
			i++
			continue
		}
		// Comments.
		if l.starts(i, '//') {
			j := l.line_end(i, end)
			doc := l.starts(i, '///') || l.starts(i, '//!')
			l.add(i, j, if doc { CodeTokenKind.comment_doc } else { CodeTokenKind.comment })
			i = j
			continue
		}
		if l.starts(i, '/*') {
			j := l.block_comment_end(i, end, '/*', '*/', spec.nested_comment)
			doc := l.starts(i, '/**') && !l.starts(i, '/**/')
			l.add(i, j, if doc { CodeTokenKind.comment_doc } else { CodeTokenKind.comment })
			i = j
			continue
		}
		// Attributes and directives.
		if spec.language == .v && l.starts(i, '@[') {
			j := l.bracket_end(i + 1, end, `[`, `]`)
			l.add(i, j, .attribute)
			i = j
			continue
		}
		if spec.language == .v && c == `#` && l.line_start_blank(i) {
			j := l.line_end(i, end)
			l.add(i, j, .attribute)
			i = j
			continue
		}
		if spec.language == .rust && (l.starts(i, '#[') || l.starts(i, '#![')) {
			j := l.bracket_end(if l.at(i + 1) == `!` { i + 2 } else { i + 1 }, end, `[`, `]`)
			l.add(i, j, .attribute)
			i = j
			continue
		}
		if (spec.language == .typescript || spec.language == .javascript) && c == `@`
			&& code_ident_start(l.at(i + 1)) {
			mut j := i + 1
			for j < end && (code_ident_rune(l.src[j]) || l.src[j] == `.`) {
				j++
			}
			l.add(i, j, .attribute)
			i = j
			continue
		}
		if spec.language == .v && c == `$` && code_ident_start(l.at(i + 1)) {
			// Compile-time `$if`, `$for`, `$embed_file`, ...
			mut j := i + 1
			for j < end && code_ident_rune(l.src[j]) {
				j++
			}
			l.add(i, j, .keyword)
			i = j
			continue
		}
		// Strings and characters.
		if spec.language == .v && (c == `r` || c == `c`) && (l.at(i + 1) == `'`
			|| l.at(i + 1) == `"`) && (i == start || !code_ident_rune(l.src[i - 1])) {
			raw := c == `r`
			j := l.lex_string(i + 1, end, l.src[i + 1], !raw, false, spec.language)
			l.add(i, i + 1, .string)
			i = j
			continue
		}
		if spec.language == .rust && (c == `r` || c == `b`) && (l.at(i + 1) == `"`
			|| (l.at(i + 1) == `#` && (l.at(i + 2) == `"` || l.at(i + 2) == `#`))
			|| (c == `b` && l.at(i + 1) == `r`)) && (i == start || !code_ident_rune(l.src[i - 1])) {
			j := l.lex_rust_raw_string(i, end)
			if j > i {
				i = j
				continue
			}
		}
		if c == `"` {
			i = l.lex_string(i, end, c, true, false, spec.language)
			continue
		}
		if c == `'` {
			if spec.language == .rust {
				i = l.lex_rust_quote(i, end)
				continue
			}
			if spec.language == .go {
				i = l.lex_string(i, end, c, true, false, spec.language)
				continue
			}
			i = l.lex_string(i, end, c, true, false, spec.language)
			continue
		}
		if c == `\`` {
			if spec.language == .go {
				// A raw string: no escapes, may span lines.
				mut j := i + 1
				for j < end && l.src[j] != `\`` {
					j++
				}
				j = if j < end { j + 1 } else { j }
				l.add(i, j, .string)
				i = j
				continue
			}
			if spec.language == .v {
				// A character literal.
				mut j := i + 1
				for j < end && l.src[j] != `\`` && l.src[j] != `\n` {
					j += if l.src[j] == `\\` { 2 } else { 1 }
				}
				j = if j < end && l.src[j] == `\`` { j + 1 } else { j }
				l.add(i, j, .string)
				i = j
				continue
			}
			// A template literal with ${} interpolation.
			i = l.lex_string(i, end, c, true, true, spec.language)
			continue
		}
		// Numbers.
		if code_digit(c) || (c == `.` && code_digit(l.at(i + 1)) && !after_dot) {
			j := l.number_end(i, end)
			l.add(i, j, .number)
			i = j
			after_dot = false
			pending = .plain
			continue
		}
		// Identifiers.
		if code_ident_start(c) {
			mut j := i
			for j < end && code_ident_rune(l.src[j]) {
				j++
			}
			w := l.src[i..j].string()
			mut kind := CodeTokenKind.plain
			next := l.next_non_space(j, end)
			if after_dot {
				kind = if l.at(next) == `(` {
					CodeTokenKind.function
				} else {
					CodeTokenKind.property
				}
			} else if w in spec.keywords {
				kind = .keyword
			} else if w in spec.constants {
				kind = .constant
			} else if w in spec.specials {
				kind = .variable_special
			} else if pending != .plain {
				kind = pending
			} else if w in spec.types {
				kind = .type
			} else if spec.language == .rust && l.at(j) == `!` && l.at(j + 1) != `=` {
				// A macro call: `println!`, `vec!`.
				kind = .function
				j++
			} else if l.at(next) == `(` {
				kind = if code_capitalized(w) && spec.language != .go && spec.language != .v {
					CodeTokenKind.type
				} else {
					CodeTokenKind.function
				}
			} else if code_all_caps(w) {
				kind = .constant
			} else if code_capitalized(w) {
				kind = .type
			}
			l.add(i, j, kind)
			pending = if w in spec.function_words {
				CodeTokenKind.function
			} else if w in spec.declarations {
				CodeTokenKind.type
			} else if w == 'mut' || w == 'pub' || w == 'export' || w == 'async' || w == 'default' {
				pending
			} else {
				CodeTokenKind.plain
			}
			after_dot = false
			i = j
			continue
		}
		// V method receivers `fn (mut a App) name(` and Go `func (a *App) Name(`
		// keep the function name pending across the parenthesis.
		if c == `(` && pending == .function {
			j := l.bracket_end(i, end, `(`, `)`)
			l.lex_c_like(spec, i + 1, math_max_int(j - 1, i + 1))
			l.add(i, i + 1, .punctuation)
			if j - 1 > i && l.at(j - 1) == `)` {
				l.add(j - 1, j, .punctuation)
			}
			i = j
			continue
		}
		after_dot = c == `.` && l.at(i + 1) != `.`
		if c == `?` && l.at(i + 1) == `.` {
			after_dot = true
			l.add(i, i + 2, .operator)
			i += 2
			continue
		}
		if c != `.` {
			pending = if c == `[` || c == `]` || c == `*` || c == `&` || c == `<` || c == `>`
				|| c == `,` || c == `?` || c == `!` {
				pending
			} else {
				CodeTokenKind.plain
			}
		}
		l.add(i, i + 1, code_symbol_kind(c))
		i++
	}
}

fn math_max_int(a int, b int) int {
	return if a > b { a } else { b }
}

fn code_symbol_kind(c rune) CodeTokenKind {
	return match c {
		`(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `.`, `:` { .punctuation }
		`+`, `-`, `*`, `/`, `%`, `=`, `<`, `>`, `!`, `&`, `|`, `^`, `~`, `?` { .operator }
		else { .plain }
	}
}

fn (l &CodeLexer) line_start_blank(i int) bool {
	mut j := i - 1
	for j >= 0 && (l.src[j] == ` ` || l.src[j] == `\t`) {
		j--
	}
	return j < 0 || l.src[j] == `\n`
}

fn (l &CodeLexer) block_comment_end(i int, end int, open string, close string, nested bool) int {
	open_len := open.runes().len
	close_len := close.runes().len
	mut depth := 1
	mut j := i + open_len
	for j < end {
		if l.starts(j, close) {
			depth--
			j += close_len
			if depth == 0 || !nested {
				return j
			}
			continue
		}
		if nested && l.starts(j, open) {
			depth++
			j += open_len
			continue
		}
		j++
	}
	return end
}

// bracket_end returns the index just past the bracket matching the one at i,
// or end.
fn (l &CodeLexer) bracket_end(i int, end int, open rune, close rune) int {
	mut depth := 0
	mut j := i
	for j < end {
		r := l.src[j]
		if r == open {
			depth++
		} else if r == close {
			depth--
			if depth == 0 {
				return j + 1
			}
		} else if r == `\n` && open == `[` {
			// Attributes do not span lines here; stop rather than run away.
			return j
		}
		j++
	}
	return end
}

fn (l &CodeLexer) number_end(i int, end int) int {
	mut j := i
	if l.at(j) == `0` && (l.at(j + 1) == `x` || l.at(j + 1) == `X`) {
		j += 2
		for j < end && (code_hex_digit(l.src[j]) || l.src[j] == `_`) {
			j++
		}
	} else if l.at(j) == `0` && (l.at(j + 1) == `b` || l.at(j + 1) == `B` || l.at(j + 1) == `o`
		|| l.at(j + 1) == `O`) {
		j += 2
		for j < end && (code_digit(l.src[j]) || l.src[j] == `_`) {
			j++
		}
	} else {
		for j < end && (code_digit(l.src[j]) || l.src[j] == `_`) {
			j++
		}
		if j < end && l.src[j] == `.` && code_digit(l.at(j + 1)) {
			j++
			for j < end && (code_digit(l.src[j]) || l.src[j] == `_`) {
				j++
			}
		}
		if j < end && (l.src[j] == `e` || l.src[j] == `E`) && (code_digit(l.at(j + 1))
			|| ((l.at(j + 1) == `+` || l.at(j + 1) == `-`) && code_digit(l.at(j + 2)))) {
			j += 2
			for j < end && code_digit(l.src[j]) {
				j++
			}
		}
	}
	// Type suffixes such as `u8`, `f32`, `n`, `L`.
	for j < end && code_ident_rune(l.src[j]) {
		j++
	}
	return j
}

// lex_string tokenizes a quoted string starting at the quote at i: escapes when
// `escapes`, and `${...}` interpolation (plus V's `$name`) when the language
// interpolates in this kind of string. It returns the index past the closing
// quote; an unterminated string ends at the line end, or at `end` for strings
// that span lines.
fn (mut l CodeLexer) lex_string(i int, end int, quote rune, escapes bool, multiline bool, language CodeLanguage) int {
	interpolates := (language == .v && quote != `\``) || ((language == .javascript
		|| language == .typescript) && quote == `\``)
	spans_lines := multiline || language == .v
	mut seg := i
	mut j := i + 1
	for j < end {
		r := l.src[j]
		if r == quote {
			j++
			l.add(seg, j, .string)
			return j
		}
		if r == `\n` && !spans_lines {
			l.add(seg, j, .string)
			return j
		}
		if escapes && r == `\\` && j + 1 < end {
			l.add(seg, j, .string)
			esc := l.escape_end(j, end)
			l.add(j, esc, .string_escape)
			j = esc
			seg = j
			continue
		}
		if interpolates && r == `$` && l.at(j + 1) == `{` {
			l.add(seg, j, .string)
			close := l.bracket_end(j + 1, end, `{`, `}`)
			l.add(j, j + 2, .embedded)
			inner_end := if close > j + 2 && l.at(close - 1) == `}` { close - 1 } else { close }
			l.run(language, j + 2, inner_end)
			if inner_end < close {
				l.add(inner_end, close, .embedded)
			}
			j = close
			seg = j
			continue
		}
		if interpolates && language == .v && r == `$` && code_ident_start(l.at(j + 1)) {
			l.add(seg, j, .string)
			mut k := j + 1
			for k < end && (code_ident_rune(l.src[k]) || (l.src[k] == `.`
				&& code_ident_start(l.at(k + 1)))) {
				k++
			}
			l.add(j, j + 1, .embedded)
			l.add(j + 1, k, .variable_special)
			j = k
			seg = j
			continue
		}
		j++
	}
	l.add(seg, end, .string)
	return end
}

fn (l &CodeLexer) escape_end(i int, end int) int {
	// i is at the backslash.
	next := l.at(i + 1)
	mut j := i + 2
	if next == `x` {
		for j < end && j < i + 4 && code_hex_digit(l.src[j]) {
			j++
		}
	} else if next == `u` || next == `U` {
		if l.at(j) == `{` {
			for j < end && l.src[j] != `}` && l.src[j] != `\n` {
				j++
			}
			if j < end && l.src[j] == `}` {
				j++
			}
		} else {
			limit := if next == `u` { i + 6 } else { i + 10 }
			for j < end && j < limit && code_hex_digit(l.src[j]) {
				j++
			}
		}
	} else if code_digit(next) {
		for j < end && j < i + 4 && code_digit(l.src[j]) {
			j++
		}
	}
	return if j > end { end } else { j }
}

// lex_rust_quote tells a char literal ('a', '\n') from a lifetime ('a).
fn (mut l CodeLexer) lex_rust_quote(i int, end int) int {
	if l.at(i + 1) == `\\` {
		mut j := l.escape_end(i + 1, end)
		if l.at(j) == `'` {
			j++
		}
		l.add(i, i + 1, .string)
		l.add(i + 1, if l.at(j - 1) == `'` { j - 1 } else { j }, .string_escape)
		if l.at(j - 1) == `'` {
			l.add(j - 1, j, .string)
		}
		return j
	}
	if l.at(i + 2) == `'` && l.at(i + 1) != `\n` {
		l.add(i, i + 3, .string)
		return i + 3
	}
	if code_ident_start(l.at(i + 1)) {
		mut j := i + 1
		for j < end && code_ident_rune(l.src[j]) {
			j++
		}
		l.add(i, j, .variable_special)
		return j
	}
	l.add(i, i + 1, .punctuation)
	return i + 1
}

// lex_rust_raw_string handles r"..", r#".."#, b"..", br#".."#. It returns i when
// the text at i is not one.
fn (mut l CodeLexer) lex_rust_raw_string(i int, end int) int {
	mut j := i
	if l.at(j) == `b` {
		j++
		if l.at(j) == `"` {
			k := l.lex_string(j, end, `"`, true, false, .rust)
			l.add(i, j, .string)
			return k
		}
	}
	if l.at(j) != `r` {
		return i
	}
	j++
	mut hashes := 0
	for l.at(j) == `#` {
		hashes++
		j++
	}
	if l.at(j) != `"` {
		return i
	}
	j++
	for j < end {
		if l.src[j] == `"` {
			mut k := 0
			for k < hashes && l.at(j + 1 + k) == `#` {
				k++
			}
			if k == hashes {
				j += 1 + hashes
				l.add(i, j, .string)
				return j
			}
		}
		j++
	}
	l.add(i, end, .string)
	return end
}

// ── Python ────────────────────────────────────────────────────────────────

const code_python_keywords = ['and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue',
	'def', 'del', 'elif', 'else', 'except', 'finally', 'for', 'from', 'global', 'if', 'import',
	'in', 'is', 'lambda', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try', 'while', 'with',
	'yield', 'match', 'case']
const code_python_types = ['int', 'float', 'str', 'bool', 'list', 'dict', 'set', 'tuple', 'bytes',
	'object', 'type', 'complex', 'frozenset', 'bytearray']

fn (mut l CodeLexer) lex_python(start int, end int) {
	mut i := start
	mut after_dot := false
	mut pending := CodeTokenKind.plain
	for i < end {
		c := l.src[i]
		if c == ` ` || c == `\t` || c == `\r` || c == `\n` {
			i++
			continue
		}
		if c == `#` {
			j := l.line_end(i, end)
			l.add(i, j, .comment)
			i = j
			continue
		}
		if c == `@` && l.line_start_blank(i) && code_ident_start(l.at(i + 1)) {
			mut j := i + 1
			for j < end && (code_ident_rune(l.src[j]) || l.src[j] == `.`) {
				j++
			}
			l.add(i, j, .attribute)
			i = j
			continue
		}
		// String prefixes: r, b, f, u and their pairs.
		if code_ident_start(c) {
			mut p := i
			for p < end && p < i + 2 && (l.src[p] in [`r`, `R`, `b`, `B`, `f`, `F`, `u`, `U`]) {
				p++
			}
			if p > i && (l.at(p) == `'` || l.at(p) == `"`) && (i == start
				|| !code_ident_rune(l.src[i - 1])) {
				prefix := l.src[i..p].string().to_lower()
				raw := prefix.contains('r')
				formatted := prefix.contains('f')
				l.add(i, p, .string)
				i = l.lex_python_string(p, end, raw, formatted)
				continue
			}
		}
		if c == `'` || c == `"` {
			i = l.lex_python_string(i, end, false, false)
			continue
		}
		if code_digit(c) || (c == `.` && code_digit(l.at(i + 1))) {
			j := l.number_end(i, end)
			l.add(i, j, .number)
			i = j
			after_dot = false
			continue
		}
		if code_ident_start(c) {
			mut j := i
			for j < end && code_ident_rune(l.src[j]) {
				j++
			}
			w := l.src[i..j].string()
			next := l.next_non_space(j, end)
			mut kind := CodeTokenKind.plain
			if after_dot {
				kind = if l.at(next) == `(` {
					CodeTokenKind.function
				} else {
					CodeTokenKind.property
				}
			} else if w in code_python_keywords {
				kind = .keyword
			} else if w in ['True', 'False', 'None'] {
				kind = .constant
			} else if w in ['self', 'cls'] {
				kind = .variable_special
			} else if pending != .plain {
				kind = pending
			} else if w in code_python_types {
				kind = .type
			} else if l.at(next) == `(` {
				kind = if code_capitalized(w) { CodeTokenKind.type } else { CodeTokenKind.function }
			} else if code_all_caps(w) {
				kind = .constant
			} else if code_capitalized(w) {
				kind = .type
			}
			l.add(i, j, kind)
			pending = if w == 'def' {
				CodeTokenKind.function
			} else if w == 'class' {
				CodeTokenKind.type
			} else {
				CodeTokenKind.plain
			}
			after_dot = false
			i = j
			continue
		}
		after_dot = c == `.`
		pending = .plain
		l.add(i, i + 1, code_symbol_kind(c))
		i++
	}
}

fn (mut l CodeLexer) lex_python_string(i int, end int, raw bool, formatted bool) int {
	quote := l.src[i]
	triple := l.at(i + 1) == quote && l.at(i + 2) == quote
	open_len := if triple { 3 } else { 1 }
	mut seg := i
	mut j := i + open_len
	for j < end {
		r := l.src[j]
		if r == quote && (!triple || (l.at(j + 1) == quote && l.at(j + 2) == quote)) {
			j += open_len
			l.add(seg, j, .string)
			return j
		}
		if r == `\n` && !triple {
			l.add(seg, j, .string)
			return j
		}
		if !raw && r == `\\` && j + 1 < end {
			l.add(seg, j, .string)
			esc := l.escape_end(j, end)
			l.add(j, esc, .string_escape)
			j = esc
			seg = j
			continue
		}
		if formatted && r == `{` {
			if l.at(j + 1) == `{` {
				j += 2
				continue
			}
			l.add(seg, j, .string)
			close := l.bracket_end(j, end, `{`, `}`)
			l.add(j, j + 1, .embedded)
			inner_end := if close > j + 1 && l.at(close - 1) == `}` { close - 1 } else { close }
			l.lex_python(j + 1, inner_end)
			if inner_end < close {
				l.add(inner_end, close, .embedded)
			}
			j = close
			seg = j
			continue
		}
		j++
	}
	l.add(seg, end, .string)
	return end
}

// ── JSON ──────────────────────────────────────────────────────────────────

fn (mut l CodeLexer) lex_json(start int, end int) {
	mut i := start
	for i < end {
		c := l.src[i]
		if c == ` ` || c == `\t` || c == `\r` || c == `\n` {
			i++
			continue
		}
		if l.starts(i, '//') {
			j := l.line_end(i, end)
			l.add(i, j, .comment)
			i = j
			continue
		}
		if l.starts(i, '/*') {
			j := l.block_comment_end(i, end, '/*', '*/', false)
			l.add(i, j, .comment)
			i = j
			continue
		}
		if c == `"` {
			// A key is a string followed by a colon.
			mut j := i + 1
			for j < end && l.src[j] != `"` && l.src[j] != `\n` {
				j += if l.src[j] == `\\` { 2 } else { 1 }
			}
			j = if j < end && l.src[j] == `"` { j + 1 } else { math_min_int(j, end) }
			if l.at(l.next_non_space(j, end)) == `:` {
				l.add(i, j, .property)
			} else {
				l.lex_string(i, j, `"`, true, false, .json)
			}
			i = j
			continue
		}
		if code_digit(c) || (c == `-` && code_digit(l.at(i + 1))) {
			j := l.number_end(if c == `-` { i + 1 } else { i }, end)
			l.add(i, j, .number)
			i = j
			continue
		}
		if code_ident_start(c) {
			mut j := i
			for j < end && code_ident_rune(l.src[j]) {
				j++
			}
			w := l.src[i..j].string()
			l.add(i, j, if w in ['true', 'false', 'null'] {
				CodeTokenKind.constant
			} else {
				CodeTokenKind.plain
			})
			i = j
			continue
		}
		l.add(i, i + 1, code_symbol_kind(c))
		i++
	}
}

fn math_min_int(a int, b int) int {
	return if a < b { a } else { b }
}

// ── TOML ──────────────────────────────────────────────────────────────────

fn (mut l CodeLexer) lex_toml(start int, end int) {
	mut i := start
	mut line_start := true
	mut in_value := false
	for i < end {
		c := l.src[i]
		if c == `\n` {
			line_start = true
			in_value = false
			i++
			continue
		}
		if c == ` ` || c == `\t` || c == `\r` {
			i++
			continue
		}
		if c == `#` {
			j := l.line_end(i, end)
			l.add(i, j, .comment)
			i = j
			continue
		}
		if line_start && c == `[` {
			// A [table] or [[array of tables]] header.
			j := l.line_end(i, end)
			mut k := i
			for k < j && l.src[k] != `#` {
				k++
			}
			for k > i && (l.src[k - 1] == ` ` || l.src[k - 1] == `\t`) {
				k--
			}
			l.add(i, k, .title)
			i = k
			line_start = false
			continue
		}
		line_start = false
		if !in_value && (code_ident_rune(c) || c == `-` || c == `"` || c == `'`) {
			// A key, possibly dotted or quoted, up to `=`.
			mut j := i
			for j < end && l.src[j] != `=` && l.src[j] != `\n` {
				j++
			}
			if j < end && l.src[j] == `=` {
				mut k := j
				for k > i && (l.src[k - 1] == ` ` || l.src[k - 1] == `\t`) {
					k--
				}
				l.add(i, k, .property)
				l.add(j, j + 1, .operator)
				in_value = true
				i = j + 1
				continue
			}
		}
		if c == `"` || c == `'` {
			triple := l.at(i + 1) == c && l.at(i + 2) == c
			if triple {
				mut j := i + 3
				for j < end && !(l.src[j] == c && l.at(j + 1) == c && l.at(j + 2) == c) {
					j++
				}
				j = math_min_int(j + 3, end)
				l.add(i, j, .string)
				i = j
				continue
			}
			i = l.lex_string(i, end, c, c == `"`, false, .toml)
			continue
		}
		if code_digit(c) || ((c == `-` || c == `+`) && code_digit(l.at(i + 1))) {
			// Numbers, dates and times.
			mut j := i + 1
			for j < end && (code_ident_rune(l.src[j]) || l.src[j] in [`-`, `:`, `.`, `+`]) {
				j++
			}
			l.add(i, j, .number)
			i = j
			continue
		}
		if code_ident_start(c) {
			mut j := i
			for j < end && code_ident_rune(l.src[j]) {
				j++
			}
			w := l.src[i..j].string()
			l.add(i, j, if w in ['true', 'false', 'inf', 'nan'] {
				CodeTokenKind.constant
			} else {
				CodeTokenKind.plain
			})
			i = j
			continue
		}
		l.add(i, i + 1, code_symbol_kind(c))
		i++
	}
}

// ── Shell ─────────────────────────────────────────────────────────────────

const code_shell_keywords = ['if', 'then', 'else', 'elif', 'fi', 'case', 'esac', 'for', 'while',
	'until', 'do', 'done', 'in', 'function', 'select', 'time', 'return', 'exit', 'export', 'local',
	'readonly', 'declare', 'unset', 'break', 'continue', 'shift', 'source', 'alias']
const code_shell_builtins = ['echo', 'printf', 'cd', 'pwd', 'test', 'read', 'eval', 'exec', 'set',
	'trap', 'wait', 'kill', 'mkdir', 'rm', 'cp', 'mv', 'ls', 'cat', 'grep', 'sed', 'awk', 'git',
	'make', 'curl', 'tar', 'chmod', 'touch', 'find', 'xargs']

fn (mut l CodeLexer) lex_shell(start int, end int) {
	mut i := start
	mut command_position := true
	for i < end {
		c := l.src[i]
		if c == `\n` || c == `;` || c == `|` || c == `&` {
			command_position = true
			if c != `\n` {
				l.add(i, i + 1, .operator)
			}
			i++
			continue
		}
		if c == ` ` || c == `\t` || c == `\r` {
			i++
			continue
		}
		if c == `#` && (i == start || l.src[i - 1] == ` ` || l.src[i - 1] == `\t`
			|| l.src[i - 1] == `\n`) {
			j := l.line_end(i, end)
			l.add(i, j, .comment)
			i = j
			continue
		}
		if c == `'` {
			mut j := i + 1
			for j < end && l.src[j] != `'` {
				j++
			}
			j = math_min_int(j + 1, end)
			l.add(i, j, .string)
			i = j
			command_position = false
			continue
		}
		if c == `"` {
			i = l.lex_shell_double(i, end)
			command_position = false
			continue
		}
		if c == `$` {
			i = l.lex_shell_variable(i, end)
			command_position = false
			continue
		}
		if code_digit(c) && (i == start || !code_ident_rune(l.src[i - 1])) {
			mut j := i
			for j < end && code_digit(l.src[j]) {
				j++
			}
			if j >= end || !code_ident_rune(l.src[j]) {
				l.add(i, j, .number)
				i = j
				command_position = false
				continue
			}
		}
		if c == `-` && (i == start || l.src[i - 1] == ` ` || l.src[i - 1] == `\t`)
			&& (code_ident_start(l.at(i + 1)) || l.at(i + 1) == `-`) {
			mut j := i + 1
			for j < end && (code_ident_rune(l.src[j]) || l.src[j] == `-`) {
				j++
			}
			l.add(i, j, .attribute)
			i = j
			command_position = false
			continue
		}
		if code_ident_start(c) {
			mut j := i
			for j < end && (code_ident_rune(l.src[j]) || l.src[j] == `-` || l.src[j] == `.`
				|| l.src[j] == `/`) {
				j++
			}
			w := l.src[i..j].string()
			mut kind := CodeTokenKind.plain
			if w in code_shell_keywords {
				kind = .keyword
			} else if l.at(j) == `=` {
				kind = .property
			} else if l.starts(l.next_non_space(j, end), '()') {
				kind = .function
			} else if command_position && (w in code_shell_builtins || !w.contains('/')) {
				kind = .function
			}
			l.add(i, j, kind)
			command_position = w in code_shell_keywords && w !in ['in', 'function']
			i = j
			continue
		}
		l.add(i, i + 1, code_symbol_kind(c))
		command_position = c == `(` || c == `{`
		i++
	}
}

fn (mut l CodeLexer) lex_shell_double(i int, end int) int {
	mut seg := i
	mut j := i + 1
	for j < end {
		r := l.src[j]
		if r == `"` {
			j++
			l.add(seg, j, .string)
			return j
		}
		if r == `\\` && j + 1 < end {
			l.add(seg, j, .string)
			l.add(j, j + 2, .string_escape)
			j += 2
			seg = j
			continue
		}
		if r == `$` {
			l.add(seg, j, .string)
			j = l.lex_shell_variable(j, end)
			seg = j
			continue
		}
		j++
	}
	l.add(seg, end, .string)
	return end
}

fn (mut l CodeLexer) lex_shell_variable(i int, end int) int {
	next := l.at(i + 1)
	if next == `{` {
		close := l.bracket_end(i + 1, end, `{`, `}`)
		l.add(i, close, .variable_special)
		return close
	}
	if next == `(` {
		close := l.bracket_end(i + 1, end, `(`, `)`)
		l.add(i, i + 2, .embedded)
		inner_end := if close > i + 2 && l.at(close - 1) == `)` { close - 1 } else { close }
		l.lex_shell(i + 2, inner_end)
		if inner_end < close {
			l.add(inner_end, close, .embedded)
		}
		return close
	}
	mut j := i + 1
	if code_digit(next) || next in [`@`, `#`, `?`, `$`, `!`, `*`, `-`] {
		j++
	} else {
		for j < end && code_ident_rune(l.src[j]) {
			j++
		}
	}
	if j == i + 1 {
		return j
	}
	l.add(i, j, .variable_special)
	return j
}

// ── Markdown ──────────────────────────────────────────────────────────────

fn (mut l CodeLexer) lex_markdown(start int, end int) {
	mut i := start
	for i < end {
		line_end := l.line_end(i, end)
		indent := l.next_non_space(i, line_end)
		// Fenced code blocks, highlighted in their own language when it is known.
		if l.starts(indent, '```') || l.starts(indent, '~~~') {
			fence := l.src[indent]
			mut info_start := indent
			for info_start < line_end && l.src[info_start] == fence {
				info_start++
			}
			fence_len := info_start - indent
			info := l.src[info_start..line_end].string().trim_space().all_before(' ')
			l.add(indent, line_end, .code_span)
			body_start := math_min_int(line_end + 1, end)
			mut k := body_start
			mut close_start := end
			mut close_end := end
			for k < end {
				k_end := l.line_end(k, end)
				k_indent := l.next_non_space(k, k_end)
				mut fence_run := 0
				for k_indent + fence_run < k_end && l.src[k_indent + fence_run] == fence {
					fence_run++
				}
				if fence_run >= fence_len && l.src[k_indent + fence_run..k_end].string().trim_space().len == 0 {
					close_start = k
					close_end = k_end
					break
				}
				k = k_end + 1
			}
			body_end := if close_start > body_start { close_start - 1 } else { body_start }
			inner := code_language(info)
			if inner != .plain && inner != .markdown {
				l.run(inner, body_start, math_max_int(body_end, body_start))
			} else {
				l.add(body_start, body_end, .code_span)
			}
			if close_start < end {
				l.add(close_start, close_end, .code_span)
			}
			i = if close_end < end { close_end + 1 } else { end }
			continue
		}
		c := l.at(indent)
		if c == `#` {
			mut level := 0
			for l.at(indent + level) == `#` {
				level++
			}
			if level <= 6 && (indent + level == line_end || l.at(indent + level) == ` `) {
				l.add(indent, line_end, .title)
				i = line_end + 1
				continue
			}
		}
		if c == `>` {
			l.add(indent, indent + 1, .tag)
			l.lex_markdown_inline(indent + 1, line_end)
			i = line_end + 1
			continue
		}
		if (c == `-` || c == `*` || c == `_`) && l.markdown_rule(indent, line_end) {
			l.add(indent, line_end, .tag)
			i = line_end + 1
			continue
		}
		if (c == `-` || c == `*` || c == `+`) && l.at(indent + 1) == ` ` {
			l.add(indent, indent + 1, .tag)
			mut body := indent + 2
			if l.starts(body, '[ ]') || l.starts(body, '[x]') || l.starts(body, '[X]') {
				l.add(body, body + 3, .tag)
				body += 3
			}
			l.lex_markdown_inline(body, line_end)
			i = line_end + 1
			continue
		}
		if code_digit(c) {
			mut j := indent
			for j < line_end && code_digit(l.src[j]) {
				j++
			}
			if (l.at(j) == `.` || l.at(j) == `)`) && l.at(j + 1) == ` ` {
				l.add(indent, j + 1, .tag)
				l.lex_markdown_inline(j + 1, line_end)
				i = line_end + 1
				continue
			}
		}
		if l.starts(indent, '<!--') {
			j := l.block_comment_end(indent, end, '<!--', '-->', false)
			l.add(indent, j, .comment)
			i = l.line_end(j, end) + 1
			continue
		}
		l.lex_markdown_inline(i, line_end)
		i = line_end + 1
	}
}

fn (l &CodeLexer) markdown_rule(i int, end int) bool {
	mut count := 0
	first := l.src[i]
	for j in i .. end {
		r := l.src[j]
		if r == first {
			count++
		} else if r != ` ` && r != `\t` {
			return false
		}
	}
	return count >= 3
}

fn (mut l CodeLexer) lex_markdown_inline(start int, end int) {
	mut i := start
	for i < end {
		c := l.src[i]
		if c == `\\` && i + 1 < end {
			l.add(i, i + 2, .string_escape)
			i += 2
			continue
		}
		if c == `\`` {
			mut ticks := 0
			for l.at(i + ticks) == `\`` {
				ticks++
			}
			mut j := i + ticks
			for j < end {
				if l.src[j] == `\`` {
					mut tick_run := 0
					for l.at(j + tick_run) == `\`` {
						tick_run++
					}
					if tick_run == ticks {
						j += tick_run
						break
					}
					j += tick_run
					continue
				}
				j++
			}
			l.add(i, math_min_int(j, end), .code_span)
			i = j
			continue
		}
		if c == `[` || (c == `!` && l.at(i + 1) == `[`) {
			open := if c == `!` { i + 1 } else { i }
			close := l.bracket_end(open, end, `[`, `]`)
			if close <= end && l.at(close - 1) == `]` && l.at(close) == `(` {
				uri_end := l.bracket_end(close, end, `(`, `)`)
				if l.at(uri_end - 1) == `)` {
					l.add(i, close, .link_text)
					l.add(close, uri_end, .link_uri)
					i = uri_end
					continue
				}
			}
		}
		if c == `<` && (l.starts(i + 1, 'http://') || l.starts(i + 1, 'https://')) {
			mut j := i + 1
			for j < end && l.src[j] != `>` && l.src[j] != ` ` {
				j++
			}
			if l.at(j) == `>` {
				l.add(i, j + 1, .link_uri)
				i = j + 1
				continue
			}
		}
		if (c == `*` || c == `_`) && i + 1 < end {
			strong := l.at(i + 1) == c
			delim_len := if strong { 2 } else { 1 }
			if !strong && c == `_` && i > start && code_ident_rune(l.src[i - 1]) {
				i++
				continue
			}
			body := i + delim_len
			if body < end && l.src[body] != ` ` {
				mut j := body
				for j < end {
					if l.src[j] == c && (!strong || l.at(j + 1) == c) && l.src[j - 1] != ` ` {
						break
					}
					j++
				}
				if j < end && j > body {
					l.add(i, j + delim_len, if strong {
						CodeTokenKind.strong
					} else {
						CodeTokenKind.emphasis
					})
					i = j + delim_len
					continue
				}
			}
		}
		i++
	}
}
