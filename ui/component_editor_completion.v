module ui2

import math

// Manual completions for the code editor, after GPUI Kit's ShowCompletions: a
// menu of suggestions that opens below the caret, refined by the identifier
// before it, moved with the arrow keys and accepted with Enter or Tab. The
// application decides when to open it (upstream binds no key by default) and
// supplies the items.

pub enum CodeCompletionKind {
	text
	keyword
	function
	method
	variable
	field
	type
	module
	constant
	snippet
}

// CodeCompletionItem is one suggestion. Accepting it replaces the identifier
// before the caret with `insert`, or with the label when insert is empty.
pub struct CodeCompletionItem {
pub:
	label  string
	kind   CodeCompletionKind
	detail string // Shown muted at the right: a signature, a type, a module.
	insert string
}

// CodeCompletionState is whether the menu is open and which of the filtered
// items is highlighted.
pub struct CodeCompletionState {
pub:
	open   bool
	active int
}

// CodeCompletionConfig places and fills the menu. It is an overlay: build it
// after everything it may cover, with the editor's window rectangle and its
// scroll positions, which the menu needs to find the caret on screen.
pub struct CodeCompletionConfig {
pub:
	editor CodeEditorConfig
	// origin is the editor's frame in window coordinates; its config frame is
	// in its parent's.
	origin Rect
	window Rect // Pass ui2.bounds().
	// scroll_offset is scroll_offset(code_editor_scroll_id(id)), and
	// hscroll_offset scroll_horizontal_offset(code_editor_hscroll_id(id)).
	scroll_offset  f64
	hscroll_offset f64
	items          []CodeCompletionItem
	state          CodeCompletionState
	max_rows       int = 8
	width          f64 // Zero fits the widest row, within limits.
	size           ComponentSize = .small
}

// code_completion_prefix is the identifier before the caret that the menu
// refines against: letters, digits, `_` and the language's extra word
// characters. It may be empty.
pub fn code_completion_prefix(text string, selection TextSelection, settings CodeEditSettings) CodeRange {
	runes := text.runes()
	rules := settings.language_rules()
	caret := clamp_int(selection.caret, 0, runes.len)
	mut start := caret
	for start > 0 && code_word_rune(runes[start - 1], rules) {
		start--
	}
	return CodeRange{start, caret}
}

struct CodeCompletionHit {
	item  CodeCompletionItem
	score int
}

// code_completion_filter keeps the items that match a prefix and orders them:
// the ones that start with it (exact case first), then the ones that contain
// its characters in order, each group in its original order.
pub fn code_completion_filter(items []CodeCompletionItem, prefix string) []CodeCompletionItem {
	if prefix.len == 0 {
		return items
	}
	lower := prefix.to_lower()
	mut hits := []CodeCompletionHit{}
	for index, item in items {
		score := if item.label.starts_with(prefix) {
			3000 - index
		} else if item.label.to_lower().starts_with(lower) {
			2000 - index
		} else if m := list_match(prefix, item.label, .fuzzy) {
			m.score - index
		} else {
			continue
		}
		hits << CodeCompletionHit{item, score}
	}
	hits.sort_with_compare(fn (a &CodeCompletionHit, b &CodeCompletionHit) int {
		return b.score - a.score
	})
	return hits.map(it.item)
}

// code_completion_items is what the menu lists for the editor's caret.
pub fn code_completion_items(config CodeCompletionConfig) []CodeCompletionItem {
	editor := config.editor
	prefix := code_completion_prefix(editor.text, editor.selection, code_editor_settings(editor))
	runes := editor.text.runes()
	return code_completion_filter(config.items, runes[prefix.start..prefix.end].string())
}

// CodeCompletionStep is what a key or press did: the state to store, and the
// edit that accepting an item makes.
pub struct CodeCompletionStep {
pub:
	state    CodeCompletionState
	edit     ?CodeEdit
	accepted bool
	item     CodeCompletionItem
}

// code_completion_show opens the menu with its first item highlighted, as the
// application's show-completions command should. A read-only or disabled
// editor gets none, as upstream issues no request for them, and neither does a
// prefix nothing matches.
pub fn code_completion_show(config CodeCompletionConfig) ?CodeCompletionStep {
	if config.editor.read_only || config.editor.disabled {
		return none
	}
	if config.state.open {
		// Already open: keep the highlight where it is.
		return CodeCompletionStep{
			state: config.state
		}
	}
	if code_completion_items(config).len == 0 {
		return none
	}
	return CodeCompletionStep{
		state: CodeCompletionState{
			open:   true
			active: 0
		}
	}
}

