module ui2

pub struct VNode {
pub mut:
	tag      string
	id       string
	props    map[string]string
	children []&VNode
mut:
	expressions    map[string]&VExpression
	property_types map[string]string
	property_order []string
	line           int
	path           string
}

enum VExpressionKind {
	literal
	path
	call
	unary
	binary
	conditional
	interpolation
}

struct VInterpolationPart {
	text string
	expr &VExpression = unsafe { nil }
}

struct VExpression {
	kind   VExpressionKind
	value  string
	line   int
	left   &VExpression = unsafe { nil }
	right  &VExpression = unsafe { nil }
	third  &VExpression = unsafe { nil }
	args   []&VExpression
	parts  []VInterpolationPart
	quoted bool
}

pub fn (node &VNode) find(id string) ?&VNode {
	if node.id == id {
		return unsafe { node }
	}
	for child in node.children {
		found := child.find(id) or { continue }
		return found
	}
	return none
}

pub fn (node &VNode) prop(key string) string {
	return node.props[key] or { '' }
}

pub fn (node &VNode) prop_or(key string, default_ string) string {
	return node.props[key] or { default_ }
}

pub fn (node &VNode) prop_int(key string) int {
	s := node.prop(key)
	if s.len == 0 {
		return 0
	}
	return s.int()
}

pub fn (node &VNode) prop_f64(key string) f64 {
	s := node.prop(key)
	if s.len == 0 {
		return 0.0
	}
	return s.f64()
}

pub fn (node &VNode) prop_bool(key string) bool {
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
	quote := l.advance()
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
				`'` { val << `'` }
				else { val << next }
			}
		} else if c == quote {
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
			`"`, `'` {
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

fn (mut p Parser) parse_node() !&VNode {
	tag := p.eat(.ident)!
	p.eat(.lbrace)!
	mut node := &VNode{
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

fn expression_text(expr &VExpression) string {
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

fn (mut p Parser) parse_expression() !&VExpression {
	return p.parse_conditional()
}

fn (mut p Parser) parse_conditional() !&VExpression {
	condition := p.parse_or()!
	if p.at().kind != .question {
		return condition
	}
	line := p.eat(.question)!.line
	when_true := p.parse_expression()!
	p.eat(.colon)!
	when_false := p.parse_expression()!
	return &VExpression{
		kind: .conditional
		line: line
		left: condition
		right: when_true
		third: when_false
	}
}

fn (mut p Parser) parse_or() !&VExpression {
	mut left := p.parse_and()!
	for p.at().kind == .or_or {
		op := p.at()
		p.pos++
		left = &VExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_and()! }
	}
	return left
}

fn (mut p Parser) parse_and() !&VExpression {
	mut left := p.parse_equality()!
	for p.at().kind == .and_and {
		op := p.at()
		p.pos++
		left = &VExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_equality()! }
	}
	return left
}

fn (mut p Parser) parse_equality() !&VExpression {
	mut left := p.parse_comparison()!
	for p.at().kind in [.eq_eq, .bang_eq] {
		op := p.at()
		p.pos++
		left = &VExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_comparison()! }
	}
	return left
}

fn (mut p Parser) parse_comparison() !&VExpression {
	mut left := p.parse_term()!
	for p.at().kind in [.lt, .lte, .gt, .gte] {
		op := p.at()
		p.pos++
		left = &VExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_term()! }
	}
	return left
}

fn (mut p Parser) parse_term() !&VExpression {
	mut left := p.parse_factor()!
	for p.at().kind in [.plus, .minus] {
		op := p.at()
		p.pos++
		left = &VExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_factor()! }
	}
	return left
}

fn (mut p Parser) parse_factor() !&VExpression {
	mut left := p.parse_unary()!
	for p.at().kind in [.star, .slash, .percent] {
		op := p.at()
		p.pos++
		left = &VExpression{ kind: .binary, value: op.val, line: op.line, left: left, right: p.parse_unary()! }
	}
	return left
}

fn (mut p Parser) parse_unary() !&VExpression {
	if p.at().kind in [.bang, .minus] {
		op := p.at()
		p.pos++
		return &VExpression{ kind: .unary, value: op.val, line: op.line, left: p.parse_unary()! }
	}
	return p.parse_primary()
}

