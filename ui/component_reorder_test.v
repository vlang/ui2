module ui2

import math

// Items are labels keyed by name, so each one has a real frame to be ordered by.

fn reorder_test_sized(key string, width f64, height f64) Element {
	return Element{
		...label('text_${key}', key, rect(0, 0, width, height), TextStyle{})
		key: key
	}
}

// reorder_test_queue is three items along a vertical axis, 40, 60 and 20 points long.
fn reorder_test_queue() []Element {
	return [
		reorder_test_sized('a', 120, 40),
		reorder_test_sized('b', 120, 60),
		reorder_test_sized('c', 120, 20),
	]
}

fn reorder_test_config(items []Element) ReorderConfig {
	return ReorderConfig{
		id:      'queue'
		frame:   rect(0, 0, 240, 300)
		items:   items
		gap:     8
		padding: 4
	}
}

fn reorder_test_pointer(phase string, key string, x f64, y f64) string {
	action := reorder_item_action('queue', key)
	return 'pointer:${phase}:${action}:${x}:${y}'
}

// reorder_test_drop presses key at (x, y), drags it by travel along the vertical
// axis and releases it, returning the step of the release.
fn reorder_test_drop(config ReorderConfig, key string, x f64, y f64, travel f64) ReorderStep {
	down := reorder_update(config, reorder_test_pointer('down', key, x, y)) or {
		panic('press ignored')
	}
	moving := reorder_update(ReorderConfig{
		...config
		state: down.state
	}, reorder_test_pointer('drag', key, x, y + travel)) or { panic('drag ignored') }
	return reorder_update(ReorderConfig{
		...config
		state: moving.state
	}, reorder_test_pointer('up', key, x, y + travel)) or { panic('drop ignored') }
}

fn reorder_test_find(el Element, key string) ?Element {
	if el.key == key {
		return el
	}
	for child in el.children {
		if found := reorder_test_find(child, key) {
			return found
		}
	}
	return none
}

fn reorder_test_keys(items []Element) []string {
	mut keys := []string{}
	for item in items {
		keys << item.key
	}
	return keys
}

// reorder_test_rows are the item wrappers a container draws, in drawing order.
fn reorder_test_rows(root Element) []Element {
	return root.children[0].children
}

// ── Layout ──────────────────────────────────────────────────────────

fn test_reorder_layout_stacks_items_with_gap_and_padding() {
	layout := reorder_layout(reorder_test_config(reorder_test_queue())) or { panic(err) }
	assert layout.axis == .vertical
	assert layout.items[0] == rect(4, 4, 232, 40)
	assert layout.items[1] == rect(4, 52, 232, 60)
	assert layout.items[2] == rect(4, 120, 232, 20)
	assert layout.length == 144
	assert !layout.scrolls
}

fn test_reorder_layout_runs_along_a_horizontal_axis() {
	items := [reorder_test_sized('a', 30, 20), reorder_test_sized('b', 50, 20)]
	layout := reorder_layout(ReorderConfig{
		id:    'strip'
		frame: rect(0, 0, 200, 60)
		axis:  .horizontal
		items: items
		gap:   10
	}) or { panic(err) }
	assert layout.items[0] == rect(0, 0, 30, 60)
	assert layout.items[1] == rect(40, 0, 50, 60)
	assert layout.length == 90
	assert !layout.scrolls
}

