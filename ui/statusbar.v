module ui2

// Status bars use one line of text at the bottom of their area. The message
// takes the remaining width after the optional indicators on the right.
pub const statusbar_height = 28.0

pub struct StatusIndicator {
pub:
	id        string
	text      string
	tooltip   string
	width     f64    // optional fixed pane width; otherwise sized from its text
	action_id string // optional; makes the indicator a button
	toggle    bool
	pressed   bool
	enabled   bool = true
}

pub struct StatusBarConfig {
pub:
	id              string = 'status_bar'
	area            Rect // optional; defaults to the current window bounds
	message         string
	indicators      []StatusIndicator
	box             BoxStyle = BoxStyle{
		bg:           0xf5f5f5
		border_top:   1
		border_color: 0xcccccc
	}
	message_style   TextStyle = TextStyle{
		size:  12
		color: 0x334155
	}
	indicator_style TextStyle = TextStyle{
		size:  11
		color: 0x64748b
		align: .center
	}
}

// statusbar_content_area is the space above a bar in a window or panel.
pub fn statusbar_content_area(area Rect) Rect {
	height := if area.height > statusbar_height { area.height - statusbar_height } else { 0.0 }
	return rect(area.x, area.y, area.width, height)
}

fn statusbar_frame(area Rect) Rect {
	content := statusbar_content_area(area)
	return rect(area.x, area.y + content.height, area.width, area.height - content.height)
}

fn status_indicator_width(indicator StatusIndicator) f64 {
	if indicator.width > 0 {
		return if indicator.width < 32 { 32 } else { indicator.width }
	}
	estimated := f64(indicator.text.runes().len) * 7 + 24
	return if estimated < 52 { 52 } else { estimated }
}

// statusbar docks itself along the bottom of the current window. Set area only
// when building a preview or a bar inside a smaller panel. On each rebuild,
// the message and indicators reflect the application's current state.
pub fn statusbar(config StatusBarConfig) Element {
	area := if config.area.width == 0 && config.area.height == 0 { bounds() } else { config.area }
	frame := statusbar_frame(area)
	mut visible := []bool{len: config.indicators.len}
	mut widths := []f64{len: config.indicators.len}
	mut remaining := frame.width - 96 // 8px margins and an 80px message pane
	mut indicator_width := 0.0
	for index := config.indicators.len - 1; index >= 0; index-- {
		widths[index] = status_indicator_width(config.indicators[index])
		if widths[index] <= remaining {
			visible[index] = true
			remaining -= widths[index]
			indicator_width += widths[index]
		}
	}
	mut children := []Element{}
	message_space := frame.width - 28 - indicator_width
	message_width := if message_space > 0 { message_space } else { 0.0 }
	text_height := if frame.height > 8 { frame.height - 8 } else { 0.0 }
	children << label('${config.id}__message', config.message, rect(10, 4, message_width,
		text_height), config.message_style)
	mut x := frame.width - 8 - indicator_width
	for index, indicator in config.indicators {
		if !visible[index] {
			continue
		}
		width := widths[index]
		pane_id := '${config.id}__${if indicator.id.len > 0 { indicator.id } else { index.str() }}'
		control_frame := rect(1, 0, width - 1, frame.height)
		mut control := if indicator.toggle && indicator.action_id.len > 0 {
			toggle_button(
				id:              '${pane_id}__control'
				action_id:       indicator.action_id
				title:           indicator.text
				frame:           control_frame
				pressed:         indicator.pressed
				box:             BoxStyle{ transparent: true }
				down_box:        BoxStyle{ bg: 0xdbeafe, radius: 3 }
				text_style:      config.indicator_style
				down_text_style: TextStyle{
					...config.indicator_style
					color: 0x1d4ed8
				}
			)
		} else if indicator.action_id.len > 0 {
			with_action(button('${pane_id}__control', indicator.text, control_frame,
				BoxStyle{ transparent: true }, config.indicator_style), indicator.action_id)
		} else {
			label('', indicator.text, rect(8, 4, width - 16, text_height), config.indicator_style)
		}
		control = Element{
			...control
			enabled: indicator.enabled
		}
		if indicator.tooltip.len > 0 {
			control = with_tooltip(control, indicator.tooltip)
		}
		pane := view(pane_id,
			rect(x, 0, width, frame.height), BoxStyle{
				transparent:  true
				border_color: config.box.border_color
				border_left:  1
			}, [control])
		children << if indicator.tooltip.len > 0 {
			with_tooltip(pane, indicator.tooltip)
		} else {
			pane
		}
		x += width
	}
	return view(config.id, frame, config.box, children)
}
