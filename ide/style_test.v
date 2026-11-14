module main

import os
import ui2

fn find_style_ide_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_style_ide_element(child, id) {
			return found
		}
	}
	return none
}

fn test_vss_document_sheet_round_trips() {
	mut app := new_ide_app('.')
	app.style_doc_text = 'Button.primary { background: #123456; opacity: 0.5; }'
	app.style_doc_modified = true
	assert app.apply_style_doc()
	assert app.stylesheet_source.contains('Button.primary')
	app.sync_source()
	assert app.source_text.contains('Style {')
	assert app.source_text.contains('Button.primary')

	document := document_from_vml(app.source_text) or { panic(err) }
	assert document.stylesheet_source.trim_space() == app.stylesheet_source.trim_space()
	ui2.element_from_vml(app.source_text, ui2.rect(0, 0, app.form_width, app.form_height)) or {
		panic(err)
	}
}

fn test_vss_component_class_inline_scoped_round_trip() {
	mut app := new_ide_app('.')
	app.add_component('button', 40, 48)
	assert app.set_style_classes('primary big')
	assert app.set_inline_style('opacity: 0.5;')
	app.style_scoped_drafts[app.selected_id] = 'Button.primary { border-radius: 9px; }'
	assert app.apply_scoped_style()
	app.sync_source()
	assert app.source_text.contains('class: "primary big"')
	assert app.source_text.contains('style: "opacity: 0.5;"')
	assert app.source_text.contains('Style {')

	document := document_from_vml(app.source_text) or { panic(err) }
	assert document.components.len == 1
	assert document.components[0].classes == 'primary big'
	assert document.components[0].inline_style == 'opacity: 0.5;'
	assert document.components[0].scoped_style.contains('border-radius')
}

fn test_vss_loader_rejects_import_and_bad_sheet() {
	mut bad_import := 'Screen { id: Form1 width: 400 height: 300 Style { @import "other.vss"; } }'
	if _ := document_from_vml(bad_import) {
		assert false, '@import in Style must fail'
	} else {
		assert err.msg().contains('@import')
	}
	mut bad_sheet := 'Screen { id: Form1 width: 400 height: 300 Style { Button { background red; } } }'
	if _ := document_from_vml(bad_sheet) {
		assert false, 'bad sheet must fail'
	} else {
		assert err.msg().contains('Style')
	}
}

fn test_vss_validators_reject_bad_class_and_inline() {
	mut app := new_ide_app('.')
	app.add_component('label', 8, 8)
	assert app.set_style_classes('good-name _ok')
	assert app.components[0].classes == 'good-name _ok'
	assert !app.set_style_classes('bad!name')
	assert app.components[0].classes == 'good-name _ok'
	assert !app.set_inline_style('--x: 1;')
	assert app.components[0].inline_style == ''
	assert app.set_inline_style('opacity: 0.5;')
	assert app.components[0].inline_style == 'opacity: 0.5;'
}

fn test_vss_undo_redo_covers_stylesheet() {
	mut app := new_ide_app('.')
	app.style_doc_text = 'Label { color: #ff0000; }'
	app.style_doc_modified = true
	assert app.apply_style_doc()
	assert app.stylesheet_source.contains('Label')
	app.undo()
	assert app.stylesheet_source.trim_space() == ''
	app.redo()
	assert app.stylesheet_source.contains('Label')
}

fn test_vss_preview_applies_sheets_live() {
	mut app := new_ide_app('.')
	app.style_doc_text = 'Button { opacity: 0.5; } Button:hover { opacity: 0.9; }'
	app.style_doc_modified = true
	assert app.apply_style_doc()
	app.add_component('button', 40, 48)
	// New components start with empty inline style, so the sheet below can
	// fill opacity (inline would beat the sheet).
	frame := ui2.rect(0, 0, ide_width, ide_height)
	layout := ide_layout(frame, app)
	root := build_preview_form(layout, app)
	plain := ui2.apply_stylesheet(root, ui2.Stylesheet{}, ui2.StyleMatchEnv{
		dark: false
		dpi:  1.0
	})
	mut found_plain := false
	for child in plain.children {
		if child.id == 'preview_1' {
			assert child.box.opacity == 0.5
			found_plain = true
		}
	}
	assert found_plain
	hovered := ui2.apply_stylesheet(root, ui2.Stylesheet{}, ui2.StyleMatchEnv{
		hovered: 'preview_1'
		dark:    false
		dpi:     1.0
	})
	mut found_hover := false
	for child in hovered.children {
		if child.id == 'preview_1' {
			assert child.box.opacity == 0.9
			found_hover = true
		}
	}
	assert found_hover
}

