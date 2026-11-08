module ui2

import math

// MessageStatus is the delivery state a message's footer reports. The words are
// message_status_text's unless the message gives its own.
pub enum MessageStatus {
	none
	sending
	sent
	delivered
	read
	failed
}

// message_status_text is the default footer wording of a status.
pub fn message_status_text(status MessageStatus) string {
	return match status {
		.none { '' }
		.sending { 'Sending…' }
		.sent { 'Sent' }
		.delivered { 'Delivered' }
		.read { 'Read' }
		.failed { 'Not delivered' }
	}
}

fn message_status_symbol(status MessageStatus) string {
	return match status {
		.none { '' }
		.sending { 'clock' }
		.sent { 'checkmark' }
		.delivered { 'checkmark.circle' }
		.read { 'checkmark.circle.fill' }
		.failed { 'exclamationmark.circle.fill' }
	}
}

// MessageAction is a footer command such as Reply or Copy: an icon button, a
// text button, or both side by side.
pub struct MessageAction {
pub:
	name    string // What chat_message_event_from_action reports.
	label   string // Visible text; also the accessible name.
	icon    string // A symbol name (symbol_known); with no label the button shows only it.
	tooltip string // Hover help; an icon-only action falls back to its label or name.
	enabled bool = true
}

pub struct ChatMessageConfig {
pub:
	id string // Required when footer actions or bubble reactions are interactive.
	// frame is the message's row: x, y and width. The element is as tall as
	// frame.height or its content (chat_message_height), whichever is more.
	frame     Rect
	alignment MessageAlignment
	// Sender identity. author is the header's name and the avatar's initials.
	author       string
	avatar_image string // An image path for the avatar instead of initials.
	// show_avatar reserves the avatar column. Within a run only the last message
	// draws the avatar; the others keep the column empty so the bubbles line up.
	show_avatar     bool = true
	avatar_size     f64 // 0 uses the size preset: 24, 32 or 40.
	identity_colors bool = true // Color initials by name (avatar_identity_theme).
	// Header, shown on the first message of a run.
	show_header bool = true
	timestamp   string
	badges      []string // Short labels after the name, such as 'Admin' or 'Bot'.
	// Content: a bubble when bubble has text or content, then the application's
	// own content below it, sized content_width x content_height.
	bubble         BubbleConfig
	content        []Element
	content_width  f64
	content_height f64
	// Footer: status, a note such as 'Edited' and actions.
	status      MessageStatus
	status_text string // Replaces message_status_text(status).
	footer_text string
	actions     []MessageAction
	// content_inset keeps (true) or drops (false) the header and footer inset that
	// lines them up with a bubble's text. Unset, a ghost bubble drops it.
	content_inset       ?bool
	group_position      ChatGroupPosition
	enabled             bool          = true // False: actions and reactions are not interactive.
	size                ComponentSize = .medium
	theme               ComponentTheme
	accessibility_label string // Defaults to the author, timestamp and status.
}

// ChatMessageLayout is where a message puts its parts, relative to its element.
pub struct ChatMessageLayout {
pub:
	height  f64
	column  Rect // Everything beside the avatar column.
	avatar  Rect // Empty when no avatar is drawn.
	header  Rect // Empty without a header.
	bubble  Rect // The bubble's element; empty without a bubble.
	surface Rect // The bubble's visible surface.
	content Rect // The application's content under the bubble.
	footer  Rect // Empty without a footer.
	inset   f64  // Of the header and footer from the column's edge.
}

struct ChatMessageMetrics {
	avatar      f64
	avatar_gap  f64
	meta_font   f64
	meta_gap    f64
	badge_font  f64
	badge_pad   f64
	action      f64
	item_gap    f64
	status_icon f64
}

fn chat_message_metrics(size ComponentSize) ChatMessageMetrics {
	return match size {
		.small { ChatMessageMetrics{24, 6, 11, 3, 9, 5, 20, 6, 11} }
		.medium { ChatMessageMetrics{32, 8, 12, 4, 10, 6, 24, 8, 12} }
		.large { ChatMessageMetrics{40, 10, 13, 6, 11, 7, 28, 10, 14} }
	}
}

enum ChatMetaKind {
	name
	badge
	note
	status
	action
}

