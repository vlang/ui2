module ui2

import math
import time

// ── Helpers ───────────────────────────────────────────────────────

// special_chart_test_hover_at is the innermost hover action at (x, y), given in
// the coordinates of el's parent, as a backend finds it: the topmost element
// under the point, then the nearest hoverable element up from it. It is none
// when the point is outside el.
fn special_chart_test_hover_at(el Element, x f64, y f64) ?string {
	f := el.frame
	if el.hidden || x < f.x || y < f.y || x >= f.x + f.width || y >= f.y + f.height {
		return none
	}
	for i := el.children.len - 1; i >= 0; i-- {
		if found := special_chart_test_hover_at(el.children[i], x - f.x, y - f.y) {
			if found.len > 0 {
				return found
			}
			return if el.hoverable { element_action_id(el) } else { '' }
		}
	}
	return if el.hoverable { element_action_id(el) } else { '' }
}

fn special_chart_test_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for c in el.children {
		if found := special_chart_test_find(c, id) {
			return found
		}
	}
	return none
}

fn special_chart_test_texts(el Element) []string {
	mut out := []string{}
	if el.kind == .label {
		out << el.text
	}
	for c in el.children {
		out << special_chart_test_texts(c)
	}
	return out
}

fn special_chart_test_hit_count(el Element) int {
	mut n := if el.hoverable && el.id.len == 0 && el.children.len == 0 { 1 } else { 0 }
	for c in el.children {
		n += special_chart_test_hit_count(c)
	}
	return n
}

fn special_chart_test_subpaths(path []PathCommand) int {
	return path.filter(it.verb == .move_to).len
}

fn special_chart_test_event(phase string, action string) string {
	return 'pointer:${phase}:${action}:10.0:20.0'
}

fn special_chart_test_close(a f64, b f64) bool {
	return math.abs(a - b) < 1e-6
}

// ── Shared ────────────────────────────────────────────────────────

fn test_special_chart_colors_follow_the_theme() {
	light := special_chart_colors(component_theme(false))
	dark := special_chart_colors(component_theme(true))
	assert light.palette.len == 8 && dark.palette.len == 8
	assert light.palette[0] != dark.palette[0]
	assert light.surface == 0xffffff
	assert dark.text == component_theme(true).foreground
	assert light.bullish != light.bearish
	assert special_chart_series_color(light, 9) == light.palette[1]
	assert special_chart_mix(0x000000, 0xffffff, 0) == 0x000000
	assert special_chart_mix(0x000000, 0xffffff, 1) == 0xffffff
	assert special_chart_mix(0x000000, 0xffffff, 0.5) == 0x808080
	assert special_chart_ink_on(0x111111) == 0xffffff
	assert special_chart_ink_on(0xfde68a) == 0x111827
}

fn test_special_chart_number_formats() {
	assert special_chart_format(12345.678, 2) == '12,345.68'
	assert special_chart_format(1234567, 0) == '1,234,567'
	assert special_chart_format(-1234.5, 1) == '-1,234.5'
	assert special_chart_format(-0.004, 2) == '0.00'
	assert special_chart_format(0.05, 2) == '0.05'
	assert special_chart_format(math.nan(), 2) == '-'
	assert special_chart_auto_format(3) == '3'
	assert special_chart_auto_format(2.5) == '2.5'
	assert special_chart_auto_format(1234.567) == '1,234.57'
	assert special_chart_compact(1284) == '1,284'
	assert special_chart_compact(12900) == '12.9K'
	assert special_chart_compact(4.2e6) == '4.2M'
	assert special_chart_compact(-3.0e9) == '-3B'
	assert special_chart_compact(250e6) == '250M'
	assert special_chart_percent(0.321) == '32%'
	assert special_chart_percent(0.097) == '9.7%'
	assert special_chart_percent(0.05) == '5%'
}

fn test_special_chart_ticks_are_round() {
	assert special_chart_nice_step(94, 4) == 25
	assert special_chart_nice_step(1, 5) == 0.2
	assert special_chart_nice_step(37, 5) == 10
	assert special_chart_tick_values(181.3, 211.7, 10) == [190.0, 200, 210]
	assert special_chart_decimals(0.25) == 2
	assert special_chart_decimals(10) == 0
}

fn test_special_chart_spread_moves_labels_apart_as_little_as_it_can() {
	// Already apart: nothing moves.
	assert special_chart_spread([10.0, 40, 70], 16, 0, 100) == [10.0, 40, 70]
	// Two labels on one spot are centered on it, a gap apart.
	pair := special_chart_spread([50.0, 50], 16, 0, 100)
	assert special_chart_test_close(pair[0], 42) && special_chart_test_close(pair[1], 58)
	// Order of the input is kept, and every center stays in bounds.
	crowd := special_chart_spread([95.0, 2, 90, 5, 93], 16, 8, 92)
	mut sorted := crowd.clone()
	sorted.sort()
	for i in 1 .. sorted.len {
		assert sorted[i] - sorted[i - 1] >= 16 - 1e-9
	}
	for c in crowd {
		assert c >= 8 - 1e-9
	}
	assert crowd[1] < crowd[3] && crowd[3] < crowd[2] && crowd[2] < crowd[4]
	assert crowd[4] < crowd[0]
	assert special_chart_spread([]f64{}, 10, 0, 10).len == 0
}

fn test_special_chart_legend_wraps_and_centers_rows() {
	items := ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'].map(SpecialChartLegendItem{
		label: it
		color: 0x123456
	})
	frames := special_chart_legend_layout(items, 180, 12, false)
	assert frames.len == 5
	mut rows := map[f64][]Rect{}
	for f in frames {
		assert f.x >= 0 && f.x + f.width <= 180 + 1e-9
		rows[f.y] << f
	}
	assert rows.len > 1
	for _, row in rows {
		left := row[0].x
		right := row[row.len - 1].x + row[row.len - 1].width
		assert math.abs(left - (180 - right)) < 1.0
		for i in 1 .. row.len {
			assert row[i].x >= row[i - 1].x + row[i - 1].width
		}
	}
	column := special_chart_legend_layout(items, 300, 12, true)
	for i in 1 .. column.len {
		assert column[i].x == 0 && column[i].y > column[i - 1].y
	}
}

