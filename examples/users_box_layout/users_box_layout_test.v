module main

import ui2

fn find_users_box_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_users_box_element(child, id) {
			return found
		}
	}
	return none
}

fn test_users_box_seeds_the_table_and_its_progress_bar() {
	app := users_box_demo()
	assert app.users.len == 2
	assert app.users.map(it.key) == ['user-1', 'user-2']
	assert app.users[0].first_name == 'Sam'
	assert app.users[1].country == 'Canada'
	assert app.progress == 0.2
	assert app.progress_label == '2/10'
	assert app.country == 'United States'
	assert app.countries.len == 4
}

fn test_users_box_requires_the_three_mandatory_fields() {
	mut app := users_box_demo()
	app.first_name = 'Ada'
	app.add_user()
	assert app.is_error
	assert app.users.len == 2
	assert app.status == 'First name, last name, and age are required.'
	app.last_name = 'Lovelace'
	app.age = '36'
	app.select_country('United Kingdom')
	app.add_user()
	assert !app.is_error
	assert app.users.len == 3
	assert app.users.last().country == 'United Kingdom'
	assert app.progress_label == '3/10'
	// A successful add empties the form, password included.
	assert app.first_name == '' && app.last_name == '' && app.age == '' && app.password == ''
}

fn test_users_box_fields_cap_their_own_length_and_age_takes_digits_only() {
	mut app := users_box_demo()
	app.first_name = 'x'.repeat(40)
	app.first_name_changed()
	assert app.first_name.len == first_name_max
	app.last_name = 'y'.repeat(80)
	app.last_name_changed()
	assert app.last_name.len == last_name_max
	app.age = '3a6b9c1'
	app.age_changed()
	assert app.age == '369'
}

fn test_users_box_stops_at_capacity() {
	mut app := users_box_demo()
	for index in 0 .. 20 {
		app.first_name = 'User'
		app.last_name = 'Number${index}'
		app.age = '30'
		app.add_user()
	}
	assert app.users.len == users_box_capacity
	assert app.progress == 1.0
	assert app.status == 'The list is full at 10 users.'
	app.reset()
	assert app.users.len == 0
	assert app.progress == 0
	assert app.progress_label == '0/10'
}

fn test_users_box_vml_anchors_the_table_pane_to_the_window() {
	app := users_box_demo()
	frame := ui2.rect(0, 0, users_box_width, users_box_height)
	root := ui2.element_from_vml_model(users_box_vml_source, app, frame) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	form := find_users_box_element(root, 'form') or { panic('missing form') }
	table := find_users_box_element(root, 'table') or { panic('missing table') }
	assert form.frame.width == 232
	assert form.frame.x + form.frame.width <= table.frame.x

	// Widening the window leaves the form alone and grows only the table.
	wide := ui2.rect(0, 0, users_box_width + 200, users_box_height)
	grown := ui2.element_from_vml_model(users_box_vml_source, app, wide) or { panic(err) }
	grown_form := find_users_box_element(grown, 'form') or { panic('missing form') }
	grown_table := find_users_box_element(grown, 'table') or { panic('missing table') }
	assert grown_form.frame.width == form.frame.width
	assert grown_table.frame.width == table.frame.width + 200

	rows := find_users_box_element(root, 'user_rows') or { panic('missing rows') }
	assert rows.children.len == 2
	assert (find_users_box_element(root, 'password') or { panic('missing password') }).secure
	assert (find_users_box_element(root, 'add_user') or { panic('missing add') }).tooltip.contains('Required fields')
	assert (find_users_box_element(root, 'online') or { panic('missing checkbox') }).checked
}
