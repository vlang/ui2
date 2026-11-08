module main

import ui2

// A chat built from the GPUI Kit chat components: messages with avatars,
// headers, bubbles and footers, grouped by sender; date and "New messages"
// markers; reactions that toggle; a typing marker that shimmers; and a
// composer that sends. The column on the right shows the bubble variants,
// marker styles and avatar groups.

const window_width = 1180
const window_height = 880
const card_x = 24.0
const card_y = 76.0
const card_width = 620.0
const side_x = 668.0
const side_width = 488.0
const header_height = 64.0
const composer_height = 68.0
const pad = 16.0

enum Who {
	maya
	me
	system
}

struct Item {
	id           string
	who          Who
	text         string
	timestamp    string
	variant      ui2.BubbleVariant = .secondary
	marker       ui2.MarkerVariant
	marker_color bool // Draw the marker in the "unread" color.
	file         bool // A file card instead of text.
	actions      bool // Reply and copy in the footer.
	edited       bool
mut:
	reactions []ui2.BubbleReaction
	status    ui2.MessageStatus
}

@[heap]
struct App {
mut:
	dark   bool
	items  []Item
	draft  string
	picker string // The message whose quick reactions are open.
	note   string = 'Click a reaction to toggle it, or + to add one.'
	sent   int
}

const quick_reactions = ['👍', '❤️', '😂', '🎉', '👀', '🔥']

const app_state = &App{
	items: [
		Item{
			id:     'today'
			who:    .system
			text:   'Today'
			marker: .separator
		},
		Item{
			id:        'm1'
			who:       .maya
			text:      'Morning! Did you get a chance to look at the new onboarding flow?'
			timestamp: '9:41 AM'
		},
		Item{
			id:   'm2'
			who:  .maya
			text: 'I pushed the latest mocks to the design file last night 🎨'
		},
		Item{
			id:        'm3'
			who:       .me
			text:      'Yes! Going through it now.'
			timestamp: '9:44 AM'
			variant:   .filled
		},
		Item{
			id:        'm4'
			who:       .me
			text:      'The empty states look great. One question about the permissions step, though.'
			variant:   .filled
			reactions: [ui2.BubbleReaction{
				emoji: '👍'
				count: 1
				label: 'Thumbs up'
			}]
			status:    .read
		},
		Item{
			id:           'new'
			who:          .system
			text:         'New messages'
			marker:       .separator
			marker_color: true
		},
		Item{
			id:        'm5'
			who:       .maya
			text:      'Good catch. I moved the permissions step after the first project is created, so people see why we ask for calendar access before we ask for it. The welcome screen stays short: two fields and a button, and everything else happens in context.'
			timestamp: '9:52 AM'
			reactions: [ui2.BubbleReaction{
				emoji:    '❤️'
				count:    2
				selected: true
				label:    'Heart'
			}, ui2.BubbleReaction{
				emoji: '🎉'
				count: 1
				label: 'Party popper'
			}]
			actions:   true
			edited:    true
		},
		Item{
			id:   'm6'
			who:  .maya
			file: true
		},
	]
}

fn page_color(dark bool) u32 {
	return if dark { 0x111827 } else { 0xeef2f7 }
}

fn heading(text string, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, side_width, 20), ui2.TextStyle{
		color: theme.foreground
		size:  14
		bold:  true
	})
}

fn caption(text string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

// card draws a rounded panel with a one-point border: the border color with the
// fill inset over it, which every renderer draws the same.
fn card(id string, frame ui2.Rect, theme ui2.ComponentTheme, children []ui2.Element) ui2.Element {
	return ui2.view(id + '-border', frame, ui2.BoxStyle{
		bg:     theme.border
		radius: 14
	}, [
		ui2.view(id, ui2.rect(1, 1, frame.width - 2, frame.height - 2), ui2.BoxStyle{
			bg:     theme.background
			radius: 13
		}, children),
	])
}

// ── The conversation ───────────────────────────────────────────────

fn author_key(item Item) string {
	return match item.who {
		.maya { 'maya' }
		.me { 'me' }
		.system { '' }
	}
}

fn file_card(theme ui2.ComponentTheme) []ui2.Element {
	return [
		ui2.view('', ui2.rect(0, 2, 36, 36), ui2.BoxStyle{
			bg:     ui2.avatar_identity_theme('Figma', theme).muted
			radius: 8
		}, [
			ui2.Element{
				...ui2.image('', 'symbol:doc.fill', ui2.rect(9, 9, 18, 18))
				text_style: ui2.TextStyle{
					color: theme.primary
				}
			},
		]),
		ui2.label('', 'onboarding-v3.fig', ui2.rect(48, 2, 170, 18), ui2.TextStyle{
			color: theme.foreground
			size:  13
			bold:  true
		}),
		ui2.label('', 'Design file · 4.2 MB', ui2.rect(48, 21, 170, 16), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
		}),
	]
}

