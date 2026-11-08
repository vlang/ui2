// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Drawing for the tab bar in component_navigation2_tabs.v. The colors of each
// variant's states and the folder tab's outline follow GPUI Kit's tab.rs.
module ui2

import math

struct TabBarColors {
	bar          u32 // The fill of a tab or folder bar.
	track        u32 // The segmented track.
	surface      u32 // The content's color, which selected tab and folder tabs join.
	fg           u32
	active       u32 // Selected and hovered text.
	disabled     u32
	border       u32
	hover        u32 // Hovered outline and pill tabs.
	folder_hover u32
	badge        u32
	primary      u32
	primary_fg   u32
}

fn tab_bar_colors(theme ComponentTheme) TabBarColors {
	bar := popover_blend(theme.background, theme.muted, 0.8)
	return TabBarColors{
		bar:          bar
		track:        theme.muted
		surface:      theme.background
		fg:           theme.muted_foreground
		active:       theme.foreground
		disabled:     popover_blend(theme.muted_foreground, theme.background, 0.5)
		border:       theme.border
		hover:        theme.muted
		folder_hover: popover_blend(bar, theme.foreground, 0.07)
		badge:        popover_blend(theme.background, theme.foreground, 0.1)
		primary:      theme.primary
		primary_fg:   theme.primary_foreground
	}
}

fn tab_bar_box(variant TabVariant, colors TabBarColors, m TabBarMetrics) BoxStyle {
	return match variant {
		.tab, .folder {
			BoxStyle{
				bg: colors.bar
			}
		}
		.segmented {
			BoxStyle{
				bg:     colors.track
				radius: m.track
			}
		}
		else {
			BoxStyle{
				transparent: true
			}
		}
	}
}

// tab_bar_strip_fill is what a scrolling strip is filled with: the custom
// renderer fills a Scroll whatever its box says, so it is the color the
// strip sits on. A bar without a fill of its own sits on the theme's
// background.
fn tab_bar_strip_fill(variant TabVariant, colors TabBarColors) u32 {
	return match variant {
		.tab, .folder { colors.bar }
		.segmented { colors.track }
		else { colors.surface }
	}
}

fn tab_bar_line(frame Rect, color u32, key string) Element {
	return Element{
		...view('', frame, BoxStyle{ bg: color }, []Element{})
		key: key
	}
}

fn tab_bar_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

struct TabLook {
	selected bool
	hovered  bool
	dragged  bool
	leading  bool // Starts where the strip does, against the bar's edge.
}

fn tab_bar_text_color(variant TabVariant, item TabBarItem, look TabLook, colors TabBarColors) u32 {
	if !item.enabled {
		return if look.selected && variant == .pill {
			popover_blend(colors.primary_fg, colors.primary, 0.5)
		} else {
			colors.disabled
		}
	}
	if look.selected {
		return match variant {
			.pill { colors.primary_fg }
			.outline { colors.primary }
			else { colors.active }
		}
	}
	return if look.hovered { colors.active } else { colors.fg }
}

fn tab_bar_tab_box(config TabBarConfig, item TabBarItem, look TabLook, frame Rect, horizontal bool, m TabBarMetrics, colors TabBarColors) BoxStyle {
	round := math.min(frame.width, frame.height) / 2
	hover := look.hovered && !look.selected && item.enabled
	if look.dragged {
		// A dragged tab floats over the others.
		return BoxStyle{
			bg:            if config.variant == .pill && look.selected {
				colors.primary
			} else {
				colors.surface
			}
			radius:        if config.variant in [.outline, .pill] { round } else { m.radius }
			border_color:  colors.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        component_card_shadow()
		}
	}
	match config.variant {
		.tab {
			if !look.selected {
				return BoxStyle{
					transparent: true
				}
			}
			lead := if look.leading { 0.0 } else { 1.0 }
			return BoxStyle{
				bg:            colors.surface
				border_color:  colors.border
				border_left:   if horizontal { lead } else { 0.0 }
				border_right:  if horizontal { 1.0 } else { 0.0 }
				border_top:    if horizontal { 0.0 } else { lead }
				border_bottom: if horizontal { 0.0 } else { 1.0 }
			}
		}
		.outline {
			ring := if look.selected {
				if item.enabled {
					colors.primary
				} else {
					popover_blend(colors.primary, colors.surface, 0.5)
				}
			} else {
				colors.border
			}
			return BoxStyle{
				bg:            colors.hover
				transparent:   !hover
				radius:        round
				border_color:  ring
				border_left:   1
				border_top:    1
				border_right:  1
				border_bottom: 1
			}
		}
		.pill {
			return BoxStyle{
				bg:          colors.hover
				transparent: !hover
				radius:      round
			}
		}
		else {
			return BoxStyle{
				transparent: true
			}
		}
	}
}

