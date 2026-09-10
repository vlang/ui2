module main

import ui2

fn find_slider_textbox_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_slider_textbox_element(child, id) {
			return found
		}
	}
	return none
}

fn test_slider_textbox_synchronizes_ranges_and_validates_text() {
	mut app := slider_textbox_demo()
	app.set_horizontal(100)
	assert app.horizontal_value == 100
	assert app.horizontal_text == '100'
	app.set_vertical(-100)
	assert app.vertical_value == -100
	app.apply_horizontal_text(' 25 ')
	assert app.horizontal_value == 25
	assert app.horizontal_valid
	app.apply_vertical_text('-12')
	assert !app.vertical_valid
	assert app.vertical_value == -100
}

fn test_slider_textbox_uses_reusable_slider_controls() {
	app := slider_textbox_demo()
	root := ui2.element_from_vml_model(slider_textbox_vml_source, app, ui2.rect(0, 0, slider_textbox_width, slider_textbox_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	horizontal := find_slider_textbox_element(root, 'horizontal_slider') or {
		panic('missing horizontal slider')
	}
	assert horizontal.kind == .slider
	assert horizontal.min_value == -20
	assert horizontal.max_value == 100
	assert horizontal.step == 1
	vertical := find_slider_textbox_element(root, 'vertical_slider') or {
		panic('missing vertical slider')
	}
	assert vertical.kind == .slider
	assert vertical.orientation == .vertical
	assert vertical.min_value == -100
	assert vertical.max_value == -20
	assert (find_slider_textbox_element(root, 'reset') or { panic('missing reset') }).native_style
}