fn test_reorder_layout_rejects_items_it_cannot_order() {
	if _ := reorder_layout(reorder_test_config([reorder_test_sized('', 120, 10)])) {
		assert false, 'keyless item accepted'
	}
	duplicate := [reorder_test_sized('a', 120, 10), reorder_test_sized('a', 120, 10)]
	if _ := reorder_layout(reorder_test_config(duplicate)) {
		assert false, 'duplicate key accepted'
	}
	hidden := Element{
		...reorder_test_sized('h', 120, 10)
		hidden: true
	}
	if _ := reorder_layout(reorder_test_config([hidden])) {
		assert false, 'hidden item accepted'
	}
	if _ := reorder_layout(reorder_test_config([reorder_test_sized('n', 120, -1)])) {
		assert false, 'negative length accepted'
	}
	if _ := reorder_layout(reorder_test_config([reorder_test_sized('n', 120, math.nan())])) {
		assert false, 'NaN length accepted'
	}
	gapless := ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		gap: -1
	}
	if _ := reorder_layout(gapless) {
		assert false, 'negative gap accepted'
	}
	unbounded := ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		padding: math.inf(1)
	}
	if _ := reorder_layout(unbounded) {
		assert false, 'infinite padding accepted'
	}
	narrow := ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		frame: rect(0, 0, -1, 10)
	}
	if _ := reorder_layout(narrow) {
		assert false, 'negative frame accepted'
	}
}

fn test_reorder_move_takes_an_item_to_its_new_index() {
	assert reorder_move(['a', 'b', 'c', 'd'], 0, 2) == ['b', 'c', 'a', 'd']
	assert reorder_move(['a', 'b', 'c', 'd'], 3, 0) == ['d', 'a', 'b', 'c']
	assert reorder_move(['a', 'b'], 1, 1) == ['a', 'b']
	assert reorder_move(['a', 'b'], 0, 5) == ['a', 'b']
}

// ── Pointer ─────────────────────────────────────────────────────────

fn test_reorder_drag_past_a_neighbour_moves_the_item() {
	config := reorder_test_config(reorder_test_queue())
	down := reorder_update(config, reorder_test_pointer('down', 'a', 20, 10)) or {
		panic('press ignored')
	}
	assert down.state.drag.item == 'a'
	assert !down.state.drag.active
	pressed := ReorderConfig{
		...config
		state: down.state
	}
	moving := reorder_update(pressed, reorder_test_pointer('drag', 'a', 20, 70)) or {
		panic('drag ignored')
	}
	assert moving.state.drag.active
	dragging := ReorderConfig{
		...config
		state: moving.state
	}
	dropped := reorder_update(dragging, reorder_test_pointer('up', 'a', 20, 70)) or {
		panic('drop ignored')
	}
	assert dropped.moved
	assert dropped.from == 0 && dropped.to == 1
	assert dropped.clicked == ''
	assert dropped.state.drag.item == ''
	assert dropped.state.active == 'a'
	assert reorder_test_keys(reorder_move(reorder_test_queue(), dropped.from, dropped.to)) == [
		'b',
		'a',
		'c',
	]
}

fn test_reorder_drop_where_the_item_started_moves_nothing() {
	config := reorder_test_config(reorder_test_queue())
	down := reorder_update(config, reorder_test_pointer('down', 'a', 20, 10)) or {
		panic('press ignored')
	}
	moving := reorder_update(ReorderConfig{
		...config
		state: down.state
	}, reorder_test_pointer('drag', 'a', 20, 16)) or { panic('drag ignored') }
	dropped := reorder_update(ReorderConfig{
		...config
		state: moving.state
	}, reorder_test_pointer('up', 'a', 20, 16)) or { panic('drop ignored') }
	assert !dropped.moved
	assert dropped.clicked == ''
	assert dropped.from == 0 && dropped.to == 0
}

fn test_reorder_release_without_a_drag_is_a_click() {
	config := reorder_test_config(reorder_test_queue())
	down := reorder_update(config, reorder_test_pointer('down', 'b', 20, 60)) or {
		panic('press ignored')
	}
	// Two points of movement stay under the drag threshold.
	nudged := reorder_update(ReorderConfig{
		...config
		state: down.state
	}, reorder_test_pointer('drag', 'b', 22, 60)) or { panic('drag ignored') }
	assert !nudged.state.drag.active
	click := reorder_update(ReorderConfig{
		...config
		state: nudged.state
	}, reorder_test_pointer('up', 'b', 22, 60)) or { panic('release ignored') }
	assert click.clicked == 'b'
	assert !click.moved
	assert click.state.active == 'b'
	assert click.state.drag.item == ''
}

