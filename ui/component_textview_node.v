module ui2

import strings

// The document model a TextView renders, after GPUI Kit's TextView. Markdown
// and HTML both parse into the same tree of TextViewNode values, so layout and
// rendering never look at the source again. Parsing also produces the text the
// view shows (`TextViewDocument.text`, GPUI Kit's `rendered_text()`) and a map
// from that text back to the source, which is what highlights, reveals and the
// streaming fade address.

// TextViewNodeKind names a node of the parsed document. Block kinds hold other
// blocks or inline content; inline kinds hold text.
pub enum TextViewNodeKind {
	document
	paragraph
	heading
	blockquote
	list
	list_item
	code_block
	thematic_break
	table
	table_row
	table_cell
	html_block
	frontmatter
	text
	emphasis
	strong
	strikethrough
	code_span
	link
	image
	soft_break
	hard_break
}

// TextViewTask is the check box a GFM task list item starts with.
pub enum TextViewTask {
	plain
	unchecked
	checked
}

// TextViewAlign is a table column's alignment from its delimiter row.
pub enum TextViewAlign {
	auto
	left
	center
	right
}

// TextViewEntry is one `key: value` of YAML front matter. The offsets locate the
// key and value in the document's rendered text.
pub struct TextViewEntry {
pub:
	key         string
	value       string
	key_start   int
	value_start int
}

// TextViewSpan maps rendered text back to source: the bytes rendered_start to
// rendered_end came from source_start to source_end. A verbatim span maps byte
// for byte; any other (an entity, an escape, a code span with a line break in
// it) is one unit, so a source range touching it covers all of it.
pub struct TextViewSpan {
pub:
	rendered_start int
	rendered_end   int
	source_start   int
	source_end     int
	verbatim       bool
}

// TextViewRange is a half-open byte range of a document's rendered text.
pub struct TextViewRange {
pub:
	start int
	end   int
}

pub struct TextViewNode {
	// A text whose bytes came from several stretches of source (HTML whitespace
	// collapsing, decoded entities) maps through these, offsets relative to text.
	segments []TextViewSpan
	// Parsing state: the inline content a Markdown block still has to parse, and
	// the raw tag of inline HTML still to be paired.
	slot int = -1
	tag  string
pub:
	kind     TextViewNodeKind
	children []TextViewNode
	// text is the content of a text, code span or code block, an image's alt
	// text, or the raw source of an HTML block.
	text    string
	level   int  // heading: 1 to 6
	ordered bool // list
	start   int = 1 // list: the first item's number
	tight   bool            // list: items are not separated by blank lines
	task    TextViewTask    // list_item
	fenced  bool            // code_block: fenced rather than indented
	lang    string          // code_block: the first word of the info string
	info    string          // code_block: the whole info string
	url     string          // link destination or image source
	title   string          // link or image title
	align   TextViewAlign   // table_cell
	header  bool            // table_row and table_cell of the head row
	width   f64             // image: width from HTML attributes, 0 when unknown
	height  f64             // image: height from HTML attributes
	entries []TextViewEntry // frontmatter
	// index numbers links (into TextViewDocument.links) and code blocks (into
	// TextViewDocument.code_blocks) in document order; -1 elsewhere.
	index int = -1
	// The node's bytes in the source and in the rendered text.
	source_start   int
	source_end     int
	rendered_start int
	rendered_end   int
	verbatim       bool // text: its bytes are the source's from source_start on
}

// TextViewCodeBlock is a code block of a document, as its copy button and code
// block actions report it.
pub struct TextViewCodeBlock {
pub:
	index int
	lang  string
	info  string
	code  string
}

// TextViewDocument is a parsed Markdown or HTML document. Parse once, then lay
// it out for each width with text_view_layout.
pub struct TextViewDocument {
pub:
	root        TextViewNode
	source      string
	html        bool
	text        string // the rendered text: what plain copy produces
	spans       []TextViewSpan
	links       []string // destination of each link, by TextViewNode.index
	code_blocks []TextViewCodeBlock
}

// rendered_text is the text the view shows, GPUI Kit's `rendered_text()`:
// `hello **world**` reads `hello world`, escapes and entities are resolved,
// heading and list markers and table pipes are left out. Blocks are separated
// by a line break, table cells by a tab, and a soft line break reads as a
// space. Images, rules and front matter separators render nothing.
pub fn (doc TextViewDocument) rendered_text() string {
	return doc.text
}

