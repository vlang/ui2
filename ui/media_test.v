module ui2

fn test_media_source_for_src_detects_urls() {
	assert media_source_for_src('https://example.com/a.mp4') == .url
	assert media_source_for_src('http://example.com/a.mp3') == .url
	assert media_source_for_src('HTTPS://EXAMPLE.COM/A.MP4') == .url
	assert media_source_for_src('  https://example.com/a.mp4  ') == .url
	assert media_source_for_src('rtsp://cam.local/stream') == .url
	assert media_source_for_src('/home/user/a.mp3') == .file
	assert media_source_for_src('assets/theme.mp3') == .file
	assert media_source_for_src('C:\\Music\\a.wav') == .file
	assert media_source_for_src('') == .file
}

fn test_media_time_format_reads_like_a_player() {
	assert media_time_format(0) == '0:00'
	assert media_time_format(5) == '0:05'
	assert media_time_format(65) == '1:05'
	assert media_time_format(3599) == '59:59'
	assert media_time_format(3600) == '1:00:00'
	assert media_time_format(3723) == '1:02:03'
	assert media_time_format(-1) == '--:--'
	assert media_time_format(-100) == '--:--'
}

fn test_media_clamped_volume_stays_in_range() {
	assert media_clamped_volume(0.5) == 0.5
	assert media_clamped_volume(0) == 0.0
	assert media_clamped_volume(1) == 1.0
	assert media_clamped_volume(-2) == 0.0
	assert media_clamped_volume(99) == 1.0
}

fn test_media_builder_sets_kind_src_and_accessibility() {
	el := media(
		id:       'intro'
		kind:     .video
		source:   .url
		src:      'https://example.com/intro.mp4'
		frame:    rect(20, 100, 320, 180)
		autoplay: true
		loop:     true
		volume:   0.5
		rate:     1.5
	)!
	assert el.kind == .media
	assert el.id == 'intro'
	assert el.media_kind == .video
	assert el.media_src == 'https://example.com/intro.mp4'
	assert el.autoplay
	assert el.loop
	assert el.media_volume == 0.5
	assert el.media_rate == 1.5
	assert el.accessibility_role == 'video'
	assert el.accessibility_label == 'intro'
}

fn test_media_builder_rejects_capture_sources_and_bad_values() {
	if _ := media(id: 'x', kind: .audio, source: .file, src: '', frame: rect(0, 0, 10, 10)) {
		assert false, 'empty src must fail'
	}
	if _ := media(id: '', kind: .audio, source: .file, src: 'a.mp3', frame: rect(0, 0, 10, 10)) {
		assert false, 'empty id must fail'
	}
	if _ := media(id: 'x', kind: .audio, source: .microphone, src: '', frame: rect(0, 0, 10, 10)) {
		assert false, 'microphone cannot render'
	}
	if _ := media(id: 'x', kind: .audio, source: .screen, src: '', frame: rect(0, 0, 10, 10)) {
		assert false, 'screen cannot render'
	}
	if _ := media(
		id:     'x'
		kind:   .audio
		source: .file
		src:    'a.mp3'
		frame:  rect(0, 0, 10, 10)
		rate:   0
	) {
		assert false, 'non-positive rate must fail'
	}
	// Volume is forgiving: clamped, not rejected.
	hot := media(
		id:     'x'
		kind:   .audio
		source: .file
		src:    'a.mp3'
		frame:  rect(0, 0, 10, 10)
		volume: 4
	)!
	assert hot.media_volume == 1.0
}

fn test_video_and_audio_shortcuts_carry_sensible_defaults() {
	mut v := video('intro', 'https://example.com/i.mp4', rect(1, 2, 320, 180))
	assert v.kind == .media
	assert v.media_kind == .video
	assert v.media_src == 'https://example.com/i.mp4'
	assert v.frame == rect(1, 2, 320, 180)
	assert !v.autoplay && !v.loop && !v.media_muted
	assert v.media_volume == 1.0 && v.media_rate == 1.0
	assert v.accessibility_role == 'video'

	mut a := audio('theme', 'assets/theme.mp3')
	assert a.kind == .media
	assert a.media_kind == .audio
	assert a.media_src == 'assets/theme.mp3'
	assert a.frame == Rect{}
	assert a.accessibility_role == 'audio'
}

fn test_media_control_actions_round_trip() {
	assert media_play_action('x') == 'media:play:x'
	assert media_pause_action('x') == 'media:pause:x'
	assert media_toggle_action('x') == 'media:toggle:x'
	assert media_mute_action('x') == 'media:mute:x'
	assert media_record_action('x') == 'media:record:x'
	assert media_seek_slider_id('x') == 'x:component:seek'
	assert media_seek_action('x') == 'media:seek:x:component:seek'
	// Unknown ids consume nothing and touch no backend.
	assert !media_handle_control('missing', 'media:play:missing')
	assert !media_handle_control('missing', 'media:seek:x:component:seek')
	assert !media_handle_control('missing', 'tap')
	assert media_state('missing') == .idle
	assert media_position('missing') == -1.0
	assert media_duration('missing') == -1.0
	assert media_error('missing') == ''
	assert !media_can_seek('missing')
	assert media_recording_elapsed('missing') == -1.0
	assert !media_play('missing')
	assert !media_pause('missing')
	assert !media_toggle('missing')
	assert !media_stop('missing')
	assert !media_seek('missing', 3)
	assert !media_set_volume('missing', 0.5)
	assert !media_set_muted('missing', true)
	assert !media_set_rate('missing', 2)
	assert !media_set_loop('missing', true)
	assert !media_open('', .audio, 'a.mp3')
	assert !media_open('x', .audio, '')
	assert !media_start_recording('', .microphone, 'a.wav')
	assert !media_start_recording('x', .microphone, '')
	assert !media_start_recording('x', .screen, 'a.png')
	assert !media_stop_recording('missing')
	assert !media_capture_screen('')
	media_close('missing')
}

fn test_media_recorder_validates_its_config() {
	if _ := media_recorder(id: '', output_path: 'a.wav', frame: rect(0, 0, 100, 40)) {
		assert false, 'empty id must fail'
	}
	if _ := media_recorder(id: 'memo', output_path: '', frame: rect(0, 0, 100, 40)) {
		assert false, 'empty output path must fail'
	}
	if _ := media_recorder(
		id:          'memo'
		source:      .screen
		output_path: 'a.png'
		frame:       rect(0, 0, 100, 40)
	) {
		assert false, 'screen is one-shot, not a recorder'
	}
	el := media_recorder(id: 'memo', output_path: 'memo.wav', frame: rect(0, 0, 120, 40))!
	assert el.id == 'memo'
	assert el.accessibility_role == 'button'
	assert el.action_id == 'media:record:memo'
}

fn test_media_controls_render_for_unknown_sessions() {
	el := media_controls(id: 'ghost', frame: rect(0, 0, 300, 40))!
	assert el.accessibility_role == 'toolbar'
	seek := media_seek_slider_id('ghost')
	found := media_find_control(el, seek) or { panic('missing seek slider') }
	assert !found.enabled
}

fn media_find_control(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := media_find_control(child, id) {
			return found
		}
	}
	return none
}

fn test_media_support_queries_answer_without_hardware() {
	// Read-only probes: safe to call on every platform, including headless CI.
	assert media_playback_supported(.audio) == native_media_supported(.audio)
	assert media_playback_supported(.video) == native_media_supported(.video)
	assert media_capture_supported(.microphone) == native_media_capture_supported(.microphone)
	assert media_capture_supported(.screen) == native_media_capture_supported(.screen)
}