fn test_reorder_ignores_forged_and_disabled_presses() {
	items := [
		reorder_test_sized('a', 120, 40),
		Element{
			...reorder_test_sized('b', 120, 60)
			enabled: false
		},
		reorder_test_sized('c', 120, 20),
	]
	config := reorder_test_config(items)
	// A disabled item cannot be picked up.
	assert reorder_update(config, reorder_test_pointer('down', 'b', 20, 60)) == none
	// Unknown keys, other containers' actions and malformed actions change nothing.
	other := reorder_item_action('other', 'a')
	assert reorder_update(config, reorder_test_pointer('down', 'zz', 20, 10)) == none
	assert reorder_update(config, 'pointer:down:${other}:20.0:10.0') == none
	assert reorder_update(config, 'pointer:down:queue:component:item:6:20.0:10.0') == none
	assert reorder_update(config, 'something else') == none
	// A drag or release without a press is ignored, and so is a hover report.
	assert reorder_update(config, reorder_test_pointer('drag', 'a', 20, 70)) == none
	assert reorder_update(config, reorder_test_pointer('up', 'a', 20, 70)) == none
	assert reorder_update(config, reorder_test_pointer('enter', 'a', 20, 10)) == none
}

// ── Disabled items ──────────────────────────────────────────────────

fn test_reorder_disabled_items_stay_put_and_block_passing() {
	items := [
		reorder_test_sized('a', 120, 40),
		Element{
			...reorder_test_sized('b', 120, 60)
			enabled: false
		},
		reorder_test_sized('c', 120, 20),
	]
	config := reorder_test_config(items)
	// c cannot pass the disabled b on the way up, and a cannot pass it on the way down.
	up := reorder_test_drop(config, 'c', 20, 130, -400)
	assert !up.moved
	assert up.to == 2
	down := reorder_test_drop(config, 'a', 20, 20, 400)
	assert !down.moved
	assert down.to == 0
	// Items on the same side of it still reorder.
	four := [
		reorder_test_sized('a', 120, 40),
		Element{
			...reorder_test_sized('b', 120, 60)
			enabled: false
		},
		reorder_test_sized('c', 120, 20),
		reorder_test_sized('d', 120, 20),
	]
	past := reorder_test_drop(reorder_test_config(four), 'd', 20, 158, -30)
	assert past.moved
	assert past.from == 3 && past.to == 2
	assert reorder_test_keys(reorder_move(four, past.from, past.to)) == ['a', 'b', 'd', 'c']
}

// ── Drawing ─────────────────────────────────────────────────────────

fn test_reorder_container_floats_the_dragged_item_and_shifts_the_items_it_passes() {
	config := ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		state: ReorderState{
			drag: ReorderDrag{
				item:    'a'
				start_x: 20
				start_y: 10
				x:       20
				y:       70
				active:  true
			}
		}
	}
	root := reorder_container(config) or { panic(err) }
	rows := reorder_test_rows(root)
	// The dragged item is drawn last, so it floats above the others.
	assert reorder_test_keys(rows) == ['b', 'c', 'a']
	// b moves up into the place a left, and a follows the pointer.
	assert rows[0].frame == rect(4, 4, 232, 60)
	assert rows[1].frame == rect(4, 120, 232, 20)
	assert rows[2].frame == rect(4, 64, 232, 40)
	assert rows[2].box.shadow.opacity > 0
	assert rows[0].box.shadow.opacity == 0
}

