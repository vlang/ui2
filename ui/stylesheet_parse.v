module ui2

import os

// P0 stylesheet parser: QSS/CSS-familiar selectors with ui2 extensions.
//
// Parses a stylesheet string (or `.vss` file via load_stylesheet) into a
// Stylesheet of rules plus variables. Matching and cascading live in
// stylesheet_match.v / stylesheet_cascade.v; this file never touches an
// Element or a backend.
//
// Supported syntax (v1):
//   @name: value;  --name: value;          variables (global)
//   light { @bg: #fff; }  dark { @bg: #000; }  theme-scoped variables
//   Type, #id, .class, *                    simple selectors
//   A B   A > B                             descendant / child
//   :hover :pressed :focused :disabled :enabled :checked :selected
//   :first-child :last-child :only-child :empty :nth-child(2|odd|even)
// Errors carry `line:col` so editors and the lint helper can point at them.

pub enum StyleCombinator {
	descendant
	child
}

pub struct StylePseudo {
pub:
	name string
	arg  string
}

pub struct StyleSelectorPart {
pub:
	// kind is the type name (`Button`, `View`, ...) or '' when the compound
	// has no type. universal is set for `*`. parent_ref marks a leading `&`
	// in a nested rule, replaced by the parent selector when flattening.
	kind       string
	universal  bool
	id         string
	classes    []string
	pseudos    []StylePseudo
	parent_ref bool
}

pub struct StyleSelector {
pub:
	parts       []StyleSelectorPart
	combinators []StyleCombinator // len is parts.len - 1
	specificity int
}

pub struct StyleDeclaration {
pub:
	prop  string
	value string
	line  int
	col   int
}

pub struct StyleRule {
pub:
	selectors    []StyleSelector
	declarations []StyleDeclaration
	// media and containers are the innermost query lists (comma = OR). A
	// rule inside nested query blocks also carries every enclosing level,
	// outermost first; each level must hold, since nesting intersects.
	media            []MediaQuery
	containers       []ContainerQuery
	outer_media      [][]MediaQuery
	outer_containers [][]ContainerQuery
	line             int
	col              int
}

// StyleKeyframe is one stop inside a `@keyframes` block: a progress (0..1)
// plus the declarations that apply at that stop. `from`/`to` are aliases
// for 0 and 1.
pub struct StyleKeyframe {
pub:
	stop         f64
	declarations []StyleDeclaration
	line         int
	col          int
}

// StyleKeyframes is a named animation definition usable by the
// `animation-name` property and the `animation` shorthand.
pub struct StyleKeyframes {
pub:
	name  string
	stops []StyleKeyframe
	line  int
	col   int
}

struct StyleQueryCtx {
	media      [][]MediaQuery
	containers [][]ContainerQuery
}

// rule builds a rule under this nesting: the innermost level of each kind
// becomes the rule's own list, the rest its outer levels.
fn (q StyleQueryCtx) rule(selectors []StyleSelector, declarations []StyleDeclaration, line int, col int) StyleRule {
	return StyleRule{
		selectors:        selectors
		declarations:     declarations
		media:            if q.media.len > 0 { q.media.last().clone() } else { []MediaQuery{} }
		containers:       if q.containers.len > 0 {
			q.containers.last().clone()
		} else {
			[]ContainerQuery{}
		}
		outer_media:      if q.media.len > 1 {
			q.media[..q.media.len - 1].clone()
		} else {
			[][]MediaQuery{}
		}
		outer_containers: if q.containers.len > 1 {
			q.containers[..q.containers.len - 1].clone()
		} else {
			[][]ContainerQuery{}
		}
		line:             line
		col:              col
	}
}

pub struct Stylesheet {
mut:
	// Source-order bookkeeping for load_stylesheet, so imports splice in
	// place: the number of top-level rules before each `@import`, and every
	// variable definition with the number of imports before it.
	import_rule_pos []int
	var_log         []StyleVarEntry
pub mut:
	rules      []StyleRule
	variables  map[string]string
	light_vars map[string]string
	dark_vars  map[string]string
	imports    []string                  // `@import` paths in source order, for load_stylesheet
	rule_index StyleRuleIndex            // subject buckets; empty on hand-built sheets
	keyframes  map[string]StyleKeyframes // `@keyframes` definitions by name
}

// merge_keyframes returns a merged map: base first, preset overrides on name clash.
fn merge_keyframes(base map[string]StyleKeyframes, preset map[string]StyleKeyframes) map[string]StyleKeyframes {
	mut out := map[string]StyleKeyframes{}
	for key, value in base {
		out[key] = value
	}
	for key, value in preset {
		out[key] = value
	}
	return out
}

// when dark is true, then the global one. Returns none when undefined.
pub fn (s Stylesheet) resolve_var(name string, dark bool) ?string {
	key := name.trim_space()
	if dark {
		if value := s.dark_vars[key] {
			return value
		}
	}
	if value := s.light_vars[key] {
		// light_vars only apply in light mode; in dark mode they are ignored
		// unless no dark override exists and the variable is theme-agnostic.
		if !dark {
			return value
		}
	}
	if value := s.variables[key] {
		return value
	}
	return none
}

// StyleVarEntry is one variable definition in source order: mode is '',
// 'light' or 'dark'.
struct StyleVarEntry {
	mode           string
	name           string
	value          string
	imports_before int
}

// style_max_expansion_depth caps plugin at-rule expansion nesting, so a
// plugin whose replacement re-emits its own at-rule fails instead of
// recursing until the stack overflows.
const style_max_expansion_depth = 16

