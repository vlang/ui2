module main

import math
import ui2

const colorbox_width = 760
const colorbox_height = 580
const colorbox_qml_source = $embed_file('colorbox.qml').to_string()
const hue_bands = 32
const sv_side = 16
const swatch_columns = 2
const swatch_rows = 3
// The picker is a fixed-size instrument, so its origin in the window never
// moves and pointer positions convert with plain constants.
const hue_root_y = 76.0
const picker_side = 256.0
const sv_root_x = 78.0
const sv_root_y = 76.0
const swatch_root_x = 348.0
const swatch_root_y = 76.0
const swatch_cell_w = 74.0
const swatch_cell_h = 37.0
const swatch_gap = 6.0

pub struct HueCell {
pub:
	key   string
	index int
	color string
}

pub struct SvCell {
pub:
	key    string
	column int
	row    int
	color  string
}

pub struct Swatch {
pub:
	key    string
	index  int
	column int
	row    int
pub mut:
	color    string
	selected bool
}

@[heap]
pub struct ColorBoxDemo {
pub mut:
	hue         f64
	saturation  f64 = 0.75
	value       f64 = 0.75
	red         int
	green       int
	blue        int
	red_text    string
	green_text  string
	blue_text   string
	valid       bool = true
	color       string
	hue_color   string
	hue_marker  f64
	sv_marker_x f64
	sv_marker_y f64
	hue_cells   []HueCell
	sv_cells    []SvCell
	swatches    []Swatch
	status      string = 'Drag the hue strip and the square, or type RGB values.'
}

const colorbox_state = &ColorBoxDemo{}

// hsv_to_rgb and rgb_to_hsv are the same round trip the original colorbox
// component performs between its canvases and its three numeric text boxes.
fn hsv_to_rgb(hue f64, saturation f64, value f64) (int, int, int) {
	sector := int(hue / 60.0) % 6
	fraction := hue / 60.0 - math.floor(hue / 60.0)
	p := value * (1.0 - saturation)
	q := value * (1.0 - fraction * saturation)
	t := value * (1.0 - (1.0 - fraction) * saturation)
	mut red, mut green, mut blue := value, t, p
	match sector {
		1 {
			red, green, blue = q, value, p
		}
		2 {
			red, green, blue = p, value, t
		}
		3 {
			red, green, blue = p, q, value
		}
		4 {
			red, green, blue = t, p, value
		}
		5 {
			red, green, blue = value, p, q
		}
		else {}
	}
	return int(math.round(red * 255)), int(math.round(green * 255)), int(math.round(blue * 255))
}

fn rgb_to_hsv(red int, green int, blue int) (f64, f64, f64) {
	r := f64(red) / 255.0
	g := f64(green) / 255.0
	b := f64(blue) / 255.0
	high := math.max(r, math.max(g, b))
	low := math.min(r, math.min(g, b))
	span := high - low
	mut hue := 0.0
	if span > 0 {
		hue = if high == r {
			60.0 * (((g - b) / span) + if g < b { 6.0 } else { 0.0 })
		} else if high == g {
			60.0 * ((b - r) / span + 2.0)
		} else {
			60.0 * ((r - g) / span + 4.0)
		}
	}
	saturation := if high == 0 { 0.0 } else { span / high }
	return hue, saturation, high
}

fn hex_color(red int, green int, blue int) string {
	return '#${red:02X}${green:02X}${blue:02X}'
}

fn clamp_unit(value f64) f64 {
	return math.max(0.0, math.min(1.0, value))
}

fn colorbox_demo() ColorBoxDemo {
	mut app := ColorBoxDemo{
		hue_cells: hue_strip_cells()
	}
	for index in 0 .. swatch_columns * swatch_rows {
		hue := f64(index) * 360.0 / f64(swatch_columns * swatch_rows)
		red, green, blue := hsv_to_rgb(hue, 0.65, 0.9)
		app.swatches << Swatch{
			key: 'swatch-${index}'
			index: index
			column: index % swatch_columns
			row: index / swatch_columns
			color: hex_color(red, green, blue)
			selected: index == 0
		}
	}
	app.sync()
	return app
}

// hue_strip_cells never changes: the strip always shows the whole circle at
// full saturation and value, and only the marker over it moves.
fn hue_strip_cells() []HueCell {
	mut cells := []HueCell{cap: hue_bands}
	for index in 0 .. hue_bands {
		hue := f64(index) * 360.0 / f64(hue_bands)
		red, green, blue := hsv_to_rgb(hue, 1.0, 1.0)
		cells << HueCell{
			key: 'hue-${index}'
			index: index
			color: hex_color(red, green, blue)
		}
	}
	return cells
}

// sync rebuilds everything that is derived from the current hue, saturation,
// and value: the square's tiles, the marker positions, and the RGB read-outs.
fn (mut app ColorBoxDemo) sync() {
	app.sv_cells = []SvCell{cap: sv_side * sv_side}
	for row in 0 .. sv_side {
		for column in 0 .. sv_side {
			saturation := (f64(column) + 0.5) / f64(sv_side)
			value := 1.0 - (f64(row) + 0.5) / f64(sv_side)
			red, green, blue := hsv_to_rgb(app.hue, saturation, value)
			app.sv_cells << SvCell{
				key: 'sv-${row}-${column}'
				column: column
				row: row
				color: hex_color(red, green, blue)
			}
		}
	}
	app.red, app.green, app.blue = hsv_to_rgb(app.hue, app.saturation, app.value)
	app.red_text = app.red.str()
	app.green_text = app.green.str()
	app.blue_text = app.blue.str()
	app.color = hex_color(app.red, app.green, app.blue)
	hue_red, hue_green, hue_blue := hsv_to_rgb(app.hue, 1.0, 1.0)
	app.hue_color = hex_color(hue_red, hue_green, hue_blue)
	app.hue_marker = app.hue / 360.0 * picker_side
	app.sv_marker_x = app.saturation * picker_side
	app.sv_marker_y = (1.0 - app.value) * picker_side
	app.valid = true
}

