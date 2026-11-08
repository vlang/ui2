module ui2

// Markdown inline parsing for TextView: code spans, emphasis and strong
// emphasis by CommonMark's delimiter-run rules, GFM strikethrough, inline,
// reference and image links, autolinks (`<...>` and GFM's bare `https://` and
// `www.`), backslash escapes, entities, hard and soft line breaks, and the
// common inline HTML tags.

// Nesting limits that keep hostile input from recursing without bound: the
// deepest containers, open brackets and HTML elements, and the longest
// delimiter run read as emphasis.
const tvmd_max_depth = 48
const tvmd_max_run = 32

struct TvMdTok {
mut:
	node      TextViewNode
	delim     u8 // `*`, `_`, `~` delimiter run; `[` or `!` link opener; 0 a node
	count     int
	orig      int
	can_open  bool
	can_close bool
	src       int // source offset of the run's first remaining character
	depth     int // how deeply the node nests emphasis and links
}

fn tvmd_depth(toks []TvMdTok) int {
	mut depth := 0
	for tok in toks {
		depth = tv_max_int(depth, tok.depth)
	}
	return depth
}

struct TvMdBracket {
	tok      int
	image    bool
	text_pos int // where the label text starts
mut:
	active bool
}

struct TvMdInlineParser {
	text string
	segs []TvMdSeg
	refs map[string]TvMdRef
	html bool
mut:
	pos        int
	text_start int
	toks       []TvMdTok
	brackets   []TvMdBracket
}

fn tvmd_parse_inline(source TvMdInline, refs map[string]TvMdRef, html bool) []TextViewNode {
	mut p := TvMdInlineParser{
		text: source.text
		segs: source.segs
		refs: refs
		html: html
	}
	for p.pos < p.text.len {
		p.step()
	}
	p.flush()
	return tvmd_merge_text(tvmd_process_emphasis(p.toks))
}

// src maps an offset of the inline text onto source.
fn (p &TvMdInlineParser) src(pos int) int {
	if p.segs.len == 0 {
		return pos
	}
	mut seg := p.segs[0]
	for s in p.segs {
		if s.pos > pos {
			break
		}
		seg = s
	}
	return seg.src + pos - seg.pos
}

// flush turns the plain text since text_start into a verbatim text node. Plain
// text never holds a line break, so it lies on one line of source.
fn (mut p TvMdInlineParser) flush() {
	if p.pos > p.text_start {
		start := p.src(p.text_start)
		p.toks << TvMdTok{
			node: TextViewNode{
				kind:         .text
				text:         p.text[p.text_start..p.pos]
				source_start: start
				source_end:   start + p.pos - p.text_start
				verbatim:     true
			}
		}
	}
	p.text_start = p.pos
}

fn (mut p TvMdInlineParser) push_node(n TextViewNode, end int) {
	p.toks << TvMdTok{
		node: n
	}
	p.pos = end
	p.text_start = end
}

fn (mut p TvMdInlineParser) step() {
	t := p.text
	c := t[p.pos]
	match c {
		`\\` {
			if p.pos + 1 < t.len {
				n := t[p.pos + 1]
				if n == `\n` {
					p.flush()
					p.push_node(TextViewNode{
						kind:         .hard_break
						source_start: p.src(p.pos)
						source_end:   p.src(p.pos) + 2
					}, p.pos + 2)
					p.skip_line_start()
					return
				}
				if tvmd_is_punct(n) {
					p.flush()
					p.push_node(TextViewNode{
						kind:         .text
						text:         t[p.pos + 1..p.pos + 2]
						source_start: p.src(p.pos)
						source_end:   p.src(p.pos) + 2
					}, p.pos + 2)
					return
				}
			}
			p.pos++
		}
		`\`` {
			p.code_span()
		}
		`*`, `_`, `~` {
			p.delim_run()
		}
		`[` {
			p.open_bracket(false)
		}
		`!` {
			if p.pos + 1 < t.len && t[p.pos + 1] == `[` {
				p.open_bracket(true)
			} else {
				p.pos++
			}
		}
		`]` {
			p.close_bracket()
		}
		`<` {
			p.angle()
		}
		`&` {
			decoded, n := tv_decode_entity(t, p.pos)
			if n == 0 {
				p.pos++
				return
			}
			p.flush()
			p.push_node(TextViewNode{
				kind:         .text
				text:         decoded
				source_start: p.src(p.pos)
				source_end:   p.src(p.pos) + n
			}, p.pos + n)
		}
		`\n` {
			p.newline()
		}
		`h`, `w` {
			p.bare_autolink()
		}
		else {
			p.pos++
		}
	}
}

