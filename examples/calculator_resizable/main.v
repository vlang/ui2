module main

import math
import ui2

const resizable_calc_width = 340
const resizable_calc_height = 480
const resizable_calc_qml_source = $embed_file('calculator_resizable.qml').to_string()

pub struct CalculatorKey {
pub:
	text   string
	key    string
	row    int
	column int
	role   string
}

// Every measurement in this example is a fraction of the window, so the model
// only has to carry the keypad and the running arithmetic.
pub struct ResizableCalculator {
pub:
	keys []CalculatorKey
pub mut:
	display string = '0'
mut:
	accumulator      f64
	pending_operator string
	replace_input    bool = true
	has_error        bool
}

fn resizable_calculator_keys() []CalculatorKey {
	rows := [['C', '%', '^', '÷'], ['7', '8', '9', '*'], ['4', '5', '6', '-'], ['1', '2', '3',
		'+'], ['0', '.', '±', '=']]
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
				key: 'key-${row}-${column}'
				row: row
				column: column
				role: role
			}
		}
	}
	return keys
}

fn resizable_calculator() ResizableCalculator {
	return ResizableCalculator{
		keys: resizable_calculator_keys()
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

fn apply_operator(left f64, right f64, operator string) ?f64 {
	result := match operator {
		'+' { left + right }
		'-' { left - right }
		'*' { left * right }
		'÷' {
			if right == 0 {
				return none
			} else {
				left / right
			}
		}
		'^' { math.pow(left, right) }
		else {
			return none
		}
	}
	return if math.is_finite(result) { result } else { none }
}

fn (mut calc ResizableCalculator) clear() {
	calc.display = '0'
	calc.accumulator = 0
	calc.pending_operator = ''
	calc.replace_input = true
	calc.has_error = false
}

fn (mut calc ResizableCalculator) fail() {
	calc.clear()
	calc.display = 'Error'
	calc.has_error = true
}

fn (mut calc ResizableCalculator) input_digit(digit string) {
	if calc.has_error {
		calc.clear()
	}
	if calc.replace_input {
		calc.display = digit
		calc.replace_input = false
		return
	}
	calc.display = if calc.display == '0' { digit } else { calc.display + digit }
}

fn (mut calc ResizableCalculator) input_decimal() {
	if calc.has_error {
		calc.clear()
	}
	if calc.replace_input {
		calc.display = '0.'
		calc.replace_input = false
	} else if !calc.display.contains('.') {
		calc.display += '.'
	}
}

// resolve folds the pending operator into the accumulator. It is what both a
// new operator and `=` go through, so `2 + 3 * 4` evaluates left to right the
// way a desk calculator does.
fn (mut calc ResizableCalculator) resolve() bool {
	if calc.pending_operator.len == 0 {
		calc.accumulator = calc.display.f64()
		return true
	}
	result := apply_operator(calc.accumulator, calc.display.f64(), calc.pending_operator) or {
		calc.fail()
		return false
	}
	calc.accumulator = result
	calc.display = format_number(result)
	return true
}

fn (mut calc ResizableCalculator) set_operator(operator string) {
	if calc.has_error {
		return
	}
	if !calc.replace_input && !calc.resolve() {
		return
	}
	if calc.replace_input && calc.pending_operator.len == 0 {
		calc.accumulator = calc.display.f64()
	}
	calc.pending_operator = operator
	calc.replace_input = true
}

fn (mut calc ResizableCalculator) equals() {
	if calc.has_error || calc.pending_operator.len == 0 {
		return
	}
	if !calc.resolve() {
		return
	}
	calc.pending_operator = ''
	calc.replace_input = true
}

pub fn (mut calc ResizableCalculator) press(key string) {
	if key.len == 1 && key[0].is_digit() {
		calc.input_digit(key)
		return
	}
	match key {
		'C' {
			calc.clear()
		}
		'.' {
			calc.input_decimal()
		}
		'±' {
			if !calc.has_error {
				calc.display = format_number(-calc.display.f64())
				calc.replace_input = false
			}
		}
		'%' {
			if !calc.has_error {
				calc.display = format_number(calc.display.f64() / 100.0)
				calc.replace_input = false
			}
		}
		'+', '-', '*', '÷', '^' {
			calc.set_operator(key)
		}
		'=' {
			calc.equals()
		}
		else {}
	}
}

fn main() {
	ui2.run_qml[ResizableCalculator](
		source: resizable_calc_qml_source
		model: resizable_calculator()
		title: 'V Calc (resizable)'
		width: resizable_calc_width
		height: resizable_calc_height
	) or { panic(err) }
}
