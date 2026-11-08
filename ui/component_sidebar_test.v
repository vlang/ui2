module ui2

import math

fn sidebar_test_groups() []SidebarGroup {
	return [
		SidebarGroup{
			label: 'Main'
			items: [
				SidebarItem{
					id:    'home'
					label: 'Home'
					icon:  'house'
				},
				SidebarItem{
					id:    'inbox'
					label: 'Inbox'
					icon:  'tray'
					badge: '12'
				},
				SidebarItem{
					id:       'projects'
					label:    'Projects'
					icon:     'folder'
					more:     true
					children: [
						SidebarItem{
							id:    'web'
							label: 'Web App'
						},
						SidebarItem{
							id:    'mobile'
							label: 'Mobile App'
						},
						SidebarItem{
							id:      'legacy'
							label:   'Legacy'
							enabled: false
						},
					]
				},
				SidebarItem{
					id:      'archive'
					label:   'Archive'
					icon:    'tray'
					enabled: false
				},
			]
		},
		SidebarGroup{
			id:          'settings'
			label:       'Settings'
			collapsible: true
			items:       [
				SidebarItem{
					id:    'general'
					label: 'General'
					icon:  'gearshape'
				},
				SidebarItem{
					id:     'billing'
					label:  'Billing'
					icon:   'creditcard'
					suffix: '⌘B'
				},
			]
		},
	]
}

fn sidebar_test_config(state SidebarState) SidebarConfig {
	return SidebarConfig{
		id:     'nav'
		frame:  rect(0, 0, 255, 600)
		groups: sidebar_test_groups()
		header: SidebarHeader{
			title:    'Acme'
			subtitle: 'Enterprise'
			icon:     'bolt'
			menu:     true
		}
		footer: SidebarFooter{
			title:  'Ada Lovelace'
			avatar: 'Ada Lovelace'
		}
		state:  state
	}
}

fn sidebar_test_find(el Element, key string) ?Element {
	for child in el.children {
		if child.key == key {
			return child
		}
		if found := sidebar_test_find(child, key) {
			return found
		}
	}
	return none
}

fn sidebar_test_press(config SidebarConfig, action string) SidebarStep {
	return sidebar_update(config, action) or { panic('`${action}` was not handled') }
}

fn sidebar_test_key(config SidebarConfig, code KeyCode) ?SidebarStep {
	return sidebar_key(config, KeyEvent{
		code: code
	})
}

// ── Validation ──────────────────────────────────────────────────────

fn test_sidebar_rejects_ambiguous_or_undrawable_configs() {
	base := sidebar_test_config(SidebarState{})
	bad := [
		SidebarConfig{
			...base
			id: ' '
		},
		SidebarConfig{
			...base
			frame: rect(0, 0, -1, 10)
		},
		SidebarConfig{
			...base
			offset: math.inf(1)
		},
		SidebarConfig{
			...base
			groups: [SidebarGroup{
				items: [SidebarItem{
					label: 'No id'
				}]
			}]
		},
		SidebarConfig{
			...base
			groups: [SidebarGroup{
				items: [SidebarItem{
					id: 'blank'
				}]
			}]
		},
		SidebarConfig{
			...base
			groups: [SidebarGroup{
				items: [SidebarItem{
					id:    'twice'
					label: 'A'
				}, SidebarItem{
					id:       'x'
					label:    'B'
					children: [SidebarItem{
						id:    'twice'
						label: 'C'
					}]
				}]
			}]
		},
		SidebarConfig{
			...base
			groups: [SidebarGroup{
				id:    'same'
				label: 'Group'
				items: [SidebarItem{
					id:    'same'
					label: 'Item'
				}]
			}]
		},
		SidebarConfig{
			...base
			groups: [SidebarGroup{
				items: [SidebarItem{
					id:    'icon'
					label: 'Icon'
					icon:  'not.a.symbol'
				}]
			}]
		},
		SidebarConfig{
			...base
			groups: [SidebarGroup{
				label:       'Needs an id'
				collapsible: true
			}]
		},
		SidebarConfig{
			...base
			groups: [SidebarGroup{
				id:          'unlabelled'
				collapsible: true
			}]
		},
		SidebarConfig{
			...base
			groups: [SidebarGroup{
				items: [SidebarItem{
					id:              'wide'
					label:           'Wide'
					accessory_width: -4
				}]
			}]
		},
		SidebarConfig{
			...base
			header: SidebarHeader{
				icon: 'nope'
			}
		},
		SidebarConfig{
			...base
			footer: SidebarFooter{
				avatar: 'Ada'
				menu:   true
			}
		},
	]
	for index, config in bad {
		if _ := sidebar(config) {
			assert false, 'bad config ${index} accepted'
		}
	}
}

