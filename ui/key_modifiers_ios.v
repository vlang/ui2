module ui2

// A touch screen holds no modifier keys; a hardware keyboard's are not tracked.
fn native_key_modifiers() KeyModifiers {
	return KeyModifiers{}
}
