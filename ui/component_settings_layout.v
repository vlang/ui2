module ui2

import math

// Geometry of the settings: the navigation column, a page's header and the
// groups and items of a page. Everything here is pure, so tests and
// applications (scrolling to a group) can use it without building elements.

struct SettingsMetrics {
	size       ComponentSize
	base       ComponentMetrics
	nav_pad    f64 // Around the search field and the navigation rows.
	pad        f64 // Left and right of the page, and below its content.
	top        f64 // Above the page title and the first group.
	row_pad    f64 // Above and below an item's content.
	inset      f64 // Inside an outline or fill surface.
	col_gap    f64 // Between an item's text and its control.
	group_gap  f64 // Between groups.
	title_gap  f64 // Between a group's title and its surface, and above a footer.
	font       f64 // Item and page-row titles.
	small      f64 // Descriptions, footers and group rows.
	page_title f64
	line       f64 // Line heights of the three sizes.
	small_line f64
	page_line  f64
	radius     f64 // Corner radius of group surfaces.
	nav_row    f64 // Height of a page row.
	nav_sub    f64 // Height of a group row.
	icon       f64 // Side of a navigation icon.
	reset      f64 // Side of an item's reset button.
}

fn settings_line(size f64) f64 {
	return math.ceil(font_em_pixels(size) * 1.34)
}

fn settings_metrics(size ComponentSize) SettingsMetrics {
	m := component_metrics(size)
	s := m.height / 32
	return SettingsMetrics{
		size:       size
		base:       m
		nav_pad:    math.round(12 * s)
		pad:        math.round(28 * s)
		top:        math.round(20 * s)
		row_pad:    math.round(12 * s)
		inset:      math.round(16 * s)
		col_gap:    math.round(24 * s)
		group_gap:  math.round(28 * s)
		title_gap:  math.round(8 * s)
		font:       m.font_size
		small:      m.font_size - 1
		page_title: m.font_size + 6
		line:       settings_line(m.font_size)
		small_line: settings_line(m.font_size - 1)
		page_line:  settings_line(m.font_size + 6)
		radius:     m.radius + 2
		nav_row:    m.height
		nav_sub:    m.height - math.round(4 * s)
		icon:       m.font_size + 2
		reset:      math.round(24 * s)
	}
}

// settings_rune_em is roughly how wide a character draws, in ems, in the
// proportional faces the renderers use (San Francisco, Segoe UI, Roboto). It
// is finer than component_text_width_estimate so wrapped descriptions do not
// leave blank lines, and still leans wide: an extra blank line is better
// than a clipped one.
fn settings_rune_em(r rune) f64 {
	if r >= 0x2e80 {
		return 1.0
	}
	if r in [` `, `i`, `j`, `l`, `I`, `.`, `,`, `:`, `;`, `'`, `!`, `|`, `’`, `‘`] {
		return 0.28
	}
	if r in [`f`, `t`, `r`, `(`, `)`, `[`, `]`, `-`, `/`, `\\`, `"`] {
		return 0.38
	}
	if r in [`m`, `w`] {
		return 0.82
	}
	if r in [`M`, `W`] {
		return 0.92
	}
	if r >= `A` && r <= `Z` {
		return 0.68
	}
	if r >= `0` && r <= `9` {
		return 0.6
	}
	if r >= `a` && r <= `z` {
		return 0.54
	}
	return 0.62
}

fn settings_text_width(source string, size f64) f64 {
	mut ems := 0.0
	for r in source.runes() {
		ems += settings_rune_em(r)
	}
	return ems * font_em_pixels(size)
}

// settings_text_lines estimates how many lines text wraps onto in width,
// breaking between words as the renderers do.
fn settings_text_lines(source string, size f64, width f64) int {
	if source.trim_space().len == 0 {
		return 0
	}
	if width <= 0 {
		return 1
	}
	space := settings_text_width(' ', size)
	mut lines := 0
	for paragraph in source.split('\n') {
		lines++
		mut used := 0.0
		for word in paragraph.split(' ') {
			if word.len == 0 {
				continue
			}
			w := settings_text_width(word, size)
			if used > 0 && used + space + w > width {
				lines++
				used = 0
			}
			if w > width {
				// A word wider than the line breaks inside itself.
				extra := int(math.ceil(w / width)) - 1
				lines += extra
				used = w - f64(extra) * width
				continue
			}
			used += if used > 0 { space + w } else { w }
		}
	}
	return lines
}

