module ui2

import strings

// A small, forgiving HTML parser for TextView. It reads the subset rich text
// uses (p, h1-h6, b/strong, i/em, s/del, code, pre, a, ul/ol/li, blockquote,
// br, hr, img, table/thead/tbody/tr/th/td, span/div and the like) into the same
// document tree Markdown parses into. Malformed markup is tolerated the way a
// browser tolerates it: unclosed paragraphs, list items and cells close when
// the next one starts, stray end tags are ignored, unknown elements keep their
// content, and script and style content is dropped. Entities are decoded and
// whitespace collapses outside `pre`.

// text_view_html parses HTML into a document.
pub fn text_view_html(source string) TextViewDocument {
	root := TextViewNode{
		kind:         .document
		children:     tvhtml_blocks(source, 0)
		source_start: 0
		source_end:   source.len
	}
	return tv_finish_document(root, source, true)
}

struct TvHtmlTag {
	name         string
	attrs        map[string]string
	closing      bool
	self_closing bool
	end          int
}

// TvHtmlEl is an element, or a text node when name is empty.
struct TvHtmlEl {
	name      string
	attrs     map[string]string
	text      string
	segs      []TextViewSpan
	src_start int
mut:
	src_end  int
	children []TvHtmlEl
}

const tvhtml_void = ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta',
	'source', 'track', 'wbr']

const tvhtml_blockish = ['p', 'div', 'section', 'article', 'header', 'footer', 'main', 'nav', 'aside',
	'figure', 'figcaption', 'blockquote', 'ul', 'ol', 'li', 'pre', 'table', 'thead', 'tbody', 'tfoot',
	'tr', 'td', 'th', 'caption', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr', 'dl', 'dt', 'dd', 'details',
	'summary', 'center', 'address', 'body', 'html', 'form', 'fieldset', 'legend', 'hgroup', 'search',
	'menu']

// Opening one of these ends an open paragraph, as in a browser.
const tvhtml_closes_p = ['p', 'div', 'ul', 'ol', 'table', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
	'blockquote', 'pre', 'hr', 'dl', 'section', 'article', 'header', 'footer', 'nav', 'aside',
	'figure', 'details', 'address', 'fieldset', 'form', 'main', 'menu']

// tvhtml_read_tag reads the start or end tag at t[start]: its lowercased name,
// attributes (entities decoded) and where it ends. None when there is no
// well-formed tag there.
fn tvhtml_read_tag(t string, start int) ?TvHtmlTag {
	if start >= t.len || t[start] != `<` {
		return none
	}
	mut i := start + 1
	closing := i < t.len && t[i] == `/`
	if closing {
		i++
	}
	if i >= t.len || !t[i].is_letter() {
		return none
	}
	name_start := i
	for i < t.len && (t[i].is_letter() || t[i].is_digit() || t[i] == `-` || t[i] == `:`) {
		i++
	}
	name := t[name_start..i].to_lower()
	mut attrs := map[string]string{}
	mut self_closing := false
	for {
		for i < t.len && tvmd_is_space(t[i]) {
			i++
		}
		if i >= t.len {
			return none
		}
		c := t[i]
		if c == `>` {
			i++
			break
		}
		if c == `/` && i + 1 < t.len && t[i + 1] == `>` {
			self_closing = true
			i += 2
			break
		}
		if closing {
			end := t.index_after('>', i) or { return none }
			i = end + 1
			break
		}
		attr_start := i
		for i < t.len && !tvmd_is_space(t[i]) && t[i] !in [`=`, `>`, `/`, `"`, `'`, `<`] {
			i++
		}
		if i == attr_start {
			return none
		}
		attr := t[attr_start..i].to_lower()
		for i < t.len && tvmd_is_space(t[i]) {
			i++
		}
		mut value := ''
		if i < t.len && t[i] == `=` {
			i++
			for i < t.len && tvmd_is_space(t[i]) {
				i++
			}
			if i >= t.len {
				return none
			}
			q := t[i]
			if q == `"` || q == `'` {
				end := t.index_after([q].bytestr(), i + 1) or { return none }
				value = t[i + 1..end]
				i = end + 1
			} else {
				value_start := i
				for i < t.len && !tvmd_is_space(t[i]) && t[i] != `>` {
					i++
				}
				value = t[value_start..i]
			}
		}
		attrs[attr] = tvmd_unescape(value)
	}
	return TvHtmlTag{
		name:         name
		attrs:        attrs
		closing:      closing
		self_closing: self_closing || name in tvhtml_void
		end:          i
	}
}

