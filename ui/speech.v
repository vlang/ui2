// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/component/src/speech/system/macos.rs. How
// SFSpeechRecognizer results become phrases (a result that ends an utterance
// is kept until the next one shows whether it carried on, phrases are joined
// with the separator their scripts need) and the no-speech error that ends a
// stopped session normally are ported to V. The C bridge, the availability
// checks and the polled event queue are new UI2 implementations. See
// third_party/gpui-kit.
module ui2

// The platform's own speech recognizer, GPUI Kit's SystemRecognizer. macOS
// uses SFSpeechRecognizer on the device (speech_darwin.v and speech_darwin.h);
// every other platform reports it unsupported, with the reason, so
// speech_button hides itself there unless the application brings its own
// SpeechRecognizer.
//
// The platform files only open the recognizer, start, stop and cancel it, and
// hand over what it reported as SpeechNativeEvents. Turning those into
// phrases and hypotheses happens here, in V, the same on every platform.

pub struct SystemSpeechRecognizerConfig {
pub:
	// locale is a BCP 47 tag such as `en-US` or `zh-CN`; empty recognizes the
	// system's language. A language the platform cannot recognize on the
	// device makes the recognizer unavailable.
	locale string
}

// What keeps the system recognizer from working.
enum SpeechNativeProblem {
	none
	unsupported_platform     // No recognizer on this platform.
	framework_missing        // Speech.framework or AVFoundation could not be loaded.
	missing_speech_usage     // Info.plist lacks NSSpeechRecognitionUsageDescription.
	missing_microphone_usage // Info.plist lacks NSMicrophoneUsageDescription.
	missing_usage            // Info.plist lacks both.
	no_recognizer            // No recognizer for the locale.
	recognizer_unavailable   // The recognizer says it is not available now.
	not_on_device            // The locale cannot be recognized without a server.
	speech_denied
	speech_restricted
	microphone_denied
	microphone_restricted
	no_microphone     // Capture could not start.
	busy              // A session is still running.
	responsible_usage // The app that started this one lacks the usage descriptions.
}

enum SpeechNativeEventKind {
	permission = 1 // Asking the user for access.
	ready      // Capturing and recognizing.
	level      // value: RMS of the latest 80 ms of audio, 1 is full scale.
	hypothesis // text: the transcription so far.
	result     // text, is_final, ends_utterance: a recognition result.
	done       // success; otherwise domain, code and text describe the failure.
	error      // text: why the session could not go on.
}

struct SpeechNativeEvent {
	kind           SpeechNativeEventKind
	text           string
	value          f64
	is_final       bool
	ends_utterance bool
	success        bool
	domain         string
	code           i64
}

// SystemSpeechRecognizer is the platform's recognizer. Create it with
// system_speech_recognizer and pass it to new_speech_session.
@[heap]
pub struct SystemSpeechRecognizer {
pub:
	locale string
mut:
	native         voidptr
	problem        SpeechNativeProblem
	sink           &SpeechSink = unsafe { nil }
	finishing      bool
	done           bool
	hypothesis     string // The latest result, as the platform reported it.
	utterance      string // A result that ended an utterance, until the next one shows whether it carries on.
	has_utterance  bool
	last_committed rune
	has_committed  bool
}

// system_speech_recognizer opens the platform's recognizer. It never asks for
// access: that happens when a session starts. Where there is none, or the
// application cannot use it, the recognizer says so through availability.
pub fn system_speech_recognizer(config SystemSpeechRecognizerConfig) &SystemSpeechRecognizer {
	native, problem := native_speech_open(config.locale)
	return &SystemSpeechRecognizer{
		locale:  config.locale
		native:  native
		problem: problem
	}
}

// system_speech_recognizer_name names the platform's recognizer, or says there
// is none.
pub fn system_speech_recognizer_name() string {
	return native_speech_name()
}

pub fn (recognizer &SystemSpeechRecognizer) availability() SpeechAvailability {
	if recognizer.problem != .none || recognizer.native == unsafe { nil } {
		return speech_problem_availability(recognizer.problem, recognizer.locale)
	}
	problem := native_speech_check(recognizer.native)
	if problem != .none {
		return speech_problem_availability(problem, recognizer.locale)
	}
	return speech_available()
}

