# Message scroller

A port of GPUI Kit's
[MessageScroller](https://github.com/longbridge/gpui-kit/blob/main/website/component/message-scroller.md):
a virtual list for a conversation that follows the latest row while the reader
is at the bottom, keeps the reader's place when history goes in above them,
counts the rows that arrive while they read further up, and offers a way back.

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `MessageScrollerState` | `MessageScrollerState`, `message_scroller_state`, `MessageScrollerStart` | `ui/component_messages.v` |
| `MessageScroller` | `message_scroller(MessageScrollerConfig) !Element`, `message_scroller_scroll`, `message_scroller_update` | `ui/component_messages_view.v` |

Tests are in `ui/component_messages_test.v`. `examples/gpui_messages/main.v` is
a chat channel of 3,000 messages of different heights (wrapped text, code
blocks, file cards, day separators, an unread marker) that opens at the first
unread message, with buttons to append a message, stream a reply into the last
row word by word (an `after` timer), load 50 earlier messages, jump to the
first unread, the oldest or the latest message, a "N new messages" pill while
the reader is away from the tail, a composer, and a light/dark toggle.
Scrolling near the top loads earlier history by itself, and resizing the window
reflows every row.

```sh
v run examples/gpui_messages/main.v
v -d ui2_custom_rendering run examples/gpui_messages/main.v
```

## How it works

- **The application owns the rows.** It keeps the messages, works out each
  row's height (ui2 has no measuring layout pass, so heights come from the
  application, as for `virtual_list_sized`) and builds a `VirtualListLayout`
  with `message_scroller_layout(heights, gap, padding)`. Every change to the rows
  goes through the state as the new layout (`append`, `prepend`, `splice`,
  `remeasure_rows`, `remeasure`, `reset`), so the state can tell where the
  reader was and work out where they should be.
- **The state is a value.** `MessageScrollerState` holds the layout, the
  viewport height, the offset it is built for, whether it follows the tail, the
  first unread row and a serial. Its methods return the next state; store it.
- **Scrolls are requests.** A change that moves the reader (an append while
  following, a prepend, a jump) takes a new serial and marks a scroll pending.
  After every change pass `take_scroll_request(id)` to `scroll_to_offset`. The
  serial names the Scroll element (`message_scroller_scroll_id(id, state)`), so
  the request is for an element the backend has not laid out yet: it holds the
  request and carries it out when it lays that element out with its new
  content, instead of clamping it to the old content's end. The element keeps
  its reconciliation key, so the native scroll view and its rows stay.
- **Reports are reader moves.** Pass `on_scroll` reports to
  `message_scroller_scroll(config, id, scroll_offset(id))`. It ignores other
  Scroll elements and stale serials, applies the follow-tail and unread rules,
  and says whether the scroller needs a rebuild (other rows, the jump control or
  its count) and whether to load earlier history. Ask for the rebuild with
  `request_refresh()`: a scroll can be reported in the middle of a rebuild.
