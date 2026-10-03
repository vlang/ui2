module ui2

import math

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

// GridSpan reserves adjacent cells for one child. Spans follow the configured
// fill direction. In an automatic grid, column spans shrink with the viewport.
pub struct GridSpan {
pub:
	column_span int = 1
	row_span    int = 1
}

pub struct GridLayoutConfig {
pub:
	id      string
	frame   Rect
	box     BoxStyle
	columns int
	rows    int
	// Automatic columns are used only when neither columns nor rows is set.
	auto_columns_min_width f64
	max_columns            int
	// Entries correspond to children; missing trailing entries mean 1 x 1.
	child_spans          []GridSpan
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

struct GridPlacement {
	column      int
	row         int
	column_span int = 1
	row_span    int = 1
}

fn grid_validate_config(config GridLayoutConfig, child_count int) ! {
	if child_count < 0 {
		return error('grid child count cannot be negative')
	}
	if config.columns < 0 || config.rows < 0 || config.max_columns < 0 {
		return error('grid rows, columns and max_columns cannot be negative')
	}
	for value in [config.frame.width, config.frame.height, config.padding.left, config.padding.top,
		config.padding.right, config.padding.bottom, config.spacing.horizontal,
		config.spacing.vertical, config.column_default_width, config.row_default_height,
		config.auto_columns_min_width] {
		if math.is_nan(value) || math.is_inf(value, 0) || value < 0 {
			return error('grid dimensions, spacing and padding must be finite and non-negative')
		}
	}
	for minimum in [config.columns_minimum, config.rows_minimum] {
		for index, value in minimum {
			if index < 0 {
				return error('grid minimum indices cannot be negative')
			}
			if math.is_nan(value) || math.is_inf(value, 0) || value < 0 {
				return error('grid minimum sizes must be finite and non-negative')
			}
		}
	}
	if config.child_spans.len > child_count {
		return error('grid has more child spans than children')
	}
	for span in config.child_spans {
		if span.column_span < 1 || span.row_span < 1 {
			return error('grid child spans must be positive')
		}
	}
}

fn grid_automatic_columns(config GridLayoutConfig, child_count int) int {
	inner := math.max(0.0, config.frame.width - config.padding.left - config.padding.right)
	fit := if inner < config.auto_columns_min_width {
		f64(1)
	} else {
		1 + math.floor((inner - config.auto_columns_min_width) / (config.auto_columns_min_width + config.spacing.horizontal))
	}
	mut columns := int(math.min(f64(math.max(1, child_count)), fit))
	if config.max_columns > 0 {
		columns = math.min(columns, config.max_columns)
	}
	return columns
}

fn grid_column_major(orientation GridOrientation) bool {
	return orientation in [.top_to_bottom_left_to_right, .top_to_bottom_right_to_left,
		.bottom_to_top_left_to_right, .bottom_to_top_right_to_left]
}

fn grid_reverse_columns(orientation GridOrientation) bool {
	return orientation in [.right_to_left_top_to_bottom, .top_to_bottom_right_to_left,
		.right_to_left_bottom_to_top, .bottom_to_top_right_to_left]
}

fn grid_reverse_rows(orientation GridOrientation) bool {
	return orientation in [.left_to_right_bottom_to_top, .bottom_to_top_left_to_right,
		.right_to_left_bottom_to_top, .bottom_to_top_right_to_left]
}

fn grid_pack_spans(spans []GridSpan, columns int, rows int, orientation GridOrientation) ?[]GridPlacement {
	mut occupied := []bool{len: columns * rows}
	mut cells := []GridPlacement{cap: spans.len}
	for span in spans {
		mut found := false
		for index in 0 .. occupied.len {
			column := if grid_column_major(orientation) { index / rows } else { index % columns }
			row := if grid_column_major(orientation) { index % rows } else { index / columns }
			if column + span.column_span > columns || row + span.row_span > rows {
				continue
			}
			mut available := true
			for y in row .. row + span.row_span {
				for x in column .. column + span.column_span {
					if occupied[y * columns + x] {
						available = false
					}
				}
			}
			if !available {
				continue
			}
			for y in row .. row + span.row_span {
				for x in column .. column + span.column_span {
					occupied[y * columns + x] = true
				}
			}
			cells << GridPlacement{
				column:      if grid_reverse_columns(orientation) {
					columns - column - span.column_span
				} else {
					column
				}
				row:         if grid_reverse_rows(orientation) {
					rows - row - span.row_span
				} else {
					row
				}
				column_span: span.column_span
				row_span:    span.row_span
			}
			found = true
			break
		}
		if !found {
			return none
		}
	}
	return cells
}

fn grid_spanned_dimensions(config GridLayoutConfig, child_count int, automatic bool) !(int, int, []GridPlacement) {
	mut columns := if automatic {
		grid_automatic_columns(config, child_count)
	} else {
		config.columns
	}
	mut rows := config.rows
	if columns == 0 && rows == 0 {
		return error('grid layout requires columns or rows')
	}
	mut spans := []GridSpan{len: child_count}
	mut area := i64(0)
	mut max_column_span := 1
	mut max_row_span := 1
	for index in 0 .. child_count {
		span := if index < config.child_spans.len { config.child_spans[index] } else { GridSpan{} }
		spans[index] = GridSpan{
			column_span: if automatic {
				math.min(span.column_span, columns)
			} else {
				span.column_span
			}
			row_span:    span.row_span
		}
		max_column_span = math.max(max_column_span, spans[index].column_span)
		max_row_span = math.max(max_row_span, spans[index].row_span)
		area += i64(spans[index].column_span) * i64(spans[index].row_span)
		if area > 2_147_483_647 {
			return error('grid child spans are too large')
		}
	}
	if columns > 0 && max_column_span > columns {
		return error('grid child column span exceeds its ${columns} columns')
	}
	if rows > 0 && max_row_span > rows {
		return error('grid child row span exceeds its ${rows} rows')
	}
	if columns > 0 && rows > 0 {
		if i64(columns) * i64(rows) > 2_147_483_647 {
			return error('grid span capacity is too large')
		}
		cells := grid_pack_spans(spans, columns, rows, config.orientation) or {
			return error('grid child spans do not fit within ${columns} columns and ${rows} rows')
		}
		return columns, rows, cells
	}
	grow_rows := rows == 0
	if grow_rows {
		rows = math.max(max_row_span, int((area + columns - 1) / columns))
	} else {
		columns = math.max(max_column_span, int((area + rows - 1) / rows))
	}
	for {
		if i64(columns) * i64(rows) > 2_147_483_647 {
			return error('grid span capacity is too large')
		}
		if cells := grid_pack_spans(spans, columns, rows, config.orientation) {
			return columns, rows, cells
		}
		if grow_rows {
			rows++
		} else {
			columns++
		}
	}
	return error('unable to place grid child spans')
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
		capacity := i64(columns) * i64(rows)
		if i64(child_count) > capacity {
			return error('grid layout has ${child_count} children but only ${capacity} cells')
		}
		return columns, rows
	}
	if columns > 0 {
		computed_rows := if child_count == 0 {
			0
		} else {
			int((i64(child_count) + columns - 1) / columns)
		}
		return columns, computed_rows
	}
	computed_columns := if child_count == 0 { 0 } else { int((i64(child_count) + rows - 1) / rows) }
	return computed_columns, rows
}

