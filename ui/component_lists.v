// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// A list after GPUI Kit's List (crates/component/src/list/). Its row model
// follows list/cache.rs: sections without rows are hidden with their header
// and footer, and Up and Down skip headers, separators and disabled rows and
// wrap around from the last row to the first. The item model, layout,
// selection with modifiers, virtualization and rendering are new UI2 code.
// See third_party/gpui-kit.
module ui2

import encoding.hex
import math

pub enum ListItemKind {
	item      // A row: selectable, unless disabled.
	separator // A divider between rows; never selectable.
}

// ListItemAction is a small icon button at the end of a row.
pub struct ListItemAction {
pub:
	id      string // Unique within its row; list_update reports it.
	icon    string // A symbol name; see symbol_known.
	label   string // Accessibility label and tooltip.
	enabled bool = true
}

// ListItem is one row of a list: a title, an optional description below it, a
// leading icon or avatar, and trailing text, a badge and action buttons.
pub struct ListItem {
pub:
	id                  string // Unique across the list; the selection names rows by it.
	kind                ListItemKind = .item
	title               string
	description         string // A second, muted line; it makes the row taller.
	icon                string // A leading symbol name; see symbol_known.
	avatar              string // A name for a leading avatar's initials, when there is no icon.
	avatar_image        string // A picture for that avatar.
	trailing            string // Muted text at the end: a size, a date, a count.
	badge               string // A badge at the end.
	badge_tone          ComponentTone = .neutral
	actions             []ListItemAction
	menu                []MenuEntry // The row's native right-click menu; entries emit their own ids.
	enabled             bool = true
	accessibility_label string // Defaults to the title and description.
}

// list_item is a plain row.
pub fn list_item(id string, title string) ListItem {
	return ListItem{
		id:    id
		title: title
	}
}

// list_separator is a divider row.
pub fn list_separator() ListItem {
	return ListItem{
		kind: .separator
	}
}

// ListSection is a group of rows under a header. A section without rows is
// not drawn at all, header and footer included.
pub struct ListSection {
pub:
	title  string // The header; empty draws none.
	icon   string // A symbol drawn before the header.
	footer string // Muted text after the rows; empty draws none.
	items  []ListItem
}

pub enum ListSelectionMode {
	none     // Rows only confirm; nothing stays selected.
	single   // One row at a time.
	multiple // Any number of rows: Cmd/Ctrl-click toggles, Shift-click selects a range.
}

// ListState is a list's controlled state. The application keeps it, passes it
// in, and stores what list_update and list_key return.
pub struct ListState {
pub:
	selected []string // Ids of the selected rows.
	active   string   // The keyboard cursor: the row the arrow keys move from.
	anchor   string   // Where a Shift range starts.
	hovered  string   // The row under the pointer.
}

// ListModifiers are the modifier keys held during a click. ui2's pointer
// events do not carry them, so the application supplies them
// (list_held_modifiers for a click, list_modifiers for a key) or offers its own
// way to toggle and extend.
pub struct ListModifiers {
pub:
	toggle bool // Cmd on macOS, Ctrl elsewhere: add or remove one row.
	extend bool // Shift: select the range from the anchor to the row.
}

// list_modifiers reads the toggle and extend modifiers from a key event.
pub fn list_modifiers(event KeyEvent) ListModifiers {
	return ListModifiers{
		toggle: event.cmd || event.ctrl
		extend: event.shift
	}
}

// list_held_modifiers reads the toggle and extend modifiers held right now
// (key_modifiers), for the click being handled.
pub fn list_held_modifiers() ListModifiers {
	held := key_modifiers()
	return ListModifiers{
		toggle: held.cmd || held.ctrl
		extend: held.shift
	}
}

