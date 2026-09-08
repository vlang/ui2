module main

import ui2

fn find_accordion_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_accordion_element(child, id) {
			return found
		}
	}
	return none
}

fn test_accordion_opens_one_section_and_collapses_it() {
	mut app := initial_accordion()
	app.toggle_section(4)
	assert app.open_id == 4
	assert app.status == 'Group is open.'
	app.toggle_section(4)
	assert app.open_id == -1
	assert app.status == 'All sections are collapsed.'
}

fn test_accordion_vml_expands_and_offsets_following_sections() {
	mut app := initial_accordion()
	app.toggle_section(2)
	root := ui2.element_from_vml_model(accordion_vml_source, app, ui2.rect(0, 0, accordion_width, accordion_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	list := find_accordion_element(root, 'section_list') or { panic('missing section list') }
	assert list.children.len == 5
	assert list.children[0].frame.height == 40
	assert list.children[1].frame.height == 160
	assert list.children[2].frame.y == 224
	assert list.children[1].children[0].native_style
	assert !list.children[1].children[1].hidden
	assert list.children[2].children[1].hidden
}
