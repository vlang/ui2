module ui2

import math

// Drawing the questionnaire. The progress line sits at the top and the actions
// at the bottom of the frame, so Previous and Next stay put from one step to
// the next; the item between them scrolls when it is taller than the room it
// has. questionnaire_natural_height says how tall a frame needs to be for the
// tallest step not to scroll.
//
// Answers are cards, as upstream draws them: a view with button behavior
// holding the radio or checkbox indicator, the label and its description, and
// the shortcut key on the right. A freeform answer beside choices is a card
// whose indicator is the button and whose body is the native field.

// QuestionnaireMetrics is the questionnaire's geometry at one size.
struct QuestionnaireMetrics {
	font          f64 // answers
	detail        f64 // descriptions, hints and errors
	title         f64
	progress      f64 // the progress line
	section       f64 // between the progress, the item and the actions
	text_gap      f64 // between a title and its description
	item_gap      f64 // between an item's text and its answers
	choices_gap   f64 // between answer cards
	pad_x         f64 // inside a card
	pad_y         f64
	content_gap   f64 // between a label and its description
	gap           f64 // between an indicator and its label
	indicator     f64
	shortcut      f64
	shortcut_font f64
	radius        f64
	button_height f64
	button_min    f64 // narrowest navigation button
	field_height  f64 // a one-line field inside a card
	bare_field    f64 // a one-line field that is the whole answer
	bar           f64 // progress bar thickness
	bar_gap       f64
	page_gap      f64 // between items on a page
	error_gap     f64
}

fn questionnaire_metrics(size ComponentSize) QuestionnaireMetrics {
	return match size {
		.small {
			QuestionnaireMetrics{
				font:          12
				detail:        11
				title:         14
				progress:      11
				section:       14
				text_gap:      2
				item_gap:      12
				choices_gap:   6
				pad_x:         10
				pad_y:         7
				content_gap:   1
				gap:           8
				indicator:     14
				shortcut:      18
				shortcut_font: 10
				radius:        6
				button_height: 24
				button_min:    68
				field_height:  22
				bare_field:    28
				bar:           4
				bar_gap:       6
				page_gap:      20
				error_gap:     6
			}
		}
		.medium {
			QuestionnaireMetrics{
				font:          14
				detail:        13
				title:         17
				progress:      12
				section:       20
				text_gap:      4
				item_gap:      16
				choices_gap:   8
				pad_x:         14
				pad_y:         10
				content_gap:   2
				gap:           10
				indicator:     16
				shortcut:      22
				shortcut_font: 11
				radius:        8
				button_height: 32
				button_min:    88
				field_height:  28
				bare_field:    36
				bar:           6
				bar_gap:       8
				page_gap:      28
				error_gap:     8
			}
		}
		.large {
			QuestionnaireMetrics{
				font:          16
				detail:        14
				title:         20
				progress:      13
				section:       26
				text_gap:      6
				item_gap:      20
				choices_gap:   10
				pad_x:         18
				pad_y:         13
				content_gap:   3
				gap:           12
				indicator:     18
				shortcut:      26
				shortcut_font: 13
				radius:        10
				button_height: 40
				button_min:    104
				field_height:  32
				bare_field:    44
				bar:           8
				bar_gap:       10
				page_gap:      36
				error_gap:     10
			}
		}
	}
}

const questionnaire_text_line_limit = 3

// ── Layout ──────────────────────────────────────────────────────────

struct QuestionnaireCardLayout {
	frame             Rect // relative to the answers box
	label_lines       int
	description_lines int
}

// QuestionnaireItemLayout places an item's parts relative to the item.
struct QuestionnaireItemLayout {
	title             Rect
	title_lines       int
	description       Rect
	description_lines int
	hint              Rect
	answers           Rect
	cards             []QuestionnaireCardLayout // relative to answers
	input             Rect                      // relative to answers; empty without an input
	error             Rect
	error_lines       int
	height            f64
}

// questionnaire_card_min is the height of a one-line card.
fn questionnaire_card_min(m QuestionnaireMetrics, shortcut bool) f64 {
	tallest := math.max(font_line_height(m.font), math.max(m.indicator, if shortcut {
		m.shortcut
	} else {
		0.0
	}))
	return math.round(tallest + 2 * m.pad_y)
}

