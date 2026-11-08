# Attachments

A port of GPUI Kit's [Attachment](https://github.com/longbridge/gpui-kit/blob/main/website/component/attachment.md)
page and `AttachmentGroup`, compared with GPUI Kit `main` at
`f8cf0bd964f9ef2e5b7be79f3a8fc391371feb4a`. The gallery is
`examples/gpui_attachments`:

```sh
v run examples/gpui_attachments/main.v
v -d ui2_custom_rendering run examples/gpui_attachments/main.v
```

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `Attachment` with its media, content, title, description and actions slots | `attachment(AttachmentConfig)` | `ui/component_attachments.v` |
| `AttachmentStatus` | `AttachmentStatus` | `ui/component_attachments.v` |
| `AttachmentGroup` | `attachment_group(AttachmentGroupConfig)` | `ui/component_attachments_group.v` |

The size geometry, the status rules and the scrim strengths follow
`crates/component/src/attachment.rs`, so that file carries GPUI Kit's
Apache-2.0 header; the layout, file-type detection, sizes in words, the middle
ellipsis, the dashed border and the action decoding are new. Like every ported
component the attachment is controlled: the application owns the upload, builds
never change it, and actions are decoded in `on_event`.

## Attachment

GPUI Kit composes an attachment from typed slots holding arbitrary elements. A
ui2 component is a config, so the slots become fields: the file's `name`, `mime`
and `bytes` give the icon, title and description, and the controls are switches
and a list of actions.

```v
el := ui2.attachment(
	id:        'report'
	frame:     ui2.rect(16, 16, 0, 0) // zero width and height: the natural size
	name:      'quarterly-report.pdf'
	bytes:     2_516_582 // described as `PDF · 2.4 MB`
	status:    .uploading
	progress:  model.percent // a ring in the media, a bar along the bottom, `· 62%`
	removable: true
	theme:     theme
)!
```

### Fields