pub fn (mut recognizer SystemSpeechRecognizer) start(sink &SpeechSink) ! {
	if recognizer.problem != .none || recognizer.native == unsafe { nil } {
		return error(speech_problem_reason(recognizer.problem, recognizer.locale))
	}
	recognizer.reset()
	problem := native_speech_start(recognizer.native)
	if problem != .none {
		return error(speech_problem_reason(problem, recognizer.locale))
	}
	recognizer.sink = sink
	recognizer.poll()
}

// push_audio ignores application audio: the system recognizer listens to the
// microphone itself.
pub fn (mut recognizer SystemSpeechRecognizer) push_audio(samples []i16) {}

pub fn (mut recognizer SystemSpeechRecognizer) poll() {
	if recognizer.sink == unsafe { nil } || recognizer.native == unsafe { nil } {
		return
	}
	for event in native_speech_events(recognizer.native) {
		recognizer.apply_native(event)
	}
}

pub fn (mut recognizer SystemSpeechRecognizer) stop() {
	if recognizer.sink == unsafe { nil } || recognizer.finishing || recognizer.done {
		return
	}
	recognizer.finishing = true
	native_speech_stop(recognizer.native)
}

pub fn (mut recognizer SystemSpeechRecognizer) cancel() {
	if recognizer.native != unsafe { nil } {
		native_speech_cancel(recognizer.native)
	}
	recognizer.sink = unsafe { nil }
	recognizer.reset()
}

fn (mut recognizer SystemSpeechRecognizer) reset() {
	recognizer.finishing = false
	recognizer.done = false
	recognizer.hypothesis = ''
	recognizer.utterance = ''
	recognizer.has_utterance = false
	recognizer.has_committed = false
	recognizer.last_committed = 0
}

// apply_native turns one platform report into sink calls.
fn (mut recognizer SystemSpeechRecognizer) apply_native(event SpeechNativeEvent) {
	if recognizer.done || recognizer.sink == unsafe { nil } {
		return
	}
	mut sink := recognizer.sink
	match event.kind {
		.permission {
			sink.permission()
		}
		.ready {
			sink.ready()
		}
		.level {
			sink.level(speech_level_of_rms(event.value))
		}
		.hypothesis {
			recognizer.on_result(event.text, false, false)
		}
		.result {
			recognizer.on_result(event.text, event.is_final, event.ends_utterance)
		}
		.done {
			if event.success || (recognizer.finishing && speech_is_no_speech(event.domain, event.code)) {
				// Stopping without (more) speech is a normal end.
				pending := recognizer.hypothesis
				recognizer.hypothesis = ''
				recognizer.commit(pending)
				sink.finish()
			} else {
				sink.error(speech_native_error_text(event))
			}
			recognizer.done = true
		}
		.error {
			sink.error(if event.text.len > 0 { event.text } else { 'Speech recognition failed.' })
			recognizer.done = true
		}
	}
}

// on_result takes one transcription. A platform result carries the whole text
// of the session so far, except that some systems start over after a pause:
// the result that ends an utterance is kept until the next one shows whether
// it carries the utterance on or dropped it, and a dropped one is committed.
fn (mut recognizer SystemSpeechRecognizer) on_result(result string, is_final bool, ends_utterance bool) {
	mut sink := recognizer.sink
	if recognizer.has_utterance {
		recognizer.has_utterance = false
		if speech_starts_over(recognizer.utterance, result) {
			recognizer.commit(recognizer.utterance)
		}
	} else if speech_ends_sentence(recognizer.hypothesis)
		&& speech_starts_over(recognizer.hypothesis, result) {
		// A finished sentence that the next result no longer contains started
		// over without saying so.
		recognizer.commit(recognizer.hypothesis)
	}
	if is_final {
		recognizer.hypothesis = ''
		recognizer.commit(result)
		sink.finish()
		recognizer.done = true
		return
	}
	if ends_utterance {
		recognizer.utterance = result
		recognizer.has_utterance = true
	}
	recognizer.hypothesis = result
	sink.hypothesis(recognizer.joined(result))
}

