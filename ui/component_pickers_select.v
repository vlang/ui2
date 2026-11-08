module ui2

import math

// select_box is GPUI Kit's Select: a trigger showing the chosen option (or
// several, as tags, a count or a list) that opens a popup of options below
// it, optionally with a search field. `select` is a V keyword, hence the name.
// It is drawn by ui2 on every backend; `dropdown` remains the platform's own
// pop-up button (see docs/gpui-kit/pickers.md for when to use which).
//
// Like a popover, the popup is an overlay: build select_popup last, as one of
// the final children of the screen. Both builders take the same SelectConfig.

// SelectMultipleDisplay is how a multiple select shows its choices in the trigger.
pub enum SelectMultipleDisplay {
	tags  // a removable tag per choice, as many as fit and a "+N" tag for the rest
	count // "3 selected" (count_format)
	list  // the labels joined with commas, cut short at the trigger's edge
}

// SelectState is the part of a select's state that is not the selection: the
// popup, its highlighted option (by value) and the search query.
pub struct SelectState {
pub:
	open      bool
	highlight string
	query     string
}

pub struct SelectConfig {
pub:
	id     string
	frame  Rect // The trigger, in its parent's coordinates.
	anchor Rect // The trigger in window coordinates, for the popup; zero means frame.
	window Rect // Pass ui2.bounds().
	// Controlled: the application stores what select_update returns and rebuilds.
	options  []PickerOption
	selected []string // Values of the chosen options; at most one unless multiple.
	state    SelectState
	multiple bool // Choosing toggles an option and keeps the popup open.
	display  SelectMultipleDisplay = .tags
	// count_format is the count display's text; {count} is replaced.
	count_format       string = '{count} selected'
	placeholder        string = 'Select…'
	title_prefix       string // Shown before the chosen label: 'Country: ' gives "Country: Spain".
	icon               string // A symbol name replacing the chevron.
	searchable         bool   // A search field at the top of the popup filters the options.
	search_placeholder string          = 'Search…'
	match_mode         PickerMatchMode = .substring
	clearable          bool // A clear button replaces the chevron while something is chosen.
	enabled            bool = true
	invalid            bool // Draw the danger border.
	empty_text         string = 'No results'
	separators         bool // Draw a line between groups.
	// menu_width fixes the popup width; zero makes it as wide as the trigger.
	menu_width          f64
	max_height          f64 = 320 // The popup's, search field included; the window limits it too.
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// SelectStep is a decoded event: the next state and the selection after it.
pub struct SelectStep {
pub:
	state    SelectState
	selected []string
	changed  bool // The selection differs from the config's: store it.
	// focus is an id to focus once the tree is rebuilt: the search field of a
	// searchable select that just opened. Empty otherwise.
	focus string
	// propagate means the key should also do its usual job (Tab moving
	// focus): do not consume it.
	propagate bool
}

pub fn select_toggle_action(id string) string {
	return component_part_id(id, 'toggle')
}

pub fn select_dismiss_action(id string) string {
	return component_part_id(id, 'dismiss')
}

pub fn select_clear_action(id string) string {
	return component_part_id(id, 'clear')
}

// select_option_action is the action the popup row of an option emits.
pub fn select_option_action(id string, value string) string {
	return component_part_id(id, picker_option_part(value))
}

// select_remove_action is the action of a tag's remove button.
pub fn select_remove_action(id string, value string) string {
	return component_part_id(id, picker_value_part('remove:', value))
}

fn select_search_group_id(id string) string {
	return component_part_id(id, 'search')
}

// select_search_id is the id of the popup's search field, for focus() and
// text(); it is also the action the field emits on each edit.
pub fn select_search_id(id string) string {
	return input_group_field_id(select_search_group_id(id))
}

// select_list_id is the id of the popup's scroll element while the options
// are taller than the popup, for scroll_to_rect.
pub fn select_list_id(id string) string {
	return component_part_id(id, 'list')
}

fn select_popup_id(id string) string {
	return component_part_id(id, 'popup')
}

fn select_validate(config SelectConfig) ! {
	component_validate_id(config.id)!
	component_validate_frame(config.frame)!
	component_validate_frame(config.anchor)!
	component_validate_frame(config.window)!
	validate_picker_options(config.options)!
	if !config.multiple && config.selected.len > 1 {
		return error('select `${config.id}` chooses one option but has ${config.selected.len} selected')
	}
	for value in [config.menu_width, config.max_height] {
		if !component_finite(value) || value < 0 {
			return error('select menu width and max height must be finite and non-negative')
		}
	}
	if config.icon.len > 0 && !symbol_known(config.icon) {
		return error('select icon `${config.icon}` is not drawn by every renderer; pick a name from symbol_names()')
	}
}

// select_hits are the options the current query shows, in display order.
fn select_hits(config SelectConfig) []PickerHit {
	query := if config.searchable { config.state.query } else { '' }
	return picker_filter(config.options, query, config.match_mode, false)
}

fn select_option(config SelectConfig, value string) ?PickerOption {
	for option in config.options {
		if option.value == value {
			return option
		}
	}
	return none
}

// select_titles are the titles of the chosen options, in the order chosen.
// Values that name no option are skipped.
pub fn select_titles(config SelectConfig) []string {
	mut titles := []string{cap: config.selected.len}
	for value in config.selected {
		if option := select_option(config, value) {
			titles << option.title()
		}
	}
	return titles
}

// select_display_text is what the trigger says, as text: the chosen title with
// its prefix, the count or the list of a multiple select, or '' when nothing is
// chosen (the trigger then shows the placeholder).
pub fn select_display_text(config SelectConfig) string {
	titles := select_titles(config)
	if titles.len == 0 {
		return ''
	}
	if !config.multiple {
		return config.title_prefix + titles[0]
	}
	if config.display == .count {
		return config.count_format.replace('{count}', titles.len.str())
	}
	return config.title_prefix + titles.join(', ')
}

// select_initial_highlight is the option highlighted when the popup opens: the
// first chosen one that is enabled, or else the first enabled option.
fn select_initial_highlight(config SelectConfig, hits []PickerHit) string {
	for value in config.selected {
		position := picker_hit_of(config.options, hits, value)
		if position >= 0 && picker_navigable(config.options, hits[position]) {
			return value
		}
	}
	return picker_first_value(config.options, hits)
}

fn select_opened(config SelectConfig) SelectStep {
	hits := picker_filter(config.options, '', config.match_mode, false)
	return SelectStep{
		state:    SelectState{
			open:      true
			highlight: select_initial_highlight(config, hits)
		}
		selected: config.selected.clone()
		focus:    if config.searchable { select_search_id(config.id) } else { '' }
	}
}

fn select_closed(config SelectConfig) SelectStep {
	return SelectStep{
		state:    SelectState{}
		selected: config.selected.clone()
	}
}

fn select_moved(config SelectConfig, value string) ?SelectStep {
	if value.len == 0 || value == config.state.highlight {
		return none
	}
	return SelectStep{
		state:    SelectState{
			...config.state
			highlight: value
		}
		selected: config.selected.clone()
	}
}

// select_choose applies a choice of value: a single select takes it and
// closes; a multiple one adds or removes it and stays open on it.
fn select_choose(config SelectConfig, value string) SelectStep {
	if !config.multiple {
		return SelectStep{
			state:    SelectState{}
			selected: [value]
			changed:  config.selected != [value]
		}
	}
	mut next := config.selected.filter(it != value)
	if next.len == config.selected.len {
		next << value
	}
	return SelectStep{
		state:    SelectState{
			...config.state
			highlight: value
		}
		selected: next
		changed:  true
	}
}

// select_visible_value decodes an option part to the value of an enabled
// option the popup is showing, rejecting hidden, disabled and unknown ones.
fn select_visible_value(config SelectConfig, part string) ?string {
	value := picker_value_from_part('option:', part)?
	hits := select_hits(config)
	position := picker_hit_of(config.options, hits, value)
	if position < 0 || !picker_navigable(config.options, hits[position]) {
		return none
	}
	return value
}

// select_update decodes an event a select emitted against the config it was
// built with: its trigger (open or close), a press outside the popup, a row
// (choose), a pointer entering a row (highlight), the clear button, a tag's
// remove button and Return in the search field. It returns none for events
// that are not the select's, are forged or malformed, name hidden or disabled
// options, or change nothing. Edits of the search field go to select_search.
pub fn select_update(config SelectConfig, event string) ?SelectStep {
	open := config.state.open
	if pointer := parse_pointer_event(event) {
		if !open || !config.enabled || pointer.phase != 'enter' {
			return none
		}
		part := component_action_part(config.id, pointer.action) or { return none }
		value := select_visible_value(config, part) or { return none }
		return select_moved(config, value)
	}
	part := component_action_part(config.id, event) or { return none }
	if part == 'dismiss' {
		return if open { select_closed(config) } else { none }
	}
	if !config.enabled {
		return none
	}
	if part == 'toggle' {
		return if open { select_closed(config) } else { select_opened(config) }
	}
	if part == 'clear' {
		if !config.clearable || config.selected.len == 0 {
			return none
		}
		return SelectStep{
			state:   config.state
			changed: true
		}
	}
	if part == 'search:component:submit' {
		if !open || config.state.highlight.len == 0 {
			return none
		}
		value := select_visible_value(config, picker_option_part(config.state.highlight)) or {
			return none
		}
		return select_choose(config, value)
	}
	if removed := picker_value_from_part('remove:', part) {
		if !config.multiple || config.display != .tags || removed !in config.selected {
			return none
		}
		return SelectStep{
			state:    config.state
			selected: config.selected.filter(it != removed)
			changed:  true
		}
	}
	if !open {
		return none
	}
	value := select_visible_value(config, part) or { return none }
	return select_choose(config, value)
}

// select_search applies an edit of the search field: read it with
// text(select_search_id(id)) when that id arrives as an event. The highlight
// moves to the first option the query shows.
pub fn select_search(config SelectConfig, query string) SelectStep {
	hits := picker_filter(config.options, query, config.match_mode, false)
	return SelectStep{
		state:    SelectState{
			open:      true
			query:     query
			highlight: picker_first_value(config.options, hits)
		}
		selected: config.selected.clone()
	}
}

// select_open_key reports whether a key opens a closed select whose trigger
// the application treats as focused: Down, Up, Enter or Space.
pub fn select_open_key(event KeyEvent) bool {
	return picker_plain_key(event) && !event.shift
		&& event.code in [.down, .up, .enter, .kp_enter, .space]
}

// select_key handles a key while the popup is open, for on_key_event: Up and
// Down move the highlight (wrapping, skipping disabled options), Page Up and
// Page Down jump to the ends, Enter chooses (Space too without a search field,
// which also takes Home, End and a letter to jump to the next option starting
// with it), Escape closes, and Tab closes without being consumed. It returns
// none for keys it leaves alone; consume the key otherwise unless propagate.
// On AppKit the search field keeps Return, which arrives as the field's submit
// action through select_update instead.
pub fn select_key(config SelectConfig, event KeyEvent) ?SelectStep {
	if !config.state.open || !picker_plain_key(event) {
		return none
	}
	if event.code == .tab {
		return SelectStep{
			...select_closed(config)
			propagate: true
		}
	}
	if event.shift {
		return none
	}
	if event.code == .escape {
		return select_closed(config)
	}
	if !config.enabled {
		return none
	}
	hits := select_hits(config)
	current := config.state.highlight
	match event.code {
		.down {
			return select_moved(config, picker_step_value(config.options, hits, current, 1))
		}
		.up {
			return select_moved(config, picker_step_value(config.options, hits, current, -1))
		}
		.page_up {
			return select_moved(config, picker_edge_value(config.options, hits, false))
		}
		.page_down {
			return select_moved(config, picker_edge_value(config.options, hits, true))
		}
		.home, .end {
			if config.searchable {
				return none
			}
			return select_moved(config, picker_edge_value(config.options, hits, event.code == .end))
		}
		.enter, .kp_enter, .space {
			if event.code == .space && config.searchable {
				return none
			}
			value := select_visible_value(config, picker_option_part(current)) or { return none }
			return select_choose(config, value)
		}
		else {}
	}
	if config.searchable {
		return none
	}
	ch := picker_key_rune(event) or { return none }
	return select_moved(config, picker_typeahead_value(config.options, hits, current, ch))
}

// ── Trigger ────────────────────────────────────────────────────────

fn select_padding(metrics ComponentMetrics) f64 {
	return metrics.padding + 4
}

// SelectTag is a tag the trigger shows: a chosen option (value set) or the
// "+N" tag standing for the choices that did not fit (value empty).
struct SelectTag {
	value  string
	text   string
	frame  Rect
	remove Rect // the remove button, in the trigger's coordinates; empty for "+N"
}

fn select_tag_height(height f64) f64 {
	return math.max(math.min(math.round(height * 0.72), height - 4), math.min(16, height))
}

// select_tags lays out the tags of a multiple select from x = left, as many as
// fit before right, then a "+N" tag for the rest.
fn select_tags(config SelectConfig, left f64, right f64, height f64) []SelectTag {
	metrics := component_metrics(config.size)
	tag_height := select_tag_height(height)
	tag_font := metrics.font_size - 1
	pad := math.round(metrics.padding * 0.75)
	remove_side := if config.enabled { math.round(tag_height * 0.75) } else { 0.0 }
	gap := metrics.gap - 2
	y := math.round((height - tag_height) / 2)
	mut chosen := []PickerOption{}
	for value in config.selected {
		if option := select_option(config, value) {
			chosen << option
		}
	}
	mut tags := []SelectTag{}
	mut x := left
	for index, option in chosen {
		text_width := picker_text_width(option.title(), tag_font) + picker_label_slack
		mut width := math.ceil(pad * 2 + text_width + remove_side)
		rest := chosen.len - index - 1
		plus_width := math.ceil(pad * 2 + picker_text_width('+${rest}', tag_font) +
			picker_label_slack)
		reserve := if rest > 0 { gap + plus_width } else { 0.0 }
		if x + width + reserve > right {
			room := right - x - reserve
			if index == 0 && room >= pad * 2 + remove_side + tag_font {
				// The first tag shows shortened to the room left.
				width = room
			} else {
				all_rest := chosen.len - index
				tags << SelectTag{
					text:  '+${all_rest}'
					frame: rect(x, y, math.ceil(pad * 2 + picker_text_width('+${all_rest}',
						tag_font) + picker_label_slack), tag_height)
				}
				break
			}
		}
		frame := rect(x, y, width, tag_height)
		tags << SelectTag{
			value:  option.value
			text:   option.title()
			frame:  frame
			remove: if remove_side > 0 {
				rect(frame.x + frame.width - remove_side - 2, y + (tag_height - remove_side) / 2,
					remove_side, remove_side)
			} else {
				Rect{}
			}
		}
		x += width + gap
		if width < pad * 2 + text_width + remove_side && rest > 0 {
			tags << SelectTag{
				text:  '+${rest}'
				frame: rect(x, y, plus_width, tag_height)
			}
			break
		}
	}
	return tags
}

fn select_tag_elements(config SelectConfig, tags []SelectTag) ([]Element, []Element) {
	metrics := component_metrics(config.size)
	theme := config.theme
	tag_font := metrics.font_size - 1
	pad := math.round(metrics.padding * 0.75)
	foreground := if config.enabled { theme.foreground } else { theme.muted_foreground }
	mut shapes := []Element{cap: tags.len}
	mut removers := []Element{cap: tags.len}
	for index, item in tags {
		text_right := if item.remove.width > 0 {
			item.remove.x - item.frame.x
		} else {
			item.frame.width - pad
		}
		shapes << Element{
			...view('', item.frame, BoxStyle{
				bg:     if config.enabled { theme.muted } else { theme.background }
				radius: math.max(metrics.radius - 2, 2)
			}, [
				label('', item.text, rect(pad, 0, math.max(text_right - pad, 0), item.frame.height),
					TextStyle{
						color: if item.value.len > 0 { foreground } else { theme.muted_foreground }
						size:  tag_font
					}),
			])
			key: 'tag:${index}'
		}
		if item.remove.width > 0 {
			glyph := math.round(item.remove.width * 0.6)
			removers << Element{
				...button_view(select_remove_action(config.id, item.value), item.remove, BoxStyle{
					transparent: true
				}, [
					picker_symbol('xmark', rect((item.remove.width - glyph) / 2, (item.remove.height - glyph) / 2,
						glyph, glyph), theme.muted_foreground),
				])
				key:                 picker_value_part('remove:', item.value)
				cursor:              cursor_pointing_hand
				accessibility_label: 'Remove ${item.text}'
			}
		}
	}
	return shapes, removers
}

// select_box draws a select's trigger. Pressing it emits
// select_toggle_action(id); decode that and everything the popup emits with
// select_update, store the result and rebuild.
pub fn select_box(config SelectConfig) !Element {
	select_validate(config)!
	metrics := component_metrics(config.size)
	theme := config.theme
	local := component_local(config.frame)
	pad := select_padding(metrics)
	border := if config.invalid {
		theme.danger
	} else if config.state.open {
		theme.primary
	} else {
		theme.border
	}
	fill := if config.enabled { theme.background } else { theme.muted }
	box, mut children := popover_panel(local, fill, border, metrics.radius, false)
	icon_side := metrics.font_size
	shows_clear := config.clearable && config.enabled && config.selected.len > 0
	trailing_x := local.width - pad - icon_side
	mut content := []Element{}
	if !shows_clear {
		name := if config.icon.len > 0 { config.icon } else { 'chevron.down' }
		content << Element{
			...picker_symbol(name, rect(trailing_x, (local.height - icon_side) / 2, icon_side,
				icon_side), theme.muted_foreground)
			key: 'chevron'
		}
	}
	mut x := pad
	right := trailing_x - metrics.gap
	titles := select_titles(config)
	text_color := if config.enabled { theme.foreground } else { theme.muted_foreground }
	mut removers := []Element{}
	if titles.len == 0 {
		content << label('', config.placeholder, rect(x, 0, math.max(right - x, 0), local.height),
			TextStyle{
				color: theme.muted_foreground
				size:  metrics.font_size
			})
	} else if config.multiple && config.display == .tags {
		tags := select_tags(config, x - pad / 3, right, local.height)
		shapes, buttons := select_tag_elements(config, tags)
		content << shapes
		removers = buttons.clone()
	} else {
		if !config.multiple {
			chosen := select_option(config, config.selected[0]) or { PickerOption{} }
			if chosen.icon.len > 0 {
				side := metrics.font_size + 2
				content << picker_symbol(chosen.icon, rect(x, (local.height - side) / 2, side,
					side), text_color)
				x += side + metrics.gap
			}
		}
		content << label('', select_display_text(config), rect(x, 0, math.max(right - x, 0),
			local.height), TextStyle{
			color: text_color
			size:  metrics.font_size
		})
	}
	description := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		config.placeholder
	}
	shown := select_display_text(config)
	children << Element{
		...button_view(select_toggle_action(config.id), local, BoxStyle{ transparent: true },
			content)
		key:                 'trigger'
		enabled:             config.enabled
		cursor:              if config.enabled { cursor_pointing_hand } else { cursor_default }
		accessibility_role:  'combobox'
		accessibility_label: description
		accessibility_value: if shown.len > 0 { shown } else { config.placeholder }
	}
	children << removers
	if shows_clear {
		side := math.min(local.height - 8, icon_side + 10)
		glyph := icon_side - 2
		children << Element{
			...button_view(select_clear_action(config.id), rect(local.width - pad - icon_side / 2 - side / 2,
				(local.height - side) / 2, side, side), BoxStyle{ transparent: true }, [
				picker_symbol('xmark', rect((side - glyph) / 2, (side - glyph) / 2, glyph, glyph),
					theme.muted_foreground),
			])
			key:                 'clear'
			tooltip:             'Clear'
			cursor:              cursor_pointing_hand
			accessibility_label: 'Clear'
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_role:  'group'
		accessibility_label: description
	})
}

