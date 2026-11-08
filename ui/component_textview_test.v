module ui2

import math

// ── Helpers ─────────────────────────────────────────────────────────

fn tvt_kinds(nodes []TextViewNode) []TextViewNodeKind {
	return nodes.map(it.kind)
}

fn tvt_md(source string) TextViewDocument {
	return text_view_markdown(source)
}

// tvt_first finds the first node of a kind, depth first.
fn tvt_first(n TextViewNode, kind TextViewNodeKind) ?TextViewNode {
	if n.kind == kind {
		return n
	}
	for child in n.children {
		if found := tvt_first(child, kind) {
			return found
		}
	}
	return none
}

fn tvt_count(n TextViewNode, kind TextViewNodeKind) int {
	mut count := if n.kind == kind { 1 } else { 0 }
	for child in n.children {
		count += tvt_count(child, kind)
	}
	return count
}

fn tvt_inline(source string) []TextViewNode {
	doc := tvt_md(source)
	return doc.root.children[0].children
}

fn tvt_layout(source string, width f64) TextViewLayout {
	return text_view_layout(tvt_md(source), width: width)
}

fn tvt_texts(lay TextViewLayout) []TextViewItem {
	return lay.items.filter(it.kind == .text)
}

fn tvt_walk(el Element, mut out []Element) {
	out << el
	for child in el.children {
		tvt_walk(child, mut out)
	}
}

fn tvt_all(el Element) []Element {
	mut out := []Element{}
	tvt_walk(el, mut out)
	return out
}

fn tvt_by_id(el Element, id string) ?Element {
	for e in tvt_all(el) {
		if e.id == id {
			return e
		}
	}
	return none
}

// ── Markdown blocks ─────────────────────────────────────────────────

fn test_textview_markdown_blocks() {
	doc := tvt_md('# Title\n\nHello *world*.\n\n- a\n- b\n')
	assert tvt_kinds(doc.root.children) == [.heading, .paragraph, .list]
	assert doc.text == 'Title\nHello world.\na\nb'
	assert doc.rendered_text() == doc.text
}

fn test_textview_atx_and_setext_headings() {
	doc := tvt_md('## Second ##\n###### Six\n####### seven\n#nospace\n\nSetext one\n===\n\nSetext two\n---')
	h := doc.root.children
	assert h[0].kind == .heading && h[0].level == 2
	assert tv_plain_text(h[0].children) == 'Second'
	assert h[1].kind == .heading && h[1].level == 6
	assert h[2].kind == .paragraph // seven #s and `#nospace` are text
	assert tv_plain_text(h[2].children) == '####### seven #nospace'
	assert h[3].kind == .heading && h[3].level == 1
	assert tv_plain_text(h[3].children) == 'Setext one'
	assert h[4].kind == .heading && h[4].level == 2
}

fn test_textview_thematic_breaks() {
	doc := tvt_md('***\n\n- - -\n\n___\n\nText\n\n* * *')
	assert tvt_kinds(doc.root.children) == [.thematic_break, .thematic_break, .thematic_break,
		.paragraph, .thematic_break]
}

fn test_textview_soft_and_hard_breaks() {
	nodes := tvt_inline('one\ntwo  \nthree\\\nfour')
	assert tvt_kinds(nodes) == [.text, .soft_break, .text, .hard_break, .text, .hard_break, .text]
	doc := tvt_md('one\ntwo  \nthree')
	assert doc.text == 'one two\nthree'
}

fn test_textview_fenced_and_indented_code() {
	doc := tvt_md('```v title="x"\nfn main() {\n\tprintln(1)\n}\n```\n\n~~~\nplain\n~~~\n\n    indented\n      more\n\n```\nunclosed')
	blocks := doc.root.children
	assert blocks.len == 4
	assert blocks[0].kind == .code_block && blocks[0].fenced
	assert blocks[0].lang == 'v'
	assert blocks[0].info == 'v title="x"'
	assert blocks[0].text == 'fn main() {\n\tprintln(1)\n}'
	assert blocks[0].children.len == 3
	assert blocks[1].text == 'plain'
	assert !blocks[2].fenced
	assert blocks[2].text == 'indented\n  more'
	assert blocks[3].text == 'unclosed'
	assert doc.code_blocks.len == 4
	assert doc.code_blocks[0].index == 0 && doc.code_blocks[0].code == blocks[0].text
	assert blocks[3].index == 3
}

fn test_textview_blockquotes_and_lazy_lines() {
	doc := tvt_md('> quoted\nlazy line\n> > nested\n\nafter')
	quote := doc.root.children[0]
	assert quote.kind == .blockquote
	assert quote.children[0].kind == .paragraph
	assert tv_plain_text(quote.children[0].children) == 'quoted lazy line'
	assert quote.children[1].kind == .blockquote
	assert doc.root.children[1].kind == .paragraph
	// A lazy line does not continue a quote's code block.
	fenced := tvt_md('> ```\n> code\nnot code')
	assert fenced.root.children.len == 2
}

fn test_textview_lists_tight_loose_nested() {
	doc := tvt_md('- a\n- b\n  - nested\n    1. deep\n- c\n\n3. three\n4. four\n\n- x\n\n- y\n')
	lists := doc.root.children
	assert lists.len == 3
	assert lists[0].kind == .list && !lists[0].ordered && lists[0].tight
	assert lists[0].children.len == 3
	nested := lists[0].children[1].children[1]
	assert nested.kind == .list
	assert nested.children[0].children[1].kind == .list
	assert nested.children[0].children[1].ordered
	assert lists[1].ordered && lists[1].start == 3 && lists[1].children.len == 2
	assert !lists[2].tight
}

fn test_textview_list_interruption_rules() {
	// Only a list starting at 1 interrupts a paragraph.
	doc := tvt_md('text\n2. not a list\n\ntext\n1. a list')
	assert tvt_kinds(doc.root.children) == [.paragraph, .paragraph, .list]
	// Different bullet characters start new lists.
	two := tvt_md('- a\n+ b')
	assert tvt_kinds(two.root.children) == [.list, .list]
}

fn test_textview_task_list_items() {
	doc := tvt_md('- [ ] todo\n- [x] done\n- [X] also\n- [] not a task\n')
	items := doc.root.children[0].children
	assert items.map(it.task) == [TextViewTask.unchecked, .checked, .checked, .plain]
	assert tv_plain_text(items[0].children[0].children) == 'todo'
	assert tv_plain_text(items[3].children[0].children) == '[] not a task'
	assert doc.text == 'todo\ndone\nalso\n[] not a task'
}

