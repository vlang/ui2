module ui2

// ── Fixtures ────────────────────────────────────────────────────────

fn qn_choices(values ...string) []QuestionnaireChoice {
	return values.map(QuestionnaireChoice{
		value: it
		label: it.capitalize()
	})
}

// qn_items is a survey: a required single choice, a conditional multiple
// choice with a limit and an "other" input, an optional single choice, and a
// required free-text question with a validator.
fn qn_items() []QuestionnaireItem {
	return [
		QuestionnaireItem{
			name:     'mood'
			title:    'How was it?'
			required: true
			choices:  qn_choices('good', 'okay', 'bad')
		},
		QuestionnaireItem{
			name:        'issues'
			title:       'What went wrong?'
			multiple:    true
			required:    true
			max_choices: 2
			choices:     qn_choices('slow', 'crash', 'price')
			input:       QuestionnaireInput{
				label:       'Something else'
				placeholder: 'Type another answer'
			}
			visible_if:  questionnaire_when_chosen('mood', ['okay', 'bad'])
		},
		QuestionnaireItem{
			name:    'source'
			title:   'Where did you hear of us?'
			choices: qn_choices('search', 'friend')
			input:   QuestionnaireInput{
				label: 'Other source'
			}
		},
		QuestionnaireItem{
			name:      'improve'
			title:     'What should we improve?'
			required:  true
			input:     QuestionnaireInput{
				label:     'Improvement'
				multiline: true
			}
			validator: fn (context QuestionnaireValidationContext) ! {
				if context.answer.freeform.trim_space().len < 5 {
					return error('Write at least five characters.')
				}
			}
		},
	]
}

fn qn_config(qs QuestionnaireState) QuestionnaireConfig {
	return QuestionnaireConfig{
		id:            'survey'
		frame:         rect(0, 0, 480, 520)
		items:         qn_items()
		state:         qs
		shortcuts:     .numbers
		reduce_motion: false
	}
}

fn qn_start() QuestionnaireConfig {
	return qn_config(questionnaire_initial_state(qn_items()) or { panic(err) })
}

// qn_apply stores an update's state in the config, as an application would.
fn qn_apply(config QuestionnaireConfig, update ?QuestionnaireUpdate) QuestionnaireConfig {
	next := update or { panic('expected an update') }
	return questionnaire_with_state(config, next.state)
}

fn qn_kinds(update QuestionnaireUpdate) []QuestionnaireEventKind {
	return update.events.map(it.kind)
}

fn qn_key(code KeyCode) KeyEvent {
	return KeyEvent{
		code: code
	}
}

fn qn_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := qn_find(child, id) {
			return found
		}
	}
	return none
}

fn qn_collect(el Element, keep fn (Element) bool) []Element {
	mut found := []Element{}
	if keep(el) {
		found << el
	}
	for child in el.children {
		found << qn_collect(child, keep)
	}
	return found
}

fn qn_texts(el Element) []string {
	return qn_collect(el, fn (e Element) bool {
		return e.kind == .label
	}).map(it.text)
}

// qn_assert_inside checks that every child lies inside its parent, except the
// content of a scroll element, which may be taller.
fn qn_assert_inside(el Element) {
	component_validate_frame(el.frame) or { panic(err) }
	if el.kind == .scroll {
		return
	}
	for child in el.children {
		f := child.frame
		assert f.x >= -1e-6 && f.y >= -1e-6 && f.x + f.width <= el.frame.width + 1e-6
			&& f.y + f.height <= el.frame.height + 1e-6, '${child.key} ${f} outside ${el.key} ${el.frame}'
		qn_assert_inside(child)
	}
}

// ── Schema ──────────────────────────────────────────────────────────

fn test_questionnaire_validate_rejects_bad_schemas() {
	questionnaire_validate(qn_items()) or { panic(err) }
	bad := [
		[QuestionnaireItem{
			name:    ' '
			choices: qn_choices('a')
		}],
		[QuestionnaireItem{
			name:    'a'
			choices: qn_choices('x')
		}, QuestionnaireItem{
			name:    'a'
			choices: qn_choices('y')
		}],
		[QuestionnaireItem{
			name:    'a'
			choices: qn_choices('x', 'x')
		}],
		[QuestionnaireItem{
			name:    'a'
			choices: [QuestionnaireChoice{
				label:    'x'
				selected: true
			}, QuestionnaireChoice{
				label:    'y'
				selected: true
			}]
		}],
		[QuestionnaireItem{
			name:        'a'
			max_choices: 2
			choices:     qn_choices('x')
		}],
		[QuestionnaireItem{
			name:        'a'
			multiple:    true
			min_choices: 3
			max_choices: 2
			choices:     qn_choices('x', 'y', 'z')
		}],
		[QuestionnaireItem{
			name:        'a'
			multiple:    true
			max_choices: 1
			choices:     [QuestionnaireChoice{
				label:    'x'
				selected: true
			}, QuestionnaireChoice{
				label:    'y'
				selected: true
			}]
		}],
		[QuestionnaireItem{
			name:  'a'
			input: QuestionnaireInput{
				placeholder: 'no label'
			}
		}],
		[QuestionnaireItem{
			name: 'a'
		}],
	]
	for items in bad {
		if _ := questionnaire_validate(items) {
			assert false, 'accepted ${items.map(it.name)}'
		}
		if _ := questionnaire_initial_state(items) {
			assert false, 'built a state for ${items.map(it.name)}'
		}
		if _ := questionnaire(id: 'q', frame: rect(0, 0, 100, 100), items: items) {
			assert false, 'drew ${items.map(it.name)}'
		}
	}
	// Two defaults are fine on a multiple-choice item.
	questionnaire_validate([
		QuestionnaireItem{
			name:     'a'
			multiple: true
			choices:  [QuestionnaireChoice{
				label:    'x'
				selected: true
			}, QuestionnaireChoice{
				label:    'y'
				selected: true
			}]
		},
	]) or { panic(err) }
}

