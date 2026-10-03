module main

import os
import ui2

const responsive_source = $embed_file('responsive_layout.vml').to_string()

pub struct Project {
pub:
	id          int
	title       string
	description string
}

pub struct ResponsiveApp {
pub mut:
	created  int
	projects []Project = [
		Project{ id: 1, title: 'Design system', description: 'Shared controls and typography' },
		Project{ id: 2, title: 'Desktop app', description: 'One layout across window sizes' },
	]
}

pub fn (mut app ResponsiveApp) create_project() {
	app.created++
}

fn main() {
	ui2.run_vml[ResponsiveApp](
		source: responsive_source
		model:  ResponsiveApp{}
		title:  'UI2 · Responsive layout'
		width:  if '--compact' in os.args { 390 } else { 1000 }
		height: 780
	) or { panic(err) }
}
