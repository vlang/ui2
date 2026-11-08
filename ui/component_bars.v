module ui2

import math

// Bars: the toolbar, the status bar and the title bar. They share one item
// model (BarItem), one way of laying items along an axis, and one look for
// commands, labels and separators; this file holds what they share and
// component_bars_toolbar.v, component_bars_status.v and component_bars_title.v
// hold each bar.
//
// Commands are views with button behavior, not native buttons, so the bar
// decides every color: a native button dims its title when disabled, cannot
// show a pressed (selected) state without being disabled, and centers one line
// of text where a command wants an icon beside its caption.

// BarKind names a bar for bar_metrics.
pub enum BarKind {
	toolbar
	status_bar
	title_bar
}

pub enum BarItemKind {
	command   // A ghost button: an icon, a caption or both.
	label     // Read-only text, with an optional icon.
	separator // A thin line between runs of items.
	spacer    // Flexible space; spacers share what the other items leave.
	custom    // Application elements in a slot of a fixed width.
	group     // A named run of items announced as one unit.
}

// BarItem is one item of a toolbar, status bar or title bar. Build it with
// bar_command, bar_icon_command, bar_label, bar_separator, bar_spacer,
// bar_custom or toolbar_group, and spread it to set the other fields:
// `ui2.BarItem{ ...ui2.bar_icon_command('bold', 'textformat', 'Bold'), selected: true }`.
pub struct BarItem {
pub:
	kind     BarItemKind
	id       string // Stable key. Commands, groups and custom items need one, unique in the bar.
	label    string // A command's caption or a label's text; a group's accessible name.
	icon     string // Symbol name drawn before the caption; see symbol_known.
	tooltip  string // Hover help, and the accessible name of an icon-only command.
	selected bool   // Drawn pressed: a toggle that is on, or the current mode.
	enabled  bool = true
	dropdown bool // Draws a chevron after the content: the command opens a menu.
	muted    bool // Labels: the muted text color.
	bold     bool // Labels: bold text.
	// action_id replaces the action the command emits (by default
	// bar_item_action(bar id, item id)); give a menu trigger
	// dropdown_menu_toggle_action(menu id) so dropdown_menu_update opens its menu.
	action_id string
	// width is a custom item's extent along the bar (required). For commands
	// and labels it overrides the estimate made from the text.
	width               f64
	children            []Element // Custom items: content in item-local coordinates.
	items               []BarItem // Groups: their members.
	accessibility_label string
}

// bar_command is a command with a caption, and an icon before it unless icon is empty.
pub fn bar_command(id string, caption string, icon string) BarItem {
	return BarItem{
		kind:  .command
		id:    id
		label: caption
		icon:  icon
	}
}

// bar_icon_command is an icon-only command. Its tooltip is also its accessible
// name, so always give one.
pub fn bar_icon_command(id string, icon string, tooltip string) BarItem {
	return BarItem{
		kind:    .command
		id:      id
		icon:    icon
		tooltip: tooltip
	}
}

// bar_label is read-only text. It has no hover and answers no click.
pub fn bar_label(caption string) BarItem {
	return BarItem{
		kind:  .label
		label: caption
	}
}

pub fn bar_separator() BarItem {
	return BarItem{
		kind: .separator
	}
}

// bar_spacer pushes the items after it to the far end of the bar.
pub fn bar_spacer() BarItem {
	return BarItem{
		kind: .spacer
	}
}

// bar_custom reserves `width` along the bar for application elements, such as a
// search field or a progress bar. Their frames are relative to the slot, which
// is bar_metrics(...).control high and centered across the bar.
pub fn bar_custom(id string, width f64, children []Element) BarItem {
	return BarItem{
		kind:     .custom
		id:       id
		width:    width
		children: children
	}
}

