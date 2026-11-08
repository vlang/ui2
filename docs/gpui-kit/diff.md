# Diff

A port of GPUI Kit's [Diff](https://github.com/longbridge/gpui-kit/blob/main/website/component/diff.md):
a readonly, virtualized view of one or more files' changes for code review,
merge conflicts and source previews. Upstream only displays patches an
application obtained elsewhere; the ui2 port also computes line diffs of two
texts and writes unified patches.

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `DiffFile`, `DiffFileStatus`, `DiffConflict`, document model | `DiffFile`, `DiffHunk`, `DiffLine`, `DiffConflict`, `DiffFileStatus` | `ui/component_diff.v` |
| (none: upstream does not compute diffs) | `diff_edits`, `diff_texts`, `diff_hunks`, `diff_unified_text`, `diff_inline_ranges` | `ui/component_diff.v` |
| `DiffFile::parse`, `DiffParseError`, `DiffFile::parse_conflicts`, `DiffFile::unchanged` | `parse_diff`, `DiffParseError`, `parse_diff_conflicts`, `diff_file_unchanged`, `parse_diff_header` | `ui/component_diff_parse.v`, `ui/component_diff.v` |
| `DiffState`, `DiffLinePosition`, `DiffLineRange`, `DiffSide`, `DiffMode`, `DiffEvent`, `DiffAnnotation`, `DiffConflictResolution` | `DiffState` (`diff_state`), the same names, `DiffEvent` + `DiffState.apply` | `ui/component_diff_state.v` |
| `Diff` (the element) | `diff_view(DiffViewConfig)`, `diff_event_from_action`, `diff_event_from_key`, `diff_navigate` | `ui/component_diff_view.v` |

Tests are in `ui/component_diff_test.v`. `examples/gpui_diff/main.v` is a
git-history view of one commit, parsed from real `git format-patch` output: a
modified file with a review comment, a rename, a file whose merge still has
two conflicts (one diff3), a file without a final newline, a binary file, a
deleted file, a mode change, and a 3,000-line generated file supplied with its
whole text as context, so that its unchanged lines fold away and can be
revealed and only the rows on screen are built while it scrolls. It has a
Unified/Split toggle, context lines, Expand, previous/next change, a file list
that scrolls to a file, line selection with copying as lines, old, new or
patch text, keyboard control and a light/dark toggle.

```sh
v run examples/gpui_diff/main.v
v -d ui2_custom_rendering run examples/gpui_diff/main.v
```

## Conventions

- **Controlled state.** The application keeps one `DiffState`, passes it to
  `diff_view` in `DiffViewConfig.state`, and rebuilds. Everything the view
  emits comes back through `on_event`: `diff_event_from_action(config, event)`
  turns it into a typed `DiffEvent` (none for actions that are not this view's,
  malformed or forged ones, and requests that would change nothing), and
  `state.apply(event)` makes the change. Scroll and copy events are the
  application's to carry out. Programmatic methods (`set_mode`,
  `set_file_collapsed`, `resolve_conflict`, `set_selected_lines`, ...) emit
  nothing, as upstream.
- **The state caches the rows.** Every change to files, mode, context, folds,
  collapsed files, conflict resolutions or annotations rebuilds `rows()` once,
  so a build only lays out row heights and builds the rows in view. Do not
  create a new state per build: keep it, as upstream keeps its entity.
- **Source coordinates** are `DiffLinePosition{path, side, line}` and
  `DiffLineRange{path, side, start, end, crosses}` with one-based source line
  numbers. A file is named by `path()`: the modified path, or the original one
  for a deleted file. Display modes and folding never renumber lines.
- **Scrolling.** The body is a vertical Scroll element, `diff_body_id(id)`.
  Pass `scroll_y: ui2.scroll_offset(diff_body_id(id))` and rebuild from
  `on_scroll` (with `request_refresh`, as for any virtual list); the custom
  renderer rebuilds every frame anyway. Each file's code column is a
  horizontal Scroll element (`diff_code_scroll_id(id, file, side)`) that
  scrolls by itself, so the line numbers stay put while long lines move, and a
  vertical gesture over code still scrolls the list.

## Computing and reading diffs

```v
// Two versions of a file: a complete file, every line in one hunk.
file := ui2.diff_texts('src/app.v', 'src/app.v', old_text, new_text)
// A patch from Git or anywhere else, one DiffFile per file.
files := ui2.parse_diff(patch) or {
	if err is ui2.DiffParseError {
		eprintln('line ${err.line}: ${err.message}')
	}
	[]ui2.DiffFile{}
}
// A whole file for reference, and a working file with conflict markers.
reference := ui2.diff_file_unchanged('README.md', readme)
merge := ui2.parse_diff_conflicts('src/config.v', working_text)!
```

