module main

import os
import ui2

fn test_numeric_age_discards_non_digits_and_limits_length() {
	assert numeric_age('2a9🙂7') == '297'
	assert numeric_age('12345') == '123'
}

fn test_limited_text_counts_unicode_characters() {
	assert limited_text('Zoë🙂', 3) == 'Zoë'
	assert limited_text('Kate', 20) == 'Kate'
}

fn find_element_by_id(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_element_by_id(child, id) {
			return found
		}
	}
	return none
}

fn find_element_by_text(element ui2.Element, text string) ?ui2.Element {
	if element.text == text {
		return element
	}
	for child in element.children {
		if found := find_element_by_text(child, text) {
			return found
		}
	}
	return none
}

fn test_users_screen_is_evaluated_from_model_qml() {
	bounds := ui2.rect(0, 0, window_width, window_height)
	assert users_qml_source.contains('bind.text: app.first_name')
	assert users_qml_source.contains('Repeater {')
	assert !users_qml_source.contains('__USER_ROWS__')
	root := ui2.element_from_qml_model(users_qml_source, initial_app(), bounds) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	assert (find_element_by_text(root, 'Add user') or { panic('missing Add user label') }).text == 'Add user'
	assert (find_element_by_text(root, '2/10') or { panic('missing progress label') }).text == '2/10'
	table := find_element_by_id(root, 'users_table') or { panic('missing users table') }
	assert table.persistent_scrollbars
	assert find_element_by_text(table, 'Sam') != none
	assert find_element_by_text(table, 'Kate') != none
	logo := find_element_by_id(root, 'v_logo') or { panic('missing V logo') }
	assert logo.image_path == initial_app().logo_path
	assert os.exists(logo.image_path)
	assert logo.frame == ui2.rect(window_width - 66, window_height - 66, 50, 50)
	country := find_element_by_text(root, 'United States') or { panic('missing country dropdown') }
	assert country.menu.len == 4
	assert country.menu[1].title == 'Canada'
}

fn test_app_add_user_is_only_business_logic() {
	mut app := initial_app()
	app.first_name = ' Grace '
	app.last_name = ' Hopper '
	app.age = '8x5'
	app.country = 'United Kingdom'
	app.add_user()
	assert app.users.len == 3
	assert app.users[2] == User{
		id: 3
		first_name: 'Grace'
		last_name: 'Hopper'
		age: 85
		country: 'United Kingdom'
	}
	assert app.first_name == ''
	assert app.age == ''
}

fn test_app_validation_and_stable_removal() {
	mut app := initial_app()
	app.add_user()
	assert app.is_error
	assert app.users.len == 2
	app.remove_user(1)
	assert app.users.len == 1
	assert app.users[0].id == 2
}
