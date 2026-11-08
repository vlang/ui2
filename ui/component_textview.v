module ui2

import math
import time

// TextView after GPUI Kit's TextView: Markdown or HTML rendered with ui2's own
// elements. Parsing (component_textview_markdown.v, component_textview_html.v)
// and layout (component_textview_layout.v) are pure; this file builds the
// elements, decodes the actions links and code block buttons emit, and runs
// the streaming fade through the widget animation system.
//
// Labels cannot be selected, so text selection, copy from a selection and
// GPUI Kit's touch selection handles are not available.

// text_view_fade_duration is how long streamed text takes to reach full color,
// GPUI Kit's 350 ms.
pub const text_view_fade_duration = 0.35

// How long text_view_stream_chunks remembers a chunk, in milliseconds: well
// past any fade, so a chunk is gone once nothing animates for it.
const tv_chunk_memory_ms = i64(2000)

// TextViewColors are the colors a text view draws with. text_view_colors
// derives them from a ComponentTheme; text_view_surface_colors from the two
// colors of a surface the text sits on, such as a filled chat bubble.
pub struct TextViewColors {
pub:
	background        u32 // what the text sits on: fades start from it
	foreground        u32
	muted             u32 // block quotes, front matter keys, code languages
	link              u32
	code              u32 // inline code text
	code_background   u32
	code_border       u32
	border            u32 // rules, table grid, heading underlines
	quote_bar         u32
	table_header      u32
	table_stripe      u32
	check             u32 // checked task box
	check_foreground  u32
	highlight         u32 // range highlights without a color of their own
	highlight_current u32
}

pub fn text_view_colors(theme ComponentTheme) TextViewColors {
	return TextViewColors{
		background:        theme.background
		foreground:        theme.foreground
		muted:             theme.muted_foreground
		link:              theme.primary
		code:              theme.foreground
		code_background:   theme.muted
		code_border:       tv_mix(theme.border, theme.muted, 0.55)
		border:            tv_mix(theme.border, theme.background, 0.75)
		quote_bar:         theme.border
		table_header:      theme.muted
		table_stripe:      tv_mix(theme.muted, theme.background, 0.45)
		check:             theme.primary
		check_foreground:  theme.primary_foreground
		highlight:         tv_mix(theme.warning, theme.background, 0.3)
		highlight_current: tv_strong_highlight(theme.warning, theme.background, theme.foreground)
	}
}

// tv_strong_highlight is the current match's color: the accent itself behind
// dark text, toned towards the background behind light text so the text on it
// stays readable.
fn tv_strong_highlight(accent u32, background u32, foreground u32) u32 {
	return if tv_luminance(foreground) > 0.5 { tv_mix(accent, background, 0.55) } else { accent }
}

fn tv_luminance(c u32) f64 {
	r := f64((c >> 16) & 0xff) / 255
	g := f64((c >> 8) & 0xff) / 255
	b := f64(c & 0xff) / 255
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

// text_view_surface_colors derives every color from a surface's background and
// text colors, as GPUI Kit's TextView does inside an inverted surface: links
// are the text color (and underlined), and code, table and border tints are
// the text color thinned over the background.
pub fn text_view_surface_colors(background u32, foreground u32) TextViewColors {
	return TextViewColors{
		background:        background
		foreground:        foreground
		muted:             tv_mix(foreground, background, 0.72)
		link:              foreground
		code:              foreground
		code_background:   tv_mix(foreground, background, 0.13)
		code_border:       tv_mix(foreground, background, 0.24)
		border:            tv_mix(foreground, background, 0.3)
		quote_bar:         tv_mix(foreground, background, 0.45)
		table_header:      tv_mix(foreground, background, 0.12)
		table_stripe:      tv_mix(foreground, background, 0.05)
		check:             foreground
		check_foreground:  background
		highlight:         tv_mix(0xfbbf24, background, 0.4)
		highlight_current: tv_strong_highlight(0xfbbf24, background, foreground)
	}
}

// role_color is the color a layout role is drawn in.
pub fn (c TextViewColors) role_color(role TextViewRole) u32 {
	return match role {
		.foreground { c.foreground }
		.muted { c.muted }
		.link { c.link }
		.code { c.code }
		.code_block { c.foreground }
		.background { c.background }
		.code_background { c.code_background }
		.code_border { c.code_border }
		.border { c.border }
		.quote_bar { c.quote_bar }
		.table_header { c.table_header }
		.table_stripe { c.table_stripe }
	}
}

// tv_mix is a over b at weight t (0 is b, 1 is a), channel by channel.
fn tv_mix(a u32, b u32, t f64) u32 {
	w := math.max(0, math.min(1, t))
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		ca := f64((a >> shift) & 0xff)
		cb := f64((b >> shift) & 0xff)
		out |= u32(math.round(ca * w + cb * (1 - w))) << shift
	}
	return out
}

