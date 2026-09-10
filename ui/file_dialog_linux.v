module ui2

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
	command := match tool {
		'zenity' { linux_zenity_file_dialog_command(cfg) }
		'kdialog' { linux_kdialog_file_dialog_command(cfg) }
		else { '' }
	}
	if command.len == 0 {
		eprintln('ui2: no native file dialog is available')
		return []string{}
	}
	result := os.execute(command)
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

fn linux_zenity_file_dialog_command(cfg FileDialogConfig) string {
	mut parts := ['zenity', '--file-selection']
	if cfg.kind == .save {
		parts << ['--save', '--confirm-overwrite']
	}
	if cfg.kind == .folder {
		parts << '--directory'
	}
	if cfg.kind == .open && cfg.multiple {
		parts << ['--multiple', '--separator=' + linux_shell_quote('\n')]
	}
	if cfg.title.len > 0 {
		parts << '--title=' + linux_shell_quote(cfg.title)
	}
	start := linux_file_dialog_start_path(cfg)
	if start.len > 0 {
		parts << '--filename=' + linux_shell_quote(start)
	}
	if cfg.kind != .folder {
		for filter in cfg.filters {
			mut patterns := []string{}
			for extension in file_dialog_extensions([filter]) {
				patterns << '*.' + extension
			}
			if patterns.len > 0 {
				filter_name := if filter.name.len > 0 { filter.name } else { patterns.join(', ') }
				parts << '--file-filter=' + linux_shell_quote('${filter_name} | ${patterns.join(' ')}')
			}
		}
	}
	return parts.join(' ')
}

fn linux_kdialog_file_dialog_command(cfg FileDialogConfig) string {
	mut parts := ['kdialog']
	if cfg.title.len > 0 {
		parts << ['--title', linux_shell_quote(cfg.title)]
	}
	start := linux_file_dialog_start_path(cfg)
	filter := linux_kdialog_file_filter(cfg.filters)
	match cfg.kind {
		.open {
			parts << ['--getopenfilename', linux_shell_quote(start), linux_shell_quote(filter)]
			if cfg.multiple {
				parts << ['--multiple', '--separate-output']
			}
		}
		.save {
			parts << ['--getsavefilename', linux_shell_quote(start), linux_shell_quote(filter)]
		}
		.folder {
			parts << ['--getexistingdirectory', linux_shell_quote(cfg.directory)]
		}
	}
	return parts.join(' ')
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
		if path.len > 0 {
			paths << path
		}
	}
	return paths
}
