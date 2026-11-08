// Android has no alert a NativeActivity app can reach without a JVM callback
// this layer does not install, so message_box_supported is false there and
// callers reach custom_message_box instead. The _android file suffix is what
// keeps this compiling: V claims every _nix file for Android too, and
// message_box_nix's body is spelled out for the desktops, so without an
// os-specific file of its own the message box's functions would not exist at
// all on Android.
module ui2

fn native_message_box_supported() bool {
	return false
}

fn native_message_box(cfg MessageBoxConfig) MessageBoxResult {
	// Answer as if the user dismissed the dialog, and say the message out
	// loud so it is not swallowed.
	eprintln('ui2: ${cfg.title} ${cfg.text}')
	return message_box_default_result(cfg.buttons)
}
