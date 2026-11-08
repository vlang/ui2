module ui2

import math

// ── Virtual list ────────────────────────────────────────────────────

fn lists_sized(sizes []f64) VirtualListLayout {
	return virtual_list_sized(sizes, 0) or { panic(err) }
}

fn test_virtual_list_fixed_layout_positions() {
	layout := virtual_list_fixed(10, 20, 4) or { panic(err) }
	assert layout.count == 10
	assert layout.total() == 10 * 20 + 9 * 4
	assert layout.item_start(0) == 0
	assert layout.item_start(3) == 72
	assert layout.item_size(3) == 20
	assert layout.item_end(3) == 92
	assert layout.item_size(10) == 0
	// A position in the gap after an item belongs to the next one.
	assert layout.index_at(21) == 1
	assert layout.index_at(19.5) == 0
	assert layout.index_at(1e9) == 9
	padded := layout.padded(8) or { panic(err) }
	assert padded.total() == layout.total() + 16
	assert padded.item_start(0) == 8
	assert padded.item_start(1) == 32
	empty := VirtualListLayout{}
	assert empty.total() == 0
	assert empty.index_at(10) == -1
}

fn test_virtual_list_sized_layout_positions() {
	layout := virtual_list_sized([10.0, 30, 5, 50], 2) or { panic(err) }
	assert layout.total() == 95 + 6
	assert layout.item_start(1) == 12
	assert layout.item_size(1) == 30
	assert layout.item_start(3) == 51
	assert layout.item_end(3) == 101
	assert layout.index_at(46.5) == 2
	assert layout.index_at(50) == 3
}

fn test_virtual_list_layouts_reject_invalid_sizes() {
	if _ := virtual_list_fixed(-1, 20, 0) {
		assert false, 'negative count accepted'
	}
	if _ := virtual_list_fixed(10, 0, 0) {
		assert false, 'zero item size accepted'
	}
	if _ := virtual_list_fixed(10, 20, math.nan()) {
		assert false, 'NaN gap accepted'
	}
	if _ := virtual_list_sized([10.0, -1], 0) {
		assert false, 'negative size accepted'
	}
	if _ := virtual_list_sized([10.0, math.inf(1)], 0) {
		assert false, 'infinite size accepted'
	}
	layout := virtual_list_fixed(3, 10, 0) or { panic(err) }
	if _ := layout.padded(-2) {
		assert false, 'negative padding accepted'
	}
}

// Cases in the spirit of GPUI Kit's visible_range tests, with no overscan.
fn test_virtual_list_range_finds_the_items_crossing_the_viewport() {
	twenty := lists_sized([]f64{len: 10, init: 20})
	top := twenty.range(60, 0, 0)
	assert top.visible_start == 0 && top.visible_end == 3
	assert top.start == 0 && top.end == 3
	middle := twenty.range(60, 50, 0)
	assert middle.visible_start == 2 && middle.visible_end == 6
	uneven := lists_sized([10.0, 30, 5, 50])
	span := uneven.range(32, 12, 0)
	assert span.visible_start == 1 && span.visible_end == 3
	// The whole list fits.
	all := twenty.range(500, 0, 0)
	assert all.visible_start == 0 && all.visible_end == 10
}

fn test_virtual_list_range_adds_overscan_and_reports_spacers() {
	layout := virtual_list_fixed(1000, 10, 0) or { panic(err) }
	span := layout.range(100, 5000, 3)
	assert span.visible_start == 500 && span.visible_end == 510
	assert span.start == 497 && span.end == 513
	assert span.len() == 16
	assert span.before == 4970
	assert span.after == 10000 - 5130
	assert span.total == 10000
	first := layout.range(100, 0, 3)
	assert first.start == 0 && first.end == 13
	assert first.before == 0
}

fn test_virtual_list_range_clamps_stale_and_invalid_offsets() {
	layout := virtual_list_fixed(100, 10, 0) or { panic(err) }
	// An offset past the end, from before the list shrank, shows its end.
	stale := layout.range(100, 1e6, 0)
	assert stale.visible_start == 90 && stale.visible_end == 100
	assert stale.after == 0
	for offset in [-50.0, math.nan(), math.inf(-1)] {
		span := layout.range(100, offset, 0)
		assert span.visible_start == 0 && span.visible_end == 10
	}
	empty := VirtualListLayout{}.range(100, 0, 5)
	assert empty.len() == 0
	none_shown := layout.range(0, 0, 2)
	assert none_shown.visible_end == none_shown.visible_start
	assert none_shown.len() == 2
	assert stale.near_end(100, 5)
	assert !layout.range(100, 0, 0).near_end(100, 5)
	assert !VirtualListRange{}.near_end(0, 5)
}

