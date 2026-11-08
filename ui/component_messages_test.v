module ui2

import math

// Rows of 40, 4 apart, 8 of padding at each end: row i starts at 8 + 44 i.
fn messages_rows(count int) VirtualListLayout {
	return message_scroller_layout([]f64{len: count, init: 40.0}, 4, 8) or { panic(err) }
}

fn messages_heights(heights []f64) VirtualListLayout {
	return message_scroller_layout(heights, 4, 8) or { panic(err) }
}

fn messages_close(a f64, b f64) bool {
	return math.abs(a - b) < 1e-9
}

fn messages_item(index int, frame Rect) Element {
	return Element{
		...view('', frame, BoxStyle{}, []Element{})
		key: 'row:${index}'
	}
}

fn messages_config(s MessageScrollerState) MessageScrollerConfig {
	return MessageScrollerConfig{
		id:    'feed'
		frame: rect(0, 0, 320, s.viewport)
		state: s
		item:  messages_item
	}
}

fn messages_find(el Element, key string) ?Element {
	if el.key == key {
		return el
	}
	for child in el.children {
		if found := messages_find(child, key) {
			return found
		}
	}
	return none
}

fn test_message_scroller_layout_and_anchor() {
	layout := messages_heights([10.0, 20, 30])
	assert layout.total() == 8 + 10 + 4 + 20 + 4 + 30 + 8
	assert message_scroller_anchor(layout, 0) == MessageScrollerAnchor{0, -8}
	assert message_scroller_anchor(layout, 8) == MessageScrollerAnchor{0, 0}
	// In the gap before row 1, which starts at 22.
	assert message_scroller_anchor(layout, 20) == MessageScrollerAnchor{1, -2}
	assert message_scroller_anchor(layout, 30) == MessageScrollerAnchor{1, 8}
	// Past the end: the last row.
	assert message_scroller_anchor(layout, 500).index == 2
	assert message_scroller_anchor(VirtualListLayout{}, 40) == MessageScrollerAnchor{}
	if _ := message_scroller_layout([10.0, -1], 4, 8) {
		assert false, 'negative height accepted'
	}
	if _ := message_scroller_layout([10.0], 4, -8) {
		assert false, 'negative padding accepted'
	}
}

fn test_message_scroller_anchor_offset_follows_moved_rows() {
	before := messages_heights([10.0, 20, 30])
	anchor := message_scroller_anchor(before, 27) // 5 into row 1
	assert anchor == MessageScrollerAnchor{1, 5}
	// Two rows of 7 and 9 before it move it down by 7 + 4 + 9 + 4.
	after := messages_heights([7.0, 9, 10, 20, 30])
	moved := MessageScrollerAnchor{
		index:  message_scroller_spliced_row(anchor.index, 0, 0, 2)
		offset: anchor.offset
	}
	assert moved.index == 3
	assert message_scroller_anchor_offset(after, moved) == 27 + 24
	// A row that shrinks below the anchor's offset keeps the anchor at its end.
	shrunk := messages_heights([10.0, 3, 30])
	assert message_scroller_anchor_offset(shrunk, anchor) == 22 + 3
	// An anchor in the padding stays in the padding.
	assert message_scroller_anchor_offset(after, MessageScrollerAnchor{0, -8}) == 0
	assert message_scroller_anchor_offset(after, MessageScrollerAnchor{9, 0}) == 0
	assert message_scroller_anchor_offset(after, MessageScrollerAnchor{}) == 0
}

fn test_message_scroller_spliced_row() {
	assert message_scroller_spliced_row(2, 5, 3, 1) == 2
	assert message_scroller_spliced_row(9, 5, 3, 1) == 7
	assert message_scroller_spliced_row(9, 0, 0, 4) == 13
	// Removed rows map to the row that took their place.
	assert message_scroller_spliced_row(6, 5, 3, 1) == 5
	assert message_scroller_spliced_row(6, 5, 3, 0) == 5
}

fn test_message_scroller_follow_rule() {
	// At the bottom, within the tolerance, the tail is followed.
	assert message_scroller_follows(false, 100, 500, 500)
	assert message_scroller_follows(false, 100, 498.5, 500)
	assert message_scroller_follows(true, 500, 520, 500)
	// Moving up leaves it.
	assert !message_scroller_follows(true, 500, 480, 500)
	// Moving down short of the bottom, or not moving, keeps what was.
	assert !message_scroller_follows(false, 100, 300, 500)
	assert message_scroller_follows(true, 300, 300.2, 500)
}

