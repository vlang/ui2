module ui2

// AreaChartConfig describes GPUI Kit's AreaChart: each series filled down to
// the baseline (overlapping), or stacked on the ones before it, with an
// optional fade from the top of the plot to the baseline.
pub struct AreaChartConfig {
pub:
	id            string // Required: the series, hover bands and motion are keyed on it.
	frame         Rect
	categories    []string
	series        []PlotSeries
	hidden_series []string
	layout        PlotAreaLayout = .overlap
	curve         PlotCurve      = .smooth
	stroke_width  f64            = 2 // The line along each area's top; 0 draws none.
	fill_opacity  f64            = 0.35
	// gradient fades each fill from fill_opacity at the top of the plot to
	// gradient_end_opacity at its bottom, drawn as horizontal slices of
	// stepped opacity (shapes have one fill color each).
	gradient             bool
	gradient_end_opacity f64 = 0.04
	dots                 bool
	dot_size             f64  = 7
	hovered              int  = -1 // From plot_hover_from_event; -1 is none.
	interactive          bool = true
	x_axis               bool = true
	y_axis               bool = true
	grid                 bool = true
	grid_columns         int
	grid_dashed          bool
	y_tick_count         int = 5
	y_min                ?f64 // Pin the y axis (overlap and stacked layouts).
	y_max                ?f64
	tick_margin          int
	x_tick_count         int
	point_count          int
	reference_lines      []f64
	y_axis_inside        bool // The y tick labels over the plot, not in a gutter.
	y_tick_format        PlotFormatFn     = unsafe { nil }
	tooltip_title        PlotTitleFn      = unsafe { nil }
	tooltip_value_format PlotFormatFn     = unsafe { nil }
	tooltip_value_color  PlotValueColorFn = unsafe { nil }
	legend               PlotLegendPosition
	legend_toggle        bool
	margin               PlotMargin
	appear               bool = true
	appear_key           string
	appear_duration      f64 = 1.0
	reduce_motion        bool
	size                 ComponentSize = .medium
	theme                ComponentTheme
	accessibility_label  string
}

pub fn area_chart(config AreaChartConfig) !Element {
	return point_chart(PointChartSpec{
		kind:                 .area
		id:                   config.id
		frame:                config.frame
		categories:           config.categories
		series:               config.series
		hidden_series:        config.hidden_series
		curve:                config.curve
		stroke_width:         config.stroke_width
		dots:                 config.dots
		dot_size:             config.dot_size
		area_layout:          config.layout
		fill_opacity:         config.fill_opacity
		gradient:             config.gradient
		gradient_end_opacity: config.gradient_end_opacity
		hovered:              config.hovered
		interactive:          config.interactive
		x_axis:               config.x_axis
		y_axis:               config.y_axis
		grid:                 config.grid
		grid_columns:         config.grid_columns
		grid_dashed:          config.grid_dashed
		y_tick_count:         config.y_tick_count
		y_min:                config.y_min
		y_max:                config.y_max
		tick_margin:          config.tick_margin
		x_tick_count:         config.x_tick_count
		point_count:          config.point_count
		reference_lines:      config.reference_lines
		y_axis_inside:        config.y_axis_inside
		y_tick_format:        config.y_tick_format
		tooltip_title:        config.tooltip_title
		tooltip_value_format: config.tooltip_value_format
		tooltip_value_color:  config.tooltip_value_color
		legend:               config.legend
		legend_toggle:        config.legend_toggle
		margin:               config.margin
		appear:               config.appear
		appear_key:           config.appear_key
		appear_duration:      config.appear_duration
		reduce_motion:        config.reduce_motion
		size:                 config.size
		theme:                config.theme
		accessibility_label:  config.accessibility_label
	})
}
