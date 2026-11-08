module ui2

// ── Helpers ─────────────────────────────────────────────────────────

fn nav2_items() []TabBarItem {
	return [
		tab_bar_item('a', 'Account'),
		tab_bar_item('b', 'Profile'),
		TabBarItem{
			id:      'c'
			label:   'Billing'
			enabled: false
		},
		TabBarItem{
			id:       'd'
			label:    'Documents'
			icon:     'doc'
			badge:    '3'
			closable: true
		},
	]
}

fn nav2_bar(selected string) TabBarConfig {
	return TabBarConfig{
		id:    'bar'
		frame: rect(0, 0, 600, tab_bar_height(.tab, .medium))
		items: nav2_items()
		state: TabBarState{
			selected: selected
		}
	}
}

fn nav2_find(el Element, key string) ?Element {
	if el.key == key {
		return el
	}
	for child in el.children {
		if found := nav2_find(child, key) {
			return found
		}
	}
	return none
}

fn nav2_find_id(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := nav2_find_id(child, id) {
			return found
		}
	}
	return none
}

fn nav2_count(el Element, key_prefix string) int {
	mut count := if el.key.starts_with(key_prefix) { 1 } else { 0 }
	for child in el.children {
		count += nav2_count(child, key_prefix)
	}
	return count
}

fn nav2_key(code KeyCode) KeyEvent {
	return KeyEvent{
		code: code
	}
}

fn nav2_pointer(phase string, action string, x f64, y f64) string {
	return 'pointer:${phase}:${action}:${x}:${y}'
}

// ── Tab bar layout ──────────────────────────────────────────────────

fn test_tab_bar_heights_follow_variant_and_size() {
	assert tab_bar_height(.tab, .medium) == 32
	assert tab_bar_height(.underline, .medium) == 36
	assert tab_bar_height(.tab, .small) == 24
	assert tab_bar_height(.underline, .large) == 44
	assert tab_bar_height(.folder, .medium) == 36
}

fn test_tab_bar_layout_packs_tabs_and_aligns_them() {
	layout := tab_bar_layout(nav2_bar('a')) or { panic(err) }
	assert layout.horizontal
	assert !layout.scrolls
	assert layout.tabs.len == 4
	assert layout.tabs[0].x == 0
	for i in 1 .. 4 {
		// The tab variant packs its tabs edge to edge.
		assert layout.tabs[i].x == layout.tabs[i - 1].x + layout.tabs[i - 1].width
		assert layout.tabs[i].height == 32
	}
	// A tab with an icon, badge and close button is wider than its label.
	assert layout.tabs[3].width > layout.tabs[1].width
	centered := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		align: .center
	}) or { panic(err) }
	last := centered.tabs[3]
	assert centered.tabs[0].x > 0
	assert centered.tabs[0].x - 1 <= 600 - (last.x + last.width)
	assert 600 - (last.x + last.width) - centered.tabs[0].x <= 1
}

fn test_tab_bar_layout_spaces_variants_and_fills() {
	outline := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		variant: .outline
	}) or { panic(err) }
	assert outline.tabs[1].x == outline.tabs[0].x + outline.tabs[0].width + 12
	segmented := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		variant: .segmented
		fill:    true
	}) or { panic(err) }
	// The strip sits inside the track; filled tabs share it.
	assert segmented.strip == rect(0, 4, 600, 24)
	assert segmented.tabs[0].x == 4
	end := segmented.tabs[3].x + segmented.tabs[3].width
	assert end > 595 && end <= 596.01
	folder := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		variant: .folder
		frame:   rect(0, 0, 600, tab_bar_height(.folder, .medium))
	}) or { panic(err) }
	// Folder tabs leave room for their curves and the bar's top space.
	assert folder.tabs[0].x == 8
	assert folder.tabs[0].y == 4
	assert folder.tabs[0].height == 32
}

fn test_tab_bar_layout_places_prefix_suffix_and_menu() {
	layout := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		prefix:      [view('back', rect(0, 0, 20, 20), BoxStyle{}, [])]
		prefix_size: 50
		suffix:      [view('add', rect(0, 0, 20, 20), BoxStyle{}, [])]
		suffix_size: 40
		menu:        true
	}) or { panic(err) }
	assert layout.prefix == rect(0, 0, 50, 32)
	assert layout.suffix == rect(560, 0, 40, 32)
	assert layout.more == rect(528, 0, 32, 32)
	assert layout.strip == rect(56, 0, 466, 32)
}

fn test_tab_bar_layout_scrolls_overflowing_tabs() {
	config := TabBarConfig{
		...nav2_bar('a')
		frame: rect(0, 0, 160, 32)
	}
	layout := tab_bar_layout(config) or { panic(err) }
	assert layout.scrolls
	assert layout.length > 160
	el := tab_bar(config) or { panic(err) }
	strip := nav2_find(el, 'strip') or { panic('no strip') }
	assert strip.kind == .scroll
	assert strip.id == tab_bar_scroll_id('bar')
	assert strip.scroll_mode == .horizontal_only
	fitting := tab_bar(nav2_bar('a')) or { panic(err) }
	assert (nav2_find(fitting, 'strip') or { panic('no strip') }).kind == .view
}

fn test_tab_bar_layout_caps_tab_width() {
	capped := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		max_tab_width: 60
		min_tab_width: 50
	}) or { panic(err) }
	for tab in capped.tabs {
		assert tab.width <= 60 && tab.width >= 50
	}
	el := tab_bar(TabBarConfig{
		...nav2_bar('a')
		max_tab_width: 60
	}) or { panic(err) }
	// A shortened label tells its whole text in a tooltip.
	documents := nav2_find(el, 'tab:d') or { panic('no tab') }
	assert documents.tooltip == 'Documents'
}

fn test_tab_bar_layout_stacks_vertical_tabs() {
	left := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		frame:    rect(0, 0, 160, 300)
		position: .left
	}) or { panic(err) }
	assert !left.horizontal
	assert left.tabs[0] == rect(0, 0, 160, 32)
	assert left.tabs[1] == rect(0, 32, 160, 32)
	right_folder := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		frame:    rect(0, 0, 160, 300)
		position: .right
		variant:  .folder
	}) or { panic(err) }
	// The folder's top space is on the side away from the content.
	assert right_folder.tabs[0].x == 0
	assert right_folder.tabs[0].width == 156
	bottom := tab_bar_layout(TabBarConfig{
		...nav2_bar('a')
		position: .bottom
		variant:  .folder
		frame:    rect(0, 0, 600, 36)
	}) or { panic(err) }
	assert bottom.tabs[0].y == 0
}

