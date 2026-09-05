module main

import os
import ui2

fn find_rasterview_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_rasterview_element(child, id) {
			return found
		}
	}
	return none
}

fn test_rasterview_uses_bundled_logo_and_toggles_details() {
	mut app := initial_rasterview()
	assert os.exists(app.image_path)
	assert app.image_path.ends_with('.png') || app.image_path.ends_with('.bmp')
	app.toggle_details()
	assert !app.show_details
	assert app.status == 'Image details hidden.'
}

fn test_rasterview_qml_centers_image_in_responsive_frame() {
	root := ui2.element_from_qml_model(rasterview_qml_source, initial_rasterview(), ui2.rect(0, 0, rasterview_width, rasterview_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	frame := find_rasterview_element(root, 'image_frame') or { panic('missing image frame') }
	logo := find_rasterview_element(root, 'logo') or { panic('missing logo') }
	assert logo.image_path == raster_logo_path()
	assert logo.frame.width == 260
	assert logo.frame.x == (frame.frame.width - 260) / 2
	assert (find_rasterview_element(root, 'toggle_details') or {
		panic('missing details button')
	}).native_style
}
