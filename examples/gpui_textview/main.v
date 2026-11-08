module main

import math
import os
import time
import ui2

// GPUI Kit's TextView ported to ui2: a Markdown document (front matter,
// headings, lists, tasks, quotes, code blocks with actions, a table, an image,
// a chart plugin) with search highlights that scroll to the current match, an
// HTML sample, a preview clamped to three lines, and a reply that streams in
// word by word inside a colored bubble, each word fading in.

const demo_margin = 20.0
const demo_left_width = 600.0
const demo_right_x = 640.0
const demo_right_width = 520.0
const demo_doc_top = 104.0

const demo_markdown = "---
title: ui2 TextView
author: The ui2 authors
status: Draft
---

# Rich text in ui2

`rich_text_view` renders **Markdown** and *HTML* with ordinary ui2 elements: one label per styled run, measured so wrapped runs line up. It knows ~~plain text only~~ **bold**, *italic*, ***both***, `inline code`, [links](https://github.com/vlang/ui2) and bare URLs like https://vlang.io.

## Lists

- Parse once with `text_view_markdown`
- Lay out for each width with `text_view_layout`
  - nested items get their own bullets
    - and deeper ones too
- Build the elements with `rich_text_view`

1. Ordered lists keep their numbers
2. Even when an item wraps onto a second line because it is long enough to need one
3. And the numbers stay right-aligned

- [x] Markdown and HTML parsers
- [x] Tables, code blocks and images
- [ ] Text selection (labels cannot be selected)

## Quotes

> Block quotes get a bar and muted text.
> They can span several lines and hold **inline** styles.

## Code

```v
fn main() {
	name := 'ui2'
	println('Hello from \${name}')
}
```

```text
A line too long for the block scrolls sideways instead of wrapping: 0123456789 abcdefghijklmnopqrstuvwxyz
```

## Tables

| Feature | Markdown | HTML | Notes |
|:--|:-:|:-:|--:|
| Headings | yes | yes | levels 1-6 |
| Emphasis | yes | yes | nested |
| Tables | GFM | yes | aligned |
| Images | yes | yes | sized |

## Images and plugins

![The ui2 logo](logo.png)

```chart
Mon 12
Tue 19
Wed 8
Thu 24
Fri 16
```

---

<p>An <b>HTML block</b> inside Markdown goes through the <i>HTML parser</i>.</p>

Search above highlights every match in this text and scrolls to the current one.
"

const demo_html = '<h3>HTML sample</h3>
<p>Parsed by a <b>forgiving</b> parser: <i>unclosed</i> tags, <code>&lt;entities&gt;</code> &amp; <a href="https://example.com">links</a> all work.
<ul><li>First item<li>Second item with <s>strikethrough</s></ul>
<table><tr><th>Key<th align=right>Value<tr><td>alpha<td align=right>1<tr><td>beta<td align=right>22</table>'

const demo_preview = '**Release notes.** This preview is clamped to three lines and ends in an ellipsis. The full text keeps going: it lists the parsers, the layout engine, the streaming fade and the highlights, and explains how links and code block buttons report actions the application decodes. Nothing here is selectable, because labels are not.'

const demo_reply = 'Sure! Here is how **streaming** works: the app appends each word to the source, records a chunk with `text_view_stream_chunks` and parses again, and the new words *fade in* over 350 ms.

- Markdown that completes as it streams, like **bold text**, fades only its new glyphs
- With reduced motion the text shows at once

Replacing the text, as **Restart** does, shows it at once too.'

@[heap]
struct Demo {
mut:
	dark          bool
	doc           ui2.TextViewDocument
	html          ui2.TextViewDocument
	preview       ui2.TextViewDocument
	reply_doc     ui2.TextViewDocument
	doc_cache     ui2.TextViewCache
	html_cache    ui2.TextViewCache
	preview_cache ui2.TextViewCache
	reply_cache   ui2.TextViewCache
	expanded      bool
	query         string = 'text'
	matches       []int
	current       int
	status        string = 'Click a link, copy or run a code block, or search the document.'
	clips         ui2.ClipboardFeedback
	clipboard     bool = true
	logo          string
	words         []string
	shown         int
	reply         string
	chunks        []ui2.TextViewChunk
	timer         ui2.TimerId
}

const demo = &Demo{}

fn demo_logo_path() string {
	candidates := [
		os.join_path(os.dir(@FILE), '..', 'users', 'logo.png'),
		os.join_path(os.home_dir(), '.vmodules', 'ui2', 'examples', 'users', 'logo.png'),
	]
	for path in candidates {
		if os.exists(path) {
			return os.real_path(path)
		}
	}
	return ''
}

fn (app &Demo) theme() ui2.ComponentTheme {
	return ui2.component_theme(app.dark)
}

fn (app &Demo) page_color() u32 {
	return if app.dark { u32(0x0f172a) } else { u32(0xf1f5f9) }
}

fn (app &Demo) code_actions() []ui2.TextViewCodeAction {
	return [
		ui2.TextViewCodeAction{
			id:     'run'
			title:  'Run'
			symbol: 'play.fill'
			langs:  ['v']
		},
	]
}

fn (app &Demo) plugins() []ui2.TextViewBlockPlugin {
	theme := app.theme()
	return [
		ui2.TextViewBlockPlugin{
			name:   'chart'
			height: fn (_ ui2.TextViewPluginBlock) f64 {
				return 150
			}
			render: fn [theme] (block ui2.TextViewPluginBlock, frame ui2.Rect) ui2.Element {
				return demo_chart(block.code, frame, theme)
			}
		},
	]
}

// demo_chart draws a ```chart block of `label value` lines as bars.
fn demo_chart(code string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	mut names := []string{}
	mut values := []f64{}
	for line in code.split_into_lines() {
		parts := line.fields()
		if parts.len == 2 {
			names << parts[0]
			values << parts[1].f64()
		}
	}
	mut top := 1.0
	for v in values {
		top = math.max(top, v)
	}
	mut kids := []ui2.Element{}
	pad := 14.0
	chart_h := frame.height - 2 * pad - 36
	slot := if values.len > 0 { (frame.width - 2 * pad) / f64(values.len) } else { 0.0 }
	bar_w := math.min(48, slot * 0.6)
	small := ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
		align: .center
	}
	for i, v in values {
		h := math.round(chart_h * v / top)
		x := pad + slot * f64(i) + (slot - bar_w) / 2
		y := pad + 18 + chart_h - h
		kids << ui2.view('', ui2.rect(x, y, bar_w, h), ui2.BoxStyle{
			bg:     theme.primary
			radius: 4
		}, []ui2.Element{})
		kids << ui2.label('', '${v:.0}', ui2.rect(x - 10, y - 18, bar_w + 20, 16), small)
		kids << ui2.label('', names[i], ui2.rect(x - 10, pad + 18 + chart_h + 4, bar_w + 20,
			16), small)
	}
	return ui2.view('', frame, ui2.BoxStyle{
		bg:     theme.muted
		radius: 8
	}, kids)
}

