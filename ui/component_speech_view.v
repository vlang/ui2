module ui2

import math

// The speech views draw a SpeechSnapshot: speech_button starts and stops
// dictation (GPUI Kit's SpeechButton), speech_waveform shows the input levels
// (SpeechWaveform) and speech_indicator is a status pill with a cancel button.
// Like every component they are controlled: they emit actions, which
// speech_command_from_action (or SpeechSession.handle_action) decodes.

// speech_button_action_id is the action a speech button emits when pressed.
pub fn speech_button_action_id(id string) string {
	return component_part_id(id, 'toggle')
}

// speech_cancel_action_id is the action a speech indicator's cancel button
// emits.
pub fn speech_cancel_action_id(id string) string {
	return component_part_id(id, 'cancel')
}

pub struct SpeechButtonConfig {
pub:
	id     string
	frame  Rect
	speech SpeechSnapshot
	// show_when_unsupported draws a disabled button where there is no
	// recognizer at all; by default the button is hidden there, so an
	// application can place it unconditionally (GPUI Kit's default).
	show_when_unsupported bool
	enabled               bool = true // False for application reasons, such as a read-only field.
	round                 bool   // A circle instead of GPUI Kit's rounded square.
	filled                bool   // A muted fill at rest instead of a ghost button.
	reduce_motion         bool   // No pulse while listening and a still spinner.
	tooltip               string // Replaces the status tooltip.
	accessibility_label   string        = 'Dictation'
	size                  ComponentSize = .medium
	theme                 ComponentTheme
}

// speech_button_tooltip is the help a speech button shows for a snapshot.
pub fn speech_button_tooltip(speech SpeechSnapshot) string {
	return match speech.status {
		.idle { 'Start dictation' }
		.requesting_permission { 'Waiting for permission — click to stop' }
		.connecting { 'Starting — click to stop' }
		.listening { 'Stop dictation' }
		.processing { 'Transcribing…' }
		.error { speech.reason() + ' Click to try again.' }
		.unavailable { speech.reason() }
	}
}

// speech_command_from_action decodes an action a speech button (or a speech
// indicator with the same id) emitted, against the snapshot the application
// shows now. A press starts dictation when idle or failed and stops it while
// it asks for permission, starts or listens; the indicator's cancel button
// cancels a running session. Foreign, malformed and forged actions, actions
// while the button is disabled or unavailable, and no-ops (a press while
// processing, a cancel with nothing to cancel) are rejected.
pub fn speech_command_from_action(config SpeechButtonConfig, action string) ?SpeechCommand {
	return speech_decode(config.id, config.speech.status, config.enabled, action)
}

fn speech_decode(id string, status SpeechStatus, enabled bool, action string) ?SpeechCommand {
	part := component_action_part(id, action) or { return none }
	if !enabled {
		return none
	}
	if part == 'toggle' {
		if status in [.idle, .error] {
			return .start
		}
		if status in [.requesting_permission, .connecting, .listening] {
			return .stop
		}
	} else if part == 'cancel' && status.is_active() {
		return .cancel
	}
	return none
}

// speech_command_from_key is the command a key asks for: Escape cancels a
// running session. Components cannot capture keys; call it from on_key_event.
pub fn speech_command_from_key(status SpeechStatus, event KeyEvent) ?SpeechCommand {
	if event.code == .escape && !event.shift && !event.ctrl && !event.alt && !event.cmd
		&& status.is_active() {
		return .cancel
	}
	return none
}

// stop_speech_animations stops the pulse and spinner loops a speech button or
// indicator started under id. They stop by themselves when the status changes;
// call this when the application stops showing a running one.
pub fn stop_speech_animations(id string) {
	if id.len > 0 {
		feedback_clear_parts(id, 'pulse')
		stop_feedback_animations(component_part_id(id, 'spinner'))
	}
}

fn speech_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

fn speech_tint(color u32, background u32, amount f64) u32 {
	return interpolate_color(background, color, amount)
}

fn speech_centered_square(frame Rect, side f64) Rect {
	s := math.max(math.min(side, math.min(frame.width, frame.height)), 0)
	return rect(frame.x + (frame.width - s) / 2, frame.y + (frame.height - s) / 2, s, s)
}

struct SpeechButtonLook {
	bg      u32
	fill    bool
	icon    string // Empty for the spinner.
	color   u32
	enabled bool
}

