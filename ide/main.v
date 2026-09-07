module main

import os
import ui2

const ide_width = 1400
const ide_height = 900

const ide_state = &IdeApp{}

fn menu_item_enabled(item ui2.MenuItem, enabled bool) ui2.MenuItem {
	return if enabled { item } else { ui2.disabled(item) }
}

fn (app &IdeApp) menus() []ui2.Menu {
	return [
		ui2.Menu{
			title: 'File'
			items: [
				ui2.menu_item_with_shortcut('new_form', 'New Form', 'cmd+n'),
				ui2.menu_item_with_shortcut('open_path', 'Open Path', 'cmd+o'),
				ui2.menu_separator(),
				ui2.menu_item_with_shortcut('save_form', 'Save', 'cmd+s'),
				ui2.menu_item('generate_main', 'Generate main.v'),
				ui2.menu_separator(),
				ui2.menu_item_with_shortcut('quit', 'Quit', 'cmd+q'),
			]
		},
		ui2.Menu{
			title: 'Edit'
			items: [
				menu_item_enabled(ui2.menu_item_with_shortcut('undo', 'Undo', 'cmd+z'), app.undo_stack.len > 0),
				menu_item_enabled(ui2.menu_item_with_shortcut('redo', 'Redo', 'cmd+shift+z'), app.redo_stack.len > 0),
				ui2.menu_separator(),
				menu_item_enabled(ui2.menu_item_with_shortcut('duplicate_component', 'Duplicate', 'cmd+d'), app.selected_id > 0),
				menu_item_enabled(ui2.menu_item('delete_component', 'Delete'), app.selected_id > 0),
				menu_item_enabled(ui2.menu_item('bring_front', 'Bring to Front'), app.selected_id > 0),
				menu_item_enabled(ui2.menu_item('send_back', 'Send to Back'), app.selected_id > 0),
			]
		},
		ui2.Menu{
			title: 'View'
			items: [
				ui2.menu_check_item('toggle_grid', 'Grid', app.show_grid),
				ui2.menu_check_item('toggle_snap', 'Snap to Grid', app.snap_to_grid),
				ui2.menu_check_item('toggle_output', 'Messages', app.output_open),
				ui2.menu_separator(),
				ui2.menu_item('tab_designer', 'Form Designer'),
				ui2.menu_item('tab_source', 'QML Source'),
			]
		},
		ui2.Menu{
			title: 'Run'
			items: [
				ui2.menu_item_with_shortcut('preview', 'Toggle Preview', 'f9'),
				ui2.menu_item_with_shortcut('build_project', 'Build Project', 'cmd+b'),
			]
		},
		ui2.Menu{
			title: 'Help'
			items: [
				ui2.menu_item('about', 'About UI2 Studio'),
			]
		},
	]
}

fn build_ide_screen() ui2.Element {
	state := unsafe { ide_state }
	return build_ide(ui2.bounds(), state)
}

fn pointer_event(event string) ?(string, string, f64, f64) {
	parts := event.split(':')
	if parts.len < 5 || parts[0] != 'pointer' {
		return none
	}
	return parts[1], parts[2], parts[3].f64(), parts[4].f64()
}

fn event_numeric_suffix(event string, prefix string) ?int {
	if !event.starts_with(prefix) {
		return none
	}
	raw := event[prefix.len..]
	if raw.len == 0 {
		return none
	}
	return raw.int()
}

fn point_inside(rect ui2.Rect, x f64, y f64) bool {
	return x >= rect.x && x <= rect.x + rect.width && y >= rect.y
		&& y <= rect.y + rect.height
}

fn (mut app IdeApp) handle_palette_pointer(phase string, kind string, x f64, y f64, layout IdeLayout) {
	match phase {
		'down' {
			app.armed_kind = ''
			app.palette_drag_kind = kind
			app.palette_drag_x = x
			app.palette_drag_y = y
			app.palette_drag_moved = false
			app.status = 'Drag ${component_title(kind)} onto the form.'
		}
		'drag' {
			if app.palette_drag_kind != kind {
				return
			}
			app.palette_drag_x = x
			app.palette_drag_y = y
			app.palette_drag_moved = true
			app.status = if app.active_tab == 'designer' && point_inside(layout.form, x, y) {
				'Release to place ${component_title(kind)}.'
			} else {
				'Drag ${component_title(kind)} onto the form.'
			}
		}
		'up' {
			if app.palette_drag_kind != kind {
				return
			}
			moved := app.palette_drag_moved
			app.palette_drag_kind = ''
			app.palette_drag_moved = false
			if !moved {
				app.armed_kind = kind
				app.status = '${component_title(kind)} tool selected. Click the form to place it.'
				return
			}
			if app.active_tab != 'designer' || !point_inside(layout.form, x, y) {
				app.status = '${component_title(kind)} drop canceled.'
				return
			}
			component_width, component_height := component_default_size(kind)
			local_x := (x - layout.form.x) / layout.scale - component_width / 2
			local_y := (y - layout.form.y) / layout.scale - component_height / 2
			app.add_component(kind, local_x, local_y)
		}
		else {}
	}
}

