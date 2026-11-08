@[has_globals]
module ui2

import os
import sokol.sapp

#flag -I @VMODROOT/ui
#include "file_dialog_android.h"

fn C.ui2_android_start_file_picker(activity voidptr, multiple int) int

// The Android picker is the system document picker. The activity opens it and,
// when it returns, copies the chosen files into the app's files directory and
// writes their paths to picker/result.txt; an empty file is a cancel. The request
// does not wait for it: the frame loop checks for the result file, because a wait
// on the frame thread stops the app from handling input and Android closes it.
__global g_android_picker_result = ''
__global g_android_picker_done = FileDialogDoneFn(unsafe { nil })

fn android_activity() &os.NativeActivity {
	return unsafe { &os.NativeActivity(sapp.android_get_native_activity()) }
}

fn native_file_dialog_supported() bool {
	return !isnil(android_activity())
}

// native_file_dialog is the blocking form the desktops' callers use; on Android it
// has nothing to block on, so it answers with no files.
fn native_file_dialog(cfg FileDialogConfig) []string {
	return []string{}
}

fn android_request_file_dialog(cfg FileDialogConfig, on_done FileDialogDoneFn) {
	act := android_activity()
	if isnil(act) {
		on_done([]string{})
		return
	}
	dir := os.join_path(unsafe { cstring_to_vstring(act.internalDataPath) }, 'picker')
	os.mkdir_all(dir) or {
		on_done([]string{})
		return
	}
	result := os.join_path(dir, 'result.txt')
	os.rm(result) or {}
	if C.ui2_android_start_file_picker(voidptr(act), if cfg.multiple { 1 } else { 0 }) == 0 {
		eprintln('ui2: the file picker could not be opened')
		on_done([]string{})
		return
	}
	g_android_picker_result = result
	g_android_picker_done = on_done
}

// android_poll_file_dialog delivers the picker's answer once the activity has
// written it. It runs every frame, so it does no more than a file check until
// then.
fn android_poll_file_dialog() {
	if g_android_picker_result.len == 0 {
		return
	}
	if !os.is_file(g_android_picker_result) {
		// An on-demand window stays idle unless asked, so keep frames coming
		// while the answer is pending.
		g_gg_app.scheduler.invalidate(.paint)
		return
	}
	text := os.read_file(g_android_picker_result) or { '' }
	os.rm(g_android_picker_result) or {}
	mut paths := []string{}
	for line in text.split_into_lines() {
		if line.len > 0 {
			paths << line
		}
	}
	done := g_android_picker_done
	g_android_picker_result = ''
	g_android_picker_done = FileDialogDoneFn(unsafe { nil })
	if voidptr(done) != unsafe { nil } {
		done(paths)
	}
}
