module ui2

import math

// Shared pieces of the pie, radar, candlestick and sankey charts: their theme
// colors, legend, tooltip card, appear timing, hover glides and hover targets.
// Every chart is built from `shape` paths and ordinary views, so it draws the
// same on every backend.

// SpecialChartColors are what the pie, radar, candlestick and sankey charts draw
// with. special_chart_colors derives them from a ComponentTheme, so a chart
// follows the light or dark theme it is given.
pub struct SpecialChartColors {
pub:
	palette        []u32 // categorical series colors, in a fixed order
	surface        u32   // what the chart is drawn on
	text           u32   // values, titles, labels
	muted_text     u32   // axis ticks, captions, secondary labels
	grid           u32   // hairline grid rings, spokes and rules
	axis           u32   // axis lines and leader lines
	bullish        u32   // a candle that closed above its open
	bearish        u32   // a candle that closed at or below its open
	highlight      u32   // the hover band behind a candle
	tooltip        u32   // tooltip card fill
	tooltip_border u32
}

// The categorical palette, in an order whose neighbors stay apart for readers
// with color vision deficiencies; the dark steps are the same hues lifted for a
// dark surface.
const special_chart_light_palette = [u32(0x2a78d6), 0xeb6834, 0x1baf7a, 0xeda100, 0xe87ba4, 0x008300,
	0x4a3aa7, 0xe34948]
const special_chart_dark_palette = [u32(0x3987e5), 0xd95926, 0x199e70, 0xc98500, 0xd55181, 0x2f9e44,
	0x9085e9, 0xe66767]

// special_chart_colors returns the chart colors of a theme: the palette and
// candle colors by whether its background is dark, and the text, grid and
// tooltip colors from its own tokens.
pub fn special_chart_colors(theme ComponentTheme) SpecialChartColors {
	dark := special_chart_is_dark(theme.background)
	return SpecialChartColors{
		palette:        if dark {
			special_chart_dark_palette.clone()
		} else {
			special_chart_light_palette.clone()
		}
		surface:        theme.background
		text:           theme.foreground
		muted_text:     theme.muted_foreground
		grid:           special_chart_mix(theme.background, theme.border, if dark {
			0.55
		} else {
			0.5
		})
		axis:           special_chart_mix(theme.background, theme.muted_foreground, if dark {
			0.5
		} else {
			0.45
		})
		bullish:        if dark { u32(0x26b08f) } else { u32(0x089981) }
		bearish:        if dark { u32(0xf7525f) } else { u32(0xf23645) }
		highlight:      theme.foreground
		tooltip:        theme.background
		tooltip_border: special_chart_mix(theme.background, theme.border, 0.8)
	}
}

// special_chart_series_color is the palette color for the series, slice or
// node at `index`. Past the end of the palette the colors repeat; fold such
// series into an "Other" one where you can.
pub fn special_chart_series_color(colors SpecialChartColors, index int) u32 {
	if colors.palette.len == 0 {
		return colors.text
	}
	return colors.palette[(if index < 0 { 0 } else { index }) % colors.palette.len]
}

fn special_chart_channel(color u32, shift u32) f64 {
	return f64((color >> shift) & 0xff)
}

// special_chart_mix blends from `a` (t = 0) to `b` (t = 1), channel by channel.
pub fn special_chart_mix(a u32, b u32, t f64) u32 {
	k := math.clamp(t, 0.0, 1.0)
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		value := special_chart_channel(a, shift) * (1 - k) + special_chart_channel(b, shift) * k
		out |= u32(math.round(math.clamp(value, 0.0, 255.0))) << shift
	}
	return out
}

fn special_chart_linear(channel f64) f64 {
	c := channel / 255
	return if c <= 0.04045 { c / 12.92 } else { math.pow((c + 0.055) / 1.055, 2.4) }
}

// special_chart_luminance is the WCAG relative luminance of an RGB color.
fn special_chart_luminance(color u32) f64 {
	return 0.2126 * special_chart_linear(special_chart_channel(color, 16)) +
		0.7152 * special_chart_linear(special_chart_channel(color, 8)) +
		0.0722 * special_chart_linear(special_chart_channel(color, 0))
}

