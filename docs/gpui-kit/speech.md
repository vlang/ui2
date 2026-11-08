# Speech

A port of GPUI Kit's [speech](https://github.com/longbridge/gpui-kit/blob/main/website/component/speech.md)
module (dictation), compared with GPUI Kit `main` at
`d4c56812984d5fb2640ed922fe230c3113479563` (the speech sources last changed in
`4890b1c2ab37c7a072d1a3c6adc6a5923ec09807`). The gallery is `examples/gpui_speech`.

Files:

| File | What |
| --- | --- |
| `ui/component_speech.v` | Statuses, events, `SpeechSink`, the `SpeechRecognizer` interface, the level meter, the pure state machine `SpeechSessionState`, `SpeechSession`, phrase joining and the "dictate into a field" helpers |
| `ui/component_speech_view.v` | `speech_button`, `speech_waveform`, `speech_indicator` and their decoders |
| `ui/component_speech_script.v` | `ScriptedSpeechRecognizer` and `speech_script`, for demos and tests |
| `ui/speech.v` | `SystemSpeechRecognizer`, the platform recognizer, in V |
| `ui/speech_darwin.v`, `ui/speech_darwin.h` | The macOS bridge to `SFSpeechRecognizer` (plain C through the Objective-C runtime) |
| `ui/speech_default.c.v`, `ui/speech_windows.c.v`, `ui/speech_ios.v` | Linux, the BSDs, Android, Windows and iOS: no system recognizer, with the reason |

Parts are adapted from GPUI Kit under Apache-2.0 (see the file headers):
the session lifecycle and the level meter of `speech/state.rs` and
`speech/level.rs`, and the result handling, phrase spacing and utterance reset
rules of `speech/system/macos.rs` with its test cases. Everything else (the
controlled snapshot, the polled sink, the views, the scripted recognizer, the
insertion helpers and the C bridge) is new V code.

## Model

GPUI Kit's `SpeechState` is an entity that emits `SpeechEvent`s. In ui2 the
application owns a `&SpeechSession` (keep it in heap-allocated app state: its
timer holds its address) and draws a `SpeechSnapshot` of it, so the views stay
controlled like every other component:

- `SpeechSessionState` is the pure state machine. Each method applies one input
  (start, a recognizer signal, stop, cancel, the stop timeout) and returns the
  events it causes; it never starts a timer or calls a recognizer, so it is
  tested directly.
- `SpeechSession` drives it: it starts the recognizer with a fresh
  `SpeechSink`, polls the recognizer and drains the sink every `tick_interval`
  (60 ms) through `after` while a session is active, enforces `stop_timeout`
  (3 s, GPUI Kit's), and hands events to `on_event` (or queues them for
  `take_events`). Each tick is an ordinary `after` callback, so the window
  rebuilds with the new transcript and levels.
- `SpeechSink` only queues reports under a mutex, so a recognizer may report
  from any V thread. Once its session ends (finished, failed, cancelled, timed
  out or replaced) the sink is closed and ignores everything, so a late result
  cannot leak into the next session.

| `SpeechStatus` | Meaning | GPUI Kit |
| --- | --- | --- |
| `idle` | No session; the button offers to start one | `Idle` |
| `requesting_permission` | Waiting for the user to allow the microphone or speech recognition | (inside `Connecting`) |
| `connecting` | A session started; the recognizer is not listening yet | `Connecting` |
| `listening` | Audio is captured and recognized | `Recording` |
| `processing` | Capture stopped; waiting for the final result | `Stopping` |
| `error` | The last session failed; `snapshot.reason()` says why | (an `Error` event) |
| `unavailable` | No session can start: the recognizer is missing or unavailable | `has_recognizer()` / `is_available()` false |

`is_active()` is true from `requesting_permission` to `processing`;
`is_capturing()` for `connecting` and `listening`, as upstream.

Events carry the **whole** transcript, as upstream: `partial` while the user
speaks (committed phrases followed by the current hypothesis) and `final` when
the session ends normally (possibly empty). `started`, `cancelled` and `error`
(with the reason) complete the set; every event carries its session number.

## API

### Session