fn test_questionnaire_initial_state_applies_defaults() {
	items := [
		QuestionnaireItem{
			name:    'off'
			enabled: false
			choices: qn_choices('a')
		},
		QuestionnaireItem{
			name:    'plan'
			choices: [QuestionnaireChoice{
				label: 'Plus'
			}, QuestionnaireChoice{
				label:    'Pro'
				selected: true
			}]
		},
		QuestionnaireItem{
			name:     'tools'
			multiple: true
			choices:  [QuestionnaireChoice{
				label:    'Editor'
				selected: true
			}, QuestionnaireChoice{
				label:    'Browser'
				selected: true
				enabled:  false
			}]
			input:    QuestionnaireInput{
				label: 'Other'
				text:  'Terminal'
			}
		},
		QuestionnaireItem{
			name:    'role'
			choices: [QuestionnaireChoice{
				label:    'Dev'
				selected: true
			}]
			input:   QuestionnaireInput{
				label: 'Other'
				text:  'Designer'
			}
		},
	]
	qs := questionnaire_initial_state(items) or { panic(err) }
	assert qs.current == 'plan'
	config := QuestionnaireConfig{
		id:    'q'
		items: items
		state: qs
	}
	assert questionnaire_answer(config, 'plan').choices == ['Pro']
	tools := questionnaire_answer(config, 'tools')
	assert tools.choices == ['Editor']
	assert tools.freeform == 'Terminal'
	// A default draft is a single-choice item's answer and replaces its choice.
	role := questionnaire_answer(config, 'role')
	assert role.choices.len == 0 && role.freeform == 'Designer'
	assert questionnaire_answer(config, 'off').is_empty()
	assert questionnaire_active_items(config) == ['plan', 'tools', 'role']
	assert questionnaire_status(config, 'plan') == .answered
}

// ── Visibility, answers and progress ────────────────────────────────

fn test_questionnaire_conditions_follow_earlier_answers() {
	mut config := qn_start()
	assert questionnaire_active_items(config) == ['mood', 'source', 'improve']
	assert !questionnaire_item_visible(config, 'issues')
	assert questionnaire_progress(config) == QuestionnaireProgress{
		current:  1
		total:    3
		answered: 0
	}
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'bad'))
	assert questionnaire_item_visible(config, 'issues')
	assert questionnaire_progress(config).total == 4
	config = questionnaire_with_state(config, questionnaire_set_answer(config, 'issues',
		QuestionnaireAnswer{ choices: ['crash'] }) or { panic(err) })
	assert questionnaire_answer(config, 'issues').choices == ['crash']
	// Hiding the follow-up removes its answer from the answers and the totals,
	// but the stored state keeps it for when it shows again.
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'good'))
	assert !questionnaire_item_visible(config, 'issues')
	assert questionnaire_answer(config, 'issues').is_empty()
	assert questionnaire_answers(config).items.map(it.name) == ['mood', 'source', 'improve']
	assert config.state.item('issues').choices == ['crash']
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'okay'))
	assert questionnaire_answer(config, 'issues').choices == ['crash']
}

fn test_questionnaire_conditions_chain_and_disabled_items_leave() {
	items := [
		QuestionnaireItem{
			name:    'a'
			choices: qn_choices('yes', 'no')
		},
		QuestionnaireItem{
			name:       'b'
			choices:    qn_choices('yes', 'no')
			visible_if: questionnaire_when_chosen('a', ['yes'])
		},
		QuestionnaireItem{
			name:       'c'
			choices:    qn_choices('x')
			visible_if: questionnaire_when_answered('b')
		},
		QuestionnaireItem{
			name:    'd'
			enabled: false
			choices: qn_choices('x')
		},
	]
	mut config := QuestionnaireConfig{
		id:    'q'
		items: items
		state: QuestionnaireState{
			items: [QuestionnaireItemState{
				name:    'a'
				choices: ['yes']
			}, QuestionnaireItemState{
				name:    'b'
				choices: ['no']
			}]
		}
	}
	assert questionnaire_active_items(config) == ['a', 'b', 'c']
	// c depends on b, which depends on a: hiding b hides c with it.
	config = questionnaire_with_state(config, questionnaire_set_answer(config, 'a', QuestionnaireAnswer{
		choices: ['no']
	}) or { panic(err) })
	assert questionnaire_active_items(config) == ['a']
}

fn test_questionnaire_answers_keep_schema_order_and_drop_disabled_choices() {
	items := [
		QuestionnaireItem{
			name:     'tools'
			multiple: true
			choices:  [QuestionnaireChoice{
				label: 'A'
			}, QuestionnaireChoice{
				label:   'B'
				enabled: false
			}, QuestionnaireChoice{
				label: 'C'
			}]
		},
	]
	config := QuestionnaireConfig{
		id:    'q'
		items: items
		state: QuestionnaireState{
			items: [QuestionnaireItemState{
				name:    'tools'
				choices: ['C', 'B', 'A']
			}]
		}
	}
	answer := questionnaire_answer(config, 'tools')
	assert answer.choices == ['A', 'C']
	assert answer.count() == 2
	assert questionnaire_answer_labels(config, 'tools') == ['A', 'C']
	answers := questionnaire_answers(config)
	assert answers.chose('tools', 'A') && !answers.chose('tools', 'B')
	assert answers.answer('missing').is_empty()
	if _ := answers.entry('missing') {
		assert false
	}
}

// ── Validation ──────────────────────────────────────────────────────

fn test_questionnaire_validation_messages() {
	mut config := qn_start()
	// Nothing shows before validation is attempted.
	assert questionnaire_error(config, 'mood') == ''
	assert !questionnaire_item_valid(config, 'mood')
	update := questionnaire_next(config) or { panic('no update') }
	assert qn_kinds(update) == [.invalid]
	assert update.events[0].error == 'Choose an answer to continue.'
	config = questionnaire_with_state(config, update.state)
	assert questionnaire_current(config) == 'mood'
	assert questionnaire_error(config, 'mood') == 'Choose an answer to continue.'
	// After an attempt the error follows every change.
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'good'))
	assert questionnaire_error(config, 'mood') == ''
	// An optional item asks to be answered or skipped; a text item to be written.
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'source') or {
		panic(err)
	})
	config = qn_apply(config, questionnaire_next(config))
	assert questionnaire_error(config, 'source') == 'Choose an answer or skip this question.'
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'improve') or {
		panic(err)
	})
	config = qn_apply(config, questionnaire_submit(config))
	assert questionnaire_current(config) == 'source', 'the first invalid item becomes current'
	assert questionnaire_error(config, 'improve') == 'Write an answer to continue.'
	// The validator runs on an answer and its message is shown.
	config = questionnaire_with_state(config, questionnaire_set_input_text(config, 'improve',
		'abc') or { panic(err) })
	assert questionnaire_error(config, 'improve') == 'Write at least five characters.'
	config = questionnaire_with_state(config, questionnaire_set_input_text(config, 'improve',
		'abcdef') or { panic(err) })
	assert questionnaire_error(config, 'improve') == ''
}

