module ui2

pub enum FloatHintAnchor {
	declared
	start
	center
	end
}

pub struct FloatAxisHint {
pub:
	anchor FloatHintAnchor
	value  f64
}

pub struct FloatLayoutChild {
pub:
	element        Element
	size_hint_x    f64 = 1.0
	size_hint_y    f64 = 1.0
	minimum_width  f64 = -1.0
	minimum_height f64 = -1.0
	maximum_width  f64 = -1.0
	maximum_height f64 = -1.0
	x_hint         FloatAxisHint
	y_hint         FloatAxisHint
}

pub struct FloatLayoutConfig {
pub:
	id       string
	frame    Rect
	box      BoxStyle
	children []FloatLayoutChild
}

fn float_validate(config FloatLayoutConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('float layout dimensions cannot be negative')
	}
	for child in config.children {
		if child.element.frame.width < 0 || child.element.frame.height < 0 {
			return error('float child dimensions cannot be negative')
		}
		if child.minimum_width >= 0 && child.maximum_width >= 0
			&& child.minimum_width > child.maximum_width {
			return error('float child minimum width cannot exceed its maximum width')
		}
		if child.minimum_height >= 0 && child.maximum_height >= 0
			&& child.minimum_height > child.maximum_height {
			return error('float child minimum height cannot exceed its maximum height')
		}
	}
}

fn float_axis_position(declared f64, available f64, size f64, hint FloatAxisHint) f64 {
	return match hint.anchor {
		.declared { declared }
		.start { hint.value * available }
		.center { hint.value * available - size / 2 }
		.end { hint.value * available - size }
	}
}

// float_layout_frames independently sizes and positions every child. Negative
// size hints retain the declared dimension; non-negative hints multiply the
// corresponding layout dimension.
pub fn float_layout_frames(config FloatLayoutConfig) ![]Rect {
	float_validate(config)!
	mut frames := []Rect{cap: config.children.len}
	for child in config.children {
		width := box_bound(if child.size_hint_x < 0 {
			child.element.frame.width
		} else {
			config.frame.width * child.size_hint_x
		}, child.minimum_width, child.maximum_width)
		height := box_bound(if child.size_hint_y < 0 {
			child.element.frame.height
		} else {
			config.frame.height * child.size_hint_y
		}, child.minimum_height, child.maximum_height)
		x := float_axis_position(child.element.frame.x, config.frame.width, width, child.x_hint)
		y := float_axis_position(child.element.frame.y, config.frame.height, height, child.y_hint)
		frames << rect(x, y, width, height)
	}
	return frames
}

pub fn float_layout(config FloatLayoutConfig) !Element {
	frames := float_layout_frames(config)!
	mut children := []Element{cap: config.children.len}
	for index, child in config.children {
		children << Element{
			...child.element
			frame: frames[index]
		}
	}
	return view(config.id, config.frame, config.box, children)
}
