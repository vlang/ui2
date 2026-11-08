# Code editor

A port of GPUI Kit's [Editor](https://github.com/longbridge/gpui-kit/blob/main/website/component/editor.md)
(the code-editor mode of its input). The implementation is split by concern:

| File | What |
| --- | --- |
| `ui/component_editor.v` | `code_editor`, its configuration, layout, gutter, folding and geometry helpers |
| `ui/component_editor_lang.v` | languages, their editing rules, and the tokenizers |
| `ui/component_editor_theme.v` | light and dark palettes, diagnostics and decorations, text runs |
| `ui/component_editor_edit.v` | editing rules, commands and key mapping, range tracking |
| `ui/component_editor_search.v` | find and replace, the regular-expression engine, the search bar |
| `ui/component_editor_completion.v` | the manual completion menu |

`examples/gpui_editor/main.v` edits a V file with highlighting, the gutter, a
search bar with matches, two diagnostics and a completion menu at the caret,
and switches between V, JSON, Markdown and Python, light and dark, soft wrap,
line numbers and read-only. A side panel lists the problems (click one to
select its range) and shows a read-only snippet sized to its content. For
screenshots, `UI2_EDITOR_DARK=1`, `UI2_EDITOR_LANG=json|markdown|python`,
`UI2_EDITOR_WRAP=1` and `UI2_EDITOR_REPLACE=1` start it in those states.

## How it is built

ui2 has no code-editor control, so the editor is composed from what it has:

- The code lives in a **rich text area** (`rich_text_area_without_scroll`), so
  typing, selection, the clipboard, undo and input methods are the platform's.
  The syntax colors, search matches and diagnostics are its `text_runs`.
- The text area is **sized to its content** (as tall as its lines, and without
  soft wrap as wide as its longest line) and sits in a ui2 `scroll` next to the
  **gutter**, so the line numbers scroll with the code natively on every
  backend, with no scroll offset to follow. Without soft wrap the code sits in a
  second, sideways scroll, so the gutter stays put while long lines scroll.
- Everything drawn beside or over the text (line numbers, the current-line
  tint, indent guides, frames, inline messages, the custom renderer's caret) is
  placed from **`code_editor_metrics`**: the line pitch, character advance,
  insets and tab stops of the text area on the running backend. AppKit lays
  lines out at the font's rounded ascender, descender and leading (measured:
  Menlo 13 pt → 15 pt lines, 7.83 pt characters, 5 pt line-fragment padding,
  tab stops every 28 pt); the custom renderer at 1.25 em with 8 pt of padding.
  `line_height` in the config overrides the pitch for other faces.
- On AppKit the text view is transparent, so the tint, guides and frames lie
  **beneath** it, where they cannot take its clicks. The custom renderer paints
  a text area's background whatever its box says but does not hit-test plain
  views, so there they lie **over** it, translucent.

The application owns everything, as with every component here: the text, the
selection, the search, the completions, the diagnostics. The helpers return
edits (`CodeEdit`) and steps; the application applies them and rebuilds.

## The editor

```v
ui2.code_editor(
	id:                 'editor'
	frame:              ui2.rect(16, 60, 900, 600)
	text:               app.source
	selection:          app.selection // read from the text area, see below
	focused:            ui2.focused_text_area_id() == ui2.code_editor_text_id('editor')
	language:           .v            // or ui2.code_language('rs'), code_language_from_path(path)
	hard_tabs:          true
	tab_size:           4
	folding:            true
	inline_diagnostics: true
	diagnostics:        app.diagnostics
	search:             app.search
	theme:              ui2.code_editor_theme(app.dark)
) or { panic(err) }
```

| Field | Meaning |
| --- | --- |
| `text`, `selection` | The code, and its selection in runes (`TextSelection`). |
| `focused` | Whether the text area has focus: the custom renderer's caret is drawn only then. |
| `language`, `rules` | Highlighting and editing rules; `rules` replaces `code_language_rules(language)`. |
| `tab_size`, `hard_tabs`, `auto_close`, `smart_indent` | Editing preferences (default 4, spaces, on, on). |
| `line_numbers`, `folding`, `indent_guides`, `current_line`, `inline_diagnostics` | Gutter and marks. |
| `soft_wrap` | Wrap long lines; off (the default) scrolls them sideways. |
| `read_only`, `disabled` | Read-only keeps selection, copying and search but refuses edits; disabled takes no input at all. |
| `highlight` | Syntax colors on or off. |
| `font_family`, `font_size`, `line_height` | The face (empty: Menlo, Consolas, or the bundled monospace face), its size, and an explicit line pitch. |
| `size` | The padding round the code: `.small`, `.medium`, `.large`, as upstream's sizes. |
| `bordered`, `placeholder`, `label` | Chrome and accessibility. |
| `diagnostics`, `decorations` | Annotations, below. |
| `search`, `search_bar`, `search_size` | Find and replace, below. |

