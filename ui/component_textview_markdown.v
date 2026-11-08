module ui2

// A Markdown parser for TextView: CommonMark's block structure (paragraphs,
// ATX and setext headings, block quotes with lazy continuation, bullet and
// ordered lists with loose/tight detection, fenced and indented code, thematic
// breaks, HTML blocks, link reference definitions) plus GitHub's tables, task
// list items, strikethrough and bare autolinks, and optional YAML front matter.
// It is a pragmatic subset written for display, not a conformance-tested
// CommonMark implementation. Inline parsing is in component_textview_inline.v.

pub struct TextViewMarkdownOptions {
pub:
	// frontmatter reads a leading `---` block as YAML front matter, as GPUI Kit's
	// MarkdownExtensions::frontmatter does. Off by default: it is not Markdown.
	frontmatter bool
	// html parses raw HTML blocks and the common inline tags (b, i, code, a, br,
	// ...) through the HTML path. Off, they show as text.
	html bool = true
}

// text_view_markdown parses Markdown with the default options.
pub fn text_view_markdown(source string) TextViewDocument {
	return text_view_parse_markdown(source, TextViewMarkdownOptions{})
}

// text_view_parse_markdown parses Markdown into a document. It never fails:
// anything it does not understand reads as text.
pub fn text_view_parse_markdown(source string, options TextViewMarkdownOptions) TextViewDocument {
	mut p := TvMdParser{
		source:  source
		options: options
	}
	lines := tvmd_lines(source)
	mut start := 0
	mut blocks := []TextViewNode{}
	if options.frontmatter {
		consumed, front := tvmd_frontmatter(lines)
		if consumed > 0 {
			blocks << front
			start = consumed
		}
	}
	blocks << p.blocks(lines[start..])
	root := TextViewNode{
		kind:         .document
		children:     p.resolve_inlines(blocks)
		source_start: 0
		source_end:   source.len
	}
	return tv_finish_document(root, source, false)
}

struct TvMdLine {
	text string
	src  int // source offset of text[0]
}

struct TvMdRef {
	url   string
	title string
}

// TvMdInline is the inline content of a block, still to be parsed once every
// link reference definition is known. segs maps its offsets onto source: from
// pos on, text continues from src.
struct TvMdInline {
	text string
	segs []TvMdSeg
}

struct TvMdSeg {
	pos int
	src int
}

struct TvMdParser {
	source  string
	options TextViewMarkdownOptions
mut:
	refs    map[string]TvMdRef
	inlines []TvMdInline
	depth   int // containers open around the lines being parsed
}

fn tvmd_lines(source string) []TvMdLine {
	mut lines := []TvMdLine{}
	mut start := 0
	for i := 0; i <= source.len; i++ {
		if i == source.len || source[i] == `\n` {
			if i == source.len && start == source.len {
				break
			}
			mut end := i
			if end > start && source[end - 1] == `\r` {
				end--
			}
			lines << TvMdLine{source[start..end], start}
			start = i + 1
		}
	}
	return lines
}

// tvmd_indent counts the columns of leading whitespace, tabs stopping at
// multiples of four.
fn tvmd_indent(s string) int {
	mut col := 0
	for c in s {
		if c == ` ` {
			col++
		} else if c == `\t` {
			col += 4 - col % 4
		} else {
			break
		}
	}
	return col
}

// tvmd_strip_cols removes up to n columns of leading whitespace.
fn tvmd_strip_cols(ln TvMdLine, n int) TvMdLine {
	mut col := 0
	mut i := 0
	for i < ln.text.len && col < n {
		c := ln.text[i]
		if c == ` ` {
			col++
			i++
		} else if c == `\t` {
			w := 4 - col % 4
			if col + w > n {
				rest := col + w - n
				return TvMdLine{' '.repeat(rest) + ln.text[i + 1..], ln.src + i}
			}
			col += w
			i++
		} else {
			break
		}
	}
	return TvMdLine{ln.text[i..], ln.src + i}
}

fn tvmd_trim_left(ln TvMdLine) TvMdLine {
	mut i := 0
	for i < ln.text.len && (ln.text[i] == ` ` || ln.text[i] == `\t`) {
		i++
	}
	return TvMdLine{ln.text[i..], ln.src + i}
}

fn tvmd_blank(s string) bool {
	for c in s {
		if c != ` ` && c != `\t` {
			return false
		}
	}
	return true
}

fn tvmd_is_space(c u8) bool {
	return c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == `\f`
}

fn tvmd_is_punct(c u8) bool {
	return (c >= `!` && c <= `/`) || (c >= `:` && c <= `@`) || (c >= `[` && c <= `\``)
		|| (c >= `{` && c <= `~`)
}

// ── Block starts ────────────────────────────────────────────────────

