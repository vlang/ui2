module ui2

import hash.fnv1a
import math

// Shared machinery for the feedback components: linear_progress, progress_circle,
// loading_spinner, shimmer and shimmer_text.
//
// ui2 has no canvas, no clipping view and no per-frame callback, so every moving
// part is an ordinary view driven by a looping animation from animation.v: a
// sequence of linear tweens through keyframes that begins with a zero-length
// tween to its first keyframe, so every cycle starts from the same values
// whatever was on screen before. Colors fade through keyframes; the cells of a
// ring jump in and out of sight instead, so a moving arc costs one animated
// element per cell and none of them has to be recolored.
//
// A looping animation keeps running until it is stopped, even after its element
// leaves the tree, and the native backends redraw for as long as one runs. Part
// ids carry a signature of everything their keyframes depend on, so a new color,
// size or speed starts a fresh set of loops and clears the old ones; call
// stop_feedback_animations when a component is no longer shown.

// FeedbackKey is one keyframe of a looping part: at is the fraction of the cycle,
// level how far the part is between its resting and its lit color.
struct FeedbackKey {
	at    f64
	level f64
}

// FeedbackSpan is one keyframe of a part that moves: its x and width at a
// fraction of the cycle.
struct FeedbackSpan {
	at    f64
	x     f64
	width f64
}

enum FeedbackChannel {
	background
	text_color
}

// stop_feedback_animations cancels and forgets every looping animation a feedback
// component started under id. Call it when the application stops showing a
// loading_spinner, shimmer, shimmer_text or loading progress indicator: the loop
// otherwise keeps running, and the native backends keep redrawing, after the
// element has left the tree. Building the component again starts it afresh.
pub fn stop_feedback_animations(id string) {
	if id.len > 0 {
		feedback_clear_parts(id, '')
	}
}

// progress_percent clamps a percentage to 0...100. NaN counts as no progress.
pub fn progress_percent(value f64) f64 {
	if math.is_nan(value) {
		return 0
	}
	return math.clamp(value, 0, 100)
}

// feedback_ease is GPUI's ease_in_out, a quadratic ease in and out.
fn feedback_ease(t f64) f64 {
	x := math.clamp(t, 0, 1)
	if x < 0.5 {
		return 2 * x * x
	}
	y := 2 - 2 * x
	return 1 - y * y / 2
}

// feedback_ease_inverse returns the time at which feedback_ease reaches y.
fn feedback_ease_inverse(y f64) f64 {
	v := math.clamp(y, 0, 1)
	if v < 0.5 {
		return math.sqrt(v / 2)
	}
	return 1 - math.sqrt(2 * (1 - v)) / 2
}

// feedback_fraction wraps a number of turns into [0, 1).
fn feedback_fraction(turns f64) f64 {
	wrapped := turns - math.floor(turns)
	return if wrapped >= 1 { 0.0 } else { wrapped }
}

