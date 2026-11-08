module ui2

import math

// notification_default_width is GPUI Kit's notification width.
pub const notification_default_width = 382.0

pub struct NotificationStackConfig {
pub:
	id    string
	frame Rect // The area the stacks are placed in, usually the window's bounds.
	list  NotificationList
	width f64 = notification_default_width // Clamped to the frame minus its margins.
	// margin keeps the stacks off the edges of frame; gap separates notifications.
	margin f64 = 16
	gap    f64 = 12
	// animate slides notifications in and out. Without it a dismissed notification
	// disappears at once while the list finishes its exit timer.
	animate bool          = true
	size    ComponentSize = .medium
	theme   ComponentTheme
}

struct NotificationMetrics {
	font   f64
	line   f64
	pad_x  f64
	pad_y  f64
	icon   f64
	close  f64
	inset  f64
	gap    f64
	radius f64
	action ComponentMetrics
}

fn notification_metrics(size ComponentSize) NotificationMetrics {
	m := component_metrics(size)
	return NotificationMetrics{
		font:   m.font_size
		line:   math.round(m.font_size * 1.43)
		pad_x:  m.padding * 2
		pad_y:  math.round(m.padding * 1.75)
		icon:   m.font_size + 2
		close:  math.round(m.height * 0.625)
		inset:  math.round(m.padding / 2)
		gap:    m.gap * 2
		radius: m.radius + 2
		action: component_metrics(if size == .large { ComponentSize.medium } else { .small })
	}
}

// NotificationCardLayout places the parts of one notification, card-local.
struct NotificationCardLayout {
	width   f64
	height  f64
	icon    Rect
	title   Rect
	message Rect
	content Rect
	action  Rect
	close   Rect
}

// notification_text_width estimates how wide text renders by character class.
// It is tighter than component_text_width_estimate for Latin text, which would
// leave most notifications with an empty last line, and still errs wide.
fn notification_text_width(text string, font_size f64, bold bool) f64 {
	mut ems := 0.0
	for r in text.runes() {
		ems += if r >= 0x2e80 {
			1.0
		} else if r in [` `, `.`, `,`, `:`, `;`, `'`, `|`, `i`, `j`, `l`, `!`, `I`] {
			0.3
		} else if r in [`f`, `t`, `r`, `(`, `)`, `[`, `]`, `-`, `/`, `"`] {
			0.4
		} else if r in [`m`, `w`] {
			0.85
		} else if r in [`M`, `W`] {
			0.92
		} else if r >= `a` && r <= `z` {
			0.56
		} else if r >= `A` && r <= `Z` {
			0.68
		} else if r >= `0` && r <= `9` {
			0.6
		} else {
			0.62
		}
	}
	return ems * font_size * if bold { 1.07 } else { 1.0 }
}

// notification_line_count estimates how many lines text wraps to in width,
// breaking at spaces and newlines, and inside words too long for a line.
fn notification_line_count(text string, font_size f64, bold bool, width f64) int {
	if text.trim_space().len == 0 {
		return 0
	}
	space := notification_text_width(' ', font_size, bold)
	mut lines := 0
	for paragraph in text.split('\n') {
		lines++
		mut used := 0.0
		for word in paragraph.fields() {
			word_width := notification_text_width(word, font_size, bold)
			if used > 0 {
				if used + space + word_width <= width {
					used += space + word_width
					continue
				}
				lines++
			}
			if width > 0 && word_width > width {
				extra := int(math.ceil(word_width / width)) - 1
				lines += extra
				used = word_width - f64(extra) * width
			} else {
				used = word_width
			}
		}
	}
	return lines
}

fn notification_has_icon(n Notification) bool {
	return n.kind != .plain || n.icon.len > 0
}

