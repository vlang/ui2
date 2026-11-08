module ui2

// LineChartConfig describes GPUI Kit's LineChart: one line per series through
// the categories, with axes, grid lines, a legend, and a crosshair and tooltip
// for the hovered category.
pub struct LineChartConfig {
pub:
	id         string // Required: the series, hover bands and motion are keyed on it.
	frame      Rect
	categories []string // The x values, one point each.
	series     []PlotSeries
	// hidden_series are keys of series left out, as a legend toggle hides
	// them; they keep their color slot and legend item.
	hidden_series []string
	curve         PlotCurve = .smooth
	stroke_width  f64       = 2
	dots          bool // A dot on every point.
	dot_size      f64 = 7
	// hovered is the category the pointer is over, from plot_hover_from_event;
	// -1 is none.
	hovered int = -1
	// interactive false leaves out the hover layer, the tooltip and legend
	// toggling: for a chart that only decorates, or one drawn under something
	// else. The chart still draws in.
	interactive  bool = true
	x_axis       bool = true
	y_axis       bool = true // Tick labels left of the plot.
	grid         bool = true // Horizontal grid lines at the y ticks.
	grid_columns int // Vertical grid lines dividing the plot into this many columns.
	grid_dashed  bool
	y_tick_count int = 5 // About this many y ticks, at round values.
	// y_min and y_max pin the y axis; by default it fits the data from zero,
	// rounded out to the ticks. Pinned values outside it stop at the plot's edge.
	y_min ?f64
	y_max ?f64
	// tick_margin labels every n-th category; 0 picks the stride that keeps
	// the labels apart.
	tick_margin int
	// x_tick_count labels this many categories spread from the first to the
	// last instead.
	x_tick_count int
	// point_count lays the x axis out for more points than there are
	// categories, so a series still in progress fills only the leading part.
	point_count     int
	reference_lines []f64 // Dashed lines across the plot at these values.
	// y_axis_inside draws the y tick labels over the plot beside their grid
	// lines instead of in a gutter (GPUI Kit's AxisLabelPlacement::Inside).
	y_axis_inside bool
	y_tick_format PlotFormatFn = unsafe { nil }
	// tooltip_title and tooltip_value_format write the tooltip's title and
	// values; by default the category and the value as y ticks write it.
	tooltip_title        PlotTitleFn  = unsafe { nil }
	tooltip_value_format PlotFormatFn = unsafe { nil }
	// tooltip_value_color colors each tooltip value, such as by its sign.
	tooltip_value_color PlotValueColorFn = unsafe { nil }
	legend              PlotLegendPosition
	// legend_toggle makes legend items buttons that emit
	// component_part_id(id, 'legend:<index>'); decode them with
	// plot_legend_key_from_action and update hidden_series.
	legend_toggle bool
	margin        PlotMargin
	// appear draws the lines in from the left the first time the chart is
	// built, over appear_duration seconds; appear_key replays it when changed.
	appear          bool = true
	appear_key      string
	appear_duration f64 = 1.0
	// reduce_motion shows everything in place: no appear, no gliding.
	reduce_motion       bool
	size                ComponentSize = .medium
	theme               ComponentTheme
	accessibility_label string
}

pub fn line_chart(config LineChartConfig) !Element {
	return point_chart(PointChartSpec{
		kind:                 .line
		id:                   config.id
		frame:                config.frame
		categories:           config.categories
		series:               config.series
		hidden_series:        config.hidden_series
		curve:                config.curve
		stroke_width:         config.stroke_width
		dots:                 config.dots
		dot_size:             config.dot_size
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
