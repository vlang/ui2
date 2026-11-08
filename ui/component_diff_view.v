module ui2

import math

// The diff view: GPUI Kit's Diff, a readonly, virtualized list of every file's
// rows. One vertical Scroll element holds all files; only the rows near its
// offset are built. Long lines scroll sideways: each file's code column (one
// in Unified mode, one per side in Split mode) is a horizontal Scroll element
// spanning that file's rows, so the line numbers stay put while the code moves,
// and a vertical gesture over code still scrolls the list. Rows that are not
// code (headers, hunk separators, folds, conflict headings, annotations) are
// drawn above those columns.

pub enum DiffHunkSeparator {
	metadata  // The hunk's `@@ -a,b +c,d @@ section` line.
	line_info // How many lines the patch leaves out before the hunk.
	simple    // A thin divider.
}

pub enum DiffChangeIndicator {
	signs // A + or − before changed lines.
	bars  // A colored bar: green added, red removed, amber modified (paired).
	none
}

// DiffAnnotationFn draws an annotation's content into the card's content box,
// in coordinates local to it. Set DiffAnnotation.height to the height it needs.
pub type DiffAnnotationFn = fn (annotation DiffAnnotation, frame Rect) []Element

pub struct DiffViewConfig {
pub:
	id    string // Required.
	frame Rect
	state DiffState
	// scroll_y is the body's vertical offset: store scroll_offset(diff_body_id(id))
	// when on_scroll reports that id and rebuild; the rows built follow it.
	scroll_y            f64
	overscan            int                 = 12 // Rows built beyond each edge of the body.
	line_numbers        bool                = true
	header_visible      bool                = true
	hunk_separator      DiffHunkSeparator   = .metadata
	change_indicator    DiffChangeIndicator = .signs
	change_background   bool                = true // Tint changed lines; inline emphasis stays without it.
	render_annotation   DiffAnnotationFn    = unsafe { nil }
	empty_text          string              = 'No changes'
	bordered            bool                = true
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// DiffMetrics are the sizes a diff view draws with.
pub struct DiffMetrics {
pub:
	code_size      f64 // Code and line numbers, in the monospace face.
	text_size      f64 // Headers, headings and buttons.
	row_height     f64
	header_height  f64
	hunk_height    f64
	fold_height    f64
	heading_height f64 // A conflict part's heading.
	summary_height f64
	file_gap       f64 // Space above every file header but the first.
	padding        f64
	radius         f64
}

pub fn diff_metrics(size ComponentSize) DiffMetrics {
	return match size {
		.small {
			DiffMetrics{
				code_size:      11
				text_size:      12
				row_height:     18
				header_height:  34
				hunk_height:    24
				fold_height:    26
				heading_height: 28
				summary_height: 36
				file_gap:       10
				padding:        6
				radius:         6
			}
		}
		.medium {
			DiffMetrics{
				code_size:      12
				text_size:      13
				row_height:     20
				header_height:  38
				hunk_height:    26
				fold_height:    28
				heading_height: 30
				summary_height: 40
				file_gap:       12
				padding:        8
				radius:         6
			}
		}
		.large {
			DiffMetrics{
				code_size:      14
				text_size:      15
				row_height:     24
				header_height:  44
				hunk_height:    30
				fold_height:    32
				heading_height: 34
				summary_height: 46
				file_gap:       14
				padding:        10
				radius:         8
			}
		}
	}
}

// Both scroll backends leave this much room below a Scroll element's content.
const diff_scroll_inset = 16.0

// Where code text starts in its column, past the marker.
const diff_code_pad = 6.0

// diff_body_id is the id of the vertical Scroll element, for scroll_offset,
// scroll_to_offset and on_scroll.
pub fn diff_body_id(id string) string {
	return component_part_id(id, 'body')
}

// diff_code_scroll_id is the id of the Scroll element holding a file's code
// column: side .original is the left column in Split mode, .modified the right
// one and the only one in Unified mode.
pub fn diff_code_scroll_id(id string, file int, side DiffSide) string {
	return component_part_id(id, 'code:${file}:${if side == .original { 'o' } else { 'm' }}')
}

// DiffViewLayout is where the view puts its parts and rows, in view-local points.
pub struct DiffViewLayout {
pub:
	box          Rect // The bordered surface.
	body         Rect // The scrolling body, in the surface.
	rows         VirtualListLayout
	range        VirtualListRange // The rows built.
	scroll_y     f64              // The offset, held to the scroll range.
	metrics      DiffMetrics
	advance      f64 // The width of one character of code.
	inset        f64 // What a label adds around its text, measured by the backend.
	number_width f64 // One line-number column; 0 without line numbers.
	marker_width f64
	// tail is room below each file's code for its horizontal scroller: the gap
	// above the next file's header, and this much more after the last file.
	tail f64
}

// content_height is how tall the scrolled content is.
pub fn (layout DiffViewLayout) content_height() f64 {
	return layout.rows.total() + layout.tail
}

// max_offset is the furthest the body scrolls.
pub fn (layout DiffViewLayout) max_offset() f64 {
	return math.max(0.0, layout.content_height() + diff_scroll_inset - layout.body.height)
}

fn diff_code_style(metrics DiffMetrics, color u32) TextStyle {
	return TextStyle{
		color:       color
		size:        metrics.code_size
		font_family: 'monospace'
	}
}

// diff_text_metrics measures the monospace face: the advance of one character
// and the inset a backend's labels add around their text, which the boxes
// drawn behind changed words have to allow for.
fn diff_text_metrics(style TextStyle) (f64, f64) {
	short := measure_text_width('0'.repeat(20), style)
	long := measure_text_width('0'.repeat(60), style)
	advance := (long - short) / 40
	if !component_finite(advance) || advance <= 0 {
		fallback := style.size * 0.6
		return fallback, 0.0
	}
	return advance, math.max(0.0, short - 20 * advance)
}

fn diff_digits(n int) int {
	mut digits := 1
	mut v := n
	for v >= 10 {
		v /= 10
		digits++
	}
	return digits
}

pub fn diff_view_layout(config DiffViewConfig) DiffViewLayout {
	metrics := diff_metrics(config.size)
	advance, inset := diff_text_metrics(diff_code_style(metrics, 0))
	border := if config.bordered { 1.0 } else { 0.0 }
	corner := if config.bordered { math.max(0.0, metrics.radius - 2) } else { 0.0 }
	w := config.frame.width
	h := config.frame.height
	box := rect(0, 0, w, h)
	body := rect(border, border + corner, math.max(0.0, w - 2 * border), math.max(0.0, h - 2 * border - 2 * corner))
	number_width := if config.line_numbers {
		math.ceil(f64(math.max(3, diff_digits(config.state.max_line))) * advance + inset +
			2 * metrics.padding)
	} else {
		0.0
	}
	marker_width := match config.change_indicator {
		.signs { math.ceil(advance + inset + 8) }
		.bars { 8.0 }
		.none { 4.0 }
	}
	base := DiffViewLayout{
		box:          box
		body:         body
		metrics:      metrics
		advance:      advance
		inset:        inset
		number_width: number_width
		marker_width: marker_width
		tail:         if config.header_visible { metrics.file_gap } else { 0.0 }
	}
	rows := config.state.rows
	mut sizes := []f64{cap: rows.len}
	for row in rows {
		sizes << diff_row_size(config, base, row)
	}
	stack := virtual_list_sized(sizes, 0) or { VirtualListLayout{} }
	max_y := math.max(0.0, stack.total() + base.tail + diff_scroll_inset - body.height)
	scroll_y := if component_finite(config.scroll_y) {
		math.min(max_y, math.max(0.0, config.scroll_y))
	} else {
		0.0
	}
	return DiffViewLayout{
		...base
		rows:     stack
		range:    stack.range(body.height, scroll_y, config.overscan)
		scroll_y: scroll_y
	}
}

fn diff_row_size(config DiffViewConfig, layout DiffViewLayout, row DiffRow) f64 {
	m := layout.metrics
	return match row.kind {
		.file_header {
			if config.header_visible {
				m.header_height + if row.file > 0 { m.file_gap } else { 0.0 }
			} else {
				0.0
			}
		}
		.file_summary {
			m.summary_height
		}
		.hunk {
			if config.hunk_separator == .simple { 9.0 } else { m.hunk_height }
		}
		.fold {
			m.fold_height
		}
		.line {
			m.row_height
		}
		.conflict {
			m.heading_height
		}
		.annotation {
			diff_annotation_height(config, layout, row)
		}
	}
}

// ── Columns ─────────────────────────────────────────────────────────

// DiffColumns are the x positions of a file's gutter and code, in the body.
// A column that is not there has x -1.
struct DiffColumns {
	split      bool
	old_x      f64 = -1
	new_x      f64 = -1
	marker_x   f64
	code_x     f64
	code_w     f64
	divider_x  f64 = -1
	r_new_x    f64 = -1
	r_marker_x f64
	r_code_x   f64
	r_code_w   f64
	half       f64
}

fn diff_columns(config DiffViewConfig, layout DiffViewLayout, file DiffFile) DiffColumns {
	w := layout.body.width
	nw := layout.number_width
	mw := layout.marker_width
	numbers := config.line_numbers
	if file.single_column() {
		return DiffColumns{
			new_x:    if numbers { 0.0 } else { -1.0 }
			marker_x: nw
			code_x:   nw + mw
			code_w:   math.max(0.0, w - nw - mw)
		}
	}
	if config.state.mode == .split {
		half := math.floor(w / 2)
		right := half + 1
		return DiffColumns{
			split:      true
			old_x:      if numbers { 0.0 } else { -1.0 }
			marker_x:   nw
			code_x:     nw + mw
			code_w:     math.max(0.0, half - nw - mw)
			divider_x:  half
			r_new_x:    if numbers { right } else { -1.0 }
			r_marker_x: right + nw
			r_code_x:   right + nw + mw
			r_code_w:   math.max(0.0, w - right - nw - mw)
			half:       half
		}
	}
	return DiffColumns{
		old_x:    if numbers { 0.0 } else { -1.0 }
		new_x:    if numbers { nw } else { -1.0 }
		marker_x: 2 * nw
		code_x:   2 * nw + mw
		code_w:   math.max(0.0, w - 2 * nw - mw)
	}
}

// diff_annotation_box is where an annotation card goes across the body: under
// the code of its side, or across the whole width for a file annotation.
fn diff_annotation_box(config DiffViewConfig, layout DiffViewLayout, note DiffAnnotation, fi int) (f64, f64) {
	w := layout.body.width
	pad := layout.metrics.padding
	if note.line <= 0 || fi < 0 || fi >= config.state.files.len {
		return pad, math.max(0.0, w - 2 * pad)
	}
	cols := diff_columns(config, layout, config.state.files[fi])
	if cols.split && note.side == .modified {
		return cols.r_code_x + pad, math.max(0.0, cols.r_code_w - 2 * pad)
	}
	return cols.code_x + pad, math.max(0.0, cols.code_w - 2 * pad)
}

const diff_note_margin = 6.0

fn diff_note_title_style(m DiffMetrics, color u32) TextStyle {
	return TextStyle{
		color: color
		size:  m.text_size
		bold:  true
	}
}

fn diff_note_text_style(m DiffMetrics, color u32) TextStyle {
	return TextStyle{
		color: color
		size:  m.text_size
	}
}

fn diff_note_line_height(m DiffMetrics) f64 {
	return math.ceil(m.text_size * 1.45)
}

fn diff_annotation_lines(config DiffViewConfig, layout DiffViewLayout, note DiffAnnotation, fi int) []string {
	_, width := diff_annotation_box(config, layout, note, fi)
	inner := math.max(10.0, width - 2 * layout.metrics.padding - 6)
	return wrap_text_to_width(note.text, diff_note_text_style(layout.metrics, 0), inner)
}

fn diff_annotation_height(config DiffViewConfig, layout DiffViewLayout, row DiffRow) f64 {
	if row.annotation < 0 || row.annotation >= config.state.annotations.len {
		return 0
	}
	note := config.state.annotations[row.annotation]
	m := layout.metrics
	if note.height > 0 && component_finite(note.height) {
		return note.height + 2 * diff_note_margin
	}
	line_h := diff_note_line_height(m)
	mut inner := 0.0
	if note.title.len > 0 {
		inner += line_h
	}
	if note.text.len > 0 {
		inner += f64(diff_annotation_lines(config, layout, note, row.file).len) * line_h
	}
	return math.ceil(math.max(inner, line_h) + 2 * m.padding + 2 * diff_note_margin)
}

// ── Colors ──────────────────────────────────────────────────────────

struct DiffColors {
	surface         u32
	text            u32
	muted           u32
	border          u32
	gutter          u32
	header          u32
	hunk            u32
	hunk_text       u32
	added           u32
	added_gutter    u32
	added_strong    u32
	added_mark      u32
	removed         u32
	removed_gutter  u32
	removed_strong  u32
	removed_mark    u32
	modified_mark   u32
	empty           u32
	selected        u32
	selected_gutter u32
	accent          u32
	ours            u32
	ours_heading    u32
	theirs          u32
	theirs_heading  u32
	base            u32
	base_heading    u32
	note            u32
	note_border     u32
}

fn diff_colors(theme ComponentTheme) DiffColors {
	bg := theme.background
	dark := choice_luminance(bg) < 0.4
	add := theme.success
	del := theme.danger
	theirs := if dark { u32(0xc4b5fd) } else { u32(0x7c3aed) }
	t := if dark { 1.35 } else { 1.0 }
	return DiffColors{
		surface:         bg
		text:            theme.foreground
		muted:           theme.muted_foreground
		border:          theme.border
		gutter:          choice_mix(bg, theme.muted, 0.55)
		header:          theme.muted
		hunk:            choice_mix(bg, theme.primary, 0.07 * t)
		hunk_text:       theme.muted_foreground
		added:           choice_mix(bg, add, 0.10 * t)
		added_gutter:    choice_mix(bg, add, 0.19 * t)
		added_strong:    choice_mix(bg, add, 0.30 * t)
		added_mark:      if dark { add } else { choice_mix(add, theme.foreground, 0.15) }
		removed:         choice_mix(bg, del, 0.09 * t)
		removed_gutter:  choice_mix(bg, del, 0.17 * t)
		removed_strong:  choice_mix(bg, del, 0.27 * t)
		removed_mark:    if dark { del } else { choice_mix(del, theme.foreground, 0.1) }
		modified_mark:   if dark { theme.warning } else { choice_mix(theme.warning, 0xb45309, 0.5) }
		empty:           choice_mix(bg, theme.muted, if dark { 0.45 } else { 0.7 })
		selected:        choice_mix(bg, theme.primary, 0.13 * t)
		selected_gutter: choice_mix(bg, theme.primary, 0.26 * t)
		accent:          theme.primary
		ours:            choice_mix(bg, theme.primary, 0.09 * t)
		ours_heading:    choice_mix(bg, theme.primary, 0.20 * t)
		theirs:          choice_mix(bg, theirs, 0.09 * t)
		theirs_heading:  choice_mix(bg, theirs, 0.20 * t)
		base:            choice_mix(bg, theme.muted_foreground, 0.08 * t)
		base_heading:    choice_mix(bg, theme.muted_foreground, 0.18 * t)
		note:            choice_mix(bg, theme.muted, 0.6)
		note_border:     choice_mix(theme.border, bg, 0.2)
	}
}

fn diff_tone_color(theme ComponentTheme, tone ComponentTone) u32 {
	return match tone {
		.neutral { theme.muted_foreground }
		.primary { theme.primary }
		.success { theme.success }
		.warning {
			if choice_luminance(theme.background) < 0.4 { theme.warning } else { u32(0xb45309) }
		}
		.danger { theme.danger }
	}
}

// ── Building ────────────────────────────────────────────────────────

// DiffBuild is what every row builder needs, worked out once per build.
struct DiffBuild {
	config        DiffViewConfig
	layout        DiffViewLayout
	colors        DiffColors
	code          TextStyle
	numbers       TextStyle
	sel_file      int = -1
	sel_first     int
	sel_last      int
	sel_offsets   []int // Patch position of each hunk's first line in the selected file.
	current_start int = -1
	current_end   int = -1
}

pub fn diff_view(config DiffViewConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	layout := diff_view_layout(config)
	colors := diff_colors(config.theme)
	s := config.state
	mut build := DiffBuild{
		config:  config
		layout:  layout
		colors:  colors
		code:    diff_code_style(layout.metrics, colors.text)
		numbers: TextStyle{
			...diff_code_style(layout.metrics, colors.muted)
			align: .right
		}
	}
	if fi, first, last := s.selection_span() {
		mut offsets := []int{}
		mut pos := 0
		for hunk in s.files[fi].hunks {
			offsets << pos
			pos += hunk.lines.len
		}
		build = DiffBuild{
			...build
			sel_file:    fi
			sel_first:   first
			sel_last:    last
			sel_offsets: offsets
		}
	}
	if s.current >= 0 && s.current < s.rows.len {
		mut end := s.current + 1
		for end < s.rows.len && (s.rows[end].kind == .annotation || s.row_is_change(s.rows[end])) {
			end++
		}
		build = DiffBuild{
			...build
			current_start: s.current
			current_end:   end
		}
	}
	mut line_rows := []Element{}
	mut overlays := []Element{}
	mut cells := map[string][]Element{}
	range := layout.range
	for r in range.start .. range.end {
		row := s.rows[r]
		height := layout.rows.item_size(r)
		if height <= 0 {
			continue
		}
		y := layout.rows.item_start(r)
		match row.kind {
			.line {
				line_rows << build.line_row(r, row, y, height, mut cells)
			}
			.file_header {
				overlays << build.file_header(r, row, y, height)
			}
			.file_summary {
				overlays << build.file_summary(r, row, y, height)
			}
			.hunk {
				overlays << build.hunk_row(r, row, y, height)
			}
			.fold {
				overlays << build.fold_row(r, row, y, height)
			}
			.conflict {
				overlays << build.conflict_row(r, row, y, height)
			}
			.annotation {
				overlays << build.annotation_row(r, row, y, height)
			}
		}
	}
	mut body_children := []Element{cap: line_rows.len + overlays.len + 4}
	body_children << Element{
		...view('', rect(0, 0, 1, layout.content_height()), BoxStyle{ transparent: true },
			[]Element{})
		key: 'extent'
	}
	body_children << line_rows
	body_children << build.code_columns(cells)
	body_children << overlays
	body := Element{
		...scroll_with_mode(diff_body_id(config.id), layout.body, colors.surface, .vertical_only,
			body_children)
		key:                 'body'
		accessibility_role:  'list'
		accessibility_label: 'Diff rows'
	}
	mut children := [body]
	if s.files.len == 0 {
		children << Element{
			...label('', config.empty_text, layout.body, TextStyle{
				color: colors.muted
				size:  layout.metrics.text_size
				align: .center
			})
			key: 'empty'
		}
	}
	box_style := if config.bordered {
		component_box(colors.surface, colors.border, layout.metrics.radius)
	} else {
		BoxStyle{
			bg: colors.surface
		}
	}
	mut additions := 0
	mut deletions := 0
	for file in s.files {
		additions += file.additions
		deletions += file.deletions
	}
	return component_finish(Element{
		...view(config.id, config.frame, box_style, children)
		accessibility_role:  'group'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			'Diff'
		}
		accessibility_value: '${s.files.len} files, ${additions} additions, ${deletions} deletions'
	})
}

