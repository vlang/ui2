module ui2

import math

// The point charts, line_chart and area_chart: categories at evenly spaced
// points along x (a point scale), values up y (a linear scale).

enum PointChartKind {
	line
	area
}

// PlotAreaLayout is how an area chart's series share the plot.
pub enum PlotAreaLayout {
	overlap // every series from the baseline, drawn over the ones before it
	stacked // each series on top of the one before it
	expand  // stacked, as shares of each category's total (a 100% chart)
}

// PointChartSpec is what line_chart and area_chart have in common; each
// config converts to one.
struct PointChartSpec {
	kind                 PointChartKind
	id                   string
	frame                Rect
	categories           []string
	series               []PlotSeries
	hidden_series        []string
	curve                PlotCurve
	stroke_width         f64
	dots                 bool
	dot_size             f64
	area_layout          PlotAreaLayout
	fill_opacity         f64
	gradient             bool
	gradient_end_opacity f64
	hovered              int
	interactive          bool
	x_axis               bool
	y_axis               bool
	grid                 bool
	grid_columns         int
	grid_dashed          bool
	y_tick_count         int
	y_min                ?f64
	y_max                ?f64
	tick_margin          int
	x_tick_count         int
	point_count          int
	reference_lines      []f64
	y_axis_inside        bool
	y_tick_format        PlotFormatFn     = unsafe { nil }
	tooltip_title        PlotTitleFn      = unsafe { nil }
	tooltip_value_format PlotFormatFn     = unsafe { nil }
	tooltip_value_color  PlotValueColorFn = unsafe { nil }
	legend               PlotLegendPosition
	legend_toggle        bool
	margin               PlotMargin
	appear               bool
	appear_key           string
	appear_duration      f64
	reduce_motion        bool
	size                 ComponentSize
	theme                ComponentTheme
	accessibility_label  string
}

// PointChartGeometry is where everything of a point chart goes, in the
// chart's own coordinates: what tests check and what the builder draws.
struct PointChartGeometry {
	plot         Rect
	legend       Rect
	legend_items []CartesianLegendItem
	x            PlotPointScale  // 0 to plot.width
	y            PlotLinearScale // plot.height to 0
	x_ticks      []PlotAxisTick
	y_ticks      []PlotAxisTick
	series       []CartesianSeries
	visible      []CartesianSeries
	tops         [][]f64 // per visible series and category: the value of its upper edge
	bottoms      [][]f64 // per visible series: its lower edge when stacked
	stacked      bool
	text         CartesianText
}

fn point_chart_validate(spec PointChartSpec) ! {
	component_validate_id(spec.id)!
	component_validate_frame(spec.frame)!
	for name, value in {
		'stroke width':         spec.stroke_width
		'dot size':             spec.dot_size
		'fill opacity':         spec.fill_opacity
		'gradient end opacity': spec.gradient_end_opacity
		'appear duration':      spec.appear_duration
	} {
		if !plot_finite(value) || value < 0 {
			return error('chart ${name} must be finite and non-negative')
		}
	}
	if spec.y_tick_count < 2 || spec.y_tick_count > 20 {
		return error('chart y_tick_count must be 2 to 20')
	}
}

fn point_chart_y_format(spec PointChartSpec, decimals int) PlotFormatFn {
	if voidptr(spec.y_tick_format) != unsafe { nil } {
		return spec.y_tick_format
	}
	if spec.kind == .area && spec.area_layout == .expand {
		return plot_format_percent
	}
	return fn [decimals] (value f64) string {
		return plot_format_number(value, decimals)
	}
}

fn point_chart_value_text(spec PointChartSpec, value f64) string {
	if !plot_finite(value) {
		return '–'
	}
	if voidptr(spec.tooltip_value_format) != unsafe { nil } {
		return spec.tooltip_value_format(value)
	}
	// An expanded chart's ticks read shares; its values are not shares.
	if voidptr(spec.y_tick_format) != unsafe { nil }
		&& !(spec.kind == .area && spec.area_layout == .expand) {
		return spec.y_tick_format(value)
	}
	return plot_format_value(value)
}

