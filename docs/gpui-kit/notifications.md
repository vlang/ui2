# Notifications and clipboard

Ports of GPUI Kit's [notification](https://github.com/longbridge/gpui-kit/blob/main/website/component/notification.md)
and [clipboard](https://github.com/longbridge/gpui-kit/blob/main/website/component/clipboard.md)
pages, compared with GPUI Kit `main` at `f8cf0bd964f9ef2e5b7be79f3a8fc391371feb4a`.
The gallery is `examples/gpui_notifications`.

Both are new V implementations of the documented behavior; no GPUI Kit code was
translated. Like every ported component they are controlled: the application
owns the state, builds never change it, and actions are decoded in `on_event`.

## Notification

GPUI Kit keeps a `NotificationList` inside the window's `Root` and pushes into
it with `window.push_notification`. In ui2 the application owns a
`NotificationList` value and draws it with `notification_stacks`. Every change
to the list returns the timers it needs as `[]NotificationTimer` data, which
`list.schedule(id, timers)` turns into `after`/`cancel_timer` calls; when a
timer is due it is fed back to `list.fire(timer)`. The list itself never
starts a timer, so it is deterministic and is tested with a fake clock.

### API

| Item | Purpose |
| --- | --- |
| `Notification` | `key`, `kind`, `title`, `message`, `icon`, `action`, `clickable`, `autohide ?bool`, `duration`, `placement`, `content`/`content_height` |
| `NotificationKind` | `plain` (no icon), `info`, `success`, `warning`, `error` |
| `NotificationPlacement` | `inherit`, `top_left`, `top_center`, `top_right`, `left_center`, `right_center`, `bottom_left`, `bottom_center`, `bottom_right` |
| `NotificationList` | Settings `placement` (default `top_right`), `max_visible` (10), `enter_duration` (0.4 s), `exit_duration` (0.2 s), `clock` |
| `list.push(n)` | Adds the newest notification; a `key` already in the list is replaced |
| `list.dismiss(seq)`, `list.dismiss_key(key)`, `list.clear()` | Start the slide out (GPUI Kit's dismiss, `remove_notification`, `clear_notifications`) |
| `list.pause(placement)`, `list.resume(placement)` | Stop and restart every countdown, keeping the time left |
| `list.settle()` | Finish every slide in now, for notifications already on screen when a window opens |
| `list.fire(timer)` | Advance the notification a due timer belongs to; stale timers change nothing |
| `list.schedule(id, timers)` | Run timer requests with `after`/`cancel_timer` and release animation state |
| `list.entries()`, `list.visible()`, `list.find(key)`, `list.remaining(seq)`, `list.is_paused()`, `list.len()` | Read the list |
| `notification_stacks(NotificationStackConfig) ![]Element` | One stack per placement in use |
| `notification_event_from_action(id, list, action) ?NotificationEvent` | Decode `close`, `action`, `click`, `hover_start`, `hover_end` |
| `list.respond(event)` | GPUI Kit's built-in responses: close, action and click dismiss; hover pauses |
| `notification_action_id(id, seq, part)` | The action a part emits |

`NotificationStackConfig` has `id`, `frame` (usually `ui2.bounds()`), `list`,
`width` (382, GPUI Kit's), `margin` (16), `gap` (12), `animate` (true), `size`
and `theme`. `notification_stacks` returns a list rather than one element:
each stack is only as large as its notifications, so the rest of the window
stays clickable and hoverable on AppKit and Windows, where a transparent view
covering the window would take every click. Append the stacks after the other
children so they are drawn on top.

### Example

```v
@[heap]
struct App {
mut:
	notes ui2.NotificationList
}

const app = &App{}

fn build() ui2.Element {
	state := unsafe { app }
	theme := ui2.component_theme(false)
	mut children := []ui2.Element{}
	children << ui2.button('save', 'Save', ui2.rect(20, 20, 120, 32), ui2.BoxStyle{}, ui2.TextStyle{})
	// Last, so the stacks draw on top.
	children << ui2.notification_stacks(
		id:    'toasts'
		frame: ui2.bounds()
		list:  state.notes
		theme: theme
	) or { panic(err) }
	return ui2.screen(theme.background, children)
}

fn on_event(event string) {
	mut state := unsafe { app }
	if note := ui2.notification_event_from_action('toasts', state.notes, event) {
		if note.kind == .action && note.key == 'connection' {
			// Retry here.
		}
		state.notes.schedule('toasts', state.notes.respond(note))
		ui2.refresh()
		return
	}
	if event == 'save' {
		state.notes.schedule('toasts', state.notes.push(
			kind:    .success
			title:   'Saved'
			message: 'Your changes have been saved.'
		))
		ui2.refresh()
	}
}
```

A failed connection with a retry button that stays until it is handled, and an
upload whose notification is replaced when it finishes:

```v
state.notes.schedule('toasts', state.notes.push(
	key:     'connection'
	kind:    .error
	title:   'Connection lost'
	message: 'Unable to connect to the server.'
	action:  'Retry' // An action turns auto-hide off unless autohide says otherwise.
))
state.notes.schedule('toasts', state.notes.push(key: 'upload', kind: .info, message: 'Uploading…', autohide: false))
// Later: same key, so it replaces the first one.
state.notes.schedule('toasts', state.notes.push(key: 'upload', kind: .success, message: 'Uploaded'))
```

Keep the list in heap-allocated state (as above): `schedule` hands its address
to the timers it starts. Pass the same `id` to `schedule` and
`notification_stacks`, since `schedule` uses it to release the animation state
of notifications that are gone. Call `schedule` from `on_event` or a timer
callback, never from a build.

### Behavior

- Order and limits. The list is oldest first. Stacks put the newest
  notification nearest the edge they grow from: at the top of a top or
  side-centered stack, at the bottom of a bottom stack. `visible()` is the
  newest `max_visible` notifications plus every one still sliding out, as GPUI
  Kit's `ToastManager::visible`; the rest wait, still counting down.
- Auto-hide. A notification hides itself after `duration` seconds (default 5)
  unless `autohide` is false, or it has an `action` and `autohide` is unset.
  Like GPUI Kit, the countdown starts once the slide in is over.
- Pause. The stacks report `pointer:enter`/`pointer:leave`; while any stack is
  hovered every countdown stops and keeps its time left (GPUI Kit pauses all of
  them while its stacks are expanded). A stack that disappears under the
  pointer releases its pause even if no leave event arrives.
- Phases. A notification is `entering`, `present` or `leaving`, after GPUI
  Kit's toast transition status, and is dropped once its exit timer fires.
- Motion. Entering notifications slide in from just past the edge their stack
  grows from (sideways for the side-centered placements), all of a stack's
  arrivals by one distance so they move together; leaving ones slide out
  sideways. The card moves inside its slot and the slot inside the stack, along
  axes whose declared offset is zero, so a reflow or a window resize never
  fights the values an animation leaves behind. `animate: false` turns it off.
- Decoding. `notification_event_from_action` rejects foreign ids, malformed or
  leading-zero numbers, notifications that are gone, hidden or already leaving,
  parts a notification does not have (an action on one without, a click on one
  that is not clickable), and hover changes that change nothing.
- Icons. The kinds use SF Symbols `info.circle`, `checkmark.circle`,
  `exclamationmark.triangle` and `xmark.circle`, after GPUI Kit's Lucide icons.
  Only `info.circle` is in the portable symbol table today, so until all four
  are, every kind is drawn as a ring holding `i`, `✓`, `!` or `✕` in the kind's
  color, which looks the same on every renderer. `icon` takes any symbol name.
- Accessibility. Cards are `status`, or `alert` for warnings and errors, named
  by their title and message; a clickable card is a `button`. Stacks are
  `group`s named "Notifications"; the close button is "Dismiss notification".

### Implemented and omitted

| GPUI Kit feature | ui2 |
| --- | --- |
| Message, title, types with icons, custom icon | Implemented |
| Auto-hide after 5 s, `autohide(false)`, action disables auto-hide | Implemented; `duration` is configurable |
| Pause while hovered | Implemented for every stack, as in GPUI Kit |
| Pause while a notification has keyboard focus | Omitted: components cannot observe focus |
| Placement, global default and per notification, stacked separately | Implemented, all eight anchors |
| `max_items` | `max_visible` |
| Action button | Implemented as a title; the decoder reports `.action` |
| `on_click` (click dismisses and reports) | `clickable`; `respond` dismisses |
| `on_close` callback | Omitted: the application sees every dismissal it starts, and `find(key)` tells whether a notification is still there |
| Unique ids (`id::<T>()`, `id1`) and `remove_notification` | `key`, replacing on push, and `dismiss_key` |
| `clear_notifications` | `clear` |
| Custom content builder | `content` elements in a `content_height` box below the message |
| Enter/exit animation (slide and fade) | Slide only: ui2 has no opacity to animate |
| Collapsed Sonner-style stack that expands on hover | Omitted: notifications are always listed; expanding on hover would move cards under the pointer without the springs GPUI Kit animates them with |
| Close button shown on hover only | Always shown: touch backends have no hover, and a hidden control is hard to discover |
| Middle-click to dismiss | Omitted: ui2 reports no auxiliary clicks |
| Shadow | Omitted: ui2 boxes have no shadow; the card has a border |
| System notifications (`NotificationDelivery`) | Omitted: ui2 has no OS notification API |
| `margins`, `width` settings | `margin` and `width` on `NotificationStackConfig` |

## Clipboard

`clipboard_button` is GPUI Kit's `Clipboard`: a ghost button with a copy icon
that turns into a check mark after copying. Building it never touches the
clipboard; it emits `clipboard_action_id(id)` and the application copies the
current value in `on_event` (GPUI Kit's `value`/`value_fn`), then shows the
copied state, which ui2 leaves to application state.

| Item | Purpose |
| --- | --- |
| `clipboard_button(ClipboardButtonConfig) !Element` | Icon-only, or with `label` an outlined button reading `label` then `copied_label` |
| `copyable_text(CopyableTextConfig) !Element` | A read-only value with a copy button at its end |
| `clipboard_action_id(id)` | The action both emit |
| `clipboard_copy_from_action(id, value, action) bool` | Copies `value` when `action` is the button's; reports success |
| `ClipboardFeedback` | `copy_from_action(id, value, action)`, `show(id)`, `copied(id)`: the copied state for `duration` seconds (2, GPUI Kit's) through `after` |

`ClipboardButtonConfig` has `id`, `frame`, `label`, `copied_label`, `copied`,
`supported`, `hide_unsupported`, `enabled`, `tooltip`, `accessibility_label`,
`size` (default `.small`) and `theme`. `CopyableTextConfig` has `id`, `frame`,
`text`, `copied`, `supported`, `monospace`, `enabled`, `tooltip`,
`accessibility_label`, `size` and `theme`.

```v
@[heap]
struct App {
mut:
	clips ui2.ClipboardFeedback
	notes ui2.NotificationList
}

const app = &App{}
const clipboard_ok = ui2.clipboard_supported() // Cache it: on Linux and the BSDs it searches PATH.

fn build() ui2.Element {
	state := unsafe { app }
	return ui2.screen(0xffffff, [
		ui2.copyable_text(
			id:                  'api-key'
			frame:               ui2.rect(20, 20, 300, 36)
			text:                'sk-1234567890abcdef'
			monospace:           true
			copied:              state.clips.copied('api-key')
			supported:           clipboard_ok
			accessibility_label: 'Copy API key'
		) or { panic(err) },
	])
}

fn on_event(event string) {
	mut state := unsafe { app }
	if state.clips.copy_from_action('api-key', 'sk-1234567890abcdef', event) {
		// GPUI Kit's on_copied: here, a notification.
		state.notes.schedule('toasts', state.notes.push(kind: .success, message: 'API key copied'))
		ui2.refresh()
	}
}
```

### Implemented and omitted

| GPUI Kit feature | ui2 |
| --- | --- |
| Copy icon, check icon after copying, for 2 s | Implemented through `ClipboardFeedback`; `copied` is controlled |
| `value` and `value_fn` | The value is passed when the action is handled, so it is always current |
| `on_copied` | `copy_from_action` returns true; react in `on_event` |
| Localized "Copy" accessible name, `accessibility_label` | Implemented (English default) |
| `tooltip` | Implemented; `tooltip_show_delay` omitted (the backend owns the delay) |
| Sizes | `ComponentSize`, default `.small` (GPUI Kit's default is XSmall) |
| Clicking while copied does nothing | Copying again re-copies and restarts the feedback, so a value that changed can be copied without waiting |
| Label beside the icon, input suffix (documented compositions) | `label` variant and `copyable_text` |
| Platforms without a clipboard | `supported: false` disables the button with a tooltip, or `hide_unsupported` hides it |

The check icon uses the SF Symbol `checkmark` when every renderer has it and
the `✓` character until then; the copy icon is `doc.on.doc`.
