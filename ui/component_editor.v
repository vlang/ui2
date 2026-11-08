module ui2

import math

// A code editor after GPUI Kit's Editor, composed from what ui2 already has: a
// rich text area (the native text view on AppKit) holds and edits the text,
// colored by the runs code_highlight_runs makes, inside a scroll together with a
// gutter of line numbers, fold markers and diagnostic markers, so the two
// scroll as one. The text area is sized to its content (it never scrolls on
// its own), which is what keeps the gutter beside its lines.
//
// The application owns the text, the selection, the search and the completion
// state, as with every ui2 component, and applies the edits the editing
// helpers return (code_editor_command, code_editor_after_input, ...).

// CodeEditorConfig is everything the editor draws from. Build it from the
// application's model in one function and use it both to build the editor and
// to run commands, keys and events against.
pub struct CodeEditorConfig {
pub:
	id    string
	frame Rect
	text  string
	// selection is the text area's selection in runes, as the application last
	// read it (code_editor_selection_from_native). The current line, the caret
	// the custom renderer needs drawn, and where completions open come from it.
	selection TextSelection
	focused   bool // The text area has focus: focused_text_area_id() == code_editor_text_id(id).
	language  CodeLanguage
	rules     ?CodeLanguageRules // Replaces the language's editing rules.
	// Editing preferences, as in CodeEditSettings.
	tab_size     int = 4
	hard_tabs    bool
	auto_close   bool = true
	smart_indent bool = true
	// Options.
	line_numbers       bool = true
	folding            bool // Fold markers in the gutter (see code_fold_ranges).
	soft_wrap          bool // Wrap long lines; off scrolls them sideways.
	read_only          bool // Selectable, searchable and copyable, but not editable.
	disabled           bool
	highlight          bool = true // Syntax colors.
	current_line       bool = true // Tint the line the caret is on.
	indent_guides      bool = true
	inline_diagnostics bool // Show each line's first diagnostic message after its text.
	bordered           bool = true
	placeholder        string
	font_family        string // Empty picks the platform's monospace face (code_editor_font_family).
	font_size          f64 = 13
	line_height        f64 // Zero uses the line height the text area lays lines out at.
	size               ComponentSize = .medium // Padding round the code, as upstream's sizes.
	theme              CodeEditorTheme
	// Annotations.
	diagnostics []CodeDiagnostic
	decorations []CodeDecoration
	// Search: the matches of search.query are highlighted while search.open, and
	// the built-in bar shows unless search_bar is off, which is how an
	// application draws a search UI of its own over the same engine.
	search      CodeSearchState
	search_bar  bool          = true
	search_size ComponentSize = .small
	label       string // Accessibility label; `Code editor` when empty.
}

// code_editor_text_id is the id of the editor's text area: pass it to text(),
// set_text(), focus(), text_area_caret(), text_area_set_selection() and
// insert_text_area_text(). It is also the action the text area emits on every
// edit.
pub fn code_editor_text_id(id string) string {
	return component_part_id(id, 'text')
}

// code_editor_scroll_id is the id of the scroll the gutter and the text move
// in, for scroll_offset() and scroll_to_rect().
pub fn code_editor_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

// code_editor_hscroll_id is the id of the sideways scroll the text moves in
// without soft wrap.
pub fn code_editor_hscroll_id(id string) string {
	return component_part_id(id, 'hscroll')
}

// code_editor_font_family is the monospace face the editor uses when none is
// set: Menlo on Apple platforms, Consolas on Windows, and the custom
// renderer's bundled monospace face elsewhere.
pub fn code_editor_font_family() string {
	$if macos || ios {
		return 'Menlo'
	} $else $if windows {
		return 'Consolas'
	} $else {
		return 'monospace'
	}
}

// code_editor_text_style is the base style of the code: the font, its size and
// the theme's foreground.
pub fn code_editor_text_style(config CodeEditorConfig) TextStyle {
	return TextStyle{
		color:       config.theme.foreground
		size:        if config.font_size > 0 { config.font_size } else { 13 }
		font_family: if config.font_family.len > 0 {
			config.font_family
		} else {
			code_editor_font_family()
		}
		valign:      .top
		lines:       0
	}
}

// ── Metrics ───────────────────────────────────────────────────────────────

// CodeEditorMetrics describe how the text area lays code out, which is what
// everything drawn beside or over the text has to follow: the line pitch, the
// advance of a character, where the first line and column start inside the
// text area, and its tab stops.
pub struct CodeEditorMetrics {
pub:
	line_height f64
	char_width  f64
	inset_top   f64 // From the text area's top edge to its first line.
	inset_left  f64 // From the text area's left edge to column 0.
	inset_right f64 // What the text area keeps free at its right edge.
	tab_stop    f64 // The distance between tab stops; zero when a tab is tab_advance wide.
	tab_advance f64
}

// Backend facts. The text area's padding_left is set to this inset, which the
// custom renderer honors and AppKit's line fragment padding already is.
const code_editor_text_inset = 5.0
const code_editor_custom_inset_top = 8.0 // The custom renderer's text_area_vertical_padding.
const code_editor_appkit_tab_stop = 28.0 // NSParagraphStyle's default tab stops.

// code_editor_overlays_on_top reports whether marks that belong under the
// text (the current-line tint, indent guides, the placeholder) have to be laid
// over the text area instead: the custom renderer paints a text area's
// background whatever its box says, so nothing beneath it shows, while it does
// not hit-test plain views, so a translucent tint on top costs nothing. On
// AppKit the transparent text view shows what lies beneath, and a view on top
// would take its clicks.
fn code_editor_overlays_on_top() bool {
	$if ui2_custom_rendering ? {
		return true
	} $else $if linux || freebsd || openbsd || netbsd || dragonfly || solaris || android {
		return true
	} $else {
		return false
	}
}

