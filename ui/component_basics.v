module ui2

import math

// Shared machinery for the basics components: image_box, styled_label,
// textarea, tooltip_popup, scrollable and scrollbar. They layer GPUI Kit's Image,
// Label, Textarea, Tooltip and Scrollable on top of ui2's own image, label,
// text_area, with_tooltip and scroll elements, which stay as they are.

// basics_label_inset is how far in from its frame a label's text starts on
// each side. AppKit text fields keep two points, which measure_text_width
// counts on both sides; the other renderers draw from the frame's edge. An
// estimate (no window yet, or a test) has no inset either.
fn basics_label_inset() f64 {
	if !text_measurement_exact() {
		return 0
	}
	$if macos && !ui2_custom_rendering ? {
		return 2
	} $else {
		return 0
	}
}

// basics_text_width is how wide text draws in style: measure_text_width
// without the inset a label puts around it, so runs of differently styled text
// can be set one after another.
fn basics_text_width(text string, style TextStyle) f64 {
	if text.len == 0 {
		return 0
	}
	return math.max(0, measure_text_width(text, style) - 2 * basics_label_inset())
}

// BasicsSpan is a stretch of runes, end exclusive.
struct BasicsSpan {
	start int
	end   int
}

// basics_wrap_spans breaks runes into the lines a label `width` wide shows
// them on, as wrap_text_to_width does: at newlines, and at the space before a
// word that would not fit, which the break swallows. A word wider than the line
// stays whole on its own line. Unlike wrap_text_to_width it reports where each
// line lies in the text, so styled runs can be cut along the same lines.
fn basics_wrap_spans(runes []rune, width f64, measure fn (string) f64) []BasicsSpan {
	mut spans := []BasicsSpan{}
	mut para_start := 0
	for para_start <= runes.len {
		mut para_end := para_start
		for para_end < runes.len && runes[para_end] != `\n` {
			para_end++
		}
		mut line_start := para_start
		mut line_end := para_start
		mut first := true
		mut i := para_start
		for {
			mut j := i
			for j < para_end && runes[j] != ` ` {
				j++
			}
			if first || width <= 0 || measure(runes[line_start..j].string()) <= width {
				line_end = j
				first = false
			} else {
				spans << BasicsSpan{line_start, line_end}
				line_start = line_end + 1
				line_end = j
			}
			if j >= para_end {
				break
			}
			i = j + 1
		}
		spans << BasicsSpan{line_start, line_end}
		para_start = para_end + 1
	}
	return spans
}

// basics_flat replaces the line breaks in text with spaces, for the last line
// a label has room for, which carries the rest of the text and ends in the
// ellipsis the renderer draws.
fn basics_flat(text string) string {
	return text.replace('\r\n', ' ').replace('\n', ' ')
}

// basics_clamp holds value inside low...high, preferring low when the range is
// empty.
fn basics_clamp(value f64, low f64, high f64) f64 {
	if high < low {
		return low
	}
	return math.min(math.max(value, low), high)
}

// basics_symbol is an icon image tinted with color.
fn basics_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}