fn (mut p TvMdInlineParser) skip_line_start() {
	for p.pos < p.text.len && (p.text[p.pos] == ` ` || p.text[p.pos] == `\t`) {
		p.pos++
	}
	p.text_start = p.pos
}

fn (mut p TvMdInlineParser) newline() {
	t := p.text
	mut s := p.pos
	for s > p.text_start && t[s - 1] == ` ` {
		s--
	}
	hard := p.pos - s >= 2
	at := p.pos
	p.pos = s
	p.flush()
	p.push_node(TextViewNode{
		kind:         if hard { .hard_break } else { .soft_break }
		source_start: p.src(s)
		source_end:   p.src(at) + 1
	}, at + 1)
	p.skip_line_start()
}

fn (mut p TvMdInlineParser) code_span() {
	t := p.text
	start := p.pos
	mut n := 0
	for start + n < t.len && t[start + n] == `\`` {
		n++
	}
	mut k := start + n
	for k < t.len {
		if t[k] != `\`` {
			k++
			continue
		}
		mut m := 0
		for k + m < t.len && t[k + m] == `\`` {
			m++
		}
		if m != n {
			k += m
			continue
		}
		p.flush()
		raw := t[start + n..k]
		mut content := raw.replace('\n', ' ')
		mut lead := 0
		if content.len >= 2 && content[0] == ` ` && content[content.len - 1] == ` `
			&& content.trim(' ').len > 0 {
			content = content[1..content.len - 1]
			lead = 1
		}
		mut segs := []TextViewSpan{}
		if !raw.contains('\n') {
			from := p.src(start + n + lead)
			segs << TextViewSpan{
				rendered_start: 0
				rendered_end:   content.len
				source_start:   from
				source_end:     from + content.len
				verbatim:       true
			}
		}
		p.push_node(TextViewNode{
			kind:         .code_span
			text:         content
			segments:     segs
			source_start: p.src(start)
			source_end:   p.src(k + n - 1) + 1
		}, k + n)
		return
	}
	// No closing run: the backticks are text.
	p.pos = start + n
}

fn (mut p TvMdInlineParser) delim_run() {
	t := p.text
	c := t[p.pos]
	start := p.pos
	mut n := 0
	for start + n < t.len && t[start + n] == c {
		n++
	}
	// Long runs are rules or decoration, not emphasis, and would nest deeply.
	if (c == `~` && n > 2) || n > tvmd_max_run {
		p.pos += n
		return
	}
	before := if start == 0 { u8(` `) } else { t[start - 1] }
	next_char := if start + n >= t.len { u8(` `) } else { t[start + n] }
	ws_before := tvmd_is_space(before)
	ws_after := tvmd_is_space(next_char)
	punct_before := tvmd_is_punct(before)
	punct_after := tvmd_is_punct(next_char)
	left := !ws_after && (!punct_after || ws_before || punct_before)
	right := !ws_before && (!punct_before || ws_after || punct_after)
	mut can_open := left
	mut can_close := right
	if c == `_` {
		can_open = left && (!right || punct_before)
		can_close = right && (!left || punct_after)
	}
	p.flush()
	p.toks << TvMdTok{
		node:      TextViewNode{
			kind: .text
			text: t[start..start + n]
		}
		delim:     c
		count:     n
		orig:      n
		can_open:  can_open
		can_close: can_close
		src:       p.src(start)
	}
	p.pos = start + n
	p.text_start = p.pos
}

