module ui2

import math

// textarea is GPUI Kit's Textarea on top of ui2's text_area element: a fixed
// number of rows or auto-grow between min_rows and max_rows, a placeholder, a
// character counter with a maximum length, sizes, a border, and disabled,
// read-only and invalid looks. The editing itself (wrapping, selection,
// clipboard, undo, scrolling) stays the backend's native text area.
//
// State is the application's, as for text_area: the text area's id is the
// config's id, its change events carry that id, and ui2.text(id) reads what
// was typed. Store it (through textarea_limit when there is a max_length) and
// rebuild: the height, the placeholder and the counter follow the text.

pub struct TextareaConfig {
pub:
	id          string // Required: the text area's own id, for ui2.text and its change events.
	frame       Rect   // Position and width; the box's height too when neither rows nor max_rows is set.
	text        string
	placeholder string
	rows        int // A fixed height of this many lines.
	// max_rows above zero makes the textarea grow with its text from min_rows to
	// max_rows lines; longer text scrolls inside it.
	min_rows   int = 1
	max_rows   int
	max_length int  // Above zero, the counter shows `count / max_length`, tinted once over it.
	show_count bool // Shows the counter without a max_length.
	enabled    bool = true
	readonly   bool // Selectable and copyable, but not editable, and drawn as usual.
	bordered   bool = true
	invalid    bool
	label      string // Accessibility label; defaults to the placeholder.
	size       ComponentSize = .medium
	theme      ComponentTheme
}

// textarea_limit cuts text to at most max_length characters (runes); a
// max_length of zero or less leaves it whole. Apply it to what ui2.text reads
// before storing it.
pub fn textarea_limit(text string, max_length int) string {
	if max_length <= 0 {
		return text
	}
	runes := text.runes()
	if runes.len <= max_length {
		return text
	}
	return runes[..max_length].string()
}

// textarea_count_text is the counter a textarea shows: `12 / 200`, or `12`
// without a maximum.
pub fn textarea_count_text(text string, max_length int) string {
	count := text.runes().len
	return if max_length > 0 { '${count} / ${max_length}' } else { count.str() }
}

// textarea_over_limit reports whether text is longer than max_length.
pub fn textarea_over_limit(text string, max_length int) bool {
	return max_length > 0 && text.runes().len > max_length
}

fn textarea_padding(size ComponentSize) (f64, f64) {
	return match size {
		.small { 8.0, 6.0 }
		.medium { 10.0, 8.0 }
		.large { 14.0, 10.0 }
	}
}

// textarea_painted reports whether the renderer paints a text area's box
// itself, whatever its BoxStyle says: the custom renderer fills it and outlines
// it in fixed colors, and pads the text eight points from the top. There the
// box is the text area, with the placeholder and the border drawn over it.
// Elsewhere the text area is clear and sits inset in a box drawn beneath it,
// with the placeholder showing through.
fn textarea_painted() bool {
	$if android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ui2_custom_rendering ? {
		return true
	} $else {
		return false
	}
}

// textarea_text_top is how far below the box's top edge the first line sits.
fn textarea_text_top(size ComponentSize) f64 {
	if textarea_painted() {
		return 8
	}
	_, pad_y := textarea_padding(size)
	return pad_y
}

fn textarea_style(config TextareaConfig) TextStyle {
	return TextStyle{
		color: if config.enabled { config.theme.foreground } else { config.theme.muted_foreground }
		size:  component_metrics(config.size).font_size
	}
}

// textarea_line_height is the height of one line of a textarea's text.
pub fn textarea_line_height(size ComponentSize) f64 {
	return math.ceil(font_line_height(component_metrics(size).font_size))
}

// textarea_wrap_width is how wide a line of text may be in a box `width`
// wide: what is left beside the padding, and the custom renderer's scroller
// gutter. The label inset measure_text_width counts is added back, since a
// text view has none.
fn textarea_wrap_width(width f64, size ComponentSize) f64 {
	pad_x, _ := textarea_padding(size)
	room := if textarea_painted() { width - pad_x - 12 } else { width - 2 * pad_x }
	return math.max(room, 1) + 2 * basics_label_inset()
}

// textarea_line_count is how many lines config.text wraps onto in its box.
pub fn textarea_line_count(config TextareaConfig) int {
	if config.text.len == 0 {
		return 1
	}
	return wrap_text_to_width(config.text, textarea_style(config), textarea_wrap_width(config.frame.width,
		config.size)).len
}

// textarea_rows is how many lines tall a textarea's box is: rows, the text's
// line count held between min_rows and max_rows, or what frame.height holds.
pub fn textarea_rows(config TextareaConfig) int {
	if config.max_rows > 0 {
		low := math.max(config.min_rows, 1)
		high := math.max(config.max_rows, low)
		return math.min(math.max(textarea_line_count(config), low), high)
	}
	if config.rows > 0 {
		return config.rows
	}
	lh := textarea_line_height(config.size)
	return math.max(1, int((config.frame.height - 2 * textarea_text_top(config.size)) / lh))
}

