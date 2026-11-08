module main

import math
import ui2

fn build() ui2.Element {
	mut points := []ui2.PathPoint{}
	for i in 0 .. 40 {
		x := f64(i) * 10
		points << ui2.path_point(x, 80 + 50 * math.sin(f64(i) / 4) + f64(i % 3) * 6)
	}
	mut area := ui2.path_smooth(points)
	area << ui2.path_line_to(390, 160)
	area << ui2.path_line_to(0, 160)
	area << ui2.path_close()
	mut children := []ui2.Element{}
	children << ui2.shape('area', ui2.rect(20, 20, 400, 160), area, ui2.ShapeStyle{
		fill:         u32(0x3b82f6)
		fill_opacity: 0.25
	})
	children << ui2.shape('line', ui2.rect(20, 20, 400, 160), ui2.path_smooth(points), ui2.ShapeStyle{
		stroke:       u32(0x2563eb)
		stroke_width: 2.5
	})
	// Pie and doughnut slices.
	colors := [u32(0xef4444), 0xf59e0b, 0x10b981, 0x6366f1]
	mut a := -math.pi / 2
	for i, frac in [0.4, 0.25, 0.2, 0.15] {
		b := a + frac * 2 * math.pi
		children << ui2.shape('pie${i}', ui2.rect(450, 20, 160, 160), ui2.path_sector(80, 80, 70, a, b), ui2.ShapeStyle{
			fill:         colors[i]
			stroke:       u32(0xffffff)
			stroke_width: 2
		})
		children << ui2.shape('ring${i}', ui2.rect(630, 20, 160, 160), ui2.path_annular_sector(80, 80, 40, 70, a + 0.02, b - 0.02), ui2.ShapeStyle{
			fill: colors[i]
		})
		a = b
	}
	// Radar polygon, star (even-odd hole), rounded rect outline, polyline joins.
	mut radar := []ui2.PathPoint{}
	for i, r in [60.0, 40, 70, 30, 55, 45] {
		t := -math.pi / 2 + f64(i) * math.pi / 3
		radar << ui2.path_point(80 + r * math.cos(t), 80 + r * math.sin(t))
	}
	children << ui2.shape('radar', ui2.rect(20, 200, 160, 160), ui2.path_polyline(radar, true), ui2.ShapeStyle{
		fill:         u32(0x8b5cf6)
		fill_opacity: 0.35
		stroke:       u32(0x7c3aed)
		stroke_width: 2
	})
	mut star := []ui2.PathPoint{}
	for i in 0 .. 5 {
		t := -math.pi / 2 + f64(i * 2) * 2 * math.pi / 5
		star << ui2.path_point(80 + 70 * math.cos(t), 80 + 70 * math.sin(t))
	}
	children << ui2.shape('star', ui2.rect(200, 200, 160, 160), ui2.path_polyline(star, true), ui2.ShapeStyle{
		fill:      u32(0xf59e0b)
		fill_rule: .even_odd
	})
	children << ui2.shape('rr', ui2.rect(380, 200, 160, 160), ui2.path_rounded_rect(ui2.rect(10, 10, 140, 140), 24), ui2.ShapeStyle{
		stroke:       u32(0x0f172a)
		stroke_width: 4
	})
	zig := [ui2.path_point(10, 140), ui2.path_point(50, 20), ui2.path_point(90, 140),
		ui2.path_point(130, 20)]
	children << ui2.shape('zigm', ui2.rect(560, 200, 140, 160), ui2.path_polyline(zig, false), ui2.ShapeStyle{
		stroke:       u32(0x0ea5e9)
		stroke_width: 10
		line_join:    .miter
		line_cap:     .butt
	})
	children << ui2.shape('zigr', ui2.rect(700, 200, 140, 160), ui2.path_polyline(zig, false), ui2.ShapeStyle{
		stroke:       u32(0x14b8a6)
		stroke_width: 10
	})
	// Candlesticks: a wick line and a body rect each.
	for i, c in [[40.0, 90, 30, 110], [90.0, 60, 50, 100], [60.0, 120, 40, 130], [120.0, 100, 90,
		140]] {
		x := 20 + f64(i) * 40
		up := c[1] > c[0]
		col := if up { u32(0x16a34a) } else { u32(0xdc2626) }
		children << ui2.shape('wick${i}', ui2.rect(20, 380, 200, 160), ui2.path_polyline([
			ui2.path_point(x, 160 - c[3]),
			ui2.path_point(x, 160 - c[2]),
		], false), ui2.ShapeStyle{
			stroke:       col
			stroke_width: 1.5
			line_cap:     .butt
		})
		top := 160 - math.max(c[0], c[1])
		children << ui2.shape('body${i}', ui2.rect(20, 380, 200, 160), ui2.path_rect(ui2.rect(x - 8, top, 16, math.abs(c[1] - c[0]))), ui2.ShapeStyle{
			fill: col
		})
	}
	// A sankey ribbon.
	ribbon := [ui2.path_move_to(0, 20), ui2.path_cubic_to(100, 20, 100, 90, 200, 90),
		ui2.path_line_to(200, 140), ui2.path_cubic_to(100, 140, 100, 60, 0, 60), ui2.path_close()]
	children << ui2.shape('ribbon', ui2.rect(260, 380, 200, 160), ribbon, ui2.ShapeStyle{
		fill:         u32(0x06b6d4)
		fill_opacity: 0.4
	})
	return ui2.screen(0xffffff, children)
}

fn on_event(_ string) {}

fn main() {
	ui2.run_window('Shapes', 860, 560, build, on_event)
}
