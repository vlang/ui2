module ui2

import math

pub enum Orientation {
	horizontal
	vertical
}

pub struct SliderStyle {
pub:
	track_color       u32 = 0xcbd5e1
	value_track_color u32 = 0x93c5fd
	thumb_color       u32 = 0x2563eb
	track_width       f64 = 4.0
	// The thumb is a square of this size drawn centred on the value, so it
	// overhangs the track by half its size at either end. Zero keeps the
	// default; a negative size draws no thumb at all, for a slider that shows a
	// bare track.
	thumb_size f64 = 20.0
}

pub struct SliderConfig {
pub:
	id          string
	action_id   string
	frame       Rect
	min         f64
	max         f64 = 100.0
	value       f64
	step        f64
	orientation Orientation
	padding     f64 = 16.0
	value_track bool
	style       SliderStyle
	// enabled false dims the control and ignores input on every backend.
	enabled             bool   = true
	accessibility_label string = 'Slider'
}

struct SliderSpec {
	min         f64
	max         f64
	step        f64
	orientation Orientation
}

fn slider_spec(el Element) SliderSpec {
	return SliderSpec{
		min:         el.min_value
		max:         el.max_value
		step:        el.step
		orientation: el.orientation
	}
}

pub fn slider_clamped_value(value f64, min f64, max f64) f64 {
	if max <= min {
		return min
	}
	if value <= min {
		return min
	}
	if value >= max {
		return max
	}
	return value
}

pub fn slider_value_normalized(value f64, min f64, max f64) f64 {
	if max <= min {
		return 0
	}
	return (slider_clamped_value(value, min, max) - min) / (max - min)
}

// slider_value_from_normalized maps a 0...1 position to the declared range.
// A positive step snaps relative to min and caps the final partial step at max.
pub fn slider_value_from_normalized(normalized f64, min f64, max f64, step f64) f64 {
	if max <= min {
		return min
	}
	position := if normalized < 0 {
		0.0
	} else if normalized > 1 {
		1.0
	} else {
		normalized
	}
	raw := min + position * (max - min)
	if step <= 0 {
		return slider_clamped_value(raw, min, max)
	}
	snapped := min + math.round((raw - min) / step) * step
	return slider_clamped_value(snapped, min, max)
}

fn slider_track_padding(padding f64, extent f64) f64 {
	if padding <= 0 || extent <= 0 {
		return 0
	}
	maximum := extent / 2
	return if padding < maximum { padding } else { maximum }
}

// slider_normalized_from_point maps root-view pointer coordinates onto a
// slider. Vertical sliders place min at the bottom and max at the top.
fn slider_normalized_from_point(frame Rect, orientation Orientation, padding f64, x f64, y f64) f64 {
	if orientation == .vertical {
		inset := slider_track_padding(padding, frame.height)
		extent := frame.height - inset * 2
		if extent <= 0 {
			return 0
		}
		return (frame.y + frame.height - inset - y) / extent
	}
	inset := slider_track_padding(padding, frame.width)
	extent := frame.width - inset * 2
	if extent <= 0 {
		return 0
	}
	return (x - frame.x - inset) / extent
}

fn slider_number(value f64) string {
	integer := i64(value)
	if value == f64(integer) {
		return integer.str()
	}
	return value.str()
}

pub fn slider(config SliderConfig) Element {
	value := slider_clamped_value(config.value, config.min, config.max)
	return Element{
		kind:                .slider
		id:                  config.id
		action_id:           config.action_id
		frame:               config.frame
		value:               value
		min_value:           config.min
		max_value:           config.max
		step:                if config.step > 0 { config.step } else { 0.0 }
		orientation:         config.orientation
		padding:             config.padding
		value_track:         config.value_track
		slider_style:        config.style
		enabled:             config.enabled
		accessibility_role:  'slider'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			'Slider'
		}
		accessibility_value: slider_number(value)
	}
}

// slider_decimals is how many decimals x needs to be written exactly, up to 6.
fn slider_decimals(x f64) int {
	for d in 0 .. 6 {
		scaled := math.abs(x) * math.pow(10, f64(d))
		if math.abs(scaled - math.round(scaled)) < 1e-6 {
			return d
		}
	}
	return 6
}

fn slider_round(value f64, decimals int) f64 {
	p := math.pow(10, f64(decimals))
	return math.round(value * p) / p
}

// slider_snap rounds value to the nearest min + k * step and keeps it in
// min...max. The result is rounded to the decimals of step and min, so steps
// such as 0.1 do not accumulate binary noise. A zero step only clamps.
fn slider_snap(value f64, min f64, max f64, step f64) f64 {
	if step <= 0 || !(max > min) {
		return slider_clamped_value(value, min, max)
	}
	snapped := min + math.round((value - min) / step) * step
	decimals := if slider_decimals(step) > slider_decimals(min) {
		slider_decimals(step)
	} else {
		slider_decimals(min)
	}
	return slider_clamped_value(slider_round(snapped, decimals), min, max)
}

// slider_key_value is where a key moves a linear slider's value: Left/Down and
// Right/Up by a step (ten with Shift), Page Down and Page Up by a tenth of the
// range rounded up to whole steps, Home and End to the ends. A continuous
// slider moves by 1% (10% with Shift or a page key). None for other keys.
fn slider_key_value(current f64, min f64, max f64, step f64, event KeyEvent) ?f64 {
	if !(max > min) {
		return none
	}
	direction := match event.code {
		.home { return min }
		.end { return max }
		.right, .up, .page_up { 1.0 }
		.left, .down, .page_down { -1.0 }
		else { return none }
	}
	span := max - min
	page := event.code in [.page_up, .page_down]
	if step > 0 {
		amount := if page {
			math.max(step, math.ceil(span / 10 / step - 1e-9) * step)
		} else if event.shift {
			step * 10
		} else {
			step
		}
		return slider_snap(current + direction * amount, min, max, step)
	}
	amount := span * if page || event.shift { 0.1 } else { 0.01 }
	return slider_clamped_value(current + direction * amount, min, max)
}

// slider_value_after_key returns the value a key asks a slider for, so a
// renderer without keyboard focus for sliders (or an application with its own
// focus model) can drive one: call it from on_key_event while the slider is
// the key target and rebuild with the result. See slider_key_value for the
// keys. None for other keys, keys with Command, Control or Option, disabled
// sliders and keys that change nothing.
pub fn slider_value_after_key(config SliderConfig, event KeyEvent) ?f64 {
	if !config.enabled || event.cmd || event.ctrl || event.alt {
		return none
	}
	current := slider_clamped_value(config.value, config.min, config.max)
	next := slider_key_value(current, config.min, config.max, if config.step > 0 {
		config.step
	} else {
		0.0
	}, event)?
	if next == current {
		return none
	}
	return next
}
