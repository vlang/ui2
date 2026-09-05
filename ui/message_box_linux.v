// Linux has no single system alert API. The desktop portals that ship with
// GNOME (zenity) and KDE (kdialog) are the dialogs those environments draw for
// their own apps, so driving them keeps the alert native without linking the
// whole of GTK or Qt into every ui2 binary.
module ui2

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
	command := match tool {
		'zenity' { linux_zenity_command(cfg) }
		'kdialog' { linux_kdialog_command(cfg) }
		else { '' }
	}
	if command.len == 0 {
		// Headless or unequipped: report the message so it is not swallowed,
		// then answer as if the user dismissed the dialog.
		eprintln('ui2: ${cfg.title} ${cfg.text}')
		return message_box_default_result(cfg.buttons)
	}
	result := os.execute(command)
	if result.exit_code < 0 {
		return message_box_default_result(cfg.buttons)
	}
	if tool == 'zenity' {
		return linux_zenity_result(cfg.buttons, result.exit_code, result.output)
	}
	return linux_kdialog_result(cfg.buttons, result.exit_code)
}

// linux_shell_quote wraps a value for /bin/sh, which is what os.execute runs
// the command through.
fn linux_shell_quote(value string) string {
	return "'" + value.replace("'", "'\\''") + "'"
}

fn linux_zenity_command(cfg MessageBoxConfig) string {
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
	mut parts := ['zenity', kind, '--title=' + linux_shell_quote(cfg.title),
		'--text=' + linux_shell_quote(linux_dialog_body(cfg))]
	parts << '--ok-label=' + linux_shell_quote(titles[0])
	if titles.len > 1 {
		parts << '--cancel-label=' + linux_shell_quote(titles[titles.len - 1])
	}
	if titles.len > 2 {
		// zenity offers exactly one OK and one Cancel button; anything in
		// between has to be an extra button, which prints its own label.
		parts << '--extra-button=' + linux_shell_quote(titles[1])
	}
	return parts.join(' ')
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

fn linux_kdialog_command(cfg MessageBoxConfig) string {
	titles := message_box_button_titles(cfg.buttons)
	body := linux_shell_quote(linux_dialog_body(cfg))
	mut parts := ['kdialog', '--title', linux_shell_quote(cfg.title)]
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
			parts << ['--yesnocancel', body, '--yes-label', linux_shell_quote(titles[0]),
				'--no-label', linux_shell_quote(titles[1]),
				'--cancel-label', linux_shell_quote(titles[2])]
		}
		else {
			parts << ['--yesno', body, '--yes-label', linux_shell_quote(titles[0]),
				'--no-label', linux_shell_quote(titles[1])]
		}
	}
	return parts.join(' ')
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
