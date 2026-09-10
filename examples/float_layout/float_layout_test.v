module main

import ui2

fn find_float_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_float_element(child, id) {
			return found
		}
	}
	return none
}

fn test_float_layout_demo_centers_fixed_action() {
	root := ui2.element_from_vml_model(float_vml_source, FloatLayoutDemo{}, ui2.rect(0, 0,
		float_width, float_height)) or { panic(err) }
	canvas := find_float_element(root, 'canvas') or { panic('missing float canvas') }
	action := find_float_element(root, 'center_action') or { panic('missing centered action') }
	assert canvas.frame.width == 360
	assert action.frame == ui2.rect(120, 64, 120, 42)
}
