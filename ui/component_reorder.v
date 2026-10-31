module ui2

import encoding.hex
import math

// A reorder container lays its items out along one axis and lets them be moved:
// drag an item to a new place, or move the item the keyboard cursor is on with
// Alt and the arrows. It draws nothing of its own. Each item is an element the
// application builds and keys, and keyed items keep their native state as they
// move. Like the other components it is controlled: pass pointer events to
// reorder_update and keys to reorder_key, store the state they return, and
// apply a reported move with reorder_move.

const reorder_drag_threshold = 4.0
const reorder_scroller_width = 6.0

// ReorderDrag is an item being dragged. Pointer positions are in window points.
pub struct ReorderDrag {
pub:
	item    string // The key of the item pressed; empty when no press is under way.
	start_x f64
	start_y f64
	x       f64
	y       f64
	active  bool // The pointer moved far enough for the press to be a drag.
}

// ReorderState is a reorder container's controlled state. The application keeps
// it, passes it in, and stores what reorder_update and reorder_key return.
pub struct ReorderState {
pub:
	active string // The keyboard cursor: the item last pressed, or moved with the keys.
	drag   ReorderDrag
}

// ReorderConfig describes a reorder container.
pub struct ReorderConfig {
pub:
	id    string
	frame Rect
	axis  Orientation = .vertical
	// items are the elements in order. Each needs a key unique among them: the
	// state names items by it, and it keeps an item's native state as the item
	// moves. An item's length is its frame's height along a vertical axis and its
	// width along a horizontal one; its position is ignored, and it is stretched
	// across the container. A disabled item stays where it is: it cannot be
	// dragged, and the others cannot be moved past it.
	items []Element
	state ReorderState
	// gap is the space between items, and padding the space kept from each end
	// of the frame.
	gap     f64
	padding f64
	// offset is the scroll position along the axis that reorder_reveal_offset
	// starts from. Store scroll_offset (scroll_horizontal_offset on a horizontal
	// axis) of reorder_scroll_id(id) when on_scroll reports it.
	offset f64
	// handle puts a grip at each item's leading edge and makes only the grip
	// draggable, so the item's own buttons and clickable surfaces keep their
	// presses.
	handle              bool
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// ReorderStep is what reorder_update or reorder_key did: the state to store and
// what else the application has to do.
pub struct ReorderStep {
pub:
	state ReorderState
	// moved is set when an item lands somewhere new: arrange the application's
	// array with reorder_move(items, from, to). `to` is the item's index after
	// the move.
	moved bool
	from  int
	to    int
	// clicked is the key of an item pressed and released without a drag.
	clicked string
	// reveal is set when a key moved the item: after the move, scroll it into
	// view with reorder_reveal_offset.
	reveal bool
}

// ReorderLayout is where a reorder container puts its items, in the coordinates
// of its content: the frame itself, or the scrolled content when it scrolls.
pub struct ReorderLayout {
pub:
	axis    Orientation
	items   []Rect // Each item, stretched across the content.
	length  f64    // The content's length along the axis, padding included.
	scrolls bool   // The content is longer than the frame, which then scrolls.
mut:
	list     VirtualListLayout
	viewport f64
}

// reorder_item_action is the action a press on the item named key emits.
pub fn reorder_item_action(id string, key string) string {
	return component_part_id(id, 'item:' + key.bytes().hex())
}

// reorder_scroll_id is the id of the Scroll element the items scroll in when
// they are longer than the frame.
pub fn reorder_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

// reorder_action_key decodes the key of the item a pointer event named.
fn reorder_action_key(id string, action string) ?string {
	part := component_action_part(id, action)?
	if !part.starts_with('item:') {
		return none
	}
	return reorder_hex_text(part['item:'.len..])
}

// reorder_hex_text decodes the lowercase hex an action carries. Other spellings
// of the same bytes were not written by the container, so they are rejected.
fn reorder_hex_text(digits string) ?string {
	if digits.len == 0 {
		return none
	}
	bytes := hex.decode(digits) or { return none }
	if bytes.hex() != digits {
		return none
	}
	return bytes.bytestr()
}

fn reorder_index(items []Element, key string) int {
	for index, item in items {
		if item.key == key {
			return index
		}
	}
	return -1
}

// reorder_layout places the items along the axis, gap apart and padding in from
// each end, and stretches each one across the frame.
pub fn reorder_layout(config ReorderConfig) !ReorderLayout {
	component_validate_frame(config.frame)!
	if !component_finite(config.gap) || config.gap < 0 {
		return error('reorder gap must be finite and non-negative')
	}
	if !component_finite(config.padding) || config.padding < 0 {
		return error('reorder padding must be finite and non-negative')
	}
	horizontal := config.axis == .horizontal
	mut sizes := []f64{cap: config.items.len}
	mut keys := map[string]bool{}
	for item in config.items {
		if item.key.len == 0 {
			return error('reorder items need a key, which names them in the state')
		}
		if item.key in keys {
			return error('duplicate reorder item key `${item.key}`')
		}
		keys[item.key] = true
		if item.hidden {
			return error('reorder item `${item.key}` is hidden; leave it out of the items instead')
		}
		length := if horizontal { item.frame.width } else { item.frame.height }
		if !component_finite(length) || length < 0 {
			return error('reorder item `${item.key}` needs a finite, non-negative length')
		}
		sizes << length
	}
	item_list := virtual_list_sized(sizes, config.gap)!.padded(config.padding)!
	viewport := if horizontal { config.frame.width } else { config.frame.height }
	scrolls := item_list.total() > viewport + 0.5
	// The scroller is drawn over the content's far edge, so items keep clear of it.
	scroller := if scrolls { reorder_scroller_width } else { 0.0 }
	cross_extent := if horizontal { config.frame.height } else { config.frame.width }
	cross := math.max(cross_extent - 2 * config.padding - scroller, 0)
	mut items := []Rect{cap: sizes.len}
	for index in 0 .. sizes.len {
		start := item_list.item_start(index)
		size := item_list.item_size(index)
		items << if horizontal {
			rect(start, config.padding, size, cross)
		} else {
			rect(config.padding, start, cross, size)
		}
	}
	return ReorderLayout{
		axis:     config.axis
		items:    items
		length:   item_list.total()
		scrolls:  scrolls
		list:     item_list
		viewport: viewport
	}
}

// span is where the item at index starts along the axis and how long it is.
fn (layout ReorderLayout) span(index int) (f64, f64) {
	place := layout.items[index]
	return if layout.axis == .horizontal { place.x, place.width } else { place.y, place.height }
}

// reorder_bounds is the span of places the item at from may take. Disabled items
// keep their places, so the item cannot move past them.
fn reorder_bounds(items []Element, from int) (int, int) {
	mut low := 0
	mut high := items.len - 1
	for index, item in items {
		if index == from || item.enabled {
			continue
		}
		if index < from {
			low = math.max(low, index + 1)
		} else {
			high = math.min(high, index - 1)
		}
	}
	return low, high
}

// reorder_delta is how far the pointer has moved along the axis since the press.
fn reorder_delta(drag ReorderDrag, axis Orientation) f64 {
	return if axis == .horizontal { drag.x - drag.start_x } else { drag.y - drag.start_y }
}

// reorder_drop is where the item at from lands when it is dragged `travel` along
// the axis. It returns that travel, kept within the places the item may take, and
// the index it lands at: the number of other items whose middles its middle has
// passed.
fn reorder_drop(items []Element, layout ReorderLayout, from int, travel f64) (f64, int) {
	low, high := reorder_bounds(items, from)
	start, size := layout.span(from)
	low_start, _ := layout.span(low)
	high_start, high_size := layout.span(high)
	delta := math.min(math.max(travel, low_start - start), high_start + high_size - size - start)
	center := start + size / 2 + delta
	mut to := 0
	for index in 0 .. items.len {
		if index == from {
			continue
		}
		other_start, other_size := layout.span(index)
		if center > other_start + other_size / 2 {
			to++
		}
	}
	return delta, math.min(math.max(to, low), high)
}

// reorder_shifts is how far each item is drawn from its place while the item at
// from is dragged to `to`: the items it passes move into the place it left.
fn reorder_shifts(layout ReorderLayout, gap f64, from int, to int) []f64 {
	_, size := layout.span(from)
	room := size + gap
	mut shifts := []f64{len: layout.items.len}
	for index in 0 .. shifts.len {
		if index > from && index <= to {
			shifts[index] = -room
		} else if index < from && index >= to {
			shifts[index] = room
		}
	}
	return shifts
}

// reorder_update applies an event from on_event to a reorder container. A press
// on an item and the drag that follows it are kept in the state. Released after a
// drag, the item lands where the pointer left it, which `moved`, `from` and `to`
// report. Released where it was pressed, it is a click, which `clicked` reports,
// and it becomes the keyboard cursor. It returns none for events that are not the
// container's, malformed or forged ones, presses on disabled items, and drags of
// items that were not pressed.
pub fn reorder_update(config ReorderConfig, event string) ?ReorderStep {
	pointer := parse_pointer_event(event)?
	key := reorder_action_key(config.id, pointer.action)?
	from := reorder_index(config.items, key)
	if from < 0 {
		return none
	}
	now := config.state
	match pointer.phase {
		'down' {
			if !config.items[from].enabled || !component_finite(pointer.x) || !component_finite(pointer.y) {
				return none
			}
			return ReorderStep{
				state: ReorderState{
					...now
					drag: ReorderDrag{
						item:    key
						start_x: pointer.x
						start_y: pointer.y
						x:       pointer.x
						y:       pointer.y
					}
				}
			}
		}
		'drag' {
			if now.drag.item != key || !component_finite(pointer.x) || !component_finite(pointer.y) {
				return none
			}
			dx := pointer.x - now.drag.start_x
			dy := pointer.y - now.drag.start_y
			return ReorderStep{
				state: ReorderState{
					...now
					drag: ReorderDrag{
						...now.drag
						x:      pointer.x
						y:      pointer.y
						active: now.drag.active || dx * dx + dy * dy > reorder_drag_threshold * reorder_drag_threshold
					}
				}
			}
		}
		'up' {
			if now.drag.item != key {
				return none
			}
			ended := ReorderState{
				...now
				active: key
				drag:   ReorderDrag{}
			}
			if !now.drag.active {
				return ReorderStep{
					state:   ended
					clicked: key
				}
			}
			layout := reorder_layout(config) or {
				return ReorderStep{
					state: ended
				}
			}
			released := ReorderDrag{
				...now.drag
				x: if component_finite(pointer.x) { pointer.x } else { now.drag.x }
				y: if component_finite(pointer.y) { pointer.y } else { now.drag.y }
			}
			_, to := reorder_drop(config.items, layout, from, reorder_delta(released, config.axis))
			return ReorderStep{
				state: ended
				moved: to != from
				from:  from
				to:    to
			}
		}
		else {
			return none
		}
	}
}

// reorder_key moves the keyboard cursor's item from on_key_event: Alt (Option on
// macOS) with the arrows along the axis moves it one place, and Alt with Home or
// End moves it to the first or last place it may take. It returns none for other
// keys and modifiers, when no item is the cursor, when the cursor's item is
// disabled, and when the move goes nowhere. Consume the key whenever a step comes
// back.
pub fn reorder_key(config ReorderConfig, event KeyEvent) ?ReorderStep {
	if !event.alt || event.cmd || event.ctrl || event.shift || config.state.drag.active {
		return none
	}
	from := reorder_index(config.items, config.state.active)
	if from < 0 || !config.items[from].enabled {
		return none
	}
	low, high := reorder_bounds(config.items, from)
	horizontal := config.axis == .horizontal
	backward := if horizontal { event.code == .left } else { event.code == .up }
	forward := if horizontal { event.code == .right } else { event.code == .down }
	mut to := from
	if backward {
		to = math.max(from - 1, low)
	} else if forward {
		to = math.min(from + 1, high)
	} else if event.code == .home {
		to = low
	} else if event.code == .end {
		to = high
	} else {
		return none
	}
	if to == from {
		return none
	}
	return ReorderStep{
		state:  config.state
		moved:  true
		from:   from
		to:     to
		reveal: true
	}
}

// reorder_reveal_offset is the scroll offset of reorder_scroll_id(id) that shows
// the item named key, scrolling as little as it can from config.offset. It returns
// none when the items fit the frame or no item has the key.
pub fn reorder_reveal_offset(config ReorderConfig, key string) ?f64 {
	index := reorder_index(config.items, key)
	if index < 0 {
		return none
	}
	layout := reorder_layout(config) or { return none }
	if !layout.scrolls {
		return none
	}
	current := if component_finite(config.offset) { config.offset } else { 0.0 }
	return layout.list.scroll_offset_for(index, layout.viewport, current, .nearest)
}

// reorder_move arranges items the way a step that reported `moved` did: the item
// at from is taken out and put back at index to.
pub fn reorder_move[T](items []T, from int, to int) []T {
	if from < 0 || from >= items.len || to < 0 || to >= items.len || from == to {
		return items.clone()
	}
	mut out := items.clone()
	moved := out[from]
	out.delete(from)
	out.insert(to, moved)
	return out
}

// reorder_placed moves a place along the axis by shift.
fn reorder_placed(place Rect, axis Orientation, shift f64) Rect {
	return if axis == .horizontal {
		rect(place.x + shift, place.y, place.width, place.height)
	} else {
		rect(place.x, place.y + shift, place.width, place.height)
	}
}

// reorder_grip_dots draws a grip's dots: cols by rows of square dots, `dot`
// points across and a dot apart, centred in the grip's frame.
fn reorder_grip_dots(frame Rect, cols int, rows int, dot f64, color u32) []Element {
	span_x := f64(cols) * 2 * dot - dot
	span_y := f64(rows) * 2 * dot - dot
	x0 := math.round((frame.width - span_x) / 2)
	y0 := math.round((frame.height - span_y) / 2)
	mut dots := []Element{cap: cols * rows}
	for row in 0 .. rows {
		for col in 0 .. cols {
			dots << view('', rect(x0 + f64(col) * 2 * dot, y0 + f64(row) * 2 * dot, dot, dot), BoxStyle{
				bg:     color
				radius: dot / 2
			}, []Element{})
		}
	}
	return dots
}

// reorder_item_element draws one item in its place. Without a handle the whole
// item is the press; with one, only the grip along its leading edge is.
fn reorder_item_element(config ReorderConfig, item Element, place Rect, lifted bool, m ComponentMetrics) Element {
	action := reorder_item_action(config.id, item.key)
	box := if lifted {
		BoxStyle{
			transparent: true
			radius:      m.radius
			shadow:      component_card_shadow()
		}
	} else {
		BoxStyle{
			transparent: true
		}
	}
	if !config.handle {
		return Element{
			...view(action, place, box, [
				Element{
					...item
					frame: rect(0, 0, place.width, place.height)
				},
			])
			key:                item.key
			draggable:          item.enabled
			accessibility_role: 'listitem'
		}
	}
	horizontal := config.axis == .horizontal
	across := if horizontal { place.height } else { place.width }
	grip := math.min(math.round(m.height / 2), across)
	dot := math.max(math.round(m.font_size / 5), 2)
	grip_frame := if horizontal {
		rect(0, 0, place.width, grip)
	} else {
		rect(0, 0, grip, place.height)
	}
	body_frame := if horizontal {
		rect(0, grip, place.width, math.max(place.height - grip, 0))
	} else {
		rect(grip, 0, math.max(place.width - grip, 0), place.height)
	}
	color := if item.enabled { config.theme.muted_foreground } else { config.theme.border }
	dots := if horizontal {
		reorder_grip_dots(grip_frame, 3, 2, dot, color)
	} else {
		reorder_grip_dots(grip_frame, 2, 3, dot, color)
	}
	return Element{
		...view('', place, box, [
			Element{
				...view(action, grip_frame, BoxStyle{
					transparent: true
				}, dots)
				draggable: item.enabled
			},
			Element{
				...item
				frame: body_frame
			},
		])
		key:                item.key
		accessibility_role: 'listitem'
	}
}

// reorder_container draws the items in order along the axis. While an item is
// dragged it follows the pointer and floats above the others, and the items it
// passes move aside to show where it will land. Items longer than the frame
// scroll in reorder_scroll_id(id). It is controlled: store what reorder_update
// and reorder_key return and rebuild.
pub fn reorder_container(config ReorderConfig) !Element {
	component_validate_id(config.id)!
	layout := reorder_layout(config)!
	m := component_metrics(config.size)
	drag := config.state.drag
	from := if drag.active { reorder_index(config.items, drag.item) } else { -1 }
	mut delta := 0.0
	mut to := from
	if from >= 0 {
		delta, to = reorder_drop(config.items, layout, from, reorder_delta(drag, config.axis))
	}
	shifts := if from >= 0 {
		reorder_shifts(layout, config.gap, from, to)
	} else {
		[]f64{len: config.items.len}
	}
	mut rows := []Element{cap: config.items.len}
	mut lifted := []Element{}
	for index, item in config.items {
		shift := if index == from { delta } else { shifts[index] }
		place := reorder_placed(layout.items[index], config.axis, shift)
		if index == from {
			lifted << reorder_item_element(config, item, place, true, m)
		} else {
			rows << reorder_item_element(config, item, place, false, m)
		}
	}
	rows << lifted
	local := rect(0, 0, config.frame.width, config.frame.height)
	axis_mode := if config.axis == .horizontal {
		ScrollMode.horizontal_only
	} else {
		ScrollMode.vertical_only
	}
	body := if layout.scrolls {
		Element{
			...scroll_with_mode(reorder_scroll_id(config.id), local, 0, axis_mode, rows)
			box: BoxStyle{
				transparent: true
			}
			key: 'scroll'
		}
	} else {
		Element{
			...view('', local, BoxStyle{
				transparent: true
			}, rows)
			key: 'rows'
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{
			transparent: true
		}, [body])
		accessibility_role:  'list'
		accessibility_label: config.accessibility_label
	})
}