fn grid_track_defaults(count int, default_size f64, minimum map[int]f64, automatic bool) ![]f64 {
	if count == 0 {
		return []
	}
	mut sizes := []f64{len: count, init: default_size}
	for index, value in minimum {
		if automatic && index >= count {
			continue
		}
		if index < 0 || index >= count {
			return error('grid minimum index ${index} is outside 0..${count - 1}')
		}
		if value < 0 {
			return error('grid minimum sizes cannot be negative')
		}
		sizes[index] = value
	}
	return sizes
}

fn grid_axis_sizes(available f64, count int, default_size f64, force_default bool, minimum map[int]f64, automatic bool) ![]f64 {
	if available < 0 || math.is_inf(available, 0) || math.is_nan(available) || default_size < 0 {
		return error('grid dimensions must be finite and non-negative')
	}
	mut sizes := grid_track_defaults(count, default_size, minimum, automatic)!
	if count == 0 { return sizes }
	mut used := f64(0)
	for size in sizes {
		used += size
	}
	if math.is_inf(used, 0) {
		return error('grid track sizes exceed the finite layout range')
	}
	if automatic && used > available {
		for index in 0 .. count {
			sizes[index] *= available / used
		}
	} else if !force_default && used < available {
		extra := (available - used) / f64(count)
		for index in 0 .. count {
			sizes[index] += extra
		}
	}
	return sizes
}

fn grid_resolved_cells(config GridLayoutConfig, child_count int, automatic bool) !(int, int, []GridPlacement) {
	if config.child_spans.any(it.column_span > 1 || it.row_span > 1) && child_count > 0 {
		return grid_spanned_dimensions(config, child_count, automatic)
	}
	configured_columns := if automatic {
		grid_automatic_columns(config, child_count)
	} else {
		config.columns
	}
	columns, rows := grid_dimensions(configured_columns, config.rows, child_count)!
	mut cells := []GridPlacement{cap: child_count}
	for index in 0 .. child_count {
		column, row := grid_cell_coordinates(index, columns, rows, config.orientation)
		cells << GridPlacement{ column: column, row: row }
	}
	return columns, rows, cells
}

fn grid_fit_padding(available f64, leading f64, trailing f64, automatic bool) (f64, f64) {
	if automatic && leading + trailing > available {
		// Division before multiplication avoids overflowing the padding sum.
		ratio := if leading > trailing {
			1 / (1 + trailing / leading)
		} else {
			(leading / trailing) / (1 + leading / trailing)
		}
		return available * ratio, available * (1 - ratio)
	}
	return leading, trailing
}