fn tvmd_thematic_break(s string) bool {
	t := s.trim_left(' ')
	if t.len == 0 || t[0] !in [`*`, `-`, `_`] {
		return false
	}
	c := t[0]
	mut count := 0
	for ch in t {
		if ch == c {
			count++
		} else if ch != ` ` && ch != `\t` {
			return false
		}
	}
	return count >= 3
}

struct TvMdAtx {
	level int
	start int // content offsets in the line
	end   int
}

fn tvmd_atx(s string) ?TvMdAtx {
	mut i := 0
	for i < s.len && s[i] == ` ` && i < 3 {
		i++
	}
	mut level := 0
	for i + level < s.len && s[i + level] == `#` {
		level++
	}
	if level == 0 || level > 6 {
		return none
	}
	mut k := i + level
	if k < s.len && s[k] != ` ` && s[k] != `\t` {
		return none
	}
	for k < s.len && (s[k] == ` ` || s[k] == `\t`) {
		k++
	}
	mut end := s.len
	for end > k && (s[end - 1] == ` ` || s[end - 1] == `\t`) {
		end--
	}
	// A closing sequence of #s, preceded by a space (or making up the whole
	// content), is not part of the heading.
	mut h := end
	for h > k && s[h - 1] == `#` {
		h--
	}
	if h < end && (h == k || s[h - 1] == ` ` || s[h - 1] == `\t`) {
		end = h
		for end > k && (s[end - 1] == ` ` || s[end - 1] == `\t`) {
			end--
		}
	}
	return TvMdAtx{level, k, end}
}

fn tvmd_setext(s string) int {
	t := s.trim_space()
	if t.len == 0 {
		return 0
	}
	c := t[0]
	if c != `=` && c != `-` {
		return 0
	}
	for ch in t {
		if ch != c {
			return 0
		}
	}
	return if c == `=` { 1 } else { 2 }
}

struct TvMdFence {
	ch     u8
	len    int
	indent int
	info   string
}

fn tvmd_fence_open(ln TvMdLine) ?TvMdFence {
	indent := tvmd_indent(ln.text)
	if indent >= 4 {
		return none
	}
	s := tvmd_strip_cols(ln, indent).text
	if s.len < 3 || (s[0] != `\`` && s[0] != `~`) {
		return none
	}
	c := s[0]
	mut n := 0
	for n < s.len && s[n] == c {
		n++
	}
	if n < 3 {
		return none
	}
	info := s[n..].trim_space()
	if c == `\`` && info.contains('`') {
		return none
	}
	return TvMdFence{c, n, indent, tvmd_unescape(info)}
}

fn tvmd_fence_close(s string, fence TvMdFence) bool {
	t := s.trim_left(' ')
	if s.len - t.len >= 4 {
		return false
	}
	mut n := 0
	for n < t.len && t[n] == fence.ch {
		n++
	}
	return n >= fence.len && tvmd_blank(t[n..])
}

struct TvMdMarker {
	ordered bool
	ch      u8 // bullet character, or `.`/`)` after an ordered number
	number  int
	width   int // the column the item's content starts at
	blank   bool
	content TvMdLine
}

fn tvmd_list_marker(ln TvMdLine) ?TvMdMarker {
	indent := tvmd_indent(ln.text)
	if indent >= 4 {
		return none
	}
	s := tvmd_strip_cols(ln, indent)
	t := s.text
	if t.len == 0 {
		return none
	}
	mut mlen := 0
	mut ordered := false
	mut ch := u8(0)
	mut number := 0
	if t[0] in [`-`, `+`, `*`] {
		mlen = 1
		ch = t[0]
	} else {
		mut k := 0
		for k < t.len && k < 9 && t[k].is_digit() {
			k++
		}
		if k == 0 || k >= t.len || (t[k] != `.` && t[k] != `)`) {
			return none
		}
		number = t[..k].int()
		ch = t[k]
		mlen = k + 1
		ordered = true
	}
	tail := t[mlen..]
	if tail.len > 0 && tail[0] != ` ` && tail[0] != `\t` {
		return none
	}
	rest := TvMdLine{tail, s.src + mlen}
	if tvmd_blank(tail) {
		return TvMdMarker{
			ordered: ordered
			ch:      ch
			number:  number
			width:   indent + mlen + 1
			blank:   true
			content: TvMdLine{'', rest.src + tail.len}
		}
	}
	spaces := tvmd_indent(tail)
	if spaces >= 5 {
		return TvMdMarker{
			ordered: ordered
			ch:      ch
			number:  number
			width:   indent + mlen + 1
			content: tvmd_strip_cols(rest, 1)
		}
	}
	return TvMdMarker{
		ordered: ordered
		ch:      ch
		number:  number
		width:   indent + mlen + spaces
		content: tvmd_strip_cols(rest, spaces)
	}
}