fn test_tab_bar_rejects_invalid_configs() {
	if _ := tab_bar(TabBarConfig{
		...nav2_bar('a')
		id: ' '
	})
	{
		assert false, 'empty id accepted'
	}
	if _ := tab_bar(TabBarConfig{
		...nav2_bar('a')
		items: [tab_bar_item('x', 'X'), tab_bar_item('x', 'Y')]
	})
	{
		assert false, 'duplicate tab ids accepted'
	}
	if _ := tab_bar(TabBarConfig{
		...nav2_bar('a')
		items: [TabBarItem{
			id: 'blank'
		}]
	})
	{
		assert false, 'a tab with neither label nor icon accepted'
	}
	if _ := tab_bar(TabBarConfig{
		...nav2_bar('a')
		items: [TabBarItem{
			id:   'x'
			icon: 'no.such.symbol'
		}]
	})
	{
		assert false, 'unknown symbol accepted'
	}
	if _ := tab_bar(TabBarConfig{
		...nav2_bar('a')
		max_tab_width: -1
	})
	{
		assert false, 'negative width accepted'
	}
}

// ── Tab bar elements ────────────────────────────────────────────────

fn test_tab_bar_element_exposes_tabs() {
	el := tab_bar(TabBarConfig{
		...nav2_bar('b')
		accessibility_label: 'Settings'
	}) or { panic(err) }
	assert el.accessibility_role == 'tablist'
	assert el.accessibility_label == 'Settings'
	profile := nav2_find(el, 'tab:b') or { panic('no tab') }
	assert profile.accessibility_role == 'tab'
	assert profile.accessibility_value == 'selected'
	assert profile.button_behavior
	assert profile.hoverable
	assert profile.action_id == tab_bar_tab_action('bar', 'b')
	// The selected tab takes the content's color and joins it.
	assert !profile.box.transparent
	assert profile.box.bg == ComponentTheme{}.background
	billing := nav2_find(el, 'tab:c') or { panic('no tab') }
	assert !billing.enabled
	assert billing.accessibility_value == 'not selected'
	documents := nav2_find(el, 'tab:d') or { panic('no tab') }
	close := nav2_find(documents, 'close') or { panic('no close button') }
	// A button's id is its action.
	assert close.id == tab_bar_close_action('bar', 'd')
	assert close.accessibility_label == 'Close Documents'
	assert nav2_find(documents, 'badge') != none
	assert nav2_find(documents, 'icon') != none
	assert !documents.draggable
}

fn test_tab_bar_variants_draw_their_selection() {
	for variant in [TabVariant.segmented, .pill, .underline] {
		el := tab_bar(TabBarConfig{
			...nav2_bar('b')
			variant: variant
			frame:   rect(0, 0, 600, tab_bar_height(variant, .medium))
			animate: false
		}) or { panic(err) }
		indicator := nav2_find(el, 'indicator:b') or { panic('no indicator for ${variant}') }
		assert indicator.id == component_part_id('bar', 'indicator')
		profile := nav2_find(el, 'tab:b') or { panic('no tab') }
		if variant == .underline {
			assert indicator.frame.height == 2
			assert indicator.frame.y == 34
			assert indicator.frame.x == profile.frame.x
		} else {
			assert indicator.frame == profile.frame
		}
	}
	folder := tab_bar(TabBarConfig{
		...nav2_bar('b')
		variant: .folder
		frame:   rect(0, 0, 600, tab_bar_height(.folder, .medium))
	}) or { panic(err) }
	shape_el := nav2_find(folder, 'folder') or { panic('no folder shape') }
	assert shape_el.path.len > 4
	// The selected folder tab reaches a curve past its tab on either side.
	tab := nav2_find(folder, 'tab:b') or { panic('no tab') }
	assert shape_el.frame.x == tab.frame.x - 8
	assert shape_el.frame.width == tab.frame.width + 16
	// Separators divide the tabs that are neither selected nor hovered.
	assert nav2_count(folder, 'divider:') == 1
	vertical := tab_bar(TabBarConfig{
		...nav2_bar('b')
		variant:  .underline
		position: .left
		frame:    rect(0, 0, 140, 300)
		animate:  false
	}) or { panic(err) }
	line := nav2_find(vertical, 'indicator:b') or { panic('no indicator') }
	assert line.frame == rect(138, 32, 2, 32)
}

fn test_tab_bar_application_actions_and_slots() {
	mut items := nav2_items()
	items[0] = TabBarItem{
		...items[0]
		action_id: 'show_account'
	}
	el := tab_bar(TabBarConfig{
		...nav2_bar('a')
		items:       items
		reorderable: true
		prefix:      [label('', 'P', rect(0, 0, 10, 10), TextStyle{})]
		prefix_size: 30
		menu:        true
	}) or { panic(err) }
	account := nav2_find(el, 'tab:a') or { panic('no tab') }
	assert account.action_id == 'show_account'
	assert account.draggable
	assert nav2_find(el, 'prefix') != none
	more := nav2_find(el, 'more') or { panic('no menu button') }
	assert more.action_id == dropdown_menu_toggle_action(tab_bar_menu_id('bar'))
	assert more.accessibility_value == 'collapsed'
}

// ── Tab bar events ──────────────────────────────────────────────────

fn test_tab_bar_update_selects_enabled_tabs() {
	config := nav2_bar('a')
	step := tab_bar_update(config, tab_bar_tab_action('bar', 'b')) or { panic('press ignored') }
	assert step.selected
	assert step.reveal
	assert step.state.selected == 'b'
	// The selected tab, a disabled tab, unknown tabs and forged actions change nothing.
	assert tab_bar_update(config, tab_bar_tab_action('bar', 'a')) == none
	assert tab_bar_update(config, tab_bar_tab_action('bar', 'c')) == none
	assert tab_bar_update(config, tab_bar_tab_action('bar', 'zz')) == none
	assert tab_bar_update(config, tab_bar_tab_action('other', 'b')) == none
	assert tab_bar_update(config, 'bar:component:tab:6G') == none
	assert tab_bar_update(config, 'bar:component:tab:62'.to_upper()) == none
	assert tab_bar_update(config, 'bar:component:tab:') == none
	assert tab_bar_update(config, 'something') == none
}

