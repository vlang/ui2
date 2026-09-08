module main

import ui2

fn find_temperature_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_temperature_element(child, id) {
			return found
		}
	}
	return none
}

fn test_temperature_conversion_in_both_directions() {
	mut app := TemperatureConverter{
		celsius: '100'
	}
	app.update_from_celsius()
	assert app.celsius_valid
	assert app.fahrenheit == '212'
	app.fahrenheit = '14'
	app.update_from_fahrenheit()
	assert app.fahrenheit_valid
	assert app.celsius == '-10'
}

fn test_temperature_rejects_invalid_input() {
	mut app := TemperatureConverter{
		celsius: 'warm'
	}
	app.update_from_celsius()
	assert !app.celsius_valid
	app.celsius = '-12.5'
	app.update_from_celsius()
	assert app.celsius_valid
	assert app.fahrenheit == '9.5'
}

fn test_temperature_vml_builds_bound_fields() {
	app := TemperatureConverter{
		celsius: '20'
		fahrenheit: '68'
	}
	root := ui2.element_from_vml_model(temperature_vml_source, app, ui2.rect(0, 0, temperature_width, temperature_height)) or { panic(err) }
	celsius := find_temperature_element(root, 'celsius') or { panic('missing Celsius field') }
	fahrenheit := find_temperature_element(root, 'fahrenheit') or {
		panic('missing Fahrenheit field')
	}
	assert celsius.text == '20'
	assert fahrenheit.text == '68'
	assert celsius.action_id.len > 0
}
