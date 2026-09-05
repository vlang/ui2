module main

import ui2

fn find_flight_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_flight_element(child, id) {
			return found
		}
	}
	return none
}

fn test_flight_booker_validates_calendar_dates() {
	assert valid_date('29.2.2024')
	assert !valid_date('29.2.2023')
	assert !valid_date('31.4.2026')
	assert !valid_date('tomorrow')
}

fn test_flight_booker_creates_both_confirmation_messages() {
	mut app := FlightBooker{
		departure: '5.9.2026'
		return_date: '12.9.2026'
	}
	app.book()
	assert app.confirmation.contains('one-way')
	app.flight_type = 'return flight'
	app.book()
	assert app.confirmation.contains('5.9.2026')
	assert app.confirmation.contains('12.9.2026')
}

fn test_flight_booker_qml_controls_return_field_and_booking() {
	mut app := FlightBooker{
		departure: '5.9.2026'
		return_date: '12.9.2026'
	}
	root := ui2.element_from_qml_model(flight_booker_qml_source, app, ui2.rect(0, 0, flight_booker_width, flight_booker_height)) or { panic(err) }
	return_field := find_flight_element(root, 'return-date') or {
		panic('missing return date field')
	}
	assert !return_field.enabled
	assert return_field.frame.height == 32
	assert (find_flight_element(root, 'departure') or {
		panic('missing departure field')
	}).frame.height == 32
	assert (find_flight_element(root, 'book') or { panic('missing Book button') }).enabled

	app.flight_type = 'return flight'
	app.return_valid = false
	return_root := ui2.element_from_qml_model(flight_booker_qml_source, app, ui2.rect(0, 0, flight_booker_width, flight_booker_height)) or { panic(err) }
	assert (find_flight_element(return_root, 'return-date') or { panic('missing return field') }).enabled
	assert !(find_flight_element(return_root, 'book') or { panic('missing Book button') }).enabled
}
