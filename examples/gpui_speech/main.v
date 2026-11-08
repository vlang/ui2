module main

import ui2

// Dictation after GPUI Kit's speech module. A scripted recognizer "speaks" a
// message word by word, arriving through the session's `after` ticks with
// live input levels, and the final transcript is inserted into the message at
// the caret (or the end). The right column shows the button in every state,
// waveform sizes and what the platform's own recognizer says about itself:
// an unbundled `v run` has no usage descriptions, so on macOS it explains why
// it is off instead of asking for access.

const window_width = 960
const window_height = 744
const left_x = 24.0
const left_width = 536.0
const right_x = 592.0
const right_width = 344.0
const composer_y = 122.0
const composer_height = 204.0

const demo_transcript = 'Thanks for the notes from Tuesday. I moved the review to Friday morning, and the draft is in the shared folder. Let me know if anything is missing!'

@[heap]
struct Gallery {
mut:
	session        &ui2.SpeechSession            = unsafe { nil }
	scripted       &ui2.ScriptedSpeechRecognizer = unsafe { nil }
	system         &ui2.SystemSpeechRecognizer   = unsafe { nil }
	use_system     bool
	ask_permission bool
	at_caret       bool = true
	dark           bool
	message        string = 'Hi Sam,\n\n'
	insertion      ui2.SpeechInsertion
	events         []string
}

const gallery = &Gallery{}

fn heading(content string, x f64, y f64, width f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', content, ui2.rect(x, y, width, 22), ui2.TextStyle{
		color: theme.foreground
		size:  15
		bold:  true
	})
}

fn note(content string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', content, frame, ui2.TextStyle{
		color:  theme.muted_foreground
		size:   12
		lines:  0
		valign: .top
	})
}

fn demo_button(id string, title string, x f64, y f64, width f64, enabled bool, theme ui2.ComponentTheme) ui2.Element {
	return ui2.Element{
		...ui2.button(id, title, ui2.rect(x, y, width, 30), ui2.BoxStyle{
			bg:     theme.muted
			radius: 6
		}, ui2.TextStyle{
			color: if enabled { theme.foreground } else { theme.muted_foreground }
			size:  13
			align: .center
		})
		enabled: enabled
	}
}

fn script_steps(ask_permission bool) []ui2.SpeechScriptStep {
	return ui2.speech_script(demo_transcript,
		permission_delay: if ask_permission {
			1.4
		} else {
			0
		}
	)
}

fn mic_config(app &Gallery, theme ui2.ComponentTheme) ui2.SpeechButtonConfig {
	return ui2.SpeechButtonConfig{
		id:     'mic'
		frame:  ui2.rect(left_width - 52, 156, 40, 40)
		speech: app.session.snapshot()
		round:  true
		filled: true
		size:   .large
		theme:  theme
	}
}

fn indicator_config(app &Gallery, theme ui2.ComponentTheme) ui2.SpeechIndicatorConfig {
	return ui2.SpeechIndicatorConfig{
		id:     'dictation'
		frame:  ui2.rect(12, 162, 340, 28)
		speech: app.session.snapshot()
		theme:  theme
	}
}

// sample_levels is a stretch of speech-like levels for the static waveforms:
// words of a few syllables with short pauses between them.
fn sample_levels(count int) []f64 {
	mut levels := []f64{cap: count}
	mut seed := u32(7)
	for levels.len < count {
		seed = seed * 1103515245 + 12345
		syllables := 2 + int((seed >> 16) % 5)
		for i in 0 .. syllables {
			seed = seed * 1103515245 + 12345
			loud := 0.35 + 0.6 * f64((seed >> 16) % 100) / 100.0
			edge := if i == 0 || i == syllables - 1 { 0.6 } else { 1.0 }
			levels << loud * edge
		}
		levels << 0.0
		if (seed >> 20) % 3 == 0 {
			levels << 0.0
		}
	}
	return levels[..count]
}

