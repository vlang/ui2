// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The dock area after GPUI Kit's Dock (crates/component/src/dock). Its chrome
// rules are taken from tab_panel.rs: the dock toggle buttons sit in the center's
// first and last groups and in the bottom dock's first group, a closed bottom
// dock stays as a strip of tabs that opens it again, a group of one panel shows
// a title bar instead of tabs, zooming is offered in the panel menu with a
// toolbar button to zoom back out, and a dock's last panel offers no close. The
// controlled model, geometry, events and drawing are new UI2 code. See
// third_party/gpui-kit.
module ui2

import math

// DockPanel describes one panel the application can put in a dock area. The
// layout names panels by id; the area takes their titles and capabilities from
// here and asks DockAreaConfig.content for what they show.
pub struct DockPanel {
pub:
	id       string // Required: the stable name saved layouts use. Never change it.
	title    string
	icon     string // A symbol name shown before the title.
	closable bool = true
	zoomable bool = true
	// zoom_button shows a zoom button in the tab bar; zooming is always in the
	// panel menu.
	zoom_button bool
	// title_bar lets a group holding only this panel show a title bar instead
	// of a tab (with DockPanelStyle.auto).
	title_bar bool = true
	// menu_items are the panel's own rows at the top of its menu. Choosing one
	// reports a menu_item event with its id. Ids starting with `dock:` are the
	// area's own.
	menu_items []DropdownMenuItem
}

// DockPanelBuildFn builds the content of the panel `panel` for its
// content-local frame, rect(0, 0, width, height).
pub type DockPanelBuildFn = fn (panel string, frame Rect) Element

pub enum DockPanelStyle {
	auto // A group with one panel shows a title bar; more show tabs.
	tabs // Every group shows tabs.
}

// DockResizeDrag remembers a dock edge or group divider drag. The decoder fills
// it in on the press; it stays in the state until the release.
pub struct DockResizeDrag {
pub:
	handle string // '' when nothing is being dragged.
	start  f64    // Window coordinate of the press along the handle's axis.
	size   f64    // A dock edge: the dock's size at the press.
	sizes  []f64  // A group divider: the region's group sizes at the press.
	moved  bool
}

pub fn (drag DockResizeDrag) active() bool {
	return drag.handle.len > 0
}

// DockAreaState is a dock area's transient state, next to the DockLayout the
// application saves. Store both from every DockAreaEvent.
pub struct DockAreaState {
pub:
	drag          DockResizeDrag
	hovered       string // The handle under the pointer.
	focused       string // The handle keys act on; set by pressing it.
	focus_visible bool
	current       string // The panel last activated: its tab carries the accent.
	menu_panel    string // The panel whose menu is open.
	menu          DropdownMenuState
}

pub struct DockAreaConfig {
pub:
	id     string // Required.
	frame  Rect
	layout DockLayout
	state  DockAreaState
	panels []DockPanel
	// content builds the displayed panel of every group.
	content        DockPanelBuildFn = unsafe { nil }
	panel_style    DockPanelStyle
	toggle_buttons bool = true // Buttons that open and close the docks.
	close_buttons  bool = true // A close button on every closable tab.
	// locked freezes the arrangement: no closing, moving or splitting. Docks
	// still open, close and resize.
	locked      bool
	side_size   f64           = 240 // A side dock's width while its layout size is 0.
	bottom_size f64           = 200 // The bottom dock's height while its layout size is 0.
	min_dock    f64           = 120 // Dragging a dock below half of this closes it.
	min_center  f64           = 160 // The center keeps at least this width and height.
	min_group   f64           = 80
	step        f64           = 10 // Keyboard resizing step; Shift moves five steps.
	empty_text  string        = 'No open panels'
	enabled     bool          = true
	size        ComponentSize = .medium
	theme       ComponentTheme
}

pub enum DockGroupKind {
	tabs  // A tab bar over the displayed panel.
	title // A title bar over the group's only panel.
	strip // A closed bottom dock: its tabs, no content.
	empty // A center without panels.
}

pub struct DockTabLayout {
pub:
	panel string
	frame Rect // Area-local; zero for a tab that does not fit.
	close Rect // Area-local; zero without a close button.
	shown bool
}

pub struct DockToolLayout {
pub:
	tool  string // toggle:left, toggle:right, toggle:bottom, zoom or menu.
	frame Rect   // Area-local.
}

// DockGroupLayout is where a tab group draws, in area-local points.
pub struct DockGroupLayout {
pub:
	placement DockPlacement
	index     int // The group in its region; -1 for the strip and the empty center.
	kind      DockGroupKind
	frame     Rect
	bar       Rect
	content   Rect
	panel     string // The panel displayed; '' for the strip and the empty center.
	tabs      []DockTabLayout
	tools     []DockToolLayout
	leading   f64 = -1 // x of the line after the leading tools.
	trailing  f64 = -1 // x of the line before the trailing tools.
}

// DockHandleLayout is a dock edge (left, right, bottom) or a divider between
// two groups (split:<placement>:<index>).
pub struct DockHandleLayout {
pub:
	name  string
	axis  Orientation // The direction it resizes along.
	line  f64         // Area-local position of its line along the axis.
	frame Rect        // Its grab band.
}

// DockAreaLayout is a dock area laid out in its frame, in area-local points.
pub struct DockAreaLayout {
pub:
	left    Rect
	right   Rect
	center  Rect
	bottom  Rect
	groups  []DockGroupLayout
	handles []DockHandleLayout
	lines   []Rect // Separators that do not resize.
	zoomed  bool
}

pub enum DockAreaEventKind {
	activate     // A tab was clicked; the panel is displayed and current.
	close        // A panel was closed.
	move         // A panel moved to another region.
	split        // A panel moved into a new group of its own.
	toggle_dock  // A dock opened or closed.
	zoom         // A group zoomed in or out.
	resize_start // A handle was pressed; it is now focused.
	resize       // A dock or a group was resized.
	resize_end   // The drag ended: a good moment to save the layout.
	hover        // The pointer entered or left a handle.
	focus        // The focused handle or its indicator changed.
	menu         // The panel menu opened, closed or moved its highlight.
	menu_item    // A row from DockPanel.menu_items was chosen: see `item`.
}

// DockAreaEvent is what a dock area event did, with the layout and the state
// after it. Store both.
pub struct DockAreaEvent {
pub:
	kind      DockAreaEventKind
	panel     string
	placement DockPlacement
	item      string
	layout    DockLayout
	state     DockAreaState
}

struct DockMetrics {
	bar     f64
	pad     f64
	gap     f64
	icon    f64
	font    f64
	close   f64
	tool    f64
	glyph   f64
	min_tab f64
	max_tab f64
}

fn dock_metrics(size ComponentSize) DockMetrics {
	return match size {
		.small {
			DockMetrics{
				bar:     28
				pad:     8
				gap:     4
				icon:    12
				font:    12
				close:   14
				tool:    20
				glyph:   12
				min_tab: 56
				max_tab: 180
			}
		}
		.medium {
			DockMetrics{
				bar:     34
				pad:     10
				gap:     6
				icon:    14
				font:    13
				close:   16
				tool:    24
				glyph:   14
				min_tab: 64
				max_tab: 220
			}
		}
		.large {
			DockMetrics{
				bar:     40
				pad:     12
				gap:     8
				icon:    16
				font:    14
				close:   18
				tool:    28
				glyph:   16
				min_tab: 72
				max_tab: 260
			}
		}
	}
}

