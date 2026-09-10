module ui2

// FileDialogKind selects which platform picker to show.
pub enum FileDialogKind {
	open
	save
	folder
}

// FileDialogFilter gives a file type a user-facing name and its filename
// extensions. Extensions may be written as `v`, `.v`, or `*.v`.
pub struct FileDialogFilter {
pub:
	name       string
	extensions []string
}

// FileDialogConfig configures a synchronous platform file picker. `directory`
// is the initial folder when the platform supports it, and `filename` is the
// proposed name for save dialogs. `multiple` applies only to open dialogs.
pub struct FileDialogConfig {
pub:
	kind      FileDialogKind = .open
	title     string
	directory string
	filename  string
	filters   []FileDialogFilter
	multiple  bool
}

// file_dialog opens the operating system's own file picker and blocks until it
// is accepted or dismissed. An empty result means that the user cancelled, or
// that this target has no native picker. Check file_dialog_supported when those
// cases must be distinguished.
pub fn file_dialog(cfg FileDialogConfig) []string {
	return native_file_dialog(cfg)
}

// file_dialog_supported reports whether this target can display a native file
// picker. macOS, Windows, and Linux desktop sessions with zenity or kdialog
// are supported; mobile and headless fallback targets return false.
pub fn file_dialog_supported() bool {
	return native_file_dialog_supported()
}

// open_file_dialog selects one file, or several when cfg.multiple is true.
pub fn open_file_dialog(cfg FileDialogConfig) []string {
	return native_file_dialog(open_file_dialog_config(cfg))
}

fn open_file_dialog_config(cfg FileDialogConfig) FileDialogConfig {
	return FileDialogConfig{
		kind: .open
		title: cfg.title
		directory: cfg.directory
		filename: cfg.filename
		filters: cfg.filters
		multiple: cfg.multiple
	}
}

// save_file_dialog asks for a destination filename. It returns either one path
// or no paths when dismissed.
pub fn save_file_dialog(cfg FileDialogConfig) []string {
	return native_file_dialog(save_file_dialog_config(cfg))
}

fn save_file_dialog_config(cfg FileDialogConfig) FileDialogConfig {
	return FileDialogConfig{
		kind: .save
		title: cfg.title
		directory: cfg.directory
		filename: cfg.filename
		filters: cfg.filters
	}
}

// open_folder_dialog selects one existing folder. File filters and `multiple`
// do not apply to folder dialogs.
pub fn open_folder_dialog(cfg FileDialogConfig) []string {
	return native_file_dialog(open_folder_dialog_config(cfg))
}

fn open_folder_dialog_config(cfg FileDialogConfig) FileDialogConfig {
	return FileDialogConfig{
		kind: .folder
		title: cfg.title
		directory: cfg.directory
	}
}

// file_dialog_extensions normalizes the common extension notation before it is
// handed to native filter APIs. It preserves first-seen order and ignores the
// wildcard, because an unrestricted picker needs no explicit type filter.
fn file_dialog_extensions(filters []FileDialogFilter) []string {
	mut seen := map[string]bool{}
	mut result := []string{}
	for filter in filters {
		for extension in filter.extensions {
			mut clean := extension.trim_space()
			if clean.starts_with('*.') {
				clean = clean[2..]
			} else if clean.starts_with('.') {
				clean = clean[1..]
			}
			if clean.len == 0 || clean == '*' || clean == '*.*' || seen[clean] {
				continue
			}
			seen[clean] = true
			result << clean
		}
	}
	return result
}

// file_dialog_filter_spec is the label/pattern representation expected by the
// Windows backend. It is deliberately plain text so each backend can map the
// same public filters onto its own native control.
fn file_dialog_filter_spec(filters []FileDialogFilter) string {
	mut parts := []string{}
	for filter in filters {
		mut patterns := []string{}
		for extension in filter.extensions {
			mut clean := extension.trim_space()
			if clean.starts_with('*.') {
				clean = clean[2..]
			} else if clean.starts_with('.') {
				clean = clean[1..]
			}
			if clean.len > 0 && clean != '*' && clean != '*.*' {
				patterns << '*.' + clean
			}
		}
		if patterns.len > 0 {
			filter_name := if filter.name.len > 0 { filter.name } else { patterns.join(', ') }
			parts << filter_name
			parts << patterns.join(';')
		}
	}
	parts << 'All files'
	parts << '*.*'
	return parts.join('|')
}
