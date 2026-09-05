module main

import math
import ui2

const window_width = 284
const window_height = 364

@[heap]
struct Calculator {
mut:
	display          string = '0'
	accumulator      f64
	pending_operator string
	last_operator    string
	last_operand     f64
	has_accumulator  bool
	replace_input    bool = true
	has_error        bool
}

const calculator_state = &Calculator{}

fn calculator_keys() [][]string {
	return [
		['C', '%', '^', '÷'],
		['7', '8', '9', '*'],
		['4', '5', '6', '-'],
		['1', '2', '3', '+'],
		['0', '.', '±', '='],
	]
}

fn format_number(value f64) string {
	if value == 0 {
		return '0'
	}
	absolute := math.abs(value)
	if absolute < 1.0e12 && math.trunc(value).eq_epsilon(value) {
		return i64(math.round(value)).str()
	}
	if absolute >= 1.0e12 || absolute < 1.0e-9 {
		return value.str()
	}
	return '${value:.10f}'.trim_right('0').trim_right('.')
}

fn calculate_binary(left f64, right f64, operator string) ?f64 {
	result := match operator {
		'+' { left + right }
		'-' { left - right }
		'*' { left * right }
		'÷' {
			if right == 0 {
				return none
			}
			left / right
		}
		'^' { math.pow(left, right) }
		else {
			return none
		}
	}
	if !math.is_finite(result) {
		return none
	}
	return result
}

fn (mut calculator Calculator) clear() {
	calculator.display = '0'
	calculator.accumulator = 0
	calculator.pending_operator = ''
	calculator.last_operator = ''
	calculator.last_operand = 0
	calculator.has_accumulator = false
	calculator.replace_input = true
	calculator.has_error = false
}

fn (mut calculator Calculator) fail() {
	calculator.display = 'Error'
	calculator.accumulator = 0
	calculator.pending_operator = ''
	calculator.last_operator = ''
	calculator.last_operand = 0
	calculator.has_accumulator = false
	calculator.replace_input = true
	calculator.has_error = true
}

fn (mut calculator Calculator) input_digit(digit string) {
	if calculator.has_error {
		calculator.clear()
	}
	if calculator.replace_input {
		if calculator.pending_operator.len == 0 {
			calculator.has_accumulator = false
		}
		calculator.display = digit
		calculator.replace_input = false
		return
	}
	if calculator.display == '0' {
		calculator.display = digit
	} else {
		calculator.display += digit
	}
}

fn (mut calculator Calculator) input_decimal() {
	if calculator.has_error {
		calculator.clear()
	}
	if calculator.replace_input {
		if calculator.pending_operator.len == 0 {
			calculator.has_accumulator = false
		}
		calculator.display = '0.'
		calculator.replace_input = false
	} else if !calculator.display.contains('.') {
		calculator.display += '.'
	}
}

fn (mut calculator Calculator) set_display_value(value f64) {
	calculator.display = format_number(value)
}

fn (mut calculator Calculator) evaluate_pending(right f64) bool {
	result := calculate_binary(calculator.accumulator, right, calculator.pending_operator) or {
		calculator.fail()
		return false
	}
	calculator.accumulator = result
	calculator.set_display_value(result)
	return true
}

fn (mut calculator Calculator) set_operator(operator string) {
	if calculator.has_error {
		return
	}
	current := calculator.display.f64()
	if !calculator.has_accumulator {
		calculator.accumulator = current
		calculator.has_accumulator = true
	} else if calculator.pending_operator.len > 0 && !calculator.replace_input {
		if !calculator.evaluate_pending(current) {
			return
		}
	} else if calculator.pending_operator.len == 0 {
		calculator.accumulator = current
	}
	calculator.pending_operator = operator
	calculator.last_operator = ''
	calculator.replace_input = true
}

fn (mut calculator Calculator) equals() {
	if calculator.has_error {
		return
	}
	if calculator.pending_operator.len > 0 {
		right := if calculator.replace_input {
			calculator.accumulator
		} else {
			calculator.display.f64()
		}
		calculator.last_operator = calculator.pending_operator
		calculator.last_operand = right
		if !calculator.evaluate_pending(right) {
			return
		}
		calculator.pending_operator = ''
		calculator.replace_input = true
		return
	}
	if calculator.last_operator.len > 0 {
		calculator.accumulator = calculator.display.f64()
		if calculator.evaluate_pending_with(calculator.last_operator, calculator.last_operand) {
			calculator.replace_input = true
		}
	}
}

