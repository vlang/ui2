module ui2

import math

// ChartType selects the geometry used by chart.
pub enum ChartType {
	line
	bar
	scatter
	pie
	doughnut
}

// ChartPoint supplies numeric x/y coordinates for scatter charts.
pub struct ChartPoint {
pub:
	x f64
	y f64
}

// ChartDataset describes one series. Scatter uses points; other types use data.
// An omitted color uses the chart palette; pie/doughnut use a color per slice.
pub struct ChartDataset {
pub:
	label        string
	data         []f64
	points       []ChartPoint
	color        ?u32
	colors       []u32
	hidden       bool
	line_width   f64 = 2
	point_radius f64 = 3
}

// ChartData pairs category labels with datasets, in the style of Chart.js.
pub struct ChartData {
pub:
	labels   []string
	datasets []ChartDataset
}

// ChartOptions controls titles, legends, axes, and styling. Explicit y bounds
// clamp plotted values. cutout is the doughnut's inner radius fraction (0...1).
pub struct ChartOptions {
pub:
	title         string
	legend        bool = true
	grid          bool = true
	tooltips      bool = true
	begin_at_zero bool = true
	y_min         ?f64
	y_max         ?f64
	ticks         int   = 5
	cutout        f64   = 0.5
	background    u32   = 0xffffff
	text_color    u32   = 0x334155
	grid_color    u32   = 0xe2e8f0
	palette       []u32 = [u32(0x3b82f6), 0xef4444, 0x10b981, 0xf59e0b, 0x8b5cf6, 0x06b6d4]
}

// ChartConfig describes a display-only chart that fits its supplied frame.
pub struct ChartConfig {
pub:
	id      string
	frame   Rect
	type    ChartType
	data    ChartData
	options ChartOptions
}

struct ChartScale {
	min f64
	max f64
}

fn chart_finite(value f64) bool {
	return !math.is_nan(value) && !math.is_inf(value, 0)
}

fn chart_scale(values []f64, zero bool, lower ?f64, upper ?f64) !ChartScale {
	mut lo := math.inf(1)
	mut hi := math.inf(-1)
	for value in values {
		if chart_finite(value) {
			lo = math.min(lo, value)
			hi = math.max(hi, value)
		}
	}
	if lo > hi {
		lo, hi = 0.0, 1.0
	}
	if zero {
		lo = math.min(lo, 0)
		hi = math.max(hi, 0)
	}
	if lo == hi {
		padding := math.max(math.abs(lo) * 0.1, 1)
		if !zero || lo != 0 {
			lo -= padding
		}
		hi += padding
	}
	if value := lower {
		lo = value
		if upper == none && hi <= lo {
			hi = lo + math.max(math.abs(lo) * 0.1, 1)
		}
	}
	if value := upper {
		hi = value
		if lower == none && lo >= hi {
			lo = hi - math.max(math.abs(hi) * 0.1, 1)
		}
	}
	if !chart_finite(lo) || !chart_finite(hi) || hi <= lo || !chart_finite(hi - lo) {
		return error('chart: axis bounds must be finite and increasing')
	}
	return ChartScale{lo, hi}
}

fn (scale ChartScale) fraction(value f64) f64 {
	return math.max(0.0, math.min(1.0, (value - scale.min) / (scale.max - scale.min)))
}

fn chart_tick_scale(scale ChartScale, ticks int) (ChartScale, int) {
	raw := (scale.max - scale.min) / ticks
	unit := math.pow(10, math.floor(math.log10(raw)))
	ratio := raw / unit
	multiple := if ratio <= 1 {
		1.0
	} else if ratio <= 2 {
		2.0
	} else if ratio <= 5 {
		5.0
	} else {
		10.0
	}
	step := multiple * unit
	lo := math.floor(scale.min / step) * step
	hi := math.ceil(scale.max / step) * step
	// Very small or very large finite ranges may not permit rounded bounds.
	if step <= 0 || !chart_finite(lo) || !chart_finite(hi) || hi <= lo
		|| !chart_finite(hi - lo) {
		return scale, ticks
	}
	return ChartScale{lo, hi}, int(math.round((hi - lo) / step))
}

fn chart_number(value f64) string {
	if math.abs(value) >= 1e6 || (value != 0 && math.abs(value) < 0.001) {
		return '${value:.2e}'
	}
	return '${value:.3f}'.trim_right('0').trim_right('.')
}

fn chart_tick_number(scale ChartScale, index int, ticks int) string {
	step := (scale.max - scale.min) / ticks
	value := scale.min + f64(index) * step
	return chart_number(if math.abs(value) <= math.abs(step) * 1e-12 { 0.0 } else { value })
}

