module ui2

pub struct QNode {
pub mut:
	tag      string
	id       string
	props    map[string]string
	children []&QNode
mut:
	expressions    map[string]&QExpression
	property_types map[string]string
	property_order []string
	line           int
	path           string
}

enum QExpressionKind {
	literal
	path
	call
	unary
	binary
	conditional
	interpolation
}

struct QInterpolationPart {
	text string
	expr &QExpression = unsafe { nil }
}

struct QExpression {
	kind   QExpressionKind
	value  string
	line   int
	left   &QExpression = unsafe { nil }
	right  &QExpression = unsafe { nil }
	third  &QExpression = unsafe { nil }
	args   []&QExpression
	parts  []QInterpolationPart
	quoted bool
}

pub fn (node &QNode) find(id string) ?&QNode {
	if node.id == id {
		return unsafe { node }
	}
	for child in node.children {
		found := child.find(id) or { continue }
		return found
	}
	return none
}

pub fn (node &QNode) prop(key string) string {
	return node.props[key] or { '' }
}

pub fn (node &QNode) prop_or(key string, default_ string) string {
	return node.props[key] or { default_ }
}

pub fn (node &QNode) prop_int(key string) int {
	s := node.prop(key)
	if s.len == 0 {
		return 0
	}
	return s.int()
}

pub fn (node &QNode) prop_f64(key string) f64 {
	s := node.prop(key)
	if s.len == 0 {
		return 0.0
	}
	return s.f64()
}

pub fn (node &QNode) prop_bool(key string) bool {
	return node.prop(key) == 'true'
}

pub fn parse_hex_color(s string) u32 {
	raw := if s.starts_with('#') { s[1..] } else { s }
	if raw.len != 6 {
		return 0xFFFFFF
	}
	mut val := u32(0)
	for c in raw {
		val = val << 4
		if c >= `0` && c <= `9` {
			val |= u32(c - `0`)
		} else if c >= `a` && c <= `f` {
			val |= u32(c - `a` + 10)
		} else if c >= `A` && c <= `F` {
			val |= u32(c - `A` + 10)
		} else {
			return 0xFFFFFF
		}
	}
	return val
}

enum TokenKind {
	ident
	string_lit
	number
	lbrace
	rbrace
	colon
	lparen
	rparen
	comma
	question
	plus
	minus
	star
	slash
	percent
	bang
	eq_eq
	bang_eq
	lt
	lte
	gt
	gte
	and_and
	or_or
	eof
}

struct Token {
	kind TokenKind
	val  string
	line int
}

struct Lexer {
	src string
mut:
	pos  int
	line int = 1
}

fn (mut l Lexer) peek() u8 {
	if l.pos >= l.src.len {
		return 0
	}
	return l.src[l.pos]
}

fn (mut l Lexer) advance() u8 {
	c := l.src[l.pos]
	l.pos++
	if c == `\n` {
		l.line++
	}
	return c
}

fn (mut l Lexer) skip_whitespace_and_comments() {
	for l.pos < l.src.len {
		c := l.src[l.pos]
		if c == ` ` || c == `\t` || c == `\r` || c == `\n` {
			l.advance()
		} else if c == `/` && l.pos + 1 < l.src.len && l.src[l.pos + 1] == `/` {
			for l.pos < l.src.len && l.src[l.pos] != `\n` {
				l.pos++
			}
		} else {
			break
		}
	}
}

fn (mut l Lexer) read_string() !Token {
	line := l.line
	l.advance() // skip opening quote
	mut val := []u8{}
	for l.pos < l.src.len {
		c := l.advance()
		if c == `\\` && l.pos < l.src.len {
			next := l.advance()
			match next {
				`n` { val << `\n` }
				`t` { val << `\t` }
				`\\` { val << `\\` }
				`"` { val << `"` }
				else { val << next }
			}
		} else if c == `"` {
			return Token{.string_lit, val.bytestr(), line}
		} else {
			val << c
		}
	}
	return error('unterminated string at line ${line}')
}

fn is_ident_char(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`)
		|| c == `_` || c == `-` || c == `.` || c == `#`
}

fn is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

fn (mut l Lexer) read_ident() Token {
	line := l.line
	start := l.pos
	for l.pos < l.src.len && is_ident_char(l.src[l.pos]) {
		if l.src[l.pos] == `-` && l.pos > start {
			prefix := unsafe { l.src[start..l.pos] }
			// Keep legacy hyphenated ids (`first-name`) while still allowing
			// compact model arithmetic (`app.count-1`, `index-1`).
			if prefix.contains('.') || prefix == 'index' {
				break
			}
		}
		l.pos++
	}
	return Token{.ident, l.src[start..l.pos].clone(), line}
}

