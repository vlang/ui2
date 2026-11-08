module ui2

import math

// TextView layout. A label has one style, so rich text is laid out here as one
// label per styled run per line: inline content is broken into words, the
// words are measured with measure_text_width and filled into lines, and each
// line's runs are measured again as a whole so neighbouring labels meet
// exactly. Every backend's label draws its text inset by a fixed amount
// (NSTextField by two points a side, the others by nothing); that inset is
// measured, not assumed, and taken back out so runs line up on every backend.
//
// The result is a TextViewLayout: positioned items in document coordinates and
// the lines they sit on, plus the height. Parse a document once, lay it out
// for each width (TextViewCache keeps the last one), and build it with
// rich_text_view.

// TextViewStyle sets a text view's metrics. Zero font_size takes the
// ComponentSize's.
pub struct TextViewStyle {
pub:
	font_size   f64
	font_family string
	code_family string = 'monospace'
	code_scale  f64    = 0.9  // code size relative to font_size
	line_height f64    = 1.55 // body line height, in ems
	block_gap   f64    = 0.85 // space between blocks, in ems
	// heading_scales sizes headings 1 to 6 relative to font_size; empty uses
	// 1.75, 1.45, 1.25, 1.1, 1 and 0.9.
	heading_scales []f64
	padding        f64 // inset around the content
	image_width    f64 = 360 // size of an image nothing else sizes
	image_height   f64 = 200
	wrap_code      bool // wrap long code lines instead of scrolling them sideways
}

// TextViewImage is how an image source is drawn: the path an image element
// loads (empty draws a placeholder with the alt text) and its natural size
// (zero takes the HTML attributes or TextViewStyle's default). Images wider
// than the text are scaled down.
pub struct TextViewImage {
pub:
	path   string
	width  f64
	height f64
}

// TextViewImageFn resolves an image source. Without one, a relative or
// absolute path (or file:// URL) is loaded as it is and remote and data URLs
// draw a placeholder: a text view never fetches anything itself.
pub type TextViewImageFn = fn (src string, alt string) TextViewImage

// TextViewPluginBlock is a fenced code block a plugin renders instead.
pub struct TextViewPluginBlock {
pub:
	index int // code block index
	name  string
	info  string
	code  string
	width f64 // the width the block has
}

pub type TextViewPluginHeightFn = fn (block TextViewPluginBlock) f64

pub type TextViewPluginRenderFn = fn (block TextViewPluginBlock, frame Rect) Element

// TextViewBlockPlugin renders fenced code blocks whose language is `name`
// (```chart, say) with the application's own elements. height reports how tall
// the block is for a width (160 without one); render builds it in a frame at
// the origin.
pub struct TextViewBlockPlugin {
pub:
	name   string
	height TextViewPluginHeightFn = unsafe { nil }
	render TextViewPluginRenderFn = unsafe { nil }
}

pub struct TextViewLayoutConfig {
pub:
	width     f64
	style     TextViewStyle
	size      ComponentSize = .medium
	max_lines int // show at most this many lines, the last ending in an ellipsis
	plugins   []TextViewBlockPlugin
	images    TextViewImageFn = unsafe { nil }
	// code_header gives code blocks a strip with their language and actions.
	code_header bool = true
}

pub enum TextViewItemKind {
	text        // a label: one styled run on one line
	fill        // a solid rectangle: backgrounds, bars, rules, borders, bullets
	image       // an image, or its placeholder when path is empty
	check       // a task list check box
	code_header // a code block's strip for its language, copy button and actions
	container   // a sideways-scrolling area holding a wide code block or table
	plugin      // a block a plugin renders
}

// TextViewRole names the color an item is drawn in; TextViewColors maps roles
// to colors when the view is built, so a theme change needs no new layout.
pub enum TextViewRole {
	foreground
	muted
	link
	code
	code_block
	background
	code_background
	code_border
	border
	quote_bar
	table_header
	table_stripe
}

pub struct TextViewItem {
pub:
	kind  TextViewItemKind
	frame Rect // in document coordinates, containers included
	// text items: the run's rendered text (edge spaces included; the label
	// shows it without them), where its glyphs start and how wide they are.
	text      string
	text_x    f64
	advance   f64
	size      f64
	bold      bool
	italic    bool
	mono      bool
	underline bool
	strike    bool
	role      TextViewRole
	radius    f64
	align     Align
	link      int = -1 // the link a text or image belongs to
	block     int = -1 // code block (or, for a table's container, table) index
	container int = -1 // the container item this item scrolls with
	line      int = -1 // the TextViewLine a text item sits on
	// The item's bytes in the rendered text; -1 for list numbers and the like.
	rendered_start int = -1
	rendered_end   int = -1
	path           string // image
	alt            string // image
	checked        bool   // check
	content_width  f64    // container: how wide its content is
	ellipsis       bool   // text: ends in the clamp's ellipsis
}

// TextViewLine is one laid-out line of text (or an image or plugin block,
// with no rendered range), as reveals and clamping count them.
pub struct TextViewLine {
pub:
	frame          Rect // x, y, the width the line had, height
	baseline       f64
	rendered_start int = -1
	rendered_end   int = -1
	container      int = -1
}

pub struct TextViewLayout {
pub:
	document TextViewDocument
	style    TextViewStyle // with font_size resolved
	width    f64
	height   f64  // what to size the view (or scroll content) to
	clamped  bool // max_lines left content out
	items    []TextViewItem
	lines    []TextViewLine
}

// TextViewCache keeps the last layout so a build (the custom renderer builds
// every frame) does not lay the document out again. It lays out anew when the
// document, width, size, line budget, style or text measurement changes. Call
// clear after changing plugins or the image resolver.
pub struct TextViewCache {
mut:
	valid  bool
	source string
	html   bool
	key    string
	layout TextViewLayout
}

pub fn (mut cache TextViewCache) layout(doc TextViewDocument, config TextViewLayoutConfig) TextViewLayout {
	key := tv_layout_key(config)
	if cache.valid && cache.html == doc.html && cache.key == key && cache.source == doc.source {
		return cache.layout
	}
	cache.layout = text_view_layout(doc, config)
	cache.source = doc.source
	cache.html = doc.html
	cache.key = key
	cache.valid = true
	return cache.layout
}

pub fn (mut cache TextViewCache) clear() {
	cache.valid = false
}

fn tv_layout_key(config TextViewLayoutConfig) string {
	s := config.style
	return '${config.width}|${config.size}|${config.max_lines}|${config.code_header}|${text_measurement_exact()}|${s.font_size}|${s.font_family}|${s.code_family}|${s.code_scale}|${s.line_height}|${s.block_gap}|${s.heading_scales}|${s.padding}|${s.image_width}|${s.image_height}|${s.wrap_code}|${config.plugins.len}'
}

