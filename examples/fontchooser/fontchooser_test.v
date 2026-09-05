module main

import ui2

fn find_fontchooser_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_fontchooser_element(child, id) {
			return found
		}
	}
	return none
}

fn test_fontchooser_updates_and_resets_style() {
	mut app := FontChooserDemo{}
	app.font_choice = 'Monospace'
	app.size_choice = '24'
	app.color_choice = 'Blue'
	app.italic = true
	app.style_changed()
	assert app.font_family == 'Courier New'
	assert app.font_size == 24
	assert app.text_color == '#1D4ED8'
	assert app.status == 'Monospace, 24 pt, blue'
	app.reset_style()
	assert app.font_family == ''
	assert app.bold
	assert !app.italic
}

fn test_fontchooser_qml_forwards_dynamic_text_style() {
	mut app := FontChooserDemo{}
	app.font_choice = 'Serif'
	app.size_choice = '36'
	app.color_choice = 'Purple'
	app.italic = true
	app.style_changed()
	root := ui2.element_from_qml_model(fontchooser_qml_source, app, ui2.rect(0, 0, fontchooser_width, fontchooser_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	preview := find_fontchooser_element(root, 'preview_editor') or { panic('missing preview') }
	assert preview.text_style.font_family == 'Times New Roman'
	assert preview.text_style.size == 36
	assert preview.text_style.color == 0x7e22ce
	assert preview.text_style.bold
	assert preview.text_style.italic
	assert (find_fontchooser_element(root, 'reset_style') or {
		panic('missing reset button')
	}).native_style
}
