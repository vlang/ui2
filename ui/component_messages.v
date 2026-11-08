module ui2

import math

// MessageScroller: GPUI Kit's message scroller, a virtual list for a
// conversation. It follows the latest row while the reader is at the bottom,
// keeps the reader's place when rows are added above them, and counts the rows
// that arrived while they were reading further up.
//
// The application owns the messages and the row heights (it builds a
// VirtualListLayout from them) and keeps a MessageScrollerState next to them.
// Every change to the rows goes through the state as a new layout, so the
// state can tell where the reader was and work out where they should be.
//
// Moving the reader means asking the backend to scroll, and that has to wait
// for the content the new position was worked out for: an offset past the end
// of the content the backend shows now would be cut short. A state that wants
// to scroll therefore takes a new serial, which names its Scroll element
// (message_scroller_scroll_id), and the application passes the request from
// take_scroll_request to scroll_to_offset. The backends keep a request for a
// Scroll element they have not laid out yet and carry it out when they lay that
// element out with its new content, so the request lands where it should
// whether it is made from an event handler, a timer or the build function. The
// element keeps its reconciliation key, so the native scroll view stays.

// AppKit, UIKit and the custom renderer leave this much room below a Scroll
// element's content, and the bottom of the scroller includes it. Win32 leaves
// none and clamps the difference away, which still counts as the bottom.
const message_scroller_scroll_inset = 16.0

// How close to the last row's end still counts as at the bottom.
const message_scroller_end_tolerance = 2.0

// MessageScrollerPosition is where a scroller starts.
pub enum MessageScrollerPosition {
	latest // At the bottom, following the latest row.
	top    // At the first row.
	row    // At MessageScrollerStart.row, placed by its align.
}

// MessageScrollerStart is the starting position of message_scroller_state
// and reset: the latest row (the default), the first, or a given one, such as
// a saved place or the first unread message.
pub struct MessageScrollerStart {
pub:
	position MessageScrollerPosition = .latest
	row      int
	align    VirtualListAlign = .start
	// first_unread is the first row the reader has not seen; rows from it on
	// count as unread until they are scrolled into view. -1 means none.
	first_unread int = -1
}

// MessageScrollerAnchor is a scroll position told by the row at the top of
// the viewport: its index and how far into it the viewport starts. The offset
// is negative when the viewport starts in the gap or padding before the row.
// GPUI calls this the logical scroll top.
pub struct MessageScrollerAnchor {
pub:
	index  int = -1 // -1 for an empty list.
	offset f64
}

// MessageScrollerScroll is a scroll a state asks for: pass it to
// scroll_to_offset(request.id, request.offset).
pub struct MessageScrollerScroll {
pub:
	id     string
	offset f64
}

// MessageScrollerState is the controlled state of a message scroller. Make
// one with message_scroller_state, replace it with what its methods return,
// and after each change pass take_scroll_request to scroll_to_offset. The zero
// value is an empty scroller.
pub struct MessageScrollerState {
pub:
	layout   VirtualListLayout // The rows: their heights, the gap and the padding.
	viewport f64               // The height of the scroller the positions are for.
	offset   f64               // The scroll position the scroller is built for.
	// following is true while the scroller follows the tail: rows added at the
	// end, and growth of the last row, keep the bottom in view.
	following    bool = true
	first_unread int  = -1 // The first unread row, or -1.
	serial       int // Names the Scroll element; a new one comes with every scroll asked for.
mut:
	pending bool // A scroll has been asked for and not yet taken.
}

// message_scroller_layout lays out rows of the given heights with `gap`
// between them and `padding` above the first and below the last, GPUI Kit's
// row and list spacing (its defaults are a 32 gap and 8 padding).
pub fn message_scroller_layout(heights []f64, gap f64, padding f64) !VirtualListLayout {
	return virtual_list_sized(heights, gap)!.padded(padding)!
}