fn test_textview_list_with_code_and_paragraphs() {
	doc := tvt_md('1. first\n\n   second paragraph\n\n   ```\n   code\n   ```\n2. next')
	list_node := doc.root.children[0]
	assert list_node.children.len == 2
	assert tvt_kinds(list_node.children[0].children) == [.paragraph, .paragraph, .code_block]
	assert !list_node.tight
	assert list_node.children[0].children[2].text == 'code'
}

fn test_textview_tables() {
	doc := tvt_md('| Name | Qty | Note |\n|:--|--:|:-:|\n| a \\| b | 2 |\n| c | 3 | x | extra |\n\nafter')
	table_node := doc.root.children[0]
	assert table_node.kind == .table
	assert table_node.children.len == 3
	head := table_node.children[0]
	assert head.header && head.children.map(it.align) == [TextViewAlign.left, .right, .center]
	assert tv_plain_text(table_node.children[1].children[0].children) == 'a | b'
	// Missing cells are empty, extra ones dropped.
	assert table_node.children[1].children.len == 3
	assert table_node.children[2].children.len == 3
	assert doc.root.children[1].kind == .paragraph
	assert doc.text.starts_with('Name\tQty\tNote\na | b\t2\t\nc\t3\tx')
	// A delimiter row needs a header with a pipe; otherwise it is a setext heading.
	setext := tvt_md('Title\n---')
	assert setext.root.children[0].kind == .heading
	// The table header can end a paragraph.
	after := tvt_md('intro\n| a | b |\n|---|---|\n| 1 | 2 |')
	assert tvt_kinds(after.root.children) == [.paragraph, .table]
}

fn test_textview_link_reference_definitions() {
	doc := tvt_md('[Full][ref], [ref][], [ref] and [missing].\n\n[ref]: https://example.com "Title"\n[other]: <https://x.org>')
	assert doc.root.children.len == 1
	links := tvt_md('[a][ref]\n\n[ref]: /url').links
	assert links == ['/url']
	assert doc.links == ['https://example.com', 'https://example.com', 'https://example.com']
	assert doc.text == 'Full, ref, ref and [missing].'
	first := tvt_first(doc.root, .link) or { panic('no link') }
	assert first.title == 'Title'
}

// ── Markdown inlines ────────────────────────────────────────────────

fn test_textview_emphasis_rules() {
	assert tvt_kinds(tvt_inline('*a* _b_ **c** __d__')) == [.emphasis, .text, .emphasis, .text,
		.strong, .text, .strong]
	both := tvt_inline('***both***')
	assert both.len == 1 && both[0].kind == .emphasis
	assert both[0].children[0].kind == .strong
	assert tv_plain_text(both) == 'both'
	// Underscores inside words are not emphasis; spaces inside delimiters break them.
	assert tvt_kinds(tvt_inline('snake_case_name')) == [.text]
	assert tvt_kinds(tvt_inline('*not emphasis *')) == [.text]
	nested := tvt_inline('*a **b** c*')
	assert nested.len == 1 && nested[0].kind == .emphasis
	assert nested[0].children[1].kind == .strong
	// Rule of three: `**a*` leaves one star as text.
	assert tv_plain_text(tvt_inline('**a*')) == '*a'
	assert tvt_md('2 * 3 * 4').text == '2 * 3 * 4'
}

fn test_textview_strikethrough() {
	assert tvt_kinds(tvt_inline('~~gone~~ and ~one~')) == [.strikethrough, .text, .strikethrough]
	assert tvt_kinds(tvt_inline('a ~~~three~~~')) == [.text]
	// At the start of a line three tildes open a code fence.
	assert tvt_md('~~~three~~~').root.children[0].kind == .code_block
	assert tvt_kinds(tvt_inline('~~a~')) == [.text]
}

fn test_textview_code_spans() {
	nodes := tvt_inline('`code` and `` a ` b `` and ` spaced `')
	spans := nodes.filter(it.kind == .code_span)
	assert spans.map(it.text) == ['code', 'a ` b', 'spaced']
	assert tvt_kinds(tvt_inline('`unclosed')) == [.text]
	// Emphasis and escapes do not apply inside code.
	assert tvt_inline('`*x* \\*`')[0].text == '*x* \\*'
	multi := tvt_inline('`a\nb`')
	assert multi[0].text == 'a b'
}

fn test_textview_links_and_images() {
	nodes := tvt_inline('[text *em*](http://a.com "T") ![alt **x**](img.png) [![logo](l.png)](http://b.com)')
	assert nodes[0].kind == .link && nodes[0].url == 'http://a.com' && nodes[0].title == 'T'
	assert nodes[0].children[1].kind == .emphasis
	assert nodes[2].kind == .image && nodes[2].url == 'img.png' && nodes[2].text == 'alt x'
	assert nodes[4].kind == .link && nodes[4].children[0].kind == .image
	// Destinations with parentheses, angle brackets and escapes.
	parens := tvt_inline('[a](https://x.org/a_(b)) [c](<with space>) [d](\\(e\\))')
	assert parens.filter(it.kind == .link).map(it.url) == ['https://x.org/a_(b)', 'with space',
		'(e)']
	// No links inside links.
	inner := tvt_inline('[a [b](u1) c](u2)')
	assert tvt_count(TextViewNode{ children: inner }, .link) == 1
	// Brackets that are not links stay text.
	assert tvt_md('[not a link] and [x](').text == '[not a link] and [x]('
}

fn test_textview_autolinks() {
	nodes := tvt_inline('<https://vlang.io> <me@example.com> see https://x.org/a?b=1. and www.example.com, (http://y.org)')
	links := nodes.filter(it.kind == .link)
	assert links.map(it.url) == ['https://vlang.io', 'mailto:me@example.com', 'https://x.org/a?b=1',
		'http://www.example.com', 'http://y.org']
	assert tv_plain_text(links[2].children) == 'https://x.org/a?b=1'
	// Not at a word start, or no dot in the host: plain text.
	assert tvt_count(TextViewNode{ children: tvt_inline('xhttps://a.b and https://localhost') }, .link) == 0
}

