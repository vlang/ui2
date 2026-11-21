// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Settings after GPUI Kit's Settings, SettingPage, SettingGroup, SettingItem
// and SettingField. Three rules are adapted from crates/component/src/setting/:
// the selection kept while searching (SettingsFilter::selected_index in
// settings.rs), what a search matches (SettingItem::is_match in item.rs: the
// title, description and keywords ignoring case, keywords alone for a custom
// row; here every word of the query has to match) and Reset all touching only
// the items a search shows (SettingGroup::reset in group.rs). The controlled
// model, layout, rendering and action decoding are new UI2 code. See
// third_party/gpui-kit. This file holds the model, matching and the decoders;
// layout is in component_settings_layout.v and rendering in
// component_settings_view.v.
module ui2

import math

// SettingValue is one setting's value. A switch or checkbox holds a bool, a
// number input or slider an f64, a text input a string and a dropdown the
// string value of the chosen option. Custom items may hold any of them.
pub type SettingValue = bool | f64 | string

// SettingChange is a value to store: values[change.key] = change.value.
pub struct SettingChange {
pub:
	key   string
	value SettingValue
	reset bool // The change puts the item back to its default.
}

// SettingFieldKind is the control an item shows.
pub enum SettingFieldKind {
	switch   // bool
	checkbox // bool
	dropdown // string: the value of one of `options`
	input    // string
	number   // f64, typed or stepped (number_input)
	slider   // f64 between min and max
	button   // An action, no value: SettingsStep.action names the item.
	custom   // Elements the application builds with `content`.
}

// SettingLayout places an item's control beside its title (horizontal) or
// below it (vertical). Narrow settings stack every item vertically.
pub enum SettingLayout {
	horizontal
	vertical
}

// SettingsGroupVariant is the surface a group's items sit on, after GPUI
// Kit's GroupBoxVariant.
pub enum SettingsGroupVariant {
	normal  // Directly on the page.
	outline // A bordered card.
	fill    // A filled card.
}

// SettingOption is one choice of a dropdown.
pub struct SettingOption {
pub:
	value string
	label string // Defaults to value.
}

// SettingContentOptions describe the frame custom content is built for, as
// GPUI Kit's RenderOptions. Content frames are relative to that frame.
pub struct SettingContentOptions {
pub:
	key      string
	width    f64
	height   f64
	disabled bool // Disable the content's own controls: the settings cannot.
	layout   SettingLayout
	size     ComponentSize
	theme    ComponentTheme
}

// SettingContentFn builds custom content: a custom item's control, a whole
// custom row (an item without title or description) or a page title suffix.
pub type SettingContentFn = fn (options SettingContentOptions) []Element

// SettingItem is one setting. Items are named by `key`, unique across the
// settings, which is also the key of its value in SettingsConfig.values.
pub struct SettingItem {
pub:
	key   string
	title string
	// description is plain text. Simple Markdown (emphasis, code spans and
	// links) is shown as its plain text; see settings_plain_text.
	description string
	keywords    []string // Extra search terms; never shown.
	kind        SettingFieldKind
	layout      SettingLayout
	disabled    bool // Dims the row and disables the control.
	// default_value makes the item resettable: a reset button shows while the
	// value differs from it, and the page's Reset all restores it.
	default_value  ?SettingValue
	options        []SettingOption // dropdown
	min            ?f64            // number; required for a slider
	max            ?f64            // number; required for a slider
	step           f64 = 1  // number and slider; zero makes a slider continuous
	precision      int = -1 // number and slider: decimals, -1 for as many as needed
	unit           string // Written after a slider's value, such as '%' or ' px'.
	placeholder    string // input and number
	secure         bool   // input: password entry
	button_text    string // button
	button_variant ButtonVariant
	// content builds a custom item. With a title or description it is the
	// control beside them, field_width wide; without either it spans the row.
	content        SettingContentFn = unsafe { nil }
	content_height f64
	field_width    f64 // The control's width in a horizontal row; zero picks one per kind.
}

// SettingGroup is a titled (or untitled) set of items on one surface.
pub struct SettingGroup {
pub:
	title       string
	description string
	items       []SettingItem
	variant     ?SettingsGroupVariant // Overrides SettingsConfig.group_variant.
	// footer is small muted text below the group's surface. It follows the
	// group's search visibility but does not match a search by itself.
	footer string
}

// SettingPage is one entry of the navigation and the groups it shows.
pub struct SettingPage {
pub:
	id           string // Stable identity, unique among the pages; defaults to title.
	title        string
	icon         string // A symbol name (see symbol_known) shown in the navigation.
	description  string
	groups       []SettingGroup
	default_open bool // The navigation lists the page's groups from the start.
	resettable   bool = true // Offer Reset all while a shown item differs from its default.
	// title_suffix builds elements after the page title, such as a help
	// button, in a frame title_suffix_width wide and one control high.
	title_suffix       SettingContentFn = unsafe { nil }
	title_suffix_width f64
}

// SettingsState is everything about the settings the application stores
// besides the values.
pub struct SettingsState {
pub:
	page     string // Id of the selected page; empty selects the first.
	group    int = -1 // Index in the page's groups of the selected group, or -1.
	query    string   // The search text.
	expanded []string // Pages whose groups the navigation lists.
	// menu is the key of the dropdown item whose menu is open, and
	// menu_state that menu's highlight.
	menu       string
	menu_state DropdownMenuState
	// draft holds what is typed into the number item draft_key until it is
	// committed, so a value is stored only while the text is a valid number.
	draft_key string
	draft     string
}