// diff_cell_line is the line a row shows on a side, if any.
fn diff_cell_line(s DiffState, row DiffRow, side DiffSide) ?DiffLine {
	k := if side == .original { row.old } else { row.new }
	if k < 0 {
		return none
	}
	return s.files[row.file].hunks[row.hunk].lines[k]
}

fn (b &DiffBuild) in_current(r int) bool {
	return r >= b.current_start && r < b.current_end
}

fn (b &DiffBuild) selected(row DiffRow, side DiffSide, k int) bool {
	if b.sel_file != row.file || k < 0 {
		return false
	}
	s := b.config.state
	line := s.files[row.file].hunks[row.hunk].lines[k]
	pos := b.sel_offsets[row.hunk] + k
	return s.selection_contains(line, side, pos, b.sel_first, b.sel_last)
}

// DiffCellLook is how one side of a line row is painted.
struct DiffCellLook {
	bg       u32
	gutter   u32
	strong   u32
	marker   string
	mark     u32
	selected bool
}

fn (b &DiffBuild) look(row DiffRow, line DiffLine, side DiffSide, k int, paired bool) DiffCellLook {
	c := b.colors
	cfg := b.config
	mut look := DiffCellLook{
		bg:     c.surface
		gutter: c.gutter
	}
	if row.conflict >= 0 && row.part != .resolved {
		look = match row.part {
			.ours {
				DiffCellLook{
					bg:     c.ours
					gutter: c.ours_heading
					mark:   c.accent
				}
			}
			.base {
				DiffCellLook{
					bg:     c.base
					gutter: c.base_heading
					mark:   c.muted
				}
			}
			else {
				DiffCellLook{
					bg:     c.theirs
					gutter: c.theirs_heading
					mark:   c.theirs_heading
				}
			}
		}
	} else if line.kind == .added {
		look = DiffCellLook{
			bg:     if cfg.change_background { c.added } else { c.surface }
			gutter: c.added_gutter
			strong: c.added_strong
			marker: '+'
			mark:   if paired && cfg.change_indicator == .bars {
				c.modified_mark
			} else {
				c.added_mark
			}
		}
	} else if line.kind == .removed {
		look = DiffCellLook{
			bg:     if cfg.change_background { c.removed } else { c.surface }
			gutter: c.removed_gutter
			strong: c.removed_strong
			marker: '−'
			mark:   if paired && cfg.change_indicator == .bars {
				c.modified_mark
			} else {
				c.removed_mark
			}
		}
	}
	if b.selected(row, side, k) {
		look = DiffCellLook{
			...look
			bg:       choice_mix(look.bg, c.accent, 0.12)
			gutter:   c.selected_gutter
			selected: true
		}
	}
	return look
}

