// SPDX-License-Identifier: Apache-2.0
// Dropdown menus and dropdown buttons after GPUI Kit's PopupMenu and
// DropdownButton (Longbridge, copyright 2024 - 2026). Keyboard navigation
// follows crates/component/src/menu/popup_menu.rs: arrows skip separators,
// labels and disabled rows and wrap around, and a row the pointer leaves keeps
// its highlight when a key has moved it elsewhere. The state model, layout and
// rendering are new UI2 code. See third_party/gpui-kit.
module ui2

import math

// DropdownMenuItemKind is what a row of a dropdown menu is.
pub enum DropdownMenuItemKind {
	item      // Emits its id when chosen.
	checkbox  // Shows a check mark when checked.
	radio     // Shows a dot when checked; the application keeps one per group checked.
	separator // A divider between groups.
	label     // A heading over a group; not selectable.
	submenu   // Opens `items` beside it.
}

// DropdownMenuItem is one row of a menu drawn inside the window. Unlike
// MenuItem (menu bar and tray, drawn by the system) and MenuEntry (an element's
// native right-click menu), it can carry icons, radio rows, group labels and
// custom content, and it looks the same on every backend.
pub struct DropdownMenuItem {
pub:
	id       string // Emitted when chosen; unique among the menu's choosable rows.
	label    string
	kind     DropdownMenuItemKind = .item
	icon     string // A symbol name, drawn as `symbol:<icon>`.
	shortcut string // An accelerator such as 'cmd+c', shown as ⌘C on macOS and Ctrl+C elsewhere.
	checked  bool
	enabled  bool = true
	items    []DropdownMenuItem // The rows of a submenu.
	children []Element          // Custom row content, drawn in place of the label.
	height   f64                // Row height for custom content; zero means the default.
}

pub fn dropdown_menu_item(id string, caption string) DropdownMenuItem {
	return DropdownMenuItem{
		id:    id
		label: caption
	}
}

pub fn dropdown_menu_checkbox(id string, caption string, checked bool) DropdownMenuItem {
	return DropdownMenuItem{
		id:      id
		label:   caption
		kind:    .checkbox
		checked: checked
	}
}

pub fn dropdown_menu_radio(id string, caption string, checked bool) DropdownMenuItem {
	return DropdownMenuItem{
		id:      id
		label:   caption
		kind:    .radio
		checked: checked
	}
}

pub fn dropdown_menu_separator() DropdownMenuItem {
	return DropdownMenuItem{
		kind: .separator
	}
}

pub fn dropdown_menu_heading(caption string) DropdownMenuItem {
	return DropdownMenuItem{
		label: caption
		kind:  .label
	}
}

pub fn dropdown_menu_submenu(caption string, items []DropdownMenuItem) DropdownMenuItem {
	return DropdownMenuItem{
		label: caption
		kind:  .submenu
		items: items
	}
}

// dropdown_menu_items_from_menu reuses rows declared for the menu bar or the
// tray in a dropdown menu: titles, shortcuts, check marks, disabled rows,
// separators and submenus carry over.
pub fn dropdown_menu_items_from_menu(items []MenuItem) []DropdownMenuItem {
	mut rows := []DropdownMenuItem{cap: items.len}
	for item in items {
		if item.separator {
			rows << dropdown_menu_separator()
		} else if item.items.len > 0 {
			rows << DropdownMenuItem{
				...dropdown_menu_submenu(item.title, dropdown_menu_items_from_menu(item.items))
				enabled: item.enabled
			}
		} else {
			rows << DropdownMenuItem{
				id:       item.id
				label:    item.title
				kind:     if item.checked { DropdownMenuItemKind.checkbox } else { .item }
				shortcut: item.shortcut
				checked:  item.checked
				enabled:  item.enabled
			}
		}
	}
	return rows
}

// dropdown_menu_items_from_entries turns an element's right-click entries into
// dropdown rows, for showing the same choices from a button.
pub fn dropdown_menu_items_from_entries(entries []MenuEntry) []DropdownMenuItem {
	mut rows := []DropdownMenuItem{cap: entries.len}
	for entry in entries {
		rows << dropdown_menu_item(entry.id, entry.title)
	}
	return rows
}

// dropdown_menu_navigable reports whether the keyboard and the pointer can
// highlight a row: an enabled item, check, radio or submenu row.
pub fn dropdown_menu_navigable(item DropdownMenuItem) bool {
	return item.enabled && match item.kind {
		.item, .checkbox, .radio { true }
		.submenu { item.items.len > 0 }
		.separator, .label { false }
	}
}

