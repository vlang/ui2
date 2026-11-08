module main

import math
import os
import ui2

// A dashboard of the special charts: a doughnut with leader-line labels, a pie
// with a hovered slice and a legend, a radar comparing three people, a daily
// candlestick chart with volume and two moving averages, and an energy-flow
// sankey diagram. Every chart answers the pointer; the buttons switch the
// theme, stop the motion and draw the charts in again.

@[heap]
struct Dashboard {
mut:
	dark          bool
	reduce_motion bool
	replays       int
	browser       string
	source        string = 'Direct'
	radar         ui2.RadarChartHover
	candle        string
	flow          ui2.SankeyChartHover
}

const dashboard = &Dashboard{}

const window_width = 1240
const window_height = 900

// Screenshots are taken on the first frame, before a chart has drawn in, so
// a screenshot run shows the charts whole.
fn screenshot_run() bool {
	return os.getenv('UI2_SCREENSHOT_PATH') != '' || os.getenv('VGG_SCREENSHOT_FOLDER') != ''
}

fn appear_key(state Dashboard) string {
	return 'replay-${state.replays}'
}

// ── Data ──────────────────────────────────────────────────────────

fn browser_slices() []ui2.PieSlice {
	return [
		ui2.PieSlice{
			label: 'Chrome'
			value: 275
		},
		ui2.PieSlice{
			label: 'Safari'
			value: 200
		},
		ui2.PieSlice{
			label: 'Firefox'
			value: 187
		},
		ui2.PieSlice{
			label: 'Edge'
			value: 173
		},
		ui2.PieSlice{
			label: 'Other'
			value: 90
		},
	]
}

fn source_slices() []ui2.PieSlice {
	return [
		ui2.PieSlice{
			label: 'Search'
			value: 412
		},
		ui2.PieSlice{
			label: 'Direct'
			value: 236
		},
		ui2.PieSlice{
			label: 'Referral'
			value: 158
		},
		ui2.PieSlice{
			label: 'Social'
			value: 121
		},
		ui2.PieSlice{
			label: 'Email'
			value: 73
		},
	]
}

fn skill_axes() []ui2.RadarAxis {
	return ['Design', 'Frontend', 'Backend', 'Testing', 'DevOps', 'Docs'].map(ui2.RadarAxis{
		label: it
	})
}

fn skill_series() []ui2.RadarSeries {
	return [
		ui2.RadarSeries{
			name:   'Alice'
			values: [82.0, 94, 58, 70, 45, 86]
		},
		ui2.RadarSeries{
			name:   'Bob'
			values: [52.0, 68, 92, 78, 90, 48]
		},
		ui2.RadarSeries{
			name:   'Carol'
			values: [90.0, 60, 72, 95, 62, 74]
		},
	]
}

// trading_days are the labels of `count` weekdays from Monday, March 2.
fn trading_days(count int) []string {
	months := ['Mar', 'Apr', 'May', 'Jun', 'Jul']
	lengths := [31, 30, 31, 30, 31]
	mut out := []string{}
	mut month := 0
	mut day := 2
	mut weekday := 0
	for out.len < count {
		if weekday < 5 {
			out << '${months[month]} ${day}'
		}
		weekday = (weekday + 1) % 7
		day++
		if day > lengths[month] {
			day = 1
			month++
		}
	}
	return out
}

// Lcg is a linear congruential generator: the same numbers on every run.
struct Lcg {
mut:
	state u32
}

fn (mut g Lcg) next() f64 {
	g.state = g.state * 1664525 + 1013904223
	return f64(g.state >> 8) / f64(1 << 24)
}

// candles is a deterministic random walk, so the chart is the same on every
// run.
fn candles() []ui2.Candle {
	days := trading_days(64)
	mut rng := Lcg{
		state: 20260302
	}
	mut out := []ui2.Candle{}
	mut close := 182.0
	for i, label in days {
		open := close + (rng.next() - 0.5) * 1.6
		drift := 0.18 * math.sin(f64(i) / 9.0) + 0.05
		close = open + (rng.next() - 0.5) * 6.0 + drift * 3
		high := math.max(open, close) + rng.next() * 2.4
		low := math.min(open, close) - rng.next() * 2.4
		volume := 1.8e6 + rng.next() * 2.6e6 + math.abs(close - open) * 3.0e5
		out << ui2.Candle{
			label:  label
			open:   math.round(open * 100) / 100
			high:   math.round(high * 100) / 100
			low:    math.round(low * 100) / 100
			close:  math.round(close * 100) / 100
			volume: math.round(volume)
		}
	}
	return out
}

