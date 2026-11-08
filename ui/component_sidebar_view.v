// Rendering of the sidebar (see component_sidebar.v) and its collapse toggle.
module ui2

import math

// SidebarColors are the colors a sidebar draws with, derived from a
// ComponentTheme: GPUI Kit's sidebar, sidebar_foreground, sidebar_border,
// sidebar_accent and sidebar_primary tokens.
pub struct SidebarColors {
pub:
	background        u32 // The sidebar's fill.
	foreground        u32 // Labels.
	muted             u32 // Group labels, suffixes, icons and chevrons.
	disabled          u32 // Disabled labels and icons.
	border            u32 // The edge, the guides beside sub-items, the rail's dividers.
	hover             u32 // A hovered row.
	pressed           u32 // A button whose menu is open.
	active            u32 // The current row.
	active_foreground u32 // Its icon.
	ring              u32 // The keyboard cursor.
	logo              u32 // The header's logo tile.
	logo_foreground   u32
}

// sidebar_colors derives the sidebar's colors from a theme: a fill between the
// background and the muted color, rows that darken (or lighten, in a dark
// theme) toward the foreground on hover, and a current row tinted with the
// primary color.
pub fn sidebar_colors(theme ComponentTheme) SidebarColors {
	dark := feedback_is_dark(theme)
	background := popover_blend(theme.background, theme.muted, 0.5)
	return SidebarColors{
		background:        background
		foreground:        theme.foreground
		muted:             theme.muted_foreground
		disabled:          popover_blend(theme.muted_foreground, background, 0.45)
		border:            popover_blend(theme.border, background, if dark { 0.35 } else { 0.3 })
		hover:             popover_blend(background, theme.foreground, if dark {
			0.08
		} else {
			0.05
		})
		pressed:           popover_blend(background, theme.foreground, if dark { 0.14 } else { 0.1 })
		active:            popover_blend(background, theme.primary, if dark { 0.22 } else { 0.12 })
		active_foreground: theme.primary
		ring:              theme.primary
		logo:              theme.primary
		logo_foreground:   theme.primary_foreground
	}
}

fn sidebar_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

fn sidebar_none() Rect {
	return rect(0, 0, 0, 0)
}

fn sidebar_has(frame Rect) bool {
	return frame.width > 0 && frame.height > 0
}

// sidebar_fill is a row's box: its fill, and when it has the keyboard cursor a
// ring drawn as a ring-colored shape with the fill inset over it, since the
// custom renderer draws BoxStyle borders square-cornered.
fn sidebar_fill(size Rect, fill u32, transparent bool, radius f64, ring bool, c SidebarColors, m SidebarMetrics) (BoxStyle, []Element) {
	if !ring {
		return BoxStyle{
			bg:          fill
			transparent: transparent
			radius:      radius
		}, []Element{}
	}
	inset := m.ring
	return BoxStyle{
		bg:     c.ring
		radius: radius
	}, [
		Element{
			...view('', rect(inset, inset, math.max(size.width - 2 * inset, 0), math.max(size.height - 2 * inset,
				0)), BoxStyle{
				bg:     fill
				radius: math.max(radius - inset, 0)
			}, []Element{})
			key: 'ring'
		},
	]
}

fn sidebar_initial(text string) string {
	for r in text.runes() {
		if r != ` ` && r != `\t` {
			return [r].string().to_upper()
		}
	}
	return '?'
}

fn sidebar_item_value(current bool, expandable bool, expanded bool) string {
	mut parts := []string{}
	if current {
		parts << 'current'
	}
	if expandable {
		parts << if expanded { 'expanded' } else { 'collapsed' }
	}
	return parts.join(', ')
}

