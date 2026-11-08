# Lists, virtual lists and searchable lists

Ports of GPUI Kit's [list](https://github.com/longbridge/gpui-kit/blob/main/website/component/list.md),
[virtual list](https://github.com/longbridge/gpui-kit/blob/main/website/component/virtual-list.md),
and the searchable list behind [select](https://github.com/longbridge/gpui-kit/blob/main/website/component/select.md)
and [combobox](https://github.com/longbridge/gpui-kit/blob/main/website/component/combobox.md).
The implementation is in `ui/component_lists_virtual.v` (virtual list),
`ui/component_lists.v` (list) and `ui/component_lists_search.v` (matching and
the searchable list). The reorder container, which GPUI Kit does not have, is in
`ui/component_reorder.v`. `examples/gpui_lists/main.v` shows a sectioned list with
multiple selection, loading and empty lists, a virtual list of 10,000 rows of
different heights, and two searchable lists, one of them with no results.

## Conventions

- **Controlled state.** The application owns the selection, the keyboard
  cursor, the hovered row and the search query. Components emit actions; the
  decoders (`list_update`, `searchable_list_update`) and key helpers
  (`list_key`, `searchable_list_key`, `VirtualListLayout.index_after_key`) turn
  an event into the next state, rejecting actions that belong to something else,
  are malformed or forged, name rows the list does not show, separators or
  disabled rows, or change nothing. Store the result and rebuild.
- **Rows are named by id.** A row's `id` is unique across its list, and the
  selection is a list of ids, so it survives filtering, sorting and rows being
  added. Ids are hex-encoded into actions, so they may contain any character.
- **Scroll positions come from `on_scroll`.** Components cannot call backend
  functions, so a list takes its scroll position as `offset`. Store
  `scroll_offset(id)` when `on_scroll` reports the list's scroll id, and pass
  scroll targets the helpers compute to `scroll_to_offset`. Request the rebuild
  with `request_refresh()` rather than calling `refresh()` from the scroll
  handler: a scroll can be reported while a rebuild is under way (when a new
  tree changes how far the content reaches, say).
- **Keys.** Components cannot capture keys: call the key helpers from
  `on_key_event` and `consume_key()` whenever they return a step.
- **Size and theme.** `size` is a `ComponentSize`, colors come from
  `ComponentTheme`.

## Virtual list

```v
// Once, and again whenever the sizes change:
m.layout = ui2.virtual_list_sized(heights, 0)! // or virtual_list_fixed(count, 36, 0)!

// build:
ui2.virtual_list(
	id:     'people'
	frame:  frame
	layout: m.layout
	offset: m.offset
	item:   fn [m] (index int, frame ui2.Rect) ui2.Element {
		return row_for(m, index, frame)
	}
)!

// on_scroll: rebuild only when the rows to show change.
fn on_scroll(id string) {
	if id == 'people' {
		m.offset = ui2.scroll_offset(id)
		next := m.layout.range(viewport, m.offset, 3)
		if next.start != m.built.start || next.end != m.built.end {
			ui2.request_refresh()
		}
	}
}

// Scroll to an item:
ui2.scroll_to_offset('people', m.layout.scroll_offset_for(5000, viewport, m.offset, .center))
```

A Scroll element is as long as its lowest child, so `virtual_list` adds one
empty spacer the length of the whole content and positions only the items in
range inside it, each keyed by its index (`item:<index>`) so a row that stays in
range keeps its native view while the list scrolls. The gallery's 10,000 rows
build 22 elements at a time.

`VirtualListLayout` holds the item extents along the list's axis. The zero
value is an empty list.

| Function | Purpose |
| --- | --- |
| `virtual_list_fixed(count, item_size, gap) !VirtualListLayout` | One size for every item; stores nothing per item. |
| `virtual_list_sized(sizes, gap) !VirtualListLayout` | A size each; stores the running total so lookups are binary searches. Build it once per change of the sizes. |
| `layout.padded(padding) !VirtualListLayout` | Space before the first item and after the last (GPUI Kit's `paddings`). |
| `layout.total()`, `item_start(i)`, `item_size(i)`, `item_end(i)`, `index_at(position)`, `max_offset(viewport)` | Geometry. |
| `layout.range(viewport, offset, overscan) VirtualListRange` | The items to build: `start`/`end` (overscan included), `visible_start`/`visible_end`, and `before`/`after`, the space the items outside the range would take, for layouts that stack spacers. Offsets are clamped, so a stale one from before the list shrank still shows its end. |
| `range.near_end(count, threshold) bool` | GPUI Kit's `load_more_threshold`: the visible items reach within `threshold` of the end. |
| `layout.scroll_offset_for(index, viewport, current, align) f64` | Where to scroll to show an item: `.nearest` (not at all when it shows), `.start`, `.center` or `.end`; clamped to the content. |
| `layout.index_after_key(current, viewport, event) ?int` | Up, Down, Page Up, Page Down, Home and End, stopping at the ends. |
| `virtual_list(config) !Element` | The Scroll element. `orientation: .horizontal` lays the items out sideways in a `horizontal_only` scroll (read its position with `scroll_horizontal_offset`). |

`VirtualListConfig`: `id` (the scroll's id), `frame`, `layout`, `offset`,
`overscan` (3), `orientation`, `item`, `transparent`, `accessibility_label`,
`theme`.

| GPUI Kit | ui2 |
| --- | --- |
| `v_virtual_list`, `h_virtual_list` | `virtual_list` with `orientation` |
| Variable item sizes, gap, paddings | `virtual_list_sized`, `gap`, `padded` |
| Render callback for the visible range | `item`, called once per item in range |
| `scroll_to_item(ix, ScrollStrategy)`, `scroll_to_bottom` | `scroll_offset_for` (`.nearest`, `.start`, `.center`, `.end`) and `scroll_to_offset` |
| `offset()`, `set_offset()` | `scroll_offset` and `scroll_to_offset`, which the application calls |
| Overdraw past the viewport | `overscan` items on both sides |
| `track_scroll`, `VirtualListScrollHandle` | The scroll's `id` and `on_scroll`, owned by the application |
| `with_item_to_measure_index`, `ListSizingBehavior::Infer` | Omitted: ui2 has no measuring layout pass; items fill the cross axis and the frame is given. |
| Scroll on both axes | Omitted: a vertical list's items are as wide as the frame. |
| `Scrollbar` with axis options | The backend's own scroller. |

## List

```v
fn files_config(m &Model) ui2.ListConfig {
	return ui2.ListConfig{
		id:        'files'
		frame:     ui2.rect(24, 196, 360, 340)
		sections:  [
			ui2.ListSection{
				title: 'Pinned'
				icon:  'star'
				items: [
					ui2.ListItem{
						id:          'readme'
						title:       'README.md'
						description: 'Edited 2 hours ago'
						icon:        'doc.text.fill'
						trailing:    '4 KB'
						actions:     [ui2.ListItemAction{ id: 'share', icon: 'square.and.arrow.up', label: 'Share' }]
					},
					ui2.list_item('notes', 'Meeting notes'),
					ui2.list_separator(),
				]
			},
		]
		state:     m.files
		selection: .multiple
		offset:    m.files_offset
	}
}

// build:
ui2.list(files_config(m))!

// on_event (Cmd/Ctrl-click toggles, Shift-click extends):
if step := ui2.list_update(files_config(m), event, ui2.list_held_modifiers()) {
	m.files = step.state
	if step.confirmed { open(step.item) }
	if step.action == 'share' { share(step.item) }
}

// on_key_event:
if step := ui2.list_key(files_config(m), event) {
	ui2.consume_key()
	m.files = step.state
	if step.reveal {
		config := ui2.ListConfig{ ...files_config(m), state: step.state }
		if offset := ui2.list_reveal_offset(config, step.state.active) {
			ui2.scroll_to_offset(ui2.list_scroll_id('files'), offset) // after refresh()
		}
	}
}

// on_scroll:
if id == ui2.list_scroll_id('files') {
	m.files_offset = ui2.scroll_offset(id)
}
```

`ListItem`: `id`, `kind` (`.item` or `.separator`), `title`, `description` (a
second, muted line that makes the row taller), `icon` (a leading symbol) or
`avatar`/`avatar_image` (a leading avatar), `trailing` (muted text), `badge`
and `badge_tone`, `actions` (icon buttons: `id`, `icon`, `label`, `enabled`),
`menu` (the row's native right-click menu), `enabled`, `accessibility_label`.

`ListSection`: `title` (the header), `icon`, `footer`, `items`. A section
without rows is not drawn, header and footer included, as upstream.

`ListConfig`: `id`, `frame`, `items` or `sections`, `state`, `selection`
(`.none`, `.single`, `.multiple`), `check_icon` (a check mark on selected rows),
`loading`, `empty_title`, `empty_description`, `empty_icon`, `offset`,
`virtualize`, `overscan`, `bordered`, `accessibility_label`, `size`, `theme`.

`ListState`: `selected` (ids), `active` (the keyboard cursor), `anchor` (where a
Shift range starts), `hovered`. `ListStep`: `state`, `confirmed`, `secondary`,
`cancelled`, `item`, `action`, `reveal`.

| Function | Purpose |
| --- | --- |
| `list(config) !Element` | The list. Rows scroll in `list_scroll_id(id)` once they are taller than the frame; content that fits does not scroll. |
| `list_update(config, event, modifiers) ?ListStep` | Row presses (selection; a plain press confirms), row actions, and hover enter/leave. |
| `list_key(config, event) ?ListStep` | The keyboard, below. |
| `list_selection_after_click(config, item_id, modifiers) ?ListState` | The selection rules on their own. |
| `list_reveal_offset(config, item_id) ?f64` | The scroll offset that brings a row into view, scrolling as little as it can from `config.offset`. |
| `list_visible_range(config) !VirtualListRange` | The drawn rows at `config.offset`, for deciding when to rebuild a virtualized list or load more. |
| `list_row(config) !Element`, `list_row_height(item, size)` | One row the way the list draws it, for rows a `virtual_list` builds itself. |
| `list_press(id, action) ?ListPress` | Decodes a press on a row or row action (and the action of a hover event) without looking the row up, for such virtual lists. |
| `list_modifiers(event) ListModifiers` | `toggle` (Cmd or Ctrl) and `extend` (Shift) from a key event. |
| `list_held_modifiers() ListModifiers` | The same from the keys held right now, for a click. |
| `list_row_action(id, item_id)`, `list_item_action_action(id, item_id, action_id)`, `list_scroll_id(id)` | Action and element ids. |

### Selection

| Input | `.single` | `.multiple` | `.none` |
| --- | --- | --- | --- |
| Click | Selects the row and confirms it | Selects only the row and confirms it | Confirms the row |
| Toggle-click (Cmd/Ctrl) | Deselects the selected row, selects another | Adds or removes the row | Confirms the row |
| Extend-click (Shift) | Selects the row | Selects the range from the anchor | Confirms the row |
| Toggle + extend | Selects the row | Adds the range to the selection | Confirms the row |
| Up / Down | Moves the selection, wrapping around | Moves the selection; with Shift, extends the range | Moves the cursor |
| Home / End, Page Up / Page Down | To the first or last row, or a viewport's height | Same; Shift extends | Moves the cursor |
| Space | Selects the active row | Toggles the active row | — |
| Cmd/Ctrl+A | — | Selects every row | — |
| Enter | Confirms the active row (`secondary` with Cmd/Ctrl) | Same | Same |
| Escape | Clears the cursor and reports `cancelled` | Same | Same |

The keyboard skips headers, footers, separators and disabled rows, as GPUI Kit's
row cache does.

**Modifier keys and clicks.** ui2's pointer events do not carry the modifier
keys, so the application passes `ListModifiers` to `list_update`:
`list_held_modifiers()` reads the keys held during the click (`key_modifiers`),
so Cmd/Ctrl-click toggles a row and Shift-click extends from the anchor. On a
touch screen there are no such keys; the gallery adds a Click / Toggle / Range
switch for that. Every keyboard selection works with its real modifiers.

### Looks and states

A selected row is tinted toward the primary color (with a check mark when
`check_icon` is set), the active row that is not selected has a primary ring,
and the hovered row a muted fill; disabled rows are muted and take no hover.
Rows report hover with `hoverable`, so a hover highlight costs one rebuild per
row entered. `loading` draws GPUI Kit's loading view, placeholder rows with a
shimmer, after the rows there are (so it also serves for loading more at the
end); the empty state shows `empty_icon`, `empty_title` and
`empty_description` centered. With `virtualize`, only the rows near `offset`
are built (headers and separators count as rows), so an application that wires
`on_scroll` can give a list thousands of rows.

Accessibility: the list is a `list`, each row a `listitem` (AppKit keeps the
row's own pressable role for that name) labeled with its title and description,
with the value `selected` when selected; the empty state is a `status`.

| GPUI Kit | ui2 |
| --- | --- |
| `ListDelegate` with `items_count`, `render_item` | `items` or `sections` of `ListItem` values; the application rebuilds them |
| Sections, headers, footers; empty sections hidden | Implemented |
| `ListItem` children, `suffix`, `check_icon`/`confirmed`, `disabled` | `title`, `description`, `icon`, `avatar`, `trailing`, `badge`, `actions`; `check_icon`; `enabled` |
| `ListSeparatorItem` | `list_separator()` |
| `selected_index`, `ListEvent::Select` | `state.active` and `state.selected` |
| `ListEvent::Confirm` (click, Enter, secondary Enter) | `step.confirmed`, `step.secondary` |
| `ListEvent::Cancel` (Escape) | `step.cancelled` |
| `selectable(false)` | `selection: .none` |
| Multiple selection with Cmd/Ctrl and Shift | Implemented (beyond upstream's List); clicks need `ListModifiers` |
| Hover highlight | Implemented with hover events |
| `loading`, `render_loading` | `loading` (placeholder rows); custom loading content is the application's own element |
| `render_empty` | `empty_title`, `empty_description`, `empty_icon` |
| `scroll_to_item`, `scroll_to_selected_item` | `list_reveal_offset` and `scroll_to_offset` |
| Virtualized rows | `virtualize` with `offset` |
| `has_more`, `load_more_threshold`, `load_more` | `list_visible_range(config).near_end(count, threshold)` and `loading` |
| Right-click outline (`secondary_selected`) | A native right-click `menu` per row instead |
| `searchable(true)`, `perform_search` | `searchable_list` (below) |
| `render_initial` | Omitted: pass the rows to show before a search as the items. |
| Drag and drop reordering | Not part of the list, which stays a selection list. Reordering is the separate [reorder container](#reorder-container). |
| `max_h`, `paddings`, `scrollbar_visible`, `scroll_bounce` | The frame; the list's own padding; the backend's scroller and its native bounce. |
| Type-ahead | Not in GPUI Kit's List, so not added. |

## Searchable list

```v
fn pantry_config(m &Model) ui2.SearchableListConfig {
	return ui2.SearchableListConfig{
		id:         'pantry'
		frame:      ui2.rect(808, 196, 360, 340)
		query:      m.query
		sections:   pantry_sections()
		state:      m.pantry
		match_mode: .fuzzy
		offset:     m.pantry_offset
	}
}

// on_event:
field := ui2.searchable_list_field_id('pantry')
if step := ui2.searchable_list_update(pantry_config(m), event, ui2.text(field)) {
	m.query = step.query
	m.pantry = step.state
	if step.confirmed { choose(step.item) }
	// After refresh(): if step.sync_field { set_text(field, step.query); focus(field) }
	// and if step.reveal, scroll to list_reveal_offset (below).
}

// on_key_event (the field keeps focus):
if step := ui2.searchable_list_key(pantry_config(m), event) {
	ui2.consume_key()
	// store it as above
}

// Revealing the highlight:
list_config := ui2.searchable_list_list_config(pantry_config(m))!
if offset := ui2.list_reveal_offset(list_config, m.pantry.active) {
	ui2.scroll_to_offset(ui2.searchable_list_scroll_id('pantry'), offset)
}
```

`searchable_list` puts an `input_group` (search icon, clear button) above a
list of the rows that match its query, with GPUI Kit's empty results state.
Up and Down (wrapping) and Page Up and Page Down move the highlight
(`state.active`) while the field keeps focus; the selection stays where it is,
as in GPUI Kit's Select and Combobox. Enter or Return in the field chooses the
highlighted row, Escape clears the query and then reports `cancelled`. A new
query moves the highlight to the first result, as upstream. In `.single` mode a
click chooses a row and confirms it; in `.multiple` mode a click, Enter or
Return toggles the row without confirming, as Combobox's multi-select does.
Home, End, Space and Cmd/Ctrl+A stay with the field.

`SearchableListConfig`: `id`, `frame`, `query`, `placeholder`, `items` or
`sections`, `state`, `selection`, `match_mode`, `filter` (off when the
application searches itself and passes the results), `check_icon` (on),
`loading`, `empty_title`, `empty_description` (defaults to naming the query),
`offset`, `virtualize`, `overscan`, `accessibility_label`, `size`, `theme`.

| Function | Purpose |
| --- | --- |
| `searchable_list(config) !Element` | The component. |
| `searchable_list_update(config, event, field_text) ?SearchableListStep` | Field edits (pass `text(searchable_list_field_id(id))`), Return, the clear button, and row presses and hovers. |
| `searchable_list_key(config, event) ?SearchableListStep` | The keys above. |
| `searchable_list_query_state(config, query) ListState` | The state after a programmatic query change. |
| `searchable_list_results(config) ![]ListSection`, `searchable_list_list_config(config) !ListConfig` | What the list shows, and its `ListConfig` for `list_reveal_offset` and `list_visible_range`. |
| `searchable_list_field_id(id)`, `searchable_list_list_id(id)`, `searchable_list_scroll_id(id)` | Element ids. |
| `list_match(query, text, mode) ?ListMatch` | Matches one text: `score`, and the matched rune `ranges`. |
| `list_item_matches(item, query, mode)`, `list_filter(sections, query, mode)` | Filtering. |

`SearchableListStep`: `query`, `state`, `confirmed`, `secondary`,
`cancelled`, `item`, `action`, `reveal`, `sync_field` (the query changed other
than by typing: put it back into the field and focus it).

**Matching.** `.substring` is GPUI Kit's match: the query, ignoring case and
surrounding spaces, anywhere in the row's title (or, in ui2, its description).
`.fuzzy` takes the query as one run where it can and otherwise as its characters
in order, so `gtc` matches "GPUI Toolkit Core". Both compare Unicode lowercase
runes. Rows keep their order; `ListMatch.score` ranks earlier matches, matches
at word starts and fewer gaps higher, for applications that sort. A section
whose title contains the query keeps all its rows. Section titles always match
as substrings, since two letters in order would match most of them.

**Keys while the field has focus.** The custom renderer offers every key to
`on_key_event` first. AppKit offers the arrows and the other function keys
(see `docs/gpui-kit/inputs.md`), but not Return or Escape: Return arrives as the
field's submit action, which `searchable_list_update` handles, and Escape does
not arrive, so on AppKit the clear button clears the query.

| GPUI Kit | ui2 |
| --- | --- |
| Search input with search icon and clear button | `input_group` with an icon addon and `clearable` |
| `SearchableVec`, `SearchableGroup` | `items` or `sections` with `filter` |
| `SearchableListItem::matches` (case-insensitive substring of the title) | `.substring`, also matching the description; `.fuzzy` added |
| A group whose title matches stays | It stays with all its rows (upstream keeps only matching rows, which leaves the group empty and hidden) |
| `perform_search` (custom or asynchronous search) | `filter: false`, with `loading` while the application fetches |
| Highlight moves with the arrows; Enter confirms; Escape cancels | Implemented; Escape first clears a non-empty query |
| New query highlights the first row | Implemented |
| Multi-select toggling, check icon | `selection: .multiple`, `check_icon` |
| Disabled items | `enabled: false` |
| Empty state | Implemented, naming the query |
| Match highlighting | Not in GPUI Kit; `ListMatch.ranges` reports the matched runes, but rows are not highlighted, since a ui2 label has one style. |
| Footer action slot, custom trigger, `Select`/`Combobox` popups | Outside this group: put a `searchable_list` in a `popover` and a button below it. |

## Reorder container

`reorder_container` lays its items out along one axis and lets the user move
them: drag an item to a new place, or select it and press Alt (Option on macOS)
with the arrow keys along that axis. Queues, playlists and other ordered lists
are the typical use. Items are ordinary elements the application builds, so any
content can be an item, and each item's `key` keeps its native state as the item
moves.

```v
// build:
ui2.reorder_container(queue_config(m))!

fn queue_config(m &Model) ui2.ReorderConfig {
	return ui2.ReorderConfig{
		id:      'queue'
		frame:   ui2.rect(24, 84, 512, 300)
		items:   m.jobs.map(job_card) // each card has a key unique among the cards
		state:   m.queue
		gap:     8
		padding: 4
		offset:  m.queue_offset
	}
}

// on_event (presses, drags and releases on the items):
if step := ui2.reorder_update(queue_config(m), event) {
	m.queue = step.state
	if step.moved {
		m.jobs = ui2.reorder_move(m.jobs, step.from, step.to)
	}
	if step.clicked.len > 0 {
		select_job(step.clicked)
	}
}

// on_key_event (acts on the cursor item, `state.active`):
if step := ui2.reorder_key(queue_config(m), event) {
	ui2.consume_key()
	m.queue = step.state
	m.jobs = ui2.reorder_move(m.jobs, step.from, step.to)
	// After the rebuild, when step.reveal is set, scroll the item into view.
	if offset := ui2.reorder_reveal_offset(queue_config(m), step.state.active) {
		ui2.scroll_to_offset(ui2.reorder_scroll_id('queue'), offset)
	}
}

// on_scroll:
if id == ui2.reorder_scroll_id('queue') {
	m.queue_offset = ui2.scroll_offset(id)
}
```

| `ReorderConfig` | Meaning |
| --- | --- |
| `axis` | `.vertical` (default) or `.horizontal`. |
| `items` | The elements in order. An item's length is its frame's height (its width on a horizontal axis), and the container stretches it across. Hidden items are rejected: leave them out of the list instead. |
| `state` | `ReorderState{active, drag}`: the keyboard cursor and the drag in progress. |
| `gap`, `padding` | The space between items, and the space kept from each end. |
| `offset` | The scroll position along the axis, which `reorder_reveal_offset` starts from. |
| `handle` | Only a grip at the leading edge drags. See below. |
| `size`, `theme`, `accessibility_label` | The grip's size and colors, and the container's accessible name. |

**Dragging.** Past 4 points, a press becomes a drag. The item follows the
pointer, floating above the others on a shadow, and the items it passes move
aside into the place it left. Released, `reorder_update` reports `moved` with
`from` and `to`, where `to` is the item's index after the move. Released where it
was pressed, it reports `clicked`, and the item becomes the cursor. A drag does
not scroll the list, so scroll an item closer before moving it far.

**Keys.** Alt with the arrows along the axis moves the cursor's item one place,
and Alt with Home or End moves it to the first or last place it may take. Each
move reports `reveal`. Other keys are left alone.

**Disabled items** (`enabled: false`) keep their places. They cannot be dragged
or moved with the keys, and the others cannot be moved past them. That suits an
item already printing at the head of a queue.

**Presses inside an item.** By default the whole item is the press, but a button
or other interactive child keeps its own presses, so a Remove button can sit in
each row. An item that is itself a button or a clickable view needs
`handle: true`: a grip, a column of dots at the leading edge, is then the only
press that drags. The item is narrower by the grip, so lay its content out with
that in mind.

**Scrolling and accessibility.** Items longer than the frame scroll in
`reorder_scroll_id(id)`, and the items keep clear of the scroller. The container
is a `list` and each item a `listitem`.

| Function | Purpose |
| --- | --- |
| `reorder_container(config) !Element` | The container. |
| `reorder_update(config, event) ?ReorderStep` | Presses, drags and releases on the items. |
| `reorder_key(config, event) ?ReorderStep` | The keys above. |
| `reorder_move[T](items, from, to) []T` | Applies a `moved` step to the application's own array. |
| `reorder_reveal_offset(config, key) ?f64` | The scroll offset that shows an item, scrolling as little as it can from `config.offset`; none when the items fit. |
| `reorder_layout(config) !ReorderLayout` | Where the items go: `items`, `length` and `scrolls`. |
| `reorder_item_action(id, key)`, `reorder_scroll_id(id)` | The action and element ids. |

```sh
v test ui/component_reorder_test.v
v -d ui2_custom_rendering test ui/component_reorder_test.v
v test examples/reorder_queue/
v run examples/reorder_queue/main.v
```

## Verification

```sh
v test ui/component_lists_test.v
v -d ui2_custom_rendering test ui/component_lists_test.v
v run examples/gpui_lists/main.v
v -d ui2_custom_rendering run examples/gpui_lists/main.v
```

The gallery opens its virtual list at row 5,000; started with the scroll set
elsewhere, it rebuilds at the new rows on AppKit and in the custom renderer,
which checks the `on_scroll` → `scroll_offset` → `request_refresh` loop.
