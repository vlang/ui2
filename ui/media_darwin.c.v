// macOS media through AVFoundation: audio and video playback, microphone
// recording, and one-shot screen snapshots. Video surfaces attach as an
// AVPlayerLayer of the element's own NSView (native backend) or of the
// custom renderer's window content (custom renderer).
module ui2

#flag darwin -framework AVFoundation -framework QuartzCore -framework Cocoa
#flag darwin -fno-objc-arc
#include "@VMODROOT/ui/media_apple.h"
#include "@VMODROOT/ui/media_apple.m"

import os

fn C.ui2_media_apple_open(cid &char, kind &char, src &char) int
fn C.ui2_media_apple_attach(cid &char, parent voidptr) voidptr
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

fn native_media_attach(id string, parent voidptr, _x f64, _y f64, _w f64, _h f64) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_apple_attach(id.str, parent) != unsafe { nil }
}

fn native_media_detach(id string) {
	// Layers detach on close; the session outlives the view so a rebuilt
	// element resumes without reopening the stream.
	if media_session(id) == none {
		return
	}
}

fn native_media_capture_supported(source MediaSource) bool {
	return source in [.microphone, .screen]
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

fn native_media_capture_screen(output_path string) bool {
	if output_path.trim_space().len == 0 {
		return false
	}
	res := os.execute('screencapture -x -t png "${output_path}"')
	return res.exit_code == 0
}
