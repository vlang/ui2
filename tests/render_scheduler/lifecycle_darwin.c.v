module main

import sokol.sapp

#include "@VMODROOT/tests/render_scheduler/lifecycle_darwin.h"

fn C.ui2_scheduler_minimize_restore(window voidptr, delay_ms i64) bool

// Call from a dispatcher callback on the UI thread, after the window mounts.
// The native main queue restores the real window even while Sokol is paused.
fn schedule_real_window_lifecycle(delay_ms int) bool {
	return C.ui2_scheduler_minimize_restore(sapp.macos_get_window(), i64(delay_ms))
}