fn test_questionnaire_custom_messages_and_limits() {
	items := [
		QuestionnaireItem{
			name:             'pick'
			required:         true
			required_message: 'Pick one, please.'
			choices:          qn_choices('a')
		},
		QuestionnaireItem{
			name:        'many'
			multiple:    true
			min_choices: 2
			max_choices: 3
			choices:     qn_choices('a', 'b', 'c', 'd')
		},
	]
	mut config := QuestionnaireConfig{
		id:       'q'
		items:    items
		messages: QuestionnaireMessages{
			too_few: 'Need {min} or more.'
		}
		state:    QuestionnaireState{
			items: [QuestionnaireItemState{
				name:      'pick'
				attempted: true
			}, QuestionnaireItemState{
				name:      'many'
				choices:   ['a']
				attempted: true
			}]
		}
	}
	assert questionnaire_error(config, 'pick') == 'Pick one, please.'
	assert questionnaire_error(config, 'many') == 'Need 2 or more.'
	assert questionnaire_hint(items[1], config.messages) == 'Choose 2 to 3.'
	assert questionnaire_hint(QuestionnaireItem{
		multiple:    true
		max_choices: 2
	}, config.messages) == 'Choose up to 2.'
	assert questionnaire_hint(QuestionnaireItem{
		multiple:    true
		min_choices: 2
	}, config.messages) == 'Choose at least 2.'
	assert questionnaire_hint(QuestionnaireItem{
		multiple:    true
		min_choices: 2
		max_choices: 2
	}, config.messages) == 'Choose 2.'
	assert questionnaire_hint(QuestionnaireItem{
		multiple: true
	}, config.messages) == ''
	// A state set by the application can exceed the limit; validation says so.
	config = QuestionnaireConfig{
		...config
		state: config.state.with_item(QuestionnaireItemState{
			name:      'many'
			choices:   ['a', 'b', 'c', 'd']
			attempted: true
		})
	}
	assert questionnaire_error(config, 'many') == 'Choose at most 3.'
}

fn test_questionnaire_external_errors_block_until_cleared_and_survive_reset() {
	mut config := qn_start()
	config = questionnaire_with_state(config, questionnaire_set_external_error(config, 'mood',
		'Server says no.') or { panic(err) })
	assert questionnaire_error(config, 'mood') == 'Server says no.'
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'good'))
	update := questionnaire_next(config) or { panic('no update') }
	assert qn_kinds(update) == [.invalid]
	assert update.events[0].error == 'Server says no.'
	config = questionnaire_with_state(config, questionnaire_reset(config))
	assert questionnaire_answer(config, 'mood').is_empty()
	assert questionnaire_error(config, 'mood') == 'Server says no.'
	config = questionnaire_with_state(config, questionnaire_clear_external_error(config,
		'mood') or { panic(err) })
	assert questionnaire_error(config, 'mood') == ''
	if _ := questionnaire_set_external_error(config, 'nope', 'x') {
		assert false
	}
}

fn test_questionnaire_validator_sees_every_shown_answer() {
	items := [
		QuestionnaireItem{
			name:    'size'
			choices: qn_choices('small', 'large')
		},
		QuestionnaireItem{
			name:      'count'
			input:     QuestionnaireInput{
				label: 'Count'
			}
			validator: fn (context QuestionnaireValidationContext) ! {
				if context.answers.chose('size', 'small') && context.answer.freeform.int() > 3 {
					return error('Small holds at most 3.')
				}
				assert context.item == 'count'
			}
		},
	]
	config := QuestionnaireConfig{
		id:    'q'
		items: items
		state: QuestionnaireState{
			items: [QuestionnaireItemState{
				name:    'size'
				choices: ['small']
			}, QuestionnaireItemState{
				name:      'count'
				text:      '5'
				freeform:  true
				attempted: true
			}]
		}
	}
	assert questionnaire_error(config, 'count') == 'Small holds at most 3.'
}

// ── Choosing and confirming ─────────────────────────────────────────

fn test_questionnaire_single_choice_confirms_after_a_pause() {
	mut config := qn_start()
	update := questionnaire_choose(config, 'mood', 'good') or { panic('no update') }
	assert qn_kinds(update) == [.answer_changed]
	assert update.events[0].answer.choices == ['good']
	assert update.events[0].status == .answered
	assert update.confirm_later
	assert update.state.pending == 'mood'
	config = questionnaire_with_state(config, update.state)
	assert questionnaire_current(config) == 'mood', 'the selection shows before moving on'
	moved := questionnaire_confirm_pending(config) or { panic('no confirm') }
	assert qn_kinds(moved) == [.current_item_changed]
	assert moved.events[0].previous == 'mood' && moved.events[0].item == 'source'
	assert moved.state.pending == ''
	config = questionnaire_with_state(config, moved.state)
	if _ := questionnaire_confirm_pending(config) {
		assert false, 'nothing is pending any more'
	}
	// Going back and choosing the selected answer again confirms at once.
	config = qn_apply(config, questionnaire_previous(config))
	again := questionnaire_choose(config, 'mood', 'good') or { panic('no update') }
	assert qn_kinds(again) == [.current_item_changed]
	assert !again.confirm_later
}

fn test_questionnaire_pending_confirm_is_dropped_by_later_changes() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_choose(config, 'mood', 'bad'))
	assert config.state.pending == 'mood'
	// Another change drops the pending confirm; the newer choice owns it.
	config = qn_apply(config, questionnaire_choose(config, 'mood', 'okay'))
	assert config.state.pending == 'mood'
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'source') or {
		panic(err)
	})
	assert config.state.pending == ''
	if _ := questionnaire_confirm_pending(config) {
		assert false
	}
	// A pending item that is no longer current is cleared without confirming.
	stale := questionnaire_with_state(config, QuestionnaireState{
		...config.state
		pending: 'mood'
	})
	cleared := questionnaire_confirm_pending(stale) or { panic('no update') }
	assert cleared.events.len == 0 && cleared.state.pending == ''
}

fn test_questionnaire_reduce_motion_confirms_at_once() {
	config := QuestionnaireConfig{
		...qn_start()
		reduce_motion: true
	}
	update := questionnaire_choose(config, 'mood', 'bad') or { panic('no update') }
	assert qn_kinds(update) == [.answer_changed, .current_item_changed]
	assert questionnaire_current(questionnaire_with_state(config, update.state)) == 'issues'
	assert !update.confirm_later
	// activate_choice never confirms.
	quiet := questionnaire_activate_choice(config, 'mood', 'good') or { panic('no update') }
	assert qn_kinds(quiet) == [.answer_changed]
}

