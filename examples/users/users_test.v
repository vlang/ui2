module main

import os
import ui2

fn users_test_data_path(name string) string {
	return os.join_path(os.temp_dir(), 'ui2-users-example-test-${os.getpid()}-${name}.json')
}

fn reset_test_users_data(path string) {
	if os.exists(path) {
		os.rm(path) or { panic(err) }
	}
}

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

fn test_users_screen_is_evaluated_from_model_vml() {
	data_path := users_test_data_path('screen')
	reset_test_users_data(data_path)
	defer {
		reset_test_users_data(data_path)
	}
	app := app_with_data_path(data_path)
	assert os.exists(data_path)
	bounds := ui2.rect(0, 0, window_width, window_height)
	assert users_vml_source.contains('bind.text: app.first_name')
	assert users_vml_source.contains('Repeater {')
	assert !users_vml_source.contains('__USER_ROWS__')
	root := ui2.element_from_vml_model(users_vml_source, app, bounds) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	add_user := find_element_by_id(root, 'add-user') or { panic('missing Add user button') }
	assert add_user.text == 'Add user'
	assert add_user.native_style
	assert (find_element_by_id(root, 'help') or { panic('missing help button') }).native_style
	assert (find_element_by_id(root, 'close-help') or { panic('missing Close button') }).native_style
	assert (find_element_by_text(root, '2/10') or { panic('missing progress label') }).text == '2/10'
	table := find_element_by_id(root, 'users_table') or { panic('missing users table') }
	assert table.persistent_scrollbars
	assert find_element_by_text(table, 'Sam') != none
	assert find_element_by_text(table, 'Kate') != none
	logo := find_element_by_id(root, 'v_logo') or { panic('missing V logo') }
	assert logo.image_path == app.logo_path
	assert os.exists(logo.image_path)
	assert logo.frame == ui2.rect(window_width - 66, window_height - 66, 50, 50)
	country := find_element_by_text(root, 'United States') or { panic('missing country dropdown') }
	assert country.menu.len == 4
	assert country.menu[1].title == 'Canada'
}

fn test_users_screen_keeps_table_beside_form_at_minimum_width() {
	data_path := users_test_data_path('minimum-width')
	reset_test_users_data(data_path)
	defer {
		reset_test_users_data(data_path)
	}
	mut app := app_with_data_path(data_path)
	app.show_help = true
	resized := ui2.rect(0, 0, window_min_width, 300)
	root := ui2.element_from_vml_model(users_vml_source, app, resized) or { panic(err) }
	page := find_element_by_id(root, 'users_page') or { panic('missing users page scroll') }
	table := find_element_by_id(page, 'users_table') or { panic('missing users table') }
	dialog := find_element_by_id(root, 'help_dialog') or { panic('missing help dialog') }
	assert page.frame == resized
	assert table.frame.x == 244
	assert table.frame.y == 16
	assert table.frame.width == window_min_width - 260
	assert dialog.frame == ui2.rect(190, 118, 320, 145)
	assert !dialog.hidden
	assert find_element_by_id(page, 'help_dialog') == none
}

fn test_app_add_user_is_only_business_logic() {
	data_path := users_test_data_path('add')
	reset_test_users_data(data_path)
	defer {
		reset_test_users_data(data_path)
	}
	mut app := app_with_data_path(data_path)
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
	stored_users := load_users(data_path) or { panic(err) }
	assert stored_users == app.users
}

fn test_app_validation_and_stable_removal() {
	data_path := users_test_data_path('remove')
	reset_test_users_data(data_path)
	defer {
		reset_test_users_data(data_path)
	}
	mut app := app_with_data_path(data_path)
	app.add_user()
	assert app.is_error
	assert app.users.len == 2
	app.remove_user(1)
	assert app.users.len == 1
	assert app.users[0].id == 2
	stored_users := load_users(data_path) or { panic(err) }
	assert stored_users == app.users
}

fn test_users_reload_from_os_temp_json_without_password_data() {
	data_path := users_test_data_path('reload')
	reset_test_users_data(data_path)
	defer {
		reset_test_users_data(data_path)
	}
	assert users_data_path() == os.join_path(os.temp_dir(), users_data_directory, users_data_filename)
	mut app := app_with_data_path(data_path)
	app.first_name = 'Ada'
	app.last_name = 'Lovelace'
	app.age = '36'
	app.password = 'not persisted'
	app.country = 'United Kingdom'
	app.add_user()

	contents := os.read_file(data_path) or { panic(err) }
	assert !contents.contains('password')
	reloaded := app_with_data_path(data_path)
	assert reloaded.users == app.users
	assert reloaded.next_id == 4
}
