// Android drives its integrations through JNI only, so no Java code or
// activity subclass is needed: the vibrator, the VIEW/SEND intents and the
// chooser all resolve on the NativeActivity's own classes. The _android file
// suffix is what keeps this compiling: V claims every _nix file for Android
// too, and platform_nix's body is spelled out for the desktops, so without an
// os-specific file of its own the platform functions would not exist at all
// on Android.
module ui2

import os
import sokol.sapp

#flag -I @VMODROOT/ui
#include "platform_android.h"

fn C.ui2_android_haptic(activity voidptr, duration_ms int, amplitude int) int
fn C.ui2_android_open_url(activity voidptr, url &char) int
fn C.ui2_android_share_text(activity voidptr, text &char) int

// android_platform_activity answers the running NativeActivity, or nil
// outside an Android runtime.
fn android_platform_activity() voidptr {
	return sapp.android_get_native_activity()
}

fn native_haptic_supported() bool {
	return android_platform_activity() != unsafe { nil }
}

fn native_haptic(style HapticStyle) bool {
	act := android_platform_activity()
	if act == unsafe { nil } {
		return false
	}
	duration_ms, amplitude := match style {
		.light { 20, 80 }
		.medium { 40, 140 }
		.heavy { 60, 255 }
		.selection { 12, 60 }
		.success { 30, 170 }
		.warning { 50, 220 }
		.error { 70, 255 }
	}
	return C.ui2_android_haptic(act, duration_ms, amplitude) != 0
}

fn native_app_badge_supported() bool {
	return false
}

fn native_set_app_badge(_count int) bool {
	return false
}

fn native_open_url_supported() bool {
	return android_platform_activity() != unsafe { nil }
}

fn native_open_url(url string) bool {
	act := android_platform_activity()
	if act == unsafe { nil } {
		return false
	}
	return C.ui2_android_open_url(act, &char(url.str)) != 0
}

fn native_share_supported() bool {
	return android_platform_activity() != unsafe { nil }
}

fn native_share_text(text string) bool {
	act := android_platform_activity()
	if act == unsafe { nil } {
		return false
	}
	return C.ui2_android_share_text(act, &char(text.str)) != 0
}
