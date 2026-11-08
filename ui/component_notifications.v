module ui2

import math
import time

// Toast notifications after GPUI Kit's Notification and NotificationList. The
// application owns a NotificationList and changes it from on_event; every change
// returns the timers it needs (auto-hide, enter and exit transitions) as data,
// so the model stays deterministic and testable, and schedule() turns them into
// `after`/`cancel_timer` calls. notification_stacks (component_notifications_view.v)
// draws the list.

// notification_default_duration is how long, in seconds, a notification stays
// before it hides itself (GPUI Kit's five seconds).
pub const notification_default_duration = 5.0

// notification_enter_duration and notification_exit_duration are the default
// lengths, in seconds, of the slide in and the slide out.
pub const notification_enter_duration = 0.4
pub const notification_exit_duration = 0.2

// NotificationKind picks the icon and its color, like GPUI Kit's NotificationType.
// A plain notification has no icon unless Notification.icon names one.
pub enum NotificationKind {
	plain
	info
	success
	warning
	error
}

// NotificationPlacement is where a stack of notifications sits in the frame
// notification_stacks is given. Each placement in use gets its own stack.
// A notification with `.inherit` uses NotificationList.placement.
pub enum NotificationPlacement {
	inherit
	top_left
	top_center
	top_right
	left_center
	right_center
	bottom_left
	bottom_center
	bottom_right
}

const notification_placements = [NotificationPlacement.top_left, .top_center, .top_right, .left_center,
	.right_center, .bottom_left, .bottom_center, .bottom_right]

fn notification_placement_from_name(name string) ?NotificationPlacement {
	for placement in notification_placements {
		if placement.str() == name {
			return placement
		}
	}
	return none
}

// notification_anchored_bottom reports whether a stack grows up from the bottom
// edge, with the newest notification lowest.
fn notification_anchored_bottom(placement NotificationPlacement) bool {
	return placement in [.bottom_left, .bottom_center, .bottom_right]
}

// Notification is one message to push. Only message (or title) is required.
pub struct Notification {
pub:
	// key makes a notification unique: pushing a key that is already in the list
	// replaces that notification, and dismiss_key removes it. Empty keys never match.
	key     string
	kind    NotificationKind
	title   string
	message string
	// icon is an SF Symbol name (see symbol_known) drawn instead of the kind's icon.
	icon string
	// action is the title of a button beside the text; the decoder reports its
	// clicks as `.action`. Like GPUI Kit, a notification with an action does not
	// hide itself unless autohide says so.
	action string
	// clickable makes the whole notification a button reporting `.click`.
	clickable bool
	// autohide defaults to true without an action and false with one.
	autohide ?bool
	// duration is the auto-hide delay in seconds; zero or less means
	// notification_default_duration.
	duration  f64
	placement NotificationPlacement
	// content is drawn below the message, in a box content_height tall and as wide
	// as the text; child frames are relative to that box.
	content        []Element
	content_height f64
}

// autohides reports whether the notification hides itself after its duration.
pub fn (n Notification) autohides() bool {
	if value := n.autohide {
		return value
	}
	return n.action.len == 0
}

fn (n Notification) duration_ms() i64 {
	seconds := if component_finite(n.duration) && n.duration > 0 {
		n.duration
	} else {
		notification_default_duration
	}
	return i64(math.ceil(seconds * 1000))
}

// NotificationPhase follows GPUI Kit's toast transition status: a notification
// slides in (entering), stays (present), and slides out before it is dropped
// (leaving). Only a present notification counts down.
pub enum NotificationPhase {
	entering
	present
	leaving
}

// NotificationEntry is a notification as the list holds it.
pub struct NotificationEntry {
pub:
	seq          int // Unique for the life of the list; it names the entry in actions.
	notification Notification
	placement    NotificationPlacement // Resolved; never `.inherit`.
	phase        NotificationPhase
}

pub enum NotificationTimerKind {
	enter  // The slide in is over: start counting down.
	expire // The countdown ran out: start the slide out.
	remove // The slide out is over: drop the entry.
}

