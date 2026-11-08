module ui2

import math
import time

@[heap]
struct NotificationTestClock {
mut:
	ms i64
}

fn notification_test_list(clock &NotificationTestClock, max_visible int) NotificationList {
	return NotificationList{
		max_visible: max_visible
		clock:       fn [clock] () i64 {
			return clock.ms
		}
	}
}

fn notification_starts(timers []NotificationTimer) []NotificationTimer {
	return timers.filter(it.op == .start)
}

fn notification_only_start(timers []NotificationTimer, kind NotificationTimerKind) NotificationTimer {
	starts := notification_starts(timers)
	assert starts.len == 1, 'expected one start timer, got ${timers}'
	assert starts[0].kind == kind
	return starts[0]
}

// notification_present pushes n and runs its enter timer, returning the expire
// timer it asks for, if any.
fn notification_present(mut list NotificationList, n Notification) []NotificationTimer {
	enter := notification_only_start(list.push(n), .enter)
	return list.fire(enter)
}

fn test_notification_push_orders_oldest_first_and_replaces_by_key() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	list.push(Notification{ message: 'one' })
	list.push(Notification{ key: 'upload', message: 'uploading' })
	list.push(Notification{ message: 'three' })
	assert list.entries().map(it.notification.message) == ['one', 'uploading', 'three']
	assert list.entries().map(it.seq) == [1, 2, 3]
	assert list.entries().all(it.phase == .entering && it.placement == .top_right)
	replaced := list.push(Notification{ key: 'upload', kind: .success, message: 'uploaded' })
	assert list.entries().map(it.notification.message) == ['one', 'three', 'uploaded']
	assert list.entries().last().seq == 4
	// The old entry's timer is called off and its elements released.
	assert replaced.any(it.op == .cancel && it.seq == 2 && it.kind == .enter)
	assert replaced.any(it.op == .release && it.seq == 2)
	assert notification_only_start(replaced, .enter).seq == 4
	found := list.find('upload') or { panic('keyed notification missing') }
	assert found.seq == 4
	assert found.notification.kind == .success
	if _ := list.find('') {
		assert false, 'an empty key matched'
	}
}

fn test_notification_visible_keeps_the_newest_and_every_leaving_one() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 2)
	for i in 1 .. 5 {
		list.push(Notification{ message: '${i}' })
	}
	assert list.visible().map(it.seq) == [3, 4]
	list.dismiss(4)
	// The leaving notification stays to slide out; the next newest takes its place.
	assert list.visible().map(it.seq) == [2, 3, 4]
	assert list.visible().last().phase == .leaving
	zero := NotificationList{
		max_visible: 0
	}
	assert zero.visible().len == 0
	mut one := NotificationList{
		max_visible: 0
	}
	one.push(Notification{ message: 'a' })
	one.push(Notification{ message: 'b' })
	assert one.visible().map(it.seq) == [2]
}

fn test_notification_lifecycle_runs_enter_expire_and_remove_timers() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	enter := notification_only_start(list.push(Notification{ message: 'saved', duration: 3 }),
		.enter)
	assert enter.seconds == notification_enter_duration
	expire := notification_only_start(list.fire(enter), .expire)
	assert expire.seconds == 3
	assert list.entries()[0].phase == .present
	// A timer that already ran is ignored.
	assert list.fire(enter).len == 0
	remove := notification_only_start(list.fire(expire), .remove)
	assert remove.seconds == notification_exit_duration
	assert list.entries()[0].phase == .leaving
	done := list.fire(remove)
	assert done.any(it.op == .release && it.seq == 1)
	assert list.len() == 0
	assert list.fire(remove).len == 0
}

fn test_notification_autohide_defaults_follow_the_action() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	assert Notification{}.autohides()
	assert !Notification{
		action: 'Retry'
	}.autohides()
	assert Notification{
		action:   'Retry'
		autohide: true
	}.autohides()
	assert notification_present(mut list, Notification{ action: 'Retry' }).len == 0
	assert notification_present(mut list, Notification{ autohide: false }).len == 0
	timers := notification_present(mut list, Notification{ action: 'Undo', autohide: true })
	assert notification_only_start(timers, .expire).seconds == notification_default_duration
	if _ := list.remaining(1) {
		assert false, 'a persistent notification counts down'
	}
	for duration in [0.0, -2, math.nan(), math.inf(1)] {
		assert Notification{
			duration: duration
		}.duration_ms() == 5000
	}
}

