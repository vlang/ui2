module ui2

import math

fn test_slider_clamps_and_normalizes_ranges() {
	assert slider_clamped_value(-20, 0, 100) == 0
	assert slider_clamped_value(120, 0, 100) == 100
	assert slider_clamped_value(25, 0, 100) == 25
	assert slider_clamped_value(25, 10, 10) == 10
	assert slider_value_normalized(25, 0, 100) == 0.25
	assert slider_value_normalized(-50, -100, 100) == 0.25
	assert slider_value_normalized(20, 10, 10) == 0
}

fn test_slider_normalized_values_snap_to_steps_and_cap_last_step() {
	assert slider_value_from_normalized(0.54, 0, 100, 10) == 50
	assert slider_value_from_normalized(0.56, 0, 100, 10) == 60
	assert slider_value_from_normalized(1, 0, 95, 10) == 95
	assert slider_value_from_normalized(-1, -20, 100, 0) == -20
	assert slider_value_from_normalized(2, -20, 100, 0) == 100
	assert math.abs(slider_value_from_normalized(0.25, -100, 100, 0) - -50) < 0.000001
}

fn test_slider_maps_horizontal_and_vertical_pointer_coordinates() {
	horizontal := rect(10, 20, 120, 30)
	assert slider_normalized_from_point(horizontal, .horizontal, 10, 20, 35) == 0
	assert slider_normalized_from_point(horizontal, .horizontal, 10, 70, 35) == 0.5
	assert slider_normalized_from_point(horizontal, .horizontal, 10, 120, 35) == 1

	vertical := rect(10, 20, 30, 120)
	assert slider_normalized_from_point(vertical, .vertical, 10, 25, 130) == 0
	assert slider_normalized_from_point(vertical, .vertical, 10, 25, 80) == 0.5
	assert slider_normalized_from_point(vertical, .vertical, 10, 25, 30) == 1
}

fn test_slider_constructor_exposes_state_style_and_accessibility() {
	el := slider(
		id: 'volume'
		action_id: 'volume_changed'
		frame: rect(4, 8, 240, 32)
		min: -20
		max: 100
		value: 140
		step: 5
		value_track: true
		style: SliderStyle{
			track_color: 0x111827
			value_track_color: 0x22c55e
			thumb_color: 0xf8fafc
			track_width: 6
			thumb_size: 24
		}
	)

	assert el.kind == .slider
	assert el.id == 'volume'
	assert el.action_id == 'volume_changed'
	assert el.value == 100
	assert el.min_value == -20
	assert el.max_value == 100
	assert el.step == 5
	assert el.orientation == .horizontal
	assert el.value_track
	assert el.slider_style.track_width == 6
	assert el.accessibility_role == 'slider'
	assert el.accessibility_value == '100'
}
