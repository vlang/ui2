module ui2

import math

// Virtual lists: only the items near the visible part of a long list are built.
//
// A Scroll element is as tall as its lowest child, so a virtual list keeps the
// full extent with one empty spacer and positions just the items in range
// inside it. The application reads the scroll position (on_scroll, then
// scroll_offset) and rebuilds when the range of items it shows changes; the
// pure helpers here say what that range is and where to scroll to bring an
// item into view. The same helpers lay out ui2's List.

// VirtualListAlign is where scrolling to an item puts it in the viewport.
pub enum VirtualListAlign {
	nearest // As little as needed: not at all when it is already in view.
	start   // At the top (or left) edge.
	center  // In the middle.
	end     // At the bottom (or right) edge.
}

// VirtualListLayout holds the extents of a virtual list's items along its
// axis: one fixed size for all of them, or one size each. Items are `gap`
// apart, and `padding` is kept before the first and after the last. The zero
// value is an empty list.
pub struct VirtualListLayout {
pub:
	count   int
	gap     f64
	padding f64
mut:
	fixed f64   // The size of every item when ends is empty.
	ends  []f64 // With sizes of their own: where each item ends, padding excluded.
}

// virtual_list_fixed lays out count items of one size, the fast case: no
// per-item storage, so a million rows cost nothing.
pub fn virtual_list_fixed(count int, item_size f64, gap f64) !VirtualListLayout {
	if count < 0 {
		return error('virtual list count must not be negative')
	}
	if !component_finite(item_size) || item_size <= 0 {
		return error('virtual list item size must be finite and positive')
	}
	if !component_finite(gap) || gap < 0 {
		return error('virtual list gap must be finite and non-negative')
	}
	return VirtualListLayout{
		count: count
		gap:   gap
		fixed: item_size
	}
}

// virtual_list_sized lays out items with a size each, such as rows of different
// heights. Build it once per change of the sizes and keep it: it stores the
// running total, so finding the items in view is a binary search.
pub fn virtual_list_sized(sizes []f64, gap f64) !VirtualListLayout {
	if !component_finite(gap) || gap < 0 {
		return error('virtual list gap must be finite and non-negative')
	}
	mut ends := []f64{cap: sizes.len}
	mut end := 0.0
	for index, size in sizes {
		if !component_finite(size) || size < 0 {
			return error('virtual list item ${index} has an invalid size')
		}
		if index > 0 {
			end += gap
		}
		end += size
		ends << end
	}
	if !component_finite(end) {
		return error('virtual list is too long')
	}
	return VirtualListLayout{
		count: sizes.len
		gap:   gap
		ends:  ends
	}
}

// padded keeps padding before the first item and after the last.
pub fn (layout VirtualListLayout) padded(padding f64) !VirtualListLayout {
	if !component_finite(padding) || padding < 0 {
		return error('virtual list padding must be finite and non-negative')
	}
	return VirtualListLayout{
		...layout
		padding: padding
	}
}

fn (layout VirtualListLayout) uniform() bool {
	return layout.ends.len == 0
}

// total is the length of the whole content: every item, the gaps between them
// and the padding at both ends.
pub fn (layout VirtualListLayout) total() f64 {
	if layout.count == 0 {
		return layout.padding * 2
	}
	return layout.padding * 2 + layout.content_end(layout.count - 1)
}

// content_end is where an item ends, measured from the first item's start.
fn (layout VirtualListLayout) content_end(index int) f64 {
	if layout.uniform() {
		return f64(index) * (layout.fixed + layout.gap) + layout.fixed
	}
	return layout.ends[index]
}

// item_size is the extent of the item at index; zero outside the list.
pub fn (layout VirtualListLayout) item_size(index int) f64 {
	if index < 0 || index >= layout.count {
		return 0
	}
	if layout.uniform() {
		return layout.fixed
	}
	return layout.ends[index] - if index == 0 { 0.0 } else { layout.ends[index - 1] + layout.gap }
}

// item_start is where the item at index begins in the scrolled content.
pub fn (layout VirtualListLayout) item_start(index int) f64 {
	if index <= 0 || layout.count == 0 {
		return layout.padding
	}
	i := math.min(index, layout.count)
	if i == layout.count {
		return layout.padding + layout.content_end(layout.count - 1)
	}
	return layout.padding + layout.content_end(i) - layout.item_size(i)
}

// item_end is where the item at index ends in the scrolled content.
pub fn (layout VirtualListLayout) item_end(index int) f64 {
	return layout.item_start(index) + layout.item_size(index)
}