fn test_special_chart_tooltip_flips_and_stays_inside() {
	bounds := rect(0, 0, 300, 200)
	right := special_chart_tooltip_place(rect(100, 100, 0, 0), 80, 40, bounds, 10, false)
	assert right == rect(110, 80, 80, 40)
	flipped := special_chart_tooltip_place(rect(250, 100, 0, 0), 80, 40, bounds, 10, false)
	assert flipped.x == 160
	preferred := special_chart_tooltip_place(rect(150, 5, 0, 0), 80, 40, bounds, 10, true)
	assert preferred.x == 60 && preferred.y == 0
	rows := [
		SpecialChartTooltipRow{
			color: u32(0xff0000)
			name:  'Desktop'
			value: '373'
		},
		SpecialChartTooltipRow{
			name:  'Total'
			value: '560'
		},
	]
	w, h := special_chart_tooltip_size('Apr 5', rows, 12)
	assert w > special_chart_text_width('Desktop', 12, false) + special_chart_text_width('373',
		12, true)
	assert h == math.ceil(3 * special_chart_line(12) + 2 + 2 * special_chart_tooltip_pad_y)
	card := special_chart_tooltip('tip', rect(0, 0, w, h), 'Apr 5', rows, special_chart_colors(component_theme(false)),
		12)
	assert card.accessibility_label == 'Apr 5, Desktop 373, Total 560'
	assert special_chart_test_texts(card) == ['Apr 5', 'Desktop', '373', 'Total', '560']
}

fn test_special_chart_hit_strips_cover_a_region_with_few_rects() {
	// A disc of radius 40: every strip rect lies over the disc's samples.
	hits := special_chart_hit_strips(rect(0, 0, 100, 100), 5, 2, fn (x f64, y f64) int {
		return if math.hypot(x - 50, y - 50) <= 40 { 0 } else { -1 }
	})
	assert hits.len > 0 && hits.len <= 20
	for h in hits {
		assert h.index == 0
		cy := h.frame.y + h.frame.height / 2
		assert math.hypot(h.frame.x + h.frame.width / 2 - 50, cy - 50) <= 40
	}
	// Two halves of a box, each one rect after merging down.
	halves := special_chart_hit_strips(rect(0, 0, 40, 30), 6, 4, fn (x f64, y f64) int {
		return if x < 20 { 0 } else { 1 }
	})
	assert halves.len == 2
	assert halves[0].frame == rect(0, 0, 20, 30) && halves[0].index == 0
	assert halves[1].frame == rect(20, 0, 20, 30) && halves[1].index == 1
	assert special_chart_hit_strips(rect(0, 0, 0, 10), 6, 4, fn (x f64, y f64) int {
		return 0
	}).len == 0
}

fn test_special_chart_hover_event_reads_only_its_own_targets() {
	action := special_chart_hover_action('pie', 'slice:a')
	entered, target := special_chart_hover_event('pie', special_chart_test_event('enter',
		action)) or { panic('not decoded') }
	assert entered && target == 'slice:a'
	left, _ := special_chart_hover_event('pie', special_chart_test_event('leave', action)) or {
		panic('not decoded')
	}
	assert !left
	for event in [special_chart_test_event('down', action), special_chart_test_event('enter',
		special_chart_hover_action('other', 'slice:a')), 'pie:component:hover:slice:a',
		special_chart_test_event('enter', component_part_id('pie', 'hover:'))] {
		if _, _ := special_chart_hover_event('pie', event) {
			assert false, 'decoded ${event}'
		}
	}
}

fn test_special_chart_keys_default_and_must_be_unique() {
	assert special_chart_keys(['', 'k', ''], ['A', 'B', ''], 'x')! == ['A', 'k', '2']
	if _ := special_chart_keys(['', 'A'], ['A', ''], 'slice') {
		assert false, 'duplicate keys accepted'
	}
}

fn test_special_chart_appear_runs_once_and_honors_reduce_motion() {
	still, driver := special_chart_appear('appear-still', '', true, true, 1.0)
	assert still == 1 && driver.hidden && driver.id.len > 0
	off, _ := special_chart_appear('appear-off', '', false, false, 1.0)
	assert off == 1
	first, run := special_chart_appear('appear-run', 'k', true, false, 1.0)
	assert first == 0
	assert animation_info(run.id).status == .running
	// Halfway through the run the chart is drawn as far as the curve says.
	apply_widget_animations_at(run, time.ticks() + 500)
	half, _ := special_chart_appear('appear-run', 'k', true, false, 1.0)
	assert half > 0.85 && half < 1
	apply_widget_animations_at(run, time.ticks() + 2000)
	done, _ := special_chart_appear('appear-run', 'k', true, false, 1.0)
	assert done == 1
	// A new key draws it in again and forgets the old run.
	again, _ := special_chart_appear('appear-run', 'k2', true, false, 1.0)
	assert again == 0
	assert animation_info(run.id).status == .idle
}

fn test_special_chart_glide_places_then_slides() {
	id := 'glide-test'
	special_chart_glide(id, 10, 20, 0.2)
	target := special_chart_glide_target(id) or { panic('no glide') }
	assert target == path_point(10, 20)
	assert animation_info(id).duration == 0
	special_chart_glide(id, 30, 20, 0.2)
	assert animation_info(id).duration == 0.2
	special_chart_glide(id, 30, 20, 0)
	assert animation_info(id).status == .idle
	special_chart_glide(id, 5, 5, 0.2)
	special_chart_glide_reset(id)
	assert special_chart_glide_target(id) == none
}

// ── Pie ───────────────────────────────────────────────────────────

fn pie_test_slices() []PieSlice {
	return [
		PieSlice{
			label: 'Chrome'
			value: 50
		},
		PieSlice{
			label: 'Safari'
			value: 25
		},
		PieSlice{
			label: 'Gone'
			value: 0
		},
		PieSlice{
			key:   'ff'
			label: 'Firefox'
			value: 25
		},
	]
}

fn test_pie_chart_arcs_share_the_turn() {
	arcs := pie_chart_arcs(pie_test_slices(), 0)
	assert arcs.len == 3
	assert arcs.map(it.key) == ['Chrome', 'Safari', 'ff']
	assert arcs.map(it.index) == [0, 1, 3]
	assert special_chart_test_close(arcs[0].share, 0.5)
	assert special_chart_test_close(arcs[0].end, math.pi)
	assert arcs[1].start == arcs[0].end && arcs[2].start == arcs[1].end
	assert special_chart_test_close(arcs[2].end, 2 * math.pi)
	turned := pie_chart_arcs(pie_test_slices(), math.pi / 2)
	assert special_chart_test_close(turned[0].start, math.pi / 2)
	half := pie_chart_sweep(arcs, 0, 0.5)
	assert special_chart_test_close(half[2].end, math.pi)
	assert special_chart_test_close(half[0].end, math.pi / 2)
	assert pie_chart_arcs([PieSlice{
		value: -1
	}], 0).len == 0
}

