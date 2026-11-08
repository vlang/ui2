module ui2

import math

// SankeyLinkColor says how a ribbon is colored.
pub enum SankeyLinkColor {
	gradient // From the source node's color to the target's, left to right.
	source   // The source node's color.
	target   // The target node's color.
}

// SankeyChartHover is what the pointer is over: a node (its links stand out)
// or a single link.
pub struct SankeyChartHover {
pub:
	node string // Key of the hovered node, or ''.
	link int = -1 // Position of the hovered link in SankeyChartConfig.links, or -1.
}

pub struct SankeyChartConfig {
pub:
	id    string // Required: hover targets and the appear use parts of it.
	frame Rect
	nodes []SankeyNode
	links []SankeyLink
	// node_width, node_padding, align, iterations and value_scale shape the
	// layout as in SankeyLayoutOptions.
	node_width     f64              = 10
	node_padding   f64              = 16
	align          SankeyAlign      = .justify
	iterations     int              = 6
	value_scale    SankeyValueScale = .linear
	node_radius    f64              = 2
	link_color     SankeyLinkColor  = .gradient
	link_opacity   f64              = 0.35
	min_link_width f64              = 1    // Keeps hairline flows visible.
	label_gap      f64              = 6    // Between a node and its label.
	show_values    bool             = true // A line with each node's throughput under its name.
	unit           string // Written after values, such as "TWh".
	// hover is what the pointer is over; keep it with sankey_chart_hover_from_event.
	hover           SankeyChartHover
	link_hover      bool = true // Links answer the pointer as well as nodes.
	interactive     bool = true
	appear          bool = true // Reveal the diagram from the left the first time.
	appear_key      string
	appear_duration f64 = 1.0
	reduce_motion   bool
	title           string // Accessibility label; "Sankey chart" by default.
	size            ComponentSize = .medium
	theme           ComponentTheme
}

fn sankey_value_text(value f64, unit string) string {
	number := special_chart_auto_format(value)
	return if unit.len > 0 { '${number} ${unit}' } else { number }
}

// sankey_node_value_text is how a node's throughput reads in its label.
pub fn sankey_node_value_text(config SankeyChartConfig, node SankeyLayoutNode) string {
	given := config.nodes[node.index].value_text
	return if given.len > 0 { given } else { sankey_value_text(node.throughput(), config.unit) }
}

fn sankey_node_color(config SankeyChartConfig, colors SpecialChartColors, index int) u32 {
	return config.nodes[index].color or { special_chart_series_color(colors, index) }
}

// SankeyChartLabel is one node's label block: the name over its value, beside
// the node.
struct SankeyChartLabel {
	node   int
	frame  Rect
	right  bool // Left-aligned to the right of the node.
	name   string
	amount string
}

// sankey_chart_value_texts is how each node's throughput reads, from the
// links alone: the label beside it and the margins depend on it before the
// nodes are placed.
fn sankey_chart_value_texts(config SankeyChartConfig) []string {
	mut inflow := []f64{len: config.nodes.len}
	mut outflow := []f64{len: config.nodes.len}
	keys := sankey_node_keys(config.nodes) or { return []string{len: config.nodes.len} }
	for l in config.links {
		s := keys.index(l.source)
		t := keys.index(l.target)
		if s >= 0 && t >= 0 && component_finite(l.value) && l.value > 0 {
			outflow[s] += l.value
			inflow[t] += l.value
		}
	}
	mut out := []string{cap: config.nodes.len}
	for i, n in config.nodes {
		out << if n.value_text.len > 0 {
			n.value_text
		} else {
			sankey_value_text(math.max(inflow[i], outflow[i]), config.unit)
		}
	}
	return out
}

// sankey_chart_margins is how much room the labels of the first and last
// columns take beside the flow, each at most 30% of the width.
fn sankey_chart_margins(config SankeyChartConfig, columns [][]int, width f64, font f64) (f64, f64) {
	if columns.len == 0 {
		return 0, 0
	}
	amounts := sankey_chart_value_texts(config)
	mut sides := [0.0, 0.0]
	limit := width * 0.3
	edge_columns := if columns.len > 1 { [0, columns.len - 1] } else { [0] }
	for side, c in edge_columns {
		for i in columns[c] {
			mut w := special_chart_text_width(config.nodes[i].label, font, false)
			if config.show_values {
				w = math.max(w, special_chart_text_width(amounts[i], font - 1, false))
			}
			sides[side] = math.max(sides[side], math.ceil(w) + config.label_gap)
		}
	}
	if columns.len == 1 {
		return 0, math.min(sides[0], limit)
	}
	return math.min(sides[0], limit), math.min(sides[1], limit)
}