const style_pseudo_no_arg = ['hover', 'pressed', 'focused', 'disabled', 'enabled', 'checked', 'selected',
	'first-child', 'last-child', 'only-child', 'empty']

const style_pseudo_with_arg = ['nth-child']

struct StyleParser {
	src   string
	depth int // plugin at-rule expansion nesting
mut:
	pos             int
	line            int = 1
	col             int = 1
	variables       map[string]string
	light_vars      map[string]string
	dark_vars       map[string]string
	imports         []string
	import_rule_pos []int
	var_log         []StyleVarEntry
	keyframes       map[string]StyleKeyframes
}

// define records one variable definition: the mode's map for lookups and
// the source-order log for import splicing.
fn (mut p StyleParser) define(mode string, name string, value string) {
	match mode {
		'light' { p.light_vars[name] = value }
		'dark' { p.dark_vars[name] = value }
		else { p.variables[name] = value }
	}
	p.var_log << StyleVarEntry{
		mode:           mode
		name:           name
		value:          value
		imports_before: p.imports.len
	}
}

// parse_stylesheet parses a stylesheet string into a Stylesheet. A leading
// UTF-8 byte order mark, as some editors save, is skipped.
pub fn parse_stylesheet(source string) !Stylesheet {
	mut parser := StyleParser{
		src:        source.trim_string_left('\xef\xbb\xbf')
		variables:  map[string]string{}
		light_vars: map[string]string{}
		dark_vars:  map[string]string{}
		imports:    []string{}
		keyframes:  map[string]StyleKeyframes{}
	}
	rules := parser.parse_block(StyleQueryCtx{}, true)!
	return Stylesheet{
		rules:           rules
		variables:       parser.variables
		light_vars:      parser.light_vars
		dark_vars:       parser.dark_vars
		imports:         parser.imports
		import_rule_pos: parser.import_rule_pos
		var_log:         parser.var_log
		rule_index:      stylesheet_index_rules(rules)
		keyframes:       parser.keyframes
	}
}

// load_stylesheet reads a `.vss` file and its `@import` chain, splicing
// imported files in place (depth-first, each file once): an import's rules
// and variables land exactly where the `@import` stands. A partial imported
// by two files contributes only at its first import. Imports resolve
// relative to the importing file and must stay inside the directory of
// the file passed here, so a sheet from an untrusted source cannot read
// arbitrary files; use load_stylesheet_within to allow a wider root.
// Cycles terminate on the second visit.
pub fn load_stylesheet(path string) !Stylesheet {
	return load_stylesheet_within(path, os.dir(path))
}

// load_stylesheet_within is load_stylesheet with an explicit confinement
// root: every file in the import chain, including path itself, must
// resolve (symlinks followed) inside root.
pub fn load_stylesheet_within(path string, root string) !Stylesheet {
	confine := os.real_path(root)
	if confine == '' || !os.is_dir(confine) {
		return error('stylesheet: cannot resolve root directory "${root}"')
	}
	mut visited := []string{}
	return load_stylesheet_file(path, confine, mut visited)!
}

// style_path_within reports whether an absolute, resolved path lies inside
// dir (or is dir).
fn style_path_within(path string, dir string) bool {
	if path == dir {
		return true
	}
	prefix := if dir.ends_with(os.path_separator) { dir } else { dir + os.path_separator }
	return path.starts_with(prefix)
}

fn load_stylesheet_file(path string, confine string, mut visited []string) !Stylesheet {
	absolute := os.real_path(path)
	if absolute == '' || !os.exists(absolute) {
		return error('stylesheet: cannot read "${path}": no such file')
	}
	if !style_path_within(absolute, confine) {
		return error('stylesheet: "${path}" is outside the stylesheet directory "${confine}"')
	}
	if absolute in visited {
		return Stylesheet{}
	}
	visited << absolute
	if !os.is_file(absolute) {
		return error('stylesheet: cannot read "${path}": not a regular file')
	}
	source := os.read_file(absolute) or {
		return error('stylesheet: cannot read "${path}": ${err.msg()}')
	}
	sheet := parse_stylesheet(source) or {
		// Point at the file: `theme.vss:3:1: ...` instead of `stylesheet:3:1:`.
		msg := err.msg()
		return error(if msg.starts_with('stylesheet:') {
			'${path}:${msg['stylesheet:'.len..]}'
		} else {
			'${path}: ${msg}'
		})
	}
	if sheet.imports.len == 0 {
		return sheet
	}
	base := os.dir(absolute)
	mut rules := []StyleRule{}
	mut variables := map[string]string{}
	mut light_vars := map[string]string{}
	mut dark_vars := map[string]string{}
	mut keyframes := map[string]StyleKeyframes{}
	mut next_rule := 0
	mut next_var := 0
	for i, name in sheet.imports {
		// Own rules and variables written before this `@import` come first.
		pos := if i < sheet.import_rule_pos.len { sheet.import_rule_pos[i] } else { 0 }
		if pos > next_rule {
			rules << sheet.rules[next_rule..pos]
			next_rule = pos
		}
		for next_var < sheet.var_log.len && sheet.var_log[next_var].imports_before <= i {
			style_apply_var_entry(sheet.var_log[next_var], mut variables, mut light_vars, mut
				dark_vars)
			next_var++
		}
		target := if os.is_abs_path(name) { name } else { os.join_path(base, name) }
		sub := load_stylesheet_file(target, confine, mut visited)!
		rules << sub.rules
		for key, value in sub.variables {
			variables[key] = value
		}
		for key, value in sub.light_vars {
			light_vars[key] = value
		}
		for key, value in sub.dark_vars {
			dark_vars[key] = value
		}
		for key, value in sub.keyframes {
			keyframes[key] = value
		}
	}
	rules << sheet.rules[next_rule..]
	for next_var < sheet.var_log.len {
		style_apply_var_entry(sheet.var_log[next_var], mut variables, mut light_vars, mut
			dark_vars)
		next_var++
	}
	for key, value in sheet.keyframes {
		keyframes[key] = value
	}
	return Stylesheet{
		rules:      rules
		variables:  variables
		light_vars: light_vars
		dark_vars:  dark_vars
		imports:    sheet.imports.clone()
		rule_index: stylesheet_index_rules(rules)
		keyframes:  keyframes
	}
}

