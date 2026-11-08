// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Resizable panels after GPUI Kit's resizable (crates/base/src/resizable and
// crates/component/src/resizable.rs). Two rules are taken from there: the
// handle's indicator levels (length and opacity for hovered, pressed and
// dragging, its 3-point thickness and the 4-point grab padding), and the
// container-resize rule that keeps a fixed panel's size while the other panels
// share the difference in proportion to their sizes. The controlled state, the
// drag and keyboard rules, collapsing and the rendering are new UI2 code. See
// third_party/gpui-kit.
module ui2

import math

// Resizable panels: a row or a column of panels separated by handles the user
// drags. Like every ui2 component they are controlled. The application keeps a
// ResizableState per group, passes it in, and turns what the group emits back
// into a new state with resizable_panels_event and resizable_panels_key.

pub const resizable_default_min_size = 100.0

// How far the grab band of a handle reaches past its one-point line on each side.
const resizable_handle_reach = 4.0
const resizable_indicator_thickness = 3.0
// A step that takes a handle to the end of its range, for Home and End.
const resizable_far = 1.0e9

// ResizeHandlePhase is how far the pointer has gone with a handle. A drag takes
// the pointer off the handle's thin band almost at once, so the phase comes from
// the drag state rather than from hover.
pub enum ResizeHandlePhase {
	idle     // Only the hairline shows.
	hovered  // The pointer is over the band.
	pressed  // The pointer went down on it and has not moved.
	dragging // It is being dragged.
}

// ResizeHandleEdge says where a handle's band sits against the boundary it
// resizes. A handle between two panels straddles it; the handle on the edge of a
// container that clips (a dock, a sidebar) hugs that edge from inside, with its
// line on the container's outermost point.
pub enum ResizeHandleEdge {
	straddle
	leading  // The line is the band's first point; the band reaches inward after it.
	trailing // The line is the band's last point.
}

pub struct ResizeHandleConfig {
pub:
	id    string // Required: the action of the pointer events the handle reports.
	frame Rect   // The band, from resize_handle_frame.
	// axis is the direction the handle resizes along: .horizontal for a vertical
	// divider between side-by-side panels.
	axis                Orientation = .horizontal
	edge                ResizeHandleEdge
	phase               ResizeHandlePhase
	focus_visible       bool // Draw the keyboard focus indicator.
	line                bool = true // Draw the resting hairline.
	enabled             bool = true
	accessibility_label string
	accessibility_value string
	theme               ComponentTheme
}

// resize_handle_frame is the band of a handle whose one-point line starts at
// `position` along axis and runs from `start` for `length` across it.
pub fn resize_handle_frame(axis Orientation, position f64, start f64, length f64, edge ResizeHandleEdge) Rect {
	r := resizable_handle_reach
	from, extent := match edge {
		.straddle { position - r, 1 + 2 * r }
		.leading { position, 1 + r }
		.trailing { position - r, 1 + r }
	}
	return if axis == .horizontal {
		rect(from, start, extent, length)
	} else {
		rect(start, from, length, extent)
	}
}

// resize_handle_indicator is the length and the fill opacity of the pill a
// handle shows over its line in a phase; idle shows none.
pub fn resize_handle_indicator(phase ResizeHandlePhase) (f64, f64) {
	return match phase {
		.idle { 0.0, 0.0 }
		.hovered { 20.0, 0.35 }
		.pressed { 28.0, 0.6 }
		.dragging { 44.0, 0.9 }
	}
}

fn resize_handle_line_offset(edge ResizeHandleEdge) f64 {
	return match edge {
		.straddle, .trailing { resizable_handle_reach }
		.leading { 0 }
	}
}

// resize_handle draws a standalone handle: a band that reports pointer
// `down`, `drag` and `up` (with window coordinates) and `enter`/`leave` under
// its id, shows the resize cursor, and paints the hairline and the indicator for
// its phase. What a drag resizes is the application's: decode the events with
// parse_pointer_event. Resizable panels and the dock area draw their handles
// with it.
pub fn resize_handle(config ResizeHandleConfig) !Element {
	component_validate_id(config.id)!
	component_validate_frame(config.frame)!
	return component_finish(resize_handle_element(config))
}

