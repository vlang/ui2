// An X11 or Wayland clipboard belongs to a client that has to stay around to
// hand its contents over. The standard command-line clients — wl-copy, xclip and
// xsel — do exactly that from the background, so driving them gives custom-
// rendered windows on Linux and the BSDs a real system clipboard without
// taking over the event loop sokol owns. The _nix file suffix keeps the file
// out of Windows builds only, so the desktop scope is spelled out: macOS and
// iOS have their own bridge files, and Android the default fallback.
module ui2

import time

$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
	import os

	struct LinuxClipboardTool {
		copy  []string // arguments of the tool reading the text from its stdin
		paste []string
	}

	fn linux_has_executable(name string) bool {
		return (os.find_abs_path_of_executable(name) or { '' }).len > 0
	}

	fn linux_clipboard_tool() ?LinuxClipboardTool {
		if os.getenv('WAYLAND_DISPLAY').len > 0 && linux_has_executable('wl-copy')
			&& linux_has_executable('wl-paste') {
			return LinuxClipboardTool{
				copy:  ['wl-copy']
				paste: ['wl-paste', '--no-newline', '--type', 'text']
			}
		}
		if os.getenv('DISPLAY').len == 0 {
			return none
		}
		if linux_has_executable('xclip') {
			return LinuxClipboardTool{
				copy:  ['xclip', '-selection', 'clipboard', '-in']
				paste: ['xclip', '-selection', 'clipboard', '-out']
			}
		}
		if linux_has_executable('xsel') {
			return LinuxClipboardTool{
				copy:  ['xsel', '--clipboard', '--input']
				paste: ['xsel', '--clipboard', '--output']
			}
		}
		return none
	}

	fn native_clipboard_supported() bool {
		linux_clipboard_tool() or { return false }
		return true
	}

	// The copy tools daemonize while they hold the pasted selection: an xclip
	// keeps serving it after the command answers, and wl-copy never exits (it
	// serves until superseded). Any descendant that inherits the launcher's
	// captured output pipe keeps it open for that whole lifetime, so every
	// copy would block the caller until the selection is claimed by someone
	// else. Nothing reads the child's output: both streams are redirected away
	// from the capture pipe and stdin comes from a flushed temp file. xclip's
	// immediate child is waited for and its status reported, while wl-copy is
	// fire-and-forget and never waited.
	fn native_clipboard_write(copy_args []string, text string) bool {
		if copy_args.len == 0 {
			return false
		}
		path := os.join_path(os.temp_dir(), 'ui2-clipboard-${os.getpid()}-${time.sys_mono_now()}.txt')
		os.write_file(path, text) or { return false }
		defer {
			os.rm(path) or {}
		}
		$if clipboard_stage_probe ? {
			eprintln('KW stage: file ${time.sys_mono_now()}')
		}
		// `os.execute` captures the child's stdout and stderr through a pipe and
		// reads it to EOF before returning. A clipboard owner outlives the
		// launcher to serve the selection (xclip forks one, wl-copy never
		// exits), so if it inherits that pipe every copy blocks for the owner's
		// whole lifetime. Redirect BOTH streams away from the capture pipe and
		// feed stdin from the temp file — `os.write_file` above has already
		// written and closed it, so the launcher reads a flushed file, not a
		// pipe that keeps the caller waiting for EOF.
		cmd := copy_args.join(' ') + " < '" + path + "' > /dev/null 2>&1"
		if copy_args[0].contains('wl-copy') {
			// wl-copy serves until superseded, so never wait for it. Open the
			// file on fd 3 in the launching shell *before* backgrounding and
			// hand that descriptor to the child: unlinking `path` in the defer
			// cannot yank the input away once the child holds a descriptor.
			os.execute("exec 3< '" + path + "'; " + copy_args.join(' ') + ' <&3 > /dev/null 2>&1 &')
			$if clipboard_stage_probe ? {
				eprintln('KW stage: post-run ${time.sys_mono_now()}')
			}
			return true
		}
		$if clipboard_stage_probe ? {
			eprintln('KW stage: post-run ${time.sys_mono_now()}')
		}
		result := os.execute(cmd)
		$if clipboard_stage_probe ? {
			eprintln('KW stage: post-wait ${time.sys_mono_now()}')
		}
		$if clipboard_stage_probe ? {
			eprintln('KW stage: post-close ${time.sys_mono_now()}')
		}
		return result.exit_code == 0
	}

	fn native_set_clipboard_text(text string) bool {
		tool := linux_clipboard_tool() or { return false }
		return native_clipboard_write(tool.copy, text)
	}

	fn native_clipboard_text() ?string {
		tool := linux_clipboard_tool() or { return none }
		result := os.exec(tool.paste)
		if result.exit_code != 0 {
			return none
		}
		return result.output
	}

	// native_set_primary_text publishes X11-style primary selection text (the
	// one the middle button pastes): select with the mouse, paste with the
	// middle button. The same background tools drive it through their
	// primary-service arguments, program first like the clipboard argv above.
	fn native_set_primary_text(text string) bool {
		mut copy_args := []string{}
		if os.getenv('WAYLAND_DISPLAY').len > 0 && linux_has_executable('wl-copy')
			&& linux_has_executable('wl-paste') {
			copy_args = ['wl-copy', '--primary']
		} else if os.getenv('DISPLAY').len == 0 {
			return false
		} else if linux_has_executable('xclip') {
			copy_args = ['xclip', '-selection', 'primary', '-in']
		} else if linux_has_executable('xsel') {
			copy_args = ['xsel', '--primary', '--input']
		} else {
			return false
		}
		return native_clipboard_write(copy_args, text)
	}

	fn native_primary_text() ?string {
		mut paste_args := []string{}
		if os.getenv('WAYLAND_DISPLAY').len > 0 && linux_has_executable('wl-paste') {
			paste_args = ['wl-paste', '--no-newline', '--primary', '--type', 'text']
		} else if os.getenv('DISPLAY').len == 0 {
			return none
		} else if linux_has_executable('xclip') {
			paste_args = ['xclip', '-selection', 'primary', '-out']
		} else if linux_has_executable('xsel') {
			paste_args = ['xsel', '--primary', '--output']
		} else {
			return none
		}
		result := os.exec(paste_args)
		if result.exit_code != 0 {
			return none
		}
		return result.output
	}
}