fn test_message_scroller_unread_rules() {
	assert message_scroller_read_up_to(-1, 10, 4) == -1
	assert message_scroller_read_up_to(6, 10, 4) == 6
	assert message_scroller_read_up_to(6, 10, 8) == 8
	assert message_scroller_read_up_to(6, 10, 10) == -1
	// Appended rows are unread only while the reader is away from the tail.
	assert message_scroller_unread_after_splice(-1, 10, 10, 0, 3, false) == 10
	assert message_scroller_unread_after_splice(-1, 10, 10, 0, 3, true) == -1
	assert message_scroller_unread_after_splice(7, 10, 10, 0, 3, false) == 7
	// Prepended rows move the boundary; history is not new.
	assert message_scroller_unread_after_splice(7, 10, 0, 0, 5, false) == 12
	assert message_scroller_unread_after_splice(-1, 10, 0, 0, 5, false) == -1
	// A removed boundary moves to what took its place; past the end, none.
	assert message_scroller_unread_after_splice(7, 10, 6, 3, 1, false) == 6
	assert message_scroller_unread_after_splice(9, 10, 8, 2, 0, false) == -1
}

fn test_message_scroller_starts_at_latest() {
	layout := messages_rows(100) // 8 + 100 * 40 + 99 * 4 + 8 = 4412
	mut s := message_scroller_state(layout, 400, MessageScrollerStart{})
	assert s.item_count() == 100
	assert s.following
	assert s.at_end()
	assert !s.is_scrolled_up()
	// The bottom includes the room the backends leave below the content.
	assert s.offset == 4412 + 16 - 400
	assert s.end_offset() == s.offset
	assert s.serial == 1
	assert s.pending_scroll()
	request := s.take_scroll_request('feed') or { panic('no request') }
	assert request.id == 'feed:component:scroll:1'
	assert request.id == message_scroller_scroll_id('feed', s)
	assert request.offset == s.offset
	assert !s.pending_scroll()
	if _ := s.take_scroll_request('feed') {
		assert false, 'a request was handed out twice'
	}
}

fn test_message_scroller_starts_at_top_or_a_row() {
	layout := messages_rows(100)
	top := message_scroller_state(layout, 400, position: .top)
	assert top.offset == 0
	assert !top.following
	assert top.is_scrolled_up()
	assert top.pending_scroll()
	row := message_scroller_state(layout, 400, position: .row, row: 50)
	assert row.offset == 8 + 50 * 44
	assert row.anchor() == MessageScrollerAnchor{50, 0}
	centered := message_scroller_state(layout, 400, position: .row, row: 50, align: .center)
	assert centered.offset == 8 + 50 * 44 + 20 - 200
	// A row outside the list starts at the latest one.
	outside := message_scroller_state(layout, 400, position: .row, row: 100)
	assert outside.following
	// Content that fits is always at its end, and so followed.
	short := message_scroller_state(messages_rows(3), 400, position: .top)
	assert short.following
	assert !short.is_scrolled_up()
}

fn test_message_scroller_start_marks_shown_rows_read() {
	layout := messages_rows(100)
	// Opening at the first unread row shows rows 90 to 98 in full (row 98
	// ends at 8 + 98 * 44 + 40 = 4360, inside 3968 + 400) and only the top
	// of row 99.
	s := message_scroller_state(layout, 400, position: .row, row: 90, first_unread: 90)
	assert s.offset == 8 + 90 * 44
	assert s.first_unread == 99
	assert s.unread() == 1
	// At the latest row everything is read.
	latest := message_scroller_state(layout, 400, first_unread: 90)
	assert latest.unread() == 0
	// An out-of-range boundary is ignored.
	none_unread := message_scroller_state(layout, 400, position: .top, first_unread: 100)
	assert none_unread.first_unread == -1
}

fn test_message_scroller_appends_follow_the_tail() {
	mut s := message_scroller_state(messages_rows(100), 400, MessageScrollerStart{})
	s.take_scroll_request('feed') or { panic('no request') }
	next := s.append(messages_rows(102)) or { panic(err) }
	assert next.following
	assert next.offset == s.offset + 88
	assert next.serial == s.serial + 1
	assert next.pending_scroll()
	assert next.unread() == 0
	if _ := s.append(messages_rows(99)) {
		assert false, 'fewer rows accepted as an append'
	}
}

