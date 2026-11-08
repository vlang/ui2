module ui2

import math

// plot_axis draws an axis along one edge of a plot area: its line, tick
// marks, tick labels measured with measure_text_width, and optional grid
// lines across the plot, as GPUI Kit's PlotAxis and Grid do.

pub enum PlotAxisOrientation {
	bottom // labels below the plot
	left   // labels left of the plot, right-aligned
	top    // labels above the plot
	right  // labels right of the plot
}

pub fn (orientation PlotAxisOrientation) is_vertical() bool {
	return orientation in [.left, .right]
}

// PlotTickAlign places a tick's label against its position: centered on it,
// starting at it, or ending at it (top and bottom for left and right axes).
pub enum PlotTickAlign {
	center
	start
	end
}

// PlotAxisTick is one tick: where it sits along the axis, measured from the
// plot's left edge for top and bottom axes and from its top edge for left and
// right ones, and its label.
pub struct PlotAxisTick {
pub:
	position f64
	text     string
	align    PlotTickAlign
}

pub struct PlotAxisConfig {
pub:
	id          string // Required: the line and the grid are shapes with ids under it.
	plot        Rect   // The plot area, in the coordinates of the parent the axis goes in.
	orientation PlotAxisOrientation
	ticks       []PlotAxisTick
	line        bool = true // The axis line.
	// line_offset moves the line across the plot, such as onto the zero of a
	// chart with negative values: from the plot's top for top and bottom axes,
	// from its left for the others. By default it runs along the edge.
	line_offset  ?f64
	tick_size    f64 // Tick marks out from the edge; 0 draws none.
	tick_padding f64  = 6 // Space between the edge (or the tick marks) and the labels.
	labels       bool = true
	// labels_inside draws a left or right axis' labels over the plot, beside
	// the grid line each one reads (above it, or below it at the top edge), so
	// the plot keeps the room a gutter would take: GPUI Kit's
	// AxisLabelPlacement::Inside.
	labels_inside bool
	// label_extent is the width of a left or right axis' label gutter; 0 fits
	// the widest label.
	label_extent f64
	grid         bool // Grid lines across the plot at every tick.
	grid_dashed  bool
	label_size   f64 = 11
	label_color  ?u32 // Defaults to the theme's muted foreground.
	line_color   ?u32 // Defaults to the theme's border.
	grid_color   ?u32 // Defaults to plot_grid_color(theme).
	theme        ComponentTheme
}

// plot_label_height is the height a label of `size` needs.
pub fn plot_label_height(size f64) f64 {
	return math.ceil(size * 1.45)
}

fn plot_axis_label_style(config PlotAxisConfig) TextStyle {
	return TextStyle{
		color: config.label_color or { config.theme.muted_foreground }
		size:  config.label_size
	}
}

// plot_axis_size is how far the axis reaches out from the plot's edge: the
// tick marks, the padding and the labels (their height for top and bottom
// axes, the widest one for left and right). A chart leaves that much room.
pub fn plot_axis_size(config PlotAxisConfig) f64 {
	mut size := math.max(0.0, config.tick_size)
	if !config.labels || config.ticks.len == 0 || plot_axis_inside(config) {
		return size
	}
	size += math.max(0.0, config.tick_padding)
	if config.orientation.is_vertical() {
		return size + plot_axis_label_extent(config)
	}
	return size + plot_label_height(config.label_size)
}

fn plot_axis_label_extent(config PlotAxisConfig) f64 {
	if config.label_extent > 0 {
		return config.label_extent
	}
	style := plot_axis_label_style(config)
	mut widest := 0.0
	for tick in config.ticks {
		widest = math.max(widest, measure_text_width(tick.text, style))
	}
	return math.ceil(widest)
}

fn plot_axis_inside(config PlotAxisConfig) bool {
	return config.labels_inside && config.orientation.is_vertical()
}