fn questionnaire_card_text_x(m QuestionnaireMetrics) f64 {
	return m.pad_x + m.indicator + m.gap
}

// questionnaire_card_text_width is the room a card leaves its label: the card
// less the indicator before it and the shortcut after it.
fn questionnaire_card_text_width(width f64, m QuestionnaireMetrics, shortcut bool) f64 {
	reserved := questionnaire_card_text_x(m) + m.pad_x + if shortcut {
		m.shortcut + m.gap
	} else {
		0.0
	}
	return math.max(0.0, width - reserved)
}

fn questionnaire_lines(content string, font f64, bold bool, width f64) int {
	return math.min(dialog_line_count(content, font, bold, width), questionnaire_text_line_limit)
}

// questionnaire_card_block is how tall a card's label and description are.
fn questionnaire_card_block(label_lines int, description_lines int, m QuestionnaireMetrics) f64 {
	mut block := dialog_text_height(label_lines, m.font)
	if description_lines > 0 {
		block += m.content_gap + dialog_text_height(description_lines, m.detail)
	}
	return block
}

// questionnaire_input_height is the height of an item's freeform input: a
// card holding the field beside choices, the bare field otherwise.
fn questionnaire_input_height(item QuestionnaireItem, input QuestionnaireInput, m QuestionnaireMetrics, shortcut bool) f64 {
	line := font_line_height(m.font)
	if input.multiline {
		area := math.round(f64(input.lines) * line + 12)
		return if item.choices.len > 0 { area + 2 * m.pad_y } else { area }
	}
	if item.choices.len > 0 {
		return math.max(questionnaire_card_min(m, shortcut), m.field_height + 12)
	}
	return m.bare_field
}

fn questionnaire_shows_shortcuts(config QuestionnaireConfig, item QuestionnaireItem) bool {
	return config.shortcuts != .off && item.choices.any(it.enabled)
}

// questionnaire_item_layout lays an item out in width: its title, description,
// limits hint, the answer cards and input, and the error, top to bottom.
fn questionnaire_item_layout(config QuestionnaireConfig, item QuestionnaireItem, width f64, m QuestionnaireMetrics, error_text string) QuestionnaireItemLayout {
	mut y := 0.0
	title_lines := dialog_line_count(item.title, m.title, true, width)
	title_height := dialog_text_height(title_lines, m.title)
	title := rect(0, y, width, title_height)
	y += title_height
	mut description := Rect{}
	mut description_lines := 0
	if item.description.len > 0 {
		y += m.text_gap
		description_lines = dialog_line_count(item.description, m.detail, false, width)
		height := dialog_text_height(description_lines, m.detail)
		description = rect(0, y, width, height)
		y += height
	}
	mut hint := Rect{}
	if questionnaire_hint(item, config.messages).len > 0 {
		y += m.text_gap
		height := font_line_height(m.detail)
		hint = rect(0, y, width, height)
		y += height
	}
	y += m.item_gap
	shortcut := questionnaire_shows_shortcuts(config, item)
	text_width := questionnaire_card_text_width(width, m, shortcut)
	card_min := questionnaire_card_min(m, shortcut)
	mut cards := []QuestionnaireCardLayout{cap: item.choices.len}
	mut answers_height := 0.0
	for choice in item.choices {
		label_lines := questionnaire_lines(choice.label, m.font, false, text_width)
		detail_lines := if choice.description.len > 0 {
			questionnaire_lines(choice.description, m.detail, false, text_width)
		} else {
			0
		}
		height := math.max(card_min, math.round(questionnaire_card_block(label_lines,
			detail_lines, m) + 2 * m.pad_y))
		if cards.len > 0 {
			answers_height += m.choices_gap
		}
		cards << QuestionnaireCardLayout{
			frame:             rect(0, answers_height, width, height)
			label_lines:       label_lines
			description_lines: detail_lines
		}
		answers_height += height
	}
	mut input_rect := Rect{}
	if input := item.input {
		if cards.len > 0 {
			answers_height += m.choices_gap
		}
		height := questionnaire_input_height(item, input, m, shortcut)
		input_rect = rect(0, answers_height, width, height)
		answers_height += height
	}
	answers := rect(0, y, width, answers_height)
	y += answers_height
	mut error_rect := Rect{}
	mut error_lines := 0
	if error_text.len > 0 {
		y += m.error_gap
		icon := math.floor(font_line_height(m.detail))
		error_lines = dialog_line_count(error_text, m.detail, false, math.max(0.0, width - icon - 6))
		height := dialog_text_height(error_lines, m.detail)
		error_rect = rect(0, y, width, height)
		y += height
	}
	return QuestionnaireItemLayout{
		title:             title
		title_lines:       title_lines
		description:       description
		description_lines: description_lines
		hint:              hint
		answers:           answers
		cards:             cards
		input:             input_rect
		error:             error_rect
		error_lines:       error_lines
		height:            math.ceil(y)
	}
}

