module ui2

import math

// The color picker's entry points: color_picker builds the inline panel or a
// trigger, and color_picker_popover the panel a trigger opens.
//
// The popover is an overlay in the element tree, as popup and modal_view are:
// a transparent backdrop over the window that reports a click outside, and the
// panel above it. Add it to the screen's children last, so it is drawn on top
// and its coordinates are window coordinates. Where it goes is decided by
// color_picker_popover_frame alone, so a shared popover positioner can
// replace that one function.

// color_picker_swatch_box is the frame drawn round a color square: a darker
// shade of the color, or the theme border while there is no color. A swatch
// trigger's square takes the primary color, twice as wide, while its popover
// is open; a field shows that on its own frame instead.
fn color_picker_swatch_box(config ColorPickerConfig, radius f64, highlight bool) BoxStyle {
	open := highlight && config.open
	color := if open {
		config.theme.primary
	} else if config.empty {
		config.theme.border
	} else {
		choice_mix(config.value.rgb(), 0x000000, 0.3)
	}
	return color_picker_border_box(color, if open { 2.0 } else { 1.0 }, radius)
}

// color_picker_square draws the current color in frame: a rounded fill when
// it is opaque, a square over a checkerboard when it is translucent, and an
// empty frame when there is no color.
fn color_picker_square(config ColorPickerConfig, frame Rect, radius f64, highlight bool) []Element {
	value := config.value.normalized()
	alpha := if config.alpha { value.a } else { 1.0 }
	opaque := color_alpha_byte(alpha) >= 255
	corner := if opaque { radius } else { 0.0 }
	mut out := []Element{}
	if config.empty {
		out << view('', frame, BoxStyle{
			bg:     config.theme.background
			radius: corner
		}, []Element{})
	} else if opaque {
		out << view('', frame, BoxStyle{
			bg:     value.rgb()
			radius: corner
		}, []Element{})
	} else {
		out << color_picker_translucent(frame, value.rgb(), alpha, config.theme)
	}
	out << view('', frame, color_picker_swatch_box(config, corner, highlight), []Element{})
	return out
}

fn color_picker_trigger_value(config ColorPickerConfig) string {
	return if config.empty { 'none' } else { color_picker_hex_of(config, config.value) }
}

// color_picker_swatch_trigger is GPUI Kit's ColorPicker button: the color
// square, or an icon with a bar of the color under it, followed by the label.
fn color_picker_swatch_trigger(config ColorPickerConfig) Element {
	metrics := component_metrics(config.size)
	theme := config.theme
	width := config.frame.width
	height := config.frame.height
	side := math.max(math.min(math.min(height, metrics.height), width), 0)
	square := rect(0, (height - side) / 2, side, side)
	mut children := []Element{}
	if config.icon.len > 0 {
		icon_side := math.round(side * 0.6)
		bar := math.max(2.0, math.round(side / 10))
		top := square.y + (side - icon_side - bar - 2) / 2
		children << choice_icon(config.icon, rect((side - icon_side) / 2, top, icon_side,
			icon_side), if config.enabled { theme.foreground } else { theme.muted_foreground })
		bar_frame := rect(side * 0.2, top + icon_side + 2, side * 0.6, bar)
		if config.empty {
			children << view('', bar_frame, color_picker_border_box(theme.border, 1, 0),
				[]Element{})
		} else {
			children << view('', bar_frame, BoxStyle{
				bg:      config.value.rgb()
				opacity: if config.alpha { color_alpha(config.value.a) } else { 1.0 }
			}, []Element{})
		}
		if config.open {
			children << view('', square, color_picker_border_box(theme.primary, 2, metrics.radius),
				[]Element{})
		}
	} else {
		children << color_picker_square(config, square, metrics.radius / 2, true)
	}
	if config.label.len > 0 {
		x := side + metrics.gap
		children << label('', config.label, rect(x, 0, math.max(width - x, 0), height),
			TextStyle{
				color: if config.enabled { theme.foreground } else { theme.muted_foreground }
				size:  metrics.font_size
			})
	}
	return Element{
		...button_view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		action_id:           component_part_id(config.id, 'trigger')
		enabled:             config.enabled
		tooltip:             if config.empty || config.label.len > 0 {
			''
		} else {
			color_picker_hex_of(config, config.value)
		}
		cursor:              cursor_pointing_hand
		accessibility_role:  'button'
		accessibility_label: color_picker_description(config)
		accessibility_value: color_picker_trigger_value(config)
	}
}