pub struct ListConfig {
pub:
	id        string
	frame     Rect
	items     []ListItem    // The rows of a list without sections.
	sections  []ListSection // Rows in sections; use either this or items.
	state     ListState
	selection ListSelectionMode = .single
	// check_icon draws a check mark at the end of selected rows, as GPUI
	// Kit's confirmed rows and multi-select pickers show.
	check_icon bool
	// loading adds placeholder rows after the rows there are; with none it is
	// the whole list, as GPUI Kit's loading view is.
	loading           bool
	empty_title       string = 'No items'
	empty_description string
	empty_icon        string = 'tray'
	// offset is the scroll position: store scroll_offset(list_scroll_id(id))
	// when on_scroll reports that id. With virtualize, only the rows near it are
	// built, so a long list stays cheap to rebuild; without, every row is.
	offset              f64
	virtualize          bool
	overscan            int  = 3
	bordered            bool = true
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// ListStep is what list_update or list_key did: the state to store, and
// whether a row was confirmed, a row action pressed or the list cancelled.
pub struct ListStep {
pub:
	state     ListState
	confirmed bool     // A row was opened: a plain click, or Enter on the active row.
	secondary bool     // Confirmed with Cmd/Ctrl+Enter, GPUI Kit's secondary confirm.
	cancelled bool     // Escape was pressed.
	item      ListItem // The row confirmed or clicked, or whose action was pressed.
	action    string   // The id of the row action pressed; empty otherwise.
	// reveal is set when a key moved the active row: scroll it into view with
	// list_reveal_offset.
	reveal bool
}

// ListPress is a press decoded from an action: on a row, or on one of its
// action buttons.
pub struct ListPress {
pub:
	item_id string
	action  string // The row action's id; empty for the row itself.
}

pub fn list_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

// list_row_action is the action a press on a row emits, and the action of the
// hover events it reports.
pub fn list_row_action(id string, item_id string) string {
	return component_part_id(id, 'row:' + item_id.bytes().hex())
}

pub fn list_item_action_action(id string, item_id string, action_id string) string {
	return component_part_id(id, 'action:' + item_id.bytes().hex() + ':' + action_id.bytes().hex())
}

// list_hex_text decodes the lowercase hex a list wrote into an action; other
// spellings of the same bytes are not what it wrote, so they are rejected.
fn list_hex_text(digits string) ?string {
	if digits.len == 0 {
		return none
	}
	bytes := hex.decode(digits) or { return none }
	if bytes.hex() != digits {
		return none
	}
	return bytes.bytestr()
}

// list_press decodes a press on a row or a row action of the list (or virtual
// list of list_row rows) named id, without looking the row up. It also decodes
// the action of a hover event: pass parse_pointer_event(event).action.
pub fn list_press(id string, action string) ?ListPress {
	part := component_action_part(id, action) or { return none }
	if part.starts_with('row:') {
		return ListPress{
			item_id: list_hex_text(part['row:'.len..])?
		}
	}
	if part.starts_with('action:') {
		rest := part['action:'.len..]
		colon := rest.index(':') or { return none }
		return ListPress{
			item_id: list_hex_text(rest[..colon])?
			action:  list_hex_text(rest[colon + 1..])?
		}
	}
	return none
}

// ── Metrics ─────────────────────────────────────────────────────────

struct ListMetrics {
	font       f64
	small      f64
	row        f64
	row_two    f64
	header     f64
	footer     f64
	separator  f64
	padding    f64 // Above the first row, below the last, and beside every row.
	inner      f64 // Inside a row, before its content and after it.
	gap        f64
	icon       f64
	avatar     f64
	avatar_two f64
	action     f64
	radius     f64
}

fn list_metrics(size ComponentSize) ListMetrics {
	m := component_metrics(size)
	return ListMetrics{
		font:       m.font_size
		small:      m.font_size - 2
		row:        m.height + 4
		row_two:    m.height + m.font_size + 8
		header:     m.height - 4
		footer:     m.height - 8
		separator:  9
		padding:    4
		inner:      m.padding + 2
		gap:        m.gap + 2
		icon:       math.round(m.font_size * 1.25)
		avatar:     m.height - 8
		avatar_two: m.height + 2
		action:     m.height - 6
		radius:     math.max(m.radius - 2, 2)
	}
}

// list_row_height is how tall a row of the item is: taller with a
// description, thin for a separator.
pub fn list_row_height(item ListItem, size ComponentSize) f64 {
	m := list_metrics(size)
	if item.kind == .separator {
		return m.separator
	}
	return if item.description.len > 0 { m.row_two } else { m.row }
}

// ── Model ───────────────────────────────────────────────────────────

const list_loading_rows = 3

enum ListEntryKind {
	header
	item
	separator
	footer
	loading
}

// ListEntry is one row of the list as drawn: a section's header or footer, an
// item, or a loading placeholder.
struct ListEntry {
	kind    ListEntryKind
	section int
	index   int // The item's index in its section.
}

struct ListModel {
	sections []ListSection
	entries  []ListEntry
	layout   VirtualListLayout
	metrics  ListMetrics
}

fn list_config_sections(config ListConfig) ![]ListSection {
	if config.sections.len > 0 && config.items.len > 0 {
		return error('list `${config.id}` takes items or sections, not both')
	}
	if config.sections.len > 0 {
		return config.sections
	}
	return [ListSection{
		items: config.items
	}]
}

fn list_validate_item(item ListItem) ! {
	if item.kind == .separator {
		return
	}
	if item.id.trim_space().len == 0 {
		return error('list row `${item.title}` has no id')
	}
	if item.icon.len > 0 && !symbol_known(item.icon) {
		return error('list row `${item.id}` uses `${item.icon}`, which not every renderer can draw; pick a name from symbol_names()')
	}
	mut actions := map[string]bool{}
	for action in item.actions {
		if action.id.trim_space().len == 0 || action.id in actions {
			return error('list row `${item.id}` needs unique, non-empty action ids')
		}
		actions[action.id] = true
		if !symbol_known(action.icon) {
			return error('list row `${item.id}` action `${action.id}` needs an icon from symbol_names()')
		}
		if action.label.trim_space().len == 0 {
			return error('list row `${item.id}` action `${action.id}` needs a label')
		}
	}
}

fn list_validate(sections []ListSection) ! {
	mut ids := map[string]bool{}
	for section in sections {
		if section.icon.len > 0 && !symbol_known(section.icon) {
			return error('list section `${section.title}` uses `${section.icon}`, which not every renderer can draw')
		}
		for item in section.items {
			list_validate_item(item)!
			if item.kind == .item {
				if item.id in ids {
					return error('duplicate list row id `${item.id}`')
				}
				ids[item.id] = true
			}
		}
	}
}

fn list_entry_size(entry ListEntry, sections []ListSection, m ListMetrics) f64 {
	return match entry.kind {
		.header {
			m.header
		}
		.footer {
			m.footer
		}
		.separator {
			m.separator
		}
		.loading {
			m.row_two
		}
		.item {
			if sections[entry.section].items[entry.index].description.len > 0 {
				m.row_two
			} else {
				m.row
			}
		}
	}
}

fn list_model_of(sections []ListSection, loading bool, size ComponentSize) !ListModel {
	m := list_metrics(size)
	mut entries := []ListEntry{}
	for s, section in sections {
		if section.items.len == 0 {
			continue
		}
		if section.title.len > 0 {
			entries << ListEntry{
				kind:    .header
				section: s
			}
		}
		for i, item in section.items {
			entries << ListEntry{
				kind:    if item.kind == .separator { ListEntryKind.separator } else { .item }
				section: s
				index:   i
			}
		}
		if section.footer.len > 0 {
			entries << ListEntry{
				kind:    .footer
				section: s
			}
		}
	}
	if loading {
		for _ in 0 .. list_loading_rows {
			entries << ListEntry{
				kind: .loading
			}
		}
	}
	mut sizes := []f64{cap: entries.len}
	for entry in entries {
		sizes << list_entry_size(entry, sections, m)
	}
	layout := virtual_list_sized(sizes, 0)!.padded(m.padding)!
	return ListModel{
		sections: sections
		entries:  entries
		layout:   layout
		metrics:  m
	}
}

fn list_model(config ListConfig) !ListModel {
	sections := list_config_sections(config)!
	return list_model_of(sections, config.loading, config.size)
}

fn (model ListModel) item(entry ListEntry) ListItem {
	return model.sections[entry.section].items[entry.index]
}

fn list_selectable(item ListItem) bool {
	return item.kind == .item && item.enabled
}

// order lists the selectable rows, in the order they are drawn: what the
// keyboard moves through and a Shift range spans.
fn (model ListModel) order() []string {
	mut ids := []string{}
	for entry in model.entries {
		if entry.kind == .item {
			item := model.item(entry)
			if list_selectable(item) {
				ids << item.id
			}
		}
	}
	return ids
}

// order_entries is the drawn row of each row in order().
fn (model ListModel) order_entries() []int {
	mut indices := []int{}
	for index, entry in model.entries {
		if entry.kind == .item && list_selectable(model.item(entry)) {
			indices << index
		}
	}
	return indices
}

fn (model ListModel) find(item_id string) ?ListItem {
	for section in model.sections {
		for item in section.items {
			if item.kind == .item && item.id == item_id {
				return item
			}
		}
	}
	return none
}

fn (model ListModel) entry_index(item_id string) int {
	for index, entry in model.entries {
		if entry.kind == .item && model.item(entry).id == item_id {
			return index
		}
	}
	return -1
}

// list_viewport is the part of the list's frame its rows scroll in, in the
// list's own coordinates.
fn list_viewport(config ListConfig) Rect {
	inset := if config.bordered { 1.0 } else { 0.0 }
	return rect(inset, inset, math.max(config.frame.width - 2 * inset, 0), math.max(config.frame.height - 2 * inset,
		0))
}

// ── Selection ───────────────────────────────────────────────────────

// list_span is the rows of order from one id to another, both included.
fn list_span(order []string, from string, to string) []string {
	a := order.index(from)
	b := order.index(to)
	if a < 0 || b < 0 {
		return if b >= 0 { [to] } else { []string{} }
	}
	return order[math.min(a, b)..math.max(a, b) + 1].clone()
}

fn list_union(first []string, second []string) []string {
	mut out := first.clone()
	for id in second {
		if id !in out {
			out << id
		}
	}
	return out
}

// list_range_anchor is where a Shift range starts: the anchor, else the active
// row, else the row itself.
fn list_range_anchor(state ListState, order []string, id string) string {
	if state.anchor in order {
		return state.anchor
	}
	if state.active in order {
		return state.active
	}
	return id
}

fn list_click_state(mode ListSelectionMode, state ListState, order []string, id string, modifiers ListModifiers) ListState {
	match mode {
		.none {
			return ListState{
				...state
				active: id
				anchor: id
			}
		}
		.single {
			deselect := modifiers.toggle && id in state.selected
			return ListState{
				...state
				selected: if deselect { []string{} } else { [id] }
				active:   id
				anchor:   id
			}
		}
		.multiple {
			if modifiers.extend {
				anchor := list_range_anchor(state, order, id)
				span := list_span(order, anchor, id)
				return ListState{
					...state
					selected: if modifiers.toggle { list_union(state.selected, span) } else { span }
					active:   id
					anchor:   anchor
				}
			}
			if modifiers.toggle {
				return ListState{
					...state
					selected: if id in state.selected {
						state.selected.filter(it != id)
					} else {
						list_union(state.selected, [id])
					}
					active:   id
					anchor:   id
				}
			}
			return ListState{
				...state
				selected: [id]
				active:   id
				anchor:   id
			}
		}
	}
}

// list_selection_after_click is the state after a click on a row with the given
// modifiers: in single mode the row alone (toggle deselects it); in multiple
// mode the row alone, toggled in or out, or the range from the anchor (with
// toggle, added to what is selected). It returns none for rows the list does not
// show, separators and disabled rows.
pub fn list_selection_after_click(config ListConfig, item_id string, modifiers ListModifiers) ?ListState {
	model := list_model(config) or { return none }
	item := model.find(item_id) or { return none }
	if !list_selectable(item) {
		return none
	}
	return list_click_state(config.selection, config.state, model.order(), item_id, modifiers)
}

// ── Events ──────────────────────────────────────────────────────────

// list_update applies an event from on_event to a list: a press on a row
// (selection with the given modifiers; a plain press also confirms the row), a
// press on a row action, and the pointer entering or leaving a row (hovered).
// It returns none for events that are not the list's, name rows it does not
// show, separators, disabled rows or actions, or change nothing.
pub fn list_update(config ListConfig, event string, modifiers ListModifiers) ?ListStep {
	model := list_model(config) or { return none }
	return list_update_model(config, model, event, modifiers)
}

fn list_update_model(config ListConfig, model ListModel, event string, modifiers ListModifiers) ?ListStep {
	if pointer := parse_pointer_event(event) {
		if pointer.phase != 'enter' && pointer.phase != 'leave' {
			return none
		}
		press := list_press(config.id, pointer.action) or { return none }
		if press.action.len > 0 {
			return none
		}
		item := model.find(press.item_id) or { return none }
		if !list_selectable(item) {
			return none
		}
		if pointer.phase == 'enter' {
			if config.state.hovered == item.id {
				return none
			}
			return ListStep{
				state: ListState{
					...config.state
					hovered: item.id
				}
			}
		}
		if config.state.hovered != item.id {
			return none
		}
		return ListStep{
			state: ListState{
				...config.state
				hovered: ''
			}
		}
	}
	press := list_press(config.id, event) or { return none }
	item := model.find(press.item_id) or { return none }
	if !list_selectable(item) {
		return none
	}
	if press.action.len > 0 {
		for action in item.actions {
			if action.id == press.action {
				if !action.enabled {
					return none
				}
				return ListStep{
					state:  config.state
					item:   item
					action: action.id
				}
			}
		}
		return none
	}
	plain := !modifiers.toggle && !modifiers.extend
	return ListStep{
		state:     list_click_state(config.selection, config.state, model.order(), item.id,
			modifiers)
		confirmed: plain
		item:      item
	}
}

// list_page_target is the selectable row a viewport away from the active one,
// or the nearest selectable row beyond it. entries holds the drawn row of each
// selectable row, in order.
fn list_page_target(model ListModel, entries []int, current int, viewport f64, forward bool) int {
	if current < 0 {
		return if forward { 0 } else { entries.len - 1 }
	}
	start := model.layout.item_start(entries[current])
	position := if forward { start + viewport } else { start - viewport }
	landed := model.layout.index_at(math.max(position, 0))
	if forward {
		for index in current + 1 .. entries.len {
			if entries[index] >= landed {
				return index
			}
		}
		return entries.len - 1
	}
	for index := current - 1; index >= 0; index-- {
		if entries[index] <= landed {
			return index
		}
	}
	return 0
}

// list_key_model moves a list's cursor. follow makes the selection follow the
// cursor, as a list's does; without it the cursor is a highlight that leaves the
// selection alone, as a searchable picker's is.
fn list_key_model(config ListConfig, model ListModel, event KeyEvent, follow bool) ?ListStep {
	if event.alt {
		return none
	}
	order := model.order()
	now := config.state
	command := event.cmd || event.ctrl
	current := order.index(now.active)
	match event.code {
		.escape {
			if command || event.shift {
				return none
			}
			return ListStep{
				state:     ListState{
					...now
					active: ''
				}
				cancelled: true
			}
		}
		.enter, .kp_enter {
			if current < 0 || event.shift {
				return none
			}
			item := model.find(order[current]) or { return none }
			selected := if follow && config.selection != .none {
				if config.selection == .single {
					[item.id]
				} else {
					list_union(now.selected, [item.id])
				}
			} else {
				now.selected
			}
			return ListStep{
				state:     ListState{
					...now
					selected: selected
				}
				confirmed: true
				secondary: command
				item:      item
			}
		}
		.space {
			if current < 0 || command || event.shift || config.selection == .none {
				return none
			}
			id := order[current]
			selected := if config.selection == .multiple {
				if id in now.selected {
					now.selected.filter(it != id)
				} else {
					list_union(now.selected, [id])
				}
			} else {
				[id]
			}
			if selected == now.selected {
				return none
			}
			return ListStep{
				state: ListState{
					...now
					selected: selected
					anchor:   id
				}
			}
		}
		.a {
			if !command || event.shift || config.selection != .multiple || order.len == 0 {
				return none
			}
			if now.selected.len == order.len && order.all(it in now.selected) {
				return none
			}
			return ListStep{
				state: ListState{
					...now
					selected: order
				}
			}
		}
		.up, .down, .home, .end, .page_up, .page_down {
			if command || order.len == 0 {
				return none
			}
			viewport := list_viewport(config).height
			target := match event.code {
				.down {
					if current < 0 { 0 } else { (current + 1) % order.len }
				}
				.up {
					if current < 0 { order.len - 1 } else { (current - 1 + order.len) % order.len }
				}
				.home { 0 }
				.end { order.len - 1 }
				.page_down {
					list_page_target(model, model.order_entries(), current, viewport, true)
				}
				else { list_page_target(model, model.order_entries(), current, viewport, false) }
			}
			id := order[target]
			mut next := ListState{
				...now
				active: id
			}
			if follow && config.selection != .none {
				if event.shift && config.selection == .multiple {
					anchor := list_range_anchor(now, order, id)
					next = ListState{
						...next
						selected: list_span(order, anchor, id)
						anchor:   anchor
					}
				} else {
					next = ListState{
						...next
						selected: [id]
						anchor:   id
					}
				}
			}
			if next == now {
				return none
			}
			return ListStep{
				state:  next
				reveal: true
			}
		}
		else {
			return none
		}
	}
}

// list_key moves through a list from on_key_event. Up and Down go to the
// previous or next selectable row, wrapping around; Home and End to the first and
// last; Page Up and Page Down a viewport's height. The selection follows the
// cursor, and Shift extends it from the anchor in multiple mode. Space toggles
// the active row (multiple) or selects it (single), Cmd/Ctrl+A selects every
// row (multiple), Enter confirms the active row (Cmd/Ctrl+Enter: secondary) and
// Escape clears the cursor and reports cancelled. When step.reveal is set,
// scroll to list_reveal_offset. Consume the key whenever a step comes back.
pub fn list_key(config ListConfig, event KeyEvent) ?ListStep {
	model := list_model(config) or { return none }
	return list_key_model(config, model, event, true)
}

// list_reveal_offset is the scroll offset of list_scroll_id(id) that brings a
// row into view, scrolling as little as it can from config.offset; none when
// the list does not show the row.
pub fn list_reveal_offset(config ListConfig, item_id string) ?f64 {
	model := list_model(config) or { return none }
	index := model.entry_index(item_id)
	if index < 0 {
		return none
	}
	return model.layout.scroll_offset_for(index, list_viewport(config).height, config.offset,
		.nearest)
}

// list_visible_range is the range of drawn rows (headers, separators and
// footers count) a list shows at config.offset, for deciding when a virtualized
// list needs rebuilding or an infinitely scrolling one more rows.
pub fn list_visible_range(config ListConfig) !VirtualListRange {
	model := list_model(config)!
	return model.layout.range(list_viewport(config).height, config.offset, config.overscan)
}

// ── Rendering ───────────────────────────────────────────────────────

struct ListRowLook {
	selected   bool
	active     bool
	hovered    bool
	check_icon bool
}

// list_selected_fill tints the background toward the primary color, more in
// a dark theme, where the muted hover fill is closer to it.
fn list_selected_fill(theme ComponentTheme) u32 {
	return interpolate_color(theme.background, theme.primary, if feedback_is_dark(theme) {
		0.32
	} else {
		0.2
	})
}

fn list_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

fn list_centered(x f64, height f64, side f64) Rect {
	return rect(x, math.round((height - side) / 2), side, side)
}

// list_badge_width leaves the badge's label room to spare over the estimate:
// a native label that is a little short cuts its text off.
fn list_badge_width(text string, m ListMetrics) f64 {
	return math.ceil(component_text_width_estimate(text, m.small) * 1.1 + m.small + 8)
}

fn list_row_element(list_id string, item ListItem, frame Rect, look ListRowLook, m ListMetrics, theme ComponentTheme) Element {
	if item.kind == .separator {
		line := math.floor(frame.height / 2)
		return Element{
			...view('', frame, BoxStyle{ transparent: true }, [
				view('', rect(m.inner, line, math.max(frame.width - 2 * m.inner, 0), 1),
					BoxStyle{ bg: theme.border }, []Element{}),
			])
			accessibility_role: 'separator'
		}
	}
	width := frame.width
	height := frame.height
	enabled := item.enabled
	two_lines := item.description.len > 0
	foreground := if enabled { theme.foreground } else { theme.muted_foreground }
	mut children := []Element{}
	mut left := m.inner
	if item.icon.len > 0 {
		children << list_symbol(item.icon, list_centered(left, height, m.icon), if enabled {
			theme.muted_foreground
		} else {
			theme.border
		})
		left += m.icon + m.gap
	} else if item.avatar.len > 0 || item.avatar_image.len > 0 {
		side := if two_lines { m.avatar_two } else { m.avatar }
		children << avatar(
			name:       if item.avatar.len > 0 { item.avatar } else { item.title }
			image_path: item.avatar_image
			frame:      list_centered(left, height, side)
			theme:      theme
		) or { view('', rect(0, 0, 0, 0), BoxStyle{ transparent: true }, []Element{}) }
		left += side + m.gap
	}
	mut right := width - m.inner
	if look.check_icon {
		right -= m.icon
		if look.selected {
			children << list_symbol('checkmark', list_centered(right, height, m.icon),
				if enabled { theme.primary } else { theme.muted_foreground })
		}
		right -= m.gap
	}
	for index := item.actions.len - 1; index >= 0; index-- {
		action := item.actions[index]
		right -= m.action
		glyph := math.round(m.action * 0.6)
		action_enabled := enabled && action.enabled
		children << Element{
			...button_view(list_item_action_action(list_id, item.id, action.id), list_centered(right,
				height, m.action), BoxStyle{
				transparent: true
				radius:      m.radius
			}, [
				list_symbol(action.icon, list_centered((m.action - glyph) / 2, m.action, glyph),
					if action_enabled { theme.muted_foreground } else { theme.border }),
			])
			key:                 'action:' + action.id
			enabled:             action_enabled
			tooltip:             action.label
			accessibility_label: action.label
		}
		right -= 2
	}
	if item.badge.len > 0 {
		badge_width := math.min(list_badge_width(item.badge, m), math.max(right - left, 0) / 2)
		badge_height := math.round(m.small + 8)
		right -= badge_width
		children << badge(
			text:  item.badge
			frame: rect(right, math.round((height - badge_height) / 2), badge_width, badge_height)
			tone:  item.badge_tone
			size:  .small
			theme: theme
		) or { view('', rect(0, 0, 0, 0), BoxStyle{ transparent: true }, []Element{}) }
		right -= m.gap
	}
	if item.trailing.len > 0 {
		wanted := math.ceil(component_text_width_estimate(item.trailing, m.small) + 4)
		trailing_width := math.min(wanted, math.max(right - left, 0) / 2)
		right -= trailing_width
		children << label('', item.trailing, rect(right, 0, trailing_width, height), TextStyle{
			color: theme.muted_foreground
			size:  m.small
			align: .right
		})
		right -= m.gap
	}
	text_width := math.max(right - left, 0)
	if two_lines {
		title_height := math.round(m.font * 1.4)
		description_height := math.round(m.small * 1.4)
		top := math.round((height - title_height - description_height) / 2)
		children << label('', item.title, rect(left, top, text_width, title_height), TextStyle{
			color: foreground
			size:  m.font
		})
		children << label('', item.description, rect(left, top + title_height, text_width,
			description_height), TextStyle{
			color: theme.muted_foreground
			size:  m.small
		})
	} else {
		children << label('', item.title, rect(left, 0, text_width, height), TextStyle{
			color: foreground
			size:  m.font
		})
	}
	fill := if !enabled {
		BoxStyle{
			transparent: true
		}
	} else if look.selected {
		BoxStyle{
			bg:     list_selected_fill(theme)
			radius: m.radius
		}
	} else if look.active || look.hovered {
		BoxStyle{
			bg:     theme.muted
			radius: m.radius
		}
	} else {
		BoxStyle{
			transparent: true
			radius:      m.radius
		}
	}
	box := if look.active && !look.selected && enabled {
		BoxStyle{
			...fill
			border_color:  theme.primary
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}
	} else {
		fill
	}
	description := if item.accessibility_label.len > 0 {
		item.accessibility_label
	} else if two_lines {
		'${item.title}, ${item.description}'
	} else {
		item.title
	}
	return Element{
		...button_view(list_row_action(list_id, item.id), frame, box, children)
		enabled:             enabled
		hoverable:           enabled
		menu:                item.menu
		accessibility_role:  'listitem'
		accessibility_label: description
		accessibility_value: if look.selected { 'selected' } else { '' }
	}
}

pub struct ListRowConfig {
pub:
	list_id    string // The id the row's actions are named after; list_press decodes them.
	item       ListItem
	frame      Rect
	selected   bool
	active     bool
	hovered    bool
	check_icon bool
	size       ComponentSize = .medium
	theme      ComponentTheme
}

// list_row draws one row the way list draws it, for rows a virtual_list
// builds itself: size the frame with list_row_height and decode presses with
// list_press(list_id, action).
pub fn list_row(config ListRowConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.list_id)!
	list_validate_item(config.item)!
	m := list_metrics(config.size)
	look := ListRowLook{
		selected:   config.selected
		active:     config.active
		hovered:    config.hovered
		check_icon: config.check_icon
	}
	return component_finish(Element{
		...list_row_element(config.list_id, config.item, config.frame, look, m, config.theme)
		key: 'row:' + config.item.id
	})
}