// toolbar_group gives a run of items one accessible name, so assistive
// technology reads them as a unit ("History": Undo, Redo).
pub fn toolbar_group(id string, caption string, items []BarItem) BarItem {
	return BarItem{
		kind:  .group
		id:    id
		label: caption
		items: items
	}
}

// BarEdges says which edges of a bar carry a divider line.
pub enum BarEdges {
	auto // The bar's default: none for a toolbar, top for a status bar, bottom for a title bar.
	none
	top
	bottom
	top_and_bottom
	all // A border on every side, following `radius`.
}

// BarStyle overrides a bar's surface; what is left unset keeps the bar's default.
pub struct BarStyle {
pub:
	background ?u32     // A toolbar is transparent until given one.
	gradient   Gradient // With two or more stops, fills the bar instead of background.
	foreground ?u32     // Text and icon color.
	border     ?u32     // Divider and border color.
	edges      BarEdges
	radius     f64
	shadow     BoxShadow
}

// BarMetrics is the geometry of one bar size. `height` is the bar height the
// size is designed for; give the bar that frame height (or width, for a vertical
// toolbar). `control` is the height of its commands and custom slots.
pub struct BarMetrics {
pub:
	height        f64
	control       f64
	padding       f64 // From the bar's ends to the first and last item.
	gap           f64 // Between items.
	font_size     f64
	icon          f64
	radius        f64
	inner         f64 // Inside a command, on each side of its content.
	window_button f64 // Title bars: the width of a minimize, maximize or close button.
}

// bar_metrics returns the geometry of a bar. Toolbar sizes follow GPUI Kit's
// xsmall (28), small (32, its default) and medium (48) toolbars; the status
// bar's medium is GPUI Kit's bar of xsmall ghost buttons, and the title bar's
// medium is its 34-point title bar.
pub fn bar_metrics(kind BarKind, size ComponentSize) BarMetrics {
	return match kind {
		.toolbar {
			match size {
				.small { BarMetrics{28, 20, 4, 4, 12, 14, 4, 6, 0} }
				.medium { BarMetrics{32, 24, 4, 4, 13, 15, 5, 8, 0} }
				.large { BarMetrics{48, 32, 8, 8, 14, 17, 6, 10, 0} }
			}
		}
		.status_bar {
			match size {
				.small { BarMetrics{24, 18, 6, 6, 11, 12, 4, 5, 0} }
				.medium { BarMetrics{28, 20, 8, 8, 12, 13, 4, 6, 0} }
				.large { BarMetrics{32, 24, 10, 10, 13, 14, 5, 7, 0} }
			}
		}
		.title_bar {
			match size {
				.small { BarMetrics{28, 20, 8, 4, 12, 14, 4, 6, 40} }
				.medium { BarMetrics{34, 24, 10, 6, 13, 15, 5, 8, 46} }
				.large { BarMetrics{40, 28, 12, 8, 14, 16, 6, 10, 50} }
			}
		}
	}
}

// bar_item_action is the action a bar's command emits unless its action_id
// says otherwise. The item id is hex-encoded, so any id is valid and the
// command keeps its identity when items move.
pub fn bar_item_action(bar_id string, item_id string) string {
	return component_part_id(bar_id, choice_item_part('item:', item_id))
}

fn bars_resolved_action(bar_id string, item BarItem) string {
	return if item.action_id.len > 0 { item.action_id } else { bar_item_action(bar_id, item.id) }
}

// bars_flatten lists the items of every region, with group members after
// their group, in visual order.
fn bars_flatten(items []BarItem) []BarItem {
	mut out := []BarItem{}
	for item in items {
		out << item
		if item.kind == .group {
			out << bars_flatten(item.items)
		}
	}
	return out
}

