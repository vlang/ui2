module main

import ui2

const ide_toolbar_height = 46.0
const ide_palette_height = 62.0
const ide_status_height = 24.0
const ide_tab_height = 36.0

const color_window = u32(0xe5e7eb)
const color_panel = u32(0xf8fafc)
const color_panel_alt = u32(0xf1f5f9)
const color_border = u32(0xcbd5e1)
const color_text = u32(0x172033)
const color_muted = u32(0x64748b)
const color_primary = u32(0x2563eb)
const color_stage = u32(0x334155)

struct IdeLayout {
	frame   ui2.Rect
	toolbar ui2.Rect
	palette ui2.Rect
	left    ui2.Rect
	center  ui2.Rect
	right   ui2.Rect
	tabs    ui2.Rect
	stage   ui2.Rect
	output  ui2.Rect
	status  ui2.Rect
	form    ui2.Rect
	scale   f64
}

fn minimum(value f64, other f64) f64 {
	return if value < other { value } else { other }
}

fn ide_layout(frame ui2.Rect, app &IdeApp) IdeLayout {
	left_width := if frame.width >= 1120 { 218.0 } else { 178.0 }
	right_width := if frame.width >= 1120 { 286.0 } else { 234.0 }
	body_y := ide_toolbar_height + ide_palette_height
	status_y := frame.height - ide_status_height
	body_height := status_y - body_y
	center_x := left_width
	center_width := if frame.width - left_width - right_width > 320 {
		frame.width - left_width - right_width
	} else {
		320.0
	}
	output_height := if app.output_open && body_height > 420 {
		126.0
	} else if app.output_open { 86.0 } else { 0.0 }
	tabs := ui2.rect(center_x, body_y, center_width, ide_tab_height)
	stage := ui2.rect(center_x, body_y + ide_tab_height, center_width, body_height - ide_tab_height - output_height)
	output := ui2.rect(center_x, stage.y + stage.height, center_width, output_height)
	available_width := stage.width - 54
	available_height := stage.height - 54
	mut scale := minimum(available_width / app.form_width, available_height / app.form_height)
	if scale > 1 {
		scale = 1
	}
	if scale < 0.2 {
		scale = 0.2
	}
	form_width := app.form_width * scale
	form_height := app.form_height * scale
	return IdeLayout{
		frame: frame
		toolbar: ui2.rect(0, 0, frame.width, ide_toolbar_height)
		palette: ui2.rect(0, ide_toolbar_height, frame.width, ide_palette_height)
		left: ui2.rect(0, body_y, left_width, body_height)
		center: ui2.rect(center_x, body_y, center_width, body_height)
		right: ui2.rect(center_x + center_width, body_y, right_width, body_height)
		tabs: tabs
		stage: stage
		output: output
		status: ui2.rect(0, status_y, frame.width, ide_status_height)
		form: ui2.rect(stage.x + (stage.width - form_width) / 2, stage.y + (stage.height - form_height) / 2, form_width, form_height)
		scale: scale
	}
}

fn text_style(size f64, color u32, bold bool) ui2.TextStyle {
	return ui2.TextStyle{
		size: size
		color: color
		bold: bold
	}
}

fn panel(id string, frame ui2.Rect, background u32, children []ui2.Element) ui2.Element {
	return ui2.view(id, frame, ui2.BoxStyle{
		bg: background
	}, children)
}

fn ide_button(id string, title string, frame ui2.Rect, active bool) ui2.Element {
	return ui2.with_tooltip(ui2.button(id, title, frame, ui2.BoxStyle{
		bg: if active { color_primary } else { 0xffffff }
		radius: 5
	}, text_style(11, if active { u32(0xffffff) } else { color_text }, active)), title)
}

fn tiny_button(id string, title string, frame ui2.Rect, enabled bool) ui2.Element {
	return ui2.Element{
		...ui2.button(id, title, frame, ui2.BoxStyle{
			bg: 0xffffff
			radius: 4
		}, text_style(10, color_text, false))
		enabled: enabled
	}
}

