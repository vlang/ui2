// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The segment editing rules (the segments each precision and hour cycle shows,
// the displayed value of each, 12 AM as midnight and 12 PM as noon, stepping
// that wraps within a segment without carrying, typing with a two-digit buffer
// that moves on once no further digit could fit, a/p for the period, and
// clearing a segment to its first value) are adapted from SegmentEditor in
// gpui-kit crates/base/src/time_field.rs. Steps, bounds, parsing, rendering,
// the stepper buttons and action decoding are new UI2 implementations. See
// third_party/gpui-kit.
module ui2

import math
import time

const datetime_seconds_per_day = 86400

// TimeOfDay is a wall-clock time without a date or a time zone. The comparison
// operators order times within a day.
pub struct TimeOfDay {
pub:
	hour   int // 0 to 23
	minute int // 0 to 59
	second int // 0 to 59
}

pub fn time_of_day(hour int, minute int, second int) !TimeOfDay {
	t := TimeOfDay{hour, minute, second}
	if !t.is_valid() {
		return error('${hour}:${minute}:${second} is not a valid time of day')
	}
	return t
}

pub fn (t TimeOfDay) is_valid() bool {
	return t.hour >= 0 && t.hour <= 23 && t.minute >= 0 && t.minute <= 59 && t.second >= 0
		&& t.second <= 59
}

// seconds counts from midnight: 0 to 86399.
pub fn (t TimeOfDay) seconds() int {
	return t.hour * 3600 + t.minute * 60 + t.second
}

// time_of_day_from_seconds is the time that many seconds after midnight,
// wrapping around the day in both directions.
pub fn time_of_day_from_seconds(seconds int) TimeOfDay {
	s := datetime_floor_mod(seconds, datetime_seconds_per_day)
	return TimeOfDay{s / 3600, s % 3600 / 60, s % 60}
}

pub fn (a TimeOfDay) < (b TimeOfDay) bool {
	return a.seconds() < b.seconds()
}

// str is `09:30:15`.
pub fn (t TimeOfDay) str() string {
	return '${t.hour:02}:${t.minute:02}:${t.second:02}'
}

// time_of_day_now is the current time on the system clock, in local time.
pub fn time_of_day_now() TimeOfDay {
	now := time.now()
	return TimeOfDay{now.hour, now.minute, now.second}
}

pub enum TimePrecision {
	minute // Hours and minutes: 09:30.
	second // Hours, minutes and seconds: 09:30:15.
}

pub enum HourCycle {
	h23 // A 24-hour clock, 00 to 23.
	h12 // A 12-hour clock, 12 to 11, with an AM/PM segment.
}

pub enum TimeSegment {
	hour
	minute
	second
	period // AM or PM, on a 12-hour clock.
}

// time_segments lists the segments a field shows, in reading order.
pub fn time_segments(precision TimePrecision, hour_cycle HourCycle) []TimeSegment {
	mut segments := [TimeSegment.hour, .minute]
	if precision == .second {
		segments << .second
	}
	if hour_cycle == .h12 {
		segments << .period
	}
	return segments
}

// time_segment_bounds is the range a segment's displayed value takes.
fn time_segment_bounds(segment TimeSegment, hour_cycle HourCycle) (int, int) {
	if segment == .hour {
		return if hour_cycle == .h12 { 1 } else { 0 }, if hour_cycle == .h12 { 12 } else { 23 }
	}
	if segment == .period {
		return 0, 1
	}
	return 0, 59
}

// time_segment_value is what a segment shows: the hour on the field's clock
// (12 for midnight and noon on a 12-hour clock), the minute or second, or 0
// for AM and 1 for PM.
pub fn time_segment_value(t TimeOfDay, segment TimeSegment, hour_cycle HourCycle) int {
	return match segment {
		.hour {
			if hour_cycle == .h12 { (t.hour + 11) % 12 + 1 } else { t.hour }
		}
		.minute { t.minute }
		.second { t.second }
		.period { t.hour / 12 }
	}
}

