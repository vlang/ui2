module ui2

pub struct ToggleButtonConfig {
pub:
	id                 string
	action_id          string
	title              string
	frame              Rect
	pressed            bool
	group              string
	allow_no_selection bool = true
	box                BoxStyle
	down_box           BoxStyle = BoxStyle{ bg: 0x2563eb, radius: 6 }
	text_style         TextStyle
	down_text_style    TextStyle = TextStyle{ color: 0xffffff }
	native_style       bool
}

// toggle_button creates a button that retains an explicit pressed/released
// state across rebuilds. Its action fires after the backend has toggled the
// live state, so toggle_button_pressed can be read from the callback. Controls
// sharing a non-empty group are mutually exclusive; allow_no_selection controls
// whether pressing the selected member can release it.
pub fn toggle_button(config ToggleButtonConfig) Element {
	return Element{
		kind: .toggle_button
		id: config.id
		action_id: config.action_id
		text: config.title
		frame: config.frame
		box: config.box
		text_style: config.text_style
		checked: config.pressed
		toggle_group: config.group
		toggle_allow_no_selection: config.allow_no_selection
		toggle_down_box: config.down_box
		toggle_down_text_style: config.down_text_style
		native_style: config.native_style
		accessibility_role: 'button'
		accessibility_label: config.title
		accessibility_value: if config.pressed { 'pressed' } else { 'released' }
	}
}
