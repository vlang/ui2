module ui2

// HapticStyle names the platform haptic a call to haptic plays: three impact
// weights, the light tick of moving a selection, and the three notification
// outcomes. Backends without a haptics engine answer unsupported instead.
pub enum HapticStyle {
	light
	medium
	heavy
	selection
	success
	warning
	error
}

// haptic_supported reports whether haptic can make the device buzz on this
// platform. iOS, macOS (Force Touch hardware) and Android answer true;
// Windows, Linux and the BSDs have no engine this layer drives.
pub fn haptic_supported() bool {
	return native_haptic_supported()
}

// haptic plays style and reports whether the platform took it. It never
// blocks and never raises: without an engine it answers false.
pub fn haptic(style HapticStyle) bool {
	return native_haptic(style)
}

// app_badge_supported reports whether set_app_badge can stamp a number on the
// application's icon: iOS and macOS dock tiles answer true.
pub fn app_badge_supported() bool {
	return native_app_badge_supported()
}

// set_app_badge stamps count on the application icon — the unread dot iOS and
// macOS draw over it — and reports whether the platform took it. Zero clears
// the stamp; a negative count is rejected.
pub fn set_app_badge(count int) bool {
	if count < 0 {
		return false
	}
	return native_set_app_badge(count)
}

// open_url_supported reports whether open_url can hand a link to the
// platform: every backend answers true except the ones with no opener.
pub fn open_url_supported() bool {
	return native_open_url_supported()
}

// open_url opens url in the default browser, mail client or app that owns it,
// and reports whether the platform took it. Only http, https and mailto links
// with an address are accepted; anything else is rejected without touching
// the platform.
pub fn open_url(url string) bool {
	if !platform_valid_url(url) {
		return false
	}
	return native_open_url(url)
}

// share_supported reports whether share_text can open the platform share
// sheet: iOS and Android answer true.
pub fn share_supported() bool {
	return native_share_supported()
}

// share_text opens the platform share sheet with content and reports whether
// the platform took it. Blank content is rejected without touching the
// platform.
pub fn share_text(content string) bool {
	if content.trim_space().len == 0 {
		return false
	}
	return native_share_text(content)
}

// platform_valid_url accepts the links open_url can hand over: http and https
// URLs with something after the scheme separator, and mailto links with an
// address. Anything with whitespace or control characters is rejected, since
// no opener takes it verbatim.
fn platform_valid_url(url string) bool {
	candidate := url.trim_space()
	if candidate.len == 0 {
		return false
	}
	for ch in candidate.bytes() {
		if ch <= 32 || ch == 127 {
			return false
		}
	}
	if candidate.starts_with('mailto:') {
		addr := candidate['mailto:'.len..]
		return addr.len > 0 && addr.contains('@')
	}
	sep := candidate.index('://') or { return false }
	if sep <= 0 || candidate.len <= sep + 3 {
		return false
	}
	scheme := candidate[..sep]
	return scheme == 'http' || scheme == 'https'
}