fn test_message_scroller_appends_away_from_the_tail_are_unread() {
	start := message_scroller_state(messages_rows(100), 400, position: .row, row: 40)
	mut s := start
	s.take_scroll_request('feed') or { panic('no request') }
	next := s.append(messages_rows(103)) or { panic(err) }
	assert !next.following
	assert next.offset == s.offset
	assert next.serial == s.serial
	assert !next.pending_scroll()
	assert next.first_unread == 100
	assert next.unread() == 3
	assert next.is_scrolled_up()
	more := next.append(messages_rows(105)) or { panic(err) }
	assert more.first_unread == 100
	assert more.unread() == 5
}

fn test_message_scroller_streaming_growth() {
	mut heights := []f64{len: 100, init: 40.0}
	mut s := message_scroller_state(messages_heights(heights), 400, MessageScrollerStart{})
	s.take_scroll_request('feed') or { panic('no request') }
	heights[99] = 100
	grown := s.remeasure_rows(99, 100, messages_heights(heights)) or { panic(err) }
	assert grown.following
	assert grown.offset == s.offset + 60
	assert grown.pending_scroll()
	// The same heights again ask for nothing.
	mut settled := grown
	settled.take_scroll_request('feed') or { panic('no request') }
	again := settled.remeasure_rows(99, 100, messages_heights(heights)) or { panic(err) }
	assert again.serial == settled.serial
	assert !again.pending_scroll()
	// Away from the tail, a row growing below the reader moves nothing.
	away := settled.scroll_to_row(10, .start) or { panic('no row') }
	heights[99] = 160
	still := away.remeasure_rows(99, 100, messages_heights(heights)) or { panic(err) }
	assert still.offset == away.offset
	assert still.serial == away.serial
	// Nor does the row the reader is in growing at its end: the reader stays
	// as far into it as before.
	inside := away.scrolled(away.offset + 25)
	heights[10] = 90
	kept := inside.remeasure_rows(10, 11, messages_heights(heights)) or { panic(err) }
	assert kept.anchor() == MessageScrollerAnchor{10, 25}
	for start, end in {
		-1: 1
		5:  4
		99: 101
	} {
		if _ := s.remeasure_rows(start, end, messages_heights(heights)) {
			assert false, 'rows ${start}..${end} accepted'
		}
	}
	if _ := s.remeasure_rows(0, 1, messages_rows(99)) {
		assert false, 'a different row count accepted'
	}
}

fn test_message_scroller_remeasure_reflows_around_the_top_row() {
	mut heights := []f64{len: 100, init: 40.0}
	s := message_scroller_state(messages_heights(heights), 400, position: .row, row: 50)
	// Every row reflows taller (a narrower window): the row at the top stays
	// at the top.
	for i in 0 .. 100 {
		heights[i] = 60
	}
	next := s.remeasure(messages_heights(heights)) or { panic(err) }
	assert next.offset == s.offset + 50 * 20
	assert next.anchor() == MessageScrollerAnchor{50, 0}
	assert next.pending_scroll()
	// Partway into the row, the reader stays the same fraction into it.
	into := s.scrolled(s.offset + 30)
	wider := into.remeasure(messages_heights([]f64{len: 100, init: 20.0})) or { panic(err) }
	assert wider.anchor() == MessageScrollerAnchor{50, 15}
	narrower := into.remeasure(messages_heights(heights)) or { panic(err) }
	assert narrower.anchor() == MessageScrollerAnchor{50, 45}
	assert message_scroller_scaled_anchor(MessageScrollerAnchor{3, -4}, 40, 80) == MessageScrollerAnchor{3, -4}
	assert message_scroller_scaled_anchor(MessageScrollerAnchor{3, 10}, 40, 80) == MessageScrollerAnchor{3, 20}
	assert message_scroller_scaled_anchor(MessageScrollerAnchor{3, 10}, 0, 80) == MessageScrollerAnchor{3, 10}
	if _ := s.remeasure(messages_rows(99)) {
		assert false, 'a different row count accepted'
	}
}

fn test_message_scroller_prepend_keeps_the_reader_in_place() {
	mut s := message_scroller_state(messages_rows(100), 400,
		position:     .row
		row:          3
		first_unread: 60
	)
	s.take_scroll_request('feed') or { panic('no request') }
	s = s.scrolled(s.offset + 10)
	anchor := s.anchor()
	assert anchor == MessageScrollerAnchor{3, 10}
	next := s.prepend(messages_rows(150)) or { panic(err) }
	assert next.anchor() == MessageScrollerAnchor{53, 10}
	assert next.offset == s.offset + 50 * 44
	assert next.first_unread == 110
	assert next.serial == s.serial + 1
	assert next.pending_scroll()
	assert !next.following
	// From the top padding as well.
	top := message_scroller_state(messages_rows(100), 400, position: .top)
	prepended := top.prepend(messages_rows(101)) or { panic(err) }
	assert prepended.offset == 44
	// Following the tail, the bottom stays in view.
	latest := message_scroller_state(messages_rows(100), 400, MessageScrollerStart{})
	grown := latest.prepend(messages_rows(110)) or { panic(err) }
	assert grown.following
	assert grown.offset == grown.end_offset()
}

