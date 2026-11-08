module ui2

import math

// styled_label is GPUI Kit's Label on top of ui2's label element: secondary
// text in a muted color, highlighted matches of a search, masking for
// sensitive values, alignment, wrapping and line height. A ui2 label has one
// style, so the text is cut into runs (the main text, the secondary text and
// each highlighted match) along the lines it wraps onto, and every run is a
// label of its own, set after the previous one with measure_text_width.

// LabelMatch says where a highlight may match.
pub enum LabelMatch {
	full   // every occurrence, overlapping ones included
	prefix // only at the very start of the text
}

// LabelRange is a stretch of a label's text in runes, end exclusive.
pub struct LabelRange {
pub:
	start int
	end   int
}

pub struct StyledLabelConfig {
pub:
	id    string
	frame Rect
	text  string
	// secondary follows the text after a space, in the muted color: an
	// "(optional)" or a required marker.
	secondary       string
	secondary_color ?u32
	// highlight marks every case-insensitive match of it, or only one at the
	// start with highlight_match: .prefix. Matches may run into the secondary
	// text.
	highlight            string
	highlight_match      LabelMatch
	highlight_color      ?u32 // Defaults to the theme's primary color.
	highlight_background bool // Also lays a soft mark behind each match.
	// masked shows a bullet for every character, for a balance or a key; the
	// highlights are not shown then, and assistive technology reads masked_label.
	masked       bool
	masked_label string = 'Hidden'
	align        Align
	valign       VAlign = .middle
	wrap         bool   = true // Break lines at the frame's width.
	max_lines    int  // Zero shows as many lines as the frame's height holds.
	line_height  f64  // Zero is 1.45 times the font size.
	color        ?u32 // Defaults to the theme's foreground.
	font_size    f64  // Zero takes the size's font size.
	bold         bool
	italic       bool
	font_family  string
	size         ComponentSize = .medium
	theme        ComponentTheme
}

// label_full_text is the text a styled_label shows: the text, then the
// secondary text after a space.
pub fn label_full_text(text string, secondary string) string {
	return if secondary.len > 0 { '${text} ${secondary}' } else { text }
}

// label_masked_text replaces every character of text with a bullet.
pub fn label_masked_text(text string) string {
	return '•'.repeat(text.runes().len)
}

// label_highlight_ranges finds query in text, ignoring case: every occurrence
// (overlapping ones too) with .full, or the start of the text alone with
// .prefix. Offsets are runes. An empty query matches nothing.
pub fn label_highlight_ranges(text string, query string, mode LabelMatch) []LabelRange {
	needle := query.runes().map(it.to_lower())
	if needle.len == 0 {
		return []LabelRange{}
	}
	hay := text.runes().map(it.to_lower())
	if needle.len > hay.len {
		return []LabelRange{}
	}
	mut ranges := []LabelRange{}
	last := if mode == .prefix { 0 } else { hay.len - needle.len }
	for start := 0; start <= last; start++ {
		mut matched := true
		for i, r in needle {
			if hay[start + i] != r {
				matched = false
				break
			}
		}
		if matched {
			ranges << LabelRange{start, start + needle.len}
		}
	}
	return ranges
}

fn styled_label_font(config StyledLabelConfig) f64 {
	return if component_finite(config.font_size) && config.font_size > 0 {
		config.font_size
	} else {
		component_metrics(config.size).font_size
	}
}

// styled_label_line_height is the height of one line of a styled_label.
pub fn styled_label_line_height(config StyledLabelConfig) f64 {
	if component_finite(config.line_height) && config.line_height > 0 {
		return config.line_height
	}
	return math.round(styled_label_font(config) * 1.45)
}

fn styled_label_base(config StyledLabelConfig) TextStyle {
	return TextStyle{
		color:       config.color or { config.theme.foreground }
		size:        styled_label_font(config)
		bold:        config.bold
		italic:      config.italic
		font_family: config.font_family
	}
}

// StyledLabelPlan is a styled_label laid out: its text, the lines it shows
// (the last one carrying the rest of a text too long for the frame), which
// runes are secondary and which highlighted.
struct StyledLabelPlan {
	runes     []rune
	main      int // Runes before the secondary text.
	marks     []bool
	lines     []BasicsSpan
	truncated bool
}

fn styled_label_plan(config StyledLabelConfig) StyledLabelPlan {
	full := label_full_text(config.text, config.secondary)
	shown := if config.masked { label_masked_text(full) } else { full }
	runes := shown.runes()
	mut marks := []bool{len: runes.len}
	if !config.masked {
		for r in label_highlight_ranges(full, config.highlight, config.highlight_match) {
			for i in r.start .. r.end {
				marks[i] = true
			}
		}
	}
	base := styled_label_base(config)
	inset := basics_label_inset()
	width := if config.wrap { config.frame.width - 2 * inset } else { 0.0 }
	mut lines := basics_wrap_spans(runes, width, fn [base] (line string) f64 {
		return basics_text_width(line, base)
	})
	lh := styled_label_line_height(config)
	limit := if config.max_lines > 0 {
		config.max_lines
	} else if config.frame.height > 0 {
		math.max(1, int(math.floor((config.frame.height + 0.5) / lh)))
	} else {
		lines.len
	}
	mut truncated := false
	if lines.len > limit {
		lines = lines[..limit].clone()
		lines[limit - 1] = BasicsSpan{lines[limit - 1].start, runes.len}
		truncated = true
	}
	return StyledLabelPlan{
		runes:     runes
		main:      config.text.runes().len
		marks:     marks
		lines:     lines
		truncated: truncated
	}
}

