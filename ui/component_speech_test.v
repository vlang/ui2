// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The phrase spacing and utterance reset cases in
// test_speech_phrase_spacing_and_resets come from the tests of gpui-kit
// crates/component/src/speech/system/macos.rs; the other tests are new. See
// third_party/gpui-kit.
module ui2

import math

@[heap]
struct SpeechTestClock {
mut:
	now f64 = 100
}

fn speech_test_clock(clock &SpeechTestClock) SpeechClockFn {
	return fn [clock] () f64 {
		return clock.now
	}
}

fn speech_test_labels(events []SpeechEvent) []string {
	return events.map(match it.kind {
		.started { 'started' }
		.partial { 'partial:${it.text}' }
		.final { 'final:${it.text}' }
		.cancelled { 'cancelled' }
		.error { 'error:${it.text}' }
	})
}

fn speech_test_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := speech_test_find(child, id) {
			return found
		}
	}
	return none
}

fn speech_test_images(el Element) []string {
	mut paths := []string{}
	if el.kind == .image {
		paths << el.image_path
	}
	for child in el.children {
		paths << speech_test_images(child)
	}
	return paths
}

fn speech_test_ids(el Element, prefix string) []string {
	mut ids := []string{}
	if el.id.starts_with(prefix) {
		ids << el.id
	}
	for child in el.children {
		ids << speech_test_ids(child, prefix)
	}
	return ids
}

fn speech_test_tone(amplitude i16, len int) []i16 {
	mut samples := []i16{cap: len}
	for i in 0 .. len {
		samples << if i % 2 == 0 { amplitude } else { -amplitude }
	}
	return samples
}

fn test_speech_status_predicates_and_text() {
	assert !SpeechStatus.idle.is_active()
	assert SpeechStatus.requesting_permission.is_active()
	assert SpeechStatus.processing.is_active()
	assert !SpeechStatus.error.is_active()
	assert !SpeechStatus.unavailable.is_active()
	assert SpeechStatus.connecting.is_capturing()
	assert SpeechStatus.listening.is_capturing()
	assert !SpeechStatus.requesting_permission.is_capturing()
	assert !SpeechStatus.processing.is_capturing()
	assert speech_status_text(.listening) == 'Listening…'
	assert speech_status_text(.processing) == 'Transcribing…'
	assert speech_available().available && speech_available().supported
	assert !speech_unavailable('x').available && speech_unavailable('x').supported
	assert !speech_unsupported('y').supported && speech_unsupported('y').reason == 'y'
}

fn test_speech_level_scale_gate_and_smoothing() {
	assert speech_level_of_rms(0) == 0
	assert speech_level_of_rms(-1) == 0
	assert speech_level_of_rms(math.nan()) == 0
	assert speech_level_of_rms(1) == 1
	// -20 dBFS sits at 0.6 on the -50...0 dB scale.
	assert math.abs(speech_level_of_rms(0.1) - 0.6) < 1e-9
	up := speech_smooth(0, 1)
	assert up >= 0.85
	down := speech_smooth(1, 0)
	assert down >= 0.65
	assert speech_smooth(down, 0) < down
	assert speech_level_window(SpeechAudioFormat{}) == 1280
	assert speech_level_window(sample_rate: 48000, channels: 2) == 7680
	assert speech_level_window(sample_rate: 0, channels: 0) == 1
}

fn test_speech_level_meter_records_one_level_per_interval() {
	mut meter := speech_level_meter(SpeechAudioFormat{})
	window := speech_level_window(SpeechAudioFormat{})
	assert meter.push(speech_test_tone(8000, window / 3)) == 0
	assert meter.push(speech_test_tone(8000, window)) == 1
	assert meter.push(speech_test_tone(8000, window + window / 6)) == 1
	assert meter.levels().len == 2
	assert meter.levels()[0] > 0.5
	// -60 dBFS is under the scale and the noise floor: silence.
	mut quiet := speech_level_meter(SpeechAudioFormat{})
	quiet.push(speech_test_tone(32, window))
	assert quiet.levels() == [0.0]
	// The history is bounded.
	mut long := speech_level_meter(SpeechAudioFormat{})
	long.push(speech_test_tone(8000, window * (speech_level_history + 10)))
	assert long.levels().len == speech_level_history
	// Raw readings are clamped, gated and smoothed.
	mut direct := speech_level_meter(SpeechAudioFormat{})
	direct.push_level(2)
	direct.push_level(0.03)
	direct.push_level(math.nan())
	levels := direct.levels()
	assert levels.len == 3
	assert levels[0] == 0.85
	assert levels[1] < levels[0] && levels[1] > 0
	assert levels[2] < levels[1]
}

