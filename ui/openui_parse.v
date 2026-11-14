module ui2

// OpenUI Lang line parser: `identifier = Expression`, one statement per line.
//
// The statement kinds mirror the spec: component or value statements,
// `$name` state declarations, and `Query` / `Mutation` data statements.
// Forward references are allowed and resolved at eval time; the parser only
// records the tree with line numbers for error reports.

pub enum OpenuiExprKind {
	literal
	ref
	state_ref
	member
	array
	object
	unary
	binary
	ternary
	call
	at_call
	action_list
	query
	mutation
}

pub struct OpenuiExpr {
pub:
	kind  OpenuiExprKind
	value string
	line  int
pub mut:
	args        []&OpenuiExpr
	field_order []string
	fields      map[string]&OpenuiExpr
	left        &OpenuiExpr = unsafe { nil }
	middle      &OpenuiExpr = unsafe { nil }
	right       &OpenuiExpr = unsafe { nil }
	target      &OpenuiExpr = unsafe { nil }
	field       string
	quoted      bool
	is_null     bool
	is_bool     bool
	bool_value  bool
	number_text string
}

pub struct OpenuiStatement {
pub:
	name string
	line int
pub mut:
	expr &OpenuiExpr = unsafe { nil }
}

enum OpenuiTokenKind {
	ident
	state
	string_lit
	number
	lbracket
	rbracket
	lbrace
	rbrace
	lparen
	rparen
	comma
	colon
	question
	plus
	minus
	star
	slash
	percent
	bang
	assign
	eq_eq
	bang_eq
	lt
	lte
	gt
	gte
	and_and
	or_or
	dot
	at
	eof
}

struct OpenuiToken {
	kind OpenuiTokenKind
	val  string
	line int
}

fn openui_is_ident_start(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`
}

fn openui_is_ident_char(c u8) bool {
	return openui_is_ident_start(c) || (c >= `0` && c <= `9`)
}

fn openui_is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

fn openui_tokenize_line(src string, line int) ![]OpenuiToken {
	mut tokens := []OpenuiToken{}
	mut pos := 0
	for pos < src.len {
		c := src[pos]
		if c == ` ` || c == `\t` || c == `\r` {
			pos++
			continue
		}
		if c == `/` && pos + 1 < src.len && src[pos + 1] == `/` {
			break
		}
		if c == `"` || c == `'` {
			quote := c
			pos++
			mut val := []u8{}
			for pos < src.len {
				q := src[pos]
				pos++
				if q == `\\` && pos < src.len {
					next := src[pos]
					pos++
					match next {
						`n` { val << `\n` }
						`t` { val << `\t` }
						`\\` { val << `\\` }
						`"` { val << `"` }
						`'` { val << `'` }
						else { val << next }
					}
				} else if q == quote {
					break
				} else {
					val << q
				}
			}
			tokens << OpenuiToken{.string_lit, val.bytestr(), line}
			continue
		}
		if c == `$` {
			start := pos + 1
			mut end := start
			for end < src.len && (openui_is_ident_char(src[end]) || src[end] == `.`) {
				end++
			}
			if end == start {
				return error('stray `$` at line ${line}')
			}
			tokens << OpenuiToken{.state, src[start..end].clone(), line}
			pos = end
			continue
		}
		if c == `@` {
			tokens << OpenuiToken{.at, '@', line}
			pos++
			continue
		}
		if openui_is_digit(c) || (c == `-` && pos + 1 < src.len && openui_is_digit(src[pos + 1])
			&& (tokens.len == 0 || tokens.last().kind in [.lparen, .comma, .lbracket, .colon,
				.question, .plus, .minus, .star, .slash, .percent, .bang, .assign, .eq_eq, .bang_eq,
				.lt, .lte, .gt, .gte, .and_and, .or_or])) {
			start := pos
			if src[pos] == `-` {
				pos++
			}
			mut saw_dot := false
			for pos < src.len {
				d := src[pos]
				if openui_is_digit(d) {
					pos++
				} else if d == `.` && !saw_dot && pos + 1 < src.len
					&& openui_is_digit(src[pos + 1]) {
					saw_dot = true
					pos++
				} else {
					break
				}
			}
			tokens << OpenuiToken{.number, src[start..pos].clone(), line}
			continue
		}
		if openui_is_ident_start(c) {
			start := pos
			for pos < src.len && openui_is_ident_char(src[pos]) {
				pos++
			}
			tokens << OpenuiToken{.ident, src[start..pos].clone(), line}
			continue
		}
		two := if pos + 1 < src.len { src[pos..pos + 2] } else { '' }
		if two == '==' {
			tokens << OpenuiToken{.eq_eq, '==', line}
			pos += 2
			continue
		}
		if two == '!=' {
			tokens << OpenuiToken{.bang_eq, '!=', line}
			pos += 2
			continue
		}
		if two == '<=' {
			tokens << OpenuiToken{.lte, '<=', line}
			pos += 2
			continue
		}
		if two == '>=' {
			tokens << OpenuiToken{.gte, '>=', line}
			pos += 2
			continue
		}
		if two == '&&' {
			tokens << OpenuiToken{.and_and, '&&', line}
			pos += 2
			continue
		}
		if two == '||' {
			tokens << OpenuiToken{.or_or, '||', line}
			pos += 2
			continue
		}
		match c {
			`=` {
				tokens << OpenuiToken{.assign, '=', line}
				pos++
			}
			`[` {
				tokens << OpenuiToken{.lbracket, '[', line}
				pos++
			}
			`]` {
				tokens << OpenuiToken{.rbracket, ']', line}
				pos++
			}
			`{` {
				tokens << OpenuiToken{.lbrace, '{', line}
				pos++
			}
			`}` {
				tokens << OpenuiToken{.rbrace, '}', line}
				pos++
			}
			`(` {
				tokens << OpenuiToken{.lparen, '(', line}
				pos++
			}
			`)` {
				tokens << OpenuiToken{.rparen, ')', line}
				pos++
			}
			`,` {
				tokens << OpenuiToken{.comma, ',', line}
				pos++
			}
			`:` {
				tokens << OpenuiToken{.colon, ':', line}
				pos++
			}
			`?` {
				tokens << OpenuiToken{.question, '?', line}
				pos++
			}
			`+` {
				tokens << OpenuiToken{.plus, '+', line}
				pos++
			}
			`-` {
				tokens << OpenuiToken{.minus, '-', line}
				pos++
			}
			`*` {
				tokens << OpenuiToken{.star, '*', line}
				pos++
			}
			`/` {
				tokens << OpenuiToken{.slash, '/', line}
				pos++
			}
			`%` {
				tokens << OpenuiToken{.percent, '%', line}
				pos++
			}
			`!` {
				tokens << OpenuiToken{.bang, '!', line}
				pos++
			}
			`.` {
				tokens << OpenuiToken{.dot, '.', line}
				pos++
			}
			else {
				return error('unexpected character `${c.ascii_str()}` at line ${line}')
			}
		}
	}
	tokens << OpenuiToken{.eof, '', line}
	return tokens
}