- `diff_edits(old, new []string) []DiffEdit` is the line diff behind
  `diff_texts`: Myers' O(ND) algorithm in linear space (middle-snake
  divide and conquer). Lines found on one side only are set aside before the
  search (no shortest script can use them), which makes unrelated texts cost
  next to nothing. A sub-problem needing more than about the square root of its
  size in edits (at least 256) is split at the furthest point reached instead
  of the optimal one, which keeps huge, very different inputs near-linear;
  ordinary changes stay optimal. Changes are then slid down as far as equal
  lines allow and back up to end on a blank line where possible, as diff tools
  present them. Within a change removals come before additions. The tests check
  minimality against a quadratic LCS on 1,650 random inputs and time 100,000
  lines with 1,000 scattered edits, 20,000 shuffled lines and 100,000 unrelated
  lines.
- `diff_texts(old_path, new_path, old_text, new_text)` numbers the lines, marks
  a version that does not end with a newline (`DiffLine.no_newline`), and sets
  the status: added or deleted for an empty path, renamed for different paths.
  The result is `complete`: every unchanged line is there to reveal.
- `diff_hunks(file, context)` cuts a file into unified hunks with `context`
  lines, as `diff -U` does, with Git's default function-name text after the
  `@@`; `diff_unified_text(file, context)` writes a Git patch (quoting unusual
  paths, rename and mode headers, `\ No newline at end of file`) that
  `parse_diff` reads back.
- `parse_diff` reads unified diffs and Git patches with any number of files:
  `git format-patch` mail (the message and diffstat are skipped;
  `parse_diff_header` returns commit, author, date, subject and message, also
  for `git show`), the prefixes of `diff.noprefix` and `diff.mnemonicPrefix`,
  quoted paths with C escapes, `--- `/`+++ ` timestamps, renames and copies
  with their similarity, mode changes, new and deleted files, binary markers
  (`Binary files ... differ` and `GIT binary patch`, whose payload is skipped),
  `\ No newline at end of file`, empty context lines whose space a mailer
  stripped, and CRLF transport. Malformed hunks, source lines outside a hunk,
  unordered hunks and combined diffs (`diff --cc`) return a `DiffParseError`
  with the one-based patch line and a message. Each file keeps its extended
  header lines in `headers`.
- A file without source rows (binary, a mode change, a pure rename or copy, an
  empty new file) shows `summary()` instead.

### Merge conflicts

`DiffFile.conflicts` lists the `<<<<<<<` / `|||||||` / `=======` / `>>>>>>>`
regions found in the modified version: in a working file read with
`parse_diff_conflicts` (which also reports unbalanced markers as errors), and
in a patch whose hunks contain whole regions, as `git diff HEAD` shows a merge
in progress. Each `DiffConflict` has the labels after its markers, the hunk line
ranges of the current (ours), base (diff3) and incoming (theirs) parts and the
working-file lines of its first and last marker. The view replaces the markers
with headings: **Current change** with **Accept current**, **Accept incoming**
and **Accept both**, **Common ancestor**, **Incoming change**; a resolved
conflict shows only the kept lines under **Accepted ...** with **Undo**.

```v
state.resolve_conflict('src/config.v', 0, .theirs)
state.unresolve_conflict('src/config.v', 0)
if text := state.resolved_text('src/config.v') {
	// Every conflict has a resolution: save text.
}
```

`DiffConflictResolution` is `.ours`, `.theirs` or `.both` (upstream's Current,
Incoming and Both). `resolved_text` is none while a conflict is unresolved and
for a file that is part of a patch rather than whole; `diff_conflict_kept` and
`diff_resolve_text` do the same on a file without a state.

## State

```v
mut state := ui2.diff_state(files, mode: .split, context_lines: 3)
state.set_mode(.unified)
state.set_context_lines(5) // -1 shows every supplied line
state.set_expansion_lines(20) // lines one reveal step shows
state.set_min_collapsed_lines(2) // shorter unchanged ranges stay visible
state.expand_unchanged() // show all; collapse_unchanged folds again
state.set_inline_unit(.character) // .word (default), .character or .none
state.set_file_collapsed('docs/old.md', true)
state.set_annotations(notes)
state.set_files(newer_files) // resets reveals, selection and resolutions
```

Unchanged runs keep `context_lines` lines next to each change and fold the
rest into a row showing how many lines are hidden and which; its buttons reveal
`expansion_lines` more below the source above, above the source below, or all
of them. In a patch only the supplied context can fold and be revealed; the
gaps between hunks are separator rows. A reference file never folds; a
conflicted working file folds around its conflicts.

## The view

```v
ui2.diff_view(ui2.DiffViewConfig{
	id:       'review'
	frame:    ui2.rect(300, 64, 960, 700)
	state:    app.diff
	scroll_y: ui2.scroll_offset(ui2.diff_body_id('review'))
	theme:    ui2.component_theme(app.dark)
})!
```