fn list_header_element(section ListSection, frame Rect, m ListMetrics, theme ComponentTheme) Element {
	mut children := []Element{}
	mut x := m.inner
	icon := math.round(m.small * 1.2)
	if section.icon.len > 0 {
		children << list_symbol(section.icon, list_centered(x, frame.height, icon), theme.muted_foreground)
		x += icon + m.gap / 2
	}
	children << label('', section.title, rect(x, 0, math.max(frame.width - x - m.inner, 0),
		frame.height), TextStyle{
		color: theme.muted_foreground
		size:  m.small
		bold:  true
	})
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'text'
		accessibility_label: section.title
	}
}

fn list_footer_element(section ListSection, frame Rect, m ListMetrics, theme ComponentTheme) Element {
	return label('', section.footer, rect(frame.x + m.inner, frame.y, math.max(frame.width - 2 * m.inner,
		0), frame.height), TextStyle{
		color: theme.muted_foreground
		size:  m.small - 1
	})
}

// list_loading_element is GPUI Kit's loading view: placeholder rows of two
// bars each, with a shimmer sweeping over them.
fn list_loading_element(id string, frame Rect, rows int, m ListMetrics, theme ComponentTheme) !Element {
	mut shapes := []ShimmerShape{}
	for row in 0 .. rows {
		top := f64(row) * m.row_two
		first := math.round(m.font * 0.9)
		second := math.round(m.small * 0.8)
		y := top + math.round((m.row_two - first - second - 6) / 2)
		shapes << ShimmerShape{
			frame:  rect(m.inner, y, math.min(192, frame.width * 0.55), first)
			radius: 4
		}
		shapes << ShimmerShape{
			frame:  rect(m.inner, y + first + 6, math.min(256, frame.width * 0.75), second)
			radius: 4
		}
	}
	return shimmer(
		id:     id
		frame:  frame
		shapes: shapes
		theme:  theme
	)
}

