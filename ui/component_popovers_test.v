// SPDX-License-Identifier: Apache-2.0
// The positioning cases marked as such are adapted from GPUI Kit's positioner
// tests (crates/base/src/positioner.rs, Longbridge, copyright 2024 - 2026);
// the other tests are new. See third_party/gpui-kit.
module ui2

import math

const popover_test_window = rect(0, 0, 500, 400)

fn popover_test_place(anchor Rect, side PopoverSide, align PopoverAlign, width f64, height f64) PopoverPlacement {
	return popover_place(
		anchor: anchor
		window: popover_test_window
		width:  width
		height: height
		side:   side
		align:  align
		offset: 0
		margin: 4
	) or { panic(err) }
}

// Adapted from positioner.rs: prefers_the_requested_side_when_it_fits.
fn test_popover_place_prefers_the_requested_side() {
	placed := popover_test_place(rect(200, 200, 40, 20), .top, .center, 80, 30)
	assert placed.side == .top
	assert !placed.flipped
	assert placed.frame == rect(180, 170, 80, 30)
}

// Adapted from positioner.rs: flips_to_the_opposite_side_when_the_preferred_side_does_not_fit.
fn test_popover_place_flips_when_the_preferred_side_has_no_room() {
	placed := popover_test_place(rect(200, 10, 40, 20), .top, .center, 80, 60)
	assert placed.side == .bottom
	assert placed.flipped
	assert placed.frame.y == 30
	right := popover_place(
		anchor: rect(260, 60, 32, 32)
		window: rect(0, 0, 300, 200)
		width:  120
		height: 30
		side:   .right
		offset: 0
		margin: 4
	) or { panic(err) }
	assert right.side == .left
	assert right.frame.x + right.frame.width == 260
}

// Adapted from positioner.rs: clamps_into_the_viewport_while_keeping_the_flipped_side.
fn test_popover_place_shifts_inside_the_window_and_keeps_its_side() {
	placed := popover_test_place(rect(480, 200, 40, 20), .bottom, .center, 120, 30)
	assert placed.side == .bottom
	assert placed.frame.x + placed.frame.width == 496
	assert placed.frame.y == 220
	high := popover_test_place(rect(20, 2, 32, 20), .right, .center, 120, 40)
	assert high.side == .right
	assert high.frame.y == 4
	assert high.frame.x == 52
}

// Adapted from positioner.rs: alignment_selects_the_leading_center_or_trailing_edge.
fn test_popover_place_aligns_start_center_and_end() {
	anchor := rect(200, 200, 100, 20)
	assert popover_test_place(anchor, .bottom, .start, 40, 30).frame.x == 200
	assert popover_test_place(anchor, .bottom, .center, 40, 30).frame.x == 230
	assert popover_test_place(anchor, .bottom, .end, 40, 30).frame.x == 260
	side_anchor := rect(200, 100, 40, 100)
	assert popover_test_place(side_anchor, .right, .start, 40, 30).frame.y == 100
	assert popover_test_place(side_anchor, .right, .center, 40, 30).frame.y == 135
	assert popover_test_place(side_anchor, .left, .end, 40, 30).frame == rect(160, 170, 40, 30)
}

// Adapted from positioner.rs: side_offset_adds_a_gap_between_trigger_and_popup.
fn test_popover_place_offset_and_arrow_add_to_the_gap() {
	gap := popover_place(
		anchor: rect(200, 200, 40, 20)
		window: popover_test_window
		width:  40
		height: 30
		offset: 8
	) or { panic(err) }
	assert gap.frame.y == 228
	with_arrow := popover_place(
		anchor: rect(200, 200, 40, 20)
		window: popover_test_window
		width:  40
		height: 30
		offset: 8
		arrow:  6
	) or { panic(err) }
	assert with_arrow.frame.y == 234
	above := popover_place(
		anchor: rect(200, 200, 40, 20)
		window: popover_test_window
		width:  40
		height: 30
		side:   .top
		offset: 8
		arrow:  6
	) or { panic(err) }
	assert above.frame.y + above.frame.height == 186
}

// Adapted from positioner.rs: uses_larger_side_when_neither_vertical_side_fits.
fn test_popover_place_takes_the_roomier_side_when_neither_fits() {
	placed := popover_place(
		anchor: rect(120, 20, 40, 20)
		window: rect(0, 0, 300, 100)
		width:  160
		height: 120
		side:   .top
		align:  .center
		offset: 0
		margin: 4
	) or { panic(err) }
	assert placed.side == .bottom
	assert placed.frame.y == 4
	assert placed.frame.x == 60
	stays := popover_place(
		anchor: rect(120, 60, 40, 20)
		window: rect(0, 0, 300, 100)
		width:  160
		height: 120
		side:   .top
		offset: 0
		margin: 4
	) or { panic(err) }
	assert stays.side == .top
}

fn test_popover_place_without_flip_or_shift() {
	no_flip := popover_place(
		anchor: rect(200, 10, 40, 20)
		window: popover_test_window
		width:  80
		height: 60
		side:   .top
		offset: 0
		margin: 4
		flip:   false
	) or { panic(err) }
	assert no_flip.side == .top
	assert no_flip.frame.y == 4
	no_shift := popover_place(
		anchor: rect(480, 200, 40, 20)
		window: popover_test_window
		width:  120
		height: 30
		offset: 0
		shift:  false
	) or { panic(err) }
	assert no_shift.frame.x == 480
	assert no_shift.frame.x + no_shift.frame.width > popover_test_window.width
}