// message_scroller_state starts a scroller over layout in a viewport of the
// given height, at the position start names. It asks for that position, so
// take the request and pass it to scroll_to_offset before or after the first
// build: the backend applies it when it first lays the scroller out.
pub fn message_scroller_state(layout VirtualListLayout, viewport f64, start MessageScrollerStart) MessageScrollerState {
	return MessageScrollerState{
		viewport: message_scroller_extent(viewport)
	}.reset(layout, start)
}

// message_scroller_scroll_id is the id of the Scroll element a scroller with
// this state builds, the id on_scroll reports. It changes with every scroll
// the state asks for.
pub fn message_scroller_scroll_id(id string, s MessageScrollerState) string {
	return component_part_id(id, 'scroll:${s.serial}')
}

fn message_scroller_extent(value f64) f64 {
	return if component_finite(value) { math.max(value, 0) } else { 0.0 }
}

// message_scroller_anchor finds the row at the top of a viewport scrolled to
// offset: the first row that ends below it, which is the next row when the
// offset falls in a gap and the last row past the end.
pub fn message_scroller_anchor(layout VirtualListLayout, offset f64) MessageScrollerAnchor {
	if layout.count == 0 {
		return MessageScrollerAnchor{}
	}
	position := message_scroller_extent(offset)
	index := layout.index_at(position)
	return MessageScrollerAnchor{
		index:  index
		offset: position - layout.item_start(index)
	}
}

// message_scroller_anchor_offset is the scroll offset that puts an anchor's
// row back at the top of the viewport, as far into it as before, in a layout
// whose rows may have moved or changed size. A row that got shorter than the
// anchor's offset is kept to its end. An empty layout or an anchor outside it
// gives 0.
pub fn message_scroller_anchor_offset(layout VirtualListLayout, anchor MessageScrollerAnchor) f64 {
	if anchor.index < 0 || anchor.index >= layout.count {
		return 0
	}
	into := math.min(anchor.offset, layout.item_size(anchor.index))
	return math.max(layout.item_start(anchor.index) + into, 0)
}

// message_scroller_scaled_anchor keeps an anchor the same fraction of the
// way into its row when the row changes from old_size to new_size, which is
// where the same text roughly is after the row reflows. An anchor in the gap
// or padding before its row keeps its offset.
pub fn message_scroller_scaled_anchor(anchor MessageScrollerAnchor, old_size f64, new_size f64) MessageScrollerAnchor {
	if anchor.offset <= 0 || old_size <= 0 || !component_finite(new_size) {
		return anchor
	}
	return MessageScrollerAnchor{
		index:  anchor.index
		offset: anchor.offset * new_size / old_size
	}
}

// message_scroller_spliced_row maps a row index across a splice that
// replaced `removed` rows at `start` with `inserted` new ones: rows before the
// splice keep their index, rows after it move with the difference, and a
// removed row maps to the row that took its place (the first inserted one, or
// the one after the splice).
pub fn message_scroller_spliced_row(index int, start int, removed int, inserted int) int {
	if index < start {
		return index
	}
	if index >= start + removed {
		return index - removed + inserted
	}
	return start
}

// message_scroller_follows is the follow-tail rule for a reported scroll from
// previous to offset, where `bottom` is the offset at which the last row's end
// shows: at the bottom the scroller follows the tail, a move up stops it, and
// anything else keeps what it was. Only the reader moves the scroller up, so a
// move up is the reader leaving the tail; reaching the bottom again, by any
// means, resumes following, as GPUI's list does.
pub fn message_scroller_follows(following bool, previous f64, offset f64, bottom f64) bool {
	if offset >= bottom - message_scroller_end_tolerance {
		return true
	}
	if offset < previous - 0.5 {
		return false
	}
	return following
}

// message_scroller_read_up_to is the unread rule: the rows before seen_end
// have been read, so the first unread row is no earlier than seen_end, and
// when that is past the last row nothing is unread (-1). It is a high-water
// mark, as a chat's read marker is: rows the reader scrolled past count as
// read even if no report caught them in view.
pub fn message_scroller_read_up_to(first_unread int, count int, seen_end int) int {
	if first_unread < 0 {
		return -1
	}
	next := math.max(first_unread, seen_end)
	return if next >= count { -1 } else { next }
}