fn test_speech_state_machine_runs_a_session() {
	mut machine := SpeechSessionState{}
	assert speech_test_labels(machine.start(1)) == ['started']
	assert machine.status == .connecting
	assert machine.start(2).len == 0, 'a running session ignores start'
	machine.apply(kind: .permission)
	assert machine.status == .requesting_permission
	machine.apply(kind: .ready)
	assert machine.status == .listening
	machine.apply(kind: .permission)
	assert machine.status == .listening, 'permission only applies before listening'
	assert speech_test_labels(machine.apply(kind: .hypothesis, text: 'hello')) == [
		'partial:hello',
	]
	assert machine.apply(kind: .hypothesis, text: 'hello').len == 0, 'unchanged hypotheses are not reported'
	assert speech_test_labels(machine.apply(kind: .phrase, text: 'Hello.')) == ['partial:Hello.']
	assert speech_test_labels(machine.apply(kind: .hypothesis, text: ' How')) == [
		'partial:Hello. How',
	]
	machine.apply(kind: .level, level: 0.9)
	assert machine.meter.levels().len == 1
	assert machine.stop()
	assert machine.status == .processing
	assert !machine.stop(), 'stopping twice is a no-op'
	machine.apply(kind: .level, level: 0.9)
	assert machine.meter.levels().len == 1, 'no levels once capture stopped'
	machine.apply(kind: .phrase, text: ' How are you?')
	assert speech_test_labels(machine.apply(kind: .finish)) == [
		'final:Hello. How are you?',
	]
	assert machine.status == .idle
	assert machine.transcript() == 'Hello. How are you?'
	assert machine.meter.levels().len == 0
	// Reports after the session ended change nothing.
	assert machine.apply(kind: .hypothesis, text: 'late').len == 0
	assert machine.apply(kind: .finish).len == 0
	assert machine.transcript() == 'Hello. How are you?'
}

fn test_speech_state_machine_cancel_timeout_and_errors() {
	mut machine := SpeechSessionState{}
	machine.start(1)
	machine.apply(kind: .hypothesis, text: 'draft')
	assert speech_test_labels(machine.cancel()) == ['cancelled']
	assert machine.status == .idle
	assert machine.transcript() == ''
	assert machine.cancel().len == 0
	// A late final result is a stop that timed out.
	machine.start(2)
	machine.apply(kind: .hypothesis, text: 'half a sentence')
	assert machine.time_out().len == 0, 'only a processing session times out'
	machine.stop()
	assert speech_test_labels(machine.time_out()) == ['final:half a sentence']
	// A failure keeps the transcript and shows the reason until dismissed.
	machine.start(3)
	machine.apply(kind: .phrase, text: 'kept')
	assert speech_test_labels(machine.apply(kind: .error, text: 'offline')) == [
		'error:offline',
	]
	assert machine.status == .error
	assert machine.error == 'offline'
	assert machine.transcript() == 'kept'
	assert speech_test_labels(machine.fail('')) == ['error:Dictation failed.']
	machine.dismiss()
	assert machine.status == .idle && machine.error == ''
	// A failed session can start again; the new one starts clean.
	machine.fail('denied')
	assert speech_test_labels(machine.start(4)) == ['started']
	assert machine.error == '' && machine.transcript() == ''
	// Stop is also accepted while asking for permission.
	machine.apply(kind: .permission)
	assert machine.stop()
	assert machine.status == .processing
}

fn test_speech_display_status_reads_unavailable() {
	mut machine := SpeechSessionState{}
	assert machine.display_status(speech_available()) == .idle
	assert machine.display_status(speech_unavailable('no')) == .unavailable
	machine.fail('x')
	assert machine.display_status(speech_available()) == .error
	assert machine.display_status(speech_unavailable('no')) == .unavailable
	machine.start(1)
	assert machine.display_status(speech_unavailable('no')) == .connecting, 'a running session stays stoppable'
	snapshot := SpeechSnapshot{
		status:       .unavailable
		availability: speech_unavailable('Sign in first.')
	}
	assert snapshot.reason() == 'Sign in first.'
	assert SpeechSnapshot{
		status: .unavailable
	}.reason() == 'Speech input is not available.'
	assert SpeechSnapshot{
		status: .error
		error:  'boom'
	}.reason() == 'boom'
	assert SpeechSnapshot{
		status: .listening
		error:  'boom'
	}.reason() == ''
}

fn test_speech_sink_queues_until_closed() {
	mut sink := new_speech_sink(7)
	assert sink.session == 7
	sink.permission()
	sink.ready()
	sink.hypothesis('a')
	sink.phrase('b')
	sink.level(0.5)
	sink.audio([i16(1), 2])
	sink.finish()
	sink.error('e')
	signals := sink.take()
	assert signals.map(it.kind) == [SpeechSignalKind.permission, .ready, .hypothesis, .phrase,
		.level, .audio, .finish, .error]
	assert signals[2].text == 'a' && signals[4].level == 0.5 && signals[5].samples == [
		i16(1),
		2,
	]
	assert sink.take().len == 0
	sink.hypothesis('queued')
	sink.close()
	assert sink.is_closed()
	sink.hypothesis('late')
	assert sink.take().len == 0
}

fn speech_test_session(clock &SpeechTestClock, steps []SpeechScriptStep) (&SpeechSession, &ScriptedSpeechRecognizer) {
	recognizer := scripted_speech_recognizer(
		steps:        steps
		finish_delay: 0.5
		clock:        speech_test_clock(clock)
	)
	session := new_speech_session(recognizer,
		auto_tick:    false
		stop_timeout: 2
		clock:        speech_test_clock(clock)
	)
	return session, recognizer
}

