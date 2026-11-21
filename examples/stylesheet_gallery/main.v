module main

import ui2

const gallery_width = 1000
const gallery_height = 700
const gallery_sheet_source = $embed_file('gallery.vss').to_string()

const gallery_accents = [
	['#2563eb', '#1d4ed8'],
	['#0d9488', '#0f766e'],
	['#e11d48', '#be123c'],
	['#d97706', '#b45309'],
]

const gallery_nav = ['Buttons', 'State', 'Cards', 'Queries']

struct GalleryDemo {
mut:
	section    string = 'Buttons'
	count      int
	notify     bool
	dark       bool
	accent     int
	status     string = 'Welcome to the stylesheet gallery.'
	base_sheet ui2.Stylesheet
	nav_sheet  ui2.Stylesheet
}

const gallery_state = &GalleryDemo{}

fn hoverable(el ui2.Element) ui2.Element {
	return ui2.Element{
		...el
		hoverable: true
	}
}

fn nav_button(id string, title string, frame ui2.Rect, active bool) ui2.Element {
	mut classes := ['nav']
	if active {
		classes << 'active'
	}
	return hoverable(ui2.with_classes(ui2.button(id, title, frame, ui2.BoxStyle{},
		ui2.TextStyle{}), ...classes))
}

fn build_gallery_screen() ui2.Element {
	state := unsafe { gallery_state }
	// The screen background is builder-owned (screen() takes a plain color),
	// so it follows the mode here; everything else comes from the sheet.
	screen_bg := if state.dark { u32(0x0f1420) } else { u32(0xeef1f6) }
	return ui2.screen(screen_bg, [
		ui2.view('topbar', ui2.rect(0, 0, gallery_width, 64), ui2.BoxStyle{}, [
			ui2.with_classes(ui2.label('title', 'Stylesheet Gallery', ui2.rect(24, 10,
				500, 28), ui2.TextStyle{}), 'title'),
			ui2.with_classes(ui2.label('platform', 'vss on ${ui2.stylesheet_platform_name()} - one sheet, every backend',
				ui2.rect(24, 38, 500, 18), ui2.TextStyle{}), 'subtitle'),
			hoverable(ui2.button('toggle_dark', if state.dark { 'Light' } else { 'Dark' },
				ui2.rect(gallery_width - 320, 13, 140, 38), ui2.BoxStyle{}, ui2.TextStyle{})),
			hoverable(ui2.with_classes(ui2.button('cycle_accent', 'Accent ${state.accent + 1}/4',
				ui2.rect(gallery_width - 164, 13, 140, 38), ui2.BoxStyle{}, ui2.TextStyle{}),
				'ghost')),
		]),
		ui2.with_stylesheet(ui2.view('sidebar', ui2.rect(16, 80, 190, 536), ui2.BoxStyle{},
			gallery_nav_buttons(state)), state.nav_sheet),
		ui2.view('content', ui2.rect(222, 80, 762, 536), ui2.BoxStyle{},
			build_gallery_section(state)),
		ui2.with_classes(ui2.label('status', gallery_status(state), ui2.rect(16, 628, 968,
			56), ui2.TextStyle{}), 'readout'),
	])
}

fn gallery_nav_buttons(state &GalleryDemo) []ui2.Element {
	mut buttons := []ui2.Element{cap: gallery_nav.len}
	for index, name in gallery_nav {
		buttons << nav_button('nav_${name}', name, ui2.rect(12, 12 + index * 52, 166, 40),
			state.section == name)
	}
	return buttons
}

fn build_gallery_section(state &GalleryDemo) []ui2.Element {
	match state.section {
		'State' {
			return gallery_state_section(state)
		}
		'Cards' {
			return gallery_cards_section(state)
		}
		'Queries' {
			return gallery_queries_section()
		}
		else {
			return gallery_buttons_section(state)
		}
	}
}