fn (mut l Lexer) read_number() Token {
	line := l.line
	start := l.pos
	mut saw_dot := false
	for l.pos < l.src.len {
		c := l.src[l.pos]
		if is_digit(c) {
			l.pos++
		} else if c == `.` && !saw_dot {
			saw_dot = true
			l.pos++
		} else {
			break
		}
	}
	return Token{.number, l.src[start..l.pos].clone(), line}
}

fn tokenize(source string) ![]Token {
	mut l := Lexer{
		src: source
	}
	mut tokens := []Token{}
	for {
		l.skip_whitespace_and_comments()
		if l.pos >= l.src.len {
			tokens << Token{.eof, '', l.line}
			break
		}
		c := l.peek()
		match c {
			`{` {
				tokens << Token{.lbrace, '{', l.line}
				l.advance()
			}
			`}` {
				tokens << Token{.rbrace, '}', l.line}
				l.advance()
			}
			`:` {
				tokens << Token{.colon, ':', l.line}
				l.advance()
			}
			`(` {
				tokens << Token{.lparen, '(', l.line}
				l.advance()
			}
			`)` {
				tokens << Token{.rparen, ')', l.line}
				l.advance()
			}
			`,` {
				tokens << Token{.comma, ',', l.line}
				l.advance()
			}
			`?` {
				tokens << Token{.question, '?', l.line}
				l.advance()
			}
			`+` {
				tokens << Token{.plus, '+', l.line}
				l.advance()
			}
			`-` {
				tokens << Token{.minus, '-', l.line}
				l.advance()
			}
			`*` {
				tokens << Token{.star, '*', l.line}
				l.advance()
			}
			`%` {
				tokens << Token{.percent, '%', l.line}
				l.advance()
			}
			`/` {
				tokens << Token{.slash, '/', l.line}
				l.advance()
			}
			`!` {
				line := l.line
				l.advance()
				if l.peek() == `=` {
					l.advance()
					tokens << Token{.bang_eq, '!=', line}
				} else {
					tokens << Token{.bang, '!', line}
				}
			}
			`=` {
				line := l.line
				l.advance()
				if l.peek() != `=` {
					return error('expected `==` at line ${line}')
				}
				l.advance()
				tokens << Token{.eq_eq, '==', line}
			}
			`<` {
				line := l.line
				l.advance()
				if l.peek() == `=` {
					l.advance()
					tokens << Token{.lte, '<=', line}
				} else {
					tokens << Token{.lt, '<', line}
				}
			}
			`>` {
				line := l.line
				l.advance()
				if l.peek() == `=` {
					l.advance()
					tokens << Token{.gte, '>=', line}
				} else {
					tokens << Token{.gt, '>', line}
				}
			}
			`&` {
				line := l.line
				l.advance()
				if l.peek() != `&` {
					return error('expected `&&` at line ${line}')
				}
				l.advance()
				tokens << Token{.and_and, '&&', line}
			}
			`|` {
				line := l.line
				l.advance()
				if l.peek() != `|` {
					return error('expected `||` at line ${line}')
				}
				l.advance()
				tokens << Token{.or_or, '||', line}
			}
			`"` {
				tokens << l.read_string()!
			}
			else {
				if is_digit(c) {
					tokens << l.read_number()
				} else if is_ident_char(c) {
					tokens << l.read_ident()
				} else {
					return error('unexpected character `${[c].bytestr()}` at line ${l.line}')
				}
			}
		}
	}
	return tokens
}

struct Parser {
	tokens []Token
mut:
	pos int
}

fn (p &Parser) at() Token {
	if p.pos >= p.tokens.len {
		return Token{.eof, '', 0}
	}
	return p.tokens[p.pos]
}

fn (mut p Parser) eat(kind TokenKind) !Token {
	t := p.at()
	if t.kind != kind {
		return error('expected ${kind}, got ${t.kind} ("${t.val}") at line ${t.line}')
	}
	p.pos++
	return t
}

fn (mut p Parser) parse_node() !&QNode {
	tag := p.eat(.ident)!
	p.eat(.lbrace)!
	mut node := &QNode{
		tag: tag.val
		line: tag.line
	}
	for p.at().kind != .rbrace && p.at().kind != .eof {
		// Lookahead: if IDENT followed by '{', it's a child node; if followed by ':', it's a property
		if p.at().kind == .ident {
			if p.at().val == 'property' {
				p.eat(.ident)!
				type_token := p.eat(.ident)!
				name_token := p.eat(.ident)!
				p.eat(.colon)!
				expr := p.parse_expression()!
				node.expressions[name_token.val] = expr
				node.property_types[name_token.val] = type_token.val
				node.property_order << name_token.val
				node.props[name_token.val] = expression_text(expr)
			} else if p.pos + 1 < p.tokens.len && p.tokens[p.pos + 1].kind == .lbrace {
				child := p.parse_node()!
				node.children << child
			} else if p.pos + 1 < p.tokens.len && p.tokens[p.pos + 1].kind == .colon {
				key := p.eat(.ident)!
				p.eat(.colon)!
				expr := p.parse_expression()!
				val := expression_text(expr)
				if key.val == 'id' {
					if expr.kind !in [.literal, .path] {
						return error('id must be a literal identifier at line ${key.line}')
					}
					node.id = val
				}
				node.props[key.val] = val
				node.expressions[key.val] = expr
			} else {
				return error('unexpected token "${p.at().val}" at line ${p.at().line}')
			}
		} else {
			return error('unexpected token "${p.at().val}" at line ${p.at().line}')
		}
	}
	p.eat(.rbrace)!
	return node
}