fn point_chart_geometry(spec PointChartSpec) !PointChartGeometry {
	point_chart_validate(spec)!
	series := cartesian_series(spec.series, spec.hidden_series, spec.theme)!
	visible := cartesian_visible(series)
	n := spec.categories.len
	sizes := cartesian_text(spec.size)
	stacked := spec.kind == .area && spec.area_layout != .overlap
	mut tops := [][]f64{}
	mut bottoms := [][]f64{}
	if stacked {
		mut values := [][]f64{}
		for s in visible {
			values << []f64{len: n, init: cartesian_value(s, index)}
		}
		offset := if spec.area_layout == .expand { PlotStackOffset.expand } else { .none }
		for layer in plot_stack(visible.map(it.key), values, offset) {
			tops << layer.points.map(it.y1)
			bottoms << layer.points.map(it.y0)
		}
	} else {
		for s in visible {
			tops << []f64{len: n, init: cartesian_value(s, index)}
		}
	}
	mut domain_values := []f64{}
	for row in tops {
		domain_values << row
	}
	for row in bottoms {
		domain_values << row
	}
	mut y := if stacked && spec.area_layout == .expand {
		plot_linear_scale(0, 1, 0, 1)
	} else {
		plot_value_scale(domain_values, spec.y_min, spec.y_max, spec.y_tick_count)
	}
	// Tick values do not depend on the range, so the labels can be measured
	// before the plot is laid out past them.
	tick_values := y.ticks(spec.y_tick_count)
	format := point_chart_y_format(spec, plot_tick_decimals(y.tick_step(spec.y_tick_count)))
	tick_style := TextStyle{
		size: sizes.tick
	}
	mut y_texts := []string{cap: tick_values.len}
	mut gutter := 0.0
	for value in tick_values {
		t := format(value)
		y_texts << t
		gutter = math.max(gutter, math.ceil(measure_text_width(t, tick_style)))
	}
	if spec.y_axis && !spec.y_axis_inside {
		gutter += 6
	} else {
		gutter = 0
	}
	legend_items := cartesian_legend_items(series)
	legend_shown := cartesian_legend_shown(spec.legend, series.len)
	legend_width := math.max(0.0, spec.frame.width - spec.margin.left - spec.margin.right)
	_, legend_height := if legend_shown {
		cartesian_legend_frames(legend_items, legend_width, sizes.legend)
	} else {
		[]Rect{}, 0.0
	}
	legend_top := legend_shown && spec.legend == .top
	label_height := plot_label_height(sizes.tick)
	mut top := spec.margin.top + if spec.y_axis && !spec.y_axis_inside {
		label_height / 2
	} else {
		2.0
	}
	if legend_top {
		top += legend_height + 8
	}
	mut bottom := spec.margin.bottom
	if spec.x_axis {
		bottom += 6 + label_height
	}
	if legend_shown && !legend_top {
		bottom += legend_height + 10
	}
	left := spec.margin.left + gutter
	plot := rect(left, top, math.max(0.0, spec.frame.width - left - spec.margin.right),
		math.max(0.0, spec.frame.height - top - bottom))
	legend := if legend_top {
		rect(spec.margin.left, spec.margin.top, legend_width, legend_height)
	} else if legend_shown {
		rect(spec.margin.left, spec.frame.height - spec.margin.bottom - legend_height,
			legend_width, legend_height)
	} else {
		Rect{}
	}
	x := PlotPointScale{
		domain:      spec.categories
		range_start: 0
		range_end:   plot.width
		count:       spec.point_count
	}
	y = y.with_range(plot.height, 0)
	mut y_ticks := []PlotAxisTick{cap: tick_values.len}
	for i, value in tick_values {
		y_ticks << PlotAxisTick{
			position: y.position(value)
			text:     y_texts[i]
		}
	}
	indices := if spec.x_tick_count > 0 {
		plot_spread_indices(x.point_count(), spec.x_tick_count).filter(it < n)
	} else {
		stride := if spec.tick_margin > 0 {
			spec.tick_margin
		} else {
			plot_label_stride(spec.categories, x.step(), tick_style, 12)
		}
		[]int{len: n, init: index}.filter(it % stride == 0)
	}
	return PointChartGeometry{
		plot:         plot
		legend:       legend
		legend_items: legend_items
		x:            x
		y:            y
		x_ticks:      plot_point_ticks_at(x, indices)
		y_ticks:      y_ticks
		series:       series
		visible:      visible
		tops:         tops
		bottoms:      bottoms
		stacked:      stacked
		text:         sizes
	}
}