fn style_apply_var_entry(entry StyleVarEntry, mut variables map[string]string, mut light_vars map[string]string, mut dark_vars map[string]string) {
	match entry.mode {
		'light' { light_vars[entry.name] = entry.value }
		'dark' { dark_vars[entry.name] = entry.value }
		else { variables[entry.name] = entry.value }
	}
}

fn style_err(line int, col int, msg string) string {
	return 'stylesheet:${line}:${col}: ${msg}'
}

fn (mut p StyleParser) eof() bool {
	return p.pos >= p.src.len
}

fn (mut p StyleParser) peek() u8 {
	if p.pos >= p.src.len {
		return 0
	}
	return p.src[p.pos]
}

fn (mut p StyleParser) advance() u8 {
	if p.pos >= p.src.len {
		return 0
	}
	ch := p.src[p.pos]
	p.pos++
	if ch == `\n` {
		p.line++
		p.col = 1
	} else {
		p.col++
	}
	return ch
}

fn is_style_space(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r` || ch == 12
}

fn is_style_name_start(ch u8) bool {
	return (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || ch == `_`
}

fn is_style_name_char(ch u8) bool {
	return is_style_name_start(ch) || (ch >= `0` && ch <= `9`) || ch == `-`
}

// style_keyword_end reports whether a theme-block keyword may end at pos:
// the next character must not continue an identifier.
fn style_keyword_end(src string, pos int) bool {
	if pos >= src.len {
		return true
	}
	return !is_style_name_char(src[pos])
}

fn (mut p StyleParser) skip_space_and_comments() ! {
	for !p.eof() {
		if is_style_space(p.peek()) {
			p.advance()
			continue
		}
		if p.peek() == `/` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `*` {
			p.skip_comment()!
			continue
		}
		break
	}
}

// skip_comment consumes one `/* ... */` comment starting at pos.
fn (mut p StyleParser) skip_comment() ! {
	line := p.line
	col := p.col
	p.advance()
	p.advance()
	for !p.eof() {
		if p.peek() == `*` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `/` {
			p.advance()
			p.advance()
			return
		}
		p.advance()
	}
	return error(style_err(line, col, 'unclosed comment'))
}

// parse_block parses rules until `}` or the end of input. At the top level
// it also takes variables, theme blocks and `@import`s; inside query blocks
// only rules and nested blocks belong. Plugin at-rules expand to replacement
// source parsed recursively with the same media/container context.
fn (mut p StyleParser) parse_block(q StyleQueryCtx, top_level bool) ![]StyleRule {
	return p.parse_block_inner(q, top_level, top_level)
}

// parse_block_inner is parse_block with an independent EOF rule: fragments
// (at-rule expansions) end at EOF like top-level sheets, but only take
// rules and nested blocks like query bodies.
fn (mut p StyleParser) parse_block_inner(q StyleQueryCtx, top_level bool, eof_ok bool) ![]StyleRule {
	mut rules := []StyleRule{}
	for {
		p.skip_space_and_comments()!
		if p.eof() {
			if eof_ok {
				break
			}
			return error(style_err(p.line, p.col, 'unclosed block'))
		}
		if p.peek() == `}` {
			if top_level {
				return error(style_err(p.line, p.col, 'unexpected `}`'))
			}
			p.advance()
			break
		}
		if p.peek() == `@` || (p.peek() == `-` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `-`) {
			if (p.src[p.pos..].starts_with('@media') && style_keyword_end(p.src, p.pos + 6))
				|| (p.src[p.pos..].starts_with('@container')
					&& style_keyword_end(p.src, p.pos + 10)) {
				for rule in p.parse_query_block(q)! {
					rules << rule
				}
				continue
			}
			// `@keyframes name { ... }`: an animation definition, not a rule.
			if top_level && p.src[p.pos..].starts_with('@keyframes')
				&& style_keyword_end(p.src, p.pos + 10) {
				kf := p.parse_keyframes()!
				p.keyframes[kf.name] = kf
				continue
			}
			// Builtins (`@import`, `@name: value;`) take precedence over plugin
			// at-rules, so a plugin claim can never change how an existing
			// sheet parses.
			if top_level && p.src[p.pos..].starts_with('@import')
				&& style_keyword_end(p.src, p.pos + 7) {
				p.import_rule_pos << rules.len
				p.imports << p.parse_import()!
				continue
			}
			if name := p.plugin_at_rule_name() {
				at_line := p.line
				at_col := p.col
				prelude, body := p.capture_at_block(name)!
				replacement := style_plugin_expand_at_rule(name, prelude, body) or {
					return error(style_err(at_line, at_col, err.msg()))
				}
				for rule in p.parse_fragment(replacement, q, at_line, at_col, name)! {
					rules << rule
				}
				continue
			}
			if top_level {
				if p.peek() == `@`
					|| (p.peek() == `-` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `-`) {
					name, value := p.parse_variable_def()!
					p.define('', name, value)
					continue
				}
			}
			if top_level {
				// Theme blocks and plain rules follow below.
			} else {
				return error(style_err(p.line, p.col,
					'only rules and query blocks belong inside a query block'))
			}
		}
		// Theme blocks: `light { ... }` / `dark { ... }`. The keyword needs a
		// word boundary so a type selector that merely starts with those
		// letters (e.g. `lights`) parses as a rule instead.
		if (p.src[p.pos..].starts_with('light') && style_keyword_end(p.src, p.pos + 5))
			|| (p.src[p.pos..].starts_with('dark') && style_keyword_end(p.src, p.pos + 4)) {
			if !top_level {
				return error(style_err(p.line, p.col,
					'only rules and query blocks belong inside a query block'))
			}
			p.parse_theme_block()!
			continue
		}
		for rule in p.parse_rule_guarded(q)! {
			rules << rule
		}
	}
	return rules
}

// parse_fragment parses replacement source from an at-rule expansion with
// the enclosing query context. Only rules and nested query blocks belong in
// an expansion; variables and imports stay at the top level. Errors inside
// the replacement point at the at-rule that produced it, and expansions
// nest at most style_max_expansion_depth deep.
fn (mut p StyleParser) parse_fragment(source string, q StyleQueryCtx, line int, col int, name string) ![]StyleRule {
	if p.depth >= style_max_expansion_depth {
		return error(style_err(line, col, '"@${name}" expands into itself (more than ${style_max_expansion_depth} nested expansions)'))
	}
	mut sub := StyleParser{
		src:   source
		depth: p.depth + 1
	}
	return sub.parse_block_inner(q, false, true) or {
		// Positions inside the replacement mean nothing to the author: name
		// the at-rule instead. The innermost failing expansion wraps once.
		if err.msg().contains(' expansion') {
			return err
		}
		return error(style_err(line, col, '"@${name}" expansion: ${err.msg()}'))
	}
}

// plugin_at_rule_name reports the claimed `@name` at pos, or none when the
// `@`-word is a builtin, an unknown at-rule, or not an at-rule at all.
fn (mut p StyleParser) plugin_at_rule_name() ?string {
	if p.eof() || p.peek() != `@` {
		return none
	}
	mut end := p.pos + 1
	for end < p.src.len && is_style_name_char(p.src[end]) {
		end++
	}
	name := p.src[p.pos + 1..end]
	if name == '' || name in ['import', 'media', 'container'] || !style_plugin_has_at_rule(name) {
		return none
	}
	// `@name: value;` stays a variable definition even when a plugin
	// claims `name`.
	mut look := end
	for look < p.src.len && is_style_space(p.src[look]) {
		look++
	}
	if look < p.src.len && p.src[look] == `:` {
		return none
	}
	return name
}

// capture_at_block consumes `@name`, its prelude, and its balanced `{...}`
// body, returning both as text. Strings (with backslash escapes) pass
// through verbatim and their braces do not count; `/* */` comments are
// dropped. There are no `//` line comments in stylesheets, so text like
// `url(http://x/y.png)` survives.
fn (mut p StyleParser) capture_at_block(name string) !(string, string) {
	start_line := p.line
	start_col := p.col
	for _ in 0 .. name.len + 1 {
		p.advance()
	}
	mut prelude := []u8{}
	for !p.eof() && p.peek() != `{` {
		if p.peek() == `;` || p.peek() == `}` {
			break
		}
		prelude << p.advance()
	}
	if p.eof() || p.peek() != `{` {
		return error(style_err(start_line, start_col, 'expected `{` after "@${name}"'))
	}
	p.advance()
	mut body := []u8{}
	mut depth := 1
	mut quote := u8(0)
	for !p.eof() {
		ch := p.peek()
		if quote != 0 {
			body << p.advance()
			if ch == `\\` && !p.eof() {
				body << p.advance()
			} else if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			body << p.advance()
			continue
		}
		if ch == `/` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `*` {
			p.skip_comment()!
			body << ` `
			continue
		}
		if ch == `{` {
			depth++
		} else if ch == `}` {
			depth--
			if depth == 0 {
				p.advance()
				break
			}
		}
		body << p.advance()
	}
	if depth != 0 {
		return error(style_err(start_line, start_col, 'unclosed "@${name}" block'))
	}
	return prelude.bytestr().trim_space(), body.bytestr()
}