fn test_tab_bar_update_reports_close_and_hover() {
	config := nav2_bar('d')
	closed := tab_bar_update(config, tab_bar_close_action('bar', 'd')) or {
		panic('close ignored')
	}
	assert closed.closed == 'd'
	assert !closed.selected
	// Only closable, enabled tabs close.
	assert tab_bar_update(config, tab_bar_close_action('bar', 'a')) == none
	enter := tab_bar_update(config, nav2_pointer('enter', tab_bar_tab_action('bar', 'b'),
		10, 10)) or { panic('hover ignored') }
	assert enter.state.hovered == 'b'
	hovered := TabBarConfig{
		...config
		state: enter.state
	}
	assert tab_bar_update(hovered, nav2_pointer('enter', tab_bar_tab_action('bar', 'b'),
		10, 10)) == none
	leave := tab_bar_update(hovered, nav2_pointer('leave', tab_bar_tab_action('bar', 'b'),
		10, 10)) or { panic('leave ignored') }
	assert leave.state.hovered == ''
	assert tab_bar_update(config, nav2_pointer('enter', tab_bar_tab_action('bar', 'c'),
		10, 10)) == none
}

fn test_tab_bar_menu_opens_and_selects() {
	config := TabBarConfig{
		...nav2_bar('a')
		menu: true
	}
	rows := tab_bar_menu_items(config)
	assert rows.len == 4
	assert rows[0].checked && !rows[1].checked
	assert !rows[2].enabled
	opened := tab_bar_update(config, dropdown_menu_toggle_action(tab_bar_menu_id('bar'))) or {
		panic('menu toggle ignored')
	}
	assert opened.state.menu.open
	open := TabBarConfig{
		...config
		state: opened.state
	}
	chosen := tab_bar_update(open, dropdown_menu_item_action(tab_bar_menu_id('bar'), [3])) or {
		panic('menu choice ignored')
	}
	assert chosen.selected
	assert chosen.state.selected == 'd'
	assert !chosen.state.menu.open
	// Keys move through the open menu.
	down := tab_bar_key(open, nav2_key(.down)) or { panic('menu key ignored') }
	assert down.state.menu.path == [0]
	overlay := tab_bar_menu(open, tab_bar_menu_anchor(open), rect(0, 0, 800, 600)) or {
		panic(err)
	}
	assert overlay.children.len > 0
	assert tab_bar_menu_anchor(open) == rect(568, 0, 32, 32)
}

fn test_tab_bar_drag_reorders_tabs() {
	config := TabBarConfig{
		...nav2_bar('a')
		reorderable: true
	}
	layout := tab_bar_layout(config) or { panic(err) }
	action := tab_bar_tab_action('bar', 'a')
	down := tab_bar_update(config, nav2_pointer('down', action, 20, 10)) or {
		panic('down ignored')
	}
	assert down.state.drag.tab == 'a'
	assert !down.state.drag.active
	pressed := TabBarConfig{
		...config
		state: down.state
	}
	// A press released where it started is a click, not a move.
	click := tab_bar_update(pressed, nav2_pointer('up', action, 21, 10)) or {
		panic('up ignored')
	}
	assert !click.moved
	assert click.state.drag.tab == ''
	// Dragged past the middle of the second tab, the first lands after it.
	target := layout.tabs[1].x + layout.tabs[1].width / 2 - layout.tabs[0].width / 2 + 2
	moving := tab_bar_update(pressed, nav2_pointer('drag', action, 20 + target, 12)) or {
		panic('drag ignored')
	}
	assert moving.state.drag.active
	dragging := TabBarConfig{
		...config
		state: moving.state
	}
	// While dragging, the dragged tab follows the pointer and floats on top.
	el := tab_bar(dragging) or { panic(err) }
	strip := nav2_find(el, 'strip') or { panic('no strip') }
	assert strip.children.last().key == 'tab:a'
	assert strip.children.last().frame.x == target
	dropped := tab_bar_update(dragging, nav2_pointer('up', action, 20 + target, 12)) or {
		panic('drop ignored')
	}
	assert dropped.moved
	assert dropped.from == 0 && dropped.to == 1
	assert tab_bar_reorder(['a', 'b', 'c', 'd'], dropped.from, dropped.to) == ['b', 'a', 'c', 'd']
	assert tab_bar_reorder(['a', 'b', 'c'], 2, 0) == ['c', 'a', 'b']
	assert tab_bar_reorder(['a', 'b'], 0, 5) == ['a', 'b']
	// Pointer reports of a bar that does not reorder are ignored.
	assert tab_bar_update(nav2_bar('a'), nav2_pointer('down', action, 20, 10)) == none
}

fn test_tab_bar_drop_index_counts_passed_tabs() {
	layout := tab_bar_layout(nav2_bar('a')) or { panic(err) }
	assert tab_bar_drop_index(layout, 0, 0) == 0
	assert tab_bar_drop_index(layout, 0, 10000) == 3
	assert tab_bar_drop_index(layout, 3, -10000) == 0
	assert tab_bar_drop_index(layout, 2, 0) == 2
}

// ── Tab bar keys and helpers ────────────────────────────────────────

