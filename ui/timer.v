@[has_globals]
module ui2

import math
import sync
import time

// TimerFn runs on the UI thread, where it may change application state; the
// window is rebuilt afterwards so the change shows.
pub type TimerFn = fn ()

// TimerId names a pending `after` call so it can be cancelled. Zero is never
// handed out.
pub type TimerId = u64

struct PendingTimer {
	deadline i64 // time.ticks() milliseconds
	callback TimerFn = unsafe { nil }
}

@[heap]
struct TimerRuntime {
	mutex &sync.Mutex = sync.new_mutex()
mut:
	next    u64
	pending map[u64]PendingTimer
}

__global g_timer_runtime = &TimerRuntime{
	pending: map[u64]PendingTimer{}
}

// after runs callback on the UI thread once `seconds` have passed, and then
// rebuilds the window. It is how a toast dismisses itself or a debounce fires
// without the application owning a thread. A negative, NaN or infinite delay
// runs at the next build. Pass the returned id to cancel_timer to call it off.
//
// Callbacks run where widget animation callbacks do: between building the
// declared tree and rendering it, so they see the state that tree was built
// from, and a refresh is requested so their changes are rendered next.
pub fn after(seconds f64, callback TimerFn) TimerId {
	delay := if math.is_nan(seconds) || math.is_inf(seconds, 0) || seconds <= 0 {
		i64(0)
	} else {
		i64(math.ceil(seconds * 1000.0))
	}
	mut runtime := g_timer_runtime
	runtime.mutex.lock()
	runtime.next++
	id := runtime.next
	runtime.pending[id] = PendingTimer{
		deadline: time.ticks() + delay
		callback: callback
	}
	runtime.mutex.unlock()
	spawn timer_wake_after(delay)
	return TimerId(id)
}

// cancel_timer calls off a pending `after`. It reports whether the timer was
// still pending; a timer whose callback has already run cannot be cancelled.
pub fn cancel_timer(id TimerId) bool {
	mut runtime := g_timer_runtime
	runtime.mutex.lock()
	pending := u64(id) in runtime.pending
	runtime.pending.delete(u64(id))
	runtime.mutex.unlock()
	return pending
}

// timer_pending reports whether an `after` callback has yet to run.
pub fn timer_pending(id TimerId) bool {
	runtime := g_timer_runtime
	runtime.mutex.lock()
	pending := u64(id) in runtime.pending
	runtime.mutex.unlock()
	return pending
}

// The waiting thread only asks for a build; the callback itself runs on the UI
// thread inside that build, never on this one.
fn timer_wake_after(delay i64) {
	if delay > 0 {
		time.sleep(delay * time.millisecond)
	}
	request_animation_refresh()
}

// run_due_timers runs, in deadline order, every callback whose time has come
// by `now`, and reports whether any did. Callbacks are taken out of the table
// before they run, so one may schedule or cancel timers itself.
fn run_due_timers(now i64) bool {
	mut runtime := g_timer_runtime
	runtime.mutex.lock()
	mut due := []u64{}
	for id, timer in runtime.pending {
		if timer.deadline <= now {
			due << id
		}
	}
	due.sort_with_compare(fn [runtime] (a &u64, b &u64) int {
		da := runtime.pending[*a].deadline
		db := runtime.pending[*b].deadline
		if da != db {
			return if da < db { -1 } else { 1 }
		}
		return if *a < *b { -1 } else { 1 }
	})
	mut callbacks := []TimerFn{cap: due.len}
	for id in due {
		callbacks << runtime.pending[id].callback
		runtime.pending.delete(id)
	}
	runtime.mutex.unlock()
	for callback in callbacks {
		if voidptr(callback) != unsafe { nil } {
			callback()
		}
	}
	return callbacks.len > 0
}
