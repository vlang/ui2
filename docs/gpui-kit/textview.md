# TextView: Markdown and HTML

Port of GPUI Kit's [TextView](https://github.com/longbridge/gpui-kit/blob/main/website/component/text-view.md)
page, compared with GPUI Kit `main` at `d4c56812984d5fb2640ed922fe230c3113479563`.
The gallery is `examples/gpui_textview`; tests are in `ui/component_textview_test.v`.

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `markdown`, `TextView::markdown`, `MarkdownExtensions` | `text_view_markdown`, `text_view_parse_markdown`, `TextViewMarkdownOptions` | `ui/component_textview_markdown.v`, `ui/component_textview_inline.v` |
| `TextView::html` | `text_view_html` | `ui/component_textview_html.v` |
| Parsed document, `rendered_text`, `range_for_source` | `TextViewDocument`, `TextViewNode` | `ui/component_textview_node.v` |
| Layout, `max_lines`, `is_clamped`, `reveal_range` | `text_view_layout`, `TextViewLayout`, `TextViewCache`, `range_rect`, `text_view_reveal_offset` | `ui/component_textview_layout.v` |
| `TextView` element, styles, links, code block actions, highlights, stream fade | `rich_text_view(TextViewConfig)`, `text_view_event_from_action` and friends | `ui/component_textview.v` |

Everything is a new V implementation. No GPUI Kit code was translated: the
Markdown and HTML parsers, the layout engine and the fade are written for ui2.

The builder is called `rich_text_view`, not `text_view`, because `text_view` is
a local variable name in the AppKit backend and a function of that name would
make it shadow one (next to `rich_text_area`, the name also says what it is).

## How it works

Parsing, layout and building are separate steps, so an application can parse
a document once, lay it out once per width, and build every frame cheaply:

```v
doc := ui2.text_view_markdown(source) // or text_view_html(source)
lay := ui2.text_view_layout(doc, width: 520) // lay.height sizes the view
el := ui2.rich_text_view(id: 'doc', frame: ui2.rect(20, 20, 520, lay.height), layout: lay)!
```

`rich_text_view` also takes `markdown:`, `html:` or `document:` and lays the
content out itself, for small or one-off content. `text_view_config_layout(config)`
returns the layout it would make, so the frame can be sized from it.

A label has one style, so rich text is one label per styled run per line. The
layout breaks inline content into words, measures them with
`measure_text_width`, fills lines, then measures each line's runs as whole
strings and places them end to end. Backends draw labels with an inset
(NSTextField two points a side, the others none); the inset is measured by
comparing `n` with `nn` and taken back out, so neighbouring labels meet exactly
on every backend. Runs of different fonts on a line (inline code in a
monospace face, headings) share a baseline: labels centre their text, and the
offset of each font's baseline from that centre was measured on AppKit and
computed from the bundled Roboto faces for the custom renderer. In the custom
renderer, which truncates text positions to whole points, label positions are
rounded so runs are off by half a point at most.

The layout depends on measurement, so it is exact only once a window runs.
`TextViewCache` remembers the last layout and makes a new one when the
document, width, size, line budget, style or measurement exactness changes:

```v
@[heap]
struct App {
mut:
	doc   ui2.TextViewDocument
	cache ui2.TextViewCache
}

fn build() ui2.Element {
	mut app := unsafe { state }
	lay := app.cache.layout(app.doc, width: 520)
	return ui2.screen(0xffffff, [
		ui2.rich_text_view(id: 'doc', frame: ui2.rect(0, 0, 520, 600), layout: lay, scrollable: true) or {
			panic(err)
		},
	])
}
```

Call `cache.clear()` after changing plugins or the image resolver; their
functions cannot be compared.

## API

