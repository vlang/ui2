module ui2

import math

// AttachmentGroupLayout is how a group arranges its attachments.
pub enum AttachmentGroupLayout {
	row  // One row that scrolls sideways: GPUI's AttachmentGroup.
	wrap // Rows that wrap at the frame's width and scroll down.
	list // One attachment per line, chips stretched to the frame's width.
}

// AttachmentGroupConfig describes a group of attachments, such as the files
// waiting in a chat composer or those sent with a message.
pub struct AttachmentGroupConfig {
pub:
	id    string // Required: names the scroll and every item.
	frame Rect
	// items are the attachments. Each item's id is its key in the group (it
	// must be non-empty and unique); its frame is ignored, the group places it.
	items  []AttachmentConfig
	layout AttachmentGroupLayout
	// status is the status of every item whose own status is none.
	status AttachmentStatus = .complete
	gap    f64              = 12 // Between attachments.
	// hovered is the key of the item under the pointer, kept from hover events.
	hovered string
	// edge_fade fades a row's edges into this color while they hide
	// attachments; pass the color behind the row. A row reports where it is
	// scrolled through on_scroll: keep scroll_offset with
	// scroll_horizontal_offset(attachment_group_scroll_id(id)).
	edge_fade     ?u32
	scroll_offset f64
	enabled       bool = true // False disables every item's controls.
	reduce_motion bool // For every item.
	// surface is the color behind the group, which items use to round image
	// tiles on the custom renderer; it defaults to the theme's background.
	surface             ?u32
	accessibility_label string = 'Attachments'
	theme               ComponentTheme // For every item.
}

// The space a row leaves above its attachments, as GPUI's does, and below
// them, where the custom renderer, which always shows an overflowing row's
// scroller, draws it clear of the cards.
const attachment_group_padding = 4.0
const attachment_group_scroller = 12.0
// How wide an edge fade is.
const attachment_group_fade = 24.0

pub fn attachment_group_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

// attachment_group_item_id is the element id of the item with key in group id,
// which its controls' actions are named under.
pub fn attachment_group_item_id(id string, key string) string {
	return component_part_id(id, 'item:' + key.bytes().hex())
}

// attachment_group_item is the item as the group builds it: under the group's
// namespace, with the group's theme and switches.
fn attachment_group_item(config AttachmentGroupConfig, item AttachmentConfig, frame Rect) AttachmentConfig {
	return AttachmentConfig{
		...item
		id:            attachment_group_item_id(config.id, item.id)
		frame:         frame
		hovered:       config.hovered.len > 0 && item.id == config.hovered
		enabled:       config.enabled && item.enabled
		reduce_motion: config.reduce_motion || item.reduce_motion
		surface:       config.surface or { config.theme.background }
		theme:         config.theme
	}
}

// attachment_group_frames places the items inside the group's frame, relative
// to it. Cards share a top edge: when any item can be removed, every row
// leaves room above for the remove control's overhang. A list stretches each
// horizontal chip to the frame's width, minus that overhang.
pub fn attachment_group_frames(config AttachmentGroupConfig) []Rect {
	mut reserve := 0.0
	for item in config.items {
		if item.removable {
			reserve = attachment_remove_overhang
		}
	}
	gap := if component_finite(config.gap) { math.max(config.gap, 0) } else { 0.0 }
	available := config.frame.width
	mut frames := []Rect{cap: config.items.len}
	mut x := 0.0
	mut y := if config.layout == .row { attachment_group_padding } else { 0.0 }
	mut line := 0.0
	for item in config.items {
		r := attachment_resolve(item, item.status or { config.status })
		over := if item.removable { attachment_remove_overhang } else { 0.0 }
		mut width, mut height := attachment_natural_size_with(item, r)
		if config.layout == .list && item.axis == .horizontal {
			width = math.max(available - reserve + over, 0)
			height = attachment_metrics(item.size).height + over
		}
		if config.layout == .list {
			frames << rect(0, y + reserve - over, width, height)
			y += height - over + reserve + gap
			continue
		}
		if config.layout == .wrap && x > 0 && x + width > available {
			x = 0
			y += line + gap
			line = 0
		}
		frames << rect(x, y + reserve - over, width, height)
		x += width + gap
		line = math.max(line, height - over + reserve)
	}
	return frames
}

