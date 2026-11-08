// SPDX-License-Identifier: Apache-2.0
// A command palette after GPUI Kit's Command (Longbridge, copyright 2024 -
// 2026). Its behavior follows crates/component/src/command/state.rs: a query
// filters items by label and keywords, a group whose items all filter out hides
// its heading, the highlight resets to the first enabled item when the query
// changes, arrows wrap and skip disabled items, and Escape clears a non-empty
// query before it closes. The fuzzy scoring, recent items, layout and rendering
// are new UI2 code. See third_party/gpui-kit.
module ui2

import math

// command_palette is a searchable list of commands with groups, icons and
// shortcut hints, shown as a modal at the top of the window (the ⌘K palette)
// or, with modal: false, as a panel in the page. Build the modal last, as one
// of the final children of the screen.

// CommandPaletteItem is one command.
pub struct CommandPaletteItem {
pub:
	id          string // Identity: non-empty and unique; what the decoders report.
	label       string
	description string   // A muted second line.
	icon        string   // A symbol name (see symbol_known).
	shortcut    string   // An accelerator such as 'cmd+shift+p', shown ⇧⌘P on macOS and Ctrl+Shift+P elsewhere.
	group       string   // The heading the command is listed under.
	keywords    []string // Further words the search matches.
	checked     bool     // A check mark at the right end, where no shortcut is shown.
	enabled     bool = true
}

// CommandPaletteState is the palette's state: open (for the modal), the query
// and the highlighted command by id.
pub struct CommandPaletteState {
pub:
	open      bool
	query     string
	highlight string
}

pub struct CommandPaletteConfig {
pub:
	id    string
	state CommandPaletteState
	items []CommandPaletteItem
	// recent lists command ids, most recent first. While the query is empty
	// those commands are listed first under recent_label; command_palette_remember
	// keeps such a list.
	recent       []string
	recent_label string = 'Recent'
	// modal shows the palette over the window, at the top center of window,
	// above a backdrop. Without it the palette is a panel drawn at frame.
	modal    bool = true
	window   Rect // Modal: pass ui2.bounds().
	frame    Rect // Not modal: the panel, in its parent's coordinates.
	backdrop DialogBackdrop = .dim
	width    f64            = 560 // Modal: the palette's width, limited by the window.
	top      f64            = -1  // Modal: the distance from the window's top; -1 picks 12% of its height.
	// max_height bounds the modal's list, which scrolls past it; the window
	// limits it too. A panel's list fills the panel.
	max_height   f64             = 340
	searchable   bool            = true
	placeholder  string          = 'Type a command or search…'
	match_mode   PickerMatchMode = .fuzzy
	sort         bool            = true // With a query, list the best matches first.
	separators   bool            = true // Draw a line between groups.
	empty_text   string          = 'No results found.'
	loading      bool // Application-driven: show a spinner instead of the empty message.
	loading_text string        = 'Searching…'
	footer       bool          = true // Key hints and the number of results under the list.
	label        string        = 'Command palette'
	size         ComponentSize = .medium
	theme        ComponentTheme
}

// CommandPaletteStep is a decoded event: the next state and, when chosen is
// set, the command to run.
pub struct CommandPaletteStep {
pub:
	state  CommandPaletteState
	chosen bool
	item   CommandPaletteItem
	// focus is an id to focus once the tree is rebuilt: the search field of a
	// palette that just opened.
	focus string
}

// CommandPaletteMatch is a command the query shows, in display order, with the
// matched characters of its label.
pub struct CommandPaletteMatch {
pub:
	item   CommandPaletteItem
	group  string // The group it is listed under: recent_label for a recent command.
	score  int
	ranges []PickerRange
}

fn command_palette_search_group_id(id string) string {
	return component_part_id(id, 'search')
}

// command_palette_search_id is the id of the search field, for focus() and
// text(); it is also the action the field emits on each edit.
pub fn command_palette_search_id(id string) string {
	return input_group_field_id(command_palette_search_group_id(id))
}

