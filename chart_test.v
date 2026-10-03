module ui2

import math

fn test_chart_scales_empty_constant_negative_and_nonfinite_data() {
	empty := chart_scale([], false, none, none) or { panic(err) }
	assert empty.min == 0 && empty.max == 1
	constant := chart_scale([f64(7), 7], false, none, none) or { panic(err) }
	assert constant.min < 7 && constant.max > 7
	negative := chart_scale([f64(-5), -2, math.nan(), math.inf(1)], true, none, none) or {
		panic(err)
	}
	assert negative.min == -5 && negative.max == 0
	bounded := chart_scale([f64(-5), 10], false, f64(0), f64(5)) or { panic(err) }
	assert bounded.fraction(-5) == 0
	assert bounded.fraction(2.5) == 0.5
	assert bounded.fraction(10) == 1
	chart_scale([], false, f64(3), f64(2)) or {
		assert err.msg().contains('increasing')
		return
	}
	assert false, 'reversed axis bounds must fail'
}

fn test_chart_ticks_round_outward_and_keep_zero_series_nonnegative() {
	scale, ticks := chart_tick_scale(ChartScale{-3, 34}, 5)
	assert scale.min == -10 && scale.max == 40
	assert ticks == 5
	assert chart_tick_number(scale, 1, ticks) == '0'
	assert chart_tick_number(ChartScale{-0.3, 0.2}, 3, 5) == '0'
	zero := chart_scale([f64(0)], true, none, none) or { panic(err) }
	assert zero.min == 0 && zero.max == 1
}

fn test_chart_grouped_bars_share_zero_baseline_and_fit_categories() {
	el := chart(
		id:      'bars'
		frame:   rect(3, 4, 320, 240)
		type:    .bar
		data:    ChartData{
			labels:   ['A', 'B']
			datasets: [
				ChartDataset{
					label: 'First'
					data:  [f64(-5), 10]
					color: u32(0)
				},
				ChartDataset{
					label: 'Second'
					data:  [f64(5), 0]
				},
			]
		}
		options: ChartOptions{
			legend: false
			y_min:  f64(-10)
			y_max:  f64(10)
		}
	) or { panic(err) }
	validate_element_tree(el) or { panic(err) }
	assert el.id == 'bars' && el.frame == rect(3, 4, 320, 240)
	assert el.accessibility_role == 'img'
	assert el.accessibility_value.contains('A: -5')
	plot := el.children.last()
	assert plot.children.len == 4
	negative, positive := plot.children[0], plot.children[2]
	baseline := plot.frame.height / 2
	assert negative.frame.y == baseline
	assert positive.frame.y + positive.frame.height == baseline
	assert negative.frame.x + negative.frame.width <= positive.frame.x
	assert negative.box.bg == u32(0)
	assert negative.tooltip == 'First A: -5'
	assert plot.children[3].frame.height == 0
}

fn test_chart_line_gaps_do_not_connect_and_resize_moves_points() {
	data := ChartData{
		datasets: [ChartDataset{ data: [f64(1), math.nan(), 3] }]
	}
	small := chart(
		frame:   rect(0, 0, 320, 240)
		data:    data
		options: ChartOptions{
			legend: false
		}
	) or { panic(err) }
	large := chart(
		frame:   rect(0, 0, 640, 240)
		data:    data
		options: ChartOptions{
			legend: false
		}
	) or { panic(err) }
	small_plot, large_plot := small.children.last(), large.children.last()
	assert small_plot.children.len == 2, 'a gap must produce two isolated point markers'
	assert large_plot.children.len == 2
	assert large_plot.children[1].frame.x - small_plot.children[1].frame.x == 320
	assert small_plot.children[0].tooltip == '1: 1'
	assert small_plot.children[1].tooltip == '3: 3'
	connected := chart(
		frame:   rect(0, 0, 320, 240)
		data:    ChartData{
			datasets: [ChartDataset{ data: [f64(1), 3] }]
		}
		options: ChartOptions{
			legend: false
		}
	) or { panic(err) }
	assert connected.children.last().children.len > 2
}

