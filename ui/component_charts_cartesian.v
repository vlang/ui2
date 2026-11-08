module ui2

import math
import time

// What line_chart, bar_chart and area_chart share: their series, legend,
// hover layer and tooltip card, and the appear and glide motion.
//
// Hover works the way GPUI Kit's charts do, in ui2's controlled style: an
// invisible band over each category reports `pointer:enter` and
// `pointer:leave`, the application turns those into a hovered index with
// plot_hover_from_event and builds the chart with it, and the chart draws its
// crosshair, dots, highlight and tooltip card for that index. The bands are the
// topmost layer, so the card and the marks never take the pointer from them.

// PlotSeries is one series of values, one per category.
pub struct PlotSeries {
pub:
	// key is the series' identity: its shapes' ids, its color slot, and what
	// hiding it from the legend refers to. Required and unique in a chart.
	key    string
	name   string // Shown in the legend and the tooltip; defaults to the key.
	values []f64  // One per category; NaN is a missing value.
	color  ?u32   // Defaults to the theme's chart palette, by the series' position.
	// colors gives a bar chart's bars their own colors, one per category, as
	// GPUI Kit's fill closure does; categories past the list take `color`.
	colors []u32
}

// PlotMargin is the space a chart keeps clear inside its frame.
pub struct PlotMargin {
pub:
	top    f64 = 8
	right  f64 = 12
	bottom f64 = 4
	left   f64 = 4
}

pub enum PlotLegendPosition {
	auto // at the bottom when there are two series or more
	top
	bottom
	hidden
}

// PlotTitleFn writes the tooltip title of the category at `index`.
pub type PlotTitleFn = fn (index int) string

// PlotValueColorFn colors a tooltip row's value, such as green or red by its
// sign: `series` is the series' position in the chart's list.
pub type PlotValueColorFn = fn (series int, index int, value f64) u32

// ── Series ─────────────────────────────────────────────────────────

struct CartesianSeries {
	key    string
	name   string
	values []f64
	color  u32
	colors []u32
	slot   int // the position in the chart's series list
	hidden bool
}

fn cartesian_series(series []PlotSeries, hidden []string, theme ComponentTheme) ![]CartesianSeries {
	mut seen := map[string]bool{}
	mut out := []CartesianSeries{cap: series.len}
	for i, s in series {
		if s.key.trim_space().len == 0 {
			return error('chart series ${i} needs a key')
		}
		if s.key in seen {
			return error('duplicate chart series key `${s.key}`')
		}
		seen[s.key] = true
		out << CartesianSeries{
			key:    s.key
			name:   if s.name.len > 0 { s.name } else { s.key }
			values: s.values
			color:  s.color or { plot_chart_color(theme, i) }
			colors: s.colors
			slot:   i
			hidden: s.key in hidden
		}
	}
	return out
}

fn cartesian_visible(series []CartesianSeries) []CartesianSeries {
	return series.filter(!it.hidden)
}

// cartesian_color is the color of a series' mark for category `index`.
fn cartesian_color(s CartesianSeries, index int) u32 {
	return if index >= 0 && index < s.colors.len { s.colors[index] } else { s.color }
}

fn cartesian_value(s CartesianSeries, index int) f64 {
	return if index >= 0 && index < s.values.len { s.values[index] } else { math.nan() }
}

// ── Sizes ──────────────────────────────────────────────────────────

struct CartesianText {
	tick    f64 // axis tick labels
	legend  f64
	tooltip f64
}

fn cartesian_text(size ComponentSize) CartesianText {
	return match size {
		.small { CartesianText{10, 11, 11} }
		.medium { CartesianText{11, 12, 12} }
		.large { CartesianText{12, 13, 13} }
	}
}

// ── Decoders ───────────────────────────────────────────────────────