// bars_validate_items checks a bar's items before anything is drawn: commands,
// groups and custom items need ids, ids are unique across the bar, groups do
// not nest, and custom widths are finite.
fn bars_validate_items(items []BarItem, bar string) ! {
	mut seen := map[string]bool{}
	for item in bars_flatten(items) {
		needs_id := item.kind in [.command, .group, .custom]
		if needs_id && item.id.trim_space().len == 0 {
			return error('${bar} commands, groups and custom items need an id')
		}
		if item.id.len > 0 {
			if item.id in seen {
				return error('${bar} item ids must be unique: `${item.id}`')
			}
			seen[item.id] = true
		}
		if !component_finite(item.width) || item.width < 0 {
			return error('${bar} item widths must be finite and non-negative')
		}
		if item.kind == .group {
			for member in item.items {
				if member.kind == .group {
					return error('${bar} groups cannot contain groups')
				}
			}
		}
	}
}

fn bars_has_commands(items []BarItem) bool {
	for item in bars_flatten(items) {
		if item.kind == .command {
			return true
		}
	}
	return false
}

// bars_item_from_action finds the command an action came from. Disabled
// commands, and every command of a disabled bar, answer nothing.
fn bars_item_from_action(bar_id string, items []BarItem, enabled bool, action string) ?BarItem {
	if !enabled || bar_id.len == 0 || action.len == 0 {
		return none
	}
	for item in bars_flatten(items) {
		if item.kind == .command && bars_resolved_action(bar_id, item) == action {
			return if item.enabled { item } else { none }
		}
	}
	return none
}

// bars_hover_from_event turns a pointer entering or leaving a command into the
// id the bar should draw hovered: the command's id on enter, '' when the
// hovered command is left. extra maps the actions of a bar's own parts (window
// buttons) to the ids they hover as.
fn bars_hover_from_event(bar_id string, items []BarItem, extra map[string]string, current string, event string) ?string {
	pointer := parse_pointer_event(event) or { return none }
	if pointer.phase != 'enter' && pointer.phase != 'leave' {
		return none
	}
	mut target := extra[pointer.action] or { '' }
	if target.len == 0 {
		for item in bars_flatten(items) {
			if item.kind == .command && bars_resolved_action(bar_id, item) == pointer.action {
				target = item.id
				break
			}
		}
	}
	if target.len == 0 {
		return none
	}
	if pointer.phase == 'enter' {
		return if target == current { none } else { target }
	}
	return if target == current { '' } else { none }
}

// ── Measuring and packing ───────────────────────────────────────────

fn bars_icon_gap(m BarMetrics) f64 {
	return math.round(m.font_size * 0.4)
}

fn bars_chevron(m BarMetrics) f64 {
	return math.round(m.font_size * 0.8)
}

// bars_text_width estimates a caption with room to spare. The shared estimate
// is short for digits and symbols in some faces, and a native label insets
// its text a little and ends it with an ellipsis rather than overflow, so a
// slot sized to the bare estimate would cut short words such as "View".
fn bars_text_width(caption string, m BarMetrics) f64 {
	if caption.len == 0 {
		return 0.0
	}
	return math.ceil(component_text_width_estimate(caption, m.font_size) * 1.08 + 6)
}

// bars_caption_extent is a closer estimate of a caption's width than the
// shared one, by glyph class: narrow letters, wide ones, capitals and digits
// differ by a factor of three. Slots keep the shared estimate, which errs wide;
// this one only places what follows a caption, such as a dropdown's chevron.
fn bars_caption_extent(caption string, size f64) f64 {
	mut ems := 0.0
	for r in caption.runes() {
		ems += if r >= 0x2e80 {
			1.0
		} else if r in [` `, `i`, `l`, `j`, `!`, `|`, `.`, `,`, `:`, `;`, `'`] {
			0.28
		} else if r in [`f`, `t`, `r`, `I`, `(`, `)`, `-`] {
			0.38
		} else if r in [`m`, `w`] {
			0.85
		} else if r in [`M`, `W`, `%`] {
			0.9
		} else if r >= `0` && r <= `9` {
			0.6
		} else if r >= `A` && r <= `Z` {
			0.68
		} else if r >= `a` && r <= `z` {
			0.55
		} else {
			0.62
		}
	}
	return ems * font_em_pixels(size)
}