fn test_popover_place_in_a_window_smaller_than_the_surface() {
	placed := popover_place(
		anchor: rect(10, 10, 10, 10)
		window: rect(0, 0, 50, 40)
		width:  200
		height: 100
		margin: 8
	) or { panic(err) }
	assert placed.frame.x == 8
	assert placed.frame.y == 8
	empty := popover_place(
		anchor: rect(0, 0, 0, 0)
		window: rect(0, 0, 0, 0)
		width:  10
		height: 10
	) or {
		panic(err)
	}
	assert empty.frame.width == 10
	shifted := popover_place(
		anchor: rect(10, 10, 10, 10)
		window: rect(100, 50, 300, 200)
		width:  40
		height: 20
		margin: 8
	) or { panic(err) }
	assert shifted.frame.x == 108
	assert shifted.frame.y == 58
}

fn test_popover_place_rounds_to_whole_points() {
	placed := popover_test_place(rect(10.3, 20.6, 41, 20), .bottom, .center, 30, 30)
	assert placed.frame.x == math.round(placed.frame.x)
	assert placed.frame.y == math.round(placed.frame.y)
}

fn test_popover_place_rejects_invalid_geometry() {
	for config in [
		PopoverPlacementConfig{
			anchor: rect(math.nan(), 0, 1, 1)
			window: popover_test_window
		},
		PopoverPlacementConfig{
			anchor: rect(0, 0, 1, 1)
			window: rect(0, 0, -1, 10)
		},
		PopoverPlacementConfig{
			window: popover_test_window
			width:  -1
		},
		PopoverPlacementConfig{
			window: popover_test_window
			height: math.inf(1)
		},
		PopoverPlacementConfig{
			window: popover_test_window
			offset: math.nan()
		},
		PopoverPlacementConfig{
			window: popover_test_window
			margin: -2
		},
		PopoverPlacementConfig{
			window: popover_test_window
			arrow:  -1
		},
	] {
		if _ := popover_place(config) {
			assert false, 'invalid placement accepted: ${config}'
		}
	}
}

fn test_popover_arrow_aims_at_the_anchor_clear_of_the_corners() {
	centered := popover_place(
		anchor: rect(200, 100, 40, 20)
		window: popover_test_window
		width:  120
		height: 60
		align:  .start
		arrow:  6
		radius: 6
	) or { panic(err) }
	assert centered.arrow == 220
	// An anchor near the surface's leading edge still gets an arrow clear of
	// the rounded corner: radius plus half the base.
	corner := popover_place(
		anchor: rect(10, 100, 4, 20)
		window: popover_test_window
		width:  120
		height: 60
		align:  .center
		arrow:  6
		radius: 6
	) or { panic(err) }
	assert corner.frame.x == 8
	assert corner.arrow == 8 + 12
	sideways := popover_place(
		anchor: rect(100, 200, 20, 40)
		window: popover_test_window
		width:  80
		height: 120
		side:   .right
		align:  .center
		arrow:  6
	) or { panic(err) }
	assert sideways.arrow == 220
}

fn test_popover_arrow_strips_build_a_triangle_toward_the_anchor() {
	outline := popover_arrow_strips(.bottom, 100, 50, 6, 0, 1)
	assert outline.len == 6
	// The tip is the narrowest strip, farthest from the surface.
	assert outline[0].y == 94
	assert outline[0].width < outline[5].width
	assert outline[5].y + outline[5].height == 100
	for strip in outline {
		assert math.abs(strip.x + strip.width / 2 - 50) < 1e-9
		assert strip.width <= 12
	}
	fill := popover_arrow_strips(.bottom, 100, 50, 6, 1, 1)
	// The fill reaches one point into the surface, over its border.
	assert fill.last().y + fill.last().height == 101
	assert fill.last().width < outline.last().width
	above := popover_arrow_strips(.top, 100, 50, 6, 0, 1)
	for strip in above {
		assert strip.y >= 100
	}
	assert above[0].y + above[0].height == 106
	right := popover_arrow_strips(.right, 100, 50, 6, 0, 1)
	for strip in right {
		assert strip.x + strip.width <= 100
		assert math.abs(strip.y + strip.height / 2 - 50) < 1e-9
	}
	left := popover_arrow_strips(.left, 100, 50, 6, 0, 1)
	for strip in left {
		assert strip.x >= 100
	}
	assert popover_arrow_strips(.bottom, 100, 50, 0, 0, 1).len == 0
}

// popover_test_part finds a keyed child, so the tests do not depend on where
// the panel's fill or a divider sits among the children.
fn popover_test_part(el Element, key string) Element {
	for child in el.children {
		if child.key == key {
			return child
		}
	}
	panic('no child keyed `${key}`')
}

fn menu_test_rows(surface Element) []Element {
	return surface.children.filter(it.key.starts_with('row:'))
}

