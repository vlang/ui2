// SPDX-License-Identifier: Apache-2.0
// Includes fixed-panel sizing cases adapted from GPUI Kit's resizable tests
// (crates/base/src/resizable/mod.rs; Longbridge, copyright 2024 - 2026); the
// other tests are new. See third_party/gpui-kit.
module ui2

import math

fn panels_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := panels_find(child, id) {
			return found
		}
	}
	return none
}

fn panels_find_key(el Element, key string) ?Element {
	if el.key == key {
		return el
	}
	for child in el.children {
		if found := panels_find_key(child, key) {
			return found
		}
	}
	return none
}

fn panels_close(a f64, b f64) bool {
	return math.abs(a - b) < 1e-6
}

fn panels_sizes_close(a []f64, b []f64) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		if !panels_close(a[i], b[i]) {
			return false
		}
	}
	return true
}

fn panels_pointer(phase string, id string, part string, x f64, y f64) string {
	return 'pointer:${phase}:${component_part_id(id, part)}:${x}:${y}'
}

// ── Resize handle ───────────────────────────────────────────────────

fn test_resize_handle_frame_places_the_band_against_the_line() {
	assert resize_handle_frame(.horizontal, 100, 0, 50, .straddle) == rect(96, 0, 9, 50)
	assert resize_handle_frame(.horizontal, 100, 0, 50, .leading) == rect(100, 0, 5, 50)
	assert resize_handle_frame(.horizontal, 100, 0, 50, .trailing) == rect(96, 0, 5, 50)
	assert resize_handle_frame(.vertical, 40, 10, 300, .straddle) == rect(10, 36, 300, 9)
}

fn test_resize_handle_indicator_grows_with_engagement() {
	idle, idle_opacity := resize_handle_indicator(.idle)
	hovered, hovered_opacity := resize_handle_indicator(.hovered)
	pressed, pressed_opacity := resize_handle_indicator(.pressed)
	dragging, dragging_opacity := resize_handle_indicator(.dragging)
	assert idle == 0 && idle_opacity == 0
	assert hovered < pressed && pressed < dragging
	assert hovered_opacity < pressed_opacity && pressed_opacity < dragging_opacity
	assert dragging == 44 && dragging_opacity == 0.9
}

fn test_resize_handle_draws_line_cursor_and_indicator() {
	theme := component_theme(false)
	idle := resize_handle(id: 'edge', frame: rect(96, 0, 9, 200), theme: theme) or { panic(err) }
	assert idle.draggable && idle.hoverable && idle.enabled
	assert idle.cursor == cursor_resize_ew
	assert idle.accessibility_role == 'separator'
	line := panels_find_key(idle, 'line')?
	assert line.frame == rect(4, 0, 1, 200)
	assert line.box.bg == theme.border
	assert panels_find_key(idle, 'indicator') == none
	dragging := resize_handle(
		id:    'edge'
		frame: rect(0, 96, 300, 9)
		axis:  .vertical
		phase: .dragging
		theme: theme
	) or { panic(err) }
	assert dragging.cursor == cursor_resize_ns
	pill := panels_find_key(dragging, 'indicator')?
	assert pill.frame == rect(128, 3, 44, 3)
	assert pill.box.opacity == 0.9
	assert pill.box.bg == theme.muted_foreground
	focused := resize_handle(
		id:            'edge'
		frame:         rect(0, 0, 9, 200)
		focus_visible: true
		theme:         theme
	) or {
		panic(err)
	}
	assert panels_find_key(focused, 'indicator')?.box.bg == theme.primary
	disabled := resize_handle(
		id:      'edge'
		frame:   rect(0, 0, 9, 200)
		phase:   .dragging
		enabled: false
	) or { panic(err) }
	assert !disabled.enabled && !disabled.hoverable && disabled.cursor == cursor_default
	assert panels_find_key(disabled, 'indicator') == none
	if _ := resize_handle(frame: rect(0, 0, 9, 9)) {
		assert false, 'a handle without an id was accepted'
	}
	if _ := resize_handle(id: 'edge', frame: rect(0, 0, -9, 9)) {
		assert false, 'a negative frame was accepted'
	}
}

// ── Resizable sizing rules ──────────────────────────────────────────

fn panels_three(width f64, fixed bool, sizes []f64) ResizablePanelsConfig {
	return ResizablePanelsConfig{
		id:     'row'
		frame:  rect(0, 0, width + 2, 100)
		panels: [
			ResizablePanel{
				key:      'sidebar'
				size:     240
				max_size: 480
				fixed:    fixed
			},
			ResizablePanel{
				key:  'main'
				size: 400
			},
			ResizablePanel{
				key: 'aside'
			},
		]
		state:  ResizableState{
			sizes: sizes
		}
	}
}

fn test_resizable_layout_starts_from_the_panels_sizes() {
	layout := resizable_panels_layout(panels_three(840, true, [])) or { panic(err) }
	assert panels_sizes_close(layout.sizes, [240.0, 400, 200])
	assert layout.frames == [rect(0, 0, 240, 100), rect(241, 0, 400, 100), rect(642, 0, 200, 100)]
	assert layout.handles.len == 2
	assert layout.handles[0].panel == 0 && layout.handles[0].next == 1
	assert layout.handles[0].line == 240
	assert layout.handles[0].frame == rect(236, 0, 9, 100)
	assert layout.handles[1].line == 641
}

fn test_resizable_fixed_panel_keeps_its_size_when_the_container_resizes() {
	start := [240.0, 400, 200]
	wide := resizable_panels_layout(panels_three(1140, true, start)) or { panic(err) }
	assert panels_sizes_close(wide.sizes, [240.0, 600, 300])
	narrow := resizable_panels_layout(panels_three(600, true, start)) or { panic(err) }
	assert panels_sizes_close(narrow.sizes, [240.0, 240, 120])
	// A container briefly too small for everything still fits the panels into
	// it, and the stored sizes bring the proportions back when it grows.
	tiny := resizable_panels_layout(panels_three(200, true, start)) or { panic(err) }
	mut total := 0.0
	for size in tiny.sizes {
		total += size
	}
	assert panels_close(total, 200)
	again := resizable_panels_layout(panels_three(600, true, start)) or { panic(err) }
	assert panels_sizes_close(again.sizes, [240.0, 240, 120])
	// Without fixed, every panel shares the difference.
	shared := resizable_panels_layout(panels_three(1680, false, start)) or { panic(err) }
	assert panels_sizes_close(shared.sizes, [480.0, 800, 400])
}