// bars_content_width estimates an icon, a caption and a chevron side by side.
fn bars_content_width(caption string, icon string, chevron bool, m BarMetrics) f64 {
	mut width := bars_text_width(caption, m)
	if icon.len > 0 {
		width += m.icon + if caption.len > 0 { bars_icon_gap(m) } else { 0.0 }
	}
	if chevron {
		width += bars_chevron(m) + if width > 0 { bars_icon_gap(m) / 2 } else { 0.0 }
	}
	return width
}

// bars_extent is how much room an item takes along the bar.
fn bars_extent(item BarItem, m BarMetrics, vertical bool) f64 {
	return match item.kind {
		.command {
			if item.width > 0 {
				item.width
			} else if vertical || (item.label.len == 0 && !item.dropdown) {
				m.control
			} else {
				math.max(m.control, math.ceil(bars_content_width(item.label, item.icon,
					item.dropdown, m) + 2 * m.inner))
			}
		}
		.label {
			if item.width > 0 {
				item.width
			} else if vertical {
				m.control
			} else {
				bars_content_width(item.label, item.icon, false, m)
			}
		}
		.separator {
			m.gap + 1
		}
		.spacer {
			0.0
		}
		.custom {
			item.width
		}
		.group {
			bars_run_extent(item.items, m, vertical)
		}
	}
}

// bars_run_extent is the natural length of items laid out with the bar's gap.
fn bars_run_extent(items []BarItem, m BarMetrics, vertical bool) f64 {
	mut total := 0.0
	for index, item in items {
		total += bars_extent(item, m, vertical) + if index > 0 { m.gap } else { 0.0 }
	}
	return total
}

// BarPlacement is where one item of a run went along the bar's main axis.
struct BarPlacement {
	offset f64
	extent f64
	shown  bool
}

// bars_pack lays items along `room` from `start`. Items are kept in order while
// they fit; the first that does not is left out with everything after it, so
// nothing overlaps and the order never changes. Spacers share the room the
// others leave. Offsets are whole points, so lines stay crisp.
fn bars_pack(items []BarItem, start f64, room f64, m BarMetrics, vertical bool) []BarPlacement {
	extents := items.map(bars_extent(it, m, vertical))
	mut shown := []bool{len: items.len}
	mut used := 0.0
	mut count := 0
	mut spacers := 0
	for index, extent in extents {
		need := used + extent + if count > 0 { m.gap } else { 0.0 }
		if need > room + 0.01 {
			break
		}
		used = need
		shown[index] = true
		count++
		if items[index].kind == .spacer {
			spacers++
		}
	}
	left_over := math.max(room - used, 0.0)
	share := if spacers > 0 { left_over / f64(spacers) } else { 0.0 }
	mut placements := []BarPlacement{cap: items.len}
	mut position := start
	mut first := true
	for index, item in items {
		if !shown[index] {
			placements << BarPlacement{}
			continue
		}
		if !first {
			position += m.gap
		}
		first = false
		extent := if item.kind == .spacer { share } else { extents[index] }
		left := math.round(position)
		placements << BarPlacement{
			offset: left
			extent: math.max(math.round(position + extent) - left, 0.0)
			shown:  true
		}
		position += extent
	}
	return placements
}

// bars_pack_end packs items against the far end of the room, so when they do
// not all fit it is the ones nearest the middle of the bar that go.
fn bars_pack_end(items []BarItem, end f64, room f64, m BarMetrics, vertical bool) []BarPlacement {
	reversed := items.reverse()
	packed := bars_pack(reversed, 0, room, m, vertical)
	mut placements := []BarPlacement{len: items.len}
	for index, placement in packed {
		target := items.len - 1 - index
		placements[target] = if placement.shown {
			BarPlacement{
				offset: end - placement.offset - placement.extent
				extent: placement.extent
				shown:  true
			}
		} else {
			placement
		}
	}
	return placements
}

