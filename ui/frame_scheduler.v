module ui2

import sync

// RenderReason describes why a custom-renderer frame was requested.
pub enum RenderReason {
	build
	paint
	surface
	animation
	timer
	worker
	presentation
}

// RenderStats separates callbacks from actual work. Skipping builds and draws
// does not imply that the platform event loop stopped waking up.
pub struct RenderStats {
pub:
	callbacks             u64
	builds                u64
	draws                 u64
	flushes               u64
	coalesced             u64
	requests              u64
	generation            u64
	finished_generation   u64
	pending               bool
	in_flight             bool
	pending_reasons       []RenderReason
	next_deadline         i64 = -1
	animation_active      bool
	presentation_required bool
	suspended             bool
	closed                bool
}

struct FrameWork {
	generation u64
	serial     u64
	build      bool
	draw       bool
	reasons    []RenderReason
}

// Each renderer context owns one coordinator. The lock protects only scheduler
// state; builders, drawing and posted callbacks always run outside it.
@[heap]
struct FrameCoordinator {
	mutex &sync.Mutex = sync.new_mutex()
mut:
	callbacks             u64
	builds                u64
	draws                 u64
	flushes               u64
	coalesced             u64
	requests              u64
	generation            u64
	finished_generation   u64
	pending_reasons       []RenderReason
	next_serial           u64
	active_serial         u64
	next_deadline         i64 = -1
	animation_active      bool
	presentation_required bool
	suspended             bool
	closed                bool
	tasks                 []fn ()
}

fn new_frame_coordinator() &FrameCoordinator {
	mut coordinator := &FrameCoordinator{}
	coordinator.invalidate(.surface)
	return coordinator
}

// Some platform loops present their swapchain after every callback, even when
// UI2 issues no commands. Those backends must paint the retained declaration on
// idle callbacks until the embedder can suppress presentation itself.
fn (mut coordinator FrameCoordinator) set_presentation_required(required bool) {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	if !coordinator.closed {
		coordinator.presentation_required = required
	}
}

fn (mut coordinator FrameCoordinator) invalidate(reason RenderReason) {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	coordinator.invalidate_locked(reason)
}

fn (mut coordinator FrameCoordinator) invalidate_locked(reason RenderReason) {
	if coordinator.closed {
		return
	}
	coordinator.requests++
	coordinator.generation++
	if coordinator.pending_reasons.len > 0 {
		coordinator.coalesced++
	}
	if reason !in coordinator.pending_reasons {
		coordinator.pending_reasons << reason
	}
}

// begin_frame takes a generation snapshot and detaches its reasons. Requests
// arriving while the caller works therefore belong to the following frame.
// now and deadlines use the same caller-supplied monotonic millisecond clock.
fn (mut coordinator FrameCoordinator) begin_frame(now i64) ?FrameWork {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	coordinator.callbacks++
	if coordinator.closed || coordinator.suspended || coordinator.active_serial != 0 {
		return none
	}
	if coordinator.next_deadline >= 0 && now >= coordinator.next_deadline {
		coordinator.next_deadline = -1
		coordinator.invalidate_locked(.timer)
	}
	if coordinator.animation_active {
		coordinator.invalidate_locked(.animation)
	}
	if coordinator.pending_reasons.len == 0 && !coordinator.presentation_required {
		return none
	}
	reasons := if coordinator.pending_reasons.len == 0 && coordinator.presentation_required {
		// This is a platform presentation requirement, not a new invalidation.
		// Keep request/generation counters about actual application work.
		[RenderReason.presentation]
	} else {
		coordinator.pending_reasons
	}
	coordinator.pending_reasons = []RenderReason{}
	coordinator.next_serial++
	coordinator.active_serial = coordinator.next_serial
	mut build := false
	for reason in reasons {
		if reason in [.build, .surface, .animation, .worker] {
			build = true
			break
		}
	}
	return FrameWork{
		generation: coordinator.generation
		serial:     coordinator.active_serial
		build:      build
		draw:       true
		reasons:    reasons
	}
}

fn (mut coordinator FrameCoordinator) finish_frame(work FrameWork) {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	if coordinator.closed || work.serial == 0 || coordinator.active_serial != work.serial {
		return
	}
	coordinator.active_serial = 0
	coordinator.finished_generation = work.generation
	coordinator.flushes++
}