fn questionnaire_progress_height(config QuestionnaireConfig, m QuestionnaireMetrics) f64 {
	if !config.show_progress {
		return 0
	}
	return math.round(font_line_height(m.progress) + if config.progress_bar {
		m.bar_gap + m.bar
	} else {
		0.0
	})
}

// questionnaire_chrome_height is the room the progress line and the actions
// take, with the gaps that separate them from the item.
fn questionnaire_chrome_height(config QuestionnaireConfig, m QuestionnaireMetrics) (f64, f64) {
	top := if config.show_progress {
		questionnaire_progress_height(config, m) + m.section
	} else {
		0.0
	}
	bottom := if config.show_actions { m.button_height + m.section } else { 0.0 }
	return top, bottom
}

// questionnaire_page_height is how tall the shown items are stacked on a page.
fn questionnaire_page_height(config QuestionnaireConfig, resolved QuestionnaireResolved, m QuestionnaireMetrics, width f64) f64 {
	mut height := 0.0
	for position, index in resolved.order {
		if position > 0 {
			height += m.page_gap
		}
		height += questionnaire_item_layout(config, config.items[index], width, m, questionnaire_shown_error(config,
			index, resolved)).height
	}
	return height
}

// questionnaire_natural_height is the frame height at which nothing scrolls:
// for steps, the tallest enabled item with room for a one-line error, so the
// frame suits every step; for a page, every shown item as it stands. Set the
// config's frame width first, since text wraps to it.
pub fn questionnaire_natural_height(config QuestionnaireConfig) f64 {
	m := questionnaire_metrics(config.size)
	width := config.frame.width
	top, bottom := questionnaire_chrome_height(config, m)
	resolved := questionnaire_resolve(config.items, config.state)
	mut body := 0.0
	if config.layout == .page {
		body = questionnaire_page_height(config, resolved, m, width)
	} else {
		for index, item in config.items {
			if !item.enabled {
				continue
			}
			shown := questionnaire_shown_error(config, index, resolved)
			body = math.max(body, questionnaire_item_layout(config, item, width, m, if shown.len > 0 {
				shown
			} else {
				'M'
			}).height)
		}
	}
	return math.ceil(top + body + bottom)
}

// ── Parts ───────────────────────────────────────────────────────────

// questionnaire_ring draws a rounded border `width` thick under a fill, as
// choice_ring does for a one-unit border.
fn questionnaire_ring(frame Rect, radius f64, border u32, fill u32, width f64) []Element {
	mut shapes := choice_shape(frame, radius, border, .all, false)
	inner := rect(frame.x + width, frame.y + width, math.max(0.0, frame.width - 2 * width),
		math.max(0.0, frame.height - 2 * width))
	shapes << choice_shape(inner, radius - width, fill, .all, false)
	return shapes
}

// questionnaire_check_indicator is a checkbox square: a ring under an inner
// fill, filled with the primary color and a check mark when checked.
fn questionnaire_check_indicator(frame Rect, checked bool, enabled bool, theme ComponentTheme) Element {
	d := math.min(frame.width, frame.height)
	mut ring := if checked { theme.primary } else { theme.border }
	mut fill := if checked { theme.primary } else { theme.background }
	mut mark := theme.primary_foreground
	if !enabled {
		ring = choice_mix(ring, theme.background, 0.5)
		fill = choice_mix(fill, theme.background, 0.5)
		mark = choice_mix(mark, theme.background, 0.3)
	}
	mut children := choice_ring(rect(0, 0, d, d), math.max(3.0, math.round(d * 0.25)), ring,
		fill, .all, false)
	if checked {
		glyph := math.round(d * 0.8)
		children << choice_icon('checkmark', rect((d - glyph) / 2, (d - glyph) / 2, glyph,
			glyph), mark)
	}
	return view('', frame, BoxStyle{ transparent: true }, children)
}

