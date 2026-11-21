module ui2

import macos

#insert "@VMODROOT/ui/platform_ios.h"

fn C.ui2_platform_ios_string(bytes voidptr, length usize) voidptr

fn ios_platform_main_thread() bool {
	return macos.msg_bool(macos.get_class('NSThread'), 'isMainThread')
}

fn native_haptic_supported() bool {
	return true
}

// ios_impact_generator builds a UIImpactFeedbackGenerator for style, where 0,
// 1 and 2 are the light, medium and heavy UIImpactFeedbackStyle values.
// The returned object is owned by the caller (+1) and must be released.
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
	if !ios_platform_main_thread() {
		return false
	}
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
	if !ios_platform_main_thread() {
		return false
	}
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
	if !ios_platform_main_thread() {
		return false
	}
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
	// empty options and a nil handler the request is made on the main thread and
	// its outcome is not observed. This function therefore reports true when the
	// request was submitted for a valid app and URL. Avoid canOpenURL:, whose
	// scheme allowlist can reject schemes that openURL itself can open.
	options := macos.msg_id(macos.get_class('NSDictionary'), 'dictionary')
	macos.msg_void3(app, 'openURL:options:completionHandler:', target, options, objc_nil())
	return true
}

fn native_share_supported() bool {
	return true
}

fn native_share_text(text string) bool {
	if !ios_platform_main_thread() || g_root_vc == unsafe { nil } || g_root_view == unsafe { nil } {
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
	// macos.nsstring uses a NUL-terminated UTF-8 string. Share the full V
	// string, including embedded NULs, through a length-aware initializer.
	body := macos.Id(C.ui2_platform_ios_string(text.str, usize(text.len)))
	if objc_is_nil(body) {
		macos.release(items)
		return false
	}
	macos.msg_void1(items, 'addObject:', body)
	macos.release(body)

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
	// The presenting view controller retains activity for the sheet's lifetime;
	// release our own +1 reference.
	macos.release(activity)
	return true
}
