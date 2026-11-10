module main

import time
import ui2

const player_width = 560
const player_height = 460

@[heap]
pub struct MediaPlayerApp {
pub mut:
	src     string = 'https://download.samplelib.com/mp4/sample-5s.mp4'
	message string = 'Enter a file path or URL, then press Play.'
}

const player_id = 'clip'
const player_state = &MediaPlayerApp{}

fn build_media_screen() ui2.Element {
	mut app := unsafe { player_state }
	state := ui2.media_state(player_id)
	app.message = match state {
		.playing { 'Playing ${ui2.media_time_format(ui2.media_position(player_id))} …' }
		.paused { 'Paused at ${ui2.media_time_format(ui2.media_position(player_id))}.' }
		.ended { 'Finished. Press Play to watch again.' }
		.error { 'Cannot play this source: ${ui2.media_error(player_id)}' }
		else { app.message }
	}
	return ui2.view('root', ui2.rect(0, 0, player_width, player_height), ui2.BoxStyle{
		bg: 0xf1f5f9
	}, [
		ui2.label('src_label', 'Source (file path or URL)', ui2.rect(20, 12, 300, 20), ui2.TextStyle{
			size: 13
		}),
		ui2.text_field_with_change('src_field', 'https://… or C:/…', app.src, ui2.rect(20, 34, 380, 32), ui2.BoxStyle{}, ui2.TextStyle{
			size: 13
		}, ui2.keyboard_default),
		ui2.button('load', 'Load', ui2.rect(410, 34, 130, 32), ui2.BoxStyle{}, ui2.TextStyle{
			size: 13
		}),
		ui2.video(player_id, app.src, ui2.rect(20, 78, 520, 260)),
		ui2.media_controls(id: player_id, frame: ui2.rect(20, 348, 520, 40)) or {
			eprintln('media controls failed: ${err}')
			ui2.view('controls_fallback', ui2.rect(0, 0, 0, 0), ui2.BoxStyle{}, [])
		},
		ui2.label('message', app.message, ui2.rect(20, 396, 520, 20), ui2.TextStyle{
			size:  12
			color: 0x475569
		}),
		ui2.label('support', support_line(), ui2.rect(20, 418, 520, 20), ui2.TextStyle{
			size:  11
			color: 0x94a3b8
		}),
	])
}

fn support_line() string {
	video := if ui2.media_playback_supported(.video) { 'video+audio' } else { 'audio-only' }
	mic := if ui2.media_capture_supported(.microphone) { '+mic' } else { '' }
	screen := if ui2.media_capture_supported(.screen) { '+screen' } else { '' }
	return 'This platform plays ${video}${mic}${screen}.'
}

// refresh_media_while_playing repaints the position readout a few times per
// second while the clip runs, like the timer example's refresh loop.
fn refresh_media_while_playing() {
	for _ in 0 .. 240 {
		if ui2.media_state(player_id) != .playing {
			return
		}
		ui2.request_refresh()
		time.sleep(250 * time.millisecond)
	}
	ui2.request_refresh()
}

fn handle_media_event(event string) {
	mut app := unsafe { player_state }
	if ui2.media_handle_control(player_id, event) {
		if event == ui2.media_toggle_action(player_id)
			|| event == ui2.media_play_action(player_id) {
			spawn refresh_media_while_playing()
		}
		ui2.refresh()
		return
	}
	if event == 'load' {
		app.src = ui2.text('src_field')
		ui2.media_close(player_id)
		app.message = 'Loaded ${app.src}. Press Play.'
	} else if event == 'src_field' {
		app.src = ui2.text('src_field')
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('Media Player', player_width, player_height, build_media_screen, handle_media_event)
}
