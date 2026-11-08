// iOS's refresh rate is a CADisplayLink property this layer does not read
// yet, so the answer is 0 and callers keep their fallbacks. The _ios file
// suffix is what keeps this compiling: monitor_darwin claims the _darwin
// suffix for iOS too, and its body is spelled out for the Mac, so without an
// os-specific file of its own the rate reader would not exist on iOS.
module ui2

fn native_monitor_refresh_rate() f64 {
	return 0
}