fn test_notification_pause_keeps_the_time_left_and_resume_restarts_it() {
	mut clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	expire := notification_only_start(notification_present(mut list, Notification{ message: 'a' }),
		.expire)
	clock.ms = 2000
	paused := list.pause(.top_right)
	assert paused.len == 1
	assert paused[0].op == .cancel && paused[0].token == expire.token
	assert list.is_paused()
	assert list.fire(expire).len == 0, 'a cancelled countdown fired'
	clock.ms = 60000
	left := list.remaining(1) or { panic('no countdown') }
	assert left == 3
	// Hovering another stack keeps everything paused until both are left.
	assert list.pause(.bottom_left).len == 0
	assert list.pause(.top_right).len == 0
	assert list.resume(.top_right).len == 0
	resumed := list.resume(.bottom_left)
	restarted := notification_only_start(resumed, .expire)
	assert restarted.seconds == 3
	assert restarted.token != expire.token
	assert list.resume(.bottom_left).len == 0
	assert !list.is_paused()
	clock.ms = 61000
	assert list.remaining(1) or { 0 } == 2
}

fn test_notification_pushed_while_paused_waits_to_count_down() {
	mut clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	list.pause(.inherit)
	assert list.is_paused()
	assert notification_present(mut list, Notification{ message: 'later' }).len == 0
	clock.ms = 9000
	assert list.remaining(1) or { 0 } == notification_default_duration
	assert notification_only_start(list.resume(.top_right), .expire).seconds == notification_default_duration
}

fn test_notification_removing_a_hovered_stack_resumes_the_rest() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	notification_present(mut list, Notification{ message: 'top' })
	notification_present(mut list, Notification{ message: 'bottom', placement: .bottom_left })
	list.pause(.bottom_left)
	remove := notification_only_start(list.dismiss(2), .remove)
	timers := list.fire(remove)
	assert !list.is_paused()
	assert timers.any(it.op == .release && it.seq == 2)
	assert notification_only_start(timers, .expire).seq == 1
}

fn test_notification_replacing_keeps_a_hovered_stack_paused() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	notification_present(mut list, Notification{ key: 'upload', message: 'Uploading' })
	list.pause(.top_right)
	timers := list.push(Notification{ key: 'upload', message: 'Uploaded' })
	assert list.is_paused(), 'replacing the only notification resumed a hovered stack'
	assert timers.any(it.op == .release && it.seq == 1)
	// Moving it to another placement leaves the hovered stack empty.
	moved := list.push(Notification{ key: 'upload', message: 'Moved', placement: .bottom_left })
	assert !list.is_paused()
	assert moved.any(it.op == .release && it.seq == 2)
}

fn test_notification_dismiss_clear_and_zero_durations() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	list.push(Notification{ key: 'a' })
	list.push(Notification{ key: 'b' })
	list.push(Notification{ key: 'c' })
	dismissed := list.dismiss_key('b')
	assert dismissed.any(it.op == .cancel && it.kind == .enter && it.seq == 2)
	assert notification_only_start(dismissed, .remove).seq == 2
	assert list.dismiss(2).len == 0, 'dismissed twice'
	assert list.dismiss_key('missing').len == 0
	assert list.dismiss(99).len == 0
	cleared := list.clear()
	assert notification_starts(cleared).map(it.seq) == [1, 3]
	assert list.entries().all(it.phase == .leaving)

	mut instant := NotificationList{
		enter_duration: 0
		exit_duration:  0
		clock:          fn () i64 {
			return 0
		}
	}
	timers := instant.push(Notification{ message: 'now' })
	assert instant.entries()[0].phase == .present
	assert notification_only_start(timers, .expire).seq == 1
	gone := instant.dismiss(1)
	assert gone.any(it.op == .cancel && it.kind == .expire)
	assert gone.any(it.op == .release)
	assert instant.len() == 0
}

fn test_notification_settle_shows_entering_notifications_at_once() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	enter := notification_only_start(list.push(Notification{ message: 'restored' }), .enter)
	list.push(Notification{ message: 'pinned', autohide: false })
	timers := list.settle()
	assert timers.filter(it.op == .cancel).len == 2
	assert notification_only_start(timers, .expire).seq == 1
	assert list.entries().all(it.phase == .present)
	assert list.fire(enter).len == 0
	assert list.settle().len == 0
}