fn test_resizable_fit_respects_ranges_and_fills_the_container() {
	slots := [
		ResizableSlot{
			min:     50
			max:     100
			visible: true
		},
		ResizableSlot{
			min:     50
			max:     math.max_f64
			visible: true
		},
	]
	collapsed := []bool{len: 2}
	assert panels_sizes_close(resizable_fit_sizes(slots, [80.0, 80], collapsed, 300), [
		100.0,
		200,
	])
	// Everything at its maximum: the last resort still covers the container.
	capped := [
		ResizableSlot{
			min:     10
			max:     100
			visible: true
		},
		ResizableSlot{
			min:     10
			max:     100
			visible: true
		},
	]
	grown := resizable_fit_sizes(capped, [100.0, 100], collapsed, 300)
	assert panels_close(grown[0] + grown[1], 300)
	// Zero-sized panels share evenly.
	assert panels_sizes_close(resizable_fit_sizes(slots, [0.0, 0], collapsed, 100), [
		50.0,
		50,
	])
}

fn test_resizable_drag_takes_from_the_far_side_and_skips_fixed_panels() {
	config := panels_three(600, true, [240.0, 240, 120])
	slots := resizable_slots(config)
	order := [0, 1, 2]
	collapsed := []bool{len: 3}
	// Dragging the main panel below its minimum takes the rest from the panel
	// after it, not from the fixed sidebar before it.
	sizes, _ := resizable_drag_sizes(slots, [240.0, 240, 120], collapsed, order, 1, -190,
		true)
	assert panels_sizes_close(sizes, [240.0, 100, 260])
	// Its own handle still resizes the fixed sidebar.
	grown, _ := resizable_drag_sizes(slots, sizes, collapsed, order, 0, 60, true)
	assert panels_sizes_close(grown, [300.0, 100, 200])
	// The panels after the handle give way down to their minimums, nearest
	// first; the sidebar would stop at its maximum of 480.
	capped, _ := resizable_drag_sizes(slots, [240.0, 240, 120], collapsed, order, 0, 900,
		true)
	assert panels_sizes_close(capped, [400.0, 100, 100])
	roomy, _ := resizable_drag_sizes(slots, [240.0, 600, 120], collapsed, order, 0, 900,
		true)
	assert panels_sizes_close(roomy, [480.0, 360, 120])
	// Nothing moves for a zero, a non-finite delta or a handle out of range.
	same, _ := resizable_drag_sizes(slots, [240.0, 240, 120], collapsed, order, 0, math.nan(),
		true)
	assert same == [240.0, 240, 120]
	outside, _ := resizable_drag_sizes(slots, [240.0, 240, 120], collapsed, order, 2, 10,
		true)
	assert outside == [240.0, 240, 120]
}

fn test_resizable_drag_moves_a_locked_panel_along_whole() {
	slots := [
		ResizableSlot{
			min:     10
			max:     math.max_f64
			visible: true
		},
		ResizableSlot{
			min:     10
			max:     math.max_f64
			locked:  true
			visible: true
		},
		ResizableSlot{
			min:     10
			max:     math.max_f64
			visible: true
		},
	]
	sizes, _ := resizable_drag_sizes(slots, [100.0, 100, 100], []bool{len: 3}, [0, 1, 2],
		0, 30, true)
	assert panels_sizes_close(sizes, [130.0, 100, 70])
}

// ── Resizable events ────────────────────────────────────────────────

fn panels_sidebar(sizes []f64, collapsed []bool, drag ResizableDrag) ResizablePanelsConfig {
	return ResizablePanelsConfig{
		id:     'split'
		frame:  rect(0, 0, 801, 300)
		panels: [
			ResizablePanel{
				key:         'sidebar'
				label:       'Sidebar'
				size:        230
				min_size:    160
				collapsible: true
			},
			ResizablePanel{
				key: 'main'
			},
		]
		state:  ResizableState{
			sizes:     sizes
			collapsed: collapsed
			drag:      drag
			focused:   0
		}
	}
}

fn test_resizable_event_hover_press_drag_and_release() {
	config := panels_sidebar([], [], ResizableDrag{})
	enter := resizable_panels_event(config, panels_pointer('enter', 'split', 'handle:0',
		230, 10))?
	assert enter.kind == .hover && enter.state.hovered == 0
	hovered := ResizablePanelsConfig{
		...config
		state: enter.state
	}
	assert resizable_panels_event(hovered, panels_pointer('enter', 'split', 'handle:0',
		230, 10)) == none
	leave := resizable_panels_event(hovered, panels_pointer('leave', 'split', 'handle:0',
		230, 10))?
	assert leave.state.hovered == -1
	down := resizable_panels_event(config, panels_pointer('down', 'split', 'handle:0', 230,
		10))?
	assert down.kind == .resize_start && down.handle == 0
	assert down.state.drag.active() && !down.state.drag.moved
	assert down.state.drag.start == 230
	assert panels_sizes_close(down.state.drag.sizes, [230.0, 570])
	assert down.state.focused == 0 && !down.state.focus_visible
	pressed := ResizablePanelsConfig{
		...config
		state: down.state
	}
	moved := resizable_panels_event(pressed, panels_pointer('drag', 'split', 'handle:0',
		280, 40))?
	assert moved.kind == .resize && moved.state.drag.moved
	assert panels_sizes_close(moved.state.sizes, [280.0, 520])
	dragging := ResizablePanelsConfig{
		...config
		state: moved.state
	}
	assert resizable_panels_event(dragging, panels_pointer('drag', 'split', 'handle:0',
		280, 90)) == none
	up := resizable_panels_event(dragging, panels_pointer('up', 'split', 'handle:0', 300,
		40))?
	assert up.kind == .resize_end && !up.state.drag.active()
	assert panels_sizes_close(up.state.sizes, [300.0, 500])
	// The handle shows the phase the state is in.
	el := resizable_panels(dragging) or { panic(err) }
	handle := panels_find(el, resizable_handle_action('split', 0))?
	assert panels_find_key(handle, 'indicator')?.frame.height == 44
}

fn test_resizable_event_rejects_foreign_and_forged_events() {
	config := panels_sidebar([], [], ResizableDrag{})
	assert resizable_panels_event(config, 'split') == none
	assert resizable_panels_event(config, panels_pointer('down', 'other', 'handle:0', 1, 1)) == none
	// The last panel has no handle, and indexes are bounded and canonical.
	assert resizable_panels_event(config, panels_pointer('down', 'split', 'handle:1', 1, 1)) == none
	assert resizable_panels_event(config, panels_pointer('down', 'split', 'handle:9', 1, 1)) == none
	assert resizable_panels_event(config, panels_pointer('down', 'split', 'handle:00', 1,
		1)) == none
	assert resizable_panels_event(config, panels_pointer('down', 'split', 'panel:0', 1, 1)) == none
	// A drag without a press is ignored.
	assert resizable_panels_event(config, panels_pointer('drag', 'split', 'handle:0', 1, 1)) == none
	disabled := ResizablePanelsConfig{
		...config
		enabled: false
	}
	assert resizable_panels_event(disabled, panels_pointer('down', 'split', 'handle:0', 1,
		1)) == none
}