fn popover_test_config() PopoverConfig {
	return PopoverConfig{
		id:       'info'
		open:     true
		anchor:   rect(40, 40, 80, 32)
		window:   rect(0, 0, 600, 400)
		width:    200
		height:   100
		label:    'Details'
		children: [label('body', 'Hello', rect(0, 0, 100, 20), TextStyle{})]
	}
}

fn test_popover_closed_mounts_nothing() {
	el := popover(PopoverConfig{
		...popover_test_config()
		open: false
	}) or { panic(err) }
	assert el.id == 'info'
	assert el.hidden
	assert el.children.len == 0
}

fn test_popover_open_with_backdrop_and_surface() {
	el := popover(popover_test_config()) or { panic(err) }
	assert el.id == 'info'
	assert el.frame == rect(0, 0, 600, 400)
	assert !el.hidden
	assert el.children.len == 2
	backdrop := el.children[0]
	assert backdrop.kind == .button
	assert backdrop.frame == rect(0, 0, 600, 400)
	assert backdrop.box.transparent
	assert backdrop.action_id == popover_dismiss_action('info')
	assert backdrop.accessibility_role == 'presentation'
	chrome := el.children[1]
	assert chrome.frame == rect(40, 76, 200, 100)
	surface := chrome.children[0]
	assert surface.id == 'info:component:surface'
	assert surface.clickable
	assert surface.accessibility_role == 'dialog'
	assert surface.accessibility_label == 'Details'
	assert surface.frame == rect(0, 0, 200, 100)
	// A rounded border: a border-colored panel with the fill inset over it.
	assert surface.box.bg == ComponentTheme{}.border
	assert surface.box.radius == 6
	fill := popover_test_part(surface, 'fill')
	assert fill.frame == rect(1, 1, 198, 98)
	assert fill.box.bg == ComponentTheme{}.background
	assert fill.box.radius == 5
	body := surface.children.last()
	assert body.frame == rect(12, 12, 176, 76)
	assert body.children[0].id == 'body'
}

fn test_popover_dismiss_options() {
	custom := popover(PopoverConfig{
		...popover_test_config()
		dismiss_action: 'close-info'
	}) or { panic(err) }
	assert custom.children[0].action_id == 'close-info'
	modeless := popover(PopoverConfig{
		...popover_test_config()
		close_on_outside_click: false
	}) or { panic(err) }
	assert modeless.id == 'info'
	assert modeless.frame == rect(40, 76, 200, 100)
	assert modeless.children[0].id == 'info:component:surface'
}

fn test_popover_arrow_joins_the_surface() {
	el := popover(PopoverConfig{
		...popover_test_config()
		arrow: true
	}) or { panic(err) }
	chrome := el.children[1]
	// The surface sits one arrow depth further away, and the container reaches
	// up to the arrow tip.
	assert chrome.frame.y == 72 + 4
	assert chrome.frame.height == 106
	mut surface_index := -1
	for index, child in chrome.children {
		if child.id == 'info:component:surface' {
			surface_index = index
		}
	}
	assert surface_index > 0
	assert chrome.children[0].box.bg == ComponentTheme{}.border
	assert chrome.children.last().box.bg == ComponentTheme{}.background
	assert chrome.children[surface_index].frame.y == 6
}

fn test_popover_validation() {
	if _ := popover(PopoverConfig{ open: true }) {
		assert false, 'popover accepted without an id'
	}
	if _ := popover(PopoverConfig{
		...popover_test_config()
		padding: -3
	}) {
		assert false, 'negative padding accepted'
	}
	if _ := popover(PopoverConfig{
		...popover_test_config()
		width: math.nan()
	}) {
		assert false, 'NaN width accepted'
	}
	if _ := popover(PopoverConfig{
		...popover_test_config()
		children: [label('info', 'Clash', rect(0, 0, 10, 10), TextStyle{})]
	}) {
		assert false, 'duplicate identity accepted'
	}
}

fn test_popover_actions_and_escape() {
	assert popover_open_from_action('info', false, popover_toggle_action('info'))? == true
	assert popover_open_from_action('info', true, popover_toggle_action('info'))? == false
	assert popover_open_from_action('info', true, popover_dismiss_action('info'))? == false
	for action in [popover_dismiss_action('info'), 'info', 'info:component:', 'other:component:toggle',
		'info:component:surface', 'pointer:down:info:component:surface:1:2'] {
		if _ := popover_open_from_action('info', false, action) {
			assert false, 'decoded ${action}'
		}
	}
	assert popover_dismiss_key(true, KeyEvent{ code: .escape })
	assert !popover_dismiss_key(false, KeyEvent{ code: .escape })
	assert !popover_dismiss_key(true, KeyEvent{ code: .escape, cmd: true })
	assert !popover_dismiss_key(true, KeyEvent{ code: .enter })
}

fn hover_test_event(phase string, part string) string {
	return 'pointer:${phase}:card:component:${part}:10:20'
}

