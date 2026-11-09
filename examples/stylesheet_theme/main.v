module main

import ui2

// A variable-driven theme studio: accents times modes, all from one sheet.
// The sheet declares every color as a variable; the app only swaps variable
// values and the dark flag, then re-applies.

const theme_accents = {
	'Blue':  ['#2563eb', '#1d4ed8']
	'Teal':  ['#0d9488', '#0f766e']
	'Rose':  ['#e11d48', '#be123c']
	'Amber': ['#d97706', '#b45309']
}

const theme_sheet = '
light {
	@bg: #f4f6f8;
	@surface: #ffffff;
	@ink: #172033;
	@muted: #64748b;
	@line: #cbd5e1;
}
dark {
	@bg: #10151f;
	@surface: #1a2230;
	@ink: #f1f5f9;
	@muted: #94a3b8;
	@line: #334155;
}

Label { color: @ink; font-size: 14px; }
Label.title { font-size: 22px; font-weight: bold; }
Label.sub { color: @muted; font-size: 13px; }
Label.preview-title { font-size: 16px; font-weight: bold; }
Label.check-note { color: @muted; font-size: 13px; }
Button {
	background: @accent;
	color: white;
	border-radius: 6px;
	font-size: 14px;
}
Button:hover { opacity: 0.92; }
Button:disabled { opacity: 0.4; }
Button.acc-Blue { background: #2563eb; }
Button.acc-Teal { background: #0d9488; }
Button.acc-Rose { background: #e11d48; }
Button.acc-Amber { background: #d97706; }
Button.acc { border-radius: 8px; }
Button.acc.picked {
	border-color: @ink;
	border-width: 3px;
}
Button.mode {
	background: @surface;
	color: @muted;
	border-color: @line;
	border-width: 1px;
	border-radius: 8px;
}
Button.mode.picked {
	background: @accent;
	color: white;
	border-width: 0px;
}
View.hero {
	background: linear-gradient(135deg, @accent, @accent-hover);
	border-radius: 12px;
}
View.preview {
	background: @surface;
	border-radius: 12px;
	border-color: @line;
	border-width: 1px;
}
Checkbox:checked { color: @accent; }
'

struct ThemeDemo {
mut:
	accent     string = 'Blue'
	mode       string = 'System'
	notify     bool
	count      int
	status     string = 'Pick an accent and a mode.'
	base_sheet ui2.Stylesheet
}

const theme_state = &ThemeDemo{}

fn hoverable(el ui2.Element) ui2.Element {
	return ui2.Element{
		...el
		hoverable: true
	}
}

fn theme_apply_sheet(state &ThemeDemo) {
	pair := theme_accents[state.accent] or { ['#2563eb', '#1d4ed8'] }
	mut vars := state.base_sheet.variables.clone()
	vars['@accent'] = pair[0]
	vars['@accent-hover'] = pair[1]
	ui2.set_global_stylesheet(ui2.Stylesheet{
		...state.base_sheet
		variables: vars
	})
}

fn theme_apply_mode(state &ThemeDemo) {
	match state.mode {
		'Light' {
			ui2.set_stylesheet_dark(false)
		}
		'Dark' {
			ui2.set_stylesheet_dark(true)
		}
		else {
			ui2.set_stylesheet_follow_system(true)
		}
	}
}

fn build_theme_screen() ui2.Element {
	state := unsafe { theme_state }
	screen_bg := if ui2.stylesheet_dark_mode() { u32(0x10151f) } else { u32(0xf4f6f8) }
	mut children := [
		ui2.with_classes(ui2.label('title', 'Theme Studio', ui2.rect(24, 16, 500, 28),
			ui2.TextStyle{}), 'title'),
		ui2.with_classes(ui2.label('sub', 'Accents times modes from one variable sheet',
			ui2.rect(24, 46, 500, 18), ui2.TextStyle{}), 'sub'),
	]
	mut x := 24.0
	for name in ['Blue', 'Teal', 'Rose', 'Amber'] {
		mut classes := ['acc', 'acc-${name}']
		if state.accent == name {
			classes << 'picked'
		}
		children << hoverable(ui2.with_classes(ui2.button('acc_${name}', name, ui2.rect(x,
			84, 130, 36), ui2.BoxStyle{}, ui2.TextStyle{}), ...classes))
		x += 142.0
	}
	for index, name in ['Light', 'Dark', 'System'] {
		mut classes := ['mode']
		if state.mode == name {
			classes << 'picked'
		}
		children << hoverable(ui2.with_classes(ui2.button('mode_${name}', name,
			ui2.rect(24.0 + f64(index) * 142.0, 132, 130, 36), ui2.BoxStyle{},
			ui2.TextStyle{}), ...classes))
	}
	children << ui2.view('hero', ui2.rect(24, 182, 592, 90), ui2.BoxStyle{}, [
		ui2.label('hero_t', '${state.accent} / ${state.mode}', ui2.rect(16, 14, 400,
			26), ui2.TextStyle{ color: 0xffffff, size: 16, bold: true }),
		ui2.label('hero_n', 'The hero gradient follows @accent through the sheet.',
			ui2.rect(16, 44, 560, 20), ui2.TextStyle{ color: 0xe0e7ff, size: 13 }),
	])
	children << ui2.view('preview', ui2.rect(24, 284, 592, 150), ui2.BoxStyle{}, [
		ui2.with_classes(ui2.label('p_t', 'Preview', ui2.rect(16, 12, 400, 24),
			ui2.TextStyle{}), 'preview-title'),
		hoverable(ui2.button('inc', 'Count: ${state.count}', ui2.rect(16, 44, 180, 36),
			ui2.BoxStyle{}, ui2.TextStyle{})),
		ui2.Element{
			...ui2.button('never', 'Disabled', ui2.rect(208, 44, 140, 36), ui2.BoxStyle{},
				ui2.TextStyle{})
			enabled: false
		},
		ui2.checkbox('notify', 'Accent checkbox', state.notify, ui2.rect(16, 92, 300,
			24), ui2.TextStyle{}),
	])
	children << ui2.with_classes(ui2.label('status', state.status, ui2.rect(24, 446, 592,
		22), ui2.TextStyle{}), 'check-note')
	return ui2.screen(screen_bg, children)
}

fn handle_theme_event(event string) {
	mut state := unsafe { theme_state }
	if event.starts_with('acc_') {
		state.accent = event[4..]
		theme_apply_sheet(state)
		state.status = 'Accent: ${state.accent}.'
	} else {
		match event {
			'mode_Light', 'mode_Dark', 'mode_System' {
				state.mode = event[5..]
				theme_apply_mode(state)
				state.status = 'Mode: ${state.mode}.'
			}
			'inc' {
				state.count++
				state.status = 'Count is ${state.count}.'
			}
			'notify' {
				state.notify = !state.notify
				state.status = if state.notify { 'Checked.' } else { 'Unchecked.' }
			}
			else {
				return
			}
		}
	}
	ui2.refresh()
}

fn main() {
	base := ui2.parse_stylesheet(theme_sheet) or { panic(err) }
	mut state := unsafe { theme_state }
	state.base_sheet = base
	theme_apply_sheet(state)
	ui2.run_window('Theme Studio', 640, 500, build_theme_screen, handle_theme_event)
}