fn test_textview_escapes_and_entities() {
	doc := tvt_md('\\*not em\\* &amp; &copy; &#65;&#x42; &bogus; &#xZZ; \\q')
	assert doc.text == '*not em* & © AB &bogus; &#xZZ; \\q'
	zero, zero_len := tv_decode_entity('&#0;', 0)
	assert zero == '\ufffd' && zero_len == 4
	big, big_len := tv_decode_entity('&#x110000;', 0)
	assert big == '\ufffd' && big_len == 10
	_, open_len := tv_decode_entity('&amp', 0)
	assert open_len == 0
}

fn test_textview_inline_html() {
	nodes := tvt_inline('a <b>bold <i>both</i></b><br>next <span>plain</span> <code>c</code> <a href="/u">l</a> <x-y>z</x-y><!-- gone -->')
	assert tvt_count(TextViewNode{ children: nodes }, .strong) == 1
	assert tvt_count(TextViewNode{ children: nodes }, .emphasis) == 1
	assert tvt_count(TextViewNode{ children: nodes }, .hard_break) == 1
	assert tvt_count(TextViewNode{ children: nodes }, .code_span) == 1
	link_node := tvt_first(TextViewNode{ children: nodes }, .link) or { panic('no link') }
	assert link_node.url == '/u'
	assert tv_plain_text(nodes) == 'a bold both\nnext plain c l z'
	// With HTML off, tags are text.
	off := text_view_parse_markdown('<b>x</b>', TextViewMarkdownOptions{ html: false })
	assert off.text == '<b>x</b>'
}

fn test_textview_html_blocks_in_markdown() {
	doc := tvt_md('<div>\n<p>Hello <b>there</b></p>\n</div>\n\n*after*')
	assert doc.root.children[0].kind == .html_block
	assert doc.root.children[0].children[0].kind == .paragraph
	assert doc.text == 'Hello there\nafter'
	comment := tvt_md('<!--\nhidden\n-->\nshown')
	assert comment.text == 'shown'
}

fn test_textview_frontmatter() {
	source := '---\ntitle: Hello\ntags: one two\nbody: |-\n  line one\n    indented\nfold: >-\n  a\n  b\n---\n# Doc'
	off := tvt_md(source)
	assert off.root.children[0].kind == .thematic_break
	doc := text_view_parse_markdown(source, frontmatter: true)
	front := doc.root.children[0]
	assert front.kind == .frontmatter
	assert front.entries.map(it.key) == ['title', 'tags', 'body', 'fold']
	assert front.entries.map(it.value) == ['Hello', 'one two', 'line one\n  indented', 'a b']
	assert doc.root.children[1].kind == .heading
	assert doc.text.starts_with('title\tHello\ntags\tone two\n')
	// Quoted values, comments and collections are kept as YAML source.
	for yaml in ['---\nname: "quoted"\n---', '---\nname: x # comment\n---', '---\nlist:\n  - a\n---',
		'---\n# note\n---'] {
		fallback := text_view_parse_markdown(yaml, frontmatter: true)
		block := fallback.root.children[0]
		assert block.kind == .code_block, yaml
		assert block.lang == 'yaml'
	}
	// No closing line: not front matter.
	open := text_view_parse_markdown('---\ntitle: x\n', frontmatter: true)
	assert open.root.children[0].kind == .thematic_break
}

// ── Source mapping ──────────────────────────────────────────────────

fn test_textview_range_for_source() {
	doc := tvt_md('hello **world** &amp; x')
	assert doc.text == 'hello world & x'
	// The delimiters render nothing: the bold word converts to its text.
	whole := doc.range_for_source(6, 15) or { panic('none') }
	assert whole == TextViewRange{6, 11}
	inner := doc.range_for_source(8, 13) or { panic('none') }
	assert inner == whole
	// Part of an entity includes all of it.
	amp := doc.range_for_source(17, 19) or { panic('none') }
	assert amp == TextViewRange{12, 13}
	if _ := doc.range_for_source(6, 8) {
		assert false, 'delimiters alone render nothing'
	}
	if _ := doc.range_for_source(3, 3) {
		assert false, 'empty range'
	}
	if _ := doc.range_for_source(0, 999) {
		assert false, 'out of bounds'
	}
	multibyte := tvt_md('é')
	if _ := multibyte.range_for_source(1, 2) {
		assert false, 'not on a character boundary'
	}
}

fn test_textview_rendered_offset_for_source() {
	doc := tvt_md('# Hi\n\nOne **bo')
	assert doc.text == 'Hi\nOne **bo'
	// Source offset 10 is the first `*`, rendered as it is while unmatched.
	assert doc.rendered_offset_for_source(10) == doc.text.len - 4
	completed := tvt_md('# Hi\n\nOne **bold**')
	// The bold word's first two letters were there before the 14 bytes the
	// first text had; the rest is new.
	assert completed.text == 'Hi\nOne bold'
	assert completed.rendered_offset_for_source(14) == completed.text.len - 2
	assert completed.rendered_offset_for_source(999) == completed.text.len
	html := text_view_html('<p>a &amp; b</p>')
	assert html.text == 'a & b'
	assert html.rendered_offset_for_source(7) == 2
}

fn test_textview_valid_range() {
	assert text_view_valid_range('héllo', 0, 3)
	assert !text_view_valid_range('héllo', 0, 2)
	assert !text_view_valid_range('abc', 2, 1)
	assert !text_view_valid_range('abc', -1, 1)
	assert !text_view_valid_range('abc', 0, 4)
}

// ── HTML ────────────────────────────────────────────────────────────

fn test_textview_html_basic() {
	doc := text_view_html('<h2>Title</h2><p>One <b>two</b> <em>three</em> <s>four</s> <code>5</code></p><hr><blockquote><p>q</p></blockquote>')
	assert tvt_kinds(doc.root.children) == [.heading, .paragraph, .thematic_break, .blockquote]
	assert doc.root.children[0].level == 2
	assert doc.text == 'Title\nOne two three four 5\nq'
	assert doc.html
}

fn test_textview_html_tolerates_malformed_markup() {
	doc := text_view_html('<p>one<p>two <b>bold <i>both</b> after</i></div><ul><li>a<li>b</ul><table><tr><td>1<td>2<tr><td>3</table>')
	assert tvt_count(doc.root, .paragraph) >= 2
	list_node := tvt_first(doc.root, .list) or { panic('no list') }
	assert list_node.children.len == 2
	table_node := tvt_first(doc.root, .table) or { panic('no table') }
	assert table_node.children.len == 2
	assert table_node.children[1].children.len == 2
	for junk in ['<', '<<<>>>&&&;;', '<a href="unterminated', '</p></p>', '<p', '&#xFFFFFFFF;',
		'<script>alert(1)', '<!--', '<table><td>x', '<ul><li><ul><li>deep'] {
		_ := text_view_html(junk)
		_ := tvt_md(junk)
	}
}

