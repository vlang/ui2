// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// A tab bar after GPUI Kit's TabBar and Tab (crates/component/src/tab/). The
// six variants with their per-size heights, paddings and gaps, the colors each
// one gives its normal, hovered, selected and disabled tabs, the sliding
// indicator of the segmented, pill and underline variants, and the folder
// tab's outline (rounded on top, curving out into the content at its foot)
// follow tab.rs and tab_bar.rs. The item model, layout, overflow scrolling and
// menu, keyboard navigation, dragging, vertical bars and rendering are new UI2
// code. See third_party/gpui-kit.
module ui2

import encoding.hex
import math

// TabVariant is how a tab bar draws its tabs, after GPUI Kit's TabVariant.
pub enum TabVariant {
	tab       // Tabs on a muted bar; the selected one takes the content's color and joins it.
	outline   // Rounded, outlined tabs; the selected one in the primary color.
	pill      // Rounded tabs; the selected one filled with the primary color.
	segmented // A segmented control: the selected tab raised on a muted track.
	underline // Text tabs over a line; the selected one underlined in the primary color.
	folder    // Folder index tabs, as in a web browser: the selected one rises into the content.
}

// TabBarPosition is where a tab bar sits against the content it switches: a
// bar on top or at the bottom lays its tabs out in a row, one on the left or
// right stacks them. The side facing the content is where the tab and folder
// variants join the selected tab to it and where the underline runs.
pub enum TabBarPosition {
	top
	bottom
	left
	right
}

// TabBarItem is one tab: a label, an optional leading icon, a trailing badge
// and a close button.
pub struct TabBarItem {
pub:
	id         string // Unique within the bar; the selection names tabs by it.
	label      string // Empty with an icon makes an icon-only tab.
	icon       string // A symbol drawn before the label; see symbol_known.
	badge      string // A count or short text drawn after the label.
	badge_tone ComponentTone = .neutral
	closable   bool // Draws a close button; tab_bar_update reports the press as `closed`.
	enabled    bool = true
	// action_id replaces the tab's own action, for applications that route each
	// tab to an action of their own. tab_bar_update does not see such a tab's
	// presses; hover and drag reports carry the action too.
	action_id           string
	tooltip             string // Defaults to the label of an icon-only or shortened tab.
	accessibility_label string // Defaults to the label.
}

// tab_bar_item is a tab with a label.
pub fn tab_bar_item(id string, caption string) TabBarItem {
	return TabBarItem{
		id:    id
		label: caption
	}
}

// TabBarDrag is a tab being dragged to a new place. Pointer positions are in
// window points, as pointer events report them.
pub struct TabBarDrag {
pub:
	tab     string // The tab pressed; empty when no press is under way.
	start_x f64
	start_y f64
	x       f64
	y       f64
	active  bool // The pointer moved far enough for the press to be a drag.
}

// TabBarState is a tab bar's controlled state. The application keeps it,
// passes it in, and stores what tab_bar_update and tab_bar_key return.
pub struct TabBarState {
pub:
	selected string            // The id of the selected tab; empty selects none.
	hovered  string            // The tab under the pointer.
	menu     DropdownMenuState // The tab menu (`menu: true`).
	drag     TabBarDrag
}