fn test_speech_session_runs_a_scripted_dictation() {
	mut clock := &SpeechTestClock{}
	mut session, recognizer := speech_test_session(clock, [
		SpeechScriptStep{
			at:   0
			kind: .permission
		},
		SpeechScriptStep{
			at:   0.5
			kind: .ready
		},
		SpeechScriptStep{
			at:    0.55
			kind:  .level
			level: 0.8
		},
		SpeechScriptStep{
			at:   0.8
			kind: .hypothesis
			text: 'Hello'
		},
		SpeechScriptStep{
			at:   1.0
			kind: .phrase
			text: 'Hello world.'
		},
		SpeechScriptStep{
			at:   1.3
			kind: .hypothesis
			text: ' How'
		},
	])
	assert session.status() == .idle
	session.start()
	// The permission step is due at once and applied inside start.
	assert session.status() == .requesting_permission
	assert recognizer.is_running()
	clock.now += 0.5
	session.tick()
	assert session.status() == .listening
	clock.now += 0.1
	session.tick()
	assert session.levels().len == 1
	clock.now += 0.8
	session.tick()
	assert session.transcript() == 'Hello world. How'
	snapshot := session.snapshot()
	assert snapshot.status == .listening
	assert snapshot.transcript == 'Hello world. How'
	assert snapshot.levels.len == 1
	session.stop()
	assert session.status() == .processing
	clock.now += 0.3
	session.tick()
	assert session.status() == .processing
	clock.now += 0.3
	session.tick()
	assert session.status() == .idle
	assert !recognizer.is_running()
	assert speech_test_labels(session.take_events()) == ['started', 'partial:Hello',
		'partial:Hello world.', 'partial:Hello world. How', 'partial:Hello world. How',
		'final:Hello world. How']
	assert session.take_events().len == 0
	assert session.levels().len == 0
}

fn test_speech_session_times_out_cancels_and_ignores_stale_results() {
	mut clock := &SpeechTestClock{}
	// A recognizer that never finishes by itself after stop.
	mut session, mut recognizer := speech_test_session(clock, [
		SpeechScriptStep{
			kind: .ready
		},
		SpeechScriptStep{
			at:   0.1
			kind: .hypothesis
			text: 'half'
		},
	])
	recognizer.finish_delay = 100
	session.start()
	clock.now += 0.2
	session.tick()
	session.stop()
	clock.now += 1.9
	session.tick()
	assert session.status() == .processing
	clock.now += 0.2
	session.tick()
	assert session.status() == .idle
	assert speech_test_labels(session.take_events()).last() == 'final:half'
	assert !recognizer.is_running(), 'a timed-out recognizer is cancelled'
	// Cancelling closes the sink: a result the old session reports later is dropped.
	session.start()
	mut stale := session.sink
	session.cancel()
	assert session.status() == .idle
	assert stale.is_closed()
	stale.phrase('late')
	session.tick()
	assert session.transcript() == ''
	assert speech_test_labels(session.take_events()) == ['started', 'cancelled']
	// Ticks of an idle session do nothing.
	session.tick()
	assert session.take_events().len == 0
}

fn test_speech_session_reports_start_failures_and_unavailability() {
	mut clock := &SpeechTestClock{}
	mut session, mut recognizer := speech_test_session(clock, [])
	recognizer.start_error = 'The service is offline.'
	session.start()
	assert session.status() == .error
	assert session.error() == 'The service is offline.'
	assert speech_test_labels(session.take_events()) == ['error:The service is offline.']
	recognizer.start_error = ''
	recognizer.set_availability(speech_unavailable('Sign in to dictate.'))
	assert session.status() == .unavailable
	assert session.snapshot().reason() == 'Sign in to dictate.'
	session.start()
	assert speech_test_labels(session.take_events()) == ['error:Sign in to dictate.']
	assert !recognizer.is_running()
	recognizer.set_availability(speech_available())
	session.dismiss_error()
	assert session.status() == .idle
	// Recognizers switch only between sessions.
	other := scripted_speech_recognizer(clock: speech_test_clock(clock))
	session.start()
	assert !session.set_recognizer(other)
	session.cancel()
	assert session.set_recognizer(other)
}

fn test_speech_session_events_go_to_the_callback() {
	mut clock := &SpeechTestClock{}
	mut received := []string{}
	mut log := &received
	recognizer := scripted_speech_recognizer(
		steps: [SpeechScriptStep{
			kind: .ready
		}, SpeechScriptStep{
			at:   0.1
			kind: .phrase
			text: 'Hi.'
		}, SpeechScriptStep{
			at:   0.2
			kind: .finish
		}]
		clock: speech_test_clock(clock)
	)
	mut session := new_speech_session(recognizer,
		auto_tick: false
		clock:     speech_test_clock(clock)
		on_event:  fn [mut log] (event SpeechEvent) {
			log << '${event.kind}:${event.text}:${event.session}'
		}
	)
	session.start()
	clock.now += 0.3
	session.tick()
	assert received == ['started::1', 'partial:Hi.:1', 'final:Hi.:1']
	assert session.take_events().len == 0
	assert session.status() == .idle
}

