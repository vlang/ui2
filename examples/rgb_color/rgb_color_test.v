module main

import ui2

fn find_rgb_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_rgb_element(child, id) {
			return found
		}
	}
	return none
}

fn test_rgb_color_updates_preview_and_rejects_invalid_components() {
	mut app := RgbColorDemo{}
	app.red = '255'
	app.green = '100'
	app.blue = '0'
	app.update_color()
	assert app.valid
	assert app.preview_color == '#FF6400'
	assert app.message == 'rgb(255, 100, 0)'

	app.blue = '256'
	app.update_color()
	assert !app.valid
	assert app.preview_color == '#FFFFFF'
}

fn test_rgb_color_vml_uses_dynamic_preview_and_native_button() {
	root := ui2.element_from_vml_model(rgb_color_vml_source, RgbColorDemo{}, ui2.rect(0, 0, rgb_color_width, rgb_color_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	assert (find_rgb_element(root, 'preview') or { panic('missing preview') }).box.bg == 0x808080
	button := find_rgb_element(root, 'show_color') or { panic('missing Show RGB button') }
	assert button.native_style
	assert button.action_id.len > 0
}
