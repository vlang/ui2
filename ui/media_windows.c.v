// Windows media through MCI (winmm) plus a GDI screen grab: every Windows
// install can play, record and screenshot without extra libraries. The same
// file serves the native backend and the custom renderer; both hand the
// parent window of each video surface to `native_media_attach`.
@[has_globals]
module ui2

#flag windows -lwinmm -lgdi32
#include "@VMODROOT/windows/media_windows.h"

fn C.ui2_mci_send(command &u16, result &u16, result_len u32) u32
fn C.ui2_mci_error_text(code u32, text &u16, text_len u32) int
fn C.ui2_media_screenshot(path &u16) int
fn C.wcslen(text &u16) u32

__global g_media_win_aliases = map[string]string{}
__global g_media_win_counter = 0
__global g_media_win_open = map[string]bool{}
__global g_media_win_rects = map[string]string{}

// media_mci runs one MCI command string, returning ok plus any text result.
fn media_mci(command string) (bool, string) {
	wide := command.to_wide()
	mut out := []u16{len: 512}
	code := C.ui2_mci_send(wide, unsafe { &out[0] }, 512)
	unsafe { free(wide) }
	if code != 0 {
		return false, ''
	}
	length := int(C.wcslen(unsafe { &out[0] }))
	if length <= 0 {
		return true, ''
	}
	return true, unsafe { string_from_wide2(&out[0], length) }
}

fn media_win_alias(id string) string {
	if alias := g_media_win_aliases[id] {
		return alias
	}
	g_media_win_counter++
	alias := 'ui2m${g_media_win_counter}'
	g_media_win_aliases[id] = alias
	return alias
}

fn media_win_drop_alias(id string) {
	if alias := g_media_win_aliases[id] {
		media_mci('close ${alias}')
		g_media_win_aliases.delete(id)
	}
	g_media_win_open.delete(id)
	g_media_win_rects.delete(id)
}

// media_win_type maps a source to its MCI device: the mpegvideo driver plays
// the common containers, streams and PCM wave files and honors the full
// transport (seek, volume, rate); the waveaudio driver cannot even change
// volume, so only MIDI keeps its sequencer and recording keeps waveaudio.
fn media_win_type(_kind MediaKind, src string) string {
	lowered := src.to_lower()
	if lowered.ends_with('.mid') || lowered.ends_with('.midi') || lowered.ends_with('.rmi') {
		return 'sequencer'
	}
	return 'mpegvideo'
}

fn native_media_supported(kind MediaKind) bool {
	return kind in [.audio, .video]
}

// native_media_open readies audio at once; video opens on attach, once its
// parent window is known, so no stray popup ever appears for headless use.
fn native_media_open(id string, kind MediaKind, src string) bool {
	if id.trim_space().len == 0 || src.trim_space().len == 0 {
		return false
	}
	if kind == .video {
		return true
	}
	media_win_drop_alias(id)
	alias := media_win_alias(id)
	ok, _ := media_mci('open "${src}" type ${media_win_type(kind, src)} alias ${alias}')
	if !ok {
		media_win_drop_alias(id)
		return false
	}
	media_mci('set ${alias} time format milliseconds')
	g_media_win_open[id] = true
	return true
}

fn native_media_play(id string) bool {
	session := media_session(id) or { return false }
	if session.kind == .video && session.surface == unsafe { nil } {
		return false
	}
	alias := g_media_win_aliases[id] or { return false }
	if !(g_media_win_open[id] or { false }) {
		return false
	}
	ok, _ := media_mci('play ${alias}')
	return ok
}

fn native_media_pause(id string) bool {
	alias := g_media_win_aliases[id] or { return false }
	ok, _ := media_mci('pause ${alias}')
	return ok
}

fn native_media_stop(id string) bool {
	alias := g_media_win_aliases[id] or { return true }
	ok, _ := media_mci('stop ${alias}')
	media_mci('seek ${alias} to start')
	return ok
}

fn native_media_seek(id string, secs f64) bool {
	alias := g_media_win_aliases[id] or { return false }
	ms := int(secs * 1000.0)
	ok, _ := media_mci('seek ${alias} to ${ms}')
	return ok
}

fn native_media_set_volume(id string, volume f64) bool {
	alias := g_media_win_aliases[id] or { return false }
	ok, _ := media_mci('setaudio ${alias} volume to ${int(volume * 1000.0)}')
	return ok
}

fn native_media_set_muted(id string, muted bool) bool {
	alias := g_media_win_aliases[id] or { return false }
	ok, _ := media_mci(if muted { 'setaudio ${alias} off' } else { 'setaudio ${alias} on' })
	return ok
}