// text_view_layout lays a document out for a width.
pub fn text_view_layout(doc TextViewDocument, config TextViewLayoutConfig) TextViewLayout {
	style := tv_resolve_style(config.style, config.size)
	width := if component_finite(config.width) { math.max(config.width, 0) } else { 0.0 }
	em := font_em_pixels(style.font_size)
	mut e := TvEngine{
		style:   style
		plugins: config.plugins
		images:  config.images
		header:  config.code_header
		em:      em
		lh:      em * style.line_height
	}
	pad := style.padding
	ctx := TvCtx{
		x:     pad
		width: math.max(width - 2 * pad, em)
	}
	bottom := e.blocks(doc.root.children, pad, ctx)
	height := if e.items.len == 0 { 0.0 } else { math.ceil(bottom + pad) }
	lay := TextViewLayout{
		document: doc
		style:    style
		width:    width
		height:   height
		items:    e.items
		lines:    e.lines
	}
	if config.max_lines > 0 {
		return tv_clamp(lay, config.max_lines)
	}
	return lay
}

fn tv_resolve_style(style TextViewStyle, size ComponentSize) TextViewStyle {
	font_size := if style.font_size > 0 && component_finite(style.font_size) {
		style.font_size
	} else {
		component_metrics(size).font_size
	}
	return TextViewStyle{
		...style
		font_size:   font_size
		code_scale:  if style.code_scale > 0 { style.code_scale } else { 0.9 }
		line_height: if style.line_height > 0 { style.line_height } else { 1.55 }
		block_gap:   if style.block_gap >= 0 { style.block_gap } else { 0.85 }
		padding:     if style.padding > 0 && component_finite(style.padding) {
			style.padding
		} else {
			0
		}
	}
}

// text_view_heading_scale is a heading level's size relative to body text.
pub fn text_view_heading_scale(style TextViewStyle, level int) f64 {
	index := tv_min_int(tv_max_int(level, 1), 6) - 1
	if index < style.heading_scales.len && style.heading_scales[index] > 0 {
		return style.heading_scales[index]
	}
	return [1.75, 1.45, 1.25, 1.1, 1.0, 0.9][index]
}

// ── Measuring ───────────────────────────────────────────────────────

// tv_label_inset is how much wider a label is than the glyphs it shows: the
// two-point margin NSTextField draws in, zero elsewhere. Measuring `n` twice
// against `nn` finds it without assuming which backend runs.
fn tv_label_inset(style TextStyle) f64 {
	one := measure_text_width('n', style)
	two := measure_text_width('nn', style)
	return math.max(0, math.min(2 * one - two, style.size))
}

fn tv_space_width(style TextStyle) f64 {
	return math.max(0, measure_text_width('n n', style) - measure_text_width('nn', style))
}

// tv_advance is how far text moves the pen: the glyph width without the label
// inset. Spaces at either end are counted from the width of a space, since
// some measurers leave trailing whitespace out.
fn tv_advance(s string, style TextStyle) f64 {
	if s.len == 0 {
		return 0
	}
	core := s.trim(' ')
	space := tv_space_width(style)
	if core.len == 0 {
		return space * f64(s.len)
	}
	lead := s.len - s.trim_left(' ').len
	trail := s.len - s.trim_right(' ').len
	return math.max(0, measure_text_width(tv_display(core), style) - tv_label_inset(style)) +
		space * f64(lead + trail)
}

// tv_display is the text a label shows for rendered text: tabs as four spaces.
fn tv_display(s string) string {
	return if s.contains('\t') { s.replace('\t', '    ') } else { s }
}

// tv_baseline_ratio is how far below the middle of a label its baseline sits,
// in ems of its font. Labels centre their text, and fonts put their baseline
// at different heights in the line box (Roboto Mono's lower than Roboto's,
// Menlo's higher than the system font's), so runs of different fonts on one
// line are placed by these ratios to share a baseline. They come from the
// bundled Roboto faces in the custom renderer and were measured from
// NSTextField on AppKit.
fn tv_baseline_ratio(mono bool) f64 {
	$if ui2_custom_rendering ? {
		return if mono { 0.388 } else { 0.342 }
	} $else $if linux || freebsd || openbsd || netbsd || dragonfly || solaris || android {
		return if mono { 0.388 } else { 0.342 }
	} $else $if macos || ios {
		return if mono { 0.347 } else { 0.378 }
	} $else {
		return 0.36
	}
}

// tv_snap rounds a label's position to a whole point where the renderer would
// truncate it (the custom renderer draws text at integer positions), so runs
// next to each other are off by half a point at most instead of a whole one.
fn tv_snap(v f64) f64 {
	$if ui2_custom_rendering ? {
		return math.round(v)
	} $else $if linux || freebsd || openbsd || netbsd || dragonfly || solaris || android {
		return math.round(v)
	} $else {
		return v
	}
}

fn tv_text_style(size f64, bold bool, italic bool, mono bool, style TextViewStyle) TextStyle {
	return TextStyle{
		size:        size
		bold:        bold
		italic:      italic
		font_family: if mono { style.code_family } else { style.font_family }
	}
}

// ── Engine ──────────────────────────────────────────────────────────

struct TvEngine {
	style   TextViewStyle
	plugins []TextViewBlockPlugin
	images  TextViewImageFn = unsafe { nil }
	header  bool
	em      f64
	lh      f64
mut:
	items  []TextViewItem
	lines  []TextViewLine
	tables int
}

struct TvCtx {
	x         f64
	width     f64
	role      TextViewRole
	container int = -1
	tight     bool
	depth     int
}

struct TvRunStyle {
	size   f64
	bold   bool
	italic bool
	mono   bool
	strike bool
	code   bool // an inline code span: drawn on a tinted background
	link   int = -1
	role   TextViewRole
	lh     f64 // line height in ems
}

// TvFrag is a word, a run of spaces, a line break or an image of inline content.
struct TvFrag {
	kind   int // 0 word, 1 spaces, 2 line break, 3 image
	text   string
	style  TvRunStyle
	rstart int = -1
	path   string
	alt    string
mut:
	w     f64
	h     f64
	pad_l f64
	pad_r f64
}

struct TvPlaced {
	frag TvFrag
	x    f64
}

struct TvRun {
mut:
	kind   int
	text   string
	style  TvRunStyle
	rstart int
	pad_l  f64
	pad_r  f64
	x      f64
	adv    f64
	w      f64
	h      f64
	path   string
	alt    string
}

fn (e &TvEngine) run_style(st TvRunStyle) TextStyle {
	return tv_text_style(st.size, st.bold, st.italic, st.mono, e.style)
}

fn (e &TvEngine) adv(s string, st TvRunStyle) f64 {
	return tv_advance(s, e.run_style(st))
}

fn (e &TvEngine) body(role TextViewRole) TvRunStyle {
	return TvRunStyle{
		size: e.style.font_size
		role: role
		lh:   e.style.line_height
	}
}