fn (app &Demo) images() ui2.TextViewImageFn {
	logo := app.logo
	return fn [logo] (src string, alt string) ui2.TextViewImage {
		if src == 'logo.png' {
			return ui2.TextViewImage{
				path:   logo
				width:  96
				height: 96
			}
		}
		return ui2.TextViewImage{}
	}
}

fn (mut app Demo) search() {
	app.matches = if app.query.len == 0 {
		[]int{}
	} else {
		lower := ui2.TextViewDocument{
			...app.doc
			text: app.doc.text.to_lower()
		}
		ui2.text_view_find(lower, app.query.to_lower())
	}
	if app.current >= app.matches.len {
		app.current = 0
	}
}

fn (app &Demo) highlights() []ui2.TextViewHighlight {
	mut out := []ui2.TextViewHighlight{}
	for i, start in app.matches {
		out << ui2.TextViewHighlight{
			start:   start
			end:     start + app.query.len
			current: i == app.current
		}
	}
	return out
}

fn (mut app Demo) doc_layout() ui2.TextViewLayout {
	return app.doc_cache.layout(app.doc, ui2.TextViewLayoutConfig{
		width:   demo_left_width - 10
		style:   ui2.TextViewStyle{
			padding: 14
		}
		plugins: app.plugins()
		images:  app.images()
	})
}

fn (mut app Demo) reveal_current() {
	if app.matches.len == 0 {
		return
	}
	lay := app.doc_layout()
	start := app.matches[app.current]
	scroll_id := ui2.text_view_scroll_id('doc')
	viewport := ui2.bounds().height - demo_doc_top - demo_margin - 18
	if offset := ui2.text_view_reveal_offset(lay, start, start + app.query.len, 0, viewport,
		ui2.scroll_offset(scroll_id))
	{
		ui2.scroll_to_offset(scroll_id, offset)
	}
}

// ── Streaming ───────────────────────────────────────────────────────

fn (mut app Demo) restart_stream(shown int) {
	if app.timer != 0 {
		ui2.cancel_timer(app.timer)
	}
	app.words = demo_reply.split(' ')
	app.shown = math.min(shown, app.words.len)
	app.reply = app.words[..app.shown].join(' ')
	app.chunks = []
	app.reply_doc = ui2.text_view_markdown(app.reply)
	app.schedule_word()
}