// bars_used is the span shown items cover, from the first offset to the end
// of the last; zero when nothing is shown.
fn bars_used(placements []BarPlacement) (f64, f64) {
	mut low := math.max_f64
	mut high := -math.max_f64
	for placement in placements {
		if placement.shown {
			low = math.min(low, placement.offset)
			high = math.max(high, placement.offset + placement.extent)
		}
	}
	return if high < low { 0.0, 0.0 } else { low, high }
}

// bars_shift moves every shown placement by delta.
fn bars_shift(placements []BarPlacement, delta f64) []BarPlacement {
	return placements.map(if it.shown {
		BarPlacement{
			offset: math.round(it.offset + delta)
			extent: it.extent
			shown:  true
		}
	} else {
		it
	})
}

// bars_cross_frame turns a placement into a bar-local frame. Commands and
// custom slots are `control` across and centered; labels take the bar's whole
// breadth so their text centers too; separators get a line of their own.
fn bars_cross_frame(item BarItem, placement BarPlacement, breadth f64, m BarMetrics, vertical bool) Rect {
	across := match item.kind {
		.label, .separator, .spacer {
			breadth
		}
		.command {
			if vertical && (item.label.len > 0 || item.dropdown) {
				math.max(breadth - 2 * m.padding, m.control)
			} else {
				m.control
			}
		}
		.custom, .group {
			m.control
		}
	}
	size := math.min(across, breadth)
	cross := math.round((breadth - size) / 2)
	return if vertical {
		rect(cross, placement.offset, size, placement.extent)
	} else {
		rect(placement.offset, cross, placement.extent, size)
	}
}

// bars_overflow lists the commands a layout left out, groups included, so an
// application can offer them in an overflow menu.
fn bars_overflow(items []BarItem, placements []BarPlacement) []string {
	mut ids := []string{}
	for index, item in items {
		if index < placements.len && placements[index].shown {
			continue
		}
		for hidden in bars_flatten([item]) {
			if hidden.kind == .command {
				ids << hidden.id
			}
		}
	}
	return ids
}

// ── Drawing ─────────────────────────────────────────────────────────

// BarLook is what every item of one bar is drawn with.
struct BarLook {
	bar_id     string
	theme      ComponentTheme
	metrics    BarMetrics
	foreground u32
	muted      u32
	surface    u32 // The color under the items, for the inside of a focus ring.
	enabled    bool
	hovered    string
	focused    string
	vertical   bool
	region     string // Prefixes keys, so items of different regions never share one.
}

fn bars_is_dark(theme ComponentTheme) bool {
	return choice_luminance(theme.background) < 0.18
}

// bars_divider is the line color of a bar's edge: the theme border, softened
// toward the background so a bar reads as part of the window.
fn bars_divider(theme ComponentTheme) u32 {
	return choice_mix(theme.border, theme.background, if bars_is_dark(theme) { 0.2 } else { 0.35 })
}

fn bars_disabled(theme ComponentTheme) u32 {
	return choice_disabled_text(theme)
}

// bars_overlay is the translucent fill a command shows when it is hovered or
// selected. It tints whatever is under the bar, so it works on any surface.
fn bars_overlay(frame Rect, radius f64, color u32, opacity f64) Element {
	return view('', frame, BoxStyle{
		bg:      color
		radius:  radius
		opacity: opacity
	}, []Element{})
}

fn bars_overlay_opacity(selected bool, hovered bool, enabled bool, dark bool) f64 {
	scale := if dark { 1.25 } else { 1.0 }
	if !enabled {
		return if selected { 0.06 * scale } else { 0.0 }
	}
	base := if selected && hovered {
		0.2
	} else if selected {
		0.13
	} else if hovered {
		0.08
	} else {
		0.0
	}
	return base * scale
}