// time_segment_text is a segment as drawn: two digits, or AM/PM.
pub fn time_segment_text(t TimeOfDay, segment TimeSegment, hour_cycle HourCycle) string {
	if segment == .period {
		return if t.hour >= 12 { 'PM' } else { 'AM' }
	}
	return '${time_segment_value(t, segment, hour_cycle):02}'
}

// time_with_segment replaces one segment's displayed value. On a 12-hour
// clock the hour keeps the period (12 AM is midnight, 12 PM noon) and the
// period keeps the hour. Out-of-range values leave the time unchanged.
pub fn time_with_segment(t TimeOfDay, segment TimeSegment, hour_cycle HourCycle, value int) TimeOfDay {
	lo, hi := time_segment_bounds(segment, hour_cycle)
	if value < lo || value > hi {
		if !(segment == .hour && hour_cycle == .h12 && value == 0) {
			return t
		}
	}
	return match segment {
		.hour {
			if hour_cycle == .h12 {
				TimeOfDay{
					...t
					hour: value % 12 + t.hour / 12 * 12
				}
			} else {
				TimeOfDay{
					...t
					hour: value
				}
			}
		}
		.minute {
			TimeOfDay{
				...t
				minute: value
			}
		}
		.second {
			TimeOfDay{
				...t
				second: value
			}
		}
		.period {
			TimeOfDay{
				...t
				hour: t.hour % 12 + value * 12
			}
		}
	}
}

// time_format writes a time at a precision on a clock: `09:30`, `09:30:15`,
// `09:30 PM` or `09:30:15 PM`.
pub fn time_format(t TimeOfDay, precision TimePrecision, hour_cycle HourCycle) string {
	mut out := '${time_segment_value(t, .hour, hour_cycle):02}:${t.minute:02}'
	if precision == .second {
		out += ':${t.second:02}'
	}
	if hour_cycle == .h12 {
		out += ' ' + time_segment_text(t, .period, hour_cycle)
	}
	return out
}

// time_parse reads `H:MM`, `HH:MM:SS` and those followed by AM or PM (any
// case, with or without a space before it, also `a`/`p`), plus a bare hour
// with a period (`9pm`). A 12-hour time needs an hour from 1 to 12. Anything
// else returns none.
pub fn time_parse(source string) ?TimeOfDay {
	mut body := source.trim_space().to_lower()
	mut period := -1
	for suffix, value in {
		'am': 0
		'pm': 1
		'a':  0
		'p':  1
	} {
		if body.ends_with(suffix) {
			period = value
			body = body[..body.len - suffix.len].trim_space()
			break
		}
	}
	parts := body.split(':')
	if parts.len > 3 || (parts.len == 1 && period < 0) {
		return none
	}
	mut values := []int{}
	for index, part in parts {
		if part.len == 0 || part.len > 2 || (index > 0 && part.len != 2) {
			return none
		}
		values << datetime_parse_digits(part) or { return none }
	}
	mut hour := values[0]
	minute := if values.len > 1 { values[1] } else { 0 }
	second := if values.len > 2 { values[2] } else { 0 }
	if period >= 0 {
		if hour < 1 || hour > 12 {
			return none
		}
		hour = hour % 12 + period * 12
	}
	t := TimeOfDay{hour, minute, second}
	return if t.is_valid() { t } else { none }
}

// TimeFieldState is what the application stores for a time field.
pub struct TimeFieldState {
pub:
	time    TimeOfDay
	segment TimeSegment // The segment keys edit.
	pending int = -1 // A first digit typed into the segment, waiting for a second; -1 for none.
	focused bool // Whether the application treats the field as focused; shows the segment highlight.
}

// blurred is the state once focus moves elsewhere: no highlight and no
// half-typed digit.
pub fn (s TimeFieldState) blurred() TimeFieldState {
	return TimeFieldState{
		...s
		pending: -1
		focused: false
	}
}

