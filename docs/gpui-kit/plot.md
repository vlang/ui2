# Plot and cartesian charts: scales, shapes, axes, line, bar and area charts

This group ports GPUI Kit's
[Plot](https://github.com/longbridge/gpui-kit/blob/main/website/component/plot.md)
module and the cartesian charts of its
[Chart](https://github.com/longbridge/gpui-kit/blob/main/website/component/chart.md)
page: `LineChart`, `BarChart` and `AreaChart`. Pie, radar, candlestick and sankey
charts are not part of this group (the pie and arc generators they need are).

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `ScaleLinear` | `PlotLinearScale`, `plot_linear_scale` | `ui/component_plot_scale.v` |
| `ScaleBand` | `PlotBandScale`, `plot_band_scale` | `ui/component_plot_scale.v` |
| `ScalePoint` | `PlotPointScale`, `plot_point_scale` | `ui/component_plot_scale.v` |
| `ScaleOrdinal` | `PlotOrdinalScale`, `plot_color_scale` | `ui/component_plot_scale.v` |
| `Bar`, `BarAlignment` | `plot_bar_rect`, `plot_rounded_rect_path`, `plot_tip_corners`, `PlotBarAlignment` | `ui/component_plot_shape.v` |
| `Line`, `Area`, `Curve` | `plot_line_path`, `plot_area_path`, `plot_band_area_path`, `PlotCurve` | `ui/component_plot_shape.v` |
| `Pie`, `Arc` | `plot_pie`, `plot_arc_path`, `plot_arc_centroid` | `ui/component_plot_shape.v` |
| `Stack` | `plot_stack`, `PlotStackOffset` | `ui/component_plot_shape.v` |
| `PlotAxis`, `Grid`, `AxisText` | `plot_axis(PlotAxisConfig)`, `PlotAxisTick` | `ui/component_plot_axis.v` |
| `chart.1` … `chart.5`, `chart.grid` | `plot_chart_palette`, `plot_chart_color`, `plot_grid_color` | `ui/component_plot.v` |
| `LineChart` | `line_chart(LineChartConfig)` | `ui/component_charts_cartesian_line.v` |
| `BarChart` | `bar_chart(BarChartConfig)`, `bar_chart_bars` | `ui/component_charts_cartesian_bar.v` |
| `AreaChart` | `area_chart(AreaChartConfig)` | `ui/component_charts_cartesian_area.v` |
| hover, `Tooltip`, legend, motion | `plot_hover_from_event`, `plot_legend_key_from_action`, `plot_toggle_hidden` | `ui/component_charts_cartesian.v` |

The two point charts share `ui/component_charts_cartesian_point.v`. Tests are in
`ui/component_plot_test.v`, and `examples/gpui_plot/main.v` is a dashboard of
every chart, a bar chart built by hand from the primitives and a donut from the
pie generator, with a light/dark toggle:

```sh
v run examples/gpui_plot/main.v
v -d ui2_custom_rendering run examples/gpui_plot/main.v
UI2_PLOT_DARK=1 UI2_PLOT_HOVER=1 v run examples/gpui_plot/main.v  # dark, more charts hovered
```

Everything is drawn with ui2's vector `shape` element, so lines and curves are
antialiased paths on every backend (the older `chart()` in `ui/chart.v` is kept
unchanged). Every shape gets a stable id derived from the chart's id, so the
custom renderer keeps its triangles between frames.

## The plot module

Everything here is a pure function or value type: scales map data to positions,
shape generators turn positions into paths and frames, and `plot_axis` draws an
axis. Draw what they return with `shape`, `view` and `label`.

### Scales

```v
// Values up a plot 200 tall: 0 at the bottom, rounded out to round ticks.
y := ui2.plot_linear_scale(0, 186, 200, 0).nice(5) // domain 0..200
y.position(100) // 100.0
y.invert(50)    // 150.0
y.ticks(5)      // [0, 50, 100, 150, 200]
y.with_clamp(true).position(300) // 0.0, the edge

// Categories as bands across 300, d3's padding semantics.
x := ui2.plot_band_scale(['A', 'B', 'C'], 0, 300).with_padding(0.1, 0.1)
x.bandwidth()   // the width of each band
x.position('A')? // where band A starts
x.center_at(2)  // the middle of band C
x.nearest_index(140) // the band under a pointer

// Evenly spaced points, first and last on the ends (line charts).
p := ui2.plot_point_scale(['Jan', 'Feb', 'Mar'], 0, 300) // 0, 150, 300

// Colors per key from the theme's chart palette.
colors := ui2.plot_color_scale(['desktop', 'mobile'], theme)
colors.get('mobile')? // the second palette color
```

- `PlotLinearScale{domain_min, domain_max, range_start, range_end, clamp}`:
  `position`, `invert`, `ticks(count)` (round values, d3's 1-2-5 steps, exact
  decimals), `tick_step(count)`, `nice(count)`, `with_range`, `with_clamp`.
  `plot_tick_step(start, stop, count)` and `plot_extent(values, include)` help
  build domains; NaN and infinite values are ignored.
- `PlotBandScale{domain, range_start, range_end, padding_inner, padding_outer,
  align, count, max_bandwidth}`: `step`, `bandwidth`, `position(value)`,
  `position_at(i)`, `center_at(i)`, `index_of`, `nearest_index`, `band_count`.
  `count` reserves bands for data still to come (upstream `band_count`), and a
  band capped by `max_bandwidth` stays centered in its slot. A backwards range
  lays the bands out backwards. `plot_band_scale` drops repeated values.
- `PlotPointScale{domain, range_start, range_end, padding, align, count}`:
  `step`, `position`, `position_at`, `nearest_index`, `point_count`; a single
  point sits in the middle, and `count` lays the axis out for points to come
  (upstream `point_count`).
- `PlotOrdinalScale{domain, range, unknown}`: `get(value) ?u32`, repeating the
  range for longer domains.

### Colors and numbers

`plot_chart_palette(theme)` is the chart palette of a `ComponentTheme`: eight
categorical hues in a fixed order validated for color-blind separation, with
separate steps for light and dark surfaces (`plot_theme_is_dark` decides by the
background's luminance). `plot_chart_color(theme, i)` is slot `i`;
`plot_grid_color(theme)` is the recessive hairline of grid lines. Upstream's
default theme ships five shades of one blue; ui2 has no chart colors in
`ComponentTheme`, so the palette lives here and widens to hues that stay apart
when several series share a chart.

`plot_format_number(value, decimals)` writes `1,284.50`; `plot_format_compact`
writes `950`, `12.9K`, `4.2M`; `plot_format_percent(0.25)` writes `25%`;
`plot_format_value` is the default tooltip text; `plot_tick_decimals(step)` is
how many decimals ticks that far apart need. `PlotFormatFn` is
`fn (value f64) string`, used wherever a chart writes a value.

### Shapes

```v
// A bar standing on a baseline at y 180, its tip rounded.
r := ui2.plot_bar_rect(.bottom, x.position_at(0), x.bandwidth(), 180, y.position(120))
bar := ui2.shape('bar', r, ui2.plot_rounded_rect_path(ui2.rect(0, 0, r.width, r.height),
	ui2.plot_tip_corners(.bottom, 4, 180, y.position(120))), ui2.ShapeStyle{ fill: color })

// A smooth line and the area under it.
line := ui2.plot_line_path(points, .smooth)
area := ui2.plot_area_path(points, baseline, .smooth)
layer := ui2.plot_band_area_path(upper_points, lower_points, .linear)
```

- Bars: `plot_bar_rect(alignment, cross, thickness, base, tip)`,
  `plot_bar_tip(base, tip, min_length, value, positive)` (a minimum length that
  grows away from zero, as upstream's `min_length`), `PlotCorners`,
  `plot_corners(r)`, `plot_tip_corners(alignment, r, base, tip)` and
  `plot_rounded_rect_path(rect, corners)` (each corner its own radius).
- Lines and areas: `PlotCurve` is `.smooth` (a monotone cubic through the
  points that never overshoots them, `path_smooth`), `.linear`, `.step_after`,
  `.step_before` or `.step`. `plot_line_path` breaks the line at a point with a
  NaN coordinate. `plot_area_path` closes down to a baseline,
  `plot_band_area_path` between two series.
- Path tools: `plot_path_reverse`, `plot_path_clip_right(path, x)` (how lines
  draw in from the left; curves are split exactly at x) and
  `plot_clip_polygon_y(points, y0, y1)` (the slice of a polygon between two
  heights, how area fills fade).
- Pies: `plot_pie(values, start_angle:, end_angle:, pad_angle:)` returns a
  `PlotArc` per positive value with d3's angles (0 at 12 o'clock, clockwise),
  the pad included in each span. `plot_arc_path(arc, cx, cy, inner, outer)`
  draws a slice or a ring segment with the pad taken out as a gap of even width
  (d3's pad radius); `plot_arc_centroid` is where its label goes.
- Stacks: `plot_stack(keys, values, offset)` stacks `values[series][column]`
  into `PlotStackSeries{key, index, points}` of `PlotStackPoint{y0, y1, value}`.
  `PlotStackOffset` is `.none` (each series on the one before), `.expand`
  (shares of the column total, a 100% stack) or `.diverging` (positive values up
  from zero, negative ones down). Missing values count as zero.
  `plot_stack_extent` is the value range a stack covers.

### Axes

```v
ui2.plot_axis(
	id:          'sales:y'
	plot:        plot // the plot area in the parent's coordinates
	orientation: .left
	ticks:       ui2.plot_linear_ticks(y, 5, ui2.plot_format_compact)
	line:        false
	grid:        true
	theme:       theme
)!
```

`plot_axis` returns one transparent view over the plot and the room its labels
take: the axis line (moved by `line_offset`, such as onto a zero line), tick
marks (`tick_size`), labels measured with `measure_text_width` and placed by
each tick's `PlotTickAlign`, and grid lines across the plot (`grid`,
`grid_dashed`). Orientation is `.bottom`, `.left`, `.top` or `.right`.
`labels_inside` draws a left or right axis' labels over the plot beside their
grid lines (upstream `AxisLabelPlacement::Inside`). `plot_axis_size` is how
much room an axis takes outside the plot, `plot_axis_frame` the element's
frame and `plot_axis_label_frames` where its labels go, so a chart can be laid
out before it is drawn. Hairlines are drawn on pixel centers, so a grid line
and another axis' line at the same position share one pixel row.

Tick helpers: `plot_linear_ticks(scale, count, format)`,
`plot_band_ticks(scale, stride)`, `plot_point_ticks(scale, stride)` (the end
labels aligned inward, as upstream does), `plot_point_ticks_at(scale,
indices)`, `plot_spread_indices(count, labels)` (upstream's `x_tick_count`) and
`plot_label_stride(texts, spacing, style, gap)` (the smallest stride that keeps
measured labels apart).

### A custom bar chart

The upstream "Custom Bar Chart Implementation", a stacked bar chart from the
primitives (`custom_bar_chart` in the example):

```v
stack := ui2.plot_stack(['desktop', 'mobile'], [desktop, mobile], .none)
_, top := ui2.plot_stack_extent(stack)
x := ui2.PlotBandScale{
	domain:        days
	range_end:     plot.width
	padding_inner: 0.35
	padding_outer: 0.2
}
y := ui2.plot_linear_scale(0, top, plot.height, 0).nice(4)
mut children := [
	ui2.plot_axis(id: 'custom:y', plot: plot, orientation: .left, line: false, grid: true,
		ticks: ui2.plot_linear_ticks(y, 4, unsafe { nil }), theme: theme)!,
	ui2.plot_axis(id: 'custom:x', plot: plot, ticks: ui2.plot_band_ticks(x, 1), theme: theme)!,
]
colors := ui2.plot_color_scale(['desktop', 'mobile'], theme)
for layer in stack {
	for i, p in layer.points {
		r := ui2.plot_bar_rect(.bottom, plot.x + x.position_at(i), x.bandwidth(),
			plot.y + y.position(p.y0), plot.y + y.position(p.y1))
		children << ui2.shape('custom:bar:${layer.key}:${i}', r, ui2.path_rect(ui2.rect(0, 0,
			r.width, r.height)), ui2.ShapeStyle{ fill: colors.get(layer.key)? })
	}
}
```

## Charts

The three charts take data as categories and series, the way ui2 components
take plain values instead of closures over the application's records:

```v
ui2.PlotSeries{
	key:    'desktop' // identity: ids, color slot, legend toggling
	name:   'Desktop' // legend and tooltip; defaults to the key
	values: [186.0, 305, 237] // one per category, NaN for a missing value
	color:  none      // defaults to the palette slot of the series' position
	colors: []        // bar charts: a color per category (upstream's fill closure)
}
```

What they share:

- **Layout.** `frame` holds the whole chart: value-axis labels in a gutter
  measured to fit them, category labels below, the legend, and `margin`
  (`PlotMargin{top, right, bottom, left}`) inside the frame. Category labels
  thin themselves out when they would overlap; `tick_margin` labels every
  n-th instead and `x_tick_count` / `band_tick_count` labels that many spread
  from the first to the last.
- **Value axis.** By default it fits the data from zero and is rounded out to
  about `y_tick_count` (`value_tick_count`) round ticks. `y_min`/`y_max`
  (`value_min`/`value_max`) pin it, and values outside stop at the plot's edge.
  `y_tick_format` (`value_format`) writes the labels; `y_axis_inside`
  (`value_axis_inside`) puts them over the plot.
- **Theme.** `theme: ui2.component_theme(dark)`; series take the palette by
  position, grid lines `plot_grid_color`, text the theme's foregrounds, the
  tooltip card the background, border and popup shadow. `size` picks 10–12
  point tick labels.
- **Legend.** Shown at the bottom for two series or more (`legend: .top`,
  `.bottom`, `.hidden`). With `legend_toggle: true` each item is a checkbox
  button emitting `component_part_id(id, 'legend:<i>')`; a hidden series keeps
  its color slot and its dimmed, struck-through item.

```v
if key := ui2.plot_legend_key_from_action('traffic', series, event) {
	app.hidden = ui2.plot_toggle_hidden(app.hidden, key)
}
```

### Hover and tooltips

Hover is controlled like everything else in ui2. The chart puts an invisible
hoverable band over each category on top of everything it draws; the
application decodes their `pointer:enter`/`pointer:leave` events into the
hovered index and builds the chart with it:

```v
fn on_event(event string) {
	if index := ui2.plot_hover_from_event('traffic', app.hovered, months.len, event) {
		app.hovered = index // -1 when the pointer leaves
		ui2.refresh()
	}
}

ui2.line_chart(id: 'traffic', hovered: app.hovered, ...)!
```

`plot_hover_from_event` rejects other components' actions, forged indexes and
changes that change nothing, such as the late leave of a category the pointer
has already left. For the hovered category:

| Chart | Draws |
| --- | --- |
| `line_chart`, `area_chart` | a crosshair, and a dot with a halo on each series (on the top of each stacked layer) |
| `bar_chart` | a highlight band behind the hovered bars; the other bars fade to 45% |

and a tooltip card titled with the category, a row per series (swatch, name,
value) and a total for stacked charts (and each share for 100% bars).
`tooltip_title` (`fn (index int) string`), `tooltip_value_format` and
`tooltip_value_color` (`fn (series int, index int, value f64) u32`, such as
green or red by sign) change its text. The card sits beside the hovered marks,
flipping to the other side near an edge; it is drawn under the hover bands, so
moving the pointer over it never takes the hover away.

**Identity.** Everything is keyed on `id`, which is required: series shapes,
hover bands, the card, the motion. Give sibling charts different ids.

**Turning it off.** `interactive: false` leaves out the hover bands, the
crosshair, highlight and card, and legend toggling, for a chart that only
decorates or one with something drawn over it. It still draws in.

### Motion

- **Appear.** The first build of a chart draws its data in over
  `appear_duration` (1 s) on ease-out-quart: lines and areas are revealed from
  the left (their paths cut exactly where the reveal is), bars grow out of the
  zero line together and a stack grows as one piece. Axes, grid lines and
  labels are there from the first frame; the hover marks and value labels wait
  until the data is whole. The timing comes from the widget animation system:
  a hidden element under the chart runs a one-second animation and the chart
  reads its progress on every build (the native backends rebuild while it
  runs). It runs once per `id` and `appear_key`; change the key to replay it,
  `appear: false` to never draw in.
- **Glide.** The crosshair, dots, highlight and card glide to a newly hovered
  category on a 0.2 s ease-out (widget animations on their frames). Shown again
  within 0.3 s of leaving, as when the pointer crosses from one band to the
  next, they glide from where they were; later they appear in place.
- **`reduce_motion: true`** shows everything in place: no appear, no gliding.
  ui2 cannot read the system setting, so the application passes it.

### `line_chart`

```v
ui2.line_chart(
	id:              'traffic'
	frame:           ui2.rect(0, 0, 640, 280)
	categories:      ['Jan', 'Feb', 'Mar', 'Apr']
	series:          [ui2.PlotSeries{
		key:    'desktop'
		name:   'Desktop'
		values: [186.0, 305, 237, 273]
	}, ui2.PlotSeries{
		key:    'mobile'
		name:   'Mobile'
		values: [80.0, 200, 120, 190]
	}]
	curve:           .smooth // or .linear, .step_after, .step_before, .step
	dots:            true
	reference_lines: [250.0]
	hovered:         app.hovered
	legend_toggle:   true
	hidden_series:   app.hidden
	theme:           theme
)!
```

Options beyond the shared ones: `stroke_width` (2), `dots`/`dot_size`,
`grid`, `grid_columns` (vertical grid lines), `grid_dashed`, `x_axis`,
`y_axis`, `point_count` (an axis laid out for more points than there are, for
a series in progress), `reference_lines` (dashed lines at values; ones off a
pinned axis are not drawn).

### `bar_chart`

```v
ui2.bar_chart(
	id:            'quarters'
	frame:         ui2.rect(0, 0, 360, 240)
	categories:    ['Q1', 'Q2', 'Q3', 'Q4']
	series:        [ui2.PlotSeries{
		key:    '2024'
		values: [42000.0, 51000, 47000, 63000]
	}, ui2.PlotSeries{
		key:    '2025'
		values: [48000.0, 57000, 61000, 72000]
	}]
	layout:        .grouped // .stacked, .expand
	alignment:     .bottom // .top, .left (horizontal), .right
	value_labels:  true
	value_format:  fn (v f64) string { return '$' + ui2.plot_format_compact(v) }
	hovered:       app.hovered
	theme:         theme
)!
```

- `layout`: `.grouped` places the series side by side in each band,
  `.stacked` end to end (negative values stack down from zero, d3's diverging
  offset), `.expand` as shares of each category's total.
- `alignment` is upstream's `BarAlignment`: the side the bars grow from, which
  is where the category labels go.
- Bars grow from zero, so negative values point the other way and the
  category axis line follows the zero line.
- `padding_inner` (0.4) and `padding_outer` (0.2) are upstream's band
  paddings; `max_bar_width` (30) caps each bar; `bar_gap` (2) separates the
  bars of a group and the segments of a stack; `corner_radius` (4) rounds each
  bar's tip (only the outer segment of a stack); `min_length` gives every bar a
  stub; `band_count` keeps bar widths for a short series.
- `value_labels` writes each value (each stack's total) past the tip, in
  `label_format` if set, and keeps room for it inside the frame.
- `bar_chart_bars(config)` returns every bar's frame, corners, value and
  category in chart coordinates, for drawing beside a bar or hit-testing.

### `area_chart`

```v
ui2.area_chart(
	id:            'signups'
	frame:         ui2.rect(0, 0, 640, 260)
	categories:    months
	series:        plans
	layout:        .stacked // .overlap (default), .expand
	gradient:      true
	fill_opacity:  0.5
	y_tick_format: ui2.plot_format_compact
	legend:        .top
	hovered:       app.hovered
	theme:         theme
)!
```

`layout: .overlap` fills every series down to the zero line, drawn over the
ones before it (every fill first, then every line); `.stacked` stacks each on
the one before; `.expand` stacks shares of each category's total.
`fill_opacity` (0.35) is the fill; `gradient: true` fades it from
`fill_opacity` at the top of the plot to `gradient_end_opacity` (0.04) at its
bottom, upstream's linear-gradient fill, drawn as horizontal slices of the
fill polygon about 6 points tall (8 to 32 of them) with stepped opacity,
because a shape fills with one color; the steps are too small to show.
`stroke_width` draws each area's top edge (0 for none), and `dots`, `curve`,
`point_count` and the axis options work as in `line_chart`.

## Implemented and omitted

Implemented from the upstream pages: the four scales (with band and point
`count`, `max_band_width`, `nearest_index`), the bar, line, area, pie/arc and
stack generators, the axis with labels and grid lines and inside label
placement; `LineChart` (`linear`, `step_after`, natural curve, `dot`,
`stroke`, `tick_margin`, `x_tick_count`, `y_domain`, `point_count`, `y_axis`,
`y_tick_count`, `y_tick_format`, `grid_columns`, `grid_dashed`,
`reference_line`, `x_axis`, `grid`); `BarChart` (`fill` per bar, `label`,
`tick_margin`, `label_axis`, `alignment`, `corner_radii` at the tip, negative
values, `value_axis`, `value_tick_count`, `value_tick_format`, inside labels,
`band_count`, `band_tick_count`, `grid_dashed`, `padding_inner`,
`padding_outer`, `min_length`); `AreaChart` (several series, `stroke`, `fill`,
gradient fills, `linear`/`step_after`, `y_domain`, `point_count`); hover with
crosshair, dots and halos, highlight band and fading bars, tooltip title,
rows, `tooltip_title`, `tooltip_value`, `tooltip_value_color`, `name`,
identity, `interactive(false)`, appear with `appear_key` and `appear(false)`,
gliding hover marks and reduced motion; theme integration. New beyond
upstream: several series in a bar chart (grouped, stacked, 100%), stacked and
100% area charts, legends with series toggling, `step_before` and `step`
curves, NaN gaps in lines, and `bar_chart_bars`.

Omitted, with the reason:

- **Closures over records** (`x(|d| ...)`, `y(|d| ...)`): ui2 components take
  plain values, so data is categories and `PlotSeries` values.
- **A tooltip that follows the cursor**, and `Plot::tooltip_state` hit-testing
  of arbitrary positions: ui2 reports where the pointer entered a hoverable
  element, not where it moves within it, so hover is per category band and the
  card is anchored to the hovered marks.
- **`tooltip_content`** (an arbitrary element as the card's content) and
  `plain_row`: the card is built from the title and rows; a stacked chart adds
  its total row itself.
- **The fade of the hover overlay**: ui2 can fade a box's fill but not an
  element with its children; the marks appear in place and then glide.
- **`PlotAppearScope`**: a chart's appear is kept by the animation system for
  as long as the application runs, so a chart in a virtual list does not draw in
  again when it scrolls back; nothing needs scoping.
- **Gradient bar fills (`fill_gradient`) and arbitrary `Background` fills**:
  shapes have one fill color with an opacity. Area fades are approximated with
  slices as described above.
- **`y_padding`**: the value axis is rounded out to round ticks instead, which
  leaves headroom above the data whenever the top value is not itself round.
  Pinned domains are not padded.
- **Evenly spaced pixel ticks**: upstream spaces `y_tick_count` ticks evenly
  from the baseline to the top and labels whatever value falls there; ui2 puts
  about that many ticks on round values (d3's tick algorithm), so labels read
  0, 50, 100 rather than 0, 77.5, 155.
- **Path caching**: the custom renderer already caches a shape's triangles by
  its id and the hash of its path.
- **Pie, radar, candlestick and sankey charts and `#[derive(IntoPlot)]`**: not in
  this group; `plot_pie`, `plot_arc_path` and the scales are what they need.

## Accessibility

A chart's root has role `group`, labelled by `accessibility_label` (or "Line
chart", "Bar chart", "Area chart") with the series names and category range as
its value. Each hover band is labelled with its tooltip text ("Mar: Desktop
237, Mobile 120"), the tooltip card is a `status` with the same, the legend a
`list` whose toggles are `checkbox` buttons valued `shown` or `hidden`, and
each axis a `group`. Values are never told by color alone: the legend and the
tooltip name every series.

## Platform notes

- Nothing here relies on a shape being clipped to its frame: reveals cut the
  paths themselves and pinned axes clamp values to the plot.
- The custom renderer draws at most 65,536 sokol-gl vertices a frame; the
  example's dashboard takes about 25,000 with four charts hovered, most of them
  in the round joins of its smooth lines. Dashed grids cost a quad per dash, so
  grids are solid by default.

## Attribution

No upstream code is adapted. Values taken from GPUI Kit: the band paddings 0.4
and 0.2 and the 30-point bar cap, the 45% fade of unhovered bars, the 1-second
ease-out-quart appear, and the hover dot and halo sizes. The scales, ticks,
pad-angle arcs and stack offsets follow d3's published definitions.

## Verification

```sh
v test ui/component_plot_test.v
v -d ui2_custom_rendering test ui/component_plot_test.v
v run examples/gpui_plot/main.v
v -d ui2_custom_rendering run examples/gpui_plot/main.v
```
