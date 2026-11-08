module ui2

import math

// Drawing for the themed tree_view in component_navigation2_tree.v.

struct TreeRowLook {
	selected bool
	active   bool
	hovered  bool
	dragged  bool // The row being dragged, left behind dimmed.
	target   bool // A drag would drop into this folder.
}

fn tree_view_guide_color(theme ComponentTheme) u32 {
	return popover_blend(theme.border, theme.background, 0.35)
}

fn tree_view_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

fn tree_view_centered(x f64, height f64, side f64) Rect {
	return rect(x, math.round((height - side) / 2), side, side)
}

// tree_view_checkbox draws a check box: a rounded square, filled with the
// primary color and marked with a check, or with a dash when its folder is
// partly checked.
fn tree_view_checkbox(side f64, check TableCheckState, enabled bool, theme ComponentTheme) []Element {
	on := check != .unchecked
	mut fill := if on { theme.primary } else { theme.background }
	mut ring := if on { theme.primary } else { theme.border }
	if !enabled {
		fill = popover_blend(fill, theme.background, 0.5)
		ring = popover_blend(ring, theme.background, 0.5)
	}
	mut marks := []Element{}
	if on {
		inset := math.round(side * 0.14)
		marks << tree_view_symbol(if check == .mixed { 'minus' } else { 'checkmark' }, rect(inset,
			inset, side - 2 * inset, side - 2 * inset), theme.primary_foreground)
	}
	return [view('', rect(0, 0, side, side), component_box(fill, ring, math.round(side / 4)),
		marks)]
}

fn tree_view_states(node TreeViewNode, look TreeRowLook, checkable bool) string {
	mut states := []string{}
	if look.selected {
		states << 'selected'
	}
	if tree_view_is_folder(node) {
		states << if node.expanded { 'expanded' } else { 'collapsed' }
	}
	if checkable {
		states << table_check_value(tree_view_check_state(node))
	}
	if node.loading {
		states << 'loading'
	}
	return states.join(', ')
}

fn tree_view_content_x(depth int, m TreeViewMetrics) f64 {
	return m.inner + f64(depth) * m.indent
}

fn tree_view_guides(depth int, height f64, m TreeViewMetrics, theme ComponentTheme) []Element {
	mut out := []Element{cap: depth}
	color := tree_view_guide_color(theme)
	for level in 0 .. depth {
		x := math.round(tree_view_content_x(level, m) + m.chevron / 2)
		out << Element{
			...view('', rect(x, 0, 1, height), BoxStyle{ bg: color }, []Element{})
			key: 'guide:${level}'
		}
	}
	return out
}

fn tree_view_row_element(config TreeViewConfig, entry TreeViewEntry, frame Rect, look TreeRowLook, m TreeViewMetrics, theme ComponentTheme) Element {
	node := entry.node
	enabled := node.enabled
	height := frame.height
	dim := !enabled || look.dragged
	fg := if dim {
		popover_blend(theme.muted_foreground, theme.background, 0.35)
	} else {
		theme.foreground
	}
	mut children := []Element{}
	if config.guides {
		children << tree_view_guides(entry.depth, height, m, theme)
	}
	mut x := tree_view_content_x(entry.depth, m)
	folder := tree_view_is_folder(node)
	if folder {
		disclosure := rect(x, 0, m.chevron, height)
		glyph := m.glyph
		children << Element{
			...button_view(tree_view_toggle_action(config.id, node.id), disclosure, BoxStyle{
				transparent: true
			}, [
				tree_view_symbol(if node.expanded { 'chevron.down' } else { 'chevron.right' },
					rect(math.round((m.chevron - glyph) / 2), math.round((height - glyph) / 2),
						glyph, glyph), if dim {
						fg
					} else {
						theme.muted_foreground
					}),
			])
			action_id:           if node.toggle_action_id.len > 0 {
				node.toggle_action_id
			} else {
				tree_view_toggle_action(config.id, node.id)
			}
			key:                 'toggle'
			enabled:             enabled
			accessibility_label: if node.expanded {
				'Collapse ${node.text}'
			} else {
				'Expand ${node.text}'
			}
			accessibility_value: if node.expanded { 'expanded' } else { 'collapsed' }
		}
	}
	x += m.chevron + m.gap / 2
	if config.checkable {
		check := tree_view_check_state(node)
		box_frame := tree_view_centered(x, height, m.check)
		children << Element{
			...button_view(tree_view_check_action(config.id, node.id), box_frame, BoxStyle{
				transparent: true
			}, tree_view_checkbox(m.check, check, enabled, theme))
			key:                 'check'
			enabled:             enabled
			accessibility_role:  'checkbox'
			accessibility_label: node.text
			accessibility_value: table_check_value(check)
		}
		x += m.check + m.gap
	}
	if config.row_content != unsafe { nil } {
		children << Element{
			...view('', rect(x, 0, math.max(frame.width - m.inner - x, 0), height), BoxStyle{
				transparent: true
			}, config.row_content(node, rect(0, 0, math.max(frame.width - m.inner - x, 0),
				height), look.selected))
			key: 'content'
		}
		return tree_view_row_finish(config, node, frame, look, m, theme, children)
	}
	icon := if node.expanded && node.expanded_icon.len > 0 { node.expanded_icon } else { node.icon }
	if icon.len > 0 {
		color := if dim {
			fg
		} else if folder {
			theme.primary
		} else {
			theme.muted_foreground
		}
		children << Element{
			...tree_view_symbol(icon, tree_view_centered(x, height, m.icon), color)
			key: 'icon'
		}
		x += m.icon + m.gap
	}
	mut right := frame.width - m.inner
	if node.trailing.len > 0 {
		wanted := math.ceil(measure_text_width(node.trailing, TextStyle{ size: m.small }))
		width := math.min(wanted, math.max(right - x, 0) / 2)
		right -= width
		children << Element{
			...label('', node.trailing, rect(right, 0, width, height), TextStyle{
				color: popover_blend(theme.muted_foreground, theme.background, if dim {
					0.35
				} else {
					0.0
				})
				size:  m.small
				align: .right
			})
			key: 'trailing'
		}
		right -= m.gap
	}
	children << Element{
		...label('', node.text, rect(x, 0, math.max(right - x, 0), height), TextStyle{
			color: fg
			size:  m.font
		})
		key: 'text'
	}
	return tree_view_row_finish(config, node, frame, look, m, theme, children)
}

