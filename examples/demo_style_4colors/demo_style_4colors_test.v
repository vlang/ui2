module main

import ui2

fn find_style_colors_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_style_colors_element(child, id) {
			return found
		}
	}
	return none
}

fn test_four_color_style_switches_complete_palettes() {
	mut app := StyleFourColorsDemo{}
	app.palette = 'Sunset'
	app.palette_changed()
	assert app.color0 == '#FFF7ED'
	assert app.color1 == '#FED7AA'
	assert app.color2 == '#F97316'
	assert app.color3 == '#7C2D12'
	app.apply_palette()
	assert app.status == 'Sunset palette applied to the preview.'
}

fn test_four_color_style_qml_applies_model_colors() {
	mut app := StyleFourColorsDemo{}
	app.palette = 'Forest'
	app.palette_changed()
	root := ui2.element_from_qml_model(style_colors_qml_source, app, ui2.rect(0, 0, style_colors_width, style_colors_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	assert (find_style_colors_element(root, 'color0') or { panic('missing color 0') }).box.bg == 0xf0fdf4
	assert (find_style_colors_element(root, 'color3') or { panic('missing color 3') }).box.bg == 0x14532d
	palette := find_style_colors_element(root, 'palette') or { panic('missing palette dropdown') }
	assert palette.menu.len == 4
	assert (find_style_colors_element(root, 'sample_enabled') or {
		panic('missing sample checkbox')
	}).checked
	assert (find_style_colors_element(root, 'apply_palette') or {
		panic('missing apply button')
	}).native_style
}