fn test_tab_bar_key_moves_between_enabled_tabs() {
	config := nav2_bar('b')
	right := tab_bar_key(config, nav2_key(.right)) or { panic('right ignored') }
	// The disabled tab is skipped.
	assert right.state.selected == 'd'
	assert right.reveal
	wrap := tab_bar_key(nav2_bar('d'), nav2_key(.right)) or { panic('right ignored') }
	assert wrap.state.selected == 'a'
	left := tab_bar_key(nav2_bar('a'), nav2_key(.left)) or { panic('left ignored') }
	assert left.state.selected == 'd'
	end := tab_bar_key(config, nav2_key(.end)) or { panic('end ignored') }
	assert end.state.selected == 'd'
	assert tab_bar_key(nav2_bar('a'), nav2_key(.home)) == none
	next := tab_bar_key(config, KeyEvent{
		code: .tab
		ctrl: true
	}) or { panic('ctrl+tab ignored') }
	assert next.state.selected == 'd'
	previous := tab_bar_key(config, KeyEvent{
		code:  .tab
		ctrl:  true
		shift: true
	}) or { panic('ctrl+shift+tab ignored') }
	assert previous.state.selected == 'a'
	// Arrows across the bar, plain Tab and modified arrows are left alone.
	assert tab_bar_key(config, nav2_key(.down)) == none
	assert tab_bar_key(config, nav2_key(.tab)) == none
	assert tab_bar_key(config, KeyEvent{
		code: .right
		cmd:  true
	}) == none
	vertical := TabBarConfig{
		...config
		position: .left
		frame:    rect(0, 0, 140, 300)
	}
	down := tab_bar_key(vertical, nav2_key(.down)) or { panic('down ignored') }
	assert down.state.selected == 'd'
	assert tab_bar_key(vertical, nav2_key(.right)) == none
	// With nothing selected the first key starts from an end.
	none_selected := tab_bar_key(nav2_bar(''), nav2_key(.right)) or { panic('right ignored') }
	assert none_selected.state.selected == 'a'
}

fn test_tab_bar_after_close_moves_selection_like_a_browser() {
	items := nav2_items()
	assert tab_bar_after_close(items, 'a', 'b') == 'a'
	assert tab_bar_after_close(items, 'b', 'b') == 'd'
	assert tab_bar_after_close(items, 'd', 'd') == 'b'
	assert tab_bar_after_close([tab_bar_item('x', 'X')], 'x', 'x') == ''
}

fn test_tab_bar_reveal_offset_shows_tab_and_neighbors() {
	config := TabBarConfig{
		...nav2_bar('a')
		frame: rect(0, 0, 200, 32)
	}
	layout := tab_bar_layout(config) or { panic(err) }
	assert layout.tabs[3].width < 200
	assert tab_bar_reveal_offset(nav2_bar('a'), 'a') == none
	assert tab_bar_reveal_offset(config, 'nope') == none
	first := tab_bar_reveal_offset(config, 'a') or { panic('no offset') }
	assert first == 0
	last := tab_bar_reveal_offset(config, 'd') or { panic('no offset') }
	assert last == layout.length - 200
	middle := tab_bar_reveal_offset(config, 'c') or { panic('no offset') }
	c := layout.tabs[2]
	assert middle <= c.x && middle + 200 >= c.x + c.width
	// A tab wider than the strip shows its start.
	narrow := TabBarConfig{
		...config
		frame: rect(0, 0, 120, 32)
	}
	narrow_layout := tab_bar_layout(narrow) or { panic(err) }
	assert tab_bar_reveal_offset(narrow, 'd') or { panic('no offset') } == narrow_layout.tabs[3].x
	// Part of the next tab stays in view when the tab itself fits with it.
	peeked := tab_bar_reveal_offset(TabBarConfig{
		...config
		frame: rect(0, 0, 220, 32)
	}, 'b') or { panic('no offset') }
	wide := tab_bar_layout(TabBarConfig{
		...config
		frame: rect(0, 0, 220, 32)
	}) or { panic(err) }
	assert peeked + 220 >= wide.tabs[2].x + 32 - 0.01
}

// ── Tabbed panel ────────────────────────────────────────────────────

fn nav2_panel_tabs() []TabbedPanelTab {
	return [
		TabbedPanelTab{
			title:   'One'
			content: view('one', rect(0, 0, 1, 1), BoxStyle{}, [])
		},
		TabbedPanelTab{
			title:     'Two'
			action_id: 'show_two'
			icon:      'star'
			content:   view('two', rect(0, 0, 1, 1), BoxStyle{}, [])
		},
		TabbedPanelTab{
			title:    'Three'
			closable: true
			badge:    '2'
			content:  view('three', rect(0, 0, 1, 1), BoxStyle{}, [])
		},
	]
}

fn test_tabbed_panel_themed_draws_a_tab_bar() {
	config := TabbedPanelConfig{
		id:      'panel'
		frame:   rect(0, 0, 400, 300)
		variant: .underline
		tabs:    nav2_panel_tabs()
	}
	geometry := tabbed_panel_geometry(config) or { panic(err) }
	assert geometry.content == rect(0, 36, 400, 264)
	assert geometry.headers.len == 3
	assert geometry.headers[0].y == 0
	el := tabbed_panel(config) or { panic(err) }
	assert el.children[0].id == 'one'
	assert el.children[0].frame == geometry.content
	bar := el.children[1]
	assert bar.accessibility_role == 'tablist'
	two := nav2_find(bar, 'tab:1') or { panic('no tab') }
	// A tab's own action is kept, so VML on_select handlers still fire.
	assert two.action_id == 'show_two'
	assert nav2_find(bar, 'tab:2') != none
	// Without a variant or theme the panel keeps its application-styled headers.
	legacy := tabbed_panel(TabbedPanelConfig{
		...config
		variant: none
	}) or { panic(err) }
	assert legacy.children[1].kind == .button
}

fn test_tabbed_panel_themed_positions() {
	left := TabbedPanelConfig{
		id:           'panel'
		frame:        rect(0, 0, 400, 300)
		theme:        component_theme(true)
		tab_position: .left_top
		bar_size:     120
		tabs:         nav2_panel_tabs()
	}
	geometry := tabbed_panel_geometry(left) or { panic(err) }
	assert geometry.content == rect(120, 0, 280, 300)
	assert geometry.headers[1] == rect(0, 32, 120, 32)
	bottom := tabbed_panel_geometry(TabbedPanelConfig{
		...left
		tab_position: .bottom_right
		variant:      .pill
	}) or { panic(err) }
	assert bottom.content == rect(0, 0, 400, 268)
	assert bottom.headers[0].y == 268
	last := bottom.headers[2]
	assert last.x + last.width == 400
	el := tabbed_panel(left) or { panic(err) }
	assert el.box.bg == component_theme(true).background
}