fn (mut coordinator FrameCoordinator) record_build() {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	coordinator.builds++
}

fn (mut coordinator FrameCoordinator) record_draw() {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	coordinator.draws++
}

// A negative deadline cancels the pending visual timer. The renderer combines
// its tooltip, cursor and other visual timers into the earliest deadline.
fn (mut coordinator FrameCoordinator) set_deadline(at i64) {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	if coordinator.closed || coordinator.suspended {
		return
	}
	coordinator.next_deadline = at
}

fn (mut coordinator FrameCoordinator) set_animation_active(active bool) {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	if !coordinator.closed {
		coordinator.animation_active = active
	}
}

fn (mut coordinator FrameCoordinator) suspend() {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	if !coordinator.closed {
		coordinator.suspended = true
		coordinator.next_deadline = -1
	}
}

fn (mut coordinator FrameCoordinator) resume() {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	if coordinator.closed || !coordinator.suspended {
		return
	}
	coordinator.suspended = false
	coordinator.invalidate_locked(.surface)
}

fn (mut coordinator FrameCoordinator) close() {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	coordinator.closed = true
	coordinator.suspended = false
	coordinator.animation_active = false
	coordinator.next_deadline = -1
	coordinator.active_serial = 0
	coordinator.pending_reasons = []RenderReason{}
	coordinator.tasks = []fn (){}
}

fn (mut coordinator FrameCoordinator) is_closed() bool {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	return coordinator.closed
}

fn (mut coordinator FrameCoordinator) post(task fn ()) bool {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	if coordinator.closed {
		return false
	}
	coordinator.tasks << task
	coordinator.invalidate_locked(.worker)
	return true
}

// The UI thread drains business callbacks even while drawing is suspended.
// A callback can post another callback or invalidate without holding this lock.
// Close and callback execution belong to the UI thread; close cancels the queue.
fn (mut coordinator FrameCoordinator) take_tasks() []fn () {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	if coordinator.closed || coordinator.active_serial != 0 {
		return []fn (){}
	}
	tasks := coordinator.tasks
	coordinator.tasks = []fn (){}
	// A callback in an earlier batch can post another task before begin_frame.
	// Its post may have been acknowledged by that frame while the task itself
	// waited for the next drain. Delivery must still invalidate its own frame.
	if tasks.len > 0 && RenderReason.worker !in coordinator.pending_reasons {
		coordinator.invalidate_locked(.worker)
	}
	return tasks
}

fn (mut coordinator FrameCoordinator) stats() RenderStats {
	coordinator.mutex.lock()
	defer { coordinator.mutex.unlock() }
	return RenderStats{
		callbacks:             coordinator.callbacks
		builds:                coordinator.builds
		draws:                 coordinator.draws
		flushes:               coordinator.flushes
		coalesced:             coordinator.coalesced
		requests:              coordinator.requests
		generation:            coordinator.generation
		finished_generation:   coordinator.finished_generation
		pending:               coordinator.pending_reasons.len > 0
		in_flight:             coordinator.active_serial != 0
		pending_reasons:       coordinator.pending_reasons.clone()
		next_deadline:         coordinator.next_deadline
		animation_active:      coordinator.animation_active
		presentation_required: coordinator.presentation_required
		suspended:             coordinator.suspended
		closed:                coordinator.closed
	}
}

// UiDispatcher is a lifetime-safe handle for delivering worker results to the
// custom renderer's UI thread. Capture this handle before starting the worker;
// mutate the model only inside post's callback. A closed window rejects posts.
pub struct UiDispatcher {
	coordinator &FrameCoordinator = unsafe { nil }
}

pub fn (dispatcher UiDispatcher) post(task fn ()) bool {
	if isnil(dispatcher.coordinator) {
		return false
	}
	mut coordinator := dispatcher.coordinator
	return coordinator.post(task)
}

// stats is a synchronized snapshot; reading it never requests a frame.
pub fn (dispatcher UiDispatcher) stats() RenderStats {
	if isnil(dispatcher.coordinator) {
		return RenderStats{
			closed: true
		}
	}
	mut coordinator := dispatcher.coordinator
	return coordinator.stats()
}