fn expression_text(expr &QExpression) string {
	return match expr.kind {
		.literal, .path { expr.value }
		.call { expr.value + '(' + expr.args.map(expression_text(it)).join(', ') + ')' }
		.unary { expr.value + expression_text(expr.left) }
		.binary { '${expression_text(expr.left)} ${expr.value} ${expression_text(expr.right)}' }
		.conditional {
			'${expression_text(expr.left)} ? ${expression_text(expr.right)} : ${expression_text(expr.third)}'
		}
		.interpolation {
			mut out := ''
			for part in expr.parts {
				out += if isnil(part.expr) {
					part.text
				} else {
					r'${' + expression_text(part.expr) + '}'
				}
			}
			out
		}
	}
}

fn (mut p Parser) parse_expression() !&QExpression {
	return p.parse_conditional()
}

fn (mut p Parser) parse_conditional() !&QExpression {
	condition := p.parse_or()!
	if p.at().kind != .question {
		return condition
	}
	line := p.eat(.question)!.line
	when_true := p.parse_expression()!
	p.eat(.colon)!
	when_false := p.parse_expression()!
	return &QExpression{
		kind: .conditional
		line: line
		left: condition
		right: when_true
		third: when_false
	}
}

fn (mut p Parser) parse_or() !&QExpression {
	mut left := p.parse_and()!
	for p.at().kind == .or_or {
		op := p.at()
		p.pos++
		left = &QExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_and()! }
	}
	return left
}

fn (mut p Parser) parse_and() !&QExpression {
	mut left := p.parse_equality()!
	for p.at().kind == .and_and {
		op := p.at()
		p.pos++
		left = &QExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_equality()! }
	}
	return left
}

fn (mut p Parser) parse_equality() !&QExpression {
	mut left := p.parse_comparison()!
	for p.at().kind in [.eq_eq, .bang_eq] {
		op := p.at()
		p.pos++
		left = &QExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_comparison()! }
	}
	return left
}

fn (mut p Parser) parse_comparison() !&QExpression {
	mut left := p.parse_term()!
	for p.at().kind in [.lt, .lte, .gt, .gte] {
		op := p.at()
		p.pos++
		left = &QExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_term()! }
	}
	return left
}

fn (mut p Parser) parse_term() !&QExpression {
	mut left := p.parse_factor()!
	for p.at().kind in [.plus, .minus] {
		op := p.at()
		p.pos++
		left = &QExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_factor()! }
	}
	return left
}

fn (mut p Parser) parse_factor() !&QExpression {
	mut left := p.parse_unary()!
	for p.at().kind in [.star, .slash, .percent] {
		op := p.at()
		p.pos++
		left = &QExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_unary()! }
	}
	return left
}

fn (mut p Parser) parse_unary() !&QExpression {
	if p.at().kind in [.bang, .minus] {
		op := p.at()
		p.pos++
		return &QExpression{ kind: .unary, value: op.val, line: op.line, left: p.parse_unary()! }
	}
	return p.parse_primary()
}

fn (mut p Parser) parse_primary() !&QExpression {
	t := p.at()
	match t.kind {
		.string_lit {
			p.pos++
			return parse_interpolated_string(t.val, t.line)!
		}
		.ident, .number {
			p.pos++
			if p.at().kind == .lparen {
				p.pos++
				mut args := []&QExpression{}
				if p.at().kind != .rparen {
					for {
						args << p.parse_expression()!
						if p.at().kind != .comma {
							break
						}
						p.pos++
					}
				}
				p.eat(.rparen)!
				return &QExpression{ kind: .call, value: t.val, line: t.line, args: args }
			}
			return &QExpression{
				kind: if t.kind == .number || t.val in ['true', 'false'] {
					QExpressionKind.literal
				} else {
					QExpressionKind.path
				}
				value: t.val
				line: t.line
			}
		}
		.lparen {
			p.pos++
			expr := p.parse_expression()!
			p.eat(.rparen)!
			return expr
		}
		else {
			return error('expected expression, got ${t.kind} ("${t.val}") at line ${t.line}')
		}
	}
}