// command_palette_list_id is the id of the list's scroll element while the
// commands are taller than the list, for scroll_to_rect.
pub fn command_palette_list_id(id string) string {
	return component_part_id(id, 'list')
}

pub fn command_palette_dismiss_action(id string) string {
	return component_part_id(id, 'dismiss')
}

pub fn command_palette_item_action(id string, item_id string) string {
	return component_part_id(id, picker_option_part(item_id))
}

// command_palette_shortcut reports whether a key event is the palette's
// shortcut: Command+K on macOS, Ctrl+K elsewhere.
pub fn command_palette_shortcut(event KeyEvent) bool {
	if event.code != .k || event.shift || event.alt {
		return false
	}
	$if macos {
		return event.cmd && !event.ctrl
	} $else {
		return event.ctrl && !event.cmd
	}
}

// command_palette_shortcut_label is that shortcut as the platform writes it,
// for a button or a hint: ⌘K on macOS, Ctrl+K elsewhere.
pub fn command_palette_shortcut_label() string {
	return menu_shortcut_label('cmd+k')
}

// command_palette_remember puts id first in a recent list, dropping its older
// entry and keeping at most limit ids (all of them when limit is zero).
pub fn command_palette_remember(recent []string, id string, limit int) []string {
	mut next := [id]
	for entry in recent {
		if entry != id && (limit <= 0 || next.len < limit) {
			next << entry
		}
	}
	return next
}

fn command_palette_validate(config CommandPaletteConfig) ! {
	component_validate_id(config.id)!
	if config.modal {
		component_validate_frame(config.window)!
	} else {
		component_validate_frame(config.frame)!
	}
	for value in [config.width, config.max_height] {
		if !component_finite(value) || value < 0 {
			return error('command palette width and max height must be finite and non-negative')
		}
	}
	if !component_finite(config.top) || (config.top < 0 && config.top != -1) {
		return error('command palette top must be non-negative, or -1 for the default')
	}
	mut ids := map[string]bool{}
	for index, item in config.items {
		if item.id.len == 0 {
			return error('command palette item ${index} has no id')
		}
		if item.id in ids {
			return error('duplicate command palette item id `${item.id}`')
		}
		ids[item.id] = true
		if item.icon.len > 0 && !symbol_known(item.icon) {
			return error('command `${item.id}` uses `${item.icon}`, which not every renderer can draw; pick a name from symbol_names()')
		}
	}
}

// CommandPaletteEntries are the items as options, recent ones moved to the
// front under the recent heading while the query is empty. sources maps an
// option back to its item.
struct CommandPaletteEntries {
	options []PickerOption
	sources []int
	hints   []string
	checked []string
}

fn command_palette_entries(config CommandPaletteConfig, query string) CommandPaletteEntries {
	mut order := []int{cap: config.items.len}
	mut recent_count := 0
	if picker_query(query, config.match_mode).len == 0 && config.recent.len > 0 {
		for id in config.recent {
			for index, item in config.items {
				if item.id == id && index !in order {
					order << index
				}
			}
		}
		recent_count = order.len
	}
	for index in 0 .. config.items.len {
		if index !in order {
			order << index
		}
	}
	mut options := []PickerOption{cap: order.len}
	mut sources := []int{cap: order.len}
	mut hints := []string{cap: order.len}
	mut checked := []string{}
	for position, index in order {
		item := config.items[index]
		options << PickerOption{
			value:       item.id
			label:       item.label
			description: item.description
			icon:        item.icon
			group:       if position < recent_count { config.recent_label } else { item.group }
			keywords:    item.keywords
			enabled:     item.enabled
		}
		sources << index
		hints << dropdown_menu_shortcut_text(item.shortcut)
		if item.checked {
			checked << item.id
		}
	}
	return CommandPaletteEntries{
		options: options
		sources: sources
		hints:   hints
		checked: checked
	}
}

fn command_palette_query(config CommandPaletteConfig) string {
	return if config.searchable { config.state.query } else { '' }
}