fn test_hover_card_opens_after_the_open_delay() {
	state := HoverCardState{}
	entered := state.trigger_entered()
	assert entered.schedule
	assert !entered.cancel
	assert entered.delay == 0.6
	assert entered.state.pending == .open
	assert entered.state.trigger_hovered
	assert !entered.state.open
	fired := entered.state.timer_fired(entered.state.generation)
	assert fired.state.open
	assert fired.state.pending == .none
	assert !fired.schedule
	// A stale firing changes nothing.
	stale := fired.state.timer_fired(entered.state.generation - 1)
	assert stale.state == fired.state
}

fn test_hover_card_quick_sweep_never_opens() {
	entered := HoverCardState{}.trigger_entered()
	left := entered.state.trigger_left()
	assert left.cancel
	assert !left.schedule
	assert left.state.pending == .none
	assert !left.state.trigger_hovered
	late := left.state.timer_fired(entered.state.generation)
	assert !late.state.open
}

fn test_hover_card_stays_open_from_trigger_to_card() {
	open := HoverCardState{
		open: true
	}.trigger_entered()
	assert !open.schedule
	left := open.state.trigger_left()
	assert left.schedule
	assert left.delay == 0.3
	assert left.state.pending == .close
	on_card := left.state.card_entered()
	assert on_card.cancel
	assert on_card.state.pending == .none
	assert on_card.state.card_hovered
	// The close that was scheduled is stale now.
	assert on_card.state.timer_fired(left.state.generation).state.open
	off_card := on_card.state.card_left()
	assert off_card.schedule
	assert off_card.state.pending == .close
	back := off_card.state.trigger_entered()
	assert back.cancel
	assert back.state.open
	assert back.state.pending == .none
	gone := back.state.trigger_left()
	closed := gone.state.timer_fired(gone.state.generation)
	assert !closed.state.open
}

fn test_hover_card_card_and_trigger_overlap() {
	// Leaving the trigger while the card is hovered schedules nothing.
	state := HoverCardState{
		open:            true
		trigger_hovered: true
		card_hovered:    true
	}
	step := state.trigger_left()
	assert !step.schedule
	assert step.state.open
	assert !state.card_left().schedule
}

fn test_hover_card_dismiss_tap_and_delays() {
	pending := HoverCardState{
		open: true
	}.card_left()
	dismissed := pending.state.dismissed()
	assert !dismissed.state.open
	assert dismissed.cancel
	assert dismissed.state.pending == .none
	assert !HoverCardState{}.dismissed().cancel
	tapped := HoverCardState{}.tapped()
	assert tapped.state.open
	assert !tapped.schedule
	assert !tapped.state.tapped().state.open
	fast := HoverCardState{
		open_delay:  0.2
		close_delay: math.nan()
	}
	assert fast.trigger_entered().delay == 0.2
	assert HoverCardState{
		...fast
		open: true
	}.trigger_left().delay == 0
	// Every scheduled timer gets a new generation.
	first := HoverCardState{}.trigger_entered()
	second := first.state.trigger_entered()
	assert second.cancel
	assert second.state.generation == first.state.generation + 1
}

fn test_hover_card_step_decodes_pointer_events() {
	state := HoverCardState{}
	entered := hover_card_step('card', state, hover_test_event('enter', 'trigger')) or {
		panic('trigger enter not decoded')
	}
	assert entered.state.trigger_hovered
	left := hover_card_step('card', entered.state, hover_test_event('leave', 'trigger')) or {
		panic('trigger leave not decoded')
	}
	assert !left.state.trigger_hovered
	on_card := hover_card_step('card', HoverCardState{ open: true }, hover_test_event('enter',
		'card')) or { panic('card enter not decoded') }
	assert on_card.state.card_hovered
	for event in [hover_test_event('down', 'trigger'), hover_test_event('enter', 'surface'),
		'pointer:enter:other:component:trigger:1:2', 'card:component:trigger', 'pointer:enter:card:1:2'] {
		if _ := hover_card_step('card', state, event) {
			assert false, 'decoded ${event}'
		}
	}
}

fn test_hover_card_elements() {
	trigger := hover_card_trigger('card', with_action(button('ada', '@ada', rect(30, 40, 60,
		20), BoxStyle{}, TextStyle{}), 'open-profile')) or { panic(err) }
	assert trigger.id == hover_card_trigger_action('card')
	assert trigger.hoverable
	assert trigger.frame == rect(30, 40, 60, 20)
	assert trigger.children[0].frame == rect(0, 0, 60, 20)
	assert trigger.children[0].action_id == 'open-profile'
	config := HoverCardConfig{
		id:     'card'
		anchor: rect(30, 40, 60, 20)
		window: rect(0, 0, 600, 400)
		width:  200
		height: 80
		arrow:  true
	}
	closed := hover_card(config) or { panic(err) }
	assert closed.hidden
	opened := hover_card(HoverCardConfig{
		...config
		state: HoverCardState{
			open: true
		}
	}) or { panic(err) }
	assert !opened.hidden
	assert opened.id == 'card'
	assert opened.hoverable
	assert opened.action_id == hover_card_card_action('card')
	// No backdrop: the card covers only itself and its arrow.
	assert opened.frame.width == 200
	assert opened.frame.y == 40 + 20 + 4
	if _ := hover_card_trigger('', label('', 'x', rect(0, 0, 1, 1), TextStyle{})) {
		assert false, 'trigger accepted without an id'
	}
}