fn dropdown_menu_choosable(item DropdownMenuItem) bool {
	return item.enabled && item.kind in [.item, .checkbox, .radio]
}

// validate_dropdown_menu_items rejects rows a menu cannot show or decode:
// choosable rows without an id or with a duplicated one, untitled rows,
// empty submenus and decorated separators.
pub fn validate_dropdown_menu_items(items []DropdownMenuItem) ! {
	mut ids := map[string]bool{}
	dropdown_menu_validate_level(items, 'menu', mut ids)!
}

fn dropdown_menu_validate_level(items []DropdownMenuItem, path string, mut ids map[string]bool) ! {
	for index, item in items {
		here := '${path}/${index}'
		if !component_finite(item.height) || item.height < 0 {
			return error('dropdown menu row at ${here} has an invalid height')
		}
		match item.kind {
			.separator {
				if item.id.len > 0 || item.label.len > 0 || item.items.len > 0 {
					return error('separator at ${here} cannot carry an id, label or rows')
				}
			}
			.label {
				if item.label.trim_space().len == 0 || item.items.len > 0 {
					return error('heading at ${here} needs a label and no rows')
				}
			}
			.submenu {
				if item.label.trim_space().len == 0 || item.items.len == 0 {
					return error('submenu at ${here} needs a label and rows')
				}
				dropdown_menu_validate_level(item.items, here, mut ids)!
			}
			.item, .checkbox, .radio {
				if item.id.trim_space().len == 0 {
					return error('dropdown menu row at ${here} has no id')
				}
				if item.id in ids {
					return error('duplicate dropdown menu row id `${item.id}` at ${here}')
				}
				if item.label.trim_space().len == 0 && item.children.len == 0 {
					return error('dropdown menu row `${item.id}` at ${here} has no label')
				}
				if item.items.len > 0 {
					return error('dropdown menu row `${item.id}` at ${here} is not a submenu')
				}
				ids[item.id] = true
			}
		}
	}
}

// DropdownMenuState is a dropdown menu's controlled state. path holds the
// highlighted row of each open level: [2] highlights the third row, and when
// that row is a submenu its menu shows beside it; [2, 0] highlights that
// submenu's first row as well.
pub struct DropdownMenuState {
pub:
	open bool
	path []int
}

pub fn (state DropdownMenuState) opened() DropdownMenuState {
	return DropdownMenuState{
		open: true
	}
}

pub fn (state DropdownMenuState) closed() DropdownMenuState {
	return DropdownMenuState{}
}

pub fn (state DropdownMenuState) toggled() DropdownMenuState {
	return if state.open { state.closed() } else { state.opened() }
}

// DropdownMenuStep is the next menu state, and the row chosen when `chosen` is
// set (the menu closes then).
pub struct DropdownMenuStep {
pub:
	state  DropdownMenuState
	chosen bool
	item   DropdownMenuItem
	path   []int
}

pub fn dropdown_menu_toggle_action(id string) string {
	return component_part_id(id, 'toggle')
}

pub fn dropdown_menu_dismiss_action(id string) string {
	return component_part_id(id, 'dismiss')
}

// dropdown_menu_item_action is the action of the row at path.
pub fn dropdown_menu_item_action(id string, path []int) string {
	return component_part_id(id, 'item:' + path.map(it.str()).join('.'))
}

// dropdown_menu_at returns the row at path, following submenus.
pub fn dropdown_menu_at(items []DropdownMenuItem, path []int) ?DropdownMenuItem {
	if path.len == 0 {
		return none
	}
	mut level := items.clone()
	for depth, index in path {
		if index < 0 || index >= level.len {
			return none
		}
		item := level[index]
		if depth == path.len - 1 {
			return item
		}
		if item.kind != .submenu {
			return none
		}
		level = item.items.clone()
	}
	return none
}

// dropdown_menu_level returns the rows of the submenu at path, or the top
// level for an empty path.
fn dropdown_menu_level(items []DropdownMenuItem, path []int) ?[]DropdownMenuItem {
	if path.len == 0 {
		return items
	}
	parent := dropdown_menu_at(items, path)?
	if parent.kind != .submenu {
		return none
	}
	return parent.items
}

// dropdown_menu_path_from_action decodes the row path an action names, checking
// every index against the rows the menu showed.
fn dropdown_menu_path_from_action(id string, items []DropdownMenuItem, action string) ?[]int {
	part := component_action_part(id, action) or { return none }
	if !part.starts_with('item:') {
		return none
	}
	mut path := []int{}
	mut level := items.clone()
	segments := part['item:'.len..].split('.')
	for depth, segment in segments {
		if level.len == 0 {
			return none
		}
		index := component_parse_index(segment, level.len - 1) or { return none }
		path << index
		if depth < segments.len - 1 {
			if level[index].kind != .submenu {
				return none
			}
			level = level[index].items.clone()
		}
	}
	return path
}

