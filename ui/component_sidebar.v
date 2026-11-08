// A sidebar after GPUI Kit's Sidebar (crates/component/src/sidebar/): a
// header, labelled groups of menu items with icons, suffixes and nested
// sub-items, a footer, either side of the window, and an icon rail when
// collapsed. The controlled state, the actions and their decoders, keyboard
// navigation, layout and rendering are new UI2 code.
module ui2

import encoding.hex
import math

// sidebar_default_width is GPUI Kit's sidebar width.
pub const sidebar_default_width = 255.0

// sidebar_breakpoint is the window width under which sidebar_auto_collapsed
// collapses a sidebar, the width GPUI Kit's responsive example uses.
pub const sidebar_breakpoint = 768.0

pub enum SidebarSide {
	left
	right
}

// SidebarCollapsible is what a collapsed sidebar becomes.
pub enum SidebarCollapsible {
	icon      // A rail of icons, sidebar_rail_width wide.
	offcanvas // Nothing: it takes no width and builds hidden.
	none      // It never collapses; `collapsed` is ignored.
}

// SidebarItemClick is what a press on an item with sub-items does besides
// activating it. Its chevron always shows and hides them.
pub enum SidebarItemClick {
	activate // Activates the item only.
	open     // Also shows its sub-items.
	toggle   // Also shows or hides its sub-items.
}

// SidebarItem is one entry of a sidebar menu: an icon, a label, a badge,
// muted suffix text or custom trailing content, and sub-items under it.
pub struct SidebarItem {
pub:
	id    string // Unique across the sidebar's items and groups; the state names items by it.
	label string
	icon  string // A symbol name; see symbol_known. The rail shows the label's initial without one.
	// badge is short text in a pill at the end: a count, 'New'.
	badge      string
	badge_tone ComponentTone = .primary
	dot        bool   // A dot in the badge tone instead of a pill.
	suffix     string // Muted text at the end: a total, a shortcut.
	// accessory is custom trailing content, such as a small switch, framed in a
	// box accessory_width wide and as tall as the row.
	accessory       []Element
	accessory_width f64
	children        []SidebarItem // Sub-items, shown while the item is in state.expanded.
	click           SidebarItemClick = .activate
	// more adds a ⋯ button that emits sidebar_more_action, for the actions a
	// right-click context menu would hold: open a dropdown_menu at
	// sidebar_more_anchor. It shows while the row is hovered, focused or current.
	more bool
	// menu is the row's native right-click menu, whose entries emit their own
	// ids. AppKit and Windows show it; the custom renderer and touch screens have
	// none, so pair it with `more` (dropdown_menu_items_from_entries reuses it).
	menu                []MenuEntry
	enabled             bool = true
	tooltip             string // What the rail shows on hover; the label by default.
	accessibility_label string // The label by default.
}

// SidebarGroup is a run of items under an optional label. A collapsible group
// folds shut when its label is pressed.
pub struct SidebarGroup {
pub:
	id          string // Required when collapsible; unique across the sidebar's items and groups.
	label       string // Empty draws no label row.
	collapsible bool
	items       []SidebarItem
}

// SidebarHeader is the block above the groups: a logo tile or an avatar, a
// title and a subtitle. With `menu` it is a button, as GPUI Kit's header with a
// dropdown menu is.
pub struct SidebarHeader {
pub:
	title        string
	subtitle     string
	icon         string // A symbol drawn on a primary-colored tile.
	avatar       string // A name for avatar initials, when there is no icon.
	avatar_image string
	// menu makes the block a button emitting sidebar_header_action and draws
	// menu_icon at its end: open a dropdown_menu at sidebar_header_anchor.
	menu      bool
	menu_icon string = 'chevron.down'
	// children replace the logo, title and subtitle with custom content, framed in
	// the block's own coordinates. The rail still shows the icon or avatar.
	children []Element
	height   f64 // Zero picks one for the size.
}

// SidebarFooter is the block below the groups, usually the signed-in user.
pub struct SidebarFooter {
pub:
	title        string
	subtitle     string
	icon         string
	avatar       string
	avatar_image string
	// menu makes the block a button emitting sidebar_footer_action; open a
	// dropdown_menu at sidebar_footer_anchor.
	menu      bool
	menu_icon string = 'ellipsis'
	children  []Element
	height    f64
}

// SidebarState is a sidebar's controlled state. The application keeps it,
// passes it in and stores what sidebar_update and sidebar_key return.
pub struct SidebarState {
pub:
	active        string   // The current item, drawn highlighted.
	expanded      []string // Items whose sub-items show.
	closed_groups []string // Collapsible groups folded shut.
	// focused is the keyboard cursor: an item or a collapsible group, drawn with
	// a focus ring. Pointer presses clear it.
	focused string
	// hovered names the element under the pointer by its action; it is only
	// meant to be passed back.
	hovered string
}

