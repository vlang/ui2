// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/component/src/progress/progress.rs and
// progress_circle.rs. The size presets, the 20% track, the ring's stroke width
// and the start/end curves of both indeterminate animations are ported to V;
// drawing them from views, the ring of round cells, the keyframed loops and the
// value transitions are new UI2 implementations. See third_party/gpui-kit.
module ui2

import math

// LinearProgressConfig describes GPUI's linear Progress: a pill-shaped bar
// whose value is a percentage. It complements progress_bar, which keeps its
// Kivy-style value/max API.
pub struct LinearProgressConfig {
pub:
	id    string // Required: the indeterminate loop and value transitions run on its parts.
	frame Rect
	value f64 // Percent, clamped to 0...100.
	// loading shows an indeterminate sliding animation and ignores value.
	loading bool
	// reduce_motion renders loading as a static centered segment and changes
	// value without a transition.
	reduce_motion bool
	transition    f64           = 0.25 // Seconds a value change takes; zero jumps.
	duration      f64           = 1.0  // Seconds per indeterminate cycle.
	tone          ComponentTone = .primary
	color         ?u32 // Indicator color; defaults to the tone's color.
	track_color   ?u32 // Defaults to the indicator color at 20% over the background.
	// thickness is the bar height, centered vertically in frame. Zero uses the
	// size preset: small 6, medium 8, large 10 (GPUI's xsmall is thickness: 4).
	thickness           f64
	radius              ?f64 // Corner radius; defaults to a pill.
	size                ComponentSize = .medium
	accessibility_label string        = 'Progress'
	theme               ComponentTheme
}

// linear_progress_thickness returns GPUI's bar height for a size.
pub fn linear_progress_thickness(size ComponentSize) f64 {
	return match size {
		.small { 6 }
		.medium { 8 }
		.large { 10 }
	}
}

// linear_progress_loading_span is the indeterminate indicator at a fraction t of
// its cycle, as (left, right) fractions of the track: the right edge eases out
// to the end over the whole cycle while the left edge follows in the second
// half, so the bar grows from the start and then drains away at the end.
pub fn linear_progress_loading_span(t f64) (f64, f64) {
	return feedback_ease(math.clamp((t - 0.5) * 2, 0, 1)), feedback_ease(t)
}

fn linear_progress_loading_spans(width f64) []FeedbackSpan {
	mut spans := []FeedbackSpan{}
	for t in feedback_times(32, [0.5]) {
		left, right := linear_progress_loading_span(t)
		spans << FeedbackSpan{
			at:    t
			x:     left * width
			width: (right - left) * width
		}
	}
	return feedback_compact_spans(spans)
}

// feedback_width_target is the width the last tween started on id is heading
// for, so a rebuild with the same value leaves a running transition alone.
fn feedback_width_target(id string) ?f64 {
	runtime := g_animation_runtime
	runtime.mutex.lock()
	defer {
		runtime.mutex.unlock()
	}
	if id !in runtime.runs {
		return none
	}
	definition := runtime.runs[id].definition
	if definition.kind != .tween {
		return none
	}
	return definition.targets.width
}

// feedback_transition_width eases the width of id to target over duration. The
// first build only records the width; later changes animate from what is on
// screen. A zero duration releases the element to its declared width.
fn feedback_transition_width(id string, target f64, duration f64) {
	current := feedback_width_target(id)
	if duration <= 0 {
		if _ := current {
			clear_animation(id)
		}
		return
	}
	if previous := current {
		if math.abs(previous - target) > 1e-6 {
			animation(duration: duration, transition: .out_cubic, width: target).start(id)
		}
		return
	}
	animation(duration: 0, width: target).start(id)
}

