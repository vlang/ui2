// Fallback for targets with no integration this layer can drive. Every
// desktop and mobile OS ships its own bridge file, so this only answers for
// the platforms none of them covers.
module ui2

fn native_haptic_supported() bool {
	return false
}

fn native_haptic(_style HapticStyle) bool {
	return false
}

fn native_app_badge_supported() bool {
	return false
}

fn native_set_app_badge(_count int) bool {
	return false
}

fn native_open_url_supported() bool {
	return false
}

fn native_open_url(_url string) bool {
	return false
}

fn native_share_supported() bool {
	return false
}

fn native_share_text(_text string) bool {
	return false
}