fn build_toolbar(layout IdeLayout, app &IdeApp) ui2.Element {
	mut children := []ui2.Element{}
	children << ui2.label('', 'UI2 Studio', ui2.rect(14, 11, 108, 24), text_style(17, 0xffffff, true))
	children << ide_button('new_form', 'New', ui2.rect(132, 8, 58, 30), false)
	children << ide_button('open_path', 'Open', ui2.rect(196, 8, 62, 30), false)
	children << ide_button('save_form', 'Save', ui2.rect(264, 8, 58, 30), false)
	children << ide_button('undo', 'Undo', ui2.rect(334, 8, 58, 30), false)
	children << ide_button('redo', 'Redo', ui2.rect(398, 8, 58, 30), false)
	children << ide_button('preview', if app.active_tab == 'preview' { 'Design' } else { 'Run' }, ui2.rect(468, 8, 64, 30), app.active_tab == 'preview')
	path_x := 548.0
	path_width := if layout.frame.width - path_x - 124 > 180 {
		layout.frame.width - path_x - 124
	} else {
		180.0
	}
	children << ui2.text_field_with_change_and_submit('project_path', 'open_path', 'path/to/form.qml', app.path_input, ui2.rect(path_x, 8, path_width, 30), ui2.BoxStyle{
		bg: 0xffffff
		radius: 5
	}, text_style(10, color_text, false), ui2.keyboard_default)
	children << ide_button('build_project', 'Build', ui2.rect(path_x + path_width + 8, 8, 72, 30), false)
	return panel('toolbar', layout.toolbar, 0x172033, children)
}

fn build_palette(layout IdeLayout, app &IdeApp) ui2.Element {
	items := [
		['pointer', 'Pointer'],
		['label', 'Label'],
		['button', 'Button'],
		['text_field', 'Text field'],
		['text_area', 'Text area'],
		['checkbox', 'Checkbox'],
		['dropdown', 'Dropdown'],
		['rectangle', 'Rectangle'],
		['image', 'Image'],
	]
	mut children := [
		ui2.label('', 'STANDARD', ui2.rect(14, 7, 82, 16), text_style(9, color_muted, true)),
	]
	mut x := 14.0
	for item in items {
		kind := item[0]
		title := item[1]
		width := if kind in ['text_field', 'text_area', 'rectangle', 'checkbox', 'dropdown'] {
			82.0
		} else {
			68.0
		}
		children << ide_button('palette_${kind}', title, ui2.rect(x, 26, width, 28), if kind == 'pointer' {
			app.armed_kind.len == 0
		} else {
			app.armed_kind == kind
		})
		x += width + 6
	}
	children << ui2.label('', if app.armed_kind.len > 0 {
		'${component_title(app.armed_kind)} tool selected - click the form'
	} else {
		'Selection tool'
	}, ui2.rect(x + 8, 31, layout.frame.width - x - 24, 18), text_style(10, color_muted, false))
	return panel('palette', layout.palette, color_panel_alt, children)
}

fn build_left_panel(layout IdeLayout, app &IdeApp) ui2.Element {
	width := layout.left.width
	mut children := []ui2.Element{}
	children << ui2.label('', 'PROJECT INSPECTOR', ui2.rect(12, 10, width - 24, 18), text_style(10, color_muted, true))
	children << ui2.label('', 'v  ${os_name(app.project_root)}', ui2.rect(12, 34, width - 24, 20), text_style(11, color_text, true))
	children << tiny_button('project_form', '  ${if app.dirty { '*' } else { '' }}${display_file_name(app)}', ui2.rect(18, 58, width - 30, 27), true)
	children << tiny_button('generate_main', '  main.v  (generate)', ui2.rect(18, 89, width - 30, 27), true)
	divider_y := 126.0
	children << panel('', ui2.rect(0, divider_y, width, 1), color_border, [])
	children << ui2.label('', 'OBJECT TREE', ui2.rect(12, divider_y + 10, width - 24, 18), text_style(10, color_muted, true))
	mut rows := []ui2.Element{}
	rows << tiny_button('select_form', '${if app.selected_id == 0 { '> ' } else { '' }}${app.form_name}: Screen', ui2.rect(5, 2, width - 20, 28), true)
	for index, component in app.components {
		rows << tiny_button('tree_${component.id}', '${if app.selected_id == component.id {
			'> '
		} else {
			'  '
		}}${component.name}: ${component_tag(component.kind)}', ui2.rect(12, 34 + index * 31, width - 27, 27), true)
	}
	tree_y := divider_y + 32
	tree_height := layout.left.height - tree_y - 42
	children << ui2.scroll('object_tree', ui2.rect(6, tree_y, width - 12, tree_height), color_panel, rows)
	children << tiny_button('delete_component', 'Delete', ui2.rect(10, layout.left.height - 34, 58, 25), app.selected_id > 0)
	children << tiny_button('duplicate_component', 'Duplicate', ui2.rect(74, layout.left.height - 34, 72, 25), app.selected_id > 0)
	children << tiny_button('bring_front', 'Front', ui2.rect(152, layout.left.height - 34, width - 162, 25), app.selected_id > 0)
	return panel('left_panel', layout.left, color_panel, children)
}