fn test_message_scroller_splice_removing_rows() {
	s := message_scroller_state(messages_rows(100), 400, position: .row, row: 50)
	// Rows above go: the reader stays with row 50, now row 40.
	fewer := s.splice(10, 10, messages_rows(90)) or { panic(err) }
	assert fewer.anchor() == MessageScrollerAnchor{40, 0}
	// The row at the top goes: the one after it takes its place.
	gone := s.splice(50, 1, messages_rows(99)) or { panic(err) }
	assert gone.anchor() == MessageScrollerAnchor{50, 0}
	// Replacing one row by two below the reader moves nothing.
	below := s.splice(80, 1, messages_rows(101)) or { panic(err) }
	assert below.offset == s.offset
	for start, removed in {
		-1:  0
		101: 0
		95:  6
		0:   -1
	} {
		if _ := s.splice(start, removed, messages_rows(100)) {
			assert false, 'splice ${start}+${removed} accepted'
		}
	}
	if _ := s.splice(10, 10, messages_rows(80)) {
		assert false, 'a layout short of the kept rows accepted'
	}
	// Removing everything leaves an empty, followed scroller.
	empty := s.splice(0, 100, VirtualListLayout{}) or { panic(err) }
	assert empty.item_count() == 0
	assert empty.offset == 0
	assert empty.following
}

fn test_message_scroller_navigation() {
	mut s := message_scroller_state(messages_rows(100), 400, MessageScrollerStart{})
	s.take_scroll_request('feed') or { panic('no request') }
	if _ := s.scroll_to_row(100, .start) {
		assert false, 'row outside the list accepted'
	}
	if _ := s.scroll_to_row(-1, .start) {
		assert false, 'negative row accepted'
	}
	mid := s.scroll_to_row(20, .center) or { panic('no row') }
	assert !mid.following
	assert mid.is_scrolled_up()
	assert mid.serial == s.serial + 1
	// A row that shows in full is not moved by .nearest.
	mut settled := mid
	settled.take_scroll_request('feed') or { panic('no request') }
	near := settled.scroll_to_row(20, .nearest) or { panic('no row') }
	assert near.offset == settled.offset
	assert !near.pending_scroll()
	// Bringing the last row's end into view resumes following.
	last := settled.scroll_to_row(99, .end) or { panic('no row') }
	assert last.following
	back := settled.mark_unread(90).scroll_to_end()
	assert back.following
	assert back.offset == back.end_offset()
	assert back.unread() == 0
	assert settled.mark_unread(90).unread() == 10
	assert settled.mark_unread(90).mark_read().unread() == 0
	assert settled.mark_unread(100).first_unread == -1
}

fn test_message_scroller_reported_scrolls() {
	s := message_scroller_state(messages_rows(100), 400, MessageScrollerStart{})
	// Moving up leaves the tail.
	up := s.scrolled(s.offset - 200)
	assert !up.following
	assert up.is_scrolled_up()
	assert up.serial == s.serial
	// Rows appended now are unread, and are read once the reader scrolls down
	// to them.
	more := up.append(messages_rows(104)) or { panic(err) }
	assert more.unread() == 4
	// Rows 100 and 101 end above the viewport's bottom edge at 4100 + 400.
	partway := more.scrolled(4100)
	assert !partway.following
	assert partway.unread() == 2
	bottom := partway.scrolled(partway.end_offset())
	assert bottom.following
	assert bottom.unread() == 0
	// Non-finite reports change nothing; negative ones are the top.
	assert s.scrolled(math.nan()) == s
	assert s.scrolled(-30).offset == 0
}

fn test_message_scroller_resize() {
	s := message_scroller_state(messages_rows(100), 400, MessageScrollerStart{})
	taller := s.resize(500)
	assert taller.viewport == 500
	assert taller.offset == taller.end_offset()
	assert taller.offset == s.offset - 100
	assert taller.serial == s.serial + 1
	assert s.resize(400) == s
	away := message_scroller_state(messages_rows(100), 400, position: .row, row: 30)
	shorter := away.resize(300)
	assert shorter.offset == away.offset
	assert shorter.serial == away.serial
	assert s.resize(math.inf(1)).viewport == 0
}