fn test_questionnaire_multiple_choice_toggles_within_its_limit() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'bad'))
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'issues') or {
		panic(err)
	})
	update := questionnaire_choose(config, 'issues', 'price') or { panic('no update') }
	assert !update.confirm_later
	assert questionnaire_current(questionnaire_with_state(config, update.state)) == 'issues'
	config = questionnaire_with_state(config, update.state)
	config = qn_apply(config, questionnaire_choose(config, 'issues', 'slow'))
	assert questionnaire_answer(config, 'issues').choices == ['slow', 'price']
	// At the limit the other choices cannot be selected, but selected ones can go.
	if _ := questionnaire_choose(config, 'issues', 'crash') {
		assert false, 'selected past the limit'
	}
	config = qn_apply(config, questionnaire_choose(config, 'issues', 'slow'))
	assert questionnaire_answer(config, 'issues').choices == ['price']
	// The freeform answer counts as a selection.
	config = qn_apply(config, questionnaire_update_from_text(config, questionnaire_input_id('survey',
		'issues'), 'Sync'))
	assert questionnaire_answer(config, 'issues') == QuestionnaireAnswer{
		choices:  ['price']
		freeform: 'Sync'
	}
	if _ := questionnaire_choose(config, 'issues', 'crash') {
		assert false, 'selected past the limit with the freeform answer'
	}
	if _ := questionnaire_choose(config, 'issues', 'nope') {
		assert false, 'chose an unknown choice'
	}
	if _ := questionnaire_choose(config, 'nope', 'slow') {
		assert false, 'chose in an unknown item'
	}
}

fn test_questionnaire_freeform_answer_rules() {
	mut config := qn_start()
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'source') or {
		panic(err)
	})
	field := questionnaire_input_id('survey', 'source')
	config = qn_apply(config, questionnaire_activate_choice(config, 'source', 'search'))
	// Typing replaces a single choice with the draft.
	typed := questionnaire_update_from_text(config, field, 'Podcast') or { panic('no update') }
	assert qn_kinds(typed) == [.answer_changed]
	assert !typed.confirm_later, 'typing never confirms'
	config = questionnaire_with_state(config, typed.state)
	assert questionnaire_answer(config, 'source') == QuestionnaireAnswer{
		freeform: 'Podcast'
	}
	// Choosing a fixed answer keeps the draft out of the answer but keeps it.
	config = qn_apply(config, questionnaire_activate_choice(config, 'source', 'friend'))
	assert questionnaire_answer(config, 'source').freeform == ''
	assert config.state.item('source').text == 'Podcast'
	// The indicator brings the draft back, and focuses the field.
	other := questionnaire_update_from_action(config, questionnaire_other_action_id('survey',
		'source')) or { panic('no update') }
	assert other.focus == field
	config = questionnaire_with_state(config, other.state)
	assert questionnaire_answer(config, 'source') == QuestionnaireAnswer{
		freeform: 'Podcast'
	}
	// Pressing it again with a draft confirms, like choosing the selected answer.
	again := questionnaire_update_from_action(config, questionnaire_other_action_id('survey',
		'source')) or { panic('no update') }
	assert qn_kinds(again) == [.current_item_changed]
	// Whitespace is no answer.
	config = qn_apply(config, questionnaire_update_from_text(config, field, '   '))
	assert questionnaire_answer(config, 'source').is_empty()
	assert questionnaire_status(config, 'source') == .unanswered
	// The same text again changes nothing.
	if _ := questionnaire_update_from_text(config, field, '   ') {
		assert false
	}
	// Fields of items that are not drawn, and foreign ids, are not this one's.
	if _ := questionnaire_update_from_text(config, questionnaire_input_id('survey', 'improve'),
		'x') {
		assert false, 'typed into an item that is not shown'
	}
	if _ := questionnaire_update_from_text(config, 'other-field', 'x') {
		assert false
	}
	assert questionnaire_input_item(config, field) or { '' } == 'source'
}

fn test_questionnaire_multiple_freeform_toggles_with_its_indicator() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'bad'))
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'issues') or {
		panic(err)
	})
	action := questionnaire_other_action_id('survey', 'issues')
	on := questionnaire_update_from_action(config, action) or { panic('no update') }
	assert on.focus == questionnaire_input_id('survey', 'issues')
	config = questionnaire_with_state(config, on.state)
	assert config.state.item('issues').freeform
	assert questionnaire_answer(config, 'issues').is_empty(), 'a blank draft is no answer'
	config = qn_apply(config, questionnaire_update_from_text(config, questionnaire_input_id('survey',
		'issues'), 'Sync'))
	config = qn_apply(config, questionnaire_choose(config, 'issues', 'slow'))
	assert questionnaire_answer(config, 'issues').count() == 2
	off := questionnaire_update_from_action(config, action) or { panic('no update') }
	assert off.focus == ''
	config = questionnaire_with_state(config, off.state)
	assert questionnaire_answer(config, 'issues') == QuestionnaireAnswer{
		choices: ['slow']
	}
}

// ── Navigation ──────────────────────────────────────────────────────

fn test_questionnaire_navigation_states() {
	mut config := qn_start()
	assert questionnaire_navigation(config) == QuestionnaireNavigation{
		next: true
	}
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'good'))
	assert questionnaire_navigation(config).confirmable
	config = qn_apply(config, questionnaire_next(config))
	assert questionnaire_current(config) == 'source'
	assert questionnaire_navigation(config) == QuestionnaireNavigation{
		previous: true
		next:     true
		skip:     true
	}
	config = qn_apply(config, questionnaire_skip(config))
	assert questionnaire_current(config) == 'improve'
	assert questionnaire_status(config, 'source') == .skipped
	assert questionnaire_navigation(config) == QuestionnaireNavigation{
		previous: true
		submit:   true
	}
	// Required items cannot be skipped; the first item has no previous.
	if _ := questionnaire_skip(config) {
		assert false
	}
	config = qn_apply(config, questionnaire_previous(config))
	config = qn_apply(config, questionnaire_previous(config))
	assert questionnaire_current(config) == 'mood'
	if _ := questionnaire_previous(config) {
		assert false
	}
	// Re-entering a skipped item and answering it clears the skip.
	config = qn_apply(config, questionnaire_next(config))
	config = qn_apply(config, questionnaire_activate_choice(config, 'source', 'friend'))
	assert questionnaire_status(config, 'source') == .answered
	assert questionnaire_progress(config).answered == 2
}

fn test_questionnaire_skip_reports_and_continues() {
	mut config := qn_start()
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'source') or {
		panic(err)
	})
	config = qn_apply(config, questionnaire_activate_choice(config, 'source', 'friend'))
	update := questionnaire_skip(config) or { panic('no update') }
	assert qn_kinds(update) == [.answer_changed, .current_item_changed]
	assert update.events[0].status == .skipped
	assert update.events[0].answer.is_empty()
	// Arriving at a text item focuses its field.
	assert update.focus == questionnaire_input_id('survey', 'improve')
	// Skipping the last item submits.
	items := [
		QuestionnaireItem{
			name:     'a'
			required: true
			choices:  qn_choices('x')
		},
		QuestionnaireItem{
			name:    'b'
			choices: qn_choices('y')
		},
	]
	mut last := QuestionnaireConfig{
		id:    'q'
		items: items
		state: QuestionnaireState{
			current: 'b'
			items:   [QuestionnaireItemState{
				name:    'a'
				choices: ['x']
			}]
		}
	}
	done := questionnaire_skip(last) or { panic('no update') }
	assert qn_kinds(done) == [.answer_changed, .completed, .submit]
	submitted := done.submission() or { panic('no submission') }
	assert submitted.items.map(it.status) == [QuestionnaireItemStatus.answered, .skipped]
}