- **Unified** shows the original and modified line numbers, a `+` or `−` and
  the code, removed lines above added ones. **Split** puts the original on the
  left and the modified version on the right, pairing the n-th removed line of
  a change with its n-th added line and leaving an empty cell where a line has
  no counterpart. A reference or conflicted working file has one column in
  both modes.
- **Inline emphasis.** Paired changed lines get boxes behind the words (or
  characters) that differ, placed with `measure_text_width` in the monospace
  face: the view measures the face's advance and the inset the backend's
  labels add, so the boxes line up with the glyphs on AppKit, Win32 and the
  custom renderer alike. Pairs with less than half of their text in common get
  none; lines longer than `inline_max_line_length` (1,000) neither.
- **Colors** come from `ComponentTheme`: additions from `success`, removals from
  `danger`, modified pairs (with `.bars`) from `warning`, the current conflict
  part from `primary`, folds and hunk separators from a trace of `primary`,
  selection from `primary`; dark themes get stronger tints.
- **File headers** have a collapse chevron (the whole header toggles), the path
  or `old → new` for a rename or copy, `+N −M` with five blocks in proportion,
  and a status badge (Modified, Added, Deleted, Renamed, Copied, Binary, the
  number of open conflicts, or Resolved).
- **Annotations** (`DiffAnnotation{id, path, side, line, title, text, tone}`)
  are cards under their line, on that side's half in Split mode, or under the
  header for `line: 0`. They wrap their text to the width; set
  `render_annotation` to draw your own content into the card and `height` to
  its height. An annotation on a folded line shows when the line is revealed.
- **Appearance options:** `line_numbers`, `header_visible`,
  `hunk_separator` (`.metadata` for the `@@` line, `.line_info` for the number
  of lines the patch leaves out, `.simple` for a thin divider),
  `change_indicator` (`.signs`, `.bars`, `.none`), `change_background`,
  `empty_text`, `bordered`, `size`, `overscan`.
- **Long lines** are never wrapped: each file's code column scrolls sideways on
  its own, with its scroller in the gap below the file. Lines are drawn with
  tabs expanded to four columns and cut after 2,000 characters.
- **Virtualization.** Row heights go into a `VirtualListLayout`
  (`ui/component_lists_virtual.v`); only the rows near `scroll_y` are built,
  `overscan` (12) more on each side, so a build makes the same few dozen rows
  whatever the size of the diff and only adds up their heights.

### Selection and copying

Click a line number, or a line's code, to select that line; Shift-click
another to extend the inclusive range from the anchor (`key_modifiers()` is
read while the click is handled). In Unified mode a range may cross from
removed to added lines; in Split mode a click on the other side starts over.

```v
state.set_selected_lines(ui2.DiffLineRange{
	path:  'src/main.v'
	side:  .modified
	start: 3
	end:   8
})
lines := state.selected_text(.source) // also .original, .modified, .patch
ui2.diff_copy_selection(state, .patch) // through set_clipboard_text
```

`selected_text` returns source without line numbers, markers or annotations:
`.source` is the selection's own side, `.original` and `.modified` that
version of the span it covers, `.patch` the span as `-`/`+`/space lines with
any `\ No newline at end of file` marker. A range is clipped to the lines the
file has; one with none of them clears the selection.

### Coordinates, navigation and keys

```v
row := state.reveal_line(ui2.DiffLinePosition{'src/main.v', .modified, 120}) or { -1 }
ui2.scroll_to_offset(ui2.diff_body_id('review'), ui2.diff_scroll_offset_for_row(config, row, .center))
header := state.file_row('src/main.v') or { 0 }
if e := ui2.diff_navigate(config, true, false) { // next change; true for hunks
	state.apply(e) // marks it as the current change
	ui2.scroll_to_offset(ui2.diff_body_id('review'), e.offset)
}
```

`row_position(row, side)` and `row_for_line(position)` map between rows and
source lines; `reveal_line` also expands a collapsed file and the fold around
the line. `change_rows`, `next_change`, `previous_change`, `hunk_rows`,
`next_hunk` and `previous_hunk` are pure helpers over the rows (changes wrap
across files); `diff_navigate` starts from the change navigation last went to
while it is on screen, otherwise from the top of the body, and marks the new
one with an accent bar. `diff_top_position(config)` is the source line at the
top, to scroll back to after a mode or context change.

Components cannot take focus, so `diff_event_from_key(config, event)` is for
the application's `on_key_event` while the diff is what the keyboard drives:

| Key | Event |
| --- | --- |
| Up / Down, Page Up / Page Down, Home / End | `.scroll` to `offset` |
| Shift+Up / Shift+Down | `.select`, extending the line selection |
| Cmd+C / Ctrl+C | `.copy` (with a selection) |
| Cmd+A / Ctrl+A | `.select` every line of the selected or topmost file's side |
| Escape | `.clear_selection` |
| F7 / Shift+F7 | `.navigate` to the next / previous change |
| Alt+Down / Alt+Up | `.navigate` to the next / previous hunk |