Ids for the backend calls:

- `code_editor_text_id(id)`: the text area. Pass it to `text`, `focus`,
  `text_area_caret`, `text_area_selection_length`, `text_area_set_selection`
  and `insert_text_area_text`. It is also the action of every edit.
- `code_editor_scroll_id(id)` and `code_editor_hscroll_id(id)`: the vertical
  and (without soft wrap) sideways scrolls.

### Reading the selection

Text areas report edits but not caret moves. Read the selection from the text
area whenever it matters (before running a command, when building), and keep
it in the model:

```v
tid := ui2.code_editor_text_id('editor')
sel := ui2.code_editor_selection_from_native(source, ui2.text_area_caret(tid),
	ui2.text_area_selection_length(tid))
```

AppKit sends nothing when the caret moves by a click or an arrow key, and the
custom renderer rebuilds every frame anyway, so the gallery also re-reads it on
a 250 ms `after` loop to keep the current line, the status bar and the
completion menu in step. A selection-change event is requested below.

### Applying an edit

Every helper returns a `CodeEdit`: the new text and selection, and the
replacement that makes it (`start`, `end`, `insert`, in runes of the old text).
Apply it through the text area so it stays undoable on AppKit:

```v
fn apply(edit ui2.CodeEdit) {
	tid := ui2.code_editor_text_id('editor')
	n := ui2.code_edit_native(app.source, edit) // UTF-16 offsets
	app.applying = true // the insertion reports an edit: do not treat it as typing
	if edit.changes_text() {
		ui2.text_area_set_selection(tid, n.location, n.length)
		ui2.insert_text_area_text(tid, n.insert)
	}
	ui2.text_area_set_selection(tid, n.select_location, n.select_length)
	app.applying = false
	app.diagnostics = ui2.code_diagnostics_after_edit(app.diagnostics, edit)
	app.source, app.selection = edit.text, edit.selection
	ui2.refresh()
	for r in ui2.code_editor_reveal(config(), ui2.CodeRange{edit.selection.caret, edit.selection.caret}) {
		ui2.scroll_to_rect(r.id, r.rect.x, r.rect.y, r.rect.width, r.rect.height)
	}
}
```

`code_editor_reveal` returns the scroll requests that bring a range into view;
AppKit scrolls to the caret by itself, the custom renderer needs them, and both
need them to show a search match. Call it after `refresh()` so the scroll has
its new range.

On the custom renderer, `set_text`, `text_area_set_selection`,
`insert_text_area_text` and `focus` do nothing when called from an `after`
callback (which runs during a build): call them from event and key handlers.

## Language editing rules

`CodeLanguageRules` is the supported subset of GPUI Kit's `LanguageConfig`:

```v
ui2.CodeLanguageRules{
	brackets:          [ui2.CodePair{'{', '}'}, ui2.CodePair{'(', ')'}]   // Enter indents after and splits these
	auto_pairs:        [ui2.CodePair{'{', '}'}, ui2.CodePair{'"', '"'}]   // closed as they are typed
	auto_close_before: ';:.,=}])>'   // besides blanks and the end of the text
	line_comment:      '//'
	block_comment:     ui2.CodePair{'/*', '*/'}
	indent_after:      [':']         // line endings that open a block (Python)
	word_extra:        '$'           // extra word characters (shell, JavaScript)
}
```

`code_language_rules(language)` gives the defaults: plain text has no pairs,
JSON closes only `{`, `[` and `"`, Python also indents after `:`, Rust does not
pair `'` (lifetimes), V, Go and JavaScript pair backticks. Upstream's `not_in`
contexts are fixed here: no pair is inserted inside a string or a comment, as
the tokenizer sees them.

All the rules are pure functions of a text and a selection, each returning a
`CodeEdit` (none when there is nothing special to do):

