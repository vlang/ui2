module ui2

fn finish_scheduler_test_frame(mut coordinator FrameCoordinator, now i64) FrameWork {
	work := coordinator.begin_frame(now) or { panic('expected a frame') }
	if work.build {
		coordinator.record_build()
	}
	if work.draw {
		coordinator.record_draw()
	}
	coordinator.finish_frame(work)
	return work
}

fn test_frame_scheduler_on_demand_idle_and_coalescing() {
	mut coordinator := new_frame_coordinator(.on_demand)
	initial := finish_scheduler_test_frame(mut coordinator, 0)
	assert initial.build && initial.draw
	for now in 1 .. 30_001 {
		if _ := coordinator.begin_frame(now) {
			assert false, 'idle callback must not request work'
		}
	}
	idle := coordinator.stats()
	assert idle.callbacks == 30_001
	assert idle.builds == 1
	assert idle.draws == 1
	assert idle.flushes == 1
	for _ in 0 .. 100 {
		coordinator.invalidate(.build)
	}
	pending := coordinator.stats()
	assert pending.requests == 101
	assert pending.coalesced == 99
	assert pending.pending_reasons == [.build]
	finish_scheduler_test_frame(mut coordinator, 30_001)
	assert coordinator.stats().flushes == 2
	assert !coordinator.stats().pending
}

fn test_frame_scheduler_invalidation_during_flush_survives() {
	mut coordinator := new_frame_coordinator(.on_demand)
	work := coordinator.begin_frame(0) or { panic('expected initial frame') }
	coordinator.invalidate(.build)
	if _ := coordinator.begin_frame(1) {
		assert false, 'a nested callback must not start a second flush'
	}
	coordinator.finish_frame(work)
	assert coordinator.stats().pending
	assert coordinator.stats().finished_generation == work.generation
	next := finish_scheduler_test_frame(mut coordinator, 2)
	assert next.generation > work.generation
	assert next.build
	coordinator.finish_frame(work)
	assert coordinator.stats().flushes == 2
	assert coordinator.stats().finished_generation == next.generation
}

fn test_frame_scheduler_paint_deadline_and_animation_return_to_idle() {
	mut coordinator := new_frame_coordinator(.on_demand)
	finish_scheduler_test_frame(mut coordinator, 0)
	coordinator.invalidate(.paint)
	paint := finish_scheduler_test_frame(mut coordinator, 10)
	assert !paint.build && paint.draw
	coordinator.set_deadline(500)
	if _ := coordinator.begin_frame(499) {
		assert false, 'timer fired before its monotonic deadline'
	}
	timer := finish_scheduler_test_frame(mut coordinator, 500)
	assert timer.reasons == [.timer]
	assert !timer.build && timer.draw
	assert coordinator.stats().next_deadline == -1
	coordinator.set_animation_active(true)
	animation := finish_scheduler_test_frame(mut coordinator, 501)
	assert animation.build && animation.draw
	assert animation.reasons == [.animation]
	finish_scheduler_test_frame(mut coordinator, 509)
	coordinator.set_animation_active(false)
	if _ := coordinator.begin_frame(510) {
		assert false, 'finished animation must return to idle'
	}
	coordinator.set_deadline(600)
	coordinator.set_deadline(-1)
	if _ := coordinator.begin_frame(600) {
		assert false, 'cancelled deadline must not fire'
	}
}