fn native_media_set_rate(id string, rate f64) bool {
	alias := g_media_win_aliases[id] or { return false }
	ok, _ := media_mci('set ${alias} speed ${int(rate * 1000.0)}')
	return ok
}

fn native_media_set_loop(_id string, _loop bool) bool {
	// Looping is settled in `media_state` from position and duration, so the
	// player itself needs nothing.
	return true
}

fn native_media_close(id string) {
	media_win_drop_alias(id)
}

fn native_media_position(id string) f64 {
	alias := g_media_win_aliases[id] or { return -1.0 }
	ok, result := media_mci('status ${alias} position')
	if !ok {
		return -1.0
	}
	return f64(result.int()) / 1000.0
}

fn native_media_duration(id string) f64 {
	alias := g_media_win_aliases[id] or { return -1.0 }
	ok, result := media_mci('status ${alias} length')
	if !ok {
		return -1.0
	}
	return f64(result.int()) / 1000.0
}

fn native_media_state(id string) MediaState {
	alias := g_media_win_aliases[id] or { return .idle }
	if !(g_media_win_open[id] or { false }) {
		return .idle
	}
	ok, mode := media_mci('status ${alias} mode')
	if !ok {
		return .idle
	}
	if mode == 'playing' {
		return .playing
	}
	if mode == 'paused' {
		return .paused
	}
	return .stopped
}

fn native_media_can_seek(id string) bool {
	return g_media_win_open[id] or { false }
}

// native_media_attach opens the video device on first sight (parented to the
// backend's window, so no popup escapes) and keeps its picture on the
// element's frame. Audio never reaches this function.
fn native_media_attach(id string, parent voidptr, x f64, y f64, w f64, h f64) bool {
	mut session := media_session(id) or { return false }
	if session.kind != .video || parent == unsafe { nil } {
		return false
	}
	if !(g_media_win_open[id] or { false }) {
		media_win_drop_alias(id)
		alias := media_win_alias(id)
		parent_handle := u64(parent)
		ok, _ := media_mci('open "${session.src}" type ${media_win_type(session.kind, session.src)} alias ${alias} style child parent ${parent_handle}')
		if !ok {
			media_win_drop_alias(id)
			return false
		}
		media_mci('set ${alias} time format milliseconds')
		g_media_win_open[id] = true
		session.state = .stopped
		session.duration = native_media_duration(id)
	}
	alias := g_media_win_aliases[id] or { return false }
	rect := '${int(x)}:${int(y)}:${int(w)}:${int(h)}'
	if g_media_win_rects[id] != rect {
		media_mci('put ${alias} window at ${int(x)} ${int(y)} ${int(w)} ${int(h)}')
		g_media_win_rects[id] = rect
	}
	media_mci('window ${alias} state show')
	session.surface = parent
	return true
}

fn native_media_detach(id string) {
	// The video window belongs to MCI; hiding keeps the session while the
	// element is only briefly gone (scrolling, tab switches).
	if alias := g_media_win_aliases[id] {
		media_mci('window ${alias} state hide')
	}
}

fn native_media_capture_supported(source MediaSource) bool {
	return source in [.microphone, .screen]
}

fn native_media_start_recording(id string, source MediaSource, output_path string) bool {
	if source != .microphone {
		return false
	}
	media_win_drop_alias(id)
	alias := media_win_alias(id)
	mut ok, _ := media_mci('open new type waveaudio alias ${alias}')
	if !ok {
		media_win_drop_alias(id)
		return false
	}
	media_mci('set ${alias} time format milliseconds')
	media_mci('set ${alias} samplespersec 44100')
	media_mci('set ${alias} bitspersample 16')
	media_mci('set ${alias} channels 1')
	media_mci('set ${alias} bytespersec 88200')
	media_mci('set ${alias} alignment 2')
	ok, _ = media_mci('record ${alias}')
	if !ok {
		media_win_drop_alias(id)
		return false
	}
	g_media_win_open[id] = true
	return true
}

fn native_media_stop_recording(id string) bool {
	alias := g_media_win_aliases[id] or { return false }
	session := media_session(id) or { return false }
	media_mci('stop ${alias}')
	ok, _ := media_mci('save ${alias} "${session.record_path}"')
	media_win_drop_alias(id)
	return ok
}

fn native_media_capture_screen(output_path string) bool {
	wide := output_path.to_wide()
	res := C.ui2_media_screenshot(wide)
	unsafe { free(wide) }
	return res != 0
}