fn message_config(item Item, position ui2.ChatGroupPosition, frame ui2.Rect, theme ui2.ComponentTheme) ui2.ChatMessageConfig {
	mine := item.who == .me
	mut actions := []ui2.MessageAction{}
	if item.actions {
		actions << ui2.MessageAction{
			name:  'reply'
			label: 'Reply'
			icon:  'arrow.uturn.backward'
		}
		actions << ui2.MessageAction{
			name:    'copy'
			icon:    'doc.on.doc'
			tooltip: 'Copy text'
		}
	}
	return ui2.ChatMessageConfig{
		id:             item.id
		frame:          frame
		alignment:      if mine { .end } else { .start }
		author:         if mine { '' } else { 'Maya Chen' }
		show_avatar:    !mine
		timestamp:      item.timestamp
		badges:         if mine { []string{} } else { ['Design'] }
		bubble:         ui2.BubbleConfig{
			text:           if item.file { '' } else { item.text }
			variant:        if item.file { .outline } else { item.variant }
			content:        if item.file { file_card(theme) } else { []ui2.Element{} }
			content_width:  if item.file { 220.0 } else { 0.0 }
			content_height: if item.file { 40.0 } else { 0.0 }
			reactions:      item.reactions
			add_reaction:   item.reactions.len > 0 || item.actions
		}
		status:         item.status
		footer_text:    if item.edited { 'Edited' } else { '' }
		actions:        actions
		group_position: position
		theme:          theme
	}
}

fn unread_color(item Item, theme ui2.ComponentTheme) ?u32 {
	if item.marker_color {
		return theme.danger
	}
	return none
}

fn marker_config(item Item, frame ui2.Rect, theme ui2.ComponentTheme) ui2.MarkerConfig {
	return ui2.MarkerConfig{
		id:         item.id
		frame:      frame
		text:       item.text
		variant:    item.marker
		color:      unread_color(item, theme)
		line_color: unread_color(item, theme)
		bold:       item.marker_color
		size:       .small
		theme:      theme
	}
}

struct Row {
	item     Item
	position ui2.ChatGroupPosition
	y        f64
}

// layout_rows places every item of the conversation: runs of one sender are
// packed tight, and everything else gets room around it.
fn layout_rows(app &App, width f64, theme ui2.ComponentTheme) ([]Row, f64) {
	positions := ui2.chat_group_positions(app.items.map(author_key(it)))
	mut rows := []Row{cap: app.items.len}
	mut y := pad
	for index, item in app.items {
		position := positions[index]
		if index > 0 {
			y += if position == .middle || position == .last { 2.0 } else { 14.0 }
		}
		rows << Row{
			item:     item
			position: position
			y:        y
		}
		frame := ui2.rect(0, 0, width, 0)
		y += if item.who == .system {
			ui2.marker_height(marker_config(item, frame, theme))
		} else {
			ui2.chat_message_height(message_config(item, position, frame, theme))
		}
		if app.picker == item.id {
			y += 6 + picker_height
		}
	}
	return rows, y
}

const picker_height = 36.0
const picker_width = 8 + 7 * 32 - 4.0