## Events

| `DiffEventKind` | When | Upstream |
| --- | --- | --- |
| `file_collapsed` | A header was clicked: `path`, `collapsed` | `FileCollapsed` / `FileExpanded` |
| `reveal` | A fold button: `row`, `edge` (`.top`, `.bottom`, `.all`) | (internal) |
| `select` | A line click or key: `range`, `anchor` | `SelectionChanged` |
| `clear_selection` | Escape | `SelectionChanged(None)` |
| `conflict_resolved` | Accept or Undo: `path`, `conflict`, `resolution`, `undo` | `ConflictResolved` |
| `copy` | Cmd+C: `format` | (Diff copies itself) |
| `scroll` | A scrolling key: `offset` | (Diff scrolls itself) |
| `navigate` | F7, Alt+arrows, `diff_navigate`: `row`, `offset` | `next_change` |

## Implemented and omitted

Implemented: parsing unified and Git patches with every documented form and
error reporting; reference and conflicted working files; diff3 conflicts with
Accept Current / Incoming / Both and Undo, `resolved_text`; unified and split
modes; context lines, partial and full reveals, expansion and minimum folded
lengths, expand/collapse all, no folding; inline word or character emphasis
with the similarity cut-off and length limit; file headers with collapse,
rename, counts and status; summaries for files without rows; multiple files in
one virtualized list; annotations on lines and files with custom content;
hunk separators (metadata, line info, simple); change indicators (signs, bars,
none) and `change_background`; line numbers and header visibility;
independent horizontal scrolling of long lines; source coordinates, reveal and
scroll to a line or file; change navigation across files with wrapping;
line selection with Shift extension and crossing ranges; copying source;
`set_files` keeping collapsed files; keyboard scrolling, Shift+Up/Down,
copy, select all. New in ui2: computing diffs, unified output, commit headers,
copy as original, modified or patch text, hunk navigation and key bindings for
navigation, the current-change marker.

Omitted, with the reason:

- **Syntax highlighting** (`syntax_highlight`, `with_language`, the syntax
  length limit). ui2 has no highlighter, and a label has one style: colored
  tokens would mean a label per token per line.
- **Soft wrap.** Rows have one height per kind so the layout stays cheap for
  huge diffs; long lines scroll sideways instead.
- **Text selection by dragging over code**, drag selection over line numbers,
  and the `SelectionStarted` / `SelectionEnded` events. Labels are not
  selectable and composed views do not report drags as selections; click and
  Shift-click select lines instead, and every change is one `select` event.
- **Hover highlight, `on_line_hover`, `on_line_click` and
  `on_add_annotation`'s hover button.** A hover report per row would double the
  elements of every row; a click on a line's code selects it, which the
  application observes, and it can add annotations from the selection.
- **Header render slots** (`render_header_prefix`, `..._title_suffix`,
  `..._suffix`, `render_header`). The header has a fixed layout; put
  per-file controls in the application's file list, or in an annotation with
  `line: 0`.
- **Focus by Tab and built-in key bindings.** Components cannot take focus;
  `diff_event_from_key` is the binding table for the application.
- **Background preparation.** Emphasis is computed for the rows in view while
  they are built, and the row model once per change, so there is nothing to
  prepare off the UI thread.

## Accessibility

The view is a `group` labelled `Diff` (or `accessibility_label`) whose value
counts files, additions and deletions; the body is a `list`. Source rows are
`row`s labelled like `Added line 12: text`; line numbers and code are buttons
(`Select modified line 12`); file headers are buttons labelled `Collapse
<path>` or `Expand <path>` with the value `expanded` or `collapsed`; fold
buttons are labelled with what they reveal; conflict actions are native
buttons; annotations use the ARIA role `note`, which AppKit currently leaves at
the native role.

## Platform notes

- The custom renderer shows scrollers while content overflows; each code
  column's horizontal scroller therefore sits in the gap below its file,
  never over code. AppKit's overlay scrollers appear while scrolling.
- Native backends rebuild after `on_scroll` asks for it; the rows in
  `overscan` cover a fast scroll until the rebuild arrives.

## Attribution

No upstream code is adapted. The API follows the documentation (names, events,
the conflict headings and buttons, 3 context lines, 20 expansion lines, 2
minimum collapsed lines, the 1,000-character inline limit); the parser, the
diff algorithm, the row model and the view are new implementations.

## Verification

```sh
v test ui/component_diff_test.v
v -d ui2_custom_rendering test ui/component_diff_test.v
v run examples/gpui_diff/main.v
v -d ui2_custom_rendering run examples/gpui_diff/main.v
```
