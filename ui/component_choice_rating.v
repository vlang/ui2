// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/component/src/rating.rs. The rule that turns a
// click on a star into the new value is ported to V; rendering, validation,
// keyboard stepping and action decoding are new UI2 implementations. See
// third_party/gpui-kit.
module ui2

import math

// rating_max_stars bounds the work a rating does for any requested maximum.
pub const rating_max_stars = 50

pub struct RatingConfig {
pub:
	id       string
	frame    Rect
	value    int // Clamped to 0..max.
	max      int  = 5
	enabled  bool = true // False: not interactive and dimmed.
	readonly bool // True: not interactive, drawn at full strength.
	tone     ComponentTone = .warning // Color of the filled stars.
	size     ComponentSize = .medium
	theme    ComponentTheme
}

pub fn rating_action_id(id string, star int) string {
	return component_part_id(id, 'star:${star}')
}

fn rating_interactive(config RatingConfig) bool {
	return config.enabled && !config.readonly
}

fn rating_clamped_value(config RatingConfig) int {
	return if config.value < 0 {
		0
	} else if config.value > config.max {
		config.max
	} else {
		config.value
	}
}

// rating_value_after_click is upstream's rule: clicking a filled star sets
// the rating to the star before it, and clicking an empty star fills up to
// it. Clicking the highest filled star therefore lowers the rating by one,
// and clicking the first star of a non-empty rating clears it.
pub fn rating_value_after_click(value int, star int) int {
	return if value >= star { star - 1 } else { star }
}

fn rating_star_size(metrics ComponentMetrics) f64 {
	return math.round(metrics.height * 0.8)
}

// rating_width is the width a rating of max stars wants at size.
pub fn rating_width(max int, size ComponentSize) f64 {
	return f64(math.max(max, 0)) * rating_star_size(component_metrics(size))
}

// rating_star draws one star filling frame: the solid `star.fill` symbol on
// every renderer, in the color that says whether it is lit.
fn rating_star(frame Rect, color u32) Element {
	return choice_icon('star.fill', frame, color)
}

fn rating_label(value int, max int) string {
	return '${value} of ${max} stars'
}

// rating shows max stars with the first `value` filled. Stars are filled
// glyphs in the tone's color and empty ones take the border color, so the two
// stay distinct in both themes and on every renderer.
pub fn rating(config RatingConfig) !Element {
	component_validate_frame(config.frame)!
	if config.max < 1 || config.max > rating_max_stars {
		return error('rating max must be between 1 and ${rating_max_stars}')
	}
	interactive := rating_interactive(config)
	if interactive {
		component_validate_id(config.id)!
	}
	metrics := component_metrics(config.size)
	value := rating_clamped_value(config)
	tone, _ := config.theme.colors(config.tone)
	mut filled_color := tone
	mut empty_color := config.theme.border
	if !config.enabled {
		filled_color = choice_mix(filled_color, config.theme.background, 0.5)
		empty_color = choice_mix(empty_color, config.theme.background, 0.4)
	}
	cell := math.max(0.0, math.min(rating_star_size(metrics), math.min(config.frame.width / f64(config.max),
		config.frame.height)))
	y := (config.frame.height - cell) / 2
	mut children := []Element{cap: config.max}
	for star in 1 .. config.max + 1 {
		filled := star <= value
		frame := rect(f64(star - 1) * cell, y, cell, cell)
		glyph := rating_star(component_local(frame), if filled { filled_color } else { empty_color })
		if interactive {
			children << Element{
				...button_view(rating_action_id(config.id, star), frame, BoxStyle{ transparent: true }, [
					glyph,
				])
				key:                 'star:${star}'
				accessibility_label: if star == 1 { '1 star' } else { '${star} stars' }
				accessibility_value: if filled { 'filled' } else { 'empty' }
			}
		} else {
			children << Element{
				...view('', frame, BoxStyle{ transparent: true }, [glyph])
				key: 'star:${star}'
			}
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  if interactive { 'group' } else { 'img' }
		accessibility_label: 'Rating'
		accessibility_value: rating_label(value, config.max)
	})
}

// rating_value_from_action returns the rating a click on a star asks for,
// following rating_value_after_click. It returns none for foreign, malformed
// or out-of-range actions and for readonly or disabled ratings.
pub fn rating_value_from_action(config RatingConfig, action string) ?int {
	if !rating_interactive(config) || config.max < 1 || config.max > rating_max_stars {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	if !part.starts_with('star:') {
		return none
	}
	star := component_parse_index(part['star:'.len..], config.max) or { return none }
	if star < 1 {
		return none
	}
	return rating_value_after_click(rating_clamped_value(config), star)
}

// rating_value_after_key steps a rating from the keyboard: right/up add a
// star, left/down remove one, home clears and end fills, and a digit key sets
// that many stars. Call it from on_key_event while the rating has focus in
// the application's model.
pub fn rating_value_after_key(config RatingConfig, code KeyCode) ?int {
	if !rating_interactive(config) || config.max < 1 || config.max > rating_max_stars {
		return none
	}
	value := rating_clamped_value(config)
	next := match code {
		.right, .up { math.min(value + 1, config.max) }
		.left, .down { math.max(value - 1, 0) }
		.home { 0 }
		.end { config.max }
		._0, ._1, ._2, ._3, ._4, ._5, ._6, ._7, ._8, ._9 { int(code) - int(KeyCode._0) }
		else { return none }
	}
	if next == value || next > config.max {
		return none
	}
	return next
}
