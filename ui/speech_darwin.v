// SFSpeechRecognizer only needs the Objective-C runtime and frameworks loaded
// at run time, so this file serves custom-rendered macOS windows as well as the
// AppKit backend. speech_darwin.h holds the bridge; it is plain C so that tcc
// builds it too.
module ui2

import macos as _

#insert "@VMODROOT/ui/speech_darwin.h"

struct C.ui2_speech {}

struct C.ui2_speech_event {
	kind           int
	is_final       int
	ends_utterance int
	success        int
	value          f64
	code           i64
	text           &char
	domain         &char
}

fn C.ui2_speech_open(locale &char, problem &int) &C.ui2_speech
fn C.ui2_speech_check(bridge &C.ui2_speech) int
fn C.ui2_speech_start(bridge &C.ui2_speech) int
fn C.ui2_speech_pump(bridge &C.ui2_speech)
fn C.ui2_speech_next(bridge &C.ui2_speech, event &C.ui2_speech_event) int
fn C.ui2_speech_event_free(event &C.ui2_speech_event)
fn C.ui2_speech_stop(bridge &C.ui2_speech)
fn C.ui2_speech_cancel(bridge &C.ui2_speech)

fn native_speech_name() string {
	return 'SFSpeechRecognizer (on device)'
}

fn native_speech_unsupported_reason() string {
	return 'This Mac has no speech recognizer.'
}

fn speech_native_problem(code int) SpeechNativeProblem {
	if code < 0 || code > int(SpeechNativeProblem.responsible_usage) {
		return .no_microphone
	}
	return unsafe { SpeechNativeProblem(code) }
}

fn native_speech_open(locale string) (voidptr, SpeechNativeProblem) {
	mut code := 0
	bridge := C.ui2_speech_open(&char(locale.str), &code)
	return voidptr(bridge), speech_native_problem(code)
}

fn native_speech_check(native voidptr) SpeechNativeProblem {
	return speech_native_problem(C.ui2_speech_check(unsafe { &C.ui2_speech(native) }))
}

fn native_speech_start(native voidptr) SpeechNativeProblem {
	return speech_native_problem(C.ui2_speech_start(unsafe { &C.ui2_speech(native) }))
}

fn speech_c_string(value &char) string {
	if value == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(value) }
}

fn native_speech_events(native voidptr) []SpeechNativeEvent {
	bridge := unsafe { &C.ui2_speech(native) }
	C.ui2_speech_pump(bridge)
	mut events := []SpeechNativeEvent{}
	mut raw := C.ui2_speech_event{
		text:   unsafe { nil }
		domain: unsafe { nil }
	}
	for C.ui2_speech_next(bridge, &raw) != 0 {
		kind := if raw.kind >= int(SpeechNativeEventKind.permission)
			&& raw.kind <= int(SpeechNativeEventKind.error) {
			unsafe { SpeechNativeEventKind(raw.kind) }
		} else {
			SpeechNativeEventKind.error
		}
		mut message := speech_c_string(raw.text)
		if kind == .error && message.len == 0 && raw.code > 0 {
			message = speech_problem_reason(speech_native_problem(int(raw.code)), '')
		}
		events << SpeechNativeEvent{
			kind:           kind
			text:           message
			value:          raw.value
			is_final:       raw.is_final != 0
			ends_utterance: raw.ends_utterance != 0
			success:        raw.success != 0
			domain:         speech_c_string(raw.domain)
			code:           raw.code
		}
		C.ui2_speech_event_free(&raw)
	}
	return events
}

fn native_speech_stop(native voidptr) {
	C.ui2_speech_stop(unsafe { &C.ui2_speech(native) })
}

fn native_speech_cancel(native voidptr) {
	C.ui2_speech_cancel(unsafe { &C.ui2_speech(native) })
}