// bars_focus_ring draws a two-point ring in the primary color with the
// surface inside it, so the content and overlay drawn next sit inside the ring.
fn bars_focus_ring(local Rect, radius f64, look BarLook) []Element {
	mut shapes := choice_shape(local, radius, look.theme.primary, .all, false)
	inner := rect(local.x + 2, local.y + 2, math.max(local.width - 4, 0.0), math.max(local.height - 4,
		0.0))
	shapes << choice_shape(inner, math.max(radius - 2, 0.0), look.surface, .all, false)
	return shapes
}

fn bars_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

// bars_content lays out an icon, a caption and a chevron in an item-local
// frame. A caption alone is centered in the frame; after an icon it is
// left-aligned, since only an estimate of its width is known, and the icon and
// caption are centered as a pair on that estimate when `center`. The chevron
// keeps to the trailing edge.
fn bars_content(item BarItem, local Rect, color u32, m BarMetrics, center bool) []Element {
	alone := item.icon.len == 0 && !item.dropdown
	style := TextStyle{
		color: color
		size:  m.font_size
		bold:  item.bold
		align: if center && alone { Align.center } else { Align.left }
	}
	icon_size := math.min(m.icon, math.min(local.width, local.height))
	chevron := if item.dropdown { math.min(bars_chevron(m), local.width) } else { 0.0 }
	content := bars_content_width(item.label, item.icon, item.dropdown, m)
	pad := if item.kind == .command { math.min(m.inner, local.width / 2) } else { 0.0 }
	mut x := if center { math.max(pad, math.round((local.width - content) / 2)) } else { pad }
	mut children := []Element{}
	if item.icon.len > 0 {
		icon_x := math.min(x, math.max(local.width - icon_size, 0.0))
		children << bars_symbol(item.icon, rect(icon_x, math.round((local.height - icon_size) / 2),
			icon_size, icon_size), color)
		x = icon_x + icon_size + if item.label.len > 0 { bars_icon_gap(m) } else { 0.0 }
	}
	chevron_x := math.max(local.width - pad - chevron, 0.0)
	if item.label.len > 0 {
		// The caption may use the padding on its trailing side: a native
		// label ends in an ellipsis long before its text reaches the edge.
		left := if style.align == .center { pad / 2 } else { math.min(x, local.width) }
		end := if chevron > 0 {
			chevron_x - bars_icon_gap(m) / 2
		} else if style.align == .center {
			local.width - pad / 2
		} else {
			local.width
		}
		children << label('', item.label, rect(left, 0, math.max(end - left, 0.0), local.height),
			style)
	}
	if chevron > 0 {
		// Just after the caption's plain estimate, which is close for words;
		// never past the trailing edge, where the caption's room ends.
		trail := x + if item.label.len > 0 {
			bars_caption_extent(item.label, m.font_size) * 1.04 + bars_icon_gap(m) / 2 + 1
		} else {
			0.0
		}
		cx := if item.icon.len == 0 && item.label.len == 0 {
			math.round((local.width - chevron) / 2)
		} else {
			math.round(math.min(trail, chevron_x))
		}
		children << bars_symbol('chevron.down', rect(cx, math.round((local.height - chevron) / 2),
			chevron, chevron), color)
	}
	return children
}

fn bars_command_label(item BarItem) string {
	return if item.accessibility_label.len > 0 {
		item.accessibility_label
	} else if item.label.len > 0 {
		item.label
	} else if item.tooltip.len > 0 {
		item.tooltip
	} else {
		item.id
	}
}

