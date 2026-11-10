// HTML5-like media: audio/video playback plus microphone and screen capture,
// using only each platform's built-in capabilities. No mpv, VLC, ffmpeg or
// other third-party media library is ever needed (nor linked).
//
// Playback ports the familiar <audio>/<video> surface: a declarative
// `media()` element names the source, while transport runs through small
// imperative calls (`media_play`, `media_pause`, `media_seek`, ...) keyed by
// the element id — the same controlled pattern `text_field` and `slider`
// use. Position, duration and state are pulled by the application, usually
// on a timer tick, so every backend behaves the same without event plumbing:
//
// ```v
// audio('theme', 'assets/theme.mp3')
// video('intro', 'https://example.com/intro.mp4', ui2.rect(20, 100, 320, 180))
// media_controls(id: 'intro', frame: ui2.rect(20, 290, 320, 40))
//
// fn on_event(mut app App, e string) {
//     if ui2.media_handle_control('intro', e) {
//         // play / pause / seek / mute consumed; rebuild to repaint.
//     }
// }
// ```
//
// What runs where (see `media_playback_supported`):
// - Windows (native and custom renderer): audio + video via MCI (winmm).
// - macOS / iOS (native and custom renderer): audio + video via AVFoundation.
// - Android: audio via OpenSL ES; video is unsupported.
// - Linux / BSDs: WAV audio through `aplay`/`paplay`/`pw-play` when one is
// installed (no seek or position readout); video is unsupported.
//
// Capture inputs follow the same shape: `media_recorder()` for the
// microphone plus `media_start_recording` / `media_stop_recording`, and the
// one-shot `media_capture_screen()`. Unsupported inputs report false instead
// of failing.
@[has_globals]
module ui2

import math
import time

// MediaKind selects what a `media` element plays back.
pub enum MediaKind {
	audio
	video
}

// MediaState is the pulled playback or recording state of one session.
// Sessions are terminal in .ended and .error until `media_play` (or a fresh
// `media_open`) moves them again.
pub enum MediaState {
	idle
	loading
	playing
	paused
	stopped
	ended
	error
	recording
}

// MediaSource names where media comes from or goes to.
pub enum MediaSource {
	file
	url
	microphone
	screen
}

// MediaConfig declares one `media` element. `src` is a file path or URL for
// `.file` / `.url` sources; `microphone` and `screen` sources cannot render
// into an element — record them with `media_recorder` / `media_capture_screen`.
pub struct MediaConfig {
pub:
	id       string
	kind     MediaKind   = .audio
	source   MediaSource = .file
	src      string
	frame    Rect
	autoplay bool
	loop     bool
	muted    bool
	volume   f64 = 1.0
	rate     f64 = 1.0
}

// media_source_for_src guesses `.url` for remote locations and `.file` for
// everything else, so the `video` / `audio` shortcuts rarely need a config.
pub fn media_source_for_src(src string) MediaSource {
	lowered := src.trim_space().to_lower()
	if lowered.starts_with('http://') || lowered.starts_with('https://')
		|| lowered.starts_with('rtsp://') || lowered.starts_with('rtsps://') {
		return .url
	}
	return .file
}

// media builds a playback element. Only `.file` and `.url` sources render;
// `.microphone` and `.screen` are capture inputs and return an error here.
pub fn media(config MediaConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if config.source == .microphone || config.source == .screen {
		return error('media element `${config.id}` cannot render a ${config.source} source; record it with media_recorder / media_capture_screen')
	}
	if config.src.trim_space().len == 0 {
		return error('media element `${config.id}` needs a src path or URL')
	}
	if config.rate <= 0 {
		return error('media element `${config.id}` needs a positive playback rate')
	}
	return Element{
		kind:                .media
		id:                  config.id
		frame:               config.frame
		media_src:           config.src
		media_kind:          config.kind
		autoplay:            config.autoplay
		loop:                config.loop
		media_muted:         config.muted
		media_volume:        media_clamped_volume(config.volume)
		media_rate:          config.rate
		accessibility_role:  if config.kind == .video { 'video' } else { 'audio' }
		accessibility_label: media_accessible_name(config)
	}
}

fn media_accessible_name(config MediaConfig) string {
	if config.id.len > 0 {
		return config.id
	}
	return if config.kind == .video { 'Video' } else { 'Audio' }
}