// ── Layout ──────────────────────────────────────────────────────────

fn test_sidebar_lays_out_header_groups_and_footer() {
	model := sidebar_model(sidebar_test_config(SidebarState{})) or { panic(err) }
	assert model.header == rect(8, 8, 238, 48)
	assert model.footer == rect(8, 544, 238, 48)
	assert model.body == rect(0, 60, 254, 480)
	assert !model.scrolls
	// Main's label, its four items, Settings' label and its two items.
	assert model.rows.len == 8
	assert model.rows[0].kind == .label
	assert model.rows[0].frame == rect(8, 4, 238, 28)
	assert model.rows[1].item.id == 'home'
	assert model.rows[1].frame == rect(8, 32, 238, 32)
	assert model.rows[2].frame.y == 66
	assert model.rows[5].kind == .label
	// After the last item of Main (y 134 + 32 + 2) and the group gap.
	assert model.rows[5].frame.y == 176
}

fn test_sidebar_shows_expanded_sub_items_with_a_guide() {
	model := sidebar_model(sidebar_test_config(SidebarState{
		expanded: ['projects']
	})) or { panic('none') }
	row := model.item_row('mobile') or { panic('mobile is not shown') }
	assert row.depth == 1
	assert row.parent == 'projects'
	assert row.frame.x == 33
	assert row.frame.width == 213
	assert row.frame.height == 28
	mut guides := 0
	for r in model.rows {
		if r.kind == .guide {
			guides++
			assert r.frame.x == 22
			assert r.frame.width == 1
			// From the first sub-item's top to the last one's bottom.
			first := model.item_row('web') or { panic('none') }
			last := model.item_row('legacy') or { panic('none') }
			assert r.frame.y == first.frame.y
			assert r.frame.y + r.frame.height == last.frame.y + last.frame.height
		}
	}
	assert guides == 1
	collapsed := sidebar_model(sidebar_test_config(SidebarState{})) or { panic(err) }
	if _ := collapsed.item_row('mobile') {
		assert false, 'sub-items of a collapsed item are shown'
	}
}

fn test_sidebar_closed_group_keeps_its_label_only() {
	model := sidebar_model(sidebar_test_config(SidebarState{
		closed_groups: ['settings']
	})) or { panic('none') }
	if _ := model.item_row('general') {
		assert false, 'items of a closed group are shown'
	}
	_ := model.label_row(1) or { panic('the closed group lost its label') }
}

fn test_sidebar_rail_hides_labels_and_sub_items_and_divides_groups() {
	config := SidebarConfig{
		...sidebar_test_config(SidebarState{
			active:        'mobile'
			expanded:      ['projects']
			closed_groups: ['settings']
		})
		frame:     rect(0, 0, sidebar_rail_width(.medium), 600)
		collapsed: true
	}
	model := sidebar_model(config) or { panic(err) }
	assert model.rail
	for row in model.rows {
		assert row.kind != .label
		assert row.kind != .guide
		if row.kind == .item {
			assert row.depth == 0
			assert row.frame.width == 32
			assert row.frame.x == 8
		}
	}
	// The rail has no labels to unfold a group with, so it shows every item.
	_ := model.item_row('general') or { panic('the rail hides a closed group') }
	assert model.rows.filter(it.kind == .divider).len == 1
	// The active sub-item is hidden, so the item it is under is drawn current.
	assert model.current == 'projects'
	assert model.header == rect(8, 8, 32, 32)
	right := sidebar_model(SidebarConfig{
		...config
		side: .right
	}) or { panic('none') }
	assert (right.item_row('home') or { panic('none') }).frame.x == 7
}