// range_for_source converts a byte range of the source into the smallest range
// of the rendered text that holds every character rendered from it. Source
// that renders nothing (emphasis delimiters, markers, fences, pipes, link
// destinations) adds nothing, so `**bold**` and `bold` convert to the same
// range. None when the range is empty, out of bounds, not on character
// boundaries, or renders nothing.
pub fn (doc TextViewDocument) range_for_source(start int, end int) ?TextViewRange {
	if start < 0 || end > doc.source.len || start >= end
		|| !tv_char_boundary(doc.source, start) || !tv_char_boundary(doc.source, end) {
		return none
	}
	mut lo := -1
	mut hi := -1
	for span in doc.spans {
		if span.source_end <= start || span.source_start >= end {
			continue
		}
		mut a := span.rendered_start
		mut b := span.rendered_end
		if span.verbatim {
			a = span.rendered_start + tv_max_int(0, start - span.source_start)
			b = span.rendered_start + tv_min_int(span.rendered_end - span.rendered_start,
				end - span.source_start)
			a = tv_floor_boundary(doc.text, a)
			b = tv_ceil_boundary(doc.text, b)
		}
		if a >= b {
			continue
		}
		if lo < 0 || a < lo {
			lo = a
		}
		if b > hi {
			hi = b
		}
	}
	if lo < 0 {
		return none
	}
	return TextViewRange{lo, hi}
}

// rendered_offset_for_source is where in the rendered text the characters
// rendered from source at or after `offset` begin: the first byte text appended
// at that source offset shows as. A character any of whose source is at or
// after the offset counts, so an entity completed by an append is new.
pub fn (doc TextViewDocument) rendered_offset_for_source(offset int) int {
	for span in doc.spans {
		if span.source_end <= offset {
			continue
		}
		if !span.verbatim || offset <= span.source_start {
			return span.rendered_start
		}
		return tv_ceil_boundary(doc.text, span.rendered_start + offset - span.source_start)
	}
	return doc.text.len
}

// text_view_valid_range reports whether start..end is a range of text a
// highlight or reveal may use: ordered, in bounds and on character boundaries.
pub fn text_view_valid_range(text string, start int, end int) bool {
	return start >= 0 && end <= text.len && start <= end && tv_char_boundary(text, start)
		&& tv_char_boundary(text, end)
}

fn tv_char_boundary(s string, i int) bool {
	if i <= 0 || i >= s.len {
		return i == 0 || i == s.len
	}
	return s[i] & 0xc0 != 0x80
}

fn tv_floor_boundary(s string, i int) int {
	mut k := tv_min_int(tv_max_int(i, 0), s.len)
	for k > 0 && k < s.len && s[k] & 0xc0 == 0x80 {
		k--
	}
	return k
}

fn tv_ceil_boundary(s string, i int) int {
	mut k := tv_min_int(tv_max_int(i, 0), s.len)
	for k < s.len && s[k] & 0xc0 == 0x80 {
		k++
	}
	return k
}

fn tv_min_int(a int, b int) int {
	return if a < b { a } else { b }
}

fn tv_max_int(a int, b int) int {
	return if a > b { a } else { b }
}

// tv_plain_text concatenates the text inline nodes show: an image's alt text,
// a link's or emphasis's content.
fn tv_plain_text(nodes []TextViewNode) string {
	mut sb := strings.new_builder(32)
	tv_plain_text_into(nodes, mut sb)
	return sb.str()
}

fn tv_plain_text_into(nodes []TextViewNode, mut sb strings.Builder) {
	for n in nodes {
		match n.kind {
			.text, .code_span, .image {
				sb.write_string(n.text)
			}
			.soft_break {
				sb.write_u8(` `)
			}
			.hard_break {
				sb.write_u8(`\n`)
			}
			else {
				tv_plain_text_into(n.children, mut sb)
			}
		}
	}
}

// ── Rendered text ───────────────────────────────────────────────────

// TvRenderBuilder assigns every node its place in the rendered text, numbers
// links and code blocks, and records the span map.
struct TvRenderBuilder {
mut:
	sb    strings.Builder
	spans []TextViewSpan
	links []string
	codes []TextViewCodeBlock
}

fn tv_finish_document(root TextViewNode, source string, html bool) TextViewDocument {
	mut b := TvRenderBuilder{
		sb: strings.new_builder(source.len + 16)
	}
	finished := b.block(root)
	return TextViewDocument{
		root:        finished
		source:      source
		html:        html
		text:        b.sb.str()
		spans:       b.spans
		links:       b.links
		code_blocks: b.codes
	}
}

