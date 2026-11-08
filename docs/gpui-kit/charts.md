# Charts: pie, radar, candlestick and sankey

Ports of the PieChart, RadarChart, CandlestickChart and SankeyChart of GPUI Kit's
[Chart](https://github.com/longbridge/gpui-kit/blob/main/website/component/chart.md)
component. Line, bar and area charts, scales and axes are a separate group
(`ui/component_plot*.v`); the older box-drawn `ui2.chart` (`ui/chart.v`) is
unchanged.

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `PieChart` (pie and donut) | `pie_chart(PieChartConfig)`, `PieSlice`, `pie_chart_hover_from_event` | `ui/component_charts_special_pie.v` |
| `RadarChart` | `radar_chart(RadarChartConfig)`, `RadarAxis`, `RadarSeries`, `radar_chart_hover_from_event` | `ui/component_charts_special_radar.v` |
| `CandlestickChart` | `candlestick_chart(CandlestickChartConfig)`, `Candle`, `candlestick_chart_hover_from_event` | `ui/component_charts_special_candlestick.v` |
| `SankeyChart`, `plot::shape::Sankey`, `SankeyLink`, `SankeyAlign`, `SankeyValueScale` | `sankey_chart(SankeyChartConfig)`, `sankey_layout`, `SankeyNode`, `SankeyLink`, `SankeyAlign`, `SankeyValueScale`, `sankey_chart_hover_from_event` | `ui/component_charts_special_sankey.v`, `ui/component_charts_special_sankey_layout.v` |
| Tooltip, legend, theme chart colors, appear and hover motion | `SpecialChartTooltipRow`, `SpecialChartLegendItem`, `special_chart_colors`, appear and glide helpers | `ui/component_charts_special.v` |

Tests are in `ui/component_charts_special_test.v`. `examples/gpui_charts/main.v`
is a dashboard with a doughnut with leader-line labels, a pie with a hovered
slice and a legend, a radar comparing three people, a daily candlestick chart
(deterministic data) with volume and two moving averages, an energy-flow
sankey diagram, and buttons for the dark theme, reduced motion and replaying
the appear:

```sh
v run examples/gpui_charts/main.v
v -d ui2_custom_rendering run examples/gpui_charts/main.v
```

## Conventions

- **Vector drawing.** Every slice, polygon, candle, ribbon, grid and leader line
  is a `shape` path, so the charts draw antialiased on every backend. Shapes have
  stable ids under the chart's id (`<id>:component:slice:<key>`, `series:<key>`,
  `link:<index>:<band>`, ...), which the custom renderer caches triangles under.
- **Controlled state.** A chart owns nothing. The application keeps what is
  hovered, passes it in (`hovered` or `hover`) and rebuilds. Each chart's
  `*_hover_from_event(config, event)` turns the pointer events it emitted into
  the next value, and returns none for events of anything else, unknown or
  forged keys and indices, and moves that change nothing.
- **Identity.** Charts require an `id`. Each datum has a `key` (a slice, axis,
  series, candle or node) defaulting to its label, then to its position; keys
  must be unique and are what hover state and element ids use, so a datum keeps
  its hover and its shape when the data around it changes. Sankey links name
  their nodes by key.
