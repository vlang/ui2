module ui2

pub enum BoxOrientation {
	horizontal
	vertical
}

pub enum BoxAlignment {
	start
	center
	end
}

pub struct BoxPadding {
pub:
	left   f64
	top    f64
	right  f64
	bottom f64
}

// BoxLayoutChild combines an element with the sizing hints used by its parent.
// A negative size hint preserves the element's declared size on that axis.
pub struct BoxLayoutChild {
pub:
	element          Element
	size_hint_x      f64 = 1.0
	size_hint_y      f64 = 1.0
	minimum_width    f64 = -1.0
	minimum_height   f64 = -1.0
	maximum_width    f64 = -1.0
	maximum_height   f64 = -1.0
	horizontal_align BoxAlignment
	vertical_align   BoxAlignment
}

pub struct BoxLayoutConfig {
pub:
	id          string
	frame       Rect
	box         BoxStyle
	orientation BoxOrientation
	padding     BoxPadding
	spacing     f64
	children    []BoxLayoutChild
}

pub fn box_orientation(value string) !BoxOrientation {
	return match value {
		'', 'horizontal' { .horizontal }
		'vertical' { .vertical }
		else {
			return error('unknown box orientation `${value}`')
		}
	}
}

pub fn box_alignment(value string) !BoxAlignment {
	return match value {
		'', 'start', 'left', 'top' { .start }
		'center' { .center }
		'end', 'right', 'bottom' { .end }
		else {
			return error('unknown box alignment `${value}`')
		}
	}
}

fn box_bound(value f64, minimum f64, maximum f64) f64 {
	mut bounded := if value < 0 { 0.0 } else { value }
	if minimum >= 0 && bounded < minimum {
		bounded = minimum
	}
	if maximum >= 0 && bounded > maximum {
		bounded = maximum
	}
	return bounded
}

fn box_max(left f64, right f64) f64 {
	return if left > right { left } else { right }
}

fn box_validate(config BoxLayoutConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('box layout dimensions cannot be negative')
	}
	if config.spacing < 0 {
		return error('box layout spacing cannot be negative')
	}
	if config.padding.left < 0 || config.padding.top < 0 || config.padding.right < 0
		|| config.padding.bottom < 0 {
		return error('box layout padding cannot be negative')
	}
	for child in config.children {
		if child.element.frame.width < 0 || child.element.frame.height < 0 {
			return error('box child dimensions cannot be negative')
		}
		if child.minimum_width >= 0 && child.maximum_width >= 0
			&& child.minimum_width > child.maximum_width {
			return error('box child minimum width cannot exceed its maximum width')
		}
		if child.minimum_height >= 0 && child.maximum_height >= 0
			&& child.minimum_height > child.maximum_height {
			return error('box child minimum height cannot exceed its maximum height')
		}
	}
}

fn box_axis_sizes(available f64, declared []f64, hints []f64, minimums []f64, maximums []f64) ![]f64 {
	if available < 0 {
		return error('box layout padding and spacing exceed its available size')
	}
	mut sizes := []f64{len: declared.len}
	mut flexible := []bool{len: declared.len}
	mut remaining := available
	for index, declared_size in declared {
		if hints[index] < 0 {
			sizes[index] = box_bound(declared_size, minimums[index], maximums[index])
			remaining -= sizes[index]
		} else {
			flexible[index] = true
		}
	}

	// Lock hinted children that hit a bound, then redistribute what remains
	// between the other children in proportion to their hints.
	for {
		mut weight := f64(0)
		mut count := 0
		for index, pending in flexible {
			if pending {
				weight += hints[index]
				count++
			}
		}
		if count == 0 {
			break
		}
		mut locked := false
		for index, pending in flexible {
			if !pending {
				continue
			}
			candidate := if weight > 0 { remaining * hints[index] / weight } else { 0.0 }
			bounded := box_bound(candidate, minimums[index], maximums[index])
			if bounded != candidate {
				sizes[index] = bounded
				remaining -= bounded
				flexible[index] = false
				locked = true
			}
		}
		if locked {
			continue
		}
		for index, pending in flexible {
			if pending {
				sizes[index] = if weight > 0 { remaining * hints[index] / weight } else { 0.0 }
				flexible[index] = false
			}
		}
		break
	}
	return sizes
}

fn box_cross_position(start f64, available f64, size f64, alignment BoxAlignment) f64 {
	return match alignment {
		.start { start }
		.center { start + (available - size) / 2 }
		.end { start + available - size }
	}
}