// parse_import parses `@import "path";` or `@import url(path);`. Paths
// resolve relative to the importing file when loaded from disk.
fn (mut p StyleParser) parse_import() !string {
	for _ in 0 .. '@import'.len {
		p.advance()
	}
	p.skip_space_and_comments()!
	if p.eof() {
		return error(style_err(p.line, p.col, 'expected a path after "@import"'))
	}
	mut path := ''
	if p.peek() == `"` || p.peek() == `'` {
		quote := p.advance()
		mut out := []u8{}
		for !p.eof() && p.peek() != quote {
			out << p.advance()
		}
		if p.eof() {
			return error(style_err(p.line, p.col, 'unclosed "@import" path'))
		}
		p.advance()
		path = out.bytestr().trim_space()
	} else {
		word := p.parse_ident()!.to_lower()
		if word != 'url' || p.eof() || p.peek() != `(` {
			return error(style_err(p.line, p.col, 'expected `"path"` or `url(path)` after "@import"'))
		}
		p.advance()
		mut out := []u8{}
		for !p.eof() && p.peek() != `)` {
			out << p.advance()
		}
		if p.eof() {
			return error(style_err(p.line, p.col, 'unclosed `url()` in "@import"'))
		}
		p.advance()
		trimmed := out.bytestr().trim_space()
		if (trimmed.starts_with('"') && trimmed.ends_with('"') && trimmed.len >= 2)
			|| (trimmed.starts_with("'") && trimmed.ends_with("'") && trimmed.len >= 2) {
			path = trimmed[1..trimmed.len - 1].trim_space()
		} else {
			path = trimmed
		}
	}
	if path == '' {
		return error(style_err(p.line, p.col, 'empty "@import" path'))
	}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `;` {
		return error(style_err(p.line, p.col, 'expected `;` after "@import" path'))
	}
	p.advance()
	return path
}