fn test_textview_html_whitespace_entities_and_pre() {
	doc := text_view_html('<p>  a\n   b  &amp;\tc &nbsp;d  </p><pre><code class="language-v">x  y\n  z\n</code></pre>')
	assert doc.text == 'a b & c \u00a0d\nx  y\n  z'
	code := tvt_first(doc.root, .code_block) or { panic('no code') }
	assert code.lang == 'v'
	assert code.children.len == 2
	assert text_view_html('<p>a <b> b</b> c<br>  d</p>').text == 'a b c\nd'
	assert text_view_html('<script>var x = "<p>";</script><style>p{}</style><p>ok</p><!-- c -->').text == 'ok'
}

fn test_textview_html_lists_tables_images_links() {
	doc := text_view_html('<ol start="3"><li><input type="checkbox" checked> done</li><li>two<ul><li>nested</li></ul></li></ol><table><thead><tr><th>K</th><th align="right">V</th></tr></thead><tbody><tr><td style="text-align: center">a</td><td>1</td></tr></tbody></table><p><a href="/x" title="T">link</a> <img src="i.png" alt="pic" width="40" height="20"></p>')
	list_node := doc.root.children[0]
	assert list_node.ordered && list_node.start == 3
	assert list_node.children[0].task == .checked
	assert tvt_first(list_node.children[1], .list) != none
	table_node := doc.root.children[1]
	assert table_node.children[0].header
	assert table_node.children[0].children[1].align == .right
	assert table_node.children[1].children[0].align == .center
	img := tvt_first(doc.root, .image) or { panic('no image') }
	assert img.url == 'i.png' && img.text == 'pic' && img.width == 40 && img.height == 20
	assert doc.links == ['/x']
}

// ── Layout ──────────────────────────────────────────────────────────

fn test_textview_layout_runs_line_up() {
	lay := tvt_layout('plain **bold** *italic* `code` [link](u) ~~gone~~ end of the line here', 2000)
	texts := tvt_texts(lay)
	assert texts.len >= 6
	for i in 1 .. texts.len {
		prev := texts[i - 1]
		cur := texts[i]
		assert cur.line == prev.line
		// Runs follow each other exactly; code spans add their padding.
		gap := cur.text_x - (prev.text_x + prev.advance)
		if prev.mono || cur.mono {
			assert gap > 0 && gap < 12
		} else {
			assert math.abs(gap) < 0.01, '${prev.text} -> ${cur.text}: ${gap}'
		}
		assert cur.rendered_start >= prev.rendered_end
	}
	// The rendered text of the items is the paragraph's.
	mut joined := ''
	for item in texts {
		joined += lay.document.text[item.rendered_start..item.rendered_end]
	}
	assert joined == lay.document.text
	assert texts.filter(it.bold).len == 1
	assert texts.filter(it.italic).len == 1
	assert texts.filter(it.underline).len == 1
	assert texts.filter(it.strike).len == 1
	// The code span has its tinted background, the strikethrough its line.
	assert lay.items.filter(it.kind == .fill && it.role == .code_background).len == 1
}

fn test_textview_layout_wraps_within_width() {
	width := 200.0
	lay := tvt_layout('The quick brown fox jumps over the lazy dog, again and again, until the paragraph has to wrap onto several lines.',
		width)
	texts := tvt_texts(lay)
	mut lines := map[int]bool{}
	for item in texts {
		assert item.text_x + item.advance <= width + 0.5
		assert item.text_x >= 0
		lines[item.line] = true
	}
	assert lines.len > 3
	assert lay.height == math.ceil(lay.lines.last().frame.y + lay.lines.last().frame.height)
	narrow := tvt_layout('The quick brown fox jumps over the lazy dog.', 80)
	wide := tvt_layout('The quick brown fox jumps over the lazy dog.', 800)
	assert narrow.height > wide.height
	assert wide.lines.len == 1
}

fn test_textview_layout_breaks_long_words() {
	lay := tvt_layout('https://example.com/a/very/long/path/that/cannot/fit/on/one/line', 120)
	texts := tvt_texts(lay)
	assert texts.len > 1
	mut joined := ''
	for item in texts {
		assert item.text_x + item.advance <= 120.5
		joined += item.text
	}
	assert joined == 'https://example.com/a/very/long/path/that/cannot/fit/on/one/line'
}

fn test_textview_layout_headings_and_rules() {
	lay := tvt_layout('# One\n\n## Two\n\n### Three\n\nbody\n\n---', 400)
	texts := tvt_texts(lay)
	assert texts[0].size > texts[1].size
	assert texts[1].size > texts[2].size
	assert texts[2].size > texts[3].size
	assert texts[0].bold && !texts[3].bold
	// H1 and H2 are underlined by a rule, and so is the thematic break.
	rules := lay.items.filter(it.kind == .fill && it.role == .border)
	assert rules.len == 3
	assert text_view_heading_scale(TextViewStyle{}, 1) == 1.75
	assert text_view_heading_scale(TextViewStyle{ heading_scales: [3.0] }, 1) == 3.0
	assert text_view_heading_scale(TextViewStyle{}, 99) == 0.9
}

fn test_textview_layout_lists_and_markers() {
	lay := tvt_layout('- a\n  - b\n    - c\n\n7. seven\n8. eight\n\n- [x] done\n- [ ] todo', 400)
	checks := lay.items.filter(it.kind == .check)
	assert checks.len == 2
	assert checks[0].checked && !checks[1].checked
	numbers := tvt_texts(lay).filter(it.rendered_start < 0)
	assert numbers.map(it.text) == ['7.', '8.']
	content := tvt_texts(lay).filter(it.text == 'seven')[0]
	// Numbers sit before their item's text, on its line.
	assert numbers[0].text_x + numbers[0].advance < content.text_x
	assert math.abs((numbers[0].frame.y + numbers[0].frame.height / 2) - (content.frame.y +
		content.frame.height / 2)) < 2
	// Nested items are indented further.
	a := tvt_texts(lay).filter(it.text == 'a')[0]
	b := tvt_texts(lay).filter(it.text == 'b')[0]
	c := tvt_texts(lay).filter(it.text == 'c')[0]
	assert a.text_x < b.text_x && b.text_x < c.text_x
	// Three bullet styles: disc, ring (two fills), square.
	bullets := lay.items.filter(it.kind == .fill && (it.role == .foreground || it.role == .background))
	assert bullets.len == 4
}

