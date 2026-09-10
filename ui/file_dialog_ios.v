module ui2

// UIKit document pickers are asynchronous and require a presentation callback.
// Keep the synchronous desktop API explicit about not supporting that contract.
fn native_file_dialog_supported() bool {
	return false
}

fn native_file_dialog(cfg FileDialogConfig) []string {
	eprintln('ui2: native file dialogs are unavailable on iOS')
	return []string{}
}
