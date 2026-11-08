module ui2

import math

// MessageScrollerUnreadFn words the unread count on the jump control, for
// localization; the default is "1 new message" or "N new messages".
pub type MessageScrollerUnreadFn = fn (count int) string

// MessageScrollerJumpFn draws the jump control instead of the default one.
// Keep jump.action as the action of what it returns, so message_scroller_update
// still recognizes a press on it.
pub type MessageScrollerJumpFn = fn (jump MessageScrollerJump) Element

// MessageScrollerJump is what a MessageScrollerJumpFn gets: the control the
// scroller would draw and the parts it is made from.
pub struct MessageScrollerJump {
pub:
	action  string  // The action that jumps; message_scroller_update decodes it.
	frame   Rect    // Where the default control sits, in the scroller's coordinates.
	unread  int     // Rows not read yet.
	text    string  // The unread text the default control shows, or empty.
	label   string  // Its tooltip and accessible name.
	control Element // The default control.
	theme   ComponentTheme
}

pub struct MessageScrollerConfig {
pub:
	id    string // Required. The Scroll element inside is message_scroller_scroll_id(id, state).
	frame Rect
	state MessageScrollerState
	// item builds the row at index in frame, which is the row's place in the
	// scrolled content, inset from the sides. Give the row a key that names
	// the message (its id) so a row keeps its native view when rows are added
	// above it; otherwise rows are keyed by index.
	item     VirtualListItemFn = unsafe { nil }
	overscan int               = 4 // Rows built past each edge of the viewport.
	// inset is the space left and right of the rows (GPUI Kit's list px_3).
	// The vertical spacing is the layout's gap and padding.
	inset f64 = 12
	// load_earlier_threshold is how near the first row the rows in view come
	// before message_scroller_scroll reports load_earlier; -1 never does.
	load_earlier_threshold int = 3
	// The jump-to-latest control shows while the reader is away from the tail.
	jump_button     bool   = true
	jump_label      string = 'Jump to latest' // Tooltip and accessible name.
	jump_to_unread  bool // Jump to the first unread row first, when there is one.
	unread_text     MessageScrollerUnreadFn = unsafe { nil }
	jump_background ?u32 // Defaults to the background, or the primary color with unread rows.
	jump_foreground ?u32
	jump_border     ?u32
	jump_render     MessageScrollerJumpFn = unsafe { nil }
	// bottom_fade fades the rows into fade_color (the scroller's background by
	// default) at the bottom edge while the reader is away from the tail.
	bottom_fade bool
	fade_color  ?u32
	background  ?u32 // The scroller's fill; the theme's background by default.
	transparent bool // Leave the background unpainted where the backend can.
	// The empty state, drawn when there are no rows.
	empty_title         string = 'No messages yet'
	empty_description   string
	empty_icon          string        = 'text.bubble'
	accessibility_label string        = 'Messages'
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// MessageScrollerStep is what a reported scroll did to a scroller.
pub struct MessageScrollerStep {
pub:
	state MessageScrollerState
	// rebuild is set when the scroller shows something else: other rows, the
	// jump control or its unread count. Call request_refresh() then.
	rebuild bool
	// load_earlier is set while the rows in view are within the threshold of
	// the first row. Load earlier history if there is more and no load is
	// under way, then prepend it.
	load_earlier bool
}

// The room the backends' overlay scrollbars take at the right edge, which the
// bottom fade leaves alone.
const message_scroller_scrollbar_room = 14.0

const message_scroller_fade_height = 48.0

// message_scroller_unread_text is the default wording of the unread count.
pub fn message_scroller_unread_text(count int) string {
	return if count == 1 { '1 new message' } else { '${badge_text(count, 999)} new messages' }
}

fn message_scroller_unread_label(config MessageScrollerConfig, count int) string {
	if voidptr(config.unread_text) != unsafe { nil } {
		return config.unread_text(count)
	}
	return message_scroller_unread_text(count)
}

// message_scroller_jump_action is the action the jump control emits.
pub fn message_scroller_jump_action(id string) string {
	return component_part_id(id, 'jump')
}

// message_scroller is a virtual list of conversation rows that follows the
// tail, keeps the reader's place when history is added above it, and offers a
// way back to the latest row, with the unread count, while the reader is away.
// It is controlled: pass reported scrolls to message_scroller_scroll and jump
// presses to message_scroller_update, store the state they return, and pass
// take_scroll_request to scroll_to_offset after every change.
pub fn message_scroller(config MessageScrollerConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if voidptr(config.item) == unsafe { nil } {
		return error('message scroller `${config.id}` needs an item builder')
	}
	if !component_finite(config.inset) || config.inset < 0 {
		return error('message scroller inset must be finite and non-negative')
	}
	s := config.state
	viewport := component_local(config.frame)
	mut children := []Element{}
	if s.layout.count == 0 {
		children << message_scroller_empty(config, viewport)
	} else {
		children << message_scroller_rows(config, viewport)!
		if s.is_scrolled_up() {
			if config.bottom_fade {
				children << message_scroller_fade(config, viewport)
			}
			if config.jump_button {
				children << message_scroller_jump(config, viewport)
			}
		}
	}
	box := if config.transparent {
		BoxStyle{
			transparent: true
		}
	} else {
		BoxStyle{
			bg: message_scroller_background(config)
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		// Keyed by its id, which is unique in the tree, so the scroller keeps
		// its native scroll view, and with it the reader's place, when the
		// application adds or removes siblings before it.
		key: 'message-scroller:' + config.id
	})
}

fn message_scroller_background(config MessageScrollerConfig) u32 {
	return config.background or { config.theme.background }
}

// message_scroller_rows is the virtual list itself. Its id carries the state's
// serial and its key stays, so a requested scroll waits for this content while
// the native scroll view lives on.
fn message_scroller_rows(config MessageScrollerConfig, frame Rect) !Element {
	s := config.state
	inset := math.min(config.inset, frame.width / 2)
	width := frame.width - 2 * inset
	item := config.item
	built := virtual_list(
		id:          message_scroller_scroll_id(config.id, s)
		frame:       frame
		layout:      s.layout
		offset:      s.offset
		overscan:    config.overscan
		item:        fn [item, inset, width] (index int, slot Rect) Element {
			return item(index, rect(inset, slot.y, width, slot.height))
		}
		transparent: config.transparent
		theme:       ComponentTheme{
			...config.theme
			background: message_scroller_background(config)
		}
	)!
	unread := s.unread()
	return Element{
		...built
		key:                 'message-scroller:rows'
		// A log, as GPUI Kit's transcript is: rows added at the end are
		// announced as they arrive.
		accessibility_role:  'log'
		accessibility_label: config.accessibility_label
		accessibility_value: if unread > 0 {
			message_scroller_unread_label(config, unread)
		} else {
			''
		}
	}
}

fn message_scroller_fade(config MessageScrollerConfig, viewport Rect) Element {
	color := config.fade_color or { message_scroller_background(config) }
	height := math.min(message_scroller_fade_height, viewport.height / 3)
	return Element{
		...view('', rect(viewport.x, viewport.y + viewport.height - height, math.max(viewport.width - message_scroller_scrollbar_room,
			0), height), BoxStyle{
			gradient: linear_gradient(90, GradientStop{
				color:    color
				position: 0
				opacity:  0
			}, GradientStop{
				color:    color
				position: 1
				opacity:  1
			})
		}, []Element{})
		key: 'message-scroller:fade'
	}
}

// message_scroller_jump_frame is where the jump control sits in a viewport:
// centered, a little above the bottom edge. A control with text is as wide as
// the text needs, within the viewport.
fn message_scroller_jump_frame(viewport Rect, caption string, size ComponentSize) Rect {
	m := component_metrics(size)
	height := m.height
	icon := math.round(m.font_size * 1.15)
	pad := m.padding + 4
	width := if caption.len == 0 {
		height
	} else {
		math.min(math.ceil(pad + icon + m.gap + component_text_width_estimate(caption, m.font_size) +
			pad), math.max(viewport.width - 32, height))
	}
	return rect(viewport.x + math.round((viewport.width - width) / 2), viewport.y +
		math.max(viewport.height - height - 16, 0), width, height)
}

fn message_scroller_jump(config MessageScrollerConfig, viewport Rect) Element {
	theme := config.theme
	m := component_metrics(config.size)
	unread := config.state.unread()
	caption := if unread > 0 { message_scroller_unread_label(config, unread) } else { '' }
	frame := message_scroller_jump_frame(viewport, caption, config.size)
	accent := unread > 0
	bg := config.jump_background or { if accent { theme.primary } else { theme.background } }
	fg := config.jump_foreground or {
		if accent { theme.primary_foreground } else { theme.foreground }
	}
	border := config.jump_border or { if accent { theme.primary } else { theme.border } }
	icon := math.round(m.font_size * 1.15)
	pad := m.padding + 4
	icon_x := if caption.len == 0 { (frame.height - icon) / 2 } else { pad }
	mut parts := [
		Element{
			...image('', 'symbol:arrow.down', rect(icon_x, (frame.height - icon) / 2, icon,
				icon))
			text_style: TextStyle{
				color: fg
			}
		},
	]
	if caption.len > 0 {
		text_x := pad + icon + m.gap
		parts << label('', caption, rect(text_x, 0, math.max(frame.width - text_x - pad + 4, 0),
			frame.height), TextStyle{
			color: fg
			size:  m.font_size
			bold:  true
		})
	}
	action := message_scroller_jump_action(config.id)
	name := if caption.len > 0 { '${config.jump_label}, ${caption}' } else { config.jump_label }
	control := Element{
		...button_view(action, frame, BoxStyle{
			bg:            bg
			radius:        frame.height / 2
			border_color:  border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        component_card_shadow()
		}, parts)
		key:                 'message-scroller:jump'
		tooltip:             config.jump_label
		cursor:              cursor_pointing_hand
		accessibility_label: name
	}
	if voidptr(config.jump_render) == unsafe { nil } {
		return control
	}
	custom := config.jump_render(MessageScrollerJump{
		action:  action
		frame:   frame
		unread:  unread
		text:    caption
		label:   name
		control: control
		theme:   theme
	})
	return Element{
		...custom
		key: 'message-scroller:jump'
	}
}

fn message_scroller_empty(config MessageScrollerConfig, frame Rect) Element {
	theme := config.theme
	m := component_metrics(config.size)
	icon := math.round(m.font_size * 2.4)
	title_height := math.round(m.font_size * 1.5)
	small := math.max(m.font_size - 1, 11)
	description_height := if config.empty_description.len > 0 {
		math.round(small * 1.5) * 2
	} else {
		0.0
	}
	block := icon + m.gap + title_height + description_height
	mut y := math.max(math.round((frame.height - block) / 2), 0)
	inner := math.max(frame.width - 2 * config.inset, 0)
	mut children := []Element{}
	if config.empty_icon.len > 0 && symbol_known(config.empty_icon) {
		children << Element{
			...image('', 'symbol:' + config.empty_icon, rect(math.round((frame.width - icon) / 2),
				y, icon, icon))
			text_style: TextStyle{
				color: theme.border
			}
		}
		y += icon + m.gap
	}
	children << label('', config.empty_title, rect(config.inset, y, inner, title_height),
		TextStyle{
			color: theme.muted_foreground
			size:  m.font_size
			bold:  true
			align: .center
		})
	y += title_height
	if config.empty_description.len > 0 {
		children << label('', config.empty_description, rect(config.inset, y, inner, description_height),
			TextStyle{
				color:  theme.muted_foreground
				size:   small
				align:  .center
				lines:  2
				valign: .top
			})
	}
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		key:                 'message-scroller:empty'
		accessibility_role:  'status'
		accessibility_label: if config.empty_description.len > 0 {
			'${config.empty_title}. ${config.empty_description}'
		} else {
			config.empty_title
		}
	}
}

