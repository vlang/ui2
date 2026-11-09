module main

import ui2

// A responsive stylesheet demo: layout adapts in V code from bounds(), style
// adapts in the sheet from @media. Resize the window (or rotate a mobile
// device) and watch both halves move together.

const responsive_sheet = '
@accent: #7c3aed;

light {
	@bg: #faf8ff;
	@surface: #ffffff;
	@ink: #1e1b4b;
	@muted: #6d6a8a;
	@line: #ddd6fe;
}
dark {
	@bg: #14121f;
	@surface: #201d33;
	@ink: #ede9fe;
	@muted: #a8a3c7;
	@line: #4c4680;
}

Label { color: @ink; font-size: 14px; }
Label.hero { font-size: 30px; font-weight: bold; }
Label.sub { color: @muted; font-size: 14px; }
Label.card-title { font-size: 15px; font-weight: bold; }
Label.card-note { color: @muted; font-size: 13px; }
Label.readout { color: @muted; font-size: 12px; }

View.feature {
	background: @surface;
	border-radius: 12px;
	border-color: @line;
	border-width: 1px;
}
@container feature (min-width: 220px) {
	Label.card-title { font-size: 17px; }
}
@container feature (max-width: 180px) {
	Label.card-note { font-size: 11px; }
}

/* breakpoints: layout columns come from V, sizes from here */
@media (max-width: 560px) {
	Label.hero { font-size: 22px; }
	Label.sub { font-size: 12px; }
	Label.card-title { font-size: 13px; }
	View.feature { border-radius: 8px; }
}
@media (min-width: 900px) {
	Label.hero { font-size: 36px; }
	Label.card-title { font-size: 17px; }
}
@media (orientation: portrait) {
	Label.hero { font-size: 24px; }
}
@media (platform: ios), (platform: android) {
	View.feature { border-radius: 16px; }
}
'

struct ResponsiveDemo {
mut:
	dark   bool
	status string = 'Resize the window to cross the breakpoints.'
}

const responsive_state = &ResponsiveDemo{}

fn hoverable(el ui2.Element) ui2.Element {
	return ui2.Element{
		...el
		hoverable: true
	}
}

fn feature_card(id string, title string, note string, frame ui2.Rect) ui2.Element {
	return ui2.with_classes(ui2.view(id, frame, ui2.BoxStyle{}, [
		ui2.with_classes(ui2.label('${id}_t', title, ui2.rect(16, 14, 400, 24),
			ui2.TextStyle{}), 'card-title'),
		ui2.with_classes(ui2.label('${id}_n', note, ui2.rect(16, 42, 400, 60),
			ui2.TextStyle{}), 'card-note'),
	]), 'feature')
}

fn build_responsive_screen() ui2.Element {
	state := unsafe { responsive_state }
	b := ui2.bounds()
	w := if b.width > 0 { b.width } else { 760.0 }
	columns := if w < 560 {
		1
	} else if w < 900 {
		2
	} else {
		3
	}
	gap := 16.0
	margin := 24.0
	card_w := (w - margin * 2 - gap * f64(columns - 1)) / f64(columns)
	card_h := 120.0
	top := 150.0
	mut cards := []ui2.Element{cap: 3}
	titles := ['Media queries', 'Container queries', 'One engine']
	notes := [
		'Width, orientation, platform, pointer, resolution and color scheme gates.',
		'Cards restyle from their own frame, not the window.',
		'The same sheet drives native and custom renderers.',
	]
	for i in 0 .. 3 {
		col := i % columns
		row := i / columns
		if columns == 1 && i > 0 {
			// single column: stack the first card only, keep the demo compact
			continue
		}
		if columns == 2 && i > 1 {
			continue
		}
		cards << feature_card('feat_${i}', titles[i], notes[i], ui2.rect(margin +
			f64(col) * (card_w + gap), top + f64(row) * (card_h + gap), card_w, card_h))
	}
	screen_bg := if state.dark { u32(0x14121f) } else { u32(0xfaf8ff) }
	plural := if columns == 1 { '' } else { 's' }
	mut children := [
		ui2.with_classes(ui2.label('hero', 'Responsive u2ss', ui2.rect(margin, 24, w -
			margin * 2, 44), ui2.TextStyle{}), 'hero'),
		ui2.with_classes(ui2.label('sub', '${columns} column${plural} at ${w:.0f}px - layout in V, style in the sheet',
			ui2.rect(margin, 70, w - margin * 2, 22), ui2.TextStyle{}), 'sub'),
	]
	children << cards
	children << hoverable(ui2.button('toggle_dark', if state.dark { 'Light' } else { 'Dark' },
		ui2.rect(margin, top + card_h + gap + 20, 140, 38), ui2.BoxStyle{},
		ui2.TextStyle{}))
	children << ui2.with_classes(ui2.label('status', state.status, ui2.rect(margin,
		top + card_h + gap + 68, w - margin * 2, 22), ui2.TextStyle{}), 'readout')
	return ui2.screen(screen_bg, children)
}

fn handle_responsive_event(event string) {
	mut state := unsafe { responsive_state }
	match event {
		'toggle_dark' {
			state.dark = !state.dark
			ui2.set_stylesheet_dark(state.dark)
			state.status = if state.dark {
				'Dark variables active.'
			} else {
				'Light variables active.'
			}
		}
		else {
			return
		}
	}
	ui2.refresh()
}

fn main() {
	ui2.set_global_stylesheet(ui2.parse_stylesheet(responsive_sheet) or { panic(err) })
	ui2.run_window('Responsive Stylesheet', 760, 480, build_responsive_screen,
		handle_responsive_event)
}
