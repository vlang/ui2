module ui2

import math

// LayoutSize is a measured size in the same logical units as Element.frame.
pub struct LayoutSize {
pub:
	width  f64
	height f64
}

// LayoutConstraints describes the sizes a parent accepts. A maximum of -1 is
// unbounded; zero is an actual bound. Minimums win only after validation, so
// contradictory constraints produce an error instead of overflowing silently.
pub struct LayoutConstraints {
pub:
	min_width  f64
	min_height f64
	max_width  f64 = -1
	max_height f64 = -1
}

pub fn (constraints LayoutConstraints) validate() ! {
	for minimum in [constraints.min_width, constraints.min_height] {
		if !math.is_finite(minimum) || minimum < 0 {
			return error('layout minimums must be finite and nonnegative')
		}
	}
	for maximum in [constraints.max_width, constraints.max_height] {
		if !math.is_finite(maximum) || (maximum < 0 && maximum != -1) {
			return error('layout maximums must be nonnegative or -1 (unbounded)')
		}
	}
	if (constraints.max_width >= 0 && constraints.min_width > constraints.max_width)
		|| (constraints.max_height >= 0 && constraints.min_height > constraints.max_height) {
		return error('layout minimum cannot exceed its maximum')
	}
}

pub fn (constraints LayoutConstraints) constrain(size LayoutSize) !LayoutSize {
	constraints.validate()!
	if !math.is_finite(size.width) || !math.is_finite(size.height) {
		return error('measured layout size must be finite')
	}
	return LayoutSize{
		width:  layout_constrain_axis(size.width, constraints.min_width, constraints.max_width)
		height: layout_constrain_axis(size.height, constraints.min_height, constraints.max_height)
	}
}

pub fn (constraints LayoutConstraints) loosen() LayoutConstraints {
	return LayoutConstraints{ max_width: constraints.max_width, max_height: constraints.max_height }
}

// deflate gives content the space left inside a container's padding. Padding
// larger than a bounded axis leaves a tight zero, never a negative maximum.
pub fn (constraints LayoutConstraints) deflate(padding LayoutPadding) !LayoutConstraints {
	constraints.validate()!
	for inset in [padding.left, padding.top, padding.right, padding.bottom] {
		if !math.is_finite(inset) || inset < 0 {
			return error('layout padding must be finite and nonnegative')
		}
	}
	horizontal := padding.left + padding.right
	vertical := padding.top + padding.bottom
	return LayoutConstraints{
		min_width:  math.max(0, constraints.min_width - horizontal)
		min_height: math.max(0, constraints.min_height - vertical)
		max_width:  if constraints.max_width < 0 {
			-1
		} else {
			math.max(0, constraints.max_width - horizontal)
		}
		max_height: if constraints.max_height < 0 {
			-1
		} else {
			math.max(0, constraints.max_height - vertical)
		}
	}
}

fn layout_constrain_axis(value f64, minimum f64, maximum f64) f64 {
	bounded := math.max(minimum, value)
	return if maximum < 0 { bounded } else { math.min(maximum, bounded) }
}

// LayoutTextMeasureFn measures rendered text under a maximum logical width.
// -1 means unbounded. Supplying a callback makes layout independent of a window
// or GPU and lets an embedder use its own font engine without changing layout.
pub type LayoutTextMeasureFn = fn (string, TextStyle, f64) !LayoutSize

// measure_layout_element keeps positive declared dimensions and measures zero
// axes from text or children. Existing controls opt in by calling this API;
// constructing an Element retains its declared geometry. Containers with
// a layout algorithm measure/place their children before this extent fallback.
pub fn measure_layout_element(element Element, constraints LayoutConstraints, measure LayoutTextMeasureFn) !LayoutSize {
	constraints.validate()!
	if element.hidden {
		return constraints.constrain(LayoutSize{})
	}
	if element.frame.width > 0 && element.frame.height > 0 {
		return constraints.constrain(LayoutSize{ width: element.frame.width, height: element.frame.height })
	}
	mut preferred := LayoutSize{}
	if element.kind in [.label, .button, .toggle_button, .checkbox, .dropdown, .text_field, .text_area] {
		if voidptr(measure) == unsafe { nil } {
			return error('intrinsic text sizing requires a text measurer')
		}
		insets := layout_measure_control_insets(element)
		outer_width := if element.frame.width > 0 {
			layout_constrain_axis(element.frame.width, constraints.min_width, constraints.max_width)
		} else {
			constraints.max_width
		}
		text_width := if outer_width < 0 {
			-1.0
		} else {
			math.max(0, outer_width - insets.left - insets.right)
		}
		content := if element.text.len == 0 && element.kind in [.text_field, .text_area] {
			element.placeholder
		} else {
			element.text
		}
		measured := $if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
			// Editors wrap every row, unlike labels with a declared line limit.
			// Keep external callbacks' original TextStyle contract unchanged.
			if element.kind == .text_area && voidptr(measure) == voidptr(measure_layout_text) {
				layout_measure_custom_text_area(content, element.text_style, text_width)!
			} else {
				measure(content, element.text_style, text_width)!
			}
		} $else {
			measure(content, element.text_style, text_width)!
		}
		preferred = LayoutSize{
			width:  measured.width + insets.left + insets.right
			height: measured.height + insets.top + insets.bottom
		}
		if element.kind == .checkbox {
			preferred = LayoutSize{ ...preferred, height: math.max(18, preferred.height) }
		}
	} else {
		mut width := 0.0
		mut height := 0.0
		for child in element.children {
			if child.hidden { continue }
			child_size := measure_layout_element(child, LayoutConstraints{}, measure)!
			width = math.max(width, child.frame.x + child_size.width)
			height = math.max(height, child.frame.y + child_size.height)
		}
		preferred = LayoutSize{ width: width, height: height }
	}
	return constraints.constrain(LayoutSize{
		width:  if element.frame.width > 0 { element.frame.width } else { preferred.width }
		height: if element.frame.height > 0 { element.frame.height } else { preferred.height }
	})
}

