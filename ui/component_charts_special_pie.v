module ui2

import math

// PieSlice is one datum of a pie or doughnut chart.
pub struct PieSlice {
pub:
	key   string // Stable identity for hover and element ids; defaults to the label.
	label string
	value f64  // Slices worth zero or less are left out.
	color ?u32 // Defaults to the theme palette, by the slice's position.
	// value_text is how the tooltip writes the value; it defaults to the value
	// and its share, "275 (32.1%)". Set it where the raw number is not what a
	// reader should see.
	value_text string
}

// PieChartLabels says where slices are labelled.
pub enum PieChartLabels {
	none
	inside  // Centered in a slice, when the text fits there.
	outside // Beside the ring, joined to the slice by a leader line.
}

// PieChartLabelContent is what a slice label says.
pub enum PieChartLabelContent {
	name
	share
	name_and_share
	value
}

pub struct PieChartConfig {
pub:
	id     string // Required: hover targets, slices and the appear use parts of it.
	frame  Rect
	slices []PieSlice
	// outer_radius of the ring in points; zero fits the ring, and its outside
	// labels, in the frame.
	outer_radius f64
	// inner_radius in points makes a doughnut; inner_ratio sets it as a share
	// of the outer radius instead (0.6 is a typical doughnut).
	inner_radius f64
	inner_ratio  f64
	// pad_angle is the gap between slices in radians at the outer radius. The
	// gap keeps its width all the way in, as GPUI Kit's does.
	pad_angle     f64
	start_angle   f64 // Radians clockwise from twelve o'clock where the first slice starts.
	labels        PieChartLabels
	label_content PieChartLabelContent
	label_gap     f64 = 15 // Between the ring and the outside labels.
	label_color   ?u32 // Outside label text; the theme's foreground by default.
	leader_color  ?u32 // Leader lines; a muted line color by default.
	// center_text and center_caption are written in a doughnut's hole, such
	// as a total and what it counts.
	center_text    string
	center_caption string
	legend         SpecialChartLegendPosition
	name           string // What the values measure: the tooltip row's name for a slice without a label.
	// hovered is the key of the slice under the pointer: it lifts out of the
	// ring, the others fade, and a tooltip shows its value and share. Feed
	// pie_chart_hover_from_event the chart's events to keep it.
	hovered    string
	hover_lift f64 = 6
	// hover_center reads the hovered slice out in a doughnut's hole, in place
	// of center_text, instead of in a floating tooltip.
	hover_center    bool = true
	interactive     bool = true // Off: no hover targets and no tooltip.
	appear          bool = true // Sweep the slices in clockwise the first time the chart is built.
	appear_key      string // A new key sweeps the chart in again.
	appear_duration f64 = 1.0
	reduce_motion   bool
	title           string // Accessibility label; "Pie chart" by default.
	size            ComponentSize = .medium
	theme           ComponentTheme
}

// PieChartArc is where one slice lies on the ring.
pub struct PieChartArc {
pub:
	index int    // The slice's position in PieChartConfig.slices.
	key   string // The slice's identity.
	value f64
	share f64 // Of the total of the positive values, 0...1.
	start f64 // Radians clockwise from twelve o'clock.
	end   f64
}

fn pie_chart_slice_keys(slices []PieSlice) ![]string {
	return special_chart_keys(slices.map(it.key), slices.map(it.label), 'pie slice')
}

// pie_chart_arcs lays the positive slices around the ring in order, from
// `start_angle` clockwise, each spanning its share of the full turn.
pub fn pie_chart_arcs(slices []PieSlice, start_angle f64) []PieChartArc {
	keys := pie_chart_slice_keys(slices) or { return []PieChartArc{} }
	mut total := 0.0
	for s in slices {
		if component_finite(s.value) && s.value > 0 {
			total += s.value
		}
	}
	mut arcs := []PieChartArc{}
	if total <= 0 {
		return arcs
	}
	mut angle := start_angle
	for i, s in slices {
		if !component_finite(s.value) || s.value <= 0 {
			continue
		}
		share := s.value / total
		arcs << PieChartArc{
			index: i
			key:   keys[i]
			value: s.value
			share: share
			start: angle
			end:   angle + share * 2 * math.pi
		}
		angle += share * 2 * math.pi
	}
	return arcs
}