// video is the short form of `media` for moving pictures: source is guessed
// from the `src` prefix, sound starts unmuted at full volume.
pub fn video(id string, src string, frame Rect) Element {
	return Element{
		kind:                .media
		id:                  id
		frame:               frame
		media_src:           src
		media_kind:          .video
		media_volume:        1.0
		media_rate:          1.0
		accessibility_role:  'video'
		accessibility_label: if id.len > 0 { id } else { 'Video' }
	}
}

// audio is the short form of `media` for sound without a picture: the element
// takes no space and only carries the declarative intent for its session.
pub fn audio(id string, src string) Element {
	return Element{
		kind:                .media
		id:                  id
		frame:               Rect{}
		media_src:           src
		media_kind:          .audio
		media_volume:        1.0
		media_rate:          1.0
		accessibility_role:  'audio'
		accessibility_label: if id.len > 0 { id } else { 'Audio' }
	}
}

// media_clamped_volume keeps a declared or requested volume inside the
// 0 (silent) to 1 (full) range instead of failing the call.
pub fn media_clamped_volume(volume f64) f64 {
	return math.min(math.max(volume, 0.0), 1.0)
}

// media_time_format renders seconds the way media players do: `m:ss`, or
// `h:mm:ss` past the hour. Unknown or negative positions read `--:--`.
pub fn media_time_format(secs f64) string {
	if secs < 0 || secs != secs {
		return '--:--'
	}
	total := int(secs)
	hours := total / 3600
	minutes := (total % 3600) / 60
	seconds := total % 60
	if hours > 0 {
		return '${hours}:${minutes:02}:${seconds:02}'
	}
	return '${minutes}:${seconds:02}'
}

// media_playback_supported reports whether this platform can play `kind`
// through its built-in stack — no third-party decoder is ever required.
pub fn media_playback_supported(kind MediaKind) bool {
	return native_media_supported(kind)
}

// media_capture_supported reports whether this platform can capture from
// `source` (microphone recording, screen snapshot) without extra tools.
pub fn media_capture_supported(source MediaSource) bool {
	return native_media_capture_supported(source)
}

// ---------------------------------------------------------------------------
// Sessions: one id-keyed player or recorder, shared by the declarative
// element and the imperative transport calls below.
// ---------------------------------------------------------------------------

struct MediaSession {
mut:
	id             string
	kind           MediaKind
	src            string
	state          MediaState
	autoplay       bool
	loop           bool
	muted          bool
	volume         f64 = 1.0
	rate           f64 = 1.0
	duration       f64 = -1.0
	error_msg      string
	open_failed    bool // open was refused: do not retry every frame
	handle         voidptr
	surface        voidptr
	applied_muted  bool
	applied_volume f64 = -1.0
	applied_rate   f64 = -1.0
	applied_loop   bool
	seen_frame     u64
	record_path    string
	record_start   i64
}

__global g_media_sessions = map[string]&MediaSession{}
__global g_media_frame = u64(0)

fn media_session(id string) ?&MediaSession {
	if id.len == 0 {
		return none
	}
	return g_media_sessions[id] or { return none }
}

fn media_ensure_session(id string, kind MediaKind, src string) &MediaSession {
	if mut existing := media_session(id) {
		if existing.src != src || existing.kind != kind {
			media_close_session(mut existing)
		} else {
			return existing
		}
	}
	mut session := &MediaSession{
		id:     id
		kind:   kind
		src:    src
		state:  .idle
		volume: 1.0
		rate:   1.0
	}
	g_media_sessions[id] = session
	return session
}

fn media_close_session(mut session &MediaSession) {
	native_media_close(session.id)
	session.handle = unsafe { nil }
	session.surface = unsafe { nil }
	session.state = .idle
	session.duration = -1.0
	session.error_msg = ''
	session.open_failed = false
	session.applied_volume = -1.0
	session.applied_rate = -1.0
	session.applied_muted = false
	session.applied_loop = false
	session.record_path = ''
	session.record_start = 0
}