fn chart_color(dataset ChartDataset, index int, options ChartOptions) u32 {
	return dataset.color or { options.palette[index % options.palette.len] }
}

fn chart_slice_color(dataset ChartDataset, index int, options ChartOptions) u32 {
	if dataset.colors.len > 0 {
		return dataset.colors[index % dataset.colors.len]
	}
	return options.palette[index % options.palette.len]
}

fn chart_category(data ChartData, index int) string {
	return if index < data.labels.len { data.labels[index] } else { (index + 1).str() }
}

fn chart_box(frame Rect, color u32, tooltip string) Element {
	return Element{
		...view('', frame, BoxStyle{ bg: color }, [])
		tooltip: tooltip
	}
}

fn chart_text(text string, frame Rect, options ChartOptions, align Align) Element {
	return label('', text, frame, TextStyle{
		color: options.text_color
		size:  12
		align: align
	})
}

// A line is scan-converted into adjoining one-unit strips. These ordinary
// views draw on every backend without adding a backend-specific canvas API.
fn chart_line(mut children []Element, a ChartPoint, b ChartPoint, width f64, color u32) {
	if width <= 0 {
		return
	}
	dx, dy := b.x - a.x, b.y - a.y
	steps := int(math.ceil(math.min(math.abs(dx), math.abs(dy))))
	if steps == 0 {
		children << chart_box(rect(math.min(a.x, b.x) - width / 2, math.min(a.y, b.y) - width / 2,

			math.abs(dx) + width, math.abs(dy) + width), color, '')
		return
	}
	for i in 0 .. steps {
		t0, t1 := f64(i) / steps, f64(i + 1) / steps
		x0, x1 := a.x + dx * t0, a.x + dx * t1
		y0, y1 := a.y + dy * t0, a.y + dy * t1
		children << chart_box(rect(math.min(x0, x1) - width / 2, math.min(y0, y1) - width / 2,

			math.abs(x1 - x0) + width, math.abs(y1 - y0) + width), color, '')
	}
}

fn chart_legend(mut children []Element, names []string, colors []u32, width f64, y f64, options ChartOptions) f64 {
	if !options.legend || names.len == 0 {
		return y
	}
	mut x := 12.0
	mut row_y := y
	for i, name in names {
		item_width := math.min(width - 24, math.max(48.0, f64(name.runes().len) * 7 + 28))
		if x > 12 && x + item_width > width - 12 {
			x = 12
			row_y += 22
		}
		children << chart_box(rect(x, row_y + 5, 10, 10), colors[i], '')
		children << with_tooltip(chart_text(name, rect(x + 16, row_y, item_width - 20, 20),
			options, .left), name)
		x += item_width
	}
	return row_y + 26
}

// chart builds a portable Element tree. Rebuild it with new data or a new frame
// to update the chart. Invalid options return an error; non-finite data are gaps.
// Pie and doughnut charts accept at most one visible dataset and skip values <= 0.
pub fn chart(config ChartConfig) !Element {
	o := config.options
	if !chart_finite(config.frame.x) || !chart_finite(config.frame.y)
		|| !chart_finite(config.frame.width) || !chart_finite(config.frame.height)
		|| config.frame.width < 120 || config.frame.height < 100 {
		return error('chart: frame must be finite and at least 120 by 100')
	}
	if o.palette.len == 0 || o.ticks < 1 || o.ticks > 20 || !chart_finite(o.cutout) || o.cutout < 0
		|| o.cutout >= 1 {
		return error('chart: use a nonempty palette, 1...20 ticks, and cutout in [0, 1)')
	}
	mut datasets := []ChartDataset{}
	for index, dataset in config.data.datasets {
		if dataset.hidden {
			continue
		}
		if !chart_finite(dataset.line_width) || dataset.line_width < 0 || dataset.line_width > 20
			|| !chart_finite(dataset.point_radius) || dataset.point_radius < 0
			|| dataset.point_radius > 20 {
			return error('chart: line width and point radius must be in 0...20')
		}
		if (config.type == .scatter && dataset.data.len > 0)
			|| (config.type != .scatter && dataset.points.len > 0) {
			return error('chart: scatter uses points; other chart types use data')
		}
		datasets << ChartDataset{
			...dataset
			color: chart_color(dataset, index, o)
		}
	}
	mut children := []Element{}
	mut top := 12.0
	if o.title.len > 0 {
		children << label('', o.title, rect(12, top, config.frame.width - 24, 24), TextStyle{
			color: o.text_color
			size:  16
			bold:  true
		})
		top += 30
	}
	circular := config.type in [.pie, .doughnut]
	if circular && datasets.len > 1 {
		return error('chart: pie and doughnut accept one visible dataset')
	}
	mut names := []string{}
	mut colors := []u32{}
	if circular && datasets.len == 1 {
		for i, _ in datasets[0].data {
			names << chart_category(config.data, i)
			colors << chart_slice_color(datasets[0], i, o)
		}
	} else {
		for i, dataset in datasets {
			names << if dataset.label.len > 0 { dataset.label } else { 'Series ${i + 1}' }
			colors << chart_color(dataset, i, o)
		}
	}
	top = chart_legend(mut children, names, colors, config.frame.width, top, o)
	if config.frame.height - top < 48 {
		return error('chart: frame is too short for its title and legend')
	}
	if circular {
		if datasets.len > 0 {
			chart_slices(mut children, datasets[0], config, top)
		}
	} else {
		chart_cartesian(mut children, datasets, config, top)!
	}
	return Element{
		...view(config.id, config.frame, BoxStyle{ bg: o.background }, children)
		accessibility_role:  'img'
		accessibility_label: if o.title.len > 0 { o.title } else { '${config.type} chart' }
		accessibility_value: chart_description(datasets, config)
	}
}

