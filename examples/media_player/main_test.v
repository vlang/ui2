module main

import ui2

fn test_media_player_control_actions_round_trip_without_backend() {
	// Unknown sessions consume nothing and touch no backend.
	assert !ui2.media_handle_control('ghost', ui2.media_play_action('ghost'))
	assert !ui2.media_handle_control('ghost', ui2.media_toggle_action('ghost'))
	assert ui2.media_time_format(-1) == '--:--'
	assert ui2.media_source_for_src('C:\\clips\\intro.mp4') == .file
}