fn test_vss_style_inspector_builds_valid_tree() {
	mut app := new_ide_app('.')
	app.inspector_tab = 'style'
	root := build_ide(ui2.rect(0, 0, ide_width, ide_height), app)
	ui2.validate_element_tree(root) or { panic('form style: ${err}') }
	_ := find_style_ide_element(root, 'style_doc_editor') or { panic('missing doc editor') }
	_ := find_style_ide_element(root, 'style_doc_apply') or { panic('missing doc apply') }
	_ := find_style_ide_element(root, 'style_dark_preview') or { panic('missing dark toggle') }

	app.add_component('button', 32, 40)
	app.inspector_tab = 'style'
	comp_root := build_ide(ui2.rect(0, 0, ide_width, ide_height), app)
	ui2.validate_element_tree(comp_root) or { panic('component style: ${err}') }
	_ := find_style_ide_element(comp_root, 'style_class') or { panic('missing class field') }
	_ := find_style_ide_element(comp_root, 'style_inline') or { panic('missing inline field') }
	_ := find_style_ide_element(comp_root, 'style_scoped_editor') or {
		panic('missing scoped editor')
	}
	_ := find_style_ide_element(comp_root, 'style_enabled') or { panic('missing enabled toggle') }
	_ := find_style_ide_element(comp_root, 'style_reset_inline') or { panic('missing reset') }
	_ := find_style_ide_element(comp_root, 'style_all_lint') or { panic('missing lint-all') }
}

fn test_vss_tab_order_covers_style_fields() {
	mut app := new_ide_app('.')
	app.inspector_tab = 'style'
	assert app.adjacent_inspector_property_id('style_doc_editor', false)? == 'style_doc_editor'
	app.add_component('button', 32, 40)
	assert app.adjacent_inspector_property_id('style_class', false)? == 'style_inline'
	assert app.adjacent_inspector_property_id('style_inline', false)? == 'style_scoped_editor'
	assert app.adjacent_inspector_property_id('style_scoped_editor', false)? == 'style_class'
}

fn test_vss_sample_file_loads_and_applies() {
	source := os.read_file(os.join_path(@VMODROOT, 'ide', 'vss_sample.vml')) or { panic(err) }
	document := document_from_vml(source) or { panic(err) }
	assert document.form_name == 'VssForm'
	assert document.stylesheet_source.contains('Button.primary')
	assert document.components.len == 5
	mut saw_class := false
	mut saw_inline := false
	mut saw_scoped := false
	for component in document.components {
		if component.classes.contains('primary') {
			saw_class = true
		}
		if component.inline_style.contains('opacity') {
			saw_inline = true
		}
		if component.scoped_style.contains('border-color') {
			saw_scoped = true
		}
	}
	assert saw_class
	assert saw_inline
	assert saw_scoped
	ui2.element_from_vml(source, ui2.rect(0, 0, document.form_width, document.form_height)) or {
		panic(err)
	}
}

fn test_vss_enabled_round_trip_and_disabled_preview() {
	mut app := new_ide_app('.')
	app.style_doc_text = 'Button:disabled { opacity: 0.4; }'
	app.style_doc_modified = true
	assert app.apply_style_doc()
	app.add_component('button', 40, 48)
	app.toggle_selected_enabled()
	assert !app.components[0].enabled
	app.sync_source()
	assert app.source_text.contains('enabled: false')
	document := document_from_vml(app.source_text) or { panic(err) }
	assert !document.components[0].enabled
	frame := ui2.rect(0, 0, ide_width, ide_height)
	layout := ide_layout(frame, app)
	root := build_preview_form(layout, app)
	styled := ui2.apply_stylesheet(root, ui2.Stylesheet{}, ui2.StyleMatchEnv{
		dark: false
		dpi:  1.0
	})
	mut found := false
	for child in styled.children {
		if child.id == 'preview_1' {
			assert !child.enabled
			assert child.box.opacity == 0.4
			found = true
		}
	}
	assert found
}

