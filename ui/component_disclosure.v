module ui2

import math

// Disclosure components: the stack layout of `accordion` (GPUI Kit's
// Accordion) and the shared animation helpers the accordion and the carousel
// use. The carousel's viewport, controls and indicators live in
// component_disclosure_carousel.v. Both are new UI2 implementations of the
// documented GPUI Kit behavior.
//
// A ui2 view does not clip its children, so content that has to be revealed
// gradually sits in an anonymous or fitted `scroll`: a scroll always clips to
// its frame, and one whose content fits it has nothing to scroll and hands the
// wheel to the pane around it.

const disclosure_slide_duration = 0.22

// ── Animation helpers ───────────────────────────────────────────────

enum DisclosureProp {
	x
	y
	height
}

fn disclosure_release_animation(event AnimationEvent) {
	if event.kind == .complete {
		clear_animation(event.id)
	}
}

fn disclosure_target(prop DisclosureProp, value f64, duration f64) Animation {
	return match prop {
		.x { animation(duration: duration, transition: .out_cubic, x: value) }
		.y { animation(duration: duration, transition: .out_cubic, y: value) }
		.height { animation(duration: duration, transition: .out_cubic, height: value) }
	}
}

// disclosure_tween jumps the element to `from` and glides it to `to`, its
// declared value, after which the element returns to its declaration.
fn disclosure_tween(id string, prop DisclosureProp, from f64, to f64, duration f64) {
	if id.len == 0 || !component_finite(from) || !component_finite(to) || math.abs(from - to) < 0.5 {
		return
	}
	(disclosure_target(prop, from, 0) + disclosure_target(prop, to, duration)).with_event_handler(disclosure_release_animation).start(id)
}

// ── Accordion: stack layout ─────────────────────────────────────────

struct AccordionStackMetrics {
	title_height f64
	pad_x        f64
	pad_bottom   f64
	gap          f64
	font_size    f64
	icon_size    f64
	chevron_size f64
	radius       f64
}

fn accordion_stack_metrics(size ComponentSize) AccordionStackMetrics {
	return match size {
		.small { AccordionStackMetrics{32, 10, 8, 6, 13, 14, 12, 6} }
		.medium { AccordionStackMetrics{40, 12, 10, 8, 14, 16, 13, 8} }
		.large { AccordionStackMetrics{48, 16, 14, 10, 16, 18, 15, 10} }
	}
}

// AccordionStackLayout places a stacked accordion's items. Every rect is
// relative to the accordion.
pub struct AccordionStackLayout {
pub:
	height     f64    // what the items need, borders included
	items      []Rect // each item: its separator, title row and open panel
	titles     []Rect // the title rows
	panels     []Rect // the open panels; a closed item's panel has no height
	body_width f64    // the width an open item's content has
}

fn accordion_content_empty(content Element) bool {
	// Element{} is a screen with nothing in it: an item without content.
	return content.kind == .screen
}

// accordion_content_extent is how tall an item's content is: its content's
// frame is relative to the panel body, so it reaches to its own bottom edge.
fn accordion_content_extent(item AccordionItem) f64 {
	if accordion_content_empty(item.content) {
		return 0
	}
	extent := item.content.frame.y + item.content.frame.height
	return if component_finite(extent) && extent > 0 { extent } else { 0.0 }
}

// accordion_open_items is `open` as the accordion uses it: indices of
// existing items, ascending and without repeats, and only the first one
// unless the accordion allows several.
pub fn accordion_open_items(config AccordionConfig) []int {
	mut open := []int{}
	for index in config.open {
		if index >= 0 && index < config.items.len && index !in open {
			open << index
		}
	}
	open.sort()
	if !config.multiple && open.len > 1 {
		return [config.open.filter(it >= 0 && it < config.items.len)[0]]
	}
	return open
}

