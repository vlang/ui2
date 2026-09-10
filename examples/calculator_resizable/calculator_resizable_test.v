module main

import ui2

fn find_resizable_calc_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_resizable_calc_element(child, id) {
			return found
		}
	}
	return none
}

fn press_all(mut calc ResizableCalculator, keys []string) {
	for key in keys {
		calc.press(key)
	}
}

fn test_resizable_calculator_evaluates_left_to_right() {
	mut calc := resizable_calculator()
	assert calc.display == '0'
	press_all(mut calc, ['1', '2', '+', '3', '='])
	assert calc.display == '15'
	calc.press('C')
	// A desk calculator folds the pending operator as soon as the next one arrives.
	press_all(mut calc, ['2', '+', '3', '*', '4', '='])
	assert calc.display == '20'
	calc.press('C')
	press_all(mut calc, ['2', '^', '1', '0', '='])
	assert calc.display == '1024'
}

fn test_resizable_calculator_handles_decimals_sign_and_percent() {
	mut calc := resizable_calculator()
	press_all(mut calc, ['1', '.', '5', '*', '4', '='])
	assert calc.display == '6'
	calc.press('C')
	press_all(mut calc, ['5', '±'])
	assert calc.display == '-5'
	press_all(mut calc, ['+', '2', '0', '='])
	assert calc.display == '15'
	calc.press('C')
	press_all(mut calc, ['5', '0', '%'])
	assert calc.display == '0.5'
	// A second decimal point is ignored rather than making an unparseable number.
	calc.press('C')
	press_all(mut calc, ['1', '.', '2', '.', '3'])
	assert calc.display == '1.23'
}

fn test_resizable_calculator_recovers_from_division_by_zero() {
	mut calc := resizable_calculator()
	press_all(mut calc, ['8', '÷', '0', '='])
	assert calc.display == 'Error'
	// Typing a digit clears the error instead of appending to it.
	calc.press('7')
	assert calc.display == '7'
	press_all(mut calc, ['+', '1', '='])
	assert calc.display == '8'
}

fn test_resizable_calculator_vml_scales_every_measurement_with_the_window() {
	app := resizable_calculator()
	small := ui2.rect(0, 0, resizable_calc_width, resizable_calc_height)
	root := ui2.element_from_vml_model(resizable_calc_vml_source, app, small) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	display := find_resizable_calc_element(root, 'display') or { panic('missing display') }
	assert display.text_style.size == resizable_calc_height / 10
	// The keypad fills the window: the last key ends one margin short of the edges.
	keys := root.children.filter(it.id == '')
	assert keys.len == 20
	last := keys.last()
	margin := resizable_calc_width * 0.04
	assert last.frame.x + last.frame.width - (resizable_calc_width - margin) < 0.001
	assert last.frame.y + last.frame.height - (resizable_calc_height - margin) < 0.001

	// Doubling the window doubles the type and the keys with it.
	big := ui2.rect(0, 0, resizable_calc_width * 2, resizable_calc_height * 2)
	grown := ui2.element_from_vml_model(resizable_calc_vml_source, app, big) or { panic(err) }
	grown_display := find_resizable_calc_element(grown, 'display') or { panic('missing display') }
	assert grown_display.text_style.size == display.text_style.size * 2
	grown_keys := grown.children.filter(it.id == '')
	assert grown_keys.first().frame.width == keys.first().frame.width * 2
	assert grown_keys.first().text_style.size == keys.first().text_style.size * 2
	assert grown_keys.first().box.radius == keys.first().box.radius * 2
}