fn test_textview_layout_quote() {
	lay := tvt_layout('> quoted text\n> more', 300)
	bar := lay.items.filter(it.kind == .fill && it.role == .quote_bar)
	assert bar.len == 1
	texts := tvt_texts(lay)
	assert texts.all(it.role == .muted)
	assert texts[0].text_x > bar[0].frame.x + bar[0].frame.width
	assert bar[0].frame.height >= texts[0].frame.height
}

fn test_textview_layout_code_blocks() {
	lay := tvt_layout('```v\nshort\n```\n\n```\n' + 'x'.repeat(200) + '\n```', 300)
	headers := lay.items.filter(it.kind == .code_header)
	assert headers.len == 2
	assert headers[0].text == 'v' && headers[0].block == 0
	containers := lay.items.filter(it.kind == .container)
	assert containers.len == 1
	assert containers[0].block == 1
	assert containers[0].content_width > containers[0].frame.width
	long_line := tvt_texts(lay).filter(it.mono && it.text.len == 200)[0]
	assert long_line.container == lay.items.index(containers[0])
	// Wrapping instead of scrolling.
	wrapped := text_view_layout(tvt_md('```\n' + 'word '.repeat(60) + '\n```'),
		width: 300
		style: TextViewStyle{
			wrap_code: true
		}
	)
	assert wrapped.items.filter(it.kind == .container).len == 0
	assert tvt_texts(wrapped).len > 3
	for item in tvt_texts(wrapped) {
		assert item.text_x + item.advance <= 300
	}
	// No header when asked.
	plain := text_view_layout(tvt_md('```\nx\n```'), width: 300, code_header: false)
	assert plain.items.filter(it.kind == .code_header).len == 0
}

fn test_textview_layout_tables() {
	source := '| Left | Right |\n|:--|--:|\n| a | 1 |\n| longer cell | 22 |'
	lay := tvt_layout(source, 600)
	texts := tvt_texts(lay)
	assert texts.filter(it.bold).map(it.text) == ['Left', 'Right']
	one := texts.filter(it.text == '1')[0]
	twenty_two := texts.filter(it.text == '22')[0]
	// Right-aligned cells end at the same x.
	assert math.abs((one.text_x + one.advance) - (twenty_two.text_x + twenty_two.advance)) < 0.5
	assert lay.items.filter(it.kind == .fill && it.role == .table_header).len == 1
	assert lay.items.filter(it.kind == .container).len == 0
	// Narrow: columns shrink and cells wrap; narrower still, the table scrolls.
	wrapped := tvt_layout('| a | b |\n|---|---|\n| ' + 'word '.repeat(20) + '| x |', 260)
	assert wrapped.items.filter(it.kind == .container).len == 0
	assert tvt_texts(wrapped).filter(it.text.contains('word')).len > 1
	mut heads := []string{}
	mut values := []string{}
	for k in 0 .. 8 {
		heads << 'column${k}'
		values << 'value${k}'
	}
	wide := tvt_layout('| ' + heads.join(' | ') + ' |\n|' + '---|'.repeat(8) + '\n| ' +
		values.join(' | ') + ' |', 200)
	assert wide.items.filter(it.kind == .container).len == 1
}

fn test_textview_layout_images() {
	doc := tvt_md('![remote](https://x.org/a.png)\n\n![local](pic.png)\n\ntext ![inline](i.png) text')
	lay := text_view_layout(doc, width: 200)
	images := lay.items.filter(it.kind == .image)
	assert images.len == 3
	assert images[0].path == '' && images[0].alt == 'remote'
	assert images[1].path == 'pic.png'
	// The default size is scaled down to the width.
	assert images[0].frame.width == 200
	assert images[0].frame.height == math.round(200.0 * 200 / 360)
	resolved := text_view_layout(doc,
		width:  400
		images: fn (src string, alt string) TextViewImage {
			return TextViewImage{
				path:   '/abs/' + src
				width:  50
				height: 25
			}
		}
	)
	sized := resolved.items.filter(it.kind == .image)
	assert sized[0].path == '/abs/https://x.org/a.png'
	assert sized[1].frame.width == 50 && sized[1].frame.height == 25
	assert tv_default_image_path('file:///tmp/a.png') == '/tmp/a.png'
	assert tv_default_image_path('data:image/png;base64,xx') == ''
}

fn test_textview_layout_plugin_blocks() {
	plugin := TextViewBlockPlugin{
		name:   'chart'
		height: fn (block TextViewPluginBlock) f64 {
			return block.code.split_into_lines().len * 20.0
		}
	}
	lay := text_view_layout(tvt_md('```chart\na 1\nb 2\nc 3\n```\n\n```Chart\nx\n```\n\n```v\ncode\n```'),
		width:   300
		plugins: [plugin]
	)
	plugins := lay.items.filter(it.kind == .plugin)
	assert plugins.len == 2
	assert plugins[0].frame.height == 60
	assert plugins[0].block == 0 && plugins[1].block == 1
	assert lay.items.filter(it.kind == .code_header).len == 1
}

fn test_textview_layout_frontmatter() {
	doc := text_view_parse_markdown('---\ntitle: Hello\nauthor: Someone\n---\ntext',
		frontmatter: true
	)
	lay := text_view_layout(doc, width: 400)
	texts := tvt_texts(lay)
	assert texts.map(it.text)[..4] == ['title', 'Hello', 'author', 'Someone']
	assert texts[0].role == .muted && texts[0].bold
	assert texts[1].text_x > texts[0].text_x + texts[0].advance
	assert lay.items[0].kind == .fill && lay.items[0].role == .code_background
}