fn test_sidebar_current_is_the_nearest_shown_ancestor() {
	shown := sidebar_model(sidebar_test_config(SidebarState{
		active:   'mobile'
		expanded: ['projects']
	})) or { panic('none') }
	assert shown.current == 'mobile'
	hidden := sidebar_model(sidebar_test_config(SidebarState{
		active: 'mobile'
	})) or { panic('none') }
	assert hidden.current == 'projects'
	unknown := sidebar_model(sidebar_test_config(SidebarState{
		active: 'gone'
	})) or { panic('none') }
	assert unknown.current == ''
}

fn test_sidebar_scrolls_only_when_the_groups_overflow() {
	tall := SidebarConfig{
		...sidebar_test_config(SidebarState{})
		frame: rect(0, 0, 255, 300)
	}
	el := sidebar(tall) or { panic(err) }
	body := sidebar_test_find(el, 'body') or { panic('none') }
	assert body.kind == .scroll
	assert body.id == sidebar_scroll_id('nav')
	assert body.accessibility_role == 'tree'
	fits := sidebar(sidebar_test_config(SidebarState{})) or { panic(err) }
	assert (sidebar_test_find(fits, 'body') or { panic('none') }).kind == .view
}

// ── Rendering ───────────────────────────────────────────────────────

fn test_sidebar_draws_rows_with_their_actions_and_state() {
	config := sidebar_test_config(SidebarState{
		active:   'mobile'
		expanded: ['projects']
		focused:  'home'
	})
	el := sidebar(config) or { panic(err) }
	assert el.id == 'nav'
	assert el.accessibility_role == 'navigation'
	assert el.accessibility_label == 'Sidebar'
	border := sidebar_test_find(el, 'border') or { panic('none') }
	assert border.frame == rect(254, 0, 1, 600)
	mobile := sidebar_test_find(el, 'item:mobile') or { panic('none') }
	assert mobile.id == sidebar_item_action('nav', 'mobile')
	assert mobile.button_behavior
	assert mobile.hoverable
	assert mobile.accessibility_role == 'treeitem'
	assert mobile.accessibility_value == 'current'
	projects := sidebar_test_find(el, 'item:projects') or { panic('none') }
	assert projects.accessibility_value == 'expanded'
	chevron := sidebar_test_find(projects, 'chevron') or { panic('none') }
	assert chevron.id == sidebar_expand_action('nav', 'projects')
	assert chevron.accessibility_label == 'Toggle Projects submenu'
	// The ⋯ button shows only while the row is hovered, focused, current or open.
	if _ := sidebar_test_find(projects, 'more') {
		assert false, 'an idle row shows its ⋯ button'
	}
	hovered := sidebar(SidebarConfig{
		...config
		state: SidebarState{
			...config.state
			hovered: sidebar_item_action('nav', 'projects')
		}
	}) or { panic('none') }
	more := sidebar_test_find(sidebar_test_find(hovered, 'item:projects') or { panic('none') },
		'more') or { panic('none') }
	assert more.id == sidebar_more_action('nav', 'projects')
	assert more.accessibility_label == 'More actions for Projects'
	home := sidebar_test_find(el, 'item:home') or { panic('none') }
	// The focus ring is the box, with the fill inset over it.
	assert home.box.bg == sidebar_colors(config.theme).ring
	assert home.children[0].key == 'ring'
	inbox := sidebar_test_find(el, 'item:inbox') or { panic('none') }
	assert inbox.accessibility_label == 'Inbox, 12'
	badge_el := sidebar_test_find(inbox, 'badge') or { panic('none') }
	assert badge_el.children[0].text == '12'
	archive := sidebar_test_find(el, 'item:archive') or { panic('none') }
	assert !archive.enabled
	assert !archive.hoverable
	label_el := sidebar_test_find(el, 'label:1') or { panic('none') }
	assert label_el.id == sidebar_group_action('nav', 'settings')
	assert label_el.accessibility_value == 'expanded'
	header := sidebar_test_find(el, 'header') or { panic('none') }
	assert header.id == sidebar_header_action('nav')
	assert header.accessibility_label == 'Acme, Enterprise'
	footer := sidebar_test_find(el, 'footer') or { panic('none') }
	assert !footer.button_behavior
}