// attachment_group_content_size is how much room the placed items take, which
// a frame of that size shows without scrolling.
pub fn attachment_group_content_size(config AttachmentGroupConfig) (f64, f64) {
	mut width := 0.0
	mut height := 0.0
	for frame in attachment_group_frames(config) {
		width = math.max(width, frame.x + frame.width)
		height = math.max(height, frame.y + frame.height)
	}
	if config.layout == .row && config.items.len > 0 {
		height += attachment_group_scroller
	}
	return width, height
}

// attachment_group_forget stops the animations of items that have left the
// group, which went on running after their elements did.
fn attachment_group_forget(config AttachmentGroupConfig, keys map[string]bool) {
	prefix := component_part_id(config.id, 'item:')
	mut stale := []string{}
	runtime := g_animation_runtime
	runtime.mutex.lock()
	for name, _ in runtime.runs {
		if !name.starts_with(prefix) {
			continue
		}
		digits := name[prefix.len..].all_before(':')
		key := attachment_hex_text(digits) or { '' }
		if key !in keys {
			stale << name
		}
	}
	runtime.mutex.unlock()
	for name in stale {
		clear_animation(name)
	}
}

pub fn attachment_group(config AttachmentGroupConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if !component_finite(config.gap) || config.gap < 0 {
		return error('attachment group gap must be finite and non-negative')
	}
	mut keys := map[string]bool{}
	for item in config.items {
		if item.id.trim_space().len == 0 || item.id in keys {
			return error('attachment group item ids must be non-empty and unique')
		}
		keys[item.id] = true
	}
	attachment_group_forget(config, keys)
	frames := attachment_group_frames(config)
	mut items := []Element{cap: config.items.len}
	for index, item in config.items {
		built := attachment_build(attachment_group_item(config, item, frames[index]), config.status)!
		items << Element{
			...built
			key: item.id
		}
	}
	local := component_local(config.frame)
	content_width, content_height := attachment_group_content_size(config)
	// A row always scrolls, so its offset can be read back; wrapped and listed
	// items scroll only when they overflow, since the custom renderer pads a
	// vertical scroll's content and would show a scroller for a group that fits.
	body := if config.layout == .row || content_height > config.frame.height + 0.5 {
		mode := if config.layout == .row {
			ScrollMode.horizontal_only
		} else {
			ScrollMode.vertical_only
		}
		Element{
			...scroll_with_mode(attachment_group_scroll_id(config.id), local, 0, mode,
				items)
			box: BoxStyle{
				transparent: true
			}
		}
	} else {
		view(attachment_group_scroll_id(config.id), local, BoxStyle{ transparent: true },
			items)
	}
	mut children := [body]
	if color := config.edge_fade {
		overflow := content_width - config.frame.width
		if config.layout == .row && overflow > 1 {
			fade := math.min(attachment_group_fade, config.frame.width / 4)
			height := math.min(content_height, config.frame.height)
			if config.scroll_offset > 1 {
				children << view(component_part_id(config.id, 'fade:leading'), rect(0, 0,
					fade, height), BoxStyle{
					gradient: linear_gradient(0, gradient_stop(color, 0), GradientStop{
						color:    color
						position: 1
						opacity:  0
					})
				}, []Element{})
			}
			if config.scroll_offset < overflow - 1 {
				children << view(component_part_id(config.id, 'fade:trailing'), rect(config.frame.width - fade,
					0, fade, height), BoxStyle{
					gradient: linear_gradient(0, GradientStop{
						color:    color
						position: 0
						opacity:  0
					}, gradient_stop(color, 1))
				}, []Element{})
			}
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'list'
		accessibility_label: config.accessibility_label
		accessibility_value: '${config.items.len} attachments'
	})
}

// attachment_group_event_from_action decodes an action, or a hover event, of
// one of the group's items, against the group it was built from: the event's
// key is the item's. It rejects foreign and malformed actions, items that are
// gone, and everything attachment_event_from_action rejects for the item.
pub fn attachment_group_event_from_action(config AttachmentGroupConfig, action string) ?AttachmentEvent {
	target := if pointer := parse_pointer_event(action) { pointer.action } else { action }
	part := component_action_part(config.id, target) or { return none }
	if !part.starts_with('item:') {
		return none
	}
	digits := part['item:'.len..].all_before(':')
	key := attachment_hex_text(digits) or { return none }
	for item in config.items {
		if item.id == key {
			return attachment_decode(attachment_group_item(config, item, rect(0, 0, 0, 0)),
				key, config.status, action)
		}
	}
	return none
}