fn test_virtual_list_scroll_offset_for_aligns_items() {
	layout := virtual_list_fixed(100, 20, 0) or { panic(err) }
	assert layout.scroll_offset_for(10, 100, 0, .start) == 200
	assert layout.scroll_offset_for(10, 100, 0, .end) == 120
	assert layout.scroll_offset_for(10, 100, 0, .center) == 160
	// Nearest leaves an item in view alone and scrolls as little as it can.
	assert layout.scroll_offset_for(10, 100, 150, .nearest) == 150
	assert layout.scroll_offset_for(10, 100, 300, .nearest) == 200
	assert layout.scroll_offset_for(10, 100, 0, .nearest) == 120
	// Clamped to the content.
	assert layout.scroll_offset_for(99, 100, 0, .start) == 1900
	assert layout.scroll_offset_for(-5, 100, 400, .start) == 0
	// An item taller than the viewport is shown from its start.
	tall := lists_sized([20.0, 300, 20])
	assert tall.scroll_offset_for(1, 100, 0, .nearest) == 20
	// The first and last items take the padding along.
	padded := layout.padded(4) or { panic(err) }
	assert padded.scroll_offset_for(0, 100, 50, .nearest) == 0
	assert padded.scroll_offset_for(99, 100, 0, .nearest) == padded.total() - 100
	assert VirtualListLayout{}.scroll_offset_for(3, 100, 0, .start) == 0
}

fn test_virtual_list_index_after_key() {
	layout := virtual_list_fixed(100, 20, 0) or { panic(err) }
	assert layout.index_after_key(5, 100, KeyEvent{ code: .down })? == 6
	assert layout.index_after_key(5, 100, KeyEvent{ code: .up })? == 4
	assert layout.index_after_key(-1, 100, KeyEvent{ code: .down })? == 0
	assert layout.index_after_key(-1, 100, KeyEvent{ code: .up })? == 99
	assert layout.index_after_key(5, 100, KeyEvent{ code: .home })? == 0
	assert layout.index_after_key(5, 100, KeyEvent{ code: .end })? == 99
	assert layout.index_after_key(5, 100, KeyEvent{ code: .page_down })? == 10
	assert layout.index_after_key(10, 100, KeyEvent{ code: .page_up })? == 5
	assert layout.index_after_key(98, 100, KeyEvent{ code: .page_down })? == 99
	// No wrapping, no modifiers, no other keys.
	if _ := layout.index_after_key(99, 100, KeyEvent{ code: .down }) {
		assert false, 'moved past the end'
	}
	if _ := layout.index_after_key(0, 100, KeyEvent{ code: .up }) {
		assert false, 'moved before the start'
	}
	if _ := layout.index_after_key(5, 100, KeyEvent{ code: .down, shift: true }) {
		assert false, 'took a modified key'
	}
	if _ := layout.index_after_key(5, 100, KeyEvent{ code: .enter }) {
		assert false, 'took Enter'
	}
	// A page of items taller than the viewport still moves.
	tall := lists_sized([300.0, 300, 300])
	assert tall.index_after_key(0, 100, KeyEvent{ code: .page_down })? == 1
	assert tall.index_after_key(2, 100, KeyEvent{ code: .page_up })? == 1
}

fn test_virtual_list_builds_only_the_items_in_range() {
	layout := virtual_list_fixed(10_000, 30, 0) or { panic(err) }
	el := virtual_list(
		id:       'rows'
		frame:    rect(0, 0, 200, 300)
		layout:   layout
		offset:   150_000
		overscan: 2
		item:     fn (index int, frame Rect) Element {
			return label('', 'Row ${index}', frame, TextStyle{})
		}
	) or { panic(err) }
	assert el.kind == .scroll
	assert el.id == 'rows'
	assert el.accessibility_role == 'list'
	// The spacer gives the full extent; 10 visible rows plus 2 on each side.
	assert el.children[0].key == virtual_list_extent_key
	assert el.children[0].frame.height == 300_000
	assert el.children.len == 1 + 14
	assert el.children[1].key == 'item:4998'
	assert el.children[1].text == 'Row 4998'
	assert el.children[1].frame == rect(0, 4998 * 30, 200, 30)
	assert el.children[14].key == 'item:5011'
}

fn test_virtual_list_horizontal_and_validation() {
	layout := virtual_list_sized([50.0, 80, 50], 10) or { panic(err) }
	el := virtual_list(
		id:          'strip'
		frame:       rect(0, 0, 100, 40)
		layout:      layout
		orientation: .horizontal
		item:        fn (index int, frame Rect) Element {
			return Element{
				...view('', frame, BoxStyle{}, []Element{})
				key: 'card:${index}'
			}
		}
	) or { panic(err) }
	assert el.scroll_mode == .horizontal_only
	assert el.children[0].frame == rect(0, 0, 200, 0)
	assert el.children[2].frame == rect(60, 0, 80, 40)
	// An item's own key is kept.
	assert el.children[1].key == 'card:0'
	if _ := virtual_list(id: 'x', frame: rect(0, 0, 10, 10)) {
		assert false, 'virtual list without an item builder accepted'
	}
	if _ := virtual_list(
		frame: rect(0, 0, 10, 10)
		item:  fn (index int, frame Rect) Element {
			return view('', frame, BoxStyle{}, []Element{})
		}
	) {
		assert false, 'virtual list without an id accepted'
	}
}

// ── List ────────────────────────────────────────────────────────────