pub struct SidebarConfig {
pub:
	id     string
	frame  Rect
	groups []SidebarGroup
	header SidebarHeader // Drawn when it has a title, an icon, an avatar or children.
	footer SidebarFooter
	state  SidebarState
	// collapsed turns the sidebar into an icon rail, or hides it when it is
	// collapsible off-canvas. Frame it with sidebar_width.
	collapsed   bool
	collapsible SidebarCollapsible = .icon
	side        SidebarSide        = .left
	// offset is the scroll position of the groups: store
	// scroll_offset(sidebar_scroll_id(id)) when on_scroll reports it. The anchors
	// and sidebar_reveal_offset use it.
	offset f64
	// follow_focus makes the arrow keys activate the item they move to, as a
	// native source list does; without it Enter or Space activates.
	follow_focus bool
	// open_menu is the item whose ⋯ menu (or, in the rail, whose flyout) is
	// open, and header_open and footer_open say whether theirs are: they are
	// drawn pressed.
	open_menu   string
	header_open bool
	footer_open bool
	// more_always shows every ⋯ button, for touch screens, which do not hover.
	more_always         bool
	border              bool          = true // A line along the edge that faces the content.
	accessibility_label string        = 'Sidebar'
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// SidebarEvent is what a SidebarStep reports.
pub enum SidebarEvent {
	activate // An item became current: step.item.
	flyout   // A rail item with sub-items was pressed: show sidebar_flyout_items.
	expand   // An item's sub-items were shown or hidden: step.item.
	group    // A group was folded or unfolded: step.group.
	collapse // The collapse toggle was pressed: step.collapsed is the new value.
	header   // The header was pressed: open its menu at sidebar_header_anchor.
	footer   // The footer was pressed: open its menu at sidebar_footer_anchor.
	more     // An item's ⋯ button was pressed: open its menu at sidebar_more_anchor.
	focus    // A key moved or cleared the cursor.
	hover    // The pointer entered or left a row.
}

// SidebarStep is the state to store after an event or a key, and what happened.
pub struct SidebarStep {
pub:
	event     SidebarEvent
	state     SidebarState
	item      SidebarItem
	group     SidebarGroup
	collapsed bool
	// reveal is set when a key moved the cursor: scroll to sidebar_reveal_offset.
	reveal bool
}

// ── Actions ─────────────────────────────────────────────────────────

pub fn sidebar_scroll_id(id string) string {
	return component_part_id(id, 'scroll')
}

pub fn sidebar_item_action(id string, item_id string) string {
	return component_part_id(id, 'item:' + item_id.bytes().hex())
}

// sidebar_expand_action is the action of an item's chevron.
pub fn sidebar_expand_action(id string, item_id string) string {
	return component_part_id(id, 'expand:' + item_id.bytes().hex())
}

pub fn sidebar_more_action(id string, item_id string) string {
	return component_part_id(id, 'more:' + item_id.bytes().hex())
}

pub fn sidebar_group_action(id string, group_id string) string {
	return component_part_id(id, 'group:' + group_id.bytes().hex())
}

pub fn sidebar_header_action(id string) string {
	return component_part_id(id, 'header')
}

pub fn sidebar_footer_action(id string) string {
	return component_part_id(id, 'footer')
}

// sidebar_collapse_action is what a sidebar_toggle_button for the sidebar id
// emits; any button can emit it.
pub fn sidebar_collapse_action(id string) string {
	return component_part_id(id, 'collapse')
}

// sidebar_hex_text decodes the lowercase hex a sidebar wrote into an action;
// other spellings of the same bytes are not what it wrote, so they are rejected.
fn sidebar_hex_text(digits string) ?string {
	if digits.len == 0 {
		return none
	}
	bytes := hex.decode(digits) or { return none }
	if bytes.hex() != digits {
		return none
	}
	return bytes.bytestr()
}

// ── Widths ──────────────────────────────────────────────────────────

// sidebar_rail_width is how wide a sidebar collapsed to icons is.
pub fn sidebar_rail_width(size ComponentSize) f64 {
	m := component_metrics(size)
	return m.height + 2 * m.padding
}

// sidebar_width is the width to frame a sidebar with: `expanded` while it is
// open, the rail's width when it is collapsed to icons, and nothing when it is
// collapsed off-canvas.
pub fn sidebar_width(expanded f64, collapsed bool, collapsible SidebarCollapsible, size ComponentSize) f64 {
	if !collapsed || collapsible == .none {
		return expanded
	}
	return if collapsible == .icon { sidebar_rail_width(size) } else { 0.0 }
}

// sidebar_auto_collapsed is GPUI Kit's responsive rule: a sidebar is collapsed
// when the user collapsed it or when the space it is in is narrower than
// breakpoint (sidebar_breakpoint, say). Keep the user's choice in the
// application and pass this as `collapsed`.
pub fn sidebar_auto_collapsed(available f64, breakpoint f64, collapsed bool) bool {
	return collapsed || available < breakpoint
}

fn sidebar_rail(config SidebarConfig) bool {
	return config.collapsed && config.collapsible == .icon
}

fn sidebar_hidden(config SidebarConfig) bool {
	return config.collapsed && config.collapsible == .offcanvas
}

// ── Metrics ─────────────────────────────────────────────────────────

struct SidebarMetrics {
	font      f64
	small     f64
	row       f64 // A top-level item.
	sub_row   f64 // A sub-item.
	row_gap   f64
	label     f64 // A group's label row.
	group_gap f64
	inset     f64 // From the sidebar's edges to its rows.
	inner     f64 // Inside a row, before its icon and after its last part.
	icon      f64
	gap       f64
	radius    f64
	indent    f64 // From a row's left edge to the guide beside its sub-items.
	sub_x     f64 // From a row's left edge to its sub-items.
	block     f64 // The header's and the footer's height.
	button    f64 // The chevron and ⋯ buttons.
	glyph     f64 // The symbols on those buttons.
	badge     f64
	dot       f64
	ring      f64 // The keyboard focus ring.
}

fn sidebar_metrics(size ComponentSize) SidebarMetrics {
	m := component_metrics(size)
	icon := math.round(m.font_size * 1.15)
	indent := m.padding + math.round(icon / 2) - 2
	return SidebarMetrics{
		font:      m.font_size
		small:     m.font_size - 2
		row:       m.height
		sub_row:   m.height - 4
		row_gap:   2
		label:     m.height - 4
		group_gap: m.padding
		inset:     m.padding
		inner:     m.padding
		icon:      icon
		gap:       m.padding
		radius:    m.radius
		indent:    indent
		sub_x:     indent + 1 + m.padding + 2
		block:     m.height + 2 * m.padding
		button:    m.height - 8
		glyph:     math.round(m.font_size * 0.9)
		badge:     math.round(m.font_size + 4)
		dot:       math.round(m.font_size / 2)
		ring:      2
	}
}

// ── Model ───────────────────────────────────────────────────────────

// SidebarIndex knows every item, shown or not: where it is and what it is under.
struct SidebarIndex {
mut:
	items   map[string]SidebarItem
	parents map[string]string // Item id to the id of the item it is under, or ''.
	group   map[string]int    // Item id to the index of its group.
	groups  map[string]int    // Group id to its index.
}

fn sidebar_validate_block(name string, title string, icon string, menu bool, menu_icon string, height f64) ! {
	if icon.len > 0 && !symbol_known(icon) {
		return error('sidebar ${name} uses `${icon}`, which not every renderer can draw; pick a name from symbol_names()')
	}
	if menu && menu_icon.len > 0 && !symbol_known(menu_icon) {
		return error('sidebar ${name} menu icon `${menu_icon}` is not a known symbol')
	}
	if !component_finite(height) || height < 0 {
		return error('sidebar ${name} height must be finite and non-negative')
	}
	if menu && title.trim_space().len == 0 {
		return error('a sidebar ${name} with a menu needs a title to name it')
	}
}

fn (mut index SidebarIndex) add_items(items []SidebarItem, group int, parent string) ! {
	for item in items {
		if item.id.trim_space().len == 0 {
			return error('sidebar item `${item.label}` has no id')
		}
		if item.id in index.items || item.id in index.groups {
			return error('duplicate sidebar id `${item.id}`')
		}
		if item.label.trim_space().len == 0 {
			return error('sidebar item `${item.id}` has no label')
		}
		if item.icon.len > 0 && !symbol_known(item.icon) {
			return error('sidebar item `${item.id}` uses `${item.icon}`, which not every renderer can draw; pick a name from symbol_names()')
		}
		if !component_finite(item.accessory_width) || item.accessory_width < 0 {
			return error('sidebar item `${item.id}` accessory width must be finite and non-negative')
		}
		for entry in item.menu {
			if entry.id.trim_space().len == 0 || entry.title.trim_space().len == 0 {
				return error('sidebar item `${item.id}` menu entries need an id and a title')
			}
		}
		index.items[item.id] = item
		index.parents[item.id] = parent
		index.group[item.id] = group
		index.add_items(item.children, group, item.id)!
	}
}

fn sidebar_index(config SidebarConfig) !SidebarIndex {
	mut index := SidebarIndex{}
	for g, group in config.groups {
		if group.id.len > 0 {
			if group.id.trim_space().len == 0 || group.id in index.groups {
				return error('sidebar group ids must be unique and not blank')
			}
			index.groups[group.id] = g
		} else if group.collapsible {
			return error('collapsible sidebar group `${group.label}` needs an id')
		}
		if group.collapsible && group.label.trim_space().len == 0 {
			return error('collapsible sidebar group `${group.id}` needs a label to press')
		}
	}
	for g, group in config.groups {
		index.add_items(group.items, g, '')!
	}
	header := config.header
	footer := config.footer
	sidebar_validate_block('header', header.title, header.icon, header.menu, header.menu_icon,
		header.height)!
	sidebar_validate_block('footer', footer.title, footer.icon, footer.menu, footer.menu_icon,
		footer.height)!
	if !component_finite(config.offset) {
		return error('sidebar offset must be finite')
	}
	return index
}

// ancestors lists the items an item is under, nearest first.
fn (index SidebarIndex) ancestors(item_id string) []string {
	mut chain := []string{}
	mut at := index.parents[item_id] or { return chain }
	for at.len > 0 && chain.len <= index.items.len {
		chain << at
		at = index.parents[at] or { break }
	}
	return chain
}

enum SidebarRowKind {
	label   // A group's label.
	item    // An item or a sub-item.
	divider // The line between groups in the rail.
	guide   // The line beside a list of sub-items.
}

struct SidebarRow {
	kind   SidebarRowKind
	group  int
	item   SidebarItem
	depth  int
	parent string
	frame  Rect // In the coordinates of the groups' content.
}

// SidebarBlock is a header or a footer.
struct SidebarBlock {
	title        string
	subtitle     string
	icon         string
	avatar       string
	avatar_image string
	menu         bool
	menu_icon    string
	children     []Element
	height       f64
}

fn sidebar_header_block(header SidebarHeader) SidebarBlock {
	return SidebarBlock{
		title:        header.title
		subtitle:     header.subtitle
		icon:         header.icon
		avatar:       header.avatar
		avatar_image: header.avatar_image
		menu:         header.menu
		menu_icon:    header.menu_icon
		children:     header.children
		height:       header.height
	}
}

fn sidebar_footer_block(footer SidebarFooter) SidebarBlock {
	return SidebarBlock{
		title:        footer.title
		subtitle:     footer.subtitle
		icon:         footer.icon
		avatar:       footer.avatar
		avatar_image: footer.avatar_image
		menu:         footer.menu
		menu_icon:    footer.menu_icon
		children:     footer.children
		height:       footer.height
	}
}

fn (block SidebarBlock) present() bool {
	return block.title.len > 0 || block.subtitle.len > 0 || block.icon.len > 0
		|| block.avatar.len > 0 || block.avatar_image.len > 0 || block.children.len > 0
}

struct SidebarModel {
	index   SidebarIndex
	metrics SidebarMetrics
	rail    bool
	rows    []SidebarRow
	content f64  // How tall the groups' content is.
	header  Rect // Sidebar-local; empty without a header.
	footer  Rect
	body    Rect // Sidebar-local: where the groups scroll.
	scrolls bool
	current string // The item drawn as current: the active one, or the nearest shown item it is under.
}

struct SidebarLayout {
	config SidebarConfig
	m      SidebarMetrics
	rail   bool
mut:
	rows []SidebarRow
}

fn (mut layout SidebarLayout) add(items []SidebarItem, group int, depth int, parent string, x f64, width f64, top f64) f64 {
	m := layout.m
	mut y := top
	for item in items {
		height := if depth == 0 { m.row } else { m.sub_row }
		layout.rows << SidebarRow{
			kind:   .item
			group:  group
			item:   item
			depth:  depth
			parent: parent
			frame:  rect(x, y, width, height)
		}
		y += height + m.row_gap
		if !layout.rail && item.children.len > 0 && item.id in layout.config.state.expanded {
			start := y
			y = layout.add(item.children, group, depth + 1, item.id, x + m.sub_x, math.max(width - m.sub_x,
				0), y)
			layout.rows << SidebarRow{
				kind:   .guide
				group:  group
				item:   item
				depth:  depth
				parent: item.id
				frame:  rect(x + m.indent, start, 1, math.max(y - start - m.row_gap, 0))
			}
		}
	}
	return y
}

fn sidebar_block_height(block SidebarBlock, rail bool, m SidebarMetrics) f64 {
	if rail {
		return m.row
	}
	return if block.height > 0 { block.height } else { m.block }
}

fn sidebar_model(config SidebarConfig) !SidebarModel {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	index := sidebar_index(config)!
	m := sidebar_metrics(config.size)
	rail := sidebar_rail(config)
	width := config.frame.width
	height := config.frame.height
	edge := if config.border { math.min(1.0, width) } else { 0.0 }
	content_x := if config.side == .right { edge } else { 0.0 }
	content_width := math.max(width - edge, 0)
	// Rows sit `inset` from the outer edge; in the rail they are squares, and
	// the border may take a point of the inset on the inner side.
	row_width := if rail {
		math.min(m.row, math.max(width - 2 * m.inset, 0))
	} else {
		math.max(content_width - 2 * m.inset, 0)
	}
	row_x := if rail && config.side == .right {
		math.max(width - m.inset - row_width, 0)
	} else {
		content_x + math.min(m.inset, content_width / 2)
	}
	header_block := sidebar_header_block(config.header)
	footer_block := sidebar_footer_block(config.footer)
	mut top := 0.0
	mut header := rect(0, 0, 0, 0)
	if header_block.present() {
		header = rect(row_x, m.inset, row_width, sidebar_block_height(header_block, rail,
			m))
		top = header.y + header.height + m.row_gap * 2
	}
	mut bottom := height
	mut footer := rect(0, 0, 0, 0)
	if footer_block.present() {
		footer_height := sidebar_block_height(footer_block, rail, m)
		footer = rect(row_x, math.max(height - m.inset - footer_height, top), row_width,
			footer_height)
		bottom = footer.y - m.row_gap * 2
	}
	body := rect(content_x, top, content_width, math.max(bottom - top, 0))
	mut layout := SidebarLayout{
		config: config
		m:      m
		rail:   rail
	}
	x := row_x - content_x
	mut y := m.row_gap * 2
	mut drawn := false
	for g, group in config.groups {
		if group.items.len == 0 && (rail || group.label.len == 0) {
			continue
		}
		if drawn {
			if rail {
				layout.rows << SidebarRow{
					kind:  .divider
					group: g
					frame: rect(x + m.row / 4, y + m.group_gap / 2, row_width - m.row / 2,
						1)
				}
				y += m.group_gap + 1
			} else {
				y += m.group_gap
			}
		}
		drawn = true
		if !rail && group.label.len > 0 {
			layout.rows << SidebarRow{
				kind:  .label
				group: g
				frame: rect(x, y, row_width, m.label)
			}
			y += m.label
		}
		// The rail shows no labels to unfold a group with, so it shows every item.
		if !rail && group.collapsible && group.id in config.state.closed_groups {
			continue
		}
		y = layout.add(group.items, g, 0, '', x, row_width, y)
	}
	content := y + m.row_gap * 2
	mut shown := map[string]bool{}
	for row in layout.rows {
		if row.kind == .item {
			shown[row.item.id] = true
		}
	}
	mut current := ''
	active := config.state.active
	if active in index.items {
		if active in shown {
			current = active
		} else {
			for ancestor in index.ancestors(active) {
				if ancestor in shown {
					current = ancestor
					break
				}
			}
		}
	}
	return SidebarModel{
		index:   index
		metrics: m
		rail:    rail
		rows:    layout.rows
		content: content
		header:  header
		footer:  footer
		body:    body
		scrolls: content > body.height + 0.5
		current: current
	}
}

// item_row finds the row an item is shown in.
fn (model SidebarModel) item_row(item_id string) ?SidebarRow {
	for row in model.rows {
		if row.kind == .item && row.item.id == item_id {
			return row
		}
	}
	return none
}

fn (model SidebarModel) label_row(group int) ?SidebarRow {
	for row in model.rows {
		if row.kind == .label && row.group == group {
			return row
		}
	}
	return none
}

// order is what the keyboard moves through, top to bottom: the labels of
// collapsible groups and enabled items.
fn (model SidebarModel) order(config SidebarConfig) []string {
	mut ids := []string{}
	for row in model.rows {
		match row.kind {
			.label {
				group := config.groups[row.group]
				if group.collapsible {
					ids << group.id
				}
			}
			.item {
				if row.item.enabled {
					ids << row.item.id
				}
			}
			else {}
		}
	}
	return ids
}

// scroll_y is the offset the groups are scrolled by, within the range a Scroll
// element has: its content plus the 16 points every backend leaves below it.
fn (model SidebarModel) scroll_y(config SidebarConfig) f64 {
	if !model.scrolls {
		return 0
	}
	return math.min(math.max(config.offset, 0), math.max(model.content - model.body.height + 16,
		0))
}

// ── Item parts ──────────────────────────────────────────────────────

// SidebarItemParts places what a row shows, in the row's coordinates; parts it
// does not show are empty.
struct SidebarItemParts {
	icon      Rect
	text      Rect
	chevron   Rect
	more      Rect
	accessory Rect
	badge     Rect
	suffix    Rect
}

// sidebar_text_width estimates short trailing text. Symbols such as ⌘ and
// arrows are about an em wide and digits and capitals wider than the average
// glyph, so the general estimate would cut a shortcut or a count off.
fn sidebar_text_width(text string, size f64) f64 {
	mut ems := 0.0
	for r in text.runes() {
		ems += if r >= 0x2190 {
			1.0
		} else if (r >= `0` && r <= `9`) || (r >= `A` && r <= `Z`) {
			0.68
		} else {
			0.6
		}
	}
	return ems * font_em_pixels(size)
}

fn sidebar_badge_width(text string, m SidebarMetrics) f64 {
	return math.ceil(math.max(sidebar_text_width(text, m.small) + m.small, m.badge))
}

fn sidebar_more_shown(config SidebarConfig, model SidebarModel, item SidebarItem) bool {
	if !item.more || model.rail {
		return false
	}
	return config.more_always || config.open_menu == item.id || model.current == item.id
		|| config.state.focused == item.id
		|| (item.enabled && config.state.hovered == sidebar_item_action(config.id, item.id))
}

fn sidebar_item_parts(config SidebarConfig, model SidebarModel, row SidebarRow) SidebarItemParts {
	m := model.metrics
	item := row.item
	width := row.frame.width
	height := row.frame.height
	centered := fn [height] (x f64, side f64) Rect {
		return rect(x, math.round((height - side) / 2), side, side)
	}
	if model.rail {
		side := math.min(m.icon, width)
		return SidebarItemParts{
			icon: rect(math.round((width - side) / 2), math.round((height - side) / 2), side,
				side)
		}
	}
	mut left := m.inner
	mut icon := rect(0, 0, 0, 0)
	if item.icon.len > 0 {
		icon = centered(left, m.icon)
		left += m.icon + m.gap
	}
	mut right := width - m.inner / 2
	mut chevron := rect(0, 0, 0, 0)
	if item.children.len > 0 {
		right -= m.button
		chevron = centered(right, m.button)
		right -= 2
	}
	mut more := rect(0, 0, 0, 0)
	if sidebar_more_shown(config, model, item) {
		right -= m.button
		more = centered(right, m.button)
		right -= 2
	}
	if chevron.width == 0 && more.width == 0 {
		right = width - m.inner
	}
	mut accessory := rect(0, 0, 0, 0)
	if item.accessory.len > 0 && item.accessory_width > 0 {
		accessory_width := math.min(item.accessory_width, math.max(right - left, 0))
		right -= accessory_width
		accessory = rect(right, 0, accessory_width, height)
		right -= m.gap
	}
	mut badge_frame := rect(0, 0, 0, 0)
	if item.dot {
		right -= m.dot
		badge_frame = centered(right, m.dot)
		right -= m.gap
	} else if item.badge.len > 0 {
		badge_width := math.min(sidebar_badge_width(item.badge, m), math.max(right - left, 0) / 2)
		right -= badge_width
		badge_frame = rect(right, math.round((height - m.badge) / 2), badge_width, m.badge)
		right -= m.gap
	}
	mut suffix := rect(0, 0, 0, 0)
	if item.suffix.len > 0 {
		wanted := math.ceil(sidebar_text_width(item.suffix, m.small) + 6)
		suffix_width := math.min(wanted, math.max(right - left, 0) / 2)
		right -= suffix_width
		suffix = rect(right, 0, suffix_width, height)
		right -= m.gap / 2
	}
	return SidebarItemParts{
		icon:      icon
		text:      rect(left, 0, math.max(right - left, 0), height)
		chevron:   chevron
		more:      more
		accessory: accessory
		badge:     badge_frame
		suffix:    suffix
	}
}

// ── Anchors ─────────────────────────────────────────────────────────

// sidebar_local_to_outer moves a sidebar-local rectangle into the coordinates
// config.frame is given in.
fn sidebar_local_to_outer(config SidebarConfig, frame Rect) Rect {
	return rect(config.frame.x + frame.x, config.frame.y + frame.y, frame.width, frame.height)
}

fn sidebar_row_outer(config SidebarConfig, model SidebarModel, frame Rect) Rect {
	return sidebar_local_to_outer(config, rect(model.body.x + frame.x, model.body.y + frame.y - model.scroll_y(config),
		frame.width, frame.height))
}

// sidebar_item_anchor is the row an item is shown in, in the coordinates of
// config.frame (window coordinates for a sidebar placed in the screen), for
// anchoring a menu or popover to it; none when it is not shown.
pub fn sidebar_item_anchor(config SidebarConfig, item_id string) ?Rect {
	if sidebar_hidden(config) {
		return none
	}
	model := sidebar_model(config) or { return none }
	row := model.item_row(item_id)?
	return sidebar_row_outer(config, model, row.frame)
}

// sidebar_more_anchor is an item's ⋯ button, in the coordinates of
// config.frame; none when the item has none or is not shown. Pass the item as
// open_menu so the button stays where the menu opened from.
pub fn sidebar_more_anchor(config SidebarConfig, item_id string) ?Rect {
	if sidebar_hidden(config) {
		return none
	}
	model := sidebar_model(config) or { return none }
	row := model.item_row(item_id)?
	parts := sidebar_item_parts(SidebarConfig{
		...config
		open_menu: item_id
	}, model, row)
	if parts.more.width == 0 {
		return none
	}
	return sidebar_row_outer(config, model, rect(row.frame.x + parts.more.x, row.frame.y +
		parts.more.y, parts.more.width, parts.more.height))
}

// sidebar_header_anchor is the header, in the coordinates of config.frame.
pub fn sidebar_header_anchor(config SidebarConfig) ?Rect {
	if sidebar_hidden(config) {
		return none
	}
	model := sidebar_model(config) or { return none }
	if model.header.width == 0 && model.header.height == 0 {
		return none
	}
	return sidebar_local_to_outer(config, model.header)
}

// sidebar_footer_anchor is the footer, in the coordinates of config.frame.
pub fn sidebar_footer_anchor(config SidebarConfig) ?Rect {
	if sidebar_hidden(config) {
		return none
	}
	model := sidebar_model(config) or { return none }
	if model.footer.width == 0 && model.footer.height == 0 {
		return none
	}
	return sidebar_local_to_outer(config, model.footer)
}

// sidebar_reveal_offset is the scroll offset of sidebar_scroll_id(id) that
// brings an item or a group's label into view, scrolling as little as it can
// from config.offset; none when the groups do not scroll or it is not shown.
pub fn sidebar_reveal_offset(config SidebarConfig, target string) ?f64 {
	if sidebar_hidden(config) {
		return none
	}
	model := sidebar_model(config) or { return none }
	if !model.scrolls {
		return none
	}
	mut frame := rect(0, 0, 0, 0)
	if row := model.item_row(target) {
		frame = row.frame
	} else {
		group := model.index.groups[target] or { return none }
		row := model.label_row(group) or { return none }
		frame = row.frame
	}
	viewport := model.body.height
	offset := model.scroll_y(config)
	pad := model.metrics.row_gap * 2
	if frame.y - pad < offset {
		return math.max(frame.y - pad, 0)
	}
	if frame.y + frame.height + pad > offset + viewport {
		return math.max(frame.y + frame.height + pad - viewport, 0)
	}
	return offset
}

// ── Updates ─────────────────────────────────────────────────────────

fn sidebar_toggled(list []string, id string) []string {
	return if id in list { list.filter(it != id) } else { sidebar_with(list, id) }
}

fn sidebar_with(list []string, id string) []string {
	if id in list {
		return list
	}
	mut out := list.clone()
	out << id
	return out
}

// sidebar_press_item is a press on an item, or Enter on it: a rail item with
// sub-items asks for its flyout; any other becomes current, opening or
// toggling its sub-items as its `click` says. It returns none when nothing
// would change.
fn sidebar_press_item(config SidebarConfig, model SidebarModel, row SidebarRow, keyboard bool) ?SidebarStep {
	item := row.item
	now := config.state
	focused := if keyboard { item.id } else { '' }
	if model.rail && item.children.len > 0 {
		return SidebarStep{
			event: .flyout
			state: SidebarState{
				...now
				focused: focused
			}
			item:  item
		}
	}
	expanded := if item.children.len == 0 {
		now.expanded
	} else {
		match item.click {
			.activate { now.expanded }
			.open { sidebar_with(now.expanded, item.id) }
			.toggle { sidebar_toggled(now.expanded, item.id) }
		}
	}
	next := SidebarState{
		...now
		active:   item.id
		expanded: expanded
		focused:  focused
	}
	if next == now {
		return none
	}
	return SidebarStep{
		event: if now.active != item.id { SidebarEvent.activate } else { .expand }
		state: next
		item:  item
	}
}

fn sidebar_toggle_item(config SidebarConfig, row SidebarRow, keyboard bool) SidebarStep {
	return SidebarStep{
		event: .expand
		state: SidebarState{
			...config.state
			expanded: sidebar_toggled(config.state.expanded, row.item.id)
			focused:  if keyboard { row.item.id } else { '' }
		}
		item:  row.item
	}
}

fn sidebar_toggle_group(config SidebarConfig, group SidebarGroup, keyboard bool) SidebarStep {
	return SidebarStep{
		event: .group
		state: SidebarState{
			...config.state
			closed_groups: sidebar_toggled(config.state.closed_groups, group.id)
			focused:       if keyboard { group.id } else { '' }
		}
		group: group
	}
}

// hover_targets are the actions of what highlights under the pointer.
fn (model SidebarModel) hover_targets(config SidebarConfig) []string {
	mut targets := []string{}
	for row in model.rows {
		if row.kind == .item && row.item.enabled {
			targets << sidebar_item_action(config.id, row.item.id)
		} else if row.kind == .label && config.groups[row.group].collapsible {
			targets << sidebar_group_action(config.id, config.groups[row.group].id)
		}
	}
	if config.header.menu && model.header.height > 0 {
		targets << sidebar_header_action(config.id)
	}
	if config.footer.menu && model.footer.height > 0 {
		targets << sidebar_footer_action(config.id)
	}
	return targets
}

// sidebar_toggle_hovered reports whether the pointer is over the collapse
// toggle of the sidebar id, by the state its sidebar_update keeps: pass it as
// the toggle button's `hovered`.
pub fn sidebar_toggle_hovered(state SidebarState, sidebar_id string) bool {
	return sidebar_id.len > 0 && state.hovered == sidebar_collapse_action(sidebar_id)
}

fn sidebar_hover(config SidebarConfig, targets []string, pointer PointerEvent) ?SidebarStep {
	if pointer.phase != 'enter' && pointer.phase != 'leave' {
		return none
	}
	if pointer.action !in targets {
		return none
	}
	now := config.state
	if pointer.phase == 'enter' {
		if now.hovered == pointer.action {
			return none
		}
		return SidebarStep{
			event: .hover
			state: SidebarState{
				...now
				hovered: pointer.action
			}
		}
	}
	if now.hovered != pointer.action {
		return none
	}
	return SidebarStep{
		event: .hover
		state: SidebarState{
			...now
			hovered: ''
		}
	}
}

// sidebar_update applies an event from on_event to a sidebar: presses on
// items, chevrons, ⋯ buttons, group labels, the header, the footer and the
// collapse toggle, and the pointer entering and leaving rows. It returns none
// for events that are not the sidebar's, are malformed, name items or groups
// it does not show or that are disabled, or would change nothing. A press
// clears the keyboard cursor.
pub fn sidebar_update(config SidebarConfig, event string) ?SidebarStep {
	if config.id.len == 0 {
		return none
	}
	collapse_action := sidebar_collapse_action(config.id)
	if config.collapsible != .none {
		if event == collapse_action {
			return SidebarStep{
				event:     .collapse
				state:     config.state
				collapsed: !config.collapsed
			}
		}
		if pointer := parse_pointer_event(event) {
			if pointer.action == collapse_action {
				return sidebar_hover(config, [collapse_action], pointer)
			}
		}
	}
	if sidebar_hidden(config) {
		return none
	}
	model := sidebar_model(config) or { return none }
	if pointer := parse_pointer_event(event) {
		return sidebar_hover(config, model.hover_targets(config), pointer)
	}
	part := component_action_part(config.id, event) or { return none }
	pressed := SidebarState{
		...config.state
		focused: ''
	}
	if part == 'header' || part == 'footer' {
		is_header := part == 'header'
		menu := if is_header { config.header.menu } else { config.footer.menu }
		frame := if is_header { model.header } else { model.footer }
		if !menu || frame.height == 0 {
			return none
		}
		return SidebarStep{
			event: if is_header { SidebarEvent.header } else { .footer }
			state: pressed
		}
	}
	colon := part.index(':') or { return none }
	kind := part[..colon]
	target := sidebar_hex_text(part[colon + 1..]) or { return none }
	if kind == 'group' {
		g := model.index.groups[target] or { return none }
		group := config.groups[g]
		if !group.collapsible || model.rail {
			return none
		}
		return sidebar_toggle_group(config, group, false)
	}
	row := model.item_row(target) or { return none }
	if !row.item.enabled {
		return none
	}
	match kind {
		'item' {
			return sidebar_press_item(config, model, row, false)
		}
		'expand' {
			if model.rail || row.item.children.len == 0 {
				return none
			}
			return sidebar_toggle_item(config, row, false)
		}
		'more' {
			if model.rail || !row.item.more {
				return none
			}
			return SidebarStep{
				event: .more
				state: pressed
				item:  row.item
			}
		}
		else {
			return none
		}
	}
}

// sidebar_item_from_action decodes a press that makes an item current,
// rejecting foreign, malformed and forged actions, items the sidebar does not
// show, disabled items and presses on the item already current.
pub fn sidebar_item_from_action(config SidebarConfig, action string) ?SidebarItem {
	step := sidebar_update(config, action)?
	return if step.event == .activate { step.item } else { none }
}

// sidebar_expanded_from_action decodes a press on an item's chevron, or on an
// item whose press shows its sub-items, into the next expanded list.
pub fn sidebar_expanded_from_action(config SidebarConfig, action string) ?[]string {
	step := sidebar_update(config, action)?
	if (step.event != .expand && step.event != .activate) || step.state.expanded == config.state.expanded {
		return none
	}
	return step.state.expanded
}

// sidebar_closed_groups_from_action decodes a press on a collapsible group's
// label into the next closed_groups list.
pub fn sidebar_closed_groups_from_action(config SidebarConfig, action string) ?[]string {
	step := sidebar_update(config, action)?
	return if step.event == .group { step.state.closed_groups } else { none }
}

// sidebar_collapsed_from_action decodes the collapse toggle of the sidebar id
// into the next collapsed value.
pub fn sidebar_collapsed_from_action(id string, collapsed bool, action string) ?bool {
	if id.len == 0 || action != sidebar_collapse_action(id) {
		return none
	}
	return !collapsed
}

// sidebar_select makes an item current from outside the sidebar (a flyout
// menu, a route, a search): it shows the item by unfolding its group and
// expanding the items it is under. It returns none for ids the sidebar does
// not have and disabled items.
pub fn sidebar_select(config SidebarConfig, item_id string) ?SidebarState {
	index := sidebar_index(config) or { return none }
	item := index.items[item_id] or { return none }
	if !item.enabled {
		return none
	}
	mut expanded := config.state.expanded.clone()
	for ancestor in index.ancestors(item_id) {
		expanded = sidebar_with(expanded, ancestor)
	}
	group := config.groups[index.group[item_id] or { 0 }]
	return SidebarState{
		...config.state
		active:        item_id
		expanded:      expanded
		closed_groups: config.state.closed_groups.filter(it != group.id || group.id.len == 0)
	}
}

// sidebar_flyout_items turns an item's sub-items into dropdown menu rows, for
// showing them beside a collapsed rail: a dropdown_menu anchored at
// sidebar_item_anchor on the side facing the content. The current item is
// checked; choosing a row names a sidebar item, so pass its id to
// sidebar_select.
pub fn sidebar_flyout_items(config SidebarConfig, item_id string) []DropdownMenuItem {
	index := sidebar_index(config) or { return []DropdownMenuItem{} }
	item := index.items[item_id] or { return []DropdownMenuItem{} }
	return sidebar_menu_rows(item.children, config.state.active)
}

fn sidebar_menu_rows(items []SidebarItem, active string) []DropdownMenuItem {
	mut rows := []DropdownMenuItem{cap: items.len}
	for item in items {
		if item.children.len > 0 {
			rows << DropdownMenuItem{
				...dropdown_menu_submenu(item.label, sidebar_menu_rows(item.children, active))
				icon:    item.icon
				enabled: item.enabled
			}
		} else {
			rows << DropdownMenuItem{
				id:      item.id
				label:   item.label
				icon:    item.icon
				checked: item.id == active
				enabled: item.enabled
			}
		}
	}
	return rows
}

// ── Keyboard ────────────────────────────────────────────────────────

fn sidebar_focus_step(config SidebarConfig, model SidebarModel, target string) SidebarStep {
	if config.follow_focus {
		if row := model.item_row(target) {
			if !(model.rail && row.item.children.len > 0) && config.state.active != target {
				return SidebarStep{
					event:  .activate
					state:  SidebarState{
						...config.state
						active:  target
						focused: target
					}
					item:   row.item
					reveal: true
				}
			}
		}
	}
	return SidebarStep{
		event:  .focus
		state:  SidebarState{
			...config.state
			focused: target
		}
		reveal: true
	}
}

// sidebar_key moves through a sidebar from on_key_event, as through a tree:
// Up and Down go to the previous and next item or collapsible group label
// (without wrapping), Home and End to the first and last. Right shows an item's
// sub-items or unfolds a group, and then goes into them; Left hides them, folds
// the group, or goes up to the item or group above. Enter and Space activate
// the item (or fold the group) under the cursor, and Escape hides the cursor.
// The first key starts from the current item. With follow_focus, moving also
// activates. Consume the key whenever a step comes back; when step.reveal is
// set, scroll to sidebar_reveal_offset(config, step.state.focused).
pub fn sidebar_key(config SidebarConfig, event KeyEvent) ?SidebarStep {
	if event.cmd || event.ctrl || event.alt || event.shift || sidebar_hidden(config) {
		return none
	}
	model := sidebar_model(config) or { return none }
	order := model.order(config)
	if order.len == 0 {
		return none
	}
	now := config.state
	current := order.index(now.focused)
	match event.code {
		.escape {
			if now.focused.len == 0 {
				return none
			}
			return SidebarStep{
				event: .focus
				state: SidebarState{
					...now
					focused: ''
				}
			}
		}
		.up, .down, .home, .end, .page_up, .page_down {
			start := order.index(model.current)
			target := match event.code {
				.down {
					if current >= 0 {
						math.min(current + 1, order.len - 1)
					} else if start >= 0 {
						start
					} else {
						0
					}
				}
				.up {
					if current >= 0 {
						math.max(current - 1, 0)
					} else if start >= 0 {
						start
					} else {
						order.len - 1
					}
				}
				.home, .page_up {
					0
				}
				else {
					order.len - 1
				}
			}
			if target == current {
				return none
			}
			return sidebar_focus_step(config, model, order[target])
		}
		.right, .left, .enter, .kp_enter, .space {
			if current < 0 {
				return none
			}
			id := order[current]
			if g := model.index.groups[id] {
				group := config.groups[g]
				open := group.id !in now.closed_groups
				match event.code {
					.right {
						if !open {
							return sidebar_toggle_group(config, group, true)
						}
						if current + 1 < order.len {
							next := order[current + 1]
							if (model.index.group[next] or { -1 }) == g {
								return sidebar_focus_step(config, model, next)
							}
						}
						return none
					}
					.left {
						return if open { sidebar_toggle_group(config, group, true) } else { none }
					}
					else {
						return sidebar_toggle_group(config, group, true)
					}
				}
			}
			row := model.item_row(id) or { return none }
			item := row.item
			has_children := item.children.len > 0 && !model.rail
			expanded := item.id in now.expanded
			match event.code {
				.right {
					if !has_children {
						return none
					}
					if !expanded {
						return sidebar_toggle_item(config, row, true)
					}
					if current + 1 < order.len {
						next := order[current + 1]
						if (model.index.parents[next] or { '' }) == item.id {
							return sidebar_focus_step(config, model, next)
						}
					}
					return none
				}
				.left {
					if has_children && expanded {
						return sidebar_toggle_item(config, row, true)
					}
					if row.parent.len > 0 && row.parent in order {
						return sidebar_focus_step(config, model, row.parent)
					}
					group := config.groups[row.group]
					if row.depth == 0 && group.collapsible && group.id in order {
						return sidebar_focus_step(config, model, group.id)
					}
					return none
				}
				else {
					return sidebar_press_item(config, model, row, true)
				}
			}
		}
		else {
			return none
		}
	}
}
