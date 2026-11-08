module main

import ui2

fn adaptive_toolbar_height(app &IdeApp) f64 {
	return if app.adaptive && app.active_tab != 'source' { 76.0 } else { 0.0 }
}

fn layout_help(text string, y f64, width f64, height f64) ui2.Element {
	return ui2.label('', text, ui2.rect(4, y, width - 8, height), ui2.TextStyle{
		size:  10
		color: color_muted
		lines: 4
	})
}

fn layout_axis_buttons(prefix string, titles []string, axis ui2.AdaptiveAxis, y f64, width f64, enabled bool) []ui2.Element {
	mut children := []ui2.Element{}
	axes := [ui2.AdaptiveAxis.start, .end, .center, .stretch]
	button_width := (width - 20) / 4
	for index, value in axes {
		children << ui2.Element{
			...ide_button('${prefix}_${value}', titles[index], ui2.rect(4 +
				index * (button_width + 4), y, button_width, 24), axis == value)
			enabled: enabled
		}
	}
	return children
}

fn layout_number_field(id string, title string, value string, y f64, width f64, enabled bool) []ui2.Element {
	return [
		ui2.label('', title, ui2.rect(4, y + 3, 78, 16), text_style(10, color_muted, false)),
		ui2.Element{
			...ui2.text_field_with_submit(id, id, '', value, ui2.rect(86, y, width - 90,
				ide_inspector_field_height), ui2.BoxStyle{ bg: 0xffffff, radius: 2 }, text_style(10,
				color_text, false), ui2.keyboard_decimal)
			enabled: enabled
			tooltip: 'Logical pixels. Press Return to apply.'
		},
	]
}

fn build_layout_inspector(width f64, app &IdeApp) []ui2.Element {
	mut children := [
		ui2.checkbox('layout_enable', 'Adaptive layout', app.adaptive,
			ui2.rect(4, 4, width - 8, 24), text_style(11, color_text, true)),
	]
	if !app.adaptive {
		children << layout_help('Enable parent pins, centering, stretching and size-class variations. Existing fixed coordinates become the base layout.',
			36, width, 66)
		return children
	}
	children << layout_help('Editing: ${app.edit_class_label()}', 34, width, 24)
	if app.selected_id == 0 {
		children << layout_number_field('layout_breakpoint_width', 'Compact W <',
			'${app.breakpoint_width:g}', 62, width, true)
		children << layout_number_field('layout_breakpoint_height', 'Compact H <',
			'${app.breakpoint_height:g}', 88, width, true)
		children << layout_help('Thresholds use logical pixels. At or above a threshold the class is regular. These are app-defined, not Apple device traits.',
			122, width, 70)
		children << layout_help('Use the preview bar to change size without changing your saved form. Select a control to edit its pins and size limits.',
			198, width, 68)
		return children
	}
	component := app.selected_component() or { return children }
	editable := app.geometry_editable()
	children << layout_help('Horizontal pins', 60, width, 18)
	children << layout_axis_buttons('layout_x', ['Left', 'Right', 'Center', 'Both'],
		component.layout.horizontal, 82, width, editable)
	children << layout_help('Vertical pins', 114, width, 18)
	children << layout_axis_buttons('layout_y', ['Top', 'Bottom', 'Center', 'Both'],
		component.layout.vertical, 136, width, editable)
	children << layout_number_field('layout_min_width', 'Min width',
		'${component.layout.min_width:g}', 174, width, editable)
	children << layout_number_field('layout_max_width', 'Max width',
		'${component.layout.max_width:g}', 198, width, editable)
	children << layout_number_field('layout_min_height', 'Min height',
		'${component.layout.min_height:g}', 222, width, editable)
	children << layout_number_field('layout_max_height', 'Max height',
		'${component.layout.max_height:g}', 246, width, editable)
	children << ui2.Element{
		...ui2.checkbox('layout_hidden', 'Hidden in this layout', component.layout.hidden, ui2.rect(4,
			276, width - 8, 24), text_style(10, color_text, false))
		enabled: editable
	}
	children << tiny_button('layout_reset_variation', 'Reset this size-class override', ui2.rect(4,
		308, width - 8, 24), editable && app.editing_variation())
	children << layout_help('Both pins stretch the control; Center keeps its center offset. A maximum of 0 means unlimited. Text and events are shared across layouts.',
		344, width, 70)
	if app.editing_variation() {
		index := app.find_component_index(app.selected_id)
		state := if app.exact_variation_index(app.components[index]) >= 0 {
			'Local override'
		} else {
			'Inherited; first layout edit creates an override'
		}
		children << layout_help(state, 422, width, 44)
	} else if !editable {
		children << layout_help('Choose Base or an editing size class to change geometry. Preview sizes never rewrite the saved design.',
			422, width, 56)
	}
	return children
}

