module main

import ui2

fn test_voice_memo_control_actions_are_safe_without_hardware() {
	assert !ui2.media_handle_control('ghost', ui2.media_record_action('ghost'))
	assert ui2.media_state('ghost') == .idle
	assert ui2.media_recording_elapsed('ghost') == -1.0
}