fn parse_interpolated_string(value string, line int) !&QExpression {
	if !value.contains(r'${') {
		return &QExpression{ kind: .literal, value: value, line: line, quoted: true }
	}
	mut parts := []QInterpolationPart{}
	mut cursor := 0
	for cursor < value.len {
		start_relative := value[cursor..].index(r'${') or {
			parts << QInterpolationPart{ text: value[cursor..] }
			break
		}
		start := cursor + start_relative
		if start > cursor {
			parts << QInterpolationPart{ text: value[cursor..start] }
		}
		end_relative := value[start + 2..].index('}') or {
			return error('unterminated interpolation at line ${line}')
		}
		end := start + 2 + end_relative
		raw_tokens := tokenize(value[start + 2..end])!
		mut tokens := []Token{cap: raw_tokens.len}
		for token in raw_tokens {
			tokens << Token{
				...token
				line: line + token.line - 1
			}
		}
		mut parser := Parser{ tokens: tokens }
		expr := parser.parse_expression()!
		parser.eat(.eof) or { return error('invalid interpolation at line ${line}: ${err}') }
		parts << QInterpolationPart{ expr: expr }
		cursor = end + 1
	}
	return &QExpression{ kind: .interpolation, line: line, parts: parts }
}

pub fn parse_qml(source string) !&QNode {
	tokens := tokenize(source)!
	mut p := Parser{
		tokens: tokens
	}
	mut node := p.parse_node()!
	p.eat(.eof)!
	assign_qml_paths(mut node, '0')
	return node
}

fn assign_qml_paths(mut node QNode, path string) {
	node.path = path
	for index, mut child in node.children {
		assign_qml_paths(mut child, '${path}.${index}')
	}
}

pub fn element_from_qml(source string, frame Rect) !Element {
	node := parse_qml(source)!
	return node_to_element(node, frame)!
}

pub fn element_from_qnode(node &QNode, frame Rect) !Element {
	return node_to_element(node, frame)!
}

fn node_to_element(node &QNode, frame Rect) !Element {
	resolved := q_frame(node, frame)
	el := node_to_element_base(node, resolved)!
	key := node.prop('key')
	menu := q_menu(node)
	secure := node.prop_bool('secure')
	return Element{
		...el
		action_id: if el.action_id.len > 0 { el.action_id } else { node.prop('on_tap') }
		key: key
		menu: if menu.len > 0 { menu } else { el.menu }
		secure: secure
		clickable: node.prop_bool('clickable')
		draggable: node.prop_bool('draggable')
		long_press: node.prop_bool('long_press')
		swipe_left: node.prop_bool('swipe_left')
		rotation: node.prop_or('rotation', '0').f64()
		cursor: node.prop('cursor')
		tooltip: node.prop('tooltip')
		hidden: node.prop_bool('hidden')
		enabled: node.prop('enabled') != 'false'
		accessibility_role: node.prop_or('accessibility_role', el.accessibility_role)
		accessibility_label: node.prop_or('accessibility_label', el.accessibility_label)
		accessibility_value: node.prop_or('accessibility_value', el.accessibility_value)
		native_style: node.prop_bool('native')
		autocorrect: node.prop('autocorrect') != 'false'
		padding_left: node.prop_or('pad_left', '12').f64()
	}
}

// q_menu collects MenuItem children as a right-click context menu.
fn q_menu(node &QNode) []MenuEntry {
	mut out := []MenuEntry{}
	for child in node.children {
		if child.tag == 'MenuItem' {
			out << MenuEntry{
				id: child.prop_or('on_tap', child.id)
				title: child.prop('text')
			}
		}
	}
	return out
}

