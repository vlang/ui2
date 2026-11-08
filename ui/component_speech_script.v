module ui2

import math

// ScriptedSpeechRecognizer replays a script of recognizer reports on a clock:
// a stand-in for a real recognizer in demos and tests, and an example of
// implementing SpeechRecognizer. speech_script writes a script that dictates a
// text word by word, with input levels that rise and fall like speech.

// SpeechScriptStep is one report, `at` seconds after the session started. The
// kind, text and level mean what they do in a SpeechSignal.
pub struct SpeechScriptStep {
pub:
	at    f64
	kind  SpeechSignalKind
	text  string
	level f64
}

pub struct SpeechScriptConfig {
pub:
	// permission_delay, when positive, makes the script ask for permission
	// first and be granted it this many seconds later.
	permission_delay f64
	connect_delay    f64 = 0.25 // Seconds before it starts listening.
	word_interval    f64 = 0.28 // Seconds per word.
	sentence_pause   f64 = 0.7  // Silence after each sentence.
	// finish ends the session by itself after the last sentence; otherwise
	// the script keeps listening (to silence) until the user stops it.
	finish bool
}

// speech_script dictates transcript: it says each sentence word by word as a
// growing hypothesis, commits it as a phrase (spaced from the one before) and
// pauses, with a level every speech_level_interval from the moment it listens.
// Longer words take longer, words are separated by short silences and commas
// by longer ones, and each word has its own loudness, so the levels rise and
// fall like speech.
pub fn speech_script(transcript string, config SpeechScriptConfig) []SpeechScriptStep {
	mut steps := []SpeechScriptStep{}
	mut t := 0.0
	if config.permission_delay > 0 {
		steps << SpeechScriptStep{
			kind: .permission
		}
		t += config.permission_delay
	}
	t += math.max(config.connect_delay, 0)
	steps << SpeechScriptStep{
		at:   t
		kind: .ready
	}
	listening_at := t
	// A breath before the first word.
	t += 0.3
	word_time := math.max(config.word_interval, 0.05)
	mut spoken := []SpeechScriptWord{}
	mut committed := ''
	for sentence in speech_script_sentences(transcript) {
		mut words := []string{}
		for word in sentence.fields() {
			words << word
			syllables := speech_script_syllables(word)
			duration := word_time * (0.7 + 0.15 * f64(syllables))
			spoken << SpeechScriptWord{
				start:     t
				voiced:    duration * 0.75
				syllables: syllables
				loudness:  0.55 + 0.45 * f64((spoken.len * 7919 + 104729) % 101) / 100.0
			}
			t += duration
			steps << SpeechScriptStep{
				at:   t
				kind: .hypothesis
				text: speech_script_joined(committed, words.join(' '))
			}
			if word.ends_with(',') || word.ends_with(';') || word.ends_with('，') {
				t += word_time * 0.6
			}
		}
		phrase := speech_script_joined(committed, words.join(' '))
		committed += phrase
		steps << SpeechScriptStep{
			at:   t + word_time / 2
			kind: .phrase
			text: phrase
		}
		t += math.max(config.sentence_pause, 0)
	}
	end := t + 1.0
	mut index := 0
	for at := listening_at; at <= end; at += speech_level_interval {
		steps << SpeechScriptStep{
			at:    at
			kind:  .level
			level: speech_script_level(spoken, at, index)
		}
		index++
	}
	if config.finish {
		steps << SpeechScriptStep{
			at:   t
			kind: .finish
		}
	}
	// Ordered by time; steps at the same time keep the order they were written in.
	mut order := []int{len: steps.len, init: index}
	order.sort_with_compare(fn [steps] (a &int, b &int) int {
		if steps[*a].at != steps[*b].at {
			return if steps[*a].at < steps[*b].at { -1 } else { 1 }
		}
		return *a - *b
	})
	return order.map(steps[it])
}

// SpeechScriptWord is when a scripted word sounds, and how.
struct SpeechScriptWord {
	start     f64 // Seconds after the session started.
	voiced    f64 // Seconds of sound; silence follows until the next word.
	syllables int
	loudness  f64 // The word's peak level, 0 to 1.
}

// speech_script_joined is phrase as it follows committed: with a leading
// space when the two need one.
fn speech_script_joined(committed string, phrase string) string {
	return speech_join(committed, phrase)[committed.len..]
}

// speech_script_sentences splits a transcript after each `.`, `?` or `!`.
fn speech_script_sentences(transcript string) []string {
	mut sentences := []string{}
	mut current := []rune{}
	for r in transcript.runes() {
		current << r
		if r in [`.`, `?`, `!`, `。`, `？`, `！`] {
			sentence := current.string().trim_space()
			if sentence.len > 0 {
				sentences << sentence
			}
			current.clear()
		}
	}
	rest := current.string().trim_space()
	if rest.len > 0 {
		sentences << rest
	}
	return sentences
}

