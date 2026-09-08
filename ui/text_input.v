module ui2

pub struct TextInputConfig {
pub:
	id             string
	action_id      string
	submit_id      string
	frame          Rect
	text           string
	hint_text      string
	multiline      bool = true
	password       bool
	readonly       bool
	disable_scroll bool
	enabled        bool = true
	autocorrect    bool = true
	keyboard       int
	padding_left   f64 = 12.0
	box            BoxStyle
	text_style     TextStyle
}

// text_input unifies UI2's single-line field and multiline editor. Password
// masking is currently a single-line behavior because native multiline editors
// do not expose a secure-entry mode.
pub fn text_input(config TextInputConfig) !Element {
	if config.password && config.multiline {
		return error('password text input must be single-line')
	}
	if config.multiline {
		return Element{
			kind: .text_area
			id: config.id
			action_id: config.action_id
			text: config.text
			placeholder: config.hint_text
			frame: config.frame
			box: config.box
			text_style: config.text_style
			emit_change: config.action_id.len > 0
			readonly: config.readonly
			disable_scroll: config.disable_scroll
			enabled: config.enabled
			autocorrect: config.autocorrect
			padding_left: config.padding_left
		}
	}
	mut field := if config.action_id.len > 0 {
		text_field_with_change_and_submit(config.id, config.submit_id, config.hint_text, config.text, config.frame, config.box, config.text_style, config.keyboard)
	} else if config.submit_id.len > 0 {
		text_field_with_submit(config.id, config.submit_id, config.hint_text, config.text, config.frame, config.box, config.text_style, config.keyboard)
	} else {
		text_field(config.id, config.hint_text, config.text, config.frame, config.box, config.text_style, config.keyboard)
	}
	field = Element{
		...field
		action_id: config.action_id
		secure: config.password
		readonly: config.readonly
		enabled: config.enabled
		autocorrect: config.autocorrect
		padding_left: config.padding_left
	}
	return field
}