const tvmd_block_tags = ['address', 'article', 'aside', 'base', 'basefont', 'blockquote', 'body',
	'caption', 'center', 'col', 'colgroup', 'dd', 'details', 'dialog', 'dir', 'div', 'dl', 'dt',
	'fieldset', 'figcaption', 'figure', 'footer', 'form', 'frame', 'frameset', 'h1', 'h2', 'h3',
	'h4', 'h5', 'h6', 'head', 'header', 'hr', 'html', 'iframe', 'legend', 'li', 'link', 'main',
	'menu', 'menuitem', 'nav', 'noframes', 'ol', 'optgroup', 'option', 'p', 'param', 'search',
	'section', 'summary', 'table', 'tbody', 'td', 'tfoot', 'th', 'thead', 'title', 'tr', 'track',
	'ul']

// tvmd_html_start returns the CommonMark HTML block type (1-7) a line starts,
// or 0.
fn tvmd_html_start(s string) int {
	t := s.trim_left(' ')
	if t.len < 2 || t[0] != `<` {
		return 0
	}
	lower := t.to_lower()
	for name in ['script', 'pre', 'style', 'textarea'] {
		if lower.starts_with('<' + name) {
			k := name.len + 1
			if k == t.len || t[k] == ` ` || t[k] == `>` || t[k] == `\t` {
				return 1
			}
		}
	}
	if t.starts_with('<!--') {
		return 2
	}
	if t.starts_with('<?') {
		return 3
	}
	if t.starts_with('<![CDATA[') {
		return 5
	}
	if t.len > 2 && t[1] == `!` && t[2].is_letter() {
		return 4
	}
	mut k := 1
	if t[k] == `/` {
		k++
	}
	start := k
	for k < t.len && (t[k].is_letter() || t[k].is_digit()) {
		k++
	}
	name := lower[start..k]
	if name.len > 0 && name in tvmd_block_tags {
		if k == t.len || t[k] in [` `, `\t`, `>`] || t[k..].starts_with('/>') {
			return 6
		}
	}
	trimmed := t.trim_right(' \t')
	if name.len > 0 && trimmed.ends_with('>') && !trimmed[1..].contains('<')
		&& name !in ['script', 'style', 'pre', 'textarea'] {
		return 7
	}
	return 0
}

fn tvmd_html_end(s string, kind int) bool {
	lower := s.to_lower()
	return match kind {
		1 {
			lower.contains('</script>') || lower.contains('</pre>') || lower.contains('</style>')
				|| lower.contains('</textarea>')
		}
		2 {
			s.contains('-->')
		}
		3 {
			s.contains('?>')
		}
		4 {
			s.contains('>')
		}
		5 {
			s.contains(']]>')
		}
		else {
			false
		}
	}
}

// tvmd_starts_block reports whether a line opens a block that ends a paragraph,
// which is what keeps it from being a lazy continuation line.
fn tvmd_starts_block(ln TvMdLine, html bool) bool {
	indent := tvmd_indent(ln.text)
	if indent >= 4 {
		return false
	}
	s := tvmd_strip_cols(ln, indent).text
	if s.len == 0 {
		return false
	}
	if tvmd_thematic_break(s) || s.starts_with('>') {
		return true
	}
	if _ := tvmd_atx(s) {
		return true
	}
	if _ := tvmd_fence_open(ln) {
		return true
	}
	if m := tvmd_list_marker(ln) {
		if !m.blank && (!m.ordered || m.number == 1) {
			return true
		}
	}
	if html {
		kind := tvmd_html_start(s)
		if kind > 0 && kind < 7 {
			return true
		}
	}
	return false
}

// ── Blocks ──────────────────────────────────────────────────────────

