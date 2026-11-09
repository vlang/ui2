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
	media        []MediaQuery
	containers   []ContainerQuery
	line         int
	col          int
}

pub struct Stylesheet {
pub mut:
	rules      []StyleRule
	variables  map[string]string
	light_vars map[string]string
	dark_vars  map[string]string
	imports    []string       // `@import` paths in source order, for load_stylesheet
	rule_index StyleRuleIndex // subject buckets; empty on hand-built sheets
}

// resolve_var reads a `@name` or `--name` variable: dark-mode value first
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

const style_pseudo_no_arg = ['hover', 'pressed', 'focused', 'disabled', 'enabled', 'checked', 'selected',
	'first-child', 'last-child', 'only-child', 'empty']

const style_pseudo_with_arg = ['nth-child']

struct StyleParser {
	src string
mut:
	pos        int
	line       int = 1
	col        int = 1
	variables  map[string]string
	light_vars map[string]string
	dark_vars  map[string]string
	imports    []string
}

// parse_stylesheet parses a stylesheet string into a Stylesheet.
pub fn parse_stylesheet(source string) !Stylesheet {
	mut parser := StyleParser{
		src:        source
		variables:  map[string]string{}
		light_vars: map[string]string{}
		dark_vars:  map[string]string{}
		imports:    []string{}
	}
	rules := parser.parse_block([]MediaQuery{}, []ContainerQuery{}, true)!
	return Stylesheet{
		rules:      rules
		variables:  parser.variables
		light_vars: parser.light_vars
		dark_vars:  parser.dark_vars
		imports:    parser.imports
		rule_index: stylesheet_index_rules(rules)
	}
}

// load_stylesheet reads a `.vss` file and its `@import` chain, splicing
// imported files in place (depth-first, each file once). Imports resolve
// relative to the importing file; cycles terminate on the second visit.
pub fn load_stylesheet(path string) !Stylesheet {
	mut visited := []string{}
	return load_stylesheet_file(path, mut visited)!
}

fn load_stylesheet_file(path string, mut visited []string) !Stylesheet {
	absolute := os.real_path(path)
	if absolute == '' {
		return error('stylesheet: cannot resolve "${path}"')
	}
	if absolute in visited {
		return Stylesheet{}
	}
	visited << absolute
	source := os.read_file(path) or {
		return error('stylesheet: cannot read "${path}": ${err.msg()}')
	}
	sheet := parse_stylesheet(source)!
	if sheet.imports.len == 0 {
		return sheet
	}
	base := os.dir(absolute)
	mut rules := []StyleRule{}
	mut variables := map[string]string{}
	mut light_vars := map[string]string{}
	mut dark_vars := map[string]string{}
	for name in sheet.imports {
		sub := load_stylesheet_file(os.join_path(base, name), mut visited)!
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
	}
	rules << sheet.rules
	for key, value in sheet.variables {
		variables[key] = value
	}
	for key, value in sheet.light_vars {
		light_vars[key] = value
	}
	for key, value in sheet.dark_vars {
		dark_vars[key] = value
	}
	return Stylesheet{
		rules:      rules
		variables:  variables
		light_vars: light_vars
		dark_vars:  dark_vars
		imports:    sheet.imports.clone()
		rule_index: stylesheet_index_rules(rules)
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
			p.advance()
			p.advance()
			mut closed := false
			for !p.eof() {
				if p.peek() == `*` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `/` {
					p.advance()
					p.advance()
					closed = true
					break
				}
				p.advance()
			}
			if !closed {
				return error(style_err(p.line, p.col, 'unclosed comment'))
			}
			continue
		}
		break
	}
}

// parse_block parses rules until `}` or the end of input. At the top level
// it also takes variables, theme blocks and `@import`s; inside query blocks
// only rules and nested blocks belong. Plugin at-rules expand to replacement
// source parsed recursively with the same media/container context.
fn (mut p StyleParser) parse_block(media []MediaQuery, containers []ContainerQuery, top_level bool) ![]StyleRule {
	return p.parse_block_inner(media, containers, top_level, top_level)
}

// parse_block_inner is parse_block with an independent EOF rule: fragments
// (at-rule expansions) end at EOF like top-level sheets, but only take
// rules and nested blocks like query bodies.
fn (mut p StyleParser) parse_block_inner(media []MediaQuery, containers []ContainerQuery, top_level bool, eof_ok bool) ![]StyleRule {
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
				for rule in p.parse_query_block(media, containers)! {
					rules << rule
				}
				continue
			}
			if name := p.plugin_at_rule_name() {
				prelude, body := p.capture_at_block(name)!
				replacement := style_plugin_expand_at_rule(name, prelude, body)!
				for rule in p.parse_fragment(replacement, media, containers)! {
					rules << rule
				}
				continue
			}
			if top_level {
				if p.src[p.pos..].starts_with('@import') && style_keyword_end(p.src, p.pos + 7) {
					p.imports << p.parse_import()!
					continue
				}
				if p.peek() == `@`
					|| (p.peek() == `-` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `-`) {
					name, value := p.parse_variable_def()!
					p.variables[name] = value
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
			mode, vars := p.parse_theme_block()!
			if mode == 'light' {
				for key, value in vars {
					p.light_vars[key] = value
				}
			} else {
				for key, value in vars {
					p.dark_vars[key] = value
				}
			}
			continue
		}
		for rule in p.parse_rule_guarded(media, containers)! {
			rules << rule
		}
	}
	return rules
}