fn test_resizable_drag_collapses_and_expands_a_collapsible_panel() {
	start := panels_sidebar([], [], ResizableDrag{})
	down := resizable_panels_event(start, panels_pointer('down', 'split', 'handle:0', 230,
		0))?
	pressed := panels_sidebar(down.state.sizes, down.state.collapsed, down.state.drag)
	// Past the minimum but not half of it beyond: the sidebar stops at 160.
	held := resizable_panels_event(pressed, panels_pointer('drag', 'split', 'handle:0', 130,
		0))?
	assert panels_sizes_close(held.state.sizes, [160.0, 640])
	assert !held.state.collapsed[0]
	// Past half the minimum: it collapses and remembers the size it had.
	gone := resizable_panels_event(pressed, panels_pointer('drag', 'split', 'handle:0', 79,
		0))?
	assert gone.kind == .collapse && gone.panel == 0
	assert gone.state.collapsed == [true, false]
	assert panels_sizes_close(gone.state.sizes, [230.0, 800])
	collapsed := panels_sidebar(gone.state.sizes, gone.state.collapsed, ResizableDrag{})
	layout := resizable_panels_layout(collapsed) or { panic(err) }
	assert panels_sizes_close(layout.sizes, [0.0, 800])
	el := resizable_panels(collapsed) or { panic(err) }
	panel := panels_find_key(el, 'panel:sidebar')?
	assert panel.hidden && panel.accessibility_value == 'collapsed'
	// Dragging back far enough expands it to at least its minimum.
	down2 := resizable_panels_event(collapsed, panels_pointer('down', 'split', 'handle:0',
		0, 0))?
	pulling := panels_sidebar(down2.state.sizes, down2.state.collapsed, down2.state.drag)
	// Not far enough yet: the drag only starts.
	nudged := resizable_panels_event(pulling, panels_pointer('drag', 'split', 'handle:0',
		60, 0))?
	assert nudged.state.collapsed == [true, false] && nudged.state.drag.moved
	assert panels_sizes_close(nudged.state.sizes, [230.0, 800])
	open := resizable_panels_event(pulling, panels_pointer('drag', 'split', 'handle:0', 100,
		0))?
	assert open.kind == .expand && open.state.collapsed == [false, false]
	assert panels_sizes_close(open.state.sizes, [160.0, 640])
}

fn test_resizable_toggle_collapses_and_restores() {
	config := panels_sidebar([], [], ResizableDrag{})
	collapsed := resizable_panels_toggle(config, 0)?
	assert collapsed.collapsed == [true, false]
	assert panels_sizes_close(collapsed.sizes, [230.0, 800])
	restored := resizable_panels_toggle(panels_sidebar(collapsed.sizes, collapsed.collapsed,
		ResizableDrag{}), 0)?
	assert restored.collapsed == [false, false]
	assert panels_sizes_close(restored.sizes, [230.0, 570])
	assert resizable_panels_toggle(config, 1) == none
	assert resizable_panels_toggle(config, 5) == none
}

fn test_resizable_keys_move_the_focused_handle() {
	config := panels_sidebar([], [], ResizableDrag{})
	right := resizable_panels_key(config, KeyEvent{ code: .right })?
	assert right.kind == .resize && right.state.focus_visible
	assert panels_sizes_close(right.state.sizes, [240.0, 560])
	shifted := resizable_panels_key(config, KeyEvent{ code: .right, shift: true })?
	assert panels_sizes_close(shifted.state.sizes, [280.0, 520])
	home := resizable_panels_key(config, KeyEvent{ code: .home })?
	assert panels_sizes_close(home.state.sizes, [160.0, 640])
	assert !home.state.collapsed[0]
	end := resizable_panels_key(config, KeyEvent{ code: .end })?
	assert panels_sizes_close(end.state.sizes, [700.0, 100])
	enter := resizable_panels_key(config, KeyEvent{ code: .enter })?
	assert enter.kind == .collapse && enter.panel == 0 && enter.state.collapsed[0]
	escape := resizable_panels_key(config, KeyEvent{ code: .escape })?
	assert escape.kind == .focus && escape.state.focused == -1
	// Keys across the axis, with a command modifier, or without focus do nothing.
	assert resizable_panels_key(config, KeyEvent{ code: .up }) == none
	assert resizable_panels_key(config, KeyEvent{ code: .right, cmd: true }) == none
	unfocused := ResizablePanelsConfig{
		...config
		state: ResizableState{}
	}
	assert resizable_panels_key(unfocused, KeyEvent{ code: .right }) == none
	// At the limit with the focus already showing, Home changes nothing.
	at_min := panels_sidebar(home.state.sizes, home.state.collapsed, ResizableDrag{})
	limited := ResizablePanelsConfig{
		...at_min
		state: ResizableState{
			...at_min.state
			focus_visible: true
		}
	}
	assert resizable_panels_key(limited, KeyEvent{ code: .home }) == none
}

fn test_resizable_hidden_panels_take_no_space_and_keep_their_size() {
	config := ResizablePanelsConfig{
		...panels_three(840, true, [240.0, 400, 200])
		panels: [
			ResizablePanel{
				key:     'sidebar'
				size:    240
				visible: false
			},
			ResizablePanel{
				key:  'main'
				size: 400
			},
			ResizablePanel{
				key: 'aside'
			},
		]
	}
	layout := resizable_panels_layout(config) or { panic(err) }
	assert layout.order == [1, 2]
	assert layout.sizes[0] == 0
	assert panels_close(layout.sizes[1] + layout.sizes[2], 841)
	assert layout.handles.len == 1 && layout.handles[0].panel == 1
	down := resizable_panels_event(config, panels_pointer('down', 'row', 'handle:1', 500,
		0))?
	assert down.state.sizes[0] == 240
	assert resizable_panels_event(config, panels_pointer('down', 'row', 'handle:0', 500,
		0)) == none
	el := resizable_panels(config) or { panic(err) }
	assert panels_find_key(el, 'panel:sidebar') == none
}