fn speech_button_look(config SpeechButtonConfig) SpeechButtonLook {
	theme := config.theme
	rest := if config.filled { theme.muted } else { theme.background }
	return match config.speech.status {
		.idle {
			SpeechButtonLook{rest, config.filled, 'mic', theme.foreground, true}
		}
		.requesting_permission {
			SpeechButtonLook{speech_tint(theme.primary, theme.background, 0.16), true, 'lock', theme.primary, true}
		}
		.connecting {
			// Capturing already, but not recognizing yet: the listening look, lighter.
			SpeechButtonLook{speech_tint(theme.primary, theme.background, 0.7), true, 'stop.fill', theme.primary_foreground, true}
		}
		.listening {
			SpeechButtonLook{theme.primary, true, 'stop.fill', theme.primary_foreground, true}
		}
		.processing {
			SpeechButtonLook{speech_tint(theme.primary, theme.background, 0.16), true, '', theme.primary, false}
		}
		.error {
			SpeechButtonLook{speech_tint(theme.danger, theme.background, 0.16), true, 'exclamationmark.triangle', theme.danger, true}
		}
		.unavailable {
			SpeechButtonLook{rest, config.filled, 'mic', speech_tint(theme.muted_foreground, theme.background,
				0.6), false}
		}
	}
}

// speech_button is the button that starts and stops dictation. It shows a
// microphone at rest, a lock while asking for permission, a stop glyph on the
// primary color (with a pulse) while listening, a spinner while transcribing,
// a warning after a failure, and a dimmed microphone, disabled, while the
// recognizer is unavailable. The tooltip says what a press does or why it
// cannot.
pub fn speech_button(config SpeechButtonConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	status := config.speech.status
	theme := config.theme
	spinner_id := component_part_id(config.id, 'spinner')
	hidden := status == .unavailable && !config.speech.availability.supported
		&& !config.show_when_unsupported
	body_frame := speech_centered_square(component_local(config.frame), math.min(config.frame.width,
		config.frame.height))
	side := body_frame.width
	radius := if config.round {
		side / 2
	} else {
		math.min(component_metrics(config.size).radius, side / 2)
	}
	animate := !config.reduce_motion && !hidden && side > 0
	pulsing := animate && status == .listening
	if !pulsing {
		feedback_clear_parts(config.id, 'pulse')
	}
	if status != .processing || hidden {
		stop_feedback_animations(spinner_id)
	}
	if hidden {
		return component_finish(Element{
			...view(config.id, config.frame, BoxStyle{ transparent: true }, []Element{})
			hidden: true
		})
	}
	look := speech_button_look(config)
	enabled := config.enabled && look.enabled
	color := if config.enabled {
		look.color
	} else {
		speech_tint(theme.muted_foreground, theme.background, 0.6)
	}
	icon_side := math.round(math.max(math.min(side * 0.5, side), 0))
	icon_frame := speech_centered_square(rect(0, 0, side, side), icon_side)
	mut content := []Element{}
	if look.icon.len > 0 {
		content << speech_symbol(look.icon, icon_frame, color)
	} else {
		content << loading_spinner(
			id:            spinner_id
			frame:         speech_centered_square(rect(0, 0, side, side), math.round(side * 0.56))
			kind:          .ring
			color:         theme.primary
			background:    look.bg
			reduce_motion: config.reduce_motion
			theme:         theme
		)!
	}
	mut children := []Element{}
	if pulsing {
		signature := feedback_signature([side, radius], [theme.primary])
		pulse_id := component_part_id(config.id, 'pulse:${signature}')
		if feedback_should_start(config.id, 'pulse', pulse_id, false) {
			component_keep_animating(pulse_id, speech_pulse_loop(side))
		}
		children << view(pulse_id, body_frame, BoxStyle{
			bg:     theme.primary
			radius: radius
			shadow: BoxShadow{
				color:   theme.primary
				opacity: 0.5
				blur:    2
			}
		}, []Element{})
	}
	body := Element{
		...button_view(component_part_id(config.id, 'body'), body_frame, BoxStyle{
			bg:          look.bg
			transparent: !look.fill
			radius:      radius
		}, content)
		action_id:           speech_button_action_id(config.id)
		enabled:             enabled
		tooltip:             if config.tooltip.len > 0 {
			config.tooltip
		} else {
			speech_button_tooltip(config.speech)
		}
		accessibility_label: config.accessibility_label
		accessibility_value: speech_status_text(status)
		cursor:              if enabled { cursor_pointing_hand } else { cursor_default }
	}
	children << body
	return component_finish(view(config.id, config.frame, BoxStyle{ transparent: true },
		children))
}