struct ChatMetaItem {
	kind  ChatMetaKind
	text  string
	icon  string
	width f64
	index int // Of the action.
}

// chat_message_action_id is the action a message's index-th footer action emits.
pub fn chat_message_action_id(id string, index int) string {
	return component_part_id(id, 'action:${index}')
}

// chat_message_bubble_id is the id of a message's bubble, whose reaction
// actions start with it.
pub fn chat_message_bubble_id(id string) string {
	return component_part_id(id, 'bubble')
}

fn chat_message_has_bubble(config ChatMessageConfig) bool {
	b := config.bubble
	return b.text.len > 0 || b.content.len > 0 || b.content_width > 0 || b.content_height > 0
}

fn chat_message_has_content(config ChatMessageConfig) bool {
	return config.content.len > 0 || config.content_width > 0 || config.content_height > 0
}

fn chat_message_shows_header(config ChatMessageConfig) bool {
	return config.show_header && chat_group_opens(config.group_position)
		&& (config.author.len > 0 || config.timestamp.len > 0 || config.badges.len > 0)
}

fn chat_message_has_footer(config ChatMessageConfig) bool {
	return config.status != .none || config.status_text.len > 0 || config.footer_text.len > 0
		|| config.actions.len > 0
}

fn chat_message_avatar_size(config ChatMessageConfig, m ChatMessageMetrics) f64 {
	return if config.avatar_size > 0 && component_finite(config.avatar_size) {
		config.avatar_size
	} else {
		m.avatar
	}
}

fn chat_meta_height(m ChatMessageMetrics) f64 {
	return math.ceil(font_line_height(m.meta_font)) + 2
}

fn chat_footer_height(config ChatMessageConfig, m ChatMessageMetrics) f64 {
	line := chat_meta_height(m)
	return if config.actions.len > 0 { math.max(line, m.action) } else { line }
}

// chat_message_bubble is the bubble config a message draws at y in its row.
fn chat_message_bubble(config ChatMessageConfig, column Rect, y f64) BubbleConfig {
	return BubbleConfig{
		...config.bubble
		id:             chat_message_bubble_id(config.id)
		frame:          rect(column.x, y, column.width, 0)
		alignment:      config.alignment
		group_position: config.group_position
		enabled:        config.enabled && config.bubble.enabled
		size:           config.size
		theme:          config.theme
	}
}

// chat_message_layout computes where a message draws its parts. The avatar is
// flush with the bottom of the content beside it, the header sits above the
// content and the footer below both, indented to the content column.
pub fn chat_message_layout(config ChatMessageConfig) ChatMessageLayout {
	m := chat_message_metrics(config.size)
	row := if component_finite(config.frame.width) { math.max(config.frame.width, 0) } else { 0.0 }
	avatar_size := chat_message_avatar_size(config, m)
	reserve := if config.show_avatar { math.min(avatar_size + m.avatar_gap, row) } else { 0.0 }
	column_x := if config.alignment == .start { reserve } else { 0.0 }
	column_width := row - reserve
	has_bubble := chat_message_has_bubble(config)
	ghost := has_bubble && config.bubble.variant == .ghost
	keep_inset := config.content_inset or { !ghost }
	inset := if keep_inset { bubble_metrics(config.size).pad_x } else { 0.0 }
	mut y := 0.0
	mut header := rect(0, 0, 0, 0)
	if chat_message_shows_header(config) {
		header = rect(column_x, 0, column_width, chat_meta_height(m))
		y = header.height + m.meta_gap
	}
	content_top := y
	mut bubble_frame := rect(0, 0, 0, 0)
	mut surface := rect(0, 0, 0, 0)
	if has_bubble {
		b := bubble_layout(chat_message_bubble(config, rect(column_x, 0, column_width, 0),
			y))
		bubble_frame = rect(column_x, y, column_width, b.height)
		surface = rect(column_x + b.surface.x, y + b.surface.y, b.surface.width, b.surface.height)
		y += b.height
	}
	mut content := rect(0, 0, 0, 0)
	mut content_bottom := surface.y + surface.height
	if chat_message_has_content(config) {
		if has_bubble {
			y += m.meta_gap * 1.5
		}
		width := math.min(chat_length(config.content_width), column_width)
		height := chat_length(config.content_height)
		x := if config.alignment == .start { column_x } else { column_x + column_width - width }
		content = rect(x, y, width, height)
		y += height
		content_bottom = y
	}
	if !has_bubble && !chat_message_has_content(config) {
		content_bottom = content_top
	}
	mut avatar_frame := rect(0, 0, 0, 0)
	if config.show_avatar && chat_group_closes(config.group_position) {
		size := math.min(avatar_size, row)
		ax := if config.alignment == .start { 0.0 } else { row - size }
		avatar_frame = rect(ax, math.max(0, content_bottom - size), size, size)
		y = math.max(y, avatar_frame.y + size)
	}
	mut footer := rect(0, 0, 0, 0)
	if chat_message_has_footer(config) {
		y += m.meta_gap
		footer = rect(column_x, y, column_width, chat_footer_height(config, m))
		y += footer.height
	}
	return ChatMessageLayout{
		height:  y
		column:  rect(column_x, 0, column_width, y)
		avatar:  avatar_frame
		header:  header
		bubble:  bubble_frame
		surface: surface
		content: content
		footer:  footer
		inset:   inset
	}
}

