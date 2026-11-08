module main

$if !ui2_custom_rendering ? {
	import macos

	#flag darwin -framework AppKit

	fn apply_window_title(title string) {
		app := macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
		window := macos.msg_id(app, 'keyWindow')
		if window == unsafe { nil } || title.len == 0 {
			return
		}
		macos.msg_void1(window, 'setTitle:', macos.nsstring(title))
	}
}