fn notification_card_layout(n Notification, width f64, size ComponentSize) NotificationCardLayout {
	nm := notification_metrics(size)
	text_x := nm.pad_x + if notification_has_icon(n) { nm.icon + nm.pad_x / 2 } else { 0.0 }
	// The close button stays visible (GPUI Kit shows it on hover only), so the
	// first line of text keeps clear of the corner it sits in; the lines below
	// it may run on to the padding.
	close := rect(width - nm.inset - nm.close, nm.inset, nm.close, nm.close)
	reserve := nm.close + nm.inset * 2
	mut first_right := width - math.max(nm.pad_x, reserve)
	mut rest_right := width - nm.pad_x
	mut action_width := 0.0
	if n.action.len > 0 {
		action_width = notification_text_width(n.action, nm.action.font_size, false) +
			nm.action.padding * 2 + 4
		first_right = width - reserve - action_width - nm.gap
		rest_right = first_right
	}
	first_width := math.max(first_right - text_x, 0)
	rest_width := math.max(rest_right - text_x, 0)
	message_width := if n.title.len > 0 { rest_width } else { first_width }
	title_height := f64(notification_line_count(n.title, nm.font, true, first_width)) * nm.line
	message_height := f64(notification_line_count(n.message, nm.font, false, message_width)) * nm.line
	content_extent := if n.content.len > 0 && component_finite(n.content_height)
		&& n.content_height > 0 {
		n.content_height
	} else {
		0.0
	}
	content_gap := if content_extent > 0 && title_height + message_height > 0 {
		nm.gap / 2
	} else {
		0.0
	}
	text_height := title_height + message_height + content_gap + content_extent
	action_height := if n.action.len > 0 { nm.action.height } else { 0.0 }
	body := math.max(math.max(text_height, nm.line), action_height)
	height := nm.pad_y * 2 + body
	text_y := nm.pad_y + (body - text_height) / 2
	return NotificationCardLayout{
		width:   width
		height:  height
		icon:    rect(nm.pad_x, text_y + (nm.line - nm.icon) / 2, nm.icon, nm.icon)
		title:   rect(text_x, text_y, first_width, title_height)
		message: rect(text_x, text_y + title_height, message_width, message_height)
		content: rect(text_x, text_y + title_height + message_height + content_gap, rest_width,
			content_extent)
		action:  rect(first_right + nm.gap, (height - action_height) / 2, action_width, action_height)
		close:   close
	}
}

// NotificationStackLayout is one placement's stack: its frame in the coordinate
// space of the config frame's parent, and its notifications top to bottom.
struct NotificationStackLayout {
	placement NotificationPlacement
	frame     Rect
	entries   []NotificationEntry
	slots     []Rect // Stack-local.
	cards     []NotificationCardLayout
}

fn notification_stack_layouts(config NotificationStackConfig) ![]NotificationStackLayout {
	component_validate_frame(config.frame)!
	for value in [config.width, config.margin, config.gap] {
		if !component_finite(value) || value < 0 {
			return error('notification width, margin and gap must be finite and non-negative')
		}
	}
	frame := config.frame
	width := math.max(math.min(config.width, frame.width - config.margin * 2), 0)
	visible := config.list.visible()
	mut layouts := []NotificationStackLayout{}
	for placement in notification_placements {
		mut entries := visible.filter(it.placement == placement
			&& (config.animate || it.phase != .leaving))
		if entries.len == 0 {
			continue
		}
		// The newest notification sits nearest the edge its stack grows from.
		if !notification_anchored_bottom(placement) {
			entries.reverse_in_place()
		}
		mut slots := []Rect{cap: entries.len}
		mut cards := []NotificationCardLayout{cap: entries.len}
		mut y := 0.0
		for index, entry in entries {
			card := notification_card_layout(entry.notification, width, config.size)
			if index > 0 {
				y += config.gap
			}
			slots << rect(0, y, width, card.height)
			cards << card
			y += card.height
		}
		x := match placement {
			.top_left, .left_center, .bottom_left { frame.x + config.margin }
			.top_center, .bottom_center { frame.x + (frame.width - width) / 2 }
			else { frame.x + frame.width - config.margin - width }
		}
		top := match placement {
			.top_left, .top_center, .top_right { frame.y + config.margin }
			.left_center, .right_center { frame.y + (frame.height - y) / 2 }
			else { frame.y + frame.height - config.margin - y }
		}
		layouts << NotificationStackLayout{
			placement: placement
			frame:     rect(x, top, width, y)
			entries:   entries
			slots:     slots
			cards:     cards
		}
	}
	return layouts
}

fn notification_kind_color(theme ComponentTheme, kind NotificationKind) u32 {
	return match kind {
		.plain { theme.foreground }
		.info { theme.primary }
		.success { theme.success }
		.warning { theme.warning }
		.error { theme.danger }
	}
}

// notification_kind_symbol names the SF Symbol for a kind, after GPUI Kit's
// Info, CircleCheck, TriangleAlert and CircleX icons.
fn notification_kind_symbol(kind NotificationKind) string {
	return match kind {
		.plain { '' }
		.info { 'info.circle' }
		.success { 'checkmark.circle' }
		.warning { 'exclamationmark.triangle' }
		.error { 'xmark.circle' }
	}
}

