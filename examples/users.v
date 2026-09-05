module main

import ui2

const window_width = 780
const window_height = 420
const maximum_users = 10
const desktop_form_width = 210.0
const desktop_table_x = 244.0
const users_qml_template = $embed_file('users.qml').to_string()

struct User {
	first_name string
	last_name  string
	age        int
	country    string
}

@[heap]
struct State {
mut:
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
}

const users_state = &State{
	users: [
		User{
			first_name: 'Sam'
			last_name: 'Johnson'
			age: 29
			country: 'United States'
		},
		User{
			first_name: 'Kate'
			last_name: 'Williams'
			age: 26
			country: 'Canada'
		},
	]
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

fn qml_quote(value string) string {
	escaped := value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t')
	return '"${escaped}"'
}

fn qml_bool(value bool) string {
	return if value { 'true' } else { 'false' }
}

fn table_cell_qml(id string, value string, x f64, width f64, color string, bold bool) string {
	return 'Label {
		id: ${id}
		text: ${qml_quote(value)}
		x: ${x + 7}
		y: 0
		width: ${width - 14}
		height: 32
		color: ${color}
		font_size: 13
		bold: ${qml_bool(bold)}
	}'
}

fn users_rows_qml(width f64, users []User) string {
	first_width := width * 0.23
	last_width := width * 0.23
	age_width := width * 0.12
	country_width := width - first_width - last_width - age_width
	mut rows := ''
	for index, user in users {
		y := 32.0 + f64(index) * 34.0
		background := if index % 2 == 0 { '#FFFFFF' } else { '#F1F5F9' }
		rows += '
		Rectangle {
			id: user-row-${index}
			x: 0
			y: ${y}
			width: ${width}
			height: 32
			background: ${background}
			${table_cell_qml('user-${index}-first', user.first_name, 0, first_width, '#1F2937',
		false)}
			${table_cell_qml('user-${index}-last', user.last_name, first_width, last_width,
		'#1F2937', false)}
			${table_cell_qml('user-${index}-age', user.age.str(), first_width + last_width,
		age_width, '#1F2937', false)}
			${table_cell_qml('user-${index}-country', user.country, first_width + last_width + age_width,
		country_width, '#1F2937', false)}
		}'
	}
	return rows
}

fn users_qml(bounds ui2.Rect, state &State) string {
	compact := bounds.width < 700
	form_width := if compact { bounds.width - 32 } else { desktop_form_width }
	table_left := if compact { 16.0 } else { desktop_table_x }
	table_top := if compact { 414.0 } else { 16.0 }
	table_width := if compact { form_width } else { bounds.width - desktop_table_x - 16 }
	available_table_height := bounds.height - table_top - 16
	table_height := if compact && available_table_height > 220 {
		available_table_height
	} else {
		270.0
	}
	first_width := table_width * 0.23
	last_width := table_width * 0.23
	age_width := table_width * 0.12
	country_width := table_width - first_width - last_width - age_width
	input_background := if state.is_error { '#FFEEEE' } else { '#FFFFFF' }
	progress_width := 170.0 * f64(state.users.len) / maximum_users
	validation_left := if compact { 16.0 } else { desktop_table_x }
	validation_top := if compact { 390.0 } else { 302.0 }
	validation_width := if compact { form_width } else { table_width - 112 }
	help_left := if bounds.width > 320 { (bounds.width - 320) / 2 } else { 0.0 }
	mut source := users_qml_template
	replacements := {
		'__FORM_WIDTH__':           form_width.str()
		'__INPUT_BACKGROUND__':     input_background
		'__ONLINE_CHECKED__':       qml_bool(state.online_registration)
		'__SUBSCRIBE_CHECKED__':    qml_bool(state.subscribe)
		'__PROGRESS_WIDTH__':       progress_width.str()
		'__PROGRESS_LABEL_WIDTH__': (form_width - 176).str()
		'__USER_COUNT__':           state.users.len.str()
		'__MAXIMUM_USERS__':        maximum_users.str()
		'__TABLE_LEFT__':           table_left.str()
		'__TABLE_TOP__':            table_top.str()
		'__TABLE_WIDTH__':          table_width.str()
		'__TABLE_HEIGHT__':         table_height.str()
		'__TABLE_FIRST_X__':        '7'
		'__TABLE_FIRST_WIDTH__':    (first_width - 14).str()
		'__TABLE_LAST_X__':         (first_width + 7).str()
		'__TABLE_LAST_WIDTH__':     (last_width - 14).str()
		'__TABLE_AGE_X__':          (first_width + last_width + 7).str()
		'__TABLE_AGE_WIDTH__':      (age_width - 14).str()
		'__TABLE_COUNTRY_X__':      (first_width + last_width + age_width + 7).str()
		'__TABLE_COUNTRY_WIDTH__':  (country_width - 14).str()
		'__LOGO_HIDDEN__':          qml_bool(compact)
		'__LOGO_X__':               (desktop_table_x + table_width - 92).str()
		'__VALIDATION_HIDDEN__':    qml_bool(!state.is_error)
		'__VALIDATION_LEFT__':      validation_left.str()
		'__VALIDATION_TOP__':       validation_top.str()
		'__VALIDATION_WIDTH__':     validation_width.str()
		'__HELP_HIDDEN__':          qml_bool(!state.show_help)
		'__HELP_LEFT__':            help_left.str()
	}
	for placeholder, value in replacements {
		source = source.replace(placeholder, value)
	}
	source = source.replace('__FIRST_NAME__', qml_quote(state.first_name))
	source = source.replace('__LAST_NAME__', qml_quote(state.last_name))
	source = source.replace('__AGE__', qml_quote(state.age))
	source = source.replace('__PASSWORD__', qml_quote(state.password))
	source = source.replace('__COUNTRY__', qml_quote(state.country))
	source = source.replace('__USER_ROWS__', users_rows_qml(table_width, state.users))
	return source
}