// chat_message_height is how tall chat_message draws config: what a list
// gives the row.
pub fn chat_message_height(config ChatMessageConfig) f64 {
	return chat_message_layout(config).height
}

fn chat_message_header_items(config ChatMessageConfig, m ChatMessageMetrics) []ChatMetaItem {
	mut items := []ChatMetaItem{}
	if config.author.len > 0 {
		items << ChatMetaItem{
			kind:  .name
			text:  config.author
			width: math.ceil(chat_text_width(config.author, m.meta_font, true) + chat_label_slack)
		}
	}
	for badge_text in config.badges {
		if badge_text.len > 0 {
			items << ChatMetaItem{
				kind:  .badge
				text:  badge_text
				width: math.ceil(chat_text_width(badge_text, m.badge_font, true) + 2 * m.badge_pad)
			}
		}
	}
	if config.timestamp.len > 0 {
		items << ChatMetaItem{
			kind:  .note
			text:  config.timestamp
			width: math.ceil(chat_text_width(config.timestamp, m.meta_font, false) +
				chat_label_slack)
		}
	}
	return items
}

fn chat_message_footer_items(config ChatMessageConfig, m ChatMessageMetrics) []ChatMetaItem {
	mut items := []ChatMetaItem{}
	status := if config.status_text.len > 0 {
		config.status_text
	} else {
		message_status_text(config.status)
	}
	if status.len > 0 {
		symbol := message_status_symbol(config.status)
		icon_width := if symbol.len > 0 { m.status_icon + 4 } else { 0.0 }
		items << ChatMetaItem{
			kind:  .status
			text:  status
			icon:  symbol
			width: math.ceil(icon_width + chat_text_width(status, m.meta_font, false) +
				chat_label_slack)
		}
	}
	if config.footer_text.len > 0 {
		items << ChatMetaItem{
			kind:  .note
			text:  config.footer_text
			width: math.ceil(chat_text_width(config.footer_text, m.meta_font, false) +
				chat_label_slack)
		}
	}
	for index, action in config.actions {
		icon_only := action.label.len == 0
		mut width := if icon_only { m.action } else { 0.0 }
		if !icon_only {
			width = math.ceil(chat_text_width(action.label, m.meta_font, false) + 2 * m.badge_pad)
			if action.icon.len > 0 {
				width += m.status_icon + 4
			}
		}
		items << ChatMetaItem{
			kind:  .action
			text:  action.label
			icon:  action.icon
			width: width
			index: index
		}
	}
	return items
}

// chat_meta_place returns the x of each item laid out in a row from left to
// right, at the start or packed against the end of [left, right]. Items that
// start past the row are dropped (-1); the last one shown is cut to fit.
fn chat_meta_place(items []ChatMetaItem, left f64, right f64, gap f64, alignment MessageAlignment) ([]f64, []f64) {
	mut total := 0.0
	for index, item in items {
		total += item.width + if index > 0 { gap } else { 0.0 }
	}
	mut x := if alignment == .start { left } else { math.max(left, right - total) }
	mut xs := []f64{cap: items.len}
	mut widths := []f64{cap: items.len}
	for item in items {
		if x >= right {
			xs << -1
			widths << 0
			continue
		}
		xs << x
		widths << math.min(item.width, right - x)
		x += item.width + gap
	}
	return xs, widths
}

