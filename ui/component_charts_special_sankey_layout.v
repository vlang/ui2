// The sankey layout follows the algorithm of d3-sankey
// (https://github.com/d3/d3-sankey, Copyright 2015 Mike Bostock, BSD-3-Clause),
// which GPUI Kit's SankeyChart also mirrors: longest-path columns, node heights
// from flows, alternating relaxation passes with middle-out collision
// resolution, and links ordered by the position of their other end. This is a
// new V implementation; the per-end ribbon widths of the square-root value
// scale are ui2's.
module ui2

import math

// SankeyNode is a node of a sankey diagram: a stage flow passes through.
pub struct SankeyNode {
pub:
	key   string // What links name the node by; defaults to the label.
	label string
	color ?u32 // Defaults to the theme palette, by the node's position.
	// value_text is how the label and tooltip write the node's throughput;
	// defaults to the number and the chart's unit.
	value_text string
}

// SankeyLink is a flow of `value` from node `source` to node `target`, both
// named by key. Links worth zero are left out.
pub struct SankeyLink {
pub:
	source     string
	target     string
	value      f64
	value_text string // How the tooltip writes the flow; defaults to the number and unit.
}

// SankeyAlign places nodes in columns, as d3-sankey's alignments do.
pub enum SankeyAlign {
	justify // By depth, with nodes that lead nowhere in the last column.
	left    // By depth: the longest path from any source.
	right   // By height: the longest path to any sink, counted from the right.
	center  // By depth, with sources pulled next to their first target.
}

// SankeyValueScale maps flow values to heights.
pub enum SankeyValueScale {
	linear // Heights in proportion to the values.
	sqrt   // In proportion to their square roots, so small flows stay visible.
}

pub struct SankeyLayoutOptions {
pub:
	extent       Rect // Where the nodes go; labels are outside it.
	node_width   f64              = 10
	node_padding f64              = 16 // The vertical gap between nodes in a column.
	align        SankeyAlign      = .justify
	iterations   int              = 6 // Relaxation passes.
	value_scale  SankeyValueScale = .linear
}

// SankeyLayoutNode is where a node goes. Its link lists are positions in
// SankeyLayout.links, ordered top to bottom along its side.
pub struct SankeyLayoutNode {
pub:
	index        int // Position in the nodes given.
	key          string
	x0           f64
	x1           f64
	y0           f64
	y1           f64
	value        f64 // In the layout's value space (square roots under .sqrt).
	inflow       f64 // Raw total of the incoming flows.
	outflow      f64 // Raw total of the outgoing flows.
	depth        int // Longest path from a source.
	height       int // Longest path to a sink.
	layer        int // Column.
	source_links []int
	target_links []int
}

// throughput is the larger of a node's inflow and outflow, in raw units.
pub fn (node SankeyLayoutNode) throughput() f64 {
	return math.max(node.inflow, node.outflow)
}

// SankeyLayoutLink is where a link's ribbon runs: from the right side of its
// source at height y0 (the middle of its end there) to the left side of its
// target at y1. Each end has its own width; under the linear scale the two are
// equal and in proportion to the value.
pub struct SankeyLayoutLink {
pub:
	index        int // Position in the links given.
	source       int // Position of the source in SankeyLayout.nodes.
	target       int
	value        f64 // Raw.
	width        f64 // Nominal width from the value.
	source_width f64
	target_width f64
	y0           f64
	y1           f64
}

pub struct SankeyLayout {
pub:
	nodes  []SankeyLayoutNode
	links  []SankeyLayoutLink
	layers int
}

// SankeyGraph is the graph by index, after resolving keys.
struct SankeyGraph {
	keys   []string
	source []int
	target []int
	raw    []f64
	link   []int // Position of each kept link in the links given.
}

fn sankey_node_keys(nodes []SankeyNode) ![]string {
	return special_chart_keys(nodes.map(it.key), nodes.map(it.label), 'sankey node')
}