// media_open preloads `src` for later transport calls without starting
// playback. Elements open their own sessions during rendering; explicit
// opens are for element-less (background audio) use.
pub fn media_open(id string, kind MediaKind, src string) bool {
	if id.trim_space().len == 0 || src.trim_space().len == 0 {
		return false
	}
	mut session := media_ensure_session(id, kind, src)
	if !native_media_open(id, kind, src) {
		session.state = .error
		session.error_msg = 'unsupported source'
		return false
	}
	session.state = .stopped
	session.duration = native_media_duration(id)
	return true
}

// media_play starts or resumes `id`, opening its session when the matching
// element (or an explicit `media_open`) has not done so yet. Recording
// sessions refuse playback; stop the take first.
pub fn media_play(id string) bool {
	mut session := media_session(id) or { return false }
	if session.state == .recording {
		return false
	}
	if session.state == .error {
		session.error_msg = ''
	}
	if session.state == .ended {
		native_media_seek(id, 0)
	}
	if !native_media_play(id) {
		session.state = .error
		session.error_msg = 'play failed'
		return false
	}
	session.state = .playing
	return true
}

// media_pause freezes `id` where it stands; a second pause is a no-op.
pub fn media_pause(id string) bool {
	mut session := media_session(id) or { return false }
	if session.state == .recording {
		return false
	}
	if session.state != .playing {
		return true
	}
	if !native_media_pause(id) {
		return false
	}
	session.state = .paused
	return true
}

// media_toggle plays a paused, stopped or ended session and pauses a playing
// one — the single call a play/pause button needs.
pub fn media_toggle(id string) bool {
	session := media_session(id) or { return false }
	if session.state == .playing {
		return media_pause(id)
	}
	return media_play(id)
}

// media_stop halts `id` and rewinds to the start, like ejecting and
// re-inserting the track.
pub fn media_stop(id string) bool {
	mut session := media_session(id) or { return false }
	if session.state == .recording {
		return false
	}
	if !native_media_stop(id) {
		return false
	}
	session.state = .stopped
	return true
}

// media_seek jumps `id` to `secs` seconds. Backends without random access
// (streamed CLI playback) report false and keep playing.
pub fn media_seek(id string, secs f64) bool {
	session := media_session(id) or { return false }
	if session.state == .recording {
		return false
	}
	if secs < 0 {
		return false
	}
	return native_media_seek(session.id, secs)
}

// media_set_volume stores 0..1 (clamped) on the session and the player.
pub fn media_set_volume(id string, volume f64) bool {
	mut session := media_session(id) or { return false }
	clamped := media_clamped_volume(volume)
	if !native_media_set_volume(id, clamped) {
		return false
	}
	session.volume = clamped
	if clamped == 0 {
		session.muted = true
	}
	return true
}

// media_set_muted silences `id` without touching its volume level.
pub fn media_set_muted(id string, muted bool) bool {
	mut session := media_session(id) or { return false }
	if !native_media_set_muted(id, muted) {
		return false
	}
	session.muted = muted
	return true
}

// media_set_rate changes tempo (1 is normal speed) without shifting pitch
// where the platform allows it.
pub fn media_set_rate(id string, rate f64) bool {
	mut session := media_session(id) or { return false }
	if rate <= 0 {
		return false
	}
	if !native_media_set_rate(id, rate) {
		return false
	}
	session.rate = rate
	return true
}

// media_set_loop replays `id` from the start instead of settling in .ended.
pub fn media_set_loop(id string, loop bool) bool {
	mut session := media_session(id) or { return false }
	if !native_media_set_loop(id, loop) {
		return false
	}
	session.loop = loop
	return true
}

// media_close releases `id`: playback stops, the surface detaches and the
// session forgets its source. Rendered elements reopen on demand.
pub fn media_close(id string) {
	if mut session := media_session(id) {
		media_close_session(mut session)
		g_media_sessions.delete(id)
	}
}

// media_position reads back seconds played, or -1 while unknown (a live
// stream, or CLI playback without a progress channel).
pub fn media_position(id string) f64 {
	session := media_session(id) or { return -1.0 }
	return native_media_position(session.id)
}

// media_duration reads back total seconds, or -1 while unknown.
pub fn media_duration(id string) f64 {
	session := media_session(id) or { return -1.0 }
	if session.duration >= 0 {
		return session.duration
	}
	return native_media_duration(session.id)
}