// start_line separates a block's text from the text before it.
fn (mut b TvRenderBuilder) start_line() {
	if b.sb.len > 0 {
		b.sb.write_u8(`\n`)
	}
}

fn (mut b TvRenderBuilder) block(n TextViewNode) TextViewNode {
	match n.kind {
		.paragraph, .heading {
			b.start_line()
			start := b.sb.len
			children := b.inlines(n.children)
			return TextViewNode{
				...n
				children:       children
				rendered_start: start
				rendered_end:   b.sb.len
			}
		}
		.code_block {
			b.start_line()
			start := b.sb.len
			mut lines := []TextViewNode{cap: n.children.len}
			for i, line in n.children {
				if i > 0 {
					b.sb.write_u8(`\n`)
				}
				lines << b.leaf(line)
			}
			index := b.codes.len
			b.codes << TextViewCodeBlock{
				index: index
				lang:  n.lang
				info:  n.info
				code:  n.text
			}
			return TextViewNode{
				...n
				children:       lines
				index:          index
				rendered_start: start
				rendered_end:   b.sb.len
			}
		}
		.table {
			start := b.sb.len
			mut rows := []TextViewNode{cap: n.children.len}
			for row in n.children {
				b.start_line()
				row_start := b.sb.len
				mut cells := []TextViewNode{cap: row.children.len}
				for i, cell in row.children {
					if i > 0 {
						b.sb.write_u8(`\t`)
					}
					cell_start := b.sb.len
					children := b.inlines(cell.children)
					cells << TextViewNode{
						...cell
						children:       children
						rendered_start: cell_start
						rendered_end:   b.sb.len
					}
				}
				rows << TextViewNode{
					...row
					children:       cells
					rendered_start: row_start
					rendered_end:   b.sb.len
				}
			}
			return TextViewNode{
				...n
				children:       rows
				rendered_start: start
				rendered_end:   b.sb.len
			}
		}
		.frontmatter {
			start := b.sb.len
			mut entries := []TextViewEntry{cap: n.entries.len}
			for entry in n.entries {
				b.start_line()
				key_start := b.sb.len
				b.sb.write_string(entry.key)
				b.sb.write_u8(`\t`)
				value_start := b.sb.len
				b.sb.write_string(entry.value)
				entries << TextViewEntry{
					key:         entry.key
					value:       entry.value
					key_start:   key_start
					value_start: value_start
				}
			}
			return TextViewNode{
				...n
				entries:        entries
				rendered_start: start
				rendered_end:   b.sb.len
			}
		}
		.thematic_break {
			return TextViewNode{
				...n
				rendered_start: b.sb.len
				rendered_end:   b.sb.len
			}
		}
		.document, .blockquote, .list, .list_item, .html_block, .table_row, .table_cell {
			start := b.sb.len
			mut children := []TextViewNode{cap: n.children.len}
			for child in n.children {
				children << b.block(child)
			}
			return TextViewNode{
				...n
				children:       children
				rendered_start: start
				rendered_end:   b.sb.len
			}
		}
		else {
			// Inline content left at block level reads as a paragraph of its own.
			b.start_line()
			return b.inline(n)
		}
	}
}

fn (mut b TvRenderBuilder) inlines(nodes []TextViewNode) []TextViewNode {
	mut out := []TextViewNode{cap: nodes.len}
	for n in nodes {
		out << b.inline(n)
	}
	return out
}

fn (mut b TvRenderBuilder) inline(n TextViewNode) TextViewNode {
	start := b.sb.len
	match n.kind {
		.text, .code_span {
			return b.leaf(n)
		}
		.soft_break {
			b.sb.write_u8(` `)
		}
		.hard_break {
			b.sb.write_u8(`\n`)
		}
		.image {
			return TextViewNode{
				...n
				rendered_start: start
				rendered_end:   start
			}
		}
		.link {
			index := b.links.len
			b.links << n.url
			children := b.inlines(n.children)
			return TextViewNode{
				...n
				children:       children
				index:          index
				rendered_start: start
				rendered_end:   b.sb.len
			}
		}
		else {
			children := b.inlines(n.children)
			return TextViewNode{
				...n
				children:       children
				rendered_start: start
				rendered_end:   b.sb.len
			}
		}
	}
	return TextViewNode{
		...n
		rendered_start: start
		rendered_end:   b.sb.len
	}
}

