// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/component/src/speech/{state,level}.rs and
// system/macos.rs. The session lifecycle (committed phrases plus a replaceable
// hypothesis, the stop timeout, stale results ignored), the level meter's
// decibel scale, noise gate and attack/release smoothing, and the phrase
// spacing and utterance reset rules are ported to V. The poll-based sink, the
// controlled snapshot, the dictation insertion helper and the timer-driven pump
// are new UI2 implementations. See third_party/gpui-kit.
module ui2

import math
import sync
import time

// Speech input after GPUI Kit's speech module. A SpeechSession owns one
// dictation at a time: it starts a SpeechRecognizer, collects what the
// recognizer reports through a SpeechSink, keeps the transcript and the input
// levels, and reports SpeechEvents to the application. speech_button,
// speech_waveform and speech_indicator (component_speech_view.v) draw a
// SpeechSnapshot of it; the application decides where the text goes, with
// speech_insertion's help.
//
// Recognizers may report from any thread: the sink only queues what they say.
// The session applies the queue on the UI thread, in `tick`, which an `after`
// timer runs while a session is active, so a result arrives as an ordinary
// rebuild. The state machine itself (SpeechSessionState) never starts a timer
// and never calls a recognizer, so it is deterministic and tested directly.

// SpeechStatus is where a dictation is.
pub enum SpeechStatus {
	idle                  // No session runs; the button offers to start one.
	requesting_permission // Waiting for the user to allow the microphone or speech recognition.
	connecting            // A session started; the recognizer is not listening yet.
	listening             // Audio is captured and recognized.
	processing            // Capture stopped; waiting for the recognizer's final result.
	error                 // The last session failed; the snapshot holds the reason.
	unavailable           // No session can start: the recognizer is missing or unavailable.
}

// is_active reports whether a session runs: everything from asking for
// permission to waiting for the final result.
pub fn (status SpeechStatus) is_active() bool {
	return status in [.requesting_permission, .connecting, .listening, .processing]
}

// is_capturing reports whether the session is taking audio (GPUI Kit's
// Connecting and Recording).
pub fn (status SpeechStatus) is_capturing() bool {
	return status in [.connecting, .listening]
}

// speech_status_text is a short English description of a status, for a status
// line, a tooltip or an accessibility value.
pub fn speech_status_text(status SpeechStatus) string {
	return match status {
		.idle { 'Ready to dictate' }
		.requesting_permission { 'Waiting for permission…' }
		.connecting { 'Starting…' }
		.listening { 'Listening…' }
		.processing { 'Transcribing…' }
		.error { 'Dictation failed' }
		.unavailable { 'Dictation unavailable' }
	}
}

// SpeechAvailability is what a recognizer says about itself. GPUI Kit's
// has_recognizer is `supported`; its is_available is `available`.
pub struct SpeechAvailability {
pub:
	// supported is false where there is no recognizer at all, such as the
	// system recognizer on a platform without one. speech_button then draws
	// nothing unless asked to show itself disabled.
	supported bool
	// available is true when a session can start now. A supported recognizer
	// can be unavailable for a while: before the user signs in, while the
	// language is not installed, or after access was denied.
	available bool
	reason    string // Why it is not available, in a sentence; empty when it is.
}

// speech_available is the availability of a recognizer that can start now.
pub fn speech_available() SpeechAvailability {
	return SpeechAvailability{
		supported: true
		available: true
	}
}

// speech_unavailable is the availability of a supported recognizer that
// cannot start now, and why.
pub fn speech_unavailable(reason string) SpeechAvailability {
	return SpeechAvailability{
		supported: true
		reason:    reason
	}
}

// speech_unsupported is the availability of a recognizer that does not exist
// here, and why.
pub fn speech_unsupported(reason string) SpeechAvailability {
	return SpeechAvailability{
		reason: reason
	}
}

pub enum SpeechEventKind {
	started   // A session started.
	partial   // The transcript changed; text holds all of it so far.
	final     // The session ended normally; text holds the transcript, possibly empty.
	cancelled // The session was cancelled and its transcript discarded.
	error     // The session failed and ended; text holds the reason.
}