fn test_pie_chart_pad_keeps_the_gap_equally_wide() {
	pad := 0.1
	outer := 100.0
	half_gap := outer * pad / 2
	for inner in [0.0, 40] {
		path := pie_chart_slice_path(0, 0, inner, outer, 0, math.pi / 2, pad)
		assert path.len > 2 && path[0].verb == .move_to
		// The slice starts at twelve o'clock: its first side runs straight up,
		// half a gap to the right of the center line.
		assert special_chart_test_close(path[0].x, half_gap)
		last := path[path.len - 2]
		if inner > 0 {
			assert special_chart_test_close(last.x, half_gap)
		} else {
			// A pie slice's sides meet at an apex on its middle line.
			assert special_chart_test_close(last.x, last.y * -1)
		}
		for cmd in path {
			if cmd.verb != .close {
				assert math.hypot(cmd.x, cmd.y) <= outer + 1e-6
			}
		}
	}
	// Too thin for its gap: no path.
	assert pie_chart_slice_path(0, 0, 0, 100, 0, 0.05, 0.1).len == 0
	// No pad: the plain sector and annular sector.
	assert pie_chart_slice_path(0, 0, 0, 100, 0, 1, 0) == path_sector(0, 0, 100, -math.pi / 2,
		1 - math.pi / 2)
}

fn test_pie_chart_arc_at_finds_the_slice_under_a_point() {
	arcs := pie_chart_arcs(pie_test_slices(), 0)
	assert pie_chart_arc_at(arcs, 50, 0, 0, 100) == 0 // Three o'clock: Chrome.
	assert pie_chart_arc_at(arcs, -10, 60, 0, 100) == 1 // Just past six o'clock: Safari.
	assert pie_chart_arc_at(arcs, -60, -10, 0, 100) == 2 // Ten o'clock: Firefox.
	assert pie_chart_arc_at(arcs, 5, 5, 30, 100) == -1 // In the hole.
	assert pie_chart_arc_at(arcs, 200, 0, 0, 100) == -1
}

fn test_pie_chart_outside_labels_never_overlap() {
	mut slices := []PieSlice{}
	for i in 0 .. 12 {
		slices << PieSlice{
			label: 's${i}'
			value: if i < 2 { 30.0 } else { 1.0 }
		}
	}
	arcs := pie_chart_arcs(slices, 0)
	widths := []f64{len: arcs.len, init: 40}
	line := 16.0
	placed := pie_chart_label_layout(arcs, 200, 150, 80, 95, widths, line, 0, 300)
	assert placed.len == arcs.len
	for side in [true, false] {
		mut ys := placed.filter(it.right == side).map(it.elbow.y)
		ys.sort()
		for i in 1 .. ys.len {
			assert ys[i] - ys[i - 1] >= line - 1e-6
		}
	}
	for p in placed {
		assert (p.text.x >= 200) == p.right
		// The elbow stays on the label circle, outside the ring.
		assert math.hypot(p.elbow.x - 200, p.elbow.y - 150) >= 95 - 1e-6
		assert special_chart_test_close(math.hypot(p.edge.x - 200, p.edge.y - 150), 80)
		assert p.text.y >= 0 && p.text.y + p.text.height <= 300 + 1e-6
	}
}

fn test_pie_chart_builds_slices_labels_legend_and_accessibility() {
	el := pie_chart(
		id:            'pie-build'
		frame:         rect(10, 20, 400, 300)
		slices:        pie_test_slices()
		inner_ratio:   0.6
		labels:        .outside
		label_content: .name_and_share
		legend:        .bottom
		appear:        false
		title:         'Browsers'
	)!
	assert el.accessibility_role == 'img'
	assert el.accessibility_label == 'Browsers'
	assert el.accessibility_value == 'Chrome 50%, Safari 25%, Firefox 25%'
	ring := special_chart_test_find(el, component_part_id('pie-build', 'ring')) or {
		panic('no ring')
	}
	assert ring.children.len == 3
	assert ring.children.all(it.path.len > 0 && it.frame.x == 0 && it.frame.y == 0)
	texts := special_chart_test_texts(el)
	assert 'Chrome 50%' in texts && 'Firefox 25%' in texts
	assert 'Chrome' in texts && '50%' in texts // The legend.
	assert special_chart_test_find(el, component_part_id('pie-build', 'leaders')) != none
	assert special_chart_test_find(el, component_part_id('pie-build', 'tooltip')) == none
	assert special_chart_test_hit_count(el) > 0
}

fn test_pie_chart_hovered_slice_lifts_and_shows_its_value() {
	config := PieChartConfig{
		id:     'pie-hover'
		frame:  rect(0, 0, 300, 300)
		slices: pie_test_slices()
		appear: false
	}
	el := pie_chart(PieChartConfig{
		...config
		hovered: 'Chrome'
	})!
	chrome := special_chart_test_find(el, component_part_id('pie-hover', 'slice:Chrome')) or {
		panic('no slice')
	}
	// Chrome spans twelve to six o'clock, so it lifts to the right.
	assert special_chart_test_close(chrome.frame.x, 6) && math.abs(chrome.frame.y) < 1e-9
	assert chrome.shape_style.fill_opacity == 1
	safari := special_chart_test_find(el, component_part_id('pie-hover', 'slice:Safari')) or {
		panic('no slice')
	}
	assert safari.shape_style.fill_opacity < 1 && safari.frame.x == 0
	tooltip := special_chart_test_find(el, component_part_id('pie-hover', 'tooltip')) or {
		panic('no tooltip')
	}
	assert special_chart_test_texts(tooltip) == ['Chrome', '50 (50.0%)']
	// The hover targets are on top: the pointer over a slice hovers it, also
	// where the tooltip is drawn.
	assert special_chart_test_hover_at(el, 200, 150)? == special_chart_hover_action('pie-hover',
		'slice:Chrome')
	assert special_chart_test_hover_at(el, 100, 200)? == special_chart_hover_action('pie-hover',
		'slice:Safari')
	assert special_chart_test_hover_at(el, 5, 5)? == ''
	// A doughnut reads the slice out in its hole instead.
	doughnut := pie_chart(PieChartConfig{
		...config
		inner_ratio: 0.6
		center_text: 'Total'
		hovered:     'Safari'
	})!
	assert special_chart_test_find(doughnut, component_part_id('pie-hover', 'tooltip')) == none
	texts := special_chart_test_texts(doughnut)
	assert '25' in texts && 'Safari · 25.0%' in texts && 'Total' !in texts
	// Without interaction there is no hover at all.
	still := pie_chart(PieChartConfig{
		...config
		hovered:     'Chrome'
		interactive: false
	})!
	assert special_chart_test_hit_count(still) == 0
	assert special_chart_test_find(still, component_part_id('pie-hover', 'tooltip')) == none
}