pub struct TimeFieldConfig {
pub:
	id                  string
	frame               Rect
	state               TimeFieldState
	precision           TimePrecision
	hour_cycle          HourCycle
	minute_step         int = 1 // Up, Down and the steppers move minutes to multiples of it.
	second_step         int = 1
	min                 ?TimeOfDay // Steps stop at the bounds; typed times outside them show as invalid.
	max                 ?TimeOfDay
	steppers            bool = true // Up and down buttons that step the selected segment.
	enabled             bool = true
	invalid             bool // Draw the danger border; times outside min and max always do.
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub enum TimeFieldEventKind {
	change // The time changed.
	select // Only the selected segment, the focus or a half-typed digit changed.
}

pub struct TimeFieldEvent {
pub:
	kind  TimeFieldEventKind
	state TimeFieldState // Store it and rebuild.
}

fn time_segment_name(segment TimeSegment) string {
	return match segment {
		.hour { 'hour' }
		.minute { 'minute' }
		.second { 'second' }
		.period { 'period' }
	}
}

fn time_segment_label(segment TimeSegment) string {
	return match segment {
		.hour { 'Hour' }
		.minute { 'Minute' }
		.second { 'Second' }
		.period { 'AM/PM' }
	}
}

pub fn time_field_segment_action_id(id string, segment TimeSegment) string {
	return component_part_id(id, 'segment:' + time_segment_name(segment))
}

fn time_field_validate(config TimeFieldConfig) ! {
	if config.minute_step < 1 || config.minute_step > 59 || config.second_step < 1
		|| config.second_step > 59 {
		return error('time field steps must be 1 to 59')
	}
	if !config.state.time.is_valid() {
		return error('time field time ${config.state.time} is not valid')
	}
	if lo := config.min {
		if !lo.is_valid() {
			return error('time field min is not a valid time')
		}
		if hi := config.max {
			if hi < lo {
				return error('time field min must not be after max')
			}
		}
	}
	if hi := config.max {
		if !hi.is_valid() {
			return error('time field max is not a valid time')
		}
	}
}

// time_field_segment is the segment edits apply to: the state's when the
// field shows it, else the hour.
fn time_field_segment(config TimeFieldConfig) TimeSegment {
	segments := time_segments(config.precision, config.hour_cycle)
	return if config.state.segment in segments { config.state.segment } else { .hour }
}

// time_in_range reports whether t lies within the field's min and max.
pub fn time_in_range(config TimeFieldConfig, t TimeOfDay) bool {
	if lo := config.min {
		if t < lo {
			return false
		}
	}
	if hi := config.max {
		if hi < t {
			return false
		}
	}
	return true
}

fn time_clamp(config TimeFieldConfig, t TimeOfDay) TimeOfDay {
	if lo := config.min {
		if t < lo {
			return lo
		}
	}
	if hi := config.max {
		if hi < t {
			return hi
		}
	}
	return t
}

// time_step_value moves value to the next multiple of step above it (or the
// previous one below it) counted from lo, wrapping around within lo..hi.
fn time_step_value(value int, lo int, hi int, step int, direction int) int {
	offset := value - lo
	if direction > 0 {
		next := lo + (offset / step + 1) * step
		return if next > hi { lo } else { next }
	}
	below := if offset % step == 0 { offset / step - 1 } else { offset / step }
	return if below < 0 { lo + (hi - lo) / step * step } else { lo + below * step }
}

// time_field_step is the time after one step of segment up (direction 1) or
// down (-1). Minutes and seconds move to multiples of their step, and every
// segment wraps around without changing the next one (59 minutes steps to 00
// in the same hour), as upstream. A result outside min and max is pulled onto
// the bound; none means the step cannot move the time.
pub fn time_field_step(config TimeFieldConfig, segment TimeSegment, direction int) ?TimeOfDay {
	if !config.enabled || direction == 0 || segment !in time_segments(config.precision,
		config.hour_cycle) {
		return none
	}
	t := config.state.time
	lo, hi := time_segment_bounds(segment, config.hour_cycle)
	step := match segment {
		.minute { int(math.max(1, config.minute_step)) }
		.second { int(math.max(1, config.second_step)) }
		else { 1 }
	}
	value := time_step_value(time_segment_value(t, segment, config.hour_cycle), lo, hi, step,
		direction)
	next := time_clamp(config, time_with_segment(t, segment, config.hour_cycle, value))
	if next == t {
		return none
	}
	return next
}

fn time_field_result(config TimeFieldConfig, next TimeFieldState) ?TimeFieldEvent {
	st := config.state
	if next.time != st.time {
		return TimeFieldEvent{
			kind:  .change
			state: next
		}
	}
	if next.segment != st.segment || next.pending != st.pending || next.focused != st.focused {
		return TimeFieldEvent{
			kind:  .select
			state: next
		}
	}
	return none
}

// time_field_move is the state after moving the selected segment by offset,
// or none at either end.
fn time_field_move(config TimeFieldConfig, offset int) ?TimeFieldState {
	segments := time_segments(config.precision, config.hour_cycle)
	index := segments.index(time_field_segment(config)) + offset
	if index < 0 || index >= segments.len {
		return none
	}
	return TimeFieldState{
		...config.state
		segment: segments[index]
		pending: -1
		focused: true
	}
}

// time_field_type_digit types one digit into the selected segment. A first
// digit that could start a two-digit value waits for a second; a pair that is
// out of range starts over from the second digit; once no further digit could
// fit, the selection moves to the next segment.
fn time_field_type_digit(config TimeFieldConfig, digit int) ?TimeFieldState {
	segment := time_field_segment(config)
	if segment == .period {
		return none
	}
	st := config.state
	lo, hi := time_segment_bounds(segment, config.hour_cycle)
	mut value := digit
	mut complete := digit * 10 > hi
	if st.pending >= 0 {
		pair := st.pending * 10 + digit
		if pair >= lo && pair <= hi {
			value = pair
			complete = true
		}
	}
	next_time := time_with_segment(st.time, segment, config.hour_cycle, value)
	mut next := TimeFieldState{
		...st
		time:    next_time
		segment: segment
		pending: if complete { -1 } else { digit }
		focused: true
	}
	if complete {
		if moved := time_field_move(TimeFieldConfig{
			...config
			state: next
		}, 1)
		{
			next = moved
		}
	}
	return next
}

fn time_field_key_digit(code KeyCode) ?int {
	value := int(code)
	if value >= int(KeyCode._0) && value <= int(KeyCode._9) {
		return value - int(KeyCode._0)
	}
	if value >= int(KeyCode.kp_0) && value <= int(KeyCode.kp_9) {
		return value - int(KeyCode.kp_0)
	}
	return none
}

// time_field_key_event decodes a key for a time field the application treats
// as focused; call it from on_key_event and consume the key when it returns
// an event. Up and Down step the selected segment, Left and Right move between
// segments, Tab and Shift-Tab too (returning none at either end, so the
// application can move focus on), digits type into the segment, A and P set
// the period, and Backspace or Delete reset the segment to its first value.
// Digits are read from the physical key, with or without Shift, so they work
// on layouts such as AZERTY that need Shift for digits.
pub fn time_field_key_event(config TimeFieldConfig, event KeyEvent) ?TimeFieldEvent {
	if !config.enabled || !datetime_plain_key(event) {
		return none
	}
	segment := time_field_segment(config)
	st := TimeFieldState{
		...config.state
		segment: segment
	}
	focused := TimeFieldConfig{
		...config
		state: st
	}
	if digit := time_field_key_digit(event.code) {
		return time_field_result(config, time_field_type_digit(focused, digit) or { return none })
	}
	next := match event.code {
		.up, .down {
			stepped := time_field_step(focused, segment, if event.code == .up { 1 } else { -1 }) or {
				return none
			}
			TimeFieldState{
				...st
				time:    stepped
				pending: -1
				focused: true
			}
		}
		.left, .right {
			if event.shift {
				return none
			}
			time_field_move(focused, if event.code == .right { 1 } else { -1 }) or { return none }
		}
		.tab {
			time_field_move(focused, if event.shift { -1 } else { 1 }) or { return none }
		}
		.a, .p {
			if segment != .period {
				return none
			}
			TimeFieldState{
				...st
				time:    time_with_segment(st.time, .period, config.hour_cycle, if event.code == .p {
					1
				} else {
					0
				})
				pending: -1
				focused: true
			}
		}
		.backspace, .delete {
			TimeFieldState{
				...st
				time:    time_with_segment(st.time, segment, config.hour_cycle, 0)
				pending: -1
				focused: true
			}
		}
		else {
			return none
		}
	}
	return time_field_result(config, next)
}

// time_field_event decodes a click on a segment (select it and focus the
// field) or on a stepper (step the selected segment). It returns none for
// foreign and forged actions, everything while disabled, and steps that cannot
// move the time.
pub fn time_field_event(config TimeFieldConfig, action string) ?TimeFieldEvent {
	if !config.enabled {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	st := config.state
	if part == 'increment' || part == 'decrement' {
		segment := time_field_segment(config)
		stepped := time_field_step(config, segment, if part == 'increment' { 1 } else { -1 }) or {
			return none
		}
		return time_field_result(config, TimeFieldState{
			...st
			time:    stepped
			segment: segment
			pending: -1
			focused: true
		})
	}
	if !part.starts_with('segment:') {
		return none
	}
	for segment in time_segments(config.precision, config.hour_cycle) {
		if part == 'segment:' + time_segment_name(segment) {
			return time_field_result(config, TimeFieldState{
				...st
				segment: segment
				pending: -1
				focused: true
			})
		}
	}
	return none
}

// ── Layout and rendering ────────────────────────────────────────────

struct TimeFieldMetrics {
	pad     f64 // Inside the border, before the first segment.
	digits  f64 // Width of a two-digit segment.
	colon   f64
	period  f64 // Width of the AM/PM segment.
	spacing f64 // Before the AM/PM segment.
	stepper f64 // Width of the stepper column.
	inset   f64 // Of a segment's highlight from the top and bottom.
	font    f64
	radius  f64
	icon    f64
}

fn time_field_metrics(size ComponentSize, height f64) TimeFieldMetrics {
	metrics := component_metrics(size)
	font := metrics.font_size
	return TimeFieldMetrics{
		pad:     math.max(2.0, metrics.padding - 3)
		// AppKit insets a label's text by a few points on each side and cuts it
		// short when the rest is narrower than the glyphs, so the segments keep
		// some slack over the estimate.
		digits:  component_text_width_estimate('00', font) + 10
		colon:   math.round(font * 0.35)
		period:  component_text_width_estimate('PM', font) * 1.15 + 10
		spacing: math.round(font * 0.3)
		stepper: math.min(math.round(height * 0.75), 24)
		inset:   math.min(4.0, height / 6)
		font:    font
		radius:  math.max(2.0, metrics.radius - 2)
		icon:    math.round(font * 0.8)
	}
}

// time_field_width is the natural width of a field: its segments, the
// padding, and the steppers when it has them. Use it to size the frame.
pub fn time_field_width(config TimeFieldConfig) f64 {
	height := if config.frame.height > 0 {
		config.frame.height
	} else {
		component_metrics(config.size).height
	}
	tm := time_field_metrics(config.size, height)
	mut width := 2 * tm.pad
	for index, segment in time_segments(config.precision, config.hour_cycle) {
		if segment == .period {
			width += tm.spacing + tm.period
		} else {
			width += tm.digits + if index > 0 { tm.colon } else { 0.0 }
		}
	}
	if config.steppers {
		width += tm.stepper
	}
	return math.ceil(width)
}

fn time_field_segment_element(config TimeFieldConfig, segment TimeSegment, frame Rect, tm TimeFieldMetrics) Element {
	theme := config.theme
	st := config.state
	selected := st.focused && config.enabled && segment == time_field_segment(config)
	caption := time_segment_text(st.time, segment, config.hour_cycle)
	mut children := []Element{}
	if selected {
		children << view('', component_local(frame), BoxStyle{
			bg:     choice_mix(theme.primary, theme.background, 0.72)
			radius: tm.radius
		}, []Element{})
	}
	children << label('', caption, component_local(frame), TextStyle{
		color: if config.enabled { theme.foreground } else { choice_disabled_text(theme) }
		size:  tm.font
		align: .center
	})
	part := 'segment:' + time_segment_name(segment)
	return Element{
		...button_view(time_field_segment_action_id(config.id, segment), frame, BoxStyle{
			transparent: true
		}, children)
		key:                 part
		enabled:             config.enabled
		accessibility_role:  'spinbutton'
		accessibility_label: time_segment_label(segment)
		accessibility_value: caption
	}
}

fn time_field_stepper(config TimeFieldConfig, direction int, frame Rect, tm TimeFieldMetrics) Element {
	theme := config.theme
	part := if direction > 0 { 'increment' } else { 'decrement' }
	segment := time_field_segment(config)
	live := if _ := time_field_step(config, segment, direction) { true } else { false }
	color := if live { theme.foreground } else { choice_disabled_text(theme) }
	local := component_local(frame)
	return Element{
		...button_view(component_part_id(config.id, part), frame, BoxStyle{ transparent: true }, [
			choice_icon(if direction > 0 { 'chevron.up' } else { 'chevron.down' }, datetime_center(local,
				tm.icon, tm.icon), color),
		])
		key:                 part
		enabled:             live
		accessibility_label: '${if direction > 0 { 'Increase' } else { 'Decrease' }} ${time_segment_label(segment).to_lower()}'
	}
}

// time_field is a segmented time-of-day field: hours, minutes, optional
// seconds and an optional AM/PM segment, with optional stepper buttons. It is
// controlled: a click selects a segment and gives the field focus, and the
// application sends keys to time_field_key_event while it treats the field as
// focused. Store the state each event returns and rebuild.
pub fn time_field(config TimeFieldConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	time_field_validate(config)!
	metrics := component_metrics(config.size)
	theme := config.theme
	st := config.state
	w := config.frame.width
	h := config.frame.height
	tm := time_field_metrics(config.size, h)
	stepper_w := if config.steppers { math.min(tm.stepper, w / 3) } else { 0.0 }
	// The colons go first, under the segments: their labels are wider than the
	// gap between two segments, since AppKit insets a label's text and would
	// clip a colon in a frame as narrow as the gap.
	mut colons := []Element{}
	mut segments := []Element{}
	mut x := tm.pad
	seg_h := math.max(0.0, h - 2 * tm.inset)
	ink := if config.enabled { theme.foreground } else { choice_disabled_text(theme) }
	for index, segment in time_segments(config.precision, config.hour_cycle) {
		if segment == .period {
			x += tm.spacing
		} else if index > 0 {
			colons << Element{
				...label('', ':', choice_fit(rect(x - tm.colon, 0, 3 * tm.colon, h), w, h),
					TextStyle{
						color: ink
						size:  tm.font
						align: .center
					})
				key: 'colon:${index}'
			}
			x += tm.colon
		}
		width := if segment == .period { tm.period } else { tm.digits }
		frame := choice_fit(rect(x, tm.inset, width, seg_h), math.max(0.0, w - stepper_w), h)
		segments << time_field_segment_element(config, segment, frame, tm)
		x += width
	}
	mut children := colons
	children << segments
	if stepper_w > 0 {
		sx := w - stepper_w
		half := h / 2
		children << Element{
			...view('', rect(sx, 0, 1, h), BoxStyle{
				bg: theme.border
			}, []Element{})
			key: 'divider'
		}
		children << time_field_stepper(config, 1, rect(sx + 1, 0, stepper_w - 1, half), tm)
		children << time_field_stepper(config, -1, rect(sx + 1, half, stepper_w - 1, h - half),
			tm)
	}
	out_of_range := !time_in_range(config, st.time)
	border := if config.invalid || out_of_range {
		theme.danger
	} else if st.focused && config.enabled {
		theme.primary
	} else {
		theme.border
	}
	formatted := time_format(st.time, config.precision, config.hour_cycle)
	return component_finish(Element{
		...view(config.id, config.frame, component_box(if config.enabled {
			theme.background
		} else {
			theme.muted
		}, border, metrics.radius), children)
		accessibility_role:  'group'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			'Time'
		}
		accessibility_value: formatted
	})
}