fn picker(item Item, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	mut children := []ui2.Element{}
	for index, emoji in quick_reactions {
		children << ui2.Element{
			...ui2.button_view('pick:${item.id}:${index}', ui2.rect(4 + f64(index) * 32, 4, 28,
				28), ui2.BoxStyle{
				transparent: true
				radius:      14
			}, [
				ui2.label('', emoji, ui2.rect(0, 0, 28, 28), ui2.TextStyle{
					color: theme.foreground
					size:  16
					align: .center
				}),
			])
			cursor:              ui2.cursor_pointing_hand
			accessibility_label: 'React with ${emoji}'
		}
	}
	children << ui2.Element{
		...ui2.button_view('pick:${item.id}:close', ui2.rect(4 + 6 * 32, 4, 28, 28), ui2.BoxStyle{
			transparent: true
			radius:      14
		}, [
			ui2.Element{
				...ui2.image('', 'symbol:xmark', ui2.rect(8, 8, 12, 12))
				text_style: ui2.TextStyle{
					color: theme.muted_foreground
				}
			},
		])
		cursor:              ui2.cursor_pointing_hand
		accessibility_label: 'Close'
	}
	width := picker_width
	return ui2.view('', ui2.rect(x, y, width, picker_height), ui2.BoxStyle{
		bg:     theme.border
		radius: picker_height / 2
	}, [
		ui2.view('', ui2.rect(1, 1, width - 2, picker_height - 2), ui2.BoxStyle{
			bg:     theme.background
			radius: picker_height / 2 - 1
		}, children),
	])
}

fn conversation(app &App, theme ui2.ComponentTheme) ui2.Element {
	inner := card_width - 2
	height := window_height - card_y - 24 - 2
	width := inner - 2 * pad
	rows, content_height := layout_rows(app, width, theme)
	mut transcript := []ui2.Element{}
	for row in rows {
		item := row.item
		frame := ui2.rect(pad, row.y, width, 0)
		if item.who == .system {
			transcript << ui2.marker(marker_config(item, frame, theme)) or { panic(err) }
			continue
		}
		config := message_config(item, row.position, frame, theme)
		transcript << ui2.chat_message(config) or { panic(err) }
		if app.picker == item.id {
			layout := ui2.chat_message_layout(config)
			x := if item.who == .me { pad + width - picker_width } else { pad + layout.column.x }
			transcript << picker(item, x, row.y + layout.height + 6, theme)
		}
	}
	// The other side is typing: a marker whose text shimmers, in line with Maya's bubbles.
	typing_y := content_height + 14
	avatar_column := ui2.avatar_group_diameter(.medium) + 8
	transcript << ui2.marker(
		id:            'typing'
		frame:         ui2.rect(pad + avatar_column + 12, typing_y, width - avatar_column - 12,
			0)
		text:          'Maya is typing…'
		loading:       true
		loading_style: .shimmer
		size:          .small
		theme:         theme
	) or { panic(err) }
	transcript << ui2.view('', ui2.rect(0, typing_y + 18, 1, pad), ui2.BoxStyle{ transparent: true },
		[]ui2.Element{})

	transcript_top := header_height + 1
	transcript_height := height - transcript_top - composer_height - 1
	mut children := []ui2.Element{}
	children << chat_header(theme)
	children << ui2.view('', ui2.rect(0, header_height, inner, 1), ui2.BoxStyle{
		bg: theme.border
	}, []ui2.Element{})
	children << ui2.scroll('transcript', ui2.rect(0, transcript_top, inner, transcript_height),
		theme.background, transcript)
	children << ui2.view('', ui2.rect(0, height - composer_height - 1, inner, 1), ui2.BoxStyle{
		bg: theme.border
	}, []ui2.Element{})
	children << composer(app, inner, height, theme)
	return card('chat', ui2.rect(card_x, card_y, card_width, height + 2), theme, children)
}

fn transcript_bottom(app &App, theme ui2.ComponentTheme) f64 {
	inner := card_width - 2
	height := window_height - card_y - 24 - 2
	_, content_height := layout_rows(app, inner - 2 * pad, theme)
	visible := height - header_height - 1 - composer_height - 1
	return content_height + 14 + 18 + pad - visible
}