fn os_name(path string) string {
	name := path.replace('\\', '/').all_after_last('/')
	return if name.len > 0 { name } else { path }
}

fn display_file_name(app &IdeApp) string {
	if app.file_path.len > 0 {
		return os_name(app.file_path)
	}
	name := os_name(app.path_input)
	return if name.len > 0 { name } else { 'form.qml' }
}

fn inspector_field(id string, label string, value string, y f64, width f64) []ui2.Element {
	return [
		ui2.label('', label, ui2.rect(10, y + 7, 84, 18), text_style(10, color_muted, false)),
		ui2.text_field_with_change(id, '', value, ui2.rect(94, y, width - 104, 30), ui2.BoxStyle{
			bg: 0xffffff
			radius: 4
		}, text_style(10, color_text, false), ui2.keyboard_default),
	]
}

fn build_form_inspector(width f64, app &IdeApp) []ui2.Element {
	mut children := []ui2.Element{}
	children << inspector_field('form_property_name', 'Name', app.form_name, 8, width)
	children << inspector_field('form_property_width', 'Width', int(app.form_width).str(), 44, width)
	children << inspector_field('form_property_height', 'Height', int(app.form_height).str(), 80, width)
	children << inspector_field('form_property_background', 'Background', color_hex(app.form_background), 116, width)
	children << ui2.label('', 'Select a control or choose one from the palette, then click the form.', ui2.rect(10, 160, width - 20, 44), ui2.TextStyle{
		size: 10
		color: color_muted
		lines: 3
	})
	return children
}

fn build_component_inspector(width f64, component DesignerComponent) []ui2.Element {
	mut children := []ui2.Element{}
	children << inspector_field('property_name', 'Name', component.name, 8, width)
	children << inspector_field('property_text', if component.kind == 'image' {
		'Source'
	} else {
		'Text'
	}, component.text, 44, width)
	children << inspector_field('property_x', 'X', int(component.x).str(), 80, width)
	children << inspector_field('property_y', 'Y', int(component.y).str(), 116, width)
	children << inspector_field('property_width', 'Width', int(component.width).str(), 152, width)
	children << inspector_field('property_height', 'Height', int(component.height).str(), 188, width)
	children << inspector_field('property_background', 'Background', color_hex(component.background), 224, width)
	children << inspector_field('property_color', 'Foreground', color_hex(component.color), 260, width)
	children << inspector_field('property_font_size', 'Font size', '${component.font_size:g}', 296, width)
	if component.kind == 'checkbox' {
		children << ui2.checkbox('property_checked', 'Checked', component.checked, ui2.rect(94, 334, width - 104, 28), text_style(10, color_text, false))
	}
	children << ui2.label('', 'Type', ui2.rect(10, 375, 84, 18), text_style(10, color_muted, false))
	children << ui2.label('', component_tag(component.kind), ui2.rect(94, 375, width - 104, 18), text_style(10, color_text, true))
	return children
}

fn component_event_property(component DesignerComponent) string {
	return if component.kind in ['text_field', 'text_area', 'dropdown'] {
		'on_change'
	} else {
		'on_tap'
	}
}

fn build_events_inspector(width f64, app &IdeApp) []ui2.Element {
	component := app.selected_component() or {
		return [ui2.label('', 'Screen has no direct event. Select a control to bind an action id.', ui2.rect(10, 12, width - 20, 44), ui2.TextStyle{
			size: 10
			color: color_muted
			lines: 3
		})]
	}
	mut children := inspector_field('property_event', component_event_property(component), component.event_handler, 8, width)
	children << ui2.label('', 'The generated action id is emitted by run_window. Handle it in main.v.', ui2.rect(10, 52, width - 20, 44), ui2.TextStyle{
		size: 10
		color: color_muted
		lines: 3
	})
	return children
}

