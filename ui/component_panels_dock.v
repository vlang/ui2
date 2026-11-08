module ui2

import math
import strconv

// Dock layouts after GPUI Kit's Dock. A layout is a plain value: the center
// region and the left, right and bottom docks, each a row or a column of tab
// groups. Build it, compare it, save it with dock_layout_encode and restore it
// with dock_layout_decode; every operation below returns a new layout and
// leaves the one passed in alone. dock_area draws a layout and its decoders
// return the layout after what the user did.

pub enum DockPlacement {
	center
	left
	right
	bottom
}

// dock_placements lists the regions in the order a layout is drawn and saved.
pub fn dock_placements() []DockPlacement {
	return [DockPlacement.center, .left, .right, .bottom]
}

pub fn (placement DockPlacement) name() string {
	return match placement {
		.center { 'center' }
		.left { 'left' }
		.right { 'right' }
		.bottom { 'bottom' }
	}
}

// title is how a placement is named in the panel menu.
pub fn (placement DockPlacement) title() string {
	return match placement {
		.center { 'Center' }
		.left { 'Left Dock' }
		.right { 'Right Dock' }
		.bottom { 'Bottom Dock' }
	}
}

// split_axis is the direction a region's groups follow: the center and the
// bottom dock put them side by side, the side docks stack them.
pub fn (placement DockPlacement) split_axis() Orientation {
	return match placement {
		.left, .right { .vertical }
		.center, .bottom { .horizontal }
	}
}

pub fn dock_placement_from_name(name string) ?DockPlacement {
	return match name {
		'center' { DockPlacement.center }
		'left' { DockPlacement.left }
		'right' { DockPlacement.right }
		'bottom' { DockPlacement.bottom }
		else { none }
	}
}

// DockGroup is a tab group: panels shown one at a time.
pub struct DockGroup {
pub:
	panels []string // Panel ids, in tab order.
	active int      // The tab displayed.
	// size is the group's extent along its region's split; 0 shares what the
	// sized groups leave.
	size f64
}

// DockRegion is the center or one dock: its groups, whether a dock is open, and
// its size. A closed dock keeps its groups and its size, so opening it restores
// both.
pub struct DockRegion {
pub:
	groups []DockGroup
	open   bool = true
	// size is a side dock's width or the bottom dock's height; 0 uses the dock
	// area's default. The center takes what the docks leave.
	size f64
}

// DockLayout is a whole dock area's arrangement, the value an application
// saves and restores. Panels are named by the ids of the application's
// DockPanel entries.
pub struct DockLayout {
pub:
	version int // The application's layout schema version; see dock_layout_decode.
	center  DockRegion
	left    DockRegion
	right   DockRegion
	bottom  DockRegion
	// zoomed names a panel whose group fills the whole area, or ''.
	zoomed string
}

// DockPanelLocation is where a panel sits in a layout.
pub struct DockPanelLocation {
pub:
	placement DockPlacement
	group     int
	index     int
}

pub fn (layout DockLayout) region(placement DockPlacement) DockRegion {
	return match placement {
		.center { layout.center }
		.left { layout.left }
		.right { layout.right }
		.bottom { layout.bottom }
	}
}

fn (layout DockLayout) with_region(placement DockPlacement, region DockRegion) DockLayout {
	return match placement {
		.center {
			DockLayout{
				...layout
				center: region
			}
		}
		.left {
			DockLayout{
				...layout
				left: region
			}
		}
		.right {
			DockLayout{
				...layout
				right: region
			}
		}
		.bottom {
			DockLayout{
				...layout
				bottom: region
			}
		}
	}
}

// has_panels reports whether a region holds any panel.
pub fn (region DockRegion) has_panels() bool {
	for group in region.groups {
		if group.panels.len > 0 {
			return true
		}
	}
	return false
}