fn test_vss_reset_inline_lets_sheet_win() {
	mut app := new_ide_app('.')
	app.add_component('button', 40, 48)
	app.components[0].background = 0x123456
	app.components[0].color = 0x654321
	app.components[0].font_size = 20
	app.reset_inline_to_sheet_defaults()
	assert app.components[0].background == 0xffffff
	assert app.components[0].color == 0x111111
	assert app.components[0].font_size == 15
}

fn test_vss_dark_preview_toggle() {
	mut app := new_ide_app('.')
	defer {
		app.set_preview_dark(false)
	}
	app.set_preview_dark(true)
	assert app.preview_dark
	assert ui2.stylesheet_dark_mode()
	app.set_preview_dark(false)
	assert !app.preview_dark
	assert ui2.stylesheet_dark_mode() == (ui2.system_appearance() == .dark)
}

fn test_vss_dropdown_with_style_round_trips() {
	mut app := new_ide_app('.')
	app.add_component('dropdown', 40, 48)
	assert app.set_style_classes('menu')
	app.style_scoped_drafts[app.selected_id] = 'Dropdown { border-radius: 9px; }'
	assert app.apply_scoped_style()
	app.sync_source()
	assert app.source_text.contains('Dropdown {')
	assert app.source_text.contains('Option {')
	assert app.source_text.contains('class: "menu"')
	assert app.source_text.contains('Style {')
	document := document_from_vml(app.source_text) or { panic(err) }
	assert document.components.len == 1
	assert document.components[0].classes == 'menu'
	assert document.components[0].scoped_style.contains('border-radius')
}

fn test_vss_lint_all_covers_doc_and_scoped() {
	mut app := new_ide_app('.')
	app.style_doc_text = 'Button { frobnicate: 1; }'
	app.style_doc_modified = true
	app.add_component('button', 40, 48)
	app.style_scoped_drafts[app.selected_id] = 'Label { frobnicate: 2; }'
	app.lint_all_styles()
	assert app.output_open
	assert app.status.contains('document:')
	assert app.status.contains('scoped:')
}

fn test_vss_apply_source_preserves_style_tab() {
	mut app := new_ide_app('.')
	app.inspector_tab = 'style'
	app.apply_source('Screen { id: Form1 width: 760 height: 520 Style { Button { opacity: 0.5; } } Button { id: b1 x: 10 y: 10 width: 100 height: 30 } }') or {
		panic(err)
	}
	assert app.inspector_tab == 'style'
	assert app.stylesheet_source.contains('opacity')
	assert app.components.len == 1
}

fn test_vss_undo_preserves_unapplied_style_drafts() {
	mut app := new_ide_app('.')
	app.add_component('button', 40, 48)
	app.style_doc_text = 'Button { color: #111111; }'
	app.style_doc_modified = true
	assert app.apply_style_doc()
	// Unapplied drafts: must survive an unrelated checkpoint + undo.
	app.style_doc_text = 'Button { color: #222222; }'
	app.style_doc_modified = true
	app.style_scoped_drafts[app.selected_id] = 'Button { border-radius: 9px; }'
	app.checkpoint()
	app.undo()
	assert app.stylesheet_source.contains('#111111')
	assert app.style_doc_modified
	assert app.style_doc_text.contains('#222222')
	assert app.style_scoped_drafts[app.selected_id] == 'Button { border-radius: 9px; }'
	app.redo()
	assert app.style_doc_text.contains('#222222')
	assert app.style_scoped_drafts[app.selected_id] == 'Button { border-radius: 9px; }'
}

fn test_vss_whitespace_scoped_edit_is_clean() {
	mut app := new_ide_app('.')
	app.add_component('label', 8, 8)
	app.style_scoped_drafts[app.selected_id] = 'Label { color: #111111; }'
	assert app.apply_scoped_style()
	app.dirty = false
	app.edit_scoped_draft('  Label { color: #111111; }  \n')
	assert app.selected_id !in app.style_scoped_drafts
	assert !app.dirty
	assert app.status == 'Scoped stylesheet matches saved version.'
}

fn test_vss_scoped_apply_refreshes_lint_banner() {
	mut app := new_ide_app('.')
	app.add_component('button', 40, 48)
	app.style_scoped_drafts[app.selected_id] = 'Button { frobnicate: 1; }'
	assert app.apply_scoped_style()
	assert app.stylesheet_error.contains('scoped:')
}