// point_chart_points are a series' points in bleed-frame coordinates.
fn point_chart_points(g PointChartGeometry, values []f64) []PathPoint {
	mut points := []PathPoint{cap: values.len}
	for i, value in values {
		points << path_point(g.x.position_at(i) + plot_bleed, if plot_finite(value) {
			g.y.position(value) + plot_bleed
		} else {
			math.nan()
		})
	}
	return points
}

// point_chart_hover_frames are the hover bands, one per category, each
// reaching halfway to its neighbors, in chart coordinates.
fn point_chart_hover_frames(g PointChartGeometry, n int) []Rect {
	mut frames := []Rect{cap: n}
	half := math.abs(g.x.step()) / 2
	for i in 0 .. n {
		center := g.x.position_at(i)
		x0 := if n == 1 { 0.0 } else { math.max(0.0, center - half) }
		x1 := if n == 1 { g.plot.width } else { math.min(g.plot.width, center + half) }
		frames << rect(g.plot.x + x0, g.plot.y, math.max(0.0, x1 - x0), g.plot.height)
	}
	return frames
}

// point_chart_fade_path is one horizontal slice of a fill polygon, between
// y0 and y1 in bleed-frame coordinates: the fill drawn with fading opacity.
fn point_chart_fade_path(contours []PathContour, y0 f64, y1 f64) []PathCommand {
	mut path := []PathCommand{}
	for contour in contours {
		clipped := plot_clip_polygon_y(contour.points, y0, y1)
		if clipped.len >= 3 {
			path << path_polyline(clipped, true)
		}
	}
	return path
}

// plot_fade_slices is how many slices an area's fade is drawn in: about one
// every 6 points of the plot's height, so neighbors differ by too little
// opacity to show a step.
fn plot_fade_slices(height f64) int {
	return int(math.max(8, math.min(32, math.ceil(height / 6))))
}