pub enum NotificationTimerOp {
	start   // Call fire(timer) once `seconds` have passed.
	cancel  // Call off the timer started for `token`.
	release // The entry is gone: release the animation state of its elements.
}

// NotificationTimer is a request a list change makes of the application. schedule()
// carries them out; an application with its own timer handling can instead start
// and cancel timers itself and pass each due one back to fire().
pub struct NotificationTimer {
pub:
	op      NotificationTimerOp
	kind    NotificationTimerKind
	seq     int
	token   u64
	seconds f64
}

// NotificationClock returns milliseconds from any fixed origin; tests pass a fake one.
pub type NotificationClock = fn () i64

struct NotificationItem {
mut:
	seq       int
	note      Notification
	placement NotificationPlacement
	phase     NotificationPhase
	remaining i64 // Countdown left, in milliseconds, as of the last start or pause.
	started   i64 = -1 // Clock reading when the running countdown started; -1 when stopped.
	token     u64 // The pending timer, 0 when there is none.
	timer     NotificationTimerKind
}

// NotificationList is the application-owned list of notifications, oldest first.
// Keep it in heap-allocated application state: schedule() hands its address to
// the timers it starts. Change its notifications only through its methods, and
// pass every []NotificationTimer they return to schedule(). The settings may
// change at any time; placement applies to notifications pushed afterwards.
pub struct NotificationList {
pub mut:
	// placement is where notifications that inherit theirs go.
	placement NotificationPlacement = .top_right
	// max_visible is how many of the newest notifications are shown; older ones
	// wait their turn, still counting down, as in GPUI Kit.
	max_visible int = 10
	// enter_duration and exit_duration are the seconds a notification takes to
	// slide in and out. Zero shows it at once, or drops it at once.
	enter_duration f64 = notification_enter_duration
	exit_duration  f64 = notification_exit_duration
	// clock returns milliseconds; it defaults to time.ticks().
	clock NotificationClock = unsafe { nil }
mut:
	items      []NotificationItem
	next_seq   int = 1
	next_token u64 = 1
	hovered    []NotificationPlacement
	timer_ids  map[u64]TimerId
}

fn (list &NotificationList) now() i64 {
	if voidptr(list.clock) != unsafe { nil } {
		return list.clock()
	}
	return time.ticks()
}

fn (list &NotificationList) resolve(placement NotificationPlacement) NotificationPlacement {
	if placement != .inherit {
		return placement
	}
	return if list.placement == .inherit { .top_right } else { list.placement }
}

fn (list &NotificationList) index_of(seq int) int {
	for index, item in list.items {
		if item.seq == seq {
			return index
		}
	}
	return -1
}

fn notification_seconds(seconds f64) f64 {
	return if component_finite(seconds) && seconds > 0 { seconds } else { 0.0 }
}

fn (item NotificationItem) entry() NotificationEntry {
	return NotificationEntry{
		seq:          item.seq
		notification: item.note
		placement:    item.placement
		phase:        item.phase
	}
}

// len counts every notification in the list, including hidden and leaving ones.
pub fn (list &NotificationList) len() int {
	return list.items.len
}

// entries lists every notification, oldest first.
pub fn (list &NotificationList) entries() []NotificationEntry {
	return list.items.map(it.entry())
}

// visible lists what notification_stacks draws, oldest first: the newest
// max_visible notifications that are not leaving, plus every leaving one so it
// can finish sliding out (GPUI Kit's ToastManager::visible).
pub fn (list &NotificationList) visible() []NotificationEntry {
	limit := if list.max_visible < 1 { 1 } else { list.max_visible }
	mut active := 0
	for item in list.items {
		if item.phase != .leaving {
			active++
		}
	}
	skip := math.max(active - limit, 0)
	mut seen := 0
	mut entries := []NotificationEntry{}
	for item in list.items {
		if item.phase == .leaving {
			entries << item.entry()
			continue
		}
		if seen >= skip {
			entries << item.entry()
		}
		seen++
	}
	return entries
}

// find returns the notification pushed with key, if it is still in the list.
pub fn (list &NotificationList) find(key string) ?NotificationEntry {
	if key.len == 0 {
		return none
	}
	for item in list.items {
		if item.note.key == key {
			return item.entry()
		}
	}
	return none
}