// pie_chart_sweep is the ring `progress` (0...1) of the way through its
// appear: every angle scaled toward the start, so the slices sweep in
// clockwise together.
pub fn pie_chart_sweep(arcs []PieChartArc, start_angle f64, progress f64) []PieChartArc {
	p := math.clamp(progress, 0.0, 1.0)
	if p >= 1 {
		return arcs
	}
	return arcs.map(PieChartArc{
		...it
		start: start_angle + (it.start - start_angle) * p
		end:   start_angle + (it.end - start_angle) * p
	})
}

// pie_chart_screen_angle turns a chart angle (clockwise from twelve o'clock)
// into a path angle (clockwise from three o'clock).
fn pie_chart_screen_angle(angle f64) f64 {
	return angle - math.pi / 2
}

fn pie_chart_point(cx f64, cy f64, radius f64, angle f64) PathPoint {
	a := pie_chart_screen_angle(angle)
	return path_point(cx + radius * math.cos(a), cy + radius * math.sin(a))
}

// pie_chart_slice_path outlines a slice from `start` to `end` (chart angles)
// between the radii, with half of a `pad`-radian gap (measured at the outer
// radius) taken off each side. The sides stay parallel to the slice's edges,
// so the gap between two slices is equally wide from the rim to the center.
// A slice too thin for its gap has no path.
pub fn pie_chart_slice_path(cx f64, cy f64, inner f64, outer f64, start f64, end f64, pad f64) []PathCommand {
	span := end - start
	if outer <= 0 || span <= 1e-9 {
		return []PathCommand{}
	}
	r0 := math.clamp(inner, 0.0, outer)
	half_gap := if pad > 0 && span < 2 * math.pi - 1e-9 { outer * pad / 2 } else { 0.0 }
	if half_gap <= 0 {
		if r0 > 0 {
			return path_annular_sector(cx, cy, r0, outer, pie_chart_screen_angle(start), pie_chart_screen_angle(end))
		}
		return path_sector(cx, cy, outer, pie_chart_screen_angle(start), pie_chart_screen_angle(end))
	}
	if half_gap >= outer {
		return []PathCommand{}
	}
	outer_inset := math.asin(half_gap / outer)
	a0, a1 := start + outer_inset, end - outer_inset
	if a1 <= a0 {
		return []PathCommand{}
	}
	mid := (start + end) / 2
	// Where the two sides, each half a gap inside its edge, meet.
	apex_distance := if span < math.pi { half_gap / math.sin(span / 2) } else { half_gap }
	if apex_distance >= outer {
		return []PathCommand{}
	}
	mut path := path_arc(cx, cy, outer, pie_chart_screen_angle(a0), pie_chart_screen_angle(a1),
		false)
	if r0 > half_gap && apex_distance < r0 {
		inner_inset := math.asin(half_gap / r0)
		path << path_arc(cx, cy, r0, pie_chart_screen_angle(end - inner_inset), pie_chart_screen_angle(start +
			inner_inset), true)
	} else if span < math.pi {
		apex := pie_chart_point(cx, cy, apex_distance, mid)
		path << path_line_to(apex.x, apex.y)
	} else {
		// A slice wider than a half turn: its sides end half a gap from the
		// center, on either side of it.
		end_side := pie_chart_point(cx, cy, half_gap, end - math.pi / 2)
		start_side := pie_chart_point(cx, cy, half_gap, start + math.pi / 2)
		path << path_line_to(end_side.x, end_side.y)
		path << path_line_to(start_side.x, start_side.y)
	}
	path << path_close()
	return path
}