fn (mut p TvMdParser) blocks(lines []TvMdLine) []TextViewNode {
	mut out := []TextViewNode{}
	mut para := []TvMdLine{}
	mut i := 0
	for i < lines.len {
		ln := lines[i]
		if tvmd_blank(ln.text) {
			p.flush_para(mut out, mut para)
			i++
			continue
		}
		indent := tvmd_indent(ln.text)
		if indent >= 4 {
			if para.len > 0 {
				para << ln
				i++
				continue
			}
			i = p.indented_code(lines, i, mut out)
			continue
		}
		s := tvmd_strip_cols(ln, indent)
		if para.len > 0 {
			if aligns := tvmd_table_delimiter(s.text) {
				header := para.last()
				if header.text.contains('|') && tvmd_split_row(header).len == aligns.len {
					para.pop()
					p.flush_para(mut out, mut para)
					i = p.table(lines, i, header, aligns, mut out)
					continue
				}
			}
			level := tvmd_setext(s.text)
			if level > 0 {
				p.setext(mut out, mut para, level, ln)
				i++
				continue
			}
		}
		if tvmd_thematic_break(s.text) {
			p.flush_para(mut out, mut para)
			out << TextViewNode{
				kind:         .thematic_break
				source_start: ln.src
				source_end:   ln.src + ln.text.len
			}
			i++
			continue
		}
		if atx := tvmd_atx(s.text) {
			p.flush_para(mut out, mut para)
			content := TvMdLine{s.text[atx.start..atx.end], s.src + atx.start}
			out << p.inline_block(.heading, atx.level, [content], ln.src, ln.src + ln.text.len)
			i++
			continue
		}
		if fence := tvmd_fence_open(ln) {
			p.flush_para(mut out, mut para)
			i = p.fenced_code(lines, i, fence, mut out)
			continue
		}
		if s.text.starts_with('>') && p.depth < tvmd_max_depth {
			p.flush_para(mut out, mut para)
			i = p.blockquote(lines, i, mut out)
			continue
		}
		if m := tvmd_list_marker(ln) {
			if !tvmd_thematic_break(s.text) && p.depth < tvmd_max_depth
				&& (para.len == 0 || (!m.blank && (!m.ordered || m.number == 1))) {
				p.flush_para(mut out, mut para)
				i = p.list(lines, i, mut out)
				continue
			}
		}
		if p.options.html {
			kind := tvmd_html_start(s.text)
			if kind > 0 && (para.len == 0 || kind < 7) {
				p.flush_para(mut out, mut para)
				i = p.html_block(lines, i, kind, mut out)
				continue
			}
		}
		para << ln
		i++
	}
	p.flush_para(mut out, mut para)
	return out
}

// inline_block makes a block whose inline content is parsed later, once every
// link reference definition in the document is known.
fn (mut p TvMdParser) inline_block(kind TextViewNodeKind, level int, lines []TvMdLine, source_start int, source_end int) TextViewNode {
	mut joined := ''
	mut segs := []TvMdSeg{cap: lines.len}
	for i, ln in lines {
		mut part := ln.text
		if i == lines.len - 1 {
			part = part.trim_right(' \t')
		}
		segs << TvMdSeg{joined.len, ln.src}
		joined += part
		if i < lines.len - 1 {
			joined += '\n'
		}
	}
	slot := p.inlines.len
	p.inlines << TvMdInline{joined, segs}
	return TextViewNode{
		kind:         kind
		level:        level
		slot:         slot
		source_start: source_start
		source_end:   source_end
	}
}

fn (mut p TvMdParser) flush_para(mut out []TextViewNode, mut para []TvMdLine) {
	if para.len == 0 {
		return
	}
	mut lines := []TvMdLine{cap: para.len}
	for ln in para {
		lines << tvmd_trim_left(ln)
	}
	lines = p.extract_refs(lines)
	if lines.len > 0 {
		last := lines.last()
		out << p.inline_block(.paragraph, 0, lines, lines[0].src, last.src + last.text.len)
	}
	para.clear()
}

fn (mut p TvMdParser) setext(mut out []TextViewNode, mut para []TvMdLine, level int, underline TvMdLine) {
	mut lines := []TvMdLine{cap: para.len}
	for ln in para {
		lines << tvmd_trim_left(ln)
	}
	para.clear()
	lines = p.extract_refs(lines)
	if lines.len == 0 {
		// Only definitions above it: the underline is text.
		para << underline
		return
	}
	out << p.inline_block(.heading, level, lines, lines[0].src, underline.src + underline.text.len)
}

// extract_refs takes the link reference definitions off the start of a
// paragraph, one per line.
fn (mut p TvMdParser) extract_refs(lines []TvMdLine) []TvMdLine {
	mut k := 0
	for k < lines.len {
		name, url, title := tvmd_ref_definition(lines[k].text) or { break }
		key := tvmd_norm_label(name)
		if key.len > 0 && key !in p.refs {
			p.refs[key] = TvMdRef{url, title}
		}
		k++
	}
	return lines[k..]
}

fn tvmd_ref_definition(s string) ?(string, string, string) {
	t := s.trim_space()
	if !t.starts_with('[') {
		return none
	}
	close := tvmd_find_label_end(t, 1) or { return none }
	if close + 1 >= t.len || t[close + 1] != `:` {
		return none
	}
	name := t[1..close]
	if name.trim_space().len == 0 {
		return none
	}
	mut i := close + 2
	for i < t.len && (t[i] == ` ` || t[i] == `\t`) {
		i++
	}
	if i >= t.len {
		return none
	}
	mut url := ''
	if t[i] == `<` {
		end := t.index_after('>', i + 1) or { return none }
		url = t[i + 1..end]
		i = end + 1
	} else {
		start := i
		for i < t.len && t[i] != ` ` && t[i] != `\t` {
			i++
		}
		url = t[start..i]
	}
	rest := t[i..].trim_space()
	mut title := ''
	if rest.len > 0 {
		if rest.len < 2 || rest[0] !in [`"`, `'`, `(`] {
			return none
		}
		closer := if rest[0] == `(` { `)` } else { rest[0] }
		if rest[rest.len - 1] != closer {
			return none
		}
		title = rest[1..rest.len - 1]
	}
	return name, tvmd_unescape(url), tvmd_unescape(title)
}