fn settings_nav_width(config SettingsConfig) f64 {
	return math.max(math.min(config.nav_width, config.frame.width), 0)
}

fn settings_content_width(config SettingsConfig) f64 {
	return math.max(config.frame.width - settings_nav_width(config), 0)
}

fn settings_has_default(item SettingItem) bool {
	return if _ := item.default_value { true } else { false }
}

// settings_item_resettable reports whether an item gets a reset button
// (while it differs from its default): it has a default, it is enabled and
// its page is resettable.
fn settings_item_resettable(page SettingPage, item SettingItem) bool {
	return page.resettable && !item.disabled && settings_has_default(item)
}

fn settings_full_row(item SettingItem) bool {
	return item.kind == .custom && item.title.len == 0 && item.description.len == 0
}

fn settings_longest_option(item SettingItem) string {
	mut longest := ''
	mut widest := 0.0
	for option in item.options {
		caption := settings_option_label(option)
		w := component_text_width_estimate(caption, 14)
		if w > widest {
			widest = w
			longest = caption
		}
	}
	return longest
}

// settings_slider_text is a slider's value as its label shows it.
fn settings_slider_text(item SettingItem, value f64) string {
	places := if item.precision >= 0 {
		item.precision
	} else if item.step > 0 {
		number_input_decimal_places(item.step)
	} else {
		0
	}
	return number_input_format(value, places) + item.unit
}

fn settings_slider_value_width(item SettingItem, m SettingsMetrics) f64 {
	mut widest := 0.0
	for value in [item.min or { 0.0 }, item.max or { 0.0 }] {
		widest = math.max(widest, component_text_width_estimate(settings_slider_text(item,
			value), m.small))
	}
	return math.ceil(widest + 4)
}

// settings_field_size is the size of an item's control: its natural width
// in a horizontal row, the row's width (avail) for wide controls in a
// vertical one.
fn settings_field_size(item SettingItem, m SettingsMetrics, layout SettingLayout, avail f64) (f64, f64) {
	h := m.base.height
	vertical := layout == .vertical
	mut width := 0.0
	mut height := h
	match item.kind {
		.switch {
			return math.round(h * 1.125), math.round(h * 0.625)
		}
		.checkbox {
			side := math.round(h * 0.5625)
			return side, side
		}
		.dropdown {
			natural := dropdown_button_width(settings_longest_option(item), '', false, m.size) +
				m.base.gap
			width = if vertical {
				avail
			} else if item.field_width > 0 {
				item.field_width
			} else {
				math.min(math.max(natural, h * 4), h * 8)
			}
		}
		.input {
			width = if vertical {
				avail
			} else if item.field_width > 0 {
				item.field_width
			} else {
				h * 7
			}
		}
		.number {
			width = if vertical {
				avail
			} else if item.field_width > 0 {
				item.field_width
			} else {
				h * 4
			}
		}
		.slider {
			width = if vertical {
				avail
			} else if item.field_width > 0 {
				item.field_width
			} else {
				h * 6 + m.base.gap + settings_slider_value_width(item, m)
			}
		}
		.button {
			width = styled_button_width(item.button_text, '', m.size)
		}
		.custom {
			width = if vertical {
				avail
			} else if item.field_width > 0 {
				item.field_width
			} else {
				h * 6
			}
			height = if item.content_height > 0 { item.content_height } else { h }
		}
	}
	return math.max(math.min(width, avail), 0), height
}

// SettingsItemBox is where an item goes, in the page's scrolled content.
struct SettingsItemBox {
	group       int
	item        int
	layout      SettingLayout
	full        bool // Custom content spanning the row.
	row         Rect
	title       Rect
	description Rect
	field       Rect
	reset       Rect // Zero unless the item can be reset.
}