// parse_variable_def parses `@name: value;` or `--name: value;`.
fn (mut p StyleParser) parse_variable_def() !(string, string) {
	start_line := p.line
	start_col := p.col
	mut name := ''
	if p.peek() == `@` {
		p.advance()
		name = '@' + p.parse_ident()!
	} else {
		p.advance()
		p.advance()
		name = '--' + p.parse_ident()!
	}
	if name.trim_space().len <= 1 {
		return error(style_err(start_line, start_col, 'expected a variable name'))
	}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `:` {
		return error(style_err(p.line, p.col, 'expected `:` after variable "${name}"'))
	}
	p.advance()
	value := p.parse_raw_value()!
	if value.trim_space().len == 0 {
		return error(style_err(start_line, start_col, 'variable "${name}" has an empty value'))
	}
	return name, value.trim_space()
}

// parse_theme_block parses `light { @a: 1; }` / `dark { ... }`. Only variable
// definitions are allowed inside; rules are rejected with a position.
fn (mut p StyleParser) parse_theme_block() ! {
	mut mode := ''
	if p.src[p.pos..].starts_with('light') {
		mode = 'light'
		for _ in 0 .. 5 {
			p.advance()
		}
	} else if p.src[p.pos..].starts_with('dark') {
		mode = 'dark'
		for _ in 0 .. 4 {
			p.advance()
		}
	} else {
		return error(style_err(p.line, p.col, 'expected `light` or `dark`'))
	}
	// Guard against `lightfoo` being read as the `light` block.
	if !p.eof() && (is_style_name_char(p.peek()) || p.peek() == `-`) {
		return error(style_err(p.line, p.col, 'expected a rule or variable'))
	}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `{` {
		return error(style_err(p.line, p.col, 'expected `{` after `${mode}`'))
	}
	p.advance()
	for {
		p.skip_space_and_comments()!
		if p.eof() {
			return error(style_err(p.line, p.col, 'unclosed `${mode}` block'))
		}
		if p.peek() == `}` {
			p.advance()
			break
		}
		if p.peek() == `@` || (p.peek() == `-` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `-`) {
			name, value := p.parse_variable_def()!
			p.define(mode, name, value)
			continue
		}
		return error(style_err(p.line, p.col, 'only variables are allowed inside `${mode}`'))
	}
}

fn (mut p StyleParser) parse_ident() !string {
	mut out := []u8{}
	for !p.eof() && is_style_name_char(p.peek()) {
		out << p.advance()
	}
	if out.len == 0 {
		return error(style_err(p.line, p.col, 'expected a name'))
	}
	return out.bytestr()
}

// parse_raw_value reads until `;` at paren depth 0 (so functions and quoted
// strings survive), consuming the `;`. Quoted strings keep backslash
// escapes verbatim; `/* */` comments outside strings drop out of the value
// (one space stands in, so `1px/**/solid` stays two words), as CSS removes
// them before parsing.
fn (mut p StyleParser) parse_raw_value() !string {
	mut out := []u8{}
	mut depth := 0
	mut quote := u8(0)
	for !p.eof() {
		ch := p.peek()
		if quote != 0 {
			out << p.advance()
			if ch == `\\` && !p.eof() {
				out << p.advance()
			} else if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			out << p.advance()
			continue
		}
		if ch == `/` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `*` {
			p.skip_comment()!
			if out.len > 0 && !is_style_space(out.last()) {
				out << ` `
			}
			continue
		}
		if ch == `(` {
			depth++
			out << p.advance()
			continue
		}
		if ch == `)` {
			if depth > 0 {
				depth--
			}
			out << p.advance()
			continue
		}
		if ch == `;` && depth == 0 {
			p.advance()
			return out.bytestr()
		}
		if ch == `}` && depth == 0 {
			return error(style_err(p.line, p.col, 'expected `;` before `}`'))
		}
		out << p.advance()
	}
	return error(style_err(p.line, p.col, 'unexpected end inside a value'))
}

// parse_rule_guarded parses one rule plus any nested rules, flattening the
// nested selectors onto their parents: `Card { Button { } }` behaves as
// `Card Button { }`, and a leading `&` splices the parent in (`&:hover` is
// the parent hovered). Only a leading `&` is supported.
fn (mut p StyleParser) parse_rule_guarded(q StyleQueryCtx) ![]StyleRule {
	start_line := p.line
	start_col := p.col
	selectors := p.parse_selector_list()!
	for selector in selectors {
		for part in selector.parts {
			if part.parent_ref {
				return error(style_err(start_line, start_col,
					'`&` only makes sense nested inside another rule'))
			}
		}
	}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `{` {
		return error(style_err(p.line, p.col, 'expected `{` after selector'))
	}
	p.advance()
	return p.parse_rule_body(selectors, start_line, start_col, q)!
}