// SpeechEvent is what a SpeechSession reports. Partial and final events carry
// the whole transcript of the session: every committed phrase followed by the
// current hypothesis. A later event replaces an earlier one, so show the latest
// partial as a preview and commit only the final text.
pub struct SpeechEvent {
pub:
	kind    SpeechEventKind
	text    string
	session int // Which session it belongs to, counting from 1.
}

pub type SpeechEventFn = fn (SpeechEvent)

// SpeechClockFn returns seconds on a monotonic clock. Sessions and the
// scripted recognizer take one so tests can drive time.
pub type SpeechClockFn = fn () f64

fn speech_monotonic_seconds() f64 {
	return f64(time.ticks()) / 1000.0
}

// SpeechCommand is a request to a session, decoded from the button, the
// indicator's cancel button or a key.
pub enum SpeechCommand {
	start
	stop
	cancel
}

// SpeechSignalKind is what a recognizer can report through its sink.
pub enum SpeechSignalKind {
	permission // It is asking the user for access; the status becomes requesting_permission.
	ready      // It is listening; the status becomes listening.
	hypothesis // text replaces the guess for the phrase being spoken.
	phrase     // text is a recognized phrase: it is committed and the hypothesis cleared.
	level      // level is the input loudness, 0 to 1, of the latest stretch of audio.
	audio      // samples are 16-bit PCM in the session's audio format, for the level meter.
	finish     // The session is complete; no more results follow.
	error      // The session failed; text says why.
}

// SpeechSignal is one report from a recognizer. ScriptedSpeechRecognizer
// replays them from a script; SpeechSink queues them.
pub struct SpeechSignal {
pub:
	kind    SpeechSignalKind
	text    string
	level   f64
	samples []i16
}

// SpeechSink is where a recognizer reports one session. Its methods only queue
// the report, under a lock, so they may be called from any V thread; the
// session applies the queue on the UI thread. Once its session has ended the
// sink is closed and ignores everything, so a late result cannot leak into the
// next session.
@[heap]
pub struct SpeechSink {
pub:
	session int
mut:
	mutex   &sync.Mutex = sync.new_mutex()
	signals []SpeechSignal
	closed  bool
}

fn new_speech_sink(session int) &SpeechSink {
	return &SpeechSink{
		session: session
	}
}

// push queues a signal unless the sink is closed.
pub fn (mut sink SpeechSink) push(signal SpeechSignal) {
	sink.mutex.lock()
	if !sink.closed {
		sink.signals << signal
	}
	sink.mutex.unlock()
}

// permission says the recognizer is waiting for the user to grant access.
pub fn (mut sink SpeechSink) permission() {
	sink.push(kind: .permission)
}

// ready says the recognizer is listening.
pub fn (mut sink SpeechSink) ready() {
	sink.push(kind: .ready)
}

// hypothesis replaces the guess for the phrase being spoken.
pub fn (mut sink SpeechSink) hypothesis(text string) {
	sink.push(kind: .hypothesis, text: text)
}

// phrase commits a recognized phrase and clears the hypothesis. Phrases are
// joined verbatim, so include the separator the language needs, such as a
// leading space between English sentences (speech_join does that).
pub fn (mut sink SpeechSink) phrase(text string) {
	sink.push(kind: .phrase, text: text)
}

// level reports the loudness of the latest stretch of audio, 0 to 1, for a
// recognizer that measures its own input (see speech_level_of_rms).
pub fn (mut sink SpeechSink) level(value f64) {
	sink.push(kind: .level, level: value)
}

// audio hands captured PCM to the session's level meter.
pub fn (mut sink SpeechSink) audio(samples []i16) {
	sink.push(kind: .audio, samples: samples)
}

// finish says the session is complete.
pub fn (mut sink SpeechSink) finish() {
	sink.push(kind: .finish)
}

// error says the session failed, and why.
pub fn (mut sink SpeechSink) error(message string) {
	sink.push(kind: .error, text: message)
}