fn test_message_scroller_near_start() {
	layout := messages_rows(100)
	s := message_scroller_state(layout, 400, position: .row, row: 4)
	assert !s.near_start(3)
	assert s.near_start(4)
	assert !s.near_start(-1)
	assert message_scroller_state(layout, 400, position: .top).near_start(0)
	assert !MessageScrollerState{}.near_start(10)
}

fn test_message_scroller_zero_value_is_empty() {
	s := MessageScrollerState{}
	assert s.item_count() == 0
	assert s.following
	assert !s.is_scrolled_up()
	assert s.unread() == 0
	assert s.end_offset() == 0
	assert s.anchor().index == -1
	appended := s.append(messages_rows(2)) or { panic(err) }
	assert appended.item_count() == 2
}

fn test_message_scroller_scroll_decoder() {
	s := message_scroller_state(messages_rows(100), 400, MessageScrollerStart{})
	config := messages_config(s)
	id := message_scroller_scroll_id('feed', s)
	if _ := message_scroller_scroll(config, 'other', 10) {
		assert false, 'foreign scroll accepted'
	}
	stale := message_scroller_scroll_id('feed', MessageScrollerState{})
	if _ := message_scroller_scroll(config, stale, 10) {
		assert false, 'stale scroll accepted'
	}
	// The room below the content counts as the bottom.
	inset := message_scroller_scroll(config, id, s.offset - 10) or { panic('rejected') }
	assert inset.state.following
	assert !inset.rebuild
	// A small move inside the built rows rebuilds only because the jump
	// control appears.
	step := message_scroller_scroll(config, id, s.offset - 30) or { panic('rejected') }
	assert !step.state.following
	assert step.rebuild
	assert !step.load_earlier
	quiet := message_scroller_scroll(messages_config(step.state), id, step.state.offset - 1) or {
		panic('rejected')
	}
	assert !quiet.rebuild
	far := message_scroller_scroll(messages_config(step.state), id, 100) or { panic('rejected') }
	assert far.rebuild
	assert far.load_earlier
	never := message_scroller_scroll(MessageScrollerConfig{
		...messages_config(step.state)
		load_earlier_threshold: -1
	}, id, 0) or { panic('rejected') }
	assert !never.load_earlier
}

fn test_message_scroller_jump_decoder() {
	s := message_scroller_state(messages_rows(100), 400, MessageScrollerStart{})
	action := message_scroller_jump_action('feed')
	assert action == 'feed:component:jump'
	// Not shown at the tail.
	if _ := message_scroller_update(messages_config(s), action) {
		assert false, 'jump accepted at the tail'
	}
	away := (s.scrolled(1000).append(messages_rows(120)) or { panic(err) })
	config := messages_config(away)
	for forged in ['feed:component:jumps', 'feed:component:', 'other:component:jump', 'jump',
		'feed:component:jump:1'] {
		if _ := message_scroller_update(config, forged) {
			assert false, '`${forged}` accepted'
		}
	}
	disabled := MessageScrollerConfig{
		...config
		jump_button: false
	}
	if _ := message_scroller_update(disabled, action) {
		assert false, 'jump accepted with the control off'
	}
	latest := message_scroller_update(config, action) or { panic('rejected') }
	assert latest.following
	assert latest.offset == latest.end_offset()
	assert latest.unread() == 0
	assert latest.serial == away.serial + 1
	// To the first unread row first, then to the end.
	unread_first := MessageScrollerConfig{
		...config
		jump_to_unread: true
	}
	first := message_scroller_update(unread_first, action) or { panic('rejected') }
	assert first.anchor().index == 100
	assert !first.following
	second := message_scroller_update(messages_config(first), action) or { panic('rejected') }
	assert second.following
}

