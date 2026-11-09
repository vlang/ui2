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

// parse_media_query parses one comma-free query: an optional `not` or
// `only`, an optional media type (`all`, `screen`, `print`, ...), then
// `(feature: value)` conditions joined by `and`. A media type needs `and`
// before its first condition, as in CSS.
fn (mut p StyleParser) parse_media_query() !MediaQuery {
	mut negate := false
	mut media_type := ''
	mut conditions := []MediaCondition{}
	p.skip_space_and_comments()!
	if !p.eof() && p.peek() != `(` {
		mut word_line := p.line
		mut word_col := p.col
		mut word := p.parse_ident() or {
			return error(style_err(p.line, p.col, 'expected `not`, a media type or a `(...)` condition'))
		}.to_lower()
		if word == 'not' || word == 'only' {
			negate = word == 'not'
			p.skip_space_and_comments()!
			if !p.eof() && p.peek() != `(` {
				word_line = p.line
				word_col = p.col
				word = p.parse_ident()!.to_lower()
			} else {
				word = ''
			}
		}
		if word != '' {
			if word !in style_media_types {
				return error(style_err(word_line, word_col, 'unknown media type "${word}"'))
			}
			media_type = word
			p.skip_space_and_comments()!
			if !p.media_and_follows()! {
				return MediaQuery{
					negate:     negate
					media_type: media_type
				}
			}
		}
	}
	for {
		p.skip_space_and_comments()!
		conditions << p.parse_media_condition()!
		p.skip_space_and_comments()!
		if !p.media_and_follows()! {
			break
		}
	}
	return MediaQuery{
		negate:     negate
		media_type: media_type
		conditions: conditions
	}
}

// media_and_follows consumes an `and` keyword when one is next and reports
// whether it did; anything else is left for the caller.
fn (mut p StyleParser) media_and_follows() !bool {
	if p.eof() || !is_style_name_start(p.peek()) {
		return false
	}
	saved_pos := p.pos
	saved_line := p.line
	saved_col := p.col
	word := p.parse_ident()!.to_lower()
	if word == 'and' {
		return true
	}
	p.pos = saved_pos
	p.line = saved_line
	p.col = saved_col
	return false
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

fn style_validate_condition(feature string, op string, raw_value string, in_container bool) !MediaCondition {
	if feature !in ['orientation', 'platform', 'pointer', 'prefers-color-scheme', 'width', 'height',
		'resolution'] {
		if in_container || !style_plugin_has_media(feature) {
			return error('unknown query feature "${feature}"')
		}
		// Plugin-owned features pass through untouched: the plugin validates
		// the value at match time.
		if raw_value.len == 0 {
			return error('"${feature}" needs a value')
		}
		return MediaCondition{
			feature: feature
			op:      op
			value:   raw_value.to_lower()
		}
	}
	if in_container && feature !in ['width', 'height'] {
		return error('"${feature}" is a media feature; containers test width/height only')
	}
	if op != '' && feature !in ['width', 'height', 'resolution'] {
		return error('"${op}-${feature}" is not a query: min-/max- apply to width, height and resolution')
	}
	if raw_value.len == 0 {
		return error('"${feature}" needs a value')
	}
	// Keywords compare ASCII-case-insensitively, as in CSS; a quoted
	// keyword is accepted too, so `(platform: "windows")` does not turn
	// into a condition that can never hold.
	value := if feature in ['orientation', 'platform', 'pointer', 'prefers-color-scheme'] {
		style_unquote(raw_value).to_lower()
	} else {
		raw_value
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
		if !p.media_and_follows()! {
			break
		}
		// `and` must lead to another condition.
		p.skip_space_and_comments()!
		if p.eof() || p.peek() != `(` {
			return error(style_err(p.line, p.col, 'expected a `(size: value)` condition after `and`'))
		}
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
// the keyword. The block's query list becomes one more nesting level on
// every inner rule: levels intersect (each must hold), while the commas
// inside one level stay OR. Only rules and further query blocks may
// appear inside.

fn (mut p StyleParser) parse_query_block(q StyleQueryCtx) ![]StyleRule {
	mut media := q.media.clone()
	mut containers := q.containers.clone()
	if p.src[p.pos..].starts_with('@media') {
		for _ in 0 .. 6 {
			p.advance()
		}
		media << p.parse_media_queries()!
	} else if p.src[p.pos..].starts_with('@container') {
		for _ in 0 .. 10 {
			p.advance()
		}
		containers << p.parse_container_queries()!
	} else {
		return error(style_err(p.line, p.col, 'expected `@media` or `@container`'))
	}
	p.skip_space_and_comments()!
	if p.eof() || p.peek() != `{` {
		return error(style_err(p.line, p.col, 'expected `{` after the query'))
	}
	p.advance()
	return p.parse_block(StyleQueryCtx{
		media:      media
		containers: containers
	}, false)
}

// style_media_types are the CSS media types. `all` and `screen` match
// every ui2 window; the rest (print, speech and the deprecated ones) never
// match, as CSS treats them on a screen.
const style_media_types = ['all', 'screen', 'print', 'speech', 'tty', 'tv', 'projection', 'handheld',
	'braille', 'embossed', 'aural']

// style_unquote strips one pair of matching quotes around text.
fn style_unquote(text string) string {
	trimmed := text.trim_space()
	if trimmed.len >= 2 && ((trimmed[0] == `"` && trimmed[trimmed.len - 1] == `"`)
		|| (trimmed[0] == `'` && trimmed[trimmed.len - 1] == `'`)) {
		return trimmed[1..trimmed.len - 1].trim_space()
	}
	return trimmed
}
