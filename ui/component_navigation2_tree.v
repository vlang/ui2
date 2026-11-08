// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The themed look and controlled behavior of tree_view, after GPUI Kit's Tree
// (crates/component/src/tree.rs and crates/base/src/tree.rs). The keyboard
// follows TreeState: Up and Down move through the visible rows and wrap
// around, Left closes an open folder, Right opens a closed one, Enter opens
// or closes the selected folder, and revealing a node opens its ancestors.
// Multiple selection, check boxes with tri-state folders, lazily loaded
// children, filtering, virtualization, dragging and the rendering are new
// UI2 code. See third_party/gpui-kit.
module ui2

import math

// TreeViewRowFn draws the content of a themed tree row: it gets the node,
// the frame beside the disclosure and check box (local to the row), and
// whether the row is selected.
pub type TreeViewRowFn = fn (node TreeViewNode, frame Rect, selected bool) []Element

// TreeViewDrag is a row being dragged to a new place. Pointer positions are
// in window points, as pointer events report them.
pub struct TreeViewDrag {
pub:
	node    string // The node pressed; empty when no press is under way.
	start_x f64
	start_y f64
	x       f64
	y       f64
	active  bool // The pointer moved far enough for the press to be a drag.
}

// TreeViewState is the interaction state of a themed tree. The selection,
// expansion and check marks live on the nodes; tree_view_apply updates them.
pub struct TreeViewState {
pub:
	active  string // The keyboard cursor: the node the arrow keys move from.
	anchor  string // Where a Shift range starts.
	hovered string // The node under the pointer.
	drag    TreeViewDrag
}

// TreeDropPosition is where a dragged node lands against the node under it.
pub enum TreeDropPosition {
	before // Above it, among its siblings.
	after  // Below it, among its siblings.
	inside // Into it, as its last child.
}

pub struct TreeViewMove {
pub:
	node     string // The node moved.
	target   string // The node it was dropped on or beside.
	position TreeDropPosition
}

// TreeViewStep is what tree_view_update or tree_view_key did. Store `state`,
// apply the rest to the nodes with tree_view_apply, and load and move what
// it asks for.
pub struct TreeViewStep {
pub:
	state     TreeViewState
	selection bool     // `selected` is the new selection.
	selected  []string // The ids of the selected nodes, when `selection` is set.
	expand    string   // A folder to open.
	collapse  string   // A folder to close.
	// load names a folder opened before its children were loaded:
	// tree_view_apply marks it loading; give it its children with
	// tree_view_with_children.
	load      string
	checked   []string     // Nodes to check.
	unchecked []string     // Nodes to uncheck.
	confirmed bool         // A node was opened: a plain click, or Enter on a leaf.
	cancelled bool         // Escape was pressed.
	node      TreeViewNode // The node clicked or acted on.
	// moved is set when a drag ended somewhere new: rearrange the nodes with
	// tree_view_move_nodes.
	moved bool
	move  TreeViewMove
	// reveal is set when a key moved the cursor: scroll it into view with
	// tree_view_reveal_offset.
	reveal bool
}

// ── Ids and actions ─────────────────────────────────────────────────

pub fn tree_view_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

// tree_view_row_action is the action a press on a themed row emits (unless
// the node has an action_id of its own), and the action of its hover and
// drag reports.
pub fn tree_view_row_action(id string, node_id string) string {
	return component_part_id(id, 'row:' + node_id.bytes().hex())
}

pub fn tree_view_toggle_action(id string, node_id string) string {
	return component_part_id(id, 'toggle:' + node_id.bytes().hex())
}

pub fn tree_view_check_action(id string, node_id string) string {
	return component_part_id(id, 'check:' + node_id.bytes().hex())
}

enum TreeViewPart {
	row
	toggle
	check
}

struct TreeViewPress {
	part TreeViewPart
	node string
}

fn tree_view_find_action(nodes []TreeViewNode, action string) ?TreeViewPress {
	for node in nodes {
		if node.action_id.len > 0 && node.action_id == action {
			return TreeViewPress{
				part: .row
				node: node.id
			}
		}
		if node.toggle_action_id.len > 0 && node.toggle_action_id == action {
			return TreeViewPress{
				part: .toggle
				node: node.id
			}
		}
		if found := tree_view_find_action(node.children, action) {
			return found
		}
	}
	return none
}