fn test_resizable_panels_build_content_and_nest_groups() {
	config := ResizablePanelsConfig{
		id:     'outer'
		frame:  rect(10, 20, 601, 400)
		panels: [
			ResizablePanel{
				key:      'left'
				label:    'Left'
				size:     200
				children: [label('', 'static', rect(0, 0, 100, 20), TextStyle{})]
			},
			ResizablePanel{
				key:   'right'
				build: fn (frame Rect) Element {
					return resizable_panels(ResizablePanelsConfig{
						id:     'inner'
						frame:  frame
						axis:   .vertical
						panels: [
							ResizablePanel{
								key:  'top'
								size: 150
							},
							ResizablePanel{
								key: 'bottom'
							},
						]
					}) or { view('', frame, BoxStyle{}, []Element{}) }
				}
			},
		]
	}
	el := resizable_panels(config) or { panic(err) }
	assert el.id == 'outer' && el.frame == config.frame
	assert el.children.len == 3
	assert el.children[0].key == 'panel:left' && el.children[0].children[0].text == 'static'
	assert el.children[0].accessibility_label == 'Left'
	right := el.children[1]
	assert right.frame == rect(201, 0, 400, 400)
	inner := right.children[0]
	assert inner.id == 'inner' && inner.frame == rect(0, 0, 400, 400)
	inner_handle := panels_find(inner, resizable_handle_action('inner', 0))?
	assert inner_handle.cursor == cursor_resize_ns
	assert inner_handle.frame == rect(0, 146, 400, 9)
	handle := el.children[2]
	assert handle.key == 'handle:left' && handle.accessibility_label == 'Resize Left'
	assert handle.accessibility_value == '200'
	validate_element_tree(el) or { panic(err) }
}

fn test_resizable_panels_validate_their_config() {
	base := panels_three(840, false, [])
	for panels in [
		[ResizablePanel{
			key: ''
		}],
		[ResizablePanel{
			key: 'a'
		}, ResizablePanel{
			key: 'a'
		}],
		[ResizablePanel{
			key:  'a'
			size: -1
		}],
		[ResizablePanel{
			key:      'a'
			min_size: math.nan()
		}],
	] {
		if _ := resizable_panels(ResizablePanelsConfig{ ...base, panels: panels }) {
			assert false, 'invalid panels accepted'
		}
	}
	if _ := resizable_panels(ResizablePanelsConfig{ ...base, id: '' }) {
		assert false, 'missing id accepted'
	}
	if _ := resizable_panels(ResizablePanelsConfig{ ...base, step: 0 }) {
		assert false, 'zero step accepted'
	}
	if _ := resizable_panels(ResizablePanelsConfig{
		...base
		state: ResizableState{
			sizes: [1.0, math.inf(1), 2]
		}
	})
	{
		assert false, 'infinite size accepted'
	}
}

// ── Dock layouts ────────────────────────────────────────────────────

fn panels_layout() DockLayout {
	return DockLayout{
		version: 2
		center:  DockRegion{
			groups: [DockGroup{
				panels: ['a.v', 'b.v', 'c.v']
				active: 1
			}]
		}
		left:    DockRegion{
			groups: [DockGroup{
				panels: ['files', 'search']
			}]
		}
		right:   DockRegion{
			size:   260
			groups: [DockGroup{
				panels: ['outline']
			}]
		}
		bottom:  DockRegion{
			groups: [DockGroup{
				panels: ['terminal', 'problems']
			}]
		}
	}
}

fn test_dock_layout_normalizes_ids_groups_and_indexes() {
	messy := DockLayout{
		center: DockRegion{
			groups: [
				DockGroup{
					panels: ['a', '', 'b', 'a']
					active: 9
					size:   math.nan()
				},
				DockGroup{},
			]
		}
		left:   DockRegion{
			open:   false
			size:   -5
			groups: [DockGroup{
				panels: ['b', 'c']
				active: 1
			}]
		}
		zoomed: 'gone'
	}
	clean := dock_layout_normalized(messy)
	assert clean.center.groups.len == 1
	assert clean.center.groups[0].panels == ['a', 'b']
	assert clean.center.groups[0].active == 1
	assert clean.center.groups[0].size == 0
	assert clean.left.groups[0].panels == ['c']
	assert clean.left.groups[0].active == 0
	assert !clean.left.open && clean.left.size == 0
	assert clean.zoomed == ''
	assert dock_layout_normalized(clean) == clean
}

fn test_dock_layout_find_list_and_open() {
	layout := panels_layout()
	at := dock_layout_find(layout, 'problems')?
	assert at.placement == .bottom && at.group == 0 && at.index == 1
	assert dock_layout_find(layout, 'nope') == none
	assert dock_layout_find(layout, '') == none
	assert dock_layout_panels(layout) == ['a.v', 'b.v', 'c.v', 'files', 'search', 'outline', 'terminal',
		'problems']
	assert dock_layout_is_open(layout, .left)
	assert !dock_layout_is_open(DockLayout{}, .left)
	assert layout.center.groups[0].active_panel() == 'b.v'
	assert layout.bottom.panel_count() == 2
}

fn test_dock_layout_activate_close_and_zoom() {
	layout := panels_layout()
	shown := dock_layout_activate(layout, 'c.v')?
	assert shown.center.groups[0].active == 2
	assert dock_layout_activate(layout, 'b.v') == none
	// Activating a panel of a closed dock opens it.
	closed := dock_layout_toggle(layout, .bottom)?
	assert !closed.bottom.open
	reopened := dock_layout_activate(closed, 'terminal')?
	assert reopened.bottom.open
	// Closing the displayed tab shows the next one; the last tab shows the one
	// before it; a tab before the displayed one keeps the display.
	after := dock_layout_close(layout, 'b.v')?
	assert after.center.groups[0].panels == ['a.v', 'c.v']
	assert after.center.groups[0].active_panel() == 'c.v'
	last := dock_layout_close(shown, 'c.v')?
	assert last.center.groups[0].active_panel() == 'b.v'
	before := dock_layout_close(layout, 'a.v')?
	assert before.center.groups[0].active_panel() == 'b.v'
	gone := dock_layout_close(layout, 'outline')?
	assert gone.right.groups.len == 0 && !gone.right.has_panels()
	assert dock_layout_close(layout, 'nope') == none
	// Zoom names a group; closing its displayed panel hands the zoom on.
	zoomed := dock_layout_zoom(layout, 'b.v')?
	assert zoomed.zoomed == 'b.v'
	assert dock_layout_zoom(zoomed, 'a.v')?.zoomed == ''
	assert dock_layout_zoom(zoomed, 'terminal')?.zoomed == 'terminal'
	handed := dock_layout_close(zoomed, 'b.v')?
	assert handed.zoomed == 'c.v'
}