fn questionnaire_indicator(frame Rect, multiple bool, checked bool, enabled bool, theme ComponentTheme) Element {
	return if multiple {
		questionnaire_check_indicator(frame, checked, enabled, theme)
	} else {
		radio_indicator(frame, checked, enabled, theme)
	}
}

// questionnaire_shortcut_badge is the key hint at the end of a card.
fn questionnaire_shortcut_badge(key string, frame Rect, enabled bool, m QuestionnaireMetrics, theme ComponentTheme) Element {
	local := component_local(frame)
	border := if enabled { theme.border } else { choice_mix(theme.border, theme.background, 0.5) }
	mut children := choice_ring(local, math.max(3.0, m.radius - 4), border, theme.background,
		.all, false)
	children << label('', key, local, TextStyle{
		color:       if enabled { theme.muted_foreground } else { choice_disabled_text(theme) }
		size:        m.shortcut_font
		font_family: 'monospace'
		bold:        true
		align:       .center
	})
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		key: 'shortcut'
	}
}

// QuestionnaireCardColors are the colors of an answer card in one state.
struct QuestionnaireCardColors {
	border u32
	fill   u32
	label  u32
	detail u32
	ring   f64 // border thickness
}

fn questionnaire_card_colors(theme ComponentTheme, selected bool, enabled bool, invalid bool, highlighted bool) QuestionnaireCardColors {
	fill := if selected {
		choice_mix(theme.background, theme.primary, 0.08)
	} else if !enabled {
		choice_mix(theme.background, theme.muted, 0.5)
	} else {
		theme.background
	}
	border := if highlighted {
		theme.primary
	} else if invalid && !selected {
		choice_mix(theme.background, theme.danger, 0.75)
	} else if selected {
		choice_mix(theme.background, theme.primary, 0.6)
	} else if !enabled {
		choice_mix(theme.border, theme.background, 0.4)
	} else {
		theme.border
	}
	return QuestionnaireCardColors{
		border: border
		fill:   fill
		label:  if enabled { theme.foreground } else { choice_disabled_text(theme) }
		detail: if enabled { theme.muted_foreground } else { choice_disabled_text(theme) }
		ring:   if highlighted { 2.0 } else { 1.0 }
	}
}

struct QuestionnaireItemContext {
	config      QuestionnaireConfig
	item        QuestionnaireItem
	item_state  QuestionnaireItemState
	answer      QuestionnaireAnswer
	invalid     bool
	interactive bool // the questionnaire is enabled and the item takes input
	shortcuts   bool // the item is current: key hints and the keyboard highlight are drawn
	m           QuestionnaireMetrics
}