// tree_view_press decodes a press on a row, a disclosure or a check box: the
// tree's own actions, or the action_id and toggle_action_id of a node.
fn tree_view_press(config TreeViewConfig, action string) ?TreeViewPress {
	if part := component_action_part(config.id, action) {
		for prefix, kind in {
			'row:':    TreeViewPart.row
			'toggle:': TreeViewPart.toggle
			'check:':  TreeViewPart.check
		} {
			if part.starts_with(prefix) {
				return TreeViewPress{
					part: kind
					node: tab_bar_hex_text(part[prefix.len..])?
				}
			}
		}
		return none
	}
	return tree_view_find_action(config.nodes, action)
}

// ── Nodes ───────────────────────────────────────────────────────────

fn tree_view_themed(config TreeViewConfig) bool {
	return config.theme != none
}

// tree_view_is_folder reports a node with children, loaded or not.
pub fn tree_view_is_folder(node TreeViewNode) bool {
	return node.children.len > 0 || node.has_children
}

// tree_view_find returns the node with the id, wherever it is in the tree.
pub fn tree_view_find(nodes []TreeViewNode, id string) ?TreeViewNode {
	for node in nodes {
		if node.id == id {
			return node
		}
		if found := tree_view_find(node.children, id) {
			return found
		}
	}
	return none
}

fn tree_view_collect_selected(nodes []TreeViewNode, mut out []string) {
	for node in nodes {
		if node.selected {
			out << node.id
		}
		tree_view_collect_selected(node.children, mut out)
	}
}

// tree_view_selected_ids lists the selected nodes, collapsed ones included,
// in tree order.
pub fn tree_view_selected_ids(nodes []TreeViewNode) []string {
	mut out := []string{}
	tree_view_collect_selected(nodes, mut out)
	return out
}

// tree_view_check_state is what a node's check box shows: its own mark for a
// leaf (or a folder whose children are not loaded), and for a folder whether
// all, some or none of its descendants are checked.
pub fn tree_view_check_state(node TreeViewNode) TableCheckState {
	if node.children.len == 0 {
		return if node.checked { .checked } else { .unchecked }
	}
	mut all := true
	mut any := false
	for child in node.children {
		check := tree_view_check_state(child)
		if check != .checked {
			all = false
		}
		if check != .unchecked {
			any = true
		}
	}
	return if all {
		.checked
	} else if any {
		.mixed
	} else {
		.unchecked
	}
}

fn tree_view_collect_ids(node TreeViewNode, mut out []string) {
	if !node.enabled {
		return
	}
	out << node.id
	for child in node.children {
		tree_view_collect_ids(child, mut out)
	}
}

// tree_view_all_leaves_checked reports whether every enabled leaf under a
// node (or the node, as a leaf) is checked: what decides whether its check
// box checks or unchecks.
fn tree_view_all_leaves_checked(node TreeViewNode) bool {
	if !node.enabled {
		return true
	}
	if node.children.len == 0 {
		return node.checked
	}
	return node.children.all(tree_view_all_leaves_checked(it))
}

struct TreeViewChanges {
	selection bool
	selected  map[string]bool
	expand    string
	collapse  string
	load      string
	checked   map[string]bool
	unchecked map[string]bool
}

fn tree_view_apply_changes(nodes []TreeViewNode, changes TreeViewChanges) []TreeViewNode {
	mut out := []TreeViewNode{cap: nodes.len}
	for node in nodes {
		out << TreeViewNode{
			...node
			selected: if changes.selection { node.id in changes.selected } else { node.selected }
			expanded: if node.id == changes.expand {
				true
			} else if node.id == changes.collapse {
				false
			} else {
				node.expanded
			}
			loading:  node.loading || node.id == changes.load
			checked:  if node.id in changes.checked {
				true
			} else if node.id in changes.unchecked {
				false
			} else {
				node.checked
			}
			children: tree_view_apply_changes(node.children, changes)
		}
	}
	return out
}

