module ui2

import math

// GPUI Kit's Slider drawn from views: one thumb or a range of two, horizontal
// or vertical, stepped or continuous, linear or logarithmic, with marks, a
// value bubble, three sizes, a custom color, a reversed fill and keyboard
// steps. The platform `slider` (slider.v) stays the native single-thumb
// control. See component_controls.v.
//
// The track and the thumbs are draggable views. Decode what they emit with
// styled_slider_change: pointer events carry window coordinates, so the config
// says where its frame is in the window through origin_x and origin_y.

// SliderScale maps a thumb's position to a value. Logarithmic gives finer
// control at the low end of a wide range: value = min * (max / min)^position,
// so min must be above zero.
pub enum SliderScale {
	linear
	logarithmic
}

// SliderThumb names a thumb: `value` is the only thumb of a single slider,
// `start` and `end` are the two thumbs of a range.
pub enum SliderThumb {
	value
	start
	end
}

// SliderValueLabel is when the value bubble shows over a thumb.
pub enum SliderValueLabel {
	hidden
	active // Over the active thumb while the slider is focused (pressed or driven by keys).
	always // Over every thumb; the two bubbles of a range merge when they would overlap.
}

// SliderMark is a point on the track: a dot, with a label under (or beside) it
// when label is not empty.
pub struct SliderMark {
pub:
	value f64
	label string
}

