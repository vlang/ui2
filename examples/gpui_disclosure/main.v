module main

import math
import ui2

// A gallery of the disclosure components, GPUI Kit's Accordion and Carousel.
// Every component is controlled: the state below is the only state, each build
// derives the configs from it, and on_event decodes actions against those same
// configs before rebuilding. Tab moves the keyboard between the components.

const window_width = 1200
const window_height = 820
const col_a = 24.0
const col_b = 612.0
const col_a_width = 552.0
const col_b_width = 564.0
const autoplay_seconds = 3.0

@[heap]
struct Gallery {
mut:
	dark         bool
	focus        string // which component the keyboard drives: '', 'faq', 'hero', 'shelf', 'tower'
	faq_open     []int = [0]
	faq_hover    int   = -1
	faq_focus    int   = -1
	prefs_open   []int = [0, 2]
	prefs_hover  int   = -1
	guide_open   []int = [1]
	guide_hover  int   = -1
	inner_open   []int = [0]
	inner_hover  int   = -1
	hero         int
	hero_offset  f64
	hero_drag    ui2.CarouselDrag
	hero_hovered bool
	playing      bool = true
	timer        ui2.TimerId
	shelf        int
	tower        int
	fill         int
	message      string = 'Click a title, an arrow or a dot. Tab moves the keyboard between components.'
}

const gallery = &Gallery{}

fn app() &Gallery {
	return unsafe { gallery }
}

fn theme_of(g &Gallery) ui2.ComponentTheme {
	return ui2.component_theme(g.dark)
}

// ── Content ────────────────────────────────────────────────────────

fn paragraph(text string, width f64, theme ui2.ComponentTheme) ui2.Element {
	style := ui2.TextStyle{
		color:  theme.muted_foreground
		size:   13
		lines:  0
		valign: .top
	}
	lines := ui2.wrap_text_to_width(text, style, width)
	return ui2.label('', text, ui2.rect(0, 0, width, f64(lines.len) * 18 + 2), style)
}

struct SlideSpec {
	title string
	text  string
	icon  string
	light u32
	dark  u32
	ink   u32
}

const slide_specs = [
	SlideSpec{'Mountains', 'Trails above the tree line', 'map', 0xdbeafe, 0x1e3a5f, 0x1d4ed8},
	SlideSpec{'Forest', 'Cabins under the pines', 'house', 0xdcfce7, 0x14412a, 0x15803d},
	SlideSpec{'Coast', 'Cliffs, coves and tide pools', 'globe', 0xfef3c7, 0x4a3a10, 0xb45309},
	SlideSpec{'Desert', 'Dunes at sunrise', 'sun.max', 0xffedd5, 0x4a2a12, 0xc2410c},
	SlideSpec{'Lakes', 'Paddle across still water', 'cloud', 0xede9fe, 0x2e2257, 0x6d28d9},
]

fn slide_card(spec SlideSpec, compact bool, theme ui2.ComponentTheme, dark bool) ui2.Element {
	bg := if dark { spec.dark } else { spec.light }
	ink := if dark { 0xf8fafc } else { spec.ink }
	sub := if dark { theme.muted_foreground } else { 0x475569 }
	if compact {
		return ui2.view('', ui2.rect(0, 0, 0, 0), ui2.BoxStyle{
			bg:     bg
			radius: 10
		}, [
			ui2.Element{
				...ui2.image('', 'symbol:${spec.icon}', ui2.rect(14, 14, 22, 22))
				text_style: ui2.TextStyle{
					color: ink
				}
			},
			ui2.label('', spec.title, ui2.rect(14, 46, 120, 22), ui2.TextStyle{
				color: ink
				size:  15
				bold:  true
			}),
			ui2.label('', spec.text, ui2.rect(14, 68, 124, 34), ui2.TextStyle{
				color:  sub
				size:   12
				lines:  2
				valign: .top
			}),
		])
	}
	return ui2.view('', ui2.rect(0, 0, 0, 0), ui2.BoxStyle{
		bg:     bg
		radius: 12
	}, [
		ui2.Element{
			...ui2.image('', 'symbol:${spec.icon}', ui2.rect(24, 24, 32, 32))
			text_style: ui2.TextStyle{
				color: ink
			}
		},
		ui2.label('', spec.title, ui2.rect(24, 100, 400, 34), ui2.TextStyle{
			color: ink
			size:  26
			bold:  true
		}),
		ui2.label('', spec.text, ui2.rect(24, 136, 400, 22), ui2.TextStyle{
			color: sub
			size:  14
		}),
	])
}