fn lists_sections() []ListSection {
	return [
		ListSection{
			title:  'Pinned'
			icon:   'star'
			footer: 'Two pinned'
			items:  [
				ListItem{
					id:          'readme'
					title:       'README'
					description: 'Edited today'
					icon:        'doc'
					actions:     [
						ListItemAction{
							id:    'share'
							icon:  'square.and.arrow.up'
							label: 'Share'
						},
						ListItemAction{
							id:      'pin'
							icon:    'star'
							label:   'Unpin'
							enabled: false
						},
					]
				},
				list_item('plan', 'Plan'),
			]
		},
		ListSection{
			title: 'Empty'
		},
		ListSection{
			title: 'Files'
			items: [
				list_item('a', 'Alpha'),
				list_separator(),
				ListItem{
					id:      'locked'
					title:   'Locked'
					enabled: false
				},
				list_item('b', 'Beta'),
				list_item('c', 'Gamma'),
			]
		},
	]
}

fn lists_config(state ListState, selection ListSelectionMode) ListConfig {
	return ListConfig{
		id:        'files'
		frame:     rect(0, 0, 300, 400)
		sections:  lists_sections()
		state:     state
		selection: selection
	}
}

fn lists_find(el Element, key string) ?Element {
	for child in el.children {
		if child.key == key {
			return child
		}
		if found := lists_find(child, key) {
			return found
		}
	}
	return none
}

fn test_list_draws_sections_rows_and_hides_empty_sections() {
	el := list(lists_config(ListState{}, .single)) or { panic(err) }
	assert el.id == 'files'
	assert el.accessibility_role == 'list'
	// 2 headers, 1 footer, 6 rows (a separator among them) fit in 400 points.
	rows := el.children[0]
	assert rows.key == 'rows'
	assert rows.kind == .view
	keys := rows.children.map(it.key)
	assert keys == [virtual_list_extent_key, 'header:0', 'row:readme', 'row:plan', 'footer:0',
		'header:2', 'row:a', 'separator:2:1', 'row:locked', 'row:b', 'row:c']
	m := list_metrics(.medium)
	readme := rows.children[2]
	assert readme.frame == rect(m.padding, m.padding + m.header, 298 - 2 * m.padding, m.row_two)
	assert rows.children[3].frame.height == m.row
	assert rows.children[0].frame.height == 2 * m.padding + 2 * m.header + m.footer + m.row_two +
		5 * m.row + m.separator
	assert readme.id == list_row_action('files', 'readme')
	assert readme.accessibility_role == 'listitem'
	assert readme.accessibility_label == 'README, Edited today'
	assert readme.hoverable
	assert readme.button_behavior
	locked := rows.children[8]
	assert !locked.enabled
	assert !locked.hoverable
	assert lists_find(el, 'header:1') == none
}

fn test_list_scrolls_long_content_and_virtualizes_on_request() {
	mut items := []ListItem{}
	for i in 0 .. 200 {
		items << list_item('r${i}', 'Row ${i}')
	}
	config := ListConfig{
		id:    'long'
		frame: rect(0, 0, 200, 182)
		items: items
	}
	full := list(config) or { panic(err) }
	scroller := full.children[0]
	assert scroller.kind == .scroll
	assert scroller.id == list_scroll_id('long')
	assert scroller.children.len == 201
	m := list_metrics(.medium)
	virtual := list(ListConfig{
		...config
		offset:     m.padding + 100 * m.row
		virtualize: true
		overscan:   1
	}) or { panic(err) }
	rows := virtual.children[0].children
	// 180 points show 5 rows of 36; one more on each side.
	assert rows.len == 1 + 7
	assert rows[1].key == 'row:r99'
	assert rows[7].key == 'row:r105'
	assert rows[0].frame.height == 2 * m.padding + 200 * m.row
	range := list_visible_range(ListConfig{
		...config
		offset:     m.padding + 100 * m.row
		virtualize: true
		overscan:   0
	}) or { panic(err) }
	assert range.visible_start == 100 && range.visible_end == 105
}

fn test_list_row_looks_follow_the_state() {
	theme := component_theme(false)
	el := list(ListConfig{
		...lists_config(ListState{
			selected: ['plan']
			active:   'a'
			hovered:  'b'
		}, .multiple)
		check_icon: true
	}) or { panic(err) }
	plan := lists_find(el, 'row:plan') or { panic('no plan row') }
	assert plan.box.bg == list_selected_fill(theme)
	assert plan.box.border_left == 0
	assert plan.accessibility_value == 'selected'
	assert plan.children.any(it.image_path == 'symbol:checkmark')
	active := lists_find(el, 'row:a') or { panic('no active row') }
	assert active.box.bg == theme.muted
	assert active.box.border_left == 1
	assert active.box.border_color == theme.primary
	assert !active.children.any(it.image_path == 'symbol:checkmark')
	hovered := lists_find(el, 'row:b') or { panic('no hovered row') }
	assert hovered.box.bg == theme.muted
	assert hovered.box.border_left == 0
	plain := lists_find(el, 'row:c') or { panic('no plain row') }
	assert plain.box.transparent
	readme := lists_find(el, 'row:readme') or { panic('no readme row') }
	share := lists_find(readme, 'action:share') or { panic('no share action') }
	assert share.id == list_item_action_action('files', 'readme', 'share')
	assert share.enabled
	assert share.accessibility_label == 'Share'
	unpin := lists_find(readme, 'action:pin') or { panic('no pin action') }
	assert !unpin.enabled
	// Selection mode none shows no selection.
	unselectable := list(lists_config(ListState{
		selected: ['plan']
	}, .none)) or { panic(err) }
	none_plan := lists_find(unselectable, 'row:plan') or { panic('no plan row') }
	assert none_plan.accessibility_value == ''
}