fn resize_handle_element(config ResizeHandleConfig) Element {
	frame := config.frame
	horizontal := config.axis == .horizontal
	offset := resize_handle_line_offset(config.edge)
	along := if horizontal { frame.height } else { frame.width }
	mut children := []Element{}
	if config.line {
		line := if horizontal {
			rect(offset, 0, 1, frame.height)
		} else {
			rect(0, offset, frame.width, 1)
		}
		children << Element{
			...view('', line, BoxStyle{ bg: config.theme.border }, []Element{})
			key: 'line'
		}
	}
	mut length, mut opacity := resize_handle_indicator(config.phase)
	mut color := config.theme.muted_foreground
	if config.focus_visible && config.enabled {
		length = math.max(length, 44)
		opacity = 1
		color = config.theme.primary
	}
	if !config.enabled {
		length = 0
	}
	length = math.min(length, along)
	if length > 0.5 {
		t := resizable_indicator_thickness
		cross := offset - (t - 1) / 2
		start := math.round((along - length) / 2)
		pill := if horizontal {
			rect(cross, start, t, length)
		} else {
			rect(start, cross, length, t)
		}
		children << Element{
			...view('', pill, BoxStyle{
				bg:      color
				radius:  t / 2
				opacity: opacity
			}, []Element{})
			key: 'indicator'
		}
	}
	return Element{
		...draggable_view_with_cursor(config.id, frame, BoxStyle{ transparent: true }, if config.enabled {
			if horizontal { cursor_resize_ew } else { cursor_resize_ns }
		} else {
			cursor_default
		}, children)
		hoverable:           config.enabled
		enabled:             config.enabled
		accessibility_role:  'separator'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			'Resize'
		}
		accessibility_value: config.accessibility_value
	}
}

// ── Resizable panels ────────────────────────────────────────────────

// ResizablePanelBuildFn builds a panel's content for its panel-local frame,
// rect(0, 0, width, height), so the content can follow the panel's size. A
// nested group is built here: return resizable_panels with this frame.
pub type ResizablePanelBuildFn = fn (frame Rect) Element

pub struct ResizablePanel {
pub:
	key      string // Required, unique in the group: names the panel and its handle.
	size     f64    // Initial size along the axis; 0 shares what the sized panels leave.
	min_size f64 = resizable_default_min_size
	max_size f64 // 0 means no maximum.
	// fixed keeps the panel's size when the container resizes; the other panels
	// share the difference. Its own handles still resize it.
	fixed bool
	// resizable false locks the panel at its size: a drag on a handle beside it
	// moves it along whole and resizes the panels past it.
	resizable bool = true
	// visible false takes the panel out: no space, no handle. Its size is kept.
	visible bool = true
	// A collapsible panel collapses to collapsed_size when its handle is dragged
	// more than half its minimum past that minimum, or with Enter on a focused
	// handle beside it; it restores to the size it had.
	collapsible    bool
	collapsed_size f64
	label          string // Accessibility label; also names its handle.
	box            BoxStyle = BoxStyle{
		transparent: true
	}
	children       []Element // Content in panel-local coordinates.
	// build makes the content from the panel's frame instead; it wins over children.
	build ResizablePanelBuildFn = unsafe { nil }
}

// ResizableDrag remembers where a handle drag started. The decoder fills it in
// on the press; it stays in the state until the release.
pub struct ResizableDrag {
pub:
	handle    int = -1 // Index of the panel before the handle.
	start     f64   // Window coordinate of the press along the axis.
	sizes     []f64 // The laid-out sizes at the press.
	stored    []f64 // The state's sizes at the press (what collapsed panels restore to).
	collapsed []bool
	moved     bool
}

pub fn (drag ResizableDrag) active() bool {
	return drag.handle >= 0
}

// ResizableState is a group's controlled state. sizes and collapsed run
// parallel to the panels; when sizes does not have one entry per panel the
// panels' own sizes are used. A collapsed panel's entry is the size it restores
// to. Handles are named by the index of the panel before them.
pub struct ResizableState {
pub:
	sizes         []f64
	collapsed     []bool
	drag          ResizableDrag
	hovered       int = -1 // The handle under the pointer.
	focused       int = -1 // The handle keys act on.
	focus_visible bool // Show the focus indicator: set by keys, cleared by the pointer.
}

pub struct ResizablePanelsConfig {
pub:
	id string // Required.
	// frame is the group's frame in its parent.
	frame Rect
	// axis is the direction the panels follow: .horizontal places them side by
	// side with vertical dividers, .vertical stacks them.
	axis                Orientation = .horizontal
	panels              []ResizablePanel
	state               ResizableState
	step                f64  = 10 // Keyboard step; Shift moves five steps.
	enabled             bool = true
	accessibility_label string
	theme               ComponentTheme
}

// ResizableHandle is one handle of a laid-out group.
pub struct ResizableHandle {
pub:
	panel int  // The panel before the handle; the handle's index.
	next  int  // The panel after it.
	line  f64  // Group-local position of its one-point line along the axis.
	frame Rect // Its grab band, group-local.
}