- **Theme.** `special_chart_colors(theme)` derives everything from a
  `ComponentTheme`: a categorical palette of eight colors in a fixed order (a
  color-vision-deficiency-checked order, with separate steps for a dark
  surface, chosen by the background's luminance), bullish and bearish candle
  colors, a hairline grid, muted text and the tooltip card. Text is always in
  text colors, never in a series color; a label inside a slice picks white or
  ink by the slice's color (`special_chart_ink_on`).
- **Sizes.** `size` (`.small`, `.medium`, `.large`) sets the label text to 11, 12
  (GPUI Kit's chart text size) or 14 points. Text is measured with
  `measure_text_width`, so labels, legends, axis columns and tooltips are as wide
  as the running backend draws them.
- **Hover.** ui2 hit-tests views by their frames, and hover reports only enter
  and leave, so each chart lays transparent hover targets over its data, drawn
  last: strips that follow a slice or a polygon (`special_chart_hit_strips`),
  bands for candles, strips along each ribbon (`sankey_link_hit_rects`) and
  node rectangles. Every target of one datum carries the same action, and hover
  is tracked by action, so the pointer moving between them keeps the datum
  hovered. The targets are above the tooltip, so a tooltip never takes the hover
  from the chart. The tooltip is anchored to the datum, not to the pointer.
- **Motion.** Marks that follow the hover glide on the animation system: the
  hovered pie slice lifts out along its middle, the candle band and the radar's
  hover dots slide between data (0.18 s, out-cubic), placed outright when the
  hover starts. `reduce_motion` makes them jump.
- **Appear.** The first build of a chart draws it in over `appear_duration`
  (1 s) on easeOutQuart, Chart.js's curve, as GPUI Kit does: a pie sweeps
  clockwise, a radar grows out of its center, candles and a sankey diagram are
  revealed from the left. The run is timed by a hidden element's animation, and
  each build reads its progress, so every frame is laid out afresh; the native
  backends rebuild while it runs. Axes, grids and labels are there from the
  first frame; hover targets and tooltips wait until the chart is whole. The
  appear runs once per id; a new `appear_key` (a symbol, a period) runs it
  again. `appear: false` or `reduce_motion: true` show the chart whole at once.
- **Turning it off.** `interactive: false` leaves out the hover targets, the
  legend's hover and the tooltip, as GPUI Kit's `interactive(false)` does.

## Pie chart

```v
pie := ui2.pie_chart(
	id:             'browsers'
	frame:          ui2.rect(16, 16, 400, 280)
	slices:         [
		ui2.PieSlice{ label: 'Chrome', value: 275 },
		ui2.PieSlice{ label: 'Safari', value: 200 },
		ui2.PieSlice{ label: 'Firefox', value: 187 },
	]
	inner_ratio:    0.62 // a doughnut
	pad_angle:      0.025
	labels:         .outside
	label_content:  .name_and_share
	center_text:    '662'
	center_caption: 'visitors'
	hovered:        app.hovered
	theme:          theme
)!

// in on_event:
if next := ui2.pie_chart_hover_from_event(pie_config, event) {
	app.hovered = next
	ui2.refresh()
}
```

| Field | Meaning |
| --- | --- |
| `slices` | `PieSlice{key, label, value, color, value_text}`; slices worth zero or less are left out |
| `outer_radius` | Points; zero fits the ring, its outside labels and the hover lift in the frame |
| `inner_radius`, `inner_ratio` | A doughnut's hole, in points or as a share of the outer radius |
| `pad_angle` | Radians between slices at the outer radius; the gap keeps that width to the center (`pie_chart_slice_path`) |
| `start_angle` | Radians clockwise from twelve o'clock |
| `labels` | `.none`, `.inside` (centered, only where the text fits), `.outside` (leader lines; `pie_chart_label_layout` moves crowded labels apart as little as possible and slides their elbows along the label circle so a line never crosses the ring) |
| `label_content` | `.name`, `.share`, `.name_and_share`, `.value` |
| `label_gap`, `label_color`, `leader_color` | Outside label spacing and colors |
| `center_text`, `center_caption` | Text in a doughnut's hole |
| `legend` | `.none`, `.bottom`, `.top`, `.right`; items show each share and hover their slice |
| `hovered`, `hover_lift` (6) | The hovered slice lifts out and the others fade to 55% |
| `hover_center` (true) | A doughnut reads the hovered slice out in its hole instead of a floating tooltip |
| `name` | The tooltip row's name for a slice without a label (GPUI Kit's `name`) |

The tooltip row is the slice's label and `value_text`, or its value and share
(`275 (32.1%)`, `pie_chart_value_text`), GPUI Kit's `tooltip_name` and
`tooltip_value`.

## Radar chart

```v
radar := ui2.radar_chart(
	id:           'skills'
	frame:        ui2.rect(16, 16, 380, 280)
	axes:         ['Design', 'Frontend', 'Backend', 'Testing'].map(ui2.RadarAxis{ label: it })
	series:       [
		ui2.RadarSeries{ name: 'Alice', values: [82.0, 94, 58, 70] },
		ui2.RadarSeries{ name: 'Bob', values: [52.0, 68, 92, 78] },
	]
	max_value:    100
	level_labels: true
	hover:        app.radar // ui2.RadarChartHover{axis, series}
	theme:        theme
)!
```

| Field | Meaning |
| --- | --- |
| `axes` | Spokes clockwise from twelve o'clock, `RadarAxis{key, label}` |
| `series` | `RadarSeries{key, name, values, color, fill_opacity}`, one value per axis |
| `min_value`, `max_value` | The values at the center and at the outer ring; `max_value` zero rounds the largest value up so every ring is a round number (`radar_chart_domain`) |
| `grid` | `.polygon`, `.circle` or `.none`, with `grid_levels` rings (4) |
| `level_labels` | Each ring's value beside the first spoke |
| `dots`, `fill_opacity` (0.15), `stroke_width` (2) | Vertex dots and the polygons' paint |
| `outer_radius`, `label_gap` (10), `label_color` | Zero fits the ring so every axis label is inside the frame (`radar_chart_fit_radius`) |
| `legend` | `.bottom` by default; an item hovers its series |
| `hover_mode` | `.axis` (default): the spoke nearest the pointer gets a dot on every series that glides between spokes, a bold label and a tooltip with a row per series, placed in a corner clear of the spoke and the labels. `.series`: the polygon under the pointer (the smallest, so nested ones stay reachable) stands out and lists its values |

## Candlestick chart

```v
chart := ui2.candlestick_chart(
	id:              'acme'
	frame:           ui2.rect(16, 16, 680, 400)
	candles:         app.candles // []ui2.Candle{label, open, high, low, close, volume}
	volume:          true
	moving_averages: [5, 20]
	hovered:         app.candle
	theme:           theme
)!
```

| Field | Meaning |
| --- | --- |
| `candles` | `Candle{key, label, open, high, low, close, volume}`; `low <= open, close <= high` is checked |
| `body_width_ratio` (0.7), `max_band_width` (30) | Body width in its band; a few candles across a wide chart stay narrow and centered |
| `tick_margin` | Label every nth candle; zero spaces labels by their measured widths (`candlestick_label_interval`) |
| `volume`, `volume_ratio` (0.22) | Volume bars in a pane under the candles, colored like their candles |
| `moving_averages`, `moving_average_colors` | Simple moving averages of the close (`candlestick_moving_average`) drawn as lines, keyed above the plot with their value at the hovered or last candle |
| `y_axis`, `y_ticks` (5), `price_decimals` (2) | Round price ticks on the right, as trading charts put them |
| `x_axis`, `grid`, `legend` | Category axis, hairline price grid, moving average keys |
| `bullish`, `bearish` | Up and down colors; swap them for markets that read a rise as red |
| `hovered` | A band slides to the candle, a rule and a tag mark its close on the price axis, and the tooltip lists open, high, low, close, the change from the previous close, volume and the averages |

`candlestick_layout(config, width, height)` returns the panes, the candle
positions (`candlestick_center`) and the price scale (`price_y`).

## Sankey chart

```v
flow := ui2.sankey_chart(
	id:     'energy'
	frame:  ui2.rect(16, 16, 480, 400)
	nodes:  ['Coal', 'Gas', 'Electricity', 'Homes', 'Losses'].map(ui2.SankeyNode{ label: it })
	links:  [
		ui2.SankeyLink{ source: 'Coal', target: 'Electricity', value: 60 },
		ui2.SankeyLink{ source: 'Gas', target: 'Electricity', value: 110 },
		ui2.SankeyLink{ source: 'Gas', target: 'Homes', value: 140 },
		ui2.SankeyLink{ source: 'Electricity', target: 'Homes', value: 100 },
		ui2.SankeyLink{ source: 'Electricity', target: 'Losses', value: 70 },
	]
	unit:   'TWh'
	hover:  app.flow // ui2.SankeyChartHover{node, link}
	theme:  theme
)!
```

The layout, `sankey_layout(nodes, links, SankeyLayoutOptions)`, is pure and
follows d3-sankey, which GPUI Kit's mirrors:

1. Links name nodes by key; unknown keys, duplicate node keys, negative or
   non-finite values and **cycles** (a self link included) are errors. Links
   worth zero are left out.
2. Columns by longest path: `depth` from any source, `height` to any sink;
   `align` places a node by depth (`.left`), by height (`.right`), by depth with
   nodes that lead nowhere in the last column (`.justify`, the default), or by
   depth with sources next to their first target (`.center`).
3. Node heights from flow: a node is as tall as the larger of its inflow and
   outflow, on one scale for every column, the one that fits the fullest column
   with `node_padding` between nodes.
4. `iterations` (6) relaxation passes, right to left and left to right, move
   each node toward where its links would run straight, weighted by value, then
   resolve overlaps from the middle of the column outward; this is what
   reduces crossings.
5. Link ordering: a node's links are stacked in the order of the nodes at their
   other ends, so ribbons leaving one node do not cross each other.

`value_scale: .sqrt` sizes nodes by the square roots of the flows, so small
flows stay visible; the links of each side then share it in proportion, filling
it, and labels still read the raw values. `sankey_columns` gives just the
columns.

| Field | Meaning |
| --- | --- |
| `node_width` (10), `node_padding` (16), `node_radius` (2), `align`, `iterations`, `value_scale` | Layout and node shape |
| `link_color` | `.gradient` (default; the ribbon blends from the source's color to the target's in bands that meet on whole points), `.source`, `.target` |
| `link_opacity` (0.35), `min_link_width` (1) | Ribbon paint and the thinnest ribbon |
| `show_values`, `unit`, `SankeyNode.value_text` | A value line under each node name: the throughput (the larger of inflow and outflow) with the unit |
| `label_gap` (6) | First-column labels go left of their nodes, the last column's right, middle columns beside their nodes on a veil of the surface; margins are measured, at most 30% of the width each, and crowded labels in a column are moved apart |
| `hover`, `link_hover` | A hovered node keeps its links and neighbors strong while the rest fade, with a tooltip of its inflow and outflow; a hovered link shows its flow and its share of its source |

## Implemented and omitted

Implemented from GPUI Kit: pie and donut with inner and outer radius, pad
angle, per-slice colors, leader-line labels with overlap spreading, label and
line colors and gap; radar with several series, per-series stroke and fill,
dots, grid levels, outer radius, label gap and color, max value; candlestick
bodies and wicks with bullish and bearish theme colors, body width ratio, max
band width, tick margin, grid and x axis switches; sankey with the d3-sankey
layout, the four alignments, node width, padding, corner radius and colors,
link opacity, minimum link width, iterations, the square-root value scale,
value labels and gradient ribbons; hover emphasis and tooltips on every chart
(lift and fade on a pie, dots on a radar, a band on a candlestick, linked
ribbons on a sankey), `interactive`, `appear`, `appear_key`, reduced motion,
stable identity, theme colors.

Added beyond GPUI Kit: a legend (pie, radar, candlestick keys), inside pie
labels, a doughnut center readout, a radar circle grid, ring value labels and
series hover mode, a candlestick price axis, volume pane, moving averages,
price tag and change row, sankey link hover, link color modes and a hover
decoder per chart.

Omitted, with the reason:

- **Closures** (`value`, `label`, `color`, `tooltip_title`, `tooltip_value`,
  `tooltip_value_color`, `inner_radius_fn`, `outer_radius_fn`, sankey `labels`).
  ui2 configs are data: each datum carries its label, color and `value_text`, and
  the application formats values before building.
- **Element labels and `tooltip_content`** (custom elements around a radar or in
  a tooltip). A chart lays out text it measures; arbitrary elements would need a
  layout pass ui2 does not have. Rows and titles cover the documented cases.
- **A tooltip following the pointer.** ui2 hover reports only where the pointer
  entered, so the tooltip is anchored to the datum and flips away from the
  chart's edges.
- **Springs.** The hover glides are eased tweens on the animation system, which
  has no spring curve; GPUI Kit's fade-in of the whole overlay is omitted
  because shape paints cannot be animated property by property.
- **`PlotAppearScope`** for charts in virtual lists: the appear runs once per id
  and key for the life of the process; pass `appear: false` in such lists.
- **Path caching across frames.** The custom renderer already caches each
  shape's triangles under its id until its path changes.

## Accessibility

Each chart is an `img` whose label is `title` (or "Pie chart", "Radar chart",
"Candlestick chart", "Sankey chart") and whose value is the data in words:
every slice's share, every series' values, the period range and last close, or
every flow. Legend items carry their label and value. The tooltip card has the
`tooltip` role (a help tag on AppKit) and an accessibility label with its
text. Hover targets are transparent views without roles.

## Platform notes

- The charts do not rely on a shape being clipped to its frame: gradient
  ribbons are cut into exact pieces (`sankey_ribbon_piece`) and the appear
  reveal leaves out what is past its edge.
- **The custom renderer measures bold text narrower than regular** for some
  strings; labels that can turn bold on hover are given the wider of the two.
- Touch platforms have no hover, so the charts show no tooltips there.

## Attribution

The sankey layout follows d3-sankey (Copyright 2015 Mike Bostock,
BSD-3-Clause), as GPUI Kit's does; the V implementation is new. No GPUI Kit
source is copied: the APIs, the defaults (12-point text, a 6-point hover lift,
15- and 10-point label gaps, 4 grid rings, 6 relaxation passes, a 1-second
easeOutQuart appear) and the behaviors follow its documentation and constants.

## Verification

```sh
v test ui/component_charts_special_test.v
v -d ui2_custom_rendering test ui/component_charts_special_test.v
```