// ── Popup ──────────────────────────────────────────────────────────

// SelectPopupLayout is where the popup and its parts go. surface is in window
// coordinates; search and list are relative to the surface; rows are in the
// list content's coordinates.
struct SelectPopupLayout {
	surface Rect
	search  Rect
	list    Rect
	hits    []PickerHit
	rows    []PickerRow
}

const select_popup_offset = 4.0
const select_popup_margin = 8.0
const select_popup_min_width = 120.0

fn select_popup_layout(config SelectConfig) !SelectPopupLayout {
	anchor := picker_anchor(config.anchor, config.frame)
	m := picker_metrics(config.size)
	metrics := component_metrics(config.size)
	limits := popover_limits(config.window, select_popup_margin)
	requested := if config.menu_width > 0 {
		config.menu_width
	} else {
		math.max(anchor.width, select_popup_min_width)
	}
	width := math.max(math.min(requested, limits.right - limits.left), 0)
	hits := select_hits(config)
	rows := picker_rows(config.options, hits, config.separators, m)
	search_margin := 6.0
	search := if config.searchable {
		rect(search_margin, search_margin, math.max(width - search_margin * 2, 0), metrics.height)
	} else {
		Rect{}
	}
	// The list stays inside the surface's one-point border, so a scrolling
	// list does not paint over it.
	list_top := if config.searchable { search.y + search.height + 2 } else { 1.0 }
	content := if rows.len > 0 { picker_rows_height(rows) + m.inset * 2 } else { m.empty }
	natural := math.min(list_top + content + 1, if config.max_height > 0 {
		config.max_height
	} else {
		list_top + content + 1
	})
	height := picker_popup_height(natural, anchor, config.window, select_popup_margin,
		select_popup_offset)
	placement := popover_place(
		anchor: anchor
		window: config.window
		width:  width
		height: height
		side:   .bottom
		align:  .start
		offset: select_popup_offset
		margin: select_popup_margin
	)!
	return SelectPopupLayout{
		surface: placement.frame
		search:  search
		list:    rect(1, list_top, math.max(width - 2, 0), math.max(height - list_top - 1, 0))
		hits:    hits
		rows:    rows
	}
}

