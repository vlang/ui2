module main

import ui2

const window_width = 780
const window_height = 420
const maximum_users = 10
const users_qml_source = $embed_file('users.qml').to_string()

pub struct User {
pub:
	id         int
	first_name string
	last_name  string
	age        int
	country    string
}

pub struct App {
pub:
	max_users int = maximum_users
pub mut:
	first_name          string
	last_name           string
	age                 string
	password            string
	country             string = 'United States'
	online_registration bool = true
	subscribe           bool
	show_help           bool
	is_error            bool
	users               []User
	next_id             int = 3
}

fn initial_app() App {
	return App{
		users: [
			User{
				id: 1
				first_name: 'Sam'
				last_name: 'Johnson'
				age: 29
				country: 'United States'
			},
			User{
				id: 2
				first_name: 'Kate'
				last_name: 'Williams'
				age: 26
				country: 'Canada'
			},
		]
	}
}

fn limited_text(value string, maximum int) string {
	characters := value.runes()
	if characters.len <= maximum {
		return value
	}
	return characters[..maximum].string()
}

fn numeric_age(value string) string {
	mut characters := []rune{cap: 3}
	for character in value.runes() {
		if character >= `0` && character <= `9` && characters.len < 3 {
			characters << character
		}
	}
	return characters.string()
}

pub fn (mut app App) clear_error() {
	app.is_error = false
}

pub fn (mut app App) add_user() {
	if app.users.len >= app.max_users {
		return
	}
	first := limited_text(app.first_name.trim_space(), 20)
	last := limited_text(app.last_name.trim_space(), 50)
	age := numeric_age(app.age)
	if first.len == 0 || last.len == 0 || age.len == 0 {
		app.is_error = true
		return
	}
	app.users << User{
		id: app.next_id
		first_name: first
		last_name: last
		age: age.int()
		country: app.country
	}
	app.next_id++
	app.first_name = ''
	app.last_name = ''
	app.age = ''
	app.password = ''
	app.is_error = false
	ui2.focus('first_name')
}

pub fn (mut app App) remove_user(id int) {
	app.users = app.users.filter(it.id != id)
}

pub fn (mut app App) open_help() {
	app.show_help = true
}

pub fn (mut app App) close_help() {
	app.show_help = false
}

fn main() {
	ui2.run_qml[App](
		source: users_qml_source
		model: initial_app()
		title: 'V UI Demo'
		width: window_width
		height: window_height
	) or {
		panic(err)
	}
}