fn sidebar_badge_element(item SidebarItem, frame Rect, cutout u32, rail bool, config SidebarConfig, c SidebarColors, m SidebarMetrics) Element {
	tone_bg, tone_fg := config.theme.colors(item.badge_tone)
	bg := if item.badge_tone == .neutral { c.pressed } else { tone_bg }
	fg := if item.badge_tone == .neutral { c.foreground } else { tone_fg }
	if rail || item.dot {
		// In the rail a badge shrinks to a dot on the icon's corner, cut out of
		// the row's fill so it stays legible over the glyph.
		if rail {
			return Element{
				...view('', frame, BoxStyle{
					bg:     cutout
					radius: frame.width / 2
				}, [
					view('', rect(2, 2, math.max(frame.width - 4, 0), math.max(frame.height - 4,
						0)), BoxStyle{
						bg:     bg
						radius: math.max(frame.width / 2 - 2, 0)
					}, []Element{}),
				])
				key: 'badge'
			}
		}
		return Element{
			...view('', frame, BoxStyle{
				bg:     bg
				radius: frame.width / 2
			}, []Element{})
			key: 'badge'
		}
	}
	return Element{
		...view('', frame, BoxStyle{
			bg:     bg
			radius: frame.height / 2
		}, [
			label('', item.badge, rect(0, 0, frame.width, frame.height), TextStyle{
				color: fg
				size:  m.small
				bold:  true
				align: .center
			}),
		])
		key: 'badge'
	}
}

fn sidebar_item_element(config SidebarConfig, model SidebarModel, row SidebarRow, c SidebarColors) Element {
	m := model.metrics
	item := row.item
	enabled := item.enabled
	action := sidebar_item_action(config.id, item.id)
	current := model.current == item.id
	hovered := enabled && config.state.hovered == action
	focused := enabled && config.state.focused == item.id
	// In the rail an item's own menu (its flyout) opens from the item itself.
	pressed := model.rail && enabled && config.open_menu == item.id
	expandable := item.children.len > 0 && !model.rail
	expanded := expandable && item.id in config.state.expanded
	size := rect(0, 0, row.frame.width, row.frame.height)
	fill := if current {
		c.active
	} else if pressed {
		c.pressed
	} else if hovered {
		c.hover
	} else {
		c.background
	}
	box, mut children := sidebar_fill(size, fill, !current && !pressed && !hovered && !focused,
		m.radius, focused, c, m)
	parts := sidebar_item_parts(config, model, row)
	text_color := if enabled { c.foreground } else { c.disabled }
	icon_color := if !enabled {
		c.disabled
	} else if current {
		c.active_foreground
	} else {
		c.muted
	}
	if sidebar_has(parts.icon) {
		if item.icon.len > 0 {
			children << sidebar_symbol(item.icon, parts.icon, icon_color)
		} else {
			// The rail has no room for a label, so an item without an icon shows
			// its initial.
			children << label('', sidebar_initial(item.label), size, TextStyle{
				color: if current { c.active_foreground } else { text_color }
				size:  m.font
				bold:  true
				align: .center
			})
		}
	}
	if model.rail {
		if item.dot || item.badge.len > 0 {
			side := m.dot + 4
			children << sidebar_badge_element(item, rect(parts.icon.x + parts.icon.width - side +
				3, parts.icon.y - 3, side, side), fill, true, config, c, m)
		}
	} else {
		children << label('', item.label, parts.text, TextStyle{
			color: text_color
			size:  m.font
			bold:  current
		})
		if sidebar_has(parts.suffix) {
			children << label('', item.suffix, parts.suffix, TextStyle{
				color: if enabled { c.muted } else { c.disabled }
				size:  m.small
				align: .right
			})
		}
		if sidebar_has(parts.badge) {
			children << sidebar_badge_element(item, parts.badge, fill, false, config,
				c, m)
		}
		if sidebar_has(parts.accessory) {
			children << Element{
				...view('', parts.accessory, BoxStyle{ transparent: true }, item.accessory)
				key: 'accessory'
			}
		}
		if sidebar_has(parts.more) {
			open := config.open_menu == item.id
			glyph := m.glyph
			children << Element{
				...button_view(sidebar_more_action(config.id, item.id), parts.more, BoxStyle{
					bg:          c.pressed
					transparent: !open
					radius:      math.max(m.radius - 2, 2)
				}, [
					sidebar_symbol('ellipsis', rect(math.round((parts.more.width - glyph) / 2),
						math.round((parts.more.height - glyph) / 2), glyph, glyph), if enabled {
						c.muted
					} else {
						c.disabled
					}),
				])
				key:                 'more'
				enabled:             enabled
				tooltip:             'More actions'
				accessibility_label: 'More actions for ${item.label}'
				accessibility_value: if open { 'expanded' } else { '' }
			}
		}
		if sidebar_has(parts.chevron) {
			glyph := m.glyph
			children << Element{
				...button_view(sidebar_expand_action(config.id, item.id), parts.chevron,
					BoxStyle{
						transparent: true
						radius:      math.max(m.radius - 2, 2)
					}, [
						sidebar_symbol(if expanded { 'chevron.down' } else { 'chevron.right' },
							rect(math.round((parts.chevron.width - glyph) / 2), math.round((parts.chevron.height - glyph) / 2),
								glyph, glyph), if enabled { c.muted } else { c.disabled }),
					])
				key:                 'chevron'
				enabled:             enabled
				accessibility_role:  'button'
				accessibility_label: 'Toggle ${item.label} submenu'
				accessibility_value: if expanded { 'expanded' } else { 'collapsed' }
			}
		}
	}
	description := if item.accessibility_label.len > 0 {
		item.accessibility_label
	} else if item.badge.len > 0 {
		'${item.label}, ${item.badge}'
	} else {
		item.label
	}
	el := Element{
		...button_view(action, row.frame, box, children)
		key:                 'item:' + item.id
		enabled:             enabled
		hoverable:           enabled
		menu:                if enabled { item.menu } else { []MenuEntry{} }
		accessibility_role:  'treeitem'
		accessibility_label: description
		accessibility_value: sidebar_item_value(current, expandable, expanded)
	}
	if model.rail {
		tip := if item.tooltip.len > 0 {
			item.tooltip
		} else if item.badge.len > 0 {
			'${item.label} (${item.badge})'
		} else {
			item.label
		}
		return with_tooltip(el, tip)
	}
	return if item.tooltip.len > 0 { with_tooltip(el, item.tooltip) } else { el }
}

