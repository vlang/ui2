module ui2

// MessageBoxStyle selects the platform alert's severity: it drives the icon
// and, on macOS, whether the alert is rendered as a critical one.
pub enum MessageBoxStyle {
	info
	warning
	error
	question
}

// MessageBoxButtons picks one of the standard button sets. Platforms lay the
// buttons out in their own conventional order and give the last "negative"
// entry the Escape/Back behavior.
pub enum MessageBoxButtons {
	ok
	ok_cancel
	yes_no
	yes_no_cancel
	retry_cancel
}

pub enum MessageBoxResult {
	ok
	cancel
	yes
	no
	retry
}

pub struct MessageBoxConfig {
pub:
	// title is the short heading. macOS renders it as the alert's bold
	// message text, Windows and Linux as the dialog caption.
	title string
	// text is the explanatory body below the heading.
	text    string
	style   MessageBoxStyle   = .info
	buttons MessageBoxButtons = .ok
}

// message_box shows the operating system's own modal alert and blocks until
// the user dismisses it. Use custom_message_box instead when the dialog has to
// stay inside the window, or on platforms where message_box_supported is false.
pub fn message_box(cfg MessageBoxConfig) MessageBoxResult {
	return native_message_box(cfg)
}

// message_box_supported reports whether message_box reaches a real platform
// dialog. Android has no alert this layer can drive without a JVM callback, so
// message_box returns the dismissal result there without showing anything.
pub fn message_box_supported() bool {
	return native_message_box_supported()
}

// alert shows a single-button informational message box.
pub fn alert(title string, text string) {
	message_box(title: title, text: text)
}

// confirm asks a yes/no question and reports whether the user answered yes.
pub fn confirm(title string, text string) bool {
	return message_box(title: title, text: text, style: .question, buttons: .yes_no) == .yes
}

// message_box_button_titles lists the button labels in platform order: the
// affirmative answer first, the dismissal last.
fn message_box_button_titles(buttons MessageBoxButtons) []string {
	return match buttons {
		.ok { ['OK'] }
		.ok_cancel { ['OK', 'Cancel'] }
		.yes_no { ['Yes', 'No'] }
		.yes_no_cancel { ['Yes', 'No', 'Cancel'] }
		.retry_cancel { ['Retry', 'Cancel'] }
	}
}

// message_box_results mirrors message_box_button_titles so a backend can map a
// chosen button index straight back to a result.
fn message_box_results(buttons MessageBoxButtons) []MessageBoxResult {
	return match buttons {
		.ok { [MessageBoxResult.ok] }
		.ok_cancel { [MessageBoxResult.ok, .cancel] }
		.yes_no { [MessageBoxResult.yes, .no] }
		.yes_no_cancel { [MessageBoxResult.yes, .no, .cancel] }
		.retry_cancel { [MessageBoxResult.retry, .cancel] }
	}
}

// message_box_default_result is what a dismissed — or unavailable — dialog
// reports. It is always the non-destructive answer.
fn message_box_default_result(buttons MessageBoxButtons) MessageBoxResult {
	return match buttons {
		.ok { MessageBoxResult.ok }
		.yes_no { MessageBoxResult.no }
		.ok_cancel, .yes_no_cancel, .retry_cancel { MessageBoxResult.cancel }
	}
}

fn message_box_result_at(buttons MessageBoxButtons, index int) MessageBoxResult {
	results := message_box_results(buttons)
	if index < 0 || index >= results.len {
		return message_box_default_result(buttons)
	}
	return results[index]
}

// ── Hand-drawn dialog ──────────────────────────────────────────────

// MessageBoxAction is one button of a custom_message_box.
pub struct MessageBoxAction {
pub:
	id        string // element id, and the emitted event when action_id is empty
	action_id string
	title     string
}

pub struct CustomMessageBoxConfig {
pub:
	// id names the dimmed overlay; the dialog and its labels derive their ids
	// from it, so one id keeps the whole dialog addressable.
	id string = 'message_box'
	// frame is the region the overlay covers, normally bounds().
	frame   Rect
	title   string
	text    string
	hidden  bool
	width   f64 = 300
	height  f64 = 150
	actions []MessageBoxAction
}

const custom_message_box_overlay_bg = u32(0xCBD5E1)
const custom_message_box_dialog_bg = u32(0xFFFFFF)
const custom_message_box_title_color = u32(0x111827)
const custom_message_box_text_color = u32(0x475569)
const custom_message_box_button_width = f64(80)
const custom_message_box_button_height = f64(32)
const custom_message_box_padding = f64(20)
const custom_message_box_button_gap = f64(12)

// custom_message_box builds the hand-drawn, in-window dialog: a dimmed overlay
// with a rounded card, a heading, a body line and right-aligned native
// buttons. Unlike message_box it does not block — add it as the last child of
// the screen and flip `hidden` from the button events.
pub fn custom_message_box(cfg CustomMessageBoxConfig) Element {
	dialog_frame := rect((cfg.frame.width - cfg.width) / 2, (cfg.frame.height - cfg.height) / 2,
		cfg.width, cfg.height)
	label_width := cfg.width - custom_message_box_padding * 2
	mut children := [
		label('${cfg.id}_title', cfg.title, rect(custom_message_box_padding, custom_message_box_padding,
			label_width, 28), TextStyle{
			color: custom_message_box_title_color
			size: 18
			bold: true
		}),
		label('${cfg.id}_text', cfg.text, rect(custom_message_box_padding, custom_message_box_padding + 34,
			label_width, 22), TextStyle{
			color: custom_message_box_text_color
			size: 12
		}),
	]
	// Lay the buttons out right to left so the affirmative action stays in the
	// bottom-right corner however many there are.
	button_y := cfg.height - custom_message_box_padding - custom_message_box_button_height
	mut x := cfg.width - custom_message_box_padding - custom_message_box_button_width
	for index, action in cfg.actions {
		id := if action.id.len > 0 { action.id } else { '${cfg.id}_action_${index}' }
		children << Element{
			...with_native_style(button(id, action.title, rect(x, button_y, custom_message_box_button_width,
				custom_message_box_button_height), BoxStyle{}, TextStyle{}))
			action_id: action.action_id
		}
		x -= custom_message_box_button_width + custom_message_box_button_gap
	}
	dialog := view('${cfg.id}_dialog', dialog_frame, BoxStyle{
		bg: custom_message_box_dialog_bg
		radius: 12
	}, children)
	return Element{
		...view(cfg.id, cfg.frame, BoxStyle{
			bg: custom_message_box_overlay_bg
		}, [dialog])
		hidden: cfg.hidden
	}
}