fn test_questionnaire_submit_completes_once_until_answers_change() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'good'))
	config = questionnaire_with_state(config, questionnaire_set_answer(config, 'source',
		QuestionnaireAnswer{ freeform: 'Radio' }) or { panic(err) })
	config = questionnaire_with_state(config, questionnaire_set_input_text(config, 'improve',
		'Faster sync') or { panic(err) })
	first := questionnaire_submit(config) or { panic('no update') }
	assert qn_kinds(first) == [.completed, .submit]
	answers := first.submission() or { panic('no submission') }
	assert answers.items.map(it.name) == ['mood', 'source', 'improve']
	assert answers.answer('source').freeform == 'Radio'
	assert answers.answer('improve').freeform == 'Faster sync'
	config = questionnaire_with_state(config, first.state)
	assert config.state.complete
	second := questionnaire_submit(config) or { panic('no update') }
	assert qn_kinds(second) == [.submit]
	// Changing an answer clears completion, so the next submit completes again.
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'okay'))
	assert !config.state.complete
	// ...but the follow-up it revealed must be answered first.
	stopped := questionnaire_submit(config) or { panic('no update') }
	assert qn_kinds(stopped) == [.current_item_changed, .invalid]
	assert stopped.events[1].item == 'issues'
	config = questionnaire_with_state(config, stopped.state)
	assert questionnaire_current(config) == 'issues'
	config = qn_apply(config, questionnaire_choose(config, 'issues', 'crash'))
	third := questionnaire_submit(config) or { panic('no update') }
	assert qn_kinds(third) == [.completed, .submit]
}

fn test_questionnaire_confirm_is_next_or_submit() {
	mut config := qn_start()
	update := questionnaire_confirm(config) or { panic('no update') }
	assert qn_kinds(update) == [.invalid]
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'good'))
	config = qn_apply(config, questionnaire_confirm(config))
	assert questionnaire_current(config) == 'source'
	disabled := QuestionnaireConfig{
		...config
		enabled: false
	}
	for result in [questionnaire_confirm(disabled), questionnaire_next(disabled),
		questionnaire_previous(disabled), questionnaire_skip(disabled), questionnaire_submit(disabled),
		questionnaire_choose(disabled, 'source', 'friend')] {
		if _ := result {
			assert false, 'a disabled questionnaire changed'
		}
	}
}

fn test_questionnaire_reset_returns_to_the_baseline() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'bad'))
	config = qn_apply(config, questionnaire_next(config))
	config = qn_apply(config, questionnaire_choose(config, 'issues', 'slow'))
	assert questionnaire_current(config) == 'issues'
	reset := questionnaire_reset(config)
	assert reset == questionnaire_initial_state(qn_items()) or { panic(err) }
}

fn test_questionnaire_silent_setters_check_the_schema() {
	config := qn_start()
	if _ := questionnaire_set_current(config, 'issues') {
		assert false, 'made a hidden item current'
	}
	if _ := questionnaire_set_current(config, 'nope') {
		assert false
	}
	if _ := questionnaire_set_answer(config, 'mood', QuestionnaireAnswer{
		choices: ['good', 'bad']
	}) {
		assert false, 'two answers on a single-choice item'
	}
	if _ := questionnaire_set_answer(config, 'mood', QuestionnaireAnswer{
		freeform: 'x'
	}) {
		assert false, 'freeform answer without an input'
	}
	if _ := questionnaire_set_answer(config, 'mood', QuestionnaireAnswer{
		choices: ['great']
	}) {
		assert false, 'unknown choice'
	}
	if _ := questionnaire_set_input_text(config, 'mood', 'x') {
		assert false, 'typed into an item without input'
	}
	items := [
		QuestionnaireItem{
			name:    'a'
			choices: [QuestionnaireChoice{
				label:   'x'
				enabled: false
			}]
		},
	]
	if _ := questionnaire_set_answer(QuestionnaireConfig{ items: items }, 'a', QuestionnaireAnswer{
		choices: ['x']
	}) {
		assert false, 'selected a disabled choice'
	}
}

// ── Page layout ─────────────────────────────────────────────────────

fn test_questionnaire_page_layout() {
	mut config := QuestionnaireConfig{
		...qn_start()
		layout: .page
	}
	assert questionnaire_navigation(config) == QuestionnaireNavigation{
		submit: true
	}
	// Choosing never confirms on a page; the item worked on becomes current.
	update := questionnaire_choose(config, 'source', 'friend') or { panic('no update') }
	assert qn_kinds(update) == [.answer_changed, .current_item_changed]
	assert !update.confirm_later
	config = questionnaire_with_state(config, update.state)
	assert questionnaire_current(config) == 'source'
	// Submit shows every error and moves to the first invalid item.
	stopped := questionnaire_submit(config) or { panic('no update') }
	assert qn_kinds(stopped) == [.current_item_changed, .invalid]
	config = questionnaire_with_state(config, stopped.state)
	assert questionnaire_current(config) == 'mood'
	assert questionnaire_error(config, 'mood').len > 0
	assert questionnaire_error(config, 'improve').len > 0
	config = qn_apply(config, questionnaire_choose(config, 'mood', 'good'))
	config = questionnaire_with_state(config, questionnaire_set_input_text(config, 'improve',
		'Better search') or { panic(err) })
	// Choosing the selected answer again changes nothing on a page.
	if _ := questionnaire_choose(config, 'source', 'friend') {
		assert false
	}
	config = questionnaire_with_state(config, questionnaire_set_answer(config, 'source',
		QuestionnaireAnswer{}) or { panic(err) })
	assert questionnaire_answer(config, 'source').is_empty()
	// An unanswered optional item does not hold up a page: it is skipped.
	done := questionnaire_submit(config) or { panic('no update') }
	answers := done.submission() or { panic('no submission') }
	assert (answers.entry('source') or { panic('missing') }).status == .skipped
	assert questionnaire_progress(questionnaire_with_state(config, done.state)).answered == 3
}

// ── Decoders ────────────────────────────────────────────────────────