fn test_list_empty_and_loading_states() {
	empty := list(
		id:                'inbox'
		frame:             rect(0, 0, 240, 200)
		empty_title:       'No messages'
		empty_description: 'New ones show up here.'
		empty_icon:        'envelope'
	) or { panic(err) }
	state_view := empty.children[0]
	assert state_view.key == 'empty'
	assert state_view.accessibility_role == 'status'
	assert state_view.children[0].image_path == 'symbol:envelope'
	assert state_view.children[1].text == 'No messages'
	assert state_view.children[2].text == 'New ones show up here.'
	loading := list(id: 'feed', frame: rect(0, 0, 240, 300), loading: true) or { panic(err) }
	assert loading.accessibility_value == 'loading'
	placeholder := lists_find(loading, 'loading') or { panic('no loading rows') }
	assert placeholder.id == component_part_id('feed', 'loading')
	assert lists_find(loading, 'empty') == none
	// Loading more keeps the rows and adds the placeholders after them.
	more := list(
		id:      'feed'
		frame:   rect(0, 0, 240, 600)
		items:   [list_item('one', 'One')]
		loading: true
	) or { panic(err) }
	rows := more.children[0].children
	assert rows[1].key == 'row:one'
	assert rows[2].key == 'loading'
	assert rows[2].frame.y == rows[1].frame.y + rows[1].frame.height
}

fn test_list_rejects_invalid_models() {
	if _ := list(id: 'x', items: [list_item('', 'No id')]) {
		assert false, 'row without an id accepted'
	}
	if _ := list(id: 'x', items: [list_item('a', 'A'), list_item('a', 'B')]) {
		assert false, 'duplicate row ids accepted'
	}
	if _ := list(
		id:    'x'
		items: [ListItem{
			id:    'a'
			title: 'A'
			icon:  'no.such.symbol'
		}]
	) {
		assert false, 'unknown icon accepted'
	}
	if _ := list(
		id:    'x'
		items: [ListItem{
			id:      'a'
			title:   'A'
			actions: [ListItemAction{
				id:   'go'
				icon: 'trash'
			}]
		}]
	) {
		assert false, 'action without a label accepted'
	}
	if _ := list(id: 'x', items: [list_item('a', 'A')], sections: lists_sections()) {
		assert false, 'items and sections together accepted'
	}
	if _ := list(items: [list_item('a', 'A')]) {
		assert false, 'list without an id accepted'
	}
	// Separators need no id, and may repeat.
	list(id: 'x', items: [list_separator(), list_separator()]) or { panic(err) }
}

fn test_list_press_decodes_rows_and_actions() {
	row := list_press('files', list_row_action('files', 'a:b'))?
	assert row.item_id == 'a:b'
	assert row.action == ''
	action := list_press('files', list_item_action_action('files', 'readme', 'share'))?
	assert action.item_id == 'readme'
	assert action.action == 'share'
	for forged in [list_row_action('other', 'a'), 'files:component:row:', 'files:component:row:6',
		'files:component:row:zz', 'files:component:row:6A', 'files:component:action:61',
		'files:component:action:61:', 'files:component:scroll'] {
		if _ := list_press('files', forged) {
			assert false, 'accepted ${forged}'
		}
	}
}

