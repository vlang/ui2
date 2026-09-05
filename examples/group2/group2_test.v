module main

import ui2

fn find_group2_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_group2_element(child, id) {
			return found
		}
	}
	return none
}

fn test_group2_fills_ipsum_and_validates_submission() {
	mut app := Group2Demo{}
	app.more_ipsum()
	assert app.first_ipsum == 'Lorem ipsum'
	assert app.second_ipsum == 'dolor sit amet'
	app.submit()
	assert app.status == 'Enter your full name first.'
	app.full_name = '  Ada Lovelace '
	app.submit()
	assert app.full_name == 'Ada Lovelace'
	assert app.status.contains('V likes you too')
}

fn test_group2_qml_contains_bound_groups_and_native_buttons() {
	root := ui2.element_from_qml_model(group2_qml_source, Group2Demo{}, ui2.rect(0, 0, group2_width, group2_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	first := find_group2_element(root, 'first_group') or { panic('missing first group') }
	second := find_group2_element(root, 'second_group') or { panic('missing second group') }
	assert first.frame.width == 308
	assert second.frame.x == 356
	assert (find_group2_element(root, 'likes_v') or { panic('missing checkbox') }).checked
	assert (find_group2_element(root, 'more_ipsum') or { panic('missing ipsum button') }).native_style
	assert (find_group2_element(root, 'submit') or { panic('missing submit button') }).native_style
}
