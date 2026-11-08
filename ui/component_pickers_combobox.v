module ui2

import math

// combobox is a text field with a list of options under it that filters as
// the user types. The field keeps the keyboard focus throughout: the
// application passes keys to combobox_key, which moves the highlight with the
// arrows, picks with Enter and closes with Escape. Picking puts the option's
// title in the field and commits its value. The list is an overlay: build
// combobox_popup last, as one of the final children of the screen.

// ComboboxState is the list's state: open, and its highlighted option by value.
pub struct ComboboxState {
pub:
	open      bool
	highlight string
}

pub struct ComboboxConfig {
pub:
	id     string
	frame  Rect // The field, in its parent's coordinates.
	anchor Rect // The field in window coordinates, for the list; zero means frame.
	window Rect // Pass ui2.bounds().
	// Controlled: the application stores what the decoders return and rebuilds.
	text    string // What the field holds.
	value   string // The committed option, by value; '' for none.
	options []PickerOption
	state   ComboboxState
	// Filtering. While the text is the committed option's title the list shows
	// every option, so reopening it offers the other choices.
	match_mode PickerMatchMode = .substring
	sort       bool // With a query, list the best matches first.
	min_chars  int  // Typing opens the list once the text is this long.
	max_rows   int  // Show at most this many matching options; zero shows all.
	// auto_highlight highlights the first match as the user types, so Enter
	// picks it. Without it Enter submits the typed text unless an arrow key
	// has highlighted an option.
	auto_highlight bool = true
	// Application-driven loading: while set, the list shows a spinner and
	// loading_text instead of the empty message.
	loading             bool
	loading_text        string = 'Loading…'
	empty_text          string = 'No matches'
	placeholder         string
	icon                string // A leading symbol name, such as magnifyingglass.
	clearable           bool
	enabled             bool = true
	invalid             bool
	separators          bool
	menu_width          f64 // Zero makes the list as wide as the field.
	max_height          f64 = 280
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub enum ComboboxChange {
	none      // Only the list changed.
	typed     // The text changed; value is cleared when it no longer names the committed option.
	picked    // An option was picked: text is its title and value its value.
	submitted // Enter with no option highlighted: decide what the typed text means.
	cleared   // The clear button emptied the field.
}

pub struct ComboboxStep {
pub:
	state  ComboboxState
	text   string
	value  string
	change ComboboxChange
	// focus is an id to give the focus back to once the tree is rebuilt: the
	// field, after a press on the list or a button took it.
	focus string
	// propagate means the key should also do its usual job (Tab moving
	// focus): do not consume it.
	propagate bool
}

// combobox_field_id is the id of the native field, for focus() and text(); it
// is also the action the field emits on each edit.
pub fn combobox_field_id(id string) string {
	return component_part_id(id, 'field')
}

pub fn combobox_toggle_action(id string) string {
	return component_part_id(id, 'toggle')
}

pub fn combobox_dismiss_action(id string) string {
	return component_part_id(id, 'dismiss')
}

pub fn combobox_clear_action(id string) string {
	return component_part_id(id, 'clear')
}

pub fn combobox_option_action(id string, value string) string {
	return component_part_id(id, picker_option_part(value))
}

// combobox_list_id is the id of the list's scroll element while the options
// are taller than the list, for scroll_to_rect.
pub fn combobox_list_id(id string) string {
	return component_part_id(id, 'list')
}

fn combobox_popup_id(id string) string {
	return component_part_id(id, 'popup')
}

fn combobox_validate(config ComboboxConfig) ! {
	component_validate_id(config.id)!
	component_validate_frame(config.frame)!
	component_validate_frame(config.anchor)!
	component_validate_frame(config.window)!
	validate_picker_options(config.options)!
	if config.min_chars < 0 || config.max_rows < 0 {
		return error('combobox min_chars and max_rows must be non-negative')
	}
	for value in [config.menu_width, config.max_height] {
		if !component_finite(value) || value < 0 {
			return error('combobox menu width and max height must be finite and non-negative')
		}
	}
	if config.icon.len > 0 && !symbol_known(config.icon) {
		return error('combobox icon `${config.icon}` is not drawn by every renderer; pick a name from symbol_names()')
	}
}

fn combobox_option(config ComboboxConfig, value string) ?PickerOption {
	if value.len == 0 {
		return none
	}
	for option in config.options {
		if option.value == value {
			return option
		}
	}
	return none
}

// combobox_query is what the list filters by: the text, unless it is the
// committed option's title.
fn combobox_query(config ComboboxConfig, text string) string {
	if committed := combobox_option(config, config.value) {
		if committed.title() == text {
			return ''
		}
	}
	return text
}

// combobox_matches are the options the list shows for text, in display order.
pub fn combobox_matches(config ComboboxConfig, text string) []PickerHit {
	hits := picker_filter(config.options, combobox_query(config, text), config.match_mode,
		config.sort)
	if config.max_rows > 0 && hits.len > config.max_rows {
		return hits[..config.max_rows]
	}
	return hits
}

fn combobox_step(config ComboboxConfig, state ComboboxState) ComboboxStep {
	return ComboboxStep{
		state: state
		text:  config.text
		value: config.value
	}
}

fn combobox_closed(config ComboboxConfig) ComboboxStep {
	return combobox_step(config, ComboboxState{})
}

// combobox_opened opens the list with the committed option highlighted, or,
// moving from the end with Up, the last option.
fn combobox_opened(config ComboboxConfig, from_end bool) ComboboxStep {
	hits := combobox_matches(config, config.text)
	position := picker_hit_of(config.options, hits, config.value)
	highlight := if position >= 0 && picker_navigable(config.options, hits[position]) {
		config.value
	} else {
		picker_edge_value(config.options, hits, from_end)
	}
	return combobox_step(config, ComboboxState{
		open:      true
		highlight: highlight
	})
}

fn combobox_moved(config ComboboxConfig, value string) ?ComboboxStep {
	if value.len == 0 || value == config.state.highlight {
		return none
	}
	return combobox_step(config, ComboboxState{
		open:      true
		highlight: value
	})
}

fn combobox_pick(config ComboboxConfig, value string) ?ComboboxStep {
	hits := combobox_matches(config, config.text)
	position := picker_hit_of(config.options, hits, value)
	if position < 0 || !picker_navigable(config.options, hits[position]) {
		return none
	}
	option := config.options[hits[position].index]
	return ComboboxStep{
		state:  ComboboxState{}
		text:   option.title()
		value:  option.value
		change: .picked
		focus:  combobox_field_id(config.id)
	}
}

// combobox_input applies an edit of the field: read the text with
// text(combobox_field_id(id)) when that id arrives as an event. The list opens
// once the text is min_chars long and highlights the first match when
// auto_highlight is set; a text that no longer is the committed option's title
// clears the committed value.
pub fn combobox_input(config ComboboxConfig, text string) ComboboxStep {
	mut keeps := false
	if committed := combobox_option(config, config.value) {
		keeps = committed.title() == text
	}
	next := ComboboxConfig{
		...config
		text:  text
		value: if keeps { config.value } else { '' }
	}
	open := config.enabled && text.runes().len >= config.min_chars
	hits := combobox_matches(next, text)
	return ComboboxStep{
		state:  ComboboxState{
			open:      open
			highlight: if open && config.auto_highlight && text.len > 0 {
				picker_first_value(config.options, hits)
			} else {
				''
			}
		}
		text:   text
		value:  next.value
		change: .typed
	}
}

// combobox_update decodes an event the combobox emitted against the config it
// was built with: the chevron (open or close), a press outside the list, a row
// (pick), a pointer entering a row (highlight), the clear button and Return in
// the field, which picks the highlighted option or, with none, submits the
// text. It returns none for events that are not the combobox's, are forged or
// malformed, name hidden or disabled options, or change nothing. Edits of the
// field go to combobox_input.
pub fn combobox_update(config ComboboxConfig, event string) ?ComboboxStep {
	open := config.state.open
	if pointer := parse_pointer_event(event) {
		if !open || !config.enabled || pointer.phase != 'enter' {
			return none
		}
		part := component_action_part(config.id, pointer.action) or { return none }
		value := picker_value_from_part('option:', part) or { return none }
		hits := combobox_matches(config, config.text)
		position := picker_hit_of(config.options, hits, value)
		if position < 0 || !picker_navigable(config.options, hits[position]) {
			return none
		}
		return combobox_moved(config, value)
	}
	part := component_action_part(config.id, event) or { return none }
	if part == 'dismiss' {
		return if open { combobox_closed(config) } else { none }
	}
	if !config.enabled {
		return none
	}
	match part {
		'toggle' {
			step := if open { combobox_closed(config) } else { combobox_opened(config, false) }
			return ComboboxStep{
				...step
				focus: combobox_field_id(config.id)
			}
		}
		'clear' {
			if !config.clearable || (config.text.len == 0 && config.value.len == 0) {
				return none
			}
			return ComboboxStep{
				change: .cleared
				focus:  combobox_field_id(config.id)
			}
		}
		'submit' {
			if open && config.state.highlight.len > 0 {
				return combobox_pick(config, config.state.highlight)
			}
			return ComboboxStep{
				...combobox_closed(config)
				change: .submitted
			}
		}
		else {}
	}
	if !open {
		return none
	}
	value := picker_value_from_part('option:', part) or { return none }
	return combobox_pick(config, value)
}

// combobox_key handles a key while the field has focus, for on_key_event: Down
// and Up open the list (at the committed option, or the first or last one) and
// then move the highlight, wrapping and skipping disabled options; Page Up and
// Page Down jump to the ends; Enter picks the highlighted option; Escape closes
// the list; Tab closes it without being consumed. Home, End, Left, Right and
// typing stay with the field. It returns none for keys it leaves alone; consume
// the key otherwise unless propagate. On AppKit a focused field keeps Return,
// which arrives as the field's submit action through combobox_update instead.
pub fn combobox_key(config ComboboxConfig, event KeyEvent) ?ComboboxStep {
	if !config.enabled || !picker_plain_key(event) {
		return none
	}
	open := config.state.open
	if event.code == .tab {
		return if open {
			ComboboxStep{
				...combobox_closed(config)
				propagate: true
			}
		} else {
			none
		}
	}
	if event.shift {
		return none
	}
	hits := combobox_matches(config, config.text)
	current := config.state.highlight
	match event.code {
		.down, .up {
			if !open {
				return combobox_opened(config, event.code == .up)
			}
			return combobox_moved(config, picker_step_value(config.options, hits, current,
				if event.code == .down { 1 } else { -1 }))
		}
		.page_up, .page_down {
			if !open {
				return none
			}
			return combobox_moved(config, picker_edge_value(config.options, hits, event.code == .page_down))
		}
		.enter, .kp_enter {
			if !open || current.len == 0 {
				return none
			}
			return combobox_pick(config, current)
		}
		.escape {
			return if open { combobox_closed(config) } else { none }
		}
		else {
			return none
		}
	}
}

// combobox_highlight_rect is the highlighted row in the coordinates of the
// list's content, for scroll_to_rect(combobox_list_id(id), ...). none while the
// list is closed or nothing is highlighted.
pub fn combobox_highlight_rect(config ComboboxConfig) ?Rect {
	if !config.state.open {
		return none
	}
	layout := combobox_popup_layout(config) or { return none }
	return picker_row_rect(config.options, layout.rows, config.state.highlight, layout.list.width,
		picker_metrics(config.size))
}

// ── Field ──────────────────────────────────────────────────────────

struct ComboboxFieldLayout {
	icon   Rect
	field  Rect
	clear  Rect
	toggle Rect
}

fn combobox_field_layout(config ComboboxConfig) ComboboxFieldLayout {
	width := config.frame.width
	height := config.frame.height
	side := math.min(height, width / 4)
	icon := if config.icon.len > 0 { rect(0, 0, side, height) } else { Rect{} }
	button_frame := rect(width - side, 0, side, height)
	field := rect(icon.width, 0, math.max(width - icon.width - side, 0), height)
	mut clear := Rect{}
	if config.clearable && config.enabled && (config.text.len > 0 || config.value.len > 0)
		&& field.width > 2 && field.height > 2 {
		clear_side := math.min(field.height - 2, field.width / 2)
		clear = rect(field.x + field.width - 1 - clear_side, 1, clear_side, field.height - 2)
	}
	return ComboboxFieldLayout{
		icon:   icon
		field:  field
		clear:  clear
		toggle: button_frame
	}
}

// combobox draws the field with its chevron button (and a leading icon and a
// clear button when asked for). The field emits combobox_field_id(id) on each
// edit; pass that to combobox_input and every other event to combobox_update.
pub fn combobox(config ComboboxConfig) !Element {
	combobox_validate(config)!
	metrics := component_metrics(config.size)
	theme := config.theme
	layout := combobox_field_layout(config)
	icon_size := inputs_icon_size(metrics)
	description := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		config.placeholder
	}
	mut children := []Element{}
	if layout.icon.width > 0 {
		children << Element{
			...view('', layout.icon, BoxStyle{ transparent: true }, [
				inputs_symbol(config.icon, inputs_centered_square(component_local(layout.icon),
					icon_size), theme.muted_foreground),
			])
			key: 'icon'
		}
	}
	field := inputs_field(
		id:          combobox_field_id(config.id)
		submit_id:   component_part_id(config.id, 'submit')
		placeholder: config.placeholder
		text:        config.text
		frame:       layout.field
		font_size:   metrics.font_size
		enabled:     config.enabled
		invalid:     config.invalid
		autocorrect: false
		role:        'combobox'
		label:       description
		key:         'field'
		theme:       theme
	)
	children << Element{
		...field
		accessibility_value: if config.state.open { 'expanded' } else { 'collapsed' }
	}
	if layout.clear.width > 0 {
		children << Element{
			...button_view(combobox_clear_action(config.id), layout.clear, BoxStyle{
				bg: theme.background
			}, [
				inputs_symbol('xmark', inputs_centered_square(component_local(layout.clear),
					metrics.font_size - 2), theme.muted_foreground),
			])
			key:                 'clear'
			tooltip:             'Clear'
			accessibility_label: 'Clear'
		}
	}
	chevron := metrics.font_size
	children << Element{
		...button_view(combobox_toggle_action(config.id), layout.toggle, BoxStyle{
			transparent: true
		}, [
			inputs_symbol(if config.state.open { 'chevron.up' } else { 'chevron.down' },
				inputs_centered_square(component_local(layout.toggle), chevron), if config.enabled {
					theme.muted_foreground
				} else {
					theme.border
				}),
		])
		key:                 'toggle'
		enabled:             config.enabled
		cursor:              cursor_pointing_hand
		accessibility_label: if config.state.open { 'Hide options' } else { 'Show options' }
	}
	return component_finish(Element{
		...view(config.id, config.frame, inputs_frame_box(theme, config.invalid, metrics.radius),
			children)
		accessibility_role:  'group'
		accessibility_label: description
	})
}