// leaf writes a text-bearing node and the spans mapping it to source.
fn (mut b TvRenderBuilder) leaf(n TextViewNode) TextViewNode {
	start := b.sb.len
	b.sb.write_string(n.text)
	if n.segments.len > 0 {
		for seg in n.segments {
			b.spans << TextViewSpan{
				rendered_start: start + seg.rendered_start
				rendered_end:   start + seg.rendered_end
				source_start:   seg.source_start
				source_end:     seg.source_end
				verbatim:       seg.verbatim
			}
		}
	} else if n.text.len > 0 && n.source_end > n.source_start {
		b.spans << TextViewSpan{
			rendered_start: start
			rendered_end:   start + n.text.len
			source_start:   n.source_start
			source_end:     n.source_end
			verbatim:       n.verbatim && n.source_end - n.source_start == n.text.len
		}
	}
	return TextViewNode{
		...n
		rendered_start: start
		rendered_end:   b.sb.len
	}
}

// ── Text segments ───────────────────────────────────────────────────

// tv_segments_slice keeps the part of a text's segment map covering its bytes
// a..b, rebased so a is 0.
fn tv_segments_slice(segs []TextViewSpan, a int, b int) []TextViewSpan {
	mut out := []TextViewSpan{}
	for seg in segs {
		if seg.rendered_end <= a || seg.rendered_start >= b {
			continue
		}
		lo := tv_max_int(seg.rendered_start, a)
		hi := tv_min_int(seg.rendered_end, b)
		if seg.verbatim {
			out << TextViewSpan{
				rendered_start: lo - a
				rendered_end:   hi - a
				source_start:   seg.source_start + lo - seg.rendered_start
				source_end:     seg.source_start + hi - seg.rendered_start
				verbatim:       true
			}
		} else {
			out << TextViewSpan{
				rendered_start: lo - a
				rendered_end:   hi - a
				source_start:   seg.source_start
				source_end:     seg.source_end
			}
		}
	}
	return out
}

// tv_text_slice is the part a..b of a text node, its source map kept.
fn tv_text_slice(n TextViewNode, a int, b int) TextViewNode {
	if a == 0 && b == n.text.len {
		return n
	}
	if n.segments.len > 0 {
		segs := tv_segments_slice(n.segments, a, b)
		return TextViewNode{
			...n
			text:         n.text[a..b]
			segments:     segs
			source_start: if segs.len > 0 { segs[0].source_start } else { n.source_start }
			source_end:   if segs.len > 0 { segs.last().source_end } else { n.source_start }
		}
	}
	if n.verbatim {
		return TextViewNode{
			...n
			text:         n.text[a..b]
			source_start: n.source_start + a
			source_end:   n.source_start + b
		}
	}
	return TextViewNode{
		...n
		text: n.text[a..b]
	}
}

// ── Entities ────────────────────────────────────────────────────────

// tv_decode_entity decodes the character reference at s[pos] (`&amp;`,
// `&#169;`, `&#x1F600;`) and reports how many bytes it took, or 0 when there
// is none there. Named references cover the common HTML set.
fn tv_decode_entity(s string, pos int) (string, int) {
	if pos >= s.len || s[pos] != `&` {
		return '', 0
	}
	mut end := pos + 1
	for end < s.len && end - pos <= 32 && s[end] != `;` {
		c := s[end]
		if !(c.is_letter() || c.is_digit() || c == `#`) {
			return '', 0
		}
		end++
	}
	if end >= s.len || s[end] != `;` || end == pos + 1 {
		return '', 0
	}
	name := s[pos + 1..end]
	if name[0] == `#` {
		mut code := u32(0)
		digits := name[1..]
		if digits.len == 0 {
			return '', 0
		}
		if digits[0] == `x` || digits[0] == `X` {
			hex := digits[1..]
			if hex.len == 0 || hex.len > 6 {
				return '', 0
			}
			for c in hex {
				v := if c >= `0` && c <= `9` {
					u32(c - `0`)
				} else if c >= `a` && c <= `f` {
					u32(c - `a` + 10)
				} else if c >= `A` && c <= `F` {
					u32(c - `A` + 10)
				} else {
					return '', 0
				}
				code = code * 16 + v
			}
		} else {
			if digits.len > 7 {
				return '', 0
			}
			for c in digits {
				if !c.is_digit() {
					return '', 0
				}
				code = code * 10 + u32(c - `0`)
			}
		}
		if code == 0 || code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff) {
			code = 0xfffd
		}
		return rune(code).str(), end + 1 - pos
	}
	value := tv_named_entity(name)
	if value.len == 0 {
		return '', 0
	}
	return value, end + 1 - pos
}