fn test_pie_chart_appear_sweeps_then_turns_on_hover() {
	config := PieChartConfig{
		id:      'pie-appear'
		frame:   rect(0, 0, 200, 200)
		slices:  pie_test_slices()
		hovered: 'Chrome'
	}
	first := pie_chart(config)!
	ring := special_chart_test_find(first, component_part_id('pie-appear', 'ring')) or {
		panic('no ring')
	}
	assert ring.children.all(it.path.len == 0)
	assert special_chart_test_hit_count(first) == 0
	apply_widget_animations_at(first, time.ticks() + 300)
	middle := pie_chart(config)!
	mid_ring := special_chart_test_find(middle, component_part_id('pie-appear', 'ring')) or {
		panic('no ring')
	}
	assert mid_ring.children[0].path.len > 0
	assert special_chart_test_find(middle, component_part_id('pie-appear', 'tooltip')) == none
	apply_widget_animations_at(middle, time.ticks() + 3000)
	whole := pie_chart(config)!
	assert special_chart_test_hit_count(whole) > 0
	assert special_chart_test_find(whole, component_part_id('pie-appear', 'tooltip')) != none
}

fn test_pie_chart_hover_decoder() {
	config := PieChartConfig{
		id:      'pie-events'
		slices:  pie_test_slices()
		hovered: 'Chrome'
	}
	enter := fn [config] (key string) string {
		return special_chart_test_event('enter', special_chart_hover_action(config.id, 'slice:${key}'))
	}
	leave := fn [config] (key string) string {
		return special_chart_test_event('leave', special_chart_hover_action(config.id, 'slice:${key}'))
	}
	assert pie_chart_hover_from_event(config, enter('Safari'))? == 'Safari'
	assert pie_chart_hover_from_event(config, enter('ff'))? == 'ff'
	assert pie_chart_hover_from_event(config, leave('Chrome'))? == ''
	for event in [enter('Chrome'), leave('Safari'), enter('Gone'), enter('Missing'),
		special_chart_test_event('enter', special_chart_hover_action('other', 'slice:Safari')),
		'pie-events:component:hover:slice:Safari', 'theme'] {
		if next := pie_chart_hover_from_event(config, event) {
			assert false, 'decoded ${event} as ${next}'
		}
	}
}

fn test_pie_chart_rejects_bad_configs() {
	for config in [
		PieChartConfig{
			slices: pie_test_slices()
		},
		PieChartConfig{
			id:     'p'
			slices: [PieSlice{
				value: math.nan()
			}]
		},
		PieChartConfig{
			id:     'p'
			slices: [PieSlice{
				label: 'a'
				value: 1
			}, PieSlice{
				label: 'a'
				value: 2
			}]
		},
		PieChartConfig{
			id:          'p'
			inner_ratio: 1
		},
		PieChartConfig{
			id:        'p'
			pad_angle: -0.1
		},
		PieChartConfig{
			id:    'p'
			frame: rect(0, 0, -1, 10)
		},
	] {
		if _ := pie_chart(config) {
			assert false, 'accepted ${config.id}'
		}
	}
	empty := pie_chart(id: 'p', frame: rect(0, 0, 100, 100), appear: false)!
	assert empty.accessibility_value == ''
}

// ── Radar ─────────────────────────────────────────────────────────

fn radar_test_config() RadarChartConfig {
	return RadarChartConfig{
		id:     'radar'
		frame:  rect(0, 0, 360, 300)
		axes:   ['Speed', 'Power', 'Range', 'Cost'].map(RadarAxis{
			label: it
		})
		series: [
			RadarSeries{
				name:   'A'
				values: [80.0, 40, 90, 30]
			},
			RadarSeries{
				name:   'B'
				values: [20.0, 30, 25, 20]
			},
		]
		appear: false
	}
}

fn test_radar_chart_geometry() {
	lo, hi := radar_chart_domain(radar_test_config().series, 0, 0, 4)
	assert lo == 0 && hi == 100
	lo2, hi2 := radar_chart_domain(radar_test_config().series, 10, 50, 4)
	assert lo2 == 10 && hi2 == 50
	up := radar_chart_direction(0, 4)
	assert special_chart_test_close(up.x, 0) && special_chart_test_close(up.y, -1)
	right := radar_chart_direction(1, 4)
	assert special_chart_test_close(right.x, 1) && special_chart_test_close(right.y, 0)
	points := radar_chart_polygon([100.0, 50, 150], 4, 0, 0, 80, 0, 100)
	assert special_chart_test_close(points[0].y, -80)
	assert special_chart_test_close(points[1].x, 40)
	assert special_chart_test_close(points[2].y, 80) // Clamped to the outer ring.
	assert special_chart_test_close(points[3].x, 0) && special_chart_test_close(points[3].y, 0)
	assert radar_chart_axis_at(4, 0, -50, 90) == 0
	assert radar_chart_axis_at(4, 50, 5, 90) == 1
	assert radar_chart_axis_at(4, -40, -45, 90) in [0, 3]
	assert radar_chart_axis_at(4, 0, 100, 90) == -1
	outer := [path_point(0, 0), path_point(100, 0), path_point(100, 100), path_point(0, 100)]
	inner := [path_point(40, 40), path_point(60, 40), path_point(60, 60), path_point(40, 60)]
	assert radar_chart_series_at([outer, inner], 50, 50) == 1
	assert radar_chart_series_at([outer, inner], 10, 10) == 0
	assert radar_chart_series_at([outer, inner], 150, 10) == -1
}

fn test_radar_chart_fits_its_labels() {
	plot := rect(0, 0, 300, 220)
	widths := [60.0, 90, 40, 70, 50]
	line := 17.0
	r := radar_chart_fit_radius(plot, widths, line, 10)
	assert r > 40 && r <= 110
	for i, w in widths {
		box := radar_chart_label_box(i, widths.len, 150, 110, r, 10, w, line)
		assert box.x >= -1e-6 && box.y >= -1e-6
		assert box.x + box.width <= 300 + 1e-6 && box.y + box.height <= 220 + 1e-6
	}
}

fn test_radar_chart_tooltip_corner_avoids_what_it_describes() {
	plot := rect(0, 0, 300, 200)
	// A spoke to the lower right puts the tooltip top left.
	assert radar_chart_tooltip_corner(path_point(0.8, 0.6), 80, 50, plot, []Rect{}) == rect(0,
		0, 80, 50)
	// With that corner taken, the next one clear of obstacles.
	assert radar_chart_tooltip_corner(path_point(0.8, 0.6), 80, 50, plot, [
		rect(10, 10, 20, 20),
	]) == rect(0, 150, 80, 50)
}

