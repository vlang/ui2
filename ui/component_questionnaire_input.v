// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/base/src/questionnaire/keyboard.rs and the
// answer-focus movement and shortcut labels of state.rs: the key rules are
// ported to V over a highlight the application stores; action ids, decoders and
// the dialog helpers are new UI2 implementations. See third_party/gpui-kit.
module ui2

// Questionnaire action ids, decoders and keyboard handling. Every decoder takes
// the config the questionnaire was built with and returns the update to store,
// or none for actions that belong to something else, forged or malformed
// actions, parts that are not drawn (another step's choices, hidden actions),
// disabled choices and inputs, and actions that would change nothing.

fn questionnaire_hex(value string) string {
	return value.bytes().hex()
}

// questionnaire_choice_action_id is the action a choice emits, so an
// application can recognize it.
pub fn questionnaire_choice_action_id(id string, item string, value string) string {
	return component_part_id(id, 'choice:${questionnaire_hex(item)}:${questionnaire_hex(value)}')
}

// questionnaire_other_action_id is the action of the indicator beside an
// item's freeform input.
pub fn questionnaire_other_action_id(id string, item string) string {
	return component_part_id(id, 'other:${questionnaire_hex(item)}')
}

// questionnaire_input_id is the id (and change action) of an item's freeform
// field. Read the typed text with ui2.text(id) and focus it with ui2.focus(id).
pub fn questionnaire_input_id(id string, item string) string {
	return component_part_id(id, 'input:${questionnaire_hex(item)}')
}

// questionnaire_input_submit_id is what a one-line freeform field emits when
// Return is pressed in it.
pub fn questionnaire_input_submit_id(id string, item string) string {
	return component_part_id(id, 'submit:${questionnaire_hex(item)}')
}

pub enum QuestionnaireCommand {
	previous
	next
	skip
	submit
}

// questionnaire_command_action_id is the action of a navigation button.
pub fn questionnaire_command_action_id(id string, command QuestionnaireCommand) string {
	return component_part_id(id, command.str())
}

// questionnaire_rendered lists the items whose parts are drawn: the current
// item of a stepped questionnaire, every shown item of a page.
fn questionnaire_rendered(config QuestionnaireConfig, resolved QuestionnaireResolved) []int {
	if config.layout == .page {
		return resolved.order
	}
	return if resolved.current >= 0 { [resolved.current] } else { []int{} }
}

fn questionnaire_run(config QuestionnaireConfig, command QuestionnaireCommand) QuestionnaireUpdate {
	return match command {
		.previous { questionnaire_previous_op(config) }
		.next { questionnaire_next_op(config) }
		.skip { questionnaire_skip_op(config) }
		.submit { questionnaire_submit_op(config) }
	}
}

fn questionnaire_command_visible(nav QuestionnaireNavigation, command QuestionnaireCommand) bool {
	return match command {
		.previous { nav.previous }
		.next { nav.next }
		.skip { nav.skip }
		.submit { nav.submit }
	}
}

// questionnaire_focus_item makes an item of a page current before a command
// that works on the current item runs for it.
fn questionnaire_focus_item(config QuestionnaireConfig, index int) QuestionnaireConfig {
	resolved := questionnaire_resolve(config.items, config.state)
	if resolved.current == index {
		return config
	}
	return questionnaire_with_state(config, questionnaire_move(config, config.state, resolved.current,
		index).state)
}