// message_scroller_unread_after_splice moves the first unread row across a
// splice of `removed` rows at `start` by `inserted` new ones. Rows added at the
// end (start == count) while the reader is away from the tail are new
// messages: when nothing was unread they become the first unread ones.
pub fn message_scroller_unread_after_splice(first_unread int, count int, start int, removed int, inserted int, following bool) int {
	new_count := count - removed + inserted
	if first_unread >= 0 {
		moved := message_scroller_spliced_row(first_unread, start, removed, inserted)
		return if moved < new_count { moved } else { -1 }
	}
	if start == count && inserted > 0 && !following {
		return count - removed
	}
	return -1
}

// end_offset is the scroll offset of the bottom: the furthest the backend
// scrolls, the room it leaves below the content included.
pub fn (s MessageScrollerState) end_offset() f64 {
	if s.layout.count == 0 {
		return 0
	}
	return math.max(s.layout.total() + message_scroller_scroll_inset - s.viewport, 0)
}

// bottom is the offset at which the last row's end comes into view.
fn (s MessageScrollerState) bottom() f64 {
	return s.layout.max_offset(s.viewport)
}

// seen_end is the end of the rows the reader has seen at this position: those
// whose end is above the viewport's bottom edge, and at the bottom all of them.
// A row only peeking in at the bottom is not read yet.
fn (s MessageScrollerState) seen_end() int {
	if s.at_end() {
		return s.layout.count
	}
	return s.layout.first_ending_after(s.offset + s.viewport)
}

// item_count is the number of rows the state knows.
pub fn (s MessageScrollerState) item_count() int {
	return s.layout.count
}

// at_end reports whether the last row's end is in view.
pub fn (s MessageScrollerState) at_end() bool {
	return s.offset >= s.bottom() - message_scroller_end_tolerance
}

// is_scrolled_up reports whether the reader has left the tail: there is
// content below the viewport and the scroller does not follow it. It is when
// the jump-to-latest control shows.
pub fn (s MessageScrollerState) is_scrolled_up() bool {
	return s.bottom() > 0 && !s.following && !s.at_end()
}

// unread is the number of rows from the first unread one to the end.
pub fn (s MessageScrollerState) unread() int {
	return if s.first_unread < 0 { 0 } else { math.max(s.layout.count - s.first_unread, 0) }
}

// anchor is the row at the top of the viewport and how far into it the
// viewport starts.
pub fn (s MessageScrollerState) anchor() MessageScrollerAnchor {
	return message_scroller_anchor(s.layout, s.offset)
}

// range is what the scroller builds: the rows in view and overscan more on
// each side.
pub fn (s MessageScrollerState) range(overscan int) VirtualListRange {
	return s.layout.range(s.viewport, s.offset, overscan)
}

// near_start reports whether the rows in view reach within threshold rows of
// the first, the moment to load earlier history. It is also true while every
// row fits, so loading continues until the viewport is full.
pub fn (s MessageScrollerState) near_start(threshold int) bool {
	if s.layout.count == 0 || threshold < 0 {
		return false
	}
	return s.range(0).visible_start <= threshold
}

// pending_scroll reports whether a scroll has been asked for and not taken.
pub fn (s MessageScrollerState) pending_scroll() bool {
	return s.pending
}

// take_scroll_request hands out the scroll this state asked for, once: pass
// it to scroll_to_offset. id is the scroller's id. It returns none when there
// is nothing to do.
pub fn (mut s MessageScrollerState) take_scroll_request(id string) ?MessageScrollerScroll {
	if !s.pending {
		return none
	}
	s.pending = false
	return MessageScrollerScroll{
		id:     message_scroller_scroll_id(id, s)
		offset: s.offset
	}
}