fn test_speech_session_meters_application_audio_and_decodes_actions() {
	mut clock := &SpeechTestClock{}
	mut session, _ := speech_test_session(clock, [SpeechScriptStep{
		kind: .ready
	}])
	window := speech_level_window(SpeechAudioFormat{})
	session.push_audio(speech_test_tone(8000, window))
	assert session.levels().len == 0, 'no audio is taken while idle'
	assert session.handle_action('mic', speech_button_action_id('mic'))
	assert session.status() == .listening
	session.push_audio(speech_test_tone(8000, window * 2))
	assert session.levels().len == 2
	assert !session.handle_action('mic', 'other')
	assert !session.handle_action('mic', speech_button_action_id('mic2'))
	assert session.handle_action('mic', speech_button_action_id('mic'))
	assert session.status() == .processing
	assert !session.handle_action('mic', speech_button_action_id('mic')), 'a press while processing is a no-op'
	assert session.handle_action('mic', speech_cancel_action_id('mic'))
	assert session.status() == .idle
	assert !session.handle_action('mic', speech_cancel_action_id('mic'))
}

fn test_speech_script_dictates_word_by_word() {
	steps := speech_script('Hello there. How are you?',
		permission_delay: 0.5
		connect_delay:    0.2
		word_interval:    0.3
		sentence_pause:   0.5
		finish:           true
	)
	assert steps[0].kind == .permission && steps[0].at == 0
	for i in 1 .. steps.len {
		assert steps[i].at >= steps[i - 1].at, 'steps are in time order'
	}
	ready := steps.filter(it.kind == .ready)
	assert ready.len == 1 && math.abs(ready[0].at - 0.7) < 1e-9
	assert steps.filter(it.kind == .hypothesis).map(it.text) == ['Hello', 'Hello there.', ' How',
		' How are', ' How are you?']
	assert steps.filter(it.kind == .phrase).map(it.text) == ['Hello there.', ' How are you?']
	assert steps.filter(it.kind == .finish).len == 1
	levels := steps.filter(it.kind == .level)
	assert levels.len > 20
	assert levels.all(it.at >= 0.7 && it.level >= 0 && it.level <= 1)
	assert levels.any(it.level > 0.5), 'words are loud'
	assert levels.any(it.level < 0.05), 'pauses are quiet'
	plain := speech_script('one two', SpeechScriptConfig{})
	assert plain[0].kind == .ready
	assert plain.filter(it.kind == .finish).len == 0
	assert speech_script_sentences('今天天气很好。明天呢') == [
		'今天天气很好。',
		'明天呢',
	]
	assert speech_script('', SpeechScriptConfig{}).filter(it.kind in [.hypothesis, .phrase]).len == 0
	// Words are separated by silence and longer words take longer.
	assert speech_script_syllables('the') == 1
	assert speech_script_syllables('Tuesday.') == 2
	assert speech_script_syllables('anything') == 3
	assert speech_script_syllables('extraordinarily') == 4
	assert speech_script_syllables('今天') == 2
	assert speech_script_syllables('hmm') == 1
	timed := speech_script('a extraordinary, b', word_interval: 0.4, connect_delay: 0)
	words := timed.filter(it.kind == .hypothesis)
	assert words[1].at - words[0].at > words[0].at - 0.3, 'a long word takes longer'
	assert words[2].at - words[1].at > 0.4 * 0.7 + 0.4 * 0.15, 'a comma pauses'
	gaps := timed.filter(it.kind == .level && it.at > 0.3 && it.at < words[2].at).map(it.level)
	assert gaps.any(it == 0.0) && gaps.any(it > 0.4), 'loud syllables with silence between words'
}

fn test_speech_scripted_recognizer_replays_and_finishes_after_stop() {
	mut clock := &SpeechTestClock{}
	mut recognizer := scripted_speech_recognizer(
		steps:        [SpeechScriptStep{
			kind: .ready
		}, SpeechScriptStep{
			at:   0.2
			kind: .hypothesis
			text: 'almost'
		}, SpeechScriptStep{
			at:   5
			kind: .phrase
			text: 'never'
		}]
		finish_delay: 0.4
		clock:        speech_test_clock(clock)
	)
	mut sink := new_speech_sink(1)
	recognizer.start(sink)!
	clock.now += 0.3
	recognizer.poll()
	recognizer.stop()
	clock.now += 0.3
	recognizer.poll()
	assert sink.take().map(it.kind) == [SpeechSignalKind.ready, .hypothesis]
	clock.now += 0.2
	recognizer.poll()
	finished := sink.take()
	assert finished.map(it.kind) == [SpeechSignalKind.phrase, .finish]
	assert finished[0].text == 'almost'
	assert !recognizer.is_running()
	recognizer.poll()
	assert sink.take().len == 0
}