fn command_palette_hits(config CommandPaletteConfig, entries CommandPaletteEntries, query string) []PickerHit {
	return picker_filter(entries.options, query, config.match_mode, config.sort)
}

// command_palette_matches are the commands the current query shows, in the
// order the palette lists them.
pub fn command_palette_matches(config CommandPaletteConfig) []CommandPaletteMatch {
	query := command_palette_query(config)
	entries := command_palette_entries(config, query)
	hits := command_palette_hits(config, entries, query)
	mut matches := []CommandPaletteMatch{cap: hits.len}
	for hit in hits {
		matches << CommandPaletteMatch{
			item:   config.items[entries.sources[hit.index]]
			group:  entries.options[hit.index].group
			score:  hit.score
			ranges: hit.ranges
		}
	}
	return matches
}

fn command_palette_active(config CommandPaletteConfig) bool {
	return config.state.open || !config.modal
}

fn command_palette_first(config CommandPaletteConfig, query string) string {
	entries := command_palette_entries(config, query)
	return picker_first_value(entries.options, command_palette_hits(config, entries, query))
}

// command_palette_open opens the palette with an empty query and the first
// command highlighted. Focus step.focus, the search field, after rebuilding.
pub fn command_palette_open(config CommandPaletteConfig) CommandPaletteStep {
	return CommandPaletteStep{
		state: CommandPaletteState{
			open:      true
			highlight: command_palette_first(config, '')
		}
		focus: if config.searchable { command_palette_search_id(config.id) } else { '' }
	}
}

fn command_palette_closed() CommandPaletteStep {
	return CommandPaletteStep{}
}

// command_palette_toggle_key opens a closed modal palette, or closes an open
// one, on command_palette_shortcut. Call it from on_key_event before anything
// else and consume the key when it returns a step.
pub fn command_palette_toggle_key(config CommandPaletteConfig, event KeyEvent) ?CommandPaletteStep {
	if !config.modal || !command_palette_shortcut(event) {
		return none
	}
	return if config.state.open { command_palette_closed() } else { command_palette_open(config) }
}

// command_palette_search applies an edit of the search field: read it with
// text(command_palette_search_id(id)) when that id arrives as an event. The
// highlight moves to the first command the query shows.
pub fn command_palette_search(config CommandPaletteConfig, query string) CommandPaletteStep {
	return CommandPaletteStep{
		state: CommandPaletteState{
			open:      config.state.open
			query:     query
			highlight: command_palette_first(config, query)
		}
	}
}

fn command_palette_moved(config CommandPaletteConfig, value string) ?CommandPaletteStep {
	if value.len == 0 || value == config.state.highlight {
		return none
	}
	return CommandPaletteStep{
		state: CommandPaletteState{
			...config.state
			highlight: value
		}
	}
}

// command_palette_choose runs the command with id when the palette shows it
// enabled. A modal palette closes; a panel keeps its query.
fn command_palette_choose(config CommandPaletteConfig, id string) ?CommandPaletteStep {
	query := command_palette_query(config)
	entries := command_palette_entries(config, query)
	hits := command_palette_hits(config, entries, query)
	position := picker_hit_of(entries.options, hits, id)
	if position < 0 || !picker_navigable(entries.options, hits[position]) {
		return none
	}
	return CommandPaletteStep{
		state:  if config.modal { CommandPaletteState{} } else { config.state }
		chosen: true
		item:   config.items[entries.sources[hits[position].index]]
	}
}

