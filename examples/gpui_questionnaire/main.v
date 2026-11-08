module main

import ui2

// A product feedback survey built on ui2's questionnaire: a required rating,
// a follow-up that only appears for lukewarm ratings (a multi-select limited
// to two answers, with an "other" text answer), a multi-select with a range,
// an optional question with its own "other" answer, a required free-text
// question with a custom validator, and an optional last question. The same
// questionnaire, sharing its answers, also runs in a dialog whose footer
// carries its actions.
//
// The application owns everything: it stores the QuestionnaireState, hands
// every action, text change and key to the questionnaire's decoders, stores
// the state they return and reads their events into the activity panel.

const window_width = 1080
const window_height = 780
const card_pad = 28.0

@[heap]
struct Survey {
mut:
	dark        bool
	page        bool // every question on one page instead of one per step
	qs          ui2.QuestionnaireState
	submitted   bool
	sent        ui2.QuestionnaireAnswers
	dialog_open bool
	log         []LogLine
	timer       ui2.TimerId
}

struct LogLine {
	kind   string
	detail string
}

const survey = &Survey{}

fn theme_of(app &Survey) ui2.ComponentTheme {
	return ui2.component_theme(app.dark)
}

fn page_background(app &Survey) u32 {
	return if app.dark { u32(0x0f1729) } else { u32(0xf1f5f9) }
}

// window_frame is the window's content area, or its initial size before the
// window exists.
fn window_frame() ui2.Rect {
	b := ui2.bounds()
	if b.width <= 0 || b.height <= 0 {
		return ui2.rect(0, 0, window_width, window_height)
	}
	return ui2.rect(0, 0, b.width, b.height)
}

// ── The survey ──────────────────────────────────────────────────────

fn feedback_items() []ui2.QuestionnaireItem {
	return [
		ui2.QuestionnaireItem{
			name:        'satisfaction'
			title:       'How satisfied are you with Acme Notes?'
			description: 'Think about the last month of use.'
			required:    true
			choices:     [
				ui2.QuestionnaireChoice{
					value: 'very_satisfied'
					label: 'Very satisfied'
				},
				ui2.QuestionnaireChoice{
					value: 'satisfied'
					label: 'Satisfied'
				},
				ui2.QuestionnaireChoice{
					value: 'neutral'
					label: 'Neutral'
				},
				ui2.QuestionnaireChoice{
					value: 'dissatisfied'
					label: 'Dissatisfied'
				},
			]
		},
		ui2.QuestionnaireItem{
			name:        'problems'
			title:       'What got in the way?'
			description: 'Pick the two that mattered most.'
			required:    true
			multiple:    true
			max_choices: 2
			visible_if:  ui2.questionnaire_when_chosen('satisfaction', [
				'neutral',
				'dissatisfied',
			])
			choices:     [
				ui2.QuestionnaireChoice{
					value:       'sync'
					label:       'Slow sync'
					description: 'Changes take a while to reach my other devices.'
				},
				ui2.QuestionnaireChoice{
					value: 'search'
					label: 'Search misses notes'
				},
				ui2.QuestionnaireChoice{
					value: 'price'
					label: 'Too expensive'
				},
			]
			input:       ui2.QuestionnaireInput{
				label:       'Something else'
				placeholder: 'Something else…'
			}
		},
		ui2.QuestionnaireItem{
			name:        'features'
			title:       'Which features do you use most?'
			required:    true
			multiple:    true
			min_choices: 1
			max_choices: 3
			choices:     [
				ui2.QuestionnaireChoice{
					value: 'capture'
					label: 'Quick capture'
				},
				ui2.QuestionnaireChoice{
					value: 'shared'
					label: 'Shared notebooks'
				},
				ui2.QuestionnaireChoice{
					value: 'offline'
					label: 'Offline mode'
				},
				ui2.QuestionnaireChoice{
					value: 'clipper'
					label: 'Web clipper'
				},
				ui2.QuestionnaireChoice{
					value: 'templates'
					label: 'Templates'
				},
			]
		},
		ui2.QuestionnaireItem{
			name:    'discovery'
			title:   'How did you first hear about us?'
			choices: [
				ui2.QuestionnaireChoice{
					value: 'search'
					label: 'Search engine'
				},
				ui2.QuestionnaireChoice{
					value: 'friend'
					label: 'A friend or colleague'
				},
				ui2.QuestionnaireChoice{
					value: 'podcast'
					label: 'Podcast or newsletter'
				},
			]
			input:   ui2.QuestionnaireInput{
				label:       'Somewhere else'
				placeholder: 'Somewhere else…'
			}
		},
		ui2.QuestionnaireItem{
			name:        'improve'
			title:       'What is one thing we should improve?'
			description: 'A sentence or two is plenty.'
			required:    true
			input:       ui2.QuestionnaireInput{
				label:     'Suggested improvement'
				multiline: true
				lines:     4
			}
			validator:   fn (context ui2.QuestionnaireValidationContext) ! {
				if context.answer.freeform.trim_space().runes().len < 20 {
					return error('Tell us a little more: at least 20 characters.')
				}
			}
		},
		ui2.QuestionnaireItem{
			name:    'contact'
			title:   'May we follow up about your answers?'
			choices: [
				ui2.QuestionnaireChoice{
					value:       'yes'
					label:       'Yes, email me'
					description: 'One message from feedback@acme.example, no newsletter.'
				},
				ui2.QuestionnaireChoice{
					value: 'no'
					label: 'No, thanks'
				},
			]
		},
	]
}