fn test_speech_phrase_spacing_and_resets() {
	assert speech_needs_space(`.`, `H`)
	assert !speech_needs_space(`d`, `,`)
	assert !speech_needs_space(`d`, `.`)
	assert !speech_needs_space(` `, `a`)
	assert !speech_needs_space(`a`, ` `)
	assert !speech_needs_space(`(`, `a`)
	assert !speech_needs_space(`。`, `明`)
	assert !speech_needs_space(`好`, `O`)
	assert speech_join('Hello.', 'How') == 'Hello. How'
	assert speech_join('Hello', ', world') == 'Hello, world'
	assert speech_join('', 'x') == 'x'
	assert speech_join('x', '') == 'x'
	assert speech_join('今天', '明天') == '今天明天'
	assert !speech_starts_over('Hello word', 'Hello world, how')
	assert !speech_starts_over('Hello world', 'Hello world. How are you')
	assert !speech_starts_over('今天天气', '今天天气很好')
	assert speech_starts_over('Hello world.', 'How')
	assert speech_starts_over('今天天气很好。', '明天')
	assert !speech_starts_over('', 'anything')
}

fn test_speech_insertion_at_the_caret_selection_and_end() {
	text_value := 'Hello world'
	at_end := speech_insertion(text_value, -1, 0)
	assert at_end.before == text_value && at_end.after == ''
	assert at_end.text_with('how are you') == 'Hello world how are you'
	assert at_end.caret_with('how are you') == 23
	// Out of range also appends.
	assert speech_insertion(text_value, 99, 0).text_with('x') == 'Hello world x'
	middle := speech_insertion(text_value, 6, 0)
	assert middle.before == 'Hello ' && middle.after == 'world'
	assert middle.text_with('big') == 'Hello big world'
	assert middle.caret_with('big') == 9, 'after the words, before the added space'
	// A selection is replaced.
	replaced := speech_insertion(text_value, 6, 5)
	assert replaced.text_with('there') == 'Hello there'
	// Punctuation after the insertion point needs no space.
	assert speech_insertion('Hi!', 2, 0).text_with('there') == 'Hi there!'
	// Empty and whitespace-only transcripts change nothing.
	assert middle.text_with('') == text_value
	assert middle.text_with('  ') == text_value
	assert middle.caret_with('') == 6
	// Leading spaces from joined phrases are trimmed.
	assert speech_insertion('', 0, 0).text_with(' Hello. How') == 'Hello. How'
	// Offsets are UTF-16: an emoji counts twice.
	emoji := 'A😀B'
	split := speech_insertion(emoji, 3, 0)
	assert split.before == 'A😀' && split.after == 'B'
	assert split.caret_with('c') == 5
	// Chinese needs no spaces.
	assert speech_insertion('今天', 2, 0).text_with('很好') == '今天很好'
	updated, caret := speech_dictate('Dear Sam,', 'thanks for the call.', -1, 0)
	assert updated == 'Dear Sam, thanks for the call.'
	assert caret == text_area_utf16_length(updated)
}

fn test_speech_commands_decode_against_the_snapshot() {
	press := speech_button_action_id('mic')
	for status, expected in {
		SpeechStatus.idle:      'start'
		.error:                 'start'
		.requesting_permission: 'stop'
		.connecting:            'stop'
		.listening:             'stop'
		.processing:            ''
		.unavailable:           ''
	} {
		config := SpeechButtonConfig{
			id:     'mic'
			speech: SpeechSnapshot{
				status: status
			}
		}
		got := if command := speech_command_from_action(config, press) {
			command.str()
		} else {
			''
		}
		assert got == expected, '${status}'
	}
	listening := SpeechButtonConfig{
		id:     'mic'
		speech: SpeechSnapshot{
			status: .listening
		}
	}
	if _ := speech_command_from_action(SpeechButtonConfig{ ...listening, enabled: false }, press) {
		assert false, 'a disabled button decoded'
	}
	for forged in ['', 'mic', 'mic:component:', 'mic:component:toggle2', 'mic2:component:toggle',
		'other:component:toggle'] {
		if _ := speech_command_from_action(listening, forged) {
			assert false, 'decoded ${forged}'
		}
	}
	cancel := speech_cancel_action_id('mic')
	assert speech_command_from_action(listening, cancel)? == .cancel
	if _ := speech_command_from_action(SpeechButtonConfig{ id: 'mic' }, cancel) {
		assert false, 'cancel with nothing to cancel'
	}
	indicator := SpeechIndicatorConfig{
		id:     'mic'
		speech: SpeechSnapshot{
			status: .processing
		}
	}
	assert speech_indicator_command(indicator, cancel)? == .cancel
	if _ := speech_indicator_command(indicator, press) {
		assert false, 'the indicator has no toggle'
	}
	if _ := speech_indicator_command(SpeechIndicatorConfig{ ...indicator, cancellable: false },
		cancel)
	{
		assert false, 'a hidden cancel button decoded'
	}
	escape := KeyEvent{
		code: .escape
	}
	assert speech_command_from_key(.listening, escape)? == .cancel
	if _ := speech_command_from_key(.idle, escape) {
		assert false, 'escape while idle'
	}
	if _ := speech_command_from_key(.listening, KeyEvent{ code: .escape, cmd: true }) {
		assert false, 'cmd+escape'
	}
	if _ := speech_command_from_key(.listening, KeyEvent{ code: .enter }) {
		assert false, 'enter'
	}
}