// questionnaire_card draws one choice as a card that answers a click.
fn questionnaire_card(ctx QuestionnaireItemContext, choice QuestionnaireChoice, card QuestionnaireCardLayout) Element {
	theme := ctx.config.theme
	m := ctx.m
	value := questionnaire_choice_key(choice)
	selected := ctx.answer.has(value)
	open := ctx.interactive && questionnaire_choice_open(ctx.item, choice, ctx.answer)
	highlighted := ctx.interactive && ctx.shortcuts && ctx.config.state.highlight == value
	colors := questionnaire_card_colors(theme, selected, open, ctx.invalid, highlighted)
	width := card.frame.width
	height := card.frame.height
	mut children := questionnaire_ring(rect(0, 0, width, height), m.radius, colors.border,
		colors.fill, colors.ring)
	line := font_line_height(m.font)
	block := questionnaire_card_block(card.label_lines, card.description_lines, m)
	top := math.max(m.pad_y, (height - block) / 2)
	shortcut := questionnaire_shows_shortcuts(ctx.config, ctx.item)
	text_x := questionnaire_card_text_x(m)
	text_width := questionnaire_card_text_width(width, m, shortcut)
	children << questionnaire_indicator(rect(m.pad_x, top + (line - m.indicator) / 2, m.indicator,
		m.indicator), ctx.item.multiple, selected, open || selected, theme)
	label_height := dialog_text_height(card.label_lines, m.font)
	children << label('', choice.label, rect(text_x, top, text_width, label_height), TextStyle{
		color:  colors.label
		size:   m.font
		valign: .top
		lines:  card.label_lines
	})
	if card.description_lines > 0 {
		children << label('', choice.description, rect(text_x, top + label_height + m.content_gap,
			text_width, dialog_text_height(card.description_lines, m.detail)), TextStyle{
			color:  colors.detail
			size:   m.detail
			valign: .top
			lines:  card.description_lines
		})
	}
	if shortcut && ctx.shortcuts {
		key := questionnaire_shortcut(ctx.config, ctx.item.name, value)
		if key.len > 0 {
			children << questionnaire_shortcut_badge(key, rect(width - m.pad_x - m.shortcut,
				top + (line - m.shortcut) / 2, m.shortcut, m.shortcut), open, m, theme)
		}
	}
	return Element{
		...button_view(questionnaire_choice_action_id(ctx.config.id, ctx.item.name, value),
			card.frame, BoxStyle{ transparent: true }, children)
		key:                 'choice:' + questionnaire_hex(value)
		enabled:             open
		cursor:              if open { cursor_pointing_hand } else { '' }
		accessibility_role:  if ctx.item.multiple { 'checkbox' } else { 'radio' }
		accessibility_label: if choice.description.len > 0 {
			'${choice.label}, ${choice.description}'
		} else {
			choice.label
		}
		accessibility_value: if selected { 'checked' } else { 'unchecked' }
	}
}

// questionnaire_text_input is a freeform input: a one-line native field or a
// text area inside a drawn border.
fn questionnaire_text_input(ctx QuestionnaireItemContext, input QuestionnaireInput, frame Rect, enabled bool, radius f64, border u32) []Element {
	theme := ctx.config.theme
	m := ctx.m
	field_id := questionnaire_input_id(ctx.config.id, ctx.item.name)
	if !input.multiline {
		return [
			inputs_field(InputsFieldSpec{
				id:                field_id
				submit_id:         questionnaire_input_submit_id(ctx.config.id, ctx.item.name)
				placeholder:       input.placeholder
				text:              ctx.item_state.text
				frame:             frame
				font_size:         m.font
				enabled:           enabled
				invalid:           ctx.invalid && ctx.item.choices.len == 0
				label:             input.label
				key:               'field'
				standalone_radius: radius
				theme:             theme
			}),
		]
	}
	// A text area draws no border of its own on AppKit, so it sits inside one.
	mut parts := []Element{}
	parts << Element{
		...view('', frame, BoxStyle{ transparent: true }, questionnaire_ring(component_local(frame),
			radius, border, theme.background, 1))
		key: 'field-border'
	}
	parts << Element{
		...text_area(field_id, ctx.item_state.text, rect(frame.x + 1, frame.y + 1, math.max(0.0,
			frame.width - 2), math.max(0.0, frame.height - 2)), BoxStyle{
			bg:     theme.background
			radius: math.max(0.0, radius - 1)
		}, TextStyle{
			color: if enabled { theme.foreground } else { theme.muted_foreground }
			size:  m.font
		})
		key:                 'field'
		enabled:             enabled
		accessibility_label: input.label
	}
	return parts
}