// select_highlight_rect is the highlighted row in the coordinates of the
// list's content, for scroll_to_rect(select_list_id(id), ...) after a key
// moved the highlight. none while closed or nothing is highlighted.
pub fn select_highlight_rect(config SelectConfig) ?Rect {
	if !config.state.open {
		return none
	}
	layout := select_popup_layout(config) or { return none }
	return picker_row_rect(config.options, layout.rows, config.state.highlight, layout.list.width,
		picker_metrics(config.size))
}

// select_popup draws the open popup of a select, or nothing while it is
// closed: an overlay to add after everything it may cover. A press outside it
// emits select_dismiss_action(id).
pub fn select_popup(config SelectConfig) !Element {
	select_validate(config)!
	if !config.state.open || !config.enabled {
		return component_finish(popover_closed(select_popup_id(config.id)))
	}
	layout := select_popup_layout(config)!
	theme := config.theme
	mut content := []Element{}
	if config.searchable {
		content << Element{
			...input_group(
				id:                  select_search_group_id(config.id)
				frame:               layout.search
				text:                config.state.query
				placeholder:         config.search_placeholder
				addons:              [
					InputGroupAddon{
						id:   'search'
						kind: .icon
						icon: 'magnifyingglass'
					},
				]
				accessibility_label: config.search_placeholder
				size:                config.size
				theme:               theme
			)!
			key: 'search'
		}
	}
	if layout.rows.len == 0 {
		content << picker_message(config.id, layout.list, config.empty_text, false, config.size,
			theme)
	} else {
		content << picker_list(PickerListSpec{
			id:        config.id
			options:   config.options
			rows:      layout.rows
			width:     layout.list.width
			highlight: config.state.highlight
			selected:  config.selected
			size:      config.size
			theme:     theme
		}, layout.list, select_list_id(config.id))
	}
	caption := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		config.placeholder
	}
	surface := picker_surface(component_part_id(config.id, 'surface'), layout.surface, content,
		'list', caption, config.size, theme)
	return component_finish(popover_layer(select_popup_id(config.id), config.window, component_part_id(config.id,
		'backdrop'), select_dismiss_action(config.id), [surface]))
}
