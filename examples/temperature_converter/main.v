module main

import math
import strconv
import ui2

const temperature_width = 600
const temperature_height = 168
const temperature_qml_source = $embed_file('temperature_converter.qml').to_string()

pub struct TemperatureConverter {
pub mut:
	celsius          string
	fahrenheit       string
	celsius_valid    bool = true
	fahrenheit_valid bool = true
}

fn parse_temperature(value string) ?f64 {
	trimmed := value.trim_space()
	if trimmed.len == 0 {
		return none
	}
	parsed := strconv.atof64(trimmed) or { return none }
	if !math.is_finite(parsed) {
		return none
	}
	return parsed
}

fn format_temperature(value f64) string {
	if math.trunc(value).eq_epsilon(value) {
		return i64(math.round(value)).str()
	}
	return '${value:.2f}'.trim_right('0').trim_right('.')
}

pub fn (mut app TemperatureConverter) update_from_celsius() {
	if app.celsius.trim_space().len == 0 {
		app.celsius_valid = true
		app.fahrenheit_valid = true
		app.fahrenheit = ''
		return
	}
	celsius := parse_temperature(app.celsius) or {
		app.celsius_valid = false
		return
	}
	app.celsius_valid = true
	app.fahrenheit_valid = true
	app.fahrenheit = format_temperature(celsius * 9.0 / 5.0 + 32.0)
}

pub fn (mut app TemperatureConverter) update_from_fahrenheit() {
	if app.fahrenheit.trim_space().len == 0 {
		app.fahrenheit_valid = true
		app.celsius_valid = true
		app.celsius = ''
		return
	}
	fahrenheit := parse_temperature(app.fahrenheit) or {
		app.fahrenheit_valid = false
		return
	}
	app.fahrenheit_valid = true
	app.celsius_valid = true
	app.celsius = format_temperature((fahrenheit - 32.0) * 5.0 / 9.0)
}

fn main() {
	ui2.run_qml[TemperatureConverter](
		source: temperature_qml_source
		model: TemperatureConverter{}
		title: 'Temperature Converter'
		width: temperature_width
		height: temperature_height
	) or { panic(err) }
}
