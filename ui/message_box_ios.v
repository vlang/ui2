module ui2

import macos

const ui_alert_controller_style_alert = macos.Id(usize(1))
const ui_alert_action_style_default = macos.Id(usize(0))
const ui_alert_action_style_cancel = macos.Id(usize(1))

// void (^)(UIAlertAction *)
const alert_action_signature = 'v16@?0@8'

// The alert's answer arrives on the block below, after native_message_box has
// already parked itself in a run loop, so it is handed back through globals.
__global g_alert_block = GlobalBlock{}
__global g_alert_titles = []string{}
__global g_alert_choice = -1

fn C.vui_alert_action(block voidptr, action voidptr)

@[export: 'vui_alert_action']
fn vui_alert_action(_block voidptr, action voidptr) {
	// A global block captures nothing, so the button is identified by the
	// action UIKit passes back. Every button set has distinct titles.
	title := objc_string(macos.msg_id(View(action), 'title'))
	for index, candidate in g_alert_titles {
		if candidate == title {
			g_alert_choice = index
			return
		}
	}
	g_alert_choice = g_alert_titles.len - 1
}

fn optional_nsstring(text string) macos.Id {
	return if text.len == 0 { objc_nil() } else { macos.nsstring(text) }
}

fn native_message_box_supported() bool {
	return true
}

fn native_message_box(cfg MessageBoxConfig) MessageBoxResult {
	titles := message_box_button_titles(cfg.buttons)
	handler := g_alert_block.build(voidptr(C.vui_alert_action), alert_action_signature)
	if g_root_vc == unsafe { nil } || titles.len == 0 || handler == unsafe { nil } {
		return message_box_default_result(cfg.buttons)
	}
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	// UIAlertController carries no severity styling, so cfg.style only survives
	// as the wording the caller already put in the title and text.
	// An empty heading or body has to be nil, or the alert reserves a blank
	// line for it.
	alert := macos.msg_id3(macos.get_class('UIAlertController'), 'alertControllerWithTitle:message:preferredStyle:', optional_nsstring(cfg.title), optional_nsstring(cfg.text), ui_alert_controller_style_alert)
	if objc_is_nil(alert) {
		return message_box_default_result(cfg.buttons)
	}
	for index, title in titles {
		// The last entry of a multi-button set is the dismissal, which iOS
		// draws apart from the rest and binds to the hardware back gesture.
		dismissal := titles.len > 1 && index + 1 == titles.len
		style := if dismissal {
			ui_alert_action_style_cancel
		} else {
			ui_alert_action_style_default
		}
		action := macos.msg_id3(macos.get_class('UIAlertAction'), 'actionWithTitle:style:handler:', macos.nsstring(title), style, macos.Id(handler))
		macos.msg_void1(alert, 'addAction:', action)
	}
	g_alert_titles = titles.clone()
	g_alert_choice = -1
	macos.msg_void_id_i64_id(top_view_controller(g_root_vc), 'presentViewController:animated:completion:', alert, 1, objc_nil())
	chosen := wait_for_alert(alert)
	g_alert_titles = []string{}
	return message_box_result_at(cfg.buttons, chosen)
}

// wait_for_alert pumps the main run loop in place instead of returning to it,
// which keeps message_box synchronous on iOS like it is on the desktop
// backends. An alert that goes away without answering — one that never managed
// to present, most of all — ends the wait rather than hanging the app.
fn wait_for_alert(alert macos.Id) int {
	loop := macos.msg_id(macos.get_class('NSRunLoop'), 'currentRunLoop')
	mode := extern_id('NSDefaultRunLoopMode', macos.run_loop_default_mode)
	date_class := macos.get_class('NSDate')
	mut grace := 0
	for g_alert_choice < 0 {
		deadline := macos.msg_id_f64(date_class, 'dateWithTimeIntervalSinceNow:', 0.02)
		macos.msg_id2(loop, 'runMode:beforeDate:', mode, deadline)
		if !objc_is_nil(macos.msg_id(alert, 'presentingViewController')) {
			continue
		}
		// The handler runs just after the dismissal, so leave it a moment.
		grace++
		if grace > 25 {
			return -1
		}
	}
	return g_alert_choice
}
