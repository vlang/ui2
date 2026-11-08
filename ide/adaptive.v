module main

import ui2
import math

fn clone_designer_components(components []DesignerComponent) []DesignerComponent {
	mut result := []DesignerComponent{cap: components.len}
	for component in components {
		result << DesignerComponent{
			...component
			variations: component.variations.clone()
		}
	}
	return result
}

fn (app &IdeApp) canvas_width() f64 {
	return if app.adaptive && app.preview_width > 0 { app.preview_width } else { app.form_width }
}

fn (app &IdeApp) canvas_height() f64 {
	return if app.adaptive && app.preview_height > 0 { app.preview_height } else { app.form_height }
}

fn (app &IdeApp) editing_variation() bool {
	return app.adaptive && (app.edit_width_class != .any || app.edit_height_class != .any)
}

fn (app &IdeApp) geometry_editable() bool {
	return app.active_tab == 'designer' && (!app.adaptive || app.editing_variation()
		|| (app.preview_width == 0 && app.preview_height == 0))
}

fn (mut app IdeApp) require_geometry_editable() bool {
	if !app.geometry_editable() {
		app.status = 'Preview only. Choose Base or a width/height size class before editing layout.'
		return false
	}
	return true
}

fn component_frame(component DesignerComponent) ui2.Rect {
	return ui2.rect(component.x, component.y, component.width, component.height)
}

fn (app &IdeApp) component_for_canvas(component DesignerComponent) DesignerComponent {
	if !app.adaptive {
		return component
	}
	mut rules := component.layout
	mut design := component_frame(component)
	mut rw := app.form_width
	mut rh := app.form_height
	mut index := -1
	if app.active_tab != 'preview' && app.editing_variation() {
		// An abstract class is edited independently of more-specific variants.
		index = ui2.adaptive_variation_index(component.variations, app.edit_width_class,
			app.edit_height_class)
	} else if app.active_tab == 'preview' || app.preview_width > 0 || app.preview_height > 0 {
		index = ui2.adaptive_variation_index(component.variations, ui2.adaptive_size_class(app.canvas_width(),
			app.breakpoint_width), ui2.adaptive_size_class(app.canvas_height(),
			app.breakpoint_height))
	}
	if index >= 0 {
		variation := component.variations[index]
		design = variation.frame
		rw = variation.reference_width
		rh = variation.reference_height
		rules = variation.layout
	}
	frame := ui2.adaptive_layout_frame(design, rw, rh, ui2.rect(0, 0, app.canvas_width(),
		app.canvas_height()), rules)
	return DesignerComponent{
		...component
		x:      frame.x
		y:      frame.y
		width:  frame.width
		height: frame.height
		layout: rules
	}
}

fn (app &IdeApp) exact_variation_index(component DesignerComponent) int {
	for index, variation in component.variations {
		if variation.width_class == app.edit_width_class
			&& variation.height_class == app.edit_height_class {
			return index
		}
	}
	return -1
}

fn (mut app IdeApp) store_geometry(index int, edited DesignerComponent) {
	if app.editing_variation() {
		mut variations := app.components[index].variations.clone()
		variation := ui2.AdaptiveLayoutVariation{
			width_class:      app.edit_width_class
			height_class:     app.edit_height_class
			frame:            component_frame(edited)
			reference_width:  app.canvas_width()
			reference_height: app.canvas_height()
			layout:           edited.layout
		}
		existing := app.exact_variation_index(app.components[index])
		if existing >= 0 {
			variations[existing] = variation
		} else {
			variations << variation
		}
		app.components[index].variations = variations
	} else {
		app.components[index].x = edited.x
		app.components[index].y = edited.y
		app.components[index].width = edited.width
		app.components[index].height = edited.height
	}
}

fn (mut app IdeApp) set_layout_rules(rules ui2.AdaptiveLayout) bool {
	index := app.find_component_index(app.selected_id)
	if index < 0 || !app.adaptive || !app.require_geometry_editable() {
		return false
	}
	ui2.validate_adaptive_layout(rules) or {
		app.status = err.msg()
		return false
	}
	current := app.component_for_canvas(app.components[index])
	if current.layout == rules {
		return false
	}
	app.checkpoint()
	if app.editing_variation() {
		existing := app.exact_variation_index(app.components[index])
		if existing < 0 {
			app.store_geometry(index, current)
		}
		mut variations := app.components[index].variations.clone()
		at := app.exact_variation_index(app.components[index])
		variations[at].layout = rules
		app.components[index].variations = variations
	} else {
		app.components[index].layout = rules
	}
	app.changed('Updated layout for `${current.name}` (${app.edit_class_label()}).')
	return true
}