fn special_chart_is_dark(color u32) bool {
	return special_chart_luminance(color) < 0.2
}

// special_chart_ink_on picks white or near-black text for a label set inside a
// fill of `color`, whichever contrasts more.
pub fn special_chart_ink_on(color u32) u32 {
	l := special_chart_luminance(color)
	on_white := 1.05 / (l + 0.05)
	on_black := (l + 0.05) / (0.0 + 0.05)
	return if on_white >= on_black * 0.8 { u32(0xffffff) } else { u32(0x111827) }
}

// ── Text ──────────────────────────────────────────────────────────

// special_chart_font is the point size of a chart's labels for a component
// size: GPUI Kit's charts write their ticks and labels at 12.
fn special_chart_font(size ComponentSize) f64 {
	return match size {
		.small { 11 }
		.medium { 12 }
		.large { 14 }
	}
}

fn special_chart_line(font f64) f64 {
	return math.ceil(font * 1.4)
}

fn special_chart_text_style(color u32, font f64, bold bool, align Align) TextStyle {
	return TextStyle{
		color: color
		size:  font
		bold:  bold
		align: align
	}
}

fn special_chart_text_width(text string, font f64, bold bool) f64 {
	return measure_text_width(text, TextStyle{
		size: font
		bold: bold
	})
}

// special_chart_text is a one-line label. Centered text is drawn left-aligned
// in a frame cut to its measured width and centered where it was asked for:
// AppKit shortens a centered label exactly as wide as measure_text_width says
// its text is.
fn special_chart_text(text string, frame Rect, color u32, font f64, bold bool, align Align) Element {
	if align == .center {
		w := special_chart_text_width(text, font, bold)
		if w < frame.width {
			return label('', text, rect(frame.x + (frame.width - w) / 2, frame.y, w, frame.height),
				special_chart_text_style(color, font, bold, .left))
		}
		return label('', text, frame, special_chart_text_style(color, font, bold, .left))
	}
	return label('', text, frame, special_chart_text_style(color, font, bold, align))
}

// special_chart_format writes value with `decimals` digits after the point and
// commas between thousands: 12345.678 with 2 is "12,345.68".
pub fn special_chart_format(value f64, decimals int) string {
	if math.is_nan(value) || math.is_inf(value, 0) {
		return '-'
	}
	places := if decimals < 0 {
		0
	} else if decimals > 9 {
		9
	} else {
		decimals
	}
	mut scale := i64(1)
	for _ in 0 .. places {
		scale *= 10
	}
	scaled := i64(math.round(math.abs(value) * f64(scale)))
	whole := scaled / scale
	digits := whole.str()
	mut grouped := []u8{cap: digits.len + digits.len / 3}
	for i, ch in digits.bytes() {
		if i > 0 && (digits.len - i) % 3 == 0 {
			grouped << `,`
		}
		grouped << ch
	}
	mut out := if value < 0 && scaled > 0 { '-' } else { '' }
	out += grouped.bytestr()
	if places > 0 {
		fraction := (scaled % scale).str()
		out += '.' + '0'.repeat(places - fraction.len) + fraction
	}
	return out
}

// special_chart_auto_format writes a whole number without decimals and any
// other with up to two, trailing zeros dropped.
pub fn special_chart_auto_format(value f64) string {
	mut out := special_chart_format(value, 2)
	if out.contains('.') {
		out = out.trim_right('0').trim_right('.')
	}
	return out
}