fn tab_bar_badge_element(item TabBarItem, frame Rect, m TabBarMetrics, theme ComponentTheme, colors TabBarColors) Element {
	bg, fg := if item.badge_tone == .neutral {
		colors.badge, theme.foreground
	} else {
		theme.colors(item.badge_tone)
	}
	return Element{
		...view('', frame, BoxStyle{
			bg:     if item.enabled { bg } else { popover_blend(bg, colors.surface, 0.5) }
			radius: frame.height / 2
		}, [
			label('', item.badge, rect(0, 0, frame.width, frame.height), TextStyle{
				color: if item.enabled { fg } else { colors.disabled }
				size:  m.small
				align: .center
			}),
		])
		key:                 'badge'
		accessibility_role:  'status'
		accessibility_label: item.badge
	}
}

fn tab_bar_caption(item TabBarItem) string {
	return if item.accessibility_label.len > 0 {
		item.accessibility_label
	} else if item.label.len > 0 {
		item.label
	} else {
		item.id
	}
}

fn tab_bar_tab_element(config TabBarConfig, item TabBarItem, frame Rect, look TabLook, horizontal bool, m TabBarMetrics, colors TabBarColors) Element {
	pieces := tab_bar_pieces(item, frame, m, horizontal)
	color := tab_bar_text_color(config.variant, item, look, colors)
	mut children := []Element{}
	if item.icon.len > 0 {
		children << Element{
			...tab_bar_symbol(item.icon, pieces.icon, color)
			key: 'icon'
		}
	}
	if item.label.len > 0 {
		children << Element{
			...label('', item.label, pieces.label, TextStyle{
				color: color
				size:  m.font
			})
			key: 'label'
		}
	}
	if item.badge.len > 0 {
		children << tab_bar_badge_element(item, pieces.badge, m, config.theme, colors)
	}
	caption := tab_bar_caption(item)
	if item.closable {
		mark := math.round(m.close * 0.6)
		close := pieces.close
		children << Element{
			...button_view(tab_bar_close_action(config.id, item.id), close, BoxStyle{
				transparent: true
				radius:      4
			}, [
				tab_bar_symbol('xmark', rect(math.round((close.width - mark) / 2), math.round((close.height - mark) / 2),
					mark, mark), if item.enabled { colors.fg } else { colors.disabled }),
			])
			key:                 'close'
			enabled:             item.enabled
			tooltip:             'Close'
			cursor:              cursor_pointing_hand
			accessibility_label: 'Close ${caption}'
		}
	}
	shortened := item.label.len > 0 && pieces.label.width + 0.5 < pieces.label_width
	tip := if item.tooltip.len > 0 {
		item.tooltip
	} else if tab_bar_icon_only(item) || shortened {
		caption
	} else {
		''
	}
	tab := button_view(tab_bar_tab_action(config.id, item.id), frame, tab_bar_tab_box(config,
		item, look, frame, horizontal, m, colors), children)
	return Element{
		...tab
		action_id:           if item.action_id.len > 0 { item.action_id } else { tab.id }
		key:                 'tab:' + item.id
		enabled:             item.enabled
		hoverable:           item.enabled
		draggable:           config.reorderable && item.enabled
		tooltip:             tip
		cursor:              if item.enabled { cursor_pointing_hand } else { '' }
		accessibility_role:  'tab'
		accessibility_label: caption
		accessibility_value: if look.selected { 'selected' } else { 'not selected' }
	}
}

// ── The sliding indicator ───────────────────────────────────────────

const tab_bar_slide_seconds = 0.22