fn test_textview_layout_clamp() {
	source := 'one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen'
	full := tvt_layout(source, 150)
	assert !full.clamped
	assert full.lines.len > 3
	lay := text_view_layout(tvt_md(source), width: 150, max_lines: 2)
	assert lay.clamped
	assert lay.lines.len == 2
	assert lay.height < full.height
	assert lay.height == math.ceil(lay.lines[1].frame.y + lay.lines[1].frame.height)
	last := tvt_texts(lay).last()
	assert last.ellipsis && last.text.ends_with('…')
	assert last.rendered_end <= last.rendered_start + last.text.len - '…'.len
	assert last.text_x + last.advance <= 150.5
	fits := text_view_layout(tvt_md('short'), width: 150, max_lines: 2)
	assert !fits.clamped
	// Lines side by side count once; boxes are cut at the last line.
	code := text_view_layout(tvt_md('```\n1\n2\n3\n4\n5\n```'), width: 300, max_lines: 2)
	assert code.clamped
	for item in code.items {
		assert item.frame.y + item.frame.height <= code.height + 0.5
	}
}

fn test_textview_range_rect_and_reveal() {
	lay := tvt_layout('# Title\n\nfirst paragraph\n\nsecond paragraph with more words in it', 1000)
	doc := lay.document
	start := doc.text.index('second') or { panic('missing') }
	r := lay.range_rect(start, start + 6) or { panic('no rect') }
	assert r.y > 0
	second := lay.lines.filter(it.rendered_start <= start && start < it.rendered_end)[0]
	assert r == second.frame
	// A position in the break between blocks reveals the next line.
	// A range starting in the break between blocks reveals the next line; an
	// empty range there, the line it ends.
	gap := doc.text.index('\nsecond') or { panic('missing') }
	assert lay.range_rect(gap, gap + 3) or { panic('none') } == second.frame
	first := lay.lines.filter(it.rendered_end == gap)[0]
	assert lay.range_rect(gap, gap) or { panic('none') } == first.frame
	if _ := lay.range_rect(5, 2) {
		assert false, 'reversed range'
	}
	// Already visible: no scroll. Below the viewport: scroll down to it.
	assert text_view_reveal_offset(lay, start, start + 6, 0, 1000, 0) == none
	down := text_view_reveal_offset(lay, start, start + 6, 500, 200, 0) or { panic('none') }
	assert down > 0
	assert down <= 500 + r.y
	up := text_view_reveal_offset(lay, 0, 1, 0, 50, 300) or { panic('none') }
	assert up == 0
}

fn test_textview_cache() {
	mut calls := &TvtCounter{}
	doc := tvt_md('![x](a.png)')
	config := TextViewLayoutConfig{
		width:  300
		images: fn [mut calls] (src string, alt string) TextViewImage {
			calls.n++
			return TextViewImage{}
		}
	}
	mut cache := TextViewCache{}
	first := cache.layout(doc, config)
	again := cache.layout(doc, config)
	assert calls.n == 1
	assert first.height == again.height
	_ := cache.layout(doc, TextViewLayoutConfig{ ...config, width: 200 })
	assert calls.n == 2
	_ := cache.layout(tvt_md('![y](a.png)'), TextViewLayoutConfig{ ...config, width: 200 })
	assert calls.n == 3
	cache.clear()
	_ := cache.layout(tvt_md('![y](a.png)'), TextViewLayoutConfig{ ...config, width: 200 })
	assert calls.n == 4
}

@[heap]
struct TvtCounter {
mut:
	n int
}

fn test_textview_measuring_helpers() {
	style := TextStyle{
		size: 14
	}
	// Without a window, measuring estimates and labels have no inset.
	assert tv_label_inset(style) == 0
	assert tv_space_width(style) > 0
	assert tv_advance('', style) == 0
	assert math.abs(tv_advance(' ab ', style) - (tv_advance('ab', style) + 2 * tv_space_width(style))) < 0.001
	assert tv_advance('   ', style) == 3 * tv_space_width(style)
	assert tv_display('a\tb') == 'a    b'
}

// ── Building ────────────────────────────────────────────────────────

fn test_textview_builds_valid_tree() {
	el := rich_text_view(
		id:       'doc'
		frame:    rect(0, 0, 400, 600)
		markdown: '# Hi\n\nSome *text* with a [link](https://x.org) and `code`.\n\n```v\nfn main() {}\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- [x] done\n\n![pic](p.png)'
	) or { panic(err) }
	validate_element_tree(el) or { panic(err) }
	assert el.id == 'doc'
	assert el.accessibility_role == 'group'
	labels := tvt_all(el).filter(it.kind == .label)
	assert labels.any(it.text == 'Hi')
	assert labels.all(it.text_style.lines == 1)
	assert tvt_all(el).any(it.kind == .image && it.image_path == 'p.png')
	assert tvt_all(el).any(it.accessibility_role == 'checkbox' && it.accessibility_value == 'checked')
	if _ := rich_text_view(markdown: 'x', frame: rect(0, 0, 10, 10)) {
		assert false, 'id required'
	}
	if _ := rich_text_view(id: 'x', frame: rect(0, 0, -1, 10)) {
		assert false, 'negative frame accepted'
	}
}

fn test_textview_html_and_layout_sources() {
	html_el := rich_text_view(id: 'h', frame: rect(0, 0, 300, 100), html: '<p><b>bold</b></p>') or {
		panic(err)
	}
	assert tvt_all(html_el).any(it.kind == .label && it.text == 'bold' && it.text_style.bold)
	doc := tvt_md('from document')
	from_doc := rich_text_view(
		id:       'd'
		frame:    rect(0, 0, 300, 100)
		document: doc
		markdown: 'ignored'
	) or {
		panic(err)
	}
	assert tvt_all(from_doc).any(it.text == 'from document')
	lay := text_view_layout(tvt_md('from layout'), width: 300)
	assert text_view_config_layout(TextViewConfig{
		layout: lay
		html:   '<p>x</p>'
	}).height == lay.height
	from_layout := rich_text_view(id: 'l', frame: rect(0, 0, 300, 100), layout: lay) or {
		panic(err)
	}
	assert tvt_all(from_layout).any(it.text == 'from layout')
}