// special_chart_compact shortens a large number: 1,284 stays, 12,900 is 12.9K,
// 4,200,000 is 4.2M.
pub fn special_chart_compact(value f64) string {
	magnitude := math.abs(value)
	for step in [SpecialChartUnit{1e12, 1e12, 'T'}, SpecialChartUnit{1e9, 1e9, 'B'},
		SpecialChartUnit{1e6, 1e6, 'M'}, SpecialChartUnit{1e4, 1e3, 'K'}] {
		if magnitude >= step.from {
			short := value / step.size
			short_text := if math.abs(short) >= 100 {
				special_chart_format(short, 0)
			} else {
				special_chart_auto_format(math.round(short * 10) / 10)
			}
			return short_text + step.suffix
		}
	}
	return special_chart_auto_format(value)
}

struct SpecialChartUnit {
	from   f64 // Smallest magnitude written with the suffix.
	size   f64
	suffix string
}

// special_chart_percent writes a share (0...1) as a percentage: one decimal
// under ten percent, none above.
pub fn special_chart_percent(share f64) string {
	percent := share * 100
	return if math.abs(percent) < 10 && math.round(percent) != percent {
		special_chart_format(percent, 1) + '%'
	} else {
		special_chart_format(percent, 0) + '%'
	}
}

// ── Scales ────────────────────────────────────────────────────────

// special_chart_nice_step is a round tick interval (1, 2, 2.5 or 5 times a
// power of ten) that cuts `span` into about `count` parts.
fn special_chart_nice_step(span f64, count int) f64 {
	if span <= 0 || !component_finite(span) {
		return 1
	}
	raw := span / f64(if count > 0 { count } else { 1 })
	magnitude := math.pow(10, math.floor(math.log10(raw)))
	norm := raw / magnitude
	nice := if norm <= 1 {
		1.0
	} else if norm <= 2 {
		2.0
	} else if norm <= 2.5 {
		2.5
	} else if norm <= 5 {
		5.0
	} else {
		10.0
	}
	return nice * magnitude
}

// special_chart_tick_values lists the multiples of `step` from lo to hi.
fn special_chart_tick_values(lo f64, hi f64, step f64) []f64 {
	mut values := []f64{}
	if step <= 0 || hi < lo {
		return values
	}
	first := math.ceil(lo / step - 1e-9)
	last := math.floor(hi / step + 1e-9)
	if last - first > 1000 {
		return values
	}
	for k := first; k <= last; k += 1 {
		v := k * step
		values << if math.abs(v) < step * 1e-9 { 0.0 } else { v }
	}
	return values
}

// special_chart_decimals is how many decimals tick labels `step` apart need.
fn special_chart_decimals(step f64) int {
	mut decimals := 0
	mut s := step
	for decimals < 6 && math.abs(s - math.round(s)) > 1e-6 * math.max(1.0, math.abs(s)) {
		s *= 10
		decimals++
	}
	return decimals
}

// ── Layout helpers ────────────────────────────────────────────────

// special_chart_spread moves label centers apart so neighbors are at least
// `gap` apart and every center stays within top...bottom, moving them as
// little as it can: each run of labels that would overlap is laid out as one
// block centered on where its labels want to be. Centers come back in the
// order they were given.
pub fn special_chart_spread(centers []f64, gap f64, top f64, bottom f64) []f64 {
	n := centers.len
	if n == 0 {
		return []f64{}
	}
	mut order := []int{len: n, init: index}
	order.sort_with_compare(fn [centers] (a &int, b &int) int {
		if centers[*a] < centers[*b] {
			return -1
		}
		if centers[*a] > centers[*b] {
			return 1
		}
		return if *a < *b {
			-1
		} else if *a > *b {
			1
		} else {
			0
		}
	})
	// A block of `count` labels starting at sorted position `first` sits with its
	// first center at `sum / count`: the mean of where each would put it.
	mut blocks := []SpecialChartBlock{}
	for i, index in order {
		blocks << SpecialChartBlock{
			first: i
			count: 1
			sum:   centers[index]
		}
		blocks[blocks.len - 1] = special_chart_block_clamp(blocks[blocks.len - 1], gap, top, bottom)
		for blocks.len > 1 {
			last := blocks[blocks.len - 1]
			previous := blocks[blocks.len - 2]
			if previous.start + f64(previous.count) * gap <= last.start + 1e-9 {
				break
			}
			merged := SpecialChartBlock{
				first: previous.first
				count: previous.count + last.count
				sum:   previous.sum + last.sum - f64(last.count * previous.count) * gap
			}
			blocks.delete_last()
			blocks[blocks.len - 1] = special_chart_block_clamp(merged, gap, top, bottom)
		}
	}
	mut out := []f64{len: n}
	for block in blocks {
		for k in 0 .. block.count {
			out[order[block.first + k]] = block.start + f64(k) * gap
		}
	}
	return out
}