fn build_right_panel(layout IdeLayout, app &IdeApp) ui2.Element {
	width := layout.right.width
	mut children := []ui2.Element{}
	children << ui2.label('', 'OBJECT INSPECTOR', ui2.rect(12, 10, width - 24, 18), text_style(10, color_muted, true))
	selection_title := if component := app.selected_component() {
		'${component.name}: ${component_tag(component.kind)}'
	} else {
		'${app.form_name}: Screen'
	}
	children << ui2.label('', selection_title, ui2.rect(12, 33, width - 24, 22), text_style(12, color_text, true))
	children << ide_button('inspector_properties', 'Properties', ui2.rect(10, 62, (width - 26) / 2, 28), app.inspector_tab == 'properties')
	children << ide_button('inspector_events', 'Events', ui2.rect(16 + (width - 26) / 2, 62, (width - 26) / 2, 28), app.inspector_tab == 'events')
	property_children := if app.inspector_tab == 'events' {
		build_events_inspector(width - 12, app)
	} else if component := app.selected_component() {
		build_component_inspector(width - 12, component)
	} else {
		build_form_inspector(width - 12, app)
	}
	children << ui2.scroll('property_grid', ui2.rect(6, 98, width - 12, layout.right.height - 104), color_panel, property_children)
	return panel('right_panel', layout.right, color_panel, children)
}

fn build_tabs(layout IdeLayout, app &IdeApp) ui2.Element {
	mut children := []ui2.Element{}
	children << ide_button('tab_designer', 'Design', ui2.rect(10, 4, 78, 28), app.active_tab == 'designer')
	children << ide_button('tab_source', 'Source', ui2.rect(94, 4, 78, 28), app.active_tab == 'source')
	children << ide_button('tab_preview', 'Preview', ui2.rect(178, 4, 78, 28), app.active_tab == 'preview')
	children << ui2.label('', '${app.form_name}  ${int(app.form_width)} x ${int(app.form_height)}  ${int(layout.scale * 100)}%', ui2.rect(270, 9, layout.tabs.width - 282, 18), text_style(10, color_muted, false))
	return panel('document_tabs', layout.tabs, color_panel_alt, children)
}

fn grid_children(app &IdeApp, scale f64) []ui2.Element {
	mut children := []ui2.Element{}
	if !app.show_grid {
		return children
	}
	spacing := designer_grid_size * scale
	mut x := spacing
	for x < app.form_width * scale {
		children << panel('', ui2.rect(x, 0, 1, app.form_height * scale), 0xe8edf3, [])
		x += spacing
	}
	mut y := spacing
	for y < app.form_height * scale {
		children << panel('', ui2.rect(0, y, app.form_width * scale, 1), 0xe8edf3, [])
		y += spacing
	}
	return children
}

fn selection_outline(width f64, height f64, id int) []ui2.Element {
	line := 2.0
	mut children := [
		panel('', ui2.rect(0, 0, width, line), color_primary, []),
		panel('', ui2.rect(0, height - line, width, line), color_primary, []),
		panel('', ui2.rect(0, 0, line, height), color_primary, []),
		panel('', ui2.rect(width - line, 0, line, height), color_primary, []),
		panel('', ui2.rect(0, 0, 7, 7), color_primary, []),
		panel('', ui2.rect(width - 7, 0, 7, 7), color_primary, []),
		panel('', ui2.rect(0, height - 7, 7, 7), color_primary, []),
	]
	children << ui2.draggable_view_with_cursor('resize_${id}', ui2.rect(width - 9, height - 9, 9, 9), ui2.BoxStyle{
		bg: color_primary
	}, ui2.cursor_resize_nwse, [])
	return children
}