// textarea_box_height is the height of the bordered box the text is edited in.
pub fn textarea_box_height(config TextareaConfig) f64 {
	if config.max_rows <= 0 && config.rows <= 0 {
		return config.frame.height
	}
	return f64(textarea_rows(config)) * textarea_line_height(config.size) +
		2 * textarea_text_top(config.size)
}

fn textarea_has_counter(config TextareaConfig) bool {
	return config.max_length > 0 || config.show_count
}

const textarea_counter_height = 16.0
const textarea_counter_gap = 4.0

// textarea_height is how tall a textarea is, its counter included.
pub fn textarea_height(config TextareaConfig) f64 {
	box := textarea_box_height(config)
	return if textarea_has_counter(config) {
		box + textarea_counter_gap + textarea_counter_height
	} else {
		box
	}
}

// textarea_editor_frame is where the native text area sits in the box. A
// text view draws its text five points in from its sides and right at its top,
// so it is inset by the padding; a painted one is the box.
fn textarea_editor_frame(width f64, height f64, size ComponentSize) Rect {
	if textarea_painted() {
		return rect(0, 0, width, height)
	}
	pad_x, _ := textarea_padding(size)
	top := textarea_text_top(size)
	return rect(pad_x - 5, top, math.max(width - 2 * (pad_x - 5), 0), math.max(height - 2 * top,
		0))
}

// textarea draws a multi-line text field in a bordered box whose height follows
// rows or the text (auto-grow), with a placeholder while it is empty and a
// counter below it. Its frame's height is textarea_height(config).
pub fn textarea(config TextareaConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if config.rows < 0 || config.min_rows < 0 || config.max_rows < 0 || config.max_length < 0 {
		return error('textarea rows and max_length must be non-negative')
	}
	metrics := component_metrics(config.size)
	width := config.frame.width
	box_h := textarea_box_height(config)
	pad_x, _ := textarea_padding(config.size)
	top := textarea_text_top(config.size)
	lh := textarea_line_height(config.size)
	style := textarea_style(config)
	over := textarea_over_limit(config.text, config.max_length)
	border := if config.invalid || over {
		config.theme.danger
	} else {
		config.theme.border
	}
	fill := if config.enabled { config.theme.background } else { config.theme.muted }
	edge := if config.bordered { border } else { fill }
	painted := textarea_painted()
	mut placeholder := []Element{}
	if config.text.len == 0 && config.placeholder.len > 0 {
		placeholder << label('', config.placeholder, rect(pad_x, top, math.max(width - 2 * pad_x,
			0), math.max(box_h - 2 * top, lh)), TextStyle{
			color:  config.theme.muted_foreground
			size:   style.size
			valign: .top
			lines:  0
		})
	}
	editor := Element{
		...text_area(config.id, config.text, textarea_editor_frame(width, box_h, config.size),
			if painted {
				BoxStyle{
					bg:     fill
					radius: metrics.radius
				}
			} else {
				BoxStyle{
					transparent: true
				}
			}, style)
		padding_left:        pad_x
		readonly:            config.readonly
		enabled:             config.enabled
		accessibility_label: if config.label.len > 0 { config.label } else { config.placeholder }
	}
	mut box_style := BoxStyle{
		transparent: true
	}
	mut box_children := []Element{}
	if painted {
		// The renderer outlines the text area in its own gray; the border is
		// stroked over that outline, in the fill's color when there is none.
		box_children << editor
		box_children << placeholder
		box_children << shape(component_part_id(config.id, 'border'), rect(0, 0, width, box_h),
			path_rounded_rect(rect(0.5, 0.5, math.max(width - 1, 0), math.max(box_h - 1, 0)),
				math.max(metrics.radius - 0.5, 0)), ShapeStyle{
				stroke:       edge
				stroke_width: 1
			})
	} else {
		box_style, box_children = popover_panel(rect(0, 0, width, box_h), fill, edge,
			metrics.radius, false)
		box_children << placeholder
		box_children << editor
	}
	mut children := [
		view(component_part_id(config.id, 'box'), rect(0, 0, width, box_h), box_style,
			box_children),
	]
	if textarea_has_counter(config) {
		children << label('', textarea_count_text(config.text, config.max_length), rect(0,
			box_h + textarea_counter_gap, width, textarea_counter_height), TextStyle{
			color: if over { config.theme.danger } else { config.theme.muted_foreground }
			size:  math.max(metrics.font_size - 2, 11)
			align: .right
		})
	}
	total := textarea_height(config)
	return component_finish(view(component_part_id(config.id, 'textarea'), rect(config.frame.x,
		config.frame.y, width, total), BoxStyle{ transparent: true }, children))
}
