module ui2

// P1 stylesheet cascade: apply parsed stylesheets to an element tree.
//
// apply_stylesheet walks the tree once, carrying the ancestor chain (for
// descendant/child selectors) and the active scope stack (global sheet plus
// every ancestor's Element.stylesheet). Matching declarations are ordered by
// (specificity, scope depth, source order) and applied in that order, so the
// strongest wins.
//
// Inline wins: a sheet declaration only fills a property the element leaves
// at its struct default. Anything a builder sets explicitly survives. The
// one caveat: explicitly setting a field to its default value (e.g.
// `bg: 0xffffff`) is indistinguishable from leaving it unset, and the sheet
// will override it. Layout-owned props (padding/margin/gap) are collected
// into warnings instead of applied; the layout code does not read them yet.

// stylesheet_known_props lists every property the cascade applies or
// deliberately defers. Anything else warns as unknown. The lint helper reads
// the same list, so the two can never disagree.
pub const stylesheet_known_props = ['background', 'background-color', 'background-gradient', 'color',
	'font-size', 'font-family', 'font-weight', 'font-style', 'text-align', 'text-decoration', 'border',
	'border-radius', 'border-color', 'border-width', 'opacity', 'box-shadow', 'padding', 'margin',
	'gap']

pub struct StylesheetWarning {
pub:
	element string
	prop    string
	message string
}

// with_classes returns el with stylesheet classes attached.
pub fn with_classes(el Element, classes ...string) Element {
	return Element{
		...el
		classes: classes.clone()
	}
}

// with_stylesheet returns el with a scoped sheet for its subtree.
pub fn with_stylesheet(el Element, sheet Stylesheet) Element {
	return Element{
		...el
		stylesheet: sheet
	}
}

// apply_stylesheet applies the global sheet to the tree rooted at root.
// Scoped Element.stylesheet sheets on the way down win over global rules on
// equal specificity; inline (builder-set) properties always win.
pub fn apply_stylesheet(root Element, global Stylesheet, env StyleMatchEnv) Element {
	result, _ := apply_stylesheet_ex(root, global, env)
	return result
}

// apply_stylesheet_ex is apply_stylesheet plus per-property warnings.
pub fn apply_stylesheet_ex(root Element, global Stylesheet, env StyleMatchEnv) (Element, []StylesheetWarning) {
	mut warnings := []StylesheetWarning{}
	mut scopes := []Stylesheet{}
	if global.rules.len > 0 {
		scopes << global
	}
	root_out := cascade_element(root, [], 0, 1, scopes, env, mut warnings)
	return root_out, warnings
}

fn cascade_element(el Element, ancestors []StyleAncestor, index int, count int, scopes []Stylesheet, env StyleMatchEnv, mut warnings []StylesheetWarning) Element {
	mut active := scopes.clone()
	if el.stylesheet.rules.len > 0 || el.stylesheet.variables.len > 0
		|| el.stylesheet.light_vars.len > 0 || el.stylesheet.dark_vars.len > 0 {
		active << el.stylesheet
	}
	mut out := if el.ignore_stylesheet {
		el
	} else {
		cascade_props(el, ancestors, index, count, active, env, mut warnings)
	}
	mut children := []Element{cap: el.children.len}
	for child_index, child in el.children {
		ancestors_next := [...ancestors, StyleAncestor{
			el:    out
			index: index
			count: count
		}]
		children << cascade_element(child, ancestors_next, child_index, el.children.len,
			active, env, mut warnings)
	}
	return Element{
		...out
		children: children
	}
}

struct StyleCandidate {
	specificity int
	scope_level int
	rule_order  int
	decl_index  int
	decl        StyleDeclaration
}

fn cascade_props(el Element, ancestors []StyleAncestor, index int, count int, scopes []Stylesheet, env StyleMatchEnv, mut warnings []StylesheetWarning) Element {
	mut candidates := []StyleCandidate{}
	for scope_level, sheet in scopes {
		for rule_index, rule in sheet.rules {
			for sel in rule.selectors {
				if stylesheet_selector_matches(sel, el, ancestors, index, count, env) {
					for decl_index, decl in rule.declarations {
						candidates << StyleCandidate{
							specificity: sel.specificity
							scope_level: scope_level
							rule_order:  rule_index
							decl_index:  decl_index
							decl:        decl
						}
					}
					break
				}
			}
		}
	}
	if candidates.len == 0 {
		return el
	}
	candidates.sort_with_compare(fn (a &StyleCandidate, b &StyleCandidate) int {
		if a.specificity != b.specificity {
			return a.specificity - b.specificity
		}
		if a.scope_level != b.scope_level {
			return a.scope_level - b.scope_level
		}
		if a.rule_order != b.rule_order {
			return a.rule_order - b.rule_order
		}
		// Same rule, several declarations: source order wins, independent of
		// the sort algorithm's stability.
		return a.decl_index - b.decl_index
	})
	mut out := el
	for candidate in candidates {
		out = apply_declaration(el, out, candidate.decl, scopes, env, mut warnings)
	}
	return out
}

