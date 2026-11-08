module ui2

import math

// BubbleVariant selects a bubble's semantic surface. It changes colors and
// framing, never the content model.
pub enum BubbleVariant {
	filled      // Primary surface: the default, usually outgoing.
	secondary   // Neutral surface, usually incoming.
	muted       // Low-emphasis context, in the muted text color.
	tinted      // A subtle primary tint.
	outline     // Background surface with a visible border.
	ghost       // No surface, padding or radius; may use the whole row.
	destructive // Failed or invalid content; say so in the text too.
}

// BubbleReactionSide is the bubble edge the reaction region hangs from.
pub enum BubbleReactionSide {
	bottom
	top
}

// BubbleReaction is one reaction chip: an emoji, how many people chose it and
// whether the viewer is one of them. The application owns the list.
pub struct BubbleReaction {
pub:
	emoji    string
	count    int    // Shown after the emoji when above zero.
	selected bool   // The viewer reacted with it; the chip is highlighted.
	label    string // Accessible name such as 'Thumbs up'; defaults to the emoji.
}

pub struct BubbleConfig {
pub:
	id string // Required when the reactions are interactive.
	// frame is the row the bubble is aligned in: x, y and the width available.
	// The element is as tall as frame.height or its content, whichever is more;
	// pass 0 and use bubble_height to size a list row.
	frame Rect
	text  string // Wraps inside the bubble; newlines start new lines.
	// content is application-drawn rich content below the text, such as a file
	// card. Its frames are relative to a content_width x content_height box.
	content        []Element
	content_width  f64
	content_height f64
	alignment      MessageAlignment
	variant        BubbleVariant
	// max_width caps the surface's width; 0 allows 80% of the row (all of it
	// for a ghost bubble).
	max_width f64
	// max_lines above zero shows that many lines of text and ends the last one
	// with an ellipsis, for a collapsed long message.
	max_lines          int
	group_position     ChatGroupPosition // Set by bubble_group and chat_message.
	reactions          []BubbleReaction
	reaction_side      BubbleReactionSide
	reaction_alignment MessageAlignment = .end
	add_reaction       bool // Show an add-reaction button after the reactions.
	enabled            bool = true // False: reactions are shown but not interactive.
	background         ?u32 // Replaces the variant's fill.
	text_color         ?u32 // Replaces the variant's text color.
	border_color       ?u32 // Replaces the outline's border, or borders any variant.
	// surface_color is what the bubble sits on. The reaction region is ringed
	// with it so it reads as cut out of the bubble; defaults to the background.
	surface_color       ?u32
	font_size           f64 // 0 uses the size preset: 12, 14 or 16.
	size                ComponentSize = .medium
	theme               ComponentTheme
	accessibility_label string
}

// BubbleLayout is where a bubble puts its parts, relative to its element.
pub struct BubbleLayout {
pub:
	height    f64  // Of the whole element, reactions included.
	surface   Rect // The visible surface.
	text      Rect // The text label.
	content   Rect // The application's rich content.
	reactions Rect // The reaction region; empty without reactions.
	lines     int  // Lines of text drawn.
	truncated bool // max_lines cut the text short.
}

struct BubbleMetrics {
	font            f64
	pad_x           f64
	pad_y           f64
	radius          f64
	joined          f64
	gap             f64
	group_gap       f64
	reaction_height f64
	reaction_font   f64
	reaction_inside f64
	reaction_ring   f64
	chip_pad        f64
}

fn bubble_metrics(size ComponentSize) BubbleMetrics {
	return match size {
		.small {
			BubbleMetrics{12, 10, 6, 14, 4, 6, 2, 22, 11, 6, 2, 4}
		}
		.medium {
			BubbleMetrics{14, 12, 8, 17, 5, 8, 2, 26, 12, 8, 2, 5}
		}
		.large {
			BubbleMetrics{16, 14, 10, 20, 6, 10, 3, 30, 14, 10, 3, 6}
		}
	}
}

// bubble_reaction_action_id is the action a reaction chip emits.
pub fn bubble_reaction_action_id(id string, index int) string {
	return component_part_id(id, 'reaction:${index}')
}

// bubble_add_reaction_action_id is the action the add-reaction button emits.
pub fn bubble_add_reaction_action_id(id string) string {
	return component_part_id(id, 'add-reaction')
}

