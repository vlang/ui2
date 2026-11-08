module ui2

import macos

fn native_clipboard_supported() bool {
	return true
}

fn general_pasteboard() macos.Id {
	return macos.msg_id(macos.get_class('UIPasteboard'), 'generalPasteboard')
}

fn native_set_clipboard_text(text string) bool {
	pasteboard := general_pasteboard()
	if pasteboard == unsafe { nil } {
		return false
	}
	macos.msg_void1(pasteboard, 'setString:', macos.nsstring(text))
	return true
}

fn native_clipboard_text() ?string {
	pasteboard := general_pasteboard()
	if pasteboard == unsafe { nil } {
		return none
	}
	value := macos.msg_id(pasteboard, 'string')
	if value == unsafe { nil } {
		return none
	}
	return macos.utf8_string(value)
}

// iOS has no X11-style primary selection; both halves answer unsupported.
fn native_set_primary_text(_ string) bool {
	return false
}

fn native_primary_text() ?string {
	return none
}
