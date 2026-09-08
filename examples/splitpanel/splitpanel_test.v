module main

import ui2

fn find_splitpanel_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_splitpanel_element(child, id) {
			return found
		}
	}
	return none
}

fn test_splitpanel_adjusts_and_clamps_both_axes() {
	mut app := initial_splitpanel()
	app.top_more()
	app.left_less()
	assert app.top_weight == 0.33
	assert app.left_weight > 0.289 && app.left_weight < 0.291
	for _ in 0 .. 20 {
		app.left_less()
	}
	assert app.left_weight == 0.18
	app.reset_splits()
	assert app.top_weight == 0.28
	assert app.left_weight == 0.34
}

fn test_splitpanel_vml_reflows_nested_panes() {
	app := initial_splitpanel()
	root := ui2.element_from_vml_model(splitpanel_vml_source, app, ui2.rect(0, 0, splitpanel_width, splitpanel_height)) or { panic(err) }
	wide := ui2.element_from_vml_model(splitpanel_vml_source, app, ui2.rect(0, 0, 1000, splitpanel_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	stage := find_splitpanel_element(root, 'stage') or { panic('missing stage') }
	top := find_splitpanel_element(root, 'top_panel') or { panic('missing top pane') }
	notes := find_splitpanel_element(root, 'split_notes') or { panic('missing notes pane') }
	grid := find_splitpanel_element(root, 'split_grid') or { panic('missing grid pane') }
	wide_grid := find_splitpanel_element(wide, 'split_grid') or { panic('missing wide grid') }
	assert top.frame.height == (stage.frame.height - 10) * app.top_weight
	assert grid.frame.x == notes.frame.width + 8
	assert wide_grid.frame.width > grid.frame.width
	assert grid.children.len == app.rows.len + 1
	assert (find_splitpanel_element(root, 'reset_splits') or { panic('missing reset') }).native_style
}