// speech_script_syllables guesses how many syllables a word has from its
// groups of vowels: one to four, enough for the level envelope. Characters of
// scripts without spaces between words (Chinese, Japanese) count one each.
fn speech_script_syllables(word string) int {
	mut count := 0
	mut in_vowel := false
	for r in word.to_lower().runes() {
		vowel := r in [`a`, `e`, `i`, `o`, `u`, `y`]
		if (vowel && !in_vowel) || (speech_unspaced_script(r) && r > 0x3040) {
			count++
		}
		in_vowel = vowel
	}
	return if count < 1 {
		1
	} else if count > 4 {
		4
	} else {
		count
	}
}

// speech_script_level is a speech-like loudness at time `at`: within a word a
// swell per syllable with a dip between syllables, at the word's own loudness;
// silence between words. A small deterministic wobble per level keeps equal
// syllables from drawing equal bars.
fn speech_script_level(words []SpeechScriptWord, at f64, index int) f64 {
	for word in words {
		if at < word.start || at >= word.start + word.voiced {
			continue
		}
		phase := (at - word.start) / word.voiced * f64(word.syllables)
		envelope := math.pow(math.sin(math.pi * (phase - math.floor(phase))), 0.6)
		wobble := f64((index * 7919) % 97) / 97.0
		return math.clamp(word.loudness * (0.3 + 0.7 * envelope) * (0.85 + 0.15 * wobble), 0,
			1)
	}
	return 0.0
}

pub struct ScriptedSpeechRecognizerConfig {
pub:
	steps        []SpeechScriptStep
	availability SpeechAvailability = speech_available()
	// start_error, when set, makes every start fail with it.
	start_error string
	// finish_delay is how long the recognizer takes, after stop, to commit
	// the hypothesis and finish: the processing state.
	finish_delay f64           = 0.6
	clock        SpeechClockFn = unsafe { nil }
}

@[heap]
pub struct ScriptedSpeechRecognizer {
pub mut:
	steps        []SpeechScriptStep
	start_error  string
	finish_delay f64
mut:
	reported   SpeechAvailability
	clock      SpeechClockFn = unsafe { nil }
	sink       &SpeechSink   = unsafe { nil }
	started_at f64
	stopped_at f64 // Zero while listening.
	next       int
	hypothesis string
	running    bool
}

// scripted_speech_recognizer creates a recognizer that replays config.steps.
pub fn scripted_speech_recognizer(config ScriptedSpeechRecognizerConfig) &ScriptedSpeechRecognizer {
	return &ScriptedSpeechRecognizer{
		steps:        config.steps
		start_error:  config.start_error
		finish_delay: config.finish_delay
		reported:     config.availability
		clock:        if voidptr(config.clock) != unsafe { nil } {
			config.clock
		} else {
			speech_monotonic_seconds
		}
	}
}

// set_availability changes what the recognizer says about itself, as a real
// one does when the user signs out or denies access.
pub fn (mut recognizer ScriptedSpeechRecognizer) set_availability(availability SpeechAvailability) {
	recognizer.reported = availability
}

pub fn (recognizer &ScriptedSpeechRecognizer) availability() SpeechAvailability {
	return recognizer.reported
}

// is_running reports whether a session is being replayed.
pub fn (recognizer &ScriptedSpeechRecognizer) is_running() bool {
	return recognizer.running
}

pub fn (mut recognizer ScriptedSpeechRecognizer) start(sink &SpeechSink) ! {
	if recognizer.start_error.len > 0 {
		return error(recognizer.start_error)
	}
	recognizer.sink = sink
	recognizer.started_at = recognizer.clock()
	recognizer.stopped_at = 0
	recognizer.next = 0
	recognizer.hypothesis = ''
	recognizer.running = true
	recognizer.poll()
}

// push_audio ignores the audio: the script already knows what is said.
pub fn (mut recognizer ScriptedSpeechRecognizer) push_audio(samples []i16) {}

pub fn (mut recognizer ScriptedSpeechRecognizer) poll() {
	if !recognizer.running || recognizer.sink == unsafe { nil } {
		return
	}
	mut sink := recognizer.sink
	now := recognizer.clock()
	if recognizer.stopped_at > 0 {
		if now - recognizer.stopped_at >= recognizer.finish_delay {
			if recognizer.hypothesis.len > 0 {
				sink.phrase(recognizer.hypothesis)
				recognizer.hypothesis = ''
			}
			sink.finish()
			recognizer.running = false
		}
		return
	}
	elapsed := now - recognizer.started_at
	for recognizer.next < recognizer.steps.len && recognizer.steps[recognizer.next].at <= elapsed {
		step := recognizer.steps[recognizer.next]
		recognizer.next++
		match step.kind {
			.hypothesis { recognizer.hypothesis = step.text }
			.phrase { recognizer.hypothesis = '' }
			else {}
		}
		sink.push(SpeechSignal{
			kind:  step.kind
			text:  step.text
			level: step.level
		})
		if step.kind in [.finish, .error] {
			recognizer.running = false
			return
		}
	}
}

pub fn (mut recognizer ScriptedSpeechRecognizer) stop() {
	if recognizer.running && recognizer.stopped_at == 0 {
		recognizer.stopped_at = math.max(recognizer.clock(), 1e-9)
	}
}

pub fn (mut recognizer ScriptedSpeechRecognizer) cancel() {
	recognizer.running = false
	recognizer.sink = unsafe { nil }
	recognizer.hypothesis = ''
}
