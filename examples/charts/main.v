module main

import math
import ui2

fn build_charts() ui2.Element {
	return charts_screen(ui2.bounds())
}

fn charts_screen(bounds ui2.Rect) ui2.Element {
	width := math.max(360.0, bounds.width)
	columns := if width >= 1000 {
		3
	} else if width >= 680 {
		2
	} else {
		1
	}
	card_width := (width - 16) / columns - 16
	mut children := []ui2.Element{}
	for i, kind in [ui2.ChartType.line, .bar, .scatter, .pie, .doughnut] {
		data := match kind {
			.scatter {
				ui2.ChartData{
					datasets: [
						ui2.ChartDataset{
							label:  'Observations'
							points: [ui2.ChartPoint{1, 3}, ui2.ChartPoint{2, 7}, ui2.ChartPoint{3, 5},
								ui2.ChartPoint{5, 12}, ui2.ChartPoint{8, 9}]
						},
					]
				}
			}
			.pie, .doughnut {
				ui2.ChartData{
					labels:   ['Desktop', 'Mobile', 'Tablet']
					datasets: [
						ui2.ChartDataset{
							label: 'Visitors'
							data:  [f64(55), 35, 10]
						},
					]
				}
			}
			else {
				ui2.ChartData{
					labels:   ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
					datasets: [
						ui2.ChartDataset{
							label: 'Revenue'
							data:  [f64(12), 19, 15, 28, 22, 34]
						},
						ui2.ChartDataset{
							label: 'Profit'
							data:  [f64(-3), 5, 2, 12, 8, 16]
						},
					]
				}
			}
		}

		children << ui2.chart(
			id:      'chart_${kind}'
			frame:   ui2.rect(16 + (i % columns) * (card_width + 16), 16 + (i / columns) * 330,
				card_width, 314)
			type:    kind
			data:    data
			options: ui2.ChartOptions{
				title: '${kind} chart'
			}
		) or { panic(err) }
	}
	return ui2.screen(0xf1f5f9, [
		ui2.scroll('charts', ui2.rect(0, 0, bounds.width, bounds.height), 0xf1f5f9, children),
	])
}

fn handle_chart_event(_event string) {}

fn main() {
	ui2.run_window('UI2 Charts', 1080, 720, build_charts, handle_chart_event)
}
