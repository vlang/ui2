module main

import ui2

fn find_crud_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_crud_element(child, id) {
			return found
		}
	}
	return none
}

fn test_crud_filters_selects_updates_creates_and_deletes() {
	mut app := initial_crud()
	assert app.people.len == 6
	app.filter = 'wo'
	app.filter_changed()
	assert app.visible_people.len == 2

	app.select_person(3)
	assert app.name == 'James'
	assert app.surname == 'Bond'
	app.surname = 'Bourne'
	app.update_person()
	assert app.people[2].display == 'Bourne, James'
	app.delete_person()
	assert app.people.len == 5

	app.filter = ''
	app.name = 'Grace'
	app.surname = 'Hopper'
	app.create_person()
	assert app.people.len == 6
	assert app.people.last().display == 'Hopper, Grace'
}

fn test_crud_vml_builds_filtered_list_and_native_actions() {
	root := ui2.element_from_vml_model(crud_vml_source, initial_crud(), ui2.rect(0, 0, crud_width, crud_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	list := find_crud_element(root, 'people_list') or { panic('missing people list') }
	assert list.children.len == 6
	assert list.children[0].text == 'Man, Iron'
	assert list.children[0].native_style
	create := find_crud_element(root, 'create') or { panic('missing Create button') }
	assert create.native_style
	assert create.frame.y == 184
	filter := find_crud_element(root, 'filter') or { panic('missing filter field') }
	assert filter.frame.height == 32
	assert filter.text_style.size == 13
	assert !(find_crud_element(root, 'update') or { panic('missing Update button') }).enabled
	assert !(find_crud_element(root, 'delete') or { panic('missing Delete button') }).enabled
}
