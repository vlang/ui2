module main

import ui2

const tabs_width = 640
const tabs_height = 400
const tabs_vml_source = $embed_file('tabs.vml').to_string()

pub struct TabPage {
pub:
	id         int
	title      string
	heading    string
	body       string
	background string
}

pub struct TabsDemo {
pub:
	pages []TabPage
pub mut:
	active_tab int = 1
	status     string = 'tab1 selected.'
}

fn initial_tabs() TabsDemo {
	return TabsDemo{
		pages: [
			TabPage{ id: 1, title: 'tab1', heading: 'Buttons', body: 'The original first page contains two buttons.', background: '#F3E8FF' },
			TabPage{ id: 2, title: 'tab2', heading: 'Color preview', body: 'The original second page connects a color box to a rectangle.', background: '#DBEAFE' },
			TabPage{ id: 3, title: 'tab3', heading: 'Double list', body: 'The original third page embeds a double-list component.', background: '#CCFBF1' },
		]
	}
}

pub fn (mut app TabsDemo) select_tab(id int) {
	for page in app.pages {
		if page.id == id {
			app.active_tab = id
			app.status = '${page.title} selected.'
			return
		}
	}
}

fn main() {
	ui2.run_vml[TabsDemo](
		source: tabs_vml_source
		model: initial_tabs()
		title: 'Tabs'
		width: tabs_width
		height: tabs_height
	) or { panic(err) }
}