// tvmd_find_label_end finds the `]` closing a link label that starts at i.
fn tvmd_find_label_end(t string, i int) ?int {
	mut k := i
	for k < t.len {
		c := t[k]
		if c == `\\` && k + 1 < t.len {
			k += 2
			continue
		}
		if c == `[` {
			return none
		}
		if c == `]` {
			return k
		}
		k++
	}
	return none
}

fn tvmd_norm_label(name string) string {
	return name.to_lower().fields().join(' ')
}

// tvmd_unescape resolves backslash escapes and entities in a destination,
// title or info string.
fn tvmd_unescape(s string) string {
	if !s.contains('\\') && !s.contains('&') {
		return s
	}
	mut out := []u8{cap: s.len}
	mut i := 0
	for i < s.len {
		c := s[i]
		if c == `\\` && i + 1 < s.len && tvmd_is_punct(s[i + 1]) {
			out << s[i + 1]
			i += 2
			continue
		}
		if c == `&` {
			decoded, n := tv_decode_entity(s, i)
			if n > 0 {
				out << decoded.bytes()
				i += n
				continue
			}
		}
		out << c
		i++
	}
	return out.bytestr()
}

fn (mut p TvMdParser) indented_code(lines []TvMdLine, start int, mut out []TextViewNode) int {
	mut body := []TvMdLine{}
	mut i := start
	for i < lines.len {
		ln := lines[i]
		if tvmd_blank(ln.text) || tvmd_indent(ln.text) >= 4 {
			body << tvmd_strip_cols(ln, 4)
			i++
			continue
		}
		break
	}
	for body.len > 0 && tvmd_blank(body.last().text) {
		body.pop()
	}
	out << tvmd_code_node(body, '', false)
	return i
}

fn (mut p TvMdParser) fenced_code(lines []TvMdLine, start int, fence TvMdFence, mut out []TextViewNode) int {
	mut body := []TvMdLine{}
	mut i := start + 1
	for i < lines.len {
		ln := lines[i]
		if tvmd_fence_close(ln.text, fence) {
			i++
			break
		}
		body << tvmd_strip_cols(ln, fence.indent)
		i++
	}
	mut node := tvmd_code_node(body, fence.info, true)
	node = TextViewNode{
		...node
		source_start: lines[start].src
		source_end:   if i - 1 < lines.len {
			lines[i - 1].src + lines[i - 1].text.len
		} else {
			node.source_end
		}
	}
	out << node
	return i
}

// tvmd_code_node keeps one text child per line, so each maps onto its own line
// of source whatever container prefix the line had.
fn tvmd_code_node(body []TvMdLine, info string, fenced bool) TextViewNode {
	mut children := []TextViewNode{cap: body.len}
	mut texts := []string{cap: body.len}
	for ln in body {
		children << TextViewNode{
			kind:         .text
			text:         ln.text
			source_start: ln.src
			source_end:   ln.src + ln.text.len
			verbatim:     true
		}
		texts << ln.text
	}
	lang := if info.len > 0 { info.fields()[0] } else { '' }
	return TextViewNode{
		kind:         .code_block
		children:     children
		text:         texts.join('\n')
		fenced:       fenced
		lang:         lang
		info:         info
		source_start: if body.len > 0 { body[0].src } else { 0 }
		source_end:   if body.len > 0 { body.last().src + body.last().text.len } else { 0 }
	}
}

fn (mut p TvMdParser) blockquote(lines []TvMdLine, start int, mut out []TextViewNode) int {
	mut inner := []TvMdLine{}
	mut i := start
	mut last_blank := false
	for i < lines.len {
		ln := lines[i]
		indent := tvmd_indent(ln.text)
		if indent < 4 {
			s := tvmd_strip_cols(ln, indent)
			if s.text.starts_with('>') {
				rest := tvmd_strip_cols(TvMdLine{s.text[1..], s.src + 1}, 1)
				inner << rest
				last_blank = tvmd_blank(rest.text)
				i++
				continue
			}
		}
		// A lazy continuation line carries on a paragraph without the marker.
		if tvmd_blank(ln.text) || last_blank || inner.len == 0
			|| tvmd_starts_block(ln, p.options.html) || tvmd_fence_inside(inner) {
			break
		}
		inner << tvmd_trim_left(ln)
		i++
	}
	p.depth++
	children := p.blocks(inner)
	p.depth--
	last := lines[i - 1]
	out << TextViewNode{
		kind:         .blockquote
		children:     children
		source_start: lines[start].src
		source_end:   last.src + last.text.len
	}
	return i
}

