// Fallback for targets with no clipboard this layer can drive — Android, whose
// ClipboardManager needs a JVM callback the C backend cannot install.
module ui2

fn native_clipboard_supported() bool {
	return false
}

fn native_set_clipboard_text(_text string) bool {
	return false
}

fn native_clipboard_text() ?string {
	return none
}

// Primary selection has no counterpart on platforms without an X11-style
// middle-button paste: both halves answer unsupported there.
fn native_set_primary_text(_ string) bool {
	return false
}

fn native_primary_text() ?string {
	return none
}
