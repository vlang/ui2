# Select, combobox and command palette

Ports of GPUI Kit's [select](https://github.com/longbridge/gpui-kit/blob/main/website/component/select.md),
[combobox](https://github.com/longbridge/gpui-kit/blob/main/website/component/combobox.md)
and [command](https://github.com/longbridge/gpui-kit/blob/main/website/component/command.md).
The implementation is in `ui/component_pickers.v` (options, matching, the shared
list), `ui/component_pickers_select.v`, `ui/component_pickers_combobox.v` and
`ui/component_pickers_command.v`. `examples/gpui_pickers/main.v` shows all of
them with a select and a combobox list open and a command panel mid-search;
start it with `UI2_PICKERS_PALETTE=1` to open the ⌘K palette at once.

## Conventions

These follow the [popovers](popovers.md) and [inputs](inputs.md) batches.

- **Popups are overlays.** A select's popup (`select_popup`), a combobox's list
  (`combobox_popup`) and the modal command palette are drawn on top of the
  window: add them after everything they may cover, as the last children of the
  screen. Each takes `window` (pass `ui2.bounds()`) and opens from the trigger.
  The trigger's `frame` is in its parent's coordinates; when the trigger is not
  a direct child of the screen, also pass its window rectangle as `anchor`.
- **Controlled state.** The application owns the open state, the highlighted
  option, the query and the selection. Every component has a config struct;
  build it from the model in one function and use it both to build and to
  decode. Decoders return a *step* — the next state plus what changed — and
  return none for events that are not the component's, are forged or
  malformed, name a disabled option or one the query hides, or change nothing.
- **Fields carry their text.** A search field or a combobox field emits its id
  on every edit; read the text with `ui2.text(id)` and pass it to the matching
  function: `select_search`, `combobox_input`, `command_palette_search`. The
  `*_search_id` and `combobox_field_id` helpers return those ids.
- **After rebuilding.** A step's `focus` names a field to focus once the new
  tree exists (the search field of a select that just opened, the palette's
  field, the combobox field after a press on its list): call `ui2.refresh()`,
  then `ui2.focus(step.focus)`. To keep the highlighted row visible after an
  arrow key, call `ui2.scroll_to_rect(list_id, r.x, r.y, r.width, r.height)`
  with the rectangle from `select_highlight_rect`, `combobox_highlight_rect` or
  `command_palette_highlight_rect` and the id from `select_list_id`,
  `combobox_list_id` or `command_palette_list_id`. Do that after keys and
  edits only: scrolling to a row the pointer highlighted would slide the next
  row under the pointer, which would highlight that one in turn. The gallery's
  `settle` does both.
- **Keys.** Components cannot capture keys: `select_key`, `combobox_key`,
  `command_palette_key` and `command_palette_toggle_key` are pure helpers for
  `on_key_event`. Consume the key when they return a step, unless the step's
  `propagate` is set (Tab closes a list but should still move the focus).
- **Size and theme.** `size` is a `ComponentSize`; colors come from
  `ComponentTheme`. Surfaces are the rounded, shadowed panels of the popovers.

### Which keys reach `on_key_event` while a field has focus

Measured on AppKit with a probe that queued key events for a key window whose
`NSTextField` (with a delegate and an action, as ui2 sets them up) was being
edited; the custom renderer gives every key to `on_key_event` first.

| Key | AppKit | Custom renderer |
| --- | --- | --- |
| Up, Down, Page Up, Page Down | `on_key_event`, before the field moves the caret | `on_key_event`, then the field |
| Escape | `on_key_event`, after the field editor passed on it | `on_key_event` |
| Return | The field only: it emits its `submit_id` | `on_key_event`, then the field's `submit_id` |
| Tab, Shift+Tab | `on_key` only, as `'tab'` / `'shift+tab'` | `on_key_event`, then `on_key` |

So every field here has a `submit_id`, and the decoders treat it as Enter:
`select_update`, `combobox_update` and `command_palette_update` choose the
highlighted option when it arrives. On the custom renderer the key helpers
consume Enter first, so it is never handled twice. The gallery passes Tab from
`on_key` through the same routing as other keys (`on_tab`).

## Options and matching

```v
ui2.PickerOption{
    value:       'go'            // identity: unique, non-empty; what decoders report
    label:       'Go'            // shown and searched (the value when empty)
    description: 'Garbage collected, concurrent' // muted second line
    icon:        'bolt'          // a symbol name (symbol_known)
    group:       'Compiled'      // heading; options are gathered under it
    keywords:    ['golang']      // also searched, not shown
    enabled:     true
}
ui2.picker_option('apple', 'Apple') // the short form
```

Groups appear in the order of their first option, and options keep their order
within a group. `validate_picker_options` rejects missing or repeated values and
icons not every renderer can draw.

`picker_match(query, text, mode)` matches ignoring case (ASCII, Latin-1, Greek
and Cyrillic letters; accents are not folded) and returns a `PickerMatch` with a
`score` and the matched `ranges` (rune offsets, end excluded). A blank query
matches everything with score 0.

- `.substring` — the query appears in the text as typed. GPUI Kit's search.
- `.fuzzy` — the query's characters appear in order, with gaps; spaces in the
  query are skipped, so `new fi` finds "New File".

Both modes share one scale. Each matched character earns 16 points, a
character right after the previous match 10 more, and a match after a gap
earns a bonus for where it lands — the start of the text (12), of a word (8),
of a capitalized camelCase part (6) or of a number (4) — less 3 for the gap and
1 per further skipped character. Characters skipped before the first match
cost 1 each, up to 8, and matching the whole text adds 24. The fuzzy matcher
finds the alignment with the best score by dynamic programming (time
proportional to query × text length; text past 512 characters is ignored), so
"ab" in "a-xb ab" highlights the contiguous "ab" at the word start, not the
first `a` and `b`. Contiguous beats scattered, prefixes beat inner matches.

`picker_option_match` also tries the keywords; a keyword match scores 12 less
than the same match in the label and highlights nothing. `picker_filter(options,
query, mode, sort)` returns `PickerHit`s (option index, score, ranges) grouped
as above; with `sort` and a query, groups are ordered by their best match and
options by score.

Matched characters are marked with a tinted box behind them, like a highlighter
pen. ui2 cannot style part of a label, and a bold run built from separate labels
would show gaps where the width estimates are off; a marker forgives that.

## Select

```v
fn language_config(app &App) ui2.SelectConfig {
    return ui2.SelectConfig{
        id:          'language'
        frame:       ui2.rect(24, 120, 260, 32) // the trigger
        window:      ui2.rect(0, 0, ui2.bounds().width, ui2.bounds().height)
        options:     languages()
        selected:    app.languages      // []string of values
        state:       app.language_state // ui2.SelectState
        searchable:  true
        clearable:   true
        placeholder: 'Choose a language'
        theme:       app.theme
    }
}

// build: the trigger in place, the popup last.
children << ui2.select_box(language_config(app))!
// ...
children << ui2.select_popup(language_config(app))!

// on_event:
if event == ui2.select_search_id('language') {
    app.apply(ui2.select_search(language_config(app), ui2.text(event)))
} else if step := ui2.select_update(language_config(app), event) {
    app.apply(step)
}

// on_key_event, while it is open:
if step := ui2.select_key(language_config(app), event) {
    if !step.propagate {
        ui2.consume_key()
    }
    app.apply(step)
}

fn (mut app App) apply(step ui2.SelectStep) {
    app.language_state = step.state
    if step.changed {
        app.languages = step.selected
    }
    // after ui2.refresh(): focus step.focus when set, and scroll
    // select_highlight_rect into view in select_list_id('language').
}
```

`select` is a V keyword, so the trigger is `select_box`. Pressing it emits
`select_toggle_action(id)`; a press outside the popup emits
`select_dismiss_action(id)`; rows emit `select_option_action(id, value)` and
report the pointer entering them, which moves the highlight. Choosing in a
single select takes the option and closes the popup (`changed` is false when it
was already chosen); in a multiple select it adds or removes the option and
the popup stays open on it. Opening highlights the first chosen option, or the
first enabled one; closing forgets the query.

| `SelectConfig` field | Meaning |
| --- | --- |
| `options`, `selected`, `state` | The options, the chosen values (at most one unless `multiple`), and `SelectState{open, highlight, query}`. |
| `multiple`, `display` | Several choices, shown `.tags` (removable tags as far as they fit, then "+N"), `.count` (`count_format`, default `'{count} selected'`) or `.list` (comma-joined). |
| `placeholder`, `title_prefix` | Shown with nothing chosen; text before the chosen label ("Theme: " → "Theme: System"). |
| `icon` | A symbol replacing the chevron. The chosen option's own icon is drawn before its label. |
| `searchable`, `search_placeholder`, `match_mode` | A search field at the top of the popup (an `input_group` with a magnifying glass); substring matching by default. |
| `clearable` | A clear button replaces the chevron while something is chosen (`select_clear_action`). |
| `enabled`, `invalid` | Disabled: muted and inert, its popup closed. Invalid: the danger border. |
| `separators`, `empty_text` | Lines between groups; the text shown when nothing matches. |
| `menu_width`, `max_height` | Popup width (the trigger's by default, at least 120) and height (320, search field included; the window limits it too). The popup opens below the trigger, or above when only there it fits, and scrolls when its options are taller. |
| `accessibility_label`, `size`, `theme` | The trigger's accessible name (the placeholder by default), size preset and colors. |

Keys while the popup is open (`select_key`): Up and Down move the highlight,
wrapping and skipping disabled options; Page Up and Page Down jump to the ends;
Enter chooses; Escape closes; Tab closes and propagates. Without a search
field, Space chooses, Home and End jump to the ends and a letter or digit jumps
to the next option starting with it; with one, those keys type. A closed select
takes no keys: ui2's triggers are not keyboard-focusable views, so an
application that tracks a focused trigger itself opens it on
`select_open_key(event)` (Down, Up, Enter or Space).

Other helpers: `select_titles` (chosen titles, unknown values skipped),
`select_display_text` (what the trigger says), `select_remove_action` (a tag's
remove button).

### Select or `dropdown`?

`ui2.dropdown` is the platform's own pop-up button: NSPopUpButton on macOS, a
Win32 combo box, a drawn list in the custom renderer. Use it for a plain list of
strings when looking native matters more than looking the same everywhere — it
follows the system's keyboard handling, accessibility and menu look, needs no
overlay or state of its own, and emits the chosen string. Use `select_box` when
you need what a native pop-up cannot do the same way on every backend: groups
with headings, icons and descriptions, disabled rows, a search field, several
choices shown as tags or a count, a clear button, a placeholder, sizes and
theme colors that match the rest of the components, and identical rendering on
AppKit, Win32 and the custom renderer.

## Combobox

A text field with a list under it that filters as the user types. The field
keeps the keyboard focus: arrows move the highlight, Enter picks, Escape closes.
Picking puts the option's title in the field and commits its value.

```v
fn city_config(app &App) ui2.ComboboxConfig {
    return ui2.ComboboxConfig{
        id:          'city'
        frame:       ui2.rect(24, 120, 280, 32)
        window:      ui2.rect(0, 0, ui2.bounds().width, ui2.bounds().height)
        text:        app.city       // what the field holds
        value:       app.city_value // the committed option, '' for none
        options:     cities()
        state:       app.city_state // ui2.ComboboxState{open, highlight}
        placeholder: 'Search a city'
        clearable:   true
        theme:       app.theme
    }
}

children << ui2.combobox(city_config(app))!
// ...
children << ui2.combobox_popup(city_config(app))!

// on_event:
if event == ui2.combobox_field_id('city') {
    app.apply(ui2.combobox_input(city_config(app), ui2.text(event)))
} else if step := ui2.combobox_update(city_config(app), event) {
    app.apply(step)
}

// on_key_event, while ui2.focused_id() == ui2.combobox_field_id('city'):
if step := ui2.combobox_key(city_config(app), event) { ... }

fn (mut app App) apply(step ui2.ComboboxStep) {
    app.city = step.text
    app.city_value = step.value
    app.city_state = step.state
    match step.change {
        .picked { /* an option was picked */ }
        .submitted { /* Enter with nothing highlighted: decide what step.text means */ }
        else {}
    }
}
```

- **Filtering.** `match_mode` (substring by default), `sort` (best first),
  `min_chars` (typing opens the list once the text is that long) and `max_rows`
  (show at most that many matches). While the text is the committed option's
  title the list shows every option, so reopening it offers the other choices.
- **Highlight.** `auto_highlight` (default on) highlights the first match as the
  user types, so Enter picks it. Off, Enter submits the typed text unless an
  arrow key highlighted something.
- **Free text.** Typing a text that is no longer the committed title clears the
  committed value; Enter with nothing highlighted reports `.submitted` with the
  text. That covers what a "creatable" combobox does without a special row.
- **Loading.** The list is application-driven: set `loading` while results are
  on their way and the list shows a spinner and `loading_text` instead of
  `empty_text`. The gallery's module search answers after 0.6 s with `ui2.after`
  and ignores stale answers.
- **Parts.** An optional leading `icon`, the native field (accessibility role
  `combobox`, value `expanded`/`collapsed`), a clear button with `clearable`, and
  a chevron button (`combobox_toggle_action`) that opens the full list.
- **Dismissal.** The list's backdrop covers the window *except* the combobox,
  so a press elsewhere closes the list (`combobox_dismiss_action`) while a press
  on the field still places the caret.

Keys (`combobox_key`): Down and Up open the list (at the committed option, or
the first or last one) and then move the highlight, wrapping and skipping
disabled options; Page Up and Page Down jump to the ends; Enter picks the
highlighted option; Escape closes the list; Tab closes it and propagates.
Home, End, Left, Right and typing stay with the field.

## Command palette

```v
fn palette_config(app &App) ui2.CommandPaletteConfig {
    return ui2.CommandPaletteConfig{
        id:     'palette'
        window: ui2.rect(0, 0, ui2.bounds().width, ui2.bounds().height)
        state:  app.palette // ui2.CommandPaletteState{open, query, highlight}
        items:  [
            ui2.CommandPaletteItem{
                id:       'open'
                label:    'Open File…'
                icon:     'folder'
                shortcut: 'cmd+o' // shown ⌘O on macOS, Ctrl+O elsewhere
                group:    'Files'
                keywords: ['load']
            },
            // ...
        ]
        recent: app.recent // ids, most recent first
        theme:  app.theme
    }
}

children << ui2.command_palette(palette_config(app))! // last

// on_key_event, first:
if step := ui2.command_palette_toggle_key(palette_config(app), event) { // ⌘K / Ctrl+K
    ui2.consume_key()
    app.apply(step)
} else if app.palette.open {
    if step := ui2.command_palette_key(palette_config(app), event) {
        ui2.consume_key()
        app.apply(step)
    }
}

// on_event:
if event == ui2.command_palette_search_id('palette') {
    app.apply(ui2.command_palette_search(palette_config(app), ui2.text(event)))
} else if step := ui2.command_palette_update(palette_config(app), event) {
    app.apply(step)
}

fn (mut app App) apply(step ui2.CommandPaletteStep) {
    app.palette = step.state
    if step.chosen {
        app.recent = ui2.command_palette_remember(app.recent, step.item.id, 5)
        app.run(step.item.id)
    }
    // after ui2.refresh(): focus step.focus (the search field on opening).
}
```

The modal palette sits at the top center of the window (`top`, by default 12%
of the window height; `width` 560, narrowed to fit) over a dimming backdrop
(`backdrop`, any `DialogBackdrop`; with `.none` the page stays interactive).
It has a search field, the list (`max_height` 340, scrolling past it) and a
footer with key hints and the number of results.

- **Search.** Fuzzy by default (`match_mode`), matched against the label and
  the keywords, best matches first (`sort`). A group whose commands all filter
  out loses its heading, separators stay between the groups that remain, and
  the highlight moves to the first enabled command whenever the query changes.
  `command_palette_matches(config)` returns what is shown, with each label's
  match ranges.
- **Recent.** While the query is empty, the commands in `recent` are listed
  first under `recent_label` ("Recent") and not again in their groups.
  `command_palette_remember(recent, id, limit)` keeps such a list.
- **Rows.** Icon, label (matches marked), optional description, and at the
  right the shortcut (`menu_shortcut_label`) or, for a `checked` command
  without one, a check mark. Disabled commands are muted and skipped.
- **Empty and loading.** `empty_text` ("No results found.") when nothing
  matches; with `loading` (application-driven, for remote search) a spinner
  and `loading_text` instead, and a spinner in place of the result count while
  stale results stay listed.
- **Keys** (`command_palette_key`): Up and Down move, wrapping and skipping
  disabled commands; Page Up and Page Down jump to the ends; Enter runs the
  highlighted command; Escape clears a non-empty query first and closes on the
  next press. Tab is for `command_palette_focus_trap(config)`, which keeps the
  focus on the search field while the palette is open (see the dialogs'
  [focus trap](dialogs.md#focus-trap)).
- **Shortcut.** `command_palette_shortcut(event)` is ⌘K on macOS and Ctrl+K
  elsewhere; `command_palette_shortcut_label()` writes it the platform's way for
  a button or a hint.
- **Inline.** With `modal: false` and a `frame`, the same palette is a bordered
  panel in the page (GPUI Kit's inline `Command`): no backdrop, never "closed",
  and running a command keeps the query. The gallery shows one.
- `searchable: false` drops the search field (a compact action list), and
  `footer: false` the footer.

Running a command closes a modal palette and reports `chosen` with the
`CommandPaletteItem`. A press outside closes it (`command_palette_dismiss_action`).

## Accessibility

| Part | Role | Label / value |
| --- | --- | --- |
| Select trigger | `combobox` inside a `group` | `accessibility_label` (placeholder by default) / the chosen text or the placeholder |
| Combobox field | `combobox` | `accessibility_label` / `expanded` or `collapsed` |
| Popup surfaces | `list`; the modal palette `dialog` | the component's label |
| Rows | `option` (a button with `button_behavior`) | the title / `selected` when chosen |
| Group headings, separators, messages | `text`, `separator`, `status` | heading text, message |

AppKit keeps the native role for `option`, since the role
mapper does not know it; `listbox` and `option` mappings are requested below.
Tag remove buttons are labeled "Remove <title>", clear buttons "Clear", the
combobox chevron "Show options"/"Hide options".

## Parity with GPUI Kit

### Select

| Upstream | ui2 |
| --- | --- |
| Items, placeholder, `title_prefix`, `icon`, `cleanable`, sizes, disabled | Implemented (`clearable`). |
| Searchable with `search_placeholder`, `SelectItem::matches` | Implemented: search field, `match_mode`, `keywords` for extra terms. |
| Groups (`SelectGroup`) | Implemented with `PickerOption.group`, plus optional separators. |
| `menu_width`, `menu_max_h` | `menu_width`, `max_height`. |
| `SelectEvent::Confirm`, `set_selected_index/value`, `set_items` | Controlled state: steps report `changed` and `selected`; the application sets values and options directly. |
| Keyboard: Enter, Up/Down, Escape, Space | `select_key` while open; `select_open_key` for an application-tracked focused trigger. |
| Accessibility label and committed value | Implemented. |
| Disabled items, icons, descriptions | Implemented (upstream allows them through custom items). |
| Multiple selection | Added: upstream Select is single, its Combobox is the multi-select; here `multiple` with tags, a count or a list. |
| Custom `display_title` / item elements, custom `empty` element | Omitted: rows and the trigger are drawn by the component; `empty_text` sets the message. |
| `appearance(false)` (borderless, for embedding in an input) | Omitted: a native-looking border is part of the trigger; place it beside an `input_group` instead. |
| `scroll_bounce`, focus ring | Omitted: scrolling is the backend's; an open select shows a primary border instead of a ring, and triggers are not focusable. |

### Combobox

GPUI Kit's Combobox is a button trigger with a searchable popup that can choose
several values. The brief for ui2's combobox is the classic autocomplete text
field, so the multi-select trigger lives in `select_box(multiple: true)`.

| Upstream | ui2 |
| --- | --- |
| Searchable list, grouped items, disabled items | Implemented. |
| `cleanable`, sizes, disabled, placeholder | Implemented (`clearable`). |
| Keyboard: Up/Down open and move, Enter confirms, Escape closes | Implemented from the field, which keeps the focus. |
| `Change` / `Confirm` events | `ComboboxStep.change`: `.typed`, `.picked`, `.submitted`, `.cleared`. |
| `multiple(true)`, tags in the trigger | In `select_box`. |
| Custom trigger (`render_trigger`), custom check icon, footer action slot | Omitted: the trigger is a native field; a footer button is easy to place under the field. |
| Creatable values | Not in upstream; Enter with nothing highlighted reports the free text (`.submitted`). |
| Loading state | Added: `loading` and `loading_text`, application-driven. |

### Command

| Upstream | ui2 |
| --- | --- |
| Items, groups with headings, separators | Implemented; separators are drawn between groups (`separators`). |
| Label and `keywords` search, groups hiding when empty | Implemented, with fuzzy scoring and match ranges added (substring is available as `match_mode: .substring`). |
| Icons, `checked`, disabled items | Implemented. |
| Keybinding hints from Actions | `shortcut` strings rendered by `menu_shortcut_label`: ui2 has no action registry. |
| `searchable(false)`, `placeholder`, `empty`, `max_h` | `searchable`, `placeholder`, `empty_text`, `max_height`. |
| `set_loading` | `loading`, `loading_text`. |
| Keyboard: arrows wrap and skip disabled, Enter, Escape clears a query first | Implemented. |
| `on_query`, `on_select`, `on_confirm`, `on_cancel` | `command_palette_search`, the step's `state.highlight`, `chosen`, and a closed `state`. |
| In a dialog | The modal palette (backdrop, top center, focus trap) and `command_palette_toggle_key` for ⌘K / Ctrl+K. |
| Inline palette | `modal: false` with a `frame`. |
| Recent items | Added (`recent`, `command_palette_remember`). |
| Result count and key hints | Added as the built-in footer. |
| `header` / `footer` slots, custom row `child`, `bordered(false)` | Omitted: rows and chrome are drawn by the component. |
| Virtualized rows, `scroll_bounce` | Omitted: every row is built (fine for hundreds of commands); scrolling is the backend's. |

## Attribution

The command palette's filtering and navigation rules (label and keyword
search, hidden empty group headings, the highlight resetting to the first
enabled command, wrapping navigation that skips disabled commands, Escape
clearing the query first) follow `crates/component/src/command/state.rs` of
GPUI Kit (Longbridge, Apache-2.0); `ui/component_pickers_command.v` carries the
header. See the [attribution](../../third_party/gpui-kit/NOTICE.md). The
matcher, the select, the combobox and all rendering are new code.

## Verification

```sh
v test ui/component_pickers_test.v
v -d ui2_custom_rendering test ui/component_pickers_test.v
v run examples/gpui_pickers/main.v
v -d ui2_custom_rendering run examples/gpui_pickers/main.v
UI2_PICKERS_PALETTE=1 v run examples/gpui_pickers/main.v
```

The tests cover the matcher (blank queries, case folding beyond ASCII, rune
ranges, word-start and camelCase bonuses, the best alignment rather than the
first, ranking, keywords), filtering, grouping and sorting, wrapping navigation
and typeahead, value encoding and forged parts, and for each component its
validation, elements, every decoded event and key, forged, disabled and hidden
options, popup placement and scrolling, the combobox's backdrop hole and
loading state, and the palette's recent items, search, Escape behavior, inline
form and shortcut.
