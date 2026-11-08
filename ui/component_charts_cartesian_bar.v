module ui2

import math

// PlotBarLayout is how a bar chart's series share a category.
pub enum PlotBarLayout {
	grouped // side by side
	stacked // end to end; negative values stack the other way from zero
	expand  // stacked, as shares of each category's total (a 100% chart)
}

// BarChartConfig describes GPUI Kit's BarChart, widened to several series:
// bars from the zero line for each category, vertical or horizontal,
// grouped or stacked, with a highlight and tooltip for the hovered category.
pub struct BarChartConfig {
pub:
	id            string // Required: the bars, hover bands and motion are keyed on it.
	frame         Rect
	categories    []string // One band each.
	series        []PlotSeries
	hidden_series []string
	layout        PlotBarLayout
	// alignment is the side the bars grow from: .bottom (vertical bars, the
	// default), .top, .left (horizontal bars) or .right. The category labels
	// go on that side.
	alignment     PlotBarAlignment = .bottom
	padding_inner f64              = 0.4 // Space between bands, as a share of a band's step.
	padding_outer f64              = 0.2 // Space before the first band and after the last, in steps.
	bar_gap       f64              = 2   // Between the bars of a group and the segments of a stack.
	max_bar_width f64              = 30  // The thickest a bar (or a stack) is drawn.
	corner_radius f64              = 4   // Rounds the corners at each bar's tip.
	min_length    f64  // Draws every bar at least this long, so a zero still shows.
	value_labels  bool // The value at each bar's tip (each stack's total).
	label_format  PlotFormatFn = unsafe { nil }
	hovered       int          = -1 // From plot_hover_from_event; -1 is none.
	interactive   bool         = true
	band_axis     bool         = true // The category labels and the zero line.
	value_axis    bool         = true // The value tick labels.
	grid          bool         = true
	grid_dashed   bool
	// value_tick_count is about how many value ticks there are, at round
	// values; value_min and value_max pin the value axis.
	value_tick_count int = 5
	value_min        ?f64
	value_max        ?f64
	tick_margin      int // Label every n-th category; 0 keeps labels apart.
	band_tick_count  int // Label this many categories, spread out, instead.
	// band_count lays the band axis out for more bands than categories, so a
	// short series keeps each bar's width and fills only the leading bands.
	band_count int
	// value_axis_inside draws the value tick labels of vertical bars over the
	// plot beside their grid lines instead of in a gutter.
	value_axis_inside    bool
	value_format         PlotFormatFn     = unsafe { nil } // Value tick labels.
	tooltip_title        PlotTitleFn      = unsafe { nil }
	tooltip_value_format PlotFormatFn     = unsafe { nil }
	tooltip_value_color  PlotValueColorFn = unsafe { nil }
	legend               PlotLegendPosition
	legend_toggle        bool
	margin               PlotMargin
	// appear grows the bars out of the zero line the first time the chart is
	// built; appear_key replays it when changed.
	appear              bool = true
	appear_key          string
	appear_duration     f64 = 1.0
	reduce_motion       bool
	size                ComponentSize = .medium
	theme               ComponentTheme
	accessibility_label string
}

// PlotBar is one drawn bar (or one segment of a stack), in the chart's
// coordinates, as bar_chart_bars computes it.
pub struct PlotBar {
pub:
	key     string // The series key.
	series  int    // The series' position in config.series.
	index   int    // The category.
	value   f64
	frame   Rect
	corners PlotCorners
	base    f64 // Where the bar starts along the value axis, in chart coordinates.
	tip     f64 // Where it ends.
}

struct BarChartGeometry {
	plot         Rect
	legend       Rect
	legend_items []CartesianLegendItem
	band         PlotBandScale   // along the band axis, in plot coordinates
	value        PlotLinearScale // along the value axis, in plot coordinates
	band_ticks   []PlotAxisTick
	value_ticks  []PlotAxisTick
	series       []CartesianSeries
	visible      []CartesianSeries
	bars         []PlotBar
	groups       []Rect // per category: around its bars, in chart coordinates
	slots        []Rect // per category: its hover band
	totals       []f64  // per category: the stack's total, for labels and the tooltip
	zero         f64    // the zero line along the value axis, in plot coordinates
	text         CartesianText
	horizontal   bool
}