// dock_area_menu_id is the id of the panel menu a dock area draws.
pub fn dock_area_menu_id(id string) string {
	return component_part_id(id, 'menu')
}

fn dock_hex(id string) string {
	return id.bytes().hex()
}

// dock_area_panel_from_hex decodes the panel an action names, which must be in
// the layout. Only the lowercase hex the area writes is accepted.
fn dock_area_panel_from_hex(layout DockLayout, text string) ?string {
	if text.len == 0 || text.len % 2 != 0 {
		return none
	}
	mut out := []u8{cap: text.len / 2}
	for i := 0; i < text.len; i += 2 {
		if (text[i] >= `A` && text[i] <= `F`) || (text[i + 1] >= `A` && text[i + 1] <= `F`) {
			return none
		}
		high := dock_hex_value(text[i])
		low := dock_hex_value(text[i + 1])
		if high < 0 || low < 0 {
			return none
		}
		out << u8(high * 16 + low)
	}
	panel := out.bytestr()
	dock_layout_find(layout, panel)?
	return panel
}

// dock_area_panel returns the description of a panel, or a plain one titled
// with its id for a panel the application did not describe.
pub fn dock_area_panel(config DockAreaConfig, id string) DockPanel {
	for panel in config.panels {
		if panel.id == id {
			return panel
		}
	}
	return DockPanel{
		id:    id
		title: id
	}
}

fn dock_area_title(panel DockPanel) string {
	return if panel.title.len > 0 { panel.title } else { panel.id }
}

fn dock_area_validate(config DockAreaConfig) ! {
	component_validate_id(config.id)!
	component_validate_frame(config.frame)!
	for value in [config.side_size, config.bottom_size, config.min_dock, config.min_center,
		config.min_group] {
		if !component_finite(value) || value < 0 {
			return error('dock area sizes must be finite and non-negative')
		}
	}
	if !component_finite(config.step) || config.step <= 0 {
		return error('dock area step must be finite and positive')
	}
	mut ids := map[string]bool{}
	for panel in config.panels {
		if panel.id.len == 0 || panel.id in ids {
			return error('dock panel ids must be non-empty and unique')
		}
		ids[panel.id] = true
	}
}

// dock_area_can_close reports whether a panel offers to close: it must be
// closable, the area unlocked, and it must not be the last panel of a dock.
pub fn dock_area_can_close(config DockAreaConfig, panel string) bool {
	layout := dock_layout_normalized(config.layout)
	at := dock_layout_find(layout, panel) or { return false }
	return !config.locked && dock_area_panel(config, panel).closable
		&& (at.placement == .center || layout.region(at.placement).panel_count() > 1)
}

// ── Geometry ────────────────────────────────────────────────────────

fn dock_want(size f64, fallback f64, min_size f64) f64 {
	return math.max(if size > 0 { size } else { fallback }, min_size)
}

// dock_squeeze fits two dock sizes into room: first from what each has above
// the minimum, in proportion, then from both evenly in proportion to size.
fn dock_squeeze(a f64, b f64, room f64, min_size f64) (f64, f64) {
	total := a + b
	if total <= room {
		return a, b
	}
	over := total - room
	ea := math.max(a - min_size, 0)
	eb := math.max(b - min_size, 0)
	if ea + eb >= over {
		return a - over * ea / (ea + eb), b - over * eb / (ea + eb)
	}
	a2 := a - ea
	b2 := b - eb
	rest := a2 + b2
	if rest <= 0 {
		return 0, 0
	}
	scale := math.max(rest - (over - ea - eb), 0) / rest
	return a2 * scale, b2 * scale
}

fn dock_side_widths(config DockAreaConfig, layout DockLayout) (f64, f64) {
	left_open := dock_layout_is_open(layout, .left)
	right_open := dock_layout_is_open(layout, .right)
	lw := if left_open {
		dock_want(layout.left.size, config.side_size, config.min_dock)
	} else {
		0.0
	}
	rw := if right_open {
		dock_want(layout.right.size, config.side_size, config.min_dock)
	} else {
		0.0
	}
	mut lines := 0.0
	if left_open {
		lines++
	}
	if right_open {
		lines++
	}
	room := math.max(config.frame.width - lines - config.min_center, 0)
	a, b := dock_squeeze(lw, rw, room, config.min_dock)
	return math.round(a), math.round(b)
}

fn dock_group_slots(config DockAreaConfig, count int) []ResizableSlot {
	return []ResizableSlot{len: count, init: ResizableSlot{
		min:     config.min_group
		max:     math.max_f64
		visible: true
	}}
}

// dock_region_sizes is how long each group of a region is along the region's
// split when the region has `extent` points.
fn dock_region_sizes(config DockAreaConfig, region DockRegion, extent f64) []f64 {
	count := region.groups.len
	if count == 0 {
		return []f64{}
	}
	available := math.max(extent - f64(count - 1), 0)
	slots := dock_group_slots(config, count)
	collapsed := []bool{len: count}
	initial := resizable_initial_sizes(slots, region.groups.map(it.size), collapsed, available)
	return resizable_fit_sizes(slots, initial, collapsed, available)
}

fn dock_axis_extent(axis Orientation, frame Rect) f64 {
	return if axis == .horizontal { frame.width } else { frame.height }
}

fn dock_region_layout(config DockAreaConfig, layout DockLayout, placement DockPlacement, frame Rect, m DockMetrics) ([]DockGroupLayout, []DockHandleLayout) {
	region := layout.region(placement)
	axis := placement.split_axis()
	horizontal := axis == .horizontal
	sizes := dock_region_sizes(config, region, dock_axis_extent(axis, frame))
	order := []int{len: sizes.len, init: index}
	segments := resizable_segments(sizes, order, if horizontal { frame.x } else { frame.y })
	mut groups := []DockGroupLayout{cap: segments.len}
	mut handles := []DockHandleLayout{}
	for g, segment in segments {
		group_frame := if horizontal {
			rect(segment.start, frame.y, segment.length, frame.height)
		} else {
			rect(frame.x, segment.start, frame.width, segment.length)
		}
		groups << dock_group_layout(config, layout, placement, g, group_frame, m, false)
		if segment.line >= 0 {
			handles << DockHandleLayout{
				name:  'split:${placement.name()}:${g}'
				axis:  axis
				line:  segment.line
				frame: if horizontal {
					resize_handle_frame(axis, segment.line, frame.y, frame.height, .straddle)
				} else {
					resize_handle_frame(axis, segment.line, frame.x, frame.width, .straddle)
				}
			}
		}
	}
	return groups, handles
}

// dock_area_layout lays a dock area out: the side docks take the full height,
// the bottom dock sits under the center between them, each region's groups are
// side by side (center, bottom) or stacked (side docks), and a one-point line
// separates every two neighbors. A zoomed group fills the area alone.
pub fn dock_area_layout(config DockAreaConfig) !DockAreaLayout {
	dock_area_validate(config)!
	return dock_area_place(config, dock_layout_normalized(config.layout))
}

