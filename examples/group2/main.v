module main

import ui2

const group2_width = 680
const group2_height = 370
const group2_vml_source = $embed_file('group2.vml').to_string()

pub struct Group2Demo {
pub mut:
	first_ipsum  string
	second_ipsum string
	full_name    string
	likes_v      bool = true
	status       string = 'Fill either group to try the controls.'
}

pub fn (mut app Group2Demo) more_ipsum() {
	app.first_ipsum = 'Lorem ipsum'
	app.second_ipsum = 'dolor sit amet'
	app.status = 'Added a little more ipsum.'
}

pub fn (mut app Group2Demo) submit() {
	name := app.full_name.trim_space()
	if name.len == 0 {
		app.status = 'Enter your full name first.'
		return
	}
	app.full_name = name
	app.status = if app.likes_v {
		'Thanks, ${name} — V likes you too!'
	} else {
		'Thanks, ${name}.'
	}
}

fn main() {
	ui2.run_vml[Group2Demo](
		source: group2_vml_source
		model: Group2Demo{}
		title: 'Group 2 Demo'
		width: group2_width
		height: group2_height
	) or { panic(err) }
}