// pie_chart_arc_at returns the position in `arcs` of the slice under the point
// (dx, dy) from the ring's center, or -1 outside the ring. Gaps between slices
// count for the nearer slice.
pub fn pie_chart_arc_at(arcs []PieChartArc, dx f64, dy f64, inner f64, outer f64) int {
	r := math.hypot(dx, dy)
	if arcs.len == 0 || r > outer || r < inner {
		return -1
	}
	first := arcs[0].start
	mut angle := math.atan2(dy, dx) + math.pi / 2
	angle = first + math.fmod(math.fmod(angle - first, 2 * math.pi) + 2 * math.pi, 2 * math.pi)
	for i, a in arcs {
		if angle >= a.start && angle < a.end {
			return i
		}
	}
	return arcs.len - 1
}

// PieChartLabelPlacement is an outside label: its leader line runs from `edge`
// on the ring to `elbow` and across to `end`, and its text sits in `text`.
pub struct PieChartLabelPlacement {
pub:
	arc   int // Position in the arcs the labels were laid out for.
	right bool
	edge  PathPoint
	elbow PathPoint
	end   PathPoint
	text  Rect
}

// pie_chart_label_layout places outside labels for `arcs` (widths[i] is the
// text width of arcs[i]'s label). Each label starts level with its slice's
// middle at `label_radius`; the labels on each side are then moved apart as
// little as needed to keep `line` apart within top...bottom, and their elbows
// slide along the label circle so a leader line never crosses the ring. The
// text stands in a column just past the circle on its side.
pub fn pie_chart_label_layout(arcs []PieChartArc, cx f64, cy f64, edge_radius f64, label_radius f64, widths []f64, line f64, top f64, bottom f64) []PieChartLabelPlacement {
	mut sides := [][]int{len: 2}
	mut wanted := []f64{len: arcs.len}
	for i, a in arcs {
		if a.end - a.start < math.pi / 360 || i >= widths.len {
			continue
		}
		p := pie_chart_point(cx, cy, label_radius, (a.start + a.end) / 2)
		wanted[i] = p.y
		sides[if p.x >= cx - 1e-9 { 0 } else { 1 }] << i
	}
	mut out := []PieChartLabelPlacement{}
	for side, members in sides {
		if members.len == 0 {
			continue
		}
		right := side == 0
		centers := special_chart_spread(members.map(wanted[it]), line, top + line / 2, bottom - line / 2)
		sign := if right { 1.0 } else { -1.0 }
		for k, i in members {
			a := arcs[i]
			mid := (a.start + a.end) / 2
			y := centers[k]
			dy := y - cy
			natural := pie_chart_point(cx, cy, label_radius, mid)
			elbow_x := if math.abs(dy) < label_radius {
				cx + sign * math.sqrt(label_radius * label_radius - dy * dy)
			} else {
				natural.x
			}
			end_x := cx + sign * (label_radius + 4)
			text_x := if right { end_x + 4 } else { end_x - 4 - widths[i] }
			out << PieChartLabelPlacement{
				arc:   i
				right: right
				edge:  pie_chart_point(cx, cy, edge_radius, mid)
				elbow: path_point(elbow_x, y)
				end:   path_point(end_x, y)
				text:  rect(text_x, y - line / 2, widths[i], line)
			}
		}
	}
	return out
}

fn pie_chart_label_text(content PieChartLabelContent, slice PieSlice, arc PieChartArc) string {
	return match content {
		.name { slice.label }
		.share { special_chart_percent(arc.share) }
		.name_and_share { '${slice.label} ${special_chart_percent(arc.share)}' }
		.value { special_chart_auto_format(slice.value) }
	}
}

// pie_chart_value_text is how a slice's value reads in the tooltip.
pub fn pie_chart_value_text(slice PieSlice, share f64) string {
	if slice.value_text.len > 0 {
		return slice.value_text
	}
	return '${special_chart_auto_format(slice.value)} (${special_chart_format(share * 100, 1)}%)'
}