fn menu_test_items() []DropdownMenuItem {
	return [
		dropdown_menu_heading('Clipboard'),
		DropdownMenuItem{
			...dropdown_menu_item('cut', 'Cut')
			icon:     'scissors'
			shortcut: 'cmd+x'
		},
		DropdownMenuItem{
			...dropdown_menu_item('paste', 'Paste')
			enabled: false
		},
		dropdown_menu_separator(),
		dropdown_menu_checkbox('wrap', 'Word wrap', true),
		dropdown_menu_submenu('Sort by', [
			dropdown_menu_radio('name', 'Name', true),
			DropdownMenuItem{
				...dropdown_menu_radio('date', 'Date', false)
				enabled: false
			},
			dropdown_menu_radio('size', 'Size', false),
		]),
		dropdown_menu_separator(),
	]
}

fn menu_open(path []int) DropdownMenuState {
	return DropdownMenuState{
		open: true
		path: path
	}
}

fn test_dropdown_menu_validation() {
	validate_dropdown_menu_items(menu_test_items()) or { panic(err) }
	bad := [
		[dropdown_menu_item('', 'No id')],
		[dropdown_menu_item('a', 'A'), dropdown_menu_item('a', 'Again')],
		[dropdown_menu_item('a', 'A'), dropdown_menu_submenu('More', [
			dropdown_menu_item('a', 'Nested'),
		])],
		[DropdownMenuItem{
			...dropdown_menu_separator()
			label: 'x'
		}],
		[dropdown_menu_submenu('Empty', []DropdownMenuItem{})],
		[dropdown_menu_heading(' ')],
		[dropdown_menu_item('a', ' ')],
		[DropdownMenuItem{
			...dropdown_menu_item('a', 'A')
			height: -1
		}],
	]
	for items in bad {
		if _ := validate_dropdown_menu_items(items) {
			assert false, 'invalid rows accepted: ${items}'
		}
	}
	custom := DropdownMenuItem{
		id:       'custom'
		children: [label('', 'Custom', rect(0, 0, 80, 20), TextStyle{})]
	}
	validate_dropdown_menu_items([custom]) or { panic(err) }
}

fn test_dropdown_menu_navigation_skips_unselectable_rows_and_wraps() {
	items := menu_test_items()
	assert dropdown_menu_first_index(items) == 1
	assert dropdown_menu_last_index(items) == 5
	assert dropdown_menu_next_index(items, 1, true) == 4
	assert dropdown_menu_next_index(items, 4, true) == 5
	assert dropdown_menu_next_index(items, 5, true) == 1
	assert dropdown_menu_next_index(items, 1, false) == 5
	assert dropdown_menu_next_index(items, 99, true) == 1
	assert dropdown_menu_next_index([dropdown_menu_separator(), DropdownMenuItem{
		...dropdown_menu_item('x', 'X')
		enabled: false
	}], -1, true) == -1
	assert dropdown_menu_next_index([]DropdownMenuItem{}, -1, true) == -1
	only := [dropdown_menu_item('x', 'X')]
	assert dropdown_menu_next_index(only, 0, true) == 0
}

fn test_dropdown_menu_update_toggles_dismisses_and_chooses() {
	items := menu_test_items()
	opened := dropdown_menu_update('m', items, DropdownMenuState{}, dropdown_menu_toggle_action('m')) or {
		panic('toggle not decoded')
	}
	assert opened.state.open
	toggled := dropdown_menu_update('m', items, menu_open([1]), dropdown_menu_toggle_action('m')) or {
		panic('toggle not decoded')
	}
	assert !toggled.state.open
	dismissed := dropdown_menu_update('m', items, menu_open([1]), dropdown_menu_dismiss_action('m')) or {
		panic('dismiss not decoded')
	}
	assert !dismissed.state.open
	if _ := dropdown_menu_update('m', items, DropdownMenuState{}, dropdown_menu_dismiss_action('m')) {
		assert false, 'closed menu dismissed'
	}
	chosen := dropdown_menu_update('m', items, menu_open([]), dropdown_menu_item_action('m',
		[1])) or { panic('choice not decoded') }
	assert chosen.chosen
	assert chosen.item.id == 'cut'
	assert chosen.path == [1]
	assert !chosen.state.open
	nested := dropdown_menu_update('m', items, menu_open([5]), dropdown_menu_item_action('m',
		[5, 2])) or { panic('nested choice not decoded') }
	assert nested.item.id == 'size'
	submenu := dropdown_menu_update('m', items, menu_open([]), dropdown_menu_item_action('m',
		[5])) or { panic('submenu tap not decoded') }
	assert !submenu.chosen
	assert submenu.state.path == [5]
}

