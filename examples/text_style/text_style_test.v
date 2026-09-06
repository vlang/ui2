module main

import ui2

fn find_text_style_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_text_style_element(child, id) {
			return found
		}
	}
	return none
}

fn test_font_family_name_keeps_families_and_drops_their_variants() {
	assert font_family_name('Roboto-Regular')? == 'Roboto'
	assert font_family_name('HelveticaNeue')? == 'HelveticaNeue'
	assert font_family_name('Georgia')? == 'Georgia'
	// "Roman" is only a suffix when a hyphen separates it, so this family keeps its name.
	assert font_family_name('Times New Roman')? == 'Times New Roman'
	assert font_family_name('Palatino-Roman')? == 'Palatino'
	// Weight and slant are style flags in ui2, not separate families.
	assert font_family_name('Roboto-Bold') == none
	assert font_family_name('DejaVuSans-Oblique') == none
	assert font_family_name('Inter-SemiBold') == none
	// Variable fonts are skipped for the same reason ui2's own index skips them.
	assert font_family_name('Roboto[wdth,wght]') == none
	assert font_family_name('OpenSansVariableFont') == none
}

fn test_text_style_always_offers_a_usable_family_list() {
	app := text_style_demo()
	assert app.fonts.len > 0
	assert app.fonts.len <= text_style_max_fonts
	assert app.fonts.first().id == 1
	assert app.fonts.map(it.key).first() == 'font-1'
	assert app.selected == 1
	assert app.family == app.fonts.first().family
	assert app.family.len > 0
	assert app.status.contains('${app.fonts.len} families found')
}

fn test_text_style_size_and_emphasis_are_reported() {
	mut app := text_style_demo()
	app.size_choice = '44'
	app.size_changed()
	assert app.font_size == 44
	assert app.status.contains('44 pt')
	app.bold = true
	app.italic = true
	app.emphasis_changed()
	assert app.status.contains('bold italic')
	// A nonsense size falls back to something drawable rather than to zero.
	app.size_choice = 'huge'
	app.size_changed()
	assert app.font_size == 6
}

fn test_text_style_qml_applies_the_chosen_family_to_the_preview() {
	mut app := text_style_demo()
	if app.fonts.len > 1 {
		app.choose_font(2)
		assert app.selected == 2
	}
	app.bold = true
	app.size_choice = '24'
	app.size_changed()
	frame := ui2.rect(0, 0, text_style_width, text_style_height)
	root := ui2.element_from_qml_model(text_style_qml_source, app, frame) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	preview := find_text_style_element(root, 'preview_text') or { panic('missing preview') }
	assert preview.text == app.sample
	assert preview.text_style.font_family == app.family
	assert preview.text_style.size == 24
	assert preview.text_style.bold
	list := find_text_style_element(root, 'font_list') or { panic('missing font list') }
	assert list.children.len == app.fonts.len
	assert list.children[0].text == app.fonts[0].family
	assert (find_text_style_element(root, 'bold') or { panic('missing bold') }).checked
}