fn chart_description(datasets []ChartDataset, config ChartConfig) string {
	mut descriptions := []string{}
	for dataset in datasets {
		mut values := []string{}
		if config.type == .scatter {
			for point in dataset.points {
				if chart_finite(point.x) && chart_finite(point.y) {
					values << '(${chart_number(point.x)}, ${chart_number(point.y)})'
				}
			}
		} else {
			for i, value in dataset.data {
				if chart_finite(value) && (config.type !in [.pie, .doughnut] || value > 0) {
					values << '${chart_category(config.data, i)}: ${chart_number(value)}'
				}
			}
		}
		descriptions << '${dataset.label}: ${values.join(', ')}'
	}
	return descriptions.join('; ')
}

fn chart_cartesian(mut children []Element, datasets []ChartDataset, config ChartConfig, top f64) ! {
	o := config.options
	mut xs := []f64{}
	mut ys := []f64{}
	mut count := config.data.labels.len
	for dataset in datasets {
		count = math.max(count, dataset.data.len)
		if config.type == .scatter {
			for p in dataset.points {
				if chart_finite(p.x) && chart_finite(p.y) {
					xs << p.x
					ys << p.y
				}
			}
		} else {
			ys << dataset.data
		}
	}
	mut yscale := chart_scale(ys, o.begin_at_zero || config.type == .bar, o.y_min, o.y_max)!
	mut yticks := o.ticks
	if o.y_min == none && o.y_max == none {
		yscale, yticks = chart_tick_scale(yscale, o.ticks)
	}
	xscale, xticks := chart_tick_scale(chart_scale(xs, false, none, none)!, o.ticks)
	plot := rect(64, top + 8, config.frame.width - 96, config.frame.height - top - 42)
	for i in 0 .. yticks + 1 {
		fraction := f64(i) / yticks
		y := plot.y + plot.height * (1 - fraction)
		if o.grid {
			children << chart_box(rect(plot.x, y, plot.width, 1), o.grid_color, '')
		}
		children << chart_text(chart_tick_number(yscale, i, yticks), rect(2,
			y - 9, 56, 18), o, .right)
	}
	if config.type == .scatter {
		for i in 0 .. xticks + 1 {
			fraction := f64(i) / xticks
			x := plot.x + plot.width * fraction
			if o.grid {
				children << chart_box(rect(x, plot.y, 1, plot.height), o.grid_color, '')
			}
			children << chart_text(chart_tick_number(xscale, i, xticks), rect(x - 28,

				plot.y + plot.height + 6, 56, 20), o, .center)
		}
	} else if count > 0 {
		label_slots := math.max(1, int(plot.width / 60))
		stride := math.max(1, int(math.ceil(f64(count) / label_slots)))
		for i := 0; i < count; i += stride {
			x := chart_category_x(i, count, plot, config.type)
			children << with_tooltip(chart_text(chart_category(config.data, i), rect(x - 28,

				plot.y + plot.height + 6, 56, 20), o, .center), chart_category(config.data, i))
		}
	}
	children << chart_box(rect(plot.x, plot.y, 1, plot.height), o.text_color, '')
	children << chart_box(rect(plot.x, plot.y + plot.height, plot.width, 1), o.text_color, '')
	mut marks := []Element{}
	for series, dataset in datasets {
		color := chart_color(dataset, series, o)
		mut previous := ?ChartPoint(none)
		length := if config.type == .scatter { dataset.points.len } else { dataset.data.len }
		for i in 0 .. length {
			value := if config.type == .scatter { dataset.points[i].y } else { dataset.data[i] }
			if !chart_finite(value)
				|| (config.type == .scatter && !chart_finite(dataset.points[i].x)) {
				previous = none
				continue
			}
			x := if config.type == .scatter {
				plot.width * xscale.fraction(dataset.points[i].x)
			} else {
				chart_category_x(i, count, plot, config.type) - plot.x
			}
			y := plot.height * (1 - yscale.fraction(value))
			caption := if config.type == .scatter {
				'(${chart_number(dataset.points[i].x)}, ${chart_number(value)})'
			} else {
				'${chart_category(config.data, i)}: ${chart_number(value)}'
			}
			tip := if o.tooltips { '${dataset.label} ${caption}'.trim_space() } else { '' }
			if config.type == .bar {
				group_width := plot.width / math.max(1, count) * 0.8
				bar_width := group_width / datasets.len
				baseline := plot.height * (1 - yscale.fraction(0))
				marks << chart_box(rect(x - group_width / 2 + series * bar_width, math.min(y,
					baseline), bar_width * 0.9, math.abs(baseline - y)), color, tip)
			} else {
				point := ChartPoint{x, y}
				if config.type == .line {
					if a := previous {
						chart_line(mut marks, a, point, dataset.line_width, color)
					}
				}
				r := dataset.point_radius
				if r > 0 {
					marks << Element{
						...chart_box(rect(x - r, y - r, 2 * r, 2 * r), color, tip)
						box: BoxStyle{
							bg:     color
							radius: r
						}
					}
				}
				previous = point
			}
		}
	}
	children << view('', plot, BoxStyle{ transparent: true }, marks)
}