struct SettingsGroupBox {
	group       int
	variant     SettingsGroupVariant
	frame       Rect // From the title down to the footer.
	title       Rect
	description Rect
	surface     Rect
	items       []SettingsItemBox
	separators  []Rect
	footer      Rect
}

struct SettingsPageLayout {
	page    int
	width   f64
	height  f64 // Of the content, bottom padding included.
	stacked bool
	groups  []SettingsGroupBox
}

fn settings_item_box(page SettingPage, item SettingItem, group_ix int, item_ix int, x f64, y f64, w f64, stacked bool, m SettingsMetrics) SettingsItemBox {
	layout := if stacked { SettingLayout.vertical } else { item.layout }
	reset_w := if settings_item_resettable(page, item) { m.reset + m.base.gap } else { 0.0 }
	description := settings_plain_text(item.description)
	if settings_full_row(item) {
		height := if item.content_height > 0 { item.content_height } else { m.base.height }
		field := rect(x, y + m.row_pad, math.max(w - reset_w, 0), height)
		return SettingsItemBox{
			group:  group_ix
			item:   item_ix
			layout: layout
			full:   true
			row:    rect(x, y, w, height + 2 * m.row_pad)
			field:  field
			reset:  if reset_w > 0 {
				rect(x + w - m.reset, field.y + (height - m.reset) / 2, m.reset, m.reset)
			} else {
				Rect{}
			}
		}
	}
	if layout == .horizontal {
		fw, fh := settings_field_size(item, m, .horizontal, w * 0.6)
		text_w := math.max(math.min(w - fw - reset_w - m.col_gap, w * 0.72), w * 0.3)
		title_h := f64(settings_text_lines(item.title, m.font, text_w)) * m.line
		desc_h := f64(settings_text_lines(description, m.small, text_w)) * m.small_line
		text_h := title_h + if desc_h > 0 { 2 + desc_h } else { 0.0 }
		inner := math.max(text_h, fh)
		ty := y + m.row_pad + math.round((inner - text_h) / 2)
		field := rect(x + w - fw, y + m.row_pad + math.round((inner - fh) / 2), fw, fh)
		return SettingsItemBox{
			group:       group_ix
			item:        item_ix
			layout:      layout
			row:         rect(x, y, w, inner + 2 * m.row_pad)
			title:       rect(x, ty, text_w, title_h)
			description: if desc_h > 0 { rect(x, ty + title_h + 2, text_w, desc_h) } else { Rect{} }
			field:       field
			reset:       if reset_w > 0 {
				rect(field.x - m.base.gap - m.reset, y + m.row_pad + math.round((inner - m.reset) / 2),
					m.reset, m.reset)
			} else {
				Rect{}
			}
		}
	}
	text_w := math.max(w - reset_w, 0)
	title_h := f64(settings_text_lines(item.title, m.font, text_w)) * m.line
	desc_h := f64(settings_text_lines(description, m.small, text_w)) * m.small_line
	text_h := title_h + if desc_h > 0 { 2 + desc_h } else { 0.0 }
	fw, fh := settings_field_size(item, m, .vertical, w)
	ty := y + m.row_pad
	fy := ty + text_h + if text_h > 0 { m.title_gap } else { 0.0 }
	return SettingsItemBox{
		group:       group_ix
		item:        item_ix
		layout:      layout
		row:         rect(x, y, w, fy + fh + m.row_pad - y)
		title:       rect(x, ty, text_w, title_h)
		description: if desc_h > 0 { rect(x, ty + title_h + 2, text_w, desc_h) } else { Rect{} }
		field:       rect(x, fy, fw, fh)
		reset:       if reset_w > 0 {
			rect(x + w - m.reset, ty + math.round((math.max(title_h, m.line) - m.reset) / 2),
				m.reset, m.reset)
		} else {
			Rect{}
		}
	}
}