| Function | What |
| --- | --- |
| `code_edit_newline` | Enter: keep the indentation, indent after an opener (or `indent_after`), split `{|}` into three lines, outdent before a closer. `smart_indent: false` only keeps the indentation. |
| `code_edit_after_input` | Call with the text before and after a text-area change and the caret: closes an opener, types over a closer when the line's pairs balance, wraps a one-line selection in a typed pair; nothing for pastes and deletions. |
| `code_edit_backspace` | Deletes an empty pair together, and spaces back to the previous tab stop; none otherwise, so the text area's own Backspace runs. |
| `code_edit_indent` / `code_edit_outdent` | Tab with a multi-line selection indents its non-blank lines and keeps them selected; with a caret it inserts a tab or spaces to the next stop. Shift+Tab removes a level from each line. |
| `code_edit_toggle_comment` | Line comments at the lines' common indentation, or removed when every non-blank line has one; block comments for Markdown. |
| `code_edit_duplicate_lines`, `code_edit_move_lines`, `code_edit_delete_lines` | Line commands; moving stops at the first and last line. |
| `code_select_line`, `code_select_word`, `code_word_at` | Selections; Cmd+D selects the word, then moves to its next occurrence. |

`code_editor_command(config, command)` runs a `CodeCommand` against the
config's text and selection, refusing edits in a read-only or disabled editor,
and `code_editor_after_input(config, text, selection)` is the typing hook.

```v
fn on_text_changed() {
	tid := ui2.code_editor_text_id('editor')
	value := ui2.text(tid)
	sel := ui2.code_editor_selection_from_native(value, ui2.text_area_caret(tid),
		ui2.text_area_selection_length(tid))
	if !app.applying {
		if edit := ui2.code_editor_after_input(config(), value, sel) {
			app.source = value
			apply(edit)
			return
		}
	}
	app.source, app.selection = value, sel
	ui2.refresh()
}
```

## Keys

Components cannot capture keys. `code_command_for_key(event)` maps an
`on_key_event` key to a command, with Command on Apple platforms where others
use Control:

