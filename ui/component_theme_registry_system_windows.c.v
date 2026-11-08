module ui2

import os

#flag windows -ladvapi32

// native_system_appearance reads the "Choose your app mode" setting:
// AppsUseLightTheme under the Personalize key is 0 in dark mode and 1 in light.
fn native_system_appearance() SystemAppearance {
	mut key := voidptr(0)
	path := 'Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize'
	// KEY_QUERY_VALUE
	if C.RegOpenKeyExW(os.hkey_current_user, path.to_wide(), 0, 0x0001, voidptr(&key)) != 0 {
		return .unknown
	}
	defer {
		C.RegCloseKey(key)
	}
	mut value := u32(0)
	mut size := u32(sizeof(u32))
	mut kind := u32(0)
	// REG_DWORD is 4. The DWORD pointers go as voidptr: a DWORD is an
	// unsigned long, which C compilers do not take for V's u32.
	if C.RegQueryValueExW(key, 'AppsUseLightTheme'.to_wide(), unsafe { nil }, voidptr(&kind),
		voidptr(&value), voidptr(&size)) != 0 || kind != 4 {
		return .unknown
	}
	return if value == 0 { .dark } else { .light }
}