// command_palette_update decodes an event the palette emitted against the
// config it was built with: a press on a command (choose it), a pointer
// entering one (highlight), a press on the backdrop (close) and Return in the
// search field (choose the highlighted command). It returns none for events
// that are not the palette's, are forged or malformed, name hidden or disabled
// commands, or change nothing. Edits of the search field go to
// command_palette_search.
pub fn command_palette_update(config CommandPaletteConfig, event string) ?CommandPaletteStep {
	if !command_palette_active(config) {
		return none
	}
	if pointer := parse_pointer_event(event) {
		if pointer.phase != 'enter' {
			return none
		}
		part := component_action_part(config.id, pointer.action) or { return none }
		id := picker_value_from_part('option:', part) or { return none }
		query := command_palette_query(config)
		entries := command_palette_entries(config, query)
		hits := command_palette_hits(config, entries, query)
		position := picker_hit_of(entries.options, hits, id)
		if position < 0 || !picker_navigable(entries.options, hits[position]) {
			return none
		}
		return command_palette_moved(config, id)
	}
	part := component_action_part(config.id, event) or { return none }
	if part == 'dismiss' {
		return if config.modal { command_palette_closed() } else { none }
	}
	if part == 'search:component:submit' {
		return command_palette_choose(config, config.state.highlight)
	}
	id := picker_value_from_part('option:', part) or { return none }
	return command_palette_choose(config, id)
}

// command_palette_key handles a key while the palette is open (or, for a
// panel, while its field has focus), for on_key_event: Up and Down move the
// highlight, wrapping and skipping disabled commands; Page Up and Page Down
// jump to the ends; Enter runs the highlighted command; Escape clears a
// non-empty query and otherwise closes a modal palette. Tab is left to a focus
// trap (command_palette_focus_trap). It returns none for keys it leaves alone;
// consume the key otherwise. On AppKit a focused field keeps Return, which
// arrives as the field's submit action through command_palette_update instead.
pub fn command_palette_key(config CommandPaletteConfig, event KeyEvent) ?CommandPaletteStep {
	if !command_palette_active(config) || !picker_plain_key(event) || event.shift {
		return none
	}
	if event.code == .escape {
		if config.searchable && config.state.query.len > 0 {
			return command_palette_search(config, '')
		}
		return if config.modal { command_palette_closed() } else { none }
	}
	query := command_palette_query(config)
	entries := command_palette_entries(config, query)
	hits := command_palette_hits(config, entries, query)
	current := config.state.highlight
	match event.code {
		.down {
			return command_palette_moved(config, picker_step_value(entries.options, hits, current,
				1))
		}
		.up {
			return command_palette_moved(config, picker_step_value(entries.options, hits, current,
				-1))
		}
		.page_up, .page_down {
			return command_palette_moved(config, picker_edge_value(entries.options, hits,
				event.code == .page_down))
		}
		.enter, .kp_enter {
			return command_palette_choose(config, current)
		}
		else {
			return none
		}
	}
}

// command_palette_focus_trap keeps Tab on the search field while the modal
// palette is open, so focus cannot wander to the page behind it.
pub fn command_palette_focus_trap(config CommandPaletteConfig) FocusTrap {
	return FocusTrap{
		ids:     if config.searchable { [command_palette_search_id(config.id)] } else { []string{} }
		enabled: config.modal && config.state.open
	}
}

// ── Layout ─────────────────────────────────────────────────────────

// CommandPaletteLayout places the palette. surface is in window coordinates
// for the modal and in the frame's parent's for a panel; the other rectangles
// are relative to the surface, and rows to the list's content.
struct CommandPaletteLayout {
	surface Rect
	search  Rect
	divider f64 // y of the line under the search field; -1 without one
	list    Rect
	footer  Rect
	entries CommandPaletteEntries
	hits    []PickerHit
	rows    []PickerRow
}

const command_palette_margin = 16.0

fn command_palette_footer_height(size ComponentSize) f64 {
	return component_metrics(size).height + 2
}

