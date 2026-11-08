module ui2

import math

fn chat_test_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := chat_test_find(child, id) {
			return found
		}
	}
	return none
}

fn chat_test_labels(el Element) []string {
	mut out := []string{}
	if el.kind == .label {
		out << el.text
	}
	for child in el.children {
		out << chat_test_labels(child)
	}
	return out
}

fn chat_test_count_bg(el Element, color u32) int {
	mut count := if el.kind == .view && !el.box.transparent && el.box.bg == color { 1 } else { 0 }
	for child in el.children {
		count += chat_test_count_bg(child, color)
	}
	return count
}

fn chat_test_contains(outer Rect, inner Rect) bool {
	return inner.x >= outer.x - 0.001 && inner.y >= outer.y - 0.001
		&& inner.x + inner.width <= outer.x + outer.width + 0.001
		&& inner.y + inner.height <= outer.y + outer.height + 0.001
}

// ── Shared ─────────────────────────────────────────────────────────

fn test_chat_group_positions_follow_runs_of_equal_keys() {
	assert chat_group_positions([]string{}) == []ChatGroupPosition{}
	assert chat_group_positions(['a']) == [ChatGroupPosition.single]
	assert chat_group_positions(['a', 'a', 'a', 'b', '', '', 'b', 'b']) == [
		ChatGroupPosition.first,
		.middle,
		.last,
		.single,
		.single,
		.single,
		.first,
		.last,
	]
	assert chat_run_position(0, 1) == .single
	assert chat_run_position(0, 3) == .first
	assert chat_run_position(1, 3) == .middle
	assert chat_run_position(2, 3) == .last
}

fn test_chat_text_estimates_wrap_and_count_emoji() {
	plain := chat_text_width('Hello', 14, false)
	assert plain > 0
	assert chat_text_width('Hello', 14, true) > plain
	// An emoji is wider than an em; its variation selector draws nothing.
	heart := chat_text_width('❤️', 14, false)
	assert heart > font_em_pixels(14)
	assert heart == chat_text_width('❤', 14, false)
	assert chat_text_width('👍🏽', 14, false) == chat_text_width('👍', 14, false)
	assert chat_wrap('', 14, false, 200, 0).len == 0
	long := 'one two three four five six seven eight nine ten eleven twelve'
	lines := chat_wrap(long, 14, false, 120, 0)
	assert lines.len > 2
	for line in lines {
		assert chat_text_width(line, 14, false) <= 120 || !line.contains(' ')
	}
	assert chat_wrap(long, 14, false, 120, 2).len == 2
	assert chat_wrap('a\nb', 14, false, 400, 0).len == 2
	assert chat_wrap('a\nb', 14, false, 400, 1) == ['a b']
	assert chat_lines_height(0, 14) == 0
	assert chat_lines_height(1, 14) == math.ceil(font_line_height(14))
	assert chat_lines_height(3, 14) > 3 * font_line_height(14)
}