// is_paused reports whether countdowns are stopped because a stack is hovered.
pub fn (list &NotificationList) is_paused() bool {
	return list.hovered.len > 0
}

// remaining is how many seconds the notification seq has left before it hides
// itself, or none when it does not count down.
pub fn (list &NotificationList) remaining(seq int) ?f64 {
	index := list.index_of(seq)
	if index < 0 || !list.items[index].note.autohides() || list.items[index].phase == .leaving {
		return none
	}
	item := list.items[index]
	mut left := item.remaining
	if item.started >= 0 {
		left -= math.max(list.now() - item.started, 0)
	}
	return f64(math.max(left, 0)) / 1000.0
}

fn (mut list NotificationList) start_timer(index int, kind NotificationTimerKind, seconds f64) NotificationTimer {
	token := list.next_token
	list.next_token++
	list.items[index].token = token
	list.items[index].timer = kind
	return NotificationTimer{
		op:      .start
		kind:    kind
		seq:     list.items[index].seq
		token:   token
		seconds: notification_seconds(seconds)
	}
}

fn (mut list NotificationList) stop_timer(index int) []NotificationTimer {
	token := list.items[index].token
	if token == 0 {
		return []NotificationTimer{}
	}
	list.items[index].token = 0
	return [
		NotificationTimer{
			op:    .cancel
			kind:  list.items[index].timer
			seq:   list.items[index].seq
			token: token
		},
	]
}

fn (mut list NotificationList) start_countdown(index int, now i64) []NotificationTimer {
	item := list.items[index]
	if item.phase != .present || !item.note.autohides() || item.started >= 0
		|| list.hovered.len > 0 {
		return []NotificationTimer{}
	}
	list.items[index].started = now
	return [list.start_timer(index, .expire, f64(item.remaining) / 1000.0)]
}

fn (mut list NotificationList) stop_countdown(index int, now i64) []NotificationTimer {
	item := list.items[index]
	if item.started < 0 {
		return []NotificationTimer{}
	}
	list.items[index].remaining = math.max(item.remaining - math.max(now - item.started, 0), 0)
	list.items[index].started = -1
	return list.stop_timer(index)
}

fn (mut list NotificationList) begin_leaving(index int) []NotificationTimer {
	mut timers := list.stop_timer(index)
	list.items[index].started = -1
	list.items[index].phase = .leaving
	if notification_seconds(list.exit_duration) > 0 {
		timers << list.start_timer(index, .remove, list.exit_duration)
		return timers
	}
	timers << list.remove_at(index)
	return timers
}

fn (mut list NotificationList) remove_at(index int) []NotificationTimer {
	mut timers := list.stop_timer(index)
	removed := list.items[index]
	list.items.delete(index)
	timers << NotificationTimer{
		op:  .release
		seq: removed.seq
	}
	timers << list.release_hover(removed.placement)
	return timers
}

// release_hover forgets the hover of a stack that has gone, whether or not the
// backend reports the pointer leaving an element that no longer exists.
fn (mut list NotificationList) release_hover(placement NotificationPlacement) []NotificationTimer {
	if placement !in list.hovered || list.items.any(it.placement == placement) {
		return []NotificationTimer{}
	}
	return list.resume(placement)
}

// push adds a notification as the newest, replacing one with the same key.
pub fn (mut list NotificationList) push(n Notification) []NotificationTimer {
	mut timers := []NotificationTimer{}
	mut replaced := NotificationPlacement.inherit
	if n.key.len > 0 {
		for index, item in list.items {
			if item.note.key == n.key {
				// Its stack keeps its hover until the replacement has joined it.
				replaced = item.placement
				timers << list.stop_timer(index)
				timers << NotificationTimer{
					op:  .release
					seq: item.seq
				}
				list.items.delete(index)
				break
			}
		}
	}
	seq := list.next_seq
	list.next_seq++
	entering := notification_seconds(list.enter_duration) > 0
	list.items << NotificationItem{
		seq:       seq
		note:      n
		placement: list.resolve(n.placement)
		phase:     if entering { .entering } else { .present }
		remaining: n.duration_ms()
	}
	index := list.items.len - 1
	if entering {
		timers << list.start_timer(index, .enter, list.enter_duration)
	} else {
		timers << list.start_countdown(index, list.now())
	}
	if replaced != .inherit {
		timers << list.release_hover(replaced)
	}
	return timers
}