fn command_palette_layout(config CommandPaletteConfig) CommandPaletteLayout {
	m := picker_metrics(config.size)
	metrics := component_metrics(config.size)
	query := command_palette_query(config)
	entries := command_palette_entries(config, query)
	hits := command_palette_hits(config, entries, query)
	rows := picker_rows(entries.options, hits, config.separators, m)
	window := config.window
	width := if config.modal {
		math.max(math.min(config.width, window.width - command_palette_margin * 2), 0)
	} else {
		config.frame.width
	}
	pad := metrics.padding
	search := if config.searchable {
		rect(pad, pad, math.max(width - pad * 2, 0), metrics.height + 4)
	} else {
		Rect{}
	}
	divider := if config.searchable { search.y + search.height + pad } else { -1.0 }
	// The list stays inside the surface's one-point border.
	list_top := if config.searchable { divider + 1 } else { 1.0 }
	bottom := if config.footer { 0.0 } else { 1.0 }
	footer_height := if config.footer { command_palette_footer_height(config.size) } else { 0.0 }
	content := if rows.len > 0 { picker_rows_height(rows) + m.inset * 2 } else { m.empty }
	mut surface := Rect{}
	mut list_height := 0.0
	if config.modal {
		top := if config.top >= 0 {
			config.top
		} else {
			math.max(command_palette_margin, math.round(window.height * 0.12))
		}
		room := math.max(window.height - top - command_palette_margin - list_top - footer_height - bottom,
			0)
		list_height = math.min(math.min(content, if config.max_height > 0 {
			config.max_height
		} else {
			content
		}), room)
		surface = rect(window.x + math.round((window.width - width) / 2), window.y + top,
			width, list_top + list_height + footer_height + bottom)
	} else {
		list_height = math.max(config.frame.height - list_top - footer_height - bottom, 0)
		surface = config.frame
	}
	return CommandPaletteLayout{
		surface: surface
		search:  search
		divider: divider
		list:    rect(1, list_top, math.max(width - 2, 0), list_height)
		footer:  if config.footer {
			rect(0, list_top + list_height, width, footer_height)
		} else {
			Rect{}
		}
		entries: entries
		hits:    hits
		rows:    rows
	}
}

// command_palette_highlight_rect is the highlighted command's row in the
// coordinates of the list's content, for
// scroll_to_rect(command_palette_list_id(id), ...).
pub fn command_palette_highlight_rect(config CommandPaletteConfig) ?Rect {
	if !command_palette_active(config) {
		return none
	}
	layout := command_palette_layout(config)
	return picker_row_rect(layout.entries.options, layout.rows, config.state.highlight,
		layout.list.width, picker_metrics(config.size))
}

// ── Rendering ──────────────────────────────────────────────────────

// command_palette_key_hint is a key cap followed by what the key does.
fn command_palette_key_hint(keys string, caption string, x f64, height f64, size f64, theme ComponentTheme) ([]Element, f64) {
	cap_height := math.round(size + 8)
	cap_width := math.max(math.ceil(dropdown_menu_hint_width(keys, size) + 8 + picker_label_slack),
		cap_height)
	y := math.round((height - cap_height) / 2)
	text_width := math.ceil(picker_text_width(caption, size) + picker_label_slack)
	elements := [
		view('', rect(x, y, cap_width, cap_height), BoxStyle{
			...component_box(theme.muted, theme.border, 4)
		}, [
			label('', keys, rect(0, 0, cap_width, cap_height), TextStyle{
				color: theme.muted_foreground
				size:  size
				align: .center
			}),
		]),
		label('', caption, rect(x + cap_width + 6, 0, text_width, height), TextStyle{
			color: theme.muted_foreground
			size:  size
		}),
	]
	return elements, x + cap_width + 6 + text_width + 12
}

fn command_palette_footer(config CommandPaletteConfig, frame Rect, count int) Element {
	m := picker_metrics(config.size)
	theme := config.theme
	size := m.hint_size
	mut children := [
		view('', rect(0, 0, frame.width, 1), BoxStyle{ bg: theme.border }, []Element{}),
	]
	mut x := m.padding + m.inset
	mut hints := [['↑↓', 'Navigate'], ['↵', 'Run']]
	if config.modal {
		hints << ['esc', 'Close']
	}
	for hint in hints {
		parts, next := command_palette_key_hint(hint[0], hint[1], x, frame.height, size, theme)
		children << parts
		x = next
	}
	right := rect(x, 0, math.max(frame.width - x - m.padding - m.inset, 0), frame.height)
	if config.loading {
		diameter := loading_spinner_diameter(.small)
		children << loading_spinner(
			id:         component_part_id(config.id, 'footer-spinner')
			frame:      rect(right.x + right.width - diameter, (frame.height - diameter) / 2,
				diameter, diameter)
			size:       .small
			background: theme.background
			theme:      theme
		) or { view('', Rect{}, BoxStyle{ transparent: true }, []Element{}) }
	} else {
		children << label('', if count == 1 { '1 result' } else { '${count} results' }, right,
			TextStyle{
				color: theme.muted_foreground
				size:  size
				align: .right
			})
	}
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		key:                 'footer'
		accessibility_role:  'status'
		accessibility_label: '${count} results'
	}
}

