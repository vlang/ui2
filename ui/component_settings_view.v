module ui2

import math

// Rendering of the settings. Switches and checkboxes are drawn here rather
// than taken from the platform, and dropdowns use dropdown_button and
// dropdown_menu, so every control follows the theme on every renderer.

// settings_mix blends two 0xRRGGBB colors; t = 0 is a, t = 1 is b.
fn settings_mix(a u32, b u32, t f64) u32 {
	amount := math.max(0.0, math.min(1.0, t))
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := f64((a >> shift) & 0xff)
		to := f64((b >> shift) & 0xff)
		out |= u32(math.round(from + (to - from) * amount)) << shift
	}
	return out
}

fn settings_brightness(color u32) f64 {
	return 0.299 * f64((color >> 16) & 0xff) + 0.587 * f64((color >> 8) & 0xff) +
		0.114 * f64(color & 0xff)
}

fn settings_is_dark(theme ComponentTheme) bool {
	return settings_brightness(theme.background) < settings_brightness(theme.foreground)
}

struct SettingsColors {
	nav          u32 // The navigation column.
	nav_active   u32 // The selected row.
	divider      u32 // Between the navigation and the page, and under the header.
	separator    u32 // Between items on a surface.
	fill         u32 // A fill group's surface.
	disabled     u32 // A disabled item's title.
	disabled_alt u32 // A disabled item's description.
}

fn settings_colors(theme ComponentTheme) SettingsColors {
	dark := settings_is_dark(theme)
	nav := if dark {
		settings_mix(theme.background, 0x000000, 0.22)
	} else {
		settings_mix(theme.background, theme.muted, 0.85)
	}
	fill := if dark {
		settings_mix(theme.background, theme.muted, 0.7)
	} else {
		settings_mix(theme.background, theme.muted, 0.8)
	}
	return SettingsColors{
		nav:          nav
		nav_active:   settings_mix(nav, theme.primary, if dark { 0.2 } else { 0.13 })
		divider:      settings_mix(theme.border, theme.background, 0.35)
		separator:    settings_mix(theme.border, theme.background, 0.45)
		fill:         fill
		disabled:     settings_mix(theme.muted_foreground, theme.background, 0.2)
		disabled_alt: settings_mix(theme.muted_foreground, theme.background, 0.45)
	}
}

fn settings_local(frame Rect, origin Rect) Rect {
	return rect(frame.x - origin.x, frame.y - origin.y, frame.width, frame.height)
}

fn settings_text(content string, frame Rect, color u32, size f64, bold bool, wrap bool) Element {
	return label('', content, frame, TextStyle{
		color:  color
		size:   size
		bold:   bold
		valign: if wrap { VAlign.top } else { VAlign.middle }
		lines:  if wrap { 0 } else { 1 }
	})
}

// settings_fill is one of the view's surfaces, painted unless it is transparent.
fn settings_fill(config SettingsConfig, color u32) BoxStyle {
	return if config.transparent { BoxStyle{ transparent: true } } else { BoxStyle{ bg: color } }
}