struct SpecialChartBlock {
	first int
	count int
	sum   f64
	start f64
}

fn special_chart_block_clamp(block SpecialChartBlock, gap f64, top f64, bottom f64) SpecialChartBlock {
	lowest := bottom - f64(block.count - 1) * gap
	mut start := block.sum / f64(block.count)
	if start > lowest {
		start = lowest
	}
	if start < top {
		start = top
	}
	return SpecialChartBlock{
		...block
		start: start
	}
}

// ── Legend ────────────────────────────────────────────────────────

// SpecialChartLegendPosition is where a chart puts its legend.
pub enum SpecialChartLegendPosition {
	none
	bottom
	top
	right
}

// SpecialChartMarker is how a legend item shows its color: a square for
// filled marks, a short line for lines, a dot for points.
pub enum SpecialChartMarker {
	square
	line
	dot
}

pub struct SpecialChartLegendItem {
pub:
	label  string
	value  string // Muted text after the label, such as a share.
	color  u32
	marker SpecialChartMarker
	action string // Hover action: pointing at the item hovers what it stands for.
	dimmed bool   // Faded behind another hovered item.
}

const special_chart_legend_marker = 10.0
const special_chart_legend_gap = 16.0

fn special_chart_legend_item_width(item SpecialChartLegendItem, font f64) f64 {
	mut w := special_chart_legend_marker + 6 + special_chart_text_width(item.label, font, false)
	if item.value.len > 0 {
		w += 4 + special_chart_text_width(item.value, font, false)
	}
	return math.ceil(w)
}

// special_chart_legend_layout places legend items in rows at most `width`
// wide, each row centered, or in one column when `vertical`. Frames are
// relative to the legend's top-left corner.
pub fn special_chart_legend_layout(items []SpecialChartLegendItem, width f64, font f64, vertical bool) []Rect {
	line := special_chart_line(font)
	mut frames := []Rect{cap: items.len}
	if vertical {
		for i, item in items {
			frames << rect(0, f64(i) * (line + 4), math.min(width, special_chart_legend_item_width(item,
				font)), line)
		}
		return frames
	}
	mut row := []int{}
	mut row_width := 0.0
	mut y := 0.0
	for i, item in items {
		w := math.min(width, special_chart_legend_item_width(item, font))
		needed := if row.len == 0 { w } else { row_width + special_chart_legend_gap + w }
		if row.len > 0 && needed > width {
			special_chart_legend_center_row(mut frames, row, row_width, width)
			row.clear()
			row_width = 0
			y += line + 4
		}
		x := if row.len == 0 { 0.0 } else { row_width + special_chart_legend_gap }
		frames << rect(x, y, w, line)
		row << i
		row_width = x + w
	}
	special_chart_legend_center_row(mut frames, row, row_width, width)
	return frames
}

fn special_chart_legend_center_row(mut frames []Rect, row []int, row_width f64, width f64) {
	offset := math.max(0.0, (width - row_width) / 2)
	for i in row {
		frames[i] = rect(frames[i].x + offset, frames[i].y, frames[i].width, frames[i].height)
	}
}

// special_chart_legend_extent is the size of a laid out legend.
fn special_chart_legend_extent(frames []Rect) (f64, f64) {
	mut w, mut h := 0.0, 0.0
	for f in frames {
		w = math.max(w, f.x + f.width)
		h = math.max(h, f.y + f.height)
	}
	return w, h
}