fn test_tabbed_panel_update_and_key() {
	config := TabbedPanelConfig{
		id:      'panel'
		frame:   rect(0, 0, 400, 300)
		variant: .tab
		tabs:    nav2_panel_tabs()
	}
	by_action := tabbed_panel_update(config, 'show_two') or { panic('action ignored') }
	assert by_action.current == 1 && by_action.selected
	bar := tabbed_panel_bar(config) or { panic(err) }
	by_tab := tabbed_panel_update(config, tab_bar_tab_action(bar.id, '2')) or {
		panic('tab ignored')
	}
	assert by_tab.current == 2
	closed := tabbed_panel_update(config, tab_bar_close_action(bar.id, '2')) or {
		panic('close ignored')
	}
	assert closed.closed == 2 && closed.current == 0 && !closed.selected
	hover := tabbed_panel_update(config, nav2_pointer('enter', 'show_two', 1, 1)) or {
		panic('hover ignored')
	}
	assert hover.hovered == 1
	assert tabbed_panel_update(config, tab_bar_tab_action(bar.id, '0')) == none
	assert tabbed_panel_update(config, tab_bar_tab_action(bar.id, '7')) == none
	// Keys work for the legacy look too.
	legacy := TabbedPanelConfig{
		frame: rect(0, 0, 400, 300)
		tabs:  nav2_panel_tabs()
	}
	right := tabbed_panel_key(legacy, nav2_key(.right)) or { panic('key ignored') }
	assert right.current == 1 && right.selected
	assert tabbed_panel_update(legacy, 'show_two') or { panic('legacy action ignored') }.current == 1
	vertical := tabbed_panel_key(TabbedPanelConfig{
		...legacy
		tab_position: .right_mid
	}, nav2_key(.down)) or { panic('key ignored') }
	assert vertical.current == 1
}

// ── Tree view: model ────────────────────────────────────────────────

fn nav2_nodes() []TreeViewNode {
	return [
		TreeViewNode{
			id:       'src'
			text:     'src'
			icon:     'folder'
			expanded: true
			children: [
				TreeViewNode{
					id:      'main'
					text:    'main.v'
					checked: true
				},
				TreeViewNode{
					id:   'lib'
					text: 'lib.v'
				},
				TreeViewNode{
					id:       'ui'
					text:     'ui'
					children: [
						TreeViewNode{
							id:   'tree'
							text: 'tree.v'
						},
					]
				},
			]
		},
		TreeViewNode{
			id:           'remote'
			text:         'remote'
			has_children: true
		},
		TreeViewNode{
			id:      'locked'
			text:    'locked'
			enabled: false
		},
		TreeViewNode{
			id:   'readme'
			text: 'README.md'
		},
	]
}

fn nav2_tree(nodes []TreeViewNode) TreeViewConfig {
	return TreeViewConfig{
		id:        'tree'
		frame:     rect(0, 0, 300, 400)
		nodes:     nodes
		theme:     ComponentTheme{}
		selection: .multiple
	}
}

fn test_tree_view_check_state_is_tri_state() {
	nodes := nav2_nodes()
	assert tree_view_check_state(nodes[0]) == .mixed
	assert tree_view_check_state(nodes[0].children[0]) == .checked
	assert tree_view_check_state(nodes[0].children[2]) == .unchecked
	all := tree_view_apply(nodes, TreeViewStep{
		checked: ['lib', 'tree']
	})
	assert tree_view_check_state(all[0]) == .checked
}

fn test_tree_view_themed_rows_use_size_metrics() {
	config := nav2_tree(nav2_nodes())
	rows := tree_view_rows(config) or { panic(err) }
	assert rows.len == 7
	assert rows[0].frame == rect(5, 5, 290, 28)
	assert rows[1].depth == 1
	assert rows[1].frame.y == 33
	assert tree_view_content_height(config)! == 7 * 28 + 8
	small := tree_view_rows(TreeViewConfig{
		...config
		size: .small
	}) or { panic(err) }
	assert small[1].frame.y == 29
	// Without a theme the application's geometry is kept.
	legacy := tree_view_rows(TreeViewConfig{
		...config
		theme: none
	}) or { panic(err) }
	assert legacy[0].frame == rect(0, 0, 300, 36)
}

fn test_tree_view_helpers_reveal_filter_and_load() {
	nodes := nav2_nodes()
	assert tree_view_find(nodes, 'tree') or { panic('not found') }.text == 'tree.v'
	assert tree_view_find(nodes, 'nope') == none
	revealed := tree_view_reveal(nodes, 'tree')
	assert tree_view_find(revealed, 'ui') or { panic('') }.expanded
	filtered := tree_view_filter(nodes, 'TREE')
	assert filtered.len == 1
	assert filtered[0].expanded && filtered[0].children.len == 1
	assert filtered[0].children[0].expanded
	assert filtered[0].children[0].children[0].id == 'tree'
	assert tree_view_filter(nodes, '  ').len == 4
	assert tree_view_filter(nodes, 'zzz').len == 0
	loaded := tree_view_with_children(nodes, 'remote', [TreeViewNode{
		id:   'remote/a'
		text: 'a'
	}])
	remote := tree_view_find(loaded, 'remote') or { panic('') }
	assert remote.children.len == 1 && !remote.loading
	empty := tree_view_with_children(nodes, 'remote', [])
	assert !tree_view_is_folder(tree_view_find(empty, 'remote') or { panic('') })
	assert tree_view_selected_ids(tree_view_apply(nodes, TreeViewStep{
		selection: true
		selected:  ['lib', 'readme']
	})) == ['lib', 'readme']
}

fn test_tree_view_move_nodes() {
	nodes := nav2_nodes()
	inside := tree_view_move_nodes(nodes, TreeViewMove{
		node:     'readme'
		target:   'ui'
		position: .inside
	}) or { panic('move refused') }
	ui := tree_view_find(inside, 'ui') or { panic('') }
	assert ui.expanded
	assert ui.children.map(it.id) == ['tree', 'readme']
	assert inside.len == 3
	before := tree_view_move_nodes(nodes, TreeViewMove{
		node:     'readme'
		target:   'src'
		position: .before
	}) or { panic('move refused') }
	assert before.map(it.id) == ['readme', 'src', 'remote', 'locked']
	after := tree_view_move_nodes(nodes, TreeViewMove{
		node:     'main'
		target:   'lib'
		position: .after
	}) or { panic('move refused') }
	assert after[0].children.map(it.id) == ['lib', 'main', 'ui']
	// Into itself or its own subtree, and unknown nodes, go nowhere.
	assert tree_view_move_nodes(nodes, TreeViewMove{
		node:     'src'
		target:   'tree'
		position: .inside
	}) == none
	assert tree_view_move_nodes(nodes, TreeViewMove{
		node:   'src'
		target: 'src'
	}) == none
	assert tree_view_move_nodes(nodes, TreeViewMove{
		node:   'nope'
		target: 'src'
	}) == none
}