fn sankey_chart_validate(config SankeyChartConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	sankey_graph(config.nodes, config.links)!
	if !component_finite(config.link_opacity) || config.link_opacity < 0 || config.link_opacity > 1 {
		return error('sankey link_opacity must be in [0, 1]')
	}
	special_chart_validate_length('sankey node_radius', config.node_radius)!
	special_chart_validate_length('sankey min_link_width', config.min_link_width)!
	special_chart_validate_length('sankey label_gap', config.label_gap)!
	special_chart_validate_length('sankey appear_duration', config.appear_duration)!
}

// sankey_chart_layout lays the diagram out in a frame `width` by `height`,
// leaving room beside the outer columns for their labels.
pub fn sankey_chart_layout(config SankeyChartConfig, width f64, height f64) !SankeyLayout {
	font := special_chart_font(config.size)
	line := special_chart_line(font)
	columns := sankey_columns(config.nodes, config.links, config.align)!
	left, right := sankey_chart_margins(config, columns, width, font)
	pad := if config.show_values { line } else { line / 2 }
	extent := rect(left, pad, math.max(0.0, width - left - right), math.max(0.0, height - 2 * pad))
	return sankey_layout(config.nodes, config.links, SankeyLayoutOptions{
		extent:       extent
		node_width:   config.node_width
		node_padding: config.node_padding
		align:        config.align
		iterations:   config.iterations
		value_scale:  config.value_scale
	})!
}

// sankey_chart_labels places each node's label block beside it: left of the
// first column, right of the others (left of nodes past the middle), centered
// on the node and moved apart from its column's other labels when crowded.
fn sankey_chart_labels(config SankeyChartConfig, layout SankeyLayout, width f64, height f64, font f64) []SankeyChartLabel {
	line := special_chart_line(font)
	block := if config.show_values { 2 * line } else { line }
	mut groups := map[string][]int{}
	mut placed := []SankeyChartLabel{}
	for node in layout.nodes {
		name := config.nodes[node.index].label
		amount := if config.show_values { sankey_node_value_text(config, node) } else { '' }
		// The hovered node's name is bold; leave room for either weight.
		w := math.ceil(math.max(math.max(special_chart_text_width(name, font, false), special_chart_text_width(name,
			font, true)), special_chart_text_width(amount, font - 1, false)))
		right := if node.layer == 0 && layout.layers > 1 {
			false
		} else if node.layer == layout.layers - 1 {
			true
		} else {
			(node.x0 + node.x1) / 2 < width / 2
		}
		x := if right {
			node.x1 + config.label_gap
		} else {
			node.x0 - config.label_gap - w
		}
		room := if right { width - x } else { x + w }
		clipped := math.max(0.0, math.min(w, room))
		fx := if right { x } else { x + w - clipped }
		placed << SankeyChartLabel{
			node:   node.index
			frame:  rect(fx, (node.y0 + node.y1) / 2 - block / 2, clipped, block)
			right:  right
			name:   name
			amount: amount
		}
		key := '${node.layer}:${right}'
		groups[key] << placed.len - 1
	}
	for _, members in groups {
		centers := sankey_spread_centers(placed, members, block, height)
		for k, p in members {
			f := placed[p].frame
			placed[p] = SankeyChartLabel{
				...placed[p]
				frame: rect(f.x, centers[k] - block / 2, f.width, f.height)
			}
		}
	}
	return placed
}

fn sankey_spread_centers(placed []SankeyChartLabel, members []int, block f64, height f64) []f64 {
	wanted := members.map(placed[it].frame.y + block / 2)
	return special_chart_spread(wanted, block, block / 2, height - block / 2)
}

// sankey_link_attached reports whether link `l` of the layout starts or ends
// at the node at layout position `node`.
fn sankey_link_attached(link SankeyLayoutLink, node int) bool {
	return link.source == node || link.target == node
}

