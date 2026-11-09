module ui2

// ── Prelude parsing ─────────────────────────────────────────────────
// These run on the same StyleParser the stylesheet parser uses; only the
// prelude (before the block's `{`) is read here.

// parse_media_prelude parses one @media prelude (comma-separated queries)
// from a standalone string, for the DSL.
pub fn parse_media_prelude(source string) ![]MediaQuery {
	mut parser := StyleParser{
		src: source
	}
	queries := parser.parse_media_queries()!
	parser.skip_space_and_comments()!
	if !parser.eof() {
		return error(style_err(parser.line, parser.col, 'unexpected text after @media prelude'))
	}
	return queries
}

// parse_container_prelude parses one @container prelude from a standalone
// string, for the DSL.
pub fn parse_container_prelude(source string) ![]ContainerQuery {
	mut parser := StyleParser{
		src: source
	}
	queries := parser.parse_container_queries()!
	parser.skip_space_and_comments()!
	if !parser.eof() {
		return error(style_err(parser.line, parser.col,
			'unexpected text after @container prelude'))
	}
	return queries
}

fn (mut p StyleParser) parse_media_queries() ![]MediaQuery {
	mut queries := []MediaQuery{}
	for {
		p.skip_space_and_comments()!
		queries << p.parse_media_query()!
		p.skip_space_and_comments()!
		if !p.eof() && p.peek() == `,` {
			p.advance()
			continue
		}
		break
	}
	if queries.len == 0 {
		return error(style_err(p.line, p.col, 'expected a media query'))
	}
	return queries
}

fn (mut p StyleParser) parse_media_query() !MediaQuery {
	mut negate := false
	mut conditions := []MediaCondition{}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `(` {
		word := p.parse_ident()!.to_lower()
		if word != 'not' {
			return error(style_err(p.line, p.col, 'expected `not` or a `(...)` condition'))
		}
		negate = true
		p.skip_space_and_comments()!
	}
	for {
		p.skip_space_and_comments()!
		conditions << p.parse_media_condition()!
		p.skip_space_and_comments()!
		if p.eof() {
			break
		}
		if is_style_name_start(p.peek()) {
			saved_pos := p.pos
			saved_line := p.line
			saved_col := p.col
			word := p.parse_ident()!.to_lower()
			if word == 'and' {
				continue
			}
			p.pos = saved_pos
			p.line = saved_line
			p.col = saved_col
			break
		}
		break
	}
	if conditions.len == 0 {
		return error(style_err(p.line, p.col, 'a media query needs at least one condition'))
	}
	return MediaQuery{
		negate:     negate
		conditions: conditions
	}
}

fn (mut p StyleParser) parse_media_condition() !MediaCondition {
	if p.eof() || p.peek() != `(` {
		return error(style_err(p.line, p.col, 'expected a `(feature: value)` condition'))
	}
	line := p.line
	col := p.col
	p.advance()
	p.skip_space_and_comments()!
	word := p.parse_ident()!.to_lower()
	mut op := ''
	mut feature := word
	if word.starts_with('min-') && word.len > 4 {
		op = 'min'
		feature = word[4..]
	} else if word.starts_with('max-') && word.len > 4 {
		op = 'max'
		feature = word[4..]
	}
	p.skip_space_and_comments()!
	mut value := ''
	if !p.eof() && p.peek() == `:` {
		p.advance()
		p.skip_space_and_comments()!
		value = p.parse_condition_value()!
	}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `)` {
		return error(style_err(p.line, p.col, 'expected `)` to close the condition'))
	}
	p.advance()
	condition := style_validate_condition(feature, op, value, false) or {
		return error(style_err(line, col, err.msg()))
	}
	return condition
}

fn (mut p StyleParser) parse_condition_value() !string {
	mut out := []u8{}
	for !p.eof() && p.peek() != `)` {
		out << p.advance()
	}
	if p.eof() {
		return error(style_err(p.line, p.col, 'unclosed condition value'))
	}
	return out.bytestr().trim_space()
}