// moved is the state at offset in its layout, with the rows that come into
// view there marked read. When the offset differs from where the backend is
// (the current offset), it asks the backend to scroll there under a new serial.
fn (s MessageScrollerState) moved(next MessageScrollerState, offset f64, following bool) MessageScrollerState {
	clamped := math.min(message_scroller_extent(offset), next.end_offset())
	placed := MessageScrollerState{
		...next
		offset: clamped
	}
	changed := math.abs(clamped - s.offset) > 0.5
	return MessageScrollerState{
		...placed
		following:    following || placed.at_end()
		first_unread: message_scroller_read_up_to(next.first_unread, next.layout.count,
			placed.seen_end())
		serial:       if changed { s.serial + 1 } else { s.serial }
		pending:      s.pending || changed
	}
}

// reset replaces every row with layout (a new conversation) and goes to the
// position start names. Unlike splice it keeps no anchor.
pub fn (s MessageScrollerState) reset(layout VirtualListLayout, start MessageScrollerStart) MessageScrollerState {
	first_unread := if start.first_unread >= 0 && start.first_unread < layout.count {
		start.first_unread
	} else {
		-1
	}
	base := MessageScrollerState{
		layout:       layout
		viewport:     s.viewport
		offset:       s.offset
		first_unread: first_unread
		serial:       s.serial
		pending:      s.pending
	}
	mut offset := base.end_offset()
	mut following := true
	if layout.count > 0 && start.position == .top {
		offset = 0
		following = false
	} else if layout.count > 0 && start.position == .row && start.row >= 0
		&& start.row < layout.count {
		offset = layout.scroll_offset_for(start.row, s.viewport, 0, start.align)
		following = false
	}
	// Always ask: a new conversation starts where start says, wherever the
	// last one was.
	moved := s.moved(base, offset, following)
	return MessageScrollerState{
		...moved
		serial:  s.serial + 1
		pending: true
	}
}

// splice replaces the `removed` rows at `start` with the rows layout has in
// their place; layout is the whole new list. Following the tail, the bottom
// stays in view. Otherwise the row at the top of the viewport stays where it
// is on screen, so rows inserted or removed above it do not move what the
// reader is looking at. Rows added at the end while the reader is away from
// the tail count as unread. It fails when the range is outside the list.
pub fn (s MessageScrollerState) splice(start int, removed int, layout VirtualListLayout) !MessageScrollerState {
	count := s.layout.count
	if start < 0 || removed < 0 || start > count || removed > count - start {
		return error('message scroller splice ${start}+${removed} is outside its ${count} rows')
	}
	inserted := layout.count - (count - removed)
	if inserted < 0 {
		return error('message scroller layout has ${layout.count} rows, fewer than the ${count - removed} kept')
	}
	next := MessageScrollerState{
		...s
		layout:       layout
		first_unread: message_scroller_unread_after_splice(s.first_unread, count, start,
			removed, inserted, s.following)
	}
	if s.following {
		return s.moved(next, next.end_offset(), true)
	}
	anchor := s.anchor()
	moved_anchor := MessageScrollerAnchor{
		index:  message_scroller_spliced_row(anchor.index, start, removed, inserted)
		offset: if anchor.index >= start && anchor.index < start + removed {
			0.0
		} else {
			anchor.offset
		}
	}
	offset := if anchor.index < 0 {
		0.0
	} else {
		message_scroller_anchor_offset(layout, moved_anchor)
	}
	return s.moved(next, offset, false)
}

// append adds the rows layout has after the current ones, GPUI Kit's append:
// followed when at the tail, unread when not.
pub fn (s MessageScrollerState) append(layout VirtualListLayout) !MessageScrollerState {
	return s.splice(s.layout.count, 0, layout)
}

// prepend adds the rows layout has before the current ones, such as earlier
// history, keeping the row the reader is looking at where it is.
pub fn (s MessageScrollerState) prepend(layout VirtualListLayout) !MessageScrollerState {
	return s.splice(0, 0, layout)
}