fn dock_area_place(config DockAreaConfig, layout DockLayout) DockAreaLayout {
	w := config.frame.width
	h := config.frame.height
	m := dock_metrics(config.size)
	if at := dock_layout_find(layout, layout.zoomed) {
		full := rect(0, 0, w, h)
		return DockAreaLayout{
			center: full
			groups: [dock_group_layout(config, layout, at.placement, at.group, full, m, true)]
			zoomed: true
		}
	}
	lw, rw := dock_side_widths(config, layout)
	col_x := if lw > 0 { lw + 1 } else { 0.0 }
	col_right := if rw > 0 { w - rw - 1 } else { w }
	col_w := math.max(col_right - col_x, 0)
	has_bottom := layout.bottom.has_panels()
	bottom_open := has_bottom && layout.bottom.open
	mut bh := 0.0
	if bottom_open {
		bh = math.round(math.min(dock_want(layout.bottom.size, config.bottom_size, config.min_dock),
			math.max(h - 1 - config.min_center, 0)))
	} else if has_bottom {
		bh = math.min(m.bar, math.max(h - 1, 0))
	}
	bottom_line := if bh > 0 { 1.0 } else { 0.0 }
	center_h := math.max(h - bh - bottom_line, 0)
	center := rect(col_x, 0, col_w, center_h)
	bottom := if bh > 0 { rect(col_x, center_h + 1, col_w, bh) } else { rect(0, 0, 0, 0) }
	left := if lw > 0 { rect(0, 0, lw, h) } else { rect(0, 0, 0, 0) }
	right := if rw > 0 { rect(w - rw, 0, rw, h) } else { rect(0, 0, 0, 0) }
	mut groups := []DockGroupLayout{}
	mut handles := []DockHandleLayout{}
	mut lines := []Rect{}
	if layout.center.groups.len == 0 {
		groups << dock_special_group(config, layout, .center, center, m, .empty)
	} else {
		found, splits := dock_region_layout(config, layout, .center, center, m)
		groups << found
		handles << splits
	}
	if left.width > 0 {
		found, splits := dock_region_layout(config, layout, .left, left, m)
		groups << found
		handles << splits
	}
	if right.width > 0 {
		found, splits := dock_region_layout(config, layout, .right, right, m)
		groups << found
		handles << splits
	}
	if bh > 0 {
		if bottom_open {
			found, splits := dock_region_layout(config, layout, .bottom, bottom, m)
			groups << found
			handles << splits
			handles << DockHandleLayout{
				name:  'bottom'
				axis:  .vertical
				line:  center_h
				frame: resize_handle_frame(.vertical, center_h, col_x, col_w, .straddle)
			}
		} else {
			groups << dock_special_group(config, layout, .bottom, bottom, m, .strip)
			lines << rect(col_x, center_h, col_w, 1)
		}
	}
	if lw > 0 {
		handles << DockHandleLayout{
			name:  'left'
			axis:  .horizontal
			line:  lw
			frame: resize_handle_frame(.horizontal, lw, 0, h, .straddle)
		}
	}
	if rw > 0 {
		handles << DockHandleLayout{
			name:  'right'
			axis:  .horizontal
			line:  w - rw - 1
			frame: resize_handle_frame(.horizontal, w - rw - 1, 0, h, .straddle)
		}
	}
	// A drag that closed its dock keeps the dock's edge where the dock went, so
	// the drag carries on and can open the dock again.
	dragged := config.state.drag.handle
	if dragged in ['left', 'right', 'bottom'] && dragged !in handles.map(it.name)
		&& layout.region(dock_edge_placement(dragged)).has_panels() {
		handles << match dragged {
			'left' {
				DockHandleLayout{
					name:  'left'
					axis:  .horizontal
					line:  0
					frame: resize_handle_frame(.horizontal, 0, 0, h, .leading)
				}
			}
			'right' {
				DockHandleLayout{
					name:  'right'
					axis:  .horizontal
					line:  math.max(w - 1, 0)
					frame: resize_handle_frame(.horizontal, math.max(w - 1, 0), 0, h, .trailing)
				}
			}
			else {
				DockHandleLayout{
					name:  'bottom'
					axis:  .vertical
					line:  center_h
					frame: resize_handle_frame(.vertical, center_h, col_x, col_w, .straddle)
				}
			}
		}
	}
	return DockAreaLayout{
		left:    left
		right:   right
		center:  center
		bottom:  bottom
		groups:  groups
		handles: handles
		lines:   lines
	}
}

// dock_leading_tools are the toggle buttons at the start of a tab bar: the
// left dock's in the center's first group, the bottom dock's in its own first
// group (or its strip).
fn dock_leading_tools(config DockAreaConfig, layout DockLayout, placement DockPlacement, index int, zoomed bool) []string {
	if !config.toggle_buttons || zoomed || index > 0 {
		return []string{}
	}
	if placement == .center && layout.left.has_panels() {
		return ['toggle:left']
	}
	if placement == .bottom {
		return ['toggle:bottom']
	}
	return []string{}
}

// dock_trailing_tools are the buttons at the end of a tab bar: zoom, the panel
// menu, and the right dock's toggle in the center's last group.
fn dock_trailing_tools(config DockAreaConfig, layout DockLayout, placement DockPlacement, index int, zoomed bool, panel string) []string {
	mut tools := []string{}
	if panel.len > 0 {
		info := dock_area_panel(config, panel)
		if zoomed || (info.zoom_button && info.zoomable) {
			tools << 'zoom'
		}
		if dock_area_menu_items(config, panel).len > 0 {
			tools << 'menu'
		}
	}
	last := index < 0 || index == layout.center.groups.len - 1
	if config.toggle_buttons && !zoomed && placement == .center && last
		&& layout.right.has_panels() {
		tools << 'toggle:right'
	}
	return tools
}

struct DockBarSpace {
	tools    []DockToolLayout
	start    f64
	end      f64
	leading  f64 = -1
	trailing f64 = -1
}

// dock_bar_space places the tool buttons at both ends of a bar and returns the
// space left between them for tabs or a title.
fn dock_bar_space(bar Rect, leading []string, trailing []string, m DockMetrics) DockBarSpace {
	pad := math.max(math.round((m.bar - m.tool) / 2), 2)
	y := bar.y + math.round((bar.height - m.tool) / 2)
	mut tools := []DockToolLayout{}
	mut x := bar.x
	mut leading_line := -1.0
	if leading.len > 0 {
		x += pad
		for tool in leading {
			tools << DockToolLayout{
				tool:  tool
				frame: rect(x, y, m.tool, m.tool)
			}
			x += m.tool + 2
		}
		x += pad - 2
		leading_line = x
		x += 1
	}
	mut end := bar.x + bar.width
	mut trailing_line := -1.0
	if trailing.len > 0 {
		end -= pad
		mut placed := []DockToolLayout{}
		for i := trailing.len - 1; i >= 0; i-- {
			end -= m.tool
			placed << DockToolLayout{
				tool:  trailing[i]
				frame: rect(end, y, m.tool, m.tool)
			}
			end -= 2
		}
		end -= pad - 2
		trailing_line = end - 1
		end -= 1
		tools << placed.reverse()
	}
	return DockBarSpace{
		tools:    tools
		start:    x
		end:      math.max(end, x)
		leading:  leading_line
		trailing: trailing_line
	}
}