fn (mut e TvEngine) fill(frame Rect, role TextViewRole, radius f64, container int) {
	e.items << TextViewItem{
		kind:      .fill
		frame:     frame
		role:      role
		radius:    radius
		container: container
	}
}

fn (mut e TvEngine) blocks(nodes []TextViewNode, y0 f64, ctx TvCtx) f64 {
	mut y := y0
	mut first := true
	for n in nodes {
		top := if first { y } else { y + e.gap_before(n, ctx) }
		bottom := e.block(n, top, ctx)
		if bottom > top {
			y = bottom
			first = false
		}
	}
	return y
}

fn (e &TvEngine) gap_before(n TextViewNode, ctx TvCtx) f64 {
	if ctx.tight {
		return math.round(e.em * 0.3)
	}
	gap := e.em * e.style.block_gap
	if n.kind == .heading {
		return math.round(if n.level <= 2 { gap * 1.7 } else { gap * 1.35 })
	}
	return math.round(gap)
}

fn (mut e TvEngine) block(n TextViewNode, y f64, ctx TvCtx) f64 {
	return match n.kind {
		.paragraph { e.paragraph(n, y, ctx) }
		.heading { e.heading(n, y, ctx) }
		.blockquote { e.quote(n, y, ctx) }
		.list { e.list_block(n, y, ctx) }
		.code_block { e.code(n, y, ctx) }
		.thematic_break { e.rule(y, ctx) }
		.table { e.table_block(n, y, ctx) }
		.frontmatter { e.frontmatter(n, y, ctx) }
		.html_block, .document, .list_item, .table_row, .table_cell { e.blocks(n.children, y, ctx) }
		else { e.inline([n], y, ctx, e.body(ctx.role), .auto) }
	}
}

// ── Inline content ──────────────────────────────────────────────────

fn tv_split_words(s string, rstart int, st TvRunStyle, mut out []TvFrag) {
	mut i := 0
	for i < s.len {
		from := i
		if s[i] == ` ` {
			for i < s.len && s[i] == ` ` {
				i++
			}
			out << TvFrag{
				kind:   1
				text:   s[from..i]
				style:  st
				rstart: if rstart >= 0 { rstart + from } else { -1 }
			}
		} else {
			for i < s.len && s[i] != ` ` {
				i++
			}
			out << TvFrag{
				kind:   0
				text:   s[from..i]
				style:  st
				rstart: if rstart >= 0 { rstart + from } else { -1 }
			}
		}
	}
}

fn (mut e TvEngine) flatten(nodes []TextViewNode, st TvRunStyle, max_w f64, mut out []TvFrag) {
	for n in nodes {
		match n.kind {
			.text {
				tv_split_words(n.text, n.rendered_start, st, mut out)
			}
			.code_span {
				code := TvRunStyle{
					...st
					mono: true
					code: true
					size: st.size * e.style.code_scale
					role: if st.link >= 0 { TextViewRole.link } else { TextViewRole.code }
				}
				first := out.len
				tv_split_words(n.text, n.rendered_start, code, mut out)
				if out.len > first {
					pad := math.round(e.em * 0.3)
					out[first].pad_l = pad
					out[out.len - 1].pad_r = pad
				}
			}
			.soft_break {
				out << TvFrag{
					kind:   1
					text:   ' '
					style:  st
					rstart: n.rendered_start
				}
			}
			.hard_break {
				out << TvFrag{
					kind:  2
					style: st
				}
			}
			.emphasis {
				e.flatten(n.children, TvRunStyle{ ...st, italic: true }, max_w, mut out)
			}
			.strong {
				e.flatten(n.children, TvRunStyle{ ...st, bold: true }, max_w, mut out)
			}
			.strikethrough {
				e.flatten(n.children, TvRunStyle{ ...st, strike: true }, max_w, mut out)
			}
			.link {
				e.flatten(n.children, TvRunStyle{
					...st
					link: n.index
					role: .link
				}, max_w, mut out)
			}
			.image {
				info := e.image_info(n)
				w, h := tv_fit(info.width, info.height, max_w)
				out << TvFrag{
					kind:   3
					style:  st
					path:   info.path
					alt:    n.text
					rstart: n.rendered_start
					w:      w
					h:      h
				}
			}
			else {
				e.flatten(n.children, st, max_w, mut out)
			}
		}
	}
}

fn (e &TvEngine) measure(mut frags []TvFrag) {
	for mut f in frags {
		match f.kind {
			0 { f.w = e.adv(f.text, f.style) + f.pad_l + f.pad_r }
			1 { f.w = tv_space_width(e.run_style(f.style)) * f64(f.text.len) }
			else {}
		}
	}
}

// break_lines fills words into lines `width` wide, breaking at spaces. A word
// wider than a whole line is broken between characters.
fn (e &TvEngine) break_lines(frags []TvFrag, width f64) [][]TvPlaced {
	mut lines := [][]TvPlaced{}
	mut cur := []TvPlaced{}
	mut x := 0.0
	mut space := TvFrag{
		kind: -1
	}
	mut i := 0
	for i < frags.len {
		f := frags[i]
		if f.kind == 2 {
			lines << cur
			cur = []TvPlaced{}
			x = 0
			space = TvFrag{
				kind: -1
			}
			i++
			continue
		}
		if f.kind == 1 {
			if cur.len > 0 {
				space = f
			}
			i++
			continue
		}
		mut word := []TvFrag{}
		mut ww := 0.0
		for i < frags.len && (frags[i].kind == 0 || frags[i].kind == 3) {
			word << frags[i]
			ww += frags[i].w
			i++
		}
		mut sw := if cur.len > 0 && space.kind == 1 { space.w } else { 0.0 }
		if cur.len > 0 && x + sw + ww > width + 0.01 {
			lines << cur
			cur = []TvPlaced{}
			x = 0
			sw = 0
		}
		pending := space
		space = TvFrag{
			kind: -1
		}
		if cur.len == 0 && ww > width + 0.01 {
			pieces := e.split_word(word, width)
			for k, piece in pieces {
				for pf in piece {
					cur << TvPlaced{pf, x}
					x += pf.w
				}
				if k < pieces.len - 1 {
					lines << cur
					cur = []TvPlaced{}
					x = 0
				}
			}
			continue
		}
		if sw > 0 {
			cur << TvPlaced{pending, x}
			x += sw
		}
		for wf in word {
			cur << TvPlaced{wf, x}
			x += wf.w
		}
	}
	if cur.len > 0 {
		lines << cur
	}
	return lines
}