fn (b &DiffBuild) number_button(r int, side DiffSide, n int, x f64, height f64) Element {
	tag_side := if side == .original { 'o' } else { 'm' }
	pad := b.layout.metrics.padding
	nw := b.layout.number_width
	which := if side == .original { 'original' } else { 'modified' }
	return Element{
		...diff_button(component_part_id(b.config.id, 'line:${r}:${tag_side}'), rect(x, 0,
			nw, height), [
			label('', n.str(), rect(pad - b.layout.inset / 2, 0, nw - 2 * pad + b.layout.inset,
				height), b.numbers),
		])
		key:                 'n' + tag_side
		cursor:              cursor_pointing_hand
		accessibility_label: 'Select ${which} line ${n}'
	}
}

fn (b &DiffBuild) marker(look DiffCellLook, x f64, height f64, key string) ?Element {
	mw := b.layout.marker_width
	match b.config.change_indicator {
		.signs {
			if look.marker.len == 0 {
				return none
			}
			return Element{
				...label('', look.marker, rect(x, 0, mw, height), TextStyle{
					...b.code
					color: look.mark
					align: .center
					bold:  true
				})
				key: key
			}
		}
		.bars {
			if look.mark == 0 {
				return none
			}
			return Element{
				...view('', rect(x + 2, 0, 3, height), BoxStyle{
					bg: look.mark
				}, []Element{})
				key: key
			}
		}
		.none {
			return none
		}
	}
}