fn (mut p Parser) parse_primary() !&VExpression {
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
				mut args := []&VExpression{}
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
				return &VExpression{ kind: .call, value: t.val, line: t.line, args: args }
			}
			return &VExpression{
				kind: if t.kind == .number || t.val in ['true', 'false'] {
					VExpressionKind.literal
				} else {
					VExpressionKind.path
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

fn parse_interpolated_string(value string, line int) !&VExpression {
	if !value.contains(r'${') {
		return &VExpression{ kind: .literal, value: value, line: line, quoted: true }
	}
	mut parts := []VInterpolationPart{}
	mut cursor := 0
	for cursor < value.len {
		start_relative := value[cursor..].index(r'${') or {
			parts << VInterpolationPart{ text: value[cursor..] }
			break
		}
		start := cursor + start_relative
		if start > cursor {
			parts << VInterpolationPart{ text: value[cursor..start] }
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
		parts << VInterpolationPart{ expr: expr }
		cursor = end + 1
	}
	return &VExpression{ kind: .interpolation, line: line, parts: parts }
}

pub fn parse_vml(source string) !&VNode {
	tokens := tokenize(source)!
	mut p := Parser{
		tokens: tokens
	}
	mut node := p.parse_node()!
	p.eat(.eof)!
	assign_vml_paths(mut node, '0')
	return node
}

fn assign_vml_paths(mut node VNode, path string) {
	node.path = path
	for index, mut child in node.children {
		assign_vml_paths(mut child, '${path}.${index}')
	}
}

pub fn element_from_vml(source string, frame Rect) !Element {
	node := parse_vml(source)!
	return node_to_element(node, frame)!
}

pub fn element_from_vnode(node &VNode, frame Rect) !Element {
	return node_to_element(node, frame)!
}

fn node_to_element(node &VNode, frame Rect) !Element {
	resolved := v_frame(node, frame)
	el := node_to_element_base(node, resolved)!
	key := node.prop('key')
	menu := v_menu(node)
	secure := el.secure || node.prop_bool('secure') || node.prop_bool('password')
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
		hidden: el.hidden || node.prop_bool('hidden')
		enabled: node.prop('enabled') != 'false'
		accessibility_role: node.prop_or('accessibility_role', el.accessibility_role)
		accessibility_label: node.prop_or('accessibility_label', el.accessibility_label)
		accessibility_value: node.prop_or('accessibility_value', el.accessibility_value)
		native_style: node.prop_bool('native')
		autocorrect: node.prop('autocorrect') != 'false'
		padding_left: node.prop_or('pad_left', el.padding_left.str()).f64()
	}
}

// v_menu collects MenuItem children as a right-click context menu.
fn v_menu(node &VNode) []MenuEntry {
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

fn node_to_element_base(node &VNode, frame Rect) !Element {
	local := rect(0, 0, frame.width, frame.height)
	match node.tag {
		'Screen' {
			return Element{
				...screen(v_color(node, 'background', 0xffffff), v_children(node, local)!)
				box: v_box(node)
			}
		}
		'Column' {
			return v_column(node, frame)!
		}
		'Row' {
			return v_row(node, frame)!
		}
		'BoxLayout' {
			return v_box_layout(node, frame)!
		}
		'FloatLayout', 'RelativeLayout' {
			return v_float_layout(node, frame)!
		}
		'GridLayout' {
			return v_grid(node, frame)!
		}
		'AnchorLayout' {
			return v_anchor(node, frame)!
		}
		'StackLayout' {
			return v_stack(node, frame)!
		}
		'PageLayout' {
			return v_page_layout(node, frame)!
		}
		'TabbedPanel' {
			return v_tabbed_panel(node, frame)!
		}
		'Accordion' {
			return v_accordion(node, frame)!
		}
		'TreeView' {
			return v_tree_view(node, frame)!
		}
		'ScreenManager' {
			return v_screen_manager(node, frame)!
		}
		'Carousel' {
			return v_carousel(node, frame)!
		}
		'ModalView' {
			return v_modal_view(node, frame)!
		}
		'Popup' {
			return v_popup(node, frame)!
		}
		'Scroll' {
			children := v_children(node, local)!
			if node.prop_bool('persistent') {
				return Element{
					...scroll_persistent(node.id, frame, v_color(node, 'background', 0xffffff), children)
					box: v_box(node)
				}
			}
			return Element{
				...scroll(node.id, frame, v_color(node, 'background', 0xffffff), children)
				box: v_box(node)
			}
		}
		'View', 'Rectangle' {
			return view(node.id, frame, v_box(node), v_children(node, local)!)
		}
		'Label' {
			return label(node.id, node.prop('text'), frame, v_text_style(node))
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
				background: v_color(node, 'background', 0xe2e8f0)
				color: v_color(node, 'color', 0x3b82f6)
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
				orientation: v_orientation(node.prop('orientation'))
				padding: node.prop_or('padding', '16').f64()
				value_track: node.prop_bool('value_track')
				style: SliderStyle{
					track_color: v_color(node, 'background', 0xcbd5e1)
					value_track_color: v_color(node, 'value_track_color', v_color(node, 'color', 0x93c5fd))
					thumb_color: v_color(node, 'thumb_color', 0x2563eb)
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
					inactive_track_color: v_color(node, 'inactive_color', 0xcbd5e1)
					active_track_color: v_color(node, 'active_color', v_color(node, 'color', 0x22c55e))
					thumb_color: v_color(node, 'thumb_color', 0xffffff)
					disabled_track_color: v_color(node, 'disabled_track_color', 0xe2e8f0)
					disabled_thumb_color: v_color(node, 'disabled_thumb_color', 0xf8fafc)
				}
			)
		}
		'ToggleButton' {
			action_id := if node.prop('on_state').len > 0 {
				node.prop('on_state')
			} else {
				node.prop('on_tap')
			}
			normal_box := v_box(node)
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
					bg: v_color(node, 'down_background', 0x2563eb)
					radius: node.prop_or('down_corner_radius', normal_box.radius.str()).f64()
				}
				text_style: v_text_style(node)
				down_text_style: TextStyle{
					...v_text_style(node)
					color: v_color(node, 'down_color', 0xffffff)
				}
				native_style: node.prop_bool('native')
			)
		}
		'Button' {
			return Element{
				...button(node.id, node.prop('text'), frame, v_box(node), v_text_style(node))
				action_id: node.prop('on_tap')
			}
		}
		'MessageBox' {
			return v_message_box(node, frame)
		}
		'Checkbox' {
			return Element{
				...checkbox(node.id, node.prop('text'), node.prop_bool('checked'), frame, v_text_style(node))
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
				values: v_options(node)
				text_autoupdate: node.prop_bool('text_autoupdate')
				box: v_box(node)
				text_style: v_text_style(node)
			)
		}
		'Dropdown' {
			action_id := if node.prop('on_change').len > 0 {
				node.prop('on_change')
			} else {
				node.prop('on_tap')
			}
			return Element{
				...dropdown(node.id, node.prop('text'), v_options(node), frame, v_box(node), v_text_style(node))
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
				box: v_box(node)
				text_style: v_text_style(node)
				readonly: node.prop('editable') == 'false'
				emit_change: node.prop('on_change').len > 0
			}
		}
		'TextInput' {
			return text_input(
				id: node.id
				action_id: node.prop_or('on_text', node.prop('on_change'))
				submit_id: node.prop_or('on_text_validate', node.prop('on_submit'))
				frame: frame
				text: node.prop('text')
				hint_text: node.prop_or('hint_text', node.prop('placeholder'))
				multiline: node.prop_or('multiline', 'true') != 'false'
				password: node.prop_bool('password') || node.prop_bool('secure')
				readonly: node.prop_bool('readonly')
				disable_scroll: node.prop_bool('disable_scroll')
				enabled: node.prop('enabled') != 'false'
				autocorrect: node.prop('autocorrect') != 'false'
				keyboard: v_keyboard(node.prop('keyboard'))
				padding_left: node.prop_or('pad_left', node.prop_or('padding', '12')).f64()
				box: v_box(node)
				text_style: v_text_style(node)
			)!
		}
		'TextField' {
			id := node.id
			change_id := node.prop('on_change')
			submit_id := node.prop('on_submit')
			keyboard := v_keyboard(node.prop('keyboard'))
			if node.prop_bool('emit_change') || node.prop('on_change').len > 0 {
				return Element{
					...text_field_with_change_and_submit(id, submit_id, node.prop('placeholder'), node.prop('text'), frame, v_box(node), v_text_style(node), keyboard)
					action_id: change_id
				}
			}
			if submit_id.len > 0 {
				return text_field_with_submit(id, submit_id, node.prop('placeholder'), node.prop('text'), frame, v_box(node), v_text_style(node), keyboard)
			}
			return text_field(id, node.prop('placeholder'), node.prop('text'), frame, v_box(node), v_text_style(node), keyboard)
		}
		else {
			return view(node.id, frame, v_box(node), v_children(node, local)!)
		}
	}
}