// panel_count is how many panels a region holds.
pub fn (region DockRegion) panel_count() int {
	mut count := 0
	for group in region.groups {
		count += group.panels.len
	}
	return count
}

// active_panel is the panel a group displays, or '' for an empty group.
pub fn (group DockGroup) active_panel() string {
	if group.panels.len == 0 {
		return ''
	}
	return group.panels[dock_clamp_index(group.active, group.panels.len)]
}

fn dock_clamp_index(index int, count int) int {
	return if count <= 0 || index < 0 {
		0
	} else if index >= count {
		count - 1
	} else {
		index
	}
}

fn dock_clean_size(size f64) f64 {
	return if component_finite(size) && size > 0 { size } else { 0 }
}

// dock_layout_find returns where a panel is.
pub fn dock_layout_find(layout DockLayout, panel string) ?DockPanelLocation {
	if panel.len == 0 {
		return none
	}
	for placement in dock_placements() {
		for g, group in layout.region(placement).groups {
			for i, id in group.panels {
				if id == panel {
					return DockPanelLocation{
						placement: placement
						group:     g
						index:     i
					}
				}
			}
		}
	}
	return none
}

// dock_layout_panels lists every panel in the layout, region by region.
pub fn dock_layout_panels(layout DockLayout) []string {
	mut ids := []string{}
	for placement in dock_placements() {
		for group in layout.region(placement).groups {
			ids << group.panels
		}
	}
	return ids
}

// dock_layout_is_open reports whether a region shows its content: the center
// always does when it has panels, a dock when it has panels and is open.
pub fn dock_layout_is_open(layout DockLayout, placement DockPlacement) bool {
	region := layout.region(placement)
	return region.has_panels() && (placement == .center || region.open)
}

// dock_layout_normalized returns a well-formed layout: empty and repeated
// panel ids are dropped (the first place a panel appears wins), empty groups
// are removed, every active index names a tab, sizes are finite and
// non-negative, and a zoom names a panel that is there.
pub fn dock_layout_normalized(layout DockLayout) DockLayout {
	mut seen := map[string]bool{}
	mut out := DockLayout{
		...layout
	}
	for placement in dock_placements() {
		region := layout.region(placement)
		mut groups := []DockGroup{}
		for group in region.groups {
			mut panels := []string{}
			mut active := dock_clamp_index(group.active, group.panels.len)
			for i, id in group.panels {
				if id.len == 0 || id in seen {
					if i < group.active && active > 0 {
						active--
					}
					continue
				}
				seen[id] = true
				panels << id
			}
			if panels.len == 0 {
				continue
			}
			groups << DockGroup{
				panels: panels
				active: dock_clamp_index(active, panels.len)
				size:   dock_clean_size(group.size)
			}
		}
		out = out.with_region(placement, DockRegion{
			groups: groups
			open:   region.open
			size:   dock_clean_size(region.size)
		})
	}
	if out.zoomed.len > 0 && out.zoomed !in seen {
		out = DockLayout{
			...out
			zoomed: ''
		}
	}
	return out
}

fn dock_layout_with_group(layout DockLayout, placement DockPlacement, index int, group DockGroup) DockLayout {
	region := layout.region(placement)
	mut groups := region.groups.clone()
	groups[index] = group
	return layout.with_region(placement, DockRegion{
		...region
		groups: groups
	})
}

fn dock_layout_set_open(layout DockLayout, placement DockPlacement, open bool) DockLayout {
	region := layout.region(placement)
	return layout.with_region(placement, DockRegion{
		...region
		open: open
	})
}

// dock_layout_activate displays a panel in its group, opening its dock if it
// is closed. It returns none for an unknown panel or one already displayed.
pub fn dock_layout_activate(layout DockLayout, panel string) ?DockLayout {
	at := dock_layout_find(layout, panel)?
	region := layout.region(at.placement)
	group := region.groups[at.group]
	if dock_clamp_index(group.active, group.panels.len) == at.index
		&& (at.placement == .center || region.open) {
		return none
	}
	next := dock_layout_with_group(layout, at.placement, at.group, DockGroup{
		...group
		active: at.index
	})
	return dock_layout_set_open(next, at.placement, true)
}