// dropdown_menu_item_from_action decodes the row a press on a menu row chose,
// rejecting foreign, malformed, forged, disabled and unchoosable rows.
pub fn dropdown_menu_item_from_action(id string, items []DropdownMenuItem, action string) ?DropdownMenuItem {
	path := dropdown_menu_path_from_action(id, items, action) or { return none }
	item := dropdown_menu_at(items, path) or { return none }
	return if dropdown_menu_choosable(item) { item } else { none }
}

// dropdown_menu_next_index moves from current to the next navigable row,
// forward or backward, wrapping around; current -1 starts before the first
// row (or after the last when moving backward). It returns -1 when no row is
// navigable.
pub fn dropdown_menu_next_index(items []DropdownMenuItem, current int, forward bool) int {
	count := items.len
	mut index := current
	for _ in 0 .. count {
		index = if forward {
			if index < 0 || index >= count - 1 { 0 } else { index + 1 }
		} else {
			if index <= 0 || index >= count { count - 1 } else { index - 1 }
		}
		if dropdown_menu_navigable(items[index]) {
			return index
		}
	}
	return -1
}

pub fn dropdown_menu_first_index(items []DropdownMenuItem) int {
	return dropdown_menu_next_index(items, -1, true)
}

pub fn dropdown_menu_last_index(items []DropdownMenuItem) int {
	return dropdown_menu_next_index(items, -1, false)
}

fn dropdown_menu_moved(state DropdownMenuState, path []int) ?DropdownMenuStep {
	if path == state.path {
		return none
	}
	return DropdownMenuStep{
		state: DropdownMenuState{
			open: true
			path: path
		}
	}
}

fn dropdown_menu_chose(item DropdownMenuItem, path []int) DropdownMenuStep {
	return DropdownMenuStep{
		state:  DropdownMenuState{}
		chosen: true
		item:   item
		path:   path
	}
}

// dropdown_menu_activate chooses the row at path, or opens it when it is a
// submenu, highlighting the submenu's first row if `enter` is set.
fn dropdown_menu_activate(items []DropdownMenuItem, state DropdownMenuState, path []int, enter bool) ?DropdownMenuStep {
	item := dropdown_menu_at(items, path) or { return none }
	if item.kind == .submenu && dropdown_menu_navigable(item) {
		mut next := path.clone()
		if enter {
			first := dropdown_menu_first_index(item.items)
			if first >= 0 {
				next << first
			}
		}
		return dropdown_menu_moved(state, next)
	}
	if dropdown_menu_choosable(item) {
		return dropdown_menu_chose(item, path)
	}
	return none
}

// dropdown_menu_update applies an event from on_event to a menu: its toggle
// action (from the trigger), its dismiss action (a press outside), a press on
// a row (a choice, or opening a submenu) and the pointer entering or leaving a
// row (the highlight). It returns none for events that are not the menu's or
// change nothing.
pub fn dropdown_menu_update(id string, items []DropdownMenuItem, state DropdownMenuState, event string) ?DropdownMenuStep {
	if event == dropdown_menu_toggle_action(id) {
		return DropdownMenuStep{
			state: state.toggled()
		}
	}
	if !state.open {
		return none
	}
	if event == dropdown_menu_dismiss_action(id) {
		return DropdownMenuStep{
			state: state.closed()
		}
	}
	if pointer := parse_pointer_event(event) {
		if pointer.phase != 'enter' && pointer.phase != 'leave' {
			return none
		}
		path := dropdown_menu_path_from_action(id, items, pointer.action) or { return none }
		item := dropdown_menu_at(items, path) or { return none }
		parent := path[..path.len - 1].clone()
		if pointer.phase == 'enter' {
			return dropdown_menu_moved(state, if dropdown_menu_navigable(item) {
				path
			} else {
				parent
			})
		}
		// A submenu row keeps its highlight while the pointer travels into the
		// submenu; any other row lets go of it, unless a key moved it elsewhere.
		if item.kind == .submenu || state.path != path {
			return none
		}
		return dropdown_menu_moved(state, parent)
	}
	path := dropdown_menu_path_from_action(id, items, event) or { return none }
	return dropdown_menu_activate(items, state, path, false)
}

