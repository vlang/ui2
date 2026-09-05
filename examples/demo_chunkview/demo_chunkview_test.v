module main

import ui2

fn find_chunkview_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_chunkview_element(child, id) {
			return found
		}
	}
	return none
}

fn test_chunkview_toggles_sections_and_alignment() {
	mut app := ChunkviewDemo{}
	app.second_open = false
	app.sections_changed()
	assert app.status == 'Only the first styled chunk is visible.'
	app.alignment = 'Right'
	app.alignment_changed()
	assert app.text_align == 'right'
	app.reset_chunks()
	assert app.first_open
	assert app.second_open
	assert app.text_align == 'center'
}

fn test_chunkview_qml_preserves_nested_text_styles() {
	mut app := ChunkviewDemo{}
	app.second_open = false
	root := ui2.element_from_qml_model(chunkview_qml_source, app, ui2.rect(0, 0, chunkview_width, chunkview_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	first := find_chunkview_element(root, 'first_chunk') or { panic('missing first chunk') }
	second := find_chunkview_element(root, 'second_chunk') or { panic('missing second chunk') }
	assert !first.hidden
	assert second.hidden
	assert first.children[0].text_style.bold
	assert first.children[0].text_style.italic
	assert second.children[1].text_style.font_family == 'Courier New'
	assert second.children[2].text_style.underline
	assert (find_chunkview_element(root, 'reset_chunks') or { panic('missing reset') }).native_style
}
