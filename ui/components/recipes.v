module ui2

import math

// composable_button is shadcn's button recipe: a variant selects the
// appearance, a size selects the metrics, and the children are whatever the
// caller supplies, positioned relative to the button's frame. The default
// renders a caption when no children are given.
pub fn composable_button(id string, frame Rect, variant ComponentVariant, size ComponentSize, children []Element, text string, text_style TextStyle) !Element {
	component_validate_frame(frame)!
	metrics := component_metrics(size)
	box, style := component_variant(BoxStyle{ bg: 0xffffff, radius: metrics.radius }, text_style, variant)
	mut kids := children.clone()
	if kids.len == 0 && text.len > 0 {
		kids << label('${id}_label', text, component_local(frame), style)
	}
	return component_finish(Element{
		...button(id, text, frame, box, style)
		children: kids
	})
}

// composable_card is shadcn's card recipe: header, content and footer slots
// assembled into one box, each slot a view the caller can replace.
pub fn composable_card(id string, frame Rect, variant ComponentVariant, parts ComponentParts) !Element {
	box, _ := component_variant(BoxStyle{ bg: 0xffffff, radius: 8 }, TextStyle{}, variant)
	return component_assemble(frame, box, parts)
}

// composable_input is shadcn's input recipe: a leading and trailing slot
// around an editable text field, so icons can be composed in without a
// bespoke control.
pub fn composable_input(id string, frame Rect, variant ComponentVariant, leading ?Element, trailing ?Element, placeholder string, text string, style TextStyle) !Element {
	component_validate_frame(frame)!
	box, text_style := component_variant(BoxStyle{ bg: 0xffffff, radius: 6, border_color: 0xcbd5e1, border_left: 1, border_top: 1, border_right: 1, border_bottom: 1 }, style, variant)
	mut children := []Element{}
	if el := leading {
		children << el
	}
	children << text_field('${id}_field', placeholder, text, component_local(frame), BoxStyle{ transparent: true }, text_style, keyboard_default)
	if el := trailing {
		children << el
	}
	return component_finish(view(id, frame, box, children))
}

// component_variant_presets are the shadcn-style variants ui2 ships ready to
// use, so an application can name them instead of spelling out colors.
pub fn component_variant_presets() map[string]ComponentVariant {
	return {
		'default':     ComponentVariant{ name: 'default', box: BoxStyle{ bg: 0xffffff, radius: 6 }, text: TextStyle{ color: 0x111111 } }
		'secondary':   ComponentVariant{ name: 'secondary', box: BoxStyle{ bg: 0xf1f5f9, radius: 6 }, text: TextStyle{ color: 0x111111 } }
		'destructive': ComponentVariant{ name: 'destructive', box: BoxStyle{ bg: 0xb91c1c, radius: 6 }, text: TextStyle{ color: 0xffffff } }
		'outline':     ComponentVariant{ name: 'outline', box: BoxStyle{ bg: 0xffffff, radius: 6, border_color: 0xcbd5e1, border_left: 1, border_top: 1, border_right: 1, border_bottom: 1 }, text: TextStyle{ color: 0x111111 } }
		'ghost':       ComponentVariant{ name: 'ghost', box: BoxStyle{ bg: 0xffffff, transparent: true, radius: 6 }, text: TextStyle{ color: 0x111111 } }
		'link':        ComponentVariant{ name: 'link', box: BoxStyle{ bg: 0xffffff, transparent: true, radius: 0 }, text: TextStyle{ color: 0x2563eb, underline: true } }
	}
}