fn test_dropdown_menu_rejects_forged_and_unchoosable_actions() {
	items := menu_test_items()
	for action in [dropdown_menu_item_action('m', [2]), dropdown_menu_item_action('m', [0]),
		dropdown_menu_item_action('m', [3]), dropdown_menu_item_action('m', [5, 1]),
		dropdown_menu_item_action('m', [7]), dropdown_menu_item_action('m', [1, 0]),
		'm:component:item:01', 'm:component:item:-1', 'm:component:item:', 'm:component:item:1.',
		'm:component:item:99999999999999999999', 'other:component:item:1', 'm:component:menu:0',
		'cut'] {
		if _ := dropdown_menu_update('m', items, menu_open([]), action) {
			assert false, 'accepted ${action}'
		}
		if _ := dropdown_menu_item_from_action('m', items, action) {
			assert false, 'decoded ${action}'
		}
	}
	if _ := dropdown_menu_update('m', items, DropdownMenuState{}, dropdown_menu_item_action('m',
		[1])) {
		assert false, 'closed menu chose a row'
	}
	assert dropdown_menu_item_from_action('m', items, dropdown_menu_item_action('m', [4]))?.id == 'wrap'
}

fn menu_pointer(phase string, path []int) string {
	return 'pointer:${phase}:${dropdown_menu_item_action('m', path)}:5:5'
}

fn test_dropdown_menu_hover_moves_the_highlight() {
	items := menu_test_items()
	entered := dropdown_menu_update('m', items, menu_open([]), menu_pointer('enter', [1])) or {
		panic('enter not decoded')
	}
	assert entered.state.path == [1]
	if _ := dropdown_menu_update('m', items, entered.state, menu_pointer('enter', [1])) {
		assert false, 'unchanged highlight reported'
	}
	left := dropdown_menu_update('m', items, entered.state, menu_pointer('leave', [1])) or {
		panic('leave not decoded')
	}
	assert left.state.path == []int{}
	// A key moved the highlight away: leaving the old row keeps it.
	if _ := dropdown_menu_update('m', items, menu_open([4]), menu_pointer('leave', [1])) {
		assert false, 'leave cleared a keyboard highlight'
	}
	disabled := dropdown_menu_update('m', items, menu_open([5, 0]), menu_pointer('enter', [2])) or {
		panic('enter not decoded')
	}
	assert disabled.state.path == []int{}
	submenu := dropdown_menu_update('m', items, menu_open([1]), menu_pointer('enter', [5])) or {
		panic('enter not decoded')
	}
	assert submenu.state.path == [5]
	if _ := dropdown_menu_update('m', items, submenu.state, menu_pointer('leave', [5])) {
		assert false, 'leaving a submenu row closed its submenu'
	}
	inner := dropdown_menu_update('m', items, submenu.state, menu_pointer('enter', [5, 2])) or {
		panic('enter not decoded')
	}
	assert inner.state.path == [5, 2]
	out := dropdown_menu_update('m', items, inner.state, menu_pointer('leave', [5, 2])) or {
		panic('leave not decoded')
	}
	assert out.state.path == [5]
	if _ := dropdown_menu_update('m', items, menu_open([]), 'pointer:down:m:component:menu:0:1:2') {
		assert false, 'surface press decoded'
	}
}

fn menu_key(items []DropdownMenuItem, path []int, code KeyCode) ?DropdownMenuStep {
	return dropdown_menu_key(items, menu_open(path), KeyEvent{ code: code })
}

fn test_dropdown_menu_keyboard() {
	items := menu_test_items()
	assert menu_key(items, [], .down)?.state.path == [1]
	assert menu_key(items, [], .up)?.state.path == [5]
	assert menu_key(items, [1], .down)?.state.path == [4]
	assert menu_key(items, [5], .down)?.state.path == [1]
	assert menu_key(items, [4], .home)?.state.path == [1]
	assert menu_key(items, [1], .end)?.state.path == [5]
	assert menu_key(items, [5], .right)?.state.path == [5, 0]
	assert menu_key(items, [5, 0], .down)?.state.path == [5, 2]
	assert menu_key(items, [5, 2], .down)?.state.path == [5, 0]
	assert menu_key(items, [5, 2], .left)?.state.path == [5]
	assert menu_key(items, [5], .enter)?.state.path == [5, 0]
	chosen := menu_key(items, [5, 2], .enter)?
	assert chosen.chosen
	assert chosen.item.id == 'size'
	assert chosen.path == [5, 2]
	assert !chosen.state.open
	assert menu_key(items, [4], .space)?.item.id == 'wrap'
	assert !menu_key(items, [4], .escape)?.state.open
	assert !menu_key(items, [], .tab)?.state.open
	for path, code in {
		'[]':  KeyCode.enter
		'[1]': KeyCode.right
		'[0]': KeyCode.left
		'[4]': KeyCode.a
	} {
		state_path := if path == '[]' {
			[]int{}
		} else {
			[path[1..path.len - 1].int()]
		}
		if _ := menu_key(items, state_path, code) {
			assert false, 'key ${code} at ${path} handled'
		}
	}
	if _ := dropdown_menu_key(items, DropdownMenuState{}, KeyEvent{ code: .down }) {
		assert false, 'closed menu moved'
	}
	if _ := dropdown_menu_key(items, menu_open([1]), KeyEvent{ code: .down, cmd: true }) {
		assert false, 'shortcut handled as navigation'
	}
}

fn menu_test_config(path []int) DropdownMenuConfig {
	return DropdownMenuConfig{
		id:     'm'
		state:  menu_open(path)
		items:  menu_test_items()
		anchor: rect(40, 40, 100, 32)
		window: rect(0, 0, 800, 600)
		label:  'Edit'
	}
}