// line_row builds a source row: its backgrounds, numbers and markers here, its
// code into the code column of its file and side.
fn (b &DiffBuild) line_row(r int, row DiffRow, y f64, height f64, mut cells map[string][]Element) Element {
	s := b.config.state
	file := s.files[row.file]
	cols := diff_columns(b.config, b.layout, file)
	w := b.layout.body.width
	mut children := []Element{cap: 12}
	if cols.split {
		left := diff_cell_line(s, row, .original)
		right := diff_cell_line(s, row, .modified)
		paired := row.old >= 0 && row.new >= 0 && row.old != row.new
		mut old_ranges := []DiffInlineRange{}
		mut new_ranges := []DiffInlineRange{}
		mut left_text := ''
		mut right_text := ''
		if l := left {
			left_text = diff_display_text(l.text)
		}
		if rl := right {
			right_text = diff_display_text(rl.text)
		}
		if paired {
			old_ranges, new_ranges = b.inline(left_text, right_text)
		}
		for side in [DiffSide.original, .modified] {
			x0 := if side == .original { 0.0 } else { cols.divider_x + 1 }
			x1 := if side == .original { cols.half } else { w }
			code_x := if side == .original { cols.code_x } else { cols.r_code_x }
			marker_x := if side == .original { cols.marker_x } else { cols.r_marker_x }
			number_x := if side == .original { cols.old_x } else { cols.r_new_x }
			side_line := if side == .original { left } else { right }
			k := if side == .original { row.old } else { row.new }
			key := if side == .original { 'l' } else { 'r' }
			if line := side_line {
				look := b.look(row, line, side, k, paired)
				children << Element{
					...view('', rect(x0, 0, x1 - x0, height), BoxStyle{
						bg: look.bg
					}, []Element{})
					key: key + 'bg'
				}
				children << Element{
					...view('', rect(x0, 0, code_x - x0, height), BoxStyle{
						bg: look.gutter
					}, []Element{})
					key: key + 'gutter'
				}
				n := line.number(side)
				if number_x >= 0 && n > 0 {
					children << Element{
						...b.number_button(r, side, n, number_x, height)
						key: key + 'num'
					}
				}
				if mark := b.marker(look, marker_x, height, key + 'mark') {
					children << mark
				}
				display := if side == .original { left_text } else { right_text }
				ranges := if side == .original { old_ranges } else { new_ranges }
				cells[diff_cell_key(row.file, side)] << b.code_cell(r, side, line, display,
					ranges, look, y, height, if side == .original {
						cols.code_w
					} else {
						cols.r_code_w
					})
			} else {
				children << Element{
					...view('', rect(x0, 0, x1 - x0, height), BoxStyle{
						bg: b.colors.empty
					}, []Element{})
					key: key + 'empty'
				}
			}
		}
		children << Element{
			...view('', rect(cols.divider_x, 0, 1, height), BoxStyle{
				bg: b.colors.border
			}, []Element{})
			key: 'divider'
		}
	} else {
		// One code column: a context row shows its line once; a removed or
		// added row its one line. Conflict lines are on the modified side.
		side := if row.new >= 0 { DiffSide.modified } else { DiffSide.original }
		k := if side == .modified { row.new } else { row.old }
		line := s.files[row.file].hunks[row.hunk].lines[k]
		display := diff_display_text(line.text)
		mut ranges := []DiffInlineRange{}
		if row.pair >= 0 {
			partner := s.files[row.file].hunks[row.hunk].lines[row.pair]
			partner_text := diff_display_text(partner.text)
			old_ranges, new_ranges := if line.kind == .removed {
				b.inline(display, partner_text)
			} else {
				b.inline(partner_text, display)
			}
			ranges = if line.kind == .removed { old_ranges } else { new_ranges }
		}
		look := b.look(row, line, side, k, row.pair >= 0)
		code_x := cols.code_x
		children << Element{
			...view('', rect(0, 0, w, height), BoxStyle{
				bg: look.bg
			}, []Element{})
			key: 'bg'
		}
		children << Element{
			...view('', rect(0, 0, code_x, height), BoxStyle{
				bg: look.gutter
			}, []Element{})
			key: 'gutter'
		}
		if file.single_column() {
			if cols.new_x >= 0 {
				children << b.number_button(r, .modified, line.new_line, cols.new_x, height)
			}
		} else {
			if cols.old_x >= 0 && line.old_line > 0 && row.old >= 0 {
				children << b.number_button(r, .original, line.old_line, cols.old_x, height)
			}
			if cols.new_x >= 0 && line.new_line > 0 && row.new >= 0 {
				children << b.number_button(r, .modified, line.new_line, cols.new_x, height)
			}
		}
		if mark := b.marker(look, cols.marker_x, height, 'mark') {
			children << mark
		}
		cells[diff_cell_key(row.file, .modified)] << b.code_cell(r, side, line, display, ranges,
			look, y, height, cols.code_w)
	}
	if b.in_current(r) {
		children << Element{
			...view('', rect(0, 0, 3, height), BoxStyle{
				bg: b.colors.accent
			}, []Element{})
			key: 'current'
		}
	}
	return Element{
		...view('', rect(0, y, w, height), BoxStyle{ transparent: true }, children)
		key:                 'row:${r}'
		accessibility_role:  'row'
		accessibility_label: diff_row_label(s, row)
	}
}

fn diff_row_label(s DiffState, row DiffRow) string {
	lines := s.files[row.file].hunks[row.hunk].lines
	mut parts := []string{}
	for k in [row.old, row.new] {
		if k < 0 || (parts.len > 0 && row.old == row.new) {
			continue
		}
		line := lines[k]
		word := match line.kind {
			.context { 'Line ${line.new_line}' }
			.removed { 'Removed line ${line.old_line}' }
			.added { 'Added line ${line.new_line}' }
		}
		parts << '${word}: ${line.text}'
	}
	return parts.join('; ')
}

fn diff_cell_key(file int, side DiffSide) string {
	return '${file}:${if side == .original { 'o' } else { 'm' }}'
}

fn (b &DiffBuild) inline(old_text string, new_text string) ([]DiffInlineRange, []DiffInlineRange) {
	s := b.config.state
	if s.inline_unit == .none || old_text.len > s.inline_max || new_text.len > s.inline_max {
		return []DiffInlineRange{}, []DiffInlineRange{}
	}
	return diff_inline_ranges(old_text, new_text, s.inline_unit)
}

fn diff_is_ascii(text string) bool {
	for c in text.bytes() {
		if c >= 0x80 {
			return false
		}
	}
	return true
}

// text_width is how far text reaches from where its first glyph starts.
fn (b &DiffBuild) text_width(runes []rune, ascii bool, count int) f64 {
	if count <= 0 {
		return 0
	}
	if ascii {
		return f64(count) * b.layout.advance
	}
	return math.max(0.0, measure_text_width(runes[..math.min(count, runes.len)].string(), b.code) - b.layout.inset)
}