fn tv_named_entity(name string) string {
	return match name {
		'amp' { '&' }
		'lt' { '<' }
		'gt' { '>' }
		'quot' { '"' }
		'apos' { "'" }
		'nbsp' { '\u00a0' }
		'copy' { '©' }
		'reg' { '®' }
		'trade' { '™' }
		'hellip' { '…' }
		'mdash' { '—' }
		'ndash' { '–' }
		'lsquo' { '‘' }
		'rsquo' { '’' }
		'ldquo' { '“' }
		'rdquo' { '”' }
		'laquo' { '«' }
		'raquo' { '»' }
		'bull' { '•' }
		'middot' { '·' }
		'times' { '×' }
		'divide' { '÷' }
		'deg' { '°' }
		'plusmn' { '±' }
		'para' { '¶' }
		'sect' { '§' }
		'euro' { '€' }
		'pound' { '£' }
		'yen' { '¥' }
		'cent' { '¢' }
		'larr' { '←' }
		'rarr' { '→' }
		'uarr' { '↑' }
		'darr' { '↓' }
		'harr' { '↔' }
		'lArr' { '⇐' }
		'rArr' { '⇒' }
		'hearts' { '♥' }
		'check' { '✓' }
		'le' { '≤' }
		'ge' { '≥' }
		'ne' { '≠' }
		'asymp' { '≈' }
		'infin' { '∞' }
		'minus' { '−' }
		'prime' { '′' }
		'frac12' { '½' }
		'frac14' { '¼' }
		'frac34' { '¾' }
		'sup2' { '²' }
		'sup3' { '³' }
		'micro' { 'µ' }
		'shy' { '\u00ad' }
		'zwj' { '\u200d' }
		'zwnj' { '\u200c' }
		'ensp' { '\u2002' }
		'emsp' { '\u2003' }
		'thinsp' { '\u2009' }
		'iexcl' { '¡' }
		'iquest' { '¿' }
		'auml' { 'ä' }
		'ouml' { 'ö' }
		'uuml' { 'ü' }
		'Auml' { 'Ä' }
		'Ouml' { 'Ö' }
		'Uuml' { 'Ü' }
		'szlig' { 'ß' }
		'eacute' { 'é' }
		'egrave' { 'è' }
		'agrave' { 'à' }
		'aacute' { 'á' }
		'ccedil' { 'ç' }
		'ntilde' { 'ñ' }
		'oslash' { 'ø' }
		'aring' { 'å' }
		else { '' }
	}
}

// tv_decode_text decodes every entity in s and returns the decoded text with a
// segment map onto source starting at `base`: verbatim stretches and one
// segment per entity.
fn tv_decode_text(s string, base int) (string, []TextViewSpan) {
	if !s.contains('&') {
		return s, [
			TextViewSpan{
				rendered_start: 0
				rendered_end:   s.len
				source_start:   base
				source_end:     base + s.len
				verbatim:       true
			},
		]
	}
	mut sb := strings.new_builder(s.len)
	mut segs := []TextViewSpan{}
	mut run_start := 0
	mut i := 0
	for i < s.len {
		if s[i] == `&` {
			decoded, n := tv_decode_entity(s, i)
			if n > 0 {
				if i > run_start {
					at := sb.len
					sb.write_string(s[run_start..i])
					segs << TextViewSpan{
						rendered_start: at
						rendered_end:   sb.len
						source_start:   base + run_start
						source_end:     base + i
						verbatim:       true
					}
				}
				at := sb.len
				sb.write_string(decoded)
				segs << TextViewSpan{
					rendered_start: at
					rendered_end:   sb.len
					source_start:   base + i
					source_end:     base + i + n
				}
				i += n
				run_start = i
				continue
			}
		}
		i++
	}
	if run_start < s.len {
		at := sb.len
		sb.write_string(s[run_start..])
		segs << TextViewSpan{
			rendered_start: at
			rendered_end:   sb.len
			source_start:   base + run_start
			source_end:     base + s.len
			verbatim:       true
		}
	}
	return sb.str(), segs
}