// ResizableLayout is a group laid out in its frame, in group-local points.
pub struct ResizableLayout {
pub:
	sizes     []f64 // Each panel's size along the axis; 0 for hidden ones.
	frames    []Rect
	collapsed []bool
	handles   []ResizableHandle
	order     []int // The visible panels, in order.
}

// ResizablePanelsEventKind names what a ResizablePanelsStep did.
pub enum ResizablePanelsEventKind {
	hover        // The pointer entered or left a handle.
	resize_start // A handle was pressed; it is now focused.
	resize       // The sizes changed during a drag or from a key.
	resize_end   // The drag ended: a good moment to save the sizes.
	collapse     // A panel collapsed.
	expand       // A panel was restored.
	focus        // The focused handle changed, or its focus indicator.
}

// ResizablePanelsStep is the group's next state and what changed.
pub struct ResizablePanelsStep {
pub:
	kind   ResizablePanelsEventKind
	state  ResizableState
	handle int = -1
	panel  int = -1 // The panel collapsed or expanded.
}

// ResizableSlot is the part of a panel the sizing rules read.
struct ResizableSlot {
	min            f64
	max            f64
	fixed          bool
	locked         bool
	visible        bool
	collapsible    bool
	collapsed_size f64
}

fn resizable_slot(panel ResizablePanel) ResizableSlot {
	max := if panel.max_size > 0 { math.max(panel.max_size, panel.min_size) } else { math.max_f64 }
	return ResizableSlot{
		min:            panel.min_size
		max:            max
		fixed:          panel.fixed
		locked:         !panel.resizable
		visible:        panel.visible
		collapsible:    panel.collapsible
		collapsed_size: panel.collapsed_size
	}
}

fn resizable_validate(config ResizablePanelsConfig) ! {
	component_validate_id(config.id)!
	component_validate_frame(config.frame)!
	if !component_finite(config.step) || config.step <= 0 {
		return error('resizable panels step must be finite and positive')
	}
	mut keys := map[string]bool{}
	for panel in config.panels {
		if panel.key.trim_space().len == 0 || panel.key in keys {
			return error('resizable panel keys must be non-empty and unique')
		}
		keys[panel.key] = true
		for value in [panel.size, panel.min_size, panel.max_size, panel.collapsed_size] {
			if !component_finite(value) || value < 0 {
				return error('resizable panel sizes must be finite and non-negative')
			}
		}
	}
	for value in config.state.sizes {
		if !component_finite(value) || value < 0 {
			return error('resizable state sizes must be finite and non-negative')
		}
	}
}

fn resizable_extent(config ResizablePanelsConfig) f64 {
	return if config.axis == .horizontal { config.frame.width } else { config.frame.height }
}

fn resizable_cross(config ResizablePanelsConfig) f64 {
	return if config.axis == .horizontal { config.frame.height } else { config.frame.width }
}

fn resizable_collapsed_flags(config ResizablePanelsConfig) []bool {
	mut flags := []bool{len: config.panels.len}
	for i, panel in config.panels {
		flags[i] = i < config.state.collapsed.len && config.state.collapsed[i] && panel.collapsible
	}
	return flags
}

// resizable_order lists the visible panels.
fn resizable_order(slots []ResizableSlot) []int {
	mut order := []int{}
	for i, slot in slots {
		if slot.visible {
			order << i
		}
	}
	return order
}

// resizable_stored_sizes returns the state's sizes when there is one per panel,
// and otherwise the starting sizes from the panels' own.
fn resizable_stored_sizes(config ResizablePanelsConfig, slots []ResizableSlot, collapsed []bool, available f64) []f64 {
	if config.state.sizes.len == config.panels.len {
		return config.state.sizes.clone()
	}
	return resizable_initial_sizes(slots, config.panels.map(it.size), collapsed, available)
}

// resizable_initial_sizes starts every panel at its preferred size, and the
// visible ones that have none share evenly what the sized ones leave.
fn resizable_initial_sizes(slots []ResizableSlot, preferred []f64, collapsed []bool, available f64) []f64 {
	mut sizes := preferred.clone()
	mut taken := 0.0
	mut flexible := 0
	for i, slot in slots {
		if !slot.visible {
			continue
		}
		if collapsed[i] {
			taken += slot.collapsed_size
		} else if preferred[i] > 0 {
			taken += preferred[i]
		} else {
			flexible++
		}
	}
	if flexible > 0 {
		share := math.max(available - taken, 0) / f64(flexible)
		for i, slot in slots {
			if slot.visible && !collapsed[i] && preferred[i] <= 0 {
				sizes[i] = math.min(math.max(share, slot.min), slot.max)
			}
		}
	}
	return sizes
}

