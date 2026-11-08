module ui2

import math

// GPUI Kit's Switch drawn from views: a pill track with a round thumb, a label
// on either side, an optional description, three sizes, a custom checked color,
// a loading state and the 150 ms thumb slide. See component_controls.v.

// SwitchLabelSide is the side of the track the label goes on.
pub enum SwitchLabelSide {
	right // The track first, then the label: GPUI Kit's default.
	left  // The label first; the track sits at the right edge of the frame.
}

pub struct StyledSwitchConfig {
pub:
	id          string
	frame       Rect
	checked     bool
	label       string
	description string // Muted text under the label; both wrap to the frame's width.
	label_side  SwitchLabelSide
	enabled     bool = true
	// loading shows a spinner in the thumb while the application applies a
	// change; the switch keeps its current state and ignores clicks.
	loading bool
	color   ?u32 // Track color when checked; defaults to the theme's primary.
	tooltip string
	// focused draws the focus ring around the track. Components cannot take
	// keyboard focus; set it while the application routes keys to the switch
	// (see styled_switch_checked_after_key).
	focused bool
	// reduce_motion moves the thumb at once instead of sliding it.
	reduce_motion       bool
	action_id           string // Defaults to id.
	accessibility_label string // Defaults to label.
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// SwitchMetrics are GPUI Kit's track sizes: 28x16, 36x20 and 44x24 with 12, 16
// and 20 unit thumbs inset by 2.
struct SwitchMetrics {
	width  f64
	height f64
	thumb  f64
	font   f64
	gap    f64
}

const switch_inset = 2.0
const switch_slide_seconds = 0.15

fn switch_metrics(size ComponentSize) SwitchMetrics {
	return match size {
		.small { SwitchMetrics{28, 16, 12, 12, 8} }
		.medium { SwitchMetrics{36, 20, 16, 14, 8} }
		.large { SwitchMetrics{44, 24, 20, 16, 8} }
	}
}

// styled_switch_thumb_x is where the thumb sits in its track, in track
// coordinates: at the start when off and at the end when on.
pub fn styled_switch_thumb_x(size ComponentSize, checked bool) f64 {
	sm := switch_metrics(size)
	return if checked { sm.width - sm.thumb - switch_inset } else { switch_inset }
}

// switch_colors returns the track and thumb colors. Unchecked tracks use the
// border color with a light thumb; a checked track takes the accent, with the
// theme's light or dark end on it, whichever reads better.
fn switch_colors(config StyledSwitchConfig) (u32, u32) {
	theme := config.theme
	light_end := if choice_luminance(theme.background) >= choice_luminance(theme.foreground) {
		theme.background
	} else {
		theme.foreground
	}
	dark_end := if light_end == theme.background { theme.foreground } else { theme.background }
	mut track := theme.border
	mut thumb := light_end
	if config.checked {
		if accent := config.color {
			track = accent
			thumb = if choice_contrast(light_end, accent) >= choice_contrast(dark_end, accent) {
				light_end
			} else {
				dark_end
			}
		} else {
			track = theme.primary
			thumb = theme.primary_foreground
		}
	}
	if !config.enabled {
		track = choice_mix(track, theme.background, 0.5)
	}
	return track, thumb
}

fn switch_row(config StyledSwitchConfig, width f64) ControlsRow {
	sm := switch_metrics(config.size)
	return controls_row(ControlsRowSpec{
		width:       width
		indicator_w: sm.width
		indicator_h: sm.height
		label:       config.label
		description: config.description
		label_left:  config.label_side == .left
		font:        sm.font
		gap:         sm.gap
	})
}

// styled_switch_width is how wide a switch's frame must be to show its label on
// one line. A description wraps to the width it is given.
pub fn styled_switch_width(config StyledSwitchConfig) f64 {
	sm := switch_metrics(config.size)
	return controls_row_width(sm.width, config.label, sm.font, sm.gap)
}

// styled_switch_height is how tall a switch is at its frame's width, with its
// label and description wrapped.
pub fn styled_switch_height(config StyledSwitchConfig) f64 {
	return switch_row(config, config.frame.width).height
}

fn switch_action(config StyledSwitchConfig) string {
	return if config.action_id.len > 0 { config.action_id } else { config.id }
}

// switch_x_target is where the last tween started on id is moving x to, so a
// rebuild with an unchanged state leaves a running slide alone.
fn switch_x_target(id string) ?f64 {
	runtime := g_animation_runtime
	runtime.mutex.lock()
	defer {
		runtime.mutex.unlock()
	}
	if id !in runtime.runs {
		return none
	}
	definition := runtime.runs[id].definition
	if definition.kind != .tween {
		return none
	}
	return definition.targets.x
}

// switch_slide moves the thumb id to x: the first build only records where it
// is, and a later change slides it there from wherever it is on screen, even in
// the middle of the previous slide. reduce_motion releases the thumb to its
// declared position.
fn switch_slide(id string, x f64, reduce_motion bool) {
	current := switch_x_target(id)
	if reduce_motion {
		if _ := current {
			clear_animation(id)
		}
		return
	}
	if previous := current {
		if math.abs(previous - x) > 1e-6 {
			animation(duration: switch_slide_seconds, transition: .out_cubic, x: x).start(id)
		}
		return
	}
	animation(duration: 0, x: x).start(id)
}

// styled_switch is GPUI Kit's Switch. The whole row, label included, is
// clickable; decode its action with styled_switch_checked_from_action.
pub fn styled_switch(config StyledSwitchConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	sm := switch_metrics(config.size)
	theme := config.theme
	frame := config.frame
	row := switch_row(config, frame.width)
	dy := math.max(0.0, (frame.height - row.height) / 2)
	track_frame := choice_fit(controls_shift(row.indicator, dy), frame.width, frame.height)
	track_color, thumb_color := switch_colors(config)
	thumb_id := component_part_id(config.id, 'thumb')
	thumb_x := styled_switch_thumb_x(config.size, config.checked)
	switch_slide(thumb_id, thumb_x, config.reduce_motion)
	mut thumb_children := []Element{}
	if config.loading {
		spinner_side := sm.thumb - 4
		thumb_children << loading_spinner(
			id:            component_part_id(config.id, 'loading')
			frame:         rect(2, 2, spinner_side, spinner_side)
			kind:          .ring
			diameter:      spinner_side
			color:         if config.checked { track_color } else { theme.muted_foreground }
			background:    thumb_color
			reduce_motion: config.reduce_motion
			theme:         theme
		)!
	}
	thumb := view(thumb_id, rect(thumb_x, (sm.height - sm.thumb) / 2, sm.thumb, sm.thumb),
		BoxStyle{
			bg:     thumb_color
			radius: sm.thumb / 2
			shadow: if config.enabled { box_shadow(0x000000, 0.2, 2, 0) } else { BoxShadow{} }
		}, thumb_children)
	mut children := []Element{}
	if config.focused && config.enabled {
		children << controls_focus_ring(track_frame, sm.height / 2, config.color or {
			theme.primary
		}, theme)
	}
	children << view('', track_frame, BoxStyle{
		bg:     track_color
		radius: sm.height / 2
	}, [thumb])
	label_color := if config.enabled { theme.foreground } else { choice_disabled_text(theme) }
	detail_color := if config.enabled {
		theme.muted_foreground
	} else {
		choice_disabled_text(theme)
	}
	children << controls_row_children(row, dy, config.label, config.description, sm.font,
		label_color, detail_color, frame.width, frame.height)
	state_text := if config.checked { 'on' } else { 'off' }
	el := Element{
		...button_view(config.id, frame, BoxStyle{ transparent: true }, children)
		action_id:           switch_action(config)
		enabled:             config.enabled && !config.loading
		accessibility_role:  'switch'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			config.label
		}
		accessibility_value: if config.loading { '${state_text}, busy' } else { state_text }
	}
	return component_finish(if config.tooltip.len > 0 {
		with_tooltip(el, config.tooltip)
	} else {
		el
	})
}

// styled_switch_checked_from_action returns the checked value an action asks
// for, the opposite of `checked`. None for other actions, while disabled and
// while loading.
pub fn styled_switch_checked_from_action(config StyledSwitchConfig, action string) ?bool {
	if !config.enabled || config.loading || config.id.len == 0 || action != switch_action(config) {
		return none
	}
	return !config.checked
}

// styled_switch_checked_after_key toggles the switch on Space or Return, as a
// focused GPUI Kit switch does. Call it from on_key_event while the
// application routes keys to the switch.
pub fn styled_switch_checked_after_key(config StyledSwitchConfig, event KeyEvent) ?bool {
	if !config.enabled || config.loading || !controls_enter_or_space(event) {
		return none
	}
	return !config.checked
}
