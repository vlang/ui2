module ui2

import math

// Copy buttons after GPUI Kit's Clipboard. Building one never touches the
// clipboard: the button emits clipboard_action_id(id), and the application
// copies from on_event with clipboard_copy_from_action, or with
// ClipboardFeedback.copy_from_action, which also shows the check icon for a
// moment the way GPUI Kit's element does by itself.

// clipboard_feedback_duration is how long, in seconds, a copy button shows that
// it copied (GPUI Kit's two seconds).
pub const clipboard_feedback_duration = 2.0

pub struct ClipboardButtonConfig {
pub:
	id    string
	frame Rect
	// label is drawn beside the icon; empty gives GPUI Kit's icon-only button.
	label        string
	copied_label string = 'Copied' // Replaces label while copied.
	// copied shows the check icon. The application owns it; ClipboardFeedback
	// keeps it for clipboard_feedback_duration after each copy.
	copied bool
	// supported is false where there is no clipboard to copy to: pass a cached
	// clipboard_supported() (on Linux it searches PATH). The button is then
	// disabled, or hidden with hide_unsupported.
	supported        bool = true
	hide_unsupported bool
	enabled          bool = true
	tooltip          string
	// accessibility_label names the button; it defaults to label, or "Copy".
	// Name what is copied when the context does not, such as "Copy API key".
	accessibility_label string
	size                ComponentSize = .small
	theme               ComponentTheme
}

// clipboard_action_id is the action a copy button (or copyable text) emits.
pub fn clipboard_action_id(id string) string {
	return component_part_id(id, 'copy')
}

fn clipboard_is_copy_action(id string, action string) bool {
	part := component_action_part(id, action) or { return false }
	return part == 'copy'
}

// clipboard_copy_from_action copies value to the system clipboard when action
// is the copy button id's, and reports whether it did. Call it from on_event
// with the value as it is now (GPUI Kit's value or value_fn).
pub fn clipboard_copy_from_action(id string, value string, action string) bool {
	if !clipboard_is_copy_action(id, action) {
		return false
	}
	return set_clipboard_text(value)
}

// ClipboardFeedback remembers which copy buttons have just copied and forgets
// each after `duration` seconds, using `after`. Keep it in heap-allocated
// application state, since its timers hold its address.
pub struct ClipboardFeedback {
pub:
	duration f64 = clipboard_feedback_duration
mut:
	timers map[string]TimerId
}

// copied is the value to pass as a copy button's `copied`.
pub fn (feedback &ClipboardFeedback) copied(id string) bool {
	return id in feedback.timers
}

// copy_from_action is clipboard_copy_from_action that also shows the copied
// state when the copy succeeds. Copying again restarts the feedback, so a value
// that has changed since can be copied without waiting.
pub fn (mut feedback ClipboardFeedback) copy_from_action(id string, value string, action string) bool {
	if !clipboard_copy_from_action(id, value, action) {
		return false
	}
	feedback.show(id)
	return true
}

// show marks id as copied for `duration` seconds.
pub fn (mut feedback ClipboardFeedback) show(id string) {
	if previous := feedback.timers[id] {
		cancel_timer(previous)
	}
	feedback.timers[id] = after(feedback.duration, fn [mut feedback, id] () {
		feedback.timers.delete(id)
	})
}

// clipboard_icon is the copy icon, or the check mark once copied. SF Symbols'
// checkmark is not in every renderer's symbol table, so the check mark falls
// back to the ✓ character there.
fn clipboard_icon(copied bool, frame Rect, color u32) Element {
	if !copied {
		return notification_symbol('doc.on.doc', frame, color)
	}
	if symbol_known('checkmark') {
		return notification_symbol('checkmark', frame, color)
	}
	return label('', '✓', frame, TextStyle{
		color: color
		size:  math.round(frame.height * 1.1)
		bold:  true
		align: .center
	})
}

