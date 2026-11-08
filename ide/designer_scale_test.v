module main

import math
import ui2

fn scale_test_find(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := scale_test_find(child, id) {
			return found
		}
	}
	return none
}

fn scale_test_caption(element ui2.Element, text string) ?ui2.Element {
	for child in element.children {
		if child.kind == .label && child.text == text {
			return child
		}
	}
	return none
}

fn scale_test_assert_children_fit(element ui2.Element) {
	for child in element.children {
		assert child.frame.x >= 0
		assert child.frame.y >= 0
		assert child.frame.width >= 0
		assert child.frame.height >= 0
		assert child.frame.x + child.frame.width <= element.frame.width + 0.000001
		assert child.frame.y + child.frame.height <= element.frame.height + 0.000001
	}
}

fn test_designer_keeps_palette_contents_and_handles_when_scaled_down() {
	kinds := ['label', 'button', 'text_field', 'text_area', 'checkbox', 'dropdown', 'rectangle',
		'image']
	for kind in kinds {
		width, height := component_default_size(kind)
		component := DesignerComponent{
			id:         1
			kind:       kind
			name:       'control1'
			text:       if kind == 'image' { '' } else { 'Keep this text' }
			x:          32
			y:          48
			width:      width
			height:     height
			background: component_default_background(kind)
			checked:    true
		}
		caption_text := match kind {
			'rectangle' { component.name }
			'image' { 'IMAGE' }
			else { component.text }
		}

		unscaled := designer_component(component, false, 1)
		unscaled_caption := scale_test_caption(unscaled, caption_text)?
		for scale in [1.0, 0.75, 0.5, 0.25, 0.1, 0.01] {
			for selected in [false, true] {
				element := designer_component(component, selected, scale)
				assert element.frame == ui2.rect(32 * scale, 48 * scale, width * scale,
					height * scale)
				assert element.draggable
				assert element.box.bg == component.background
				assert element.box.transparent == (kind in ['label', 'checkbox'])
				caption := scale_test_caption(element, caption_text) or {
					panic('${kind} lost its caption at ${scale}')
				}
				assert caption.frame.width > 0
				assert caption.frame.height > 0
				assert math.abs(caption.frame.x - unscaled_caption.frame.x * scale) < 0.000001
				assert math.abs(caption.frame.y - unscaled_caption.frame.y * scale) < 0.000001
				assert math.abs(caption.frame.width - unscaled_caption.frame.width * scale) < 0.000001
				assert math.abs(caption.frame.height - unscaled_caption.frame.height * scale) < 0.000001
				assert math.abs(caption.text_style.size - unscaled_caption.text_style.size * scale) < 0.000001
				if kind == 'checkbox' {
					_ := scale_test_caption(element, 'x')?
				}
				if kind == 'dropdown' {
					_ := scale_test_caption(element, 'v')?
				}
				if selected {
					handle := scale_test_find(element, 'resize_1')?
					assert handle.draggable
					assert handle.cursor == ui2.cursor_resize_nwse
					assert handle.frame.width == minimum(9, element.frame.width)
					assert handle.frame.height == minimum(9, element.frame.height)
				} else {
					assert scale_test_find(element, 'resize_1') == none
				}
				scale_test_assert_children_fit(element)
				ui2.validate_element_tree(element)!
			}
		}
	}
}

fn test_designer_narrow_and_short_controls_have_bounded_content_and_selection() {
	for kind in ['label', 'button', 'text_field', 'text_area', 'checkbox', 'dropdown', 'rectangle',
		'image'] {
		for size in [ui2.rect(0, 0, 32, 24), ui2.rect(0, 0, 4, 2), ui2.rect(0, 0, 0.25, 0.5)] {
			component := DesignerComponent{
				id:        1
				kind:      kind
				name:      'tiny'
				text:      'Text'
				width:     size.width
				height:    size.height
				font_size: 72
				checked:   true
			}
			for scale in [1.0, 0.5, 0.01] {
				element := designer_component(component, true, scale)
				assert element.children.len > selection_outline(element.frame.width,
					element.frame.height, 1).len
				handle := scale_test_find(element, 'resize_1')?
				assert handle.frame.width > 0
				assert handle.frame.height > 0
				scale_test_assert_children_fit(element)
			}
		}
	}
}

fn test_desktop_canvas_preserves_text_and_supports_pointer_resize_with_undo() {
	mut app := new_ide_app('.')
	app.snap_to_grid = false
	app.add_component('label', 24, 24)
	id := app.add_component('button', 24, 64)
	app.set_adaptive_enabled(true)
	// Exercise the actual toolbar preset at a typical IDE window size.
	app.handle_adaptive_event('layout_desktop')
	frame := ui2.rect(0, 0, 900, 700)
	layout := ide_layout(frame, app)
	assert layout.scale < 0.55
	root := build_ide(frame, app)
	for raw in app.components {
		element := scale_test_find(root, 'cmp_${raw.id}')?
		assert element.frame.height < 20
		_ := scale_test_caption(element, raw.text)?
	}
	selected := scale_test_find(root, 'cmp_${id}')?
	_ := scale_test_find(selected, 'resize_${id}')?

	// Editing a size-class scope enables geometry edits at that canvas size.
	app.select_edit_class(.regular, .regular)
	edit_layout := ide_layout(frame, app)
	shown := app.selected_component()?
	before := app.snapshot()
	undo_count := app.undo_stack.len
	x := edit_layout.form.x + (shown.x + shown.width) * edit_layout.scale
	y := edit_layout.form.y + (shown.y + shown.height) * edit_layout.scale
	assert app.handle_pointer('pointer:down:resize_${id}:${x}:${y}', frame)
	assert app.handle_pointer('pointer:drag:resize_${id}:${x + 20 * edit_layout.scale}:${y +
		10 * edit_layout.scale}', frame)
	assert app.handle_pointer('pointer:up:resize_${id}:${x + 20 * edit_layout.scale}:${y +
		10 * edit_layout.scale}', frame)
	resized := app.selected_component()?
	assert math.abs(resized.width - shown.width - 20) < 0.000001
	assert math.abs(resized.height - shown.height - 10) < 0.000001
	assert app.undo_stack.len == undo_count + 1
	assert app.components[1].variations.len == 1
	app.undo()
	assert app.snapshot() == before
}
