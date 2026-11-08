// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/component/src/shimmer.rs. The sweep timing, the
// spread rules, the layered band geometry and the theme-aware highlight color
// are ported to V; drawing the band as clipped views over skeleton shapes, the
// circle and text pulses and the keyframed loops are new UI2 implementations.
// See third_party/gpui-kit.
module ui2

import math

// Upstream paints twelve translucent layers; ui2 colors are opaque, so the band
// is six nested views stepping from the base color to the highlight.
const shimmer_layer_count = 6

pub struct ShimmerShape {
pub:
	frame  Rect // Relative to the shimmer's frame.
	circle bool // A circle the size of the frame's shorter side, centered in it.
	radius f64 = 6 // Corner radius of a rectangular shape, limited to a pill.
}

// ShimmerConfig describes skeleton placeholders with a highlight sweeping over
// them. Rectangles get a soft band that crosses them; a circle brightens as the
// band passes its center.
pub struct ShimmerConfig {
pub:
	id     string // Required: the sweep runs on its parts.
	frame  Rect
	shapes []ShimmerShape
	// duration of one sweep in seconds; shorter values are clamped to 1 ms.
	duration f64 = 2.0
	// spread is the band's half-width as a fraction of the frame's width,
	// clamped to 0.05...1; a non-finite value keeps the default 0.3.
	spread f64 = 0.3
	// spread_pixels, when positive, is an absolute half-width (at least 1)
	// used instead of spread, so bands of differently sized shimmers match.
	spread_pixels f64
	reverse       bool // Sweep from right to left.
	once          bool // One sweep, then the shapes rest.
	// reduce_motion draws the shapes without a sweep.
	reduce_motion       bool
	base_color          ?u32 // Shape fill; defaults to a gray a step darker than the theme's muted fill.
	highlight_color     ?u32 // Brightest band color; defaults toward the background or, in a dark theme, the foreground.
	accessibility_label string = 'Loading'
	theme               ComponentTheme
}

// shimmer_paragraph returns line shapes for a placeholder paragraph: lines
// rows line_height tall with gap between them, the last one shorter.
pub fn shimmer_paragraph(x f64, y f64, width f64, lines int, line_height f64, gap f64) []ShimmerShape {
	mut shapes := []ShimmerShape{cap: lines}
	for i in 0 .. lines {
		line_width := if i == lines - 1 && lines > 1 { width * 0.6 } else { width }
		shapes << ShimmerShape{
			frame:  rect(x, y + f64(i) * (line_height + gap), line_width, line_height)
			radius: line_height / 2
		}
	}
	return shapes
}

// shimmer_half_width resolves a sweep's spread to the band's half-width in a
// frame width wide, following GPUI's rules for relative and absolute spreads.
pub fn shimmer_half_width(width f64, spread f64, spread_pixels f64) f64 {
	if component_finite(spread_pixels) && spread_pixels > 0 {
		return math.max(spread_pixels, 1)
	}
	fraction := if component_finite(spread) { math.clamp(spread, 0.05, 1) } else { 0.3 }
	return width * fraction
}

// shimmer_band_center is where the band's center is at a fraction t of a
// sweep across width. The sweep starts and ends with the whole band outside the
// frame, five percent of the width beyond its edge.
pub fn shimmer_band_center(t f64, width f64, half f64, reverse bool) f64 {
	if width <= 0 {
		return 0
	}
	padding := half / width + 0.05
	phase := if reverse { 1 - t } else { t }
	return (phase * (1 + 2 * padding) - padding) * width
}

// shimmer_band_time is the inverse of shimmer_band_center.
fn shimmer_band_time(center f64, width f64, half f64, reverse bool) f64 {
	if width <= 0 {
		return 0
	}
	padding := half / width + 0.05
	phase := (center / width + padding) / (1 + 2 * padding)
	return if reverse { 1 - phase } else { phase }
}

// shimmer_band_span is the part of the band of half-width half centered at
// center that lies over [start, start + extent], as an offset from start and a
// width. It is empty while the band is elsewhere.
pub fn shimmer_band_span(center f64, half f64, start f64, extent f64) (f64, f64) {
	left := math.clamp(center - half, start, start + extent)
	right := math.clamp(center + half, start, start + extent)
	return left - start, right - left
}