fn test_notification_decoder_accepts_shown_parts_and_rejects_the_rest() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 2)
	list.push(Notification{ key: 'hidden', message: 'old' })
	list.push(Notification{ key: 'retry', message: 'Lost', action: 'Retry' })
	list.push(Notification{ message: 'Open', clickable: true, placement: .bottom_center })
	close := notification_event_from_action('toasts', list, notification_action_id('toasts', 2, 'close')) or {
		panic('close rejected')
	}
	assert close.kind == .close && close.seq == 2 && close.key == 'retry'
	assert close.placement == .top_right
	action := notification_event_from_action('toasts', list, notification_action_id('toasts', 2, 'action')) or {
		panic('action rejected')
	}
	assert action.kind == .action
	click := notification_event_from_action('toasts', list, 'toasts:component:toast:3:click') or {
		panic('click rejected')
	}
	assert click.kind == .click && click.placement == .bottom_center
	for forged in [
		'toasts:component:toast:1:close', // hidden past max_visible
		'toasts:component:toast:3:action', // has no action
		'toasts:component:toast:2:click', // not clickable
		'toasts:component:toast:4:close', // never pushed
		'toasts:component:toast:02:close',
		'toasts:component:toast:-2:close',
		'toasts:component:toast:2:',
		'toasts:component:toast:2',
		'toasts:component:toast:99999999999999999999:close',
		'toasts:component:toast:2:close:extra',
		'other:component:toast:2:close',
		'toasts:component:stack:top_right',
		'toasts',
		'',
	] {
		if event := notification_event_from_action('toasts', list, forged) {
			assert false, '${forged} decoded to ${event}'
		}
	}
	list.respond(close)
	if _ := notification_event_from_action('toasts', list, notification_action_id('toasts', 2, 'action')) {
		assert false, 'a leaving notification accepted its action'
	}
}

fn test_notification_decoder_reads_stack_hover() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	notification_present(mut list, Notification{ message: 'a' })
	stack := notification_stack_id('toasts', .top_right)
	enter := notification_event_from_action('toasts', list, 'pointer:enter:${stack}:10:20') or {
		panic('hover rejected')
	}
	assert enter.kind == .hover_start && enter.placement == .top_right
	if _ := notification_event_from_action('toasts', list, 'pointer:leave:${stack}:10:20') {
		assert false, 'leaving a stack that was never entered'
	}
	assert list.respond(enter).any(it.op == .cancel)
	if _ := notification_event_from_action('toasts', list, 'pointer:enter:${stack}:10:20') {
		assert false, 'entered twice'
	}
	for forged in ['pointer:down:${stack}:1:2', 'pointer:enter:toasts:component:stack:middle:1:2',
		'pointer:enter:other:component:stack:top_right:1:2', 'pointer:enter:${stack}:x:2'] {
		if event := notification_event_from_action('toasts', list, forged) {
			assert false, '${forged} decoded to ${event}'
		}
	}
	leave := notification_event_from_action('toasts', list, 'pointer:leave:${stack}:0:0') or {
		panic('leave rejected')
	}
	assert leave.kind == .hover_end
	assert notification_only_start(list.respond(leave), .expire).seq == 1
}

fn test_notification_line_count_wraps_words_and_long_runs() {
	assert notification_line_count('', 14, false, 100) == 0
	assert notification_line_count('   ', 14, false, 100) == 0
	assert notification_line_count('Saved', 14, false, 300) == 1
	assert notification_line_count('one\ntwo', 14, false, 300) == 2
	words := 'The quick brown fox jumps over the lazy dog again and again'
	assert notification_line_count(words, 14, false, 120) > 2
	assert notification_line_count('x'.repeat(40), 10, false, 60) == 4
	// Narrow letters estimate narrower than wide ones, and bold wider still.
	assert notification_text_width('illicit', 14, false) < notification_text_width('MWMWMWM', 14, false)
	assert notification_text_width('Saved', 14, true) > notification_text_width('Saved', 14, false)
	assert notification_text_width('漢字', 10, false) == 20
}