// media_state pulls the session state, settling a finished track first: a
// playing session found past its known end replays when looping and reports
// .ended otherwise. Looping a stream of unknown length never settles, so it
// plays until stopped.
pub fn media_state(id string) MediaState {
	mut session := media_session(id) or { return .idle }
	native := native_media_state(session.id)
	if session.state == .playing {
		if native == .paused {
			session.state = .paused
		} else {
			duration := media_duration(id)
			if duration > 0 && media_position(id) >= duration - 0.05 {
				if session.loop {
					native_media_seek(id, 0)
					native_media_play(id)
				} else {
					session.state = .ended
				}
			} else if native != .playing {
				session.state = native
			}
		}
	} else if session.state in [.paused, .stopped, .ended, .error, .idle] && native == .playing {
		session.state = .playing
	}
	return session.state
}

// media_error explains the last failure of `id`, or '' when healthy.
pub fn media_error(id string) string {
	session := media_session(id) or { return '' }
	return session.error_msg
}

// media_can_seek reports whether `id` supports random access right now.
pub fn media_can_seek(id string) bool {
	session := media_session(id) or { return false }
	return native_media_can_seek(session.id)
}

// media_recording_elapsed reads back seconds captured so far, or -1 when
// `id` is not recording.
pub fn media_recording_elapsed(id string) f64 {
	session := media_session(id) or { return -1.0 }
	if session.state != .recording || session.record_start <= 0 {
		return -1.0
	}
	return f64(time.now().unix() - session.record_start)
}

// media_start_recording captures `source` (microphone) to `output_path`
// (WAV). Screen snapshots are one-shot — see `media_capture_screen`.
pub fn media_start_recording(id string, source MediaSource, output_path string) bool {
	if id.trim_space().len == 0 || output_path.trim_space().len == 0 {
		return false
	}
	if source != .microphone {
		return false
	}
	mut session := media_ensure_session(id, .audio, '')
	session.record_path = output_path
	if !native_media_start_recording(id, source, output_path) {
		session.state = .error
		session.error_msg = 'record failed'
		return false
	}
	session.state = .recording
	session.record_start = time.now().unix()
	return true
}

// media_stop_recording finalizes the take started by `media_start_recording`
// and leaves the file at its output path.
pub fn media_stop_recording(id string) bool {
	mut session := media_session(id) or { return false }
	if session.state != .recording {
		return true
	}
	if !native_media_stop_recording(id) {
		return false
	}
	session.state = .stopped
	session.record_start = 0
	return true
}

// media_capture_screen snapshots the main display to `output_path` (PNG
// where the platform picks the format) and reports whether the shot landed.
pub fn media_capture_screen(output_path string) bool {
	if output_path.trim_space().len == 0 {
		return false
	}
	return native_media_capture_screen(output_path)
}

// ---------------------------------------------------------------------------
// Rendering: each backend's `.media` arm parents a native surface for video
// and keeps the player in step with the declarative element. Frame hooks
// detach surfaces whose element left the tree.
// ---------------------------------------------------------------------------

// media_begin_frame opens a render pass; every rendered `.media` element
// calls `media_sync_native` before it closes.
pub fn media_begin_frame() {
	g_media_frame++
}

// media_end_frame detaches video surfaces whose element was not rendered this
// pass and closes sessions that settled quietly (idle, stopped, ended,
// error). Playing, paused and recording sessions survive hiding so background
// audio and takes are never cut by layout.
pub fn media_end_frame() {
	mut closing := []string{}
	for id in g_media_sessions.keys() {
		mut session := g_media_sessions[id] or { continue }
		if session.seen_frame == g_media_frame {
			continue
		}
		if session.surface != unsafe { nil } {
			native_media_detach(session.id)
			session.surface = unsafe { nil }
		}
		if session.state in [.idle, .stopped, .ended, .error] {
			closing << id
		}
	}
	for id in closing {
		media_close(id)
	}
}

