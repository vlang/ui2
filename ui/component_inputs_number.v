// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The stepping rules in number_input_step (step from zero when the text does
// not parse, clamp to the bounds, keep the decimals of the text, step and
// bound, and do nothing unless the value moves the way it was asked to) are
// adapted from step_value in gpui-kit crates/base/src/number_input.rs.
// Parsing, sanitizing, formatting, rendering and action decoding are new UI2
// implementations. See third_party/gpui-kit.
module ui2

import math
import strconv

pub const number_input_max_precision = 12

// NumberInputControls places the step buttons.
pub enum NumberInputControls {
	sides    // − field +
	trailing // field, then increment above decrement on the right
}

pub enum NumberInputStep {
	decrement
	increment
}

pub enum NumberInputEventKind {
	change    // The text changed: read text(number_input_field_id(id)) and sanitize it.
	submit    // Return was pressed: commit the text (parse, clamp and format it).
	decrement // The decrement button was pressed.
	increment // The increment button was pressed.
}

pub struct NumberInputConfig {
pub:
	id          string
	frame       Rect
	text        string // Controlled: the application stores edits and rebuilds.
	placeholder string
	min         ?f64
	max         ?f64
	step        f64  = 1
	precision   int  = -1 // Decimal places; -1 keeps those of the text, step and bounds.
	enabled     bool = true
	readonly    bool // Selectable but neither editable nor steppable.
	invalid     bool // Draw the danger border, e.g. while the text is out of range.
	controls    NumberInputControls
	// AppKit fields keep their text on the left whatever the alignment, so
	// .center and .right only take effect on the other renderers for now.
	align               Align
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// number_input_field_id is the id of the native field, for text(), set_text()
// and focus(). It is also the action the field emits on each edit.
pub fn number_input_field_id(id string) string {
	return component_part_id(id, 'field')
}

fn number_input_validate(config NumberInputConfig) ! {
	if !component_finite(config.step) || config.step <= 0 {
		return error('number input step must be finite and positive')
	}
	if config.precision < -1 || config.precision > number_input_max_precision {
		return error('number input precision must be -1 or 0..${number_input_max_precision}')
	}
	if low := config.min {
		if !component_finite(low) {
			return error('number input min must be finite')
		}
		if high := config.max {
			if low > high {
				return error('number input min must not exceed max')
			}
		}
	}
	if high := config.max {
		if !component_finite(high) {
			return error('number input max must be finite')
		}
	}
}

// number_input_ascii folds the full-width digits, signs and decimal points an
// IME commits (and the typographic minus) into their ASCII forms.
fn number_input_ascii(r rune) rune {
	if r >= 0xff10 && r <= 0xff19 {
		return `0` + (r - 0xff10)
	}
	return match r {
		0xff0b { `+` }
		0xff0d, 0x2212 { `-` }
		0xff0e, 0x3002, 0xff61 { `.` }
		else { r }
	}
}

// number_input_sanitize is what to keep of the text the user typed: an
// optional leading sign (a minus only when the range has negative values),
// digits, and one decimal point unless precision is 0. Full-width characters
// become ASCII; everything else is dropped. Store the result, and when it
// differs from the field's text call set_text on the field, since a rebuild
// with an unchanged declaration keeps what the field shows.
pub fn number_input_sanitize(config NumberInputConfig, typed string) string {
	allow_minus := if low := config.min { low < 0 } else { true }
	allow_point := config.precision != 0
	mut kept := []rune{cap: typed.len}
	mut has_point := false
	for raw in typed.runes() {
		r := number_input_ascii(raw)
		if r >= `0` && r <= `9` {
			kept << r
		} else if r == `.` && allow_point && !has_point {
			has_point = true
			kept << r
		} else if kept.len == 0 && (r == `+` || (r == `-` && allow_minus)) {
			kept << r
		}
	}
	return kept.string()
}

// number_input_parse reads an optional sign, digits and at most one decimal
// point, with at least one digit: `-1.5`, `.5` and `2.` parse, while ``, `-`,
// `.`, `1e3` and `1,000` do not.
pub fn number_input_parse(source string) ?f64 {
	trimmed := source.trim_space()
	if trimmed.len == 0 {
		return none
	}
	negative := trimmed[0] == `-`
	start := if negative || trimmed[0] == `+` { 1 } else { 0 }
	mut digit_count := 0
	mut has_point := false
	for ch in trimmed[start..].bytes() {
		if ch >= `0` && ch <= `9` {
			digit_count++
		} else if ch == `.` && !has_point {
			has_point = true
		} else {
			return none
		}
	}
	if digit_count == 0 {
		return none
	}
	mut body := trimmed[start..]
	if body.starts_with('.') {
		body = '0' + body
	}
	if body.ends_with('.') {
		body += '0'
	}
	magnitude := strconv.atof64(body) or { return none }
	if !component_finite(magnitude) {
		return none
	}
	return if negative { -magnitude } else { magnitude }
}

// number_input_fraction_digits counts the digits after the decimal point.
fn number_input_fraction_digits(source string) int {
	point := source.index('.') or { return 0 }
	return math.min(source.len - point - 1, number_input_max_precision)
}

// number_input_decimal_places is how many decimals a configured number such
// as a step of 0.25 needs: the fewest that represent it to within rounding.
fn number_input_decimal_places(value f64) int {
	mut scaled := math.abs(value)
	for places in 0 .. number_input_max_precision {
		if math.abs(scaled - math.round(scaled)) <= 1e-9 * math.max(scaled, 1) {
			return places
		}
		scaled *= 10
	}
	return number_input_max_precision
}

// number_input_plain writes a configured number with the decimals it needs.
fn number_input_plain(value f64) string {
	return number_input_format(value, number_input_decimal_places(value))
}

fn number_input_pow10(places int) f64 {
	return math.pow(10, f64(places))
}

// number_input_format writes value with exactly precision decimals (clamped to
// 0..12), rounding half away from zero. Values are turned into an integer count
// of the last decimal before they are printed, so a step of 0.1 from 0.2 gives
// `0.3`, not `0.30000000000000004`.
pub fn number_input_format(value f64, precision int) string {
	if !component_finite(value) {
		return ''
	}
	places := math.min(math.max(precision, 0), number_input_max_precision)
	return number_input_format_scaled(math.round(value * number_input_pow10(places)),
		places, value)
}

fn number_input_format_scaled(scaled f64, places int, value f64) string {
	if math.abs(scaled) >= 9.0e15 {
		// Past the range where every integer is exact the decimals carry no
		// information; print the value itself.
		return strconv.f64_to_str_lnd1(value, places)
	}
	count := i64(scaled)
	negative := count < 0
	mut digits := (if negative { -count } else { count }).str()
	if places > 0 {
		if digits.len <= places {
			digits = '0'.repeat(places - digits.len + 1) + digits
		}
		digits = digits[..digits.len - places] + '.' + digits[digits.len - places..]
	}
	return if negative { '-' + digits } else { digits }
}

// number_input_places is the number of decimals a result is written with:
// the configured precision, or else as many as the text and the step use.
fn number_input_places(config NumberInputConfig, source string) int {
	if config.precision >= 0 {
		return config.precision
	}
	return math.max(number_input_fraction_digits(source.trim_space()), number_input_decimal_places(config.step))
}

// number_input_fit clamps value into the configured range and writes it with
// places decimals. The clamping is done in counts of the last decimal, so a
// rounded value never lands outside the range: with a max of 0.25 and one
// decimal the result is 0.2, not 0.3. A value pulled onto a bound keeps the
// bound's own decimals when the precision is not fixed.
fn number_input_fit(config NumberInputConfig, value f64, places int) string {
	mut digits := places
	mut target := value
	if low := config.min {
		if target < low {
			target = low
			if config.precision < 0 {
				digits = math.max(digits, number_input_decimal_places(low))
			}
		}
	}
	if high := config.max {
		if target > high {
			target = high
			if config.precision < 0 {
				digits = math.max(digits, number_input_decimal_places(high))
			}
		}
	}
	scale := number_input_pow10(digits)
	mut scaled := math.round(target * scale)
	if high := config.max {
		limit := math.floor(high * scale + 1e-7 * math.max(math.abs(high * scale), 1))
		if scaled > limit {
			scaled = limit
		}
	}
	if low := config.min {
		limit := math.ceil(low * scale - 1e-7 * math.max(math.abs(low * scale), 1))
		if scaled < limit {
			scaled = limit
		}
	}
	return number_input_format_scaled(scaled, digits, target)
}

// number_input_step returns the text one step up or down from config.text, or
// none when the step cannot move the value that way: at or past the bound in
// that direction, or while disabled or read-only. Empty or unparsable text
// steps from zero into the range, so the first increment of an empty field with
// a min of 10 gives 10. Decimals follow number_input_places.
pub fn number_input_step(config NumberInputConfig, direction NumberInputStep) ?string {
	if !config.enabled || config.readonly {
		return none
	}
	number_input_validate(config) or { return none }
	current := number_input_parse(config.text)
	delta := if direction == .increment { config.step } else { -config.step }
	next := number_input_fit(config, (current or { 0.0 }) + delta, number_input_places(config,
		config.text))
	if was := current {
		now := number_input_parse(next) or { return none }
		moved := if direction == .increment { now > was } else { now < was }
		if !moved {
			return none
		}
	}
	return next
}

// number_input_commit is the text to keep once the user is done typing, for
// Return or before the value is used: the value parsed, clamped into range and
// written with the configured precision, or else with the decimals typed (or
// those of the bound it was clamped to). Empty text stays empty; text that does
// not parse gives none, leaving the application to keep or revert it.
pub fn number_input_commit(config NumberInputConfig, source string) ?string {
	trimmed := source.trim_space()
	if trimmed.len == 0 {
		return ''
	}
	number_input_validate(config) or { return none }
	value := number_input_parse(trimmed) or { return none }
	places := if config.precision >= 0 {
		config.precision
	} else {
		number_input_fraction_digits(trimmed)
	}
	return number_input_fit(config, value, places)
}

// number_input_in_range reports whether text parses and lies within the
// configured bounds, for showing a typed value as invalid before it is
// committed.
pub fn number_input_in_range(config NumberInputConfig, source string) bool {
	value := number_input_parse(source) or { return false }
	if low := config.min {
		if value < low {
			return false
		}
	}
	if high := config.max {
		if value > high {
			return false
		}
	}
	return true
}

// number_input_event decodes an action the number input emitted. It rejects
// foreign and forged actions, everything while disabled, edits and steps while
// read-only, and a step that could not move the value.
pub fn number_input_event(config NumberInputConfig, action string) ?NumberInputEventKind {
	part := component_action_part(config.id, action) or { return none }
	if !config.enabled {
		return none
	}
	match part {
		'field' {
			if config.readonly {
				return none
			}
			return .change
		}
		'submit' {
			return .submit
		}
		'decrement', 'increment' {
			direction := if part == 'increment' {
				NumberInputStep.increment
			} else {
				NumberInputStep.decrement
			}
			number_input_step(config, direction) or { return none }
			return if direction == .increment {
				NumberInputEventKind.increment
			} else {
				NumberInputEventKind.decrement
			}
		}
		else {
			return none
		}
	}
}

// number_input_value_from_action turns a step-button action into the new text,
// or none for any other action and for steps number_input_event rejects.
pub fn number_input_value_from_action(config NumberInputConfig, action string) ?string {
	kind := number_input_event(config, action) or { return none }
	if kind == .increment {
		return number_input_step(config, .increment)
	}
	if kind == .decrement {
		return number_input_step(config, .decrement)
	}
	return none
}

// number_input_key_step maps the up and down arrows, without modifiers, to a
// step. Components cannot capture keys, so call it from on_key_event while the
// field has focus (focused_id() == number_input_field_id(id)).
pub fn number_input_key_step(event KeyEvent) ?NumberInputStep {
	if event.shift || event.ctrl || event.alt || event.cmd {
		return none
	}
	if event.code == .up {
		return NumberInputStep.increment
	}
	if event.code == .down {
		return NumberInputStep.decrement
	}
	return none
}

// number_input_value_from_key is the text after the step an arrow key asks
// for, or none when the key is not a step key or the step cannot move.
pub fn number_input_value_from_key(config NumberInputConfig, event KeyEvent) ?string {
	direction := number_input_key_step(event) or { return none }
	return number_input_step(config, direction)
}

struct NumberInputLayout {
	field     Rect
	decrement Rect
	increment Rect
}

fn number_input_layout(controls NumberInputControls, width f64, height f64) NumberInputLayout {
	if controls == .trailing {
		side := math.min(height * 0.75, width / 3)
		half := height / 2
		return NumberInputLayout{
			field:     rect(0, 0, width - side, height)
			increment: rect(width - side, 0, side, half)
			decrement: rect(width - side, half, side, height - half)
		}
	}
	side := math.min(height, width / 4)
	return NumberInputLayout{
		field:     rect(side, 0, width - 2 * side, height)
		decrement: rect(0, 0, side, height)
		increment: rect(width - side, 0, side, height)
	}
}

fn number_input_button(config NumberInputConfig, direction NumberInputStep, frame Rect) Element {
	part := if direction == .increment { 'increment' } else { 'decrement' }
	metrics := component_metrics(config.size)
	available := if _ := number_input_step(config, direction) { true } else { false }
	glyph := match config.controls {
		.sides {
			if direction == .increment { '+' } else { '−' }
		}
		.trailing {
			if direction == .increment { '▲' } else { '▼' }
		}
	}
	return Element{
		...button(component_part_id(config.id, part), glyph, frame, BoxStyle{ transparent: true }, TextStyle{
			color: if available { config.theme.foreground } else { config.theme.muted_foreground }
			size:  if config.controls == .sides {
				metrics.font_size + 2
			} else {
				math.max(math.round(frame.height * 0.7), 6)
			}
			align: .center
		})
		key:                 part
		enabled:             available
		accessibility_label: if direction == .increment { 'Increment' } else { 'Decrement' }
	}
}

// number_input is a native field between decrement and increment buttons (or
// with both buttons stacked on its right), inside one frame. The application
// owns the text: sanitize edits, commit on Return and store stepped values,
// then rebuild. Buttons that cannot move the value are disabled.
pub fn number_input(config NumberInputConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	number_input_validate(config)!
	metrics := component_metrics(config.size)
	theme := config.theme
	layout := number_input_layout(config.controls, config.frame.width, config.frame.height)
	description := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		config.placeholder
	}
	mut children := [
		inputs_field(
			id:          number_input_field_id(config.id)
			submit_id:   component_part_id(config.id, 'submit')
			placeholder: config.placeholder
			text:        config.text
			frame:       layout.field
			font_size:   metrics.font_size
			align:       config.align
			// The custom renderer keeps 8 points clear on the right of a field's
			// text, so the same on the left centers it.
			padding:     if config.align == .center { 8.0 } else { 12.0 }
			enabled:     config.enabled
			readonly:    config.readonly
			invalid:     config.invalid
			autocorrect: false
			keyboard:    keyboard_decimal
			role:        'spinbutton'
			label:       description
			key:         'field'
			theme:       theme
		),
		number_input_button(config, .decrement, layout.decrement),
		number_input_button(config, .increment, layout.increment),
	]
	if config.controls == .trailing {
		children << Element{
			...view('', rect(layout.increment.x, layout.decrement.y - 0.5, layout.increment.width,
				1), BoxStyle{ bg: if config.invalid { theme.danger } else { theme.border } }, []Element{})
			key: 'divider'
		}
	}
	mut range_text := ''
	if low := config.min {
		range_text = 'from ' + number_input_plain(low)
	}
	if high := config.max {
		range_text = (range_text + ' to ' + number_input_plain(high)).trim_space()
	}
	return component_finish(Element{
		...view(config.id, config.frame, inputs_frame_box(theme, config.invalid, metrics.radius),
			children)
		accessibility_role:  'group'
		accessibility_label: description
		accessibility_value: range_text
	})
}
