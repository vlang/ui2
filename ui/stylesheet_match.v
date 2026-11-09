module ui2

// P1 stylesheet matching: does a parsed selector match an element?
//
// Matching is pure and backend-independent. The caller walks the tree and
// supplies the element, its ancestor chain (with sibling positions, so
// structural pseudo-classes work on every level), the element's own
// position, and a StyleMatchEnv with the transient interaction state the
// application keeps (hovered/pressed/focused ids) plus the color mode.

pub struct StyleMatchEnv {
pub:
	hovered string // id of the element under the pointer
	pressed string // id of the pressed element
	focused string // id of the keyboard-focused element (besides Element.focused)
	dark    bool   // resolve theme variables for dark mode
	dpi     f64    // device pixel ratio from the backend; <= 0 means unknown
}

// StyleAncestor snapshots one ancestor with its position among its siblings,
// so left-hand selector parts can carry structural pseudo-classes too.
pub struct StyleAncestor {
pub:
	el    Element
	index int // position among siblings, 0-based
	count int // number of siblings including self
}

// stylesheet_selector_matches reports whether sel matches el.
pub fn stylesheet_selector_matches(sel StyleSelector, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
	// Rightmost part matches the element itself; walk left through ancestors.
	right := sel.parts.len - 1
	if !style_part_matches(sel.parts[right], el, ancestors, index, count, env) {
		return false
	}
	mut ancestor_pos := ancestors.len - 1
	for part_index := right - 1; part_index >= 0; part_index-- {
		combinator := sel.combinators[part_index]
		if ancestor_pos < 0 {
			return false
		}
		if combinator == .child {
			ancestor := ancestors[ancestor_pos]
			if !style_part_matches(sel.parts[part_index], ancestor.el, ancestors, ancestor.index,
				ancestor.count, env) {
				return false
			}
			ancestor_pos--
		} else {
			mut found := false
			for ancestor_pos >= 0 {
				ancestor := ancestors[ancestor_pos]
				if style_part_matches(sel.parts[part_index], ancestor.el, ancestors, ancestor.index,
					ancestor.count, env) {
					found = true
					ancestor_pos--
					break
				}
				ancestor_pos--
			}
			if !found {
				return false
			}
		}
	}
	return true
}

fn style_part_matches(part StyleSelectorPart, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
	if !part.universal && part.kind.len > 0 {
		if part.kind.to_lower() != el.kind.str() {
			return false
		}
	}
	if part.id.len > 0 && part.id != el.id {
		return false
	}
	for class in part.classes {
		if class !in el.classes {
			return false
		}
	}
	for pseudo in part.pseudos {
		if !style_pseudo_matches(pseudo, el, ancestors, index, count, env) {
			return false
		}
	}
	return true
}

// style_id_matches compares a state id against an element. Backends track the
// hover/press/focus chain by action id (the event identity, falling back to
// the element id), so either one matches.
fn style_id_matches(el Element, want string) bool {
	if want.len == 0 {
		return false
	}
	if el.id == want {
		return true
	}
	return el.action_id.len > 0 && el.action_id == want
}

fn style_pseudo_matches(pseudo StylePseudo, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
	match pseudo.name {
		'hover' { return style_id_matches(el, env.hovered) }
		'pressed' { return style_id_matches(el, env.pressed) }
		'focused' { return el.focused || style_id_matches(el, env.focused) }
		'disabled' { return !el.enabled }
		'enabled' { return el.enabled }
		'checked' { return el.checked }
		'selected' { return el.checked || el.accessibility_value == 'selected' }
		'first-child' { return index == 0 }
		'last-child' { return count > 0 && index == count - 1 }
		'only-child' { return count == 1 }
		'empty' { return el.children.len == 0 && el.text.len == 0 }
		'nth-child' {
			return style_nth_matches(pseudo.arg, index)
		}
		else {
			return style_plugin_match_pseudo(pseudo, el, ancestors, index, count, env)
		}
	}
}

fn style_nth_matches(arg string, index int) bool {
	n := index + 1 // CSS counts from 1
	if arg == 'odd' {
		return n % 2 == 1
	}
	if arg == 'even' {
		return n % 2 == 0
	}
	return n == arg.int()
}