// ── Tree view: elements ─────────────────────────────────────────────

fn test_tree_view_themed_element() {
	mut nodes := nav2_nodes()
	nodes = tree_view_apply(nodes, TreeViewStep{
		selection: true
		selected:  ['lib']
	})
	config := TreeViewConfig{
		...nav2_tree(nodes)
		checkable:           true
		state:               TreeViewState{
			hovered: 'readme'
			active:  'lib'
		}
		accessibility_label: 'Files'
	}
	el := tree_view(config) or { panic(err) }
	assert el.accessibility_role == 'tree'
	assert el.accessibility_label == 'Files'
	src := nav2_find(el, 'node:src') or { panic('no row') }
	assert src.accessibility_role == 'treeitem'
	assert src.accessibility_value == 'expanded, mixed'
	assert src.action_id == tree_view_row_action('tree', 'src')
	toggle := nav2_find(src, 'toggle') or { panic('no disclosure') }
	assert toggle.action_id == tree_view_toggle_action('tree', 'src')
	check := nav2_find(src, 'check') or { panic('no check box') }
	assert check.accessibility_value == 'mixed'
	assert check.id == tree_view_check_action('tree', 'src')
	lib := nav2_find(el, 'node:lib') or { panic('no row') }
	assert lib.accessibility_value.starts_with('selected')
	assert lib.box.bg == list_selected_fill(ComponentTheme{})
	readme := nav2_find(el, 'node:readme') or { panic('no row') }
	assert readme.box.bg == ComponentTheme{}.muted
	// Rows nested a level deeper draw an indent guide.
	assert nav2_find(lib, 'guide:0') != none
	assert nav2_find(src, 'guide:0') == none
	locked := nav2_find(el, 'node:locked') or { panic('no row') }
	assert !locked.enabled
	assert !locked.hoverable
	assert nav2_find(el, 'node:tree') == none
	// The application's own actions are kept.
	mut with_actions := nav2_nodes()
	with_actions[3] = TreeViewNode{
		...with_actions[3]
		action_id: 'open_readme'
	}
	custom := tree_view(nav2_tree(with_actions)) or { panic(err) }
	assert (nav2_find(custom, 'node:readme') or { panic('') }).action_id == 'open_readme'
}

fn test_tree_view_row_content_replaces_icon_and_text() {
	config := TreeViewConfig{
		...nav2_tree(nav2_nodes())
		row_content: fn (node TreeViewNode, frame Rect, selected bool) []Element {
			return [label('', '${node.text}!', frame, TextStyle{})]
		}
	}
	el := tree_view(config) or { panic(err) }
	row := nav2_find(el, 'node:readme') or { panic('no row') }
	content := nav2_find(row, 'content') or { panic('no content') }
	assert content.children[0].text == 'README.md!'
	assert content.children[0].frame.height == 28
	assert nav2_find(row, 'text') == none
	// The disclosure is still the tree's.
	src := nav2_find(el, 'node:src') or { panic('no row') }
	assert nav2_find(src, 'toggle') != none
}

fn test_tree_view_loading_and_empty_rows() {
	mut nodes := nav2_nodes()
	nodes[1] = TreeViewNode{
		...nodes[1]
		expanded: true
		loading:  true
	}
	el := tree_view(nav2_tree(nodes)) or { panic(err) }
	loading := nav2_find(el, 'loading:remote') or { panic('no loading row') }
	assert loading.accessibility_role == 'status'
	empty := tree_view(nav2_tree([])) or { panic(err) }
	assert nav2_find(empty, 'empty') or { panic('no empty state') }.text == 'No items'
	if _ := tree_view(TreeViewConfig{
		...nav2_tree(nodes)
		id: ''
	})
	{
		assert false, 'themed tree without an id accepted'
	}
	if _ := tree_view(nav2_tree([TreeViewNode{
		id: 'x'
	}, TreeViewNode{
		id: 'x'
	}]))
	{
		assert false, 'duplicate node ids accepted'
	}
}

fn nav2_big_tree() []TreeViewNode {
	mut children := []TreeViewNode{}
	for i in 0 .. 1000 {
		children << TreeViewNode{
			id:   'n${i}'
			text: 'Node ${i}'
		}
	}
	return [TreeViewNode{
		id:       'root'
		text:     'root'
		expanded: true
		children: children
	}]
}

fn test_tree_view_virtualizes_and_scrolls() {
	config := TreeViewConfig{
		...nav2_tree(nav2_big_tree())
		virtualize: true
		overscan:   2
		offset:     28 * 500
	}
	el := tree_view(config) or { panic(err) }
	scroller := nav2_find(el, 'scroll') or { panic('no scroll') }
	assert scroller.kind == .scroll
	assert scroller.id == tree_view_scroll_id('tree')
	assert nav2_count(el, 'node:') < 25
	assert nav2_find(el, 'node:n499') != none
	assert nav2_find(el, 'node:n10') == none
	span := tree_view_visible_range(config) or { panic(err) }
	// Row 500 (n498, after the root) still shows its last pixels.
	assert span.visible_start == 499
	offset := tree_view_reveal_offset(config, 'n10') or { panic('no offset') }
	assert offset == 4 + 11 * 28
	assert tree_view_reveal_offset(config, 'n505') or { panic('no offset') } == config.offset
	assert tree_view_reveal_offset(config, 'nope') == none
}

// ── Tree view: events ───────────────────────────────────────────────