pub struct StyledSliderConfig {
pub:
	id    string
	frame Rect // Parent-local, as every component frame.
	// Pointer events carry window coordinates. origin is the window position of
	// the element frame is relative to: zero for a child of the screen, the
	// parent's window position for a slider nested in views.
	origin_x f64
	origin_y f64
	min      f64
	max      f64 = 100
	step     f64 = 1 // Values snap to min + k * step; zero is continuous.
	value    f64 // The value of a single slider.
	// range shows two thumbs selecting start..end; value is then unused.
	range       bool
	start       f64
	end         f64
	scale       SliderScale
	orientation Orientation // Vertical sliders have min at the bottom.
	// reverse fills the track from the thumb to max instead of from min to the
	// thumb, for a remaining amount. Ignored for ranges, as upstream.
	reverse bool
	marks   []SliderMark
	// snap_to_marks restricts values to the marks: a press or a drag picks the
	// nearest one, and arrow keys move from mark to mark.
	snap_to_marks bool
	value_label   SliderValueLabel
	// focused draws a ring around the active thumb and shows its value bubble
	// with value_label: .active. Components cannot take keyboard focus: set it
	// while the application routes keys to the slider, typically from the
	// first press until another control is used.
	focused bool
	active  SliderThumb // The thumb keys move; .value means .end for a range.
	enabled bool = true
	color   ?u32 // Track fill and thumb ring; defaults to the theme's primary.
	// thumb_color fills the thumb inside its ring; defaults to the background.
	thumb_color ?u32
	// decimals the value bubble and assistive technology show; -1 derives them
	// from step (continuous sliders show 0 to 2 by the size of the range).
	decimals            int = -1
	value_prefix        string // Shown before the value, such as `$`.
	value_suffix        string // Shown after the value, such as `%` or ` °C`.
	accessibility_label string        = 'Slider'
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// SliderChange is what a pointer event or a key asks a slider to become. Store
// value for a single slider, or start and end for a range, and rebuild.
pub struct SliderChange {
pub:
	thumb SliderThumb // The thumb that moved: .value, or .start / .end of a range.
	value f64         // The moved thumb's new value.
	start f64         // A range's start after the change; for a single slider, value.
	end   f64         // A range's end after the change; for a single slider, value.
	// done is set when the pointer was released, as GPUI Kit's
	// SliderEvent::Release, and for key changes, which are complete at once.
	done bool
}

// SliderMetrics are GPUI Kit's 6-unit track and 16-unit thumb in a 24-unit
// band for medium, scaled down and up for small and large.
struct SliderMetrics {
	track f64
	thumb f64
	band  f64
	font  f64 // Mark labels and the value bubble.
}

fn slider_metrics(size ComponentSize) SliderMetrics {
	return match size {
		.small { SliderMetrics{4, 12, 20, 11} }
		.medium { SliderMetrics{6, 16, 24, 12} }
		.large { SliderMetrics{8, 20, 28, 13} }
	}
}

// slider_thumb_ring is the width of the ring around a focused thumb; the track
// keeps that much room past each thumb's center so the ring is never clipped.
const slider_thumb_ring = 3.0
const slider_arrow = 5.0
const slider_bubble_pad = 6.0

// ── Values ──────────────────────────────────────────────────────────

// slider_scale_fraction is where value sits on a track from min (0) to max
// (1) under scale. Values outside the range clamp to its ends.
pub fn slider_scale_fraction(value f64, min f64, max f64, scale SliderScale) f64 {
	if !(max > min) {
		return 0
	}
	v := slider_clamped_value(value, min, max)
	if scale == .logarithmic && min > 0 {
		return math.max(0.0, math.min(1.0, math.log(v / min) / math.log(max / min)))
	}
	return (v - min) / (max - min)
}

// slider_scale_value is the value at fraction (0 at min, 1 at max) of a track
// under scale: linear, or min * (max / min)^fraction when logarithmic.
pub fn slider_scale_value(fraction f64, min f64, max f64, scale SliderScale) f64 {
	if !(max > min) {
		return min
	}
	p := math.max(0.0, math.min(1.0, fraction))
	if scale == .logarithmic && min > 0 {
		return slider_clamped_value(min * math.pow(max / min, p), min, max)
	}
	return min + (max - min) * p
}

fn styled_slider_validate(config StyledSliderConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	for number in [config.origin_x, config.origin_y, config.min, config.max, config.step, config.value,
		config.start, config.end] {
		if !component_finite(number) {
			return error('slider values must be finite')
		}
	}
	for mark in config.marks {
		if !component_finite(mark.value) {
			return error('slider marks must be finite')
		}
	}
	if config.max < config.min {
		return error('slider max must not be less than min')
	}
	if config.step < 0 {
		return error('slider step must not be negative')
	}
	if config.scale == .logarithmic && config.min <= 0 {
		return error('a logarithmic slider needs min above zero')
	}
}

// styled_slider_values returns the slider's current start and end: a range's
// clamped and ordered values, or min and the value of a single slider.
fn styled_slider_values(config StyledSliderConfig) (f64, f64) {
	if config.range {
		a := slider_clamped_value(config.start, config.min, config.max)
		b := slider_clamped_value(config.end, config.min, config.max)
		return math.min(a, b), math.max(a, b)
	}
	return config.min, slider_clamped_value(config.value, config.min, config.max)
}

// styled_slider_marks are the marks inside the range, in value order.
fn styled_slider_marks(config StyledSliderConfig) []SliderMark {
	mut marks := config.marks.filter(it.value >= config.min && it.value <= config.max)
	marks.sort(a.value < b.value)
	return marks
}

// styled_slider_value_at is the value a press at fraction of the track picks:
// the nearest mark with snap_to_marks, or the value there snapped to step.
fn styled_slider_value_at(config StyledSliderConfig, fraction f64) f64 {
	if config.snap_to_marks {
		marks := styled_slider_marks(config)
		if marks.len > 0 {
			mut best := marks[0].value
			mut distance := 2.0
			for mark in marks {
				d := math.abs(slider_scale_fraction(mark.value, config.min, config.max,
					config.scale) - fraction)
				if d < distance {
					distance = d
					best = mark.value
				}
			}
			return best
		}
	}
	return slider_snap(slider_scale_value(fraction, config.min, config.max, config.scale),
		config.min, config.max, config.step)
}

// styled_slider_decimals is how many decimals the slider shows.
fn styled_slider_decimals(config StyledSliderConfig) int {
	if config.decimals >= 0 {
		return math.min(config.decimals, 6)
	}
	if config.step > 0 {
		return math.max(slider_decimals(config.step), slider_decimals(config.min))
	}
	span := config.max - config.min
	return if span >= 100 {
		0
	} else if span >= 10 {
		1
	} else {
		2
	}
}

// slider_format_number writes value with exactly `decimals` decimals.
fn slider_format_number(value f64, decimals int) string {
	d := math.max(0, math.min(decimals, 6))
	p := math.pow(10, f64(d))
	scaled := i64(math.round(math.abs(value) * p))
	unit := i64(p)
	mut out := (scaled / unit).str()
	if d > 0 {
		fraction := (scaled % unit).str()
		out += '.' + '0'.repeat(d - fraction.len) + fraction
	}
	return if value < 0 && scaled != 0 { '-' + out } else { out }
}

// styled_slider_value_text formats a value as the bubble and assistive
// technology show it: the prefix, the number and the suffix.
pub fn styled_slider_value_text(config StyledSliderConfig, value f64) string {
	return config.value_prefix + slider_format_number(value, styled_slider_decimals(config)) +
		config.value_suffix
}

// styled_slider_moved applies target to thumb, keeping a range's start at or
// below its end.
fn styled_slider_moved(config StyledSliderConfig, thumb SliderThumb, target f64, done bool) SliderChange {
	lo, hi := styled_slider_values(config)
	if !config.range {
		return SliderChange{
			thumb: .value
			value: target
			start: target
			end:   target
			done:  done
		}
	}
	if thumb == .start {
		v := math.min(target, hi)
		return SliderChange{
			thumb: .start
			value: v
			start: v
			end:   hi
			done:  done
		}
	}
	v := math.max(target, lo)
	return SliderChange{
		thumb: .end
		value: v
		start: lo
		end:   v
		done:  done
	}
}

fn styled_slider_current(config StyledSliderConfig, thumb SliderThumb) f64 {
	lo, hi := styled_slider_values(config)
	return if config.range && thumb == .start { lo } else { hi }
}

// styled_slider_key_thumb is the thumb keys move.
fn styled_slider_key_thumb(config StyledSliderConfig) SliderThumb {
	if !config.range {
		return .value
	}
	return if config.active == .start { SliderThumb.start } else { SliderThumb.end }
}

// ── Geometry ────────────────────────────────────────────────────────

// SliderLayout places a slider in its frame. `pad` is the room before the
// first and after the last thumb center along the track, `cross` the track's
// center across it; both are frame-local.
struct SliderLayout {
	m          SliderMetrics
	vertical   bool
	pad        f64
	length     f64 // Distance between the thumb centers at min and at max.
	cross      f64
	band       Rect // The draggable strip along the track.
	labels     bool // Some mark has a label.
	label_line f64
}

fn slider_bubble_size(text string, m SliderMetrics) (f64, f64) {
	return controls_text_width(text, m.font) + 2 * slider_bubble_pad, font_line_height(m.font) + 4
}

// styled_slider_bubble_room is how far the widest bubble reaches out from the
// band, beyond the room the band already leaves around the thumb.
fn styled_slider_bubble_room(config StyledSliderConfig, m SliderMetrics) f64 {
	if config.value_label == .hidden {
		return 0
	}
	low := styled_slider_value_text(config, config.min)
	high := styled_slider_value_text(config, config.max)
	along := if config.orientation == .vertical {
		mut texts := [low, high]
		if config.range {
			texts << '${low} – ${high}'
		}
		mut widest := 0.0
		for text in texts {
			w, _ := slider_bubble_size(text, m)
			widest = math.max(widest, w)
		}
		widest
	} else {
		_, h := slider_bubble_size(low, m)
		h
	}
	return math.max(0.0, along + slider_arrow + 2 - (m.band - m.thumb) / 2)
}

fn styled_slider_label_room(config StyledSliderConfig, m SliderMetrics) f64 {
	marks := styled_slider_marks(config)
	if !marks.any(it.label.len > 0) {
		return 0
	}
	if config.orientation == .vertical {
		mut widest := 0.0
		for mark in marks {
			widest = math.max(widest, controls_text_width(mark.label, m.font))
		}
		return 4 + widest
	}
	return 2 + font_line_height(m.font)
}

// styled_slider_thickness is the natural size of a slider across its track:
// the height of a horizontal slider or the width of a vertical one, with room
// for the value bubble and the mark labels it shows.
pub fn styled_slider_thickness(config StyledSliderConfig) f64 {
	m := slider_metrics(config.size)
	return styled_slider_bubble_room(config, m) + m.band + styled_slider_label_room(config, m)
}

fn styled_slider_layout(config StyledSliderConfig) SliderLayout {
	m := slider_metrics(config.size)
	vertical := config.orientation == .vertical
	extent := if vertical { config.frame.height } else { config.frame.width }
	across := if vertical { config.frame.width } else { config.frame.height }
	pad := math.min(m.thumb / 2 + slider_thumb_ring, extent / 2)
	room := styled_slider_bubble_room(config, m)
	natural := room + m.band + styled_slider_label_room(config, m)
	band_at := math.max(0.0, (across - natural) / 2) + room
	band := if vertical {
		choice_fit(rect(band_at, 0, m.band, extent), config.frame.width, config.frame.height)
	} else {
		choice_fit(rect(0, band_at, extent, m.band), config.frame.width, config.frame.height)
	}
	return SliderLayout{
		m:          m
		vertical:   vertical
		pad:        pad
		length:     math.max(0.0, extent - 2 * pad)
		cross:      band_at + m.band / 2
		band:       band
		labels:     styled_slider_marks(config).any(it.label.len > 0)
		label_line: font_line_height(m.font)
	}
}

// slider_point is the frame-local center of a thumb at fraction of the track.
fn slider_point(l SliderLayout, fraction f64) (f64, f64) {
	along := l.pad + fraction * l.length
	if l.vertical {
		return l.cross, l.pad + l.length - fraction * l.length
	}
	return along, l.cross
}

// styled_slider_fraction_at maps a window point onto the track: 0 at min, 1 at
// max, clamped, so a drag can leave the slider.
fn styled_slider_fraction_at(config StyledSliderConfig, x f64, y f64) f64 {
	l := styled_slider_layout(config)
	if l.length <= 0 {
		return 0
	}
	f := if l.vertical {
		(config.origin_y + config.frame.y + l.pad + l.length - y) / l.length
	} else {
		(x - config.origin_x - config.frame.x - l.pad) / l.length
	}
	return math.max(0.0, math.min(1.0, f))
}

// styled_slider_nearest is the thumb of a range that a press at fraction
// moves: the nearer one, the start when the press is before both thumbs and
// the end when it is after both.
fn styled_slider_nearest(config StyledSliderConfig, fraction f64) SliderThumb {
	if !config.range {
		return .value
	}
	lo, hi := styled_slider_values(config)
	a := slider_scale_fraction(lo, config.min, config.max, config.scale)
	b := slider_scale_fraction(hi, config.min, config.max, config.scale)
	return if fraction < (a + b) / 2 { SliderThumb.start } else { SliderThumb.end }
}

// ── Build ───────────────────────────────────────────────────────────

pub fn styled_slider_thumb_id(id string, thumb SliderThumb) string {
	return component_part_id(id, match thumb {
		.value { 'thumb' }
		.start { 'thumb:start' }
		.end { 'thumb:end' }
	})
}

pub fn styled_slider_track_id(id string) string {
	return component_part_id(id, 'track')
}

struct SliderColors {
	accent      u32
	track       u32
	thumb       u32
	dot_on      u32 // A mark dot on the filled part of the track.
	dot_off     u32
	mark_text   u32
	bubble      u32
	bubble_text u32
}

fn styled_slider_colors(config StyledSliderConfig) SliderColors {
	theme := config.theme
	mut accent := config.color or { theme.primary }
	mut thumb := config.thumb_color or { theme.background }
	if !config.enabled {
		accent = choice_mix(accent, theme.background, 0.55)
		thumb = choice_mix(thumb, theme.background, 0.3)
	}
	return SliderColors{
		accent:      accent
		track:       choice_mix(accent, theme.background, 0.8)
		thumb:       thumb
		dot_on:      choice_mix(accent, thumb, 0.7)
		dot_off:     choice_mix(accent, theme.background, 0.45)
		mark_text:   if config.enabled {
			theme.muted_foreground
		} else {
			choice_disabled_text(theme)
		}
		bubble:      theme.foreground
		bubble_text: theme.background
	}
}

// slider_bar is a rounded bar along the track from fraction a to b, in the
// coordinates of the band.
fn slider_bar(l SliderLayout, a f64, b f64, color u32) Element {
	t := l.m.track
	lo := l.pad + math.min(a, b) * l.length
	hi := l.pad + math.max(a, b) * l.length
	frame := if l.vertical {
		rect((l.band.width - t) / 2, l.pad + l.length - (hi - l.pad), t, hi - lo)
	} else {
		rect(lo, (l.band.height - t) / 2, hi - lo, t)
	}
	return view('', frame, BoxStyle{
		bg:     color
		radius: t / 2
	}, []Element{})
}

fn styled_slider_track(config StyledSliderConfig, l SliderLayout, colors SliderColors, fa f64, fb f64) Element {
	mut parts := [slider_bar(l, 0, 1, colors.track)]
	if fb - fa > 1e-9 {
		parts << slider_bar(l, fa, fb, colors.accent)
	}
	dot := math.max(2.0, math.round(l.m.track * 0.6))
	for mark in styled_slider_marks(config) {
		f := slider_scale_fraction(mark.value, config.min, config.max, config.scale)
		x, y := slider_point(l, f)
		on := f >= fa - 1e-9 && f <= fb + 1e-9 && fb - fa > 1e-9
		parts << view('', rect(x - l.band.x - dot / 2, y - l.band.y - dot / 2, dot, dot),
			BoxStyle{
				bg:     if on { colors.dot_on } else { colors.dot_off }
				radius: dot / 2
			}, []Element{})
	}
	return Element{
		...draggable_view(styled_slider_track_id(config.id), l.band, BoxStyle{
			transparent: true
		}, parts)
		key:     'track'
		enabled: config.enabled
	}
}

fn styled_slider_mark_labels(config StyledSliderConfig, l SliderLayout, colors SliderColors) []Element {
	if !l.labels {
		return []Element{}
	}
	width := config.frame.width
	height := config.frame.height
	mut out := []Element{}
	for mark in styled_slider_marks(config) {
		if mark.label.len == 0 {
			continue
		}
		f := slider_scale_fraction(mark.value, config.min, config.max, config.scale)
		x, y := slider_point(l, f)
		w := controls_text_width(mark.label, l.m.font)
		frame := if l.vertical {
			rect(l.band.x + l.band.width + 4, math.max(0.0, math.min(y - l.label_line / 2, height - l.label_line)),
				w, l.label_line)
		} else {
			rect(math.max(0.0, math.min(x - w / 2, width - w)), l.band.y + l.band.height + 2,
				w, l.label_line)
		}
		// The frame is centered on the mark and exactly as wide as the text, which
		// is left-aligned in it: AppKit truncates centered text in so tight a frame.
		out << label('', mark.label, choice_fit(frame, width, height), TextStyle{
			color: colors.mark_text
			size:  l.m.font
		})
	}
	return out
}

fn styled_slider_thumb(config StyledSliderConfig, l SliderLayout, colors SliderColors, thumb SliderThumb, value f64, fraction f64) []Element {
	d := l.m.thumb
	x, y := slider_point(l, fraction)
	frame := rect(x - d / 2, y - d / 2, d, d)
	mut parts := []Element{}
	if config.focused && config.enabled && thumb == styled_slider_key_thumb(config) {
		r := slider_thumb_ring
		parts << view('', rect(frame.x - r, frame.y - r, d + 2 * r, d + 2 * r), BoxStyle{
			bg:     choice_mix(colors.accent, config.theme.background, 0.6)
			radius: d / 2 + r
		}, []Element{})
	}
	inset := math.max(1.0, math.round(d / 8))
	inner := view('', rect(inset, inset, d - 2 * inset, d - 2 * inset), BoxStyle{
		bg:     colors.thumb
		radius: d / 2 - inset
	}, []Element{})
	name := match thumb {
		.value { '' }
		.start { ' minimum' }
		.end { ' maximum' }
	}
	parts << Element{
		...draggable_view(styled_slider_thumb_id(config.id, thumb), frame, BoxStyle{
			bg:     colors.accent
			radius: d / 2
			shadow: if config.enabled { box_shadow(0x000000, 0.16, 2, 0) } else { BoxShadow{} }
		}, [inner])
		key:                 'thumb:${thumb}'
		enabled:             config.enabled
		accessibility_role:  'slider'
		accessibility_label: config.accessibility_label + name
		accessibility_value: styled_slider_value_text(config, value)
	}
	return parts
}

// slider_value_bubble draws a bubble pointing at the frame-local point (x, y):
// above it on a horizontal slider, to its left on a vertical one. The bubble
// stays inside the frame; its arrow stays on the point.
fn slider_value_bubble(config StyledSliderConfig, l SliderLayout, colors SliderColors, text string, x f64, y f64, key string) []Element {
	w, h := slider_bubble_size(text, l.m)
	gap := l.m.thumb / 2 + 2
	a := slider_arrow
	width := config.frame.width
	height := config.frame.height
	mut bubble_box := Rect{}
	mut arrow := Rect{}
	mut path := []PathCommand{}
	if l.vertical {
		right := x - gap - a
		bubble_box = rect(math.max(0.0, right - w), math.max(0.0, math.min(y - h / 2, height - h)),
			w, h)
		arrow = rect(right, y - a, a, 2 * a)
		path = path_polyline([path_point(0, 0), path_point(a, a), path_point(0, 2 * a)], true)
	} else {
		bottom := y - gap - a
		bubble_box = rect(math.max(0.0, math.min(x - w / 2, width - w)), math.max(0.0, bottom - h),
			w, h)
		arrow = rect(x - a, bottom, 2 * a, a)
		path = path_polyline([path_point(0, 0), path_point(2 * a, 0), path_point(a, a)], true)
	}
	return [
		shape(component_part_id(config.id, 'arrow:${key}'), choice_fit(arrow, width,
			height), path, ShapeStyle{
			fill: colors.bubble
		}),
		Element{
			...view('', choice_fit(bubble_box, width, height), BoxStyle{
				bg:     colors.bubble
				radius: 4
				shadow: component_card_shadow()
			}, [
				label('', text, rect(0, 0, bubble_box.width, bubble_box.height), TextStyle{
					color: colors.bubble_text
					size:  l.m.font
					align: .center
				}),
			])
			key: 'bubble:${key}'
		},
	]
}

fn styled_slider_bubbles(config StyledSliderConfig, l SliderLayout, colors SliderColors, lo f64, hi f64, fa f64, fb f64) []Element {
	if config.value_label == .hidden
		|| (config.value_label == .active && (!config.focused || !config.enabled)) {
		return []Element{}
	}
	if !config.range {
		x, y := slider_point(l, fb)
		return slider_value_bubble(config, l, colors, styled_slider_value_text(config, hi),
			x, y, 'value')
	}
	start_text := styled_slider_value_text(config, lo)
	end_text := styled_slider_value_text(config, hi)
	sx, sy := slider_point(l, fa)
	ex, ey := slider_point(l, fb)
	if config.value_label == .active {
		return if styled_slider_key_thumb(config) == .start {
			slider_value_bubble(config, l, colors, start_text, sx, sy, 'start')
		} else {
			slider_value_bubble(config, l, colors, end_text, ex, ey, 'end')
		}
	}
	sw, sh := slider_bubble_size(start_text, l.m)
	ew, eh := slider_bubble_size(end_text, l.m)
	overlap := if l.vertical {
		math.abs(sy - ey) < (sh + eh) / 2 + 2
	} else {
		math.abs(ex - sx) < (sw + ew) / 2 + 2
	}
	if overlap {
		return slider_value_bubble(config, l, colors, '${start_text} – ${end_text}', (sx + ex) / 2,
			(sy + ey) / 2, 'range')
	}
	mut out := slider_value_bubble(config, l, colors, start_text, sx, sy, 'start')
	out << slider_value_bubble(config, l, colors, end_text, ex, ey, 'end')
	return out
}

// styled_slider is GPUI Kit's Slider. Decode what it emits with
// styled_slider_change and route keys through styled_slider_change_after_key.
pub fn styled_slider(config StyledSliderConfig) !Element {
	styled_slider_validate(config)!
	l := styled_slider_layout(config)
	colors := styled_slider_colors(config)
	lo, hi := styled_slider_values(config)
	fa := if config.range {
		slider_scale_fraction(lo, config.min, config.max, config.scale)
	} else {
		0.0
	}
	fb := slider_scale_fraction(hi, config.min, config.max, config.scale)
	reversed := config.reverse && !config.range
	fill_a := if reversed { fb } else { fa }
	fill_b := if reversed { 1.0 } else { fb }
	mut children := [styled_slider_track(config, l, colors, fill_a, fill_b)]
	children << styled_slider_mark_labels(config, l, colors)
	if config.range {
		// The thumb drawn last is the one a press on both picks. When they meet
		// in the upper half, the start goes on top so it can be dragged back down;
		// otherwise the end, so it can be dragged up.
		start_on_top := fb - fa < 1e-9 && fa > 0.5
		start_parts := styled_slider_thumb(config, l, colors, .start, lo, fa)
		end_parts := styled_slider_thumb(config, l, colors, .end, hi, fb)
		if start_on_top {
			children << end_parts
			children << start_parts
		} else {
			children << start_parts
			children << end_parts
		}
	} else {
		children << styled_slider_thumb(config, l, colors, .value, hi, fb)
	}
	children << styled_slider_bubbles(config, l, colors, lo, hi, fa, fb)
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
		accessibility_value: if config.range {
			'${styled_slider_value_text(config, lo)} – ${styled_slider_value_text(config, hi)}'
		} else {
			styled_slider_value_text(config, hi)
		}
	})
}