fn (mut p TvMdInlineParser) open_bracket(image bool) {
	if p.brackets.len >= tvmd_max_depth {
		p.pos += if image { 2 } else { 1 }
		return
	}
	p.flush()
	n := if image { 2 } else { 1 }
	p.toks << TvMdTok{
		node:  TextViewNode{
			kind:         .text
			text:         p.text[p.pos..p.pos + n]
			source_start: p.src(p.pos)
			source_end:   p.src(p.pos) + n
			verbatim:     true
		}
		delim: if image { u8(`!`) } else { u8(`[`) }
		src:   p.src(p.pos)
	}
	p.brackets << TvMdBracket{
		tok:      p.toks.len - 1
		image:    image
		text_pos: p.pos + n
		active:   true
	}
	p.pos += n
	p.text_start = p.pos
}

fn (mut p TvMdInlineParser) close_bracket() {
	t := p.text
	if p.brackets.len == 0 {
		p.pos++
		return
	}
	b := p.brackets.last()
	if !b.active {
		p.brackets.pop()
		p.pos++
		return
	}
	close := p.pos
	mut url := ''
	mut title := ''
	mut end := -1
	if close + 1 < t.len && t[close + 1] == `(` {
		if dest := tvmd_inline_dest(t, close + 2) {
			url = dest.url
			title = dest.title
			end = dest.end
		}
	}
	if end < 0 && close + 1 < t.len && t[close + 1] == `[` {
		if k := tvmd_find_label_end(t, close + 2) {
			inner := t[close + 2..k]
			label_text := if inner.trim_space().len == 0 { t[b.text_pos..close] } else { inner }
			if ref := p.refs[tvmd_norm_label(label_text)] {
				url = ref.url
				title = ref.title
				end = k + 1
			}
		}
	}
	if end < 0 {
		if ref := p.refs[tvmd_norm_label(t[b.text_pos..close])] {
			url = ref.url
			title = ref.title
			end = close + 1
		}
	}
	if end < 0 {
		p.brackets.pop()
		p.pos++
		return
	}
	depth := tvmd_depth(p.toks[b.tok + 1..]) + 1
	if depth > tvmd_max_depth {
		p.brackets.pop()
		p.pos++
		return
	}
	p.flush()
	children := tvmd_merge_text(tvmd_process_emphasis(p.toks[b.tok + 1..]))
	opener := p.toks[b.tok]
	source_start := opener.src
	source_end := p.src(end - 1) + 1
	node := if b.image {
		TextViewNode{
			kind:         .image
			url:          url
			title:        title
			text:         tv_plain_text(children)
			source_start: source_start
			source_end:   source_end
		}
	} else {
		TextViewNode{
			kind:         .link
			url:          url
			title:        title
			children:     children
			source_start: source_start
			source_end:   source_end
		}
	}
	p.toks = p.toks[..b.tok].clone()
	p.toks << TvMdTok{
		node:  node
		depth: depth
	}
	p.brackets.pop()
	if !b.image {
		// No links inside links.
		for mut br in p.brackets {
			if !br.image {
				br.active = false
			}
		}
	}
	p.pos = end
	p.text_start = end
}

struct TvMdDest {
	url   string
	title string
	end   int
}

fn tvmd_skip_ws(t string, i int) int {
	mut k := i
	mut newlines := 0
	for k < t.len && (t[k] == ` ` || t[k] == `\t` || t[k] == `\n`) {
		if t[k] == `\n` {
			newlines++
			if newlines > 1 {
				break
			}
		}
		k++
	}
	return k
}