// notification_kind_glyph is the character a kind's ring holds, and its size
// relative to the ring: × and ✓ draw small within their em.
fn notification_kind_glyph(kind NotificationKind) (string, f64) {
	return match kind {
		.plain { '', 0.0 }
		.info { 'i', 0.66 }
		.success { '✓', 0.72 }
		.warning { '!', 0.66 }
		.error { '✕', 0.7 }
	}
}

// notification_kind_symbols_known reports whether every renderer draws all four
// kind symbols. Until they all are, every kind is drawn as a ring, so the four
// keep one style rather than mixing a symbol with rings.
fn notification_kind_symbols_known() bool {
	for kind in [NotificationKind.info, .success, .warning, .error] {
		if !symbol_known(notification_kind_symbol(kind)) {
			return false
		}
	}
	return true
}

// notification_symbol is a `symbol:` image tinted with color.
fn notification_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

// notification_ring_glyph draws glyph in a ring, the outline-circle style of the
// kind symbols, for a symbol not every renderer has. Borders ignore corner radii
// in the custom renderer, so the ring is a disc with a smaller one on top.
fn notification_ring_glyph(glyph string, scale f64, frame Rect, color u32, background u32) Element {
	side := math.min(frame.width, frame.height)
	stroke := math.max(math.round(side / 11 * 2) / 2, 1)
	return view('', frame, BoxStyle{
		bg:     color
		radius: side / 2
	}, [
		view('', rect(stroke, stroke, side - stroke * 2, side - stroke * 2), BoxStyle{
			bg:     background
			radius: side / 2 - stroke
		}, []Element{}),
		label('', glyph, rect(0, 0, side, side), TextStyle{
			color: color
			size:  math.round(side * scale)
			bold:  true
			align: .center
		}),
	])
}

fn notification_icon(n Notification, frame Rect, theme ComponentTheme) ?Element {
	color := notification_kind_color(theme, n.kind)
	if n.icon.len > 0 {
		return notification_symbol(n.icon, frame, color)
	}
	name := notification_kind_symbol(n.kind)
	if name.len == 0 {
		return none
	}
	if notification_kind_symbols_known() {
		return notification_symbol(name, frame, color)
	}
	glyph, scale := notification_kind_glyph(n.kind)
	return notification_ring_glyph(glyph, scale, frame, color, theme.background)
}

fn notification_card(config NotificationStackConfig, entry NotificationEntry, layout NotificationCardLayout) Element {
	n := entry.notification
	nm := notification_metrics(config.size)
	theme := config.theme
	// A disc of border color under a slightly smaller one of background: the
	// custom renderer draws borders without rounding their corners.
	mut children := [
		view('', rect(1, 1, math.max(layout.width - 2, 0), math.max(layout.height - 2, 0)),
			BoxStyle{
				bg:     theme.background
				radius: nm.radius - 1
			}, []Element{}),
	]
	if icon := notification_icon(n, layout.icon, theme) {
		children << icon
	}
	if n.title.len > 0 {
		children << label('', n.title, layout.title, TextStyle{
			color:  theme.foreground
			size:   nm.font
			bold:   true
			valign: .top
			lines:  0
		})
	}
	if n.message.len > 0 {
		children << label('', n.message, layout.message, TextStyle{
			color:  theme.foreground
			size:   nm.font
			valign: .top
			lines:  0
		})
	}
	if layout.content.height > 0 {
		children << view('', layout.content, BoxStyle{ transparent: true }, n.content)
	}
	if n.action.len > 0 {
		action_id := notification_action_id(config.id, entry.seq, 'action')
		children << Element{
			...button(action_id, n.action, layout.action, BoxStyle{
				bg:     theme.primary
				radius: nm.action.radius
			}, TextStyle{
				color: theme.primary_foreground
				size:  nm.action.font_size
				align: .center
			})
			accessibility_label: n.action
		}
	}
	close_id := notification_action_id(config.id, entry.seq, 'close')
	glyph := math.round(layout.close.height * 0.55)
	children << Element{
		...button_view(close_id, layout.close, BoxStyle{
			transparent: true
			radius:      nm.action.radius
		}, [
			notification_symbol('xmark', rect((layout.close.width - glyph) / 2, (layout.close.height - glyph) / 2,
				glyph, glyph), theme.muted_foreground),
		])
		cursor:              cursor_pointing_hand
		accessibility_label: 'Dismiss notification'
	}
	summary := [n.title, n.message].filter(it.len > 0).join(': ')
	card := Element{
		...view(notification_card_id(config.id, entry.seq), rect(0, 0, layout.width, layout.height),
			BoxStyle{
				bg:     theme.border
				radius: nm.radius
				shadow: component_card_shadow()
			}, children)
		accessibility_role:  if n.kind in [.warning, .error] { 'alert' } else { 'status' }
		accessibility_label: summary
	}
	if !n.clickable {
		return card
	}
	return Element{
		...with_button_behavior(card)
		action_id:          notification_action_id(config.id, entry.seq, 'click')
		cursor:             cursor_pointing_hand
		accessibility_role: 'button'
	}
}