fn bars_command(item BarItem, frame Rect, look BarLook) Element {
	m := look.metrics
	enabled := look.enabled && item.enabled
	hovered := enabled && item.id == look.hovered
	focused := enabled && item.id == look.focused
	color := if enabled { look.foreground } else { bars_disabled(look.theme) }
	local := component_local(frame)
	radius := math.min(m.radius, math.min(local.width, local.height) / 2)
	mut children := []Element{}
	mut inside := local
	if focused {
		children << bars_focus_ring(local, radius, look)
		inside = rect(2, 2, math.max(local.width - 4, 0.0), math.max(local.height - 4, 0.0))
	}
	opacity := bars_overlay_opacity(item.selected, hovered || focused, enabled, bars_is_dark(look.theme))
	if opacity > 0 {
		children << bars_overlay(inside, if focused { math.max(radius - 2, 0.0) } else { radius },
			look.theme.foreground, opacity)
	}
	children << bars_content(item, local, color, m, true)
	el := button_view(component_part_id(look.bar_id, choice_item_part('item:', item.id)),
		frame, BoxStyle{ transparent: true }, children)
	return Element{
		...el
		key:                 look.region + 'item:' + item.id
		action_id:           bars_resolved_action(look.bar_id, item)
		enabled:             enabled
		hoverable:           true
		tooltip:             item.tooltip
		accessibility_role:  'button'
		accessibility_label: bars_command_label(item)
		accessibility_value: if item.selected { 'selected' } else { '' }
	}
}

fn bars_label(item BarItem, frame Rect, look BarLook, index int) Element {
	color := if item.muted { look.muted } else { look.foreground }
	name := if item.id.len > 0 { 'label:' + item.id } else { 'label#${index}' }
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, bars_content(item, component_local(frame),
			color, look.metrics, look.vertical))
		key:                 look.region + name
		accessibility_role:  'text'
		accessibility_label: if item.accessibility_label.len > 0 {
			item.accessibility_label
		} else {
			item.label
		}
	}
}

fn bars_separator(frame Rect, look BarLook, index int) Element {
	m := look.metrics
	line := if look.vertical {
		length := math.round(math.min(m.control * 0.75, math.max(frame.width - 4, 0.0)))
		rect(math.round((frame.width - length) / 2), math.floor(frame.height / 2), length, 1)
	} else {
		length := math.round(math.min(m.control * 0.75, math.max(frame.height - 4, 0.0)))
		rect(math.floor(frame.width / 2), math.round((frame.height - length) / 2), 1, length)
	}
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, [
			view('', choice_fit(line, frame.width, frame.height), BoxStyle{
				bg: bars_divider(look.theme)
			}, []Element{}),
		])
		key:                look.region + 'separator#${index}'
		accessibility_role: 'separator'
	}
}

fn bars_custom(item BarItem, frame Rect, look BarLook) Element {
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, item.children)
		key: look.region + 'custom:' + item.id
	}
}

// bars_group_room is the room a group's members are packed in again. Its slot
// was rounded to whole points, which must not cost the last member its place.
fn bars_group_room(item BarItem, placement BarPlacement, m BarMetrics, vertical bool) f64 {
	return math.max(placement.extent, bars_run_extent(item.items, m, vertical)) + 0.5
}

// bars_items draws a packed run of items; group members are packed again
// inside their group's slot.
fn bars_items(items []BarItem, placements []BarPlacement, breadth f64, look BarLook) []Element {
	m := look.metrics
	mut out := []Element{}
	for index, item in items {
		placement := placements[index]
		if !placement.shown || item.kind == .spacer {
			continue
		}
		frame := bars_cross_frame(item, placement, breadth, m, look.vertical)
		match item.kind {
			.command {
				out << bars_command(item, frame, look)
			}
			.label {
				out << bars_label(item, frame, look, index)
			}
			.separator {
				out << bars_separator(frame, look, index)
			}
			.custom {
				out << bars_custom(item, frame, look)
			}
			.group {
				// The group spans the bar's breadth so its separators and labels
				// line up with the ones outside it.
				slot := if look.vertical {
					rect(0, placement.offset, breadth, placement.extent)
				} else {
					rect(placement.offset, 0, placement.extent, breadth)
				}
				inner := bars_pack(item.items, 0, bars_group_room(item, placement, m, look.vertical),
					m, look.vertical)
				member_look := BarLook{
					...look
					region: ''
				}
				out << Element{
					...view('', slot, BoxStyle{ transparent: true }, bars_items(item.items,
						inner, breadth, member_look))
					key:                 look.region + 'group:' + item.id
					accessibility_role:  'group'
					accessibility_label: item.label
				}
			}
			.spacer {}
		}
	}
	return out
}

