module ui2

fn window_test_button(id string) Element {
	return Element{
		kind:    .button
		id:      id
		enabled: true
	}
}

fn test_stylesheet_apply_frame_noop_without_sheet() {
	clear_global_stylesheet()
	el := window_test_button('a')
	out := stylesheet_apply_frame(el, stylesheet_frame_env('', '', ''))
	assert out.id == 'a'
	assert out.box.bg == 0xffffff
}

fn test_stylesheet_global_applies_and_clears() {
	clear_global_stylesheet()
	set_global_stylesheet(parse_stylesheet('Button { background: #123456; }')!)
	out := stylesheet_apply_frame(window_test_button('a'), stylesheet_frame_env('', '',
		''))
	assert out.box.bg == 0x123456
	clear_global_stylesheet()
	plain := stylesheet_apply_frame(window_test_button('a'), stylesheet_frame_env('', '',
		''))
	assert plain.box.bg == 0xffffff
}

fn test_stylesheet_live_dpi_tracks_frames() {
	clear_global_stylesheet()
	env := StyleMatchEnv{ dpi: 2.5 }
	stylesheet_apply_frame(window_test_button('a'), env)
	assert stylesheet_live_dpi() == 2.5
	stylesheet_apply_frame(window_test_button('a'), StyleMatchEnv{})
	assert stylesheet_live_dpi() == 2.5
}

fn test_stylesheet_dark_mode_flag() {
	set_stylesheet_follow_system(false)
	set_stylesheet_dark(true)
	assert stylesheet_dark_mode()
	set_stylesheet_dark(false)
	assert !stylesheet_dark_mode()
	set_stylesheet_follow_system(true)
}

fn test_stylesheet_action_id_matches_state() {
	clear_global_stylesheet()
	set_global_stylesheet(parse_stylesheet('Button:hover { background: #123456; }')!)
	el := Element{
		kind:      .button
		id:        'x'
		action_id: 'go'
		enabled:   true
	}
	out := stylesheet_apply_frame(el, stylesheet_frame_env('go', '', ''))
	assert out.box.bg == 0x123456
	clear_global_stylesheet()
}