fn chat_message_header(config ChatMessageConfig, layout ChatMessageLayout, m ChatMessageMetrics) []Element {
	theme := config.theme
	items := chat_message_header_items(config, m)
	xs, widths := chat_meta_place(items, layout.header.x + layout.inset, layout.header.x +
		layout.header.width - layout.inset, m.item_gap * 0.75, config.alignment)
	mut out := []Element{}
	for index, item in items {
		if xs[index] < 0 {
			continue
		}
		frame := rect(xs[index], layout.header.y, widths[index], layout.header.height)
		match item.kind {
			.badge {
				height := math.ceil(font_line_height(m.badge_font)) + 2
				pill := rect(frame.x, frame.y + (frame.height - height) / 2, frame.width,
					height)
				out << view('', pill, BoxStyle{
					bg:     theme.muted
					radius: height / 2
				}, [
					label('', item.text, component_local(pill), TextStyle{
						color: theme.muted_foreground
						size:  m.badge_font
						bold:  true
						align: .center
					}),
				])
			}
			else {
				out << label('', item.text, frame, TextStyle{
					color: if item.kind == .name {
						theme.foreground
					} else {
						theme.muted_foreground
					}
					size:  m.meta_font
					bold:  item.kind == .name
				})
			}
		}
	}
	return out
}

fn chat_message_footer(config ChatMessageConfig, layout ChatMessageLayout, m ChatMessageMetrics) []Element {
	theme := config.theme
	items := chat_message_footer_items(config, m)
	xs, widths := chat_meta_place(items, layout.footer.x + layout.inset, layout.footer.x +
		layout.footer.width - layout.inset, m.item_gap, config.alignment)
	muted := theme.muted_foreground
	mut out := []Element{}
	for index, item in items {
		if xs[index] < 0 {
			continue
		}
		frame := rect(xs[index], layout.footer.y, widths[index], layout.footer.height)
		match item.kind {
			.status {
				color := match config.status {
					.failed { theme.danger }
					.read { theme.primary }
					else { muted }
				}
				mut text_x := frame.x
				if item.icon.len > 0 {
					out << chat_symbol(item.icon, rect(frame.x, frame.y + (frame.height - m.status_icon) / 2,
						m.status_icon, m.status_icon), color)
					text_x += m.status_icon + 4
				}
				out << label('', item.text, rect(text_x, frame.y, math.max(frame.x + frame.width - text_x,
					0), frame.height), TextStyle{
					color: if config.status == .failed { theme.danger } else { muted }
					size:  m.meta_font
				})
			}
			.action {
				out << chat_message_action(config, config.actions[item.index], item.index,
					frame, m)
			}
			else {
				out << label('', item.text, frame, TextStyle{
					color: muted
					size:  m.meta_font
				})
			}
		}
	}
	return out
}

fn chat_message_action(config ChatMessageConfig, action MessageAction, index int, frame Rect, m ChatMessageMetrics) Element {
	theme := config.theme
	enabled := config.enabled && action.enabled
	color := if enabled {
		theme.muted_foreground
	} else {
		chat_mix(theme.muted_foreground, theme.background, 0.5)
	}
	height := math.min(m.action, frame.height)
	local := rect(0, 0, frame.width, height)
	icon := math.round(m.status_icon * 1.1)
	mut parts := []Element{}
	if action.icon.len > 0 {
		x := if action.label.len == 0 { (frame.width - icon) / 2 } else { m.badge_pad }
		parts << chat_symbol(action.icon, rect(x, (height - icon) / 2, icon, icon), color)
	}
	if action.label.len > 0 {
		x := if action.icon.len > 0 { m.badge_pad + icon + 4 } else { 0.0 }
		parts << label('', action.label, rect(x, 0, local.width - x, height), TextStyle{
			color: color
			size:  m.meta_font
			align: if action.icon.len > 0 { Align.left } else { Align.center }
		})
	}
	name := if action.label.len > 0 { action.label } else { action.name }
	tip := if action.tooltip.len > 0 {
		action.tooltip
	} else if action.label.len == 0 {
		name
	} else {
		''
	}
	mut el := Element{
		...button_view(chat_message_action_id(config.id, index), rect(frame.x, frame.y +
			(frame.height - height) / 2, frame.width, height), BoxStyle{
			transparent: true
			radius:      6
		}, parts)
		key:                 'action:${index}'
		enabled:             enabled
		cursor:              if enabled { cursor_pointing_hand } else { cursor_default }
		accessibility_label: name
	}
	if tip.len > 0 {
		el = with_tooltip(el, tip)
	}
	return el
}

