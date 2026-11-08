module ui2

// clipboard_supported reports whether this platform has a system clipboard
// set_clipboard_text and clipboard_text can reach. Linux needs wl-clipboard,
// xclip or xsel installed; Android has none this layer can drive.
pub fn clipboard_supported() bool {
	return native_clipboard_supported()
}

// set_clipboard_text replaces the system clipboard with plain text, as a copy
// button does. It reports whether the platform took it. Text fields keep
// handling their own copy and paste; this is for copying anything else.
pub fn set_clipboard_text(text string) bool {
	return native_set_clipboard_text(text)
}

// clipboard_text returns the plain text on the system clipboard, or none when
// it holds no text or the platform has no clipboard this layer can read.
pub fn clipboard_text() ?string {
	return native_clipboard_text()
}

// set_primary_selection publishes X11-style primary selection text: select
// with the mouse, paste with the middle button, the copy path every mouse
// user reaches for before they think of the clipboard. Linux and the BSDs
// drive it through the same background tools as the clipboard; platforms
// without such a convention report false.
pub fn set_primary_selection(text string) bool {
	return native_set_primary_text(text)
}

// primary_selection_text returns the primary selection's plain text, or none
// where the selection does not exist or holds no text.
pub fn primary_selection_text() ?string {
	return native_primary_text()
}
