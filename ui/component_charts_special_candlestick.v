module ui2

import math

// Candle is one period of a candlestick chart: its open, high, low and close
// prices, and optionally what traded.
pub struct Candle {
pub:
	key    string // Stable identity for hover; defaults to the label.
	label  string // The period on the x axis, such as a date.
	open   f64
	high   f64
	low    f64
	close  f64
	volume f64 // Drawn as a bar under the candles when the chart shows volume.
}

pub struct CandlestickChartConfig {
pub:
	id      string // Required: hover targets and the appear use parts of it.
	frame   Rect
	candles []Candle
	// body_width_ratio is how much of a candle's band its body fills, 0...1.
	body_width_ratio f64 = 0.7
	max_band_width   f64 = 30 // A few candles across a wide chart stay this narrow.
	// tick_margin labels every nth candle on the x axis; zero spaces the labels
	// by their measured widths.
	tick_margin int
	volume      bool // Volume bars in a pane under the candles.
	// volume_ratio is the share of the plot's height the volume pane takes.
	volume_ratio f64 = 0.22
	// moving_averages are periods of simple moving averages of the close, each
	// drawn as a line over the candles.
	moving_averages       []int
	moving_average_colors []u32 // Defaults to the theme palette.
	price_decimals        int  = 2 // In the tooltip and the price tag.
	y_ticks               int  = 5 // About how many price ticks.
	grid                  bool = true
	x_axis                bool = true
	y_axis                bool = true // Price ticks on the right, as trading charts put them.
	legend                bool = true // Moving average keys above the plot.
	// bullish and bearish color candles that closed above, and at or below,
	// their open. Markets that read a rise as red swap them.
	bullish ?u32
	bearish ?u32
	// hovered is the key of the candle under the pointer: a band marks it, a
	// tag shows its close on the price axis and the tooltip lists its prices.
	// Keep it with candlestick_chart_hover_from_event.
	hovered         string
	interactive     bool = true
	appear          bool = true // Reveal the candles from the left the first time.
	appear_key      string
	appear_duration f64 = 1.0
	reduce_motion   bool
	title           string // Accessibility label; "Candlestick chart" by default.
	size            ComponentSize = .medium
	theme           ComponentTheme
}

// CandlestickLayout is where a candlestick chart's parts go, in the chart's
// local coordinates.
pub struct CandlestickLayout {
pub:
	price      Rect // The candles' pane.
	volume     Rect // The volume pane; empty without volume.
	axis       Rect // The price axis labels.
	x_labels   Rect // The x axis labels.
	legend     Rect // The moving average keys.
	step       f64  // How far apart candles are.
	band       f64  // How wide a candle's band is: step, at most max_band_width.
	first      f64  // Center of the first candle.
	lo         f64  // The price at the bottom of the price pane.
	hi         f64  // The price at its top.
	tick_step  f64
	tick_label []string
	tick_value []f64
}

fn candlestick_keys(candles []Candle) ![]string {
	return special_chart_keys(candles.map(it.key), candles.map(it.label), 'candle')
}

// candlestick_moving_average is the simple moving average of the closes over
// `period` candles; candles before the first full period are NaN.
pub fn candlestick_moving_average(candles []Candle, period int) []f64 {
	mut out := []f64{len: candles.len, init: math.nan()}
	if period < 1 {
		return out
	}
	mut sum := 0.0
	for i, c in candles {
		sum += c.close
		if i >= period {
			sum -= candles[i - period].close
		}
		if i >= period - 1 {
			out[i] = sum / f64(period)
		}
	}
	return out
}