// settings_page_layout places the groups of a page that the current search
// shows, in content `width` wide. Items stack vertically while the content
// is at most config.stacked_width wide, as upstream switches layouts below
// 480 pixels.
fn settings_page_layout(config SettingsConfig, state SettingsState, page_ix int, width f64) SettingsPageLayout {
	m := settings_metrics(config.size)
	page := config.pages[page_ix]
	stacked := width <= config.stacked_width
	x := m.pad
	w := math.max(width - 2 * m.pad, 0)
	mut y := m.top
	mut groups := []SettingsGroupBox{}
	for group_ix, group in page.groups {
		if !settings_group_matches(group, state.query) {
			continue
		}
		if groups.len > 0 {
			y += m.group_gap
		}
		variant := group.variant or { config.group_variant }
		top := y
		mut title := Rect{}
		mut description := Rect{}
		if group.title.len > 0 {
			title = rect(x, y, w, f64(settings_text_lines(group.title, m.font, w)) * m.line)
			y += title.height
		}
		desc_text := settings_plain_text(group.description)
		if desc_text.len > 0 {
			y += if group.title.len > 0 { 2.0 } else { 0.0 }
			description = rect(x, y, w, f64(settings_text_lines(desc_text, m.small, w)) * m.small_line)
			y += description.height
		}
		boxed := variant != .normal
		if title.height > 0 || description.height > 0 {
			// A normal group's first row brings its own padding.
			y += if boxed { m.title_gap } else { 0.0 }
		}
		surface_top := y
		inner_x := if boxed { x + m.inset } else { x }
		inner_w := math.max(if boxed { w - 2 * m.inset } else { w }, 0)
		mut items := []SettingsItemBox{}
		mut separators := []Rect{}
		for item_ix, item in group.items {
			if !settings_item_matches(item, state.query) {
				continue
			}
			if items.len > 0 && boxed {
				separators << rect(inner_x, y, inner_w, 1)
			}
			box := settings_item_box(page, item, group_ix, item_ix, inner_x, y, inner_w, stacked,
				m)
			items << box
			y += box.row.height
		}
		surface := rect(x, surface_top, w, y - surface_top)
		mut footer := Rect{}
		footer_text := settings_plain_text(group.footer)
		if footer_text.len > 0 {
			y += m.title_gap
			footer = rect(x, y, w, f64(settings_text_lines(footer_text, m.small, w)) * m.small_line)
			y += footer.height
		}
		groups << SettingsGroupBox{
			group:       group_ix
			variant:     variant
			frame:       rect(x, top, w, y - top)
			title:       title
			description: description
			surface:     surface
			items:       items
			separators:  separators
			footer:      footer
		}
	}
	return SettingsPageLayout{
		page:    page_ix
		width:   width
		height:  y + m.pad
		stacked: stacked
		groups:  groups
	}
}

// settings_group_offset is the scroll offset that brings a group of the
// selected page to the top of the page's scroll, or none when the search
// hides it.
pub fn settings_group_offset(config SettingsConfig, group int) ?f64 {
	resolved := settings_resolve_state(config.pages, config.state)
	page_ix := settings_page_index(config.pages, resolved.page)
	if page_ix < 0 {
		return none
	}
	layout := settings_page_layout(config, resolved, page_ix, settings_content_width(config))
	m := settings_metrics(config.size)
	for box in layout.groups {
		if box.group == group {
			return math.max(box.frame.y - m.top, 0)
		}
	}
	return none
}

// ── Header ──────────────────────────────────────────────────────────

struct SettingsHeaderLayout {
	height      f64
	title       Rect
	suffix      Rect
	reset       Rect // Where Reset all goes when it shows.
	description Rect
}

fn settings_reset_all_width(config SettingsConfig) f64 {
	return math.ceil(styled_button_width(config.reset_all_text, 'arrow.uturn.backward',
		.small) + 4)
}