fn composer(app &Gallery, theme ui2.ComponentTheme) ui2.Element {
	mut children := []ui2.Element{}
	children << ui2.text_input(
		id:         'message'
		action_id:  'message-changed'
		frame:      ui2.rect(12, 12, left_width - 24, 132)
		text:       app.message
		hint_text:  'Write a message, or dictate one'
		box:        ui2.BoxStyle{
			bg: theme.background
		}
		text_style: ui2.TextStyle{
			color: theme.foreground
			size:  14
		}
	) or { panic(err) }
	children << ui2.view('', ui2.rect(0, 152, left_width, 1), ui2.BoxStyle{
		bg: theme.border
	}, []ui2.Element{})
	children << ui2.speech_indicator(indicator_config(app, theme)) or { panic(err) }
	children << ui2.speech_button(mic_config(app, theme)) or { panic(err) }
	return ui2.view('composer', ui2.rect(left_x, composer_y, left_width, composer_height),
		ui2.BoxStyle{
			bg:            theme.background
			radius:        10
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, children)
}

struct StateRow {
	status ui2.SpeechStatus
	title  string
	hint   string
}

fn state_rows(mut children []ui2.Element, theme ui2.ComponentTheme) {
	rows := [
		StateRow{.idle, 'Idle', 'Press to start dictating'},
		StateRow{.requesting_permission, 'Requesting permission', 'Waiting for the system prompt'},
		StateRow{.connecting, 'Starting', 'Capturing while the recognizer connects'},
		StateRow{.listening, 'Listening', 'Pulses; press to stop'},
		StateRow{.processing, 'Transcribing', 'Waiting for the final result'},
		StateRow{.error, 'Failed', 'The tooltip says why; press to retry'},
		StateRow{.unavailable, 'Unavailable', 'Disabled, with the reason as tooltip'},
	]
	mut y := 122.0
	for row in rows {
		children << ui2.speech_button(
			id:     'state-${row.status}'
			frame:  ui2.rect(right_x, y, 32, 32)
			speech: ui2.SpeechSnapshot{
				status:       row.status
				error:        'Microphone access is off.'
				availability: if row.status == .unavailable {
					ui2.speech_unavailable('Sign in to dictate.')
				} else {
					ui2.speech_available()
				}
			}
			theme:  theme
		) or { panic(err) }
		children << ui2.label('', row.title, ui2.rect(right_x + 44, y - 1, 200, 18), ui2.TextStyle{
			color: theme.foreground
			size:  13
			bold:  true
		})
		children << ui2.label('', row.hint, ui2.rect(right_x + 44, y + 16, right_width - 44, 16),
			ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
			})
		y += 38
	}
}

fn waveform_rows(mut children []ui2.Element, theme ui2.ComponentTheme) {
	levels := sample_levels(64)
	mut y := 418.0
	for height in [12.0, 24] {
		children << ui2.label('', '${int(height)} pt high', ui2.rect(right_x, y + (height - 16) / 2,
			120, 16), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
		})
		children << ui2.speech_waveform(
			frame:  ui2.rect(right_x + 96, y, right_width - 96, height)
			levels: levels
			theme:  theme
		) or { panic(err) }
		y += height + 12
	}
	children << ui2.label('', 'stopped', ui2.rect(right_x, y, 120, 16), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
	children << ui2.speech_waveform(
		frame:  ui2.rect(right_x + 96, y, right_width - 96, 16)
		levels: levels
		active: false
		theme:  theme
	) or { panic(err) }
}

fn system_section(mut children []ui2.Element, app &Gallery, theme ui2.ComponentTheme) {
	availability := app.system.availability()
	mut y := 508.0
	children << heading('System recognizer', right_x, y, right_width, theme)
	y += 30
	children << ui2.label('', ui2.system_speech_recognizer_name(), ui2.rect(right_x, y, right_width,
		18), ui2.TextStyle{
		color: theme.foreground
		size:  13
		bold:  true
	})
	y += 22
	state_text, tone := if availability.available {
		'Available', theme.success
	} else if availability.supported {
		'Unavailable', theme.danger
	} else {
		'Not on this platform', theme.muted_foreground
	}
	children << ui2.view('', ui2.rect(right_x, y + 5, 8, 8), ui2.BoxStyle{
		bg:     tone
		radius: 4
	}, []ui2.Element{})
	children << ui2.label('', state_text, ui2.rect(right_x + 14, y, 200, 18), ui2.TextStyle{
		color: theme.foreground
		size:  13
	})
	y += 26
	can_switch := availability.available || app.use_system
	children << ui2.Element{
		...ui2.checkbox('use-system', 'Dictate with the system recognizer', app.use_system,
			ui2.rect(right_x, y, right_width, 22), ui2.TextStyle{
				color: if can_switch { theme.foreground } else { theme.muted_foreground }
				size:  13
			})
		enabled: can_switch
	}
	y += 30
	reason := if availability.available {
		'Access is asked for when dictation starts. Audio stays on this device.'
	} else {
		availability.reason
	}
	children << note(reason, ui2.rect(right_x, y, right_width, window_height - y - 16), theme)
}