fn chat_header(theme ui2.ComponentTheme) ui2.Element {
	maya := ui2.avatar(
		name:  'Maya Chen'
		frame: ui2.rect(pad, 12, 40, 40)
		theme: ui2.avatar_identity_theme('Maya Chen', theme)
	) or { panic(err) }
	width := ui2.avatar_group_width(avatars: people_list(), size: .small)
	people := ui2.avatar_group(
		id:      'participants'
		frame:   ui2.rect(card_width - 2 - pad - width, 16, width, 32)
		avatars: people_list()
		size:    .small
		theme:   theme
	) or { panic(err) }
	return ui2.view('', ui2.rect(0, 0, card_width - 2, header_height), ui2.BoxStyle{
		transparent: true
	}, [
		maya,
		ui2.view('', ui2.rect(pad + 30, 42, 10, 10), ui2.BoxStyle{
			bg:     theme.background
			radius: 5
		}, [
			ui2.view('', ui2.rect(2, 2, 6, 6), ui2.BoxStyle{
				bg:     0x22c55e
				radius: 3
			}, []ui2.Element{}),
		]),
		ui2.label('', 'Maya Chen', ui2.rect(pad + 52, 13, 240, 20), ui2.TextStyle{
			color: theme.foreground
			size:  15
			bold:  true
		}),
		ui2.label('', 'Product designer · Active now', ui2.rect(pad + 52, 33, 240, 18),
			ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
			}),
		people,
	])
}

fn people_list() []ui2.AvatarConfig {
	return ['Maya Chen', 'You', 'Leo Park', 'Ana Silva', 'Sam Lee'].map(ui2.AvatarConfig{
		name: it
	})
}

fn composer_config(app &App, inner f64, y f64, theme ui2.ComponentTheme) ui2.InputGroupConfig {
	return ui2.InputGroupConfig{
		id:          'composer'
		frame:       ui2.rect(pad, y + 14, inner - 2 * pad, 40)
		text:        app.draft
		placeholder: 'Message Maya…'
		addons:      [
			ui2.InputGroupAddon{
				id:                  'send'
				kind:                .button
				side:                .trailing
				icon:                'paperplane.fill'
				primary:             true
				enabled:             app.draft.trim_space().len > 0
				tooltip:             'Send'
				accessibility_label: 'Send'
			},
		]
		size:        .large
		theme:       theme
	}
}

fn composer(app &App, inner f64, height f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.input_group(composer_config(app, inner, height - composer_height, theme)) or {
		panic(err)
	}
}

// ── The showcase ───────────────────────────────────────────────────