fn (mut app IdeApp) set_layout_number(field string, raw string) bool {
	component := app.selected_component() or { return false }
	number := parse_f64_property(raw) or {
		app.status = 'Enter a finite, non-negative size limit.'
		return false
	}
	mut rules := component.layout
	match field {
		'layout_min_width' { rules.min_width = number }
		'layout_max_width' { rules.max_width = number }
		'layout_min_height' { rules.min_height = number }
		'layout_max_height' { rules.max_height = number }
		else { return false }
	}

	return app.set_layout_rules(rules)
}

fn (mut app IdeApp) set_layout_axis(horizontal bool, axis ui2.AdaptiveAxis) {
	component := app.selected_component() or { return }
	mut rules := component.layout
	if horizontal {
		rules.horizontal = axis
	} else {
		rules.vertical = axis
	}
	app.set_layout_rules(rules)
}

fn (mut app IdeApp) reset_selected_variation() {
	index := app.find_component_index(app.selected_id)
	if index < 0 || !app.editing_variation() || !app.require_geometry_editable() {
		return
	}
	at := app.exact_variation_index(app.components[index])
	if at < 0 {
		app.status = 'This size class already inherits its layout.'
		return
	}
	app.checkpoint()
	mut variations := app.components[index].variations.clone()
	variations.delete(at)
	app.components[index].variations = variations
	app.changed('Removed ${app.edit_class_label()} override; inherited layout restored.')
}

fn (app &IdeApp) edit_class_label() string {
	return if app.editing_variation() {
		'w:${app.edit_width_class} h:${app.edit_height_class}'
	} else if app.adaptive && (app.preview_width > 0 || app.preview_height > 0) {
		'Preview only'
	} else {
		'Base (Any/Any)'
	}
}

fn (mut app IdeApp) reset_adaptive_preview() {
	app.preview_width = 0
	app.preview_height = 0
	app.edit_width_class = .any
	app.edit_height_class = .any
	app.end_drag()
}

fn (mut app IdeApp) set_adaptive_enabled(enabled bool) {
	if app.adaptive == enabled {
		return
	}
	app.checkpoint()
	app.adaptive = enabled
	app.reset_adaptive_preview()
	app.changed(if enabled {
		'Adaptive layout enabled. Set control rules in the Layout inspector.'
	} else {
		'Fixed-coordinate layout enabled. Adaptive rules are retained.'
	})
}

fn (mut app IdeApp) set_preview_size(width f64, height f64) {
	if !app.adaptive || math.is_nan(width) || math.is_nan(height) || math.is_inf(width, 0)
		|| math.is_inf(height, 0) {
		return
	}
	app.end_drag()
	app.preview_width = clamp(width, 240, 3840)
	app.preview_height = clamp(height, 240, 2160)
	app.edit_width_class = .any
	app.edit_height_class = .any
	app.status = 'Preview ${int(app.preview_width)} x ${int(app.preview_height)}. Saved design is unchanged.'
}

fn class_preview_length(current f64, selector ui2.AdaptiveSizeClass, breakpoint f64) f64 {
	if selector == .any || ui2.adaptive_size_class(current, breakpoint) == selector {
		return current
	}
	return if selector == .compact { breakpoint * 0.65 } else { breakpoint * 1.4 }
}

fn (mut app IdeApp) select_edit_class(width_class ui2.AdaptiveSizeClass, height_class ui2.AdaptiveSizeClass) {
	if !app.adaptive {
		return
	}
	app.end_drag()
	if width_class == .any && height_class == .any {
		app.reset_adaptive_preview()
	} else {
		app.preview_width = class_preview_length(app.canvas_width(), width_class,
			app.breakpoint_width)
		app.preview_height = class_preview_length(app.canvas_height(), height_class,
			app.breakpoint_height)
		app.edit_width_class = width_class
		app.edit_height_class = height_class
	}
	app.status = 'Editing ${app.edit_class_label()}. Geometry, rules and visibility vary; text and events are shared.'
}

