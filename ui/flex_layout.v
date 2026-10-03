module ui2

import math

pub enum FlexAlignment {
	auto
	start
	center
	end
	stretch
}

pub enum FlexJustify {
	start
	center
	end
	space_between
	space_around
	space_evenly
}

// FlexLayoutChild supplies preferred main-axis size and its allowed bounds.
// A basis of -1 uses the element's frame size. Grow shares extra space; shrink
// shares a deficit in proportion to shrink * basis. Explicit minima may overflow.
pub struct FlexLayoutChild {
pub:
	element        Element
	basis          f64 = -1
	grow           f64
	shrink         f64 = 1
	minimum_width  f64
	minimum_height f64
	maximum_width  f64           = -1
	maximum_height f64           = -1
	align_self     FlexAlignment = .auto
}

pub struct FlexLayoutConfig {
pub:
	id          string
	frame       Rect
	box         BoxStyle
	orientation BoxOrientation
	padding     BoxPadding
	gap         f64
	line_gap    f64 = -1
	wrap        bool
	justify     FlexJustify
	align       FlexAlignment = .stretch
	children    []FlexLayoutChild
}

pub fn flex_alignment(value string) !FlexAlignment {
	return match value {
		'', 'auto' { .auto }
		'start' { .start }
		'center' { .center }
		'end' { .end }
		'stretch' { .stretch }
		else { return error('unknown flex alignment `${value}`') }
	}
}

pub fn flex_justify(value string) !FlexJustify {
	return match value {
		'', 'start' { .start }
		'center' { .center }
		'end' { .end }
		'space_between' { .space_between }
		'space_around' { .space_around }
		'space_evenly' { .space_evenly }
		else { return error('unknown flex justification `${value}`') }
	}
}

fn flex_finite(value f64) bool {
	return !math.is_nan(value) && !math.is_inf(value, 0)
}

fn flex_validate(config FlexLayoutConfig) ! {
	if config.align == .auto {
		return error('flex layout alignment must be start, center, end, or stretch')
	}
	for value in [config.frame.x, config.frame.y, config.frame.width, config.frame.height,
		config.padding.left, config.padding.top, config.padding.right, config.padding.bottom,
		config.gap, config.line_gap] {
		if !flex_finite(value) {
			return error('flex layout dimensions and spacing must be finite')
		}
	}
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('flex layout dimensions cannot be negative')
	}
	if config.gap < 0 || (config.line_gap < 0 && config.line_gap != -1) {
		return error('flex layout gaps cannot be negative (line_gap accepts -1 for gap)')
	}
	if config.padding.left < 0 || config.padding.top < 0 || config.padding.right < 0
		|| config.padding.bottom < 0 {
		return error('flex layout padding cannot be negative')
	}
	mut total_width := config.padding.left + config.padding.right
	mut total_height := config.padding.top + config.padding.bottom
	for child in config.children {
		for value in [child.element.frame.x, child.element.frame.y, child.element.frame.width,
			child.element.frame.height, child.basis, child.grow, child.shrink, child.minimum_width,
			child.minimum_height, child.maximum_width, child.maximum_height] {
			if !flex_finite(value) {
				return error('flex child sizes, bounds, and weights must be finite')
			}
		}
		if child.element.frame.width < 0 || child.element.frame.height < 0
			|| (child.basis < 0 && child.basis != -1) {
			return error('flex child dimensions and basis cannot be negative (basis accepts -1)')
		}
		if child.grow < 0 || child.shrink < 0 {
			return error('flex child grow and shrink cannot be negative')
		}
		if child.minimum_width < 0 || child.minimum_height < 0
			|| (child.maximum_width < 0 && child.maximum_width != -1)
			|| (child.maximum_height < 0 && child.maximum_height != -1) {
			return error('flex child bounds cannot be negative (maximum accepts -1)')
		}
		if child.maximum_width >= 0 && child.minimum_width > child.maximum_width {
			return error('flex child minimum width cannot exceed its maximum width')
		}
		if child.maximum_height >= 0 && child.minimum_height > child.maximum_height {
			return error('flex child minimum height cannot exceed its maximum height')
		}
		// Reject arithmetic overflow as well as explicitly non-finite inputs.
		total_width += box_max(child.element.frame.width, box_max(child.minimum_width,
			box_max(child.maximum_width, child.basis))) + config.gap
		total_height += box_max(child.element.frame.height, box_max(child.minimum_height,
			box_max(child.maximum_height, child.basis))) + config.gap
	}
	if !flex_finite(total_width) || !flex_finite(total_height) {
		return error('flex layout total size exceeds the supported range')
	}
}