fn point_chart(spec PointChartSpec) !Element {
	g := point_chart_geometry(spec)!
	plot := g.plot
	n := spec.categories.len
	theme := spec.theme
	progress, appear_marker := plot_appear(spec.id, spec.appear, spec.appear_key, spec.appear_duration,
		spec.reduce_motion)
	mut children := []Element{}
	if spec.grid || spec.y_axis {
		children << plot_axis(PlotAxisConfig{
			id:            component_part_id(spec.id, 'y-axis')
			plot:          plot
			orientation:   .left
			ticks:         g.y_ticks
			line:          false
			labels:        spec.y_axis
			labels_inside: spec.y_axis_inside
			grid:          spec.grid
			grid_dashed:   spec.grid_dashed
			label_size:    g.text.tick
			theme:         theme
		})!
	}
	if spec.grid && spec.grid_columns > 0 {
		children << shape(component_part_id(spec.id, 'grid-columns'), plot, plot_columns_path(spec.grid_columns,
			plot.width, plot.height, spec.grid_dashed), ShapeStyle{
			stroke:   plot_grid_color(theme)
			line_cap: .butt
		})
	}
	// The baseline sits on zero, which is the bottom edge unless values go
	// below it.
	zero := math.max(0.0, math.min(plot.height, g.y.position(0)))
	if spec.x_axis {
		children << plot_axis(PlotAxisConfig{
			id:          component_part_id(spec.id, 'x-axis')
			plot:        plot
			orientation: .bottom
			ticks:       g.x_ticks
			line_offset: if spec.kind == .area { zero } else { plot.height }
			label_size:  g.text.tick
			theme:       theme
		})!
	}
	frame := plot_bleed_frame(plot)
	// How far the series have drawn in from the left, in bleed coordinates.
	cut := if progress < 1 {
		plot_bleed + plot.width * progress
	} else {
		plot.width + 2 * plot_bleed
	}
	// Every fill first, then every line, then the dots, so a later series'
	// fill does not wash out an earlier one's line.
	mut fills := []Element{}
	mut lines := []Element{}
	mut dots := []Element{}
	for si, s in g.visible {
		top_points := point_chart_points(g, g.tops[si])
		mut top_path := plot_line_path(top_points, spec.curve)
		if progress < 1 {
			top_path = plot_path_clip_right(top_path, cut)
		}
		if spec.kind == .area && top_path.len > 0 {
			fill_path := if g.stacked {
				mut bottom_path := plot_line_path(point_chart_points(g, g.bottoms[si]),
					spec.curve)
				if progress < 1 {
					bottom_path = plot_path_clip_right(bottom_path, cut)
				}
				plot_close_between(top_path, bottom_path)
			} else {
				plot_close_to_baseline(top_path, zero + plot_bleed)
			}
			if spec.gradient {
				contours := path_flatten(fill_path, 0.5)
				span := plot.height + 2 * plot_bleed
				count := plot_fade_slices(span)
				for k in 0 .. count {
					y0 := span * f64(k) / f64(count)
					y1 := span * f64(k + 1) / f64(count)
					slice := point_chart_fade_path(contours, y0, y1)
					if slice.len == 0 {
						continue
					}
					t := (f64(k) + 0.5) / f64(count)
					fills << shape(component_part_id(spec.id, 'area:${s.key}:fade${k}'), frame,
						slice, ShapeStyle{
							fill:         s.color
							fill_opacity: spec.fill_opacity +
								(spec.gradient_end_opacity - spec.fill_opacity) * t
						})
				}
			} else {
				fills << shape(component_part_id(spec.id, 'area:${s.key}'), frame, fill_path,
					ShapeStyle{
						fill:         s.color
						fill_opacity: spec.fill_opacity
					})
			}
		}
		if top_path.len > 0 && spec.stroke_width > 0 {
			part := if spec.kind == .area { 'area-line:${s.key}' } else { 'line:${s.key}' }
			lines << shape(component_part_id(spec.id, part), frame, top_path, ShapeStyle{
				stroke:       s.color
				stroke_width: spec.stroke_width
			})
		}
		if spec.dots && spec.dot_size > 0 {
			dot_path := plot_dot_path(top_points.filter(it.x <= cut), spec.dot_size / 2)
			if dot_path.len > 0 {
				dots << shape(component_part_id(spec.id, 'dots:${s.key}'), frame, dot_path,
					ShapeStyle{
						fill:         s.color
						stroke:       theme.background
						stroke_width: 1.5
					})
			}
		}
	}
	children << fills
	children << lines
	children << dots
	// A reference line outside the y axis (one that is pinned) is not drawn.
	unclamped := g.y.with_clamp(false)
	mut rows := []f64{}
	for value in spec.reference_lines {
		if plot_finite(value) {
			position := unclamped.position(value)
			if position >= -0.5 && position <= plot.height + 0.5 {
				rows << position
			}
		}
	}
	if rows.len > 0 {
		children << shape(component_part_id(spec.id, 'reference'), frame, plot_reference_path(rows,
			plot.width), ShapeStyle{
			stroke:   theme.muted_foreground
			line_cap: .butt
		})
	}
	if g.legend.width > 0 && g.legend.height > 0 {
		children << cartesian_legend(spec.id, g.legend_items, g.legend, g.text.legend, spec.legend_toggle
			&& spec.interactive, theme)
	}
	children << point_chart_overlay(spec, g, progress)
	if spec.interactive && n > 0 {
		children << cartesian_hover_bands(spec.id, point_chart_hover_frames(g, n), point_chart_band_labels(spec,
			g))
	}
	children << appear_marker
	return cartesian_chart_view(spec.id, spec.frame, children, if spec.accessibility_label.len > 0 {
		spec.accessibility_label
	} else if spec.kind == .area {
		'Area chart'
	} else {
		'Line chart'
	}, cartesian_summary(g.series, spec.categories))
}

fn point_chart_title(spec PointChartSpec, index int) string {
	if voidptr(spec.tooltip_title) != unsafe { nil } {
		return spec.tooltip_title(index)
	}
	return if index < spec.categories.len { spec.categories[index] } else { '' }
}

