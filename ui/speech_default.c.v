// Linux and Android have no system speech recognizer this layer can drive:
// there is no platform dictation service to call. Applications dictate there
// with their own SpeechRecognizer, such as one wrapping a local model or a
// cloud service, and feed it audio through SpeechSession.push_audio.
module ui2

fn native_speech_name() string {
	return 'none'
}

fn native_speech_unsupported_reason() string {
	return 'This platform has no system speech recognizer; the application has to provide one.'
}

fn native_speech_open(_locale string) (voidptr, SpeechNativeProblem) {
	return unsafe { nil }, SpeechNativeProblem.unsupported_platform
}

fn native_speech_check(_native voidptr) SpeechNativeProblem {
	return .unsupported_platform
}

fn native_speech_start(_native voidptr) SpeechNativeProblem {
	return .unsupported_platform
}

fn native_speech_events(_native voidptr) []SpeechNativeEvent {
	return []
}

fn native_speech_stop(_native voidptr) {}

fn native_speech_cancel(_native voidptr) {}