// sankey_chart builds GPUI Kit's SankeyChart: nodes as bars in columns, links
// as ribbons between them, labels beside the nodes, and hover on nodes and
// links. It is controlled: keep `hover` with sankey_chart_hover_from_event.
pub fn sankey_chart(config SankeyChartConfig) !Element {
	sankey_chart_validate(config)!
	colors := special_chart_colors(config.theme)
	font := special_chart_font(config.size)
	line := special_chart_line(font)
	local := component_local(config.frame)
	progress, driver := special_chart_appear(config.id, config.appear_key, config.appear,
		config.reduce_motion, config.appear_duration)
	whole := progress >= 1
	active := config.interactive && whole
	mut children := []Element{}
	children << driver
	if config.nodes.len == 0 || local.width <= 0 || local.height <= 0 {
		return component_finish(Element{
			...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
			accessibility_role:  'img'
			accessibility_label: if config.title.len > 0 { config.title } else { 'Sankey chart' }
		})
	}
	layout := sankey_chart_layout(config, local.width, local.height)!
	mut hovered_node := -1
	if active && config.hover.node.len > 0 {
		for i, node in layout.nodes {
			if node.key == config.hover.node {
				hovered_node = i
			}
		}
	}
	mut hovered_link := -1
	if active && config.hover.link >= 0 {
		for i, l in layout.links {
			if l.index == config.hover.link {
				hovered_link = i
			}
		}
	}
	emphasis := hovered_node >= 0 || hovered_link >= 0
	reveal := local.width * progress
	// Ribbons first, beneath the nodes. A gradient ribbon is drawn in vertical
	// bands at whole points, each clipped to its band and filled with the mix
	// of the two node colors there.
	for li, l in layout.links {
		source := layout.nodes[l.source]
		target := layout.nodes[l.target]
		x0, x1 := source.x1, target.x0
		if x1 <= x0 || x0 >= reveal {
			continue
		}
		w0 := math.max(l.source_width, config.min_link_width)
		w1 := math.max(l.target_width, config.min_link_width)
		top := math.min(l.y0 - w0 / 2, l.y1 - w1 / 2)
		bottom := math.max(l.y0 + w0 / 2, l.y1 + w1 / 2)
		emphasized := (hovered_node >= 0 && sankey_link_attached(l, hovered_node))
			|| li == hovered_link
		opacity := if !emphasis {
			config.link_opacity
		} else if emphasized {
			math.min(1.0, config.link_opacity + 0.3)
		} else {
			config.link_opacity * 0.3
		}
		source_color := sankey_node_color(config, colors, source.index)
		target_color := sankey_node_color(config, colors, target.index)
		bands := if config.link_color == .gradient {
			int(math.clamp(math.round((x1 - x0) / 9), 2, 16))
		} else {
			1
		}
		fy := math.floor(top) - 1
		fh := math.ceil(bottom) + 1 - fy
		for b in 0 .. bands {
			// Band edges fall on whole points, so neighbors meet on a pixel edge.
			bx0 := if b == 0 { x0 } else { math.round(x0 + (x1 - x0) * f64(b) / f64(bands)) }
			bx1 := if b == bands - 1 {
				x1
			} else {
				math.round(x0 + (x1 - x0) * f64(b + 1) / f64(bands))
			}
			visible := math.min(bx1, reveal)
			if visible <= bx0 {
				continue
			}
			color := match config.link_color {
				.gradient {
					special_chart_mix(source_color, target_color, (f64(b) + 0.5) / f64(bands))
				}
				.source { source_color }
				.target { target_color }
			}
			fx := math.floor(bx0)
			piece := sankey_ribbon_piece(x0 - fx, l.y0 - fy, w0, x1 - fx, l.y1 - fy, w1,
				bx0 - fx, visible - fx)
			children << shape(component_part_id(config.id, 'link:${l.index}:${b}'), rect(fx,
				fy, math.ceil(visible) - fx, fh), piece, ShapeStyle{
				fill:         color
				fill_opacity: opacity
			})
		}
	}
	for i, node in layout.nodes {
		if node.x0 >= reveal {
			continue
		}
		dim := emphasis && i != hovered_node && !(hovered_link >= 0
			&& (layout.links[hovered_link].source == i || layout.links[hovered_link].target == i))
			&& !(hovered_node >= 0 && sankey_nodes_linked(layout, hovered_node, i))
		h := math.max(1.0, node.y1 - node.y0)
		children << view(component_part_id(config.id, 'node:${node.key}'), rect(node.x0, node.y0,
			math.min(node.x1, reveal) - node.x0, h), BoxStyle{
			bg:      sankey_node_color(config, colors, node.index)
			radius:  math.min(config.node_radius, math.min(config.node_width, h) / 2)
			opacity: if dim { 0.45 } else { 1.0 }
		}, []Element{})
	}
	for lab in sankey_chart_labels(config, layout, local.width, local.height, font) {
		node := layout.nodes[lab.node]
		if node.x0 >= reveal || lab.frame.width <= 0 {
			continue
		}
		align := if lab.right { Align.left } else { Align.right }
		dim := emphasis && lab.node != hovered_node && !(hovered_link >= 0
			&& (layout.links[hovered_link].source == lab.node
				|| layout.links[hovered_link].target == lab.node))
			&& !(hovered_node >= 0 && sankey_nodes_linked(layout, hovered_node, lab.node))
		if node.layer > 0 && node.layer < layout.layers - 1 {
			// A label among the ribbons sits on a veil of the surface.
			children << view('', rect(lab.frame.x - 3, lab.frame.y, lab.frame.width + 6,
				lab.frame.height), BoxStyle{
				bg:      colors.surface
				opacity: 0.75
				radius:  3
			}, []Element{})
		}
		children << special_chart_text(lab.name, rect(lab.frame.x, lab.frame.y, lab.frame.width,
			line), if dim { colors.muted_text } else { colors.text }, font, lab.node == hovered_node,
			align)
		if lab.amount.len > 0 {
			children << special_chart_text(lab.amount, rect(lab.frame.x, lab.frame.y + line,
				lab.frame.width, line), colors.muted_text, font - 1, false, align)
		}
	}
	tooltip_id := component_part_id(config.id, 'tooltip')
	if hovered_node >= 0 {
		node := layout.nodes[hovered_node]
		mut rows := []SpecialChartTooltipRow{}
		if node.inflow > 0 {
			rows << SpecialChartTooltipRow{
				name:  'Inflow'
				value: sankey_value_text(node.inflow, config.unit)
			}
		}
		if node.outflow > 0 {
			rows << SpecialChartTooltipRow{
				name:  'Outflow'
				value: sankey_value_text(node.outflow, config.unit)
			}
		}
		if node.inflow > 0 && node.outflow > 0 && math.abs(node.inflow - node.outflow) > 1e-9 {
			rows << SpecialChartTooltipRow{
				name:  'Difference'
				value: sankey_value_text(node.outflow - node.inflow, config.unit)
			}
		}
		title := config.nodes[node.index].label
		w, h := special_chart_tooltip_size(title, rows, font)
		anchor := rect(node.x0 - 2, node.y0, node.x1 - node.x0 + 4, node.y1 - node.y0)
		frame := special_chart_tooltip_place(anchor, w, h, local, 8, node.layer > 0
			&& node.layer == layout.layers - 1)
		children << special_chart_tooltip(tooltip_id, frame, title, rows, colors, font)
	} else if hovered_link >= 0 {
		l := layout.links[hovered_link]
		source := layout.nodes[l.source]
		target := layout.nodes[l.target]
		given := config.links[l.index].value_text
		mut rows := [
			SpecialChartTooltipRow{
				color: sankey_node_color(config, colors, source.index)
				name:  'Flow'
				value: if given.len > 0 { given } else { sankey_value_text(l.value, config.unit) }
			},
		]
		if source.outflow > 0 {
			rows << SpecialChartTooltipRow{
				name:  'Share of ${config.nodes[source.index].label}'
				value: special_chart_format(l.value / source.outflow * 100, 1) + '%'
			}
		}
		title := '${config.nodes[source.index].label} → ${config.nodes[target.index].label}'
		w, h := special_chart_tooltip_size(title, rows, font)
		mx := (source.x1 + target.x0) / 2
		top, bottom := sankey_ribbon_span(source.x1, l.y0, l.source_width, target.x0, l.y1,
			l.target_width, mx)
		anchor := rect(mx, top, 0, bottom - top)
		frame := special_chart_tooltip_place(anchor, w, h, local, 12, false)
		children << special_chart_tooltip(tooltip_id, frame, title, rows, colors, font)
	}
	if active {
		if config.link_hover {
			for l in layout.links {
				source := layout.nodes[l.source]
				target := layout.nodes[l.target]
				action := special_chart_hover_action(config.id, 'link:${l.index}')
				for hit in sankey_link_hit_rects(source.x1, l.y0, math.max(l.source_width,
					config.min_link_width), target.x0, l.y1, math.max(l.target_width, config.min_link_width),
					10) {
					children << special_chart_hit_view(hit, action)
				}
			}
		}
		for node in layout.nodes {
			h := math.max(node.y1 - node.y0, 8.0)
			cy := (node.y0 + node.y1) / 2
			children << special_chart_hit_view(rect(node.x0 - 3, cy - h / 2 - 2, node.x1 - node.x0 +
				6, h + 4), special_chart_hover_action(config.id, 'node:${node.key}'))
		}
	}
	mut summary := []string{}
	for l in layout.links {
		summary << '${config.nodes[layout.nodes[l.source].index].label} to ${config.nodes[layout.nodes[l.target].index].label} ${sankey_value_text(l.value, config.unit)}'
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'img'
		accessibility_label: if config.title.len > 0 { config.title } else { 'Sankey chart' }
		accessibility_value: summary.join('; ')
	})
}

