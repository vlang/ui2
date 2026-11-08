module ui2

import math

// StatusBarConfig describes a status bar: three regions of labels, commands,
// separators and custom slots, usually along the bottom of a window or pane.
pub struct StatusBarConfig {
pub:
	id    string // Needed once the bar has a command.
	frame Rect
	// leading is pinned to the start (GPUI Kit's `left`) and trailing to the
	// end (its `right`). The center (its `child`) fills the room between them:
	// centered there when both ends have items, against the end when only
	// leading has, and from the start otherwise.
	leading  []BarItem
	center   []BarItem
	trailing []BarItem
	enabled  bool = true
	// hovered is the command under the pointer; keep it with status_bar_hover_from_event.
	hovered string
	label   string = 'Status' // The accessible name.
	style   BarStyle
	size    ComponentSize = .medium
	theme   ComponentTheme
}

struct StatusBarLayout {
	metrics  BarMetrics
	leading  []BarPlacement
	center   []BarPlacement
	trailing []BarPlacement
}

fn bars_any_shown(placements []BarPlacement) bool {
	for placement in placements {
		if placement.shown {
			return true
		}
	}
	return false
}

// status_bar_layout packs the ends first, leading before trailing, and gives
// the center what they leave. When room runs out, each end loses the items
// nearest the middle of the bar.
fn status_bar_layout(config StatusBarConfig) StatusBarLayout {
	m := bar_metrics(.status_bar, config.size)
	width := config.frame.width
	pad := math.min(m.padding, width / 2)
	leading := bars_pack(config.leading, pad, width - 2 * pad, m, false)
	_, leading_end := bars_used(leading)
	start := if bars_any_shown(leading) { leading_end + m.gap } else { pad }
	trailing := bars_pack_end(config.trailing, width - pad, math.max(width - pad - start, 0.0),
		m, false)
	trailing_start, _ := bars_used(trailing)
	stop := if bars_any_shown(trailing) { trailing_start - m.gap } else { width - pad }
	room := math.max(stop - start, 0.0)
	mut center := bars_pack(config.center, start, room, m, false)
	low, high := bars_used(center)
	slack := math.max(room - (high - low), 0.0)
	if config.leading.len > 0 && config.trailing.len > 0 {
		center = bars_shift(center, slack / 2)
	} else if config.leading.len > 0 {
		center = bars_shift(center, slack)
	}
	return StatusBarLayout{
		metrics:  m
		leading:  leading
		center:   center
		trailing: trailing
	}
}

fn status_bar_items(config StatusBarConfig) []BarItem {
	mut items := config.leading.clone()
	items << config.center
	items << config.trailing
	return items
}

// status_bar_background is the bar's default fill: the background tinted
// toward the muted color, so the bar reads apart from the content above it.
fn status_bar_background(theme ComponentTheme) u32 {
	return choice_mix(theme.background, theme.muted, 0.75)
}

// status_bar draws a status bar. Its text is small and muted, as GPUI Kit's
// is; commands are ghost buttons that emit bar_item_action(id, item id) (or
// their action_id) for status_bar_item_from_action.
pub fn status_bar(config StatusBarConfig) !Element {
	component_validate_frame(config.frame)!
	all := status_bar_items(config)
	if bars_has_commands(all) {
		component_validate_id(config.id)!
	}
	bars_validate_items(all, 'status bar')!
	layout := status_bar_layout(config)
	theme := config.theme
	fill := config.style.background or { status_bar_background(theme) }
	edges := if config.style.edges == .auto { BarEdges.top } else { config.style.edges }
	mut children := bars_surface(config.frame.width, config.frame.height, fill, config.style.gradient,
		config.style.border or { bars_divider(theme) }, edges, config.style.radius, config.style.shadow)
	base := BarLook{
		bar_id:     config.id
		theme:      theme
		metrics:    layout.metrics
		foreground: config.style.foreground or {
			choice_mix(theme.muted_foreground, theme.foreground, 0.4)
		}
		muted:      theme.muted_foreground
		surface:    bars_surface_color(fill, config.style.gradient, fill)
		enabled:    config.enabled
		hovered:    config.hovered
	}
	breadth := config.frame.height
	children << bars_items(config.leading, layout.leading, breadth, BarLook{
		...base
		region: 'leading:'
	})
	children << bars_items(config.center, layout.center, breadth, BarLook{
		...base
		region: 'center:'
	})
	children << bars_items(config.trailing, layout.trailing, breadth, BarLook{
		...base
		region: 'trailing:'
	})
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'status'
		accessibility_label: config.label
	})
}

// status_bar_item_from_action returns the command an action came from, or none
// for foreign actions, disabled commands and a disabled bar.
pub fn status_bar_item_from_action(config StatusBarConfig, action string) ?BarItem {
	return bars_item_from_action(config.id, status_bar_items(config), config.enabled, action)
}

// status_bar_hover_from_event returns the next `hovered` value when the
// pointer enters or leaves a command, and none for every other event.
pub fn status_bar_hover_from_event(config StatusBarConfig, event string) ?string {
	return bars_hover_from_event(config.id, status_bar_items(config), map[string]string{},
		config.hovered, event)
}

// status_bar_item_frame is where an item is drawn, in the coordinates of the
// bar's parent (a menu's anchor), or none when it is not shown.
pub fn status_bar_item_frame(config StatusBarConfig, item_id string) ?Rect {
	layout := status_bar_layout(config)
	m := layout.metrics
	mut frames := map[string]Rect{}
	breadth := config.frame.height
	bars_item_frames(config.leading, layout.leading, breadth, m, false, mut frames)
	bars_item_frames(config.center, layout.center, breadth, m, false, mut frames)
	bars_item_frames(config.trailing, layout.trailing, breadth, m, false, mut frames)
	local := frames[item_id] or { return none }
	return rect(config.frame.x + local.x, config.frame.y + local.y, local.width, local.height)
}

// status_bar_overflow lists the commands left out for lack of room.
pub fn status_bar_overflow(config StatusBarConfig) []string {
	layout := status_bar_layout(config)
	mut ids := bars_overflow(config.leading, layout.leading)
	ids << bars_overflow(config.center, layout.center)
	ids << bars_overflow(config.trailing, layout.trailing)
	return ids
}