fn (mut p StyleParser) parse_rule_body(selectors []StyleSelector, start_line int, start_col int, q StyleQueryCtx) ![]StyleRule {
	mut declarations := []StyleDeclaration{}
	mut nested := []StyleRule{}
	for {
		p.skip_space_and_comments()!
		if p.eof() {
			return error(style_err(p.line, p.col, 'unclosed rule block'))
		}
		if p.peek() == `}` {
			p.advance()
			break
		}
		if p.nested_rule_start()! {
			for rule in p.parse_nested_rule(selectors, q)! {
				nested << rule
			}
			continue
		}
		decl_line := p.line
		decl_col := p.col
		prop := p.parse_ident()!
		p.skip_space_and_comments()!
		if p.eof() || p.peek() != `:` {
			return error(style_err(p.line, p.col, 'expected `:` after property "${prop}"'))
		}
		p.advance()
		p.skip_space_and_comments()!
		value := p.parse_raw_value()!
		if value.trim_space().len == 0 {
			return error(style_err(decl_line, decl_col, 'property "${prop}" has an empty value'))
		}
		declarations << StyleDeclaration{
			prop:  prop.to_lower()
			value: value.trim_space()
			line:  decl_line
			col:   decl_col
		}
	}
	if declarations.len == 0 && nested.len == 0 {
		return error(style_err(start_line, start_col, 'rule has no declarations'))
	}
	mut rules := []StyleRule{}
	if declarations.len > 0 {
		rules << q.rule(selectors, declarations, start_line, start_col)
	}
	rules << nested
	return rules
}

// nested_rule_start reports whether a rule body continues with a nested
// rule rather than a declaration: `&`, `.class`, `#id`, `:state`, `*` or
// `>` always start a rule. A name could start either (`Button:hover {` vs
// `color: red;`), so it looks ahead: a `{` before the next `;` or `}`
// makes it a rule, since a declaration value can never contain `{`.
fn (mut p StyleParser) nested_rule_start() !bool {
	if p.eof() {
		return false
	}
	ch := p.peek()
	if ch == `&` || ch == `.` || ch == `#` || ch == `:` || ch == `*` || ch == `>` {
		return true
	}
	if !is_style_name_start(ch) {
		return false
	}
	mut i := p.pos
	mut depth := 0
	mut quote := u8(0)
	for i < p.src.len {
		c := p.src[i]
		if quote != 0 {
			if c == `\\` {
				i += 2
				continue
			}
			if c == quote {
				quote = 0
			}
			i++
			continue
		}
		if c == `"` || c == `'` {
			quote = c
		} else if c == `/` && i + 1 < p.src.len && p.src[i + 1] == `*` {
			end := p.src.index_after('*/', i + 2) or { return false }
			i = end + 2
			continue
		} else if c == `(` {
			depth++
		} else if c == `)` {
			if depth > 0 {
				depth--
			}
		} else if depth == 0 {
			if c == `{` {
				return true
			}
			if c == `;` || c == `}` {
				return false
			}
		}
		i++
	}
	return false
}

// parse_nested_rule parses one nested rule after its parent's selectors,
// combining each nested selector with each parent selector.
fn (mut p StyleParser) parse_nested_rule(parents []StyleSelector, q StyleQueryCtx) ![]StyleRule {
	start_line := p.line
	start_col := p.col
	mut explicit_child := false
	if !p.eof() && p.peek() == `>` {
		p.advance()
		p.skip_space_and_comments()!
		explicit_child = true
	}
	child := p.parse_selector_list()!
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `{` {
		return error(style_err(p.line, p.col, 'expected `{` after nested selector'))
	}
	p.advance()
	mut selectors := []StyleSelector{}
	for parent in parents {
		for part in child {
			selectors << style_combine_selectors(parent, part, explicit_child)!
		}
	}
	return p.parse_rule_body(selectors, start_line, start_col, q)!
}

// style_combine_selectors flattens one nested selector onto its parent. A
// leading `&` splices the parent in (merging when the `&` compound carries
// its own type, id, classes or states); otherwise the child descends from
// the parent, or is its direct child after an explicit `>`.
fn style_combine_selectors(parent StyleSelector, child StyleSelector, explicit_child bool) !StyleSelector {
	if child.parts.len == 0 {
		return error('empty nested selector')
	}
	for part in child.parts[1..] {
		if part.parent_ref {
			return error('only a leading `&` is supported in nested selectors')
		}
	}
	if child.parts[0].parent_ref && explicit_child {
		// `> &` would need the parent on both sides of the `>`; only a
		// leading `&` is supported, so refuse instead of dropping the `>`.
		return error('`> &` is not supported; write `& > child` or `> child`')
	}
	if !child.parts[0].parent_ref {
		mut parts := parent.parts.clone()
		parts << child.parts
		mut combinators := parent.combinators.clone()
		combinators << if explicit_child {
			StyleCombinator.child
		} else {
			StyleCombinator.descendant
		}
		combinators << child.combinators
		return new_style_selector(parts, combinators)!
	}
	ref := child.parts[0]
	rest := child.parts[1..].clone()
	if ref.kind.len == 0 && ref.id.len == 0 && !ref.universal && ref.classes.len == 0
		&& ref.pseudos.len == 0 {
		// Bare `&`: splice the whole parent in.
		mut parts := parent.parts.clone()
		parts << rest
		mut combinators := parent.combinators.clone()
		if rest.len > 0 {
			combinators << if explicit_child {
				StyleCombinator.child
			} else {
				child.combinators[0]
			}
			combinators << child.combinators[1..]
		}
		return new_style_selector(parts, combinators)!
	}
	// `&` with its own type/id/classes/states: merge into the parent's last
	// compound, e.g. `&:hover` is the parent hovered.
	if parent.parts.len == 0 {
		return error('`&` has no parent selector')
	}
	merged := style_merge_compounds(parent.parts.last(), ref)!
	mut parts := parent.parts[..parent.parts.len - 1].clone()
	parts << merged
	parts << rest
	mut combinators := parent.combinators.clone()
	if rest.len > 0 {
		combinators << child.combinators[0]
		combinators << child.combinators[1..]
	}
	return new_style_selector(parts, combinators)!
}