// dock_tab_width fits an icon, the title and a close button. The title gets
// some slack over the estimate: a native label insets its text and truncates a
// title that is a point too wide.
fn dock_tab_width(panel DockPanel, close bool, m DockMetrics) f64 {
	icon := if panel.icon.len > 0 { m.icon + m.gap } else { 0.0 }
	right := if close { m.gap / 2 + m.close + m.pad / 2 } else { m.pad }
	width := m.pad + icon + component_text_width_estimate(dock_area_title(panel), m.font) + 6 +
		right
	return math.ceil(math.min(math.max(width, m.min_tab), m.max_tab))
}

// dock_tab_layouts sizes the tabs to their titles, shrinks them toward the
// minimum when they do not fit, and leaves out the ones that still do not,
// keeping the displayed tab in view.
fn dock_tab_layouts(config DockAreaConfig, panels []string, active int, closes []bool, space DockBarSpace, bar Rect, m DockMetrics) []DockTabLayout {
	mut widths := []f64{cap: panels.len}
	for i, id in panels {
		widths << dock_tab_width(dock_area_panel(config, id), closes[i], m)
	}
	available := space.end - space.start
	mut total := 0.0
	for width in widths {
		total += width
	}
	if total > available {
		mut shrinkable := 0.0
		for width in widths {
			shrinkable += math.max(width - m.min_tab, 0)
		}
		if shrinkable > 0 {
			factor := math.min((total - available) / shrinkable, 1)
			for i in 0 .. widths.len {
				widths[i] = math.floor(widths[i] - math.max(widths[i] - m.min_tab, 0) * factor)
			}
		}
	}
	mut first := 0
	if active >= 0 {
		for first < active {
			mut span := 0.0
			for i in first .. active + 1 {
				span += widths[i]
			}
			if span <= available + 0.5 {
				break
			}
			first++
		}
	}
	mut tabs := []DockTabLayout{cap: panels.len}
	mut x := space.start
	for i, id in panels {
		fits := i >= first && x + widths[i] <= space.end + 0.5
		if !fits {
			tabs << DockTabLayout{
				panel: id
			}
			continue
		}
		frame := rect(x, bar.y, widths[i], bar.height)
		close := if closes[i] {
			rect(x + widths[i] - m.pad / 2 - m.close, bar.y + math.round((bar.height - m.close) / 2),
				m.close, m.close)
		} else {
			rect(0, 0, 0, 0)
		}
		tabs << DockTabLayout{
			panel: id
			frame: frame
			close: close
			shown: true
		}
		x += widths[i]
	}
	return tabs
}

fn dock_group_layout(config DockAreaConfig, layout DockLayout, placement DockPlacement, index int, frame Rect, m DockMetrics, zoomed bool) DockGroupLayout {
	group := layout.region(placement).groups[index]
	panel := group.active_panel()
	info := dock_area_panel(config, panel)
	bar := rect(frame.x, frame.y, frame.width, math.min(m.bar, frame.height))
	content := rect(frame.x, bar.y + bar.height, frame.width, math.max(frame.height - bar.height,
		0))
	space := dock_bar_space(bar, dock_leading_tools(config, layout, placement, index, zoomed),
		dock_trailing_tools(config, layout, placement, index, zoomed, panel), m)
	kind := if config.panel_style == .auto && group.panels.len == 1 && info.title_bar {
		DockGroupKind.title
	} else {
		DockGroupKind.tabs
	}
	tabs := if kind == .title {
		[
			DockTabLayout{
				panel: panel
				frame: rect(space.start, bar.y, space.end - space.start, bar.height)
				shown: true
			},
		]
	} else {
		closes := group.panels.map(config.close_buttons && dock_area_can_close(config, it))
		dock_tab_layouts(config, group.panels, dock_clamp_index(group.active, group.panels.len),
			closes, space, bar, m)
	}
	return DockGroupLayout{
		placement: placement
		index:     index
		kind:      kind
		frame:     frame
		bar:       bar
		content:   content
		panel:     panel
		tabs:      tabs
		tools:     space.tools
		leading:   space.leading
		trailing:  space.trailing
	}
}

// dock_special_group lays out the strip of a closed bottom dock (all of its
// panels as tabs, which open it) or an empty center (just its toggles).
fn dock_special_group(config DockAreaConfig, layout DockLayout, placement DockPlacement, frame Rect, m DockMetrics, kind DockGroupKind) DockGroupLayout {
	bar := rect(frame.x, frame.y, frame.width, math.min(m.bar, frame.height))
	content := rect(frame.x, bar.y + bar.height, frame.width, math.max(frame.height - bar.height,
		0))
	space := dock_bar_space(bar, dock_leading_tools(config, layout, placement, 0, false),
		dock_trailing_tools(config, layout, placement, -1, false, ''), m)
	mut tabs := []DockTabLayout{}
	if kind == .strip {
		mut panels := []string{}
		for group in layout.bottom.groups {
			panels << group.panels
		}
		tabs = dock_tab_layouts(config, panels, -1, []bool{len: panels.len}, space, bar,
			m)
	}
	return DockGroupLayout{
		placement: placement
		index:     -1
		kind:      kind
		frame:     frame
		bar:       bar
		content:   if kind == .strip { rect(0, 0, 0, 0) } else { content }
		tabs:      tabs
		tools:     space.tools
		leading:   space.leading
		trailing:  space.trailing
	}
}

// ── Drawing ─────────────────────────────────────────────────────────

fn dock_bar_color(theme ComponentTheme) u32 {
	return popover_blend(theme.background, theme.muted, 0.6)
}

fn dock_line(frame Rect, color u32, key string) Element {
	return Element{
		...view('', frame, BoxStyle{ bg: color }, []Element{})
		key: key
	}
}

fn dock_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

fn dock_local(frame Rect, origin Rect) Rect {
	return rect(frame.x - origin.x, frame.y - origin.y, frame.width, frame.height)
}

// dock_panel_glyph draws the toggle icon of a dock: a window outline with the
// dock's pane marked, filled while the dock is open. It is built from boxes so
// that it looks the same on every renderer.
fn dock_panel_glyph(placement DockPlacement, open bool, side f64, m DockMetrics, color u32, bg u32) Element {
	gw := m.glyph + 1
	gh := math.round(m.glyph * 0.86)
	outer := rect(math.round((side - gw) / 2), math.round((side - gh) / 2), gw, gh)
	inner := rect(1, 1, gw - 2, gh - 2)
	mut children := [
		Element{
			...view('', inner, BoxStyle{
				bg:     bg
				radius: 1.5
			}, []Element{})
			key: 'inner'
		},
	]
	pane, line := match placement {
		.left {
			w := math.round(inner.width * 0.36)
			rect(1, 1, w, inner.height), rect(1 + w, 1, 1, inner.height)
		}
		.right {
			w := math.round(inner.width * 0.36)
			rect(1 + inner.width - w, 1, w, inner.height), rect(inner.width - w, 1, 1, inner.height)
		}
		else {
			hh := math.round(inner.height * 0.4)
			rect(1, 1 + inner.height - hh, inner.width, hh), rect(1, inner.height - hh, inner.width,
				1)
		}
	}
	children << dock_line(line, color, 'divider')
	if open {
		children << Element{
			...view('', pane, BoxStyle{
				bg:      color
				opacity: 0.55
			}, []Element{})
			key: 'pane'
		}
	}
	return Element{
		...view('', outer, BoxStyle{
			bg:     color
			radius: 2.5
		}, children)
		key: 'glyph'
	}
}

