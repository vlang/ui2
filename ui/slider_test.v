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
	assert math.abs(slider_value_from_normalized(0.25, -100, 100, 0) + 50) < 0.000001
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
		id:          'volume'
		action_id:   'volume_changed'
		frame:       rect(4, 8, 240, 32)
		min:         -20
		max:         100
		value:       140
		step:        5
		value_track: true
		style:       SliderStyle{
			track_color:       0x111827
			value_track_color: 0x22c55e
			thumb_color:       0xf8fafc
			track_width:       6
			thumb_size:        24
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

fn test_slider_config_sets_enabled_and_accessibility_label() {
	el := slider(id: 's', enabled: false, accessibility_label: 'Volume')
	assert !el.enabled
	assert el.accessibility_label == 'Volume'
	assert slider(id: 's').enabled
	assert slider(id: 's').accessibility_label == 'Slider'
	assert slider(id: 's', accessibility_label: '').accessibility_label == 'Slider'
}

fn test_slider_keys_step_page_and_jump_to_the_ends() {
	config := SliderConfig{
		id:    'volume'
		value: 50
		step:  5
	}
	assert slider_value_after_key(config, KeyEvent{ code: .right })? == 55
	assert slider_value_after_key(config, KeyEvent{ code: .down })? == 45
	assert slider_value_after_key(config, KeyEvent{ code: .up, shift: true })? == 100
	assert slider_value_after_key(config, KeyEvent{ code: .page_down })? == 40
	assert slider_value_after_key(config, KeyEvent{ code: .home })? == 0
	assert slider_value_after_key(config, KeyEvent{ code: .end })? == 100
	assert slider_value_after_key(SliderConfig{ ...config, value: 100 }, KeyEvent{
		code: .right
	}) == none
	assert slider_value_after_key(config, KeyEvent{ code: .right, cmd: true }) == none
	assert slider_value_after_key(config, KeyEvent{ code: .tab }) == none
	assert slider_value_after_key(SliderConfig{ ...config, enabled: false }, KeyEvent{
		code: .right
	}) == none
	continuous := SliderConfig{
		id:    'pan'
		min:   -1
		max:   1
		value: 0
	}
	assert math.abs(slider_value_after_key(continuous, KeyEvent{ code: .right })? - 0.02) < 1e-9
	assert math.abs(slider_value_after_key(continuous, KeyEvent{ code: .page_up })? - 0.2) < 1e-9
	// Steps of 0.1 do not accumulate binary noise.
	tenths := SliderConfig{
		id:    'gain'
		max:   1
		value: 0.2
		step:  0.1
	}
	assert slider_value_after_key(tenths, KeyEvent{ code: .right })? == 0.3
}