// tvhtml_tag_end is where the inline HTML tag at t[start] ends, for Markdown.
fn tvhtml_tag_end(t string, start int) ?int {
	found := tvhtml_read_tag(t, start)?
	return found.end
}

fn tvhtml_dom(src string, base int) TvHtmlEl {
	mut stack := [TvHtmlEl{
		name: '#root'
	}]
	lower := src.to_lower()
	mut i := 0
	mut text_start := 0
	for i < src.len {
		if src[i] != `<` {
			i++
			continue
		}
		if src[i..].starts_with('<!--') {
			tvhtml_add_text(mut stack, src, text_start, i, base)
			end := src.index_after('-->', i + 4) or { src.len - 3 }
			i = end + 3
			text_start = i
			continue
		}
		if i + 1 < src.len && (src[i + 1] == `!` || src[i + 1] == `?`) {
			tvhtml_add_text(mut stack, src, text_start, i, base)
			end := src.index_after('>', i) or { src.len - 1 }
			i = end + 1
			text_start = i
			continue
		}
		found := tvhtml_read_tag(src, i) or {
			i++
			continue
		}
		tvhtml_add_text(mut stack, src, text_start, i, base)
		if found.closing {
			tvhtml_close(mut stack, found.name, base + found.end)
		} else if found.name in ['script', 'style', 'title', 'template', 'noscript', 'textarea']
			&& !found.self_closing {
			// Raw text: everything up to the end tag is dropped.
			close := lower.index_after('</' + found.name, found.end) or { src.len }
			end := src.index_after('>', close) or { src.len - 1 }
			i = end + 1
			text_start = i
			continue
		} else {
			tvhtml_open(mut stack, found, base + i, base + found.end)
		}
		i = found.end
		text_start = i
	}
	tvhtml_add_text(mut stack, src, text_start, src.len, base)
	for stack.len > 1 {
		tvhtml_pop(mut stack, base + src.len)
	}
	return stack[0]
}

fn tvhtml_pop(mut stack []TvHtmlEl, end int) {
	mut el := stack.pop()
	if el.src_end == 0 {
		el.src_end = end
	}
	stack[stack.len - 1].children << el
}

// tvhtml_close_open closes the nearest open element named one of names, unless
// a boundary element is open in between.
fn tvhtml_close_open(mut stack []TvHtmlEl, names []string, boundaries []string, end int) {
	for k := stack.len - 1; k >= 1; k-- {
		name := stack[k].name
		if name in names {
			for stack.len > k {
				tvhtml_pop(mut stack, end)
			}
			return
		}
		if name in boundaries {
			return
		}
	}
}

fn tvhtml_open(mut stack []TvHtmlEl, tag TvHtmlTag, start int, end int) {
	name := tag.name
	if name in tvhtml_closes_p {
		tvhtml_close_open(mut stack, ['p'], ['div', 'blockquote', 'li', 'td', 'th', 'section',
			'article', 'body', 'table'], start)
	}
	match name {
		'li' {
			tvhtml_close_open(mut stack, ['li'], ['ul', 'ol', 'table'], start)
		}
		'dt', 'dd' {
			tvhtml_close_open(mut stack, ['dt', 'dd'], ['dl', 'table'], start)
		}
		'tr' {
			tvhtml_close_open(mut stack, ['tr'], ['table', 'thead', 'tbody', 'tfoot'], start)
		}
		'td', 'th' {
			tvhtml_close_open(mut stack, ['td', 'th'], ['tr', 'table'], start)
		}
		'thead', 'tbody', 'tfoot' {
			tvhtml_close_open(mut stack, ['thead', 'tbody', 'tfoot'], ['table'], start)
		}
		else {}
	}
	el := TvHtmlEl{
		name:      name
		attrs:     tag.attrs
		src_start: start
		src_end:   if tag.self_closing { end } else { 0 }
	}
	if tag.self_closing {
		stack[stack.len - 1].children << el
	} else if stack.len < tvmd_max_depth {
		stack << el
	}
	// Past the nesting limit an element's tags are dropped and its content
	// joins its parent's.
}

