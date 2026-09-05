module main

import ui2

const rgb_color_width = 380
const rgb_color_height = 330
const rgb_color_qml_source = $embed_file('rgb_color.qml').to_string()

pub struct RgbColorDemo {
pub mut:
	red           string = '128'
	green         string = '128'
	blue          string = '128'
	preview_color string = '#808080'
	valid         bool = true
	message       string = 'rgb(128, 128, 128)'
}

fn rgb_component(value string) ?int {
	trimmed := value.trim_space()
	if trimmed.len == 0 {
		return none
	}
	for character in trimmed {
		if character < `0` || character > `9` {
			return none
		}
	}
	component := trimmed.int()
	if component < 0 || component > 255 {
		return none
	}
	return component
}

pub fn (mut app RgbColorDemo) update_color() {
	r := rgb_component(app.red) or {
		app.valid = false
		app.preview_color = '#FFFFFF'
		app.message = 'RGB values must be between 0 and 255.'
		return
	}
	g := rgb_component(app.green) or {
		app.valid = false
		app.preview_color = '#FFFFFF'
		app.message = 'RGB values must be between 0 and 255.'
		return
	}
	b := rgb_component(app.blue) or {
		app.valid = false
		app.preview_color = '#FFFFFF'
		app.message = 'RGB values must be between 0 and 255.'
		return
	}
	app.valid = true
	app.preview_color = '#${r:02X}${g:02X}${b:02X}'
	app.message = 'rgb(${r}, ${g}, ${b})'
}

pub fn (mut app RgbColorDemo) show_color() {
	app.update_color()
}

fn main() {
	ui2.run_qml[RgbColorDemo](
		source: rgb_color_qml_source
		model: RgbColorDemo{}
		title: 'RGB Color'
		width: rgb_color_width
		height: rgb_color_height
	) or { panic(err) }
}