fn speech_test_button(status SpeechStatus, config SpeechButtonConfig) Element {
	return speech_button(SpeechButtonConfig{
		...config
		id:            'mic'
		frame:         rect(10, 20, 32, 32)
		reduce_motion: true
		speech:        SpeechSnapshot{
			...config.speech
			status: status
		}
	}) or { panic(err) }
}

fn test_speech_button_draws_every_state() {
	body_id := component_part_id('mic', 'body')
	for status, icon in {
		SpeechStatus.idle:      'symbol:mic'
		.requesting_permission: 'symbol:lock'
		.connecting:            'symbol:stop.fill'
		.listening:             'symbol:stop.fill'
		.error:                 'symbol:exclamationmark.triangle'
		.unavailable:           'symbol:mic'
	} {
		el := speech_test_button(status, SpeechButtonConfig{})
		assert el.id == 'mic' && el.frame == rect(10, 20, 32, 32)
		assert !el.hidden
		body := speech_test_find(el, body_id) or { panic('no body for ${status}') }
		assert body.button_behavior
		assert body.action_id == speech_button_action_id('mic')
		assert body.frame == rect(0, 0, 32, 32)
		assert body.accessibility_role == 'button'
		assert body.accessibility_label == 'Dictation'
		assert body.accessibility_value == speech_status_text(status)
		assert body.enabled == (status != .unavailable), '${status}'
		assert speech_test_images(el) == [icon], '${status}'
		assert symbol_known(icon['symbol:'.len..])
	}
	theme := ComponentTheme{}
	listening := speech_test_find(speech_test_button(.listening, SpeechButtonConfig{}), body_id)?
	assert listening.box.bg == theme.primary && !listening.box.transparent
	assert listening.tooltip == 'Stop dictation'
	idle := speech_test_find(speech_test_button(.idle, SpeechButtonConfig{}), body_id)?
	assert idle.box.transparent, 'a ghost button at rest'
	filled := speech_test_find(speech_test_button(.idle, SpeechButtonConfig{ filled: true }),
		body_id)?
	assert !filled.box.transparent && filled.box.bg == theme.muted
	round := speech_test_find(speech_test_button(.idle, SpeechButtonConfig{ round: true }),
		body_id)?
	assert round.box.radius == 16
	failed := speech_test_find(speech_test_button(.error, SpeechButtonConfig{
		speech: SpeechSnapshot{
			error: 'Microphone access is off.'
		}
	}), body_id)?
	assert failed.tooltip == 'Microphone access is off. Click to try again.'
	unavailable := speech_test_find(speech_test_button(.unavailable, SpeechButtonConfig{
		speech: SpeechSnapshot{
			availability: speech_unavailable('Sign in first.')
		}
	}), body_id)?
	assert unavailable.tooltip == 'Sign in first.'
	assert !unavailable.enabled
	custom := speech_test_find(speech_test_button(.idle, SpeechButtonConfig{
		tooltip:             'Dictate a reply'
		accessibility_label: 'Dictate reply'
	}), body_id)?
	assert custom.tooltip == 'Dictate a reply' && custom.accessibility_label == 'Dictate reply'
	disabled := speech_test_find(speech_test_button(.idle, SpeechButtonConfig{ enabled: false }),
		body_id)?
	assert !disabled.enabled
	// Processing shows a spinner instead of an icon and ignores presses.
	processing := speech_test_button(.processing, SpeechButtonConfig{})
	assert speech_test_images(processing).len == 0
	assert !speech_test_find(processing, body_id)?.enabled
	assert speech_test_find(processing, component_part_id('mic', 'spinner')) != none
	stop_speech_animations('mic')
}

fn test_speech_button_hides_without_a_recognizer_and_pulses_while_listening() {
	unsupported := SpeechButtonConfig{
		speech: SpeechSnapshot{
			availability: speech_unsupported('No recognizer here.')
		}
	}
	hidden := speech_test_button(.unavailable, unsupported)
	assert hidden.hidden && hidden.children.len == 0
	shown := speech_test_button(.unavailable, SpeechButtonConfig{
		...unsupported
		show_when_unsupported: true
	})
	assert !shown.hidden
	assert !speech_test_find(shown, component_part_id('mic', 'body'))?.enabled
	if _ := speech_button(SpeechButtonConfig{ frame: rect(0, 0, 32, 32) }) {
		assert false, 'a button without an id'
	}
	if _ := speech_button(SpeechButtonConfig{
		id:    'mic'
		frame: rect(0, 0, -1, 32)
	})
	{
		assert false, 'a negative frame'
	}
	pulse_prefix := component_part_id('pulse-test', 'pulse')
	listening := speech_button(
		id:     'pulse-test'
		frame:  rect(0, 0, 40, 32)
		speech: SpeechSnapshot{
			status: .listening
		}
	)!
	pulses := speech_test_ids(listening, pulse_prefix)
	assert pulses.len == 1
	assert animation_info(pulses[0]).status == .running
	pulse := speech_test_find(listening, pulses[0])?
	assert pulse.frame == rect(4, 0, 32, 32), 'the body is the centered square'
	// Rebuilding keeps the loop; leaving the listening state stops it.
	speech_button(
		id:     'pulse-test'
		frame:  rect(0, 0, 40, 32)
		speech: SpeechSnapshot{
			status: .listening
		}
	)!
	assert animation_info(pulses[0]).status == .running
	idle := speech_button(id: 'pulse-test', frame: rect(0, 0, 40, 32))!
	assert speech_test_ids(idle, pulse_prefix).len == 0
	assert animation_info(pulses[0]).status != .running
	still := speech_button(
		id:            'pulse-test'
		frame:         rect(0, 0, 40, 32)
		reduce_motion: true
		speech:        SpeechSnapshot{
			status: .listening
		}
	)!
	assert speech_test_ids(still, pulse_prefix).len == 0
}