// TextViewHighlight paints rendered text bytes start to end (half-open,
// TextViewDocument.text offsets) behind the text. Color 0 takes the colors'
// highlight, or highlight_current when current. Later highlights paint over
// earlier ones; the breaks between blocks and table cells are not painted.
pub struct TextViewHighlight {
pub:
	start   int
	end     int
	color   u32
	current bool
}

// text_view_check_highlights reports why a set of highlights cannot be used:
// a range that is reversed, out of bounds or not on character boundaries
// rejects the whole set, as GPUI Kit's set_range_highlights does.
// rich_text_view draws no highlights from a rejected set.
pub fn text_view_check_highlights(doc TextViewDocument, highlights []TextViewHighlight) ! {
	for h in highlights {
		if !text_view_valid_range(doc.text, h.start, h.end) {
			return error('highlight ${h.start}..${h.end} is not a range of the rendered text')
		}
	}
}

// text_view_find returns the start of every occurrence of query in the
// rendered text, for a search that highlights its matches.
pub fn text_view_find(doc TextViewDocument, query string) []int {
	mut out := []int{}
	if query.len == 0 {
		return out
	}
	mut at := 0
	for {
		found := doc.text.index_after(query, at) or { break }
		out << found
		at = found + query.len
	}
	return out
}

// TextViewChunk is text streamed into a view: it starts at source offset
// `start` and arrived at `at` (time.ticks() milliseconds).
pub struct TextViewChunk {
pub:
	start int
	at    i64
}

// text_view_stream_chunks records that the text appended at source offset
// `start` arrives now, and forgets chunks long done fading. Call it with the
// source's length just before appending to it; when the text is replaced
// rather than extended, start again from an empty list so it shows at once.
pub fn text_view_stream_chunks(chunks []TextViewChunk, start int, now i64) []TextViewChunk {
	mut out := []TextViewChunk{cap: chunks.len + 1}
	for c in chunks {
		if c.start < start && now - c.at < tv_chunk_memory_ms {
			out << c
		}
	}
	out << TextViewChunk{start, now}
	return out
}

// TextViewCodeAction is a button in the header of code blocks: a title, a
// symbol (symbol_known), or both. langs limits it to code blocks of those
// languages; empty puts it on every one. Clicking it reports a code_action
// event carrying id.
pub struct TextViewCodeAction {
pub:
	id     string
	title  string
	symbol string
	langs  []string
}

fn tv_action_applies(action TextViewCodeAction, lang string) bool {
	if action.langs.len == 0 {
		return true
	}
	for l in action.langs {
		if l.to_lower() == lang.to_lower() {
			return true
		}
	}
	return false
}

pub struct TextViewConfig {
pub:
	id    string
	frame Rect
	// Content, first match wins: a layout (made for frame.width), a parsed
	// document, HTML, or Markdown. Pass a layout from TextViewCache to keep
	// builds from laying the document out again.
	layout           ?TextViewLayout
	document         ?TextViewDocument
	html             string
	markdown         string
	markdown_options TextViewMarkdownOptions
	// Layout settings, used when no layout is passed.
	style       TextViewStyle
	size        ComponentSize = .medium
	max_lines   int
	plugins     []TextViewBlockPlugin
	images      TextViewImageFn = unsafe { nil }
	code_header bool            = true
	// Appearance: colors default to text_view_colors(theme).
	theme  ComponentTheme
	colors ?TextViewColors
	fill   bool // paint the colors' background behind the content
	radius f64  // corner radius of that background
	// scrollable scrolls the content inside frame (text_view_scroll_id).
	scrollable bool
	highlights []TextViewHighlight
	// Streaming: text in the chunks fades in over fade_duration, unless the
	// system asks for reduced motion. now (time.ticks()) is for tests.
	stream        []TextViewChunk
	fade_duration f64 = text_view_fade_duration
	reduce_motion bool
	now           i64
	// Code blocks: the actions in their header, the blocks to show as just
	// copied, and whether there is a clipboard (pass clipboard_supported()).
	code_actions        []TextViewCodeAction
	copied_blocks       []int
	clipboard           bool = true
	accessibility_label string
}