fn node_to_element_base(node &QNode, frame Rect) !Element {
	local := rect(0, 0, frame.width, frame.height)
	match node.tag {
		'Screen' {
			return screen(q_color(node, 'background', 0xffffff), q_children(node, local)!)
		}
		'Column' {
			return q_column(node, frame)!
		}
		'Row' {
			return q_row(node, frame)!
		}
		'BoxLayout' {
			return q_box_layout(node, frame)!
		}
		'FloatLayout', 'RelativeLayout' {
			return q_float_layout(node, frame)!
		}
		'GridLayout' {
			return q_grid(node, frame)!
		}
		'AnchorLayout' {
			return q_anchor(node, frame)!
		}
		'StackLayout' {
			return q_stack(node, frame)!
		}
		'Scroll' {
			children := q_children(node, local)!
			if node.prop_bool('persistent') {
				return Element{
					...scroll_persistent(node.id, frame, q_color(node, 'background', 0xffffff), children)
					box: q_box(node)
				}
			}
			return Element{
				...scroll(node.id, frame, q_color(node, 'background', 0xffffff), children)
				box: q_box(node)
			}
		}
		'View', 'Rectangle' {
			return view(node.id, frame, q_box(node), q_children(node, local)!)
		}
		'Label' {
			return label(node.id, node.prop('text'), frame, q_text_style(node))
		}
		'Image' {
			return image(node.id, node.prop_or('source', node.prop('path')), frame)
		}
		'ProgressBar' {
			return progress_bar(
				id: node.id
				frame: frame
				value: node.prop_or('value', '0').f64()
				max: node.prop_or('max', '100').f64()
				background: q_color(node, 'background', 0xe2e8f0)
				color: q_color(node, 'color', 0x3b82f6)
				radius: node.prop_or('corner_radius', node.prop_or('radius', '4')).f64()
			)
		}
		'Slider' {
			action_id := if node.prop('on_change').len > 0 {
				node.prop('on_change')
			} else {
				node.prop('on_tap')
			}
			return slider(
				id: node.id
				action_id: action_id
				frame: frame
				min: node.prop_or('min', '0').f64()
				max: node.prop_or('max', '100').f64()
				value: node.prop_or('value', '0').f64()
				step: node.prop_or('step', '0').f64()
				orientation: q_orientation(node.prop('orientation'))
				padding: node.prop_or('padding', '16').f64()
				value_track: node.prop_bool('value_track')
				style: SliderStyle{
					track_color: q_color(node, 'background', 0xcbd5e1)
					value_track_color: q_color(node, 'value_track_color', q_color(node, 'color', 0x93c5fd))
					thumb_color: q_color(node, 'thumb_color', 0x2563eb)
					track_width: node.prop_or('track_width', '4').f64()
					thumb_size: node.prop_or('thumb_size', '20').f64()
				}
			)
		}
		'Switch' {
			action_id := if node.prop('on_active').len > 0 {
				node.prop('on_active')
			} else if node.prop('on_change').len > 0 {
				node.prop('on_change')
			} else {
				node.prop('on_tap')
			}
			return switch_control(
				id: node.id
				action_id: action_id
				frame: frame
				active: node.prop_bool('active')
				style: SwitchStyle{
					inactive_track_color: q_color(node, 'inactive_color', 0xcbd5e1)
					active_track_color: q_color(node, 'active_color', q_color(node, 'color', 0x22c55e))
					thumb_color: q_color(node, 'thumb_color', 0xffffff)
					disabled_track_color: q_color(node, 'disabled_track_color', 0xe2e8f0)
					disabled_thumb_color: q_color(node, 'disabled_thumb_color', 0xf8fafc)
				}
			)
		}
		'ToggleButton' {
			action_id := if node.prop('on_state').len > 0 {
				node.prop('on_state')
			} else {
				node.prop('on_tap')
			}
			normal_box := q_box(node)
			return toggle_button(
				id: node.id
				action_id: action_id
				title: node.prop('text')
				frame: frame
				pressed: node.prop_bool('pressed') || node.prop('state') == 'down'
				group: node.prop('group')
				allow_no_selection: node.prop_or('allow_no_selection', 'true') == 'true'
				box: normal_box
				down_box: BoxStyle{
					bg: q_color(node, 'down_background', 0x2563eb)
					radius: node.prop_or('down_corner_radius', normal_box.radius.str()).f64()
				}
				text_style: q_text_style(node)
				down_text_style: TextStyle{
					...q_text_style(node)
					color: q_color(node, 'down_color', 0xffffff)
				}
				native_style: node.prop_bool('native')
			)
		}
		'Button' {
			return Element{
				...button(node.id, node.prop('text'), frame, q_box(node), q_text_style(node))
				action_id: node.prop('on_tap')
			}
		}
		'MessageBox' {
			return q_message_box(node, frame)
		}
		'Checkbox' {
			return Element{
				...checkbox(node.id, node.prop('text'), node.prop_bool('checked'), frame, q_text_style(node))
				action_id: node.prop('on_tap')
			}
		}
		'Spinner' {
			action_id := if node.prop('on_text').len > 0 {
				node.prop('on_text')
			} else if node.prop('on_change').len > 0 {
				node.prop('on_change')
			} else {
				node.prop('on_tap')
			}
			return spinner(
				id: node.id
				action_id: action_id
				frame: frame
				text: node.prop('text')
				values: q_options(node)
				text_autoupdate: node.prop_bool('text_autoupdate')
				box: q_box(node)
				text_style: q_text_style(node)
			)
		}
		'Dropdown' {
			action_id := if node.prop('on_change').len > 0 {
				node.prop('on_change')
			} else {
				node.prop('on_tap')
			}
			return Element{
				...dropdown(node.id, node.prop('text'), q_options(node), frame, q_box(node), q_text_style(node))
				action_id: action_id
			}
		}
		'TextArea' {
			return Element{
				kind: .text_area
				id: node.id
				action_id: node.prop('on_change')
				text: node.prop('text')
				frame: frame
				box: q_box(node)
				text_style: q_text_style(node)
				readonly: node.prop('editable') == 'false'
				emit_change: node.prop('on_change').len > 0
			}
		}
		'TextField' {
			id := node.id
			change_id := node.prop('on_change')
			submit_id := node.prop('on_submit')
			keyboard := q_keyboard(node.prop('keyboard'))
			if node.prop_bool('emit_change') || node.prop('on_change').len > 0 {
				return Element{
					...text_field_with_change_and_submit(id, submit_id, node.prop('placeholder'), node.prop('text'), frame, q_box(node), q_text_style(node), keyboard)
					action_id: change_id
				}
			}
			if submit_id.len > 0 {
				return text_field_with_submit(id, submit_id, node.prop('placeholder'), node.prop('text'), frame, q_box(node), q_text_style(node), keyboard)
			}
			return text_field(id, node.prop('placeholder'), node.prop('text'), frame, q_box(node), q_text_style(node), keyboard)
		}
		else {
			return view(node.id, frame, q_box(node), q_children(node, local)!)
		}
	}
}

