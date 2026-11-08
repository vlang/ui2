module main

import ui2

// A gallery of the color picker: inline panels showing each tab, and the
// swatch, icon and field triggers that open the panel in a popover. The
// application owns every color. Each picker's events are decoded by
// color_picker_event against the config it was built with, and on_key_event
// adds arrow-key nudging and Escape.

const window_width = 960
const window_height = 800

const theme = ui2.component_theme(false)

// Picker is the state the application keeps for one picker.
struct Picker {
mut:
	value    ui2.ColorHsva
	empty    bool
	hex_text ?string
	preview  ?ui2.ColorHsva
	panel    ui2.ColorPickerPanel
	open     bool
	focused  ?ui2.ColorPickerPart
}

@[heap]
struct ColorDemo {
mut:
	spectrum Picker = Picker{
		value: ui2.color_from_rgb(0x3b82f6)
	}
	palette  Picker = Picker{
		value: ui2.color_from_rgb(0xef4444)
		panel: .palette
	}
	sliders  Picker = Picker{
		value: ui2.color_from_rgba(0x14b8a6, 0.6)
		panel: .sliders
	}
	// The field's popover starts open, so the gallery shows one at once.
	theme_tint Picker = Picker{
		value: ui2.color_from_rgb(0x8b5cf6)
		open:  true
	}
	background Picker = Picker{
		value: ui2.color_from_rgb(0xfef3c7)
	}
	text_color Picker = Picker{
		value: ui2.color_from_rgb(0x7c2d12)
	}
	accent     Picker = Picker{
		empty: true
		value: ui2.color_from_rgb(0x22c55e)
	}
	// The picker arrow keys go to, and the field to put back after a commit.
	active    string = 'spectrum'
	sync_id   string
	sync_text string
	message   string = 'Drag the area or a slider, click a swatch, or type a hex value.'
}

const demo = &ColorDemo{}

// ── Configurations, shared by the build and the event handlers ──────

fn base_config(id string, p Picker) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		id:           id
		value:        p.value
		empty:        p.empty
		hex_text:     p.hex_text
		preview:      p.preview
		panel:        p.panel
		open:         p.open
		focused_part: p.focused
		window:       ui2.bounds()
		theme:        theme
	}
}

fn spectrum_config(app &ColorDemo) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		...base_config('spectrum', app.spectrum)
		frame:               ui2.rect(24, 108, 288, 0)
		accessibility_label: 'Brand color'
	}
}

fn palette_config(app &ColorDemo) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		...base_config('palette', app.palette)
		frame:               ui2.rect(336, 108, 288, 0)
		alpha:               false
		accessibility_label: 'Opaque color'
	}
}

fn sliders_config(app &ColorDemo) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		...base_config('sliders', app.sliders)
		frame:               ui2.rect(648, 108, 288, 0)
		panels:              [ui2.ColorPickerPanel.sliders]
		opaque_gradients:    true
		accessibility_label: 'Overlay color'
	}
}

fn theme_tint_config(app &ColorDemo) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		...base_config('theme_tint', app.theme_tint)
		frame:            ui2.rect(648, 344, 288, 32)
		variant:          .field
		opaque_gradients: true
		label:            'Theme color'
	}
}

fn background_config(app &ColorDemo) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		...base_config('background', app.background)
		frame:    ui2.rect(24, 592, 150, 32)
		variant:  .swatch
		label:    'Background'
		featured: [u32(0xffffff), 0xfef3c7, 0xdcfce7, 0xdbeafe, 0xfce7f3, 0xf1f5f9, 0x1e293b]
	}
}

fn text_color_config(app &ColorDemo) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		...base_config('text_color', app.text_color)
		frame:   ui2.rect(190, 592, 120, 32)
		variant: .swatch
		icon:    'textformat'
		label:   'Text'
		alpha:   false
	}
}