fn feedback_luminance(color u32) f64 {
	r := f64((color >> 16) & 0xff) / 255
	g := f64((color >> 8) & 0xff) / 255
	b := f64(color & 0xff) / 255
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

// feedback_is_dark tells a dark theme from a light one by its background, since
// ComponentTheme carries colors rather than a mode.
fn feedback_is_dark(theme ComponentTheme) bool {
	return feedback_luminance(theme.background) < 0.5
}

// feedback_tone_color is the indicator color of a tone. The neutral tone's fill
// is a near-background gray, so its indicator uses the muted text color.
fn feedback_tone_color(theme ComponentTheme, tone ComponentTone) u32 {
	if tone == .neutral {
		return theme.muted_foreground
	}
	fill, _ := theme.colors(tone)
	return fill
}

// feedback_track_color is color drawn at 20% over background: the translucent
// track GPUI draws, flattened because ui2 colors are opaque.
fn feedback_track_color(color u32, background u32) u32 {
	return interpolate_color(color, background, 0.8)
}

fn feedback_validate_length(name string, value f64) ! {
	if !component_finite(value) || value < 0 {
		return error('${name} must be finite and non-negative')
	}
}

// feedback_signature condenses the values a loop's keyframes depend on into a
// short tag for its part ids.
fn feedback_signature(values []f64, colors []u32) string {
	mut parts := []string{cap: values.len + colors.len}
	for value in values {
		parts << '${value:.3f}'
	}
	for color in colors {
		parts << '${color:06x}'
	}
	return '${fnv1a.sum32_string(parts.join('|')):08x}'
}

// feedback_clear_parts clears every animation registered under the parts of id
// whose name starts with group.
fn feedback_clear_parts(id string, group string) {
	prefix := component_part_id(id, group)
	if prefix.len == 0 {
		return
	}
	mut stale := []string{}
	runtime := g_animation_runtime
	runtime.mutex.lock()
	for key, _ in runtime.runs {
		if key.starts_with(prefix) {
			stale << key
		}
	}
	runtime.mutex.unlock()
	for key in stale {
		clear_animation(key)
	}
}

// feedback_should_start decides whether a component must (re)start the loops of
// one group, whose first part id is first. Loops are started together, so the
// first part speaks for the group. Before a restart every animation left in the
// group by an earlier configuration is cleared. A one-shot sweep that has
// completed stays completed.
fn feedback_should_start(id string, group string, first string, once bool) bool {
	status := animation_info(first).status
	if status == .running || (once && status == .completed) {
		return false
	}
	feedback_clear_parts(id, group)
	return true
}

// feedback_compact_keys drops keyframes that lie on the line through their
// neighbors: flat stretches and straight ramps need only their ends.
fn feedback_compact_keys(keys []FeedbackKey) []FeedbackKey {
	if keys.len <= 2 {
		return keys
	}
	mut compact := [keys[0]]
	for i in 1 .. keys.len - 1 {
		previous := compact[compact.len - 1]
		next := keys[i + 1]
		span := next.at - previous.at
		expected := if span <= 0 {
			previous.level
		} else {
			previous.level + (next.level - previous.level) * (keys[i].at - previous.at) / span
		}
		if math.abs(expected - keys[i].level) > 1e-4 {
			compact << keys[i]
		}
	}
	compact << keys[keys.len - 1]
	return compact
}

// feedback_times merges evenly spaced samples with the instants at which a
// level changes slope, sorted and without near duplicates, all within [0, 1].
fn feedback_times(samples int, critical []f64) []f64 {
	mut times := []f64{cap: samples + 1 + critical.len}
	for k in 0 .. samples + 1 {
		times << f64(k) / f64(samples)
	}
	for t in critical {
		if component_finite(t) && t > 0 && t < 1 {
			times << t
		}
	}
	times.sort()
	mut unique := []f64{cap: times.len}
	for t in times {
		if unique.len == 0 || t - unique[unique.len - 1] > 1e-6 {
			unique << t
		}
	}
	return unique
}

// feedback_level_loop animates a color channel between off and on through keys,
// which run from at = 0 to at = 1 over period seconds.
fn feedback_level_loop(period f64, keys []FeedbackKey, off u32, on u32, channel FeedbackChannel, repeat bool) Animation {
	mut steps := []Animation{cap: keys.len}
	for i, key in keys {
		duration := if i == 0 { 0.0 } else { (key.at - keys[i - 1].at) * period }
		color := interpolate_color(off, on, math.clamp(key.level, 0, 1))
		steps << match channel {
			.background { animation(duration: duration, background: color) }
			.text_color { animation(duration: duration, text_color: color) }
		}
	}
	definition := sequence(...steps)
	return if repeat { definition.repeating() } else { definition }
}

// feedback_span_loop animates x and width through spans over period seconds.
fn feedback_span_loop(period f64, spans []FeedbackSpan, repeat bool) Animation {
	mut steps := []Animation{cap: spans.len}
	for i, span in spans {
		duration := if i == 0 { 0.0 } else { (span.at - spans[i - 1].at) * period }
		steps << animation(duration: duration, x: span.x, width: span.width)
	}
	definition := sequence(...steps)
	return if repeat { definition.repeating() } else { definition }
}

// feedback_compact_spans drops spans that lie on the line through their
// neighbors in both x and width.
fn feedback_compact_spans(spans []FeedbackSpan) []FeedbackSpan {
	if spans.len <= 2 {
		return spans
	}
	mut compact := [spans[0]]
	for i in 1 .. spans.len - 1 {
		previous := compact[compact.len - 1]
		next := spans[i + 1]
		span := next.at - previous.at
		ratio := if span <= 0 { 0.0 } else { (spans[i].at - previous.at) / span }
		x := previous.x + (next.x - previous.x) * ratio
		width := previous.width + (next.width - previous.width) * ratio
		if math.abs(x - spans[i].x) > 1e-3 || math.abs(width - spans[i].width) > 1e-3 {
			compact << spans[i]
		}
	}
	compact << spans[spans.len - 1]
	return compact
}

// A sector loop hides a part by moving it this far to the left.
const feedback_hidden_x = -100000.0

// feedback_toggle_loop puts a part at shown_x from on to off of every cycle and
// moves it out of sight for the rest. The window may wrap past the cycle's end.
// Showing and hiding are jumps: a part is either drawn in full or not at all.
fn feedback_toggle_loop(period f64, on f64, off f64, shown_x f64) Animation {
	mut times := [0.0, 1.0]
	for t in [feedback_fraction(on), feedback_fraction(off)] {
		if t > 0 {
			times << t
		}
	}
	times.sort()
	mut steps := []Animation{}
	for i in 0 .. times.len - 1 {
		length := times[i + 1] - times[i]
		if length <= 1e-9 {
			continue
		}
		middle := (times[i] + times[i + 1]) / 2
		x := if feedback_window_contains(on, off, middle) { shown_x } else { feedback_hidden_x }
		steps << animation(duration: 0, x: x)
		steps << animation(duration: length * period, x: x)
	}
	return sequence(...steps).repeating()
}

// feedback_window_contains reports whether t lies in the cyclic window that
// opens at on and closes at off.
fn feedback_window_contains(on f64, off f64, t f64) bool {
	return feedback_fraction(t - on) < feedback_fraction(off - on)
}

// FeedbackPiece is one shape of a ring: its frame in the ring's square box and
// the sector of the ring it lies in.
struct FeedbackPiece {
	frame  Rect
	radius f64
	sector int
}

// The custom renderer spends some 370 sokol-gl vertices on every rounded rect
// and has 65,536 a frame, so rings of round cells would blank a busy window
// there. It gets scan-converted strips instead, which cost six vertices each;
// the other renderers draw round cells, which they antialias.
fn feedback_draws_strips() bool {
	$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
		return true
	} $else {
		return false
	}
}