fn cascade_lookup_var(name string, scopes []Stylesheet, dark bool) ?string {
	for i := scopes.len - 1; i >= 0; i-- {
		if value := scopes[i].resolve_var(name, dark) {
			return value
		}
	}
	return none
}

fn cascade_resolve_value(raw string, scopes []Stylesheet, dark bool) ?string {
	value := raw.trim_space()
	if value.starts_with('@') || value.starts_with('--') {
		key := value.fields()[0]
		rest := value[key.len..].trim_space()
		resolved := cascade_lookup_var(key, scopes, dark) or { return none }
		if rest.len > 0 {
			return '${resolved} ${rest}'
		}
		return resolved
	}
	return value
}

fn cascade_warn(mut warnings []StylesheetWarning, el Element, prop string, message string) {
	warnings << StylesheetWarning{
		element: el.id
		prop:    prop
		message: message
	}
}

// Inline wins is read off base (the pre-cascade element): checks below look
// at base, writes accumulate onto out, so later (stronger) sheet rules still
// override earlier ones while builder-set properties survive.
fn apply_declaration(base Element, out Element, decl StyleDeclaration, scopes []Stylesheet, env StyleMatchEnv, mut warnings []StylesheetWarning) Element {
	value := cascade_resolve_value(decl.value, scopes, env.dark) or {
		cascade_warn(mut warnings, out, decl.prop, 'unknown variable "${decl.value}"')
		return out
	}
	match decl.prop {
		'background', 'background-color', 'background-gradient' {
			if base.box.bg != 0xffffff || base.box.gradient.stops.len > 0 {
				return out // inline wins
			}
			token := component_theme_token(value) or {
				cascade_warn(mut warnings, out, decl.prop, 'unparseable color: ${err.msg()}')
				return out
			}
			if token.has_gradient() {
				return Element{
					...out
					box: BoxStyle{
						...out.box
						gradient: token.gradient
					}
				}
			}
			bg := token.over(0xffffff)
			opacity := if token.opacity < 1.0 { token.opacity } else { out.box.opacity }
			return Element{
				...out
				box: BoxStyle{
					...out.box
					bg:      bg
					opacity: opacity
				}
			}
		}
		'color' {
			if base.text_style.color != 0x111111 {
				return out
			}
			token := component_theme_token(value) or {
				cascade_warn(mut warnings, out, decl.prop, 'unparseable color: ${err.msg()}')
				return out
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					color: token.over(0xffffff)
				}
			}
		}
		'font-size' {
			if base.text_style.size != 15.0 {
				return out
			}
			size := cascade_length(value) or {
				cascade_warn(mut warnings, out, decl.prop, 'expected a px length')
				return out
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					size: size
				}
			}
		}
		'font-family' {
			if base.text_style.font_family.len > 0 {
				return out
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					font_family: value.trim('"\'')
				}
			}
		}
		'font-weight' {
			lower := value.to_lower()
			bold := if lower in ['bold', 'bolder'] {
				true
			} else if lower == 'normal' || lower == 'lighter' {
				false
			} else {
				(lower.int() >= 600)
			}
			if base.text_style.bold {
				return out // inline wins
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					bold: bold
				}
			}
		}
		'font-style' {
			italic := value.to_lower() == 'italic'
			if base.text_style.italic {
				return out // inline wins (default false)
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					italic: italic
				}
			}
		}
		'text-align' {
			align := match value.to_lower() {
				'left' { Align.left }
				'center' { Align.center }
				'right' { Align.right }
				else {
					cascade_warn(mut warnings, out, decl.prop, 'expected left, center or right')
					return out
				}
			}
			if base.text_style.align != .left {
				return out // inline wins
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					align: align
				}
			}
		}
		'text-decoration' {
			lower := value.to_lower()
			if lower == 'none' {
				return out
			}
			if base.text_style.underline || base.text_style.strikethrough {
				return out // inline wins
			}
			underline := lower.contains('underline')
			strike := lower.contains('line-through') || lower.contains('strikethrough')
			if !underline && !strike {
				cascade_warn(mut warnings, out, decl.prop, 'expected underline, line-through or none')
				return out
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					underline:     underline
					strikethrough: strike
				}
			}
		}
		'border' {
			if value.to_lower() == 'none' {
				return out
			}
			mut width := ?f64(none)
			mut color := ?u32(none)
			for part in value.fields() {
				if width == none {
					if w := cascade_length(part) {
						width = w
						continue
					}
				}
				if color == none {
					if token := component_theme_token(part) {
						color = token.over(0xffffff)
					}
				}
			}
			if width == none && color == none {
				cascade_warn(mut warnings, out, decl.prop, 'expected `<width> [style] <color>`')
				return out
			}
			w := width or { base.box.border_left }
			c := color or { base.box.border_color }
			if base.box.border_left != 0 || base.box.border_color != 0 {
				return out // inline wins
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					border_left:   w
					border_top:    w
					border_right:  w
					border_bottom: w
					border_color:  c
				}
			}
		}
		'border-radius' {
			if base.box.radius != 0 {
				return out
			}
			radius := cascade_length(value) or {
				cascade_warn(mut warnings, out, decl.prop, 'expected a px length')
				return out
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					radius: radius
				}
			}
		}
		'border-color' {
			if base.box.border_color != 0 {
				return out
			}
			token := component_theme_token(value) or {
				cascade_warn(mut warnings, out, decl.prop, 'unparseable color: ${err.msg()}')
				return out
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					border_color: token.over(0xffffff)
				}
			}
		}
		'border-width' {
			if base.box.border_left != 0 || base.box.border_top != 0 || base.box.border_right != 0
				|| base.box.border_bottom != 0 {
				return out
			}
			width := cascade_length(value) or {
				cascade_warn(mut warnings, out, decl.prop, 'expected a px length')
				return out
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					border_left:   width
					border_top:    width
					border_right:  width
					border_bottom: width
				}
			}
		}
		'opacity' {
			if base.box.opacity != 1.0 {
				return out
			}
			trimmed := value.trim_space()
			raw := if trimmed.ends_with('%') { trimmed[..trimmed.len - 1] } else { trimmed }
			number := cascade_length(raw) or {
				cascade_warn(mut warnings, out, decl.prop, 'expected a number or percentage')
				return out
			}
			opacity := if trimmed.ends_with('%') { number / 100 } else { number }
			return Element{
				...out
				box: BoxStyle{
					...out.box
					opacity: unit_clamp(opacity)
				}
			}
		}
		'box-shadow' {
			if value.to_lower() == 'none' {
				return out
			}
			if base.box.shadow.opacity != 0 {
				return out
			}
			shadow := cascade_shadow(value) or {
				cascade_warn(mut warnings, out, decl.prop, 'expected `<color> [blur] [x y] [spread]`')
				return out
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					shadow: shadow
				}
			}
		}
		'padding', 'margin', 'gap' {
			cascade_warn(mut warnings, out, decl.prop, 'layout-owned in v1: parsed, not applied yet')
			return out
		}
		else {
			cascade_warn(mut warnings, out, decl.prop, 'unknown property')
			return out
		}
	}
}