// first_ending_after is the first item that ends past position, or count.
fn (layout VirtualListLayout) first_ending_after(position f64) int {
	mut low := 0
	mut high := layout.count
	for low < high {
		mid := low + (high - low) / 2
		if layout.item_end(mid) <= position {
			low = mid + 1
		} else {
			high = mid
		}
	}
	return low
}

// first_starting_from is the first item that starts at or past position, or count.
fn (layout VirtualListLayout) first_starting_from(position f64) int {
	mut low := 0
	mut high := layout.count
	for low < high {
		mid := low + (high - low) / 2
		if layout.item_start(mid) < position {
			low = mid + 1
		} else {
			high = mid
		}
	}
	return low
}

// index_at is the item at a position in the content, the next one when the
// position falls in a gap, and the last one past the end; -1 when empty.
pub fn (layout VirtualListLayout) index_at(position f64) int {
	if layout.count == 0 {
		return -1
	}
	return math.min(layout.first_ending_after(position), layout.count - 1)
}

// max_offset is the furthest the content scrolls with a viewport of this size.
pub fn (layout VirtualListLayout) max_offset(viewport f64) f64 {
	return math.max(layout.total() - math.max(viewport, 0), 0)
}

// VirtualListRange is what to build for one scroll position: the items in
// [start, end), which are the visible ones in [visible_start, visible_end) plus
// `overscan` more on each side, and the space the items before and after them
// would take, for layouts that stack spacers rather than position items.
pub struct VirtualListRange {
pub:
	start         int
	end           int
	visible_start int
	visible_end   int
	before        f64 // From the content's start to the start of item `start`.
	after         f64 // From the end of item `end - 1` to the content's end.
	total         f64
}

// len is how many items the range builds.
pub fn (r VirtualListRange) len() int {
	return r.end - r.start
}

// near_end reports whether the visible items reach within threshold items of
// the last of count, the moment an infinitely scrolling list loads more.
pub fn (r VirtualListRange) near_end(count int, threshold int) bool {
	return count > 0 && r.visible_end >= count - math.max(threshold, 0)
}

// range returns the items a viewport of the given size shows at a scroll
// offset, with overscan items more on each side so a fast scroll does not
// uncover empty space before the list is rebuilt. Offsets are clamped to the
// content, so a stale offset from before the list shrank still builds the
// items at its end.
pub fn (layout VirtualListLayout) range(viewport f64, offset f64, overscan int) VirtualListRange {
	total := layout.total()
	if layout.count == 0 {
		return VirtualListRange{
			before: total
			total:  total
		}
	}
	size := if component_finite(viewport) { math.max(viewport, 0) } else { 0.0 }
	wanted := if component_finite(offset) { offset } else { 0.0 }
	top := math.min(math.max(wanted, 0), layout.max_offset(size))
	visible_start := layout.first_ending_after(top)
	visible_end := math.max(layout.first_starting_from(top + size), visible_start)
	extra := math.max(overscan, 0)
	start := math.max(visible_start - extra, 0)
	end := math.min(visible_end + extra, layout.count)
	leading := layout.item_start(start)
	trailing := if end > start { total - layout.item_end(end - 1) } else { total - leading }
	return VirtualListRange{
		start:         start
		end:           end
		visible_start: visible_start
		visible_end:   visible_end
		before:        leading
		after:         trailing
		total:         total
	}
}

// scroll_offset_for is the scroll offset that brings the item at index into a
// viewport of the given size, aligned as asked; `current` is the offset now,
// which `.nearest` keeps when the item already shows in full. The result is
// clamped to the content. Pass it to scroll_to_offset (or, for a horizontal
// list, scroll_to_horizontal_offset).
pub fn (layout VirtualListLayout) scroll_offset_for(index int, viewport f64, current f64, align VirtualListAlign) f64 {
	if layout.count == 0 {
		return 0
	}
	size := math.max(viewport, 0)
	i := math.min(math.max(index, 0), layout.count - 1)
	start := layout.item_start(i)
	end := layout.item_end(i)
	// The first and last items take the padding along, so the content's edge
	// shows rather than stopping a few points short of it.
	lead := if i == 0 { 0.0 } else { start }
	trail := if i == layout.count - 1 { layout.total() } else { end }
	target := match align {
		.start {
			lead
		}
		.end {
			trail - size
		}
		.center {
			start + (end - start) / 2 - size / 2
		}
		.nearest {
			if lead < current || end - start > size {
				lead
			} else if trail > current + size {
				trail - size
			} else {
				current
			}
		}
	}
	return math.min(math.max(target, 0), layout.max_offset(size))
}