fn test_notification_card_layout_places_icon_text_action_and_close() {
	plain := notification_card_layout(Notification{ message: 'Saved' }, 382, .medium)
	with_icon := notification_card_layout(Notification{ kind: .info, title: 'Update', message: 'Ready' },
		382, .medium)
	assert with_icon.title.x > plain.message.x
	assert with_icon.height > plain.height
	assert with_icon.message.y == with_icon.title.y + with_icon.title.height
	assert with_icon.close.x + with_icon.close.width < 382
	assert with_icon.title.x + with_icon.title.width <= with_icon.close.x
	actionable := notification_card_layout(Notification{ message: 'Lost', action: 'Retry' },
		382, .medium)
	assert actionable.action.width > 0
	assert actionable.message.x + actionable.message.width < actionable.action.x
	assert actionable.action.x + actionable.action.width <= actionable.close.x
	long := notification_card_layout(Notification{ message: 'word '.repeat(60) }, 382, .medium)
	assert long.height > plain.height * 2
	content := notification_card_layout(Notification{
		message:        'Results'
		content:        [view('', rect(0, 0, 10, 10), BoxStyle{}, [])]
		content_height: 40
	}, 382, .medium)
	assert content.content.height == 40
	assert content.content.y > content.message.y
}

fn notification_test_stacks(list NotificationList) []Element {
	return notification_stacks(
		id:      'toasts'
		frame:   rect(0, 0, 800, 600)
		list:    list
		animate: false
	) or { panic(err) }
}

fn test_notification_stacks_place_one_stack_per_placement() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	assert notification_test_stacks(list).len == 0
	list.push(Notification{ kind: .info, message: 'first' })
	list.push(Notification{ kind: .error, message: 'second' })
	list.push(Notification{ message: 'below', placement: .bottom_left })
	stacks := notification_test_stacks(list)
	assert stacks.len == 2
	top := stacks[0]
	assert top.id == 'toasts:component:stack:top_right'
	assert top.hoverable
	assert top.frame.x == 800 - 16 - notification_default_width
	assert top.frame.y == 16
	// Newest first at the top edge.
	assert top.children.map(it.key) == ['toast:2', 'toast:1']
	assert top.children[1].frame.y == top.children[0].frame.height + 12
	assert top.children[0].children[0].accessibility_role == 'alert'
	assert top.children[1].children[0].accessibility_role == 'status'
	bottom := stacks[1]
	assert bottom.frame.x == 16
	assert bottom.frame.y + bottom.frame.height == 600 - 16
	narrow := notification_stacks(id: 'toasts', frame: rect(10, 20, 200, 300), list: list) or {
		panic(err)
	}
	assert narrow[0].frame.width == 200 - 32
	assert narrow[0].frame.x == 10 + 16
	for bad in [
		NotificationStackConfig{
			frame: rect(0, 0, 10, 10)
			list:  list
		},
		NotificationStackConfig{
			id:     'toasts'
			list:   list
			margin: -1
		},
		NotificationStackConfig{
			id:    'toasts'
			list:  list
			width: math.nan()
		},
		NotificationStackConfig{
			id:    'toasts'
			list:  list
			frame: rect(0, 0, -1, 10)
		},
	] {
		if _ := notification_stacks(bad) {
			assert false, 'invalid stack config accepted'
		}
	}
}

fn test_notification_stacks_center_placements() {
	clock := &NotificationTestClock{}
	mut list := NotificationList{
		placement: .bottom_center
		clock:     fn [clock] () i64 {
			return clock.ms
		}
	}
	list.push(Notification{ message: 'a' })
	list.push(Notification{ message: 'b', placement: .right_center })
	stacks := notification_test_stacks(list)
	assert stacks.len == 2
	assert stacks[0].id.ends_with('stack:right_center')
	assert stacks[0].frame.y == (600 - stacks[0].frame.height) / 2
	assert stacks[1].id.ends_with('stack:bottom_center')
	assert stacks[1].frame.x == (800 - notification_default_width) / 2
}

fn notification_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := notification_find(child, id) {
			return found
		}
	}
	return none
}