// clipboard_control builds the button for clipboard_button and copyable_text;
// element_id is its lookup id and frame its frame, while its action always
// belongs to config.id.
fn clipboard_control(config ClipboardButtonConfig, element_id string, frame Rect) Element {
	metrics := component_metrics(config.size)
	theme := config.theme
	active := config.enabled && config.supported
	icon_color := if !active {
		theme.muted_foreground
	} else if config.copied {
		theme.success
	} else {
		theme.foreground
	}
	side := math.max(math.min(metrics.font_size + 2, math.min(frame.width, frame.height)), 0)
	caption := if config.copied { config.copied_label } else { config.label }
	mut children := []Element{}
	mut box := BoxStyle{
		transparent: true
		radius:      metrics.radius
	}
	if config.label.len == 0 {
		children << clipboard_icon(config.copied, rect((frame.width - side) / 2, (frame.height - side) / 2,
			side, side), icon_color)
	} else {
		// Outlined, with the border drawn as a disc under the fill so its corners
		// round on every renderer.
		box = BoxStyle{
			bg:     theme.border
			radius: metrics.radius
		}
		children << view('', rect(1, 1, math.max(frame.width - 2, 0), math.max(frame.height - 2, 0)),
			BoxStyle{
				bg:     theme.background
				radius: math.max(metrics.radius - 1, 0)
			}, []Element{})
		width := side + metrics.gap +
			math.max(component_text_width_estimate(config.label, metrics.font_size), component_text_width_estimate(config.copied_label,
				metrics.font_size))
		x := math.max((frame.width - width) / 2, metrics.padding)
		children << clipboard_icon(config.copied, rect(x, (frame.height - side) / 2, side, side),
			icon_color)
		text_x := x + side + metrics.gap
		children << label('', caption, rect(text_x, 0, math.max(frame.width - text_x - metrics.padding / 2, 0),
			frame.height), TextStyle{
			color: if active { theme.foreground } else { theme.muted_foreground }
			size:  metrics.font_size
		})
	}
	name := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else if config.label.len > 0 {
		config.label
	} else {
		'Copy'
	}
	tip := if config.tooltip.len > 0 {
		config.tooltip
	} else if !config.supported {
		'Clipboard unavailable'
	} else {
		''
	}
	return Element{
		...button_view(element_id, frame, box, children)
		action_id:           clipboard_action_id(config.id)
		enabled:             active
		hidden:              !config.supported && config.hide_unsupported
		tooltip:             tip
		cursor:              if active { cursor_pointing_hand } else { '' }
		accessibility_label: name
		accessibility_value: if config.copied { 'Copied' } else { '' }
	}
}

// clipboard_button is GPUI Kit's Clipboard: a ghost button with a copy icon
// that turns into a check mark while `copied`, or with a label, an outlined
// button reading label and then copied_label.
pub fn clipboard_button(config ClipboardButtonConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	return component_finish(clipboard_control(config, config.id, config.frame))
}

pub struct CopyableTextConfig {
pub:
	id        string
	frame     Rect
	text      string
	copied    bool
	supported bool = true
	monospace bool
	enabled   bool = true
	tooltip   string // For the copy button.
	// accessibility_label names the copy button; it defaults to "Copy".
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// copyable_text shows a value in a read-only box with a copy button at its end,
// the composition GPUI Kit's documentation builds from an Input and a Clipboard
// suffix. Its button emits clipboard_action_id(id).
pub fn copyable_text(config CopyableTextConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	metrics := component_metrics(config.size)
	theme := config.theme
	frame := config.frame
	inset := math.min(math.round(metrics.padding / 2), math.min(frame.width, frame.height) / 2)
	side := math.max(math.min(frame.height - inset * 2, frame.width - inset * 2), 0)
	text_x := math.min(metrics.padding, frame.width)
	copy_button := clipboard_control(ClipboardButtonConfig{
		id:                  config.id
		copied:              config.copied
		supported:           config.supported
		enabled:             config.enabled
		tooltip:             config.tooltip
		accessibility_label: config.accessibility_label
		size:                config.size
		theme:               theme
	}, component_part_id(config.id, 'button'), rect(frame.width - inset - side, (frame.height - side) / 2,
		side, side))
	return component_finish(Element{
		...view(config.id, frame, BoxStyle{
			bg:     theme.border
			radius: metrics.radius
		}, [
			view('', rect(1, 1, math.max(frame.width - 2, 0), math.max(frame.height - 2, 0)),
				BoxStyle{
					bg:     theme.muted
					radius: math.max(metrics.radius - 1, 0)
				}, []Element{}),
			label('', config.text, rect(text_x, 0, math.max(frame.width - text_x - side - inset * 2,
				0), frame.height), TextStyle{
				color:       if config.enabled { theme.foreground } else { theme.muted_foreground }
				size:        metrics.font_size
				font_family: if config.monospace { 'monospace' } else { '' }
			}),
			copy_button,
		])
		accessibility_role:  'group'
		accessibility_label: config.text
	})
}
