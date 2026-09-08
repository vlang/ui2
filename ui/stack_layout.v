module ui2

pub enum StackOrientation {
	left_to_right_top_to_bottom
	top_to_bottom_left_to_right
	right_to_left_top_to_bottom
	top_to_bottom_right_to_left
	left_to_right_bottom_to_top
	bottom_to_top_left_to_right
	right_to_left_bottom_to_top
	bottom_to_top_right_to_left
}

pub struct StackPadding {
pub:
	left   f64
	top    f64
	right  f64
	bottom f64
}

pub struct StackSpacing {
pub:
	horizontal f64
	vertical   f64
}

pub struct StackLayoutConfig {
pub:
	id          string
	frame       Rect
	box         BoxStyle
	orientation StackOrientation
	padding     StackPadding
	spacing     StackSpacing
	children    []Element
}

pub fn stack_orientation(value string) !StackOrientation {
	return match value {
		'', 'lr-tb' { .left_to_right_top_to_bottom }
		'tb-lr' { .top_to_bottom_left_to_right }
		'rl-tb' { .right_to_left_top_to_bottom }
		'tb-rl' { .top_to_bottom_right_to_left }
		'lr-bt' { .left_to_right_bottom_to_top }
		'bt-lr' { .bottom_to_top_left_to_right }
		'rl-bt' { .right_to_left_bottom_to_top }
		'bt-rl' { .bottom_to_top_right_to_left }
		else {
			return error('unknown stack orientation `${value}`')
		}
	}
}

fn stack_flows_horizontally(orientation StackOrientation) bool {
	return orientation in [.left_to_right_top_to_bottom, .right_to_left_top_to_bottom,
		.left_to_right_bottom_to_top, .right_to_left_bottom_to_top]
}

fn stack_reverses_x(orientation StackOrientation) bool {
	return orientation in [.right_to_left_top_to_bottom, .top_to_bottom_right_to_left,
		.right_to_left_bottom_to_top, .bottom_to_top_right_to_left]
}

fn stack_reverses_y(orientation StackOrientation) bool {
	return orientation in [.left_to_right_bottom_to_top, .bottom_to_top_left_to_right,
		.right_to_left_bottom_to_top, .bottom_to_top_right_to_left]
}

fn stack_validate(config StackLayoutConfig, sizes []Rect) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('stack layout dimensions cannot be negative')
	}
	for size in sizes {
		if size.width < 0 || size.height < 0 {
			return error('stack child dimensions cannot be negative')
		}
	}
}

fn stack_canonical_frames(config StackLayoutConfig, sizes []Rect) !([]Rect, Rect) {
	stack_validate(config, sizes)!
	mut frames := []Rect{cap: sizes.len}
	mut used_width := f64(0)
	mut used_height := f64(0)
	if stack_flows_horizontally(config.orientation) {
		limit := config.frame.width - config.padding.right
		mut x := config.padding.left
		mut y := config.padding.top
		mut row_height := f64(0)
		mut row_started := false
		for size in sizes {
			next_x := if row_started { x + config.spacing.horizontal } else { x }
			if row_started && next_x + size.width > limit {
				y += row_height + config.spacing.vertical
				x = config.padding.left
				row_height = 0
				row_started = false
			}
			if row_started {
				x += config.spacing.horizontal
			}
			frames << rect(x, y, size.width, size.height)
			x += size.width
			row_started = true
			if size.height > row_height {
				row_height = size.height
			}
			line_width := x - config.padding.left
			if line_width > used_width {
				used_width = line_width
			}
			used_height = y + row_height - config.padding.top
		}
	} else {
		limit := config.frame.height - config.padding.bottom
		mut x := config.padding.left
		mut y := config.padding.top
		mut column_width := f64(0)
		mut column_started := false
		for size in sizes {
			next_y := if column_started { y + config.spacing.vertical } else { y }
			if column_started && next_y + size.height > limit {
				x += column_width + config.spacing.horizontal
				y = config.padding.top
				column_width = 0
				column_started = false
			}
			if column_started {
				y += config.spacing.vertical
			}
			frames << rect(x, y, size.width, size.height)
			y += size.height
			column_started = true
			if size.width > column_width {
				column_width = size.width
			}
			used_width = x + column_width - config.padding.left
			line_height := y - config.padding.top
			if line_height > used_height {
				used_height = line_height
			}
		}
	}
	minimum := rect(0, 0, config.padding.left + used_width + config.padding.right, config.padding.top + used_height + config.padding.bottom)
	return frames, minimum
}

// stack_layout_frames packs variable-size children, wrapping when the next
// child would cross the layout's inner right or bottom edge.
pub fn stack_layout_frames(config StackLayoutConfig, sizes []Rect) ![]Rect {
	canonical, _ := stack_canonical_frames(config, sizes)!
	mut frames := []Rect{cap: canonical.len}
	for frame in canonical {
		x := if stack_reverses_x(config.orientation) {
			config.frame.width - config.padding.right - (frame.x - config.padding.left) - frame.width
		} else {
			frame.x
		}
		y := if stack_reverses_y(config.orientation) {
			config.frame.height - config.padding.bottom - (frame.y - config.padding.top) - frame.height
		} else {
			frame.y
		}
		frames << rect(x, y, frame.width, frame.height)
	}
	return frames
}

// stack_layout_minimum_size reports the occupied size for the wrapping that
// results from the configured frame. The width and height are returned in Rect.
pub fn stack_layout_minimum_size(config StackLayoutConfig, sizes []Rect) !Rect {
	_, minimum := stack_canonical_frames(config, sizes)!
	return minimum
}

pub fn stack_layout(config StackLayoutConfig) !Element {
	mut sizes := []Rect{cap: config.children.len}
	for child in config.children {
		sizes << rect(0, 0, child.frame.width, child.frame.height)
	}
	frames := stack_layout_frames(config, sizes)!
	mut children := []Element{cap: config.children.len}
	for index, child in config.children {
		children << Element{
			...child
			frame: frames[index]
		}
	}
	return view(config.id, config.frame, config.box, children)
}
