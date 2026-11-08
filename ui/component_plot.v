module ui2

import math

// The plot module: the building blocks GPUI Kit's charts are made of, as pure
// functions over numbers and paths. Scales map data to positions
// (component_plot_scale.v), shape generators turn positions into paths and
// frames (component_plot_shape.v), and plot_axis draws ticks, labels and grid
// lines (component_plot_axis.v). line_chart, bar_chart and area_chart
// (component_charts_cartesian*.v) are built from them, and an application can
// build its own chart from the same parts.

// PlotFormatFn writes a value as text: an axis tick label, a tooltip value.
pub type PlotFormatFn = fn (value f64) string

// PlotCurve says how a line, or the edge of an area, runs between its points.
pub enum PlotCurve {
	smooth      // a monotone cubic through every point that never overshoots them
	linear      // straight segments
	step_after  // level until the next point's x, then up or down to it
	step_before // up or down first, then level to the next point
	step        // changes halfway between the points
}

// The categorical palette: eight hues in a fixed order that keeps neighbors
// apart for color-blind readers, stepped separately for light and dark
// surfaces. A series keeps its slot whatever else is shown or hidden.
const plot_palette_light = [u32(0x2a78d6), 0xeb6834, 0x1baf7a, 0xeda100, 0xe87ba4, 0x008300, 0x4a3aa7,
	0xe34948]
const plot_palette_dark = [u32(0x3987e5), 0xd95926, 0x199e70, 0xc98500, 0xd55181, 0x008300, 0x9085e9,
	0xe66767]

// plot_theme_is_dark reports whether a theme draws on a dark surface, which is
// how the chart colors pick their steps.
pub fn plot_theme_is_dark(theme ComponentTheme) bool {
	return plot_luminance(theme.background) < 0.4
}

// plot_chart_palette is the theme's chart palette: GPUI Kit's chart.1 to
// chart.5, widened to eight distinguishable hues for multi-series charts.
pub fn plot_chart_palette(theme ComponentTheme) []u32 {
	return if plot_theme_is_dark(theme) {
		plot_palette_dark.clone()
	} else {
		plot_palette_light.clone()
	}
}

// plot_chart_color is the palette color of series `index`. Past the eighth
// series the colors repeat; fold the rest into an "Other" series instead.
pub fn plot_chart_color(theme ComponentTheme, index int) u32 {
	palette := if plot_theme_is_dark(theme) { plot_palette_dark } else { plot_palette_light }
	return palette[(if index < 0 { 0 } else { index }) % palette.len]
}

// plot_grid_color is the recessive hairline color of grid lines: GPUI Kit's
// chart.grid, a translucent border flattened onto the background.
pub fn plot_grid_color(theme ComponentTheme) u32 {
	return plot_mix(theme.border, theme.background, 0.55)
}

fn plot_mix(a u32, b u32, t f64) u32 {
	amount := math.max(0.0, math.min(1.0, t))
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := f64((a >> shift) & 0xff)
		to := f64((b >> shift) & 0xff)
		out |= u32(math.round(from + (to - from) * amount)) << shift
	}
	return out
}

fn plot_luminance(color u32) f64 {
	weights := [0.2126, 0.7152, 0.0722]
	mut sum := 0.0
	for i, shift in [u32(16), 8, 0] {
		channel := f64((color >> shift) & 0xff) / 255.0
		linear := if channel <= 0.03928 {
			channel / 12.92
		} else {
			math.pow((channel + 0.055) / 1.055, 2.4)
		}
		sum += weights[i] * linear
	}
	return sum
}

fn plot_finite(value f64) bool {
	return !math.is_nan(value) && !math.is_inf(value, 0)
}

// ── Numbers ────────────────────────────────────────────────────────

// plot_tick_decimals is how many decimals tick labels `step` apart need to
// tell each other apart: none for 50, one for 0.5, two for 0.25.
pub fn plot_tick_decimals(step f64) int {
	if !plot_finite(step) || step <= 0 {
		return 0
	}
	mut decimals := 0
	mut scaled := step
	for decimals < 10 && math.abs(scaled - math.round(scaled)) > 1e-9 * math.max(1.0, scaled) {
		scaled *= 10
		decimals++
	}
	return decimals
}

// plot_format_number writes value with `decimals` decimals and commas between
// thousands: 1,284 or 0.25. Negative zero reads as zero.
pub fn plot_format_number(value f64, decimals int) string {
	if math.is_nan(value) {
		return ''
	}
	if math.is_inf(value, 1) {
		return '∞'
	}
	if math.is_inf(value, -1) {
		return '-∞'
	}
	places := math.max(0, math.min(decimals, 12))
	scale := math.pow(10, f64(places))
	scaled := math.round(math.abs(value) * scale)
	if scaled >= 9.0e15 {
		return '${value:.0f}'
	}
	units := u64(scaled)
	whole := units / u64(scale)
	frac := units % u64(scale)
	digits := whole.str()
	mut grouped := []u8{cap: digits.len + digits.len / 3}
	for i, ch in digits.bytes() {
		if i > 0 && (digits.len - i) % 3 == 0 {
			grouped << `,`
		}
		grouped << ch
	}
	mut out := grouped.bytestr()
	if places > 0 {
		mut tail := frac.str()
		for tail.len < places {
			tail = '0' + tail
		}
		out += '.' + tail
	}
	return if value < 0 && units > 0 { '-' + out } else { out }
}

// plot_format_compact shortens large values the way dashboards label them:
// 950, 12.9K, 4.2M, 1.5B, keeping one decimal where it is not zero.
pub fn plot_format_compact(value f64) string {
	if !plot_finite(value) {
		return plot_format_number(value, 0)
	}
	magnitude := math.abs(value)
	for unit in [PlotCompactUnit{1e12, 'T'}, PlotCompactUnit{1e9, 'B'}, PlotCompactUnit{1e6, 'M'},
		PlotCompactUnit{1e3, 'K'}] {
		if magnitude >= unit.size * 0.9995 {
			short := value / unit.size
			decimals := if math.abs(short - math.round(short)) < 0.05 { 0 } else { 1 }
			return plot_format_number(short, decimals) + unit.suffix
		}
	}
	return plot_format_number(value, plot_tick_decimals(math.round(magnitude * 100) / 100))
}

struct PlotCompactUnit {
	size   f64
	suffix string
}

// plot_format_percent writes a share (0.25) as a percentage (25%).
pub fn plot_format_percent(share f64) string {
	percent := share * 100
	decimals := if math.abs(percent - math.round(percent)) < 0.05 { 0 } else { 1 }
	return plot_format_number(percent, decimals) + '%'
}

// plot_format_value is the default text of a data value: whole numbers bare,
// the rest to at most two decimals, with thousands separated.
pub fn plot_format_value(value f64) string {
	rounded := math.round(value * 100) / 100
	return plot_format_number(rounded, plot_tick_decimals(rounded))
}

fn plot_call_format(format PlotFormatFn, value f64, fallback string) string {
	if voidptr(format) == unsafe { nil } {
		return fallback
	}
	return format(value)
}