// split_word breaks a word too wide for a line between characters.
fn (e &TvEngine) split_word(word []TvFrag, width f64) [][]TvFrag {
	mut out := [][]TvFrag{}
	mut cur := []TvFrag{}
	mut x := 0.0
	for f in word {
		if f.kind != 0 || x + f.w <= width + 0.01 {
			if cur.len > 0 && x + f.w > width + 0.01 {
				out << cur
				cur = []TvFrag{}
				x = 0
			}
			cur << f
			x += f.w
			continue
		}
		mut piece_start := 0
		mut k := 0
		for k < f.text.len {
			n := utf8_char_len(f.text[k])
			next := tv_min_int(k + n, f.text.len)
			pad := if piece_start == 0 { f.pad_l } else { 0.0 }
			cw := e.adv(f.text[piece_start..next], f.style) + pad
			if x + cw > width + 0.01 && (k > piece_start || x > 0) {
				if k > piece_start {
					mut piece := TvFrag{
						...f
						text:   f.text[piece_start..k]
						rstart: if f.rstart >= 0 { f.rstart + piece_start } else { -1 }
						pad_l:  pad
						pad_r:  0
					}
					piece.w = e.adv(piece.text, f.style) + pad
					cur << piece
				}
				out << cur
				cur = []TvFrag{}
				x = 0
				piece_start = k
				continue
			}
			k = next
		}
		mut last := TvFrag{
			...f
			text:   f.text[piece_start..]
			rstart: if f.rstart >= 0 { f.rstart + piece_start } else { -1 }
			pad_l:  if piece_start == 0 { f.pad_l } else { 0.0 }
		}
		last.w = e.adv(last.text, f.style) + last.pad_l + last.pad_r
		cur << last
		x += last.w
	}
	if cur.len > 0 {
		out << cur
	}
	return out
}

// run_metrics is how far a run reaches above and below the baseline. Labels
// draw their text centred in their frame, so a run's frame is placed for its
// baseline to meet the line's (tv_baseline_ratio).
fn (e &TvEngine) run_metrics(r TvRun) (f64, f64) {
	if r.kind == 3 {
		return r.h, math.round(e.em * 0.3)
	}
	em := font_em_pixels(r.style.size)
	own := em * r.style.lh
	asc := own / 2 + tv_baseline_ratio(r.style.mono) * em
	return asc, own - asc
}

fn (e &TvEngine) runs_of(line []TvPlaced) []TvRun {
	mut runs := []TvRun{}
	for p in line {
		f := p.frag
		if f.kind == 3 {
			runs << TvRun{
				kind:   3
				style:  f.style
				w:      f.w
				h:      f.h
				path:   f.path
				alt:    f.alt
				rstart: f.rstart
			}
			continue
		}
		if runs.len > 0 {
			last := runs.last()
			if last.kind == 0 && last.style == f.style && last.pad_r == 0 && f.pad_l == 0
				&& (last.rstart < 0 || f.rstart < 0 || last.rstart + last.text.len == f.rstart) {
				runs[runs.len - 1].text += f.text
				runs[runs.len - 1].pad_r = f.pad_r
				continue
			}
		}
		runs << TvRun{
			kind:   0
			text:   f.text
			style:  f.style
			rstart: f.rstart
			pad_l:  f.pad_l
			pad_r:  f.pad_r
		}
	}
	mut x := 0.0
	for mut r in runs {
		if r.kind == 3 {
			r.x = x
			x += r.w
			continue
		}
		r.x = x + r.pad_l
		r.adv = e.adv(r.text, r.style)
		x = r.x + r.adv + r.pad_r
	}
	return runs
}

fn (e &TvEngine) line_extent(runs []TvRun, base TvRunStyle) (f64, f64) {
	mut asc := 0.0
	mut desc := 0.0
	if runs.len == 0 {
		return e.run_metrics(TvRun{
			style: base
		})
	}
	for r in runs {
		a, d := e.run_metrics(r)
		asc = math.max(asc, a)
		desc = math.max(desc, d)
	}
	return asc, desc
}

// emit_text adds the label for a run whose glyphs start at gx and whose text
// is centred on center_y.
fn (mut e TvEngine) emit_text(s string, rstart int, st TvRunStyle, gx f64, center_y f64, container int, align Align) f64 {
	ts := e.run_style(st)
	adv := tv_advance(s, ts)
	core := s.trim(' ')
	em := font_em_pixels(st.size)
	own := em * st.lh
	center := tv_snap(center_y)
	if core.len == 0 {
		// A run of spaces between two styled runs draws nothing, but a highlight
		// across it paints it.
		e.items << TextViewItem{
			kind:           .text
			frame:          rect(gx, center - own / 2, adv, own)
			text:           s
			text_x:         gx
			advance:        adv
			size:           st.size
			mono:           st.mono
			role:           st.role
			container:      container
			line:           e.lines.len
			rendered_start: rstart
			rendered_end:   if rstart >= 0 { rstart + s.len } else { -1 }
		}
		return adv
	}
	lead := s.len - s.trim_left(' ').len
	core_x := gx + tv_space_width(ts) * f64(lead)
	core_adv := tv_advance(core, ts)
	inset := tv_label_inset(ts)
	if st.code {
		bg_h := math.round(em * 1.45)
		bg_pad := math.round(e.em * 0.22)
		e.fill(rect(math.round(core_x - bg_pad), math.round(center - bg_h / 2), math.round(core_adv +
			2 * bg_pad), bg_h), .code_background, 4, container)
	}
	e.items << TextViewItem{
		kind:           .text
		frame:          rect(tv_snap(core_x - inset / 2), center - own / 2, core_adv + inset + 1,
			own)
		text:           s
		text_x:         gx
		advance:        adv
		size:           st.size
		bold:           st.bold
		italic:         st.italic
		mono:           st.mono
		underline:      st.link >= 0
		strike:         st.strike
		role:           st.role
		align:          align
		link:           st.link
		container:      container
		line:           e.lines.len
		rendered_start: rstart
		rendered_end:   if rstart >= 0 { rstart + s.len } else { -1 }
	}
	if st.strike {
		baseline := center + tv_baseline_ratio(st.mono) * em
		e.fill(rect(core_x, math.round(baseline - em * 0.3), core_adv, math.max(1, math.round(em / 14))),
			st.role, 0, container)
	}
	return adv
}