// code_cell is a line's code: the boxes behind its changed words, then the
// text. A click on it selects the line, as a click on its number does.
fn (b &DiffBuild) code_cell(r int, side DiffSide, line DiffLine, display string, ranges []DiffInlineRange, look DiffCellLook, y f64, height f64, column_width f64) Element {
	runes := display.runes()
	ascii := diff_is_ascii(display)
	width := b.text_width(runes, ascii, runes.len)
	mut children := []Element{cap: ranges.len + 2}
	for i, span in ranges {
		x0 := diff_code_pad + b.text_width(runes, ascii, span.start)
		x1 := diff_code_pad + b.text_width(runes, ascii, span.end)
		children << Element{
			...view('', rect(x0, 2, math.max(2.0, x1 - x0), height - 4), BoxStyle{
				bg:     look.strong
				radius: 3
			}, []Element{})
			key: 'hl${i}'
		}
	}
	inset := b.layout.inset
	children << Element{
		...label('', display, rect(diff_code_pad - inset / 2, 0, width + inset + b.layout.advance,
			height), b.code)
		key: 'text'
	}
	if line.no_newline {
		icon := math.round(b.layout.metrics.code_size)
		children << Element{
			...with_tooltip(image('', 'symbol:minus.circle', rect(diff_code_pad + width +
				b.layout.advance, (height - icon) / 2, icon, icon)), 'No newline at end of file')
			key:        'eol'
			text_style: TextStyle{
				color: b.colors.removed_mark
			}
		}
	}
	tag_side := if side == .original { 'o' } else { 'm' }
	cell_width := math.max(column_width, width + 2 * diff_code_pad + inset + 3 * b.layout.advance)
	return Element{
		...diff_button(component_part_id(b.config.id, 'line:${r}:${tag_side}'), rect(0, y, cell_width,
			height), children)
		key:                 'row:${r}'
		accessibility_label: if display.len > 0 { display } else { 'Empty line' }
	}
}

// code_columns builds the horizontal Scroll element of each file side with
// rows in range, holding those rows' code. The content is as wide as the
// file's longest line on that side, whichever rows are built.
fn (b &DiffBuild) code_columns(cells map[string][]Element) []Element {
	s := b.config.state
	layout := b.layout
	mut out := []Element{}
	for fi, file in s.files {
		first := s.file_rows[fi]
		last := if fi + 1 < s.file_rows.len { s.file_rows[fi + 1] - 1 } else { s.rows.len - 1 }
		if last <= first {
			continue
		}
		y0 := layout.rows.item_end(first)
		y1 := layout.rows.item_end(last) + layout.tail
		if y1 <= y0 + layout.tail {
			continue
		}
		cols := diff_columns(b.config, layout, file)
		for side in [DiffSide.original, .modified] {
			key := diff_cell_key(fi, side)
			if key !in cells {
				continue
			}
			right := cols.split && side == .modified
			x := if right { cols.r_code_x } else { cols.code_x }
			w := if right { cols.r_code_w } else { cols.code_w }
			// In one column every line is on the .modified key; the widest
			// line may be on either side.
			columns := if cols.split {
				s.columns[fi][if side == .original { 0 } else { 1 }]
			} else {
				math.max(s.columns[fi][0], s.columns[fi][1])
			}
			content := f64(columns) * layout.advance + 2 * diff_code_pad + layout.inset +
				3 * layout.advance
			mut children := []Element{cap: cells[key].len + 1}
			children << Element{
				...view('', rect(0, 0, math.max(w, content), 1), BoxStyle{ transparent: true },
					[]Element{})
				key: 'extent'
			}
			for cell in cells[key] {
				children << Element{
					...cell
					frame: rect(cell.frame.x, cell.frame.y - y0, cell.frame.width, cell.frame.height)
				}
			}
			out << Element{
				...scroll_with_mode(diff_code_scroll_id(b.config.id, fi, side), rect(x, y0,
					w, y1 - y0), b.colors.surface, .horizontal_only, children)
				box:                 BoxStyle{
					transparent: true
				}
				key:                 'code:' + key
				accessibility_label: '${file.path()} code'
			}
		}
	}
	return out
}

// ── Other rows ──────────────────────────────────────────────────────

// diff_button is a transparent composite button that emits action. Several
// may emit the same action (a line's number and its code), so it has no id.
fn diff_button(action string, frame Rect, children []Element) Element {
	return with_action(button_view('', frame, BoxStyle{ transparent: true }, children), action)
}

fn (b &DiffBuild) text_style(color u32, bold bool) TextStyle {
	return TextStyle{
		color: color
		size:  b.layout.metrics.text_size
		bold:  bold
	}
}

fn (b &DiffBuild) symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

// pill is a small rounded badge with text, sized to it.
fn (b &DiffBuild) pill(text string, right f64, y f64, height f64, fg u32, bg u32, key string) (Element, f64) {
	style := TextStyle{
		color: fg
		size:  b.layout.metrics.text_size - 2
		bold:  true
		align: .center
	}
	width := math.ceil(measure_text_width(text, style) + 14)
	return Element{
		...view('', rect(right - width, y, width, height), BoxStyle{
			bg:     bg
			radius: height / 2
		}, [label('', text, rect(0, 0, width, height), style)])
		key: key
	}, width
}

fn (b &DiffBuild) file_header(r int, row DiffRow, y f64, height f64) Element {
	s := b.config.state
	c := b.colors
	m := b.layout.metrics
	file := s.files[row.file]
	gap := if row.file > 0 { m.file_gap } else { 0.0 }
	h := height - gap
	w := b.layout.body.width
	pad := m.padding + 4
	collapsed := s.is_file_collapsed(file.path())
	mut children := []Element{cap: 16}
	icon := math.round(m.text_size)
	children << b.symbol(if collapsed { 'chevron.right' } else { 'chevron.down' }, rect(pad,
		(h - icon) / 2, icon, icon), c.muted)
	mut x := pad + icon + 8
	// The right side, laid out from the right edge: status, blocks, counts.
	mut right := w - pad
	pill_h := math.round(m.text_size + 6)
	status_text, status_tone := diff_status_badge(s, row.file)
	tone_color := diff_tone_color(b.config.theme, status_tone)
	badge, badge_w := b.pill(status_text, right, (h - pill_h) / 2, pill_h, tone_color,
		choice_mix(c.header, tone_color, 0.16), 'status')
	children << badge
	right -= badge_w + 10
	total := file.additions + file.deletions
	if total > 0 {
		block := 8.0
		green := int(math.round(5 * f64(file.additions) / f64(total)))
		for i in 0 .. 5 {
			bx := right - f64(5 - i) * (block + 2)
			children << Element{
				...view('', rect(bx, (h - block) / 2, block, block), BoxStyle{
					bg:     if i < green { c.added_mark } else { c.removed_mark }
					radius: 2
				}, []Element{})
				key: 'block${i}'
			}
		}
		right -= 5 * (block + 2) + 8
		minus := '−${file.deletions}'
		plus := '+${file.additions}'
		minus_style := TextStyle{
			...b.text_style(c.removed_mark, true)
			align: .right
		}
		plus_style := TextStyle{
			...b.text_style(c.added_mark, true)
			align: .right
		}
		mw := math.ceil(measure_text_width(minus, minus_style))
		children << label('', minus, rect(right - mw, 0, mw, h), minus_style)
		right -= mw + 6
		pw := math.ceil(measure_text_width(plus, plus_style))
		children << label('', plus, rect(right - pw, 0, pw, h), plus_style)
		right -= pw + 12
	}
	// The path, or `old → new` for a rename or copy.
	path_style := b.text_style(c.text, true)
	room := math.max(0.0, right - x)
	if file.status in [.renamed, .copied] && file.old_path.len > 0 && file.old_path != file.new_path {
		old_style := b.text_style(c.muted, false)
		old_w := math.min(math.ceil(measure_text_width(file.old_path, old_style)), room * 0.45)
		children << label('', file.old_path, rect(x, 0, old_w, h), old_style)
		x += old_w + 6
		children << b.symbol('arrow.right', rect(x, (h - icon) / 2, icon, icon), c.muted)
		x += icon + 6
	}
	new_w := math.min(math.ceil(measure_text_width(file.path(), path_style)), math.max(0.0,
		right - x))
	children << label('', file.path(), rect(x, 0, new_w, h), path_style)
	el := with_action(button_view('', rect(0, y + gap, w, h), BoxStyle{
		bg:            c.header
		border_color:  c.border
		border_top:    if row.file > 0 { 1 } else { 0 }
		border_bottom: 1
	}, children), component_part_id(b.config.id, 'file:${row.file}'))
	// The gap above the header is left empty: the code columns of the file
	// before keep their horizontal scrollers there.
	return Element{
		...el
		key:                 'row:${r}'
		cursor:              cursor_pointing_hand
		accessibility_label: '${if collapsed { 'Expand' } else { 'Collapse' }} ${file.path()}'
		accessibility_value: if collapsed { 'collapsed' } else { 'expanded' }
	}
}