// code_editor_scroll_bottom_inset is the room the custom renderer's Scroll
// element adds below its content (AppKit's adds none).
fn code_editor_scroll_bottom_inset() f64 {
	return if code_editor_overlays_on_top() { 16.0 } else { 0.0 }
}

// code_editor_backend_draws_caret reports whether the text area draws its own
// caret. The custom renderer's text area does not (it shows a selection but no
// insertion point), so the editor draws one there.
fn code_editor_backend_draws_caret() bool {
	return !code_editor_overlays_on_top()
}

// code_editor_font_ems are a face's ascender, descender and leading in ems, as
// AppKit lays lines out with them: each rounded to a point, then added.
fn code_editor_font_ems(family string) (f64, f64, f64) {
	return match family.to_lower() {
		'monaco' { 1.0, 0.25, 0.0835 }
		'courier new', 'couriernewpsmt' { 0.83252, 0.30029, 0.0 }
		else { // Menlo, which AppKit also gives `monospace`.
			0.928223, 0.235840, 0.0
		}
	}
}

// code_editor_backend_line_height is the line pitch of the text area that
// draws the code. AppKit and UIKit lay a line out at the font's rounded
// ascender, descender and leading; the custom renderer at 1.25 em. Windows
// gets an estimate.
fn code_editor_backend_line_height(style TextStyle) f64 {
	$if ui2_custom_rendering ? {
		return font_line_height(style.size)
	} $else $if linux || freebsd || openbsd || netbsd || dragonfly || solaris || android {
		return font_line_height(style.size)
	} $else $if macos || ios {
		asc, desc, lead := code_editor_font_ems(style.font_family)
		return math.round(asc * style.size) + math.round(desc * style.size) +
			math.round(lead * style.size)
	} $else {
		return math.round(font_em_pixels(style.size) * 1.17)
	}
}

// code_editor_char_width is the advance of one character of the editor's face,
// measured by the backend (an estimate before a window runs). The difference
// of two widths cancels the inset measure_text_width includes.
fn code_editor_char_width(style TextStyle) f64 {
	wide := measure_text_width('0'.repeat(60), style)
	narrow := measure_text_width('0'.repeat(10), style)
	width := (wide - narrow) / 50.0
	return if width > 0 { width } else { font_em_pixels(style.size) * 0.6 }
}

// code_editor_metrics returns how the running backend lays the editor's code
// out.
pub fn code_editor_metrics(config CodeEditorConfig) CodeEditorMetrics {
	style := code_editor_text_style(config)
	char_width := code_editor_char_width(style)
	line_height := if config.line_height > 0 {
		config.line_height
	} else {
		math.max(1.0, code_editor_backend_line_height(style))
	}
	$if ui2_custom_rendering ? {
		return code_editor_custom_metrics(style, line_height, char_width)
	} $else $if linux || freebsd || openbsd || netbsd || dragonfly || solaris || android {
		return code_editor_custom_metrics(style, line_height, char_width)
	} $else $if macos || ios {
		return CodeEditorMetrics{
			line_height: line_height
			char_width:  char_width
			inset_top:   $if ios { 8.0 } $else { 0.0 }
			inset_left:  code_editor_text_inset
			inset_right: code_editor_text_inset
			tab_stop:    code_editor_appkit_tab_stop
		}
	} $else {
		return CodeEditorMetrics{
			line_height: line_height
			char_width:  char_width
			inset_top:   1
			inset_left:  code_editor_text_inset
			inset_right: code_editor_text_inset
			tab_stop:    8 * char_width
		}
	}
}

fn code_editor_custom_metrics(style TextStyle, line_height f64, char_width f64) CodeEditorMetrics {
	tab := measure_text_width('0\t0', style) - measure_text_width('00', style)
	return CodeEditorMetrics{
		line_height: line_height
		char_width:  char_width
		inset_top:   code_editor_custom_inset_top
		inset_left:  code_editor_text_inset
		inset_right: 8
		tab_advance: if tab > 0 { tab } else { char_width }
	}
}

fn code_wide_rune(r rune) bool {
	return (r >= 0x1100 && r <= 0x115f) || (r >= 0x2e80 && r <= 0xa4cf) || (r >= 0xac00
		&& r <= 0xd7a3) || (r >= 0xf900 && r <= 0xfaff) || (r >= 0xfe30 && r <= 0xfe4f)
		|| (r >= 0xff00 && r <= 0xff60) || (r >= 0xffe0 && r <= 0xffe6) || r >= 0x1f300
}

// advance moves an x offset (from column 0) past one character.
fn (m CodeEditorMetrics) advance(x f64, r rune) f64 {
	if r == `\t` {
		if m.tab_stop > 0 {
			return (math.floor((x + 0.01) / m.tab_stop) + 1) * m.tab_stop
		}
		return x + m.tab_advance
	}
	return x + if code_wide_rune(r) { 2 * m.char_width } else { m.char_width }
}

// prefix_width is how far into a line its first `count` characters reach.
fn (m CodeEditorMetrics) prefix_width(runes []rune, start int, count int) f64 {
	mut x := 0.0
	for k in start .. start + count {
		x = m.advance(x, runes[k])
	}
	return x
}

// ── Layout ────────────────────────────────────────────────────────────────

struct CodeEditorRow {
	line  int // logical line
	start int // rune offset of the row's first character
	end   int // rune offset past its last character (before a newline)
}