fn test_radar_chart_builds_and_hovers_an_axis() {
	config := radar_test_config()
	el := radar_chart(RadarChartConfig{
		...config
		level_labels: true
		hover:        RadarChartHover{
			axis: 'Range'
		}
	})!
	assert el.accessibility_value == 'A: Speed 80, Power 40, Range 90, Cost 30; B: Speed 20, Power 30, Range 25, Cost 20'
	assert special_chart_test_find(el, component_part_id('radar', 'series:A')) != none
	assert special_chart_test_find(el, component_part_id('radar', 'grid')) != none
	dot := special_chart_test_find(el, component_part_id('radar', 'hover-dot:A')) or {
		panic('no dot')
	}
	assert dot.frame.width == 10
	tooltip := special_chart_test_find(el, component_part_id('radar', 'tooltip')) or {
		panic('no tooltip')
	}
	assert special_chart_test_texts(tooltip) == ['Range', 'A', '90', 'B', '25']
	texts := special_chart_test_texts(el)
	assert '25' in texts && '100' in texts // Ring values.
	// The plot's center is hovered by the spoke nearest the pointer.
	plot_hit := special_chart_test_hover_at(el, 180, 40)?
	assert plot_hit == special_chart_hover_action('radar', 'axis:Speed')
	// Legend items hover their series.
	mut legend_hits := 0
	for c in el.children {
		if c.hoverable && c.children.len > 0 {
			legend_hits++
		}
	}
	assert legend_hits == 2
}

fn test_radar_chart_series_mode_hovers_the_smallest_polygon() {
	config := RadarChartConfig{
		...radar_test_config()
		hover_mode: .series
		hover:      RadarChartHover{
			series: 'B'
		}
	}
	el := radar_chart(config)!
	b := special_chart_test_find(el, component_part_id('radar', 'series:B')) or {
		panic('no series')
	}
	a := special_chart_test_find(el, component_part_id('radar', 'series:A')) or {
		panic('no series')
	}
	assert b.shape_style.fill_opacity > a.shape_style.fill_opacity
	assert a.shape_style.stroke_opacity < 1
	tooltip := special_chart_test_find(el, component_part_id('radar', 'tooltip')) or {
		panic('no tooltip')
	}
	assert special_chart_test_texts(tooltip)[0] == 'B'
	// Near the center both polygons contain the point; B is the smaller.
	center_hit := special_chart_test_hover_at(el, 182, 128)?
	assert center_hit == special_chart_hover_action('radar', 'series:B')
}

fn test_radar_chart_hover_decoder_and_validation() {
	config := RadarChartConfig{
		...radar_test_config()
		hover: RadarChartHover{
			axis: 'Speed'
		}
	}
	axis := fn (phase string, key string) string {
		return special_chart_test_event(phase, special_chart_hover_action('radar', 'axis:${key}'))
	}
	series := fn (phase string, key string) string {
		return special_chart_test_event(phase, special_chart_hover_action('radar', 'series:${key}'))
	}
	assert radar_chart_hover_from_event(config, axis('enter', 'Cost'))? == RadarChartHover{
		axis: 'Cost'
	}
	assert radar_chart_hover_from_event(config, axis('leave', 'Speed'))? == RadarChartHover{}
	assert radar_chart_hover_from_event(config, series('enter', 'A'))? == RadarChartHover{
		axis:   'Speed'
		series: 'A'
	}
	for event in [axis('enter', 'Speed'), axis('leave', 'Cost'), axis('enter', 'Nope'),
		series('leave', 'A'), series('enter', 'C')] {
		if _ := radar_chart_hover_from_event(config, event) {
			assert false, 'decoded ${event}'
		}
	}
	for bad in [
		RadarChartConfig{
			...radar_test_config()
			grid_levels: 0
		},
		RadarChartConfig{
			...radar_test_config()
			fill_opacity: 2
		},
		RadarChartConfig{
			...radar_test_config()
			series: [RadarSeries{
				name:   'A'
				values: [math.inf(1)]
			}]
		},
		RadarChartConfig{
			...radar_test_config()
			axes: [RadarAxis{
				label: 'x'
			}, RadarAxis{
				label: 'x'
			}]
		},
	] {
		if _ := radar_chart(bad) {
			assert false, 'bad radar accepted'
		}
	}
}

// ── Candlestick ───────────────────────────────────────────────────

fn candle_test_data() []Candle {
	closes := [10.0, 11, 12, 11, 13, 14]
	mut out := []Candle{}
	for i, c in closes {
		open := if i == 0 { 9.5 } else { closes[i - 1] }
		out << Candle{
			label:  'd${i}'
			open:   open
			high:   math.max(open, c) + 0.5
			low:    math.min(open, c) - 0.5
			close:  c
			volume: f64(100 * (i + 1))
		}
	}
	return out
}

fn test_candlestick_math() {
	data := candle_test_data()
	ma := candlestick_moving_average(data, 3)
	assert math.is_nan(ma[0]) && math.is_nan(ma[1])
	assert special_chart_test_close(ma[2], 11)
	assert special_chart_test_close(ma[5], (11.0 + 13 + 14) / 3)
	assert candlestick_moving_average(data, 0).all(math.is_nan(it))
	lo, hi := candlestick_price_range(data, [ma])
	assert lo < 9 && hi > 14.5
	flat_lo, flat_hi := candlestick_price_range([Candle{
		open:  5
		high:  5
		low:   5
		close: 5
	}], [][]f64{})
	assert flat_lo < 5 && flat_hi > 5
	delta, share := candlestick_change(data, 3)
	assert delta == -1 && special_chart_test_close(share, -1.0 / 12)
	first, _ := candlestick_change(data, 0)
	assert first == 0.5
	assert candlestick_label_interval(40, 10) == 6
	assert candlestick_label_interval(10, 40) == 1
}

fn test_candlestick_layout_places_panes_and_candles() {
	config := CandlestickChartConfig{
		id:              'candles'
		candles:         candle_test_data()
		volume:          true
		moving_averages: [3]
	}
	layout := candlestick_layout(config, 600, 300)
	assert layout.volume.y >= layout.price.y + layout.price.height
	assert layout.axis.x == layout.price.x + layout.price.width && layout.axis.width > 0
	assert layout.legend.height > 0 && layout.price.y >= layout.legend.height
	// Six candles across a wide pane keep the 30 point band and are centered.
	assert layout.band == 30
	assert special_chart_test_close(layout.candlestick_center(0) - layout.price.x,
		layout.price.x + layout.price.width - layout.candlestick_center(5))
	assert layout.price_y(layout.hi) == layout.price.y
	assert layout.price_y(layout.lo) == layout.price.y + layout.price.height
	assert layout.tick_value.len >= 2 && layout.tick_label.len == layout.tick_value.len
	narrow := candlestick_layout(CandlestickChartConfig{
		...config
		volume: false
		legend: false
	}, 120, 200)
	assert narrow.volume.height == 0 && narrow.band < 30
}