// diff_status_badge is the word a file's header shows and its tone.
fn diff_status_badge(s DiffState, fi int) (string, ComponentTone) {
	file := s.files[fi]
	if file.conflicts.len > 0 {
		mut open := 0
		for ix in 0 .. file.conflicts.len {
			if diff_conflict_key(file.path(), ix) !in s.resolutions {
				open++
			}
		}
		if open == 0 {
			return 'Resolved', ComponentTone.success
		}
		return if open == 1 { '1 conflict' } else { '${open} conflicts' }, ComponentTone.warning
	}
	if file.binary {
		return 'Binary', ComponentTone.neutral
	}
	return file.status.text(), match file.status {
		.added { ComponentTone.success }
		.deleted { ComponentTone.danger }
		.renamed, .copied { ComponentTone.primary }
		else { ComponentTone.neutral }
	}
}

fn (b &DiffBuild) file_summary(r int, row DiffRow, y f64, height f64) Element {
	file := b.config.state.files[row.file]
	w := b.layout.body.width
	style := TextStyle{
		...b.text_style(b.colors.muted, false)
		italic: true
	}
	tw := math.min(w, math.ceil(measure_text_width(file.summary(), style)))
	return Element{
		...view('', rect(0, y, w, height), BoxStyle{
			bg: b.colors.surface
		}, [label('', file.summary(), rect((w - tw) / 2, 0, tw, height), style)])
		key:                 'row:${r}'
		accessibility_role:  'row'
		accessibility_label: file.summary()
	}
}

fn (b &DiffBuild) hunk_row(r int, row DiffRow, y f64, height f64) Element {
	s := b.config.state
	c := b.colors
	file := s.files[row.file]
	hunk := file.hunks[row.hunk]
	w := b.layout.body.width
	cols := diff_columns(b.config, b.layout, file)
	mut children := []Element{}
	mut caption := ''
	match b.config.hunk_separator {
		.metadata {
			caption = hunk.header()
		}
		.line_info {
			before := if row.hunk == 0 {
				hunk.new_start - 1
			} else {
				prev := file.hunks[row.hunk - 1]
				hunk.new_start - (prev.new_start + prev.new_count)
			}
			caption = if before > 0 {
				'${before} unchanged ${if before == 1 { 'line' } else { 'lines' }} not shown'
			} else {
				''
			}
		}
		.simple {
			children << view('', rect(0, height / 2, w, 1), BoxStyle{
				bg: c.border
			}, []Element{})
		}
	}
	if b.config.hunk_separator != .simple {
		children << view('', rect(0, 0, cols.code_x, height), BoxStyle{
			bg: choice_mix(c.hunk, c.accent, 0.06)
		}, []Element{})
		icon := math.round(b.layout.metrics.code_size)
		children << b.symbol('ellipsis', rect((cols.code_x - icon) / 2, (height - icon) / 2,
			icon, icon), c.hunk_text)
		if caption.len > 0 {
			children << label('', caption, rect(cols.code_x + diff_code_pad - b.layout.inset / 2,
				0, math.max(0.0, w - cols.code_x - diff_code_pad), height), diff_code_style(b.layout.metrics,
				c.hunk_text))
		}
	}
	return Element{
		...view('', rect(0, y, w, height), BoxStyle{
			bg: if b.config.hunk_separator == .simple { c.surface } else { c.hunk }
		}, children)
		key:                 'row:${r}'
		accessibility_role:  'row'
		accessibility_label: if caption.len > 0 { caption } else { 'Hunk' }
	}
}

fn (b &DiffBuild) fold_row(r int, row DiffRow, y f64, height f64) Element {
	s := b.config.state
	c := b.colors
	m := b.layout.metrics
	file := s.files[row.file]
	lines := file.hunks[row.hunk].lines
	w := b.layout.body.width
	cols := diff_columns(b.config, b.layout, file)
	hidden := row.fold_end - row.fold_start
	step := s.expansion_lines
	mut children := []Element{}
	children << view('', rect(0, 0, cols.code_x, height), BoxStyle{
		bg: choice_mix(c.hunk, c.accent, 0.06)
	}, []Element{})
	// Reveal buttons in the gutter: down shows the lines under the source
	// above, up the lines over the source below, both arrows all of them.
	mut edges := []DiffRevealEdge{}
	if hidden <= step || (!row.above && !row.below) {
		edges << .all
	} else {
		if row.above {
			edges << .top
		}
		if row.below {
			edges << .bottom
		}
	}
	gutter := math.max(cols.code_x, 24.0)
	bw := math.min(32.0, gutter / f64(edges.len))
	icon := math.round(m.code_size + 1)
	for i, edge in edges {
		name, edge_name, tip := match edge {
			.top { 'arrow.down', 'top', 'Show ${step} more lines' }
			.bottom { 'arrow.up', 'bottom', 'Show ${step} more lines' }
			.all { 'arrow.up.and.down', 'all', 'Show ${hidden} hidden lines' }
		}
		bx := (gutter - bw * f64(edges.len)) / 2 + f64(i) * bw
		children << Element{
			...with_tooltip(diff_button(component_part_id(b.config.id, 'fold:${r}:${edge_name}'),
				rect(bx, 0, bw, height), [
					b.symbol(name, rect((bw - icon) / 2, (height - icon) / 2, icon, icon), c.accent),
				]), tip)
			key:                 'fold:${edge_name}'
			cursor:              cursor_pointing_hand
			accessibility_label: tip
		}
	}
	first := lines[row.fold_start]
	last := lines[row.fold_end - 1]
	from := if first.new_line > 0 { first.new_line } else { first.old_line }
	to := if last.new_line > 0 { last.new_line } else { last.old_line }
	caption := '${hidden} unchanged ${if hidden == 1 { 'line' } else { 'lines' }} (${from}–${to})'
	style := b.text_style(c.hunk_text, false)
	tx := cols.code_x + diff_code_pad
	tw := math.ceil(measure_text_width(caption, style))
	children << label('', caption, rect(tx, 0, tw, height), style)
	all_style := b.text_style(c.accent, true)
	all_text := 'Show all'
	aw := math.ceil(measure_text_width(all_text, all_style)) + 12
	if tx + tw + 12 + aw <= w {
		children << Element{
			...diff_button(component_part_id(b.config.id, 'fold:${r}:all'), rect(tx + tw + 8,
				0, aw, height), [
				label('', all_text, rect(6, 0, aw - 12, height), all_style),
			])
			key:                 'fold:show-all'
			cursor:              cursor_pointing_hand
			accessibility_label: 'Show ${hidden} hidden lines'
		}
	}
	return Element{
		...view('', rect(0, y, w, height), BoxStyle{
			bg: c.hunk
		}, children)
		key:                 'row:${r}'
		accessibility_role:  'row'
		accessibility_label: caption
	}
}

