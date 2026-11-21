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

fn test_native_clipboard_write_quotes_paths_and_reports_copy_failure() ! {
	$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
		dir := os.join_path(os.temp_dir(), 'ui2-copy-test-${os.getpid()}-${time.sys_mono_now()}')
		os.mkdir_all(dir)!
		defer { os.rmdir_all(dir) or {} }
		script := os.join_path(dir, "wl-copy 'fixture.sh")
		output := os.join_path(dir, "copy 'result.txt")
		os.write_file(script, 'cat > "$1"')!
		assert native_clipboard_write(['/bin/sh', script, output], 'quoted clipboard contents')
		assert os.read_file(output)! == 'quoted clipboard contents'
		os.write_file(script, 'exit 7')!
		assert !native_clipboard_write(['/bin/sh', script], 'must fail')
	}
}

fn test_native_clipboard_write_reports_wayland_launcher_failure() ! {
	$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
		dir := os.join_path(os.temp_dir(), 'ui2-copy-failure-${os.getpid()}-${time.sys_mono_now()}')
		os.mkdir_all(dir)!
		defer { os.rmdir_all(dir) or {} }
		script := os.join_path(dir, 'wl-copy')
		os.write_file(script, '#!/bin/sh\nexit 7\n')!
		os.chmod(script, 0o755)!
		assert !native_clipboard_write([script], 'must fail')
		assert !native_clipboard_write([]string{}, 'no tool')
	}
}

fn test_native_clipboard_write_does_not_wait_for_owner_output_pipes() ! {
	$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
		dir := os.join_path(os.temp_dir(), 'ui2-copy-owner-${os.getpid()}-${time.sys_mono_now()}')
		os.mkdir_all(dir)!
		defer { os.rmdir_all(dir) or {} }
		script := os.join_path(dir, 'wl-copy')
		output := os.join_path(dir, 'contents.txt')
		// The descendant keeps both output descriptors open, just as a
		// selection owner can do. It exits on its own even if the test fails.
		os.write_file(script, '#!/bin/sh\ncat > "$1"\nsleep 3 &\n')!
		os.chmod(script, 0o755)!
		start := time.sys_mono_now()
		assert native_clipboard_write([script, output], 'owned clipboard contents')
		assert time.sys_mono_now() - start < 2 * time.second
		// Success must also mean the launcher has already consumed stdin.
		assert os.read_file(output)! == 'owned clipboard contents'
	}
}