// ResizableSegment is where a laid-out panel starts and how long it is, with
// the one-point line after it, on whole points.
struct ResizableSegment {
	start  f64
	length f64
	line   f64 // -1 after the last panel.
}

// resizable_segments places the panels of `order` one after another from
// origin, a one-point line between each two, rounding every boundary so lines
// land on whole points.
fn resizable_segments(sizes []f64, order []int, origin f64) []ResizableSegment {
	mut segments := []ResizableSegment{cap: order.len}
	mut exact := origin
	mut start := origin
	for n, i in order {
		exact += sizes[i]
		end := math.round(exact)
		last := n == order.len - 1
		segments << ResizableSegment{
			start:  start
			length: math.max(end - start, 0)
			line:   if last { -1 } else { end }
		}
		if !last {
			exact += 1
			start = end + 1
		}
	}
	return segments
}

// resizable_fit_sizes makes the visible panels fill `available`. Sizes are
// first held to each panel's range; then a difference is shared by the
// flexible panels in proportion to their sizes, then by the fixed ones, then by
// the locked ones, and as a last resort past the panels' limits so the panels
// always cover the container. Collapsed panels keep their collapsed size and
// hidden ones take nothing.
fn resizable_fit_sizes(slots []ResizableSlot, sizes []f64, collapsed []bool, available f64) []f64 {
	mut out := []f64{len: slots.len}
	mut active := []int{}
	mut room := math.max(available, 0)
	for i, slot in slots {
		if !slot.visible {
			continue
		}
		if collapsed[i] {
			out[i] = math.min(slot.collapsed_size, room)
			room -= out[i]
			continue
		}
		size := if i < sizes.len { sizes[i] } else { 0.0 }
		out[i] = math.min(math.max(size, slot.min), slot.max)
		active << i
	}
	if active.len == 0 {
		return out
	}
	mut total := 0.0
	for i in active {
		total += out[i]
	}
	delta := room - total
	if math.abs(delta) < 1e-9 {
		return out
	}
	grow := delta > 0
	mut tiers := [][]int{}
	tiers << active.filter(!slots[it].fixed && !slots[it].locked)
	tiers << active.filter(slots[it].fixed && !slots[it].locked)
	tiers << active.filter(slots[it].locked)
	mut left := math.abs(delta)
	for tier in tiers {
		if left <= 1e-9 {
			break
		}
		left = resizable_share(slots, mut out, tier, left, grow, true)
	}
	if left > 1e-9 {
		// Every panel is at its limit: go past the limits rather than leave a gap
		// or overflow the container.
		left = resizable_share(slots, mut out, active, left, grow, false)
	}
	return out
}

// resizable_share spreads amount over members in proportion to their sizes
// (evenly when they are all zero), growing or shrinking them, within their
// ranges when `limits` is set. It returns what it could not place.
fn resizable_share(slots []ResizableSlot, mut sizes []f64, members []int, amount f64, grow bool, limits bool) f64 {
	mut left := amount
	mut open := members.clone()
	for _ in 0 .. members.len + 1 {
		if left <= 1e-9 || open.len == 0 {
			break
		}
		mut weight := 0.0
		for i in open {
			weight += sizes[i]
		}
		mut placed := 0.0
		mut next := []int{}
		for i in open {
			share := if weight > 0 { left * sizes[i] / weight } else { left / f64(open.len) }
			capacity := if grow {
				if limits { slots[i].max - sizes[i] } else { math.max_f64 }
			} else {
				if limits { sizes[i] - slots[i].min } else { sizes[i] }
			}
			step := math.min(share, math.max(capacity, 0))
			sizes[i] += if grow { step } else { -step }
			placed += step
			if step < share - 1e-9 {
				continue
			}
			next << i
		}
		left -= placed
		if placed <= 1e-9 && next.len == open.len {
			break
		}
		open = next.clone()
	}
	return math.max(left, 0)
}

// resizable_capacity is how much a panel can grow (or shrink) in a drag.
// `immediate` is true for the panel right beside the handle: a fixed panel only
// gives way to its own handle, and locked and collapsed panels never do.
fn resizable_capacity(slot ResizableSlot, size f64, collapsed bool, immediate bool, grow bool) f64 {
	if slot.locked || collapsed || (slot.fixed && !immediate) {
		return 0
	}
	return if grow { math.max(slot.max - size, 0) } else { math.max(size - slot.min, 0) }
}