fn next_size_class(value ui2.AdaptiveSizeClass) ui2.AdaptiveSizeClass {
	return match value {
		.any { .compact }
		.compact { .regular }
		.regular { .any }
	}
}

fn (mut app IdeApp) set_breakpoint(field string, raw string) bool {
	if field !in ['layout_breakpoint_width', 'layout_breakpoint_height'] { return false }
	number := parse_f64_property(raw) or { return false }
	if number <= 0 || number > 3840 {
		app.status = 'A size-class breakpoint must be greater than 0 and at most 3840.'
		return false
	}
	if (field == 'layout_breakpoint_width' && number == app.breakpoint_width)
		|| (field == 'layout_breakpoint_height' && number == app.breakpoint_height) {
		return false
	}
	app.checkpoint()
	if field == 'layout_breakpoint_width' {
		app.breakpoint_width = number
	} else if field == 'layout_breakpoint_height' {
		app.breakpoint_height = number
	} else {
		return false
	}
	app.reset_adaptive_preview()
	app.changed('Updated size-class breakpoint.')
	return true
}

fn adaptive_rule_properties(layout ui2.AdaptiveLayout, include_defaults bool) []string {
	mut properties := []string{}
	if include_defaults || layout.horizontal != .start {
		properties << 'layout_x: ${layout.horizontal}'
	}
	if include_defaults || layout.vertical != .start {
		properties << 'layout_y: ${layout.vertical}'
	}
	if include_defaults || layout.min_width != 0 {
		properties << 'layout_min_width: ${layout.min_width:g}'
	}
	if include_defaults || layout.max_width != 0 {
		properties << 'layout_max_width: ${layout.max_width:g}'
	}
	if include_defaults || layout.min_height != 0 {
		properties << 'layout_min_height: ${layout.min_height:g}'
	}
	if include_defaults || layout.max_height != 0 {
		properties << 'layout_max_height: ${layout.max_height:g}'
	}
	if include_defaults || layout.hidden { properties << 'hidden: ${layout.hidden}' }
	return properties
}

fn adaptive_variation_vml(variation ui2.AdaptiveLayoutVariation) string {
	mut properties := [
		'width_class: ${variation.width_class}',
		'height_class: ${variation.height_class}',
		'reference_width: ${variation.reference_width:g}',
		'reference_height: ${variation.reference_height:g}',
		'x: ${variation.frame.x:g}',
		'y: ${variation.frame.y:g}',
		'width: ${variation.frame.width:g}',
		'height: ${variation.frame.height:g}',
	]
	properties << adaptive_rule_properties(variation.layout, true)
	return 'LayoutVariation { ${properties.join(' ')} }'
}

fn (app &IdeApp) layout_warnings() []string {
	mut warnings := []string{}
	if !app.adaptive {
		return warnings
	}
	for raw in app.components {
		component := app.component_for_canvas(raw)
		if component.layout.hidden {
			continue
		}
		if component.x < 0 || component.y < 0
			|| component.x + component.width > app.canvas_width() + 0.01
			|| component.y + component.height > app.canvas_height() + 0.01 {
			warnings << '${component.name} extends outside the preview. Adjust its pins or add a size-class variation.'
		}
		if component.width <= 0 || component.height <= 0 {
			warnings << '${component.name} has no visible area at this size.'
		}
	}
	return warnings
}

fn (mut app IdeApp) set_geometry_property(field string, raw string) bool {
	index := app.find_component_index(app.selected_id)
	if index < 0 || !app.require_geometry_editable() {
		return false
	}
	number := parse_f64_property(raw) or {
		app.status = 'Enter a finite numeric value.'
		return false
	}
	mut component := app.component_for_canvas(app.components[index])
	before := component_frame(component)
	match field {
		'property_x' { component.x = clamp(number, 0, app.canvas_width() - component.width) }
		'property_y' { component.y = clamp(number, 0, app.canvas_height() - component.height) }
		'property_width' { component.width = clamp(number, 32, app.canvas_width() - component.x) }
		'property_height' {
			component.height = clamp(number, 24, app.canvas_height() - component.y)
		}
		else { return false }
	}

	if before == component_frame(component) {
		return false
	}
	app.checkpoint()
	app.store_geometry(index, component)
	app.changed('Updated `${component.name}` (${app.edit_class_label()}).')
	return true
}