// message_scroller_shown is what a state makes the scroller show, to tell
// whether a scroll needs a rebuild.
struct MessageScrollerShown {
	start  int
	end    int
	jump   bool
	unread int
}

fn message_scroller_shown(config MessageScrollerConfig, s MessageScrollerState) MessageScrollerShown {
	span := s.layout.range(config.frame.height, s.offset, config.overscan)
	away := s.is_scrolled_up()
	return MessageScrollerShown{
		start:  span.start
		end:    span.end
		jump:   away
		unread: if away { s.unread() } else { 0 }
	}
}

// message_scroller_scroll takes a scroll the backend reported from on_scroll:
// pass the id it reported and scroll_offset(id). It returns none for any other
// Scroll element, including this scroller's from before its last requested
// scroll, whose reports are stale.
pub fn message_scroller_scroll(config MessageScrollerConfig, scroll_id string, offset f64) ?MessageScrollerStep {
	if config.id.len == 0 || scroll_id != message_scroller_scroll_id(config.id, config.state) {
		return none
	}
	next := config.state.scrolled(offset)
	return MessageScrollerStep{
		state:        next
		rebuild:      message_scroller_shown(config, config.state) != message_scroller_shown(config,
			next)
		load_earlier: next.near_start(config.load_earlier_threshold)
	}
}

// message_scroller_update decodes a press on the jump control into the state
// it leads to: the latest row, following the tail again (or, with
// jump_to_unread, the first unread row first). It returns none for other
// actions, malformed ones, and while the control is not shown.
pub fn message_scroller_update(config MessageScrollerConfig, action string) ?MessageScrollerState {
	part := component_action_part(config.id, action) or { return none }
	s := config.state
	if part != 'jump' || !config.jump_button || !s.is_scrolled_up() {
		return none
	}
	if config.jump_to_unread && s.first_unread >= 0 {
		if next := s.scroll_to_row(s.first_unread, .start) {
			if next.offset > s.offset + 0.5 {
				return next
			}
		}
	}
	return s.scroll_to_end()
}