fn test_list_update_selects_with_modifiers() {
	plain := ListModifiers{}
	toggling := ListModifiers{
		toggle: true
	}
	extend := ListModifiers{
		extend: true
	}
	single := lists_config(ListState{}, .single)
	step := list_update(single, list_row_action('files', 'plan'), plain)?
	assert step.state.selected == ['plan']
	assert step.state.active == 'plan'
	assert step.confirmed
	assert step.item.id == 'plan'
	// Toggle deselects the selected row of a single-selection list.
	off := list_update(lists_config(step.state, .single), list_row_action('files', 'plan'),
		toggling)?
	assert off.state.selected.len == 0
	assert !off.confirmed
	multiple := lists_config(ListState{
		selected: ['plan']
		active:   'plan'
		anchor:   'plan'
	}, .multiple)
	added := list_update(multiple, list_row_action('files', 'b'), toggling)?
	assert added.state.selected == ['plan', 'b']
	assert added.state.anchor == 'b'
	removed := list_update(lists_config(added.state, .multiple), list_row_action('files',
		'plan'), toggling)?
	assert removed.state.selected == ['b']
	// A range runs from the anchor over the selectable rows only.
	ranged := list_update(multiple, list_row_action('files', 'b'), extend)?
	assert ranged.state.selected == ['plan', 'a', 'b']
	assert ranged.state.anchor == 'plan'
	assert ranged.state.active == 'b'
	assert !ranged.confirmed
	backwards := list_update(lists_config(ranged.state, .multiple), list_row_action('files',
		'readme'), extend)?
	assert backwards.state.selected == ['readme', 'plan']
	joined := list_update(lists_config(ListState{
		selected: ['c']
		anchor:   'readme'
	}, .multiple), list_row_action('files', 'plan'), ListModifiers{
		toggle: true
		extend: true
	})?
	assert joined.state.selected == ['c', 'readme', 'plan']
	replaced := list_update(multiple, list_row_action('files', 'c'), plain)?
	assert replaced.state.selected == ['c']
	assert replaced.confirmed
	// Selection mode none confirms and moves only the cursor.
	opened := list_update(lists_config(ListState{}, .none), list_row_action('files', 'a'),
		plain)?
	assert opened.confirmed
	assert opened.state.selected.len == 0
	assert opened.state.active == 'a'
	via := list_selection_after_click(multiple, 'c', extend)?
	assert via.selected == ['plan', 'a', 'b', 'c']
}

fn test_list_update_rejects_what_it_did_not_show() {
	config := lists_config(ListState{}, .multiple)
	for event in [list_row_action('files', 'locked'), list_row_action('files', 'ghost'),
		list_row_action('files', ''), list_row_action('other', 'a'), 'files',
		list_item_action_action('files', 'readme', 'pin'), list_item_action_action('files',
			'readme', 'ghost'), list_item_action_action('files', 'plan', 'share')] {
		if _ := list_update(config, event, ListModifiers{}) {
			assert false, 'accepted ${event}'
		}
	}
	if _ := list_selection_after_click(config, 'locked', ListModifiers{}) {
		assert false, 'disabled row selected'
	}
	action := list_update(config, list_item_action_action('files', 'readme', 'share'),
		ListModifiers{})?
	assert action.action == 'share'
	assert action.item.id == 'readme'
	assert !action.confirmed
	assert action.state == config.state
}

fn test_list_update_tracks_hover() {
	config := lists_config(ListState{}, .single)
	row := list_row_action('files', 'a')
	entered := list_update(config, 'pointer:enter:${row}:10:20', ListModifiers{})?
	assert entered.state.hovered == 'a'
	hovering := lists_config(entered.state, .single)
	if _ := list_update(hovering, 'pointer:enter:${row}:12:20', ListModifiers{}) {
		assert false, 'entering again changed something'
	}
	other := list_row_action('files', 'b')
	if _ := list_update(hovering, 'pointer:leave:${other}:12:20', ListModifiers{}) {
		assert false, 'leaving another row cleared the hover'
	}
	left := list_update(hovering, 'pointer:leave:${row}:12:20', ListModifiers{})?
	assert left.state.hovered == ''
	for event in ['pointer:down:${row}:1:1', 'pointer:enter:${list_row_action('files', 'locked')}:1:1',
		'pointer:enter:${list_item_action_action('files', 'readme', 'share')}:1:1'] {
		if _ := list_update(config, event, ListModifiers{}) {
			assert false, 'accepted ${event}'
		}
	}
}

fn test_list_key_moves_wraps_and_skips_unselectable_rows() {
	order := ['readme', 'plan', 'a', 'b', 'c']
	mut walked := ListState{}
	for expected in order {
		step := list_key(lists_config(walked, .single), KeyEvent{ code: .down })?
		assert step.state.active == expected
		assert step.state.selected == [expected]
		assert step.reveal
		walked = step.state
	}
	wrapped := list_key(lists_config(walked, .single), KeyEvent{ code: .down })?
	assert wrapped.state.active == 'readme'
	back := list_key(lists_config(wrapped.state, .single), KeyEvent{ code: .up })?
	assert back.state.active == 'c'
	last := list_key(lists_config(ListState{}, .single), KeyEvent{ code: .up })?
	assert last.state.active == 'c'
	home := list_key(lists_config(walked, .single), KeyEvent{ code: .home })?
	assert home.state.active == 'readme'
	if _ := list_key(lists_config(home.state, .single), KeyEvent{ code: .home }) {
		assert false, 'Home on the first row changed something'
	}
	end := list_key(lists_config(home.state, .single), KeyEvent{ code: .end })?
	assert end.state.active == 'c'
	// Without a selection mode only the cursor moves.
	cursor := list_key(lists_config(ListState{
		selected: ['b']
	}, .none), KeyEvent{ code: .down })?
	assert cursor.state.active == 'readme'
	assert cursor.state.selected == ['b']
	for event in [KeyEvent{
		code: .down
		alt:  true
	}, KeyEvent{
		code: .down
		cmd:  true
	}, KeyEvent{
		code: .tab
	}] {
		if _ := list_key(lists_config(walked, .single), event) {
			assert false, 'took ${event}'
		}
	}
}