// text_view_config_layout is the layout rich_text_view builds for config, so an
// application can size the view (layout.height) before building it.
pub fn text_view_config_layout(config TextViewConfig) TextViewLayout {
	if lay := config.layout {
		return lay
	}
	doc := config.document or {
		if config.html.len > 0 {
			text_view_html(config.html)
		} else {
			text_view_parse_markdown(config.markdown, config.markdown_options)
		}
	}
	return text_view_layout(doc, TextViewLayoutConfig{
		width:       config.frame.width
		style:       config.style
		size:        config.size
		max_lines:   config.max_lines
		plugins:     config.plugins
		images:      config.images
		code_header: config.code_header
	})
}

// text_view_scroll_id is the scroll element of a scrollable text view, for
// scroll_to_offset and scroll_offset.
pub fn text_view_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

pub enum TextViewEventKind {
	link
	copy_code
	code_action
}

// TextViewEvent is a click a text view reported: a link (url), a code block's
// copy button, or one of its code actions (action is its id).
pub struct TextViewEvent {
pub:
	kind   TextViewEventKind
	url    string
	link   int = -1
	block  int = -1
	lang   string
	code   string
	action string
}

// text_view_event_from_action decodes an action a text view emitted against
// the document it shows and the code actions it was built with. Foreign,
// malformed and forged actions (an index the document does not have, an
// action that does not apply to the block's language) decode to none.
pub fn text_view_event_from_action(id string, doc TextViewDocument, code_actions []TextViewCodeAction, action string) ?TextViewEvent {
	part := component_action_part(id, action)?
	if part.starts_with('link:') {
		index := component_parse_index(part['link:'.len..], doc.links.len - 1)?
		url := doc.links[index]
		if url.len == 0 {
			return none
		}
		return TextViewEvent{
			kind: .link
			url:  url
			link: index
		}
	}
	if !part.starts_with('code:') {
		return none
	}
	rest := part['code:'.len..]
	sep := rest.index(':')?
	block := component_parse_index(rest[..sep], doc.code_blocks.len - 1)?
	code := doc.code_blocks[block]
	tail := rest[sep + 1..]
	if tail == 'copy' {
		return TextViewEvent{
			kind:  .copy_code
			block: block
			lang:  code.lang
			code:  code.code
		}
	}
	if tail.starts_with('action:') {
		k := component_parse_index(tail['action:'.len..], code_actions.len - 1)?
		if !tv_action_applies(code_actions[k], code.lang) {
			return none
		}
		return TextViewEvent{
			kind:   .code_action
			block:  block
			lang:   code.lang
			code:   code.code
			action: code_actions[k].id
		}
	}
	return none
}

// text_view_link_from_action is the destination of the link (or linked
// image) an action came from. The application decides what opening it means.
pub fn text_view_link_from_action(id string, doc TextViewDocument, action string) ?string {
	event := text_view_event_from_action(id, doc, [], action)?
	if event.kind != .link {
		return none
	}
	return event.url
}

// text_view_copy_from_action copies a code block to the clipboard when action
// is its copy button's, and returns the block's index (to show it as copied).
pub fn text_view_copy_from_action(id string, doc TextViewDocument, action string) ?int {
	event := text_view_event_from_action(id, doc, [], action)?
	if event.kind != .copy_code || !set_clipboard_text(event.code) {
		return none
	}
	return event.block
}

// ── Building ────────────────────────────────────────────────────────

struct TvFade {
	rendered int // where the chunk's text starts in the rendered text
	source   int
}

struct TvPiece {
	a     int // byte offsets in the item's text
	b     int
	chunk int // index into TvBuild.fades, or -1
}

struct TvBuild {
	config     TextViewConfig
	lay        TextViewLayout
	colors     TextViewColors
	highlights []TextViewHighlight
	fades      []TvFade
	groups     map[int][]int
mut:
	link_seq map[int]int
	fade_seq map[int]int
	fade_ids map[string]bool
}