// dock_layout_remove takes a panel out of its group. A group left empty goes;
// when the panel was displayed, the tab after it (or before it, for the last
// tab) takes over, and so does a zoom on the group.
fn dock_layout_remove(layout DockLayout, panel string) ?DockLayout {
	at := dock_layout_find(layout, panel)?
	region := layout.region(at.placement)
	group := region.groups[at.group]
	mut panels := group.panels.clone()
	panels.delete(at.index)
	shown := dock_clamp_index(group.active, group.panels.len)
	active := if at.index < shown || (at.index == shown && shown == panels.len) {
		shown - 1
	} else {
		shown
	}
	mut groups := region.groups.clone()
	if panels.len == 0 {
		groups.delete(at.group)
	} else {
		groups[at.group] = DockGroup{
			...group
			panels: panels
			active: dock_clamp_index(active, panels.len)
		}
	}
	mut zoomed := layout.zoomed
	if zoomed.len > 0 && zoomed in group.panels {
		zoomed = if panels.len > 0 && zoomed != panel {
			zoomed
		} else if panels.len > 0 {
			panels[dock_clamp_index(active, panels.len)]
		} else {
			''
		}
	}
	return DockLayout{
		...layout.with_region(at.placement, DockRegion{
			...region
			groups: groups
		})
		zoomed: zoomed
	}
}

// dock_layout_close removes a panel from the layout. It returns none for a
// panel that is not there.
pub fn dock_layout_close(layout DockLayout, panel string) ?DockLayout {
	return dock_layout_remove(layout, panel)
}

// dock_layout_add puts a panel in a region's first group (a new group when the
// region has none), displays it and opens the dock. A panel already in the
// layout moves there.
pub fn dock_layout_add(layout DockLayout, panel string, placement DockPlacement) DockLayout {
	if panel.len == 0 {
		return layout
	}
	base := dock_layout_remove(layout, panel) or { layout }
	region := base.region(placement)
	mut groups := region.groups.clone()
	if groups.len == 0 {
		groups << DockGroup{
			panels: [panel]
		}
	} else {
		mut panels := groups[0].panels.clone()
		panels << panel
		groups[0] = DockGroup{
			...groups[0]
			panels: panels
			active: panels.len - 1
		}
	}
	return base.with_region(placement, DockRegion{
		...region
		groups: groups
		open:   true
	})
}

// dock_layout_move moves a panel to another region (see dock_layout_add). It
// returns none for an unknown panel or one already in that region.
pub fn dock_layout_move(layout DockLayout, panel string, placement DockPlacement) ?DockLayout {
	at := dock_layout_find(layout, panel)?
	if at.placement == placement {
		return none
	}
	return dock_layout_add(layout, panel, placement)
}

// dock_layout_split moves a panel into a new group just after its own, which
// gives up half its size to it. It returns none for an unknown panel or the
// only panel of its group.
pub fn dock_layout_split(layout DockLayout, panel string) ?DockLayout {
	at := dock_layout_find(layout, panel)?
	region := layout.region(at.placement)
	group := region.groups[at.group]
	if group.panels.len < 2 {
		return none
	}
	removed := dock_layout_remove(layout, panel)?
	mut groups := removed.region(at.placement).groups.clone()
	half := group.size / 2
	groups[at.group] = DockGroup{
		...groups[at.group]
		size: half
	}
	groups.insert(at.group + 1, DockGroup{
		panels: [panel]
		size:   half
	})
	return removed.with_region(at.placement, DockRegion{
		...region
		groups: groups
	})
}

