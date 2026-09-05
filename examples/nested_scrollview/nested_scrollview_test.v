module main

import ui2

fn find_nested_scroll_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_nested_scroll_element(child, id) {
			return found
		}
	}
	return none
}

fn test_nested_scrollview_builds_twelve_scrollable_boxes() {
	app := initial_nested_scrollview()
	assert app.boxes.len == 12
	assert app.boxes[0].title == 'Box 1'
	assert app.boxes[11].title == 'Box 12'
	assert app.boxes[0].content.split_into_lines().len == 8
}

fn test_nested_scrollview_qml_nests_text_areas_in_outer_scroll() {
	root := ui2.element_from_qml_model(nested_scrollview_qml_source, initial_nested_scrollview(), ui2.rect(0, 0, nested_scrollview_width, nested_scrollview_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	outer := find_nested_scroll_element(root, 'outer_scroll') or { panic('missing outer scroll') }
	assert outer.children.len == 12
	assert outer.children[0].key == '1'
	assert outer.children[0].children.len == 3
	text_area := outer.children[0].children[2]
	assert text_area.readonly
	assert text_area.text.split_into_lines().len == 8
}
