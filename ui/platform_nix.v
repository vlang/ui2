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
		result := os.execute('${os.quoted_path(open)} ${os.quoted_path(url)}')
		return result.exit_code == 0
	}

	fn native_share_supported() bool {
		return false
	}

	fn native_share_text(_text string) bool {
		return false
	}
}