fn tvhtml_close(mut stack []TvHtmlEl, name string, end int) {
	for k := stack.len - 1; k >= 1; k-- {
		if stack[k].name == name {
			for stack.len > k + 1 {
				tvhtml_pop(mut stack, end)
			}
			mut el := stack.pop()
			el.src_end = end
			stack[stack.len - 1].children << el
			return
		}
	}
}

fn tvhtml_in_pre(stack []TvHtmlEl) bool {
	for el in stack {
		if el.name == 'pre' {
			return true
		}
	}
	return false
}

fn tvhtml_add_text(mut stack []TvHtmlEl, src string, a int, b int, base int) {
	if a >= b {
		return
	}
	decoded, segs := tv_decode_text(src[a..b], base + a)
	content, mapping := if tvhtml_in_pre(stack) {
		decoded, segs
	} else {
		tvhtml_collapse(decoded, segs)
	}
	if content.len == 0 {
		return
	}
	stack[stack.len - 1].children << TvHtmlEl{
		text:      content
		segs:      mapping
		src_start: base + a
		src_end:   base + b
	}
}

// tvhtml_collapse turns every run of whitespace into one space, keeping the
// source map: a collapsed run maps onto all the whitespace it stands for.
fn tvhtml_collapse(text string, segs []TextViewSpan) (string, []TextViewSpan) {
	mut sb := strings.new_builder(text.len)
	mut out := []TextViewSpan{}
	mut prev_space := false
	for seg in segs {
		piece := text[seg.rendered_start..seg.rendered_end]
		if !seg.verbatim {
			at := sb.len
			sb.write_string(piece)
			out << TextViewSpan{
				rendered_start: at
				rendered_end:   sb.len
				source_start:   seg.source_start
				source_end:     seg.source_end
			}
			prev_space = false
			continue
		}
		mut k := 0
		for k < piece.len {
			from := k
			if tvmd_is_space(piece[k]) {
				for k < piece.len && tvmd_is_space(piece[k]) {
					k++
				}
				if prev_space {
					continue
				}
				at := sb.len
				sb.write_u8(` `)
				tvhtml_push_seg(mut out, TextViewSpan{
					rendered_start: at
					rendered_end:   at + 1
					source_start:   seg.source_start + from
					source_end:     seg.source_start + k
					verbatim:       k - from == 1 && piece[from] == ` `
				})
				prev_space = true
			} else {
				for k < piece.len && !tvmd_is_space(piece[k]) {
					k++
				}
				at := sb.len
				sb.write_string(piece[from..k])
				tvhtml_push_seg(mut out, TextViewSpan{
					rendered_start: at
					rendered_end:   sb.len
					source_start:   seg.source_start + from
					source_end:     seg.source_start + k
					verbatim:       true
				})
				prev_space = false
			}
		}
	}
	return sb.str(), out
}

fn tvhtml_push_seg(mut out []TextViewSpan, seg TextViewSpan) {
	if out.len > 0 {
		last := out.last()
		if last.verbatim && seg.verbatim && last.rendered_end == seg.rendered_start
			&& last.source_end == seg.source_start {
			out[out.len - 1] = TextViewSpan{
				...last
				rendered_end: seg.rendered_end
				source_end:   seg.source_end
			}
			return
		}
	}
	out << seg
}

// ── Conversion to the document tree ────────────────────────────────

fn tvhtml_blocks(source string, base int) []TextViewNode {
	dom := tvhtml_dom(source, base)
	return tvhtml_convert_blocks(dom.children)
}

fn tvhtml_is_block(el TvHtmlEl) bool {
	return el.name.len > 0 && el.name in tvhtml_blockish
}

fn tvhtml_convert_blocks(children []TvHtmlEl) []TextViewNode {
	mut out := []TextViewNode{}
	mut pending := []TvHtmlEl{}
	for c in children {
		if tvhtml_is_block(c) {
			tvhtml_flush_inline(mut out, mut pending)
			out << tvhtml_convert_block(c)
		} else {
			pending << c
		}
	}
	tvhtml_flush_inline(mut out, mut pending)
	return out
}

fn tvhtml_flush_inline(mut out []TextViewNode, mut pending []TvHtmlEl) {
	if pending.len == 0 {
		return
	}
	inlines := tvhtml_trim(tvhtml_convert_inlines(pending))
	if inlines.len > 0 {
		out << TextViewNode{
			kind:         .paragraph
			children:     inlines
			source_start: pending[0].src_start
			source_end:   pending.last().src_end
		}
	}
	pending.clear()
}