fn bar_chart_validate(config BarChartConfig) ! {
	component_validate_id(config.id)!
	component_validate_frame(config.frame)!
	for name, value in {
		'padding_outer':   config.padding_outer
		'bar_gap':         config.bar_gap
		'max_bar_width':   config.max_bar_width
		'corner_radius':   config.corner_radius
		'min_length':      config.min_length
		'appear_duration': config.appear_duration
	} {
		if !plot_finite(value) || value < 0 {
			return error('bar chart ${name} must be finite and non-negative')
		}
	}
	if !plot_finite(config.padding_inner) || config.padding_inner < 0 || config.padding_inner >= 1 {
		return error('bar chart padding_inner must be at least 0 and below 1')
	}
	if config.value_tick_count < 2 || config.value_tick_count > 20 {
		return error('bar chart value_tick_count must be 2 to 20')
	}
}

fn bar_chart_tick_format(config BarChartConfig, decimals int) PlotFormatFn {
	if voidptr(config.value_format) != unsafe { nil } {
		return config.value_format
	}
	if config.layout == .expand {
		return plot_format_percent
	}
	return fn [decimals] (value f64) string {
		return plot_format_number(value, decimals)
	}
}

fn bar_chart_value_text(config BarChartConfig, value f64) string {
	if !plot_finite(value) {
		return '–'
	}
	if voidptr(config.tooltip_value_format) != unsafe { nil } {
		return config.tooltip_value_format(value)
	}
	if voidptr(config.value_format) != unsafe { nil } && config.layout != .expand {
		return config.value_format(value)
	}
	return plot_format_value(value)
}

fn bar_chart_label_text(config BarChartConfig, value f64) string {
	if voidptr(config.label_format) != unsafe { nil } {
		return config.label_format(value)
	}
	return bar_chart_value_text(config, value)
}

// bar_chart_positive is the pixel direction positive values grow in along
// the value axis.
fn bar_chart_positive(alignment PlotBarAlignment) f64 {
	return match alignment {
		.bottom, .right { -1.0 }
		.top, .left { 1.0 }
	}
}

