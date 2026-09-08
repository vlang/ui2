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
	thumb_size        f64 = 20.0
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
}

struct SliderSpec {
	min         f64
	max         f64
	step        f64
	orientation Orientation
}

fn slider_spec(el Element) SliderSpec {
	return SliderSpec{
		min: el.min_value
		max: el.max_value
		step: el.step
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
		kind: .slider
		id: config.id
		action_id: config.action_id
		frame: config.frame
		value: value
		min_value: config.min
		max_value: config.max
		step: if config.step > 0 { config.step } else { 0.0 }
		orientation: config.orientation
		padding: config.padding
		value_track: config.value_track
		slider_style: config.style
		accessibility_role: 'slider'
		accessibility_label: 'Slider'
		accessibility_value: slider_number(value)
	}
}
