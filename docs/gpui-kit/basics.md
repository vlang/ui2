# Basics: image, label, textarea, tooltip, scrollable

This group audits ui2's existing basics against GPUI Kit's
[Image](https://github.com/longbridge/gpui-kit/blob/main/website/component/image.md),
[Label](https://github.com/longbridge/gpui-kit/blob/main/website/component/label.md),
[Textarea](https://github.com/longbridge/gpui-kit/blob/main/website/component/textarea.md),
[Tooltip](https://github.com/longbridge/gpui-kit/blob/main/website/component/tooltip.md) and
[Scrollable](https://github.com/longbridge/gpui-kit/blob/main/website/component/scrollable.md)
pages, and closes the gaps with components layered on top of them. The
existing elements (`image`, `label`, `text_area`, `with_tooltip`, `scroll`,
`scroll_with_mode`, `scroll_persistent`) are unchanged.

| GPUI Kit | ui2 element (kept) | New component | Source |
| --- | --- | --- | --- |
| `img()`, `ObjectFit`, `with_loading`, `with_fallback` | `image` | `image_box(ImageBoxConfig)`, `ImageFit`, `image_fit_rect`, `image_natural_size` | `ui/component_basics_image.v` |
| `Label`, `HighlightsMatch` | `label` | `styled_label(StyledLabelConfig)`, `LabelMatch`, `label_highlight_ranges` | `ui/component_basics_label.v` |
| `Textarea`, `TextareaState` | `text_area` | `textarea(TextareaConfig)`, `textarea_limit`, `textarea_height` | `ui/component_basics_textarea.v` |
| `Tooltip`, `TooltipDefaults`, managed tooltips | `with_tooltip` | `tooltip_popup(TooltipPopupConfig)`, `TooltipGroup`, `tooltip_trigger`, `tooltip_step` | `ui/component_basics_tooltip.v` |
| `Scrollable`, `overflow_*_scrollbar`, `Scrollbar`, `ScrollbarMode` | `scroll`, `scroll_with_mode` | `scrollable(ScrollableConfig)`, `ScrollMetrics`, `scrollbar(ScrollbarConfig)`, `scroll_key_offset` | `ui/component_basics_scroll.v` |

Shared helpers live in `ui/component_basics.v`, the tests in
`ui/component_basics_test.v`, and `examples/gpui_basics/main.v` shows every
component with a light/dark switch:

```sh
v run examples/gpui_basics/main.v
v -d ui2_custom_rendering run examples/gpui_basics/main.v
```

The image and tooltip builders are named `image_box` and `tooltip_popup` rather
than `image_view` and `tooltip`: AppKit's backend has local variables of those
names, which functions called that would shadow.

All components follow the catalog's conventions: a `XConfig` struct, a builder
returning `!Element`, parent-local child frames, part ids under
`${id}:component:`, and controlled state the application keeps and rebuilds
from.

## Image: `image_box`

```v
ui2.image_box(
	id:            'cover'
	frame:         ui2.rect(20, 20, 320, 180)
	path:          'images/cover.png'
	alt:           'The album cover'
	fit:           .cover
	radius:        8
	loading:       app.cover_loading
	fallback_text: 'Image unavailable'
	theme:         theme
)!
```

- **Object fit.** `ImageFit` is `contain` (the default, as upstream), `cover`,
  `fill`, `scale_down` and `none`. `position_x` and `position_y` (0 to 1, CSS
  `object-position`) place the image in spare room and choose the part a crop
  keeps. `image_fit_rect(fit, w, h, natural_w, natural_h, px, py)` is the pure
  geometry.
- **Natural size.** Fit needs the image's own size. `natural_width` and
  `natural_height` take it from the application; otherwise
  `image_natural_size(path)` reads it from the header of a PNG, JPEG, GIF, BMP
  or WebP file (JPEG EXIF orientation is not applied). It reads the header on
  every build, which is cheap for one image; for a grid, read each size once and
  pass it in. `symbol:` icons count as square. An unknown size draws the image
  over the whole frame, as `image` does.
- **Why it computes the rectangle itself.** Left to themselves the backends
  disagree: AppKit keeps an image's aspect ratio inside its frame, the custom
  renderer stretches it to the frame. `image_box` gives the backend a frame of
  exactly the image's shape, so contain, cover, scale_down and none look the
  same everywhere.
- **Cropping.** ui2 views do not clip, so an image that reaches past the frame
  (cover, or none on a large image) sits in an id-less Scroll element whose one
  child ends at its right edge and is no taller than what it hides: it clips,
  with nothing to scroll (the trick `data_table` uses for its header).
- **Rounded and circular corners.** `radius`, or `circle` for a fully rounded
  shorter side, paint the corners over with `backdrop` (the theme's background by
  default) in an even-odd shape: the custom renderer does not clip children to
  rounded corners. Give `backdrop` the surface color when the image sits on a
  card.
- **Border, letterbox fill, tint.** `bordered` strokes the frame in the theme's
  border color; `background` fills the room a contained image leaves; `tint`
  colors a `symbol:` icon.
- **Loading.** `loading: true` shows a shimmer (or, without an id or with
  `reduce_motion`, a still muted fill) in the image's box, with an optional
  `loading_text`. Call `image_box_stop_loading(id)` when the image arrives: like
  every feedback loop, the sweep keeps the window redrawing otherwise.
- **Fallback.** `failed: true`, a missing file or an unknown symbol shows a muted
  box with `fallback_icon` (`photo` by default) and `fallback_text`; with no icon
  the text alone, large, such as initials. `image_box_status(config)` reports
  which of the three an image_box shows.
- **Gallery thumbnails.** With `action` the image_box is a button
  (`with_button_behavior`, pointing-hand cursor) and `selected` rings it in the
  primary color, upstream's "gallery with selection".
- **Accessibility.** `alt` is the image's description and its role `img`; an
  image without one is `presentation`. A thumbnail is a `button` whose label is
  `alt` and whose value is `selected`. The loading and fallback texts replace
  `alt` while they show.

## Label: `styled_label`

```v
ui2.styled_label(
	frame:     ui2.rect(20, 20, 300, 24)
	text:      'Company Name'
	secondary: '(optional)'
	highlight: search
	theme:     theme
)!
```

- `secondary` follows the text after a space in the muted color
  (`secondary_color` overrides it: a red `*` for a required field).
- `highlight` marks every case-insensitive match (overlapping ones too, as
  upstream) in the primary color, or only a match at the very start with
  `highlight_match: .prefix`. Matches may run from the text into the secondary
  text. `highlight_background` also lays a soft mark behind each match.
  `label_highlight_ranges(text, query, mode)` returns the ranges in runes;
  case folding is Unicode-aware (`rune.to_lower`).
- `masked` shows a bullet per character (text and secondary text, as upstream),
  shows no highlights, and reads `masked_label` ("Hidden") to assistive
  technology instead of the value.
- `align` (left, center, right), `valign`, `wrap` (on by default, at the frame's
  width), `max_lines` (zero: as many as the frame's height holds; the last one
  shown ends in an ellipsis), `line_height` (zero: 1.45 times the font size),
  `color`, `font_size` (zero: the size's), `bold`, `italic` and `font_family`.
- `styled_label_size(config)` is the widest line and the height of the lines,
  wrapped at `frame.width`, for laying the label out.

A ui2 label has a single style, so the text is cut into runs (main text,
secondary text, each match) along the lines it wraps onto, and each run is a
label of its own, placed after the previous one with `measure_text_width`. The
two points AppKit text fields keep on each side of their text are allowed for,
so the runs read as one line on every renderer. The match and color changes
must not change the font, so highlights change the color only.

## Textarea: `textarea`

```v
ui2.textarea(
	id:          'message'
	frame:       ui2.rect(20, 20, 360, 0) // the height follows the text
	text:        app.message
	min_rows:    2
	max_rows:    6
	max_length:  200
	placeholder: 'Write a message'
	theme:       theme
)!

// in the event handler, for the text area's change event `message`:
app.message = ui2.textarea_limit(ui2.text('message'), 200)
```

- **Rows.** `rows` gives a fixed height; `max_rows` above zero turns on
  auto-grow from `min_rows` to `max_rows` lines (upstream's `auto_grow(2, 8)`),
  after which the native text area scrolls. With neither, `frame.height` is the
  box. `textarea_rows`, `textarea_line_count`, `textarea_box_height` and
  `textarea_height` (the counter included) are the pure layout, so the
  application can place what follows. Line counts come from
  `wrap_text_to_width` at the text area's own wrap width.
- **Placeholder** while the text is empty, drawn behind a clear text area
  (AppKit) or over the custom renderer's, which paints its own box.
- **Counter and maximum length.** `max_length` shows `12 / 200` below the box and
  turns the counter and border to the danger color past it; `show_count` shows a
  count without a limit. Components cannot intercept typing, so the application
  applies `textarea_limit(text, max)` to what it stores; the text area then shows
  the cut text.
- **Sizes** change the font and padding together (small, medium, large), as
  upstream; **`bordered`**, **`enabled`** (disabled dims the text and fills the
  box with the muted color), **`readonly`** (selectable, copyable, unchanged
  look), **`invalid`** (danger border) and `label` for assistive technology.
- The text area is the native one (`NSTextView` on AppKit), so wrapping,
  selection, clipboard, undo and scrolling are the platform's. Its id is the
  config's id: `ui2.text(id)`, `focus(id)` and change events work unchanged.

## Tooltip: `tooltip_popup`, `TooltipGroup`, `tooltip_trigger`

```v
// The state, kept by the application; the triggers share one group.
tips ui2.TooltipGroup

// Build: wrap each trigger, and add the tooltips last, over everything.
ui2.tooltip_trigger('tips', 'save', -1, save_button)!
...
ui2.tooltip_popup(
	id:       'tip:save'
	open:     app.tips.shows('save')
	anchor:   save_frame // window coordinates
	window:   ui2.bounds()
	text:     'Save file'
	shortcut: 'cmd+s' // ⌘S on macOS, Ctrl+S elsewhere
	theme:    theme
)!

// Events: feed pointer events in, run the timers the step asks for.
if step := ui2.tooltip_step('tips', app.tips, event) {
	app.tips = step.state
	if step.cancel { ui2.cancel_timer(app.tips_timer) }
	if step.schedule {
		generation := step.state.generation
		app.tips_timer = ui2.after(step.delay, fn [generation] () {
			// feed app.tips.timer_fired(generation) back the same way
		})
	}
}
```

- **Timing**, as upstream's `TooltipDefaults` and `TooltipOverlay`: a tooltip
  opens after the pointer rests on its trigger for `show_delay` (0.5 s), stays for
  `grace_period` (0.3 s) after the pointer leaves, and a trigger entered within
  that period switches at once. `tooltip_trigger`'s `delay` is the per-trigger
  `tooltip_show_delay` (zero opens at once; -1 uses the group's). Pointer sweeps
  that leave before the delay never open anything; stale timer firings are
  ignored by generation, as with `HoverCardState`.
- **Press and Escape.** `state.pressed(key)` (call it from the trigger's own
  action) hides the tooltip until the pointer leaves that trigger, as upstream's
  managed tooltips do; `state.dismissed()` is for Escape.
- **Content.** `text` wraps at `max_width` (280). `shortcut` is a key binding
  written by `menu_shortcut_label`; `keys` shows keys as given. `title`,
  `description` and `icon` (a symbol) make the rich tooltip upstream builds with
  `Tooltip::element`; `children` with `content_width` x `content_height` take
  anything else, under the text.
- **Placement and look.** `side` (bottom by default), `align`, `offset`,
  `margin` and `arrow`, through `popover_place`, so a tooltip flips and shifts to
  stay in the window. The surface is the popover's: background, border, shadow and
  radius from the theme, or a `tone`'s colors (upstream's `.bg(...)` styling).
  `tooltip_popup_size(config)` is its size.
- **Accessibility.** The surface has the `tooltip` role and reads the title, text
  and description.
- `with_tooltip` stays the simple, platform-styled hover text. Touch platforms
  have no hover, so triggers never fire there, which is upstream's mobile policy.

## Scrollable: `scrollable`, `ScrollMetrics`, `scrollbar`

```v
ui2.scrollable(
	id:        'files'
	frame:     ui2.rect(20, 20, 240, 300)
	axis:      .vertical_only // .horizontal_only, .both
	stack:     .column        // .row, .none
	padding:   6
	gap:       2
	bordered:  true
	scrollbar: .always
	children:  rows
	theme:     theme
)!

// on_scroll(id): id == ui2.scrollable_scroll_id('files')
m := ui2.scroll_metrics(ui2.scroll_offset(id), content_height, viewport_height)
ui2.scroll_to_offset(id, m.reveal(row_y, row_h, .center))
```

- **`scrollable`** wraps `scroll_with_mode`: `axis` picks the axes, `stack`
  lays the children out in a column or a row by their sizes (a child without a
  width, or height, spans the pane), `padding` insets the content on every side
  and is carried into the scroll range, `gap` separates stacked children, and
  `bordered` draws the pane in a rounded border. `scrollbar: .always` keeps the
  platform's scroller on screen (`scroll_persistent`); `.scrolling` and `.hover`
  use the overlay scroller, which AppKit shows while scrolling.
  `scrollable_scroll_id(id)` is the Scroll element's id for `scroll_offset`,
  `scroll_to_offset` and `on_scroll`; `scrollable_viewport` and
  `scrollable_content_size` give the extents.
- **`ScrollMetrics`** (from `scroll_metrics(offset, content, viewport)`) decodes a
  position: `max_offset`, `clamp`, `scrolls`, `at_start`, `at_end`, `progress`,
  `visible_fraction`; and computes scroll-to targets: `reveal(start, size,
  align)` (start, center, end or nearest, upstream's `ScrollStrategy`), `page(n)`,
  and `follow(new_content)`, which stays at the end of a growing chat when the
  pane was showing it (upstream's auto-scroll example).
- **`scroll_key_offset(m, event, line, horizontal)`** maps the arrow keys, Page
  Up/Down, Space and Shift+Space, Home/End and Command+arrows to an offset, for an
  application to call from `on_key_event` while a pane has the keyboard.
- **`scrollbar`** is a themed scrollbar of the application's own, upstream's
  manual `Scrollbar`: a track and a thumb for an offset, content length and
  viewport, either orientation. Its `mode` is upstream's `ScrollbarMode`:
  `.always`, `.hover` (shown while `active`, which the application sets from
  `with_hover` on the scroll area) and `.scrolling` (shown while `active`, set on
  each scroll and cleared with a timer). Hovering the bar widens the thumb;
  `scrollbar_step(config, drag, event)` turns thumb drags (`draggable_view`),
  clicks on the track before or after the thumb (a page back or on) and the bar's
  hover into the offset to scroll to and the new drag state. Keep it in step
  with a pane through `on_scroll` and `scroll_to_offset`, or use it for content
  the application positions itself.

## Implemented, already present, omitted

### Image

| Upstream | Status |
| --- | --- |
| Sources: file paths | Already present (`image`); `symbol:` icons too |
| Sources: asset keys, URLs, encoded bytes, custom loaders | Omitted: ui2 loads files; an application that downloads shows `loading` until the file is written |
| `ObjectFit` contain, cover, scale_down, none | Implemented, the same on every renderer |
| `ObjectFit::Fill` | Implemented; AppKit keeps the aspect ratio (see backend notes) |
| `aspect_ratio` and reserving the box | Implemented through fixed frames and `image_fit_rect`/`image_natural_size` |
| `.rounded(...)`, `.rounded_full()` | Implemented (`radius`, `circle`) by painting the corners |
| Borders, backgrounds | Implemented (`bordered`, `background`) |
| `with_loading` (after 200 ms), `with_fallback` | Implemented as `loading` and the fallback; the delay is the application's |
| Gallery with selection | Implemented (`action`, `selected`) |
| `.grayscale(true)` | Omitted: no backend can desaturate an image |
| `svg()` single-color icons | Already present: `symbol:` images and `named_icon` |
| Animated GIF/WebP, image caches, HTTP caching | Omitted: backend image loading |

### Label

| Upstream | Status |
| --- | --- |
| Text, `secondary`, `masked`, `highlights` (full and prefix) | Implemented |
| `HighlightsMatch::as_str`, `is_prefix` | Not needed: `LabelMatch` and the query are plain values |
| Alignment, color, size, weight, line height, wrapping | Implemented |
| Unicode text | Implemented: rune offsets and Unicode case folding |
| Text selection | Omitted: labels are not selectable (see `TextRangeSelection` for painted text) |

### Textarea

| Upstream | Status |
| --- | --- |
| Multi-line editing, wrapping, scrolling, value, change events | Already present (`text_area`) |
| `rows`, `auto_grow(min, max)`, placeholder | Implemented |
| Sizes, `bordered`, `disabled`, `readonly`, `aria_label` | Implemented (`readonly` was already on `Element`) |
| Character counter and maximum length | Implemented (not upstream: the task's request) |
| `h(...)` fixed height | Implemented through `frame.height` |
| `appearance(false)` | Covered by `bordered: false` and the theme's colors |
| Scroll staying in the textarea, scroll bounce | Backend behavior: AppKit's text view does this natively |
| `submit_on_enter` | Omitted: AppKit and Win32 report `text:<id>:enter` to `on_key`, but the custom renderer sends no text commands |
| Atomic inline tokens, custom context menu, paste handler | Omitted: they need editor internals ui2 does not expose |
| `insert`, `replace`, `cursor_position`, searchable | Omitted: imperative editor API beyond `set_text` and the `text_area_selection_*` functions |

### Tooltip

| Upstream | Status |
| --- | --- |
| Text tooltips | Already present (`with_tooltip`, platform-styled); implemented themed (`tooltip_popup`) |
| `Tooltip::element` (custom content) | Implemented: title, description, icon, or `children` |
| `key_binding(Kbd)`, `tooltip_with_action` | Implemented as `shortcut`/`keys`; ui2 has no action registry to look bindings up in |
| Show delay, grace period, switching, per-trigger delay, `TooltipDefaults` | Implemented (`TooltipGroup`, `tooltip_trigger` delay) |
| Press dismisses until leave; Escape | Implemented |
| Placement with flipping | Implemented (`side`, `align`, `arrow`) |
| Styling (`.bg`, `.text_color`) | Implemented as `tone` |
| Showing on keyboard focus | Omitted: components cannot observe focus |
| Enter fade/slide and switch slide animations | Omitted: ui2's opacity is a box fill's only, and an animated position is kept after the animation ends |
| Mobile: disabled | Same outcome: touch platforms report no hover |

### Scrollable

| Upstream | Status |
| --- | --- |
| Vertical, horizontal, both axes | Already present (`scroll_with_mode`); `scrollable` adds stacking, padding, a border |
| `ScrollbarMode` always | Implemented (persistent scroller) |
| `ScrollbarMode` scrolling, hover | Implemented in `scrollbar`; native scrollers: overlay (AppKit shows it while scrolling) |
| Scrollbar colors (theme) | Implemented in `scrollbar` (theme-derived); native scrollers keep the platform's look |
| Manual scrollbar bound to a scroll handle | Implemented (`scrollbar`, `scrollbar_step`) |
| Scroll handle offsets, `max_offset`, `set_offset` | Already present (`scroll_offset`, `scroll_to_offset`, horizontal variants); `ScrollMetrics` decodes them |
| `scroll_to_item` with `ScrollStrategy` | Implemented (`ScrollMetrics.reveal`); `VirtualListLayout.scroll_offset_for` already did it for lists |
| `VirtualList`, variable item sizes | Already present (`virtual_list*`) |
| Chat auto-scroll | Implemented (`ScrollMetrics.follow`); `message_scroller` already does it |
| Scroll bounce, nested-scroll gesture rules | Backend behavior: AppKit bounces natively and nested scrolls hand gestures on |
| `ScrollableMask` edge fades | Omitted: an overlay over a native scroll view would take its wheel events |
| `sync_scrollbar_appearance` | Omitted: ui2 picks the scroller style per element |

## Backend notes

- **Image scaling differs.** AppKit draws `image` with
  `NSImageScaleProportionallyUpOrDown`, the custom renderer stretches to the
  frame; `image_box` hides this for every fit except `fill`, which AppKit draws
  like `contain`.
- `textarea` draws its own border and placeholder over the text area, so it
  looks the same whatever the text area's own frame looks like on a backend.

## Tests

`ui/component_basics_test.v` covers object-fit geometry and positions, header
parsing for PNG, GIF, BMP (top-down), JPEG (skipping segments) and WebP, missing
and malformed files, image states, corner masks, crop clipping and thumbnails;
highlight ranges (upstream's cases: overlap, prefix, Unicode, boundaries), runs
across the secondary text, masking, alignment, wrapping spans and truncation;
textarea limits, counters, rows, auto-grow and both renderer layouts; the
tooltip state machine (delay, grace, switching, sweeps, stale timers, zero
delays, press and Escape), trigger action encoding and forged events, tooltip
layout and placement; scroll metrics, reveal, paging, following and keys;
scrollable stacking and padding; and scrollbar geometry, visibility by mode,
drags, paging and hover.

```sh
v test ui/component_basics_test.v
v -d ui2_custom_rendering test ui/component_basics_test.v
```