fn point_chart_rows(spec PointChartSpec, g PointChartGeometry, index int) []CartesianTooltipRow {
	mut rows := []CartesianTooltipRow{}
	mut total := 0.0
	for s in g.visible {
		value := cartesian_value(s, index)
		if plot_finite(value) {
			total += value
		}
		rows << CartesianTooltipRow{
			color:       s.color
			name:        s.name
			value:       point_chart_value_text(spec, value)
			value_color: cartesian_value_color(spec.tooltip_value_color, s, index, value)
		}
	}
	if g.stacked && g.visible.len > 1 {
		rows << CartesianTooltipRow{
			name:  'Total'
			value: point_chart_value_text(spec, total)
		}
	}
	return rows
}

fn point_chart_band_labels(spec PointChartSpec, g PointChartGeometry) []string {
	mut labels := []string{cap: spec.categories.len}
	for i in 0 .. spec.categories.len {
		rows := point_chart_rows(spec, g, i).map('${it.name} ${it.value}')
		labels << '${point_chart_title(spec, i)}: ${rows.join(', ')}'
	}
	return labels
}

// point_chart_overlay is the crosshair, the dot on each series and the
// tooltip card for the hovered category, once the data has drawn in.
fn point_chart_overlay(spec PointChartSpec, g PointChartGeometry, progress f64) []Element {
	crosshair_id := component_part_id(spec.id, 'crosshair')
	card_id := component_part_id(spec.id, 'tooltip')
	index := spec.hovered
	shown := spec.interactive && index >= 0 && index < spec.categories.len && progress >= 1
	continues := plot_hover_continues(spec.id, shown)
	if !shown {
		return []Element{}
	}
	if !continues {
		// Back after a while: the marks appear in place.
		plot_glide_release(crosshair_id)
		plot_glide_release(card_id)
		for s in g.series {
			plot_glide_release(component_part_id(spec.id, 'halo:${s.key}'))
			plot_glide_release(component_part_id(spec.id, 'dot:${s.key}'))
		}
	}
	animate := !spec.reduce_motion
	theme := spec.theme
	plot := g.plot
	x := plot.x + g.x.position_at(index)
	mut out := []Element{}
	out << plot_glide_element(view(crosshair_id, rect(math.floor(x), plot.y, 1, plot.height),
		BoxStyle{
			bg: plot_mix(theme.border, theme.foreground, 0.3)
		}, []Element{}), animate)
	mut min_y := math.max_f64
	mut max_y := -math.max_f64
	for si, s in g.visible {
		value := g.tops[si][index]
		halo_id := component_part_id(spec.id, 'halo:${s.key}')
		dot_id := component_part_id(spec.id, 'dot:${s.key}')
		if !plot_finite(value) {
			plot_glide_release(halo_id)
			plot_glide_release(dot_id)
			continue
		}
		y := plot.y + g.y.position(value)
		min_y = math.min(min_y, y)
		max_y = math.max(max_y, y)
		out << plot_glide_element(shape(halo_id, rect(x - 10, y - 10, 20, 20), path_circle(10,
			10, 10), ShapeStyle{
			fill:         s.color
			fill_opacity: 0.2
		}), animate)
		out << plot_glide_element(shape(dot_id, rect(x - 6, y - 6, 12, 12), path_circle(6, 6,
			4), ShapeStyle{
			fill:         s.color
			stroke:       theme.background
			stroke_width: 2
		}), animate)
	}
	for s in g.series {
		if s.hidden {
			plot_glide_release(component_part_id(spec.id, 'halo:${s.key}'))
			plot_glide_release(component_part_id(spec.id, 'dot:${s.key}'))
		}
	}
	if min_y > max_y {
		min_y = plot.y + plot.height / 2
		max_y = min_y
	}
	title := point_chart_title(spec, index)
	rows := point_chart_rows(spec, g, index)
	w, h := cartesian_tooltip_size(title, rows, g.text.tooltip)
	anchor := rect(x - 8, min_y - 8, 16, max_y - min_y + 16)
	card := plot_tooltip_place(anchor, w, h, rect(0, 0, spec.frame.width, spec.frame.height),
		false)
	out << plot_glide_element(cartesian_tooltip(card_id, title, rows, card, g.text.tooltip,
		theme), animate)
	return out
}