fn cascade_length(raw string) ?f64 {
	lower := raw.trim_space().to_lower()
	number := if lower.ends_with('px') { lower[..lower.len - 2] } else { lower }
	if number.contains(' ') || number.len == 0 {
		return none
	}
	value := number.f64()
	if value != value || value < 0 || value > 100000 {
		return none
	}
	// f64() yields 0 for garbage; reject non-numeric text that is not zero.
	if value == 0 && number != '0' && !number.starts_with('0.') && number != '.0'
		&& number != '0.0' {
		return none
	}
	return value
}

fn cascade_shadow(raw string) ?BoxShadow {
	parts := raw.trim_space().fields()
	if parts.len == 0 {
		return none
	}
	// Color is the first token that parses as a color; the rest are lengths.
	mut color := ?u32(none)
	mut opacity := 1.0
	mut numbers := []f64{}
	for part in parts {
		if token := component_theme_token(part) {
			if color == none {
				color = token.color & 0xffffff
				opacity = token.opacity
				continue
			}
		}
		numbers << cascade_length(part) or { return none }
	}
	solid := color or { return none }
	mut blur := 0.0
	mut x := 0.0
	mut y := 0.0
	mut spread := 0.0
	if numbers.len > 0 {
		blur = numbers[0]
	}
	if numbers.len > 1 {
		x = numbers[1]
	}
	if numbers.len > 2 {
		y = numbers[2]
	}
	if numbers.len > 3 {
		spread = numbers[3]
	}
	if numbers.len > 4 {
		return none
	}
	return BoxShadow{
		color:   solid
		opacity: opacity
		blur:    blur
		x:       x
		y:       y
		spread:  spread
	}
}
