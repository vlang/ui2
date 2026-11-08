module main

import os
import ui2

// A code editor after GPUI Kit's Editor: V source with highlighting, a gutter
// of line numbers with diagnostic and fold markers, find and replace, a
// diagnostic, and a completion menu at the caret. The toolbar switches the
// language, the gutter, soft wrap, read-only and the theme.
//
// For screenshots, UI2_EDITOR_DARK=1 starts dark, UI2_EDITOR_LANG=json (or
// markdown, python) on another language, UI2_EDITOR_WRAP=1 with soft wrap and
// UI2_EDITOR_REPLACE=1 with the replace row open.

const editor_id = 'editor'
const snippet_id = 'snippet'

const v_source = "module main

import ui2
import math

// Counter keeps a count and the step it grows by.
@[heap]
struct Counter {
mut:
	count int
	step  int = 1
	title string = 'Clicks'
}

const max_count = 1_000

fn (mut c Counter) increment() {
	c.count = math.min(c.count + c.step, max_count)
}

fn (c &Counter) label() string {
	return '\${c.title}: \${c.count}'
}

fn (mut c Counter) reset() {
	c.count = 0
}

fn main() {
	mut counter := &Counter{
		step: 2
	}
	for i in 0 .. 3 {
		counter.increment()
	}
	println(counter.label())
	counter.
	ui2.run_window(counter.title, 320, 200, fn [counter] () ui2.Element {
		return ui2.label('', counter.label(), ui2.rect(16, 16, 200, 24), ui2.TextStyle{})
	}, fn (event string) {})
}
"

const json_source = '{
	"name": "ui2-editor",
	"version": "0.3.0",
	"private": true,
	"keywords": ["editor", "gpui", "v"],
	"settings": {
		"tab_size": 4,
		"soft_wrap": false,
		"theme": { "light": "GPUI Light", "dark": "GPUI Dark" }
	},
	"contributors": [
		{ "name": "Ada", "commits": 128 },
		{ "name": "Linus", "commits": 64.5 }
	],
	"license": null
}
'

const markdown_source = "# Code editor

The editor is a **rich text area** with a gutter beside it, both in one
scroll. Highlighting comes from `code_highlight_runs`.

## Features

