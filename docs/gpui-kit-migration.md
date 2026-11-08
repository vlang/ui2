# GPUI Kit component migration

Every component GPUI Kit documents now has a ui2 counterpart: the
[parity tracker](#parity-tracker) lists all 80 pages of its catalog, 78
components marked done with the batch that added them and two pages that are
not components (the index and the window root). Batch 1 compared
UI2 at `15709bb28ddb4a05c499f52936a11cf0feedb22d` with
[GPUI Kit](https://github.com/longbridge/gpui-kit) at
`1b6059c13315dc5c304759ad3aa666e0b6e301d8`.

## Added components

All constructors return `!Element`, validate finite/non-negative frame
geometry, and compose existing UI2 elements rather than introducing renderer
kinds or a Rust dependency. Their child frames are parent-local.

| GPUI Kit concept | UI2 API | Behavior in this migration |
| --- | --- | --- |
| Badge | `badge(BadgeConfig)` | Text, capped counters, zero visibility, dot display |
| Avatar | `avatar(AvatarConfig)` | Image or Unicode-scalar first/last initials |
| Tag | `tag(TagConfig)` | Solid/outline styling, optional dismiss action |
| Separator | `separator(SeparatorConfig)` | Horizontal/vertical, bounded thickness |
| Skeleton | `skeleton(SkeletonConfig)` | Static rounded or centered circular placeholder |
| Kbd | `kbd(KbdConfig)` | Display-only keyboard shortcut hint |
| Link | `link(LinkConfig)` | Button activation with application-owned navigation |
| Alert | `inline_alert(InlineAlertConfig)` | Inline title/message and optional dismiss action; `alert()` remains the OS message box |
| Empty | `empty_state(EmptyStateConfig)` | Empty-state text and optional primary action |
| GroupBox | `group_box(GroupBoxConfig)` | Labeled border and padded content body |
| DescriptionList | `description_list(DescriptionListConfig)` | Two-column term/value rows |
| Collapsible | `collapsible(CollapsibleConfig)` | Controlled disclosure; closed content unmounted |
| Breadcrumb | `breadcrumb(BreadcrumbConfig)` | Stable item keys, disabled items, non-actionable current location |
| Pagination | `pagination(PaginationConfig)` | Controlled page navigation, page windows, compact mode |

The display and container builders are new V implementations following the
catalog's concepts. The pagination state/window algorithm is adapted from
`crates/base/src/pagination.rs`; see the [attribution](../third_party/gpui-kit/NOTICE.md)
and Apache-2.0 license. Existing UI2 code remains under its existing license.

## Added primitives

`ComponentSize` and `component_metrics` supply small/medium/large metrics.
`ComponentTheme`, `ComponentTone`, and `component_theme(dark)` provide explicit,
immutable semantic color tokens. Pass the same theme to related components;
there is no global theme singleton. `component_inset` safely pads a `Rect`,
preserving its coordinate space and clamping padding for tiny frames.

`PaginationState` contains normalized, immutable controlled state. It clamps
empty totals to one page, rejects disabled/current/out-of-range transitions,
and exposes `items()`, `previous_page()`, `next_page()`, and `request_page()`.
The requested visible window is clamped to 5..100; total pages are not capped.
Ellipses expose half-open hidden ranges, so clients can implement their own
jump UI without allocating a list for every page in the dataset.

```v
state := ui2.pagination_state(5, 1000).with_visible_pages(7)
pages := ui2.pagination(
    id: 'results'
    frame: ui2.rect(20, 20, 420, 40)
    state: state
    theme: ui2.component_theme(false)
) or { panic(err) }
```

In the application's event handler, decode and validate the action against
its **current** state, then store the returned page and rebuild:

```v
if page := ui2.pagination_page_from_action('results', state, event) {
    // Update the model's current page, preserving its theme/window preferences.
    // Rebuild pagination with pagination_state(page, state.total_pages()).
    println('Requested page ${page}')
}
```

The decoder rejects unrelated IDs, malformed digits, integer overflow,
leading-zero encodings, disabled state, and invalid destinations. Previous,
next, and numbered controls all use the same action encoding. The current page
is an enabled button marked `current` (a disabled one is dimmed and announced as
unavailable by native backends); activating it decodes to nothing. Ellipses are
labels in this version, not clickable page-jump menus.

## Identity and state

Interactive components require a non-empty `id`. Internal actionable parts
reserve `${id}:component:` for their mounted IDs; application children must
not reuse that namespace. Action IDs are separate: tag/alert/empty-state
buttons use the configured action; collapsible defaults to its root ID;
breadcrumb entries default to the item ID. Generated children are anonymous
where lookup is unnecessary. Each constructor checks the resulting subtree
with `validate_element_tree`; the renderer still validates the complete tree.

Handle a disclosure or dismiss event in application state and rebuild. No
builder mutates a model or creates timers. Collapsible removes its body while
closed, so local native edits/focus in that body are not retained. Group-box
and collapsible children are positioned relative to their body, not the root.
Application-supplied child geometry is not automatically resized or clipped
by these builders beyond the existing backend's behavior.

Button text is centered in its frame on every backend, so give a link a frame
sized to its text. UI2 has no backend-neutral text measurement, so breadcrumb
items are sized from an estimate of their label width and packed from the
left, shrinking evenly when the trail does not fit.

Accessibility roles, labels, and current/expanded state are attached to the
resulting elements. This is metadata, not a claim of GPUI's AccessKit parity;
keyboard behavior and native accessibility mapping remain backend-dependent.
AppKit exposes `group`, `navigation`, `status` and `alert` as `AXGroup`,
`separator` as `AXSplitter` and `img` as `AXImage`.
Images use the existing image implementation: initials are chosen only when
`image_path` is empty, not after a load failure. Image masking also depends on
the backend. Skeletons do not shimmer; keyboard hints do not register shortcuts;
links never automatically launch a URL. Display strings are application-owned;
pagination's built-in accessibility strings are currently English.

These are V APIs. This migration does not add VML tags, compiled-VML lowering,
or C ABI constructors for the new components.

## Existing counterparts retained

UI2 already provides buttons, checkboxes, switches, sliders, text input,
dropdowns, progress bars, charts, accordion, carousel, tabbed panel, tree view,
menus, tooltips, modal view, popup, animation, and several layout families.
They are retained rather than replaced by parallel implementations. These are
counterparts, not assertions that every GPUI option or interaction is present.
The existing `spinner` is a selection control, not a GPUI loading indicator.

## Parity tracker

The target is every component GPUI Kit documents (`website/component/*.md`,
80 pages). Status per page: **Done** — ported with its documented, portable
features; **Existing** — a ui2 component predating the port covers it, but its
options have not yet been compared with GPUI Kit's; **Partial** — some of it
exists; **Planned** — scheduled for the named batch. Per-group details live in
[`docs/gpui-kit/`](gpui-kit/).

| GPUI Kit | ui2 | Status | Notes |
| --- | --- | --- | --- |
| accordion | `accordion` | Done (batch 10) | Stack layout, multiple open, sizes, animation; [disclosure](gpui-kit/disclosure.md) |
| alert-dialog | `alert_dialog` | Done (batch 3) | Native `confirm` also exists; [dialogs](gpui-kit/dialogs.md) |
| alert | `inline_alert` | Done (batch 1) |  |
| attachment | `attachment`, `attachment_group` | Done (batch 7) | Upload states, previews, groups; [attachments](gpui-kit/attachments.md) |
| avatar | `avatar`, `avatar_group` | Done (batch 7) | Avatar group with overflow; [chat](gpui-kit/chat.md) |
| badge | `badge` | Done (batch 1) |  |
| bubble | `bubble`, `bubble_group` | Done (batch 7) | Variants, groups, reactions; [chat](gpui-kit/chat.md) |
| button | `styled_button`, `button_group`, `button` | Done (batch 2) | Variants and button group; [choice](gpui-kit/choice.md) |
| calendar | `calendar`, `CalendarDate` | Done (batch 4) | [datetime](gpui-kit/datetime.md) |
| carousel | `carousel` | Done (batch 10) | Controls, indicators, several per view, drag, autoplay; [disclosure](gpui-kit/disclosure.md) |
| chart | `line_chart`, `bar_chart`, `area_chart`, `pie_chart`, `radar_chart`, `candlestick_chart`, `sankey_chart` | Done (batch 9) | Hover tooltips, legends, appear motion; [plot](gpui-kit/plot.md), [charts](gpui-kit/charts.md). The older `chart` stays |
| checkbox | `styled_checkbox`, `checkbox_group`, `checkbox` | Done (batch 10) | Description, indeterminate, sizes, groups; [controls](gpui-kit/controls.md) |
| clipboard | `clipboard_button`, `copyable_text` | Done (batch 3) | [notifications](gpui-kit/notifications.md) |
| collapsible | `collapsible` | Done (batch 1) |  |
| color-picker | `color_picker`, `color_picker_popover`, `ColorHsva` | Done (batch 4) | [color](gpui-kit/color.md) |
| combobox | `combobox` | Done (batch 5) | [pickers](gpui-kit/pickers.md) |
| command | `command_palette` | Done (batch 5) | [pickers](gpui-kit/pickers.md) |
| data-table | `data_table` | Done (batch 5) | Virtualized rows, sorting, resizing, selection; [tables](gpui-kit/tables.md) |
| date-picker | `date_picker`, `date_picker_overlay` | Done (batch 4) | [datetime](gpui-kit/datetime.md) |
| description-list | `description_list` | Done (batch 1) |  |
| dialog | `modal_dialog`, `modal_view`, `popup` | Done (batch 3) | [dialogs](gpui-kit/dialogs.md) |
| diff | `diff_view`, `diff_state`, `parse_diff` | Done (batch 8) | Unified and split, patches, conflicts, virtualized; [diff](gpui-kit/diff.md) |
| dock | `dock_area`, `DockLayout` | Done (batch 6) | Tabbed docks, resizing, zoom, saved layouts; [panels](gpui-kit/panels.md) |
| dropdown_button | `dropdown_button` | Done (batch 3) | [popovers](gpui-kit/popovers.md) |
| editor | `code_editor`, `text_editor`, `text_area` | Done (batch 8) | Highlighting, gutter, search, completions, editing rules; [editor](gpui-kit/editor.md) |
| empty | `empty_state` | Done (batch 1) |  |
| focus-trap | `focus_trap_next`, `FocusTrap` | Done (batch 3) | [dialogs](gpui-kit/dialogs.md) |
| form | `form`, `form_field` | Done (batch 6) | Grid layout, sections, validation; [form](gpui-kit/form.md) |
| group-box | `group_box` | Done (batch 1) |  |
| hover-card | `hover_card`, `HoverCardState` | Done (batch 3) | [popovers](gpui-kit/popovers.md) |
| icon | `named_icon`, `IconName`, `symbol:` images | Done (batch 2) | [feedback](gpui-kit/feedback.md) |
| image | `image_box`, `image` | Done (batch 10) | Fit modes, rounded corners, loading and fallback; [basics](gpui-kit/basics.md) |
| index | — | Not applicable | Upstream documentation landing page |
| input-group | `input_group` | Done (batch 2) | [inputs](gpui-kit/inputs.md) |
| input | `text_field`, `input_group` | Done (batch 2) | Prefix, suffix and clear button through `input_group`; [inputs](gpui-kit/inputs.md) |
| kbd | `kbd` | Done (batch 1) |  |
| label | `styled_label`, `label` | Done (batch 10) | Secondary text, highlights, masking; [basics](gpui-kit/basics.md) |
| list | `list`, `searchable_list` | Done (batch 5) | [lists](gpui-kit/lists.md) |
| marker | `marker` | Done (batch 7) | [chat](gpui-kit/chat.md) |
| menu | `dropdown_menu`, `set_menu_bar`, `Element.menu`, tray | Done (batch 3) | Dropdown/popup menus with submenus; [popovers](gpui-kit/popovers.md) |
| message-scroller | `message_scroller`, `MessageScrollerState` | Done (batch 7) | Follow-tail, prepend anchoring, unread; [messages](gpui-kit/messages.md) |
| message | `chat_message`, `chat_message_group` | Done (batch 7) | Named `chat_message`; [chat](gpui-kit/chat.md) |
| notification | `NotificationList`, `notification_stacks` | Done (batch 3) | [notifications](gpui-kit/notifications.md) |
| number-input | `number_input` | Done (batch 2) | [inputs](gpui-kit/inputs.md) |
| otp-input | `otp_input` | Done (batch 2) | [inputs](gpui-kit/inputs.md) |
| pagination | `pagination` | Done (batch 1) |  |
| plot | `PlotLinearScale`, `PlotBandScale`, `plot_line_path`, `plot_stack`, `plot_axis` | Done (batch 9) | Scales, shape generators, axes; [plot](gpui-kit/plot.md) |
| popover | `popover`, `popover_place` | Done (batch 3) | [popovers](gpui-kit/popovers.md) |
| progress | `progress_bar`, `linear_progress`, `progress_circle` | Done (batch 2) | [feedback](gpui-kit/feedback.md) |
| questionnaire | `questionnaire` | Done (batch 7) | [questionnaire](gpui-kit/questionnaire.md) |
| radio | `radio`, `radio_group` | Done (batch 2) | [choice](gpui-kit/choice.md) |
| rating | `rating` | Done (batch 2) | [choice](gpui-kit/choice.md) |
| resizable | `resizable_panels`, `resize_handle` | Done (batch 6) | [panels](gpui-kit/panels.md) |
| root | `screen` | Not applicable | GPUI window root; ui2 builds a `screen` |
| scrollable | `scrollable`, `scrollbar`, `scroll` | Done (batch 10) | Stacks, metrics, scroll-to, themed scrollbars; [basics](gpui-kit/basics.md) |
| select | `select_box`, `dropdown`, `spinner` | Done (batch 5) | Searchable and multiple select; [pickers](gpui-kit/pickers.md) |
| settings | `settings` | Done (batch 6) | Pages, groups, search, reset; [settings](gpui-kit/settings.md) |
| sheet | `sheet` | Done (batch 3) | [dialogs](gpui-kit/dialogs.md) |
| shimmer | `shimmer`, `shimmer_text` | Done (batch 2) | [feedback](gpui-kit/feedback.md) |
| sidebar | `sidebar`, `sidebar_toggle_button` | Done (batch 6) | Groups, nested items, icon rail; [sidebar](gpui-kit/sidebar.md) |
| skeleton | `skeleton` | Done (batch 1) |  |
| slider | `styled_slider`, `slider` | Done (batch 10) | Range, log scale, marks, value labels; [controls](gpui-kit/controls.md) |
| speech | `speech_button`, `SpeechSession`, `SpeechRecognizer` | Done (batch 7) | macOS recognizer in bundled apps; elsewhere apps plug one in; [speech](gpui-kit/speech.md) |
| spinner | `loading_spinner` | Done (batch 2) | `spinner` is ui2's selection control; [feedback](gpui-kit/feedback.md) |
| status-bar | `status_bar` | Done (batch 6) | [bars](gpui-kit/bars.md) |
| stepper | `stepper` | Done (batch 2) | [choice](gpui-kit/choice.md) |
| switch | `styled_switch`, `switch_control` | Done (batch 10) | Label, description, sizes, loading; [controls](gpui-kit/controls.md) |
| table | `table` | Done (batch 5) | [tables](gpui-kit/tables.md) |
| tabs | `tab_bar`, `tabbed_panel` | Done (batch 10) | Six variants, closable, overflow, reorder; [navigation2](gpui-kit/navigation2.md) |
| tag | `tag` | Done (batch 1) |  |
| text-view | `rich_text_view`, `text_view_markdown`, `text_view_html` | Done (batch 8) | Markdown and HTML, streaming fade, highlights; [textview](gpui-kit/textview.md) |
| textarea | `textarea`, `text_area` | Done (batch 10) | Auto-grow, counter, max length; [basics](gpui-kit/basics.md) |
| theme | `ComponentTheme`, `component_theme_registry` | Done (batch 9) | Theme sets from JSON, built-in sets, gradients, system appearance; [theme](gpui-kit/theme.md) |
| time-field | `time_field` | Done (batch 4) | [datetime](gpui-kit/datetime.md) |
| title-bar | `title_bar` | Done (batch 6) | Uses `set_window_chrome`; [bars](gpui-kit/bars.md) |
| toggle | `toggle`, `toggle_group` | Done (batch 2) | [choice](gpui-kit/choice.md) |
| toolbar | `toolbar` | Done (batch 6) | [bars](gpui-kit/bars.md) |
| tooltip | `tooltip_popup`, `with_tooltip` | Done (batch 10) | Delays, rich content, shortcuts; [basics](gpui-kit/basics.md) |
| tree | `tree_view` | Done (batch 10) | Selection, check boxes, lazy children, virtualized, drag; [navigation2](gpui-kit/navigation2.md) |
| virtual-list | `virtual_list`, `virtual_list_fixed`, `virtual_list_sized` | Done (batch 5) | [lists](gpui-kit/lists.md) |

GPUI's application runtime, WebAssembly and JavaScript extension infrastructure
are not part of this port.

## Verification and gallery

With V 0.5.2+ and the repository's normal native dependencies installed:

```sh
v test ui/component_catalog_test.v
v run examples/component_catalog/main.v
# macOS/Windows custom renderer:
v -d ui2_custom_rendering test ui/component_catalog_test.v
v -d ui2_custom_rendering run examples/component_catalog/main.v
```

The gallery exercises all 14 additions, themes, dismiss actions, disclosure,
breadcrumb navigation events and pagination. The regression suite covers
identity, disabled/action behavior, invalid and tiny geometry, Unicode initials,
page-window coverage, large totals and malicious action payloads. The existing
CI matrix now runs that suite and builds the gallery with the other examples.
Manual visual/keyboard/screen-reader testing is still required on each backend.