fn (mut app IdeApp) handle_pointer(event string, frame ui2.Rect) bool {
	phase, id, x, y := pointer_event(event) or { return false }
	layout := ide_layout(frame, app)
	if id.starts_with('palette_') {
		kind := id.all_after('palette_')
		if kind != 'pointer' && component_tag(kind).len > 0 {
			app.handle_palette_pointer(phase, kind, x, y, layout)
			return true
		}
	}
	local_x := (x - layout.form.x) / layout.scale
	local_y := (y - layout.form.y) / layout.scale
	if id == 'form_surface' {
		if phase == 'up' {
			if app.armed_kind.len > 0 {
				app.add_component(app.armed_kind, local_x, local_y)
			} else {
				app.selected_id = 0
				app.status = '${app.form_name} selected.'
			}
		}
		return true
	}
	mut mode := 'move'
	component_id := event_numeric_suffix(id, 'cmp_') or {
		mode = 'resize'
		event_numeric_suffix(id, 'resize_') or { return false }
	}
	if phase == 'down' {
		app.begin_drag(component_id, mode, local_x, local_y)
	} else if phase == 'drag' {
		app.drag_to(local_x, local_y)
	} else if phase == 'up' {
		app.end_drag()
	}
	return true
}

fn (mut app IdeApp) confirm_discard() bool {
	return !app.dirty || ui2.confirm('Discard unsaved changes?', 'The current form contains unsaved changes.')
}

fn (mut app IdeApp) apply_source_editor() bool {
	if app.active_tab != 'source' && !app.source_modified {
		return true
	}
	source := if app.active_tab == 'source' { ui2.text('source_editor') } else { app.source_text }
	app.apply_source(source) or {
		app.status = 'Source error: ${err}'
		app.log(app.status)
		return false
	}
	return true
}

fn (mut app IdeApp) save_from_ui() bool {
	app.path_input = ui2.text('project_path')
	if app.source_modified && !app.apply_source_editor() {
		return false
	}
	app.save_document() or {
		app.status = 'Save failed: ${err}'
		app.log(app.status)
		return false
	}
	return true
}

fn (mut app IdeApp) open_from_ui() {
	path := ui2.text('project_path')
	if !app.confirm_discard() {
		return
	}
	app.open_document(path) or {
		app.status = 'Open failed: ${err}'
		app.log(app.status)
	}
}

fn (mut app IdeApp) generate_main_from_ui() {
	if app.file_path.len == 0 && !app.save_from_ui() {
		return
	}
	app.generate_companion(false) or {
		app.status = 'Generate failed: ${err}'
		app.log(app.status)
	}
}

fn (mut app IdeApp) build_project() {
	if !app.save_from_ui() {
		return
	}
	main_path := os.join_path(app.project_root, 'main.v')
	if !os.exists(main_path) {
		app.generate_companion(false) or {
			app.status = 'Build failed: ${err}'
			app.log(app.status)
			return
		}
	}
	app.status = 'Building ${main_path}...'
	app.log(app.status)
	result := os.execute('${os.quoted_path(@VEXE)} -check ${os.quoted_path(main_path)}')
	if result.output.trim_space().len > 0 {
		app.log(result.output.trim_space())
	}
	app.status = if result.exit_code == 0 {
		'Build succeeded.'
	} else {
		'Build failed with exit code ${result.exit_code}.'
	}
	app.log(app.status)
}

fn (mut app IdeApp) select_tab(tab string) {
	if tab == 'designer' && app.active_tab == 'source' && app.source_modified {
		if !app.apply_source_editor() {
			return
		}
	}
	app.active_tab = tab
	app.armed_kind = ''
	app.status = match tab {
		'source' { 'QML source editor.' }
		'preview' { 'Preview mode. Controls are live; press F9 to return.' }
		else { 'Visual form designer.' }
	}
}

fn (mut app IdeApp) toggle_preview() {
	if app.active_tab == 'preview' {
		app.select_tab('designer')
		return
	}
	if app.active_tab == 'source' && app.source_modified && !app.apply_source_editor() {
		return
	}
	app.select_tab('preview')
}

fn (mut app IdeApp) handle_property_event(event string) bool {
	if event.starts_with('property_') {
		if event == 'property_checked' {
			app.toggle_selected_checked()
		} else {
			app.set_component_text_property(event, ui2.text(event))
		}
		return true
	}
	if event.starts_with('form_property_') {
		app.set_form_property(event, ui2.text(event))
		return true
	}
	return false
}