// dock_zoom_glyph draws a window outline to zoom in, and two overlapping ones
// to zoom out, from boxes like the toggle icons.
fn dock_zoom_glyph(zoomed bool, side f64, m DockMetrics, color u32, bg u32) Element {
	g := math.round(m.glyph * 0.8)
	outer := rect(math.round((side - g) / 2), math.round((side - g) / 2), g, g)
	window := fn [color, bg] (frame Rect, key string) Element {
		return Element{
			...view('', frame, BoxStyle{
				bg:     color
				radius: 1.5
			}, [
				view('', rect(1, 2, math.max(frame.width - 2, 0), math.max(frame.height - 3, 0)),
					BoxStyle{
						bg:     bg
						radius: 0.5
					}, []Element{}),
			])
			key: key
		}
	}
	if !zoomed {
		return Element{
			...view('', outer, BoxStyle{ transparent: true }, [
				window(rect(0, 0, g, g), 'window'),
			])
			key: 'glyph'
		}
	}
	small := math.round(g * 0.72)
	return Element{
		...view('', outer, BoxStyle{ transparent: true }, [
			window(rect(g - small, 0, small, small), 'back'),
			window(rect(0, g - small, small, small), 'front'),
		])
		key: 'glyph'
	}
}

fn dock_tool_element(config DockAreaConfig, layout DockLayout, group DockGroupLayout, tool DockToolLayout, m DockMetrics) Element {
	theme := config.theme
	frame := dock_local(tool.frame, group.bar)
	glyph := m.glyph
	icon_frame := rect(math.round((frame.width - glyph) / 2), math.round((frame.height - glyph) / 2),
		glyph, glyph)
	color := theme.muted_foreground
	bar_bg := dock_bar_color(theme)
	panel := group.panel
	menu_open := tool.tool == 'menu' && config.state.menu.open && config.state.menu_panel == panel
		&& panel.len > 0
	mut action := ''
	mut tip := ''
	mut child := Element{}
	match tool.tool {
		'menu' {
			action = 'menu:' + dock_hex(panel)
			tip = 'More'
			child = dock_symbol('ellipsis', icon_frame, color)
		}
		'zoom' {
			zoomed := layout.zoomed.len > 0
			action = 'zoom:' + dock_hex(panel)
			tip = if zoomed { 'Zoom Out' } else { 'Zoom In' }
			child = dock_zoom_glyph(zoomed, frame.width, m, color, bar_bg)
		}
		else {
			placement := dock_placement_from_name(tool.tool['toggle:'.len..]) or { DockPlacement.left }
			open := dock_layout_is_open(layout, placement)
			action = tool.tool
			tip = if open { 'Close ${placement.title()}' } else { 'Open ${placement.title()}' }
			child = dock_panel_glyph(placement, open, frame.width, m, color, if menu_open {
				theme.muted
			} else {
				bar_bg
			})
		}
	}
	return Element{
		...button_view(component_part_id(config.id, action), frame, if menu_open {
			BoxStyle{
				bg:     theme.muted
				radius: 4
			}
		} else {
			BoxStyle{
				transparent: true
				radius:      4
			}
		}, [child])
		key:                 'tool:' + tool.tool
		tooltip:             tip
		cursor:              cursor_pointing_hand
		accessibility_label: tip
		accessibility_value: if menu_open { 'expanded' } else { '' }
	}
}

fn dock_tab_element(config DockAreaConfig, group DockGroupLayout, tab DockTabLayout, m DockMetrics) Element {
	theme := config.theme
	info := dock_area_panel(config, tab.panel)
	title := dock_area_title(info)
	frame := dock_local(tab.frame, group.bar)
	selected := group.kind != .strip && tab.panel == group.panel
	current := selected && config.state.current == tab.panel
	color := if selected { theme.foreground } else { theme.muted_foreground }
	// Every tab draws the line on its right; the one on a tab's left is the tab
	// before it, the leading tools' separator or the group's edge.
	mut children := []Element{}
	divider_height := if selected { frame.height } else { frame.height - 1 }
	children << dock_line(rect(frame.width - 1, 0, 1, divider_height), theme.border, 'right')
	if current {
		children << dock_line(rect(0, 0, frame.width, 2), theme.primary, 'accent')
	}
	mut x := m.pad
	if info.icon.len > 0 {
		children << Element{
			...dock_symbol(info.icon, rect(x, math.round((frame.height - m.icon) / 2), m.icon,
				m.icon), if selected { theme.primary } else { theme.muted_foreground })
			key: 'icon'
		}
		x += m.icon + m.gap
	}
	right := if tab.close.width > 0 {
		frame.width - (tab.close.x - tab.frame.x) + m.gap / 2
	} else {
		m.pad
	}
	children << Element{
		...label('', title, rect(x, 0, math.max(frame.width - x - right, 0), frame.height),
			TextStyle{
				color: color
				size:  m.font
			})
		key: 'title'
	}
	if tab.close.width > 0 {
		close := dock_local(tab.close, tab.frame)
		mark := math.round(m.close * 0.55)
		children << Element{
			...button_view(component_part_id(config.id, 'close:' + dock_hex(tab.panel)), close,
				BoxStyle{
					transparent: true
					radius:      4
				}, [
					dock_symbol('xmark', rect(math.round((close.width - mark) / 2), math.round((close.height - mark) / 2),
						mark, mark), theme.muted_foreground),
				])
			key:                 'close'
			tooltip:             'Close'
			cursor:              cursor_pointing_hand
			accessibility_label: 'Close ${title}'
		}
	}
	return Element{
		...with_button_behavior(view(component_part_id(config.id, 'tab:' + dock_hex(tab.panel)),
			frame, if selected {
				BoxStyle{
					bg: theme.background
				}
			} else {
				BoxStyle{
					transparent: true
				}
			}, children))
		key:                 'tab:' + tab.panel
		accessibility_role:  'tab'
		accessibility_label: title
		accessibility_value: if selected { 'selected' } else { 'not selected' }
	}
}

fn dock_title_element(config DockAreaConfig, group DockGroupLayout, tab DockTabLayout, m DockMetrics) Element {
	theme := config.theme
	info := dock_area_panel(config, tab.panel)
	title := dock_area_title(info)
	frame := dock_local(tab.frame, group.bar)
	mut children := []Element{}
	mut x := m.pad
	if info.icon.len > 0 {
		children << Element{
			...dock_symbol(info.icon, rect(x, math.round((frame.height - m.icon) / 2), m.icon,
				m.icon), theme.muted_foreground)
			key: 'icon'
		}
		x += m.icon + m.gap
	}
	children << Element{
		...label('', if group.placement == .center { title } else { title.to_upper() }, rect(x,
			0, math.max(frame.width - x - m.pad / 2, 0),
			frame.height), TextStyle{
			color: if config.state.current == tab.panel {
				theme.foreground
			} else {
				theme.muted_foreground
			}
			size:  m.font - 2
			bold:  true
		})
		key: 'title'
	}
	return Element{
		...with_button_behavior(view(component_part_id(config.id, 'tab:' + dock_hex(tab.panel)),
			frame, BoxStyle{ transparent: true }, children))
		key:                 'tab:' + tab.panel
		accessibility_role:  'tab'
		accessibility_label: title
		accessibility_value: 'selected'
	}
}

