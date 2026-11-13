module main

import os
import time
import ui2

const memo_width = 420
const memo_height = 260
const memo_id = 'memo'

@[heap]
pub struct VoiceMemoApp {
pub mut:
	path    string
	message string = 'Press Record, speak, then press Stop.'
}

const memo_state = &VoiceMemoApp{}

fn memo_output_path() string {
	return os.join_path(os.temp_dir(), 'ui2_voice_memo.wav')
}

fn build_memo_screen() ui2.Element {
	mut app := unsafe { memo_state }
	recording := ui2.media_state(memo_id) == .recording
	if recording {
		elapsed := ui2.media_recording_elapsed(memo_id)
		app.message = if elapsed >= 0 {
			'Recording ${ui2.media_time_format(elapsed)} …'
		} else {
			'Recording …'
		}
	}
	return ui2.view('root', ui2.rect(0, 0, memo_width, memo_height), ui2.BoxStyle{
		bg: 0xf1f5f9
	}, [
		ui2.media_recorder(
			id:          memo_id
			output_path: memo_output_path()
			frame:       ui2.rect(20, 20, 200, 40)
		) or {
			eprintln('recorder failed: ${err}')
			ui2.view('recorder_fallback', ui2.rect(0, 0, 0, 0), ui2.BoxStyle{}, [])
		},
		ui2.button('shoot', 'Screenshot', ui2.rect(230, 20, 170, 40), ui2.BoxStyle{}, ui2.TextStyle{
			size: 13
		}),
		ui2.label('message', app.message, ui2.rect(20, 76, 380, 20), ui2.TextStyle{
			size:  12
			color: 0x475569
		}),
		ui2.label('path', 'Take: ${app.path}', ui2.rect(20, 100, 380, 20), ui2.TextStyle{
			size:  11
			color: 0x94a3b8
		}),
		ui2.label('support', support_line(), ui2.rect(20, 124, 380, 20), ui2.TextStyle{
			size:  11
			color: 0x94a3b8
		}),
	])
}

fn support_line() string {
	mic := if ui2.media_capture_supported(.microphone) { 'mic ready' } else { 'no mic' }
	screen := if ui2.media_capture_supported(.screen) { 'screen ready' } else { 'no screen' }
	return 'Capture: ${mic}, ${screen}.'
}

// refresh_memo_while_recording repaints the elapsed readout until the take
// stops, mirroring the media player's playback loop.
fn refresh_memo_while_recording() {
	for _ in 0 .. 3600 {
		if ui2.media_state(memo_id) != .recording {
			return
		}
		ui2.request_refresh()
		time.sleep(500 * time.millisecond)
	}
	ui2.request_refresh()
}

fn handle_memo_event(event string) {
	mut app := unsafe { memo_state }
	if event == ui2.media_record_action(memo_id) {
		if ui2.media_state(memo_id) == .recording {
			if ui2.media_stop_recording(memo_id) {
				app.path = memo_output_path()
				app.message = 'Saved ${app.path}.'
			} else {
				app.message = 'Could not stop the take.'
			}
		} else {
			app.path = memo_output_path()
			if ui2.media_start_recording(memo_id, .microphone, app.path) {
				app.message = 'Recording …'
				spawn refresh_memo_while_recording()
			} else {
				app.message = 'Microphone unavailable on this machine.'
			}
		}
	} else if event == 'shoot' {
		shot_ext := $if windows { '.bmp' } $else { '.png' }
		shot := os.join_path(os.temp_dir(), 'ui2_screenshot${shot_ext}')
		if ui2.media_capture_screen(shot) {
			app.message = 'Screenshot saved to ${shot}.'
		} else {
			app.message = 'Screen capture is not available here.'
		}
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('Voice Memo', memo_width, memo_height, build_memo_screen, handle_memo_event)
}