fn test_candlestick_chart_draws_candles_and_hover() {
	config := CandlestickChartConfig{
		id:              'candles'
		frame:           rect(0, 0, 600, 320)
		candles:         candle_test_data()
		volume:          true
		moving_averages: [3]
		appear:          false
	}
	el := candlestick_chart(config)!
	up := special_chart_test_find(el, component_part_id('candles', 'bodies:up')) or {
		panic('no bodies')
	}
	down := special_chart_test_find(el, component_part_id('candles', 'bodies:down')) or {
		panic('no bodies')
	}
	assert special_chart_test_subpaths(up.path) == 5
	assert special_chart_test_subpaths(down.path) == 1
	assert special_chart_test_find(el, component_part_id('candles', 'volume:up')) != none
	assert special_chart_test_find(el, component_part_id('candles', 'ma:3')) != none
	assert special_chart_test_hit_count(el) == 6
	assert el.accessibility_value.starts_with('6 periods from d0 to d5')
	hovered := candlestick_chart(CandlestickChartConfig{
		...config
		hovered: 'd3'
	})!
	tooltip := special_chart_test_find(hovered, component_part_id('candles', 'tooltip')) or {
		panic('no tooltip')
	}
	texts := special_chart_test_texts(tooltip)
	assert texts[0] == 'd3'
	assert texts[1..11] == ['Open', '12.00', 'High', '12.50', 'Low', '10.50', 'Close', '11.00',
		'Change', '-1.00 (-8.33%)']
	assert 'Volume' in texts && 'MA 3' in texts
	band := special_chart_test_find(hovered, component_part_id('candles', 'band')) or {
		panic('no band')
	}
	layout := candlestick_layout(config, 600, 320)
	assert special_chart_test_close(band.frame.x + band.frame.width / 2, layout.candlestick_center(3))
	assert special_chart_test_find(hovered, component_part_id('candles', 'price-tag')) != none
	// Every candle's band answers the pointer, the tooltip notwithstanding.
	for i in 0 .. 6 {
		hit := special_chart_test_hover_at(hovered, layout.candlestick_center(i), layout.price.y +
			10)?
		assert hit == special_chart_hover_action('candles', 'candle:d${i}')
	}
}

fn test_candlestick_chart_reveals_from_the_left() {
	config := CandlestickChartConfig{
		id:             'candles-appear'
		frame:          rect(0, 0, 600, 320)
		candles:        candle_test_data()
		max_band_width: 0
	}
	first := candlestick_chart(config)!
	assert special_chart_test_find(first, component_part_id('candles-appear', 'bodies:up')) == none
	apply_widget_animations_at(first, time.ticks() + 250)
	part := candlestick_chart(config)!
	bodies := special_chart_test_find(part, component_part_id('candles-appear', 'bodies:up')) or {
		panic('no bodies')
	}
	assert special_chart_test_subpaths(bodies.path) in [1, 2, 3, 4]
	assert special_chart_test_hit_count(part) == 0
}

fn test_candlestick_hover_decoder_and_validation() {
	config := CandlestickChartConfig{
		id:      'candles'
		candles: candle_test_data()
		hovered: 'd1'
	}
	ev := fn (phase string, key string) string {
		return special_chart_test_event(phase, special_chart_hover_action('candles', 'candle:${key}'))
	}
	assert candlestick_chart_hover_from_event(config, ev('enter', 'd2'))? == 'd2'
	assert candlestick_chart_hover_from_event(config, ev('leave', 'd1'))? == ''
	for event in [ev('enter', 'd1'), ev('leave', 'd2'), ev('enter', 'd9')] {
		if _ := candlestick_chart_hover_from_event(config, event) {
			assert false, 'decoded ${event}'
		}
	}
	bad_candle := Candle{
		label: 'x'
		open:  5
		high:  4
		low:   3
		close: 4
	}
	for bad in [
		CandlestickChartConfig{
			id:      'c'
			candles: [bad_candle]
		},
		CandlestickChartConfig{
			id:      'c'
			candles: [Candle{
				label:  'x'
				open:   1
				high:   1
				low:    1
				close:  1
				volume: -1
			}]
		},
		CandlestickChartConfig{
			id:              'c'
			moving_averages: [0]
		},
		CandlestickChartConfig{
			id:               'c'
			body_width_ratio: 0
		},
		CandlestickChartConfig{
			id:      'c'
			candles: [candle_test_data()[0], candle_test_data()[0]]
		},
	] {
		if _ := candlestick_chart(bad) {
			assert false, 'bad candlestick accepted'
		}
	}
}

// ── Sankey ────────────────────────────────────────────────────────

fn sankey_test_nodes(labels ...string) []SankeyNode {
	return labels.map(SankeyNode{
		label: it
	})
}

fn sankey_test_link(s string, t string, v f64) SankeyLink {
	return SankeyLink{
		source: s
		target: t
		value:  v
	}
}

fn test_sankey_columns_follow_the_longest_path() {
	nodes := sankey_test_nodes('a', 'b', 'c', 'd')
	links := [sankey_test_link('a', 'b', 5), sankey_test_link('b', 'c', 5),
		sankey_test_link('a', 'c', 3), sankey_test_link('a', 'd', 2)]
	// c is two steps from a; d leads nowhere, so justify puts it last.
	assert sankey_columns(nodes, links, .justify)! == [[0], [1], [2, 3]]
	assert sankey_columns(nodes, links, .left)! == [[0], [1, 3], [2]]
	assert sankey_columns(nodes, links, .right)! == [[0], [1], [2, 3]]
	center := sankey_columns(sankey_test_nodes('a', 'b', 'c', 'e'), [
		sankey_test_link('a', 'b', 1),
		sankey_test_link('b', 'c', 1),
		sankey_test_link('e', 'c', 1),
	], .center)!
	// e feeds c only, so it moves up next to c.
	assert center == [[0], [1, 3], [2]]
}

