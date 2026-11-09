module ui2

import math

// Stylesheet math: modern CSS value functions for lengths.
//
// Supported: px and bare numbers (logical pixels, the ui2 convention),
// viewport units (vw/vh/vmin/vmax and the sv-/lv-/dv- small/large/dynamic
// variants, all resolving against the window — ui2 windows have no
// collapsing browser chrome, so the variants coincide),
// container units (cqw/cqh/cqmin/cqmax, against the query container),
// env(safe-area-inset-*, fallback), and calc/min/max/clamp/round/mod/rem/
// abs/sign/sqrt/hypot/pow/exp/log plus sin/cos/tan/asin/acos/atan/atan2.
// Percentages, font-relative and dpi units are rejected: they need a layout
// or font context the cascade does not have.

// StyleLengthCtx carries everything a length can resolve against. The
// container basis is the matched query container, else the parent frame,
// else the window (the CSS small-viewport fallback).
struct StyleLengthCtx {
mut:
	win_w  f64
	win_h  f64
	cont_w f64
	cont_h f64
	insets ?SafeInsets
}

// style_split_value splits a declaration value on whitespace outside
// parentheses and quotes, so `calc(1px + 2px)` and `rgb(1, 2, 3)` survive as
// single parts for shorthands like `border` and `box-shadow`.
pub fn style_split_value(raw string) []string {
	mut parts := []string{}
	mut depth := 0
	mut quote := u8(0)
	mut start := 0
	mut in_word := false
	for index in 0 .. raw.len {
		ch := raw[index]
		if quote != 0 {
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			if !in_word {
				start = index
				in_word = true
			}
			continue
		}
		if ch == `(` {
			depth++
			if !in_word {
				start = index
				in_word = true
			}
			continue
		}
		if ch == `)` {
			if depth > 0 {
				depth--
			}
			continue
		}
		if (ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r`) && depth == 0 {
			if in_word {
				parts << raw[start..index]
				in_word = false
			}
			continue
		}
		if !in_word {
			start = index
			in_word = true
		}
	}
	if in_word {
		parts << raw[start..]
	}
	return parts
}

// query_plain_number reads a bare decimal for unitless properties. The whole
// string must be numeric: V's f64() accepts leading-number prefixes, so
// garbage like `0.0)` or `12px` must not slip through here.
pub fn query_plain_number(raw string) ?f64 {
	text := raw.trim_space()
	if text.len == 0 {
		return none
	}
	mut digits := 0
	mut points := 0
	mut index := 0
	if text[0] == `-` || text[0] == `+` {
		index = 1
	}
	for index < text.len {
		ch := text[index]
		if ch >= `0` && ch <= `9` {
			digits++
		} else if ch == `.` {
			points++
		} else {
			return none
		}
		index++
	}
	if digits == 0 || points > 1 {
		return none
	}
	value := text.f64()
	return if value != value { none } else { value }
}

enum StyleDim {
	px
	scalar
	percent
	angle
}

struct StyleValue {
	dim   StyleDim
	value f64 // px, plain number, or radians
}

struct StyleMathToken {
	kind string // 'num', 'ident', 'op'
	num  f64
	unit string
	text string
}

struct StyleMathParser {
	tokens []StyleMathToken
mut:
	pos int
	ctx StyleLengthCtx
}

// style_math_channel evaluates a color-channel expression to a value and
// its dimension (scalar, percent or angle). Lengths resolve but are
// rejected: they are not valid color channels.
pub fn style_math_channel(raw string, ctx StyleLengthCtx) ?StyleValue {
	mut parser := StyleMathParser{
		tokens: style_math_tokenize(raw.trim_space()) or { return none }
		ctx:    ctx
	}
	value := parser.parse_expr() or { return none }
	if !parser.eof() {
		return none
	}
	if value.dim == .px {
		return none
	}
	return value
}

// style_length_px resolves a declaration value to logical pixels.
pub fn style_length_px(raw string, ctx StyleLengthCtx) ?f64 {
	mut parser := StyleMathParser{
		tokens: style_math_tokenize(raw.trim_space()) or { return none }
		ctx:    ctx
	}
	value := parser.parse_expr() or { return none }
	if !parser.eof() {
		return none
	}
	return style_value_to_px(value) or { return none }
}

fn style_value_to_px(value StyleValue) ?f64 {
	match value.dim {
		.px {
			return value.value
		}
		.scalar {
			// A bare number in length position is pixels, the ui2 convention.
			return value.value
		}
		else {
			// Percentages and angles have no meaning as lengths here.
			return none
		}
	}
}

// style_math_number evaluates one tokenized number against the length
// context. Percentages stay percentages for color channels to interpret;
// lengths reject them in style_length_px.

// style_scan_number scans a decimal with optional exponent and unit from i.
// It returns the end of the number and the end of the unit, or none when
// the text is not a number. A leading `-` belongs to the number only when
// directly followed by a digit or `.digit` (whitespace around binary `-`
// and `+` stays mandatory, as in CSS); `--name` stays an identifier.
fn style_scan_number(source string, i int) !(int, int) {
	mut end := i
	if source[end] == `-` {
		end++
	}
	mut points := 0
	for end < source.len
		&& ((source[end] >= `0` && source[end] <= `9`) || source[end] == `.`) {
		if source[end] == `.` {
			points++
		}
		end++
	}
	if points > 1 {
		return error('not a number')
	}
	// Exponent: e/E, optional sign, then digits. `1em` keeps its unit
	// because `m` is not a digit; `1e5` and `1e-5` fold into the number.
	if end < source.len && (source[end] == `e` || source[end] == `E`) {
		mut exp := end + 1
		if exp < source.len && (source[exp] == `-` || source[exp] == `+`) {
			exp++
		}
		if exp < source.len && source[exp] >= `0` && source[exp] <= `9` {
			for exp < source.len && source[exp] >= `0` && source[exp] <= `9` {
				exp++
			}
			end = exp
		}
	}
	if end == i || (end == i + 1 && (source[i] == `.` || source[i] == `-`)) {
		return error('not a number')
	}
	if end == i + 2 && source[i] == `-` && source[i + 1] == `.` {
		return error('not a number')
	}
	mut unit_end := end
	for unit_end < source.len
		&& ((source[unit_end] >= `a` && source[unit_end] <= `z`)
			|| (source[unit_end] >= `A` && source[unit_end] <= `Z`) || source[unit_end] == `%`) {
		unit_end++
	}
	return end, unit_end
}

fn style_scan_number_here(source string, i int) bool {
	if i >= source.len {
		return false
	}
	ch := source[i]
	if (ch >= `0` && ch <= `9`) || ch == `.` {
		return true
	}
	if ch != `-` || i + 1 >= source.len {
		return false
	}
	next := source[i + 1]
	if next >= `0` && next <= `9` {
		return true
	}
	return next == `.` && i + 2 < source.len && source[i + 2] >= `0` && source[i + 2] <= `9`
}

fn style_math_tokenize(source string) ![]StyleMathToken {
	if source.len == 0 {
		return error('empty value')
	}
	mut tokens := []StyleMathToken{}
	mut i := 0
	for i < source.len {
		ch := source[i]
		if ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r` {
			i++
			continue
		}
		if style_scan_number_here(source, i) {
			end, unit_end := style_scan_number(source, i) or {
				return error('"${source}" is not a number')
			}
			number := source[i..end]
			value := number.f64()
			if value != value {
				return error('"${source}" is not a number')
			}
			tokens << StyleMathToken{
				kind: 'num'
				num:  value
				unit: source[end..unit_end].to_lower()
			}
			i = unit_end
			continue
		}
		if (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || ch == `_`
			|| (ch == `-` && i + 1 < source.len
				&& (((source[i + 1] >= `a` && source[i + 1] <= `z`)
					|| (source[i + 1] >= `A` && source[i + 1] <= `Z`) || source[i + 1] == `_`)
					|| source[i + 1] == `-`)) {
			mut end := i
			for end < source.len
				&& ((source[end] >= `a` && source[end] <= `z`)
					|| (source[end] >= `A` && source[end] <= `Z`)
					|| (source[end] >= `0` && source[end] <= `9`) || source[end] == `_`
					|| source[end] == `-`) {
				end++
			}
			tokens << StyleMathToken{
				kind: 'ident'
				text: source[i..end].to_lower()
			}
			i = end
			continue
		}
		if ch == `+` || ch == `-` || ch == `*` || ch == `/` || ch == `(` || ch == `)`
			|| ch == `,` {
			tokens << StyleMathToken{
				kind: 'op'
				text: source[i..i + 1]
			}
			i++
			continue
		}
		return error('"${source}" has an unexpected character')
	}
	return tokens
}

fn (mut p StyleMathParser) eof() bool {
	return p.pos >= p.tokens.len
}

fn (mut p StyleMathParser) peek() StyleMathToken {
	if p.pos >= p.tokens.len {
		return StyleMathToken{ kind: 'end' }
	}
	return p.tokens[p.pos]
}

fn (mut p StyleMathParser) next() StyleMathToken {
	token := p.peek()
	if p.pos < p.tokens.len {
		p.pos++
	}
	return token
}

fn (mut p StyleMathParser) expect_op(text string) ! {
	token := p.next()
	if token.kind != 'op' || token.text != text {
		return error('expected "${text}"')
	}
}

fn (mut p StyleMathParser) parse_expr() !StyleValue {
	mut left := p.parse_term()!
	for !p.eof() && p.peek().kind == 'op' && (p.peek().text == '+' || p.peek().text == '-') {
		op := p.next().text
		right := p.parse_term()!
		left = style_math_add(left, right, op)!
	}
	return left
}

fn style_math_add(a StyleValue, b StyleValue, op string) !StyleValue {
	if a.dim == .angle || b.dim == .angle {
		if a.dim != b.dim {
			return error('cannot mix angles with lengths')
		}
		// Angles only combine inside trig arguments; the evaluator keeps them
		// numeric and callers convert once.
		combined := if op == '+' { a.value + b.value } else { a.value - b.value }
		return StyleValue{ dim: .angle, value: combined }
	}
	if a.dim == .percent || b.dim == .percent {
		if a.dim != b.dim {
			return error('cannot mix percentages with other units here')
		}
		combined := if op == '+' { a.value + b.value } else { a.value - b.value }
		return StyleValue{ dim: .percent, value: combined }
	}
	if a.dim == .px || b.dim == .px {
		if a.dim != .scalar && b.dim != .scalar && a.dim != b.dim {
			return error('mismatched units')
		}
		// Scalars adopt pixels in addition, per the bare-means-px convention.
		combined := if op == '+' { a.value + b.value } else { a.value - b.value }
		return StyleValue{ dim: .px, value: combined }
	}
	combined := if op == '+' { a.value + b.value } else { a.value - b.value }
	return StyleValue{ dim: .scalar, value: combined }
}

fn (mut p StyleMathParser) parse_term() !StyleValue {
	mut left := p.parse_factor()!
	for !p.eof() && p.peek().kind == 'op' && (p.peek().text == '*' || p.peek().text == '/') {
		op := p.next().text
		right := p.parse_factor()!
		left = style_math_mul(left, right, op)!
	}
	return left
}

fn style_math_mul(a StyleValue, b StyleValue, op string) !StyleValue {
	if op == '*' {
		if a.dim == .scalar {
			return StyleValue{ dim: b.dim, value: a.value * b.value }
		}
		if b.dim == .scalar {
			return StyleValue{ dim: a.dim, value: a.value * b.value }
		}
		return error('multiplication needs a plain number on one side')
	}
	if b.dim != .scalar {
		return error('division needs a plain number divisor')
	}
	if b.value == 0 {
		return error('division by zero')
	}
	return StyleValue{ dim: a.dim, value: a.value / b.value }
}

fn (mut p StyleMathParser) parse_factor() !StyleValue {
	token := p.peek()
	if token.kind == 'op' && (token.text == '+' || token.text == '-') {
		p.next()
		value := p.parse_factor()!
		if token.text == '-' {
			return StyleValue{ dim: value.dim, value: -value.value }
		}
		return value
	}
	if token.kind == 'num' {
		p.next()
		return style_math_number(token, p.ctx)!
	}
	if token.kind == 'op' && token.text == '(' {
		p.next()
		value := p.parse_expr()!
		p.expect_op(')')!
		return value
	}
	if token.kind == 'ident' {
		return p.parse_function()!
	}
	return error('expected a number, function or parenthesized expression')
}

fn style_math_number(token StyleMathToken, ctx StyleLengthCtx) !StyleValue {
	match token.unit {
		'' {
			return StyleValue{ dim: .scalar, value: token.num }
		}
		'px' {
			return StyleValue{ dim: .px, value: token.num }
		}
		'vw', 'svw', 'lvw', 'dvw' {
			return StyleValue{ dim: .px, value: token.num * ctx.win_w / 100 }
		}
		'vh', 'svh', 'lvh', 'dvh' {
			return StyleValue{ dim: .px, value: token.num * ctx.win_h / 100 }
		}
		'vmin', 'svmin', 'lvmin', 'dvmin' {
			small := if ctx.win_w < ctx.win_h { ctx.win_w } else { ctx.win_h }
			return StyleValue{ dim: .px, value: token.num * small / 100 }
		}
		'vmax', 'svmax', 'lvmax', 'dvmax' {
			large := if ctx.win_w > ctx.win_h { ctx.win_w } else { ctx.win_h }
			return StyleValue{ dim: .px, value: token.num * large / 100 }
		}
		'cqw' {
			return StyleValue{ dim: .px, value: token.num * ctx.cont_w / 100 }
		}
		'cqh' {
			return StyleValue{ dim: .px, value: token.num * ctx.cont_h / 100 }
		}
		'cqmin' {
			small := if ctx.cont_w < ctx.cont_h { ctx.cont_w } else { ctx.cont_h }
			return StyleValue{ dim: .px, value: token.num * small / 100 }
		}
		'cqmax' {
			large := if ctx.cont_w > ctx.cont_h { ctx.cont_w } else { ctx.cont_h }
			return StyleValue{ dim: .px, value: token.num * large / 100 }
		}
		'deg' {
			return StyleValue{ dim: .angle, value: token.num * math.pi / 180 }
		}
		'rad' {
			return StyleValue{ dim: .angle, value: token.num }
		}
		'grad' {
			return StyleValue{ dim: .angle, value: token.num * math.pi / 200 }
		}
		'turn' {
			return StyleValue{ dim: .angle, value: token.num * 2 * math.pi }
		}
		'dppx', 'dpi', 'dpcm' {
			return error('"${token.unit}" needs a resolution context stylesheets do not have')
		}
		'%' {
			return StyleValue{ dim: .percent, value: token.num }
		}
		else {
			return error('"${token.unit}" needs a layout or font context stylesheets do not have')
		}
	}
}

fn (mut p StyleMathParser) parse_function() !StyleValue {
	name := p.next().text
	p.expect_op('(')!
	match name {
		'calc' {
			value := p.parse_expr()!
			p.expect_op(')')!
			return value
		}
		'env' {
			value := p.parse_env()!
			p.expect_op(')')!
			return value
		}
		'min', 'max' {
			values := p.parse_csv()!
			p.expect_op(')')!
			return style_math_minmax(name, values)!
		}
		'clamp' {
			values := p.parse_csv()!
			p.expect_op(')')!
			if values.len != 3 {
				return error('clamp() needs exactly three arguments')
			}
			lo := style_math_coerce(values[0], values[1])!
			hi := style_math_coerce(values[2], values[1])!
			mid := style_math_coerce(values[1], values[1])!
			clamped := if mid.value < lo.value {
				lo.value
			} else if mid.value > hi.value {
				hi.value
			} else {
				mid.value
			}
			return StyleValue{ dim: mid.dim, value: clamped }
		}
		'round' {
			value := p.parse_round()!
			p.expect_op(')')!
			return value
		}
		'mod', 'rem' {
			values := p.parse_csv()!
			p.expect_op(')')!
			if values.len != 2 {
				return error('${name}() needs exactly two arguments')
			}
			a := style_math_expect_px(values[0])!
			b := style_math_expect_px(values[1])!
			if b == 0 {
				return error('${name}() division by zero')
			}
			quotient := if name == 'mod' {
				math.floor(a / b)
			} else {
				math.trunc(a / b)
			}
			return StyleValue{ dim: .px, value: a - b * quotient }
		}
		'abs', 'sign' {
			value := p.parse_expr()!
			p.expect_op(')')!
			if name == 'abs' {
				return StyleValue{ dim: value.dim, value: math.abs(value.value) }
			}
			sign := if value.value > 0 {
				1.0
			} else if value.value < 0 {
				-1.0
			} else {
				0.0
			}
			return StyleValue{ dim: .scalar, value: sign }
		}
		'sqrt', 'exp', 'log' {
			value := p.parse_expr()!
			p.expect_op(')')!
			scalar := style_math_expect_scalar(value)!
			result := match name {
				'sqrt' {
					if scalar < 0 {
						return error('sqrt() of a negative number')
					}
					math.sqrt(scalar)
				}
				'exp' {
					math.exp(scalar)
				}
				else {
					if scalar <= 0 {
						return error('log() of a non-positive number')
					}
					math.log(scalar)
				}
			}
			return StyleValue{ dim: .scalar, value: result }
		}
		'hypot', 'pow' {
			values := p.parse_csv()!
			p.expect_op(')')!
			if values.len < 2 {
				return error('${name}() needs at least two arguments')
			}
			mut scalars := []f64{cap: values.len}
			for value in values {
				scalars << style_math_expect_scalar(value)!
			}
			if name == 'pow' {
				if scalars.len != 2 {
					return error('pow() needs exactly two arguments')
				}
				return StyleValue{ dim: .scalar, value: math.pow(scalars[0], scalars[1]) }
			}
			mut total := 0.0
			for scalar in scalars {
				total += scalar * scalar
			}
			return StyleValue{ dim: .scalar, value: math.sqrt(total) }
		}
		'sin', 'cos', 'tan', 'asin', 'acos', 'atan' {
			value := p.parse_expr()!
			p.expect_op(')')!
			radians := style_math_angle_rad(value)!
			result := match name {
				'sin' { math.sin(radians) }
				'cos' { math.cos(radians) }
				'tan' { math.tan(radians) }
				'asin' { math.asin(radians) }
				'acos' { math.acos(radians) }
				else { math.atan(radians) }
			}
			return StyleValue{ dim: .scalar, value: result }
		}
		'atan2' {
			values := p.parse_csv()!
			p.expect_op(')')!
			if values.len != 2 {
				return error('atan2() needs exactly two arguments')
			}
			y := style_math_angle_rad(values[0])!
			x := style_math_angle_rad(values[1])!
			return StyleValue{ dim: .scalar, value: math.atan2(y, x) }
		}
		else {
			return error('unknown function "${name}()"')
		}
	}
}

// parse_csv parses comma-separated expressions (min, max, hypot, ...).
fn (mut p StyleMathParser) parse_csv() ![]StyleValue {
	mut values := []StyleValue{}
	for {
		if !p.eof() && p.peek().kind == 'op' && p.peek().text == ')' {
			break
		}
		values << p.parse_expr()!
		if p.eof() {
			break
		}
		if p.peek().kind == 'op' && p.peek().text == ',' {
			p.next()
			continue
		}
		break
	}
	return values
}

fn style_math_minmax(name string, values []StyleValue) !StyleValue {
	if values.len == 0 {
		return error('${name}() needs at least one argument')
	}
	mut dim := values[0].dim
	mut best := values[0].value
	// A bare number adopts the dimension it is compared against.
	for value in values[1..] {
		current_dim := if value.dim == .scalar { dim } else { value.dim }
		current := value.value
		if current_dim != dim {
			return error('${name}() mixes incompatible units')
		}
		if (name == 'min' && current < best) || (name == 'max' && current > best) {
			best = current
		}
	}
	return StyleValue{ dim: dim, value: best }
}

// style_math_coerce converts value to target's dimension under the
// bare-means-px convention; mismatched real units are an error.
fn style_math_coerce(value StyleValue, target StyleValue) !StyleValue {
	if value.dim == target.dim {
		return value
	}
	if value.dim == .scalar {
		return StyleValue{ dim: target.dim, value: value.value }
	}
	return error('mismatched units')
}

fn style_math_expect_px(value StyleValue) !f64 {
	coerced := style_math_coerce(value, StyleValue{ dim: .px })!
	if coerced.dim != .px {
		return error('expected a length')
	}
	return coerced.value
}

fn style_math_expect_scalar(value StyleValue) !f64 {
	if value.dim != .scalar {
		return error('expected a plain number')
	}
	return value.value
}

fn style_math_angle_rad(value StyleValue) !f64 {
	if value.dim == .angle || value.dim == .scalar {
		return value.value
	}
	return error('expected an angle')
}

// parse_round parses round([strategy,] A, B): CSS round() quantizes A to a
// multiple of B.
fn (mut p StyleMathParser) parse_round() !StyleValue {
	saved_pos := p.pos
	if !p.eof() && p.peek().kind == 'ident' {
		word := p.peek().text
		if word in ['nearest', 'up', 'down', 'to-zero'] {
			p.next()
			if !p.eof() && p.peek().kind == 'op' && p.peek().text == ',' {
				p.next()
				a := p.parse_expr()!
				p.expect_op(',')!
				b := p.parse_expr()!
				return style_math_round(word, a, b)!
			}
		}
		p.pos = saved_pos
	}
	a := p.parse_expr()!
	p.expect_op(',')!
	b := p.parse_expr()!
	return style_math_round('nearest', a, b)!
}

fn style_math_round(strategy string, a StyleValue, b StyleValue) !StyleValue {
	av := style_math_expect_px(a)!
	bv := style_math_expect_px(b)!
	if bv == 0 {
		return error('round() division by zero')
	}
	quotient := match strategy {
		'up' { math.ceil(av / bv) }
		'down' { math.floor(av / bv) }
		'to-zero' { math.trunc(av / bv) }
		else { math.round(av / bv) }
	}
	return StyleValue{ dim: .px, value: quotient * bv }
}

// parse_env parses env(name[, fallback]) against the platform safe area.
// Unknown names fail; missing insets use the fallback, else zero —
// unsupported platforms still resolve, to the unsafe edge.
fn (mut p StyleMathParser) parse_env() !StyleValue {
	if p.eof() || p.peek().kind != 'ident' {
		return error('env() needs a variable name')
	}
	name := p.next().text
	if name !in ['safe-area-inset-top', 'safe-area-inset-right', 'safe-area-inset-bottom',
		'safe-area-inset-left'] {
		return error('unknown env() variable "${name}"')
	}
	if insets := p.ctx.insets {
		edge := match name {
			'safe-area-inset-top' { insets.top }
			'safe-area-inset-right' { insets.right }
			'safe-area-inset-bottom' { insets.bottom }
			else { insets.left }
		}
		// The edge is known; an optional fallback is parsed and ignored.
		if !p.eof() && p.peek().kind == 'op' && p.peek().text == ',' {
			p.next()
			fallback := p.parse_expr()!
			_ = fallback
		}
		return StyleValue{ dim: .px, value: edge }
	}
	if p.eof() || p.peek().kind != 'op' || p.peek().text != ',' {
		return StyleValue{ dim: .px, value: 0 }
	}
	p.next()
	fallback := p.parse_expr()!
	coerced := style_math_coerce(fallback, StyleValue{ dim: .px }) or {
		return error('env() fallback must be a length')
	}
	if coerced.dim != .px {
		return error('env() fallback must be a length')
	}
	return coerced
}