// parse_fragment parses replacement source from an at-rule expansion with
// the enclosing query context. Only rules and nested query blocks belong in
// an expansion; variables and imports stay at the top level.
fn (mut p StyleParser) parse_fragment(source string, media []MediaQuery, containers []ContainerQuery) ![]StyleRule {
	mut sub := StyleParser{
		src: source
	}
	return sub.parse_block_inner(media, containers, false, true)
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
	if name == '' || !style_plugin_has_at_rule(name) {
		return none
	}
	return name
}

// capture_at_block consumes `@name`, its prelude, and its balanced `{...}`
// body, returning both as text. Braces inside strings and comments do not
// count.
fn (mut p StyleParser) capture_at_block(name string) !(string, string) {
	for _ in 0 .. name.len + 1 {
		p.advance()
	}
	mut prelude := []u8{}
	for !p.eof() && p.peek() != `{` {
		prelude << p.advance()
	}
	if p.eof() {
		return error(style_err(p.line, p.col, 'expected `{` after "@${name}"'))
	}
	p.advance()
	mut body := []u8{}
	mut depth := 1
	mut quote := u8(0)
	mut line_comment := false
	for !p.eof() && depth > 0 {
		ch := p.peek()
		if line_comment {
			p.advance()
			if ch == `\n` {
				line_comment = false
			}
			continue
		}
		if quote != 0 {
			p.advance()
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			body << p.advance()
			continue
		}
		if ch == `/` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `/` {
			line_comment = true
			p.advance()
			continue
		}
		if ch == `/` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `*` {
			p.advance()
			p.advance()
			mut closed := false
			for !p.eof() {
				if p.peek() == `*` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `/` {
					p.advance()
					p.advance()
					closed = true
					break
				}
				p.advance()
			}
			if !closed {
				return error(style_err(p.line, p.col, 'unclosed comment'))
			}
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
		return error(style_err(p.line, p.col, 'unclosed "@${name}" block'))
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
fn (mut p StyleParser) parse_theme_block() !(string, map[string]string) {
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
	mut vars := map[string]string{}
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
			vars[name] = value
			continue
		}
		return error(style_err(p.line, p.col, 'only variables are allowed inside `${mode}`'))
	}
	return mode, vars
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
// strings survive), consuming the `;`.
fn (mut p StyleParser) parse_raw_value() !string {
	mut out := []u8{}
	mut depth := 0
	mut quote := u8(0)
	for !p.eof() {
		ch := p.peek()
		if quote != 0 {
			out << p.advance()
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			out << p.advance()
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
fn (mut p StyleParser) parse_rule_guarded(media []MediaQuery, containers []ContainerQuery) ![]StyleRule {
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
	return p.parse_rule_body(selectors, start_line, start_col, media, containers)!
}

fn (mut p StyleParser) parse_rule_body(selectors []StyleSelector, start_line int, start_col int, media []MediaQuery, containers []ContainerQuery) ![]StyleRule {
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
			for rule in p.parse_nested_rule(selectors, media, containers)! {
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
		rules << StyleRule{
			selectors:    selectors
			declarations: declarations
			media:        media.clone()
			containers:   containers.clone()
			line:         start_line
			col:          start_col
		}
	}
	rules << nested
	return rules
}

// nested_rule_start reports whether a rule body continues with a nested
// rule rather than a declaration: `&`, `.class`, `#id`, `:state`, `*`, `>`
// or a type name that is not followed by `:`.
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
	saved_pos := p.pos
	saved_line := p.line
	saved_col := p.col
	p.parse_ident() or {
		p.pos = saved_pos
		p.line = saved_line
		p.col = saved_col
		return false
	}
	p.skip_space_and_comments() or {
		p.pos = saved_pos
		p.line = saved_line
		p.col = saved_col
		return false
	}
	is_decl := !p.eof() && p.peek() == `:`
	p.pos = saved_pos
	p.line = saved_line
	p.col = saved_col
	return !is_decl
}

// parse_nested_rule parses one nested rule after its parent's selectors,
// combining each nested selector with each parent selector.
fn (mut p StyleParser) parse_nested_rule(parents []StyleSelector, media []MediaQuery, containers []ContainerQuery) ![]StyleRule {
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
	return p.parse_rule_body(selectors, start_line, start_col, media, containers)!
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
		for !p.eof() && is_style_space(p.peek()) {
			saw_space = true
			p.advance()
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