fn test_dock_layout_add_move_split_toggle_resize_and_retain() {
	layout := panels_layout()
	added := dock_layout_add(layout, 'notes', .right)
	assert added.right.groups[0].panels == ['outline', 'notes']
	assert added.right.groups[0].active_panel() == 'notes'
	fresh := dock_layout_add(DockLayout{
		bottom: DockRegion{
			open: false
		}
	}, 'log', .bottom)
	assert fresh.bottom.groups.len == 1 && fresh.bottom.open
	moved := dock_layout_move(layout, 'search', .bottom)?
	assert moved.left.groups[0].panels == ['files']
	assert moved.bottom.groups[0].panels == ['terminal', 'problems', 'search']
	assert dock_layout_move(layout, 'search', .left) == none
	assert dock_layout_move(layout, 'nope', .left) == none
	split := dock_layout_split(layout, 'c.v')?
	assert split.center.groups.len == 2
	assert split.center.groups[0].panels == ['a.v', 'b.v']
	assert split.center.groups[1].panels == ['c.v']
	assert dock_layout_split(layout, 'outline') == none
	sized := DockLayout{
		...layout
		center: DockRegion{
			groups: [DockGroup{
				panels: ['a.v', 'b.v']
				size:   600
			}]
		}
	}
	halves := dock_layout_split(sized, 'b.v')?
	assert halves.center.groups[0].size == 300 && halves.center.groups[1].size == 300
	assert dock_layout_toggle(layout, .center) == none
	assert dock_layout_toggle(DockLayout{}, .left) == none
	assert dock_layout_resize(layout, .left, 300).left.size == 300
	assert dock_layout_resize(layout, .left, math.nan()).left.size == 0
	kept := dock_layout_retain(layout, ['b.v', 'c.v', 'terminal'])
	assert kept.center.groups[0].panels == ['b.v', 'c.v']
	assert kept.center.groups[0].active_panel() == 'b.v'
	assert !kept.left.has_panels() && kept.bottom.groups[0].panels == ['terminal']
}

fn test_dock_layout_encode_and_decode_round_trip() {
	layout := DockLayout{
		...dock_layout_split(panels_layout(), 'c.v')?
		zoomed: 'terminal'
		left:   DockRegion{
			open:   false
			size:   250.5
			groups: [DockGroup{
				panels: ['a file.v', '100%', 'line\nbreak', 'naïve', '=']
				active: 3
				size:   120.25
			}]
		}
	}
	text := dock_layout_encode(layout)
	assert text.starts_with('ui2-dock 1\nversion 2\nzoomed terminal\n')
	assert text.contains('left closed 250.5\ngroup 3 120.25 a%20file.v 100%25 line%0Abreak na%C3%AFve %3D\n')
	back := dock_layout_decode(text) or { panic(err) }
	assert back == dock_layout_normalized(layout)
	assert dock_layout_decode(dock_layout_encode(DockLayout{})) or { panic(err) } == DockLayout{}
	// Regions left out stay empty and open; blank lines and spaces are fine.
	partial := dock_layout_decode('ui2-dock 1\n\n  center open 0 \ngroup 0 0 x\n') or {
		panic(err)
	}
	assert partial.center.groups[0].panels == ['x'] && partial.left.open
}

fn test_dock_layout_decode_rejects_anything_else() {
	for text in [
		'',
		'ui2-dock 2\n',
		'version 1\n',
		'ui2-dock 1\ngroup 0 0 a\n',
		'ui2-dock 1\ncenter open\n',
		'ui2-dock 1\ncenter ajar 0\n',
		'ui2-dock 1\nmiddle open 0\n',
		'ui2-dock 1\ncenter open 0\ncenter open 0\n',
		'ui2-dock 1\ncenter open -1\n',
		'ui2-dock 1\ncenter open nan\n',
		'ui2-dock 1\ncenter open 0\ngroup x 0 a\n',
		'ui2-dock 1\ncenter open 0\ngroup 0 0\n',
		'ui2-dock 1\ncenter open 0\ngroup 0 0 a%2\n',
		'ui2-dock 1\ncenter open 0\ngroup 0 0 a%zz\n',
		'ui2-dock 1\nversion -1\n',
		'ui2-dock 1\nversion 01\n',
		'ui2-dock 1\ncenter open 0\nversion 1\n',
		'ui2-dock 1\nzoomed\n',
	] {
		if _ := dock_layout_decode(text) {
			assert false, 'accepted `${text}`'
		}
	}
}

// ── Dock area geometry and drawing ──────────────────────────────────

fn panels_dock_config(layout DockLayout, state DockAreaState) DockAreaConfig {
	return DockAreaConfig{
		id:      'dock'
		frame:   rect(0, 40, 1000, 700)
		layout:  layout
		state:   state
		panels:  [
			DockPanel{
				id:    'a.v'
				title: 'a.v'
				icon:  'doc'
			},
			DockPanel{
				id:         'b.v'
				title:      'b.v'
				menu_items: [dropdown_menu_item('copy-path', 'Copy Path')]
			},
			DockPanel{
				id:       'files'
				title:    'Files'
				closable: false
			},
			DockPanel{
				id:       'outline'
				title:    'Outline'
				zoomable: false
			},
		]
		content: fn (panel string, frame Rect) Element {
			return label('', panel, frame, TextStyle{})
		}
	}
}

fn test_dock_area_layout_places_docks_center_and_handles() {
	geometry := dock_area_layout(panels_dock_config(panels_layout(), DockAreaState{})) or {
		panic(err)
	}
	assert geometry.left == rect(0, 0, 240, 700)
	assert geometry.right == rect(740, 0, 260, 700)
	assert geometry.center == rect(241, 0, 498, 499)
	assert geometry.bottom == rect(241, 500, 498, 200)
	names := geometry.handles.map(it.name)
	assert 'left' in names && 'right' in names && 'bottom' in names
	for handle in geometry.handles {
		match handle.name {
			'left' {
				assert handle.line == 240 && handle.frame == rect(236, 0, 9, 700)
			}
			'right' {
				assert handle.line == 739
			}
			'bottom' {
				assert handle.line == 499 && handle.axis == .vertical
			}
			else {}
		}
	}
	center := geometry.groups.filter(it.placement == .center)[0]
	assert center.kind == .tabs && center.panel == 'b.v'
	assert center.bar == rect(241, 0, 498, 34)
	assert center.content == rect(241, 34, 498, 465)
	assert center.tools.map(it.tool) == ['toggle:left', 'menu', 'toggle:right']
	right := geometry.groups.filter(it.placement == .right)[0]
	assert right.kind == .title && right.tools.map(it.tool) == ['menu']
	bottom := geometry.groups.filter(it.placement == .bottom)[0]
	assert bottom.tools.map(it.tool) == ['toggle:bottom', 'menu']
}

fn test_dock_area_layout_squeezes_docks_into_a_small_window() {
	config := DockAreaConfig{
		...panels_dock_config(panels_layout(), DockAreaState{})
		frame: rect(0, 0, 500, 300)
	}
	geometry := dock_area_layout(config) or { panic(err) }
	// The center keeps its minimum; the docks share the rest down to theirs.
	assert geometry.center.width >= 160
	assert geometry.left.width >= 120 && geometry.right.width >= 120
	assert geometry.left.width + geometry.right.width + geometry.center.width + 2 == 500
	assert geometry.bottom.height + geometry.center.height + 1 == 300
	assert geometry.center.height >= 139
	// What is taken comes from what each has above the minimum, in proportion.
	a, b := dock_squeeze(300, 100, 200, 50)
	assert panels_close(a, 300 - 200.0 * 250 / 300) && panels_close(b, 100 - 200.0 * 50 / 300)
	c, d := dock_squeeze(100, 100, 50, 80)
	assert panels_close(c, 25) && panels_close(d, 25)
}

