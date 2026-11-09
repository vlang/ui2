module ui2

import os

// P0 stylesheet parser: QSS/CSS-familiar selectors with ui2 extensions.
//
// Parses a stylesheet string (or `.u2ss` file via load_stylesheet) into a
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
	// has no type. universal is set for `*`.
	kind      string
	universal bool
	id        string
	classes   []string
	pseudos   []StylePseudo
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
	line         int
	col          int
}

pub struct Stylesheet {
pub mut:
	rules      []StyleRule
	variables  map[string]string
	light_vars map[string]string
	dark_vars  map[string]string
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
	pos  int
	line int = 1
	col  int = 1
}

// parse_stylesheet parses a stylesheet string into a Stylesheet.
pub fn parse_stylesheet(source string) !Stylesheet {
	mut parser := StyleParser{
		src: source
	}
	return parser.parse()!
}

// load_stylesheet reads a `.u2ss` file and parses it.
pub fn load_stylesheet(path string) !Stylesheet {
	source := os.read_file(path) or { return error('stylesheet: cannot read "${path}": ${err.msg()}') }
	return parse_stylesheet(source)!
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

fn (mut p StyleParser) parse() !Stylesheet {
	mut result := Stylesheet{
		variables:  map[string]string{}
		light_vars: map[string]string{}
		dark_vars:  map[string]string{}
	}
	for {
		p.skip_space_and_comments()!
		if p.eof() {
			break
		}
		// Variable definitions at top level: `@name:` or `--name:`.
		if p.peek() == `@` || (p.peek() == `-` && p.pos + 1 < p.src.len && p.src[p.pos + 1] == `-`) {
			name, value := p.parse_variable_def()!
			result.variables[name] = value
			continue
		}
		// Theme blocks: `light { ... }` / `dark { ... }`.
		if p.src[p.pos..].starts_with('light') || p.src[p.pos..].starts_with('dark') {
			mode, vars := p.parse_theme_block()!
			if mode == 'light' {
				for key, value in vars {
					result.light_vars[key] = value
				}
			} else {
				for key, value in vars {
					result.dark_vars[key] = value
				}
			}
			continue
		}
		rule := p.parse_rule()!
		result.rules << rule
	}
	return result
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

fn (mut p StyleParser) parse_rule() !StyleRule {
	start_line := p.line
	start_col := p.col
	selectors := p.parse_selector_list()!
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `{` {
		return error(style_err(p.line, p.col, 'expected `{` after selector'))
	}
	p.advance()
	mut declarations := []StyleDeclaration{}
	for {
		p.skip_space_and_comments()!
		if p.eof() {
			return error(style_err(p.line, p.col, 'unclosed rule block'))
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
		declarations << StyleDeclaration{
			prop:  prop.to_lower()
			value: value.trim_space()
			line:  decl_line
			col:   decl_col
		}
	}
	if declarations.len == 0 {
		return error(style_err(start_line, start_col, 'rule has no declarations'))
	}
	return StyleRule{
		selectors:    selectors
		declarations: declarations
		line:         start_line
		col:          start_col
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
			// caller can report the real error (e.g. missing `{`).
			if p.peek() == `*` || is_style_name_start(p.peek()) || p.peek() == `#`
				|| p.peek() == `.` || p.peek() == `:` {
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
	if p.peek() == `*` {
		p.advance()
		universal = true
	} else if is_style_name_start(p.peek()) {
		kind = p.parse_ident()!
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
				if name !in style_pseudo_with_arg {
					return error(style_err(p.line, p.col, '`:${name}` takes no argument'))
				}
				p.advance()
				arg = p.parse_pseudo_arg()!
			} else if name in style_pseudo_with_arg {
				return error(style_err(p.line, p.col, '`:${name}` needs an argument'))
			}
			if name !in style_pseudo_no_arg && name !in style_pseudo_with_arg {
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
	if kind.len == 0 && !universal && id.len == 0 && classes.len == 0 && pseudos.len == 0 {
		return error(style_err(p.line, p.col, 'expected a type, `#id`, `.class` or `:state`'))
	}
	return StyleSelectorPart{
		kind:      kind
		universal: universal
		id:        id
		classes:   classes
		pseudos:   pseudos
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