// rich_text_view draws a document, GPUI Kit's TextView. (It is not called
// text_view: that is a variable name in the AppKit backend.) Size frame to the
// layout's height (text_view_config_layout), or set scrollable to scroll the
// content in a fixed frame. Links and code block buttons emit actions; decode
// them with text_view_event_from_action.
pub fn rich_text_view(config TextViewConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	lay := text_view_config_layout(config)
	colors := config.colors or { text_view_colors(config.theme) }
	mut highlights := config.highlights.clone()
	text_view_check_highlights(lay.document, highlights) or { highlights = [] }
	now := if config.now != 0 { config.now } else { time.ticks() }
	mut groups := map[int][]int{}
	for i, item in lay.items {
		groups[item.container] << i
	}
	mut b := TvBuild{
		config:     config
		lay:        lay
		colors:     colors
		highlights: highlights
		fades:      tv_active_fades(config, lay.document, now)
		groups:     groups
	}
	content := b.group(-1, 0, 0)
	tv_clear_stale_fades(config.id, b.fade_ids)
	box := if config.fill {
		BoxStyle{
			bg:     colors.background
			radius: config.radius
		}
	} else {
		BoxStyle{
			transparent: true
		}
	}
	local := rect(0, 0, config.frame.width, config.frame.height)
	mut children := content.clone()
	if config.scrollable {
		mut kids := content.clone()
		kids << view('', rect(0, math.max(lay.height - 1, 0), 1, 1), BoxStyle{
			transparent: true
		}, []Element{})
		children = [scroll(text_view_scroll_id(config.id), local, colors.background, kids)]
	}
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}

fn tv_fade_id(id string, source int, k int) string {
	return component_part_id(id, 'fade:${source}:${k}')
}

// tv_active_fades lists the chunks still fading: younger than the fade, or
// with their animation still running.
fn tv_active_fades(config TextViewConfig, doc TextViewDocument, now i64) []TvFade {
	if config.reduce_motion || config.fade_duration <= 0 || !component_finite(config.fade_duration) {
		return []
	}
	limit := i64(config.fade_duration * 1000) + 150
	mut out := []TvFade{}
	for c in config.stream {
		if now - c.at >= limit && animation_info(tv_fade_id(config.id, c.start, 0)).status != .running {
			continue
		}
		out << TvFade{
			rendered: doc.rendered_offset_for_source(c.start)
			source:   c.start
		}
	}
	out.sort(a.rendered < b.rendered)
	return out
}

// tv_clear_stale_fades releases the animation state of labels that no longer
// fade, so a later theme change shows on them.
fn tv_clear_stale_fades(id string, keep map[string]bool) {
	prefix := component_part_id(id, 'fade:')
	mut stale := []string{}
	runtime := g_animation_runtime
	runtime.mutex.lock()
	for key, _ in runtime.runs {
		if key.starts_with(prefix) && key !in keep {
			stale << key
		}
	}
	runtime.mutex.unlock()
	for key in stale {
		clear_animation(key)
	}
}

fn tv_local(frame Rect, ox f64, oy f64) Rect {
	return rect(frame.x - ox, frame.y - oy, frame.width, frame.height)
}

// group builds the items of one container (-1: the document) relative to ox,
// oy: fills first, then highlights over them, then the text.
fn (mut b TvBuild) group(container int, ox f64, oy f64) []Element {
	mut fills := []Element{}
	mut marks := []Element{}
	mut blocks := []Element{}
	mut front := []Element{}
	for i in b.groups[container] {
		item := b.lay.items[i]
		match item.kind {
			.fill {
				fills << view('', tv_local(item.frame, ox, oy), BoxStyle{
					bg:     b.colors.role_color(item.role)
					radius: item.radius
				}, []Element{})
			}
			.text {
				marks << b.highlight_boxes(item, ox, oy)
				front << b.text(item, ox, oy)
			}
			.image {
				front << b.image_el(item, ox, oy)
			}
			.check {
				front << b.check(item, ox, oy)
			}
			.code_header {
				blocks << b.code_header(item, ox, oy)
			}
			.container {
				blocks << b.container(i, item, ox, oy)
			}
			.plugin {
				blocks << b.plugin(item, ox, oy)
			}
		}
	}
	mut out := []Element{cap: fills.len + marks.len + blocks.len + front.len}
	out << fills
	out << marks
	out << blocks
	out << front
	return out
}