fn test_questionnaire_action_decoder_accepts_only_drawn_parts() {
	mut config := qn_start()
	choice := questionnaire_choice_action_id('survey', 'mood', 'good')
	update := questionnaire_update_from_action(config, choice) or { panic('no update') }
	assert update.confirm_later
	// The current item's parts only: another step's choices are not drawn.
	for forged in [questionnaire_choice_action_id('survey', 'source', 'friend'),
		questionnaire_choice_action_id('survey', 'mood', 'great'),
		questionnaire_choice_action_id('other', 'mood', 'good'),
		questionnaire_command_action_id('survey', .previous),
		questionnaire_command_action_id('survey', .skip),
		questionnaire_command_action_id('survey', .submit),
		questionnaire_other_action_id('survey', 'mood'), 'survey:component:', 'survey', '',
		choice + '00', 'survey:component:choice:6d6f6f64'] {
		if _ := questionnaire_update_from_action(config, forged) {
			assert false, 'accepted ${forged}'
		}
	}
	next := questionnaire_update_from_action(config, questionnaire_command_action_id('survey',
		.next)) or { panic('no update') }
	assert qn_kinds(next) == [.invalid]
	// Without drawn actions, their actions are forged.
	hidden := QuestionnaireConfig{
		...config
		show_actions: false
	}
	if _ := questionnaire_update_from_action(hidden, questionnaire_command_action_id('survey',
		.next)) {
		assert false
	}
	// Return in a one-line field confirms a filled draft only.
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'source') or {
		panic(err)
	})
	submit := questionnaire_input_submit_id('survey', 'source')
	if _ := questionnaire_update_from_action(config, submit) {
		assert false, 'confirmed an empty draft'
	}
	config = qn_apply(config, questionnaire_update_from_text(config, questionnaire_input_id('survey',
		'source'), 'Radio'))
	moved := questionnaire_update_from_action(config, submit) or { panic('no update') }
	assert qn_kinds(moved) == [.current_item_changed]
	// Pointer activation clears the keyboard highlight.
	lit := questionnaire_with_state(config, QuestionnaireState{
		...config.state
		highlight: 'friend'
	})
	clicked := questionnaire_update_from_action(lit, questionnaire_choice_action_id('survey',
		'source', 'search')) or { panic('no update') }
	assert clicked.state.highlight == ''
}

fn test_questionnaire_action_ids_encode_any_name() {
	items := [
		QuestionnaireItem{
			name:    'a:b'
			choices: [QuestionnaireChoice{
				value: 'x:y'
				label: 'X'
			}]
		},
		QuestionnaireItem{
			name:    'a'
			choices: [QuestionnaireChoice{
				value: 'b:x:y'
				label: 'Y'
			}]
		},
	]
	config := QuestionnaireConfig{
		id:    'q'
		items: items
		state: QuestionnaireState{
			current: 'a:b'
		}
	}
	update := questionnaire_update_from_action(config, questionnaire_choice_action_id('q',
		'a:b', 'x:y')) or { panic('no update') }
	assert update.events[0].item == 'a:b'
	assert questionnaire_choice_action_id('q', 'a:b', 'x:y') != questionnaire_choice_action_id('q',
		'a', 'b:x:y')
}

fn test_questionnaire_keys() {
	mut config := qn_start()
	// A shortcut chooses and confirms like a click.
	two := questionnaire_update_from_key(config, qn_key(._2), '') or { panic('no update') }
	assert two.confirm_later
	assert two.state.highlight == 'okay'
	assert questionnaire_answer(questionnaire_with_state(config, two.state), 'mood').choices == [
		'okay',
	]
	// Shortcuts beyond the choices, modified keys and keys typed into a field are left alone.
	for event in [qn_key(._4), KeyEvent{
		code:  ._1
		shift: true
	}, KeyEvent{
		code: ._1
		cmd:  true
	}] {
		if _ := questionnaire_update_from_key(config, event, '') {
			assert false, 'handled ${event}'
		}
	}
	off := QuestionnaireConfig{
		...config
		shortcuts: .off
	}
	if _ := questionnaire_update_from_key(off, qn_key(._1), '') {
		assert false
	}
	letters := QuestionnaireConfig{
		...config
		shortcuts: .letters
	}
	c := questionnaire_update_from_key(letters, qn_key(.c), '') or { panic('no update') }
	assert questionnaire_answer(questionnaire_with_state(config, c.state), 'mood').choices == [
		'bad',
	]
	// Down starts at the first choice, and a radio selection follows it.
	down := questionnaire_update_from_key(config, qn_key(.down), '') or { panic('no update') }
	assert down.state.highlight == 'good'
	assert !down.confirm_later
	config = questionnaire_with_state(config, down.state)
	assert questionnaire_answer(config, 'mood').choices == ['good']
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.up), ''))
	assert config.state.highlight == 'bad'
	assert questionnaire_answer(config, 'mood').choices == ['bad']
	// Left and Right move a highlighted radio group too.
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.right), ''))
	assert config.state.highlight == 'good'
	// Enter on a selected highlight confirms the item.
	entered := questionnaire_update_from_key(config, qn_key(.enter), '') or { panic('no update') }
	assert qn_kinds(entered) == [.current_item_changed]
	config = questionnaire_with_state(config, entered.state)
	assert questionnaire_current(config) == 'source'
	assert config.state.highlight == ''
	// Without a highlight, Left goes back and Right goes on once answered.
	if _ := questionnaire_update_from_key(config, qn_key(.right), '') {
		assert false, 'went past an unanswered item'
	}
	back := questionnaire_update_from_key(config, qn_key(.left), '') or { panic('no update') }
	assert questionnaire_current(questionnaire_with_state(config, back.state)) == 'mood'
	// Up with nothing highlighted starts at the end, which is the input.
	up := questionnaire_update_from_key(config, qn_key(.up), '') or { panic('no update') }
	assert up.focus == questionnaire_input_id('survey', 'source')
	// Down from the last choice moves into the input.
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.down), ''))
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.down), ''))
	assert config.state.highlight == 'friend'
	into := questionnaire_update_from_key(config, qn_key(.down), '') or { panic('no update') }
	assert into.focus == questionnaire_input_id('survey', 'source')
	assert into.state.highlight == ''
	// In a field, only Enter on a filled draft does anything.
	field := questionnaire_input_id('survey', 'source')
	if _ := questionnaire_update_from_key(config, qn_key(._1), field) {
		assert false, 'a shortcut fired while typing'
	}
	if _ := questionnaire_update_from_key(config, qn_key(.enter), field) {
		assert false, 'confirmed an empty draft'
	}
	config = qn_apply(config, questionnaire_update_from_text(config, field, 'Radio'))
	typed := questionnaire_update_from_key(config, qn_key(.enter), field) or { panic('no update') }
	assert questionnaire_current(questionnaire_with_state(config, typed.state)) == 'improve'
	config = questionnaire_with_state(config, typed.state)
	// Enter in a text area is a line break, but Cmd+Enter confirms from anywhere.
	area := questionnaire_input_id('survey', 'improve')
	config = qn_apply(config, questionnaire_update_from_text(config, area, 'Faster sync'))
	if _ := questionnaire_update_from_key(config, qn_key(.enter), area) {
		assert false
	}
	submitted := questionnaire_update_from_key(config, KeyEvent{
		code: .enter
		cmd:  true
	}, area) or { panic('no update') }
	assert qn_kinds(submitted) == [.completed, .submit]
}