// notification_entering_offset is where the entering notifications of a stack
// start, relative to their places: just past the edge the stack grows from, all
// by one distance, so notifications pushed together arrive together.
fn notification_entering_offset(config NotificationStackConfig, stack NotificationStackLayout) (f64, f64) {
	frame := config.frame
	if stack.placement == .left_center {
		return frame.x - stack.frame.x - stack.frame.width, 0.0
	}
	if stack.placement == .right_center {
		return frame.x + frame.width - stack.frame.x, 0.0
	}
	bottom := notification_anchored_bottom(stack.placement)
	mut edge := if bottom { stack.frame.height } else { 0.0 }
	for index, entry in stack.entries {
		if entry.phase == .entering {
			slot := stack.slots[index]
			edge = if bottom {
				math.min(edge, slot.y)
			} else {
				math.max(edge, slot.y + slot.height)
			}
		}
	}
	return 0.0, if bottom {
		frame.y + frame.height - stack.frame.y - edge
	} else {
		frame.y - stack.frame.y - edge
	}
}

// notification_start_motion slides a notification in while it is entering and
// out while it is leaving. The card moves inside its slot, and the slot moves
// across the stack, along axes whose declared offset is always zero, so the
// values an animation leaves behind never fight a later layout.
fn notification_start_motion(config NotificationStackConfig, stack NotificationStackLayout, entry NotificationEntry, slot Rect, in_x f64, in_y f64) {
	if !config.animate {
		return
	}
	frame := config.frame
	if entry.phase == .entering {
		card_id := notification_card_id(config.id, entry.seq)
		if animation_info(card_id).status != .idle {
			return
		}
		duration := notification_seconds(config.list.enter_duration)
		motion := if in_x != 0 {
			animation(duration: 0, x: in_x) + animation(
				duration:   duration
				x:          0
				transition: .out_cubic
			)
		} else {
			animation(duration: 0, y: in_y) + animation(
				duration:   duration
				y:          0
				transition: .out_cubic
			)
		}
		motion.start(card_id)
	} else if entry.phase == .leaving {
		slot_id := notification_slot_id(config.id, entry.seq)
		if animation_info(slot_id).status != .idle {
			return
		}
		out_x := if stack.placement in [.top_left, .left_center, .bottom_left] {
			frame.x - stack.frame.x - slot.width
		} else {
			frame.x + frame.width - stack.frame.x
		}
		animation(
			duration:   notification_seconds(config.list.exit_duration)
			x:          out_x
			transition: .in_cubic
		).start(slot_id)
	}
}

// notification_stacks draws a list's visible notifications as one stack per
// placement in use, each sized to its notifications so the window around them
// stays clickable. Append the result after the rest of the window's children so
// the stacks draw on top. The stacks report hover for pause/resume; decode their
// actions with notification_event_from_action.
pub fn notification_stacks(config NotificationStackConfig) ![]Element {
	component_validate_id(config.id)!
	layouts := notification_stack_layouts(config)!
	mut stacks := []Element{cap: layouts.len}
	for stack in layouts {
		in_x, in_y := notification_entering_offset(config, stack)
		mut slots := []Element{cap: stack.entries.len}
		for index, entry in stack.entries {
			slot := stack.slots[index]
			notification_start_motion(config, stack, entry, slot, in_x, in_y)
			slots << Element{
				...view(notification_slot_id(config.id, entry.seq), slot, BoxStyle{ transparent: true }, [
					notification_card(config, entry, stack.cards[index]),
				])
				key: 'toast:${entry.seq}'
			}
		}
		stacks << component_finish(Element{
			...view(notification_stack_id(config.id, stack.placement), stack.frame, BoxStyle{
				transparent: true
			}, slots)
			key:                 'stack:${stack.placement}'
			hoverable:           true
			accessibility_role:  'group'
			accessibility_label: 'Notifications'
		})!
	}
	return stacks
}