fn v_orientation(raw string) Orientation {
	return if raw == 'vertical' { .vertical } else { .horizontal }
}

// v_message_box maps the declarative dialog onto custom_message_box. Its
// Button children become the dialog's actions instead of free-standing views,
// so the card owns their layout.
fn v_message_box(node &VNode, frame Rect) Element {
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
		width: v_dimension(node, 'dialog_width', 300)
		height: v_dimension(node, 'dialog_height', 150)
		actions: actions
	)
}

fn v_children(node &VNode, frame Rect) ![]Element {
	mut out := []Element{}
	for child in node.children {
		if child.tag == 'MenuItem' || child.tag == 'Option' {
			continue // context menu entries, not child views
		}
		out << node_to_element(child, frame)!
	}
	return out
}

fn v_options(node &VNode) []string {
	mut options := []string{}
	for child in node.children {
		if child.tag == 'Option' {
			options << child.prop('text')
		}
	}
	return options
}

fn v_keyboard(raw string) int {
	return match raw {
		'decimal', 'numeric', 'number' { keyboard_decimal }
		else { keyboard_default }
	}
}

fn v_column(node &VNode, frame Rect) !Element {
	container := v_frame(node, frame)
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	mut y := padding
	mut children := []Element{}
	for child in node.children {
		if child.tag == 'MenuItem' || child.tag == 'Option' {
			continue
		}
		child_h := v_dimension(child, 'height', 32)
		child_w := v_dimension(child, 'width', container.width - padding * 2)
		child_frame := rect(padding, y, child_w, child_h)
		children << node_to_element(child, child_frame)!
		y += child_h + spacing
	}
	return view(node.id, container, v_box(node), children)
}