// emit_line places one broken line at y and returns where the next starts.
fn (mut e TvEngine) emit_line(line []TvPlaced, y f64, ctx TvCtx, align TextViewAlign, base TvRunStyle) f64 {
	runs := e.runs_of(line)
	asc, desc := e.line_extent(runs, base)
	line_h := math.ceil(asc + desc)
	baseline := y + asc
	mut line_w := 0.0
	if runs.len > 0 {
		last := runs.last()
		line_w = last.x + (if last.kind == 3 { last.w } else { last.adv + last.pad_r })
	}
	shift := match align {
		.right { math.max(0, ctx.width - line_w) }
		.center { math.max(0, (ctx.width - line_w) / 2) }
		else { 0.0 }
	}
	mut rstart := -1
	mut rend := -1
	for r in runs {
		gx := ctx.x + shift + r.x
		if r.kind == 3 {
			e.items << TextViewItem{
				kind:      .image
				frame:     rect(gx, baseline - r.h, r.w, r.h)
				path:      r.path
				alt:       r.alt
				link:      r.style.link
				container: ctx.container
			}
			continue
		}
		em := font_em_pixels(r.style.size)
		e.emit_text(r.text, r.rstart, r.style, gx, baseline - tv_baseline_ratio(r.style.mono) * em,
			ctx.container, .left)
		if r.rstart >= 0 {
			if rstart < 0 {
				rstart = r.rstart
			}
			rend = r.rstart + r.text.len
		}
	}
	e.lines << TextViewLine{
		frame:          rect(ctx.x, y, ctx.width, line_h)
		baseline:       baseline
		rendered_start: rstart
		rendered_end:   rend
		container:      ctx.container
	}
	return y + line_h
}

fn (mut e TvEngine) inline(nodes []TextViewNode, y f64, ctx TvCtx, st TvRunStyle, align TextViewAlign) f64 {
	mut frags := []TvFrag{}
	e.flatten(nodes, st, ctx.width, mut frags)
	return e.place(mut frags, y, ctx, st, align)
}

fn (mut e TvEngine) inline_text(s string, rstart int, y f64, ctx TvCtx, st TvRunStyle) f64 {
	mut frags := []TvFrag{}
	tv_split_words(s, rstart, st, mut frags)
	return e.place(mut frags, y, ctx, st, .auto)
}

fn (mut e TvEngine) place(mut frags []TvFrag, y f64, ctx TvCtx, st TvRunStyle, align TextViewAlign) f64 {
	if frags.len == 0 {
		return y
	}
	e.measure(mut frags)
	mut cy := y
	for line in e.break_lines(frags, ctx.width) {
		cy = e.emit_line(line, cy, ctx, align, st)
	}
	return cy
}

// ── Blocks ──────────────────────────────────────────────────────────

struct TvLoneImage {
	image TextViewNode
	link  int
}

// tv_lone_image finds a paragraph that is nothing but an image (or a linked
// image), which is laid out as a block.
fn tv_lone_image(nodes []TextViewNode) ?TvLoneImage {
	mut found := []TextViewNode{}
	for n in nodes {
		if n.kind == .text && n.text.trim_space().len == 0 {
			continue
		}
		found << n
	}
	if found.len != 1 {
		return none
	}
	n := found[0]
	if n.kind == .image {
		return TvLoneImage{n, -1}
	}
	if n.kind == .link {
		inner := tv_lone_image(n.children)?
		return TvLoneImage{inner.image, n.index}
	}
	return none
}

fn (mut e TvEngine) paragraph(n TextViewNode, y f64, ctx TvCtx) f64 {
	if lone := tv_lone_image(n.children) {
		return e.block_image(lone.image, lone.link, y, ctx)
	}
	return e.inline(n.children, y, ctx, e.body(ctx.role), .auto)
}

fn (mut e TvEngine) heading(n TextViewNode, y f64, ctx TvCtx) f64 {
	st := TvRunStyle{
		size: e.style.font_size * text_view_heading_scale(e.style, n.level)
		bold: true
		role: if n.level >= 6 { TextViewRole.muted } else { ctx.role }
		lh:   1.3
	}
	mut bottom := e.inline(n.children, y, ctx, st, .auto)
	if bottom <= y {
		bottom = y + math.ceil(font_em_pixels(st.size) * st.lh)
	}
	if n.level <= 2 {
		rule_y := bottom + math.round(e.em * 0.35)
		e.fill(rect(ctx.x, rule_y, ctx.width, 1), .border, 0, ctx.container)
		bottom = rule_y + 1
	}
	return bottom
}

fn (mut e TvEngine) quote(n TextViewNode, y f64, ctx TvCtx) f64 {
	bar := math.max(2, math.round(e.em * 0.25))
	indent := bar + math.round(e.em * 0.9)
	inner := TvCtx{
		...ctx
		x:     ctx.x + indent
		width: math.max(ctx.width - indent, e.em)
		role:  .muted
	}
	mut bottom := e.blocks(n.children, y, inner)
	if bottom <= y {
		bottom = y + e.lh
	}
	e.fill(rect(ctx.x, y, bar, bottom - y), .quote_bar, bar / 2, ctx.container)
	return bottom
}

fn (mut e TvEngine) list_block(n TextViewNode, y f64, ctx TvCtx) f64 {
	body := e.body(ctx.role)
	mut marker_w := math.round(e.em * 1.5)
	if n.ordered {
		last := n.start + n.children.len - 1
		marker_w = math.max(marker_w, math.ceil(e.adv('${last}.', body) + e.em * 0.6))
	}
	for item in n.children {
		if item.task != .plain {
			marker_w = math.max(marker_w, math.round(e.em * 1.75))
			break
		}
	}
	gap := if n.tight { math.round(e.em * 0.3) } else { math.round(e.em * e.style.block_gap) }
	mut cy := y
	for k, item in n.children {
		top := if k == 0 { cy } else { cy + gap }
		inner := TvCtx{
			...ctx
			x:     ctx.x + marker_w
			width: math.max(ctx.width - marker_w, e.em)
			tight: n.tight
			depth: ctx.depth + 1
		}
		first_line := e.lines.len
		mut bottom := e.blocks(item.children, top, inner)
		mut baseline := top + e.lh / 2 + tv_baseline_ratio(false) * e.em
		if e.lines.len > first_line && e.lines[first_line].rendered_start >= 0 {
			baseline = e.lines[first_line].baseline
		}
		if bottom <= top {
			bottom = top + e.lh
		}
		e.marker(n, item, k, ctx, marker_w, baseline)
		cy = bottom
	}
	return cy
}

fn (mut e TvEngine) marker(list_node TextViewNode, item TextViewNode, k int, ctx TvCtx, marker_w f64, baseline f64) {
	center := baseline - 0.3 * e.em
	if item.task != .plain {
		side := math.round(e.em * 1.05)
		e.items << TextViewItem{
			kind:      .check
			frame:     rect(ctx.x + math.round((marker_w - side) / 2 - e.em * 0.2), math.round(center - side / 2),
				side, side)
			checked:   item.task == .checked
			radius:    math.round(side / 4)
			container: ctx.container
		}
		return
	}
	if list_node.ordered {
		number := '${list_node.start + k}.'
		st := e.body(ctx.role)
		advance := e.adv(number, st)
		gx := ctx.x + marker_w - math.round(e.em * 0.45) - advance
		e.emit_text(number, -1, st, gx, baseline - tv_baseline_ratio(false) * e.em, ctx.container,
			.left)
		return
	}
	d := math.max(4, math.round(e.em * 0.38))
	bx := ctx.x + math.round((marker_w - d) / 2 - e.em * 0.2)
	by := math.round(center - d / 2)
	match ctx.depth % 3 {
		0 {
			e.fill(rect(bx, by, d, d), ctx.role, d / 2, ctx.container)
		}
		1 {
			ring := math.max(1, math.round(d / 4))
			e.fill(rect(bx, by, d, d), ctx.role, d / 2, ctx.container)
			e.fill(rect(bx + ring, by + ring, d - 2 * ring, d - 2 * ring), .background, d / 2 - ring,
				ctx.container)
		}
		else {
			e.fill(rect(bx, by, d, d), ctx.role, 1, ctx.container)
		}
	}
}