// accordion_stack_layout places the items of a stacked accordion: title rows
// of the size's height, each followed, when open, by a panel as tall as its
// content plus the bottom padding. The width is the frame's; the height is
// what the items need, whatever the frame's height.
pub fn accordion_stack_layout(config AccordionConfig) !AccordionStackLayout {
	component_validate_frame(config.frame)!
	m := accordion_stack_metrics(config.size)
	inset := if config.bordered { 1.0 } else { 0.0 }
	inner := math.max(0.0, config.frame.width - 2 * inset)
	open := accordion_open_items(config)
	mut items := []Rect{cap: config.items.len}
	mut titles := []Rect{cap: config.items.len}
	mut panels := []Rect{cap: config.items.len}
	mut y := inset
	for index, item in config.items {
		rule := if index > 0 { 1.0 } else { 0.0 }
		title := rect(inset, y + rule, inner, m.title_height)
		panel_height := if index in open {
			accordion_content_extent(item) + m.pad_bottom
		} else {
			0.0
		}
		titles << title
		panels << rect(inset, title.y + title.height, inner, panel_height)
		items << rect(inset, y, inner, rule + m.title_height + panel_height)
		y += rule + m.title_height + panel_height
	}
	return AccordionStackLayout{
		height:     if config.items.len == 0 { 0.0 } else { y + inset }
		items:      items
		titles:     titles
		panels:     panels
		body_width: math.max(0.0, inner - 2 * m.pad_x)
	}
}

// accordion_body_width is the width an open item's content can use in a
// stacked accordion `width` wide.
pub fn accordion_body_width(width f64, size ComponentSize, bordered bool) f64 {
	inset := if bordered { 2.0 } else { 0.0 }
	return math.max(0.0, width - inset - 2 * accordion_stack_metrics(size).pad_x)
}

pub fn accordion_item_action_id(id string, index int) string {
	return component_part_id(id, 'item:${index}')
}

pub fn accordion_panel_id(id string, index int) string {
	return component_part_id(id, 'panel:${index}')
}

fn accordion_item_enabled(config AccordionConfig, index int) bool {
	return config.enabled && index >= 0 && index < config.items.len && config.items[index].enabled
}

// accordion_toggled is the open set after the item at index is clicked: an
// open item closes, a closed one opens, and without `multiple` opening one
// closes the others. Every item may be closed, as upstream.
pub fn accordion_toggled(config AccordionConfig, index int) []int {
	open := accordion_open_items(config)
	if index < 0 || index >= config.items.len {
		return open
	}
	if index in open {
		return open.filter(it != index)
	}
	if !config.multiple {
		return [index]
	}
	mut next := open.clone()
	next << index
	next.sort()
	return next
}

