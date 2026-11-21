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
			macos.release(generator)
		}
		.medium {
			generator := ios_impact_generator(1)
			if objc_is_nil(generator) {
				return false
			}
			macos.msg_void(generator, 'impactOccurred')
			macos.release(generator)
		}
		.heavy {
			generator := ios_impact_generator(2)
			if objc_is_nil(generator) {
				return false
			}
			macos.msg_void(generator, 'impactOccurred')
			macos.release(generator)
		}
		.selection {
			generator := macos.msg_id(macos.alloc('UISelectionFeedbackGenerator'), 'init')
			if objc_is_nil(generator) {
				return false
			}
			macos.msg_void(generator, 'selectionChanged')
			macos.release(generator)
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
			macos.release(generator)
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
	// UIApplication.openURL: is deprecated and returns false on iOS 18+ SDKs.
	// openURL:options:completionHandler: (iOS 10+) is asynchronous and returns
	// void, so the OS result is delivered only to the completion handler. With
	// nil options and a nil handler the request is queued on the main thread and
	// its outcome is not observed. This function therefore reports true when the
	// request was queued against a valid app and URL, and false only when those
	// objects could not be obtained.
	macos.msg_void3(app, 'openURL:options:completionHandler:', target, objc_nil(), objc_nil())
	return true
}

fn native_share_supported() bool {
	return true
}

fn native_share_text(text string) bool {
	if g_root_vc == unsafe { nil } || g_root_view == unsafe { nil } {
		return false
	}
	// UIKit presents view controllers on the main thread only; a share fired
	// from a render or event thread answers false instead of presenting from
	// the wrong thread.
	if !macos.msg_bool(macos.get_class('NSThread'), 'isMainThread') {
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
	// initWithActivityItems:applicationActivities: is an instance initializer:
	// it must be sent to an allocated instance, not to the class object.
	mut activity := macos.alloc('UIActivityViewController')
	if objc_is_nil(activity) {
		macos.release(items)
		return false
	}
	activity = macos.msg_id2(activity, 'initWithActivityItems:applicationActivities:', items,
		objc_nil())
	// The controller retains/copies the items array once initialized, so drop
	// our own +1 reference on every path after the initializer has run.
	macos.release(items)
	if objc_is_nil(activity) {
		// A failed initializer consumed and released the allocated instance.
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
	// The presentation retains both; the caller's +1 references are released.
	macos.release(activity)
	macos.release(items)
	return true
}