fn sidebar_label_element(config SidebarConfig, row SidebarRow, c SidebarColors, m SidebarMetrics) Element {
	group := config.groups[row.group]
	if !group.collapsible {
		return Element{
			...view('', row.frame, BoxStyle{ transparent: true }, [
				label('', group.label, rect(m.inner, 0, math.max(row.frame.width - 2 * m.inner,
					0), row.frame.height), TextStyle{
					color: c.muted
					size:  m.small
				}),
			])
			key:                 'label:${row.group}'
			accessibility_role:  'text'
			accessibility_label: group.label
		}
	}
	action := sidebar_group_action(config.id, group.id)
	hovered := config.state.hovered == action
	focused := config.state.focused == group.id
	open := group.id !in config.state.closed_groups
	size := rect(0, 0, row.frame.width, row.frame.height)
	box, mut children := sidebar_fill(size, if hovered { c.hover } else { c.background },
		!hovered && !focused, m.radius, focused, c, m)
	glyph := m.glyph
	chevron_x := row.frame.width - m.inner / 2 - m.button
	children << label('', group.label, rect(m.inner, 0, math.max(chevron_x - m.inner, 0),
		row.frame.height), TextStyle{
		color: c.muted
		size:  m.small
	})
	children << sidebar_symbol(if open { 'chevron.down' } else { 'chevron.right' }, rect(chevron_x +
		math.round((m.button - glyph) / 2), math.round((row.frame.height - glyph) / 2), glyph,
		glyph), c.muted)
	return Element{
		...button_view(action, row.frame, box, children)
		key:                 'label:${row.group}'
		hoverable:           true
		accessibility_role:  'button'
		accessibility_label: group.label
		accessibility_value: if open { 'expanded' } else { 'collapsed' }
	}
}