| Item | Purpose |
| --- | --- |
| `new_speech_session(recognizer, SpeechSessionConfig) &SpeechSession` | `stop_timeout` (3 s), `tick_interval` (0.06 s), `auto_tick` (true), `on_event`, `format` (`SpeechAudioFormat`, 16 kHz mono), `clock` |
| `start()`, `stop()`, `cancel()`, `toggle()`, `run(SpeechCommand)` | GPUI Kit's `start`/`stop`/`cancel`/`toggle`. `start` does nothing while a session runs; an unavailable recognizer or a failing start makes the status `error` with an `error` event |
| `status()`, `transcript()`, `levels()`, `availability()`, `error()`, `snapshot()`, `state()` | Read the session; `snapshot()` is what the views draw |
| `handle_action(id, action) bool` | Run the command a `speech_button`/`speech_indicator` with this id emitted |
| `set_recognizer(recognizer) bool` | Switch recognizers between sessions (false while one runs) |
| `push_audio([]i16)` | PCM the application captured, to the recognizer and the level meter (GPUI Kit's `AudioInput` seam) |
| `tick()`, `take_events()`, `dismiss_error()` | Manual ticking (tests turn `auto_tick` off), queued events, back from `error` to `idle` |
| `SpeechSessionState` | `start(session)`, `apply(SpeechSignal)`, `stop()`, `cancel()`, `time_out()`, `fail(message)`, `dismiss()`, `transcript()`, `display_status(availability)` |

### Recognizers

```v
pub interface SpeechRecognizer {
	availability() SpeechAvailability // called on every build: keep it cheap
mut:
	start(sink &SpeechSink) !
	push_audio(samples []i16)
	poll()   // every tick of a running session, on the UI thread
	stop()   // flush, then sink.finish() once the last result is in
	cancel() // report nothing more; also called after every session
}
```

The sink takes `permission()`, `ready()`, `hypothesis(text)` (replaces the
guess for the phrase being spoken), `phrase(text)` (commits a phrase and clears
the hypothesis; phrases are joined verbatim, so include the separator, which
`speech_join` computes), `level(0..1)`, `audio(samples)`, `finish()` and
`error(message)`. `SpeechAvailability` is `speech_available()`,
`speech_unavailable(reason)` (supported, not usable now) or
`speech_unsupported(reason)` (no recognizer here: the button hides).

`scripted_speech_recognizer(steps:, availability:, start_error:, finish_delay:, clock:)`
replays `[]SpeechScriptStep` on a clock; `speech_script(transcript, SpeechScriptConfig)`
writes a script that says a text word by word (`permission_delay`,
`connect_delay`, `word_interval`, `sentence_pause`, `finish`), with speech-like
levels: a swell per syllable at each word's own loudness, silence between
words, longer after commas and sentences.

`system_speech_recognizer(locale: 'en-US')` is GPUI Kit's `SystemRecognizer`;
`system_speech_recognizer_name()` names it. See [Platforms](#platforms).

### Views

| Item | Purpose |
| --- | --- |
| `speech_button(SpeechButtonConfig) !Element` | `id`, `frame`, `speech` (a snapshot), `show_when_unsupported`, `enabled`, `round`, `filled`, `reduce_motion`, `tooltip`, `accessibility_label` ("Dictation"), `size`, `theme` |
| `speech_command_from_action(config, action) ?SpeechCommand` | `.start` when idle or failed, `.stop` while asking, connecting or listening, `.cancel` for the indicator's cancel button; rejects foreign, malformed, forged and disabled actions and no-ops (a press while processing) |
| `speech_command_from_key(status, KeyEvent) ?SpeechCommand` | Escape (no modifiers) cancels a running session; call it from `on_key_event` |
| `speech_waveform(SpeechWaveformConfig) !Element` | `levels` (oldest first), `active`, `color`, `bar_width` (height/8, 2 to 4), `gap` (1.5 bars) |
| `speech_waveform_bars(width, height, levels, bar, gap) []Rect` | The pure bar layout |
| `speech_indicator(SpeechIndicatorConfig) !Element` | A status pill: a mark, the status or reason, a small waveform while capturing and a cancel button while active (`show_levels`, `cancellable`, `text`, `reduce_motion`) |
| `speech_indicator_command(config, action) ?SpeechCommand` | Decodes the cancel button |
| `speech_button_action_id(id)`, `speech_cancel_action_id(id)`, `stop_speech_animations(id)` | Action ids; stop the pulse and spinner loops |
| `speech_status_text`, `speech_button_tooltip`, `speech_indicator_text` | English strings for a status line, tooltip or accessibility value |

The button: a microphone at rest (ghost, or `filled`), a lock while asking for
permission, a stop glyph on the primary color with a pulsing ring while
listening (lighter while connecting), a spinner while processing (presses
ignored), a warning on a red tint after a failure (the tooltip gives the reason
and a press retries), and a dimmed, disabled microphone while unavailable (the
tooltip gives the reason). Without any recognizer (`supported` false) it draws
nothing unless `show_when_unsupported`, as upstream. Roles: the button is a
`button` whose value is the status text, the waveform an `img` ("Input level",
the latest level in percent), the indicator a `status`.

### Dictate into a field

`speech_insertion(content, location, length)` splits a field's text at a UTF-16
selection (as `text_area_caret`/`text_area_selection_length` report it; a
negative or out-of-range location appends) and `speech_insertion_at_end`
appends. Take it on `started`; on `final`, `text_with(transcript)` is the new
text, with the transcript trimmed and a space on either side only where the
neighbouring text needs one (none before punctuation, none in Chinese or
Japanese), replacing a selection; `caret_with(transcript)` is the caret after
the inserted words. `speech_dictate(content, transcript, location, length)` does
both at once.

## Example

```v
import ui2

@[heap]
struct App {
mut:
	session   &ui2.SpeechSession = unsafe { nil }
	message   string
	insertion ui2.SpeechInsertion
}

const app = &App{}

fn on_speech(event ui2.SpeechEvent) {
	mut a := unsafe { app }
	match event.kind {
		.started {
			a.insertion = ui2.speech_insertion(a.message, ui2.text_area_caret('message'),
				ui2.text_area_selection_length('message'))
		}
		.final {
			a.message = a.insertion.text_with(event.text)
		}
		else {}
	}
}

fn build() ui2.Element {
	a := unsafe { app }
	theme := ui2.component_theme(false)
	return ui2.screen(theme.background, [
		ui2.text_input(id: 'message', action_id: 'edit', frame: ui2.rect(20, 20, 400, 120), text: a.message) or {
			panic(err)
		},
		ui2.speech_button(
			id:     'mic'
			frame:  ui2.rect(428, 20, 32, 32)
			speech: a.session.snapshot()
			theme:  theme
		) or { panic(err) },
		ui2.label('', a.session.transcript(), ui2.rect(20, 148, 440, 40), ui2.TextStyle{}),
	])
}

fn on_event(event string) {
	mut a := unsafe { app }
	if a.session.handle_action('mic', event) {
		ui2.refresh()
	} else if event == 'edit' {
		a.message = ui2.text('message')
	}
}

fn main() {
	mut a := unsafe { app }
	a.session = ui2.new_speech_session(ui2.system_speech_recognizer(ui2.SystemSpeechRecognizerConfig{}),
		on_event: on_speech)
	ui2.run_window('Dictation', 480, 200, build, on_event)
}
```

A recognizer for a cloud service implements the interface: `start` opens the
connection and returns at once (report `sink.ready()` when it accepts audio),
`push_audio` forwards what the application captured through
`session.push_audio`, the response reader calls `sink.hypothesis`/`sink.phrase`
from its thread, and `stop` sends the end of audio and calls `sink.finish()`
when the last result is in. The gallery's `ScriptedSpeechRecognizer` is a
complete, small implementation.

## Platforms

| Platform | `system_speech_recognizer` |
| --- | --- |
| macOS (AppKit and custom renderer) | `SFSpeechRecognizer`, on the device only (`requiresOnDeviceRecognition`), punctuation on (macOS 13+), the default microphone through an AudioQueue at 16 kHz mono |
| Windows | Unsupported: the button hides unless `show_when_unsupported` |
| Linux, the BSDs, Android | Unsupported: there is no platform dictation service |
| iOS | Unsupported for now |

### macOS

The bridge (`ui/speech_darwin.h`) is plain C over the Objective-C runtime, so it
builds with tcc as well as clang (and as ARC Objective-C in custom-rendered
builds). Results arrive through a delegate class built at run time
(`SFSpeechRecognitionTaskDelegate`'s hypothesis, result and finish messages)
on an operation queue of its own, audio through an AudioQueue input callback,
and the two authorization requests take a hand-built global block (the Block
ABI layout with `_NSConcreteGlobalBlock`, which the runtime never copies or
frees). Nothing in those callbacks calls into V; they queue events under a
lock, and `poll` drains them on the UI thread. The frameworks are loaded with
`dlopen`, so no link flag is needed.

Asking for speech recognition or microphone access without a usage
description makes macOS terminate the process. The recognizer therefore never
asks unless both `NSSpeechRecognitionUsageDescription` and
`NSMicrophoneUsageDescription` are present where the system looks, and
otherwise reports itself unavailable with the reason:

- The app's own Info.plist: its bundle's, or for a bare executable the one
  embedded with `-sectcreate __TEXT __info_plist`. Foundation also reads an
  `Info.plist` lying next to a bare executable; that one does not count.
- When another app started this one (a terminal, an IDE), macOS holds that app
  responsible for privacy access, asks on its behalf and checks its keys
  (`responsibility_get_pid_responsible_for_pid`); that app's Info.plist must
  have both keys too. Terminal.app has neither, so a bundle run from Terminal
  is unavailable; launch it from Finder or with `open`.

So `v run examples/gpui_speech` reports the recognizer unavailable and the
gallery keeps dictating with the scripted recognizer. To dictate for real,
bundle the app with both keys and open it:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Dictate text into messages.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Turn your speech into text.</string>
```

Other reasons it reports: no recognizer for the locale, the recognizer not
available right now, a language that cannot be recognized on the device
(download it in System Settings › Keyboard › Dictation), access denied or
restricted (speech or microphone), and a microphone that cannot be opened.
`kAFAssistantErrorDomain` 1110 (no speech) after a stop ends the session
normally, as upstream.

### What is missing elsewhere

- **Windows**: GPUI Kit uses `Windows.Media.SpeechRecognition`, a WinRT API.
  From C that means activating `SpeechRecognizer` through `RoActivateInstance`
  and implementing the `IAsyncOperation` completion and `TypedEventHandler` COM
  interfaces by hand; continuous dictation also goes through Microsoft's online
  service and the "Online speech recognition" privacy setting. SAPI 5's
  in-process `ISpRecoContext` with a dictation grammar is reachable from plain
  C but was not wired up either. Neither could be run from the macOS machine
  this was written on.
- **iOS**: `SFSpeechRecognizer` exists, but capture needs an `AVAudioSession` in
  the record category, activated before and deactivated after, and the iOS
  backend cannot be built or run here, so it stays off rather than shipping
  untested capture code.
- **Linux, the BSDs, Android**: no system service; use an application recognizer and
  `session.push_audio`.

## Implemented and omitted

| GPUI Kit feature | ui2 |
| --- | --- |
| `SpeechState`: start, stop, cancel, toggle, status, transcript, levels | `SpeechSession`, plus the pure `SpeechSessionState` |
| `Started`, `Partial`, `Final`, `Cancelled`, `Error` events with the whole transcript | Implemented, with the session number; `on_event` or `take_events` |
| Stop timeout (3 s) ending with the transcript so far | Implemented, configurable |
| Stale results ignored after stop, cancel or a new session | Implemented by closing the sink |
| `SpeechRecognizer`, `RecognitionSession`, `SpeechSink` (ready, hypothesis, phrase, finish, error) | One `SpeechRecognizer` interface whose methods act on the running session, and a thread-safe `SpeechSink`; adds `permission`, `level` and `audio` |
| `has_recognizer()` / `is_available()` | `SpeechAvailability.supported` / `.available`, with a reason |
| `system_fallback`, choosing the recognizer | The application passes the recognizer it wants; `set_recognizer` switches between sessions |
| `SystemRecognizer` with `locale` | macOS implemented; Windows omitted (see above) |
| `AudioInput`, `AudioSink`, `AudioFormat`, `Microphone` | `SpeechAudioFormat` and `session.push_audio` take application audio; no built-in microphone capture for application recognizers (the macOS system recognizer captures by itself) |
| `levels()`: 80 ms levels, dB scale, noise gate, fast attack and slow release | Implemented (`SpeechLevelMeter`); keeps 128 levels instead of 256 |
| `SpeechWaveform`: bars from the trailing edge, dots for silence, height sets the bar size | Implemented; it steps one bar per level instead of GPUI Kit's smoothly scrolling playhead, which needs a per-frame clock |
| `SpeechButton`: ghost icon button, stop glyph while capturing, spinner and ignored clicks while stopping, hidden without a recognizer, `show_when_unsupported`, disabled with a tooltip when unavailable, `.disabled()`, sizes | Implemented, plus permission, error and connecting looks, `round`, `filled`, a pulse while listening and `reduce_motion` |
| A status indicator with a cancel button, Escape to cancel | New in ui2 (`speech_indicator`, `speech_command_from_key`) |
| Inserting the final text into an input | `speech_insertion`/`speech_dictate`: caret or selection, UTF-16 offsets, script-aware spacing |
| Localized tooltip and accessible name | English strings; `tooltip` and `accessibility_label` replace them |

## Verification

```sh
v test ui/component_speech_test.v
v -d ui2_custom_rendering test ui/component_speech_test.v
v run examples/gpui_speech
v -d ui2_custom_rendering run examples/gpui_speech
```
