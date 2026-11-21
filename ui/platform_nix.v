// The Linux and BSD desktops open links through xdg-open; they have no
// haptics engine, icon badge or share sheet this layer can drive. The _nix
// file suffix keeps the file out of Windows builds only, so the desktop scope
// is spelled out: macOS and iOS have their own bridge files, Windows and
// Android theirs, and the default answers for the rest.
module ui2

import os

$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
	fn native_haptic_supported() bool {
		return false
	}

	fn native_haptic(_style HapticStyle) bool {
		return false
	}

	fn native_app_badge_supported() bool {
		return false
	}

	fn native_set_app_badge(_count int) bool {
		return false
	}

	fn native_open_url_supported() bool {
		return linux_has_executable('xdg-open')
	}

	fn native_open_url(url string) bool {
		open := os.find_abs_path_of_executable('xdg-open') or { return false }
		// xdg-open may wait for the browser's entire lifetime. Launch without
		// waiting on the UI thread, and reap the child in the background. Pass
		// literal argv through the shell, which supplies redirection only.
		mut process := os.new_process('/bin/sh')
		process.set_args(['-c', 'exec "$@" < /dev/null > /dev/null 2>&1', 'ui2-url', open, url])
		process.run()
		if process.status != .running {
			process.close()
			return false
		}
		go platform_wait_url_launcher(mut process)
		return true
	}

	fn platform_wait_url_launcher(mut process os.Process) {
		process.wait()
		process.close()
	}

	fn native_share_supported() bool {
		return false
	}

	fn native_share_text(_text string) bool {
		return false
	}
}