fn command_palette_content(config CommandPaletteConfig, layout CommandPaletteLayout) ![]Element {
	theme := config.theme
	mut content := []Element{}
	if config.searchable {
		content << Element{
			...input_group(
				id:                  command_palette_search_group_id(config.id)
				frame:               layout.search
				text:                config.state.query
				placeholder:         config.placeholder
				addons:              [
					InputGroupAddon{
						id:   'search'
						kind: .icon
						icon: 'magnifyingglass'
					},
				]
				accessibility_label: config.placeholder
				size:                config.size
				theme:               theme
			)!
			key: 'search'
		}
		content << Element{
			...view('', rect(0, layout.divider, layout.surface.width, 1), BoxStyle{
				bg: theme.border
			}, []Element{})
			key: 'divider'
		}
	}
	if layout.rows.len == 0 {
		content << picker_message(config.id, layout.list, if config.loading {
			config.loading_text
		} else {
			config.empty_text
		}, config.loading, config.size, theme)
	} else {
		content << picker_list(PickerListSpec{
			id:        config.id
			options:   layout.entries.options
			rows:      layout.rows
			width:     layout.list.width
			highlight: config.state.highlight
			selected:  layout.entries.checked
			hints:     layout.entries.hints
			size:      config.size
			theme:     theme
		}, layout.list, command_palette_list_id(config.id))
	}
	if config.footer {
		content << command_palette_footer(config, layout.footer, layout.hits.len)
	}
	return content
}

// command_palette draws the palette: over the window when modal (nothing
// while closed), or as a panel at frame. Pass its events to
// command_palette_update, edits of its field to command_palette_search and keys
// to command_palette_key, store the state they return and rebuild.
pub fn command_palette(config CommandPaletteConfig) !Element {
	command_palette_validate(config)!
	if config.modal && !config.state.open {
		return component_finish(popover_closed(config.id))
	}
	layout := command_palette_layout(config)
	content := command_palette_content(config, layout)!
	theme := config.theme
	m := picker_metrics(config.size)
	box, mut children := popover_panel(layout.surface, theme.background, theme.border,
		m.surface_rad + 2, config.modal)
	children << content
	if !config.modal {
		return component_finish(Element{
			...view(config.id, layout.surface, box, children)
			accessibility_role:  'group'
			accessibility_label: config.label
		})
	}
	window := config.window
	surface := Element{
		...view(component_part_id(config.id, 'surface'), popover_translate(layout.surface,
			-window.x, -window.y), box, children)
		key:                 'surface'
		clickable:           true
		accessibility_role:  'dialog'
		accessibility_label: config.label
	}
	// Without a backdrop the palette covers only itself, so the page around it
	// keeps its clicks and hover.
	if config.backdrop == .none {
		return component_finish(Element{
			...surface
			id:    config.id
			frame: layout.surface
			key:   ''
		})
	}
	backdrop := Element{
		...button(component_part_id(config.id, 'backdrop'), '', rect(0, 0, window.width,
			window.height), dialog_backdrop_box(config.backdrop, theme), TextStyle{})
		action_id:          command_palette_dismiss_action(config.id)
		key:                'backdrop'
		accessibility_role: 'presentation'
	}
	return component_finish(Element{
		...view(config.id, window, BoxStyle{ transparent: true }, [backdrop, surface])
		accessibility_role:  'dialog'
		accessibility_label: config.label
	})
}