fn (mut app IdeApp) handle_event(event string) {
	if app.handle_pointer(event, ui2.bounds()) {
		return
	}
	if app.handle_property_event(event) {
		return
	}
	if event.starts_with('palette_') {
		kind := event.all_after('palette_')
		if kind == 'pointer' {
			app.armed_kind = ''
			app.status = 'Selection tool active.'
		} else {
			app.armed_kind = kind
			app.status = '${component_title(kind)} tool selected. Click the form to place it.'
		}
		return
	}
	if id := event_numeric_suffix(event, 'tree_') {
		if app.find_component_index(id) >= 0 {
			app.selected_id = id
			app.armed_kind = ''
		}
		return
	}
	match event {
		'project_path' {
			app.path_input = ui2.text('project_path')
		}
		'new_form' {
			if app.confirm_discard() {
				app.new_document()
			}
		}
		'open_path' { app.open_from_ui() }
		'save_form' { app.save_from_ui() }
		'generate_main' { app.generate_main_from_ui() }
		'build_project' { app.build_project() }
		'quit' {
			if app.confirm_discard() {
				ui2.quit()
			}
		}
		'undo' { app.undo() }
		'redo' { app.redo() }
		'delete_component' { app.delete_selected() }
		'duplicate_component' { app.duplicate_selected() }
		'bring_front' { app.reorder_selected(true) }
		'send_back' { app.reorder_selected(false) }
		'select_form' {
			app.selected_id = 0
			app.armed_kind = ''
		}
		'project_form', 'tab_source' { app.select_tab('source') }
		'tab_designer' { app.select_tab('designer') }
		'tab_preview', 'preview' { app.toggle_preview() }
		'apply_source' { app.apply_source_editor() }
		'source_edit' {
			app.source_text = ui2.text('source_editor')
			app.source_modified = true
			app.dirty = true
			app.status = 'QML source modified; apply it to update the designer.'
		}
		'toggle_grid' {
			app.show_grid = !app.show_grid
			app.status = 'Grid ${if app.show_grid { 'shown' } else { 'hidden' }}.'
		}
		'toggle_snap' {
			app.snap_to_grid = !app.snap_to_grid
			app.status = 'Snap to grid ${if app.snap_to_grid { 'enabled' } else { 'disabled' }}.'
		}
		'toggle_output' {
			app.output_open = !app.output_open
		}
		'inspector_events' {
			app.inspector_tab = 'events'
			app.status = 'Event bindings emit action ids to the generated main.v handler.'
		}
		'inspector_properties' {
			app.inspector_tab = 'properties'
		}
		'about' {
			ui2.alert('UI2 Studio', 'A visual form designer written in V with ui2. Design, inspect, edit QML, preview, and build without leaving the app.')
		}
		else {
			if event.starts_with('preview_') {
				app.status = 'Preview event: ${event}'
				app.log(app.status)
			}
		}
	}
}

fn handle_ide_event(event string) {
	mut state := unsafe { ide_state }
	state.handle_event(event)
	ui2.set_menu_bar(state.menus())
	ui2.refresh()
}

fn handle_ide_key(key string) {
	mut state := unsafe { ide_state }
	focused := ui2.focused_id()
	if focused.len > 0 && key in ['forward_delete', 'backspace', 'left', 'right', 'up', 'down',
		'shift+left', 'shift+right', 'shift+up', 'shift+down', 'cmd+z', 'cmd+shift+z'] {
		return
	}
	mut handled := true
	match key {
		'forward_delete', 'backspace' { state.delete_selected() }
		'left' { state.nudge_selected(-1, 0) }
		'right' { state.nudge_selected(1, 0) }
		'up' { state.nudge_selected(0, -1) }
		'down' { state.nudge_selected(0, 1) }
		'shift+left' { state.nudge_selected(-designer_grid_size, 0) }
		'shift+right' { state.nudge_selected(designer_grid_size, 0) }
		'shift+up' { state.nudge_selected(0, -designer_grid_size) }
		'shift+down' { state.nudge_selected(0, designer_grid_size) }
		'cmd+z' { state.undo() }
		'cmd+shift+z' { state.redo() }
		'cmd+d' { state.duplicate_selected() }
		'f9' { state.toggle_preview() }
		'tab', 'shift+tab' {
			next := state.adjacent_inspector_property_id(focused, key == 'shift+tab') or {
				handled = false
				''
			}
			if handled {
				ui2.focus(next)
			}
		}
		'escape' {
			state.armed_kind = ''
			state.active_tab = 'designer'
		}
		else {
			handled = false
		}
	}
	if handled {
		ui2.consume_key()
		ui2.set_menu_bar(state.menus())
		ui2.refresh()
	}
}

fn handle_ide_drop(event ui2.DropEvent) {
	if event.paths.len == 0 {
		return
	}
	mut state := unsafe { ide_state }
	if state.dirty && !state.confirm_discard() {
		return
	}
	state.open_document(event.paths[0]) or {
		state.status = 'Drop failed: ${err}'
		state.log(state.status)
	}
	ui2.set_menu_bar(state.menus())
	ui2.refresh()
}

fn main() {
	mut state := unsafe { ide_state }
	unsafe {
		*state = new_ide_app(os.getwd())
	}
	if os.args.len > 1 {
		state.open_document(os.args[1]) or {
			state.status = 'Could not open ${os.args[1]}: ${err}'
			state.log(state.status)
		}
	}
	ui2.on_key(handle_ide_key)
	ui2.on_drop(handle_ide_drop)
	ui2.set_menu_bar(state.menus())
	ui2.run_window('UI2 Studio', ide_width, ide_height, build_ide_screen, handle_ide_event)
}