// feedback_parent_clips reports whether the renderer clips a view's children to
// its rounded corners, as AppKit does by masking a layer with a corner radius.
fn feedback_parent_clips() bool {
	$if macos && !ui2_custom_rendering ? {
		return true
	} $else {
		return false
	}
}

// feedback_ring_pieces covers the stretch of a ring from turn `from` to turn
// `to` (clockwise from twelve o'clock; a whole turn or more is the full ring)
// with pieces split into `sectors` equal sectors. A single sector draws round
// ends half the stroke beyond from and to.
fn feedback_ring_pieces(diameter f64, stroke f64, from f64, to f64, sectors int) []FeedbackPiece {
	if feedback_draws_strips() {
		return feedback_ring_strips(diameter, stroke, from, to, sectors, feedback_strip_row(diameter))
	}
	return feedback_ring_cells(diameter, stroke, from, to, sectors, 0.5)
}

// feedback_strip_row is the height of a ring's scan lines: one device pixel on
// a 2x display for small rings, a point for large ones.
fn feedback_strip_row(diameter f64) f64 {
	return if diameter <= 200 { 0.5 } else { 1.0 }
}

fn feedback_sector(turn f64, sectors int) int {
	if sectors <= 1 {
		return 0
	}
	index := int(feedback_fraction(turn) * f64(sectors))
	return if index >= sectors { sectors - 1 } else { index }
}