struct CodeEditorLayout {
	metrics     CodeEditorMetrics
	runes       []rune
	line_starts []int
	rows        []CodeEditorRow // visual rows, in order
	first_row   []int           // the first row of each logical line, plus the total
	border      f64
	viewport    Rect // inside the border, in the editor's coordinates
	pad_top     f64
	gutter_w    f64
	marker_x    f64
	number_x    f64
	number_w    f64
	fold_x      f64
	body_w      f64 // the text column's visible width
	content_w   f64 // the text area's width
	content_h   f64 // the scroll content's height
	scroll_pad  f64 // what the scroll adds below it
	text_area   Rect
}

// code_editor_radius is the corner radius of a bordered editor: small, so the
// square scroll inside stays within the rounded border on renderers that do
// not clip children to it.
fn code_editor_radius(size ComponentSize) f64 {
	return math.min(component_metrics(size).radius, 4)
}

// code_editor_inset is how far the scroll sits inside the frame: the border,
// and one more point that keeps its square corners inside the rounded one.
fn code_editor_inset(config CodeEditorConfig) f64 {
	return if config.bordered { 2.0 } else { 0.0 }
}

fn code_editor_padding(size ComponentSize) f64 {
	return match size {
		.small { 4 }
		.medium { 8 }
		.large { 12 }
	}
}

// code_editor_wrap_rows breaks one logical line into visual rows the way the
// text areas wrap: greedily, at the last blank that fits, or inside a word
// longer than the row.
fn code_editor_wrap_rows(runes []rune, line int, start int, end int, width f64, m CodeEditorMetrics) []CodeEditorRow {
	if end <= start || width <= 0 {
		return [CodeEditorRow{line, start, end}]
	}
	mut rows := []CodeEditorRow{}
	mut row_start := start
	for row_start < end {
		mut x := 0.0
		mut k := row_start
		mut last_blank := -1
		for k < end {
			next := m.advance(x, runes[k])
			if next > width + 0.01 && k > row_start {
				break
			}
			if runes[k] == ` ` || runes[k] == `\t` {
				last_blank = k
			}
			x = next
			k++
		}
		if k >= end {
			rows << CodeEditorRow{line, row_start, end}
			break
		}
		mut row_end := k
		mut next_start := k
		// Break at the blank that did not fit, or else at the last one that did.
		blank := if runes[k] == ` ` || runes[k] == `\t` { k } else { last_blank }
		if blank > row_start {
			row_end = blank
			next_start = blank + 1
			for next_start < end && (runes[next_start] == ` ` || runes[next_start] == `\t`) {
				next_start++
			}
		}
		rows << CodeEditorRow{line, row_start, row_end}
		row_start = next_start
	}
	if rows.len == 0 {
		rows << CodeEditorRow{line, start, end}
	}
	return rows
}

fn code_editor_layout(config CodeEditorConfig) CodeEditorLayout {
	m := code_editor_metrics(config)
	runes := config.text.runes()
	line_starts := code_line_starts(runes)
	border := code_editor_inset(config)
	viewport := rect(border, border, math.max(config.frame.width - 2 * border, 0), math.max(config.frame.height - 2 * border,
		0))
	pad := code_editor_padding(config.size)
	style := code_editor_text_style(config)
	// Gutter: [diagnostic marker][line numbers][fold marker]
	mut gutter_w := 0.0
	mut marker_x := 0.0
	mut number_x := 0.0
	mut number_w := 0.0
	mut fold_x := 0.0
	if config.line_numbers {
		digits := math.max(2, line_starts.len.str().len)
		marker_x = 2
		number_x = 16
		// A label needs the width measure_text_width gives, inset included.
		number_w = math.ceil(math.max(measure_text_width('8'.repeat(digits), style), f64(digits) * m.char_width)) +
			2
		fold_x = number_x + number_w + 2
		// Whole points, so the text area's edge does not fall between pixels.
		gutter_w = math.ceil(fold_x + if config.folding { 16.0 } else { 6.0 })
	} else if config.folding || config.diagnostics.len > 0 {
		marker_x = 2
		fold_x = 16
		gutter_w = if config.folding { 32.0 } else { 18.0 }
	}
	body_w := math.max(viewport.width - gutter_w, 0)
	text_width := body_w - m.inset_left - m.inset_right
	mut rows := []CodeEditorRow{cap: line_starts.len}
	mut first_row := []int{cap: line_starts.len + 1}
	mut longest := 0.0
	for line, start in line_starts {
		end := code_line_end(runes, start)
		first_row << rows.len
		if config.soft_wrap {
			rows << code_editor_wrap_rows(runes, line, start, end, text_width, m)
		} else {
			rows << CodeEditorRow{line, start, end}
			w := m.prefix_width(runes, start, end - start)
			if w > longest {
				longest = w
			}
		}
	}
	first_row << rows.len
	content_w := if config.soft_wrap {
		body_w
	} else {
		math.max(body_w, longest + m.inset_left + m.inset_right + 2 * m.char_width)
	}
	text_h := f64(rows.len) * m.line_height
	// The custom renderer's scrolls add room of their own below their content;
	// the editor's content leaves it out so a text that fits does not scroll.
	scroll_inset := code_editor_scroll_bottom_inset()
	pad_bottom := if scroll_inset > 0 { m.inset_top } else { math.max(pad, m.inset_top) }
	content_h := math.max(pad + text_h + pad_bottom, viewport.height - scroll_inset)
	area_y := pad - m.inset_top
	return CodeEditorLayout{
		metrics:     m
		runes:       runes
		line_starts: line_starts
		rows:        rows
		first_row:   first_row
		border:      border
		viewport:    viewport
		pad_top:     pad
		gutter_w:    gutter_w
		marker_x:    marker_x
		number_x:    number_x
		number_w:    number_w
		fold_x:      fold_x
		body_w:      body_w
		content_w:   content_w
		content_h:   content_h
		scroll_pad:  scroll_inset
		text_area:   rect(0, area_y, content_w, content_h - area_y)
	}
}