fn test_dock_area_layout_strip_zoom_and_empty_center() {
	closed := dock_layout_toggle(panels_layout(), .bottom)?
	geometry := dock_area_layout(panels_dock_config(closed, DockAreaState{})) or { panic(err) }
	strip := geometry.groups.filter(it.kind == .strip)[0]
	assert strip.frame == rect(241, 666, 498, 34)
	assert strip.tabs.map(it.panel) == ['terminal', 'problems']
	assert strip.tabs.all(it.close.width == 0)
	assert strip.tools.map(it.tool) == ['toggle:bottom']
	assert 'bottom' !in geometry.handles.map(it.name)
	assert geometry.lines == [rect(241, 665, 498, 1)]
	zoomed := dock_area_layout(panels_dock_config(DockLayout{
		...panels_layout()
		zoomed: 'terminal'
	}, DockAreaState{})) or { panic(err) }
	assert zoomed.zoomed && zoomed.groups.len == 1 && zoomed.handles.len == 0
	assert zoomed.groups[0].frame == rect(0, 0, 1000, 700)
	assert zoomed.groups[0].tools.map(it.tool) == ['zoom', 'menu']
	empty := dock_area_layout(panels_dock_config(DockLayout{
		left: panels_layout().left
	}, DockAreaState{})) or { panic(err) }
	center := empty.groups.filter(it.kind == .empty)[0]
	assert center.tools.map(it.tool) == ['toggle:left']
	el := dock_area(panels_dock_config(DockLayout{}, DockAreaState{})) or { panic(err) }
	assert panels_find_key(el, 'content:empty')?.children[0].text == 'No open panels'
}

fn test_dock_area_tabs_offer_close_only_where_allowed() {
	geometry := dock_area_layout(panels_dock_config(panels_layout(), DockAreaState{})) or {
		panic(err)
	}
	center := geometry.groups.filter(it.placement == .center)[0]
	assert center.tabs.all(it.shown && it.close.width > 0)
	left := geometry.groups.filter(it.placement == .left)[0]
	// Files is not closable; Search is, as the left dock has another panel.
	assert left.tabs[0].close.width == 0 && left.tabs[1].close.width > 0
	single := dock_area_layout(panels_dock_config(DockLayout{
		...panels_layout()
		left: DockRegion{
			groups: [DockGroup{
				panels: ['search']
			}]
		}
	}, DockAreaState{})) or { panic(err) }
	// A dock's last panel offers no close.
	only := single.groups.filter(it.placement == .left)[0]
	assert only.kind == .title
	assert dock_area_menu_items(panels_dock_config(DockLayout{
		...panels_layout()
		left: DockRegion{
			groups: [DockGroup{
				panels: ['search']
			}]
		}
	}, DockAreaState{}), 'search').all(it.id != 'dock:close')
	tabs_style := dock_area_layout(DockAreaConfig{
		...panels_dock_config(panels_layout(), DockAreaState{})
		panel_style: .tabs
	}) or { panic(err) }
	assert tabs_style.groups.filter(it.placement == .right)[0].kind == .tabs
	locked := DockAreaConfig{
		...panels_dock_config(panels_layout(), DockAreaState{})
		locked: true
	}
	assert !dock_area_can_close(locked, 'a.v')
	assert dock_area_menu_items(locked, 'a.v').map(it.id) == ['dock:zoom']
}

fn test_dock_area_tabs_shrink_and_keep_the_displayed_tab_in_view() {
	mut panels := []string{}
	for i in 0 .. 12 {
		panels << 'document-number-${i}.v'
	}
	layout := DockLayout{
		center: DockRegion{
			groups: [DockGroup{
				panels: panels
				active: 11
			}]
		}
	}
	geometry := dock_area_layout(DockAreaConfig{
		...panels_dock_config(layout, DockAreaState{})
		frame: rect(0, 0, 600, 400)
	}) or { panic(err) }
	group := geometry.groups[0]
	assert group.tabs.len == 12
	assert group.tabs[11].shown
	assert !group.tabs[0].shown
	shown := group.tabs.filter(it.shown)
	for tab in shown {
		assert tab.frame.width >= 64
		assert tab.frame.x >= 0 && tab.frame.x + tab.frame.width <= 600 - 34
	}
}

fn test_dock_area_draws_groups_content_handles_and_menu() {
	state := DockAreaState{
		current:    'b.v'
		menu_panel: 'b.v'
		menu:       DropdownMenuState{
			open: true
		}
		hovered:    'left'
	}
	config := panels_dock_config(panels_layout(), state)
	el := dock_area(config) or { panic(err) }
	assert el.id == 'dock' && el.frame == config.frame
	validate_element_tree(el) or { panic(err) }
	content := panels_find_key(el, 'content:b.v')?
	assert content.frame == rect(241, 34, 498, 465)
	assert content.children[0].text == 'b.v'
	assert content.children[0].frame == rect(0, 0, 498, 465)
	assert panels_find_key(el, 'content:a.v') == none
	tab := panels_find(el, component_part_id('dock', 'tab:' + 'b.v'.bytes().hex()))?
	assert tab.button_behavior && tab.accessibility_role == 'tab'
	assert tab.accessibility_value == 'selected'
	assert panels_find_key(tab, 'accent')?.box.bg == config.theme.primary
	other := panels_find(el, component_part_id('dock', 'tab:' + 'a.v'.bytes().hex()))?
	assert other.accessibility_value == 'not selected'
	assert panels_find_key(other, 'accent') == none
	close := panels_find(el, component_part_id('dock', 'close:' + 'a.v'.bytes().hex()))?
	assert close.button_behavior && close.accessibility_label == 'Close a.v'
	handle := panels_find(el, component_part_id('dock', 'handle:left'))?
	assert handle.draggable && handle.cursor == cursor_resize_ew
	assert panels_find_key(handle, 'indicator')?.frame.height == 20
	menu := panels_find(el, dock_area_menu_id('dock'))?
	assert menu.children.len > 1
	menu_button := panels_find(el, component_part_id('dock', 'menu:' + 'b.v'.bytes().hex()))?
	assert menu_button.accessibility_value == 'expanded'
	for size in [ComponentSize.small, .medium, .large] {
		for dark in [false, true] {
			tree := dock_area(DockAreaConfig{
				...config
				size:  size
				theme: component_theme(dark)
			}) or { panic(err) }
			validate_element_tree(tree) or { panic(err) }
		}
	}
}