fn tab_bar_slide_target(run AnimationRun) ?Rect {
	targets := run.definition.targets
	x := targets.x?
	y := targets.y?
	width := targets.width?
	height := targets.height?
	return rect(x, y, width, height)
}

// tab_bar_slide moves the indicator element `id` to `target`: smoothly when
// it last showed another tab (its key names the tab), at once when the same
// tab only moved, as it does while the window is resized. The widget
// animation keeps the frame it ends at, so a later build that declares the
// same frame changes nothing.
fn tab_bar_slide(id string, key string, target Rect) {
	mut seen := false
	mut applied := false
	mut aiming := false
	mut aim := Rect{}
	mut last_key := ''
	mut last_frame := Rect{}
	runtime := g_animation_runtime
	runtime.mutex.lock()
	if run := runtime.runs[id] {
		seen = true
		applied = run.initialized
		last_key = run.last.key
		last_frame = run.last.frame
		if run.status == .running {
			if goal := tab_bar_slide_target(run) {
				aiming = true
				aim = goal
			}
		}
	}
	runtime.mutex.unlock()
	if aiming && aim == target {
		return
	}
	if seen && applied && !aiming && last_frame == target {
		return
	}
	duration := if seen && applied && last_key != key { tab_bar_slide_seconds } else { 0.0 }
	animation(
		duration:   duration
		transition: .out_cubic
		x:          target.x
		y:          target.y
		width:      target.width
		height:     target.height
	).start(id)
}

fn tab_bar_indicator(config TabBarConfig, item TabBarItem, frame Rect, strip_thickness f64, horizontal bool, m TabBarMetrics, colors TabBarColors) Element {
	enabled := item.enabled
	mut target := frame
	mut box := BoxStyle{}
	match config.variant {
		.segmented {
			box = BoxStyle{
				bg:     colors.surface
				radius: math.max(m.track - m.inset, 2)
				shadow: if enabled { box_shadow(0x000000, 0.14, 3, 1) } else { BoxShadow{} }
			}
		}
		.pill {
			box = BoxStyle{
				bg:     if enabled {
					colors.primary
				} else {
					popover_blend(colors.primary, colors.surface, 0.5)
				}
				radius: math.min(frame.width, frame.height) / 2
			}
		}
		else {
			start, length := tab_bar_along(frame, horizontal)
			target = tab_bar_place(config.position, start, strip_thickness - m.line, length,
				m.line, strip_thickness)
			box = BoxStyle{
				bg: if enabled { colors.primary } else { colors.border }
			}
		}
	}
	id := tab_bar_indicator_id(config.id)
	key := 'indicator:' + item.id
	if config.animate && !config.state.drag.active {
		tab_bar_slide(id, key, target)
	}
	return Element{
		...view(id, target, box, []Element{})
		key: key
	}
}

// ── Folder tabs ─────────────────────────────────────────────────────

// tab_bar_quarter is a quarter circle from `from` to `to` whose tangents
// meet at `corner`, as a cubic curve.
fn tab_bar_quarter(from PathPoint, corner PathPoint, to PathPoint) PathCommand {
	k := 0.5522847498
	return path_cubic_to(from.x + (corner.x - from.x) * k, from.y + (corner.y - from.y) * k,
		to.x + (corner.x - to.x) * k, to.y + (corner.y - to.y) * k, to.x, to.y)
}

// tab_bar_folder_point maps a point `along` the tab and `across` it from its
// top (the bar's far side) into the shape's own coordinates.
fn tab_bar_folder_point(position TabBarPosition, along f64, across f64, depth f64) PathPoint {
	return match position {
		.top { path_point(along, across) }
		.bottom { path_point(along, depth - across) }
		.left { path_point(across, along) }
		.right { path_point(depth - across, along) }
	}
}

