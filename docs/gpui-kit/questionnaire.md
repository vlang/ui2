# Questionnaire

A port of GPUI Kit's
[questionnaire](https://github.com/longbridge/gpui-kit/blob/main/website/component/questionnaire.md):
an ordered set of questions with single and multiple choice, an "other"
freeform answer, free-text questions, required and custom validation, skipping,
conditional questions, progress, keyboard shortcuts and submission.

The model (schema, state, answers, visibility, validation, navigation and the
commands) is in `ui/component_questionnaire.v`; action ids, decoders, keyboard
handling and the dialog helpers are in `ui/component_questionnaire_input.v`;
drawing is in `ui/component_questionnaire_view.v`. `ui/component_questionnaire_test.v`
covers the rules, and `examples/gpui_questionnaire/main.v` is a product
feedback survey with a conditional follow-up, a limited multi-select, "other"
answers, a validated free-text question, progress, a summary after submit, a
one-page layout, the same questionnaire in a dialog, and a light/dark toggle.

## How it maps onto ui2

Upstream's `QuestionnaireState` is an entity that owns answers, focus and a
confirm timer and emits `QuestionnaireEvent`s to subscribers. ui2 components
are controlled, so here:

- the **schema** is a plain `[]QuestionnaireItem` the application rebuilds every
  frame (it may hold closures: validators and visibility conditions);
- the **state** is a plain `QuestionnaireState` value the application stores;
- every user intent is a **command** that takes the `QuestionnaireConfig` the
  questionnaire was built with and returns `?QuestionnaireUpdate`: the new state,
  the events the change raised (in upstream's order), an element to focus after
  rebuilding, and whether a chosen answer waits to confirm;
- the **decoders** turn an action, a field's text or a key into such an update,
  and return `none` for foreign, forged or malformed actions, parts that are not
  drawn (another step's choices, hidden actions), disabled choices and no-ops.

```v
fn feedback_config(app &App) ui2.QuestionnaireConfig {
	return ui2.QuestionnaireConfig{
		id:        'feedback'
		frame:     ui2.rect(24, 24, 560, 520)
		items:     feedback_items()
		state:     app.qs // from ui2.questionnaire_initial_state(feedback_items())!
		shortcuts: .numbers
		theme:     ui2.component_theme(app.dark)
	}
}

// build:
ui2.questionnaire(feedback_config(app)) or { panic(err) }

// on_event:
cfg := feedback_config(app)
if _ := ui2.questionnaire_input_item(cfg, action) {
	if update := ui2.questionnaire_update_from_text(cfg, action, ui2.text(action)) {
		app.apply(update)
	}
} else if update := ui2.questionnaire_update_from_action(cfg, action) {
	app.apply(update)
}

// on_key_event:
if update := ui2.questionnaire_update_from_key(cfg, event, ui2.focused_id()) {
	ui2.consume_key()
	app.apply(update)
}

fn (mut app App) apply(update ui2.QuestionnaireUpdate) {
	app.qs = update.state
	for event in update.events {
		// .current_item_changed, .answer_changed, .invalid, .completed, .submit
	}
	if answers := update.submission() {
		// send answers.items (name, status, answer) to the server
	}
	if update.confirm_later {
		ui2.cancel_timer(app.timer)
		app.timer = ui2.after(ui2.questionnaire_confirm_delay, fn () {
			mut a := unsafe { the_app }
			if next := ui2.questionnaire_confirm_pending(feedback_config(a)) {
				a.apply(next)
			}
		})
	}
	if update.focus.len > 0 {
		// focus once the rebuilt tree is on screen
		id := update.focus
		ui2.after(0.05, fn [id] () { ui2.focus(id) })
	}
}
```

## Schema

```v
items := [
	ui2.QuestionnaireItem{
		name:     'satisfaction'
		title:    'How satisfied are you?'
		required: true
		choices:  [ui2.QuestionnaireChoice{ value: 'happy', label: 'Happy' },
			ui2.QuestionnaireChoice{ value: 'meh', label: 'Meh', description: 'Could be better.' }]
	},
	ui2.QuestionnaireItem{
		name:        'problems'
		title:       'What got in the way?'
		multiple:    true
		max_choices: 2 // min_choices too
		visible_if:  ui2.questionnaire_when_chosen('satisfaction', ['meh'])
		choices:     [ui2.QuestionnaireChoice{ label: 'Slow sync' }, ui2.QuestionnaireChoice{ label: 'Price' }]
		input:       ui2.QuestionnaireInput{ label: 'Something else', placeholder: 'Something else…' }
	},
	ui2.QuestionnaireItem{
		name:      'improve'
		title:     'What should we improve?'
		required:  true
		input:     ui2.QuestionnaireInput{ label: 'Improvement', multiline: true, lines: 4 }
		validator: fn (c ui2.QuestionnaireValidationContext) ! {
			if c.answer.freeform.len < 20 { return error('At least 20 characters, please.') }
		}
	},
]
```

API: `QuestionnaireChoice{value, label, description, enabled, selected}`;
`QuestionnaireInput{label, placeholder, multiline, lines, text, enabled}`;
`QuestionnaireItem{name, title, description, required, multiple, min_choices,
max_choices, enabled, choices, input, validator, visible_if, required_message}`;
`QuestionnaireValidator = fn (QuestionnaireValidationContext) !`;
`QuestionnaireCondition = fn (QuestionnaireAnswers) bool`;
`questionnaire_validate(items) !`, `questionnaire_when_chosen(item, values)`,
`questionnaire_when_answered(item)`.

`questionnaire_validate` (run by the builder, `questionnaire_initial_state` and
`questionnaire_reset`) rejects empty or duplicate item names, empty or duplicate
choice values, more than one default on a single-choice item, negative or
inverted limits, limits on single-choice items, more defaults than
`max_choices`, inputs without an accessible label, and items with neither
choices nor an input.

A choice's `selected`, an input's `text` and `QuestionnaireItem.enabled` are the
initial snapshot: `questionnaire_initial_state(items)` applies them and
`questionnaire_reset(config)` returns to them. A non-blank default draft is a
single-choice item's answer and replaces its default choice, as upstream.

## State, answers and events

`QuestionnaireState{current, items, complete, pending, highlight}` with
`QuestionnaireItemState{name, choices, text, freeform, skipped, attempted,
external_error}`. `state.item(name)` reads an item's state (empty when absent),
so `QuestionnaireState{}` is a valid, unanswered start.

`QuestionnaireAnswer{choices, freeform}` (`is_empty`, `has`, `count`),
`QuestionnaireEntry{name, status, answer}`, `QuestionnaireAnswers{items}`
(`entry`, `answer`, `chose`), `QuestionnaireItemStatus` (`unanswered`,
`answered`, `skipped`), `QuestionnaireEvent{kind, item, previous, answer,
status, error, answers}` with `QuestionnaireEventKind` (`current_item_changed`,
`answer_changed`, `invalid`, `completed`, `submit`), and
`QuestionnaireUpdate{state, events, focus, confirm_later}` (`submission()`).

Readers: `questionnaire_current`, `questionnaire_active_items`,
`questionnaire_item_visible`, `questionnaire_answer`, `questionnaire_answers`,
`questionnaire_status`, `questionnaire_error`, `questionnaire_item_valid`,
`questionnaire_answer_labels`, `questionnaire_progress`
(`QuestionnaireProgress{current, total, answered}`, `percent()`,
`answered_percent()`), `questionnaire_navigation`
(`QuestionnaireNavigation{previous, next, skip, submit, confirmable}`),
`questionnaire_shortcut`.

## Rules

- **Effective answers.** Selected enabled choices in schema order, plus the
  draft when it is part of the answer and not blank. A disabled choice leaves
  the answer; a hidden or disabled item answers nothing.
- **Single choice.** Choosing (click, Space/Enter on the highlight, shortcut)
  selects and confirms: the update has `confirm_later`, and
  `questionnaire_confirm_pending` after `questionnaire_confirm_delay` (0.15 s)
  moves on, or submits on the last item, unless validation fails. Anything that
  happens meanwhile drops the pending confirm. Choosing the selected answer
  again confirms at once; `reduce_motion: true` confirms in the same update.
  `questionnaire_activate_choice` and the arrow keys select without confirming.
- **Multiple choice.** Choosing toggles; Next continues. With `max_choices`,
  the other choices (and the freeform answer) disable once the limit is
  reached; `min_choices`/`max_choices` are also checked by validation, and a
  hint line ("Choose up to 2.") is drawn under the description.
- **Freeform answer.** Typing a non-blank draft makes it the answer (replacing
  a single choice); choosing a fixed answer keeps the draft out of the answer
  but keeps the draft. The indicator beside the field selects the draft (single)
  or toggles it (multiple) and focuses the field. Whitespace is no answer.
  Typing never confirms.
- **Validation.** `Next` validates the current item, `Submit` every shown item
  and makes the first invalid one current. Errors show once validation was
  attempted on an item and then follow every change. Order: a skipped optional
  item passes; an external error; an empty answer (required, or optional and not
  skipped: "Choose an answer or skip this question."); the selection limits; the
  item's validator, which sees every shown answer.
  `questionnaire_set_external_error`/`questionnaire_clear_external_error` manage
  owner errors, which block until cleared and survive reset.
- **Skipping.** Optional items show Skip; skipping clears the answer, is valid,
  and continues (submits on the last item). Answering a skipped item clears the
  skip.
- **Conditional items.** `visible_if` is evaluated in order against the shown
  items before the item, so chains follow. A hidden item leaves progress,
  navigation, validation, shortcuts and the submission; its stored state stays
  for when it shows again. `enabled: false` does the same unconditionally.
- **Completion.** `completed` is raised on the transition into a complete
  state, then `submit`; later submits raise only `submit` until an answer
  changes.
- **Silent setters** apply owner values without events and return an error for
  unknown items or answers the item cannot hold: `questionnaire_set_current`,
  `questionnaire_set_answer`, `questionnaire_set_input_text`, `questionnaire_reset`.

## Navigation and layouts

`layout: .stepped` (default) shows one item: "Question 2 of 4" with a
`linear_progress` bar, the item, and Previous at the start and Skip and
Next/Submit at the end of the frame's bottom row, so the buttons stay put from
step to step. `layout: .page` shows every shown item stacked, "3 of 5
answered", and a single Submit; on a page, choosing never confirms, the item a
person works on becomes current, and Submit records unanswered optional items as
skipped. When the items are taller than the room between the progress line and
the actions they scroll; `questionnaire_scroll_id` and
`questionnaire_item_rect` let the application scroll an item into view with
`ui2.scroll_to_rect` (the example does after a failed Submit on a page).

Commands: `questionnaire_previous`, `questionnaire_next`, `questionnaire_skip`,
`questionnaire_submit`, `questionnaire_confirm` (Next or Submit),
`questionnaire_confirm_pending`, `questionnaire_choose`,
`questionnaire_activate_choice`. Action ids:
`questionnaire_choice_action_id(id, item, value)`,
`questionnaire_other_action_id(id, item)`, `questionnaire_input_id(id, item)`
(also the field's change action), `questionnaire_input_submit_id(id, item)`,
`questionnaire_command_action_id(id, command)`; names and values are hex-encoded,
so any string is safe.

`questionnaire_natural_height(config)` is the frame height at which nothing
scrolls: for steps, the tallest enabled item with room for a one-line error, so
the frame suits every step.

## Keyboard

`questionnaire_update_from_key(config, event, ui2.focused_id())`:

| Key | Effect |
| --- | --- |
| `1`–`9` / `A`–`Z` (with `shortcuts: .numbers` / `.letters`) | choose that choice, as a click |
| Up, Down | move a highlight through the enabled choices and into the input; a single-choice selection follows |
| Left, Right | on a highlighted single-choice item, the same; otherwise previous item, and next item once the current one is answered or skipped |
| Space | choose the highlighted choice |
| Enter | choose the highlighted choice if unselected, else confirm an answered item |
| Enter in a one-line field | confirm a filled draft (AppKit sends Return to the field's submit action, which the action decoder treats the same) |
| Cmd+Enter / Ctrl+Enter | confirm the current item from anywhere |

Shortcut keys are drawn as key hints on the current item's cards, assigned in
enabled-choice order; disabled choices get none. Keys typed into a field and
modified keys are left alone. The highlight is drawn as a two-pixel primary
ring; a pointer action clears it.

## Card and dialog composition

The questionnaire draws no surface of its own, so it sits in any card,
`group_box` or dialog body. For a dialog, build it with `show_actions: false`,
size it with `questionnaire_natural_height`, and put its actions in the dialog
footer next to the application's Cancel:

```v
questions := ui2.QuestionnaireConfig{ ...cfg, frame: ui2.rect(0, 0, width, height), show_actions: false }
mut buttons := [ui2.DialogButton{ id: 'cancel', text: 'Cancel', role: .cancel }]
buttons << ui2.questionnaire_dialog_buttons(questions)
dialog := ui2.DialogConfig{
	...
	children:       [ui2.questionnaire(questions)!]
	content_height: questions.frame.height
	buttons:        buttons
}
// events: ui2.dialog_event_from_action(dialog, action) -> dismisses(), or
//         ui2.questionnaire_update_from_dialog(questions, event)
```

Next and Submit are confirm buttons, so the dialog's Enter runs them. Close the
dialog when an update carries a submission, as upstream's host does on
`Submit`.

## Sizes, theming and accessibility

`size` (`.small`, `.medium`, `.large`) scales every part; colors come from
`ComponentTheme`. All strings, including the error messages and the progress
line, are in `QuestionnaireMessages` for translation; `required_message`
overrides one item's required message. Cards are views with button behavior,
with roles `radio`/`checkbox` and values `checked`/`unchecked`; an item is a
`group` labelled by its title with its description as value; the answers are a
`radiogroup` (single choice) or `group`; the error is an `alert`; the progress
line a `progressbar` (the bar's value is the percentage). The root has role
`form`, which AppKit does not map yet, so it keeps the native role.

## Implemented and omitted

Implemented: the schema with choices, descriptions, defaults and disabled
items/choices; single and multiple choice; the freeform input beside choices
and as the whole answer, one-line and multiline; required and custom
validation, external errors, attempted-only error display; skipping; the
current item, previous/next/submit/confirm and their visibility rules;
completion and submit events in upstream's order; the 150 ms confirm pause and
reduced motion; reset to the schema's baseline keeping external errors; silent
setters with schema errors; conditional items (as upstream's host-side
`set_item_disabled`, plus declarative `visible_if`); progress text and bar;
number and letter shortcuts with key hints; arrow-key movement, Space, Enter
and Cmd+Enter; sizes; theming; card and dialog composition.

Additions: `min_choices`/`max_choices` with a hint line and limit-aware
disabling; `visible_if` conditions; the one-page layout; translatable messages;
`questionnaire_natural_height` and scroll helpers.

Omitted, with reasons:

- **Compound parts and style seams** (`QuestionnaireTitle`, `render_indicator`,
  `indicator_style`, custom choice children, `QuestionnaireChoiceDescription`).
  ui2 builds elements from config values; the builder draws the default
  composition. A custom skin can be drawn by the application from the readers
  and emit the same action ids, which the decoders accept.
- **Focus handles.** ui2 has no focus API for views, so only the freeform field
  is focused (`QuestionnaireUpdate.focus`); keyboard movement among choices is a
  drawn highlight. Up from an empty focused field back to the choices is not
  available, since a component cannot take focus away from a native field.
- **Repeated keys and IME composition.** `KeyEvent` reports neither, so the
  helper cannot skip them; native text fields keep their own composition.
- **`Size::XSmall` and custom sizes.** `ComponentSize` has three presets.
- **Hover styling of cards.** It would need hover state round-tripped through
  the application for every card; the pointer cursor marks them instead.
- **A placeholder in multiline inputs.** ui2's text area has none.
- **`aria-invalid`.** Not exposed upstream either; the error alert and colors
  carry the invalid state.