// dropdown_menu_key moves a menu's highlight from on_key_event: Up and Down
// (wrapping), Home and End, Right or Enter into a submenu, Left out of one,
// Enter or Space to choose, and Escape or Tab to close. It returns none for
// keys it leaves alone; consume the key otherwise.
pub fn dropdown_menu_key(items []DropdownMenuItem, state DropdownMenuState, event KeyEvent) ?DropdownMenuStep {
	if !state.open || event.cmd || event.ctrl || event.alt {
		return none
	}
	if event.code == .escape || event.code == .tab {
		return DropdownMenuStep{
			state: state.closed()
		}
	}
	depth := math.max(state.path.len - 1, 0)
	prefix := state.path[..depth].clone()
	rows := dropdown_menu_level(items, prefix) or { return none }
	current := if state.path.len == 0 { -1 } else { state.path[depth] }
	mut target := -2
	match event.code {
		.down { target = dropdown_menu_next_index(rows, current, true) }
		.up { target = dropdown_menu_next_index(rows, current, false) }
		.home, .page_up { target = dropdown_menu_first_index(rows) }
		.end, .page_down { target = dropdown_menu_last_index(rows) }
		.right {
			if current < 0 || current >= rows.len || rows[current].kind != .submenu {
				return none
			}
			return dropdown_menu_activate(items, state, state.path, true)
		}
		.left {
			if depth == 0 {
				return none
			}
			return dropdown_menu_moved(state, prefix)
		}
		.enter, .kp_enter, .space {
			if current < 0 {
				return none
			}
			return dropdown_menu_activate(items, state, state.path, true)
		}
		else {
			return none
		}
	}
	if target < 0 {
		return none
	}
	mut path := prefix.clone()
	path << target
	return dropdown_menu_moved(state, path)
}

pub struct DropdownMenuConfig {
pub:
	id     string
	state  DropdownMenuState
	items  []DropdownMenuItem
	anchor Rect // The trigger, in window coordinates.
	window Rect // Pass ui2.bounds().
	side   PopoverSide  = .bottom
	align  PopoverAlign = .start
	offset f64          = 4
	margin f64          = 8
	// width fixes the menu width; zero sizes it to an estimate of its rows,
	// between min_width and max_width.
	width     f64
	min_width f64 = 128
	max_width f64 = 480
	// max_height bounds every level, which scrolls past it; zero bounds it by
	// the window alone.
	max_height             f64
	close_on_outside_click bool = true
	label                  string // Accessibility label of the menu.
	size                   ComponentSize = .medium
	theme                  ComponentTheme
}

struct DropdownMenuMetrics {
	padding     f64
	row_height  f64
	separator   f64
	inner       f64
	icon        f64
	gap         f64
	font_size   f64
	hint_size   f64
	right_gap   f64
	chevron     f64
	row_radius  f64
	surface_rad f64
}

fn dropdown_menu_metrics(size ComponentSize) DropdownMenuMetrics {
	metrics := component_metrics(size)
	return DropdownMenuMetrics{
		padding:     4
		row_height:  metrics.height - 4
		separator:   9
		inner:       metrics.padding
		icon:        math.round(metrics.font_size * 1.15)
		gap:         metrics.gap
		font_size:   metrics.font_size
		hint_size:   metrics.font_size - 1
		right_gap:   metrics.padding * 3
		chevron:     metrics.font_size
		row_radius:  math.max(metrics.radius - 2, 2)
		surface_rad: metrics.radius
	}
}

fn dropdown_menu_row_height(item DropdownMenuItem, m DropdownMenuMetrics) f64 {
	if item.kind == .separator {
		return m.separator
	}
	return if item.height > 0 { item.height } else { m.row_height }
}

fn dropdown_menu_has_icon_column(items []DropdownMenuItem) bool {
	for item in items {
		if item.icon.len > 0 || item.checked || item.kind in [.checkbox, .radio] {
			return true
		}
	}
	return false
}

// dropdown_menu_shortcut_text renders an accelerator the platform's way, or the
// text unchanged when it is not one.
fn dropdown_menu_shortcut_text(shortcut string) string {
	if shortcut.len == 0 {
		return ''
	}
	rendered := menu_shortcut_label(shortcut)
	return if rendered.len > 0 { rendered } else { shortcut }
}

// dropdown_menu_hint_width estimates a shortcut hint. Modifier symbols and
// arrows are about an em wide and the keys are capitals, so the general text
// estimate would leave a hint such as ⇧⌘S too little room.
fn dropdown_menu_hint_width(hint string, size f64) f64 {
	mut ems := 0.0
	for r in hint.runes() {
		ems += if r >= 0x2190 { 1.0 } else { 0.7 }
	}
	return ems * size
}

