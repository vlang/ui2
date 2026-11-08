// The X11 desktops have no single system alert API. zenity and kdialog — the
// dialogs GNOME and KDE draw for their own apps, on Linux and the BSDs alike —
// are driven instead, which keeps every ui2 binary free of whole GTK or Qt.
// The _nix file suffix keeps the file out of Windows builds only, so the
// desktop scope is spelled out: macOS and iOS have their own bridge files,
// and Android the default fallback.
module ui2

$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
	import os

	// linux_message_box_tool reports the helper this machine can show a dialog
	// with, preferring the one belonging to the running desktop. It is empty when
	// there is no display or neither helper is installed.
	fn linux_message_box_tool() string {
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

	fn native_message_box_supported() bool {
		return linux_message_box_tool().len > 0
	}

	fn native_message_box(cfg MessageBoxConfig) MessageBoxResult {
		tool := linux_message_box_tool()
		dialog := match tool {
			'zenity' { linux_zenity_command(cfg) }
			'kdialog' { linux_kdialog_command(cfg) }
			else { []string{} }
		}
		if dialog.len == 0 {
			// Headless or unequipped: report the message so it is not swallowed,
			// then answer as if the user dismissed the dialog.
			eprintln('ui2: ${cfg.title} ${cfg.text}')
			return message_box_default_result(cfg.buttons)
		}
		result := os.exec(dialog)
		if result.exit_code < 0 {
			return message_box_default_result(cfg.buttons)
		}
		if tool == 'zenity' {
			return linux_zenity_result(cfg.buttons, result.exit_code, result.output)
		}
		return linux_kdialog_result(cfg.buttons, result.exit_code)
	}

	fn linux_zenity_command(cfg MessageBoxConfig) []string {
		titles := message_box_button_titles(cfg.buttons)
		// Only --question draws more than one button, so multi-button sets use it
		// whatever their severity and relabel the standard pair.
		kind := if cfg.buttons == .ok {
			match cfg.style {
				.info { '--info' }
				.warning { '--warning' }
				.error { '--error' }
				.question { '--question' }
			}
		} else {
			'--question'
		}
		mut parts := ['zenity', kind, '--title=${cfg.title}', '--text=${linux_dialog_body(cfg)}']
		parts << '--ok-label=${titles[0]}'
		if titles.len > 1 {
			parts << '--cancel-label=${titles[titles.len - 1]}'
		}
		if titles.len > 2 {
			// zenity offers exactly one OK and one Cancel button; anything in
			// between has to be an extra button, which prints its own label.
			parts << '--extra-button=${titles[1]}'
		}
		return parts
	}

	fn linux_zenity_result(buttons MessageBoxButtons, exit_code int, output string) MessageBoxResult {
		titles := message_box_button_titles(buttons)
		if exit_code == 0 {
			return message_box_result_at(buttons, 0)
		}
		if titles.len > 2 && output.trim_space() == titles[1] {
			return message_box_result_at(buttons, 1)
		}
		return message_box_result_at(buttons, titles.len - 1)
	}

	fn linux_kdialog_command(cfg MessageBoxConfig) []string {
		titles := message_box_button_titles(cfg.buttons)
		body := linux_dialog_body(cfg)
		mut parts := ['kdialog', '--title', cfg.title]
		match cfg.buttons {
			.ok {
				kind := match cfg.style {
					.info, .question { '--msgbox' }
					.warning { '--sorry' }
					.error { '--error' }
				}
				parts << [kind, body]
			}
			.yes_no_cancel {
				parts << ['--yesnocancel', body, '--yes-label', titles[0], '--no-label', titles[1],
					'--cancel-label', titles[2]]
			}
			else {
				parts << ['--yesno', body, '--yes-label', titles[0], '--no-label', titles[1]]
			}
		}
		return parts
	}

	fn linux_kdialog_result(buttons MessageBoxButtons, exit_code int) MessageBoxResult {
		if buttons == .ok {
			return message_box_result_at(buttons, 0)
		}
		// --yesno and --yesnocancel exit 0/1/2 in button order.
		return message_box_result_at(buttons, exit_code)
	}

	// linux_dialog_body keeps the heading visible: both helpers show the title in
	// the window frame only, which some window managers hide entirely.
	fn linux_dialog_body(cfg MessageBoxConfig) string {
		if cfg.title.len == 0 {
			return cfg.text
		}
		if cfg.text.len == 0 {
			return cfg.title
		}
		return '${cfg.title}\n\n${cfg.text}'
	}
}
