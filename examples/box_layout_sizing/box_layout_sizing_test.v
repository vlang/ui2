module main

import ui2

fn find_box_sizing_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_box_sizing_element(child, id) {
			return found
		}
	}
	return none
}

fn test_box_layout_sizing_demo_uses_fixed_and_weighted_widths() {
	root := ui2.element_from_vml_model(box_sizing_vml_source, BoxLayoutSizingDemo{}, ui2.rect(0, 0, box_sizing_width, box_sizing_height)) or { panic(err) }
	actions := find_box_sizing_element(root, 'actions') or { panic('missing actions box') }
	assert actions.children.len == 3
	assert actions.children[0].frame == ui2.rect(10, 10, 88, 76)
	assert actions.children[1].frame == ui2.rect(106, 10, 164, 76)
	assert actions.children[2].frame == ui2.rect(278, 10, 82, 76)
}