// plot_hover_from_event turns a pointer event from a chart's hover layer into
// the hovered index to build the chart with: the category entered, or -1 when
// the pointer leaves the hovered one. It returns none for other events, for
// indexes past `count`, and for changes that change nothing, such as the late
// leave of a category the pointer has already moved on from.
pub fn plot_hover_from_event(id string, current int, count int, event string) ?int {
	pointer := parse_pointer_event(event)?
	part := component_action_part(id, pointer.action)?
	if !part.starts_with('hover:') {
		return none
	}
	index := component_parse_index(part['hover:'.len..], count - 1)?
	match pointer.phase {
		'enter' {
			return if index == current { none } else { index }
		}
		'leave' {
			return if index == current { -1 } else { none }
		}
		else {
			return none
		}
	}
}

// plot_legend_key_from_action is the key of the series whose legend item was
// clicked, for a chart built with legend_toggle; none for any other action.
pub fn plot_legend_key_from_action(id string, series []PlotSeries, action string) ?string {
	part := component_action_part(id, action)?
	if !part.starts_with('legend:') {
		return none
	}
	index := component_parse_index(part['legend:'.len..], series.len - 1)?
	return series[index].key
}

// plot_toggle_hidden adds `key` to the hidden series, or shows it again.
pub fn plot_toggle_hidden(hidden []string, key string) []string {
	if key in hidden {
		return hidden.filter(it != key)
	}
	mut out := hidden.clone()
	out << key
	return out
}

// ── Legend ─────────────────────────────────────────────────────────

const plot_legend_row = 20.0
const plot_legend_swatch = 10.0
const plot_legend_gap = 16.0

struct CartesianLegendItem {
	text   string
	color  u32
	hidden bool
	slot   int
}

fn cartesian_legend_items(series []CartesianSeries) []CartesianLegendItem {
	mut items := []CartesianLegendItem{cap: series.len}
	for s in series {
		items << CartesianLegendItem{s.name, s.color, s.hidden, s.slot}
	}
	return items
}

fn cartesian_legend_shown(position PlotLegendPosition, count int) bool {
	return match position {
		.auto { count >= 2 }
		.top, .bottom { count >= 1 }
		.hidden { false }
	}
}

// cartesian_legend_frames lays the items out in rows `width` wide, centered,
// and returns each item's frame and the legend's height.
fn cartesian_legend_frames(items []CartesianLegendItem, width f64, size f64) ([]Rect, f64) {
	style := TextStyle{
		size: size
	}
	mut frames := []Rect{cap: items.len}
	mut rows := [][]int{}
	mut row := []int{}
	mut row_width := 0.0
	mut widths := []f64{cap: items.len}
	for i, item in items {
		// A name too long for the legend is cut short rather than drawn past it.
		w := math.min(width, plot_legend_swatch + 6 + math.ceil(measure_text_width(item.text,
			style)))
		widths << w
		needed := if row.len == 0 { w } else { row_width + plot_legend_gap + w }
		if row.len > 0 && needed > width {
			rows << row
			row = []int{}
			row_width = w
		} else {
			row_width = needed
		}
		row << i
	}
	if row.len > 0 {
		rows << row
	}
	frames = []Rect{len: items.len}
	for r, indices in rows {
		mut total := 0.0
		for k, i in indices {
			total += widths[i] + if k > 0 { plot_legend_gap } else { 0.0 }
		}
		mut x := math.max(0.0, (width - total) / 2)
		for i in indices {
			frames[i] = rect(x, f64(r) * plot_legend_row, widths[i], plot_legend_row)
			x += widths[i] + plot_legend_gap
		}
	}
	return frames, f64(rows.len) * plot_legend_row
}

