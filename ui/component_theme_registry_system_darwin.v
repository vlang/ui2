// NSUserDefaults only needs the Objective-C runtime bridge, so this file serves
// custom-rendered macOS windows as well as the AppKit backend.
module ui2

import macos

// native_system_appearance reads the Appearance setting from the global
// defaults domain: AppleInterfaceStyle is "Dark" while the system is dark,
// including when it switches automatically, and absent while it is light.
// Asking NSApp for its effective appearance would need an application object,
// which ui/ does not own.
fn native_system_appearance() SystemAppearance {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	defaults := macos.msg_id(macos.get_class('NSUserDefaults'), 'standardUserDefaults')
	if defaults == unsafe { nil } {
		return .unknown
	}
	style := macos.msg_id1(defaults, 'stringForKey:', macos.nsstring('AppleInterfaceStyle'))
	if style == unsafe { nil } {
		return .light
	}
	return if macos.utf8_string(style).to_lower() == 'dark' { .dark } else { .light }
}
