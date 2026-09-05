// Fallback for targets with no alert this layer can drive — Android, whose
// AlertDialog needs a JVM callback the C backend cannot install. Apps that must
// ask something there should draw custom_message_box instead; check
// message_box_supported to decide.
module ui2

fn native_message_box_supported() bool {
	return false
}

fn native_message_box(cfg MessageBoxConfig) MessageBoxResult {
	eprintln('ui2: ${cfg.title} ${cfg.text}')
	return message_box_default_result(cfg.buttons)
}