// is_closed reports whether the session the sink belongs to has ended.
pub fn (mut sink SpeechSink) is_closed() bool {
	sink.mutex.lock()
	closed := sink.closed
	sink.mutex.unlock()
	return closed
}

fn (mut sink SpeechSink) close() {
	sink.mutex.lock()
	sink.closed = true
	sink.signals.clear()
	sink.mutex.unlock()
}

fn (mut sink SpeechSink) take() []SpeechSignal {
	sink.mutex.lock()
	signals := sink.signals.clone()
	sink.signals.clear()
	sink.mutex.unlock()
	return signals
}

// SpeechRecognizer turns speech into text. Implement it for the service an
// application uses (a cloud API, a local model) and hand it to
// new_speech_session; system_speech_recognizer is the platform's own and
// scripted_speech_recognizer replays a script for demos and tests.
//
// A session runs as follows:
//  1. `start` opens a session that reports to `sink`. Return at once; report
//     `sink.permission()` while the user is asked for access and `sink.ready()`
//     once listening. An error fails the start.
//  2. Report results as they arrive: `sink.hypothesis` replaces the guess for
//     the phrase being spoken, `sink.phrase` commits one. A recognizer that
//     captures audio itself reports `sink.level` or `sink.audio` for the meter.
//  3. `stop` means the user stopped talking: flush, then `sink.finish()` once
//     the last result is in. The session gives up after its stop timeout.
//  4. `cancel` ends the session: report nothing more and release resources.
//     The session calls it after every session, including one that finished.
//
// Every method runs on the UI thread. `poll` is called on every tick of a
// running session (about every 60 ms), so a recognizer whose results arrive
// elsewhere, such as from C callbacks, can move them into the sink there;
// `push_audio` delivers PCM the application captured (SpeechSession.push_audio).
pub interface SpeechRecognizer {
	// availability is called on every build: keep it cheap.
	availability() SpeechAvailability
mut:
	start(sink &SpeechSink) !
	push_audio(samples []i16)
	poll()
	stop()
	cancel()
}

// SpeechAudioFormat is the PCM a session meters: interleaved 16-bit samples at
// sample_rate per channel. 16 kHz mono is what most speech services take.
pub struct SpeechAudioFormat {
pub:
	sample_rate int = 16000
	channels    int = 1
}

// How much audio one level covers: about the pace of a syllable.
pub const speech_level_interval = 0.08
// How many recent levels a session keeps: enough for a wide waveform.
pub const speech_level_history = 128
// Raw levels below this are background noise and read as silence.
const speech_noise_floor = 0.06
// How far a level moves toward a louder reading per step: peaks pop.
const speech_attack = 0.85
// How far a level moves toward a quieter reading per step: bars fall smoothly.
const speech_release = 0.3

// speech_level_of_rms maps an RMS amplitude (1 is full scale) to a loudness
// in 0...1, -50 dBFS to 0 dBFS linearly, so normal speech fills most of it.
pub fn speech_level_of_rms(rms f64) f64 {
	if !component_finite(rms) || rms <= 0 {
		return 0
	}
	db := 20 * math.log10(rms)
	return math.clamp((db + 50) / 50, 0, 1)
}

// speech_smooth is one step of fast-attack, slow-release smoothing from
// previous toward raw.
pub fn speech_smooth(previous f64, raw f64) f64 {
	rate := if raw > previous { speech_attack } else { speech_release }
	return previous + (raw - previous) * rate
}

fn speech_gate(level f64) f64 {
	return if level < speech_noise_floor { 0.0 } else { level }
}

// SpeechLevelMeter turns PCM, or raw loudness readings, into smoothed levels,
// one per speech_level_interval of audio, carrying partial intervals across
// pushes. Levels are kept oldest first, at most speech_level_history of them.
pub struct SpeechLevelMeter {
mut:
	window   int = 1280
	sum      f64
	count    int
	smoothed f64
	history  []f64
}