pub fn linear_progress(config LinearProgressConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	feedback_validate_length('progress thickness', config.thickness)!
	feedback_validate_length('progress transition', config.transition)!
	feedback_validate_length('progress duration', config.duration)!
	width := config.frame.width
	thickness := math.min(if config.thickness > 0 {
		config.thickness
	} else {
		linear_progress_thickness(config.size)
	}, config.frame.height)
	requested_radius := config.radius or { thickness / 2 }
	feedback_validate_length('progress radius', requested_radius)!
	radius := math.min(requested_radius, thickness / 2)
	color := config.color or { feedback_tone_color(config.theme, config.tone) }
	track := config.track_color or { feedback_track_color(color, config.theme.background) }
	percent := progress_percent(config.value)
	period := math.max(config.duration, 0.001)
	indicator_box := BoxStyle{
		bg:     color
		radius: radius
	}
	mut indicator := Element{}
	if config.loading {
		if config.reduce_motion {
			feedback_clear_parts(config.id, 'loading')
			indicator = view('', rect(width * 0.325, 0, width * 0.35, thickness), indicator_box,
				[]Element{})
		} else {
			signature := feedback_signature([width, period], []u32{})
			part := component_part_id(config.id, 'loading:${signature}')
			if feedback_should_start(config.id, 'loading', part, false) {
				component_keep_animating(part, feedback_span_loop(period, linear_progress_loading_spans(width),
					true))
			}
			indicator = view(part, rect(0, 0, 0, thickness), indicator_box, []Element{})
		}
	} else {
		feedback_clear_parts(config.id, 'loading')
		part := component_part_id(config.id, 'indicator')
		target := width * percent / 100
		feedback_transition_width(part, target, if config.reduce_motion {
			0.0
		} else {
			config.transition
		})
		indicator = view(part, rect(0, 0, target, thickness), indicator_box, []Element{})
	}
	track_view := view('', rect(0, (config.frame.height - thickness) / 2, width, thickness),
		BoxStyle{
			bg:     track
			radius: radius
		}, [indicator])
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, [track_view])
		accessibility_role:  'progressbar'
		accessibility_label: config.accessibility_label
		accessibility_value: if config.loading { '' } else { progress_value_text(percent) }
	})
}

// progress_value_text is how a percentage is announced: whole percents, and a
// tenth only when the value has one.
pub fn progress_value_text(percent f64) string {
	rounded := math.round(percent * 10) / 10
	if rounded == math.round(rounded) {
		return '${i64(rounded)}%'
	}
	return '${rounded:.1f}%'
}

pub struct ProgressCircleConfig {
pub:
	id    string // Required: the indeterminate loop runs on its parts.
	frame Rect
	value f64 // Percent, clamped to 0...100.
	// loading shows GPUI's indeterminate arc, which grows from twelve o'clock
	// around the ring and is then chased off it by its tail. value is ignored.
	loading       bool
	reduce_motion bool // Loading draws a still quarter arc instead.
	duration      f64 = 1.0 // Seconds per indeterminate cycle.
	// diameter of the ring, centered in frame and limited to it. Zero uses the
	// size preset: small 12, medium 16, large 20.
	diameter f64
	// thickness of the ring; zero is GPUI's 15% of the diameter, at most 5.
	thickness   f64
	tone        ComponentTone = .primary
	color       ?u32 // Arc color; defaults to the tone's color.
	track_color ?u32 // Defaults to the arc color at 20% over the background.
	// background fills the ring's hole; it defaults to the theme's background.
	// Set it to the surface color when the ring sits on a card or a button.
	background ?u32
	// label and caption are centered in the ring, caption below label in a
	// smaller muted face. Give the ring room for them, such as diameter: 80.
	label   string
	caption string
	// children are placed inside the ring, relative to the ring's square.
	children            []Element
	size                ComponentSize = .medium
	accessibility_label string        = 'Progress'
	theme               ComponentTheme
}

// progress_circle_diameter returns GPUI's ring size for a size preset.
pub fn progress_circle_diameter(size ComponentSize) f64 {
	return match size {
		.small { 12 }
		.medium { 16 }
		.large { 20 }
	}
}

// progress_circle_thickness is GPUI's stroke for a ring of a given diameter.
pub fn progress_circle_thickness(diameter f64) f64 {
	return math.min(diameter * 0.15, 5)
}

// progress_circle_loading_arc is the indeterminate arc at a fraction t of its
// cycle, as (start, end) fractions of a turn from twelve o'clock: the end eases
// around the ring over the cycle and the start follows in the second half.
pub fn progress_circle_loading_arc(t f64) (f64, f64) {
	return feedback_ease(math.clamp((t - 0.5) * 2, 0, 1)), feedback_ease(t)
}