fn test_tree_view_update_selects_with_modifiers() {
	config := nav2_tree(nav2_nodes())
	plain := tree_view_update(config, tree_view_row_action('tree', 'lib'), ListModifiers{}) or {
		panic('press ignored')
	}
	assert plain.selection && plain.selected == ['lib']
	assert plain.confirmed
	assert plain.state.active == 'lib' && plain.state.anchor == 'lib'
	nodes := tree_view_apply(config.nodes, plain)
	after := TreeViewConfig{
		...config
		nodes: nodes
		state: plain.state
	}
	toggled := tree_view_update(after, tree_view_row_action('tree', 'readme'), ListModifiers{
		toggle: true
	}) or { panic('toggle ignored') }
	assert toggled.selected == ['lib', 'readme']
	assert !toggled.confirmed
	range_step := tree_view_update(after, tree_view_row_action('tree', 'remote'), ListModifiers{
		extend: true
	}) or { panic('extend ignored') }
	// The range runs through the visible, enabled rows from the anchor.
	assert range_step.selected == ['lib', 'ui', 'remote']
	single := tree_view_update(TreeViewConfig{
		...config
		selection: .single
	}, tree_view_row_action('tree', 'readme'), ListModifiers{
		extend: true
	}) or { panic('single ignored') }
	assert single.selected == ['readme']
	assert tree_view_update(config, tree_view_row_action('tree', 'locked'), ListModifiers{}) == none
	assert tree_view_update(config, tree_view_row_action('tree', 'nope'), ListModifiers{}) == none
	assert tree_view_update(config, 'tree:component:row:zz', ListModifiers{}) == none
	assert tree_view_update(config, tree_view_row_action('other', 'lib'), ListModifiers{}) == none
}

fn test_tree_view_update_opens_folders_and_loads() {
	config := nav2_tree(nav2_nodes())
	closing := tree_view_update(config, tree_view_toggle_action('tree', 'src'), ListModifiers{}) or {
		panic('toggle ignored')
	}
	assert closing.collapse == 'src'
	assert !closing.selection
	opening := tree_view_update(config, tree_view_toggle_action('tree', 'ui'), ListModifiers{}) or {
		panic('toggle ignored')
	}
	assert opening.expand == 'ui' && opening.load == ''
	lazy := tree_view_update(config, tree_view_toggle_action('tree', 'remote'), ListModifiers{}) or {
		panic('toggle ignored')
	}
	assert lazy.expand == 'remote' && lazy.load == 'remote'
	marked := tree_view_find(tree_view_apply(config.nodes, lazy), 'remote') or { panic('') }
	assert marked.expanded && marked.loading
	// A plain click on a folder opens it too, unless turned off.
	click := tree_view_update(config, tree_view_row_action('tree', 'ui'), ListModifiers{}) or {
		panic('press ignored')
	}
	assert click.expand == 'ui' && click.selected == ['ui']
	no_open := tree_view_update(TreeViewConfig{
		...config
		expand_on_click: false
	}, tree_view_row_action('tree', 'ui'), ListModifiers{}) or { panic('press ignored') }
	assert no_open.expand == ''
	// Closing the folder the cursor is in moves the cursor onto it.
	inside := tree_view_update(TreeViewConfig{
		...config
		state: TreeViewState{
			active: 'lib'
		}
	}, tree_view_toggle_action('tree', 'src'), ListModifiers{}) or { panic('toggle ignored') }
	assert inside.state.active == 'src'
	assert tree_view_update(config, tree_view_toggle_action('tree', 'readme'), ListModifiers{}) == none
	// Application toggle actions count as disclosure presses.
	mut nodes := nav2_nodes()
	nodes[0] = TreeViewNode{
		...nodes[0]
		toggle_action_id: 'toggle_src'
	}
	legacy := tree_view_update(TreeViewConfig{
		...config
		nodes: nodes
	}, 'toggle_src', ListModifiers{}) or { panic('app toggle ignored') }
	assert legacy.collapse == 'src'
}

fn test_tree_view_update_checks_subtrees() {
	config := TreeViewConfig{
		...nav2_tree(nav2_nodes())
		checkable: true
	}
	step := tree_view_update(config, tree_view_check_action('tree', 'src'), ListModifiers{}) or {
		panic('check ignored')
	}
	assert step.checked == ['src', 'main', 'lib', 'ui', 'tree']
	assert step.unchecked.len == 0
	nodes := tree_view_apply(config.nodes, step)
	assert tree_view_check_state(nodes[0]) == .checked
	again := tree_view_update(TreeViewConfig{
		...config
		nodes: nodes
	}, tree_view_check_action('tree', 'src'), ListModifiers{}) or { panic('check ignored') }
	assert again.unchecked.len == 5
	assert tree_view_update(nav2_tree(nav2_nodes()), tree_view_check_action('tree', 'src'),
		ListModifiers{}) == none
	assert tree_view_update(config, tree_view_check_action('tree', 'locked'), ListModifiers{}) == none
}

fn test_tree_view_update_hover() {
	config := nav2_tree(nav2_nodes())
	action := tree_view_row_action('tree', 'lib')
	enter := tree_view_update(config, nav2_pointer('enter', action, 5, 5), ListModifiers{}) or {
		panic('enter ignored')
	}
	assert enter.state.hovered == 'lib'
	hovered := TreeViewConfig{
		...config
		state: enter.state
	}
	assert tree_view_update(hovered, nav2_pointer('enter', action, 5, 5), ListModifiers{}) == none
	leave := tree_view_update(hovered, nav2_pointer('leave', action, 5, 5), ListModifiers{}) or {
		panic('leave ignored')
	}
	assert leave.state.hovered == ''
	assert tree_view_update(config, nav2_pointer('leave', action, 5, 5), ListModifiers{}) == none
}

fn nav2_drag(config TreeViewConfig, node string, dy f64) ?TreeViewStep {
	action := tree_view_row_action('tree', node)
	down := tree_view_update(config, nav2_pointer('down', action, 50, 100), ListModifiers{})?
	pressed := TreeViewConfig{
		...config
		state: down.state
	}
	moving := tree_view_update(pressed, nav2_pointer('drag', action, 52, 100 + dy), ListModifiers{})?
	dragging := TreeViewConfig{
		...pressed
		state: moving.state
	}
	return tree_view_update(dragging, nav2_pointer('up', action, 52, 100 + dy), ListModifiers{})
}