fn (mut e TvEngine) rule(y f64, ctx TvCtx) f64 {
	gap := math.round(e.em * 0.5)
	e.fill(rect(ctx.x, y + gap, ctx.width, 2), .border, 1, ctx.container)
	return y + 2 * gap + 2
}

fn (e &TvEngine) plugin_for(lang string) ?TextViewBlockPlugin {
	if lang.len == 0 {
		return none
	}
	for p in e.plugins {
		if p.name.to_lower() == lang.to_lower() {
			return p
		}
	}
	return none
}

fn (mut e TvEngine) plugin_block(p TextViewBlockPlugin, n TextViewNode, y f64, ctx TvCtx) f64 {
	block := TextViewPluginBlock{
		index: n.index
		name:  p.name
		info:  n.info
		code:  n.text
		width: ctx.width
	}
	mut h := if p.height != unsafe { nil } { p.height(block) } else { 160.0 }
	if !component_finite(h) || h < 0 {
		h = 0
	}
	e.items << TextViewItem{
		kind:      .plugin
		frame:     rect(ctx.x, y, ctx.width, h)
		text:      p.name
		block:     n.index
		container: ctx.container
	}
	e.lines << TextViewLine{
		frame:     rect(ctx.x, y, ctx.width, h)
		baseline:  y + h
		container: ctx.container
	}
	return y + h
}

fn (mut e TvEngine) code(n TextViewNode, y f64, ctx TvCtx) f64 {
	if p := e.plugin_for(n.lang) {
		return e.plugin_block(p, n, y, ctx)
	}
	size := e.style.font_size * e.style.code_scale
	cem := font_em_pixels(size)
	line_h := math.round(cem * 1.6)
	st := TvRunStyle{
		size: size
		mono: true
		role: .code_block
		lh:   line_h / cem
	}
	pad := math.round(e.em * 0.85)
	pad_v := math.round(e.em * 0.65)
	header_h := if e.header { math.round(e.em * 2.15) } else { 0.0 }
	x := ctx.x
	w := ctx.width
	wrap := e.style.wrap_code
	text_w := math.max(w - 2 * pad, e.em)
	mut wrapped := [][][]TvPlaced{}
	mut rows := 0
	mut max_w := 0.0
	for ln in n.children {
		if wrap {
			mut frags := []TvFrag{}
			tv_split_words(tv_display(ln.text), ln.rendered_start, st, mut frags)
			e.measure(mut frags)
			broken := e.break_lines(frags, text_w)
			wrapped << broken
			rows += tv_max_int(broken.len, 1)
		} else {
			max_w = math.max(max_w, e.adv(ln.text, st))
			rows++
		}
	}
	rows = tv_max_int(rows, 1)
	content_w := max_w + 2 * pad
	scrolls := !wrap && content_w > w - 2
	// A block that scrolls sideways keeps room under its last line for the
	// scroller, so the scroller never covers code.
	bar := if scrolls { math.round(e.em * 0.5) } else { 0.0 }
	box_h := header_h + 2 * pad_v + f64(rows) * line_h + bar
	e.fill(rect(x, y, w, box_h), .code_border, 6, ctx.container)
	e.fill(rect(x + 1, y + 1, w - 2, box_h - 2), .code_background, 5, ctx.container)
	if header_h > 0 {
		e.items << TextViewItem{
			kind:      .code_header
			frame:     rect(x + 1, y + 1, w - 2, header_h - 1)
			text:      n.lang
			block:     n.index
			container: ctx.container
		}
		e.fill(rect(x + 1, y + header_h, w - 2, 1), .code_border, 0, ctx.container)
	}
	body_top := y + header_h + pad_v
	mut container := ctx.container
	if scrolls {
		container = e.items.len
		e.items << TextViewItem{
			kind:          .container
			frame:         rect(x + 1, y + header_h + 1, w - 2, box_h - header_h - 2)
			content_width: math.ceil(content_w)
			block:         n.index
			role:          .code_background
			container:     ctx.container
		}
	}
	mut cy := body_top
	for i, ln in n.children {
		if wrap {
			broken := wrapped[i]
			if broken.len == 0 {
				cy += line_h
				continue
			}
			for line in broken {
				cy = e.emit_line(line, cy, TvCtx{
					x:         x + pad
					width:     text_w
					container: container
				}, .auto, st)
			}
			continue
		}
		e.emit_text(ln.text, ln.rendered_start, st, x + pad, cy + line_h / 2, container,
			.left)
		e.lines << TextViewLine{
			frame:          rect(x + pad, cy, w - 2 * pad, line_h)
			baseline:       cy + line_h / 2 + tv_baseline_ratio(true) * cem
			rendered_start: ln.rendered_start
			rendered_end:   ln.rendered_end
			container:      container
		}
		cy += line_h
	}
	return y + box_h
}