// progress_circle_sector_window is the part of the cycle during which the
// indeterminate arc covers the turn `middle`: from when its end passes there
// until its start does.
fn progress_circle_sector_window(middle f64) (f64, f64) {
	return feedback_ease_inverse(middle), 0.5 + feedback_ease_inverse(middle) / 2
}

// progress_circle_lit_turns is the stretch of the ring, in turns, between the
// centers of the round ends of the arc for percent. The ends reach half a
// stroke beyond those centers, so the stretch is pulled in by that much at each
// end to make the arc start at twelve o'clock and end where the value does.
fn progress_circle_lit_turns(percent f64, ring f64, stroke f64) (f64, f64) {
	if percent <= 0 || ring <= 0 {
		return 0.0, 0.0
	}
	if percent >= 100 {
		return 0.0, 1.0
	}
	half_stroke := stroke / 2 / (2 * math.pi * ring)
	end := percent / 100 - half_stroke
	return if end <= half_stroke {
		half_stroke, half_stroke
	} else {
		half_stroke, end
	}
}

pub fn progress_circle(config ProgressCircleConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	feedback_validate_length('progress circle diameter', config.diameter)!
	feedback_validate_length('progress circle thickness', config.thickness)!
	feedback_validate_length('progress circle duration', config.duration)!
	fit := math.min(config.frame.width, config.frame.height)
	diameter := math.min(if config.diameter > 0 {
		config.diameter
	} else {
		progress_circle_diameter(config.size)
	}, fit)
	stroke := math.min(if config.thickness > 0 {
		config.thickness
	} else {
		progress_circle_thickness(diameter)
	}, diameter / 2)
	ring := (diameter - stroke) / 2
	color := config.color or { feedback_tone_color(config.theme, config.tone) }
	background := config.background or { config.theme.background }
	track := config.track_color or { feedback_track_color(color, background) }
	percent := progress_percent(config.value)
	period := math.max(config.duration, 0.001)
	full := !config.loading && percent >= 100
	mut parts := feedback_ring_track(diameter, stroke, if full { color } else { track },
		background)
	if config.loading && !config.reduce_motion && diameter > 0 {
		signature := feedback_signature([diameter, stroke, period], []u32{})
		parts << feedback_ring_loop(config.id, 'loading', signature, diameter, stroke, color,
			period, .progress)
	} else {
		feedback_clear_parts(config.id, 'loading')
		first, last := if config.loading {
			progress_circle_lit_turns(25, ring, stroke)
		} else {
			progress_circle_lit_turns(percent, ring, stroke)
		}
		if (config.loading || percent > 0) && !full {
			for piece in feedback_ring_pieces(diameter, stroke, first, last, 1) {
				parts << view('', piece.frame, BoxStyle{
					bg:     color
					radius: piece.radius
				}, []Element{})
			}
		}
	}
	metrics := component_metrics(config.size)
	if config.label.len > 0 || config.caption.len > 0 {
		inner := math.max(diameter - 2 * stroke, 0)
		label_height := if config.label.len > 0 {
			math.min(metrics.font_size * 1.4, inner)
		} else {
			0.0
		}
		caption_size := math.max(metrics.font_size - 3, 9)
		caption_height := if config.caption.len > 0 {
			math.min(caption_size * 1.4, inner - label_height)
		} else {
			0.0
		}
		mut y := (diameter - label_height - caption_height) / 2
		if config.label.len > 0 {
			parts << label('', config.label, rect(stroke, y, inner, label_height), TextStyle{
				color: color
				size:  metrics.font_size
				bold:  true
				align: .center
			})
			y += label_height
		}
		if config.caption.len > 0 {
			parts << label('', config.caption, rect(stroke, y, inner, caption_height),
				TextStyle{
					color: config.theme.muted_foreground
					size:  caption_size
					align: .center
				})
		}
	}
	parts << config.children
	ring_view := view('', rect((config.frame.width - diameter) / 2, (config.frame.height - diameter) / 2,
		diameter, diameter), BoxStyle{ transparent: true }, parts)
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, [ring_view])
		accessibility_role:  'progressbar'
		accessibility_label: config.accessibility_label
		accessibility_value: if config.loading { '' } else { progress_value_text(percent) }
	})
}
