module ui2

// ComponentBoxField and ComponentTextField mark explicit overrides, including
// zero, false and values equal to the style defaults.
pub enum ComponentBoxField {
	bg
	radius
	transparent
	border_color
	border_left
	border_top
	border_right
	border_bottom
	opacity
	gradient
	shadow
}

pub enum ComponentTextField {
	color
	background_color
	size
	font_family
	bold
	italic
	underline
	strikethrough
	shadow
	outline
	vertical_align
	link
	align
	valign
	head_indent
	first_line_indent
	hyphenation_factor
	lines
}

// ComponentVariant is a reusable style bundle applied to a component's
// BoxStyle and TextStyle. shadcn-style components are built from these
// variants plus small named parts, so an application can change a button's
// appearance without rewriting its layout.
pub struct ComponentVariant {
pub:
	name        string
	box         BoxStyle
	text        TextStyle
	box_fields  []ComponentBoxField
	text_fields []ComponentTextField
}

// component_variant merges a base style with a variant's overrides. For
// convenience, nonzero/nondefault values override the base automatically.
// List a field in box_fields or text_fields to apply its value explicitly,
// including black, zero, false, empty values and style defaults.
pub fn component_variant(base_box BoxStyle, base_text TextStyle, variant ComponentVariant) (BoxStyle, TextStyle) {
	box := BoxStyle{
		bg:            if ComponentBoxField.bg in variant.box_fields || (variant.box.bg != 0 && variant.box.bg != BoxStyle{}.bg) {
			variant.box.bg
		} else {
			base_box.bg
		}
		radius:        if ComponentBoxField.radius in variant.box_fields || (variant.box.radius > 0) {
			variant.box.radius
		} else {
			base_box.radius
		}
		transparent:   if ComponentBoxField.transparent in variant.box_fields {
			variant.box.transparent
		} else {
			variant.box.transparent || base_box.transparent
		}
		border_color:  if ComponentBoxField.border_color in variant.box_fields || (variant.box.border_color != 0) {
			variant.box.border_color
		} else {
			base_box.border_color
		}
		border_left:   if ComponentBoxField.border_left in variant.box_fields || (variant.box.border_left > 0) {
			variant.box.border_left
		} else {
			base_box.border_left
		}
		border_top:    if ComponentBoxField.border_top in variant.box_fields || (variant.box.border_top > 0) {
			variant.box.border_top
		} else {
			base_box.border_top
		}
		border_right:  if ComponentBoxField.border_right in variant.box_fields || (variant.box.border_right > 0) {
			variant.box.border_right
		} else {
			base_box.border_right
		}
		border_bottom: if ComponentBoxField.border_bottom in variant.box_fields || (variant.box.border_bottom > 0) {
			variant.box.border_bottom
		} else {
			base_box.border_bottom
		}
		opacity:       if ComponentBoxField.opacity in variant.box_fields || (variant.box.opacity > 0 && variant.box.opacity != 1) {
			variant.box.opacity
		} else {
			base_box.opacity
		}
		gradient:      if ComponentBoxField.gradient in variant.box_fields || (variant.box.gradient.stops.len > 0) {
			variant.box.gradient
		} else {
			base_box.gradient
		}
		shadow:        if ComponentBoxField.shadow in variant.box_fields || (component_box_shadow_is_set(variant.box.shadow)) {
			variant.box.shadow
		} else {
			base_box.shadow
		}
	}
	text := TextStyle{
		color:              if ComponentTextField.color in variant.text_fields || (variant.text.color != 0 && variant.text.color != TextStyle{}.color) {
			variant.text.color
		} else {
			base_text.color
		}
		background_color:   if ComponentTextField.background_color in variant.text_fields || (variant.text.background_color != 0) {
			variant.text.background_color
		} else {
			base_text.background_color
		}
		size:               if ComponentTextField.size in variant.text_fields || (variant.text.size > 0 && variant.text.size != TextStyle{}.size) {
			variant.text.size
		} else {
			base_text.size
		}
		font_family:        if ComponentTextField.font_family in variant.text_fields || (variant.text.font_family.len > 0) {
			variant.text.font_family
		} else {
			base_text.font_family
		}
		bold:               if ComponentTextField.bold in variant.text_fields {
			variant.text.bold
		} else {
			variant.text.bold || base_text.bold
		}
		italic:             if ComponentTextField.italic in variant.text_fields {
			variant.text.italic
		} else {
			variant.text.italic || base_text.italic
		}
		underline:          if ComponentTextField.underline in variant.text_fields {
			variant.text.underline
		} else {
			variant.text.underline || base_text.underline
		}
		strikethrough:      if ComponentTextField.strikethrough in variant.text_fields {
			variant.text.strikethrough
		} else {
			variant.text.strikethrough || base_text.strikethrough
		}
		shadow:             if ComponentTextField.shadow in variant.text_fields {
			variant.text.shadow
		} else {
			variant.text.shadow || base_text.shadow
		}
		outline:            if ComponentTextField.outline in variant.text_fields {
			variant.text.outline
		} else {
			variant.text.outline || base_text.outline
		}
		vertical_align:     if ComponentTextField.vertical_align in variant.text_fields || (variant.text.vertical_align.len > 0) {
			variant.text.vertical_align
		} else {
			base_text.vertical_align
		}
		link:               if ComponentTextField.link in variant.text_fields || (variant.text.link.len > 0) {
			variant.text.link
		} else {
			base_text.link
		}
		align:              if ComponentTextField.align in variant.text_fields || (variant.text.align != .left) {
			variant.text.align
		} else {
			base_text.align
		}
		valign:             if ComponentTextField.valign in variant.text_fields || (variant.text.valign != .middle) {
			variant.text.valign
		} else {
			base_text.valign
		}
		head_indent:        if ComponentTextField.head_indent in variant.text_fields || (variant.text.head_indent > 0) {
			variant.text.head_indent
		} else {
			base_text.head_indent
		}
		first_line_indent:  if ComponentTextField.first_line_indent in variant.text_fields || (variant.text.first_line_indent > 0) {
			variant.text.first_line_indent
		} else {
			base_text.first_line_indent
		}
		hyphenation_factor: if ComponentTextField.hyphenation_factor in variant.text_fields || (variant.text.hyphenation_factor > 0) {
			variant.text.hyphenation_factor
		} else {
			base_text.hyphenation_factor
		}
		lines:              if ComponentTextField.lines in variant.text_fields || (variant.text.lines != 0 && variant.text.lines != TextStyle{}.lines) {
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
// them the way shadcn slot children are positioned by the parent. The id names
// the assembled root, so a component stays addressable by ID-based APIs and a
// collision with a slot child is rejected when the tree is validated.
pub fn component_assemble(id string, frame Rect, box BoxStyle, parts ComponentParts) !Element {
	component_validate_frame(frame)!
	mut children := []Element{cap: parts.leading.len + parts.body.len + parts.trailing.len + parts.footer.len}
	children << parts.leading
	children << parts.body
	children << parts.trailing
	children << parts.footer
	return component_finish(view(id, frame, box, children))
}

// component_slot reports whether a named slot is populated. Empty and unknown
// slots return false, allowing a caller to supply fallback content.
pub fn component_slot(parts ComponentParts, name string) bool {
	match name {
		'leading' { return parts.leading.len > 0 }
		'trailing' { return parts.trailing.len > 0 }
		'body' { return parts.body.len > 0 }
		'footer' { return parts.footer.len > 0 }
		else { return false }
	}
}