fn test_chart_scatter_uses_numeric_x_and_skips_invalid_points() {
	el := chart(
		frame:   rect(0, 0, 320, 240)
		type:    .scatter
		data:    ChartData{
			datasets: [
				ChartDataset{
					points: [ChartPoint{0, 1}, ChartPoint{10, 2}, ChartPoint{100, 3},
						ChartPoint{math.inf(1), 4}]
				},
			]
		}
		options: ChartOptions{
			legend:   false
			tooltips: false
		}
	) or { panic(err) }
	plot := el.children.last()
	assert plot.children.len == 3
	a, b, c := plot.children[0].frame, plot.children[1].frame, plot.children[2].frame
	assert math.abs((b.x - a.x) / (c.x - a.x) - 0.1) < 1e-9
	assert plot.children[0].tooltip == ''
}

fn chart_test_covers(el Element, x f64, y f64) bool {
	return x >= el.frame.x && x < el.frame.x + el.frame.width && y >= el.frame.y
		&& y < el.frame.y + el.frame.height
}

fn test_chart_pie_slices_have_correct_colors_and_doughnut_leaves_a_hole() {
	data := ChartData{
		labels:   ['Left', 'Right', 'Ignored']
		datasets: [
			ChartDataset{
				data:   [f64(1e308), 1e308, -2]
				colors: [u32(0xff0000), 0x00ff00]
			},
		]
	}
	pie := chart(
		frame:   rect(0, 0, 240, 240)
		type:    .pie
		data:    data
		options: ChartOptions{
			legend: false
		}
	) or { panic(err) }
	doughnut := chart(
		frame:   rect(0, 0, 240, 240)
		type:    .doughnut
		data:    data
		options: ChartOptions{
			legend: false
		}
	) or { panic(err) }
	validate_element_tree(pie) or { panic(err) }
	mut left, mut right, mut center := false, false, false
	for child in pie.children {
		if chart_test_covers(child, 60, 120) {
			assert child.box.bg == u32(0x00ff00)
			assert child.tooltip.starts_with('Right: ')
			left = true
		}
		if chart_test_covers(child, 180, 120) {
			assert child.box.bg == u32(0xff0000)
			right = true
		}
		if chart_test_covers(child, 120, 120) {
			center = true
		}
	}
	assert left && right && center
	for child in doughnut.children {
		assert !chart_test_covers(child, 120, 120)
	}
}

fn test_chart_hidden_series_empty_data_and_invalid_configuration() {
	for kind in [ChartType.line, .bar, .scatter, .pie, .doughnut] {
		el := chart(frame: rect(0, 0, 240, 200), type: kind) or { panic(err) }
		validate_element_tree(el) or { panic(err) }
	}
	el := chart(
		frame: rect(0, 0, 240, 200)
		data:  ChartData{
			datasets: [ChartDataset{ hidden: true, label: 'Hidden', data: [f64(100)] }]
		}
	) or { panic(err) }
	assert el.accessibility_value == ''
	assert el.children.last().children.len == 0
	colored := chart(
		frame:   rect(0, 0, 240, 200)
		data:    ChartData{
			datasets: [ChartDataset{ hidden: true }, ChartDataset{ data: [f64(1)] }]
		}
		options: ChartOptions{ legend: false }
	) or { panic(err) }
	assert colored.children.last().children[0].box.bg == ChartOptions{}.palette[1]
	configs := [
		ChartConfig{
			frame: rect(0, 0, 10, 10)
		},
		ChartConfig{
			frame:   rect(0, 0, 240, 200)
			options: ChartOptions{
				palette: []u32{}
			}
		},
		ChartConfig{
			frame:   rect(0, 0, 240, 200)
			options: ChartOptions{
				ticks: 0
			}
		},
		ChartConfig{
			frame:   rect(0, 0, 240, 200)
			options: ChartOptions{
				cutout: 1
			}
		},
		ChartConfig{
			frame: rect(0, 0, 240, 200)
			type:  .scatter
			data:  ChartData{
				datasets: [ChartDataset{ data: [f64(1)] }]
			}
		},
		ChartConfig{
			frame: rect(0, 0, 240, 200)
			type:  .pie
			data:  ChartData{
				datasets: [ChartDataset{}, ChartDataset{}]
			}
		},
	]
	for config in configs {
		chart(config) or {
			assert err.msg().starts_with('chart:')
			continue
		}
		assert false, 'invalid chart configuration must fail'
	}
}