// speech_level_meter measures a stream in format.
pub fn speech_level_meter(format SpeechAudioFormat) SpeechLevelMeter {
	return SpeechLevelMeter{
		window: speech_level_window(format)
	}
}

// speech_level_window is how many samples one level covers.
pub fn speech_level_window(format SpeechAudioFormat) int {
	per_second := i64(math.max(format.sample_rate, 1)) * i64(math.max(format.channels, 1))
	return int(math.max(per_second * 80 / 1000, 1))
}

// push measures samples and reports how many levels it recorded.
pub fn (mut meter SpeechLevelMeter) push(samples []i16) int {
	mut recorded := 0
	for sample in samples {
		value := f64(sample) / 32767.0
		meter.sum += value * value
		meter.count++
		if meter.count >= meter.window {
			meter.push_level(speech_level_of_rms(math.sqrt(meter.sum / f64(meter.count))))
			meter.sum = 0
			meter.count = 0
			recorded++
		}
	}
	return recorded
}

// push_level records one raw loudness reading in 0...1: gated against the
// noise floor and smoothed.
pub fn (mut meter SpeechLevelMeter) push_level(raw f64) {
	value := if component_finite(raw) { math.clamp(raw, 0, 1) } else { 0.0 }
	meter.smoothed = speech_smooth(meter.smoothed, speech_gate(value))
	if meter.history.len >= speech_level_history {
		meter.history.delete(0)
	}
	meter.history << meter.smoothed
}

// levels returns the recorded levels, oldest first.
pub fn (meter &SpeechLevelMeter) levels() []f64 {
	return meter.history.clone()
}

// SpeechSessionState is the pure state machine of a session. Each method
// applies one input, changes the state and returns the events it causes; none
// of them calls a recognizer or starts a timer.
pub struct SpeechSessionState {
pub:
	format SpeechAudioFormat
pub mut:
	status     SpeechStatus
	session    int    // The running or last session.
	committed  string // Phrases recognized so far.
	hypothesis string // The guess for the phrase being spoken.
	error      string // Why the last session failed, while the status is error.
	meter      SpeechLevelMeter
}

// transcript is every committed phrase followed by the hypothesis.
pub fn (machine &SpeechSessionState) transcript() string {
	return machine.committed + machine.hypothesis
}

// start begins session `session`, which the caller has already started on
// its recognizer. It does nothing while a session runs.
pub fn (mut machine SpeechSessionState) start(session int) []SpeechEvent {
	if machine.status.is_active() {
		return []
	}
	machine.status = .connecting
	machine.session = session
	machine.committed = ''
	machine.hypothesis = ''
	machine.error = ''
	machine.meter = speech_level_meter(machine.format)
	return [SpeechEvent{
		kind:    .started
		session: session
	}]
}

// fail ends the running session with an error, or records why one could not
// start.
pub fn (mut machine SpeechSessionState) fail(message string) []SpeechEvent {
	reason := if message.trim_space().len > 0 { message } else { 'Dictation failed.' }
	machine.status = .error
	machine.error = reason
	machine.meter = speech_level_meter(machine.format)
	return [SpeechEvent{
		kind:    .error
		text:    reason
		session: machine.session
	}]
}

// stop moves a capturing session (or one still asking for permission) to
// processing. It reports whether it did, so the caller knows to tell the
// recognizer.
pub fn (mut machine SpeechSessionState) stop() bool {
	if !machine.status.is_active() || machine.status == .processing {
		return false
	}
	machine.status = .processing
	return true
}

// cancel ends a running session at once and discards its transcript.
pub fn (mut machine SpeechSessionState) cancel() []SpeechEvent {
	if !machine.status.is_active() {
		return []
	}
	machine.status = .idle
	machine.committed = ''
	machine.hypothesis = ''
	machine.meter = speech_level_meter(machine.format)
	return [SpeechEvent{
		kind:    .cancelled
		session: machine.session
	}]
}

// time_out ends a processing session whose final result is late, with the
// transcript it has.
pub fn (mut machine SpeechSessionState) time_out() []SpeechEvent {
	if machine.status != .processing {
		return []
	}
	return machine.finish()
}