pub fn (mut app ColorBoxDemo) set_hue(hue f64) {
	app.hue = math.max(0.0, math.min(359.999, hue))
	app.sync()
	app.status = 'Hue ${int(app.hue)}° · ${app.color}'
}

pub fn (mut app ColorBoxDemo) set_saturation_value(saturation f64, value f64) {
	app.saturation = clamp_unit(saturation)
	app.value = clamp_unit(value)
	app.sync()
	app.status = 'S ${int(app.saturation * 100)}% · V ${int(app.value * 100)}% · ${app.color}'
}

fn parse_channel(text string) ?int {
	trimmed := text.trim_space()
	if trimmed.len == 0 || trimmed.len > 3 {
		return none
	}
	for character in trimmed {
		if !character.is_digit() {
			return none
		}
	}
	channel := trimmed.int()
	return if channel > 255 { none } else { channel }
}

pub fn (mut app ColorBoxDemo) apply_channel(name string, text string) {
	match name {
		'red' {
			app.red_text = text
		}
		'green' {
			app.green_text = text
		}
		else {
			app.blue_text = text
		}
	}
	red := parse_channel(app.red_text) or {
		app.valid = false
		app.status = 'Each channel must be a number between 0 and 255.'
		return
	}
	green := parse_channel(app.green_text) or {
		app.valid = false
		app.status = 'Each channel must be a number between 0 and 255.'
		return
	}
	blue := parse_channel(app.blue_text) or {
		app.valid = false
		app.status = 'Each channel must be a number between 0 and 255.'
		return
	}
	app.hue, app.saturation, app.value = rgb_to_hsv(red, green, blue)
	app.sync()
	app.status = 'RGB(${red}, ${green}, ${blue}) · ${app.color}'
}

fn (app &ColorBoxDemo) selected_slot() int {
	for swatch in app.swatches {
		if swatch.selected {
			return swatch.index
		}
	}
	return 0
}

pub fn (mut app ColorBoxDemo) select_swatch(index int) {
	if index < 0 || index >= app.swatches.len {
		return
	}
	for slot in 0 .. app.swatches.len {
		app.swatches[slot].selected = slot == index
	}
	stored := app.swatches[index].color
	red := ('0x' + stored[1..3]).int()
	green := ('0x' + stored[3..5]).int()
	blue := ('0x' + stored[5..7]).int()
	app.hue, app.saturation, app.value = rgb_to_hsv(red, green, blue)
	app.sync()
	app.status = 'Recalled slot ${index + 1} · ${app.color}'
}

pub fn (mut app ColorBoxDemo) store_swatch() {
	index := app.selected_slot()
	app.swatches[index].color = app.color
	app.status = 'Stored ${app.color} in slot ${index + 1}.'
}

fn (app &ColorBoxDemo) swatch_at(x f64, y f64) int {
	local_x := x - swatch_root_x
	local_y := y - swatch_root_y
	if local_x < 0 || local_y < 0 {
		return -1
	}
	column := int(local_x / (swatch_cell_w + swatch_gap))
	row := int(local_y / (swatch_cell_h + swatch_gap))
	if column >= swatch_columns || row >= swatch_rows {
		return -1
	}
	// The gap between two slots belongs to neither of them.
	if local_x - f64(column) * (swatch_cell_w + swatch_gap) > swatch_cell_w
		|| local_y - f64(row) * (swatch_cell_h + swatch_gap) > swatch_cell_h {
		return -1
	}
	return row * swatch_columns + column
}

fn colorbox_pointer(event string) ?(string, f64, f64) {
	parts := event.split(':')
	if parts.len < 5 || parts[0] != 'pointer' {
		return none
	}
	return parts[2], parts[3].f64(), parts[4].f64()
}

fn (mut app ColorBoxDemo) handle_event(event string) {
	match event {
		'red_input' { app.apply_channel('red', ui2.text('red_input')) }
		'green_input' { app.apply_channel('green', ui2.text('green_input')) }
		'blue_input' { app.apply_channel('blue', ui2.text('blue_input')) }
		'store' { app.store_swatch() }
		else {
			id, x, y := colorbox_pointer(event) or { return }
			match id {
				'hue_strip' {
					app.set_hue(clamp_unit((y - hue_root_y) / picker_side) * 359.999)
				}
				'sv_square' {
					app.set_saturation_value((x - sv_root_x) / picker_side, 1.0 - (y - sv_root_y) / picker_side)
				}
				'swatch_grid' {
					if event.starts_with('pointer:up:') {
						app.select_swatch(app.swatch_at(x, y))
					}
				}
				else {}
			}
		}
	}
}

fn build_colorbox_screen() ui2.Element {
	state := unsafe { colorbox_state }
	return ui2.element_from_qml_model(colorbox_qml_source, *state, ui2.bounds()) or {
		eprintln('colorbox QML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_colorbox_event(event string) {
	mut state := unsafe { colorbox_state }
	state.handle_event(event)
	ui2.refresh()
}

fn main() {
	mut state := unsafe { colorbox_state }
	unsafe {
		*state = colorbox_demo()
	}
	ui2.run_window('Color Box', colorbox_width, colorbox_height, build_colorbox_screen, handle_colorbox_event)
}