fn test_notification_card_parts_carry_their_actions() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	list.push(Notification{ kind: .warning, title: 'Lost', message: 'Offline', action: 'Retry' })
	list.push(Notification{ message: 'Open', clickable: true, icon: 'folder' })
	stacks := notification_test_stacks(list)
	stack := stacks[0]
	close := notification_find(stack, notification_action_id('toasts', 1, 'close')) or {
		panic('no close button')
	}
	assert close.button_behavior
	assert close.accessibility_label == 'Dismiss notification'
	assert close.children[0].image_path == 'symbol:xmark'
	retry := notification_find(stack, notification_action_id('toasts', 1, 'action')) or {
		panic('no action button')
	}
	assert retry.kind == .button && retry.text == 'Retry'
	first := notification_find(stack, notification_card_id('toasts', 1)) or { panic('no card') }
	assert !first.button_behavior
	assert first.accessibility_label == 'Lost: Offline'
	clickable := notification_find(stack, notification_card_id('toasts', 2)) or { panic('no card') }
	assert clickable.button_behavior
	assert clickable.action_id == notification_action_id('toasts', 2, 'click')
	assert clickable.accessibility_role == 'button'
	assert clickable.children.any(it.image_path == 'symbol:folder')
}

fn test_notification_kind_icons_use_symbols_or_a_ring() {
	theme := component_theme(false)
	for kind in [NotificationKind.info, .success, .warning, .error] {
		icon := notification_icon(Notification{ kind: kind }, rect(0, 0, 16, 16), theme) or {
			panic('no icon for ${kind}')
		}
		name := notification_kind_symbol(kind)
		if notification_kind_symbols_known() {
			assert icon.image_path == 'symbol:${name}'
			assert icon.text_style.color == notification_kind_color(theme, kind)
		} else {
			glyph, _ := notification_kind_glyph(kind)
			assert icon.kind == .view
			assert icon.box.bg == notification_kind_color(theme, kind)
			assert icon.children.last().text == glyph
		}
	}
	if _ := notification_icon(Notification{}, rect(0, 0, 16, 16), theme) {
		assert false, 'a plain notification has an icon'
	}
}

fn test_notification_leaving_cards_hide_without_animation() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	list.push(Notification{ message: 'a' })
	list.push(Notification{ message: 'b' })
	list.dismiss(2)
	assert notification_test_stacks(list)[0].children.map(it.key) == ['toast:1']
}

fn test_notification_entering_block_starts_past_its_edge() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	notification_present(mut list, Notification{ message: 'old' })
	list.push(Notification{ message: 'new one' })
	list.push(Notification{ message: 'newest' })
	list.push(Notification{ message: 'below', placement: .bottom_right })
	config := NotificationStackConfig{
		id:    'toasts'
		frame: rect(0, 0, 800, 600)
		list:  list
	}
	layouts := notification_stack_layouts(config) or { panic(err) }
	top := layouts[0]
	// The two entering notifications are the newest, so they sit first; both
	// start above the window by the height of the pair.
	assert top.entries.map(it.phase) == [.entering, .entering, .present]
	in_x, in_y := notification_entering_offset(config, top)
	assert in_x == 0
	assert in_y == -(top.frame.y + top.slots[1].y + top.slots[1].height)
	bottom := layouts[1]
	_, below := notification_entering_offset(config, bottom)
	assert below == 600 - bottom.frame.y
	mut sideways := NotificationList{
		placement: .left_center
	}
	sideways.push(Notification{ message: 'side' })
	side_config := NotificationStackConfig{
		...config
		list: sideways
	}
	side := notification_stack_layouts(side_config) or { panic(err) }
	side_x, side_y := notification_entering_offset(side_config, side[0])
	assert side_x == -(16 + notification_default_width)
	assert side_y == 0
}

fn test_notification_stacks_start_enter_and_exit_motion() {
	clock := &NotificationTestClock{}
	mut list := notification_test_list(clock, 10)
	list.push(Notification{ message: 'animated' })
	card_id := notification_card_id('motion', 1)
	slot_id := notification_slot_id('motion', 1)
	defer {
		clear_animation(card_id)
		clear_animation(slot_id)
	}
	notification_stacks(id: 'motion', frame: rect(0, 0, 800, 600), list: list) or { panic(err) }
	entering := animation_info(card_id)
	assert entering.status == .running
	assert entering.animated_properties == ['y']
	list.dismiss(1)
	notification_stacks(id: 'motion', frame: rect(0, 0, 800, 600), list: list) or { panic(err) }
	leaving := animation_info(slot_id)
	assert leaving.status == .running
	assert leaving.animated_properties == ['x']
	mut released := NotificationList{}
	released.schedule('motion', [NotificationTimer{
		op:  .release
		seq: 1
	}])
	assert animation_info(card_id).status == .idle
	assert animation_info(slot_id).status == .idle
}