fn chat_message_validate(config ChatMessageConfig) ! {
	component_validate_frame(config.frame)!
	chat_validate_length('message avatar size', config.avatar_size)!
	chat_validate_length('message content width', config.content_width)!
	chat_validate_length('message content height', config.content_height)!
	for action in config.actions {
		if action.icon.len > 0 && !symbol_known(action.icon) {
			return error('unknown message action icon `${action.icon}`')
		}
		if action.label.len == 0 && action.icon.len == 0 {
			return error('a message action needs a label or an icon')
		}
	}
	if config.enabled && config.actions.len > 0 {
		component_validate_id(config.id)!
	}
	if chat_message_has_bubble(config) {
		member := chat_message_bubble(config, rect(0, 0, config.frame.width, 0), 0)
		if bubble_interactive(member) {
			component_validate_id(config.id)!
		}
		bubble_validate(member)!
	}
}

fn chat_message_label(config ChatMessageConfig) string {
	if config.accessibility_label.len > 0 {
		return config.accessibility_label
	}
	mut parts := []string{}
	for part in [config.author, config.timestamp, if config.status_text.len > 0 {
		config.status_text
	} else {
		message_status_text(config.status)
	}] {
		if part.len > 0 {
			parts << part
		}
	}
	return parts.join(', ')
}

// chat_message draws one message row: the sender's avatar, a header with name,
// badges and timestamp, a bubble and/or the application's own content, and a
// footer with the delivery status, a note and actions. Footer actions emit
// chat_message_action_id and the bubble's reactions their bubble actions;
// chat_message_event_from_action decodes both.
pub fn chat_message(config ChatMessageConfig) !Element {
	chat_message_validate(config)!
	return component_finish(chat_message_element(config, chat_message_layout(config))!)
}

fn chat_message_element(config ChatMessageConfig, layout ChatMessageLayout) !Element {
	m := chat_message_metrics(config.size)
	mut children := []Element{}
	if layout.header.height > 0 {
		children << chat_message_header(config, layout, m)
	}
	if layout.avatar.width > 0 {
		children << Element{
			...avatar(
				name:       config.author
				image_path: config.avatar_image
				frame:      layout.avatar
				theme:      if config.identity_colors && config.avatar_image.len == 0 {
					avatar_identity_theme(config.author, config.theme)
				} else {
					config.theme
				}
			)!
			key: 'avatar'
		}
	}
	if layout.bubble.height > 0 {
		member := chat_message_bubble(config, layout.column, layout.bubble.y)
		children << Element{
			...bubble_element(member, bubble_layout(member))
			key: 'bubble'
		}
	}
	if config.content.len > 0 {
		children << Element{
			...view('', layout.content, BoxStyle{ transparent: true }, config.content)
			key: 'content'
		}
	}
	if layout.footer.height > 0 {
		children << chat_message_footer(config, layout, m)
	}
	return Element{
		...view(config.id, rect(config.frame.x, config.frame.y, config.frame.width, math.max(config.frame.height,
			layout.height)), BoxStyle{ transparent: true }, children)
		accessibility_role:  'listitem'
		accessibility_label: chat_message_label(config)
	}
}

pub enum ChatMessageEventKind {
	action       // A footer action.
	reaction     // A reaction chip in the bubble.
	add_reaction // The bubble's add-reaction button.
}

pub struct ChatMessageEvent {
pub:
	kind     ChatMessageEventKind
	index    int    // Of the action or the reaction.
	name     string // The action's name or the reaction's emoji.
	selected bool   // Reaction: whether the viewer has it after the toggle.
}