fn test_dock_area_validates_its_config() {
	base := panels_dock_config(panels_layout(), DockAreaState{})
	if _ := dock_area(DockAreaConfig{ ...base, id: '' }) {
		assert false, 'missing id accepted'
	}
	if _ := dock_area(DockAreaConfig{ ...base, min_dock: -1 }) {
		assert false, 'negative minimum accepted'
	}
	if _ := dock_area(DockAreaConfig{ ...base, step: math.nan() }) {
		assert false, 'NaN step accepted'
	}
	if _ := dock_area(DockAreaConfig{
		...base
		panels: [DockPanel{
			id: 'x'
		}, DockPanel{
			id: 'x'
		}]
	})
	{
		assert false, 'duplicate panel ids accepted'
	}
	// A panel the application did not describe is titled with its id.
	assert dock_area_panel(base, 'terminal').title == 'terminal'
}

// ── Dock area events ────────────────────────────────────────────────

fn panels_action(part string) string {
	return component_part_id('dock', part)
}

fn panels_hex_action(kind string, panel string) string {
	return panels_action(kind + ':' + panel.bytes().hex())
}

fn test_dock_area_event_activates_closes_and_toggles() {
	config := panels_dock_config(panels_layout(), DockAreaState{})
	shown := dock_area_event(config, panels_hex_action('tab', 'c.v'))?
	assert shown.kind == .activate && shown.panel == 'c.v' && shown.placement == .center
	assert shown.layout.center.groups[0].active_panel() == 'c.v'
	assert shown.state.current == 'c.v'
	// Clicking the displayed tab makes it current once, then does nothing.
	current := dock_area_event(config, panels_hex_action('tab', 'b.v'))?
	assert current.state.current == 'b.v' && current.layout == config.layout
	again := panels_dock_config(panels_layout(), current.state)
	assert dock_area_event(again, panels_hex_action('tab', 'b.v')) == none
	closed := dock_area_event(config, panels_hex_action('close', 'a.v'))?
	assert closed.kind == .close && dock_layout_find(closed.layout, 'a.v') == none
	// Files is not closable.
	assert dock_area_event(config, panels_hex_action('close', 'files')) == none
	toggled := dock_area_event(config, panels_action('toggle:left'))?
	assert toggled.kind == .toggle_dock && toggled.placement == .left
	assert !toggled.layout.left.open
	assert dock_area_event(config, panels_action('toggle:center')) == none
	assert dock_area_event(config, panels_action('toggle:top')) == none
	zoomed := dock_area_event(config, panels_hex_action('zoom', 'b.v'))?
	assert zoomed.kind == .zoom && zoomed.layout.zoomed == 'b.v'
	assert dock_area_event(config, panels_hex_action('zoom', 'outline')) == none
	disabled := DockAreaConfig{
		...config
		enabled: false
	}
	assert dock_area_event(disabled, panels_hex_action('tab', 'c.v')) == none
}

fn test_dock_area_event_rejects_forged_panels() {
	config := panels_dock_config(panels_layout(), DockAreaState{})
	assert dock_area_event(config, panels_hex_action('tab', 'nope')) == none
	assert dock_area_event(config, panels_action('tab:' + 'c.v'.bytes().hex().to_upper())) == none
	assert dock_area_event(config, panels_action('tab:6')) == none
	assert dock_area_event(config, panels_action('tab:zz')) == none
	assert dock_area_event(config, panels_action('tab:')) == none
	assert dock_area_event(config, 'other:component:tab:' + 'c.v'.bytes().hex()) == none
	assert dock_area_event(config, panels_action('handle:middle')) == none
	assert dock_area_event(config, panels_pointer('down', 'dock', 'handle:middle', 1, 1)) == none
	assert dock_area_event(config, panels_pointer('down', 'dock', 'handle:split:center:0',
		1, 1)) == none
}

fn test_dock_area_menu_opens_chooses_and_closes() {
	config := panels_dock_config(panels_layout(), DockAreaState{})
	items := dock_area_menu_items(config, 'b.v')
	ids := items.filter(it.id.len > 0).map(it.id)
	assert ids == ['copy-path', 'dock:zoom', 'dock:move:left', 'dock:move:right', 'dock:move:bottom',
		'dock:split', 'dock:close']
	opened := dock_area_event(config, panels_hex_action('menu', 'b.v'))?
	assert opened.kind == .menu && opened.state.menu.open && opened.state.menu_panel == 'b.v'
	open := panels_dock_config(panels_layout(), opened.state)
	// The same button closes it again; the backdrop dismisses it.
	shut := dock_area_event(open, panels_hex_action('menu', 'b.v'))?
	assert !shut.state.menu.open && shut.state.menu_panel == ''
	dismissed := dock_area_event(open, dropdown_menu_dismiss_action(dock_area_menu_id('dock')))?
	assert dismissed.kind == .menu && !dismissed.state.menu.open
	index := items.map(it.id).index('dock:move:bottom')
	moved := dock_area_event(open, dropdown_menu_item_action(dock_area_menu_id('dock'), [
		index,
	]))?
	assert moved.kind == .move && moved.placement == .bottom && moved.panel == 'b.v'
	assert moved.layout.bottom.groups[0].panels.last() == 'b.v'
	assert !moved.state.menu.open && moved.state.current == 'b.v'
	own := dock_area_event(open, dropdown_menu_item_action(dock_area_menu_id('dock'), [0]))?
	assert own.kind == .menu_item && own.item == 'copy-path' && own.panel == 'b.v'
	assert own.layout == open.layout
	split := dock_area_event(open, dropdown_menu_item_action(dock_area_menu_id('dock'), [
		items.map(it.id).index('dock:split'),
	]))?
	assert split.kind == .split && split.layout.center.groups.len == 2
	// The keyboard drives the open menu too.
	down := dock_area_key(open, KeyEvent{ code: .down })?
	assert down.kind == .menu && down.state.menu.path == [0]
	escape := dock_area_key(open, KeyEvent{ code: .escape })?
	assert !escape.state.menu.open && escape.state.menu_panel == ''
	// A panel with nothing to offer has no menu.
	bare := DockAreaConfig{
		...config
		locked: true
		panels: [DockPanel{
			id:       'outline'
			zoomable: false
		}]
	}
	assert dock_area_menu_items(bare, 'outline').len == 0
	assert dock_area_event(bare, panels_hex_action('menu', 'outline')) == none
}