// ── Decoding ────────────────────────────────────────────────────────

// styled_slider_change decodes the `pointer:` events of a slider's track and
// thumbs into the values it asks for. A press on the track moves the nearest
// thumb there; a press on a thumb only reports it and a drag moves it. Store
// the change's thumb as `active` and set `focused`: a drag that began on the
// track of a focused range then keeps moving that thumb, as upstream does.
// Presses and releases are reported even when nothing moves; drags that change
// nothing, foreign and malformed events, and everything while disabled or with
// an invalid config are none.
pub fn styled_slider_change(config StyledSliderConfig, event string) ?SliderChange {
	if !config.enabled {
		return none
	}
	styled_slider_validate(config) or { return none }
	pointer := parse_pointer_event(event)?
	part := component_action_part(config.id, pointer.action)?
	if pointer.phase !in ['down', 'drag', 'up'] {
		return none
	}
	fraction := styled_slider_fraction_at(config, pointer.x, pointer.y)
	thumb := match part {
		'track' {
			// A drag that began on the track keeps the thumb its press picked when
			// the application kept that thumb active; otherwise the nearer one
			// follows the pointer, which is the one the press moved.
			if config.range && config.focused && pointer.phase != 'down' {
				styled_slider_key_thumb(config)
			} else {
				styled_slider_nearest(config, fraction)
			}
		}
		'thumb' {
			if config.range {
				return none
			}
			SliderThumb.value
		}
		'thumb:start', 'thumb:end' {
			if !config.range {
				return none
			}
			if part == 'thumb:start' { SliderThumb.start } else { SliderThumb.end }
		}
		else {
			return none
		}
	}
	current := styled_slider_current(config, thumb)
	target := if part != 'track' && pointer.phase == 'down' {
		current
	} else {
		styled_slider_value_at(config, fraction)
	}
	change := styled_slider_moved(config, thumb, target, pointer.phase == 'up')
	if pointer.phase == 'drag' && change.value == current {
		return none
	}
	return change
}