// special_chart_legend_area splits a chart's frame into the plot and the
// legend, for a legend at `position`. Both are in the chart's local
// coordinates; the frames place the items within the legend area.
fn special_chart_legend_area(local Rect, items []SpecialChartLegendItem, position SpecialChartLegendPosition, font f64) (Rect, Rect, []Rect) {
	if position == .none || items.len == 0 {
		return local, Rect{}, []Rect{}
	}
	if position == .right {
		frames := special_chart_legend_layout(items, local.width * 0.4, font, true)
		w, h := special_chart_legend_extent(frames)
		area := rect(local.x + local.width - w, local.y + math.max(0.0, (local.height - h) / 2), w,
			math.min(h, local.height))
		return rect(local.x, local.y, math.max(0.0, local.width - w - 16), local.height), area, frames
	}
	frames := special_chart_legend_layout(items, local.width, font, false)
	_, h := special_chart_legend_extent(frames)
	if position == .top {
		return rect(local.x, local.y + h + 10, local.width, math.max(0.0, local.height - h - 10)), rect(local.x,
			local.y, local.width, h), frames
	}
	return rect(local.x, local.y, local.width, math.max(0.0, local.height - h - 10)), rect(local.x,
		local.y + local.height - h, local.width, h), frames
}

// special_chart_legend draws legend items at their frames inside `area`.
fn special_chart_legend(area Rect, frames []Rect, items []SpecialChartLegendItem, colors SpecialChartColors, font f64) []Element {
	mut out := []Element{cap: items.len}
	line := special_chart_line(font)
	for i, item in items {
		if i >= frames.len {
			break
		}
		f := frames[i]
		m := special_chart_legend_marker
		marker_box := match item.marker {
			.square {
				BoxStyle{
					bg:     item.color
					radius: 2
				}
			}
			.line {
				BoxStyle{
					bg:     item.color
					radius: 1
				}
			}
			.dot {
				BoxStyle{
					bg:     item.color
					radius: m / 2
				}
			}
		}
		marker_frame := if item.marker == .line {
			rect(0, (line - 2) / 2, m, 2)
		} else {
			rect(0, (line - m) / 2, m, m)
		}
		mut parts := []Element{}
		parts << view('', marker_frame, BoxStyle{
			...marker_box
			opacity: if item.dimmed { 0.35 } else { 1.0 }
		}, []Element{})
		label_x := m + 6
		label_w := special_chart_text_width(item.label, font, false)
		parts << special_chart_text(item.label, rect(label_x, 0, math.min(label_w, f.width - label_x),
			line), if item.dimmed { colors.muted_text } else { colors.text }, font, false, .left)
		if item.value.len > 0 {
			value_x := label_x + label_w + 4
			parts << special_chart_text(item.value, rect(value_x, 0, math.max(0.0, f.width - value_x),
				line), colors.muted_text, font, false, .left)
		}
		out << Element{
			...view('', rect(area.x + f.x, area.y + f.y, f.width, f.height), BoxStyle{
				transparent: true
			}, parts)
			action_id:           item.action
			hoverable:           item.action.len > 0
			accessibility_label: if item.value.len > 0 {
				'${item.label}, ${item.value}'
			} else {
				item.label
			}
		}
	}
	return out
}

// ── Tooltip ───────────────────────────────────────────────────────

// SpecialChartTooltipRow is one line of a chart tooltip: a short line key in
// the series color, a name and the value, which is what the reader is after
// and so is drawn stronger than the name.
pub struct SpecialChartTooltipRow {
pub:
	color       ?u32 // The series color; none for a row without a key, such as a total.
	name        string
	value       string
	value_color ?u32 // Colors the value, such as green or red by its sign.
}

const special_chart_tooltip_pad_x = 10.0
const special_chart_tooltip_pad_y = 8.0
const special_chart_tooltip_key = 12.0

