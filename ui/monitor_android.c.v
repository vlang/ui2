// Android's refresh rate is a SurfaceFlinger property this layer cannot read
// without a JVM callback, so the answer is 0 and callers keep their
// fallbacks — vendetta takes the rate on its --display-fps flag instead. The
// _android file suffix is what keeps this compiling: V claims every _nix file
// for Android too, and monitor_nix's body is spelled out for the X11
// desktops, so without an os-specific file of its own the rate reader would
// not exist at all on Android.
module ui2

fn native_monitor_refresh_rate() f64 {
	return 0
}