// dock_layout_toggle opens a closed dock or closes an open one. It returns none
// for the center and for a dock without panels.
pub fn dock_layout_toggle(layout DockLayout, placement DockPlacement) ?DockLayout {
	region := layout.region(placement)
	if placement == .center || !region.has_panels() {
		return none
	}
	return dock_layout_set_open(layout, placement, !region.open)
}

// dock_layout_resize sets a dock's size (a side dock's width, the bottom dock's
// height); the dock area holds it to the room there is when it draws.
pub fn dock_layout_resize(layout DockLayout, placement DockPlacement, size f64) DockLayout {
	region := layout.region(placement)
	return layout.with_region(placement, DockRegion{
		...region
		size: dock_clean_size(size)
	})
}

// dock_layout_zoom zooms a panel's group in to fill the area, or out again when
// that group is the one zoomed. It returns none for an unknown panel.
pub fn dock_layout_zoom(layout DockLayout, panel string) ?DockLayout {
	at := dock_layout_find(layout, panel)?
	if zoomed_at := dock_layout_find(layout, layout.zoomed) {
		if zoomed_at.placement == at.placement && zoomed_at.group == at.group {
			return DockLayout{
				...layout
				zoomed: ''
			}
		}
	}
	return DockLayout{
		...layout
		zoomed: panel
	}
}

// dock_layout_retain keeps only the panels the application still has, for a
// saved layout from an older version of it.
pub fn dock_layout_retain(layout DockLayout, known []string) DockLayout {
	mut keep := map[string]bool{}
	for id in known {
		keep[id] = true
	}
	mut out := DockLayout{
		...layout
	}
	for placement in dock_placements() {
		region := layout.region(placement)
		mut groups := []DockGroup{}
		for group in region.groups {
			shown := group.active_panel()
			panels := group.panels.filter(it in keep)
			shown_index := panels.index(shown)
			groups << DockGroup{
				...group
				panels: panels
				active: if shown_index < 0 { 0 } else { shown_index }
			}
		}
		out = out.with_region(placement, DockRegion{
			...region
			groups: groups
		})
	}
	return dock_layout_normalized(out)
}

// ── Saving and restoring ────────────────────────────────────────────

const dock_layout_format = 'ui2-dock 1'

fn dock_escape(id string) string {
	mut out := []u8{cap: id.len}
	for ch in id.bytes() {
		if ch.is_letter() || ch.is_digit() || ch in [`.`, `_`, `-`, `/`, `:`, `@`, `+`, `#`, `~`] {
			out << ch
		} else {
			out << `%`
			out << '0123456789ABCDEF'[ch >> 4]
			out << '0123456789ABCDEF'[ch & 15]
		}
	}
	return out.bytestr()
}

fn dock_hex_value(ch u8) int {
	return if ch >= `0` && ch <= `9` {
		int(ch - `0`)
	} else if ch >= `A` && ch <= `F` {
		int(ch - `A`) + 10
	} else if ch >= `a` && ch <= `f` {
		int(ch - `a`) + 10
	} else {
		-1
	}
}

fn dock_unescape(text string) !string {
	mut out := []u8{cap: text.len}
	mut i := 0
	for i < text.len {
		ch := text[i]
		if ch == `%` {
			if i + 2 >= text.len {
				return error('dock layout: truncated escape in `${text}`')
			}
			high := dock_hex_value(text[i + 1])
			low := dock_hex_value(text[i + 2])
			if high < 0 || low < 0 {
				return error('dock layout: bad escape in `${text}`')
			}
			out << u8(high * 16 + low)
			i += 3
			continue
		}
		out << ch
		i++
	}
	if out.len == 0 {
		return error('dock layout: empty panel id')
	}
	return out.bytestr()
}

fn dock_number(value f64) string {
	clean := dock_clean_size(value)
	rounded := math.round(clean * 100) / 100
	return if rounded == math.floor(rounded) { '${i64(rounded)}' } else { '${rounded}' }
}