struct OpenuiParser {
	tokens []OpenuiToken
mut:
	pos int
}

fn (mut p OpenuiParser) peek() OpenuiToken {
	return p.tokens[p.pos]
}

fn (mut p OpenuiParser) advance() OpenuiToken {
	token := p.tokens[p.pos]
	if p.pos + 1 < p.tokens.len {
		p.pos++
	}
	return token
}

fn (mut p OpenuiParser) expect(kind OpenuiTokenKind) !OpenuiToken {
	token := p.peek()
	if token.kind != kind {
		return error('expected ${kind} at line ${token.line}')
	}
	return p.advance()
}

fn (mut p OpenuiParser) parse_expr() !&OpenuiExpr {
	return p.parse_ternary()
}

fn (mut p OpenuiParser) parse_ternary() !&OpenuiExpr {
	cond := p.parse_or()!
	if p.peek().kind == .question {
		line := p.advance().line
		when_true := p.parse_ternary()!
		p.expect(.colon)!
		when_false := p.parse_ternary()!
		return &OpenuiExpr{
			kind:   .ternary
			line:   line
			left:   cond
			middle: when_true
			right:  when_false
		}
	}
	return cond
}

fn (mut p OpenuiParser) parse_or() !&OpenuiExpr {
	mut left := p.parse_and()!
	for p.peek().kind == .or_or {
		line := p.advance().line
		right := p.parse_and()!
		left = &OpenuiExpr{
			kind:  .binary
			value: '||'
			line:  line
			left:  left
			right: right
		}
	}
	return left
}

fn (mut p OpenuiParser) parse_and() !&OpenuiExpr {
	mut left := p.parse_equality()!
	for p.peek().kind == .and_and {
		line := p.advance().line
		right := p.parse_equality()!
		left = &OpenuiExpr{
			kind:  .binary
			value: '&&'
			line:  line
			left:  left
			right: right
		}
	}
	return left
}