// feedback_ring_cells places round cells of the stroke's diameter along the
// ring's centerline, spacing strokes apart, so they overlap into a smooth band
// whose ends are round.
fn feedback_ring_cells(diameter f64, stroke f64, from f64, to f64, sectors int, spacing f64) []FeedbackPiece {
	ring := (diameter - stroke) / 2
	center := diameter / 2
	span := math.min(to - from, 1.0)
	if ring <= 0 || stroke <= 0 || span < 0 {
		return []FeedbackPiece{}
	}
	full := span >= 1
	steps := math.max(1, int(math.ceil(2 * math.pi * ring * span / (stroke * spacing))))
	count := if full { steps } else { steps + 1 }
	mut pieces := []FeedbackPiece{cap: count}
	for i in 0 .. count {
		turn := from + span * f64(i) / f64(steps)
		pieces << FeedbackPiece{
			frame:  feedback_ring_cell(center, center, ring, stroke, turn)
			radius: stroke / 2
			sector: feedback_sector(turn, sectors)
		}
	}
	return pieces
}

struct FeedbackInterval {
	start  f64
	end    f64
	sector int
}

// feedback_ring_strips scan-converts the same band into horizontal strips row
// tall, the way chart.v draws doughnut slices: each row of the ring is split
// where a sector boundary crosses it, and kept where it lies between from and
// to. A single sector also takes in the round end caps and merges each row
// into as few strips as possible.
fn feedback_ring_strips(diameter f64, stroke f64, from f64, to f64, sectors int, row f64) []FeedbackPiece {
	outer := diameter / 2
	inner := outer - stroke
	center := diameter / 2
	span := math.min(to - from, 1.0)
	if outer <= 0 || stroke <= 0 || row <= 0 || span < 0 {
		return []FeedbackPiece{}
	}
	full := span >= 1
	mut boundaries := []f64{}
	if sectors > 1 {
		for k in 0 .. sectors {
			boundaries << f64(k) / f64(sectors)
		}
	}
	if !full {
		boundaries << from
		boundaries << to
	}
	middle := (outer + inner) / 2
	caps := sectors <= 1 && !full
	mut cap_centers := []f64{}
	if caps {
		for turn in [from, to] {
			angle := turn * 2 * math.pi
			cap_centers << middle * math.sin(angle)
			cap_centers << -middle * math.cos(angle)
		}
	}
	rows := int(math.ceil(diameter / row))
	mut pieces := []FeedbackPiece{}
	for r in 0 .. rows {
		y0 := -outer + f64(r) * row
		y1 := math.min(outer, y0 + row)
		y := (y0 + y1) / 2
		mut segments := [][]f64{}
		if math.abs(y) < outer {
			half := math.sqrt(outer * outer - y * y)
			if math.abs(y) < inner {
				hole := math.sqrt(inner * inner - y * y)
				segments << [-half, -hole]
				segments << [hole, half]
			} else {
				segments << [-half, half]
			}
		}
		mut kept := []FeedbackInterval{}
		for segment in segments {
			mut edges := [segment[0], segment[1]]
			for turn in boundaries {
				angle := turn * 2 * math.pi
				dy := -math.cos(angle)
				if math.abs(dy) > 1e-10 && y / dy >= 0 {
					x := y * math.sin(angle) / dy
					if x > segment[0] && x < segment[1] {
						edges << x
					}
				}
			}
			edges.sort()
			for j in 0 .. edges.len - 1 {
				if edges[j + 1] - edges[j] <= 1e-9 {
					continue
				}
				x := (edges[j] + edges[j + 1]) / 2
				turn := feedback_fraction(math.atan2(x, -y) / (2 * math.pi))
				if !full && feedback_fraction(turn - from) > span {
					continue
				}
				kept << FeedbackInterval{edges[j], edges[j + 1], feedback_sector(turn, sectors)}
			}
		}
		if caps {
			for c in 0 .. 2 {
				cx := cap_centers[c * 2]
				cy := cap_centers[c * 2 + 1]
				dy := y - cy
				if math.abs(dy) < stroke / 2 {
					chord := math.sqrt(stroke * stroke / 4 - dy * dy)
					kept << FeedbackInterval{cx - chord, cx + chord, 0}
				}
			}
			kept.sort(a.start < b.start)
			mut merged := []FeedbackInterval{}
			for interval in kept {
				if merged.len > 0 && interval.start <= merged[merged.len - 1].end + 1e-9 {
					last := merged[merged.len - 1]
					merged[merged.len - 1] = FeedbackInterval{last.start, math.max(last.end,
						interval.end), 0}
				} else {
					merged << interval
				}
			}
			kept = merged.clone()
		}
		for interval in kept {
			pieces << FeedbackPiece{
				frame:  rect(center + interval.start, center + y0, interval.end - interval.start,
					y1 - y0)
				sector: interval.sector
			}
		}
	}
	return pieces
}

