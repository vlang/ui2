module main

import math
import ui2

fn find_responsive(element ui2.Element, id string) ?ui2.Element {
	if element.id == id { return element }
	for child in element.children {
		if found := find_responsive(child, id) { return found }
	}
	return none
}

fn test_responsive_grid_changes_column_count_and_clamps_featured_span() {
	app := ResponsiveApp{}
	wide := responsive_tree(app, ui2.rect(0, 0, 1000, 780))!
	compact := responsive_tree(app, ui2.rect(0, 0, 390, 780))!
	ui2.validate_element_tree(wide)!
	ui2.validate_element_tree(compact)!
	wide_grid := find_responsive(wide, 'projects') or { panic('missing grid') }
	compact_grid := find_responsive(compact, 'projects') or { panic('missing compact grid') }
	assert wide_grid.frame.width == 952
	assert compact_grid.frame.width == 342
	assert wide_grid.children.len == 3 && compact_grid.children.len == 3
	// Three 306 2/3-unit columns with 16-unit gaps: the featured card spans two.
	assert math.abs(wide_grid.children[0].frame.width - 629.3333333333334) < 0.0001
	assert math.abs(wide_grid.children[1].frame.x - 645.3333333333334) < 0.0001
	assert compact_grid.children[0].frame.width == 342
	assert compact_grid.children[1].frame.x == 0
	assert compact_grid.children[1].frame.y > compact_grid.children[0].frame.y
	wide_toolbar := find_responsive(wide, 'toolbar') or { panic('missing toolbar') }
	compact_toolbar := find_responsive(compact, 'toolbar') or { panic('missing toolbar') }
	assert wide_toolbar.frame.height == 40
	assert compact_toolbar.frame.height == 92
	assert app.created == 0
}

fn test_responsive_build_keeps_control_identity_and_reads_updated_model() {
	mut app := ResponsiveApp{}
	first := responsive_tree(app, ui2.rect(0, 0, 1000.5, 780))!
	app.created = 2
	second := responsive_tree(app, ui2.rect(0, 0, 390.25, 780))!
	for id in ['search', 'create', 'create-featured', 'project-1', 'project-2'] {
		assert (find_responsive(first, id) or { panic('missing ${id}') }).id == id
		assert (find_responsive(second, id) or { panic('missing ${id}') }).id == id
	}
	count := find_responsive(second, 'count') or { panic('missing count') }
	assert count.text == 'Created: 2'
	grid := find_responsive(second, 'projects') or { panic('missing grid') }
	assert grid.frame.width == 342.25
}