// chat_message_event_from_action decodes an action a message emitted, against
// the application's current config. Foreign, malformed and out-of-range
// actions, disabled actions and a disabled message give none.
pub fn chat_message_event_from_action(config ChatMessageConfig, action string) ?ChatMessageEvent {
	if !config.enabled {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	if part.starts_with('action:') {
		if config.actions.len == 0 {
			return none
		}
		index := component_parse_index(part['action:'.len..], config.actions.len - 1) or {
			return none
		}
		if !config.actions[index].enabled {
			return none
		}
		return ChatMessageEvent{
			kind:  .action
			index: index
			name:  config.actions[index].name
		}
	}
	if !chat_message_has_bubble(config) {
		return none
	}
	event := bubble_reaction_from_action(chat_message_bubble(config, rect(0, 0, 0, 0), 0),
		action) or { return none }
	return match event.kind {
		.toggle {
			ChatMessageEvent{
				kind:     .reaction
				index:    event.index
				name:     event.emoji
				selected: event.selected
			}
		}
		.add {
			ChatMessageEvent{
				kind: .add_reaction
			}
		}
	}
}

pub struct ChatMessageGroupConfig {
pub:
	id string
	// frame is the group's row; the element is as tall as frame.height or its
	// messages (chat_message_group_height), whichever is more.
	frame Rect
	// messages are one sender's run, in order. The group sets their frame,
	// group position, size and theme.
	messages []ChatMessageConfig
	gap      f64           = -1 // Between messages; negative uses the bubble group's gap.
	size     ComponentSize = .medium
	theme    ComponentTheme
}

fn chat_message_group_gap(config ChatMessageGroupConfig) f64 {
	if config.gap >= 0 && component_finite(config.gap) {
		return config.gap
	}
	return bubble_metrics(config.size).group_gap
}

fn chat_message_group_member(config ChatMessageGroupConfig, index int, y f64) ChatMessageConfig {
	return ChatMessageConfig{
		...config.messages[index]
		frame:          rect(0, y, config.frame.width, 0)
		group_position: chat_run_position(index, config.messages.len)
		size:           config.size
		theme:          config.theme
	}
}

// chat_message_group_height is how tall chat_message_group draws config.
pub fn chat_message_group_height(config ChatMessageGroupConfig) f64 {
	gap := chat_message_group_gap(config)
	mut y := 0.0
	for index in 0 .. config.messages.len {
		if index > 0 {
			y += gap
		}
		y += chat_message_height(chat_message_group_member(config, index, y))
	}
	return y
}

// chat_message_group stacks one sender's consecutive messages: the header on
// the first, the avatar beside the last, and the bubbles joined in between.
pub fn chat_message_group(config ChatMessageGroupConfig) !Element {
	component_validate_frame(config.frame)!
	if !component_finite(config.gap) {
		return error('message group gap must be finite')
	}
	gap := chat_message_group_gap(config)
	mut children := []Element{cap: config.messages.len}
	mut y := 0.0
	for index in 0 .. config.messages.len {
		if index > 0 {
			y += gap
		}
		member := chat_message_group_member(config, index, y)
		chat_message_validate(member)!
		member_layout := chat_message_layout(member)
		children << Element{
			...chat_message_element(member, member_layout)!
			key: 'message:${index}'
		}
		y += member_layout.height
	}
	return component_finish(Element{
		...view(config.id, rect(config.frame.x, config.frame.y, config.frame.width, math.max(config.frame.height,
			y)), BoxStyle{ transparent: true }, children)
		accessibility_role: 'list'
	})
}

pub struct ChatMessageGroupEvent {
pub:
	index int // Of the message in the group.
	event ChatMessageEvent
}

// chat_message_group_event_from_action decodes an action from any message of a
// group, as chat_message_event_from_action does for one message.
pub fn chat_message_group_event_from_action(config ChatMessageGroupConfig, action string) ?ChatMessageGroupEvent {
	for index in 0 .. config.messages.len {
		member := chat_message_group_member(config, index, 0)
		if member.id.len == 0 {
			continue
		}
		if event := chat_message_event_from_action(member, action) {
			return ChatMessageGroupEvent{
				index: index
				event: event
			}
		}
	}
	return none
}