// questionnaire_other draws the freeform answer beside choices: a card whose
// indicator selects the draft and whose body is the field.
fn questionnaire_other(ctx QuestionnaireItemContext, input QuestionnaireInput, frame Rect) Element {
	theme := ctx.config.theme
	m := ctx.m
	item := ctx.item
	active := ctx.item_state.freeform && (item.multiple || ctx.answer.choices.len == 0)
	open := ctx.interactive && questionnaire_other_open(item, ctx.item_state, ctx.answer)
	colors := questionnaire_card_colors(theme, active, open || active, ctx.invalid, false)
	width := frame.width
	height := frame.height
	line := font_line_height(m.font)
	text_x := questionnaire_card_text_x(m)
	mut children := questionnaire_ring(rect(0, 0, width, height), m.radius, colors.border,
		colors.fill, colors.ring)
	indicator_y := if input.multiline {
		m.pad_y + 6 + (line - m.indicator) / 2
	} else {
		(height - m.indicator) / 2
	}
	children << Element{
		...button_view(questionnaire_other_action_id(ctx.config.id, item.name), rect(0, 0, text_x,
			height), BoxStyle{ transparent: true }, [
			questionnaire_indicator(rect(m.pad_x, indicator_y, m.indicator, m.indicator),
				item.multiple, active, open || active, theme),
		])
		key:                 'select'
		enabled:             open
		cursor:              if open { cursor_pointing_hand } else { '' }
		accessibility_role:  if item.multiple { 'checkbox' } else { 'radio' }
		accessibility_label: input.label
		accessibility_value: if active { 'checked' } else { 'unchecked' }
	}
	field_width := math.max(0.0, width - text_x - m.pad_x)
	field_frame := if input.multiline {
		rect(text_x, m.pad_y, field_width, math.max(0.0, height - 2 * m.pad_y))
	} else {
		rect(text_x, (height - m.field_height) / 2, field_width, m.field_height)
	}
	children << questionnaire_text_input(ctx, input, field_frame, open, math.max(0.0, m.radius - 2),
		theme.border)
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		key:                 'other'
		accessibility_role:  'group'
		accessibility_label: input.label
	}
}

// questionnaire_item_view draws one item at y in a column `width` wide.
fn questionnaire_item_view(config QuestionnaireConfig, resolved QuestionnaireResolved, index int, m QuestionnaireMetrics, width f64, y f64) Element {
	item := config.items[index]
	theme := config.theme
	error_text := questionnaire_shown_error(config, index, resolved)
	geom := questionnaire_item_layout(config, item, width, m, error_text)
	current := index == resolved.current
	ctx := QuestionnaireItemContext{
		config:      config
		item:        item
		item_state:  config.state.item(item.name)
		answer:      resolved.answers[index]
		invalid:     error_text.len > 0
		interactive: config.enabled
		shortcuts:   current
		m:           m
	}
	mut children := []Element{}
	children << Element{
		...label('', item.title, geom.title, TextStyle{
			color:  theme.foreground
			size:   m.title
			bold:   true
			valign: .top
			lines:  geom.title_lines
		})
		key: 'title'
	}
	if geom.description_lines > 0 {
		children << Element{
			...label('', item.description, geom.description, TextStyle{
				color:  theme.muted_foreground
				size:   m.detail
				valign: .top
				lines:  geom.description_lines
			})
			key: 'description'
		}
	}
	hint := questionnaire_hint(item, config.messages)
	if hint.len > 0 {
		children << Element{
			...label('', hint, geom.hint, TextStyle{
				color: theme.muted_foreground
				size:  m.detail
				bold:  true
			})
			key: 'hint'
		}
	}
	mut answers := []Element{}
	for choice_index, choice in item.choices {
		answers << questionnaire_card(ctx, choice, geom.cards[choice_index])
	}
	if input := item.input {
		if item.choices.len > 0 {
			answers << questionnaire_other(ctx, input, geom.input)
		} else {
			answers << questionnaire_text_input(ctx, input, geom.input, config.enabled
				&& input.enabled, m.radius, if ctx.invalid {
				choice_mix(theme.background, theme.danger, 0.75)
			} else {
				theme.border
			})
		}
	}
	children << Element{
		...view('', geom.answers, BoxStyle{ transparent: true }, answers)
		key:                 'answers'
		accessibility_role:  if item.multiple || item.choices.len == 0 {
			'group'
		} else {
			'radiogroup'
		}
		accessibility_label: item.title
	}
	if error_text.len > 0 {
		// A whole number of pixels: the custom renderer shortens a glyph that is
		// a fraction wider than its frame to an ellipsis.
		icon := math.floor(font_line_height(m.detail))
		children << Element{
			...view('', geom.error, BoxStyle{ transparent: true }, [
				choice_icon('exclamationmark.circle', rect(0, math.floor((font_line_height(m.detail) - icon) / 2),
					icon, icon), theme.danger),
				label('', error_text, rect(icon + 6, 0, math.max(0.0, geom.error.width - icon - 6),
					geom.error.height), TextStyle{
					color:  theme.danger
					size:   m.detail
					valign: .top
					lines:  geom.error_lines
				}),
			])
			key:                 'error'
			accessibility_role:  'alert'
			accessibility_label: error_text
		}
	}
	return Element{
		...view(component_part_id(config.id, 'item:${questionnaire_hex(item.name)}'), rect(0,
			y, width, geom.height), BoxStyle{ transparent: true }, children)
		key:                 'item:' + questionnaire_hex(item.name)
		accessibility_role:  'group'
		accessibility_label: item.title
		accessibility_value: item.description
	}
}

