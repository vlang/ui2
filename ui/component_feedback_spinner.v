module ui2

import math

// LoadingSpinnerKind picks the look of a loading_spinner. GPUI turns a Loader or
// LoaderCircle icon; ui2 cannot rotate views, so both are drawn from parts that
// light up in turn instead.
pub enum LoadingSpinnerKind {
	dots // GPUI's Loader: eight dots, the head bright and the ones behind it fading.
	ring // GPUI's LoaderCircle: a three-quarter arc going round a faint track.
}

// LoadingSpinnerConfig describes an indeterminate loading indicator. It is
// named loading_spinner because ui2's spinner is a selection control.
pub struct LoadingSpinnerConfig {
pub:
	id    string // Required: the animation runs on its parts.
	frame Rect
	kind  LoadingSpinnerKind
	// diameter is centered in frame and limited to it. Zero uses the size
	// preset: small 14, medium 16, large 24 (GPUI's xsmall is diameter: 12).
	diameter f64
	duration f64 = 0.8 // Seconds per revolution; the head eases in and out like GPUI's.
	// reduce_motion draws the spinner at rest without starting an animation.
	reduce_motion bool
	tone          ComponentTone = .neutral
	color         ?u32 // Defaults to the tone's color; neutral is the muted text color.
	track_color   ?u32 // Resting dots and the ring's track; defaults to the color at 20% over the background.
	// background is the surface the spinner sits on, which the track is mixed
	// with and the ring's hole is filled with; it defaults to the theme's.
	background          ?u32
	size                ComponentSize = .medium
	accessibility_label string        = 'Loading'
	theme               ComponentTheme
}

// loading_spinner_diameter returns GPUI's spinner size for a size preset.
pub fn loading_spinner_diameter(size ComponentSize) f64 {
	return match size {
		.small { 14 }
		.medium { 16 }
		.large { 24 }
	}
}

// loading_spinner_head is where the spinner's head is, in turns from twelve
// o'clock, at a fraction t of a revolution.
pub fn loading_spinner_head(t f64) f64 {
	return feedback_ease(t)
}

// The dots spinner has eight dots, and its tail fades over this much of a turn.
const spinner_dot_count = 8
const spinner_dot_tail = 0.75
// The ring's arc covers three quarters of a turn.
const spinner_ring_arc = 0.75

// spinner_dot_level is how lit a dot is when the head has gone distance turns
// past it: full at the head, fading over the tail and back up just before the
// head arrives again.
fn spinner_dot_level(distance f64) f64 {
	rise := 0.5 / f64(spinner_dot_count)
	d := feedback_fraction(distance)
	if d <= spinner_dot_tail {
		return 1 - d / spinner_dot_tail
	}
	if d >= 1 - rise {
		return (d - (1 - rise)) / rise
	}
	return 0
}

fn spinner_dot_keys(turn f64) []FeedbackKey {
	rise := 0.5 / f64(spinner_dot_count)
	mut critical := []f64{}
	for distance in [0.0, spinner_dot_tail, 1 - rise] {
		critical << feedback_ease_inverse(feedback_fraction(turn + distance))
	}
	mut keys := []FeedbackKey{}
	for t in feedback_times(16, critical) {
		keys << FeedbackKey{
			at:    t
			level: spinner_dot_level(loading_spinner_head(t) - turn)
		}
	}
	return feedback_compact_keys(keys)
}

// spinner_ring_window is the part of a revolution during which the ring's arc
// covers the turn `middle`: from when the head reaches it until the tail
// leaves it.
fn spinner_ring_window(middle f64) (f64, f64) {
	return feedback_ease_inverse(middle), feedback_ease_inverse(feedback_fraction(middle +
		spinner_ring_arc))
}

pub fn loading_spinner(config LoadingSpinnerConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	feedback_validate_length('spinner diameter', config.diameter)!
	feedback_validate_length('spinner duration', config.duration)!
	diameter := math.min(if config.diameter > 0 {
		config.diameter
	} else {
		loading_spinner_diameter(config.size)
	}, math.min(config.frame.width, config.frame.height))
	color := config.color or { feedback_tone_color(config.theme, config.tone) }
	background := config.background or { config.theme.background }
	track := config.track_color or { feedback_track_color(color, background) }
	period := math.max(config.duration, 0.001)
	animate := !config.reduce_motion && diameter > 0
	// Dots fade between colors, so a new color restarts them; the ring only moves
	// its cells, which take a new color as they are.
	signature := feedback_signature([diameter, period, f64(int(config.kind))], if config.kind == .dots {
		[color, track]
	} else {
		[]u32{}
	})
	if !animate {
		feedback_clear_parts(config.id, 'spin')
	}
	mut parts := []Element{}
	match config.kind {
		.dots {
			start := animate && feedback_should_start(config.id, 'spin', component_part_id(config.id,
				'spin:${signature}:0'), false)
			dot := math.min(math.max(2.0, diameter * 0.2), diameter)
			ring := (diameter - dot) / 2
			for i in 0 .. spinner_dot_count {
				turn := f64(i) / f64(spinner_dot_count)
				part := if animate {
					component_part_id(config.id, 'spin:${signature}:${i}')
				} else {
					''
				}
				if start {
					component_keep_animating(part, feedback_level_loop(period, spinner_dot_keys(turn),
						track, color, .background, true))
				}
				parts << view(part, feedback_ring_cell(diameter / 2, diameter / 2, ring, dot,
					turn), BoxStyle{
					bg:     interpolate_color(track, color, spinner_dot_level(-turn))
					radius: dot / 2
				}, []Element{})
			}
		}
		.ring {
			stroke := math.min(math.max(1.5, diameter * 0.12), diameter / 2)
			parts << feedback_ring_track(diameter, stroke, track, background)
			if animate {
				parts << feedback_ring_loop(config.id, 'spin', signature, diameter, stroke, color,
					period, .spinner)
			} else {
				// At rest the arc runs from three o'clock round to twelve.
				ring := (diameter - stroke) / 2
				first, last := progress_circle_lit_turns(100 * spinner_ring_arc, ring, stroke)
				for piece in feedback_ring_pieces(diameter, stroke, first + 0.25, last + 0.25,
					1) {
					parts << view('', piece.frame, BoxStyle{
						bg:     color
						radius: piece.radius
					}, []Element{})
				}
			}
		}
	}
	ring_view := view('', rect((config.frame.width - diameter) / 2, (config.frame.height - diameter) / 2,
		diameter, diameter), BoxStyle{ transparent: true }, parts)
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, [ring_view])
		accessibility_role:  'progressbar'
		accessibility_label: config.accessibility_label
	})
}
