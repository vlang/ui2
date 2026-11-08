module ui2

// AlertDialogChoice is what an alert dialog was answered with. Every way of
// dismissing it (Cancel, Escape, the close button, the backdrop) is .cancel,
// the non-destructive answer, as for message_box.
pub enum AlertDialogChoice {
	confirm
	cancel
}

const alert_dialog_confirm_id = 'confirm'
const alert_dialog_cancel_id = 'cancel'

pub struct AlertDialogConfig {
pub:
	id          string
	frame       Rect // normally the window
	open        bool
	title       string
	description string
	// icon is a symbol name (see symbol_known) drawn beside the title, tinted
	// with icon_tone; destructive alerts default to the danger tone.
	icon         string
	icon_tone    ?ComponentTone
	confirm_text string = 'OK'
	cancel_text  string = 'Cancel'
	show_cancel  bool   = true
	// destructive fills the confirm button with the theme's danger color.
	destructive bool
	// default_choice is the button Enter activates. Destructive confirmations
	// often make it .cancel so Return cannot delete anything by accident.
	default_choice AlertDialogChoice = .confirm
	// children add body content below the description, laid out like a
	// dialog body; content_height -1 measures them.
	children          []Element
	content_height    f64               = -1
	footer_align      DialogFooterAlign = .center
	custom_width      f64               = 420
	close_button      bool
	close_on_backdrop bool
	close_on_escape   bool           = true
	backdrop          DialogBackdrop = .dim
	enabled           bool           = true
	size              ComponentSize  = .medium
	theme             ComponentTheme
}

// alert_dialog_dialog_config is the dialog an alert dialog is: Cancel then the
// confirm button in the footer, the icon in the header, and the alert's
// defaults for dismissal.
fn alert_dialog_dialog_config(config AlertDialogConfig) DialogConfig {
	mut buttons := []DialogButton{cap: 2}
	if config.show_cancel {
		buttons << DialogButton{
			id:   alert_dialog_cancel_id
			text: config.cancel_text
			role: .cancel
		}
	}
	buttons << DialogButton{
		id:      alert_dialog_confirm_id
		text:    config.confirm_text
		role:    .confirm
		variant: if config.destructive { .danger } else { .primary }
	}
	return DialogConfig{
		id:                config.id
		frame:             config.frame
		open:              config.open
		title:             config.title
		description:       config.description
		icon:              config.icon
		icon_tone:         config.icon_tone or {
			if config.destructive { ComponentTone.danger } else { ComponentTone.warning }
		}
		children:          config.children
		content_height:    config.content_height
		buttons:           buttons
		footer_align:      config.footer_align
		custom_width:      config.custom_width
		close_button:      config.close_button
		close_on_backdrop: config.close_on_backdrop
		close_on_escape:   config.close_on_escape
		// Enter is decoded by alert_dialog_key_choice, which honors default_choice.
		confirm_on_enter:  false
		backdrop:          config.backdrop
		enabled:           config.enabled
		size:              config.size
		theme:             config.theme
	}
}

// alert_dialog_layout is the geometry of alert_dialog(config); see dialog_layout.
pub fn alert_dialog_layout(config AlertDialogConfig) !DialogLayout {
	return dialog_layout(alert_dialog_dialog_config(config))
}

// alert_dialog is a confirmation built on modal_dialog. Unlike a plain dialog
// it has no close button and ignores backdrop presses unless asked, and its
// buttons are centered. The default button's accessibility value is `default`.
pub fn alert_dialog(config AlertDialogConfig) !Element {
	el := modal_dialog(alert_dialog_dialog_config(config))!
	default_id := dialog_button_action_id(config.id, if alert_dialog_effective_default(config) == .cancel {
		alert_dialog_cancel_id
	} else {
		alert_dialog_confirm_id
	})
	return component_finish(alert_dialog_mark_default(Element{
		...el
		accessibility_role: 'alertdialog'
	}, default_id))
}

fn alert_dialog_mark_default(el Element, default_id string) Element {
	if el.id == default_id {
		return Element{
			...el
			accessibility_value: 'default'
		}
	}
	if el.children.len == 0 {
		return el
	}
	mut children := []Element{cap: el.children.len}
	for child in el.children {
		children << alert_dialog_mark_default(child, default_id)
	}
	return Element{
		...el
		children: children
	}
}

fn alert_dialog_effective_default(config AlertDialogConfig) AlertDialogChoice {
	return if config.show_cancel { config.default_choice } else { .confirm }
}

// alert_dialog_choice_from_action decodes an action from alert_dialog against
// the config it was built with. The close button and the backdrop, when
// enabled, answer .cancel.
pub fn alert_dialog_choice_from_action(config AlertDialogConfig, action string) ?AlertDialogChoice {
	event := dialog_event_from_action(alert_dialog_dialog_config(config), action)?
	return if event.reason == .confirm { .confirm } else { .cancel }
}

// alert_dialog_key_choice is for on_key_event: Escape answers .cancel when
// close_on_escape allows it, and Enter answers default_choice.
pub fn alert_dialog_key_choice(config AlertDialogConfig, event KeyEvent) ?AlertDialogChoice {
	if !config.open || !config.enabled || event.shift || event.ctrl || event.alt || event.cmd {
		return none
	}
	if event.code == .escape {
		return if config.close_on_escape { AlertDialogChoice.cancel } else { none }
	}
	if event.code == .enter || event.code == .kp_enter {
		return alert_dialog_effective_default(config)
	}
	return none
}

// alert_dialog_open_animation is dialog_open_animation for an alert dialog;
// start it on dialog_surface_id(config.id).
pub fn alert_dialog_open_animation(config AlertDialogConfig) !Animation {
	return dialog_open_animation(alert_dialog_dialog_config(config))
}