fn tree_view_set(ids []string) map[string]bool {
	mut out := map[string]bool{}
	for id in ids {
		out[id] = true
	}
	return out
}

// tree_view_apply returns the nodes with a step's selection, expansion,
// loading mark and check marks applied.
pub fn tree_view_apply(nodes []TreeViewNode, step TreeViewStep) []TreeViewNode {
	return tree_view_apply_changes(nodes, TreeViewChanges{
		selection: step.selection
		selected:  tree_view_set(step.selected)
		expand:    step.expand
		collapse:  step.collapse
		load:      step.load
		checked:   tree_view_set(step.checked)
		unchecked: tree_view_set(step.unchecked)
	})
}

// tree_view_with_children gives a lazily loaded folder its children and
// clears its loading mark. A folder that turns out empty loses its
// disclosure.
pub fn tree_view_with_children(nodes []TreeViewNode, id string, children []TreeViewNode) []TreeViewNode {
	mut out := []TreeViewNode{cap: nodes.len}
	for node in nodes {
		out << if node.id == id {
			TreeViewNode{
				...node
				children:     children
				has_children: children.len > 0
				loading:      false
			}
		} else {
			TreeViewNode{
				...node
				children: tree_view_with_children(node.children, id, children)
			}
		}
	}
	return out
}

fn tree_view_path_to(nodes []TreeViewNode, id string, mut path []string) bool {
	for node in nodes {
		if node.id == id {
			return true
		}
		path << node.id
		if tree_view_path_to(node.children, id, mut path) {
			return true
		}
		path.delete_last()
	}
	return false
}

// tree_view_reveal opens every folder above a node so that it shows, as
// GPUI Kit's reveal_item and set_selected_item do.
pub fn tree_view_reveal(nodes []TreeViewNode, id string) []TreeViewNode {
	mut path := []string{}
	if !tree_view_path_to(nodes, id, mut path) || path.len == 0 {
		return nodes.clone()
	}
	return tree_view_expand_ids(nodes, tree_view_set(path))
}

fn tree_view_expand_ids(nodes []TreeViewNode, ids map[string]bool) []TreeViewNode {
	mut out := []TreeViewNode{cap: nodes.len}
	for node in nodes {
		out << TreeViewNode{
			...node
			expanded: node.expanded || node.id in ids
			children: tree_view_expand_ids(node.children, ids)
		}
	}
	return out
}

// tree_view_filter keeps the nodes whose text contains the query (ignoring
// case) and the folders on the way to them, opened, as GPUI Kit's search
// example does. A match keeps all its children. An empty query keeps all.
pub fn tree_view_filter(nodes []TreeViewNode, query string) []TreeViewNode {
	needle := query.trim_space().to_lower()
	if needle.len == 0 {
		return nodes.clone()
	}
	mut out := []TreeViewNode{}
	for node in nodes {
		if node.text.to_lower().contains(needle) {
			out << TreeViewNode{
				...node
				expanded: node.expanded || node.children.len > 0
			}
			continue
		}
		children := tree_view_filter(node.children, needle)
		if children.len > 0 {
			out << TreeViewNode{
				...node
				expanded: true
				children: children
			}
		}
	}
	return out
}

fn tree_view_without(nodes []TreeViewNode, id string) []TreeViewNode {
	mut out := []TreeViewNode{cap: nodes.len}
	for node in nodes {
		if node.id == id {
			continue
		}
		out << TreeViewNode{
			...node
			children: tree_view_without(node.children, id)
		}
	}
	return out
}

fn tree_view_insert(nodes []TreeViewNode, move TreeViewMove, moving TreeViewNode) []TreeViewNode {
	mut out := []TreeViewNode{cap: nodes.len + 1}
	for node in nodes {
		if node.id != move.target {
			out << TreeViewNode{
				...node
				children: tree_view_insert(node.children, move, moving)
			}
			continue
		}
		match move.position {
			.before {
				out << moving
				out << node
			}
			.after {
				out << node
				out << moving
			}
			.inside {
				mut children := node.children.clone()
				children << moving
				out << TreeViewNode{
					...node
					expanded: true
					children: children
				}
			}
		}
	}
	return out
}