fn accordion_stack(config AccordionConfig) !Element {
	component_validate_id(config.id)!
	layout := accordion_stack_layout(config)!
	m := accordion_stack_metrics(config.size)
	theme := config.theme
	open := accordion_open_items(config)
	height := if config.frame.height > 0 { config.frame.height } else { layout.height }
	mut children := []Element{cap: config.items.len + 2}
	if config.bordered && config.items.len > 0 {
		children << view(component_part_id(config.id, 'card'), rect(0, 0, config.frame.width,
			layout.height), BoxStyle{
			bg:     theme.border
			radius: m.radius
		}, []Element{})
		children << view(component_part_id(config.id, 'card-fill'), rect(1, 1, math.max(0.0,
			config.frame.width - 2), math.max(0.0, layout.height - 2)), BoxStyle{
			bg:     theme.background
			radius: math.max(0.0, m.radius - 1)
		}, []Element{})
	}
	for index, item in config.items {
		children << accordion_stack_item(config, layout, m, index, item, index in open)
	}
	return component_finish(Element{
		...view(config.id, rect(config.frame.x, config.frame.y, config.frame.width, height),
			BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}

fn accordion_row_corners(config AccordionConfig, index int, open bool) ChoiceCorners {
	if !config.bordered {
		return .none
	}
	first := index == 0
	last := index == config.items.len - 1 && !open
	return if first && last {
		.all
	} else if first {
		.start
	} else if last {
		.end
	} else {
		.none
	}
}

fn accordion_stack_item(config AccordionConfig, layout AccordionStackLayout, m AccordionStackMetrics, index int, item AccordionItem, open bool) Element {
	theme := config.theme
	frame := layout.items[index]
	title := layout.titles[index]
	panel := layout.panels[index]
	enabled := accordion_item_enabled(config, index)
	row := rect(0, title.y - frame.y, frame.width, title.height)
	mut parts := []Element{}
	if index > 0 {
		parts << view('', rect(0, 0, frame.width, 1), BoxStyle{ bg: theme.border }, []Element{})
	}
	parts << accordion_title_row(config, m, index, item, open, enabled, row)
	if open && panel.height > 0 && !accordion_content_empty(item.content) {
		content := Element{
			...item.content
			frame: rect(m.pad_x + item.content.frame.x, item.content.frame.y, item.content.frame.width,
				item.content.frame.height)
		}
		parts << Element{
			...scroll_with_mode(accordion_panel_id(config.id, index), rect(0, panel.y - frame.y,
				frame.width, panel.height), 0, .horizontal_only, [content])
			box:                 BoxStyle{
				transparent: true
			}
			accessibility_role:  'group'
			accessibility_label: item.title
		}
	}
	return Element{
		...view(component_part_id(config.id, 'section:${index}'), frame, BoxStyle{ transparent: true },
			parts)
		key: 'item:${index}'
	}
}

fn accordion_title_row(config AccordionConfig, m AccordionStackMetrics, index int, item AccordionItem, open bool, enabled bool, row Rect) Element {
	theme := config.theme
	local := rect(0, 0, row.width, row.height)
	text_color := if enabled { theme.foreground } else { choice_disabled_text(theme) }
	mut parts := []Element{}
	if enabled && config.hovered == index {
		r := math.max(0.0, m.radius - 1)
		parts << choice_shape(local, r, theme.muted, accordion_row_corners(config, index, open),
			true)
	}
	mut x := m.pad_x
	if item.icon.len > 0 {
		parts << choice_icon(item.icon, rect(x, (row.height - m.icon_size) / 2, m.icon_size,
			m.icon_size), text_color)
		x += m.icon_size + m.gap
	}
	chevron_room := if enabled { m.chevron_size + m.gap } else { 0.0 }
	parts << label('', item.title, rect(x, 0, math.max(0.0, row.width - x - m.pad_x - chevron_room),
		row.height), TextStyle{
		color: text_color
		size:  m.font_size
	})
	if enabled {
		// Upstream turns a chevron half a turn. A symbol image does not rotate on
		// every renderer, so the open item shows the chevron that points up.
		parts << choice_icon(if open { 'chevron.up' } else { 'chevron.down' }, rect(row.width - m.pad_x - m.chevron_size,
			(row.height - m.chevron_size) / 2, m.chevron_size, m.chevron_size), theme.muted_foreground)
	}
	if enabled && config.focused == index && row.width > 6 && row.height > 6 {
		ring := rect(2, 2, row.width - 4, row.height - 4)
		parts << shape(component_part_id(config.id, 'focus:${index}'), ring, path_rounded_rect(rect(1,
			1, ring.width - 2, ring.height - 2), math.max(2.0, m.radius - 3)), ShapeStyle{
			stroke:       theme.primary
			stroke_width: 2
		})
	}
	value := if open { 'expanded' } else { 'collapsed' }
	if !enabled {
		return Element{
			...view('', row, BoxStyle{ transparent: true }, parts)
			enabled:             false
			accessibility_role:  'button'
			accessibility_label: item.title
			accessibility_value: value
		}
	}
	return Element{
		...button_view(accordion_item_action_id(config.id, index), row, BoxStyle{ transparent: true },
			parts)
		hoverable:           true
		accessibility_label: item.title
		accessibility_value: value
	}
}

// ── Accordion: decoding ─────────────────────────────────────────────

fn accordion_action_index(config AccordionConfig, action string) ?int {
	if config.layout != .stack || config.items.len == 0 {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	if !part.starts_with('item:') {
		return none
	}
	return component_parse_index(part['item:'.len..], config.items.len - 1)
}

// accordion_open_from_action returns the open items after a click on a title
// row, like upstream's on_toggle_click: pass the config the accordion was built
// with and store the result as `open`. It returns none for foreign, malformed
// or forged actions, disabled items, a disabled accordion and the fill layout.
pub fn accordion_open_from_action(config AccordionConfig, action string) ?[]int {
	index := accordion_action_index(config, action)?
	if !accordion_item_enabled(config, index) {
		return none
	}
	return accordion_toggled(config, index)
}

// accordion_hover_from_event returns the next `hovered` when the pointer
// enters or leaves a title row, and none for anything else or when hovered
// would not change.
pub fn accordion_hover_from_event(config AccordionConfig, event string) ?int {
	pointer := parse_pointer_event(event)?
	if pointer.phase !in ['enter', 'leave'] {
		return none
	}
	index := accordion_action_index(config, pointer.action)?
	next := if pointer.phase == 'enter' && accordion_item_enabled(config, index) {
		index
	} else if pointer.phase == 'leave' && config.hovered == index {
		-1
	} else {
		return none
	}
	return if next == config.hovered { none } else { next }
}

// accordion_focus_after_key moves the keyboard focus among the title rows as
// WAI-ARIA's accordion does: Down and Up go to the next and previous enabled
// row, wrapping, and Home and End to the first and last. Store the result as
// `focused`. Components cannot take focus, so call it while the application
// considers the accordion focused.
pub fn accordion_focus_after_key(config AccordionConfig, code KeyCode) ?int {
	if config.layout != .stack || !config.enabled {
		return none
	}
	enabled := []int{len: config.items.len, init: index}.filter(accordion_item_enabled(config,
		it))
	if enabled.len == 0 {
		return none
	}
	at := enabled.index(config.focused)
	next := match code {
		.down {
			if at < 0 { enabled[0] } else { enabled[(at + 1) % enabled.len] }
		}
		.up {
			if at < 0 { enabled.last() } else { enabled[(at + enabled.len - 1) % enabled.len] }
		}
		.home {
			enabled[0]
		}
		.end {
			enabled.last()
		}
		else {
			return none
		}
	}
	return if next == config.focused { none } else { next }
}

// accordion_open_after_key toggles the focused item on Enter or Space, the way
// a click on its title row does.
pub fn accordion_open_after_key(config AccordionConfig, code KeyCode) ?[]int {
	if config.layout != .stack || code !in [.enter, .kp_enter, .space]
		|| !accordion_item_enabled(config, config.focused) {
		return none
	}
	return accordion_toggled(config, config.focused)
}

// accordion_animate starts the animations that carry a stacked accordion from
// the state `before` describes to the one `after` does, usually just after
// accordion_open_from_action changed `open`: the items below a changed panel
// glide to their places, an opening panel unrolls from its title row, and the
// card grows or shrinks with them. A closing panel's content goes at once,
// since a closed item is not mounted. Call it before the rebuild; elements
// return to their declarations when the animations end.
pub fn accordion_animate(before AccordionConfig, after AccordionConfig) ! {
	if before.layout != .stack || after.layout != .stack || before.id != after.id
		|| before.items.len != after.items.len || after.id.len == 0 {
		return
	}
	from := accordion_stack_layout(before)!
	to := accordion_stack_layout(after)!
	for index in 0 .. after.items.len {
		disclosure_tween(component_part_id(after.id, 'section:${index}'), .y, from.items[index].y,
			to.items[index].y, disclosure_slide_duration)
		if to.panels[index].height > 0 {
			disclosure_tween(accordion_panel_id(after.id, index), .height, from.panels[index].height,
				to.panels[index].height, disclosure_slide_duration)
		}
	}
	if after.bordered && before.bordered {
		disclosure_tween(component_part_id(after.id, 'card'), .height, from.height, to.height,
			disclosure_slide_duration)
		disclosure_tween(component_part_id(after.id, 'card-fill'), .height, from.height - 2,
			to.height - 2, disclosure_slide_duration)
	}
}