fn build() ui2.Element {
	app := unsafe { gallery }
	theme := ui2.component_theme(app.dark)
	mut children := []ui2.Element{}
	children << ui2.label('', 'Speech', ui2.rect(left_x, 16, 300, 30), ui2.TextStyle{
		color: theme.foreground
		size:  22
		bold:  true
	})
	children << ui2.link(
		id:    'theme'
		text:  'Toggle light / dark'
		frame: ui2.rect(window_width - 24 - 140, 22, 140, 22)
		theme: theme
	) or { panic(err) }
	children << note('A scripted recognizer dictates into the message: press the microphone, watch the words arrive, press again to insert them. Esc cancels.',
		ui2.rect(left_x, 52, left_width, 34), theme)

	children << heading('Dictate into a message', left_x, 92, left_width, theme)
	children << composer(app, theme)
	transcript := app.session.transcript()
	preview_y := composer_y + composer_height + 14
	children << ui2.label('', 'Live transcript', ui2.rect(left_x, preview_y, 200, 16),
		ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
			bold:  true
		})
	active := app.session.status().is_active()
	children << ui2.label('', if active && transcript.len > 0 {
		transcript
	} else if active {
		'Listening for the first words…'
	} else {
		'Words show here while you speak; they go into the message when you stop.'
	}, ui2.rect(left_x, preview_y + 20, left_width, 38), ui2.TextStyle{
		color:  if active { theme.foreground } else { theme.muted_foreground }
		size:   13
		italic: !active
		lines:  2
		valign: .top
	})

	controls_y := preview_y + 66
	status := app.session.status()
	children << demo_button('start', 'Start', left_x, controls_y, 76, status in [
		.idle,
		.error,
	],
		theme)
	children << demo_button('stop', 'Stop', left_x + 84, controls_y, 76, status in [
		.requesting_permission,
		.connecting,
		.listening,
	], theme)
	children << demo_button('cancel', 'Cancel', left_x + 168, controls_y, 76, status.is_active(),
		theme)
	children << ui2.checkbox('at-caret', 'Insert at the caret', app.at_caret, ui2.rect(left_x + 262,
		controls_y + 4, 140, 22), ui2.TextStyle{
		color: theme.foreground
		size:  13
	})
	children << ui2.checkbox('ask', 'Ask for permission', app.ask_permission, ui2.rect(left_x + 404,
		controls_y + 4, 140, 22), ui2.TextStyle{
		color: theme.foreground
		size:  13
	})

	events_y := controls_y + 48
	children << heading('Events', left_x, events_y, left_width, theme)
	mut log := []ui2.Element{}
	for index, line in app.events {
		log << ui2.label('', line, ui2.rect(12, 8 + f64(index) * 20, left_width - 24, 18),
			ui2.TextStyle{
				color:       theme.foreground
				size:        12
				font_family: 'monospace'
			})
	}
	if app.events.len == 0 {
		log << note('Session events appear here: started, partial, final, cancelled, error.',
			ui2.rect(12, 8, left_width - 24, 18), theme)
	}
	children << ui2.view('events', ui2.rect(left_x, events_y + 30, left_width, window_height - events_y - 54),
		ui2.BoxStyle{
			bg:     theme.muted
			radius: 8
		}, log)

	children << heading('Button states', right_x, 92, right_width, theme)
	state_rows(mut children, theme)
	children << heading('Waveform', right_x, 390, right_width, theme)
	waveform_rows(mut children, theme)
	system_section(mut children, app, theme)
	return ui2.screen(theme.background, children)
}