fn tvhtml_paragraph(el TvHtmlEl, strong bool) []TextViewNode {
	for c in el.children {
		if tvhtml_is_block(c) {
			return tvhtml_convert_blocks(el.children)
		}
	}
	mut inlines := tvhtml_trim(tvhtml_convert_inlines(el.children))
	if inlines.len == 0 {
		return []
	}
	if strong {
		inlines = [TextViewNode{
			kind:         .strong
			children:     inlines
			source_start: el.src_start
			source_end:   el.src_end
		}]
	}
	return [
		TextViewNode{
			kind:         .paragraph
			children:     inlines
			source_start: el.src_start
			source_end:   el.src_end
		},
	]
}

fn tvhtml_convert_block(el TvHtmlEl) []TextViewNode {
	match el.name {
		'p', 'dd', 'figcaption', 'caption', 'legend', 'address' {
			return tvhtml_paragraph(el, false)
		}
		'dt', 'summary' {
			return tvhtml_paragraph(el, true)
		}
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6' {
			return [
				TextViewNode{
					kind:         .heading
					level:        int(el.name[1] - `0`)
					children:     tvhtml_trim(tvhtml_convert_inlines(el.children))
					source_start: el.src_start
					source_end:   el.src_end
				},
			]
		}
		'blockquote' {
			return [
				TextViewNode{
					kind:         .blockquote
					children:     tvhtml_convert_blocks(el.children)
					source_start: el.src_start
					source_end:   el.src_end
				},
			]
		}
		'ul', 'ol' {
			return [tvhtml_list(el)]
		}
		'pre' {
			return [tvhtml_pre(el)]
		}
		'hr' {
			return [
				TextViewNode{
					kind:         .thematic_break
					source_start: el.src_start
					source_end:   el.src_end
				},
			]
		}
		'table' {
			return tvhtml_table(el)
		}
		else {
			return tvhtml_convert_blocks(el.children)
		}
	}
}

fn tvhtml_list(el TvHtmlEl) TextViewNode {
	mut items := []TextViewNode{}
	mut tight := true
	for c in el.children {
		if c.name.len == 0 && c.text.trim_space().len == 0 {
			continue
		}
		if c.name != 'li' {
			items << TextViewNode{
				kind:         .list_item
				children:     tvhtml_convert_blocks([c])
				source_start: c.src_start
				source_end:   c.src_end
			}
			continue
		}
		mut kids := c.children.clone()
		mut task := TextViewTask.plain
		mut box_index := -1
		for k, kid in kids {
			if kid.name.len == 0 && kid.text.trim_space().len == 0 {
				continue
			}
			if kid.name == 'input' && kid.attrs['type'] == 'checkbox' {
				task = if 'checked' in kid.attrs { .checked } else { .unchecked }
				box_index = k
			}
			break
		}
		if box_index >= 0 {
			kids.delete(box_index)
		}
		mut paragraphs := 0
		for kid in kids {
			if kid.name == 'p' {
				paragraphs++
			}
		}
		if paragraphs > 1 {
			tight = false
		}
		items << TextViewNode{
			kind:         .list_item
			task:         task
			children:     tvhtml_convert_blocks(kids)
			source_start: c.src_start
			source_end:   c.src_end
		}
	}
	return TextViewNode{
		kind:         .list
		children:     items
		ordered:      el.name == 'ol'
		start:        if el.name == 'ol' && 'start' in el.attrs {
			el.attrs['start'].int()
		} else {
			1
		}
		tight:        tight
		source_start: el.src_start
		source_end:   el.src_end
	}
}

// tvhtml_text_content is the text of an element's descendants with its source
// map; `br` reads as a line break.
fn tvhtml_text_content(el TvHtmlEl, mut sb strings.Builder, mut segs []TextViewSpan) {
	for c in el.children {
		if c.name.len == 0 {
			at := sb.len
			sb.write_string(c.text)
			for seg in c.segs {
				segs << TextViewSpan{
					...seg
					rendered_start: at + seg.rendered_start
					rendered_end:   at + seg.rendered_end
				}
			}
		} else if c.name == 'br' {
			sb.write_u8(`\n`)
		} else {
			tvhtml_text_content(c, mut sb, mut segs)
		}
	}
}

