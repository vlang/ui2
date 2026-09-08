module main

import ui2

const tree_view_widget_width = 460
const tree_view_widget_height = 360
const tree_view_widget_vml_source = $embed_file('tree_view_widget.vml').to_string()

pub struct TreeViewWidgetDemo {
pub mut:
	docs_open bool
	selected  string = 'welcome'
}

pub fn (mut app TreeViewWidgetDemo) toggle_docs() {
	app.docs_open = !app.docs_open
}

pub fn (mut app TreeViewWidgetDemo) select_welcome() {
	app.selected = 'welcome'
}

pub fn (mut app TreeViewWidgetDemo) select_installation() {
	app.selected = 'installation'
}

pub fn (mut app TreeViewWidgetDemo) select_license() {
	app.selected = 'license'
}

fn main() {
	ui2.run_vml[TreeViewWidgetDemo](
		source: tree_view_widget_vml_source
		model: TreeViewWidgetDemo{}
		title: 'Tree View'
		width: tree_view_widget_width
		height: tree_view_widget_height
	) or { panic(err) }
}