// tree_view_move_nodes moves a node (with its subtree) before, after or into
// another, the way a drag the tree reported as moved arranges them. It
// returns none when either node is missing or the target is inside the node
// moved.
pub fn tree_view_move_nodes(nodes []TreeViewNode, move TreeViewMove) ?[]TreeViewNode {
	moving := tree_view_find(nodes, move.node)?
	tree_view_find(nodes, move.target)?
	if move.node == move.target {
		return none
	}
	if _ := tree_view_find(moving.children, move.target) {
		return none
	}
	return tree_view_insert(tree_view_without(nodes, move.node), move, moving)
}

fn tree_view_outline(nodes []TreeViewNode, depth int, mut out []string) {
	for node in nodes {
		out << '${depth}:${node.id}'
		tree_view_outline(node.children, depth + 1, mut out)
	}
}

// ── Model ───────────────────────────────────────────────────────────

struct TreeViewMetrics {
	row     f64
	font    f64
	small   f64
	indent  f64
	chevron f64 // The disclosure's column.
	glyph   f64 // The chevron symbol.
	icon    f64
	check   f64
	gap     f64
	padding f64 // Around the rows.
	inner   f64 // Inside a row, before its content and after it.
	radius  f64
}

fn tree_view_metrics(size ComponentSize) TreeViewMetrics {
	m := component_metrics(size)
	i := tab_bar_size_index(size)
	return TreeViewMetrics{
		row:     [24.0, 28, 34][i]
		font:    m.font_size
		small:   m.font_size - 1
		indent:  [14.0, 16, 20][i]
		chevron: [16.0, 18, 22][i]
		glyph:   [10.0, 11, 13][i]
		icon:    math.round(m.font_size * 1.15)
		check:   [13.0, 15, 17][i]
		gap:     [4.0, 6, 8][i]
		padding: 4
		inner:   [4.0, 6, 8][i]
		radius:  math.max(m.radius - 2, 2)
	}
}

enum TreeViewEntryKind {
	node
	loading // The row under an open folder whose children are being loaded.
}

struct TreeViewEntry {
	kind   TreeViewEntryKind
	node   TreeViewNode
	depth  int
	parent int // The entry of the folder it is in, or -1.
}

struct TreeViewModel {
	entries []TreeViewEntry
	layout  VirtualListLayout
	metrics TreeViewMetrics
}

fn tree_view_flatten(nodes []TreeViewNode, depth int, parent int, mut entries []TreeViewEntry) {
	for node in nodes {
		index := entries.len
		entries << TreeViewEntry{
			kind:   .node
			node:   node
			depth:  depth
			parent: parent
		}
		if !node.expanded || !tree_view_is_folder(node) {
			continue
		}
		if node.children.len > 0 {
			tree_view_flatten(node.children, depth + 1, index, mut entries)
		} else if node.loading {
			entries << TreeViewEntry{
				kind:   .loading
				node:   node
				depth:  depth + 1
				parent: index
			}
		}
	}
}

fn tree_view_validate_nodes(nodes []TreeViewNode, mut ids map[string]bool) ! {
	for node in nodes {
		if node.id.trim_space().len == 0 || node.id in ids {
			return error('tree view nodes need unique, non-empty ids (`${node.id}`)')
		}
		ids[node.id] = true
		for icon in [node.icon, node.expanded_icon] {
			if icon.len > 0 && !symbol_known(icon) {
				return error('tree view node `${node.id}` uses `${icon}`, which not every renderer can draw; pick a name from symbol_names()')
			}
		}
		tree_view_validate_nodes(node.children, mut ids)!
	}
}

fn tree_view_model(config TreeViewConfig) !TreeViewModel {
	component_validate_frame(config.frame)!
	if !component_finite(config.offset) || config.overscan < 0 {
		return error('tree view offset must be finite and overscan non-negative')
	}
	mut ids := map[string]bool{}
	tree_view_validate_nodes(config.nodes, mut ids)!
	m := tree_view_metrics(config.size)
	mut entries := []TreeViewEntry{}
	tree_view_flatten(config.nodes, 0, -1, mut entries)
	layout := virtual_list_fixed(entries.len, m.row, 0)!.padded(m.padding)!
	return TreeViewModel{
		entries: entries
		layout:  layout
		metrics: m
	}
}