fn test_sankey_layout_sizes_nodes_by_flow() {
	nodes := sankey_test_nodes('a', 'b', 'c', 'd')
	links := [sankey_test_link('a', 'c', 30), sankey_test_link('b', 'c', 10),
		sankey_test_link('c', 'd', 40)]
	layout := sankey_layout(nodes, links, SankeyLayoutOptions{
		extent: rect(0, 0, 300, 200)
	})!
	assert layout.layers == 3
	a, b, c, d := layout.nodes[0], layout.nodes[1], layout.nodes[2], layout.nodes[3]
	assert special_chart_test_close((a.y1 - a.y0) / (b.y1 - b.y0), 3)
	assert special_chart_test_close(c.y1 - c.y0, d.y1 - d.y0)
	assert c.throughput() == 40 && c.inflow == 40 && c.outflow == 40
	assert a.x0 == 0 && d.x1 == 300 && c.x1 - c.x0 == 10
	for n in layout.nodes {
		assert n.y0 >= -1e-6 && n.y1 <= 200 + 1e-6
	}
	// a and b share a column a padding apart.
	assert math.abs(a.y1 - b.y0) >= 16 - 1e-6 || math.abs(b.y1 - a.y0) >= 16 - 1e-6
	// The links of a side fill it, stacked in order.
	mut total := 0.0
	for l in c.target_links {
		total += layout.links[l].target_width
	}
	assert special_chart_test_close(total, c.y1 - c.y0)
	first := layout.links[c.target_links[0]]
	assert special_chart_test_close(first.y1 - first.target_width / 2, c.y0)
}

fn test_sankey_relaxation_uncrosses_links() {
	// Input order would cross A->D and B->C; relaxation reorders a column so
	// the two ribbons run side by side.
	nodes := sankey_test_nodes('A', 'B', 'C', 'D')
	links := [sankey_test_link('A', 'D', 10), sankey_test_link('B', 'C', 10)]
	layout := sankey_layout(nodes, links, SankeyLayoutOptions{
		extent: rect(0, 0, 200, 200)
	})!
	assert (layout.nodes[0].y0 < layout.nodes[1].y0) == (layout.nodes[3].y0 < layout.nodes[2].y0)
	// Without passes, nodes keep their input order.
	still := sankey_layout(nodes, links, SankeyLayoutOptions{
		extent:     rect(0, 0, 200, 200)
		iterations: 0
	})!
	assert still.nodes[2].y0 < still.nodes[3].y0
}

fn test_sankey_link_ordering_follows_the_other_end() {
	nodes := sankey_test_nodes('s', 'x', 'y', 'z')
	links := [sankey_test_link('s', 'z', 5), sankey_test_link('s', 'x', 5),
		sankey_test_link('s', 'y', 5)]
	layout := sankey_layout(nodes, links, SankeyLayoutOptions{
		extent: rect(0, 0, 200, 300)
	})!
	outgoing := layout.nodes[0].source_links
	for k in 1 .. outgoing.len {
		before := layout.nodes[layout.links[outgoing[k - 1]].target].y0
		after := layout.nodes[layout.links[outgoing[k]].target].y0
		assert before < after
		assert layout.links[outgoing[k]].y0 > layout.links[outgoing[k - 1]].y0
	}
}

fn test_sankey_sqrt_scale_fills_both_sides() {
	nodes := sankey_test_nodes('a', 'b', 'c', 'd')
	links := [sankey_test_link('a', 'b', 100), sankey_test_link('b', 'c', 64),
		sankey_test_link('b', 'd', 36)]
	layout := sankey_layout(nodes, links, SankeyLayoutOptions{
		extent:      rect(0, 0, 300, 200)
		value_scale: .sqrt
	})!
	b := layout.nodes[1]
	mut out_total := 0.0
	for l in b.source_links {
		out_total += layout.links[l].source_width
	}
	assert special_chart_test_close(out_total, b.y1 - b.y0)
	incoming := layout.links[b.target_links[0]]
	assert special_chart_test_close(incoming.target_width, b.y1 - b.y0)
	assert b.throughput() == 100
}

fn test_sankey_layout_rejects_cycles_and_bad_links() {
	nodes := sankey_test_nodes('a', 'b', 'c')
	for links in [
		[sankey_test_link('a', 'b', 1), sankey_test_link('b', 'c', 1), sankey_test_link('c', 'a', 1)],
		[sankey_test_link('a', 'a', 1)],
		[sankey_test_link('a', 'nope', 1)],
		[sankey_test_link('a', 'b', -1)],
		[sankey_test_link('a', 'b', math.nan())],
	] {
		if _ := sankey_layout(nodes, links, SankeyLayoutOptions{
			extent: rect(0, 0, 100, 100)
		})
		{
			assert false, 'bad links accepted'
		}
	}
	if _ := sankey_layout(sankey_test_nodes('a', 'a'), []SankeyLink{}, SankeyLayoutOptions{}) {
		assert false, 'duplicate nodes accepted'
	}
	// A link worth zero is left out, and does not make a cycle.
	zero := sankey_layout(nodes, [sankey_test_link('a', 'b', 2), sankey_test_link('b', 'a', 0)],
		SankeyLayoutOptions{
			extent: rect(0, 0, 100, 100)
		})!
	assert zero.links.len == 1 && zero.links[0].index == 0
}

fn test_sankey_ribbon_pieces_meet_exactly() {
	x0, y0, w0, x1, y1, w1 := 10.0, 20.0, 8.0, 110.0, 80.0, 12.0
	top0, bottom0 := sankey_ribbon_span(x0, y0, w0, x1, y1, w1, x0)
	assert special_chart_test_close(top0, 16) && special_chart_test_close(bottom0, 24)
	top1, bottom1 := sankey_ribbon_span(x0, y0, w0, x1, y1, w1, x1)
	assert special_chart_test_close(top1, 74) && special_chart_test_close(bottom1, 86)
	left := sankey_ribbon_piece(x0, y0, w0, x1, y1, w1, 0, 47)
	right := sankey_ribbon_piece(x0, y0, w0, x1, y1, w1, 47, 200)
	// left ends where right starts: at x 47, at the ribbon's span there.
	top, bottom := sankey_ribbon_span(x0, y0, w0, x1, y1, w1, 47)
	assert left[1].x == 47 && special_chart_test_close(left[1].y, top)
	assert left[2].x == 47 && special_chart_test_close(left[2].y, bottom)
	assert right[0].x == 47 && special_chart_test_close(right[0].y, top)
	assert special_chart_test_close(right[3].y, bottom)
	assert right[1].x == x1 && left[0].x == x0
	// The whole piece is the ribbon itself.
	whole := sankey_ribbon_piece(x0, y0, w0, x1, y1, w1, x0, x1)
	full := sankey_ribbon_path(x0, y0, w0, x1, y1, w1)
	for i, cmd in whole {
		assert special_chart_test_close(cmd.x, full[i].x) && special_chart_test_close(cmd.y, full[i].y)
		assert special_chart_test_close(cmd.cx1, full[i].cx1)
		assert special_chart_test_close(cmd.cy2, full[i].cy2)
	}
	assert sankey_ribbon_piece(x0, y0, w0, x1, y1, w1, 120, 130).len == 0
	hits := sankey_link_hit_rects(x0, y0, w0, x1, y1, w1, 10)
	assert hits.len == 10 && hits[0].x == x0
	for h in hits {
		mid_top, mid_bottom := sankey_ribbon_span(x0, y0, w0, x1, y1, w1, h.x + h.width / 2)
		assert h.y <= mid_top + 1e-6 && h.y + h.height >= mid_bottom - 1e-6
	}
}