fn test_questionnaire_keys_on_multiple_choice() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'bad'))
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'issues') or {
		panic(err)
	})
	// The highlight moves without selecting; Space toggles.
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.down), ''))
	assert config.state.highlight == 'slow'
	assert questionnaire_answer(config, 'issues').is_empty()
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.space), ''))
	assert questionnaire_answer(config, 'issues').choices == ['slow']
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.down), ''))
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.enter), ''))
	assert questionnaire_answer(config, 'issues').choices == ['slow', 'crash']
	// At the limit, the highlight skips choices that cannot be selected.
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.down), ''))
	assert config.state.highlight == 'slow'
	if _ := questionnaire_update_from_key(config, qn_key(._3), '') {
		assert false, 'a shortcut selected past the limit'
	}
	// Enter on a selected highlight continues.
	moved := questionnaire_update_from_key(config, qn_key(.enter), '') or { panic('no update') }
	assert questionnaire_current(questionnaire_with_state(config, moved.state)) == 'source'
}

fn test_questionnaire_dialog_buttons() {
	mut config := qn_start()
	ids := fn (buttons []DialogButton) []string {
		return buttons.map(it.id)
	}
	assert ids(questionnaire_dialog_buttons(config)) == ['questionnaire:next']
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'good'))
	next := questionnaire_dialog_buttons(config)[0]
	assert next.role == .confirm
	update := questionnaire_update_from_dialog(config, DialogEvent{
		reason: .confirm
		button: next.id
	}) or { panic('no update') }
	config = questionnaire_with_state(config, update.state)
	assert questionnaire_current(config) == 'source'
	buttons := questionnaire_dialog_buttons(config)
	assert ids(buttons) == ['questionnaire:previous', 'questionnaire:skip', 'questionnaire:next']
	assert buttons[0].role == .action && buttons[1].role == .action
	for event in [DialogEvent{
		reason: .cancel
		button: 'questionnaire:previous'
	}, DialogEvent{
		reason: .action
		button: 'questionnaire:submit'
	}, DialogEvent{
		reason: .action
		button: 'save'
	}, DialogEvent{
		reason: .escape
	}] {
		if _ := questionnaire_update_from_dialog(config, event) {
			assert false, 'accepted ${event}'
		}
	}
	back := questionnaire_update_from_dialog(config, DialogEvent{
		reason: .action
		button: 'questionnaire:previous'
	}) or { panic('no update') }
	assert questionnaire_current(questionnaire_with_state(config, back.state)) == 'mood'
}

// ── Drawing ─────────────────────────────────────────────────────────

fn test_questionnaire_draws_the_current_step() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'bad'))
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'issues') or {
		panic(err)
	})
	config = qn_apply(config, questionnaire_choose(config, 'issues', 'slow'))
	config = qn_apply(config, questionnaire_choose(config, 'issues', 'crash'))
	el := questionnaire(config) or { panic(err) }
	assert el.accessibility_role == 'form'
	assert el.accessibility_value == 'Question 2 of 4'
	qn_assert_inside(el)
	texts := qn_texts(el)
	assert 'Question 2 of 4' in texts
	assert 'What went wrong?' in texts
	assert 'Choose up to 2.' in texts
	assert 'How was it?' !in texts, 'only the current step is drawn'
	// Each choice is a card whose action decodes, with a shortcut hint.
	cards := qn_collect(el, fn (e Element) bool {
		return e.button_behavior && e.accessibility_role == 'checkbox'
	})
	assert cards.len == 4, 'three choices and the freeform indicator'
	slow := qn_find(el, questionnaire_choice_action_id('survey', 'issues', 'slow')) or {
		panic('no card')
	}
	assert slow.accessibility_value == 'checked'
	assert slow.enabled
	assert '1' in qn_texts(slow)
	// At the limit, the unselected choice and the freeform answer are disabled.
	price := qn_find(el, questionnaire_choice_action_id('survey', 'issues', 'price')) or {
		panic('no card')
	}
	assert !price.enabled && price.accessibility_value == 'unchecked'
	other := qn_find(el, questionnaire_other_action_id('survey', 'issues')) or {
		panic('no indicator')
	}
	assert !other.enabled
	field := qn_find(el, questionnaire_input_id('survey', 'issues')) or { panic('no field') }
	assert field.kind == .text_field && !field.enabled
	assert field.submit_id == questionnaire_input_submit_id('survey', 'issues')
	assert field.accessibility_label == 'Something else'
	// The actions: Previous, then Next; this item is required, so no Skip.
	previous := qn_find(el, questionnaire_command_action_id('survey', .previous)) or {
		panic('no previous')
	}
	next := qn_find(el, questionnaire_command_action_id('survey', .next)) or { panic('no next') }
	assert previous.frame.x == 0
	assert next.frame.x + next.frame.width == config.frame.width
	assert next.frame.y + next.frame.height == config.frame.height
	if _ := qn_find(el, questionnaire_command_action_id('survey', .skip)) {
		assert false
	}
	if _ := qn_find(el, questionnaire_command_action_id('survey', .submit)) {
		assert false
	}
	assert (qn_find(el, component_part_id('survey', 'progress')) or { panic('no bar') }).accessibility_value == '50%'
}

fn test_questionnaire_draws_errors_and_text_items() {
	mut config := qn_start()
	config = questionnaire_with_state(config, questionnaire_set_current(config, 'improve') or {
		panic(err)
	})
	config = qn_apply(config, questionnaire_update_from_text(config, questionnaire_input_id('survey',
		'improve'), 'abc'))
	config = qn_apply(config, questionnaire_next(config))
	el := questionnaire(config) or { panic(err) }
	qn_assert_inside(el)
	alerts := qn_collect(el, fn (e Element) bool {
		return e.accessibility_role == 'alert'
	})
	assert alerts.len == 1
	assert alerts[0].accessibility_label == 'Write at least five characters.'
	area := qn_find(el, questionnaire_input_id('survey', 'improve')) or { panic('no area') }
	assert area.kind == .text_area
	assert area.text == 'abc'
	assert area.accessibility_label == 'Improvement'
	// The last step submits; an optional one could also be skipped.
	assert qn_find(el, questionnaire_command_action_id('survey', .submit)) != none
	if _ := qn_find(el, questionnaire_command_action_id('survey', .next)) {
		assert false
	}
}