// dismiss starts the slide out of notification seq, as its close button does.
pub fn (mut list NotificationList) dismiss(seq int) []NotificationTimer {
	index := list.index_of(seq)
	if index < 0 || list.items[index].phase == .leaving {
		return []NotificationTimer{}
	}
	return list.begin_leaving(index)
}

// dismiss_key dismisses the notification pushed with key (GPUI Kit's
// remove_notification), if it is in the list.
pub fn (mut list NotificationList) dismiss_key(key string) []NotificationTimer {
	entry := list.find(key) or { return []NotificationTimer{} }
	return list.dismiss(entry.seq)
}

// clear dismisses every notification (GPUI Kit's clear_notifications).
pub fn (mut list NotificationList) clear() []NotificationTimer {
	mut timers := []NotificationTimer{}
	for seq in list.items.filter(it.phase != .leaving).map(it.seq) {
		timers << list.dismiss(seq)
	}
	return timers
}

// pause stops every countdown while the stack at placement is hovered, as GPUI
// Kit does while the pointer is over its notifications. Each countdown keeps
// the time it had left.
pub fn (mut list NotificationList) pause(placement NotificationPlacement) []NotificationTimer {
	target := list.resolve(placement)
	if target in list.hovered {
		return []NotificationTimer{}
	}
	list.hovered << target
	if list.hovered.len > 1 {
		return []NotificationTimer{}
	}
	now := list.now()
	mut timers := []NotificationTimer{}
	for index in 0 .. list.items.len {
		timers << list.stop_countdown(index, now)
	}
	return timers
}

// resume undoes pause for placement; countdowns restart once no stack is hovered.
pub fn (mut list NotificationList) resume(placement NotificationPlacement) []NotificationTimer {
	target := list.resolve(placement)
	if target !in list.hovered {
		return []NotificationTimer{}
	}
	list.hovered = list.hovered.filter(it != target)
	if list.hovered.len > 0 {
		return []NotificationTimer{}
	}
	now := list.now()
	mut timers := []NotificationTimer{}
	for index in 0 .. list.items.len {
		timers << list.start_countdown(index, now)
	}
	return timers
}

// settle ends every slide in at once, as if its timer had fired. Use it for
// notifications that were already on screen, such as ones restored with a window.
pub fn (mut list NotificationList) settle() []NotificationTimer {
	now := list.now()
	mut timers := []NotificationTimer{}
	for index in 0 .. list.items.len {
		if list.items[index].phase == .entering {
			timers << list.stop_timer(index)
			list.items[index].phase = .present
			timers << list.start_countdown(index, now)
		}
	}
	return timers
}

// fire advances the notification a due timer belongs to. A timer that was
// cancelled, replaced or already handled changes nothing.
pub fn (mut list NotificationList) fire(timer NotificationTimer) []NotificationTimer {
	if timer.op != .start || timer.token == 0 {
		return []NotificationTimer{}
	}
	index := list.index_of(timer.seq)
	if index < 0 || list.items[index].token != timer.token || list.items[index].timer != timer.kind {
		return []NotificationTimer{}
	}
	list.items[index].token = 0
	phase := list.items[index].phase
	match timer.kind {
		.enter {
			if phase == .entering {
				list.items[index].phase = .present
				return list.start_countdown(index, list.now())
			}
		}
		.expire {
			if phase == .present {
				list.items[index].remaining = 0
				list.items[index].started = -1
				return list.begin_leaving(index)
			}
		}
		.remove {
			if phase == .leaving {
				return list.remove_at(index)
			}
		}
	}
	return []NotificationTimer{}
}