// dismiss returns from the error status to idle.
pub fn (mut machine SpeechSessionState) dismiss() {
	if machine.status == .error {
		machine.status = .idle
		machine.error = ''
	}
}

fn (mut machine SpeechSessionState) finish() []SpeechEvent {
	machine.status = .idle
	machine.meter = speech_level_meter(machine.format)
	return [SpeechEvent{
		kind:    .final
		text:    machine.transcript()
		session: machine.session
	}]
}

fn (mut machine SpeechSessionState) partial() []SpeechEvent {
	return [SpeechEvent{
		kind:    .partial
		text:    machine.transcript()
		session: machine.session
	}]
}

// apply takes one report from the recognizer. Reports outside a running
// session change nothing.
pub fn (mut machine SpeechSessionState) apply(signal SpeechSignal) []SpeechEvent {
	if !machine.status.is_active() {
		return []
	}
	match signal.kind {
		.permission {
			if machine.status == .connecting {
				machine.status = .requesting_permission
			}
		}
		.ready {
			if machine.status in [.connecting, .requesting_permission] {
				machine.status = .listening
			}
		}
		.hypothesis {
			if signal.text == machine.hypothesis {
				return []
			}
			machine.hypothesis = signal.text
			return machine.partial()
		}
		.phrase {
			if signal.text.len == 0 && machine.hypothesis.len == 0 {
				return []
			}
			machine.committed += signal.text
			machine.hypothesis = ''
			return machine.partial()
		}
		.level {
			if machine.status.is_capturing() {
				machine.meter.push_level(signal.level)
			}
		}
		.audio {
			if machine.status.is_capturing() {
				machine.meter.push(signal.samples)
			}
		}
		.finish {
			return machine.finish()
		}
		.error {
			return machine.fail(signal.text)
		}
	}
	return []
}

// display_status is the status to show: an idle or failed session whose
// recognizer cannot start reads as unavailable.
pub fn (machine &SpeechSessionState) display_status(availability SpeechAvailability) SpeechStatus {
	if !machine.status.is_active() && !availability.available {
		return .unavailable
	}
	return machine.status
}

// SpeechSnapshot is everything the speech views draw, taken from a session
// with SpeechSession.snapshot or written by hand (as a gallery of states does).
pub struct SpeechSnapshot {
pub:
	status       SpeechStatus
	transcript   string
	levels       []f64 // Recent input levels, 0 to 1, oldest first.
	error        string
	availability SpeechAvailability = speech_available()
}

// reason is the sentence explaining an error or unavailable status.
pub fn (snapshot SpeechSnapshot) reason() string {
	return match snapshot.status {
		.error {
			snapshot.error
		}
		.unavailable {
			if snapshot.availability.reason.len > 0 {
				snapshot.availability.reason
			} else {
				'Speech input is not available.'
			}
		}
		else {
			''
		}
	}
}

pub struct SpeechSessionConfig {
pub:
	// stop_timeout is how long stop waits for the final result before ending
	// the session with the transcript so far (GPUI Kit's three seconds).
	stop_timeout f64 = 3.0
	// tick_interval is how often a running session polls its recognizer.
	tick_interval f64 = 0.06
	// auto_tick runs tick with `after` while a session is active. Turn it off
	// to call tick yourself, as tests do.
	auto_tick bool = true
	// on_event receives every event on the UI thread. Without it, events queue
	// up for take_events.
	on_event SpeechEventFn = unsafe { nil }
	format   SpeechAudioFormat
	clock    SpeechClockFn = unsafe { nil }
}

// SpeechSession is GPUI Kit's SpeechState: the dictation an application owns.
// Keep it in heap-allocated application state, since its timer holds its
// address, and draw it with a snapshot.
@[heap]
pub struct SpeechSession {
pub:
	stop_timeout  f64
	tick_interval f64
	auto_tick     bool
mut:
	recognizer SpeechRecognizer
	on_event   SpeechEventFn = unsafe { nil }
	clock      SpeechClockFn = unsafe { nil }
	machine    SpeechSessionState
	sink       &SpeechSink = unsafe { nil }
	next_id    int
	deadline   f64 // When a processing session gives up, on clock; zero when none.
	timer      TimerId
	queued     []SpeechEvent
}