fn test_message_scroller_element() {
	away := message_scroller_state(messages_rows(100), 400,
		position:     .row
		row:          40
		first_unread: 90
	)
	config := MessageScrollerConfig{
		...messages_config(away)
		inset:       16
		bottom_fade: true
	}
	el := message_scroller(config) or { panic(err) }
	assert el.id == 'feed'
	// Keyed by its id, so siblings added before it do not replace it.
	assert el.key == 'message-scroller:feed'
	assert el.box.bg == config.theme.background
	rows := messages_find(el, 'message-scroller:rows') or { panic('no rows') }
	assert rows.kind == .scroll
	assert rows.id == message_scroller_scroll_id('feed', away)
	assert rows.accessibility_role == 'log'
	assert rows.accessibility_label == 'Messages'
	assert rows.accessibility_value == '10 new messages'
	// Rows are inset and keep the keys the item builder gave them.
	row := messages_find(rows, 'row:40') or { panic('row 40 not built') }
	assert row.frame == rect(16, 8 + 40 * 44, 320 - 32, 40)
	if _ := messages_find(rows, 'row:0') {
		assert false, 'a row far out of view was built'
	}
	jump := messages_find(el, 'message-scroller:jump') or { panic('no jump control') }
	assert jump.id == 'feed:component:jump'
	assert jump.button_behavior
	assert jump.accessibility_label == 'Jump to latest, 10 new messages'
	assert jump.frame.y + jump.frame.height == 400 - 16
	assert messages_close(jump.frame.x * 2 + jump.frame.width, 320) || messages_close(jump.frame.x * 2 +
		jump.frame.width, 321)
	fade := messages_find(el, 'message-scroller:fade') or { panic('no fade') }
	assert fade.box.gradient.stops.len == 2
	assert fade.box.gradient.stops[1].color == config.theme.background
	assert fade.frame.y + fade.frame.height == 400
	// The background slot fills the scroller and the list, and the fade
	// fades into it.
	filled := message_scroller(MessageScrollerConfig{
		...config
		background: 0x123456
	}) or { panic(err) }
	assert filled.box.bg == 0x123456
	filled_rows := messages_find(filled, 'message-scroller:rows') or { panic('no rows') }
	assert filled_rows.box.bg == 0x123456
	filled_fade := messages_find(filled, 'message-scroller:fade') or { panic('no fade') }
	assert filled_fade.box.gradient.stops[1].color == 0x123456
	// At the tail neither shows.
	latest := message_scroller(messages_config(message_scroller_state(messages_rows(100),
		400, MessageScrollerStart{}))) or { panic(err) }
	if _ := messages_find(latest, 'message-scroller:jump') {
		assert false, 'jump control at the tail'
	}
	// Without unread rows the control is a round arrow button.
	read := message_scroller(messages_config(away.mark_read())) or { panic(err) }
	round := messages_find(read, 'message-scroller:jump') or { panic('no jump control') }
	assert round.frame.width == round.frame.height
	assert round.accessibility_label == 'Jump to latest'
}

fn test_message_scroller_element_options_and_errors() {
	away := message_scroller_state(messages_rows(100), 400,
		position:     .row
		row:          40
		first_unread: 95
	)
	worded := message_scroller(MessageScrollerConfig{
		...messages_config(away)
		unread_text: fn (count int) string {
			return '${count} nouveaux'
		}
		jump_render: fn (jump MessageScrollerJump) Element {
			return Element{
				...button(jump.action, jump.text, jump.frame, BoxStyle{}, TextStyle{})
				key: 'mine'
			}
		}
	}) or { panic(err) }
	custom := messages_find(worded, 'message-scroller:jump') or { panic('no jump control') }
	assert custom.kind == .button
	assert custom.text == '5 nouveaux'
	assert custom.id == 'feed:component:jump'
	empty := message_scroller(MessageScrollerConfig{
		...messages_config(MessageScrollerState{})
		frame:             rect(0, 0, 320, 400)
		empty_description: 'Say hello.'
	}) or { panic(err) }
	status := messages_find(empty, 'message-scroller:empty') or { panic('no empty state') }
	assert status.accessibility_role == 'status'
	assert status.accessibility_label == 'No messages yet. Say hello.'
	if _ := message_scroller(MessageScrollerConfig{
		frame: rect(0, 0, 10, 10)
		item:  messages_item
	})
	{
		assert false, 'missing id accepted'
	}
	if _ := message_scroller(MessageScrollerConfig{
		id:    'feed'
		frame: rect(0, 0, 10, 10)
	})
	{
		assert false, 'missing item builder accepted'
	}
	if _ := message_scroller(MessageScrollerConfig{
		...messages_config(away)
		inset: math.nan()
	})
	{
		assert false, 'NaN inset accepted'
	}
	assert message_scroller_unread_text(1) == '1 new message'
	assert message_scroller_unread_text(12) == '12 new messages'
	assert message_scroller_unread_text(5000) == '999+ new messages'
}
