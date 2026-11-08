# Chat components: bubble, message, marker, avatar group

This group ports GPUI Kit's
[Bubble](https://github.com/longbridge/gpui-kit/blob/main/website/component/bubble.md),
[Message](https://github.com/longbridge/gpui-kit/blob/main/website/component/message.md),
[Marker](https://github.com/longbridge/gpui-kit/blob/main/website/component/marker.md) and the
AvatarGroup part of [Avatar](https://github.com/longbridge/gpui-kit/blob/main/website/component/avatar.md)
(`avatar(AvatarConfig)` already existed).

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `Bubble`, `BubbleContent`, `BubbleReactions` | `bubble(BubbleConfig)`, `bubble_layout`, `bubble_height` | `ui/component_chat_bubble.v` |
| `BubbleGroup` | `bubble_group(BubbleGroupConfig)`, `bubble_group_height` | `ui/component_chat_bubble.v` |
| `Message` and its avatar, header, content and footer slots | `chat_message(ChatMessageConfig)`, `chat_message_layout`, `chat_message_height` | `ui/component_chat_message.v` |
| `MessageGroup` | `chat_message_group(ChatMessageGroupConfig)`, `chat_message_group_height` | `ui/component_chat_message.v` |
| `Marker`, `MarkerIcon`, `MarkerContent` | `marker(MarkerConfig)`, `marker_height` | `ui/component_chat_marker.v` |
| `AvatarGroup` | `avatar_group(AvatarGroupConfig)`, `avatar_group_width` | `ui/component_chat_avatar.v` |
| `MessageAlignment` | `MessageAlignment` (`.start`, `.end`) | `ui/component_chat.v` |

Shared helpers (alignment, run positions, text estimates, identity colors and
the surface with tightened corners) are in `ui/component_chat.v`, the tests in
`ui/component_chat_test.v`. `examples/gpui_chat/main.v` is a conversation
between two people with grouped messages, a date divider, a "New messages"
divider, reactions that toggle, a long wrapped message, a file card, a typing
marker that shimmers and a composer that sends, beside a showcase of the bubble
variants, marker styles and avatar groups, with a light/dark toggle:

```sh
v run examples/gpui_chat/main.v
v -d ui2_custom_rendering run examples/gpui_chat/main.v
```

`chat_message` is not called `message` because `message` is a common local
variable name (one is in `ui/component_catalog_test.v`), which a function of
that name would shadow.

## Conventions

- **Rows, not flex layout.** Each builder takes `frame` as the row it lives in:
  `x`, `y` and the width available. The element is as tall as its content (or
  `frame.height` when that is more), and a pure height helper —
  `bubble_height`, `bubble_group_height`, `chat_message_height`,
  `chat_message_group_height`, `marker_height` — returns that height without
  building anything, so a transcript or a virtual list can size and place its
  rows. `bubble_layout` and `chat_message_layout` return every part's frame.
- **Estimated text.** ui/ has no text measurement. Text width is estimated per
  letter (the estimate the dialogs wrap with; emoji count 1.3 em and the
  selectors, joiners and skin tones after them nothing), and wrapping follows
  the same rule labels break lines with. The estimate errs a little wide on
  purpose: a renderer may fit a line more on a row than the estimate, never
  less, so text is never cut off. A bubble centers its text vertically, so a
  line it did not need reads as padding.
- **Controlled state.** The application owns messages, reactions, statuses and
  the open quick-reaction strip; components emit actions and ship decoders
  (`bubble_reaction_from_action`, `chat_message_event_from_action`,
  `chat_message_group_event_from_action`, `marker_action_activated`) that
  reject foreign, malformed, out-of-range, hidden and disabled actions.
- **Identity.** Interactive parts require an `id`; parts use ids under
  `${id}:component:`. A message's bubble is `chat_message_bubble_id(id)`.
- **Runs of one sender.** `chat_group_positions(keys)` turns the author of each
  transcript row into `.single`, `.first`, `.middle` or `.last` (an empty key,
  such as a marker's, never joins a run). Pass the result as `group_position`:
  a run shows its header once, above the first message, its avatar once,
  beside the last, and tightens the bubble corners on the sender's side where
  two bubbles meet. `bubble_group` and `chat_message_group` do this for a run
  they hold.
- **Theme.** Colors come from `ComponentTheme`; nothing is a raw palette value
  except the identity colors below.

## Bubble

```v
config := ui2.BubbleConfig{
	id:           'msg-42'
	frame:        ui2.rect(16, y, row_width, 0)
	text:         'The empty states look great.'
	alignment:    .end
	variant:      .filled
	reactions:    [ui2.BubbleReaction{ emoji: '👍', count: 2, label: 'Thumbs up' }]
	add_reaction: true
	theme:        theme
}
children << ui2.bubble(config)!
y += ui2.bubble_height(config) // where the next row starts
```

| Field | Meaning |
| --- | --- |
| `frame` | The row; the surface is aligned at its start or end |
| `text` | Wraps inside the surface; a single line shrinks the bubble to it, wrapping widens it to its maximum |
| `content`, `content_width`, `content_height` | Application-drawn rich content (a file card, an image) below the text; frames relative to its box |
| `alignment` | `.start` (default) or `.end` |
| `variant` | `.filled` (primary, default), `.secondary`, `.muted`, `.tinted`, `.outline`, `.ghost`, `.destructive` |
| `max_width` | Caps the surface; 0 allows 80% of the row, a ghost bubble all of it |
| `max_lines` | Shows that many lines and ends the last with an ellipsis; `bubble_layout(...).truncated` says whether text was cut, for a "Show more" action |
| `group_position` | Tightens the corners where the bubble meets its neighbors in a run |
| `reactions`, `reaction_side`, `reaction_alignment`, `add_reaction` | Reaction chips hanging from the bottom (default) or top edge, at the end (default) or start |
| `enabled` | False shows reactions without buttons |
| `background`, `text_color`, `border_color`, `surface_color`, `font_size` | Overrides; `surface_color` is what the bubble sits on and rings the reaction region |
| `size`, `theme`, `accessibility_label` | Size preset and colors |

Variant colors follow upstream: filled is `primary`/`primary_foreground`,
secondary is the `muted` fill with the foreground, tinted mixes 12% (24% dark)
of `primary` into the background, outline is the background with the `border`
color, ghost has no surface, padding or radius, and destructive mixes 10% (20%
dark) of `danger` into the background with `danger` text. Muted is a lighter
fill than secondary with the muted text color. ui2 colors are opaque, so
upstream's translucent destructive surface is mixed over the background.

A `BoxStyle` has one corner radius, so a tightened corner is a patch in the
surface color with the small radius laid over the round one; an outline is the
border color with the fill inset over it, patched the same way, so borders
follow the corners on every renderer.

### Reactions

Each `BubbleReaction` is an emoji, a count (shown when above zero), whether
the viewer chose it and an accessible name. The region is a pill in the muted
color ringed with the surface color, overlapping the bubble's edge like
upstream's; a chosen chip is tinted with the primary color and outlined. Chips
emit `bubble_reaction_action_id(id, index)` and the add button
`bubble_add_reaction_action_id(id)`:

```v
if event := ui2.bubble_reaction_from_action(config, action) {
	match event.kind {
		.toggle { m.reactions = ui2.bubble_toggle_reaction(m.reactions, event.emoji) }
		.add { m.picker_open = true } // show the application's emoji choice
	}
}
```

`bubble_toggle_reaction` withdraws the viewer's reaction (dropping the chip
when nobody else chose it) or adds it, appending a new chip if none has the
emoji. Each chip is a `button` with the label "Thumbs up, 2 reactions" and the
value `selected`/`not selected`; the region is a `group` labelled "Reactions".

### `bubble_group`

```v
run := ui2.bubble_group(
	frame:     ui2.rect(16, y, row_width, 0)
	alignment: .start
	bubbles:   [ui2.BubbleConfig{ text: 'First', variant: .secondary },
		ui2.BubbleConfig{ text: 'Second', variant: .secondary }]
	theme:     theme
)!
```

The group sets each bubble's frame, alignment, run position, size and theme.
`joined: false` keeps every corner round and spaces the bubbles 8 apart; `gap`
overrides the spacing (2 when joined).

## Message: `chat_message`

```v
config := ui2.ChatMessageConfig{
	id:             'msg-7'
	frame:          ui2.rect(16, y, row_width, 0)
	author:         'Maya Chen'
	timestamp:      '9:41 AM'
	badges:         ['Design']
	bubble:         ui2.BubbleConfig{ text: 'Can you review this draft?', variant: .secondary }
	status:         .read
	actions:        [ui2.MessageAction{ name: 'reply', label: 'Reply', icon: 'arrow.uturn.backward' },
		ui2.MessageAction{ name: 'copy', icon: 'doc.on.doc', tooltip: 'Copy text' }]
	group_position: positions[index]
	theme:          theme
}
row := ui2.chat_message(config)!
y += ui2.chat_message_height(config)
```

| Part | Fields |
| --- | --- |
| Avatar | `author` (initials, colored by name unless `identity_colors: false`), `avatar_image`, `avatar_size` (24, 32, 40 by size), `show_avatar` (false drops the avatar column) |
| Header | `author` (bold), `badges` (small pills), `timestamp`; shown on the first message of a run when `show_header` |
| Content | `bubble` (drawn when it has text or content; the message sets its id, frame, alignment, run position, size, theme and `enabled`), then `content`/`content_width`/`content_height` below it |
| Footer | `status` (`.sending`, `.sent`, `.delivered`, `.read`, `.failed` with an icon; `status_text` replaces `message_status_text`), `footer_text`, `actions` |
| Layout | `alignment`, `group_position`, `content_inset`, `enabled`, `size`, `theme`, `accessibility_label` |

The avatar is flush with the bottom of the content beside it (the bubble's
surface, not its reaction overhang), and the footer sits below both, indented
to the content column, as upstream lays them out. An `.end` message mirrors the
row. Header and footer are inset by the bubble's padding so they line up with
its text; a ghost bubble drops the inset, and `content_inset` overrides either
way, as upstream's `content_inset(bool)` does.

Footer actions are compact ghost buttons: icon-only (tooltip and accessible
name from `tooltip`, `label` or `name`), a label, or both. They emit
`chat_message_action_id(id, index)`:

```v
if event := ui2.chat_message_event_from_action(config, action) {
	match event.kind {
		.action { handle(event.name) } // 'reply', 'copy'
		.reaction { m.reactions = ui2.bubble_toggle_reaction(m.reactions, event.name) }
		.add_reaction { m.picker = config.id }
	}
}
```

The row's role is `listitem`, labelled with the author, timestamp and status.

### `chat_message_group`

```v
run := ui2.ChatMessageGroupConfig{
	frame:    ui2.rect(16, y, row_width, 0)
	messages: [first, second, third] // one sender's ChatMessageConfigs
	theme:    theme
}
el := ui2.chat_message_group(run)!
if event := ui2.chat_message_group_event_from_action(run, action) {
	// event.index is the message, event.event what happened to it
}
```

The group sets each message's frame, run position, size and theme; its role is
`list`. A transcript that mixes senders and markers usually places rows itself
with `chat_group_positions`, as the example does.

## Marker

```v
today := ui2.marker(frame: ui2.rect(16, y, w, 0), text: 'Today', variant: .separator, theme: theme)!
unread := ui2.marker(
	frame:      ui2.rect(16, y, w, 0)
	text:       'New messages'
	variant:    .separator
	color:      theme.danger
	line_color: theme.danger
	bold:       true
	theme:      theme
)!
typing := ui2.marker(
	id:            'typing' // loading needs an id
	frame:         ui2.rect(56, y, w, 0)
	text:          'Maya is typing…'
	loading:       true
	loading_style: .shimmer
	theme:         theme
)!
```

| Field | Meaning |
| --- | --- |
| `variant` | `.plain` (default), `.separator` (a line on each side), `.border` (a line under the row) |
| `alignment` | `.auto` (separators center, others start), `.start`, `.center`, `.end`; a separator at the start draws only its trailing line, at the end only its leading one |
| `text`, `icon` | Text (wraps when the row is too narrow, except while shimmering) and a symbol (`symbol_known`) before it |
| `loading`, `loading_style` | `.spinner` (default) puts `loading_spinner` in the icon slot unless the marker has an icon; `.shimmer` pulses the text with `shimmer_text` |
| `reduce_motion`, `shimmer_duration` | Stillness for reduced motion; one pulse in seconds (2) |
| `action_label` | A trailing text button ("Retry", "Jump") emitting `marker_action_id(id)`; `marker_action_activated(config, action)` checks it |
| `color`, `icon_color`, `line_color`, `background` | Text, icon, line and surface colors; `background` draws a rounded surface behind the content |
| `bold`, `font_size`, `size`, `theme` | Typography and colors |
| `accessibility_role`, `accessibility_label` | `status` while loading, otherwise none; the label defaults to the text |

A marker that stops loading, or switches between spinner and shimmer, stops the
loop it started. When a loading marker leaves the tree call
`stop_marker_animations(id)`: like every feedback animation its loop keeps the
native backends redrawing otherwise.

## Avatar group

```v
team := ui2.avatar_group(
	frame:    ui2.rect(16, 16, 200, 40)
	avatars:  people.map(ui2.AvatarConfig{ name: it.name, image_path: it.photo })
	limit:    4
	overflow: .count // '+N'; .ellipsis or .hidden
	theme:    theme
)!
width := ui2.avatar_group_width(config) // to size or right-align the frame
```

| Field | Meaning |
| --- | --- |
| `avatars` | `AvatarConfig`s drawn with `avatar`; the group sets their frame and theme |
| `limit`, `overflow` | At most `limit` avatars (3; 0 shows all), then a '+N' avatar, an ellipsis avatar, or nothing (`avatar_group_counts`, `avatar_group_overflow_text`) |
| `size`, `diameter` | small 24, medium 32, large 40 (`avatar_group_diameter`); `diameter` for any other, such as GPUI's 16, 48 or 80 |
| `overlap` | Share of a diameter the avatar before covers (0.25; 0 to 0.9) |
| `ring`, `ring_color` | A 2-point ring in the background color keeps overlapped avatars apart |
| `identity_colors` | Colors initials by name (default) |

The first avatar lies on top, as upstream draws it, and the overflow avatar
stands 4 points clear of the last one, like upstream's ellipsis. Initials are a
little smaller than a lone avatar's and centered in the part of each circle
left showing. Each avatar has its name as a tooltip; the group is a `group`
labelled with the names and how many are hidden.

### Identity colors

`avatar_identity_colors(name, dark)` returns a fill and initials color picked
from the initials, so a person always gets the same one: twelve hues, pale
fills with deep initials in a light theme and deep fills with pale initials in
a dark one, every pair at least WCAG AA (tested).
`avatar_identity_theme(name, theme)` returns a theme with those colors as
`muted` and `foreground`, which is what `avatar` draws initials with, so any
avatar can use them. Upstream derives its ring from twelve OkLCH hues; ui2's
are hand-picked sRGB pairs.

## Implemented and omitted

Implemented from upstream: bubble alignment, every variant, the 80% maximum
width and full-width ghost, rich content under text, groups, top/bottom and
start/end reaction regions with action chips, theme-derived colors; message
avatar/header/content/footer slots, start/end alignment, the bottom-flush
avatar, the footer indented to the content column, ghost-driven insets and the
`content_inset` override, groups, list-item identity and role; marker plain,
separator and border variants, alignment including one-sided separators,
spinner and shimmer loading (an icon wins over the spinner, lines and borders
stay while loading), icon and text content, interactive content; avatar group
limit, ellipsis, sizes and overlap.

Added for ui2: height helpers and layouts for list rows, `chat_group_positions`
with corner joining and once-per-run headers and avatars, reaction data
(`BubbleReaction`) with a selected state, counts, an add button, a decoder and
`bubble_toggle_reaction`, `max_lines` for collapsed messages, delivery statuses,
footer action decoding, '+N' overflow, and identity colors.

Omitted, and why:

- **`Styled` refinements and arbitrary children in every slot.** ui2 configs
  take explicit fields (colors, sizes, insets, `content` elements with their
  size) because there is no style cascade or intrinsic layout to refine.
  `with_stack_style` and `separator_style` beyond the line color are therefore
  not offered.
- **Arbitrary reaction children and `action(Button)`.** Reactions are data
  (`BubbleReaction`) so the bubble can size the region and decode its actions;
  a popover trigger in the region is left to the application.
- **Shimmer per glyph.** `shimmer_text` pulses the whole label (see
  `docs/gpui-kit/feedback.md`); the opacity animation upstream gives arbitrary
  marker content is not reproduced.
- **Reading reduced motion from the system.** Pass `reduce_motion`.
- **Header/footer typography refinement.** Header and footer use the size
  preset's meta font; the name is bold in the foreground color rather than
  upstream's uniform muted medium weight, so the sender stands out.

## Renderer notes

- Emoji draw in color on AppKit and UIKit and as monochrome outlines in the
  label color in the custom renderer (Noto Emoji), as everywhere in ui2.
