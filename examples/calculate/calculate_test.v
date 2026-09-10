module main

import ui2

fn find_calculate_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_calculate_element(child, id) {
			return found
		}
	}
	return none
}

fn test_calculate_parser_handles_precedence_parentheses_and_unary() {
	assert calculate_expression('3 + 22 / 2')! == 14
	assert calculate_expression('(22 + (13 - 5) * 4) / 2 + 10')! == 37
	assert calculate_expression('-3 * (2 + 4)')! == -18
}

fn test_calculate_model_reports_errors_and_recovers() {
	mut app := CalculateDemo{ expression: '8 / 0' }
	app.evaluate()
	assert app.has_error
	assert app.result == 'Error'
	app.expression = '2.5 * 4'
	app.evaluate()
	assert !app.has_error
	assert app.result == '10'
}

fn test_calculate_vml_has_submit_and_native_actions() {
	root := ui2.element_from_vml_model(calculate_vml_source, CalculateDemo{}, ui2.rect(0, 0, calculate_width, calculate_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	field := find_calculate_element(root, 'expression') or { panic('missing expression field') }
	result := find_calculate_element(root, 'result') or { panic('missing result') }
	assert field.submit_id.len > 0
	assert result.text == '5.325'
	assert (find_calculate_element(root, 'evaluate') or { panic('missing evaluate button') }).native_style
}
