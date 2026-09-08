module ui2

pub struct SwitchStyle {
pub:
	inactive_track_color u32 = 0xcbd5e1
	active_track_color   u32 = 0x22c55e
	thumb_color          u32 = 0xffffff
	disabled_track_color u32 = 0xe2e8f0
	disabled_thumb_color u32 = 0xf8fafc
}

pub struct SwitchConfig {
pub:
	id        string
	action_id string
	frame     Rect
	active    bool
	style     SwitchStyle
}

// switch_track_frame centers the switch chrome inside the full interactive
// frame. The complete declared frame remains clickable and draggable.
fn switch_track_frame(frame Rect) Rect {
	mut height := if frame.height < 32 { frame.height } else { 32.0 }
	if height < 0 {
		height = 0
	}
	mut width := height * 1.625
	if width > frame.width {
		width = if frame.width > 0 { frame.width } else { 0.0 }
	}
	return rect(frame.x + (frame.width - width) / 2, frame.y + (frame.height - height) / 2, width, height)
}

fn switch_thumb_frame(track Rect, active bool) Rect {
	inset := if track.height > 4 { 2.0 } else { 0.0 }
	preferred := track.height - inset * 2
	size := if preferred < track.width { preferred } else { track.width }
	x := if active { track.x + track.width - inset - size } else { track.x + inset }
	return rect(x, track.y + (track.height - size) / 2, size, size)
}

// switch_control creates a two-state control. The declared active value is
// retained by rebuilding after its action fires; switch_active exposes the
// live backend value during the action callback.
pub fn switch_control(config SwitchConfig) Element {
	return Element{
		kind: .switch_control
		id: config.id
		action_id: config.action_id
		frame: config.frame
		checked: config.active
		switch_style: config.style
		accessibility_role: 'switch'
		accessibility_label: 'Switch'
		accessibility_value: if config.active { 'on' } else { 'off' }
	}
}