fn q_orientation(raw string) Orientation {
	return if raw == 'vertical' { .vertical } else { .horizontal }
}

// q_message_box maps the declarative dialog onto custom_message_box. Its
// Button children become the dialog's actions instead of free-standing views,
// so the card owns their layout.
fn q_message_box(node &QNode, frame Rect) Element {
	mut actions := []MessageBoxAction{}
	for child in node.children {
		if child.tag != 'Button' {
			continue
		}
		actions << MessageBoxAction{
			id: child.id
			action_id: child.prop('on_tap')
			title: child.prop('text')
		}
	}
	return custom_message_box(
		id: node.id
		frame: frame
		title: node.prop('title')
		text: node.prop('text')
		hidden: node.prop_bool('hidden')
		width: q_dimension(node, 'dialog_width', 300)
		height: q_dimension(node, 'dialog_height', 150)
		actions: actions
	)
}

fn q_children(node &QNode, frame Rect) ![]Element {
	mut out := []Element{}
	for child in node.children {
		if child.tag == 'MenuItem' || child.tag == 'Option' {
			continue // context menu entries, not child views
		}
		out << node_to_element(child, frame)!
	}
	return out
}

fn q_options(node &QNode) []string {
	mut options := []string{}
	for child in node.children {
		if child.tag == 'Option' {
			options << child.prop('text')
		}
	}
	return options
}

fn q_keyboard(raw string) int {
	return match raw {
		'decimal', 'numeric', 'number' { keyboard_decimal }
		else { keyboard_default }
	}
}

fn q_column(node &QNode, frame Rect) !Element {
	container := q_frame(node, frame)
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	mut y := padding
	mut children := []Element{}
	for child in node.children {
		if child.tag == 'MenuItem' || child.tag == 'Option' {
			continue
		}
		child_h := q_dimension(child, 'height', 32)
		child_w := q_dimension(child, 'width', container.width - padding * 2)
		child_frame := rect(padding, y, child_w, child_h)
		children << node_to_element(child, child_frame)!
		y += child_h + spacing
	}
	return view(node.id, container, q_box(node), children)
}

fn q_row(node &QNode, frame Rect) !Element {
	container := q_frame(node, frame)
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	mut x := padding
	mut children := []Element{}
	for child in node.children {
		if child.tag == 'MenuItem' || child.tag == 'Option' {
			continue
		}
		child_w := q_dimension(child, 'width', 80)
		child_h := q_dimension(child, 'height', container.height - padding * 2)
		child_frame := rect(x, padding, child_w, child_h)
		children << node_to_element(child, child_frame)!
		x += child_w + spacing
	}
	return view(node.id, container, q_box(node), children)
}

fn q_box_layout_child(node &QNode) !BoxLayoutChild {
	return BoxLayoutChild{
		element: Element{
			frame: rect(0, 0, q_dimension(node, 'width', 80), q_dimension(node, 'height', 32))
		}
		size_hint_x: node.prop_or('size_hint_x', '1').f64()
		size_hint_y: node.prop_or('size_hint_y', '1').f64()
		minimum_width: node.prop_or('size_hint_min_x', '-1').f64()
		minimum_height: node.prop_or('size_hint_min_y', '-1').f64()
		maximum_width: node.prop_or('size_hint_max_x', '-1').f64()
		maximum_height: node.prop_or('size_hint_max_y', '-1').f64()
		horizontal_align: box_alignment(node.prop_or('align_x', 'start'))!
		vertical_align: box_alignment(node.prop_or('align_y', 'start'))!
	}
}

