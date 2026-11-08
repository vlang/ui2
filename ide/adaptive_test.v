module main

import ui2

fn find_adaptive_ide_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_adaptive_ide_element(child, id) {
			return found
		}
	}
	return none
}

fn adaptive_test_app() IdeApp {
	mut app := new_ide_app('.')
	app.snap_to_grid = false
	app.add_component('button', 624, 460)
	app.set_adaptive_enabled(true)
	app.set_layout_axis(true, .end)
	app.set_layout_axis(false, .end)
	return app
}

fn test_adaptive_preview_never_changes_saved_geometry_or_undo_history() {
	mut app := adaptive_test_app()
	source := app.source_text
	before := app.snapshot()
	undo_count := app.undo_stack.len
	app.dirty = false
	app.set_preview_size(390, 844)
	shown := app.selected_component()?
	assert component_frame(shown) == ui2.rect(254, 784, 112, 36)
	assert app.source_text == source
	assert app.snapshot() == before
	assert !app.dirty
	assert app.undo_stack.len == undo_count
	app.nudge_selected(8, 8)
	assert app.snapshot() == before
	assert !app.set_geometry_property('property_width', '200')
	app.set_preview_size(844, 390)
	app.select_edit_class(.any, .any)
	assert app.preview_width == 0
	assert app.preview_height == 0
	assert app.source_text == source
}

fn test_adaptive_variant_geometry_and_rules_round_trip_and_undo_independently() {
	mut app := adaptive_test_app()
	base := component_frame(app.components[0])
	app.set_preview_size(390, 844)
	app.select_edit_class(.compact, .any)
	assert app.editing_variation()
	assert app.set_geometry_property('property_x', '24.5')
	app.set_layout_axis(true, .stretch)
	assert app.set_geometry_property('property_width', '341')
	assert component_frame(app.components[0]) == base
	assert app.components[0].variations.len == 1
	assert app.components[0].variations[0].frame.x == 24.5
	assert app.components[0].variations[0].reference_width == 390
	app.sync_source()
	doc := document_from_vml(app.source_text)!
	assert doc.adaptive
	assert doc.components[0].variations == app.components[0].variations
	assert doc.components[0].layout == app.components[0].layout
	assert component_frame(doc.components[0]) == base
	width := app.components[0].variations[0].frame.width
	app.undo()
	assert app.components[0].variations[0].frame.width != width
	app.redo()
	assert app.components[0].variations[0].frame.width == width
}

fn test_adaptive_snapshot_and_duplicate_do_not_alias_variations() {
	mut app := adaptive_test_app()
	app.select_edit_class(.compact, .any)
	assert app.set_geometry_property('property_x', '24')
	before := app.snapshot()
	app.set_geometry_property('property_x', '40')
	assert before.components[0].variations[0].frame.x == 24
	app.select_edit_class(.any, .any)
	app.duplicate_selected()
	assert app.components.len == 2
	assert app.components[0].variations == app.components[1].variations
	app.select_edit_class(.compact, .any)
	app.set_geometry_property('property_x', '80')
	assert app.components[0].variations[0].frame.x == 40
	assert app.components[1].variations[0].frame.x == 80
}

fn test_adaptive_inherited_class_edits_do_not_change_parent_variant() {
	mut app := adaptive_test_app()
	app.select_edit_class(.compact, .any)
	app.set_geometry_property('property_x', '24')
	app.select_edit_class(.compact, .compact)
	assert app.exact_variation_index(app.components[0]) == -1
	app.set_geometry_property('property_x', '48')
	assert app.components[0].variations.len == 2
	assert app.components[0].variations[0].frame.x == 24
	assert app.components[0].variations[1].frame.x == 48
	app.reset_selected_variation()
	assert app.components[0].variations.len == 1
	assert app.selected_component()?.x == 24
	app.undo()
	assert app.components[0].variations.len == 2
}

fn test_adaptive_designer_and_runtime_have_matching_frames() {
	mut app := adaptive_test_app()
	app.select_edit_class(.compact, .any)
	app.set_geometry_property('property_x', '24')
	app.set_geometry_property('property_width', '342')
	app.set_layout_axis(true, .stretch)
	for size in [ui2.rect(0, 0, 390, 844), ui2.rect(0, 0, 320, 568), ui2.rect(0, 0, 1280, 800)] {
		app.set_preview_size(size.width, size.height)
		displayed := app.selected_component()?
		root := ui2.element_from_vml(app.source_text, size)!
		runtime := find_adaptive_ide_element(root, app.components[0].name)?
		assert component_frame(displayed) == runtime.frame
		assert displayed.layout.hidden == runtime.hidden
	}
}

