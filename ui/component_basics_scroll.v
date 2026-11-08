module ui2

import math

// scrollable is GPUI Kit's Scrollable on top of ui2's Scroll element: either
// axis or both, a padded content box that can stack its children in a column
// or a row, a border, and the scrollbar kept on screen or shown while
// scrolling. ScrollMetrics turns a position (ui2.scroll_offset and
// scroll_horizontal_offset, read in on_scroll) into where it stands, the
// offset that reveals some content, a page or a key press further on, or the
// end of a growing chat. scrollbar is a themed scrollbar of the application's
// own, for the hover and scrolling modes and colors the platform scrollers do
// not offer, kept in step with a pane through its offsets.

// ScrollbarMode is when a scrollbar shows, after GPUI Kit's theme setting.
pub enum ScrollbarMode {
	scrolling // While the content moves (or the bar is dragged), then it fades.
	hover     // While the pointer is over the scroll area.
	always    // Whenever the content overflows.
}

// ScrollableStack lays a scrollable's children out one after another.
pub enum ScrollableStack {
	none   // Children keep their frames, inside the padding.
	column // Top to bottom by their heights; a child without a width spans the pane.
	row    // Left to right by their widths; a child without a height spans the pane.
}

pub struct ScrollableConfig {
pub:
	id    string // Required; the Scroll element's id is scrollable_scroll_id(id).
	frame Rect
	axis  ScrollMode = .vertical_only
	// scrollbar .always keeps the platform's scroller on screen; .scrolling and
	// .hover use the overlay scroller, which AppKit shows while scrolling.
	scrollbar  ScrollbarMode = .scrolling
	padding    f64
	gap        f64
	stack      ScrollableStack
	bordered   bool
	background ?u32 // Defaults to the theme's background.
	children   []Element
	label      string // Accessibility label.
	size       ComponentSize = .medium
	theme      ComponentTheme
}

// scrollable_scroll_id is the id of a scrollable's Scroll element: what
// on_scroll reports and what scroll_offset, scroll_to_offset and their
// horizontal counterparts take.
pub fn scrollable_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

// scrollable_viewport is the pane a scrollable's content scrolls in, inside its
// border, in the scrollable's own coordinates.
pub fn scrollable_viewport(config ScrollableConfig) Rect {
	if config.bordered {
		return rect(1, 1, math.max(config.frame.width - 2, 0), math.max(config.frame.height - 2,
			0))
	}
	return component_local(config.frame)
}

// scrollable_layout places a scrollable's children in its content: stacked or
// as they are, inside the padding.
fn scrollable_layout(config ScrollableConfig) []Element {
	viewport := scrollable_viewport(config)
	pad := math.max(config.padding, 0)
	gap := math.max(config.gap, 0)
	mut placed := []Element{cap: config.children.len}
	mut cursor := pad
	for child in config.children {
		frame := match config.stack {
			.none {
				rect(child.frame.x + pad, child.frame.y + pad, child.frame.width, child.frame.height)
			}
			.column {
				rect(pad + child.frame.x, cursor, if child.frame.width > 0 {
					child.frame.width
				} else {
					math.max(viewport.width - 2 * pad - child.frame.x, 0)
				}, child.frame.height)
			}
			.row {
				rect(cursor, pad + child.frame.y, child.frame.width, if child.frame.height > 0 {
					child.frame.height
				} else {
					math.max(viewport.height - 2 * pad - child.frame.y, 0)
				})
			}
		}
		if !child.hidden {
			cursor = match config.stack {
				.column { frame.y + frame.height + gap }
				.row { frame.x + frame.width + gap }
				.none { cursor }
			}
		}
		placed << Element{
			...child
			frame: frame
		}
	}
	return placed
}

// scrollable_content_size is how far a scrollable's content reaches, its
// padding included: the extents scroll_offset ranges over.
pub fn scrollable_content_size(config ScrollableConfig) (f64, f64) {
	pad := math.max(config.padding, 0)
	mut width := 0.0
	mut height := 0.0
	for child in scrollable_layout(config) {
		if child.hidden {
			continue
		}
		width = math.max(width, child.frame.x + child.frame.width)
		height = math.max(height, child.frame.y + child.frame.height)
	}
	return width + pad, height + pad
}

