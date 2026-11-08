module ui2

#flag windows -luser32

fn C.GetKeyState(key int) i16

fn key_held(key int) bool {
	return u16(C.GetKeyState(key)) & 0x8000 != 0
}

// VK_SHIFT, VK_CONTROL, VK_MENU (Alt) and the two Windows keys.
fn native_key_modifiers() KeyModifiers {
	return KeyModifiers{
		shift: key_held(0x10)
		ctrl:  key_held(0x11)
		alt:   key_held(0x12)
		cmd:   key_held(0x5b) || key_held(0x5c)
	}
}