fn sankey_graph(nodes []SankeyNode, links []SankeyLink) !SankeyGraph {
	keys := sankey_node_keys(nodes)!
	mut position := map[string]int{}
	for i, k in keys {
		position[k] = i
	}
	mut source := []int{}
	mut target := []int{}
	mut raw := []f64{}
	mut kept := []int{}
	for i, l in links {
		if !component_finite(l.value) || l.value < 0 {
			return error('sankey link values must be finite and non-negative')
		}
		s := position[l.source] or { return error('sankey link source `${l.source}` is not a node') }
		t := position[l.target] or { return error('sankey link target `${l.target}` is not a node') }
		if s == t {
			return error('sankey link from `${l.source}` to itself makes a cycle')
		}
		if l.value == 0 {
			continue
		}
		source << s
		target << t
		raw << l.value
		kept << i
	}
	return SankeyGraph{
		keys:   keys
		source: source
		target: target
		raw:    raw
		link:   kept
	}
}

// sankey_ranks gives each node its depth (longest path from a source) and
// height (longest path to a sink), or an error when the links form a cycle.
fn sankey_ranks(count int, source []int, target []int) !([]int, []int) {
	mut indegree := []int{len: count}
	mut outgoing := [][]int{len: count}
	for l, t in target {
		indegree[t]++
		outgoing[source[l]] << l
	}
	mut order := []int{cap: count}
	for i in 0 .. count {
		if indegree[i] == 0 {
			order << i
		}
	}
	mut depth := []int{len: count}
	mut head := 0
	for head < order.len {
		node := order[head]
		head++
		for l in outgoing[node] {
			t := target[l]
			depth[t] = math.max(depth[t], depth[node] + 1)
			indegree[t]--
			if indegree[t] == 0 {
				order << t
			}
		}
	}
	if order.len < count {
		return error('sankey links form a cycle')
	}
	mut height := []int{len: count}
	for k := order.len - 1; k >= 0; k-- {
		node := order[k]
		for l in outgoing[node] {
			height[node] = math.max(height[node], height[target[l]] + 1)
		}
	}
	return depth, height
}

// sankey_layers assigns every node its column and returns how many there are.
fn sankey_layers(count int, graph SankeyGraph, depth []int, height []int, align SankeyAlign) ([]int, int) {
	mut columns := 0
	for d in depth {
		columns = math.max(columns, d + 1)
	}
	mut has_in := []bool{len: count}
	mut has_out := []bool{len: count}
	mut first_target := []int{len: count, init: -1}
	for l, s in graph.source {
		t := graph.target[l]
		has_out[s] = true
		has_in[t] = true
		if first_target[s] < 0 || depth[t] < first_target[s] {
			first_target[s] = depth[t]
		}
	}
	mut layer := []int{len: count}
	for i in 0 .. count {
		layer[i] = match align {
			.left {
				depth[i]
			}
			.right {
				columns - 1 - height[i]
			}
			.justify {
				if has_out[i] { depth[i] } else { columns - 1 }
			}
			.center {
				if has_in[i] {
					depth[i]
				} else if has_out[i] {
					first_target[i] - 1
				} else {
					0
				}
			}
		}
		if layer[i] < 0 || columns == 0 {
			layer[i] = 0
		} else if layer[i] > columns - 1 {
			layer[i] = columns - 1
		}
	}
	return layer, columns
}

// sankey_columns lists the nodes of a layout by column, top to bottom, from
// layers alone: each node's column.
pub fn sankey_columns(nodes []SankeyNode, links []SankeyLink, align SankeyAlign) ![][]int {
	graph := sankey_graph(nodes, links)!
	depth, height := sankey_ranks(nodes.len, graph.source, graph.target)!
	layer, columns := sankey_layers(nodes.len, graph, depth, height, align)
	mut out := [][]int{len: columns}
	for i, c in layer {
		out[c] << i
	}
	return out
}

// SankeyWork is the layout being computed.
struct SankeyWork {
mut:
	y0       []f64
	y1       []f64
	width    []f64
	outbound [][]int
	inbound  [][]int
	columns  [][]int
	layer    []int
	py       f64
	top      f64
	bottom   f64
}