fn card_frame() ui2.Rect {
	frame := window_frame()
	return ui2.rect(24, 100, 620, frame.height - 124)
}

fn page_config(app &Survey) ui2.QuestionnaireConfig {
	card := card_frame()
	return ui2.QuestionnaireConfig{
		id:                  'feedback'
		frame:               ui2.rect(card_pad, card_pad, card.width - 2 * card_pad, card.height - 2 * card_pad)
		items:               feedback_items()
		state:               app.qs
		layout:              if app.page { .page } else { .stepped }
		shortcuts:           .numbers
		accessibility_label: 'Product feedback'
		theme:               theme_of(app)
	}
}

const dialog_width = 540.0

fn dialog_base(app &Survey) ui2.DialogConfig {
	return ui2.DialogConfig{
		id:           'quick'
		frame:        window_frame()
		open:         app.dialog_open
		title:        'Quick feedback'
		description:  'The same questionnaire in a dialog. Its answers are shared with the page.'
		custom_width: dialog_width
		theme:        theme_of(app)
	}
}

fn dialog_questionnaire(app &Survey) ui2.QuestionnaireConfig {
	config := ui2.QuestionnaireConfig{
		id:                  'quick-survey'
		frame:               ui2.rect(0, 0, ui2.dialog_body_width(dialog_base(app)), 0)
		items:               feedback_items()
		state:               app.qs
		shortcuts:           .numbers
		show_actions:        false
		accessibility_label: 'Quick feedback'
		theme:               theme_of(app)
	}
	return ui2.QuestionnaireConfig{
		...config
		frame: ui2.rect(0, 0, config.frame.width, ui2.questionnaire_natural_height(config))
	}
}

fn dialog_config(app &Survey) ui2.DialogConfig {
	questions := dialog_questionnaire(app)
	mut buttons := [
		ui2.DialogButton{
			id:   'cancel'
			text: 'Cancel'
			role: .cancel
		},
	]
	buttons << ui2.questionnaire_dialog_buttons(questions)
	return ui2.DialogConfig{
		...dialog_base(app)
		children:       [ui2.questionnaire(questions) or { panic(err) }]
		content_height: questions.frame.height
		buttons:        buttons
	}
}

// active_config is the questionnaire keys and timers go to: the dialog's
// while it is open, the page's otherwise.
fn active_config(app &Survey) ui2.QuestionnaireConfig {
	return if app.dialog_open { dialog_questionnaire(app) } else { page_config(app) }
}