// These content insets affect only opted-in intrinsic sizes. Existing explicit
// frames and backend drawing stay unchanged.
fn layout_measure_control_insets(element Element) LayoutPadding {
	$if macos && !ui2_custom_rendering ?&& !ui2_headless ? {
		if element.kind == .label {
			// Borderless NSTextField still reserves two points at each horizontal
			// edge. NSAttributedString measures glyphs only; include the cell's
			// existing margins so an intrinsic label does not truncate itself.
			return LayoutPadding{ left: 2, right: 2 }
		}
	}
	$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
		if element.kind == .text_area {
			// Include the gutter reserved by text_area_content_rect even when no
			// scrollbar is visible, so measurement and drawing wrap identically.
			return LayoutPadding{
				left:   math.max(2, element.padding_left)
				right:  if element.disable_scroll { 8 } else { 12 }
				top:    8
				bottom: 8
			}
		}
	}
	return match element.kind {
		.button, .toggle_button {
			LayoutPadding{ left: 12, right: if element.image_path.len > 0 { 36 } else { 12 }, top: 6, bottom: 6 }
		}
		.checkbox { LayoutPadding{ left: 26 } }
		.dropdown {
			LayoutPadding{ left: math.max(0, element.padding_left), right: 32, top: 6, bottom: 6 }
		}
		.text_field {
			LayoutPadding{ left: math.max(0, element.padding_left), right: 8, top: 6, bottom: 6 }
		}
		.text_area { LayoutPadding{ left: 8, right: 8, top: 8, bottom: 8 } }
		else { LayoutPadding{} }
	}
}

fn layout_validate_text_measurement(style TextStyle, max_width f64) ! {
	if !math.is_finite(style.size) || style.size <= 0 {
		return error('intrinsic text size must be finite and positive')
	}
	if !math.is_finite(max_width) || (max_width < 0 && max_width != -1) {
		return error('text measurement width must be nonnegative or -1')
	}
}

fn layout_measure_text_lines(text string, style TextStyle, max_width f64, line_height f64, width_of fn (string) f64) !LayoutSize {
	layout_validate_text_measurement(style, max_width)!
	if !math.is_finite(line_height) || line_height <= 0 {
		return error('text measurement needs a positive finite line height')
	}
	lines := if style.lines > 1 {
		wrap_text_lines_measured(text, max_width, style.lines, width_of)
	} else {
		[text]
	}
	mut width := 0.0
	for line in lines { width = math.max(width, width_of(line)) }
	return LayoutConstraints{ max_width: max_width }.constrain(LayoutSize{
		width:  width
		height: line_height * f64(lines.len)
	})
}

fn layout_measure_text_area_lines(text string, style TextStyle, max_width f64, line_height f64, width_of fn (string) f64) !LayoutSize {
	layout_validate_text_measurement(style, max_width)!
	if !math.is_finite(line_height) || line_height <= 0 {
		return error('text measurement needs a positive finite line height')
	}
	lines := if max_width < 0 {
		text.replace('\r\n', '\n').replace('\r', '\n').split('\n')
	} else {
		wrap_text_area_lines(text, max_width, width_of)
	}
	mut width := 0.0
	for line in lines { width = math.max(width, width_of(line)) }
	return LayoutConstraints{ max_width: max_width }.constrain(LayoutSize{
		width:  width
		height: line_height * f64(lines.len)
	})
}