// ── Placement ──────────────────────────────────────────────────────

// tallest is the most room a stacked accordion takes with each of its items
// open alone (or all of them, when several may be open), so the components
// below it never move as it opens and closes.
fn tallest(config ui2.AccordionConfig) f64 {
	if config.multiple {
		all := []int{len: config.items.len, init: index}
		return (ui2.accordion_stack_layout(ui2.AccordionConfig{ ...config, open: all }) or {
			panic(err)
		}).height
	}
	mut most := 0.0
	for index in 0 .. config.items.len {
		layout := ui2.accordion_stack_layout(ui2.AccordionConfig{ ...config, open: [index] }) or {
			panic(err)
		}
		if layout.height > most {
			most = layout.height
		}
	}
	return most
}

// lower_y is where the second row of accordions starts, under the FAQ.
fn lower_y(g &Gallery) f64 {
	return 124 + tallest(faq_config(g)) + 28
}

// ── Configs, shared by the build and by on_event ───────────────────

fn faq_config(g &Gallery) ui2.AccordionConfig {
	theme := theme_of(g)
	body := ui2.accordion_body_width(col_a_width, .medium, true)
	return ui2.AccordionConfig{
		id:      'faq'
		frame:   ui2.rect(col_a, 124, col_a_width, 0)
		layout:  .stack
		open:    g.faq_open
		hovered: g.faq_hover
		focused: if g.focus == 'faq' { g.faq_focus } else { -1 }
		theme:   theme
		items:   [
			ui2.AccordionItem{
				title:   'Is it accessible?'
				icon:    'questionmark.circle'
				content: paragraph('Every title row is a button that reports whether it is expanded. Up, Down, Home and End move between rows and Enter or Space opens one.',
					body, theme)
			},
			ui2.AccordionItem{
				title:   'Can several sections be open?'
				icon:    'square.stack.3d.up'
				content: paragraph('Not here: opening one closes the others, and clicking the open one closes it too. Set multiple to keep any number open, as the panel beside this one does.',
					body, theme)
			},
			ui2.AccordionItem{
				title:   'Does it animate?'
				icon:    'arrow.up.and.down'
				content: paragraph('accordion_animate glides the rows below and unrolls the panel that opens.',
					body, theme)
			},
			ui2.AccordionItem{
				title:   'Billing (disabled)'
				icon:    'creditcard'
				enabled: false
			},
		]
	}
}

fn prefs_config(g &Gallery) ui2.AccordionConfig {
	theme := theme_of(g)
	width := (col_a_width - 24) / 2
	body := ui2.accordion_body_width(width, .small, false)
	return ui2.AccordionConfig{
		id:       'prefs'
		frame:    ui2.rect(col_a, lower_y(g) + 24, width, 0)
		layout:   .stack
		open:     g.prefs_open
		multiple: true
		bordered: false
		hovered:  g.prefs_hover
		size:     .small
		theme:    theme
		items:    [
			ui2.AccordionItem{
				title:   'Notifications'
				icon:    'bell'
				content: paragraph('Mentions and replies only.', body, theme)
			},
			ui2.AccordionItem{
				title:   'Privacy'
				icon:    'lock'
				content: paragraph('Your profile is visible to your team.', body, theme)
			},
			ui2.AccordionItem{
				title:   'Appearance'
				icon:    'paintbrush'
				content: paragraph('Follows the system theme.', body, theme)
			},
		]
	}
}

fn inner_config(g &Gallery, width f64) ui2.AccordionConfig {
	theme := theme_of(g)
	body := ui2.accordion_body_width(width, .small, true)
	return ui2.AccordionConfig{
		id:      'inner'
		frame:   ui2.rect(0, 0, width, 0)
		layout:  .stack
		open:    g.inner_open
		hovered: g.inner_hover
		size:    .small
		theme:   theme
		items:   [
			ui2.AccordionItem{
				title:   'Install'
				content: paragraph('v install ui2', body, theme)
			},
			ui2.AccordionItem{
				title:   'Run'
				content: paragraph('v run main.v', body, theme)
			},
		]
	}
}

fn guide_config(g &Gallery) ui2.AccordionConfig {
	theme := theme_of(g)
	width := (col_a_width - 24) / 2
	body := ui2.accordion_body_width(width, .large, true)
	inner := inner_config(g, body)
	inner_height := ui2.accordion_stack_layout(inner) or { panic(err) }.height
	return ui2.AccordionConfig{
		id:      'guide'
		frame:   ui2.rect(col_a + width + 24, lower_y(g) + 24, width, 0)
		layout:  .stack
		open:    g.guide_open
		hovered: g.guide_hover
		size:    .large
		theme:   theme
		items:   [
			ui2.AccordionItem{
				title:   'Overview'
				content: paragraph('A large accordion.', body, theme)
			},
			ui2.AccordionItem{
				title:   'Getting started'
				content: ui2.accordion(ui2.AccordionConfig{
					...inner
					frame: ui2.rect(0, 0, body, inner_height)
				}) or { panic(err) }
			},
		]
	}
}