fn sankey_test_config() SankeyChartConfig {
	return SankeyChartConfig{
		id:     'flow'
		frame:  rect(0, 0, 500, 300)
		nodes:  sankey_test_nodes('Coal', 'Gas', 'Power', 'Homes', 'Losses')
		links:  [sankey_test_link('Coal', 'Power', 40), sankey_test_link('Gas', 'Power', 60),
			sankey_test_link('Gas', 'Homes', 30), sankey_test_link('Power', 'Homes', 70),
			sankey_test_link('Power', 'Losses', 30)]
		unit:   'TWh'
		appear: false
	}
}

fn test_sankey_chart_draws_nodes_ribbons_and_labels() {
	config := sankey_test_config()
	el := sankey_chart(config)!
	for key in ['Coal', 'Gas', 'Power', 'Homes', 'Losses'] {
		assert special_chart_test_find(el, component_part_id('flow', 'node:${key}')) != none
	}
	texts := special_chart_test_texts(el)
	assert 'Power' in texts && '100 TWh' in texts && '90 TWh' in texts
	// Gradient ribbons are drawn in bands blending the node colors.
	band0 := special_chart_test_find(el, component_part_id('flow', 'link:0:0')) or {
		panic('no band')
	}
	band1 := special_chart_test_find(el, component_part_id('flow', 'link:0:1')) or {
		panic('no band')
	}
	assert band0.shape_style.fill != band1.shape_style.fill
	source := special_chart_test_find(el, component_part_id('flow', 'link:4:0')) or {
		panic('no band')
	}
	plain := sankey_chart(SankeyChartConfig{
		...config
		link_color: .source
	})!
	assert special_chart_test_find(plain, component_part_id('flow', 'link:0:1')) == none
	only := special_chart_test_find(plain, component_part_id('flow', 'link:4:0')) or {
		panic('no ribbon')
	}
	assert only.shape_style.fill != source.shape_style.fill
	assert el.accessibility_value.contains('Coal to Power 40 TWh')
	assert special_chart_test_hit_count(el) > 5
}

fn test_sankey_chart_hover_highlights_a_node_and_its_links() {
	config := SankeyChartConfig{
		...sankey_test_config()
		hover: SankeyChartHover{
			node: 'Coal'
		}
	}
	el := sankey_chart(config)!
	attached := special_chart_test_find(el, component_part_id('flow', 'link:0:0')) or {
		panic('no ribbon')
	}
	other := special_chart_test_find(el, component_part_id('flow', 'link:2:0')) or {
		panic('no ribbon')
	}
	assert attached.shape_style.fill_opacity > config.link_opacity
	assert other.shape_style.fill_opacity < config.link_opacity
	tooltip := special_chart_test_find(el, component_part_id('flow', 'tooltip')) or {
		panic('no tooltip')
	}
	assert special_chart_test_texts(tooltip) == ['Coal', 'Outflow', '40 TWh']
	layout := sankey_chart_layout(config, 500, 300)!
	coal := layout.nodes[0]
	hit := special_chart_test_hover_at(el, (coal.x0 + coal.x1) / 2, (coal.y0 + coal.y1) / 2)?
	assert hit == special_chart_hover_action('flow', 'node:Coal')
	link := sankey_chart(SankeyChartConfig{
		...sankey_test_config()
		hover: SankeyChartHover{
			link: 4
		}
	})!
	link_tip := special_chart_test_find(link, component_part_id('flow', 'tooltip')) or {
		panic('no tooltip')
	}
	assert special_chart_test_texts(link_tip) == ['Power → Losses', 'Flow', '30 TWh', 'Share of Power',
		'30.0%']
	l := layout.links[4]
	mx := (layout.nodes[l.source].x1 + layout.nodes[l.target].x0) / 2
	top, bottom := sankey_ribbon_span(layout.nodes[l.source].x1, l.y0, l.source_width,
		layout.nodes[l.target].x0, l.y1, l.target_width, mx)
	along := special_chart_test_hover_at(link, mx, (top + bottom) / 2)?
	assert along == special_chart_hover_action('flow', 'link:4')
}

fn test_sankey_chart_hover_decoder_and_validation() {
	config := SankeyChartConfig{
		...sankey_test_config()
		hover: SankeyChartHover{
			node: 'Gas'
		}
	}
	node := fn (phase string, key string) string {
		return special_chart_test_event(phase, special_chart_hover_action('flow', 'node:${key}'))
	}
	link := fn (phase string, index string) string {
		return special_chart_test_event(phase, special_chart_hover_action('flow', 'link:${index}'))
	}
	assert sankey_chart_hover_from_event(config, node('enter', 'Coal'))? == SankeyChartHover{
		node: 'Coal'
	}
	assert sankey_chart_hover_from_event(config, node('leave', 'Gas'))? == SankeyChartHover{}
	assert sankey_chart_hover_from_event(config, link('enter', '2'))? == SankeyChartHover{
		link: 2
	}
	for event in [node('enter', 'Gas'), node('leave', 'Coal'), node('enter', 'Oil'),
		link('enter', '5'), link('enter', '02'), link('enter', '-1'), link('leave', '1')] {
		if _ := sankey_chart_hover_from_event(config, event) {
			assert false, 'decoded ${event}'
		}
	}
	for bad in [
		SankeyChartConfig{
			...sankey_test_config()
			id: ''
		},
		SankeyChartConfig{
			...sankey_test_config()
			link_opacity: 1.5
		},
		SankeyChartConfig{
			...sankey_test_config()
			links: [sankey_test_link('Coal', 'Coal', 1)]
		},
	] {
		if _ := sankey_chart(bad) {
			assert false, 'bad sankey accepted'
		}
	}
	empty := sankey_chart(id: 'flow-empty', frame: rect(0, 0, 100, 100), appear: false)!
	assert empty.accessibility_label == 'Sankey chart'
}

fn test_sankey_chart_reveals_from_the_left() {
	config := SankeyChartConfig{
		...sankey_test_config()
		id:     'flow-appear'
		appear: true
	}
	first := sankey_chart(config)!
	assert special_chart_test_find(first, component_part_id('flow-appear', 'node:Coal')) == none
	apply_widget_animations_at(first, time.ticks() + 200)
	part := sankey_chart(config)!
	assert special_chart_test_find(part, component_part_id('flow-appear', 'node:Coal')) != none
	assert special_chart_test_find(part, component_part_id('flow-appear', 'node:Losses')) == none
	assert special_chart_test_hit_count(part) == 0
}
