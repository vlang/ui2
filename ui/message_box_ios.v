module ui2

fn C.vui_message_box(root voidptr, title &char, text &char, buttons &char, fallback int) int

fn native_message_box_supported() bool {
	return true
}

fn native_message_box(cfg MessageBoxConfig) MessageBoxResult {
	if g_root_vc == unsafe { nil } {
		return message_box_default_result(cfg.buttons)
	}
	titles := message_box_button_titles(cfg.buttons)
	// UIAlertController carries no severity styling, so cfg.style only survives
	// as the wording the caller already put in the title and text.
	joined := titles.join('\n')
	chosen := C.vui_message_box(g_root_vc, &char(cfg.title.str), &char(cfg.text.str),
		&char(joined.str), titles.len - 1)
	return message_box_result_at(cfg.buttons, chosen)
}