fn (mut e TvEngine) table_block(n TextViewNode, y f64, ctx TvCtx) f64 {
	rows := n.children
	mut columns := 0
	for row in rows {
		columns = tv_max_int(columns, row.children.len)
	}
	if columns == 0 {
		return y
	}
	padx := math.round(e.em * 0.75)
	pady := math.round(e.em * 0.4)
	mut natural := []f64{len: columns, init: 2 * padx + e.em * 2}
	mut least := []f64{len: columns, init: 2 * padx + e.em * 2}
	mut cell_frags := [][][]TvFrag{}
	for row in rows {
		mut row_frags := [][]TvFrag{}
		for c, cell in row.children {
			mut frags := []TvFrag{}
			e.flatten(cell.children, e.cell_style(row, ctx), 1e9, mut frags)
			e.measure(mut frags)
			line_w, word_w := tv_extent(frags)
			natural[c] = math.max(natural[c], math.ceil(line_w) + 2 * padx)
			least[c] = math.max(least[c], math.ceil(math.min(word_w, e.em * 12)) + 2 * padx)
			row_frags << frags
		}
		cell_frags << row_frags
	}
	mut widths := natural.clone()
	avail := ctx.width - 1
	mut sum_nat := 0.0
	mut sum_min := 0.0
	for c in 0 .. columns {
		sum_nat += natural[c]
		sum_min += least[c]
	}
	if sum_nat > avail {
		if sum_min >= avail || sum_nat <= sum_min {
			widths = least.clone()
		} else {
			k := (avail - sum_min) / (sum_nat - sum_min)
			for c in 0 .. columns {
				widths[c] = math.floor(least[c] + (natural[c] - least[c]) * k)
			}
		}
	}
	mut table_w := 1.0
	for c in 0 .. columns {
		table_w += widths[c]
	}
	// Lines of every cell first: the row heights size the container and fills.
	mut broken := [][][][]TvPlaced{}
	mut row_heights := []f64{}
	for r, row in rows {
		mut row_lines := [][][]TvPlaced{}
		mut h := e.lh
		for c, _ in row.children {
			lines := e.break_lines(cell_frags[r][c], widths[c] - 2 * padx)
			mut cell_h := 0.0
			for line in lines {
				asc, desc := e.line_extent(e.runs_of(line), e.cell_style(row, ctx))
				cell_h += math.ceil(asc + desc)
			}
			h = math.max(h, cell_h)
			row_lines << lines
		}
		broken << row_lines
		row_heights << math.ceil(h + 2 * pady)
	}
	mut table_h := 1.0
	for h in row_heights {
		table_h += h
	}
	table_index := e.tables
	e.tables++
	mut container := ctx.container
	if table_w > ctx.width + 0.5 {
		container = e.items.len
		e.items << TextViewItem{
			kind:          .container
			frame:         rect(ctx.x, y, ctx.width, table_h)
			content_width: table_w
			role:          .background
			block:         table_index
			container:     ctx.container
		}
	}
	x := ctx.x
	// Row backgrounds, then the grid over them.
	mut ry := y + 1
	mut body_row := 0
	for r, row in rows {
		if row.header {
			e.fill(rect(x + 1, ry, table_w - 2, row_heights[r]), .table_header, 0, container)
		} else {
			if body_row % 2 == 1 {
				e.fill(rect(x + 1, ry, table_w - 2, row_heights[r]), .table_stripe, 0, container)
			}
			body_row++
		}
		ry += row_heights[r]
	}
	e.fill(rect(x, y, table_w, 1), .border, 0, container)
	ry = y + 1
	for h in row_heights {
		ry += h
		e.fill(rect(x, ry - 1, table_w, 1), .border, 0, container)
	}
	mut cx := x
	for c in 0 .. columns + 1 {
		e.fill(rect(cx, y, 1, table_h), .border, 0, container)
		if c < columns {
			cx += widths[c]
		}
	}
	ry = y + 1
	for r, row in rows {
		mut cell_x := x + 1
		for c, cell in row.children {
			mut cy := ry + pady
			for line in broken[r][c] {
				cy = e.emit_line(line, cy, TvCtx{
					x:         cell_x + padx - 1
					width:     widths[c] - 2 * padx
					container: container
				}, cell.align, e.cell_style(row, ctx))
			}
			cell_x += widths[c]
		}
		ry += row_heights[r]
	}
	return y + table_h
}

fn (e &TvEngine) cell_style(row TextViewNode, ctx TvCtx) TvRunStyle {
	return TvRunStyle{
		...e.body(ctx.role)
		bold: row.header
	}
}

// tv_extent is how wide inline content is on one line, and its widest word.
fn tv_extent(frags []TvFrag) (f64, f64) {
	mut line := 0.0
	mut widest_line := 0.0
	mut word := 0.0
	mut widest_word := 0.0
	for f in frags {
		match f.kind {
			2 {
				widest_line = math.max(widest_line, line)
				line = 0
				widest_word = math.max(widest_word, word)
				word = 0
			}
			1 {
				line += f.w
				widest_word = math.max(widest_word, word)
				word = 0
			}
			else {
				line += f.w
				word += f.w
			}
		}
	}
	return math.max(widest_line, line), math.max(widest_word, word)
}

fn (mut e TvEngine) frontmatter(n TextViewNode, y f64, ctx TvCtx) f64 {
	pad := math.round(e.em * 0.75)
	size := e.style.font_size * 0.92
	key_style := TvRunStyle{
		size: size
		bold: true
		role: .muted
		lh:   e.style.line_height
	}
	value_style := TvRunStyle{
		size: size
		role: ctx.role
		lh:   e.style.line_height
	}
	mut key_w := 0.0
	for entry in n.entries {
		key_w = math.max(key_w, e.adv(entry.key, key_style))
	}
	inner_w := math.max(ctx.width - 2 * pad, e.em)
	key_w = math.ceil(math.min(key_w + e.em, inner_w * 0.4))
	mark := e.items.len
	mut cy := y + pad
	for i, entry in n.entries {
		if i > 0 {
			cy += math.round(e.em * 0.2)
		}
		key_bottom := e.inline_text(entry.key, entry.key_start, cy, TvCtx{
			x:         ctx.x + pad
			width:     math.max(key_w - e.em * 0.5, e.em)
			container: ctx.container
		}, key_style)
		value_bottom := e.inline_text(entry.value, entry.value_start, cy, TvCtx{
			x:         ctx.x + pad + key_w
			width:     math.max(inner_w - key_w, e.em)
			container: ctx.container
		}, value_style)
		cy = math.max(math.max(key_bottom, value_bottom), cy + e.lh)
	}
	h := cy + pad - y
	e.items.insert(mark, TextViewItem{
		kind:      .fill
		frame:     rect(ctx.x, y, ctx.width, h)
		role:      .code_background
		radius:    6
		container: ctx.container
	})
	return y + h
}

fn (e &TvEngine) image_info(n TextViewNode) TextViewImage {
	info := if e.images != unsafe { nil } {
		e.images(n.url, n.text)
	} else {
		TextViewImage{
			path: tv_default_image_path(n.url)
		}
	}
	mut w := if info.width > 0 { info.width } else { n.width }
	mut h := if info.height > 0 { info.height } else { n.height }
	ratio := e.style.image_height / math.max(e.style.image_width, 1)
	if w <= 0 && h <= 0 {
		w = e.style.image_width
		h = e.style.image_height
	} else if w <= 0 {
		w = h / ratio
	} else if h <= 0 {
		h = w * ratio
	}
	return TextViewImage{
		path:   info.path
		width:  w
		height: h
	}
}

// tv_default_image_path loads local paths as they are and leaves remote and
// data URLs to a placeholder.
fn tv_default_image_path(src string) string {
	lower := src.to_lower()
	if lower.starts_with('http://') || lower.starts_with('https://') || lower.starts_with('data:') {
		return ''
	}
	if lower.starts_with('file://') {
		return src['file://'.len..]
	}
	return src
}