| Command | macOS | Windows / Linux / BSDs |
| --- | --- | --- |
| `newline`, `indent`, `outdent`, `backspace` | Return, Tab / ⌘], ⇧Tab / ⌘[, Backspace | Enter, Tab / Ctrl+], Shift+Tab / Ctrl+[, Backspace |
| `toggle_comment` | ⌘/ | Ctrl+/ |
| `move_lines_up` / `down` | ⌥↑ / ⌥↓ | Alt+Up / Down |
| `duplicate_lines` | ⇧⌥↓, ⇧⌘D | Shift+Alt+Down, Ctrl+Shift+D |
| `delete_lines` | ⇧⌘K | Ctrl+Shift+K |
| `select_line`, `select_word` | ⌘L, ⌘D | Ctrl+L, Ctrl+D |
| `find`, `find_replace` | ⌘F, ⌥⌘F | Ctrl+F, Ctrl+H |
| `find_next`, `find_previous` | ⌘G / F3, ⇧⌘G / ⇧F3 | Ctrl+G / F3, Ctrl+Shift+G / Shift+F3 |
| `show_completions` | none, as upstream: bind one (the gallery uses ⌃Space) | none |

### Which keys reach the application while the text area has focus

Measured on AppKit with a probe that queued key events for an `NSTextView` set
up as ui2 sets text areas up (a window overriding `performKeyEquivalent:` and
`keyDown:`, the text view's delegate answering `textView:doCommandBySelector:`),
and confirmed end to end with ui2's AppKit backend (Return between braces,
typed pairs, Backspace, Tab, ⇧Tab, ⌘/, ⌥↑, ⇧⌘D, ⇧⌘K, undo). The custom renderer
offers every key to `on_key_event` first.

| Key | AppKit | Custom renderer |
| --- | --- | --- |
| Typed characters, Option+letters | The text view inserts them; the text area reports an edit | `on_key_event` sees the key; the text area inserts the character and reports an edit |
| Return, Tab, Shift+Tab, Backspace, Delete | **`on_key` only**, as `text:<text id>:enter` (`line_break` with Shift), `tab`, `shift+tab`, `backspace`, `forward_delete`; `consume_text_key` stops the text view | `on_key_event`, then `on_key` as `text:<id>:<key>`, then the text area |
| Arrows, Home, End, Page keys, Escape, F-keys | `on_key_event` first (AppKit offers them as key equivalents), then the text view | `on_key_event`, then `on_key`, then the text area |
| Command and Control combinations | `on_key_event` first; ⌘A/X/C/V/Z left unconsumed go to the text view | `on_key_event`, then `on_key` |

So route both: `on_key_event` through `code_command_for_key` and
`on_key` through `code_editor_text_command(id, key)` (which reads
`text:<code_editor_text_id(id)>:<key>`), and consume the key when the command
returned an edit. On the custom renderer a key consumed in `on_key_event` never
reaches `on_key`, so nothing runs twice. Check that the editor has focus before
running editing commands from `on_key_event`, which sees keys wherever the
focus is.

## Syntax highlighting

`code_tokens(text, language)` tokenizes V, Rust, JavaScript, TypeScript,
Python, Go, JSON, TOML, Markdown (with fenced blocks highlighted in their own
language) and shell into `CodeToken`s of a `CodeTokenKind` (keyword, string,
string escape, number, constant, type, function, property, attribute,
comment, interpolation, Markdown titles, emphasis, links, code spans, ...).
They are hand-written scanners: one pass, no grammar, linear in the text.
Interpolation (`${}` in V and template literals, `$name` in V, f-strings,
`$VAR` and `$(...)` in shell) is tokenized in the host language.

`code_highlight_runs(CodeHighlightConfig{...})` turns a text into the text
runs of a rich text area: syntax colors from the theme over a base style (the
font), plus search matches, the current match, diagnostic tints with an
underline, and filled decorations. Runs cover the whole text in order and
neighbours with the same style are merged; a highlight never covers a newline.

`code_editor_theme(dark)` returns GPUI Kit's default light and dark editor
palettes: the editor surface, line numbers, the active line, the syntax
colors, search matches and diagnostic colors, plus `ui`, the component theme
of the search bar and the completion menu.

## Gutter and folding

The gutter shows line numbers (the caret's emphasized, on the first row of a
wrapped line), the most severe diagnostic of each line as a marker with every
message of the line in its tooltip, and with `folding` a fold marker for each
block `code_fold_ranges(text, language)` finds: bracket pairs across lines
(outside strings and comments), indentation for Python, headings for
Markdown.

Pressing a line number selects the line; pressing a fold marker selects the
block. `code_editor_update(config, event)` decodes both into a
`CodeEditorStep` (a selection and the text area to focus). Folding does not
hide lines: a text area cannot hide part of its text (requested below).

## Search

```v
app.search = ui2.CodeSearchState{
	open:    true
	replace: false
	query:   'counter'
	options: ui2.CodeSearchOptions{ match_case: false, whole_word: false, regex: false }
	current: 0 // index of the current match
}
```

- `code_search(text, query, options) ![]CodeRange` finds matches: plain,
  case-insensitive by default, whole word, or a regular expression. The
  expression language is a subset: literals and escapes, `.`, classes
  `[a-z]` `[^...]`, `\d \w \s` and their negations, `^ $` at line boundaries,
  `\b \B`, groups, `|`, and `* + ? {n} {n,} {n,m}` with lazy forms. It runs as
  a Pike VM, linear in the text (no catastrophic backtracking); an invalid
  expression is an error (`code_search_error` for the bar).
- `code_search_next_index`, `code_search_replace`, `code_search_replace_all`
  navigate and replace.
- `code_search_command(config, command)` runs Find (with the selected text as
  the query), Find and Replace, Find Next and Find Previous, also while the
  bar is closed. `code_search_update(config, event, ui2.text(event))` decodes
  the bar: query and replacement edits, Return in the query field (next, or
  previous with Shift), the Aa / ab / .* toggles, previous, next, Replace,
  All, the replace row's disclosure and close. `code_search_key` closes the
  bar on Escape. Steps carry the new state, an edit, whether to reveal the
  current match, whether to select it (after closing), and a field to focus.
- The matches are highlighted while `search.open`. With `search_bar: false`
  the built-in bar is hidden and the application can draw its own UI on the
  same engine; `code_search_bar(CodeSearchBarConfig)` draws the bar anywhere.

Selecting a match while the query field has focus would take the focus away
on AppKit (`text_area_set_selection` makes the text view first responder), so
moving through matches only highlights the current one and scrolls to it;
closing the bar selects it in the text area. A read-only editor searches but
has no replace row.

## Diagnostics and decorations

```v
ui2.CodeDiagnostic{ start: 120, end: 128, severity: .error, message: 'unknown field', source: 'v' }
ui2.CodeDecoration{ start: 0, end: 8, style: .fill }          // 12% of the foreground
ui2.CodeDecoration{ start: 12, end: 24, color: 0xd97706 }     // a frame in that color
```

Ranges are rune offsets (`code_offset(text, line, column)` converts).
Diagnostics are tinted and underlined in the text, marked in the gutter, and
with `inline_diagnostics` the first message of a line is written after it.
Fills are run backgrounds (under the glyphs, as upstream paints them); frames
are one-point outlines drawn per visual row. `code_diagnostics_after_edit` and
`code_decorations_after_edit` carry them through an edit with upstream's rules
(`code_map_range`): text inserted at either edge does not grow a range, text
inserted inside does, edges inside a replacement are clipped to it, and a range
an edit removes is dropped. `code_edit_between(before, after)` describes a
change the text area made itself (typing, a paste) as one edit.

## Completions

```v
ui2.code_completion(ui2.CodeCompletionConfig{
	editor:         config()
	origin:         config().frame // the editor's frame in window coordinates
	window:         ui2.bounds()
	scroll_offset:  ui2.scroll_offset(ui2.code_editor_scroll_id('editor'))
	hscroll_offset: ui2.scroll_horizontal_offset(ui2.code_editor_hscroll_id('editor'))
	items:          [ui2.CodeCompletionItem{ label: 'count', kind: .field, detail: 'int' }]
	state:          app.completion
}) or { panic(err) }
```

An overlay: build it last. It opens below the caret (above when there is no
room), aligned with the identifier being completed, and lists the items that
match the identifier before the caret (`code_completion_prefix`): the ones
starting with it first, then fuzzy matches. `code_completion_show` opens it (no
default key, as upstream; never for read-only or disabled editors),
`code_completion_key` moves through it from `on_key_event` (Up and Down wrap,
Page keys jump, Enter or Tab accept, Escape closes),
`code_completion_text_key` accepts on AppKit's `text:<id>:enter` and
`text:<id>:tab`, `code_completion_update` accepts a pressed row, and
`code_completion_sync` keeps it open after an edit while the prefix still
matches. Accepting returns the edit that replaces the prefix with the item's
`insert` (or label).

## Sizing to content

`code_editor_content_height(config)` is the frame height that shows every row
without scrolling (with soft wrap, at the frame's width), as GPUI Kit's
`wrap_row_count` is used for read-only snippets; `code_editor_row_count` is the
row count itself. `code_editor_caret_rect` and `code_editor_range_rect` give
positions in the editor's coordinates with nothing scrolled.

## Accessibility

| Part | Role | Label |
| --- | --- | --- |
| Editor | `group` | `label`, or "Code editor" |
| Text area | the native text area | the same label |
| Gutter | `group` | "Line numbers"; numbers are buttons labeled "Line n", fold markers "Fold lines a to b" |
| Diagnostic markers | `img` | the messages |
| Search bar | `search`; count `status` | "Find"; toggles and buttons by their tooltips |
| Completion menu | `listbox` of `option`s | "Suggestions"; rows by label and detail, `selected` value |

## Parity with GPUI Kit

| Upstream | ui2 |
| --- | --- |
| Language editing rules: brackets, auto-closing pairs, `auto_close_before`, indentation rules, `auto_close` and `smart_indent` | Implemented as `CodeLanguageRules` and the preferences; increase rules are line-ending suffixes (`indent_after`) and decrease rules the bracket closers instead of regular expressions. |
| Skip-over of an auto-inserted closer, paired Backspace | Implemented; without the record of which closers were inserted, typing over is allowed when the line's pairs balance. |
| Selection-surrounding | Added (upstream lists it as not yet supported). |
| Syntax highlighting (tree-sitter or syntect) | Hand-written tokenizers for V, Rust, JavaScript, TypeScript, Python, Go, JSON, TOML, Markdown and shell; no grammars, so no syntax-aware selection or injected languages beyond Markdown fences and interpolation. |
| Line numbers, current line, indent guides | Implemented. |
| Folding | Fold ranges and markers; a marker selects its block, since a text area cannot hide lines. |
| Tab size, hard tabs, Tab / Shift+Tab indent and outdent | Implemented. Tab stops are the backend's (AppKit 28 pt, custom renderer about one space), see below. |
| Search panel: find, replace, replace all, next/previous, case, regex | Implemented, plus whole word; custom search UI through `search_bar: false` and the pure helpers. |
| Diagnostics (LSP-style ranges, severities, hover) | Implemented with a tooltip on the gutter marker and optional inline messages; no hover popover in the text. |
| Text decorations, geometric range decorations (fill, frame), tracking through edits | Implemented as runs (fills) and outline views (frames), carried through edits by the helpers. |
| Manual completions (`ShowCompletions`, prefix refinement, no default key) | Implemented with application-supplied items. LSP providers, code actions, hover, go-to-definition, inline suggestions and semantic tokens are omitted: ui2 has no language-server plumbing. |
| Multiple cursors, column selection, Alt+click | Omitted: the text area has one selection. |
| Soft wrap, sizing to content (`prewrap`, `wrap_row_count`) | `soft_wrap`, `code_editor_content_height`, `code_editor_row_count`. |
| Fonts (`mono_font_family`), sizes, `bordered`, `readonly`, `disabled`, `aria_label` | Implemented (`font_family`, `size`, `bordered`, `read_only`, `disabled`, `label`). |
| `scroll_bounce`, `show_whitespaces`, custom context menu, paste handler | Omitted: scrolling and the context menu are the backend's; whitespace markers would need per-glyph drawing. |

## Platform notes

- **Runs are rewritten whole.** AppKit replaces a rich text area's attributed
  string when its runs change, which costs undo grouping and input-method
  composition while recoloring on every keystroke.
- **No selection-change event.** Neither backend reports caret moves; the
  gallery polls.
- **No text-area geometry.** ui2 does not report a text area's line height,
  caret rectangle or the rectangle of a range, so the editor reproduces each
  backend's layout (`code_editor_metrics`); Windows' EDIT metrics are
  estimated.
- **Tabs** stop every 28 points on AppKit and in the custom renderer, so
  `tab_size` sets the editor's own indentation, not how wide a tab draws.
- **Custom renderer text area.** It draws no caret (the editor draws one), a
  click puts the caret at the end of the text and there is no pointer
  selection, it paints its box background and outline whatever `box` says,
  `text_area_caret` returns the moving end of a selection where AppKit returns
  its start, and `set_text`, `text_area_set_selection`, `insert_text_area_text`
  and `focus` are ignored when called from an `after` callback.
- **Custom renderer scrolls add 16 points** below their content, which AppKit
  does not; the editor leaves that room out of its content height.
- **AppKit hit-testing.** A plain view laid over a text view takes its clicks,
  which is why the editor's marks lie beneath the text on AppKit.
- **Windows and iOS** draw text-area runs plain (no highlighting), and the
  Windows EDIT control is opaque, so the current-line tint and indent guides
  beneath it do not show there.

## Attribution

The light and dark palettes are GPUI Kit's default highlight themes
(`crates/component/src/theme/default-theme.json`, Longbridge, Apache-2.0);
`ui/component_editor_theme.v` carries the header. See the
[attribution](../../third_party/gpui-kit/NOTICE.md). The editing rules follow
the behavior the upstream documentation describes; the tokenizers, the regular
expression engine, the layout and all rendering are new code.

## Verification

```sh
v test ui/component_editor_test.v
v -d ui2_custom_rendering test ui/component_editor_test.v
v run examples/gpui_editor/main.v
v -d ui2_custom_rendering run examples/gpui_editor/main.v
UI2_EDITOR_DARK=1 UI2_EDITOR_REPLACE=1 v run examples/gpui_editor/main.v
```

The tests cover language names and paths, every tokenizer (with fenced and
interpolated code, unterminated strings and comments, and ordering and bounds
for all languages), run building with matches, diagnostics and fills, the
themes, every editing rule and command on marked-up texts, key mapping per
platform, read-only refusal, UTF-16 conversion with astral characters, range
tracking, plain and regular-expression search (including invalid expressions
and a pathological pattern), the search bar's events and commands, fold
ranges, gutter events, the element tree (gutter, sideways scroll, search bar,
read-only), geometry and wrapping, and the completion menu's filtering, keys,
presses, syncing and placement.