fn test_dock_area_edges_resize_close_and_reopen_by_dragging() {
	config := panels_dock_config(panels_layout(), DockAreaState{})
	down := dock_area_event(config, panels_pointer('down', 'dock', 'handle:left', 240, 300))?
	assert down.kind == .resize_start && down.state.drag.handle == 'left'
	assert down.state.drag.size == 240 && down.state.focused == 'left'
	pressed := panels_dock_config(panels_layout(), down.state)
	wider := dock_area_event(pressed, panels_pointer('drag', 'dock', 'handle:left', 300, 300))?
	assert wider.kind == .resize && wider.layout.left.size == 300 && wider.state.drag.moved
	limit := dock_area_event(pressed, panels_pointer('drag', 'dock', 'handle:left', 2000,
		300))?
	assert limit.layout.left.size == 1000 - 260 - 1 - 1 - 160
	least := dock_area_event(pressed, panels_pointer('drag', 'dock', 'handle:left', 100, 300))?
	assert least.layout.left.size == 120 && least.layout.left.open
	shut := dock_area_event(pressed, panels_pointer('drag', 'dock', 'handle:left', 40, 300))?
	assert !shut.layout.left.open && shut.layout.left.size == 240
	// The edge stays under the pointer while the drag that closed the dock goes on.
	closing := dock_area(panels_dock_config(shut.layout, shut.state)) or { panic(err) }
	assert panels_find(closing, component_part_id('dock', 'handle:left'))?.frame == rect(0, 0, 5, 700)
	released := dock_area_event(panels_dock_config(shut.layout, shut.state), panels_pointer('up',
		'dock', 'handle:left', 40, 300))?
	assert released.kind == .resize_end && !released.state.drag.active()
	assert !released.layout.left.open
	settled := dock_area(panels_dock_config(released.layout, released.state)) or { panic(err) }
	assert panels_find(settled, component_part_id('dock', 'handle:left')) == none
	reopened := dock_area_event(panels_dock_config(shut.layout, shut.state), panels_pointer('drag',
		'dock', 'handle:left', 200, 300))?
	assert reopened.layout.left.open && reopened.layout.left.size == 200
	up := dock_area_event(panels_dock_config(wider.layout, wider.state), panels_pointer('up',
		'dock', 'handle:left', 310, 300))?
	assert up.kind == .resize_end && !up.state.drag.active() && up.layout.left.size == 310
	// The right edge grows leftward, the bottom edge upward.
	right_down := dock_area_event(config, panels_pointer('down', 'dock', 'handle:right',
		739, 0))?
	right := dock_area_event(panels_dock_config(panels_layout(), right_down.state),
		panels_pointer('drag', 'dock', 'handle:right', 700, 0))?
	assert right.layout.right.size == 299
	bottom_down := dock_area_event(config, panels_pointer('down', 'dock', 'handle:bottom',
		0, 499))?
	bottom := dock_area_event(panels_dock_config(panels_layout(), bottom_down.state),
		panels_pointer('drag', 'dock', 'handle:bottom', 0, 399))?
	assert bottom.layout.bottom.size == 300
	// Hover.
	enter := dock_area_event(config, panels_pointer('enter', 'dock', 'handle:left', 240, 0))?
	assert enter.kind == .hover && enter.state.hovered == 'left'
	leave := dock_area_event(panels_dock_config(panels_layout(), enter.state), panels_pointer('leave',
		'dock', 'handle:left', 240, 0))?
	assert leave.state.hovered == ''
}

fn test_dock_area_group_dividers_resize_neighbouring_groups() {
	layout := dock_layout_split(panels_layout(), 'c.v')?
	config := panels_dock_config(layout, DockAreaState{})
	geometry := dock_area_layout(config) or { panic(err) }
	divider := geometry.handles.filter(it.name == 'split:center:0')[0]
	groups := geometry.groups.filter(it.placement == .center)
	assert groups.len == 2
	assert panels_close(groups[0].frame.width + groups[1].frame.width + 1, 498)
	down := dock_area_event(config, panels_pointer('down', 'dock', 'handle:split:center:0',
		divider.line, 0))?
	assert down.state.drag.sizes.len == 2
	moved := dock_area_event(panels_dock_config(layout, down.state), panels_pointer('drag',
		'dock', 'handle:split:center:0', divider.line + 50, 0))?
	sizes := moved.layout.center.groups.map(it.size)
	assert panels_close(sizes[0], down.state.drag.sizes[0] + 50)
	assert panels_close(sizes[0] + sizes[1], 497)
	// A group keeps its minimum.
	far := dock_area_event(panels_dock_config(layout, down.state), panels_pointer('drag',
		'dock', 'handle:split:center:0', divider.line + 1000, 0))?
	assert panels_close(far.layout.center.groups[1].size, 80)
}

fn test_dock_area_keys_resize_toggle_and_zoom_out() {
	state := DockAreaState{
		focused: 'left'
	}
	config := panels_dock_config(panels_layout(), state)
	right := dock_area_key(config, KeyEvent{ code: .right })?
	assert right.kind == .resize && right.layout.left.size == 250 && right.state.focus_visible
	shifted := dock_area_key(config, KeyEvent{ code: .left, shift: true })?
	assert shifted.layout.left.size == 190
	home := dock_area_key(config, KeyEvent{ code: .home })?
	assert home.layout.left.size == 120 && home.layout.left.open
	end := dock_area_key(config, KeyEvent{ code: .end })?
	assert end.layout.left.size == 578
	assert dock_area_key(config, KeyEvent{ code: .up }) == none
	toggled := dock_area_key(config, KeyEvent{ code: .enter })?
	assert toggled.kind == .toggle_dock && !toggled.layout.left.open
	escape := dock_area_key(config, KeyEvent{ code: .escape })?
	assert escape.kind == .focus && escape.state.focused == ''
	bottom := dock_area_key(panels_dock_config(panels_layout(), DockAreaState{
		focused: 'bottom'
	}), KeyEvent{ code: .up })?
	assert bottom.layout.bottom.size == 210
	zoomed := DockLayout{
		...panels_layout()
		zoomed: 'a.v'
	}
	out := dock_area_key(panels_dock_config(zoomed, DockAreaState{}), KeyEvent{ code: .escape })?
	assert out.kind == .zoom && out.layout.zoomed == ''
	assert dock_area_key(panels_dock_config(panels_layout(), DockAreaState{}), KeyEvent{
		code: .escape
	}) == none
	assert dock_area_key(config, KeyEvent{ code: .right, cmd: true }) == none
}

fn test_dock_area_locked_keeps_the_arrangement() {
	config := DockAreaConfig{
		...panels_dock_config(panels_layout(), DockAreaState{})
		locked: true
	}
	assert dock_area_event(config, panels_hex_action('close', 'a.v')) == none
	assert dock_area_apply(config, panels_layout(), DockAreaState{}, 'a.v', 'dock:move:left') == none
	assert dock_area_apply(config, panels_layout(), DockAreaState{}, 'a.v', 'dock:split') == none
	// Docks still open, close and resize.
	assert dock_area_event(config, panels_action('toggle:left'))?.kind == .toggle_dock
	assert dock_area_event(config, panels_pointer('down', 'dock', 'handle:left', 240, 0))?.kind == .resize_start
}