// tab_bar_folder_shape is the selected folder tab: rounded on top, it curves
// out at its foot into the content below, as a browser's tab does. It reaches
// one curve past the tab on either side.
fn tab_bar_folder_shape(config TabBarConfig, frame Rect, strip_thickness f64, horizontal bool, m TabBarMetrics, color u32) Element {
	c := m.curve
	start, length := tab_bar_along(frame, horizontal)
	depth := if horizontal { frame.height } else { frame.width }
	width := length + 2 * c
	r := math.min(math.max(length / 3, 0), c)
	foot := math.max(depth - c, 0)
	pt := fn [config, depth] (along f64, across f64) PathPoint {
		return tab_bar_folder_point(config.position, along, across, depth)
	}
	first := pt(0, depth)
	path := [
		path_move_to(first.x, first.y),
		tab_bar_quarter(first, pt(c, depth), pt(c, foot)),
		path_line_to(pt(c, r).x, pt(c, r).y),
		tab_bar_quarter(pt(c, r), pt(c, 0), pt(c + r, 0)),
		path_line_to(pt(width - c - r, 0).x, pt(width - c - r, 0).y),
		tab_bar_quarter(pt(width - c - r, 0), pt(width - c, 0), pt(width - c, r)),
		path_line_to(pt(width - c, foot).x, pt(width - c, foot).y),
		tab_bar_quarter(pt(width - c, foot), pt(width - c, depth), pt(width, depth)),
		path_close(),
	]
	across := if horizontal {
		if config.position == .top { frame.y } else { strip_thickness - frame.y - frame.height }
	} else {
		if config.position == .left { frame.x } else { strip_thickness - frame.x - frame.width }
	}
	return Element{
		...shape(component_part_id(config.id, 'folder'), tab_bar_place(config.position, start - c,
			across, width, depth, strip_thickness), path, ShapeStyle{
			fill: color
		})
		key: 'folder'
	}
}

// ── The bar ─────────────────────────────────────────────────────────

fn tab_bar_strip_children(config TabBarConfig, layout TabBarLayout, m TabBarMetrics, colors TabBarColors) []Element {
	horizontal := layout.horizontal
	strip_thickness := if horizontal { layout.strip.height } else { layout.strip.width }
	offsets := tab_bar_drag_offsets(config, layout, m)
	mut frames := []Rect{cap: layout.tabs.len}
	for index, tab in layout.tabs {
		frames << if horizontal {
			rect(tab.x + offsets[index], tab.y, tab.width, tab.height)
		} else {
			rect(tab.x, tab.y + offsets[index], tab.width, tab.height)
		}
	}
	selected := tab_bar_index(config.items, config.state.selected)
	hovered := tab_bar_index(config.items, config.state.hovered)
	dragged := if config.state.drag.active {
		tab_bar_index(config.items, config.state.drag.tab)
	} else {
		-1
	}
	mut out := []Element{}
	if config.variant in [.tab, .underline] {
		out << tab_bar_line(tab_bar_place(config.position, 0, strip_thickness - 1, layout.length,
			1, strip_thickness), colors.border, 'edge')
	}
	if config.variant == .folder {
		if hovered >= 0 && hovered != selected && hovered != dragged {
			inset := 3.0
			tab := frames[hovered]
			out << Element{
				...view('', rect(tab.x + inset, tab.y + inset, math.max(tab.width - 2 * inset,
					0), math.max(tab.height - 2 * inset, 0)), BoxStyle{
					bg:     colors.folder_hover
					radius: m.radius
				}, []Element{})
				key: 'hover'
			}
		}
		for index in 0 .. frames.len - 1 {
			shaped := [selected, hovered, dragged]
			if index in shaped || index + 1 in shaped {
				continue
			}
			start, length := tab_bar_along(frames[index], horizontal)
			middle := start + length + m.spacing / 2
			tab_depth := if horizontal { frames[index].height } else { frames[index].width }
			across := strip_thickness - tab_depth + math.round((tab_depth - m.divider) / 2)
			out << tab_bar_line(tab_bar_place(config.position, math.round(middle - 0.5), across,
				1, m.divider, strip_thickness), colors.border, 'divider:${index}')
		}
		if selected >= 0 && selected != dragged {
			out << tab_bar_folder_shape(config, frames[selected], strip_thickness, horizontal,
				m, colors.surface)
		}
	}
	if config.variant in [.segmented, .pill, .underline] && selected >= 0 {
		out << tab_bar_indicator(config, config.items[selected], frames[selected], strip_thickness,
			horizontal, m, colors)
	}
	strip_start, _ := tab_bar_along(layout.strip, horizontal)
	for index, item in config.items {
		if index == dragged {
			continue
		}
		start, _ := tab_bar_along(frames[index], horizontal)
		look := TabLook{
			selected: index == selected
			hovered:  index == hovered
			leading:  start < 0.5 && strip_start < 0.5
		}
		out << tab_bar_tab_element(config, item, frames[index], look, horizontal, m, colors)
	}
	if dragged >= 0 {
		out << tab_bar_tab_element(config, config.items[dragged], frames[dragged], TabLook{
			selected: dragged == selected
			dragged:  true
		}, horizontal, m, colors)
	}
	return out
}