fn test_sidebar_rail_items_carry_tooltips_and_badge_dots() {
	config := SidebarConfig{
		...sidebar_test_config(SidebarState{})
		frame:     rect(0, 0, 48, 600)
		collapsed: true
		side:      .right
	}
	el := sidebar(config) or { panic(err) }
	assert el.accessibility_value == 'collapsed'
	border := sidebar_test_find(el, 'border') or { panic('none') }
	assert border.frame.x == 0
	home := sidebar_test_find(el, 'item:home') or { panic('none') }
	assert home.tooltip == 'Home'
	inbox := sidebar_test_find(el, 'item:inbox') or { panic('none') }
	assert inbox.tooltip == 'Inbox (12)'
	_ := sidebar_test_find(inbox, 'badge') or { panic('no badge dot in the rail') }
	projects := sidebar_test_find(el, 'item:projects') or { panic('none') }
	if _ := sidebar_test_find(projects, 'chevron') {
		assert false, 'the rail draws a chevron'
	}
	header := sidebar_test_find(el, 'header') or { panic('none') }
	assert header.tooltip == 'Acme'
}

fn test_sidebar_offcanvas_collapse_builds_hidden() {
	config := SidebarConfig{
		...sidebar_test_config(SidebarState{})
		collapsible: .offcanvas
		collapsed:   true
	}
	el := sidebar(config) or { panic(err) }
	assert el.hidden
	assert el.children.len == 0
	if _ := sidebar_item_anchor(config, 'home') {
		assert false, 'a hidden sidebar anchors'
	}
	if _ := sidebar_update(config, sidebar_item_action('nav', 'home')) {
		assert false, 'a hidden sidebar takes presses'
	}
	step := sidebar_test_press(config, sidebar_collapse_action('nav'))
	assert step.event == .collapse
	assert !step.collapsed
}

fn test_sidebar_widths() {
	assert sidebar_rail_width(.medium) == 48
	assert sidebar_rail_width(.small) < sidebar_rail_width(.large)
	assert sidebar_width(255, false, .icon, .medium) == 255
	assert sidebar_width(255, true, .icon, .medium) == 48
	assert sidebar_width(255, true, .offcanvas, .medium) == 0
	assert sidebar_width(255, true, .none, .medium) == 255
	assert sidebar_auto_collapsed(600, sidebar_breakpoint, false)
	assert !sidebar_auto_collapsed(1024, sidebar_breakpoint, false)
	assert sidebar_auto_collapsed(1024, sidebar_breakpoint, true)
}

fn test_sidebar_colors_tell_rows_apart_in_both_themes() {
	for dark in [false, true] {
		theme := component_theme(dark)
		c := sidebar_colors(theme)
		assert c.background != theme.background
		assert c.hover != c.background
		assert c.active != c.hover
		assert c.pressed != c.hover
		assert c.ring == theme.primary
	}
	assert sidebar_colors(component_theme(false)).background != sidebar_colors(component_theme(true)).background
}

fn test_sidebar_toggle_button_emits_the_collapse_action() {
	el := sidebar_toggle_button(
		id:         'toggle'
		sidebar_id: 'nav'
		frame:      rect(10, 10, 32, 32)
	) or { panic('none') }
	assert el.id == 'toggle'
	assert el.action_id == sidebar_collapse_action('nav')
	assert el.button_behavior
	assert el.accessibility_label == 'Collapse sidebar'
	assert el.accessibility_value == 'expanded'
	assert el.box.transparent
	collapsed := sidebar_toggle_button(
		id:         'toggle'
		sidebar_id: 'nav'
		frame:      rect(10, 10, 32, 32)
		collapsed:  true
		hovered:    true
	) or { panic('none') }
	assert collapsed.tooltip == 'Expand sidebar'
	assert !collapsed.box.transparent
	// Expanded draws the pane filled; collapsed only outlines it.
	assert el.children[0].children.len == collapsed.children[0].children.len + 1
	if _ := sidebar_toggle_button(id: 'toggle', frame: rect(0, 0, 32, 32)) {
		assert false, 'a toggle without a sidebar accepted'
	}
}

// ── Updates ─────────────────────────────────────────────────────────