fn tv_fit(w f64, h f64, max_w f64) (f64, f64) {
	if !component_finite(w) || !component_finite(h) || w <= 0 || h <= 0 {
		return 0, 0
	}
	if w <= max_w || max_w <= 0 {
		return math.round(w), math.round(h)
	}
	return math.round(max_w), math.round(h * max_w / w)
}

fn (mut e TvEngine) block_image(img TextViewNode, link int, y f64, ctx TvCtx) f64 {
	info := e.image_info(img)
	w, h := tv_fit(info.width, info.height, ctx.width)
	e.items << TextViewItem{
		kind:      .image
		frame:     rect(ctx.x, y, w, h)
		path:      info.path
		alt:       img.text
		link:      link
		container: ctx.container
	}
	e.lines << TextViewLine{
		frame:     rect(ctx.x, y, ctx.width, h)
		baseline:  y + h
		container: ctx.container
	}
	return y + h
}

// ── Clamping ────────────────────────────────────────────────────────

struct TvBand {
mut:
	top    f64
	bottom f64
}

// tv_clamp keeps the first max_lines lines. Lines side by side (table cells, a
// list marker and its text) count once. A line is never cut in half; boxes
// that reach past the last line (code blocks, quote bars, table grids) are cut
// at it, and the last line kept ends in an ellipsis.
fn tv_clamp(lay TextViewLayout, max_lines int) TextViewLayout {
	mut sorted := lay.lines.clone()
	sorted.sort_with_compare(fn (a &TextViewLine, b &TextViewLine) int {
		if a.frame.y < b.frame.y {
			return -1
		}
		if a.frame.y > b.frame.y {
			return 1
		}
		return 0
	})
	mut bands := []TvBand{}
	for ln in sorted {
		bottom := ln.frame.y + ln.frame.height
		if bands.len > 0 && ln.frame.y < bands.last().bottom - 0.5 {
			bands[bands.len - 1].bottom = math.max(bands.last().bottom, bottom)
			continue
		}
		bands << TvBand{ln.frame.y, bottom}
	}
	if bands.len <= max_lines {
		return lay
	}
	cutoff := bands[max_lines - 1].bottom
	mut lines := []TextViewLine{}
	mut line_map := map[int]int{}
	for i, ln in lay.lines {
		if ln.frame.y < cutoff - 0.5 {
			line_map[i] = lines.len
			lines << ln
		}
	}
	mut items := []TextViewItem{}
	mut index_map := map[int]int{}
	for i, item in lay.items {
		top := item.frame.y
		bottom := top + item.frame.height
		if top >= cutoff - 0.5 {
			continue
		}
		if item.kind in [TextViewItemKind.text, .image, .check] {
			if item.kind == .text {
				if item.line !in line_map {
					continue
				}
			} else if bottom > cutoff + 1 {
				continue
			}
		}
		mut kept := item
		if item.kind in [TextViewItemKind.fill, .container, .plugin, .code_header]
			&& bottom > cutoff {
			kept = TextViewItem{
				...item
				frame: rect(item.frame.x, top, item.frame.width, math.max(0, cutoff - top))
			}
		}
		if item.kind == .text {
			kept = TextViewItem{
				...kept
				line: line_map[item.line]
			}
		}
		if item.container >= 0 {
			if item.container !in index_map {
				continue
			}
			kept = TextViewItem{
				...kept
				container: index_map[item.container]
			}
		}
		index_map[i] = items.len
		items << kept
	}
	tv_add_ellipsis(mut items, lines, lay.style)
	return TextViewLayout{
		...lay
		height:  math.ceil(cutoff + lay.style.padding)
		clamped: true
		items:   items
		lines:   lines
	}
}

fn tv_add_ellipsis(mut items []TextViewItem, lines []TextViewLine, style TextViewStyle) {
	mut last_line := -1
	for i := lines.len - 1; i >= 0; i-- {
		if lines[i].rendered_start >= 0 {
			last_line = i
			break
		}
	}
	if last_line < 0 {
		return
	}
	mut target := -1
	for i, item in items {
		if item.kind == .text && item.line == last_line && item.text.trim_space().len > 0
			&& (target < 0 || item.text_x > items[target].text_x) {
			target = i
		}
	}
	if target < 0 {
		return
	}
	item := items[target]
	ln := lines[last_line]
	ts := tv_text_style(item.size, item.bold, item.italic, item.mono, style)
	right := ln.frame.x + ln.frame.width
	mut kept := item.text.trim_right(' ')
	for kept.len > 0 && item.text_x + tv_advance(kept + '…', ts) > right {
		mut cut := kept.len - 1
		for cut > 0 && kept[cut] & 0xc0 == 0x80 {
			cut--
		}
		kept = kept[..cut].trim_right(' ')
	}
	shown := kept + '…'
	core := shown.trim_left(' ')
	lead := shown.len - core.len
	core_x := item.text_x + tv_space_width(ts) * f64(lead)
	core_adv := tv_advance(core, ts)
	inset := tv_label_inset(ts)
	items[target] = TextViewItem{
		...item
		text:         shown
		advance:      tv_advance(shown, ts)
		frame:        rect(core_x - inset / 2, item.frame.y, core_adv + inset + 1, item.frame.height)
		rendered_end: item.rendered_start + kept.len
		ellipsis:     true
	}
}

// ── Reveal ──────────────────────────────────────────────────────────

// range_rect is the line a range of rendered text starts on, in document
// coordinates, as GPUI Kit's reveal_range scrolls to it. An empty range gives
// the line of its position, and one in the break between blocks the next
// line. None for an invalid range or one on a line the clamp left out.
pub fn (lay TextViewLayout) range_rect(start int, end int) ?Rect {
	if !text_view_valid_range(lay.document.text, start, end) {
		return none
	}
	for ln in lay.lines {
		if ln.rendered_start >= 0 && start >= ln.rendered_start && start < ln.rendered_end {
			return ln.frame
		}
	}
	if start == end {
		for ln in lay.lines {
			if ln.rendered_start >= 0 && start == ln.rendered_end {
				return ln.frame
			}
		}
	}
	for ln in lay.lines {
		if ln.rendered_start >= start {
			return ln.frame
		}
	}
	return none
}

// text_view_reveal_offset is the scroll offset that brings the line a range
// starts on into view, or none when it is already visible. `top` is where the
// text view sits in the scroll content, `viewport` the scroll view's height
// and `offset` its current offset (scroll_offset(id)).
pub fn text_view_reveal_offset(lay TextViewLayout, start int, end int, top f64, viewport f64, offset f64) ?f64 {
	r := lay.range_rect(start, end)?
	line_top := top + r.y
	line_bottom := line_top + r.height
	if line_top >= offset && line_bottom <= offset + viewport {
		return none
	}
	margin := math.min(r.height * 2, viewport / 4)
	if line_top < offset || r.height > viewport {
		return math.max(0, line_top - margin)
	}
	return math.max(0, line_bottom - viewport + margin)
}
