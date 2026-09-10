module main

import ui2

fn find_justified_label(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_justified_label(child, id) {
			return found
		}
	}
	return none
}

fn test_label_justify_vml_preserves_alignment_and_clipping_frame() {
	root := ui2.element_from_vml_model(label_justify_vml_source, LabelJustifyDemo{}, ui2.rect(0, 0, label_justify_width, label_justify_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	assert (find_justified_label(root, 'left_label') or { panic('missing left label') }).text_style.align == .left
	assert (find_justified_label(root, 'center_label') or { panic('missing center label') }).text_style.align == .center
	assert (find_justified_label(root, 'right_label') or { panic('missing right label') }).text_style.align == .right
	clipped := find_justified_label(root, 'clipped_label') or { panic('missing clipped label') }
	assert clipped.frame.width == 190
	assert clipped.text_style.lines == 1
}