- Syntax highlighting for *ten* languages
- [Search](https://github.com/vlang/ui2) with regular expressions
- Diagnostics and completions

```v
fn main() {
	println('fenced code is highlighted too')
}
```

> Tip: press Cmd+F to search.
"

const python_source = 'from dataclasses import dataclass


@dataclass
class Counter:
    """Counts clicks."""
    count: int = 0
    step: int = 1

    def increment(self) -> None:
        self.count += self.step

    def label(self) -> str:
        return f"Count: {self.count}"


def main():
    counter = Counter(step=2)
    for _ in range(3):
        counter.increment()
    print(counter.label())  # Count: 6


if __name__ == "__main__":
    main()
'

const snippet_source = '{ "tab_size": 4, "hard_tabs": true }'

const languages = [ui2.CodeLanguage.v, .json, .markdown, .python]

// Doc is one language's document: its text, selection and annotations.
struct Doc {
mut:
	text        string
	selection   ui2.TextSelection
	diagnostics []ui2.CodeDiagnostic
}

@[heap]
struct App {
mut:
	dark         bool
	language     ui2.CodeLanguage = .v
	docs         map[string]Doc
	line_numbers bool = true
	soft_wrap    bool
	read_only    bool
	focused      bool
	search       ui2.CodeSearchState
	completion   ui2.CodeCompletionState
	applying     bool
	status       string
	ready        bool
	// The text area's selection as last read, to tell a move of its own from
	// one the application already knows about.
	native      ui2.TextSelection
	native_seen bool
}

const app_state = &App{}

fn app() &App {
	return unsafe { app_state }
}

fn offset_after(text string, needle string) int {
	index := text.index(needle) or { return 0 }
	return text[..index + needle.len].runes().len
}

fn range_of(text string, needle string) ui2.CodeRange {
	index := text.index(needle) or { return ui2.CodeRange{} }
	start := text[..index].runes().len
	return ui2.CodeRange{start, start + needle.runes().len}
}

fn init_docs(mut a App) {
	caret := offset_after(v_source, 'counter.\n') - 1
	dot := range_of(v_source, '\tcounter.\n\tui2')
	unused := range_of(v_source, 'i in 0')
	a.docs = {
		'v':        Doc{
			text:        v_source
			selection:   ui2.TextSelection{caret, caret}
			diagnostics: [
				ui2.CodeDiagnostic{
					start:    dot.start + 1
					end:      dot.start + 9
					severity: .error
					message:  'unexpected newline, expecting a field or method name'
					source:   'v'
				},
				ui2.CodeDiagnostic{
					start:    unused.start
					end:      unused.start + 1
					severity: .warning
					message:  'unused variable: `i`'
					source:   'v'
				},
			]
		}
		'json':     Doc{
			text: json_source
		}
		'markdown': Doc{
			text: markdown_source
		}
		'python':   Doc{
			text:        python_source
			diagnostics: [
				ui2.CodeDiagnostic{
					start:    range_of(python_source, '"""Counts clicks."""').start
					end:      range_of(python_source, '"""Counts clicks."""').end
					severity: .info
					message:  'docstring could say what a step is'
					source:   'pydoc'
				},
			]
		}
	}
	query := 'counter'
	matches := ui2.code_search(v_source, query, ui2.CodeSearchOptions{}) or { [] }
	a.search = ui2.CodeSearchState{
		open:    true
		query:   query
		current: ui2.code_search_next_index(matches, caret, true)
	}
	a.completion = ui2.CodeCompletionState{
		open: true
	}
	a.dark = os.getenv('UI2_EDITOR_DARK') == '1'
	a.soft_wrap = os.getenv('UI2_EDITOR_WRAP') == '1'
	if os.getenv('UI2_EDITOR_REPLACE') == '1' {
		a.search = ui2.CodeSearchState{
			...a.search
			replace:     true
			replacement: 'tally'
		}
	}
	lang := os.getenv('UI2_EDITOR_LANG')
	if lang.len > 0 {
		a.language = ui2.code_language(lang)
		a.completion = ui2.CodeCompletionState{}
		a.search = ui2.CodeSearchState{
			...a.search
			current: -1
		}
	}
}

fn (a &App) doc() Doc {
	return a.docs[a.language.id()] or { Doc{} }
}

fn (mut a App) set_doc(doc Doc) {
	a.docs[a.language.id()] = doc
}

// ── Layout ─────────────────────────────────────────────────────────────────

struct Layout {
	width   f64
	height  f64
	editor  ui2.Rect
	side    ui2.Rect
	status  ui2.Rect
	toolbar f64
}

fn layout() Layout {
	win := ui2.bounds()
	side_w := 300.0
	top := 60.0
	status_h := 30.0
	return Layout{
		width:   win.width
		height:  win.height
		editor:  ui2.rect(16, top, win.width - side_w - 48, win.height - top - status_h - 24)
		side:    ui2.rect(win.width - side_w - 16, top, side_w, win.height - top - status_h - 24)
		status:  ui2.rect(16, win.height - status_h - 12, win.width - 32, status_h)
		toolbar: top
	}
}

fn editor_config() ui2.CodeEditorConfig {
	a := app()
	doc := a.doc()
	return ui2.CodeEditorConfig{
		id:                 editor_id
		frame:              layout().editor
		text:               doc.text
		selection:          doc.selection
		focused:            a.focused
		language:           a.language
		hard_tabs:          a.language in [.v, .go, .json]
		tab_size:           4
		line_numbers:       a.line_numbers
		folding:            true
		soft_wrap:          a.soft_wrap
		read_only:          a.read_only
		inline_diagnostics: true
		diagnostics:        doc.diagnostics
		search:             a.search
		theme:              ui2.code_editor_theme(a.dark)
		label:              '${a.language.title()} source'
	}
}

fn completion_items(language ui2.CodeLanguage) []ui2.CodeCompletionItem {
	return match language {
		.v {
			[
				ui2.CodeCompletionItem{
					label:  'count'
					kind:   .field
					detail: 'int'
				},
				ui2.CodeCompletionItem{
					label:  'step'
					kind:   .field
					detail: 'int'
				},
				ui2.CodeCompletionItem{
					label:  'title'
					kind:   .field
					detail: 'string'
				},
				ui2.CodeCompletionItem{
					label:  'increment'
					kind:   .method
					detail: 'fn ()'
					insert: 'increment()'
				},
				ui2.CodeCompletionItem{
					label:  'label'
					kind:   .method
					detail: 'fn () string'
					insert: 'label()'
				},
				ui2.CodeCompletionItem{
					label:  'reset'
					kind:   .method
					detail: 'fn ()'
					insert: 'reset()'
				},
			]
		}
		.python {
			[
				ui2.CodeCompletionItem{
					label:  'count'
					kind:   .field
					detail: 'int'
				},
				ui2.CodeCompletionItem{
					label:  'increment'
					kind:   .method
					detail: '() -> None'
					insert: 'increment()'
				},
				ui2.CodeCompletionItem{
					label:  'label'
					kind:   .method
					detail: '() -> str'
					insert: 'label()'
				},
				ui2.CodeCompletionItem{
					label: 'print'
					kind:  .function
				},
				ui2.CodeCompletionItem{
					label: 'range'
					kind:  .type
				},
			]
		}
		else {
			[]ui2.CodeCompletionItem{}
		}
	}
}

fn completion_config() ui2.CodeCompletionConfig {
	a := app()
	cfg := editor_config()
	return ui2.CodeCompletionConfig{
		editor:         cfg
		origin:         cfg.frame
		window:         ui2.bounds()
		scroll_offset:  ui2.scroll_offset(ui2.code_editor_scroll_id(editor_id))
		hscroll_offset: ui2.scroll_horizontal_offset(ui2.code_editor_hscroll_id(editor_id))
		items:          completion_items(a.language)
		state:          a.completion
	}
}

// ── Building ───────────────────────────────────────────────────────────────

fn segment(id string, title string, frame ui2.Rect, on bool, theme ui2.ComponentTheme) ui2.Element {
	return ui2.button_view(id, frame, ui2.BoxStyle{
		bg:            if on { theme.primary } else { theme.muted }
		radius:        6
		border_color:  if on { theme.primary } else { theme.border }
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, [
		ui2.label('', title, ui2.rect(0, 0, frame.width, frame.height), ui2.TextStyle{
			color: if on { theme.primary_foreground } else { theme.foreground }
			size:  13
			bold:  on
			align: .center
		}),
	])
}

fn toolbar(l Layout, theme ui2.ComponentTheme) []ui2.Element {
	a := app()
	mut out := [
		ui2.label('', 'Editor', ui2.rect(16, 14, 90, 30), ui2.TextStyle{
			color: theme.foreground
			size:  20
			bold:  true
		}),
	]
	mut x := 110.0
	for language in languages {
		w := ui2.measure_text_width(language.title(), ui2.TextStyle{ size: 13, bold: true }) + 24
		out << segment('lang:${language.id()}', language.title(), ui2.rect(x, 16, w, 28),
			a.language == language, theme)
		x += w + 6
	}
	x += 18
	for toggle in [['numbers', 'Line numbers'], ['wrap', 'Soft wrap'], ['readonly', 'Read-only']] {
		on := match toggle[0] {
			'numbers' { a.line_numbers }
			'wrap' { a.soft_wrap }
			else { a.read_only }
		}
		w := ui2.measure_text_width(toggle[1], ui2.TextStyle{ size: 13, bold: true }) + 24
		out << segment('toggle:${toggle[0]}', toggle[1], ui2.rect(x, 16, w, 28), on, theme)
		x += w + 6
	}
	out << ui2.with_tooltip(segment('theme', if a.dark { 'Light' } else { 'Dark' }, ui2.rect(l.width - 90,
		16, 74, 28), false, theme), 'Switch between the light and dark theme')
	return out
}

fn severity_name(severity ui2.CodeDiagnosticSeverity) string {
	return match severity {
		.error { 'Error' }
		.warning { 'Warning' }
		.info { 'Info' }
		.hint { 'Hint' }
	}
}

fn side_panel(l Layout, theme ui2.ComponentTheme, editor_theme ui2.CodeEditorTheme) []ui2.Element {
	a := app()
	doc := a.doc()
	side := l.side
	mut out := [
		ui2.label('', 'Problems', ui2.rect(side.x, side.y, side.width, 22), ui2.TextStyle{
			color: theme.foreground
			size:  15
			bold:  true
		}),
	]
	mut y := side.y + 28
	if doc.diagnostics.len == 0 {
		out << ui2.label('', 'No problems in this file.', ui2.rect(side.x, y, side.width, 20),
			ui2.TextStyle{
				color: theme.muted_foreground
				size:  13
			})
		y += 28
	}
	for index, d in doc.diagnostics {
		pos := ui2.code_position(doc.text, d.start)
		color, _ := editor_theme.severity_colors(d.severity)
		frame := ui2.rect(side.x, y, side.width, 52)
		out << ui2.button_view('problem:${index}', frame, ui2.BoxStyle{
			bg:            theme.muted
			radius:        6
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, [
			ui2.label('', '${severity_name(d.severity)} · line ${pos.line + 1}, column ${pos.column + 1}',
				ui2.rect(10, 6, side.width - 20, 18), ui2.TextStyle{
					color: color
					size:  12
					bold:  true
				}),
			ui2.label('', d.message, ui2.rect(10, 26, side.width - 20, 18), ui2.TextStyle{
				color: theme.foreground
				size:  12
			}),
		])
		y += 60
	}
	y += 12
	out << ui2.label('', 'Read-only snippet, sized to content', ui2.rect(side.x, y, side.width,
		22), ui2.TextStyle{
		color: theme.foreground
		size:  15
		bold:  true
	})
	y += 28
	snippet := ui2.CodeEditorConfig{
		id:           snippet_id
		frame:        ui2.rect(side.x, y, side.width, 0)
		text:         snippet_source
		language:     .json
		read_only:    true
		line_numbers: false
		soft_wrap:    true
		current_line: false
		size:         .small
		theme:        editor_theme
		label:        'Settings snippet'
	}
	height := ui2.code_editor_content_height(snippet)
	out << ui2.code_editor(ui2.CodeEditorConfig{
		...snippet
		frame: ui2.rect(side.x, y, side.width, height)
	}) or { panic(err) }
	y += height + 20
	out << ui2.label('', 'Keys', ui2.rect(side.x, y, side.width, 22), ui2.TextStyle{
		color: theme.foreground
		size:  15
		bold:  true
	})
	y += 26
	keys := [
		['⌘F / ⌥⌘F', 'Find / replace'],
		['⌘G / ⇧⌘G', 'Next / previous match'],
		['⌘/', 'Toggle comment'],
		['⌥↑ / ⌥↓', 'Move lines'],
		['⇧⌥↓ / ⌘⇧K', 'Duplicate / delete lines'],
		['⌘L / ⌘D', 'Select line / word'],
		['⌃Space', 'Show completions'],
	]
	for row in keys {
		out << ui2.label('', row[0], ui2.rect(side.x, y, 120, 18), ui2.TextStyle{
			color: theme.foreground
			size:  12
			bold:  true
		})
		out << ui2.label('', row[1], ui2.rect(side.x + 124, y, side.width - 124, 18),
			ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
			})
		y += 20
	}
	return out
}

fn status_bar(l Layout, theme ui2.ComponentTheme) ui2.Element {
	a := app()
	doc := a.doc()
	pos := ui2.code_position(doc.text, doc.selection.caret)
	mut errors := 0
	mut warnings := 0
	for d in doc.diagnostics {
		if d.severity == .error {
			errors++
		} else if d.severity == .warning {
			warnings++
		}
	}
	indent := if a.language in [.v, .go, .json] { 'Tabs' } else { 'Spaces: 4' }
	left := 'Ln ${pos.line + 1}, Col ${pos.column + 1}    ${indent}    ${a.language.title()}'
	right := if a.status.len > 0 { a.status } else { '${errors} errors, ${warnings} warnings' }
	return ui2.view('', l.status, ui2.BoxStyle{
		bg:     theme.muted
		radius: 6
	}, [
		ui2.label('', left, ui2.rect(12, 0, l.status.width / 2, l.status.height), ui2.TextStyle{
			color: theme.foreground
			size:  12
		}),
		ui2.label('', right, ui2.rect(l.status.width / 2, 0, l.status.width / 2 - 12, l.status.height),
			ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
				align: .right
			}),
	])
}

// sync_selection reads the text area's selection, which moves with clicks and
// arrow keys without an event, so the current line, the caret and the status
// bar follow it.
fn sync_selection() {
	mut a := app()
	tid := ui2.code_editor_text_id(editor_id)
	was_focused := a.focused
	a.focused = ui2.focused_text_area_id() == tid
	doc := a.doc()
	if !a.ready || ui2.text(tid) != doc.text {
		return
	}
	sel := ui2.code_editor_selection_from_native(doc.text, ui2.text_area_caret(tid), ui2.text_area_selection_length(tid))
	// The first reading is only a baseline: where the demo put the caret stays
	// until the person moves it or clicks into the text.
	if !a.native_seen {
		a.native_seen = true
		a.native = sel
		return
	}
	if sel == a.native && (was_focused || !a.focused) {
		return
	}
	a.native = sel
	if sel != doc.selection {
		a.set_doc(Doc{
			...doc
			selection: sel
		})
		// The caret moved by a click or a key the editor left alone: the menu
		// belonged to where it was.
		a.completion = ui2.CodeCompletionState{}
	}
}

fn build() ui2.Element {
	sync_selection()
	a := app()
	editor_theme := ui2.code_editor_theme(a.dark)
	theme := editor_theme.ui
	l := layout()
	mut children := toolbar(l, theme)
	children << ui2.code_editor(editor_config()) or { panic(err) }
	children << side_panel(l, theme, editor_theme)
	children << status_bar(l, theme)
	// The completion menu is an overlay: last, over everything.
	children << ui2.code_completion(completion_config()) or { panic(err) }
	return ui2.screen(theme.background, children)
}

// ── Applying edits ─────────────────────────────────────────────────────────

fn reveal(range ui2.CodeRange) {
	ui2.refresh()
	for r in ui2.code_editor_reveal(editor_config(), range) {
		ui2.scroll_to_rect(r.id, r.rect.x, r.rect.y, r.rect.width, r.rect.height)
	}
}

// apply puts an edit into the text area through insert_text_area_text, which
// keeps it undoable, and moves the annotations along with it.
fn apply(edit ui2.CodeEdit) {
	mut a := app()
	tid := ui2.code_editor_text_id(editor_id)
	doc := a.doc()
	native := ui2.code_edit_native(doc.text, edit)
	a.applying = true
	if edit.changes_text() {
		ui2.text_area_set_selection(tid, native.location, native.length)
		ui2.insert_text_area_text(tid, native.insert)
	}
	ui2.text_area_set_selection(tid, native.select_location, native.select_length)
	a.applying = false
	a.native = edit.selection
	a.set_doc(Doc{
		text:        edit.text
		selection:   edit.selection
		diagnostics: if edit.changes_text() {
			ui2.code_diagnostics_after_edit(doc.diagnostics, edit)
		} else {
			doc.diagnostics
		}
	})
	a.completion = ui2.code_completion_sync(completion_config())
	reveal(ui2.CodeRange{edit.selection.caret, edit.selection.caret})
}

fn apply_search(step ui2.CodeSearchStep) {
	mut a := app()
	a.search = step.state
	if edit := step.edit {
		apply(edit)
	}
	matches := ui2.code_search_matches(a.doc().text, a.search)
	current := a.search.current
	if step.select && current >= 0 && current < matches.len {
		m := matches[current]
		apply(ui2.CodeEdit{
			text:      a.doc().text
			selection: ui2.TextSelection{m.start, m.end}
		})
	}
	ui2.refresh()
	if step.reveal && current >= 0 && current < matches.len {
		reveal(matches[current])
	}
	if step.focus.len > 0 {
		ui2.focus(step.focus)
	}
}

fn apply_completion(step ui2.CodeCompletionStep) {
	mut a := app()
	a.completion = step.state
	if edit := step.edit {
		apply(edit)
		a.status = 'Inserted `${step.item.label}`.'
	}
	ui2.refresh()
}

fn text_changed() {
	mut a := app()
	tid := ui2.code_editor_text_id(editor_id)
	doc := a.doc()
	value := ui2.text(tid)
	sel := ui2.code_editor_selection_from_native(value, ui2.text_area_caret(tid), ui2.text_area_selection_length(tid))
	a.native = sel
	if !a.applying {
		// Finish what was typed: close a bracket, type over a closer.
		if edit := ui2.code_editor_after_input(editor_config(), value, sel) {
			typed := ui2.code_edit_between(doc.text, value)
			a.set_doc(Doc{
				text:        value
				selection:   sel
				diagnostics: ui2.code_diagnostics_after_edit(doc.diagnostics, typed)
			})
			apply(edit)
			ui2.refresh()
			return
		}
	}
	if value == doc.text {
		return
	}
	typed := ui2.code_edit_between(doc.text, value)
	a.set_doc(Doc{
		text:        value
		selection:   sel
		diagnostics: ui2.code_diagnostics_after_edit(doc.diagnostics, typed)
	})
	a.status = ''
	a.completion = ui2.code_completion_sync(completion_config())
	if !a.applying {
		ui2.refresh()
	}
}

fn run_command(command ui2.CodeCommand) bool {
	mut a := app()
	cfg := editor_config()
	if step := ui2.code_search_command(cfg, command) {
		apply_search(step)
		return true
	}
	if command == .show_completions {
		if step := ui2.code_completion_show(completion_config()) {
			apply_completion(step)
		}
		return true
	}
	if !a.focused {
		return false
	}
	edit := ui2.code_editor_command(cfg, command) or { return false }
	apply(edit)
	ui2.refresh()
	return true
}

// ── Events and keys ────────────────────────────────────────────────────────

fn on_event(event string) {
	mut a := app()
	cfg := editor_config()
	if event == ui2.code_editor_text_id(editor_id) {
		text_changed()
		return
	}
	if step := ui2.code_search_update(cfg, event, ui2.text(event)) {
		apply_search(step)
		return
	}
	if step := ui2.code_completion_update(completion_config(), event) {
		apply_completion(step)
		return
	}
	if step := ui2.code_editor_update(cfg, event) {
		apply(ui2.CodeEdit{
			text:      cfg.text
			selection: step.selection
		})
		ui2.refresh()
		return
	}
	if event.starts_with('lang:') {
		a.language = ui2.code_language(event['lang:'.len..])
		a.search = ui2.CodeSearchState{
			...a.search
			current: -1
		}
		a.completion = ui2.CodeCompletionState{}
		a.status = ''
	} else if event.starts_with('problem:') {
		index := event['problem:'.len..].int()
		doc := a.doc()
		if index >= 0 && index < doc.diagnostics.len {
			d := doc.diagnostics[index]
			apply(ui2.CodeEdit{
				text:      doc.text
				selection: ui2.TextSelection{d.start, d.end}
			})
			a.status = d.message
		}
	} else {
		match event {
			'toggle:numbers' { a.line_numbers = !a.line_numbers }
			'toggle:wrap' { a.soft_wrap = !a.soft_wrap }
			'toggle:readonly' { a.read_only = !a.read_only }
			'theme' { a.dark = !a.dark }
			else { return }
		}
	}
	ui2.refresh()
}

fn on_key_event(event ui2.KeyEvent) {
	mut a := app()
	sync_selection()
	if a.completion.open {
		if step := ui2.code_completion_key(completion_config(), event) {
			apply_completion(step)
			ui2.consume_key()
			return
		}
	}
	if step := ui2.code_search_key(editor_config(), event) {
		apply_search(step)
		ui2.consume_key()
		return
	}
	command := if event.ctrl && !event.cmd && !event.alt && event.code == .space {
		ui2.CodeCommand.show_completions
	} else {
		ui2.code_command_for_key(event) or { return }
	}
	if run_command(command) {
		ui2.consume_key()
	}
}

// on_key receives what a focused text area reports through `text:<id>:<key>`:
// on AppKit that is the only way Enter, Tab and Backspace reach the app.
fn on_key(key string) {
	mut a := app()
	sync_selection()
	if a.completion.open {
		if step := ui2.code_completion_text_key(completion_config(), key) {
			apply_completion(step)
			ui2.consume_text_key()
			return
		}
	}
	command := ui2.code_editor_text_command(editor_id, key) or { return }
	if run_command(command) {
		ui2.consume_text_key()
	}
}

// follow_caret follows the caret on backends that report no selection changes.
fn follow_caret() {
	sync_selection()
	ui2.after(0.25, follow_caret)
}

fn main() {
	mut a := app()
	init_docs(mut a)
	ui2.on_key_event(on_key_event)
	ui2.on_key(on_key)
	// Once the text area exists, put its caret where the demo starts.
	ui2.after(0.1, fn () {
		mut st := app()
		tid := ui2.code_editor_text_id(editor_id)
		ui2.focus(tid)
		doc := st.doc()
		location, length := ui2.code_editor_selection_to_native(doc.text, doc.selection)
		// The custom renderer ignores focus and selection changes made from a
		// timer; there the caret stays at the end until the first click.
		ui2.text_area_set_selection(tid, location, length)
		st.ready = true
		follow_caret()
	})
	ui2.run_window('GPUI Kit editor', 1180, 780, build, on_event)
}