// order lists the rows the keyboard moves through and a Shift range spans:
// the visible, enabled nodes, top to bottom.
fn (model TreeViewModel) order() []string {
	mut ids := []string{}
	for entry in model.entries {
		if entry.kind == .node && entry.node.enabled {
			ids << entry.node.id
		}
	}
	return ids
}

fn (model TreeViewModel) entry_index(id string) int {
	for index, entry in model.entries {
		if entry.kind == .node && entry.node.id == id {
			return index
		}
	}
	return -1
}

// tree_view_viewport is the part of a themed tree's frame its rows scroll
// in, in the tree's own coordinates.
fn tree_view_viewport(config TreeViewConfig) Rect {
	inset := if config.bordered { 1.0 } else { 0.0 }
	return rect(inset, inset, math.max(config.frame.width - 2 * inset, 0), math.max(config.frame.height - 2 * inset,
		0))
}

// tree_view_row_width is how wide rows are. They keep clear of a scroller
// drawn over their end, as the custom renderer's is.
fn tree_view_row_width(model TreeViewModel, viewport Rect) f64 {
	scroller := if model.layout.total() > viewport.height + 0.5 { 6.0 } else { 0.0 }
	return math.max(viewport.width - 2 * model.metrics.padding - scroller, 0)
}

fn tree_view_themed_rows(config TreeViewConfig) ![]TreeViewRow {
	model := tree_view_model(config)!
	viewport := tree_view_viewport(config)
	m := model.metrics
	mut rows := []TreeViewRow{}
	for index, entry in model.entries {
		if entry.kind != .node {
			continue
		}
		rows << TreeViewRow{
			node:  entry.node
			depth: entry.depth
			frame: rect(viewport.x + m.padding, viewport.y + model.layout.item_start(index),
				tree_view_row_width(model, viewport), m.row)
		}
	}
	return rows
}

// tree_view_reveal_offset is the scroll offset of tree_view_scroll_id(id)
// that brings a node's row into view, scrolling as little as it can from
// config.offset; none when the row does not show (open its folders with
// tree_view_reveal first).
pub fn tree_view_reveal_offset(config TreeViewConfig, node_id string) ?f64 {
	model := tree_view_model(config) or { return none }
	index := model.entry_index(node_id)
	if index < 0 {
		return none
	}
	return model.layout.scroll_offset_for(index, tree_view_viewport(config).height, config.offset,
		.nearest)
}

// tree_view_visible_range is the range of rows a themed tree shows at
// config.offset, for deciding when a virtualized tree needs rebuilding.
pub fn tree_view_visible_range(config TreeViewConfig) !VirtualListRange {
	model := tree_view_model(config)!
	return model.layout.range(tree_view_viewport(config).height, config.offset, config.overscan)
}

// ── Steps ───────────────────────────────────────────────────────────

fn tree_view_list_state(config TreeViewConfig) ListState {
	return ListState{
		selected: tree_view_selected_ids(config.nodes)
		active:   config.state.active
		anchor:   config.state.anchor
		hovered:  config.state.hovered
	}
}

// tree_view_open_step opens or closes a folder. Closing the folder the
// cursor is inside moves the cursor onto it.
fn tree_view_open_step(config TreeViewConfig, node TreeViewNode, base TreeViewStep) TreeViewStep {
	if node.expanded {
		active_inside := if _ := tree_view_find(node.children, config.state.active) {
			true
		} else {
			false
		}
		return TreeViewStep{
			...base
			state:    TreeViewState{
				...base.state
				active: if active_inside { node.id } else { base.state.active }
			}
			collapse: node.id
			node:     node
		}
	}
	return TreeViewStep{
		...base
		expand: node.id
		load:   if node.children.len == 0 && !node.loading { node.id } else { '' }
		node:   node
	}
}