// row_y is the top of a visual row in the scroll content.
fn (l CodeEditorLayout) row_y(row int) f64 {
	return l.pad_top + f64(row) * l.metrics.line_height
}

// row_of returns the visual row a rune offset is on.
fn (l CodeEditorLayout) row_of(pos int) int {
	p := clamp_int(pos, 0, l.runes.len)
	// The logical line, by binary search over the line starts.
	mut lo := 0
	mut hi := l.line_starts.len - 1
	for lo < hi {
		mid := (lo + hi + 1) / 2
		if l.line_starts[mid] <= p {
			lo = mid
		} else {
			hi = mid - 1
		}
	}
	line := lo
	first := l.first_row[line]
	last := l.first_row[line + 1] - 1
	for row := first; row < last; row++ {
		if p < l.rows[row + 1].start {
			return row
		}
	}
	return last
}

// column_x is the x of a rune offset in the text column (from the text area's
// left edge).
fn (l CodeEditorLayout) column_x(pos int) f64 {
	p := clamp_int(pos, 0, l.runes.len)
	row := l.rows[l.row_of(p)]
	count := clamp_int(p - row.start, 0, row.end - row.start)
	return l.metrics.inset_left + l.metrics.prefix_width(l.runes, row.start, count)
}

// range_rects returns a rectangle per visual row a range covers, in the text
// area's coordinates shifted to the scroll content (x from the text column).
fn (l CodeEditorLayout) range_rects(start int, end int) []Rect {
	s := clamp_int(start, 0, l.runes.len)
	e := clamp_int(end, s, l.runes.len)
	first := l.row_of(s)
	last := l.row_of(e)
	mut out := []Rect{}
	for row in first .. last + 1 {
		r := l.rows[row]
		from := if row == first { s } else { r.start }
		to := if row == last { e } else { r.end }
		x0 := l.metrics.inset_left + l.metrics.prefix_width(l.runes, r.start, clamp_int(from - r.start,
			0, r.end - r.start))
		x1 := l.metrics.inset_left + l.metrics.prefix_width(l.runes, r.start, clamp_int(to - r.start,
			0, r.end - r.start))
		width := if x1 > x0 { x1 - x0 } else { l.metrics.char_width / 2 }
		out << rect(x0, l.row_y(row), width, l.metrics.line_height)
	}
	return out
}

// ── Geometry the application uses ─────────────────────────────────────────

// code_editor_content_height is how tall an editor's frame has to be to show
// all of its text without scrolling: read-only snippets sized to their
// content, as GPUI Kit's wrap_row_count is used for.
pub fn code_editor_content_height(config CodeEditorConfig) f64 {
	l := code_editor_layout(CodeEditorConfig{
		...config
		frame: rect(config.frame.x, config.frame.y, config.frame.width, 0)
	})
	return math.ceil(l.content_h + l.scroll_pad + 2 * l.border)
}

// code_editor_row_count is how many rows the text takes once soft wrapped.
pub fn code_editor_row_count(config CodeEditorConfig) int {
	return code_editor_layout(config).rows.len
}

// code_editor_range_rect is the rectangle a range covers on its first row, in
// the editor's coordinates as they are with nothing scrolled (scroll content
// coordinates plus the border). Subtract scroll_offset(code_editor_scroll_id(id))
// from y for where it shows.
pub fn code_editor_range_rect(config CodeEditorConfig, range CodeRange) Rect {
	l := code_editor_layout(config)
	rects := l.range_rects(range.start, range.end)
	r := if rects.len > 0 {
		rects[0]
	} else {
		rect(l.metrics.inset_left, l.pad_top, 0, l.metrics.line_height)
	}
	return rect(l.viewport.x + l.gutter_w + r.x, l.viewport.y + r.y, r.width, r.height)
}

// code_editor_caret_rect is the caret's rectangle (one character wide) in the
// editor's coordinates with nothing scrolled. Completion popups open below it.
pub fn code_editor_caret_rect(config CodeEditorConfig) Rect {
	l := code_editor_layout(config)
	caret := clamp_int(config.selection.caret, 0, l.runes.len)
	row := l.row_of(caret)
	x := l.column_x(caret)
	return rect(l.viewport.x + l.gutter_w + x, l.viewport.y + l.row_y(row), l.metrics.char_width,
		l.metrics.line_height)
}

// CodeScrollRequest asks for a rectangle of a scroll element to be made
// visible: call scroll_to_rect(r.id, r.rect.x, r.rect.y, r.rect.width,
// r.rect.height) for each.
pub struct CodeScrollRequest {
pub:
	id   string
	rect Rect
}

// code_editor_reveal returns the scroll requests that bring a range into view:
// the editor's scroll vertically and, without soft wrap, its sideways scroll.
// The text area scrolls to its caret by itself on AppKit; the custom renderer
// needs this after every edit, and both need it to show a search match.
pub fn code_editor_reveal(config CodeEditorConfig, range CodeRange) []CodeScrollRequest {
	l := code_editor_layout(config)
	rects := l.range_rects(range.start, range.end)
	if rects.len == 0 {
		return []CodeScrollRequest{}
	}
	r := rects[0]
	margin := l.metrics.line_height
	mut out := [
		CodeScrollRequest{
			id:   code_editor_scroll_id(config.id)
			rect: rect(0, math.max(r.y - margin, 0), 1, r.height + 2 * margin)
		},
	]
	if !config.soft_wrap {
		out << CodeScrollRequest{
			id:   code_editor_hscroll_id(config.id)
			rect: rect(math.max(r.x - 4 * l.metrics.char_width, 0), 0, r.width + 8 * l.metrics.char_width,
				1)
		}
	}
	return out
}

