module ui2

pub struct SpinnerConfig {
pub:
	id              string
	action_id       string
	frame           Rect
	text            string
	values          []string
	text_autoupdate bool
	box             BoxStyle
	text_style      TextStyle
}

// spinner_selected_text applies the automatic first-value rule. It is public
// so model code can use the same initialization behavior.
pub fn spinner_selected_text(text string, values []string, text_autoupdate bool) string {
	if text_autoupdate && values.len > 0 {
		return values[0]
	}
	return text
}

// spinner creates a compact single-selection control backed by UI2's native
// or custom dropdown implementation.
pub fn spinner(config SpinnerConfig) Element {
	selected := spinner_selected_text(config.text, config.values, config.text_autoupdate)
	return Element{
		...dropdown(config.id, selected, config.values, config.frame, config.box, config.text_style)
		action_id: config.action_id
		accessibility_role: 'combobox'
		accessibility_label: 'Spinner'
		accessibility_value: selected
	}
}