fn energy_nodes() []ui2.SankeyNode {
	return [
		ui2.SankeyNode{
			label: 'Coal'
			color: u32(0x64748b)
		},
		ui2.SankeyNode{
			label: 'Natural gas'
		},
		ui2.SankeyNode{
			label: 'Nuclear'
		},
		ui2.SankeyNode{
			label: 'Wind'
		},
		ui2.SankeyNode{
			label: 'Solar'
		},
		ui2.SankeyNode{
			label: 'Oil'
		},
		ui2.SankeyNode{
			label: 'Electricity'
		},
		ui2.SankeyNode{
			label: 'Homes'
		},
		ui2.SankeyNode{
			label: 'Industry'
		},
		ui2.SankeyNode{
			label: 'Transport'
		},
		ui2.SankeyNode{
			label: 'Losses'
			color: u32(0x94a3b8)
		},
	]
}

fn flow(source string, target string, value f64) ui2.SankeyLink {
	return ui2.SankeyLink{
		source: source
		target: target
		value:  value
	}
}

fn energy_links() []ui2.SankeyLink {
	return [
		flow('Coal', 'Electricity', 60),
		flow('Natural gas', 'Electricity', 110),
		flow('Natural gas', 'Homes', 140),
		flow('Natural gas', 'Industry', 70),
		flow('Nuclear', 'Electricity', 50),
		flow('Wind', 'Electricity', 80),
		flow('Solar', 'Electricity', 20),
		flow('Oil', 'Transport', 190),
		flow('Oil', 'Industry', 30),
		flow('Electricity', 'Homes', 100),
		flow('Electricity', 'Industry', 90),
		flow('Electricity', 'Transport', 10),
		flow('Electricity', 'Losses', 120),
	]
}

// ── Charts ────────────────────────────────────────────────────────

struct Card {
	x       f64
	y       f64
	width   f64
	height  f64
	title   string
	caption string
}

const card_doughnut = Card{16, 72, 400, 330, 'Browser share', 'Visitors this week, by browser'}
const card_pie = Card{428, 72, 380, 330, 'Traffic sources', 'Sessions this month'}
const card_radar = Card{820, 72, 404, 330, 'Team skills', 'Self-assessed, out of 100'}
const card_candles = Card{16, 414, 700, 470, 'ACME Corp · Daily', 'Price with volume, MA 5 and MA 20'}
const card_sankey = Card{728, 414, 496, 470, 'Energy flow', 'Primary sources to final use, TWh per year'}

// chart_frame is where a card's chart goes, under its title and caption, in
// the card's coordinates.
fn chart_frame(card Card) ui2.Rect {
	return ui2.rect(16, 60, card.width - 32, card.height - 76)
}

fn doughnut_config(state Dashboard, theme ui2.ComponentTheme) ui2.PieChartConfig {
	return ui2.PieChartConfig{
		id:             'browsers'
		frame:          chart_frame(card_doughnut)
		slices:         browser_slices()
		inner_ratio:    0.62
		pad_angle:      0.025
		labels:         .outside
		label_content:  .name_and_share
		center_text:    '925'
		center_caption: 'visitors'
		hovered:        state.browser
		appear:         !screenshot_run()
		appear_key:     appear_key(state)
		reduce_motion:  state.reduce_motion
		title:          'Browser share'
		theme:          theme
	}
}

fn pie_config(state Dashboard, theme ui2.ComponentTheme) ui2.PieChartConfig {
	return ui2.PieChartConfig{
		id:            'sources'
		frame:         chart_frame(card_pie)
		slices:        source_slices()
		pad_angle:     0.012
		labels:        .inside
		label_content: .share
		legend:        .bottom
		name:          'Sessions'
		hovered:       state.source
		appear:        !screenshot_run()
		appear_key:    appear_key(state)
		reduce_motion: state.reduce_motion
		title:         'Traffic sources'
		theme:         theme
	}
}

fn radar_config(state Dashboard, theme ui2.ComponentTheme) ui2.RadarChartConfig {
	return ui2.RadarChartConfig{
		id:            'skills'
		frame:         chart_frame(card_radar)
		axes:          skill_axes()
		series:        skill_series()
		max_value:     100
		level_labels:  true
		hover:         state.radar
		appear:        !screenshot_run()
		appear_key:    appear_key(state)
		reduce_motion: state.reduce_motion
		title:         'Team skills'
		theme:         theme
	}
}