fn settings_symbol(name string, frame Rect, color u32) Element {
	// A page icon may be an image path, which draws as it is.
	if name.contains('/') {
		return image('', name, frame)
	}
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

// ── Controls ────────────────────────────────────────────────────────

fn settings_switch(id string, frame Rect, on bool, enabled bool, caption string, theme ComponentTheme) Element {
	dark := settings_is_dark(theme)
	mut track := if on { theme.primary } else { theme.border }
	mut thumb := if on {
		theme.primary_foreground
	} else if dark {
		theme.foreground
	} else {
		theme.background
	}
	if !enabled {
		track = settings_mix(track, theme.background, 0.5)
		thumb = settings_mix(thumb, theme.background, 0.3)
	}
	inset := math.max(math.round(frame.height * 0.1), 1)
	side := math.max(frame.height - 2 * inset, 0)
	x := if on { frame.width - inset - side } else { inset }
	knob := Element{
		...view('', rect(x, inset, side, side), BoxStyle{
			bg:     thumb
			radius: side / 2
			shadow: if enabled { box_shadow(0x000000, 0.18, 2, 1) } else { BoxShadow{} }
		}, []Element{})
		key: 'thumb'
	}
	return Element{
		...button_view(id, frame, BoxStyle{
			bg:     track
			radius: frame.height / 2
		}, [knob])
		key:                 'switch'
		enabled:             enabled
		cursor:              if enabled { cursor_pointing_hand } else { cursor_default }
		accessibility_role:  'switch'
		accessibility_label: caption
		accessibility_value: if on { 'on' } else { 'off' }
	}
}

fn settings_checkbox(id string, frame Rect, checked bool, enabled bool, caption string, theme ComponentTheme) Element {
	local := component_local(frame)
	radius := math.round(frame.height * 0.22)
	mut kids := []Element{}
	mut box := BoxStyle{}
	if checked {
		fill := if enabled {
			theme.primary
		} else {
			settings_mix(theme.primary, theme.background, 0.5)
		}
		box = BoxStyle{
			bg:     fill
			radius: radius
		}
		// One point wider than the glyph on each side: the custom renderer draws a
		// symbol as a glyph as large as the frame, and cuts one that overflows.
		mark := math.round(frame.height * 0.72)
		kids << settings_symbol('checkmark', rect(math.round((frame.width - mark) / 2) - 1,
			math.round((frame.height - mark) / 2), mark + 2, mark), theme.primary_foreground)
	} else {
		border := if enabled {
			theme.border
		} else {
			settings_mix(theme.border, theme.background, 0.5)
		}
		panel, fill_kids := popover_panel(local, theme.background, border, radius, false)
		box = panel
		kids << fill_kids
	}
	return Element{
		...button_view(id, frame, box, kids)
		key:                 'checkbox'
		enabled:             enabled
		cursor:              if enabled { cursor_pointing_hand } else { cursor_default }
		accessibility_role:  'checkbox'
		accessibility_label: caption
		accessibility_value: if checked { 'checked' } else { 'unchecked' }
	}
}

// settings_field_elements builds an item's control in its row's coordinates.
fn settings_field_elements(config SettingsConfig, item SettingItem, box SettingsItemBox, origin Rect) ![]Element {
	theme := config.theme
	id := config.id
	frame := settings_local(box.field, origin)
	enabled := !item.disabled
	value := settings_item_value(config.values, item)
	m := settings_metrics(config.size)
	match item.kind {
		.switch {
			return [
				settings_switch(settings_field_id(id, item.key), frame, settings_value_bool(value),
					enabled, item.title, theme),
			]
		}
		.checkbox {
			return [
				settings_checkbox(settings_field_id(id, item.key), frame, settings_value_bool(value),
					enabled, item.title, theme),
			]
		}
		.dropdown {
			current := settings_value_string(value)
			mut shown := current
			for option in item.options {
				if option.value == current {
					shown = settings_option_label(option)
				}
			}
			trigger := dropdown_button(
				id:      settings_dropdown_id(id, item.key)
				frame:   frame
				label:   shown
				menu_id: settings_menu_id(id, item.key)
				open:    config.state.menu == item.key
				outline: true
				enabled: enabled
				size:    config.size
				theme:   theme
			)!
			return [
				Element{
					...trigger
					key:                 'dropdown'
					accessibility_role:  'combobox'
					accessibility_label: item.title
					accessibility_value: shown
				},
			]
		}
		.input {
			return [
				inputs_field(
					id:                settings_field_id(id, item.key)
					placeholder:       item.placeholder
					text:              settings_value_string(value)
					frame:             frame
					font_size:         m.font
					enabled:           enabled
					readonly:          !enabled
					secure:            item.secure
					role:              'textbox'
					label:             item.title
					key:               'input'
					standalone_radius: m.base.radius
					theme:             theme
				),
			]
		}
		.number {
			number := number_input(settings_number_input_config(config, config.state, item,
				frame))!
			return [Element{
				...number
				key: 'number'
			}]
		}
		.slider {
			current := settings_value_number(value)
			value_w := math.min(settings_slider_value_width(item, m), frame.width / 3)
			track_w := math.max(frame.width - value_w - m.base.gap, 0)
			low := item.min or { 0.0 }
			high := item.max or { 1.0 }
			mut control := slider(
				id:          settings_field_id(id, item.key)
				frame:       rect(frame.x, frame.y, track_w, frame.height)
				min:         low
				max:         high
				value:       current
				step:        item.step
				padding:     10
				value_track: true
				style:       SliderStyle{
					track_color:       theme.border
					value_track_color: theme.primary
					thumb_color:       theme.primary
					track_width:       4
					thumb_size:        16
				}
			)
			control = Element{
				...control
				key:                 'slider'
				enabled:             enabled
				accessibility_label: item.title
				accessibility_value: settings_slider_text(item, current)
			}
			return [
				control,
				Element{
					...label('', settings_slider_text(item, current), rect(frame.x + frame.width - value_w,
						frame.y, value_w, frame.height), TextStyle{
						color: if enabled {
							theme.muted_foreground
						} else {
							settings_colors(theme).disabled_alt
						}
						size:  m.small
						align: .right
					})
					key: 'slider-value'
				},
			]
		}
		.button {
			pressable := styled_button(
				id:      settings_field_id(id, item.key)
				frame:   frame
				label:   item.button_text
				variant: item.button_variant
				enabled: enabled
				size:    config.size
				theme:   theme
			)!
			return [Element{
				...pressable
				key: 'button'
			}]
		}
		.custom {
			content := item.content(SettingContentOptions{
				key:      item.key
				width:    frame.width
				height:   frame.height
				disabled: item.disabled
				layout:   box.layout
				size:     config.size
				theme:    theme
			})
			return [
				Element{
					...view('', frame, BoxStyle{ transparent: true }, content)
					key: 'custom'
				},
			]
		}
	}
}

fn settings_item_element(config SettingsConfig, item SettingItem, box SettingsItemBox, origin Rect) !Element {
	theme := config.theme
	colors := settings_colors(theme)
	m := settings_metrics(config.size)
	row := settings_local(box.row, origin)
	mut kids := []Element{}
	if !box.full {
		kids << Element{
			...settings_text(item.title, settings_local(box.title, box.row), if item.disabled {
				colors.disabled
			} else {
				theme.foreground
			}, m.font, false, box.title.height > m.line)
			key: 'title'
		}
		description := settings_plain_text(item.description)
		if description.len > 0 {
			kids << Element{
				...settings_text(description, settings_local(box.description, box.row), if item.disabled {
					colors.disabled_alt
				} else {
					theme.muted_foreground
				}, m.small, false, true)
				key: 'description'
			}
		}
	}
	kids << settings_field_elements(config, item, box, box.row)!
	if box.reset.width > 0 && settings_item_dirty(config.values, item) {
		reset := styled_button(
			id:                  settings_reset_action(config.id, item.key)
			frame:               settings_local(box.reset, box.row)
			icon:                'arrow.uturn.backward'
			variant:             .ghost
			accessibility_label: 'Reset ${item.title} to its default'.replace('  ', ' ')
			size:                .small
			theme:               theme
		)!
		kids << Element{
			...with_tooltip(reset, 'Reset to default')
			key: 'reset'
		}
	}
	return Element{
		...view('', row, BoxStyle{ transparent: true }, kids)
		key:                 'item:' + settings_hex(if item.key.len > 0 {
			item.key
		} else {
			'${box.group}:${box.item}'
		})
		accessibility_role:  'group'
		accessibility_label: item.title
	}
}

fn settings_group_element(config SettingsConfig, page SettingPage, box SettingsGroupBox) !Element {
	theme := config.theme
	colors := settings_colors(theme)
	m := settings_metrics(config.size)
	group := page.groups[box.group]
	origin := box.frame
	mut kids := []Element{}
	if box.title.height > 0 {
		kids << Element{
			...settings_text(group.title, settings_local(box.title, origin), theme.foreground,
				m.font, true, box.title.height > m.line)
			key: 'title'
		}
	}
	if box.description.height > 0 {
		kids << Element{
			...settings_text(settings_plain_text(group.description), settings_local(box.description,
				origin), theme.muted_foreground, m.small, false, true)
			key: 'description'
		}
	}
	surface := settings_local(box.surface, origin)
	mut surface_box := BoxStyle{
		transparent: true
	}
	mut surface_kids := []Element{}
	match box.variant {
		.normal {}
		.outline {
			if config.transparent {
				// A filled panel behind the rows would stop them showing through.
				surface_box = BoxStyle{
					transparent:   true
					radius:        m.radius
					border_color:  theme.border
					border_left:   1
					border_top:    1
					border_right:  1
					border_bottom: 1
				}
			} else {
				panel, fill := popover_panel(component_local(surface), theme.background,
					theme.border, m.radius, false)
				surface_box = panel
				surface_kids << fill
			}
		}
		.fill {
			surface_box = BoxStyle{
				bg:     colors.fill
				radius: m.radius
			}
		}
	}
	for index, line in box.separators {
		surface_kids << Element{
			...view('', settings_local(line, box.surface), BoxStyle{
				bg: if box.variant == .fill {
					settings_mix(colors.fill, theme.border, 0.55)
				} else {
					colors.separator
				}
			}, []Element{})
			key: 'separator:${index}'
		}
	}
	for item_box in box.items {
		item := group.items[item_box.item]
		surface_kids << settings_item_element(config, item, item_box, box.surface)!
	}
	kids << Element{
		...view('', surface, surface_box, surface_kids)
		key: 'surface'
	}
	if box.footer.height > 0 {
		kids << Element{
			...settings_text(settings_plain_text(group.footer), settings_local(box.footer,
				origin), theme.muted_foreground, m.small, false, true)
			key: 'footer'
		}
	}
	return Element{
		...view('', box.frame, BoxStyle{ transparent: true }, kids)
		key:                 'group:${box.group}'
		accessibility_role:  'group'
		accessibility_label: group.title
	}
}

// ── Page ────────────────────────────────────────────────────────────

fn settings_header_element(config SettingsConfig, page_ix int, frame Rect) !Element {
	theme := config.theme
	colors := settings_colors(theme)
	m := settings_metrics(config.size)
	page := config.pages[page_ix]
	layout := settings_header_layout(config, page_ix, frame.width)
	mut kids := []Element{}
	kids << Element{
		...settings_text(page.title, layout.title, theme.foreground, m.page_title, true, false)
		key:                'title'
		accessibility_role: 'heading'
	}
	if layout.suffix.width > 0 {
		kids << Element{
			...view('', layout.suffix, BoxStyle{ transparent: true }, page.title_suffix(SettingContentOptions{
				key:    settings_page_id(page)
				width:  layout.suffix.width
				height: layout.suffix.height
				size:   config.size
				theme:  theme
			}))
			key: 'suffix'
		}
	}
	if layout.reset.width > 0 && settings_page_resets(config, config.state).len > 0 {
		searching := settings_query_terms(config.state.query).len > 0
		reset := styled_button(
			id:                  settings_reset_page_action(config.id, settings_page_id(page))
			frame:               layout.reset
			label:               config.reset_all_text
			icon:                'arrow.uturn.backward'
			variant:             .ghost
			accessibility_label: if searching {
				'${config.reset_all_text}: the settings found'
			} else {
				'${config.reset_all_text}: ${page.title}'
			}
			size:                .small
			theme:               theme
		)!
		kids << Element{
			...with_tooltip(reset, if searching {
				'Restore the defaults of the settings found'
			} else {
				'Restore the defaults of this page'
			})
			key: 'reset-all'
		}
	}
	if layout.description.height > 0 {
		kids << Element{
			...settings_text(settings_plain_text(page.description), layout.description,
				theme.muted_foreground, m.small, false, true)
			key: 'description'
		}
	}
	kids << Element{
		...view('', rect(0, frame.height - 1, frame.width, 1), BoxStyle{ bg: colors.divider },
			[]Element{})
		key: 'divider'
	}
	return Element{
		...view('', frame, settings_fill(config, theme.background), kids)
		key: 'header'
	}
}

fn settings_body_element(config SettingsConfig, page_ix int, frame Rect) !Element {
	page := config.pages[page_ix]
	pid := settings_page_id(page)
	layout := settings_page_layout(config, config.state, page_ix, frame.width)
	content_h := math.max(layout.height, frame.height)
	mut kids := []Element{}
	kids << Element{
		...view('', rect(0, 0, 1, layout.height), BoxStyle{ transparent: true }, []Element{})
		key: 'extent'
	}
	for box in layout.groups {
		kids << settings_group_element(config, page, box)!
	}
	// An open dropdown menu is drawn over the page's content, inside the
	// scroll, so it moves with its trigger and needs no window coordinates.
	if config.state.menu.len > 0 {
		for box in layout.groups {
			for item_box in box.items {
				item := page.groups[box.group].items[item_box.item]
				if item.key != config.state.menu || item.kind != .dropdown || item.disabled {
					continue
				}
				current := settings_value_string(settings_item_value(config.values, item))
				menu := dropdown_menu(
					id:        settings_menu_id(config.id, item.key)
					state:     config.state.menu_state
					items:     settings_menu_items(item, current)
					anchor:    item_box.field
					window:    rect(0, 0, frame.width, content_h)
					side:      .bottom
					align:     .end
					min_width: item_box.field.width
					max_width: math.max(item_box.field.width, 320)
					label:     item.title
					size:      config.size
					theme:     config.theme
				)!
				kids << Element{
					...menu
					key: 'menu'
				}
			}
		}
	}
	return Element{
		...scroll(settings_scroll_id(config.id, pid), frame, config.theme.background, kids)
		box:                 settings_fill(config, config.theme.background)
		key:                 'content:' + settings_hex(pid)
		accessibility_label: page.title
	}
}

fn settings_empty_element(config SettingsConfig, frame Rect) Element {
	theme := config.theme
	m := settings_metrics(config.size)
	icon := math.round(m.base.height * 1.1)
	top := math.round(frame.height * 0.32)
	w := math.max(frame.width - 2 * m.pad, 0)
	desc_lines := math.max(settings_text_lines(config.empty_description, m.small, w), 1)
	return Element{
		...view('', frame, settings_fill(config, theme.background), [
			settings_symbol('magnifyingglass', rect((frame.width - icon) / 2, top, icon, icon),
				theme.muted_foreground),
			label('', config.empty_title, rect(m.pad, top + icon + m.base.padding, w, m.line + 4),
				TextStyle{
					color: theme.foreground
					size:  m.font + 2
					bold:  true
					align: .center
				}),
			label('', config.empty_description, rect(m.pad, top + icon + m.base.padding + m.line +
				8, w, f64(desc_lines) * m.small_line), TextStyle{
				color:  theme.muted_foreground
				size:   m.small
				align:  .center
				valign: .top
				lines:  0
			}),
		])
		key:                 'empty'
		accessibility_role:  'status'
		accessibility_label: config.empty_title
	}
}

// ── Navigation ──────────────────────────────────────────────────────

fn settings_nav_row_elements(config SettingsConfig, row SettingsNavRow, title_x f64) Element {
	theme := config.theme
	colors := settings_colors(theme)
	m := settings_metrics(config.size)
	page := config.pages[row.page]
	pid := settings_page_id(page)
	local := component_local(row.frame)
	radius := m.base.radius
	box := if row.active {
		BoxStyle{
			bg:     colors.nav_active
			radius: radius
		}
	} else {
		BoxStyle{
			transparent: true
		}
	}
	if row.group >= 0 {
		group := page.groups[row.group]
		caption := Element{
			...settings_text(group.title, rect(title_x, 0, math.max(local.width - title_x - m.base.padding,
				0), local.height), if row.active {
				theme.foreground
			} else {
				theme.muted_foreground
			},
				m.small, row.active, false)
			key: 'title'
		}
		return Element{
			...button_view(settings_group_action(config.id, pid, row.group), row.frame, box,
				[caption])
			key:                 'group:' + settings_hex(pid) + ':${row.group}'
			cursor:              cursor_pointing_hand
			accessibility_label: group.title
			accessibility_value: if row.active { 'current' } else { '' }
		}
	}
	main_w := local.width - row.caret.width
	mut main := []Element{}
	if page.icon.len > 0 {
		main << Element{
			...settings_symbol(page.icon, rect(math.round((title_x - m.icon) / 2), math.round((local.height - m.icon) / 2),
				m.icon, m.icon), if row.active { theme.primary } else { theme.muted_foreground })
			key: 'icon'
		}
	}
	mut count_w := 0.0
	if row.count >= 0 {
		count_text := row.count.str()
		badge_h := math.round(m.small_line + 2)
		count_w = math.max(component_text_width_estimate(count_text, m.small - 1) + 12, badge_h)
		badge_frame := Rect{
			x:      main_w - count_w - if row.caret.width > 0 { 0.0 } else { m.base.padding }
			y:      math.round((local.height - badge_h) / 2)
			width:  count_w
			height: badge_h
		}
		main << Element{
			...view('', badge_frame, BoxStyle{
				bg:     settings_mix(if row.active { colors.nav_active } else { colors.nav },
					theme.foreground, 0.09)
				radius: badge_h / 2
			}, [
				label('', count_text, rect(0, 0, badge_frame.width, badge_frame.height), TextStyle{
					color: theme.muted_foreground
					size:  m.small - 1
					align: .center
				}),
			])
			key: 'count'
		}
		count_w += m.base.gap
	}
	main << Element{
		...settings_text(page.title, rect(title_x, 0, math.max(main_w - title_x - count_w - m.base.gap,
			0), local.height), theme.foreground, m.font, row.active, false)
		key: 'title'
	}
	mut kids := [
		Element{
			...button_view(settings_page_action(config.id, pid), rect(0, 0, main_w, local.height),
				BoxStyle{ transparent: true }, main)
			key:                 'page'
			cursor:              cursor_pointing_hand
			accessibility_label: page.title
			accessibility_value: if pid == config.state.page { 'current' } else { '' }
		},
	]
	if row.caret.width > 0 {
		chevron := math.round(m.icon * 0.75)
		kids << Element{
			...button_view(settings_expand_action(config.id, pid), rect(main_w, 0, row.caret.width,
				local.height), BoxStyle{ transparent: true }, [
				settings_symbol(if row.open { 'chevron.down' } else { 'chevron.right' },
					inputs_centered_square(rect(0, 0, row.caret.width, local.height), chevron),
					theme.muted_foreground),
			])
			key:                 'expand'
			cursor:              cursor_pointing_hand
			accessibility_label: if row.open {
				'Hide the groups of ${page.title}'
			} else {
				'Show the groups of ${page.title}'
			}
			accessibility_value: if row.open { 'expanded' } else { 'collapsed' }
		}
	}
	return Element{
		...view('', row.frame, box, kids)
		key: 'page:' + settings_hex(pid)
	}
}

fn settings_nav_element(config SettingsConfig) !Element {
	theme := config.theme
	colors := settings_colors(theme)
	m := settings_metrics(config.size)
	nav_w := settings_nav_width(config)
	layout := settings_nav_layout(config, config.state)
	mut with_icons := false
	for page in config.pages {
		if page.icon.len > 0 {
			with_icons = true
		}
	}
	title_x := if with_icons {
		math.round(m.base.padding + m.icon + m.base.padding * 1.25)
	} else {
		m.base.padding * 1.5
	}
	mut rows := []Element{cap: layout.rows.len + 1}
	rows << Element{
		...view('', rect(0, 0, 1, layout.height), BoxStyle{ transparent: true }, []Element{})
		key: 'extent'
	}
	for row in layout.rows {
		rows << settings_nav_row_elements(config, row, title_x)
	}
	search := input_group(settings_search_config(config, layout.search))!
	return Element{
		...view('', rect(0, 0, nav_w, config.frame.height), settings_fill(config, colors.nav), [
			Element{
				...search
				key: 'search'
			},
			Element{
				...scroll(settings_nav_scroll_id(config.id), layout.list, colors.nav, rows)
				box: settings_fill(config, colors.nav)
				key: 'pages'
			},
			Element{
				...view('', rect(nav_w - 1, 0, 1, config.frame.height), BoxStyle{
					bg: colors.divider
				}, []Element{})
				key: 'divider'
			},
		])
		key:                 'nav'
		accessibility_role:  'navigation'
		accessibility_label: 'Settings pages'
	}
}

// settings draws GPUI Kit's Settings: a navigation column with a search
// field and the pages (and, for an expanded page, its titled groups), and
// the selected page's header and groups. It is controlled: the application
// owns `values` and `state`, passes every action to settings_update and every
// key to settings_key, and stores what they return. Start from
// settings_defaults(pages) and settings_initial_state(pages).
pub fn settings(config SettingsConfig) !Element {
	settings_validate(config)!
	resolved := SettingsConfig{
		...config
		state: settings_resolve_state(config.pages, config.state)
	}
	state_now := resolved.state
	nav_w := settings_nav_width(config)
	content_w := settings_content_width(config)
	mut kids := []Element{}
	if content_w > 0 {
		visible := settings_visible_groups(config.pages, state_now.query)
		page_ix := settings_page_index(config.pages, state_now.page)
		if page_ix >= 0 && visible[page_ix].len > 0 {
			header := settings_header_layout(resolved, page_ix, content_w)
			body_h := math.max(config.frame.height - header.height, 0)
			kids << settings_body_element(resolved, page_ix, rect(nav_w, header.height,
				content_w, body_h))!
			kids << settings_header_element(resolved, page_ix, rect(nav_w, 0, content_w,
				math.min(header.height, config.frame.height)))!
		} else {
			kids << settings_empty_element(resolved, rect(nav_w, 0, content_w, config.frame.height))
		}
	}
	if nav_w > 0 {
		kids << settings_nav_element(resolved)!
	}
	return component_finish(Element{
		...view(config.id, config.frame, settings_fill(config, config.theme.background), kids)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}