// sankey_layout places the nodes and links of a sankey diagram in
// options.extent. It fails when a link names a node that does not exist, two
// nodes share a key, a value is negative or not finite, or the links form a
// cycle.
pub fn sankey_layout(nodes []SankeyNode, links []SankeyLink, options SankeyLayoutOptions) !SankeyLayout {
	if options.iterations < 0 || options.iterations > 100 {
		return error('sankey iterations must be from 0 through 100')
	}
	special_chart_validate_length('sankey node_width', options.node_width)!
	special_chart_validate_length('sankey node_padding', options.node_padding)!
	component_validate_frame(options.extent)!
	graph := sankey_graph(nodes, links)!
	count := nodes.len
	depth, height := sankey_ranks(count, graph.source, graph.target)!
	layer, columns := sankey_layers(count, graph, depth, height, options.align)
	value := graph.raw.map(if options.value_scale == .sqrt { math.sqrt(it) } else { it })
	mut inflow := []f64{len: count}
	mut outflow := []f64{len: count}
	mut in_scaled := []f64{len: count}
	mut out_scaled := []f64{len: count}
	mut w := SankeyWork{
		y0:       []f64{len: count}
		y1:       []f64{len: count}
		width:    []f64{len: value.len}
		outbound: [][]int{len: count}
		inbound:  [][]int{len: count}
		columns:  [][]int{len: columns}
		layer:    layer
		top:      options.extent.y
		bottom:   options.extent.y + options.extent.height
	}
	for l, s in graph.source {
		t := graph.target[l]
		w.outbound[s] << l
		w.inbound[t] << l
		outflow[s] += graph.raw[l]
		inflow[t] += graph.raw[l]
		out_scaled[s] += value[l]
		in_scaled[t] += value[l]
	}
	node_value := []f64{len: count, init: math.max(in_scaled[index], out_scaled[index])}
	for i in 0 .. count {
		w.columns[layer[i]] << i
	}
	extent := options.extent
	mut tallest := 1
	for column in w.columns {
		tallest = math.max(tallest, column.len)
	}
	w.py = if tallest > 1 {
		math.min(options.node_padding, extent.height / f64(tallest - 1))
	} else {
		options.node_padding
	}
	// Heights: one scale for every column, the one that fits the fullest.
	mut ky := math.max_f64
	for column in w.columns {
		mut total := 0.0
		for i in column {
			total += node_value[i]
		}
		if total > 0 {
			ky = math.min(ky, (extent.height - f64(column.len - 1) * w.py) / total)
		}
	}
	if ky == math.max_f64 || ky < 0 {
		ky = 0
	}
	for column in w.columns {
		mut y := extent.y
		for i in column {
			w.y0[i] = y
			w.y1[i] = y + node_value[i] * ky
			y = w.y1[i] + w.py
		}
		spare := (extent.y + extent.height - y + w.py) / f64(column.len + 1)
		for k, i in column {
			w.y0[i] += spare * f64(k + 1)
			w.y1[i] += spare * f64(k + 1)
		}
	}
	for l in 0 .. value.len {
		w.width[l] = value[l] * ky
	}
	sankey_reorder_all(mut w, graph)
	for k in 0 .. options.iterations {
		alpha := math.pow(0.99, f64(k))
		beta := math.max(1 - alpha, f64(k + 1) / f64(options.iterations))
		sankey_relax_right_to_left(mut w, graph, value, alpha, beta)
		sankey_relax_left_to_right(mut w, graph, value, alpha, beta)
	}
	sankey_reorder_all(mut w, graph)
	// Each end of a ribbon: the nominal width under the linear scale; under
	// the square-root scale the links of a side share the node's height in
	// proportion to their values, so every side is filled.
	mut source_width := w.width.clone()
	mut target_width := w.width.clone()
	if options.value_scale == .sqrt {
		for l, s in graph.source {
			t := graph.target[l]
			if out_scaled[s] > 0 {
				source_width[l] = (w.y1[s] - w.y0[s]) * value[l] / out_scaled[s]
			}
			if in_scaled[t] > 0 {
				target_width[l] = (w.y1[t] - w.y0[t]) * value[l] / in_scaled[t]
			}
		}
	}
	mut link_y0 := []f64{len: value.len}
	mut link_y1 := []f64{len: value.len}
	for i in 0 .. count {
		mut y := w.y0[i]
		for l in w.outbound[i] {
			link_y0[l] = y + source_width[l] / 2
			y += source_width[l]
		}
		y = w.y0[i]
		for l in w.inbound[i] {
			link_y1[l] = y + target_width[l] / 2
			y += target_width[l]
		}
	}
	kx := if columns > 1 { (extent.width - options.node_width) / f64(columns - 1) } else { 0.0 }
	mut out_nodes := []SankeyLayoutNode{cap: count}
	for i in 0 .. count {
		x0 := extent.x + f64(layer[i]) * kx
		out_nodes << SankeyLayoutNode{
			index:        i
			key:          graph.keys[i]
			x0:           x0
			x1:           x0 + options.node_width
			y0:           w.y0[i]
			y1:           w.y1[i]
			value:        node_value[i]
			inflow:       inflow[i]
			outflow:      outflow[i]
			depth:        depth[i]
			height:       height[i]
			layer:        layer[i]
			source_links: w.outbound[i].clone()
			target_links: w.inbound[i].clone()
		}
	}
	mut out_links := []SankeyLayoutLink{cap: value.len}
	for l in 0 .. value.len {
		out_links << SankeyLayoutLink{
			index:        graph.link[l]
			source:       graph.source[l]
			target:       graph.target[l]
			value:        graph.raw[l]
			width:        w.width[l]
			source_width: source_width[l]
			target_width: target_width[l]
			y0:           link_y0[l]
			y1:           link_y1[l]
		}
	}
	return SankeyLayout{
		nodes:  out_nodes
		links:  out_links
		layers: columns
	}
}