fn designer_component(component DesignerComponent, selected bool, scale f64) ui2.Element {
	width := component.width * scale
	height := component.height * scale
	mut children := []ui2.Element{}
	font_size := clamp(component.font_size * scale, 8, 32)
	match component.kind {
		'label' {
			children << ui2.label('', component.text, ui2.rect(4, 2, width - 8, height - 4), text_style(font_size, component.color, false))
		}
		'button' {
			children << ui2.label('', component.text, ui2.rect(5, (height - font_size - 3) / 2, width - 10, font_size + 5), ui2.TextStyle{
				size: font_size
				color: component.color
				align: .center
			})
		}
		'text_field' {
			children << ui2.label('', component.text, ui2.rect(9, (height - font_size - 3) / 2, width - 18, font_size + 5), text_style(font_size, 0x94a3b8, false))
		}
		'text_area' {
			children << ui2.label('', component.text, ui2.rect(9, 7, width - 18, height - 14), ui2.TextStyle{
				size: font_size
				color: component.color
				lines: 4
			})
		}
		'checkbox' {
			children << panel('', ui2.rect(4, (height - 16 * scale) / 2, 16 * scale, 16 * scale), 0xffffff, [])
			if component.checked {
				children << ui2.label('', 'x', ui2.rect(5, (height - 17 * scale) / 2, 15 * scale, 17 * scale), text_style(font_size, color_primary, true))
			}
			children << ui2.label('', component.text, ui2.rect(26 * scale, (height - font_size - 3) / 2, width - 30 * scale, font_size + 5), text_style(font_size, component.color, false))
		}
		'dropdown' {
			children << ui2.label('', component.text, ui2.rect(9, (height - font_size - 3) / 2, width - 32, font_size + 5), text_style(font_size, component.color, false))
			children << ui2.label('', 'v', ui2.rect(width - 24, (height - font_size - 3) / 2, 18, font_size + 5), ui2.TextStyle{
				size: font_size
				color: color_muted
				align: .center
			})
		}
		'rectangle' {
			children << ui2.label('', component.name, ui2.rect(6, 5, width - 12, 18), text_style(9, color_muted, false))
		}
		'image' {
			children << ui2.label('', if component.text.len > 0 {
				os_name(component.text)
			} else {
				'IMAGE'
			}, ui2.rect(5, (height - 18) / 2, width - 10, 18), ui2.TextStyle{
				size: 10
				color: color_muted
				align: .center
				bold: true
			})
		}
		else {}
	}
	if selected {
		children << selection_outline(width, height, component.id)
	}
	transparent := component.kind in ['label', 'checkbox']
	return ui2.draggable_view_with_cursor('cmp_${component.id}', ui2.rect(component.x * scale, component.y * scale, width, height), ui2.BoxStyle{
		bg: component.background
		radius: if component.kind in ['button', 'text_field', 'text_area', 'dropdown', 'rectangle'] {
			5.0 * scale
		} else {
			0
		}
		transparent: transparent
	}, ui2.cursor_pointing_hand, children)
}

fn build_designer_form(layout IdeLayout, app &IdeApp) ui2.Element {
	mut children := grid_children(app, layout.scale)
	if app.components.len == 0 {
		children << ui2.label('', 'Choose a control from the palette, then click here to place it.', ui2.rect(30, 28, layout.form.width - 60, 28), ui2.TextStyle{
			size: 12
			color: 0x94a3b8
			align: .center
		})
	}
	for component in app.components {
		children << designer_component(component, component.id == app.selected_id, layout.scale)
	}
	return ui2.clickable_view('form_surface', layout.form, ui2.BoxStyle{
		bg: app.form_background
	}, children)
}

fn preview_component(component DesignerComponent, scale f64) ui2.Element {
	frame := ui2.rect(component.x * scale, component.y * scale, component.width * scale, component.height * scale)
	style := text_style(clamp(component.font_size * scale, 8, 32), component.color, false)
	box := ui2.BoxStyle{
		bg: component.background
		radius: 5 * scale
		transparent: component.kind in ['label', 'checkbox']
	}
	id := 'preview_${component.id}'
	return match component.kind {
		'label' { ui2.label(id, component.text, frame, style) }
		'button' { ui2.button(id, component.text, frame, box, style) }
		'text_field' {
			ui2.text_field(id, component.text, '', frame, box, style, ui2.keyboard_default)
		}
		'text_area' { ui2.text_area(id, component.text, frame, box, style) }
		'checkbox' { ui2.checkbox(id, component.text, component.checked, frame, style) }
		'dropdown' {
			ui2.dropdown(id, component.text, ['Option 1', 'Option 2', 'Option 3'], frame, box, style)
		}
		'rectangle' { ui2.view(id, frame, box, []) }
		'image' {
			if component.text.len > 0 {
				ui2.image(id, component.text, frame)
			} else {
				ui2.view(id, frame, box, [ui2.label('', 'IMAGE', ui2.rect(0, 0, frame.width, frame.height), ui2.TextStyle{
					color: color_muted
					size: 10
					align: .center
				})])
			}
		}
		else { ui2.view(id, frame, box, []) }
	}
}

