module main

import ui2

const accent_color_width = 800
const accent_color_height = 600
const accent_color_vml_source = $embed_file('accent_color.vml').to_string()
// The three tracks share one geometry, so a pointer position converts with the
// card inset plus the label gutter in front of them.
const track_root_x = 92.0
const track_gutter = 200.0

pub struct AccentSwatch {
pub:
	key   string
	index int
	role  string
	color string
	label string
}

@[heap]
pub struct AccentColorDemo {
pub mut:
	red         int = 100
	green       int = 40
	blue        int = 150
	red_ratio   f64
	green_ratio f64
	blue_ratio  f64
	accent      string
	shade       string
	tint        string
	font_color  string
	on_dark     bool
	swatches    []AccentSwatch
	subscribed  bool = true
	sample      string = 'Accent colors'
	status      string
}

const accent_color_state = &AccentColorDemo{}

fn hex_channel(value int) string {
	clamped := if value < 0 {
		0
	} else if value > 255 {
		255
	} else {
		value
	}
	return '${clamped:02X}'
}

fn accent_hex(red int, green int, blue int) string {
	return '#' + hex_channel(red) + hex_channel(green) + hex_channel(blue)
}

// derive builds the four-color scheme the original example asks the window for:
// a shade at a third of the accent, the accent itself, a tint at five thirds of
// it, and the font color that stays readable on all three.
fn (mut app AccentColorDemo) derive() {
	app.shade = accent_hex(app.red / 3, app.green / 3, app.blue / 3)
	app.accent = accent_hex(app.red, app.green, app.blue)
	app.tint = accent_hex(app.red * 5 / 3, app.green * 5 / 3, app.blue * 5 / 3)
	// The original divides only the blue channel before comparing, which reads
	// as a slip; averaging all three is what keeps the caption legible.
	app.on_dark = (app.red + app.green + app.blue) / 3 < 128
	app.font_color = if app.on_dark { '#FFFFFF' } else { '#111111' }
	app.red_ratio = f64(app.red) / 255.0
	app.green_ratio = f64(app.green) / 255.0
	app.blue_ratio = f64(app.blue) / 255.0
	app.swatches = [
		AccentSwatch{
			key: 'swatch-0'
			index: 0
			role: 'shade'
			color: app.shade
			label: '0 · shade'
		},
		AccentSwatch{
			key: 'swatch-1'
			index: 1
			role: 'accent'
			color: app.accent
			label: '1 · accent'
		},
		AccentSwatch{
			key: 'swatch-2'
			index: 2
			role: 'tint'
			color: app.tint
			label: '2 · tint'
		},
		AccentSwatch{
			key: 'swatch-3'
			index: 3
			role: 'font'
			color: app.font_color
			label: '3 · font'
		},
	]
	app.status = 'Accent ${app.accent} · shade ${app.shade} · tint ${app.tint} · font ${app.font_color}'
}

fn accent_color_demo() AccentColorDemo {
	mut app := AccentColorDemo{}
	app.derive()
	return app
}

fn clamp_channel(value int) int {
	if value < 0 {
		return 0
	}
	return if value > 255 { 255 } else { value }
}

pub fn (mut app AccentColorDemo) set_channel(name string, value int) {
	channel := clamp_channel(value)
	match name {
		'red' {
			app.red = channel
		}
		'green' {
			app.green = channel
		}
		else {
			app.blue = channel
		}
	}
	app.derive()
}

pub fn (mut app AccentColorDemo) set_fraction(name string, fraction f64) {
	clamped := if fraction < 0 {
		0.0
	} else if fraction > 1 {
		1.0
	} else {
		fraction
	}
	app.set_channel(name, int(clamped * 255.0 + 0.5))
}

pub fn (mut app AccentColorDemo) reset() {
	app.red = 100
	app.green = 40
	app.blue = 150
	app.derive()
	app.status = 'Accent reset to ' + app.accent + '.'
}

pub fn (mut app AccentColorDemo) toggle_subscribed() {
	app.subscribed = !app.subscribed
}

fn accent_track_width(frame ui2.Rect) f64 {
	return frame.width - 32.0 - track_gutter
}

fn accent_pointer(event string) ?(string, f64) {
	parts := event.split(':')
	if parts.len < 5 || parts[0] != 'pointer' {
		return none
	}
	return parts[2], parts[3].f64()
}

fn (mut app AccentColorDemo) handle_event(event string, track_width f64) {
	match event {
		'reset' {
			app.reset()
		}
		'subscribe' {
			app.toggle_subscribed()
		}
		'sample_input' {
			app.sample = ui2.text('sample_input')
		}
		else {
			id, x := accent_pointer(event) or { return }
			name := match id {
				'track_red' { 'red' }
				'track_green' { 'green' }
				'track_blue' { 'blue' }
				else { '' }
			}
			if name.len > 0 && track_width > 0 {
				app.set_fraction(name, (x - track_root_x) / track_width)
			}
		}
	}
}

fn build_accent_color_screen() ui2.Element {
	state := unsafe { accent_color_state }
	return ui2.element_from_vml_model(accent_color_vml_source, *state, ui2.bounds()) or {
		eprintln('accent-color VML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_accent_color_event(event string) {
	mut state := unsafe { accent_color_state }
	state.handle_event(event, accent_track_width(ui2.bounds()))
	ui2.refresh()
}

fn main() {
	mut state := unsafe { accent_color_state }
	unsafe {
		*state = accent_color_demo()
	}
	ui2.run_window('Accent Color', accent_color_width, accent_color_height, build_accent_color_screen, handle_accent_color_event)
}