fn (b &DiffBuild) conflict_row(r int, row DiffRow, y f64, height f64) Element {
	s := b.config.state
	c := b.colors
	m := b.layout.metrics
	file := s.files[row.file]
	conflict := file.conflicts[row.conflict]
	w := b.layout.body.width
	cols := diff_columns(b.config, b.layout, file)
	resolution := s.conflict_resolution(file.path(), row.conflict)
	bg, title, detail := match row.part {
		.ours {
			c.ours_heading, 'Current change', conflict.ours_label
		}
		.base {
			c.base_heading, 'Common ancestor', conflict.base_label
		}
		.theirs {
			c.theirs_heading, 'Incoming change', conflict.theirs_label
		}
		.resolved {
			c.gutter, diff_resolution_text(resolution), ''
		}
	}
	mut children := []Element{}
	icon := math.round(m.text_size)
	x0 := math.max(cols.code_x, 0.0) + diff_code_pad
	symbol := match row.part {
		.ours, .theirs { 'arrow.triangle.2.circlepath' }
		.base { 'clock.arrow.circlepath' }
		.resolved { 'checkmark.circle.fill' }
	}
	children << b.symbol(symbol, rect(math.max(4.0, x0 - icon - 8), (height - icon) / 2, icon,
		icon), if row.part == .resolved { c.added_mark } else { c.text })
	title_style := b.text_style(c.text, true)
	tw := math.ceil(measure_text_width(title, title_style))
	children << label('', title, rect(x0, 0, tw, height), title_style)
	mut x := x0 + tw + 8
	if detail.len > 0 {
		detail_style := b.text_style(c.muted, false)
		dw := math.ceil(measure_text_width(detail, detail_style))
		children << label('', detail, rect(x, 0, math.min(dw, math.max(0.0, w * 0.4)), height),
			detail_style)
		x += dw + 8
	}
	// Actions, from the right edge.
	actions := match row.part {
		.ours {
			[['ours', 'Accept current'], ['theirs', 'Accept incoming'], ['both', 'Accept both']]
		}
		.resolved { [['undo', 'Undo']] }
		else { [][]string{} }
	}
	button_style := TextStyle{
		color: c.accent
		size:  m.text_size - 1
		bold:  true
		align: .center
	}
	bh := math.round(m.text_size + 10)
	mut right := w - m.padding
	for i := actions.len - 1; i >= 0; i-- {
		action := actions[i]
		bw := math.ceil(measure_text_width(action[1], button_style) + 18)
		if right - bw < x {
			break
		}
		right -= bw
		children << Element{
			...button('', action[1], rect(right, (height - bh) / 2, bw, bh), BoxStyle{
				bg:            choice_mix(bg, c.surface, 0.55)
				radius:        5
				border_color:  choice_mix(c.accent, bg, 0.55)
				border_left:   1
				border_top:    1
				border_right:  1
				border_bottom: 1
			}, button_style)
			action_id: component_part_id(b.config.id, 'conflict:${row.file}:${row.conflict}:${action[0]}')
			key:       'action:${action[0]}'
		}
		right -= 6
	}
	return Element{
		...view('', rect(0, y, w, height), BoxStyle{
			bg:           bg
			border_color: choice_mix(bg, c.text, 0.12)
			border_top:   if row.part in [.ours, .resolved] { 1 } else { 0 }
		}, children)
		key:                 'row:${r}'
		accessibility_role:  'row'
		accessibility_label: if detail.len > 0 { '${title}: ${detail}' } else { title }
	}
}

fn diff_resolution_text(resolution ?DiffConflictResolution) string {
	chosen := resolution or { return 'Resolved' }
	return match chosen {
		.ours { 'Accepted current change' }
		.theirs { 'Accepted incoming change' }
		.both { 'Accepted both changes' }
	}
}