// shimmer_pulse_level is how bright a shape centered at middle is while the
// band's center is at center: full when they meet, nothing a half-width away.
fn shimmer_pulse_level(center f64, middle f64, half f64) f64 {
	if half <= 0 {
		return 0
	}
	return math.max(0, 1 - math.abs(center - middle) / half)
}

// shimmer_band_spans keyframes the band over [start, start + extent] of the
// sweep, offset by inset within its shape.
fn shimmer_band_spans(width f64, half f64, reverse bool, start f64, extent f64, inset f64) []FeedbackSpan {
	mut critical := []f64{}
	for edge in [start - half, start + half, start + extent - half, start + extent + half] {
		critical << shimmer_band_time(edge, width, half, reverse)
	}
	mut spans := []FeedbackSpan{}
	for t in feedback_times(1, critical) {
		x, w := shimmer_band_span(shimmer_band_center(t, width, half, reverse), half, start,
			extent)
		spans << FeedbackSpan{
			at:    t
			x:     inset + x
			width: w
		}
	}
	return feedback_compact_spans(spans)
}

fn shimmer_pulse_keys(width f64, half f64, reverse bool, middle f64) []FeedbackKey {
	mut critical := []f64{}
	for edge in [middle - half, middle, middle + half] {
		critical << shimmer_band_time(edge, width, half, reverse)
	}
	mut keys := []FeedbackKey{}
	for t in feedback_times(1, critical) {
		keys << FeedbackKey{
			at:    t
			level: shimmer_pulse_level(shimmer_band_center(t, width, half, reverse), middle,
				half)
		}
	}
	return feedback_compact_keys(keys)
}

// shimmer_base_color is the default shape fill. The muted fill skeleton uses is
// barely darker than a light background, which would leave a lighter band
// nothing to show against, so light themes take a step toward the border color.
fn shimmer_base_color(theme ComponentTheme) u32 {
	if feedback_is_dark(theme) {
		return theme.muted
	}
	return interpolate_color(theme.muted, theme.border, 0.45)
}

fn shimmer_highlight_default(theme ComponentTheme, base u32) u32 {
	if feedback_is_dark(theme) {
		return interpolate_color(base, theme.foreground, 0.16)
	}
	return interpolate_color(base, theme.background, 0.8)
}

fn shimmer_validate_duration(duration f64) !f64 {
	if !component_finite(duration) || duration < 0 {
		return error('shimmer duration must be finite and non-negative')
	}
	return math.max(duration, 0.001)
}

pub fn shimmer(config ShimmerConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	period := shimmer_validate_duration(config.duration)!
	width := config.frame.width
	half := shimmer_half_width(width, config.spread, config.spread_pixels)
	base := config.base_color or { shimmer_base_color(config.theme) }
	highlight := config.highlight_color or { shimmer_highlight_default(config.theme, base) }
	shape_theme := ComponentTheme{
		...config.theme
		muted: base
	}
	animate := !config.reduce_motion && width > 0
	// The keyframes depend on where every shape is, so moving one restarts the sweep.
	mut values := [width, half, period, if config.reverse { 1.0 } else { 0.0 },
		if config.once { 1.0 } else { 0.0 }]
	for shape in config.shapes {
		component_validate_frame(shape.frame)!
		feedback_validate_length('shimmer shape radius', shape.radius)!
		values << [shape.frame.x, shape.frame.y, shape.frame.width, shape.frame.height, shape.radius,
			if shape.circle { 1.0 } else { 0.0 }]
	}
	signature := feedback_signature(values, [base, highlight])
	start := if animate {
		feedback_should_start(config.id, 'sheen', component_part_id(config.id, 'sheen:${signature}:0'),
			config.once)
	} else {
		feedback_clear_parts(config.id, 'sheen')
		false
	}
	mut children := []Element{cap: config.shapes.len}
	for index, shape in config.shapes {
		placeholder := skeleton(
			frame:  shape.frame
			circle: shape.circle
			radius: shape.radius
			theme:  shape_theme
		)!
		// Every shape gets a first part, so the group's first id always exists.
		if shape.circle {
			mut disc := placeholder.children[0]
			if animate {
				part := component_part_id(config.id, 'sheen:${signature}:${index}')
				if start {
					middle := shape.frame.x + disc.frame.x + disc.frame.width / 2
					component_keep_animating(part, feedback_level_loop(period, shimmer_pulse_keys(width,
						half, config.reverse, middle), base, highlight, .background, !config.once))
				}
				disc = Element{
					...disc
					id: part
				}
			}
			children << Element{
				...placeholder
				children: [disc]
			}
			continue
		}
		// The band is square. AppKit clips it to the rounded shape; elsewhere it
		// crosses only the shape's straight middle so it never pokes past a corner.
		inset := if feedback_parent_clips() {
			0.0
		} else {
			math.min(placeholder.box.radius, shape.frame.width / 2)
		}
		mut bands := []Element{}
		if animate {
			for layer in 0 .. shimmer_layer_count {
				part := if layer == 0 {
					component_part_id(config.id, 'sheen:${signature}:${index}')
				} else {
					component_part_id(config.id, 'sheen:${signature}:${index}:${layer}')
				}
				layer_half := half * (1 - f64(layer) / f64(shimmer_layer_count))
				if start {
					component_keep_animating(part, feedback_span_loop(period, shimmer_band_spans(width,
						layer_half, config.reverse, shape.frame.x + inset, shape.frame.width - 2 * inset,
						inset), !config.once))
				}
				bands << view(part, rect(inset, 0, 0, shape.frame.height), BoxStyle{
					bg: interpolate_color(base, highlight, f64(layer + 1) / f64(shimmer_layer_count))
				}, []Element{})
			}
		}
		children << Element{
			...placeholder
			children: bands
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'status'
		accessibility_label: config.accessibility_label
	})
}