// ── Folding ───────────────────────────────────────────────────────────────

// CodeFoldRange is a block that can fold: lines start_line+1 .. end_line hide
// under start_line. Lines are zero-based.
pub struct CodeFoldRange {
pub:
	start_line int
	end_line   int
}

// code_fold_ranges finds the foldable blocks of a text: bracket pairs that
// span lines (outside strings and comments) for most languages, indentation
// for Python, and headings for Markdown. One range per start line, the
// outermost, sorted by start line.
pub fn code_fold_ranges(text string, language CodeLanguage) []CodeFoldRange {
	runes := text.runes()
	starts := code_line_starts(runes)
	mut ends := map[int]int{}
	match language {
		.python {
			code_fold_indentation(runes, starts, mut ends)
		}
		.markdown {
			code_fold_headings(runes, starts, mut ends)
		}
		.plain {}
		else {
			code_fold_brackets(text, runes, language, mut ends)
		}
	}
	mut out := []CodeFoldRange{}
	mut keys := ends.keys()
	keys.sort()
	for k in keys {
		out << CodeFoldRange{k, ends[k]}
	}
	return out
}

fn code_line_index(starts []int, pos int) int {
	mut lo := 0
	mut hi := starts.len - 1
	for lo < hi {
		mid := (lo + hi + 1) / 2
		if starts[mid] <= pos {
			lo = mid
		} else {
			hi = mid - 1
		}
	}
	return lo
}

fn code_fold_brackets(text string, runes []rune, language CodeLanguage, mut ends map[int]int) {
	starts := code_line_starts(runes)
	tokens := code_tokens(text, language)
	mut token_index := 0
	mut stack := []int{}
	for i, r in runes {
		for token_index < tokens.len && tokens[token_index].end <= i {
			token_index++
		}
		if token_index < tokens.len && tokens[token_index].start <= i
			&& code_in_string_or_comment(tokens[token_index].kind) {
			continue
		}
		if r == `{` || r == `[` || r == `(` {
			stack << i
		} else if (r == `}` || r == `]` || r == `)`) && stack.len > 0 {
			open := stack.pop()
			a := code_line_index(starts, open)
			b := code_line_index(starts, i)
			if b > a {
				// Lines a+1 .. b-1 hide; the closer's line stays visible.
				last := if code_leading_blank_until(runes, starts[b], i) { b - 1 } else { b }
				if last > a && last > (ends[a] or { -1 }) {
					ends[a] = last
				}
			}
		}
	}
}

fn code_leading_blank_until(runes []rune, from int, to int) bool {
	for k in from .. to {
		if runes[k] != ` ` && runes[k] != `\t` {
			return false
		}
	}
	return true
}

fn code_fold_indentation(runes []rune, starts []int, mut ends map[int]int) {
	mut indents := []int{len: starts.len, init: -1}
	for line, start in starts {
		end := code_line_end(runes, start)
		ws := code_leading_whitespace(runes, start)
		if start + ws < end {
			indents[line] = code_visual_column(runes, start, start + ws, 4)
		}
	}
	for line in 0 .. starts.len {
		if indents[line] < 0 {
			continue
		}
		mut last := line
		for next in line + 1 .. starts.len {
			if indents[next] < 0 {
				continue
			}
			if indents[next] <= indents[line] {
				break
			}
			last = next
		}
		if last > line {
			ends[line] = last
		}
	}
}

fn code_fold_headings(runes []rune, starts []int, mut ends map[int]int) {
	mut levels := []int{len: starts.len}
	for line, start in starts {
		mut level := 0
		for start + level < runes.len && runes[start + level] == `#` {
			level++
		}
		if level > 0 && level <= 6 && (start + level >= runes.len || runes[start + level] == ` `) {
			levels[line] = level
		}
	}
	for line in 0 .. starts.len {
		if levels[line] == 0 {
			continue
		}
		mut last := starts.len - 1
		for next in line + 1 .. starts.len {
			if levels[next] > 0 && levels[next] <= levels[line] {
				last = next - 1
				break
			}
		}
		for last > line && code_line_end(runes, starts[last]) == starts[last] {
			last--
		}
		if last > line {
			ends[line] = last
		}
	}
}

// ── Actions ───────────────────────────────────────────────────────────────

fn code_editor_line_action(id string, line int) string {
	return component_part_id(id, 'line:${line}')
}

fn code_editor_fold_action(id string, line int) string {
	return component_part_id(id, 'fold:${line}')
}

// CodeEditorStep is what a press in the gutter asks for: a selection to apply
// (select the line, or the foldable block whose marker was pressed) and the
// focus to give back to the text area.
pub struct CodeEditorStep {
pub:
	selection TextSelection
	line      int
	fold      bool // The press was on a fold marker.
	focus     string
}