fn q_box_layout_config(node &QNode, frame Rect, children []BoxLayoutChild) !BoxLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	return BoxLayoutConfig{
		id: node.id
		frame: frame
		box: q_box(node)
		orientation: box_orientation(node.prop_or('orientation', 'horizontal'))!
		padding: BoxPadding{
			left: node.prop_or('padding_left', padding.str()).f64()
			top: node.prop_or('padding_top', padding.str()).f64()
			right: node.prop_or('padding_right', padding.str()).f64()
			bottom: node.prop_or('padding_bottom', padding.str()).f64()
		}
		spacing: node.prop_or('spacing', '0').f64()
		children: children
	}
}

fn q_box_layout(node &QNode, frame Rect) !Element {
	mut visible := []&QNode{}
	mut items := []BoxLayoutChild{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		visible << child
		items << q_box_layout_child(child)!
	}
	config := q_box_layout_config(node, rect(0, 0, frame.width, frame.height), items)!
	frames := box_layout_frames(config)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, q_box(node), children)
}

fn q_float_axis_hint(node &QNode, start_keys []string, center_key string, end_key string) FloatAxisHint {
	for key in start_keys {
		if value := node.props[key] {
			return FloatAxisHint{ anchor: .start, value: value.f64() }
		}
	}
	if value := node.props[center_key] {
		return FloatAxisHint{ anchor: .center, value: value.f64() }
	}
	if value := node.props[end_key] {
		return FloatAxisHint{ anchor: .end, value: value.f64() }
	}
	return FloatAxisHint{}
}

fn q_float_layout_child(node &QNode) FloatLayoutChild {
	return FloatLayoutChild{
		element: Element{
			frame: rect(q_dimension(node, 'x', 0), q_dimension(node, 'y', 0), q_dimension(node, 'width', 80), q_dimension(node, 'height', 32))
		}
		size_hint_x: node.prop_or('size_hint_x', '1').f64()
		size_hint_y: node.prop_or('size_hint_y', '1').f64()
		minimum_width: node.prop_or('size_hint_min_x', '-1').f64()
		minimum_height: node.prop_or('size_hint_min_y', '-1').f64()
		maximum_width: node.prop_or('size_hint_max_x', '-1').f64()
		maximum_height: node.prop_or('size_hint_max_y', '-1').f64()
		x_hint: q_float_axis_hint(node, ['pos_hint_x'], 'pos_hint_center_x', 'pos_hint_right')
		y_hint: q_float_axis_hint(node, ['pos_hint_y', 'pos_hint_top'], 'pos_hint_center_y', 'pos_hint_bottom')
	}
}

fn q_float_layout_config(node &QNode, frame Rect, children []FloatLayoutChild) FloatLayoutConfig {
	return FloatLayoutConfig{
		id: node.id
		frame: frame
		box: q_box(node)
		children: children
	}
}

fn q_float_layout(node &QNode, frame Rect) !Element {
	mut visible := []&QNode{}
	mut items := []FloatLayoutChild{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		visible << child
		items << q_float_layout_child(child)
	}
	config := q_float_layout_config(node, rect(0, 0, frame.width, frame.height), items)
	frames := float_layout_frames(config)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, q_box(node), children)
}

fn q_grid_config(node &QNode, frame Rect) !GridLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	return GridLayoutConfig{
		id: node.id
		frame: frame
		box: q_box(node)
		columns: node.prop_or('columns', node.prop_or('cols', '0')).int()
		rows: node.prop_or('rows', '0').int()
		orientation: grid_orientation(node.prop_or('orientation', 'lr-tb'))!
		padding: GridPadding{
			left: node.prop_or('padding_left', padding.str()).f64()
			top: node.prop_or('padding_top', padding.str()).f64()
			right: node.prop_or('padding_right', padding.str()).f64()
			bottom: node.prop_or('padding_bottom', padding.str()).f64()
		}
		spacing: GridSpacing{
			horizontal: node.prop_or('spacing_x', spacing.str()).f64()
			vertical: node.prop_or('spacing_y', spacing.str()).f64()
		}
		column_default_width: node.prop_or('col_default_width', '0').f64()
		row_default_height: node.prop_or('row_default_height', '0').f64()
		force_column_width: node.prop_bool('col_force_default')
		force_row_height: node.prop_bool('row_force_default')
	}
}

fn q_grid(node &QNode, frame Rect) !Element {
	mut visible := []&QNode{}
	for child in node.children {
		if child.tag !in ['MenuItem', 'Option'] {
			visible << child
		}
	}
	config := q_grid_config(node, rect(0, 0, frame.width, frame.height))!
	frames := grid_layout_frames(config, visible.len)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, q_box(node), children)
}