// plot_axis_label_frames are the label frames of every tick, in the plot's
// coordinates (0, 0 is its top left corner).
pub fn plot_axis_label_frames(config PlotAxisConfig) []Rect {
	mut frames := []Rect{cap: config.ticks.len}
	if !config.labels {
		return frames
	}
	style := plot_axis_label_style(config)
	height := plot_label_height(config.label_size)
	gap := math.max(0.0, config.tick_size) + math.max(0.0, config.tick_padding)
	plot := config.plot
	if plot_axis_inside(config) {
		for tick in config.ticks {
			width := math.ceil(measure_text_width(tick.text, style))
			x := if config.orientation == .left { 2.0 } else { plot.width - 2 - width }
			y := if tick.position < height { tick.position + 1 } else { tick.position - height }
			frames << rect(x, y, width, height)
		}
		return frames
	}
	extent := if config.orientation.is_vertical() { plot_axis_label_extent(config) } else { 0.0 }
	for tick in config.ticks {
		if config.orientation.is_vertical() {
			y := match tick.align {
				.center { tick.position - height / 2 }
				.start { tick.position }
				.end { tick.position - height }
			}
			x := if config.orientation == .left { -gap - extent } else { plot.width + gap }
			frames << rect(x, y, extent, height)
		} else {
			width := math.ceil(measure_text_width(tick.text, style))
			x := match tick.align {
				.center { tick.position - width / 2 }
				.start { tick.position }
				.end { tick.position - width }
			}
			y := if config.orientation == .bottom { plot.height + gap } else { -gap - height }
			frames << rect(x, y, width, height)
		}
	}
	return frames
}

// plot_axis_frame is the frame of the element plot_axis returns: the plot
// area and everything the axis draws outside it.
pub fn plot_axis_frame(config PlotAxisConfig) Rect {
	plot := config.plot
	mut x0, mut y0 := 0.0, 0.0
	mut x1, mut y1 := plot.width, plot.height
	size := plot_axis_size(config)
	match config.orientation {
		.bottom { y1 += size }
		.top { y0 -= size }
		.left { x0 -= size }
		.right { x1 += size }
	}
	for f in plot_axis_label_frames(config) {
		x0 = math.min(x0, f.x)
		y0 = math.min(y0, f.y)
		x1 = math.max(x1, f.x + f.width)
		y1 = math.max(y1, f.y + f.height)
	}
	return rect(plot.x + x0, plot.y + y0, x1 - x0, y1 - y0)
}

// plot_crisp moves a hairline onto the middle of a pixel so it is drawn one
// pixel wide instead of blurred across two.
fn plot_crisp(position f64) f64 {
	return math.floor(position) + 0.5
}

// plot_dashed_segment adds the line from (x0, y0) to (x1, y1) to path, as
// dashes 4 long and 3 apart when dashed.
fn plot_dashed_segment(mut path []PathCommand, x0 f64, y0 f64, x1 f64, y1 f64, dashed bool) {
	length := math.hypot(x1 - x0, y1 - y0)
	if length <= 0 {
		return
	}
	if !dashed {
		path << path_move_to(x0, y0)
		path << path_line_to(x1, y1)
		return
	}
	mut at := 0.0
	for at < length {
		end := math.min(length, at + 4)
		path << path_move_to(x0 + (x1 - x0) * at / length, y0 + (y1 - y0) * at / length)
		path << path_line_to(x0 + (x1 - x0) * end / length, y0 + (y1 - y0) * end / length)
		at += 7
	}
}

// plot_grid_path is the grid lines of the ticks as one path in the plot's
// coordinates. A grid line on the same position as the other axis' line is
// drawn on the same pixel row, so that line covers it.
fn plot_grid_path(config PlotAxisConfig) []PathCommand {
	mut path := []PathCommand{}
	plot := config.plot
	for tick in config.ticks {
		if config.orientation.is_vertical() {
			if tick.position < -0.5 || tick.position > plot.height + 0.5 {
				continue
			}
			y := plot_crisp(tick.position)
			plot_dashed_segment(mut path, 0, y, plot.width, y, config.grid_dashed)
		} else {
			if tick.position < -0.5 || tick.position > plot.width + 0.5 {
				continue
			}
			x := plot_crisp(tick.position)
			plot_dashed_segment(mut path, x, 0, x, plot.height, config.grid_dashed)
		}
	}
	return path
}