fn list_empty_element(config ListConfig, frame Rect, m ListMetrics) Element {
	theme := config.theme
	icon := math.round(m.font * 2.4)
	title_height := math.round(m.font * 1.5)
	description_height := if config.empty_description.len > 0 {
		math.round(m.small * 1.5) * 2
	} else {
		0.0
	}
	block := icon + m.gap + title_height + description_height
	mut y := math.max(math.round((frame.height - block) / 2), 0)
	mut children := []Element{}
	if config.empty_icon.len > 0 && symbol_known(config.empty_icon) {
		children << list_symbol(config.empty_icon, rect(math.round((frame.width - icon) / 2),
			y, icon, icon), theme.border)
		y += icon + m.gap
	}
	children << label('', config.empty_title, rect(m.inner, y, math.max(frame.width - 2 * m.inner,
		0), title_height), TextStyle{
		color: theme.muted_foreground
		size:  m.font
		bold:  true
		align: .center
	})
	y += title_height
	if config.empty_description.len > 0 {
		children << label('', config.empty_description, rect(m.inner, y, math.max(frame.width - 2 * m.inner,
			0), description_height), TextStyle{
			color:  theme.muted_foreground
			size:   m.small
			align:  .center
			lines:  2
			valign: .top
		})
	}
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		key:                 'empty'
		accessibility_role:  'status'
		accessibility_label: if config.empty_description.len > 0 {
			'${config.empty_title}. ${config.empty_description}'
		} else {
			config.empty_title
		}
	}
}