fn style_validate_condition(feature string, op string, value string, in_container bool) !MediaCondition {
	if feature !in ['orientation', 'platform', 'pointer', 'prefers-color-scheme', 'width', 'height',
		'resolution'] {
		if in_container || !style_plugin_has_media(feature) {
			return error('unknown query feature "${feature}"')
		}
		// Plugin-owned features pass through untouched: the plugin validates
		// the value at match time.
		if value.len == 0 {
			return error('"${feature}" needs a value')
		}
		return MediaCondition{
			feature: feature
			op:      op
			value:   value.to_lower()
		}
	}
	if in_container && feature !in ['width', 'height'] {
		return error('"${feature}" is a media feature; containers test width/height only')
	}
	if op != '' && feature !in ['width', 'height', 'resolution'] {
		return error('"${op}-${feature}" is not a query: min-/max- apply to width, height and resolution')
	}
	if value.len == 0 {
		return error('"${feature}" needs a value')
	}
	match feature {
		'orientation' {
			if value !in ['landscape', 'portrait'] {
				return error('"${value}" is not an orientation; use landscape or portrait')
			}
		}
		'platform' {
			if value.fields().len != 1 {
				return error('"${value}" is not a platform name')
			}
		}
		'pointer' {
			if value !in ['coarse', 'fine'] {
				return error('"${value}" is not a pointer kind; use coarse or fine')
			}
		}
		'prefers-color-scheme' {
			if value !in ['dark', 'light'] {
				return error('"${value}" is not a color scheme; use dark or light')
			}
		}
		'width', 'height' {
			if _ := query_css_length(value) {
			} else {
				return error('"${value}" is not a length; use a number or px')
			}
		}
		'resolution' {
			if _ := query_resolution_value(value) {
			} else {
				return error('"${value}" is not a resolution; use a number with dppx or x')
			}
		}
		else {}
	}
	return MediaCondition{
		feature: feature
		op:      op
		value:   value.to_lower()
	}
}

fn (mut p StyleParser) parse_container_queries() ![]ContainerQuery {
	mut queries := []ContainerQuery{}
	for {
		p.skip_space_and_comments()!
		queries << p.parse_container_query()!
		p.skip_space_and_comments()!
		if !p.eof() && p.peek() == `,` {
			p.advance()
			continue
		}
		break
	}
	if queries.len == 0 {
		return error(style_err(p.line, p.col, 'expected a container query'))
	}
	return queries
}

fn (mut p StyleParser) parse_container_query() !ContainerQuery {
	mut name := ''
	mut conditions := []MediaCondition{}
	p.skip_space_and_comments()!
	if p.eof() {
		return error(style_err(p.line, p.col, 'expected a container name or condition'))
	}
	if p.peek() != `(` {
		name = p.parse_ident()!
	}
	for {
		p.skip_space_and_comments()!
		if p.eof() || p.peek() != `(` {
			break
		}
		conditions << p.parse_container_condition()!
		p.skip_space_and_comments()!
		if p.eof() {
			break
		}
		if is_style_name_start(p.peek()) {
			saved_pos := p.pos
			saved_line := p.line
			saved_col := p.col
			word := p.parse_ident()!.to_lower()
			if word == 'and' {
				continue
			}
			p.pos = saved_pos
			p.line = saved_line
			p.col = saved_col
			break
		}
		break
	}
	if name.len == 0 && conditions.len == 0 {
		return error(style_err(p.line, p.col,
			'a container query needs a name, a condition, or both'))
	}
	return ContainerQuery{
		name:       name
		conditions: conditions
	}
}

fn (mut p StyleParser) parse_container_condition() !MediaCondition {
	if p.eof() || p.peek() != `(` {
		return error(style_err(p.line, p.col, 'expected a `(size: value)` condition'))
	}
	line := p.line
	col := p.col
	p.advance()
	p.skip_space_and_comments()!
	word := p.parse_ident()!.to_lower()
	mut op := ''
	mut feature := word
	if word.starts_with('min-') && word.len > 4 {
		op = 'min'
		feature = word[4..]
	} else if word.starts_with('max-') && word.len > 4 {
		op = 'max'
		feature = word[4..]
	}
	p.skip_space_and_comments()!
	mut value := ''
	if !p.eof() && p.peek() == `:` {
		p.advance()
		p.skip_space_and_comments()!
		value = p.parse_condition_value()!
	}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `)` {
		return error(style_err(p.line, p.col, 'expected `)` to close the condition'))
	}
	p.advance()
	condition := style_validate_condition(feature, op, value, true) or {
		return error(style_err(line, col, err.msg()))
	}
	return condition
}

// ── Query blocks ────────────────────────────────────────────────────
// parse_query_block parses `@media ... { }` / `@container ... { }` after
// the keyword, attaching the accumulated queries to every inner rule.
// Nesting accumulates (intersection); only rules and further query blocks
// may appear inside.

fn (mut p StyleParser) parse_query_block(m_acc []MediaQuery, c_acc []ContainerQuery) ![]StyleRule {
	mut media := m_acc.clone()
	mut containers := c_acc.clone()
	if p.src[p.pos..].starts_with('@media') {
		for _ in 0 .. 6 {
			p.advance()
		}
		for query in p.parse_media_queries()! {
			media << query
		}
	} else if p.src[p.pos..].starts_with('@container') {
		for _ in 0 .. 10 {
			p.advance()
		}
		for query in p.parse_container_queries()! {
			containers << query
		}
	} else {
		return error(style_err(p.line, p.col, 'expected `@media` or `@container`'))
	}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `{` {
		return error(style_err(p.line, p.col, 'expected `{` after the query'))
	}
	p.advance()
	return p.parse_block(media, containers, false)
}