fn tree_view_check_step(config TreeViewConfig, node TreeViewNode) TreeViewStep {
	mut ids := []string{}
	tree_view_collect_ids(node, mut ids)
	all := tree_view_all_leaves_checked(node)
	return TreeViewStep{
		state:     config.state
		checked:   if all { []string{} } else { ids }
		unchecked: if all { ids } else { []string{} }
		node:      node
	}
}

fn tree_view_row_step(config TreeViewConfig, node TreeViewNode, modifiers ListModifiers) TreeViewStep {
	order := if model := tree_view_model(config) { model.order() } else { [node.id] }
	now := tree_view_list_state(config)
	next := list_click_state(config.selection, now, order, node.id, modifiers)
	plain := !modifiers.toggle && !modifiers.extend
	step := TreeViewStep{
		state:     TreeViewState{
			...config.state
			active: next.active
			anchor: next.anchor
		}
		selection: config.selection != .none && next.selected != now.selected
		selected:  next.selected
		confirmed: plain
		node:      node
	}
	if plain && config.expand_on_click && tree_view_is_folder(node) {
		return tree_view_open_step(config, node, step)
	}
	return step
}

// tree_view_update applies an event from on_event to a tree: a press on a
// row (selection with the given modifiers; a plain press also confirms the
// node and opens or closes a folder, see expand_on_click), on a disclosure,
// or on a check box (checking or unchecking the node and everything in it),
// the pointer entering or leaving a row (hovered), and the pointer phases of
// a drag (`moved` when one ends somewhere new). A node's own action_id and
// toggle_action_id count as presses on it. It returns none for events that
// are not the tree's, malformed or forged ones, disabled nodes and changes
// that change nothing.
pub fn tree_view_update(config TreeViewConfig, event string, modifiers ListModifiers) ?TreeViewStep {
	if pointer := parse_pointer_event(event) {
		return tree_view_pointer(config, pointer)
	}
	press := tree_view_press(config, event)?
	node := tree_view_find(config.nodes, press.node)?
	if !node.enabled {
		return none
	}
	match press.part {
		.toggle {
			if !tree_view_is_folder(node) {
				return none
			}
			return tree_view_open_step(config, node, TreeViewStep{
				state: config.state
			})
		}
		.check {
			if !config.checkable {
				return none
			}
			return tree_view_check_step(config, node)
		}
		.row {
			return tree_view_row_step(config, node, modifiers)
		}
	}
}

const tree_view_drag_threshold = 10.0

fn tree_view_pointer(config TreeViewConfig, pointer PointerEvent) ?TreeViewStep {
	press := tree_view_press(config, pointer.action)?
	if press.part != .row {
		return none
	}
	node := tree_view_find(config.nodes, press.node)?
	if !node.enabled {
		return none
	}
	now := config.state
	match pointer.phase {
		'enter', 'leave' {
			hovered := if pointer.phase == 'enter' {
				node.id
			} else if now.hovered == node.id {
				''
			} else {
				return none
			}
			if hovered == now.hovered {
				return none
			}
			return TreeViewStep{
				state: TreeViewState{
					...now
					hovered: hovered
				}
			}
		}
		'down' {
			if !config.reorderable || !component_finite(pointer.x) || !component_finite(pointer.y) {
				return none
			}
			return TreeViewStep{
				state: TreeViewState{
					...now
					drag: TreeViewDrag{
						node:    node.id
						start_x: pointer.x
						start_y: pointer.y
						x:       pointer.x
						y:       pointer.y
					}
				}
			}
		}
		'drag' {
			if !config.reorderable || now.drag.node != node.id || !component_finite(pointer.x)
				|| !component_finite(pointer.y) {
				return none
			}
			dx := pointer.x - now.drag.start_x
			dy := pointer.y - now.drag.start_y
			return TreeViewStep{
				state: TreeViewState{
					...now
					drag: TreeViewDrag{
						...now.drag
						x:      pointer.x
						y:      pointer.y
						active: now.drag.active
							|| dx * dx + dy * dy > tree_view_drag_threshold * tree_view_drag_threshold
					}
				}
			}
		}
		'up' {
			if now.drag.node != node.id {
				return none
			}
			ended := TreeViewState{
				...now
				drag: TreeViewDrag{}
			}
			if !now.drag.active {
				return TreeViewStep{
					state: ended
				}
			}
			model := tree_view_model(config) or { return none }
			dropped := TreeViewDrag{
				...now.drag
				y: if component_finite(pointer.y) { pointer.y } else { now.drag.y }
			}
			move := tree_view_drop(model, dropped) or {
				return TreeViewStep{
					state: ended
				}
			}
			return TreeViewStep{
				state: ended
				moved: tree_view_move_changes(config.nodes, move)
				move:  move
			}
		}
		else {
			return none
		}
	}
}