fn accent_config(app &ColorDemo) ui2.ColorPickerConfig {
	return ui2.ColorPickerConfig{
		...base_config('accent', app.accent)
		frame:   ui2.rect(326, 596, 96, 24)
		variant: .swatch
		size:    .small
		anchor:  .top_right
		label:   'Accent'
	}
}

fn configs(app &ColorDemo) []ui2.ColorPickerConfig {
	return [spectrum_config(app), palette_config(app), sliders_config(app), theme_tint_config(app),
		background_config(app), text_color_config(app), accent_config(app)]
}

fn picker_ref(mut app ColorDemo, id string) &Picker {
	return match id {
		'spectrum' { &app.spectrum }
		'palette' { &app.palette }
		'sliders' { &app.sliders }
		'theme_tint' { &app.theme_tint }
		'background' { &app.background }
		'text_color' { &app.text_color }
		else { &app.accent }
	}
}

// ── Build ───────────────────────────────────────────────────────────

fn heading(title string, x f64, y f64, width f64) ui2.Element {
	return ui2.label('', title, ui2.rect(x, y, width, 24), ui2.TextStyle{
		color: theme.foreground
		size:  16
		bold:  true
	})
}

fn caption(content string, x f64, y f64, width f64) ui2.Element {
	return ui2.label('', content, ui2.rect(x, y, width, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn note(content string, x f64, y f64, width f64) ui2.Element {
	return ui2.label('', content, ui2.rect(x, y, width, 20), ui2.TextStyle{
		color: theme.muted_foreground
		size:  13
	})
}

// sample is a card painted with the trigger colors, so changing them shows.
fn sample(app &ColorDemo) ui2.Element {
	bg := app.background.value
	accent_bar := if app.accent.empty {
		ui2.BoxStyle{
			bg: theme.border
		}
	} else {
		ui2.BoxStyle{
			bg:      app.accent.value.rgb()
			opacity: app.accent.value.a
		}
	}
	return ui2.view('sample', ui2.rect(24, 640, 600, 96), ui2.BoxStyle{
		bg:            bg.rgb()
		opacity:       bg.a
		radius:        8
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, [
		ui2.view('', ui2.rect(0, 0, 6, 96), accent_bar, []ui2.Element{}),
		ui2.label('', 'Release notes', ui2.rect(24, 16, 552, 26), ui2.TextStyle{
			color: app.text_color.value.rgb()
			size:  18
			bold:  true
		}),
		ui2.label('', 'Background ${bg.hex()}, text ${app.text_color.value.hex()}, accent ${if app.accent.empty {
			'not set'
		} else {
			app.accent.value.hex()
		}}.', ui2.rect(24, 50, 552, 22), ui2.TextStyle{
			color: app.text_color.value.rgb()
			size:  14
		}),
	])
}

fn build() ui2.Element {
	app := unsafe { demo }
	mut c := []ui2.Element{}
	c << ui2.label('', 'Color picker', ui2.rect(24, 16, 912, 32), ui2.TextStyle{
		color: theme.foreground
		size:  22
		bold:  true
	})
	brand := app.spectrum.value
	c << note('Brand ${brand.hex()}  ·  ${brand.css_rgb()}  ·  ${brand.css_hsl()}', 24, 50,
		912)
	c << caption('Inline, with every tab', 24, 84, 288)
	c << caption('Palette tab, opaque colors only', 336, 84, 288)
	c << caption('HSLA sliders only, opaque gradients', 648, 84, 288)
	for config in configs(app)[..3] {
		c << ui2.color_picker(config) or { panic(err) }
	}
	c << heading('Popover triggers', 648, 288, 288)
	c << caption('Field (ColorSelect), opaque gradients', 648, 320, 288)
	c << heading('Swatch triggers', 24, 532, 600)
	c << caption('Swatch with label, icon, small swatch with no color yet', 24, 564, 600)
	for config in configs(app)[3..] {
		c << ui2.color_picker(config) or { panic(err) }
	}
	c << sample(app)
	c << note(app.message, 24, 748, 912)
	c << note('Click a part, then use the arrow keys (Shift for steps of 10). Escape closes a popover.',
		24, 770, 912)
	// Popovers go last, so they cover everything above.
	for config in configs(app) {
		c << ui2.color_picker_popover(config) or { panic(err) }
	}
	return ui2.screen(theme.background, c)
}

// ── Events ──────────────────────────────────────────────────────────

// apply decodes one picker's event into its state.
fn apply(mut app ColorDemo, mut p Picker, config ui2.ColorPickerConfig, action string) bool {
	event := ui2.color_picker_event(config, action) or { return false }
	field := ui2.color_picker_hex_field_id(config.id)
	mut open := event.open
	match event.kind {
		.change {
			p.value = event.value
			p.empty = false
			p.hex_text = none
			p.focused = event.part
			app.active = config.id
		}
		.select {
			p.value = event.value
			p.empty = false
			p.hex_text = none
			app.message = '${config.id}: picked ${event.value.hex()}.'
		}
		.hex_change {
			typed := ui2.text(field)
			p.hex_text = typed
			// Typing hands the arrow keys back to the field.
			p.focused = none
			if next := ui2.color_picker_hex_value(config, typed) {
				p.value = next
				p.empty = false
			}
		}
		.hex_submit {
			if next := ui2.color_picker_hex_value(config, ui2.text(field)) {
				p.value = next
				p.empty = false
				app.message = '${config.id}: set to ${next.hex()}.'
			} else {
				app.message = '${config.id}: “${ui2.text(field)}” is not a hex color.'
				// Stay open so the text can be corrected.
				open = p.open
			}
			p.hex_text = none
			app.sync_id = field
			app.sync_text = if p.empty { '' } else { p.value.hex() }
		}
		.preview {
			p.preview = event.value
		}
		.preview_end {
			p.preview = none
		}
		.panel {
			p.panel = event.panel
			p.focused = none
		}
		.toggle, .dismiss {
			app.active = config.id
		}
	}
	if config.variant != .inline {
		p.open = open
		if !p.open {
			// A closed popover forgets the swatch under the pointer and any
			// unfinished hex text.
			p.preview = none
			p.hex_text = none
		}
	}
	return true
}

fn handle_event(action string) {
	mut app := unsafe { demo }
	for config in configs(app) {
		mut p := picker_ref(mut app, config.id)
		if apply(mut app, mut p, config, action) {
			refresh_and_settle(mut app)
			return
		}
	}
}

// refresh_and_settle rebuilds, then puts back a hex field the application
// rewrote when the rebuild left the user's text in place.
fn refresh_and_settle(mut app ColorDemo) {
	ui2.refresh()
	if app.sync_id.len > 0 {
		if ui2.text(app.sync_id) != app.sync_text {
			ui2.set_text(app.sync_id, app.sync_text)
		}
		app.sync_id = ''
	}
}

// handle_key closes an open popover on Escape and nudges the focused part
// of the picker last pressed with the arrow keys. A pressed part shows a focus
// ring and keeps the arrows until the user types in a hex field: AppKit leaves
// a text field focused when a plain view is clicked, so focused_id() alone
// cannot tell where the user is working.
fn handle_key(event ui2.KeyEvent) {
	mut app := unsafe { demo }
	for config in configs(app) {
		if ui2.color_picker_dismiss_on_key(config, event) {
			ui2.consume_key()
			mut p := picker_ref(mut app, config.id)
			p.open = false
			p.preview = none
			ui2.refresh()
			return
		}
	}
	for config in configs(app) {
		if config.id != app.active {
			continue
		}
		mut p := picker_ref(mut app, config.id)
		part := p.focused or { return }
		next := ui2.color_picker_value_after_key(config, part, event) or { return }
		ui2.consume_key()
		p.value = next
		p.hex_text = none
		ui2.refresh()
		return
	}
}

fn main() {
	ui2.on_key_event(handle_key)
	ui2.run_window('GPUI Kit color picker', window_width, window_height, build, handle_event)
}