// fill_config is the accordion's original layout, which keeps one item open
// and gives it all the room the other headers leave. Its headers emit the
// actions the items name.
fn fill_config(g &Gallery) ui2.AccordionConfig {
	theme := theme_of(g)
	y := lower_y(g) + 24 + math.max(tallest(prefs_config(g)), tallest(guide_config(g))) + 52
	names := ['Profile', 'Alerts', 'Security']
	notes := ['Your public profile.', 'Which alerts you receive.', 'Passwords and sessions.']
	mut items := []ui2.AccordionItem{}
	for index, name in names {
		items << ui2.AccordionItem{
			id:        'fill-${index}'
			title:     name
			action_id: 'fill:${index}'
			content:   ui2.label('', notes[index], ui2.rect(0, 0, 0, 0), ui2.TextStyle{
				color: theme.foreground
				size:  14
				align: .center
			})
		}
	}
	return ui2.AccordionConfig{
		id:                       'fill'
		frame:                    ui2.rect(col_a, y, col_a_width, window_height - 24 - y)
		current:                  g.fill
		min_space:                96
		box:                      ui2.BoxStyle{
			bg:     theme.muted
			radius: 10
		}
		header_box:               ui2.BoxStyle{
			bg:     theme.muted
			radius: 10
		}
		active_header_box:        ui2.BoxStyle{
			bg:     theme.primary
			radius: 10
		}
		header_text_style:        ui2.TextStyle{
			color: theme.foreground
			size:  14
			align: .center
		}
		active_header_text_style: ui2.TextStyle{
			color: theme.primary_foreground
			size:  14
			bold:  true
			align: .center
		}
		items:                    items
	}
}

fn hero_slides(g &Gallery, compact bool) []ui2.Element {
	theme := theme_of(g)
	return slide_specs.map(slide_card(it, compact, theme, g.dark))
}

fn hero_config(g &Gallery) ui2.CarouselConfig {
	return ui2.CarouselConfig{
		id:          'hero'
		frame:       ui2.rect(col_b, 124, col_b_width, 236)
		index:       g.hero
		loop:        true
		controls:    .outside
		indicators:  .dots
		draggable:   true
		drag_offset: g.hero_offset
		focused:     g.focus == 'hero'
		box:         ui2.BoxStyle{
			transparent: true
			radius:      12
		}
		theme:       theme_of(g)
		slides:      hero_slides(g, false)
	}
}

fn shelf_config(g &Gallery) ui2.CarouselConfig {
	return ui2.CarouselConfig{
		id:         'shelf'
		frame:      ui2.rect(col_b, 408, col_b_width, 150)
		index:      g.shelf
		per_view:   3
		gap:        12
		controls:   .outside
		indicators: .numbers
		focused:    g.focus == 'shelf'
		box:        ui2.BoxStyle{
			transparent: true
			radius:      10
		}
		size:       .small
		theme:      theme_of(g)
		slides:     hero_slides(g, true)
	}
}

fn tower_config(g &Gallery) ui2.CarouselConfig {
	return ui2.CarouselConfig{
		id:         'tower'
		frame:      ui2.rect(col_b, 606, 300, 190)
		index:      g.tower
		direction:  .bottom
		controls:   .inside
		indicators: .dots
		focused:    g.focus == 'tower'
		box:        ui2.BoxStyle{
			transparent: true
			radius:      12
		}
		size:       .small
		theme:      theme_of(g)
		slides:     hero_slides(g, true)
	}
}

// ── Build ──────────────────────────────────────────────────────────

fn section(text string, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, 300, 24), ui2.TextStyle{
		color: theme.foreground
		size:  16
		bold:  true
	})
}

