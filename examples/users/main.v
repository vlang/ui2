module main

import json2
import os
import ui2

const window_width = 780
const window_height = 420
const window_min_width = 700
const maximum_users = 10
const users_data_directory = 'ui2-users-example'
const users_data_filename = 'users.json'
const users_vml_source = $embed_file('users.vml').to_string()

pub struct User {
pub:
	id         int
	first_name string
	last_name  string
	age        int
	country    string
}

pub struct App {
	data_path string
pub:
	max_users int = maximum_users
	logo_path string
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
	return app_with_data_path(users_data_path())
}

fn app_with_data_path(data_path string) App {
	mut users := default_users()
	if os.exists(data_path) {
		users = load_users(data_path) or {
			eprintln('ui2 users: could not load `${data_path}`: ${err}')
			default_users()
		}
	}
	app := App{
		data_path: data_path
		logo_path: users_logo_path()
		users: users
		next_id: next_user_id(users)
	}
	if !os.exists(data_path) {
		app.persist_users()
	}
	return app
}

fn default_users() []User {
	return [
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

fn users_data_path() string {
	return os.join_path(os.temp_dir(), users_data_directory, users_data_filename)
}

fn load_users(data_path string) ![]User {
	return json2.decode[[]User](os.read_file(data_path)!)!
}

fn next_user_id(users []User) int {
	mut next_id := 1
	for user in users {
		if user.id >= next_id {
			next_id = user.id + 1
		}
	}
	return next_id
}

fn (app &App) save_users() ! {
	os.mkdir_all(os.dir(app.data_path))!
	os.write_file(app.data_path, json2.encode(app.users, escape_unicode: true))!
}

fn (app &App) persist_users() {
	app.save_users() or { eprintln('ui2 users: could not save `${app.data_path}`: ${err}') }
}

fn users_logo_path() string {
	$if windows {
		return os.real_path(os.join_path(os.dir(@FILE), 'logo.bmp'))
	} $else {
		return os.real_path(os.join_path(os.dir(@FILE), 'logo.png'))
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
	app.persist_users()
	ui2.focus('first_name')
}

pub fn (mut app App) remove_user(id int) {
	app.users = app.users.filter(it.id != id)
	app.persist_users()
}

pub fn (mut app App) open_help() {
	app.show_help = true
}

pub fn (mut app App) close_help() {
	app.show_help = false
}

fn main() {
	ui2.run_vml[App](
		source: users_vml_source
		model: initial_app()
		title: 'V UI Demo'
		width: window_width
		height: window_height
		min_width: window_min_width
	) or {
		panic(err)
	}
}