// code_editor_update decodes a press on a line number (select that line) or a
// fold marker (select the block). It returns none for anything else, and for
// lines the text does not have.
pub fn code_editor_update(config CodeEditorConfig, event string) ?CodeEditorStep {
	part := component_action_part(config.id, event) or { return none }
	runes := config.text.runes()
	starts := code_line_starts(runes)
	if part.starts_with('line:') {
		line := component_parse_index(part[5..], starts.len - 1) or { return none }
		return CodeEditorStep{
			selection: code_select_line(config.text, TextSelection{starts[line], starts[line]})
			line:      line
			focus:     code_editor_text_id(config.id)
		}
	}
	if part.starts_with('fold:') {
		if !config.folding {
			return none
		}
		line := component_parse_index(part[5..], starts.len - 1) or { return none }
		for r in code_fold_ranges(config.text, config.language) {
			if r.start_line == line {
				// The block, and the line of its closing bracket.
				mut last := r.end_line
				if last + 1 < starts.len {
					ws := code_leading_whitespace(runes, starts[last + 1])
					at := starts[last + 1] + ws
					if at < runes.len && runes[at] in [`}`, `]`, `)`] {
						last++
					}
				}
				end := code_line_end(runes, starts[last])
				return CodeEditorStep{
					selection: TextSelection{starts[line], end}
					line:      line
					fold:      true
					focus:     code_editor_text_id(config.id)
				}
			}
		}
	}
	return none
}

// ── Building ──────────────────────────────────────────────────────────────

fn code_diagnostic_symbol(severity CodeDiagnosticSeverity) string {
	return match severity {
		.error { 'exclamationmark.circle.fill' }
		.warning { 'exclamationmark.triangle.fill' }
		.info { 'info.circle.fill' }
		.hint { 'info.circle' }
	}
}

fn code_severity_rank(severity CodeDiagnosticSeverity) int {
	return match severity {
		.error { 0 }
		.warning { 1 }
		.info { 2 }
		.hint { 3 }
	}
}

fn code_diagnostic_text(d CodeDiagnostic) string {
	return if d.source.len > 0 { '${d.source}: ${d.message}' } else { d.message }
}

// code_editor_line_diagnostics groups diagnostics by the line they start on,
// most severe first.
fn code_editor_line_diagnostics(l CodeEditorLayout, diagnostics []CodeDiagnostic) map[int][]CodeDiagnostic {
	mut out := map[int][]CodeDiagnostic{}
	for d in diagnostics {
		line := code_line_index(l.line_starts, clamp_int(d.start, 0, l.runes.len))
		mut items := out[line] or { []CodeDiagnostic{} }
		items << d
		items.sort_with_compare(fn (a &CodeDiagnostic, b &CodeDiagnostic) int {
			return code_severity_rank(a.severity) - code_severity_rank(b.severity)
		})
		out[line] = items
	}
	return out
}

fn code_editor_gutter(config CodeEditorConfig, l CodeEditorLayout, current_line int) Element {
	theme := config.theme
	m := l.metrics
	style := code_editor_text_style(config)
	mut children := []Element{}
	if current_line >= 0 && config.current_line {
		first := l.first_row[current_line]
		count := l.first_row[current_line + 1] - first
		children << Element{
			...view('', rect(0, l.row_y(first), l.gutter_w, f64(count) * m.line_height), BoxStyle{
				bg: theme.active_line_background
			}, []Element{})
			key: 'active'
		}
	}
	if config.line_numbers {
		number_style := TextStyle{
			...style
			color:  theme.line_number
			align:  .right
			valign: .middle
			lines:  1
		}
		for line in 0 .. l.line_starts.len {
			y := l.row_y(l.first_row[line])
			children << Element{
				...button_view(code_editor_line_action(config.id, line), rect(l.number_x, y, l.number_w,
					m.line_height), BoxStyle{ transparent: true }, [
					label('', (line + 1).str(), rect(0, 0, l.number_w, m.line_height), TextStyle{
						...number_style
						color: if line == current_line {
							theme.active_line_number
						} else {
							theme.line_number
						}
					}),
				])
				key:                 'n${line}'
				accessibility_label: 'Line ${line + 1}'
			}
		}
	}
	if config.folding {
		icon := math.min(m.line_height - 4, 11.0)
		for r in code_fold_ranges(config.text, config.language) {
			if r.start_line >= l.line_starts.len {
				continue
			}
			y := l.row_y(l.first_row[r.start_line])
			frame := rect(l.fold_x, y, 14, m.line_height)
			children << Element{
				...button_view(code_editor_fold_action(config.id, r.start_line), frame, BoxStyle{
					transparent: true
				}, [
					inputs_symbol('chevron.down', inputs_centered_square(component_local(frame),
						icon), theme.fold_marker),
				])
				key:                 'f${r.start_line}'
				tooltip:             'Select lines ${r.start_line + 1}–${r.end_line + 1}'
				accessibility_label: 'Fold lines ${r.start_line + 1} to ${r.end_line + 1}'
			}
		}
	}
	if l.gutter_w > 0 {
		by_line := code_editor_line_diagnostics(l, config.diagnostics)
		icon := math.min(m.line_height - 3, 12.0)
		mut lines := by_line.keys()
		lines.sort()
		for line in lines {
			items := by_line[line]
			top := items[0]
			color, _ := theme.severity_colors(top.severity)
			y := l.row_y(l.first_row[line])
			frame := rect(l.marker_x, y, 14, m.line_height)
			messages := items.map(code_diagnostic_text(it)).join('\n')
			children << Element{
				...view('', frame, BoxStyle{ transparent: true }, [
					inputs_symbol(code_diagnostic_symbol(top.severity), inputs_centered_square(component_local(frame),
						icon), color),
				])
				key:                 'd${line}'
				tooltip:             messages
				accessibility_role:  'img'
				accessibility_label: messages
			}
		}
	}
	return Element{
		...view(component_part_id(config.id, 'gutter'), rect(0, 0, l.gutter_w, l.content_h),
			BoxStyle{
				bg: theme.gutter_background
			}, children)
		key:                 'gutter'
		accessibility_role:  'group'
		accessibility_label: 'Line numbers'
	}
}