fn caption(text string, x f64, y f64, width f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, width, 20), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn build() ui2.Element {
	g := app()
	theme := theme_of(g)
	mut children := []ui2.Element{}
	children << ui2.label('', 'Disclosure components', ui2.rect(col_a, 18, 600, 34), ui2.TextStyle{
		color: theme.foreground
		size:  24
		bold:  true
	})
	children << ui2.styled_button(
		id:      'theme'
		frame:   ui2.rect(window_width - 24 - 136, 20, 136, 32)
		label:   if g.dark { 'Light theme' } else { 'Dark theme' }
		icon:    'paintpalette'
		outline: true
		theme:   theme
	) or { panic(err) }

	// Accordion
	children << section('Accordion', col_a, 72, theme)
	children << caption('One open at a time, bordered, icons, a disabled item, keyboard focus',
		col_a, 100, col_a_width, theme)
	children << ui2.accordion(faq_config(g)) or { panic(err) }
	half := (col_a_width - 24) / 2
	children << caption('Multiple open, borderless, small', col_a, lower_y(g), half, theme)
	children << ui2.accordion(prefs_config(g)) or { panic(err) }
	children << caption('Large, with a nested accordion', col_a + half + 24, lower_y(g), half,
		theme)
	children << ui2.accordion(guide_config(g)) or { panic(err) }
	fill := fill_config(g)
	children << caption('The original fill layout: the open item takes the space left',
		col_a, fill.frame.y - 24, col_a_width, theme)
	children << ui2.accordion(fill) or { panic(err) }

	// Carousel
	children << section('Carousel', col_b, 72, theme)
	children << caption('Loops, outside controls, dots, drag, autoplay that pauses on hover',
		col_b, 100, 420, theme)
	children << ui2.styled_button(
		id:      'autoplay'
		frame:   ui2.rect(col_b + col_b_width - 92, 70, 92, 26)
		label:   if g.playing { 'Pause' } else { 'Play' }
		icon:    if g.playing { 'pause.fill' } else { 'play.fill' }
		variant: .ghost
		size:    .small
		theme:   theme
	) or { panic(err) }
	children << ui2.with_hover(ui2.carousel(hero_config(g)) or { panic(err) })
	children << caption('Three per view with a gap, numbered positions, stops at both ends',
		col_b, 384, col_b_width, theme)
	children << ui2.carousel(shelf_config(g)) or { panic(err) }
	children << caption('Vertical, controls over the slides', col_b, 582, 300, theme)
	children << ui2.carousel(tower_config(g)) or { panic(err) }
	children << ui2.label('', 'Tab: move the keyboard between the FAQ and the carousels. Arrows, Home and End drive the focused one; Enter or Space opens a FAQ row.',
		ui2.rect(col_b + 324, 606, col_b_width - 324, 72), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   12
			lines:  4
			valign: .top
		})
	children << ui2.label('', g.message, ui2.rect(col_b + 324, 692, col_b_width - 324, 104),
		ui2.TextStyle{
			color:  theme.foreground
			size:   13
			lines:  4
			valign: .top
		})
	return ui2.screen(theme.background, children)
}

// ── Events ─────────────────────────────────────────────────────────

// set_hero moves the hero carousel to index, sliding from where it was.
fn set_hero(mut g Gallery, index int) {
	before := hero_config(g)
	g.hero = index
	g.hero_offset = 0
	ui2.carousel_animate(before, hero_config(g)) or {}
}

fn set_shelf(mut g Gallery, index int) {
	before := shelf_config(g)
	g.shelf = index
	ui2.carousel_animate(before, shelf_config(g)) or {}
}

fn set_tower(mut g Gallery, index int) {
	before := tower_config(g)
	g.tower = index
	ui2.carousel_animate(before, tower_config(g)) or {}
}

// schedule_autoplay advances the hero carousel every few seconds while playing,
// skipping a tick while the pointer is over it or a drag is under way.
fn schedule_autoplay() {
	mut g := app()
	ui2.cancel_timer(g.timer)
	if !g.playing {
		return
	}
	g.timer = ui2.after(autoplay_seconds, fn () {
		mut g := app()
		if g.playing && !g.hero_hovered && !g.hero_drag.active {
			set_hero(mut g, ui2.carousel_autoplay_index(hero_config(g)))
		}
		schedule_autoplay()
	})
}