fn dock_group_key(group DockGroupLayout) string {
	return match group.kind {
		.strip { 'strip' }
		.empty { 'empty' }
		else { '${group.placement.name()}:${group.index}' }
	}
}

fn dock_bar_element(config DockAreaConfig, layout DockLayout, group DockGroupLayout, m DockMetrics) Element {
	theme := config.theme
	bar := group.bar
	mut children := [
		dock_line(rect(0, bar.height - 1, bar.width, 1), theme.border, 'bottom'),
	]
	if group.leading >= 0 {
		children << dock_line(rect(group.leading - bar.x, 0, 1, bar.height - 1), theme.border,
			'leading')
	}
	if group.trailing >= 0 {
		children << dock_line(rect(group.trailing - bar.x, 0, 1, bar.height - 1), theme.border,
			'trailing')
	}
	for tab in group.tabs {
		if !tab.shown {
			continue
		}
		children << if group.kind == .title {
			dock_title_element(config, group, tab, m)
		} else {
			dock_tab_element(config, group, tab, m)
		}
	}
	for tool in group.tools {
		children << dock_tool_element(config, layout, group, tool, m)
	}
	key := dock_group_key(group)
	return Element{
		...view(component_part_id(config.id, 'bar:' + key), bar, BoxStyle{
			bg: dock_bar_color(theme)
		}, children)
		key:                 'bar:' + key
		accessibility_role:  'tablist'
		accessibility_label: match group.kind {
			.strip { 'Bottom Dock' }
			.empty { 'Center' }
			else { group.placement.title() }
		}
	}
}

fn dock_content_element(config DockAreaConfig, group DockGroupLayout, m DockMetrics) Element {
	theme := config.theme
	frame := group.content
	if group.kind == .empty {
		return Element{
			...view(component_part_id(config.id, 'content:empty'), frame, BoxStyle{
				bg: theme.background
			}, [
				label('', config.empty_text, rect(0, 0, frame.width, frame.height), TextStyle{
					color: theme.muted_foreground
					size:  m.font
					align: .center
				}),
			])
			key: 'content:empty'
		}
	}
	local := rect(0, 0, frame.width, frame.height)
	content := if voidptr(config.content) != unsafe { nil } && frame.width > 0 && frame.height > 0 {
		[config.content(group.panel, local)]
	} else {
		[]Element{}
	}
	return Element{
		...view(component_part_id(config.id, 'content:' + dock_hex(group.panel)), frame,
			BoxStyle{ bg: theme.background }, content)
		key:                 'content:' + group.panel
		hidden:              frame.width <= 0 || frame.height <= 0
		accessibility_role:  'group'
		accessibility_label: dock_area_title(dock_area_panel(config, group.panel))
	}
}

fn dock_handle_phase(state DockAreaState, name string) ResizeHandlePhase {
	if state.drag.handle == name {
		return if state.drag.moved { .dragging } else { .pressed }
	}
	return if state.hovered == name && !state.drag.active() { .hovered } else { .idle }
}

fn dock_handle_label(name string) string {
	return match name {
		'left' { 'Resize Left Dock' }
		'right' { 'Resize Right Dock' }
		'bottom' { 'Resize Bottom Dock' }
		else { 'Resize Panels' }
	}
}

// dock_area draws a dock area: every region's tab groups with their tab bars
// and displayed panels, the handles on the dock edges and between groups, and
// the panel menu when it is open. Pass every event to dock_area_event and keys
// to dock_area_key, and store the layout and the state they return.
pub fn dock_area(config DockAreaConfig) !Element {
	dock_area_validate(config)!
	layout := dock_layout_normalized(config.layout)
	geometry := dock_area_place(config, layout)
	m := dock_metrics(config.size)
	theme := config.theme
	mut children := []Element{}
	for group in geometry.groups {
		if group.kind != .strip {
			children << dock_content_element(config, group, m)
		}
	}
	for group in geometry.groups {
		children << dock_bar_element(config, layout, group, m)
	}
	for i, line in geometry.lines {
		children << dock_line(line, theme.border, 'line:${i}')
	}
	for handle in geometry.handles {
		children << Element{
			...resize_handle_element(ResizeHandleConfig{
				id:                  component_part_id(config.id, 'handle:' + handle.name)
				frame:               handle.frame
				axis:                handle.axis
				phase:               dock_handle_phase(config.state, handle.name)
				focus_visible:       config.state.focus_visible
					&& config.state.focused == handle.name
				enabled:             config.enabled
				accessibility_label: dock_handle_label(handle.name)
				theme:               theme
			})
			key: 'handle:' + handle.name
		}
	}
	panel := config.state.menu_panel
	if config.state.menu.open && panel.len > 0 {
		for group in geometry.groups {
			if group.panel != panel {
				continue
			}
			for tool in group.tools {
				if tool.tool == 'menu' {
					children << dropdown_menu(DropdownMenuConfig{
						id:     dock_area_menu_id(config.id)
						state:  config.state.menu
						items:  dock_area_menu_items(config, panel)
						anchor: tool.frame
						window: rect(0, 0, config.frame.width, config.frame.height)
						align:  .end
						label:  dock_area_title(dock_area_panel(config, panel))
						size:   config.size
						theme:  theme
					})!
				}
			}
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ bg: theme.background }, children)
		accessibility_role:  'group'
		accessibility_label: 'Dock area'
	})
}

// ── Menu ────────────────────────────────────────────────────────────

// dock_area_menu_items are the rows of a panel's menu: the panel's own rows,
// then zooming, moving to each other region and splitting into a new group,
// then closing, as far as the panel and the area allow them.
pub fn dock_area_menu_items(config DockAreaConfig, panel string) []DropdownMenuItem {
	layout := dock_layout_normalized(config.layout)
	at := dock_layout_find(layout, panel) or { return []DropdownMenuItem{} }
	info := dock_area_panel(config, panel)
	mut items := info.menu_items.clone()
	if info.zoomable {
		if items.len > 0 {
			items << dropdown_menu_separator()
		}
		zoomed := if z := dock_layout_find(layout, layout.zoomed) {
			z.placement == at.placement && z.group == at.group
		} else {
			false
		}
		items << DropdownMenuItem{
			id:    'dock:zoom'
			label: if zoomed { 'Zoom Out' } else { 'Zoom In' }
			icon:  if zoomed {
				'arrow.down.right.and.arrow.up.left'
			} else {
				'arrow.up.and.down.and.arrow.left.and.right'
			}
		}
	}
	if !config.locked {
		mut moves := []DropdownMenuItem{}
		for placement in dock_placements() {
			if placement != at.placement {
				moves << dropdown_menu_item('dock:move:${placement.name()}', 'Move to ${placement.title()}')
			}
		}
		if layout.region(at.placement).groups[at.group].panels.len > 1 {
			moves << dropdown_menu_item('dock:split', if at.placement.split_axis() == .horizontal {
				'Split Right'
			} else {
				'Split Down'
			})
		}
		if items.len > 0 {
			items << dropdown_menu_separator()
		}
		items << moves
	}
	if dock_area_can_close(config, panel) {
		if items.len > 0 {
			items << dropdown_menu_separator()
		}
		items << DropdownMenuItem{
			id:    'dock:close'
			label: 'Close'
			icon:  'xmark'
		}
	}
	return items
}

