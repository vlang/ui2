module main

import math
import os
import ui2

// A dashboard of the plot module and the cartesian charts: a smooth line
// chart, grouped, stacked and horizontal bar charts, a stacked area chart, a
// bar chart built by hand from scales, shapes and an axis, and a donut from
// the pie generator. Hover a chart for its tooltip, click a legend item of the
// line or area chart to hide its series, and use the toolbar to switch the
// theme, replay the draw-in, or turn motion off. Start with UI2_PLOT_DARK=1
// for the dark theme and UI2_PLOT_HOVER=1 to show three more charts hovered.
// A screenshot run (UI2_SCREENSHOT_PATH, VGG_SCREENSHOT_OUTPUT) shows the
// charts drawn in unless UI2_PLOT_APPEAR=1 asks for the draw-in.

@[heap]
struct Dashboard {
mut:
	dark          bool
	reduce_motion bool
	replay        int
	hovered       map[string]int
	hidden        map[string][]string
}

const window_width = 1200
const window_height = 900

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const traffic = [
	ui2.PlotSeries{
		key:    'desktop'
		name:   'Desktop'
		values: [186.0, 305, 237, 273, 209, 214, 262, 298, 251, 320, 342, 365]
	},
	ui2.PlotSeries{
		key:    'mobile'
		name:   'Mobile'
		values: [80.0, 200, 120, 190, 130, 140, 170, 210, 190, 240, 260, 300]
	},
	ui2.PlotSeries{
		key:    'tablet'
		name:   'Tablet'
		values: [42.0, 60, 75, 68, 90, 82, 95, 110, 98, 104, 120, 132]
	},
]

const browsers = ['Chrome', 'Safari', 'Firefox', 'Edge', 'Other']

const quarters = ['Q1', 'Q2', 'Q3', 'Q4']

const channels = [
	ui2.PlotSeries{
		key:    'organic'
		name:   'Organic'
		values: [420.0, 380, 510, 560, 490, 620]
	},
	ui2.PlotSeries{
		key:    'paid'
		name:   'Paid'
		values: [240.0, 310, 260, 330, 360, 300]
	},
	ui2.PlotSeries{
		key:    'referral'
		name:   'Referral'
		values: [120.0, 140, 180, 150, 210, 240]
	},
]

const signups = [
	ui2.PlotSeries{
		key:    'trial'
		name:   'Trials'
		values: [1200.0, 1350, 1280, 1420, 1610, 1580, 1720, 1890, 1760, 1950, 2100, 2240]
	},
	ui2.PlotSeries{
		key:    'starter'
		name:   'Starter'
		values: [640.0, 690, 720, 700, 810, 860, 830, 920, 990, 1010, 1120, 1180]
	},
	ui2.PlotSeries{
		key:    'pro'
		name:   'Pro'
		values: [210.0, 240, 260, 300, 290, 340, 380, 360, 410, 450, 470, 520]
	},
]

const app = &Dashboard{
	dark:    os.getenv('UI2_PLOT_DARK') == '1'
	hovered: {
		'traffic':  7
		'browsers': if os.getenv('UI2_PLOT_HOVER') == '1' { 1 } else { -1 }
		'quarters': if os.getenv('UI2_PLOT_HOVER') == '1' { 2 } else { -1 }
		'channels': -1
		'signups':  if os.getenv('UI2_PLOT_HOVER') == '1' { 8 } else { -1 }
	}
}

// A still screenshot shows the charts drawn in, not their first frame.
fn capturing() bool {
	return os.getenv('UI2_SCREENSHOT_PATH') != '' || os.getenv('VGG_SCREENSHOT_OUTPUT') != ''
}

fn page_color(theme ui2.ComponentTheme) u32 {
	return if ui2.plot_theme_is_dark(theme) { u32(0x0f1726) } else { u32(0xf3f5f8) }
}