// speech_pulse_loop is the ring that swells out of a listening button and
// fades, once a second.
fn speech_pulse_loop(side f64) Animation {
	return sequence(animation(
		duration:   0
		properties: [animation_number_property('box.shadow.opacity', 0.55),
			animation_number_property('box.shadow.spread', 0)]
	), animation(
		duration:   1.1
		transition: .out_quad
		properties: [animation_number_property('box.shadow.opacity', 0),
			animation_number_property('box.shadow.spread', math.round(side * 0.3))]
	)).repeating()
}

pub struct SpeechWaveformConfig {
pub:
	id     string
	frame  Rect
	levels []f64 // Oldest first, 0 to 1; the newest is drawn at the trailing edge.
	active bool = true // Capturing: drawn in the primary color, otherwise muted.
	color  ?u32 // Replaces the color.
	// bar_width is the width of a bar; zero follows the height (an eighth of
	// it, 2 to 4 points, as GPUI Kit's).
	bar_width f64
	gap       f64 // Space between bars; zero is one and a half bars.
	theme     ComponentTheme
}

// speech_waveform_bar_width is the bar width a waveform of height uses.
pub fn speech_waveform_bar_width(height f64) f64 {
	return math.clamp(math.round(height * 0.125), 2, 4)
}

// speech_waveform_bars places one bar per level in a width by height area,
// newest at the trailing edge and older ones toward the leading edge, as many
// as fit. Each bar is centered on the midline and at least as tall as it is
// wide, so silence reads as a dot; only levels that exist are drawn, so a
// short history leaves the leading part empty.
pub fn speech_waveform_bars(width f64, height f64, levels []f64, bar f64, gap f64) []Rect {
	if width <= 0 || height <= 0 || bar <= 0 || levels.len == 0 {
		return []
	}
	pitch := bar + math.max(gap, 0)
	fit := int(math.floor((width + math.max(gap, 0)) / pitch))
	count := math.min(fit, levels.len)
	mut bars := []Rect{cap: count}
	for i in 0 .. count {
		level := levels[levels.len - count + i]
		h := math.min(math.max(height * math.clamp(level, 0, 1), bar), height)
		x := width - f64(count - i) * pitch + math.max(gap, 0)
		bars << rect(x, (height - h) / 2, bar, h)
	}
	return bars
}

// speech_waveform draws input levels as bars that grow up and down from the
// midline, the newest at the trailing edge. Feed it SpeechSession.levels():
// a running session adds a level every speech_level_interval and rebuilds, so
// the bars scroll toward the leading edge as audio arrives.
pub fn speech_waveform(config SpeechWaveformConfig) !Element {
	component_validate_frame(config.frame)!
	bar := if config.bar_width > 0 {
		config.bar_width
	} else {
		speech_waveform_bar_width(config.frame.height)
	}
	if !component_finite(bar) || !component_finite(config.gap) || config.gap < 0 {
		return error('speech waveform bar width and gap must be finite and non-negative')
	}
	gap := if config.gap > 0 { config.gap } else { math.max(math.round(bar * 1.5), 2) }
	color := config.color or {
		if config.active { config.theme.primary } else { config.theme.muted_foreground }
	}
	// The custom renderer pays for every rounded corner in vertices; bars this
	// thin look the same square.
	radius := if feedback_draws_strips() { 0.0 } else { bar / 2 }
	mut children := []Element{}
	for frame in speech_waveform_bars(config.frame.width, config.frame.height, config.levels,
		bar, gap) {
		children << view('', frame, BoxStyle{
			bg:     color
			radius: math.min(radius, frame.height / 2)
		}, []Element{})
	}
	latest := if config.levels.len > 0 { math.clamp(config.levels.last(), 0, 1) } else { 0.0 }
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'img'
		accessibility_label: 'Input level'
		accessibility_value: '${int(math.round(latest * 100))}%'
	})
}

pub struct SpeechIndicatorConfig {
pub:
	id     string
	frame  Rect
	speech SpeechSnapshot
	text   string // Replaces the status text.
	// show_levels draws a small waveform while the session captures.
	show_levels bool = true
	// cancellable shows a cancel button while a session runs; it emits
	// speech_cancel_action_id(id).
	cancellable   bool = true
	reduce_motion bool
	size          ComponentSize = .small
	theme         ComponentTheme
}

