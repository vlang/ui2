@[has_globals]
module main

import os
import time
import ui2

__global g_acceptance_started = false
__global g_acceptance_policy = ui2.RenderPolicy.continuous
__global g_acceptance_sample_seconds = 30
__global g_acceptance_interactive = false
__global g_acceptance_message = 'Static scene — waiting for worker'
__global g_acceptance_worker_builds = 0
__global g_acceptance_verify_reentrant = false
__global g_acceptance_dispatcher = ui2.UiDispatcher{}
__global g_acceptance_completion_built = false
__global g_acceptance_lifecycle = false

fn main() {
	for i, arg in os.args {
		match arg {
			'--on-demand' { g_acceptance_policy = .on_demand }
			'--interactive' { g_acceptance_interactive = true }
			'--lifecycle' { g_acceptance_lifecycle = true }
			'--seconds' {
				if i + 1 >= os.args.len || os.args[i + 1].int() <= 0 {
					panic('--seconds needs a positive integer')
				}
				g_acceptance_sample_seconds = os.args[i + 1].int()
			}
			else {}
		}
	}
	ui2.set_render_policy(g_acceptance_policy)
	ui2.run_window('UI2 renderer scheduler acceptance', 640, 480, build, event)
}

fn build() ui2.Element {
	if !g_acceptance_started {
		g_acceptance_started = true
		g_acceptance_dispatcher = ui2.ui_dispatcher()
		if !g_acceptance_interactive {
			spawn acceptance(g_acceptance_dispatcher, g_acceptance_policy, g_acceptance_sample_seconds,
				g_acceptance_lifecycle)
		} else {
			spawn observe(g_acceptance_dispatcher)
		}
	}
	if g_acceptance_message == 'Animation completed' {
		g_acceptance_completion_built = true
	}
	if g_acceptance_verify_reentrant {
		g_acceptance_worker_builds++
		if g_acceptance_worker_builds == 1 {
			// A request issued while the current generation is being built must
			// survive its acknowledgement and produce one subsequent build.
			ui2.request_refresh()
		}
	}
	style := ui2.TextStyle{ size: 14, color: 0x243247 }
	box := ui2.BoxStyle{ bg: 0xe2e8f0, radius: 6 }
	mut rows := []ui2.Element{}
	for i in 0 .. 30 {
		rows << ui2.label('row-${i}', 'Scroll row ${i + 1}', ui2.rect(8, i * 26, 240, 24), style)
	}
	return ui2.screen(0xf8fafc, [
		ui2.label('heading', 'Renderer scheduler acceptance', ui2.rect(24, 16, 590, 28),
			ui2.TextStyle{ size: 20, color: 0x0f172a }),
		ui2.with_tooltip(ui2.label('status', g_acceptance_message, ui2.rect(24, 52, 590, 28), style),
			'Tooltip appears after 500 ms with a stationary pointer.'),
		ui2.text_field('editor', 'Type, select, then refresh', '', ui2.rect(24, 96, 340, 34), box, style, 0),
		ui2.button('refresh', 'Refresh', ui2.rect(380, 96, 100, 34), box, style),
		ui2.button('worker', 'Worker', ui2.rect(496, 96, 112, 34), box, style),
		ui2.button('animate', 'Animate', ui2.rect(24, 148, 112, 34), box, style),
		ui2.view('moving', ui2.rect(160, 148, 36, 34), ui2.BoxStyle{ bg: 0x2563eb, radius: 6 }, []ui2.Element{}),
		ui2.scroll('rows', ui2.rect(24, 208, 300, 232), 0xe2e8f0, rows),
		ui2.label('instructions', 'Hover status for tooltip.\nEdit, select, scroll, resize.\nMinimize and restore.\nContent must stay intact.', ui2.rect(348, 220, 268, 140), ui2.TextStyle{ ...style, lines: 4 }),
	])
}

fn event(id string) {
	match id {
		'animate' { start_animation() }
		'worker' { spawn delayed_update(ui2.ui_dispatcher()) }
		'refresh' { ui2.refresh() }
		else {}
	}
}

fn start_animation() {
	ui2.clear_animation('moving')
	ui2.animation(
		duration: 0.8
		x:        280.0
		on_event: fn (event ui2.AnimationEvent) {
			if event.kind == .complete {
				// Event callbacks can mutate the model without their own refresh.
				g_acceptance_message = 'Animation completed'
			}
		}
	).start('moving')
}

fn observe(dispatcher ui2.UiDispatcher) {
	mut before := dispatcher.stats()
	for !before.closed {
		time.sleep(time.second)
		after := dispatcher.stats()
		report('interactive suspended=${after.suspended}', before, after)
		before = after
	}
}