// card frames a chart with a title and a caption, as the upstream gallery does.
fn card(id string, title string, caption string, frame ui2.Rect, theme ui2.ComponentTheme, body ui2.Element) ui2.Element {
	return ui2.view(id, frame, ui2.BoxStyle{
		bg:            theme.background
		radius:        12
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, [
		ui2.label('', title, ui2.rect(16, 12, frame.width - 32, 20), ui2.TextStyle{
			color: theme.foreground
			size:  14
			bold:  true
		}),
		ui2.label('', caption, ui2.rect(16, 32, frame.width - 32, 16), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
		}),
		body,
	])
}

fn body_frame(frame ui2.Rect) ui2.Rect {
	return ui2.rect(8, 54, frame.width - 16, frame.height - 62)
}

fn toolbar_button(id string, text string, x f64, width f64, theme ui2.ComponentTheme, active bool) ui2.Element {
	return ui2.button(id, text, ui2.rect(x, 18, width, 28), ui2.BoxStyle{
		bg:            if active { theme.primary } else { theme.background }
		radius:        6
		border_color:  if active { theme.primary } else { theme.border }
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

fn thousands(value f64) string {
	return ui2.plot_format_compact(value)
}

fn dollars(value f64) string {
	return '$' + ui2.plot_format_compact(value)
}

// custom_bar_chart is the upstream doc's "Custom Bar Chart Implementation":
// a stacked bar chart drawn directly from a band scale, a linear scale, the
// stack generator, bar paths and two axes.
fn custom_bar_chart(frame ui2.Rect, theme ui2.ComponentTheme) !ui2.Element {
	days := ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
	keys := ['desktop', 'mobile']
	stack := ui2.plot_stack(keys, [[222.0, 97, 167, 242, 373, 301, 245],
		[150.0, 180, 120, 260, 290, 340, 180]], .none)
	colors := ui2.plot_color_scale(keys, theme)
	_, top := ui2.plot_stack_extent(stack)
	left, bottom := 40.0, 24.0
	plot := ui2.rect(left, 8, frame.width - left - 8, frame.height - 8 - bottom)
	// 1. Scales: categories across, values up.
	x := ui2.PlotBandScale{
		domain:        days
		range_end:     plot.width
		padding_inner: 0.35
		padding_outer: 0.2
	}
	y := ui2.plot_linear_scale(0, top, plot.height, 0).nice(4)
	// 2. Axes: values with grid lines on the left, days along the bottom.
	mut children := [
		ui2.plot_axis(
			id:          'custom:y'
			plot:        plot
			orientation: .left
			ticks:       ui2.plot_linear_ticks(y, 4, thousands)
			line:        false
			grid:        true
			theme:       theme
		)!,
		ui2.plot_axis(
			id:          'custom:x'
			plot:        plot
			orientation: .bottom
			ticks:       ui2.plot_band_ticks(x, 1)
			theme:       theme
		)!,
	]
	// 3. Stacked bars: each segment from its y0 to its y1, the top one rounded.
	for layer in stack {
		color := colors.get(layer.key) or { theme.primary }
		for i, p in layer.points {
			base := y.position(p.y0) - if p.y0 > 0 { 2.0 } else { 0.0 }
			tip := y.position(p.y1)
			r := ui2.plot_bar_rect(.bottom, plot.x + x.position_at(i), x.bandwidth(), plot.y + base,
				plot.y + tip)
			corners := if layer.index == stack.len - 1 {
				ui2.plot_tip_corners(.bottom, 4, base, tip)
			} else {
				ui2.PlotCorners{}
			}
			children << ui2.shape('custom:bar:${layer.key}:${i}', r, ui2.plot_rounded_rect_path(ui2.rect(0,
				0, r.width, r.height), corners), ui2.ShapeStyle{
				fill: color
			})
		}
	}
	return ui2.view('custom', frame, ui2.BoxStyle{ transparent: true }, children)
}

// donut is a ring of pie arcs with a gap between slices and the total in its
// hole, drawn from plot_pie and plot_arc_path.
fn donut(frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	values := [275.0, 200, 187, 173, 90]
	arcs := ui2.plot_pie(values, pad_angle: 0.03)
	size := math.min(frame.height - 8, frame.width * 0.5)
	cx, cy := size / 2 + 8, frame.height / 2
	outer := size / 2
	mut children := []ui2.Element{}
	for arc in arcs {
		children << ui2.shape('donut:${arc.index}', ui2.rect(0, 0, size + 16, frame.height),
			ui2.plot_arc_path(arc, cx, cy, outer * 0.62, outer), ui2.ShapeStyle{
				fill: ui2.plot_chart_color(theme, arc.index)
			})
	}
	mut total := 0.0
	for v in values {
		total += v
	}
	children << ui2.label('', ui2.plot_format_number(total, 0), ui2.rect(cx - 40, cy - 16, 80,
		20), ui2.TextStyle{
		color: theme.foreground
		size:  18
		bold:  true
		align: .center
	})
	children << ui2.label('', 'visitors', ui2.rect(cx - 40, cy + 4, 80, 16), ui2.TextStyle{
		color: theme.muted_foreground
		size:  11
		align: .center
	})
	mut ly := cy - f64(values.len) * 22 / 2
	for i, name in browsers {
		share := arcs[i].value / total
		children << ui2.view('', ui2.rect(size + 32, ly + 5, 10, 10), ui2.BoxStyle{
			bg:     ui2.plot_chart_color(theme, i)
			radius: 3
		}, [])
		children << ui2.label('', name, ui2.rect(size + 48, ly, 80, 20), ui2.TextStyle{
			color: theme.foreground
			size:  12
		})
		children << ui2.label('', ui2.plot_format_percent(share), ui2.rect(frame.width - 64,
			ly, 56, 20), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
			align: .right
		})
		ly += 22
	}
	return ui2.view('donut', frame, ui2.BoxStyle{ transparent: true }, children)
}

fn build() ui2.Element {
	state := unsafe { app }
	theme := ui2.component_theme(state.dark)
	appear := !capturing() || os.getenv('UI2_PLOT_APPEAR') == '1'
	key := state.replay.str()
	gap := 16.0
	margin := 20.0
	col := (window_width - 2 * margin - 2 * gap) / 3
	wide := 2 * col + gap
	row1 := 64.0
	row2 := row1 + 290 + gap
	row3 := row2 + 260 + gap
	mut children := [
		ui2.label('', 'Plot and charts', ui2.rect(margin, 14, 300, 22), ui2.TextStyle{
			color: theme.foreground
			size:  20
			bold:  true
		}),
		ui2.label('', 'Scales, shape generators and axes, and the line, bar and area charts built on them',
			ui2.rect(margin, 38, 620, 16), ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
			}),
		toolbar_button('replay', 'Replay', window_width - margin - 360, 80, theme, false),
		toolbar_button('motion', 'Reduce motion', window_width - margin - 272, 128, theme,
			state.reduce_motion),
		toolbar_button('theme', if state.dark { 'Light theme' } else { 'Dark theme' }, window_width - margin -
			136, 136, theme, state.dark),
	]
	// A smooth multi-series line chart, hovered.
	f1 := ui2.rect(margin, row1, wide, 290)
	children << card('card:traffic', 'Visitors by device', 'Thousands of sessions, 2025 · click a legend item to hide it',
		f1, theme, ui2.line_chart(
			id:              'traffic'
			frame:           body_frame(f1)
			categories:      months
			series:          traffic
			hidden_series:   state.hidden['traffic'] or { []string{} }
			hovered:         state.hovered['traffic'] or { -1 }
			legend_toggle:   true
			reference_lines: [250.0]
			appear:          appear
			appear_key:      key
			reduce_motion:   state.reduce_motion
			theme:           theme
		) or { panic(err) })
	// Horizontal bars with value labels.
	f2 := ui2.rect(margin + wide + gap, row1, col, 290)
	children << card('card:browsers', 'Top browsers', 'Visitors this month', f2, theme,
		ui2.bar_chart(
			id:            'browsers'
			frame:         body_frame(f2)
			categories:    browsers
			series:        [
				ui2.PlotSeries{
					key:    'visitors'
					name:   'Visitors'
					values: [275.0, 200, 187, 173, 90]
				},
			]
			alignment:     .left
			value_labels:  true
			hovered:       state.hovered['browsers'] or { -1 }
			padding_inner: 0.3
			appear:        appear
			appear_key:    key
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) })
	// Grouped bars.
	f3 := ui2.rect(margin, row2, col, 260)
	children << card('card:quarters', 'Revenue by quarter', '2024 and 2025, grouped', f3,
		theme, ui2.bar_chart(
			id:            'quarters'
			frame:         body_frame(f3)
			categories:    quarters
			series:        [
				ui2.PlotSeries{
					key:    '2024'
					values: [42000.0, 51000, 47000, 63000]
				},
				ui2.PlotSeries{
					key:    '2025'
					values: [48000.0, 57000, 61000, 72000]
				},
			]
			value_format:  dollars
			padding_inner: 0.3
			hovered:       state.hovered['quarters'] or { -1 }
			appear:        appear
			appear_key:    key
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) })
	// Stacked bars.
	f4 := ui2.rect(margin + col + gap, row2, col, 260)
	children << card('card:channels', 'Sessions by channel', 'Stacked, January to June', f4,
		theme, ui2.bar_chart(
			id:            'channels'
			frame:         body_frame(f4)
			categories:    months[..6]
			series:        channels
			layout:        .stacked
			hovered:       state.hovered['channels'] or { -1 }
			appear:        appear
			appear_key:    key
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) })
	// Built by hand from the plot primitives.
	f5 := ui2.rect(margin + 2 * (col + gap), row2, col, 260)
	children << card('card:custom', 'Custom stacked bars', 'plot_band_scale, plot_stack, plot_axis and shapes',
		f5, theme, custom_bar_chart(body_frame(f5), theme) or { panic(err) })
	// A stacked area chart with faded fills.
	f6 := ui2.rect(margin, row3, wide, window_height - row3 - margin)
	children << card('card:signups', 'Sign-ups by plan', 'Stacked areas with a fading fill',
		f6, theme, ui2.area_chart(
			id:            'signups'
			frame:         body_frame(f6)
			categories:    months
			series:        signups
			hidden_series: state.hidden['signups'] or { []string{} }
			layout:        .stacked
			gradient:      true
			fill_opacity:  0.5
			y_tick_format: thousands
			legend:        .top
			legend_toggle: true
			hovered:       state.hovered['signups'] or { -1 }
			appear:        appear
			appear_key:    key
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) })
	f7 := ui2.rect(margin + wide + gap, row3, col, window_height - row3 - margin)
	children << card('card:donut', 'Browser share', 'plot_pie and plot_arc_path', f7, theme,
		donut(body_frame(f7), theme))
	return ui2.screen(page_color(theme), children)
}

const chart_counts = {
	'traffic':  12
	'browsers': 5
	'quarters': 4
	'channels': 6
	'signups':  12
}

fn on_event(event string) {
	mut state := unsafe { app }
	match event {
		'theme' {
			state.dark = !state.dark
		}
		'motion' {
			state.reduce_motion = !state.reduce_motion
		}
		'replay' {
			state.replay++
		}
		else {
			for id, count in chart_counts {
				if index := ui2.plot_hover_from_event(id, state.hovered[id] or { -1 }, count,
					event)
				{
					state.hovered[id] = index
					ui2.refresh()
					return
				}
			}
			for id, series in {
				'traffic': traffic
				'signups': signups
			} {
				if key := ui2.plot_legend_key_from_action(id, series, event) {
					state.hidden[id] = ui2.plot_toggle_hidden(state.hidden[id] or { []string{} },
						key)
					ui2.refresh()
					return
				}
			}
			return
		}
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('UI2 Plot and Charts', window_width, window_height, build, on_event)
}
