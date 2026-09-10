module main

import os
import ui2

fn find_ide_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_ide_element(child, id) {
			return found
		}
	}
	return none
}

fn test_designer_adds_snaps_duplicates_and_undoes_components() {
	mut app := new_ide_app('.')
	id := app.add_component('button', 13, 19)
	assert id == 1
	assert app.components.len == 1
	assert app.components[0].name == 'button1'
	assert app.components[0].x == 16
	assert app.components[0].y == 16

	app.duplicate_selected()
	assert app.components.len == 2
	assert app.components[1].name == 'button2'
	assert app.selected_id == 2

	app.undo()
	assert app.components.len == 1
	assert app.selected_id == 1
	app.redo()
	assert app.components.len == 2
	assert app.selected_id == 2
}

fn test_designer_drag_and_resize_stay_inside_form() {
	mut app := new_ide_app('.')
	id := app.add_component('text_field', 40, 40)
	original := app.components[0]
	app.begin_drag(id, 'move', original.x + 5, original.y + 5)
	app.drag_to(5000, 5000)
	app.end_drag()
	moved := app.components[0]
	assert moved.x + moved.width <= app.form_width
	assert moved.y + moved.height <= app.form_height

	app.begin_drag(id, 'resize', moved.x + moved.width, moved.y + moved.height)
	app.drag_to(moved.x + 10, moved.y + 10)
	app.end_drag()
	assert app.components[0].width >= 32
	assert app.components[0].height >= 24

	app.undo()
	assert app.components[0].width == moved.width
	assert app.components[0].height == moved.height
}

fn test_generated_vml_round_trips_all_palette_components() {
	mut app := new_ide_app('.')
	kinds := ['label', 'button', 'text_field', 'text_area', 'checkbox', 'dropdown', 'rectangle',
		'image']
	for index, kind in kinds {
		app.add_component(kind, 16 + index * 8, 24 + index * 8)
	}
	app.components[0].text = 'A "quoted" label\nwith a second line'
	app.components[4].checked = true
	app.components[1].event_handler = 'save_clicked'
	app.sync_source()

	document := document_from_vml(app.source_text) or { panic(err) }
	assert document.form_name == 'Form1'
	assert document.components.len == kinds.len
	for index, kind in kinds {
		assert document.components[index].kind == kind
	}
	assert document.components[0].text == app.components[0].text
	assert document.components[4].checked
	assert document.components[1].event_handler == 'save_clicked'
	ui2.element_from_vml(app.source_text, ui2.rect(0, 0, app.form_width, app.form_height)) or {
		panic(err)
	}
}

fn test_source_loader_reports_unsupported_dynamic_layout() {
	source := 'Screen { id: Form1 Row { width: 300 height: 40 } }'
	if _ := document_from_vml(source) {
		assert false, 'Row should require source editing rather than lossy visual loading'
	} else {
		assert err.msg().contains('not yet editable')
	}
}

fn test_source_loader_rejects_nested_controls_instead_of_losing_them() {
	source := 'Screen { id: Form1 Rectangle { id: card width: 300 height: 200 Button { id: ok } } }'
	if _ := document_from_vml(source) {
		assert false, 'nested controls must not be flattened or lost'
	} else {
		assert err.msg().contains('nested `Button`')
	}
}

fn test_property_editor_rejects_duplicate_names_and_invalid_colors() {
	mut app := new_ide_app('.')
	app.add_component('label', 8, 8)
	app.add_component('button', 32, 40)
	assert !app.set_component_text_property('property_name', 'label1')
	assert app.components[1].name == 'button1'
	assert !app.set_component_text_property('property_background', '#12XX00')
	assert app.set_component_text_property('property_background', '#123ABC')
	assert app.components[1].background == 0x123abc
}

fn test_ide_builds_a_valid_element_tree_in_each_document_mode() {
	mut app := new_ide_app('.')
	app.add_component('label', 24, 24)
	app.add_component('button', 160, 80)
	frame := ui2.rect(0, 0, ide_width, ide_height)
	for tab in ['designer', 'source', 'preview'] {
		app.active_tab = tab
		root := build_ide(frame, app)
		ui2.validate_element_tree(root) or { panic('${tab}: ${err}') }
	}
	ui2.validate_menus(app.menus()) or { panic(err) }
}

fn test_ide_docks_tree_above_inspector_and_keeps_workspace_to_the_right() {
	mut app := new_ide_app('.')
	frame := ui2.rect(0, 0, ide_width, ide_height)
	layout := ide_layout(frame, app)
	assert layout.navigator.x == 0
	assert layout.inspector.x == 0
	assert layout.navigator.y + layout.navigator.height < layout.inspector.y + 0.1
	assert layout.inspector.y + layout.inspector.height == layout.status.y
	assert layout.center.x == layout.left.width
	assert layout.center.width == frame.width - layout.left.width
	assert layout.stage.y == layout.center.y
	assert layout.tabs.y == layout.stage.y + layout.stage.height

	root := build_ide(frame, app)
	tree := find_ide_element(root, 'object_tree_panel') or { panic('missing object tree') }
	inspector := find_ide_element(root, 'object_inspector_panel') or {
		panic('missing object inspector')
	}
	stage := find_ide_element(root, 'designer_stage') or { panic('missing designer stage') }
	assert tree.frame.x == inspector.frame.x
	assert tree.frame.y < inspector.frame.y
	assert stage.frame.x >= tree.frame.x + tree.frame.width
	if _ := find_ide_element(root, 'right_panel') {
		assert false, 'the single-window layout must not have a right inspector dock'
	}
}