fn (mut p OpenuiParser) parse_equality() !&OpenuiExpr {
	mut left := p.parse_comparison()!
	for p.peek().kind in [.eq_eq, .bang_eq] {
		token := p.advance()
		right := p.parse_comparison()!
		left = &OpenuiExpr{
			kind:  .binary
			value: token.val
			line:  token.line
			left:  left
			right: right
		}
	}
	return left
}

fn (mut p OpenuiParser) parse_comparison() !&OpenuiExpr {
	mut left := p.parse_add()!
	for p.peek().kind in [.lt, .lte, .gt, .gte] {
		token := p.advance()
		right := p.parse_add()!
		left = &OpenuiExpr{
			kind:  .binary
			value: token.val
			line:  token.line
			left:  left
			right: right
		}
	}
	return left
}

fn (mut p OpenuiParser) parse_add() !&OpenuiExpr {
	mut left := p.parse_mul()!
	for p.peek().kind in [.plus, .minus] {
		token := p.advance()
		right := p.parse_mul()!
		left = &OpenuiExpr{
			kind:  .binary
			value: token.val
			line:  token.line
			left:  left
			right: right
		}
	}
	return left
}

fn (mut p OpenuiParser) parse_mul() !&OpenuiExpr {
	mut left := p.parse_unary()!
	for p.peek().kind in [.star, .slash, .percent] {
		token := p.advance()
		right := p.parse_unary()!
		left = &OpenuiExpr{
			kind:  .binary
			value: token.val
			line:  token.line
			left:  left
			right: right
		}
	}
	return left
}

fn (mut p OpenuiParser) parse_unary() !&OpenuiExpr {
	token := p.peek()
	if token.kind in [.bang, .minus] {
		p.advance()
		operand := p.parse_unary()!
		return &OpenuiExpr{
			kind:  .unary
			value: token.val
			line:  token.line
			left:  operand
		}
	}
	return p.parse_postfix()
}

fn (mut p OpenuiParser) parse_postfix() !&OpenuiExpr {
	mut node := p.parse_primary()!
	for p.peek().kind == .dot {
		p.advance()
		field := p.expect(.ident)!
		node = &OpenuiExpr{
			kind:   .member
			line:   field.line
			target: node
			field:  field.val
		}
	}
	return node
}

fn (mut p OpenuiParser) parse_call_args() ![]&OpenuiExpr {
	mut args := []&OpenuiExpr{}
	if p.peek().kind == .rparen {
		return args
	}
	for {
		args << p.parse_expr()!
		if p.peek().kind == .comma {
			p.advance()
			continue
		}
		break
	}
	return args
}

fn (mut p OpenuiParser) parse_primary() !&OpenuiExpr {
	token := p.peek()
	match token.kind {
		.string_lit {
			p.advance()
			return &OpenuiExpr{
				kind:   .literal
				value:  token.val
				line:   token.line
				quoted: true
			}
		}
		.number {
			p.advance()
			return &OpenuiExpr{
				kind:        .literal
				value:       token.val
				line:        token.line
				number_text: token.val
			}
		}
		.state {
			p.advance()
			return &OpenuiExpr{
				kind:  .state_ref
				value: token.val
				line:  token.line
			}
		}
		.at {
			p.advance()
			name := p.expect(.ident)!
			p.expect(.lparen)!
			args := p.parse_call_args()!
			p.expect(.rparen)!
			return &OpenuiExpr{
				kind:  .at_call
				value: name.val
				line:  name.line
				args:  args
			}
		}
		.ident {
			p.advance()
			if token.val == 'true' || token.val == 'false' {
				return &OpenuiExpr{
					kind:       .literal
					value:      token.val
					line:       token.line
					is_bool:    true
					bool_value: token.val == 'true'
				}
			}
			if token.val == 'null' {
				return &OpenuiExpr{
					kind:    .literal
					value:   token.val
					line:    token.line
					is_null: true
				}
			}
			if p.peek().kind == .lparen {
				p.advance()
				args := p.parse_call_args()!
				p.expect(.rparen)!
				if token.val == 'Action' {
					return &OpenuiExpr{
						kind: .action_list
						line: token.line
						args: args
					}
				}
				if token.val == 'Query' {
					return &OpenuiExpr{
						kind: .query
						line: token.line
						args: args
					}
				}
				if token.val == 'Mutation' {
					return &OpenuiExpr{
						kind: .mutation
						line: token.line
						args: args
					}
				}
				return &OpenuiExpr{
					kind:  .call
					value: token.val
					line:  token.line
					args:  args
				}
			}
			return &OpenuiExpr{
				kind:  .ref
				value: token.val
				line:  token.line
			}
		}
		.lbracket {
			p.advance()
			mut args := []&OpenuiExpr{}
			if p.peek().kind != .rbracket {
				for {
					args << p.parse_expr()!
					if p.peek().kind == .comma {
						p.advance()
						continue
					}
					break
				}
			}
			p.expect(.rbracket)!
			return &OpenuiExpr{
				kind: .array
				line: token.line
				args: args
			}
		}
		.lbrace {
			p.advance()
			mut fields := map[string]&OpenuiExpr{}
			mut order := []string{}
			if p.peek().kind != .rbrace {
				for {
					key_token := p.peek()
					key := match key_token.kind {
						.ident, .string_lit { p.advance().val }
						else { return error('expected object key at line ${key_token.line}') }
					}
					p.expect(.colon)!
					fields[key] = p.parse_expr()!
					order << key
					if p.peek().kind == .comma {
						p.advance()
						continue
					}
					break
				}
			}
			p.expect(.rbrace)!
			return &OpenuiExpr{
				kind:        .object
				line:        token.line
				fields:      fields
				field_order: order
			}
		}
		.lparen {
			p.advance()
			node := p.parse_expr()!
			p.expect(.rparen)!
			return node
		}
		else {
			return error('unexpected token at line ${token.line}')
		}
	}
}

