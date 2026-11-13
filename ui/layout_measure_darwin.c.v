// Keep AppKit imports behind the native backend switch so custom builds do not
// mix AppKit's MRC bridge with Sokol's ARC sources.
module ui2

$if macos && !ui2_custom_rendering ?&& !ui2_headless ? {
	import macos

	fn layout_measure_appkit_text(text string, style TextStyle, max_width f64) !LayoutSize {
		// NOTE(V 0.5.2 CI): AppKit `msg_point` (NSSize) does not exist in 0.5.2's
		// `macos` bridge, so disable AppKit measurement here; callers fall back
		// to CPU fontstash measurement, which is font-metrics robust in tests.
		return error('V 0.5.2: AppKit text measurement disabled')
	}
}