// tvmd_fence_inside reports whether lines leave a fenced code block open, where
// a line is code rather than a lazy paragraph continuation.
fn tvmd_fence_inside(lines []TvMdLine) bool {
	mut open := false
	mut fence := TvMdFence{}
	for ln in lines {
		if open {
			if tvmd_fence_close(ln.text, fence) {
				open = false
			}
			continue
		}
		if f := tvmd_fence_open(ln) {
			fence = f
			open = true
		}
	}
	return open
}

fn (mut p TvMdParser) list(lines []TvMdLine, start int, mut out []TextViewNode) int {
	first := tvmd_list_marker(lines[start]) or { return start + 1 }
	mut items := []TextViewNode{}
	mut i := start
	mut loose := false
	mut gap_before := false
	for i < lines.len {
		ln := lines[i]
		if tvmd_blank(ln.text) {
			break
		}
		if tvmd_thematic_break(tvmd_trim_left(ln).text) {
			break
		}
		m := tvmd_list_marker(ln) or { break }
		if m.ordered != first.ordered || m.ch != first.ch {
			break
		}
		if items.len > 0 && gap_before {
			loose = true
		}
		mut item_lines := [m.content]
		mut j := i + 1
		mut blanks := 0
		for j < lines.len {
			l2 := lines[j]
			if tvmd_blank(l2.text) {
				if m.blank && item_lines.len == 1 {
					// An item can start with at most one blank line.
					break
				}
				item_lines << TvMdLine{'', l2.src}
				blanks++
				j++
				continue
			}
			if tvmd_indent(l2.text) >= m.width {
				item_lines << tvmd_strip_cols(l2, m.width)
				blanks = 0
				j++
				continue
			}
			if blanks == 0 && !(m.blank && item_lines.len == 1)
				&& !tvmd_starts_block(l2, p.options.html) && !tvmd_fence_inside(item_lines) {
				if _ := tvmd_list_marker(l2) {
					break
				}
				item_lines << tvmd_trim_left(l2)
				j++
				continue
			}
			break
		}
		mut trailing := 0
		for item_lines.len > 1 && tvmd_blank(item_lines.last().text) {
			item_lines.pop()
			trailing++
		}
		gap_before = trailing > 0
		if tvmd_interior_blank(item_lines) {
			loose = true
		}
		mut task := TextViewTask.plain
		if item_lines.len > 0 {
			t := item_lines[0].text
			if t.len >= 3 && t[0] == `[` && t[2] == `]` && t[1] in [` `, `x`, `X`]
				&& (t.len == 3 || t[3] == ` ` || t[3] == `\t`) {
				task = if t[1] == ` ` { .unchecked } else { .checked }
				item_lines[0] = tvmd_strip_cols(TvMdLine{t[3..], item_lines[0].src + 3},
					1)
			}
		}
		p.depth++
		children := p.blocks(item_lines)
		p.depth--
		last := lines[j - 1]
		items << TextViewNode{
			kind:         .list_item
			children:     children
			task:         task
			source_start: ln.src
			source_end:   last.src + last.text.len
		}
		i = j
		// Blank lines between items are skipped; the next marker continues the list.
		for i < lines.len && tvmd_blank(lines[i].text) {
			gap_before = true
			i++
		}
		if i < lines.len {
			next := tvmd_list_marker(lines[i]) or { break }
			if next.ordered != first.ordered || next.ch != first.ch {
				break
			}
		}
	}
	// Blank lines the loop skipped after the last item are not the list's.
	for i > start + 1 && tvmd_blank(lines[i - 1].text) {
		i--
	}
	last_item := if items.len > 0 { items.last().source_end } else { lines[start].src }
	out << TextViewNode{
		kind:         .list
		children:     items
		ordered:      first.ordered
		start:        if first.ordered { first.number } else { 1 }
		tight:        !loose
		source_start: lines[start].src
		source_end:   last_item
	}
	return i
}

// tvmd_interior_blank reports a blank line between two of an item's own
// blocks, which makes its list loose. A blank inside a nested list or a code
// block does not count.
fn tvmd_interior_blank(lines []TvMdLine) bool {
	mut fence := false
	mut f := TvMdFence{}
	for k, ln in lines {
		if fence {
			if tvmd_fence_close(ln.text, f) {
				fence = false
			}
			continue
		}
		if open := tvmd_fence_open(ln) {
			f = open
			fence = true
			continue
		}
		if k == 0 || k == lines.len - 1 || !tvmd_blank(ln.text) {
			continue
		}
		mut n := k + 1
		for n < lines.len && tvmd_blank(lines[n].text) {
			n++
		}
		if n < lines.len && tvmd_indent(lines[n].text) == 0 {
			if _ := tvmd_list_marker(lines[n]) {
				continue
			}
			return true
		}
	}
	return false
}