// questionnaire_progress_text is the progress line: the position on steps,
// the answered count on a page.
fn questionnaire_progress_text(config QuestionnaireConfig, progress QuestionnaireProgress) string {
	if config.layout == .page {
		return questionnaire_fill(questionnaire_fill(config.messages.page_progress, 'answered',
			progress.answered), 'total', progress.total)
	}
	return questionnaire_fill(questionnaire_fill(config.messages.progress, 'current', progress.current),
		'total', progress.total)
}

fn questionnaire_progress_view(config QuestionnaireConfig, resolved QuestionnaireResolved, m QuestionnaireMetrics, width f64) !Element {
	progress := questionnaire_progress_of(resolved)
	caption := questionnaire_progress_text(config, progress)
	line := font_line_height(m.progress)
	mut children := [
		Element{
			...label('', caption, rect(0, 0, width, line), TextStyle{
				color: config.theme.muted_foreground
				size:  m.progress
				bold:  true
			})
			key: 'caption'
		},
	]
	if config.progress_bar {
		children << Element{
			...linear_progress(LinearProgressConfig{
				id:                  component_part_id(config.id, 'progress')
				frame:               rect(0, line + m.bar_gap, width, m.bar)
				value:               if config.layout == .page {
					progress.answered_percent()
				} else {
					progress.percent()
				}
				thickness:           m.bar
				reduce_motion:       config.reduce_motion
				accessibility_label: caption
				size:                config.size
				theme:               config.theme
			})!
			key: 'bar'
		}
	}
	return Element{
		...view('', rect(0, 0, width, questionnaire_progress_height(config, m)), BoxStyle{
			transparent: true
		}, children)
		key:                 'progress'
		accessibility_role:  'progressbar'
		accessibility_label: caption
		accessibility_value: '${progress.current}'
	}
}

fn questionnaire_button_width(caption string, m QuestionnaireMetrics, size ComponentSize) f64 {
	return math.max(m.button_min, styled_button_width(caption, '', size))
}

// questionnaire_actions draws Previous at the start and Skip, Next or Submit
// at the end of a row.
fn questionnaire_actions(config QuestionnaireConfig, nav QuestionnaireNavigation, m QuestionnaireMetrics, width f64, y f64) ![]Element {
	messages := config.messages
	height := m.button_height
	mut buttons := []Element{}
	if nav.previous {
		buttons << styled_button(StyledButtonConfig{
			id:      questionnaire_command_action_id(config.id, .previous)
			frame:   rect(0, y, questionnaire_button_width(messages.previous, m, config.size),
				height)
			label:   messages.previous
			outline: true
			enabled: config.enabled
			size:    config.size
			theme:   config.theme
		})!
	}
	mut right := width
	for command in [QuestionnaireCommand.submit, .next, .skip] {
		if !questionnaire_command_visible(nav, command) {
			continue
		}
		caption := match command {
			.submit { messages.submit }
			.next { messages.next }
			else { messages.skip }
		}
		button_width := questionnaire_button_width(caption, m, config.size)
		if right < width {
			right -= m.choices_gap
		}
		right -= button_width
		buttons << styled_button(StyledButtonConfig{
			id:      questionnaire_command_action_id(config.id, command)
			frame:   rect(math.max(0.0, right), y, button_width, height)
			label:   caption
			variant: if command == .skip { ButtonVariant.secondary } else { ButtonVariant.primary }
			outline: command == .skip
			enabled: config.enabled
			size:    config.size
			theme:   config.theme
		})!
	}
	return buttons
}