fn test_sidebar_item_press_activates_and_rejects_no_ops() {
	config := sidebar_test_config(SidebarState{
		active:  'home'
		focused: 'inbox'
	})
	step := sidebar_test_press(config, sidebar_item_action('nav', 'inbox'))
	assert step.event == .activate
	assert step.item.id == 'inbox'
	assert step.state.active == 'inbox'
	// A press hides the keyboard cursor.
	assert step.state.focused == ''
	again := SidebarConfig{
		...config
		state: step.state
	}
	if _ := sidebar_update(again, sidebar_item_action('nav', 'inbox')) {
		assert false, 'pressing the current item changed something'
	}
	item := sidebar_item_from_action(config, sidebar_item_action('nav', 'inbox')) or {
		panic('none')
	}
	assert item.id == 'inbox'
	if _ := sidebar_item_from_action(again, sidebar_item_action('nav', 'inbox')) {
		assert false, 'the current item decoded as a new one'
	}
}

fn test_sidebar_rejects_foreign_malformed_forged_hidden_and_disabled_actions() {
	config := sidebar_test_config(SidebarState{})
	inbox_hex := 'inbox'.bytes().hex()
	rejected := [
		'inbox',
		sidebar_item_action('other', 'inbox'),
		'nav:component:item:',
		'nav:component:item:zz',
		'nav:component:item:' + inbox_hex.to_upper(),
		'nav:component:item' + inbox_hex,
		'nav:component:open:' + inbox_hex,
		sidebar_item_action('nav', 'missing'),
		// Sub-items of a collapsed item are not shown, so a press on one is forged.
		sidebar_item_action('nav', 'mobile'),
		sidebar_item_action('nav', 'archive'),
		sidebar_expand_action('nav', 'home'),
		sidebar_more_action('nav', 'home'),
		sidebar_group_action('nav', 'missing'),
		sidebar_footer_action('nav'),
		'pointer:enter:' + sidebar_item_action('nav', 'archive') + ':1:1',
		'pointer:down:' + sidebar_item_action('nav', 'home') + ':1:1',
	]
	for action in rejected {
		if step := sidebar_update(config, action) {
			assert false, '`${action}` accepted as ${step.event}'
		}
	}
	expanded := sidebar_test_config(SidebarState{
		expanded: ['projects']
	})
	if _ := sidebar_update(expanded, sidebar_item_action('nav', 'legacy')) {
		assert false, 'a disabled sub-item accepted'
	}
	step := sidebar_test_press(expanded, sidebar_item_action('nav', 'mobile'))
	assert step.state.active == 'mobile'
}

fn test_sidebar_chevron_and_click_modes_show_sub_items() {
	config := sidebar_test_config(SidebarState{})
	step := sidebar_test_press(config, sidebar_expand_action('nav', 'projects'))
	assert step.event == .expand
	assert step.state.expanded == ['projects']
	assert step.state.active == ''
	closed := sidebar_test_press(SidebarConfig{
		...config
		state: step.state
	}, sidebar_expand_action('nav', 'projects'))
	assert closed.state.expanded.len == 0
	shown := sidebar_expanded_from_action(config, sidebar_expand_action('nav', 'projects')) or {
		panic('none')
	}
	assert shown == ['projects']
	// The default click only activates.
	plain := sidebar_test_press(config, sidebar_item_action('nav', 'projects'))
	assert plain.event == .activate
	assert plain.state.expanded.len == 0
	if _ := sidebar_expanded_from_action(config, sidebar_item_action('nav', 'projects')) {
		assert false, 'a plain click reported an expansion'
	}
	for mode in [SidebarItemClick.open, .toggle] {
		mut groups := sidebar_test_groups()
		mut items := groups[0].items.clone()
		items[2] = SidebarItem{
			...items[2]
			click: mode
		}
		groups[0] = SidebarGroup{
			...groups[0]
			items: items
		}
		with_mode := SidebarConfig{
			...config
			groups: groups
			state:  SidebarState{
				active:   'projects'
				expanded: ['projects']
			}
		}
		pressed := sidebar_update(with_mode, sidebar_item_action('nav', 'projects'))
		if mode == .open {
			if _ := pressed {
				assert false, 'open on an open, current item changed something'
			}
		} else {
			toggled := pressed or { panic('toggle did nothing') }
			assert toggled.event == .expand
			assert toggled.state.expanded.len == 0
		}
		first := sidebar_update(SidebarConfig{
			...with_mode
			state: SidebarState{}
		}, sidebar_item_action('nav', 'projects')) or { panic('none') }
		assert first.event == .activate
		assert first.state.expanded == ['projects']
	}
}