fn bar_chart_geometry(config BarChartConfig) !BarChartGeometry {
	bar_chart_validate(config)!
	series := cartesian_series(config.series, config.hidden_series, config.theme)!
	visible := cartesian_visible(series)
	n := config.categories.len
	sizes := cartesian_text(config.size)
	horizontal := config.alignment.is_horizontal()
	stacked := config.layout != .grouped
	mut columns := [][]f64{}
	for s in visible {
		columns << []f64{len: n, init: cartesian_value(s, index)}
	}
	stack := if stacked {
		plot_stack(visible.map(it.key), columns, if config.layout == .expand {
			PlotStackOffset.expand
		} else {
			.diverging
		})
	} else {
		[]PlotStackSeries{}
	}
	mut extent_values := []f64{}
	if stacked {
		lo, hi := plot_stack_extent(stack)
		extent_values << lo
		extent_values << hi
	} else {
		for column in columns {
			extent_values << column
		}
	}
	mut value := if config.layout == .expand {
		plot_linear_scale(0, 1, 0, 1)
	} else {
		plot_value_scale(extent_values, config.value_min, config.value_max, config.value_tick_count)
	}
	mut totals := []f64{len: n}
	for j in 0 .. n {
		for column in columns {
			if j < column.len && plot_finite(column[j]) {
				totals[j] += column[j]
			}
		}
	}
	tick_values := value.ticks(config.value_tick_count)
	format := bar_chart_tick_format(config, plot_tick_decimals(value.tick_step(config.value_tick_count)))
	tick_style := TextStyle{
		size: sizes.tick
	}
	mut value_texts := []string{cap: tick_values.len}
	mut widest_tick := 0.0
	for v in tick_values {
		t := format(v)
		value_texts << t
		widest_tick = math.max(widest_tick, math.ceil(measure_text_width(t, tick_style)))
	}
	mut widest_band := 0.0
	if config.band_axis {
		for c in config.categories {
			widest_band = math.max(widest_band, math.ceil(measure_text_width(c, tick_style)))
		}
	}
	label_height := plot_label_height(sizes.tick)
	// Room for value labels past the tips, on whichever side bars reach.
	mut has_positive := false
	mut has_negative := false
	mut widest_label := 0.0
	if config.value_labels && config.layout != .expand {
		for j in 0 .. n {
			mut texts := []f64{}
			if stacked {
				texts << totals[j]
			} else {
				for column in columns {
					if j < column.len && plot_finite(column[j]) {
						texts << column[j]
					}
				}
			}
			for v in texts {
				if v < 0 {
					has_negative = true
				} else {
					has_positive = true
				}
				widest_label = math.max(widest_label, math.ceil(measure_text_width(bar_chart_label_text(config,
					v), tick_style)))
			}
		}
	}
	legend_items := cartesian_legend_items(series)
	legend_shown := cartesian_legend_shown(config.legend, series.len)
	legend_width := math.max(0.0, config.frame.width - config.margin.left - config.margin.right)
	_, legend_height := if legend_shown {
		cartesian_legend_frames(legend_items, legend_width, sizes.legend)
	} else {
		[]Rect{}, 0.0
	}
	legend_top := legend_shown && config.legend == .top
	mut top := config.margin.top
	mut bottom := config.margin.bottom
	mut left := config.margin.left
	mut right := config.margin.right
	if legend_top {
		top += legend_height + 8
	} else if legend_shown {
		bottom += legend_height + 10
	}
	band_size := if horizontal { widest_band + 8 } else { label_height + 6 }
	value_size := if horizontal { label_height + 6 } else { widest_tick + 6 }
	if horizontal {
		if config.band_axis {
			if config.alignment == .left {
				left += band_size
			} else {
				right += band_size
			}
		}
		if config.value_axis {
			bottom += value_size
			// The tick labels at the plot's ends are centered on them.
			if value_texts.len > 0 {
				edge := math.ceil(measure_text_width(value_texts[value_texts.len - 1], tick_style) / 2)
				right = math.max(right, edge)
				first := math.ceil(measure_text_width(value_texts[0], tick_style) / 2)
				if !config.band_axis || config.alignment == .right {
					left = math.max(left, first)
				}
			}
		}
		if has_positive {
			if config.alignment == .left {
				right += widest_label + 6
			} else {
				left += widest_label + 6
			}
		}
		if has_negative {
			if config.alignment == .left {
				left += widest_label + 6
			} else {
				right += widest_label + 6
			}
		}
		top += 2
	} else {
		if config.band_axis {
			if config.alignment == .bottom {
				bottom += band_size
			} else {
				top += band_size
			}
		}
		inside := config.value_axis_inside
		if config.value_axis && !inside {
			left += value_size
		}
		reach := label_height + 2
		mut head := if config.value_axis && !inside { label_height / 2 } else { 2.0 }
		mut foot := if config.value_axis && !inside && config.alignment == .top {
			label_height / 2
		} else {
			0.0
		}
		if has_positive {
			if config.alignment == .bottom {
				head = math.max(head, reach)
			} else {
				foot = math.max(foot, reach)
			}
		}
		if has_negative {
			if config.alignment == .bottom {
				foot = math.max(foot, reach)
			} else {
				head = math.max(head, reach)
			}
		}
		top += head
		bottom += foot
	}
	plot := rect(left, top, math.max(0.0, config.frame.width - left - right), math.max(0.0,
		config.frame.height - top - bottom))
	legend := if legend_top {
		rect(config.margin.left, config.margin.top, legend_width, legend_height)
	} else if legend_shown {
		rect(config.margin.left, config.frame.height - config.margin.bottom - legend_height,
			legend_width, legend_height)
	} else {
		Rect{}
	}
	band_length := if horizontal { plot.height } else { plot.width }
	value_length := if horizontal { plot.width } else { plot.height }
	single := stacked || visible.len <= 1
	band := PlotBandScale{
		domain:        config.categories
		range_start:   0
		range_end:     band_length
		padding_inner: config.padding_inner
		padding_outer: config.padding_outer
		count:         config.band_count
		max_bandwidth: if single { config.max_bar_width } else { 0.0 }
	}
	value = match config.alignment {
		.bottom, .right { value.with_range(value_length, 0) }
		.top, .left { value.with_range(0, value_length) }
	}
	zero := math.max(0.0, math.min(value_length, value.position(0)))
	positive := bar_chart_positive(config.alignment)
	// Bars, in plot coordinates first.
	mut bars := []PlotBar{}
	if stacked {
		thickness := band.bandwidth()
		mut outer_up := []int{len: n, init: -1}
		mut outer_down := []int{len: n, init: -1}
		for si, layer in stack {
			for j, p in layer.points {
				if p.value > 0 {
					outer_up[j] = si
				} else if p.value < 0 {
					outer_down[j] = si
				}
			}
		}
		for si, layer in stack {
			s := visible[si]
			for j, p in layer.points {
				if p.value == 0 {
					continue
				}
				mut base := value.position(p.y0)
				tip := value.position(p.y1)
				if p.y0 != 0 && math.abs(tip - base) > config.bar_gap {
					base += if tip > base { config.bar_gap } else { -config.bar_gap }
				}
				outer := (p.value > 0 && outer_up[j] == si) || (p.value < 0 && outer_down[j] == si)
				bars << PlotBar{
					key:     s.key
					series:  s.slot
					index:   j
					value:   p.value
					frame:   plot_bar_rect(config.alignment, band.position_at(j), thickness,
						base, tip)
					corners: if outer {
						plot_tip_corners(config.alignment, config.corner_radius, base, tip)
					} else {
						PlotCorners{}
					}
					base:    base
					tip:     tip
				}
			}
		}
	} else {
		m := visible.len
		bandwidth := band.bandwidth()
		thickness := if m == 0 {
			0.0
		} else {
			math.max(0.5, math.min(config.max_bar_width, (bandwidth - config.bar_gap * f64(m - 1)) / f64(m)))
		}
		group := f64(m) * thickness + f64(m - 1) * config.bar_gap
		for j in 0 .. n {
			start := band.center_at(j) - group / 2
			for k, s in visible {
				v := columns[k][j]
				if !plot_finite(v) {
					continue
				}
				tip := plot_bar_tip(zero, value.position(v), config.min_length, v, positive)
				bars << PlotBar{
					key:     s.key
					series:  s.slot
					index:   j
					value:   v
					frame:   plot_bar_rect(config.alignment, start + f64(k) * (thickness +
						config.bar_gap), thickness, zero, tip)
					corners: plot_tip_corners(config.alignment, config.corner_radius, zero,
						tip)
					base:    zero
					tip:     tip
				}
			}
		}
	}
	// Into chart coordinates.
	along := if horizontal { plot.x } else { plot.y }
	for i, b in bars {
		bars[i] = PlotBar{
			...b
			frame: rect(b.frame.x + plot.x, b.frame.y + plot.y, b.frame.width, b.frame.height)
			base:  b.base + along
			tip:   b.tip + along
		}
	}
	mut groups := []Rect{cap: n}
	mut slots := []Rect{cap: n}
	step := band.step()
	for j in 0 .. n {
		mut x0, mut y0 := math.max_f64, math.max_f64
		mut x1, mut y1 := -math.max_f64, -math.max_f64
		for b in bars {
			if b.index == j {
				x0 = math.min(x0, b.frame.x)
				y0 = math.min(y0, b.frame.y)
				x1 = math.max(x1, b.frame.x + b.frame.width)
				y1 = math.max(y1, b.frame.y + b.frame.height)
			}
		}
		center := band.center_at(j)
		if x0 > x1 {
			// No bar: a sliver on the zero line.
			if horizontal {
				x0, x1 = plot.x + zero, plot.x + zero
				y0, y1 = plot.y + center - 1, plot.y + center + 1
			} else {
				x0, x1 = plot.x + center - 1, plot.x + center + 1
				y0, y1 = plot.y + zero, plot.y + zero
			}
		}
		groups << rect(x0, y0, x1 - x0, y1 - y0)
		lo := math.max(0.0, center - step / 2)
		hi := math.min(band_length, center + step / 2)
		slots << if horizontal {
			rect(plot.x, plot.y + lo, plot.width, math.max(0.0, hi - lo))
		} else {
			rect(plot.x + lo, plot.y, math.max(0.0, hi - lo), plot.height)
		}
	}
	mut value_ticks := []PlotAxisTick{cap: tick_values.len}
	for i, v in tick_values {
		value_ticks << PlotAxisTick{
			position: value.position(v)
			text:     value_texts[i]
		}
	}
	indices := if config.band_tick_count > 0 {
		plot_spread_indices(band.band_count(), config.band_tick_count).filter(it < n)
	} else {
		stride := if config.tick_margin > 0 {
			config.tick_margin
		} else if horizontal {
			int(math.max(1, math.ceil((label_height + 2) / math.max(1.0, step))))
		} else {
			plot_label_stride(config.categories, step, tick_style, 8)
		}
		[]int{len: n, init: index}.filter(it % stride == 0)
	}
	mut band_ticks := []PlotAxisTick{cap: indices.len}
	for i in indices {
		band_ticks << PlotAxisTick{
			position: band.center_at(i)
			text:     config.categories[i]
		}
	}
	return BarChartGeometry{
		plot:         plot
		legend:       legend
		legend_items: legend_items
		band:         band
		value:        value
		band_ticks:   band_ticks
		value_ticks:  value_ticks
		series:       series
		visible:      visible
		bars:         bars
		groups:       groups
		slots:        slots
		totals:       totals
		zero:         zero
		text:         sizes
		horizontal:   horizontal
	}
}