| Item | Purpose |
| --- | --- |
| `text_view_markdown(source)`, `text_view_parse_markdown(source, options)` | Parse Markdown. `TextViewMarkdownOptions{frontmatter, html}`: YAML front matter (off, as upstream) and raw HTML (on) |
| `text_view_html(source)` | Parse HTML |
| `TextViewDocument` | `root` node tree, `source`, `html`, `text` (rendered text), `spans` (rendered-to-source map), `links`, `code_blocks` |
| `doc.rendered_text()`, `doc.range_for_source(start, end) ?TextViewRange`, `doc.rendered_offset_for_source(offset)` | Rendered text and conversions from source offsets |
| `TextViewNode`, `TextViewNodeKind` | Public tree: document, paragraph, heading, blockquote, list, list_item, code_block, thematic_break, table, table_row, table_cell, html_block, frontmatter; text, emphasis, strong, strikethrough, code_span, link, image, soft_break, hard_break. Fields: `level`, `ordered`, `start`, `tight`, `task`, `fenced`, `lang`, `info`, `url`, `title`, `align`, `header`, `width`/`height`, `entries`, `index`, source and rendered ranges |
| `text_view_layout(doc, TextViewLayoutConfig)` | Lay out for `width` with `style`, `size`, `max_lines`, `plugins`, `images`, `code_header` |
| `TextViewLayout` | `height`, `clamped`, `items`, `lines`, `document`, resolved `style`; `range_rect(start, end) ?Rect` |
| `TextViewCache` | `cache.layout(doc, config)`, `cache.clear()` |
| `TextViewStyle` | `font_size` (0: the size's), `font_family`, `code_family`, `code_scale`, `line_height`, `block_gap`, `heading_scales`, `padding`, `image_width`/`image_height`, `wrap_code` |
| `rich_text_view(TextViewConfig) !Element` | Build the view |
| `TextViewConfig` | `id`, `frame`; content (`layout`, `document`, `html`, `markdown`, `markdown_options`); layout settings; `theme`, `colors`, `fill`, `radius`; `scrollable`; `highlights`; `stream`, `fade_duration`, `reduce_motion`, `now`; `code_actions`, `copied_blocks`, `clipboard`; `accessibility_label` |
| `text_view_colors(theme)`, `text_view_surface_colors(background, foreground)`, `TextViewColors` | Colors from a theme, or derived from a colored surface |
| `text_view_event_from_action(id, doc, code_actions, action) ?TextViewEvent` | Decode a link, copy or code action click |
| `text_view_link_from_action(id, doc, action) ?string` | The URL of a clicked link or linked image |
| `text_view_copy_from_action(id, doc, action) ?int` | Copy a code block to the clipboard; returns its index |
| `TextViewHighlight`, `text_view_check_highlights(doc, highlights) !`, `text_view_find(doc, query)` | Range highlights and a search helper |
| `text_view_reveal_offset(layout, start, end, top, viewport, offset) ?f64` | The scroll offset that shows a range, or none when it is visible |
| `TextViewChunk`, `text_view_stream_chunks(chunks, start, now)`, `text_view_fade_duration` | Streaming fade |
| `TextViewBlockPlugin`, `TextViewPluginBlock` | Fenced blocks the application renders |
| `TextViewImage`, `TextViewImageFn` | Image sources to paths and sizes |
| `TextViewCodeAction` | Buttons in code block headers |
| `text_view_scroll_id(id)` | The scroll element of a `scrollable` view |
| `text_view_heading_scale(style, level)`, `text_view_valid_range(text, start, end)` | Helpers |

## Rendered text and offsets

`doc.text` (GPUI Kit's `rendered_text()`) is what plain copy produces:
`hello **world**` reads `hello world`, escapes and entities are resolved, and
heading and list markers, table pipes and fences are left out. Blocks are
separated by `\n`, table cells by `\t`, a soft line break reads as a space and
a hard one as `\n`. Images, rules and markers render nothing; a front matter
entry reads `key\tvalue`.

Offsets are UTF-8 byte offsets of that text. Highlights and reveals use them,
so `text.index(query)` results can be passed as they are. An application that
keeps ranges of the Markdown source converts them with
`doc.range_for_source(start, end)`, which returns the smallest rendered range
holding every character rendered from the source range: `**bold**` and `bold`
convert to the same range, part of `&amp;` gives the whole `&`. HTML documents
map too (more coarsely where whitespace collapsed); upstream does not support
them there.

## Examples

### Markdown and HTML

```v
md := ui2.rich_text_view(id: 'readme', frame: ui2.rect(0, 0, 480, 400), markdown: '# Hello\n\nThis is **Markdown**.', scrollable: true)!
page := ui2.rich_text_view(id: 'page', frame: ui2.rect(0, 0, 480, 200), html: '<strong>Hello</strong>')!
```

### Inside a colored surface

`text_view_surface_colors(background, foreground)` derives links (the text
color, underlined), muted text, code, table and border tints from a surface's
two colors, as upstream does inside a filled `Bubble`:

```v
bg, fg := theme.colors(.primary)
ui2.view('', bubble, ui2.BoxStyle{ bg: bg, radius: 14 }, [
	ui2.rich_text_view(id: 'reply', frame: inner, layout: lay, colors: ui2.text_view_surface_colors(bg, fg))!,
])
```

### Clamp to a number of lines

```v
lay := ui2.text_view_layout(doc, width: 480, max_lines: 3)
if lay.clamped {
	// offer "Show more"
}
```

The first `max_lines` lines are kept; lines side by side (a table row's cells,
a list marker and its text) count once. A line is never cut in half, boxes
reaching past the last line (code blocks, quote bars, table grids) are cut at
it, and the last line kept ends in an ellipsis (words are dropped to make room
for it). `height` is the clamped height. Upstream counts a height budget of
`n` body lines instead; counting lines gives the same result for body text
and a predictable one around headings and code.

### Fade in streamed text

The application appends to its source and records where each chunk began:

```v
app.chunks = ui2.text_view_stream_chunks(app.chunks, app.reply.len, time.ticks())
app.reply += next_word
app.doc = ui2.text_view_markdown(app.reply)
// build: ui2.rich_text_view(..., document: app.doc, stream: app.chunks)
```

Each chunk's text fades from the background to its color over
`fade_duration` (350 ms, out-cubic) through the widget animation system, so
consecutive chunks overlap into a gradient tail. Chunks are source offsets:
Markdown that completes as it streams (`**bo` becoming **bold**) fades only
the new letters, because the old ones came from source before the chunk. Code
blocks and table cells fade the same way. Replacing the text (start again from
an empty chunk list) shows it at once, and so does `reduce_motion: true`.
Nothing animates without `stream`. The fading labels get ids, and their
animation state is released once their chunk is done.

### Highlight ranges and scroll to a range

```v
matches := ui2.text_view_find(doc, query)
highlights := matches.map(ui2.TextViewHighlight{ start: it, end: it + query.len, current: it == matches[current] })
// rich_text_view(..., highlights: highlights)
if offset := ui2.text_view_reveal_offset(lay, start, end, 0, viewport_height, ui2.scroll_offset(ui2.text_view_scroll_id('doc'))) {
	ui2.scroll_to_offset(ui2.text_view_scroll_id('doc'), offset)
}
```

Highlights paint behind the text and over code backgrounds; later ones paint
over earlier ones. A color of 0 takes `colors.highlight`, or
`highlight_current` with `current: true`. The break between blocks and between
table cells is not painted. A set with a reversed, out-of-bounds or
mid-character range is rejected whole: `text_view_check_highlights` reports
it and the view draws none of them.

`layout.range_rect(start, end)` is the line a range starts on (an empty range
gives the line of its position, a range starting in a block break the next
line). `text_view_reveal_offset` turns it into a scroll offset, leaving the
view where it is when the line is visible, for a `scrollable` view or any
`scroll` the application owns (`top` is where the view sits in its content).

### Links

Links never open anything themselves. Each link (text or linked image) is a
button-behavior view with the link role, a pointing-hand cursor and the URL as
its tooltip, emitting `<id>:component:link:<n>`:

```v
fn on_event(event string) {
	if url := ui2.text_view_link_from_action('doc', app.doc, event) {
		// Route it: open a browser, navigate inside the app, ...
		// ui2.key_modifiers() tells a Cmd-click from a plain one.
	}
}
```

### Code block actions

Code blocks get a header with their language and a copy button. Application
actions are added with `code_actions`, optionally limited to languages:

```v
actions := [ui2.TextViewCodeAction{ id: 'run', title: 'Run', symbol: 'play.fill', langs: ['v'] }]
// rich_text_view(..., code_actions: actions, copied_blocks: copied, clipboard: ui2.clipboard_supported())
if e := ui2.text_view_event_from_action('doc', app.doc, actions, event) {
	match e.kind {
		.copy_code { ui2.set_clipboard_text(e.code) } // or text_view_copy_from_action
		.code_action { run(e.code) } // e.action == 'run'
		.link { open(e.url) }
	}
}
```

`copied_blocks` shows a check mark on blocks just copied (keep them for a
moment with `ClipboardFeedback` or a timer). Without a clipboard the copy
button is disabled. Long lines scroll sideways inside the block
(`scroll_with_mode(.horizontal_only)`), or wrap with `TextViewStyle.wrap_code`.

### Block plugins

```v
chart := ui2.TextViewBlockPlugin{
	name:   'chart'
	height: fn (b ui2.TextViewPluginBlock) f64 { return 150 }
	render: fn (b ui2.TextViewPluginBlock, frame ui2.Rect) ui2.Element { return draw_chart(b.code, frame) }
}
// ```chart fenced blocks now render through it (layout config and view config both take plugins)
```

### Images

`![alt](src)` and `<img src>` render as `image` elements. Without a resolver,
paths (and `file://` URLs) load as they are and `http(s)://` and `data:` URLs
draw a placeholder with the alt text: the view never fetches anything. A
`TextViewImageFn` maps sources to paths and sizes; HTML `width`/`height`
attributes are used otherwise, then `TextViewStyle.image_width`/`image_height`.
Images wider than the text are scaled down. A paragraph that is only an image
lays it out as a block; images among text sit on the baseline.

## Markdown and HTML support

Markdown: ATX and setext headings, paragraphs with soft and hard breaks, block
quotes with lazy continuation, bullet and ordered lists (start numbers, tight
and loose, nesting, GFM task items), fenced (backtick and tilde, info string)
and indented code, thematic breaks, GFM tables with alignment and escaped
pipes, HTML blocks (parsed by the HTML parser), link reference definitions;
inline emphasis, strong and strikethrough by CommonMark's delimiter rules,
code spans, inline/reference/collapsed/shortcut links, images, `<...>`
autolinks and GFM bare `https://`/`www.` links, backslash escapes, entities,
and inline `b`/`strong`/`i`/`em`/`s`/`del`/`code`/`kbd`/`a`/`br`/`img` tags
(others are dropped, keeping their content). YAML front matter shows
`key: value` pairs (plain values, `|-` and `>-` block scalars) as a key/value
box; anything else YAML can say falls back to a YAML code block, as upstream.
It is a display-oriented subset, not a conformance-tested CommonMark parser.

HTML: p, h1–h6, b/strong, i/em, s/del/strike, code/kbd/samp, pre (with
`language-*` classes), a, ul/ol (start) /li (checkbox inputs become tasks),
blockquote, br, hr, img, table/thead/tbody/tfoot/tr/th/td (align attribute or
`text-align` style), dl/dt/dd, and transparent span, div, section and the like.
Paragraphs, list items and cells close when the next starts, stray end tags
are ignored, unknown elements keep their content, script and style are
dropped, entities are decoded and whitespace collapses outside `pre`.

## Upstream features

| Upstream | Status |
| --- | --- |
| Markdown and HTML rendering, stable id | Implemented |
| Inside a colored surface | Implemented: `text_view_surface_colors` (ui2 has no inherited text color, so the application passes the surface's colors) |
| `max_lines`, `is_clamped` | Implemented as a line count; `layout.clamped` |
| Fade in streamed text, reduced motion | Implemented with chunks of source; `TextViewMotion`'s word-by-word stagger and custom easing are not (`fade_duration` only) |
| Range highlights, `rendered_text`, `range_for_source` | Implemented, HTML included |
| `reveal_range`, `on_reveal` | `range_rect` and `text_view_reveal_offset` return the place or offset; the application scrolls, as ui2 components cannot scroll by themselves. Reveal requests are not queued or carried across content changes |
| Link click handling | Implemented as actions; there is no default URL opening |
| Images (`http`, `data:`, URIs, `ImageCache`) | Paths load; remote and data URLs need the application's resolver (`TextViewImageFn`), which is the `ImageCache` counterpart |
| Markdown plugins | Block plugins for fenced code blocks of a language; the general parse hook and inline plugins are omitted (no parser AST is exposed for plugins to match) |
| YAML front matter | Built in behind `TextViewMarkdownOptions.frontmatter` instead of a plugin |
| Code block actions | Copy button plus application actions per language |
| `scrollable` | Implemented |
| Text selection, copy from a selection, touch selection handles and menu | Not possible: labels cannot be selected. Copy is offered for code blocks only |
| Syntax highlighting | Omitted: one label per run would need a highlighter and many more labels; code is drawn in one color |
| Style refinements (`code_block`, `table`, `table_head`, `table_cell`, `inline_code`) | Replaced by `TextViewStyle` metrics and `TextViewColors` |
| Tables scrolling sideways | Columns shrink and wrap down to a minimum, then the table scrolls sideways |
| Footnotes, math, definition lists in Markdown, GitHub alerts | Not supported (shown as text) |

## Notes

- The task list check box is drawn, not a control; its accessibility role is
  `checkbox` with a checked/unchecked value.
- Accessibility: the view is a `group`, links have the `link` role and their
  text as label, images `img` with the alt text, the copy button "Copy code".