fn dropdown_menu_custom_width(children []Element) f64 {
	mut width := 0.0
	for child in children {
		width = math.max(width, child.frame.x + child.frame.width)
	}
	return width
}

// dropdown_menu_size estimates the width and height a level of rows needs.
pub fn dropdown_menu_size(items []DropdownMenuItem, size ComponentSize) (f64, f64) {
	m := dropdown_menu_metrics(size)
	icon_column := if dropdown_menu_has_icon_column(items) { m.icon + m.gap } else { 0.0 }
	mut width := 0.0
	mut height := m.padding * 2
	for index, item in items {
		if item.kind == .separator && index == items.len - 1 {
			continue
		}
		height += dropdown_menu_row_height(item, m)
		content := if item.children.len > 0 {
			dropdown_menu_custom_width(item.children)
		} else {
			component_text_width_estimate(item.label, if item.kind == .label {
				m.hint_size
			} else {
				m.font_size
			})
		}
		hint := dropdown_menu_shortcut_text(item.shortcut)
		right := if item.kind == .submenu {
			m.right_gap + m.chevron
		} else if hint.len > 0 {
			m.right_gap + dropdown_menu_hint_width(hint, m.hint_size)
		} else {
			0.0
		}
		width = math.max(width, m.inner * 2 + icon_column + content + right)
	}
	return math.ceil(width + m.padding * 2), height
}

// DropdownMenuLevel is one open level laid out: its rows, where they came from,
// and the surface in window coordinates.
struct DropdownMenuLevel {
	path   []int // Path of the submenu row this level belongs to; empty for the top.
	items  []DropdownMenuItem
	frame  Rect
	side   PopoverSide
	scroll bool
	rows   []Rect // Surface-local, or scroll-local when the level scrolls.
}

fn dropdown_menu_width(config DropdownMenuConfig, items []DropdownMenuItem, limits PopoverLimits) f64 {
	estimated, _ := dropdown_menu_size(items, config.size)
	width := if config.width > 0 {
		config.width
	} else {
		math.min(math.max(estimated, config.min_width), config.max_width)
	}
	return math.max(math.min(width, limits.right - limits.left), 0)
}

fn dropdown_menu_lay_out(config DropdownMenuConfig, items []DropdownMenuItem, path []int, anchor Rect, side PopoverSide, align PopoverAlign, offset f64) !DropdownMenuLevel {
	m := dropdown_menu_metrics(config.size)
	limits := popover_limits(config.window, config.margin)
	width := dropdown_menu_width(config, items, limits)
	_, natural := dropdown_menu_size(items, config.size)
	room := limits.bottom - limits.top
	limit := if config.max_height > 0 { math.min(config.max_height, room) } else { room }
	scrolls := natural > limit && limit > m.padding * 2
	height := if scrolls { limit } else { natural }
	placement := popover_place(
		anchor: anchor
		window: config.window
		width:  width
		height: height
		side:   side
		align:  align
		offset: offset
		margin: config.margin
	)!
	mut rows := []Rect{cap: items.len}
	mut y := if scrolls { 0.0 } else { m.padding }
	for item in items {
		row_height := dropdown_menu_row_height(item, m)
		rows << rect(m.padding, y, width - m.padding * 2, row_height)
		y += row_height
	}
	return DropdownMenuLevel{
		path:   path
		items:  items
		frame:  placement.frame
		side:   placement.side
		scroll: scrolls
		rows:   rows
	}
}

// dropdown_menu_levels lays out the top level and every submenu the state's
// path opens. A path that no longer matches the rows opens nothing further.
fn dropdown_menu_levels(config DropdownMenuConfig) ![]DropdownMenuLevel {
	m := dropdown_menu_metrics(config.size)
	mut levels := [
		dropdown_menu_lay_out(config, config.items, []int{}, config.anchor, config.side,
			config.align, config.offset)!,
	]
	for depth, index in config.state.path {
		level := levels[depth]
		if index < 0 || index >= level.items.len {
			break
		}
		item := level.items[index]
		if item.kind != .submenu || !dropdown_menu_navigable(item) {
			break
		}
		row := level.rows[index]
		// The submenu's first row lines up with the row that opened it. The scroll
		// position of a level that scrolls is unknown here, so its rows are taken
		// to be where they are when it is scrolled to the top.
		row_y := level.frame.y + row.y + if level.scroll { m.padding } else { 0.0 }
		anchor := rect(level.frame.x, row_y - m.padding, level.frame.width, row.height +
			m.padding * 2)
		side := if level.side == .left { PopoverSide.left } else { PopoverSide.right }
		path := config.state.path[..depth + 1].clone()
		levels << dropdown_menu_lay_out(config, item.items, path, anchor, side, .start,
			2)!
	}
	return levels
}

