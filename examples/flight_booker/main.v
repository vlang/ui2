module main

import time
import ui2

const flight_booker_width = 400
const flight_booker_height = 390
const flight_booker_qml_source = $embed_file('flight_booker.qml').to_string()

pub struct FlightBooker {
pub mut:
	flight_type     string = 'one-way flight'
	departure       string
	return_date     string
	departure_valid bool = true
	return_valid    bool = true
	confirmation    string
}

fn all_digits(value string) bool {
	if value.len == 0 {
		return false
	}
	for character in value {
		if !character.is_digit() {
			return false
		}
	}
	return true
}

fn valid_date(value string) bool {
	parts := value.trim_space().split('.')
	if parts.len != 3 || !all_digits(parts[0]) || !all_digits(parts[1])
		|| !all_digits(parts[2]) {
		return false
	}
	day := parts[0].int()
	month := parts[1].int()
	year := parts[2].int()
	if day < 1 || month < 1 || month > 12 || year < 1 {
		return false
	}
	days := time.days_in_month(month, year) or { return false }
	return day <= days
}

fn today_date() string {
	today := time.now()
	return '${today.day}.${today.month}.${today.year}'
}

fn initial_flight_booker() FlightBooker {
	today := today_date()
	return FlightBooker{
		departure: today
		return_date: today
	}
}

fn (app &FlightBooker) can_book() bool {
	return app.departure_valid
		&& (app.flight_type == 'one-way flight' || app.return_valid)
}

pub fn (mut app FlightBooker) flight_type_changed() {
	app.confirmation = ''
}

pub fn (mut app FlightBooker) validate_departure() {
	app.departure_valid = valid_date(app.departure)
	app.confirmation = ''
}

pub fn (mut app FlightBooker) validate_return() {
	app.return_valid = valid_date(app.return_date)
	app.confirmation = ''
}

pub fn (mut app FlightBooker) book() {
	app.departure_valid = valid_date(app.departure)
	app.return_valid = valid_date(app.return_date)
	if !app.can_book() {
		app.confirmation = ''
		return
	}
	app.confirmation = if app.flight_type == 'one-way flight' {
		'Booked a one-way flight for ${app.departure}.'
	} else {
		'Booked a return flight from ${app.departure} to ${app.return_date}.'
	}
}

fn main() {
	ui2.run_qml[FlightBooker](
		source: flight_booker_qml_source
		model: initial_flight_booker()
		title: 'Flight Booker'
		width: flight_booker_width
		height: flight_booker_height
	) or { panic(err) }
}