// bars_item_frames finds where each shown item of a packed run went, group
// members included, in bar-local coordinates.
fn bars_item_frames(items []BarItem, placements []BarPlacement, breadth f64, m BarMetrics, vertical bool, mut frames map[string]Rect) {
	for index, item in items {
		placement := placements[index]
		if !placement.shown || item.id.len == 0 {
			continue
		}
		if item.kind == .group {
			inner := bars_pack(item.items, 0, bars_group_room(item, placement, m, vertical), m,
				vertical)
			shifted := bars_shift(inner, placement.offset)
			bars_item_frames(item.items, shifted, breadth, m, vertical, mut frames)
			frames[item.id] = if vertical {
				rect(0, placement.offset, breadth, placement.extent)
			} else {
				rect(placement.offset, 0, placement.extent, breadth)
			}
			continue
		}
		frames[item.id] = bars_cross_frame(item, placement, breadth, m, vertical)
	}
}

// bars_surface draws a bar's fill, divider lines and border as its first
// children. The lines are views of their own, so they are one point wide and
// square on every renderer.
fn bars_surface(width f64, height f64, fill ?u32, gradient Gradient, border u32, edges BarEdges, radius f64, shadow BoxShadow) []Element {
	if width <= 0 || height <= 0 {
		return []Element{}
	}
	local := rect(0, 0, width, height)
	r := math.max(0.0, math.min(radius, math.min(width, height) / 2))
	has_gradient := gradient.stops.len >= 2
	mut out := []Element{}
	filled := has_gradient || fill != none
	if edges == .all && filled {
		// A border-colored shape under an inset fill keeps rounded corners
		// alike on every renderer; a BoxStyle border would not.
		out << view('', local, BoxStyle{
			bg:     border
			radius: r
			shadow: shadow
		}, []Element{})
		out << view('', rect(1, 1, math.max(width - 2, 0.0), math.max(height - 2, 0.0)),
			bars_fill_box(fill, gradient, math.max(r - 1, 0.0)), []Element{})
		return out
	}
	if filled {
		out << view('', local, BoxStyle{
			...bars_fill_box(fill, gradient, r)
			shadow: shadow
		}, []Element{})
	}
	if edges in [.top, .top_and_bottom, .all] {
		out << view('', rect(0, 0, width, 1), BoxStyle{ bg: border }, []Element{})
	}
	if edges in [.bottom, .top_and_bottom, .all] {
		out << view('', rect(0, height - 1, width, 1), BoxStyle{ bg: border }, []Element{})
	}
	if edges == .all {
		out << view('', rect(0, 0, 1, height), BoxStyle{ bg: border }, []Element{})
		out << view('', rect(width - 1, 0, 1, height), BoxStyle{ bg: border }, []Element{})
	}
	return out
}

fn bars_fill_box(fill ?u32, gradient Gradient, radius f64) BoxStyle {
	if gradient.stops.len >= 2 {
		return BoxStyle{
			gradient: gradient
			radius:   radius
		}
	}
	if color := fill {
		return BoxStyle{
			bg:     color
			radius: radius
		}
	}
	return BoxStyle{
		transparent: true
		radius:      radius
	}
}

// bars_surface_color is the color a bar's items sit on, for focus rings.
fn bars_surface_color(fill ?u32, gradient Gradient, fallback u32) u32 {
	if gradient.stops.len >= 2 {
		return gradient.stops[gradient.stops.len - 1].color
	}
	return fill or { fallback }
}