fn dock_parse_size(text string) !f64 {
	value := strconv.atof64(text) or { return error('dock layout: bad size `${text}`') }
	if !component_finite(value) || value < 0 {
		return error('dock layout: bad size `${text}`')
	}
	return value
}

fn dock_parse_int(text string) !int {
	value := component_parse_index(text, 1_000_000) or {
		return error('dock layout: bad number `${text}`')
	}
	return value
}

// dock_layout_encode writes a layout as a few lines of text: a format line, the
// version, the zoom, then each region (`center open 0`) followed by its groups
// (`group <active> <size> <panel>...`). Panel ids are percent-escaped.
pub fn dock_layout_encode(layout DockLayout) string {
	clean := dock_layout_normalized(layout)
	mut lines := [dock_layout_format, 'version ${clean.version}']
	if clean.zoomed.len > 0 {
		lines << 'zoomed ${dock_escape(clean.zoomed)}'
	}
	for placement in dock_placements() {
		region := clean.region(placement)
		lines << '${placement.name()} ${if region.open { 'open' } else { 'closed' }} ${dock_number(region.size)}'
		for group in region.groups {
			mut words := ['group', '${group.active}', dock_number(group.size)]
			for id in group.panels {
				words << dock_escape(id)
			}
			lines << words.join(' ')
		}
	}
	return lines.join('\n') + '\n'
}

// dock_layout_decode reads what dock_layout_encode wrote. It rejects anything
// else with an error rather than guessing, so keep a default layout to fall
// back on, and compare `version` with the application's own before using it.
// A region left out of the text stays empty and open.
pub fn dock_layout_decode(text string) !DockLayout {
	lines := text.split_into_lines().map(it.trim_space()).filter(it.len > 0)
	if lines.len == 0 || lines[0] != dock_layout_format {
		return error('dock layout: not a ui2 dock layout')
	}
	mut layout := DockLayout{}
	mut seen := map[string]bool{}
	mut current := ''
	mut groups := []DockGroup{}
	mut open := true
	mut size := 0.0
	for line in lines[1..] {
		words := line.split(' ').filter(it.len > 0)
		match words[0] {
			'version' {
				if words.len != 2 || current.len > 0 {
					return error('dock layout: bad line `${line}`')
				}
				layout = DockLayout{
					...layout
					version: dock_parse_int(words[1])!
				}
			}
			'zoomed' {
				if words.len != 2 || current.len > 0 {
					return error('dock layout: bad line `${line}`')
				}
				layout = DockLayout{
					...layout
					zoomed: dock_unescape(words[1])!
				}
			}
			'group' {
				if words.len < 4 || current.len == 0 {
					return error('dock layout: bad group `${line}`')
				}
				mut panels := []string{}
				for word in words[3..] {
					panels << dock_unescape(word)!
				}
				groups << DockGroup{
					panels: panels
					active: dock_parse_int(words[1])!
					size:   dock_parse_size(words[2])!
				}
			}
			else {
				placement := dock_placement_from_name(words[0]) or {
					return error('dock layout: bad line `${line}`')
				}
				if words.len != 3 || words[1] !in ['open', 'closed'] || words[0] in seen {
					return error('dock layout: bad region `${line}`')
				}
				if current.len > 0 {
					layout = dock_layout_finish_region(layout, current, groups, open, size)
				}
				seen[words[0]] = true
				current = placement.name()
				groups = []DockGroup{}
				open = words[1] == 'open'
				size = dock_parse_size(words[2])!
			}
		}
	}
	if current.len > 0 {
		layout = dock_layout_finish_region(layout, current, groups, open, size)
	}
	return dock_layout_normalized(layout)
}

fn dock_layout_finish_region(layout DockLayout, name string, groups []DockGroup, open bool, size f64) DockLayout {
	placement := dock_placement_from_name(name) or { return layout }
	return layout.with_region(placement, DockRegion{
		groups: groups
		open:   open
		size:   size
	})
}