fn (mut b TvBuild) container(index int, item TextViewItem, ox f64, oy f64) Element {
	mut children := b.group(index, item.frame.x, item.frame.y)
	children << view('', rect(math.max(item.content_width - 1, 0), 0, 1, 1), BoxStyle{
		transparent: true
	}, []Element{})
	name := if item.role == .code_background { 'code:${item.block}' } else { 'table:${item.block}' }
	return scroll_with_mode(component_part_id(b.config.id, name + ':scroll'), tv_local(item.frame,
		ox, oy), b.colors.role_color(item.role), .horizontal_only, children)
}

fn (b &TvBuild) item_style(item TextViewItem) TextStyle {
	return tv_text_style(item.size, item.bold, item.italic, item.mono, b.lay.style)
}

// pieces splits a text item where streamed chunks begin, each piece fading
// with its own chunk.
fn (b &TvBuild) pieces(item TextViewItem) []TvPiece {
	if b.fades.len == 0 || item.rendered_start < 0 {
		return [TvPiece{0, item.text.len, -1}]
	}
	rs := item.rendered_start
	rendered_len := item.rendered_end - rs
	mut out := []TvPiece{}
	mut pos := 0
	mut chunk := -1
	for f, fade in b.fades {
		boundary := fade.rendered - rs
		if boundary <= 0 {
			chunk = f
			continue
		}
		if boundary >= rendered_len {
			break
		}
		if boundary > pos {
			out << TvPiece{pos, boundary, chunk}
			pos = boundary
		}
		chunk = f
	}
	out << TvPiece{pos, item.text.len, chunk}
	return out
}

fn (mut b TvBuild) text(item TextViewItem, ox f64, oy f64) []Element {
	style := b.item_style(item)
	color := b.colors.role_color(item.role)
	space := tv_space_width(style)
	inset := tv_label_inset(style)
	mut labels := []Element{}
	for piece in b.pieces(item) {
		part := item.text[piece.a..piece.b]
		core := part.trim(' ')
		if core.len == 0 {
			continue
		}
		lead := part.len - part.trim_left(' ').len
		gx := item.text_x + tv_advance(item.text[..piece.a], style) + space * f64(lead)
		frame := rect(tv_snap(gx - inset / 2) - ox, item.frame.y - oy, tv_advance(core, style) +
			inset + 1, item.frame.height)
		mut id := ''
		if piece.chunk >= 0 {
			fade := b.fades[piece.chunk]
			k := b.fade_seq[fade.source]
			b.fade_seq[fade.source] = k + 1
			id = tv_fade_id(b.config.id, fade.source, k)
			b.fade_ids[id] = true
			if animation_info(id).status == .idle {
				from := if item.role in [.code, .code_block] {
					b.colors.code_background
				} else {
					b.colors.background
				}
				tv_fade_animation(from, color, b.config.fade_duration).start(id)
			}
		}
		labels << label(id, tv_display(core), frame, TextStyle{
			color:       color
			size:        item.size
			bold:        item.bold
			italic:      item.italic
			underline:   item.underline
			font_family: style.font_family
			valign:      .middle
		})
	}
	if item.link < 0 || labels.len == 0 {
		return labels
	}
	// One link target over the run, with the labels inside it.
	mut left := labels[0].frame.x
	mut right := left
	for l in labels {
		left = math.min(left, l.frame.x)
		right = math.max(right, l.frame.x + l.frame.width)
	}
	frame := rect(left, item.frame.y - oy, right - left, item.frame.height)
	mut kids := []Element{cap: labels.len}
	for l in labels {
		kids << Element{
			...l
			frame: rect(l.frame.x - left, 0, l.frame.width, l.frame.height)
		}
	}
	return [b.link_wrap(item.link, frame, kids, item.text.trim_space())]
}

fn tv_fade_animation(from u32, to u32, duration f64) Animation {
	return animation(duration: 0, text_color: from) + animation(
		duration:   duration
		text_color: to
		transition: .out_cubic
	)
}

fn (mut b TvBuild) link_wrap(link int, frame Rect, children []Element, name string) Element {
	seq := b.link_seq[link]
	b.link_seq[link] = seq + 1
	url := if link < b.lay.document.links.len { b.lay.document.links[link] } else { '' }
	return Element{
		...button_view(component_part_id(b.config.id, 'link:${link}:${seq}'), frame, BoxStyle{
			transparent: true
		}, children)
		action_id:           component_part_id(b.config.id, 'link:${link}')
		cursor:              cursor_pointing_hand
		tooltip:             url
		accessibility_role:  'link'
		accessibility_label: name
	}
}