fn flex_main_bounds(child FlexLayoutChild, orientation BoxOrientation) (f64, f64) {
	return if orientation == .horizontal {
		child.minimum_width, child.maximum_width
	} else {
		child.minimum_height, child.maximum_height
	}
}

fn flex_basis(child FlexLayoutChild, orientation BoxOrientation) f64 {
	preferred := if child.basis >= 0 {
		child.basis
	} else if orientation == .horizontal {
		child.element.frame.width
	} else {
		child.element.frame.height
	}
	minimum, maximum := flex_main_bounds(child, orientation)
	return box_bound(preferred, minimum, maximum)
}

fn flex_cross_size(child FlexLayoutChild, orientation BoxOrientation, stretch f64) f64 {
	if orientation == .horizontal {
		return box_bound(if stretch >= 0 { stretch } else { child.element.frame.height },
			child.minimum_height, child.maximum_height)
	}
	return box_bound(if stretch >= 0 { stretch } else { child.element.frame.width },
		child.minimum_width, child.maximum_width)
}

struct FlexLine {
	start int
	end   int
	cross f64
}

fn flex_lines(config FlexLayoutConfig, available f64) []FlexLine {
	mut lines := []FlexLine{}
	mut start := 0
	mut used := f64(0)
	mut cross := f64(0)
	for index, child in config.children {
		basis := flex_basis(child, config.orientation)
		if config.wrap && index > start && used + config.gap + basis > available {
			lines << FlexLine{start, index, cross}
			start = index
			used = 0
			cross = 0
		}
		if index > start {
			used += config.gap
		}
		used += basis
		cross = box_max(cross, flex_cross_size(child, config.orientation, -1))
	}
	if start < config.children.len {
		lines << FlexLine{start, config.children.len, cross}
	}
	return lines
}

fn flex_line_sizes(config FlexLayoutConfig, line FlexLine, available f64) []f64 {
	count := line.end - line.start
	mut bases := []f64{cap: count}
	mut sizes := []f64{cap: count}
	for index in line.start .. line.end {
		basis := flex_basis(config.children[index], config.orientation)
		bases << basis
		sizes << basis
	}
	// Every redistribution either consumes all remaining space or locks at least
	// one item at a bound. One final pass is enough after all possible locks.
	for _ in 0 .. count + 1 {
		mut used := f64(0)
		for size in sizes {
			used += size
		}
		remaining := available - used
		if remaining == 0 {
			break
		}
		growing := remaining > 0
		mut max_weight := f64(0)
		mut max_basis := f64(0)
		mut active := []bool{len: count}
		for offset in 0 .. count {
			child := config.children[line.start + offset]
			minimum, maximum := flex_main_bounds(child, config.orientation)
			if (growing && child.grow > 0 && (maximum < 0 || sizes[offset] < maximum))
				|| (!growing && child.shrink > 0 && bases[offset] > 0 && sizes[offset] > minimum) {
				active[offset] = true
				max_weight = box_max(max_weight, if growing { child.grow } else { child.shrink })
				max_basis = box_max(max_basis, bases[offset])
			}
		}
		if max_weight == 0 {
			break
		}
		// Normalize before multiplying: valid large weights must not overflow.
		mut weights := []f64{len: count}
		mut total_weight := f64(0)
		for offset, pending in active {
			if pending {
				child := config.children[line.start + offset]
				weights[offset] = if growing {
					child.grow / max_weight
				} else {
					(child.shrink / max_weight) * (bases[offset] / max_basis)
				}
				total_weight += weights[offset]
			}
		}
		if total_weight == 0 {
			break
		}
		mut limited := false
		for offset, pending in active {
			if pending {
				minimum, maximum := flex_main_bounds(config.children[line.start + offset],
					config.orientation)
				candidate := sizes[offset] + remaining * (weights[offset] / total_weight)
				sizes[offset] = box_bound(candidate, minimum, maximum)
				limited = limited || sizes[offset] != candidate
			}
		}
		if !limited {
			break
		}
	}
	return sizes
}