// special_chart_tooltip_size is how big the card for a title and rows is.
pub fn special_chart_tooltip_size(title string, rows []SpecialChartTooltipRow, font f64) (f64, f64) {
	line := special_chart_line(font)
	mut name_w, mut value_w := 0.0, 0.0
	mut keyed := false
	for row in rows {
		name_w = math.max(name_w, special_chart_text_width(row.name, font, false))
		value_w = math.max(value_w, special_chart_text_width(row.value, font, true))
		if _ := row.color {
			keyed = true
		}
	}
	key_w := if keyed { special_chart_tooltip_key + 6 } else { 0.0 }
	gap := if name_w > 0 && value_w > 0 { 16.0 } else { 0.0 }
	mut w := key_w + name_w + gap + value_w
	if title.len > 0 {
		w = math.max(w, special_chart_text_width(title, font, true))
	}
	mut h := f64(rows.len) * line
	if title.len > 0 {
		h += line + if rows.len > 0 { 2.0 } else { 0.0 }
	}
	return math.ceil(w + 2 * special_chart_tooltip_pad_x), math.ceil(h + 2 * special_chart_tooltip_pad_y)
}

// special_chart_tooltip_place puts a card `width` by `height` beside `anchor`,
// `gap` away: on its right, or on its left when `prefer_left` or when the right
// has no room, vertically centered on it, and kept inside `bounds`.
pub fn special_chart_tooltip_place(anchor Rect, width f64, height f64, bounds Rect, gap f64, prefer_left bool) Rect {
	right_x := anchor.x + anchor.width + gap
	left_x := anchor.x - gap - width
	fits_right := right_x + width <= bounds.x + bounds.width
	fits_left := left_x >= bounds.x
	mut x := if prefer_left {
		if fits_left || !fits_right { left_x } else { right_x }
	} else {
		if fits_right || !fits_left { right_x } else { left_x }
	}
	x = math.max(bounds.x, math.min(x, bounds.x + bounds.width - width))
	mut y := anchor.y + anchor.height / 2 - height / 2
	y = math.max(bounds.y, math.min(y, bounds.y + bounds.height - height))
	return rect(x, y, width, height)
}

// special_chart_tooltip draws the card: an optional bold title over the rows.
fn special_chart_tooltip(id string, frame Rect, title string, rows []SpecialChartTooltipRow, colors SpecialChartColors, font f64) Element {
	line := special_chart_line(font)
	mut keyed := false
	mut name_w := 0.0
	for row in rows {
		name_w = math.max(name_w, special_chart_text_width(row.name, font, false))
		if _ := row.color {
			keyed = true
		}
	}
	key_w := if keyed { special_chart_tooltip_key + 6 } else { 0.0 }
	inner_w := frame.width - 2 * special_chart_tooltip_pad_x
	mut children := []Element{}
	mut y := special_chart_tooltip_pad_y
	mut spoken := []string{}
	if title.len > 0 {
		children << special_chart_text(title, rect(special_chart_tooltip_pad_x, y, inner_w, line),
			colors.text, font, true, .left)
		y += line + if rows.len > 0 { 2.0 } else { 0.0 }
		spoken << title
	}
	for row in rows {
		x := special_chart_tooltip_pad_x
		if color := row.color {
			children << view('', rect(x, y + line / 2 - 1, special_chart_tooltip_key, 2), BoxStyle{
				bg:     color
				radius: 1
			}, []Element{})
		}
		if row.name.len > 0 {
			children << special_chart_text(row.name, rect(x + key_w, y, name_w, line), colors.muted_text,
				font, false, .left)
		}
		value_x := x + key_w + name_w
		children << special_chart_text(row.value, rect(value_x, y, math.max(0.0, x + inner_w - value_x),
			line), row.value_color or { colors.text }, font, true, .right)
		spoken << if row.name.len > 0 { '${row.name} ${row.value}' } else { row.value }
		y += line
	}
	return Element{
		...view(id, frame, BoxStyle{
			bg:            colors.tooltip
			radius:        6
			border_color:  colors.tooltip_border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        component_card_shadow()
		}, children)
		accessibility_role:  'tooltip'
		accessibility_label: spoken.join(', ')
	}
}