fn log_event(mut app Gallery, line string) {
	app.events << if line.len > 76 { line[..73] + '…' } else { line }
	if app.events.len > 7 {
		app.events.delete(0)
	}
}

// utf16_length is the length of content in UTF-16 code units, the unit of
// text area carets.
fn utf16_length(content string) int {
	mut length := 0
	for r in content.runes() {
		length += if r > 0xffff { 2 } else { 1 }
	}
	return length
}

// current_insertion is where dictation goes now: at the caret (or over the
// selection) of the message, or at its end.
fn current_insertion(app &Gallery) ui2.SpeechInsertion {
	if app.at_caret {
		return ui2.speech_insertion(app.message, ui2.text_area_caret('message'), ui2.text_area_selection_length('message'))
	}
	return ui2.speech_insertion_at_end(app.message)
}

fn on_speech(event ui2.SpeechEvent) {
	mut app := unsafe { gallery }
	match event.kind {
		.started {
			// Dictation goes where the caret was when it started.
			app.insertion = current_insertion(app)
			log_event(mut app, '#${event.session} started')
		}
		.partial {
			log_event(mut app, '#${event.session} partial  “${event.text}”')
		}
		.final {
			mut insertion := app.insertion
			if app.message != insertion.before + insertion.after {
				// The message was edited while dictating: insert at the caret now.
				insertion = current_insertion(app)
			}
			app.message = insertion.text_with(event.text)
			caret := insertion.caret_with(event.text)
			log_event(mut app, '#${event.session} final    “${event.text}”')
			ui2.after(0.05, fn [caret] () {
				ui2.text_area_set_caret('message', caret)
			})
		}
		.cancelled {
			log_event(mut app, '#${event.session} cancelled')
		}
		.error {
			log_event(mut app, '#${event.session} error    ${event.text}')
		}
	}
	// Keep only the latest partial line: each one replaces the one before.
	if event.kind == .partial && app.events.len > 1 && app.events[app.events.len - 2].contains(' partial ') {
		app.events.delete(app.events.len - 2)
	}
}

fn on_event(event string) {
	mut app := unsafe { gallery }
	theme := ui2.component_theme(app.dark)
	if command := ui2.speech_command_from_action(mic_config(app, theme), event) {
		app.session.run(command)
	} else if command := ui2.speech_indicator_command(indicator_config(app, theme), event) {
		app.session.run(command)
	} else {
		match event {
			'message-changed' {
				app.message = ui2.text('message')
				return
			}
			'start' {
				app.session.start()
			}
			'stop' {
				app.session.stop()
			}
			'cancel' {
				app.session.cancel()
			}
			'at-caret' {
				app.at_caret = !app.at_caret
			}
			'ask' {
				app.ask_permission = !app.ask_permission
				app.scripted.steps = script_steps(app.ask_permission)
			}
			'use-system' {
				want := !app.use_system
				recognizer := if want {
					ui2.SpeechRecognizer(app.system)
				} else {
					ui2.SpeechRecognizer(app.scripted)
				}
				if (!want || app.system.availability().available) && app.session.set_recognizer(recognizer) {
					app.use_system = want
				}
			}
			'theme' {
				app.dark = !app.dark
			}
			else {
				return
			}
		}
	}
	ui2.refresh()
}

fn on_key(event ui2.KeyEvent) {
	mut app := unsafe { gallery }
	if command := ui2.speech_command_from_key(app.session.status(), event) {
		app.session.run(command)
		ui2.consume_key()
		ui2.refresh()
	}
}

fn main() {
	mut app := unsafe { gallery }
	app.scripted = ui2.scripted_speech_recognizer(steps: script_steps(false))
	app.system = ui2.system_speech_recognizer(ui2.SystemSpeechRecognizerConfig{})
	app.session = ui2.new_speech_session(app.scripted, on_event: on_speech)
	ui2.on_key_event(on_key)
	// The caret starts at the end of the message, where dictation then goes.
	ui2.after(0.05, fn () {
		app := unsafe { gallery }
		ui2.text_area_set_caret('message', utf16_length(app.message))
	})
	ui2.run_window('GPUI Kit speech', window_width, window_height, build, on_event)
}