// resizable_move takes up to amount from (or gives it to) the listed panels,
// nearest first, and returns how much it moved.
fn resizable_move(slots []ResizableSlot, mut sizes []f64, collapsed []bool, panels []int, amount f64, grow bool) f64 {
	mut left := amount
	for n, i in panels {
		if left <= 0 {
			break
		}
		step := math.min(left, resizable_capacity(slots[i], sizes[i], collapsed[i], n == 0,
			grow))
		sizes[i] += if grow { step } else { -step }
		left -= step
	}
	return amount - left
}

fn resizable_total_capacity(slots []ResizableSlot, sizes []f64, collapsed []bool, panels []int, grow bool) f64 {
	mut total := 0.0
	for n, i in panels {
		capacity := resizable_capacity(slots[i], sizes[i], collapsed[i], n == 0, grow)
		if capacity >= math.max_f64 / 4 {
			return math.max_f64 / 4
		}
		total += capacity
	}
	return total
}

// resizable_drag_sizes moves the handle after order[position] by delta from the
// sizes at the start of the drag. Space moves between the two sides, nearest
// panels first: the side the handle moves into gives (each panel down to its
// minimum), the other side takes (each up to its maximum). With snap, a
// collapsible panel beside the handle collapses once the handle is more than
// half its minimum past its own start size, and a collapsed one beside the
// handle expands once the handle has pulled it open by half its minimum.
fn resizable_drag_sizes(slots []ResizableSlot, start []f64, start_collapsed []bool, order []int, position int, delta f64, snap bool) ([]f64, []bool) {
	mut sizes := start.clone()
	mut collapsed := start_collapsed.clone()
	if position < 0 || position >= order.len - 1 || !component_finite(delta) || delta == 0 {
		return sizes, collapsed
	}
	forward := delta > 0
	amount := math.abs(delta)
	mut leading := []int{}
	for n := position; n >= 0; n-- {
		leading << order[n]
	}
	trailing := order[position + 1..].clone()
	takers := if forward { leading } else { trailing }
	givers := if forward { trailing } else { leading }
	taker := takers[0]
	giver := givers[0]
	if collapsed[taker] {
		if !snap {
			return sizes, collapsed
		}
		slot := slots[taker]
		pulled := slot.collapsed_size + amount
		needed := math.max(slot.min - slot.collapsed_size, 0)
		available := resizable_total_capacity(slots, sizes, collapsed, givers, false)
		if pulled < slot.min / 2 || available < needed {
			return sizes, collapsed
		}
		want := math.min(math.max(pulled, slot.min), slot.max) - slot.collapsed_size
		taken := resizable_move(slots, mut sizes, collapsed, givers, math.min(want, available),
			false)
		collapsed[taker] = false
		sizes[taker] = slot.collapsed_size + taken
		return sizes, collapsed
	}
	room := resizable_total_capacity(slots, sizes, collapsed, takers, true)
	give := resizable_total_capacity(slots, sizes, collapsed, givers, false)
	moved := math.min(amount, math.min(room, give))
	resizable_move(slots, mut sizes, collapsed, givers, moved, false)
	resizable_move(slots, mut sizes, collapsed, takers, moved, true)
	slot := slots[giver]
	if snap && slot.collapsible && !collapsed[giver] && start[giver] - amount < slot.min / 2 {
		freed := sizes[giver] - slot.collapsed_size
		collapsed[giver] = true
		sizes[giver] = slot.collapsed_size
		mut left := freed - resizable_move(slots, mut sizes, collapsed, takers, freed, true)
		if left > 0 {
			// The side the handle moved into takes the rest back.
			left -= resizable_move(slots, mut sizes, collapsed, givers[1..], left, true)
		}
		if left > 0 {
			sizes[taker] += left
		}
	}
	return sizes, collapsed
}

fn resizable_slots(config ResizablePanelsConfig) []ResizableSlot {
	return config.panels.map(resizable_slot(it))
}

// resizable_panels_layout lays a group out in its frame: every panel's size and
// frame and every handle, all group-local. Panels are separated by a one-point
// line, which the handle's band straddles.
pub fn resizable_panels_layout(config ResizablePanelsConfig) !ResizableLayout {
	resizable_validate(config)!
	slots := resizable_slots(config)
	collapsed := resizable_collapsed_flags(config)
	order := resizable_order(slots)
	lines := math.max(order.len - 1, 0)
	available := math.max(resizable_extent(config) - f64(lines), 0)
	stored := resizable_stored_sizes(config, slots, collapsed, available)
	sizes := resizable_fit_sizes(slots, stored, collapsed, available)
	return resizable_place(config, sizes, collapsed, order)
}

