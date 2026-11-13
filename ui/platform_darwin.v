// NSHapticFeedbackManager and NSDockTile only need the Objective-C runtime
// bridge, so this file serves custom-rendered macOS windows as well as the
// AppKit backend.
module ui2

import macos

#flag darwin -framework AppKit

fn native_haptic_supported() bool {
	return true
}

fn native_haptic(style HapticStyle) bool {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	performer := macos.msg_id(macos.get_class('NSHapticFeedbackManager'), 'defaultPerformer')
	if performer == unsafe { nil } {
		return false
	}
	// NSHapticFeedbackPattern values: generic, alignment and level change.
	pattern := match style {
		.light { 0 }
		.medium { 1 }
		.heavy { 2 }
		.selection { 1 }
		.success { 2 }
		.warning { 0 }
		.error { 2 }
	}
	macos.msg_void_i64(performer, 'performFeedbackPattern:', i64(pattern))
	return true
}

fn native_app_badge_supported() bool {
	return true
}

fn native_set_app_badge(count int) bool {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	app := macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	if app == unsafe { nil } {
		return false
	}
	tile := macos.msg_id(app, 'dockTile')
	if tile == unsafe { nil } {
		return false
	}
	label := if count <= 0 { '' } else { count.str() }
	macos.msg_void1(tile, 'setBadgeLabel:', macos.nsstring(label))
	return true
}

fn native_open_url_supported() bool {
	return true
}

fn native_open_url(url string) bool {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	workspace := macos.msg_id(macos.get_class('NSWorkspace'), 'sharedWorkspace')
	if workspace == unsafe { nil } {
		return false
	}
	target := macos.msg_id1(macos.get_class('NSURL'), 'URLWithString:', macos.nsstring(url))
	if target == unsafe { nil } {
		return false
	}
	return macos.msg_bool_id(workspace, 'openURL:', target)
}

// The share sheet picker anchors to a view the shared layer does not own, so
// macOS answers unsupported here; apps that need it draw their own target
// list on top of share-capable backends.
fn native_share_supported() bool {
	return false
}

fn native_share_text(_text string) bool {
	return false
}