fn test_frame_scheduler_posted_callbacks_are_outside_lock_and_next_drain() {
	mut coordinator := new_frame_coordinator(.on_demand)
	dispatcher := UiDispatcher{
		coordinator: coordinator
	}
	finish_scheduler_test_frame(mut coordinator, 0)
	mut delivered := chan int{cap: 2}
	assert dispatcher.post(fn [dispatcher, delivered] () {
		delivered <- 1
		assert dispatcher.post(fn [delivered] () {
			delivered <- 2
		})
		assert dispatcher.stats().pending
	})
	tasks := coordinator.take_tasks()
	assert tasks.len == 1
	for task in tasks {
		task()
	}
	assert <-delivered == 1
	first := finish_scheduler_test_frame(mut coordinator, 1)
	assert first.build
	assert first.reasons == [.worker]
	next := coordinator.take_tasks()
	assert next.len == 1
	for task in next {
		task()
	}
	assert <-delivered == 2
	assert coordinator.take_tasks().len == 0
	worker := finish_scheduler_test_frame(mut coordinator, 2)
	assert worker.build
	assert worker.reasons == [.worker]
	assert coordinator.stats().flushes == 3
}

fn test_frame_scheduler_suspend_resume_preserves_business_tasks_and_restores_surface() {
	mut coordinator := new_frame_coordinator(.on_demand)
	finish_scheduler_test_frame(mut coordinator, 0)
	coordinator.set_deadline(500)
	coordinator.suspend()
	assert coordinator.stats().suspended
	assert coordinator.stats().next_deadline == -1
	mut delivered := chan bool{cap: 1}
	assert coordinator.post(fn [delivered] () {
		delivered <- true
	})
	for task in coordinator.take_tasks() {
		task()
	}
	assert <-delivered
	coordinator.set_deadline(600)
	if _ := coordinator.begin_frame(1000) {
		assert false, 'suspended context must not draw'
	}
	assert coordinator.stats().callbacks == 2
	assert coordinator.stats().next_deadline == -1
	coordinator.resume()
	restored := finish_scheduler_test_frame(mut coordinator, 1001)
	assert restored.build && restored.draw
	assert RenderReason.surface in restored.reasons
	assert !coordinator.stats().suspended
	if _ := coordinator.begin_frame(1002) {
		assert false, 'restored surface must return to idle'
	}
}

fn test_frame_scheduler_does_not_deliver_tasks_during_an_active_flush() {
	mut coordinator := new_frame_coordinator(.on_demand)
	finish_scheduler_test_frame(mut coordinator, 0)
	coordinator.invalidate(.paint)
	work := coordinator.begin_frame(1) or { panic('expected paint frame') }
	mut delivered := chan bool{cap: 1}
	assert coordinator.post(fn [delivered] () {
		delivered <- true
	})
	// A modal dialog can spin a nested event loop during a build or draw. It
	// must not deliver worker mutations in the middle of the outer flush.
	assert coordinator.take_tasks().len == 0
	assert coordinator.stats().pending
	coordinator.finish_frame(work)
	tasks := coordinator.take_tasks()
	assert tasks.len == 1
	for task in tasks {
		task()
	}
	assert <-delivered
	next := finish_scheduler_test_frame(mut coordinator, 2)
	assert next.build && next.reasons == [.worker]
}

fn test_frame_scheduler_close_cancels_queue_timers_and_rejects_old_handle() {
	mut coordinator := new_frame_coordinator(.on_demand)
	dispatcher := UiDispatcher{
		coordinator: coordinator
	}
	assert dispatcher.post(fn () {
		assert false, 'closed context must cancel queued callback'
	})
	coordinator.set_deadline(500)
	coordinator.set_animation_active(true)
	coordinator.close()
	assert coordinator.take_tasks().len == 0
	assert !dispatcher.post(fn () {})
	coordinator.invalidate(.build)
	coordinator.resume()
	if _ := coordinator.begin_frame(1000) {
		assert false, 'closed context must never render'
	}
	stats := dispatcher.stats()
	assert stats.closed
	assert !stats.pending && !stats.in_flight && !stats.animation_active
	assert stats.next_deadline == -1
	assert UiDispatcher{}.stats().closed
	assert !UiDispatcher{}.post(fn () {})
}