fn test_reorder_container_marks_items_draggable_unless_disabled() {
	items := [
		reorder_test_sized('a', 120, 40),
		Element{
			...reorder_test_sized('b', 120, 60)
			enabled: false
		},
	]
	root := reorder_container(reorder_test_config(items)) or { panic(err) }
	assert root.kind == .view
	assert root.accessibility_role == 'list'
	a := reorder_test_find(root, 'a') or { panic('no item a') }
	b := reorder_test_find(root, 'b') or { panic('no item b') }
	assert a.draggable
	assert a.id == reorder_item_action('queue', 'a')
	assert a.accessibility_role == 'listitem'
	assert !b.draggable
}

fn test_reorder_container_scrolls_a_queue_longer_than_its_frame() {
	fits := reorder_container(reorder_test_config(reorder_test_queue())) or { panic(err) }
	assert fits.children[0].kind == .view
	overflows := reorder_container(ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		frame: rect(0, 0, 240, 120)
	}) or { panic(err) }
	body := overflows.children[0]
	assert body.kind == .scroll
	assert body.id == reorder_scroll_id('queue')
	assert reorder_test_keys(body.children) == ['a', 'b', 'c']
}

fn test_reorder_handle_mode_puts_the_press_on_a_grip() {
	config := ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		handle: true
	}
	root := reorder_container(config) or { panic(err) }
	rows := reorder_test_rows(root)
	assert reorder_test_keys(rows) == ['a', 'b', 'c']
	assert !rows[0].draggable
	grip := rows[0].children[0]
	assert grip.draggable
	assert grip.id == reorder_item_action('queue', 'a')
	// The item keeps its own frame, to the right of the grip.
	body := rows[0].children[1]
	assert body.frame.x > 0
	assert body.frame.width < rows[0].frame.width
	down := reorder_update(config, reorder_test_pointer('down', 'a', 10, 20)) or {
		panic('grip press ignored')
	}
	assert down.state.drag.item == 'a'
}

fn test_reorder_container_builds_empty_queues_and_ignores_stale_drags() {
	empty := reorder_container(reorder_test_config([])) or { panic(err) }
	assert empty.children[0].children.len == 0
	stale := ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		state: ReorderState{
			drag: ReorderDrag{
				item:   'gone'
				active: true
			}
		}
	}
	root := reorder_container(stale) or { panic(err) }
	assert reorder_test_keys(reorder_test_rows(root)) == ['a', 'b', 'c']
	if _ := reorder_container(ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		id: ''
	}) {
		assert false, 'container without an id accepted'
	}
}

// ── Reveal ──────────────────────────────────────────────────────────

fn test_reorder_reveal_offset_scrolls_as_little_as_needed() {
	items := [
		reorder_test_sized('a', 120, 100),
		reorder_test_sized('b', 120, 100),
		reorder_test_sized('c', 120, 100),
	]
	config := ReorderConfig{
		id:    'queue'
		frame: rect(0, 0, 240, 150)
		items: items
	}
	bottom := reorder_reveal_offset(config, 'c') or { panic('no offset') }
	assert bottom == 150
	kept := reorder_reveal_offset(ReorderConfig{ ...config, offset: 150 }, 'c') or {
		panic('no offset')
	}
	assert kept == 150
	top := reorder_reveal_offset(ReorderConfig{ ...config, offset: 150 }, 'a') or {
		panic('no offset')
	}
	assert top == 0
	assert reorder_reveal_offset(config, 'zz') == none
	assert reorder_reveal_offset(ReorderConfig{ ...config, frame: rect(0, 0, 240, 400) }, 'c') == none
}

// ── Keys ────────────────────────────────────────────────────────────