fn showcase(app &App, theme ui2.ComponentTheme) ui2.Element {
	height := window_height - card_y - 24
	inner := side_width - 2
	x := 20.0
	col := (inner - 2 * x - 12) / 2
	mut children := []ui2.Element{}
	children << heading('Bubble variants', x, 16, theme)
	variants := [ui2.BubbleVariant.filled, .secondary, .muted, .tinted, .outline, .ghost]
	words := ['Filled is the default', 'Secondary, for incoming', 'Muted for quiet context',
		'Tinted for emphasis', 'Outline draws a border', 'Ghost has no surface']
	mut y := 46.0
	mut row_height := 0.0
	for index, variant in variants {
		config := ui2.BubbleConfig{
			frame:     ui2.rect(x + f64(index % 2) * (col + 12), y, col, 0)
			text:      words[index]
			variant:   variant
			max_width: col
			theme:     theme
		}
		children << ui2.bubble(config) or { panic(err) }
		row_height = if index % 2 == 0 {
			ui2.bubble_height(config)
		} else {
			if ui2.bubble_height(config) > row_height {
				ui2.bubble_height(config)
			} else {
				row_height
			}
		}
		if index % 2 == 1 {
			y += row_height + 10
		}
	}
	failed := ui2.BubbleConfig{
		frame:   ui2.rect(x, y, inner - 2 * x, 0)
		text:    'Destructive: the upload failed. Check your connection, then send it again.'
		variant: .destructive
		theme:   theme
	}
	children << ui2.bubble(failed) or { panic(err) }
	y += ui2.bubble_height(failed) + 12
	group := ui2.BubbleGroupConfig{
		frame:     ui2.rect(x, y, inner - 2 * x, 0)
		alignment: .end
		bubbles:   [ui2.BubbleConfig{
			text: 'A bubble group'
		}, ui2.BubbleConfig{
			text: 'joins the corners'
		}, ui2.BubbleConfig{
			text: 'on the sender’s side'
		}]
		theme:     theme
	}
	children << ui2.bubble_group(group) or { panic(err) }
	children << caption('Reactions can hang from the top:', ui2.rect(x, y + 4, 230, 16),
		theme)
	top := ui2.BubbleConfig{
		id:                 'top-reactions'
		frame:              ui2.rect(x, y + 26, 220, 0)
		text:               'Noted!'
		variant:            .tinted
		reactions:          [ui2.BubbleReaction{
			emoji: '✅'
			count: 3
			label: 'Check mark'
		}]
		reaction_side:      .top
		reaction_alignment: .start
		enabled:            false
		theme:              theme
	}
	children << ui2.bubble(top) or { panic(err) }
	y += ui2.bubble_group_height(group) + 22

	children << heading('Markers', x, y, theme)
	y += 30
	width := inner - 2 * x
	markers := [
		ui2.MarkerConfig{
			text:      'Yesterday'
			variant:   .separator
			alignment: .start
		},
		ui2.MarkerConfig{
			text:      'Messages are end-to-end encrypted'
			icon:      'lock.fill'
			alignment: .center
		},
		ui2.MarkerConfig{
			id:           'unread'
			text:         '3 unread messages'
			icon:         'bell'
			variant:      .border
			action_label: 'Jump'
		},
		ui2.MarkerConfig{
			id:      'loading-older'
			text:    'Loading earlier messages…'
			loading: true
		},
		ui2.MarkerConfig{
			id:            'summary'
			text:          'Generating a summary…'
			icon:          'text.bubble'
			loading:       true
			loading_style: .shimmer
		},
		ui2.MarkerConfig{
			text:       'Pinned: launch checklist'
			icon:       'bookmark.fill'
			icon_color: theme.primary
			color:      theme.foreground
			background: theme.muted
			alignment:  .end
		},
	]
	for config in markers {
		full := ui2.MarkerConfig{
			...config
			frame: ui2.rect(x, y, width, 0)
			theme: theme
		}
		children << ui2.marker(full) or { panic(err) }
		y += ui2.marker_height(full) + 12
	}
	y += 10

	children << heading('Avatar groups', x, y, theme)
	y += 30
	team := ['Ana Silva', 'Ben Okafor', 'Chen Wei', 'Dana Cruz', 'Eli Novak', 'Fay Moreau', 'Gus Lind'].map(ui2.AvatarConfig{
		name: it
	})
	groups := [
		ui2.AvatarGroupConfig{
			avatars: team
			size:    .small
		},
		ui2.AvatarGroupConfig{
			avatars: team
			limit:   4
		},
		ui2.AvatarGroupConfig{
			avatars:  team
			limit:    3
			overflow: .ellipsis
			size:     .large
		},
	]
	mut gx := x
	for index, config in groups {
		full := ui2.AvatarGroupConfig{
			...config
			id:    'group-${index}'
			frame: ui2.rect(gx, y, 0, 44)
			theme: theme
		}
		group_width := ui2.avatar_group_width(full)
		children << ui2.avatar_group(ui2.AvatarGroupConfig{
			...full
			frame: ui2.rect(gx, y, group_width, 44)
		}) or { panic(err) }
		children << caption(match index {
			0 { 'small, +4' }
			1 { 'medium, limit 4' }
			else { 'large, ellipsis' }
		}, ui2.rect(gx, y + 48, group_width + 20, 16), theme)
		gx += group_width + 28
	}
	children << ui2.label('', app.note, ui2.rect(x, height - 34, width, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
	return card('showcase', ui2.rect(side_x, card_y, side_width, height), theme, children)
}

fn build() ui2.Element {
	app := unsafe { app_state }
	theme := ui2.component_theme(app.dark)
	mut children := []ui2.Element{}
	children << ui2.label('', 'Chat', ui2.rect(24, 18, 300, 30), ui2.TextStyle{
		color: theme.foreground
		size:  22
		bold:  true
	})
	children << ui2.label('', 'Bubble, Message, Marker and AvatarGroup, ported from GPUI Kit',
		ui2.rect(24, 46, 600, 18), ui2.TextStyle{
			color: theme.muted_foreground
			size:  13
		})
	children << ui2.Element{
		...ui2.button('theme', if app.dark { 'Light mode' } else { 'Dark mode' }, ui2.rect(window_width - 24 - 112,
			24, 112, 32), ui2.BoxStyle{
			bg:            theme.background
			radius:        8
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, ui2.TextStyle{
			color: theme.foreground
			size:  13
			align: .center
		})
		cursor: ui2.cursor_pointing_hand
	}
	children << conversation(app, theme)
	children << showcase(app, theme)
	return ui2.screen(page_color(app.dark), children)
}

// ── Events ─────────────────────────────────────────────────────────

fn (mut app App) toggle(index int, emoji string) {
	app.items[index].reactions = ui2.bubble_toggle_reaction(app.items[index].reactions,
		emoji)
}

fn (mut app App) send() {
	text := app.draft.trim_space()
	if text.len == 0 {
		return
	}
	for mut item in app.items {
		if item.who == .me {
			item.status = .none
		}
	}
	app.sent++
	app.items << Item{
		id:        'sent-${app.sent}'
		who:       .me
		text:      text
		variant:   .filled
		timestamp: if app.items.last().who == .me { '' } else { '9:58 AM' }
		status:    .sent
	}
	app.draft = ''
	app.note = 'Sent “${text}”.'
}

fn on_event(event string) {
	mut app := unsafe { app_state }
	theme := ui2.component_theme(app.dark)
	if event == 'theme' {
		app.dark = !app.dark
	}
	if decoded := ui2.input_group_event(composer_config(app, 0, 0, theme), event) {
		match decoded.kind {
			.change {
				app.draft = ui2.text(ui2.input_group_field_id('composer'))
			}
			.clear {
				app.draft = ''
			}
			.submit, .addon {
				app.send()
				ui2.refresh()
				ui2.scroll_to_offset('transcript', transcript_bottom(app, theme))
				return
			}
		}
	}
	if event == ui2.marker_action_id('unread') {
		ui2.scroll_to_offset('transcript', 0)
		app.note = 'Jumped to the first unread message.'
	}
	if event.starts_with('pick:') {
		parts := event.split(':')
		if parts.len == 3 {
			for index, item in app.items {
				if item.id != parts[1] {
					continue
				}
				if parts[2] != 'close' {
					choice := parts[2].int()
					if choice >= 0 && choice < quick_reactions.len {
						app.toggle(index, quick_reactions[choice])
						app.note = 'Reacted with ${quick_reactions[choice]}.'
					}
				}
				app.picker = ''
			}
		}
		ui2.refresh()
		return
	}
	positions := ui2.chat_group_positions(app.items.map(author_key(it)))
	for index, item in app.items {
		if item.who == .system {
			continue
		}
		config := message_config(item, positions[index], ui2.rect(0, 0, 0, 0), theme)
		decoded := ui2.chat_message_event_from_action(config, event) or { continue }
		match decoded.kind {
			.reaction {
				app.toggle(index, decoded.name)
				app.note = if decoded.selected {
					'Reacted with ${decoded.name}.'
				} else {
					'Removed your ${decoded.name}.'
				}
			}
			.add_reaction {
				app.picker = if app.picker == item.id { '' } else { item.id }
			}
			.action {
				if decoded.name == 'copy' {
					copied := ui2.set_clipboard_text(item.text)
					app.note = if copied { 'Copied the message.' } else { 'No clipboard here.' }
				} else {
					app.draft = '@Maya '
					app.note = 'Replying to Maya.'
				}
			}
		}
		break
	}
	ui2.refresh()
}

fn main() {
	// Open on the newest messages, as a chat does, when they do not all fit.
	bottom := transcript_bottom(app_state, ui2.component_theme(false))
	if bottom > 0 {
		ui2.scroll_to_offset('transcript', bottom)
	}
	ui2.run_window('GPUI Kit chat', window_width, window_height, build, on_event)
}