fn settings_header_layout(config SettingsConfig, page_ix int, width f64) SettingsHeaderLayout {
	m := settings_metrics(config.size)
	page := config.pages[page_ix]
	x := m.pad
	w := math.max(width - 2 * m.pad, 0)
	small_h := component_metrics(.small).height
	reset_w := if page.resettable { settings_reset_all_width(config) } else { 0.0 }
	suffix_w := if voidptr(page.title_suffix) != unsafe { nil } {
		page.title_suffix_width
	} else {
		0.0
	}
	room := math.max(w - reset_w - m.base.gap, 0)
	// The title's frame takes the room there is, so an estimate that falls
	// short does not cut it; the suffix goes where the estimate ends.
	title_w := math.min(math.ceil(settings_text_width(page.title, m.page_title) * 1.06),
		room - suffix_w - m.base.gap)
	y := m.top
	title := rect(x, y, room, m.page_line)
	suffix := if suffix_w > 0 {
		rect(x + math.max(title_w, 0) + m.base.gap, y + math.round((m.page_line - m.base.height) / 2),
			suffix_w, m.base.height)
	} else {
		Rect{}
	}
	reset := if reset_w > 0 {
		rect(x + w - reset_w, y + math.round((m.page_line - small_h) / 2), reset_w, small_h)
	} else {
		Rect{}
	}
	mut bottom := y + m.page_line
	mut description := Rect{}
	desc_text := settings_plain_text(page.description)
	if desc_text.len > 0 {
		description = rect(x, bottom + 4, w, f64(settings_text_lines(desc_text, m.small, w)) * m.small_line)
		bottom = description.y + description.height
	}
	return SettingsHeaderLayout{
		height:      bottom + math.round(m.top * 0.8)
		title:       title
		suffix:      suffix
		reset:       reset
		description: description
	}
}

// ── Navigation ──────────────────────────────────────────────────────

// settings_nav_children lists the groups the navigation shows under a page:
// its titled groups that the search shows, when it shows more than one.
fn settings_nav_children(config SettingsConfig, state SettingsState, page_ix int) []int {
	page := config.pages[page_ix]
	mut shown := []int{}
	for index, group in page.groups {
		if settings_group_matches(group, state.query) {
			shown << index
		}
	}
	if shown.len < 2 {
		return []
	}
	return shown.filter(page.groups[it].title.len > 0)
}

struct SettingsNavRow {
	page   int
	group  int // -1 for a page row.
	frame  Rect
	caret  Rect // Zero when the page has no group rows.
	count  int  // Matching items while searching, -1 otherwise.
	open   bool
	active bool
}

struct SettingsNavLayout {
	search Rect
	list   Rect // The scroll, in the navigation column.
	rows   []SettingsNavRow
	height f64 // Of the list's content.
}

fn settings_nav_layout(config SettingsConfig, state SettingsState) SettingsNavLayout {
	m := settings_metrics(config.size)
	nav_w := settings_nav_width(config)
	search := rect(m.nav_pad, m.nav_pad, math.max(nav_w - 2 * m.nav_pad, 0), m.base.height)
	list_y := search.y + search.height + math.round(m.nav_pad * 0.75)
	list_frame := rect(0, list_y, nav_w, math.max(config.frame.height - list_y, 0))
	visible := settings_visible_groups(config.pages, state.query)
	searching := settings_query_terms(state.query).len > 0
	inset := math.round(m.nav_pad * 0.67)
	row_w := math.max(nav_w - 2 * inset, 0)
	caret_w := math.min(m.base.height * 0.75, row_w)
	mut rows := []SettingsNavRow{}
	mut y := 0.0
	for page_ix, page in config.pages {
		if visible[page_ix].len == 0 {
			continue
		}
		pid := settings_page_id(page)
		children := settings_nav_children(config, state, page_ix)
		open := children.len > 0 && pid in state.expanded
		selected := pid == state.page
		rows << SettingsNavRow{
			page:   page_ix
			group:  -1
			frame:  rect(inset, y, row_w, m.nav_row)
			caret:  if children.len > 0 {
				rect(inset + row_w - caret_w, y, caret_w, m.nav_row)
			} else {
				Rect{}
			}
			count:  if searching { settings_match_count(page, state.query) } else { -1 }
			open:   open
			active: selected && (state.group < 0 || !open || state.group !in children)
		}
		y += m.nav_row + 2
		if open {
			for group in children {
				rows << SettingsNavRow{
					page:   page_ix
					group:  group
					frame:  rect(inset, y, row_w, m.nav_sub)
					count:  -1
					active: selected && state.group == group
				}
				y += m.nav_sub + 2
			}
		}
	}
	return SettingsNavLayout{
		search: search
		list:   list_frame
		rows:   rows
		height: y + inset
	}
}