// tree_view_move_changes reports whether a move puts the node somewhere new.
fn tree_view_move_changes(nodes []TreeViewNode, move TreeViewMove) bool {
	moved := tree_view_move_nodes(nodes, move) or { return false }
	mut old_outline := []string{}
	mut new_outline := []string{}
	tree_view_outline(nodes, 0, mut old_outline)
	tree_view_outline(moved, 0, mut new_outline)
	return old_outline != new_outline
}

// tree_view_drop is where a dragged row lands: the row its middle is over
// after moving as far as the pointer has, and before, after or into it
// depending on where in that row. Dropping a node into itself or onto one of
// its own descendants goes nowhere.
fn tree_view_drop(model TreeViewModel, drag TreeViewDrag) ?TreeViewMove {
	from := model.entry_index(drag.node)
	if from < 0 || model.layout.count == 0 {
		return none
	}
	m := model.metrics
	layout := model.layout
	middle := layout.item_start(from) + m.row / 2 + drag.y - drag.start_y
	first := layout.item_start(0)
	last := layout.item_end(layout.count - 1)
	probe := math.min(math.max(middle, first), last - 0.01)
	target := layout.index_at(probe)
	if target < 0 {
		return none
	}
	entry := model.entries[target]
	if entry.kind != .node || entry.node.id == drag.node {
		return none
	}
	moving := model.entries[from].node
	if _ := tree_view_find(moving.children, entry.node.id) {
		return none
	}
	fraction := (probe - layout.item_start(target)) / m.row
	open_folder := entry.node.expanded && entry.node.children.len > 0
	position := if tree_view_is_folder(entry.node) && entry.node.enabled {
		if fraction < 0.25 {
			TreeDropPosition.before
		} else if fraction > 0.75 && !open_folder {
			TreeDropPosition.after
		} else {
			TreeDropPosition.inside
		}
	} else if fraction < 0.5 {
		TreeDropPosition.before
	} else {
		TreeDropPosition.after
	}
	return TreeViewMove{
		node:     drag.node
		target:   entry.node.id
		position: position
	}
}

// tree_view_drop_preview is where a drag would land right now, for drawing.
fn tree_view_drop_preview(config TreeViewConfig, model TreeViewModel) ?TreeViewMove {
	drag := config.state.drag
	if !config.reorderable || !drag.active {
		return none
	}
	return tree_view_drop(model, drag)
}

// ── Keys ────────────────────────────────────────────────────────────

// tree_view_cursor_step moves the cursor to a node, the selection following
// it (Shift extends it in multiple mode).
fn tree_view_cursor_step(config TreeViewConfig, order []string, id string, extend bool) ?TreeViewStep {
	now := tree_view_list_state(config)
	active := id
	mut anchor := id
	mut selected := now.selected.clone()
	if config.selection != .none {
		if extend && config.selection == .multiple {
			anchor = list_range_anchor(now, order, id)
			selected = list_span(order, anchor, id)
		} else {
			selected = [id]
		}
	}
	if active == now.active && anchor == now.anchor && selected == now.selected {
		return none
	}
	node := tree_view_find(config.nodes, id) or { TreeViewNode{} }
	return TreeViewStep{
		state:     TreeViewState{
			...config.state
			active: active
			anchor: anchor
		}
		selection: selected != now.selected
		selected:  selected
		node:      node
		reveal:    true
	}
}