// sidebar_logo is the header's or footer's leading tile: a symbol on the logo
// color, an avatar, or the title's initial.
fn sidebar_logo(block SidebarBlock, frame Rect, c SidebarColors, theme ComponentTheme, m SidebarMetrics) Element {
	if block.icon.len == 0 && (block.avatar.len > 0 || block.avatar_image.len > 0) {
		return Element{
			...avatar(
				name:       block.avatar
				image_path: block.avatar_image
				frame:      frame
				theme:      ComponentTheme{
					...theme
					muted: c.pressed
				}
			) or { view('', frame, BoxStyle{ transparent: true }, []Element{}) }
			key: 'logo'
		}
	}
	glyph := math.round(frame.width * 0.55)
	content := if block.icon.len > 0 {
		sidebar_symbol(block.icon, rect(math.round((frame.width - glyph) / 2), math.round((frame.height - glyph) / 2),
			glyph, glyph), c.logo_foreground)
	} else {
		label('', sidebar_initial(block.title), rect(0, 0, frame.width, frame.height), TextStyle{
			color: c.logo_foreground
			size:  m.font
			bold:  true
			align: .center
		})
	}
	return Element{
		...view('', frame, BoxStyle{
			bg:     c.logo
			radius: m.radius
		}, [content])
		key: 'logo'
	}
}

fn sidebar_block_element(config SidebarConfig, model SidebarModel, block SidebarBlock, frame Rect, action string, open bool, c SidebarColors, key string) Element {
	m := model.metrics
	hovered := block.menu && config.state.hovered == action
	size := rect(0, 0, frame.width, frame.height)
	mut children := []Element{}
	logo_side := math.min(m.row, frame.height)
	if model.rail {
		if block.icon.len > 0 || block.avatar.len > 0 || block.avatar_image.len > 0
			|| block.title.len > 0 {
			children << sidebar_logo(block, rect(math.round((frame.width - logo_side) / 2),
				math.round((frame.height - logo_side) / 2), logo_side, logo_side), c,
				config.theme, m)
		}
	} else if block.children.len > 0 {
		children << Element{
			...view('', size, BoxStyle{ transparent: true }, block.children)
			key: 'content'
		}
	} else {
		pad := math.round((frame.height - logo_side) / 2)
		mut x := m.inner
		if block.icon.len > 0 || block.avatar.len > 0 || block.avatar_image.len > 0 {
			children << sidebar_logo(block, rect(pad, pad, logo_side, logo_side), c, config.theme,
				m)
			x = pad + logo_side + m.gap
		}
		mut right := frame.width - m.inner
		if block.menu && block.menu_icon.len > 0 {
			glyph := m.glyph
			right -= glyph
			children << sidebar_symbol(block.menu_icon, rect(right, math.round((frame.height - glyph) / 2),
				glyph, glyph), c.muted)
			right -= m.gap
		}
		text_width := math.max(right - x, 0)
		if block.subtitle.len > 0 {
			title_height := math.round(m.font * 1.4)
			subtitle_height := math.round(m.small * 1.4)
			top := math.round((frame.height - title_height - subtitle_height) / 2)
			children << label('', block.title, rect(x, top, text_width, title_height), TextStyle{
				color: c.foreground
				size:  m.font
				bold:  true
			})
			children << label('', block.subtitle, rect(x, top + title_height, text_width,
				subtitle_height), TextStyle{
				color: c.muted
				size:  m.small
			})
		} else {
			children << label('', block.title, rect(x, 0, text_width, frame.height), TextStyle{
				color: c.foreground
				size:  m.font
				bold:  true
			})
		}
	}
	description := if block.subtitle.len > 0 {
		'${block.title}, ${block.subtitle}'
	} else {
		block.title
	}
	if !block.menu {
		el := Element{
			...view('', frame, BoxStyle{ transparent: true }, children)
			key:                 key
			accessibility_role:  'group'
			accessibility_label: description
		}
		return if model.rail && block.title.len > 0 { with_tooltip(el, block.title) } else { el }
	}
	el := Element{
		...button_view(action, frame, BoxStyle{
			bg:          if open { c.pressed } else { c.hover }
			transparent: !open && !hovered
			radius:      m.radius
		}, children)
		key:                 key
		hoverable:           true
		accessibility_label: description
		accessibility_value: if open { 'expanded' } else { 'collapsed' }
	}
	return if model.rail && block.title.len > 0 { with_tooltip(el, block.title) } else { el }
}

