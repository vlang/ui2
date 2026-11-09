module main

import ui2

const demo_width = 560
const demo_height = 520

// demo_sheet is the global u2ss sheet: type, class, id and pseudo-class
// selectors plus light/dark theme variables. Inline struct props still win;
// everything here only fills what the builders leave at defaults.
const demo_sheet = '
@accent: #2563eb;
@accent-hover: #1d4ed8;
light { @bg: #f1f5f9; @ink: #172033; @muted: #64748b; }
dark { @bg: #172033; @ink: #f8fafc; @muted: #b4c0d0; }

Button {
	background: @accent;
	color: white;
	border-radius: 6px;
	font-size: 14px;
}
Button:hover { background: @accent-hover; }
Button:pressed { opacity: 0.85; }
Button:disabled { opacity: 0.4; }
Button.ghost { background: @bg; color: @ink; border-color: @accent; border-width: 1px; }
Label { color: @ink; font-size: 14px; }
Label.title { font-size: 22px; font-weight: bold; }
Label.muted { color: @muted; font-size: 13px; }
@media (max-width: 480px) { Label.title { font-size: 16px; } }
Label.counter { font-size: 20px; font-weight: bold; }
Checkbox:checked { color: @accent; }
View.card {
	background: white;
	border-radius: 10px;
	border-color: #cbd5e1;
	border-width: 1px;
}
'

// card_sheet is scoped to one card via with_stylesheet: on equal specificity
// it beats the global sheet inside that subtree only.
const card_sheet = '
Button { background: #0d9488; }
Label.title { font-size: 16px; }
'

struct StylesheetDemo {
mut:
	count      int
	checked    bool
	dark       bool
	status     string = 'Hover the buttons, then toggle dark mode.'
	card_sheet ui2.Stylesheet
}

const demo_state = &StylesheetDemo{}

fn hoverable(el ui2.Element) ui2.Element {
	return ui2.Element{
		...el
		hoverable: true
	}
}

fn build_demo_screen() ui2.Element {
	state := unsafe { demo_state }
	return ui2.screen(0xf1f5f9, [
		ui2.label('title', 'Stylesheet Demo', ui2.rect(24, 16, 512, 30), ui2.TextStyle{}),
		ui2.with_classes(ui2.label('subtitle', 'u2ss: one sheet for both backends',
			ui2.rect(24, 48, 512, 20), ui2.TextStyle{}), 'muted'),
		hoverable(ui2.with_classes(ui2.button('inc', 'Count: ${state.count}', ui2.rect(24,
			84, 200, 38), ui2.BoxStyle{}, ui2.TextStyle{}), 'primary')),
		hoverable(ui2.button('toggle_dark', if state.dark { 'Light mode' } else { 'Dark mode' },
			ui2.rect(236, 84, 150, 38), ui2.BoxStyle{}, ui2.TextStyle{})),
		ui2.Element{
			...ui2.button('never', 'Disabled', ui2.rect(398, 84, 138, 38), ui2.BoxStyle{},
				ui2.TextStyle{})
			enabled: false
		},
		ui2.checkbox('check', 'Accent-checked box', state.checked, ui2.rect(24, 134, 300,
			28), ui2.TextStyle{}),
		ui2.with_stylesheet(ui2.view('card', ui2.rect(24, 174, 512, 220), ui2.BoxStyle{}, [
			ui2.with_classes(ui2.label('card_title', 'Scoped card', ui2.rect(16, 12, 480,
				24), ui2.TextStyle{}), 'title'),
			ui2.with_classes(ui2.label('card_note', 'The teal button below comes from the card-scoped sheet, not the global one.',
				ui2.rect(16, 40, 480, 40), ui2.TextStyle{}), 'muted'),
			hoverable(ui2.button('scoped', 'Scoped action', ui2.rect(16, 96, 200, 38),
				ui2.BoxStyle{}, ui2.TextStyle{})),
			ui2.with_classes(ui2.label('scoped_styled', 'Styled from V code via the DSL constructor.',
				ui2.rect(16, 146, 480, 24), ui2.TextStyle{}), 'from-dsl'),
		]), state.card_sheet),
		ui2.with_classes(ui2.label('status', state.status, ui2.rect(24, 406, 512, 60),
			ui2.TextStyle{}), 'muted'),
	])
}

fn handle_demo_event(event string) {
	mut state := unsafe { demo_state }
	match event {
		'inc' {
			state.count++
			state.status = 'Count is ${state.count}.'
		}
		'toggle_dark' {
			state.dark = !state.dark
			ui2.set_stylesheet_dark(state.dark)
			state.status = if state.dark {
				'Dark variables active.'
			} else {
				'Light variables active.'
			}
		}
		'check' {
			state.checked = !state.checked
			state.status = if state.checked {
				'Checkbox on: :checked rule applies.'
			} else {
				'Checkbox off.'
			}
		}
		'scoped' {
			state.status = 'Scoped button pressed: inner sheet won over global.'
		}
		else {
			return
		}
	}
	ui2.refresh()
}

fn main() {
	global := ui2.parse_stylesheet(demo_sheet) or { panic(err) }
	dsl_rule := ui2.style_rule('Label.from-dsl', {
		'color':       '#0d9488'
		'font-weight': 'bold'
	}) or { panic(err) }
	mut rules := global.rules.clone()
	rules << dsl_rule
	ui2.set_global_stylesheet(ui2.Stylesheet{
		...global
		rules: rules
	})
	mut state := unsafe { demo_state }
	state.card_sheet = ui2.parse_stylesheet(card_sheet) or { panic(err) }
	ui2.run_window('Stylesheet Demo', demo_width, demo_height, build_demo_screen,
		handle_demo_event)
}