// ── List ───────────────────────────────────────────────────────────

struct ComboboxPopupLayout {
	surface Rect
	list    Rect
	hits    []PickerHit
	rows    []PickerRow
}

fn combobox_popup_layout(config ComboboxConfig) !ComboboxPopupLayout {
	anchor := picker_anchor(config.anchor, config.frame)
	m := picker_metrics(config.size)
	limits := popover_limits(config.window, select_popup_margin)
	requested := if config.menu_width > 0 { config.menu_width } else { anchor.width }
	width := math.max(math.min(requested, limits.right - limits.left), 0)
	hits := if config.loading { []PickerHit{} } else { combobox_matches(config, config.text) }
	rows := picker_rows(config.options, hits, config.separators, m)
	// The list stays inside the surface's one-point border.
	content := (if rows.len > 0 { picker_rows_height(rows) + m.inset * 2 } else { m.empty }) + 2
	natural := if config.max_height > 0 { math.min(content, config.max_height) } else { content }
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
	return ComboboxPopupLayout{
		surface: placement.frame
		list:    rect(1, 1, math.max(width - 2, 0), math.max(height - 2, 0))
		hits:    hits
		rows:    rows
	}
}

// combobox_popup draws the open list, or nothing while it is closed: an
// overlay to add after everything it may cover. Presses anywhere but on the
// list and the combobox itself emit combobox_dismiss_action(id); the combobox
// stays reachable, so the caret can still be placed in the field.
pub fn combobox_popup(config ComboboxConfig) !Element {
	combobox_validate(config)!
	if !config.state.open || !config.enabled {
		return component_finish(popover_closed(combobox_popup_id(config.id)))
	}
	layout := combobox_popup_layout(config)!
	theme := config.theme
	mut content := []Element{}
	if config.loading {
		content << picker_message(config.id, layout.list, config.loading_text, true, config.size,
			theme)
	} else if layout.rows.len == 0 {
		content << picker_message(config.id, layout.list, config.empty_text, false, config.size,
			theme)
	} else {
		content << picker_list(PickerListSpec{
			id:        config.id
			options:   config.options
			rows:      layout.rows
			width:     layout.list.width
			highlight: config.state.highlight
			selected:  if config.value.len > 0 { [config.value] } else { []string{} }
			size:      config.size
			theme:     theme
		}, layout.list, combobox_list_id(config.id))
	}
	caption := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		config.placeholder
	}
	window := config.window
	surface := picker_surface(component_part_id(config.id, 'surface'), layout.surface, content,
		'list', caption, config.size, theme)
	mut children := picker_backdrop_around(config.id, window, picker_anchor(config.anchor,
		config.frame), combobox_dismiss_action(config.id))
	children << Element{
		...surface
		frame: popover_translate(surface.frame, -window.x, -window.y)
	}
	return component_finish(view(combobox_popup_id(config.id), window, BoxStyle{
		transparent: true
	}, children))
}