// code_completion_sync keeps an open menu in step with the text after an edit
// or a caret move: it stays open while the caret's prefix still matches
// something, with the highlight clamped, and closes otherwise (or when the
// selection is not a caret).
pub fn code_completion_sync(config CodeCompletionConfig) CodeCompletionState {
	if !config.state.open || !config.editor.selection.collapsed() {
		return CodeCompletionState{}
	}
	count := code_completion_items(config).len
	if count == 0 {
		return CodeCompletionState{}
	}
	return CodeCompletionState{
		open:   true
		active: clamp_int(config.state.active, 0, count - 1)
	}
}

// code_completion_accept replaces the caret's prefix with an item's text and
// puts the caret after it.
pub fn code_completion_accept(config CodeCompletionConfig, index int) ?CodeCompletionStep {
	items := code_completion_items(config)
	if index < 0 || index >= items.len {
		return none
	}
	editor := config.editor
	item := items[index]
	prefix := code_completion_prefix(editor.text, editor.selection, code_editor_settings(editor))
	insert := if item.insert.len > 0 { item.insert } else { item.label }
	caret := prefix.start + insert.runes().len
	edit := code_edit_replace(editor.text.runes(), prefix.start, prefix.end, insert, TextSelection{caret, caret})
	return CodeCompletionStep{
		state:    CodeCompletionState{}
		edit:     edit
		accepted: true
		item:     item
	}
}

fn code_completion_moved(active int) CodeCompletionStep {
	return CodeCompletionStep{
		state: CodeCompletionState{
			open:   true
			active: active
		}
	}
}

// code_completion_key moves the highlight from on_key_event while the menu is
// open (Up and Down wrap; Page Up and Page Down jump a page), accepts with
// Enter or Tab and closes with Escape. Consume the key when a step comes back.
// On AppKit, Enter and Tab reach the application only through on_key: route
// those through code_completion_text_key.
pub fn code_completion_key(config CodeCompletionConfig, event KeyEvent) ?CodeCompletionStep {
	if !config.state.open || event.cmd || event.ctrl || event.alt {
		return none
	}
	count := code_completion_items(config).len
	if count == 0 {
		return none
	}
	active := clamp_int(config.state.active, 0, count - 1)
	page := math.max(config.max_rows - 1, 1)
	match event.code {
		.up {
			return code_completion_moved((active - 1 + count) % count)
		}
		.down {
			return code_completion_moved((active + 1) % count)
		}
		.page_up {
			return code_completion_moved(math.max(active - page, 0))
		}
		.page_down {
			return code_completion_moved(math.min(active + page, count - 1))
		}
		.enter, .kp_enter, .tab {
			if event.shift {
				return none
			}
			return code_completion_accept(config, active)
		}
		.escape {
			return CodeCompletionStep{
				state: CodeCompletionState{}
			}
		}
		else {
			return none
		}
	}
}

// code_completion_text_key accepts the highlighted item for the keys a focused
// text area reports through on_key (`text:<id>:enter` and `text:<id>:tab` on
// AppKit). Call consume_text_key when a step comes back.
pub fn code_completion_text_key(config CodeCompletionConfig, key string) ?CodeCompletionStep {
	if !config.state.open {
		return none
	}
	prefix := 'text:' + code_editor_text_id(config.editor.id) + ':'
	if !key.starts_with(prefix) {
		return none
	}
	match key[prefix.len..] {
		'enter', 'tab' {
			count := code_completion_items(config).len
			if count == 0 {
				return none
			}
			return code_completion_accept(config, clamp_int(config.state.active, 0, count - 1))
		}
		else {
			return none
		}
	}
}

fn code_completion_row_action(id string, index int) string {
	return component_part_id(id, 'completion:${index}')
}

// code_completion_update accepts the item a press landed on, and ignores
// everything else.
pub fn code_completion_update(config CodeCompletionConfig, event string) ?CodeCompletionStep {
	if !config.state.open {
		return none
	}
	part := component_action_part(config.editor.id, event) or { return none }
	if !part.starts_with('completion:') {
		return none
	}
	count := code_completion_items(config).len
	if count == 0 {
		return none
	}
	index := component_parse_index(part['completion:'.len..], count - 1) or { return none }
	return code_completion_accept(config, index)
}

fn code_completion_symbol(kind CodeCompletionKind) string {
	return match kind {
		.text { 'textformat' }
		.keyword { 'key' }
		.function, .method { 'function' }
		.variable { 'textformat.abc' }
		.field { 'tag' }
		.type { 'curlybraces' }
		.module { 'square.stack.3d.up' }
		.constant { 'number' }
		.snippet { 'text.badge.plus' }
	}
}

fn code_completion_kind_color(kind CodeCompletionKind, theme CodeEditorTheme) u32 {
	return match kind {
		.text { theme.ui.muted_foreground }
		.keyword { theme.keyword }
		.function, .method { theme.function }
		.variable, .field { theme.property }
		.type { theme.type }
		.module { theme.attribute }
		.constant { theme.constant }
		.snippet { theme.string }
	}
}