fn test_speech_waveform_places_bars_from_the_trailing_edge() {
	assert speech_waveform_bars(98, 20, [], 2, 5).len == 0
	assert speech_waveform_bars(0, 20, [0.5], 2, 5).len == 0
	short := speech_waveform_bars(98, 20, [0.2, 0.9], 2, 5)
	assert short.len == 2
	assert short[1].x + short[1].width == 98, 'the newest bar ends at the trailing edge'
	assert short[1].height == 18
	assert short[0].x == short[1].x - 7
	assert short[0].height == 4
	for bar in short {
		assert bar.y + bar.height / 2 == 10, 'bars grow from the midline'
	}
	long := speech_waveform_bars(96, 20, []f64{len: 64, init: 0.0}, 2, 5)
	assert long.len == 14, '96 points at a 7 point pitch'
	assert long.all(it.x >= 0 && it.height == 2), 'silence is a dot'
	assert speech_waveform_bar_width(12) == 2
	assert speech_waveform_bar_width(24) == 3
	assert speech_waveform_bar_width(80) == 4
	theme := component_theme(true)
	wave := speech_waveform(
		id:     'wave'
		frame:  rect(0, 0, 60, 16)
		levels: [0.1, 0.5, 1.0]
		theme:  theme
	)!
	assert wave.children.len == 3
	assert wave.children.all(it.box.bg == theme.primary)
	assert wave.accessibility_role == 'img'
	assert wave.accessibility_value == '100%'
	muted := speech_waveform(frame: rect(0, 0, 60, 16), levels: [0.5], active: false, theme: theme)!
	assert muted.children[0].box.bg == theme.muted_foreground
	tinted := speech_waveform(frame: rect(0, 0, 60, 16), levels: [0.5], color: u32(0x123456))!
	assert tinted.children[0].box.bg == 0x123456
	if _ := speech_waveform(frame: rect(0, 0, 60, 16), gap: -1) {
		assert false, 'a negative gap'
	}
}

fn test_speech_indicator_shows_status_levels_and_cancel() {
	theme := ComponentTheme{}
	listening := speech_indicator(
		id:     'dictation'
		frame:  rect(0, 0, 260, 28)
		speech: SpeechSnapshot{
			status: .listening
			levels: [0.2, 0.6, 0.9]
		}
		theme:  theme
	)!
	assert listening.accessibility_role == 'status'
	assert listening.accessibility_label == 'Listening…'
	cancel := speech_test_find(listening, component_part_id('dictation', 'cancel-button'))?
	assert cancel.action_id == speech_cancel_action_id('dictation')
	assert cancel.button_behavior
	labels := listening.children.filter(it.kind == .label)
	assert labels.len == 1 && labels[0].text == 'Listening…'
	assert labels[0].frame.x + labels[0].frame.width <= cancel.frame.x
	// The waveform sits between the text and the cancel button.
	waves := listening.children.filter(it.accessibility_label == 'Input level')
	assert waves.len == 1
	assert waves[0].frame.x + waves[0].frame.width <= cancel.frame.x
	idle := speech_indicator(id: 'dictation', frame: rect(0, 0, 260, 28), theme: theme)!
	assert speech_test_find(idle, component_part_id('dictation', 'cancel-button')) == none
	assert idle.children.filter(it.kind == .label)[0].text == 'Ready to dictate'
	failed := speech_indicator(
		id:     'dictation'
		frame:  rect(0, 0, 260, 28)
		speech: SpeechSnapshot{
			status: .error
			error:  'Offline.'
		}
		theme:  theme
	)!
	assert failed.accessibility_label == 'Offline.'
	assert speech_test_images(failed) == ['symbol:exclamationmark.triangle']
	processing := speech_indicator(
		id:            'dictation'
		frame:         rect(0, 0, 260, 28)
		reduce_motion: true
		cancellable:   false
		text:          'Almost there'
		speech:        SpeechSnapshot{
			status: .processing
		}
		theme:         theme
	)!
	assert speech_test_find(processing, component_part_id('dictation', 'spinner')) != none
	assert speech_test_find(processing, component_part_id('dictation', 'cancel-button')) == none
	assert processing.accessibility_label == 'Almost there'
	stop_speech_animations('dictation')
}

fn speech_test_system(sink &SpeechSink) SystemSpeechRecognizer {
	return SystemSpeechRecognizer{
		sink: sink
	}
}