// questionnaire_update_from_action decodes a click on a choice, on the
// indicator of a freeform input or on a navigation button, and Return in a
// one-line freeform field. Pointer activation clears the keyboard highlight.
pub fn questionnaire_update_from_action(config QuestionnaireConfig, action string) ?QuestionnaireUpdate {
	if !config.enabled {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	resolved := questionnaire_resolve(config.items, config.state)
	update := questionnaire_decode_part(config, resolved, part) or { return none }
	return questionnaire_result(config, QuestionnaireUpdate{
		...update
		state: QuestionnaireState{
			...update.state
			highlight: ''
		}
	})
}

fn questionnaire_decode_part(config QuestionnaireConfig, resolved QuestionnaireResolved, part string) ?QuestionnaireUpdate {
	if config.show_actions {
		nav := questionnaire_navigation_of(config, resolved)
		for command in [QuestionnaireCommand.previous, .next, .skip, .submit] {
			if part == command.str() {
				if !questionnaire_command_visible(nav, command) {
					return none
				}
				return questionnaire_run(config, command)
			}
		}
	}
	for index in questionnaire_rendered(config, resolved) {
		item := config.items[index]
		key := questionnaire_hex(item.name)
		if part == 'other:${key}' {
			if item.choices.len == 0 || !questionnaire_input_enabled(item) {
				return none
			}
			return questionnaire_other_op(config, index)
		}
		if part == 'submit:${key}' {
			if !questionnaire_input_enabled(item) || questionnaire_input_multiline(item)
				|| resolved.answers[index].freeform.len == 0 {
				return none
			}
			return questionnaire_confirm_op(questionnaire_focus_item(config, index))
		}
		prefix := 'choice:${key}:'
		if !part.starts_with(prefix) {
			continue
		}
		for choice in item.choices {
			value := questionnaire_choice_key(choice)
			if part != prefix + questionnaire_hex(value) {
				continue
			}
			if !questionnaire_choice_open(item, choice, resolved.answers[index]) {
				return none
			}
			return questionnaire_choose_op(config, index, value, true)
		}
		return none
	}
	return none
}

fn questionnaire_input_index(config QuestionnaireConfig, resolved QuestionnaireResolved, action string) ?int {
	if !config.enabled || action.len == 0 {
		return none
	}
	for index in questionnaire_rendered(config, resolved) {
		item := config.items[index]
		if questionnaire_input_enabled(item) && action == questionnaire_input_id(config.id, item.name) {
			return index
		}
	}
	return none
}

// questionnaire_input_item names the item whose freeform field emitted action,
// so the application knows to read the field's text with ui2.text(action).
pub fn questionnaire_input_item(config QuestionnaireConfig, action string) ?string {
	resolved := questionnaire_resolve(config.items, config.state)
	index := questionnaire_input_index(config, resolved, action) or { return none }
	return config.items[index].name
}

// questionnaire_update_from_text applies the text a freeform field reported:
// call it with the field's action and ui2.text(action).
//
//	if _ := ui2.questionnaire_input_item(cfg, action) {
//		update := ui2.questionnaire_update_from_text(cfg, action, ui2.text(action)) or { return }
//		...
//	}
pub fn questionnaire_update_from_text(config QuestionnaireConfig, action string, typed string) ?QuestionnaireUpdate {
	resolved := questionnaire_resolve(config.items, config.state)
	index := questionnaire_input_index(config, resolved, action) or { return none }
	return questionnaire_result(config, questionnaire_text_op(config, index, typed))
}

// ── Keyboard ────────────────────────────────────────────────────────

// questionnaire_key_label is the shortcut a key press names: a digit or a
// capital letter, '' for anything else.
fn questionnaire_key_label(code KeyCode) string {
	name := code.name()
	if name.len != 1 {
		return ''
	}
	ch := name[0]
	if ch >= `1` && ch <= `9` {
		return name
	}
	if ch >= `a` && ch <= `z` {
		return name.to_upper()
	}
	return ''
}

// questionnaire_choice_for_key finds the choice of an item a shortcut names.
fn questionnaire_choice_for_key(config QuestionnaireConfig, item QuestionnaireItem, key string) ?string {
	if key.len == 0 {
		return none
	}
	mut position := 0
	for choice in item.choices {
		if !choice.enabled {
			continue
		}
		if questionnaire_shortcut_label(config.shortcuts, position) == key {
			return questionnaire_choice_key(choice)
		}
		position++
	}
	return none
}

// questionnaire_key_targets are the choices the arrow keys move through, in
// order: the item's choices that can be activated.
fn questionnaire_key_targets(item QuestionnaireItem, answer QuestionnaireAnswer) []string {
	mut values := []string{}
	for choice in item.choices {
		if questionnaire_choice_open(item, choice, answer) {
			values << questionnaire_choice_key(choice)
		}
	}
	return values
}

fn questionnaire_with_highlight(update QuestionnaireUpdate, value string) QuestionnaireUpdate {
	return QuestionnaireUpdate{
		...update
		state: QuestionnaireState{
			...update.state
			highlight: value
		}
	}
}

// questionnaire_step_highlight moves the keyboard highlight through the
// current item's choices and then into its freeform input, wrapping around.
// With nothing highlighted it starts from the selected answer. On a
// single-choice item the selection follows, as in a native radio group, but
// nothing confirms.
fn questionnaire_step_highlight(config QuestionnaireConfig, index int, forward bool) QuestionnaireUpdate {
	item := config.items[index]
	resolved := questionnaire_resolve(config.items, config.state)
	answer := resolved.answers[index]
	values := questionnaire_key_targets(item, answer)
	has_input := questionnaire_other_open(item, config.state.item(item.name), answer)
	count := values.len + if has_input { 1 } else { 0 }
	if count == 0 {
		return questionnaire_noop(config)
	}
	position := values.index(config.state.highlight)
	mut target := 0
	if position >= 0 {
		target = if forward { (position + 1) % count } else { (position + count - 1) % count }
	} else {
		mut filled := []int{}
		for i, value in values {
			if answer.has(value) {
				filled << i
			}
		}
		if has_input && answer.freeform.len > 0 {
			filled << values.len
		}
		target = if filled.len > 0 {
			if forward { filled[0] } else { filled[filled.len - 1] }
		} else if forward {
			0
		} else {
			count - 1
		}
	}
	if target == values.len {
		return QuestionnaireUpdate{
			state: QuestionnaireState{
				...config.state
				highlight: ''
			}
			focus: questionnaire_input_id(config.id, item.name)
		}
	}
	value := values[target]
	if item.multiple || answer.has(value) {
		return QuestionnaireUpdate{
			state: QuestionnaireState{
				...config.state
				highlight: value
			}
		}
	}
	return questionnaire_with_highlight(questionnaire_choose_op(config, index, value, false),
		value)
}

// questionnaire_update_from_key is for the application's on_key_event
// handler, with ui2.focused_id() as focused_id. Call ui2.consume_key when it
// returns an update. Bare keys apply when no freeform field has focus:
//
//   - a shortcut digit or letter chooses its choice (and confirms a single
//     answer, like a click);
//   - Up and Down move a highlight through the current item's choices and into
//     its input; a single-choice selection follows the highlight;
//   - Left and Right do the same on a highlighted single-choice item, and
//     otherwise go to the previous item, or the next one once the current item
//     is answered or skipped;
//   - Space chooses the highlighted choice;
//   - Enter chooses the highlighted choice when it is not selected yet, and
//     otherwise confirms an answered item: Next, or Submit on the last one.
//
// In a focused one-line field Enter confirms a filled answer. Cmd+Enter (or
// Ctrl+Enter) confirms the current item from anywhere. Other modified keys,
// and every key of a disabled questionnaire, are left alone.
pub fn questionnaire_update_from_key(config QuestionnaireConfig, event KeyEvent, focused_id string) ?QuestionnaireUpdate {
	if !config.enabled {
		return none
	}
	resolved := questionnaire_resolve(config.items, config.state)
	if resolved.current < 0 {
		return none
	}
	enter := event.code == .enter || event.code == .kp_enter
	if enter && (event.cmd != event.ctrl) && !event.shift && !event.alt {
		return questionnaire_result(config, questionnaire_confirm_op(config))
	}
	if event.shift || event.ctrl || event.alt || event.cmd {
		return none
	}
	if focused := questionnaire_input_index(config, resolved, focused_id) {
		item := config.items[focused]
		if !enter || questionnaire_input_multiline(item) || resolved.answers[focused].freeform.len == 0 {
			return none
		}
		return questionnaire_result(config, questionnaire_confirm_op(questionnaire_focus_item(config,
			focused)))
	}
	index := resolved.current
	item := config.items[index]
	answer := resolved.answers[index]
	highlight := config.state.highlight
	highlighted := highlight.len > 0 && highlight in questionnaire_key_targets(item, answer)
	update := match event.code {
		.up, .down {
			questionnaire_step_highlight(config, index, event.code == .down)
		}
		.left, .right {
			if highlighted && !item.multiple {
				questionnaire_step_highlight(config, index, event.code == .right)
			} else if event.code == .left {
				questionnaire_previous_op(config)
			} else if questionnaire_navigation_of(config, resolved).confirmable {
				questionnaire_next_op(config)
			} else {
				questionnaire_noop(config)
			}
		}
		.space {
			if highlighted {
				questionnaire_with_highlight(questionnaire_choose_op(config, index, highlight,
					true), highlight)
			} else {
				questionnaire_noop(config)
			}
		}
		.enter, .kp_enter {
			if highlighted && !answer.has(highlight) {
				questionnaire_with_highlight(questionnaire_choose_op(config, index, highlight,
					true), highlight)
			} else if questionnaire_navigation_of(config, resolved).confirmable {
				questionnaire_confirm_op(config)
			} else {
				questionnaire_noop(config)
			}
		}
		else {
			questionnaire_shortcut_update(config, index, event.code)
		}
	}
	return questionnaire_result(config, update)
}

fn questionnaire_shortcut_update(config QuestionnaireConfig, index int, code KeyCode) QuestionnaireUpdate {
	if config.shortcuts == .off {
		return questionnaire_noop(config)
	}
	item := config.items[index]
	value := questionnaire_choice_for_key(config, item, questionnaire_key_label(code)) or {
		return questionnaire_noop(config)
	}
	answer := questionnaire_resolve(config.items, config.state).answers[index]
	choice_index := questionnaire_choice_index(item, value)
	if !questionnaire_choice_open(item, item.choices[choice_index], answer) {
		return questionnaire_noop(config)
	}
	return questionnaire_with_highlight(questionnaire_choose_op(config, index, value, true),
		value)
}

// ── Dialog composition ──────────────────────────────────────────────

// questionnaire_dialog_button_id is the DialogButton id that
// questionnaire_dialog_buttons gives a command.
pub fn questionnaire_dialog_button_id(command QuestionnaireCommand) string {
	return 'questionnaire:${command}'
}

// questionnaire_dialog_buttons puts the questionnaire's visible actions in a
// dialog footer, after the application's own buttons (a Cancel, normally):
//
//	mut buttons := [ui2.DialogButton{ id: 'cancel', text: 'Cancel', role: .cancel }]
//	buttons << ui2.questionnaire_dialog_buttons(cfg)
//
// Build the questionnaire itself with show_actions: false, and decode the
// dialog's events with questionnaire_update_from_dialog. Next and Submit are
// confirm buttons, so Enter in the dialog runs them.
pub fn questionnaire_dialog_buttons(config QuestionnaireConfig) []DialogButton {
	nav := questionnaire_navigation(config)
	messages := config.messages
	mut buttons := []DialogButton{}
	if nav.previous {
		buttons << DialogButton{
			id:      questionnaire_dialog_button_id(.previous)
			text:    messages.previous
			variant: .outline
			enabled: config.enabled
		}
	}
	if nav.skip {
		buttons << DialogButton{
			id:      questionnaire_dialog_button_id(.skip)
			text:    messages.skip
			variant: .ghost
			enabled: config.enabled
		}
	}
	if nav.next {
		buttons << DialogButton{
			id:      questionnaire_dialog_button_id(.next)
			text:    messages.next
			role:    .confirm
			enabled: config.enabled
		}
	}
	if nav.submit {
		buttons << DialogButton{
			id:      questionnaire_dialog_button_id(.submit)
			text:    messages.submit
			role:    .confirm
			enabled: config.enabled
		}
	}
	return buttons
}

// questionnaire_update_from_dialog runs the command of a footer button that
// questionnaire_dialog_buttons added. Other buttons, and commands not shown,
// give none.
pub fn questionnaire_update_from_dialog(config QuestionnaireConfig, event DialogEvent) ?QuestionnaireUpdate {
	if !config.enabled || event.reason !in [.action, .confirm] {
		return none
	}
	nav := questionnaire_navigation(config)
	for command in [QuestionnaireCommand.previous, .next, .skip, .submit] {
		if event.button == questionnaire_dialog_button_id(command) {
			if !questionnaire_command_visible(nav, command) {
				return none
			}
			return questionnaire_result(config, questionnaire_run(config, command))
		}
	}
	return none
}
