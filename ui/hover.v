module ui2

import strconv

// PointerEvent is a decoded `pointer:<phase>:<action>:<x>:<y>` event. Clickable
// and draggable elements report the `down`, `drag` and `up` phases; hoverable
// ones report `enter` and `leave`. Coordinates are in window points.
pub struct PointerEvent {
pub:
	phase  string
	action string
	x      f64
	y      f64
}

// parse_pointer_event decodes a pointer event received by an on_event handler,
// or returns none for any other event. Actions may themselves contain colons
// (component actions do), so the coordinates are read from the end.
pub fn parse_pointer_event(event string) ?PointerEvent {
	if !event.starts_with('pointer:') {
		return none
	}
	rest := event['pointer:'.len..]
	phase_end := rest.index(':') or { return none }
	tail := rest[phase_end + 1..]
	y_start := tail.last_index(':') or { return none }
	x_start := tail[..y_start].last_index(':') or { return none }
	if phase_end == 0 || x_start == 0 {
		return none
	}
	x := strconv.atof64(tail[x_start + 1..y_start]) or { return none }
	y := strconv.atof64(tail[y_start + 1..]) or { return none }
	return PointerEvent{
		phase:  rest[..phase_end]
		action: tail[..x_start]
		x:      x
		y:      y
	}
}

// with_hover makes an element report `pointer:enter:<action>:<x>:<y>` when the
// pointer comes over it and `pointer:leave:...` when it goes, so a hover card can
// open or a row can highlight. The action falls back to the id, as for taps.
//
// Hover follows the CSS :hover rule on every backend: an element is hovered
// while the topmost element under the pointer is it or one of its descendants,
// so moving onto a child keeps its hoverable ancestors hovered, and an element
// covered by another one (an open popover, say) is not hovered.
pub fn with_hover(el Element) Element {
	return Element{
		...el
		hoverable: true
	}
}

// hover_transitions compares the hovered chains before and after a pointer
// move, each listed from the outermost element in. It returns the actions to
// report as left — innermost first — and as entered — outermost first, the
// order the DOM fires mouseleave and mouseenter in.
fn hover_transitions(previous []string, current []string) ([]string, []string) {
	mut left := []string{}
	for i := previous.len - 1; i >= 0; i-- {
		if previous[i] !in current {
			left << previous[i]
		}
	}
	mut entered := []string{}
	for action in current {
		if action !in previous {
			entered << action
		}
	}
	return left, entered
}
