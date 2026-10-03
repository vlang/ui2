module ui2

fn test_ios_button_behavior_release_preserves_the_captured_action() {
	assert ios_button_behavior_release_action('original', 'replacement', true, true, false,
		true) == 'original'
	assert ios_button_behavior_release_action('original', '', true, true, false, true) == ''
	assert ios_button_behavior_release_action('original', 'replacement', false, true, false,
		true) == ''
	assert ios_button_behavior_release_action('original', 'replacement', true, false, false,
		true) == ''
	assert ios_button_behavior_release_action('original', 'replacement', true, true, true, true) == ''
	assert ios_button_behavior_release_action('original', 'replacement', true, true, false,
		false) == ''
	assert ios_button_behavior_release_action('', 'replacement', true, true, false, true) == ''
}

fn test_ios_button_behavior_capture_ignores_additional_touches() {
	assert ios_button_behavior_capture_action('original', 'replacement', 1, false) == 'original'
	assert ios_button_behavior_capture_action('original', 'replacement', 1, true) == 'original'
	assert ios_button_behavior_capture_action('stale', 'replacement', 0, true) == 'replacement'
	assert ios_button_behavior_capture_action('stale', 'replacement', 0, false) == ''
}