// media_sync_native binds the session of `el` to `parent` (the backend's
// native handle: HWND, NSView, UIView, or the custom renderer's window) at
// `frame` in native units, then applies every declared value the player has
// not picked up yet. Backends call it from their `.media` arm; apps never
// call it directly. Video opens inside attach, once its parent window is
// known; audio opens eagerly.
pub fn media_sync_native(parent voidptr, el Element, frame Rect) {
	if el.id.len == 0 {
		return
	}
	mut session := media_ensure_session(el.id, el.media_kind, el.media_src)
	session.seen_frame = g_media_frame
	session.autoplay = el.autoplay
	if el.media_kind == .audio && session.src.len > 0 && session.state == .idle
		&& !session.open_failed {
		if native_media_open(el.id, el.media_kind, el.media_src) {
			session.state = .stopped
			session.duration = native_media_duration(el.id)
		} else {
			session.state = .error
			session.error_msg = 'unsupported source'
			session.open_failed = true
			return
		}
	}
	if el.media_muted != session.applied_muted {
		if native_media_set_muted(el.id, el.media_muted) {
			session.muted = el.media_muted
			session.applied_muted = el.media_muted
		}
	}
	if el.media_volume != session.applied_volume {
		if native_media_set_volume(el.id, media_clamped_volume(el.media_volume)) {
			session.volume = media_clamped_volume(el.media_volume)
			session.applied_volume = session.volume
		}
	}
	if el.media_rate != session.applied_rate {
		if native_media_set_rate(el.id, el.media_rate) {
			session.rate = el.media_rate
			session.applied_rate = el.media_rate
		}
	}
	if el.loop != session.applied_loop {
		if native_media_set_loop(el.id, el.loop) {
			session.loop = el.loop
			session.applied_loop = el.loop
		}
	}
	if el.autoplay && session.state in [.idle, .stopped, .ended] {
		media_play(el.id)
	}
	if el.media_kind == .video {
		if native_media_attach(el.id, parent, frame.x, frame.y, frame.width, frame.height) {
			session.surface = parent
			if session.duration < 0 {
				session.duration = native_media_duration(el.id)
			}
		} else if !session.open_failed {
			session.state = .error
			session.error_msg = 'unsupported source'
			session.open_failed = true
		}
	} else if session.surface != unsafe { nil } {
		native_media_detach(el.id)
		session.surface = unsafe { nil }
	}
}

// media_play_action / media_pause_action / media_toggle_action /
// media_mute_action name the actions `media_controls` emits; applications
// match them raw or, simpler, forward everything to `media_handle_control`.
pub fn media_play_action(id string) string {
	return 'media:play:' + id
}

pub fn media_pause_action(id string) string {
	return 'media:pause:' + id
}

pub fn media_toggle_action(id string) string {
	return 'media:toggle:' + id
}

pub fn media_mute_action(id string) string {
	return 'media:mute:' + id
}

pub fn media_seek_action(id string) string {
	return 'media:seek:' + media_seek_slider_id(id)
}

pub fn media_seek_slider_id(id string) string {
	return component_part_id(id, 'seek')
}

// media_handle_control executes one `media_controls` action for the session
// `id` and reports whether it consumed the event. The seek action reads the
// seek slider (`media_seek_slider_id`) through the backend's slider lookup,
// so applications forward slider changes here untouched.
pub fn media_handle_control(id string, action string) bool {
	if action == media_play_action(id) {
		return media_play(id)
	}
	if action == media_pause_action(id) {
		return media_pause(id)
	}
	if action == media_toggle_action(id) {
		return media_toggle(id)
	}
	if action == media_mute_action(id) {
		session := media_session(id) or { return false }
		return media_set_muted(id, !session.muted)
	}
	if action == media_seek_action(id) {
		if !media_can_seek(id) {
			return true
		}
		return media_seek(id, slider_value(media_seek_slider_id(id)))
	}
	if action == media_record_action(id) {
		session := media_session(id) or { return false }
		if session.state == .recording {
			return media_stop_recording(id)
		}
		return false
	}
	return false
}

// ---------------------------------------------------------------------------
// Transport and recorder components (pure ui2 primitives, every backend).
// ---------------------------------------------------------------------------

// MediaControlsConfig places one transport row for the session `id`: a
// play/pause toggle, a seek slider bound to the session position, the
// `position / duration` readout and a mute toggle. Rebuild on a timer tick
// (see the media_player example) to keep the readout and slider live.
pub struct MediaControlsConfig {
pub:
	id        string
	frame     Rect
	show_time bool = true
	show_mute bool = true
}