fn test_frame_scheduler_continuous_default_and_policy_change() {
	mut coordinator := new_frame_coordinator(.continuous)
	coordinator.set_presentation_required(true)
	for now in 0 .. 3 {
		work := finish_scheduler_test_frame(mut coordinator, now)
		assert work.build && work.draw
	}
	coordinator.set_presentation_required(false)
	coordinator.set_policy(.on_demand)
	finish_scheduler_test_frame(mut coordinator, 3)
	if _ := coordinator.begin_frame(4) {
		assert false, 'on-demand policy must become idle'
	}
	coordinator.set_policy(.continuous)
	finish_scheduler_test_frame(mut coordinator, 5)
	finish_scheduler_test_frame(mut coordinator, 6)
	assert coordinator.stats().builds == 6
}

fn test_frame_scheduler_required_presentation_reuses_tree_and_respects_lifecycle() {
	mut coordinator := new_frame_coordinator(.on_demand)
	finish_scheduler_test_frame(mut coordinator, 0)
	coordinator.set_presentation_required(true)
	assert coordinator.stats().presentation_required
	baseline := coordinator.stats()
	for now in 1 .. 4 {
		idle := finish_scheduler_test_frame(mut coordinator, now)
		assert !idle.build && idle.draw
		assert idle.reasons == [.presentation]
	}
	assert coordinator.stats().requests == baseline.requests
	assert coordinator.stats().generation == baseline.generation
	assert coordinator.stats().builds == baseline.builds
	for _ in 0 .. 10 {
		coordinator.invalidate(.build)
	}
	changed := finish_scheduler_test_frame(mut coordinator, 4)
	assert changed.build && changed.draw && changed.reasons == [.build]
	assert coordinator.stats().requests == baseline.requests + 10
	assert coordinator.stats().coalesced == 9
	cached := finish_scheduler_test_frame(mut coordinator, 5)
	assert !cached.build && cached.reasons == [.presentation]
	coordinator.suspend()
	if _ := coordinator.begin_frame(6) {
		assert false, 'suspension must suppress even required presentation'
	}
	coordinator.resume()
	restored := finish_scheduler_test_frame(mut coordinator, 7)
	assert restored.build && restored.draw
	assert restored.reasons == [.surface]
	after_restore := finish_scheduler_test_frame(mut coordinator, 8)
	assert !after_restore.build && after_restore.reasons == [.presentation]
	coordinator.set_presentation_required(false)
	assert !coordinator.stats().presentation_required
	if _ := coordinator.begin_frame(9) {
		assert false, 'a backend that can skip presentation must return to idle'
	}
}

fn test_frame_scheduler_worker_posts_are_synchronized() {
	mut coordinator := new_frame_coordinator(.on_demand)
	dispatcher := UiDispatcher{
		coordinator: coordinator
	}
	finish_scheduler_test_frame(mut coordinator, 0)
	mut workers := []thread{}
	for _ in 0 .. 4 {
		workers << spawn fn [dispatcher] () {
			for _ in 0 .. 100 {
				assert dispatcher.post(fn () {})
			}
		}()
	}
	workers.wait()
	assert coordinator.take_tasks().len == 400
	assert dispatcher.stats().requests == 401
	assert dispatcher.stats().coalesced == 399
	finish_scheduler_test_frame(mut coordinator, 1)
	assert dispatcher.stats().flushes == 2
}

fn test_frame_scheduler_contexts_keep_independent_lifetimes() {
	mut first := new_frame_coordinator(.on_demand)
	mut second := new_frame_coordinator(.on_demand)
	finish_scheduler_test_frame(mut first, 0)
	finish_scheduler_test_frame(mut second, 0)
	first.invalidate(.build)
	first.set_deadline(500)
	first.close()
	second.invalidate(.paint)
	work := finish_scheduler_test_frame(mut second, 1)
	assert !work.build && work.draw
	assert !second.stats().closed
	assert second.stats().next_deadline == -1
	assert first.stats().flushes == 1
	assert second.stats().flushes == 2
}