// bar_chart_bars is every bar the chart draws, fully grown, in the chart's
// coordinates: for hit-testing or for drawing something beside a bar.
pub fn bar_chart_bars(config BarChartConfig) ![]PlotBar {
	return bar_chart_geometry(config)!.bars
}

// bar_chart_grown is a bar as it stands `progress` of the way through the
// appear: every edge drawn toward the zero line by the same factor, so a stack
// grows as one piece.
fn bar_chart_grown(b PlotBar, alignment PlotBarAlignment, radius f64, zero f64, progress f64) PlotBar {
	if progress >= 1 {
		return b
	}
	base := zero + (b.base - zero) * progress
	tip := zero + (b.tip - zero) * progress
	horizontal := alignment.is_horizontal()
	cross := if horizontal { b.frame.y } else { b.frame.x }
	thickness := if horizontal { b.frame.height } else { b.frame.width }
	has_corners := b.corners.top_left + b.corners.top_right + b.corners.bottom_left +
		b.corners.bottom_right > 0
	return PlotBar{
		...b
		base:    base
		tip:     tip
		frame:   plot_bar_rect(alignment, cross, thickness, base, tip)
		corners: if has_corners {
			plot_tip_corners(alignment, radius, base, tip)
		} else {
			PlotCorners{}
		}
	}
}