fn test_notification_schedule_runs_timers_through_after() {
	mut list := NotificationList{
		enter_duration: 0.01
		exit_duration:  0.01
	}
	list.schedule('sched', list.push(Notification{ message: 'a', duration: 0.01 }))
	assert list.pending_timers() == 1
	for _ in 0 .. 3 {
		run_due_timers(time.ticks() + 60_000)
	}
	assert list.len() == 0
	assert list.pending_timers() == 0
	list.schedule('sched', list.push(Notification{ message: 'b' }))
	list.schedule('sched', list.dismiss(2))
	assert list.pending_timers() == 1, 'the enter timer was not cancelled'
	run_due_timers(time.ticks() + 60_000)
	assert list.len() == 0
	assert list.pending_timers() == 0
}

fn test_clipboard_button_variants_and_states() {
	theme := component_theme(false)
	icon := clipboard_button(id: 'key', frame: rect(0, 0, 24, 24), theme: theme) or { panic(err) }
	assert icon.button_behavior
	assert icon.action_id == clipboard_action_id('key')
	assert icon.accessibility_label == 'Copy'
	assert icon.children.len == 1
	assert icon.children[0].image_path == 'symbol:doc.on.doc'
	copied := clipboard_button(id: 'key', frame: rect(0, 0, 24, 24), copied: true, theme: theme) or {
		panic(err)
	}
	assert copied.enabled, 'copied must not read as disabled'
	assert copied.accessibility_value == 'Copied'
	check := copied.children[0]
	assert check.image_path == 'symbol:checkmark' || check.text == '✓'
	assert check.text_style.color == theme.success
	labeled := clipboard_button(
		id:                  'url'
		frame:               rect(0, 0, 96, 28)
		label:               'Copy'
		copied:              true
		accessibility_label: 'Copy URL'
		theme:               theme
	) or { panic(err) }
	assert labeled.children.any(it.kind == .label && it.text == 'Copied')
	assert labeled.accessibility_label == 'Copy URL'
	unsupported := clipboard_button(id: 'key', frame: rect(0, 0, 24, 24), supported: false) or {
		panic(err)
	}
	assert !unsupported.enabled
	assert !unsupported.hidden
	assert unsupported.tooltip == 'Clipboard unavailable'
	hidden := clipboard_button(
		id:               'key'
		frame:            rect(0, 0, 24, 24)
		supported:        false
		hide_unsupported: true
	) or { panic(err) }
	assert hidden.hidden
	if _ := clipboard_button(frame: rect(0, 0, 24, 24)) {
		assert false, 'a copy button without an id'
	}
}

fn test_clipboard_action_matching_rejects_other_actions() {
	assert clipboard_is_copy_action('key', clipboard_action_id('key'))
	for action in ['key', 'key:component:copy:x', 'key:component:', 'other:component:copy',
		'key:component:button', ''] {
		assert !clipboard_is_copy_action('key', action), action
		assert !clipboard_copy_from_action('key', 'secret', action)
	}
	assert !clipboard_is_copy_action('', ':component:copy')
}

fn test_clipboard_feedback_expires_with_after() {
	mut feedback := &ClipboardFeedback{
		duration: 0.01
	}
	assert !feedback.copied('key')
	feedback.show('key')
	first := feedback.timers['key'] or { panic('no timer') }
	feedback.show('key')
	assert !timer_pending(first), 'restarting kept the old timer'
	assert feedback.copied('key')
	assert !feedback.copy_from_action('key', 'v', 'other')
	run_due_timers(time.ticks() + 60_000)
	assert !feedback.copied('key')
}

fn test_copyable_text_shows_the_value_and_a_copy_button() {
	theme := component_theme(true)
	el := copyable_text(
		id:        'token'
		frame:     rect(0, 0, 300, 36)
		text:      'sk-1234567890abcdef'
		monospace: true
		copied:    true
		theme:     theme
	) or { panic(err) }
	assert el.id == 'token'
	assert el.accessibility_label == 'sk-1234567890abcdef'
	value := el.children.filter(it.kind == .label)[0]
	assert value.text == 'sk-1234567890abcdef'
	assert value.text_style.font_family == 'monospace'
	copy := el.children.last()
	assert copy.id == 'token:component:button'
	assert copy.action_id == clipboard_action_id('token')
	assert copy.accessibility_value == 'Copied'
	assert copy.frame.x + copy.frame.width <= 300
	assert value.frame.x + value.frame.width <= copy.frame.x
}