// sankey_nodes_linked reports whether a link joins the nodes at layout
// positions a and b.
fn sankey_nodes_linked(layout SankeyLayout, a int, b int) bool {
	for l in layout.nodes[a].source_links {
		if layout.links[l].target == b {
			return true
		}
	}
	for l in layout.nodes[a].target_links {
		if layout.links[l].source == b {
			return true
		}
	}
	return false
}

// sankey_link_hit_rects covers a ribbon with vertical strips about `strip`
// wide, each spanning the ribbon over its width, so a link answers the
// pointer along its curve.
pub fn sankey_link_hit_rects(x0 f64, y0 f64, w0 f64, x1 f64, y1 f64, w1 f64, strip f64) []Rect {
	mut out := []Rect{}
	if x1 <= x0 || strip <= 0 {
		return out
	}
	count := int(math.max(1.0, math.round((x1 - x0) / strip)))
	for k in 0 .. count {
		a := x0 + (x1 - x0) * f64(k) / f64(count)
		b := x0 + (x1 - x0) * f64(k + 1) / f64(count)
		ta, ba := sankey_ribbon_span(x0, y0, w0, x1, y1, w1, a)
		tb, bb := sankey_ribbon_span(x0, y0, w0, x1, y1, w1, b)
		top := math.min(ta, tb)
		bottom := math.max(math.max(ba, bb), top + 4)
		out << rect(a, top, b - a, bottom - top)
	}
	return out
}

// sankey_chart_hover_from_event returns the next `hover` when the pointer
// enters or leaves a node or a link, and none for any other event.
pub fn sankey_chart_hover_from_event(config SankeyChartConfig, event string) ?SankeyChartHover {
	entered, target := special_chart_hover_event(config.id, event) or { return none }
	if target.starts_with('node:') {
		key := target['node:'.len..]
		keys := sankey_node_keys(config.nodes) or { return none }
		if key !in keys {
			return none
		}
		if entered {
			return if key == config.hover.node && config.hover.link < 0 {
				none
			} else {
				SankeyChartHover{
					node: key
				}
			}
		}
		return if key == config.hover.node { SankeyChartHover{} } else { none }
	}
	if target.starts_with('link:') {
		if config.links.len == 0 {
			return none
		}
		index := component_parse_index(target['link:'.len..], config.links.len - 1) or {
			return none
		}
		if config.links[index].value <= 0 {
			return none
		}
		if entered {
			return if index == config.hover.link {
				none
			} else {
				SankeyChartHover{
					link: index
				}
			}
		}
		return if index == config.hover.link { SankeyChartHover{} } else { none }
	}
	return none
}