pub fn bar_chart(config BarChartConfig) !Element {
	g := bar_chart_geometry(config)!
	plot := g.plot
	n := config.categories.len
	theme := config.theme
	progress, appear_marker := plot_appear(config.id, config.appear, config.appear_key, config.appear_duration,
		config.reduce_motion)
	mut children := []Element{}
	if config.grid || config.value_axis {
		children << plot_axis(PlotAxisConfig{
			id:            component_part_id(config.id, 'value-axis')
			plot:          plot
			orientation:   if g.horizontal { PlotAxisOrientation.bottom } else { .left }
			ticks:         g.value_ticks
			line:          false
			labels:        config.value_axis
			labels_inside: config.value_axis_inside
			grid:          config.grid
			grid_dashed:   config.grid_dashed
			label_size:    g.text.tick
			theme:         theme
		})!
	}
	if config.band_axis {
		children << plot_axis(PlotAxisConfig{
			id:          component_part_id(config.id, 'band-axis')
			plot:        plot
			orientation: match config.alignment {
				.bottom { PlotAxisOrientation.bottom }
				.top { .top }
				.left { .left }
				.right { .right }
			}
			ticks:       g.band_ticks
			line_offset: g.zero
			label_size:  g.text.tick
			theme:       theme
		})!
	}
	zero := g.zero + if g.horizontal { plot.x } else { plot.y }
	interactive := config.interactive && progress >= 1
	hovered := if interactive && config.hovered >= 0 && config.hovered < n {
		config.hovered
	} else {
		-1
	}
	highlight_id := component_part_id(config.id, 'highlight')
	card_id := component_part_id(config.id, 'tooltip')
	animate := !config.reduce_motion
	continues := plot_hover_continues(config.id, hovered >= 0)
	if hovered >= 0 && !continues {
		plot_glide_release(highlight_id)
		plot_glide_release(card_id)
	}
	if hovered >= 0 {
		group := g.groups[hovered]
		frame := if g.horizontal {
			rect(plot.x, group.y - 4, plot.width, group.height + 8)
		} else {
			rect(group.x - 4, plot.y, group.width + 8, plot.height)
		}
		children << plot_glide_element(view(highlight_id, frame, BoxStyle{
			bg:     plot_mix(theme.muted, theme.background, 0.15)
			radius: 6
		}, []Element{}), animate)
	}
	for b in g.bars {
		grown := bar_chart_grown(b, config.alignment, config.corner_radius, zero, progress)
		if grown.frame.width < 0.01 || grown.frame.height < 0.01 {
			continue
		}
		color := cartesian_color(g.series[b.series], b.index)
		children << shape(component_part_id(config.id, 'bar:${b.key}:${b.index}'), grown.frame,
			plot_rounded_rect_path(rect(0, 0, grown.frame.width, grown.frame.height), grown.corners),
			ShapeStyle{
				fill:         color
				fill_opacity: if hovered >= 0 && b.index != hovered { 0.45 } else { 1.0 }
			})
	}
	if config.value_labels && config.layout != .expand && progress >= 1 {
		children << bar_chart_value_labels(config, g)
	}
	if g.legend.width > 0 && g.legend.height > 0 {
		children << cartesian_legend(config.id, g.legend_items, g.legend, g.text.legend, config.legend_toggle
			&& config.interactive, theme)
	}
	if hovered >= 0 {
		title := bar_chart_title(config, hovered)
		rows := bar_chart_rows(config, g, hovered)
		w, h := cartesian_tooltip_size(title, rows, g.text.tooltip)
		area := rect(0, 0, config.frame.width, config.frame.height)
		group := g.groups[hovered]
		card := if g.horizontal && group.x + group.width + 10 + w > area.width {
			plot_tooltip_place(group, w, h, area, true)
		} else {
			plot_tooltip_place(group, w, h, area, false)
		}
		children << plot_glide_element(cartesian_tooltip(card_id, title, rows, card, g.text.tooltip,
			theme), animate)
	}
	if config.interactive && n > 0 {
		mut labels := []string{cap: n}
		for i in 0 .. n {
			rows := bar_chart_rows(config, g, i).map('${it.name} ${it.value}')
			labels << '${bar_chart_title(config, i)}: ${rows.join(', ')}'
		}
		children << cartesian_hover_bands(config.id, g.slots, labels)
	}
	children << appear_marker
	return cartesian_chart_view(config.id, config.frame, children, if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		'Bar chart'
	}, cartesian_summary(g.series, config.categories))
}

