// vfmt off
@[has_globals]
module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg

	__global pointer_capture_events = []string{}

	fn capture_pointer_event(id string) {
		pointer_capture_events << id
	}

	fn capture_pointer_event_and_remove_current_target(id string) {
		pointer_capture_events << id
		if id.starts_with('pointer:up:') {
			g_hit_targets = []HitTarget{}
		}
	}

	fn reset_pointer_capture_test() {
		g_touch = TouchState{}
		g_hit_targets = []HitTarget{}
		g_event_handler = capture_pointer_event
		g_scroll_handler = ScrollFn(unsafe { nil })
		pointer_capture_events = []string{}
		reset_scroll_frame()
		close_dropdown()
	}

	fn test_drag_keeps_original_target_after_resize_handle_moves_and_is_covered() {
		reset_pointer_capture_test()
		// The IDE's 9px resize handles move outside the original press almost
		// immediately. They identify themselves by action_id, not an element id.
		g_hit_targets = [HitTarget{action_id: 'resize_widget', w: 9, h: 9, draggable: true}]
		handle_touch_down(4, 4)
		handle_touch_move(20, 20)
		// Simulate the next frame rebuilding the hit targets at new coordinates.
		g_hit_targets = [
			HitTarget{action_id: 'resize_widget', x: 20, y: 20, w: 9, h: 9, draggable: true},
			HitTarget{action_id: 'unrelated', w: 9, h: 9, slider: true},
		]
		handle_touch_move(50, 60)
		handle_touch_up(70, 80)
		assert pointer_capture_events == [
			pointer_event_id('down', 'resize_widget', 4, 4),
			pointer_event_id('drag', 'resize_widget', 20, 20),
			pointer_event_id('drag', 'resize_widget', 50, 60),
			pointer_event_id('up', 'resize_widget', 70, 80),
		]
		assert !g_touch.down
		handle_touch_move(90, 90)
		handle_touch_up(90, 90)
		assert pointer_capture_events.len == 4
	}

	fn test_capture_is_released_and_the_next_press_uses_the_new_target() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{action_id: 'first', w: 20, h: 20, clickable: true}]
		handle_touch_down(5, 5)
		g_hit_targets = [HitTarget{action_id: 'second', w: 20, h: 20, clickable: true}]
		handle_touch_up(5, 5)
		handle_touch_down(5, 5)
		handle_touch_up(5, 5)
		assert pointer_capture_events == [
			pointer_event_id('down', 'first', 5, 5),
			pointer_event_id('up', 'first', 5, 5),
			pointer_event_id('down', 'second', 5, 5),
			pointer_event_id('up', 'second', 5, 5),
		]
	}

	fn test_capture_survives_a_frame_with_no_hit_targets_and_cancels_on_focus_loss() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{action_id: 'drag', w: 20, h: 20, draggable: true}]
		handle_touch_down(5, 5)
		g_hit_targets = []HitTarget{}
		on_event(&gg.Event{typ: .mouse_move, mouse_x: 40, mouse_y: 50}, &GgApp{})
		on_event(&gg.Event{typ: .unfocused}, &GgApp{})
		assert pointer_capture_events == [
			pointer_event_id('down', 'drag', 5, 5),
			pointer_event_id('drag', 'drag', 40, 50),
			pointer_event_id('up', 'drag', 40, 50),
		]
		assert !g_touch.down
		on_event(&gg.Event{typ: .mouse_up, mouse_x: 40, mouse_y: 50}, &GgApp{})
		assert pointer_capture_events.len == 3
	}

	fn test_cancelling_an_ordinary_button_does_not_activate_it() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{action_id: 'button', w: 20, h: 20}]
		handle_touch_down(5, 5)
		on_event(&gg.Event{typ: .touches_cancelled}, &GgApp{})
		handle_touch_up(5, 5)
		assert pointer_capture_events.len == 0
		assert !g_touch.down
	}

	fn test_button_behavior_emits_one_plain_action_on_release_inside() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			action_id:      'save_card'
			w:              120
			h:              56
			button_behavior: true
		}]
		handle_touch_down(20, 20)
		handle_touch_up(20, 20)
		assert pointer_capture_events == ['save_card']
	}

	fn test_button_behavior_keeps_the_pressed_target_across_a_rebuild() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'original'
			w:              120
			h:              56
			button_behavior: true
		}]
		handle_touch_down(20, 20)
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'replacement'
			w:              120
			h:              56
			button_behavior: true
		}]
		handle_touch_up(20, 20)
		assert pointer_capture_events == ['original']
	}

	fn test_button_behavior_revalidates_current_geometry_and_registration() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'save'
			w:              40
			h:              20
			button_behavior: true
		}]
		handle_touch_down(10, 10)
		// Releasing in the old frame must not activate after the view moves.
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'save'
			x:              100
			w:              40
			h:              20
			button_behavior: true
		}]
		handle_touch_up(10, 10)
		assert pointer_capture_events.len == 0

		// A resize that excludes the unchanged pointer also cancels activation.
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'save'
			w:              40
			h:              20
			button_behavior: true
		}]
		handle_touch_down(30, 10)
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'save'
			w:              20
			h:              20
			button_behavior: true
		}]
		handle_touch_up(30, 10)
		assert pointer_capture_events.len == 0

		// The current frame is authoritative while the captured action stays fixed.
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'save'
			w:              5
			h:              20
			button_behavior: true
		}]
		handle_touch_down(2, 10)
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'replacement'
			x:              6
			w:              5
			h:              20
			button_behavior: true
		}]
		handle_touch_up(7, 10)
		assert pointer_capture_events == ['save']

		// Disabled and removed views are absent from the current hit-target frame.
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'save'
			w:              40
			h:              20
			button_behavior: true
		}]
		handle_touch_down(10, 10)
		g_hit_targets = []HitTarget{}
		handle_touch_up(10, 10)
		assert pointer_capture_events.len == 0

		// Another element occupying the old rectangle is not the pressed target.
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'save'
			w:              40
			h:              20
			button_behavior: true
		}]
		handle_touch_down(10, 10)
		g_hit_targets = [HitTarget{
			id:             'replacement'
			action_id:      'save'
			w:              40
			h:              20
			button_behavior: true
		}]
		handle_touch_up(10, 10)
		assert pointer_capture_events.len == 0

		// Keeping the view but removing semantic behavior also cancels activation.
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			id:             'card'
			action_id:      'save'
			w:              40
			h:              20
			button_behavior: true
		}]
		handle_touch_down(10, 10)
		g_hit_targets = [HitTarget{
			id:        'card'
			action_id: 'save'
			w:         40
			h:         20
			clickable: true
		}]
		handle_touch_up(10, 10)
		assert pointer_capture_events.len == 0

		// Id-less duplicate actions are ambiguous after a rebuild and must not fire.
		reset_pointer_capture_test()
		g_hit_targets = [
			HitTarget{action_id: 'save', w: 40, h: 20, button_behavior: true},
			HitTarget{action_id: 'save', w: 40, h: 20, button_behavior: true},
		]
		handle_touch_down(10, 10)
		handle_touch_up(10, 10)
		assert pointer_capture_events.len == 0
	}

	fn test_button_behavior_cancels_outside_and_nested_button_wins() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			action_id:      'card'
			w:              120
			h:              56
			button_behavior: true
		}]
		handle_touch_down(20, 20)
		handle_touch_up(160, 20)
		assert pointer_capture_events.len == 0

		// Children are registered after their parent and reverse hit testing
		// gives a nested control ownership of the tap.
		g_hit_targets = [
			HitTarget{action_id: 'card', w: 120, h: 56, button_behavior: true},
			HitTarget{action_id: 'child', x: 10, y: 10, w: 40, h: 30},
		]
		handle_touch_down(20, 20)
		handle_touch_up(20, 20)
		assert pointer_capture_events == ['child']
	}

	fn test_button_behavior_cancels_after_drag_or_focus_loss() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			action_id:      'card'
			w:              120
			h:              56
			button_behavior: true
		}]
		handle_touch_down(20, 20)
		handle_touch_move(50, 20)
		handle_touch_up(20, 20)
		assert pointer_capture_events.len == 0

		handle_touch_down(20, 20)
		cancel_touch()
		assert pointer_capture_events.len == 0
	}

	fn test_raw_clickable_and_button_behavior_emit_both_contracts() {
		reset_pointer_capture_test()
		g_hit_targets = [HitTarget{
			action_id:      'surface'
			w:              120
			h:              56
			clickable:      true
			button_behavior: true
		}]
		handle_touch_down(20, 20)
		handle_touch_up(20, 20)
		assert pointer_capture_events == [
			pointer_event_id('down', 'surface', 20, 20),
			pointer_event_id('up', 'surface', 20, 20),
			'surface',
		]
	}

	fn test_raw_pointer_up_rebuild_does_not_change_an_already_validated_tap() {
		reset_pointer_capture_test()
		g_event_handler = capture_pointer_event_and_remove_current_target
		g_hit_targets = [HitTarget{
			id:             'surface'
			action_id:      'surface'
			w:              120
			h:              56
			clickable:      true
			button_behavior: true
		}]
		handle_touch_down(20, 20)
		handle_touch_up(20, 20)
		assert pointer_capture_events == [
			pointer_event_id('down', 'surface', 20, 20),
			pointer_event_id('up', 'surface', 20, 20),
			'surface',
		]
	}

	fn test_scrollbar_drag_takes_precedence_over_view_capture() {
		reset_pointer_capture_test()
		frame := rect(0, 0, 100, 100)
		register_scroll_view('pane', frame, frame, 400, true, true, true)
		g_hit_targets = [HitTarget{action_id: 'view', w: 100, h: 100, draggable: true}]
		bar := scrollbar_geometry(frame, 400, 0, true)
		handle_touch_down(bar.thumb.x + 1, bar.thumb.y + 1)
		assert g_touch.scrollbar_drag
		handle_touch_move(bar.thumb.x + 1, 60)
		handle_touch_up(bar.thumb.x + 1, 60)
		assert pointer_capture_events.len == 0
	}
}