pub struct SettingsConfig {
pub:
	id     string
	frame  Rect
	pages  []SettingPage
	values map[string]SettingValue // Missing keys use the item's default.
	state  SettingsState
	// group_variant is the surface of every group that does not set its own.
	group_variant SettingsGroupVariant
	nav_width     f64 = 240
	// transparent leaves the view's own surfaces unpainted, so what it sits on
	// shows through, as in a translucent modal.
	transparent        bool
	search_placeholder string = 'Search settings'
	empty_title        string = 'No matching settings'
	empty_description  string = 'Try another word, or clear the search.'
	reset_all_text     string = 'Reset all'
	// Items stack vertically while the page is at most stacked_width wide.
	stacked_width       f64           = 480
	accessibility_label string        = 'Settings'
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// SettingsTextFn reads the live text of a field: pass ui2.text.
pub type SettingsTextFn = fn (id string) string

// SettingsNumberFn reads the live value of a slider: pass ui2.slider_value.
pub type SettingsNumberFn = fn (id string) f64

// SettingsInput gives settings_update the backend's readers for the live
// values ui/ cannot read itself:
//
//     ui2.SettingsInput{ text: ui2.text, number: ui2.slider_value }
//
// The decoder only reads the field or slider the action came from.
pub struct SettingsInput {
pub:
	text   SettingsTextFn   = unsafe { nil }
	number SettingsNumberFn = unsafe { nil }
}

fn (input SettingsInput) read_text(id string) ?string {
	if voidptr(input.text) == unsafe { nil } {
		return none
	}
	return input.text(id)
}

fn (input SettingsInput) read_number(id string) ?f64 {
	if voidptr(input.number) == unsafe { nil } {
		return none
	}
	return input.number(id)
}

// SettingsStep is a decoded action: the state to store, the values to store,
// and what to do once the tree has been rebuilt.
pub struct SettingsStep {
pub:
	state   SettingsState
	changes []SettingChange
	action  string // Key of the button item that was pressed.
	// scroll asks for scroll_to_offset(scroll_id, scroll_to) after the
	// rebuild, to show a selected group or the top of a filtered page.
	scroll    bool
	scroll_id string
	scroll_to f64
	focus     string // An id to focus after the rebuild.
	// sync_id is a field whose text should become sync_text after the
	// rebuild (set_text), because what was typed was cleaned up.
	sync_id   string
	sync_text string
}

// apply stores the step's changes in values.
pub fn (step SettingsStep) apply(mut values map[string]SettingValue) {
	for change in step.changes {
		values[change.key] = change.value
	}
}

// ── Values ──────────────────────────────────────────────────────────

// setting_value_equal compares two values; numbers compare to within
// rounding, values of different types are different.
pub fn setting_value_equal(a SettingValue, b SettingValue) bool {
	match a {
		bool {
			if b is bool {
				return a == b
			}
		}
		f64 {
			if b is f64 {
				return math.abs(a - b) <= 1e-9 * math.max(math.max(math.abs(a), math.abs(b)),
					1)
			}
		}
		string {
			if b is string {
				return a == b
			}
		}
	}
	return false
}

// setting_bool reads a bool setting, false when it is missing or not a bool.
pub fn setting_bool(values map[string]SettingValue, key string) bool {
	value := values[key] or { return false }
	return if value is bool { value } else { false }
}

// setting_number reads a number setting, 0 when it is missing or not a number.
pub fn setting_number(values map[string]SettingValue, key string) f64 {
	value := values[key] or { return 0 }
	return if value is f64 { value } else { 0 }
}

// setting_string reads a string setting, '' when it is missing or not a string.
pub fn setting_string(values map[string]SettingValue, key string) string {
	value := values[key] or { return '' }
	return if value is string { value } else { '' }
}

// settings_defaults collects every item's default value, as the values an
// application starts from.
pub fn settings_defaults(pages []SettingPage) map[string]SettingValue {
	mut values := map[string]SettingValue{}
	for page in pages {
		for group in page.groups {
			for item in group.items {
				if value := item.default_value {
					values[item.key] = value
				}
			}
		}
	}
	return values
}

fn settings_zero_value(kind SettingFieldKind) SettingValue {
	return match kind {
		.switch, .checkbox { SettingValue(false) }
		.number, .slider { SettingValue(0.0) }
		else { SettingValue('') }
	}
}

// settings_item_value is the value an item shows: the stored one, else its
// default, else the zero value of its kind.
pub fn settings_item_value(values map[string]SettingValue, item SettingItem) SettingValue {
	if value := values[item.key] {
		return value
	}
	if value := item.default_value {
		return value
	}
	return settings_zero_value(item.kind)
}

fn settings_value_bool(value SettingValue) bool {
	return if value is bool { value } else { false }
}

fn settings_value_number(value SettingValue) f64 {
	return if value is f64 { value } else { 0 }
}

fn settings_value_string(value SettingValue) string {
	return if value is string { value } else { '' }
}

// settings_item_dirty reports whether an item has a default and its value
// differs from it, which is when it can be reset.
pub fn settings_item_dirty(values map[string]SettingValue, item SettingItem) bool {
	default := item.default_value or { return false }
	return !setting_value_equal(settings_item_value(values, item), default)
}

fn settings_option_label(option SettingOption) string {
	return if option.label.len > 0 { option.label } else { option.value }
}

// settings_number_text writes a number item's value with its precision, or
// with as many decimals as it needs.
fn settings_number_text(item SettingItem, value f64) string {
	if item.precision >= 0 {
		return number_input_format(value, item.precision)
	}
	return number_input_plain(value)
}

// settings_round rounds a slider's value to the decimals of its precision,
// or of its step, so stepping by 0.1 stores 0.3 rather than 0.30000000000000004.
fn settings_round(item SettingItem, value f64) f64 {
	places := if item.precision >= 0 {
		item.precision
	} else if item.step > 0 {
		number_input_decimal_places(item.step)
	} else {
		2
	}
	return number_input_parse(number_input_format(value, places)) or { value }
}

// ── Validation ──────────────────────────────────────────────────────

fn settings_page_id(page SettingPage) string {
	return if page.id.len > 0 { page.id } else { page.title }
}

fn settings_value_kind_ok(kind SettingFieldKind, value SettingValue) bool {
	return match kind {
		.switch, .checkbox { value is bool }
		.number, .slider { value is f64 }
		.dropdown, .input { value is string }
		.button { false }
		.custom { true }
	}
}

fn settings_validate_item(item SettingItem, mut keys map[string]bool) ! {
	has_default := if _ := item.default_value { true } else { false }
	needs_key := item.kind != .custom || has_default
	if item.key.trim_space().len == 0 {
		if needs_key {
			return error('setting `${item.title}` needs a key')
		}
	} else {
		if item.key in keys {
			return error('setting key `${item.key}` is used twice')
		}
		keys[item.key] = true
	}
	if item.kind != .custom && item.title.trim_space().len == 0 {
		return error('setting `${item.key}` needs a title')
	}
	if value := item.default_value {
		if !settings_value_kind_ok(item.kind, value) {
			return error('setting `${item.key}` has a default of the wrong type for a ${item.kind}')
		}
	}
	for value in [item.field_width, item.content_height, item.step] {
		if !component_finite(value) || value < 0 {
			return error('setting `${item.key}` sizes and step must be finite and non-negative')
		}
	}
	match item.kind {
		.dropdown {
			if item.options.len == 0 {
				return error('dropdown setting `${item.key}` has no options')
			}
			mut seen := map[string]bool{}
			for option in item.options {
				if option.value in seen {
					return error('dropdown setting `${item.key}` lists `${option.value}` twice')
				}
				seen[option.value] = true
			}
			if value := item.default_value {
				if settings_value_string(value) !in seen {
					return error('dropdown setting `${item.key}` defaults to a value it does not offer')
				}
			}
		}
		.number, .slider {
			number_input_validate(settings_number_config_base(item))!
			if item.kind == .slider {
				low := item.min or { return error('slider setting `${item.key}` needs a min') }
				high := item.max or { return error('slider setting `${item.key}` needs a max') }
				if high <= low {
					return error('slider setting `${item.key}` needs max above min')
				}
			}
		}
		.button {
			if item.button_text.trim_space().len == 0 {
				return error('button setting `${item.key}` needs button_text')
			}
		}
		.custom {
			if voidptr(item.content) == unsafe { nil } {
				return error('custom setting `${item.key}` needs content')
			}
		}
		else {}
	}
}

fn settings_validate(config SettingsConfig) ! {
	component_validate_id(config.id)!
	component_validate_frame(config.frame)!
	for value in [config.nav_width, config.stacked_width] {
		if !component_finite(value) || value < 0 {
			return error('settings widths must be finite and non-negative')
		}
	}
	mut page_ids := map[string]bool{}
	mut keys := map[string]bool{}
	for page in config.pages {
		pid := settings_page_id(page)
		if pid.trim_space().len == 0 {
			return error('setting pages need an id or a title')
		}
		if pid in page_ids {
			return error('setting page `${pid}` is listed twice')
		}
		page_ids[pid] = true
		if page.icon.len > 0 && !page.icon.contains('/') && !symbol_known(page.icon) {
			return error('setting page `${pid}` uses icon `${page.icon}`, which not every renderer can draw; pick a name from symbol_names()')
		}
		if !component_finite(page.title_suffix_width) || page.title_suffix_width < 0 {
			return error('setting page `${pid}` title suffix width must be finite and non-negative')
		}
		for group in page.groups {
			for item in group.items {
				settings_validate_item(item, mut keys)!
			}
		}
	}
}

// ── Search ──────────────────────────────────────────────────────────

fn settings_lower(source string) string {
	mut out := []rune{cap: source.len}
	for r in source.runes() {
		out << r.to_lower()
	}
	return out.string()
}

// settings_plain_text turns a description written in simple Markdown into
// the plain text the settings show and search: `**bold**`, `*italic*`,
// `__bold__`, `_italic_` and `~~struck~~` lose their markers, `code` its
// backticks, and [a link](url) keeps its text. Other text is unchanged, so
// plain descriptions (and an underscore inside a word) come through as is.
pub fn settings_plain_text(source string) string {
	runes := source.runes()
	mut out := []rune{cap: runes.len}
	mut i := 0
	for i < runes.len {
		r := runes[i]
		if r == `\\` && i + 1 < runes.len && runes[i + 1] in [`*`, `_`, `~`, `\``, `[`, `]`, `\\`] {
			out << runes[i + 1]
			i += 2
			continue
		}
		if r == `[` {
			if close := settings_link_end(runes, i) {
				out << runes[i + 1..close.text_end]
				i = close.end
				continue
			}
		}
		if r == `\`` {
			if end := settings_find_rune(runes, `\``, i + 1) {
				out << runes[i + 1..end]
				i = end + 1
				continue
			}
		}
		if r in [`*`, `_`, `~`] {
			mut marks := 1
			for i + marks < runes.len && runes[i + marks] == r {
				marks++
			}
			// A marker opens or closes emphasis when it is at a word edge; an
			// underscore inside snake_case stays.
			prev_rune := if i > 0 { runes[i - 1] } else { ` ` }
			next_rune := if i + marks < runes.len { runes[i + marks] } else { ` ` }
			inside_word := settings_word_rune(prev_rune) && settings_word_rune(next_rune)
			if !(r == `_` && inside_word) && (r != `~` || marks == 2) && marks <= 3
				&& !(settings_space_rune(prev_rune) && settings_space_rune(next_rune)) {
				i += marks
				continue
			}
			for _ in 0 .. marks {
				out << r
			}
			i += marks
			continue
		}
		out << r
		i++
	}
	return out.string()
}

struct SettingsLinkEnd {
	text_end int
	end      int
}

fn settings_link_end(runes []rune, start int) ?SettingsLinkEnd {
	close := settings_find_rune(runes, `]`, start + 1) or { return none }
	if close + 1 >= runes.len || runes[close + 1] != `(` {
		return none
	}
	paren := settings_find_rune(runes, `)`, close + 2) or { return none }
	return SettingsLinkEnd{
		text_end: close
		end:      paren + 1
	}
}

fn settings_find_rune(runes []rune, target rune, from int) ?int {
	for index in from .. runes.len {
		if runes[index] == target {
			return index
		}
	}
	return none
}

fn settings_word_rune(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`)
		|| r >= 0x80
}

fn settings_space_rune(r rune) bool {
	return r == ` ` || r == `\t` || r == `\n`
}

// settings_query_terms splits a query into lower-case words.
fn settings_query_terms(query string) []string {
	mut terms := []string{}
	for word in settings_lower(query).split_any(' \t\n') {
		if word.len > 0 {
			terms << word
		}
	}
	return terms
}

// settings_item_matches reports whether an item shows for a search. Every
// word of the query, ignoring case, has to occur in the item's title, its
// description (as plain text) or one of its keywords; an empty query matches
// every item. An item without title or description (a custom row) is found
// through its keywords alone.
pub fn settings_item_matches(item SettingItem, query string) bool {
	terms := settings_query_terms(query)
	if terms.len == 0 {
		return true
	}
	mut haystack := []string{cap: item.keywords.len + 2}
	if item.title.len > 0 {
		haystack << settings_lower(item.title)
	}
	if item.description.len > 0 {
		haystack << settings_lower(settings_plain_text(item.description))
	}
	for keyword in item.keywords {
		haystack << settings_lower(keyword)
	}
	for term in terms {
		mut found := false
		for hay in haystack {
			if hay.contains(term) {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

// settings_group_matches reports whether a group shows for a search: when one
// of its items does. The group's title and footer do not count, as upstream.
pub fn settings_group_matches(group SettingGroup, query string) bool {
	for item in group.items {
		if settings_item_matches(item, query) {
			return true
		}
	}
	return false
}

// settings_visible_groups lists, page by page, the indices of the groups a
// search shows. Indices are those of page.groups: filtering never renumbers.
pub fn settings_visible_groups(pages []SettingPage, query string) [][]int {
	mut visible := [][]int{cap: pages.len}
	for page in pages {
		mut groups := []int{}
		for index, group in page.groups {
			if settings_group_matches(group, query) {
				groups << index
			}
		}
		visible << groups
	}
	return visible
}

// settings_match_count is how many items of a page match a search.
pub fn settings_match_count(page SettingPage, query string) int {
	mut count := 0
	for group in page.groups {
		for item in group.items {
			if settings_item_matches(item, query) {
				count++
			}
		}
	}
	return count
}

fn settings_page_index(pages []SettingPage, id string) int {
	for index, page in pages {
		if settings_page_id(page) == id {
			return index
		}
	}
	return -1
}

// settings_resolve_state applies GPUI Kit's selection rules while searching:
// the current page stays selected while it has matching settings, otherwise
// the first page that does is selected; a selected group stays while it
// matches on the page that stays, otherwise the selection falls back to its
// page. When nothing matches, the selection is kept for when results return.
// An empty or unknown page selects the first page.
pub fn settings_resolve_state(pages []SettingPage, state SettingsState) SettingsState {
	if pages.len == 0 {
		return state
	}
	visible := settings_visible_groups(pages, state.query)
	mut current := settings_page_index(pages, state.page)
	mut first := -1
	for index, groups in visible {
		if groups.len > 0 {
			first = index
			break
		}
	}
	if first < 0 {
		if current < 0 {
			return SettingsState{
				...state
				page:  settings_page_id(pages[0])
				group: -1
			}
		}
		return state
	}
	page_ix := if current >= 0 && visible[current].len > 0 { current } else { first }
	group := if page_ix == current && state.group in visible[page_ix] { state.group } else { -1 }
	return SettingsState{
		...state
		page:  settings_page_id(pages[page_ix])
		group: group
	}
}

// settings_initial_state selects the first page and lists the groups of the
// pages marked default_open.
pub fn settings_initial_state(pages []SettingPage) SettingsState {
	mut expanded := []string{}
	for page in pages {
		if page.default_open {
			expanded << settings_page_id(page)
		}
	}
	return SettingsState{
		page:     if pages.len > 0 { settings_page_id(pages[0]) } else { '' }
		expanded: expanded
	}
}

// ── Ids and actions ─────────────────────────────────────────────────

fn settings_hex(value string) string {
	return value.bytes().hex()
}

// settings_search_id is the id of the search input group.
fn settings_search_id(id string) string {
	return component_part_id(id, 'search')
}

// settings_search_field_id is the id of the search field, for focus() and
// text(); it is also the action the field emits on each edit.
pub fn settings_search_field_id(id string) string {
	return input_group_field_id(settings_search_id(id))
}

// settings_nav_scroll_id is the id of the navigation's scroll element.
pub fn settings_nav_scroll_id(id string) string {
	return component_part_id(id, 'nav')
}

// settings_scroll_id is the id of the scroll element showing a page's
// groups. Each page has its own, so a page opens at its top.
pub fn settings_scroll_id(id string, page string) string {
	return component_part_id(id, 'content:' + settings_hex(page))
}

// settings_field_id is the id, and the action, of an item's control: a
// switch, checkbox, text field, slider or button. A text field's text is
// text(settings_field_id(id, key)).
pub fn settings_field_id(id string, key string) string {
	return component_part_id(id, 'field:' + settings_hex(key))
}

// settings_number_id is the id of a number item's number_input; its field is
// number_input_field_id of it.
pub fn settings_number_id(id string, key string) string {
	return component_part_id(id, 'number:' + settings_hex(key))
}

// settings_menu_id is the id of a dropdown item's menu.
pub fn settings_menu_id(id string, key string) string {
	return component_part_id(id, 'menu:' + settings_hex(key))
}

fn settings_dropdown_id(id string, key string) string {
	return component_part_id(id, 'dropdown:' + settings_hex(key))
}

pub fn settings_page_action(id string, page string) string {
	return component_part_id(id, 'page:' + settings_hex(page))
}

pub fn settings_expand_action(id string, page string) string {
	return component_part_id(id, 'expand:' + settings_hex(page))
}

pub fn settings_group_action(id string, page string, group int) string {
	return component_part_id(id, 'group:' + settings_hex(page) + ':${group}')
}

pub fn settings_reset_action(id string, key string) string {
	return component_part_id(id, 'reset:' + settings_hex(key))
}

pub fn settings_reset_page_action(id string, page string) string {
	return component_part_id(id, 'reset-page:' + settings_hex(page))
}

// ── Lookups ─────────────────────────────────────────────────────────

struct SettingsItemRef {
	page  int
	group int
	index int
	item  SettingItem
}

// settings_shown_items lists the items the selected page shows for the
// current search (none while nothing matches), with where they are.
fn settings_shown_items(config SettingsConfig, state SettingsState) []SettingsItemRef {
	page_ix := settings_page_index(config.pages, state.page)
	if page_ix < 0 {
		return []
	}
	mut refs := []SettingsItemRef{}
	for group_ix, group in config.pages[page_ix].groups {
		for index, item in group.items {
			if settings_item_matches(item, state.query) {
				refs << SettingsItemRef{
					page:  page_ix
					group: group_ix
					index: index
					item:  item
				}
			}
		}
	}
	return refs
}

fn settings_number_config_base(item SettingItem) NumberInputConfig {
	return NumberInputConfig{
		id:        'settings-number'
		min:       item.min
		max:       item.max
		step:      if item.step > 0 { item.step } else { 1 }
		precision: item.precision
	}
}

// settings_number_text_shown is the text a number item's field declares: the
// draft while it is being typed into, its value otherwise.
fn settings_number_text_shown(config SettingsConfig, state SettingsState, item SettingItem) string {
	if state.draft_key == item.key && state.draft_key.len > 0 {
		return state.draft
	}
	return settings_number_text(item, settings_value_number(settings_item_value(config.values,
		item)))
}

fn settings_number_input_config(config SettingsConfig, state SettingsState, item SettingItem, frame Rect) NumberInputConfig {
	base := settings_number_config_base(item)
	shown := settings_number_text_shown(config, state, item)
	return NumberInputConfig{
		...base
		id:                  settings_number_id(config.id, item.key)
		frame:               frame
		text:                shown
		placeholder:         item.placeholder
		enabled:             !item.disabled
		invalid:             shown.len > 0 && !number_input_in_range(base, shown)
		accessibility_label: item.title
		size:                config.size
		theme:               config.theme
	}
}

fn settings_menu_items(item SettingItem, current string) []DropdownMenuItem {
	mut rows := []DropdownMenuItem{cap: item.options.len}
	for option in item.options {
		rows << dropdown_menu_checkbox('option:' + settings_hex(option.value), settings_option_label(option),
			option.value == current)
	}
	return rows
}

fn settings_search_config(config SettingsConfig, frame Rect) InputGroupConfig {
	return InputGroupConfig{
		id:                  settings_search_id(config.id)
		frame:               frame
		text:                config.state.query
		placeholder:         config.search_placeholder
		addons:              [
			InputGroupAddon{
				id:   'icon'
				kind: .icon
				icon: 'magnifyingglass'
			},
		]
		clearable:           true
		accessibility_label: config.search_placeholder
		size:                config.size
		theme:               config.theme
	}
}

// ── Decoding ────────────────────────────────────────────────────────

// settings_closed drops the transient parts of a state: an open menu and a
// number being typed.
fn settings_closed(state SettingsState) SettingsState {
	return SettingsState{
		...state
		menu:       ''
		menu_state: DropdownMenuState{}
		draft_key:  ''
		draft:      ''
	}
}

fn settings_step(state SettingsState) SettingsStep {
	return SettingsStep{
		state: state
	}
}

fn settings_change_step(state SettingsState, key string, value SettingValue) SettingsStep {
	return SettingsStep{
		state:   state
		changes: [SettingChange{
			key:   key
			value: value
		}]
	}
}

// settings_scroll_step scrolls the selected page to its selected group, or
// to the top.
fn settings_scroll_step(config SettingsConfig, step SettingsStep) SettingsStep {
	resolved := SettingsConfig{
		...config
		state: step.state
	}
	mut offset := 0.0
	if step.state.group >= 0 {
		offset = settings_group_offset(resolved, step.state.group) or { 0.0 }
	}
	return SettingsStep{
		...step
		scroll:    true
		scroll_id: settings_scroll_id(config.id, step.state.page)
		scroll_to: offset
	}
}

fn settings_with_query(config SettingsConfig, state SettingsState, query string) SettingsStep {
	next := settings_resolve_state(config.pages, SettingsState{
		...settings_closed(state)
		query: query
	})
	return settings_scroll_step(config, settings_step(next))
}

// settings_update decodes an action the settings emitted, against the
// application's current configuration:
//
//     ui2.settings_update(config, event, ui2.SettingsInput{
//         text: ui2.text, number: ui2.slider_value })
//
// It returns none for actions that are not the settings', are malformed or
// forged, name an item the selected page does not show, a disabled item, or
// change nothing. Store step.state, apply step.changes to the values and
// rebuild; then scroll, focus and sync as the step asks.
pub fn settings_update(config SettingsConfig, action string, input SettingsInput) ?SettingsStep {
	settings_validate(config) or { return none }
	return settings_update_resolved(config, settings_resolve_state(config.pages, config.state),
		action, input)
}

fn settings_update_resolved(config SettingsConfig, state SettingsState, action string, input SettingsInput) ?SettingsStep {
	// The open menu is told about every event first: its rows and the
	// pointer moving over them.
	if state.menu.len > 0 {
		if step := settings_menu_update(config, state, action) {
			return step
		}
	}
	if _ := parse_pointer_event(action) {
		return none
	}
	if !action.starts_with(component_part_id(config.id, '')) {
		return none
	}
	search := settings_search_config(config, rect(0, 0, 0, 0))
	if event := input_group_event(search, action) {
		match event.kind {
			.change {
				typed := input.read_text(settings_search_field_id(config.id)) or { return none }
				if typed == state.query {
					return none
				}
				return settings_with_query(config, state, typed)
			}
			.clear {
				step := settings_with_query(config, state, '')
				return SettingsStep{
					...step
					focus: settings_search_field_id(config.id)
				}
			}
			else {
				return none
			}
		}
	}
	part := component_action_part(config.id, action) or { return none }
	if part.starts_with('page:') || part.starts_with('expand:') {
		is_page := part.starts_with('page:')
		hex := if is_page { part['page:'.len..] } else { part['expand:'.len..] }
		page_ix := settings_page_from_hex(config, state, hex) or { return none }
		pid := settings_page_id(config.pages[page_ix])
		if is_page {
			mut expanded := state.expanded.clone()
			if pid !in expanded && settings_nav_children(config, state, page_ix).len > 0 {
				expanded << pid
			}
			next := SettingsState{
				...settings_closed(state)
				page:     pid
				group:    -1
				expanded: expanded
			}
			return settings_scroll_step(config, settings_step(next))
		}
		if settings_nav_children(config, state, page_ix).len == 0 {
			return none
		}
		expanded := if pid in state.expanded {
			state.expanded.filter(it != pid)
		} else {
			mut more := state.expanded.clone()
			more << pid
			more
		}
		return settings_step(SettingsState{
			...settings_closed(state)
			expanded: expanded
		})
	}
	if part.starts_with('group:') {
		rest := part['group:'.len..]
		colon := rest.index(':') or { return none }
		page_ix := settings_page_from_hex(config, state, rest[..colon]) or { return none }
		group := component_parse_index(rest[colon + 1..], config.pages[page_ix].groups.len - 1) or {
			return none
		}
		// Group rows show only under an expanded page.
		if group !in settings_nav_children(config, state, page_ix)
			|| settings_page_id(config.pages[page_ix]) !in state.expanded {
			return none
		}
		next := SettingsState{
			...settings_closed(state)
			page:  settings_page_id(config.pages[page_ix])
			group: group
		}
		return settings_scroll_step(config, settings_step(next))
	}
	if part.starts_with('reset-page:') {
		page_ix := settings_page_from_hex(config, state, part['reset-page:'.len..]) or {
			return none
		}
		if settings_page_id(config.pages[page_ix]) != state.page {
			return none
		}
		changes := settings_page_resets(config, state)
		if changes.len == 0 {
			return none
		}
		return SettingsStep{
			state:   settings_closed(state)
			changes: changes
		}
	}
	if part.starts_with('reset:') {
		ref := settings_item_from_hex(config, state, part['reset:'.len..]) or { return none }
		if !settings_item_dirty(config.values, ref.item) || !settings_page_resettable(config, ref.page) {
			return none
		}
		default := ref.item.default_value or { return none }
		return SettingsStep{
			state:   settings_closed(state)
			changes: [
				SettingChange{
					key:   ref.item.key
					value: default
					reset: true
				},
			]
		}
	}
	if part.starts_with('field:') {
		ref := settings_item_from_hex(config, state, part['field:'.len..]) or { return none }
		return settings_field_update(config, state, ref.item, input)
	}
	if part.starts_with('number:') {
		rest := part['number:'.len..]
		end := rest.index(':') or { return none }
		ref := settings_item_from_hex(config, state, rest[..end]) or { return none }
		if ref.item.kind != .number {
			return none
		}
		return settings_number_update(config, state, ref.item, action, input)
	}
	if part.starts_with('menu:') {
		// A menu row's action while that menu is closed, or the toggle.
		rest := part['menu:'.len..]
		end := rest.index(':') or { return none }
		ref := settings_item_from_hex(config, state, rest[..end]) or { return none }
		if ref.item.kind != .dropdown || action != dropdown_menu_toggle_action(settings_menu_id(config.id,
			ref.item.key)) {
			return none
		}
		if state.menu == ref.item.key {
			return settings_step(settings_closed(state))
		}
		return settings_step(SettingsState{
			...settings_closed(state)
			menu:       ref.item.key
			menu_state: DropdownMenuState{}.opened()
		})
	}
	return none
}

fn settings_page_from_hex(config SettingsConfig, state SettingsState, hex string) ?int {
	visible := settings_visible_groups(config.pages, state.query)
	for index, page in config.pages {
		if settings_hex(settings_page_id(page)) == hex {
			// A page the search hides is not in the navigation.
			if visible[index].len == 0 {
				return none
			}
			return index
		}
	}
	return none
}

fn settings_item_from_hex(config SettingsConfig, state SettingsState, hex string) ?SettingsItemRef {
	for ref in settings_shown_items(config, state) {
		if ref.item.key.len > 0 && settings_hex(ref.item.key) == hex {
			if ref.item.disabled {
				return none
			}
			return ref
		}
	}
	return none
}

fn settings_page_resettable(config SettingsConfig, page_ix int) bool {
	return page_ix >= 0 && page_ix < config.pages.len && config.pages[page_ix].resettable
}

// settings_page_resets are the changes Reset all makes: every item the
// selected page shows for the current search that differs from its default.
// Items the search hides, and disabled items, keep their values.
fn settings_page_resets(config SettingsConfig, state SettingsState) []SettingChange {
	mut changes := []SettingChange{}
	for ref in settings_shown_items(config, state) {
		if !settings_page_resettable(config, ref.page) || ref.item.disabled
			|| !settings_item_dirty(config.values, ref.item) {
			continue
		}
		if default := ref.item.default_value {
			changes << SettingChange{
				key:   ref.item.key
				value: default
				reset: true
			}
		}
	}
	return changes
}

fn settings_field_update(config SettingsConfig, state SettingsState, item SettingItem, input SettingsInput) ?SettingsStep {
	current := settings_item_value(config.values, item)
	next_state := settings_closed(state)
	match item.kind {
		.switch, .checkbox {
			return settings_change_step(next_state, item.key, SettingValue(!settings_value_bool(current)))
		}
		.input {
			typed := input.read_text(settings_field_id(config.id, item.key)) or { return none }
			if typed == settings_value_string(current) {
				return none
			}
			return settings_change_step(next_state, item.key, SettingValue(typed))
		}
		.slider {
			low := item.min or { return none }
			high := item.max or { return none }
			live := input.read_number(settings_field_id(config.id, item.key)) or { return none }
			if !component_finite(live) {
				return none
			}
			normalized := slider_value_normalized(live, low, high)
			value := settings_round(item, slider_value_from_normalized(normalized, low,
				high, item.step))
			if setting_value_equal(SettingValue(value), current) {
				return none
			}
			return settings_change_step(next_state, item.key, SettingValue(value))
		}
		.button {
			return SettingsStep{
				state:  next_state
				action: item.key
			}
		}
		else {
			return none
		}
	}
}

fn settings_number_update(config SettingsConfig, state SettingsState, item SettingItem, action string, input SettingsInput) ?SettingsStep {
	frame := rect(0, 0, 0, 0)
	number := settings_number_input_config(config, state, item, frame)
	kind := number_input_event(number, action) or { return none }
	current := settings_value_number(settings_item_value(config.values, item))
	base := settings_number_config_base(item)
	match kind {
		.change {
			typed := input.read_text(number_input_field_id(number.id)) or { return none }
			cleaned := number_input_sanitize(base, typed)
			mut next := SettingsState{
				...state
				menu:       ''
				menu_state: DropdownMenuState{}
				draft_key:  item.key
				draft:      cleaned
			}
			mut changes := []SettingChange{}
			if value := number_input_parse(cleaned) {
				if number_input_in_range(base, cleaned) && !setting_value_equal(SettingValue(value),
					SettingValue(current)) {
					changes << SettingChange{
						key:   item.key
						value: SettingValue(value)
					}
				}
			}
			if changes.len == 0 && cleaned == typed && state.draft_key == item.key
				&& state.draft == cleaned {
				return none
			}
			return SettingsStep{
				state:     next
				changes:   changes
				sync_id:   if cleaned != typed { number_input_field_id(number.id) } else { '' }
				sync_text: cleaned
			}
		}
		.submit {
			typed := if state.draft_key == item.key {
				state.draft
			} else {
				settings_number_text(item, current)
			}
			committed := number_input_commit(base, typed) or { '' }
			next := settings_closed(state)
			value := number_input_parse(committed) or {
				// Nothing usable was typed: go back to the stored value.
				return SettingsStep{
					state:     next
					sync_id:   number_input_field_id(number.id)
					sync_text: settings_number_text(item, current)
				}
			}
			shown := settings_number_text(item, value)
			if setting_value_equal(SettingValue(value), SettingValue(current)) {
				return SettingsStep{
					state:     next
					sync_id:   number_input_field_id(number.id)
					sync_text: shown
				}
			}
			return SettingsStep{
				...settings_change_step(next, item.key, SettingValue(value))
				sync_id:   number_input_field_id(number.id)
				sync_text: shown
			}
		}
		.increment, .decrement {
			// Steps go from what the field shows, a draft included, as
			// number_input's own buttons do.
			stepped := number_input_value_from_action(number, action) or { return none }
			value := number_input_parse(stepped) or { return none }
			return SettingsStep{
				...settings_change_step(settings_closed(state), item.key, SettingValue(value))
				sync_id:   number_input_field_id(number.id)
				sync_text: settings_number_text(item, value)
			}
		}
	}
}

fn settings_menu_update(config SettingsConfig, state SettingsState, action string) ?SettingsStep {
	mut found := ?SettingItem(none)
	for ref in settings_shown_items(config, state) {
		if ref.item.key == state.menu && ref.item.kind == .dropdown && !ref.item.disabled {
			found = ref.item
			break
		}
	}
	item := found or { return none }
	menu_id := settings_menu_id(config.id, item.key)
	current := settings_value_string(settings_item_value(config.values, item))
	rows := settings_menu_items(item, current)
	step := dropdown_menu_update(menu_id, rows, state.menu_state, action) or { return none }
	if !step.state.open {
		mut next := settings_closed(state)
		if step.chosen {
			for index, row in rows {
				if row.id == step.item.id {
					value := item.options[index].value
					if value == current {
						return settings_step(next)
					}
					return settings_change_step(next, item.key, SettingValue(value))
				}
			}
		}
		return settings_step(next)
	}
	return settings_step(SettingsState{
		...state
		menu_state: step.state
	})
}

// settings_key handles a key from on_key_event: the open dropdown menu's
// arrows, Return and Escape; Up and Down in a focused number field; and
// Escape in the search field, which clears the search. Pass focused_id().
// Consume the key when it returns a step.
pub fn settings_key(config SettingsConfig, focused string, event KeyEvent) ?SettingsStep {
	settings_validate(config) or { return none }
	return settings_key_resolved(config, settings_resolve_state(config.pages, config.state),
		focused, event)
}

fn settings_key_resolved(config SettingsConfig, state SettingsState, focused string, event KeyEvent) ?SettingsStep {
	if state.menu.len > 0 {
		for ref in settings_shown_items(config, state) {
			if ref.item.key != state.menu || ref.item.kind != .dropdown {
				continue
			}
			current := settings_value_string(settings_item_value(config.values, ref.item))
			rows := settings_menu_items(ref.item, current)
			step := dropdown_menu_key(rows, state.menu_state, event) or { return none }
			if step.state.open {
				return settings_step(SettingsState{
					...state
					menu_state: step.state
				})
			}
			next := settings_closed(state)
			if step.chosen {
				for index, row in rows {
					if row.id == step.item.id && ref.item.options[index].value != current {
						return settings_change_step(next, ref.item.key, SettingValue(ref.item.options[index].value))
					}
				}
			}
			return settings_step(next)
		}
		return none
	}
	if focused == settings_search_field_id(config.id) {
		if event.code == .escape && state.query.len > 0 && !event.cmd && !event.ctrl && !event.alt {
			return settings_with_query(config, state, '')
		}
		return none
	}
	for ref in settings_shown_items(config, state) {
		if ref.item.kind != .number || ref.item.disabled {
			continue
		}
		if focused != number_input_field_id(settings_number_id(config.id, ref.item.key)) {
			continue
		}
		number := settings_number_input_config(config, state, ref.item, rect(0, 0, 0, 0))
		stepped := number_input_value_from_key(number, event) or { return none }
		value := number_input_parse(stepped) or { return none }
		return SettingsStep{
			...settings_change_step(settings_closed(state), ref.item.key, SettingValue(value))
			sync_id:   number_input_field_id(number.id)
			sync_text: stepped
		}
	}
	return none
}