fn test_questionnaire_keyboard_highlight_and_shortcut_hints() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_update_from_key(config, qn_key(.down), ''))
	el := questionnaire(config) or { panic(err) }
	good := qn_find(el, questionnaire_choice_action_id('survey', 'mood', 'good')) or {
		panic('no card')
	}
	okay := qn_find(el, questionnaire_choice_action_id('survey', 'mood', 'okay')) or {
		panic('no card')
	}
	// The highlighted card's border is the primary color, two units thick.
	assert good.children[0].box.bg == config.theme.primary
	assert good.children[1].frame.x == 2
	assert okay.children[1].frame.x == 1
	plain := questionnaire(QuestionnaireConfig{
		...config
		shortcuts: .off
	}) or { panic(err) }
	card := qn_find(plain, questionnaire_choice_action_id('survey', 'mood', 'good')) or {
		panic('no card')
	}
	assert '1' !in qn_texts(card)
}

fn test_questionnaire_scrolls_an_item_taller_than_its_room() {
	config := QuestionnaireConfig{
		...qn_start()
		frame: rect(0, 0, 360, 200)
	}
	el := questionnaire(config) or { panic(err) }
	scrolls := qn_collect(el, fn (e Element) bool {
		return e.kind == .scroll
	})
	assert scrolls.len == 1
	assert scrolls[0].box.transparent
	natural := questionnaire_natural_height(config)
	assert natural > 200
	roomy := questionnaire(QuestionnaireConfig{
		...config
		frame: rect(0, 0, 360, natural)
	}) or { panic(err) }
	assert qn_collect(roomy, fn (e Element) bool {
		return e.kind == .scroll
	}).len == 0
	qn_assert_inside(roomy)
}

fn test_questionnaire_natural_height_suits_every_step() {
	mut config := qn_start()
	config = qn_apply(config, questionnaire_activate_choice(config, 'mood', 'bad'))
	config = QuestionnaireConfig{
		...config
		frame: rect(0, 0, 420, 0)
	}
	height := questionnaire_natural_height(config)
	config = QuestionnaireConfig{
		...config
		frame: rect(0, 0, 420, height)
	}
	for name in questionnaire_active_items(config) {
		step := questionnaire_with_state(config, questionnaire_set_current(config, name) or {
			panic(err)
		})
		failed := qn_apply(step, questionnaire_next(step))
		for shown in [step, failed] {
			el := questionnaire(shown) or { panic(err) }
			assert qn_collect(el, fn (e Element) bool {
				return e.kind == .scroll
			}).len == 0, '${name} scrolls'
			qn_assert_inside(el)
		}
	}
	// Each size grows the geometry.
	small := questionnaire_natural_height(QuestionnaireConfig{
		...config
		size: .small
	})
	large := questionnaire_natural_height(QuestionnaireConfig{
		...config
		size: .large
	})
	assert small < height && height < large
}

fn test_questionnaire_draws_a_page() {
	mut config := QuestionnaireConfig{
		...qn_start()
		layout: .page
		frame:  rect(0, 0, 480, 2000)
	}
	el := questionnaire(config) or { panic(err) }
	qn_assert_inside(el)
	texts := qn_texts(el)
	assert '0 of 3 answered' in texts
	for title in ['How was it?', 'Where did you hear of us?', 'What should we improve?'] {
		assert title in texts
	}
	assert 'What went wrong?' !in texts
	assert qn_find(el, questionnaire_command_action_id('survey', .submit)) != none
	if _ := qn_find(el, questionnaire_command_action_id('survey', .next)) {
		assert false
	}
	// Every shown item's choices answer on a page.
	update := questionnaire_update_from_action(config, questionnaire_choice_action_id('survey',
		'source', 'friend')) or { panic('no update') }
	config = questionnaire_with_state(config, update.state)
	assert questionnaire_current(config) == 'source'
	assert questionnaire_natural_height(config) < 2000
	// The application can scroll an item of a page into view.
	assert questionnaire_scroll_id(config) == 'survey:component:body'
	first := questionnaire_item_rect(config, 'mood') or { panic('no rect') }
	second := questionnaire_item_rect(config, 'source') or { panic('no rect') }
	assert first.y == 0 && second.y > first.y + first.height
	drawn := qn_find(questionnaire(config) or { panic(err) }, component_part_id('survey',
		'item:${questionnaire_hex('source')}')) or { panic('no item') }
	assert drawn.frame == second
	if _ := questionnaire_item_rect(config, 'issues') {
		assert false, 'a hidden item has no place'
	}
	// A step has one item, at the top of its own scroll.
	steps := QuestionnaireConfig{
		...config
		layout: .stepped
	}
	assert questionnaire_scroll_id(steps) == 'survey:component:body:${questionnaire_hex('source')}'
	assert (questionnaire_item_rect(steps, 'source') or { panic('no rect') }).y == 0
	if _ := questionnaire_item_rect(steps, 'mood') {
		assert false, 'another step is not drawn'
	}
}

fn test_questionnaire_dark_theme_and_disabled_drawing() {
	config := QuestionnaireConfig{
		...qn_start()
		theme:   component_theme(true)
		enabled: false
	}
	el := questionnaire(config) or { panic(err) }
	buttons := qn_collect(el, fn (e Element) bool {
		return e.button_behavior
	})
	assert buttons.len > 0
	assert buttons.all(!it.enabled)
	if _ := questionnaire_update_from_action(config, questionnaire_choice_action_id('survey',
		'mood', 'good')) {
		assert false
	}
	if _ := questionnaire(QuestionnaireConfig{
		...config
		id: ''
	}) {
		assert false, 'built without an id'
	}
}

fn test_questionnaire_empty_and_fully_hidden() {
	items := [
		QuestionnaireItem{
			name:    'a'
			enabled: false
			choices: qn_choices('x')
		},
	]
	config := QuestionnaireConfig{
		id:    'q'
		frame: rect(0, 0, 300, 200)
		items: items
	}
	assert questionnaire_current(config) == ''
	assert questionnaire_progress(config) == QuestionnaireProgress{}
	assert questionnaire_navigation(config) == QuestionnaireNavigation{}
	el := questionnaire(config) or { panic(err) }
	assert qn_texts(el).len == 0
	if _ := questionnaire_submit(config) {
		assert false
	}
	if _ := questionnaire_update_from_key(config, qn_key(.enter), '') {
		assert false
	}
}