fn q_anchor_config(node &QNode, frame Rect) !AnchorLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	return AnchorLayoutConfig{
		id: node.id
		frame: frame
		box: q_box(node)
		anchor_x: horizontal_anchor(node.prop_or('anchor_x', 'center'))!
		anchor_y: vertical_anchor(node.prop_or('anchor_y', 'center'))!
		padding: AnchorPadding{
			left: node.prop_or('padding_left', padding.str()).f64()
			top: node.prop_or('padding_top', padding.str()).f64()
			right: node.prop_or('padding_right', padding.str()).f64()
			bottom: node.prop_or('padding_bottom', padding.str()).f64()
		}
	}
}

fn q_anchor(node &QNode, frame Rect) !Element {
	config := q_anchor_config(node, rect(0, 0, frame.width, frame.height))!
	mut children := []Element{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		size := rect(0, 0, q_dimension(child, 'width', 80), q_dimension(child, 'height', 32))
		children << node_to_element(child, anchor_layout_frame(config, size))!
	}
	return view(node.id, frame, q_box(node), children)
}

fn q_stack_config(node &QNode, frame Rect) !StackLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	return StackLayoutConfig{
		id: node.id
		frame: frame
		box: q_box(node)
		orientation: stack_orientation(node.prop_or('orientation', 'lr-tb'))!
		padding: StackPadding{
			left: node.prop_or('padding_left', padding.str()).f64()
			top: node.prop_or('padding_top', padding.str()).f64()
			right: node.prop_or('padding_right', padding.str()).f64()
			bottom: node.prop_or('padding_bottom', padding.str()).f64()
		}
		spacing: StackSpacing{
			horizontal: node.prop_or('spacing_x', spacing.str()).f64()
			vertical: node.prop_or('spacing_y', spacing.str()).f64()
		}
	}
}

fn q_stack(node &QNode, frame Rect) !Element {
	mut visible := []&QNode{}
	mut sizes := []Rect{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		visible << child
		sizes << rect(0, 0, q_dimension(child, 'width', 80), q_dimension(child, 'height', 32))
	}
	config := q_stack_config(node, rect(0, 0, frame.width, frame.height))!
	frames := stack_layout_frames(config, sizes)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, q_box(node), children)
}

fn q_frame(node &QNode, fallback Rect) Rect {
	return rect(node.prop_or('x', fallback.x.str()).f64(), node.prop_or('y', fallback.y.str()).f64(), node.prop_or('width', fallback.width.str()).f64(), node.prop_or('height', fallback.height.str()).f64())
}

fn q_dimension(node &QNode, key string, fallback f64) f64 {
	raw := node.prop(key)
	if raw.len == 0 {
		return fallback
	}
	return raw.f64()
}

fn q_box(node &QNode) BoxStyle {
	border_width := node.prop_or('border_width', '0')
	return BoxStyle{
		bg: q_color(node, 'background', 0xffffff)
		radius: node.prop_or('corner_radius', node.prop_or('radius', '0')).f64()
		border_color: q_color(node, 'border_color', 0)
		border_left: node.prop_or('border_left', border_width).f64()
		border_top: node.prop_or('border_top', border_width).f64()
		border_right: node.prop_or('border_right', border_width).f64()
		border_bottom: node.prop_or('border_bottom', border_width).f64()
	}
}

fn q_text_style(node &QNode) TextStyle {
	return TextStyle{
		color: q_color(node, 'color', 0x111111)
		background_color: q_color(node, 'background_color', 0)
		size: node.prop_or('font_size', node.prop_or('size', '15')).f64()
		font_family: node.prop('font_family')
		bold: node.prop_bool('bold')
		italic: node.prop_bool('italic')
		underline: node.prop_bool('underline')
		strikethrough: node.prop_bool('strikethrough')
		shadow: node.prop_bool('shadow')
		outline: node.prop_bool('outline')
		vertical_align: node.prop('vertical_align')
		link: node.prop('link')
		align: q_align(node.prop('align'))
		head_indent: node.prop_or('head_indent', '0').f64()
		first_line_indent: node.prop_or('first_line_indent', '0').f64()
		hyphenation_factor: node.prop_or('hyphenation_factor', '0').f64()
		lines: node.prop_or('lines', '1').int()
	}
}

fn q_color(node &QNode, key string, fallback u32) u32 {
	raw := node.prop(key)
	if raw.len == 0 {
		return fallback
	}
	return parse_hex_color(raw)
}

fn q_align(raw string) Align {
	return match raw {
		'center' { Align.center }
		'right' { Align.right }
		else { Align.left }
	}
}