// styled_slider_key_target is where a key moves a thumb from current.
fn styled_slider_key_target(config StyledSliderConfig, current f64, event KeyEvent) ?f64 {
	if config.snap_to_marks {
		marks := styled_slider_marks(config)
		if marks.len > 0 {
			return match event.code {
				.home {
					marks[0].value
				}
				.end {
					marks[marks.len - 1].value
				}
				.right, .up, .page_up {
					next := marks.filter(it.value > current + 1e-9)
					if next.len == 0 {
						return none
					}
					next[0].value
				}
				.left, .down, .page_down {
					previous := marks.filter(it.value < current - 1e-9)
					if previous.len == 0 {
						return none
					}
					previous[previous.len - 1].value
				}
				else {
					return none
				}
			}
		}
	}
	if config.scale == .linear {
		return slider_key_value(current, config.min, config.max, config.step, event)
	}
	direction := match event.code {
		.home { return config.min }
		.end { return config.max }
		.right, .up, .page_up { 1.0 }
		.left, .down, .page_down { -1.0 }
		else { return none }
	}
	// A logarithmic track moves by a share of its length, not of its values,
	// and by at least one step so the smallest key press always moves.
	big := event.shift || event.code in [.page_up, .page_down]
	f := slider_scale_fraction(current, config.min, config.max, config.scale)
	mut next := slider_snap(slider_scale_value(f + direction * if big { 0.1 } else { 0.01 },
		config.min, config.max, config.scale), config.min, config.max, config.step)
	if next == current && config.step > 0 {
		next = slider_snap(current + direction * config.step, config.min, config.max,
			config.step)
	}
	return next
}