// index_after_key moves a highlight through a virtual list from on_key_event:
// Up and Down by one, Page Up and Page Down by a viewport, Home and End to the
// ends. It stops at the ends rather than wrapping, as a long list should, and
// starts from the first (or, going up, the last) item when nothing is
// highlighted (current -1). It returns none for other keys, keys with
// modifiers, and moves that go nowhere.
pub fn (layout VirtualListLayout) index_after_key(current int, viewport f64, event KeyEvent) ?int {
	if layout.count == 0 || event.cmd || event.ctrl || event.alt || event.shift {
		return none
	}
	last := layout.count - 1
	has := current >= 0 && current <= last
	target := match event.code {
		.down {
			if has { math.min(current + 1, last) } else { 0 }
		}
		.up {
			if has { math.max(current - 1, 0) } else { last }
		}
		.home {
			0
		}
		.end {
			last
		}
		.page_down {
			if has { layout.page_from(current, viewport, true) } else { 0 }
		}
		.page_up {
			if has { layout.page_from(current, viewport, false) } else { last }
		}
		else {
			return none
		}
	}
	return if target == current { none } else { target }
}

// page_from is the item a viewport's length away from index: the one at that
// position, or the next one over when an item is taller than the viewport.
fn (layout VirtualListLayout) page_from(index int, viewport f64, forward bool) int {
	size := math.max(viewport, 0)
	if forward {
		mut target := layout.index_at(layout.item_start(index) + size)
		if target <= index {
			target = index + 1
		}
		return math.min(target, layout.count - 1)
	}
	mut target := layout.index_at(math.max(layout.item_start(index) - size, 0))
	if target >= index {
		target = index - 1
	}
	return math.max(target, 0)
}

// VirtualListItemFn builds the item at index. frame is where it goes in the
// scrolled content: use it as the item's frame.
pub type VirtualListItemFn = fn (index int, frame Rect) Element

pub struct VirtualListConfig {
pub:
	id     string // The Scroll element's id: scroll_offset(id) reads its position.
	frame  Rect
	layout VirtualListLayout
	// offset is the scroll position the list is built for: store
	// scroll_offset(id) (scroll_horizontal_offset for a horizontal list) when
	// on_scroll reports the id, and rebuild when range() changes.
	offset              f64
	overscan            int               = 3
	orientation         LayoutOrientation = .vertical
	item                VirtualListItemFn = unsafe { nil }
	transparent         bool // Leave the background unpainted.
	accessibility_label string
	theme               ComponentTheme
}

// virtual_list_extent_key is the key of the spacer that gives the scroll its
// full extent, set apart from item keys.
const virtual_list_extent_key = 'virtual-list:extent'

// virtual_list builds a Scroll element as long as the whole list with only the
// items in layout.range around config.offset inside it, each keyed by its
// index so an item that stays in range keeps its native view while scrolling.
pub fn virtual_list(config VirtualListConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if voidptr(config.item) == unsafe { nil } {
		return error('virtual list `${config.id}` needs an item builder')
	}
	vertical := config.orientation == .vertical
	viewport := if vertical { config.frame.height } else { config.frame.width }
	layout := config.layout
	span := layout.range(viewport, config.offset, config.overscan)
	mut children := []Element{cap: span.len() + 1}
	children << Element{
		...view('', if vertical {
			rect(0, 0, 0, span.total)
		} else {
			rect(0, 0, span.total, 0)
		}, BoxStyle{ transparent: true }, []Element{})
		key: virtual_list_extent_key
	}
	for index in span.start .. span.end {
		start := layout.item_start(index)
		size := layout.item_size(index)
		frame := if vertical {
			rect(0, start, config.frame.width, size)
		} else {
			rect(start, 0, size, config.frame.height)
		}
		item := config.item(index, frame)
		children << Element{
			...item
			key: if item.key.len > 0 { item.key } else { 'item:${index}' }
		}
	}
	scroller := scroll_with_mode(config.id, config.frame, config.theme.background, if vertical {
		ScrollMode.vertical_only
	} else {
		ScrollMode.horizontal_only
	}, children)
	return component_finish(Element{
		...scroller
		box:                 BoxStyle{
			bg:          config.theme.background
			transparent: config.transparent
		}
		accessibility_role:  'list'
		accessibility_label: config.accessibility_label
	})
}
