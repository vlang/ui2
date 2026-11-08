module ui2

// A focus trap keeps Tab and Shift+Tab cycling through the controls of a modal
// dialog or sheet instead of escaping to the page behind it. Components cannot
// capture keys, and focus() and focused_id() belong to the backends, so these
// are pure helpers: the application reads the key in its handler, asks for the
// next id and passes it to focus():
//
//	fn on_key(key string) {
//		backwards := ui2.focus_trap_key_direction(key) or { return }
//		if next := ui2.focus_trap_target(app.traps(), ui2.focused_id(), backwards) {
//			ui2.consume_key()
//			ui2.focus(next)
//		}
//	}
//
// AppKit reports Tab pressed in a focused text field only to on_key, as
// 'tab' or 'shift+tab', and only for a field that emits change events
// (text_field_with_change and friends). Otherwise, and on the other backends,
// Tab reaches on_key_event first, where focus_trap_direction reads it.

// FocusTrap is one area Tab cycles through.
pub struct FocusTrap {
pub:
	ids     []string // the focusable element ids, in Tab order
	enabled bool = true
	// modal pulls focus into the trap when Tab is pressed outside it, as a
	// modal dialog should; a non-modal trap only confines focus already inside.
	modal bool = true
}

// focus_trap_unique drops empty and repeated ids, keeping the first of each.
fn focus_trap_unique(ids []string) []string {
	mut seen := map[string]bool{}
	mut result := []string{cap: ids.len}
	for id in ids {
		if id.len == 0 || id in seen {
			continue
		}
		seen[id] = true
		result << id
	}
	return result
}

// focus_trap_next returns the id Tab (or Shift+Tab, backwards) moves to from
// current, wrapping at either end. A current id outside the list moves to the
// first id, or the last one backwards. It returns '' when ids has no usable id.
pub fn focus_trap_next(ids []string, current string, backwards bool) string {
	order := focus_trap_unique(ids)
	if order.len == 0 {
		return ''
	}
	index := order.index(current)
	if index < 0 {
		return if backwards { order[order.len - 1] } else { order[0] }
	}
	step := if backwards { order.len - 1 } else { 1 }
	return order[(index + step) % order.len]
}

// focus_trap_direction reads Tab from on_key_event: false for Tab, true for
// Shift+Tab, none for any other key or a Tab with another modifier.
pub fn focus_trap_direction(event KeyEvent) ?bool {
	if event.code != .tab || event.ctrl || event.alt || event.cmd {
		return none
	}
	return event.shift
}

// focus_trap_key_direction is focus_trap_direction for the normalized strings
// on_key receives.
pub fn focus_trap_key_direction(key string) ?bool {
	return match key {
		'tab' { false }
		'shift+tab' { true }
		else { none }
	}
}

// contains reports whether the trap is enabled and id is one of its ids.
pub fn (trap FocusTrap) contains(id string) bool {
	return trap.enabled && id.len > 0 && id in trap.ids
}

// first is the id to focus when the trap opens.
pub fn (trap FocusTrap) first() ?string {
	if !trap.enabled {
		return none
	}
	order := focus_trap_unique(trap.ids)
	return if order.len > 0 { order[0] } else { none }
}

// next is focus_trap_next for this trap: none when it is disabled or empty,
// or when current is outside a non-modal trap.
pub fn (trap FocusTrap) next(current string, backwards bool) ?string {
	if !trap.enabled || (!trap.modal && !trap.contains(current)) {
		return none
	}
	target := focus_trap_next(trap.ids, current, backwards)
	return if target.len > 0 { target } else { none }
}

// focus_trap_target picks the trap a Tab belongs to and returns where focus
// goes. List traps from the outermost to the innermost, or from the bottom
// overlay to the top one: the last enabled trap holding current wins, so a
// nested trap confines focus inside it; with none holding it, the last enabled
// modal trap pulls focus in. none means Tab is not the traps' business.
pub fn focus_trap_target(traps []FocusTrap, current string, backwards bool) ?string {
	for i := traps.len - 1; i >= 0; i-- {
		if traps[i].contains(current) {
			return traps[i].next(current, backwards)
		}
	}
	for i := traps.len - 1; i >= 0; i-- {
		if traps[i].enabled && traps[i].modal {
			return traps[i].next(current, backwards)
		}
	}
	return none
}

// focus_trap_ids lists, in tree order, the ids of the visible and enabled text
// fields and text areas in elements, which are the controls focus() can move to
// on every backend. Build a FocusTrap from the body children of a dialog or
// sheet with it.
pub fn focus_trap_ids(elements []Element) []string {
	mut ids := []string{}
	for el in elements {
		focus_trap_collect(el, mut ids)
	}
	return ids
}

fn focus_trap_collect(el Element, mut ids []string) {
	if el.hidden || !el.enabled {
		return
	}
	if el.kind in [.text_field, .text_area] && el.id.len > 0 {
		ids << el.id
	}
	for child in el.children {
		focus_trap_collect(child, mut ids)
	}
}