fn tvhtml_pre(el TvHtmlEl) TextViewNode {
	mut lang := ''
	for c in el.children {
		if c.name == 'code' {
			for class in c.attrs['class'].fields() {
				if class.starts_with('language-') {
					lang = class['language-'.len..]
				} else if class.starts_with('lang-') {
					lang = class['lang-'.len..]
				}
			}
		}
	}
	mut sb := strings.new_builder(64)
	mut segs := []TextViewSpan{}
	tvhtml_text_content(el, mut sb, mut segs)
	all := TextViewNode{
		kind:     .text
		text:     sb.str()
		segments: segs
	}
	mut a := 0
	mut b := all.text.len
	if all.text.starts_with('\n') {
		a = 1
	}
	if b > a && all.text[b - 1] == `\n` {
		b--
	}
	mut lines := []TextViewNode{}
	mut texts := []string{}
	mut k := a
	for k <= b {
		end := if k < b { all.text.index_after('\n', k) or { b } } else { b }
		stop := if end > b { b } else { end }
		line := tv_text_slice(all, k, stop)
		lines << line
		texts << line.text
		k = stop + 1
	}
	return TextViewNode{
		kind:         .code_block
		children:     lines
		text:         texts.join('\n')
		fenced:       true
		lang:         lang
		info:         lang
		source_start: el.src_start
		source_end:   el.src_end
	}
}

fn tvhtml_table(el TvHtmlEl) []TextViewNode {
	mut rows := []TvHtmlEl{}
	mut head_rows := 0
	for c in el.children {
		if c.name == 'tr' {
			rows << c
		} else if c.name in ['thead', 'tbody', 'tfoot'] {
			for r in c.children {
				if r.name == 'tr' {
					rows << r
					if c.name == 'thead' {
						head_rows++
					}
				}
			}
		}
	}
	if rows.len == 0 {
		return []
	}
	mut columns := 0
	for r in rows {
		mut n := 0
		for c in r.children {
			if c.name in ['td', 'th'] {
				n++
			}
		}
		columns = tv_max_int(columns, n)
	}
	if columns == 0 {
		return []
	}
	mut out := []TextViewNode{cap: rows.len}
	for index, r in rows {
		mut cells := []TvHtmlEl{}
		for c in r.children {
			if c.name in ['td', 'th'] {
				cells << c
			}
		}
		header := index < head_rows || (head_rows == 0 && index == 0 && cells.all(it.name == 'th'))
		mut children := []TextViewNode{cap: columns}
		for k in 0 .. columns {
			if k < cells.len {
				cell := cells[k]
				children << TextViewNode{
					kind:         .table_cell
					header:       header
					align:        tvhtml_align(cell.attrs)
					children:     tvhtml_trim(tvhtml_convert_inlines(cell.children))
					source_start: cell.src_start
					source_end:   cell.src_end
				}
			} else {
				children << TextViewNode{
					kind:   .table_cell
					header: header
				}
			}
		}
		out << TextViewNode{
			kind:         .table_row
			header:       header
			children:     children
			source_start: r.src_start
			source_end:   r.src_end
		}
	}
	return [
		TextViewNode{
			kind:         .table
			children:     out
			source_start: el.src_start
			source_end:   el.src_end
		},
	]
}

fn tvhtml_align(attrs map[string]string) TextViewAlign {
	mut value := attrs['align'].to_lower()
	style := attrs['style'].to_lower()
	if value.len == 0 && style.contains('text-align') {
		rest := style.all_after('text-align')
		value = rest.trim_left(': ').all_before(';').trim_space()
	}
	return match value {
		'left' { .left }
		'center' { .center }
		'right' { .right }
		else { .auto }
	}
}

fn tvhtml_inline_kind(name string) bool {
	return name in ['b', 'strong', 'i', 'em', 'cite', 'var', 'dfn', 's', 'del', 'strike', 'code',
		'kbd', 'samp', 'tt', 'a']
}