fn test_tree_view_drag_moves_nodes() {
	config := TreeViewConfig{
		...nav2_tree(nav2_nodes())
		reorderable: true
	}
	// README (row 6) dragged up by four rows lands in the middle of `ui`
	// (row 3), a closed folder: into it.
	into := nav2_drag(config, 'readme', -3 * 28) or { panic('drag ignored') }
	assert into.moved
	assert into.move == TreeViewMove{
		node:     'readme'
		target:   'ui'
		position: .inside
	}
	assert into.state.drag.node == ''
	// The top quarter of a row drops before it.
	before := nav2_drag(config, 'readme', -5 * 28 - 10) or { panic('drag ignored') }
	assert before.move.target == 'main' && before.move.position == .before
	// Dropping right where it is moves nothing.
	still := nav2_drag(config, 'lib', 11) or { panic('drag ignored') }
	assert !still.moved
	// A folder cannot go into its own subtree.
	own := nav2_drag(config, 'src', 3 * 28) or { panic('drag ignored') }
	assert !own.moved
	// While dragging, a ghost follows the pointer and the target is marked.
	action := tree_view_row_action('tree', 'readme')
	down := tree_view_update(config, nav2_pointer('down', action, 50, 100), ListModifiers{}) or {
		panic('')
	}
	moving := tree_view_update(TreeViewConfig{
		...config
		state: down.state
	}, nav2_pointer('drag', action, 50, 100 - 3 * 28), ListModifiers{}) or { panic('') }
	el := tree_view(TreeViewConfig{
		...config
		state: moving.state
	}) or { panic(err) }
	assert nav2_find(el, 'ghost') != none
	target := nav2_find(el, 'node:ui') or { panic('') }
	assert target.box.border_color == ComponentTheme{}.primary
	// A tree that does not reorder ignores presses' pointer reports.
	assert tree_view_update(nav2_tree(nav2_nodes()), nav2_pointer('down', action, 1, 1),
		ListModifiers{}) == none
}

// ── Tree view: keys ─────────────────────────────────────────────────

fn nav2_tree_at(active string) TreeViewConfig {
	return TreeViewConfig{
		...nav2_tree(nav2_nodes())
		state: TreeViewState{
			active: active
			anchor: active
		}
	}
}

fn test_tree_view_key_moves_and_wraps() {
	down := tree_view_key(nav2_tree_at('src'), nav2_key(.down)) or { panic('down ignored') }
	assert down.state.active == 'main'
	assert down.selected == ['main']
	assert down.reveal
	// The disabled row is skipped; the end wraps to the start.
	skip := tree_view_key(nav2_tree_at('remote'), nav2_key(.down)) or { panic('down ignored') }
	assert skip.state.active == 'readme'
	wrap := tree_view_key(nav2_tree_at('readme'), nav2_key(.down)) or { panic('down ignored') }
	assert wrap.state.active == 'src'
	up := tree_view_key(nav2_tree_at('src'), nav2_key(.up)) or { panic('up ignored') }
	assert up.state.active == 'readme'
	end := tree_view_key(nav2_tree_at('src'), nav2_key(.end)) or { panic('end ignored') }
	assert end.state.active == 'readme'
	extend := tree_view_key(nav2_tree_at('main'), KeyEvent{
		code:  .down
		shift: true
	}) or { panic('shift down ignored') }
	assert extend.selected == ['main', 'lib']
	assert extend.state.anchor == 'main'
	// Without a cursor, the keys start from the selection.
	mut nodes := nav2_nodes()
	nodes = tree_view_apply(nodes, TreeViewStep{
		selection: true
		selected:  ['lib']
	})
	from_selection := tree_view_key(nav2_tree(nodes), nav2_key(.down)) or {
		panic('down ignored')
	}
	assert from_selection.state.active == 'ui'
}

fn test_tree_view_key_opens_closes_and_confirms() {
	collapse := tree_view_key(nav2_tree_at('src'), nav2_key(.left)) or { panic('left ignored') }
	assert collapse.collapse == 'src'
	parent := tree_view_key(nav2_tree_at('lib'), nav2_key(.left)) or { panic('left ignored') }
	assert parent.state.active == 'src'
	assert tree_view_key(nav2_tree_at('readme'), nav2_key(.left)) == none
	expand := tree_view_key(nav2_tree_at('ui'), nav2_key(.right)) or { panic('right ignored') }
	assert expand.expand == 'ui'
	child := tree_view_key(nav2_tree_at('src'), nav2_key(.right)) or { panic('right ignored') }
	assert child.state.active == 'main'
	lazy := tree_view_key(nav2_tree_at('remote'), nav2_key(.right)) or {
		panic('right ignored')
	}
	assert lazy.load == 'remote'
	toggle := tree_view_key(nav2_tree_at('src'), nav2_key(.enter)) or { panic('enter ignored') }
	assert toggle.collapse == 'src'
	confirm := tree_view_key(nav2_tree_at('readme'), nav2_key(.enter)) or {
		panic('enter ignored')
	}
	assert confirm.confirmed && confirm.node.id == 'readme'
	cancel := tree_view_key(nav2_tree_at('readme'), nav2_key(.escape)) or {
		panic('escape ignored')
	}
	assert cancel.cancelled && cancel.state.active == ''
	assert tree_view_key(nav2_tree(nav2_nodes()), nav2_key(.escape)) == none
}

fn test_tree_view_key_space_and_select_all() {
	space := tree_view_key(nav2_tree_at('lib'), nav2_key(.space)) or { panic('space ignored') }
	assert space.selected == ['lib']
	check := tree_view_key(TreeViewConfig{
		...nav2_tree_at('src')
		checkable: true
	}, nav2_key(.space)) or { panic('space ignored') }
	assert check.checked.len == 5
	all := tree_view_key(nav2_tree_at('lib'), KeyEvent{
		code: .a
		cmd:  true
	}) or { panic('select all ignored') }
	assert all.selected == ['src', 'main', 'lib', 'ui', 'remote', 'readme']
	assert tree_view_key(TreeViewConfig{
		...nav2_tree_at('lib')
		selection: .single
	}, KeyEvent{
		code: .a
		ctrl: true
	}) == none
	assert tree_view_key(nav2_tree_at('lib'), KeyEvent{
		code: .down
		alt:  true
	}) == none
}
