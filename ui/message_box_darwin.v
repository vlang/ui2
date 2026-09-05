// vfmt off
// NSAlert only needs the Objective-C runtime bridge, so unlike the AppKit view
// backend in macos/ this file stays outside the ui2_custom_rendering switch:
// custom-rendered macOS windows get the same system alert.
module ui2

import macos

#flag darwin -framework AppKit

const ns_alert_style_warning = u64(0)
const ns_alert_style_informational = u64(1)
const ns_alert_style_critical = u64(2)
const ns_alert_first_button_return = i64(1000)

fn native_alert_style(style MessageBoxStyle) u64 {
	return match style {
		.info, .question { ns_alert_style_informational }
		.warning { ns_alert_style_warning }
		.error { ns_alert_style_critical }
	}
}

fn native_message_box_supported() bool {
	return true
}

fn native_message_box(cfg MessageBoxConfig) MessageBoxResult {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	// NSAlert needs a live NSApplication to run its modal loop. Every backend
	// that opens a window already has one; the call is idempotent and keeps
	// message_box usable before the first window exists.
	macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	ns_alert := macos.msg_id(macos.alloc('NSAlert'), 'init')
	if ns_alert == unsafe { nil } {
		return message_box_default_result(cfg.buttons)
	}
	defer {
		macos.release(ns_alert)
	}
	// An NSAlert without message text renders as a bare button strip, so the
	// body moves up into the heading when no title was given.
	heading := if cfg.title.len > 0 { cfg.title } else { cfg.text }
	informative := if cfg.title.len > 0 { cfg.text } else { '' }
	macos.msg_void1(ns_alert, 'setMessageText:', macos.nsstring(heading))
	macos.msg_void1(ns_alert, 'setInformativeText:', macos.nsstring(informative))
	macos.msg_void_u64(ns_alert, 'setAlertStyle:', native_alert_style(cfg.style))
	for title in message_box_button_titles(cfg.buttons) {
		macos.msg_id1(ns_alert, 'addButtonWithTitle:', macos.nsstring(title))
	}
	response := macos.msg_i64(ns_alert, 'runModal')
	return message_box_result_at(cfg.buttons, int(response - ns_alert_first_button_return))
}