fn gallery_buttons_section(state &GalleryDemo) []ui2.Element {
	return [
		ui2.with_classes(ui2.label('h2', 'Buttons', ui2.rect(0, 0, 700, 26), ui2.TextStyle{}),
			'h2'),
		hoverable(ui2.with_classes(ui2.button('inc', 'Count: ${state.count}', ui2.rect(0,
			38, 200, 38), ui2.BoxStyle{}, ui2.TextStyle{}), 'primary')),
		hoverable(ui2.with_classes(ui2.button('reset', 'Reset', ui2.rect(212, 38, 140,
			38), ui2.BoxStyle{}, ui2.TextStyle{}), 'ghost')),
		hoverable(ui2.with_classes(ui2.button('boom', 'Danger', ui2.rect(364, 38, 140,
			38), ui2.BoxStyle{}, ui2.TextStyle{}), 'danger')),
		ui2.Element{
			...ui2.button('never', 'Disabled', ui2.rect(516, 38, 140, 38), ui2.BoxStyle{},
				ui2.TextStyle{})
			enabled: false
		},
		ui2.with_classes(ui2.label('hint', 'Hover, press and disable states all come from the sheet. The nav on the left is class-driven.',
			ui2.rect(0, 90, 700, 40), ui2.TextStyle{}), 'subtitle'),
	]
}

fn gallery_state_section(state &GalleryDemo) []ui2.Element {
	return [
		ui2.with_classes(ui2.label('h2', 'State', ui2.rect(0, 0, 700, 26), ui2.TextStyle{}),
			'h2'),
		ui2.checkbox('notify', 'Notify me (accent when checked)', state.notify, ui2.rect(0,
			38, 340, 28), ui2.TextStyle{}),
		hoverable(ui2.button('toggle_dark2', if state.dark {
			'Switch to light'
		} else {
			'Switch to dark'
		},
			ui2.rect(0, 78, 200, 38), ui2.BoxStyle{}, ui2.TextStyle{})),
		ui2.with_classes(ui2.label('dsl', 'This badge is styled from V code via the DSL constructor.',
			ui2.rect(0, 130, 700, 22), ui2.TextStyle{}), 'dsl-badge', 'live-dsl'),
	]
}

fn gallery_card(id string, title string, note string, action string, frame ui2.Rect) ui2.Element {
	return ui2.with_classes(ui2.view(id, frame, ui2.BoxStyle{}, [
		ui2.with_classes(ui2.label('${id}_title', title, ui2.rect(16, 12, 400, 24),
			ui2.TextStyle{}), 'card-title'),
		ui2.with_classes(ui2.label('${id}_note', note, ui2.rect(16, 40, 400, 60),
			ui2.TextStyle{}), 'card-note'),
		hoverable(ui2.button(action, 'Run', ui2.rect(16, 108, 160, 36), ui2.BoxStyle{},
			ui2.TextStyle{})),
	]), 'card')
}

fn gallery_cards_section(state &GalleryDemo) []ui2.Element {
	_ = state
	return [
		ui2.with_classes(ui2.label('h2', 'Container queries', ui2.rect(0, 0, 700, 26),
			ui2.TextStyle{}), 'h2'),
		gallery_card('card_wide', 'Wide card', 'At 320px the container query grows this title.',
			'run_wide', ui2.rect(0, 38, 320, 160)),
		gallery_card('card_narrow', 'Narrow card', 'At 220px the boosted 16px title applies.',
			'run_narrow', ui2.rect(332, 38, 220, 160)),
		ui2.with_classes(ui2.label('hint', 'Both cards share one sheet; only the frame widths differ.',
			ui2.rect(0, 210, 700, 22), ui2.TextStyle{}), 'subtitle'),
	]
}

