module ui2

fn tab_test_tabs(count int) []TabbedPanelTab {
	mut tabs := []TabbedPanelTab{cap: count}
	for index in 0 .. count {
		tabs << TabbedPanelTab{
			id: 'tab_${index}'
			title: 'Tab ${index}'
			action_id: 'select_${index}'
			content: view('content_${index}', rect(0, 0, 1, 1), BoxStyle{}, [])
		}
	}
	return tabs
}

fn test_tabbed_panel_positions_top_headers_and_content() {
	geometry := tabbed_panel_geometry(
		frame: rect(0, 0, 360, 200)
		tab_width: 100
		tabs: tab_test_tabs(3)
	) or { panic(err) }
	assert geometry.content == rect(0, 40, 360, 160)
	assert geometry.headers == [rect(0, 0, 100, 40), rect(100, 0, 100, 40), rect(200, 0, 100, 40)]
}

fn test_tabbed_panel_supports_bottom_right_alignment() {
	geometry := tabbed_panel_geometry(
		frame: rect(0, 0, 360, 200)
		tab_position: .bottom_right
		tab_width: 100
		tabs: tab_test_tabs(3)
	) or { panic(err) }
	assert geometry.content == rect(0, 0, 360, 160)
	assert geometry.headers[0] == rect(60, 160, 100, 40)
	assert geometry.headers[2] == rect(260, 160, 100, 40)
}

fn test_tabbed_panel_supports_vertical_mid_alignment() {
	geometry := tabbed_panel_geometry(
		frame: rect(0, 0, 300, 360)
		tab_position: .right_mid
		tab_height: 40
		tab_width: 80
		tabs: tab_test_tabs(3)
	) or { panic(err) }
	assert geometry.content == rect(0, 0, 260, 360)
	assert geometry.headers[0] == rect(260, 60, 40, 80)
	assert geometry.headers[2] == rect(260, 220, 40, 80)
}

fn test_tabbed_panel_distributes_zero_width_headers() {
	geometry := tabbed_panel_geometry(
		frame: rect(0, 0, 300, 160)
		tab_width: 0
		tabs: tab_test_tabs(3)
	) or { panic(err) }
	assert geometry.headers[0].width == 100
	assert geometry.headers[2].x == 200
}

fn test_tabbed_panel_selects_content_and_styles_active_header() {
	config := TabbedPanelConfig{
		id: 'settings'
		frame: rect(0, 0, 300, 180)
		current: 1
		tab_width: 100
		header_box: BoxStyle{ bg: 0xeeeeee }
		active_header_box: BoxStyle{ bg: 0x2563eb }
		tabs: tab_test_tabs(3)
	}
	panel := tabbed_panel(config) or { panic(err) }
	assert panel.children[0].id == 'content_1'
	assert panel.children[2].box.bg == u32(0x2563eb)
	assert panel.children[2].accessibility_value == 'selected'
	assert panel.children[2].action_id == 'select_1'
}