// tvmd_inline_dest parses `dest "title")` after a link's `(`.
fn tvmd_inline_dest(t string, start int) ?TvMdDest {
	mut i := tvmd_skip_ws(t, start)
	mut url := ''
	if i < t.len && t[i] == `<` {
		mut k := i + 1
		for k < t.len && t[k] != `>` && t[k] != `\n` && t[k] != `<` {
			if t[k] == `\\` && k + 1 < t.len {
				k++
			}
			k++
		}
		if k >= t.len || t[k] != `>` {
			return none
		}
		url = t[i + 1..k]
		i = k + 1
	} else {
		mut depth := 0
		s := i
		for i < t.len {
			c := t[i]
			if c == `\\` && i + 1 < t.len && tvmd_is_punct(t[i + 1]) {
				i += 2
				continue
			}
			if c == `(` {
				depth++
			} else if c == `)` {
				if depth == 0 {
					break
				}
				depth--
			} else if c <= ` ` {
				break
			}
			i++
		}
		url = t[s..i]
	}
	j := tvmd_skip_ws(t, i)
	mut title := ''
	if j > i && j < t.len && t[j] in [`"`, `'`, `(`] {
		closer := if t[j] == `(` { u8(`)`) } else { t[j] }
		mut k := j + 1
		for k < t.len && t[k] != closer {
			if t[k] == `\\` && k + 1 < t.len {
				k++
			}
			k++
		}
		if k >= t.len {
			return none
		}
		title = t[j + 1..k]
		i = k + 1
	} else {
		i = j
	}
	i = tvmd_skip_ws(t, i)
	if i < t.len && t[i] == `)` {
		return TvMdDest{tvmd_unescape(url), tvmd_unescape(title), i + 1}
	}
	return none
}

fn (mut p TvMdInlineParser) angle() {
	t := p.text
	start := p.pos
	// <scheme:...> and <user@host> autolinks.
	mut k := start + 1
	for k < t.len && t[k] != `>` && t[k] != `<` && t[k] > ` ` {
		k++
	}
	if k < t.len && t[k] == `>` && k > start + 1 {
		inner := t[start + 1..k]
		mut url := ''
		if tvmd_is_uri(inner) {
			url = inner
		} else if tvmd_is_email(inner) {
			url = 'mailto:' + inner
		}
		if url.len > 0 {
			p.flush()
			from := p.src(start + 1)
			p.push_node(TextViewNode{
				kind:         .link
				url:          url
				children:     [
					TextViewNode{
						kind:         .text
						text:         inner
						source_start: from
						source_end:   from + inner.len
						verbatim:     true
					},
				]
				source_start: p.src(start)
				source_end:   p.src(k) + 1
			}, k + 1)
			return
		}
	}
	if p.html {
		if t[start..].starts_with('<!--') {
			end := t.index_after('-->', start + 4) or { -1 }
			if end >= 0 {
				p.flush()
				p.pos = end + 3
				p.text_start = p.pos
				return
			}
		}
		if end := tvhtml_tag_end(t, start) {
			p.flush()
			p.push_node(TextViewNode{
				kind:         .text
				tag:          t[start..end]
				source_start: p.src(start)
				source_end:   p.src(end - 1) + 1
			}, end)
			return
		}
	}
	p.pos++
}

fn tvmd_is_uri(s string) bool {
	colon := s.index(':') or { return false }
	if colon < 2 || colon > 32 || !s[0].is_letter() {
		return false
	}
	for c in s[..colon] {
		if !(c.is_letter() || c.is_digit() || c == `+` || c == `.` || c == `-`) {
			return false
		}
	}
	return true
}

fn tvmd_is_email(s string) bool {
	at := s.index('@') or { return false }
	if at == 0 || at == s.len - 1 || !s[at + 1..].contains('.') {
		return false
	}
	for c in s {
		if !(c.is_letter() || c.is_digit() || c in [`.`, `-`, `_`, `+`, `@`]) {
			return false
		}
	}
	return true
}

