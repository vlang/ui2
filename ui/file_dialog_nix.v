// The X11 and Wayland desktops have no single file-dialog API. zenity and
// kdialog — the dialogs GNOME and KDE draw for their own apps, on Linux and
// the BSDs alike — are driven instead, which keeps every ui2 binary free of
// whole GTK or Qt. The _nix file suffix keeps the file out of Windows builds
// only, so the desktop scope is spelled out: macOS and iOS have their own
// bridge files, and Android the default fallback.
module ui2

$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
	import os

	fn linux_file_dialog_tool() string {
		if os.getenv('DISPLAY').len == 0 && os.getenv('WAYLAND_DISPLAY').len == 0 {
			return ''
		}
		desktop := os.getenv('XDG_CURRENT_DESKTOP').to_lower()
		preferred := if desktop.contains('kde') || desktop.contains('plasma') {
			['kdialog', 'zenity']
		} else {
			['zenity', 'kdialog']
		}
		for tool in preferred {
			if os.find_abs_path_of_executable(tool) or { '' }.len > 0 {
				return tool
			}
		}
		return ''
	}

	fn native_file_dialog_supported() bool {
		return linux_file_dialog_tool().len > 0
	}

	fn native_file_dialog(cfg FileDialogConfig) []string {
		tool := linux_file_dialog_tool()
		dialog := match tool {
			'zenity' { linux_zenity_file_dialog_command(cfg) }
			'kdialog' { linux_kdialog_file_dialog_command(cfg) }
			else { []string{} }
		}
		if dialog.len == 0 {
			eprintln('ui2: no native file dialog is available')
			return []string{}
		}
		// The selected paths arrive on stdout; the tools' chatty GTK warnings
		// arrive on stderr, which exec captures into the output too, and
		// linux_file_dialog_paths keeps them out of the result.
		result := os.exec(dialog)
		if result.exit_code != 0 {
			return []string{}
		}
		return linux_file_dialog_paths(result.output)
	}

	fn linux_file_dialog_start_path(cfg FileDialogConfig) string {
		if cfg.filename.len == 0 {
			return cfg.directory
		}
		if cfg.directory.len == 0 {
			return cfg.filename
		}
		return if cfg.directory.ends_with('/') {
			cfg.directory + cfg.filename
		} else {
			cfg.directory + '/' + cfg.filename
		}
	}

	fn linux_zenity_file_dialog_command(cfg FileDialogConfig) []string {
		mut parts := ['zenity', '--file-selection']
		if cfg.kind == .save {
			parts << ['--save', '--confirm-overwrite']
		}
		if cfg.kind == .folder {
			parts << '--directory'
		}
		if cfg.kind == .open && cfg.multiple {
			parts << ['--multiple', '--separator=\n']
		}
		if cfg.title.len > 0 {
			parts << '--title=${cfg.title}'
		}
		start := linux_file_dialog_start_path(cfg)
		if start.len > 0 {
			parts << '--filename=${start}'
		}
		if cfg.kind != .folder {
			for filter in cfg.filters {
				mut patterns := []string{}
				for extension in file_dialog_extensions([filter]) {
					patterns << '*.' + extension
				}
				if patterns.len > 0 {
					filter_name := if filter.name.len > 0 {
						filter.name
					} else {
						patterns.join(', ')
					}
					parts << '--file-filter=${filter_name} | ${patterns.join(' ')}'
				}
			}
		}
		return parts
	}

	fn linux_kdialog_file_dialog_command(cfg FileDialogConfig) []string {
		mut parts := ['kdialog']
		if cfg.title.len > 0 {
			parts << ['--title', cfg.title]
		}
		start := linux_file_dialog_start_path(cfg)
		filter := linux_kdialog_file_filter(cfg.filters)
		match cfg.kind {
			.open {
				parts << ['--getopenfilename', start, filter]
				if cfg.multiple {
					parts << ['--multiple', '--separate-output']
				}
			}
			.save {
				parts << ['--getsavefilename', start, filter]
			}
			.folder {
				parts << ['--getexistingdirectory', cfg.directory]
			}
		}
		return parts
	}

	fn linux_kdialog_file_filter(filters []FileDialogFilter) string {
		mut entries := []string{}
		for filter in filters {
			mut patterns := []string{}
			for extension in file_dialog_extensions([filter]) {
				patterns << '*.' + extension
			}
			if patterns.len > 0 {
				filter_name := if filter.name.len > 0 { filter.name } else { patterns.join(', ') }
				entries << '${patterns.join(' ')}|${filter_name}'
			}
		}
		return entries.join('\n')
	}

	fn linux_file_dialog_paths(output string) []string {
		mut paths := []string{}
		for raw in output.split('\n') {
			path := raw.trim_right('\r')
			// Both tools answer with absolute paths, while the GTK warnings that
			// land in the same captured output never do, so the filter keeps the
			// warnings out of the result.
			if path.len > 0 && path.starts_with('/') {
				paths << path
			}
		}
		return paths
	}
}