fn bubble_has_reactions(config BubbleConfig) bool {
	return config.reactions.len > 0 || config.add_reaction
}

fn bubble_interactive(config BubbleConfig) bool {
	return config.enabled && bubble_has_reactions(config)
}

// bubble_reaction_chips lays the chips out inside the reaction region: one per
// reaction, then the add button. It returns their frames, relative to the
// region, and the region's width.
fn bubble_reaction_chips(config BubbleConfig, m BubbleMetrics) ([]Rect, f64) {
	inset := m.reaction_ring + 1
	chip_height := m.reaction_height - 2 * inset
	emoji_box := math.round(font_em_pixels(m.reaction_font) * 1.4)
	mut chips := []Rect{cap: config.reactions.len + 1}
	mut x := inset
	for reaction in config.reactions {
		mut width := emoji_box + 2 * m.chip_pad
		if reaction.count > 0 {
			width += 2 + math.ceil(chat_text_width(reaction.count.str(), m.reaction_font, true))
		}
		chips << rect(x, inset, width, chip_height)
		x += width + 2
	}
	if config.add_reaction {
		width := chip_height + 2 * m.chip_pad - 2
		chips << rect(x, inset, width, chip_height)
		x += width + 2
	}
	return chips, x - 2 + inset
}

// bubble_layout computes where a bubble draws its surface, text, rich content
// and reactions, from estimates of the text: ui/ has no text measurement. A
// single line shrinks the bubble to its text; wrapping text widens it to its
// maximum, as CSS does with a max-width.
pub fn bubble_layout(config BubbleConfig) BubbleLayout {
	m := bubble_metrics(config.size)
	font := chat_font(config.font_size, m.font)
	ghost := config.variant == .ghost
	row := if component_finite(config.frame.width) { math.max(config.frame.width, 0) } else { 0.0 }
	pad_x := if ghost { 0.0 } else { m.pad_x }
	pad_y := if ghost { 0.0 } else { m.pad_y }
	cap := if config.max_width > 0 && component_finite(config.max_width) {
		math.min(config.max_width, row)
	} else if ghost {
		row
	} else {
		math.round(row * 0.8)
	}
	inner_cap := math.max(cap - 2 * pad_x, 0)
	max_lines := math.max(config.max_lines, 0)
	lines := chat_wrap(config.text, font, false, inner_cap, max_lines)
	truncated := max_lines > 0 && lines.len == max_lines
		&& chat_wrap(config.text, font, false, inner_cap, 0).len > max_lines
	text_width := if lines.len == 1 && !truncated {
		math.min(chat_widest(lines, font, false), inner_cap)
	} else if lines.len > 0 {
		inner_cap
	} else {
		0.0
	}
	text_height := chat_lines_height(lines.len, font)
	custom_width := math.min(chat_length(config.content_width), inner_cap)
	custom_height := chat_length(config.content_height)
	has_custom := config.content.len > 0 || custom_width > 0 || custom_height > 0
	inner_width := if ghost { inner_cap } else { math.max(text_width, custom_width) }
	inner_height := text_height + if lines.len > 0 && has_custom { m.gap } else { 0.0 } +
		custom_height
	surface_width := inner_width + 2 * pad_x
	surface_height := inner_height + 2 * pad_y
	has_reactions := bubble_has_reactions(config)
	_, region_width := bubble_reaction_chips(config, m)
	overhang := if has_reactions { m.reaction_height - m.reaction_inside } else { 0.0 }
	sy := if has_reactions && config.reaction_side == .top { overhang } else { 0.0 }
	sx := if config.alignment == .start { 0.0 } else { row - surface_width }
	surface := rect(sx, sy, surface_width, surface_height)
	mut reactions := rect(0, 0, 0, 0)
	if has_reactions {
		edge := math.max(pad_x, m.radius / 2)
		mut rx := if config.reaction_alignment == .end {
			sx + surface_width - edge - region_width
		} else {
			sx + edge
		}
		rx = math.max(0, math.min(rx, row - region_width))
		ry := if config.reaction_side == .top {
			0.0
		} else {
			sy + surface_height - m.reaction_inside
		}
		reactions = rect(rx, ry, region_width, m.reaction_height)
	}
	return BubbleLayout{
		height:    surface_height + overhang
		surface:   surface
		text:      rect(sx + pad_x, sy + pad_y, inner_width, text_height)
		content:   rect(sx + pad_x, sy + pad_y + inner_height - custom_height, custom_width,
			custom_height)
		reactions: reactions
		lines:     lines.len
		truncated: truncated
	}
}