fn list_build_rows(config ListConfig, model ListModel, viewport Rect) ![]Element {
	m := model.metrics
	theme := config.theme
	layout := model.layout
	span := if config.virtualize {
		layout.range(viewport.height, config.offset, config.overscan)
	} else {
		VirtualListRange{
			start: 0
			end:   layout.count
		}
	}
	width := viewport.width
	row_width := math.max(width - 2 * m.padding, 0)
	mut rows := []Element{cap: span.len() + 2}
	rows << Element{
		...view('', rect(0, 0, 0, layout.total()), BoxStyle{ transparent: true }, []Element{})
		key: virtual_list_extent_key
	}
	mut loading_built := false
	for index in span.start .. span.end {
		entry := model.entries[index]
		y := layout.item_start(index)
		size := layout.item_size(index)
		match entry.kind {
			.header {
				rows << Element{
					...list_header_element(model.sections[entry.section], rect(m.padding, y,
						row_width, size), m, theme)
					key: 'header:${entry.section}'
				}
			}
			.footer {
				rows << Element{
					...list_footer_element(model.sections[entry.section], rect(m.padding, y,
						row_width, size), m, theme)
					key: 'footer:${entry.section}'
				}
			}
			.separator {
				rows << Element{
					...list_row_element(config.id, model.item(entry), rect(m.padding, y, row_width,
						size), ListRowLook{}, m, theme)
					key: 'separator:${entry.section}:${entry.index}'
				}
			}
			.item {
				item := model.item(entry)
				look := ListRowLook{
					selected:   config.selection != .none && item.id in config.state.selected
					active:     item.id == config.state.active
					hovered:    item.id == config.state.hovered
					check_icon: config.check_icon
				}
				rows << Element{
					...list_row_element(config.id, item, rect(m.padding, y, row_width, size),
						look, m, theme)
					key: 'row:' + item.id
				}
			}
			.loading {
				if !loading_built {
					loading_built = true
					first := model.entries.len - list_loading_rows
					placeholder := list_loading_element(component_part_id(config.id, 'loading'),
						rect(m.padding, layout.item_start(first), row_width, f64(list_loading_rows) * m.row_two),
						list_loading_rows, m, theme)!
					rows << Element{
						...placeholder
						key: 'loading'
					}
				}
			}
		}
	}
	return rows
}