fn (b &DiffBuild) annotation_row(r int, row DiffRow, y f64, height f64) Element {
	s := b.config.state
	c := b.colors
	m := b.layout.metrics
	note := s.annotations[row.annotation]
	w := b.layout.body.width
	x, cw := diff_annotation_box(b.config, b.layout, note, row.file)
	ch := math.max(0.0, height - 2 * diff_note_margin)
	tone := diff_tone_color(b.config.theme, note.tone)
	inner := rect(m.padding + 6, m.padding, math.max(0.0, cw - 2 * m.padding - 6), math.max(0.0,
		ch - 2 * m.padding))
	mut content := []Element{}
	content << view('', rect(0, 0, 3, ch), BoxStyle{
		bg:     tone
		radius: 1.5
	}, []Element{})
	if voidptr(b.config.render_annotation) != unsafe { nil } {
		content << view('', inner, BoxStyle{ transparent: true }, b.config.render_annotation(note,
			rect(0, 0, inner.width, inner.height)))
	} else {
		line_h := diff_note_line_height(m)
		mut ly := inner.y
		if note.title.len > 0 {
			content << label('', note.title, rect(inner.x, ly, inner.width, line_h), diff_note_title_style(m,
				c.text))
			ly += line_h
		}
		if note.text.len > 0 {
			for line in diff_annotation_lines(b.config, b.layout, note, row.file) {
				content << label('', line, rect(inner.x, ly, inner.width, line_h), diff_note_text_style(m,
					c.text))
				ly += line_h
			}
		}
	}
	card := view('', rect(x, diff_note_margin, cw, ch), BoxStyle{
		bg:            choice_mix(c.note, tone, 0.05)
		radius:        m.radius
		border_color:  c.note_border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, content)
	// The row keeps the background of the code it hangs under.
	mut children := []Element{}
	if note.line > 0 {
		file := s.files[row.file]
		cols := diff_columns(b.config, b.layout, file)
		children << view('', rect(0, 0, cols.code_x, height), BoxStyle{
			bg: c.gutter
		}, []Element{})
		if cols.split {
			children << view('', rect(cols.divider_x + 1, 0, cols.r_code_x - cols.divider_x - 1,
				height), BoxStyle{
				bg: c.gutter
			}, []Element{})
			children << view('', rect(cols.divider_x, 0, 1, height), BoxStyle{
				bg: c.border
			}, []Element{})
		}
	}
	children << card
	return Element{
		...view('', rect(0, y, w, height), BoxStyle{
			bg: c.surface
		}, children)
		key:                 'row:${r}'
		accessibility_role:  'note'
		accessibility_label: if note.title.len > 0 {
			'${note.title}: ${note.text}'
		} else {
			note.text
		}
	}
}

// ── Scrolling helpers ───────────────────────────────────────────────

// diff_top_row is the row at the top of the body.
pub fn diff_top_row(config DiffViewConfig) int {
	layout := diff_view_layout(config)
	return layout.rows.index_at(layout.scroll_y)
}

// diff_scroll_offset_for_row is the body offset that brings a row into view,
// aligned as asked; pass it to scroll_to_offset with diff_body_id.
pub fn diff_scroll_offset_for_row(config DiffViewConfig, row int, align VirtualListAlign) f64 {
	layout := diff_view_layout(config)
	return diff_offset_for(layout, row, align)
}

fn diff_offset_for(layout DiffViewLayout, row int, align VirtualListAlign) f64 {
	if layout.rows.count == 0 {
		return 0
	}
	target := layout.rows.scroll_offset_for(row, layout.body.height, layout.scroll_y, align)
	return math.min(math.max(target, 0.0), layout.max_offset())
}

// diff_top_position is the source line at the top of the body (the first line
// row there or below), to scroll back to after the rows change: a new mode, more
// or less context.
pub fn diff_top_position(config DiffViewConfig) ?DiffLinePosition {
	s := config.state
	top := diff_top_row(config)
	if top < 0 {
		return none
	}
	for r in top .. s.rows.len {
		if s.rows[r].kind != .line {
			continue
		}
		if pos := s.row_position(r, .modified) {
			return pos
		}
		if pos := s.row_position(r, .original) {
			return pos
		}
	}
	return none
}

// ── Events ──────────────────────────────────────────────────────────

// diff_event_from_action decodes what the view emitted: a header click
// (collapse or expand the file), a fold button (reveal lines), a click on a
// line number or code (select it; with Shift held, extend the selection from
// its anchor), and a conflict's Accept or Undo button. It returns none for
// actions that are not this view's, malformed or forged ones, and requests that
// would change nothing.
pub fn diff_event_from_action(config DiffViewConfig, action string) ?DiffEvent {
	return diff_event_from_click(config, action, key_modifiers())
}

// diff_event_from_click is diff_event_from_action with the modifier keys given
// rather than read: Shift extends a selection.
pub fn diff_event_from_click(config DiffViewConfig, action string, modifiers KeyModifiers) ?DiffEvent {
	part := component_action_part(config.id, action)?
	s := config.state
	if part.starts_with('file:') {
		fi := component_parse_index(part['file:'.len..], s.files.len - 1)?
		path := s.files[fi].path()
		return DiffEvent{
			kind:      .file_collapsed
			path:      path
			collapsed: !s.is_file_collapsed(path)
		}
	}
	if part.starts_with('fold:') {
		rest := part['fold:'.len..]
		colon := rest.index(':')?
		r := component_parse_index(rest[..colon], s.rows.len - 1)?
		edge := match rest[colon + 1..] {
			'top' { DiffRevealEdge.top }
			'bottom' { DiffRevealEdge.bottom }
			'all' { DiffRevealEdge.all }
			else { return none }
		}
		row := s.rows[r]
		if row.kind != .fold || (edge == .top && !row.above) || (edge == .bottom && !row.below) {
			return none
		}
		return DiffEvent{
			kind: .reveal
			path: s.files[row.file].path()
			row:  r
			edge: edge
		}
	}
	if part.starts_with('line:') {
		rest := part['line:'.len..]
		colon := rest.index(':')?
		r := component_parse_index(rest[..colon], s.rows.len - 1)?
		side := match rest[colon + 1..] {
			'o' { DiffSide.original }
			'm' { DiffSide.modified }
			else { return none }
		}
		pos := s.row_position(r, side)?
		extend := modifiers.shift && s.has_selection && s.anchor.path == pos.path
			&& (s.anchor.side == pos.side || s.mode == .unified)
		range := s.click_range(pos, extend)?
		return DiffEvent{
			kind:   .select
			path:   pos.path
			row:    r
			range:  range
			anchor: if extend { s.anchor } else { pos }
		}
	}
	if part.starts_with('conflict:') {
		fields := part['conflict:'.len..].split(':')
		if fields.len != 3 {
			return none
		}
		fi := component_parse_index(fields[0], s.files.len - 1)?
		file := s.files[fi]
		ci := component_parse_index(fields[1], file.conflicts.len - 1)?
		path := file.path()
		current := s.conflict_resolution(path, ci)
		if fields[2] == 'undo' {
			if current == none {
				return none
			}
			return DiffEvent{
				kind:     .conflict_resolved
				path:     path
				conflict: ci
				undo:     true
			}
		}
		resolution := match fields[2] {
			'ours' { DiffConflictResolution.ours }
			'theirs' { DiffConflictResolution.theirs }
			'both' { DiffConflictResolution.both }
			else { return none }
		}
		if chosen := current {
			if chosen == resolution {
				return none
			}
		}
		return DiffEvent{
			kind:       .conflict_resolved
			path:       path
			conflict:   ci
			resolution: resolution
		}
	}
	return none
}

// diff_navigate goes to the next (forward) or previous change, or hunk with
// by_hunk, across all files, wrapping at the ends. It starts from the change
// navigation last went to while that is on screen, and otherwise from the top
// of the body. Apply the event, then scroll the body to its offset.
pub fn diff_navigate(config DiffViewConfig, forward bool, by_hunk bool) ?DiffEvent {
	s := config.state
	layout := diff_view_layout(config)
	visible_start := layout.range.visible_start
	visible_end := layout.range.visible_end
	current := s.current
	from := if current >= visible_start && current < visible_end {
		current
	} else if forward {
		visible_start - 1
	} else {
		visible_start
	}
	row := if by_hunk {
		if forward { s.next_hunk(from)? } else { s.previous_hunk(from)? }
	} else {
		if forward { s.next_change(from)? } else { s.previous_change(from)? }
	}
	// Leave a little of what comes before in view.
	m := layout.metrics
	start := layout.rows.item_start(row)
	shown := start >= layout.scroll_y + m.row_height
		&& start + 3 * m.row_height <= layout.scroll_y + layout.body.height
	offset := if shown {
		layout.scroll_y
	} else {
		math.min(math.max(start - 3 * m.row_height, 0.0), layout.max_offset())
	}
	return DiffEvent{
		kind:   .navigate
		row:    row
		offset: offset
	}
}

// diff_event_from_key is for on_key_event while the diff is what the keyboard
// drives (components cannot take focus):
//
// - Up, Down, Page Up, Page Down, Home, End scroll (`.scroll`).
// - Shift+Up and Shift+Down extend the line selection (`.select`).
// - Cmd+C or Ctrl+C copies the selection (`.copy`), Cmd+A or Ctrl+A selects
//   every line of the selected (or topmost) file's side, Escape clears it.
// - F7 and Shift+F7 go to the next and previous change, Alt+Down and Alt+Up
//   to the next and previous hunk (`.navigate`).
pub fn diff_event_from_key(config DiffViewConfig, event KeyEvent) ?DiffEvent {
	s := config.state
	layout := diff_view_layout(config)
	command := event.cmd || event.ctrl
	top := layout.rows.index_at(layout.scroll_y)
	if command && !event.alt && !event.shift {
		match event.code {
			.c {
				if !s.has_selection {
					return none
				}
				return DiffEvent{
					kind:   .copy
					format: .source
				}
			}
			.a {
				range := s.all_range(top)?
				return DiffEvent{
					kind:   .select
					path:   range.path
					range:  range
					anchor: DiffLinePosition{range.path, range.side, range.start}
				}
			}
			else {
				return none
			}
		}
	}
	if event.code == .f7 && !command && !event.alt {
		return diff_navigate(config, !event.shift, false)
	}
	if event.alt && !command && !event.shift && (event.code == .up || event.code == .down) {
		return diff_navigate(config, event.code == .down, true)
	}
	if event.shift && !command && !event.alt && (event.code == .up || event.code == .down) {
		range := s.extended_range(if event.code == .down { 1 } else { -1 }, top)?
		anchor := if s.has_selection && s.anchor.path == range.path && s.anchor.side == range.side {
			s.anchor
		} else {
			DiffLinePosition{range.path, range.side, range.start}
		}
		moved := if anchor.line == range.start { range.end } else { range.start }
		row := s.row_for_line(DiffLinePosition{range.path, range.side, moved}) or { -1 }
		offset := if row >= 0 { diff_offset_for(layout, row, .nearest) } else { layout.scroll_y }
		return DiffEvent{
			kind:   .select
			path:   range.path
			row:    row
			range:  range
			anchor: anchor
			offset: offset
		}
	}
	if command || event.alt || event.shift {
		return none
	}
	if event.code == .escape {
		if !s.has_selection {
			return none
		}
		return DiffEvent{
			kind: .clear_selection
		}
	}
	page := math.max(layout.metrics.row_height, layout.body.height - 2 * layout.metrics.row_height)
	target := match event.code {
		.up { layout.scroll_y - layout.metrics.row_height * 3 }
		.down { layout.scroll_y + layout.metrics.row_height * 3 }
		.page_up { layout.scroll_y - page }
		.page_down { layout.scroll_y + page }
		.home { 0.0 }
		.end { layout.max_offset() }
		else { return none }
	}
	clamped := math.min(math.max(target, 0.0), layout.max_offset())
	if clamped == layout.scroll_y {
		return none
	}
	return DiffEvent{
		kind:   .scroll
		offset: clamped
	}
}