// bubble_height is how tall bubble draws config: what a list gives the row.
pub fn bubble_height(config BubbleConfig) f64 {
	return bubble_layout(config).height
}

fn bubble_variant_colors(variant BubbleVariant, theme ComponentTheme) (u32, u32) {
	dark := chat_is_dark(theme)
	match variant {
		.filled {
			return theme.primary, theme.primary_foreground
		}
		.secondary {
			return theme.muted, theme.foreground
		}
		.muted {
			return chat_mix(theme.muted, theme.background, 0.4), theme.muted_foreground
		}
		.tinted {
			return chat_mix(theme.background, theme.primary, if dark { 0.24 } else { 0.12 }), theme.foreground
		}
		.outline, .ghost {
			return theme.background, theme.foreground
		}
		.destructive {
			return chat_mix(theme.background, theme.danger, if dark { 0.2 } else { 0.1 }), theme.danger
		}
	}
}

// bubble_colors returns the fill, text and border colors of a bubble, and
// whether it draws a border.
fn bubble_colors(config BubbleConfig) (u32, u32, u32, bool) {
	fill, fg := bubble_variant_colors(config.variant, config.theme)
	mut border := config.theme.border
	mut bordered := config.variant == .outline
	if color := config.border_color {
		border = color
		bordered = config.variant != .ghost
	}
	return config.background or { fill }, config.text_color or { fg }, border, bordered
}

fn bubble_validate(config BubbleConfig) ! {
	component_validate_frame(config.frame)!
	chat_validate_length('bubble max width', config.max_width)!
	chat_validate_length('bubble content width', config.content_width)!
	chat_validate_length('bubble content height', config.content_height)!
	chat_validate_length('bubble font size', config.font_size)!
	if config.max_lines < 0 {
		return error('bubble max lines must be non-negative')
	}
	if bubble_interactive(config) {
		component_validate_id(config.id)!
	}
}

// bubble draws a chat bubble: a surface aligned at the start or end of its
// row, holding wrapped text and optional rich content, with an optional row of
// reaction chips hanging from its top or bottom edge. Reaction chips emit
// bubble_reaction_action_id and the add button bubble_add_reaction_action_id;
// bubble_reaction_from_action decodes them.
pub fn bubble(config BubbleConfig) !Element {
	bubble_validate(config)!
	return component_finish(bubble_element(config, bubble_layout(config)))
}

fn bubble_element(config BubbleConfig, layout BubbleLayout) Element {
	m := bubble_metrics(config.size)
	fill, fg, border, bordered := bubble_colors(config)
	mut children := []Element{}
	if config.variant != .ghost {
		corners := chat_joined_corners(config.alignment, config.group_position)
		children << chat_surface(layout.surface, fill, border, if bordered { 1.0 } else { 0.0 },
			m.radius, m.joined, corners)
	}
	if layout.lines > 0 {
		// The estimate errs wide, so a renderer may need a line fewer than the
		// bubble has room for; centered, the spare room reads as padding. A single
		// line keeps a one-line budget: an AppKit label that may wrap draws its
		// text twice when its frame is barely wider than the text.
		children << label('', config.text, layout.text, TextStyle{
			color:  fg
			size:   chat_font(config.font_size, m.font)
			valign: .middle
			lines:  if config.max_lines > 0 {
				config.max_lines
			} else if layout.lines == 1 {
				1
			} else {
				0
			}
		})
	}
	if config.content.len > 0 {
		children << view('', layout.content, BoxStyle{ transparent: true }, config.content)
	}
	if bubble_has_reactions(config) {
		children << bubble_reactions(config, layout.reactions, m)
	}
	return Element{
		...view(config.id, rect(config.frame.x, config.frame.y, config.frame.width, math.max(config.frame.height,
			layout.height)), BoxStyle{ transparent: true }, children)
		accessibility_label: config.accessibility_label
	}
}

