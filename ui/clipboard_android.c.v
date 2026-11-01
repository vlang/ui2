// Android has no clipboard a NativeActivity app can reach without a JVM
// callback this layer does not install, so every answer is the empty one.
// The _android file suffix is what keeps this compiling: V claims every _nix
// file for Android too, and clipboard_nix's body is spelled out for the
// desktops, so without an os-specific file of its own the clipboard's
// functions would not exist at all on Android.
module ui2

fn native_clipboard_supported() bool {
	return false
}

fn native_set_clipboard_text(_ string) bool {
	return false
}

fn native_clipboard_text() ?string {
	return none
}

fn native_set_primary_text(_ string) bool {
	return false
}

fn native_primary_text() ?string {
	return none
}