// pie_chart_radii resolves the ring for a plot area: the outer radius set or
// fitted (leaving room for outside labels `label_room` wide and for the hover
// lift), and the inner radius from inner_radius or inner_ratio.
fn pie_chart_radii(config PieChartConfig, plot Rect, label_room f64, line f64) (f64, f64) {
	lift := math.max(config.hover_lift, 0.0)
	mut outer := config.outer_radius
	if outer <= 0 {
		if config.labels == .outside {
			outer = math.min(plot.height / 2 - config.label_gap - line / 2, plot.width / 2 -
				config.label_gap - 8 - label_room)
			outer = math.min(outer, plot.height / 2 - lift - 1)
		} else {
			outer = math.min(plot.width, plot.height) / 2 - lift - 1
		}
	}
	outer = math.max(outer, 0.0)
	inner := if config.inner_radius > 0 {
		math.min(config.inner_radius, outer * 0.95)
	} else {
		outer * math.clamp(config.inner_ratio, 0.0, 0.95)
	}
	return outer, inner
}

fn pie_chart_validate(config PieChartConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	for s in config.slices {
		if !component_finite(s.value) {
			return error('pie slice values must be finite')
		}
	}
	pie_chart_slice_keys(config.slices)!
	special_chart_validate_length('pie outer_radius', config.outer_radius)!
	special_chart_validate_length('pie inner_radius', config.inner_radius)!
	special_chart_validate_length('pie label_gap', config.label_gap)!
	special_chart_validate_length('pie hover_lift', config.hover_lift)!
	special_chart_validate_length('pie appear_duration', config.appear_duration)!
	if !component_finite(config.inner_ratio) || config.inner_ratio < 0 || config.inner_ratio >= 1 {
		return error('pie inner_ratio must be in [0, 1)')
	}
	if !component_finite(config.pad_angle) || config.pad_angle < 0 || config.pad_angle >= math.pi {
		return error('pie pad_angle must be in [0, pi)')
	}
	if !component_finite(config.start_angle) {
		return error('pie start_angle must be finite')
	}
}

fn pie_chart_slice_color(config PieChartConfig, colors SpecialChartColors, index int) u32 {
	return config.slices[index].color or { special_chart_series_color(colors, index) }
}