fn bar_chart_title(config BarChartConfig, index int) string {
	if voidptr(config.tooltip_title) != unsafe { nil } {
		return config.tooltip_title(index)
	}
	return if index < config.categories.len { config.categories[index] } else { '' }
}

fn bar_chart_rows(config BarChartConfig, g BarChartGeometry, index int) []CartesianTooltipRow {
	mut rows := []CartesianTooltipRow{}
	total := if index < g.totals.len { g.totals[index] } else { 0.0 }
	for s in g.visible {
		v := cartesian_value(s, index)
		mut value_text := bar_chart_value_text(config, v)
		if config.layout == .expand && plot_finite(v) && total != 0 {
			value_text += ' (${plot_format_percent(v / total)})'
		}
		rows << CartesianTooltipRow{
			color:       cartesian_color(s, index)
			name:        s.name
			value:       value_text
			value_color: cartesian_value_color(config.tooltip_value_color, s, index, v)
		}
	}
	if config.layout != .grouped && g.visible.len > 1 {
		rows << CartesianTooltipRow{
			name:  'Total'
			value: bar_chart_value_text(config, total)
		}
	}
	return rows
}

// bar_chart_value_labels writes each bar's value past its tip (each stack's
// total past its outermost segment).
fn bar_chart_value_labels(config BarChartConfig, g BarChartGeometry) []Element {
	style := TextStyle{
		color: config.theme.foreground
		size:  g.text.tick
	}
	height := plot_label_height(g.text.tick)
	positive := bar_chart_positive(config.alignment)
	mut out := []Element{}
	mut items := []PlotBar{}
	if config.layout == .grouped {
		items = g.bars.clone()
	} else {
		for j, total in g.totals {
			// The total goes past the stack's end on its side of zero.
			mut tip := 0.0
			mut base := 0.0
			mut found := false
			for b in g.bars {
				if b.index != j || (b.value < 0) != (total < 0) {
					continue
				}
				if !found || (b.tip - tip) * positive * (if total < 0 { -1.0 } else { 1.0 }) > 0 {
					tip = b.tip
					base = b.base
					found = true
				}
			}
			if found {
				items << PlotBar{
					index: j
					value: total
					frame: g.groups[j]
					base:  base
					tip:   tip
				}
			}
		}
	}
	for b in items {
		t := bar_chart_label_text(config, b.value)
		width := math.ceil(measure_text_width(t, style))
		// Away from the base, whichever way the bar points.
		outward := if b.tip >= b.base { 1.0 } else { -1.0 }
		f := if g.horizontal {
			x := if outward > 0 { b.tip + 4 } else { b.tip - 4 - width }
			rect(x, b.frame.y + b.frame.height / 2 - height / 2, width, height)
		} else {
			y := if outward > 0 { b.tip + 2 } else { b.tip - 2 - height }
			rect(b.frame.x + b.frame.width / 2 - width / 2, y, width, height)
		}
		out << label('', t, f, style)
	}
	return out
}
