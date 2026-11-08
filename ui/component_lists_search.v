// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// A searchable list after GPUI Kit's searchable List and the searchable_list
// module behind Select and Combobox. As upstream, the default match is a
// case-insensitive substring of the title, a section whose title matches
// stays, and a new query moves the highlight to the first result. The fuzzy
// matcher, the controlled state and the rendering are new UI2 code. See
// third_party/gpui-kit.
module ui2

import math

pub enum ListMatchMode {
	substring // The query, ignoring case, somewhere in the text: GPUI Kit's match.
	fuzzy     // The query's characters in order, not necessarily adjacent.
}

// ListMatchRange is a run of matched characters: rune offsets, end excluded.
pub struct ListMatchRange {
pub:
	start int
	end   int
}

// ListMatch is how well a query matched a text and which characters it matched,
// for applications that sort by score or draw their own highlighting.
pub struct ListMatch {
pub:
	score  int // Higher is better: earlier, at word starts, fewer gaps.
	ranges []ListMatchRange
}

fn list_lower_runes(text string) []rune {
	mut out := []rune{cap: text.len}
	for r in text.runes() {
		out << r.to_lower()
	}
	return out
}

fn list_word_rune(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`) || r >= 0x80
}

// list_word_start reports whether position starts a word: the text's start, or
// right after a space or punctuation.
fn list_word_start(text []rune, position int) bool {
	return position == 0 || !list_word_rune(text[position - 1])
}

fn list_substring_at(text []rune, query []rune) int {
	if query.len > text.len {
		return -1
	}
	for start in 0 .. text.len - query.len + 1 {
		mut found := true
		for offset, r in query {
			if text[start + offset] != r {
				found = false
				break
			}
		}
		if found {
			return start
		}
	}
	return -1
}

// list_match matches a query against a text, ignoring case and the query's
// surrounding spaces; an empty query matches everything. Substring mode wants
// the query as one run; fuzzy mode takes it as a run where it can and otherwise
// as its characters in order (spaces in the query are skipped), so `gtc`
// matches "GPUI Toolkit Core". It returns none when the text does not match.
pub fn list_match(query string, text string, mode ListMatchMode) ?ListMatch {
	needle := list_lower_runes(query.trim_space())
	if needle.len == 0 {
		return ListMatch{}
	}
	haystack := list_lower_runes(text)
	start := list_substring_at(haystack, needle)
	if start >= 0 {
		bonus := if start == 0 {
			60
		} else if list_word_start(haystack, start) {
			30
		} else {
			0
		}
		return ListMatch{
			score:  1000 + bonus - math.min(start, 100)
			ranges: [ListMatchRange{start, start + needle.len}]
		}
	}
	if mode == .substring {
		return none
	}
	mut positions := []int{cap: needle.len}
	mut cursor := 0
	for r in needle {
		if r == ` ` || r == `\t` {
			continue
		}
		for cursor < haystack.len && haystack[cursor] != r {
			cursor++
		}
		if cursor >= haystack.len {
			return none
		}
		positions << cursor
		cursor++
	}
	if positions.len == 0 {
		return ListMatch{}
	}
	mut score := 0
	mut ranges := []ListMatchRange{}
	for index, position in positions {
		score += 10
		if list_word_start(haystack, position) {
			score += 20
		}
		if index > 0 && position == positions[index - 1] + 1 {
			score += 15
			ranges[ranges.len - 1] = ListMatchRange{ranges[ranges.len - 1].start, position + 1}
		} else {
			if index > 0 {
				score -= math.min(position - positions[index - 1] - 1, 10)
			}
			ranges << ListMatchRange{position, position + 1}
		}
	}
	return ListMatch{
		score:  score - math.min(positions[0], 20)
		ranges: ranges
	}
}

fn list_matches(query string, text string, mode ListMatchMode) bool {
	if text.len == 0 {
		return false
	}
	list_match(query, text, mode) or { return false }
	return true
}

// list_item_matches reports whether a row matches a query by its title or its
// description. Separators never match.
pub fn list_item_matches(item ListItem, query string, mode ListMatchMode) bool {
	if item.kind != .item {
		return false
	}
	if query.trim_space().len == 0 {
		return true
	}
	return list_matches(query, item.title, mode) || list_matches(query, item.description, mode)
}

// list_filter keeps the rows that match a query, in their order. A section
// whose title contains the query keeps all its rows (titles are matched as
// substrings in either mode: two letters in order would match most of them);
// other sections keep their matching rows and are dropped when none match.
// Separators go while a query is active. An empty query keeps everything as it
// is.
pub fn list_filter(sections []ListSection, query string, mode ListMatchMode) []ListSection {
	if query.trim_space().len == 0 {
		return sections
	}
	mut out := []ListSection{}
	for section in sections {
		whole := section.title.len > 0 && list_matches(query, section.title, .substring)
		items := section.items.filter(it.kind == .item
			&& (whole || list_item_matches(it, query, mode)))
		if items.len > 0 {
			out << ListSection{
				...section
				items: items
			}
		}
	}
	return out
}

pub struct SearchableListConfig {
pub:
	id          string
	frame       Rect
	query       string // Controlled: store what searchable_list_update returns and rebuild.
	placeholder string = 'Search…'
	items       []ListItem
	sections    []ListSection
	state       ListState
	selection   ListSelectionMode = .single
	match_mode  ListMatchMode     = .substring
	// filter matches the rows against query. Turn it off when the application
	// searches itself (a server query, say) and passes only the results, which
	// is what GPUI Kit's perform_search hook is for.
	filter            bool = true
	check_icon        bool = true
	loading           bool
	empty_title       string = 'No results'
	empty_description string // Defaults to naming the query.
	// offset and virtualize work as in ListConfig, for the scroll
	// searchable_list_scroll_id(id).
	offset              f64
	virtualize          bool
	overscan            int = 3
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// SearchableListStep is what an event or key did to a searchable list: the
// query and state to store, and whether a row was confirmed, a row action
// pressed or the list cancelled.
pub struct SearchableListStep {
pub:
	query     string
	state     ListState
	confirmed bool     // A row was chosen: a click (single), or Enter.
	secondary bool     // Chosen with Cmd/Ctrl+Enter.
	cancelled bool     // Escape with an empty query.
	item      ListItem // The row chosen or toggled, or whose action was pressed.
	action    string   // The id of the row action pressed; empty otherwise.
	// reveal asks to scroll the highlighted row into view: pass
	// list_reveal_offset(searchable_list_list_config(config), step.state.active)
	// to scroll_to_offset(searchable_list_scroll_id(id), ...).
	reveal bool
	// sync_field is set when the query changed other than by typing (the clear
	// button, Escape): put it back with set_text(searchable_list_field_id(id),
	// step.query), and focus the field again.
	sync_field bool
}

fn searchable_list_search_id(id string) string {
	return component_part_id(id, 'search')
}

// searchable_list_field_id is the id of the search field, for text(), set_text()
// and focus(), and the action it emits on every edit.
pub fn searchable_list_field_id(id string) string {
	return input_group_field_id(searchable_list_search_id(id))
}

pub fn searchable_list_list_id(id string) string {
	return component_part_id(id, 'list')
}

// searchable_list_scroll_id is the id of the scroll the results move in.
pub fn searchable_list_scroll_id(id string) string {
	return list_scroll_id(searchable_list_list_id(id))
}

// searchable_list_results is the sections the list shows for its query.
pub fn searchable_list_results(config SearchableListConfig) ![]ListSection {
	sections := list_config_sections(ListConfig{
		id:       config.id
		items:    config.items
		sections: config.sections
	})!
	return if config.filter {
		list_filter(sections, config.query, config.match_mode)
	} else {
		sections
	}
}

struct SearchableListGeometry {
	search  Rect
	divider Rect
	results Rect
}

fn searchable_list_geometry(config SearchableListConfig) SearchableListGeometry {
	m := component_metrics(config.size)
	width := config.frame.width
	height := config.frame.height
	pad := m.padding
	search_height := math.min(m.height, math.max(height - 2 * pad, 0))
	search := rect(pad, pad, math.max(width - 2 * pad, 0), search_height)
	divider_y := math.min(search.y + search.height + pad, height)
	results_y := math.min(divider_y + 1, height)
	return SearchableListGeometry{
		search:  search
		divider: rect(0, divider_y, width, results_y - divider_y)
		results: rect(0, results_y, width, height - results_y)
	}
}

fn searchable_list_search_config(config SearchableListConfig) InputGroupConfig {
	return InputGroupConfig{
		id:                  searchable_list_search_id(config.id)
		frame:               searchable_list_geometry(config).search
		text:                config.query
		placeholder:         config.placeholder
		addons:              [
			InputGroupAddon{
				id:                  'search'
				kind:                .icon
				icon:                'magnifyingglass'
				accessibility_label: 'Search'
			},
		]
		clearable:           true
		accessibility_label: if config.accessibility_label.len > 0 {
			'Search ${config.accessibility_label}'
		} else {
			'Search'
		}
		size:                config.size
		theme:               config.theme
	}
}

// searchable_list_list_config is the ListConfig of the results: the filtered
// rows, in the part of the frame below the search field. Pass it to
// list_reveal_offset and list_visible_range.
pub fn searchable_list_list_config(config SearchableListConfig) !ListConfig {
	query := config.query.trim_space()
	return ListConfig{
		id:                  searchable_list_list_id(config.id)
		frame:               searchable_list_geometry(config).results
		sections:            searchable_list_results(config)!
		state:               config.state
		selection:           config.selection
		check_icon:          config.check_icon
		loading:             config.loading
		empty_title:         if query.len == 0 { 'No items' } else { config.empty_title }
		empty_description:   if config.empty_description.len > 0 || query.len == 0 {
			config.empty_description
		} else {
			'Nothing matches “${query}”.'
		}
		empty_icon:          if query.len == 0 { 'tray' } else { 'magnifyingglass' }
		offset:              config.offset
		virtualize:          config.virtualize
		overscan:            config.overscan
		bordered:            false
		accessibility_label: config.accessibility_label
		size:                config.size
		theme:               config.theme
	}
}

// searchable_list_query_state is the state after the query changes to query:
// the highlight on the first result, as GPUI Kit moves it, and the selection
// kept.
pub fn searchable_list_query_state(config SearchableListConfig, query string) ListState {
	next := SearchableListConfig{
		...config
		query: query
	}
	list_config := searchable_list_list_config(next) or { return config.state }
	model := list_model(list_config) or { return config.state }
	order := model.order()
	return ListState{
		...config.state
		active:  if order.len > 0 { order[0] } else { '' }
		anchor:  ''
		hovered: ''
	}
}

fn searchable_list_query_step(config SearchableListConfig, query string, refill bool) SearchableListStep {
	return SearchableListStep{
		query:      query
		state:      searchable_list_query_state(config, query)
		reveal:     true
		sync_field: refill
	}
}

// searchable_list_choose chooses the highlighted row, from Enter or the field's
// Return: in single mode it becomes the selection and is confirmed; in multiple
// mode it is toggled in or out.
fn searchable_list_choose(config SearchableListConfig, model ListModel, secondary bool) ?SearchableListStep {
	order := model.order()
	if config.state.active !in order {
		return none
	}
	item := model.find(config.state.active) or { return none }
	match config.selection {
		.multiple {
			return SearchableListStep{
				query: config.query
				state: ListState{
					...config.state
					selected: if item.id in config.state.selected {
						config.state.selected.filter(it != item.id)
					} else {
						list_union(config.state.selected, [item.id])
					}
					anchor:   item.id
				}
				item:  item
			}
		}
		.single {
			return SearchableListStep{
				query:     config.query
				state:     ListState{
					...config.state
					selected: [item.id]
					anchor:   item.id
				}
				confirmed: true
				secondary: secondary
				item:      item
			}
		}
		.none {
			return SearchableListStep{
				query:     config.query
				state:     config.state
				confirmed: true
				secondary: secondary
				item:      item
			}
		}
	}
}

fn searchable_list_from_list(config SearchableListConfig, step ListStep) SearchableListStep {
	return SearchableListStep{
		query:     config.query
		state:     step.state
		confirmed: step.confirmed
		secondary: step.secondary
		cancelled: step.cancelled
		item:      step.item
		action:    step.action
		reveal:    step.reveal
	}
}

// searchable_list_update applies an event from on_event: an edit of the search
// field (field_text is what it now holds: pass text(searchable_list_field_id(id))),
// Return in it (chooses the highlighted row), its clear button, and presses and
// hovers on the rows. A press chooses a row in single mode and toggles it in
// multiple mode. It returns none for events that are not the list's or change
// nothing.
pub fn searchable_list_update(config SearchableListConfig, event string, field_text string) ?SearchableListStep {
	search := searchable_list_search_config(config)
	if request := input_group_event(search, event) {
		match request.kind {
			.change {
				if field_text == config.query {
					return none
				}
				return searchable_list_query_step(config, field_text, false)
			}
			.clear {
				return searchable_list_query_step(config, '', true)
			}
			.submit {
				list_config := searchable_list_list_config(config) or { return none }
				model := list_model(list_config) or { return none }
				return searchable_list_choose(config, model, false)
			}
			.addon {
				return none
			}
		}
	}
	list_config := searchable_list_list_config(config) or { return none }
	model := list_model(list_config) or { return none }
	modifiers := ListModifiers{
		toggle: config.selection == .multiple
	}
	step := list_update_model(list_config, model, event, modifiers) or { return none }
	return searchable_list_from_list(config, step)
}

// searchable_list_key moves the highlight from on_key_event while the search
// field keeps focus: Up and Down (wrapping) and Page Up and Page Down. Enter
// chooses the highlighted row, and Escape clears the query or, when it is
// already empty, reports cancelled. Home, End and the other keys stay with the
// field. Consume the key whenever a step comes back.
pub fn searchable_list_key(config SearchableListConfig, event KeyEvent) ?SearchableListStep {
	if event.alt {
		return none
	}
	list_config := searchable_list_list_config(config) or { return none }
	model := list_model(list_config) or { return none }
	command := event.cmd || event.ctrl
	match event.code {
		.escape {
			if command || event.shift {
				return none
			}
			if config.query.len > 0 {
				return searchable_list_query_step(config, '', true)
			}
			step := list_key_model(list_config, model, event, false) or { return none }
			return searchable_list_from_list(config, step)
		}
		.enter, .kp_enter {
			if event.shift {
				return none
			}
			return searchable_list_choose(config, model, command)
		}
		.up, .down, .page_up, .page_down {
			step := list_key_model(list_config, model, event, false) or { return none }
			return searchable_list_from_list(config, step)
		}
		else {
			return none
		}
	}
}

// searchable_list puts a search field (an input_group with a search icon and a
// clear button) above a list of the rows that match its query, with an empty
// state when nothing does. Arrow keys move the highlight while the field keeps
// focus: route on_key_event to searchable_list_key and every event to
// searchable_list_update.
pub fn searchable_list(config SearchableListConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	geometry := searchable_list_geometry(config)
	theme := config.theme
	field := input_group(searchable_list_search_config(config))!
	results := list(searchable_list_list_config(config)!)!
	return component_finish(Element{
		...view(config.id, config.frame, component_box(theme.background, theme.border,
			component_metrics(config.size).radius), [
			Element{
				...field
				key: 'search'
			},
			Element{
				...view('', geometry.divider, BoxStyle{ bg: theme.border }, []Element{})
				key: 'divider'
			},
			Element{
				...results
				key: 'results'
			},
		])
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}
