module ui2

import math

// ComponentVariant is a reusable style bundle applied to a component's
// BoxStyle and TextStyle. shadcn-style components are built from these
// variants plus small named parts, so an application can change a button's
// appearance without rewriting its layout.
pub struct ComponentVariant {
pub:
	name string
	box  BoxStyle
	text TextStyle
}

// component_variant merges a base style with a variant's overrides. A
// zero-value field keeps the base, so a variant only has to spell out what it
// changes.
pub fn component_variant(base_box BoxStyle, base_text TextStyle, variant ComponentVariant) (BoxStyle, TextStyle) {
	box := BoxStyle{
		bg:            if variant.box.bg != 0 { variant.box.bg } else { base_box.bg }
		radius:        if variant.box.radius > 0 { variant.box.radius } else { base_box.radius }
		transparent:   variant.box.transparent || base_box.transparent
		border_color:  if variant.box.border_color != 0 {
			variant.box.border_color
		} else {
			base_box.border_color
		}
		border_left:   if variant.box.border_left > 0 {
			variant.box.border_left
		} else {
			base_box.border_left
		}
		border_top:    if variant.box.border_top > 0 {
			variant.box.border_top
		} else {
			base_box.border_top
		}
		border_right:  if variant.box.border_right > 0 {
			variant.box.border_right
		} else {
			base_box.border_right
		}
		border_bottom: if variant.box.border_bottom > 0 {
			variant.box.border_bottom
		} else {
			base_box.border_bottom
		}
		opacity:       if variant.box.opacity > 0 && variant.box.opacity != 1 {
			variant.box.opacity
		} else {
			base_box.opacity
		}
		gradient:      if variant.box.gradient.stops.len > 0 {
			variant.box.gradient
		} else {
			base_box.gradient
		}
		shadow:        if component_box_shadow_is_set(variant.box.shadow) {
			variant.box.shadow
		} else {
			base_box.shadow
		}
	}
	text := TextStyle{
		color:              if variant.text.color != 0 {
			variant.text.color
		} else {
			base_text.color
		}
		background_color:   if variant.text.background_color != 0 {
			variant.text.background_color
		} else {
			base_text.background_color
		}
		size:               if variant.text.size > 0 { variant.text.size } else { base_text.size }
		font_family:        if variant.text.font_family.len > 0 {
			variant.text.font_family
		} else {
			base_text.font_family
		}
		bold:               variant.text.bold || base_text.bold
		italic:             variant.text.italic || base_text.italic
		underline:          variant.text.underline || base_text.underline
		strikethrough:      variant.text.strikethrough || base_text.strikethrough
		shadow:             variant.text.shadow || base_text.shadow
		outline:            variant.text.outline || base_text.outline
		vertical_align:     if variant.text.vertical_align.len > 0 {
			variant.text.vertical_align
		} else {
			base_text.vertical_align
		}
		link:               if variant.text.link.len > 0 {
			variant.text.link
		} else {
			base_text.link
		}
		align:              if variant.text.align != .left {
			variant.text.align
		} else {
			base_text.align
		}
		valign:             if variant.text.valign != .middle {
			variant.text.valign
		} else {
			base_text.valign
		}
		head_indent:        if variant.text.head_indent > 0 {
			variant.text.head_indent
		} else {
			base_text.head_indent
		}
		first_line_indent:  if variant.text.first_line_indent > 0 {
			variant.text.first_line_indent
		} else {
			base_text.first_line_indent
		}
		hyphenation_factor: if variant.text.hyphenation_factor > 0 {
			variant.text.hyphenation_factor
		} else {
			base_text.hyphenation_factor
		}
		lines:              if variant.text.lines != 0 {
			variant.text.lines
		} else {
			base_text.lines
		}
	}
	return box, text
}

// component_box_shadow_is_set reports whether a BoxShadow carries a visible
// shadow rather than the zero value, so a variant can override it.
fn component_box_shadow_is_set(shadow BoxShadow) bool {
	return shadow.color != 0 || shadow.opacity > 0 || shadow.blur > 0 || shadow.spread > 0
		|| shadow.x != 0 || shadow.y != 0
}

// component_variant_name normalizes a variant name for matching, the way shadcn
// component variants are looked up by a lowercase string.
pub fn component_variant_name(name string) string {
	return name.to_lower().trim_space()
}

// component_variants_find returns the variant whose name matches, or the
// default one when no name matches. The default is always the first variant in
// the list, so a component declares its default first.
pub fn component_variants_find(variants []ComponentVariant, name string) ComponentVariant {
	key := component_variant_name(name)
	for variant in variants {
		if component_variant_name(variant.name) == key {
			return variant
		}
	}
	if variants.len > 0 {
		return variants[0]
	}
	return ComponentVariant{}
}

// component_parts holds the named sub-elements a composite component is built
// from. shadcn-style composition keeps these separate so an application can
// replace a part without rebuilding the whole control.
pub struct ComponentParts {
pub:
	leading  []Element
	body     []Element
	trailing []Element
	footer   []Element
}

// component_assemble combines the parts into one container, honoring the
// component's frame and box. Parts keep their own frames; the caller positions
// them the way shadcn slot children are positioned by the parent.
pub fn component_assemble(frame Rect, box BoxStyle, parts ComponentParts) !Element {
	component_validate_frame(frame)!
	mut children := []Element{cap: parts.leading.len + parts.body.len + parts.trailing.len + parts.footer.len}
	children << parts.leading
	children << parts.body
	children << parts.trailing
	children << parts.footer
	return component_finish(view('', frame, box, children))
}

// component_slot reports whether a component exposes a named slot. This is
// the capability check applications use to decide whether to compose children
// into a part or fall back to the default rendering.
pub fn component_slot(parts ComponentParts, name string) bool {
	match name {
		'leading' { return parts.leading.len > 0 }
		'trailing' { return parts.trailing.len > 0 }
		'body' { return parts.body.len > 0 }
		'footer' { return parts.footer.len > 0 }
		else { return false }
	}
}
