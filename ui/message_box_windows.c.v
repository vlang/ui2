// vfmt off
// MessageBoxW needs nothing from the Win32 view backend, so unlike
// windows/ui_windows.v this file stays outside the ui2_custom_rendering
// switch: custom-rendered Windows apps get the same system alert.
module ui2

#flag windows -luser32

#insert "@VMODROOT/windows/message_box_windows.h"

fn C.ui2_win_message_box(title &u16, text &u16, flags u32) int

const mb_ok = u32(0x00000000)
const mb_ok_cancel = u32(0x00000001)
const mb_yes_no_cancel = u32(0x00000003)
const mb_yes_no = u32(0x00000004)
const mb_retry_cancel = u32(0x00000005)
const mb_icon_error = u32(0x00000010)
const mb_icon_question = u32(0x00000020)
const mb_icon_warning = u32(0x00000030)
const mb_icon_information = u32(0x00000040)

const id_ok = 1
const id_cancel = 2
const id_retry = 4
const id_yes = 6
const id_no = 7

fn native_message_box_flags(cfg MessageBoxConfig) u32 {
	buttons := match cfg.buttons {
		.ok { mb_ok }
		.ok_cancel { mb_ok_cancel }
		.yes_no { mb_yes_no }
		.yes_no_cancel { mb_yes_no_cancel }
		.retry_cancel { mb_retry_cancel }
	}
	icon := match cfg.style {
		.info { mb_icon_information }
		.warning { mb_icon_warning }
		.error { mb_icon_error }
		.question { mb_icon_question }
	}
	return buttons | icon
}

fn native_message_box_supported() bool {
	return true
}

fn native_message_box(cfg MessageBoxConfig) MessageBoxResult {
	// MessageBoxW has no separate informative-text field: the caption is the
	// heading and everything else shares one body paragraph.
	caption := if cfg.title.len > 0 { cfg.title } else { cfg.text }
	body := if cfg.title.len > 0 { cfg.text } else { '' }
	wide_caption := caption.to_wide()
	wide_body := body.to_wide()
	pressed := C.ui2_win_message_box(wide_caption, wide_body, native_message_box_flags(cfg))
	unsafe {
		free(wide_caption)
		free(wide_body)
	}
	return match pressed {
		id_ok { MessageBoxResult.ok }
		id_yes { MessageBoxResult.yes }
		id_no { MessageBoxResult.no }
		id_retry { MessageBoxResult.retry }
		id_cancel { MessageBoxResult.cancel }
		else { message_box_default_result(cfg.buttons) }
	}
}