fn test_dropdown_menu_element() {
	closed := dropdown_menu(DropdownMenuConfig{
		...menu_test_config([])
		state: DropdownMenuState{}
	}) or { panic(err) }
	assert closed.hidden
	el := dropdown_menu(menu_test_config([1])) or { panic(err) }
	assert el.frame == rect(0, 0, 800, 600)
	assert el.children.len == 2
	assert el.children[0].action_id == dropdown_menu_dismiss_action('m')
	surface := el.children[1]
	assert surface.accessibility_role == 'menu'
	assert surface.accessibility_label == 'Edit'
	assert surface.clickable
	assert surface.frame.x == 40
	assert surface.frame.y == 76
	assert surface.frame.width >= 128
	assert surface.box.bg == ComponentTheme{}.border
	assert popover_test_part(surface, 'fill').box.bg == ComponentTheme{}.background
	rows := menu_test_rows(surface)
	// The trailing separator is not drawn.
	assert rows.len == 6
	heading := rows[0]
	assert heading.accessibility_role == 'text'
	assert heading.hoverable
	cut := rows[1]
	assert cut.id == dropdown_menu_item_action('m', [1])
	assert cut.button_behavior
	assert cut.hoverable
	assert cut.accessibility_role == 'menuitem'
	assert cut.box.bg == ComponentTheme{}.muted
	assert !cut.box.transparent
	assert cut.children.any(it.image_path == 'symbol:scissors')
	assert cut.children.any(it.text == menu_shortcut_label('cmd+x'))
	paste := rows[2]
	assert !paste.enabled
	assert paste.box.transparent
	assert rows[3].accessibility_role == 'separator'
	wrap := rows[4]
	assert wrap.accessibility_role == 'menuitemcheckbox'
	assert wrap.accessibility_value == 'checked'
	assert wrap.children.any(it.text == '✓')
	sort := rows[5]
	assert sort.accessibility_value == 'collapsed'
	assert sort.children.any(it.text == '›')
	assert rows.all(it.frame.height > 0)
}

fn test_dropdown_menu_opens_submenus_beside_their_row() {
	el := dropdown_menu(menu_test_config([5, 2])) or { panic(err) }
	assert el.children.len == 3
	parent := el.children[1]
	sub := el.children[2]
	parent_rows := menu_test_rows(parent)
	sub_rows := menu_test_rows(sub)
	assert parent_rows[5].accessibility_value == 'expanded'
	assert sub.id == 'm:component:menu:1'
	assert sub.accessibility_label == 'Sort by'
	assert sub.frame.x == parent.frame.x + parent.frame.width + 2
	// Its first row lines up with the row that opened it.
	assert sub.frame.y + sub_rows[0].frame.y == parent.frame.y + parent_rows[5].frame.y
	assert sub_rows[0].accessibility_role == 'menuitemradio'
	assert sub_rows[0].children.any(it.text == '●')
	assert sub_rows[2].box.bg == ComponentTheme{}.muted
	// Near the right edge the submenu flips to the left of its menu.
	flipped := dropdown_menu(DropdownMenuConfig{
		...menu_test_config([5])
		anchor: rect(640, 40, 100, 32)
	}) or { panic(err) }
	assert flipped.children[2].frame.x + flipped.children[2].frame.width < flipped.children[1].frame.x
	// A stale path opens nothing further.
	stale := dropdown_menu(menu_test_config([1, 3])) or { panic(err) }
	assert stale.children.len == 2
}

fn test_dropdown_menu_scrolls_and_sizes() {
	mut many := []DropdownMenuItem{}
	for i in 0 .. 60 {
		many << dropdown_menu_item('row${i}', 'Row ${i}')
	}
	el := dropdown_menu(DropdownMenuConfig{
		...menu_test_config([])
		items: many
	}) or { panic(err) }
	surface := el.children[1]
	assert surface.frame.height == 600 - 16
	assert surface.children.len == 2
	assert surface.children[1].kind == .scroll
	assert surface.children[1].children.len == 60
	bounded := dropdown_menu(DropdownMenuConfig{
		...menu_test_config([])
		items:      many
		max_height: 200
	}) or { panic(err) }
	assert bounded.children[1].frame.height == 200
	short_width, short_height := dropdown_menu_size([dropdown_menu_item('a', 'A')], .medium)
	long_width, _ := dropdown_menu_size([dropdown_menu_item('a', 'A much longer label')], .medium)
	assert long_width > short_width
	assert short_height == 28 + 8
	fixed := dropdown_menu(DropdownMenuConfig{
		...menu_test_config([])
		width: 300
	}) or { panic(err) }
	assert fixed.children[1].frame.width == 300
	if _ := dropdown_menu(DropdownMenuConfig{
		...menu_test_config([])
		max_height: -1
	}) {
		assert false, 'negative max height accepted'
	}
	if _ := dropdown_menu(DropdownMenuConfig{
		...menu_test_config([])
		items: [dropdown_menu_item('', 'x')]
	}) {
		assert false, 'invalid rows accepted'
	}
}