fn (b &TvBuild) highlight_boxes(item TextViewItem, ox f64, oy f64) []Element {
	if b.highlights.len == 0 || item.rendered_start < 0 {
		return []
	}
	style := b.item_style(item)
	em := font_em_pixels(item.size)
	h := math.min(item.frame.height, math.round(em * 1.45))
	y := item.frame.y + (item.frame.height - h) / 2 - oy
	mut out := []Element{}
	for hl in b.highlights {
		lo := tv_max_int(hl.start, item.rendered_start)
		hi := tv_min_int(hl.end, item.rendered_end)
		if lo >= hi {
			continue
		}
		x0 := item.text_x + tv_advance(item.text[..lo - item.rendered_start], style)
		x1 := item.text_x + tv_advance(item.text[..hi - item.rendered_start], style)
		color := if hl.color != 0 {
			hl.color
		} else if hl.current {
			b.colors.highlight_current
		} else {
			b.colors.highlight
		}
		out << view('', rect(x0 - ox, y, x1 - x0, h), BoxStyle{
			bg:     color
			radius: 3
		}, []Element{})
	}
	return out
}

fn (mut b TvBuild) image_el(item TextViewItem, ox f64, oy f64) Element {
	frame := tv_local(item.frame, ox, oy)
	local := rect(0, 0, frame.width, frame.height)
	mut el := if item.path.len > 0 {
		Element{
			...image('', item.path, local)
			accessibility_role:  'img'
			accessibility_label: item.alt
		}
	} else {
		b.placeholder(item.alt, local)
	}
	if item.link >= 0 {
		return b.link_wrap(item.link, frame, [el], item.alt)
	}
	return Element{
		...el
		frame: frame
	}
}

// placeholder stands in for an image there is no file for: a tinted box with
// a picture symbol and the alt text.
fn (b &TvBuild) placeholder(alt string, frame Rect) Element {
	side := math.min(28.0, math.min(frame.width, frame.height) / 2)
	style := TextStyle{
		color: b.colors.muted
		size:  b.lay.style.font_size * 0.9
		align: .center
	}
	mut kids := []Element{}
	text_h := font_em_pixels(style.size) * 1.5
	top := (frame.height - side - (if alt.len > 0 { text_h } else { 0.0 })) / 2
	if side >= 8 {
		kids << Element{
			...image('', 'symbol:photo', rect((frame.width - side) / 2, top, side, side))
			text_style: TextStyle{
				color: b.colors.muted
			}
		}
	}
	if alt.len > 0 {
		kids << label('', alt, rect(4, top + side + 2, math.max(frame.width - 8, 0), text_h),
			style)
	}
	return Element{
		...view('', frame, BoxStyle{
			bg:     b.colors.code_background
			radius: 6
		}, kids)
		accessibility_role:  'img'
		accessibility_label: alt
	}
}

fn (b &TvBuild) check(item TextViewItem, ox f64, oy f64) Element {
	frame := tv_local(item.frame, ox, oy)
	w := frame.width
	h := frame.height
	radius := item.radius
	mut kids := []Element{}
	mut bg := b.colors.border
	if item.checked {
		bg = b.colors.check
		inner := math.round(w * 0.16)
		kids << Element{
			...image('', 'symbol:checkmark', rect(inner, inner, w - 2 * inner, h - 2 * inner))
			text_style: TextStyle{
				color: b.colors.check_foreground
			}
		}
	} else {
		kids << view('', rect(1, 1, math.max(w - 2, 0), math.max(h - 2, 0)), BoxStyle{
			bg:     b.colors.background
			radius: math.max(radius - 1, 0)
		}, []Element{})
	}
	return Element{
		...view('', frame, BoxStyle{
			bg:     bg
			radius: radius
		}, kids)
		accessibility_role:  'checkbox'
		accessibility_label: 'Task'
		accessibility_value: if item.checked { 'checked' } else { 'unchecked' }
	}
}