// box_layout_frames returns child frames in declaration order. Non-negative
// hints share the remaining main-axis space; negative hints keep a fixed size.
pub fn box_layout_frames(config BoxLayoutConfig) ![]Rect {
	box_validate(config)!
	if config.frame.width < config.padding.left + config.padding.right
		|| config.frame.height < config.padding.top + config.padding.bottom {
		return error('box layout padding exceeds its available size')
	}
	if config.children.len == 0 {
		return []
	}
	spacing_total := config.spacing * f64(config.children.len - 1)
	mut declared := []f64{cap: config.children.len}
	mut hints := []f64{cap: config.children.len}
	mut minimums := []f64{cap: config.children.len}
	mut maximums := []f64{cap: config.children.len}
	for child in config.children {
		if config.orientation == .horizontal {
			declared << child.element.frame.width
			hints << child.size_hint_x
			minimums << child.minimum_width
			maximums << child.maximum_width
		} else {
			declared << child.element.frame.height
			hints << child.size_hint_y
			minimums << child.minimum_height
			maximums << child.maximum_height
		}
	}
	main_available := if config.orientation == .horizontal {
		config.frame.width - config.padding.left - config.padding.right - spacing_total
	} else {
		config.frame.height - config.padding.top - config.padding.bottom - spacing_total
	}
	main_sizes := box_axis_sizes(main_available, declared, hints, minimums, maximums)!
	mut cursor := if config.orientation == .horizontal {
		config.padding.left
	} else {
		config.padding.top
	}
	mut frames := []Rect{cap: config.children.len}
	for index, child in config.children {
		if config.orientation == .horizontal {
			cross_available := config.frame.height - config.padding.top - config.padding.bottom
			cross_size := box_bound(if child.size_hint_y < 0 {
				child.element.frame.height
			} else {
				cross_available * child.size_hint_y
			}, child.minimum_height, child.maximum_height)
			y := box_cross_position(config.padding.top, cross_available, cross_size, child.vertical_align)
			frames << rect(cursor, y, main_sizes[index], cross_size)
		} else {
			cross_available := config.frame.width - config.padding.left - config.padding.right
			cross_size := box_bound(if child.size_hint_x < 0 {
				child.element.frame.width
			} else {
				cross_available * child.size_hint_x
			}, child.minimum_width, child.maximum_width)
			x := box_cross_position(config.padding.left, cross_available, cross_size, child.horizontal_align)
			frames << rect(x, cursor, cross_size, main_sizes[index])
		}
		cursor += main_sizes[index] + config.spacing
	}
	return frames
}

// box_layout_minimum_size reports the fixed and bounded space required before
// proportional children receive any additional space.
pub fn box_layout_minimum_size(config BoxLayoutConfig) !Rect {
	box_validate(config)!
	spacing_total := if config.children.len > 0 {
		config.spacing * f64(config.children.len - 1)
	} else {
		0.0
	}
	mut main := spacing_total
	mut cross := f64(0)
	for child in config.children {
		if config.orientation == .horizontal {
			main += if child.size_hint_x < 0 {
				box_bound(child.element.frame.width, child.minimum_width, child.maximum_width)
			} else if child.minimum_width >= 0 {
				child.minimum_width
			} else {
				0
			}
			cross = box_max(cross, if child.size_hint_y < 0 {
				box_bound(child.element.frame.height, child.minimum_height, child.maximum_height)
			} else if child.minimum_height >= 0 {
				child.minimum_height
			} else {
				0
			})
		} else {
			main += if child.size_hint_y < 0 {
				box_bound(child.element.frame.height, child.minimum_height, child.maximum_height)
			} else if child.minimum_height >= 0 {
				child.minimum_height
			} else {
				0
			}
			cross = box_max(cross, if child.size_hint_x < 0 {
				box_bound(child.element.frame.width, child.minimum_width, child.maximum_width)
			} else if child.minimum_width >= 0 {
				child.minimum_width
			} else {
				0
			})
		}
	}
	return if config.orientation == .horizontal {
		rect(0, 0, config.padding.left + main + config.padding.right, config.padding.top + cross + config.padding.bottom)
	} else {
		rect(0, 0, config.padding.left + cross + config.padding.right, config.padding.top + main + config.padding.bottom)
	}
}

pub fn box_layout(config BoxLayoutConfig) !Element {
	frames := box_layout_frames(config)!
	mut children := []Element{cap: config.children.len}
	for index, child in config.children {
		children << Element{
			...child.element
			frame: frames[index]
		}
	}
	return view(config.id, config.frame, config.box, children)
}
