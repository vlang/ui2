// iOS has SFSpeechRecognizer too, but this layer reports it unsupported there
// for now. The macOS bridge (speech_darwin.h) would need an AVAudioSession in
// the record category, activated before capture and deactivated after, and the
// iOS backend cannot be built or run on the machine this was written on, so it
// stays off rather than shipping untested capture code. Applications dictate
// on iOS with their own SpeechRecognizer until it is.
module ui2

fn native_speech_name() string {
	return 'none'
}

fn native_speech_unsupported_reason() string {
	return 'iOS dictation (SFSpeechRecognizer) is not wired up in ui2 yet; the application has to provide a recognizer.'
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