fn resizable_place(config ResizablePanelsConfig, sizes []f64, collapsed []bool, order []int) ResizableLayout {
	cross := resizable_cross(config)
	horizontal := config.axis == .horizontal
	mut frames := []Rect{len: config.panels.len}
	mut handles := []ResizableHandle{}
	segments := resizable_segments(sizes, order, 0)
	for n, i in order {
		segment := segments[n]
		frames[i] = if horizontal {
			rect(segment.start, 0, segment.length, cross)
		} else {
			rect(0, segment.start, cross, segment.length)
		}
		if segment.line >= 0 {
			handles << ResizableHandle{
				panel: i
				next:  order[n + 1]
				line:  segment.line
				frame: resize_handle_frame(config.axis, segment.line, 0, cross, .straddle)
			}
		}
	}
	return ResizableLayout{
		sizes:     sizes
		frames:    frames
		collapsed: collapsed
		handles:   handles
		order:     order
	}
}

fn resizable_handle_phase(state ResizableState, handle int) ResizeHandlePhase {
	if state.drag.handle == handle {
		return if state.drag.moved { .dragging } else { .pressed }
	}
	return if state.hovered == handle && !state.drag.active() { .hovered } else { .idle }
}

pub fn resizable_handle_action(id string, handle int) string {
	return component_part_id(id, 'handle:${handle}')
}

fn resizable_panel_name(panel ResizablePanel) string {
	return if panel.label.len > 0 { panel.label } else { panel.key }
}