fn (b &TvBuild) code_header(item TextViewItem, ox f64, oy f64) Element {
	frame := tv_local(item.frame, ox, oy)
	block := item.block
	w := frame.width
	h := frame.height
	em := font_em_pixels(b.lay.style.font_size)
	pad := math.round(em * 0.85) - 1
	size := b.lay.style.font_size * 0.85
	mut kids := []Element{}
	caption := TextStyle{
		color: b.colors.muted
		size:  size
	}
	if item.text.len > 0 {
		kids << label('', item.text, rect(pad, 0, math.min(measure_text_width(item.text, caption) + 2,
			w / 2), h), caption)
	}
	side := math.min(math.round(h * 0.75), h)
	mut right := w - math.round(pad / 2)
	copied := block in b.config.copied_blocks
	copy_x := right - side
	icon := math.round(side * 0.62)
	copy_color := if !b.config.clipboard {
		b.colors.border
	} else if copied {
		b.colors.link
	} else {
		b.colors.muted
	}
	kids << Element{
		...button_view(component_part_id(b.config.id, 'code:${block}:copy'), rect(copy_x, (h - side) / 2,
			side, side), BoxStyle{
			transparent: true
			radius:      4
		}, [
			Element{
				...image('', 'symbol:' + if copied { 'checkmark' } else { 'doc.on.doc' }, rect((side - icon) / 2,
					(side - icon) / 2, icon, icon))
				text_style: TextStyle{
					color: copy_color
				}
			},
		])
		enabled:             b.config.clipboard
		cursor:              if b.config.clipboard { cursor_pointing_hand } else { '' }
		tooltip:             if !b.config.clipboard {
			'Clipboard unavailable'
		} else if copied {
			'Copied'
		} else {
			'Copy code'
		}
		accessibility_label: 'Copy code'
		accessibility_value: if copied { 'Copied' } else { '' }
	}
	right = copy_x - math.round(em * 0.4)
	lang := if block >= 0 && block < b.lay.document.code_blocks.len {
		b.lay.document.code_blocks[block].lang
	} else {
		''
	}
	action_h := math.min(math.round(h * 0.78), h)
	for k, act in b.config.code_actions {
		if !tv_action_applies(act, lang) {
			continue
		}
		text_w := if act.title.len > 0 { measure_text_width(act.title, caption) } else { 0.0 }
		icon_w := if act.symbol.len > 0 && symbol_known(act.symbol) {
			math.round(size * 1.1)
		} else {
			0.0
		}
		gap := if text_w > 0 && icon_w > 0 { 4.0 } else { 0.0 }
		bw := math.ceil(text_w + icon_w + gap + 16)
		bx := right - bw
		if bx < w / 3 {
			break
		}
		mut inner := []Element{}
		mut cx := 8.0
		if icon_w > 0 {
			inner << Element{
				...image('', 'symbol:' + act.symbol, rect(cx, (action_h - icon_w) / 2, icon_w,
					icon_w))
				text_style: TextStyle{
					color: b.colors.foreground
				}
			}
			cx += icon_w + gap
		}
		if text_w > 0 {
			inner << label('', act.title, rect(cx, 0, text_w + 1, action_h - 2), TextStyle{
				...caption
				color: b.colors.foreground
			})
		}
		kids << Element{
			...button_view(component_part_id(b.config.id, 'code:${block}:action:${k}'), rect(bx,
				(h - action_h) / 2, bw, action_h), BoxStyle{
				bg:     b.colors.code_border
				radius: 5
			}, [
				view('', rect(1, 1, bw - 2, action_h - 2), BoxStyle{
					bg:     b.colors.code_background
					radius: 4
				}, inner),
			])
			cursor:              cursor_pointing_hand
			accessibility_label: if act.title.len > 0 { act.title } else { act.id }
		}
		right = bx - math.round(em * 0.4)
	}
	return view('', frame, BoxStyle{
		transparent: true
	}, kids)
}

fn (b &TvBuild) plugin(item TextViewItem, ox f64, oy f64) Element {
	frame := tv_local(item.frame, ox, oy)
	mut kids := []Element{}
	for p in b.config.plugins {
		if p.name != item.text || p.render == unsafe { nil } {
			continue
		}
		code := if item.block >= 0 && item.block < b.lay.document.code_blocks.len {
			b.lay.document.code_blocks[item.block]
		} else {
			TextViewCodeBlock{}
		}
		kids << p.render(TextViewPluginBlock{
			index: item.block
			name:  p.name
			info:  code.info
			code:  code.code
			width: frame.width
		}, rect(0, 0, frame.width, frame.height))
		break
	}
	return view(component_part_id(b.config.id, 'plugin:${item.block}'), frame, BoxStyle{
		transparent: true
	}, kids)
}