fn cartesian_legend(id string, items []CartesianLegendItem, frame Rect, size f64, toggle bool, theme ComponentTheme) Element {
	frames, _ := cartesian_legend_frames(items, frame.width, size)
	mut children := []Element{cap: items.len}
	for i, item in items {
		f := frames[i]
		swatch_color := if item.hidden { theme.border } else { item.color }
		text_color := if item.hidden {
			plot_mix(theme.muted_foreground, theme.background, 0.45)
		} else {
			theme.foreground
		}
		parts := [
			view('', rect(0, (f.height - plot_legend_swatch) / 2, plot_legend_swatch,
				plot_legend_swatch), BoxStyle{
				bg:     swatch_color
				radius: 3
			}, []Element{}),
			label('', item.text, rect(plot_legend_swatch + 6, 0, f.width - plot_legend_swatch - 6,
				f.height), TextStyle{
				color:         text_color
				size:          size
				strikethrough: item.hidden
			}),
		]
		if toggle {
			children << Element{
				...button_view(component_part_id(id, 'legend:${item.slot}'), f, BoxStyle{
					transparent: true
				}, parts)
				cursor:              cursor_pointing_hand
				accessibility_role:  'checkbox'
				accessibility_label: item.text
				accessibility_value: if item.hidden { 'hidden' } else { 'shown' }
				checked:             !item.hidden
			}
		} else {
			children << Element{
				...view('', f, BoxStyle{ transparent: true }, parts)
				accessibility_label: item.text
			}
		}
	}
	return Element{
		...view(component_part_id(id, 'legend'), frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'list'
		accessibility_label: 'Legend'
	}
}

// ── Tooltip card ───────────────────────────────────────────────────

// CartesianTooltipRow is a swatch, a name and a value; a row without a color
// (a total, say) has no swatch.
struct CartesianTooltipRow {
	color       ?u32
	name        string
	value       string
	value_color ?u32
}

fn cartesian_value_color(color PlotValueColorFn, s CartesianSeries, index int, value f64) ?u32 {
	if voidptr(color) == unsafe { nil } || !plot_finite(value) {
		return none
	}
	return color(s.slot, index, value)
}

const plot_tooltip_padding = 8.0
const plot_tooltip_min_width = 132.0

fn cartesian_tooltip_size(title string, rows []CartesianTooltipRow, size f64) (f64, f64) {
	line := plot_label_height(size)
	name_style := TextStyle{
		size: size
	}
	value_style := TextStyle{
		size: size
		bold: true
	}
	mut width := math.ceil(measure_text_width(title, value_style))
	for row in rows {
		w := plot_legend_swatch - 2 + 6 + measure_text_width(row.name, name_style) + 16 +
			measure_text_width(row.value, value_style)
		width = math.max(width, math.ceil(w))
	}
	height := (if title.len > 0 { line + 2 } else { 0.0 }) + f64(rows.len) * line
	return math.max(plot_tooltip_min_width, width + 2 * plot_tooltip_padding), height + 2 * plot_tooltip_padding
}

fn cartesian_tooltip(id string, title string, rows []CartesianTooltipRow, frame Rect, size f64, theme ComponentTheme) Element {
	line := plot_label_height(size)
	inner := frame.width - 2 * plot_tooltip_padding
	mut children := []Element{}
	mut y := plot_tooltip_padding
	if title.len > 0 {
		children << label('', title, rect(plot_tooltip_padding, y, inner, line), TextStyle{
			color: theme.foreground
			size:  size
			bold:  true
		})
		y += line + 2
	}
	swatch := plot_legend_swatch - 2
	for row in rows {
		mut x := plot_tooltip_padding
		if color := row.color {
			children << view('', rect(x, y + (line - swatch) / 2, swatch, swatch), BoxStyle{
				bg:     color
				radius: 2
			}, []Element{})
			x += swatch + 6
		}
		children << label('', row.name, rect(x, y, inner - (x - plot_tooltip_padding), line),
			TextStyle{
				color: theme.muted_foreground
				size:  size
			})
		children << label('', row.value, rect(plot_tooltip_padding, y, inner, line), TextStyle{
			color: row.value_color or { theme.foreground }
			size:  size
			bold:  true
			align: .right
		})
		y += line
	}
	mut summary := []string{}
	for row in rows {
		summary << '${row.name} ${row.value}'
	}
	return Element{
		...view(id, frame, BoxStyle{
			bg:            theme.background
			radius:        8
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        component_popup_shadow()
		}, children)
		accessibility_role:  'status'
		accessibility_label: title
		accessibility_value: summary.join(', ')
	}
}

// plot_tooltip_place puts a card w by h beside `anchor` (the hovered marks),
// inside `bounds`: to its right when there is room, else to its left, top
// aligned with it; for `below`, under it and else above it, right aligned.
fn plot_tooltip_place(anchor Rect, w f64, h f64, area Rect, below bool) Rect {
	gap := 10.0
	clamp_x := fn [area, w] (x f64) f64 {
		return math.max(area.x, math.min(x, area.x + area.width - w))
	}
	clamp_y := fn [area, h] (y f64) f64 {
		return math.max(area.y, math.min(y, area.y + area.height - h))
	}
	if below {
		mut y := anchor.y + anchor.height + gap
		if y + h > area.y + area.height {
			y = anchor.y - gap - h
		}
		return rect(clamp_x(anchor.x + anchor.width - w), clamp_y(y), w, h)
	}
	mut x := anchor.x + anchor.width + gap
	if x + w > area.x + area.width {
		x = anchor.x - gap - w
	}
	return rect(clamp_x(x), clamp_y(anchor.y), w, h)
}

// ── Hover layer ────────────────────────────────────────────────────

fn cartesian_hover_bands(id string, frames []Rect, labels []string) []Element {
	mut bands := []Element{cap: frames.len}
	for i, f in frames {
		if f.width <= 0 || f.height <= 0 {
			continue
		}
		bands << Element{
			...with_hover(view(component_part_id(id, 'hover:${i}'), f, BoxStyle{
				transparent: true
			}, []Element{}))
			accessibility_label: if i < labels.len { labels[i] } else { '' }
		}
	}
	return bands
}

// ── Motion ─────────────────────────────────────────────────────────

const plot_glide_seconds = 0.2

fn plot_ease_out_quart(t f64) f64 {
	u := 1 - math.max(0.0, math.min(1.0, t))
	return 1 - u * u * u * u
}

// plot_appear is how far a chart has drawn in, eased, and the hidden element
// whose animation times it: the appear runs once for each id and key, on the
// first build that asks for it, and progress comes back from the widget
// animation system on every build until it completes.
fn plot_appear(id string, enabled bool, key string, duration f64, reduce_motion bool) (f64, []Element) {
	if !enabled || reduce_motion || duration <= 0 {
		return 1.0, []Element{}
	}
	appear_marker := component_part_id(id, 'appear:${key}')
	info := animation_info(appear_marker)
	progress := match info.status {
		.idle {
			animation(duration: duration, x: 1).start(appear_marker)
			0.0
		}
		.running {
			info.progress
		}
		else {
			return 1.0, []Element{}
		}
	}
	return plot_ease_out_quart(progress), [
		Element{
			...view(appear_marker, rect(0, 0, 0, 0), BoxStyle{ transparent: true }, []Element{})
			hidden: true
		},
	]
}

// plot_glide_target is where the last glide started on id is heading.
fn plot_glide_target(id string) ?PathPoint {
	runtime := g_animation_runtime
	runtime.mutex.lock()
	defer {
		runtime.mutex.unlock()
	}
	if id !in runtime.runs {
		return none
	}
	targets := runtime.runs[id].definition.targets
	return path_point(targets.x or { math.nan() }, targets.y or { math.nan() })
}

// plot_glide moves the element id to (x, y) smoothly when it was somewhere
// else, as the crosshair and dots of a GPUI Kit chart follow the hovered
// datum. The first build only records where it is, so a mark appears in place.
fn plot_glide(id string, x f64, y f64, animate bool) {
	if !animate {
		plot_glide_release(id)
		return
	}
	if target := plot_glide_target(id) {
		if math.abs(target.x - x) > 0.01 || math.abs(target.y - y) > 0.01 || !plot_finite(target.x)
			|| !plot_finite(target.y) {
			animation(duration: plot_glide_seconds, transition: .out_cubic, x: x, y: y).start(id)
		}
		return
	}
	animation(duration: 0, x: x, y: y).start(id)
}

// plot_glide_release forgets a mark's position, so it appears in place the
// next time it is shown.
fn plot_glide_release(id string) {
	if animation_info(id).status != .idle {
		clear_animation(id)
	}
}

// plot_hover_linger_ms is how long a chart's hover marks may be gone and
// still glide from where they were when they come back: long enough for the
// pointer to cross from one hover band to the next (a leave and an enter,
// which AppKit builds one after the other), short enough that marks shown
// again later appear in place.
const plot_hover_linger_ms = 300

// plot_hover_continues tells a chart whether its hover marks may glide from
// where they last were. A build without them stamps when they went; a build
// with them reads the stamp and drops it.
fn plot_hover_continues(id string, shown bool) bool {
	stamp := component_part_id(id, 'hover-gone')
	runtime := g_animation_runtime
	runtime.mutex.lock()
	gone_at := if stamp in runtime.runs { runtime.runs[stamp].started_at } else { i64(-1) }
	runtime.mutex.unlock()
	if !shown {
		if gone_at < 0 {
			// A run with nothing to animate records the time it started.
			animation(duration: 0, x: 0).start(stamp)
		}
		return true
	}
	if gone_at < 0 {
		return true
	}
	clear_animation(stamp)
	return time.ticks() - gone_at <= plot_hover_linger_ms
}

// plot_glide_element records el's position for gliding and returns it.
fn plot_glide_element(el Element, animate bool) Element {
	plot_glide(el.id, el.frame.x, el.frame.y, animate)
	return el
}

// ── Shared drawing ─────────────────────────────────────────────────

// plot_bleed is how far series shapes reach past the plot, so strokes and
// dots on its edges are drawn whole.
const plot_bleed = 8.0

fn plot_bleed_frame(plot Rect) Rect {
	return rect(plot.x - plot_bleed, plot.y - plot_bleed, plot.width + 2 * plot_bleed,
		plot.height + 2 * plot_bleed)
}

// plot_reference_path draws dashed lines across the plot at the given y
// positions (plot coordinates), offset into a bleed frame.
fn plot_reference_path(rows []f64, width f64) []PathCommand {
	mut path := []PathCommand{}
	for y in rows {
		plot_dashed_segment(mut path, plot_bleed, plot_crisp(y) + plot_bleed, width + plot_bleed,
			plot_crisp(y) + plot_bleed, true)
	}
	return path
}

// plot_columns_path is `count` evenly spaced vertical grid lines, the first on
// the plot's left edge.
fn plot_columns_path(count int, width f64, height f64, dashed bool) []PathCommand {
	mut path := []PathCommand{}
	for i in 0 .. count {
		x := plot_crisp(width * f64(i) / f64(count))
		plot_dashed_segment(mut path, x, 0, x, height, dashed)
	}
	return path
}

fn plot_dot_path(points []PathPoint, radius f64) []PathCommand {
	mut path := []PathCommand{}
	for p in points {
		if plot_finite(p.x) && plot_finite(p.y) {
			path << path_circle(p.x, p.y, radius)
		}
	}
	return path
}

// plot_value_domain is the value axis of a chart: the data's extent with zero
// in view and rounded out to ticks, or what the application pinned.
fn plot_value_scale(values []f64, min_value ?f64, max_value ?f64, ticks int) PlotLinearScale {
	lo, hi := plot_extent(values, [0.0])
	pinned_lo := min_value or { lo }
	pinned_hi := max_value or { hi }
	mut a := pinned_lo
	mut b := pinned_hi
	if a == b {
		b = a + 1
	}
	if a > b {
		a, b = b, a
	}
	scale := plot_linear_scale(a, b, 0, 1)
	if min_value != none || max_value != none {
		return scale.with_clamp(true)
	}
	return scale.nice(ticks)
}

// cartesian_chart_view wraps a chart's children in its root view.
fn cartesian_chart_view(id string, frame Rect, children []Element, role_label string, summary string) !Element {
	return component_finish(Element{
		...view(id, frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: role_label
		accessibility_value: summary
	})
}

fn cartesian_summary(series []CartesianSeries, categories []string) string {
	names := cartesian_visible(series).map(it.name).join(', ')
	if categories.len == 0 {
		return names
	}
	span := if categories.len == 1 {
		categories[0]
	} else {
		'${categories[0]} to ${categories[categories.len - 1]}'
	}
	return if names.len > 0 { '${names}; ${span}' } else { span }
}