// parse_openui_program parses `identifier = Expression` lines. Marker lines
// (`]]>openui:...`), blank lines, and `//` comments are skipped so stored
// messages (see openui_message.v) can be fed directly.

pub fn parse_openui_program(response string) ![]OpenuiStatement {
	mut statements := []OpenuiStatement{}
	lines := response.split_into_lines()
	for index, raw in lines {
		line_number := index + 1
		trimmed := raw.trim_space()
		if trimmed.len == 0 {
			continue
		}
		if trimmed.starts_with(']]>openui:') {
			continue
		}
		if trimmed.starts_with('//') {
			continue
		}
		depth := [u8(`(`), `[`, `{`]
		_ = depth
		mut eq := -1
		mut in_string := u8(0)
		mut level := 0
		mut pos := 0
		for pos < raw.len {
			c := raw[pos]
			if in_string != 0 {
				if c == `\\` {
					pos += 2
					continue
				}
				if c == in_string {
					in_string = 0
				}
				pos++
				continue
			}
			if c == `"` || c == `'` {
				in_string = c
				pos++
				continue
			}
			if c == `(` || c == `[` || c == `{` {
				level++
			} else if c == `)` || c == `]` || c == `}` {
				if level > 0 {
					level--
				}
			} else if c == `=` && level == 0 {
				if pos + 1 < raw.len && raw[pos + 1] == `=` {
					pos += 2
					continue
				}
				eq = pos
				break
			}
			pos++
		}
		if eq < 0 {
			if trimmed.starts_with(']]>') {
				continue
			}
			return error('expected `name = Expression` at line ${line_number}')
		}
		name := raw[..eq].trim_space()
		body := raw[eq + 1..].trim_space()
		if name.len == 0 || body.len == 0 {
			return error('expected `name = Expression` at line ${line_number}')
		}
		if name.starts_with('$') {
			short := name[1..]
			if short.len == 0 {
				return error('bad `$variable` name at line ${line_number}')
			}
			for ch in short.bytes() {
				if !(openui_is_ident_start(ch) || openui_is_ident_char(ch)) {
					return error('bad `$variable` name at line ${line_number}')
				}
			}
		} else {
			if !openui_is_ident_start(name[0]) {
				return error('bad statement name at line ${line_number}')
			}
			for ch in name.bytes() {
				if !openui_is_ident_char(ch) {
					return error('bad statement name at line ${line_number}')
				}
			}
		}
		tokens := openui_tokenize_line(body, line_number)!
		mut parser := OpenuiParser{
			tokens: tokens
		}
		expr := parser.parse_expr()!
		if parser.peek().kind != .eof {
			return error('trailing input at line ${line_number}')
		}
		statements << OpenuiStatement{
			name: name
			line: line_number
			expr: expr
		}
	}
	if statements.len == 0 {
		return error('no statements')
	}
	return statements
}