fn (mut recognizer SystemSpeechRecognizer) commit(phrase string) {
	if phrase.len == 0 {
		return
	}
	joined := recognizer.joined(phrase)
	recognizer.last_committed = joined.runes().last()
	recognizer.has_committed = true
	mut sink := recognizer.sink
	sink.phrase(joined)
}

// joined is phrase with the separator it needs after what was committed.
fn (recognizer &SystemSpeechRecognizer) joined(phrase string) string {
	if !recognizer.has_committed || phrase.len == 0 {
		return phrase
	}
	if speech_needs_space(recognizer.last_committed, phrase.runes()[0]) {
		return ' ' + phrase
	}
	return phrase
}

fn speech_ends_sentence(phrase string) bool {
	trimmed := phrase.trim_right(' ')
	if trimmed.len == 0 {
		return false
	}
	return trimmed.runes().last() in [`.`, `?`, `!`, `。`, `？`, `！`]
}

// speech_is_no_speech reports the error SFSpeechRecognizer gives when the
// audio held no speech, which ends a stopped session normally.
fn speech_is_no_speech(domain string, code i64) bool {
	return domain == 'kAFAssistantErrorDomain' && code == 1110
}

fn speech_native_error_text(event SpeechNativeEvent) string {
	message := if event.text.len > 0 { event.text } else { 'Speech recognition failed.' }
	if event.domain.len == 0 {
		return message
	}
	return '${message} (${event.domain} ${event.code})'
}

fn speech_locale_name(locale string) string {
	return if locale.len > 0 { locale } else { 'the system language' }
}

fn speech_problem_availability(problem SpeechNativeProblem, locale string) SpeechAvailability {
	reason := speech_problem_reason(problem, locale)
	return if problem in [.unsupported_platform, .framework_missing] {
		speech_unsupported(reason)
	} else {
		speech_unavailable(reason)
	}
}

fn speech_problem_reason(problem SpeechNativeProblem, locale string) string {
	usage := ' macOS ends an app that asks for access without it; bundle the app with the key to dictate.'
	return match problem {
		.none {
			''
		}
		.unsupported_platform {
			native_speech_unsupported_reason()
		}
		.framework_missing {
			'This Mac has no Speech framework, which needs macOS 10.15 or later.'
		}
		.missing_speech_usage {
			'The app’s Info.plist has no NSSpeechRecognitionUsageDescription.' + usage
		}
		.missing_microphone_usage {
			'The app’s Info.plist has no NSMicrophoneUsageDescription.' + usage
		}
		.missing_usage {
			'The app’s Info.plist has no NSSpeechRecognitionUsageDescription or NSMicrophoneUsageDescription. macOS ends an app that asks for access without them; bundle the app with both keys to dictate.'
		}
		.no_recognizer {
			'There is no speech recognizer for ${speech_locale_name(locale)}.'
		}
		.recognizer_unavailable {
			'The speech recognizer for ${speech_locale_name(locale)} is not available right now.'
		}
		.not_on_device {
			'Dictation in ${speech_locale_name(locale)} would send audio to Apple. Download the language for on-device dictation in System Settings › Keyboard › Dictation.'
		}
		.speech_denied {
			'Speech recognition access is off. Allow it in System Settings › Privacy & Security › Speech Recognition.'
		}
		.speech_restricted {
			'Speech recognition is restricted on this Mac.'
		}
		.microphone_denied {
			'Microphone access is off. Allow it in System Settings › Privacy & Security › Microphone.'
		}
		.microphone_restricted {
			'Microphone access is restricted on this Mac.'
		}
		.no_microphone {
			'The microphone could not be opened.'
		}
		.busy {
			'A dictation is still running.'
		}
		.responsible_usage {
			'This app was started by another app, such as a terminal, that macOS holds responsible for its privacy access, and that app’s Info.plist lacks NSSpeechRecognitionUsageDescription or NSMicrophoneUsageDescription. Open the app from Finder or with `open` to dictate.'
		}
	}
}