fn delayed_update(dispatcher ui2.UiDispatcher) {
	time.sleep(750 * time.millisecond)
	assert dispatcher.post(fn () {
		g_acceptance_message = 'Worker delivered on UI thread'
	})
}

fn report(phase string, before ui2.RenderStats, after ui2.RenderStats) {
	println('${phase}: callbacks=${after.callbacks - before.callbacks} builds=${after.builds - before.builds} draws=${after.draws - before.draws} flushes=${after.flushes - before.flushes} requests=${after.requests - before.requests} coalesced=${after.coalesced - before.coalesced}')
}

fn acceptance(dispatcher ui2.UiDispatcher, selected_policy ui2.RenderPolicy, seconds int, lifecycle bool) {
	// Observe counters directly from the worker: posting an observer callback
	// would itself invalidate the scene and contaminate the static sample.
	time.sleep(2 * time.second)
	before := dispatcher.stats()
	println('sample: policy=${selected_policy} seconds=${seconds} warmup=2 presentation_required=${before.presentation_required}')
	time.sleep(seconds * time.second)
	after := dispatcher.stats()
	report('static', before, after)
	assert after.callbacks > before.callbacks
	if selected_policy == .on_demand {
		assert after.builds == before.builds
		if !before.presentation_required {
			assert after.draws == before.draws
		}
	} else {
		assert after.builds > before.builds
		assert after.draws > before.draws
	}
	assert dispatcher.post(fn () {
		g_acceptance_message = 'Worker delivered on UI thread'
		g_acceptance_verify_reentrant = true
		for _ in 0 .. 20 {
			ui2.request_refresh()
		}
	})
	time.sleep(500 * time.millisecond)
	worker_after := dispatcher.stats()
	report('worker + burst + reentrant build', after, worker_after)
	if selected_policy == .on_demand {
		assert worker_after.builds - after.builds == 2
		if !after.presentation_required {
			assert worker_after.draws - after.draws == 2
		}
	}
	assert dispatcher.post(fn () {
		assert g_acceptance_worker_builds >= 2
		assert g_acceptance_message == 'Worker delivered on UI thread'
		g_acceptance_verify_reentrant = false
		start_animation()
	})
	time.sleep(1500 * time.millisecond)
	settled := dispatcher.stats()
	report('animation', worker_after, settled)
	assert settled.draws > worker_after.draws
	time.sleep(time.second)
	idle := dispatcher.stats()
	report('idle after animation', settled, idle)
	if selected_policy == .on_demand {
		assert idle.builds == settled.builds
		if !settled.presentation_required {
			assert idle.draws == settled.draws
		}
	}
	if lifecycle {
		$if macos {
			check_lifecycle(dispatcher, selected_policy)
		} $else {
			println('SKIP: native lifecycle helper currently supports macOS only')
		}
	}
	assert dispatcher.post(fn [dispatcher] () {
		assert ui2.animation_info('moving').status == .completed
		assert g_acceptance_completion_built
		println('PASS: static, worker, coalescing, reentrant request, animation, return to idle')
		ui2.quit()
		assert dispatcher.stats().closed
		assert !dispatcher.post(fn () {
			assert false, 'closed window must reject a late worker callback'
		})
		println('PASS: closed dispatcher rejected late worker callback')
	})
}

fn check_lifecycle(dispatcher ui2.UiDispatcher, selected_policy ui2.RenderPolicy) {
	assert dispatcher.post(fn () {
		assert schedule_real_window_lifecycle(2000)
	})
	mut suspended := dispatcher.stats()
	for _ in 0 .. 100 {
		if suspended.suspended {
			break
		}
		time.sleep(20 * time.millisecond)
		suspended = dispatcher.stats()
	}
	assert suspended.suspended, 'native window must become iconified'
	time.sleep(500 * time.millisecond)
	midpoint := dispatcher.stats()
	report('real window iconified', suspended, midpoint)
	assert midpoint.suspended
	assert midpoint.builds == suspended.builds
	assert midpoint.draws == suspended.draws
	mut restored := midpoint
	for _ in 0 .. 200 {
		time.sleep(20 * time.millisecond)
		restored = dispatcher.stats()
		if !restored.suspended && restored.draws > midpoint.draws {
			break
		}
	}
	report('real window restored', midpoint, restored)
	assert !restored.suspended, 'native window must restore before timeout'
	assert restored.builds > midpoint.builds
	assert restored.draws > midpoint.draws
	time.sleep(500 * time.millisecond)
	settled := dispatcher.stats()
	time.sleep(500 * time.millisecond)
	idle := dispatcher.stats()
	report('idle after restore', settled, idle)
	if selected_policy == .on_demand {
		assert idle.builds == settled.builds
		if !settled.presentation_required {
			assert idle.draws == settled.draws
		}
	}
	println('PASS: real window minimize, suspended draw suppression, restore, return to idle')
}