// tree_view_key moves through a tree from on_key_event, as GPUI Kit's tree
// does: Up and Down to the previous or next visible node (wrapping around),
// Left to close an open folder or else go to the folder above, Right to open
// a closed folder or else go to its first child, Enter to open or close a
// folder or confirm a leaf. Home and End go to the first and last node, Page
// Up and Page Down a viewport's height. The selection follows the cursor;
// Shift extends it in multiple mode and Cmd/Ctrl+A selects every visible
// node. Space checks or unchecks the node in a checkable tree and otherwise
// toggles it in the selection. Escape clears the cursor. Consume the key
// whenever a step comes back; scroll to tree_view_reveal_offset when it
// says reveal.
pub fn tree_view_key(config TreeViewConfig, event KeyEvent) ?TreeViewStep {
	if event.alt {
		return none
	}
	model := tree_view_model(config) or { return none }
	order := model.order()
	if order.len == 0 {
		return none
	}
	command := event.cmd || event.ctrl
	selected := tree_view_selected_ids(config.nodes)
	mut current := order.index(config.state.active)
	if current < 0 {
		for index, id in order {
			if id in selected {
				current = index
				break
			}
		}
	}
	match event.code {
		.escape {
			if command || event.shift || config.state.active.len == 0 {
				return none
			}
			return TreeViewStep{
				state:     TreeViewState{
					...config.state
					active: ''
				}
				cancelled: true
			}
		}
		.left, .right, .enter, .kp_enter {
			if current < 0 || command || event.shift {
				return none
			}
			entry_index := model.entry_index(order[current])
			entry := model.entries[entry_index]
			node := entry.node
			folder := tree_view_is_folder(node)
			base := TreeViewStep{
				state: TreeViewState{
					...config.state
					active: node.id
				}
			}
			match event.code {
				.left {
					if folder && node.expanded {
						return tree_view_open_step(config, node, base)
					}
					if entry.parent < 0 {
						return none
					}
					parent := model.entries[entry.parent].node
					if !parent.enabled {
						return none
					}
					return tree_view_cursor_step(config, order, parent.id, false)
				}
				.right {
					if folder && !node.expanded {
						return tree_view_open_step(config, node, base)
					}
					if !folder || entry_index + 1 >= model.entries.len
						|| model.entries[entry_index + 1].parent != entry_index {
						return none
					}
					child := model.entries[entry_index + 1]
					if child.kind != .node || !child.node.enabled {
						return none
					}
					return tree_view_cursor_step(config, order, child.node.id, false)
				}
				else {
					if folder {
						return tree_view_open_step(config, node, base)
					}
					return TreeViewStep{
						...base
						confirmed: true
						node:      node
					}
				}
			}
		}
		.space {
			if current < 0 || command || event.shift {
				return none
			}
			id := order[current]
			node := tree_view_find(config.nodes, id)?
			if config.checkable {
				return tree_view_check_step(config, node)
			}
			if config.selection == .none {
				return none
			}
			next := if config.selection == .multiple {
				if id in selected { selected.filter(it != id) } else { list_union(selected, [id]) }
			} else {
				[id]
			}
			if next == selected {
				return none
			}
			return TreeViewStep{
				state:     TreeViewState{
					...config.state
					active: id
					anchor: id
				}
				selection: true
				selected:  next
				node:      node
			}
		}
		.a {
			if !command || event.shift || config.selection != .multiple {
				return none
			}
			if selected.len == order.len && order.all(it in selected) {
				return none
			}
			return TreeViewStep{
				state:     config.state
				selection: true
				selected:  order
			}
		}
		.up, .down, .home, .end, .page_up, .page_down {
			if command {
				return none
			}
			page := math.max(int(tree_view_viewport(config).height / model.metrics.row) - 1, 1)
			target := match event.code {
				.down {
					if current < 0 { 0 } else { (current + 1) % order.len }
				}
				.up {
					if current < 0 { order.len - 1 } else { (current - 1 + order.len) % order.len }
				}
				.home { 0 }
				.end { order.len - 1 }
				.page_down { math.min(math.max(current, 0) + page, order.len - 1) }
				else { math.max(current - page, 0) }
			}
			return tree_view_cursor_step(config, order, order[target], event.shift)
		}
		else {
			return none
		}
	}
}