fn test_dropdown_menu_converts_menu_bar_rows_and_entries() {
	rows := dropdown_menu_items_from_menu([
		menu_item_with_shortcut('new', 'New', 'cmd+n'),
		menu_separator(),
		menu_check_item('ruler', 'Ruler', true),
		disabled(menu_item('revert', 'Revert')),
		submenu('Export', [menu_item('pdf', 'PDF')]),
	])
	assert rows.len == 5
	assert rows[0].id == 'new' && rows[0].label == 'New' && rows[0].shortcut == 'cmd+n'
	assert rows[1].kind == .separator
	assert rows[2].kind == .checkbox && rows[2].checked
	assert !rows[3].enabled
	assert rows[4].kind == .submenu && rows[4].items[0].id == 'pdf'
	validate_dropdown_menu_items(rows) or { panic(err) }
	entries := dropdown_menu_items_from_entries([MenuEntry{
		id:    'copy'
		title: 'Copy'
	}])
	assert entries[0].id == 'copy' && entries[0].label == 'Copy' && entries[0].kind == .item
	assert dropdown_menu_shortcut_text('not a shortcut++x') != ''
	assert dropdown_menu_shortcut_text('') == ''
	// Modifier symbols count as an em, so a hint like ⇧⌘S gets room on AppKit.
	assert dropdown_menu_hint_width('⇧⌘S', 10) == 27
	assert dropdown_menu_hint_width('Ctrl+Shift+S', 10) > dropdown_menu_hint_width('⇧⌘S', 10)
}

fn test_dropdown_button_opens_its_menu() {
	el := dropdown_button(
		id:      'edit'
		menu_id: 'm'
		label:   'Edit'
		frame:   rect(10, 10, 100, 32)
	) or { panic(err) }
	assert el.button_behavior
	assert el.action_id == dropdown_menu_toggle_action('m')
	assert el.accessibility_value == 'collapsed'
	chevron := el.children.filter(it.key == 'chevron')
	assert chevron.len == 1
	// A downward caret: strips listed from the tip, which is the lowest and
	// narrowest one, up to the base.
	strips := chevron[0].children
	assert strips.len > 2
	assert strips[0].frame.width < strips.last().frame.width
	assert strips[0].frame.y > strips.last().frame.y
	caption := el.children.filter(it.kind == .label)
	assert caption.len == 1 && caption[0].text == 'Edit'
	assert strips.all(it.box.bg == caption[0].text_style.color)
	opened := dropdown_button(
		id:      'edit'
		menu_id: 'm'
		label:   'Edit'
		frame:   rect(10, 10, 100, 32)
		open:    true
	) or { panic(err) }
	assert opened.accessibility_value == 'expanded'
	assert popover_test_part(opened, 'fill').box.bg != popover_test_part(el, 'fill').box.bg
	step := dropdown_menu_update('m', menu_test_items(), DropdownMenuState{}, el.action_id) or {
		panic('button action not handled')
	}
	assert step.state.open
	if _ := dropdown_button(id: 'edit', label: 'Edit') {
		assert false, 'dropdown button accepted without a menu'
	}
}

fn test_split_dropdown_button() {
	el := dropdown_button(
		id:      'save'
		menu_id: 'save-menu'
		label:   'Save'
		icon:    'square.and.arrow.down'
		frame:   rect(0, 0, 120, 32)
		split:   true
		tone:    .primary
	) or { panic(err) }
	assert el.accessibility_role == 'group'
	// A filled button needs no separate border, so it has no inset fill.
	assert el.box.bg == ComponentTheme{}.primary
	assert !el.children.any(it.key == 'fill')
	main := popover_test_part(el, 'action')
	trigger := popover_test_part(el, 'trigger')
	assert main.action_id == dropdown_button_action('save')
	assert main.children.any(it.image_path == 'symbol:square.and.arrow.down')
	assert trigger.action_id == dropdown_menu_toggle_action('save-menu')
	assert trigger.accessibility_label == 'More options'
	assert trigger.frame.x + trigger.frame.width == 120
	assert main.frame.width + trigger.frame.width == 120
	custom := dropdown_button(
		id:         'save'
		menu_id:    'save-menu'
		label:      'Save'
		frame:      rect(0, 0, 120, 32)
		split:      true
		action_id:  'save-now'
		menu_label: 'More save options'
		enabled:    false
	) or { panic(err) }
	assert popover_test_part(custom, 'action').action_id == 'save-now'
	assert !popover_test_part(custom, 'action').enabled
	assert popover_test_part(custom, 'trigger').accessibility_label == 'More save options'
	assert popover_test_part(custom, 'fill').box.bg == ComponentTheme{}.muted
	assert dropdown_button_width('Save', '', true, .medium) > dropdown_button_width('Save',
		'', false, .medium)
	assert dropdown_button_width('Save as', 'plus', false, .medium) > dropdown_button_width('Save',
		'', false, .medium)
}

fn test_popover_blend() {
	assert popover_blend(0x000000, 0xffffff, 0) == 0x000000
	assert popover_blend(0x000000, 0xffffff, 1) == 0xffffff
	assert popover_blend(0x000000, 0xfefefe, 0.5) == 0x7f7f7f
	assert popover_blend(0x102030, 0x102030, 0.3) == 0x102030
}