// sankey_sort_by_y orders link or node positions by a y, ties by position.
fn sankey_sort_by_y(mut items []int, ys []f64) {
	items.sort_with_compare(fn [ys] (a &int, b &int) int {
		if ys[*a] < ys[*b] {
			return -1
		}
		if ys[*a] > ys[*b] {
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
}

// sankey_sort_links orders a list of links by the y of the node at their
// other end: the targets for a node's outgoing links, the sources for its
// incoming ones.
fn sankey_sort_links(mut items []int, ends []int, y0 []f64) {
	ys := []f64{len: ends.len, init: y0[ends[index]]}
	sankey_sort_by_y(mut items, ys)
}

fn sankey_reorder_all(mut w SankeyWork, graph SankeyGraph) {
	for i in 0 .. w.outbound.len {
		sankey_sort_links(mut w.outbound[i], graph.target, w.y0)
		sankey_sort_links(mut w.inbound[i], graph.source, w.y0)
	}
}

// sankey_reorder_around re-sorts the link lists of a moved node's neighbors.
fn sankey_reorder_around(mut w SankeyWork, graph SankeyGraph, node int) {
	for l in w.inbound[node] {
		s := graph.source[l]
		sankey_sort_links(mut w.outbound[s], graph.target, w.y0)
	}
	for l in w.outbound[node] {
		t := graph.target[l]
		sankey_sort_links(mut w.inbound[t], graph.source, w.y0)
	}
}

// sankey_target_top is the y0 for `target` that lines its end of the link up
// with where the link leaves `source`.
fn sankey_target_top(w SankeyWork, graph SankeyGraph, source int, target int) f64 {
	mut y := w.y0[source] - f64(w.outbound[source].len - 1) * w.py / 2
	for l in w.outbound[source] {
		if graph.target[l] == target {
			break
		}
		y += w.width[l] + w.py
	}
	for l in w.inbound[target] {
		if graph.source[l] == source {
			break
		}
		y -= w.width[l]
	}
	return y
}

// sankey_source_top is the y0 for `source` that lines its end of the link up
// with where the link reaches `target`.
fn sankey_source_top(w SankeyWork, graph SankeyGraph, source int, target int) f64 {
	mut y := w.y0[target] - f64(w.inbound[target].len - 1) * w.py / 2
	for l in w.inbound[target] {
		if graph.source[l] == source {
			break
		}
		y += w.width[l] + w.py
	}
	for l in w.outbound[source] {
		if graph.target[l] == target {
			break
		}
		y -= w.width[l]
	}
	return y
}

fn sankey_relax_left_to_right(mut w SankeyWork, graph SankeyGraph, value []f64, alpha f64, beta f64) {
	for c in 1 .. w.columns.len {
		for node in w.columns[c] {
			mut y := 0.0
			mut weight := 0.0
			for l in w.inbound[node] {
				s := graph.source[l]
				v := value[l] * f64(w.layer[node] - w.layer[s])
				y += sankey_target_top(w, graph, s, node) * v
				weight += v
			}
			if !(weight > 0) {
				continue
			}
			dy := (y / weight - w.y0[node]) * alpha
			w.y0[node] += dy
			w.y1[node] += dy
			sankey_reorder_around(mut w, graph, node)
		}
		sankey_sort_by_y(mut w.columns[c], w.y0)
		sankey_resolve(mut w, c, beta)
	}
}

fn sankey_relax_right_to_left(mut w SankeyWork, graph SankeyGraph, value []f64, alpha f64, beta f64) {
	for c := w.columns.len - 2; c >= 0; c-- {
		for node in w.columns[c] {
			mut y := 0.0
			mut weight := 0.0
			for l in w.outbound[node] {
				t := graph.target[l]
				v := value[l] * f64(w.layer[t] - w.layer[node])
				y += sankey_source_top(w, graph, node, t) * v
				weight += v
			}
			if !(weight > 0) {
				continue
			}
			dy := (y / weight - w.y0[node]) * alpha
			w.y0[node] += dy
			w.y1[node] += dy
			sankey_reorder_around(mut w, graph, node)
		}
		sankey_sort_by_y(mut w.columns[c], w.y0)
		sankey_resolve(mut w, c, beta)
	}
}

// sankey_resolve pushes the nodes of a column apart from its middle node
// outward, then back inside the extent from the bottom and the top.
fn sankey_resolve(mut w SankeyWork, c int, alpha f64) {
	column := w.columns[c]
	if column.len == 0 {
		return
	}
	mid := column.len >> 1
	subject := column[mid]
	sankey_push_up(mut w, column, w.y0[subject] - w.py, mid - 1, alpha)
	sankey_push_down(mut w, column, w.y1[subject] + w.py, mid + 1, alpha)
	sankey_push_up(mut w, column, w.bottom, column.len - 1, alpha)
	sankey_push_down(mut w, column, w.top, 0, alpha)
}

fn sankey_push_down(mut w SankeyWork, column []int, start f64, from int, alpha f64) {
	mut y := start
	for k in from .. column.len {
		node := column[k]
		dy := (y - w.y0[node]) * alpha
		if dy > 1e-6 {
			w.y0[node] += dy
			w.y1[node] += dy
		}
		y = w.y1[node] + w.py
	}
}

fn sankey_push_up(mut w SankeyWork, column []int, start f64, from int, alpha f64) {
	mut y := start
	for k := from; k >= 0; k-- {
		node := column[k]
		dy := (w.y1[node] - y) * alpha
		if dy > 1e-6 {
			w.y0[node] -= dy
			w.y1[node] -= dy
		}
		y = w.y0[node] - w.py
	}
}

// sankey_ribbon_path outlines a link's ribbon from (x0, y0), `w0` tall, to
// (x1, y1), `w1` tall: two horizontal-tangent cubics, so the ribbon leaves and
// reaches its nodes square-on.
pub fn sankey_ribbon_path(x0 f64, y0 f64, w0 f64, x1 f64, y1 f64, w1 f64) []PathCommand {
	xm := (x0 + x1) / 2
	return [
		path_move_to(x0, y0 - w0 / 2),
		path_cubic_to(xm, y0 - w0 / 2, xm, y1 - w1 / 2, x1, y1 - w1 / 2),
		path_line_to(x1, y1 + w1 / 2),
		path_cubic_to(xm, y1 + w1 / 2, xm, y0 + w0 / 2, x0, y0 + w0 / 2),
		path_close(),
	]
}

fn sankey_cubic(a f64, b f64, c f64, d f64, t f64) f64 {
	u := 1 - t
	return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
}

// sankey_t_at is where along a ribbon (0 at x0, 1 at x1) its curves cross `x`.
// Their x rises from x0 to x1, so bisection finds it.
fn sankey_t_at(x0 f64, x1 f64, x f64) f64 {
	if x <= x0 {
		return 0
	}
	if x >= x1 {
		return 1
	}
	xm := (x0 + x1) / 2
	mut lo, mut hi := 0.0, 1.0
	for _ in 0 .. 48 {
		mid := (lo + hi) / 2
		if sankey_cubic(x0, xm, xm, x1, mid) < x {
			lo = mid
		} else {
			hi = mid
		}
	}
	return (lo + hi) / 2
}

// sankey_blossom is the polar form of a cubic: with u, v and w all equal to t
// it is the point at t, and with them taken from two parameters it gives the
// control points of the piece of the curve between them.
fn sankey_blossom(a f64, b f64, c f64, d f64, u f64, v f64, w f64) f64 {
	a1 := a + (b - a) * u
	b1 := b + (c - b) * u
	c1 := c + (d - c) * u
	a2 := a1 + (b1 - a1) * v
	b2 := b1 + (c1 - b1) * v
	return a2 + (b2 - a2) * w
}

// sankey_ribbon_span is the top and bottom of a ribbon (as sankey_ribbon_path
// draws it) where it crosses `x`.
pub fn sankey_ribbon_span(x0 f64, y0 f64, w0 f64, x1 f64, y1 f64, w1 f64, x f64) (f64, f64) {
	t := sankey_t_at(x0, x1, x)
	top := sankey_cubic(y0 - w0 / 2, y0 - w0 / 2, y1 - w1 / 2, y1 - w1 / 2, t)
	bottom := sankey_cubic(y0 + w0 / 2, y0 + w0 / 2, y1 + w1 / 2, y1 + w1 / 2, t)
	return top, bottom
}

// sankey_ribbon_piece outlines the part of a ribbon between xa and xb, cut
// square at both ends: the same curves as sankey_ribbon_path, split exactly,
// so pieces side by side make up the ribbon with nothing between them. A
// gradient ribbon is drawn as such pieces, and a ribbon being revealed as the
// piece left of the edge.
pub fn sankey_ribbon_piece(x0 f64, y0 f64, w0 f64, x1 f64, y1 f64, w1 f64, xa f64, xb f64) []PathCommand {
	a := math.max(xa, x0)
	b := math.min(xb, x1)
	if b <= a || x1 <= x0 {
		return []PathCommand{}
	}
	ta := sankey_t_at(x0, x1, a)
	tb := sankey_t_at(x0, x1, b)
	xm := (x0 + x1) / 2
	t0, t1 := y0 - w0 / 2, y1 - w1 / 2
	b0, b1 := y0 + w0 / 2, y1 + w1 / 2
	cx1 := sankey_blossom(x0, xm, xm, x1, ta, ta, tb)
	cx2 := sankey_blossom(x0, xm, xm, x1, ta, tb, tb)
	return [
		path_move_to(a, sankey_blossom(t0, t0, t1, t1, ta, ta, ta)),
		path_cubic_to(cx1, sankey_blossom(t0, t0, t1, t1, ta, ta, tb), cx2, sankey_blossom(t0,
			t0, t1, t1, ta, tb, tb), b, sankey_blossom(t0, t0, t1, t1, tb, tb, tb)),
		path_line_to(b, sankey_blossom(b0, b0, b1, b1, tb, tb, tb)),
		path_cubic_to(cx2, sankey_blossom(b0, b0, b1, b1, ta, tb, tb), cx1, sankey_blossom(b0,
			b0, b1, b1, ta, ta, tb), a, sankey_blossom(b0, b0, b1, b1, ta, ta, ta)),
		path_close(),
	]
}