// ── Events ──────────────────────────────────────────────────────────

fn dock_closed_menu(state DockAreaState) DockAreaState {
	return DockAreaState{
		...state
		menu_panel: ''
		menu:       DropdownMenuState{}
	}
}

fn dock_event(kind DockAreaEventKind, panel string, layout DockLayout, state DockAreaState) DockAreaEvent {
	placement := if at := dock_layout_find(layout, panel) {
		at.placement
	} else {
		DockPlacement.center
	}
	return DockAreaEvent{
		kind:      kind
		panel:     panel
		placement: placement
		layout:    layout
		state:     state
	}
}

// dock_area_apply carries out a panel command (`dock:zoom`, `dock:close`,
// `dock:split`, `dock:move:<placement>`), the way the panel menu does.
fn dock_area_apply(config DockAreaConfig, layout DockLayout, state DockAreaState, panel string, command string) ?DockAreaEvent {
	info := dock_area_panel(config, panel)
	match command {
		'dock:zoom' {
			if !info.zoomable && layout.zoomed.len == 0 {
				return none
			}
			next := dock_layout_zoom(layout, panel)?
			return dock_event(.zoom, panel, next, state)
		}
		'dock:close' {
			if !dock_area_can_close(config, panel) {
				return none
			}
			next := dock_layout_close(layout, panel)?
			return dock_event(.close, panel, next, DockAreaState{
				...state
				current: if state.current == panel { '' } else { state.current }
			})
		}
		'dock:split' {
			if config.locked {
				return none
			}
			next := dock_layout_split(layout, panel)?
			return dock_event(.split, panel, next, DockAreaState{
				...state
				current: panel
			})
		}
		else {
			if !command.starts_with('dock:move:') || config.locked {
				return none
			}
			placement := dock_placement_from_name(command['dock:move:'.len..])?
			next := dock_layout_move(layout, panel, placement)?
			return DockAreaEvent{
				...dock_event(.move, panel, next, DockAreaState{
					...state
					current: panel
				})
				placement: placement
			}
		}
	}
}

// dock_area_event decodes what a dock area emits: tab clicks (activate),
// close buttons, the panel menu (its button, its rows and their highlight), the
// zoom and dock toggle buttons, and the pointer on the dock edges and group
// dividers (hover and resizing). It returns none for events that are not this
// area's, forged or malformed actions, a disabled area, commands the panel or a
// locked area does not allow, and events that change nothing.
pub fn dock_area_event(config DockAreaConfig, event string) ?DockAreaEvent {
	if !config.enabled {
		return none
	}
	layout := dock_layout_normalized(config.layout)
	current := config.state
	if current.menu.open && current.menu_panel.len > 0 {
		items := dock_area_menu_items(config, current.menu_panel)
		if step := dropdown_menu_update(dock_area_menu_id(config.id), items, current.menu,
			event)
		{
			next_state := if step.state.open {
				DockAreaState{
					...current
					menu: step.state
				}
			} else {
				dock_closed_menu(current)
			}
			if step.chosen {
				if step.item.id.starts_with('dock:') {
					return dock_area_apply(config, layout, next_state, current.menu_panel,
						step.item.id)
				}
				return DockAreaEvent{
					...dock_event(.menu_item, current.menu_panel, layout, next_state)
					item: step.item.id
				}
			}
			return dock_event(.menu, current.menu_panel, layout, next_state)
		}
	}
	if pointer := parse_pointer_event(event) {
		return dock_area_pointer(config, layout, pointer)
	}
	part := component_action_part(config.id, event)?
	if part.starts_with('tab:') {
		panel := dock_area_panel_from_hex(layout, part['tab:'.len..])?
		next := dock_layout_activate(layout, panel) or { layout }
		if next == layout && current.current == panel {
			return none
		}
		return dock_event(.activate, panel, next, DockAreaState{
			...dock_closed_menu(current)
			current: panel
		})
	}
	if part.starts_with('close:') {
		panel := dock_area_panel_from_hex(layout, part['close:'.len..])?
		return dock_area_apply(config, layout, dock_closed_menu(current), panel, 'dock:close')
	}
	if part.starts_with('zoom:') {
		panel := dock_area_panel_from_hex(layout, part['zoom:'.len..])?
		return dock_area_apply(config, layout, dock_closed_menu(current), panel, 'dock:zoom')
	}
	if part.starts_with('menu:') {
		panel := dock_area_panel_from_hex(layout, part['menu:'.len..])?
		if current.menu.open && current.menu_panel == panel {
			return dock_event(.menu, panel, layout, dock_closed_menu(current))
		}
		if dock_area_menu_items(config, panel).len == 0 {
			return none
		}
		return dock_event(.menu, panel, layout, DockAreaState{
			...current
			menu_panel: panel
			menu:       DropdownMenuState{}.opened()
		})
	}
	if part.starts_with('toggle:') {
		placement := dock_placement_from_name(part['toggle:'.len..])?
		next := dock_layout_toggle(layout, placement)?
		return DockAreaEvent{
			kind:      .toggle_dock
			placement: placement
			layout:    next
			state:     dock_closed_menu(current)
		}
	}
	return none
}

// dock_split_handle decodes `split:<placement>:<index>` against the layout.
fn dock_split_handle(layout DockLayout, name string) ?(DockPlacement, int) {
	if !name.starts_with('split:') {
		return none
	}
	rest := name['split:'.len..]
	colon := rest.index(':') or { return none }
	placement := dock_placement_from_name(rest[..colon])?
	count := layout.region(placement).groups.len
	if count < 2 {
		return none
	}
	index := component_parse_index(rest[colon + 1..], count - 2)?
	return placement, index
}

fn dock_region_frame(geometry DockAreaLayout, placement DockPlacement) Rect {
	return match placement {
		.center { geometry.center }
		.left { geometry.left }
		.right { geometry.right }
		.bottom { geometry.bottom }
	}
}

fn dock_edge_size(geometry DockAreaLayout, name string) f64 {
	return match name {
		'left' { geometry.left.width }
		'right' { geometry.right.width }
		else { geometry.bottom.height }
	}
}

// dock_edge_limit is the largest size a dock edge drag may give its dock: the
// center keeps its minimum beside the other docks.
fn dock_edge_limit(config DockAreaConfig, geometry DockAreaLayout, name string) f64 {
	if name == 'left' || name == 'right' {
		other := if name == 'left' { geometry.right.width } else { geometry.left.width }
		other_line := if other > 0 { 1.0 } else { 0.0 }
		return config.frame.width - other - other_line - 1 - config.min_center
	}
	return config.frame.height - 1 - config.min_center
}

fn dock_edge_placement(name string) DockPlacement {
	return match name {
		'left' { DockPlacement.left }
		'right' { DockPlacement.right }
		else { DockPlacement.bottom }
	}
}