fn test_textview_links_emit_decodable_actions() {
	doc := tvt_md('Go [to the docs](https://docs.example) or [![img](i.png)](https://img.example).')
	el := rich_text_view(id: 'tv', frame: rect(0, 0, 120, 300), document: doc) or { panic(err) }
	links := tvt_all(el).filter(it.accessibility_role == 'link')
	// The link text wraps onto two lines, one target per line, plus the image.
	assert links.len >= 3
	for l in links {
		assert l.button_behavior
		assert l.cursor == cursor_pointing_hand
	}
	text_links := links.filter(it.action_id == component_part_id('tv', 'link:0'))
	assert text_links.len >= 2
	assert text_links[0].tooltip == 'https://docs.example'
	assert text_links.all(it.children.all(it.kind == .label && it.text_style.underline))
	assert text_view_link_from_action('tv', doc, component_part_id('tv', 'link:0')) or { '' } == 'https://docs.example'
	image_link := links.filter(it.action_id == component_part_id('tv', 'link:1'))
	assert image_link.len == 1 && image_link[0].children[0].kind == .image
	assert text_view_link_from_action('tv', doc, component_part_id('tv', 'link:1')) or { '' } == 'https://img.example'
	for forged in [component_part_id('tv', 'link:2'), component_part_id('tv', 'link:01'),
		component_part_id('tv', 'link:'), component_part_id('tv', 'link:-1'),
		component_part_id('other', 'link:0'), 'tv', component_part_id('tv', 'code:0:copy')] {
		assert text_view_link_from_action('tv', doc, forged) == none, forged
	}
}

fn test_textview_code_block_actions() {
	doc := tvt_md('```v\nprintln(1)\n```\n\n```sh\nls\n```')
	actions := [
		TextViewCodeAction{
			id:    'run'
			title: 'Run'
			langs: ['V']
		},
		TextViewCodeAction{
			id:     'explain'
			symbol: 'info.circle'
		},
	]
	el := rich_text_view(
		id:            'tv'
		frame:         rect(0, 0, 400, 300)
		document:      doc
		code_actions:  actions
		copied_blocks: [1]
	) or { panic(err) }
	copy0 := tvt_by_id(el, component_part_id('tv', 'code:0:copy')) or { panic('no copy button') }
	assert copy0.button_behavior && copy0.enabled
	assert copy0.accessibility_value == ''
	copy1 := tvt_by_id(el, component_part_id('tv', 'code:1:copy')) or { panic('no copy button') }
	assert copy1.accessibility_value == 'Copied'
	assert copy1.children[0].image_path == 'symbol:checkmark'
	// Run applies to the v block only; explain to both.
	assert tvt_by_id(el, component_part_id('tv', 'code:0:action:0')) != none
	assert tvt_by_id(el, component_part_id('tv', 'code:1:action:0')) == none
	assert tvt_by_id(el, component_part_id('tv', 'code:1:action:1')) != none
	copy_event := text_view_event_from_action('tv', doc, actions, component_part_id('tv', 'code:0:copy')) or {
		panic('no event')
	}
	assert copy_event.kind == .copy_code && copy_event.block == 0
	assert copy_event.code == 'println(1)' && copy_event.lang == 'v'
	run := text_view_event_from_action('tv', doc, actions, component_part_id('tv', 'code:0:action:0')) or {
		panic('no event')
	}
	assert run.kind == .code_action && run.action == 'run' && run.code == 'println(1)'
	for forged in ['code:1:action:0', 'code:0:action:2', 'code:2:copy', 'code:00:copy', 'code:0:paste',
		'code:0', 'code:x:copy'] {
		assert text_view_event_from_action('tv', doc, actions, component_part_id('tv', forged)) == none, forged
	}
	// Without a clipboard the copy button is disabled.
	off := rich_text_view(id: 'tv', frame: rect(0, 0, 400, 300), document: doc, clipboard: false) or {
		panic(err)
	}
	copy_off := tvt_by_id(off, component_part_id('tv', 'code:0:copy')) or { panic('no copy') }
	assert !copy_off.enabled
	assert text_view_copy_from_action('tv', doc, component_part_id('tv', 'link:0')) == none
}

fn test_textview_highlights() {
	doc := tvt_md('find me, find me again')
	matches := text_view_find(doc, 'find')
	assert matches == [0, 9]
	assert text_view_find(doc, '') == []
	colors := text_view_colors(component_theme(false))
	highlights := [TextViewHighlight{
		start: 0
		end:   4
	}, TextViewHighlight{
		start:   9
		end:     13
		current: true
	}, TextViewHighlight{
		start: 5
		end:   7
		color: 0x123456
	}]
	text_view_check_highlights(doc, highlights) or { panic(err) }
	el := rich_text_view(
		id:         'tv'
		frame:      rect(0, 0, 600, 100)
		document:   doc
		highlights: highlights
	) or {
		panic(err)
	}
	boxes := tvt_all(el).filter(it.kind == .view
		&& it.box.bg in [colors.highlight, colors.highlight_current, u32(0x123456)])
	assert boxes.len == 3
	assert boxes.filter(it.box.bg == colors.highlight_current).len == 1
	// Highlights paint behind the text: before the first label among siblings.
	first_label := el.children.map(it.kind).index(.label)
	first_mark := el.children.map(it.box.bg).index(colors.highlight)
	assert first_mark < first_label
	// The marks span the matched glyphs.
	label_el := el.children.filter(it.kind == .label)[0]
	assert math.abs(boxes[0].frame.x - label_el.frame.x) < 1
	bad := [TextViewHighlight{
		start: 3
		end:   1
	}]
	if _ := text_view_check_highlights(doc, bad) {
		assert false, 'reversed range accepted'
	}
	none_drawn := rich_text_view(
		id:         'tv'
		frame:      rect(0, 0, 600, 100)
		document:   doc
		highlights: [highlights[0], bad[0]]
	) or { panic(err) }
	assert !tvt_all(none_drawn).any(it.box.bg == colors.highlight)
}

fn test_textview_stream_chunks_helper() {
	mut chunks := text_view_stream_chunks([], 0, 1000)
	chunks = text_view_stream_chunks(chunks, 5, 1100)
	chunks = text_view_stream_chunks(chunks, 9, 1200)
	assert chunks.map(it.start) == [0, 5, 9]
	// Old chunks are forgotten; a start before them means the text was replaced.
	later := text_view_stream_chunks(chunks, 12, 1000 + 2500)
	assert later.map(it.start) == [12]
	replaced := text_view_stream_chunks(chunks, 3, 1300)
	assert replaced.map(it.start) == [0, 3]
}