// pie_chart builds a pie or doughnut chart: GPUI Kit's PieChart, drawn with
// vector slices. It is controlled: keep `hovered` with
// pie_chart_hover_from_event.
pub fn pie_chart(config PieChartConfig) !Element {
	pie_chart_validate(config)!
	colors := special_chart_colors(config.theme)
	font := special_chart_font(config.size)
	line := special_chart_line(font)
	local := component_local(config.frame)
	all_arcs := pie_chart_arcs(config.slices, config.start_angle)
	progress, driver := special_chart_appear(config.id, config.appear_key, config.appear,
		config.reduce_motion, config.appear_duration)
	whole := progress >= 1
	hovered := if config.interactive && whole { config.hovered } else { '' }
	mut hovered_arc := -1
	for i, a in all_arcs {
		if a.key == hovered {
			hovered_arc = i
		}
	}
	mut legend_items := []SpecialChartLegendItem{}
	if config.legend != .none {
		for a in all_arcs {
			legend_items << SpecialChartLegendItem{
				label:  config.slices[a.index].label
				value:  special_chart_percent(a.share)
				color:  pie_chart_slice_color(config, colors, a.index)
				action: if config.interactive {
					special_chart_hover_action(config.id, 'slice:${a.key}')
				} else {
					''
				}
				dimmed: hovered_arc >= 0 && a.key != hovered
			}
		}
	}
	plot, legend_area, legend_frames := special_chart_legend_area(local, legend_items, config.legend,
		font)
	mut label_texts := []string{len: all_arcs.len}
	mut label_widths := []f64{len: all_arcs.len}
	mut label_room := 0.0
	if config.labels != .none {
		for i, a in all_arcs {
			label_texts[i] = pie_chart_label_text(config.label_content, config.slices[a.index],
				a)
			label_widths[i] = math.ceil(special_chart_text_width(label_texts[i], font, config.labels == .inside))
			label_room = math.max(label_room, label_widths[i])
		}
	}
	outer, inner := pie_chart_radii(config, plot, label_room, line)
	cx, cy := plot.x + plot.width / 2, plot.y + plot.height / 2
	lift := math.max(config.hover_lift, 0.0)
	reach := outer + lift + 2
	ring := rect(cx - reach, cy - reach, 2 * reach, 2 * reach)
	arcs := pie_chart_sweep(all_arcs, config.start_angle, progress)
	glide := if config.reduce_motion { 0.0 } else { special_chart_glide_seconds }
	mut children := []Element{}
	children << driver
	// Slices, each in its own frame inside the ring box so the hovered one
	// can glide out along its middle.
	mut slices := []Element{}
	if outer > 0 {
		for i, a in arcs {
			slice_id := component_part_id(config.id, 'slice:${a.key}')
			mut dx, mut dy := 0.0, 0.0
			if i == hovered_arc && lift > 0 {
				p := pie_chart_point(0, 0, lift, (a.start + a.end) / 2)
				dx, dy = p.x, p.y
			}
			special_chart_glide(slice_id, dx, dy, glide)
			path := pie_chart_slice_path(reach, reach, inner, outer, a.start, a.end, config.pad_angle)
			slices << shape(slice_id, rect(dx, dy, ring.width, ring.height), path, ShapeStyle{
				fill:         pie_chart_slice_color(config, colors, a.index)
				fill_opacity: if hovered_arc >= 0 && i != hovered_arc { 0.55 } else { 1.0 }
			})
		}
	}
	children << view(component_part_id(config.id, 'ring'), ring, BoxStyle{ transparent: true },
		slices)
	labels_visible := progress >= 0.7 && outer > 0
	if labels_visible && config.labels == .outside {
		placements := pie_chart_label_layout(all_arcs, cx, cy, outer + 3, outer + config.label_gap,
			label_widths, line, plot.y, plot.y + plot.height)
		mut leaders := []PathCommand{}
		for p in placements {
			edge := if p.arc == hovered_arc {
				pie_chart_point(cx, cy, outer + lift + 1, (all_arcs[p.arc].start + all_arcs[p.arc].end) / 2)
			} else {
				p.edge
			}
			leaders << path_polyline([edge, p.elbow, p.end], false)
		}
		if leaders.len > 0 {
			children << shape(component_part_id(config.id, 'leaders'), local, leaders,
				ShapeStyle{
					stroke:       config.leader_color or { colors.axis }
					stroke_width: 1
					line_join:    .round
					line_cap:     .round
				})
		}
		for p in placements {
			children << special_chart_text(label_texts[p.arc], p.text, if hovered_arc >= 0
				&& p.arc != hovered_arc {
				colors.muted_text
			} else {
				config.label_color or { colors.text }
			}, font, false, if p.right { Align.left } else { Align.right })
		}
	}
	if labels_visible && config.labels == .inside {
		mid_radius := if inner > 0 { (inner + outer) / 2 } else { outer * 0.62 }
		thickness := outer - inner
		for i, a in all_arcs {
			span := a.end - a.start
			chord := if span >= math.pi {
				2 * mid_radius
			} else {
				2 * mid_radius * math.sin(span / 2)
			}
			if label_widths[i] + 6 > chord || line + 2 > thickness {
				continue
			}
			mut c := pie_chart_point(cx, cy, mid_radius, (a.start + a.end) / 2)
			if i == hovered_arc {
				p := pie_chart_point(0, 0, lift, (a.start + a.end) / 2)
				c = path_point(c.x + p.x, c.y + p.y)
			}
			children << special_chart_text(label_texts[i], rect(c.x - label_widths[i] / 2, c.y - line / 2,
				label_widths[i], line), special_chart_ink_on(pie_chart_slice_color(config,
				colors, a.index)), font, true, .center)
		}
	}
	big := font * 1.75
	big_line := special_chart_line(big)
	// A doughnut can read the hovered slice out in its hole instead of in a
	// floating tooltip.
	readout := hovered_arc >= 0 && config.hover_center && inner > 0
		&& big_line + line < inner * 1.5
	mut center_big := config.center_text
	mut center_small := config.center_caption
	if readout {
		a := all_arcs[hovered_arc]
		s := config.slices[a.index]
		center_big = if s.value_text.len > 0 {
			s.value_text
		} else {
			special_chart_auto_format(s.value)
		}
		center_small = '${if s.label.len > 0 { s.label } else { config.name }} · ${special_chart_format(a.share * 100, 1)}%'
	}
	if inner > 0 && center_big.len > 0 {
		has_caption := center_small.len > 0
		block := big_line + if has_caption { line } else { 0.0 }
		room := inner * 1.6
		if block < inner * 1.5 {
			children << special_chart_text(center_big, rect(cx - room / 2, cy - block / 2, room,
				big_line), colors.text, big, true, .center)
			if has_caption {
				children << special_chart_text(center_small, rect(cx - room / 2, cy - block / 2 +
					big_line, room, line), colors.muted_text, font, false, .center)
			}
		}
	}
	children << special_chart_legend(legend_area, legend_frames, legend_items, colors, font)
	tooltip_id := component_part_id(config.id, 'tooltip')
	if hovered_arc >= 0 && outer > 0 && !readout {
		a := all_arcs[hovered_arc]
		s := config.slices[a.index]
		rows := [
			SpecialChartTooltipRow{
				color: pie_chart_slice_color(config, colors, a.index)
				name:  if s.label.len > 0 { s.label } else { config.name }
				value: pie_chart_value_text(s, a.share)
			},
		]
		w, h := special_chart_tooltip_size('', rows, font)
		mid := (a.start + a.end) / 2
		tip := pie_chart_point(cx, cy, outer + lift, mid)
		anchor := rect(tip.x, tip.y, 0, 0)
		// Beside the slice's outer edge, on its side of the ring, and off the
		// legend.
		frame := special_chart_tooltip_place(anchor, w, h, plot, 10, tip.x < cx)
		children << special_chart_tooltip(tooltip_id, frame, '', rows, colors, font)
	}
	if config.interactive && whole && outer > 0 {
		actions := all_arcs.map(special_chart_hover_action(config.id, 'slice:${it.key}'))
		hit_arcs := all_arcs.clone()
		for hit in special_chart_hit_strips(rect(cx - outer, cy - outer, 2 * outer, 2 * outer),
			6, 3, fn [hit_arcs, cx, cy, inner, outer] (x f64, y f64) int {
				return pie_chart_arc_at(hit_arcs, x - cx, y - cy, inner, outer)
			}) {
			children << special_chart_hit_view(hit.frame, actions[hit.index])
		}
	}
	mut summary := []string{}
	for a in all_arcs {
		summary << '${config.slices[a.index].label} ${special_chart_percent(a.share)}'
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'img'
		accessibility_label: if config.title.len > 0 { config.title } else { 'Pie chart' }
		accessibility_value: summary.join(', ')
	})
}

// pie_chart_hover_from_event returns the next `hovered` key when the pointer
// enters or leaves a slice (or its legend item), and none for any other event
// and for a slice the chart does not show.
pub fn pie_chart_hover_from_event(config PieChartConfig, event string) ?string {
	entered, target := special_chart_hover_event(config.id, event) or { return none }
	if !target.starts_with('slice:') {
		return none
	}
	key := target['slice:'.len..]
	mut known := false
	for a in pie_chart_arcs(config.slices, config.start_angle) {
		if a.key == key {
			known = true
			break
		}
	}
	if !known {
		return none
	}
	if entered {
		return if key == config.hovered { none } else { key }
	}
	return if key == config.hovered { '' } else { none }
}
