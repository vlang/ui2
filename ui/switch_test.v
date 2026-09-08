module ui2

fn test_switch_constructor_exposes_state_style_and_accessibility() {
	el := switch_control(
		id: 'wifi'
		action_id: 'wifi_changed'
		frame: rect(10, 20, 90, 40)
		active: true
		style: SwitchStyle{
			inactive_track_color: 0x111111
			active_track_color: 0x222222
			thumb_color: 0x333333
		}
	)
	assert el.kind == .switch_control
	assert el.id == 'wifi'
	assert el.action_id == 'wifi_changed'
	assert el.checked
	assert el.switch_style.active_track_color == u32(0x222222)
	assert el.accessibility_role == 'switch'
	assert el.accessibility_value == 'on'
}

fn test_switch_chrome_is_centered_inside_the_interactive_frame() {
	track := switch_track_frame(rect(10, 20, 100, 48))
	assert track == rect(34, 28, 52, 32)
	off := switch_thumb_frame(track, false)
	on := switch_thumb_frame(track, true)
	assert off.width == 28
	assert off.height == 28
	assert off.x == 36
	assert on.x == 56
	assert off.y == 30
	assert on.y == 30
}

fn test_switch_chrome_shrinks_for_small_bounds() {
	track := switch_track_frame(rect(0, 0, 20, 12))
	assert track.width == 19.5
	assert track.height == 12
	assert switch_thumb_frame(track, false).width == 8
}