// styled_label_size is how wide the widest line of a styled_label is and how
// tall its lines are together, wrapped at frame.width (or not, with wrap off).
// Lay the label out with it: a frame that wide and tall shows all of it.
pub fn styled_label_size(config StyledLabelConfig) (f64, f64) {
	plan := styled_label_plan(StyledLabelConfig{
		...config
		frame: rect(config.frame.x, config.frame.y, config.frame.width, 0)
	})
	base := styled_label_base(config)
	mut widest := 0.0
	for line in plan.lines {
		widest = math.max(widest, basics_text_width(plan.runes[line.start..line.end].string(),
			base))
	}
	return math.ceil(widest + 2 * basics_label_inset()), f64(plan.lines.len) * styled_label_line_height(config)
}

struct StyledLabelSegment {
	text      string
	style     TextStyle
	highlight bool
	width     f64
}

fn styled_label_segments(config StyledLabelConfig, plan StyledLabelPlan, line BasicsSpan, last bool) []StyledLabelSegment {
	base := styled_label_base(config)
	secondary := TextStyle{
		...base
		color: config.secondary_color or { config.theme.muted_foreground }
	}
	marked := TextStyle{
		...base
		color: config.highlight_color or { config.theme.primary }
	}
	mut segments := []StyledLabelSegment{}
	mut start := line.start
	for start < line.end {
		is_secondary := start >= plan.main
		is_marked := plan.marks[start]
		mut end := start + 1
		for end < line.end && (end >= plan.main) == is_secondary && plan.marks[end] == is_marked {
			end++
		}
		mut piece := plan.runes[start..end].string()
		if last && plan.truncated {
			piece = basics_flat(piece)
		}
		style := if is_marked {
			marked
		} else if is_secondary {
			secondary
		} else {
			base
		}
		segments << StyledLabelSegment{
			text:      piece
			style:     style
			highlight: is_marked
			width:     basics_text_width(piece, style)
		}
		start = end
	}
	return segments
}

// styled_label draws text with secondary text, highlights and masking, wrapped
// and aligned in its frame. Size the frame with styled_label_size; text that
// does not fit ends in an ellipsis on the last line the frame holds.
pub fn styled_label(config StyledLabelConfig) !Element {
	component_validate_frame(config.frame)!
	for value in [config.font_size, config.line_height] {
		if !component_finite(value) || value < 0 {
			return error('label font size and line height must be finite and non-negative')
		}
	}
	plan := styled_label_plan(config)
	lh := styled_label_line_height(config)
	inset := basics_label_inset()
	width := config.frame.width
	block := f64(plan.lines.len) * lh
	top := if config.frame.height <= block {
		0.0
	} else {
		match config.valign {
			.top { 0.0 }
			.middle { math.round((config.frame.height - block) / 2) }
			.bottom { config.frame.height - block }
		}
	}
	mark_fill := popover_blend(config.highlight_color or { config.theme.primary }, config.theme.background,
		0.82)
	mark_height := math.min(lh, math.round(font_line_height(styled_label_font(config)) + 2))
	mut marks := []Element{}
	mut texts := []Element{}
	for index, line in plan.lines {
		last := index == plan.lines.len - 1
		segments := styled_label_segments(config, plan, line, last)
		mut total := 0.0
		for segment in segments {
			total += segment.width
		}
		y := top + f64(index) * lh
		overflows := total > width - 2 * inset + 0.5
		mut x := if overflows {
			inset
		} else {
			match config.align {
				.left { inset }
				.center { (width - total) / 2 }
				.right { width - inset - total }
			}
		}
		for i, segment in segments {
			if config.highlight_background && segment.highlight && segment.width > 0 {
				marks << view('', rect(x - 1.5, y + (lh - mark_height) / 2, segment.width + 3,
					mark_height), BoxStyle{
					bg:     mark_fill
					radius: 3
				}, []Element{})
			}
			frame_x := x - inset
			frame_w := if overflows && i == segments.len - 1 {
				math.max(width - frame_x, 0)
			} else {
				segment.width + 2 * inset + 1
			}
			texts << label('', segment.text, rect(frame_x, y, frame_w, lh), segment.style)
			x += segment.width
		}
	}
	mut children := marks.clone()
	children << texts
	full := label_full_text(config.text, config.secondary)
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'text'
		accessibility_label: if config.masked { config.masked_label } else { full }
	})
}