// dock_edge_resized is the layout after moving a dock edge `delta` points
// from where a dock of `start` points had it. Moving it more than half the
// minimum below the minimum closes the dock and keeps its size for reopening.
fn dock_edge_resized(config DockAreaConfig, layout DockLayout, geometry DockAreaLayout, name string, start f64, delta f64, snap bool) DockLayout {
	grow := if name == 'left' { delta } else { -delta }
	wanted := start + grow
	placement := dock_edge_placement(name)
	if snap && wanted < config.min_dock / 2 {
		return dock_layout_set_open(dock_layout_resize(layout, placement, start), placement,
			false)
	}
	limit := math.max(dock_edge_limit(config, geometry, name), config.min_dock)
	size := math.round(math.min(math.max(wanted, config.min_dock), limit))
	return dock_layout_set_open(dock_layout_resize(layout, placement, size), placement,
		true)
}

fn dock_split_resized(config DockAreaConfig, layout DockLayout, placement DockPlacement, divider int, start []f64, delta f64) DockLayout {
	region := layout.region(placement)
	if start.len != region.groups.len {
		return layout
	}
	slots := dock_group_slots(config, start.len)
	order := []int{len: start.len, init: index}
	sizes, _ := resizable_drag_sizes(slots, start, []bool{len: start.len}, order, divider,
		delta, false)
	mut groups := []DockGroup{cap: region.groups.len}
	for g, group in region.groups {
		groups << DockGroup{
			...group
			size: math.round(sizes[g] * 100) / 100
		}
	}
	return layout.with_region(placement, DockRegion{
		...region
		groups: groups
	})
}

fn dock_area_pointer(config DockAreaConfig, layout DockLayout, pointer PointerEvent) ?DockAreaEvent {
	part := component_action_part(config.id, pointer.action)?
	if !part.starts_with('handle:') {
		return none
	}
	name := part['handle:'.len..]
	geometry := dock_area_place(config, layout)
	mut found := false
	mut axis := Orientation.horizontal
	for handle in geometry.handles {
		if handle.name == name {
			found = true
			axis = handle.axis
		}
	}
	if !found {
		return none
	}
	current := config.state
	coordinate := if axis == .horizontal { pointer.x } else { pointer.y }
	match pointer.phase {
		'enter', 'leave' {
			hovered := if pointer.phase == 'enter' {
				name
			} else if current.hovered == name {
				''
			} else {
				current.hovered
			}
			if hovered == current.hovered {
				return none
			}
			return DockAreaEvent{
				kind:   .hover
				layout: layout
				state:  DockAreaState{
					...current
					hovered: hovered
				}
			}
		}
		'down' {
			if !component_finite(coordinate) {
				return none
			}
			mut sizes := []f64{}
			if placement, _ := dock_split_handle(layout, name) {
				frame := dock_region_frame(geometry, placement)
				sizes = dock_region_sizes(config, layout.region(placement), dock_axis_extent(placement.split_axis(),
					frame))
			}
			return DockAreaEvent{
				kind:   .resize_start
				layout: layout
				state:  DockAreaState{
					...dock_closed_menu(current)
					drag:          DockResizeDrag{
						handle: name
						start:  coordinate
						size:   dock_edge_size(geometry, name)
						sizes:  sizes
					}
					focused:       name
					focus_visible: false
				}
			}
		}
		'drag', 'up' {
			drag := current.drag
			if drag.handle != name || !component_finite(coordinate) {
				return none
			}
			delta := coordinate - drag.start
			next := if placement, index := dock_split_handle(layout, name) {
				dock_split_resized(config, layout, placement, index, drag.sizes, delta)
			} else {
				dock_edge_resized(config, layout, geometry, name, drag.size, delta, true)
			}
			moved := drag.moved || delta != 0
			if pointer.phase == 'drag' {
				if next == layout && moved == drag.moved {
					return none
				}
				return DockAreaEvent{
					kind:   .resize
					layout: next
					state:  DockAreaState{
						...current
						drag: DockResizeDrag{
							...drag
							moved: moved
						}
					}
				}
			}
			return DockAreaEvent{
				kind:   .resize_end
				layout: next
				state:  DockAreaState{
					...current
					drag: DockResizeDrag{}
				}
			}
		}
		else {
			return none
		}
	}
}

// dock_area_key handles keys for a dock area: while the panel menu is open,
// the menu's keys (dropdown_menu_key); on a focused handle (pressed last), the
// arrows along its axis move it by `step` (five steps with Shift), Home and End
// to its limits, Enter opens or closes a dock edge's dock, and Escape clears
// the focus; otherwise Escape zooms out. It returns none for keys it leaves
// alone, so consume the key only when it returns an event.
pub fn dock_area_key(config DockAreaConfig, event KeyEvent) ?DockAreaEvent {
	if !config.enabled || event.cmd || event.ctrl || event.alt {
		return none
	}
	layout := dock_layout_normalized(config.layout)
	current := config.state
	if current.menu.open && current.menu_panel.len > 0 {
		items := dock_area_menu_items(config, current.menu_panel)
		step := dropdown_menu_key(items, current.menu, event)?
		next_state := if step.state.open {
			DockAreaState{
				...current
				menu: step.state
			}
		} else {
			dock_closed_menu(current)
		}
		if step.chosen {
			if step.item.id.starts_with('dock:') {
				return dock_area_apply(config, layout, next_state, current.menu_panel, step.item.id)
			}
			return DockAreaEvent{
				...dock_event(.menu_item, current.menu_panel, layout, next_state)
				item: step.item.id
			}
		}
		return dock_event(.menu, current.menu_panel, layout, next_state)
	}
	geometry := dock_area_place(config, layout)
	name := current.focused
	mut axis := Orientation.horizontal
	mut found := false
	for handle in geometry.handles {
		if handle.name == name {
			found = true
			axis = handle.axis
		}
	}
	if !found || current.drag.active() {
		if event.code == .escape && layout.zoomed.len > 0 {
			return dock_event(.zoom, layout.zoomed, DockLayout{
				...layout
				zoomed: ''
			}, current)
		}
		return none
	}
	if event.code == .escape {
		return DockAreaEvent{
			kind:   .focus
			layout: layout
			state:  DockAreaState{
				...current
				focused:       ''
				focus_visible: false
			}
		}
	}
	split_placement, split_index := dock_split_handle(layout, name) or { DockPlacement.center, -1 }
	if event.code in [.enter, .kp_enter] {
		if split_index >= 0 {
			return none
		}
		placement := dock_edge_placement(name)
		next := dock_layout_toggle(layout, placement)?
		return DockAreaEvent{
			kind:      .toggle_dock
			placement: placement
			layout:    next
			state:     DockAreaState{
				...current
				focused:       ''
				focus_visible: false
			}
		}
	}
	step := if event.shift { config.step * 5 } else { config.step }
	horizontal := axis == .horizontal
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
	next := if split_index >= 0 {
		frame := dock_region_frame(geometry, split_placement)
		sizes := dock_region_sizes(config, layout.region(split_placement), dock_axis_extent(split_placement.split_axis(),
			frame))
		dock_split_resized(config, layout, split_placement, split_index, sizes, delta)
	} else {
		dock_edge_resized(config, layout, geometry, name, dock_edge_size(geometry, name),
			delta, false)
	}
	if next == layout && current.focus_visible {
		return none
	}
	return DockAreaEvent{
		kind:   if next == layout { .focus } else { .resize }
		layout: next
		state:  DockAreaState{
			...current
			focus_visible: true
		}
	}
}