// ── Applying updates ────────────────────────────────────────────────

fn item_title(name string) string {
	for item in feedback_items() {
		if item.name == name {
			return item.title
		}
	}
	return name
}

// answer_text describes an answer for the log and the summary.
fn answer_text(name string, answer ui2.QuestionnaireAnswer) string {
	mut parts := []string{}
	for item in feedback_items() {
		if item.name != name {
			continue
		}
		for choice in item.choices {
			if answer.has(choice.value) {
				parts << choice.label
			}
		}
	}
	if answer.freeform.len > 0 {
		parts << '“${answer.freeform.trim_space()}”'
	}
	return parts.join(', ')
}

fn (mut app Survey) note(kind string, detail string) {
	app.log << LogLine{kind, detail}
	if app.log.len > 9 {
		app.log = app.log[app.log.len - 9..].clone()
	}
}

fn (mut app Survey) record(event ui2.QuestionnaireEvent) {
	match event.kind {
		.current_item_changed {
			app.note('step', 'Now on “${item_title(event.item)}”')
		}
		.answer_changed {
			detail := match event.status {
				.skipped { 'skipped' }
				.unanswered { 'cleared' }
				.answered { answer_text(event.item, event.answer) }
			}
			app.note('answer', '${event.item}: ${detail}')
		}
		.invalid {
			app.note('invalid', '${event.item}: ${event.error}')
		}
		.completed {
			app.note('completed', '${event.answers.items.len} questions answered or skipped')
		}
		.submit {
			app.note('submit', 'Sent to the server (not really)')
		}
	}
}

// apply stores an update, logs its events, and arranges what has to wait: the
// pending confirm of a chosen answer and moving focus once the tree is built.
fn (mut app Survey) apply(update ui2.QuestionnaireUpdate) {
	app.qs = update.state
	for event in update.events {
		app.record(event)
	}
	if sent := update.submission() {
		app.sent = sent
		app.submitted = true
		app.dialog_open = false
		ui2.dismiss_keyboard()
	}
	if update.confirm_later {
		ui2.cancel_timer(app.timer)
		app.timer = ui2.after(ui2.questionnaire_confirm_delay, fn () {
			mut later := unsafe { survey }
			if next := ui2.questionnaire_confirm_pending(active_config(later)) {
				later.apply(next)
			}
		})
	}
	if update.focus.len > 0 {
		target := update.focus
		ui2.after(0.05, fn [target] () {
			ui2.focus(target)
		})
	}
	// On a page, bring the item Submit stopped at into view.
	if app.page && update.events.any(it.kind == .invalid) {
		app.reveal_current()
	}
}

// reveal_current scrolls the page so the current item's title shows, once the
// tree it is in has been built.
fn (app &Survey) reveal_current() {
	config := page_config(app)
	area := ui2.questionnaire_item_rect(config, ui2.questionnaire_current(config)) or { return }
	scroll_id := ui2.questionnaire_scroll_id(config)
	ui2.after(0.05, fn [scroll_id, area] () {
		ui2.scroll_to_rect(scroll_id, area.x, area.y, area.width, if area.height < 160 {
			area.height
		} else {
			160
		})
	})
}

// questionnaire_action offers an action to one questionnaire: a field's text
// change, or a click on one of its parts.
fn (mut app Survey) questionnaire_action(config ui2.QuestionnaireConfig, action string) bool {
	if _ := ui2.questionnaire_input_item(config, action) {
		if update := ui2.questionnaire_update_from_text(config, action, ui2.text(action)) {
			app.apply(update)
		}
		return true
	}
	if update := ui2.questionnaire_update_from_action(config, action) {
		app.apply(update)
		return true
	}
	return false
}