fn build_adaptive_toolbar(layout IdeLayout, app &IdeApp) []ui2.Element {
	if adaptive_toolbar_height(app) == 0 {
		return []ui2.Element{}
	}
	mut children := []ui2.Element{}
	mut x := 8.0
	for index, title in ['Base', 'Phone', 'Tablet', 'Desktop', 'Rotate'] {
		id := ['layout_base', 'layout_phone', 'layout_tablet', 'layout_desktop', 'layout_rotate'][index]
		children << tiny_button(id, title, ui2.rect(x, 6, 64, 24), true)
		x += 70
	}
	// Scrolling keeps the toolbar usable when the IDE window is narrow.
	children << ui2.text_field_with_submit('layout_preview_width', 'layout_preview_size', 'Width',
		'${app.canvas_width():g}', ui2.rect(x + 4, 6, 66, 24), ui2.BoxStyle{ bg: 0xffffff }, text_style(10,
			color_text, false), ui2.keyboard_decimal)
	children << ui2.label('', 'x', ui2.rect(x + 76, 9, 12, 18), text_style(10, color_muted, false))
	children << ui2.text_field_with_submit('layout_preview_height', 'layout_preview_size',
		'Height', '${app.canvas_height():g}', ui2.rect(x + 90, 6, 66, 24), ui2.BoxStyle{
			bg: 0xffffff
		}, text_style(10, color_text, false), ui2.keyboard_decimal)
	children << tiny_button('layout_preview_size', 'Apply size', ui2.rect(x + 164, 6, 76, 24), true)
	children << tiny_button('layout_check', 'Check layout', ui2.rect(x + 248, 6, 90, 24), true)
	children << ide_button('layout_width_class', 'Edit width: ${app.edit_width_class}', ui2.rect(8,
		38, 142, 24), app.edit_width_class != .any)
	children << ide_button('layout_height_class', 'Edit height: ${app.edit_height_class}', ui2.rect(158,
		38, 142, 24), app.edit_height_class != .any)
	children << ui2.checkbox('layout_guides', 'Guides', app.show_layout_guides, ui2.rect(310, 38,
		80, 24), text_style(10, color_text, false))
	classes := 'w:${ui2.adaptive_size_class(app.canvas_width(), app.breakpoint_width)} h:${ui2.adaptive_size_class(app.canvas_height(), app.breakpoint_height)}'
	children << ui2.label('', '${app.edit_class_label()}   |   Preview ${classes}', ui2.rect(398,
		42, 340, 18), text_style(10, color_muted, false))
	return [
		ui2.scroll('adaptive_toolbar', ui2.rect(layout.stage.x, layout.stage.y, layout.stage.width,
			72), color_panel_alt, children),
	]
}

fn adaptive_guide_children(app &IdeApp, scale f64) []ui2.Element {
	if !app.adaptive || !app.show_layout_guides {
		return []ui2.Element{}
	}
	component := app.selected_component() or { return []ui2.Element{} }
	mut children := []ui2.Element{}
	cx := (component.x + component.width / 2) * scale
	cy := (component.y + component.height / 2) * scale
	if component.layout.horizontal in [.start, .stretch] && component.x > 0 {
		children << panel('', ui2.rect(0, cy, component.x * scale, 1), color_primary, [])
	}
	if component.layout.horizontal in [.end, .stretch] {
		right := (component.x + component.width) * scale
		if right < app.canvas_width() * scale {
			children << panel('', ui2.rect(right, cy, app.canvas_width() * scale - right, 1),
				color_primary, [])
		}
	}
	if component.layout.horizontal == .center {
		children << panel('', ui2.rect(cx, 0, 1, app.canvas_height() * scale), color_primary, [])
	}
	if component.layout.vertical in [.start, .stretch] && component.y > 0 {
		children << panel('', ui2.rect(cx, 0, 1, component.y * scale), color_primary, [])
	}
	if component.layout.vertical in [.end, .stretch] {
		bottom := (component.y + component.height) * scale
		if bottom < app.canvas_height() * scale {
			children << panel('', ui2.rect(cx, bottom, 1, app.canvas_height() * scale - bottom),
				color_primary, [])
		}
	}
	if component.layout.vertical == .center {
		children << panel('', ui2.rect(0, cy, app.canvas_width() * scale, 1), color_primary, [])
	}
	return children
}