// list draws rows from an application-owned item model, optionally in sections
// with headers and footers, with single or multiple selection, a keyboard
// cursor and hover highlight from ListState. It is controlled: pass events to
// list_update and keys to list_key, store the state they return and rebuild.
// Rows scroll in list_scroll_id(id) once they are taller than the frame.
pub fn list(config ListConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	sections := list_config_sections(config)!
	list_validate(sections)!
	model := list_model_of(sections, config.loading, config.size)!
	theme := config.theme
	m := model.metrics
	viewport := list_viewport(config)
	mut children := []Element{}
	if model.entries.len == 0 {
		children << list_empty_element(config, viewport, m)
	} else {
		rows := list_build_rows(config, model, viewport)!
		// Content that fits does not scroll: a Scroll element would add room
		// below it to scroll into.
		if model.layout.total() <= viewport.height + 0.5 {
			children << Element{
				...view('', viewport, BoxStyle{ transparent: true }, rows)
				key: 'rows'
			}
		} else {
			children << Element{
				...scroll(list_scroll_id(config.id), viewport, theme.background, rows)
				// Unfilled where the backend honors that, so the frame's rounded
				// corners stay whole; the custom renderer fills a Scroll anyway,
				// so the fill is the frame's color.
				box: BoxStyle{
					bg:          theme.background
					transparent: true
				}
				key: 'scroll'
			}
		}
	}
	box := if config.bordered {
		component_box(theme.background, theme.border, component_metrics(config.size).radius)
	} else {
		BoxStyle{
			transparent: true
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_role:  'list'
		accessibility_label: config.accessibility_label
		accessibility_value: if config.loading { 'loading' } else { '' }
	})
}