fn dropdown_menu_row(config DropdownMenuConfig, level DropdownMenuLevel, index int, highlighted bool) Element {
	m := dropdown_menu_metrics(config.size)
	theme := config.theme
	item := level.items[index]
	frame := level.rows[index]
	mut path := level.path.clone()
	path << index
	action := dropdown_menu_item_action(config.id, path)
	key := 'row:${index}'
	if item.kind == .separator {
		line := math.floor(frame.height / 2)
		return Element{
			...view('', rect(0, frame.y, level.frame.width, frame.height), BoxStyle{
				transparent: true
			}, [
				view('', rect(0, line, level.frame.width, 1), BoxStyle{ bg: theme.border }, []Element{}),
			])
			key:                key
			action_id:          action
			hoverable:          true
			accessibility_role: 'separator'
		}
	}
	icon_column := dropdown_menu_has_icon_column(level.items)
	mut children := []Element{}
	mut x := m.inner
	if item.kind == .label {
		children << label('', item.label, rect(x, 0, frame.width - x - m.inner, frame.height),
			TextStyle{
				color: theme.muted_foreground
				size:  m.hint_size
				bold:  true
			})
		return Element{
			...view('', frame, BoxStyle{ transparent: true }, children)
			key:                 key
			action_id:           action
			hoverable:           true
			accessibility_role:  'text'
			accessibility_label: item.label
		}
	}
	enabled := item.enabled
	foreground := if !enabled {
		theme.muted_foreground
	} else {
		theme.foreground
	}
	if icon_column {
		icon_y := (frame.height - m.icon) / 2
		icon_frame := rect(x, icon_y, m.icon, m.icon)
		if item.checked && item.kind != .submenu {
			children << label('', if item.kind == .radio { '●' } else { '✓' }, icon_frame,
				TextStyle{
					color: foreground
					size:  if item.kind == .radio { m.font_size * 0.6 } else { m.font_size }
					align: .center
				})
		} else if item.icon.len > 0 {
			children << Element{
				...image('', 'symbol:' + item.icon, icon_frame)
				text_style: TextStyle{
					color: foreground
				}
			}
		}
		x += m.icon + m.gap
	}
	hint := dropdown_menu_shortcut_text(item.shortcut)
	right := if item.kind == .submenu {
		m.chevron
	} else if hint.len > 0 {
		math.min(dropdown_menu_hint_width(hint, m.hint_size) + m.inner, frame.width / 2)
	} else {
		0.0
	}
	content_width := math.max(frame.width - x - m.inner - right, 0)
	if item.children.len > 0 {
		children << view('', rect(x, 0, content_width, frame.height), BoxStyle{ transparent: true },
			item.children)
	} else {
		children << label('', item.label, rect(x, 0, content_width, frame.height), TextStyle{
			color: foreground
			size:  m.font_size
		})
	}
	if item.kind == .submenu {
		children << label('', '›', rect(frame.width - m.inner - right, 0, right, frame.height),
			TextStyle{
				color: theme.muted_foreground
				size:  m.font_size + 2
				align: .right
			})
	} else if hint.len > 0 {
		children << label('', hint, rect(frame.width - m.inner - right, 0, right, frame.height),
			TextStyle{
				color: theme.muted_foreground
				size:  m.hint_size
				align: .right
			})
	}
	open_submenu := item.kind == .submenu && highlighted
	return Element{
		...button_view(action, frame, if highlighted && enabled {
			BoxStyle{
				bg:     theme.muted
				radius: m.row_radius
			}
		} else {
			BoxStyle{
				transparent: true
			}
		}, children)
		key:                 key
		hoverable:           true
		enabled:             enabled
		accessibility_role:  match item.kind {
			.checkbox { 'menuitemcheckbox' }
			.radio { 'menuitemradio' }
			else { 'menuitem' }
		}
		accessibility_label: item.label
		accessibility_value: if item.kind == .submenu {
			if open_submenu { 'expanded' } else { 'collapsed' }
		} else if item.kind in [.checkbox, .radio] || item.checked {
			if item.checked { 'checked' } else { 'unchecked' }
		} else {
			''
		}
	}
}