// resizable_panels draws a group: each visible panel's content in its frame,
// then the handles on top. Pass every event to resizable_panels_event and keys
// to resizable_panels_key, and store the state they return.
pub fn resizable_panels(config ResizablePanelsConfig) !Element {
	layout := resizable_panels_layout(config)!
	mut children := []Element{cap: layout.order.len * 2}
	for i in layout.order {
		panel := config.panels[i]
		frame := layout.frames[i]
		local := rect(0, 0, frame.width, frame.height)
		content := if voidptr(panel.build) != unsafe { nil } {
			[panel.build(local)]
		} else {
			panel.children
		}
		children << Element{
			...view(component_part_id(config.id, 'panel:' + panel.key.bytes().hex()), frame,
				panel.box, content)
			key:                 'panel:' + panel.key
			hidden:              frame.width <= 0 || frame.height <= 0
			accessibility_role:  'group'
			accessibility_label: resizable_panel_name(panel)
			accessibility_value: if layout.collapsed[i] { 'collapsed' } else { '' }
		}
	}
	for handle in layout.handles {
		panel := config.panels[handle.panel]
		children << Element{
			...resize_handle_element(ResizeHandleConfig{
				id:                  resizable_handle_action(config.id, handle.panel)
				frame:               handle.frame
				axis:                config.axis
				phase:               resizable_handle_phase(config.state, handle.panel)
				focus_visible:       config.state.focus_visible
					&& config.state.focused == handle.panel
				enabled:             config.enabled
				accessibility_label: 'Resize ${resizable_panel_name(panel)}'
				accessibility_value: '${int(math.round(layout.sizes[handle.panel]))}'
				theme:               config.theme
			})
			key: 'handle:' + panel.key
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}

// resizable_stored_after keeps what a panel restores to while it is collapsed,
// the size it has otherwise, and a hidden panel's size untouched.
fn resizable_stored_after(slots []ResizableSlot, sizes []f64, collapsed []bool, before []f64, before_collapsed []bool, laid []f64) []f64 {
	mut out := []f64{len: slots.len}
	for i, slot in slots {
		previous := if i < before.len { before[i] } else { laid[i] }
		out[i] = if !slot.visible {
			previous
		} else if collapsed[i] {
			if before_collapsed[i] { previous } else { laid[i] }
		} else {
			sizes[i]
		}
	}
	return out
}

fn resizable_order_position(order []int, panel int) int {
	for n, i in order {
		if i == panel {
			return n
		}
	}
	return -1
}

fn resizable_axis_coordinate(axis Orientation, pointer PointerEvent) f64 {
	return if axis == .horizontal { pointer.x } else { pointer.y }
}

fn resizable_with(state ResizableState, sizes []f64, collapsed []bool, drag ResizableDrag) ResizableState {
	return ResizableState{
		...state
		sizes:     sizes
		collapsed: collapsed
		drag:      drag
	}
}

// resizable_panels_event decodes the pointer events of a group's handles:
// enter and leave (hover), and down, drag and up (resizing, which also focuses
// the handle for keys). It returns none for events that are not this group's,
// forged handles, a disabled group and events that change nothing.
pub fn resizable_panels_event(config ResizablePanelsConfig, event string) ?ResizablePanelsStep {
	if !config.enabled {
		return none
	}
	pointer := parse_pointer_event(event)?
	part := component_action_part(config.id, pointer.action)?
	if !part.starts_with('handle:') || config.panels.len == 0 {
		return none
	}
	handle := component_parse_index(part['handle:'.len..], config.panels.len - 1)?
	layout := resizable_panels_layout(config) or { return none }
	position := resizable_order_position(layout.order, handle)
	if position < 0 || position >= layout.order.len - 1 {
		return none
	}
	current := config.state
	match pointer.phase {
		'enter', 'leave' {
			hovered := if pointer.phase == 'enter' {
				handle
			} else if current.hovered == handle {
				-1
			} else {
				current.hovered
			}
			if hovered == current.hovered {
				return none
			}
			return ResizablePanelsStep{
				kind:   .hover
				state:  ResizableState{
					...current
					hovered: hovered
				}
				handle: handle
			}
		}
		'down' {
			coordinate := resizable_axis_coordinate(config.axis, pointer)
			if !component_finite(coordinate) {
				return none
			}
			slots := resizable_slots(config)
			lines := math.max(layout.order.len - 1, 0)
			available := math.max(resizable_extent(config) - f64(lines), 0)
			stored := resizable_stored_sizes(config, slots, layout.collapsed, available)
			return ResizablePanelsStep{
				kind:   .resize_start
				state:  ResizableState{
					...resizable_with(current, resizable_stored_after(slots, layout.sizes,
						layout.collapsed, stored, layout.collapsed, layout.sizes), layout.collapsed,
						ResizableDrag{
							handle:    handle
							start:     coordinate
							sizes:     layout.sizes
							stored:    stored
							collapsed: layout.collapsed
						})
					focused:       handle
					focus_visible: false
				}
				handle: handle
			}
		}
		'drag', 'up' {
			drag := current.drag
			coordinate := resizable_axis_coordinate(config.axis, pointer)
			if drag.handle != handle || !component_finite(coordinate)
				|| drag.sizes.len != config.panels.len || drag.collapsed.len != config.panels.len {
				return none
			}
			slots := resizable_slots(config)
			delta := coordinate - drag.start
			moved := drag.moved || delta != 0
			sizes, collapsed := resizable_drag_sizes(slots, drag.sizes, drag.collapsed,
				layout.order, position, delta, true)
			stored := resizable_stored_after(slots, sizes, collapsed, drag.stored, drag.collapsed,
				drag.sizes)
			changed := stored != current.sizes || collapsed != layout.collapsed
			if pointer.phase == 'drag' {
				if !changed && moved == drag.moved {
					return none
				}
				return ResizablePanelsStep{
					kind:   resizable_collapse_kind(layout.collapsed, collapsed, .resize)
					state:  resizable_with(current, stored, collapsed, ResizableDrag{
						...drag
						moved: moved
					})
					handle: handle
					panel:  resizable_toggled_panel(layout.collapsed, collapsed)
				}
			}
			return ResizablePanelsStep{
				kind:   .resize_end
				state:  resizable_with(current, stored, collapsed, ResizableDrag{})
				handle: handle
				panel:  resizable_toggled_panel(layout.collapsed, collapsed)
			}
		}
		else {
			return none
		}
	}
}

fn resizable_toggled_panel(before []bool, after []bool) int {
	for i in 0 .. math.min(before.len, after.len) {
		if before[i] != after[i] {
			return i
		}
	}
	return -1
}

fn resizable_collapse_kind(before []bool, after []bool, otherwise ResizablePanelsEventKind) ResizablePanelsEventKind {
	panel := resizable_toggled_panel(before, after)
	if panel < 0 {
		return otherwise
	}
	return if after[panel] { .collapse } else { .expand }
}

// resizable_panels_toggle collapses a collapsible panel, or restores a collapsed
// one to the size it had. The space goes to (or comes from) the panels after it
// first, then the panels before it, nearest first. It returns none for a panel
// that cannot collapse, is hidden, or cannot get its minimum back.
pub fn resizable_panels_toggle(config ResizablePanelsConfig, panel int) ?ResizableState {
	if panel < 0 || panel >= config.panels.len || !config.panels[panel].collapsible
		|| !config.panels[panel].visible {
		return none
	}
	layout := resizable_panels_layout(config) or { return none }
	slots := resizable_slots(config)
	position := resizable_order_position(layout.order, panel)
	lines := math.max(layout.order.len - 1, 0)
	available := math.max(resizable_extent(config) - f64(lines), 0)
	stored := resizable_stored_sizes(config, slots, layout.collapsed, available)
	mut sizes := layout.sizes.clone()
	mut collapsed := layout.collapsed.clone()
	slot := slots[panel]
	trailing := layout.order[position + 1..].clone()
	mut leading := []int{}
	for n := position - 1; n >= 0; n-- {
		leading << layout.order[n]
	}
	if collapsed[panel] {
		restore := math.min(math.max(stored[panel], slot.min), slot.max)
		want := math.max(restore - slot.collapsed_size, 0)
		needed := math.max(slot.min - slot.collapsed_size, 0)
		capacity := resizable_total_capacity(slots, sizes, collapsed, trailing, false) +
			resizable_total_capacity(slots, sizes, collapsed, leading, false)
		if capacity < needed {
			return none
		}
		mut taken := resizable_move(slots, mut sizes, collapsed, trailing, want, false)
		taken += resizable_move(slots, mut sizes, collapsed, leading, want - taken, false)
		collapsed[panel] = false
		sizes[panel] = slot.collapsed_size + taken
	} else {
		freed := sizes[panel] - slot.collapsed_size
		collapsed[panel] = true
		sizes[panel] = slot.collapsed_size
		mut left := freed - resizable_move(slots, mut sizes, collapsed, trailing, freed, true)
		left -= resizable_move(slots, mut sizes, collapsed, leading, left, true)
		if left > 1e-9 {
			sizes = resizable_fit_sizes(slots, sizes, collapsed, available)
		}
	}
	return resizable_with(config.state, resizable_stored_after(slots, sizes, collapsed,
		stored, layout.collapsed, layout.sizes), collapsed, config.state.drag)
}

// resizable_panels_key resizes with the keyboard through the focused handle
// (a handle is focused when it is pressed): the arrows along the group's axis
// move it by `step` (five steps with Shift), Home and End move it as far as the
// panels allow, Enter collapses or restores a collapsible panel beside it (the
// one before it first), and Escape clears the focus. It returns none for keys
// it leaves alone, so consume the key only when it returns a step.
pub fn resizable_panels_key(config ResizablePanelsConfig, event KeyEvent) ?ResizablePanelsStep {
	current := config.state
	if !config.enabled || current.focused < 0 || current.focused >= config.panels.len || event.cmd
		|| event.ctrl || event.alt || current.drag.active() {
		return none
	}
	layout := resizable_panels_layout(config) or { return none }
	handle := current.focused
	position := resizable_order_position(layout.order, handle)
	if position < 0 || position >= layout.order.len - 1 {
		return none
	}
	if event.code == .escape {
		return ResizablePanelsStep{
			kind:   .focus
			state:  ResizableState{
				...current
				focused:       -1
				focus_visible: false
			}
			handle: handle
		}
	}
	if event.code in [.enter, .kp_enter] {
		next := layout.order[position + 1]
		target := if config.panels[handle].collapsible { handle } else { next }
		toggled := resizable_panels_toggle(config, target) or { return none }
		return ResizablePanelsStep{
			kind:   if toggled.collapsed[target] { .collapse } else { .expand }
			state:  ResizableState{
				...toggled
				focus_visible: true
			}
			handle: handle
			panel:  target
		}
	}
	step := if event.shift { config.step * 5 } else { config.step }
	horizontal := config.axis == .horizontal
	delta := match event.code {
		.left {
			if horizontal { -step } else { 0.0 }
		}
		.right {
			if horizontal { step } else { 0.0 }
		}
		.up {
			if horizontal { 0.0 } else { -step }
		}
		.down {
			if horizontal { 0.0 } else { step }
		}
		.home { -resizable_far }
		.end { resizable_far }
		else { 0.0 }
	}
	if delta == 0 {
		return none
	}
	slots := resizable_slots(config)
	lines := math.max(layout.order.len - 1, 0)
	available := math.max(resizable_extent(config) - f64(lines), 0)
	stored := resizable_stored_sizes(config, slots, layout.collapsed, available)
	sizes, collapsed := resizable_drag_sizes(slots, layout.sizes, layout.collapsed, layout.order,
		position, delta, false)
	next_sizes := resizable_stored_after(slots, sizes, collapsed, stored, layout.collapsed,
		layout.sizes)
	if next_sizes == stored && current.focus_visible {
		return none
	}
	return ResizablePanelsStep{
		kind:   if next_sizes == stored { .focus } else { .resize }
		state:  ResizableState{
			...resizable_with(current, next_sizes, collapsed, current.drag)
			focus_visible: true
		}
		handle: handle
	}
}