// remeasure takes new heights for every row, after the width, the font or
// anything else that reflows them changed. Following the tail, the bottom
// stays in view; otherwise the row at the top of the viewport stays at the
// top, the same fraction of the way into it (GPUI's proportional anchor). It
// fails when layout has a different number of rows.
pub fn (s MessageScrollerState) remeasure(layout VirtualListLayout) !MessageScrollerState {
	next := s.remeasured(layout)!
	if s.following {
		return s.moved(next, next.end_offset(), true)
	}
	anchor := s.anchor()
	scaled := message_scroller_scaled_anchor(anchor, s.layout.item_size(anchor.index),
		layout.item_size(anchor.index))
	return s.moved(next, message_scroller_anchor_offset(layout, scaled), false)
}

// remeasure_rows takes new heights for the rows in [start, end), such as a
// message that grew while streaming; layout is the whole list. Following the
// tail, the bottom stays in view; otherwise the row at the top of the viewport
// stays put, as far into it as before (GPUI's item anchor), so a row growing
// below the reader moves nothing. It fails when the range is outside the list
// or layout has a different number of rows.
pub fn (s MessageScrollerState) remeasure_rows(start int, end int, layout VirtualListLayout) !MessageScrollerState {
	if start < 0 || end < start || end > s.layout.count {
		return error('message scroller rows ${start}..${end} are outside its ${s.layout.count} rows')
	}
	next := s.remeasured(layout)!
	if s.following {
		return s.moved(next, next.end_offset(), true)
	}
	return s.moved(next, message_scroller_anchor_offset(layout, s.anchor()), false)
}

fn (s MessageScrollerState) remeasured(layout VirtualListLayout) !MessageScrollerState {
	if layout.count != s.layout.count {
		return error('message scroller got ${layout.count} rows for ${s.layout.count}')
	}
	return MessageScrollerState{
		...s
		layout: layout
	}
}

// resize takes the scroller's new height. Following the tail, the bottom stays
// in view; otherwise the top row does, which is where the backend keeps it.
pub fn (s MessageScrollerState) resize(viewport f64) MessageScrollerState {
	size := message_scroller_extent(viewport)
	if size == s.viewport {
		return s
	}
	next := MessageScrollerState{
		...s
		viewport: size
	}
	return s.moved(next, if s.following { next.end_offset() } else { s.offset }, s.following)
}

// scroll_to_row brings the row at index into view, placed by align (.nearest
// does not move a row that already shows in full). Reaching the bottom this
// way resumes following the tail. It returns none for an index outside the
// list. Resolve message ids, search results and unread boundaries to an index
// first.
pub fn (s MessageScrollerState) scroll_to_row(index int, align VirtualListAlign) ?MessageScrollerState {
	if index < 0 || index >= s.layout.count {
		return none
	}
	return s.moved(s, s.layout.scroll_offset_for(index, s.viewport, s.offset, align),
		false)
}

// scroll_to_end goes to the latest row and follows the tail again; every row
// is then read.
pub fn (s MessageScrollerState) scroll_to_end() MessageScrollerState {
	return s.moved(s, s.end_offset(), true)
}

// scrolled takes a scroll position the backend reported: the reader moved.
// It applies the follow-tail rule and marks the rows now in view read.
pub fn (s MessageScrollerState) scrolled(offset f64) MessageScrollerState {
	if !component_finite(offset) {
		return s
	}
	position := math.max(offset, 0)
	placed := MessageScrollerState{
		...s
		offset: position
	}
	return MessageScrollerState{
		...placed
		following:    message_scroller_follows(s.following, s.offset, position, s.bottom())
		first_unread: message_scroller_read_up_to(s.first_unread, s.layout.count, placed.seen_end())
	}
}

// mark_unread makes the rows from index on unread, such as the messages that
// arrived since the conversation was last open. An index past the rows
// clears the unread rows.
pub fn (s MessageScrollerState) mark_unread(index int) MessageScrollerState {
	return MessageScrollerState{
		...s
		first_unread: if index >= 0 && index < s.layout.count { index } else { -1 }
	}
}

// mark_read leaves no row unread.
pub fn (s MessageScrollerState) mark_read() MessageScrollerState {
	return MessageScrollerState{
		...s
		first_unread: -1
	}
}