fn dropdown_menu_surface(config DropdownMenuConfig, level DropdownMenuLevel, depth int) Element {
	m := dropdown_menu_metrics(config.size)
	highlight := if depth < config.state.path.len { config.state.path[depth] } else { -1 }
	mut rows := []Element{cap: level.items.len}
	for index, item in level.items {
		if item.kind == .separator && index == level.items.len - 1 {
			continue
		}
		rows << dropdown_menu_row(config, level, index, index == highlight
			&& dropdown_menu_navigable(item))
	}
	surface_label := if depth == 0 {
		config.label
	} else {
		(dropdown_menu_at(config.items, level.path) or { DropdownMenuItem{} }).label
	}
	box, mut children := popover_panel(level.frame, config.theme.background, config.theme.border,
		m.surface_rad, true)
	if level.scroll {
		children << scroll(component_part_id(config.id, 'scroll:${depth}'), rect(1, m.padding,
			level.frame.width - 2, level.frame.height - m.padding * 2), config.theme.background,
			rows)
	} else {
		children << rows
	}
	return Element{
		...view(component_part_id(config.id, 'menu:${depth}'), level.frame, box, children)
		key:                 'menu:${depth}'
		clickable:           true
		accessibility_role:  'menu'
		accessibility_label: surface_label
	}
}

// dropdown_menu draws a menu in the window next to its anchor, with any
// submenu its state's path opens beside it. It is controlled: pass every event
// to dropdown_menu_update and every key to dropdown_menu_key while it is open,
// store the state they return and rebuild. Build it after everything it may
// cover.
pub fn dropdown_menu(config DropdownMenuConfig) !Element {
	component_validate_id(config.id)!
	validate_dropdown_menu_items(config.items)!
	for value in [config.width, config.min_width, config.max_width, config.max_height] {
		if !component_finite(value) || value < 0 {
			return error('dropdown menu sizes must be finite and non-negative')
		}
	}
	if !config.state.open {
		return component_finish(popover_closed(config.id))
	}
	levels := dropdown_menu_levels(config)!
	mut surfaces := []Element{cap: levels.len}
	for depth, level in levels {
		surfaces << dropdown_menu_surface(config, level, depth)
	}
	dismiss := if config.close_on_outside_click {
		dropdown_menu_dismiss_action(config.id)
	} else {
		''
	}
	return component_finish(popover_layer(config.id, config.window, component_part_id(config.id,
		'backdrop'), dismiss, surfaces))
}

pub fn dropdown_button_action(id string) string {
	return component_part_id(id, 'action')
}

pub struct DropdownButtonConfig {
pub:
	id      string
	frame   Rect
	label   string
	icon    string // A symbol name drawn before the label.
	menu_id string // The dropdown_menu this button opens.
	open    bool   // Whether that menu shows: the trigger is drawn pressed.
	// split makes a split button: the main half emits action_id (by default
	// dropdown_button_action(id)) and only the chevron half opens the menu.
	split      bool
	action_id  string
	menu_label string        = 'More options' // Accessibility label of a split button's chevron.
	enabled    bool          = true
	tone       ComponentTone = .neutral
	outline    bool
	size       ComponentSize = .medium
	theme      ComponentTheme
}

// dropdown_button_width estimates the width that fits the label, the icon and
// the chevron.
pub fn dropdown_button_width(caption string, icon string, split bool, size ComponentSize) f64 {
	metrics := component_metrics(size)
	icon_width := if icon.len > 0 {
		math.round(metrics.font_size * 1.15) + metrics.gap
	} else {
		0.0
	}
	chevron := if split { metrics.height } else { metrics.font_size + metrics.gap }
	return math.ceil(metrics.padding * 2 + icon_width +
		component_text_width_estimate(caption, metrics.font_size) + chevron)
}

fn dropdown_button_colors(config DropdownButtonConfig) (u32, u32, u32) {
	theme := config.theme
	tone_bg, tone_fg := theme.colors(config.tone)
	neutral := config.tone == .neutral
	bg := if config.outline { theme.background } else { tone_bg }
	mut fg := if !config.outline {
		tone_fg
	} else if neutral {
		theme.foreground
	} else {
		tone_bg
	}
	border := if neutral { theme.border } else { tone_bg }
	if !config.enabled {
		fg = theme.muted_foreground
	}
	return bg, fg, border
}