fn v_row(node &VNode, frame Rect) !Element {
	container := v_frame(node, frame)
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	mut x := padding
	mut children := []Element{}
	for child in node.children {
		if child.tag == 'MenuItem' || child.tag == 'Option' {
			continue
		}
		child_w := v_dimension(child, 'width', 80)
		child_h := v_dimension(child, 'height', container.height - padding * 2)
		child_frame := rect(x, padding, child_w, child_h)
		children << node_to_element(child, child_frame)!
		x += child_w + spacing
	}
	return view(node.id, container, v_box(node), children)
}

fn v_box_layout_child(node &VNode) !BoxLayoutChild {
	return BoxLayoutChild{
		element: Element{
			frame: rect(0, 0, v_dimension(node, 'width', 80), v_dimension(node, 'height', 32))
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

fn v_box_layout_config(node &VNode, frame Rect, children []BoxLayoutChild) !BoxLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	return BoxLayoutConfig{
		id: node.id
		frame: frame
		box: v_box(node)
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

fn v_box_layout(node &VNode, frame Rect) !Element {
	mut visible := []&VNode{}
	mut items := []BoxLayoutChild{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		visible << child
		items << v_box_layout_child(child)!
	}
	config := v_box_layout_config(node, rect(0, 0, frame.width, frame.height), items)!
	frames := box_layout_frames(config)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, v_box(node), children)
}

fn v_float_axis_hint(node &VNode, start_keys []string, center_key string, end_key string) FloatAxisHint {
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

fn v_float_layout_child(node &VNode) FloatLayoutChild {
	return FloatLayoutChild{
		element: Element{
			frame: rect(v_dimension(node, 'x', 0), v_dimension(node, 'y', 0), v_dimension(node, 'width', 80), v_dimension(node, 'height', 32))
		}
		size_hint_x: node.prop_or('size_hint_x', '1').f64()
		size_hint_y: node.prop_or('size_hint_y', '1').f64()
		minimum_width: node.prop_or('size_hint_min_x', '-1').f64()
		minimum_height: node.prop_or('size_hint_min_y', '-1').f64()
		maximum_width: node.prop_or('size_hint_max_x', '-1').f64()
		maximum_height: node.prop_or('size_hint_max_y', '-1').f64()
		x_hint: v_float_axis_hint(node, ['pos_hint_x'], 'pos_hint_center_x', 'pos_hint_right')
		y_hint: v_float_axis_hint(node, ['pos_hint_y', 'pos_hint_top'], 'pos_hint_center_y', 'pos_hint_bottom')
	}
}

fn v_float_layout_config(node &VNode, frame Rect, children []FloatLayoutChild) FloatLayoutConfig {
	return FloatLayoutConfig{
		id: node.id
		frame: frame
		box: v_box(node)
		children: children
	}
}

fn v_float_layout(node &VNode, frame Rect) !Element {
	mut visible := []&VNode{}
	mut items := []FloatLayoutChild{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		visible << child
		items << v_float_layout_child(child)
	}
	config := v_float_layout_config(node, rect(0, 0, frame.width, frame.height), items)
	frames := float_layout_frames(config)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, v_box(node), children)
}

fn v_grid_config(node &VNode, frame Rect) !GridLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	return GridLayoutConfig{
		id: node.id
		frame: frame
		box: v_box(node)
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

fn v_grid(node &VNode, frame Rect) !Element {
	mut visible := []&VNode{}
	for child in node.children {
		if child.tag !in ['MenuItem', 'Option'] {
			visible << child
		}
	}
	config := v_grid_config(node, rect(0, 0, frame.width, frame.height))!
	frames := grid_layout_frames(config, visible.len)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, v_box(node), children)
}

fn v_anchor_config(node &VNode, frame Rect) !AnchorLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	return AnchorLayoutConfig{
		id: node.id
		frame: frame
		box: v_box(node)
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

fn v_anchor(node &VNode, frame Rect) !Element {
	config := v_anchor_config(node, rect(0, 0, frame.width, frame.height))!
	mut children := []Element{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		size := rect(0, 0, v_dimension(child, 'width', 80), v_dimension(child, 'height', 32))
		children << node_to_element(child, anchor_layout_frame(config, size))!
	}
	return view(node.id, frame, v_box(node), children)
}

fn v_stack_config(node &VNode, frame Rect) !StackLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	return StackLayoutConfig{
		id: node.id
		frame: frame
		box: v_box(node)
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

fn v_stack(node &VNode, frame Rect) !Element {
	mut visible := []&VNode{}
	mut sizes := []Rect{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		visible << child
		sizes << rect(0, 0, v_dimension(child, 'width', 80), v_dimension(child, 'height', 32))
	}
	config := v_stack_config(node, rect(0, 0, frame.width, frame.height))!
	frames := stack_layout_frames(config, sizes)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, v_box(node), children)
}

fn v_page_layout_config(node &VNode, frame Rect, child_count int) PageLayoutConfig {
	return PageLayoutConfig{
		id: node.id
		frame: frame
		box: v_box(node)
		page: node.prop_or('page', '0').int()
		border: node.prop_or('border', '50').f64()
		swipe_threshold: node.prop_or('swipe_threshold', '0.5').f64()
		children: []Element{len: child_count}
	}
}

fn v_page_layout(node &VNode, frame Rect) !Element {
	mut visible := []&VNode{}
	for child in node.children {
		if child.tag !in ['MenuItem', 'Option'] {
			visible << child
		}
	}
	config := v_page_layout_config(node, rect(0, 0, frame.width, frame.height), visible.len)
	frames := page_layout_frames(config)!
	mut children := []Element{cap: visible.len}
	for index, child in visible {
		children << node_to_element(child, frames[index])!
	}
	return view(node.id, frame, v_box(node), children)
}

fn v_tabbed_panel_config(node &VNode, frame Rect, tabs []TabbedPanelTab) !TabbedPanelConfig {
	header_radius := node.prop_or('tab_corner_radius', '6').f64()
	return TabbedPanelConfig{
		id: node.id
		frame: frame
		box: v_box(node)
		current: node.prop_or('current', node.prop_or('current_tab', '0')).int()
		tab_position: tab_position(node.prop_or('tab_pos', 'top_left'))!
		tab_height: node.prop_or('tab_height', '40').f64()
		tab_width: node.prop_or('tab_width', '100').f64()
		header_box: BoxStyle{
			bg: v_color(node, 'tab_background', 0xe2e8f0)
			radius: header_radius
		}
		active_header_box: BoxStyle{
			bg: v_color(node, 'active_tab_background', 0xffffff)
			radius: header_radius
		}
		header_text_style: TextStyle{
			color: v_color(node, 'tab_color', 0x475569)
			size: node.prop_or('tab_font_size', '14').f64()
			align: .center
		}
		active_header_text_style: TextStyle{
			color: v_color(node, 'active_tab_color', 0x0f172a)
			size: node.prop_or('tab_font_size', '14').f64()
			bold: true
			align: .center
		}
		tabs: tabs
	}
}

fn v_tabbed_panel(node &VNode, frame Rect) !Element {
	mut tab_nodes := []&VNode{}
	mut dummy_tabs := []TabbedPanelTab{}
	for child in node.children {
		if child.tag != 'Tab' {
			continue
		}
		tab_nodes << child
		dummy_tabs << TabbedPanelTab{
			id: child.id
			title: child.prop('text')
			action_id: child.prop('on_select')
			enabled: child.prop('enabled') != 'false'
		}
	}
	local := rect(0, 0, frame.width, frame.height)
	dummy_config := v_tabbed_panel_config(node, local, dummy_tabs)!
	geometry := tabbed_panel_geometry(dummy_config)!
	current := tabbed_panel_current(dummy_config.current, tab_nodes.len)
	content_id := if node.id.len > 0 { '${node.id}__content' } else { '' }
	mut tabs := []TabbedPanelTab{cap: tab_nodes.len}
	for index, child in tab_nodes {
		content := if index == current {
			view(content_id, geometry.content, v_box(child), v_children(child, rect(0, 0, geometry.content.width, geometry.content.height))!)
		} else {
			Element{}
		}
		tabs << TabbedPanelTab{
			id: child.id
			title: child.prop('text')
			action_id: child.prop('on_select')
			content: content
			enabled: child.prop('enabled') != 'false'
		}
	}
	return tabbed_panel(v_tabbed_panel_config(node, frame, tabs)!)!
}

fn v_accordion_config(node &VNode, frame Rect, items []AccordionItem) !AccordionConfig {
	header_radius := node.prop_or('title_corner_radius', '6').f64()
	return AccordionConfig{
		id: node.id
		frame: frame
		box: v_box(node)
		current: node.prop_or('current', '0').int()
		orientation: box_orientation(node.prop_or('orientation', 'horizontal'))!
		min_space: node.prop_or('min_space', '44').f64()
		header_box: BoxStyle{
			bg: v_color(node, 'title_background', 0xe2e8f0)
			radius: header_radius
		}
		active_header_box: BoxStyle{
			bg: v_color(node, 'active_title_background', 0x2563eb)
			radius: header_radius
		}
		header_text_style: TextStyle{
			color: v_color(node, 'title_color', 0x475569)
			size: node.prop_or('title_font_size', '14').f64()
			align: .center
		}
		active_header_text_style: TextStyle{
			color: v_color(node, 'active_title_color', 0xffffff)
			size: node.prop_or('title_font_size', '14').f64()
			bold: true
			align: .center
		}
		items: items
	}
}

fn v_accordion(node &VNode, frame Rect) !Element {
	mut item_nodes := []&VNode{}
	mut dummy_items := []AccordionItem{}
	for child in node.children {
		if child.tag != 'AccordionItem' {
			continue
		}
		item_nodes << child
		dummy_items << AccordionItem{
			id: child.id
			title: child.prop('title')
			action_id: child.prop('on_select')
			enabled: child.prop('enabled') != 'false'
		}
	}
	local := rect(0, 0, frame.width, frame.height)
	dummy_config := v_accordion_config(node, local, dummy_items)!
	geometry := accordion_geometry(dummy_config)!
	current := accordion_current(dummy_config.current, item_nodes.len)
	content_id := if node.id.len > 0 { '${node.id}__content' } else { '' }
	mut items := []AccordionItem{cap: item_nodes.len}
	for index, child in item_nodes {
		content := if index == current {
			view(content_id, geometry.content, v_box(child), v_children(child, rect(0, 0, geometry.content.width, geometry.content.height))!)
		} else {
			Element{}
		}
		items << AccordionItem{
			id: child.id
			title: child.prop('title')
			action_id: child.prop('on_select')
			content: content
			enabled: child.prop('enabled') != 'false'
		}
	}
	return accordion(v_accordion_config(node, frame, items)!)!
}

fn v_tree_view_node(node &VNode) TreeViewNode {
	mut children := []TreeViewNode{}
	for child in node.children {
		if child.tag == 'TreeNode' {
			children << v_tree_view_node(child)
		}
	}
	return TreeViewNode{
		id: node.id
		text: node.prop_or('text', node.prop('title'))
		action_id: node.prop('on_select')
		toggle_action_id: node.prop('on_toggle')
		expanded: node.prop_bool('expanded')
		selected: node.prop_bool('selected')
		enabled: node.prop('enabled') != 'false'
		children: children
	}
}

fn v_tree_view(node &VNode, frame Rect) !Element {
	mut nodes := []TreeViewNode{}
	for child in node.children {
		if child.tag == 'TreeNode' {
			nodes << v_tree_view_node(child)
		}
	}
	row_radius := node.prop_or('row_corner_radius', '4').f64()
	return tree_view(
		id: node.id
		frame: frame
		box: v_box(node)
		row_height: node.prop_or('row_height', '36').f64()
		spacing: node.prop_or('spacing', '2').f64()
		indent: node.prop_or('indent', '24').f64()
		disclosure_width: node.prop_or('disclosure_width', '28').f64()
		row_box: BoxStyle{
			bg: v_color(node, 'row_background', 0xffffff)
			radius: row_radius
		}
		selected_row_box: BoxStyle{
			bg: v_color(node, 'selected_background', 0xdbeafe)
			radius: row_radius
		}
		disclosure_box: BoxStyle{
			bg: v_color(node, 'disclosure_background', 0xffffff)
			radius: row_radius
		}
		text_style: TextStyle{
			color: v_color(node, 'color', 0x334155)
			size: node.prop_or('font_size', '14').f64()
		}
		selected_text_style: TextStyle{
			color: v_color(node, 'selected_color', 0x1d4ed8)
			size: node.prop_or('font_size', '14').f64()
			bold: true
		}
		disclosure_text_style: TextStyle{
			color: v_color(node, 'disclosure_color', 0x64748b)
			size: node.prop_or('font_size', '14').f64()
			align: .center
		}
		nodes: nodes
	)!
}

fn v_managed_screen_name(node &VNode) string {
	return node.prop_or('name', node.id)
}

fn v_screen_manager_config(node &VNode, frame Rect, screens []ManagedScreen) ScreenManagerConfig {
	return ScreenManagerConfig{
		id: node.id
		frame: frame
		box: v_box(node)
		current: node.prop('current')
		screens: screens
	}
}

fn v_screen_manager(node &VNode, frame Rect) !Element {
	mut screen_nodes := []&VNode{}
	mut dummy_screens := []ManagedScreen{}
	for child in node.children {
		if child.tag !in ['Screen', 'ManagedScreen', 'ScreenView'] {
			continue
		}
		screen_nodes << child
		dummy_screens << ManagedScreen{
			name: v_managed_screen_name(child)
		}
	}
	local := rect(0, 0, frame.width, frame.height)
	dummy_config := v_screen_manager_config(node, local, dummy_screens)
	current := screen_manager_index(dummy_config)!
	mut screens := []ManagedScreen{cap: screen_nodes.len}
	for index, child in screen_nodes {
		content := if index == current {
			view(child.id, local, v_box(child), v_children(child, local)!)
		} else {
			Element{}
		}
		screens << ManagedScreen{
			name: v_managed_screen_name(child)
			content: content
		}
	}
	return screen_manager(v_screen_manager_config(node, frame, screens))!
}

fn v_carousel_config(node &VNode, frame Rect, slides []Element) !CarouselConfig {
	return CarouselConfig{
		id: node.id
		frame: frame
		box: v_box(node)
		index: node.prop_or('index', '0').int()
		direction: carousel_direction(node.prop_or('direction', 'right'))!
		loop: node.prop_bool('loop')
		min_move: node.prop_or('min_move', '0.2').f64()
		ignore_perpendicular_swipes: node.prop_bool('ignore_perpendicular_swipes')
		slides: slides
	}
}

fn v_carousel(node &VNode, frame Rect) !Element {
	local := rect(0, 0, frame.width, frame.height)
	mut slides := []Element{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		if child.tag in ['CarouselSlide', 'Slide'] {
			slides << view(child.id, local, v_box(child), v_children(child, local)!)
		} else {
			slides << node_to_element(child, local)!
		}
	}
	return carousel(v_carousel_config(node, frame, slides)!)!
}

fn v_modal_view_config(node &VNode, frame Rect, content Element) ModalViewConfig {
	return ModalViewConfig{
		id: node.id
		frame: frame
		open: node.prop_bool('open')
		auto_dismiss: node.prop('auto_dismiss') != 'false'
		dismiss_action_id: node.prop('on_dismiss')
		content_width: node.prop_or('content_width', '-1').f64()
		content_height: node.prop_or('content_height', '-1').f64()
		size_hint_x: node.prop_or('size_hint_x', '0.8').f64()
		size_hint_y: node.prop_or('size_hint_y', '0.8').f64()
		overlay_box: BoxStyle{
			bg: v_color(node, 'overlay_background', 0x475569)
		}
		content_box: v_box(node)
		content: content
	}
}

fn v_modal_view(node &VNode, frame Rect) !Element {
	config := v_modal_view_config(node, rect(0, 0, frame.width, frame.height), Element{})
	geometry := modal_view_geometry(config)!
	content_id := if node.id.len > 0 { '${node.id}__content' } else { '' }
	content := view(content_id, rect(0, 0, geometry.content.width, geometry.content.height), BoxStyle{ transparent: true }, v_children(node, rect(0, 0, geometry.content.width, geometry.content.height))!)
	return modal_view(v_modal_view_config(node, frame, content))!
}

fn v_popup_config(node &VNode, frame Rect, content Element) PopupConfig {
	return PopupConfig{
		id: node.id
		frame: frame
		open: node.prop_bool('open')
		auto_dismiss: node.prop('auto_dismiss') != 'false'
		dismiss_action_id: node.prop('on_dismiss')
		content_width: node.prop_or('content_width', '-1').f64()
		content_height: node.prop_or('content_height', '-1').f64()
		size_hint_x: node.prop_or('size_hint_x', '0.8').f64()
		size_hint_y: node.prop_or('size_hint_y', '0.8').f64()
		overlay_box: BoxStyle{
			bg: v_color(node, 'overlay_background', 0x475569)
		}
		surface_box: v_box(node)
		title: node.prop('title')
		title_height: node.prop_or('title_height', '48').f64()
		title_style: TextStyle{
			color: v_color(node, 'title_color', 0x0f172a)
			size: node.prop_or('title_font_size', '18').f64()
			bold: node.prop('title_bold') != 'false'
			align: .center
		}
		separator_height: node.prop_or('separator_height', '1').f64()
		separator_box: BoxStyle{
			bg: v_color(node, 'separator_color', 0xe2e8f0)
		}
		content: content
	}
}

fn v_popup(node &VNode, frame Rect) !Element {
	config := v_popup_config(node, rect(0, 0, frame.width, frame.height), Element{})
	geometry := popup_geometry(config)!
	body_id := if node.id.len > 0 { '${node.id}__body' } else { '' }
	body := view(body_id, rect(0, 0, geometry.body.width, geometry.body.height), BoxStyle{ transparent: true }, v_children(node, rect(0, 0, geometry.body.width, geometry.body.height))!)
	return popup(v_popup_config(node, frame, body))!
}

fn v_frame(node &VNode, fallback Rect) Rect {
	return rect(node.prop_or('x', fallback.x.str()).f64(), node.prop_or('y', fallback.y.str()).f64(), node.prop_or('width', fallback.width.str()).f64(), node.prop_or('height', fallback.height.str()).f64())
}

fn v_dimension(node &VNode, key string, fallback f64) f64 {
	raw := node.prop(key)
	if raw.len == 0 {
		return fallback
	}
	return raw.f64()
}

fn v_box(node &VNode) BoxStyle {
	border_width := node.prop_or('border_width', '0')
	return BoxStyle{
		bg: v_color(node, 'background', 0xffffff)
		radius: node.prop_or('corner_radius', node.prop_or('radius', '0')).f64()
		transparent: node.prop_bool('transparent')
		border_color: v_color(node, 'border_color', 0)
		border_left: node.prop_or('border_left', border_width).f64()
		border_top: node.prop_or('border_top', border_width).f64()
		border_right: node.prop_or('border_right', border_width).f64()
		border_bottom: node.prop_or('border_bottom', border_width).f64()
	}
}

fn v_text_style(node &VNode) TextStyle {
	return TextStyle{
		color: v_color(node, 'color', 0x111111)
		background_color: v_color(node, 'background_color', 0)
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
		align: v_align(node.prop('align'))
		head_indent: node.prop_or('head_indent', '0').f64()
		first_line_indent: node.prop_or('first_line_indent', '0').f64()
		hyphenation_factor: node.prop_or('hyphenation_factor', '0').f64()
		lines: node.prop_or('lines', '1').int()
	}
}

fn v_color(node &VNode, key string, fallback u32) u32 {
	raw := node.prop(key)
	if raw.len == 0 {
		return fallback
	}
	return parse_hex_color(raw)
}

fn v_align(raw string) Align {
	return match raw {
		'center' { Align.center }
		'right' { Align.right }
		else { Align.left }
	}
}