fn (mut p TvMdParser) html_block(lines []TvMdLine, start int, kind int, mut out []TextViewNode) int {
	mut raw := []TvMdLine{}
	mut i := start
	for i < lines.len {
		ln := lines[i]
		if kind >= 6 && tvmd_blank(ln.text) {
			break
		}
		raw << ln
		i++
		if kind <= 5 && tvmd_html_end(ln.text, kind) {
			break
		}
	}
	mut texts := []string{cap: raw.len}
	for ln in raw {
		texts << ln.text
	}
	source := texts.join('\n')
	base := raw[0].src
	blocks := tvhtml_blocks(source, base)
	out << TextViewNode{
		kind:         .html_block
		text:         source
		children:     blocks
		source_start: base
		source_end:   raw.last().src + raw.last().text.len
	}
	return i
}

// ── Tables ──────────────────────────────────────────────────────────

struct TvMdCell {
	text   string
	offset int
}

// tvmd_split_row splits a table row at its unescaped pipes; a leading and a
// trailing pipe are optional.
fn tvmd_split_row(ln TvMdLine) []TvMdCell {
	t := ln.text
	mut start := 0
	mut end := t.len
	for start < end && (t[start] == ` ` || t[start] == `\t`) {
		start++
	}
	for end > start && (t[end - 1] == ` ` || t[end - 1] == `\t`) {
		end--
	}
	if start < end && t[start] == `|` {
		start++
	}
	if end > start && t[end - 1] == `|` && (end - 2 < start || t[end - 2] != `\\`) {
		end--
	}
	mut cells := []TvMdCell{}
	mut cell_start := start
	mut k := start
	for k <= end {
		if k == end || (t[k] == `|` && (k == 0 || t[k - 1] != `\\`)) {
			mut a := cell_start
			mut b := k
			for a < b && (t[a] == ` ` || t[a] == `\t`) {
				a++
			}
			for b > a && (t[b - 1] == ` ` || t[b - 1] == `\t`) {
				b--
			}
			cells << TvMdCell{t[a..b], a}
			cell_start = k + 1
		}
		k++
	}
	return cells
}

fn tvmd_table_delimiter(s string) ?[]TextViewAlign {
	if !s.contains('|') && !s.contains('-') {
		return none
	}
	cells := tvmd_split_row(TvMdLine{s, 0})
	if cells.len == 0 {
		return none
	}
	if !s.contains('|') && cells.len < 2 {
		return none
	}
	mut aligns := []TextViewAlign{cap: cells.len}
	for cell in cells {
		c := cell.text
		if c.len == 0 {
			return none
		}
		left := c[0] == `:`
		right := c[c.len - 1] == `:`
		inner := c.trim(':')
		if inner.len == 0 {
			return none
		}
		for ch in inner {
			if ch != `-` {
				return none
			}
		}
		aligns << if left && right {
			TextViewAlign.center
		} else if right {
			TextViewAlign.right
		} else if left {
			TextViewAlign.left
		} else {
			TextViewAlign.auto
		}
	}
	return aligns
}

fn (mut p TvMdParser) table(lines []TvMdLine, delimiter int, header TvMdLine, aligns []TextViewAlign, mut out []TextViewNode) int {
	mut rows := [p.table_row(header, aligns, true)]
	mut i := delimiter + 1
	for i < lines.len {
		ln := lines[i]
		if tvmd_blank(ln.text) || tvmd_starts_block(ln, p.options.html) {
			break
		}
		rows << p.table_row(ln, aligns, false)
		i++
	}
	last := lines[i - 1]
	out << TextViewNode{
		kind:         .table
		children:     rows
		source_start: header.src
		source_end:   last.src + last.text.len
	}
	return i
}

fn (mut p TvMdParser) table_row(ln TvMdLine, aligns []TextViewAlign, header bool) TextViewNode {
	cells := tvmd_split_row(ln)
	mut children := []TextViewNode{cap: aligns.len}
	for k, align in aligns {
		cell := if k < cells.len { cells[k] } else { TvMdCell{'', ln.text.len} }
		src := ln.src + cell.offset
		slot := p.inlines.len
		p.inlines << TvMdInline{cell.text, [TvMdSeg{0, src}]}
		children << TextViewNode{
			kind:         .table_cell
			align:        align
			header:       header
			slot:         slot
			source_start: src
			source_end:   src + cell.text.len
		}
	}
	return TextViewNode{
		kind:         .table_row
		header:       header
		children:     children
		source_start: ln.src
		source_end:   ln.src + ln.text.len
	}
}