| Field | Meaning |
| --- | --- |
| `id` | Required with a control (click, remove, retry, actions) or while uploading or processing, whose animations run on its parts. In a group, the item's key. |
| `frame` | Position; a zero width or height takes the natural extent (`attachment_natural_size`). It includes the remove control's 6 px overhang above and after the card. |
| `name`, `mime`, `bytes` | The file. The name is the default title and accessible name; the MIME type, else the extension, picks the icon; the type and size make the default description. |
| `title`, `description` | Override the title and description. |
| `error_message` | The failure reason: the description while failed, and the tooltip. |
| `icon` | A symbol name drawn instead of the file type's icon. |
| `image_path`, `image_width`, `image_height` | An image preview instead of the icon. With its pixel size the image is fit inside the media square identically on every renderer; without it, it fills the square (AppKit keeps its aspect ratio, the custom renderer stretches), so pass a square thumbnail or the size. |
| `status` | `?AttachmentStatus`: none is `.complete`, or a group's status. |
| `title_status`, `description_status` | Override the status the title (shimmer) and description (danger color, default text) follow. |
| `progress` | `?f64` percent, clamped to 0...100. Only while uploading. |
| `tooltip` | Hover text on the card. |
| `axis` | `.horizontal` chip (default) or `.vertical` card with the preview above the text. |
| `size` | `.small`, `.medium` (default), `.large`. |
| `hide_media`, `hide_content` | Leave out the preview or the text. A vertical attachment without text is a square image tile. |
| `clickable` | The whole card is a button and reports `.click`. |
| `removable`, `remove_on_hover` | A remove disc on the card's upper trailing corner; with `remove_on_hover` it shows only while `hovered`. |
| `retryable` | While failed: a retry disc in the media and a Retry link at the end of the description. |
| `actions` | `[]AttachmentAction{id, label, icon, enabled}`: icon (or text) buttons after the text in a chip, raised discs over a vertical card's preview. `attachment_download_action()` and `attachment_open_action()` are ready-made. |
| `hovered` | The hover state, kept by the application from hover events. A clickable card takes a muted surface. |
| `enabled` | False disables every control and the card click. |
| `reduce_motion` | Spinners rest, the title does not shimmer, the bar does not ease. |
| `surface` | The color behind the attachment (default: the theme's background), which rounds an image tile's corners on the custom renderer. |
| `accessibility_label`, `theme` | As for every component. |

### Anatomy and sizes

| Size | Chip | Media | Title / description | Vertical card |
| --- | --- | --- | --- | --- |
| `.small` | 200 × 48 | 32 | 12 / 11 pt | 104 wide |
| `.medium` | 232 × 56 | 38 | 13 / 12 pt | 120 wide |
| `.large` | 272 × 64 | 44 | 14 / 13 pt | 144 wide |

`attachment_metrics(size)` returns the whole geometry. A chip without text hugs
its media and actions; an image tile is a square the chip's height, filled to
its border. A vertical card's media is a square the card's width less its
padding, with the text below it.

The title is shortened in the middle so the extension stays visible
(`quarterly-fin…report.pdf`, `attachment_middle_ellipsis`), using
`attachment_text_width`, a per-character estimate for bold text that is closer
for file names than `component_text_width_estimate`. The description is cut at
its end by the label.

### Lifecycle

| Status | Card | Media (icon) | Media (image) | Default description |
| --- | --- | --- | --- | --- |
| `.pending` | Dashed border | File icon | Image | `Ready to upload` |
| `.uploading` | Bar along the bottom with `progress` | Spinner, or a ring with `progress` | Scrim 35 %, white spinner or ring on a dark disc | `Uploading`, `· 62%` appended with `progress` |
| `.processing` | | Spinner | Scrim 35 %, white spinner | `Processing…` |
| `.failed` | Danger border; reason as tooltip | Danger tint with the retry disc, or an alert glyph | Scrim 55 % with the retry disc, or a white alert glyph | `error_message`, else `Upload failed`; Retry link with `retryable` |
| `.complete` | | File icon | Image | Type and size, `PDF · 2.4 MB` |

The title shimmers (`shimmer_text`) while its status is in progress. The
status helpers `is_pending()` ... `is_in_progress()` and `description()` (the
words above) are pure readers. The root's accessibility value is the status in
words with the percentage.

Animations run on the attachment's parts. The attachment stops the ones it no
longer shows when it is rebuilt; when an uploading attachment leaves the screen,
call `stop_attachment_animations(id)` (a group does this for items that leave it).

### Events

```v
fn on_event(action string) {
	if event := ui2.attachment_event_from_action(report_config(), action) {
		match event.kind {
			.remove { app.remove(event.key) }
			.retry { app.retry(event.key) }
			.click { app.preview(event.key) }
			.action { app.run(event.action, event.key) } // 'download', 'open', ...
			.hover_start { app.hovered = true }
			.hover_end { app.hovered = false }
		}
	}
}
```

Pass the same config the attachment was built from. The decoder rejects actions
of other components, malformed parts (including a custom action's id spelled
in anything but the lowercase hex the attachment wrote), controls the
attachment does not show (no `removable`, retry outside `.failed`, an action it
does not have), disabled controls and actions, and hover reports that change
nothing. Hover is reported only by a clickable card or a remove control shown
on hover.

## Attachment group

```v
row := ui2.attachment_group(
	id:            'composer'
	frame:         ui2.rect(12, 8, 700, 82)
	items:         app.uploads.map(it.config()) // each item's id is its key
	status:        .uploading // for items whose status is none
	hovered:       app.hovered_upload
	edge_fade:     theme.background
	scroll_offset: app.composer_offset
	theme:         theme
)!
```

| Field | Meaning |
| --- | --- |
| `layout` | `.row`: one row that scrolls sideways (GPUI's group). `.wrap`: rows wrapped at the frame's width, scrolling down when they overflow. `.list`: one attachment per line, chips stretched to the width. |
| `items` | `[]AttachmentConfig`. Ids are keys, non-empty and unique; frames are computed. The group's `theme`, `enabled`, `reduce_motion` and `surface` apply to every item. |
| `status` | Inherited by every item whose `status` is none; an item's own status wins. |
| `gap` | Between attachments (12). |
| `hovered` | The key of the hovered item. |
| `edge_fade`, `scroll_offset` | A row fades an edge into the color while it hides attachments. The application keeps the offset: `on_scroll` → `scroll_horizontal_offset(attachment_group_scroll_id(id))`. |

Cards share a top edge: when any item can be removed, every line leaves room for
the overhang. A row leaves 4 px above its cards and 12 px below them, where the
custom renderer draws its always-visible scroller. `attachment_group_frames` and
`attachment_group_content_size` give the layout, `attachment_group_item_id(id,
key)` an item's element id, and `attachment_group_event_from_action(config,
action)` decodes as above with the item's key, rejecting keys no longer in the
group.

## Implemented and omitted

| GPUI Kit feature | ui2 |
| --- | --- |
| Media, content (title, description), actions slots; each optional | Fields; `hide_media`, `hide_content`; the icon, title and description derive from the file |
| `AttachmentMedia::src` with `ObjectFit::Cover` | `image_path`. ui2 cannot clip an image on the custom renderer, so it is fit (with `image_width`/`image_height`) or fills the square |
| `AttachmentMedia::overlay`, arbitrary children in every slot, `Styled` refinements | Omitted: a config takes data, not elements. Custom content goes beside the attachment; colors come from `ComponentTheme` |
| `AttachmentMedia::with_size`, media aspect ratio | Omitted; the media follows the attachment's size and axis |
| Five statuses with their surfaces, scrims, spinner, progress ring, bar and percentage | Implemented with `loading_spinner`, `progress_circle`, `linear_progress` and `shimmer_text` |
| Status inheritance and explicit child status | `title_status`, `description_status`, and group → item inheritance |
| `with_shimmer_style` | Omitted; the default shimmer, or none with `reduce_motion` |
| Sizes XSmall, Small, Medium, Large, `Size::Size(px)` | Small, Medium, Large (`ComponentSize` has no XSmall); no custom base size. Vertical cards grow with the size where GPUI keeps 120 px |
| `w_auto`, `w_full`, `w(...)` | The frame's width; a list group stretches chips |
| Horizontal and vertical axes, image tile flush to the border | Implemented |
| Whole-card `on_click` with the click layer below the actions | `clickable`; actions stay separate buttons on top |
| Muted hover surface of a clickable card | Implemented through `hovered` |
| `on_remove` disc riding the corner, shown on hover on desktop | `removable`, always shown unless `remove_on_hover` (the application tracks hover; touch screens have none) |
| `on_retry`: disc in the media and a Retry link after the description | Implemented; the link sits at the end of the line, since text width is estimated |
| Failed without retry shows the ban glyph | An alert glyph (`exclamationmark.circle`); there is no ban symbol every renderer draws |
| `tooltip` | Implemented; defaults to `error_message` while failed |
| Actions as arbitrary `Button`s | `AttachmentAction`s (icon or text), with download and open presets |
| Remove and Retry localized labels | English labels (`Remove …`, `Retry …`) |
| `AttachmentGroup` horizontal scroll row | `.row`; also `.wrap` (a wrapping grid) and `.list` (not upstream) |
| `with_edge_fade(color)` | Implemented, from the application's `scroll_offset`; the fades appear and disappear without GPUI's 200 ms transition |
| `track_scroll(&ScrollHandle)` | The row's id is `attachment_group_scroll_id(id)`, for `scroll_to_horizontal_offset` and friends |
| Dashed border while pending | ui2 has no dashed borders: the border has breaks painted over its straight runs and keeps whole rounded corners |
| File-type icon and human-readable size | New: `attachment_file_kind`, `AttachmentFileKind.symbol()`, `attachment_type_text`, `attachment_size_text` (powers of 1024: `2.4 MB`), `attachment_meta_text` |

## Rendering notes

- The custom renderer does not clip views. An image preview's corners are
  rounded there by a ring in the surrounding color hugging the media from
  outside (`surface` for an image tile, whose surroundings are the page); the
  other renderers clip a rounded view and the ring falls on its own color.
- AppKit draws a view's own border above its children, so the dashed border is
  a separate ring under breaks rather than the card's border.
- The upload bar is inset from the card's rounded corners rather than following
  them, again because nothing clips it on the custom renderer.
- The edge fades are ordinary views over the row's ends. On AppKit they take
  clicks and wheel events there; scroll the row to reach what they cover.
- The custom renderer shows an overflowing scroll's bar all the time, where
  AppKit's fades out, so the attachment row leaves 12 points for it.

## Verification

```sh
v test ui/component_attachments_test.v
v -d ui2_custom_rendering test ui/component_attachments_test.v
```