// feedback_ring_track is the ring's track: a disc in the track color with a
// disc of the background over its middle. ui2 colors are opaque, so the hole
// shows the background color rather than whatever lies behind the ring.
fn feedback_ring_track(diameter f64, stroke f64, track u32, background u32) []Element {
	hole := math.max(diameter - 2 * stroke, 0)
	return [
		view('', rect(0, 0, diameter, diameter), BoxStyle{
			bg:     track
			radius: diameter / 2
		}, []Element{}),
		view('', rect(stroke, stroke, hole, hole), BoxStyle{
			bg:     background
			radius: hole / 2
		}, []Element{}),
	]
}

// FeedbackArcMotion is how the arc of an animated ring moves.
enum FeedbackArcMotion {
	spinner  // A three-quarter arc eased once round the ring per cycle.
	progress // GPUI's indeterminate arc: it grows round the ring, then its tail chases it off.
}

// window is the part of the cycle during which the arc covers turn.
fn (motion FeedbackArcMotion) window(turn f64) (f64, f64) {
	return match motion {
		.spinner { spinner_ring_window(turn) }
		.progress { progress_circle_sector_window(turn) }
	}
}

// Strips are shown and hidden this many sectors at a time.
const feedback_ring_sectors = 24

// feedback_ring_loop draws the arc of an animated ring. Each round cell, or each
// of feedback_ring_sectors sectors of strips, is a part under group that a
// looping animation shows while the arc covers it, so the arc moves without
// any element changing color. Cells overlap, and each one shown on top of the
// track gives the arc round ends.
fn feedback_ring_loop(id string, group string, signature string, diameter f64, stroke f64, color u32, period f64, motion FeedbackArcMotion) []Element {
	start := feedback_should_start(id, group, component_part_id(id, '${group}:${signature}:0'),
		false)
	mut parts := []Element{}
	if feedback_draws_strips() {
		sectors := feedback_ring_sectors
		mut groups := [][]Element{len: sectors}
		for piece in feedback_ring_strips(diameter, stroke, 0, 1, sectors, feedback_strip_row(diameter)) {
			groups[piece.sector] << view('', piece.frame, BoxStyle{ bg: color }, []Element{})
		}
		for i in 0 .. sectors {
			part := component_part_id(id, '${group}:${signature}:${i}')
			on, off := motion.window((f64(i) + 0.5) / f64(sectors))
			if start {
				component_keep_animating(part, feedback_toggle_loop(period, on, off, 0))
			}
			parts << view(part, rect(if feedback_window_contains(on, off, 0) {
				0.0
			} else {
				feedback_hidden_x
			}, 0, diameter, diameter), BoxStyle{ transparent: true }, groups[i])
		}
		return parts
	}
	cells := feedback_ring_cells(diameter, stroke, 0, 1, 1, 0.6)
	for i, cell in cells {
		part := component_part_id(id, '${group}:${signature}:${i}')
		on, off := motion.window(f64(i) / f64(cells.len))
		if start {
			component_keep_animating(part, feedback_toggle_loop(period, on, off, cell.frame.x))
		}
		parts << view(part, Rect{
			...cell.frame
			x: if feedback_window_contains(on, off, 0) { cell.frame.x } else { feedback_hidden_x }
		}, BoxStyle{
			bg:     color
			radius: cell.radius
		}, []Element{})
	}
	return parts
}

// feedback_ring_cell is the frame of a round cell of diameter cell whose center
// lies on a circle of radius ring around (cx, cy), turn of a revolution
// clockwise from twelve o'clock.
fn feedback_ring_cell(cx f64, cy f64, ring f64, cell f64, turn f64) Rect {
	angle := turn * 2 * math.pi
	x := cx + ring * math.sin(angle)
	y := cy - ring * math.cos(angle)
	return rect(x - cell / 2, y - cell / 2, cell, cell)
}