// scrollable draws its children in a pane that scrolls along axis.
pub fn scrollable(config ScrollableConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	for value in [config.padding, config.gap] {
		if !component_finite(value) || value < 0 {
			return error('scrollable padding and gap must be finite and non-negative')
		}
	}
	metrics := component_metrics(config.size)
	viewport := scrollable_viewport(config)
	bg := config.background or { config.theme.background }
	mut content := scrollable_layout(config)
	width, height := scrollable_content_size(config)
	pad := math.max(config.padding, 0)
	if pad > 0 {
		// A spacer at the far corner carries the padding into the scroll range,
		// which reaches only as far as the children do.
		content << view('', rect(math.max(width - 1, 0), math.max(height - 1, 0), 1, 1),
			BoxStyle{ transparent: true }, []Element{})
	}
	pane := Element{
		...scroll_with_mode(scrollable_scroll_id(config.id), viewport, bg, config.axis, content)
		persistent_scrollbars: config.scrollbar == .always
		accessibility_label:   config.label
	}
	if !config.bordered {
		return component_finish(Element{
			...view(config.id, config.frame, BoxStyle{ transparent: true }, [
				Element{
					...pane
					frame: viewport
				},
			])
			accessibility_role: 'group'
		})
	}
	box, mut children := popover_panel(component_local(config.frame), bg, config.theme.border,
		metrics.radius, false)
	children << pane
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_role: 'group'
	})
}

// ScrollMetrics is a scroll position along one axis: the offset, how long the
// content is, and how much of it the pane shows.
pub struct ScrollMetrics {
pub:
	offset   f64
	content  f64
	viewport f64
}

// scroll_metrics builds a ScrollMetrics, treating negative or non-finite
// values as zero.
pub fn scroll_metrics(offset f64, content f64, viewport f64) ScrollMetrics {
	clean := fn (value f64) f64 {
		return if component_finite(value) && value > 0 { value } else { 0 }
	}
	return ScrollMetrics{clean(offset), clean(content), clean(viewport)}
}

// max_offset is the furthest the content scrolls.
pub fn (m ScrollMetrics) max_offset() f64 {
	return math.max(m.content - m.viewport, 0)
}

// clamp holds an offset inside the scroll range.
pub fn (m ScrollMetrics) clamp(offset f64) f64 {
	if !component_finite(offset) {
		return 0
	}
	return basics_clamp(offset, 0, m.max_offset())
}

// scrolls reports whether the content is longer than the pane.
pub fn (m ScrollMetrics) scrolls() bool {
	return m.max_offset() > 0.5
}

// at_start reports whether the pane shows the start of the content.
pub fn (m ScrollMetrics) at_start() bool {
	return m.offset <= 0.5
}

// at_end reports whether the pane shows the end of the content.
pub fn (m ScrollMetrics) at_end() bool {
	return m.offset >= m.max_offset() - 0.5
}

// progress is how far through the scroll range the offset is, 0 to 1; content
// that fits is at 0.
pub fn (m ScrollMetrics) progress() f64 {
	limit := m.max_offset()
	return if limit <= 0 { 0 } else { basics_clamp(m.offset / limit, 0, 1) }
}

// visible_fraction is how much of the content the pane shows, 0 to 1.
pub fn (m ScrollMetrics) visible_fraction() f64 {
	return if m.content <= 0 { 1 } else { basics_clamp(m.viewport / m.content, 0, 1) }
}

// reveal is the offset that brings the stretch `start`, `size` long, into the
// pane: at its start, center or end, or (.nearest) as little as needed, not at
// all when it already shows in full. Pass it to scroll_to_offset or
// scroll_to_horizontal_offset.
pub fn (m ScrollMetrics) reveal(start f64, size f64, align VirtualListAlign) f64 {
	length := math.max(size, 0)
	target := match align {
		.start {
			start
		}
		.center {
			start + length / 2 - m.viewport / 2
		}
		.end {
			start + length - m.viewport
		}
		.nearest {
			if start < m.offset || length > m.viewport {
				start
			} else if start + length > m.offset + m.viewport {
				start + length - m.viewport
			} else {
				m.offset
			}
		}
	}
	return m.clamp(target)
}

// page is the offset `pages` pages on (negative pages go back), a page being
// nine tenths of the pane so a line of context stays in view.
pub fn (m ScrollMetrics) page(pages f64) f64 {
	return m.clamp(m.offset + pages * m.viewport * 0.9)
}

// follow is the offset to keep once the content has grown (or shrunk) to
// `content`: the new end when the pane showed the end before, as a chat that
// follows new messages does, and the same offset otherwise.
pub fn (m ScrollMetrics) follow(content f64) f64 {
	next := scroll_metrics(m.offset, content, m.viewport)
	return if m.at_end() { next.max_offset() } else { next.clamp(m.offset) }
}