// plot_axis_line_offset is where the axis line runs across the plot.
fn plot_axis_line_offset(config PlotAxisConfig) f64 {
	if offset := config.line_offset {
		return offset
	}
	return match config.orientation {
		.bottom { config.plot.height }
		.right { config.plot.width }
		.top, .left { 0.0 }
	}
}

// plot_axis_line_path is the axis line and the tick marks, in the plot's
// coordinates.
fn plot_axis_line_path(config PlotAxisConfig) []PathCommand {
	mut path := []PathCommand{}
	plot := config.plot
	at := plot_axis_line_offset(config)
	vertical := config.orientation.is_vertical()
	if config.line {
		// On the pixel row (or column) a grid line at the same position takes,
		// so the two coincide.
		if vertical {
			x := plot_crisp(at)
			path << path_move_to(x, 0)
			path << path_line_to(x, plot.height)
		} else {
			y := plot_crisp(at)
			path << path_move_to(0, y)
			path << path_line_to(plot.width, y)
		}
	}
	if config.tick_size > 0 {
		for tick in config.ticks {
			p := plot_crisp(tick.position)
			match config.orientation {
				.bottom {
					path << path_move_to(p, plot.height)
					path << path_line_to(p, plot.height + config.tick_size)
				}
				.top {
					path << path_move_to(p, 0)
					path << path_line_to(p, -config.tick_size)
				}
				.left {
					path << path_move_to(0, p)
					path << path_line_to(-config.tick_size, p)
				}
				.right {
					path << path_move_to(plot.width, p)
					path << path_line_to(plot.width + config.tick_size, p)
				}
			}
		}
	}
	return path
}

fn plot_offset_path(path []PathCommand, dx f64, dy f64) []PathCommand {
	mut out := []PathCommand{cap: path.len}
	for cmd in path {
		out << PathCommand{
			verb: cmd.verb
			x:    cmd.x + dx
			y:    cmd.y + dy
			cx1:  cmd.cx1 + dx
			cy1:  cmd.cy1 + dy
			cx2:  cmd.cx2 + dx
			cy2:  cmd.cy2 + dy
		}
	}
	return out
}