fn sidebar_rows(config SidebarConfig, model SidebarModel, c SidebarColors) []Element {
	m := model.metrics
	mut rows := []Element{cap: model.rows.len}
	for row in model.rows {
		match row.kind {
			.label {
				rows << sidebar_label_element(config, row, c, m)
			}
			.item {
				rows << sidebar_item_element(config, model, row, c)
			}
			.divider {
				rows << Element{
					...view('', row.frame, BoxStyle{ bg: c.border }, []Element{})
					key:                'divider:${row.group}'
					accessibility_role: 'separator'
				}
			}
			.guide {
				rows << Element{
					...view('', row.frame, BoxStyle{ bg: c.border }, []Element{})
					key: 'guide:' + row.parent
				}
			}
		}
	}
	return rows
}

// sidebar draws a navigation sidebar: an optional header, groups of items
// with icons, badges, suffixes and sub-items, and an optional footer, with a
// border along the edge that faces the content. Collapsed, it is an icon rail
// whose items show their labels as tooltips (or, off-canvas, nothing). The
// groups scroll in sidebar_scroll_id(id) once they are taller than the room
// between the header and the footer. It is controlled: pass events to
// sidebar_update and keys to sidebar_key, store the state they return and
// rebuild.
pub fn sidebar(config SidebarConfig) !Element {
	model := sidebar_model(config)!
	if sidebar_hidden(config) {
		return component_finish(Element{
			...view(config.id, config.frame, BoxStyle{ transparent: true }, []Element{})
			hidden:              true
			accessibility_role:  'navigation'
			accessibility_label: config.accessibility_label
		})
	}
	c := sidebar_colors(config.theme)
	width := config.frame.width
	height := config.frame.height
	mut children := []Element{}
	if model.body.height > 0 {
		rows := sidebar_rows(config, model, c)
		body := if model.scrolls {
			Element{
				...scroll(sidebar_scroll_id(config.id), model.body, c.background, rows)
				key:                 'body'
				accessibility_role:  'tree'
				accessibility_label: config.accessibility_label
			}
		} else {
			// Groups that fit do not scroll: a Scroll element would add room below
			// them to scroll into.
			Element{
				...view('', model.body, BoxStyle{ transparent: true }, rows)
				key:                 'body'
				accessibility_role:  'tree'
				accessibility_label: config.accessibility_label
			}
		}
		children << body
	}
	header := sidebar_header_block(config.header)
	if header.present() {
		children << sidebar_block_element(config, model, header, model.header, sidebar_header_action(config.id),
			config.header_open, c, 'header')
	}
	footer := sidebar_footer_block(config.footer)
	if footer.present() {
		children << sidebar_block_element(config, model, footer, model.footer, sidebar_footer_action(config.id),
			config.footer_open, c, 'footer')
	}
	if config.border && width > 0 {
		edge := if config.side == .left { width - 1 } else { 0.0 }
		children << Element{
			...view('', rect(edge, 0, math.min(1.0, width), height), BoxStyle{ bg: c.border },
				[]Element{})
			key: 'border'
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ bg: c.background }, children)
		accessibility_role:  'navigation'
		accessibility_label: config.accessibility_label
		accessibility_value: if sidebar_rail(config) { 'collapsed' } else { '' }
	})
}

// ── Toggle button ───────────────────────────────────────────────────