pub struct TabBarConfig {
pub:
	id       string
	frame    Rect // Size a horizontal bar with tab_bar_height.
	items    []TabBarItem
	state    TabBarState
	variant  TabVariant     = .tab
	position TabBarPosition = .top
	// align places tabs that do not fill the bar at its start, center or end.
	align BoxAlignment = .start
	// fill shares the bar's length among the tabs, as a segmented control
	// that spans its container does.
	fill bool
	// max_tab_width caps each tab; a longer label is shortened with an ellipsis
	// (the menu still shows it whole). Icon-only tabs keep their size.
	max_tab_width f64
	min_tab_width f64
	// prefix and suffix are application elements at the bar's ends, before
	// and after the tabs: back and forward buttons, an add button, a ⋯ menu.
	// Their frames are local to a slot prefix_size (suffix_size) long that
	// spans the bar's thickness.
	prefix      []Element
	prefix_size f64
	suffix      []Element
	suffix_size f64
	// menu adds a button after the tabs that lists all of them in a dropdown
	// menu; draw the menu with tab_bar_menu.
	menu bool
	// offset is how far the tabs are scrolled when they overflow the bar:
	// store scroll_horizontal_offset (scroll_offset for a vertical bar) of
	// tab_bar_scroll_id(id) when on_scroll reports it.
	offset f64
	// reorderable lets tabs be dragged to a new place; tab_bar_update reports
	// the move.
	reorderable bool
	// animate slides the indicator of the segmented, pill and underline
	// variants from the tab it left to the one selected.
	animate             bool = true
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// TabBarStep is what tab_bar_update or tab_bar_key did: the state to store,
// and what else the application has to do.
pub struct TabBarStep {
pub:
	state    TabBarState
	selected bool   // state.selected changed: show the content of that tab.
	closed   string // The tab whose close button was pressed: remove it (see tab_bar_after_close).
	// moved is set when a drag ended with the tab at `from` dropped at index
	// `to` (counted before it is taken out): reorder with tab_bar_reorder.
	moved bool
	from  int
	to    int
	// reveal is set when the selection moved: scroll the selected tab into
	// view with tab_bar_reveal_offset.
	reveal bool
}

// ── Ids and actions ─────────────────────────────────────────────────

pub fn tab_bar_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

// tab_bar_menu_id is the id of the bar's tab menu: the dropdown menu
// tab_bar_menu draws and its button toggles.
pub fn tab_bar_menu_id(id string) string {
	return component_part_id(id, 'menu')
}

// tab_bar_tab_action is the action a press on a tab emits.
pub fn tab_bar_tab_action(id string, tab_id string) string {
	return component_part_id(id, 'tab:' + tab_id.bytes().hex())
}

pub fn tab_bar_close_action(id string, tab_id string) string {
	return component_part_id(id, 'close:' + tab_id.bytes().hex())
}

fn tab_bar_indicator_id(id string) string {
	return component_part_id(id, 'indicator')
}

// tab_bar_hex_text decodes the lowercase hex the bar wrote into an action.
fn tab_bar_hex_text(digits string) ?string {
	if digits.len == 0 {
		return none
	}
	bytes := hex.decode(digits) or { return none }
	if bytes.hex() != digits {
		return none
	}
	return bytes.bytestr()
}

// tab_bar_action_tab decodes `<prefix><hex id>` from one of the bar's actions.
fn tab_bar_action_tab(id string, action string, prefix string) ?string {
	part := component_action_part(id, action)?
	if !part.starts_with(prefix) {
		return none
	}
	return tab_bar_hex_text(part[prefix.len..])
}

// ── Metrics ─────────────────────────────────────────────────────────

struct TabBarMetrics {
	bar        f64 // A horizontal bar's height, or a vertical bar's row height.
	font       f64
	small      f64 // Badge text.
	pad        f64 // Inside a tab, before and after its content.
	gap        f64 // Between the icon, label, badge and close button.
	spacing    f64 // Between tabs.
	inset      f64 // Around the tabs inside a segmented track.
	icon       f64
	close      f64
	radius     f64 // Tab corners; pills and outlines are fully rounded.
	track      f64 // The segmented track's corners.
	line       f64 // The underline and the selected underline.
	peek       f64 // How much of a neighbor stays in view when a tab is revealed.
	folder_top f64 // Bar space above folder tabs.
	curve      f64 // The folder tab's corner and foot curves.
	divider    f64 // The length of the separators between folder tabs.
	more       f64 // The menu button's side.
}

fn tab_bar_size_index(size ComponentSize) int {
	return match size {
		.small { 0 }
		.medium { 1 }
		.large { 2 }
	}
}

fn tab_bar_metrics(variant TabVariant, size ComponentSize, horizontal bool) TabBarMetrics {
	m := component_metrics(size)
	i := tab_bar_size_index(size)
	folder_top := [4.0, 4, 8][i]
	bar := if !horizontal {
		m.height
	} else {
		match variant {
			.underline { m.height + 4 }
			.folder { m.height + folder_top }
			else { m.height }
		}
	}
	pad := match variant {
		.underline {
			if horizontal { 0.0 } else { [10.0, 12, 16][i] }
		}
		.folder { [8.0, 12, 16][i] }
		else { [10.0, 12, 16][i] }
	}
	spacing := if horizontal {
		match variant {
			.tab { 0.0 }
			.outline { [8.0, 12, 16][i] }
			.pill { 4.0 }
			.segmented { 2.0 }
			.underline { [12.0, 16, 20][i] }
			.folder { 4.0 }
		}
	} else {
		match variant {
			.tab, .underline { 0.0 }
			.outline { 6.0 }
			else { 2.0 }
		}
	}
	return TabBarMetrics{
		bar:        bar
		font:       m.font_size
		small:      m.font_size - 2
		pad:        pad
		gap:        m.gap
		spacing:    spacing
		inset:      if variant == .segmented { [3.0, 4, 4][i] } else { 0.0 }
		icon:       math.round(m.font_size * 1.15)
		close:      math.round(m.font_size + 4)
		radius:     m.radius
		track:      m.radius + 2
		line:       2
		peek:       [24.0, 32, 40][i]
		folder_top: folder_top
		curve:      math.min(m.radius + 2, math.floor((bar - folder_top) / 3))
		divider:    [12.0, 16, 16][i]
		more:       m.height
	}
}

// tab_bar_height is how tall a horizontal tab bar of the variant and size
// is drawn: size its frame with it.
pub fn tab_bar_height(variant TabVariant, size ComponentSize) f64 {
	return tab_bar_metrics(variant, size, true).bar
}

fn tab_bar_horizontal(position TabBarPosition) bool {
	return position in [.top, .bottom]
}

// ── Layout ──────────────────────────────────────────────────────────

// TabBarLayout is where a tab bar puts its parts, all in the bar's own
// coordinates except the tabs, which are in the coordinates of the strip they
// scroll in.
pub struct TabBarLayout {
pub:
	horizontal bool
	strip      Rect   // The part of the bar the tabs show (and scroll) in.
	tabs       []Rect // Each tab, in the strip's content coordinates.
	length     f64    // How long the strip's content is along the bar.
	scrolls    bool   // The tabs are longer than the strip, which scrolls them.
	prefix     Rect
	suffix     Rect
	more       Rect // The menu button; zero size without one.
}

// TabPieces is where a tab's icon, label, badge and close button go, local
// to the tab.
struct TabPieces {
	icon        Rect
	label       Rect
	badge       Rect
	close       Rect
	label_width f64 // How wide the label wants to be.
}

fn tab_bar_label_style(m TabBarMetrics) TextStyle {
	return TextStyle{
		size: m.font
	}
}

fn tab_bar_badge_width(text string, m TabBarMetrics) f64 {
	if text.len == 0 {
		return 0
	}
	return math.ceil(measure_text_width(text, TextStyle{ size: m.small }) + m.small * 0.6 + 4)
}

fn tab_bar_badge_height(m TabBarMetrics) f64 {
	return math.round(m.small + 6)
}

fn tab_bar_icon_only(item TabBarItem) bool {
	return item.label.len == 0 && item.icon.len > 0
}

// tab_bar_content_width is how long a tab's icon, label, badge and close
// button are side by side, padding excluded.
fn tab_bar_content_width(item TabBarItem, m TabBarMetrics) f64 {
	mut parts := []f64{}
	if item.icon.len > 0 {
		parts << m.icon
	}
	if item.label.len > 0 {
		parts << math.ceil(measure_text_width(item.label, tab_bar_label_style(m)))
	}
	if item.badge.len > 0 {
		parts << tab_bar_badge_width(item.badge, m)
	}
	if item.closable {
		parts << m.close
	}
	mut total := 0.0
	for index, part in parts {
		total += part
		if index > 0 {
			total += m.gap
		}
	}
	return total
}

// tab_bar_natural_length is how long a tab wants to be along a horizontal
// bar, or how tall in a vertical one.
fn tab_bar_natural_length(config TabBarConfig, item TabBarItem, m TabBarMetrics, horizontal bool, thickness f64) f64 {
	if !horizontal {
		return m.bar
	}
	if tab_bar_icon_only(item) && !item.closable && item.badge.len == 0 {
		return if config.variant == .underline {
			m.icon + 8
		} else {
			math.round(math.max(thickness * 1.15, m.icon + 2 * m.gap))
		}
	}
	mut length := tab_bar_content_width(item, m) + 2 * m.pad
	if config.max_tab_width > 0 && !tab_bar_icon_only(item) {
		length = math.min(length, config.max_tab_width)
	}
	if config.min_tab_width > 0 {
		length = math.max(length, config.min_tab_width)
	}
	return math.ceil(length)
}

// tab_bar_lead is how far the first tab sits from the strip's start: inside
// a segmented track, and clear of the folder tab's curves.
fn tab_bar_lead(variant TabVariant, m TabBarMetrics) f64 {
	return match variant {
		.segmented { m.inset }
		.folder { m.curve }
		else { 0.0 }
	}
}

fn tab_bar_validate(config TabBarConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	mut ids := map[string]bool{}
	for item in config.items {
		if item.id.trim_space().len == 0 || item.id in ids {
			return error('tab bar `${config.id}` needs unique, non-empty tab ids')
		}
		ids[item.id] = true
		if item.label.len == 0 && item.icon.len == 0 {
			return error('tab `${item.id}` needs a label or an icon')
		}
		if item.icon.len > 0 && !symbol_known(item.icon) {
			return error('tab `${item.id}` uses `${item.icon}`, which not every renderer can draw; pick a name from symbol_names()')
		}
	}
	for value in [config.max_tab_width, config.min_tab_width, config.prefix_size, config.suffix_size,
		config.offset] {
		if !component_finite(value) || value < 0 {
			return error('tab bar sizes and offset must be finite and non-negative')
		}
	}
}

// tab_bar_layout places a tab bar's prefix, tabs, menu button and suffix,
// and says whether its tabs overflow the strip and scroll.
pub fn tab_bar_layout(config TabBarConfig) !TabBarLayout {
	tab_bar_validate(config)!
	horizontal := tab_bar_horizontal(config.position)
	m := tab_bar_metrics(config.variant, config.size, horizontal)
	length := if horizontal { config.frame.width } else { config.frame.height }
	thickness := if horizontal { config.frame.height } else { config.frame.width }
	// The strip sits inside the segmented track; folder tabs leave the bar's
	// top space above them.
	strip_across := math.min(m.inset, thickness / 2)
	strip_thickness := thickness - 2 * strip_across
	tab_across := if config.variant == .folder {
		math.min(m.folder_top, strip_thickness)
	} else {
		0.0
	}
	tab_thickness := strip_thickness - tab_across
	prefix := math.min(config.prefix_size, length)
	suffix := math.min(config.suffix_size, math.max(length - prefix, 0))
	more := if config.menu { math.min(m.more, math.max(length - prefix - suffix, 0)) } else { 0.0 }
	gap := m.gap
	start := if prefix > 0 { prefix + gap } else { 0.0 }
	end := math.max(length - suffix - more - if suffix > 0 || more > 0 { gap } else { 0.0 },
		start)
	strip_length := end - start
	lead := tab_bar_lead(config.variant, m)
	mut lengths := []f64{cap: config.items.len}
	for item in config.items {
		lengths << tab_bar_natural_length(config, item, m, horizontal, tab_thickness)
	}
	count := config.items.len
	spacing_total := if count > 1 { m.spacing * f64(count - 1) } else { 0.0 }
	mut natural := spacing_total
	for value in lengths {
		natural += value
	}
	available := math.max(strip_length - 2 * lead, 0)
	if horizontal && config.fill && count > 0 && natural < available {
		equal := (available - spacing_total) / f64(count)
		mut widest := 0.0
		for value in lengths {
			widest = math.max(widest, value)
		}
		extra := (available - natural) / f64(count)
		for i in 0 .. count {
			lengths[i] = if widest <= equal { equal } else { lengths[i] + extra }
		}
		natural = available
	}
	if !horizontal && count > 0 {
		// A vertical bar's tabs span its width.
		natural = spacing_total + m.bar * f64(count)
	}
	content := natural + 2 * lead
	scrolls := content > strip_length + 0.5
	shift := if scrolls {
		0.0
	} else {
		match config.align {
			.start { 0.0 }
			.center { math.round((strip_length - content) / 2) }
			.end { strip_length - content }
		}
	}
	mut tabs := []Rect{cap: count}
	mut cursor := lead + shift
	for value in lengths {
		tabs << tab_bar_place(config.position, cursor, tab_across, value, tab_thickness,
			strip_thickness)
		cursor += value + m.spacing
	}
	return TabBarLayout{
		horizontal: horizontal
		strip:      tab_bar_place(config.position, start, strip_across, strip_length, strip_thickness,
			thickness)
		tabs:       tabs
		length:     math.max(content, strip_length)
		scrolls:    scrolls
		prefix:     tab_bar_place(config.position, 0, 0, prefix, thickness, thickness)
		suffix:     tab_bar_place(config.position, length - suffix, 0, suffix, thickness,
			thickness)
		more:       tab_bar_place(config.position, length - suffix - more, 0, more, thickness,
			thickness)
	}
}

// tab_bar_place turns a span `along` the bar and `across` it, measured from
// the bar's far side (the one away from the content), into a rectangle.
fn tab_bar_place(position TabBarPosition, along f64, across f64, along_length f64, across_length f64, thickness f64) Rect {
	return match position {
		.top { rect(along, across, along_length, across_length) }
		.bottom { rect(along, thickness - across - across_length, along_length, across_length) }
		.left { rect(across, along, across_length, along_length) }
		.right { rect(thickness - across - across_length, along, across_length, along_length) }
	}
}

fn tab_bar_along(r Rect, horizontal bool) (f64, f64) {
	return if horizontal { r.x, r.width } else { r.y, r.height }
}

// tab_bar_pieces lays a tab's content out: in a horizontal tab centered (the
// close button at the end), in a vertical one from the start.
fn tab_bar_pieces(item TabBarItem, frame Rect, m TabBarMetrics, horizontal bool) TabPieces {
	width := frame.width
	height := frame.height
	label_width := if item.label.len > 0 {
		math.ceil(measure_text_width(item.label, tab_bar_label_style(m)))
	} else {
		0.0
	}
	badge_width := tab_bar_badge_width(item.badge, m)
	badge_height := tab_bar_badge_height(m)
	icon_y := math.round((height - m.icon) / 2)
	if tab_bar_icon_only(item) && !item.closable && item.badge.len == 0 {
		return TabPieces{
			icon: rect(math.round((width - m.icon) / 2), icon_y, m.icon, m.icon)
		}
	}
	close := if item.closable {
		rect(width - m.pad - m.close + if horizontal { m.gap / 2 } else { 0.0 }, math.round((height - m.close) / 2),
			m.close, m.close)
	} else {
		Rect{}
	}
	right := if item.closable { close.x - m.gap } else { width - m.pad }
	mut group := 0.0
	if item.icon.len > 0 {
		group += m.icon
	}
	if item.label.len > 0 {
		group += (if group > 0 { m.gap } else { 0.0 }) + label_width
	}
	if item.badge.len > 0 {
		group += (if group > 0 { m.gap } else { 0.0 }) + badge_width
	}
	room := math.max(right - m.pad, 0)
	mut x := if horizontal && group < room {
		m.pad + math.round((room - group) / 2)
	} else {
		m.pad
	}
	mut icon := Rect{}
	if item.icon.len > 0 {
		icon = rect(x, icon_y, m.icon, m.icon)
		x += m.icon + m.gap
	}
	badge_space := if item.badge.len > 0 { badge_width + m.gap } else { 0.0 }
	mut label_frame := Rect{}
	if item.label.len > 0 {
		shown := math.max(math.min(label_width, right - x - badge_space), 0)
		label_frame = rect(x, 0, shown, height)
		x += shown + m.gap
	}
	mut badge_frame := Rect{}
	if item.badge.len > 0 {
		badge_frame = rect(math.min(x, math.max(right - badge_width, 0)), math.round((height - badge_height) / 2),
			badge_width, badge_height)
	}
	return TabPieces{
		icon:        icon
		label:       label_frame
		badge:       badge_frame
		close:       close
		label_width: label_width
	}
}

// tab_bar_index is the position of a tab in the bar, or -1.
fn tab_bar_index(items []TabBarItem, tab_id string) int {
	for index, item in items {
		if item.id == tab_id {
			return index
		}
	}
	return -1
}

// ── Dragging ────────────────────────────────────────────────────────

const tab_bar_drag_threshold = 4.0

fn (drag TabBarDrag) delta(horizontal bool) f64 {
	return if horizontal { drag.x - drag.start_x } else { drag.y - drag.start_y }
}

// tab_bar_drop_index is where a tab dragged `delta` along the bar from its
// place lands: the index it takes once moved, counted among the other tabs.
pub fn tab_bar_drop_index(layout TabBarLayout, from int, delta f64) int {
	if from < 0 || from >= layout.tabs.len {
		return from
	}
	start, size := tab_bar_along(layout.tabs[from], layout.horizontal)
	center := start + size / 2 + delta
	mut to := 0
	for index, tab in layout.tabs {
		if index == from {
			continue
		}
		other_start, other_size := tab_bar_along(tab, layout.horizontal)
		if center > other_start + other_size / 2 {
			to++
		}
	}
	return to
}

// tab_bar_drag_offsets is how far each tab is drawn from its place while one
// is dragged: the dragged tab follows the pointer, and the tabs it passes make
// room for it.
fn tab_bar_drag_offsets(config TabBarConfig, layout TabBarLayout, m TabBarMetrics) []f64 {
	mut offsets := []f64{len: layout.tabs.len}
	drag := config.state.drag
	if !drag.active {
		return offsets
	}
	from := tab_bar_index(config.items, drag.tab)
	if from < 0 {
		return offsets
	}
	start, size := tab_bar_along(layout.tabs[from], layout.horizontal)
	// The dragged tab stays within the strip's content.
	lowest := -start
	highest := layout.length - start - size
	delta := math.min(math.max(drag.delta(layout.horizontal), lowest), highest)
	offsets[from] = delta
	to := tab_bar_drop_index(layout, from, delta)
	room := size + m.spacing
	for index in 0 .. layout.tabs.len {
		if index == from {
			continue
		}
		if index > from && index <= to {
			offsets[index] = -room
		} else if index < from && index >= to {
			offsets[index] = room
		}
	}
	return offsets
}

// tab_bar_reorder moves the item at from to index to, the way a drag the bar
// reported as moved arranges the tabs.
pub fn tab_bar_reorder[T](items []T, from int, to int) []T {
	if from < 0 || from >= items.len || to < 0 || to >= items.len || from == to {
		return items.clone()
	}
	mut out := items.clone()
	moved := out[from]
	out.delete(from)
	out.insert(to, moved)
	return out
}

// ── Events ──────────────────────────────────────────────────────────

fn tab_bar_selectable(config TabBarConfig, tab_id string) ?TabBarItem {
	index := tab_bar_index(config.items, tab_id)
	if index < 0 || !config.items[index].enabled {
		return none
	}
	return config.items[index]
}

fn tab_bar_select_step(config TabBarConfig, tab_id string) ?TabBarStep {
	tab_bar_selectable(config, tab_id)?
	if tab_id == config.state.selected {
		return none
	}
	return TabBarStep{
		state:    TabBarState{
			...config.state
			selected: tab_id
			menu:     DropdownMenuState{}
		}
		selected: true
		reveal:   true
	}
}

// tab_bar_menu_items lists the bar's tabs as rows of its menu, the selected
// one checked.
pub fn tab_bar_menu_items(config TabBarConfig) []DropdownMenuItem {
	mut rows := []DropdownMenuItem{cap: config.items.len}
	for item in config.items {
		rows << DropdownMenuItem{
			id:      item.id
			label:   if item.label.len > 0 {
				item.label
			} else if item.accessibility_label.len > 0 {
				item.accessibility_label
			} else {
				item.id
			}
			kind:    .checkbox
			icon:    item.icon
			checked: item.id == config.state.selected
			enabled: item.enabled
		}
	}
	return rows
}

fn tab_bar_menu_step(config TabBarConfig, step DropdownMenuStep) TabBarStep {
	if step.chosen {
		if next := tab_bar_select_step(config, step.item.id) {
			return next
		}
	}
	return TabBarStep{
		state: TabBarState{
			...config.state
			menu: step.state
		}
	}
}

// tab_bar_update applies an event from on_event to a tab bar: a press on a
// tab (selects it), on a close button (reports `closed`), on the menu button
// and in the menu, the pointer entering or leaving a tab (hovered), and the
// pointer phases of a drag (`moved` when one ends somewhere new). It returns
// none for events that are not the bar's, malformed or forged ones, disabled
// tabs, and presses that change nothing.
pub fn tab_bar_update(config TabBarConfig, event string) ?TabBarStep {
	if config.menu {
		if step := dropdown_menu_update(tab_bar_menu_id(config.id), tab_bar_menu_items(config),
			config.state.menu, event)
		{
			return tab_bar_menu_step(config, step)
		}
	}
	if pointer := parse_pointer_event(event) {
		return tab_bar_pointer(config, pointer)
	}
	if tab_id := tab_bar_action_tab(config.id, event, 'tab:') {
		return tab_bar_select_step(config, tab_id)
	}
	if tab_id := tab_bar_action_tab(config.id, event, 'close:') {
		item := tab_bar_selectable(config, tab_id)?
		if !item.closable {
			return none
		}
		return TabBarStep{
			state:  TabBarState{
				...config.state
				hovered: if config.state.hovered == tab_id { '' } else { config.state.hovered }
			}
			closed: tab_id
		}
	}
	return none
}

fn tab_bar_pointer(config TabBarConfig, pointer PointerEvent) ?TabBarStep {
	tab_id := tab_bar_action_tab(config.id, pointer.action, 'tab:')?
	tab_bar_selectable(config, tab_id)?
	now := config.state
	match pointer.phase {
		'enter' {
			if now.hovered == tab_id {
				return none
			}
			return TabBarStep{
				state: TabBarState{
					...now
					hovered: tab_id
				}
			}
		}
		'leave' {
			if now.hovered != tab_id {
				return none
			}
			return TabBarStep{
				state: TabBarState{
					...now
					hovered: ''
				}
			}
		}
		'down' {
			if !config.reorderable || !component_finite(pointer.x) || !component_finite(pointer.y) {
				return none
			}
			return TabBarStep{
				state: TabBarState{
					...now
					drag: TabBarDrag{
						tab:     tab_id
						start_x: pointer.x
						start_y: pointer.y
						x:       pointer.x
						y:       pointer.y
					}
				}
			}
		}
		'drag' {
			if !config.reorderable || now.drag.tab != tab_id || !component_finite(pointer.x)
				|| !component_finite(pointer.y) {
				return none
			}
			dx := pointer.x - now.drag.start_x
			dy := pointer.y - now.drag.start_y
			return TabBarStep{
				state: TabBarState{
					...now
					drag: TabBarDrag{
						...now.drag
						x:      pointer.x
						y:      pointer.y
						active: now.drag.active || dx * dx + dy * dy > tab_bar_drag_threshold * tab_bar_drag_threshold
					}
				}
			}
		}
		'up' {
			if now.drag.tab != tab_id {
				return none
			}
			ended := TabBarState{
				...now
				drag: TabBarDrag{}
			}
			if !now.drag.active {
				return TabBarStep{
					state: ended
				}
			}
			layout := tab_bar_layout(config) or { return none }
			from := tab_bar_index(config.items, tab_id)
			moved_drag := TabBarDrag{
				...now.drag
				x: if component_finite(pointer.x) { pointer.x } else { now.drag.x }
				y: if component_finite(pointer.y) { pointer.y } else { now.drag.y }
			}
			to := tab_bar_drop_index(layout, from, moved_drag.delta(layout.horizontal))
			return TabBarStep{
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

// tab_bar_neighbor is the enabled tab `step` places from index, wrapping
// around, or -1 when there is none.
fn tab_bar_neighbor(items []TabBarItem, index int, step int) int {
	count := items.len
	if count == 0 {
		return -1
	}
	mut at := index
	for _ in 0 .. count {
		at = if at < 0 && step < 0 { count - 1 } else { (at + step + count) % count }
		if items[at].enabled {
			return at
		}
	}
	return -1
}

fn tab_bar_edge(items []TabBarItem, last bool) int {
	if last {
		for index := items.len - 1; index >= 0; index-- {
			if items[index].enabled {
				return index
			}
		}
		return -1
	}
	for index, item in items {
		if item.enabled {
			return index
		}
	}
	return -1
}

// tab_bar_key moves a tab bar's selection from on_key_event: the arrow keys
// along the bar (Left and Right, or Up and Down for a vertical one) to the
// previous or next enabled tab, wrapping around; Home and End to the first
// and last; Ctrl+Tab and Ctrl+Shift+Tab to the next and previous in any bar.
// While the tab menu is open the keys move through the menu instead. It
// returns none for other keys and moves that change nothing; consume the key
// otherwise.
pub fn tab_bar_key(config TabBarConfig, event KeyEvent) ?TabBarStep {
	if config.menu && config.state.menu.open {
		step := dropdown_menu_key(tab_bar_menu_items(config), config.state.menu, event)?
		return tab_bar_menu_step(config, step)
	}
	horizontal := tab_bar_horizontal(config.position)
	current := tab_bar_index(config.items, config.state.selected)
	target := match event.code {
		.tab {
			if !event.ctrl || event.cmd || event.alt {
				return none
			}
			tab_bar_neighbor(config.items, current, if event.shift { -1 } else { 1 })
		}
		.left, .right, .up, .down {
			if event.cmd || event.ctrl || event.alt || event.shift {
				return none
			}
			if horizontal != (event.code in [.left, .right]) {
				return none
			}
			tab_bar_neighbor(config.items, current, if event.code in [.left, .up] { -1 } else { 1 })
		}
		.home, .end {
			if event.cmd || event.ctrl || event.alt || event.shift {
				return none
			}
			tab_bar_edge(config.items, event.code == .end)
		}
		else {
			return none
		}
	}
	if target < 0 {
		return none
	}
	return tab_bar_select_step(config, config.items[target].id)
}

// tab_bar_after_close is the tab to select once `closed` is removed: the
// selection stays where it is unless it was the closed tab, which passes it
// to the next enabled tab, or the previous one at the end, as a browser does.
pub fn tab_bar_after_close(items []TabBarItem, selected string, closed string) string {
	if selected != closed {
		return selected
	}
	index := tab_bar_index(items, closed)
	if index < 0 {
		return ''
	}
	for next in index + 1 .. items.len {
		if items[next].enabled {
			return items[next].id
		}
	}
	for previous := index - 1; previous >= 0; previous-- {
		if items[previous].enabled {
			return items[previous].id
		}
	}
	return ''
}

// tab_bar_reveal_offset is the scroll offset of tab_bar_scroll_id(id) that
// shows a tab and part of the tabs beside it, so the strip visibly goes on,
// moving as little as it can from config.offset. The tab itself wins on a
// short bar. It returns none when the tabs do not scroll or the tab is not
// in the bar.
pub fn tab_bar_reveal_offset(config TabBarConfig, tab_id string) ?f64 {
	layout := tab_bar_layout(config) or { return none }
	index := tab_bar_index(config.items, tab_id)
	if !layout.scrolls || index < 0 {
		return none
	}
	m := tab_bar_metrics(config.variant, config.size, layout.horizontal)
	_, viewport := tab_bar_along(layout.strip, layout.horizontal)
	highest := math.max(layout.length - viewport, 0)
	start, size := tab_bar_along(layout.tabs[index], layout.horizontal)
	end := start + size
	want_start := if index > 0 {
		previous_start, previous_size := tab_bar_along(layout.tabs[index - 1], layout.horizontal)
		math.max(previous_start + previous_size - m.peek, previous_start)
	} else {
		0.0
	}
	want_end := if index < layout.tabs.len - 1 {
		next_start, next_size := tab_bar_along(layout.tabs[index + 1], layout.horizontal)
		math.min(next_start + m.peek, next_start + next_size)
	} else {
		layout.length
	}
	mut offset := math.min(math.max(config.offset, 0), highest)
	if want_end > offset + viewport {
		offset = want_end - viewport
	}
	if want_start < offset {
		offset = want_start
	}
	if end > offset + viewport {
		offset = end - viewport
	}
	if start < offset {
		offset = start
	}
	return math.min(math.max(offset, 0), highest)
}

// tab_bar_menu_anchor is the frame of the bar's menu button in the
// coordinates of the bar's parent: anchor tab_bar_menu to it (offset by where
// that parent is in the window).
pub fn tab_bar_menu_anchor(config TabBarConfig) Rect {
	layout := tab_bar_layout(config) or { return config.frame }
	return rect(config.frame.x + layout.more.x, config.frame.y + layout.more.y, layout.more.width,
		layout.more.height)
}

// tab_bar_menu draws the bar's tab menu, every tab with the selected one
// checked, below its button. Build it after everything it may cover; pass
// tab_bar_menu_anchor(config) (in window coordinates) and ui2.bounds().
pub fn tab_bar_menu(config TabBarConfig, anchor Rect, window Rect) !Element {
	return dropdown_menu(
		id:        tab_bar_menu_id(config.id)
		state:     config.state.menu
		items:     tab_bar_menu_items(config)
		anchor:    anchor
		window:    window
		align:     .end
		min_width: 160
		label:     if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			'Tabs'
		}
		size:      config.size
		theme:     config.theme
	)
}