// schedule carries out timer requests: it starts each `.start` timer with
// `after` and feeds it back to fire() when due, cancels `.cancel` ones, and
// releases the animation state of entries that are gone. id is the one passed
// to notification_stacks. Call it from on_event, never from a build.
pub fn (mut list NotificationList) schedule(id string, timers []NotificationTimer) {
	for timer in timers {
		match timer.op {
			.start {
				list.timer_ids[timer.token] = after(timer.seconds, fn [mut list, id, timer] () {
					list.timer_ids.delete(timer.token)
					list.schedule(id, list.fire(timer))
				})
			}
			.cancel {
				if timer_id := list.timer_ids[timer.token] {
					cancel_timer(timer_id)
					list.timer_ids.delete(timer.token)
				}
			}
			.release {
				clear_animation(notification_slot_id(id, timer.seq))
				clear_animation(notification_card_id(id, timer.seq))
			}
		}
	}
}

// pending_timers counts the timers schedule() has started that have not run.
pub fn (list &NotificationList) pending_timers() int {
	return list.timer_ids.len
}

pub enum NotificationEventKind {
	close       // The close button.
	action      // The action button.
	click       // The body of a clickable notification.
	hover_start // The pointer came over a stack.
	hover_end   // The pointer left a stack.
}

// NotificationEvent is a decoded notification action.
pub struct NotificationEvent {
pub:
	kind      NotificationEventKind
	seq       int    // The notification, for close, action and click.
	key       string // Its key, if it was pushed with one.
	placement NotificationPlacement
}

fn notification_slot_id(id string, seq int) string {
	return component_part_id(id, 'toast:${seq}')
}

fn notification_card_id(id string, seq int) string {
	return component_part_id(id, 'toast:${seq}:card')
}

fn notification_stack_id(id string, placement NotificationPlacement) string {
	return component_part_id(id, 'stack:${placement}')
}

// notification_action_id is the action a part of notification seq emits; part is
// `close`, `action` or `click`.
pub fn notification_action_id(id string, seq int, part string) string {
	return component_part_id(id, 'toast:${seq}:${part}')
}

// notification_event_from_action decodes an action (or pointer event) from
// notification_stacks against the list it was built from. It rejects foreign and
// malformed actions, notifications that are gone, hidden or already leaving,
// parts a notification does not have, and hover changes that change nothing.
pub fn notification_event_from_action(id string, list NotificationList, action string) ?NotificationEvent {
	if pointer := parse_pointer_event(action) {
		if pointer.phase != 'enter' && pointer.phase != 'leave' {
			return none
		}
		part := component_action_part(id, pointer.action) or { return none }
		if !part.starts_with('stack:') {
			return none
		}
		placement := notification_placement_from_name(part['stack:'.len..]) or { return none }
		entering := pointer.phase == 'enter'
		if entering == (placement in list.hovered) {
			return none
		}
		return NotificationEvent{
			kind:      if entering { .hover_start } else { .hover_end }
			placement: placement
		}
	}
	part := component_action_part(id, action) or { return none }
	if !part.starts_with('toast:') {
		return none
	}
	rest := part['toast:'.len..]
	separator_at := rest.index(':') or { return none }
	seq := component_parse_index(rest[..separator_at], list.next_seq - 1) or { return none }
	kind := match rest[separator_at + 1..] {
		'close' { NotificationEventKind.close }
		'action' { NotificationEventKind.action }
		'click' { NotificationEventKind.click }
		else { return none }
	}
	for entry in list.visible() {
		if entry.seq != seq {
			continue
		}
		if entry.phase == .leaving || (kind == .action && entry.notification.action.len == 0)
			|| (kind == .click && !entry.notification.clickable) {
			return none
		}
		return NotificationEvent{
			kind:      kind
			seq:       seq
			key:       entry.notification.key
			placement: entry.placement
		}
	}
	return none
}

// respond applies what GPUI Kit does by itself: close, action and click dismiss
// the notification, and hovering a stack pauses every countdown until it ends.
// Handle `.action` and `.click` first when they should do more; skip respond
// for an action that should keep its notification open.
pub fn (mut list NotificationList) respond(event NotificationEvent) []NotificationTimer {
	return match event.kind {
		.close, .action, .click { list.dismiss(event.seq) }
		.hover_start { list.pause(event.placement) }
		.hover_end { list.resume(event.placement) }
	}
}