// speech_indicator_text is what an indicator says for a snapshot: the status,
// or the reason after a failure or while unavailable.
pub fn speech_indicator_text(speech SpeechSnapshot) string {
	reason := speech.reason()
	return if reason.len > 0 { reason } else { speech_status_text(speech.status) }
}

// speech_indicator_command decodes the indicator's cancel button.
pub fn speech_indicator_command(config SpeechIndicatorConfig, action string) ?SpeechCommand {
	part := component_action_part(config.id, action) or { return none }
	if part != 'cancel' || !config.cancellable {
		return none
	}
	return speech_decode(config.id, config.speech.status, true, action)
}

// speech_indicator is a status pill: a mark for the status (a recording dot
// while listening, a spinner while transcribing, a warning after a failure),
// the status text, the input levels while capturing and a cancel button while
// a session runs.
pub fn speech_indicator(config SpeechIndicatorConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	theme := config.theme
	status := config.speech.status
	metrics := component_metrics(config.size)
	spinner_id := component_part_id(config.id, 'spinner')
	if status != .processing {
		stop_feedback_animations(spinner_id)
	}
	w := config.frame.width
	h := config.frame.height
	pad := math.min(metrics.padding + 2, w / 4)
	mark := math.round(math.min(metrics.font_size, h))
	tone := match status {
		.listening { theme.danger }
		.requesting_permission { theme.warning }
		.connecting, .processing { theme.primary }
		.error { theme.danger }
		.idle, .unavailable { theme.muted_foreground }
	}
	bg := match status {
		.error, .listening { speech_tint(theme.danger, theme.background, 0.12) }
		.requesting_permission { speech_tint(theme.warning, theme.background, 0.16) }
		.connecting, .processing { speech_tint(theme.primary, theme.background, 0.12) }
		.idle, .unavailable { theme.muted }
	}
	mut children := []Element{}
	mark_frame := rect(pad, (h - mark) / 2, mark, mark)
	match status {
		.processing {
			children << loading_spinner(
				id:            spinner_id
				frame:         mark_frame
				kind:          .ring
				color:         theme.primary
				background:    bg
				reduce_motion: config.reduce_motion
				theme:         theme
			)!
		}
		.error {
			children << speech_symbol('exclamationmark.triangle', mark_frame, theme.danger)
		}
		.requesting_permission {
			children << speech_symbol('lock', mark_frame, tone)
		}
		else {
			dot := math.round(mark * 0.6)
			children << view('', speech_centered_square(mark_frame, dot), BoxStyle{
				bg:     tone
				radius: dot / 2
			}, []Element{})
		}
	}
	mut right := w - pad
	active := status.is_active()
	if config.cancellable && active && h > 0 {
		side := math.min(h - 4, metrics.height)
		frame := rect(w - side - 2, (h - side) / 2, side, side)
		children << Element{
			...button_view(component_part_id(config.id, 'cancel-button'), frame, BoxStyle{
				transparent: true
				radius:      side / 2
			}, [
				speech_symbol('xmark', speech_centered_square(component_local(frame), math.round(metrics.font_size - 1)),
					theme.muted_foreground),
			])
			action_id:           speech_cancel_action_id(config.id)
			tooltip:             'Cancel dictation'
			accessibility_label: 'Cancel dictation'
			cursor:              cursor_pointing_hand
		}
		right = frame.x - 2
	}
	if config.show_levels && status.is_capturing() {
		wave_width := math.min(96.0, math.max(right - pad - mark - 96, 0))
		if wave_width >= 16 {
			wave_height := math.round(math.min(h - 8, metrics.font_size + 6))
			children << speech_waveform(
				frame:  rect(right - wave_width, (h - wave_height) / 2, wave_width, wave_height)
				levels: config.speech.levels
				active: true
				color:  tone
				theme:  theme
			)!
			right -= wave_width + metrics.gap
		}
	}
	text_x := pad + mark + metrics.gap + 2
	caption := if config.text.len > 0 { config.text } else { speech_indicator_text(config.speech) }
	children << label('', caption, rect(text_x, 0, math.max(right - text_x, 0), h), TextStyle{
		color: if status in [.idle, .unavailable] {
			theme.muted_foreground
		} else {
			theme.foreground
		}
		size:  metrics.font_size
	})
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{
			bg:     bg
			radius: h / 2
		}, children)
		accessibility_role:  'status'
		accessibility_label: caption
		accessibility_value: speech_status_text(status)
	})
}