fn bubble_reaction_name(reaction BubbleReaction) string {
	name := if reaction.label.len > 0 { reaction.label } else { reaction.emoji }
	return match reaction.count {
		0 { name }
		1 { '${name}, 1 reaction' }
		else { '${name}, ${reaction.count} reactions' }
	}
}

fn bubble_reactions(config BubbleConfig, region Rect, m BubbleMetrics) Element {
	theme := config.theme
	dark := chat_is_dark(theme)
	interactive := bubble_interactive(config)
	ring_color := config.surface_color or { theme.background }
	chips, _ := bubble_reaction_chips(config, m)
	mut children := chat_surface(component_local(region), theme.muted, ring_color, m.reaction_ring,
		region.height / 2, region.height / 2, ChatCorners{})
	emoji_box := math.round(font_em_pixels(m.reaction_font) * 1.4)
	selected_fill := chat_mix(theme.muted, theme.primary, if dark { 0.3 } else { 0.16 })
	for index, chip in chips {
		adding := index >= config.reactions.len
		mut parts := []Element{}
		mut name := 'Add reaction'
		mut selected := false
		if adding {
			glyph := math.round(chip.height * 0.6)
			parts << chat_symbol('plus', rect((chip.width - glyph) / 2, (chip.height - glyph) / 2,
				glyph, glyph), theme.muted_foreground)
		} else {
			reaction := config.reactions[index]
			selected = reaction.selected
			name = bubble_reaction_name(reaction)
			if selected {
				parts << chat_surface(component_local(chip), selected_fill, theme.primary,
					1, chip.height / 2, chip.height / 2, ChatCorners{})
			}
			parts << label('', reaction.emoji, rect(m.chip_pad, 0, emoji_box, chip.height),
				TextStyle{
					color: theme.foreground
					size:  m.reaction_font
					align: .center
				})
			if reaction.count > 0 {
				x := m.chip_pad + emoji_box + 2
				parts << label('', reaction.count.str(), rect(x, 0, chip.width - x - m.chip_pad + 2,
					chip.height), TextStyle{
					color: if selected { theme.primary } else { theme.foreground }
					size:  m.reaction_font - 1
					bold:  selected
				})
			}
		}
		key := if adding { 'add' } else { 'reaction:${index}' }
		if interactive {
			mut el := Element{
				...button_view(if adding {
					bubble_add_reaction_action_id(config.id)
				} else {
					bubble_reaction_action_id(config.id, index)
				}, chip, BoxStyle{ transparent: true }, parts)
				key:                 key
				cursor:              cursor_pointing_hand
				accessibility_label: name
				accessibility_value: if adding {
					''
				} else if selected {
					'selected'
				} else {
					'not selected'
				}
			}
			if adding {
				el = with_tooltip(el, 'Add reaction')
			}
			children << el
		} else {
			children << Element{
				...view('', chip, BoxStyle{ transparent: true }, parts)
				key:                 key
				accessibility_role:  'text'
				accessibility_label: name
			}
		}
	}
	return Element{
		...view('', region, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: 'Reactions'
	}
}

pub enum BubbleReactionEventKind {
	toggle // A reaction chip: flip whether the viewer chose it.
	add    // The add-reaction button: offer a choice of emoji.
}

pub struct BubbleReactionEvent {
pub:
	kind     BubbleReactionEventKind
	index    int    // The chip's reaction (toggle).
	emoji    string // Its emoji (toggle).
	selected bool   // Whether the viewer has it after the toggle.
}

// bubble_reaction_from_action decodes an action a bubble emitted, against the
// application's current config. Foreign, malformed and out-of-range actions,
// an add button the bubble does not show and a disabled bubble give none.
pub fn bubble_reaction_from_action(config BubbleConfig, action string) ?BubbleReactionEvent {
	if !bubble_interactive(config) {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	if part == 'add-reaction' {
		if !config.add_reaction {
			return none
		}
		return BubbleReactionEvent{
			kind: .add
		}
	}
	if !part.starts_with('reaction:') || config.reactions.len == 0 {
		return none
	}
	index := component_parse_index(part['reaction:'.len..], config.reactions.len - 1) or {
		return none
	}
	reaction := config.reactions[index]
	return BubbleReactionEvent{
		kind:     .toggle
		index:    index
		emoji:    reaction.emoji
		selected: !reaction.selected
	}
}

// bubble_toggle_reaction returns reactions with the viewer's emoji reaction
// toggled: chosen again it is withdrawn (and dropped when nobody else chose
// it), otherwise it is added, as a new chip at the end if none has the emoji.
pub fn bubble_toggle_reaction(reactions []BubbleReaction, emoji string) []BubbleReaction {
	mut out := []BubbleReaction{cap: reactions.len + 1}
	if emoji.len == 0 {
		out << reactions
		return out
	}
	mut found := false
	for reaction in reactions {
		if reaction.emoji != emoji {
			out << reaction
			continue
		}
		found = true
		if reaction.selected {
			count := math.max(reaction.count - 1, 0)
			if count > 0 {
				out << BubbleReaction{
					...reaction
					count:    count
					selected: false
				}
			}
		} else {
			out << BubbleReaction{
				...reaction
				count:    math.max(reaction.count, 0) + 1
				selected: true
			}
		}
	}
	if !found {
		out << BubbleReaction{
			emoji:    emoji
			count:    1
			selected: true
		}
	}
	return out
}

pub struct BubbleGroupConfig {
pub:
	id string
	// frame is the row the bubbles are aligned in; the element is as tall as
	// frame.height or its bubbles (bubble_group_height), whichever is more.
	frame Rect
	// bubbles are stacked in order. The group sets their frame, alignment,
	// group position, size and theme; everything else is theirs.
	bubbles   []BubbleConfig
	alignment MessageAlignment
	joined    bool          = true // Tighten the corners where consecutive bubbles meet.
	gap       f64           = -1   // Between bubbles; negative uses the preset (2 joined, 8 apart).
	size      ComponentSize = .medium
	theme     ComponentTheme
}

fn bubble_group_gap(config BubbleGroupConfig) f64 {
	if config.gap >= 0 && component_finite(config.gap) {
		return config.gap
	}
	return if config.joined { bubble_metrics(config.size).group_gap } else { 8.0 }
}

// chat_run_position is the position of the index-th of count joined items.
fn chat_run_position(index int, count int) ChatGroupPosition {
	if count <= 1 {
		return .single
	}
	return if index == 0 {
		ChatGroupPosition.first
	} else if index == count - 1 {
		ChatGroupPosition.last
	} else {
		ChatGroupPosition.middle
	}
}

// bubble_group_member is the config the group draws its index-th bubble with,
// at y in the group.
fn bubble_group_member(config BubbleGroupConfig, index int, y f64) BubbleConfig {
	return BubbleConfig{
		...config.bubbles[index]
		frame:          rect(0, y, config.frame.width, 0)
		alignment:      config.alignment
		group_position: if config.joined {
			chat_run_position(index, config.bubbles.len)
		} else {
			ChatGroupPosition.single
		}
		size:           config.size
		theme:          config.theme
	}
}

// bubble_group_height is how tall bubble_group draws config.
pub fn bubble_group_height(config BubbleGroupConfig) f64 {
	gap := bubble_group_gap(config)
	mut y := 0.0
	for index in 0 .. config.bubbles.len {
		if index > 0 {
			y += gap
		}
		y += bubble_height(bubble_group_member(config, index, y))
	}
	return y
}

// bubble_group stacks consecutive bubbles from one sender. The application
// decides which bubbles belong together; joined bubbles get the tighter
// corners on the sender's side where they meet.
pub fn bubble_group(config BubbleGroupConfig) !Element {
	component_validate_frame(config.frame)!
	if !component_finite(config.gap) {
		return error('bubble group gap must be finite')
	}
	gap := bubble_group_gap(config)
	mut children := []Element{cap: config.bubbles.len}
	mut y := 0.0
	for index in 0 .. config.bubbles.len {
		if index > 0 {
			y += gap
		}
		member := bubble_group_member(config, index, y)
		bubble_validate(member)!
		member_layout := bubble_layout(member)
		children << Element{
			...bubble_element(member, member_layout)
			key: 'bubble:${index}'
		}
		y += member_layout.height
	}
	return component_finish(view(config.id, rect(config.frame.x, config.frame.y, config.frame.width,
		math.max(config.frame.height, y)), BoxStyle{ transparent: true }, children))
}
