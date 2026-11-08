module ui2

import math
import time

struct TimerLog {
mut:
	calls     []string
	follow_up TimerId
}

fn test_after_runs_due_callbacks_in_deadline_order_once() {
	mut log := &TimerLog{}
	late := after(0.2, fn [mut log] () {
		log.calls << 'late'
	})
	early := after(0.1, fn [mut log] () {
		log.calls << 'early'
	})
	now := after(0, fn [mut log] () {
		log.calls << 'now'
	})
	assert timer_pending(late) && timer_pending(early) && timer_pending(now)
	start := time.ticks()
	assert run_due_timers(start)
	assert log.calls == ['now']
	assert !run_due_timers(start)
	assert run_due_timers(start + 1000)
	assert log.calls == ['now', 'early', 'late']
	assert !timer_pending(late) && !timer_pending(early)
	assert !run_due_timers(start + 2000)
}

fn test_cancel_timer_stops_a_pending_callback_only() {
	mut log := &TimerLog{}
	id := after(0.05, fn [mut log] () {
		log.calls << 'cancelled'
	})
	assert cancel_timer(id)
	assert !cancel_timer(id)
	assert !run_due_timers(time.ticks() + 1000)
	assert log.calls.len == 0
	assert !cancel_timer(TimerId(0))
}

fn test_timer_callbacks_can_schedule_and_cancel_timers() {
	mut log := &TimerLog{}
	victim := after(5, fn [mut log] () {
		log.calls << 'victim'
	})
	after(0, fn [mut log, victim] () {
		log.calls << 'first'
		cancel_timer(victim)
		log.follow_up = after(0, fn [mut log] () {
			log.calls << 'second'
		})
	})
	assert run_due_timers(time.ticks())
	assert log.calls == ['first']
	assert timer_pending(log.follow_up)
	assert run_due_timers(time.ticks() + 10)
	assert log.calls == ['first', 'second']
	assert !run_due_timers(time.ticks() + 10000)
}

fn test_after_treats_invalid_delays_as_immediate() {
	mut log := &TimerLog{}
	for delay in [-1.0, math.nan(), math.inf(1)] {
		after(delay, fn [mut log] () {
			log.calls << 'ran'
		})
	}
	assert run_due_timers(time.ticks())
	assert log.calls.len == 3
}
