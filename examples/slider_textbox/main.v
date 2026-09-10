module main

import ui2

const slider_textbox_width = 620
const slider_textbox_height = 560
const slider_textbox_vml_source = $embed_file('slider_textbox.vml').to_string()

@[heap]
pub struct SliderTextboxDemo {
pub mut:
	horizontal_value int
	horizontal_text  string
	horizontal_valid bool = true
	vertical_value   int
	vertical_text    string
	vertical_valid   bool = true
	status           string = 'Drag either slider or type a value.'
}

const slider_textbox_state = &SliderTextboxDemo{}

fn parse_slider_integer(value string) ?int {
	trimmed := value.trim_space()
	if trimmed.len == 0 {
		return none
	}
	start := if trimmed[0] == `-` { 1 } else { 0 }
	if start == trimmed.len {
		return none
	}
	for character in trimmed[start..] {
		if !character.is_digit() {
			return none
		}
	}
	return trimmed.int()
}

fn slider_textbox_demo() SliderTextboxDemo {
	mut app := SliderTextboxDemo{}
	app.set_horizontal(40)
	app.set_vertical(-60)
	app.status = 'Drag either slider or type a value.'
	return app
}

fn (mut app SliderTextboxDemo) set_horizontal(value int) {
	clamped := if value < -20 {
		-20
	} else if value > 100 { 100 } else { value }
	app.horizontal_value = clamped
	app.horizontal_text = clamped.str()
	app.horizontal_valid = true
	app.status = 'Horizontal value: ${clamped}'
}

fn (mut app SliderTextboxDemo) set_vertical(value int) {
	clamped := if value < -100 {
		-100
	} else if value > -20 { -20 } else { value }
	app.vertical_value = clamped
	app.vertical_text = clamped.str()
	app.vertical_valid = true
	app.status = 'Vertical value: ${clamped}'
}

fn (mut app SliderTextboxDemo) apply_horizontal_text(value string) {
	app.horizontal_text = value
	parsed := parse_slider_integer(value) or {
		app.horizontal_valid = false
		app.status = 'Horizontal value must be between −20 and 100.'
		return
	}
	if parsed < -20 || parsed > 100 {
		app.horizontal_valid = false
		app.status = 'Horizontal value must be between −20 and 100.'
		return
	}
	app.set_horizontal(parsed)
}

fn (mut app SliderTextboxDemo) apply_vertical_text(value string) {
	app.vertical_text = value
	parsed := parse_slider_integer(value) or {
		app.vertical_valid = false
		app.status = 'Vertical value must be between −100 and −20.'
		return
	}
	if parsed < -100 || parsed > -20 {
		app.vertical_valid = false
		app.status = 'Vertical value must be between −100 and −20.'
		return
	}
	app.set_vertical(parsed)
}

fn (mut app SliderTextboxDemo) reset() {
	app.set_horizontal(40)
	app.set_vertical(-60)
	app.status = 'Both controls reset to their midpoint.'
}

fn (mut app SliderTextboxDemo) handle_event(event string) {
	match event {
		'horizontal_input' { app.apply_horizontal_text(ui2.text('horizontal_input')) }
		'vertical_input' { app.apply_vertical_text(ui2.text('vertical_input')) }
		'horizontal_slider' { app.set_horizontal(int(ui2.slider_value('horizontal_slider'))) }
		'vertical_slider' { app.set_vertical(int(ui2.slider_value('vertical_slider'))) }
		'reset' { app.reset() }
		else {}
	}
}

fn build_slider_textbox_screen() ui2.Element {
	state := unsafe { slider_textbox_state }
	return ui2.element_from_vml_model(slider_textbox_vml_source, *state, ui2.bounds()) or {
		eprintln('slider-textbox VML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_slider_textbox_event(event string) {
	mut state := unsafe { slider_textbox_state }
	state.handle_event(event)
	ui2.refresh()
}

fn main() {
	mut state := unsafe { slider_textbox_state }
	unsafe {
		*state = slider_textbox_demo()
	}
	ui2.run_window('Slider & Textbox', slider_textbox_width, slider_textbox_height, build_slider_textbox_screen, handle_slider_textbox_event)
}