// questionnaire_scroll_part names the scroll that holds the items when they
// are taller than their room: one for a page, one per step, so each step
// starts at its top.
fn questionnaire_scroll_part(config QuestionnaireConfig, resolved QuestionnaireResolved) string {
	if config.layout == .page || resolved.current < 0 {
		return 'body'
	}
	return 'body:' + questionnaire_hex(config.items[resolved.current].name)
}

// questionnaire_scroll_id is the id of the Scroll element that holds the items
// when they are taller than the frame, for ui2.scroll_to_rect.
pub fn questionnaire_scroll_id(config QuestionnaireConfig) string {
	return component_part_id(config.id, questionnaire_scroll_part(config, questionnaire_resolve(config.items,
		config.state)))
}

// questionnaire_item_rect is where a drawn item sits in the content of that
// scroll: on a page, scroll it into view after Submit stops at it or the keys
// move to it. It returns none for items that are not drawn.
pub fn questionnaire_item_rect(config QuestionnaireConfig, name string) ?Rect {
	m := questionnaire_metrics(config.size)
	resolved := questionnaire_resolve(config.items, config.state)
	width := config.frame.width
	mut y := 0.0
	for position, index in questionnaire_rendered(config, resolved) {
		if position > 0 {
			y += m.page_gap
		}
		height := questionnaire_item_layout(config, config.items[index], width, m, questionnaire_shown_error(config,
			index, resolved)).height
		if config.items[index].name == name {
			return rect(0, y, width, height)
		}
		y += height
	}
	return none
}

// questionnaire builds the whole questionnaire: the progress line, the current
// item (or every shown item on a page) and the actions. It is controlled:
// decode its actions with questionnaire_update_from_action, the text its
// fields report with questionnaire_update_from_text and keys with
// questionnaire_update_from_key, then store the update's state and rebuild.
pub fn questionnaire(config QuestionnaireConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	questionnaire_validate(config.items)!
	m := questionnaire_metrics(config.size)
	resolved := questionnaire_resolve(config.items, config.state)
	width := config.frame.width
	height := config.frame.height
	top, bottom := questionnaire_chrome_height(config, m)
	mut children := []Element{}
	if config.show_progress && resolved.order.len > 0 {
		children << questionnaire_progress_view(config, resolved, m, width)!
	}
	body_frame := rect(0, math.min(top, height), width, math.max(0.0, height - top - bottom))
	mut items := []Element{}
	mut stack_height := 0.0
	if config.layout == .page {
		for position, index in resolved.order {
			if position > 0 {
				items << Element{
					...view('', rect(0, stack_height + m.page_gap / 2, width, 1), BoxStyle{
						bg: config.theme.border
					}, []Element{})
					key: 'separator:' + questionnaire_hex(config.items[index].name)
				}
				stack_height += m.page_gap
			}
			el := questionnaire_item_view(config, resolved, index, m, width, stack_height)
			items << el
			stack_height += el.frame.height
		}
	} else if resolved.current >= 0 {
		el := questionnaire_item_view(config, resolved, resolved.current, m, width, 0)
		items << el
		stack_height = el.frame.height
	}
	scroll_part := questionnaire_scroll_part(config, resolved)
	children << if stack_height > body_frame.height + 0.5 {
		Element{
			...scroll(component_part_id(config.id, scroll_part), body_frame, config.theme.background,
				[
					view('', rect(0, 0, width, stack_height), BoxStyle{ transparent: true }, items),
				])
			box: BoxStyle{
				transparent: true
			}
			key: scroll_part
		}
	} else {
		Element{
			...view('', body_frame, BoxStyle{ transparent: true }, items)
			key: 'body'
		}
	}
	if config.show_actions && resolved.order.len > 0 {
		children << questionnaire_actions(config, questionnaire_navigation_of(config, resolved),
			m, width, math.max(0.0, height - m.button_height))!
	}
	progress := questionnaire_progress_of(resolved)
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'form'
		accessibility_label: config.accessibility_label
		accessibility_value: questionnaire_progress_text(config, progress)
	})
}
