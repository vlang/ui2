module main

import math
import ui2

const window_width = 284
const window_height = 364
const calculator_qml_source = $embed_file('calculator.qml').to_string()

pub struct CalculatorKey {
pub:
	text   string
	row    int
	column int
	role   string
}

pub struct Calculator {
pub:
	keys []CalculatorKey
pub mut:
	display string = '0'
mut:
	accumulator      f64
	pending_operator string
	last_operator    string
	last_operand     f64
	has_accumulator  bool
	replace_input    bool = true
	has_error        bool
}

fn calculator_keys() []CalculatorKey {
	rows := [
		['C', '%', '^', '÷'],
		['7', '8', '9', '*'],
		['4', '5', '6', '-'],
		['1', '2', '3', '+'],
		['0', '.', '±', '='],
	]
	mut keys := []CalculatorKey{cap: 20}
	for row, values in rows {
		for column, text in values {
			role := match text {
				'C' { 'clear' }
				'=', '+', '-', '*', '÷', '^' { 'operator' }
				'%', '±' { 'utility' }
				else { 'digit' }
			}
			keys << CalculatorKey{
				text: text
				row: row
				column: column
				role: role
			}
		}
	}
	return keys
}

fn initial_calculator() Calculator {
	return Calculator{
		keys: calculator_keys()
	}
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

pub fn (mut calculator Calculator) press(key string) {
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

fn main() {
	ui2.run_qml[Calculator](
		source: calculator_qml_source
		model: initial_calculator()
		title: 'V Calc'
		width: window_width
		height: window_height
	) or { panic(err) }
}