// candlestick_price_range is the price span the candles (and any moving
// averages) cover, with a little room above and below.
pub fn candlestick_price_range(candles []Candle, averages [][]f64) (f64, f64) {
	mut lo, mut hi := math.max_f64, -math.max_f64
	for c in candles {
		lo = math.min(lo, c.low)
		hi = math.max(hi, c.high)
	}
	for series in averages {
		for v in series {
			if !math.is_nan(v) {
				lo = math.min(lo, v)
				hi = math.max(hi, v)
			}
		}
	}
	if lo > hi {
		return 0, 1
	}
	if hi - lo < 1e-9 {
		pad := math.max(math.abs(hi) * 0.01, 1.0)
		return lo - pad, hi + pad
	}
	pad := (hi - lo) * 0.06
	return lo - pad, hi + pad
}

// candlestick_label_interval is how many candles apart x labels must be for
// labels `widest` wide to keep 12 points between them, `step` apart.
pub fn candlestick_label_interval(widest f64, step f64) int {
	if step <= 0 {
		return 1
	}
	return int(math.max(1.0, math.ceil((widest + 12) / step)))
}

fn candlestick_validate(config CandlestickChartConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	candlestick_keys(config.candles)!
	for c in config.candles {
		for v in [c.open, c.high, c.low, c.close, c.volume] {
			if !component_finite(v) {
				return error('candle prices and volume must be finite')
			}
		}
		if c.low > math.min(c.open, c.close) || c.high < math.max(c.open, c.close) {
			return error('candle `${c.label}` must have low <= open, close <= high')
		}
		if c.volume < 0 {
			return error('candle volume must not be negative')
		}
	}
	for p in config.moving_averages {
		if p < 1 {
			return error('moving average periods must be at least 1')
		}
	}
	if !component_finite(config.body_width_ratio) || config.body_width_ratio <= 0
		|| config.body_width_ratio > 1 {
		return error('candlestick body_width_ratio must be in (0, 1]')
	}
	if !component_finite(config.volume_ratio) || config.volume_ratio <= 0
		|| config.volume_ratio >= 1 {
		return error('candlestick volume_ratio must be in (0, 1)')
	}
	if config.tick_margin < 0 || config.y_ticks < 1 || config.price_decimals < 0
		|| config.price_decimals > 9 {
		return error('candlestick tick_margin, y_ticks and price_decimals are out of range')
	}
	special_chart_validate_length('candlestick max_band_width', config.max_band_width)!
	special_chart_validate_length('candlestick appear_duration', config.appear_duration)!
}

// candlestick_layout places a candlestick chart's panes, axes and candles in
// a frame `width` by `height`.
pub fn candlestick_layout(config CandlestickChartConfig, width f64, height f64) CandlestickLayout {
	font := special_chart_font(config.size)
	line := special_chart_line(font)
	averages := config.moving_averages.map(candlestick_moving_average(config.candles, it))
	lo, hi := candlestick_price_range(config.candles, averages)
	tick_step := special_chart_nice_step(hi - lo, config.y_ticks)
	tick_value := special_chart_tick_values(lo, hi, tick_step)
	decimals := special_chart_decimals(tick_step)
	tick_label := tick_value.map(special_chart_format(it, decimals))
	mut axis_w := 0.0
	if config.y_axis {
		for t in tick_label {
			axis_w = math.max(axis_w, special_chart_text_width(t, font, false))
		}
		// Room for the hovered close's tag too, which has every decimal.
		tag_width := special_chart_text_width(special_chart_format(hi, config.price_decimals), font,
			true) + 8
		axis_w = math.ceil(math.max(axis_w + 10, tag_width + 4))
	}
	legend_h := if config.legend && config.moving_averages.len > 0 { line + 8 } else { 0.0 }
	x_h := if config.x_axis { line + 6 } else { 0.0 }
	plot := rect(0, legend_h, math.max(0.0, width - axis_w), math.max(0.0, height - legend_h - x_h))
	mut price := plot
	mut volume := Rect{}
	if config.volume {
		volume_h := math.round(plot.height * config.volume_ratio)
		gap := 8.0
		price = rect(plot.x, plot.y, plot.width, math.max(0.0, plot.height - volume_h - gap))
		volume = rect(plot.x, price.y + price.height + gap, plot.width, math.max(0.0, volume_h))
	}
	n := config.candles.len
	step := if n > 0 { plot.width / f64(n) } else { 0.0 }
	band := if config.max_band_width > 0 { math.min(step, config.max_band_width) } else { step }
	// Candles narrower than their share of the width are centered as a group.
	first := plot.x + (plot.width - band * f64(n)) / 2 + band / 2
	return CandlestickLayout{
		price:      price
		volume:     volume
		axis:       rect(plot.x + plot.width, plot.y, axis_w, plot.height)
		x_labels:   rect(plot.x, plot.y + plot.height + 4, plot.width, x_h)
		legend:     rect(0, 0, width, legend_h)
		step:       band
		band:       band
		first:      first
		lo:         lo
		hi:         hi
		tick_step:  tick_step
		tick_label: tick_label
		tick_value: tick_value
	}
}