// new_speech_session creates an idle session that dictates with recognizer.
pub fn new_speech_session(recognizer SpeechRecognizer, config SpeechSessionConfig) &SpeechSession {
	return &SpeechSession{
		stop_timeout:  if component_finite(config.stop_timeout) && config.stop_timeout > 0 {
			config.stop_timeout
		} else {
			3.0
		}
		tick_interval: if component_finite(config.tick_interval) && config.tick_interval > 0 {
			config.tick_interval
		} else {
			0.06
		}
		auto_tick:     config.auto_tick
		recognizer:    recognizer
		on_event:      config.on_event
		clock:         if voidptr(config.clock) != unsafe { nil } {
			config.clock
		} else {
			speech_monotonic_seconds
		}
		machine:       SpeechSessionState{
			format: config.format
			meter:  speech_level_meter(config.format)
		}
	}
}

// status is the status to show, unavailable included.
pub fn (session &SpeechSession) status() SpeechStatus {
	return session.machine.display_status(session.recognizer.availability())
}

// transcript is the text of the running or last session: committed phrases
// followed by the hypothesis.
pub fn (session &SpeechSession) transcript() string {
	return session.machine.transcript()
}

// levels are the recent input levels, oldest first, while a session captures.
pub fn (session &SpeechSession) levels() []f64 {
	return session.machine.meter.levels()
}

// availability is what the recognizer says about itself now.
pub fn (session &SpeechSession) availability() SpeechAvailability {
	return session.recognizer.availability()
}

// error is why the last session failed, while the status is error.
pub fn (session &SpeechSession) error() string {
	return session.machine.error
}

// state is the session's state machine, for inspection.
pub fn (session &SpeechSession) state() SpeechSessionState {
	return session.machine
}

// snapshot is what the speech views draw.
pub fn (session &SpeechSession) snapshot() SpeechSnapshot {
	availability := session.recognizer.availability()
	return SpeechSnapshot{
		status:       session.machine.display_status(availability)
		transcript:   session.machine.transcript()
		levels:       session.machine.meter.levels()
		error:        session.machine.error
		availability: availability
	}
}

// set_recognizer switches recognizers between sessions. It reports false, and
// changes nothing, while a session runs.
pub fn (mut session SpeechSession) set_recognizer(recognizer SpeechRecognizer) bool {
	if session.machine.status.is_active() {
		return false
	}
	session.recognizer = recognizer
	session.machine.dismiss()
	return true
}

// start begins a session. It does nothing while one runs. When the recognizer
// is unavailable or fails to start, the status becomes error and an error
// event says why.
pub fn (mut session SpeechSession) start() {
	if session.machine.status.is_active() {
		return
	}
	availability := session.recognizer.availability()
	if !availability.available {
		reason := if availability.reason.len > 0 {
			availability.reason
		} else {
			'Speech input is not available.'
		}
		session.emit(session.machine.fail(reason))
		return
	}
	session.next_id++
	sink := new_speech_sink(session.next_id)
	session.recognizer.start(sink) or {
		session.machine.session = session.next_id
		session.emit(session.machine.fail(err.msg()))
		return
	}
	session.sink = sink
	session.deadline = 0
	session.emit(session.machine.start(session.next_id))
	session.drain()
	session.schedule()
}

// stop ends capture and waits for the final result, which arrives as a final
// event; after stop_timeout the session ends with the transcript so far.
pub fn (mut session SpeechSession) stop() {
	if !session.machine.stop() {
		return
	}
	session.deadline = session.clock() + session.stop_timeout
	session.recognizer.stop()
	session.drain()
	session.schedule()
}