fn gallery_queries_section() []ui2.Element {
	b := ui2.bounds()
	orientation := if b.width >= b.height { 'landscape' } else { 'portrait' }
	pointer := if ui2.stylesheet_is_coarse_pointer() { 'coarse' } else { 'fine' }
	mode := if ui2.stylesheet_dark_mode() { 'dark' } else { 'light' }
	return [
		ui2.with_classes(ui2.label('h2', 'Live queries', ui2.rect(0, 0, 700, 26),
			ui2.TextStyle{}), 'h2'),
		ui2.with_classes(ui2.label('q1', 'orientation: ${orientation} (${b.width:.0f}x${b.height:.0f}) - resize the window',
			ui2.rect(0, 38, 700, 22), ui2.TextStyle{}), 'readout'),
		ui2.with_classes(ui2.label('q2', 'platform: ${ui2.stylesheet_platform_name()} - pointer: ${pointer} - scheme: ${mode}',
			ui2.rect(0, 64, 700, 22), ui2.TextStyle{}), 'readout'),
		ui2.with_classes(ui2.label('q3', 'resolution: ${ui2.stylesheet_live_dpi():.1f}dppx - shrink below 860px to restyle the header',
			ui2.rect(0, 90, 700, 22), ui2.TextStyle{}), 'readout'),
	]
}

fn gallery_status(state &GalleryDemo) string {
	b := ui2.bounds()
	orientation := if b.width >= b.height { 'landscape' } else { 'portrait' }
	mode := if ui2.stylesheet_dark_mode() { 'dark' } else { 'light' }
	return '${state.status} | ${orientation} ${b.width:.0f}x${b.height:.0f} ${ui2.stylesheet_platform_name()} ${ui2.stylesheet_live_dpi():.1f}x ${mode}'
}

fn gallery_apply_sheet(state &GalleryDemo) {
	mut vars := state.base_sheet.variables.clone()
	vars['@accent'] = gallery_accents[state.accent][0]
	vars['@accent-hover'] = gallery_accents[state.accent][1]
	ui2.set_global_stylesheet(ui2.Stylesheet{
		...state.base_sheet
		variables: vars
	})
}

fn handle_gallery_event(event string) {
	mut state := unsafe { gallery_state }
	if event.starts_with('nav_') {
		state.section = event[4..]
		state.status = 'Section: ${state.section}.'
	} else {
		match event {
			'inc' {
				state.count++
				state.status = 'Count is ${state.count}.'
			}
			'reset' {
				state.count = 0
				state.status = 'Counter reset.'
			}
			'boom' {
				state.status = 'Danger pressed (nothing breaks).'
			}
			'notify' {
				state.notify = !state.notify
				state.status = if state.notify { 'Notifications on.' } else { 'Notifications off.' }
			}
			'toggle_dark', 'toggle_dark2' {
				state.dark = !state.dark
				ui2.set_stylesheet_dark(state.dark)
				state.status = if state.dark {
					'Dark variables active.'
				} else {
					'Light variables active.'
				}
			}
			'cycle_accent' {
				state.accent = (state.accent + 1) % gallery_accents.len
				gallery_apply_sheet(state)
				state.status = 'Accent ${state.accent + 1}/4.'
			}
			'run_wide', 'run_narrow' {
				state.status = 'Card action: ${event}.'
			}
			else {
				return
			}
		}
	}
	ui2.refresh()
}

fn main() {
	base := ui2.parse_stylesheet(gallery_sheet_source) or { panic(err) }
	dsl_rule := ui2.style_rule('Label.live-dsl', {
		'color':       '#0d9488'
		'font-weight': 'bold'
	}) or { panic(err) }
	mut rules := base.rules.clone()
	rules << dsl_rule
	base_with_dsl := ui2.Stylesheet{
		...base
		rules: rules
	}
	mut state := unsafe { gallery_state }
	state.base_sheet = base_with_dsl
	state.nav_sheet = ui2.parse_stylesheet('Button.nav { border-radius: 10px; }') or {
		panic(err)
	}
	gallery_apply_sheet(state)
	ui2.run_window('Stylesheet Gallery', gallery_width, gallery_height, build_gallery_screen,
		handle_gallery_event)
}