// color_picker_field_trigger is GPUI Kit's ColorSelect: a framed field with a
// swatch, the hex value (or the placeholder) and a caret. The whole field
// opens the popover.
fn color_picker_field_trigger(config ColorPickerConfig) Element {
	metrics := component_metrics(config.size)
	theme := config.theme
	width := config.frame.width
	height := config.frame.height
	pad := math.min(metrics.padding + 2, width / 4)
	swatch_size := match config.size {
		.small { 14.0 }
		.medium { 16.0 }
		.large { 20.0 }
	}
	side := math.max(math.min(swatch_size, height - 4), 0)
	caret := math.max(math.min(metrics.font_size, height), 0)
	caret_x := math.max(width - pad - caret, 0)
	text_x := pad + side + metrics.gap
	mut children := color_picker_square(config, rect(pad, (height - side) / 2, side, side),
		3, false)
	children << label('', if config.empty {
		config.placeholder
	} else {
		color_picker_hex_of(config, config.value)
	},
		rect(text_x, 0, math.max(caret_x - metrics.gap - text_x, 0), height), TextStyle{
			color: if config.empty || !config.enabled {
				theme.muted_foreground
			} else {
				theme.foreground
			}
			size:  metrics.font_size
		})
	children << choice_icon('chevron.down', rect(caret_x, (height - caret) / 2, caret, caret),
		theme.muted_foreground)
	border := if config.open && config.enabled { theme.primary } else { theme.border }
	return Element{
		...button_view(config.id, config.frame, component_box(if config.enabled {
			theme.background
		} else {
			theme.muted
		}, border, metrics.radius), children)
		action_id:           component_part_id(config.id, 'trigger')
		enabled:             config.enabled
		cursor:              cursor_pointing_hand
		accessibility_role:  'combobox'
		accessibility_label: color_picker_description(config)
		accessibility_value: color_picker_trigger_value(config)
	}
}

// color_picker builds the picker named by config.variant: the panel itself
// (inline), or the trigger that opens it (swatch, field). Every variant is
// controlled: decode what it emits with color_picker_event against the same
// config, store the result and rebuild. Trigger variants also need
// color_picker_popover in the tree.
pub fn color_picker(config ColorPickerConfig) !Element {
	color_picker_validate(config)!
	if config.variant == .swatch {
		return component_finish(color_picker_swatch_trigger(config))
	}
	if config.variant == .field {
		return component_finish(color_picker_field_trigger(config))
	}
	return component_finish(color_picker_inline(config))
}

// color_picker_popover is the panel a swatch or field trigger opens: a
// backdrop over config.window that reports a click outside as `dismiss`, and
// the panel, placed by color_picker_popover_frame. While the popover is
// closed, for the inline variant, and while disabled it is an empty hidden
// view. Put it in the screen's children after everything it should cover.
pub fn color_picker_popover(config ColorPickerConfig) !Element {
	color_picker_validate(config)!
	popover_id := component_part_id(config.id, 'popover')
	if config.variant == .inline || !config.open || !config.enabled {
		return Element{
			...view(popover_id, Rect{}, BoxStyle{ transparent: true }, []Element{})
			hidden: true
		}
	}
	layout := color_picker_layout(config)
	m := color_picker_metrics(config.size)
	panel := color_picker_panel_frame(config)
	window := config.window
	has_window := window.width > 0 && window.height > 0
	// The popover covers the window, so the panel keeps its window position.
	// Without a window it is just the panel.
	root := if has_window {
		rect(0, 0, math.max(window.x + window.width, panel.x + panel.width), math.max(window.y +
			window.height, panel.y + panel.height))
	} else {
		panel
	}
	// The panel answers clicks itself, so a click on its background does not
	// reach the backdrop beneath and close it. Its action is ignored.
	surface := Element{
		...button_view(component_part_id(config.id, 'panel'), if has_window {
			panel
		} else {
			component_local(panel)
		}, BoxStyle{
			bg:            config.theme.background
			radius:        m.radius
			border_color:  config.theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        box_shadow(0x000000, 0.18, 18, 6)
		}, color_picker_panel_children(config, layout))
		key:                 'panel'
		cursor:              cursor_default
		accessibility_role:  'dialog'
		accessibility_label: color_picker_description(config)
		accessibility_value: color_picker_hex_of(config, config.value)
	}
	mut children := []Element{}
	if has_window {
		children << Element{
			...button_view(component_part_id(config.id, 'dismiss'), window, BoxStyle{
				transparent: true
			}, []Element{})
			key:                 'backdrop'
			accessibility_role:  'presentation'
			accessibility_label: 'Close color picker'
		}
	}
	children << surface
	return component_finish(view(popover_id, root, BoxStyle{ transparent: true }, children))
}
