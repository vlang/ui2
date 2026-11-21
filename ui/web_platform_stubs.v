@[has_globals]
module ui2

// Platform-neutral backends (Linux, the BSDs, Solaris) do not supply the
// window hooks that native backends do. A headless web build has no native
// window at all, so provide the few hooks the portable UI code still calls.
// macOS/iOS/Windows define these themselves and must not see these stubs.
$if (linux || freebsd || openbsd || netbsd || dragonfly || solaris) && ui2_headless ? {
	// bounds feeds stylesheet media queries. The web app's logical size is the
	// framebuffer the browser renders, shared with the snapshot envelope.
	pub fn bounds() Rect {
		return web_bounds()
	}

	// request_refresh is a no-op on web. The event loop rebuilds and broadcasts
	// after each event; asking from a build would recurse back into refresh().
	pub fn request_refresh() {}

	// The default (non-Darwin/non-Windows) modifier hook reads this global. In
	// headless builds the native writer is compiled out, so declare it here.
	__global g_key_modifiers = KeyModifiers{}
}
