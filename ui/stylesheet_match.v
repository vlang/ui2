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

// StyleRuleIndex files a sheet's rules by their selectors' subject (the
// rightmost compound): kind, id, and class buckets plus a universal bucket
// for subjects constraining none of those. Per element the cascade gathers
// only the buckets the element can match instead of attempting every rule.
// Built once per sheet at construction; sheets assembled by hand (tests,
// ad-hoc literals) carry an empty index and fall back to a full scan. So
// does a sheet whose rules changed after indexing (`Stylesheet{...sheet,
// rules: more}`): the index remembers how many rules it filed, and a count
// that no longer matches means it is stale. Rebuild it with
// stylesheet_index_rules after editing rules to keep the fast path.
pub struct StyleRuleIndex {
pub:
	by_kind    map[string][]int
	by_id      map[string][]int
	by_class   map[string][]int
	universal  []int
	rule_count int // rules.len when built; a mismatch marks the index stale
}

// stylesheet_index_rules files rule indices by subject. Every rule lands in
// at least one bucket, so a non-empty index always covers a non-empty sheet.
pub fn stylesheet_index_rules(rules []StyleRule) StyleRuleIndex {
	mut by_kind := map[string][]int{}
	mut by_id := map[string][]int{}
	mut by_class := map[string][]int{}
	mut universal := []int{}
	for rule_index, rule in rules {
		for sel in rule.selectors {
			if sel.parts.len == 0 {
				universal << rule_index
				continue
			}
			subject := sel.parts[sel.parts.len - 1]
			mut filed := false
			if subject.id.len > 0 {
				mut slot := by_id[subject.id] or { []int{} }
				slot << rule_index
				by_id[subject.id] = slot
				filed = true
			}
			for class in subject.classes {
				mut slot := by_class[class] or { []int{} }
				slot << rule_index
				by_class[class] = slot
				filed = true
			}
			if !subject.universal && subject.kind.len > 0 {
				mut slot := by_kind[subject.kind] or { []int{} }
				slot << rule_index
				by_kind[subject.kind] = slot
				filed = true
			}
			if !filed {
				universal << rule_index
			}
		}
	}
	return StyleRuleIndex{
		by_kind:    by_kind
		by_id:      by_id
		by_class:   by_class
		universal:  universal
		rule_count: rules.len
	}
}

// stylesheet_index_covers reports whether a sheet carries a usable index.
// Hand-built sheets (empty index, non-empty rules) and sheets whose rules
// were added or removed after indexing fall back to full scan; trusting a
// stale index would skip new rules or read past the end of the list.
// Keep the bucket list here in sync with StyleRuleIndex: a new bucket left
// out would make an index holding only that bucket look absent (a safe
// full scan, but a silent slowdown).
fn stylesheet_index_covers(sheet Stylesheet) bool {
	if sheet.rules.len == 0 || sheet.rule_index.rule_count != sheet.rules.len {
		return false
	}
	return sheet.rule_index.universal.len > 0 || sheet.rule_index.by_kind.len > 0
		|| sheet.rule_index.by_id.len > 0 || sheet.rule_index.by_class.len > 0
}

// stylesheet_selector_matches reports whether sel matches el.
pub fn stylesheet_selector_matches(sel StyleSelector, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
	// Rightmost part matches the element itself; walk left through ancestors.
	// The kind name is computed once: part kinds are lowercased at parse
	// time, so the kind check below allocates nothing.
	kind_name := el.kind.str()
	right := sel.parts.len - 1
	if !style_part_matches(sel.parts[right], kind_name, el, ancestors, index, count, env) {
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
			if !style_part_matches(sel.parts[part_index], ancestor.el.kind.str(), ancestor.el,
				ancestors, ancestor.index, ancestor.count, env) {
				return false
			}
			ancestor_pos--
		} else {
			mut found := false
			for ancestor_pos >= 0 {
				ancestor := ancestors[ancestor_pos]
				if style_part_matches(sel.parts[part_index], ancestor.el.kind.str(), ancestor.el,
					ancestors, ancestor.index, ancestor.count, env) {
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

fn style_part_matches(part StyleSelectorPart, kind_name string, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
	if !part.universal && part.kind.len > 0 {
		if part.kind != kind_name {
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