fn candle_config(state Dashboard, theme ui2.ComponentTheme) ui2.CandlestickChartConfig {
	return ui2.CandlestickChartConfig{
		id:              'acme'
		frame:           chart_frame(card_candles)
		candles:         candles()
		volume:          true
		moving_averages: [5, 20]
		hovered:         state.candle
		appear:          !screenshot_run()
		appear_key:      appear_key(state)
		reduce_motion:   state.reduce_motion
		title:           'ACME Corp daily prices'
		theme:           theme
	}
}

fn sankey_config(state Dashboard, theme ui2.ComponentTheme) ui2.SankeyChartConfig {
	return ui2.SankeyChartConfig{
		id:            'energy'
		frame:         chart_frame(card_sankey)
		nodes:         energy_nodes()
		links:         energy_links()
		unit:          'TWh'
		node_padding:  14
		hover:         state.flow
		appear:        !screenshot_run()
		appear_key:    appear_key(state)
		reduce_motion: state.reduce_motion
		title:         'Energy flow'
		theme:         theme
	}
}

// ── Page ──────────────────────────────────────────────────────────

fn card_view(card Card, chart ui2.Element, theme ui2.ComponentTheme) ui2.Element {
	return ui2.view('', ui2.rect(card.x, card.y, card.width, card.height), ui2.BoxStyle{
		bg:            theme.background
		radius:        10
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, [
		ui2.label('', card.title, ui2.rect(16, 14, card.width - 32, 20), ui2.TextStyle{
			color: theme.foreground
			size:  14
			bold:  true
		}),
		ui2.label('', card.caption, ui2.rect(16, 34, card.width - 32, 18), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
		}),
		chart,
	])
}

fn toolbar_button(id string, text string, x f64, width f64, theme ui2.ComponentTheme, active bool) ui2.Element {
	return ui2.button(id, text, ui2.rect(x, 20, width, 30), ui2.BoxStyle{
		bg:            if active { theme.primary } else { theme.background }
		radius:        6
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, ui2.TextStyle{
		color: if active { theme.primary_foreground } else { theme.foreground }
		size:  13
		align: .center
	})
}

fn build() ui2.Element {
	state := unsafe { dashboard }
	theme := ui2.component_theme(state.dark)
	page := if state.dark { u32(0x0f172a) } else { u32(0xf1f5f9) }
	mut children := [
		ui2.label('', 'Charts', ui2.rect(20, 16, 300, 26), ui2.TextStyle{
			color: theme.foreground
			size:  20
			bold:  true
		}),
		ui2.label('', 'Pie, radar, candlestick and sankey charts drawn with vector shapes',
			ui2.rect(20, 42, 560, 18), ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
			}),
		toolbar_button('replay', 'Replay', 892, 80, theme, false),
		toolbar_button('motion', 'Reduce motion', 980, 120, theme, state.reduce_motion),
		toolbar_button('theme', 'Dark theme', 1108, 116, theme, state.dark),
	]
	children << card_view(card_doughnut, ui2.pie_chart(doughnut_config(state, theme)) or {
		panic(err)
	}, theme)
	children << card_view(card_pie, ui2.pie_chart(pie_config(state, theme)) or { panic(err) },
		theme)
	children << card_view(card_radar, ui2.radar_chart(radar_config(state, theme)) or {
		panic(err)
	}, theme)
	children << card_view(card_candles, ui2.candlestick_chart(candle_config(state, theme)) or {
		panic(err)
	}, theme)
	children << card_view(card_sankey, ui2.sankey_chart(sankey_config(state, theme)) or {
		panic(err)
	}, theme)
	return ui2.screen(page, children)
}

fn on_event(event string) {
	mut state := unsafe { dashboard }
	theme := ui2.component_theme(state.dark)
	match event {
		'theme' {
			state.dark = !state.dark
		}
		'motion' {
			state.reduce_motion = !state.reduce_motion
		}
		'replay' {
			state.replays++
		}
		else {
			if next := ui2.pie_chart_hover_from_event(doughnut_config(state, theme), event) {
				state.browser = next
			} else if next := ui2.pie_chart_hover_from_event(pie_config(state, theme), event) {
				state.source = next
			} else if next := ui2.radar_chart_hover_from_event(radar_config(state, theme), event) {
				state.radar = next
			} else if next := ui2.candlestick_chart_hover_from_event(candle_config(state, theme),
				event)
			{
				state.candle = next
			} else if next := ui2.sankey_chart_hover_from_event(sankey_config(state, theme), event) {
				state.flow = next
			} else {
				return
			}
		}
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('UI2 Charts', window_width, window_height, build, on_event)
}