fn test_object_inspector_uses_compact_property_rows() {
	mut app := new_ide_app('.')
	app.add_component('button', 224, 216)
	root := build_ide(ui2.rect(0, 0, ide_width, ide_height), app)
	property_grid := find_ide_element(root, 'property_grid') or { panic('missing property grid') }
	name := find_ide_element(root, 'property_name') or { panic('missing name property') }
	font_size := find_ide_element(root, 'property_font_size') or {
		panic('missing font size property')
	}
	assert property_grid.frame.y == 74
	assert name.frame.x == 86
	assert name.frame.y == 4
	assert name.frame.height == ide_inspector_field_height
	assert font_size.frame.y - name.frame.y == ide_inspector_row_height * 8
}

fn test_tab_order_cycles_through_visible_inspector_properties() {
	mut app := new_ide_app('.')
	assert app.adjacent_inspector_property_id('form_property_name', false)? == 'form_property_width'
	assert app.adjacent_inspector_property_id('form_property_background', false)? == 'form_property_name'
	assert app.adjacent_inspector_property_id('form_property_name', true)? == 'form_property_background'

	app.add_component('button', 32, 40)
	assert app.adjacent_inspector_property_id('property_name', false)? == 'property_text'
	assert app.adjacent_inspector_property_id('property_font_size', false)? == 'property_name'
	assert app.adjacent_inspector_property_id('project_path', false) == none

	app.inspector_tab = 'events'
	assert app.adjacent_inspector_property_id('property_event', false)? == 'property_event'
}

fn test_palette_controls_can_be_clicked_or_dragged_onto_the_form() {
	mut app := new_ide_app('.')
	frame := ui2.rect(0, 0, ide_width, ide_height)
	layout := ide_layout(frame, app)

	root := build_ide(frame, app)
	palette_button := find_ide_element(root, 'palette_button') or {
		panic('missing button palette control')
	}
	assert palette_button.kind == .view
	assert palette_button.draggable

	assert app.handle_pointer('pointer:down:palette_button:260:80', frame)
	assert app.handle_pointer('pointer:up:palette_button:260:80', frame)
	assert app.armed_kind == 'button'
	assert app.components.len == 0

	drop_x := layout.form.x + 200 * layout.scale
	drop_y := layout.form.y + 160 * layout.scale
	assert app.handle_pointer('pointer:down:palette_button:260:80', frame)
	assert app.handle_pointer('pointer:drag:palette_button:${drop_x}:${drop_y}', frame)
	assert app.palette_drag_moved
	drag_root := build_ide(frame, app)
	_ := find_ide_element(drag_root, 'palette_drag_preview') or {
		panic('missing palette drag preview')
	}
	assert app.handle_pointer('pointer:up:palette_button:${drop_x}:${drop_y}', frame)
	assert app.palette_drag_kind == ''
	assert app.components.len == 1
	assert app.components[0].kind == 'button'
	assert app.components[0].x == 144
	assert app.components[0].y == 144
}

fn test_source_mode_uses_monospace_and_toolbar_uses_icons() {
	mut app := new_ide_app('.')
	app.active_tab = 'source'
	root := build_ide(ui2.rect(0, 0, ide_width, ide_height), app)
	source := find_ide_element(root, 'source_editor') or { panic('missing source editor') }
	assert source.text_style.font_family == source_code_font_family()
	icons := {
		'new_form':  '＋'
		'open_path': '📂'
		'save_form': '💾'
		'undo':      '↶'
		'redo':      '↷'
		'preview':   '▶'
	}
	for id, icon in icons {
		button := find_ide_element(root, id) or { panic('missing toolbar button `${id}`') }
		assert button.text == icon
		assert button.tooltip.len > 0
		assert button.accessibility_label == button.tooltip
	}
}

fn test_saved_form_and_generated_main_compile_together() {
	test_dir := os.join_path(@VMODROOT, 'ide', '.generated_test_${os.getpid()}')
	os.mkdir_all(test_dir) or { panic(err) }
	defer {
		os.rmdir_all(test_dir) or {}
	}
	mut app := new_ide_app(test_dir)
	app.path_input = os.join_path(test_dir, 'form.vml')
	app.add_component('button', 40, 48)
	app.components[0].event_handler = 'button_clicked'
	app.sync_source()
	app.save_document() or { panic(err) }
	main_path := app.generate_companion(false) or { panic(err) }
	result := os.execute('${os.quoted_path(@VEXE)} -check ${os.quoted_path(main_path)}')
	assert result.exit_code == 0, result.output
}
