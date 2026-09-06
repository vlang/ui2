// vfmt off
@[has_globals]
module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	__global scroll_test_events = []string{}
	__global scroll_test_measurements = 0

	fn reset_scroll_test_state() {
		reset_scroll_frame()
		g_scroll_offsets = map[string]f64{}
		g_scroll_content_h = map[string]f64{}
		g_active_scrolls = map[string]bool{}
		g_active_fields = map[string]bool{}
		g_text_values = map[string]string{}
		g_text_props = map[string]string{}
		g_text_kinds = map[string]Kind{}
		g_text_editors = map[string]TextEditor{}
		g_text_area_layouts = map[string]TextAreaLayout{}
		g_hit_targets = []HitTarget{}
		g_touch = TouchState{}
		g_focused_field = ''
		g_scroll_handler = ScrollFn(unsafe { nil })
		g_event_handler = EventFn(unsafe { nil })
		scroll_test_events = []string{}
		scroll_test_measurements = 0
		close_dropdown()
	}

	fn scroll_test_width(line string) f64 {
		scroll_test_measurements++
		return f64(line.runes().len) * 10
	}

	fn scroll_test_changed(id string) {
		scroll_test_events << id
	}

	fn test_text_area_wraps_words_and_preserves_explicit_blank_lines() {
		reset_scroll_test_state()
		assert wrap_text_area_lines('one two three', 70, scroll_test_width) == ['one two', 'three']
		assert wrap_text_area_lines('one\r\n\r\ntwo\n', 100, scroll_test_width) == ['one', '', 'two', '']
		assert wrap_text_area_lines('', 100, scroll_test_width) == ['']
		assert wrap_text_area_lines('one\ttwo', 30, scroll_test_width) == ['one', 'two']
	}

	fn test_text_area_wraps_long_words_without_splitting_utf8_bytes() {
		reset_scroll_test_state()
		assert wrap_text_area_lines('é界🙂abcd', 30, scroll_test_width) == ['é界🙂', 'abc', 'd']
		assert wrap_text_area_lines('é界', 1, scroll_test_width) == ['é', '界']
		assert wrap_text_area_lines('abc', 0, scroll_test_width).len == 0
		assert wrap_text_area_lines('abc', -1, scroll_test_width).len == 0
	}

	fn test_text_area_does_not_limit_content_to_one_thousand_lines() {
		reset_scroll_test_state()
		mut lines := []string{}
		for index in 0 .. 1105 {
			lines << 'line ${index}'
		}
		assert wrap_text_area_lines(lines.join('\n'), 500, scroll_test_width) == lines
	}

	fn test_text_area_wrap_cache_tracks_text_width_and_font_changes() {
		reset_scroll_test_state()
		style := TextStyle{}
		assert text_area_lines('text', 'abcdef', 30, style, 15, scroll_test_width) == ['abc', 'def']
		measured := scroll_test_measurements
		assert text_area_lines('text', 'abcdef', 30, style, 15, scroll_test_width) == ['abc', 'def']
		assert scroll_test_measurements == measured
		assert text_area_lines('text', 'abcdef', 60, style, 15, scroll_test_width) == ['abcdef']
		assert text_area_lines('text', 'new', 60, style, 15, scroll_test_width) == ['new']
		before_font := scroll_test_measurements
		text_area_lines('text', 'new', 60, TextStyle{size: 20}, 20, scroll_test_width)
		assert scroll_test_measurements > before_font
	}

	fn test_text_area_content_is_top_aligned_and_clipped_inside_its_pane() {
		content := text_area_content_rect(rect(20, 100, 200, 216), 12, true)
		assert content == rect(32, 108, 176, 200)
		first, last := visible_text_area_rows(100, content.y, 20, 0, content)
		assert first == 0
		assert last == 10
		bottom_first, bottom_last := visible_text_area_rows(100, content.y, 20, 1800, content)
		assert bottom_first == 90
		assert bottom_last == 100
		parent_clip := intersect_rect(content, rect(0, 138, 150, 70))
		assert parent_clip == rect(32, 138, 118, 70)
		clipped_first, clipped_last := visible_text_area_rows(100, content.y, 20, 0, parent_clip)
		assert clipped_first == 1
		assert clipped_last == 5
		empty_first, empty_last := visible_text_area_rows(100, content.y, 20, 0, Rect{})
		assert empty_first == 0
		assert empty_last == 0
		small := text_area_content_rect(rect(0, 0, 10, 10), 12, true)
		assert small.width == 0
		assert small.height == 0
	}

	fn scroll_test_panes() {
		clip := rect(0, 0, 300, 200)
		// Read-only text areas register exactly like editable areas: registration
		// is outside the editable hit-target branch in render_element.
		register_scroll_view('info', rect(0, 0, 100, 100), clip, 400, true, true, false)
		register_scroll_view('text', rect(120, 0, 100, 100), clip, 1000, true, true, false)
	}

	fn test_readonly_panes_scroll_independently_with_wheel_and_drag() {
		reset_scroll_test_state()
		scroll_test_panes()
		on_scroll(scroll_test_changed)
		handle_mouse_scroll(150, 50, -2)
		assert scroll_offset('text') == 96
		assert scroll_offset('info') == 0
		handle_mouse_scroll(50, 50, -1)
		assert scroll_offset('info') == 48
		handle_mouse_scroll(110, 50, -1)
		assert scroll_offset('info') == 48
		assert scroll_offset('text') == 96
		handle_touch_down(150, 80)
		handle_touch_move(150, 30)
		handle_touch_up(150, 30)
		assert scroll_offset('text') == 146
		assert scroll_offset('info') == 48
		assert g_focused_field == ''
		assert scroll_test_events == ['text', 'info', 'text']
	}

	fn test_text_area_scroll_clamps_at_both_ends() {
		reset_scroll_test_state()
		scroll_test_panes()
		on_scroll(scroll_test_changed)
		handle_mouse_scroll(150, 50, -1000)
		assert scroll_offset('text') == 900
		handle_mouse_scroll(150, 50, -1000)
		assert scroll_test_events.len == 1
		handle_mouse_scroll(150, 50, 1000)
		assert scroll_offset('text') == 0
		handle_mouse_scroll(150, 50, 1000)
		assert scroll_test_events == ['text', 'text']
	}

	fn test_text_area_scroll_survives_rebuild_and_clamps_after_resize_or_edit() {
		reset_scroll_test_state()
		scroll_test_panes()
		handle_mouse_scroll(150, 50, -2)
		reset_scroll_frame()
		clip := rect(0, 0, 500, 500)
		assert register_scroll_view('text', rect(120, 0, 200, 200), clip, 1000, true, true, false) == 96
		on_scroll(scroll_test_changed)
		reset_scroll_frame()
		assert register_scroll_view('text', rect(120, 0, 200, 950), clip, 1000, true, true, false) == 50
		reset_scroll_frame()
		assert register_scroll_view('text', rect(120, 0, 200, 950), clip, 30, true, true, false) == 0
		assert scroll_test_events == ['text', 'text']
	}

	fn test_text_area_scroll_hit_testing_uses_visible_clip_and_inner_first_order() {
		reset_scroll_test_state()
		clip := rect(0, 0, 300, 300)
		register_scroll_view('outer', clip, clip, 1000, true, true, false)
		register_scroll_view('inner', rect(20, 20, 100, 200), rect(0, 0, 300, 100), 1000,
			true, true, false)
		assert scroll_maximum('inner') == 800
		assert g_scroll_areas['inner'] == rect(20, 20, 100, 80)
		handle_mouse_scroll(50, 50, -1)
		assert scroll_offset('inner') == 48
		assert scroll_offset('outer') == 0
		handle_mouse_scroll(50, 150, -1)
		assert scroll_offset('outer') == 48
		assert scroll_offset('inner') == 48
	}

	fn test_short_disabled_and_hidden_scrollbar_panes() {
		reset_scroll_test_state()
		frame := rect(0, 0, 100, 100)
		register_scroll_view('short', frame, frame, 50, true, true, false)
		on_scroll(scroll_test_changed)
		handle_mouse_scroll(50, 50, -1)
		assert scroll_offset('short') == 0
		assert scroll_test_events.len == 0
		reset_scroll_frame()
		register_scroll_view('disabled', frame, frame, 1000, false, true, false)
		assert scroll_hit_test(50, 50) == ''
		reset_scroll_frame()
		register_scroll_view('hidden-bar', frame, frame, 1000, true, false, false)
		assert 'hidden-bar' !in g_scrollbar_geometries
		handle_mouse_scroll(50, 50, -0.5)
		assert scroll_offset('hidden-bar') == 24
	}

	fn test_scrollbar_geometry_matches_the_scroll_range() {
		frame := rect(0, 0, 100, 100)
		top := scrollbar_geometry(frame, 1000, 0, false)
		assert top.track == rect(91, 4, 5, 92)
		assert top.thumb == rect(91, 4, 5, 28)
		bottom := scrollbar_geometry(frame, 1000, 900, false)
		assert bottom.thumb.y + bottom.thumb.height == bottom.track.y + bottom.track.height
		assert scrollbar_geometry(frame, 50, 0, false) == ScrollbarGeometry{}
		persistent := scrollbar_geometry(frame, 50, 0, true)
		assert persistent.track == persistent.thumb
		assert scrollbar_geometry(rect(0, 0, 5, 5), 1000, 0, true) == ScrollbarGeometry{}
	}

	fn test_scrollbar_thumb_drag_and_track_click_reach_the_bottom() {
		reset_scroll_test_state()
		frame := rect(0, 0, 100, 100)
		register_scroll_view('text', frame, frame, 1000, true, true, false)
		handle_touch_down(94, 10)
		assert g_touch.scrollbar_drag
		handle_touch_move(94, 74)
		handle_touch_up(94, 74)
		assert scroll_offset('text') == 900
		assert g_focused_field == ''
		set_scroll_offset('text', 0, 900)
		reset_scroll_frame()
		register_scroll_view('text', frame, frame, 1000, true, true, false)
		handle_touch_down(94, 90)
		handle_touch_up(94, 90)
		assert scroll_offset('text') == 900
	}

	fn test_scroll_to_rect_uses_the_full_viewport_height() {
		reset_scroll_test_state()
		register_scroll_view('text', rect(0, 0, 100, 100), rect(0, 0, 100, 50), 1000,
			true, true, false)
		scroll_to_rect('text', 0, 950, 10, 10)
		assert scroll_offset('text') == 860
		scroll_to_rect('text', 0, 0, 10, 10)
		assert scroll_offset('text') == 0
	}

	fn test_unmounted_text_area_drops_scroll_and_wrapping_state() {
		reset_scroll_test_state()
		scroll_test_panes()
		text_area_lines('text', 'abcdef', 30, TextStyle{}, 15, scroll_test_width)
		g_text_values['text'] = 'abcdef'
		g_text_kinds['text'] = .text_area
		g_active_scrolls = map[string]bool{}
		reset_scroll_frame()
		prune_unmounted_state()
		assert 'text' !in g_scroll_offsets
		assert 'text' !in g_scroll_content_h
		assert 'text' !in g_text_area_layouts
		assert scroll_hit_test(150, 50) == ''
	}
}
