module main

import ui2

fn find_demo_label_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_demo_label_element(child, id) {
			return found
		}
	}
	return none
}

fn test_demo_label_vml_centers_the_original_text() {
	root := ui2.element_from_vml_model(demo_label_vml_source, DemoLabel{}, ui2.rect(0, 0, demo_label_width, demo_label_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	label := find_demo_label_element(root, 'centered_label') or { panic('missing label') }
	assert label.text == 'Centered text'
	assert label.text_style.align == .center
	assert label.frame.width == 340
	assert label.frame.height == 140
}