fn test_sidebar_group_more_header_footer_and_collapse_actions() {
	config := sidebar_test_config(SidebarState{
		focused: 'home'
	})
	group := sidebar_test_press(config, sidebar_group_action('nav', 'settings'))
	assert group.event == .group
	assert group.group.id == 'settings'
	assert group.state.closed_groups == ['settings']
	assert group.state.focused == ''
	reopened := sidebar_closed_groups_from_action(SidebarConfig{
		...config
		state: group.state
	}, sidebar_group_action('nav', 'settings')) or { panic('none') }
	assert reopened.len == 0
	more := sidebar_test_press(config, sidebar_more_action('nav', 'projects'))
	assert more.event == .more
	assert more.item.id == 'projects'
	header := sidebar_test_press(config, sidebar_header_action('nav'))
	assert header.event == .header
	collapse := sidebar_test_press(config, sidebar_collapse_action('nav'))
	assert collapse.event == .collapse
	assert collapse.collapsed
	expanded := sidebar_collapsed_from_action('nav', true, sidebar_collapse_action('nav')) or {
		panic('none')
	}
	assert !expanded
	if _ := sidebar_collapsed_from_action('nav', true, sidebar_collapse_action('other')) {
		assert false, 'a foreign toggle decoded'
	}
	fixed := SidebarConfig{
		...config
		collapsible: .none
	}
	if _ := sidebar_update(fixed, sidebar_collapse_action('nav')) {
		assert false, 'a sidebar that never collapses took the toggle'
	}
	rail := SidebarConfig{
		...config
		collapsed: true
		frame:     rect(0, 0, 48, 600)
	}
	for action in [sidebar_group_action('nav', 'settings'), sidebar_more_action('nav', 'projects'),
		sidebar_expand_action('nav', 'projects')] {
		if _ := sidebar_update(rail, action) {
			assert false, 'the rail took `${action}`, which it does not draw'
		}
	}
}

fn test_sidebar_rail_parent_press_asks_for_a_flyout() {
	config := SidebarConfig{
		...sidebar_test_config(SidebarState{
			active: 'mobile'
		})
		collapsed: true
		frame:     rect(0, 0, 48, 600)
	}
	step := sidebar_test_press(config, sidebar_item_action('nav', 'projects'))
	assert step.event == .flyout
	assert step.item.id == 'projects'
	assert step.state.active == 'mobile'
	rows := sidebar_flyout_items(config, 'projects')
	assert rows.len == 3
	assert rows[0].id == 'web'
	assert !rows[0].checked
	assert rows[1].checked
	assert !rows[2].enabled
	validate_dropdown_menu_items(rows) or { panic(err) }
	assert sidebar_flyout_items(config, 'missing').len == 0
}

fn test_sidebar_select_reveals_the_item() {
	config := sidebar_test_config(SidebarState{
		closed_groups: ['settings']
	})
	state := sidebar_select(config, 'mobile') or { panic('none') }
	assert state.active == 'mobile'
	assert state.expanded == ['projects']
	general := sidebar_select(config, 'general') or { panic('none') }
	assert general.closed_groups.len == 0
	if _ := sidebar_select(config, 'legacy') {
		assert false, 'a disabled item selected'
	}
	if _ := sidebar_select(config, 'missing') {
		assert false, 'an unknown item selected'
	}
}