fn tvhtml_wrap_inline(name string, attrs map[string]string, inner []TextViewNode, end int) TextViewNode {
	start := if inner.len > 0 { inner[0].source_start } else { end }
	match name {
		'b', 'strong' {
			return TextViewNode{
				kind:         .strong
				children:     inner
				source_start: start
				source_end:   end
			}
		}
		'i', 'em', 'cite', 'var', 'dfn' {
			return TextViewNode{
				kind:         .emphasis
				children:     inner
				source_start: start
				source_end:   end
			}
		}
		's', 'del', 'strike' {
			return TextViewNode{
				kind:         .strikethrough
				children:     inner
				source_start: start
				source_end:   end
			}
		}
		'code', 'kbd', 'samp', 'tt' {
			if inner.len == 1 && inner[0].kind == .text {
				return TextViewNode{
					...inner[0]
					kind: .code_span
				}
			}
			return TextViewNode{
				kind:         .code_span
				text:         tv_plain_text(inner)
				source_start: start
				source_end:   end
			}
		}
		else {
			return TextViewNode{
				kind:         .link
				url:          attrs['href']
				title:        attrs['title']
				children:     inner
				source_start: start
				source_end:   end
			}
		}
	}
}

fn tvhtml_image(attrs map[string]string, start int, end int) TextViewNode {
	return TextViewNode{
		kind:         .image
		url:          attrs['src']
		text:         attrs['alt']
		title:        attrs['title']
		width:        attrs['width'].f64()
		height:       attrs['height'].f64()
		source_start: start
		source_end:   end
	}
}

fn tvhtml_convert_inlines(els []TvHtmlEl) []TextViewNode {
	mut out := []TextViewNode{}
	for el in els {
		if el.name.len == 0 {
			out << TextViewNode{
				kind:         .text
				text:         el.text
				segments:     el.segs
				source_start: el.src_start
				source_end:   el.src_end
			}
			continue
		}
		match el.name {
			'br' {
				out << TextViewNode{
					kind:         .hard_break
					source_start: el.src_start
					source_end:   el.src_end
				}
			}
			'img' {
				out << tvhtml_image(el.attrs, el.src_start, el.src_end)
			}
			'input', 'head', 'meta', 'link', 'script', 'style' {}
			else {
				inner := tvhtml_convert_inlines(el.children)
				if tvhtml_inline_kind(el.name) {
					out << tvhtml_wrap_inline(el.name, el.attrs, inner, el.src_end)
				} else {
					out << inner
				}
			}
		}
	}
	return out
}

// tvhtml_trim drops the whitespace HTML does not show inside a block: at its
// start and end, a second space where two texts meet, and spaces after a
// line break.
fn tvhtml_trim(nodes []TextViewNode) []TextViewNode {
	collapsed, _ := tvhtml_drop_spaces(nodes, true)
	return tvhtml_trim_end(collapsed)
}

// tvhtml_drop_spaces is given whether the text before ended with a space and
// reports whether its own does.
fn tvhtml_drop_spaces(nodes []TextViewNode, space_before bool) ([]TextViewNode, bool) {
	mut prev_space := space_before
	mut out := []TextViewNode{cap: nodes.len}
	for n in nodes {
		match n.kind {
			.text {
				mut t := n
				if prev_space && t.text.starts_with(' ') {
					t = tv_text_slice(t, 1, t.text.len)
				}
				if t.text.len == 0 {
					continue
				}
				prev_space = t.text.ends_with(' ')
				out << t
			}
			.hard_break {
				// Spaces before a line break are dropped too.
				if out.len > 0 && out.last().kind == .text && out.last().text.ends_with(' ') {
					last := out.last()
					trimmed := tv_text_slice(last, 0, last.text.len - 1)
					if trimmed.text.len == 0 {
						out.pop()
					} else {
						out[out.len - 1] = trimmed
					}
				}
				prev_space = true
				out << n
			}
			.code_span, .image {
				prev_space = false
				out << n
			}
			else {
				children, ends_space := tvhtml_drop_spaces(n.children, prev_space)
				prev_space = ends_space
				if children.len == 0 && n.kind != .link {
					continue
				}
				out << TextViewNode{
					...n
					children: children
				}
			}
		}
	}
	return out, prev_space
}

fn tvhtml_trim_end(nodes []TextViewNode) []TextViewNode {
	mut out := nodes.clone()
	for out.len > 0 {
		last := out.last()
		match last.kind {
			.text {
				trimmed := last.text.trim_right(' ')
				if trimmed.len == 0 {
					out.pop()
					continue
				}
				out[out.len - 1] = tv_text_slice(last, 0, trimmed.len)
			}
			.hard_break, .soft_break {
				out.pop()
				continue
			}
			.code_span, .image {}
			else {
				children := tvhtml_trim_end(last.children)
				if children.len == 0 {
					out.pop()
					continue
				}
				out[out.len - 1] = TextViewNode{
					...last
					children: children
				}
			}
		}
		break
	}
	return out
}
