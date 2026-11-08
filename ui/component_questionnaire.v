// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/base/src/questionnaire/state.rs and types.rs.
// The schema checks, effective answers and statuses, the validation order,
// skipping, completion and submit events, the navigation visibility rules and
// the choose/confirm behavior are ported to V as pure functions over a
// controlled state; conditional items, selection limits, the page layout and
// the update/decoder model are new UI2 implementations. See third_party/gpui-kit.
module ui2

// Questionnaire, after GPUI Kit's component of that name: an ordered set of
// questions answered one step at a time (or all on one page), with single and
// multiple choice, an "other" freeform answer, free-text questions, required
// and custom validation, skipping, conditional questions, progress, keyboard
// shortcuts and submission.
//
// This file is the model: the schema, the state the application stores, the
// effective answers, conditional visibility, validation, navigation and the
// commands that turn what a person did into a new state. The action and key
// decoders live in component_questionnaire_input.v and the drawing in
// component_questionnaire_view.v.
//
// Nothing here keeps state of its own. The application builds one
// QuestionnaireConfig from its model on every build, hands the same config to
// the decoders, stores the QuestionnaireUpdate.state they return and reads the
// update's events, which play the part of upstream's QuestionnaireEvent
// subscription.

// questionnaire_confirm_delay is how long a newly chosen single answer stays on
// screen, selected, before its item confirms: long enough to register the
// choice, short enough not to read as a wait. A QuestionnaireUpdate with
// confirm_later set asks the application to call questionnaire_confirm_pending
// once it has passed, typically with ui2.after.
pub const questionnaire_confirm_delay = 0.15

// ── Schema ──────────────────────────────────────────────────────────

// QuestionnaireChoice is one fixed answer of an item.
pub struct QuestionnaireChoice {
pub:
	value       string // Stable key reported in answers; defaults to label.
	label       string
	description string // Muted secondary text under the label.
	enabled     bool = true
	selected    bool // Selected in the initial state, the baseline reset returns to.
}

// QuestionnaireInput is an item's freeform answer: an "other" answer beside
// the item's choices, or the whole answer of an item without choices.
pub struct QuestionnaireInput {
pub:
	label       string // Accessible name. Required: a placeholder is not a label.
	placeholder string
	multiline   bool // A text area instead of a one-line field.
	lines       int = 3 // Visible lines of a multiline input.
	text        string // The draft in the initial state.
	enabled     bool = true
}

// QuestionnaireValidationContext is what a validator sees. Validators cannot
// change the questionnaire.
pub struct QuestionnaireValidationContext {
pub:
	item    string
	answer  QuestionnaireAnswer
	answers QuestionnaireAnswers // Every shown item, in schema order.
}

// QuestionnaireValidator checks an answered item; return an error whose
// message is shown under the item to reject the answer.
pub type QuestionnaireValidator = fn (context QuestionnaireValidationContext) !

// QuestionnaireCondition decides whether a conditional item is shown, from the
// answers to the shown items before it. It must be a pure function of them.
pub type QuestionnaireCondition = fn (answers QuestionnaireAnswers) bool

// QuestionnaireItem is one question.
pub struct QuestionnaireItem {
pub:
	name        string // Stable key, unique in the questionnaire.
	title       string // The question, drawn as the item's title and used as its accessible name.
	description string
	required    bool
	multiple    bool // Checkboxes: every selected choice is kept, and Next continues.
	min_choices int  // multiple: the fewest selections a valid answer has; the freeform answer counts as one.
	max_choices int  // multiple: the most selections, 0 for no limit. The other choices disable once reached.
	enabled     bool = true // false takes the item out of the flow, as upstream's set_item_disabled.
	choices     []QuestionnaireChoice
	input       ?QuestionnaireInput // A freeform answer: "other" beside choices, or the whole answer.
	validator   ?QuestionnaireValidator
	// visible_if makes the item conditional: it is shown only while the
	// condition holds for the answers to the shown items before it. A hidden
	// item leaves progress, navigation, validation, shortcuts and submission.
	visible_if ?QuestionnaireCondition
	// required_message replaces the built-in message for a required item
	// that has no answer.
	required_message string
}

// questionnaire_choice_key is a choice's stable value: its value, or its label
// when it has none.
fn questionnaire_choice_key(choice QuestionnaireChoice) string {
	return choice_value(choice.value, choice.label)
}

// questionnaire_validate checks a schema: unique non-empty item names and
// choice values, at most one default on a single-choice item, sensible
// selection limits, an accessible label on every input, and an answer of some
// kind on every item. The builders and setters call it.
pub fn questionnaire_validate(items []QuestionnaireItem) ! {
	mut names := map[string]bool{}
	for item in items {
		if item.name.trim_space().len == 0 {
			return error('questionnaire item names must be non-empty')
		}
		if item.name in names {
			return error('duplicate questionnaire item `${item.name}`')
		}
		names[item.name] = true
		mut values := map[string]bool{}
		mut defaults := 0
		for choice in item.choices {
			value := questionnaire_choice_key(choice)
			if value.trim_space().len == 0 {
				return error('choice values must be non-empty in item `${item.name}`')
			}
			if value in values {
				return error('duplicate choice `${value}` in item `${item.name}`')
			}
			values[value] = true
			if choice.selected {
				defaults++
			}
		}
		if !item.multiple && defaults > 1 {
			return error('single-choice item `${item.name}` has more than one default answer')
		}
		if item.min_choices < 0 || item.max_choices < 0 {
			return error('selection limits of item `${item.name}` must not be negative')
		}
		if !item.multiple && (item.min_choices > 0 || item.max_choices > 0) {
			return error('selection limits apply to multiple-choice items, not `${item.name}`')
		}
		if item.max_choices > 0 && item.min_choices > item.max_choices {
			return error('item `${item.name}` needs more selections than it allows')
		}
		if item.max_choices > 0 && defaults > item.max_choices {
			return error('item `${item.name}` selects more defaults than it allows')
		}
		if input := item.input {
			if input.label.trim_space().len == 0 {
				return error('the input of item `${item.name}` needs an accessible label')
			}
			if input.multiline && input.lines < 1 {
				return error('the input of item `${item.name}` needs at least one line')
			}
		} else if item.choices.len == 0 {
			return error('item `${item.name}` has neither choices nor an input')
		}
	}
}

// ── Answers ─────────────────────────────────────────────────────────

// QuestionnaireAnswer is an item's effective answer. Input drafts that are not
// part of the answer are left out.
pub struct QuestionnaireAnswer {
pub:
	choices  []string // Selected choice values, in schema order.
	freeform string   // The freeform text when it is part of the answer; '' otherwise.
}