// tree_view_row_finish fills a row for its state and makes it the node's
// button.
fn tree_view_row_finish(config TreeViewConfig, node TreeViewNode, frame Rect, look TreeRowLook, m TreeViewMetrics, theme ComponentTheme, children []Element) Element {
	enabled := node.enabled
	fill := if look.target {
		BoxStyle{
			bg:            list_selected_fill(theme)
			radius:        m.radius
			border_color:  theme.primary
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}
	} else if !enabled {
		BoxStyle{
			transparent: true
		}
	} else if look.selected {
		BoxStyle{
			bg:     list_selected_fill(theme)
			radius: m.radius
		}
	} else if look.active || look.hovered {
		BoxStyle{
			bg:     theme.muted
			radius: m.radius
		}
	} else {
		BoxStyle{
			transparent: true
			radius:      m.radius
		}
	}
	box := if look.active && !look.selected && enabled && !look.target {
		BoxStyle{
			...fill
			border_color:  theme.primary
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}
	} else {
		fill
	}
	row := button_view(tree_view_row_action(config.id, node.id), frame, box, children)
	return Element{
		...row
		action_id:           if node.action_id.len > 0 { node.action_id } else { row.id }
		key:                 'node:' + node.id
		enabled:             enabled
		hoverable:           enabled
		draggable:           config.reorderable && enabled
		menu:                node.menu
		accessibility_role:  'treeitem'
		accessibility_label: if node.accessibility_label.len > 0 {
			node.accessibility_label
		} else {
			node.text
		}
		accessibility_value: tree_view_states(node, look, config.checkable)
	}
}

fn tree_view_loading_row(config TreeViewConfig, entry TreeViewEntry, frame Rect, m TreeViewMetrics, theme ComponentTheme) Element {
	mut children := []Element{}
	if config.guides {
		children << tree_view_guides(entry.depth, frame.height, m, theme)
	}
	x := tree_view_content_x(entry.depth, m) + m.chevron + m.gap / 2
	side := m.icon
	children << loading_spinner(
		id:    component_part_id(config.id, 'loading:' + entry.node.id.bytes().hex())
		frame: tree_view_centered(x, frame.height, side)
		size:  .small
		theme: theme
	) or { view('', Rect{}, BoxStyle{ transparent: true }, []Element{}) }
	children << label('', 'Loading…', rect(x + side + m.gap, 0, math.max(frame.width - x - side - m.gap - m.inner,
		0), frame.height), TextStyle{
		color: theme.muted_foreground
		size:  m.small
	})
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		key:                 'loading:' + entry.node.id
		accessibility_role:  'status'
		accessibility_label: 'Loading ${entry.node.text}'
	}
}

// tree_view_drop_marker is the line a drag would drop before or after a row
// on, starting where that row's content does.
fn tree_view_drop_marker(model TreeViewModel, move TreeViewMove, row_width f64, theme ComponentTheme) ?Element {
	if move.position == .inside {
		return none
	}
	index := model.entry_index(move.target)
	if index < 0 {
		return none
	}
	m := model.metrics
	entry := model.entries[index]
	y := if move.position == .before {
		model.layout.item_start(index)
	} else {
		model.layout.item_end(index)
	}
	x := m.padding + tree_view_content_x(entry.depth, m) + m.chevron
	return Element{
		...view('', rect(x, math.round(y - 1), math.max(row_width + m.padding - x, 0), 2),
			BoxStyle{
				bg:     theme.primary
				radius: 1
			}, []Element{})
		key: 'drop'
	}
}