fn tab_bar_more_button(config TabBarConfig, frame Rect, m TabBarMetrics, colors TabBarColors) Element {
	open := config.state.menu.open
	side := math.min(m.more - 8, math.min(frame.width, frame.height) - 4)
	inner := rect(math.round((frame.width - side) / 2), math.round((frame.height - side) / 2),
		side, side)
	glyph := math.round(m.icon * 0.85)
	return Element{
		...button_view(component_part_id(config.id, 'more'), frame, BoxStyle{
			transparent: true
		}, [
			view('', inner, BoxStyle{
				bg:          colors.hover
				transparent: !open
				radius:      m.radius
			}, [
				tab_bar_symbol('chevron.down', rect(math.round((side - glyph) / 2), math.round((side - glyph) / 2),
					glyph, glyph), if open { colors.active } else { colors.fg }),
			]),
		])
		action_id:           dropdown_menu_toggle_action(tab_bar_menu_id(config.id))
		key:                 'more'
		tooltip:             'All tabs'
		cursor:              cursor_pointing_hand
		accessibility_label: 'All tabs'
		accessibility_value: if open { 'expanded' } else { 'collapsed' }
	}
}

fn tab_bar_slot(frame Rect, children []Element, key string) Element {
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		key: key
	}
}

// tab_bar draws a row (or, beside its content, a column) of tabs in one of
// GPUI Kit's variants, with icons, badges, close buttons, disabled tabs,
// application elements at either end, and a menu of all tabs. Tabs that do
// not fit scroll in tab_bar_scroll_id(id). It is controlled: pass events to
// tab_bar_update and keys to tab_bar_key, store the state they return and
// rebuild.
pub fn tab_bar(config TabBarConfig) !Element {
	layout := tab_bar_layout(config)!
	horizontal := layout.horizontal
	m := tab_bar_metrics(config.variant, config.size, horizontal)
	colors := tab_bar_colors(config.theme)
	thickness := if horizontal { config.frame.height } else { config.frame.width }
	length := if horizontal { config.frame.width } else { config.frame.height }
	mut children := []Element{}
	if config.variant in [.tab, .underline] {
		children << tab_bar_line(tab_bar_place(config.position, 0, thickness - 1, length, 1,
			thickness), colors.border, 'edge')
	}
	if config.prefix.len > 0 {
		children << tab_bar_slot(layout.prefix, config.prefix, 'prefix')
	}
	contents := tab_bar_strip_children(config, layout, m, colors)
	if layout.scrolls {
		fill := tab_bar_strip_fill(config.variant, colors)
		children << Element{
			...scroll_with_mode(tab_bar_scroll_id(config.id), layout.strip, fill, if horizontal {
				ScrollMode.horizontal_only
			} else {
				ScrollMode.vertical_only
			}, contents)
			box:            BoxStyle{
				bg:          fill
				transparent: true
			}
			// The strip scrolls by wheel, drag and reveal, without a scroller over
			// the tabs, as in GPUI Kit.
			disable_scroll: true
			key:            'strip'
		}
	} else {
		children << tab_bar_slot(layout.strip, contents, 'strip')
	}
	if config.menu && layout.more.width > 0 && layout.more.height > 0 {
		children << tab_bar_more_button(config, layout.more, m, colors)
	}
	if config.suffix.len > 0 {
		children << tab_bar_slot(layout.suffix, config.suffix, 'suffix')
	}
	return component_finish(Element{
		...view(config.id, config.frame, tab_bar_box(config.variant, colors, m), children)
		accessibility_role:  'tablist'
		accessibility_label: config.accessibility_label
	})
}