// Changing the saved reference canvas preserves its constraints. Preview sizes
// never enter this path, and variant reference canvases remain independent.
fn (mut app IdeApp) resize_design_canvas(width f64, height f64) {
	if app.adaptive {
		for index, component in app.components {
			frame := ui2.adaptive_layout_frame(component_frame(component), app.form_width,
				app.form_height, ui2.rect(0, 0, width, height), component.layout)
			app.components[index].x = frame.x
			app.components[index].y = frame.y
			app.components[index].width = frame.width
			app.components[index].height = frame.height
		}
	}
	app.form_width = width
	app.form_height = height
	if !app.adaptive {
		app.keep_components_on_form()
	}
}

fn (mut app IdeApp) handle_adaptive_event(event string) bool {
	// A stale reset event must not apply pending source and lose its edit scope.
	// Match the inspector's disabled state before the source-application path.
	if event == 'layout_reset_variation' && !app.geometry_editable() {
		return true
	}
	mutates_document :=
		event in ['layout_enable', 'layout_reset_variation', 'layout_hidden', 'layout_min_width',
			'layout_max_width', 'layout_min_height', 'layout_max_height', 'layout_breakpoint_width',
			'layout_breakpoint_height']
			|| event.starts_with('layout_x_') || event.starts_with('layout_y_')
	if mutates_document && app.source_modified && !app.apply_source_editor() { return true }
	match event {
		'layout_enable' {
			app.set_adaptive_enabled(!app.adaptive)
		}
		'layout_base' {
			app.select_edit_class(.any, .any)
		}
		'layout_phone' {
			app.set_preview_size(390, 844)
		}
		'layout_tablet' {
			app.set_preview_size(834, 1194)
		}
		'layout_desktop' {
			app.set_preview_size(1280, 800)
		}
		'layout_rotate' {
			app.set_preview_size(app.canvas_height(), app.canvas_width())
		}
		'layout_width_class' {
			app.select_edit_class(next_size_class(app.edit_width_class), app.edit_height_class)
		}
		'layout_height_class' {
			app.select_edit_class(app.edit_width_class, next_size_class(app.edit_height_class))
		}
		'layout_reset_variation' {
			app.reset_selected_variation()
		}
		'layout_guides' {
			app.show_layout_guides = !app.show_layout_guides
		}
		'layout_hidden' {
			if component := app.selected_component() {
				app.set_layout_rules(ui2.AdaptiveLayout{
					...component.layout
					hidden: !component.layout.hidden
				})
			}
		}
		'layout_check' {
			warnings := app.layout_warnings()
			app.status = if warnings.len == 0 {
				'No off-canvas or empty controls at this preview size.'
			} else {
				'${warnings.len} layout warning(s). See Messages.'
			}
			app.log(app.status)
			for warning in warnings {
				app.log(warning)
			}
			app.output_open = true
		}
		'layout_preview_size' {
			width := parse_f64_property(ui2.text('layout_preview_width')) or { return true }
			height := parse_f64_property(ui2.text('layout_preview_height')) or { return true }
			app.set_preview_size(width, height)
		}
		'layout_min_width', 'layout_max_width', 'layout_min_height', 'layout_max_height' {
			app.set_layout_number(event, ui2.text(event))
		}
		'layout_breakpoint_width', 'layout_breakpoint_height' {
			app.set_breakpoint(event, ui2.text(event))
		}
		'inspector_layout' {
			app.inspector_tab = 'layout'
		}
		else {
			if event.starts_with('layout_x_') || event.starts_with('layout_y_') {
				axis := match event.all_after_last('_') {
					'start' { ui2.AdaptiveAxis.start }
					'end' { ui2.AdaptiveAxis.end }
					'center' { ui2.AdaptiveAxis.center }
					'stretch' { ui2.AdaptiveAxis.stretch }
					else { return false }
				}

				app.set_layout_axis(event.starts_with('layout_x_'), axis)
			} else {
				return false
			}
		}
	}

	return true
}