pub fn plot_axis(config PlotAxisConfig) !Element {
	component_validate_id(config.id)!
	component_validate_frame(config.plot)!
	if !plot_finite(config.tick_size) || !plot_finite(config.tick_padding)
		|| !plot_finite(config.label_size) || config.label_size <= 0 {
		return error('plot axis sizes must be finite, and the label size positive')
	}
	frame := plot_axis_frame(config)
	// Children are placed in the axis frame; the plot sits at (dx, dy) in it.
	dx := config.plot.x - frame.x
	dy := config.plot.y - frame.y
	local := rect(0, 0, frame.width, frame.height)
	mut children := []Element{}
	if config.grid {
		grid := plot_grid_path(config)
		if grid.len > 0 {
			children << shape(component_part_id(config.id, 'grid'), local, plot_offset_path(grid,
				dx, dy), ShapeStyle{
				stroke:       config.grid_color or { plot_grid_color(config.theme) }
				stroke_width: 1
				line_cap:     .butt
			})
		}
	}
	line := plot_axis_line_path(config)
	if line.len > 0 {
		children << shape(component_part_id(config.id, 'line'), local, plot_offset_path(line,
			dx, dy), ShapeStyle{
			stroke:       config.line_color or { config.theme.border }
			stroke_width: 1
			line_cap:     .butt
		})
	}
	style := plot_axis_label_style(config)
	frames := plot_axis_label_frames(config)
	for i, tick in config.ticks {
		if i >= frames.len || tick.text.len == 0 {
			continue
		}
		f := frames[i]
		// A top or bottom label is placed centered by its frame and drawn left
		// aligned in it: AppKit cuts short a centered label exactly as wide as
		// measure_text_width says its text is.
		children << label('', tick.text, rect(f.x + dx, f.y + dy, f.width, f.height), TextStyle{
			...style
			align: if config.orientation == .left && !plot_axis_inside(config) {
				.right
			} else {
				.left
			}
		})
	}
	return component_finish(Element{
		...view(config.id, frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: if config.orientation.is_vertical() {
			'Vertical axis'
		} else {
			'Horizontal axis'
		}
	})
}

// ── Ticks ──────────────────────────────────────────────────────────

// plot_linear_ticks labels about `count` round values of a linear scale at
// their positions, written by `format` or with as many decimals as the step
// needs.
pub fn plot_linear_ticks(scale PlotLinearScale, count int, format PlotFormatFn) []PlotAxisTick {
	values := scale.ticks(count)
	decimals := plot_tick_decimals(scale.tick_step(count))
	mut ticks := []PlotAxisTick{cap: values.len}
	for value in values {
		ticks << PlotAxisTick{
			position: scale.position(value)
			text:     plot_call_format(format, value, plot_format_number(value, decimals))
		}
	}
	return ticks
}

// plot_band_ticks labels every `stride`-th band at its center, from the first.
pub fn plot_band_ticks(scale PlotBandScale, stride int) []PlotAxisTick {
	step := if stride < 1 { 1 } else { stride }
	mut ticks := []PlotAxisTick{}
	for i, value in scale.domain {
		if i % step == 0 {
			ticks << PlotAxisTick{
				position: scale.center_at(i)
				text:     value
			}
		}
	}
	return ticks
}

// plot_point_ticks labels every `stride`-th point, from the first. A label on
// a point at either end of the range is aligned inward so it stays over the
// plot.
pub fn plot_point_ticks(scale PlotPointScale, stride int) []PlotAxisTick {
	mut indices := []int{}
	step := if stride < 1 { 1 } else { stride }
	for i in 0 .. scale.domain.len {
		if i % step == 0 {
			indices << i
		}
	}
	return plot_point_ticks_at(scale, indices)
}

// plot_point_ticks_at labels the points at `indices`.
pub fn plot_point_ticks_at(scale PlotPointScale, indices []int) []PlotAxisTick {
	n := scale.point_count()
	mut ticks := []PlotAxisTick{cap: indices.len}
	for i in indices {
		if i < 0 || i >= scale.domain.len {
			continue
		}
		position := scale.position_at(i)
		align := if n == 1 || scale.padding > 0 {
			PlotTickAlign.center
		} else if i == 0 {
			PlotTickAlign.start
		} else if i == n - 1 {
			PlotTickAlign.end
		} else {
			PlotTickAlign.center
		}
		ticks << PlotAxisTick{
			position: position
			text:     scale.domain[i]
			align:    align
		}
	}
	return ticks
}

// plot_spread_indices picks `labels` of `count` items spread evenly from the
// first to the last, as GPUI Kit's x_tick_count does.
pub fn plot_spread_indices(count int, labels int) []int {
	if count <= 0 || labels <= 0 {
		return []int{}
	}
	if labels == 1 {
		return [0]
	}
	if labels >= count {
		return []int{len: count, init: index}
	}
	mut out := []int{cap: labels}
	for k in 0 .. labels {
		i := int(math.round(f64(k) * f64(count - 1) / f64(labels - 1)))
		if out.len == 0 || out[out.len - 1] != i {
			out << i
		}
	}
	return out
}

// plot_label_stride is the smallest stride that keeps labels `spacing` apart
// from overlapping: every label fits in stride * spacing with `gap` to spare.
pub fn plot_label_stride(texts []string, spacing f64, style TextStyle, gap f64) int {
	if texts.len == 0 || spacing <= 0 {
		return 1
	}
	mut widest := 0.0
	for t in texts {
		widest = math.max(widest, measure_text_width(t, style))
	}
	stride := int(math.ceil((widest + gap) / spacing))
	return if stride < 1 { 1 } else { stride }
}
