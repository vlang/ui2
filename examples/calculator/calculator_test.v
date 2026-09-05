module main

import ui2

fn press_sequence(mut calculator Calculator, keys []string) {
	for key in keys {
		calculator.press(key)
	}
}

fn find_calculator_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_calculator_element(child, id) {
			return found
		}
	}
	return none
}

fn test_basic_arithmetic_and_decimal_input() {
	mut calculator := Calculator{}
	press_sequence(mut calculator, ['1', '2', '.', '5', '*', '2', '='])
	assert calculator.display == '25'
}

fn test_operations_are_evaluated_as_they_are_entered() {
	mut calculator := Calculator{}
	press_sequence(mut calculator, ['2', '+', '3', '*', '4', '='])
	assert calculator.display == '20'
}

fn test_sign_percent_power_and_repeated_equals() {
	mut calculator := Calculator{}
	press_sequence(mut calculator, ['5', '0', '%', '±'])
	assert calculator.display == '-0.5'
	calculator.clear()
	press_sequence(mut calculator, ['2', '^', '3', '='])
	assert calculator.display == '8'
	calculator.press('=')
	assert calculator.display == '512'
}

fn test_clear_and_division_by_zero_recovery() {
	mut calculator := Calculator{}
	press_sequence(mut calculator, ['8', '÷', '0', '='])
	assert calculator.display == 'Error'
	calculator.press('7')
	assert calculator.display == '7'
	calculator.press('C')
	assert calculator.display == '0'
}

fn test_calculator_screen_contains_display_and_every_key() {
	calculator := Calculator{}
	root := calculator_screen(ui2.rect(0, 0, window_width, window_height), calculator)
	ui2.validate_element_tree(root) or { panic(err) }
	assert (find_calculator_element(root, 'display') or { panic('missing display') }).text == '0'
	panel := find_calculator_element(root, 'calculator') or { panic('missing calculator panel') }
	assert panel.children.len == 21
}