// ── Motion ────────────────────────────────────────────────────────

// special_chart_ease_out_quart is Chart.js's default curve, which the charts
// draw in on.
fn special_chart_ease_out_quart(t f64) f64 {
	u := 1 - math.clamp(t, 0.0, 1.0)
	return 1 - u * u * u * u
}

// special_chart_appear says how far a chart has drawn in, 0 to 1, eased. The
// first build of `id` with a given `key` starts a run on a hidden element that
// the returned driver puts in the tree; the build reads the run's progress, so
// every frame of the appear is laid out afresh, and after the run the chart
// stays whole. With `enabled` off or `reduce_motion` on, the chart is whole at
// once and does not draw in later. A new key draws the chart in again.
fn special_chart_appear(id string, key string, enabled bool, reduce_motion bool, duration f64) (f64, Element) {
	part := component_part_id(id, 'appear:${key}')
	driver := Element{
		...view(part, rect(0, 0, 0, 0), BoxStyle{ transparent: true }, []Element{})
		hidden: true
	}
	info := animation_info(part)
	match info.status {
		.idle {
			special_chart_clear_parts(id, 'appear:', part)
			seconds := if enabled && !reduce_motion && duration > 0 { duration } else { 0.0 }
			animation(
				duration:   seconds
				properties: [animation_number_property('box.opacity', 1)]
			).start(part)
			return if seconds > 0 { 0.0 } else { 1.0 }, driver
		}
		.running {
			if reduce_motion || info.duration <= 0 {
				if reduce_motion {
					stop_animation(part)
				}
				return 1.0, driver
			}
			return special_chart_ease_out_quart(info.progress), driver
		}
		else {
			return 1.0, driver
		}
	}
}

// special_chart_clear_parts releases the animation runs a chart left on parts
// of one group, except `keep`.
fn special_chart_clear_parts(id string, group string, keep string) {
	prefix := component_part_id(id, group)
	if prefix.len == 0 {
		return
	}
	mut stale := []string{}
	runtime := g_animation_runtime
	runtime.mutex.lock()
	for key, _ in runtime.runs {
		if key.starts_with(prefix) && key != keep {
			stale << key
		}
	}
	runtime.mutex.unlock()
	for key in stale {
		clear_animation(key)
	}
}

// special_chart_glide_target is where the last glide sent element `id`.
fn special_chart_glide_target(id string) ?PathPoint {
	runtime := g_animation_runtime
	runtime.mutex.lock()
	defer {
		runtime.mutex.unlock()
	}
	if id !in runtime.runs {
		return none
	}
	definition := runtime.runs[id].definition
	if definition.kind != .tween {
		return none
	}
	x := definition.targets.x or { return none }
	y := definition.targets.y or { return none }
	return path_point(x, y)
}

// special_chart_glide moves the origin of element `id` to (x, y): placed there
// the first time, and after special_chart_glide_reset, and sliding there over
// `duration` seconds when it changes later, as hover marks follow the pointer.
// The element must be declared at (x, y). A zero duration jumps.
fn special_chart_glide(id string, x f64, y f64, duration f64) {
	current := special_chart_glide_target(id)
	if duration <= 0 {
		if _ := current {
			clear_animation(id)
		}
		return
	}
	if previous := current {
		if math.abs(previous.x - x) > 1e-6 || math.abs(previous.y - y) > 1e-6 {
			animation(duration: duration, transition: .out_cubic, x: x, y: y).start(id)
		}
		return
	}
	animation(duration: 0, x: x, y: y).start(id)
}

// special_chart_glide_reset forgets where `id` was, so the next glide places it
// rather than sliding it from where it was last shown.
fn special_chart_glide_reset(id string) {
	if _ := special_chart_glide_target(id) {
		clear_animation(id)
	}
}

const special_chart_glide_seconds = 0.18

// ── Hover ─────────────────────────────────────────────────────────

// SpecialChartHitRect is one rectangle of a hover target: the pointer over it
// hovers datum `index`.
pub struct SpecialChartHitRect {
pub:
	frame Rect
	index int
}

