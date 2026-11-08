module ui2

import math

// ToolbarConfig describes a toolbar: a run of commands, labels, separators,
// spacers, custom slots and named groups, laid out along one axis. It is
// transparent and borderless by default, as GPUI Kit's is; the surface around
// it supplies the background unless `style` gives it one.
pub struct ToolbarConfig {
pub:
	id          string
	frame       Rect
	items       []BarItem
	orientation LayoutOrientation = .horizontal
	// enabled false disables every command and the keyboard helper.
	enabled bool = true
	// hovered is the command under the pointer; keep it with toolbar_hover_from_event.
	hovered string
	// focused is the command with keyboard focus, '' while the toolbar has none;
	// it is drawn with a focus ring. Move it with toolbar_key.
	focused string
	label   string // The accessible name, such as "Formatting".
	style   BarStyle
	size    ComponentSize = .medium
	theme   ComponentTheme
}

struct ToolbarLayout {
	metrics    BarMetrics
	vertical   bool
	breadth    f64
	placements []BarPlacement
}

fn toolbar_layout(config ToolbarConfig) ToolbarLayout {
	m := bar_metrics(.toolbar, config.size)
	vertical := config.orientation == .vertical
	length := if vertical { config.frame.height } else { config.frame.width }
	breadth := if vertical { config.frame.width } else { config.frame.height }
	pad := math.min(m.padding, length / 2)
	return ToolbarLayout{
		metrics:    m
		vertical:   vertical
		breadth:    breadth
		placements: bars_pack(config.items, pad, length - 2 * pad, m, vertical)
	}
}

// toolbar draws a toolbar. Each command emits bar_item_action(id, item id)
// (or its own action_id); decode it with toolbar_item_from_action. Commands
// that do not fit are left out from the end: toolbar_overflow lists them so
// they can go in an overflow menu.
pub fn toolbar(config ToolbarConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	bars_validate_items(config.items, 'toolbar')!
	layout := toolbar_layout(config)
	theme := config.theme
	edges := if config.style.edges == .auto { BarEdges.none } else { config.style.edges }
	mut children := bars_surface(config.frame.width, config.frame.height, config.style.background,
		config.style.gradient, config.style.border or { bars_divider(theme) }, edges, config.style.radius,
		config.style.shadow)
	look := BarLook{
		bar_id:     config.id
		theme:      theme
		metrics:    layout.metrics
		foreground: config.style.foreground or { theme.foreground }
		muted:      theme.muted_foreground
		surface:    bars_surface_color(config.style.background, config.style.gradient,
			theme.background)
		enabled:    config.enabled
		hovered:    config.hovered
		focused:    config.focused
		vertical:   layout.vertical
	}
	children << bars_items(config.items, layout.placements, layout.breadth, look)
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'toolbar'
		accessibility_label: config.label
	})
}

// toolbar_item_from_action returns the command an action came from, so the
// application can run it (and flip `selected` for a toggle). It returns none for
// foreign actions, disabled commands and a disabled toolbar.
pub fn toolbar_item_from_action(config ToolbarConfig, action string) ?BarItem {
	return bars_item_from_action(config.id, config.items, config.enabled, action)
}

// toolbar_hover_from_event returns the next `hovered` value when the pointer
// enters or leaves a command, and none for every other event.
pub fn toolbar_hover_from_event(config ToolbarConfig, event string) ?string {
	return bars_hover_from_event(config.id, config.items, map[string]string{}, config.hovered,
		event)
}

// toolbar_item_frame is where an item (a group member too) is drawn, in the
// coordinates of the toolbar's parent: the anchor for a menu a command opens.
// It is none for items that are not shown.
pub fn toolbar_item_frame(config ToolbarConfig, item_id string) ?Rect {
	layout := toolbar_layout(config)
	mut frames := map[string]Rect{}
	bars_item_frames(config.items, layout.placements, layout.breadth, layout.metrics,
		layout.vertical, mut frames)
	local := frames[item_id] or { return none }
	return rect(config.frame.x + local.x, config.frame.y + local.y, local.width, local.height)
}

// toolbar_overflow lists the commands that did not fit, in order.
pub fn toolbar_overflow(config ToolbarConfig) []string {
	return bars_overflow(config.items, toolbar_layout(config).placements)
}

// toolbar_focus_order lists the commands keyboard focus can move between: the
// shown, enabled ones, in visual order. Focus enters a toolbar at the first.
pub fn toolbar_focus_order(config ToolbarConfig) []string {
	if !config.enabled {
		return []string{}
	}
	placements := toolbar_layout(config).placements
	mut order := []string{}
	for index, item in config.items {
		if !placements[index].shown {
			continue
		}
		for member in bars_flatten([item]) {
			if member.kind == .command && member.enabled {
				order << member.id
			}
		}
	}
	return order
}

// ToolbarKeyStep is what a key did: where focus is now ('' when it left the
// toolbar), and the command to run when `activated`.
pub struct ToolbarKeyStep {
pub:
	focused   string
	activated bool
	item      BarItem
}

// toolbar_key is the toolbar's roving focus, after the ARIA toolbar pattern
// GPUI Kit follows. While `focused` names a command, Left and Right (Up and Down
// on a vertical toolbar) move to the previous or next command, wrapping at the
// ends; Home and End go to the first and last; Enter and Space run the focused
// command; Escape lets go of focus. Tab is the application's: clear `focused`
// when focus moves elsewhere. It returns none for keys it leaves alone and for
// moves that change nothing; consume the key otherwise.
pub fn toolbar_key(config ToolbarConfig, event KeyEvent) ?ToolbarKeyStep {
	if !config.enabled || config.focused.len == 0 || event.cmd || event.ctrl || event.alt {
		return none
	}
	if event.code == .escape {
		return ToolbarKeyStep{}
	}
	order := toolbar_focus_order(config)
	if order.len == 0 {
		return none
	}
	position := order.index(config.focused)
	vertical := config.orientation == .vertical
	previous := if vertical { KeyCode.up } else { KeyCode.left }
	next := if vertical { KeyCode.down } else { KeyCode.right }
	mut target := -1
	if event.code == next {
		target = if position < 0 { 0 } else { (position + 1) % order.len }
	} else if event.code == previous {
		target = if position < 0 { order.len - 1 } else { (position + order.len - 1) % order.len }
	} else if event.code == .home {
		target = 0
	} else if event.code == .end {
		target = order.len - 1
	} else if event.code in [.enter, .kp_enter, .space] {
		if position < 0 {
			return none
		}
		for item in bars_flatten(config.items) {
			if item.id == config.focused {
				return ToolbarKeyStep{
					focused:   config.focused
					activated: true
					item:      item
				}
			}
		}
		return none
	} else {
		return none
	}
	if order[target] == config.focused {
		return none
	}
	return ToolbarKeyStep{
		focused: order[target]
	}
}