// ShimmerTextConfig describes GPUI's ShimmerText: readable loading text such as
// "Thinking…" that keeps moving while work is under way.
pub struct ShimmerTextConfig {
pub:
	id       string // Required: the animation runs on a part.
	frame    Rect
	text     string
	duration f64 = 2.0 // Seconds per sweep; shorter values are clamped to 1 ms.
	// spread and spread_pixels size the band as in ShimmerConfig. A label
	// cannot be painted in part, so the whole text brightens while the band is
	// over its frame's center: a wider band makes a longer pulse.
	spread              f64 = 0.3
	spread_pixels       f64
	once                bool // One pulse, then plain text.
	reduce_motion       bool // Plain text.
	color               ?u32 // Defaults to the theme's foreground.
	highlight_color     ?u32 // Defaults to the text color moved toward the background (or foreground in a dark theme).
	font_size           f64  // Zero uses the size preset.
	bold                bool
	align               Align
	size                ComponentSize = .medium
	accessibility_label string // Defaults to the text.
	theme               ComponentTheme
}

// shimmer_text_highlight is GPUI's theme-aware highlight target: the background
// in a light theme and the foreground in a dark one, or the other end when the
// text already has that lightness, mixed with the text color.
pub fn shimmer_text_highlight(text_color u32, theme ComponentTheme) u32 {
	dark := feedback_is_dark(theme)
	mut target := if dark { theme.foreground } else { theme.background }
	if math.abs(feedback_luminance(target) - feedback_luminance(text_color)) < 0.1 {
		target = if dark { theme.background } else { theme.foreground }
	}
	return interpolate_color(text_color, target, 0.45)
}

pub fn shimmer_text(config ShimmerTextConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	period := shimmer_validate_duration(config.duration)!
	feedback_validate_length('shimmer text font size', config.font_size)!
	text_color := config.color or { config.theme.foreground }
	highlight := config.highlight_color or { shimmer_text_highlight(text_color, config.theme) }
	width := config.frame.width
	half := shimmer_half_width(width, config.spread, config.spread_pixels)
	animate := !config.reduce_motion && width > 0
	signature := feedback_signature([width, half, period, if config.once { 1.0 } else { 0.0 }],
		[text_color, highlight])
	part := if animate { component_part_id(config.id, 'sheen:${signature}') } else { '' }
	if animate {
		if feedback_should_start(config.id, 'sheen', part, config.once) {
			component_keep_animating(part, feedback_level_loop(period, shimmer_pulse_keys(width,
				half, false, width / 2), text_color, highlight, .text_color, !config.once))
		}
	} else {
		feedback_clear_parts(config.id, 'sheen')
	}
	text_label := Element{
		...label(part, config.text, component_local(config.frame), TextStyle{
			color: text_color
			size:  if config.font_size > 0 {
				config.font_size
			} else {
				component_metrics(config.size).font_size
			}
			bold:  config.bold
			align: config.align
		})
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			config.text
		}
	}
	return component_finish(view(config.id, config.frame, BoxStyle{ transparent: true }, [
		text_label,
	]))
}