fn style_merge_compounds(a StyleSelectorPart, b StyleSelectorPart) !StyleSelectorPart {
	mut kind := a.kind
	if b.kind.len > 0 {
		if a.kind.len > 0 && a.kind != b.kind {
			return error('nested `&` redefines the type "${a.kind}" as "${b.kind}"')
		}
		kind = b.kind
	}
	mut id := a.id
	if b.id.len > 0 {
		if a.id.len > 0 && a.id != b.id {
			return error('nested `&` redefines `#${a.id}` as `#${b.id}`')
		}
		id = b.id
	}
	mut classes := a.classes.clone()
	classes << b.classes
	mut pseudos := a.pseudos.clone()
	pseudos << b.pseudos
	return StyleSelectorPart{
		kind:      kind
		universal: a.universal && b.universal && kind.len == 0
		id:        id
		classes:   classes
		pseudos:   pseudos
	}
}

fn (mut p StyleParser) parse_selector_list() ![]StyleSelector {
	mut selectors := []StyleSelector{}
	for {
		p.skip_space_and_comments()!
		selectors << p.parse_selector()!
		p.skip_space_and_comments()!
		if !p.eof() && p.peek() == `,` {
			p.advance()
			continue
		}
		break
	}
	if selectors.len == 0 {
		return error(style_err(p.line, p.col, 'expected a selector'))
	}
	return selectors
}

fn (mut p StyleParser) parse_selector() !StyleSelector {
	mut parts := []StyleSelectorPart{}
	mut combinators := []StyleCombinator{}
	parts << p.parse_compound()!
	for {
		saved_pos := p.pos
		saved_line := p.line
		saved_col := p.col
		mut saw_space := false
		for !p.eof() {
			if is_style_space(p.peek()) {
				saw_space = true
				p.advance()
				continue
			}
			// A comment separates compounds like whitespace does.
			if p.peek() == `/` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `*` {
				p.skip_comment()!
				saw_space = true
				continue
			}
			break
		}
		if p.eof() {
			break
		}
		if p.peek() == `>` {
			p.advance()
			p.skip_space_and_comments()!
			combinators << .child
			parts << p.parse_compound()!
			continue
		}
		if p.peek() == `,` || p.peek() == `{` {
			break
		}
		if saw_space {
			// A compound must follow; anything else ends the selector so the
			// caller can report the real error (e.g. missing `{`). `&` is a
			// compound start too, so a non-leading `&` reaches the combiner
			// and fails there with a precise error.
			if p.peek() == `*` || is_style_name_start(p.peek()) || p.peek() == `#`
				|| p.peek() == `.` || p.peek() == `:` || p.peek() == `&` {
				combinators << .descendant
				parts << p.parse_compound()!
				continue
			}
			break
		}
		// No space, no `>`: selector is done. Restore (nothing consumed).
		p.pos = saved_pos
		p.line = saved_line
		p.col = saved_col
		break
	}
	return new_style_selector(parts, combinators)!
}

fn (mut p StyleParser) parse_compound() !StyleSelectorPart {
	if p.eof() {
		return error(style_err(p.line, p.col, 'expected a selector'))
	}
	mut kind := ''
	mut universal := false
	mut parent_ref := false
	if p.peek() == `&` {
		p.advance()
		parent_ref = true
	}
	if p.peek() == `*` {
		p.advance()
		universal = true
	} else if !p.eof() && is_style_name_start(p.peek()) {
		// Lowercased once here so matching never allocates per attempt.
		kind = p.parse_ident()!.to_lower()
	}
	mut id := ''
	mut classes := []string{}
	mut pseudos := []StylePseudo{}
	for !p.eof() {
		ch := p.peek()
		if ch == `#` {
			if id.len > 0 {
				return error(style_err(p.line, p.col, 'duplicate `#id` in one compound'))
			}
			p.advance()
			id = p.parse_ident()!
		} else if ch == `.` {
			p.advance()
			classes << p.parse_ident()!
		} else if ch == `:` {
			p.advance()
			// Allow `::` (treat like `:`) without failing QSS pastes.
			if !p.eof() && p.peek() == `:` {
				p.advance()
			}
			name := p.parse_ident()!.to_lower()
			mut arg := ''
			if !p.eof() && p.peek() == `(` {
				if name !in style_pseudo_with_arg && !style_plugin_has_pseudo(name) {
					return error(style_err(p.line, p.col, '`:${name}` takes no argument'))
				}
				p.advance()
				arg = p.parse_pseudo_arg()!
			} else if name in style_pseudo_with_arg {
				return error(style_err(p.line, p.col, '`:${name}` needs an argument'))
			}
			if name !in style_pseudo_no_arg && name !in style_pseudo_with_arg
				&& !style_plugin_has_pseudo(name) {
				return error(style_err(p.line, p.col, 'unknown pseudo-class `:${name}`'))
			}
			if name == 'nth-child' {
				arg = parse_nth_child_arg(arg)!
			}
			pseudos << StylePseudo{
				name: name
				arg:  arg
			}
		} else {
			break
		}
	}
	if kind.len == 0 && !universal && !parent_ref && id.len == 0 && classes.len == 0
		&& pseudos.len == 0 {
		return error(style_err(p.line, p.col, 'expected a type, `#id`, `.class` or `:state`'))
	}
	return StyleSelectorPart{
		kind:       kind
		universal:  universal
		id:         id
		classes:    classes
		pseudos:    pseudos
		parent_ref: parent_ref
	}
}