// code_completion_anchor is the caret's prefix start in window coordinates,
// one line tall: the menu opens below it, its text under the word.
pub fn code_completion_anchor(config CodeCompletionConfig) Rect {
	editor := config.editor
	prefix := code_completion_prefix(editor.text, editor.selection, code_editor_settings(editor))
	r := code_editor_range_rect(editor, CodeRange{prefix.start, prefix.start})
	sideways := if editor.soft_wrap { 0.0 } else { config.hscroll_offset }
	return rect(config.origin.x + r.x - sideways, config.origin.y + r.y - config.scroll_offset,
		1, r.height)
}

// code_completion draws the menu below the caret (above it when there is no
// room) with the filtered items, the highlighted one filled. It draws nothing
// while closed or with nothing to show. Decode presses with
// code_completion_update.
pub fn code_completion(config CodeCompletionConfig) !Element {
	editor := config.editor
	component_validate_id(editor.id)!
	component_validate_frame(config.window)!
	id := component_part_id(editor.id, 'completion')
	items := code_completion_items(config)
	if !config.state.open || items.len == 0 {
		return component_finish(popover_closed(id))
	}
	m := component_metrics(config.size)
	theme := editor.theme
	ui := theme.ui
	code_style := TextStyle{
		...code_editor_text_style(editor)
		color:  ui.foreground
		size:   m.font_size
		valign: .middle
		lines:  1
	}
	detail_style := TextStyle{
		color:  ui.muted_foreground
		size:   m.font_size - 1
		valign: .middle
		lines:  1
	}
	row_h := m.height
	icon := m.font_size + 1
	rows := math.min(items.len, math.max(config.max_rows, 1))
	active := clamp_int(config.state.active, 0, items.len - 1)
	// The visible window of rows keeps the highlight in view.
	first := clamp_int(active - rows + 1, 0, items.len - rows)
	mut width := config.width
	if width <= 0 {
		mut widest := 0.0
		for item in items {
			w := measure_text_width(item.label, code_style) + if item.detail.len > 0 {
				measure_text_width(item.detail, detail_style) + 3 * m.gap
			} else {
				0.0
			}
			widest = math.max(widest, w)
		}
		width = math.min(math.max(widest + icon + 4 * m.gap + 8, 200), 480)
	}
	height := f64(rows) * row_h + 8
	anchor := code_completion_anchor(config)
	placement := popover_place(PopoverPlacementConfig{
		anchor: rect(anchor.x - icon - 2 * m.gap - 4, anchor.y, 1, anchor.height)
		window: config.window
		width:  width
		height: height
		side:   .bottom
		align:  .start
		offset: 2
		margin: 6
		radius: m.radius
		flip:   true
		shift:  true
	})!
	mut children := []Element{}
	for k in 0 .. rows {
		index := first + k
		item := items[index]
		on := index == active
		frame := rect(4, 4 + f64(k) * row_h, width - 8, row_h)
		fg := if on { ui.primary_foreground } else { ui.foreground }
		mut row := []Element{}
		row << inputs_symbol(code_completion_symbol(item.kind), inputs_centered_square(rect(m.gap,
			0, icon, row_h), icon), if on {
			fg
		} else {
			code_completion_kind_color(item.kind, theme)
		})
		text_x := m.gap * 2 + icon
		detail_w := if item.detail.len > 0 {
			math.min(measure_text_width(item.detail, detail_style), (width - text_x) * 0.45)
		} else {
			0.0
		}
		row << label('', item.label, rect(text_x, 0, math.max(frame.width - text_x - detail_w - 2 * m.gap,
			0), row_h), TextStyle{
			...code_style
			color: fg
		})
		if item.detail.len > 0 {
			row << label('', item.detail, rect(frame.width - detail_w - m.gap, 0, detail_w,
				row_h), TextStyle{
				...detail_style
				color: if on { ui.primary_foreground } else { ui.muted_foreground }
				align: .right
			})
		}
		children << Element{
			...button_view(code_completion_row_action(editor.id, index), frame, if on {
				BoxStyle{
					bg:     ui.primary
					radius: math.max(m.radius - 2, 2)
				}
			} else {
				BoxStyle{
					transparent: true
				}
			}, row)
			key:                 'row${index}'
			accessibility_role:  'option'
			accessibility_label: if item.detail.len > 0 {
				'${item.label}, ${item.detail}'
			} else {
				item.label
			}
			accessibility_value: if on { 'selected' } else { '' }
		}
	}
	box, mut panel := popover_panel(placement.frame, ui.background, ui.border, m.radius,
		true)
	panel << children
	return component_finish(Element{
		...view(id, placement.frame, box, panel)
		clickable:           true
		accessibility_role:  'listbox'
		accessibility_label: 'Suggestions'
	})
}
