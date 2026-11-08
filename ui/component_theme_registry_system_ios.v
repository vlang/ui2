module ui2

import macos

// native_system_appearance reads the current trait collection's interface
// style (iOS 13 and later): UIUserInterfaceStyleLight is 1 and Dark is 2.
fn native_system_appearance() SystemAppearance {
	traits := macos.msg_id(macos.get_class('UITraitCollection'), 'currentTraitCollection')
	if traits == unsafe { nil } || !macos.responds_to(traits, 'userInterfaceStyle') {
		return .unknown
	}
	return match macos.msg_i64(traits, 'userInterfaceStyle') {
		1 { .light }
		2 { .dark }
		else { .unknown }
	}
}
