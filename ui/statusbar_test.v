module ui2

fn test_statusbar_docks_and_lays_out_message_and_indicators() {
	bar := statusbar(
		id:         'status'
		area:       rect(0, 0, 400, 300)
		message:    'Ready'
		indicators: [
			StatusIndicator{ id: 'line', text: 'Ln 12' },
			StatusIndicator{ id: 'encoding', text: 'UTF-8', tooltip: 'Text encoding' },
		]
	)
	assert bar.kind == .view
	assert bar.id == 'status'
	assert bar.frame == rect(0, 272, 400, 28)
	assert bar.box.bg == 0xf5f5f5
	assert bar.box.border_top == 1
	assert bar.box.border_color == 0xcccccc
	assert bar.children.len == 3
	assert bar.children[0].id == 'status__message'
	assert bar.children[0].text == 'Ready'
	assert bar.children[0].frame == rect(10, 4, 254, 20)
	assert bar.children[1].frame == rect(274, 0, 59, 28)
	assert bar.children[1].children[0].text == 'Ln 12'
	assert bar.children[2].frame == rect(333, 0, 59, 28)
	assert bar.children[2].tooltip == 'Text encoding'
	validate_element_tree(bar) or { panic(err) }
}

fn test_statusbar_tracks_area_and_hides_indicators_before_message() {
	assert statusbar_content_area(rect(0, 0, 400, 300)) == rect(0, 0, 400, 272)
	assert statusbar_content_area(rect(0, 0, 400, 20)) == rect(0, 0, 400, 0)
	bar := statusbar(
		area:       rect(0, 0, 150, 200)
		message:    'Still visible'
		indicators: [StatusIndicator{ id: 'encoding', text: 'UTF-8' }]
	)
	assert bar.frame == rect(0, 172, 150, 28)
	assert bar.children.len == 1
	assert bar.children[0].text == 'Still visible'
}

fn test_statusbar_uses_window_bounds_by_default_and_accepts_style() {
	default_bar := statusbar(message: 'Ready')
	assert default_bar.frame == statusbar_frame(bounds())
	style := BoxStyle{
		bg: 0xe2e8f0
	}
	bar := statusbar(area: rect(0, 0, 400, 300), box: style)
	assert bar.box == style
}

fn test_statusbar_supports_labels_buttons_and_toggles() {
	bar := statusbar(
		area:       rect(0, 0, 480, 300)
		message:    'Ready'
		indicators: [
			StatusIndicator{ id: 'format', text: 'UTF-8' },
			StatusIndicator{ id: 'reset', text: 'Reset', action_id: 'reset_count' },
			StatusIndicator{
				id:        'grid'
				text:      'Grid on'
				action_id: 'toggle_grid'
				toggle:    true
				pressed:   true
				tooltip:   'Show or hide the grid'
			},
		]
	)
	assert bar.children[1].children[0].kind == .label
	assert bar.children[2].children[0].kind == .button
	assert bar.children[2].children[0].action_id == 'reset_count'
	assert bar.children[3].children[0].kind == .toggle_button
	assert bar.children[3].children[0].action_id == 'toggle_grid'
	assert bar.children[3].children[0].checked
	assert bar.children[3].children[0].tooltip == 'Show or hide the grid'
	validate_element_tree(bar) or { panic(err) }
}