// cancel ends the session at once and discards its transcript.
pub fn (mut session SpeechSession) cancel() {
	if !session.machine.status.is_active() {
		return
	}
	session.release()
	session.emit(session.machine.cancel())
}

// toggle starts a session when none runs and stops the running one otherwise.
pub fn (mut session SpeechSession) toggle() {
	if session.machine.status.is_active() {
		session.stop()
	} else {
		session.start()
	}
}

// run carries out a decoded command.
pub fn (mut session SpeechSession) run(command SpeechCommand) {
	match command {
		.start { session.start() }
		.stop { session.stop() }
		.cancel { session.cancel() }
	}
}

// handle_action runs the command a speech_button or speech_indicator with this
// id asked for, and reports whether action was one.
pub fn (mut session SpeechSession) handle_action(id string, action string) bool {
	command := speech_command_from_action(SpeechButtonConfig{
		id:     id
		speech: session.snapshot()
	}, action) or { return false }
	session.run(command)
	return true
}

// dismiss_error returns from the error status to idle.
pub fn (mut session SpeechSession) dismiss_error() {
	session.machine.dismiss()
}

// push_audio hands PCM the application captured, in the session's format, to
// the recognizer and the level meter. GPUI Kit's AudioInput pushes the same way.
pub fn (mut session SpeechSession) push_audio(samples []i16) {
	if !session.machine.status.is_capturing() || samples.len == 0 {
		return
	}
	session.recognizer.push_audio(samples)
	session.machine.meter.push(samples)
}

// tick polls the recognizer, applies what it reported and enforces the stop
// timeout. A running session ticks itself with `after` unless auto_tick is off.
pub fn (mut session SpeechSession) tick() {
	if !session.machine.status.is_active() {
		return
	}
	session.recognizer.poll()
	session.drain()
	if session.machine.status == .processing && session.deadline > 0
		&& session.clock() >= session.deadline {
		session.release()
		session.emit(session.machine.time_out())
	}
	session.schedule()
}

// take_events returns and forgets the events queued for an application that
// set no on_event callback.
pub fn (mut session SpeechSession) take_events() []SpeechEvent {
	events := session.queued.clone()
	session.queued.clear()
	return events
}

fn (mut session SpeechSession) drain() {
	if session.sink == unsafe { nil } {
		return
	}
	mut sink := session.sink
	for signal in sink.take() {
		events := session.machine.apply(signal)
		if !session.machine.status.is_active() {
			// The recognizer finished or failed: release it before telling the
			// application, which may start the next session from the event.
			session.release()
			session.emit(events)
			return
		}
		session.emit(events)
	}
}

// release closes the sink, so nothing more from this session is applied, and
// lets the recognizer go.
fn (mut session SpeechSession) release() {
	if session.sink != unsafe { nil } {
		mut sink := session.sink
		sink.close()
		session.sink = unsafe { nil }
	}
	session.deadline = 0
	session.recognizer.cancel()
}

fn (mut session SpeechSession) emit(events []SpeechEvent) {
	for event in events {
		if voidptr(session.on_event) != unsafe { nil } {
			session.on_event(event)
		} else {
			session.queued << event
		}
	}
}

fn (mut session SpeechSession) schedule() {
	if !session.auto_tick || !session.machine.status.is_active() || timer_pending(session.timer) {
		return
	}
	session.timer = after(session.tick_interval, fn [mut session] () {
		session.tick()
	})
}

// speech_needs_space reports whether two phrases, the first ending in before
// and the second starting with next, need a space between them.
pub fn speech_needs_space(before rune, next rune) bool {
	return !speech_is_space(before) && !speech_is_space(next)
		&& next !in [`,`, `.`, `?`, `!`, `;`, `:`, `)`, `]`, `}`, `…`]
		&& before !in [`(`, `[`, `{`, `“`, `‘`] && !speech_unspaced_script(before)
		&& !speech_unspaced_script(next)
}

fn speech_is_space(r rune) bool {
	return r in [` `, `\t`, `\n`, `\r`, 0xa0, 0x3000]
}