// scroll_key_offset is the offset a key press scrolls to: the arrows (up and
// down, or left and right when horizontal) by `line`, Page Up and Page Down
// and Space (Shift+Space back) by a page, Home and End (Command with the
// arrows on a Mac) to the ends. Other keys, and keys that would not move the
// content, decode to none. Call it from on_key_event while the pane has the
// keyboard, then consume the key.
pub fn scroll_key_offset(m ScrollMetrics, event KeyEvent, line f64, horizontal bool) ?f64 {
	if event.ctrl || event.alt {
		return none
	}
	step := if component_finite(line) && line > 0 { line } else { 40.0 }
	back, ahead := if horizontal {
		KeyCode.left, KeyCode.right
	} else {
		KeyCode.up, KeyCode.down
	}
	target := match true {
		event.code == back && event.cmd { 0.0 }
		event.code == ahead && event.cmd { m.max_offset() }
		event.cmd { return none }
		event.code == back { m.offset - step }
		event.code == ahead { m.offset + step }
		event.code == .page_up { m.offset - m.viewport * 0.9 }
		event.code == .page_down { m.offset + m.viewport * 0.9 }
		event.code == .space && event.shift { m.offset - m.viewport * 0.9 }
		event.code == .space { m.offset + m.viewport * 0.9 }
		event.code == .home { 0.0 }
		event.code == .end { m.max_offset() }
		else { return none }
	}
	clamped := m.clamp(target)
	if math.abs(clamped - m.offset) < 0.01 {
		return none
	}
	return clamped
}

pub struct ScrollbarConfig {
pub:
	id          string // Required: names the thumb, the track and the hover area.
	frame       Rect   // The bar's area; its length runs along orientation.
	orientation Orientation = .vertical
	offset      f64 // The pane's scroll offset along the bar's axis.
	content     f64 // How long the content is along that axis.
	viewport    f64 // How much of it the pane shows; zero takes the bar's length.
	mode        ScrollbarMode = .always
	// active shows a .scrolling bar while the content moves (set it on a scroll
	// and clear it with a timer) and a .hover bar while the pointer is over the
	// scroll area (with_hover on the area reports that).
	active    bool
	hovered   bool // The pointer is on the bar: a wider, stronger thumb (see scrollbar_step).
	dragging  bool // The thumb is held: it stays wide and the bar stays shown.
	min_thumb f64 = 24
	theme     ComponentTheme
}

fn scrollbar_length(config ScrollbarConfig) (f64, f64) {
	return if config.orientation == .vertical {
		config.frame.height, config.frame.width
	} else {
		config.frame.width, config.frame.height
	}
}

fn scrollbar_scroll(config ScrollbarConfig) ScrollMetrics {
	length, _ := scrollbar_length(config)
	return scroll_metrics(config.offset, config.content, if config.viewport > 0 {
		config.viewport
	} else {
		length
	})
}

// scrollbar_visible reports whether a scrollbar shows its thumb: the content
// must overflow, and the mode's condition hold (or the thumb be held or hovered).
pub fn scrollbar_visible(config ScrollbarConfig) bool {
	if !scrollbar_scroll(config).scrolls() {
		return false
	}
	return config.mode == .always || config.active || config.hovered || config.dragging
}

// scrollbar_thumb is the thumb's span along the bar: where it starts and how
// long it is, in the bar's own coordinates.
pub fn scrollbar_thumb(config ScrollbarConfig) (f64, f64) {
	length, _ := scrollbar_length(config)
	m := scrollbar_scroll(config)
	if length <= 0 || !m.scrolls() {
		return 0, math.max(length, 0)
	}
	thumb := math.min(length, math.max(length * m.visible_fraction(), math.max(config.min_thumb,
		1)))
	return (length - thumb) * m.progress(), thumb
}