// ── Inline resolution ───────────────────────────────────────────────

// resolve_inlines parses the inline content every block left in a slot.
fn (mut p TvMdParser) resolve_inlines(nodes []TextViewNode) []TextViewNode {
	mut out := []TextViewNode{cap: nodes.len}
	for n in nodes {
		if n.slot >= 0 {
			source := p.inlines[n.slot]
			out << TextViewNode{
				...n
				slot:     -1
				children: tvmd_parse_inline(source, p.refs, p.options.html)
			}
		} else if n.children.len > 0 && n.kind != .html_block && n.kind != .code_block {
			out << TextViewNode{
				...n
				children: p.resolve_inlines(n.children)
			}
		} else {
			out << n
		}
	}
	return out
}

// ── Front matter ────────────────────────────────────────────────────

// tvmd_frontmatter reads a leading `---` block. Top-level `key: value` pairs
// with plain values and `|-`/`>-` block scalars become entries; anything else
// YAML can say (quotes, comments, collections, anchors) is kept as a YAML code
// block rather than shown wrongly.
fn tvmd_frontmatter(lines []TvMdLine) (int, TextViewNode) {
	if lines.len < 2 || lines[0].text.trim_right(' \t') != '---' {
		return 0, TextViewNode{}
	}
	mut close := -1
	for k in 1 .. lines.len {
		t := lines[k].text.trim_right(' \t')
		if t == '---' || t == '...' {
			close = k
			break
		}
	}
	if close < 0 {
		return 0, TextViewNode{}
	}
	body := lines[1..close]
	end := lines[close].src + lines[close].text.len
	if entries := tvmd_yaml_entries(body) {
		return close + 1, TextViewNode{
			kind:         .frontmatter
			entries:      entries
			lang:         'yaml'
			text:         body.map(it.text).join('\n')
			source_start: 0
			source_end:   end
		}
	}
	code := tvmd_code_node(body, 'yaml', true)
	return close + 1, TextViewNode{
		...code
		source_start: 0
		source_end:   end
	}
}

fn tvmd_yaml_entries(body []TvMdLine) ?[]TextViewEntry {
	mut entries := []TextViewEntry{}
	mut k := 0
	for k < body.len {
		line := body[k].text
		if tvmd_blank(line) {
			k++
			continue
		}
		if line[0] == ` ` || line[0] == `\t` || line[0] == `#` {
			return none
		}
		colon := line.index(':') or { return none }
		key := line[..colon]
		if key.len == 0 {
			return none
		}
		for c in key {
			if !(c.is_letter() || c.is_digit() || c == `_` || c == `-` || c == ` `) {
				return none
			}
		}
		if colon + 1 < line.len && line[colon + 1] != ` ` && line[colon + 1] != `\t` {
			return none
		}
		raw := line[colon + 1..].trim_space()
		k++
		if raw == '|-' || raw == '>-' {
			mut block := []string{}
			mut indent := -1
			for k < body.len {
				l2 := body[k].text
				if tvmd_blank(l2) {
					block << ''
					k++
					continue
				}
				ind := tvmd_indent(l2)
				if ind == 0 {
					break
				}
				if indent < 0 {
					indent = ind
				}
				if ind < indent {
					return none
				}
				if raw == '>-' && ind > indent {
					return none
				}
				block << tvmd_strip_cols(TvMdLine{l2, 0}, indent).text
				k++
			}
			for block.len > 0 && block.last() == '' {
				block.pop()
			}
			value := if raw == '|-' { block.join('\n') } else { tvmd_fold(block) }
			entries << TextViewEntry{
				key:   key.trim_space()
				value: value
			}
			continue
		}
		if raw.len > 0 && (raw[0] in [`"`, `'`, `[`, `{`, `&`, `*`, `!`, `|`, `>`, `%`, `@`, `\``]
			|| raw.contains(' #') || raw.starts_with('- ')) {
			return none
		}
		if raw.len == 0 && k < body.len && !tvmd_blank(body[k].text)
			&& (body[k].text[0] == ` ` || body[k].text[0] == `-`) {
			return none
		}
		entries << TextViewEntry{
			key:   key.trim_space()
			value: raw
		}
	}
	if entries.len == 0 {
		return none
	}
	return entries
}

// tvmd_fold joins a folded scalar's lines with spaces; a blank line is a break.
fn tvmd_fold(lines []string) string {
	mut out := ''
	mut previous_blank := true
	for ln in lines {
		if ln.len == 0 {
			out += '\n'
			previous_blank = true
			continue
		}
		if !previous_blank {
			out += ' '
		}
		out += ln
		previous_blank = false
	}
	return out
}