fn test_list_key_pages_by_the_viewport() {
	mut items := []ListItem{}
	for i in 0 .. 50 {
		items << list_item('r${i}', 'Row ${i}')
	}
	// 182 - 2 points of border leave 180: five rows of 36.
	config := ListConfig{
		id:    'long'
		frame: rect(0, 0, 200, 182)
		items: items
		state: ListState{
			active: 'r2'
		}
	}
	down := list_key(config, KeyEvent{ code: .page_down })?
	assert down.state.active == 'r7'
	up := list_key(ListConfig{
		...config
		state: down.state
	}, KeyEvent{ code: .page_up })?
	assert up.state.active == 'r2'
	end := list_key(ListConfig{
		...config
		state: ListState{
			active: 'r48'
		}
	}, KeyEvent{ code: .page_down })?
	assert end.state.active == 'r49'
	top := list_key(ListConfig{
		...config
		state: ListState{
			active: 'r1'
		}
	}, KeyEvent{ code: .page_up })?
	assert top.state.active == 'r0'
	m := list_metrics(.medium)
	offset := list_reveal_offset(ListConfig{
		...config
		state: down.state
	}, 'r20')?
	assert offset == m.padding + 21 * m.row - 180
	// A row already in view needs no scrolling.
	assert list_reveal_offset(ListConfig{
		...config
		offset: offset
	}, 'r18')? == offset
	if _ := list_reveal_offset(config, 'ghost') {
		assert false, 'revealed a row the list does not show'
	}
}

fn test_list_key_extends_toggles_selects_all_and_confirms() {
	start := ListState{
		selected: ['plan']
		active:   'plan'
		anchor:   'plan'
	}
	extended := list_key(lists_config(start, .multiple), KeyEvent{
		code:  .down
		shift: true
	})?
	assert extended.state.selected == ['plan', 'a']
	assert extended.state.anchor == 'plan'
	further := list_key(lists_config(extended.state, .multiple), KeyEvent{
		code:  .down
		shift: true
	})?
	assert further.state.selected == ['plan', 'a', 'b']
	// Shift in single mode just moves.
	single := list_key(lists_config(start, .single), KeyEvent{
		code:  .down
		shift: true
	})?
	assert single.state.selected == ['a']
	toggled := list_key(lists_config(further.state, .multiple), KeyEvent{ code: .space })?
	assert toggled.state.selected == ['plan', 'a']
	retoggled := list_key(lists_config(toggled.state, .multiple), KeyEvent{ code: .space })?
	assert retoggled.state.selected == ['plan', 'a', 'b']
	all := list_key(lists_config(start, .multiple), KeyEvent{
		code: .a
		cmd:  true
	})?
	assert all.state.selected == ['readme', 'plan', 'a', 'b', 'c']
	if _ := list_key(lists_config(all.state, .multiple), KeyEvent{
		code: .a
		ctrl: true
	}) {
		assert false, 'selecting all twice changed something'
	}
	if _ := list_key(lists_config(start, .single), KeyEvent{
		code: .a
		cmd:  true
	}) {
		assert false, 'select all in single mode'
	}
	confirmed := list_key(lists_config(ListState{
		active: 'b'
	}, .single), KeyEvent{ code: .enter })?
	assert confirmed.confirmed
	assert !confirmed.secondary
	assert confirmed.item.id == 'b'
	assert confirmed.state.selected == ['b']
	secondary := list_key(lists_config(ListState{
		active: 'b'
	}, .single), KeyEvent{
		code: .kp_enter
		cmd:  true
	})?
	assert secondary.secondary
	if _ := list_key(lists_config(ListState{}, .single), KeyEvent{ code: .enter }) {
		assert false, 'confirmed without an active row'
	}
	cancelled := list_key(lists_config(start, .single), KeyEvent{ code: .escape })?
	assert cancelled.cancelled
	assert cancelled.state.active == ''
	assert cancelled.state.selected == ['plan']
}

fn test_list_modifiers_and_list_row() {
	mods := list_modifiers(KeyEvent{
		code:  .left_shift
		shift: true
		ctrl:  true
	})
	assert mods.toggle && mods.extend
	assert list_row_height(list_item('a', 'A'), .medium) == list_metrics(.medium).row
	assert list_row_height(ListItem{
		id:          'a'
		description: 'More'
	}, .medium) == list_metrics(.medium).row_two
	assert list_row_height(list_separator(), .large) == list_metrics(.large).separator
	row := list_row(
		list_id:  'people'
		item:     ListItem{
			id:     'p7'
			title:  'Ada Lovelace'
			avatar: 'Ada Lovelace'
			badge:  '3'
			menu:   [MenuEntry{
				id:    'remove:p7'
				title: 'Remove'
			}]
		}
		frame:    rect(0, 40, 300, 36)
		selected: true
	) or { panic(err) }
	assert row.key == 'row:p7'
	assert row.id == list_row_action('people', 'p7')
	assert row.menu.len == 1
	assert row.children[0].accessibility_role == 'img'
	assert row.children.any(it.accessibility_role == 'status')
	press := list_press('people', row.id)?
	assert press.item_id == 'p7'
	if _ := list_row(list_id: 'people', item: list_item('', 'x'), frame: rect(0, 0, 10, 10)) {
		assert false, 'row without an id accepted'
	}
}