pub fn (answer QuestionnaireAnswer) is_empty() bool {
	return answer.choices.len == 0 && answer.freeform.len == 0
}

// has reports whether the choice with this value is selected.
pub fn (answer QuestionnaireAnswer) has(value string) bool {
	return value in answer.choices
}

// count is the number of selections, the freeform text counting as one.
pub fn (answer QuestionnaireAnswer) count() int {
	return answer.choices.len + if answer.freeform.len > 0 { 1 } else { 0 }
}

pub enum QuestionnaireItemStatus {
	unanswered
	answered
	skipped
}

// QuestionnaireEntry is one shown item's name, status and answer.
pub struct QuestionnaireEntry {
pub:
	name   string
	status QuestionnaireItemStatus
	answer QuestionnaireAnswer
}

// QuestionnaireAnswers holds the shown items in schema order. It is what
// conditions and validators read, and what a successful submit hands over.
pub struct QuestionnaireAnswers {
pub:
	items []QuestionnaireEntry
}

pub fn (answers QuestionnaireAnswers) entry(name string) ?QuestionnaireEntry {
	for entry in answers.items {
		if entry.name == name {
			return entry
		}
	}
	return none
}

// answer is the named item's answer, empty when the item is not shown.
pub fn (answers QuestionnaireAnswers) answer(name string) QuestionnaireAnswer {
	entry := answers.entry(name) or { return QuestionnaireAnswer{} }
	return entry.answer
}

// chose reports whether the named item's answer includes the choice value.
pub fn (answers QuestionnaireAnswers) chose(name string, value string) bool {
	return answers.answer(name).has(value)
}

// questionnaire_when_chosen is a condition for visible_if: the item shows
// while the named earlier item's answer includes any of values.
pub fn questionnaire_when_chosen(item string, values []string) QuestionnaireCondition {
	wanted := values.clone()
	return fn [item, wanted] (answers QuestionnaireAnswers) bool {
		answer := answers.answer(item)
		for value in wanted {
			if answer.has(value) {
				return true
			}
		}
		return false
	}
}

// questionnaire_when_answered is a condition for visible_if: the item shows
// while the named earlier item has an answer.
pub fn questionnaire_when_answered(item string) QuestionnaireCondition {
	return fn [item] (answers QuestionnaireAnswers) bool {
		return !answers.answer(item).is_empty()
	}
}

// ── State ───────────────────────────────────────────────────────────

// QuestionnaireItemState is what the application stores for one item.
pub struct QuestionnaireItemState {
pub:
	name     string
	choices  []string // Selected choice values.
	text     string   // The freeform draft, kept while a fixed choice is selected.
	freeform bool     // The draft is part of the answer (when it is not blank).
	skipped  bool
	// attempted is set once validation has run on the item: from then on its
	// error shows and follows every change.
	attempted bool
	// external_error is the owner's: a server's verdict, say. It shows and
	// blocks Next and Submit until the owner clears it, and survives reset.
	external_error string
}

// QuestionnaireState is the whole questionnaire's state. Start from
// questionnaire_initial_state, which applies the schema's defaults; the zero
// value is a questionnaire with nothing answered.
pub struct QuestionnaireState {
pub:
	current   string // The item shown; '' starts at the first shown item.
	items     []QuestionnaireItemState
	complete  bool   // Submitted successfully, and nothing has changed since.
	pending   string // The item whose chosen answer waits for questionnaire_confirm_pending.
	highlight string // The choice the arrow keys have reached in the current item.
}

// item returns the named item's state, empty when the state has none yet.
pub fn (qs QuestionnaireState) item(name string) QuestionnaireItemState {
	for entry in qs.items {
		if entry.name == name {
			return entry
		}
	}
	return QuestionnaireItemState{
		name: name
	}
}

fn (qs QuestionnaireState) with_item(next QuestionnaireItemState) QuestionnaireState {
	mut entries := []QuestionnaireItemState{cap: qs.items.len + 1}
	mut found := false
	for entry in qs.items {
		if entry.name == next.name {
			entries << next
			found = true
		} else {
			entries << entry
		}
	}
	if !found {
		entries << next
	}
	return QuestionnaireState{
		...qs
		items: entries
	}
}

// questionnaire_initial_state validates the schema and returns the state it
// starts in: default choices selected, input drafts filled in, and the first
// shown item current. A non-blank default draft is the answer of a
// single-choice item, as upstream.
pub fn questionnaire_initial_state(items []QuestionnaireItem) !QuestionnaireState {
	questionnaire_validate(items)!
	mut entries := []QuestionnaireItemState{cap: items.len}
	for item in items {
		mut chosen := []string{}
		for choice in item.choices {
			if choice.selected && choice.enabled {
				chosen << questionnaire_choice_key(choice)
			}
		}
		mut draft := ''
		mut freeform := false
		if input := item.input {
			draft = input.text
			if input.enabled && draft.trim_space().len > 0 {
				freeform = true
				if !item.multiple {
					chosen = []string{}
				}
			}
		}
		entries << QuestionnaireItemState{
			name:     item.name
			choices:  chosen
			text:     draft
			freeform: freeform
		}
	}
	base := QuestionnaireState{
		items: entries
	}
	resolved := questionnaire_resolve(items, base)
	return QuestionnaireState{
		...base
		current: if resolved.current >= 0 { items[resolved.current].name } else { '' }
	}
}

// ── Configuration, events and updates ───────────────────────────────

pub enum QuestionnaireLayout {
	stepped // one question at a time, as upstream
	page    // every shown question on one page above a single Submit
}

pub enum QuestionnaireShortcuts {
	off
	numbers // 1 to 9, in enabled-choice order
	letters // A to Z, in enabled-choice order
}

// QuestionnaireMessages holds every string the questionnaire draws, so an
// application can translate them. `{current}`, `{total}`, `{answered}`,
// `{min}` and `{max}` are filled in.
pub struct QuestionnaireMessages {
pub:
	progress        string = 'Question {current} of {total}'
	page_progress   string = '{answered} of {total} answered'
	previous        string = 'Previous'
	next            string = 'Next'
	skip            string = 'Skip'
	submit          string = 'Submit'
	required        string = 'Choose an answer to continue.'
	unanswered      string = 'Choose an answer or skip this question.'
	required_text   string = 'Write an answer to continue.'
	unanswered_text string = 'Write an answer or skip this question.'
	too_few         string = 'Choose at least {min}.'
	too_many        string = 'Choose at most {max}.'
	hint_up_to      string = 'Choose up to {max}.'
	hint_at_least   string = 'Choose at least {min}.'
	hint_between    string = 'Choose {min} to {max}.'
	hint_exactly    string = 'Choose {max}.'
}

