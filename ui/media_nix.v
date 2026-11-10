// Linux and BSD media through the small command-line tools the desktops
// already ship or package next to their sound servers — the same approach as
// clipboard_nix: no library is linked, players are spawned per session, and
// anything missing reports unsupported instead of failing.
//
// Transport is deliberately degraded here: CLI players expose no seek or
// position channel, so seeking is refused and duration reads -1. Pause uses
// SIGSTOP/SIGCONT, which freezes the player process in place.
@[has_globals]
module ui2

$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
	import os

	__global g_media_nix_players = map[string]&os.Process{}
	__global g_media_nix_recorders = map[string]&os.Process{}
	__global g_media_nix_paused = map[string]bool{}

	// media_nix_first_present picks the first installed tool: unit-testable
	// probing without touching the real players.
	fn media_nix_first_present(names []string) string {
		for name in names {
			if path := os.find_abs_path_of_executable(name) {
				return path
			}
		}
		return ''
	}

	fn media_nix_player() string {
		return media_nix_first_present(['aplay', 'paplay', 'pw-play'])
	}

	fn media_nix_recorder() string {
		return media_nix_first_present(['arecord', 'parecord'])
	}

	fn media_nix_screenshot() []string {
		for tool in [['grim'], ['gnome-screenshot', '-f'], ['scrot'], ['import', '-window', 'root']] {
			if path := os.find_abs_path_of_executable(tool[0]) {
				mut cmd := [path]
				cmd << tool[1..]
				return cmd
			}
		}
		return []
	}

	fn media_nix_stop_process(mut procs map[string]&os.Process, id string) {
		if mut proc := procs[id] {
			proc.signal_kill()
			proc.wait()
			proc.close()
			procs.delete(id)
		}
		g_media_nix_paused.delete(id)
	}

	fn native_media_supported(kind MediaKind) bool {
		if kind == .video {
			return false
		}
		return media_nix_player().len > 0
	}

	fn native_media_open(id string, kind MediaKind, src string) bool {
		if kind == .video || id.trim_space().len == 0 {
			return false
		}
		if media_nix_player().len == 0 {
			return false
		}
		return src.trim_space().len > 0 && os.exists(src)
	}

	fn native_media_play(id string) bool {
		if proc := g_media_nix_players[id] {
			if proc.is_alive() {
				if g_media_nix_paused[id] {
					proc.signal_continue()
					g_media_nix_paused.delete(id)
				}
				return true
			}
			media_nix_stop_process(mut g_media_nix_players, id)
		}
		session := media_session(id) or { return false }
		player := media_nix_player()
		if player.len == 0 || !os.exists(session.src) {
			return false
		}
		mut proc := os.new_process(player)
		proc.set_args([session.src])
		proc.run()
		g_media_nix_players[id] = proc
		return true
	}

	fn native_media_pause(id string) bool {
		if proc := g_media_nix_players[id] {
			if proc.is_alive() {
				proc.signal_stop()
				g_media_nix_paused[id] = true
				return true
			}
		}
		return false
	}

	fn native_media_stop(id string) bool {
		media_nix_stop_process(mut g_media_nix_players, id)
		return true
	}

	fn native_media_seek(_id string, _secs f64) bool {
		return false
	}

	fn native_media_set_volume(_id string, _volume f64) bool {
		return false
	}

	fn native_media_set_muted(_id string, _muted bool) bool {
		return false
	}

	fn native_media_set_rate(_id string, _rate f64) bool {
		return false
	}

	fn native_media_set_loop(_id string, _loop bool) bool {
		return false
	}

	fn native_media_close(id string) {
		media_nix_stop_process(mut g_media_nix_players, id)
		media_nix_stop_process(mut g_media_nix_recorders, id)
	}

	fn native_media_position(_id string) f64 {
		return -1.0
	}

	fn native_media_duration(_id string) f64 {
		return -1.0
	}

	fn native_media_state(id string) MediaState {
		if proc := g_media_nix_players[id] {
			if proc.is_alive() {
				return if g_media_nix_paused[id] { .paused } else { .playing }
			}
			return .ended
		}
		if _ := g_media_nix_recorders[id] {
			return .recording
		}
		return .idle
	}

	fn native_media_can_seek(_id string) bool {
		return false
	}

	fn native_media_attach(_id string, _parent voidptr, _x f64, _y f64, _w f64, _h f64) bool {
		return false
	}

	fn native_media_detach(_id string) {
	}

	fn native_media_capture_supported(source MediaSource) bool {
		if source == .microphone {
			return media_nix_recorder().len > 0
		}
		if source == .screen {
			return media_nix_screenshot().len > 0
		}
		return false
	}

	fn native_media_start_recording(id string, source MediaSource, output_path string) bool {
		if source != .microphone {
			return false
		}
		recorder := media_nix_recorder()
		if recorder.len == 0 {
			return false
		}
		media_nix_stop_process(mut g_media_nix_recorders, id)
		args := if recorder.ends_with('arecord') {
			['-f', 'cd', '-t', 'wav', output_path]
		} else {
			['--file-format=wav', output_path]
		}
		mut proc := os.new_process(recorder)
		proc.set_args(args)
		proc.run()
		g_media_nix_recorders[id] = proc
		return true
	}

	fn native_media_stop_recording(id string) bool {
		if _ := g_media_nix_recorders[id] {
			media_nix_stop_process(mut g_media_nix_recorders, id)
			return true
		}
		return false
	}

	fn native_media_capture_screen(output_path string) bool {
		cmd := media_nix_screenshot()
		if cmd.len == 0 {
			return false
		}
		mut argv := cmd.clone()
		argv << output_path
		return os.system_args(argv) == 0
	}
}