// tree_view_drag_ghost is the row being dragged, following the pointer.
fn tree_view_drag_ghost(config TreeViewConfig, model TreeViewModel, row_width f64, theme ComponentTheme) ?Element {
	drag := config.state.drag
	if !config.reorderable || !drag.active {
		return none
	}
	index := model.entry_index(drag.node)
	if index < 0 {
		return none
	}
	m := model.metrics
	node := model.entries[index].node
	layout := model.layout
	y := math.min(math.max(layout.item_start(index) + drag.y - drag.start_y, 0), math.max(layout.total() - m.row,
		0))
	icon := if node.expanded && node.expanded_icon.len > 0 { node.expanded_icon } else { node.icon }
	text_width := math.ceil(measure_text_width(node.text, TextStyle{ size: m.font }))
	icon_width := if icon.len > 0 { m.icon + m.gap } else { 0.0 }
	width := math.min(m.inner * 2 + icon_width + text_width, row_width)
	x := m.padding + math.min(tree_view_content_x(model.entries[index].depth, m) + m.chevron,
		math.max(row_width - width, 0))
	mut children := []Element{}
	if icon.len > 0 {
		children << tree_view_symbol(icon, tree_view_centered(m.inner, m.row, m.icon), theme.primary)
	}
	children << label('', node.text, rect(m.inner + icon_width, 0, math.max(width - m.inner * 2 - icon_width,
		0), m.row), TextStyle{
		color: theme.foreground
		size:  m.font
	})
	return Element{
		...view('', rect(x, y, width, m.row), BoxStyle{
			bg:            theme.background
			radius:        m.radius
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        component_card_shadow()
		}, children)
		key: 'ghost'
	}
}

fn tree_view_build_rows(config TreeViewConfig, model TreeViewModel, viewport Rect, theme ComponentTheme) []Element {
	m := model.metrics
	layout := model.layout
	span := if config.virtualize {
		layout.range(viewport.height, config.offset, config.overscan)
	} else {
		VirtualListRange{
			start: 0
			end:   layout.count
		}
	}
	row_width := tree_view_row_width(model, viewport)
	drop := tree_view_drop_preview(config, model)
	dragged := if config.reorderable && config.state.drag.active {
		config.state.drag.node
	} else {
		''
	}
	mut rows := []Element{cap: span.len() + 4}
	rows << Element{
		...view('', rect(0, 0, 0, layout.total()), BoxStyle{ transparent: true }, []Element{})
		key: virtual_list_extent_key
	}
	for index in span.start .. span.end {
		entry := model.entries[index]
		frame := rect(m.padding, layout.item_start(index), row_width, m.row)
		if entry.kind == .loading {
			rows << tree_view_loading_row(config, entry, frame, m, theme)
			continue
		}
		node := entry.node
		look := TreeRowLook{
			selected: config.selection != .none && node.selected
			active:   node.id == config.state.active
			hovered:  node.id == config.state.hovered && dragged.len == 0
			dragged:  node.id == dragged
			target:   if target := drop {
				target.position == .inside && target.target == node.id
			} else {
				false
			}
		}
		rows << tree_view_row_element(config, entry, frame, look, m, theme)
	}
	if target := drop {
		if marker := tree_view_drop_marker(model, target, row_width, theme) {
			rows << marker
		}
	}
	if ghost := tree_view_drag_ghost(config, model, row_width, theme) {
		rows << ghost
	}
	return rows
}

fn tree_view_empty_element(config TreeViewConfig, frame Rect, m TreeViewMetrics, theme ComponentTheme) Element {
	return Element{
		...label('', config.empty_title, frame, TextStyle{
			color: theme.muted_foreground
			size:  m.font
			align: .center
		})
		key:                'empty'
		accessibility_role: 'status'
	}
}

// tree_view_themed_element draws a tree_view the GPUI Kit way. Rows scroll in
// tree_view_scroll_id(id) once they are taller than the frame.
fn tree_view_themed_element(config TreeViewConfig) !Element {
	component_validate_id(config.id)!
	model := tree_view_model(config)!
	theme := config.theme or { ComponentTheme{} }
	viewport := tree_view_viewport(config)
	mut children := []Element{}
	if model.entries.len == 0 {
		children << tree_view_empty_element(config, viewport, model.metrics, theme)
	} else {
		rows := tree_view_build_rows(config, model, viewport, theme)
		// Content that fits does not scroll: a Scroll element would add room
		// below it to scroll into.
		if model.layout.total() <= viewport.height + 0.5 {
			children << Element{
				...view('', viewport, BoxStyle{ transparent: true }, rows)
				key: 'rows'
			}
		} else {
			children << Element{
				...scroll(tree_view_scroll_id(config.id), viewport, theme.background, rows)
				box: BoxStyle{
					bg:          theme.background
					transparent: true
				}
				key: 'scroll'
			}
		}
	}
	box := if config.bordered {
		component_box(theme.background, theme.border, component_metrics(config.size).radius)
	} else {
		BoxStyle{
			transparent: true
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_role:  'tree'
		accessibility_label: config.accessibility_label
	})
}
