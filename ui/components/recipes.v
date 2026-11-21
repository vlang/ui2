module ui2

import math

// composable_button is shadcn's button recipe: a variant selects the
// appearance, a size selects the metrics, and the children are whatever the
// caller supplies, positioned relative to the button's frame. The default
// renders a caption when no children are given.
pub fn composable_button(id string, frame Rect, variant ComponentVariant, size ComponentSize, children []Element, text string, text_style TextStyle) !Element {
	component_validate_frame(frame)!
	component_validate_id(id)!
	metrics := component_metrics(size)
	base_text := TextStyle{
		...text_style
		size: if text_style.size == TextStyle{}.size { metrics.font_size } else { text_style.size }
	}
	box, style := component_variant(BoxStyle{ bg: 0xffffff, radius: metrics.radius }, base_text, variant)
	mut kids := children.clone()
	if kids.len == 0 && text.len > 0 {
		kids << label('${id}_label', text, component_local(frame), style)
	}
	// A `.button` paints only its own title: both backends ignore `children`,
	// so a supplied icon (or the generated caption child) would disappear.
	// A view with button_behavior renders the composed content while keeping
	// button activation and accessibility semantics.
	base := button_view(id, frame, box, kids)
	el := Element{
		...base
		text:                text
		text_style:          style
		accessibility_label: if text.len > 0 { text } else { base.accessibility_label }
	}
	return component_finish(el)
}

// composable_card assembles ComponentParts into a styled box. The caller
// positions each part relative to the card's frame.
pub fn composable_card(id string, frame Rect, variant ComponentVariant, parts ComponentParts) !Element {
	box, _ := component_variant(BoxStyle{ bg: 0xffffff, radius: 8 }, TextStyle{}, variant)
	return component_assemble(id, frame, box, parts)
}

// composable_input is shadcn's input recipe: a leading and trailing slot
// around an editable text field, so icons can be composed in without a
// bespoke control.
// Use composable_input_field_id(id) with the text, focus and selection APIs.
pub fn composable_input(id string, frame Rect, variant ComponentVariant, leading ?Element, trailing ?Element, placeholder string, text string, style TextStyle) !Element {
	component_validate_frame(frame)!
	component_validate_id(id)!
	box, text_style := component_variant(BoxStyle{ bg: 0xffffff, radius: 6, border_color: 0xcbd5e1, border_left: 1, border_top: 1, border_right: 1, border_bottom: 1 }, style, variant)
	mut leading_children := []Element{}
	if el := leading {
		component_validate_frame(el.frame)!
		leading_children << el
	}
	mut trailing_children := []Element{}
	if el := trailing {
		component_validate_frame(el.frame)!
		trailing_children << el
	}
	// Slot frames are local to the component. Reserve each slot's horizontal
	// band so the editable field's text, caret and pointer targets cannot land
	// underneath a leading or trailing icon.
	mut field_left := 0.0
	for child in leading_children {
		if child.hidden { continue }
		right := child.frame.x + child.frame.width
		if right > field_left {
			field_left = right
		}
	}
	mut field_right := frame.width
	for child in trailing_children {
		if child.hidden { continue }
		if child.frame.x < field_right {
			field_right = child.frame.x
		}
	}
	field_right = math.clamp(field_right, 0.0, frame.width)
	field_left = math.clamp(field_left, 0.0, field_right)
	field_frame := rect(field_left, 0, field_right - field_left, frame.height)
	mut children := []Element{}
	children << leading_children
	children << text_field(composable_input_field_id(id), placeholder, text, field_frame, BoxStyle{ transparent: true }, text_style, keyboard_default)
	children << trailing_children
	return component_finish(view(id, frame, box, children))
}

// composable_input_field_id returns the editable field inside a composed input.
pub fn composable_input_field_id(id string) string {
	return '${id}_field'
}

fn component_recipe_variant(name string, box BoxStyle, text TextStyle) ComponentVariant {
	return ComponentVariant{
		name:        name
		box:         box
		text:        text
		box_fields:  [.bg, .radius, .transparent]
		text_fields: [.color]
	}
}

// component_variant_presets are the shadcn-style variants ui2 ships ready to
// use, so an application can name them instead of spelling out colors.
pub fn component_variant_presets() map[string]ComponentVariant {
	return {
		'default':     component_recipe_variant('default', BoxStyle{ bg: 0xffffff, radius: 6 }, TextStyle{ color: 0x111111 })
		'secondary':   component_recipe_variant('secondary', BoxStyle{ bg: 0xf1f5f9, radius: 6 }, TextStyle{ color: 0x111111 })
		'destructive': component_recipe_variant('destructive', BoxStyle{ bg: 0xb91c1c, radius: 6 }, TextStyle{ color: 0xffffff })
		'outline':     component_recipe_variant('outline', BoxStyle{ bg: 0xffffff, radius: 6, border_color: 0xcbd5e1, border_left: 1, border_top: 1, border_right: 1, border_bottom: 1 }, TextStyle{ color: 0x111111 })
		'ghost':       component_recipe_variant('ghost', BoxStyle{ bg: 0xffffff, transparent: true, radius: 6 }, TextStyle{ color: 0x111111 })
		'link':        component_recipe_variant('link', BoxStyle{ bg: 0xffffff, transparent: true, radius: 0 }, TextStyle{ color: 0x2563eb, underline: true })
	}
}
