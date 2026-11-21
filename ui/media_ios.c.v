// iOS media through AVFoundation: audio and video playback plus microphone
// recording, sharing the Apple bridge in media_apple.m. Screen capture
// needs ReplayKit UI integration, so it reports unsupported.
module ui2

#flag ios -framework AVFoundation
#flag ios -framework QuartzCore
#flag ios -framework UIKit
#flag ios -fno-objc-arc
#include "@VMODROOT/ui/media_apple.h"
#include "@VMODROOT/ui/media_apple.m"

fn C.ui2_media_apple_open(cid &char, kind &char, src &char) int
fn C.ui2_media_apple_attach(cid &char, parent voidptr, x f64, y f64, w f64, h f64) voidptr
fn C.ui2_media_apple_detach(cid &char)
fn C.ui2_media_apple_play(cid &char)
fn C.ui2_media_apple_pause(cid &char)
fn C.ui2_media_apple_stop(cid &char)
fn C.ui2_media_apple_seek(cid &char, secs f64)
fn C.ui2_media_apple_set_volume(cid &char, volume f64)
fn C.ui2_media_apple_set_mute(cid &char, muted int)
fn C.ui2_media_apple_set_rate(cid &char, rate f64)
fn C.ui2_media_apple_set_loop(cid &char, loop int)
fn C.ui2_media_apple_close(cid &char)
fn C.ui2_media_apple_position(cid &char) f64
fn C.ui2_media_apple_duration(cid &char) f64
fn C.ui2_media_apple_state(cid &char) int
fn C.ui2_media_apple_can_seek(cid &char) int
fn C.ui2_media_apple_record_start(cid &char, path &char) int
fn C.ui2_media_apple_record_stop(cid &char) int

fn media_apple_kind(kind MediaKind) string {
	return if kind == .video { 'video' } else { 'audio' }
}

fn native_media_supported(_kind MediaKind) bool {
	return true
}

fn native_media_open(id string, kind MediaKind, src string) bool {
	if id.trim_space().len == 0 || src.trim_space().len == 0 {
		return false
	}
	return C.ui2_media_apple_open(id.str, media_apple_kind(kind).str, src.str) != 0
}

fn native_media_play(id string) bool {
	if media_session(id) == none {
		return false
	}
	C.ui2_media_apple_play(id.str)
	return true
}

fn native_media_pause(id string) bool {
	if media_session(id) == none {
		return false
	}
	C.ui2_media_apple_pause(id.str)
	return true
}

fn native_media_stop(id string) bool {
	if media_session(id) == none {
		return false
	}
	C.ui2_media_apple_stop(id.str)
	return true
}

fn native_media_seek(id string, secs f64) bool {
	if media_session(id) == none {
		return false
	}
	C.ui2_media_apple_seek(id.str, secs)
	return true
}

fn native_media_set_volume(id string, volume f64) bool {
	if media_session(id) == none {
		return false
	}
	C.ui2_media_apple_set_volume(id.str, volume)
	return true
}

fn native_media_set_muted(id string, muted bool) bool {
	if media_session(id) == none {
		return false
	}
	C.ui2_media_apple_set_mute(id.str, if muted { 1 } else { 0 })
	return true
}

fn native_media_set_rate(id string, rate f64) bool {
	if media_session(id) == none {
		return false
	}
	C.ui2_media_apple_set_rate(id.str, rate)
	return true
}

fn native_media_set_loop(id string, loop bool) bool {
	if media_session(id) == none {
		return false
	}
	C.ui2_media_apple_set_loop(id.str, if loop { 1 } else { 0 })
	return true
}

fn native_media_close(id string) {
	C.ui2_media_apple_close(id.str)
}

fn native_media_position(id string) f64 {
	if media_session(id) == none {
		return -1.0
	}
	return C.ui2_media_apple_position(id.str)
}

fn native_media_duration(id string) f64 {
	if media_session(id) == none {
		return -1.0
	}
	return C.ui2_media_apple_duration(id.str)
}

fn native_media_state(id string) MediaState {
	if media_session(id) == none {
		return .idle
	}
	return match C.ui2_media_apple_state(id.str) {
		1 { .loading }
		2 { .playing }
		3 { .paused }
		4 { .stopped }
		5 { .ended }
		6 { .error }
		7 { .recording }
		else { .idle }
	}
}

fn native_media_can_seek(id string) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_apple_can_seek(id.str) != 0
}

fn native_media_attach(id string, parent voidptr, x f64, y f64, w f64, h f64) bool {
	session := media_session(id) or { return false }
	// media_sync_native opens audio only; a video() declaration needs its
	// Apple player created before the layer can attach to the view.
	if !native_media_open(id, session.kind, session.src) {
		return false
	}
	return C.ui2_media_apple_attach(id.str, parent, x, y, w, h) != unsafe { nil }
}

fn native_media_detach(id string) {
	if media_session(id) == none {
		return
	}
	C.ui2_media_apple_detach(id.str)
}

fn native_media_capture_supported(source MediaSource) bool {
	return source == .microphone
}

fn native_media_start_recording(id string, source MediaSource, output_path string) bool {
	if source != .microphone {
		return false
	}
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_apple_record_start(id.str, output_path.str) != 0
}

fn native_media_stop_recording(id string) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_apple_record_stop(id.str) != 0
}

fn native_media_capture_screen(_output_path string) bool {
	// ReplayKit capture needs app-level broadcast UI; out of scope for v1.
	return false
}
