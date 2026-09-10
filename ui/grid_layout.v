module ui2

pub enum GridOrientation {
	left_to_right_top_to_bottom
	top_to_bottom_left_to_right
	right_to_left_top_to_bottom
	top_to_bottom_right_to_left
	left_to_right_bottom_to_top
	bottom_to_top_left_to_right
	right_to_left_bottom_to_top
	bottom_to_top_right_to_left
}

pub struct GridPadding {
pub:
	left   f64
	top    f64
	right  f64
	bottom f64
}

pub struct GridSpacing {
pub:
	horizontal f64
	vertical   f64
}

pub struct GridLayoutConfig {
pub:
	id                   string
	frame                Rect
	box                  BoxStyle
	columns              int
	rows                 int
	orientation          GridOrientation
	padding              GridPadding
	spacing              GridSpacing
	column_default_width f64
	row_default_height   f64
	force_column_width   bool
	force_row_height     bool
	columns_minimum      map[int]f64
	rows_minimum         map[int]f64
	children             []Element
}

// grid_orientation converts the compact VML orientation names to the typed V
// API. The two letter pairs describe horizontal and vertical traversal.
pub fn grid_orientation(value string) !GridOrientation {
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
			return error('unknown grid orientation `${value}`')
		}
	}
}

fn grid_dimensions(columns int, rows int, child_count int) !(int, int) {
	if columns < 0 || rows < 0 {
		return error('grid rows and columns cannot be negative')
	}
	if columns == 0 && rows == 0 {
		return error('grid layout requires columns or rows')
	}
	if columns > 0 && rows > 0 {
		if child_count > columns * rows {
			return error('grid layout has ${child_count} children but only ${columns * rows} cells')
		}
		return columns, rows
	}
	if columns > 0 {
		computed_rows := if child_count == 0 { 0 } else { (child_count + columns - 1) / columns }
		return columns, computed_rows
	}
	computed_columns := if child_count == 0 { 0 } else { (child_count + rows - 1) / rows }
	return computed_columns, rows
}

fn grid_axis_sizes(available f64, count int, default_size f64, force_default bool, minimum map[int]f64) ![]f64 {
	if count == 0 {
		return []
	}
	if available < 0 || default_size < 0 {
		return error('grid dimensions cannot be negative')
	}
	mut sizes := []f64{len: count, init: default_size}
	for index, value in minimum {
		if index < 0 || index >= count {
			return error('grid minimum index ${index} is outside 0..${count - 1}')
		}
		if value < 0 {
			return error('grid minimum sizes cannot be negative')
		}
		sizes[index] = value
	}
	if force_default {
		return sizes
	}
	mut used := f64(0)
	for size in sizes {
		used += size
	}
	if used < available {
		extra := (available - used) / f64(count)
		for index in 0 .. count {
			sizes[index] += extra
		}
	}
	return sizes
}

fn grid_cell_coordinates(index int, columns int, rows int, orientation GridOrientation) (int, int) {
	return match orientation {
		.left_to_right_top_to_bottom { index % columns, index / columns }
		.top_to_bottom_left_to_right { index / rows, index % rows }
		.right_to_left_top_to_bottom { columns - 1 - index % columns, index / columns }
		.top_to_bottom_right_to_left { columns - 1 - index / rows, index % rows }
		.left_to_right_bottom_to_top { index % columns, rows - 1 - index / columns }
		.bottom_to_top_left_to_right { index / rows, rows - 1 - index % rows }
		.right_to_left_bottom_to_top {
			columns - 1 - index % columns, rows - 1 - index / columns
		}
		.bottom_to_top_right_to_left {
			columns - 1 - index / rows, rows - 1 - index % rows
		}
	}
}

// grid_layout_frames returns child frames in declaration order. Unless an axis
// is forced to its defaults, remaining space is distributed equally after its
// configured minimums have been reserved.
pub fn grid_layout_frames(config GridLayoutConfig, child_count int) ![]Rect {
	if child_count < 0 {
		return error('grid child count cannot be negative')
	}
	columns, rows := grid_dimensions(config.columns, config.rows, child_count)!
	if child_count == 0 {
		return []
	}
	inner_width := config.frame.width - config.padding.left - config.padding.right - config.spacing.horizontal * f64(columns - 1)
	inner_height := config.frame.height - config.padding.top - config.padding.bottom - config.spacing.vertical * f64(rows - 1)
	widths := grid_axis_sizes(inner_width, columns, config.column_default_width, config.force_column_width, config.columns_minimum)!
	heights := grid_axis_sizes(inner_height, rows, config.row_default_height, config.force_row_height, config.rows_minimum)!
	mut x_positions := []f64{len: columns}
	mut y_positions := []f64{len: rows}
	mut x := config.padding.left
	for column, width in widths {
		x_positions[column] = x
		x += width + config.spacing.horizontal
	}
	mut y := config.padding.top
	for row, height in heights {
		y_positions[row] = y
		y += height + config.spacing.vertical
	}
	mut frames := []Rect{cap: child_count}
	for index in 0 .. child_count {
		column, row := grid_cell_coordinates(index, columns, rows, config.orientation)
		frames << rect(x_positions[column], y_positions[row], widths[column], heights[row])
	}
	return frames
}

// grid_layout creates a view whose children are assigned to cells in their
// declaration order. Child frames are replaced by the computed cell frames.
pub fn grid_layout(config GridLayoutConfig) !Element {
	frames := grid_layout_frames(config, config.children.len)!
	mut children := []Element{cap: config.children.len}
	for index, child in config.children {
		children << Element{
			...child
			frame: frames[index]
		}
	}
	return view(config.id, config.frame, config.box, children)
}
