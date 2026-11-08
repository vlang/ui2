// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/base/src/pagination.rs. The controlled state
// and page-window algorithm are ported to V; rendering, bounded allocation,
// and action decoding are new UI2 implementations. See third_party/gpui-kit.
module ui2

import math

pub const pagination_max_visible_pages = 100

pub enum PaginationItemKind {
	page
	ellipsis
}

// Ellipses describe a half-open range [start, end) of hidden page numbers.
pub struct PaginationItem {
pub:
	kind  PaginationItemKind
	page  int
	start int
	end   int
}

// Private fields ensure every state is normalized, including its zero value.
pub struct PaginationState {
	page     int = 1
	pages    int = 1
	visible  int = 5
	disabled bool
}

pub fn pagination_state(current_page int, total_pages int) PaginationState {
	pages := if total_pages > 0 { total_pages } else { 1 }
	page := if current_page < 1 {
		1
	} else if current_page > pages {
		pages
	} else {
		current_page
	}
	return PaginationState{
		page:  page
		pages: pages
	}
}

pub fn (state PaginationState) current_page() int {
	return state.page
}

pub fn (state PaginationState) total_pages() int {
	return state.pages
}

pub fn (state PaginationState) is_disabled() bool {
	return state.disabled
}

pub fn (state PaginationState) with_disabled(disabled bool) PaginationState {
	return PaginationState{
		...state
		disabled: disabled
	}
}

// Bound rendering work even if the dataset has billions of pages. The cap
// applies to requested visible pages, not to total_pages or navigation.
pub fn (state PaginationState) with_visible_pages(visible int) PaginationState {
	return PaginationState{
		...state
		visible: if visible < 5 {
			5
		} else if visible > pagination_max_visible_pages {
			pagination_max_visible_pages
		} else {
			visible
		}
	}
}

// request_page returns a proposed new value; it never mutates application state.
pub fn (state PaginationState) request_page(page int) ?int {
	if state.disabled || page == state.page || page < 1 || page > state.pages {
		return none
	}
	return page
}

pub fn (state PaginationState) previous_page() ?int {
	if state.disabled || state.page <= 1 {
		return none
	}
	return state.page - 1
}

pub fn (state PaginationState) next_page() ?int {
	if state.disabled || state.page >= state.pages {
		return none
	}
	return state.page + 1
}

pub fn (state PaginationState) items() []PaginationItem {
	if state.pages <= 1 {
		return []PaginationItem{}
	}
	mut items := []PaginationItem{}
	if state.pages <= state.visible {
		for page in 1 .. state.pages + 1 {
			items << PaginationItem{ page: page }
		}
		return items
	}
	items << PaginationItem{ page: 1 }
	side := (state.visible - 3) / 2
	start := if state.page <= side + 1 {
		2
	} else if state.page > state.pages - side - 1 {
		state.pages - side - 1
	} else {
		state.page - side
	}
	if start > 2 {
		items << PaginationItem{ kind: .ellipsis, start: 2, end: start }
	}
	end := if state.page >= state.pages - side {
		state.pages - 1
	} else if state.page <= side + 1 {
		side + 2
	} else {
		state.page + side
	}
	for page in start .. end + 1 {
		items << PaginationItem{ page: page }
	}
	if end < state.pages - 1 {
		items << PaginationItem{ kind: .ellipsis, start: end + 1, end: state.pages }
	}
	items << PaginationItem{ page: state.pages }
	return items
}

pub fn pagination_action_id(id string, page int) string {
	return component_part_id(id, 'page:${page}')
}

// pagination_page_from_action rejects unrelated, malformed, overflowing,
// disabled, out-of-range, and current-page actions. Use it in on_event and
// rebuild with pagination_state(new_page, state.total_pages()).
pub fn pagination_page_from_action(id string, state PaginationState, action string) ?int {
	part := component_action_part(id, action) or { return none }
	if !part.starts_with('page:') {
		return none
	}
	page := component_parse_index(part['page:'.len..], state.pages) or { return none }
	return state.request_page(page)
}

pub struct PaginationConfig {
pub:
	id      string
	frame   Rect
	state   PaginationState
	compact bool
	size    ComponentSize = .medium
	theme   ComponentTheme
}

// A disabled native button dims its title whatever color it was given, so the
// current page only gets the primary fill while the control is enabled.
fn pagination_button(config PaginationConfig, part string, text string, frame Rect, page int, enabled bool, selected bool) Element {
	highlighted := selected && enabled
	return Element{
		...button(component_part_id(config.id, part), text, frame, BoxStyle{
			bg:     if highlighted {
				config.theme.primary
			} else if selected {
				config.theme.border
			} else {
				config.theme.muted
			}
			radius: component_metrics(config.size).radius
		}, TextStyle{
			color: if highlighted {
				config.theme.primary_foreground
			} else if enabled {
				config.theme.foreground
			} else {
				config.theme.muted_foreground
			}
			size:  component_metrics(config.size).font_size
			align: .center
		})
		key:                 part
		action_id:           pagination_action_id(config.id, page)
		enabled:             enabled
		accessibility_label: if part == 'previous' {
			'Previous page'
		} else if part == 'next' {
			'Next page'
		} else {
			'Page ${page}'
		}
		accessibility_value: if selected { 'current' } else { '' }
	}
}

pub fn pagination(config PaginationConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	page_state := config.state
	metrics := component_metrics(config.size)
	items := if config.compact { []PaginationItem{} } else { page_state.items() }
	slots := items.len + 2
	gap := math.min(metrics.gap, config.frame.width / f64(slots * 2))
	width := math.min(metrics.height, (config.frame.width - gap * f64(slots - 1)) / f64(slots))
	height := math.min(metrics.height, config.frame.height)
	y := (config.frame.height - height) / 2
	mut x := (config.frame.width - width * f64(slots) - gap * f64(slots - 1)) / 2
	previous := page_state.previous_page() or { page_state.page }
	next := page_state.next_page() or { page_state.page }
	mut children := [pagination_button(config, 'previous', '‹', rect(x, y, width, height),
		previous, previous != page_state.page, false)]
	x += width + gap
	for item in items {
		frame := rect(x, y, width, height)
		if item.kind == .page {
			// The current page stays enabled: pagination_page_from_action already
			// ignores it, and a disabled button would be announced as dimmed.
			children << pagination_button(config, 'page:${item.page}', item.page.str(), frame,
				item.page, !page_state.disabled, item.page == page_state.page)
		} else {
			children << Element{
				...label('', '…', frame, TextStyle{
					color: config.theme.muted_foreground
					size:  metrics.font_size
					align: .center
				})
				key:                 'ellipsis:${item.start}:${item.end}'
				accessibility_label: 'Pages ${item.start} to ${item.end - 1}'
			}
		}
		x += width + gap
	}
	children << pagination_button(config, 'next', '›', rect(x, y, width, height), next,
		next != page_state.page, false)
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'navigation'
		accessibility_label: 'Pagination'
		accessibility_value: 'Page ${page_state.page} of ${page_state.pages}'
	})
}