fn handle_event(action string) {
	mut app := unsafe { survey }
	if app.dialog_open {
		questions := dialog_questionnaire(app)
		if app.questionnaire_action(questions, action) {
			ui2.refresh()
			return
		}
		if event := ui2.dialog_event_from_action(dialog_config(app), action) {
			if event.dismisses() {
				app.dialog_open = false
				app.note('dialog', 'Closed; the answers stay')
			} else if update := ui2.questionnaire_update_from_dialog(questions, event) {
				app.apply(update)
			}
			ui2.refresh()
			return
		}
	} else if !app.submitted && app.questionnaire_action(page_config(app), action) {
		ui2.refresh()
		return
	}
	if selection := ui2.toggle_group_selection_from_action(layout_config(app), action) {
		app.page = selection == ['page']
		app.note('layout', if app.page {
			'All questions on one page'
		} else {
			'One question per step'
		})
	} else if pressed := ui2.toggle_pressed_from_action(dark_config(app), action) {
		app.dark = pressed
	} else {
		match action {
			'open-dialog' {
				app.dialog_open = true
				app.note('dialog', 'Opened')
				if animation := ui2.dialog_open_animation(dialog_config(app)) {
					animation.start(ui2.dialog_surface_id('quick'))
				}
			}
			'edit' {
				app.submitted = false
				first := ui2.questionnaire_active_items(page_config(app))[0] or { '' }
				app.qs = ui2.questionnaire_set_current(page_config(app), first) or { app.qs }
				app.note('edit', 'Back to the questions; the next submit is not a new completion')
			}
			'restart' {
				app.submitted = false
				app.qs = ui2.questionnaire_reset(page_config(app))
				app.log = []LogLine{}
				app.note('reset', 'Back to the initial answers')
			}
			else {
				return
			}
		}
	}
	ui2.refresh()
}

fn handle_key(event ui2.KeyEvent) {
	mut app := unsafe { survey }
	if app.submitted && !app.dialog_open {
		return
	}
	config := active_config(app)
	if update := ui2.questionnaire_update_from_key(config, event, ui2.focused_id()) {
		ui2.consume_key()
		moved := update.events.any(it.kind == .current_item_changed)
		app.apply(update)
		if moved && app.page && !app.dialog_open {
			app.reveal_current()
		}
		ui2.refresh()
		return
	}
	if !app.dialog_open {
		return
	}
	if request := ui2.dialog_key_event(dialog_config(app), event) {
		ui2.consume_key()
		if request.dismisses() {
			app.dialog_open = false
			app.note('dialog', 'Closed; the answers stay')
		} else if update := ui2.questionnaire_update_from_dialog(config, request) {
			app.apply(update)
		}
		ui2.refresh()
	}
}

// ── The page ────────────────────────────────────────────────────────

fn layout_config(app &Survey) ui2.ToggleGroupConfig {
	return ui2.ToggleGroupConfig{
		id:                  'layout'
		frame:               ui2.rect(window_frame().width - 470, 30, 190, 32)
		items:               [
			ui2.ToggleItem{
				value: 'steps'
				label: 'Steps'
				icon:  'list.number'
			},
			ui2.ToggleItem{
				value: 'page'
				label: 'One page'
				icon:  'doc.text.fill'
			},
		]
		selected:            [if app.page { 'page' } else { 'steps' }]
		multiple:            false
		allow_empty:         false
		segmented:           true
		fill:                true
		variant:             .outline
		accessibility_label: 'Layout'
		theme:               theme_of(app)
	}
}

fn dark_config(app &Survey) ui2.ToggleConfig {
	return ui2.ToggleConfig{
		id:      'dark'
		frame:   ui2.rect(window_frame().width - 268, 30, 84, 32)
		label:   'Dark'
		icon:    if app.dark { 'moon.fill' } else { 'moon' }
		pressed: app.dark
		variant: .outline
		theme:   theme_of(app)
	}
}

fn text(content string, frame ui2.Rect, color u32, size f64, bold bool) ui2.Element {
	return ui2.label('', content, frame, ui2.TextStyle{
		color: color
		size:  size
		bold:  bold
	})
}