fn accordion_event(mut g Gallery, action string) bool {
	if open := ui2.accordion_open_from_action(faq_config(g), action) {
		before := faq_config(g)
		g.faq_open = open
		ui2.accordion_animate(before, faq_config(g)) or {}
		g.message = 'FAQ open: ${open}.'
	} else if hovered := ui2.accordion_hover_from_event(faq_config(g), action) {
		g.faq_hover = hovered
	} else if open := ui2.accordion_open_from_action(prefs_config(g), action) {
		before := prefs_config(g)
		g.prefs_open = open
		ui2.accordion_animate(before, prefs_config(g)) or {}
		g.message = 'Preferences open: ${open}.'
	} else if hovered := ui2.accordion_hover_from_event(prefs_config(g), action) {
		g.prefs_hover = hovered
	} else if open := ui2.accordion_open_from_action(guide_config(g), action) {
		before := guide_config(g)
		g.guide_open = open
		ui2.accordion_animate(before, guide_config(g)) or {}
		g.message = 'Guide open: ${open}.'
	} else if hovered := ui2.accordion_hover_from_event(guide_config(g), action) {
		g.guide_hover = hovered
	} else if open := ui2.accordion_open_from_action(inner_config(g, 0), action) {
		before := guide_config(g)
		g.inner_open = open
		ui2.accordion_animate(before, guide_config(g)) or {}
		g.message = 'Nested accordion open: ${open}.'
	} else if hovered := ui2.accordion_hover_from_event(inner_config(g, 0), action) {
		g.inner_hover = hovered
	} else {
		return false
	}
	return true
}

fn carousel_event(mut g Gallery, action string) bool {
	if index := ui2.carousel_index_from_action(hero_config(g), action) {
		set_hero(mut g, index)
		g.message = 'Hero slide ${index + 1}.'
	} else if drag := ui2.carousel_drag_event(hero_config(g), g.hero_drag, action) {
		g.hero_drag = drag.drag
		if drag.phase == .end {
			set_hero(mut g, drag.index)
			g.message = 'Dragged to slide ${drag.index + 1}.'
		} else {
			g.hero_offset = drag.offset
		}
	} else if index := ui2.carousel_index_from_action(shelf_config(g), action) {
		set_shelf(mut g, index)
		g.message = 'Shelf position ${index + 1}.'
	} else if index := ui2.carousel_index_from_action(tower_config(g), action) {
		set_tower(mut g, index)
		g.message = 'Vertical slide ${index + 1}.'
	} else if pointer := ui2.parse_pointer_event(action) {
		if pointer.action != 'hero' || pointer.phase !in ['enter', 'leave'] {
			return false
		}
		g.hero_hovered = pointer.phase == 'enter'
	} else {
		return false
	}
	return true
}

fn on_event(action string) {
	mut g := app()
	if accordion_event(mut g, action) || carousel_event(mut g, action) {
		ui2.refresh()
		return
	}
	match action {
		'theme' {
			g.dark = !g.dark
		}
		'autoplay' {
			g.playing = !g.playing
			g.message = if g.playing { 'Autoplay on.' } else { 'Autoplay paused.' }
			schedule_autoplay()
		}
		else {
			if action.starts_with('fill:') {
				g.fill = action['fill:'.len..].int()
				g.message = 'Fill layout: item ${g.fill + 1}.'
				ui2.refresh()
				return
			}
			// Pointer reports and component actions the decoders turned down (the
			// current indicator, say) change nothing.
			return
		}
	}
	ui2.refresh()
}

// Components cannot capture keys, so the application routes them to whichever
// component it considers focused, through the components' key helpers.
fn on_key(event ui2.KeyEvent) {
	if event.cmd || event.ctrl || event.alt {
		return
	}
	mut g := app()
	if event.code == .tab {
		order := ['', 'faq', 'hero', 'shelf', 'tower']
		at := order.index(g.focus)
		step := if event.shift { order.len - 1 } else { 1 }
		g.focus = order[(at + step) % order.len]
		if g.focus == 'faq' && g.faq_focus < 0 {
			g.faq_focus = 0
		}
		g.message = if g.focus.len == 0 { 'Keyboard released.' } else { 'Keyboard on ${g.focus}.' }
	} else if g.focus == 'faq' {
		if focused := ui2.accordion_focus_after_key(faq_config(g), event.code) {
			g.faq_focus = focused
		} else if open := ui2.accordion_open_after_key(faq_config(g), event.code) {
			before := faq_config(g)
			g.faq_open = open
			ui2.accordion_animate(before, faq_config(g)) or {}
		} else {
			return
		}
	} else if g.focus == 'hero' {
		set_hero(mut g, ui2.carousel_index_after_key(hero_config(g), event.code) or { return })
	} else if g.focus == 'shelf' {
		set_shelf(mut g, ui2.carousel_index_after_key(shelf_config(g), event.code) or { return })
	} else if g.focus == 'tower' {
		set_tower(mut g, ui2.carousel_index_after_key(tower_config(g), event.code) or { return })
	} else {
		return
	}
	ui2.consume_key()
	ui2.refresh()
}

fn main() {
	ui2.on_key_event(on_key)
	schedule_autoplay()
	ui2.run_window('ui2 disclosure components', window_width, window_height, build, on_event)
}