fn test_sidebar_hover_follows_the_pointer() {
	config := sidebar_test_config(SidebarState{})
	row := sidebar_item_action('nav', 'home')
	enter := sidebar_test_press(config, 'pointer:enter:${row}:4:5')
	assert enter.event == .hover
	assert enter.state.hovered == row
	hovering := SidebarConfig{
		...config
		state: enter.state
	}
	if _ := sidebar_update(hovering, 'pointer:enter:${row}:4:5') {
		assert false, 'entering twice changed something'
	}
	if _ := sidebar_update(hovering, 'pointer:leave:${sidebar_item_action('nav', 'inbox')}:4:5') {
		assert false, 'leaving another row cleared the hover'
	}
	leave := sidebar_test_press(hovering, 'pointer:leave:${row}:4:5')
	assert leave.state.hovered == ''
	header := sidebar_test_press(config, 'pointer:enter:${sidebar_header_action('nav')}:1:1')
	assert header.state.hovered == sidebar_header_action('nav')
	toggle := sidebar_test_press(config, 'pointer:enter:${sidebar_collapse_action('nav')}:1:1')
	assert sidebar_toggle_hovered(toggle.state, 'nav')
	assert !sidebar_toggle_hovered(toggle.state, 'other')
}

// ── Keyboard ────────────────────────────────────────────────────────

fn test_sidebar_keys_move_through_shown_entries_without_wrapping() {
	config := sidebar_test_config(SidebarState{
		active: 'inbox'
	})
	// The first key starts on the current item.
	first := sidebar_test_key(config, .down) or { panic('none') }
	assert first.event == .focus
	assert first.state.focused == 'inbox'
	assert first.reveal
	mut state := first.state
	mut visited := []string{}
	for _ in 0 .. 10 {
		step := sidebar_test_key(SidebarConfig{
			...config
			state: state
		}, .down) or { break }
		state = step.state
		visited << state.focused
	}
	// Disabled items are skipped; the collapsible group's label is a stop.
	assert visited == ['projects', 'settings', 'general', 'billing']
	up := sidebar_test_key(SidebarConfig{
		...config
		state: state
	}, .up) or { panic('none') }
	assert up.state.focused == 'general'
	home := sidebar_test_key(SidebarConfig{
		...config
		state: state
	}, .home) or { panic('none') }
	assert home.state.focused == 'home'
	if _ := sidebar_test_key(SidebarConfig{
		...config
		state: home.state
	}, .up)
	{
		assert false, 'Up wrapped around'
	}
	end := sidebar_test_key(config, .end) or { panic('none') }
	assert end.state.focused == 'billing'
	if _ := sidebar_key(config, KeyEvent{
		code: .down
		cmd:  true
	})
	{
		assert false, 'a shortcut moved the cursor'
	}
	escape := sidebar_test_key(SidebarConfig{
		...config
		state: state
	}, .escape) or { panic('none') }
	assert escape.state.focused == ''
	if _ := sidebar_test_key(config, .escape) {
		assert false, 'Escape without a cursor did something'
	}
}

fn test_sidebar_left_and_right_fold_and_climb_like_a_tree() {
	at := fn (focused string, expanded []string, closed []string) SidebarConfig {
		return sidebar_test_config(SidebarState{
			focused:       focused
			expanded:      expanded
			closed_groups: closed
		})
	}
	open := sidebar_test_key(at('projects', [], []), .right) or { panic('none') }
	assert open.event == .expand
	assert open.state.expanded == ['projects']
	assert open.state.focused == 'projects'
	into := sidebar_test_key(at('projects', ['projects'], []), .right) or { panic('none') }
	assert into.state.focused == 'web'
	up := sidebar_test_key(at('web', ['projects'], []), .left) or { panic('none') }
	assert up.state.focused == 'projects'
	fold := sidebar_test_key(at('projects', ['projects'], []), .left) or { panic('none') }
	assert fold.state.expanded.len == 0
	if _ := sidebar_test_key(at('home', [], []), .left) {
		assert false, 'Left on a top-level item of a plain group did something'
	}
	if _ := sidebar_test_key(at('home', [], []), .right) {
		assert false, 'Right on an item without sub-items did something'
	}
	to_label := sidebar_test_key(at('general', [], []), .left) or { panic('none') }
	assert to_label.state.focused == 'settings'
	close := sidebar_test_key(at('settings', [], []), .left) or { panic('none') }
	assert close.event == .group
	assert close.state.closed_groups == ['settings']
	reopen := sidebar_test_key(at('settings', [], ['settings']), .right) or { panic('none') }
	assert reopen.state.closed_groups.len == 0
	first := sidebar_test_key(at('settings', [], []), .right) or { panic('none') }
	assert first.state.focused == 'general'
	toggled := sidebar_test_key(at('settings', [], []), .enter) or { panic('none') }
	assert toggled.event == .group
}

