module ui2

// KeyModifiers are the modifier keys held at a moment. `cmd` is Command on Apple
// platforms and the Windows key elsewhere, as in KeyEvent.
pub struct KeyModifiers {
pub:
	shift bool
	ctrl  bool
	alt   bool
	cmd   bool
}

// key_modifiers reports the modifier keys held right now. Pointer events do not
// carry them, so a click handler asks here to tell a Shift- or Cmd-click apart.
pub fn key_modifiers() KeyModifiers {
	return native_key_modifiers()
}