// scrollbar draws a track and a thumb for a pane's position. Dragging the thumb
// and clicking the track either side of it emit events scrollbar_step turns
// into the offset to scroll the pane to.
pub fn scrollbar(config ScrollbarConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if !component_finite(config.offset) || !component_finite(config.content)
		|| !component_finite(config.viewport) || !component_finite(config.min_thumb) {
		return error('scrollbar offsets and sizes must be finite')
	}
	length, across := scrollbar_length(config)
	vertical := config.orientation == .vertical
	visible := scrollbar_visible(config)
	wide := config.hovered || config.dragging
	start, thumb := scrollbar_thumb(config)
	thickness := math.min(across, if wide { 10.0 } else { 6.0 })
	side := (across - thickness) / 2
	knob := popover_blend(config.theme.foreground, config.theme.background, if wide {
		0.35
	} else {
		0.55
	})
	track_color := popover_blend(config.theme.foreground, config.theme.background, 0.92)
	span := fn [vertical] (at f64, along f64, side f64, thick f64) Rect {
		return if vertical { rect(side, at, thick, along) } else { rect(at, side, along, thick) }
	}
	mut children := []Element{}
	if visible && wide {
		children << view('', span(0, length, side, thickness), BoxStyle{
			bg:     track_color
			radius: thickness / 2
		}, []Element{})
	}
	for part in ['page:back', 'page:forward'] {
		from := if part == 'page:back' { 0.0 } else { start + thumb }
		to := if part == 'page:back' { start } else { length }
		if to - from < 1 {
			continue
		}
		children << Element{
			...button_view(component_part_id(config.id, part), span(from, to - from, 0,
				across), BoxStyle{ transparent: true }, []Element{})
			enabled:             visible
			accessibility_label: if part == 'page:back' { 'Page back' } else { 'Page forward' }
		}
	}
	children << Element{
		...draggable_view(component_part_id(config.id, 'thumb'), span(start, thumb, side,
			thickness), BoxStyle{
			bg:     knob
			radius: thickness / 2
		}, []Element{})
		hidden:  !visible
		enabled: visible
	}
	m := scrollbar_scroll(config)
	return component_finish(Element{
		...view(component_part_id(config.id, 'bar'), config.frame, BoxStyle{ transparent: true },
			children)
		hoverable:           true
		accessibility_role:  'scrollbar'
		accessibility_value: '${int(math.round(m.progress() * 100))}%'
	})
}

// ScrollbarDrag is a thumb drag in progress: where the pointer pressed, along
// the bar's axis in window points, and the offset then.
pub struct ScrollbarDrag {
pub:
	active  bool
	pointer f64
	offset  f64
}

// ScrollbarStep is what a scrollbar event changes: the offset to scroll the
// pane to (unchanged when the event moves nothing), the drag, and whether the
// pointer is on the bar.
pub struct ScrollbarStep {
pub:
	offset  f64
	drag    ScrollbarDrag
	hovered bool
}

// scrollbar_step decodes an event of scrollbar config.id: a press, drag or
// release on the thumb, a click on the track before or after it (a page back
// or on), or the pointer entering or leaving the bar. Other events, and the
// drags of a press that never started, decode to none.
pub fn scrollbar_step(config ScrollbarConfig, drag ScrollbarDrag, event string) ?ScrollbarStep {
	m := scrollbar_scroll(config)
	keep := ScrollbarStep{
		offset:  m.clamp(config.offset)
		drag:    drag
		hovered: config.hovered
	}
	if part := component_action_part(config.id, event) {
		if part == 'page:back' || part == 'page:forward' {
			return ScrollbarStep{
				...keep
				offset: m.page(if part == 'page:back' { -1 } else { 1 })
			}
		}
		return none
	}
	pointer := parse_pointer_event(event) or { return none }
	part := component_action_part(config.id, pointer.action) or { return none }
	along := if config.orientation == .vertical { pointer.y } else { pointer.x }
	if part == 'bar' {
		if pointer.phase != 'enter' && pointer.phase != 'leave' {
			return none
		}
		return ScrollbarStep{
			...keep
			hovered: pointer.phase == 'enter'
		}
	}
	if part != 'thumb' {
		return none
	}
	match pointer.phase {
		'down' {
			return ScrollbarStep{
				...keep
				drag: ScrollbarDrag{
					active:  true
					pointer: along
					offset:  keep.offset
				}
			}
		}
		'drag' {
			if !drag.active {
				return none
			}
			length, _ := scrollbar_length(config)
			_, thumb := scrollbar_thumb(config)
			room := length - thumb
			if room <= 0 {
				return keep
			}
			return ScrollbarStep{
				...keep
				offset: m.clamp(drag.offset + (along - drag.pointer) * m.max_offset() / room)
			}
		}
		'up' {
			if !drag.active {
				return none
			}
			return ScrollbarStep{
				...keep
				drag: ScrollbarDrag{}
			}
		}
		else {
			return none
		}
	}
}
