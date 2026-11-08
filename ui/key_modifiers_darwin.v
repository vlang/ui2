// NSEvent only needs the Objective-C runtime bridge, so this file serves
// custom-rendered macOS windows as well as the AppKit backend.
module ui2

import macos

fn native_key_modifiers() KeyModifiers {
	flags := macos.msg_u64(macos.get_class('NSEvent'), 'modifierFlags')
	return KeyModifiers{
		shift: flags & (u64(1) << 17) != 0
		ctrl:  flags & (u64(1) << 18) != 0
		alt:   flags & (u64(1) << 19) != 0
		cmd:   flags & (u64(1) << 20) != 0
	}
}