fn test_adaptive_hidden_variant_is_editable_but_absent_from_preview() {
	mut app := adaptive_test_app()
	app.select_edit_class(.compact, .any)
	component := app.selected_component()?
	app.set_layout_rules(ui2.AdaptiveLayout{ ...component.layout, hidden: true })
	assert !app.components[0].layout.hidden
	assert app.components[0].variations[0].layout.hidden
	frame := ui2.rect(0, 0, ide_width, ide_height)
	designer := build_ide(frame, app)
	_ := find_adaptive_ide_element(designer, 'cmp_1')?
	app.active_tab = 'preview'
	preview := build_ide(frame, app)
	assert find_adaptive_ide_element(preview, 'preview_1') == none
}

fn test_adaptive_new_inspector_and_preview_bar_have_valid_element_trees() {
	mut app := adaptive_test_app()
	app.inspector_tab = 'layout'
	for width in [900.0, 1400.0] {
		for tab in ['designer', 'preview', 'source'] {
			app.active_tab = tab
			root := build_ide(ui2.rect(0, 0, width, 900), app)
			ui2.validate_element_tree(root)!
			_ := find_adaptive_ide_element(root, 'layout_enable')?
			if tab != 'source' {
				_ := find_adaptive_ide_element(root, 'adaptive_toolbar')?
			}
		}
	}
	assert app.adjacent_inspector_property_id('layout_max_height', false)? == 'layout_min_width'
	app.selected_id = 0
	assert app.adjacent_inspector_property_id('layout_breakpoint_height', false)? == 'layout_breakpoint_width'
}

fn test_adaptive_loader_rejects_bad_metadata_without_changing_document() {
	mut app := adaptive_test_app()
	before := app.snapshot()
	bad := 'Screen { adaptive: true width: 760 height: 520 Button { id: bad LayoutVariation { width_class: compact } } }'
	app.apply_source(bad) or {
		assert app.snapshot() == before
		return
	}
	assert false
}

fn test_adaptive_drag_creates_one_undoable_variant_change() {
	mut app := adaptive_test_app()
	app.select_edit_class(.compact, .any)
	shown := app.selected_component()?
	before := app.undo_stack.len
	app.begin_drag(shown.id, 'move', shown.x + 4, shown.y + 4)
	app.drag_to(52, 104)
	app.drag_to(60, 112)
	app.end_drag()
	assert app.undo_stack.len == before + 1
	assert app.components[0].variations.len == 1
	assert app.components[0].variations[0].frame.x == 56
	app.undo()
	assert app.components[0].variations.len == 0
}

fn test_adaptive_resizing_reference_canvas_is_distinct_from_previewing() {
	mut app := adaptive_test_app()
	assert app.set_form_property('form_property_width', '1000')
	assert app.components[0].x == 864
	app.undo()
	assert app.components[0].x == 624
	assert app.form_width == 760
	app.set_preview_size(1000, 520)
	assert app.components[0].x == 624
	assert app.selected_component()?.x == 864
}

fn test_adaptive_disable_reenable_and_new_document_reset_preview_state() {
	mut app := adaptive_test_app()
	app.select_edit_class(.compact, .any)
	app.set_geometry_property('property_x', '24')
	app.set_adaptive_enabled(false)
	assert app.components[0].variations.len == 1
	assert app.preview_width == 0
	app.set_adaptive_enabled(true)
	assert app.components[0].variations.len == 1
	app.new_document()
	assert !app.adaptive
	assert app.edit_width_class == .any
	assert app.breakpoint_width == 600
	assert app.components.len == 0
}

fn test_adaptive_size_limits_are_validated_before_checkpointing() {
	mut app := adaptive_test_app()
	before := app.undo_stack.len
	assert !app.set_layout_number('layout_min_width', '-1')
	assert !app.set_layout_number('layout_min_width', 'NaN')
	assert !app.set_breakpoint('unknown', '800')
	assert app.undo_stack.len == before
	assert app.set_layout_number('layout_min_width', '120')
	assert !app.set_layout_number('layout_max_width', '100')
	assert app.components[0].layout.max_width == 0
}