fn test_chat_identity_colors_are_stable_and_legible() {
	bg, fg := avatar_identity_colors('Maya Chen', false)
	bg2, fg2 := avatar_identity_colors('Maya Chen', false)
	assert bg == bg2 && fg == fg2
	dark_bg, _ := avatar_identity_colors('Maya Chen', true)
	assert dark_bg != bg
	for table in [chat_identity_light, chat_identity_dark] {
		assert table.len == 24
		for i := 0; i < table.len; i += 2 {
			a := chat_test_relative_luminance(table[i])
			b := chat_test_relative_luminance(table[i + 1])
			ratio := (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
			assert ratio >= 4.5, 'identity pair ${i / 2} has contrast ${ratio}'
		}
	}
	theme := avatar_identity_theme('Leo Park', component_theme(true))
	lb, lf := avatar_identity_colors('Leo Park', true)
	assert theme.muted == lb
	assert theme.foreground == lf
	assert theme.background == component_theme(true).background
}

fn chat_test_relative_luminance(color u32) f64 {
	mut channels := []f64{}
	for shift in [u32(16), 8, 0] {
		c := f64((color >> shift) & 0xff) / 255
		channels << if c <= 0.03928 { c / 12.92 } else { math.pow((c + 0.055) / 1.055, 2.4) }
	}
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
}

fn test_chat_surface_tightens_only_the_named_corners() {
	frame := rect(10, 20, 100, 40)
	plain := chat_surface(frame, 0x112233, 0, 0, 16, 4, ChatCorners{})
	assert plain.len == 1
	assert plain[0].box.radius == 16
	joined := chat_surface(frame, 0x112233, 0, 0, 16, 4, chat_joined_corners(.start, .middle))
	assert joined.len == 3
	// Patches sit in the left corners and reach past the round corner.
	assert joined[1].frame == rect(10, 20, 20, 20)
	assert joined[2].frame == rect(10, 40, 20, 20)
	assert joined[1].box.radius == 4
	end := chat_surface(frame, 0x112233, 0, 0, 16, 4, chat_joined_corners(.end, .first))
	assert end.len == 2
	assert end[1].frame == rect(90, 40, 20, 20)
	// A border is a border-colored shape with the fill inset over it.
	outlined := chat_surface(frame, 0xffffff, 0x999999, 1, 16, 4, chat_joined_corners(.start,
		.last))
	assert outlined.len == 4
	assert outlined[0].box.bg == 0x999999
	assert outlined[2].box.bg == 0xffffff
	assert outlined[2].frame == rect(11, 21, 98, 38)
	assert outlined[2].box.radius == 15
	assert chat_joined_corners(.start, .single) == ChatCorners{}
	assert chat_joined_corners(.end, .last) == ChatCorners{
		top_right: true
	}
}

// ── Bubble ─────────────────────────────────────────────────────────

fn test_bubble_shrinks_to_short_text_and_aligns_in_its_row() {
	short := BubbleConfig{
		frame: rect(0, 0, 400, 0)
		text:  'Hi!'
	}
	layout := bubble_layout(short)
	assert layout.lines == 1
	assert layout.surface.x == 0
	assert layout.surface.width < 80
	assert layout.surface.width >= chat_text_width('Hi!', 14, false) + 24
	assert layout.height == layout.surface.height
	end_layout := bubble_layout(BubbleConfig{
		...short
		alignment: .end
	})
	assert end_layout.surface.x + end_layout.surface.width == 400
	assert end_layout.surface.width == layout.surface.width
	el := bubble(short) or { panic(err) }
	assert el.frame.height == layout.height
	assert chat_test_labels(el) == ['Hi!']
	assert el.children.filter(it.kind == .label)[0].text_style.lines == 1
	// A taller frame is kept.
	tall := bubble(BubbleConfig{
		...short
		frame: rect(5, 6, 400, 200)
	}) or { panic(err) }
	assert tall.frame == rect(5, 6, 400, 200)
}

fn test_bubble_wraps_long_text_at_its_maximum_width() {
	text := 'Good catch. I moved the permissions step after the first project is created, so people see why we ask before we ask.'
	config := BubbleConfig{
		frame: rect(0, 0, 400, 0)
		text:  text
	}
	layout := bubble_layout(config)
	assert layout.lines > 1
	assert layout.surface.width == 320 // 80% of the row.
	assert layout.text.width == 320 - 24
	assert layout.surface.height == chat_lines_height(layout.lines, 14) + 16
	assert bubble_height(config) == layout.height
	capped := bubble_layout(BubbleConfig{
		...config
		max_width: 200
	})
	assert capped.surface.width == 200
	assert capped.lines > layout.lines
	collapsed := bubble_layout(BubbleConfig{
		...config
		max_lines: 2
	})
	assert collapsed.lines == 2
	assert collapsed.truncated
	assert !layout.truncated
	label_el := (bubble(BubbleConfig{ ...config, max_lines: 2 }) or { panic(err) }).children.filter(it.kind == .label)[0]
	assert label_el.text_style.lines == 2
	assert label_el.text_style.valign == .middle
	wrapped := (bubble(config) or { panic(err) }).children.filter(it.kind == .label)[0]
	assert wrapped.text_style.lines == 0
	ghost := bubble_layout(BubbleConfig{
		...config
		variant: .ghost
	})
	assert ghost.surface.width == 400
	assert ghost.text.x == 0
	assert ghost.text.width == 400
}

fn test_bubble_places_rich_content_below_the_text() {
	card := view('card', rect(0, 0, 180, 40), BoxStyle{}, []Element{})
	config := BubbleConfig{
		frame:          rect(0, 0, 400, 0)
		text:           'Here is the file:'
		content:        [card]
		content_width:  180
		content_height: 40
	}
	layout := bubble_layout(config)
	assert layout.content.width == 180
	assert layout.content.y == layout.text.y + layout.text.height + bubble_metrics(.medium).gap
	assert layout.surface.width == 180 + 24
	assert layout.surface.height == layout.text.height + 8 + 40 + 16
	el := bubble(config) or { panic(err) }
	holder := chat_test_find(el, 'card') or { panic('card missing') }
	assert holder.frame == rect(0, 0, 180, 40)
	only := bubble_layout(BubbleConfig{
		frame:          rect(0, 0, 400, 0)
		content_width:  500
		content_height: 30
	})
	assert only.lines == 0
	assert only.content.width == 320 - 24
	assert only.content.y == 8
}

fn test_bubble_variant_colors_follow_the_theme() {
	light := component_theme(false)
	dark := component_theme(true)
	fill, fg, _, bordered := bubble_colors(BubbleConfig{ theme: light })
	assert fill == light.primary && fg == light.primary_foreground && !bordered
	secondary, _, _, _ := bubble_colors(BubbleConfig{
		variant: .secondary
		theme:   light
	})
	assert secondary == light.muted
	_, _, border, outline := bubble_colors(BubbleConfig{
		variant: .outline
		theme:   dark
	})
	assert outline && border == dark.border
	tinted_light, _, _, _ := bubble_colors(BubbleConfig{
		variant: .tinted
		theme:   light
	})
	tinted_dark, _, _, _ := bubble_colors(BubbleConfig{
		variant: .tinted
		theme:   dark
	})
	assert tinted_light == chat_mix(light.background, light.primary, 0.12)
	assert tinted_dark == chat_mix(dark.background, dark.primary, 0.24)
	bad, bad_fg, _, _ := bubble_colors(BubbleConfig{
		variant: .destructive
		theme:   light
	})
	assert bad_fg == light.danger
	assert bad != light.danger
	custom, custom_fg, custom_border, custom_bordered := bubble_colors(BubbleConfig{
		variant:      .secondary
		background:   0x123456
		text_color:   0xabcdef
		border_color: 0x00ff00
	})
	assert custom == 0x123456 && custom_fg == 0xabcdef
	assert custom_bordered && custom_border == 0x00ff00
	_, _, _, ghost_bordered := bubble_colors(BubbleConfig{
		variant:      .ghost
		border_color: 0x00ff00
	})
	assert !ghost_bordered
	ghost := bubble(BubbleConfig{
		variant: .ghost
		text:    'Plain'
	}) or { panic(err) }
	assert ghost.children.len == 1
	assert ghost.children[0].kind == .label
}

fn test_bubble_reactions_hang_from_the_edge_and_toggle() {
	config := BubbleConfig{
		id:           'b1'
		frame:        rect(0, 0, 400, 0)
		text:         'Shipped!'
		alignment:    .start
		reactions:    [BubbleReaction{
			emoji: '👍'
			count: 2
		}, BubbleReaction{
			emoji:    '🎉'
			count:    1
			selected: true
			label:    'Party'
		}]
		add_reaction: true
	}
	m := bubble_metrics(.medium)
	layout := bubble_layout(config)
	assert layout.surface.y == 0
	assert layout.reactions.height == m.reaction_height
	assert layout.reactions.y == layout.surface.height - m.reaction_inside
	assert layout.height == layout.surface.height + m.reaction_height - m.reaction_inside
	assert layout.reactions.x >= 0
	assert layout.reactions.x + layout.reactions.width <= 400
	top := bubble_layout(BubbleConfig{
		...config
		reaction_side:      .top
		reaction_alignment: .start
	})
	assert top.reactions.y == 0
	assert top.surface.y == m.reaction_height - m.reaction_inside
	assert top.reactions.x == top.surface.x + m.radius / 2 + 3.5 || top.reactions.x == m.pad_x
	el := bubble(config) or { panic(err) }
	first := chat_test_find(el, bubble_reaction_action_id('b1', 0)) or { panic('chip missing') }
	assert first.button_behavior
	assert first.accessibility_label == '👍, 2 reactions'
	assert first.accessibility_value == 'not selected'
	second := chat_test_find(el, bubble_reaction_action_id('b1', 1)) or { panic('chip missing') }
	assert second.accessibility_label == 'Party, 1 reaction'
	assert second.accessibility_value == 'selected'
	add := chat_test_find(el, bubble_add_reaction_action_id('b1')) or { panic('add missing') }
	assert add.accessibility_label == 'Add reaction'
	assert add.tooltip == 'Add reaction'
	chips, width := bubble_reaction_chips(config, m)
	assert chips.len == 3
	assert width == layout.reactions.width
	for chip in chips {
		assert chat_test_contains(rect(0, 0, width, m.reaction_height), chip)
	}
	// Decoding against the current config.
	toggle := bubble_reaction_from_action(config, bubble_reaction_action_id('b1', 1)) or {
		panic('toggle rejected')
	}
	assert toggle.kind == .toggle
	assert toggle.index == 1
	assert toggle.emoji == '🎉'
	assert !toggle.selected
	added := bubble_reaction_from_action(config, bubble_add_reaction_action_id('b1')) or {
		panic('add rejected')
	}
	assert added.kind == .add
	for forged in [bubble_reaction_action_id('b1', 2), 'b1:component:reaction:01',
		'b1:component:reaction:-1', 'b1:component:reaction:', 'b2:component:reaction:0', 'b1',
		'b1:component:reactions:0', 'b1:component:reaction:99999999999999999999'] {
		if _ := bubble_reaction_from_action(config, forged) {
			assert false, 'accepted ${forged}'
		}
	}
	if _ := bubble_reaction_from_action(BubbleConfig{ ...config, enabled: false }, bubble_reaction_action_id('b1',
		0))
	{
		assert false, 'disabled bubble accepted a reaction'
	}
	if _ := bubble_reaction_from_action(BubbleConfig{ ...config, add_reaction: false }, bubble_add_reaction_action_id('b1'))
	{
		assert false, 'hidden add button accepted'
	}
	// A disabled bubble still shows its reactions, without buttons.
	still := bubble(BubbleConfig{ ...config, enabled: false }) or { panic(err) }
	if _ := chat_test_find(still, bubble_reaction_action_id('b1', 0)) {
		assert false, 'disabled chip is a button'
	}
	assert '👍' in chat_test_labels(still)
	if _ := bubble(BubbleConfig{ ...config, id: '' }) {
		assert false, 'interactive reactions accepted without an id'
	}
}

fn test_bubble_toggle_reaction_counts_the_viewer() {
	start := [BubbleReaction{
		emoji: '👍'
		count: 2
	}, BubbleReaction{
		emoji:    '🎉'
		count:    1
		selected: true
	}]
	liked := bubble_toggle_reaction(start, '👍')
	assert liked[0].count == 3 && liked[0].selected
	unliked := bubble_toggle_reaction(liked, '👍')
	assert unliked[0].count == 2 && !unliked[0].selected
	// The viewer was the only one: the chip goes.
	no_party := bubble_toggle_reaction(start, '🎉')
	assert no_party.len == 1
	assert no_party[0].emoji == '👍'
	more := bubble_toggle_reaction(start, '🔥')
	assert more.len == 3
	assert more[2] == BubbleReaction{
		emoji:    '🔥'
		count:    1
		selected: true
	}
	assert bubble_toggle_reaction(start, '') == start
	assert start[0].count == 2 // The input is left alone.
}

fn test_bubble_rejects_bad_geometry() {
	for config in [BubbleConfig{
		frame: rect(0, 0, -1, 0)
	}, BubbleConfig{
		max_width: math.nan()
	}, BubbleConfig{
		content_height: -1
	}, BubbleConfig{
		font_size: math.inf(1)
	}, BubbleConfig{
		max_lines: -1
	}] {
		if _ := bubble(config) {
			assert false, 'bad bubble accepted'
		}
	}
	// The layout itself never fails, so a list can size rows from any input.
	assert bubble_layout(BubbleConfig{ frame: rect(0, 0, math.nan(), 0), text: 'x' }).surface.x <= 0
}

fn test_bubble_group_joins_corners_and_stacks() {
	light := component_theme(false)
	config := BubbleGroupConfig{
		id:        'group'
		frame:     rect(10, 20, 400, 0)
		alignment: .end
		bubbles:   [BubbleConfig{
			text: 'First'
		}, BubbleConfig{
			text: 'Second'
		}, BubbleConfig{
			text: 'Third'
		}]
		theme:     light
	}
	el := bubble_group(config) or { panic(err) }
	assert el.children.len == 3
	gap := bubble_metrics(.medium).group_gap
	single := bubble_height(BubbleConfig{
		frame: rect(0, 0, 400, 0)
		text:  'First'
	})
	assert bubble_group_height(config) == 3 * single + 2 * gap
	assert el.frame == rect(10, 20, 400, bubble_group_height(config))
	assert el.children[1].frame.y == single + gap
	// The first bubble tightens one corner, the middle two, the last one.
	assert chat_test_count_bg(el.children[0], light.primary) == 2
	assert chat_test_count_bg(el.children[1], light.primary) == 3
	assert chat_test_count_bg(el.children[2], light.primary) == 2
	// Every bubble sits at the end of the row.
	for child in el.children {
		surface := child.children[0]
		assert surface.frame.x + surface.frame.width == 400
	}
	apart := bubble_group(BubbleGroupConfig{
		...config
		joined: false
	}) or { panic(err) }
	assert chat_test_count_bg(apart.children[1], light.primary) == 1
	assert apart.children[1].frame.y == single + 8
	if _ := bubble_group(BubbleGroupConfig{ ...config, gap: math.nan() }) {
		assert false, 'NaN gap accepted'
	}
}

// ── Message ────────────────────────────────────────────────────────

fn chat_test_message() ChatMessageConfig {
	return ChatMessageConfig{
		id:        'm1'
		frame:     rect(0, 0, 500, 0)
		author:    'Maya Chen'
		timestamp: '9:41 AM'
		badges:    ['Design']
		bubble:    BubbleConfig{
			text:    'Did you get a chance to look at the new onboarding flow?'
			variant: .secondary
		}
		status:    .read
		actions:   [MessageAction{
			name:  'reply'
			label: 'Reply'
			icon:  'arrow.uturn.backward'
		}, MessageAction{
			name:    'copy'
			icon:    'doc.on.doc'
			tooltip: 'Copy text'
		}, MessageAction{
			name:    'delete'
			icon:    'trash'
			enabled: false
		}]
	}
}

fn test_chat_message_layout_stacks_header_bubble_and_footer() {
	config := chat_test_message()
	m := chat_message_metrics(.medium)
	layout := chat_message_layout(config)
	assert layout.column.x == m.avatar + m.avatar_gap
	assert layout.column.width == 500 - layout.column.x
	assert layout.header.y == 0
	assert layout.header.height > 0
	assert layout.bubble.y == layout.header.height + m.meta_gap
	assert layout.surface.x == layout.column.x
	// The avatar is flush with the bottom of the bubble's surface.
	assert layout.avatar == rect(0, layout.surface.y + layout.surface.height - m.avatar,
		m.avatar, m.avatar)
	assert layout.footer.y == layout.bubble.y + layout.bubble.height + m.meta_gap
	assert layout.footer.height == m.action
	assert layout.height == layout.footer.y + layout.footer.height
	assert chat_message_height(config) == layout.height
	assert layout.inset == bubble_metrics(.medium).pad_x
	end_layout := chat_message_layout(ChatMessageConfig{
		...config
		alignment: .end
	})
	assert end_layout.column.x == 0
	assert end_layout.avatar.x == 500 - m.avatar
	assert end_layout.surface.x + end_layout.surface.width == end_layout.column.width
}

fn test_chat_message_renders_its_parts() {
	config := chat_test_message()
	el := chat_message(config) or { panic(err) }
	assert el.id == 'm1'
	assert el.accessibility_role == 'listitem'
	assert el.accessibility_label == 'Maya Chen, 9:41 AM, Read'
	texts := chat_test_labels(el)
	for want in ['Maya Chen', 'Design', '9:41 AM', 'MC', 'Read', 'Reply',
		'Did you get a chance to look at the new onboarding flow?'] {
		assert want in texts, 'missing ${want}'
	}
	bubble_el := chat_test_find(el, chat_message_bubble_id('m1')) or { panic('bubble missing') }
	assert bubble_el.frame.y == chat_message_layout(config).bubble.y
	reply := chat_test_find(el, chat_message_action_id('m1', 0)) or { panic('reply missing') }
	assert reply.button_behavior
	assert reply.accessibility_label == 'Reply'
	copy := chat_test_find(el, chat_message_action_id('m1', 1)) or { panic('copy missing') }
	assert copy.accessibility_label == 'copy'
	assert copy.tooltip == 'Copy text'
	deleted := chat_test_find(el, chat_message_action_id('m1', 2)) or { panic('delete missing') }
	assert !deleted.enabled
	// Every part stays inside the row.
	for child in el.children {
		assert chat_test_contains(rect(0, 0, el.frame.width, el.frame.height), child.frame)
	}
}

fn test_chat_message_groups_show_header_first_and_avatar_last() {
	base := chat_test_message()
	first := chat_message_layout(ChatMessageConfig{
		...base
		group_position: .first
	})
	assert first.header.height > 0
	assert first.avatar.width == 0
	middle := chat_message_layout(ChatMessageConfig{
		...base
		group_position: .middle
	})
	assert middle.header.height == 0
	assert middle.avatar.width == 0
	assert middle.column.x == first.column.x // The column is kept.
	last := chat_message_layout(ChatMessageConfig{
		...base
		group_position: .last
	})
	assert last.header.height == 0
	assert last.avatar.width > 0
	no_column := chat_message_layout(ChatMessageConfig{
		...base
		show_avatar: false
	})
	assert no_column.column.x == 0
	assert no_column.avatar.width == 0
	group := ChatMessageGroupConfig{
		id:       'run'
		frame:    rect(0, 40, 500, 0)
		messages: [ChatMessageConfig{
			...base
			id: 'a'
		}, ChatMessageConfig{
			...base
			id:      'b'
			actions: []
			status:  .none
		}]
	}
	el := chat_message_group(group) or { panic(err) }
	assert el.children.len == 2
	assert el.frame.height == chat_message_group_height(group)
	assert el.children[1].frame.y == el.children[0].frame.height + bubble_metrics(.medium).group_gap
	assert 'Maya Chen' in chat_test_labels(el.children[0])
	assert 'Maya Chen' !in chat_test_labels(el.children[1])
	assert 'MC' !in chat_test_labels(el.children[0])
	assert 'MC' in chat_test_labels(el.children[1])
	event := chat_message_group_event_from_action(group, chat_message_action_id('a', 0)) or {
		panic('group action rejected')
	}
	assert event.index == 0
	assert event.event.name == 'reply'
	if _ := chat_message_group_event_from_action(group, chat_message_action_id('b', 0)) {
		assert false, 'action of a message without actions accepted'
	}
}

fn test_chat_message_ghost_content_drops_the_inset() {
	base := chat_test_message()
	ghost := chat_message_layout(ChatMessageConfig{
		...base
		bubble: BubbleConfig{
			...base.bubble
			variant: .ghost
		}
	})
	assert ghost.inset == 0
	kept := chat_message_layout(ChatMessageConfig{
		...base
		bubble:        BubbleConfig{
			...base.bubble
			variant: .ghost
		}
		content_inset: true
	})
	assert kept.inset == bubble_metrics(.medium).pad_x
	dropped := chat_message_layout(ChatMessageConfig{
		...base
		content_inset: false
	})
	assert dropped.inset == 0
}

fn test_chat_message_custom_content_and_status() {
	card := view('file-card', rect(0, 0, 220, 48), BoxStyle{}, []Element{})
	config := ChatMessageConfig{
		frame:          rect(0, 0, 500, 0)
		alignment:      .end
		author:         'You'
		show_header:    false
		content:        [card]
		content_width:  220
		content_height: 48
		status:         .failed
	}
	layout := chat_message_layout(config)
	assert layout.bubble.height == 0
	assert layout.content.x + layout.content.width == layout.column.width
	assert layout.avatar.y + layout.avatar.height == layout.content.y + layout.content.height
	el := chat_message(config) or { panic(err) }
	assert 'Not delivered' in chat_test_labels(el)
	assert message_status_text(.sending) == 'Sending…'
	assert message_status_text(.none) == ''
	custom := chat_message(ChatMessageConfig{
		...config
		status_text: 'Tap to retry'
	}) or { panic(err) }
	assert 'Tap to retry' in chat_test_labels(custom)
}

fn test_chat_message_events_decode_actions_and_reactions() {
	base := chat_test_message()
	config := ChatMessageConfig{
		...base
		bubble: BubbleConfig{
			...base.bubble
			reactions:    [BubbleReaction{
				emoji: '❤️'
				count: 1
			}]
			add_reaction: true
		}
	}
	reply := chat_message_event_from_action(config, chat_message_action_id('m1', 0)) or {
		panic('reply rejected')
	}
	assert reply.kind == .action
	assert reply.name == 'reply'
	bubble_id := chat_message_bubble_id('m1')
	heart := chat_message_event_from_action(config, bubble_reaction_action_id(bubble_id,
		0)) or { panic('reaction rejected') }
	assert heart.kind == .reaction
	assert heart.name == '❤️'
	assert heart.selected
	add := chat_message_event_from_action(config, bubble_add_reaction_action_id(bubble_id)) or {
		panic('add rejected')
	}
	assert add.kind == .add_reaction
	for forged in [chat_message_action_id('m1', 2), chat_message_action_id('m1', 3),
		'm1:component:action:', 'm2:component:action:0', bubble_reaction_action_id(bubble_id, 1),
		'm1:component:bubble', 'm1:component:other:0'] {
		if _ := chat_message_event_from_action(config, forged) {
			assert false, 'accepted ${forged}'
		}
	}
	if _ := chat_message_event_from_action(ChatMessageConfig{ ...config, enabled: false }, chat_message_action_id('m1',
		0))
	{
		assert false, 'disabled message accepted an action'
	}
	if _ := chat_message(ChatMessageConfig{ ...config, id: '' }) {
		assert false, 'interactive message accepted without an id'
	}
	if _ := chat_message(ChatMessageConfig{
		...base
		actions: [MessageAction{
			name: 'x'
			icon: 'no.such.symbol'
		}]
	})
	{
		assert false, 'unknown icon accepted'
	}
	if _ := chat_message(ChatMessageConfig{
		...base
		actions: [MessageAction{
			name: 'x'
		}]
	})
	{
		assert false, 'empty action accepted'
	}
}

// ── Marker ─────────────────────────────────────────────────────────

fn test_marker_separator_centers_its_label_between_lines() {
	config := MarkerConfig{
		frame:   rect(0, 0, 400, 0)
		text:    'Today'
		variant: .separator
	}
	layout := marker_layout(config)
	assert marker_alignment(config) == .center
	assert layout.leading.x == 0
	assert layout.leading.height == 1
	assert layout.trailing.x + layout.trailing.width == 400
	assert math.abs((layout.surface.x + layout.surface.width / 2) - 200) <= 1
	assert layout.leading.x + layout.leading.width < layout.text.x
	assert layout.trailing.x > layout.text.x + layout.text.width
	assert layout.height == layout.text.height
	el := marker(config) or { panic(err) }
	lines := el.children.filter(it.kind == .view)
	assert lines.len == 2
	assert lines[0].box.bg == component_theme(false).border
	label_el := el.children.filter(it.kind == .label)[0]
	assert label_el.text == 'Today'
	assert label_el.text_style.align == .center
	start := marker_layout(MarkerConfig{
		...config
		alignment: .start
	})
	assert start.leading.width == 0
	assert start.text.x == 0
	assert start.trailing.width > 0
	end := marker_layout(MarkerConfig{
		...config
		alignment: .end
	})
	assert end.trailing.width == 0
	assert end.surface.x + end.surface.width == 400
}

fn test_marker_border_icon_action_and_wrapping() {
	m := marker_metrics(.medium)
	config := MarkerConfig{
		id:           'unread'
		frame:        rect(0, 0, 400, 0)
		text:         '3 unread messages'
		icon:         'bell'
		variant:      .border
		action_label: 'Jump'
	}
	layout := marker_layout(config)
	assert layout.icon.width == m.icon
	assert layout.text.x == m.icon + m.gap
	assert layout.action.x == layout.text.x + layout.text.width + m.gap
	assert layout.border == rect(0, layout.surface.height + m.border_pad, 400, 1)
	assert layout.height == layout.border.y + 1
	assert marker_height(config) == layout.height
	el := marker(config) or { panic(err) }
	jump := chat_test_find(el, marker_action_id('unread')) or { panic('action missing') }
	assert jump.text == 'Jump'
	assert marker_action_activated(config, marker_action_id('unread'))
	assert !marker_action_activated(config, marker_action_id('other'))
	assert !marker_action_activated(MarkerConfig{ ...config, action_label: '' }, marker_action_id('unread'))
	if _ := marker(MarkerConfig{ ...config, id: '' }) {
		assert false, 'action accepted without an id'
	}
	if _ := marker(MarkerConfig{ ...config, icon: 'nope' }) {
		assert false, 'unknown icon accepted'
	}
	long := marker_layout(MarkerConfig{
		frame:     rect(0, 0, 200, 0)
		text:      'Messages and calls are end-to-end encrypted. No one outside of this chat can read them.'
		alignment: .center
	})
	assert long.lines > 1
	assert long.height == chat_lines_height(long.lines, m.font)
	surfaced := marker_layout(MarkerConfig{
		frame:      rect(0, 0, 400, 0)
		text:       'Pinned'
		background: 0xeeeeee
	})
	assert surfaced.text.x == m.pad_x
	assert surfaced.height == surfaced.text.height + 2 * m.pad_y
}

fn test_marker_loading_uses_the_feedback_components() {
	spinning := marker(MarkerConfig{
		id:            'loading-older'
		frame:         rect(0, 0, 400, 0)
		text:          'Loading messages…'
		loading:       true
		reduce_motion: true
	}) or { panic(err) }
	assert spinning.accessibility_role == 'status'
	spinner_el := chat_test_find(spinning, component_part_id('loading-older', 'spinner')) or {
		panic('spinner missing')
	}
	assert spinner_el.frame.width == marker_metrics(.medium).icon
	// An icon wins over the automatic spinner.
	iconic := marker(MarkerConfig{
		id:            'loading-icon'
		frame:         rect(0, 0, 400, 0)
		text:          'Syncing'
		icon:          'arrow.clockwise'
		loading:       true
		reduce_motion: true
	}) or { panic(err) }
	if _ := chat_test_find(iconic, component_part_id('loading-icon', 'spinner')) {
		assert false, 'spinner drawn over an icon'
	}
	typing := MarkerConfig{
		id:            'typing'
		frame:         rect(0, 0, 400, 0)
		text:          'Maya is typing…'
		loading:       true
		loading_style: .shimmer
		reduce_motion: true
	}
	shimmering := marker(typing) or { panic(err) }
	holder := chat_test_find(shimmering, component_part_id('typing', 'shimmer')) or {
		panic('shimmer missing')
	}
	assert chat_test_labels(holder) == ['Maya is typing…']
	assert marker_layout(typing).icon.width == 0
	if _ := marker(MarkerConfig{ ...typing, id: '' }) {
		assert false, 'loading marker accepted without an id'
	}
	quiet := marker(MarkerConfig{
		frame: rect(0, 0, 400, 0)
		text:  'Archived'
	}) or { panic(err) }
	assert quiet.accessibility_role == ''
	assert quiet.accessibility_label == 'Archived'
}

fn test_marker_animations_run_and_stop() {
	id := 'chat-test-marker-anim'
	marker(MarkerConfig{
		id:            id
		frame:         rect(0, 0, 300, 0)
		text:          'Thinking…'
		loading:       true
		loading_style: .shimmer
	}) or { panic(err) }
	assert chat_test_running(id + ':component:shimmer') > 0
	// Switching off loading stops the loop it started.
	marker(MarkerConfig{
		id:    id
		frame: rect(0, 0, 300, 0)
		text:  'Done'
	}) or { panic(err) }
	assert chat_test_running(id) == 0
	marker(MarkerConfig{
		id:      id
		frame:   rect(0, 0, 300, 0)
		text:    'Loading'
		loading: true
	}) or { panic(err) }
	assert chat_test_running(id + ':component:spinner') > 0
	stop_marker_animations(id)
	assert chat_test_running(id) == 0
}

fn chat_test_running(prefix string) int {
	runtime := g_animation_runtime
	runtime.mutex.lock()
	defer {
		runtime.mutex.unlock()
	}
	mut count := 0
	for key, _ in runtime.runs {
		if key.starts_with(prefix) {
			count++
		}
	}
	return count
}

// ── Avatar group ───────────────────────────────────────────────────

fn chat_test_people(names []string) []AvatarConfig {
	return names.map(AvatarConfig{
		name: it
	})
}

fn test_avatar_group_counts_and_width() {
	shown, hidden, extra := avatar_group_counts(5, 3, .count)
	assert shown == 3 && hidden == 2 && extra
	_, _, quiet := avatar_group_counts(5, 3, .hidden)
	assert !quiet
	all, none_hidden, no_extra := avatar_group_counts(2, 3, .count)
	assert all == 2 && none_hidden == 0 && !no_extra
	every, _, _ := avatar_group_counts(7, 0, .count)
	assert every == 7
	assert avatar_group_overflow_text(4) == '+4'
	assert avatar_group_overflow_text(120) == '99+'
	config := AvatarGroupConfig{
		frame:   rect(0, 0, 200, 40)
		avatars: chat_test_people(['Ada', 'Ben', 'Cy', 'Dee', 'Eve'])
	}
	d := avatar_group_diameter(.medium)
	assert d == 32
	// Three avatars, each 75% of a diameter after the one before, then the '+2'
	// clear of them.
	assert math.abs(avatar_group_width(config) - (2 * d * 0.75 + d + 4 + d + 4)) < 0.0001
	assert avatar_group_width(AvatarGroupConfig{ ...config, overflow: .hidden }) == 2 * d * 0.75 +
		d + 4
	assert avatar_group_width(AvatarGroupConfig{}) == 0
	assert avatar_group_width(AvatarGroupConfig{ ...config, diameter: 48, overlap: 0, ring: 0, limit: 0 }) == 5 * 48
}

fn test_avatar_group_overlaps_with_the_first_on_top() {
	theme := component_theme(false)
	config := AvatarGroupConfig{
		id:      'team'
		frame:   rect(10, 10, 200, 40)
		avatars: chat_test_people(['Ada Lovelace', 'Ben Ng', 'Cy Twombly', 'Dee Dee'])
		theme:   theme
	}
	el := avatar_group(config) or { panic(err) }
	assert el.accessibility_role == 'group'
	assert el.accessibility_label == 'Ada Lovelace, Ben Ng, Cy Twombly and 1 more'
	assert el.children.len == 4
	// Drawn last to first: the overflow first, the first avatar last.
	assert el.children[0].key == 'more'
	assert chat_test_labels(el.children[0]) == ['+1']
	assert el.children[3].key == 'avatar:0'
	assert el.children[3].frame.x == 0
	assert el.children[3].tooltip == 'Ada Lovelace'
	assert el.children[2].frame.x == 32 * 0.75
	assert el.children[0].frame.x == 2 * 32 * 0.75 + 32 + 4
	assert el.children[3].frame.y == math.round((40 - 36) / 2)
	assert el.children[3].box.bg == theme.background
	face := el.children[3].children[0]
	assert face.accessibility_role == 'img'
	assert face.frame == rect(2, 2, 32, 32)
	bg, _ := avatar_identity_colors('Ada Lovelace', false)
	assert face.box.bg == bg
	assert chat_test_labels(face) == ['AL']
	assert face.children[0].text_style.size == math.round(32 * 0.32)
	assert face.children[0].frame == rect(0, 0, 32, 32)
	// Later avatars center their initials in the part left showing.
	second := el.children[2].children[0].children[0]
	assert second.frame == rect((32 * 0.25 + 2) / 2, 0, 32, 32)
	plain := avatar_group(AvatarGroupConfig{
		...config
		identity_colors: false
	}) or { panic(err) }
	assert plain.children[3].children[0].box.bg == theme.muted
	dots := avatar_group(AvatarGroupConfig{
		...config
		overflow: .ellipsis
	}) or { panic(err) }
	assert dots.children[0].children[1].image_path == 'symbol:ellipsis'
	hidden := avatar_group(AvatarGroupConfig{
		...config
		overflow: .hidden
	}) or { panic(err) }
	assert hidden.children.len == 3
	large := avatar_group(AvatarGroupConfig{
		...config
		size: .large
	}) or { panic(err) }
	assert large.children[3].children[0].frame.width == 40
	for bad in [AvatarGroupConfig{
		overlap: 1
	}, AvatarGroupConfig{
		overlap: math.nan()
	}, AvatarGroupConfig{
		diameter: -1
	}, AvatarGroupConfig{
		ring: math.inf(1)
	}, AvatarGroupConfig{
		frame: rect(0, 0, -1, 1)
	}] {
		if _ := avatar_group(bad) {
			assert false, 'bad avatar group accepted'
		}
	}
}