// candlestick_center is the x of candle `index`'s middle.
pub fn (layout CandlestickLayout) candlestick_center(index int) f64 {
	return layout.first + f64(index) * layout.step
}

// price_y is where `price` falls in the price pane.
pub fn (layout CandlestickLayout) price_y(price f64) f64 {
	span := layout.hi - layout.lo
	t := if span > 0 { (layout.hi - price) / span } else { 0.5 }
	return layout.price.y + t * layout.price.height
}

fn candlestick_colors(config CandlestickChartConfig, colors SpecialChartColors) (u32, u32) {
	return config.bullish or { colors.bullish }, config.bearish or { colors.bearish }
}

fn candlestick_average_color(config CandlestickChartConfig, colors SpecialChartColors, index int) u32 {
	if index < config.moving_average_colors.len {
		return config.moving_average_colors[index]
	}
	// The first palette colors are kept for series; averages start further in,
	// clear of the up and down colors.
	return special_chart_series_color(colors, [0, 3, 6, 4, 1][index % 5])
}

// candlestick_change is a candle's move from the previous close (or from its
// own open, for the first candle), and that move as a share.
pub fn candlestick_change(candles []Candle, index int) (f64, f64) {
	c := candles[index]
	base := if index > 0 { candles[index - 1].close } else { c.open }
	delta := c.close - base
	return delta, if base != 0 { delta / base } else { 0.0 }
}

fn candlestick_signed(value f64, decimals int) string {
	text_value := special_chart_format(value, decimals)
	return if value > 0 { '+' + text_value } else { text_value }
}