// ── Matching and filtering ──────────────────────────────────────────

fn test_list_match_substring() {
	found := list_match('APP', 'Pineapple', .substring)?
	assert found.ranges == [ListMatchRange{4, 7}]
	prefix := list_match('pine', 'Pineapple', .substring)?
	word := list_match('app', 'Big Apple', .substring)?
	middle := list_match('app', 'Pineapple', .substring)?
	assert prefix.score > word.score
	assert word.score > middle.score
	assert list_match('  ', 'anything', .substring)?.ranges.len == 0
	assert list_match('écl', 'Éclair', .substring)?.ranges == [ListMatchRange{0, 3}]
	if _ := list_match('ppa', 'Apple', .substring) {
		assert false, 'substring matched out of order'
	}
	if _ := list_match('gtc', 'GPUI Toolkit Core', .substring) {
		assert false, 'substring matched scattered letters'
	}
}

fn test_list_match_fuzzy() {
	scattered := list_match('gtc', 'GPUI Toolkit Core', .fuzzy)?
	assert scattered.ranges == [ListMatchRange{0, 1}, ListMatchRange{5, 6}, ListMatchRange{13, 14}]
	runs := list_match('tool kit', 'GPUI Toolkit', .fuzzy)?
	assert runs.ranges == [ListMatchRange{5, 12}]
	// A run beats the same letters scattered.
	whole := list_match('core', 'Core', .fuzzy)?
	spread := list_match('core', 'Cold ore', .fuzzy)?
	assert whole.score > spread.score
	assert spread.ranges == [ListMatchRange{0, 2}, ListMatchRange{6, 8}]
	if _ := list_match('ba', 'Abc', .fuzzy) {
		assert false, 'fuzzy matched out of order'
	}
	if _ := list_match('xyz', 'Apple', .fuzzy) {
		assert false, 'fuzzy matched missing letters'
	}
}

fn test_list_filter_keeps_matching_rows_and_sections() {
	sections := [
		ListSection{
			title: 'Fruits'
			items: [list_item('apple', 'Apple'), list_separator(), list_item('banana', 'Banana')]
		},
		ListSection{
			title: 'Nuts'
			items: [
				list_item('almond', 'Almond'),
				ListItem{
					id:          'pecan'
					title:       'Pecan'
					description: 'Banana-shaped'
				},
			]
		},
	]
	assert list_filter(sections, '  ', .substring) == sections
	filtered := list_filter(sections, 'ban', .substring)
	assert filtered.len == 2
	assert filtered[0].items.map(it.id) == ['banana']
	assert filtered[1].items.map(it.id) == ['pecan']
	// A section whose title contains the query keeps all its rows, separators
	// excepted.
	fruits := list_filter(sections, 'fruit', .substring)
	assert fruits.len == 1
	assert fruits[0].items.map(it.id) == ['apple', 'banana']
	// Titles match as substrings even in fuzzy mode.
	assert list_filter(sections, 'fs', .fuzzy).len == 0
	assert list_filter(sections, 'xyz', .fuzzy).len == 0
	assert list_item_matches(list_item('a', 'Apple'), 'APL', .fuzzy)
	assert !list_item_matches(list_separator(), '', .fuzzy)
}

// ── Searchable list ─────────────────────────────────────────────────

fn lists_pantry(query string, state ListState, selection ListSelectionMode) SearchableListConfig {
	return SearchableListConfig{
		id:        'pantry'
		frame:     rect(0, 0, 300, 400)
		query:     query
		sections:  [
			ListSection{
				title: 'Fruits'
				items: [list_item('apple', 'Apple'), list_item('banana', 'Banana'),
					list_item('mango', 'Mango')]
			},
			ListSection{
				title: 'Nuts'
				items: [list_item('pecan', 'Pecan'), list_item('almond', 'Almond')]
			},
		]
		state:     state
		selection: selection
	}
}

fn test_searchable_list_draws_a_field_above_the_results() {
	el := searchable_list(lists_pantry('an', ListState{
		active:   'banana'
		selected: ['mango']
	}, .single)) or { panic(err) }
	assert el.id == 'pantry'
	assert el.children.map(it.key) == ['search', 'divider', 'results']
	field := lists_find(el, 'field') or { panic('no field') }
	assert field.id == searchable_list_field_id('pantry')
	assert field.text == 'an'
	results := el.children[2]
	assert results.id == searchable_list_list_id('pantry')
	rows := results.children[0].children.map(it.key)
	assert rows == [virtual_list_extent_key, 'header:0', 'row:banana', 'row:mango', 'header:1',
		'row:pecan']
	mango := lists_find(results, 'row:mango') or { panic('no mango') }
	assert mango.children.any(it.image_path == 'symbol:checkmark')
	empty := searchable_list(lists_pantry('durian', ListState{}, .single)) or { panic(err) }
	state_view := lists_find(empty, 'empty') or { panic('no empty state') }
	assert state_view.children.any(it.text == 'No results')
	assert state_view.children.any(it.text == 'Nothing matches “durian”.')
	unfiltered := searchable_list(SearchableListConfig{
		...lists_pantry('durian', ListState{}, .single)
		filter: false
	}) or { panic(err) }
	assert lists_find(unfiltered, 'row:apple') != none
	nothing := searchable_list(id: 'none', frame: rect(0, 0, 200, 200)) or { panic(err) }
	assert (lists_find(nothing, 'empty') or { panic('no empty state') }).children.any(it.text == 'No items')
}