// media_controls draws the transport row for `id`. Every control emits a
// `media:*` action that `media_handle_control(id, action)` executes.
pub fn media_controls(config MediaControlsConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	position := media_position(config.id)
	duration := media_duration(config.id)
	state := media_state(config.id)
	playing := state == .playing
	session_muted := if session := media_session(config.id) {
		session.muted
	} else {
		false
	}
	max := if duration > 0 { duration } else { 100.0 }
	value := if position >= 0 && duration > 0 { position } else { 0.0 }
	toggle_w := 64.0
	mute_w := if config.show_mute { 64.0 } else { 0.0 }
	time_w := if config.show_time { 110.0 } else { 0.0 }
	mut children := [
		button(media_toggle_action(config.id), if playing { 'Pause' } else { 'Play' }, rect(0, 0, toggle_w, config.frame.height),
			BoxStyle{
				transparent: true
			}, TextStyle{
				size: 14
			}),
	]
	slider_width := config.frame.width - toggle_w - mute_w - time_w
	children << slider(
		id:                  media_seek_slider_id(config.id)
		action_id:           media_seek_action(config.id)
		frame:               rect(toggle_w, 0, math.max(slider_width, 0), config.frame.height)
		min:                 0
		max:                 max
		value:               value
		enabled:             media_can_seek(config.id)
		accessibility_label: 'Seek'
	)
	if config.show_time {
		children << label('', '${media_time_format(position)} / ${media_time_format(duration)}',
			rect(toggle_w + math.max(slider_width, 0), 0, time_w, config.frame.height), TextStyle{
				size: 12
			})
	}
	if config.show_mute {
		children << button(media_mute_action(config.id), if session_muted {
			'Unmute'
		} else {
			'Mute'
		},
			rect(config.frame.width - mute_w, 0, mute_w, config.frame.height), BoxStyle{
				transparent: true
			}, TextStyle{
				size: 14
			})
	}
	return Element{
		...view(config.id + '#controls', rect(0, 0, config.frame.width, config.frame.height), BoxStyle{
			transparent: true
		}, children)
		key:                 'controls:' + config.id
		accessibility_role:  'toolbar'
		accessibility_label: 'Media controls'
	}
}

// MediaRecorderConfig places one microphone record button for `id`: it shows
// ● while idle and ■ plus elapsed seconds while recording, and disables
// itself where the platform cannot capture. Screen snapshots stay imperative
// (`media_capture_screen`); screen is rejected here.
pub struct MediaRecorderConfig {
pub:
	id          string
	source      MediaSource = .microphone
	output_path string
	frame       Rect
}

// media_recorder draws the record button for a microphone take. It emits
// `media:record:<id>` on tap; the application starts the take itself so it
// can react when the platform refuses:
//
// ```v
// 'media:record:memo' {
//     if ui2.media_state('memo') == .recording {
//         ui2.media_stop_recording('memo')
//     } else {
//         ui2.media_start_recording('memo', .microphone, app.memo_path)
//     }
// }
// ```
pub fn media_recorder(config MediaRecorderConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if config.source != .microphone {
		return error('media recorder `${config.id}` only captures the microphone; snapshot the screen with media_capture_screen')
	}
	if config.output_path.trim_space().len == 0 {
		return error('media recorder `${config.id}` needs an output_path to save the take')
	}
	supported := media_capture_supported(.microphone)
	recording := media_state(config.id) == .recording
	elapsed := media_recording_elapsed(config.id)
	status := if recording && elapsed >= 0 {
		'Stop ${media_time_format(elapsed)}'
	} else if recording {
		'Stop'
	} else {
		'Record'
	}
	return component_finish(Element{
		...button_view(config.id, config.frame, BoxStyle{
			transparent: true
		}, [
			label('', status, rect(0, 0, config.frame.width, config.frame.height), TextStyle{
				size:  16
				color: if recording { 0xd92d20 } else { 0x444444 }
			}),
		])
		key:                 'recorder:' + config.id
		action_id:           media_record_action(config.id)
		enabled:             supported
		accessibility_role:  'button'
		accessibility_label: if recording { 'Stop recording' } else { 'Record' }
		accessibility_value: if recording { 'recording' } else { 'idle' }
	})
}

pub fn media_record_action(id string) string {
	return 'media:record:' + id
}
