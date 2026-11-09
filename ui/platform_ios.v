module ui2

import macos

fn native_haptic_supported() bool {
	return true
}

// ios_impact_generator builds a UIImpactFeedbackGenerator for style, where 0,
// 1 and 2 are the light, medium and heavy UIImpactFeedbackStyle values.
fn ios_impact_generator(style u64) macos.Id {
	generator := macos.msg_id_u64(macos.alloc('UIImpactFeedbackGenerator'), 'initWithStyle:',
		style)
	if objc_is_nil(generator) {
		return generator
	}
	macos.msg_void(generator, 'prepare')
	return generator
}

fn native_haptic(style HapticStyle) bool {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	match style {
		.light {
			generator := ios_impact_generator(0)
			if objc_is_nil(generator) {
				return false
			}
			macos.msg_void(generator, 'impactOccurred')
		}
		.medium {
			generator := ios_impact_generator(1)
			if objc_is_nil(generator) {
				return false
			}
			macos.msg_void(generator, 'impactOccurred')
		}
		.heavy {
			generator := ios_impact_generator(2)
			if objc_is_nil(generator) {
				return false
			}
			macos.msg_void(generator, 'impactOccurred')
		}
		.selection {
			generator := macos.msg_id(macos.alloc('UISelectionFeedbackGenerator'), 'init')
			if objc_is_nil(generator) {
				return false
			}
			macos.msg_void(generator, 'selectionChanged')
		}
		.success, .warning, .error {
			generator := macos.msg_id(macos.alloc('UINotificationFeedbackGenerator'), 'init')
			if objc_is_nil(generator) {
				return false
			}
			kind := match style {
				.success { 0 }
				.warning { 1 }
				else { 2 }
			}
			macos.msg_void_i64(generator, 'notificationOccurred:', i64(kind))
		}
	}
	return true
}

fn native_app_badge_supported() bool {
	return true
}

fn native_set_app_badge(count int) bool {
	app := macos.msg_id(macos.get_class('UIApplication'), 'sharedApplication')
	if objc_is_nil(app) {
		return false
	}
	macos.msg_void_i64(app, 'setApplicationIconBadgeNumber:', i64(count))
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
	app := macos.msg_id(macos.get_class('UIApplication'), 'sharedApplication')
	if objc_is_nil(app) {
		return false
	}
	target := macos.msg_id1(macos.get_class('NSURL'), 'URLWithString:', macos.nsstring(url))
	if objc_is_nil(target) {
		return false
	}
	return macos.msg_bool_id(app, 'openURL:', target)
}

fn native_share_supported() bool {
	return true
}

fn native_share_text(text string) bool {
	if g_root_vc == unsafe { nil } || g_root_view == unsafe { nil } {
		return false
	}
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	items := macos.msg_id(macos.alloc('NSMutableArray'), 'init')
	if objc_is_nil(items) {
		return false
	}
	macos.msg_void1(items, 'addObject:', macos.nsstring(text))
	activity := macos.msg_id2(macos.get_class('UIActivityViewController'), 'initWithActivityItems:applicationActivities:',
		items, objc_nil())
	if objc_is_nil(activity) {
		return false
	}
	// iPad shows the sheet in a popover anchored to the root view; iPhone
	// ignores the anchor and slides the sheet up from the bottom.
	popover := macos.msg_id(activity, 'popoverPresentationController')
	if !objc_is_nil(popover) {
		macos.msg_void1(popover, 'setSourceView:', g_root_view)
		macos.msg_void_rect(popover, 'setSourceRect:', macos.msg_rect(g_root_view,
			'bounds'))
	}
	macos.msg_void_id_i64_id(top_view_controller(g_root_vc), 'presentViewController:animated:completion:',
		activity, 1, objc_nil())
	return true
}