// dropdown_button_content lays an optional icon and a centered label out in
// frame, leaving `trailing` points free on the right.
fn dropdown_button_content(config DropdownButtonConfig, frame Rect, trailing f64, color u32) []Element {
	metrics := component_metrics(config.size)
	icon_size := math.round(metrics.font_size * 1.15)
	mut children := []Element{}
	mut x := metrics.padding
	if config.icon.len > 0 {
		if config.label.len == 0 {
			x = (frame.width - trailing - icon_size) / 2
		}
		children << Element{
			...image('', 'symbol:' + config.icon, rect(x, (frame.height - icon_size) / 2,
				icon_size, icon_size))
			text_style: TextStyle{
				color: color
			}
		}
		x += icon_size + metrics.gap
	}
	if config.label.len > 0 {
		children << label('', config.label, rect(x, 0, math.max(frame.width - x - trailing - metrics.padding / 2,
			0), frame.height), TextStyle{
			color: color
			size:  metrics.font_size
			align: if config.icon.len > 0 { Align.left } else { Align.center }
		})
	}
	return children
}

// dropdown_button_chevron draws the downward caret from strips, as the popover
// arrows are drawn, so it has the same size on every renderer: a text glyph such
// as ▾ comes out at very different sizes from different fallback fonts.
fn dropdown_button_chevron(frame Rect, color u32, size ComponentSize) Element {
	depth := math.round(component_metrics(size).font_size * 0.3)
	top := math.round((frame.height - depth) / 2)
	center := math.round(frame.width) / 2
	mut strips := []Element{}
	for strip in popover_arrow_strips(.top, top, center, depth, 0, 0.5) {
		strips << view('', strip, BoxStyle{ bg: color }, []Element{})
	}
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, strips)
		key: 'chevron'
	}
}

// dropdown_button is a button with a chevron that opens a dropdown_menu, or,
// with `split`, a main action joined to a separate chevron trigger. Both emit
// dropdown_menu_toggle_action(menu_id), so dropdown_menu_update handles them.
// Anchor the menu to the button's frame in window coordinates.
pub fn dropdown_button(config DropdownButtonConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	component_validate_id(config.menu_id)!
	metrics := component_metrics(config.size)
	bg, fg, border := dropdown_button_colors(config)
	pressed := popover_blend(bg, fg, 0.12)
	local := component_local(config.frame)
	menu_toggle := dropdown_menu_toggle_action(config.menu_id)
	expanded := if config.open { 'expanded' } else { 'collapsed' }
	if !config.split {
		chevron := metrics.font_size
		box, mut children := popover_panel(local, if config.open { pressed } else { bg },
			border, metrics.radius, false)
		children << dropdown_button_content(config, local, chevron + metrics.padding, fg)
		children << dropdown_button_chevron(rect(local.width - metrics.padding - chevron,
			0, chevron, local.height), fg, config.size)
		return component_finish(Element{
			...button_view(config.id, config.frame, box, children)
			action_id:           menu_toggle
			enabled:             config.enabled
			accessibility_label: config.label
			accessibility_value: expanded
		})
	}
	trigger_width := math.min(metrics.height, local.width / 2)
	main_width := local.width - trigger_width
	main_frame := rect(0, 0, main_width, local.height)
	divider := if config.outline || config.tone == .neutral {
		border
	} else {
		popover_blend(bg, fg, 0.35)
	}
	mut trigger_children := []Element{}
	if config.open {
		trigger_children << view('', rect(2, 2, math.max(trigger_width - 4, 0), math.max(local.height - 4,
			0)), BoxStyle{
			bg:     pressed
			radius: math.max(metrics.radius - 2, 0)
		}, []Element{})
	}
	trigger_children << dropdown_button_chevron(rect(0, 0, trigger_width, local.height),
		fg, config.size)
	box, mut children := popover_panel(local, bg, border, metrics.radius, false)
	children << [
		Element{
			...button_view(dropdown_button_action(config.id), main_frame, BoxStyle{
				transparent: true
			}, dropdown_button_content(config, main_frame, 0, fg))
			key:                 'action'
			action_id:           if config.action_id.len > 0 {
				config.action_id
			} else {
				dropdown_button_action(config.id)
			}
			enabled:             config.enabled
			accessibility_label: config.label
		},
		Element{
			...view('', rect(main_width, 0, 1, local.height), BoxStyle{ bg: divider }, []Element{})
			key: 'divider'
		},
		Element{
			...button_view(component_part_id(config.id, 'trigger'), rect(main_width, 0,
				trigger_width, local.height), BoxStyle{ transparent: true }, trigger_children)
			key:                 'trigger'
			action_id:           menu_toggle
			enabled:             config.enabled
			accessibility_label: config.menu_label
			accessibility_value: expanded
		},
	]
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_role:  'group'
		accessibility_label: config.label
	})
}