// code_editor_under_text is what belongs beneath the code: the current-line
// tint, indent guides and the placeholder. On top is false where they can lie
// under the transparent text area; on the custom renderer they are drawn over
// it, translucent.
fn code_editor_under_text(config CodeEditorConfig, l CodeEditorLayout, current_line int, on_top bool) []Element {
	theme := config.theme
	m := l.metrics
	mut out := []Element{}
	if current_line >= 0 && config.current_line {
		first := l.first_row[current_line]
		count := l.first_row[current_line + 1] - first
		frame := rect(0, l.row_y(first), l.content_w, f64(count) * m.line_height)
		box := if on_top {
			BoxStyle{
				bg:      theme.foreground
				opacity: code_overlay_opacity(theme.background, theme.foreground, theme.active_line_background)
			}
		} else {
			BoxStyle{
				bg: theme.active_line_background
			}
		}
		out << Element{
			...view('', frame, box, []Element{})
			key: 'active'
		}
	}
	if config.indent_guides {
		out << code_editor_indent_guides(config, l)
	}
	if config.text.len == 0 && config.placeholder.len > 0 {
		out << Element{
			...label('', config.placeholder, rect(m.inset_left, l.pad_top, math.max(l.content_w - m.inset_left - m.inset_right,
				0), m.line_height), TextStyle{
				...code_editor_text_style(config)
				color:  theme.line_number
				valign: .middle
				lines:  1
			})
			key: 'placeholder'
		}
	}
	return out
}

// code_editor_indent_guides draws a thin line at each indentation level of the
// lines' leading whitespace, carried across blank lines.
fn code_editor_indent_guides(config CodeEditorConfig, l CodeEditorLayout) []Element {
	m := l.metrics
	unit := if config.hard_tabs || l.runes.len == 0 { 0 } else { math.max(config.tab_size, 1) }
	mut out := []Element{}
	mut previous := []f64{}
	for line, start in l.line_starts {
		end := code_line_end(l.runes, start)
		ws := code_leading_whitespace(l.runes, start)
		mut stops := []f64{}
		if start + ws < end {
			// One guide per indentation unit: each tab, or each tab_size spaces.
			mut x := 0.0
			mut spaces := 0
			for k in start .. start + ws {
				if l.runes[k] == `\t` {
					stops << x
					spaces = 0
				} else {
					// Only whole levels: a unit of spaces that is all there.
					if unit > 0 && spaces % unit == 0 && start + ws - k >= unit {
						stops << x
					}
					spaces++
				}
				x = m.advance(x, l.runes[k])
			}
		} else {
			stops = previous.clone()
		}
		first := l.first_row[line]
		count := l.first_row[line + 1] - first
		for index, x in stops {
			out << Element{
				...view('', rect(m.inset_left + x, l.row_y(first), 1, f64(count) * m.line_height),
					BoxStyle{
						bg: config.theme.indent_guide
					}, []Element{})
				key: 'g${line}:${index}'
			}
		}
		previous = stops.clone()
	}
	return out
}

// code_editor_frames draws the frame decorations: a one-point outline round
// each row a range covers.
fn code_editor_frames(config CodeEditorConfig, l CodeEditorLayout) []Element {
	mut out := []Element{}
	for index, d in config.decorations {
		if d.style != .frame {
			continue
		}
		color := d.color or { config.theme.foreground }
		for row_index, r in l.range_rects(d.start, d.end) {
			key := 'frame${index}:${row_index}'
			edges := [rect(r.x, r.y, r.width, 1), rect(r.x, r.y + r.height - 1, r.width, 1),
				rect(r.x, r.y, 1, r.height), rect(r.x + r.width - 1, r.y, 1, r.height)]
			for edge_index, edge in edges {
				out << Element{
					...view('', edge, BoxStyle{ bg: color }, []Element{})
					key: '${key}:${edge_index}'
				}
			}
		}
	}
	return out
}

// code_editor_inline_diagnostics writes each line's most severe message after
// its text, muted, where the line ends within the visible width.
fn code_editor_inline_diagnostics(config CodeEditorConfig, l CodeEditorLayout) []Element {
	m := l.metrics
	style := code_editor_text_style(config)
	mut out := []Element{}
	by_line := code_editor_line_diagnostics(l, config.diagnostics)
	for line, items in by_line {
		last_row := l.first_row[line + 1] - 1
		r := l.rows[last_row]
		x := m.inset_left + m.prefix_width(l.runes, r.start, r.end - r.start) + 3 * m.char_width
		width := l.content_w - x - m.inset_right
		if width < 6 * m.char_width {
			continue
		}
		color, _ := config.theme.severity_colors(items[0].severity)
		out << Element{
			...label('', items[0].message, rect(x, l.row_y(last_row), width, m.line_height),
				TextStyle{
					...style
					color:  color
					italic: true
					valign: .middle
					lines:  1
				})
			key: 'inline${line}'
		}
	}
	return out
}

// code_editor_caret draws the caret where the text area does not.
fn code_editor_caret(config CodeEditorConfig, l CodeEditorLayout) []Element {
	if !config.focused || !config.selection.collapsed() || config.read_only || config.disabled
		|| code_editor_backend_draws_caret() {
		return []Element{}
	}
	caret := clamp_int(config.selection.caret, 0, l.runes.len)
	row := l.row_of(caret)
	x := l.column_x(caret)
	return [
		Element{
			...view('', rect(x - 1, l.row_y(row) + 1, 2, l.metrics.line_height - 2), BoxStyle{
				bg: config.theme.caret
			}, []Element{})
			key: 'caret'
		},
	]
}