// bare_autolink links `https://...`, `http://...` and `www....` where a word
// starts, as GitHub does.
fn (mut p TvMdInlineParser) bare_autolink() {
	t := p.text
	start := p.pos
	if start > 0 && !(tvmd_is_space(t[start - 1]) || t[start - 1] in [`*`, `_`, `~`, `(`]) {
		p.pos++
		return
	}
	rest := t[start..]
	www := rest.starts_with('www.')
	if !www && !rest.starts_with('https://') && !rest.starts_with('http://') {
		p.pos++
		return
	}
	mut k := start
	for k < t.len && !tvmd_is_space(t[k]) && t[k] != `<` {
		k++
	}
	// Trailing punctuation is the sentence's, and so is an unbalanced `)`.
	for k > start {
		c := t[k - 1]
		if c in [`?`, `!`, `.`, `,`, `:`, `*`, `_`, `~`, `'`, `"`] {
			k--
			continue
		}
		if c == `)` {
			seg := t[start..k]
			if seg.count('(') < seg.count(')') {
				k--
				continue
			}
		}
		break
	}
	link_text := t[start..k]
	scheme_len := if www { 0 } else { link_text.index('//') or { 0 } + 2 }
	host := link_text[scheme_len..]
	if host.len == 0 || !host.contains('.') || host.starts_with('.') {
		p.pos++
		return
	}
	p.flush()
	from := p.src(start)
	p.push_node(TextViewNode{
		kind:         .link
		url:          if www { 'http://' + link_text } else { link_text }
		children:     [
			TextViewNode{
				kind:         .text
				text:         link_text
				source_start: from
				source_end:   from + link_text.len
				verbatim:     true
			},
		]
		source_start: from
		source_end:   from + link_text.len
	}, k)
}

// tvmd_process_emphasis matches delimiter runs into emphasis, strong emphasis
// and strikethrough, following CommonMark's algorithm, and returns the nodes.
// The tokens are kept in a linked list, so wrapping the tokens between an
// opener and its closer into a node costs no more than those tokens.
fn tvmd_process_emphasis(input []TvMdTok) []TextViewNode {
	mut toks := input.clone()
	if toks.len == 0 {
		return []
	}
	mut next := []int{len: toks.len, init: index + 1}
	mut prev := []int{len: toks.len, init: index - 1}
	next[toks.len - 1] = -1
	mut head := 0
	mut current := 0
	for current != -1 {
		closer := toks[current]
		if closer.delim !in [`*`, `_`, `~`] || !closer.can_close || closer.count == 0 {
			current = next[current]
			continue
		}
		mut found := -1
		mut j := prev[current]
		// An opener further back than this is not looked for, which bounds the
		// work hostile input can cause.
		mut steps := 0
		for j != -1 && steps < 1000 {
			steps++
			o := toks[j]
			if o.delim == closer.delim && o.can_open && o.count > 0 {
				matches := if closer.delim == `~` {
					o.count == closer.count
				} else {
					!((o.can_close || closer.can_open) && (o.orig + closer.orig) % 3 == 0
						&& !(o.orig % 3 == 0 && closer.orig % 3 == 0))
				}
				if matches {
					found = j
					break
				}
			}
			j = prev[j]
		}
		if found < 0 {
			current = next[current]
			continue
		}
		opener := toks[found]
		used := if closer.delim == `~` {
			opener.count
		} else if opener.count >= 2 && closer.count >= 2 {
			2
		} else {
			1
		}
		kind := if closer.delim == `~` {
			TextViewNodeKind.strikethrough
		} else if used == 2 {
			TextViewNodeKind.strong
		} else {
			TextViewNodeKind.emphasis
		}
		mut inner := []TvMdTok{}
		mut k := next[found]
		for k != current {
			inner << toks[k]
			k = next[k]
		}
		depth := tvmd_depth(inner) + 1
		if depth > tvmd_max_depth {
			current = next[current]
			continue
		}
		node_index := toks.len
		toks << TvMdTok{
			depth: depth
			node:  TextViewNode{
				kind:         kind
				children:     tvmd_merge_text(tvmd_toks_to_nodes(inner))
				source_start: opener.src + opener.count - used
				source_end:   closer.src + used
			}
		}
		toks[found].count -= used
		toks[current].count -= used
		toks[current].src += used
		// Splice opener, node, closer; a run with nothing left drops out. The
		// closer is looked at again while it has delimiters left.
		next << current
		prev << found
		next[found] = node_index
		prev[current] = node_index
		if toks[found].count == 0 {
			before := prev[found]
			if before == -1 {
				head = node_index
			} else {
				next[before] = node_index
			}
			prev[node_index] = before
		}
		if toks[current].count == 0 {
			after_closer := next[current]
			next[node_index] = after_closer
			if after_closer != -1 {
				prev[after_closer] = node_index
			}
			current = after_closer
		}
	}
	mut out := []TvMdTok{}
	mut k := head
	for k != -1 {
		out << toks[k]
		k = next[k]
	}
	return tvmd_toks_to_nodes(out)
}