fn build_screen() ui2.Element {
	state := unsafe { users_state }
	bounds := ui2.bounds()
	source := users_qml(bounds, state)
	return ui2.element_from_qml(source, ui2.rect(0, 0, bounds.width, bounds.height)) or {
		panic('invalid users QML: ${err}')
	}
}

fn update_field(event string) {
	mut state := unsafe { users_state }
	raw := ui2.text(event)
	value := match event {
		'first-name' { limited_text(raw, 20) }
		'last-name' { limited_text(raw, 50) }
		'age' { numeric_age(raw) }
		'password' { limited_text(raw, 20) }
		else { raw }
	}
	if value != raw {
		ui2.set_text(event, value)
	}
	match event {
		'first-name' {
			state.first_name = value
		}
		'last-name' {
			state.last_name = value
		}
		'age' {
			state.age = value
		}
		'password' {
			state.password = value
		}
		else {}
	}
	state.is_error = false
	ui2.refresh()
}

fn add_user() {
	mut state := unsafe { users_state }
	state.first_name = limited_text(ui2.text('first-name').trim_space(), 20)
	state.last_name = limited_text(ui2.text('last-name').trim_space(), 50)
	state.age = numeric_age(ui2.text('age'))
	state.password = limited_text(ui2.text('password'), 20)
	selected_country := ui2.text('country')
	if selected_country.len > 0 {
		state.country = selected_country
	}
	if state.users.len >= maximum_users {
		return
	}
	if state.first_name.len == 0 || state.last_name.len == 0 || state.age.len == 0 {
		state.is_error = true
		ui2.refresh()
		return
	}
	state.users << User{
		first_name: state.first_name
		last_name: state.last_name
		age: state.age.int()
		country: state.country
	}
	state.first_name = ''
	state.last_name = ''
	state.age = ''
	state.password = ''
	state.is_error = false
	ui2.set_text('first-name', '')
	ui2.set_text('last-name', '')
	ui2.set_text('age', '')
	ui2.set_text('password', '')
	ui2.refresh()
	ui2.focus('first-name')
}

fn handle_event(event string) {
	mut state := unsafe { users_state }
	match event {
		'first-name', 'last-name', 'age', 'password' {
			update_field(event)
		}
		'country' {
			selected := ui2.text('country')
			if selected.len > 0 {
				state.country = selected
			}
			ui2.refresh()
		}
		'online-registration' {
			state.online_registration = !state.online_registration
			ui2.refresh()
		}
		'subscribe' {
			state.subscribe = !state.subscribe
			ui2.refresh()
		}
		'add-user' {
			add_user()
		}
		'help' {
			state.show_help = true
			ui2.refresh()
		}
		'close-help' {
			state.show_help = false
			ui2.refresh()
		}
		else {}
	}
}

fn main() {
	$if macos {
		ui2.run_window('V UI Demo', window_width, window_height, build_screen, handle_event)
	} $else $if windows {
		ui2.run_window('V UI Demo', window_width, window_height, build_screen, handle_event)
	} $else {
		ui2.run(build_screen, handle_event)
	}
}