fn test_reorder_keys_move_the_cursor_item_along_the_axis() {
	config := ReorderConfig{
		...reorder_test_config(reorder_test_queue())
		state: ReorderState{
			active: 'b'
		}
	}
	down := reorder_key(config, KeyEvent{ code: .down, alt: true }) or { panic('move ignored') }
	assert down.moved
	assert down.from == 1 && down.to == 2
	assert down.reveal
	assert down.state.active == 'b'
	// Without Alt the arrows are left to the rest of the window.
	assert reorder_key(config, KeyEvent{ code: .down }) == none
	assert reorder_key(config, KeyEvent{ code: .down, alt: true, shift: true }) == none
	up := reorder_key(config, KeyEvent{ code: .up, alt: true }) or { panic('move ignored') }
	assert up.from == 1 && up.to == 0
	home := reorder_key(config, KeyEvent{ code: .home, alt: true }) or { panic('move ignored') }
	assert home.to == 0
	end := reorder_key(config, KeyEvent{ code: .end, alt: true }) or { panic('move ignored') }
	assert end.to == 2
	// The arrows of the other axis do nothing on a vertical queue.
	assert reorder_key(config, KeyEvent{ code: .right, alt: true }) == none
	// The last item cannot go further down, and nothing moves without a cursor.
	last := ReorderConfig{
		...config
		state: ReorderState{
			active: 'c'
		}
	}
	assert reorder_key(last, KeyEvent{ code: .down, alt: true }) == none
	assert reorder_key(reorder_test_config(reorder_test_queue()), KeyEvent{ code: .down, alt: true }) == none
}

fn test_reorder_keys_stop_at_disabled_items_and_work_on_a_horizontal_axis() {
	items := [
		reorder_test_sized('a', 120, 40),
		Element{
			...reorder_test_sized('b', 120, 60)
			enabled: false
		},
		reorder_test_sized('c', 120, 20),
	]
	beside_pinned := ReorderConfig{
		...reorder_test_config(items)
		state: ReorderState{
			active: 'c'
		}
	}
	assert reorder_key(beside_pinned, KeyEvent{ code: .up, alt: true }) == none
	pinned := ReorderConfig{
		...reorder_test_config(items)
		state: ReorderState{
			active: 'b'
		}
	}
	assert reorder_key(pinned, KeyEvent{ code: .down, alt: true }) == none
	strip := ReorderConfig{
		id:    'queue'
		frame: rect(0, 0, 300, 60)
		axis:  .horizontal
		items: [
			reorder_test_sized('a', 30, 20),
			reorder_test_sized('b', 50, 20),
			reorder_test_sized('c', 40, 20),
		]
		gap:   8
		state: ReorderState{
			active: 'a'
		}
	}
	right := reorder_key(strip, KeyEvent{ code: .right, alt: true }) or { panic('move ignored') }
	assert right.from == 0 && right.to == 1
	assert reorder_key(strip, KeyEvent{ code: .down, alt: true }) == none
}

// ── Queues ──────────────────────────────────────────────────────────

fn test_reorder_queue_round_trip_keeps_the_applications_order() {
	mut queue := [
		reorder_test_sized('a', 120, 40),
		reorder_test_sized('b', 120, 40),
		reorder_test_sized('c', 120, 40),
		reorder_test_sized('d', 120, 40),
	]
	mut state := ReorderState{}
	// Drag d up past a, releasing over the top of the queue.
	dragged := reorder_test_drop(ReorderConfig{
		...reorder_test_config(queue)
		state: state
	}, 'd', 20, 170, -100)
	assert dragged.moved
	assert dragged.from == 3 && dragged.to == 1
	queue = reorder_move(queue, dragged.from, dragged.to)
	state = dragged.state
	assert reorder_test_keys(queue) == ['a', 'd', 'b', 'c']
	// Then move d down one place from the keyboard.
	nudged := reorder_key(ReorderConfig{
		...reorder_test_config(queue)
		state: state
	}, KeyEvent{ code: .down, alt: true }) or { panic('key ignored') }
	queue = reorder_move(queue, nudged.from, nudged.to)
	state = nudged.state
	assert reorder_test_keys(queue) == ['a', 'b', 'd', 'c']
	assert state.active == 'd'
	// The queue fits its frame, so there is nothing to scroll to.
	assert reorder_reveal_offset(ReorderConfig{
		...reorder_test_config(queue)
		state: state
	}, 'd') == none
}
