module main

import ui2

fn find_textbox_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_textbox_element(child, id) {
			return found
		}
	}
	return none
}

fn test_textbox_demo_updates_character_count_and_clears() {
	mut app := TextboxDemo{
		notes: 'V is fun 🙂'
	}
	app.update_status()
	assert app.status == '10 characters'
	app.clear()
	assert app.notes == ''
	assert app.status == '0 characters'
}

fn test_textbox_qml_contains_editable_and_readonly_areas() {
	root := ui2.element_from_qml_model(textbox_qml_source, TextboxDemo{}, ui2.rect(0, 0, textbox_width, textbox_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }

	notes := find_textbox_element(root, 'notes') or { panic('missing editable notes') }
	preview := find_textbox_element(root, 'preview') or { panic('missing preview') }
	assert !notes.readonly
	assert preview.readonly
	assert !preview.hidden
	assert (find_textbox_element(root, 'clear') or { panic('missing Clear button') }).native_style
}