// styled_slider_change_after_key moves the active thumb as a focused GPUI Kit
// slider does: Left/Down and Right/Up by a step (ten with Shift), Page Down and
// Page Up by a tenth of the range, Home and End to the ends. With
// snap_to_marks the keys go from mark to mark. Call it from on_key_event while
// the application routes keys to the slider. None for other keys, modified
// keys, disabled sliders and keys that change nothing.
pub fn styled_slider_change_after_key(config StyledSliderConfig, event KeyEvent) ?SliderChange {
	if !config.enabled || event.cmd || event.ctrl || event.alt {
		return none
	}
	styled_slider_validate(config) or { return none }
	if !(config.max > config.min) {
		return none
	}
	thumb := styled_slider_key_thumb(config)
	current := styled_slider_current(config, thumb)
	target := styled_slider_key_target(config, current, event)?
	change := styled_slider_moved(config, thumb, target, true)
	if change.value == current {
		return none
	}
	return change
}

// slider_step_marks returns a mark at min, at every `every` units after it and
// at max, labelled with the slider's value text when labelled is set. Use it
// for tick marks; it returns none when every is not positive or would make
// more than 200 marks.
pub fn slider_step_marks(config StyledSliderConfig, every f64, labelled bool) ?[]SliderMark {
	if !(every > 0) || !(config.max >= config.min) || !component_finite(every) {
		return none
	}
	count := int(math.floor((config.max - config.min) / every + 1e-9))
	if count > 200 {
		return none
	}
	mut marks := []SliderMark{}
	decimals := math.max(slider_decimals(every), slider_decimals(config.min))
	// Labels show the marks' own decimals unless the config fixes them.
	shown := if config.decimals >= 0 {
		styled_slider_decimals(config)
	} else {
		math.max(styled_slider_decimals(config), decimals)
	}
	for i in 0 .. count + 1 {
		v := slider_round(config.min + f64(i) * every, decimals)
		marks << SliderMark{
			value: v
			label: if labelled { slider_mark_text(config, v, shown) } else { '' }
		}
	}
	if marks.len == 0 || marks[marks.len - 1].value < config.max - 1e-9 {
		marks << SliderMark{
			value: config.max
			label: if labelled { slider_mark_text(config, config.max, shown) } else { '' }
		}
	}
	return marks
}

fn slider_mark_text(config StyledSliderConfig, value f64, decimals int) string {
	return config.value_prefix + slider_format_number(value, decimals) + config.value_suffix
}
