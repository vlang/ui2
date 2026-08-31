module ui2

pub struct QNode {
pub mut:
	tag      string
	id       string
	props    map[string]string
	children []&QNode
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

fn (mut l Lexer) read_ident() Token {
	line := l.line
	start := l.pos
	for l.pos < l.src.len && is_ident_char(l.src[l.pos]) {
		l.pos++
	}
	val := l.src[start..l.pos]
	kind := if val.len > 0 && ((val[0] >= `0` && val[0] <= `9`) || (val[0] == `-` && val.len > 1)) {
		TokenKind.number
	} else {
		TokenKind.ident
	}
	return Token{kind, val, line}
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
			`"` {
				tokens << l.read_string()!
			}
			else {
				if is_ident_char(c) {
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
	}
	for p.at().kind != .rbrace && p.at().kind != .eof {
		// Lookahead: if IDENT followed by '{', it's a child node; if followed by ':', it's a property
		if p.at().kind == .ident {
			if p.pos + 1 < p.tokens.len && p.tokens[p.pos + 1].kind == .lbrace {
				child := p.parse_node()!
				node.children << child
			} else if p.pos + 1 < p.tokens.len && p.tokens[p.pos + 1].kind == .colon {
				key := p.eat(.ident)!
				p.eat(.colon)!
				val := p.parse_value()!
				if key.val == 'id' {
					node.id = val
				}
				node.props[key.val] = val
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

fn (mut p Parser) parse_value() !string {
	t := p.at()
	match t.kind {
		.string_lit, .ident, .number {
			p.pos++
			return t.val
		}
		else {
			return error('expected value, got ${t.kind} ("${t.val}") at line ${t.line}')
		}
	}
}

pub fn parse_qml(source string) !&QNode {
	tokens := tokenize(source)!
	mut p := Parser{
		tokens: tokens
	}
	return p.parse_node()!
}

pub fn element_from_qml(source string, frame Rect) !Element {
	node := parse_qml(source)!
	return node_to_element(node, frame)!
}

pub fn element_from_qnode(node &QNode, frame Rect) !Element {
	return node_to_element(node, frame)!
}

fn node_to_element(node &QNode, frame Rect) !Element {
	el := node_to_element_base(node, frame)!
	key := node.prop('key')
	menu := q_menu(node)
	secure := node.prop_bool('secure')
	if key == '' && menu.len == 0 && !secure {
		return el
	}
	return Element{
		...el
		key:    key
		menu:   menu
		secure: secure
	}
}

// q_menu collects MenuItem children as a right-click context menu.
fn q_menu(node &QNode) []MenuEntry {
	mut out := []MenuEntry{}
	for child in node.children {
		if child.tag == 'MenuItem' {
			out << MenuEntry{
				id:    child.prop_or('on_tap', child.id)
				title: child.prop('text')
			}
		}
	}
	return out
}

fn node_to_element_base(node &QNode, frame Rect) !Element {
	match node.tag {
		'Screen' {
			return screen(q_color(node, 'background', 0xffffff), q_children(node, frame)!)
		}
		'Column' {
			return q_column(node, frame)!
		}
		'Row' {
			return q_row(node, frame)!
		}
		'Scroll' {
			return scroll(node.id, q_frame(node, frame), q_color(node, 'background', 0xffffff), q_children(node,
				frame)!)
		}
		'View', 'Rectangle' {
			return view(node.id, q_frame(node, frame), q_box(node), q_children(node, frame)!)
		}
		'Label' {
			return label(node.id, node.prop('text'), q_frame(node, frame), q_text_style(node))
		}
		'Image' {
			return image(node.id, node.prop_or('source', node.prop('path')), q_frame(node, frame))
		}
		'Button' {
			id := node.prop_or('on_tap', node.id)
			return button(id, node.prop('text'), q_frame(node, frame), q_box(node),
				q_text_style(node))
		}
		'TextArea' {
			return Element{
				kind:       .text_area
				id:         node.id
				text:       node.prop('text')
				frame:      q_frame(node, frame)
				box:        q_box(node)
				text_style: q_text_style(node)
				readonly:   node.prop('editable') == 'false'
			}
		}
		'TextField' {
			id := node.prop_or('on_change', node.id)
			submit_id := node.prop('on_submit')
			frame_ := q_frame(node, frame)
			if node.prop_bool('emit_change') || node.prop('on_change').len > 0 {
				return text_field_with_change_and_submit(id, submit_id, node.prop('placeholder'),
					node.prop('text'), frame_, q_box(node), q_text_style(node), keyboard_default)
			}
			if submit_id.len > 0 {
				return text_field_with_submit(id, submit_id, node.prop('placeholder'), node.prop('text'),
					frame_, q_box(node), q_text_style(node), keyboard_default)
			}
			return text_field(id, node.prop('placeholder'), node.prop('text'), frame_, q_box(node),
				q_text_style(node), keyboard_default)
		}
		else {
			return view(node.id, q_frame(node, frame), q_box(node), q_children(node, frame)!)
		}
	}
}

fn q_children(node &QNode, frame Rect) ![]Element {
	mut out := []Element{}
	for child in node.children {
		if child.tag == 'MenuItem' {
			continue // context menu entries, not child views
		}
		out << node_to_element(child, q_frame(child, frame))!
	}
	return out
}

fn q_column(node &QNode, frame Rect) !Element {
	container := q_frame(node, frame)
	padding := node.prop_or('padding', '0').f64()
	spacing := node.prop_or('spacing', '0').f64()
	mut y := padding
	mut children := []Element{}
	for child in node.children {
		if child.tag == 'MenuItem' {
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
		if child.tag == 'MenuItem' {
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

fn q_frame(node &QNode, fallback Rect) Rect {
	return rect(node.prop_or('x', fallback.x.str()).f64(),
		node.prop_or('y', fallback.y.str()).f64(),
		node.prop_or('width', fallback.width.str()).f64(), node.prop_or('height',
		fallback.height.str()).f64())
}

fn q_dimension(node &QNode, key string, fallback f64) f64 {
	raw := node.prop(key)
	if raw.len == 0 {
		return fallback
	}
	return raw.f64()
}

fn q_box(node &QNode) BoxStyle {
	return BoxStyle{
		bg:     q_color(node, 'background', 0xffffff)
		radius: node.prop_or('corner_radius', node.prop_or('radius', '0')).f64()
	}
}

fn q_text_style(node &QNode) TextStyle {
	return TextStyle{
		color: q_color(node, 'color', 0x111111)
		size:  node.prop_or('font_size', node.prop_or('size', '15')).f64()
		bold:  node.prop_bool('bold')
		align: q_align(node.prop('align'))
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