// surface is a card: the theme background with a border and a soft shadow.
fn surface(id string, frame ui2.Rect, theme ui2.ComponentTheme, children []ui2.Element) ui2.Element {
	return ui2.Element{
		...ui2.view(id, frame, ui2.BoxStyle{
			bg:            theme.background
			radius:        12
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        ui2.component_card_shadow()
		}, children)
		accessibility_role: 'group'
	}
}

fn summary(app &Survey, frame ui2.Rect, theme ui2.ComponentTheme) []ui2.Element {
	width := frame.width - 2 * card_pad
	mut children := []ui2.Element{}
	children << ui2.Element{
		...ui2.image('', 'symbol:checkmark.circle.fill', ui2.rect(card_pad, card_pad, 40,
			40))
		text_style: ui2.TextStyle{
			color: theme.success
		}
	}
	children << text('Thanks for the feedback!', ui2.rect(card_pad + 56, card_pad - 2, width - 56,
		28), theme.foreground, 20, true)
	children << text('We read every response. This is what we received:', ui2.rect(card_pad + 56,
		card_pad + 26, width - 56, 20), theme.muted_foreground, 13, false)
	mut y := card_pad + 76
	for entry in app.sent.items {
		answer := match entry.status {
			.skipped { 'Skipped' }
			.unanswered { '—' }
			.answered { answer_text(entry.name, entry.answer) }
		}
		children << text(item_title(entry.name), ui2.rect(card_pad, y, width, 18), theme.muted_foreground,
			12, true)
		children << ui2.label('', answer, ui2.rect(card_pad, y + 20, width, 40), ui2.TextStyle{
			color:  if entry.status == .answered {
				theme.foreground
			} else {
				theme.muted_foreground
			}
			size:   14
			valign: .top
			lines:  2
		})
		y += 68
	}
	buttons_y := frame.height - card_pad - 32
	children << ui2.styled_button(
		id:      'edit'
		frame:   ui2.rect(card_pad, buttons_y, 130, 32)
		label:   'Edit answers'
		icon:    'pencil'
		outline: true
		theme:   theme
	) or { panic(err) }
	children << ui2.styled_button(
		id:      'restart'
		frame:   ui2.rect(card_pad + 142, buttons_y, 120, 32)
		label:   'Start over'
		icon:    'arrow.uturn.backward'
		variant: .primary
		theme:   theme
	) or { panic(err) }
	return children
}

fn answers_panel(app &Survey, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	config := page_config(app)
	width := frame.width - 40
	mut children := [
		text('Your answers', ui2.rect(20, 18, width, 20), theme.foreground, 15, true),
	]
	progress := ui2.questionnaire_progress(config)
	children << text('${progress.answered} of ${progress.total} questions done' + if app.qs.complete {
		' · submitted'
	} else {
		''
	}, ui2.rect(20, 40, width, 18), theme.muted_foreground, 12, false)
	mut y := 70.0
	for entry in ui2.questionnaire_answers(config).items {
		current := ui2.questionnaire_current(config) == entry.name && !app.submitted
		if current {
			children << ui2.view('', ui2.rect(12, y - 4, 3, 38), ui2.BoxStyle{
				bg:     theme.primary
				radius: 1.5
			}, []ui2.Element{})
		}
		children << text(item_title(entry.name), ui2.rect(20, y, width, 16), theme.muted_foreground,
			12, current)
		value := match entry.status {
			.skipped { 'Skipped' }
			.unanswered { 'Not answered yet' }
			.answered { answer_text(entry.name, entry.answer) }
		}
		children << text(value, ui2.rect(20, y + 16, width, 18), if entry.status == .answered {
			theme.foreground
		} else {
			theme.muted_foreground
		}, 13, false)
		y += 46
	}
	return surface('answers', frame, theme, children)
}