fn flex_justify_space(justify FlexJustify, free_space f64, count int, gap f64) (f64, f64) {
	remaining := box_max(0, free_space)
	return match justify {
		.start { 0.0, gap }
		.center { remaining / 2, gap }
		.end { remaining, gap }
		.space_between { 0.0, if count > 1 { gap + remaining / f64(count - 1) } else { gap } }
		.space_around { remaining / f64(count * 2), gap + remaining / f64(count) }
		.space_evenly { remaining / f64(count + 1), gap + remaining / f64(count + 1) }
	}
}

// flex_layout_frames returns local child frames in declaration order. Wrapping
// uses bounded preferred bases before distributing each line's extra space.
// Wrapped lines keep their preferred cross size and are separated by line_gap.
// An unwrapped line occupies the available cross size. Small viewports clamp
// available size to zero, while explicit minima and non-shrinking items overflow.
pub fn flex_layout_frames(config FlexLayoutConfig) ![]Rect {
	flex_validate(config)!
	main_start := if config.orientation == .horizontal {
		config.padding.left
	} else {
		config.padding.top
	}
	cross_start := if config.orientation == .horizontal {
		config.padding.top
	} else {
		config.padding.left
	}
	main_available := box_max(0, if config.orientation == .horizontal {
		config.frame.width - config.padding.left - config.padding.right
	} else {
		config.frame.height - config.padding.top - config.padding.bottom
	})
	cross_available := box_max(0, if config.orientation == .horizontal {
		config.frame.height - config.padding.top - config.padding.bottom
	} else {
		config.frame.width - config.padding.left - config.padding.right
	})
	line_gap := if config.line_gap >= 0 { config.line_gap } else { config.gap }
	mut frames := []Rect{cap: config.children.len}
	mut cross_cursor := cross_start
	for line in flex_lines(config, main_available) {
		count := line.end - line.start
		gaps := config.gap * f64(count - 1)
		sizes := flex_line_sizes(config, line, box_max(0, main_available - gaps))
		mut used := gaps
		for size in sizes {
			used += size
		}
		offset, gap := flex_justify_space(config.justify, main_available - used, count, config.gap)
		mut cursor := main_start + offset
		line_cross := if config.wrap { line.cross } else { cross_available }
		for index in line.start .. line.end {
			child := config.children[index]
			align := if child.align_self == .auto { config.align } else { child.align_self }
			cross_size := flex_cross_size(child, config.orientation, if align == .stretch {
				line_cross
			} else {
				-1.0
			})
			cross_offset := match align {
				.center { (line_cross - cross_size) / 2 }
				.end { line_cross - cross_size }
				else { 0.0 }
			}
			main_size := sizes[index - line.start]
			frames << if config.orientation == .horizontal {
				rect(cursor, cross_cursor + cross_offset, main_size, cross_size)
			} else {
				rect(cross_cursor + cross_offset, cursor, cross_size, main_size)
			}
			cursor += main_size + gap
		}
		cross_cursor += line_cross + line_gap
	}
	return frames
}

// flex_layout_preferred_size reports the natural unwrapped size before growing
// or shrinking. The caller may measure text/content into element frames first.
pub fn flex_layout_preferred_size(config FlexLayoutConfig) !Rect {
	flex_validate(config)!
	mut main := if config.children.len > 0 {
		config.gap * f64(config.children.len - 1)
	} else {
		0.0
	}
	mut cross := f64(0)
	for child in config.children {
		main += flex_basis(child, config.orientation)
		cross = box_max(cross, flex_cross_size(child, config.orientation, -1))
	}
	return if config.orientation == .horizontal {
		rect(0, 0, main + config.padding.left + config.padding.right,
			cross + config.padding.top + config.padding.bottom)
	} else {
		rect(0, 0, cross + config.padding.left + config.padding.right,
			main + config.padding.top + config.padding.bottom)
	}
}

pub fn flex_layout(config FlexLayoutConfig) !Element {
	frames := flex_layout_frames(config)!
	mut children := []Element{cap: config.children.len}
	for index, child in config.children {
		children << Element{
			...child.element
			frame: frames[index]
		}
	}
	return view(config.id, config.frame, config.box, children)
}
