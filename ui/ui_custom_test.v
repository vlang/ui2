module ui2

$if ui2_custom_rendering ? {
	fn custom_test_key_handler(_key string) {}

	fn custom_test_scroll_handler(_id string) {}

	fn custom_test_drop_handler(_event DropEvent) {}

	fn test_custom_desktop_backend_defaults() {
		assert bounds() == Rect{
			width: 800
			height: 600
		}
		assert control_support(.button) == .supported
		assert control_support(.text_field) == .supported
		assert control_support(.dropdown) == .partial
		assert control_support(.text_area) == .partial
	}

	fn test_custom_desktop_backend_exposes_desktop_hooks() {
		on_key(custom_test_key_handler)
		on_scroll(custom_test_scroll_handler)
		on_drop(custom_test_drop_handler)
		request_refresh()
		refresh_element('missing', Element{})
		insert_text_area_text('missing', 'text')
		scroll_to_rect('missing', 0, 0, 10, 10)
		assert scroll_offset('missing') == 0
		assert text_area_runs('missing').len == 0
		assert text_area_format_state('missing') == TextFormatState{}
		assert !clipboard_has_image()
		assert !save_clipboard_image_png('unused.png')
		quit()
	}

	fn test_custom_text_editor_replaces_owned_state_after_caret_moves() {
		g_text_values = map[string]string{}
		g_text_props = map[string]string{}
		g_text_editors = map[string]TextEditor{}
		g_text_kinds = map[string]Kind{}
		g_active_fields = map[string]bool{
			'field': true
		}
		g_focused_field = 'field'
		replace_text_value('field', 'abc')
		replace_text_editor('field', text_editor('abc'.clone()))
		handle_key_down(.left)
		handle_key_down(.backspace)
		handle_char_input(`x`)
		assert text('field') == 'axc'
		forget_text_state('field')
		g_active_fields = map[string]bool{}
		g_focused_field = ''
	}

	fn test_custom_pointer_event_ids_are_normalized() {
		assert pointer_event_id('down', 'surface', 20, 30) == 'pointer:down:surface:20.0:30.0'
		assert pointer_event_id('drag', 'surface', 40, 50) == 'pointer:drag:surface:40.0:50.0'
		assert pointer_event_id('up', 'surface', 40, 50) == 'pointer:up:surface:40.0:50.0'
	}

	fn test_custom_button_images_match_native_arrangements() {
		image_only := button_image_layout(30, 28, '', 'symbol:gearshape')
		assert image_only.visible
		assert image_only.image == rect(6, 5, 18, 18)
		assert image_only.text.width == 0

		compact_image_only := button_image_layout(20, 17, '', 'symbol:scissors')
		assert compact_image_only.image == rect(3.5, 2, 13, 13)

		tall_image_only := button_image_layout(44, 58, '', '/tmp/paste.png')
		assert tall_image_only.image == rect(6, 13, 32, 32)

		compact := button_image_layout(100, 24, 'Open', '/tmp/open.png')
		assert compact.image == rect(5, 5.5, 13, 13)
		assert compact.text == rect(22, 0, 74, 24)
		assert compact.has_title_area()

		narrow_compact := button_image_layout(26, 24, 'Open', '/tmp/open.png')
		assert narrow_compact.text.width == 0
		assert !narrow_compact.has_title_area()

		tall := button_image_layout(60, 62, 'Paste', '/tmp/paste.png')
		assert tall.image == rect(14, 4, 32, 32)
		assert tall.text == rect(2, 39, 56, 20)

		text_only := button_image_layout(80, 28, 'Normal', '')
		assert !text_only.visible
		assert text_only.text == rect(0, 0, 80, 28)
	}

	fn test_custom_renderer_has_portable_system_symbol_fallbacks() {
		assert system_symbol_fallback('arrow.uturn.backward') == ''
		assert system_symbol_fallback('gearshape') == ''
		assert system_symbol_fallback('magnifyingglass') == ''
		assert system_symbol_fallback('xmark') == ''
		assert system_symbol_fallback('future.symbol') == ''
	}

	fn test_custom_text_navigation_uses_the_platform_primary_modifier() {
		assert !text_navigation_primary_modifier(false, false, false)
		$if macos {
			assert !text_navigation_primary_modifier(true, false, false)
			assert text_navigation_primary_modifier(false, false, true)
			assert text_navigation_word_modifier(false, true)
			assert !text_navigation_word_modifier(true, false)
			assert text_navigation_boundary_modifier(true)
		} $else {
			assert text_navigation_primary_modifier(true, false, false)
			assert !text_navigation_primary_modifier(true, true, false)
			assert text_navigation_word_modifier(true, false)
			assert !text_navigation_word_modifier(true, true)
			assert !text_navigation_boundary_modifier(true)
		}
	}

	fn test_custom_slider_pointer_value_uses_range_step_and_orientation() {
		horizontal := HitTarget{
			slider: true
			slider_frame: rect(10, 20, 120, 30)
			slider_padding: 10
			slider_spec: SliderSpec{
				min: -20
				max: 80
				step: 5
			}
		}
		assert slider_target_value(horizontal, 70, 35) == 30

		vertical := HitTarget{
			...horizontal
			slider_frame: rect(10, 20, 30, 120)
			slider_spec: SliderSpec{
				...horizontal.slider_spec
				orientation: .vertical
			}
		}
		assert slider_target_value(vertical, 25, 30) == 80
		assert slider_target_value(vertical, 25, 130) == -20
	}

	fn test_custom_slider_value_api_only_updates_mounted_controls() {
		g_slider_values = map[string]f64{}
		g_slider_specs = map[string]SliderSpec{
			'volume': SliderSpec{
				min: -20
				max: 80
			}
		}
		g_active_sliders = map[string]bool{
			'volume': true
		}
		set_slider_value('volume', 120)
		set_slider_value('missing', 40)
		assert slider_value('volume') == 80
		assert slider_value('missing') == 0
		g_slider_values = map[string]f64{}
		g_slider_specs = map[string]SliderSpec{}
		g_active_sliders = map[string]bool{}
	}

	fn test_custom_switch_tap_and_drag_update_live_state() {
		g_switch_values = map[string]bool{
			'network': false
		}
		g_active_switches = map[string]bool{
			'network': true
		}
		target := HitTarget{
			id: 'network'
			action_id: 'network_changed'
			x: 10
			y: 20
			w: 80
			h: 32
			switch_control: true
		}
		g_hit_targets = [target]
		handle_touch_down(20, 30)
		handle_touch_up(20, 30)
		assert switch_active('network')
		set_switch_active('network', false)
		handle_touch_down(20, 30)
		handle_touch_move(80, 30)
		handle_touch_up(80, 30)
		assert switch_active('network')
		set_switch_active('network', false)
		assert !switch_active('network')
		set_switch_active('network', true)
		set_switch_active('missing', true)
		assert switch_active('network')
		assert !switch_active('missing')
		g_switch_values = map[string]bool{}
		g_switch_declared = map[string]bool{}
		g_active_switches = map[string]bool{}
		g_hit_targets = []HitTarget{}
		g_touch = TouchState{}
	}

	fn test_custom_checkbox_tap_updates_live_checked_state() {
		g_checkbox_values = map[string]bool{
			'newsletter': false
		}
		g_active_checkboxes = map[string]bool{
			'newsletter': true
		}
		g_hit_targets = [HitTarget{
			id: 'newsletter'
			action_id: 'newsletter_changed'
			x: 10
			y: 20
			w: 120
			h: 28
			checkbox: true
		}]
		handle_touch_down(20, 30)
		handle_touch_up(20, 30)
		assert checkbox_checked('newsletter')
		set_checkbox_checked('newsletter', false)
		set_checkbox_checked('missing', true)
		assert !checkbox_checked('newsletter')
		assert !checkbox_checked('missing')
		g_checkbox_values = map[string]bool{}
		g_checkbox_declared = map[string]bool{}
		g_active_checkboxes = map[string]bool{}
		g_hit_targets = []HitTarget{}
		g_touch = TouchState{}
	}

	fn test_custom_checkbox_drag_preserves_scrolling_without_toggling() {
		g_checkbox_values = map[string]bool{
			'newsletter': false
		}
		g_active_checkboxes = map[string]bool{
			'newsletter': true
		}
		g_hit_targets = [HitTarget{
			id: 'newsletter'
			x: 10
			y: 60
			w: 120
			h: 28
			checkbox: true
		}]
		g_scroll_areas = map[string]Rect{
			'form': rect(0, 0, 160, 160)
		}
		g_scroll_viewports = map[string]Rect{
			'form': rect(0, 0, 160, 160)
		}
		g_scroll_order = ['form']
		g_scroll_content_h = map[string]f64{
			'form': 320
		}
		g_scroll_offsets = map[string]f64{}
		handle_touch_down(20, 70)
		handle_touch_move(20, 20)
		handle_touch_up(20, 20)
		assert scroll_offset('form') == 50
		assert !checkbox_checked('newsletter')
		g_checkbox_values = map[string]bool{}
		g_checkbox_declared = map[string]bool{}
		g_active_checkboxes = map[string]bool{}
		g_hit_targets = []HitTarget{}
		reset_scroll_frame()
		g_scroll_content_h = map[string]f64{}
		g_scroll_offsets = map[string]f64{}
		g_touch = TouchState{}
	}

	fn test_custom_toggle_button_updates_live_pressed_state() {
		g_toggle_values = map[string]bool{
			'bold': false
		}
		g_active_toggles = map[string]bool{
			'bold': true
		}
		g_toggle_groups = map[string]string{
			'bold': ''
		}
		g_toggle_allow_no_selection = map[string]bool{
			'bold': true
		}
		g_hit_targets = [HitTarget{
			id: 'bold'
			action_id: 'bold_changed'
			x: 10
			y: 20
			w: 80
			h: 32
			toggle_button: true
		}]
		handle_touch_down(20, 30)
		handle_touch_up(20, 30)
		assert toggle_button_pressed('bold')
		set_toggle_button_pressed('bold', false)
		set_toggle_button_pressed('missing', true)
		assert !toggle_button_pressed('bold')
		assert !toggle_button_pressed('missing')
		g_toggle_values = map[string]bool{}
		g_toggle_declared = map[string]bool{}
		g_toggle_groups = map[string]string{}
		g_toggle_allow_no_selection = map[string]bool{}
		g_active_toggles = map[string]bool{}
		g_hit_targets = []HitTarget{}
		g_touch = TouchState{}
	}

	fn test_custom_toggle_button_groups_are_exclusive() {
		g_toggle_values = map[string]bool{
			'left':  true
			'right': false
		}
		g_toggle_groups = map[string]string{
			'left':  'alignment'
			'right': 'alignment'
		}
		g_toggle_allow_no_selection = map[string]bool{
			'left':  false
			'right': false
		}
		g_active_toggles = map[string]bool{
			'left':  true
			'right': true
		}
		commit_toggle_button(HitTarget{
			id: 'right'
			toggle_button: true
			toggle_group: 'alignment'
			toggle_allow_no_selection: false
		})
		assert !toggle_button_pressed('left')
		assert toggle_button_pressed('right')
		commit_toggle_button(HitTarget{
			id: 'right'
			toggle_button: true
			toggle_group: 'alignment'
			toggle_allow_no_selection: false
		})
		assert toggle_button_pressed('right')
		commit_toggle_button(HitTarget{
			id: 'right'
			toggle_button: true
			toggle_group: 'alignment'
			toggle_allow_no_selection: true
		})
		assert !toggle_button_pressed('left')
		assert !toggle_button_pressed('right')
		set_toggle_button_pressed('left', true)
		assert toggle_button_pressed('left')
		assert !toggle_button_pressed('right')
		mut members := toggle_button_group_members('left')
		members.sort()
		assert members == ['left', 'right']
		g_toggle_values = map[string]bool{}
		g_toggle_declared = map[string]bool{}
		g_toggle_groups = map[string]string{}
		g_toggle_allow_no_selection = map[string]bool{}
		g_active_toggles = map[string]bool{}
	}

	fn test_custom_dropdown_popup_opens_below_its_control() {
		row_height := dropdown_row_height(TextStyle{})
		assert row_height == 28
		frame := dropdown_popup_frame(rect(16, 40, 200, 42), 3, row_height, rect(0, 0, 320, 400))
		assert frame.x == 16
		assert frame.y == 86
		assert frame.width == 200
		assert frame.height == 3 * row_height + 8
	}

	fn test_custom_dropdown_popup_flips_above_when_more_rows_fit() {
		frame := dropdown_popup_frame(rect(16, 150, 200, 30), 4, 28, rect(0, 0, 320, 220))
		assert frame.height == 4 * 28 + 8
		assert frame.y == 26
	}

	fn test_custom_dropdown_popup_shows_whole_rows_inside_the_window() {
		frame := dropdown_popup_frame(rect(150, 60, 120, 30), 6, 28, rect(0, 0, 200, 160))
		assert frame.height == 28 + 8
		assert frame.y == 94
		assert frame.x == 76
	}

	fn test_custom_dropdown_scroll_reveals_the_selected_row() {
		g_dropdown_popup = DropdownPopup{
			id: 'menu'
			options: ['a', 'b', 'c', 'd', 'e', 'f']
			row_height: 28
			height: 2 * 28 + 8
			max_scroll: 4 * 28
			selected: 5
		}
		g_dropdown_scroll = 0
		reveal_dropdown_row(5)
		assert g_dropdown_scroll == 4 * 28
		reveal_dropdown_row(0)
		assert g_dropdown_scroll == 0
		assert clamped_dropdown_scroll(1000) == 4 * 28
		assert clamped_dropdown_scroll(-10) == 0
		close_dropdown()
		assert g_dropdown_scroll == 0
		assert g_dropdown_popup.options.len == 0
	}

	fn test_custom_dropdown_click_opens_a_list_instead_of_cycling() {
		close_dropdown()
		target := HitTarget{
			id: 'menu-click'
			action_id: 'menu-change'
			dropdown: true
			options: ['One', 'Two', 'Three']
		}
		open_dropdown(target)
		assert g_open_dropdown == 'menu-click'
		assert text('menu-click') == ''
		select_dropdown_option(HitTarget{
			...target
			dropdown_option: true
			option_index: 2
		})
		assert g_open_dropdown == ''
		assert text('menu-click') == 'Three'
	}

	fn test_custom_dropdown_without_an_id_only_reports_the_tap() {
		close_dropdown()
		open_dropdown(HitTarget{
			action_id: 'menu-change'
			dropdown: true
			options: ['One']
		})
		assert g_open_dropdown == ''
	}

	fn test_custom_dropdown_keys_move_the_highlight_and_commit() {
		close_dropdown()
		g_open_dropdown = 'menu-keys'
		g_dropdown_popup = DropdownPopup{
			id: 'menu-keys'
			action_id: 'menu-change'
			options: ['One', 'Two', 'Three']
			row_height: 28
			height: 3 * 28 + 8
			mounted: true
		}
		assert handle_dropdown_key(.down)
		assert g_dropdown_hover == 0
		assert handle_dropdown_key(.up)
		assert g_dropdown_hover == 2
		assert handle_dropdown_key(.tab) == false
		assert handle_dropdown_key(.enter)
		assert g_open_dropdown == ''
		assert text('menu-keys') == 'Three'
	}

	// The control sits at 32,70 296x42 and the list rows the popup registers on
	// the next frame start at y 120, matching the dropdown example's layout.
	fn custom_test_dropdown_targets(id string) []HitTarget {
		options := ['One', 'Two', 'Three']
		mut targets := [
			HitTarget{
				id: id
				action_id: 'menu-change'
				x: 32
				y: 70
				w: 296
				h: 42
				dropdown: true
				options: options
			},
		]
		for index in 0 .. options.len {
			targets << HitTarget{
				id: id
				action_id: 'menu-change'
				x: 32
				y: 120 + f64(index) * 28
				w: 296
				h: 28
				dropdown_option: true
				option_index: index
				options: options
			}
		}
		return targets
	}

	fn test_custom_dropdown_pointer_flow_picks_a_row_from_the_list() {
		close_dropdown()
		targets := custom_test_dropdown_targets('menu-pick')
		g_hit_targets = [targets[0]]
		handle_touch_down(100, 90)
		handle_touch_up(100, 90)
		assert g_open_dropdown == 'menu-pick'
		assert text('menu-pick') == ''
		g_hit_targets = targets.clone()
		handle_touch_down(100, 160)
		assert g_dropdown_hover == 1
		handle_touch_up(100, 160)
		assert g_open_dropdown == ''
		assert text('menu-pick') == 'Two'
		g_hit_targets = []HitTarget{}
	}

	fn test_custom_dropdown_pointer_flow_dismisses_on_an_outside_click() {
		close_dropdown()
		targets := custom_test_dropdown_targets('menu-dismiss')
		g_hit_targets = [targets[0]]
		handle_touch_down(100, 90)
		handle_touch_up(100, 90)
		assert g_open_dropdown == 'menu-dismiss'
		g_hit_targets = targets.clone()
		handle_touch_down(100, 300)
		assert g_dropdown_hover == -1
		handle_touch_up(100, 300)
		assert g_open_dropdown == ''
		assert text('menu-dismiss') == ''
		g_hit_targets = [targets[0]]
		handle_touch_down(100, 90)
		handle_touch_up(100, 90)
		assert g_open_dropdown == 'menu-dismiss'
		handle_touch_down(100, 90)
		handle_touch_up(100, 90)
		assert g_open_dropdown == ''
		assert text('menu-dismiss') == ''
		g_hit_targets = []HitTarget{}
	}

	fn test_custom_dropdown_escape_closes_the_list() {
		close_dropdown()
		g_open_dropdown = 'menu-escape'
		g_dropdown_popup = DropdownPopup{
			id: 'menu-escape'
			options: ['One', 'Two']
			row_height: 28
			height: 2 * 28 + 8
			mounted: true
		}
		assert handle_dropdown_key(.escape)
		assert g_open_dropdown == ''
		assert text('menu-escape') == ''
	}

	fn test_custom_button_press_state_follows_the_pointer() {
		g_touch = TouchState{}
		assert !touch_is_held_inside(10, 10, 100, 30)
		g_touch = TouchState{
			down: true
			start_x: 20
			start_y: 20
			current_x: 20
			current_y: 20
		}
		assert touch_is_held_inside(10, 10, 100, 30)
		// Held down, but dragged off the button.
		g_touch.current_x = 300
		assert !touch_is_held_inside(10, 10, 100, 30)
		// A press that began elsewhere does not light up what it passes over.
		g_touch = TouchState{
			down: true
			start_x: 300
			start_y: 20
			current_x: 20
			current_y: 20
		}
		assert !touch_is_held_inside(10, 10, 100, 30)
		g_touch = TouchState{}
	}
}

fn test_text_field_selection_text_uses_rune_offsets() {
	before, selected := text_field_selection_text('a🙂bc', TextSelection{
		anchor: 4
		caret: 1
	})
	assert before == 'a'
	assert selected == '🙂bc'
}

fn test_text_field_selection_origin_respects_text_alignment() {
	assert text_field_aligned_text_origin(10, 100, 40, .left) == 10
	assert text_field_aligned_text_origin(10, 100, 40, .center) == 40
	assert text_field_aligned_text_origin(10, 100, 40, .right) == 70
}
