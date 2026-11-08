// vfmt off
@[has_globals]
module ui2

// Real-tool tests for the nix clipboard shims, opt-in because a copy reaches
// the user's actual system clipboard: run with ui2_clipboard_real_test=1.
// The interesting assertion after the daemonized-owner fix is TIME: each
// write answers from the first child only, so a copy answers in a moment
// even though the selection server lives on until another claimant arrives.

import os
import time

@[test]
fn test_native_clipboard_write_answers_with_a_daemon_alive() ! {
	if os.getenv('ui2_clipboard_real_test').len == 0 {
		eprintln('skipped: set ui2_clipboard_real_test=1 to exercise the real tools')
		return
	}
	probe := 'ui2 native clipboard ${time.sys_mono_now()}'
	mut t0 := time.sys_mono_now()
	assert native_set_primary_text(probe), 'first primary write failed'
	eprintln('first primary: ${f64(time.sys_mono_now() - t0) / 1_000_000.0:.1f}ms')
	t0 = time.sys_mono_now()
	assert native_set_clipboard_text(probe), 'first clipboard write failed'
	eprintln('clipboard write: ${f64(time.sys_mono_now() - t0) / 1_000_000.0:.1f}ms')
	t0 = time.sys_mono_now()
	assert native_set_primary_text(probe), 'second primary write failed'
	eprintln('second primary: ${f64(time.sys_mono_now() - t0) / 1_000_000.0:.1f}ms')
}