fn (mut app Demo) schedule_word() {
	app.timer = ui2.after(0.07 + 0.05 * f64(app.shown % 3), fn [mut app] () {
		app.next_word()
	})
}

fn (mut app Demo) next_word() {
	if app.shown >= app.words.len {
		// Wait, then stream the reply again from the start.
		app.timer = ui2.after(3.0, fn [mut app] () {
			app.restart_stream(0)
		})
		return
	}
	piece := if app.shown == 0 { app.words[0] } else { ' ' + app.words[app.shown] }
	app.chunks = ui2.text_view_stream_chunks(app.chunks, app.reply.len, time.ticks())
	app.reply += piece
	app.shown++
	app.reply_doc = ui2.text_view_markdown(app.reply)
	app.schedule_word()
}

// ── Build ───────────────────────────────────────────────────────────

fn demo_card(x f64, y f64, w f64, h f64, theme ui2.ComponentTheme, bg u32, children []ui2.Element) ui2.Element {
	return ui2.view('', ui2.rect(x, y, w, h), ui2.BoxStyle{
		bg:     theme.border
		radius: 10
	}, [
		ui2.view('', ui2.rect(1, 1, w - 2, h - 2), ui2.BoxStyle{
			bg:     bg
			radius: 9
		}, children),
	])
}

fn demo_heading(text string, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, demo_right_width, 20), ui2.TextStyle{
		color: theme.foreground
		size:  14
		bold:  true
	})
}

// demo_button is an outlined button: a border-colored box with the button
// one point inside it, so the corners round on every renderer.
fn demo_button(id string, title string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.view('', frame, ui2.BoxStyle{
		bg:     theme.border
		radius: 7
	}, [
		ui2.button(id, title, ui2.rect(1, 1, frame.width - 2, frame.height - 2), ui2.BoxStyle{
			bg:     theme.background
			radius: 6
		}, ui2.TextStyle{
			color: theme.foreground
			size:  13
			align: .center
		}),
	])
}