// tvmd_toks_to_nodes turns what is left of delimiter runs and brackets into
// text, and pairs inline HTML tags.
fn tvmd_toks_to_nodes(toks []TvMdTok) []TextViewNode {
	mut out := []TextViewNode{cap: toks.len}
	for tok in toks {
		if tok.delim in [`*`, `_`, `~`] {
			if tok.count > 0 {
				out << TextViewNode{
					kind:         .text
					text:         [tok.delim].bytestr().repeat(tok.count)
					source_start: tok.src
					source_end:   tok.src + tok.count
					verbatim:     true
				}
			}
			continue
		}
		out << tok.node
	}
	return tvmd_pair_html(out)
}

// tvmd_merge_text joins neighbouring text nodes that come from neighbouring
// source, so `foo*bar` with an unmatched `*` is one node again.
fn tvmd_merge_text(nodes []TextViewNode) []TextViewNode {
	if nodes.len < 2 {
		return nodes
	}
	mut out := []TextViewNode{cap: nodes.len}
	for n in nodes {
		if out.len > 0 && n.kind == .text && n.tag.len == 0 && n.verbatim
			&& n.segments.len == 0 {
			prev := out.last()
			if prev.kind == .text && prev.tag.len == 0 && prev.verbatim
				&& prev.segments.len == 0 && prev.source_end == n.source_start {
				out[out.len - 1] = TextViewNode{
					...prev
					text:       prev.text + n.text
					source_end: n.source_end
				}
				continue
			}
		}
		out << n
	}
	return out
}

struct TvHtmlOpen {
	name  string
	index int
	attrs map[string]string
}

// tvmd_pair_html wraps the content between an inline HTML open tag and its
// close tag in the node the tag stands for. Tags it does not know are dropped,
// keeping their content, as a sanitizing renderer does.
fn tvmd_pair_html(nodes []TextViewNode) []TextViewNode {
	mut any_tag := false
	for n in nodes {
		if n.tag.len > 0 {
			any_tag = true
			break
		}
	}
	if !any_tag {
		return nodes
	}
	mut out := []TextViewNode{cap: nodes.len}
	mut stack := []TvHtmlOpen{}
	for n in nodes {
		if n.tag.len == 0 {
			out << n
			continue
		}
		found := tvhtml_read_tag(n.tag, 0) or { continue }
		if found.name == 'br' {
			out << TextViewNode{
				kind:         .hard_break
				source_start: n.source_start
				source_end:   n.source_end
			}
			continue
		}
		if found.name == 'img' {
			out << tvhtml_image(found.attrs, n.source_start, n.source_end)
			continue
		}
		if found.closing {
			mut k := stack.len - 1
			for k >= 0 && stack[k].name != found.name {
				k--
			}
			if k < 0 {
				continue
			}
			open := stack[k]
			stack = stack[..k].clone()
			inner := out[open.index..].clone()
			out = out[..open.index].clone()
			out << tvhtml_wrap_inline(open.name, open.attrs, inner, n.source_end)
			continue
		}
		if !found.self_closing && tvhtml_inline_kind(found.name) {
			stack << TvHtmlOpen{
				name:  found.name
				index: out.len
				attrs: found.attrs
			}
		}
	}
	return out
}