fn test_sidebar_enter_activates_and_follow_focus_activates_while_moving() {
	config := sidebar_test_config(SidebarState{
		active:  'home'
		focused: 'billing'
	})
	enter := sidebar_test_key(config, .enter) or { panic('none') }
	assert enter.event == .activate
	assert enter.state.active == 'billing'
	assert enter.state.focused == 'billing'
	space := sidebar_test_key(config, .space) or { panic('none') }
	assert space.state.active == 'billing'
	following := SidebarConfig{
		...config
		follow_focus: true
	}
	moved := sidebar_test_key(following, .up) or { panic('none') }
	assert moved.event == .activate
	assert moved.state.active == 'general'
	assert moved.reveal
	// A group's label takes the cursor but is not a page.
	label_step := sidebar_test_key(SidebarConfig{
		...following
		state: moved.state
	}, .up) or { panic('none') }
	assert label_step.event == .focus
	assert label_step.state.active == 'general'
	rail := SidebarConfig{
		...config
		collapsed: true
		frame:     rect(0, 0, 48, 600)
		state:     SidebarState{
			focused: 'projects'
		}
	}
	flyout := sidebar_test_key(rail, .enter) or { panic('none') }
	assert flyout.event == .flyout
	if _ := sidebar_test_key(rail, .right) {
		assert false, 'Right in the rail did something'
	}
}

// ── Anchors ─────────────────────────────────────────────────────────

fn test_sidebar_anchors_follow_the_frame_and_the_scroll() {
	config := SidebarConfig{
		...sidebar_test_config(SidebarState{})
		frame: rect(100, 20, 255, 600)
	}
	home := sidebar_item_anchor(config, 'home') or { panic('none') }
	assert home == rect(108, 112, 238, 32)
	header := sidebar_header_anchor(config) or { panic('none') }
	assert header == rect(108, 28, 238, 48)
	footer := sidebar_footer_anchor(config) or { panic('none') }
	assert footer.y == 20 + 544
	more := sidebar_more_anchor(config, 'projects') or { panic('none') }
	row := sidebar_item_anchor(config, 'projects') or { panic('none') }
	assert more.x > row.x + row.width / 2
	assert more.x + more.width < row.x + row.width
	assert more.y > row.y && more.y + more.height < row.y + row.height
	if _ := sidebar_more_anchor(config, 'home') {
		assert false, 'an item without a ⋯ button anchors one'
	}
	if _ := sidebar_item_anchor(config, 'mobile') {
		assert false, 'a hidden sub-item anchors'
	}
	short := SidebarConfig{
		...config
		frame:  rect(0, 0, 255, 300)
		offset: 40
	}
	scrolled := sidebar_item_anchor(short, 'home') or { panic('none') }
	assert scrolled.y == 60 + 32 - 40
}

fn test_sidebar_reveal_offset_scrolls_as_little_as_it_can() {
	config := SidebarConfig{
		...sidebar_test_config(SidebarState{})
		frame: rect(0, 0, 255, 300)
	}
	model := sidebar_model(config) or { panic(err) }
	assert model.scrolls
	assert model.body.height == 180
	if _ := sidebar_reveal_offset(sidebar_test_config(SidebarState{}), 'home') {
		assert false, 'groups that fit asked to scroll'
	}
	// Home is in view at the top.
	top := sidebar_reveal_offset(config, 'home') or { panic('none') }
	assert top == 0
	// Billing is below the fold: scroll until its bottom (and a margin) shows.
	billing := model.item_row('billing') or { panic('none') }
	down := sidebar_reveal_offset(config, 'billing') or { panic('none') }
	assert down == billing.frame.y + billing.frame.height + 4 - 180
	// Scrolled past Home, revealing it scrolls back up to it.
	up := sidebar_reveal_offset(SidebarConfig{
		...config
		offset: down
	}, 'home') or { panic('none') }
	assert up == 28
	label_offset := sidebar_reveal_offset(SidebarConfig{
		...config
		offset: down
	}, 'settings') or { panic('none') }
	assert label_offset <= down
	if _ := sidebar_reveal_offset(config, 'mobile') {
		assert false, 'a hidden item revealed'
	}
}