fn build_preview_form(layout IdeLayout, app &IdeApp) ui2.Element {
	mut children := []ui2.Element{}
	for component in app.components {
		children << preview_component(component, layout.scale)
	}
	return panel('preview_form', layout.form, app.form_background, children)
}

fn build_source_editor(layout IdeLayout, app &IdeApp) []ui2.Element {
	padding := 10.0
	apply_width := 116.0
	mut editor := ui2.text_area('source_editor', app.source_text, ui2.rect(layout.stage.x + padding, layout.stage.y + padding, layout.stage.width - padding * 2, layout.stage.height - 54), ui2.BoxStyle{
		bg: 0x0f172a
		radius: 5
	}, ui2.TextStyle{
		color: 0xe2e8f0
		size: 12
		font_family: 'Roboto Mono'
	})
	editor = ui2.Element{
		...editor
		action_id: 'source_edit'
		emit_change: true
	}
	return [
		panel('source_stage', layout.stage, 0x1e293b, []),
		editor,
		ide_button('apply_source', 'Apply to designer', ui2.rect(layout.stage.x + layout.stage.width - apply_width - padding, layout.stage.y + layout.stage.height - 38, apply_width, 28), false),
		ui2.label('', 'Edit generated QML, then apply it to return to Design.', ui2.rect(layout.stage.x + padding, layout.stage.y + layout.stage.height - 34, layout.stage.width - apply_width - 32, 18), text_style(10, 0xcbd5e1, false)),
	]
}

fn build_output(layout IdeLayout, app &IdeApp) []ui2.Element {
	if layout.output.height <= 0 {
		return []ui2.Element{}
	}
	mut output := ui2.text_area('build_output', app.messages, ui2.rect(layout.output.x + 6, layout.output.y + 25, layout.output.width - 12, layout.output.height - 30), ui2.BoxStyle{
		bg: 0x0f172a
	}, ui2.TextStyle{
		color: 0xcbd5e1
		size: 10
		font_family: 'Roboto Mono'
	})
	output = ui2.Element{
		...output
		readonly: true
	}
	return [
		panel('output_panel', layout.output, 0x1e293b, []),
		ui2.label('', 'MESSAGES', ui2.rect(layout.output.x + 10, layout.output.y + 5, 90, 16), text_style(9, 0x94a3b8, true)),
		tiny_button('toggle_output', 'Hide', ui2.rect(layout.output.x + layout.output.width - 48, layout.output.y + 3, 40, 20), true),
		output,
	]
}

fn build_status(layout IdeLayout, app &IdeApp) ui2.Element {
	selected := if component := app.selected_component() { component.name } else { app.form_name }
	mut children := [
		ui2.label('', app.status, ui2.rect(10, 4, layout.status.width - 300, 16), text_style(10, color_text, false)),
		ui2.label('', '${selected}   Grid ${if app.show_grid { 'on' } else { 'off' }}   Snap ${if app.snap_to_grid {
			'on'
		} else {
			'off'
		}}', ui2.rect(layout.status.width - 286, 4, 276, 16), ui2.TextStyle{
			size: 10
			color: color_muted
			align: .right
		}),
	]
	return panel('status_bar', layout.status, 0xe2e8f0, children)
}

fn build_ide(frame ui2.Rect, app &IdeApp) ui2.Element {
	layout := ide_layout(frame, app)
	mut children := []ui2.Element{}
	children << build_toolbar(layout, app)
	children << build_palette(layout, app)
	children << build_left_panel(layout, app)
	children << build_right_panel(layout, app)
	children << build_tabs(layout, app)
	children << panel('designer_stage', layout.stage, color_stage, [])
	match app.active_tab {
		'source' { children << build_source_editor(layout, app) }
		'preview' { children << build_preview_form(layout, app) }
		else { children << build_designer_form(layout, app) }
	}
	children << build_output(layout, app)
	if !app.output_open {
		children << tiny_button('toggle_output', 'Messages', ui2.rect(layout.center.x + layout.center.width - 72, layout.center.y + layout.center.height - 23, 68, 20), true)
	}
	children << build_status(layout, app)
	return ui2.screen(color_window, children)
}