fn activity_panel(app &Survey, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	width := frame.width - 40
	mut children := [
		text('Activity', ui2.rect(20, 18, width, 20), theme.foreground, 15, true),
		text('Events the questionnaire reported, newest last.', ui2.rect(20, 40, width, 18),
			theme.muted_foreground, 12, false),
	]
	// The newest lines that fit.
	room := int((frame.height - 68 - 12) / 22)
	shown := if app.log.len > room { app.log[app.log.len - room..] } else { app.log }
	mut y := 68.0
	for line in shown {
		tone := match line.kind {
			'invalid' { theme.danger }
			'completed', 'submit' { theme.success }
			'answer' { theme.primary }
			else { theme.muted_foreground }
		}
		children << ui2.label('', line.kind, ui2.rect(20, y, 76, 18), ui2.TextStyle{
			color:       tone
			size:        11
			bold:        true
			font_family: 'monospace'
		})
		children << text(line.detail, ui2.rect(100, y, width - 80, 18), theme.foreground, 12,
			false)
		y += 22
	}
	return surface('activity', frame, theme, children)
}

fn build() ui2.Element {
	app := unsafe { survey }
	theme := theme_of(app)
	frame := window_frame()
	card := card_frame()
	mut children := [
		text('Product feedback', ui2.rect(24, 22, 400, 30), theme.foreground, 22, true),
		text('Help us make Acme Notes better: six short questions, about two minutes.',
			ui2.rect(24, 56, 560, 20), theme.muted_foreground, 13, false),
		ui2.toggle_group(layout_config(app)) or { panic(err) },
		ui2.toggle(dark_config(app)) or { panic(err) },
		ui2.styled_button(
			id:      'open-dialog'
			frame:   ui2.rect(frame.width - 172, 30, 148, 32)
			label:   'Open in dialog'
			icon:    'text.bubble'
			variant: .primary
			theme:   theme
		) or { panic(err) },
	]
	card_children := if app.submitted {
		summary(app, card, theme)
	} else {
		[ui2.questionnaire(page_config(app)) or { panic(err) }]
	}
	children << surface('card', card, theme, card_children)
	side_x := card.x + card.width + 24
	side_width := frame.width - side_x - 24
	answers_height := 82.0 + 46 * f64(ui2.questionnaire_answers(page_config(app)).items.len)
	children << answers_panel(app, ui2.rect(side_x, card.y, side_width, answers_height), theme)
	activity_y := card.y + answers_height + 20
	children << activity_panel(app, ui2.rect(side_x, activity_y, side_width, card.y + card.height - activity_y - 52),
		theme)
	children << ui2.label('', 'Keys: 1–5 choose · ↑ ↓ move · Space select · Enter continue · ← → previous / next · Cmd+Enter confirm',
		ui2.rect(side_x, card.y + card.height - 36, side_width, 36), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   12
			valign: .top
			lines:  2
		})
	// The dialog comes last so it is drawn over the page.
	children << ui2.modal_dialog(dialog_config(app)) or { panic(err) }
	return ui2.screen(page_background(app), children)
}

fn main() {
	mut app := unsafe { survey }
	app.qs = ui2.questionnaire_initial_state(feedback_items()) or { panic(err) }
	// Answer the first question and part of the follow-up it reveals, through
	// the same calls a person's clicks and typing make, so the activity panel
	// starts with what they reported.
	app.note('start', 'Six questions; one appears only for lukewarm ratings')
	if update := ui2.questionnaire_activate_choice(page_config(app), 'satisfaction', 'neutral') {
		app.apply(update)
	}
	if update := ui2.questionnaire_next(page_config(app)) {
		app.apply(update)
	}
	if update := ui2.questionnaire_choose(page_config(app), 'problems', 'sync') {
		app.apply(update)
	}
	field := ui2.questionnaire_input_id('feedback', 'problems')
	if update := ui2.questionnaire_update_from_text(page_config(app), field, 'Sharing links expire too soon') {
		app.apply(update)
	}
	ui2.on_key_event(handle_key)
	ui2.run_window('GPUI Kit questionnaire', window_width, window_height, build, handle_event)
}
