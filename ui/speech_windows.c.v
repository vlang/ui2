// Windows reports the system recognizer unsupported for now. Its dictation
// service, Windows.Media.SpeechRecognition (what GPUI Kit uses), is a WinRT
// API: reaching it from C means activating SpeechRecognizer through
// RoActivateInstance and implementing the IAsyncOperation completion and
// TypedEventHandler COM interfaces by hand, and its continuous dictation runs
// through Microsoft's online service. SAPI 5's in-process recognizer
// (ISpRecoContext with a dictation grammar) is reachable from C but has not
// been wired up. Neither can be exercised from the macOS machine this was
// written on, so applications dictate on Windows with their own
// SpeechRecognizer until one is.
module ui2

fn native_speech_name() string {
	return 'none'
}

fn native_speech_unsupported_reason() string {
	return 'Windows dictation (Windows.Media.SpeechRecognition) is not wired up in ui2 yet; the application has to provide a recognizer.'
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