fn grid_fit_spacing(available f64, count int, spacing f64, automatic bool) f64 {
	if automatic && count > 1 {
		return math.min(spacing, math.max(0.0, available) / f64(count - 1))
	}
	return spacing
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
	grid_validate_config(config, child_count)!
	automatic := config.columns == 0 && config.rows == 0 && config.auto_columns_min_width > 0
	columns, rows, cells := grid_resolved_cells(config, child_count, automatic)!
	if child_count == 0 {
		return []
	}
	left, right := grid_fit_padding(config.frame.width, config.padding.left, config.padding.right, automatic)
	top, bottom := grid_fit_padding(config.frame.height, config.padding.top, config.padding.bottom, automatic)
	horizontal_spacing := grid_fit_spacing(config.frame.width - left - right, columns, config.spacing.horizontal, automatic)
	vertical_spacing := grid_fit_spacing(config.frame.height - top - bottom, rows, config.spacing.vertical, automatic)
	computed_width := config.frame.width - left - right - horizontal_spacing * f64(columns - 1)
	computed_height := config.frame.height - top - bottom - vertical_spacing * f64(rows - 1)
	inner_width := if automatic { math.max(0.0, computed_width) } else { computed_width }
	inner_height := if automatic { math.max(0.0, computed_height) } else { computed_height }
	widths := grid_axis_sizes(inner_width, columns, config.column_default_width, config.force_column_width, config.columns_minimum, automatic)!
	heights := grid_axis_sizes(inner_height, rows, config.row_default_height, config.force_row_height, config.rows_minimum, automatic)!
	mut x_positions := []f64{len: columns}
	mut y_positions := []f64{len: rows}
	mut x := left
	for column, width in widths {
		x_positions[column] = x
		x += width + horizontal_spacing
	}
	mut y := top
	for row, height in heights {
		y_positions[row] = y
		y += height + vertical_spacing
	}
	mut frames := []Rect{cap: child_count}
	for cell in cells {
		last_column := cell.column + cell.column_span - 1
		last_row := cell.row + cell.row_span - 1
		frames << rect(x_positions[cell.column], y_positions[cell.row],
			if cell.column_span == 1 {
				widths[cell.column]
			} else {
				x_positions[last_column] + widths[last_column] - x_positions[cell.column]
			},
			if cell.row_span == 1 {
				heights[cell.row]
			} else {
				y_positions[last_row] + heights[last_row] - y_positions[cell.row]
			})
	}
	return frames
}

// grid_layout_preferred_size measures the natural grid size, including padding
// and gaps. Automatic columns are resolved from config.frame.width; child sizes
// should therefore have been measured at the corresponding available width.
// Measurement reserves enough equally distributed extra space that every child
// fits its tracks, matching grid_layout_frames. Forced defaults ignore child
// measurements on their axis. This does not mutate
// or construct Elements and can be used by a containing layout during measurement.
pub fn grid_layout_preferred_size(config GridLayoutConfig, child_sizes []Rect) !Rect {
	grid_validate_config(config, child_sizes.len)!
	automatic := config.columns == 0 && config.rows == 0 && config.auto_columns_min_width > 0
	columns, rows, cells := grid_resolved_cells(config, child_sizes.len, automatic)!
	widths := grid_track_defaults(columns, config.column_default_width, config.columns_minimum, automatic)!
	heights := grid_track_defaults(rows, config.row_default_height, config.rows_minimum, automatic)!
	mut width_extra := f64(0)
	mut height_extra := f64(0)
	for index, child in child_sizes {
		if math.is_nan(child.width) || math.is_inf(child.width, 0) || child.width < 0
			|| math.is_nan(child.height) || math.is_inf(child.height, 0) || child.height < 0 {
			return error('grid child preferred sizes must be finite and non-negative')
		}
		cell := cells[index]
		if !config.force_column_width {
			width_extra = math.max(width_extra, grid_preferred_track_extra(widths, cell.column, cell.column_span,
				child.width, config.spacing.horizontal))
		}
		if !config.force_row_height {
			height_extra = math.max(height_extra, grid_preferred_track_extra(heights, cell.row, cell.row_span,
				child.height, config.spacing.vertical))
		}
	}
	mut width := config.padding.left + config.padding.right + config.spacing.horizontal * f64(math.max(0, columns - 1)) + width_extra * f64(columns)
	mut height := config.padding.top + config.padding.bottom + config.spacing.vertical * f64(math.max(0, rows - 1)) + height_extra * f64(rows)
	for track in widths { width += track }
	for track in heights { height += track }
	if math.is_inf(width, 0) || math.is_inf(height, 0) {
		return error('grid preferred sizes exceed the finite layout range')
	}
	return rect(0, 0, width, height)
}

fn grid_preferred_track_extra(tracks []f64, start int, count int, preferred f64, spacing f64) f64 {
	mut current := spacing * f64(count - 1)
	for index in start .. start + count {
		current += tracks[index]
	}
	return math.max(0.0, (preferred - current) / f64(count))
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