fn test_textview_streamed_text_fades_in() {
	reset_widget_animations()
	defer {
		reset_widget_animations()
	}
	first := 'Hello **wor'
	source := first + 'ld** and more words'
	doc := tvt_md(source)
	chunks := [TextViewChunk{
		start: first.len
		at:    50_000
	}]
	el := rich_text_view(
		id:       'fade'
		frame:    rect(0, 0, 600, 100)
		document: doc
		stream:   chunks
		now:      50_010
	) or { panic(err) }
	faded := tvt_all(el).filter(it.kind == .label && it.id.starts_with(component_part_id('fade',
		'fade:')))
	// The bold word splits where the chunk starts: `wor` stays, `ld` fades.
	assert faded.map(it.text) == ['ld', 'and more words']
	plain := tvt_all(el).filter(it.kind == .label && it.id == '').map(it.text)
	assert plain == ['Hello', 'wor']
	for f in faded {
		assert animation_info(f.id).status == .running
	}
	// The split pieces meet where the word was split.
	wor := tvt_all(el).filter(it.text == 'wor')[0]
	ld := faded[0]
	assert math.abs(ld.frame.x - (wor.frame.x + tv_advance('wor', TextStyle{
		size: wor.text_style.size
		bold: true
	}))) < 0.5
	// Once the chunk is old and done, its labels merge again and the
	// animation state is released.
	for f in faded {
		cancel_animation(f.id)
	}
	later := rich_text_view(
		id:       'fade'
		frame:    rect(0, 0, 600, 100)
		document: doc
		stream:   chunks
		now:      60_000
	) or { panic(err) }
	assert !tvt_all(later).any(it.id.starts_with(component_part_id('fade', 'fade:')))
	assert tvt_all(later).any(it.text == 'world')
	for f in faded {
		assert animation_info(f.id).status == .idle
	}
	// Reduced motion shows everything at once.
	still := rich_text_view(
		id:            'fade'
		frame:         rect(0, 0, 600, 100)
		document:      doc
		stream:        chunks
		now:           50_010
		reduce_motion: true
	) or { panic(err) }
	assert !tvt_all(still).any(it.id.len > 0 && it.kind == .label)
}

fn test_textview_scrollable_fill_and_colors() {
	lay := tvt_layout('one\n\ntwo\n\nthree\n\nfour', 200)
	el := rich_text_view(
		id:         'tv'
		frame:      rect(10, 20, 200, 40)
		layout:     lay
		scrollable: true
		fill:       true
		radius:     8
		theme:      component_theme(true)
	) or { panic(err) }
	assert el.frame == rect(10, 20, 200, 40)
	assert el.box.bg == component_theme(true).background && el.box.radius == 8
	assert el.children.len == 1
	scroller := el.children[0]
	assert scroller.kind == .scroll && scroller.id == text_view_scroll_id('tv')
	// The content is as tall as the layout.
	mut bottom := 0.0
	for child in scroller.children {
		bottom = math.max(bottom, child.frame.y + child.frame.height)
	}
	assert bottom >= lay.height
	surface := text_view_surface_colors(0x2563eb, 0xffffff)
	assert surface.link == 0xffffff
	assert surface.code_background != surface.background
	assert surface.role_color(.code_background) == surface.code_background
	assert surface.role_color(.muted) == surface.muted
	assert tv_mix(0xffffff, 0x000000, 0.5) == 0x808080
	assert tv_mix(0x123456, 0x000000, 1) == 0x123456
	light := text_view_colors(component_theme(false))
	dark := text_view_colors(component_theme(true))
	assert light.highlight_current == component_theme(false).warning
	assert dark.highlight_current != component_theme(true).warning
}

fn test_textview_plugin_render_and_placeholder() {
	el := rich_text_view(
		id:       'tv'
		frame:    rect(0, 0, 300, 400)
		markdown: '```chart\na 1\n```\n\n![missing](https://x.org/p.png)'
		plugins:  [
			TextViewBlockPlugin{
				name:   'chart'
				height: fn (_ TextViewPluginBlock) f64 {
					return 80
				}
				render: fn (block TextViewPluginBlock, frame Rect) Element {
					return label('', 'chart:' + block.code, frame, TextStyle{})
				}
			},
		]
	) or { panic(err) }
	holder := tvt_by_id(el, component_part_id('tv', 'plugin:0')) or { panic('no plugin') }
	assert holder.frame.height == 80
	assert holder.children[0].text == 'chart:a 1'
	assert holder.children[0].frame == rect(0, 0, 300, 80)
	placeholder := tvt_all(el).filter(it.accessibility_role == 'img')
	assert placeholder.len == 1
	assert placeholder[0].kind == .view
	assert placeholder[0].children.any(it.kind == .label && it.text == 'missing')
}

fn test_textview_clamped_view_shows_ellipsis() {
	el := rich_text_view(
		id:        'tv'
		frame:     rect(0, 0, 160, 60)
		markdown:  'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu'
		max_lines: 2
	) or { panic(err) }
	labels := tvt_all(el).filter(it.kind == .label)
	assert labels.last().text.ends_with('…')
	lay := text_view_config_layout(TextViewConfig{
		frame:     rect(0, 0, 160, 60)
		markdown:  'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu'
		max_lines: 2
	})
	assert lay.clamped
}

fn test_textview_deep_nesting_is_bounded() {
	// Hostile nesting is cut off instead of recursing without bound.
	quotes := tvt_md('> '.repeat(2000) + 'deep')
	mut depth := 0
	mut n := quotes.root
	for n.children.len > 0 && n.children[0].kind == .blockquote {
		n = n.children[0]
		depth++
	}
	assert depth <= tvmd_max_depth
	html := text_view_html('<b>'.repeat(2000) + 'x')
	assert html.text == 'x'
	emphasis := tvt_md('*a '.repeat(2000) + 'b*'.repeat(2000))
	assert emphasis.text.len > 0
	_ := text_view_layout(text_view_html('<ul><li>'.repeat(1000) + 'x'), width: 300)
	_ := text_view_layout(tvt_md('- '.repeat(1000) + 'x'), width: 300)
	_ := tvt_md('!['.repeat(1000) + 'x' + '](u)'.repeat(1000))
	assert tvt_md('*'.repeat(100) + 'a' + '*'.repeat(100)).text == '*'.repeat(100) + 'a' + '*'.repeat(100)
}

fn test_textview_empty_documents() {
	for doc in [tvt_md(''), tvt_md('\n\n   \n'), text_view_html(''), text_view_html('<p> </p>')] {
		assert doc.text == ''
		lay := text_view_layout(doc, width: 300)
		assert lay.height == 0 && lay.items.len == 0
		el := rich_text_view(id: 'e', frame: rect(0, 0, 300, 0), layout: lay) or { panic(err) }
		assert el.children.len == 0
	}
}