// speech_unspaced_script reports characters of scripts written without spaces
// between words: Chinese, Japanese and their punctuation.
fn speech_unspaced_script(r rune) bool {
	return (r >= 0x3000 && r <= 0x30ff) || (r >= 0x3400 && r <= 0x4dbf)
		|| (r >= 0x4e00 && r <= 0x9fff) || (r >= 0xf900 && r <= 0xfaff)
		|| (r >= 0xff00 && r <= 0xffef)
}

// speech_join appends addition to content with the space the two need
// between them, if any.
pub fn speech_join(content string, addition string) string {
	if content.len == 0 || addition.len == 0 {
		return content + addition
	}
	if speech_needs_space(content.runes().last(), addition.runes()[0]) {
		return content + ' ' + addition
	}
	return content + addition
}

// speech_starts_over reports whether result, the text after the one that
// ended utterance, starts a new utterance instead of carrying it on. A result
// that carries it on may still revise words, punctuation or case, so it only
// starts over when it shares less than half of utterance.
pub fn speech_starts_over(utterance string, result string) bool {
	a := utterance.runes()
	b := result.runes()
	mut common := 0
	for common < a.len && common < b.len && a[common] == b[common] {
		common++
	}
	return common * 2 < a.len
}

// SpeechInsertion is where dictated text goes in a field: the text before the
// insertion point and after it. A selection is replaced. Take it when the
// session starts, then show text_with(partial) as a live preview or commit
// text_with(final) once the session ends.
pub struct SpeechInsertion {
pub:
	before string
	after  string
}

// speech_insertion splits content at a selection given in UTF-16 code units,
// as text_area_caret and text_area_selection_length report it. A location
// outside the text, or negative, inserts at the end.
pub fn speech_insertion(content string, location int, length int) SpeechInsertion {
	if location < 0 || location > text_area_utf16_length(content) {
		return speech_insertion_at_end(content)
	}
	selection := clamped_text_area_selection(content, location, length)
	first := utf16_offset_to_rune_index(content, selection.location)
	last := utf16_offset_to_rune_index(content, selection.location + selection.length)
	runes := content.runes()
	return SpeechInsertion{
		before: runes[..first].string()
		after:  runes[last..].string()
	}
}

// speech_insertion_at_end appends dictation to content.
pub fn speech_insertion_at_end(content string) SpeechInsertion {
	return SpeechInsertion{
		before: content
	}
}

// inserted is the transcript as it goes between before and after: trimmed,
// with a space on either side where the neighbouring text needs one.
pub fn (insertion SpeechInsertion) inserted(transcript string) string {
	lead, words, trail := insertion.parts(transcript)
	return lead + words + trail
}

fn (insertion SpeechInsertion) parts(transcript string) (string, string, string) {
	words := transcript.trim_space()
	if words.len == 0 {
		return '', '', ''
	}
	lead := if insertion.before.len > 0
		&& speech_needs_space(insertion.before.runes().last(), words.runes()[0]) {
		' '
	} else {
		''
	}
	trail := if insertion.after.len > 0
		&& speech_needs_space(words.runes().last(), insertion.after.runes()[0]) {
		' '
	} else {
		''
	}
	return lead, words, trail
}

// text_with is the field's text with transcript in place.
pub fn (insertion SpeechInsertion) text_with(transcript string) string {
	return insertion.before + insertion.inserted(transcript) + insertion.after
}

// caret_with is the UTF-16 offset just after the inserted words (before any
// space added after them), for text_area_set_caret.
pub fn (insertion SpeechInsertion) caret_with(transcript string) int {
	lead, words, _ := insertion.parts(transcript)
	return text_area_utf16_length(insertion.before + lead + words)
}

// speech_dictate inserts a final transcript into content at a UTF-16
// selection (or the end, for a negative location) and returns the new text and
// the caret after the insertion.
pub fn speech_dictate(content string, transcript string, location int, length int) (string, int) {
	insertion := speech_insertion(content, location, length)
	return insertion.text_with(transcript), insertion.caret_with(transcript)
}