pub struct QuestionnaireConfig {
pub:
	id     string
	frame  Rect
	items  []QuestionnaireItem
	state  QuestionnaireState
	layout QuestionnaireLayout = .stepped
	// shortcuts labels the current item's enabled choices with keys that
	// questionnaire_update_from_key answers to.
	shortcuts     QuestionnaireShortcuts
	show_progress bool = true // the "Question 2 of 4" line
	progress_bar  bool = true // a progress bar under that line
	// show_actions draws Previous, Skip, Next and Submit. Turn it off when a
	// dialog's footer carries them: see questionnaire_dialog_buttons.
	show_actions bool = true
	enabled      bool = true
	// reduce_motion confirms a chosen single answer at once instead of
	// after questionnaire_confirm_delay, and stops the progress bar animating.
	reduce_motion       bool
	messages            QuestionnaireMessages
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub enum QuestionnaireEventKind {
	current_item_changed
	answer_changed
	invalid   // Next or Submit stopped at an item that fails validation
	completed // the first successful submit since the answers last changed
	submit    // every successful submit, after completed
}

// QuestionnaireEvent reports what a command did, in the order it happened.
pub struct QuestionnaireEvent {
pub:
	kind     QuestionnaireEventKind
	item     string                  // The item concerned; for current_item_changed, the new current item.
	previous string                  // current_item_changed: the item left, '' when there was none.
	answer   QuestionnaireAnswer     // answer_changed: the new effective answer.
	status   QuestionnaireItemStatus // answer_changed: the new status.
	error    string                  // invalid: the message shown.
	answers  QuestionnaireAnswers    // completed and submit: the validated submission.
}

// QuestionnaireUpdate is what a command returns: the state to store, the
// events it raised, and work for the application once it has rebuilt.
pub struct QuestionnaireUpdate {
pub:
	state  QuestionnaireState
	events []QuestionnaireEvent
	// focus is an element id to pass to ui2.focus after rebuilding, such as
	// the freeform input of the item now shown; '' leaves focus alone.
	focus string
	// confirm_later asks for questionnaire_confirm_pending to be called after
	// questionnaire_confirm_delay, so a chosen answer shows before it confirms.
	confirm_later bool
}

// submission returns the answers of a successful submit among the events.
pub fn (update QuestionnaireUpdate) submission() ?QuestionnaireAnswers {
	for event in update.events {
		if event.kind == .submit {
			return event.answers
		}
	}
	return none
}

// ── Resolution ──────────────────────────────────────────────────────

// QuestionnaireResolved is everything that follows from the schema and the
// state: which items are shown, their effective answers and the current item.
struct QuestionnaireResolved {
	active  []bool
	answers []QuestionnaireAnswer // effective, per item; empty for hidden items
	entries QuestionnaireAnswers  // the shown items
	order   []int                 // indices of the shown items
	current int                   // index of the current item, -1 when none is shown
}

// questionnaire_resolve walks the items in order. An item is shown when it is
// enabled and its condition holds for the answers of the shown items before
// it, so a chain of conditional items follows from the first.
fn questionnaire_resolve(items []QuestionnaireItem, qs QuestionnaireState) QuestionnaireResolved {
	mut active := []bool{len: items.len}
	mut answers := []QuestionnaireAnswer{len: items.len}
	mut entries := []QuestionnaireEntry{}
	mut order := []int{}
	for index, item in items {
		mut shown := item.enabled
		if shown {
			if condition := item.visible_if {
				shown = condition(QuestionnaireAnswers{
					items: entries.clone()
				})
			}
		}
		if !shown {
			continue
		}
		item_state := qs.item(item.name)
		answer := questionnaire_effective(item, item_state)
		active[index] = true
		answers[index] = answer
		order << index
		entries << QuestionnaireEntry{
			name:   item.name
			status: questionnaire_status_of(item_state, answer)
			answer: answer
		}
	}
	return QuestionnaireResolved{
		active:  active
		answers: answers
		entries: QuestionnaireAnswers{
			items: entries
		}
		order:   order
		current: questionnaire_resolve_current(items, qs.current, active)
	}
}

// questionnaire_resolve_current finds the current item: the named one while it
// is shown, else the next shown item after it, else the one before it. With no
// name it is the first shown item.
fn questionnaire_resolve_current(items []QuestionnaireItem, current string, active []bool) int {
	named := questionnaire_index(items, current)
	if named >= 0 {
		if active[named] {
			return named
		}
		for index in named + 1 .. items.len {
			if active[index] {
				return index
			}
		}
		for index := named - 1; index >= 0; index-- {
			if active[index] {
				return index
			}
		}
		return -1
	}
	for index, shown in active {
		if shown {
			return index
		}
	}
	return -1
}

fn questionnaire_index(items []QuestionnaireItem, name string) int {
	if name.len == 0 {
		return -1
	}
	for index, item in items {
		if item.name == name {
			return index
		}
	}
	return -1
}

fn questionnaire_choice_index(item QuestionnaireItem, value string) int {
	for index, choice in item.choices {
		if questionnaire_choice_key(choice) == value {
			return index
		}
	}
	return -1
}

// questionnaire_effective is the answer an item's state amounts to: its
// enabled selected choices in schema order, and the draft when the draft is
// part of the answer and not blank. A single-choice item keeps one source.
fn questionnaire_effective(item QuestionnaireItem, item_state QuestionnaireItemState) QuestionnaireAnswer {
	mut chosen := []string{}
	for choice in item.choices {
		value := questionnaire_choice_key(choice)
		if choice.enabled && value in item_state.choices {
			chosen << value
			if !item.multiple {
				break
			}
		}
	}
	mut freeform := ''
	if input := item.input {
		if input.enabled && item_state.freeform && item_state.text.trim_space().len > 0
			&& (item.multiple || chosen.len == 0) {
			freeform = item_state.text
		}
	}
	return QuestionnaireAnswer{
		choices:  chosen
		freeform: freeform
	}
}

fn questionnaire_status_of(item_state QuestionnaireItemState, answer QuestionnaireAnswer) QuestionnaireItemStatus {
	if item_state.skipped {
		return .skipped
	}
	return if answer.is_empty() { .unanswered } else { .answered }
}

// questionnaire_at_limit reports whether a multiple-choice answer has as many
// selections as the item allows, so nothing more can be selected.
fn questionnaire_at_limit(item QuestionnaireItem, answer QuestionnaireAnswer) bool {
	return item.multiple && item.max_choices > 0 && answer.count() >= item.max_choices
}

// questionnaire_choice_open reports whether a choice can be activated: it is
// enabled and, on a multiple-choice item at its limit, already selected.
fn questionnaire_choice_open(item QuestionnaireItem, choice QuestionnaireChoice, answer QuestionnaireAnswer) bool {
	if !choice.enabled {
		return false
	}
	return answer.has(questionnaire_choice_key(choice)) || !questionnaire_at_limit(item, answer)
}

// questionnaire_other_open reports whether an item's freeform answer can be
// selected and typed into: its input is enabled and, on a multiple-choice item
// at its limit, the draft is already part of the answer.
fn questionnaire_other_open(item QuestionnaireItem, item_state QuestionnaireItemState, answer QuestionnaireAnswer) bool {
	if !questionnaire_input_enabled(item) {
		return false
	}
	return !item.multiple || item_state.freeform || !questionnaire_at_limit(item, answer)
}

fn questionnaire_input_enabled(item QuestionnaireItem) bool {
	if input := item.input {
		return input.enabled
	}
	return false
}

fn questionnaire_input_multiline(item QuestionnaireItem) bool {
	if input := item.input {
		return input.multiline
	}
	return false
}

// ── Readers ─────────────────────────────────────────────────────────

// questionnaire_active_items names the shown items in order: enabled, and
// with their condition met.
pub fn questionnaire_active_items(config QuestionnaireConfig) []string {
	resolved := questionnaire_resolve(config.items, config.state)
	return resolved.order.map(config.items[it].name)
}

// questionnaire_item_visible reports whether the named item is shown.
pub fn questionnaire_item_visible(config QuestionnaireConfig, name string) bool {
	index := questionnaire_index(config.items, name)
	return index >= 0 && questionnaire_resolve(config.items, config.state).active[index]
}

// questionnaire_current names the current item, '' when no item is shown.
pub fn questionnaire_current(config QuestionnaireConfig) string {
	resolved := questionnaire_resolve(config.items, config.state)
	return if resolved.current >= 0 { config.items[resolved.current].name } else { '' }
}

// questionnaire_answer is the named item's effective answer, empty for an
// unknown or hidden item.
pub fn questionnaire_answer(config QuestionnaireConfig, name string) QuestionnaireAnswer {
	index := questionnaire_index(config.items, name)
	if index < 0 {
		return QuestionnaireAnswer{}
	}
	return questionnaire_resolve(config.items, config.state).answers[index]
}

// questionnaire_answers holds every shown item's answer and status, in order.
pub fn questionnaire_answers(config QuestionnaireConfig) QuestionnaireAnswers {
	return questionnaire_resolve(config.items, config.state).entries
}

pub fn questionnaire_status(config QuestionnaireConfig, name string) QuestionnaireItemStatus {
	entry := questionnaire_answers(config).entry(name) or { return .unanswered }
	return entry.status
}

// questionnaire_answer_labels describes an answer for a summary: the labels of
// the selected choices, then the freeform text.
pub fn questionnaire_answer_labels(config QuestionnaireConfig, name string) []string {
	index := questionnaire_index(config.items, name)
	if index < 0 {
		return []string{}
	}
	item := config.items[index]
	answer := questionnaire_answer(config, name)
	mut labels := []string{}
	for choice in item.choices {
		if answer.has(questionnaire_choice_key(choice)) {
			labels << choice.label
		}
	}
	if answer.freeform.len > 0 {
		labels << answer.freeform
	}
	return labels
}

fn questionnaire_fill(template string, key string, value int) string {
	return template.replace('{${key}}', value.str())
}

// questionnaire_hint is the line under a multiple-choice item's description
// that states its selection limits, '' when it has none.
fn questionnaire_hint(item QuestionnaireItem, messages QuestionnaireMessages) string {
	if !item.multiple || (item.min_choices <= 1 && item.max_choices == 0) {
		return ''
	}
	if item.max_choices > 0 && item.min_choices == item.max_choices {
		return questionnaire_fill(messages.hint_exactly, 'max', item.max_choices)
	}
	if item.max_choices > 0 && item.min_choices > 1 {
		return questionnaire_fill(questionnaire_fill(messages.hint_between, 'min', item.min_choices),
			'max', item.max_choices)
	}
	if item.max_choices > 0 {
		return questionnaire_fill(messages.hint_up_to, 'max', item.max_choices)
	}
	return questionnaire_fill(messages.hint_at_least, 'min', item.min_choices)
}

// questionnaire_problem is why a shown item fails validation now, '' when it
// passes, whether or not validation has been attempted. A skipped optional
// item passes; an external error comes first; then an empty answer, the
// selection limits and the item's validator. On a page, an unanswered optional
// item passes: Submit records it as skipped.
fn questionnaire_problem(config QuestionnaireConfig, index int, resolved QuestionnaireResolved) string {
	if index < 0 || !resolved.active[index] {
		return ''
	}
	item := config.items[index]
	item_state := config.state.item(item.name)
	if item_state.skipped && !item.required {
		return ''
	}
	if item_state.external_error.len > 0 {
		return item_state.external_error
	}
	answer := resolved.answers[index]
	messages := config.messages
	if answer.is_empty() {
		text_only := item.choices.len == 0
		if item.required {
			if item.required_message.len > 0 {
				return item.required_message
			}
			return if text_only { messages.required_text } else { messages.required }
		}
		if config.layout == .page {
			return ''
		}
		return if text_only { messages.unanswered_text } else { messages.unanswered }
	}
	if item.multiple {
		count := answer.count()
		if item.min_choices > 0 && count < item.min_choices {
			return questionnaire_fill(messages.too_few, 'min', item.min_choices)
		}
		if item.max_choices > 0 && count > item.max_choices {
			return questionnaire_fill(messages.too_many, 'max', item.max_choices)
		}
	}
	if validator := item.validator {
		validator(QuestionnaireValidationContext{
			item:    item.name
			answer:  answer
			answers: resolved.entries
		}) or { return err.msg() }
	}
	return ''
}

// questionnaire_shown_error is the message drawn under an item: an external
// error at any time, the validation problem once validation was attempted.
fn questionnaire_shown_error(config QuestionnaireConfig, index int, resolved QuestionnaireResolved) string {
	if index < 0 || !resolved.active[index] {
		return ''
	}
	item := config.items[index]
	item_state := config.state.item(item.name)
	if item_state.skipped && !item.required {
		return ''
	}
	if item_state.external_error.len > 0 {
		return item_state.external_error
	}
	if !item_state.attempted {
		return ''
	}
	return questionnaire_problem(config, index, resolved)
}

// questionnaire_error is the error shown under the named item, '' when none
// is. Errors show once validation has been attempted on the item (by Next or
// Submit) and then follow every change; external errors show at once.
pub fn questionnaire_error(config QuestionnaireConfig, name string) string {
	return questionnaire_shown_error(config, questionnaire_index(config.items, name),
		questionnaire_resolve(config.items, config.state))
}

// questionnaire_item_valid reports whether the named shown item passes
// validation now, attempted or not.
pub fn questionnaire_item_valid(config QuestionnaireConfig, name string) bool {
	index := questionnaire_index(config.items, name)
	resolved := questionnaire_resolve(config.items, config.state)
	return index >= 0 && resolved.active[index] && questionnaire_problem(config, index, resolved).len == 0
}

// QuestionnaireProgress counts the shown items only, so it moves as
// conditional items appear and disappear.
pub struct QuestionnaireProgress {
pub:
	current  int // 1-based position of the current item; 0 when none is shown
	total    int
	answered int // shown items answered or skipped
}

// percent is the current position as a percentage, as upstream's progress
// bar shows it.
pub fn (progress QuestionnaireProgress) percent() f64 {
	return if progress.total == 0 { 0.0 } else { f64(progress.current) * 100 / f64(progress.total) }
}

// answered_percent is the share of shown items answered or skipped.
pub fn (progress QuestionnaireProgress) answered_percent() f64 {
	return if progress.total == 0 {
		0.0
	} else {
		f64(progress.answered) * 100 / f64(progress.total)
	}
}

fn questionnaire_progress_of(resolved QuestionnaireResolved) QuestionnaireProgress {
	mut answered := 0
	for entry in resolved.entries.items {
		if entry.status != .unanswered {
			answered++
		}
	}
	return QuestionnaireProgress{
		current:  resolved.order.index(resolved.current) + 1
		total:    resolved.order.len
		answered: answered
	}
}

pub fn questionnaire_progress(config QuestionnaireConfig) QuestionnaireProgress {
	return questionnaire_progress_of(questionnaire_resolve(config.items, config.state))
}

// QuestionnaireNavigation says which actions show. Hidden actions are not
// drawn and their actions are rejected.
pub struct QuestionnaireNavigation {
pub:
	previous    bool
	next        bool
	skip        bool // the current item is optional
	submit      bool
	confirmable bool // the current item is answered or skipped
}

fn questionnaire_navigation_of(config QuestionnaireConfig, resolved QuestionnaireResolved) QuestionnaireNavigation {
	position := resolved.order.index(resolved.current)
	if position < 0 {
		return QuestionnaireNavigation{}
	}
	confirmable := resolved.entries.items[position].status != .unanswered
	if config.layout == .page {
		return QuestionnaireNavigation{
			submit:      true
			confirmable: confirmable
		}
	}
	last := position + 1 == resolved.order.len
	return QuestionnaireNavigation{
		previous:    position > 0
		next:        !last
		skip:        !config.items[resolved.current].required
		submit:      last
		confirmable: confirmable
	}
}

// questionnaire_navigation is the default action layout: Previous after the
// first item, Next between items, Skip on an optional item and Submit on the
// last one. A page shows Submit alone.
pub fn questionnaire_navigation(config QuestionnaireConfig) QuestionnaireNavigation {
	return questionnaire_navigation_of(config, questionnaire_resolve(config.items, config.state))
}

// questionnaire_shortcut is the key label of a choice, '' when shortcuts are
// off, the choice is disabled or it is past the ninth (numbers) or the
// twenty-sixth (letters) enabled choice.
pub fn questionnaire_shortcut(config QuestionnaireConfig, item_name string, value string) string {
	index := questionnaire_index(config.items, item_name)
	if index < 0 || config.shortcuts == .off {
		return ''
	}
	mut position := 0
	for choice in config.items[index].choices {
		if !choice.enabled {
			continue
		}
		if questionnaire_choice_key(choice) == value {
			return questionnaire_shortcut_label(config.shortcuts, position)
		}
		position++
	}
	return ''
}

fn questionnaire_shortcut_label(mode QuestionnaireShortcuts, position int) string {
	return match mode {
		.numbers {
			if position < 9 { (position + 1).str() } else { '' }
		}
		.letters {
			if position < 26 { u8(`A` + position).ascii_str() } else { '' }
		}
		.off {
			''
		}
	}
}

// ── Commands ────────────────────────────────────────────────────────

// Each command below works on a config whose state is current and returns a
// QuestionnaireUpdate. Internally a command that changes nothing returns the
// same state with no events; the public wrappers turn that into none.

fn questionnaire_with_state(config QuestionnaireConfig, qs QuestionnaireState) QuestionnaireConfig {
	return QuestionnaireConfig{
		...config
		state: qs
	}
}

fn questionnaire_noop(config QuestionnaireConfig) QuestionnaireUpdate {
	return QuestionnaireUpdate{
		state: config.state
	}
}

fn questionnaire_result(config QuestionnaireConfig, update QuestionnaireUpdate) ?QuestionnaireUpdate {
	if update.events.len == 0 && update.focus.len == 0 && !update.confirm_later
		&& update.state == config.state {
		return none
	}
	return update
}

// questionnaire_then keeps the events of two steps run one after the other.
fn questionnaire_then(first QuestionnaireUpdate, second QuestionnaireUpdate) QuestionnaireUpdate {
	mut events := first.events.clone()
	events << second.events
	return QuestionnaireUpdate{
		state:         second.state
		events:        events
		focus:         if second.focus.len > 0 { second.focus } else { first.focus }
		confirm_later: second.confirm_later
	}
}

// questionnaire_entry_focus is the element to focus on arriving at an item:
// the input of an item whose whole answer is typed.
fn questionnaire_entry_focus(config QuestionnaireConfig, index int) string {
	item := config.items[index]
	if item.choices.len == 0 && questionnaire_input_enabled(item) {
		return questionnaire_input_id(config.id, item.name)
	}
	return ''
}

// questionnaire_invalid_focus is the element to focus when an item fails
// validation: its input, when the input holds the answer or is the only answer.
fn questionnaire_invalid_focus(config QuestionnaireConfig, index int) string {
	item := config.items[index]
	if !questionnaire_input_enabled(item) {
		return ''
	}
	item_state := config.state.item(item.name)
	if item.choices.len == 0 || (item_state.freeform && item_state.text.trim_space().len > 0) {
		return questionnaire_input_id(config.id, item.name)
	}
	return ''
}

fn questionnaire_move(config QuestionnaireConfig, qs QuestionnaireState, from int, to int) QuestionnaireUpdate {
	moved := from != to
	next := QuestionnaireState{
		...qs
		current:   config.items[to].name
		pending:   ''
		highlight: if moved { '' } else { qs.highlight }
	}
	mut events := []QuestionnaireEvent{}
	if moved {
		events << QuestionnaireEvent{
			kind:     .current_item_changed
			item:     config.items[to].name
			previous: if from >= 0 { config.items[from].name } else { '' }
		}
	}
	return QuestionnaireUpdate{
		state:  next
		events: events
		focus:  if moved { questionnaire_entry_focus(config, to) } else { '' }
	}
}

// questionnaire_answer_op stores an item's new state. When its effective
// answer or status changes, completion and any pending confirm are dropped and
// answer_changed is raised. On a page the item becomes current.
fn questionnaire_answer_op(config QuestionnaireConfig, index int, next QuestionnaireItemState) QuestionnaireUpdate {
	item := config.items[index]
	before_state := config.state.item(item.name)
	old_answer := questionnaire_effective(item, before_state)
	new_answer := questionnaire_effective(item, next)
	old_status := questionnaire_status_of(before_state, old_answer)
	new_status := questionnaire_status_of(next, new_answer)
	mut qs := config.state.with_item(next)
	mut events := []QuestionnaireEvent{}
	if old_answer != new_answer || old_status != new_status {
		qs = QuestionnaireState{
			...qs
			complete: false
			pending:  ''
		}
		events << QuestionnaireEvent{
			kind:   .answer_changed
			item:   item.name
			answer: new_answer
			status: new_status
		}
	}
	if config.layout == .page {
		resolved := questionnaire_resolve(config.items, qs)
		if resolved.current != index {
			moved := questionnaire_move(config, qs, resolved.current, index)
			events << moved.events
			qs = moved.state
		}
	}
	return QuestionnaireUpdate{
		state:  qs
		events: events
	}
}

// questionnaire_choose_op applies a person's activation of a choice. A
// multiple-choice item toggles it. A single-choice item selects it and, when
// confirm is set and the item is the current step, confirms: after
// questionnaire_confirm_delay when the answer changed (at once with
// reduce_motion), immediately when the choice was already the answer.
fn questionnaire_choose_op(config QuestionnaireConfig, index int, value string, confirm bool) QuestionnaireUpdate {
	item := config.items[index]
	item_state := config.state.item(item.name)
	answer := questionnaire_effective(item, item_state)
	if item.multiple {
		mut chosen := item_state.choices.filter(it != value)
		if chosen.len == item_state.choices.len {
			if questionnaire_at_limit(item, answer) {
				return questionnaire_noop(config)
			}
			chosen << value
		}
		return questionnaire_answer_op(config, index, QuestionnaireItemState{
			...item_state
			choices: questionnaire_schema_order(item, chosen)
			skipped: false
		})
	}
	resolved := questionnaire_resolve(config.items, config.state)
	stepping := confirm && config.layout == .stepped && index == resolved.current
	if answer.choices == [value] && answer.freeform.len == 0 {
		return if stepping { questionnaire_confirm_op(config) } else { questionnaire_noop(config) }
	}
	update := questionnaire_answer_op(config, index, QuestionnaireItemState{
		...item_state
		choices:  [value]
		freeform: false
		skipped:  false
	})
	if !stepping {
		return update
	}
	if config.reduce_motion {
		return questionnaire_then(update, questionnaire_confirm_op(questionnaire_with_state(config,
			update.state)))
	}
	return QuestionnaireUpdate{
		...update
		state:         QuestionnaireState{
			...update.state
			pending: item.name
		}
		confirm_later: true
	}
}

fn questionnaire_schema_order(item QuestionnaireItem, values []string) []string {
	mut ordered := []string{cap: values.len}
	for choice in item.choices {
		value := questionnaire_choice_key(choice)
		if value in values {
			ordered << value
		}
	}
	return ordered
}

// questionnaire_other_op answers a press on the freeform answer's indicator.
// On a single-choice item it makes the draft the answer (pressing it again
// with a draft confirms, like choosing the selected answer); on a multiple one
// it toggles the draft in and out of the answer. Either way the input is the
// place to type, so it is focused.
fn questionnaire_other_op(config QuestionnaireConfig, index int) QuestionnaireUpdate {
	item := config.items[index]
	item_state := config.state.item(item.name)
	answer := questionnaire_effective(item, item_state)
	field := questionnaire_input_id(config.id, item.name)
	filled := item_state.text.trim_space().len > 0
	if !questionnaire_other_open(item, item_state, answer) {
		return questionnaire_noop(config)
	}
	if item.multiple {
		update := questionnaire_answer_op(config, index, QuestionnaireItemState{
			...item_state
			freeform: !item_state.freeform
			skipped:  if !item_state.freeform && filled { false } else { item_state.skipped }
		})
		return QuestionnaireUpdate{
			...update
			focus: if item_state.freeform { '' } else { field }
		}
	}
	if item_state.freeform {
		resolved := questionnaire_resolve(config.items, config.state)
		if filled && config.layout == .stepped && index == resolved.current {
			return questionnaire_confirm_op(config)
		}
		return QuestionnaireUpdate{
			state: config.state
			focus: field
		}
	}
	update := questionnaire_answer_op(config, index, QuestionnaireItemState{
		...item_state
		freeform: true
		choices:  []string{}
		skipped:  if filled { false } else { item_state.skipped }
	})
	return QuestionnaireUpdate{
		...update
		focus: field
	}
}

// questionnaire_text_op stores a typed draft. A draft that is not blank
// becomes part of the answer, replacing the choice of a single-choice item; a
// blank one leaves it. Typing never confirms.
fn questionnaire_text_op(config QuestionnaireConfig, index int, typed string) QuestionnaireUpdate {
	item := config.items[index]
	item_state := config.state.item(item.name)
	if typed == item_state.text {
		return questionnaire_noop(config)
	}
	next := if typed.trim_space().len > 0 {
		QuestionnaireItemState{
			...item_state
			text:     typed
			freeform: true
			skipped:  false
			choices:  if item.multiple { item_state.choices } else { []string{} }
		}
	} else {
		QuestionnaireItemState{
			...item_state
			text:     typed
			freeform: false
		}
	}
	return questionnaire_answer_op(config, index, next)
}

fn questionnaire_attempt(config QuestionnaireConfig, qs QuestionnaireState, index int) QuestionnaireState {
	item_state := qs.item(config.items[index].name)
	if item_state.attempted {
		return qs
	}
	return qs.with_item(QuestionnaireItemState{
		...item_state
		attempted: true
	})
}

fn questionnaire_previous_op(config QuestionnaireConfig) QuestionnaireUpdate {
	resolved := questionnaire_resolve(config.items, config.state)
	position := resolved.order.index(resolved.current)
	if position <= 0 {
		return questionnaire_noop(config)
	}
	return questionnaire_move(config, config.state, resolved.current, resolved.order[position - 1])
}

// questionnaire_next_op validates the current item and moves to the next shown
// one. An invalid item stays, with its error shown and an invalid event.
fn questionnaire_next_op(config QuestionnaireConfig) QuestionnaireUpdate {
	resolved := questionnaire_resolve(config.items, config.state)
	current := resolved.current
	if current < 0 {
		return questionnaire_noop(config)
	}
	qs := QuestionnaireState{
		...questionnaire_attempt(config, config.state, current)
		pending: ''
	}
	problem := questionnaire_problem(config, current, resolved)
	if problem.len > 0 {
		return QuestionnaireUpdate{
			state:  qs
			events: [
				QuestionnaireEvent{
					kind:  .invalid
					item:  config.items[current].name
					error: problem
				},
			]
			focus:  questionnaire_invalid_focus(config, current)
		}
	}
	position := resolved.order.index(current)
	if position + 1 >= resolved.order.len {
		return questionnaire_noop(config)
	}
	return questionnaire_move(config, qs, current, resolved.order[position + 1])
}

// questionnaire_submit_op validates every shown item. The first invalid one
// becomes current and raises invalid; otherwise the submission goes out as
// completed (on the transition into a complete state) followed by submit. On a
// page, unanswered optional items are recorded as skipped.
fn questionnaire_submit_op(config QuestionnaireConfig) QuestionnaireUpdate {
	resolved := questionnaire_resolve(config.items, config.state)
	if resolved.order.len == 0 {
		return questionnaire_noop(config)
	}
	mut qs := QuestionnaireState{
		...config.state
		pending: ''
	}
	mut first_invalid := -1
	mut problem := ''
	for index in resolved.order {
		qs = questionnaire_attempt(config, qs, index)
		found := questionnaire_problem(config, index, resolved)
		if found.len > 0 && first_invalid < 0 {
			first_invalid = index
			problem = found
		}
	}
	if first_invalid >= 0 {
		moved := questionnaire_move(config, qs, resolved.current, first_invalid)
		mut events := moved.events.clone()
		events << QuestionnaireEvent{
			kind:  .invalid
			item:  config.items[first_invalid].name
			error: problem
		}
		return QuestionnaireUpdate{
			state:  moved.state
			events: events
			focus:  questionnaire_invalid_focus(config, first_invalid)
		}
	}
	if config.layout == .page {
		for index in resolved.order {
			item := config.items[index]
			item_state := qs.item(item.name)
			if !item.required && !item_state.skipped && resolved.answers[index].is_empty() {
				qs = qs.with_item(QuestionnaireItemState{
					...item_state
					skipped: true
				})
			}
		}
	}
	answers := questionnaire_resolve(config.items, qs).entries
	mut events := []QuestionnaireEvent{}
	if !config.state.complete {
		events << QuestionnaireEvent{
			kind:    .completed
			answers: answers
		}
	}
	events << QuestionnaireEvent{
		kind:    .submit
		answers: answers
	}
	return QuestionnaireUpdate{
		state:  QuestionnaireState{
			...qs
			complete: true
		}
		events: events
	}
}

// questionnaire_confirm_op continues from the current item: Next between
// items, Submit on the last one.
fn questionnaire_confirm_op(config QuestionnaireConfig) QuestionnaireUpdate {
	resolved := questionnaire_resolve(config.items, config.state)
	position := resolved.order.index(resolved.current)
	if position < 0 {
		return questionnaire_noop(config)
	}
	if position + 1 == resolved.order.len {
		return questionnaire_submit_op(config)
	}
	return questionnaire_next_op(config)
}

// questionnaire_skip_op records the current optional item as skipped, which
// clears its answer and is valid, then continues: Next, or Submit after the
// last item.
fn questionnaire_skip_op(config QuestionnaireConfig) QuestionnaireUpdate {
	resolved := questionnaire_resolve(config.items, config.state)
	current := resolved.current
	if current < 0 || config.items[current].required {
		return questionnaire_noop(config)
	}
	item := config.items[current]
	item_state := config.state.item(item.name)
	skipped := QuestionnaireItemState{
		...item_state
		choices:  []string{}
		freeform: false
		skipped:  true
	}
	first := QuestionnaireUpdate{
		state:  QuestionnaireState{
			...config.state.with_item(skipped)
			complete: false
			pending:  ''
		}
		events: [
			QuestionnaireEvent{
				kind:   .answer_changed
				item:   item.name
				status: .skipped
			},
		]
	}
	return questionnaire_then(first, questionnaire_confirm_op(questionnaire_with_state(config,
		first.state)))
}

// questionnaire_previous moves to the shown item before the current one. It
// does not validate. It returns none on the first item.
pub fn questionnaire_previous(config QuestionnaireConfig) ?QuestionnaireUpdate {
	if !config.enabled {
		return none
	}
	return questionnaire_result(config, questionnaire_previous_op(config))
}

// questionnaire_next validates the current item and moves to the next shown
// one. An invalid item stays put with its error shown and an invalid event.
pub fn questionnaire_next(config QuestionnaireConfig) ?QuestionnaireUpdate {
	if !config.enabled {
		return none
	}
	return questionnaire_result(config, questionnaire_next_op(config))
}

// questionnaire_skip skips the current optional item and continues.
pub fn questionnaire_skip(config QuestionnaireConfig) ?QuestionnaireUpdate {
	if !config.enabled {
		return none
	}
	return questionnaire_result(config, questionnaire_skip_op(config))
}

// questionnaire_submit validates every shown item and submits.
pub fn questionnaire_submit(config QuestionnaireConfig) ?QuestionnaireUpdate {
	if !config.enabled {
		return none
	}
	return questionnaire_result(config, questionnaire_submit_op(config))
}

// questionnaire_confirm continues from the current item: Next, or Submit on
// the last one. Cmd/Ctrl+Enter runs it.
pub fn questionnaire_confirm(config QuestionnaireConfig) ?QuestionnaireUpdate {
	if !config.enabled {
		return none
	}
	return questionnaire_result(config, questionnaire_confirm_op(config))
}

// questionnaire_confirm_pending confirms the item a chosen answer is waiting
// on (see QuestionnaireUpdate.confirm_later). It does nothing when anything
// has happened since: another change, or another item becoming current.
pub fn questionnaire_confirm_pending(config QuestionnaireConfig) ?QuestionnaireUpdate {
	if !config.enabled || config.state.pending.len == 0 {
		return none
	}
	if config.state.pending != questionnaire_current(config) {
		return QuestionnaireUpdate{
			state: QuestionnaireState{
				...config.state
				pending: ''
			}
		}
	}
	cleared := questionnaire_with_state(config, QuestionnaireState{
		...config.state
		pending: ''
	})
	return questionnaire_confirm_op(cleared)
}

// questionnaire_choose is what a click or a shortcut does: toggle a choice of
// a multiple-choice item, or select one of a single-choice item and confirm
// it (see questionnaire_choose_op). Use it to answer for a person; it returns
// none for unknown, hidden or disabled choices and for no-ops.
pub fn questionnaire_choose(config QuestionnaireConfig, item_name string, value string) ?QuestionnaireUpdate {
	index := questionnaire_open_choice(config, item_name, value) or { return none }
	return questionnaire_result(config, questionnaire_choose_op(config, index, value,
		true))
}

// questionnaire_activate_choice selects a choice, or toggles it on a
// multiple-choice item, without confirming.
pub fn questionnaire_activate_choice(config QuestionnaireConfig, item_name string, value string) ?QuestionnaireUpdate {
	index := questionnaire_open_choice(config, item_name, value) or { return none }
	return questionnaire_result(config, questionnaire_choose_op(config, index, value,
		false))
}

fn questionnaire_open_choice(config QuestionnaireConfig, item_name string, value string) ?int {
	if !config.enabled {
		return none
	}
	index := questionnaire_index(config.items, item_name)
	resolved := questionnaire_resolve(config.items, config.state)
	if index < 0 || !resolved.active[index] {
		return none
	}
	item := config.items[index]
	choice_index := questionnaire_choice_index(item, value)
	if choice_index < 0
		|| !questionnaire_choice_open(item, item.choices[choice_index], resolved.answers[index]) {
		return none
	}
	return index
}

// ── Silent setters ──────────────────────────────────────────────────

// These apply a value the application owns, such as a saved draft, without
// raising events. They return an error for unknown items, choices that do not
// belong to the item, and answers the item cannot hold.

fn questionnaire_known(config QuestionnaireConfig, name string) !int {
	index := questionnaire_index(config.items, name)
	if index < 0 {
		return error('unknown questionnaire item `${name}`')
	}
	return index
}

// questionnaire_set_current makes the named shown item current.
pub fn questionnaire_set_current(config QuestionnaireConfig, name string) !QuestionnaireState {
	index := questionnaire_known(config, name)!
	if !questionnaire_resolve(config.items, config.state).active[index] {
		return error('questionnaire item `${name}` is not shown')
	}
	return QuestionnaireState{
		...config.state
		current:   name
		pending:   ''
		highlight: ''
	}
}

// questionnaire_set_answer replaces an item's answer. A freeform text also
// becomes the input's draft; an answer without one keeps the draft out of the
// answer.
pub fn questionnaire_set_answer(config QuestionnaireConfig, name string, answer QuestionnaireAnswer) !QuestionnaireState {
	index := questionnaire_known(config, name)!
	item := config.items[index]
	freeform := answer.freeform.trim_space().len > 0
	sources := answer.choices.len + if freeform { 1 } else { 0 }
	if !item.multiple && sources > 1 {
		return error('single-choice item `${name}` takes one answer')
	}
	if freeform && item.input == none {
		return error('questionnaire item `${name}` has no input for a freeform answer')
	}
	for value in answer.choices {
		choice_index := questionnaire_choice_index(item, value)
		if choice_index < 0 {
			return error('unknown choice `${value}` in item `${name}`')
		}
		if !item.choices[choice_index].enabled {
			return error('choice `${value}` of item `${name}` is disabled')
		}
	}
	item_state := config.state.item(name)
	next := QuestionnaireItemState{
		...item_state
		choices:  questionnaire_schema_order(item, answer.choices)
		text:     if freeform { answer.freeform } else { item_state.text }
		freeform: freeform
		skipped:  false
	}
	changed := questionnaire_effective(item, next) != questionnaire_effective(item, item_state)
		|| item_state.skipped
	return QuestionnaireState{
		...config.state.with_item(next)
		complete: config.state.complete && !changed
		pending:  ''
	}
}

// questionnaire_set_input_text replaces an input's draft as typing would,
// without events. Pass the same text to ui2.set_text when the field is
// mounted, since a refresh keeps what a field shows.
pub fn questionnaire_set_input_text(config QuestionnaireConfig, name string, draft string) !QuestionnaireState {
	index := questionnaire_known(config, name)!
	if config.items[index].input == none {
		return error('questionnaire item `${name}` has no input')
	}
	return questionnaire_text_op(config, index, draft).state
}

// questionnaire_set_external_error shows an owner's error under an item, such
// as a server's verdict. It blocks Next and Submit until cleared.
pub fn questionnaire_set_external_error(config QuestionnaireConfig, name string, message string) !QuestionnaireState {
	questionnaire_known(config, name)!
	item_state := config.state.item(name)
	return QuestionnaireState{
		...config.state.with_item(QuestionnaireItemState{
			...item_state
			external_error: message
		})
		complete: false
	}
}

pub fn questionnaire_clear_external_error(config QuestionnaireConfig, name string) !QuestionnaireState {
	return questionnaire_set_external_error(config, name, '')
}

// questionnaire_reset returns to the initial state: default choices and
// drafts, no skips, no validation attempts, not complete, and the first shown
// item current. External errors stay: they belong to the owner. Remember to
// put reset drafts back into mounted fields with ui2.set_text.
pub fn questionnaire_reset(config QuestionnaireConfig) QuestionnaireState {
	initial := questionnaire_initial_state(config.items) or { return config.state }
	mut qs := initial
	for entry in config.state.items {
		if entry.external_error.len > 0 {
			qs = qs.with_item(QuestionnaireItemState{
				...qs.item(entry.name)
				external_error: entry.external_error
			})
		}
	}
	return qs
}
