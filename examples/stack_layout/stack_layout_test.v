module main

import ui2

fn find_stack_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_stack_element(child, id) {
			return found
		}
	}
	return none
}

fn test_stack_layout_demo_wraps_tags_without_resizing_them() {
	root := ui2.element_from_qml_model(stack_qml_source, StackLayoutDemo{}, ui2.rect(0, 0,
		stack_width, stack_height)) or { panic(err) }
	stack := find_stack_element(root, 'tags') or { panic('missing tags stack') }
	assert stack.children.len == 6
	assert stack.children[0].frame == ui2.rect(10, 10, 96, 34)
	assert stack.children[2].frame == ui2.rect(242, 10, 80, 34)
	assert stack.children[3].frame == ui2.rect(10, 52, 110, 34)
	assert stack.children[5].frame == ui2.rect(10, 94, 70, 34)
}