fn test_searchable_list_update_follows_the_query() {
	config := lists_pantry('', ListState{
		selected: ['pecan']
	}, .single)
	field := searchable_list_field_id('pantry')
	typed := searchable_list_update(config, field, 'an')?
	assert typed.query == 'an'
	assert typed.state.active == 'banana'
	assert typed.state.selected == ['pecan']
	assert typed.reveal
	assert !typed.sync_field
	if _ := searchable_list_update(lists_pantry('an', ListState{}, .single), field, 'an') {
		assert false, 'an unchanged query changed something'
	}
	nothing := searchable_list_update(config, field, 'durian')?
	assert nothing.state.active == ''
	clear := input_group_config_clear_action('pantry')
	cleared := searchable_list_update(lists_pantry('an', typed.state, .single), clear,
		'')?
	assert cleared.query == ''
	assert cleared.state.active == 'apple'
	assert cleared.sync_field
	if _ := searchable_list_update(lists_pantry('', ListState{}, .single), clear, '') {
		assert false, 'cleared an empty query'
	}
	assert searchable_list_query_state(config, 'nut').active == 'pecan'
}

fn input_group_config_clear_action(id string) string {
	return component_part_id(component_part_id(id, 'search'), 'clear')
}

fn test_searchable_list_update_chooses_and_toggles_rows() {
	single := lists_pantry('an', ListState{
		active: 'banana'
	}, .single)
	submit := component_part_id(component_part_id('pantry', 'search'), 'submit')
	chosen := searchable_list_update(single, submit, 'an')?
	assert chosen.confirmed
	assert chosen.item.id == 'banana'
	assert chosen.state.selected == ['banana']
	row := list_row_action(searchable_list_list_id('pantry'), 'mango')
	clicked := searchable_list_update(single, row, 'an')?
	assert clicked.confirmed
	assert clicked.state.selected == ['mango']
	// Multiple mode toggles on a click and on Return, without confirming.
	multiple := lists_pantry('', ListState{
		selected: ['apple']
		active:   'pecan'
	}, .multiple)
	added := searchable_list_update(multiple, list_row_action(searchable_list_list_id('pantry'),
		'mango'), '')?
	assert added.state.selected == ['apple', 'mango']
	assert !added.confirmed
	removed := searchable_list_update(lists_pantry('', added.state, .multiple), list_row_action(searchable_list_list_id('pantry'),
		'apple'), '')?
	assert removed.state.selected == ['mango']
	returned := searchable_list_update(multiple, submit, '')?
	assert returned.state.selected == ['apple', 'pecan']
	assert !returned.confirmed
	hovered := searchable_list_update(single, 'pointer:enter:${row}:1:2', 'an')?
	assert hovered.state.hovered == 'mango'
	// Rows the query hides are not the list's to press.
	if _ := searchable_list_update(single, list_row_action(searchable_list_list_id('pantry'),
		'apple'), 'an') {
		assert false, 'pressed a filtered-out row'
	}
	if _ := searchable_list_update(single, 'elsewhere', 'an') {
		assert false, 'took a foreign event'
	}
}

fn test_searchable_list_key_moves_the_highlight_only() {
	config := lists_pantry('an', ListState{
		active:   'banana'
		selected: ['pecan']
	}, .single)
	down := searchable_list_key(config, KeyEvent{ code: .down })?
	assert down.state.active == 'mango'
	assert down.state.selected == ['pecan']
	assert down.reveal
	up := searchable_list_key(config, KeyEvent{ code: .up })?
	assert up.state.active == 'pecan'
	enter := searchable_list_key(config, KeyEvent{ code: .enter })?
	assert enter.confirmed
	assert enter.state.selected == ['banana']
	escape := searchable_list_key(config, KeyEvent{ code: .escape })?
	assert escape.query == ''
	assert escape.sync_field
	assert !escape.cancelled
	cancel := searchable_list_key(lists_pantry('', ListState{
		active: 'apple'
	}, .single), KeyEvent{ code: .escape })?
	assert cancel.cancelled
	// Home, End, Space and Cmd+A belong to the field.
	for event in [KeyEvent{
		code: .home
	}, KeyEvent{
		code: .end
	}, KeyEvent{
		code: .space
	}, KeyEvent{
		code: .a
		cmd:  true
	}] {
		if _ := searchable_list_key(config, event) {
			assert false, 'took ${event}'
		}
	}
}