// candlestick_chart builds GPUI Kit's CandlestickChart with a price axis,
// optional volume bars and moving averages, and a hover band, price tag and
// OHLC tooltip. It is controlled: keep `hovered` with
// candlestick_chart_hover_from_event.
pub fn candlestick_chart(config CandlestickChartConfig) !Element {
	candlestick_validate(config)!
	keys := candlestick_keys(config.candles)!
	colors := special_chart_colors(config.theme)
	font := special_chart_font(config.size)
	line := special_chart_line(font)
	local := component_local(config.frame)
	layout := candlestick_layout(config, local.width, local.height)
	bull, bear := candlestick_colors(config, colors)
	n := config.candles.len
	progress, driver := special_chart_appear(config.id, config.appear_key, config.appear,
		config.reduce_motion, config.appear_duration)
	whole := progress >= 1
	hovered := if config.interactive && whole && config.hovered.len > 0 {
		keys.index(config.hovered)
	} else {
		-1
	}
	price := layout.price
	plot := rect(price.x, price.y, price.width, (if config.volume {
		layout.volume.y + layout.volume.height
	} else {
		price.y + price.height
	}) - price.y)
	mut children := []Element{}
	children << driver
	// Grid lines at the price ticks, and the axis rules.
	mut rules := []PathCommand{}
	if config.grid {
		for v in layout.tick_value {
			y := math.round(layout.price_y(v)) + 0.5
			rules << path_move_to(price.x, y)
			rules << path_line_to(price.x + price.width, y)
		}
	}
	if rules.len > 0 {
		children << shape(component_part_id(config.id, 'grid'), local, rules, ShapeStyle{
			stroke:       colors.grid
			stroke_width: 1
		})
	}
	mut axes := []PathCommand{}
	if config.x_axis {
		y := math.round(plot.y + plot.height) + 0.5
		axes << path_move_to(plot.x, y)
		axes << path_line_to(plot.x + plot.width, y)
	}
	if config.volume {
		y := math.round(layout.volume.y) - 3.5
		axes << path_move_to(plot.x, y)
		axes << path_line_to(plot.x + plot.width, y)
	}
	if axes.len > 0 {
		children << shape(component_part_id(config.id, 'axes'), local, axes, ShapeStyle{
			stroke:       colors.grid
			stroke_width: 1
		})
	}
	// The hover band sits behind the candles and slides between them.
	band_id := component_part_id(config.id, 'band')
	glide := if config.reduce_motion { 0.0 } else { special_chart_glide_seconds }
	if hovered >= 0 {
		bx := layout.candlestick_center(hovered) - layout.band / 2
		special_chart_glide(band_id, bx, plot.y, glide)
		children << view(band_id, rect(bx, plot.y, layout.band, plot.height), BoxStyle{
			bg:      colors.highlight
			opacity: if special_chart_is_dark(colors.surface) { 0.1 } else { 0.06 }
			radius:  2
		}, []Element{})
	} else {
		special_chart_glide_reset(band_id)
	}
	// Candles, volume and averages, revealed from the left as the chart appears:
	// a candle shows once the edge passes its middle, and the averages run up
	// to the edge.
	reveal := plot.width * progress
	edge := plot.x + reveal
	if n > 0 && reveal > 0 && price.height > 0 {
		pane := price
		body_w := math.max(1.0, math.round(layout.band * config.body_width_ratio))
		mut wicks := [][]PathCommand{len: 2}
		mut bodies := [][]PathCommand{len: 2}
		for i, c in config.candles {
			if layout.candlestick_center(i) > edge {
				break
			}
			side := if c.close > c.open { 0 } else { 1 }
			x := math.round(layout.candlestick_center(i)) - price.x
			top := layout.price_y(c.high) - price.y
			bottom := layout.price_y(c.low) - price.y
			wicks[side] << path_move_to(x, top)
			wicks[side] << path_line_to(x, bottom)
			y0 := layout.price_y(math.max(c.open, c.close)) - price.y
			y1 := layout.price_y(math.min(c.open, c.close)) - price.y
			h := math.max(1.0, y1 - y0)
			bodies[side] << path_rect(rect(x - body_w / 2, y0, body_w, h))
		}
		for side, name in ['up', 'down'] {
			color := if side == 0 { bull } else { bear }
			if wicks[side].len > 0 {
				children << shape(component_part_id(config.id, 'wicks:${name}'), pane, wicks[side],
					ShapeStyle{
						stroke:       color
						stroke_width: 1
						line_cap:     .butt
					})
			}
			if bodies[side].len > 0 {
				children << shape(component_part_id(config.id, 'bodies:${name}'), pane, bodies[side],
					ShapeStyle{
						fill: color
					})
			}
		}
		if config.volume && layout.volume.height > 0 {
			vol := layout.volume
			vol_pane := vol
			mut most := 0.0
			for c in config.candles {
				most = math.max(most, c.volume)
			}
			mut bars := [][]PathCommand{len: 2}
			if most > 0 {
				for i, c in config.candles {
					if layout.candlestick_center(i) > edge {
						break
					}
					if c.volume <= 0 {
						continue
					}
					side := if c.close > c.open { 0 } else { 1 }
					x := math.round(layout.candlestick_center(i)) - vol.x
					h := math.max(1.0, vol.height * c.volume / most)
					bars[side] << path_rect(rect(x - body_w / 2, vol.height - h, body_w, h))
				}
			}
			for side, name in ['up', 'down'] {
				if bars[side].len > 0 {
					children << shape(component_part_id(config.id, 'volume:${name}'), vol_pane,
						bars[side], ShapeStyle{
							fill:         if side == 0 { bull } else { bear }
							fill_opacity: 0.45
						})
				}
			}
		}
		for k, period in config.moving_averages {
			values := candlestick_moving_average(config.candles, period)
			mut points := []PathPoint{}
			for i, v in values {
				if math.is_nan(v) {
					continue
				}
				p := path_point(layout.candlestick_center(i) - price.x, layout.price_y(v) - price.y)
				if p.x + price.x > edge {
					if points.len > 0 {
						last := points[points.len - 1]
						t := (edge - price.x - last.x) / (p.x - last.x)
						points << path_point(edge - price.x, last.y + (p.y - last.y) * t)
					}
					break
				}
				points << p
			}
			if points.len > 1 {
				children << shape(component_part_id(config.id, 'ma:${period}'), pane, path_polyline(points,
					false), ShapeStyle{
					stroke:       candlestick_average_color(config, colors, k)
					stroke_width: 1.5
					line_join:    .round
					line_cap:     .round
				})
			}
		}
	}
	// The price axis.
	if config.y_axis {
		for i, v in layout.tick_value {
			y := layout.price_y(v)
			if y < price.y - 1 || y > price.y + price.height + 1 {
				continue
			}
			children << special_chart_text(layout.tick_label[i], rect(layout.axis.x + 8, y - line / 2,
				layout.axis.width - 8, line), colors.muted_text, font, false, .left)
		}
	}
	// The x axis, every nth label, never overlapping.
	if config.x_axis && n > 0 {
		mut widest := 0.0
		for c in config.candles {
			widest = math.max(widest, special_chart_text_width(c.label, font, false))
		}
		every := if config.tick_margin > 0 {
			config.tick_margin
		} else {
			candlestick_label_interval(widest, layout.step)
		}
		for i := 0; i < n; i += every {
			c := config.candles[i]
			w := math.ceil(special_chart_text_width(c.label, font, false))
			x := math.clamp(layout.candlestick_center(i) - w / 2, 0.0, math.max(0.0, local.width - w))
			children << special_chart_text(c.label, rect(x, layout.x_labels.y, w, line), if i == hovered {
				colors.text
			} else {
				colors.muted_text
			}, font, false, .center)
		}
	}
	// Moving average keys, with their value at the hovered (or last) candle.
	if config.legend && config.moving_averages.len > 0 && n > 0 {
		at := if hovered >= 0 { hovered } else { n - 1 }
		mut items := []SpecialChartLegendItem{}
		for k, period in config.moving_averages {
			v := candlestick_moving_average(config.candles, period)[at]
			items << SpecialChartLegendItem{
				label:  'MA ${period}'
				value:  if math.is_nan(v) {
					'-'
				} else {
					special_chart_format(v, config.price_decimals)
				}
				color:  candlestick_average_color(config, colors, k)
				marker: .line
			}
		}
		frames := special_chart_legend_layout(items, local.width, font, false)
		shift := if frames.len > 0 { frames[0].x } else { 0.0 }
		children << special_chart_legend(layout.legend, frames.map(rect(it.x - shift, it.y,
			it.width, it.height)), items, colors, font)
	}
	tooltip_id := component_part_id(config.id, 'tooltip')
	if hovered >= 0 {
		c := config.candles[hovered]
		color := if c.close > c.open { bull } else { bear }
		// The close on the price axis, and a rule across to it.
		y := math.round(layout.price_y(c.close)) + 0.5
		children << shape(component_part_id(config.id, 'crosshair'), local, [
			path_move_to(price.x, y),
			path_line_to(price.x + price.width, y),
		], ShapeStyle{
			stroke:         colors.axis
			stroke_width:   1
			stroke_opacity: 0.8
		})
		if config.y_axis {
			tag_text := special_chart_format(c.close, config.price_decimals)
			tag_w := math.ceil(special_chart_text_width(tag_text, font, true)) + 8
			children << view(component_part_id(config.id, 'price-tag'), rect(layout.axis.x + 2,
				y - line / 2 - 1, math.max(tag_w, layout.axis.width - 2), line + 2), BoxStyle{
				bg:     color
				radius: 3
			}, [
				special_chart_text(tag_text, rect(4, 1, math.max(tag_w, layout.axis.width - 2) - 6,
					line), special_chart_ink_on(color), font, true, .left),
			])
		}
		delta, share := candlestick_change(config.candles, hovered)
		move_color := if delta > 0 {
			bull
		} else if delta < 0 {
			bear
		} else {
			colors.text
		}
		decimals := config.price_decimals
		mut rows := [
			SpecialChartTooltipRow{
				name:  'Open'
				value: special_chart_format(c.open, decimals)
			},
			SpecialChartTooltipRow{
				name:  'High'
				value: special_chart_format(c.high, decimals)
			},
			SpecialChartTooltipRow{
				name:  'Low'
				value: special_chart_format(c.low, decimals)
			},
			SpecialChartTooltipRow{
				name:        'Close'
				value:       special_chart_format(c.close, decimals)
				value_color: color
			},
			SpecialChartTooltipRow{
				name:        'Change'
				value:       '${candlestick_signed(delta, decimals)} (${candlestick_signed(share * 100, 2)}%)'
				value_color: move_color
			},
		]
		if config.volume {
			rows << SpecialChartTooltipRow{
				name:  'Volume'
				value: special_chart_compact(c.volume)
			}
		}
		for k, period in config.moving_averages {
			v := candlestick_moving_average(config.candles, period)[hovered]
			if !math.is_nan(v) {
				rows << SpecialChartTooltipRow{
					color: candlestick_average_color(config, colors, k)
					name:  'MA ${period}'
					value: special_chart_format(v, decimals)
				}
			}
		}
		w, h := special_chart_tooltip_size(c.label, rows, font)
		center := layout.candlestick_center(hovered)
		anchor := rect(center - layout.band / 2, plot.y + 4, layout.band, h)
		frame := special_chart_tooltip_place(anchor, w, h, rect(plot.x, plot.y, plot.width,
			plot.height), 10, false)
		children << special_chart_tooltip(tooltip_id, frame, c.label, rows, colors, font)
	}
	if config.interactive && whole && n > 0 && plot.height > 0 {
		for i in 0 .. n {
			center := layout.candlestick_center(i)
			children << special_chart_hit_view(rect(center - layout.step / 2, plot.y, layout.step,
				plot.height), special_chart_hover_action(config.id, 'candle:${keys[i]}'))
		}
	}
	mut summary := ''
	if n > 0 {
		first := config.candles[0]
		last := config.candles[n - 1]
		summary = '${n} periods from ${first.label} to ${last.label}; last close ${special_chart_format(last.close, config.price_decimals)}'
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'img'
		accessibility_label: if config.title.len > 0 { config.title } else { 'Candlestick chart' }
		accessibility_value: summary
	})
}

// candlestick_chart_hover_from_event returns the next `hovered` key when the
// pointer enters or leaves a candle's band, and none for any other event.
pub fn candlestick_chart_hover_from_event(config CandlestickChartConfig, event string) ?string {
	entered, target := special_chart_hover_event(config.id, event) or { return none }
	if !target.starts_with('candle:') {
		return none
	}
	key := target['candle:'.len..]
	keys := candlestick_keys(config.candles) or { return none }
	if key !in keys {
		return none
	}
	if entered {
		return if key == config.hovered { none } else { key }
	}
	return if key == config.hovered { '' } else { none }
}
