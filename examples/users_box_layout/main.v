module main

import os
import ui2

const users_box_width = 880
const users_box_height = 600
const users_box_qml_source = $embed_file('users_box_layout.qml').to_string()
const users_box_capacity = 10
const first_name_max = 20
const last_name_max = 50
const age_max = 3

pub struct FormUser {
pub:
	id         int
	key        string
	first_name string
	last_name  string
	age        string
	country    string
	stripe     string
}

pub struct CountryChoice {
pub:
	id   int
	key  string
	name string
}

pub struct UsersBoxLayoutDemo {
pub:
	countries []CountryChoice
pub mut:
	logo_path      string
	users          []FormUser
	first_name     string
	last_name      string
	age            string
	password       string
	country        string = 'United States'
	online         bool = true
	subscribed     bool
	is_error       bool
	progress       f64
	progress_label string
	status         string
mut:
	next_id int = 1
}

fn users_box_countries() []CountryChoice {
	names := ['United States', 'Canada', 'United Kingdom', 'Australia']
	mut choices := []CountryChoice{cap: names.len}
	for index, name in names {
		choices << CountryChoice{
			id: index + 1
			key: 'country-${index + 1}'
			name: name
		}
	}
	return choices
}

fn users_box_logo_path() string {
	// The Windows image control reads BMP, the others read PNG.
	$if windows {
		return os.real_path(os.join_path(os.dir(@FILE), '..', 'users', 'logo.bmp'))
	} $else {
		return os.real_path(os.join_path(os.dir(@FILE), '..', 'users', 'logo.png'))
	}
}

fn users_box_demo() UsersBoxLayoutDemo {
	mut app := UsersBoxLayoutDemo{
		countries: users_box_countries()
		logo_path: users_box_logo_path()
	}
	app.add_seed('Sam', 'Johnson', '29', 'United States')
	app.add_seed('Kate', 'Williams', '26', 'Canada')
	app.refresh()
	return app
}

fn (mut app UsersBoxLayoutDemo) add_seed(first string, last string, age string, country string) {
	app.users << FormUser{
		id: app.next_id
		key: 'user-${app.next_id}'
		first_name: first
		last_name: last
		age: age
		country: country
		stripe: if app.users.len % 2 == 0 { '#FFFFFF' } else { '#F8FAFC' }
	}
	app.next_id++
}

// refresh keeps the progress bar and its caption in step with the table, the
// pair the original example wires to the same counter.
fn (mut app UsersBoxLayoutDemo) refresh() {
	app.progress = f64(app.users.len) / f64(users_box_capacity)
	app.progress_label = '${app.users.len}/${users_box_capacity}'
	if app.status.len == 0 {
		app.status = 'Fill in the form, then add a user.'
	}
}

fn truncate(value string, max int) string {
	runes := value.runes()
	return if runes.len > max { runes[..max].string() } else { value }
}

fn digits_only(value string) string {
	mut out := []u8{cap: value.len}
	for character in value {
		if character.is_digit() {
			out << character
		}
	}
	return out.bytestr()
}

// Each field caps its own length the way the original textboxes do with
// `max_len`, and the age field additionally refuses anything but digits.
pub fn (mut app UsersBoxLayoutDemo) first_name_changed() {
	app.first_name = truncate(app.first_name, first_name_max)
}

pub fn (mut app UsersBoxLayoutDemo) last_name_changed() {
	app.last_name = truncate(app.last_name, last_name_max)
}

pub fn (mut app UsersBoxLayoutDemo) age_changed() {
	app.age = truncate(digits_only(app.age), age_max)
}

pub fn (mut app UsersBoxLayoutDemo) select_country(name string) {
	app.country = name
}

pub fn (mut app UsersBoxLayoutDemo) toggle_online() {
	app.online = !app.online
}

pub fn (mut app UsersBoxLayoutDemo) toggle_subscribed() {
	app.subscribed = !app.subscribed
}

pub fn (mut app UsersBoxLayoutDemo) add_user() {
	if app.users.len >= users_box_capacity {
		app.status = 'The list is full at ${users_box_capacity} users.'
		return
	}
	if app.first_name.trim_space().len == 0 || app.last_name.trim_space().len == 0
		|| app.age.len == 0 {
		app.is_error = true
		app.status = 'First name, last name, and age are required.'
		return
	}
	app.is_error = false
	app.add_seed(app.first_name.trim_space(), app.last_name.trim_space(), app.age, app.country)
	app.status = '${app.users.last().first_name} ${app.users.last().last_name} added.'
	app.first_name = ''
	app.last_name = ''
	app.age = ''
	app.password = ''
	app.refresh()
}

pub fn (mut app UsersBoxLayoutDemo) reset() {
	app.users = []
	app.next_id = 1
	app.is_error = false
	app.status = 'List cleared.'
	app.refresh()
}

pub fn (mut app UsersBoxLayoutDemo) about() {
	ui2.alert('Users', 'Built with V UI')
}

fn main() {
	ui2.run_qml[UsersBoxLayoutDemo](
		source: users_box_qml_source
		model: users_box_demo()
		title: 'Users (box layout)'
		width: users_box_width
		height: users_box_height
	) or { panic(err) }
}