fn (mut calculator Calculator) evaluate_pending_with(operator string, right f64) bool {
	result := calculate_binary(calculator.accumulator, right, operator) or {
		calculator.fail()
		return false
	}
	calculator.accumulator = result
	calculator.set_display_value(result)
	return true
}

fn (mut calculator Calculator) toggle_sign() {
	if calculator.has_error {
		return
	}
	value := -calculator.display.f64()
	calculator.set_display_value(value)
	calculator.replace_input = false
}

fn (mut calculator Calculator) percent() {
	if calculator.has_error {
		return
	}
	calculator.set_display_value(calculator.display.f64() / 100.0)
	calculator.replace_input = false
}

fn (mut calculator Calculator) press(key string) {
	if key.len == 1 && key[0].is_digit() {
		calculator.input_digit(key)
		return
	}
	match key {
		'C' { calculator.clear() }
		'.' { calculator.input_decimal() }
		'±' { calculator.toggle_sign() }
		'%' { calculator.percent() }
		'+', '-', '*', '÷', '^' { calculator.set_operator(key) }
		'=' { calculator.equals() }
		else {}
	}
}

fn key_background(key string) u32 {
	return match key {
		'C' { u32(0xef4444) }
		'=', '+', '-', '*', '÷', '^' { u32(0x3478d4) }
		'%', '±' { u32(0xcbd5e1) }
		else { u32(0xf8fafc) }
	}
}

fn key_color(key string) u32 {
	return if key in ['C', '=', '+', '-', '*', '÷', '^'] { u32(0xffffff) } else { u32(0x111827) }
}

fn calculator_screen(bounds ui2.Rect, calculator &Calculator) ui2.Element {
	outer_margin := 12.0
	available_width := bounds.width - outer_margin * 2
	panel_width := if available_width < 260 { available_width } else { 260.0 }
	panel_height := 340.0
	panel_x := if bounds.width > panel_width { (bounds.width - panel_width) / 2 } else { 0.0 }
	panel_y := if bounds.height > panel_height { (bounds.height - panel_height) / 2 } else { 0.0 }
	padding := 12.0
	spacing := 8.0
	content_width := panel_width - padding * 2
	button_width := (content_width - spacing * 3) / 4
	button_height := 44.0

	mut children := []ui2.Element{}
	children << ui2.view('display-frame', ui2.rect(padding, padding, content_width, 56), ui2.BoxStyle{
		bg: 0xffffff
		radius: 8
	}, [
		ui2.label('display', calculator.display, ui2.rect(10, 0, content_width - 20, 56), ui2.TextStyle{
			color: 0x111827
			size: 28
			align: .right
		}),
	])

	for row_index, row in calculator_keys() {
		for column_index, key in row {
			x := padding + f64(column_index) * (button_width + spacing)
			y := 76.0 + f64(row_index) * (button_height + spacing)
			button := ui2.button('key-${row_index}-${column_index}', key, ui2.rect(x, y, button_width, button_height), ui2.BoxStyle{
				bg: key_background(key)
				radius: 8
			}, ui2.TextStyle{
				color: key_color(key)
				size: 18
				bold: key == '='
				align: .center
			})
			children << ui2.with_action(button, key)
		}
	}

	panel := ui2.view('calculator', ui2.rect(panel_x, panel_y, panel_width, panel_height), ui2.BoxStyle{
		bg: 0x1f2937
		radius: 12
	}, children)
	return ui2.screen(0xf1f5f9, [panel])
}

fn build_screen() ui2.Element {
	state := unsafe { calculator_state }
	return calculator_screen(ui2.bounds(), state)
}

fn handle_event(event string) {
	mut state := unsafe { calculator_state }
	state.press(event)
	ui2.refresh()
}

fn main() {
	$if macos || linux || windows {
		ui2.run_window('V Calc', window_width, window_height, build_screen, handle_event)
	} $else {
		ui2.run(build_screen, handle_event)
	}
}