fn build() ui2.Element {
	mut app := unsafe { demo }
	theme := app.theme()
	window := ui2.bounds()
	mut children := []ui2.Element{}
	children << ui2.label('', 'TextView', ui2.rect(demo_margin, 14, 200, 28), ui2.TextStyle{
		color: theme.foreground
		size:  22
		bold:  true
	})
	children << ui2.label('', app.status, ui2.rect(demo_margin, 44, demo_left_width + 300,
		18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  13
	})
	children << demo_button('theme', if app.dark { 'Light theme' } else { 'Dark theme' },
		ui2.rect(window.width - demo_margin - 120, 16, 120, 28), theme)

	// The Markdown document, scrolled by the text view itself.
	children << ui2.text_field_with_change('search', 'Search', app.query, ui2.rect(demo_margin,
		68, 260, 28), ui2.BoxStyle{
		bg:            theme.background
		radius:        6
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, ui2.TextStyle{
		color: theme.foreground
		size:  13
	}, ui2.keyboard_default)
	children << demo_button('prev', 'Previous', ui2.rect(demo_margin + 270, 68, 84, 28),
		theme)
	children << demo_button('next', 'Next', ui2.rect(demo_margin + 360, 68, 70, 28), theme)
	found := if app.matches.len == 0 {
		'No matches'
	} else {
		'${app.current + 1} of ${app.matches.len}'
	}
	children << ui2.label('', found, ui2.rect(demo_margin + 440, 72, 150, 20), ui2.TextStyle{
		color: theme.muted_foreground
		size:  13
	})
	doc_h := math.max(window.height - demo_doc_top - demo_margin, 120)
	lay := app.doc_layout()
	mut copied := []int{}
	for i in 0 .. app.doc.code_blocks.len {
		if app.clips.copied('doc:${i}') {
			copied << i
		}
	}
	doc_view := ui2.rich_text_view(
		id:            'doc'
		frame:         ui2.rect(4, 8, demo_left_width - 10, doc_h - 18)
		layout:        lay
		theme:         theme
		scrollable:    true
		highlights:    app.highlights()
		plugins:       app.plugins()
		code_actions:  app.code_actions()
		copied_blocks: copied
		clipboard:     app.clipboard
	) or { panic(err) }
	children << demo_card(demo_margin, demo_doc_top, demo_left_width, doc_h, theme, theme.background,
		[doc_view])

	// HTML.
	x := demo_right_x
	mut y := 68.0
	children << demo_heading('HTML', x, y, theme)
	y += 26
	html_lay := app.html_cache.layout(app.html, ui2.TextViewLayoutConfig{
		width: demo_right_width - 32
	})
	html_view := ui2.rich_text_view(
		id:     'html'
		frame:  ui2.rect(16, 12, demo_right_width - 32, html_lay.height)
		layout: html_lay
		theme:  theme
	) or { panic(err) }
	html_h := html_lay.height + 24
	children << demo_card(x, y, demo_right_width, html_h, theme, theme.background, [html_view])
	y += html_h + 18

	// A clamped preview.
	children << demo_heading('Clamped to three lines', x, y, theme)
	y += 26
	preview_lay := app.preview_cache.layout(app.preview, ui2.TextViewLayoutConfig{
		width:     demo_right_width - 32
		max_lines: if app.expanded { 0 } else { 3 }
	})
	preview_view := ui2.rich_text_view(
		id:     'preview'
		frame:  ui2.rect(16, 12, demo_right_width - 32, preview_lay.height)
		layout: preview_lay
		theme:  theme
	) or { panic(err) }
	mut preview_kids := [preview_view]
	if preview_lay.clamped || app.expanded {
		preview_kids << ui2.link(
			id:    'expand'
			text:  if app.expanded { 'Show less' } else { 'Show more' }
			frame: ui2.rect(10, preview_lay.height + 14, 90, 22)
			size:  .small
			theme: theme
		) or { panic(err) }
	}
	preview_h := preview_lay.height + 44
	children << demo_card(x, y, demo_right_width, preview_h, theme, theme.background,
		preview_kids)
	y += preview_h + 18

	// A reply streaming into a filled bubble.
	children << demo_heading('Streaming into a colored surface', x, y, theme)
	children << demo_button('restart', 'Restart', ui2.rect(x + demo_right_width - 80, y - 4,
		80, 26), theme)
	y += 30
	bubble_bg, bubble_fg := theme.colors(.primary)
	reply_lay := app.reply_cache.layout(app.reply_doc, ui2.TextViewLayoutConfig{
		width: demo_right_width - 36
	})
	reply_view := ui2.rich_text_view(
		id:     'reply'
		frame:  ui2.rect(18, 14, demo_right_width - 36, reply_lay.height)
		layout: reply_lay
		colors: ui2.text_view_surface_colors(bubble_bg, bubble_fg)
		stream: app.chunks
	) or { panic(err) }
	bubble_h := math.max(reply_lay.height + 28, 48)
	children << ui2.view('', ui2.rect(x, y, demo_right_width, bubble_h), ui2.BoxStyle{
		bg:     bubble_bg
		radius: 14
	}, [reply_view])
	return ui2.screen(app.page_color(), children)
}

fn on_event(event string) {
	mut app := unsafe { demo }
	match event {
		'theme' {
			app.dark = !app.dark
		}
		'restart' {
			app.restart_stream(0)
		}
		'expand' {
			app.expanded = !app.expanded
		}
		'search' {
			app.query = ui2.text('search')
			app.current = 0
			app.search()
			app.reveal_current()
		}
		'next', 'prev' {
			if app.matches.len > 0 {
				step := if event == 'next' { 1 } else { app.matches.len - 1 }
				app.current = (app.current + step) % app.matches.len
				app.reveal_current()
			}
		}
		else {
			for id, doc in {
				'doc':     app.doc
				'html':    app.html
				'preview': app.preview
				'reply':   app.reply_doc
			} {
				if e := ui2.text_view_event_from_action(id, doc, app.code_actions(), event) {
					match e.kind {
						.link {
							app.status = 'Link clicked: ${e.url}'
						}
						.copy_code {
							if ui2.set_clipboard_text(e.code) {
								app.clips.show('${id}:${e.block}')
								app.status = 'Copied the ${if e.lang.len > 0 {
									e.lang + ' '
								} else {
									''
								}}code block.'
							}
						}
						.code_action {
							app.status = 'Run requested for code block ${e.block + 1} (${e.code.split_into_lines().len} lines).'
						}
					}
					break
				}
			}
		}
	}
	ui2.refresh()
}

fn main() {
	mut app := unsafe { demo }
	app.clipboard = ui2.clipboard_supported()
	app.logo = demo_logo_path()
	app.doc = ui2.text_view_parse_markdown(demo_markdown, ui2.TextViewMarkdownOptions{
		frontmatter: true
	})
	app.html = ui2.text_view_html(demo_html)
	app.preview = ui2.text_view_markdown(demo_preview)
	app.search()
	// Most of the reply is there when the window opens; the rest streams in.
	app.restart_stream(40)
	ui2.run_window('GPUI Kit text view', 1180, 800, build, on_event)
}
