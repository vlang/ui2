// Fallback for targets with no media stack this layer can drive: every
// answer is the graceful unsupported one, so portable code keeps compiling
// and `media_playback_supported` / `media_capture_supported` stay honest.
module ui2

fn native_media_supported(_kind MediaKind) bool {
	return false
}

fn native_media_open(_id string, _kind MediaKind, _src string) bool {
	return false
}

fn native_media_play(_id string) bool {
	return false
}

fn native_media_pause(_id string) bool {
	return false
}

fn native_media_stop(_id string) bool {
	return false
}

fn native_media_seek(_id string, _secs f64) bool {
	return false
}

fn native_media_set_volume(_id string, _volume f64) bool {
	return false
}

fn native_media_set_muted(_id string, _muted bool) bool {
	return false
}

fn native_media_set_rate(_id string, _rate f64) bool {
	return false
}

fn native_media_set_loop(_id string, _loop bool) bool {
	return false
}

fn native_media_close(_id string) {
}

fn native_media_position(_id string) f64 {
	return -1.0
}

fn native_media_duration(_id string) f64 {
	return -1.0
}

fn native_media_state(_id string) MediaState {
	return .idle
}

fn native_media_can_seek(_id string) bool {
	return false
}

fn native_media_attach(_id string, _parent voidptr, _x f64, _y f64, _w f64, _h f64) bool {
	return false
}

fn native_media_detach(_id string) {
}

fn native_media_capture_supported(_source MediaSource) bool {
	return false
}

fn native_media_start_recording(_id string, _source MediaSource, _output_path string) bool {
	return false
}

fn native_media_stop_recording(_id string) bool {
	return false
}

fn native_media_capture_screen(_output_path string) bool {
	return false
}
