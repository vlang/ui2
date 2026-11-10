// Android media through OpenSL ES (NDK C API, no JVM needed): URI audio
// playback plus AAC/AMR microphone recording. Video has no NDK surface this
// layer can reach without a JVM callback, so it reports unsupported.
module ui2

import math

#flag android -lOpenSLES
#include "@VMODROOT/ui/media_android.h"

fn C.ui2_media_android_open(id &char, src &char) int
fn C.ui2_media_android_play(id &char) int
fn C.ui2_media_android_pause(id &char) int
fn C.ui2_media_android_stop(id &char) int
fn C.ui2_media_android_seek(id &char, ms int) int
fn C.ui2_media_android_set_volume_db(id &char, millibel int) int
fn C.ui2_media_android_set_mute(id &char, muted int) int
fn C.ui2_media_android_set_rate(id &char, per_mille int) int
fn C.ui2_media_android_position_ms(id &char) int
fn C.ui2_media_android_state(id &char) int
fn C.ui2_media_android_close(id &char)
fn C.ui2_media_android_record_start(id &char, path &char) int
fn C.ui2_media_android_record_stop(id &char) int

// media_android_millibel maps 0..1 to the SLVolumeItf range; silence bottoms
// out at -100dB instead of asking logarithms about zero.
fn media_android_millibel(volume f64) int {
	if volume <= 0.001 {
		return -10000
	}
	return int(2000.0 * math.log10(media_clamped_volume(volume)))
}

fn native_media_supported(kind MediaKind) bool {
	return kind == .audio
}

fn native_media_open(id string, kind MediaKind, src string) bool {
	if id.trim_space().len == 0 || src.trim_space().len == 0 {
		return false
	}
	if kind != .audio {
		return false
	}
	return C.ui2_media_android_open(id.str, src.str) != 0
}

fn native_media_play(id string) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_android_play(id.str) != 0
}

fn native_media_pause(id string) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_android_pause(id.str) != 0
}

fn native_media_stop(id string) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_android_stop(id.str) != 0
}

fn native_media_seek(id string, secs f64) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_android_seek(id.str, int(secs * 1000.0)) != 0
}

fn native_media_set_volume(id string, volume f64) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_android_set_volume_db(id.str, media_android_millibel(volume)) != 0
}

fn native_media_set_muted(id string, muted bool) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_android_set_mute(id.str, if muted { 1 } else { 0 }) != 0
}

fn native_media_set_rate(id string, rate f64) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_android_set_rate(id.str, int(rate * 1000.0)) != 0
}

fn native_media_set_loop(_id string, _loop bool) bool {
	// No end-of-stream signal reaches this layer, so looping cannot settle.
	return false
}

fn native_media_close(id string) {
	C.ui2_media_android_close(id.str)
}

fn native_media_position(id string) f64 {
	if media_session(id) == none {
		return -1.0
	}
	ms := C.ui2_media_android_position_ms(id.str)
	if ms < 0 {
		return -1.0
	}
	return f64(ms) / 1000.0
}

fn native_media_duration(_id string) f64 {
	// No metadata interface is queried; streams report unknown length.
	return -1.0
}

fn native_media_state(id string) MediaState {
	if media_session(id) == none {
		return .idle
	}
	return match C.ui2_media_android_state(id.str) {
		2 { .playing }
		3 { .paused }
		4 { .stopped }
		7 { .recording }
		else { .idle }
	}
}

fn native_media_can_seek(id string) bool {
	return media_session(id) != none
}

fn native_media_attach(_id string, _parent voidptr, _x f64, _y f64, _w f64, _h f64) bool {
	return false
}

fn native_media_detach(_id string) {
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
	return C.ui2_media_android_record_start(id.str, output_path.str) != 0
}

fn native_media_stop_recording(id string) bool {
	if media_session(id) == none {
		return false
	}
	return C.ui2_media_android_record_stop(id.str) != 0
}

fn native_media_capture_screen(_output_path string) bool {
	return false
}
