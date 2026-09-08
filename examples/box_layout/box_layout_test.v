module main

import ui2

fn find_box_layout_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_box_layout_element(child, id) {
			return found
		}
	}
	return none
}

fn test_box_layout_vml_keeps_fixed_and_relative_geometry() {
	root := ui2.element_from_vml_model(box_layout_vml_source, BoxLayoutDemo{}, ui2.rect(0, 0, box_layout_width, box_layout_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	canvas := find_box_layout_element(root, 'canvas') or { panic('missing canvas') }
	assert canvas.frame.width == 488
	assert canvas.frame.height == 290
	red := find_box_layout_element(root, 'red') or { panic('missing fixed rectangle') }
	assert red.frame.width == 72
	green := find_box_layout_element(root, 'green') or { panic('missing stretch rectangle') }
	assert green.frame.width == 352
	assert green.frame.height == 210
	blue := find_box_layout_element(root, 'blue') or { panic('missing anchored rectangle') }
	assert blue.frame.x == 244
	assert blue.frame.y == 145
	black := find_box_layout_element(root, 'black_anchor') or { panic('missing nested anchor') }
	assert black.frame.x == 8
	assert black.frame.width == 40
}

fn test_box_layout_vml_keeps_the_blue_caption_clear_of_the_corner_anchor() {
	root := ui2.element_from_vml_model(box_layout_vml_source, BoxLayoutDemo{}, ui2.rect(0, 0, box_layout_width, box_layout_height)) or { panic(err) }

	blue := find_box_layout_element(root, 'blue') or { panic('missing anchored rectangle') }
	caption := find_box_layout_element(root, 'blue_caption') or { panic('missing caption') }
	white := find_box_layout_element(root, 'white_anchor') or { panic('missing corner anchor') }

	// Both frames are canvas relative. The corner anchor is painted after the
	// blue rectangle, so anything the caption draws underneath it is invisible.
	caption_right := blue.frame.x + caption.frame.x + caption.frame.width
	assert caption_right + 12 <= white.frame.x
}