// code_editor_seams covers the custom renderer's outline round its text area,
// which it draws whatever the box says, with the editor background.
fn code_editor_seams(config CodeEditorConfig, l CodeEditorLayout) []Element {
	if !code_editor_overlays_on_top() {
		return []Element{}
	}
	a := l.text_area
	box := BoxStyle{
		bg: config.theme.background
	}
	// The outline is stroked across the edge, so the strips reach a point
	// outside it as well, except into the gutter on the left.
	return [
		Element{
			...view('', rect(a.x - 1, a.y - 1, a.width + 2, 3), box, []Element{})
			key: 'seam:top'
		},
		Element{
			...view('', rect(a.x - 1, a.y + a.height - 2, a.width + 2, 3), box, []Element{})
			key: 'seam:bottom'
		},
		Element{
			...view('', rect(a.x, a.y - 1, 3, a.height + 2), box, []Element{})
			key: 'seam:left'
		},
		Element{
			...view('', rect(a.x + a.width - 2, a.y - 1, 3, a.height + 2), box, []Element{})
			key: 'seam:right'
		},
	]
}

// code_editor builds the editor: a bordered surface with a gutter of line
// numbers (the current one emphasized), diagnostic and fold markers, and the
// highlighted code in a text area beside it, both in one scroll; the search bar
// floats over the top-right corner while search.open.
//
// Wire it up as the gallery does (examples/gpui_editor):
//
//   - on the text area's change event (code_editor_text_id(id)) read text()
//     and the selection, pass both to code_editor_after_input with the old
//     config, apply what it returns, and store the new text;
//   - from on_key_event, map keys with code_command_for_key and run them with
//     code_editor_command (edits) or code_search_command (search);
//   - from on_key, map `text:<text id>:<key>` with code_editor_text_command,
//     which is how AppKit reports Enter, Tab and Backspace;
//   - route every event through code_search_update and code_editor_update.
pub fn code_editor(config CodeEditorConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	theme := config.theme
	l := code_editor_layout(config)
	m := l.metrics
	on_top := code_editor_overlays_on_top()
	caret := clamp_int(config.selection.caret, 0, l.runes.len)
	current_line := code_line_index(l.line_starts, caret)
	matches := if config.search.open {
		code_search_matches(config.text, config.search)
	} else {
		[]CodeRange{}
	}
	runs := code_highlight_runs(CodeHighlightConfig{
		text:        config.text
		language:    config.language
		base:        TextStyle{
			...code_editor_text_style(config)
			valign: .middle
			lines:  1
		}
		theme:       theme
		highlight:   config.highlight
		matches:     matches
		current:     config.search.current
		diagnostics: config.diagnostics
		decorations: config.decorations
	})
	style := code_editor_text_style(config)
	area := Element{
		...rich_text_area_without_scroll(code_editor_text_id(config.id), config.text, runs,
			l.text_area, BoxStyle{
				bg:          theme.background
				transparent: true
			}, TextStyle{
				...style
				valign: .middle
				lines:  1
			})
		key:                 'text'
		readonly:            config.read_only
		enabled:             !config.disabled
		padding_left:        m.inset_left
		autocorrect:         false
		accessibility_label: if config.label.len > 0 { config.label } else { 'Code editor' }
	}
	// Marks drawn with the text: beneath it where the text area is see-through,
	// over it on the custom renderer (see code_editor_overlays_on_top).
	mut marks := code_editor_under_text(config, l, current_line, on_top)
	marks << code_editor_frames(config, l)
	if config.inline_diagnostics {
		marks << code_editor_inline_diagnostics(config, l)
	}
	mut body_children := []Element{}
	if !on_top {
		body_children << marks
	}
	body_children << area
	body_children << code_editor_seams(config, l)
	if on_top {
		body_children << marks
	}
	body_children << code_editor_caret(config, l)
	body_frame := rect(l.gutter_w, 0, l.body_w, l.content_h)
	body := if config.soft_wrap {
		Element{
			...view(component_part_id(config.id, 'body'), body_frame, BoxStyle{
				transparent: true
			}, body_children)
			key: 'body'
		}
	} else {
		Element{
			...scroll_with_mode(code_editor_hscroll_id(config.id), body_frame, theme.background,
				.horizontal_only, body_children)
			key: 'body'
		}
	}
	mut scroll_children := []Element{}
	if l.gutter_w > 0 {
		scroll_children << code_editor_gutter(config, l, current_line)
	}
	scroll_children << body
	mut children := [
		Element{
			...scroll(code_editor_scroll_id(config.id), l.viewport, theme.background, scroll_children)
			key: 'scroll'
		},
	]
	if config.search.open && config.search_bar {
		editable := !config.read_only && !config.disabled
		bar_w, bar_h := code_search_bar_size(config.search, editable, config.search_size)
		w := math.min(bar_w, math.max(l.viewport.width - 24, 0))
		children << Element{
			...code_search_bar(CodeSearchBarConfig{
				id:       config.id
				frame:    rect(l.viewport.x + l.viewport.width - w - 14, l.viewport.y + 6, w,
					bar_h)
				state:    config.search
				matches:  matches.len
				error:    code_search_error(config.search)
				editable: editable
				size:     config.search_size
				theme:    theme.ui
			})!
			key: 'search'
		}
	}
	mut box := BoxStyle{
		bg: theme.background
	}
	if config.bordered {
		// A border-colored rounded box with the background inset over it, as
		// popover panels draw their border alike on every renderer.
		radius := code_editor_radius(config.size)
		panel_box, panel := popover_panel(config.frame, theme.background, theme.border, radius,
			false)
		box = panel_box
		children.insert(0, panel)
	}
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_role:  'group'
		accessibility_label: if config.label.len > 0 { config.label } else { 'Code editor' }
	})
}