- **The root is keyed by its id**, so siblings the application adds or removes
  before the scroller do not give it a new native scroll view (and lose the
  reader's place).

```v
struct App {
mut:
	messages []Message
	heights  []f64
	feed     ui2.MessageScrollerState
}

fn (a &App) layout() ui2.VirtualListLayout {
	return ui2.message_scroller_layout(a.heights, 0, 8) or { panic(err) }
}

fn (a &App) config() ui2.MessageScrollerConfig {
	return ui2.MessageScrollerConfig{
		id:    'feed'
		frame: ui2.rect(0, 60, 600, 500)
		state: a.feed
		item:  fn [a] (index int, frame ui2.Rect) ui2.Element {
			return ui2.Element{
				...message_row(a.messages[index], frame)
				key: 'm${a.messages[index].id}' // Keeps a row's view when history goes in above it.
			}
		}
		bottom_fade: true
	}
}

// Once, with the rows loaded: open at the latest row (or .top, or .row).
a.feed = ui2.message_scroller_state(a.layout(), 500, ui2.MessageScrollerStart{})

// After every change to a.feed, wherever it is made:
fn (mut a App) flush() {
	if request := a.feed.take_scroll_request('feed') {
		ui2.scroll_to_offset(request.id, request.offset)
	}
}

// A new message, or a streamed one growing:
a.messages << m
a.heights << height_of(m)
a.feed = a.feed.append(a.layout())!
a.heights[last] = height_of(a.messages[last])
a.feed = a.feed.remeasure_rows(last, last + 1, a.layout())!

// Earlier history:
a.feed = a.feed.prepend(a.layout())! // after putting the rows and heights in front

// on_scroll:
fn on_scroll(id string) {
	step := ui2.message_scroller_scroll(app.config(), id, ui2.scroll_offset(id)) or { return }
	app.feed = step.state
	if step.load_earlier { start_loading_history() }
	if step.rebuild { ui2.request_refresh() }
}

// on_event: the jump control.
if next := ui2.message_scroller_update(app.config(), event) {
	app.feed = next
}
```

## State

| Function or method | Purpose |
| --- | --- |
| `message_scroller_layout(heights, gap, padding) !VirtualListLayout` | Rows of the given heights, `gap` apart, with `padding` above the first and below the last (GPUI Kit's row `pb_8` and list `py_2`). |
| `message_scroller_state(layout, viewport, start) MessageScrollerState` | A scroller over `layout` in a viewport of that height, at `start`: `MessageScrollerStart{position: .latest}` (default, following), `.top`, or `.row` with `row` and `align` (`.start`, `.center`, `.end`, `.nearest`). `first_unread` marks the rows from it on unread; those shown at the start count as read. |
| `state.reset(layout, start)` | A new conversation: replaces every row and goes to `start`, keeping no anchor. |
| `state.splice(start, removed, layout) !` | Replace `removed` rows at `start`; `layout` is the whole new list. Following the tail, the bottom stays in view; otherwise the row at the top of the viewport stays where it is on screen. A removed top row hands over to the row that took its place. Fails for a range outside the list or a layout short of the kept rows. |
| `state.append(layout) !`, `state.prepend(layout) !` | `splice` at the end and at the start. Rows appended while the reader is away from the tail become unread. |
| `state.remeasure_rows(start, end, layout) !` | New heights for rows in `[start, end)`, such as a streamed message: the top row keeps its place and the offset into it (GPUI's item anchor), so growth below the reader moves nothing. |
| `state.remeasure(layout) !` | New heights for every row, after a width or font change: the top row stays at the top, the same fraction of the way into it (GPUI's proportional anchor). |
| `state.resize(viewport)` | The scroller's new height: following, the bottom stays in view; otherwise the top row does. |
| `state.scroll_to_row(index, align) ?` | Go to any row (unread boundary, search hit, reply target): none for an index outside the list. Reaching the bottom resumes following. |
| `state.scroll_to_end()` | The latest row; following again, every row read. |
| `state.scrolled(offset)` | A backend report (what `message_scroller_scroll` uses). |
| `state.mark_unread(index)`, `state.mark_read()` | Set or clear the unread boundary. |
| `state.take_scroll_request(id) ?MessageScrollerScroll` | The scroll asked for, once: `scroll_to_offset(request.id, request.offset)`. `pending_scroll()` tells whether there is one. |
| `state.following`, `is_scrolled_up()`, `at_end()` | Upstream's `is_following_tail`, `is_scrolled_up` (content below, not following, not at the end) and its end test. |
| `state.unread()`, `state.first_unread` | Rows from the first unread to the end, and that row (-1 for none). |
| `state.anchor() MessageScrollerAnchor` | The row at the top of the viewport and how far into it the viewport starts (upstream's `logical_scroll_top`). |
| `state.item_count()`, `range(overscan)`, `end_offset()`, `near_start(threshold)` | Row count, rows to build, the bottom offset (the backends' 16-point bottom room included), and the load-earlier test. |

The zero value is an empty scroller that follows the tail.

## Rules

The decisions are small public functions, tested on their own:

| Function | Rule |
| --- | --- |
| `message_scroller_anchor(layout, offset)` | The anchor at an offset: the first row ending below it (the next row in a gap, negative `offset` in a gap or padding before it). |
| `message_scroller_anchor_offset(layout, anchor)` | The offset that puts an anchor back at the top in a changed layout, kept within a row that shrank. |
| `message_scroller_scaled_anchor(anchor, old_size, new_size)` | The proportional anchor for a reflowed row. |
| `message_scroller_spliced_row(index, start, removed, inserted)` | Where a row index goes across a splice. |
| `message_scroller_follows(following, previous, offset, bottom)` | Follow-tail: at the bottom (2 points of tolerance) follow; a move up stops following; anything else keeps it. Only the reader moves the scroller up, so a move up is the reader leaving. |
| `message_scroller_read_up_to(first_unread, count, seen_end)` | Unread as a high-water mark: rows ending above the viewport's bottom edge are read, and rows scrolled past stay read. |
| `message_scroller_unread_after_splice(first_unread, count, start, removed, inserted, following)` | The boundary across a splice; rows appended while not following start the unread run. |

## Component

`MessageScrollerConfig`:

| Field | Default | Purpose |
| --- | --- | --- |
| `id`, `frame`, `state` | required | The Scroll element inside is `message_scroller_scroll_id(id, state)`. |
| `item` | required | `fn (index int, frame Rect) Element` for the rows in range; `frame` is the row's place, inset from the sides. Give rows a key naming the message. |
| `overscan` | 4 | Rows built past each edge. |
| `inset` | 12 | Space left and right of the rows (upstream's list `px_3`). |
| `load_earlier_threshold` | 3 | How near the first row the visible rows come before `load_earlier` is reported; -1 never. |
| `jump_button` | true | The jump control while `is_scrolled_up()`. |
| `jump_label` | `Jump to latest` | Its tooltip and accessible name. |
| `jump_to_unread` | false | Go to the first unread row first, then to the end. |
| `unread_text` | `N new messages` | Words the unread count (localization); `message_scroller_unread_text` is the default. |
| `jump_background`, `jump_foreground`, `jump_border` | theme | The control's colors: background, foreground and border, or primary with unread rows. |
| `jump_render` | none | `fn (MessageScrollerJump) Element` draws the control instead; keep `jump.action` as its action. It gets the default control, its frame, the unread count and texts. |
| `bottom_fade`, `fade_color` | off, the background | Fade the rows into a color at the bottom edge while the reader is away from the tail, clear of the scrollbar. |
| `background`, `transparent` | theme background, false | The scroller's fill, or none. |
| `empty_title`, `empty_description`, `empty_icon` | `No messages yet`, none, `text.bubble` | The empty state, shown when there are no rows. |
| `accessibility_label` | `Messages` | The log's name. |
| `size`, `theme` | `.medium`, light | Metrics and colors. |

The default control is a round arrow button, or a pill with the arrow and the
unread count in the primary color while rows are unread, centered 16 points
above the bottom edge. `message_scroller_jump_action(id)` is its action.

Accessibility: the rows' Scroll element has role `log` with the
`accessibility_label` and the unread count as its value; the jump control is a
button named `Jump to latest, N new messages`; the empty state is a `status`.
AppKit has no mapping for `log` and keeps the native scroll role (see below).

## Upstream features

| GPUI Kit | ui2 |
| --- | --- |
| `MessageScrollerState::new(count)`, follow mode on | `message_scroller_state(layout, viewport, start)`, `.latest` by default |
| Starting position via `reset` + `scroll_to_item` | `MessageScrollerStart` (`.latest`, `.top`, `.row` with `align`), and `first_unread` |
| Indexed row renderer, overdraw | `item`, `overscan` |
| `append`, `prepend`, `splice`, `reset` | The same, taking the new layout instead of a count |
| `remeasure_items` (item anchor), `remeasure` (proportional anchor) | `remeasure_rows`, `remeasure` |
| `is_following_tail`, `is_scrolled_up`, `item_count`, `logical_scroll_top` | `following`, `is_scrolled_up()`, `item_count()`, `anchor()` |
| `scroll_to_item`, `scroll_to_end` | `scroll_to_row(index, align)`, `scroll_to_end()` |
| Normal scrolling to the end resumes following | `message_scroller_follows` |
| Built-in jump button, `jump_button(false)`, `with_jump_button_label` | `jump_button`, `jump_label` |
| `with_jump_button_style`, `with_jump_button_renderer` | `jump_background`/`jump_foreground`/`jump_border`, `jump_render` |
| Unread count, "new messages" copy | Added: upstream leaves it to the application; here `first_unread`, `unread()`, `mark_unread`, the counted pill, `unread_text` and `jump_to_unread` |
| Empty state | Added as `empty_*`: upstream leaves it to the surrounding view, which still can (draw something else when `item_count()` is 0) |
| Load earlier | `load_earlier_threshold` and `MessageScrollerStep.load_earlier`, like the virtual list's `near_end` |
| `with_bottom_fade(color)` | `bottom_fade`, `fade_color` |
| Root `Styled`, `with_content_style` | `frame`, `background`, `transparent`; the viewport is the root's frame |
| `with_list_style` (padding), `with_row_style` (`pb_8` gap) | `message_scroller_layout`'s `padding` and `gap`, and `inset` |
| `Role::Log` | `accessibility_role: 'log'` |
| `with_jump_button_transition`, reduced motion | Omitted: the control appears and goes with the rebuild. A fade would need the component to start animations, which only the application can (`animation(...).start(id)`). |
| `scrollbar(false)` | Omitted: a Scroll element always has the backend's own scroller, with no switch to hide it. |
| Rows measured by the list | Not possible: heights come from the application, which re-anchors by passing new ones to `remeasure_rows`/`remeasure`. |
| Wheel chaining to an ancestor at the edges | The backends' own behavior. |

## Platform notes

- Win32 leaves no room below a Scroll element's content, where AppKit, UIKit
  and the custom renderer leave 16 points. The scroller copes (the backend
  clamps the extra).

## Verification

```sh
v test ui/component_messages_test.v
v -d ui2_custom_rendering test ui/component_messages_test.v
```

The example was also driven by a scripted probe on AppKit and in the custom
renderer: `after` timers press the jump control, append, stream, scroll up with
`scroll_to_offset` (which the backends report through `on_scroll`), prepend,
jump to the top so the threshold loads history, and resize the window both
while following and while away. After each step it compares `scroll_offset` of
the current Scroll element with the state (bottom, anchored row and offset into
it, unchanged position while a row grows below the reader) and checks that the
last build built the rows in view at the backend's position.