fn (mut p StyleParser) parse_pseudo_arg() !string {
	mut out := []u8{}
	p.skip_space_and_comments()!
	for !p.eof() && p.peek() != `)` {
		out << p.advance()
	}
	if p.eof() {
		return error(style_err(p.line, p.col, 'unclosed pseudo-class argument'))
	}
	p.advance() // `)`
	return out.bytestr().trim_space()
}

fn parse_nth_child_arg(raw string) !string {
	arg := raw.trim_space().to_lower()
	if arg in ['odd', 'even'] {
		return arg
	}
	mut digits := arg
	if digits.starts_with('+') {
		digits = digits[1..]
	}
	if digits.len == 0 {
		return error('`:nth-child` needs a number, `odd` or `even`')
	}
	for ch in digits.bytes() {
		if ch < `0` || ch > `9` {
			return error('`:nth-child` needs a number, `odd` or `even`')
		}
	}
	if digits.trim_left('0').len > 9 {
		return error('`:nth-child(${digits})` is too large')
	}
	number := digits.int()
	if number < 1 {
		return error('`:nth-child` starts at 1')
	}
	return number.str()
}

fn new_style_selector(parts []StyleSelectorPart, combinators []StyleCombinator) !StyleSelector {
	if parts.len == 0 {
		return error('empty selector')
	}
	if combinators.len != parts.len - 1 {
		return error('selector combinator mismatch')
	}
	mut ids := 0
	mut classish := 0
	mut types := 0
	for part in parts {
		if part.id.len > 0 {
			ids++
		}
		classish += part.classes.len + part.pseudos.len
		if part.kind.len > 0 {
			types++
		}
	}
	return StyleSelector{
		parts:       parts
		combinators: combinators
		specificity: ids * 1000000 + classish * 1000 + types
	}
}

// parse_keyframes parses `@keyframes name { stops }`. Stops are `from`,
// `to`, or a percentage (`0%`, `50%`); declarations inside follow the same
// grammar as a rule body.
fn (mut p StyleParser) parse_keyframes() !StyleKeyframes {
	at_line := p.line
	at_col := p.col
	for _ in 0 .. 10 {
		p.advance()
	}
	p.skip_space_and_comments()!
	name := p.parse_ident()!
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `{` {
		return error(style_err(p.line, p.col, 'expected `{` after keyframes name'))
	}
	p.advance()
	mut stops := []StyleKeyframe{}
	for {
		p.skip_space_and_comments()!
		if p.eof() {
			return error(style_err(p.line, p.col, 'unclosed `@keyframes`'))
		}
		if p.peek() == `}` {
			p.advance()
			break
		}
		stop_line := p.line
		stop_col := p.col
		mut token := ''
		for !p.eof() && p.peek() != `{` && p.peek() != ` ` && p.peek() != `\t`
			&& p.peek() != `\n` && p.peek() != `\r` {
			token += '${rune(p.peek())}'
			p.advance()
		}
		token = token.trim_space()
		if token.len == 0 {
			return error(style_err(stop_line, stop_col, 'expected a keyframe stop'))
		}
		progress := keyframe_stop_progress(token) or {
			return error(style_err(stop_line, stop_col, 'expected `from`, `to` or a percentage, got "${token}"'))
		}
		p.skip_space_and_comments()!
		if p.eof() || p.peek() != `{` {
			return error(style_err(p.line, p.col, 'expected `{` after keyframe stop'))
		}
		p.advance()
		mut declarations := []StyleDeclaration{}
		for {
			p.skip_space_and_comments()!
			if p.eof() {
				return error(style_err(p.line, p.col, 'unclosed keyframe'))
			}
			if p.peek() == `}` {
				p.advance()
				break
			}
			decl_line := p.line
			decl_col := p.col
			prop := p.parse_ident()!
			p.skip_space_and_comments()!
			if p.eof() || p.peek() != `:` {
				return error(style_err(p.line, p.col, 'expected `:` after property "${prop}"'))
			}
			p.advance()
			p.skip_space_and_comments()!
			value := p.parse_raw_value()!
			if value.trim_space().len == 0 {
				return error(style_err(decl_line, decl_col, 'property "${prop}" has an empty value'))
			}
			declarations << StyleDeclaration{
				prop:  prop.to_lower()
				value: value.trim_space()
				line:  decl_line
				col:   decl_col
			}
		}
		if declarations.len == 0 {
			return error(style_err(stop_line, stop_col, 'keyframe has no declarations'))
		}
		stops << StyleKeyframe{
			stop:         progress
			declarations: declarations
			line:         stop_line
			col:          stop_col
		}
	}
	for i in 1 .. stops.len {
		mut j := i
		for j > 0 && stops[j - 1].stop > stops[j].stop {
			tmp := stops[j]
			stops[j] = stops[j - 1]
			stops[j - 1] = tmp
			j--
		}
	}
	if stops.len == 0 {
		return error(style_err(at_line, at_col, '`@keyframes ${name}` has no stops'))
	}
	return StyleKeyframes{
		name:  name
		stops: stops
		line:  at_line
		col:   at_col
	}
}

fn keyframe_stop_progress(token string) ?f64 {
	lower := token.to_lower()
	if lower == 'from' {
		return 0.0
	}
	if lower == 'to' {
		return 1.0
	}
	if !token.ends_with('%') {
		return none
	}
	raw := token[..token.len - 1]
	number := raw.f64()
	if number < 0 || number > 100 {
		return none
	}
	return number / 100.0
}