fn test_system_recognizer_turns_platform_results_into_phrases() {
	mut sink := new_speech_sink(1)
	mut recognizer := speech_test_system(sink)
	recognizer.apply_native(kind: .permission)
	recognizer.apply_native(kind: .ready)
	recognizer.apply_native(kind: .level, value: 0.1)
	recognizer.apply_native(kind: .hypothesis, text: 'Hello')
	recognizer.apply_native(kind: .hypothesis, text: 'Hello world')
	signals := sink.take()
	assert signals.map(it.kind) == [SpeechSignalKind.permission, .ready, .level, .hypothesis,
		.hypothesis]
	assert math.abs(signals[2].level - 0.6) < 1e-9
	assert signals[4].text == 'Hello world'
	// A result that ends an utterance, then one that starts over: the first is committed.
	recognizer.apply_native(kind: .result, text: 'Hello world.', ends_utterance: true)
	recognizer.apply_native(kind: .hypothesis, text: 'How')
	reset := sink.take()
	assert reset.map(it.kind) == [SpeechSignalKind.hypothesis, .phrase, .hypothesis]
	assert reset[1].text == 'Hello world.'
	assert reset[2].text == ' How', 'joined after the committed phrase'
	// A carried-on utterance is not committed twice.
	recognizer.apply_native(kind: .result, text: 'How are', ends_utterance: true)
	recognizer.apply_native(kind: .hypothesis, text: 'How are you')
	assert sink.take().filter(it.kind == .phrase).len == 0
	// A finished sentence that the next hypothesis no longer contains is kept.
	recognizer.apply_native(kind: .hypothesis, text: 'How are you?')
	recognizer.apply_native(kind: .hypothesis, text: 'Fine')
	kept := sink.take().filter(it.kind == .phrase)
	assert kept.len == 1 && kept[0].text == ' How are you?'
	// The final result is committed and finishes.
	recognizer.apply_native(kind: .result, text: 'Fine thanks.', is_final: true)
	final := sink.take()
	assert final.map(it.kind) == [SpeechSignalKind.phrase, .finish]
	assert final[0].text == ' Fine thanks.'
	recognizer.apply_native(kind: .hypothesis, text: 'after the end')
	assert sink.take().len == 0
}

fn test_system_recognizer_ends_on_no_speech_and_reports_errors() {
	mut sink := new_speech_sink(1)
	mut recognizer := speech_test_system(sink)
	recognizer.apply_native(kind: .hypothesis, text: 'pending words')
	recognizer.finishing = true
	recognizer.apply_native(
		kind:   .done
		domain: 'kAFAssistantErrorDomain'
		code:   1110
		text:   'No speech detected'
	)
	ended := sink.take()
	assert ended.map(it.kind) == [SpeechSignalKind.hypothesis, .phrase, .finish]
	assert ended[1].text == 'pending words'
	mut failing_sink := new_speech_sink(2)
	mut failing := speech_test_system(failing_sink)
	failing.apply_native(kind: .done, domain: 'kLSRErrorDomain', code: 201, text: 'Siri is off')
	failed := failing_sink.take()
	assert failed.len == 1 && failed[0].kind == .error
	assert failed[0].text == 'Siri is off (kLSRErrorDomain 201)'
	mut error_sink := new_speech_sink(3)
	mut erroring := speech_test_system(error_sink)
	erroring.apply_native(kind: .error)
	assert error_sink.take()[0].text == 'Speech recognition failed.'
	mut done_sink := new_speech_sink(4)
	mut done := speech_test_system(done_sink)
	done.apply_native(kind: .done, success: true)
	assert done_sink.take().map(it.kind) == [SpeechSignalKind.finish]
}

fn test_system_recognizer_reports_what_keeps_it_from_working() {
	recognizer := system_speech_recognizer(SystemSpeechRecognizerConfig{})
	availability := recognizer.availability()
	assert system_speech_recognizer_name().len > 0
	// A test binary is not an app bundle, so there is no usage description to
	// ask with on macOS, and no recognizer elsewhere: never available here.
	assert !availability.available
	assert availability.reason.len > 0
	$if macos && !ios {
		assert availability.supported
		assert availability.reason.contains('NSSpeechRecognitionUsageDescription')
	} $else {
		assert !availability.supported
	}
	mut session := new_speech_session(recognizer, auto_tick: false)
	assert session.status() == .unavailable
	session.start()
	events := session.take_events()
	assert events.len == 1 && events[0].kind == .error
	assert events[0].text == availability.reason
	for problem in [SpeechNativeProblem.missing_usage, .missing_speech_usage,
		.missing_microphone_usage, .no_recognizer, .recognizer_unavailable, .not_on_device,
		.speech_denied, .speech_restricted, .microphone_denied, .microphone_restricted, .no_microphone,
		.busy, .framework_missing, .responsible_usage] {
		assert speech_problem_reason(problem, 'en-US').len > 0
	}
	assert speech_problem_availability(.framework_missing, '').supported == false
	assert speech_problem_availability(.speech_denied, '').supported
	assert speech_problem_reason(.no_recognizer, 'xx-YY').contains('xx-YY')
	assert speech_problem_reason(.no_recognizer, '').contains('the system language')
}