// special_chart_hit_strips covers the parts of `bounds` that `classify` puts in
// a datum (an index of 0 or more) with rectangles: strips `strip` tall, sampled
// every `step` along their middle line, runs of one datum merged across and
// down. ui2 hit-tests views by their frames, so a slice or a polygon answers
// the pointer through such a cover.
pub fn special_chart_hit_strips(bounds Rect, strip f64, step f64, classify fn (f64, f64) int) []SpecialChartHitRect {
	mut out := []SpecialChartHitRect{}
	if bounds.width <= 0 || bounds.height <= 0 || strip <= 0 || step <= 0 {
		return out
	}
	rows := int(math.ceil(bounds.height / strip - 1e-9))
	cols := int(math.ceil(bounds.width / step - 1e-9))
	mut previous := []int{}
	for r in 0 .. rows {
		y0 := bounds.y + f64(r) * strip
		h := math.min(strip, bounds.y + bounds.height - y0)
		cy := y0 + h / 2
		mut current := []int{}
		mut run_index := -1
		mut run_start := bounds.x
		for c in 0 .. cols + 1 {
			x0 := if c < cols { bounds.x + f64(c) * step } else { bounds.x + bounds.width }
			index := if c < cols {
				classify(x0 + math.min(step, bounds.x + bounds.width - x0) / 2, cy)
			} else {
				-1
			}
			if index == run_index {
				continue
			}
			if run_index >= 0 {
				piece := rect(run_start, y0, x0 - run_start, h)
				mut merged := false
				for p in previous {
					q := out[p].frame
					if out[p].index == run_index && math.abs(q.x - piece.x) < 1e-9
						&& math.abs(q.width - piece.width) < 1e-9
						&& math.abs(q.y + q.height - y0) < 1e-9 {
						out[p] = SpecialChartHitRect{
							frame: rect(q.x, q.y, q.width, q.height + h)
							index: run_index
						}
						current << p
						merged = true
						break
					}
				}
				if !merged {
					out << SpecialChartHitRect{
						frame: piece
						index: run_index
					}
					current << out.len - 1
				}
			}
			run_index = index
			run_start = x0
		}
		previous = current.clone()
	}
	return out
}

// special_chart_hit_view is a transparent hover target. Every target of one
// datum carries the same action, and hover is tracked by action, so moving
// between them keeps the datum hovered.
fn special_chart_hit_view(frame Rect, action string) Element {
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, []Element{})
		action_id: action
		hoverable: true
	}
}

fn special_chart_hover_action(id string, target string) string {
	return component_part_id(id, 'hover:${target}')
}

// special_chart_hover_event reads a pointer enter or leave event of one of
// chart `id`'s hover targets: whether the pointer entered, and the target's
// name. Any other event gives none.
fn special_chart_hover_event(id string, event string) ?(bool, string) {
	ev := parse_pointer_event(event) or { return none }
	if ev.phase != 'enter' && ev.phase != 'leave' {
		return none
	}
	part := component_action_part(id, ev.action) or { return none }
	if !part.starts_with('hover:') || part.len == 'hover:'.len {
		return none
	}
	return ev.phase == 'enter', part['hover:'.len..]
}

// special_chart_keys gives every datum its identity: its own key, else its
// label, else its position. Two data with one identity are an error.
fn special_chart_keys(keys []string, labels []string, what string) ![]string {
	mut out := []string{cap: keys.len}
	mut seen := map[string]bool{}
	for i, key in keys {
		resolved := if key.len > 0 {
			key
		} else if i < labels.len && labels[i].len > 0 {
			labels[i]
		} else {
			i.str()
		}
		if resolved in seen {
			return error('${what} key `${resolved}` is not unique')
		}
		seen[resolved] = true
		out << resolved
	}
	return out
}

fn special_chart_validate_length(name string, value f64) ! {
	if !component_finite(value) || value < 0 {
		return error('${name} must be finite and non-negative')
	}
}