pub struct SidebarToggleButtonConfig {
pub:
	id         string
	sidebar_id string // The sidebar it collapses: it emits sidebar_collapse_action(sidebar_id).
	frame      Rect
	collapsed  bool
	side       SidebarSide = .left
	// on_sidebar draws the hover and pressed fills in the sidebar's colors, for
	// a toggle placed inside a sidebar.
	on_sidebar bool
	// hovered draws the hover fill: pass sidebar_toggle_hovered(state, sidebar_id)
	// with the state sidebar_update keeps, which tracks the toggle's hover events.
	hovered bool
	label   string // Accessibility label and tooltip; 'Collapse sidebar' or 'Expand sidebar' by default.
	enabled bool          = true
	size    ComponentSize = .medium
	theme   ComponentTheme
}

// sidebar_panel_icon draws a panel with a pane along one side, as the
// panel-left and panel-right icons GPUI Kit's toggle uses: the pane is filled
// while the sidebar shows. It is drawn from strips, so it is the same on every
// renderer; no symbol name for it exists everywhere.
fn sidebar_panel_icon(frame Rect, side SidebarSide, filled bool, color u32) Element {
	w := frame.width
	h := math.round(frame.width * 0.84)
	top := math.round((frame.height - h) / 2)
	stroke := 1.5
	pane := math.round(w * 0.36)
	pane_x := if side == .left { 0.0 } else { w - pane }
	divider_x := if side == .left { pane - stroke } else { w - pane }
	mut strips := [
		view('', rect(0, top, w, stroke), BoxStyle{ bg: color, radius: 0.75 }, []Element{}),
		view('', rect(0, top + h - stroke, w, stroke), BoxStyle{ bg: color, radius: 0.75 },
			[]Element{}),
		view('', rect(0, top, stroke, h), BoxStyle{ bg: color, radius: 0.75 }, []Element{}),
		view('', rect(w - stroke, top, stroke, h), BoxStyle{ bg: color, radius: 0.75 },
			[]Element{}),
		view('', rect(divider_x, top, stroke, h), BoxStyle{ bg: color }, []Element{}),
	]
	if filled {
		strips << view('', rect(pane_x, top, pane, h), BoxStyle{
			bg:      color
			radius:  1
			opacity: 0.45
		}, []Element{})
	}
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, strips)
		key: 'icon'
	}
}

// sidebar_toggle_button is GPUI Kit's SidebarToggleButton: an icon button
// showing a panel with its pane on the sidebar's side, filled while the
// sidebar is expanded. It emits sidebar_collapse_action(sidebar_id), which
// sidebar_update and sidebar_collapsed_from_action decode, and reports hover
// under the same action, which sidebar_update tracks in the sidebar's state.
pub fn sidebar_toggle_button(config SidebarToggleButtonConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	component_validate_id(config.sidebar_id)!
	metrics := component_metrics(config.size)
	c := sidebar_colors(config.theme)
	hover_fill := if config.on_sidebar {
		c.hover
	} else {
		popover_blend(config.theme.background, config.theme.foreground, 0.06)
	}
	glyph := math.min(math.round(metrics.font_size * 1.15), math.min(config.frame.width,
		config.frame.height))
	color := if config.enabled { config.theme.foreground } else { config.theme.muted_foreground }
	caption := if config.label.len > 0 {
		config.label
	} else if config.collapsed {
		'Expand sidebar'
	} else {
		'Collapse sidebar'
	}
	return component_finish(Element{
		...button_view(config.id, config.frame, BoxStyle{
			bg:          hover_fill
			transparent: !config.hovered || !config.enabled
			radius:      metrics.radius
		}, [
			sidebar_panel_icon(rect(math.round((config.frame.width - glyph) / 2), math.round((config.frame.height - glyph) / 2),
				glyph, glyph), config.side, !config.collapsed, color),
		])
		action_id:           sidebar_collapse_action(config.sidebar_id)
		enabled:             config.enabled
		hoverable:           config.enabled
		tooltip:             caption
		accessibility_label: caption
		accessibility_value: if config.collapsed { 'collapsed' } else { 'expanded' }
	})
}