fn chart_category_x(index int, count int, plot Rect, kind ChartType) f64 {
	if kind == .bar || count <= 1 {
		return plot.x + plot.width * (f64(index) + 0.5) / math.max(1, count)
	}
	return plot.x + plot.width * f64(index) / (count - 1)
}

fn chart_slices(mut children []Element, dataset ChartDataset, config ChartConfig, top f64) {
	o := config.options
	// Normalize before summing to keep large finite values from overflowing.
	mut largest := 0.0
	for value in dataset.data {
		if chart_finite(value) {
			largest = math.max(largest, value)
		}
	}
	if largest <= 0 {
		return
	}
	mut total := 0.0
	for value in dataset.data {
		if chart_finite(value) && value > 0 {
			total += value / largest
		}
	}
	mut angles := []f64{}
	mut indices := []int{}
	mut sum := 0.0
	for i, value in dataset.data {
		if chart_finite(value) && value > 0 {
			sum += value / largest / total
			angles << sum * 2 * math.pi
			indices << i
		}
	}
	r := math.min(config.frame.width - 24, config.frame.height - top - 12) / 2
	cx, cy := config.frame.width / 2, top + r
	inner := if config.type == .doughnut { r * o.cutout } else { 0.0 }
	rows := int(math.ceil(2 * r))
	for row in 0 .. rows {
		y0 := -r + row
		y1 := math.min(r, y0 + 1)
		y := (y0 + y1) / 2
		half := math.sqrt(math.max(0.0, r * r - y * y))
		mut edges := [-half, half]
		if math.abs(y) < inner {
			hole := math.sqrt(inner * inner - y * y)
			edges << -hole
			edges << hole
		}
		// Slice boundaries start at twelve o'clock and run clockwise.
		for angle in angles {
			rx, ry := math.sin(angle), -math.cos(angle)
			if math.abs(ry) > 1e-10 && y / ry >= 0 {
				x := y * rx / ry
				if x > -half && x < half {
					edges << x
				}
			}
		}
		edges.sort()
		for j in 0 .. edges.len - 1 {
			x := (edges[j] + edges[j + 1]) / 2
			if x * x + y * y < inner * inner || edges[j + 1] <= edges[j] {
				continue
			}
			mut angle := math.atan2(y, x) + math.pi / 2
			if angle < 0 {
				angle += 2 * math.pi
			}
			mut slice := 0
			for slice < angles.len - 1 && angle >= angles[slice] {
				slice++
			}
			i := indices[slice]
			tip := if o.tooltips {
				'${chart_category(config.data, i)}: ${chart_number(dataset.data[i])}'
			} else {
				''
			}
			children << chart_box(rect(cx + edges[j], cy + y0, edges[j + 1] - edges[j], y1 - y0), chart_slice_color(dataset,
				i, o), tip)
		}
	}
}
